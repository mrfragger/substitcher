import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as path;
import 'package:html/parser.dart' as html_parser;
import '../services/ffmpeg_service.dart';
import '../models/encoding_config.dart';

class AnkiService {
  final FFmpegService _ffmpeg = FFmpegService();

  Future<Map<String, dynamic>> extractAndConvert(String apkgPath) async {
    final baseName = path.basenameWithoutExtension(apkgPath);
    final apkgDir = path.dirname(apkgPath);
    final outputDir = Directory(path.join(apkgDir, baseName));
    final outputMediaDir = Directory(path.join(outputDir.path, '${baseName}_media'));
    final csvPath = path.join(outputDir.path, '${baseName}_converted.csv');

    if (await outputDir.exists() &&
        await outputMediaDir.exists() &&
        await File(csvPath).exists()) {

      print('Using existing extraction from: ${outputDir.path}');

      int extractedCount = 0;
      if (await outputMediaDir.exists()) {
        final audioExtensions = ['mp3', 'm4a', 'ogg', 'wav', 'opus', 'flac'];
        await for (final file in outputMediaDir.list()) {
          if (file is File) {
            final ext = path.extension(file.path).toLowerCase().replaceFirst('.', '');
            if (audioExtensions.contains(ext)) {
              extractedCount++;
            }
          }
        }
      }

      print('Found $extractedCount existing audio files');

      final csvFile = File(csvPath);
      final csvContent = await csvFile.readAsString();

      final csvData = const CsvToListConverter().convert(
        csvContent,
        eol: '\n',
        shouldParseNumbers: false,
      );

      if (csvData.isEmpty) {
        throw Exception('CSV file is empty');
      }

      final columns = csvData[0].map((e) => e.toString()).toList();
      print('Found ${columns.length} columns: ${columns.join(", ")}');

      final previewRows = <Map<String, String>>[];
      for (int i = 1; i < csvData.length && previewRows.length < 15; i++) {
        final row = csvData[i];
        final rowData = <String, String>{};

        for (int k = 0; k < columns.length; k++) {
          if (k < row.length) {
            rowData[columns[k]] = row[k].toString();
          } else {
            rowData[columns[k]] = '';
          }
        }

        if (rowData.isNotEmpty) {
          previewRows.add(rowData);
        }
      }

      return {
        'columns': columns,
        'preview': previewRows,
        'totalNotes': csvData.length - 1,
        'mediaDir': outputMediaDir.path,
        'mediaMap': <String, String>{},
        'tempDir': '',
        'outputDir': outputDir.path,
        'csvPath': csvPath,
        'extractedCount': extractedCount,
      };
    }

    final tempDir = Directory.systemTemp.createTempSync('anki_extract_');

    try {
      final bytes = await File(apkgPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(path.join(tempDir.path, filename));
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        }
      }

      final mediaMap = <String, String>{};
      final mediaFile = File(path.join(tempDir.path, 'media'));
      if (await mediaFile.exists()) {
        final mediaJson = await mediaFile.readAsString();
        final mediaData = jsonDecode(mediaJson) as Map<String, dynamic>;
        mediaData.forEach((key, value) {
          mediaMap[key] = value.toString();
        });
      }

      if (await outputDir.exists()) {
      } else {
        await outputDir.create(recursive: true);
      }

      if (await outputMediaDir.exists()) {
        await outputMediaDir.delete(recursive: true);
      }
      await outputMediaDir.create(recursive: true);

      int extractedCount = 0;
      for (final entry in mediaMap.entries) {
        final sourceFile = File(path.join(tempDir.path, entry.key));
        if (await sourceFile.exists()) {
          final destFile = File(path.join(outputMediaDir.path, entry.value));
          await sourceFile.copy(destFile.path);
          extractedCount++;
        }
      }

      print('Extracted $extractedCount audio files');

      final dbPath = File(path.join(tempDir.path, 'collection.anki21')).existsSync()
          ? path.join(tempDir.path, 'collection.anki21')
          : path.join(tempDir.path, 'collection.anki2');

      final db = sqlite3.open(dbPath);

      try {
        final result = db.select('SELECT flds FROM notes');

        int maxFields = 0;
        for (final row in result) {
          final fields = (row['flds'] as String).split('\x1f');
          if (fields.length > maxFields) {
            maxFields = fields.length;
          }
        }

        final List<String> fieldNames = [];
        final modelsResult = db.select('SELECT models FROM col');
        if (modelsResult.isNotEmpty) {
          try {
            final modelsJson = jsonDecode(modelsResult.first['models'] as String) as Map<String, dynamic>;
            final model = modelsJson.values.first as Map<String, dynamic>;
            final flds = model['flds'] as List<dynamic>;
            for (final field in flds) {
              final fieldMap = field as Map<String, dynamic>;
              fieldNames.add(fieldMap['name'] as String);
            }
          } catch (e) {
            print('Error parsing models: $e');
          }
        }

        final columns = <String>[];
        for (int i = 0; i < maxFields; i++) {
          String fieldName;
          if (i < fieldNames.length && fieldNames[i].isNotEmpty) {
            fieldName = fieldNames[i];
          } else {
            fieldName = (i + 1).toString();
          }

          columns.add(fieldName);
          columns.add('${fieldName}_Audio');
        }
        columns.add('All_Audio_Files');

        final csvFile = File(csvPath);
        final csvBuffer = StringBuffer();

        csvBuffer.writeln(columns.map((c) => '"${c.replaceAll('"', '""')}"').join(','));

        final previewRows = <Map<String, String>>[];

        for (final row in result) {
          final fields = (row['flds'] as String).split('\x1f');
          final csvRow = <String>[];
          final allAudio = <String>[];

          while (fields.length < maxFields) {
            fields.add('');
          }

          for (int i = 0; i < maxFields; i++) {
            final soundPattern = RegExp(r'\[sound:([^\]]+)\]');
            final audioMatches = soundPattern.allMatches(fields[i]);
            final fieldAudioFiles = <String>[];

            for (final match in audioMatches) {
              final audioRef = match.group(1)!;
              final actualFilename = mediaMap[audioRef] ?? audioRef;
              fieldAudioFiles.add(actualFilename);
              allAudio.add(actualFilename);
            }

            String cleaned = _cleanField(fields[i], mediaMap);

            final textEscaped = cleaned.replaceAll('"', '""');
            csvRow.add('"$textEscaped"');

            final audioEscaped = fieldAudioFiles.join('; ').replaceAll('"', '""');
            csvRow.add('"$audioEscaped"');
          }

          final allAudioEscaped = allAudio.join('; ').replaceAll('"', '""');
          csvRow.add('"$allAudioEscaped"');

          csvBuffer.writeln(csvRow.join(','));

          if (previewRows.length < 15) {
            final rowData = <String, String>{};
            for (int i = 0; i < maxFields; i++) {
              final soundPattern = RegExp(r'\[sound:([^\]]+)\]');
              final audioMatches = soundPattern.allMatches(fields[i]);
              final fieldAudioFiles = <String>[];

              for (final match in audioMatches) {
                final audioRef = match.group(1)!;
                final actualFilename = mediaMap[audioRef] ?? audioRef;
                fieldAudioFiles.add(actualFilename);
              }

              String cleaned = _cleanField(fields[i], mediaMap);

              rowData[columns[i * 2]] = cleaned;
              rowData[columns[i * 2 + 1]] = fieldAudioFiles.join('; ');
            }

            rowData['All_Audio_Files'] = allAudio.join('; ');
            previewRows.add(rowData);
          }

        }

        await csvFile.writeAsString(csvBuffer.toString());
        print('CSV saved to: $csvPath');

        final returnValue = {
          'columns': columns,
          'preview': previewRows,
          'totalNotes': result.length,
          'mediaDir': outputMediaDir.path,
          'mediaMap': mediaMap,
          'tempDir': tempDir.path,
          'outputDir': outputDir.path,
          'csvPath': csvPath,
          'extractedCount': extractedCount,
        };

        return returnValue;

      } finally {
        db.close();
      }
    } catch (e) {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      rethrow;
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  String _cleanField(String field, Map<String, String> mediaMap) {
    final soundPattern = RegExp(r'\[sound:([^\]]+)\]');
    final audioMatches = soundPattern.allMatches(field);
    final audioFiles = <String>[];

    for (final match in audioMatches) {
      final audioRef = match.group(1)!;
      if (mediaMap.containsKey(audioRef)) {
        audioFiles.add(mediaMap[audioRef]!);
      } else {
        audioFiles.add(audioRef);
      }
    }

    var cleaned = field.replaceAll(soundPattern, '');

    final document = html_parser.parse(cleaned);
    cleaned = document.body?.text ?? cleaned;

    cleaned = cleaned
        .replaceAll(RegExp(r'\{\{c\d+::'), '[')
        .replaceAll(RegExp(r'\{\{'), '[')
        .replaceAll(RegExp(r'/V\d+\}\}'), ']')
        .replaceAll(RegExp(r'V\d+\}\}'), ']')
        .replaceAll(RegExp(r'\}\}'), ']')
        .replaceAll('::', '  ')
        .replaceAll(RegExp(r'\[ +'), '[')
        .replaceAll(RegExp(r' +\]'), ']');

    cleaned = cleaned.trim();

    if (audioFiles.isNotEmpty && cleaned.isEmpty) {
      cleaned = audioFiles.join('; ');
    }

    return cleaned;
  }

  Future<void> _stitchVttFiles({
    required String encodedDir,
    required String outputPath,
    required List<String> opusFiles,
  }) async {
    final vttBuffer = StringBuffer();
    vttBuffer.writeln('WEBVTT');
    vttBuffer.writeln();

    double cumulativeTime = 0.0;

    for (final opusFile in opusFiles) {
      final basename = path.basenameWithoutExtension(opusFile);
      final vttFile = File(path.join(encodedDir, '$basename.vtt'));

      if (!await vttFile.exists()) {
        print('Warning: VTT file not found: ${vttFile.path}');
        continue;
      }

      final vttContent = await vttFile.readAsString();
      final lines = vttContent.split('\n');

      bool inCueBlock = false;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();

        if (line.isEmpty) {
          if (inCueBlock) {
            vttBuffer.writeln();
            inCueBlock = false;
          }
          continue;
        }

        if (line == 'WEBVTT') continue;

        if (line.contains(' --> ')) {
          final parts = line.split(' --> ');
          final startTime = _parseTimestamp(parts[0]);
          final endTime = _parseTimestamp(parts[1]);

          final newStart = _formatTimestamp(Duration(
            milliseconds: (cumulativeTime * 1000 + startTime.inMilliseconds).round(),
          ));
          final newEnd = _formatTimestamp(Duration(
            milliseconds: (cumulativeTime * 1000 + endTime.inMilliseconds).round(),
          ));

          vttBuffer.writeln('$newStart --> $newEnd');
          inCueBlock = true;
        } else if (inCueBlock) {
          vttBuffer.writeln(line);
        }
      }

      final duration = await _ffmpeg.getAudioDuration(opusFile);
      cumulativeTime += duration.inMilliseconds / 1000.0;
    }

    await File(outputPath).writeAsString(vttBuffer.toString());
    print('VTT file created: $outputPath');
  }

  Duration _parseTimestamp(String timestamp) {
    final parts = timestamp.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final secondsParts = parts[2].split('.');
    final seconds = int.parse(secondsParts[0]);
    final milliseconds = int.parse(secondsParts[1]);

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  Future<void> createAudiobook({
    required String apkgPath,
    required String outputDir,
    required int frontColumn,
    required int backColumn,
    required int audioColumn,
    required int audioRepetitions,
    required bool sampleMode,
    required String author,
    required String title,
    required int bitrate,
    required Function(String status, double progress) onProgress,
  }) async {
    onProgress('Reading CSV file...', 0.0);

    final baseName = path.basenameWithoutExtension(apkgPath);
    final csvPath = path.join(outputDir, '${baseName}_converted.csv');
    final mediaDir = path.join(outputDir, '${baseName}_media');

    if (!await File(csvPath).exists()) {
      throw Exception('CSV file not found: $csvPath');
    }

    final csvFile = File(csvPath);
    final csvContent = await csvFile.readAsString();

    final csvData = const CsvToListConverter().convert(
      csvContent,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (csvData.isEmpty) {
      throw Exception('CSV file is empty');
    }

    final columns = csvData[0].map((e) => e.toString()).toList();
    print('Reading from columns: Front=${columns[frontColumn]}, Back=${columns[backColumn]}, Audio=${columns[audioColumn]}');

    final chapters = <Map<String, dynamic>>[];
    final maxNotes = sampleMode ? 50 : csvData.length - 1;

    onProgress('Processing notes...', 0.1);

    for (int i = 1; i < csvData.length && chapters.length < maxNotes; i++) {
      final row = csvData[i];

      if (frontColumn >= row.length || backColumn >= row.length || audioColumn >= row.length) {
        print('Warning: Row $i has insufficient columns');
        continue;
      }

      final front = row[frontColumn].toString().trim();
      final back = row[backColumn].toString().trim();
      final audioList = row[audioColumn].toString().trim();

      if (audioList.isEmpty) {
        print('Warning: Row $i has no audio in column ${columns[audioColumn]}');
        continue;
      }

      final audioFiles = audioList.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      for (final audioFile in audioFiles) {
        final audioPath = path.join(mediaDir, audioFile);

        if (!await File(audioPath).exists()) {
          print('Warning: Audio file not found: $audioPath');
          continue;
        }

        chapters.add({
          'front': front.isEmpty ? back : front,
          'back': back.isEmpty ? front : back,
          'audioFile': audioFile,
        });

        if (chapters.length >= maxNotes) break;
      }

      if (chapters.length >= maxNotes) break;
    }

    if (chapters.isEmpty) {
      throw Exception('No valid chapters found.\nFront: ${columns[frontColumn]}\nBack: ${columns[backColumn]}\nAudio: ${columns[audioColumn]}');
    }

    print('Found ${chapters.length} chapters to create');
    onProgress('Processing ${chapters.length} chapters...', 0.2);

    final totalChapters = chapters.length;
    int numAudiobooks = 1;
    int chaptersPerBook = totalChapters;

    if (totalChapters > 999) {
      numAudiobooks = ((totalChapters + 998) / 999).floor();
      chaptersPerBook = ((totalChapters + numAudiobooks - 1) / numAudiobooks).floor();
      onProgress(
        'Creating $numAudiobooks audiobooks (about $chaptersPerBook chapters each)',
        0.2
      );
    } else {
      onProgress('Creating 1 audiobook', 0.2);
    }

    final now = DateTime.now();
    final timestamp = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';
    final vttDir = Directory(path.join(outputDir, timestamp, 'vtt'));
    await vttDir.create(recursive: true);

    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final paddedNum = (i + 1).toString().padLeft(4, '0');
      final chapterOutputPath = path.join(vttDir.path, '$paddedNum.opus');

      onProgress('Repeating (${audioRepetitions}x) audio chapter ${i + 1}/${chapters.length}', 0.2 + (i / chapters.length) * 0.5);

      final audioFile = chapter['audioFile'] as String;
      final audioPath = path.join(mediaDir, audioFile);

      if (audioRepetitions == 1) {
        await _copyOrConvertAudio(audioPath, chapterOutputPath);
      } else {
        await _repeatAudio(audioPath, chapterOutputPath, audioRepetitions);
      }

      final duration = await _ffmpeg.getAudioDuration(chapterOutputPath);

      await _createVttFile(
        vttPath: path.join(vttDir.path, '$paddedNum.vtt'),
        front: chapter['front']!,
        back: chapter['back']!,
        duration: duration,
        repetitions: audioRepetitions,
      );

      await File(path.join(vttDir.path, '$paddedNum.back'))
          .writeAsString(chapter['back']!);
    }

    onProgress('Encoding chapters to opus...', 0.7);

    final encodedDir = Directory(path.join(vttDir.path, 'output',
        'chapters', 'encodedchapters'));
    await encodedDir.create(recursive: true);

    final opusChapterFiles = vttDir
        .listSync()
        .where((e) => e is File && e.path.endsWith('.opus'))
        .cast<File>()
        .toList();

    await _encodeToOpusParallel(
      mp3Files: opusChapterFiles,
      outputDir: encodedDir,
      bitrate: bitrate,
      onProgress: (current, total) {
        onProgress('Encoding to opus $current/$total', 0.7 + (current / total) * 0.15);
      },
    );

    for (final file in vttDir.listSync()) {
      if (file is File && (file.path.endsWith('.vtt') || file.path.endsWith('.back'))) {
        final basename = path.basename(file.path);
        await file.copy(path.join(encodedDir.path, basename));
      }
    }

    final opusFiles = encodedDir
        .listSync()
        .where((e) => e is File && e.path.endsWith('.opus'))
        .cast<File>()
        .map((f) => f.path)
        .toList()
      ..sort();

    if (opusFiles.isEmpty) {
      throw Exception('No opus files found after encoding');
    }

    for (int audiobookNum = 1; audiobookNum <= numAudiobooks; audiobookNum++) {
      final startChapter = (audiobookNum - 1) * chaptersPerBook;
      var endChapter = startChapter + chaptersPerBook - 1;
      if (endChapter >= totalChapters) {
        endChapter = totalChapters - 1;
      }

      final currentTitle = numAudiobooks > 1
          ? '${title}_$audiobookNum'
          : title;

      final audiobookOpusFiles = opusFiles.sublist(startChapter, endChapter + 1);

      final progressBase = 0.85 + ((audiobookNum - 1) / numAudiobooks) * 0.1;
      final progressRange = 0.1 / numAudiobooks;

      onProgress(
        numAudiobooks > 1
            ? 'Creating audiobook $audiobookNum/$numAudiobooks: VTT subtitles...'
            : 'Creating VTT subtitle file...',
        progressBase
      );

      final stitchedVttPath = path.join(outputDir, timestamp, '$author - $currentTitle.vtt');
      await _stitchVttFiles(
        encodedDir: encodedDir.path,
        outputPath: stitchedVttPath,
        opusFiles: audiobookOpusFiles,
      );

      onProgress(
        numAudiobooks > 1
            ? 'Creating audiobook $audiobookNum/$numAudiobooks: ${audiobookOpusFiles.length} chapters...'
            : 'Creating final audiobook...',
        progressBase + progressRange * 0.5
      );

      final finalAudiobookPath = path.join(outputDir, timestamp, '$author - $currentTitle.opus');
      await _createFinalAudiobook(
        encodedDir: encodedDir.path,
        author: author,
        title: currentTitle,
        bitrate: bitrate,
        outputPath: finalAudiobookPath,
        opusFiles: audiobookOpusFiles,
        chapters: chapters,
        startChapterIndex: startChapter,
        audioRepetitions: audioRepetitions,
      );
    }

    onProgress('Cleaning up temporary files...', 0.98);
    try {
      if (await vttDir.exists()) {
        await vttDir.delete(recursive: true);
        print('Deleted temporary vtt directory: ${vttDir.path}');
      }
    } catch (e) {
      print('Warning: Could not delete vtt directory: $e');
    }

    await Future.delayed(const Duration(milliseconds: 100));
    onProgress('Complete!', 1.0);
  }

  Future<void> _copyOrConvertAudio(String inputPath, String outputPath) async {
    await _ffmpeg.ensureBinaries();

    final result = await Process.run(_ffmpeg.ffmpegPath!, [
      '-y',
      '-i', inputPath,
      '-c:a', 'libopus',
      '-b:a', '32k',
      outputPath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('Failed to convert $inputPath: ${result.stderr}');
    }
  }

  Future<void> _repeatAudio(String inputPath, String outputPath, int times) async {
    await _ffmpeg.ensureBinaries();

    final result = await Process.run(_ffmpeg.ffmpegPath!, [
      '-y',
      '-stream_loop', '${times - 1}',
      '-i', inputPath,
      '-c:a', 'libopus',
      '-b:a', '32k',
      outputPath,
    ]);

    if (result.exitCode != 0) {
      throw Exception('Failed to repeat $inputPath: ${result.stderr}');
    }
  }

  Future<void> _encodeToOpusParallel({
    required List<File> mp3Files,
    required Directory outputDir,
    required int bitrate,
    required Function(int current, int total) onProgress,
  }) async {
    await _ffmpeg.ensureBinaries();

    final cpuCount = Platform.numberOfProcessors;
    final maxConcurrent = (cpuCount * 0.75).round().clamp(1, 8);

    int completed = 0;
    final futures = <Future>[];
    final semaphore = _Semaphore(maxConcurrent);

    for (final file in mp3Files) {
      final future = semaphore.acquire().then((_) async {
        try {
          final basename = path.basenameWithoutExtension(file.path);
          final outputPath = path.join(outputDir.path, '$basename.opus');

          final opusApplication = bitrate == 12 ? 'voip' : 'audio';

          await Process.run(_ffmpeg.ffmpegPath!, [
            '-y',
            '-i', file.path,
            '-c:a', 'libopus',
            '-application', opusApplication,
            '-frame_duration', '60',
            '-b:a', '${bitrate}k',
            '-af', 'dynaudnorm=f=250:g=31:p=0.5:m=5:r=0.9:b=1',
            outputPath,
          ]);

          completed++;
          onProgress(completed, mp3Files.length);
        } finally {
          semaphore.release();
        }
      });

      futures.add(future);
    }

    await Future.wait(futures);
  }

  Future<void> _createVttFile({
    required String vttPath,
    required String front,
    required String back,
    required Duration duration,
    required int repetitions,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();

    if (repetitions == 1) {
      buffer.writeln('00:00:00.000 --> ${_formatTimestamp(duration)}');
      buffer.writeln(front);
    } else {
      final frontRepetitions = _getFrontRepetitions(repetitions);
      final frontDurationMs = (duration.inMilliseconds * frontRepetitions / repetitions).round();
      final frontDuration = Duration(milliseconds: frontDurationMs);

      buffer.writeln('00:00:00.000 --> ${_formatTimestamp(frontDuration)}');
      buffer.writeln(front);
      buffer.writeln();
      buffer.writeln('${_formatTimestamp(frontDuration)} --> ${_formatTimestamp(duration)}');
      buffer.writeln(back);
    }

    await File(vttPath).writeAsString(buffer.toString());
  }

  int _getFrontRepetitions(int total) {
    switch (total) {
      case 1: return 0;
      case 2: return 1;
      case 3: return 2;
      case 4: return 2;
      case 5: return 3;
      case 6: return 3;
      default: return 0;
    }
  }

  String _formatTimestamp(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final ms = d.inMilliseconds.remainder(1000);

    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}.'
           '${ms.toString().padLeft(3, '0')}';
  }

  Future<void> _createFinalAudiobook({
    required String encodedDir,
    required String author,
    required String title,
    required int bitrate,
    required String outputPath,
    required List<String> opusFiles,
    required List<Map<String, dynamic>> chapters,
    required int startChapterIndex,
    required int audioRepetitions,
  }) async {
    if (opusFiles.isEmpty) {
      throw Exception('No opus files found');
    }

    await _ffmpeg.concatenateWithChapters(
      opusFiles: opusFiles,
      outputPath: outputPath,
      config: EncodingConfig(
        bitrate: bitrate,
        author: author,
        title: title,
        year: DateTime.now().year.toString(),
      ),
      chapters: chapters,
      startChapterIndex: startChapterIndex,
      audioRepetitions: audioRepetitions,
      onProgress: (message) {
        print(message);
      },
    );
  }
}

class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final List<Completer<void>> _queue = [];

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
