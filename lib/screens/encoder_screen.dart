import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import '../models/audio_file.dart';
import '../models/encoding_config.dart';
import '../services/ffmpeg_service.dart';
import '../services/whisper_service.dart';
import 'package:path/path.dart' as path;

class EncoderScreen extends StatefulWidget {
  const EncoderScreen({super.key});

  @override
  State<EncoderScreen> createState() => _EncoderScreenState();
}

class _EncoderScreenState extends State<EncoderScreen> {
  final FFmpegService _ffmpeg = FFmpegService();
  List<AudioFile> _files = [];
  bool _loading = false;
  bool _encoding = false;
  bool _cancelEncoding = false;
  double _progress = 0.0;
  String _statusMessage = '';
  int _completedFiles = 0;
  bool _useFilenames = true;
  List<AudioFile>? _titleCaseHistory;
  String? _lastEncodedPath;
  String? _lastEncodingTime;
  bool _extracting = false;
  String _extractionStatus = '';

  final WhisperService _whisperService = WhisperService();
  bool _isTranscribing = false;
  String _transcriptionStatus = '';
  double _transcriptionProgress = 0.0;
  String? _chaptersDirectory;

  DateTime? _transcriptionStartTime;
  String? _lastTranscriptionTime;
  int _totalTranscriptionChapters = 0;
  int _currentTranscriptionChapter = 0;
  
  int _bitrate = 16;
  bool _removeSilence = true;
  int _silenceDb = 34;
  bool _removeHiss = false;
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController(
    text: DateTime.now().year.toString()
  );

  Duration? _lastOriginalDuration;
  Duration? _lastFinalDuration;
  
