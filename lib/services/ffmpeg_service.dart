import 'dart:io';
import 'dart:convert';
import 'package:process_run/shell.dart';
import 'package:path/path.dart' as path;
import '../models/audio_file.dart';
import '../models/encoding_config.dart';
import '../models/audiobook_metadata.dart';

class FFmpegService {
  String? _ffmpegPath;
  String? _ffprobePath;
  late final Shell _shell;
  
  FFmpegService() {
    final environment = Map<String, String>.from(Platform.environment);
    environment['PATH'] = '/opt/homebrew/bin:/usr/local/bin:${environment['PATH']}';
    _shell = Shell(environment: environment);
  }

  Future<void> extractChapters({
    required String audiobookPath,
    required Function(String) onProgress,
  }) async {
    await _ensureBinaries();
    
    final ext = path.extension(audiobookPath).toLowerCase();
    if (ext != '.opus' && ext != '.m4a' && ext != '.m4b') {
      throw Exception('Only .opus, .m4a, and .m4b files are supported for chapter extraction');
    }
    
    final sourceDir = path.dirname(audiobookPath);
    final chaptersDir = path.join(sourceDir, 'chapters');
    
    final outputDir = Directory(chaptersDir);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    onProgress('Reading chapters from audiobook...');
    
    final result = await _shell.run(
      '$_ffprobePath -i "$audiobookPath" -show_chapters -print_format json'
    );
    
    final jsonStr = result.first.stdout.toString();
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    final chapters = json['chapters'] as List? ?? [];
    
    if (chapters.isEmpty) {
      throw Exception('No chapters found in audiobook');
    }
    
    onProgress('Found ${chapters.length} chapters. Extracting...');
    
    for (var i = 0; i < chapters.length; i++) {
      final chapter = chapters[i] as Map<String, dynamic>;
      final tags = chapter['tags'] as Map<String, dynamic>? ?? {};
      
      final startTime = chapter['start_time'].toString();
      final endTime = chapter['end_time'].toString();
      
      var title = tags['title'] ?? tags['TITLE'] ?? 'Chapter_${i + 1}';
      title = title.toString()
          .replaceAll('/', '-')
          .replaceAll('_', ' ')
          .trim();
      
      final outputExt = (ext == '.m4b') ? '.m4a' : ext;
      final outputPath = path.join(chaptersDir, '$title$outputExt');
      
      onProgress('Extracting chapter ${i + 1}/${chapters.length}: $title');
      
      await _shell.run(
        '$_ffmpegPath -hide_banner -i "$audiobookPath" '
        '-ss $startTime -to $endTime '
        '-c:v copy -c:a copy '
        '-avoid_negative_ts make_zero '
        '-fflags +genpts '
        '"$outputPath" -y'
      );
    }
    
    onProgress('All ${chapters.length} chapters extracted to: $chaptersDir');
  }

