import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

enum EncodeMode { encodeVideo, sliceVideo, encodeAudio, sliceAudio }
enum VideoCodec { x264, x265, videotoolbox, nvenc, amf, qsv }
enum AudioCodec { opus, aac, mp3, copy }
enum CombineMode { none, encoded, sliced }

class EncodeSettings {
  final EncodeMode mode;
  final VideoCodec codec;
  final int resolution;
  final int crf;
  final String container;
  final AudioCodec audioCodec;
  final String audioBitrate;
  final bool removeSilence;
  final bool removeHiss;
  final CombineMode combine;
  final bool chaptersMetadata;
  final int? fps;

  const EncodeSettings({
    this.mode = EncodeMode.encodeVideo,
    this.codec = VideoCodec.x265,
    this.resolution = 720,
    this.crf = 28,
    this.container = 'mp4',
    this.audioCodec = AudioCodec.opus,
    this.audioBitrate = '32k',
    this.removeSilence = false,
    this.removeHiss = false,
    this.combine = CombineMode.none,
    this.chaptersMetadata = false,
    this.fps,
  });
}

class StitchProgress {
  final double percent;
  final Duration elapsed;
  final Duration encodedSoFar;
  final Duration totalDuration;
  final int currentFrame;
  final int totalFrames;
  final String step;

  const StitchProgress({
    required this.percent,
    required this.elapsed,
    required this.encodedSoFar,
    required this.totalDuration,
    required this.currentFrame,
    required this.totalFrames,
    required this.step,
  });
}

class VideoEditService {
  static String? _systemFfmpegPath;
  static String? _systemFfprobePath;

  static Future<String?> findSystemFfmpeg() async {
    if (_systemFfmpegPath != null) return _systemFfmpegPath;
    final candidates = Platform.isWindows
        ? ['ffmpeg.exe', r'C:\Program Files\ffmpeg\bin\ffmpeg.exe']
        : ['/opt/homebrew/bin/ffmpeg', '/usr/local/bin/ffmpeg', '/usr/bin/ffmpeg', 'ffmpeg'];
    for (final c in candidates) {
      try {
        final r = await Process.run(c, ['-version']);
        if (r.exitCode == 0) { _systemFfmpegPath = c; return c; }
      } catch (_) {}
    }
    return null;
  }

  static Future<String?> _findFfprobe() async {
    if (_systemFfprobePath != null) return _systemFfprobePath;
    final candidates = Platform.isWindows
        ? ['ffprobe.exe', r'C:\Program Files\ffmpeg\bin\ffprobe.exe']
        : ['/opt/homebrew/bin/ffprobe', '/usr/local/bin/ffprobe', '/usr/bin/ffprobe', 'ffprobe'];
    for (final c in candidates) {
      try {
        final r = await Process.run(c, ['-version']);
        if (r.exitCode == 0) { _systemFfprobePath = c; return c; }
      } catch (_) {}
    }
    return null;
  }

  static Future<bool> isAvailable() async => await findSystemFfmpeg() != null;

  static Future<double?> getFileDuration(String filePath) async {
    final ffprobe = await _findFfprobe();
    if (ffprobe == null) return null;
    final r = await Process.run(ffprobe, [
      '-v', 'quiet', '-of', 'csv=p=0',
      '-show_entries', 'format=duration', filePath,
    ]);
    if (r.exitCode == 0) return double.tryParse((r.stdout as String).trim());
    return null;
  }

  static Future<bool> _fileHasAudio(String filePath) async {
    final ffprobe = await _findFfprobe();
    if (ffprobe == null) return false;
    final r = await Process.run(ffprobe, [
      '-v', 'quiet', '-select_streams', 'a',
      '-show_entries', 'stream=codec_type', '-of', 'csv=p=0', filePath,
    ]);
    return r.exitCode == 0 && (r.stdout as String).contains('audio');
  }

  static bool _fileExists(String filePath) {
    try { return File(filePath).existsSync(); } catch (_) { return false; }
  }

