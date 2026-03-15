import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'dart:io';
import 'dart:convert';
import '../services/anki_service.dart';
import '../services/ffmpeg_service.dart';

class AnkiConverterScreen extends StatefulWidget {
  const AnkiConverterScreen({super.key});

  @override
  State<AnkiConverterScreen> createState() => _AnkiConverterScreenState();
}

class _AnkiConverterScreenState extends State<AnkiConverterScreen> {
  static const int MAX_PREVIEW_ROWS = 200;
  static const int MAX_PREVIEW_COLS = 120; 
  final AnkiService _ankiService = AnkiService();
  final ScrollController _scrollController = ScrollController();
  
  bool _isProcessing = false;
  String _processingStatus = '';
  double _processingProgress = 0.0;
  String? _apkgFilePath;
  String? _outputDirectory;
  DateTime? _processingStartTime;
  String? _lastProcessingTime;
  int _extractedAudioCount = 0;
  int _totalNotes = 0;
  
  int _audioRepetitions = 4;
  bool _sampleMode = true;
  String _author = ''; 
  String _title = '';
  int _bitrate =  16;
  
  List<String> _availableColumns = [];
  int? _frontColumn;
  int? _backColumn;
  int? _audioColumn;

  bool _showCsvPreview = false;
  List<List<String>> _fullCsvData = [];
  final ScrollController _csvScrollController = ScrollController();
  
  List<Map<String, String>> _previewRows = [];
  String? _csvPath;

  bool _isTransliterating = false;
  String _transliterationStatus = '';
  double _transliterationProgress = 0.0;
  final List<String> _transliterationLog = [];

  @override
  void dispose() {
    _scrollController.dispose();
    _csvScrollController.dispose();
    super.dispose();
  }

