import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import 'transcribe_screen.dart';
import 'repeats_screen.dart';
import 'metadata_editor_screen.dart';
import 'anki_converter_screen.dart';
import 'trim_audio_screen.dart';
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

  bool _showSearchReplace = false;
  bool _useRegex = false;
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  bool _isPreviewingReplace = false;
  Map<int, String> _originalReplaceValues = {};
  
  int _bitrate = 16;
  bool _removeSilence = false;
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
    _searchController.dispose();
    _replaceController.dispose();
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
        
        return parts.asMap().entries.map((entry) {
          final idx = entry.key;
          final part = entry.value;
          
          if (part.trim().isEmpty) return part;
          
          final word = part;
          final isFirstWord = word == nonWhitespace.first;
          final isLastWord = word == nonWhitespace.last;
          
          if (idx > 0) {
            final prevPart = parts[idx - 1];
            if (prevPart.contains(':') || prevPart.contains('：') || 
                (idx > 1 && (parts[idx - 2].contains(':') || parts[idx - 2].contains('：')))) {
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            }
          }
          
          if (word.startsWith('"') || word.startsWith('＂')) {
            if (word.length > 1) {
              final openQuote = word[0];
              return openQuote + word[1].toUpperCase() + word.substring(2).toLowerCase();
            }
          }
          
          if (idx > 0) {
            final prevPart = parts[idx - 1];
            if (prevPart == '"' || prevPart == '＂' || 
                (prevPart.trim().isEmpty && idx > 1 && (parts[idx - 2] == '"' || parts[idx - 2] == '＂'))) {
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            }
          }
          
          if (!isFirstWord && nonWhitespace.isNotEmpty) {
            final prevIndex = nonWhitespace.indexOf(word) - 1;
            if (prevIndex >= 0) {
              final prevWord = nonWhitespace[prevIndex];
              if (prevWord == nonWhitespace.first && 
                  RegExp(r'^\d+\.?$').hasMatch(prevWord)) {
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }
              
              if (prevWord.contains(':') || prevWord.contains('：')) {
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }
              
              if (prevWord == '"' || prevWord == '＂' || prevWord.endsWith('"') || prevWord.endsWith('＂')) {
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }
            }
          }
          
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
    
  void _toggleReplacePreview() {
      if (_searchController.text.isEmpty) {
        _showError('Please enter a search term');
        return;
      }
      
      setState(() {
        if (_isPreviewingReplace) {
          for (final entry in _originalReplaceValues.entries) {
            _files[entry.key].editedTitle = entry.value;
          }
          _originalReplaceValues.clear();
          _isPreviewingReplace = false;
        } else {
          _originalReplaceValues.clear();
          
          for (int i = 0; i < _files.length; i++) {
            final currentTitle = _files[i].editedTitle.isNotEmpty 
                ? _files[i].editedTitle 
                : (_useFilenames ? _getFilenameWithoutExt(_files[i].path) : _files[i].originalTitle);
            
            String newTitle;
            if (_useRegex) {
              try {
                final regex = RegExp(_searchController.text);
                if (regex.hasMatch(currentTitle)) {
                  _originalReplaceValues[i] = currentTitle;
                  newTitle = currentTitle.replaceAllMapped(
                    regex,
                    (match) {
                      String result = _replaceController.text;
                      for (int j = 0; j <= match.groupCount; j++) {
                        result = result.replaceAll('\$$j', match.group(j) ?? '');
                      }
                      return result;
                    },
                  );
                  _files[i].editedTitle = newTitle;
                }
              } catch (e) {
                _showError('Invalid regex pattern: $e');
                setState(() {
                  for (final entry in _originalReplaceValues.entries) {
                    _files[entry.key].editedTitle = entry.value;
                  }
                  _originalReplaceValues.clear();
                  _isPreviewingReplace = false;
                });
                return;
              }
            } else {
              if (currentTitle.contains(_searchController.text)) {
                _originalReplaceValues[i] = currentTitle;
                newTitle = currentTitle.replaceAll(_searchController.text, _replaceController.text);
                _files[i].editedTitle = newTitle;
              }
            }
          }
          
          _isPreviewingReplace = true;
        }
      });
    }
    
    void _applySearchReplace() {
      if (_searchController.text.isEmpty) {
        _showError('Please enter a search term');
        return;
      }
      
      setState(() {
        if (!_isPreviewingReplace) {
          for (int i = 0; i < _files.length; i++) {
            final currentTitle = _files[i].editedTitle.isNotEmpty 
                ? _files[i].editedTitle 
                : (_useFilenames ? _getFilenameWithoutExt(_files[i].path) : _files[i].originalTitle);
            
            String newTitle;
            if (_useRegex) {
              try {
                final regex = RegExp(_searchController.text);
                newTitle = currentTitle.replaceAllMapped(
                  regex,
                  (match) {
                    String result = _replaceController.text;
                    for (int j = 0; j <= match.groupCount; j++) {
                      result = result.replaceAll('\$$j', match.group(j) ?? '');
                    }
                    return result;
                  },
                );
              } catch (e) {
                _showError('Invalid regex pattern: $e');
                return;
              }
            } else {
              newTitle = currentTitle.replaceAll(_searchController.text, _replaceController.text);
            }
            
            _files[i].editedTitle = newTitle;
          }
        }
        
        _originalReplaceValues.clear();
        _isPreviewingReplace = false;
      });
      
      _showSuccess('Replacements applied');
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
    
    if (ext != '.opus' && ext != '.m4a' && ext != '.m4b' && ext != '.mkv') {
      _showError('Please select an .opus, .m4a, .m4b or .mkv file');
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
      _statusMessage = 'Starting...';
    });
    
    print('DEBUG: _removeSilence = $_removeSilence');
    print('DEBUG: _silenceDb = $_silenceDb');
    print('DEBUG: _removeHiss = $_removeHiss');
    
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
      
      print('DEBUG: config.removeSilence = ${config.removeSilence}');
      print('DEBUG: config.silenceDb = ${config.silenceDb}');
      print('DEBUG: Filter string = ${config.buildFilterString()}');
      
      final firstFilePath = _files[0].path;
      final sourceDir = path.dirname(firstFilePath);
      
      final now = DateTime.now();
      final timestamp = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';
      
      final outputDir = path.join(sourceDir, 'substitcher', timestamp);
      final encodedChaptersDir = path.join(outputDir, 'encodedchapters');
      
      Directory(encodedChaptersDir).createSync(recursive: true);
      
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

      Duration totalEncodedDuration = Duration.zero;
      for (final encodedPath in encodedFiles) {
        final dur = await _ffmpeg.getAudioDuration(encodedPath);
        totalEncodedDuration += dur;
      }
      
      setState(() {
        _statusMessage = 'Creating final audiobook...';
        _progress = 0.99;
      });
      
      final finalPath = path.join(outputDir, '${config.author} - ${config.title}.opus');
      
      await _ffmpeg.concatenateWithChapters(
        opusFiles: encodedFiles,
        outputPath: finalPath,
        config: config,
        onProgress: (message) {
          setState(() => _statusMessage = message);
        },
      );
  
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
        duration: const Duration(seconds: 3),
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
            if (_files.isNotEmpty) ...[
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showSearchReplace = !_showSearchReplace;
                    if (!_showSearchReplace && _isPreviewingReplace) {
                      for (final entry in _originalReplaceValues.entries) {
                        _files[entry.key].editedTitle = entry.value;
                      }
                      _originalReplaceValues.clear();
                      _isPreviewingReplace = false;
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Replace'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyTitleCase,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: const Size(150, 36),
                ),
                child: Text(_titleCaseHistory != null ? 'Undo Title Case' : 'Apply Title Case'),
              ),
              const SizedBox(width: 30),
            ],
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showSearchReplace) _buildSearchReplacePanel(),
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
  
  Widget _buildSearchReplacePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: _useRegex ? 'Search (regex mode)' : 'Search (plain text)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: _showRegexHelp,
                      tooltip: 'Show regex examples',
                    ),
                  ),
                  onChanged: (_) {
                    if (_isPreviewingReplace) {
                      setState(() {
                        for (final entry in _originalReplaceValues.entries) {
                          _files[entry.key].editedTitle = entry.value;
                        }
                        _originalReplaceValues.clear();
                        _isPreviewingReplace = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _replaceController,
                  decoration: const InputDecoration(
                    labelText: 'Replace',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_isPreviewingReplace) {
                      setState(() {
                        for (final entry in _originalReplaceValues.entries) {
                          _files[entry.key].editedTitle = entry.value;
                        }
                        _originalReplaceValues.clear();
                        _isPreviewingReplace = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _toggleReplacePreview,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: _isPreviewingReplace ? Colors.orange : null,
                  foregroundColor: _isPreviewingReplace ? Colors.white : null,
                ),
                child: Text(_isPreviewingReplace ? 'Undo Preview' : 'Preview'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applySearchReplace,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _useRegex,
                onChanged: (value) {
                  setState(() {
                    _useRegex = value ?? false;
                    if (_isPreviewingReplace) {
                      for (final entry in _originalReplaceValues.entries) {
                        _files[entry.key].editedTitle = entry.value;
                      }
                      _originalReplaceValues.clear();
                      _isPreviewingReplace = false;
                    }
                  });
                },
              ),
              const Text('Use Regular Expressions'),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showRegexHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Search & Replace Examples'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Simple Pattern Matching',
                [
                  _HelpExample('Chapter \\d+', 'Matches "Chapter " + any number'),
                  _HelpExample('Part \\d+', 'Matches "Part " + any number'),
                  _HelpExample('^\\d+', 'Matches numbers at start of title'),
                  _HelpExample('\\d+\\.', 'Matches numbers with a period'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Simple Text Changes',
                [
                  _HelpExample('Search: \\sThe\\s', 'Replace: " the " - Change "The" to "the" (middle only)'),
                  _HelpExample('Search: \\sAnd\\s', 'Replace: " and " - Change "And" to "and" (middle only)'),
                  _HelpExample('Search: (?<!^)\\bThe\\b(?!\$)', 'Replace: the - Change "The" to "the" (not at start/end)'),
                  _HelpExample('Search: (?<!^)\\bAnd\\b(?!\$)', 'Replace: and - Change "And" to "and" (not at start/end)'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Removing Unwanted Text',
                [
                  _HelpExample(' - Copy\$', 'Remove " - Copy" at the end'),
                  _HelpExample('^\\d+\\s*-\\s*', 'Remove "01 - " from start'),
                  _HelpExample('\\(.*?\\)', 'Remove anything in ( )'),
                  _HelpExample('\\[.*?\\]', 'Remove anything in [ ]'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Adding/Formatting',
                [
                  _HelpExample('Search: ^(\\d+)', 'Replace: Chapter \$1'),
                  _HelpExample('Search: ^', 'Replace: Part 1 - '),
                  _HelpExample('Search: \$', 'Replace:  (Unabridged)'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Cleaning Up',
                [
                  _HelpExample('\\s+ → (space)', 'Multiple spaces to one'),
                  _HelpExample('_ → (space)', 'Underscores to spaces'),
                  _HelpExample('- →  -  ', 'Add spaces around dashes'),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Use \\d for any digit (0-9)\n'
                '• Use ^ for start of text and position at start\n'
                '• Use \$ for end of text and position at end\n'
                '• Use \\s for whitespace\n'
                '• Use . for any character\n'
                '• Use * for zero or more\n'
                '• Use + for one or more\n'
                '• Use ? for zero or one\n'
                '• Use \\. \\? \\* to match literal characters\n'
                '• Use (group) and \$1 in replace for capture groups',
                style: TextStyle(fontSize: 12),
              ),
            ],
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
  
  Widget _buildHelpSection(String title, List<_HelpExample> examples) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 8),
        ...examples.map((example) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    children: [
                      TextSpan(
                        text: example.pattern,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' - '),
                      TextSpan(text: example.description),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
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
          
          String displayTitle = file.displayTitle;
          String comparisonTitle = _isPreviewingReplace && _originalReplaceValues.containsKey(index)
              ? _originalReplaceValues[index]!
              : originalTitle;
          
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
                  child: _buildTitleWithHighlights(displayTitle, comparisonTitle),
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
      int displayIndex = 0;
      int originalIndex = 0;
      
      while (displayIndex < displayTitle.length) {
        if (originalIndex < originalTitle.length &&
            displayTitle[displayIndex] == originalTitle[originalIndex]) {
          spans.add(TextSpan(
            text: displayTitle[displayIndex],
            style: const TextStyle(fontSize: 14),
          ));
          displayIndex++;
          originalIndex++;
        } else {
          final isJustCaseChange = originalIndex < originalTitle.length &&
              displayTitle[displayIndex].toLowerCase() == 
              originalTitle[originalIndex].toLowerCase();
          
          spans.add(TextSpan(
            text: displayTitle[displayIndex],
            style: TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.bold,
              backgroundColor: isJustCaseChange ? null : Colors.green.withValues(alpha: 0.2),
            ),
          ));
          displayIndex++;
          
          if (isJustCaseChange) {
            originalIndex++;
          }
        }
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
                width: 150,
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
          LinearProgressIndicator(value: _progress.isNaN ? 0.0 : _progress.clamp(0.0, 1.0)),
          const SizedBox(height: 8),
          Text(_statusMessage),
        ],
      ),
    );
  }

  void _editAudiobookMetadata() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MetadataEditorScreen(),
      ),
    );
  }
  
  Widget _buildActions() {
  return Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        // Row 1: Main actions
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
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: (_extracting || _files.isEmpty) ? null : _startEncoding,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Encode Audiobook'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
                
        // Row 2: Utility actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TranscribeScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.subtitles),
                label: const Text('Transcribe'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RepeatsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.repeat),
                label: const Text('Repeats VTT'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrimAudioScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.cut),
                label: const Text('Trim Audio Beginning/End'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        
        // Row 3: Advanced actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : _extractChapters,
                icon: const Icon(Icons.splitscreen),
                label: const Text('Extract Chapters from opus, m4b, m4a, ogg, mkv'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MetadataEditorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Audiobook Metadata'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnkiConverterScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.school),
                label: const Text('Anki Convert to Audiobook'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _extractionStatus,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
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
      final difference = _lastOriginalDuration! - _lastFinalDuration!;
      
      if (difference.inSeconds > 0) {
        parts.add('Duration ${_formatDuration(_lastFinalDuration!)}');
        parts.add('Reduced by ${_formatDuration(difference)} (silence removed or badly encoded originals)');
      } else {
        parts.add('Duration ${_formatDuration(_lastFinalDuration!)}');
      }
    }
    
    return Text(
      'Audiobook: ${parts.join(', ')}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}

class _HelpExample {
  final String pattern;
  final String description;
  
  _HelpExample(this.pattern, this.description);
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