import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:async';
import '../models/audio_file.dart';
import '../models/encoding_config.dart';
import '../services/ffmpeg_service.dart';

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
  double _progress = 0.0;
  String _statusMessage = '';
  int _completedFiles = 0;
  bool _useFilenames = true;
  List<AudioFile>? _titleCaseHistory;
  String? _lastEncodedPath;
  String? _lastEncodingTime;
  
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
    
    final totalHours = _totalDuration.inHours;
    if (totalHours >= 100) {
      _showError('Total duration exceeds 100 hours limit!\nCurrent: $totalHours hours');
      return;
    }
    
    final startTime = DateTime.now();
    
    setState(() {
      _encoding = true;
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
      final tempDir = '$outputDir/temp';
      
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
        final file = _files[i];
        final index = i;
        final displayTitle = file.displayTitle;
        final outputPath = '$tempDir/$displayTitle.opus';
        
        final future = semaphore.acquire().then((_) async {
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
                  onPressed: _encoding ? null : _pickFiles,
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
                  onPressed: _encoding ? null : _pickFolder,
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
                child: ElevatedButton.icon(
                  onPressed: (_encoding || _files.isEmpty) ? null : _startEncoding,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Encode Audiobook'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
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