  Future<void> _ensureBinaries() async {
      if (_ffmpegPath != null && _ffprobePath != null) return;
  
      if (Platform.isAndroid) {
        final appLibDir = '/data/data/com.example.substitcher/lib';
        _ffmpegPath = '$appLibDir/libffmpeg.so';
        _ffprobePath = '$appLibDir/libffprobe.so';
        
        print('Using Android ffmpeg: $_ffmpegPath');
        print('Using Android ffprobe: $_ffprobePath');
        return;
      } else if (Platform.isMacOS) {
        final executablePath = Platform.resolvedExecutable;
        final bundleDir = path.dirname(path.dirname(executablePath));
        final resourcesDir = path.join(bundleDir, 'Resources', 'bin');
        
        final bundledFfmpeg = path.join(resourcesDir, 'ffmpeg');
        final bundledFfprobe = path.join(resourcesDir, 'ffprobe');
    
        if (await File(bundledFfmpeg).exists() && await File(bundledFfprobe).exists()) {
          _ffmpegPath = bundledFfmpeg;
          _ffprobePath = bundledFfprobe;
          print('Using bundled ffmpeg: $_ffmpegPath');
          print('Using bundled ffprobe: $_ffprobePath');
          return;
        }
    
        _ffmpegPath = '/opt/homebrew/bin/ffmpeg';
        _ffprobePath = '/opt/homebrew/bin/ffprobe';
        print('Using system ffmpeg: $_ffmpegPath');
      } else if (Platform.isLinux) {
        final executablePath = Platform.resolvedExecutable;
        final executableDir = path.dirname(executablePath);
        final bundledBinDir = path.join(executableDir, 'bin');
        
        final bundledFfmpeg = path.join(bundledBinDir, 'ffmpeg');
        final bundledFfprobe = path.join(bundledBinDir, 'ffprobe');
    
        if (await File(bundledFfmpeg).exists() && await File(bundledFfprobe).exists()) {
          _ffmpegPath = bundledFfmpeg;
          _ffprobePath = bundledFfprobe;
          print('Using bundled ffmpeg: $_ffmpegPath');
          print('Using bundled ffprobe: $_ffprobePath');
          return;
        }
    
        _ffmpegPath = 'ffmpeg';
        _ffprobePath = 'ffprobe';
        print('Using system ffmpeg');
      } else if (Platform.isWindows) {
        final executablePath = Platform.resolvedExecutable;
        final executableDir = path.dirname(executablePath);
        final bundledBinDir = path.join(executableDir, 'data', 'flutter_assets', 'bin');
        
        final bundledFfmpeg = path.join(bundledBinDir, 'ffmpeg.exe');
        final bundledFfprobe = path.join(bundledBinDir, 'ffprobe.exe');
    
        if (await File(bundledFfmpeg).exists() && await File(bundledFfprobe).exists()) {
          _ffmpegPath = bundledFfmpeg;
          _ffprobePath = bundledFfprobe;
          print('Using bundled ffmpeg: $_ffmpegPath');
          print('Using bundled ffprobe: $_ffprobePath');
          return;
        }
    
        _ffmpegPath = 'ffmpeg';
        _ffprobePath = 'ffprobe';
        print('Using system ffmpeg');
      } else {
        _ffmpegPath = 'ffmpeg';
        _ffprobePath = 'ffprobe';
      }
    }
  
  Future<bool> checkFFmpegAvailable() async {
    try {
      await _ensureBinaries();
      await _shell.run('$_ffmpegPath -version');
      return true;
    } catch (e) {
      print('FFmpeg check failed: $e');
      return false;
    }
  }
  
  Future<Duration> getAudioDuration(String filePath) async {
    await _ensureBinaries();
    try {
      final result = await _shell.run(
        '$_ffprobePath -v error -show_entries format=duration '
        '-of default=noprint_wrappers=1:nokey=1 "$filePath"'
      );
      
      final durationStr = result.first.stdout.toString().trim();
      final seconds = double.parse(durationStr);
      return Duration(milliseconds: (seconds * 1000).round());
    } catch (e) {
      throw Exception('Failed to get duration: $e');
    }
  }
  
  Future<String> getAudioTitle(String filePath) async {
    await _ensureBinaries();
    try {
      final result = await _shell.run(
        '$_ffprobePath -v error -show_entries format_tags=title '
        '-of default=noprint_wrappers=1:nokey=1 "$filePath"'
      );
      
      final title = result.first.stdout.toString().trim();
      if (title.isEmpty) {
        return path.basenameWithoutExtension(filePath);
      }
      return title;
    } catch (e) {
      return path.basenameWithoutExtension(filePath);
    }
  }
  
  Future<AudioFile> getAudioInfo(String filePath) async {
    final duration = await getAudioDuration(filePath);
    final title = await getAudioTitle(filePath);
    
    return AudioFile(
      path: filePath,
      filename: path.basename(filePath),
      duration: duration,
      originalTitle: title,
    );
  }
  
