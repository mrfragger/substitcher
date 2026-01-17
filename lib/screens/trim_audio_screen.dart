import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../services/ffmpeg_service.dart';
import '../models/audio_file.dart';
import 'package:media_kit/media_kit.dart';

class TrimAudioScreen extends StatefulWidget {
  const TrimAudioScreen({super.key});

  @override
  State<TrimAudioScreen> createState() => _TrimAudioScreenState();
}

class _TrimAudioScreenState extends State<TrimAudioScreen> {
  final FFmpegService _ffmpegService = FFmpegService();
  final ScrollController _scrollController = ScrollController();
  
  List<AudioFile> _files = [];
  bool _loading = false;
  bool _trimming = false;
  bool _previewing = false;
  String _statusMessage = '';
  double _progress = 0.0;
  int _completedFiles = 0;
  
  final _trimBeginController = TextEditingController(text: '0:00');
  final _trimEndController = TextEditingController(text: '0:00');
  
  List<String> _previewFiles = [];
  bool _hasPreview = false;
  
  final Map<int, Player> _players = {};
  final Map<int, bool> _isPlaying = {};
  final Map<int, Duration> _currentPositions = {};
  final Map<int, Duration> _durations = {};

  @override
  void dispose() {
    _scrollController.dispose();
    _trimBeginController.dispose();
    _trimEndController.dispose();
    for (final player in _players.values) {
      player.dispose();
    }
    super.dispose();
  }

