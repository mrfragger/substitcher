import 'dart:io';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class WhisperService {
  String? whisperExecutablePath;
  String? modelDirectory;

  bool _encoding = false;
  bool _cancelEncoding = false;
  
  String language = 'auto';
  String selectedModel = 'large-v3-turbo';
  int maxLength = 80;
  String segmentTime = '0:30';
  int msOffset = 65;
  bool printColors = false;
  bool useGPU = true;
  bool splitOnWord = true;
  String customPrompt = "The example of those who disbelieve is like that of one who shouts at what hears nothing but calls and cries i.e., cattle or sheep - deaf, dumb and blind, so they do not understand.";
  bool translateToEnglish = false;
  
  Future<void> initialize() async {
    try {
      whisperExecutablePath = await WhisperBundled.getWhisperExecutablePath();
      print('Whisper initialized at: $whisperExecutablePath');
    } catch (e) {
      print('Failed to initialize bundled whisper: $e');
    }
    
    final prefs = await SharedPreferences.getInstance();
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
  
  Future<void> transcribeChapters(
    String chaptersDirectory,
    Function(String status, double progress) onProgress,
    Function(String error) onError,
  ) async {
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
      
      final vttOutputDir = Directory(path.join(chaptersDirectory, 'vttsubs'));
      if (!vttOutputDir.existsSync()) {
        vttOutputDir.createSync();
      }
      
      final tempWorkDir = Directory(path.join(chaptersDirectory, 'temp_transcribe'));
      if (tempWorkDir.existsSync()) {
        tempWorkDir.deleteSync(recursive: true);
      }
      tempWorkDir.createSync();
      
      final totalChapters = opusFiles.length;
      final chapterVttFiles = <String>[];
      
      double totalElapsedSeconds = 0.0;
      
      for (int chapterIndex = 0; chapterIndex < opusFiles.length; chapterIndex++) {
        final chapterStart = DateTime.now();
        final opusFile = opusFiles[chapterIndex];
        final chapterName = path.basenameWithoutExtension(opusFile.path);
        
        onProgress(
          'Processing chapter ${chapterIndex + 1}/$totalChapters: $chapterName',
          chapterIndex / totalChapters,
        );
        
        final chapterVttPath = await _transcribeChapter(
          opusFile.path,
          tempWorkDir.path,
          modelPath,
          (segmentStatus, segmentProgress) {
            final overallProgress = (chapterIndex + segmentProgress) / totalChapters;
            onProgress(segmentStatus, overallProgress);
          },
          onError,
        );
        
        if (chapterVttPath != null) {
          final finalChapterVtt = path.join(vttOutputDir.path, '$chapterName.vtt');
          await File(chapterVttPath).copy(finalChapterVtt);
          chapterVttFiles.add(finalChapterVtt);
        }
        
        final chapterElapsed = DateTime.now().difference(chapterStart);
        totalElapsedSeconds += chapterElapsed.inSeconds;
        
        final chapterTime = _formatElapsed(chapterElapsed.inSeconds);
        final totalTime = _formatElapsed(totalElapsedSeconds.toInt());
        
        onProgress(
          'Chapter ${chapterIndex + 1}/$totalChapters complete: $chapterName ($chapterTime | Total: $totalTime)',
          (chapterIndex + 1) / totalChapters,
        );
      }
      
      onProgress('Merging ${chapterVttFiles.length} chapter VTT files...', 0.95);
      await _mergeChapterVttFiles(
        chapterVttFiles, 
        chaptersDirectory,
        opusFiles.map((f) => f.path).toList(),
      );
      
      tempWorkDir.deleteSync(recursive: true);
      
      onProgress('Transcription complete!', 1.0);
      
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
    
    try {
      final workDir = Directory(workingDirectory);
      if (workDir.existsSync()) {
        for (final entity in workDir.listSync()) {
          if (entity is File) {
            await entity.delete();
          }
          if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      }
      
      onProgress('Splitting into $segmentTime segments...', 0.1);
      await _splitIntoSegments(opusFilePath, workingDirectory);
      
      onProgress('Converting segments to WAV...', 0.2);
      final wavFiles = await _convertToWav(workingDirectory);
      
      if (wavFiles.isEmpty) {
        onError('No WAV files created');
        return null;
      }
      
      onProgress('Transcribing ${wavFiles.length} segments...', 0.3);
      await _runWhisper(wavFiles, modelPath, workingDirectory);
      
      onProgress('Organizing VTT files...', 0.7);
      await _organizeVttFiles(workingDirectory);
      
      onProgress('Stitching VTT segments...', 0.8);
      final stitchedVttPath = await _stitchVttFilesForChapter(opusFilePath, workingDirectory);
      
      onProgress('Cleaning up...', 0.9);
      await _cleanup(workingDirectory);
      
      onProgress('Chapter complete: $chapterName', 1.0);
      
      return stitchedVttPath;
      
    } catch (e) {
      onError('Error transcribing chapter: $e');
      return null;
    }
  }
  
  Future<void> _splitIntoSegments(String opusFilePath, String workingDir) async {
    final result = await Process.run(
      'ffmpeg',
      [
        '-hide_banner',
        '-i', opusFilePath,
        '-c', 'copy',
        '-f', 'segment',
        '-segment_time', segmentTime,
        '-reset_timestamps', '1',
        path.join(workingDir, '%04d.opus'),
      ],
    );
    
    if (result.exitCode != 0) {
      throw Exception('FFmpeg split failed: ${result.stderr}');
    }
  }
  
  Future<List<String>> _convertToWav(String workingDir) async {
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
        'ffmpeg',
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
    
    final result = await Process.run(
      whisperExecutablePath!,
      args,
      workingDirectory: workingDir,
    );
    
    if (result.exitCode != 0) {
      throw Exception('Whisper transcription failed: ${result.stderr}');
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
    final sourceDir = Directory(path.join(workingDir, 'source'));
    if (!sourceDir.existsSync()) {
      sourceDir.createSync();
    }
  
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
  
    final stitchedTemp1 = path.join(sourceDir.path, 'stitchedsubstemp1.vtt');
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
  
    final stitchedTemp4 = path.join(sourceDir.path, 'stitchedsubstemp4.vtt');
    await _addHourToTimecodes(stitchedTemp1, stitchedTemp4);
  
    final stitchedOverlap = path.join(sourceDir.path, 'stitchedsubsoverlap.vtt');
    await _fixOverlappingTimecodes(stitchedTemp4, stitchedOverlap);
    
    final stitchedTemp2 = path.join(sourceDir.path, 'stitchedsubstemp2.vtt');
    await _addWebvttHeader(stitchedOverlap, stitchedTemp2);
  
    final chapterName = path.basenameWithoutExtension(originalOpusPath);
    final finalVtt = path.join(workingDir, '${chapterName}_temp.vtt');
    await File(stitchedTemp2).copy(finalVtt);
  
    return finalVtt;
  }
  
  Future<void> _mergeChapterVttFiles(List<String> chapterVttFiles, String outputDir, List<String> originalOpusFiles) async {
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
    final mergedVtt = path.join(outputDir, '$baseFilename.vtt');
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

  Future<void> _cleanup(String workingDir) async {
    final dir = Directory(workingDir);
    
    for (final entity in dir.listSync()) {
      if (entity is File) {
        final name = path.basename(entity.path);
        if (name.startsWith('temp_') && name.endsWith('.wav')) {
          await entity.delete();
        }
        if (RegExp(r'^\d{4}\.opus$').hasMatch(name)) {
          await entity.delete();
        }
      }
    }
  }

  Future<double> _getOpusDuration(String opusPath) async {
    final result = await Process.run('ffprobe', [
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