  Future<void> encodeChapter({
    required String inputPath,
    required String outputPath,
    required EncodingConfig config,
    required Function(double) onProgress,
  }) async {
    await _ensureBinaries();
    final filterString = config.buildFilterString();
    
    final outputDir = Directory(path.dirname(outputPath));
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    
    final args = [
      _ffmpegPath!,
      '-i', inputPath,
      '-hide_banner',
      '-loglevel', 'error',
      '-vn',
      '-c:a', 'libopus',
      '-application', config.opusApplication,
      '-b:a', '${config.bitrate}k',
      '-af', filterString,
      outputPath,
      '-y',
    ];
    
    final process = await Process.start(args[0], args.sublist(1));
    
    final exitCode = await process.exitCode;
    
    if (exitCode != 0) {
      final error = await process.stderr.transform(const SystemEncoding().decoder).join();
      throw Exception('FFmpeg encoding failed: $error');
    }
    
    onProgress(1.0);
  }
  
  Future<void> concatenateWithChapters({
    required List<String> opusFiles,
    required String outputPath,
    required EncodingConfig config,
    required Function(String) onProgress,
  }) async {
    await _ensureBinaries();
    
    final workingDir = path.dirname(opusFiles.first);
    final listFile = File(path.join(workingDir, 'list.txt'));
    final metadataFile = File(path.join(workingDir, 'ffmetadata.txt'));
    final tempOutput = path.join(workingDir, 'temp.opus');
    
    try {
      onProgress('Creating file list...');
      
      final listContent = opusFiles
          .map((f) => "file '${path.basename(f)}'")
          .join('\n');
      
      await listFile.writeAsString(listContent);
      
      onProgress('Merging files...');
      
      final outputDir = Directory(path.dirname(outputPath));
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      final shell = Shell(workingDirectory: workingDir);
      
      await shell.run(
        '$_ffmpegPath -f concat -safe 0 -i "list.txt" '
        '-c copy "temp.opus" -y'
      );
      
      onProgress('Extracting metadata...');
      
      await shell.run(
        '$_ffmpegPath -y -i "temp.opus" -f ffmetadata "ffmetadata.txt"'
      );
      
      onProgress('Adding chapter markers...');
      
      await _addChapterMetadata(
        metadataFile: metadataFile,
        opusFiles: opusFiles,
      );
      
      onProgress('Creating final audiobook...');
      
      final coverData = _getBlackCoverPng();
      await shell.run(
        '$_ffmpegPath -i "temp.opus" -i "ffmetadata.txt" '
        '-map_chapters 1 -map 0:a '
        '-metadata "title=${config.title}" '
        '-metadata "album=${config.title}" '
        '-metadata "artist=${config.author}" '
        '-metadata "album_artist=${config.author}" '
        '-metadata "date=${config.year}" '
        '-metadata:s:a METADATA_BLOCK_PICTURE="$coverData" '
        '-c copy "$outputPath" -y'
      );
      
      onProgress('Complete!');
      
      onProgress('Cleaning up temporary files...');
      
      if (await listFile.exists()) await listFile.delete();
      if (await metadataFile.exists()) await metadataFile.delete();
      if (await File(tempOutput).exists()) await File(tempOutput).delete();
      
    } catch (e) {
      try {
        if (await listFile.exists()) await listFile.delete();
        if (await metadataFile.exists()) await metadataFile.delete();
        if (await File(tempOutput).exists()) await File(tempOutput).delete();
      } catch (cleanupError) {
        print('Warning: Could not clean up temp files: $cleanupError');
      }
      rethrow;
    }
  }
  
  Future<void> _addChapterMetadata({
    required File metadataFile,
    required List<String> opusFiles,
  }) async {
    final metadata = StringBuffer(await metadataFile.readAsString());
    
    double totalSeconds = 0;
    
    for (final opusFile in opusFiles) {
      final duration = await getAudioDuration(opusFile);
      final durationSecs = duration.inMilliseconds / 1000;
      
      var title = path.basenameWithoutExtension(opusFile);
      
      title = title.replaceAll('`', "'");
      
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      final seconds = duration.inSeconds.remainder(60);
      
      String timeStr;
      if (hours > 0) {
        timeStr = '$hours:${minutes.toString().padLeft(2, '0')}:'
                 '${seconds.toString().padLeft(2, '0')}';
      } else {
        timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }
      
      metadata.writeln('[CHAPTER]');
      metadata.writeln('TIMEBASE=1/1');
      metadata.writeln('START=${totalSeconds.round()}');
      totalSeconds += durationSecs;
      metadata.writeln('END=${totalSeconds.round()}');
      metadata.writeln('title=$title [$timeStr]');
    }
    
    await metadataFile.writeAsString(metadata.toString());
  }
  