  static List<String> _videoCodecArgs(EncodeSettings s) {
    final bitrates = {720: '5M', 1080: '8M', 1440: '15M', 2160: '25M'};
    final vbr = bitrates[s.resolution] ?? '5M';
    switch (s.codec) {
      case VideoCodec.x264:
        return ['-c:v', 'libx264', '-preset', 'fast', '-crf', '${s.crf}'];
      case VideoCodec.x265:
        return ['-c:v', 'libx265', '-preset', 'fast', '-crf', '${s.crf}'];
      case VideoCodec.videotoolbox:
        return ['-c:v', 'h264_videotoolbox', '-b:v', vbr];
      case VideoCodec.nvenc:
        return ['-c:v', 'h264_nvenc', '-preset', 'fast', '-crf', '${s.crf}'];
      case VideoCodec.amf:
        return ['-c:v', 'h264_amf', '-quality', 'quality', '-qp', '${s.crf}'];
      case VideoCodec.qsv:
        return ['-c:v', 'h264_qsv', '-preset', 'fast', '-global_quality', '${s.crf}'];
    }
  }

  static List<String> _audioCodecArgs(EncodeSettings s) {
    switch (s.audioCodec) {
      case AudioCodec.opus:
        final app = s.audioBitrate == '16k' ? 'voip' : 'audio';
        return ['-c:a', 'libopus', '-application', app, '-b:a', s.audioBitrate];
      case AudioCodec.aac:
        return ['-c:a', 'aac', '-b:a', s.audioBitrate];
      case AudioCodec.mp3:
        return ['-c:a', 'libmp3lame', '-b:a', s.audioBitrate];
      case AudioCodec.copy:
        return ['-c:a', 'copy'];
    }
  }

  static List<String> _audioFilterArgs(EncodeSettings s, bool isAudioMode) {
    final filters = <String>[];
    if (isAudioMode) {
      if (s.removeSilence) {
        filters.add(
            'silenceremove=start_periods=0:stop_periods=-1'
            ':start_threshold=-34dB:stop_threshold=-34dB'
            ':start_silence=1:start_duration=0:stop_duration=1:detection=rms');
      }
      if (s.removeHiss && s.audioCodec != AudioCodec.copy) {
        filters.add('highpass=200,lowpass=3000,afftdn=nf=-25');
      }
      if (s.removeSilence || (s.removeHiss && s.audioCodec != AudioCodec.copy)) {
        filters.add('dynaudnorm=f=250:g=31:p=0.5:m=5:r=0.9:b=1');
      }
    } else if (s.removeHiss && s.audioCodec != AudioCodec.copy) {
      filters
        ..add('highpass=200,lowpass=3000,afftdn=nf=-25')
        ..add('dynaudnorm=f=250:g=31:p=0.5:m=5:r=0.9:b=1');
    }
    if (filters.isEmpty) return [];
    return ['-af', filters.join(',')];
  }

