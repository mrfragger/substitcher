import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../services/denoise_service.dart';
import '../services/ffmpeg_service.dart';
import '../models/audio_file.dart';

class DenoiseScreen extends StatefulWidget {
  const DenoiseScreen({super.key});

  @override
  State<DenoiseScreen> createState() => _DenoiseScreenState();
}

class _DenoiseScreenState extends State<DenoiseScreen> {
  final DenoiseService _service = DenoiseService();
  final FFmpegService _ffmpeg = FFmpegService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    final audioFiles = await _ffmpeg.listAudioFilesInDirectory(result);
    if (audioFiles.isEmpty) {
      _showError('No audio files found in selected folder');
      return;
    }

    _service.loadFiles(audioFiles, result);
  }

  String _formatDuration(Duration d) => _service.formatDuration(d);

  Duration get _totalDuration => _service.files.fold(
        Duration.zero, (sum, f) => sum + f.duration);

  String get _estimatedTime {
    final totalMins = _totalDuration.inMinutes;
    final denoiseMins = (totalMins / 16).ceil();
    return '~${denoiseMins}m denoising + encoding time';
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeepFilterNet3 Denoise'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.deepPurple.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.deepPurple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI noise removal using DeepFilterNet3 — removes music, '
                    'background noise, hiss. Processes at ~22x realtime on Mac M1. '
                    '33 hours of audio would take about ~90 minutes to process. '
                    'Output: 32kbps opus files ready for SubStitcher encoder for an audiobook.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple.shade200,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _service.files.isEmpty
                ? _buildEmptyState()
                : _buildMainContent(),
          ),
          _buildBottomActions(),
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
          const Text('Select a folder of audio files to denoise',
              style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          const Text(
            'Supports mp3, wav, m4a, opus, flac, ogg and more',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Folder'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_service.files.length} files — '
                    '${_formatDuration(_totalDuration)} total'),
                Text(
                  _estimatedTime,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (_service.status != DenoiseStatus.idle) _buildProgressPanel(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _service.files.length,
            itemBuilder: (context, index) {
              final file = _service.files[index];
              return ListTile(
                dense: true,
                leading: _buildFileStateIcon(file.state),
                title: Text(file.filename,
                    style: const TextStyle(fontSize: 13)),
                subtitle: SelectableText(
                  file.statusMessage,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
                trailing: Text(_formatDuration(file.duration),
                    style: const TextStyle(fontSize: 12, color: Colors.white54)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFileStateIcon(DenoiseFileState state) {
    switch (state) {
      case DenoiseFileState.pending:
        return const Icon(Icons.hourglass_empty, color: Colors.white38, size: 20);
      case DenoiseFileState.converting:
        return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue));
      case DenoiseFileState.denoising:
        return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple));
      case DenoiseFileState.encoding:
        return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange));
      case DenoiseFileState.complete:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case DenoiseFileState.error:
        return const Icon(Icons.error, color: Colors.red, size: 20);
    }
  }

  Widget _buildProgressPanel() {
    final elapsed = _service.startTime != null
        ? DateTime.now().difference(_service.startTime!)
        : Duration.zero;
  
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_service.completedCount}/${_service.totalCount} files',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                _service.status == DenoiseStatus.paused
                    ? '⏸ Paused'
                    : _service.status == DenoiseStatus.complete
                        ? '✓ Complete'
                        : _service.status == DenoiseStatus.cancelled
                            ? '✕ Cancelled'
                            : 'Processing...',
                style: TextStyle(
                  color: _service.status == DenoiseStatus.paused
                      ? Colors.orange
                      : _service.status == DenoiseStatus.complete
                          ? Colors.green
                          : Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _service.progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Elapsed: ${_formatDuration(elapsed)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              if (_service.status == DenoiseStatus.running)
                Text(
                  'Remaining: ~${_formatDuration(_service.estimatedRemaining)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              if (_service.status == DenoiseStatus.complete && elapsed.inSeconds > 0)
                Text(
                  'Realtime Speed: ${(_totalDuration.inSeconds / elapsed.inSeconds).toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          if (_service.status == DenoiseStatus.complete &&
              _service.outputDir != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Completed in ${_formatDuration(elapsed)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.folder, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          'Output: ${_service.outputDir}',
                          style: const TextStyle(color: Colors.green, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final hasFiles = _service.files.isNotEmpty;
    final isRunning = _service.status == DenoiseStatus.running;
    final isPaused = _service.status == DenoiseStatus.paused;
    final isIdle = _service.status == DenoiseStatus.idle;
    final isComplete = _service.status == DenoiseStatus.complete;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: (isRunning || isPaused) ? null : _pickFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Folder'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16)),
          ),
          const Spacer(),
          if (isRunning) ...[
            ElevatedButton.icon(
              onPressed: _service.pause,
              icon: const Icon(Icons.pause),
              label: const Text('Pause'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _service.cancel,
              icon: const Icon(Icons.stop),
              label: const Text('Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ] else if (isPaused) ...[
            ElevatedButton.icon(
              onPressed: _service.resume,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _service.cancel,
              icon: const Icon(Icons.stop),
              label: const Text('Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ] else if (hasFiles && (isIdle || isComplete)) ...[
            if (isComplete) ...[
              ElevatedButton.icon(
                onPressed: _service.reset,
                icon: const Icon(Icons.refresh),
                label: const Text('New Batch'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16)),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton.icon(
              onPressed: isComplete ? null : _service.startProcessing,
              icon: const Icon(Icons.play_arrow),
              label: Text(isComplete ? 'Complete ✓' : 'Start Denoising'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ],
      ),
    );
  }
}