  String _getBlackCoverPng() {
    return 'AAAAAwAAAAlpbWFnZS9wbmcAAAALRnJvbnQgQ292ZXIAAAAQAAAACQAAACAAAAAAAAAAU4lQTkcNChoKAAAADUlIRFIAAAAQAAAACQgGAAAAOyqsMgAAABpJREFUeJxjZGBg+M9AAWCiRPOoARAwDAwAAFmzARHg40/fAAAAAElFTkSuQmCC';
  }
  
  Future<List<AudioFile>> listAudioFilesInDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    final audioExtensions = ['mp3', 'm4a', 'aac', 'opus', 'ogg', 'flac', 'wav', 'wma', 'webm', 'mkv', 'mp4'];
    final audioFiles = <AudioFile>[];
    
    await for (final entity in dir.list()) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase().replaceFirst('.', '');
        if (audioExtensions.contains(ext)) {
          try {
            final audioFile = await getAudioInfo(entity.path);
            audioFiles.add(audioFile);
          } catch (e) {
            print('Error loading ${entity.path}: $e');
          }
        }
      }
    }
    
    audioFiles.sort((a, b) => a.path.compareTo(b.path));
    return audioFiles;
  }
  
  Future<AudiobookMetadata> loadAudiobook(String filePath) async {
    await _ensureBinaries();
    try {
      final result = await _shell.run(
        '$_ffprobePath -v quiet -print_format json -show_format -show_chapters "$filePath"'
      );
      
      final jsonStr = result.first.stdout.toString();
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      final format = json['format'] as Map<String, dynamic>;
      final tags = format['tags'] as Map<String, dynamic>? ?? {};
      
      final title = tags['title'] ?? tags['TITLE'] ?? path.basenameWithoutExtension(filePath);
      final author = tags['artist'] ?? tags['ARTIST'] ?? tags['album_artist'] ?? tags['ALBUM_ARTIST'] ?? 'Unknown Artist';
      final year = tags['date'] ?? tags['DATE'] ?? tags['year'] ?? tags['YEAR'] ?? '';
      final durationSecs = double.parse(format['duration'] as String);
      
      final chaptersJson = json['chapters'] as List? ?? [];
      final chapters = <Chapter>[];
      
      for (var i = 0; i < chaptersJson.length; i++) {
        final chapterJson = chaptersJson[i] as Map<String, dynamic>;
        final chapterTags = chapterJson['tags'] as Map<String, dynamic>? ?? {};
        
        final startSecs = double.parse(chapterJson['start_time'].toString());
        final endSecs = double.parse(chapterJson['end_time'].toString());
        
        chapters.add(Chapter(
          index: i,
          title: chapterTags['title'] ?? chapterTags['TITLE'] ?? 'Chapter ${i + 1}',
          startTime: Duration(milliseconds: (startSecs * 1000).toInt()),
          endTime: Duration(milliseconds: (endSecs * 1000).toInt()),
          duration: Duration(milliseconds: ((endSecs - startSecs) * 1000).toInt()),
        ));
      }
      
      if (chapters.isEmpty) {
        chapters.add(Chapter(
          index: 0,
          title: 'Full Audiobook',
          startTime: Duration.zero,
          endTime: Duration(milliseconds: (durationSecs * 1000).toInt()),
          duration: Duration(milliseconds: (durationSecs * 1000).toInt()),
        ));
      }
      
      return AudiobookMetadata(
        path: filePath,
        title: title.toString(),
        author: author.toString(),
        year: year.toString(),
        duration: Duration(milliseconds: (durationSecs * 1000).toInt()),
        chapters: chapters,
      );
    } catch (e) {
      throw Exception('Failed to load audiobook: $e');
    }
  }
}