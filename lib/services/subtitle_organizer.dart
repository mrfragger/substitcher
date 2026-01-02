import 'dart:io';
import 'package:path/path.dart' as path;

class SubtitleOrganizer {
  static Future<void> organizeSubtitles(String audiobookPath) async {
    final audiobookFile = File(audiobookPath);
    if (!await audiobookFile.exists()) {
      throw Exception('Audiobook file not found: $audiobookPath');
    }

    final dir = path.dirname(audiobookPath);
    final baseName = path.basenameWithoutExtension(audiobookPath);
    
    final subDir = Directory(path.join(dir, '${baseName}_vtt'));
    if (!await subDir.exists()) {
      await subDir.create();
      print('Created subtitle directory: ${subDir.path}');
    }

    final parentDir = Directory(dir);
    final allFiles = await parentDir.list().toList();

    int movedCount = 0;
    
    for (final entity in allFiles) {
      if (entity is File) {
        final fileName = path.basename(entity.path);
        final fileExt = path.extension(fileName).toLowerCase();
        
        if (fileExt != '.srt' && fileExt != '.vtt' && fileExt != '.vtc') {
          continue;
        }
        
        if (_isSubtitleForAudiobook(fileName, baseName)) {
          final targetPath = path.join(subDir.path, fileName);
          
          if (entity.path == targetPath) {
            continue;
          }
          
          try {
            await entity.rename(targetPath);
            print('Moved: $fileName -> ${path.basename(subDir.path)}/$fileName');
            movedCount++;
          } catch (e) {
            print('Error moving ${fileName}: $e');
          }
        }
      }
    }
    
    if (movedCount > 0) {
      print('Organized $movedCount subtitle files into ${subDir.path}');
    }
  }

  static Future<void> organizeAllSubtitlesInDirectory(String directoryPath) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      throw Exception('Directory not found: $directoryPath');
    }
  
    print('Organizing all subtitles in directory: $directoryPath');
    
    final allEntities = await dir.list().toList();
    final opusFiles = <String>[];
    final subtitleFiles = <File>[];
    
    print('Total entities found: ${allEntities.length}');
    
    for (final entity in allEntities) {
      print('Entity: ${entity.path} (${entity.runtimeType})');
      
      if (entity is File) {
        final fileName = path.basename(entity.path);
        final ext = path.extension(entity.path).toLowerCase();
        print('  File: $fileName, Extension: $ext');
        
        if (ext == '.opus') {
          opusFiles.add(entity.path);
          print('    -> Added to opus files');
        } else if (ext == '.srt' || ext == '.vtt' || ext == '.vtc') {
          subtitleFiles.add(entity);
          print('    -> Added to subtitle files');
        }
      }
    }
    
    print('Found ${opusFiles.length} opus files and ${subtitleFiles.length} subtitle files');
    
    int totalMoved = 0;
    
    for (final subtitleFile in subtitleFiles) {
      final subtitleName = path.basename(subtitleFile.path);
      final subtitleBase = path.basenameWithoutExtension(subtitleName);
      
      String? matchedOpus;
      for (final opusPath in opusFiles) {
        final opusBase = path.basenameWithoutExtension(opusPath);
        if (subtitleBase == opusBase || _isSubtitleForAudiobook(subtitleName, opusBase)) {
          matchedOpus = opusPath;
          break;
        }
      }
      
      if (matchedOpus != null) {
        final opusBase = path.basenameWithoutExtension(matchedOpus);
        final subDir = Directory(path.join(directoryPath, '${opusBase}_vtt'));
        
        if (!await subDir.exists()) {
          await subDir.create();
          print('Created subtitle directory: ${subDir.path}');
        }
        
        final targetPath = path.join(subDir.path, subtitleName);
        
        if (subtitleFile.path != targetPath) {
          try {
            await subtitleFile.rename(targetPath);
            print('Moved: $subtitleName -> ${opusBase}_vtt/$subtitleName');
            totalMoved++;
          } catch (e) {
            print('Error moving $subtitleName: $e');
          }
        }
      } else {
        print('No matching opus file found for: $subtitleName');
      }
    }
    
    print('Finished organizing: moved $totalMoved subtitle files');
  }

  static bool _isSubtitleForAudiobook(String subtitleFileName, String audiobookBaseName) {
    final subtitleBase = path.basenameWithoutExtension(subtitleFileName);
    
    if (subtitleBase == audiobookBaseName) {
      return true;
    }
    
    if (subtitleBase.startsWith('$audiobookBaseName.') || 
        subtitleBase.startsWith('${audiobookBaseName}_')) {
      return true;
    }
    
    final normalizedSubtitle = _normalize(subtitleBase);
    final normalizedAudiobook = _normalize(audiobookBaseName);
    
    if (normalizedSubtitle == normalizedAudiobook) {
      return true;
    }
    
    final similarity = _calculateSimilarity(normalizedSubtitle, normalizedAudiobook);
    
    return similarity >= 0.98;
  }

  static String _normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    final shorter = s1.length < s2.length ? s1 : s2;
    final longer = s1.length < s2.length ? s2 : s1;
    
    if (longer.contains(shorter)) {
      return shorter.length / longer.length;
    }
    
    final distance = _levenshteinDistance(s1, s2);
    final maxLength = s1.length > s2.length ? s1.length : s2.length;
    
    return 1.0 - (distance / maxLength);
  }

  static int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    
    final matrix = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );
    
    for (int i = 0; i <= len1; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= len2; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[len1][len2];
  }

  static String getSubtitleDirectory(String audiobookPath) {
    final dir = path.dirname(audiobookPath);
    final baseName = path.basenameWithoutExtension(audiobookPath);
    return path.join(dir, '${baseName}_vtt');
  }

  static Future<String?> findSubtitleInDirectory(String audiobookPath, {String? suffix}) async {
    final subDir = getSubtitleDirectory(audiobookPath);
    final directory = Directory(subDir);
    
    if (!await directory.exists()) {
      return null;
    }
    
    final baseName = path.basenameWithoutExtension(audiobookPath);
    
    String searchName;
    if (suffix != null && suffix.isNotEmpty) {
      searchName = '$baseName$suffix';
    } else {
      searchName = baseName;
    }
    
    for (final ext in ['.vtt', '.srt', '.vtc']) {
      final filePath = path.join(subDir, '$searchName$ext');
      if (await File(filePath).exists()) {
        return filePath;
      }
    }
    
    return null;
  }

  static Future<List<String>> listSubtitlesInDirectory(String audiobookPath) async {
    final subDir = getSubtitleDirectory(audiobookPath);
    final directory = Directory(subDir);
    
    if (!await directory.exists()) {
      return [];
    }
    
    final files = await directory.list().toList();
    final subtitles = <String>[];
    
    for (final entity in files) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (ext == '.vtt' || ext == '.srt' || ext == '.vtc') {
          subtitles.add(entity.path);
        }
      }
    }
    
    subtitles.sort();
    return subtitles;
  }
}