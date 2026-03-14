import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../models/audio_file.dart';
import 'ffmpeg_service.dart';

enum DenoiseStatus { idle, running, paused, cancelled, complete, error }

enum DenoiseFileState { pending, converting, denoising, encoding, complete, error }

class DenoiseFileStatus {
  final String inputPath;
  final String filename;
  final Duration duration;
  String? outputPath;
  DenoiseFileState state;
  String statusMessage;
  DateTime? startedAt;
  DateTime? completedAt;

  DenoiseFileStatus({
    required this.inputPath,
    required this.filename,
    required this.duration,
    this.outputPath,
    this.state = DenoiseFileState.pending,
    this.statusMessage = '',
    this.startedAt,
    this.completedAt,
  });
}

class DenoiseService extends ChangeNotifier {
  static final DenoiseService _instance = DenoiseService._internal();
  factory DenoiseService() => _instance;
  DenoiseService._internal();

  final FFmpegService _ffmpeg = FFmpegService();

  DenoiseStatus status = DenoiseStatus.idle;
  List<DenoiseFileStatus> files = [];
  int currentIndex = 0;
  String currentStep = '';
  DateTime? startTime;
  String? sourceDir;
  String? outputDir;
  String errorMessage = '';

  Process? _currentProcess;
  bool _cancelRequested = false;
  bool _pauseRequested = false;

  String? previewOriginalPath;
  String? previewDenoisedPath;
  bool generatingPreview = false;
  String previewStatus = '';

  int get completedCount => files.where((f) => f.state == DenoiseFileState.complete).length;
  int get totalCount => files.length;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  Duration get estimatedRemaining {
    if (startTime == null || completedCount == 0) return Duration.zero;
    final elapsed = DateTime.now().difference(startTime!);
    final perFile = elapsed.inSeconds / completedCount;
    final remaining = (totalCount - completedCount) * perFile;
    return Duration(seconds: remaining.round());
  }

  String get deepFilterPath {
    if (Platform.isMacOS) {
      final executablePath = Platform.resolvedExecutable;
      final bundleDir = path.dirname(path.dirname(executablePath));
      return path.join(bundleDir, 'Resources', 'deepfilter', 'deep-filter');
    }
    if (Platform.isLinux) {
      return path.join(path.dirname(Platform.resolvedExecutable), 'deepfilter', 'deep-filter');
    }
    if (Platform.isWindows) {
      return path.join(path.dirname(Platform.resolvedExecutable), 'deepfilter', 'deep-filter.exe');
    }
    return 'deep-filter';
  }
  
  String get deepFilterModelPath {
    if (Platform.isMacOS) {
      final executablePath = Platform.resolvedExecutable;
      final bundleDir = path.dirname(path.dirname(executablePath));
      return path.join(bundleDir, 'Resources', 'deepfilter', 'DeepFilterNet3.tar.gz');
    }
    if (Platform.isLinux) {
      return path.join(path.dirname(Platform.resolvedExecutable), 'deepfilter', 'DeepFilterNet3.tar.gz');
    }
    if (Platform.isWindows) {
      return path.join(path.dirname(Platform.resolvedExecutable), 'deepfilter', 'DeepFilterNet3.tar.gz');
    }
    return 'DeepFilterNet3.tar.gz';
  }

  void loadFiles(List<AudioFile> audioFiles, String dir) {
    sourceDir = dir;
    outputDir = path.join(dir, 'denoised_opus');
    files = audioFiles.map((f) => DenoiseFileStatus(
      inputPath: f.path,
      filename: f.filename,
      duration: f.duration,
    )).toList();
    currentIndex = 0;
    status = DenoiseStatus.idle;
    notifyListeners();
  }

  Future<void> generatePreview(String inputPath) async {
    generatingPreview = true;
    previewStatus = 'Converting to WAV...';
    previewOriginalPath = null;
    previewDenoisedPath = null;
    notifyListeners();

    try {
      await _ffmpeg.ensureBinaries();
      final tempDir = path.join(path.dirname(inputPath), 'denoise_preview');
      await Directory(tempDir).create(recursive: true);

      final sampleWav = path.join(tempDir, 'sample_original.wav');
      final sampleClean = path.join(tempDir, 'sample_clean.wav');
      final sampleOrigOpus = path.join(tempDir, 'sample_original.opus');
      final sampleCleanOpus = path.join(tempDir, 'sample_clean.opus');

      await Process.run(_ffmpeg.ffmpegPath!, [
        '-ss', '60', '-t', '30',
        '-i', inputPath,
        '-ar', '48000', '-ac', '1',
        sampleWav, '-y',
      ]);

      previewStatus = 'Running DeepFilterNet3...';
      notifyListeners();

      await Process.run(deepFilterPath, [
        '-m', deepFilterModelPath,
        sampleWav,
        '-o', tempDir,
      ]);

      final dfOutput = path.join(tempDir, 'out', 'sample_original.wav');
      final dfOutputAlt = path.join(tempDir, 'sample_original.wav');
      
      if (await File(dfOutput).exists()) {
        await File(dfOutput).rename(sampleClean);
      } else if (await File(dfOutputAlt).exists()) {
        await File(dfOutputAlt).rename(sampleClean);
      } else {
        final contents = await Directory(tempDir).list(recursive: true).map((e) => e.path).toList();
        throw Exception('Preview deep-filter output not found. Contents: $contents');
      }

      previewStatus = 'Encoding previews...';
      notifyListeners();

      await Process.run(_ffmpeg.ffmpegPath!, [
        '-i', sampleWav, '-c:a', 'libopus',
        '-b:a', '32k', sampleOrigOpus, '-y',
      ]);
      await Process.run(_ffmpeg.ffmpegPath!, [
        '-i', sampleClean, '-c:a', 'libopus',
        '-b:a', '32k', sampleCleanOpus, '-y',
      ]);

      previewOriginalPath = sampleOrigOpus;
      previewDenoisedPath = sampleCleanOpus;
      previewStatus = 'Preview ready';
    } catch (e) {
      previewStatus = 'Preview failed: $e';
    }

    generatingPreview = false;
    notifyListeners();
  }