  static Stream<StitchProgress> _monitorProgress({
    required File progressFile,
    required double totalDuration,
    required int totalFrames,
    required DateTime startTime,
    required String step,
  }) async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 1));
      if (!progressFile.existsSync()) break;
      try {
        final lines = progressFile.readAsLinesSync();
        double encTime = 0;
        int frame = 0;
        for (int i = lines.length - 1; i >= 0; i--) {
          final line = lines[i];
          if (encTime == 0) {
            final m = RegExp(r'^out_time_us=(\d+)').firstMatch(line);
            if (m != null) encTime = int.parse(m.group(1)!) / 1e6;
          }
          if (frame == 0) {
            final m = RegExp(r'^frame=(\d+)').firstMatch(line);
            if (m != null) frame = int.parse(m.group(1)!);
          }
          if (encTime > 0 && frame > 0) break;
        }
        double pct = 0;
        if (totalDuration > 0 && encTime > 0) {
          pct = (encTime / totalDuration * 100).clamp(0, 100);
        } else if (totalFrames > 0 && frame > 0) {
          pct = (frame / totalFrames * 100).clamp(0, 100);
        }
        final elapsed = DateTime.now().difference(startTime);
        yield StitchProgress(
          percent: pct,
          elapsed: elapsed,
          encodedSoFar: Duration(milliseconds: (encTime * 1000).round()),
          totalDuration: Duration(milliseconds: (totalDuration * 1000).round()),
          currentFrame: frame,
          totalFrames: totalFrames,
          step: step,
        );
        if (lines.any((l) => l.startsWith('progress=end'))) break;
      } catch (_) {}
    }
  }

  static Stream<StitchProgress> stitchAndEncode({
    required List<String> segmentFiles,
    required String outputPath,
    required EncodeSettings settings,
    void Function(Process)? onProcessStarted,
  }) async* {
    final ffmpeg = await findSystemFfmpeg();
    if (ffmpeg == null) throw Exception('System ffmpeg not found');

    final workDir = path.dirname(segmentFiles.first);
    final isAudioMode = settings.mode == EncodeMode.encodeAudio ||
        settings.mode == EncodeMode.sliceAudio;

    final listFile = File(path.join(workDir, '_stitch_list.txt'));
    await listFile.writeAsString(
        segmentFiles.map((f) => "file '$f'").join('\n'));

    yield StitchProgress(
      percent: 0,
      elapsed: Duration.zero,
      encodedSoFar: Duration.zero,
      totalDuration: Duration.zero,
      currentFrame: 0,
      totalFrames: 0,
      step: 'Step 1/2: Creating temp file…',
    );

    final ext = path.extension(segmentFiles.first);
    final tempConcat = File(path.join(
        workDir, '_temp_concat${DateTime.now().millisecondsSinceEpoch}$ext'));

    final concatResult = await Process.run(ffmpeg, [
      '-y', '-f', 'concat', '-safe', '0',
      '-i', listFile.path,
      '-c', 'copy',
      tempConcat.path,
    ], workingDirectory: workDir);

    if (concatResult.exitCode != 0) {
      throw Exception('Concat step failed: ${concatResult.stderr}');
    }

    final totalDuration = await getFileDuration(tempConcat.path) ?? 0.0;
    final hasAudio = await _fileHasAudio(tempConcat.path);
    final totalFrames = (totalDuration * 30.0).round();

    final progressFile = File('${tempConcat.path}.progress');

    final encodeArgs = <String>[
      '-y',
      '-i', tempConcat.path,
      '-progress', progressFile.path,
      '-nostdin',
    ];

    if (isAudioMode) {
      encodeArgs.addAll(['-vn', '-sn', ..._audioCodecArgs(settings)]);
      encodeArgs.addAll(['-map', '0:a']);
    } else {
      encodeArgs.addAll([
        ..._videoCodecArgs(settings),
        ..._audioCodecArgs(settings),
        '-vf', 'scale=-2:${settings.resolution}',
        if (settings.fps != null) ...[ '-r', '${settings.fps}' ],
        '-map', '0:v',
      ]);
      if (hasAudio) encodeArgs.addAll(['-map', '0:a']);
    }

    encodeArgs.addAll(_audioFilterArgs(settings, isAudioMode));
    encodeArgs.addAll(['-map_metadata', '0', '-movflags', 'use_metadata_tags']);
    encodeArgs.add(outputPath);

    final startTime = DateTime.now();
    final process = await Process.start(ffmpeg, encodeArgs);
    onProcessStarted?.call(process);

    await for (final progress in _monitorProgress(
      progressFile: progressFile,
      totalDuration: totalDuration,
      totalFrames: totalFrames,
      startTime: startTime,
      step: 'Step 2/2: Encoding…',
    )) {
      yield progress;
    }

    final exitCode = await process.exitCode;

    try { await tempConcat.delete(); } catch (_) {}
    try { await progressFile.delete(); } catch (_) {}

    if (exitCode != 0) {
      final stderr = await process.stderr
          .transform(const SystemEncoding().decoder).join();
      throw Exception('Encode failed (exit $exitCode): $stderr');
    }

    yield StitchProgress(
      percent: 100,
      elapsed: DateTime.now().difference(startTime),
      encodedSoFar: Duration(milliseconds: (totalDuration * 1000).round()),
      totalDuration: Duration(milliseconds: (totalDuration * 1000).round()),
      currentFrame: totalFrames,
      totalFrames: totalFrames,
      step: 'Done: ${path.basename(outputPath)}',
    );
  }

  static Future<void> cutVideo({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration end,
    required VideoCodec cutCodec,
    String? lutPath,
    required Function(String) onProgress,
  }) async {
    final ffmpeg = await findSystemFfmpeg();
    if (ffmpeg == null) throw Exception('System ffmpeg not found');
  
    final startSecs = start.inMilliseconds / 1000.0;
    final duration = (end - start).inMilliseconds / 1000.0;
  
    String? resolvedLutPath;
    if (lutPath != null) {
      final bytes = await rootBundle.load(lutPath);
      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(lutPath);
      final tempFile = File(path.join(tempDir.path, fileName));
      await tempFile.writeAsBytes(bytes.buffer.asUint8List());
      resolvedLutPath = tempFile.path;
    }
  
    final args = <String>[
      '-y',
      '-ss', startSecs.toStringAsFixed(3),
      '-i', inputPath,
      '-t', duration.toStringAsFixed(3),
    ];
  
    if (resolvedLutPath != null) {
      args.addAll(['-vf', 'lut3d=${resolvedLutPath}']);
    }
  
    switch (cutCodec) {
      case VideoCodec.videotoolbox:
        args.addAll(['-c:v', 'h264_videotoolbox', '-b:v', '8M', '-c:a', 'copy']);
      case VideoCodec.nvenc:
        args.addAll(['-c:v', 'h264_nvenc', '-preset', 'fast', '-c:a', 'copy']);
      case VideoCodec.amf:
        args.addAll(['-c:v', 'h264_amf', '-quality', 'quality', '-c:a', 'copy']);
      case VideoCodec.qsv:
        args.addAll(['-c:v', 'h264_qsv', '-preset', 'fast', '-c:a', 'copy']);
      default:
        throw Exception('Unsupported cut encoder: $cutCodec. Use a hardware encoder.');
    }
  
    args.addAll(['-avoid_negative_ts', 'make_zero', '-movflags', '+faststart', outputPath]);
  
    final lutLabel = lutPath != null ? ' + LUT' : '';
    onProgress('Cutting with ${_codecName(cutCodec)}$lutLabel...');
  
    final result = await Process.run(ffmpeg, args);
  
    print('cutVideo stderr: ${result.stderr}');
  
    if (result.exitCode != 0) {
      throw Exception('Cut failed (exit ${result.exitCode}):\n${(result.stderr as String).split('\n').take(10).join('\n')}');
    }
  
    final outputFile = File(outputPath);
    if (!outputFile.existsSync()) {
      throw Exception('Output file was not created: ${path.basename(outputPath)}');
    }
  
    final fileSize = await outputFile.length();
    if (fileSize < 1000) {
      throw Exception('Output file too small ($fileSize bytes)');
    }
  
    onProgress('Cut complete: ${path.basename(outputPath)}');
  }

  static Future<void> combineCuts({
    required List<String> cutFiles,
    required String outputPath,
    required VideoCodec codec,
    required int resolution,
    required Function(String) onProgress,
  }) async {
    final ffmpeg = await findSystemFfmpeg();
    if (ffmpeg == null) throw Exception('System ffmpeg not found');

    final workDir = path.dirname(cutFiles.first);
    final listFile = File(path.join(workDir, '_concat_list.txt'));

    final listContent = cutFiles.map((f) {
      if (!File(f).existsSync()) throw Exception('Cut file not found: ${path.basename(f)}');
      return "file '$f'";
    }).join('\n');

    await listFile.writeAsString(listContent);

    print('Concat list content:');
    print(listContent);

    onProgress('Combining ${cutFiles.length} cuts → ${resolution}p with ${_codecName(codec)}...');

    final args = [
      '-y', '-f', 'concat', '-safe', '0',
      '-i', listFile.path,
      ..._getCodecArgs(codec),
      '-vf', 'scale=-2:$resolution',
      outputPath,
    ];

    print('FFmpeg command: $ffmpeg ${args.join(' ')}');

    final result = await Process.run(ffmpeg, args, workingDirectory: workDir);

    print('ffmpeg stderr: ${result.stderr}');
    print('ffmpeg stdout: ${result.stdout}');

    if (result.exitCode != 0) {
      throw Exception('Combine failed (exit ${result.exitCode}):\n${(result.stderr as String).split('\n').take(10).join('\n')}');
    }

    onProgress('Done: ${path.basename(outputPath)}');
  }

  static String _codecName(VideoCodec codec) {
    switch (codec) {
      case VideoCodec.x264: return 'x264';
      case VideoCodec.x265: return 'x265';
      case VideoCodec.videotoolbox: return 'VideoToolbox';
      case VideoCodec.nvenc: return 'NVENC';
      case VideoCodec.amf: return 'AMF';
      case VideoCodec.qsv: return 'QuickSync';
    }
  }

  static List<String> _getCodecArgs(VideoCodec codec) {
    switch (codec) {
      case VideoCodec.x264:
        return ['-c:v', 'libx264', '-preset', 'fast', '-crf', '25', '-c:a', 'copy'];
      case VideoCodec.x265:
        return ['-c:v', 'libx265', '-preset', 'fast', '-crf', '25', '-c:a', 'copy'];
      case VideoCodec.videotoolbox:
        return ['-c:v', 'h264_videotoolbox', '-b:v', '15M', '-c:a', 'copy'];
      case VideoCodec.nvenc:
        return ['-c:v', 'h264_nvenc', '-preset', 'medium', '-crf', '23', '-c:a', 'copy'];
      case VideoCodec.amf:
        return ['-c:v', 'h264_amf', '-quality', 'quality', '-qp', '23', '-c:a', 'copy'];
      case VideoCodec.qsv:
        return ['-c:v', 'h264_qsv', '-preset', 'medium', '-global_quality', '23', '-c:a', 'copy'];
    }
  }

  static Future<({String? resolution, double? fps})> getVideoInfo(String filePath) async {
    final ffprobe = await _findFfprobe();
    if (ffprobe == null) return (resolution: null, fps: null);
  
    final r = await Process.run(ffprobe, [
      '-v', 'quiet',
      '-select_streams', 'v:0',
      '-show_entries', 'stream=width,height,r_frame_rate',
      '-of', 'csv=p=0',
      filePath,
    ]);
  
    if (r.exitCode != 0) return (resolution: null, fps: null);
  
    final parts = (r.stdout as String).trim().split(',');
    if (parts.length < 3) return (resolution: null, fps: null);
  
    final width = parts[0].trim();
    final height = parts[1].trim();
    final fpsRaw = parts[2].trim();
  
    double? fps;
    if (fpsRaw.contains('/')) {
      final fpsParts = fpsRaw.split('/');
      final num = double.tryParse(fpsParts[0]);
      final den = double.tryParse(fpsParts[1]);
      if (num != null && den != null && den != 0) fps = num / den;
    } else {
      fps = double.tryParse(fpsRaw);
    }
  
    return (
      resolution: '${width}x${height}',
      fps: fps,
    );
  }

  static String getCutsDirectory(String videoPath) {
    final dir = path.dirname(videoPath);
    final name = path.basenameWithoutExtension(videoPath);
    return path.join(dir, '${name}_cuts');
  }

  static bool isVideoFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    return ['.mkv', '.mp4', '.webm', '.mov', '.avi', '.m4v'].contains(ext);
  }

  static String outputExtension(EncodeSettings s, String inputPath) {
    final isAudioMode = s.mode == EncodeMode.encodeAudio ||
        s.mode == EncodeMode.sliceAudio;
    if (isAudioMode) {
      return {
            AudioCodec.opus: '.opus',
            AudioCodec.aac: '.m4a',
            AudioCodec.mp3: '.mp3',
            AudioCodec.copy: path.extension(inputPath),
          }[s.audioCodec] ?? '.opus';
    }
    if (s.mode == EncodeMode.sliceVideo) return path.extension(inputPath);
    return '.${s.container}';
  }
}