  Future<void> _selectApkgFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Anki .apkg File',
      type: FileType.custom,
      allowedExtensions: ['apkg'],
    );
    
    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.first.path!;
      
      setState(() {
        _apkgFilePath = filePath;
        _processingStatus = 'Extracting and analyzing .apkg file...';
        _availableColumns = [];
        _previewRows = [];
        _frontColumn = null;
        _backColumn = null;
        _audioColumn = null;
      });
      
      try {
        final extractResult = await _ankiService.extractAndConvert(filePath);
        
        setState(() {
          _availableColumns = extractResult['columns'] as List<String>;
          _previewRows = extractResult['preview'] as List<Map<String, String>>;
          _csvPath = extractResult['csvPath'] as String?;
          _outputDirectory = extractResult['outputDir'] as String;
          _extractedAudioCount = extractResult['extractedCount'] as int;
          _totalNotes = extractResult['totalNotes'] as int;
          _processingStatus = 'Ready to configure columns';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${extractResult['totalNotes']} notes with $_extractedAudioCount audios\nCSV saved to: $_csvPath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _apkgFilePath = null;
          _processingStatus = 'Error: $e';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process .apkg: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch $urlString'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String get _pythonExecutable {
    if (Platform.isWindows) return 'python';
    return 'python3'; // macOS and Linux
  }

  Future<void> _runHiraganaTransliteration() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Directory to Transliterate VTT Files',
    );
    
    if (result == null) return;
  
    final tempDir = Directory.systemTemp;
    final scriptFile = File('${tempDir.path}/vtt_to_hiragana.py');
  await scriptFile.writeAsString(r'''
import pykakasi, sys, os, re
from pathlib import Path

kks = pykakasi.kakasi()

def has_japanese(text):
    return bool(re.search(r'[\u3040-\u9fff]', text))

def convert_line(line):
    result = kks.convert(line)
    output = ''
    for item in result:
        if all('\u30A0' <= c <= '\u30FF' for c in item['orig'] if c.strip()):
            output += item['kana']
        else:
            output += item['hira']
    return output

def convert_vtt(input_path, output_path):
    with open(input_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    with open(output_path, 'w', encoding='utf-8') as out:
        for line in lines:
            stripped = line.rstrip('\n')
            if (stripped.startswith('WEBVTT') or
                '-->' in stripped or
                stripped.strip() == '' or
                stripped.strip().isdigit()):
                out.write(line)
            elif not has_japanese(stripped):
                out.write('\u200b\n')
            else:
                out.write(convert_line(stripped) + '\n')

root = Path(sys.argv[1])
vtt_files = [
    p for p in root.rglob('*.vtt')
    if not p.stem.endswith('_hiragana')
]

print(f'Found {len(vtt_files)} VTT files', flush=True)

for i, vtt in enumerate(vtt_files):
    output = vtt.parent / f'{vtt.stem}_hiragana.vtt'
    try:
        convert_vtt(vtt, output)
        print(f'OK:{vtt.name}', flush=True)
    except Exception as e:
        print(f'ERR:{vtt.name}:{e}', flush=True)

print('DONE', flush=True)
''');
  
    setState(() {
      _isTransliterating = true;
      _transliterationStatus = 'Starting...';
      _transliterationProgress = 0.0;
      _transliterationLog.clear();
    });
  
    try {
      final checkResult = await Process.run(_pythonExecutable, ['-c', 'import pykakasi']);
      if (checkResult.exitCode != 0) {
        setState(() => _transliterationStatus = 'Installing pykakasi...');
        final pipResult = await Process.run(
          Platform.isWindows ? 'pip' : 'pip3',
          ['install', 'pykakasi'],
        );
        if (pipResult.exitCode != 0) {
          throw Exception('pykakasi not installed. Run: pip install pykakasi');
        }
      }
      
      final process = await Process.start(_pythonExecutable, [scriptFile.path, result]);
  
      int total = 0;
      int done = 0;
  
      process.stdout
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (mounted) {
          setState(() {
            if (line.startsWith('Found ')) {
              final match = RegExp(r'Found (\d+)').firstMatch(line);
              if (match != null) total = int.parse(match.group(1)!);
              _transliterationStatus = line;
            } else if (line.startsWith('OK:')) {
              done++;
              final filename = line.substring(3);
              _transliterationLog.add('✓ $filename');
              _transliterationStatus = 'Transliterating to hiragana $done/$total...';
              _transliterationProgress = total > 0 ? done / total : 0;
            } else if (line.startsWith('ERR:')) {
              final filename = line.substring(4);
              _transliterationLog.add('✗ $filename');
            } else if (line == 'DONE') {
              _transliterationStatus = 'Complete! $done/$total files converted.';
              _transliterationProgress = 1.0;
              _isTransliterating = false;
            }
          });
        }
      });
  
      process.stderr
          .transform(const SystemEncoding().decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (mounted && line.isNotEmpty) {
          setState(() => _transliterationLog.add('! $line'));
        }
      });
  
      await process.exitCode;
  
    } catch (e) {
      setState(() {
        _isTransliterating = false;
        _transliterationStatus = 'Error: $e';
      });
    } finally {
      if (await scriptFile.exists()) await scriptFile.delete();
    }
  }

  Widget _buildHiraganaSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.translate, color: Colors.pinkAccent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Transliterate Japanese VTT to Hiragana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Recursively converts all .vtt files in a directory to hiragana, '
            'retaining katakana. Outputs filename_hiragana.vtt alongside each original to be used as a Secondary sub.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isTransliterating ? null : _runHiraganaTransliteration,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Select Directory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
            ),
          ),
          if (_isTransliterating || _transliterationProgress > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (_isTransliterating)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.pinkAccent,
                    ),
                  ),
                if (_isTransliterating) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _transliterationStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _transliterationProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
              minHeight: 6,
            ),
            if (_transliterationLog.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _transliterationLog.length,
                  itemBuilder: (context, index) => SelectableText(
                    _transliterationLog[index],
                    style: TextStyle(
                      fontSize: 11,
                      color: _transliterationLog[index].startsWith('✓')
                          ? Colors.greenAccent
                          : _transliterationLog[index].startsWith('✗')
                              ? Colors.redAccent
                              : Colors.orange,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
  
  Future<void> _startConversion() async {
    if (_apkgFilePath == null || _outputDirectory == null) {
      _showError('Please select .apkg file');
      return;
    }
    
    if (_frontColumn == null || _backColumn == null || _audioColumn == null) {
      _showError('Please select Front, Back, and Audio columns');
      return;
    }
    
    if (_author.isEmpty || _title.isEmpty) {
      _showError('Please enter Language (Artist) and Title (Album)');
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Starting conversion...';
      _processingProgress = 0.0;
      _processingStartTime = DateTime.now();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
    
    try {
      await _ankiService.createAudiobook(
        apkgPath: _apkgFilePath!,
        outputDir: _outputDirectory!,
        frontColumn: _frontColumn!,
        backColumn: _backColumn!,
        audioColumn: _audioColumn!,
        audioRepetitions: _audioRepetitions,
        sampleMode: _sampleMode,
        author: _author,
        title: _title,
        bitrate: _bitrate,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _processingStatus = status;
              _processingProgress = progress;
            });
          }
        },
      );
      
      if (mounted && _isProcessing) {
        final elapsed = DateTime.now().difference(_processingStartTime!);
        final hours = elapsed.inHours;
        final minutes = elapsed.inMinutes.remainder(60);
        final seconds = elapsed.inSeconds.remainder(60);
        
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Conversion complete!';
          _processingProgress = 1.0;
          _lastProcessingTime = hours > 0 
              ? '${hours}h ${minutes}m ${seconds}s'
              : '${minutes}m ${seconds}s';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audiobook created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _processingStatus = 'Error: $e';
      });
      
      _showError('Conversion failed: $e');
    }
  }

  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
  
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Anki to Audiobook Converter'),
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Convert Anki Deck to Audiobook',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                children: [
                  const TextSpan(
                    text: 'Create opus audiobooks with VTT subtitles from Anki .apkg files\n',
                  ),
                  const TextSpan(
                    text: 'Login to ',
                  ),
                  TextSpan(
                    text: 'https://ankiweb.net',
                    style: const TextStyle(
                      color: Colors.lightBlue,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _launchUrl('https://ankiweb.net'),
                  ),
                  const TextSpan(
                    text: ' using an email address, click Get Shared Decks and find one containing audio\n',
                  ),
                  const TextSpan(
                    text: 'Automatically splits into multiple audiobooks if more than 999 chapters (audios)\n',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                  _buildHiraganaSection(),
                  const SizedBox(height: 24),

                    _buildApkgFileSection(),
                    const SizedBox(height: 24),
                    
                    _buildOutputDirectorySection(),
                    const SizedBox(height: 24),
                    
                    _buildConfigurationSection(),
                    const SizedBox(height: 24),
                    
                    if (_availableColumns.isNotEmpty) ...[
                      _buildColumnSelectionSection(),
                      const SizedBox(height: 24),
                    ],
                    
                    if (_previewRows.isNotEmpty && 
                        _frontColumn != null && 
                        _backColumn != null && 
                        _audioColumn != null) ...[
                      _buildPreviewSection(),
                      const SizedBox(height: 24),
                    ],
                    
                    if (_csvPath != null && !_showCsvPreview) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _loadFullCsv,
                          icon: const Icon(Icons.preview),
                          label: const Text('Preview Full CSV'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                    
                    if (_showCsvPreview) ...[
                      const SizedBox(height: 24),
                      _buildCsvPreview(),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    if (_isProcessing) ...[
                      _buildProcessingProgress(),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildConversionControls(),
            
            const SizedBox(height: 16),
            
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _loadFullCsv() async {
    if (_csvPath == null) return;
    
    setState(() {
      _showCsvPreview = true;
      _fullCsvData = [];
    });
    
    try {
      final file = File(_csvPath!);
      final fileSize = await file.length();
      
      if (fileSize > 5 * 1024 * 1024) { // 5MB
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Large CSV File'),
            content: Text(
              'This CSV file is ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB.\n'
              'Preview will be limited to first $MAX_PREVIEW_ROWS rows and $MAX_PREVIEW_COLS columns.\n\n'
              'Continue?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        
        if (shouldContinue != true) {
          setState(() {
            _showCsvPreview = false;
          });
          return;
        }
      }
      
      final stream = file.openRead();
      final lines = stream
          .transform(utf8.decoder)
          .transform(LineSplitter());
      
      int lineCount = 0;
      await for (final line in lines) {
        if (lineCount >= MAX_PREVIEW_ROWS + 1) break; // +1 for header
        
        final row = _parseCsvLine(line);
        
        // Limit columns
        if (row.length > MAX_PREVIEW_COLS) {
          _fullCsvData.add(row.sublist(0, MAX_PREVIEW_COLS));
        } else {
          _fullCsvData.add(row);
        }
        
        lineCount++;
        
        // Update UI periodically
        if (lineCount % 25 == 0) {
          setState(() {});
        }
      }
      
      setState(() {});
    } catch (e) {
      _showError('Failed to load CSV: $e');
      setState(() {
        _showCsvPreview = false;
      });
    }
  }
  
  List<String> _parseCsvLine(String line) {
    final row = <String>[];
    bool inQuotes = false;
    StringBuffer currentField = StringBuffer();
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        row.add(currentField.toString());
        currentField = StringBuffer();
      } else {
        currentField.write(char);
      }
    }
    row.add(currentField.toString());
    
    return row;
  }

  Widget _buildCsvPreview() {
    if (_fullCsvData.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    final columnCount = _fullCsvData.first.length;
    final rowCount = _fullCsvData.length - 1; // Exclude header
    final isLimited = rowCount >= MAX_PREVIEW_ROWS || columnCount >= MAX_PREVIEW_COLS;
    
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                'CSV Preview${isLimited ? ' (Limited)' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isLimited) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Showing first $MAX_PREVIEW_ROWS rows and $MAX_PREVIEW_COLS columns',
                  child: const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _showCsvPreview = false;
                    _fullCsvData.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Scrollbar(
              controller: _csvScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _csvScrollController,
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white12,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 96,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: const Text(
                              'Row',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          ...List.generate(
                            columnCount,
                            (index) {
                              final headerText = _fullCsvData.first[index];
                              final columnNumber = index + 1;
                              final displayHeader = headerText.isNotEmpty 
                                  ? '$columnNumber. $headerText'
                                  : columnNumber.toString();
                              
                              return Container(
                                width: 166,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                child: Text(
                                  displayHeader,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Column(
                          children: _fullCsvData.skip(1).take(MAX_PREVIEW_ROWS).toList().asMap().entries.map((entry) {
                            final rowIndex = entry.key;
                            final row = entry.value;
                            
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 66,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                    child: Text(
                                      '${rowIndex + 1}',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Data cells
                                  ...List.generate(
                                    columnCount,
                                    (index) => Container(
                                      width: 166,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Text(
                                        index < row.length ? row[index] : '',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApkgFileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.book, color: Colors.lightBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Anki .apkg File',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_apkgFilePath != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _apkgFilePath!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'No .apkg file selected',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _selectApkgFile,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Select .apkg File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOutputDirectorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Output Directory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _extractedAudioCount > 0
                ? 'Audiobook will be saved in a subfolder next to the .apkg file ($_totalNotes notes, $_extractedAudioCount audios)'
                : 'Audiobook will be saved in a subfolder next to the .apkg file',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_outputDirectory != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _outputDirectory!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Output directory will be created automatically',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildColumnSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_column, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Column Selection',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select which columns contain Front (question), Back (answer), and Audio',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Front Column',
                      style: TextStyle(color: Color(0xFF60a5fa), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _frontColumn,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      items: _availableColumns.asMap().entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            '${entry.key + 1}. ${entry.value}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _frontColumn = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Back Column',
                      style: TextStyle(color: Color(0xFF4ade80), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _backColumn,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      items: _availableColumns.asMap().entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            '${entry.key + 1}. ${entry.value}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _backColumn = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Audio Column',
                      style: TextStyle(color: Color(0xFFfbbf24), fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _audioColumn,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      items: _availableColumns.asMap().entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            '${entry.key + 1}. ${entry.value}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _audioColumn = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreviewSection() {
      if (_frontColumn == null || _backColumn == null || _audioColumn == null) {
        return const SizedBox.shrink();
      }
      
      final previewCount = _previewRows.length > 15 ? 15 : _previewRows.length;
      
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Preview ($previewCount entries)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._previewRows.take(previewCount).map((row) {
              final frontKey = _availableColumns[_frontColumn!];
              final backKey = _availableColumns[_backColumn!];
              final audioKey = _availableColumns[_audioColumn!];
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Front: ${row[frontKey] ?? ''}',
                      style: const TextStyle(color: Color(0xFF60a5fa), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Back: ${row[backKey] ?? ''}',
                      style: const TextStyle(color: Color(0xFF4ade80), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Audio: ${row[audioKey] ?? ''}',
                      style: const TextStyle(color: Color(0xFFfbbf24), fontSize: 12),
                    ),
                    const Divider(color: Colors.white12),
                  ],
                ),
              );
            }),
          ],
        ),
      );
    }
  
  Widget _buildConfigurationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Audiobook Configuration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Language (Artist & Album Artist)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Spanish, Japanese, Arabic',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _author = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Title (Title & Album)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                        hintText: 'e.g., Core 1k Sentences',
                        hintStyle: TextStyle(color: Colors.white38),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _title = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
            Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Audio Repetitions',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          initialValue: _audioRepetitions,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(),
                          ),
                          dropdownColor: const Color(0xFF1E1E1E),
                          style: const TextStyle(color: Colors.white),
                          items: [
                            const DropdownMenuItem(
                              value: 1,
                              child: Text('1 time: front 1x only'),
                            ),
                            const DropdownMenuItem(
                              value: 2,
                              child: Text('2 times: front 1x, back 1x'),
                            ),
                            const DropdownMenuItem(
                              value: 3,
                              child: Text('3 times: front 2x, back 1x'),
                            ),
                            const DropdownMenuItem(
                              value: 4,
                              child: Text('4 times: front 2x, back 2x'),
                            ),
                            const DropdownMenuItem(
                              value: 5,
                              child: Text('5 times: front 3x, back 2x'),
                            ),
                            const DropdownMenuItem(
                              value: 6,
                              child: Text('6 times: front 3x, back 3x'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _audioRepetitions = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),    
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bitrate',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _bitrate,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: [16, 32].map((bitrate) {
                        return DropdownMenuItem(
                          value: bitrate,
                          child: Text('$bitrate kbps'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _bitrate = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Sample Mode (50 entries)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Uncheck to process entire deck', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: _sampleMode,
                  onChanged: (value) {
                    setState(() {
                      _sampleMode = value!;
                    });
                  },
                  activeColor: Colors.deepPurple,
                ),
              ),
            ],
          ),
          if (_csvPath != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_chart, color: Colors.blue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CSV: $_csvPath',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingProgress() {
    String elapsedTime = '';
    
    if (_processingStartTime != null) {
      final elapsed = DateTime.now().difference(_processingStartTime!);
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes.remainder(60);
      final seconds = elapsed.inSeconds.remainder(60);
      
      if (hours > 0) {
        elapsedTime = '${hours}h ${minutes}m ${seconds}s';
      } else {
        elapsedTime = '${minutes}m ${seconds}s';
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _processingStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (elapsedTime.isNotEmpty)
            Text(
              'Elapsed Time: $elapsedTime',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _processingProgress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            minHeight: 8,
          ),
        ],
      ),
    );
  }
  
  Widget _buildConversionControls() {
    final canConvert = _apkgFilePath != null &&
        _outputDirectory != null &&
        _frontColumn != null &&
        _backColumn != null &&
        _audioColumn != null &&
        !_isProcessing;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canConvert ? _startConversion : null,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  'Create Audiobook',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  disabledBackgroundColor: Colors.grey[800],
                ),
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isProcessing = false;
                    _processingStatus = 'Cancelled';
                  });
                },
                icon: const Icon(Icons.stop, size: 24),
                label: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                ),
              ),
            ],
          ],
        ),
        if (_lastProcessingTime != null && !_isProcessing) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Last conversion completed in $_lastProcessingTime',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}