  Future<void> startProcessing() async {
    if (status == DenoiseStatus.running) return;
    _cancelRequested = false;
    _pauseRequested = false;
    status = DenoiseStatus.running;
    startTime ??= DateTime.now();
    await Directory(outputDir!).create(recursive: true);
    notifyListeners();
    _processNext();
  }

  Future<void> _processNext() async {
    currentIndex = files.indexWhere((f) => f.state == DenoiseFileState.pending);
    if (currentIndex == -1) {
      status = DenoiseStatus.complete;
      notifyListeners();
      return;
    }
  
    if (_cancelRequested) {
      status = DenoiseStatus.cancelled;
      notifyListeners();
      return;
    }
  
    final file = files[currentIndex];
    final baseName = path.basenameWithoutExtension(file.inputPath);
    final tempWav = path.join(outputDir!, '${baseName}_temp.wav');
    final outputOpus = path.join(outputDir!, '$baseName.opus');
  
    try {
      file.state = DenoiseFileState.converting;
      file.startedAt = DateTime.now();
      file.statusMessage = 'Converting to 48kHz WAV...';
      notifyListeners();
  
      await _ffmpeg.ensureBinaries();
      final result1 = await Process.run(_ffmpeg.ffmpegPath!, [
        '-i', file.inputPath,
        '-ar', '48000', '-ac', '1',
        tempWav, '-y',
      ]);
      if (result1.exitCode != 0) throw Exception('WAV conversion failed: ${result1.stderr}');
  
      file.state = DenoiseFileState.denoising;
      file.statusMessage = 'Denoising with DeepFilterNet3...';
      notifyListeners();
  
      _currentProcess = await Process.start(deepFilterPath, [
        '-m', deepFilterModelPath,
        tempWav,
        '-o', outputDir!,
      ]);
  
      final exitCode = await _currentProcess!.exitCode;
      _currentProcess = null;
  
      if (_cancelRequested) {
        try { await File(tempWav).delete(); } catch (_) {}
        status = DenoiseStatus.cancelled;
        notifyListeners();
        return;
      }
  
      if (exitCode != 0) throw Exception('DeepFilter failed with exit code $exitCode');
  
      final dfOutSubdir = path.join(outputDir!, 'out', '${baseName}_temp.wav');
      final dfOutDirect = path.join(outputDir!, '${baseName}_temp.wav');
      
      String? cleanWav;
      if (await File(dfOutSubdir).exists()) {
        cleanWav = path.join(outputDir!, '${baseName}_clean.wav');
        await File(dfOutSubdir).rename(cleanWav);
      } else if (await File(dfOutDirect).exists()) {
        cleanWav = dfOutDirect;
      } else {
        final contents = await Directory(outputDir!)
            .list(recursive: true)
            .map((e) => e.path)
            .toList();
        throw Exception('DeepFilter output not found. Dir contents: $contents');
      }
  
      if (cleanWav != tempWav && await File(tempWav).exists()) {
        await File(tempWav).delete();
      }
  
      file.state = DenoiseFileState.encoding;
      file.statusMessage = 'Encoding to 32kbps opus...';
      notifyListeners();
  
      _currentProcess = await Process.start(_ffmpeg.ffmpegPath!, [
        '-i', cleanWav,
        '-c:a', 'libopus',
        '-b:a', '32k',
        outputOpus, '-y',
      ]);
  
      final encodeExit = await _currentProcess!.exitCode;
      _currentProcess = null;
  
      if (encodeExit != 0) throw Exception('Opus encoding failed');
  
      await File(cleanWav).delete();
  
      file.completedAt = DateTime.now();
      file.state = DenoiseFileState.complete;
      file.outputPath = outputOpus;
      final fileDuration = file.completedAt!.difference(file.startedAt!);
      file.statusMessage = 'Done  ${_formatFileElapsed(fileDuration)}';
      notifyListeners();
  
      _processNext();
  
    } catch (e) {
      file.state = DenoiseFileState.error;
      file.statusMessage = 'Error: $e';
      notifyListeners();
      _processNext();
    }
  }

  String _formatFileElapsed(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _cleanup(String wav1, String wav2) async {
    try { await File(wav1).delete(); } catch (_) {}
    try { await File(wav2).delete(); } catch (_) {}
  }

  void pause() {
    if (status != DenoiseStatus.running) return;
    _pauseRequested = true;
    status = DenoiseStatus.paused;
    if (_currentProcess != null) {
      Process.killPid(_currentProcess!.pid, ProcessSignal.sigstop);
    }
    notifyListeners();
  }

  void resume() {
    if (status != DenoiseStatus.paused) return;
    _pauseRequested = false;
    status = DenoiseStatus.running;
    if (_currentProcess != null) {
      Process.killPid(_currentProcess!.pid, ProcessSignal.sigcont);
    }
    notifyListeners();
  }

  void cancel() {
    _cancelRequested = true;
    _pauseRequested = false;
    if (_currentProcess != null) {
      _currentProcess!.kill();
    }
    status = DenoiseStatus.cancelled;
    notifyListeners();
  }

  void reset() {
    cancel();
    files = [];
    status = DenoiseStatus.idle;
    currentIndex = 0;
    startTime = null;
    sourceDir = null;
    outputDir = null;
    previewOriginalPath = null;
    previewDenoisedPath = null;
    notifyListeners();
  }

  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}