  int _parseTimeToSeconds(String time) {
    if (time.isEmpty || time == '0:00') return 0;
    
    final parts = time.split(':');
    if (parts.length == 1) {
      return int.tryParse(parts[0]) ?? 0;
    } else if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return (minutes * 60) + seconds;
    }
    return 0;
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'opus', 'ogg', 'flac', 'wav', 'wma', 'mp4', 'mkv'],
      );
      
      if (result == null) return;
      
      setState(() => _loading = true);
      
      final audioFiles = <AudioFile>[];
      for (final file in result.files) {
        if (file.path == null) continue;
        
        try {
          final info = await _ffmpegService.getAudioInfo(file.path!);
          audioFiles.add(info);
        } catch (e) {
          print('Error loading ${file.name}: $e');
        }
      }
      
      audioFiles.sort((a, b) => a.path.compareTo(b.path));
      
      setState(() {
        _files = audioFiles;
        _loading = false;
        _hasPreview = false;
      });
      
      _cleanupPreview();
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
      
      final audioFiles = await _ffmpegService.listAudioFilesInDirectory(result);
      
      setState(() {
        _files = audioFiles;
        _loading = false;
        _hasPreview = false;
      });
      
      _cleanupPreview();
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error loading folder: $e');
    }
  }

  void _cleanupPreview() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
    _isPlaying.clear();
    _currentPositions.clear();
    _durations.clear();
    _previewFiles.clear();
  }

  Future<void> _generatePreview() async {
    if (_files.isEmpty) {
      _showError('No files selected');
      return;
    }
    
    final trimBeginSecs = _parseTimeToSeconds(_trimBeginController.text);
    final trimEndSecs = _parseTimeToSeconds(_trimEndController.text);
    
    if (trimBeginSecs == 0 && trimEndSecs == 0) {
      _showError('Please specify trim duration for beginning or end');
      return;
    }
    
    _cleanupPreview();
    
    setState(() {
      _previewing = true;
      _statusMessage = 'Generating preview for first 6 files...';
      _progress = 0.0;
    });
    
    try {
      final previewCount = _files.length < 6 ? _files.length : 6;
      final previewFiles = <String>[];
      
      final firstFilePath = _files[0].path;
      final sourceDir = path.dirname(firstFilePath);
      final previewDir = path.join(sourceDir, 'trim_preview');
      
      final dir = Directory(previewDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);
      
      for (int i = 0; i < previewCount; i++) {
        final file = _files[i];
        final outputPath = '$previewDir/${path.basename(file.path)}';
        
        setState(() {
          _statusMessage = 'Trimming preview ${i + 1}/$previewCount: ${path.basename(file.path)}';
          _progress = (i + 1) / previewCount;
        });
        
        await _trimFile(
          inputPath: file.path,
          outputPath: outputPath,
          trimBeginSecs: trimBeginSecs,
          trimEndSecs: trimEndSecs,
        );
        
        previewFiles.add(outputPath);
        
        final player = Player();
        _players[i] = player;
        _isPlaying[i] = false;
        _currentPositions[i] = Duration.zero;
        _durations[i] = Duration.zero;
        
        player.stream.duration.listen((duration) {
          if (mounted) {
            setState(() {
              _durations[i] = duration;
            });
          }
        });
        
        player.stream.position.listen((position) {
          if (mounted) {
            setState(() {
              _currentPositions[i] = position;
            });
          }
        });
        
        player.stream.playing.listen((playing) {
          if (mounted) {
            setState(() {
              _isPlaying[i] = playing;
            });
          }
        });
        
        player.stream.completed.listen((completed) {
          if (completed && mounted) {
            setState(() {
              _isPlaying[i] = false;
            });
          }
        });
        
        await player.open(Media(outputPath), play: false);
      }
      
      setState(() {
        _previewing = false;
        _previewFiles = previewFiles;
        _hasPreview = true;
        _statusMessage = 'Preview generated! Listen to trimmed files below';
      });
      
      _showSuccess('Preview files created successfully');
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
      
    } catch (e) {
      setState(() {
        _previewing = false;
        _statusMessage = 'Error: $e';
      });
      _showError('Preview failed: $e');
    }
  }

  Future<void> _playPausePreview(int index) async {
    final player = _players[index];
    if (player == null) return;
    
    if (_isPlaying[index] == true) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _seekToPosition(int index, Duration position) async {
    final player = _players[index];
    if (player == null) return;
    
    await player.seek(position);
  }

  Future<void> _trimFile({
    required String inputPath,
    required String outputPath,
    required int trimBeginSecs,
    required int trimEndSecs,
  }) async {
    final duration = await _ffmpegService.getAudioDuration(inputPath);
    final totalDurationSecs = duration.inSeconds;
    final outputDurationSecs = totalDurationSecs - trimBeginSecs - trimEndSecs;
    
    if (outputDurationSecs <= 0) {
      throw Exception('Trim duration exceeds file duration');
    }
    
    await _ffmpegService.trimAudioPrecise(
      inputPath: inputPath,
      outputPath: outputPath,
      startSeconds: trimBeginSecs.toDouble(),
      durationSeconds: outputDurationSecs.toDouble(),
    );
  }

  Future<void> _startTrimming() async {
    if (_files.isEmpty) {
      _showError('No files selected');
      return;
    }
    
    final trimBeginSecs = _parseTimeToSeconds(_trimBeginController.text);
    final trimEndSecs = _parseTimeToSeconds(_trimEndController.text);
    
    if (trimBeginSecs == 0 && trimEndSecs == 0) {
      _showError('Please specify trim duration for beginning or end');
      return;
    }
    
    final startTime = DateTime.now();
    
    setState(() {
      _trimming = true;
      _progress = 0.0;
      _completedFiles = 0;
      _statusMessage = 'Starting trim process...';
    });
    
    try {
      final firstFilePath = _files[0].path;
      final sourceDir = path.dirname(firstFilePath);
      
      final now = DateTime.now();
      final timestamp = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';
      
      final outputDir = path.join(sourceDir, 'trimmed_$timestamp');
      
      await Directory(outputDir).create(recursive: true);
      
      for (int i = 0; i < _files.length; i++) {
        final file = _files[i];
        final outputPath = '$outputDir/${path.basename(file.path)}';
        
        setState(() {
          _statusMessage = 'Trimming ${i + 1}/${_files.length}: ${path.basename(file.path)}';
          _progress = (i + 1) / _files.length;
        });
        
        await _trimFile(
          inputPath: file.path,
          outputPath: outputPath,
          trimBeginSecs: trimBeginSecs,
          trimEndSecs: trimEndSecs,
        );
        
        setState(() {
          _completedFiles++;
        });
      }
      
      setState(() {
        _trimming = false;
        _statusMessage = 'Complete! Trimmed files: $outputDir';
      });
      
      final elapsed = DateTime.now().difference(startTime);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds.remainder(60);
      
      _showSuccess('Trimming completed in ${minutes}m ${seconds}s!');
      
    } catch (e) {
      setState(() {
        _trimming = false;
        _statusMessage = 'Error: $e';
      });
      _showError('Trimming failed: $e');
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

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Trim Audio'),
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Trim Audio Files',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Batch trim beginning and/or end of audio files',
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
                          _buildTrimSettingsSection(),
                          const SizedBox(height: 24),
                          
                          if (_files.isNotEmpty) ...[
                            _buildFileListSection(),
                            const SizedBox(height: 24),
                          ],
                          
                          if (_hasPreview) ...[
                            _buildPreviewSection(),
                            const SizedBox(height: 24),
                          ],
                          
                          if (_trimming || _previewing) ...[
                            _buildProgressSection(),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildTrimSettingsSection() {
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
              const Icon(Icons.cut, color: Colors.deepPurple, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Trim Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter time in format M:SS (e.g., 0:13 for 13 seconds, 1:22 for 1 min 22 sec)\nKeep at 0:00 to not trim beginning or end',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trim from Beginning',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _trimBeginController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: const OutlineInputBorder(),
                        hintText: '0:00',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _hasPreview = false;
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
                      'Trim from End',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _trimEndController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        border: const OutlineInputBorder(),
                        hintText: '0:00',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _hasPreview = false;
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

  Widget _buildFileListSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.audiotrack, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_files.length} files selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'Total: ${_formatDuration(_files.fold(Duration.zero, (sum, file) => sum + file.duration))}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _files.length,
              itemBuilder: (context, index) {
                final file = _files[index];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    radius: 16,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  title: Text(
                    path.basename(file.path),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  trailing: Text(
                    file.formattedDuration,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Preview Generated',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Preview files created for first ${_previewFiles.length} files - Listen below to verify trim results',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ...List.generate(_previewFiles.length, (index) {
            return _buildPreviewPlayer(index);
          }),
        ],
      ),
    );
  }

  Widget _buildPreviewPlayer(int index) {
    final duration = _durations[index] ?? Duration.zero;
    final position = _currentPositions[index] ?? Duration.zero;
    final isPlaying = _isPlaying[index] ?? false;
    final fileName = path.basename(_previewFiles[index]);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepPurple,
                radius: 14,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.deepPurple,
                  size: 40,
                ),
                onPressed: () => _playPausePreview(index),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: duration.inMilliseconds > 0
                        ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                        : 0,
                    max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1,
                    activeColor: Colors.deepPurple,
                    inactiveColor: Colors.white24,
                    onChanged: (value) {
                      _seekToPosition(index, Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
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
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canPreview = _files.isNotEmpty && !_trimming && !_previewing;
    final canTrim = _files.isNotEmpty && !_trimming && !_previewing;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_trimming || _previewing) ? null : _pickFiles,
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
                onPressed: (_trimming || _previewing) ? null : _pickFolder,
                icon: const Icon(Icons.folder),
                label: const Text('Add Folder'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canPreview ? _generatePreview : null,
                icon: const Icon(Icons.preview),
                label: const Text('Generate Preview (first 6)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  disabledBackgroundColor: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canTrim ? _startTrimming : null,
                icon: const Icon(Icons.cut),
                label: const Text('Trim All Files'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                  disabledBackgroundColor: Colors.grey[800],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.bottomRight,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}