  @override
  void initState() {
    super.initState();
    _checkFFmpeg();
    _whisperService.initialize();
  }
  
  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _yearController.dispose();
    super.dispose();
  }
  
  Future<void> _checkFFmpeg() async {
    final available = await _ffmpeg.checkFFmpegAvailable();
    if (!available && mounted) {
      _showError('FFmpeg not found!\n\nInstall:\nMac: brew install ffmpeg\nLinux: sudo apt install ffmpeg\nWindows: choco install ffmpeg');
    }
  }
  
  String _getFilenameWithoutExt(String filepath) {
    return filepath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
  }
  
  String _titleCaseString(String text) {
    final smallWords = RegExp(r'^(a|an|and|as|at|but|by|en|for|if|in|nor|of|on|or|per|the|to|up|v\.?|vs\.?|via|with)$', caseSensitive: false);
    
    final parts = <String>[];
    final regex = RegExp(r'(\S+|\s+)');
    for (final match in regex.allMatches(text)) {
      parts.add(match.group(0)!);
    }
    
    final nonWhitespace = parts.where((p) => p.trim().isNotEmpty).toList();
    
    return parts.map((part) {
      if (part.trim().isEmpty) return part;
      
      final word = part;
      final isFirstWord = word == nonWhitespace.first;
      final isLastWord = word == nonWhitespace.last;
      
      if (RegExp(r'^[Aa][dlnstrz]-').hasMatch(word)) {
        final prefix = word.substring(0, 3);
        final rest = word.substring(3);
        if (rest.isNotEmpty) {
          return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase() + 
                 rest[0].toUpperCase() + rest.substring(1).toLowerCase();
        }
        return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
      }
      
      if (word.contains('(')) {
        return word.split('').asMap().entries.map((e) {
          if (e.value == '(' && e.key + 1 < word.length) return e.value;
          if (e.key > 0 && word[e.key - 1] == '(') return e.value.toUpperCase();
          return e.value.toLowerCase();
        }).join('');
      }
      
      if (isFirstWord || isLastWord) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      if (smallWords.hasMatch(word)) {
        return word.toLowerCase();
      }
      
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join('');
  }
  
  void _applyTitleCase() {
    if (_titleCaseHistory != null) {
      setState(() {
        _files = _titleCaseHistory!;
        _titleCaseHistory = null;
      });
      return;
    }

    setState(() {
      _titleCaseHistory = List.from(_files);
      _files = _files.map((file) {
        final currentTitle = file.editedTitle.isNotEmpty 
            ? file.editedTitle 
            : (_useFilenames ? _getFilenameWithoutExt(file.path) : file.originalTitle);
        final titleCased = _titleCaseString(currentTitle);
        return AudioFile(
          path: file.path,
          filename: file.filename,
          duration: file.duration,
          originalTitle: file.originalTitle,
          editedTitle: titleCased,
        );
      }).toList();
    });
  }
  
  void _toggleTitleSource() {
    setState(() {
      _useFilenames = !_useFilenames;
      _files = _files.map((file) => AudioFile(
        path: file.path,
        filename: file.filename,
        duration: file.duration,
        originalTitle: file.originalTitle,
        editedTitle: _useFilenames 
            ? _getFilenameWithoutExt(file.path) 
            : file.originalTitle,
      )).toList();
    });
  }

  Future<void> _extractChapters() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['opus', 'm4a', 'm4b', 'ogg', 'mkv'],
    );
    
    if (result == null || result.files.isEmpty) return;
    
    final filePath = result.files.first.path!;
    final ext = path.extension(filePath).toLowerCase();
    
    if (ext != '.opus' && ext != '.m4a' && ext != '.m4b') {
      _showError('Please select an .opus, .m4a, or .m4b file');
      return;
    }
    
    setState(() {
      _extracting = true;
      _extractionStatus = 'Starting extraction...';
    });
    
    final startTime = DateTime.now();
    
    try {
      await _ffmpeg.extractChapters(
        audiobookPath: filePath,
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _extractionStatus = message;
            });
          }
        },
      );
      
      final elapsed = DateTime.now().difference(startTime);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds.remainder(60);
      
      setState(() {
        _extracting = false;
        _extractionStatus = 'Complete!';
      });
      
      _showSuccess('Chapters extracted in ${minutes}m ${seconds}s');
    } catch (e) {
      setState(() {
        _extracting = false;
        _extractionStatus = 'Error: $e';
      });
      _showError('Extraction failed: $e');
    }
  }
  
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'opus', 'ogg', 'flac', 'wav', 'wma', 'webm', 'mkv', 'mp4'],
      );
      
      if (result == null) return;
      
      setState(() => _loading = true);
      
      final audioFiles = <AudioFile>[];
      for (final file in result.files) {
        if (file.path == null) continue;
        
        try {
          final info = await _ffmpeg.getAudioInfo(file.path!);
          audioFiles.add(AudioFile(
            path: info.path,
            filename: info.filename,
            duration: info.duration,
            originalTitle: info.originalTitle,
            editedTitle: _useFilenames 
                ? _getFilenameWithoutExt(info.path) 
                : info.originalTitle,
          ));
        } catch (e) {
          print('Error loading ${file.name}: $e');
        }
      }
      
      audioFiles.sort((a, b) => a.path.compareTo(b.path));
      
      setState(() {
        _files = audioFiles;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error picking files: $e');
    }
  }
  
  Future<void> _pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      
      if (result == null) return;
      
      setState(() => _loading = true);
      
      final audioFiles = await _ffmpeg.listAudioFilesInDirectory(result);
      final processedFiles = audioFiles.map((file) => AudioFile(
        path: file.path,
        filename: file.filename,
        duration: file.duration,
        originalTitle: file.originalTitle,
        editedTitle: _useFilenames 
            ? _getFilenameWithoutExt(file.path) 
            : file.originalTitle,
      )).toList();
      
      setState(() {
        _files = processedFiles;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error loading folder: $e');
    }
  }
  
  void _editTitle(int index) {
    final controller = TextEditingController(text: _files[index].editedTitle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Chapter Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Chapter Title',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _files[index].editedTitle = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _startEncoding() async {
    if (_files.isEmpty) {
      _showError('No files selected');
      return;
    }
    
    if (_authorController.text.isEmpty || _titleController.text.isEmpty) {
      _showError('Please enter author and title');
      return;
    }
    
    if (_files.length > 999) {
      _showError('Chapter count exceeds 999 limit!\nCurrent: ${_files.length} chapters');
      return;
    }
    
    final totalHours = _totalDuration.inHours;
    if (totalHours >= 100) {
      _showError('Total duration exceeds 100 hours limit!\nCurrent: $totalHours hours');
      return;
    }
    
    final startTime = DateTime.now();
    
    setState(() {
      _encoding = true;
      _cancelEncoding = false;
      _progress = 0.0;
      _completedFiles = 0;
    });
    
    try {
      final config = EncodingConfig(
        bitrate: _bitrate,
        removeSilence: _removeSilence,
        silenceDb: _removeSilence ? _silenceDb : null,
        removeHiss: _removeHiss,
        author: _authorController.text,
        title: _titleController.text,
        year: _yearController.text,
      );
      
      final firstFilePath = _files[0].path;
      final sourceDir = firstFilePath.substring(0, firstFilePath.lastIndexOf('/'));
      
      final now = DateTime.now();
      final timestamp = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';
      
      final outputDir = '$sourceDir/substitcher/$timestamp';
      final encodedChaptersDir = '$outputDir/encodedchapters';
      final originalFilesDir = '$outputDir/originalfiles';
      
      Directory(encodedChaptersDir).createSync(recursive: true);
      Directory(originalFilesDir).createSync(recursive: true);
      
      setState(() {
        _statusMessage = 'Encoding chapters in parallel...';
      });
      
      final cpuCount = Platform.numberOfProcessors;
      final maxConcurrent = (cpuCount * 0.75).round().clamp(1, 8);
      
      print('Encoding with $maxConcurrent concurrent processes (detected $cpuCount CPUs)');
      
      final encodedFilesMap = <int, String>{};
      final semaphore = _Semaphore(maxConcurrent);
      final futures = <Future>[];
      
      for (var i = 0; i < _files.length; i++) {
        if (_cancelEncoding) {
          setState(() {
            _encoding = false;
            _statusMessage = 'Encoding cancelled';
          });
          _showError('Encoding cancelled by user');
          return;
        }
        
        final file = _files[i];
        final index = i;
        var displayTitle = file.displayTitle;
        
        displayTitle = displayTitle
            .replaceAll('/', '-')
            .replaceAll("'", '`')
            .replaceAll('"', '`')
            .replaceAll(':', '-')
            .replaceAll('\\', '-')
            .replaceAll('|', '-')
            .replaceAll('?', '')
            .replaceAll('*', '')
            .replaceAll('<', '')
            .replaceAll('>', '');
        
        final outputPath = '$encodedChaptersDir/$displayTitle.opus';
        
        final future = semaphore.acquire().then((_) async {
          if (_cancelEncoding) {
            semaphore.release();
            return;
          }
          
          try {
            await _ffmpeg.encodeChapter(
              inputPath: file.path,
              outputPath: outputPath,
              config: config,
              onProgress: (chapterProgress) {
              },
            );
            
            encodedFilesMap[index] = outputPath;
            
            if (mounted) {
              setState(() {
                _completedFiles++;
                _progress = _completedFiles / _files.length;
                _statusMessage = 'Encoded $_completedFiles/${_files.length}: $displayTitle';
              });
            }
          } finally {
            semaphore.release();
          }
        });
        
        futures.add(future);
      }
      
      await Future.wait(futures);
      
      if (_cancelEncoding) {
        setState(() {
          _encoding = false;
          _statusMessage = 'Encoding cancelled';
        });
        _showError('Encoding cancelled by user');
        return;
      }
      
      final encodedFiles = List.generate(
        _files.length,
        (i) => encodedFilesMap[i]!,
      );
      
      setState(() {
        _statusMessage = 'Creating final audiobook...';
        _progress = 0.99;
      });
      
      final finalPath = '$outputDir/${config.author} - ${config.title}.opus';
      
      await _ffmpeg.concatenateWithChapters(
        opusFiles: encodedFiles,
        outputPath: finalPath,
        config: config,
        onProgress: (message) {
          setState(() => _statusMessage = message);
        },
      );
  
      setState(() {
        _statusMessage = 'Organizing files...';
      });
      
      for (final file in _files) {
        final originalFile = File(file.path);
        if (originalFile.existsSync()) {
          final filename = path.basename(file.path);
          final destPath = path.join(originalFilesDir, filename);
          await originalFile.rename(destPath);
        }
      }
  
      final originalDuration = _totalDuration;
      final finalDuration = await _calculateFinalDuration(encodedFiles);
      
      setState(() {
        _encoding = false;
        _progress = 1.0;
        _statusMessage = 'Complete!';
      });
      
      final elapsed = DateTime.now().difference(startTime);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds.remainder(60);
      
      if (mounted) {
        setState(() {
          _lastEncodedPath = finalPath;
          _lastEncodingTime = '${minutes}m ${seconds}s';
          _lastOriginalDuration = originalDuration;
          _lastFinalDuration = finalDuration;
        });
      }
      
      _showSuccess('Audiobook created successfully!');
      
    } catch (e) {
      setState(() {
        _encoding = false;
        _statusMessage = 'Error: $e';
      });
      _showError('Encoding failed: $e');
    }
  }

  Future<Duration> _calculateFinalDuration(List<String> opusFiles) async {
    Duration total = Duration.zero;
    for (final file in opusFiles) {
      try {
        final duration = await _ffmpeg.getAudioDuration(file);
        total += duration;
      } catch (e) {
        print('Error getting duration for $file: $e');
      }
    }
    return total;
  }
  
  String _shortenPath(String path) {
    final home = Platform.environment['HOME'] ?? '/Users/${Platform.environment['USER']}';
    if (path.startsWith(home)) {
      return path.replaceFirst(home, '~');
    }
    return path;
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
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
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
    print('DEBUG: selectChaptersDirectory - START');
    
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select encodedchapters Directory',
    );
    
    print('DEBUG: FilePicker result = $result');
    
    if (result != null) {
      print('DEBUG: Setting _chaptersDirectory to: $result');
      
      setState(() {
        _chaptersDirectory = result;
      });
      
      print('DEBUG: After setState, _chaptersDirectory = $_chaptersDirectory');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set: ${path.basename(result)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      print('DEBUG: FilePicker returned null');
    }
  }
  
  Future<void> _startTranscription() async {
    if (_chaptersDirectory == null) return;
    
    setState(() {
      _isTranscribing = true;
      _transcriptionStatus = 'Starting transcription...';
      _transcriptionProgress = 0.0;
    });
    
    await _whisperService.transcribeChapters(
      _chaptersDirectory!,
      (status, progress) {
        if (mounted) {
          setState(() {
            _transcriptionStatus = status;
            _transcriptionProgress = progress;
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
      setState(() {
        _isTranscribing = false;
        _transcriptionStatus = 'Transcription complete!';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transcription completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  void _openTranscriptionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Whisper Transcription',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (!_isTranscribing)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Transcribe audiobook chapters using whisper.cpp',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 32),
                          
                          _buildWhisperPathSection(setDialogState),
                          const SizedBox(height: 24),
                          
                          _buildModelDirectorySection(setDialogState),
                          const SizedBox(height: 24),
                          
                          _buildChaptersDirectorySectionWithCallback(setDialogState),
                          const SizedBox(height: 32),
                          
                          _buildWhisperSettingsSection(setDialogState),
                          const SizedBox(height: 32),
                          
                          _buildTranscriptionControls(setDialogState),
                          
                          if (_isTranscribing) ...[
                            const SizedBox(height: 32),
                            _buildTranscriptionProgress(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
  
  Duration get _totalDuration => _files.fold(
    Duration.zero,
    (sum, file) => sum + file.duration,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_files.isNotEmpty)
              ElevatedButton(
                onPressed: _toggleTitleSource,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(_useFilenames ? 'Using Filenames' : 'Using Metadata'),
              ),
            const Expanded(
              child: Center(
                child: Text('SubStitcher - Audiobook Encoder'),
              ),
            ),
            if (_files.isNotEmpty)
              ElevatedButton(
                onPressed: _applyTitleCase,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(_titleCaseHistory != null ? 'Undo Title Case' : 'Apply Title Case'),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_files.isNotEmpty) _buildFileListHeader(),
                
                Expanded(
                  child: _files.isEmpty
                      ? _buildEmptyState()
                      : _buildFileList(),
                ),
                
                if (_files.isNotEmpty) _buildConfigPanel(),
                
                if (_encoding) _buildProgress(),
                
                _buildActions(),
              ],
            ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.audiotrack, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No audio files selected',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Files" or "Add Folder" to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_files.length} chapters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Total: ${_formatDuration(_totalDuration)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileList() {
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final originalTitle = _useFilenames 
            ? _getFilenameWithoutExt(file.path) 
            : file.originalTitle;
        
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF006064),
            radius: 16,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: _buildTitleWithHighlights(file.displayTitle, originalTitle),
              ),
              Text(
                file.formattedDuration,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          onTap: () => _editTitle(index),
        );
      },
    );
  }
  
  Widget _buildTitleWithHighlights(String displayTitle, String originalTitle) {
    if (displayTitle == originalTitle) {
      return Text(
        displayTitle,
        style: const TextStyle(fontSize: 14),
      );
    }
    
    final spans = <InlineSpan>[];
    
    for (int i = 0; i < displayTitle.length; i++) {
      final char = displayTitle[i];
      final isChanged = i < originalTitle.length && 
                       char != originalTitle[i] &&
                       char.toLowerCase() == originalTitle[i].toLowerCase();
      
      spans.add(TextSpan(
        text: char,
        style: TextStyle(
          fontSize: 14,
          color: isChanged ? Colors.green : null,
          fontWeight: isChanged ? FontWeight.bold : null,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        children: spans,
      ),
    );
  }
  
  Widget _buildConfigPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Audiobook Metadata', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _yearController,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Bitrate:'),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('16 kbps'),
                selected: _bitrate == 16,
                onSelected: (selected) {
                  if (selected) setState(() => _bitrate = 16);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('32 kbps'),
                selected: _bitrate == 32,
                onSelected: (selected) {
                  if (selected) setState(() => _bitrate = 32);
                },
              ),
              const SizedBox(width: 24),
              Checkbox(
                value: _removeSilence,
                onChanged: (value) {
                  setState(() => _removeSilence = value ?? false);
                },
              ),
              const Text('Remove Silence'),
              if (_removeSilence) ...[
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _silenceDb,
                  isDense: true,
                  items: [26, 30, 34, 38, 42, 46]
                      .map((db) => DropdownMenuItem(
                            value: db,
                            child: Text('-$db dB'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _silenceDb = value ?? 34);
                  },
                ),
              ],
              const SizedBox(width: 24),
              Checkbox(
                value: _removeHiss,
                onChanged: (value) {
                  setState(() => _removeHiss = value ?? false);
                },
              ),
              const Text('Remove Hiss'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text(_statusMessage),
        ],
      ),
    );
  }
  
  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_encoding || _extracting) ? null : _pickFiles,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Files'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_encoding || _extracting) ? null : _pickFolder,
                  icon: const Icon(Icons.folder),
                  label: const Text('Add Folder'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _encoding 
                    ? ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _cancelEncoding = true;
                          });
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('Cancel Encoding'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: (_extracting || _files.isEmpty) ? null : _startEncoding,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Encode Audiobook'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_encoding || _extracting) ? null : _extractChapters,
                  icon: const Icon(Icons.splitscreen),
                  label: const Text('Extract Chapters'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_encoding || _extracting) ? null : _openTranscriptionDialog,
                  icon: const Icon(Icons.subtitles),
                  label: const Text('Transcribe'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (_extracting) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_extractionStatus),
                ],
              ),
            ),
          ],
          if (_lastEncodedPath != null && _lastEncodingTime != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildEncodingSummary(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _shortenPath(_lastEncodedPath!),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
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

  Widget _buildEncodingSummary() {
    final parts = <String>['Encoding took $_lastEncodingTime'];
    
    if (_lastOriginalDuration != null && _lastFinalDuration != null) {
      final silenceRemoved = _lastOriginalDuration! - _lastFinalDuration!;
      
      if (silenceRemoved.inSeconds > 0) {
        parts.add('Duration ${_formatDuration(_lastFinalDuration!)}');
        parts.add('Silence removed ${_formatDuration(silenceRemoved)}');
      }
    }
    
    return Text(
      'Audiobook: ${parts.join(', ')}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget _buildTranscriptionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Whisper Transcription',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Transcribe audiobook chapters using whisper.cpp',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 32),
          
          _buildWhisperPathSection((fn) => setState(fn)),
          const SizedBox(height: 24),
          
          _buildModelDirectorySection((fn) => setState(fn)),
          const SizedBox(height: 24),
          
          _buildChaptersDirectorySection(),
          const SizedBox(height: 32),
          
          _buildWhisperSettingsSection((fn) => setState(fn)),
          const SizedBox(height: 32),
          
          _buildTranscriptionControls((fn) => setState(fn)),
          
          if (_isTranscribing) ...[
            const SizedBox(height: 32),
            _buildTranscriptionProgress(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildWhisperPathSection(StateSetter setDialogState) {
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
            onPressed: () async {
              await _selectWhisperExecutable();
              setDialogState(() {});
            },
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
  
  Widget _buildModelDirectorySection(StateSetter setDialogState) {
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
              const Icon(Icons.storage, color: Colors.purple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Whisper Models Directory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_whisperService.modelDirectory != null) ...[
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
                      _whisperService.modelDirectory!,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _whisperService.getAvailableModels().map((model) {
                return Chip(
                  label: Text(
                    model,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: Colors.deepPurple.withValues(alpha: 0.3),
                  side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.5)),
                );
              }).toList(),
            ),
          ] else
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
                    'Model directory not set',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await _selectModelDirectory();
              setDialogState(() {});
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Select Model Directory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChaptersDirectorySectionWithCallback(StateSetter setDialogState) {
    print('DEBUG: _chaptersDirectory = $_chaptersDirectory');
    
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
            onPressed: () async {
              await _selectChaptersDirectoryWithCallback(setDialogState);
            },
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

  Widget _buildChaptersDirectorySection() {
    return _buildChaptersDirectorySectionWithCallback((fn) => setState(fn));
  }
  
  Future<void> _selectChaptersDirectoryWithCallback(StateSetter setDialogState) async {
    print('DEBUG: selectChaptersDirectory - START');
    
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Chapters Directory',
    );
    
    print('DEBUG: FilePicker result = $result');
    
    if (result != null) {
      print('DEBUG: Setting _chaptersDirectory to: $result');
      
      setState(() {
        _chaptersDirectory = result;
      });
      
      setDialogState(() {});
      
      print('DEBUG: After setState, _chaptersDirectory = $_chaptersDirectory');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Set: ${path.basename(result)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      print('DEBUG: FilePicker returned null');
    }
  } 

  Widget _buildWhisperSettingsSection(StateSetter setDialogState) {
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
            children: [
              Expanded(
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
                        'auto', 'en', 'ar', 'zh', 'de', 'es', 'ja', 'pt', 'ru',
                        'fr', 'pa', 'hi', 'id', 'it', 'ko', 'th', 'el', 'sv', 'da', 'iw'
                      ].map((lang) => DropdownMenuItem(
                        value: lang,
                        child: Text(lang == 'auto' ? 'Auto Detect' : lang),
                      )).toList(),
                      onChanged: (value) {
                        setState(() {
                          _whisperService.language = value!;
                          _whisperService.saveSettings();
                        });
                        setDialogState(() {});
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
                      'Model',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _whisperService.getAvailableModels().contains(_whisperService.selectedModel) 
                          ? _whisperService.selectedModel 
                          : null,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      style: const TextStyle(color: Colors.white),
                      items: _whisperService.getAvailableModels().isEmpty
                          ? [const DropdownMenuItem(value: null, child: Text('No models found'))]
                          : _whisperService.getAvailableModels().map((model) {
                              return DropdownMenuItem(
                                value: model,
                                child: Text(model),
                              );
                            }).toList(),
                      onChanged: _whisperService.getAvailableModels().isEmpty ? null : (value) {
                        setState(() {
                          _whisperService.selectedModel = value!;
                          _whisperService.saveSettings();
                        });
                        setDialogState(() {});
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
                      'Segment Time (shorter has less likelihood of hallucination)',
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
                        setDialogState(() {});
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
                        setDialogState(() {});
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
                    setDialogState(() {});
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
                      setDialogState(() {});
                    },
                    activeColor: Colors.deepPurple,
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom Prompt',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: TextEditingController(text: _whisperService.customPrompt),
                maxLines: 3,
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
        ],
      ),
    );
  }

  Widget _buildTranscriptionControls(StateSetter setDialogState) {
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
                onPressed: canTranscribe ? () async {
                  final chaptersDir = Directory(_chaptersDirectory!);
                  final opusCount = chaptersDir
                      .listSync()
                      .where((e) => e is File && e.path.endsWith('.opus'))
                      .length;
                  
                  setState(() {
                    _isTranscribing = true;
                    _transcriptionStatus = 'Starting transcription...';
                    _transcriptionProgress = 0.0;
                    _transcriptionStartTime = DateTime.now();
                    _totalTranscriptionChapters = opusCount;
                    _currentTranscriptionChapter = 0;
                  });
                  setDialogState(() {});
                  
                  await _whisperService.transcribeChapters(
                    _chaptersDirectory!,
                    (status, progress) {
                      if (mounted) {
                        final chapterMatch = RegExp(r'Processing chapter (\d+)/(\d+)').firstMatch(status);
                        if (chapterMatch != null) {
                          _currentTranscriptionChapter = int.parse(chapterMatch.group(1)!);
                        }
                        
                        setState(() {
                          _transcriptionStatus = status;
                          _transcriptionProgress = progress;
                        });
                        setDialogState(() {});
                      }
                    },
                    (error) {
                      if (mounted) {
                        setState(() {
                          _isTranscribing = false;
                          _transcriptionStatus = 'Error: $error';
                        });
                        setDialogState(() {});
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
                    final minutes = elapsed.inMinutes;
                    final seconds = elapsed.inSeconds.remainder(60);
                    
                    setState(() {
                      _isTranscribing = false;
                      _transcriptionStatus = 'Transcription complete!';
                      _lastTranscriptionTime = '${minutes}m ${seconds}s';
                    });
                    setDialogState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transcription completed successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } : null,
                icon: const Icon(Icons.play_arrow, size: 24),
                label: const Text(
                  'Start Transcription',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  disabledBackgroundColor: Colors.grey,
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
                  setDialogState(() {});
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.stop, size: 24),
                label: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
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
                  'Last transcription completed in $_lastTranscriptionTime',
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
    if (_transcriptionStartTime != null) {
      final elapsed = DateTime.now().difference(_transcriptionStartTime!);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds.remainder(60);
      elapsedTime = '${minutes}m ${seconds}s';
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _transcriptionStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    if (_totalTranscriptionChapters > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Chapter $_currentTranscriptionChapter/$_totalTranscriptionChapters',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (elapsedTime.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Elapsed: $elapsedTime',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _transcriptionProgress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${(_transcriptionProgress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _queue = <Completer<void>>[];
  
  _Semaphore(this.maxCount);
  
  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    
    final completer = Completer<void>();
    _queue.add(completer);
    return completer.future;
  }
  
  void release() {
    _currentCount--;
    if (_queue.isNotEmpty) {
      final completer = _queue.removeAt(0);
      _currentCount++;
      completer.complete();
    }
  }
}