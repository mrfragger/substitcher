import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/whisper_service.dart';
import '../services/ffmpeg_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TranscribeScreen extends StatefulWidget {
  const TranscribeScreen({super.key});

  @override
  State<TranscribeScreen> createState() => _TranscribeScreenState();
}

class _TranscribeScreenState extends State<TranscribeScreen> {
  final WhisperService _whisperService = WhisperService();
  final ScrollController _scrollController = ScrollController();
  bool _isTranscribing = false;
  String _transcriptionStatus = '';
  double _transcriptionProgress = 0.0;
  String? _chaptersDirectory;
  DateTime? _transcriptionStartTime;
  String? _lastTranscriptionTime;
  double? _lastRealtimeSpeed;
  Duration? _startingRemainingDuration;
  int _totalTranscriptionChapters = 0;
  int _currentTranscriptionChapter = 0;
 Duration _cumulativeChapterDuration = Duration.zero;
 final FFmpegService _ffmpegService = FFmpegService();
 Duration _totalRemainingDuration = Duration.zero;
 Duration _initialTotalDuration = Duration.zero;
 Map<String, Duration> _chapterDurations = {};

  @override
  void initState() {
    super.initState();
    _whisperService.initialize();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _selectWhisperExecutable() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Whisper Executable',
    );
    
    if (result != null && result.files.isNotEmpty) {
      await _whisperService.setWhisperExecutable(result.files.first.path!);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Whisper executable set successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  Future<void> _selectModelDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Whisper Models Directory',
    );
    
