import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'whisper_bundled.dart'; 
import 'dart:math' show min;

class WhisperService {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal();

  String? whisperExecutablePath;
  String? modelDirectory;
  String? _ffmpegPath;
  String? _ffprobePath;
  String language = 'Auto';
  String selectedModel = 'large-v3-turbo';
  String segmentTime = '0:30';
  int maxLength = 80;
  bool splitOnWord = true;
  bool translateToEnglish = false;

Process? _currentWhisperProcess;
bool _shouldCancelTranscription = false;
  
  int msOffset = 0;
  bool printColors = false;
  bool useGPU = true;
  String customPrompt = "The example of those who disbelieve is like that of one who shouts at what hears nothing but calls and cries i.e., cattle or sheep - deaf, dumb and blind, so they do not understand.";
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      whisperExecutablePath = await WhisperBundled.getWhisperExecutablePath();
      await prefs.setString('whisperExecutablePath', whisperExecutablePath!);
      print('Using bundled whisper: $whisperExecutablePath');
    } catch (e) {
      print('Could not find bundled whisper: $e');
      whisperExecutablePath = prefs.getString('whisperExecutablePath');
    }
    
    modelDirectory = prefs.getString('whisperModelDirectory');
    language = prefs.getString('whisperLanguage') ?? 'auto';
    selectedModel = prefs.getString('whisperModel') ?? 'large-v3-turbo';
    maxLength = prefs.getInt('whisperMaxLength') ?? 80;
    segmentTime = prefs.getString('whisperSegmentTime') ?? '0:30';
        
    printColors = prefs.getBool('whisperPrintColors') ?? false;
    splitOnWord = prefs.getBool('whisperSplitOnWord') ?? true;
    customPrompt = prefs.getString('whisperPrompt') ?? customPrompt;
    translateToEnglish = prefs.getBool('whisperTranslate') ?? false;
  }

  Future<void> cancelTranscription() async {
     _shouldCancelTranscription = true;
     if (_currentWhisperProcess != null) {
       print('Killing whisper process...');
       _currentWhisperProcess!.kill();
       _currentWhisperProcess = null;
     }
   }

  Future<void> _ensureFFmpeg() async {
    if (_ffmpegPath != null) return;
    
    if (Platform.isMacOS) {
      final executablePath = Platform.resolvedExecutable;
      final bundleDir = path.dirname(path.dirname(executablePath));
      final resourcesDir = path.join(bundleDir, 'Resources', 'bin');
      
      final bundledFfmpeg = path.join(resourcesDir, 'ffmpeg');
      final bundledFfprobe = path.join(resourcesDir, 'ffprobe');
      
      if (File(bundledFfmpeg).existsSync() && File(bundledFfprobe).existsSync()) {
        _ffmpegPath = bundledFfmpeg;
        _ffprobePath = bundledFfprobe;
        print('WhisperService using bundled ffmpeg: $_ffmpegPath');
        return;
      }
    } else if (Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      final executableDir = path.dirname(executablePath);
      final binDir = path.join(executableDir, 'bin');
      
      final bundledFfmpeg = path.join(binDir, 'ffmpeg.exe');
      final bundledFfprobe = path.join(binDir, 'ffprobe.exe');
      
      if (File(bundledFfmpeg).existsSync() && File(bundledFfprobe).existsSync()) {
        _ffmpegPath = bundledFfmpeg;
        _ffprobePath = bundledFfprobe;
        print('WhisperService using bundled ffmpeg: $_ffmpegPath');
        return;
      }
    } else if (Platform.isLinux) {
      final executablePath = Platform.resolvedExecutable;
      final executableDir = path.dirname(executablePath);
      final binDir = path.join(executableDir, 'bin');
      
      final bundledFfmpeg = path.join(binDir, 'ffmpeg');
      final bundledFfprobe = path.join(binDir, 'ffprobe');
      
      if (File(bundledFfmpeg).existsSync() && File(bundledFfprobe).existsSync()) {
        _ffmpegPath = bundledFfmpeg;
        _ffprobePath = bundledFfprobe;
        print('WhisperService using bundled ffmpeg: $_ffmpegPath');
        return;
      }
    } else if (Platform.isAndroid) {
      final appLibDir = '/data/data/com.example.substitcher/lib';
      _ffmpegPath = '$appLibDir/libffmpeg.so';
      _ffprobePath = '$appLibDir/libffprobe.so';
      print('WhisperService using Android ffmpeg: $_ffmpegPath');
      return;
    }
    
    _ffmpegPath = 'ffmpeg';
    _ffprobePath = 'ffprobe';
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (whisperExecutablePath != null) {
      await prefs.setString('whisperExecutablePath', whisperExecutablePath!);
    }
    if (modelDirectory != null) {
      await prefs.setString('whisperModelDirectory', modelDirectory!);
    }
    await prefs.setString('whisperLanguage', language);
    await prefs.setString('whisperModel', selectedModel);
    await prefs.setInt('whisperMaxLength', maxLength);
    await prefs.setString('whisperSegmentTime', segmentTime);
    await prefs.setBool('whisperPrintColors', printColors);
    await prefs.setBool('whisperSplitOnWord', splitOnWord);
    await prefs.setString('whisperPrompt', customPrompt);
    await prefs.setBool('whisperTranslate', translateToEnglish);
  }
      
  Future<void> setWhisperExecutable(String path) async {
    whisperExecutablePath = path;
    await saveSettings();
  }
  
  Future<void> setModelDirectory(String path) async {
    modelDirectory = path;
    await saveSettings();
  }
  
  List<String> getAvailableModels() {
    if (modelDirectory == null) return [];
    
    final dir = Directory(modelDirectory!);
    if (!dir.existsSync()) return [];
    
    final models = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.bin')) {
        final filename = path.basenameWithoutExtension(entity.path);
        if (filename.startsWith('ggml-')) {
          models.add(filename.replaceFirst('ggml-', ''));
        }
      }
    }
    return models;
  }

  Future<Map<String, dynamic>> _prepareWhisperExecutable({
    required String whisperExecutablePath,
  }) async {
    // If we're not on Linux or the whisper-cli isn't inside an AppImage mount
    // just return the original path with no extra env vars.
    if (!Platform.isLinux ||
        (!whisperExecutablePath.contains('/tmp/.mount_') &&
        !whisperExecutablePath.contains('/tmp/appimage'))) {
      return {
        'path': whisperExecutablePath,
        'env': <String, String>{},
      };
    }
  
    print('Detected Linux AppImage mount; copying whisper-cli and libraries to temp...');
  
    // Locate original file + its directory
    final origFile = File(whisperExecutablePath);
    if (!await origFile.exists()) {
      throw Exception('whisper-cli not found at $whisperExecutablePath');
    }
    final origDir = origFile.parent;
  
    // Create a fresh temp directory
    final tempDir = await Directory.systemTemp.createTemp('whisper_');
    final tempExePath = path.join(tempDir.path, 'whisper-cli');
  
    // Copy the binary and make it executable
    await origFile.copy(tempExePath);
    await Process.run('chmod', ['+x', tempExePath]);
  
    // Find and copy all .so files
    final copiedSoFiles = <String>[];
    await for (final entity in origDir.list()) {
      if (entity is File) {
        final base = path.basename(entity.path);
        if (base.endsWith('.so') || base.contains('.so.')) {
          print('Copying library $base');
          final dest = path.join(tempDir.path, base);
          await entity.copy(dest);
          copiedSoFiles.add(dest);
        }
      }
    }
  
    // Pick out the two libraries we care about for LD_PRELOAD
    final libGgml = copiedSoFiles.firstWhere(
      (s) => path.basename(s).startsWith('libggml') && !path.basename(s).contains('-'),
      orElse: () => throw Exception('libggml.so not found'),
    );
    final libWhisper = copiedSoFiles.firstWhere(
      (s) => path.basename(s) == 'libwhisper.so' || path.basename(s).startsWith('libwhisper.so.'),
      orElse: () => throw Exception('libwhisper.so not found'),
    );
  
    print('Found libggml: $libGgml');
    print('Found libwhisper: $libWhisper');
  
    // Write the wrapper script - properly escape the variables
    final wrapperPath = path.join(tempDir.path, 'whisper-wrapper.sh');
    final wrapperScript = '''#!/usr/bin/env bash
  export LD_LIBRARY_PATH="${tempDir.path}:\$LD_LIBRARY_PATH"
  export LD_PRELOAD="$libGgml:$libWhisper:\$LD_PRELOAD"
  exec "$tempExePath" "\$@"
  ''';
    
    await File(wrapperPath).writeAsString(wrapperScript);
    await Process.run('chmod', ['+x', wrapperPath]);
  
    print('Created wrapper script at $wrapperPath');
    print('Wrapper contents:');
    print(wrapperScript);
  
    // Return the wrapper as the new executable plus empty env (vars are in the script)
    return {
      'path': wrapperPath,
      'env': <String, String>{},
    };
  }
  
  Future<void> transcribeChapters(
    String chaptersDirectory,
    Function(String status, double progress, Duration cumulativeDuration) onProgress,
    Function(String error) onError,
  ) async {
    _shouldCancelTranscription = false;
    if (whisperExecutablePath == null || modelDirectory == null) {
      onError('Whisper executable or model directory not set');
      return;
    }
    
    if (!File(whisperExecutablePath!).existsSync()) {
      onError('Whisper executable not found at: $whisperExecutablePath');
      return;
    }
    
    final modelPath = path.join(modelDirectory!, 'ggml-$selectedModel.bin');
    if (!File(modelPath).existsSync()) {
      onError('Model not found: $modelPath');
      return;
    }
    
    try {
      final chaptersDir = Directory(chaptersDirectory);
      if (!chaptersDir.existsSync()) {
        onError('Chapters directory not found: $chaptersDirectory');
        return;
      }
      
      final opusFiles = chaptersDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.opus'))
          .cast<File>()
          .toList();
      
      if (opusFiles.isEmpty) {
        onError('No .opus files found in directory');
        return;
      }
      
      opusFiles.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
      
      final skippedChapters = <String>[];
      final remainingFiles = <File>[];
      
      for (final opusFile in opusFiles) {
        final chapterName = path.basenameWithoutExtension(opusFile.path);
        final vttPath = path.join(chaptersDirectory, '$chapterName.vtt');
        if (File(vttPath).existsSync()) {
          skippedChapters.add(chapterName);
        } else {
          remainingFiles.add(opusFile);
        }
      }
      
      if (skippedChapters.isNotEmpty) {
        onProgress('Skipped ${skippedChapters.length} already transcribed chapters', 0.0, Duration.zero);
        await Future.delayed(const Duration(seconds: 1));
      }
      
      if (remainingFiles.isEmpty) {
        onProgress('All chapters already transcribed!', 1.0, Duration.zero);
        return;
      }
      
      final tempWorkDir = Directory(path.join(chaptersDirectory, 'temp_transcribe'));
      
      final totalChapters = opusFiles.length;
      final chapterVttFiles = <String>[];
      
      Duration cumulativeChapterDuration = Duration.zero;
      DateTime? sessionStartTime;
      
      for (int i = 0; i < remainingFiles.length; i++) {
        if (_shouldCancelTranscription) {
          onProgress('Transcription cancelled', 0.0, Duration.zero);
          return;
        }
        
        if (sessionStartTime == null) {
          sessionStartTime = DateTime.now();
        }
        
        final chapterStart = DateTime.now();
        final opusFile = remainingFiles[i];
        final chapterName = path.basenameWithoutExtension(opusFile.path);
        final actualChapterNumber = opusFiles.indexOf(opusFile) + 1;
        
        if (tempWorkDir.existsSync()) {
          tempWorkDir.deleteSync(recursive: true);
        }
        tempWorkDir.createSync(recursive: true);
        
        onProgress(
          'Processing chapter $actualChapterNumber/$totalChapters: $chapterName',
          (actualChapterNumber - 1) / totalChapters,
          cumulativeChapterDuration,
        );
        
        final chapterVttPath = await _transcribeChapter(
          opusFile.path,
          tempWorkDir.path,
          modelPath,
          (segmentStatus, segmentProgress) {
            final overallProgress = (actualChapterNumber - 1 + segmentProgress) / totalChapters;
            onProgress(segmentStatus, overallProgress, cumulativeChapterDuration);
          },
          onError,
        );
        
        if (chapterVttPath != null) {
          final finalChapterVtt = path.join(chaptersDirectory, '$chapterName.vtt');
          await File(chapterVttPath).copy(finalChapterVtt);
          chapterVttFiles.add(finalChapterVtt);
        }
        
        final chapterDurationSeconds = await _getOpusDuration(opusFile.path);
        cumulativeChapterDuration += Duration(seconds: chapterDurationSeconds.toInt());
        
        final chapterElapsed = DateTime.now().difference(chapterStart);
        final totalElapsedSeconds = DateTime.now().difference(sessionStartTime).inSeconds;
        
        final chapterTime = _formatElapsed(chapterElapsed.inSeconds);
        final totalTime = _formatElapsed(totalElapsedSeconds);
        
        final speedMultiplier = cumulativeChapterDuration.inSeconds > 0 && totalElapsedSeconds > 0
            ? (cumulativeChapterDuration.inSeconds / totalElapsedSeconds)
            : 0.0;
        final speedText = speedMultiplier > 0 ? ' (${speedMultiplier.toStringAsFixed(1)}x realtime speed)' : '';
        
        onProgress(
          'Chapter $actualChapterNumber/$totalChapters complete: $chapterName ($chapterTime | Total: $totalTime$speedText)',
          actualChapterNumber / totalChapters,
          cumulativeChapterDuration,
        );
      }
      
      final allChapterVtts = <String>[];
      for (final opusFile in opusFiles) {
        final chapterName = path.basenameWithoutExtension(opusFile.path);
        final vttPath = path.join(chaptersDirectory, '$chapterName.vtt');
        if (File(vttPath).existsSync()) {
          allChapterVtts.add(vttPath);
        }
      }
      
      if (allChapterVtts.length > 1) {
        onProgress('Merging ${allChapterVtts.length} chapter VTT files...', 0.95, cumulativeChapterDuration);
        await mergeChapterVttFiles(
          allChapterVtts, 
          chaptersDirectory,
          opusFiles.map((f) => f.path).toList(),
        );
      }
      
      if (tempWorkDir.existsSync()) {
        tempWorkDir.deleteSync(recursive: true);
      }
      
      onProgress('Transcription complete!', 1.0, cumulativeChapterDuration);
      
    } catch (e) {
      onError('Transcription error: $e');
    }
  }
  
  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
  
  Future<String?> _transcribeChapter(
    String opusFilePath,
    String workingDirectory,
    String modelPath,
    Function(String status, double progress) onProgress,
    Function(String error) onError,
  ) async {
    final chapterName = path.basenameWithoutExtension(opusFilePath);
    final logFile = File(path.join(workingDirectory, 'chapter_debug.log'));
    
    try {
      await logFile.writeAsString('=== START ${DateTime.now()} ===\n');
      await logFile.writeAsString('Chapter: $chapterName\n', mode: FileMode.append);
      await logFile.writeAsString('Working dir: $workingDirectory\n', mode: FileMode.append);
      
      onProgress('Splitting into $segmentTime segments...', 0.1);
      await logFile.writeAsString('Step 1: Splitting...\n', mode: FileMode.append);
      await _splitIntoSegments(opusFilePath, workingDirectory);
      await logFile.writeAsString('Step 1: Done\n', mode: FileMode.append);
      
      onProgress('Converting segments to WAV...', 0.2);
      await logFile.writeAsString('Step 2: Converting to WAV...\n', mode: FileMode.append);
      final wavFiles = await _convertToWav(workingDirectory);
      await logFile.writeAsString('Step 2: Done, ${wavFiles.length} WAV files\n', mode: FileMode.append);
      
      if (wavFiles.isEmpty) {
        onError('No WAV files created');
        return null;
      }
      
      onProgress('Transcribing ${wavFiles.length} segments...', 0.3);
      await logFile.writeAsString('Step 3: Running whisper...\n', mode: FileMode.append);
      await _runWhisper(wavFiles, modelPath, workingDirectory);
      await logFile.writeAsString('Step 3: Done\n', mode: FileMode.append);
      
      onProgress('Organizing VTT files...', 0.7);
      await logFile.writeAsString('Step 4: Organizing VTT...\n', mode: FileMode.append);
      await _organizeVttFiles(workingDirectory);
      await logFile.writeAsString('Step 4: Done\n', mode: FileMode.append);
      
      onProgress('Stitching VTT segments...', 0.8);
      await logFile.writeAsString('Step 5: Stitching...\n', mode: FileMode.append);
      final stitchedVttPath = await _stitchVttFilesForChapter(opusFilePath, workingDirectory);
      await logFile.writeAsString('Step 5: Done\n', mode: FileMode.append);
      
      onProgress('Chapter complete: $chapterName', 1.0);
      await logFile.writeAsString('=== COMPLETE ===\n', mode: FileMode.append);
      
      return stitchedVttPath;
      
    } catch (e, stackTrace) {
      await logFile.writeAsString('EXCEPTION: $e\n$stackTrace\n', mode: FileMode.append);
      onError('Error transcribing chapter: $e');
      return null;
    }
  }
  
  Future<void> _splitIntoSegments(String opusFilePath, String workingDir) async {
    await _ensureFFmpeg();
    
    final duration = await _getOpusDuration(opusFilePath);
    
    int segmentSecs = 30;
    if (segmentTime.contains(':')) {
      final parts = segmentTime.split(':');
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = int.tryParse(parts[1]) ?? 30;
      segmentSecs = minutes * 60 + seconds;
    } else {
      segmentSecs = int.tryParse(segmentTime) ?? 30;
    }
    
    final numSegments = (duration / segmentSecs).ceil();
    
    for (int i = 0; i < numSegments; i++) {
      final startTime = i * segmentSecs;
      final segmentDuration = (startTime + segmentSecs > duration) 
          ? duration - startTime 
          : segmentSecs.toDouble();
      
      final outputPath = path.join(workingDir, '${i.toString().padLeft(4, '0')}.opus');
      
      final result = await Process.run(
        _ffmpegPath!,
        [
          '-hide_banner',
          '-ss', startTime.toString(),
          '-i', opusFilePath,
          '-t', segmentDuration.toString(),
          '-c', 'copy',
          '-y',
          outputPath,
        ],
      );
      
      if (result.exitCode != 0) {
        throw Exception('FFmpeg segment $i failed: ${result.stderr}');
      }
    }
  }

  Future<String> testWhisperExecutable() async {
    if (whisperExecutablePath == null) {
      return 'ERROR: whisperExecutablePath is null';
    }
    
    final whisperFile = File(whisperExecutablePath!);
    if (!whisperFile.existsSync()) {
      return 'ERROR: whisper-cli does not exist at $whisperExecutablePath';
    }
    
    final whisperDir = whisperFile.parent.path;
    final buffer = StringBuffer();
    buffer.writeln('Platform: ${Platform.operatingSystem}');
    buffer.writeln('Whisper path: $whisperExecutablePath');
    buffer.writeln('Whisper dir: $whisperDir');
    
    if (Platform.isMacOS) {
      final dylibs = Directory(whisperDir)
          .listSync()
          .where((e) => e.path.endsWith('.dylib'))
          .map((e) => path.basename(e.path))
          .toList();
      buffer.writeln('Found dylibs: $dylibs');
      
      final statResult = await Process.run('ls', ['-la', whisperExecutablePath!]);
      buffer.writeln('File permissions: ${statResult.stdout}');
      
      final xattrResult = await Process.run('xattr', ['-l', whisperExecutablePath!]);
      buffer.writeln('Extended attributes: ${xattrResult.stdout}');
      if (xattrResult.stdout.toString().contains('quarantine')) {
        buffer.writeln('WARNING: Quarantine flag is set!');
      }
      
      final codesignResult = await Process.run('codesign', ['-dv', whisperExecutablePath!]);
      buffer.writeln('Code signing: ${codesignResult.stderr}');
      
    } else if (Platform.isLinux) {
      final soFiles = Directory(whisperDir)
          .listSync()
          .where((e) => path.basename(e.path).contains('.so'))
          .map((e) => path.basename(e.path))
          .toList();
      buffer.writeln('Found .so files: $soFiles');
      
      final statResult = await Process.run('ls', ['-la', whisperExecutablePath!]);
      buffer.writeln('File permissions: ${statResult.stdout}');
      
      final lddResult = await Process.run('ldd', [whisperExecutablePath!]);
      buffer.writeln('Library dependencies:\n${lddResult.stdout}');
      
      buffer.writeln('\n=== CPU COMPATIBILITY CHECK ===');
      try {
        final cpuInfo = await File('/proc/cpuinfo').readAsString();
        final flagsLine = cpuInfo.split('\n').firstWhere(
          (line) => line.startsWith('flags'),
          orElse: () => 'flags: not found'
        );
        
        final hasAVX = flagsLine.contains(' avx ');
        final hasAVX2 = flagsLine.contains(' avx2 ');
        
        buffer.writeln('AVX support: ${hasAVX ? "YES ✓" : "NO ✗"}');
        buffer.writeln('AVX2 support: ${hasAVX2 ? "YES ✓" : "NO ✗"}');
        
        if (!hasAVX) {
          buffer.writeln('\n  CPU COMPATIBILITY WARNING ');
          buffer.writeln('Your CPU does not support AVX instructions (introduced ~2011-2013).');
          buffer.writeln('The bundled whisper-cli binary requires AVX support.');
          buffer.writeln('You are using very old hardware (pre-2014).');
          buffer.writeln('\nIf whisper fails with exit code -4 (SIGILL), you will need to:');
          buffer.writeln('1. Compile whisper.cpp yourself without AVX:');
          buffer.writeln('   cmake -DGGML_AVX=OFF -DGGML_AVX2=OFF -DGGML_FMA=OFF ..');
          buffer.writeln('2. Point SubStitcher to your custom build');
        }
      } catch (e) {
        buffer.writeln('Could not read CPU info: $e');
      }
      
      buffer.writeln('\n=== BINARY INFO ===');
      final fileResult = await Process.run('file', [whisperExecutablePath!]);
      buffer.writeln('Binary type: ${fileResult.stdout}');
      
    } else if (Platform.isWindows) {
      final dllFiles = Directory(whisperDir)
          .listSync()
          .where((e) => e.path.endsWith('.dll'))
          .map((e) => path.basename(e.path))
          .toList();
      buffer.writeln('Found DLLs: $dllFiles');
    }
    
    try {
      final environment = <String, String>{};
      
      if (Platform.isMacOS) {
        environment['DYLD_LIBRARY_PATH'] = whisperDir;
        environment['DYLD_FALLBACK_LIBRARY_PATH'] = whisperDir;
        buffer.writeln('\n=== TESTING ===');
        buffer.writeln('Testing with environment: $environment');
      } else if (Platform.isLinux) {
        environment['LD_LIBRARY_PATH'] = whisperDir;
        buffer.writeln('\n=== TESTING ===');
        buffer.writeln('Testing with environment: $environment');
      }
      
      final testResult = await Process.run(
        whisperExecutablePath!,
        ['--help'],
        environment: environment,
      ).timeout(const Duration(seconds: 5));
      
      buffer.writeln('\nTest result:');
      buffer.writeln('Exit code: ${testResult.exitCode}');
      
      if (testResult.exitCode == -4) {
        buffer.writeln('\n FATAL ERROR: Exit code -4 (SIGILL - Illegal Instruction)');
        buffer.writeln('Your CPU does not support the instructions required by this binary.');
        buffer.writeln('This confirms your CPU lacks AVX support.');
        buffer.writeln('\nYou must compile whisper.cpp without AVX for your old CPU.');
      } else if (testResult.exitCode == 0) {
        buffer.writeln('SUCCESS! Whisper executable is working.');
        buffer.writeln('Stdout: ${testResult.stdout.toString().substring(0, min(500, testResult.stdout.toString().length))}');
      } else {
        buffer.writeln('Stdout: ${testResult.stdout.toString().substring(0, min(500, testResult.stdout.toString().length))}');
        buffer.writeln('Stderr: ${testResult.stderr}');
      }
    } catch (e) {
      buffer.writeln('\nEXCEPTION running whisper: $e');
    }
    
    return buffer.toString();
  }
  
  Future<List<String>> _convertToWav(String workingDir) async {
    await _ensureFFmpeg();
    final dir = Directory(workingDir);
    final opusSegments = dir
        .listSync()
        .where((e) => e is File && path.basename(e.path).startsWith(RegExp(r'^\d{4}\.opus$')))
        .cast<File>()
        .toList();
    
    opusSegments.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
    
    final wavFiles = <String>[];
    
    for (final opusFile in opusSegments) {
      final basename = path.basenameWithoutExtension(opusFile.path);
      final wavPath = path.join(workingDir, 'temp_$basename.wav');
      
      final result = await Process.run(
        _ffmpegPath!,
        [
          '-hide_banner',
          '-i', opusFile.path,
          '-f', 'wav',
          '-ar', '16000',
          '-ac', '1',
          wavPath,
        ],
      );
      
      if (result.exitCode == 0) {
        wavFiles.add(wavPath);
      }
    }
    
    return wavFiles;
  }
  
  Future<void> _runWhisper(
    List<String> wavFiles,
    String modelPath,
    String workingDir,
  ) async {
    final whisperInfo = await _prepareWhisperExecutable(
      whisperExecutablePath: whisperExecutablePath!,
    );
    final actualWhisperPath = whisperInfo['path'] as String;
    final environment = whisperInfo['env'] as Map<String, String>;
    
    final args = <String>[
      '-m', modelPath,
      ...wavFiles,
      '-ovtt',
      '-t', '8',
      '-l', language,
    ];
    
    if (translateToEnglish && selectedModel != 'large-v3-turbo') {
      args.add('-tr');
    }
    
    args.addAll(['-ml', maxLength.toString()]);
    
    if (splitOnWord) {
      args.add('-sow');
    }
    
    if (printColors) {
      args.add('-pc');
    }
    
    args.addAll(['--prompt', customPrompt]);
    
    final logFile = File('${workingDir}/whisper_debug.log');
    final logBuffer = StringBuffer();
    logBuffer.writeln('=== WHISPER RUN ${DateTime.now()} ===');
    logBuffer.writeln('Executable: $actualWhisperPath');
    logBuffer.writeln('Environment: $environment');
    logBuffer.writeln('Working dir: $workingDir');
    logBuffer.writeln('Model: $modelPath');
    logBuffer.writeln('WAV count: ${wavFiles.length}');
    logBuffer.writeln('Args: $args');
    await logFile.writeAsString(logBuffer.toString());
    
    try {
      _currentWhisperProcess = await Process.start(
        actualWhisperPath,
        args,
        workingDirectory: workingDir,
        environment: environment,
      );
      
      final stdout = StringBuffer();
      final stderr = StringBuffer();
      
      _currentWhisperProcess!.stdout.transform(utf8.decoder).listen((data) {
        stdout.write(data);
      });
      
      _currentWhisperProcess!.stderr.transform(utf8.decoder).listen((data) {
        stderr.write(data);
      });
      
      final exitCode = await _currentWhisperProcess!.exitCode;
      
      await logFile.writeAsString(
        'Exit code: $exitCode\nStdout: ${stdout.toString()}\nStderr: ${stderr.toString()}\n',
        mode: FileMode.append,
      );
      
      if (_shouldCancelTranscription) {
        _currentWhisperProcess = null;
        throw Exception('Transcription cancelled by user');
      }
      
      if (exitCode != 0) {
        _currentWhisperProcess = null;
        throw Exception('Whisper failed (exit $exitCode): ${stderr.toString()}');
      }
      
      _currentWhisperProcess = null;
    } catch (e, stackTrace) {
      _currentWhisperProcess = null;
      await logFile.writeAsString(
        'EXCEPTION: $e\nStack: $stackTrace\n',
        mode: FileMode.append,
      );
      rethrow;
    }
  }
  
  Future<void> _organizeVttFiles(String workingDir) async {
    final vttSubsDir = Directory(path.join(workingDir, 'vttsubs'));
    if (!vttSubsDir.existsSync()) {
      vttSubsDir.createSync();
    }
    
    final dir = Directory(workingDir);
    final vttFiles = dir
        .listSync()
        .where((e) => e is File && e.path.endsWith('.vtt'))
        .cast<File>()
        .toList();
    
    vttFiles.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
    
    int counter = 0;
    for (final vttFile in vttFiles) {
      final newName = '${counter.toString().padLeft(4, '0')}.vtt';
      final newPath = path.join(vttSubsDir.path, newName);
      await vttFile.rename(newPath);
      counter++;
    }
  }
  
  Future<String> _stitchVttFilesForChapter(String originalOpusPath, String workingDir) async {
    final vttSubsDir = Directory(path.join(workingDir, 'vttsubs'));
    
    final opusSegments = Directory(workingDir)
        .listSync()
        .where((e) => e is File && RegExp(r'^\d{4}\.opus$').hasMatch(path.basename(e.path)))
        .cast<File>()
        .toList();
    
    opusSegments.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
  
    double tsum = 0.0;
    final shiftedVttFiles = <String>[];
  
    final firstVtt = path.join(vttSubsDir.path, '0000.vtt');
    if (File(firstVtt).existsSync()) {
      shiftedVttFiles.add(firstVtt);
    }
  
    for (int i = 0; i < opusSegments.length; i++) {
      final current = i.toString().padLeft(4, '0');
      final next = (i + 1).toString().padLeft(4, '0');
      final currentOpus = path.join(workingDir, '$current.opus');
      final nextVtt = path.join(vttSubsDir.path, '$next.vtt');
  
      if (File(currentOpus).existsSync()) {
        final duration = await _getOpusDuration(currentOpus);
        tsum = tsum + duration;
  
        if (File(nextVtt).existsSync()) {
          final shiftedPath = path.join(workingDir, '$next.vtt');
          await _vttShift(nextVtt, tsum, shiftedPath);
          shiftedVttFiles.add(shiftedPath);
        }
      }
    }
  
    final stitchedTemp1 = path.join(workingDir, 'stitchedsubstemp1.vtt');
    final stitchedFile = File(stitchedTemp1);
    if (stitchedFile.existsSync()) {
      await stitchedFile.delete();
    }
  
    for (final vttPath in shiftedVttFiles) {
      if (File(vttPath).existsSync()) {
        final content = await File(vttPath).readAsString();
        final cleaned = content
            .replaceAll('WEBVTT', '')
            .replaceAll(RegExp(r'\n\n+'), '\n\n');
        await stitchedFile.writeAsString(cleaned, mode: FileMode.append);
      }
    }
  
    final stitchedTemp4 = path.join(workingDir, 'stitchedsubstemp4.vtt');
    await _addHourToTimecodes(stitchedTemp1, stitchedTemp4);
  
    final stitchedTemp2 = path.join(workingDir, 'stitchedsubstemp2.vtt');
    await _addWebvttHeader(stitchedTemp4, stitchedTemp2);
  
    final chapterName = path.basenameWithoutExtension(originalOpusPath);
    final finalVtt = path.join(workingDir, '$chapterName.vtt');
    await File(stitchedTemp2).copy(finalVtt);
  
    return finalVtt;
  }
  
  Future<void> mergeChapterVttFiles(List<String> chapterVttFiles, String outputDir, List<String> originalOpusFiles) async {
    if (chapterVttFiles.isEmpty) return;
    
    final parentDir = Directory(outputDir).parent.path;
    final opusAudiobook = Directory(parentDir)
        .listSync()
        .where((e) => e is File && e.path.endsWith('.opus'))
        .cast<File>()
        .firstOrNull;
    
    String baseFilename = 'audiobook_complete';
    String outputPath = parentDir;
    
    if (opusAudiobook != null) {
      baseFilename = path.basenameWithoutExtension(opusAudiobook.path);
      outputPath = path.dirname(opusAudiobook.path);
    }
    
    final mergedVttOriginal = path.join(outputDir, '${baseFilename}_original_overlaps.vtt');
    final output = StringBuffer();
    output.writeln('WEBVTT');
    output.writeln();
    
    double cumulativeTime = 0.0;
    
    for (int i = 0; i < chapterVttFiles.length; i++) {
      final vttFile = chapterVttFiles[i];
      final content = await File(vttFile).readAsLines();
      bool inCue = false;
      
      for (final line in content) {
        if (line.trim() == 'WEBVTT') continue;
        
        if (line.contains('-->')) {
          if (inCue) {
            output.writeln();
          }
          final parts = line.split('-->');
          if (parts.length == 2) {
            final start = _shiftTimecode(parts[0].trim(), cumulativeTime);
            final end = _shiftTimecode(parts[1].trim(), cumulativeTime);
            output.writeln('$start --> $end');
            inCue = true;
          }
        } else if (line.trim().isNotEmpty) {
          output.writeln(line);
        } else if (inCue) {
          output.writeln();
          inCue = false;
        }
      }
      
      if (inCue) {
        output.writeln();
      }
      
      final chapterDuration = await _getOpusDuration(originalOpusFiles[i]);
      cumulativeTime += chapterDuration - (msOffset / 1000.0);
    }
    
    await File(mergedVttOriginal).writeAsString(output.toString());
    
    final finalVtt = path.join(outputPath, '$baseFilename.vtt');
    await _fixOverlappingTimecodes(mergedVttOriginal, finalVtt);
  }

  Future<double> _getOpusDuration(String opusPath) async {
    await _ensureFFmpeg();
    
    final result = await Process.run(_ffprobePath!, [
      '-show_entries',
      'format=duration',
      '-v',
      'quiet',
      '-of',
      'csv=p=0',
      opusPath,
    ]);
  
    if (result.exitCode == 0) {
      final durationStr = result.stdout.toString().trim();
      return double.tryParse(durationStr) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _vttShift(String inputPath, double shiftSeconds, String outputPath) async {
    final content = await File(inputPath).readAsLines();
    final output = StringBuffer();
  
    for (final line in content) {
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final startShifted = _shiftTimecode(parts[0].trim(), shiftSeconds);
          final endShifted = _shiftTimecode(parts[1].trim().split(' ')[0], shiftSeconds);
          output.writeln('$startShifted --> $endShifted');
        }
      } else {
        output.writeln(line);
      }
    }
  
    await File(outputPath).writeAsString(output.toString());
  }

  String _shiftTimecode(String timecode, double shiftSeconds) {
    final parts = timecode.split(':');
    if (parts.length != 3) return timecode;

    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final sParts = parts[2].split('.');
    final s = int.tryParse(sParts[0]) ?? 0;
    final ms = sParts.length > 1 ? int.tryParse(sParts[1]) ?? 0 : 0;

    double totalSeconds = h * 3600.0 + m * 60.0 + s + ms / 1000.0;
    totalSeconds += shiftSeconds;

    final newH = (totalSeconds / 3600).floor();
    totalSeconds -= newH * 3600;
    final newM = (totalSeconds / 60).floor();
    totalSeconds -= newM * 60;
    final newS = totalSeconds.floor();
    final newMs = ((totalSeconds - newS) * 1000).round();

    return '${newH.toString().padLeft(2, '0')}:${newM.toString().padLeft(2, '0')}:${newS.toString().padLeft(2, '0')}.${newMs.toString().padLeft(3, '0')}';
  }

  Future<void> _addHourToTimecodes(String inputPath, String outputPath) async {
    final content = await File(inputPath).readAsString();
    final pattern = RegExp(r'(^[0-9]{2}:[0-9]{2}\.[0-9]{3} --> )([0-9]{2}:[0-9]{2}\.[0-9]{3})', multiLine: true);
    final modified = content.replaceAllMapped(pattern, (match) {
      return '00:${match.group(1)}00:${match.group(2)}';
    });
    await File(outputPath).writeAsString(modified);
  }

  int _timecodeToMilliseconds(String timecode) {
    final parts = timecode.split(':');
    if (parts.length != 3) return 0;
  
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final sParts = parts[2].split('.');
    final s = int.tryParse(sParts[0]) ?? 0;
    final ms = sParts.length > 1 ? int.tryParse(sParts[1]) ?? 0 : 0;
  
    return (h * 3600 + m * 60 + s) * 1000 + ms;
  }
  
  String _millisecondsToTimecode(int ms) {
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    final s = (ms % 60000) ~/ 1000;
    final msRemainder = ms % 1000;
    
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${msRemainder.toString().padLeft(3, '0')}';
  }

  Future<void> _fixOverlappingTimecodes(String inputPath, String outputPath) async {
    final content = await File(inputPath).readAsString();
    final blocks = content.split('\n\n').where((b) => b.trim().isNotEmpty).toList();
    
    final List<Map<String, dynamic>> subtitleBlocks = [];
    
    for (final block in blocks) {
      if (block.trim() == 'WEBVTT') continue;
      
      final lines = block.split('\n');
      String? timeLine;
      final textLines = <String>[];
  
      for (final line in lines) {
        if (line.contains('-->')) {
          timeLine = line;
        } else if (line.trim().isNotEmpty) {
          textLines.add(line);
        }
      }
  
      if (timeLine != null && textLines.isNotEmpty) {
        final parts = timeLine.split('-->');
        if (parts.length == 2) {
          final startTime = parts[0].trim();
          final endTime = parts[1].trim();
          
          int startMs = _timecodeToMilliseconds(startTime);
          int endMs = _timecodeToMilliseconds(endTime);
          
          if (endMs < startMs) {
            startMs = endMs;
          }
          
          subtitleBlocks.add({
            'startMs': startMs,
            'endMs': endMs,
            'text': textLines,
          });
        }
      }
    }
    
    for (int i = 0; i < subtitleBlocks.length - 1; i++) {
      final current = subtitleBlocks[i];
      final next = subtitleBlocks[i + 1];
      
      final currentEnd = current['endMs'] as int;
      final nextStart = next['startMs'] as int;
      
      if (nextStart < currentEnd) {
        current['endMs'] = nextStart;
      } else if (nextStart > currentEnd) {
        current['endMs'] = nextStart;
      }
    }
    
    final output = StringBuffer();
    output.writeln('WEBVTT'); 
    output.writeln();   
    
    for (final block in subtitleBlocks) {
      final startMs = block['startMs'] as int;
      final endMs = block['endMs'] as int;
      final text = block['text'] as List<String>;
      
      output.writeln('${_millisecondsToTimecode(startMs)} --> ${_millisecondsToTimecode(endMs)}');
      for (final line in text) {
        output.writeln(line);
      }
      output.writeln();
    }
  
    await File(outputPath).writeAsString(output.toString());
  }

  Future<void> _addWebvttHeader(String inputPath, String outputPath) async {
    final content = await File(inputPath).readAsString();
    final output = StringBuffer();
    output.writeln('WEBVTT');
    output.writeln();
    output.write(content);
    await File(outputPath).writeAsString(output.toString());
  }
}