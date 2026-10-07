import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:path/path.dart' as path;
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import '../services/anki_service.dart';
import '../services/ffmpeg_service.dart';
import '../services/quran_tokenizers.dart';
import '../services/quran_pipeline_service.dart';

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
  final TextEditingController _titleController = TextEditingController();

  bool _isProcessing = false;
  String _processingStatus = '';
  double _processingProgress = 0.0;
  bool _quranShowLog = false;
  String? _apkgFilePath;
  String? _outputDirectory;
  DateTime? _processingStartTime;
  String? _lastProcessingTime;
  DateTime? _quranStartTime;
  String _quranElapsed = '';
  Timer? _quranElapsedTimer;
  int _extractedAudioCount = 0;
  int _totalNotes = 0;

  int _audioRepetitions = 4;
  bool _sampleMode = true;
  String _author = '';
  String _title = '';
  int _bitrate = 12;
  bool _quranPreset = false;
  final TextEditingController _authorController = TextEditingController();
  static const String _quranTitleSuffix = ' (Reciter) Verse by Verse';

  List<String> _availableColumns = [];
  int? _frontColumn;
  int? _backColumn;
  int? _audioColumn;

  int? _lastFrontColumn;
  int? _lastBackColumn;
  int? _lastAudioColumn;
  int? _lastSuraColumn;
  int? _lastAyaColumn;

  bool _matchByRange = false;
  bool _showCsvPreview = false;
  List<List<String>> _fullCsvData = [];
  final ScrollController _csvScrollController = ScrollController();

  List<Map<String, String>> _previewRows = [];
  String? _csvPath;

  bool _isTransliterating = false;
  String _transliterationStatus = '';
  double _transliterationProgress = 0.0;
  final List<String> _transliterationLog = [];
  bool _csvOnlyMode = false;
  bool _useFilenameAsChapterName = false;
  static String? _lastCsvDirectory;
  static String? _lastQuranRoot;
  String? _lastOutputFilename;

  bool _useSuraAyah = false;
  int? _suraColumn;
  int? _ayaColumn;

  late final QuranTokenizers _tokenizers;
  late final QuranPipelineService _quranService;
  bool _quranBusy = false;
  String? _quranRoot;
  List<String> _quranLanguageDirs = [];
  String _quranStatus = '';
  double _quranProgress = 0.0;
  final List<String> _quranLog = [];
  Timer? _logTimer;

  @override
  void initState() {
    super.initState();
    _tokenizers = QuranTokenizers(pythonExecutable: _pythonExecutable, log: _quranLogAdd);
    _quranService = QuranPipelineService(tokenizers: _tokenizers, log: _quranLogAdd);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _csvScrollController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _tokenizers.dispose();
    _logTimer?.cancel();
    _quranElapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _selectCsvFile() async {
    final startDir = (_quranRoot != null && await Directory(_quranRoot!).exists())
        ? _quranRoot
        : (_lastCsvDirectory != null && await Directory(_lastCsvDirectory!).exists()
            ? _lastCsvDirectory
            : null);

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select CSV File',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      initialDirectory: startDir,
    );

    if (result != null && result.files.isNotEmpty) {
      final filePath = result.files.first.path!;
      _lastCsvDirectory = path.dirname(filePath);

      setState(() {
        _csvPath = filePath;
        _apkgFilePath = null;
        _csvOnlyMode = true;
        _outputDirectory = path.dirname(filePath);
        _processingStatus = 'Reading CSV file...';
        _availableColumns = [];
        _previewRows = [];
        _frontColumn = null;
        _backColumn = null;
        _audioColumn = null;
        _suraColumn = null;
        _ayaColumn = null;
        _extractedAudioCount = 0;
        _totalNotes = 0;

        final filename = path.basenameWithoutExtension(filePath);
        final newMatch = RegExp(r'\d+[-–]\d+').firstMatch(filename);
        if (newMatch != null) {
          final newRange = newMatch.group(0)!;
          if (RegExp(r'\d+[-–]\d+').hasMatch(_title)) {
            _title = _title.replaceFirst(RegExp(r'\d+[-–]\d+'), newRange);
          } else {
            _title = '$_title $newRange'.trim();
          }
          _titleController.text = _title;
        }
      });

      try {
        final file = File(filePath);
        final csvContent = await file.readAsString();
        final csvData = Csv().decode(csvContent);

        if (csvData.isEmpty) throw Exception('CSV file is empty');

        final columns = csvData[0].map((e) => e.toString()).toList();
        final previewRows = <Map<String, String>>[];

        for (int i = 1; i < csvData.length && previewRows.length < 15; i++) {
          final row = csvData[i];
          final rowData = <String, String>{};
          for (int k = 0; k < columns.length; k++) {
            rowData[columns[k]] = k < row.length ? row[k].toString() : '';
          }
          if (rowData.isNotEmpty) previewRows.add(rowData);
        }

        setState(() {
          _availableColumns = columns;
          _previewRows = previewRows;
          _totalNotes = csvData.length - 1;
          _processingStatus = 'Ready to configure columns';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded CSV: ${csvData.length - 1} rows, ${columns.length} columns'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _csvPath = null;
          _csvOnlyMode = false;
          _processingStatus = 'Error: $e';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to read CSV: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
        _suraColumn = null;
        _ayaColumn = null;
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

  void _toast(String message, {Color color = Colors.green}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String get _pythonExecutable {
    if (Platform.isWindows) return 'python';
    return 'python3';
  }

  int? _findColumnByKeyword(String keyword) {
    for (int i = 0; i < _availableColumns.length; i++) {
      if (_availableColumns[i].toLowerCase().contains(keyword)) {
        return i;
      }
    }
    return null;
  }

  void _applyQuranPreset(bool? value) {
    final enabled = value ?? false;
    setState(() {
      _quranPreset = enabled;
      if (!enabled) return;

      _author = 'Quran Arabic';
      _authorController.text = 'Quran Arabic';

      _audioRepetitions = 1;
      _bitrate = 32;
      _useFilenameAsChapterName = true;
      _sampleMode = false;
      _useSuraAyah = true;
      _matchByRange = true;

      if (!_title.contains(_quranTitleSuffix)) {
        _title = '$_title$_quranTitleSuffix';
        _titleController.text = _title;
      }

      if (_availableColumns.isNotEmpty) {
        _frontColumn = _findColumnByKeyword('translation') ?? _frontColumn;
        _backColumn = _findColumnByKeyword('arabic') ?? _backColumn;
        _audioColumn = _findColumnByKeyword('audio') ?? _audioColumn;
        _suraColumn = _findColumnByKeyword('sura') ?? _suraColumn;
        _ayaColumn = _findColumnByKeyword('aya') ?? _ayaColumn;
      }
    });
  }

  Future<void> _startConversion() async {
    if ((_apkgFilePath == null && !_csvOnlyMode) || _outputDirectory == null) {
      _showError('Please select an .apkg or (Quran) CSV file');
      return;
    }

    if (_frontColumn == null || _backColumn == null || _audioColumn == null) {
      _showError('Please select Front, Back, and Audio columns');
      return;
    }

    if (_useSuraAyah && (_suraColumn == null || _ayaColumn == null)) {
      _showError('Please select Sura and Aya columns');
      return;
    }

    if (_author.isEmpty || _title.isEmpty) {
      _showError('Please enter Language (Artist) and Title (Album)');
      return;
    }

    final String csvPathToUse;
    final String mediaDirToUse;

    if (_csvOnlyMode) {
      final baseName = path.basenameWithoutExtension(_csvPath!);
      csvPathToUse = _csvPath!;
      mediaDirToUse = path.join(path.dirname(_csvPath!), '${baseName}_media');
    } else {
      final baseName = path.basenameWithoutExtension(_apkgFilePath!);
      csvPathToUse = path.join(_outputDirectory!, '${baseName}_converted.csv');
      mediaDirToUse = path.join(_outputDirectory!, '${baseName}_media');
    }

    _lastFrontColumn = _frontColumn;
    _lastBackColumn = _backColumn;
    _lastAudioColumn = _audioColumn;
    _lastSuraColumn = _useSuraAyah ? _suraColumn : null;
    _lastAyaColumn = _useSuraAyah ? _ayaColumn : null;

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
        apkgPath: _apkgFilePath ?? _csvPath!,
        outputDir: _outputDirectory!,
        csvPath: csvPathToUse,
        mediaDir: mediaDirToUse,
        frontColumn: _frontColumn!,
        backColumn: _backColumn!,
        audioColumn: _audioColumn!,
        audioRepetitions: _audioRepetitions,
        useFilenameAsChapterName: _useFilenameAsChapterName,
        sampleMode: _sampleMode,
        author: _author,
        title: _title,
        bitrate: _bitrate,
        suraColumn: _useSuraAyah ? _suraColumn : null,
        ayaColumn: _useSuraAyah ? _ayaColumn : null,
        matchByRange: _matchByRange,
        moveToParent: _quranPreset,
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
          _lastOutputFilename = '$_author - $_title.opus';
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
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildApkgFileSection()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildOrganizeMediaSection()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildOutputDirectorySection()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildQuranVttSection()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildConversionControls(),
          ],
        ),
      ),
    );
  }

  Future<Uint8List> _loadTranslationsZip() async {
    final data = await rootBundle.load('assets/quranversebyverse/versebyversequran.zip');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  void _refreshQuranRoot(String root) {
    _quranRoot = root;
    _lastQuranRoot = root;
    _quranLanguageDirs = QuranPipelineService.findLanguageDirs(root);
  }

  Future<void> _runOrganizeMedia() async {
    final startDir = (_quranRoot != null && await Directory(_quranRoot!).exists())
        ? _quranRoot
        : (_lastQuranRoot != null && await Directory(_lastQuranRoot!).exists()
            ? _lastQuranRoot
            : null);

    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder containing the verse-by-verse mp3 files',
      initialDirectory: startDir,
    );
    if (dir == null) return;
    final root = path.dirname(dir);
    _lastQuranRoot = root;
    setState(() {
      _quranShowLog = false;
      _quranElapsed = '';
      _quranBusy = true;
      _quranStatus = 'Organizing mp3 files...';
      _quranProgress = 0;
      _quranLog.clear();
    });
    try {
      await _quranService.organizeMedia(dir);

      final errors = _quranLog.where((l) => l.contains('ERROR')).toList();
      final warnings = _quranLog.where((l) => l.contains('WARNING')).length;

      setState(() {
        _refreshQuranRoot(root);
        _quranStatus = '';
      });

      if (errors.isNotEmpty) {
        _toast(errors.first.replaceFirst('ERROR:', '').trim(), color: Colors.red);
      } else {
        _toast(
          'Organized mp3s into 7 folders'
          '${warnings > 0 ? ' ($warnings warnings)' : ''}',
          color: warnings > 0 ? Colors.blue : Colors.green,
        );
      }
    } catch (e) {
      setState(() => _quranStatus = '');
      _toast('Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _quranBusy = false);
    }
  }

  Future<void> _unzipRangeCsvs() async {
    var root = _quranRoot;
    if (root == null) {
      root = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select root folder to extract the 7 quran_saheeh CSVs into',
      );
      if (root == null) return;
      setState(() => _refreshQuranRoot(root!));
    }
    setState(() {
      _quranShowLog = false;
      _quranElapsed = '';
      _quranBusy = true;
      _quranProgress = 0;
      _quranStatus = 'Extracting quran_saheeh CSVs...';
    });
    try {
      final n = await QuranPipelineService.extractZipInIsolate(
        await _loadTranslationsZip(),
        root,
        mode: ZipExtractMode.rangeCsvsOnly,
      );
      final missing = QuranPipelineService.ranges
          .where((r) => !File(path.join(root!, 'quran_saheeh$r.csv')).existsSync())
          .toList();

      setState(() {
        _refreshQuranRoot(root!);
        _quranStatus = '';
      });

      _toast(
        missing.isEmpty
            ? 'Extracted $n quran_saheeh CSVs'
            : 'Extracted $n CSVs, still missing: ${missing.join(', ')}',
        color: missing.isEmpty ? Colors.green : Colors.orange,
      );
    } catch (e) {
      setState(() => _quranStatus = '');
      _toast('Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _quranBusy = false);
    }
  }

  Future<void> _unzipBundledTranslations() async {
    var root = _quranRoot;
    if (root == null) {
      root = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to unzip the Quran translations into',
      );
      if (root == null) return;
      setState(() => _refreshQuranRoot(root!));
    }
    setState(() {
      _quranShowLog = false;
      _quranElapsed = '';
      _quranBusy = true;
      _quranProgress = 0;
      _quranStatus = 'Unzipping Quran translations...';
      _quranLog.clear();
    });
    try {
      final n = await QuranPipelineService.extractZipInIsolate(
        await _loadTranslationsZip(),
        root,
        mode: ZipExtractMode.languagesOnly,
      );
      final missing = QuranPipelineService.ranges
          .where((r) => !File(path.join(root!, 'quran_saheeh$r.csv')).existsSync())
          .toList();

      setState(() {
        _refreshQuranRoot(root!);
        _quranStatus = '';
      });

      _toast(
        missing.isEmpty
            ? 'Unzipped $n files, ${_quranLanguageDirs.length} languages'
            : 'Unzipped $n files, but quran_saheeh CSVs are missing '
              '(click Unzip 7 quran_saheeh CSVs)',
            color: missing.isEmpty ? Colors.green : Colors.orange,
      );
    } catch (e) {
      setState(() => _quranStatus = '');
      _toast('Error: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _quranBusy = false);
    }
  }

  Future<void> _runQuranPipeline() async {
    final root = _quranRoot;
    if (root == null) return;

    _quranStartTime = DateTime.now();
    _quranElapsedTimer?.cancel();
    _quranElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _quranStartTime == null) return;
      setState(() => _quranElapsed =
          _formatDuration(DateTime.now().difference(_quranStartTime!)));
    });

    setState(() {
      _quranShowLog = true;
      _quranBusy = true;
      _quranProgress = 0;
      _quranStatus = 'Starting...';
      _quranElapsed = '0m 0s';
      _quranLog.clear();
    });
    void onProgress(String s, double pr) {
      if (mounted) setState(() {
        _quranStatus = s;
        _quranProgress = pr;
      });
    }

    try {
      await _quranService.runBatch(root, doVtt: true, onProgress: onProgress);
      setState(() {
        _refreshQuranRoot(root);
        _quranStatus = 'Complete!';
        _quranProgress = 1.0;
      });
    } catch (e) {
      setState(() => _quranStatus = 'Error: $e');
    } finally {
        _quranElapsedTimer?.cancel();
        if (mounted) {
          setState(() {
            _quranBusy = false;
            if (_quranStartTime != null) {
              _quranElapsed =
                  _formatDuration(DateTime.now().difference(_quranStartTime!));
            }
          });
        }
      }
    }


  void _quranLogAdd(String msg) {
    _quranLog.add(msg);
    if (_quranLog.length > 200000) _quranLog.removeRange(0, 20000);
    if (_logTimer?.isActive ?? false) return;
    _logTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() {});
    });
  }

  Widget _buildQuranLogBox() {
    if (!_quranShowLog || _quranLog.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_quranLog.length} lines',
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy all'),
                onPressed: () => Clipboard.setData(ClipboardData(text: _quranLog.join('\n'))),
              ),
              TextButton.icon(
                icon: const Icon(Icons.warning_amber, size: 14),
                label: const Text('Copy warnings'),
                onPressed: () => Clipboard.setData(ClipboardData(
                  text: _quranLog
                      .where((l) => l.contains('WARNING') || l.contains('ERROR'))
                      .join('\n'),
                )),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Clear'),
                onPressed: () => setState(_quranLog.clear),
              ),
            ],
          ),
          Container(
            height: 180,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectionArea(
              child: ListView.builder(
                reverse: true,
                itemCount: _quranLog.length,
                itemBuilder: (context, i) {
                  final line = _quranLog[_quranLog.length - 1 - i];
                  final bad = line.contains('WARNING') || line.contains('ERROR');
                  return Text(
                    line,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'CustomFonts',
                      color: bad ? Colors.orange : Colors.white70,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizeMediaSection() {
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
          const Row(children: [
            Icon(Icons.drive_file_move, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Organize Quran Verse by Verse mp3s into 7 folders',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              children: [
                const TextSpan(
                  text: 'Select the folder holding the 001001.mp3 or 001_001.mp3 style files. '
                      'Download them from ',
                ),
                TextSpan(
                  text: 'everyayah.com',
                  style: const TextStyle(
                    color: Colors.lightBlue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _launchUrl('https://everyayah.com'),
                ),
                const TextSpan(
                  text: ' and '
                ),
                TextSpan(
                  text: 'audio.qud.dev',
                  style: const TextStyle(
                    color: Colors.lightBlue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _launchUrl('https://audio.qud.dev/'),
                ),
                const TextSpan(
                  text: '. Creates quran_saheeh001-006_media … '
                      'quran_saheeh070-114_media next to it (ayah 000 files go to z_bismillah). '
                      'That parent folder becomes the root. Then click Unzip 7 quran_saheeh CSVs '
                      'to extract the CSVs needed to build the audiobooks there.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: (_quranBusy || _isProcessing) ? null : _runOrganizeMedia,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Select mp3 Folder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade900,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: (_quranBusy || _isProcessing) ? null : _unzipRangeCsvs,
                icon: const Icon(Icons.unarchive, size: 18),
                label: const Text('Unzip 7 quran_saheeh CSVs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade900,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuranVttSection() {
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
          const Row(children: [
            Icon(Icons.subtitles, color: Colors.tealAccent, size: 20),
            SizedBox(width: 8),
            Text('Quran translation CSVs & VTT subs',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Cleans the CSVs, splits them into 7 ranges, generates translated VTTs and splits long cues. '
            'Works on every language subfolder in the root folder (the parent of the mp3 folder). '
            'To convert just one language, put it in its own subfolder. '
            'Khmer cue splitting uses Python (khmer-segmenter).',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(
              onPressed: _quranBusy ? null : _unzipBundledTranslations,
              icon: const Icon(Icons.unarchive, size: 18),
              label: const Text('Unzip 82 Quran Translations'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade900, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: (_quranBusy || _isProcessing || _quranRoot == null) ? null : _runQuranPipeline,
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Split vtt cues'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade900, foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            _quranRoot == null
                ? 'No root folder yet (select the mp3 folder, or unzip translations)'
                : '$_quranRoot  •  ${_quranLanguageDirs.length} language folders found',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (_quranBusy || _quranStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              if (_quranBusy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              Expanded(
                child: Text(_quranStatus,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'CustomFonts')),
              ),
              if (_quranElapsed.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  'Elapsed Time: $_quranElapsed',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontFamily: 'CustomFonts',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _quranBusy && _quranProgress == 0 ? null : _quranProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              minHeight: 6,
            ),
          ],
          _buildQuranLogBox(),
        ],
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

      if (fileSize > 5 * 1024 * 1024) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Large CSV File'),
            content: Text(
              'This CSV file is ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB.\n'
              'Preview will be limited to first $MAX_PREVIEW_ROWS rows and $MAX_PREVIEW_COLS columns.\n\n'
              'Continue?',
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
      final lines = stream.transform(utf8.decoder).transform(LineSplitter());

      int lineCount = 0;
      await for (final line in lines) {
        if (lineCount >= MAX_PREVIEW_ROWS + 1) break;

        final row = _parseCsvLine(line);

        if (row.length > MAX_PREVIEW_COLS) {
          _fullCsvData.add(row.sublist(0, MAX_PREVIEW_COLS));
        } else {
          _fullCsvData.add(row);
        }

        lineCount++;

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
    final rowCount = _fullCsvData.length - 1;
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
                        border: const Border(
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
                'Anki .apkg File or csv / Quran csv',
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
            _buildStatusBox(
              icon: Icons.check_circle,
              iconColor: Colors.green,
              text: _apkgFilePath!,
            )
          else if (_csvOnlyMode && _csvPath != null)
            _buildStatusBox(
              icon: Icons.check_circle,
              iconColor: Colors.green,
              text: 'CSV: $_csvPath',
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
                    'No .apkg or (Quran) CSV file selected',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _selectApkgFile,
                icon: const Icon(Icons.folder_open, size: 18),
                label: const Text('Select .apkg File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade900,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _selectCsvFile,
                icon: const Icon(Icons.table_chart, size: 18),
                label: const Text('Select CSV File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade900,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_csvOnlyMode) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: SelectableText(
                    'audio files must be in a subfolder named '
                    '"${_csvPath != null ? path.basenameWithoutExtension(_csvPath!) : "<deck>"}_media" '
                    'next to the CSV.',
                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBox({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
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
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'Create opus audiobooks with VTT subtitles from Anki .apkg files. Login to\n',
                ),
                TextSpan(
                  text: 'ankiweb.net',
                  style: const TextStyle(
                    color: Colors.lightBlue,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _launchUrl('https://ankiweb.net'),
                ),
                const TextSpan(
                  text: ' using an email address, click Get Shared Decks & find one with audio\n',
                ),
                const TextSpan(
                  text: 'Automatically splits into multiple audiobooks if more than 999 chapters (audios)\n',
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
              const SizedBox(width: 36),
              if (_lastFrontColumn != null && _lastBackColumn != null && _lastAudioColumn != null)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _frontColumn = _lastFrontColumn;
                      _backColumn = _lastBackColumn;
                      _audioColumn = _lastAudioColumn;
                      if (_useSuraAyah) {
                        _suraColumn = _lastSuraColumn;
                        _ayaColumn = _lastAyaColumn;
                      }
                    });
                  },
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(
                    'Use Last (${(_lastFrontColumn! + 1)}, ${(_lastBackColumn! + 1)}, ${(_lastAudioColumn! + 1)}'
                    '${_lastSuraColumn != null && _lastAyaColumn != null ? ', Sura ${_lastSuraColumn! + 1}, Aya ${_lastAyaColumn! + 1}' : ''})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
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
                      onChanged: (value) => setState(() => _frontColumn = value),
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
                      onChanged: (value) => setState(() => _backColumn = value),
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
                      onChanged: (value) => setState(() => _audioColumn = value),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_useSuraAyah) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sura Column',
                        style: TextStyle(color: Color(0xFF34d399), fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _suraColumn,
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
                        onChanged: (value) => setState(() => _suraColumn = value),
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
                        'Aya Column',
                        style: TextStyle(color: Color(0xFFa78bfa), fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _ayaColumn,
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
                        onChanged: (value) => setState(() => _ayaColumn = value),
                      ),
                    ],
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
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
            final suraKey = _useSuraAyah && _suraColumn != null ? _availableColumns[_suraColumn!] : null;
            final ayaKey = _useSuraAyah && _ayaColumn != null ? _availableColumns[_ayaColumn!] : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (suraKey != null && ayaKey != null)
                    Text(
                      'Sura/Aya: ${row[suraKey] ?? ''},${row[ayaKey] ?? ''}',
                      style: const TextStyle(color: Color(0xFF34d399), fontSize: 12),
                    ),
                  if (suraKey != null && ayaKey != null) const SizedBox(height: 4),
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
                  'Audiobook Configuration - Quran Arabic / Quran English / Quran quranenc Language',
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
                        controller: _authorController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Spanish, Japanese, Arabic',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                        onChanged: (value) => setState(() => _author = value),
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
                        controller: _titleController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(),
                          hintText: 'e.g., Core 1k Sentences',
                          hintStyle: TextStyle(color: Colors.white38),
                        ),
                        onChanged: (value) => setState(() => _title = value),
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
                                const Text('Audio Repetitions', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  initialValue: _audioRepetitions,
                                  decoration: const InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder()),
                                  dropdownColor: const Color(0xFF1E1E1E),
                                  style: const TextStyle(color: Colors.white),
                                  items: const [
                                    DropdownMenuItem(value: 1, child: Text('1 time: front 1x only')),
                                    DropdownMenuItem(value: 2, child: Text('2 times: front 1x, back 1x')),
                                    DropdownMenuItem(value: 3, child: Text('3 times: front 2x, back 1x')),
                                    DropdownMenuItem(value: 4, child: Text('4 times: front 2x, back 2x')),
                                    DropdownMenuItem(value: 5, child: Text('5 times: front 3x, back 2x')),
                                    DropdownMenuItem(value: 6, child: Text('6 times: front 3x, back 3x')),
                                  ],
                                  onChanged: (value) => setState(() => _audioRepetitions = value!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bitrate', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<int>(
                                  initialValue: _bitrate,
                                  decoration: const InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder()),
                                  dropdownColor: const Color(0xFF1E1E1E),
                                  style: const TextStyle(color: Colors.white),
                                  items: [12, 32].map((bitrate) {
                                    return DropdownMenuItem(value: bitrate, child: Text('$bitrate kbps'));
                                  }).toList(),
                                  onChanged: (value) => setState(() => _bitrate = value!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Quick Preset', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                const SizedBox(height: 4),
                                CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                  title: const Text(
                                    'Quran Presets',
                                    style: TextStyle(color: Colors.white, fontSize: 13),
                                  ),
                                  value: _quranPreset,
                                  onChanged: _applyQuranPreset,
                                  activeColor: Colors.deepPurple,
                                ),
                              ],
                            ),
                          ),
                          const Expanded(child: SizedBox()),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Use filename as chapter name', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('e.g. chapter named 001004 instead of 0001 (CSV mode only)', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              value: _useFilenameAsChapterName,
                              onChanged: (value) => setState(() => _useFilenameAsChapterName = value!),
                              activeColor: Colors.deepPurple,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Sample Mode (50 entries)', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Uncheck to process entire deck', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              value: _sampleMode,
                              onChanged: (value) => setState(() => _sampleMode = value!),
                              activeColor: Colors.deepPurple,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Prepend Sura/Aya to subtitles', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Adds "1,0 " prefix to each subtitle line', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              value: _useSuraAyah,
                              onChanged: (value) => setState(() => _useSuraAyah = value!),
                              activeColor: Colors.deepPurple,
                            ),
                          ),
                          Expanded(
                            child: CheckboxListTile(
                              title: const Text('Match media by range', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('e.g. 001-006 in CSV matches 001-006 _chapters dir', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              value: _matchByRange,
                              onChanged: (value) => setState(() => _matchByRange = value!),
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
                    fontFamily: 'CustomFonts',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (elapsedTime.isNotEmpty) ...[
                const SizedBox(width: 12),
                Text(
                  'Elapsed Time: $elapsedTime',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 14,
                    fontFamily: 'CustomFonts',
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
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
    final canConvert = (_apkgFilePath != null || _csvOnlyMode) &&
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
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text('Close'),
            ),
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
                  'Last conversion completed in $_lastProcessingTime${_lastOutputFilename != null ? '  $_lastOutputFilename' : ''}',
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