    if (result != null) {
      await _whisperService.setModelDirectory(result);
      
      final models = _whisperService.getAvailableModels();
      
      if (mounted) {
        setState(() {});
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${models.length} models'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  Future<void> _selectChaptersDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select encodedchapters Directory',
    );
    
    if (result != null) {
      setState(() {
        _chaptersDirectory = result;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set: ${path.basename(result)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  Future<void> _startTranscription() async {
    if (_chaptersDirectory == null) return;
    
    final chaptersDir = Directory(_chaptersDirectory!);
    final opusFiles = chaptersDir
        .listSync()
        .where((e) => e is File && e.path.endsWith('.opus'))
        .cast<File>()
        .toList();
    
    setState(() {
      _transcriptionStatus = 'Calculating total duration...';
    });
    
    _chapterDurations.clear();
    Duration totalDuration = Duration.zero;
    Duration totalRemainingDuration = Duration.zero;
    
    for (final file in opusFiles) {
      try {
        final duration = await _ffmpegService.getAudioDuration(file.path);
        _chapterDurations[file.path] = duration;
        totalDuration += duration;
        
        final vttPath = file.path.replaceAll('.opus', '.vtt');
        final hasVtt = await File(vttPath).exists();
        
        if (!hasVtt) {
          totalRemainingDuration += duration;
        }
      } catch (e) {
        print('Error getting duration for ${file.path}: $e');
      }
    }
    
    print('Total audiobook duration: ${_formatDuration(totalDuration)}');
    print('Total remaining duration to transcribe: ${_formatDuration(totalRemainingDuration)}');
    
    setState(() {
      _isTranscribing = true;
      _transcriptionStatus = 'Starting transcription...';
      _transcriptionProgress = 0.0;
      _transcriptionStartTime = DateTime.now();
      _totalTranscriptionChapters = opusFiles.length;
      _currentTranscriptionChapter = 0;
      _cumulativeChapterDuration = Duration.zero;
      _totalRemainingDuration = totalRemainingDuration;
      _initialTotalDuration = totalDuration;
      _startingRemainingDuration = _totalRemainingDuration;
    
      if (_initialTotalDuration.inSeconds > 0) {
        final transcribedDuration = _initialTotalDuration - _totalRemainingDuration;
        _transcriptionProgress = transcribedDuration.inSeconds / _initialTotalDuration.inSeconds;
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scrollController = _scrollController;
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
    
    await _whisperService.transcribeChapters(
      _chaptersDirectory!,
      (status, progress, cumulativeDuration) {
        if (mounted) {
          final chapterMatch = RegExp(r'Processing chapter (\d+)/(\d+)').firstMatch(status);
          if (chapterMatch != null) {
            final newChapterNum = int.parse(chapterMatch.group(1)!);
            
            // When we move to a new chapter, the previous one must be complete
            if (newChapterNum > _currentTranscriptionChapter && _currentTranscriptionChapter > 0) {
              // Find the opus file that was just completed (0-based index)
              final justCompletedIndex = _currentTranscriptionChapter - 1;
              if (justCompletedIndex >= 0 && justCompletedIndex < opusFiles.length) {
                final completedFile = opusFiles[justCompletedIndex].path;
                if (_chapterDurations.containsKey(completedFile)) {
                  setState(() {
                    // Subtract the completed chapter's duration
                    _totalRemainingDuration -= _chapterDurations[completedFile]!;
                    if (_totalRemainingDuration.isNegative) {
                      _totalRemainingDuration = Duration.zero;
                    }
                    
                    if (_initialTotalDuration.inSeconds > 0) {
                      final transcribedDuration = _initialTotalDuration - _totalRemainingDuration;
                      _transcriptionProgress = transcribedDuration.inSeconds / _initialTotalDuration.inSeconds;
                    }
                  });
                  print('Chapter $newChapterNum started, completed chapter had duration: ${_chapterDurations[completedFile]}');
                  print('Remaining duration: ${_formatDuration(_totalRemainingDuration)}');
                  print('Progress: ${(_transcriptionProgress * 100).toStringAsFixed(1)}%');
                }
              }
            }
            
            _currentTranscriptionChapter = newChapterNum;
          }
          
          if (status.contains('Transcribing') && status.contains('segments') && cumulativeDuration == Duration.zero) {
            _transcriptionStartTime = DateTime.now();
          }
          
          setState(() {
            _transcriptionStatus = status;
            _cumulativeChapterDuration = cumulativeDuration;
          });
        }
      },
      (error) {
        if (mounted) {
          setState(() {
            _isTranscribing = false;
            _transcriptionStatus = 'Error: $error';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
    
    if (mounted && _isTranscribing) {
      final elapsed = DateTime.now().difference(_transcriptionStartTime!);
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes.remainder(60);
      final seconds = elapsed.inSeconds.remainder(60);
    
      double finalRealtimeSpeed = 0.0;
      if (_startingRemainingDuration!.inSeconds > 0 && elapsed.inSeconds > 0) {
        finalRealtimeSpeed = _startingRemainingDuration!.inSeconds / elapsed.inSeconds;
      }
      
      setState(() {
        _isTranscribing = false;
        _transcriptionStatus = 'Transcription complete!';
        _transcriptionProgress = 1.0;
        _lastTranscriptionTime = hours > 0 
            ? '${hours}h ${minutes}m ${seconds}s'
            : '${minutes}m ${seconds}s';
        _lastRealtimeSpeed = finalRealtimeSpeed;
        _totalRemainingDuration = Duration.zero;
      });

      await _convertAllVttToMarkdown(_chaptersDirectory!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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

  Future<void> _convertAllVttToMarkdown(String chaptersDirectory) async {
    try {
      setState(() {
        _transcriptionStatus = 'Converting VTT files to markdown...';
      });
      
      final vttFiles = <String>[];
      final dir = Directory(chaptersDirectory);
      await for (final entity in dir.list()) {
        if (entity is File && path.extension(entity.path).toLowerCase() == '.vtt') {
          vttFiles.add(entity.path);
        }
      }
      
      vttFiles.sort();
      
      for (int i = 0; i < vttFiles.length; i++) {
        final vttPath = vttFiles[i];
        final vttFilename = path.basenameWithoutExtension(vttPath);
        
        final vttContent = await File(vttPath).readAsString();
        final paragraphs = _createParagraphsFromVtt(vttContent);
        
        if (paragraphs.isEmpty) continue;
        
        final mdContent = StringBuffer();
        mdContent.writeln('# $vttFilename\n');
        
        for (final paragraph in paragraphs) {
          mdContent.writeln(paragraph);
          mdContent.writeln();
        }
        
        final cleanFilename = vttFilename
            .replaceAll('/', '-')
            .replaceAll("'", '')
            .replaceAll('"', '')
            .replaceAll(':', '-')
            .replaceAll('\\', '-')
            .replaceAll('|', '-')
            .replaceAll('?', '')
            .replaceAll('*', '')
            .replaceAll('<', '')
            .replaceAll('>', '');
        
        final mdFilename = '$cleanFilename.md';
        final mdPath = path.join(chaptersDirectory, mdFilename);
        
        await File(mdPath).writeAsString(mdContent.toString());
      }
    } catch (e) {
      print('Error converting VTT to markdown: $e');
    }
  }
  
  List<String> _createParagraphsFromVtt(String vttContent) {
    final cues = _parseVttContent(vttContent);
    if (cues.isEmpty) return [];
    
    final allText = cues
        .map((cue) => cue.replaceAll('\n', ' ').trim())
        .where((text) => text.isNotEmpty)
        .join(' ');
    
    final sentences = <String>[];
    final words = allText.split(RegExp(r'\s+'));
    var currentSentence = '';
    
    for (final word in words) {
      currentSentence += word + ' ';
      
      if (word.endsWith('.') || word.endsWith('?') || word.endsWith('!')) {
        final abbreviations = ['Mr.', 'Dr.', 'Mrs.', 'Ms.', 'Prof.', 'Sr.', 'Jr.', 'St.'];
        final isAbbreviation = abbreviations.any((abbr) => 
          currentSentence.trim().endsWith(abbr));
        
        if (!isAbbreviation) {
          sentences.add(currentSentence.trim());
          currentSentence = '';
        }
      }
    }
    
    if (currentSentence.trim().isNotEmpty) {
      sentences.add(currentSentence.trim());
    }
  
    final paragraphs = <String>[];
    for (int i = 0; i < sentences.length; i += 9) {
      final paragraphSentences = sentences.skip(i).take(9).toList();
      if (paragraphSentences.isNotEmpty) {
        var paragraph = paragraphSentences.join(' ');
        
        if (paragraph.isNotEmpty) {
          paragraph = paragraph[0].toUpperCase() + paragraph.substring(1);
        }
        
        paragraphs.add(paragraph);
      }
    }
    
    return paragraphs;
  }
  
  List<String> _parseVttContent(String content) {
    final cues = <String>[];
    final lines = content.split('\n');
    
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final textLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }
        if (textLines.isNotEmpty) {
          cues.add(textLines.join('\n'));
        }
      }
    }
    
    return cues;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Whisper Transcription'),
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
              'Transcribe Audiobook Chapters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transcribe audiobook chapters using whisper.cpp',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 32),
            
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    _buildModelDirectorySection(),
                    const SizedBox(height: 24),

                    _buildWhisperPathSection(),
                    const SizedBox(height: 24),
                    
                    _buildChaptersDirectorySection(),
                    const SizedBox(height: 32),
                    
                    _buildWhisperSettingsSection(),
                    const SizedBox(height: 32),
                    
                    if (_isTranscribing) ...[
                      _buildTranscriptionProgress(),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
            
            _buildTranscriptionControls(),
            
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

  Widget _buildWhisperPathSection() {
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
              const Icon(Icons.terminal, color: Colors.lightBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Whisper Executable',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await _whisperService.testWhisperExecutable();
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Whisper Diagnostic'),
                    content: SingleChildScrollView(
                      child: SelectableText(
                        result,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            icon: const Icon(Icons.bug_report, size: 18),
            label: const Text('Test Whisper'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          
          const SizedBox(height: 12),
          if (_whisperService.whisperExecutablePath != null)
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
                      _whisperService.whisperExecutablePath!,
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
                    'Whisper executable not set',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _selectWhisperExecutable,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Select Whisper Executable'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModelDirectorySection() {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.view_list, color: Colors.deepPurple, size: 24),
                SizedBox(width: 12),
                Text(
                  'Whisper Models Directory',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://huggingface.co/ggerganov/whisper.cpp/tree/main');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text(
                'Download models from: https://huggingface.co/ggerganov/whisper.cpp/tree/main',
                style: TextStyle(
                  color: Color(0xFF60a5fa),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildModelInfo('ggml-large-v3-turbo.bin', '1.62GB', 
              '8G RAM works great. The fastest and tends to hallucinate a little bit more than large v2'),
            const SizedBox(height: 8),
            _buildModelInfo('ggml-large-v2-q8_0.bin', '1.66GB',
              '8GB RAM works great a tad less accurate than large v2 as it\'s quantized'),
            const SizedBox(height: 8),
            _buildModelInfo('ggml-large-v2.bin', '3.09GB',
              '8GB RAM is pushing it but will work if no other apps open and with some swap'),
            const SizedBox(height: 16),
            
            if (_whisperService.modelDirectory != null) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _whisperService.modelDirectory!,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (_whisperService.getAvailableModels().isNotEmpty) ...[
                const Text(
                  'Available Models:',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _whisperService.getAvailableModels().map((model) {
                    return ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _whisperService.selectedModel = model;
                          _whisperService.saveSettings();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _whisperService.selectedModel == model
                            ? Colors.deepPurple
                            : const Color(0xFF3A3A3A),
                      ),
                      child: Text(model),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ] else ...[
              const Text(
                'Please download a model and select the directory containing it.',
                style: TextStyle(color: Colors.orange, fontSize: 14),
              ),
              const SizedBox(height: 16),
            ],
            
            ElevatedButton.icon(
              onPressed: _selectModelDirectory,
              icon: const Icon(Icons.folder_open),
              label: Text(_whisperService.modelDirectory == null 
                  ? 'Select Model Directory' 
                  : 'Change Model Directory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
          ],
        ),
      );
    }
  
  Widget _buildModelInfo(String modelName, String size, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$modelName $size',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: description,
          child: const Icon(Icons.info_outline, color: Colors.white54, size: 16),
        ),
      ],
    );
  }

  Widget _buildChaptersDirectorySection() {
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
              const Icon(Icons.audio_file, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Chapters Directory',
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
            'Select the directory containing encoded chapter .opus files',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_chaptersDirectory != null && _chaptersDirectory!.isNotEmpty)
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
                      _chaptersDirectory!,
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
                    'No chapters directory selected',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _selectChaptersDirectory,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Select encodedchapters Directory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhisperSettingsSection() {
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
              const Icon(Icons.settings, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Whisper Settings',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Language',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _whisperService.language,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: [
                       'auto',
                       'Afrikaans', 'Albanian', 'Amharic', 'Arabic', 'Armenian', 'Azerbaijani',
                       'Basque', 'Belarusian', 'Bengali', 'Bosnian', 'Bulgarian',
                       'Catalan', 'Cebuano', 'Chichewa', 'Chinese', 'Cantonese (CN)', 'Cantonese (HK)', 'Mandarin (TW)', 'Corsican', 'Croatian', 'Czech',
                       'Danish', 'Dutch',
                       'English', 'Esperanto', 'Estonian',
                       'Filipino', 'Finnish', 'French', 'Western Frisian',
                       'Galician', 'Georgian', 'German', 'Greek', 'Gujarati',
                       'Haitian Creole', 'Hausa', 'Hawaiian', 'Hebrew', 'Hindi', 'Hmong', 'Hungarian',
                       'Icelandic', 'Igbo', 'Indonesian', 'Irish', 'Italian',
                       'Japanese', 'Javanese',
                       'Kannada', 'Kazakh', 'Khmer', 'Kinyarwanda', 'Korean', 'Kurdish', 'Kyrgyz',
                       'Lao', 'Latin', 'Latvian', 'Lithuanian', 'Luxembourgish',
                       'Macedonian', 'Malagasy', 'Malay', 'Malayalam', 'Maltese', 'Māori', 'Marathi', 'Mongolian', 'Myanmar',
                       'Nepali', 'Norwegian',
                       'Odia', 'Pashto', 'Persian', 'Polish', 'Portuguese', 'Punjabi',
                       'Romanian', 'Russian',
                       'Samoan', 'Scottish Gaelic', 'Serbian', 'Sesotho', 'Shona', 'Sindhi', 'Sinhala', 'Slovak', 'Slovenian', 'Somali', 'Spanish', 'Sundanese', 'Swahili', 'Swedish',
                       'Tajik', 'Tamil', 'Tatar', 'Telugu', 'Thai', 'Turkish', 'Turkmen',
                       'Ukrainian', 'Urdu', 'Uyghur', 'Uzbek',
                       'Vietnamese',
                       'Welsh',
                       'Xhosa',
                       'Yiddish', 'Yoruba',
                       'Zulu',
                      ].map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang == 'auto' ? 'Auto Detect' : lang),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _whisperService.language = value!;
                          _whisperService.saveSettings();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Prompt',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: _whisperService.customPrompt),
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _whisperService.customPrompt = value;
                        _whisperService.saveSettings();
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
                      'Segment Time (shorter = less chance of hallucination)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _whisperService.segmentTime,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: ['0:30', '1:00', '1:30', '2:00'].map((time) {
                        return DropdownMenuItem(
                          value: time,
                          child: Text(time),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _whisperService.segmentTime = value!;
                          _whisperService.saveSettings();
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
                      'Max Characters Line Length',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _whisperService.maxLength,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: [40, 60, 80].map((length) {
                        return DropdownMenuItem(
                          value: length,
                          child: Text('$length'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _whisperService.maxLength = value!;
                          _whisperService.saveSettings();
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
                child: CheckboxListTile(
                  title: const Text('Split on Word', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Uncheck for CJK languages', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: _whisperService.splitOnWord,
                  onChanged: (value) {
                    setState(() {
                      _whisperService.splitOnWord = value!;
                      _whisperService.saveSettings();
                    });
                  },
                  activeColor: Colors.deepPurple,
                ),
              ),
              if (_whisperService.selectedModel != 'large-v3-turbo')
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Translate to English', style: TextStyle(color: Colors.white)),
                    value: _whisperService.translateToEnglish,
                    onChanged: (value) {
                      setState(() {
                        _whisperService.translateToEnglish = value!;
                        _whisperService.saveSettings();
                      });
                    },
                    activeColor: Colors.deepPurple,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionControls() {
    final canTranscribe = _whisperService.whisperExecutablePath != null &&
        _whisperService.modelDirectory != null &&
        _chaptersDirectory != null &&
        !_isTranscribing;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canTranscribe ? _startTranscription : null,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  'Start Transcription',
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
            if (_isTranscribing) ...[
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isTranscribing = false;
                    _transcriptionStatus = 'Cancelled';
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
        if (_lastTranscriptionTime != null && !_isTranscribing) ...[
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
                  'Last transcription completed in $_lastTranscriptionTime'
                  '${_lastRealtimeSpeed != null && _lastRealtimeSpeed! > 0 ? ' • Realtime Speed ${_lastRealtimeSpeed!.toStringAsFixed(1)}x' : ''}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildTranscriptionProgress() {
    String elapsedTime = '';
    String realtimeSpeed = '';
    String totalDurationStr = '';
    String remainingDurationStr = '';
    String estimatedTimeLeftStr = '';
    String calculationLine1 = '';
    String calculationLine2 = '';
    
    if (_transcriptionStartTime != null) {
      final elapsed = DateTime.now().difference(_transcriptionStartTime!);
      final hours = elapsed.inHours;
      final minutes = elapsed.inMinutes.remainder(60);
      final seconds = elapsed.inSeconds.remainder(60);
      
      if (hours > 0) {
        elapsedTime = '${hours}h ${minutes}m ${seconds}s';
      } else {
        elapsedTime = '${minutes}m ${seconds}s';
      }
      
      double speedMultiplier = 0.0;
      if (_cumulativeChapterDuration.inSeconds > 0 && elapsed.inSeconds > 0) {
        speedMultiplier = _cumulativeChapterDuration.inSeconds / elapsed.inSeconds;
        realtimeSpeed = '${speedMultiplier.toStringAsFixed(1)}x';
      }
      
      if (speedMultiplier > 0 && _totalRemainingDuration.inSeconds > 0) {
        final estimatedSecondsLeft = _totalRemainingDuration.inSeconds / speedMultiplier;
        final estDuration = Duration(seconds: estimatedSecondsLeft.round());
        final estHours = estDuration.inHours;
        final estMinutes = estDuration.inMinutes.remainder(60);
        final estSeconds = estDuration.inSeconds.remainder(60);
        
        if (estHours > 0) {
          estimatedTimeLeftStr = '${estHours}h ${estMinutes}m ${estSeconds}s';
        } else {
          estimatedTimeLeftStr = '${estMinutes}m ${estSeconds}s';
        }
      }
    }
    
    if (_initialTotalDuration.inSeconds > 0) {
      final totalHours = _initialTotalDuration.inHours;
      final totalMinutes = _initialTotalDuration.inMinutes.remainder(60);
      final totalSeconds = _initialTotalDuration.inSeconds.remainder(60);
      
      if (totalHours > 0) {
        totalDurationStr = '${totalHours}h ${totalMinutes}m ${totalSeconds}s';
      } else {
        totalDurationStr = '${totalMinutes}m ${totalSeconds}s';
      }
    }
    
    if (_totalRemainingDuration.inSeconds > 0) {
      final remainingHours = _totalRemainingDuration.inHours;
      final remainingMinutes = _totalRemainingDuration.inMinutes.remainder(60);
      final remainingSeconds = _totalRemainingDuration.inSeconds.remainder(60);
      
      if (remainingHours > 0) {
        remainingDurationStr = '${remainingHours}h ${remainingMinutes}m ${remainingSeconds}s';
      } else if (remainingMinutes > 0) {
        remainingDurationStr = '${remainingMinutes}m ${remainingSeconds}s';
      } else {
        remainingDurationStr = '${remainingSeconds}s';
      }
    }
    
    if (_initialTotalDuration.inSeconds > 0) {
      final totalSeconds = _initialTotalDuration.inSeconds;
      final remainingSeconds = _totalRemainingDuration.inSeconds;
      final transcribedSeconds = totalSeconds - remainingSeconds;
      
      if (transcribedSeconds >= 0) {
        calculationLine1 = '($totalDurationStr) ${totalSeconds.toStringAsFixed(0)} - ($remainingDurationStr) ${remainingSeconds.toStringAsFixed(0)} = ${transcribedSeconds.toStringAsFixed(0)} seconds';
        calculationLine2 = 'Progress calculation: ${transcribedSeconds.toStringAsFixed(0)} / ${totalSeconds.toStringAsFixed(0)} = ${(_transcriptionProgress * 100).toStringAsFixed(2)}%';
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
                  '$_transcriptionStatus • Chapter $_currentTranscriptionChapter/$_totalTranscriptionChapters',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              Tooltip(
                message: 'Resumes from last complete transcribed chapter',
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Elapsed Time: $elapsedTime${realtimeSpeed.isNotEmpty ? ' ($realtimeSpeed realtime speed)' : ''}',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (totalDurationStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Total Duration of Audiobook: $totalDurationStr',
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (remainingDurationStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Remaining Audio Duration: $remainingDurationStr',
              style: const TextStyle(
                color: Colors.yellowAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (estimatedTimeLeftStr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Estimated Time Left: $estimatedTimeLeftStr',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _transcriptionProgress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            minHeight: 8,
          ),
          if (calculationLine1.isNotEmpty && calculationLine2.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              calculationLine1,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 2),
            Text(
              calculationLine2,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}