import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class YouTubeService {
  static String? _ytdlpPath;

  static String? get ytdlpPath => _ytdlpPath;
  
  static Future<bool> isYtdlpAvailable() async {
    final paths = [
      '/opt/homebrew/bin/yt-dlp',
      '/usr/local/bin/yt-dlp',
      'yt-dlp',
    ];
    
    for (final ytdlp in paths) {
      try {
        final result = await Process.run(ytdlp, ['--version']);
        if (result.exitCode == 0) {
          _ytdlpPath = ytdlp;
          return true;
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  static Future<String?> getChannelName(String youtubeUrl) async {
    if (_ytdlpPath == null && !await isYtdlpAvailable()) {
      return null;
    }
    
    final result = await Process.run(_ytdlpPath!, [
      '--get-filename',
      '-o', '%(channel)s',
      '--no-playlist',
      youtubeUrl,
    ]);
    
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return null;
  }
  
  static Future<String?> getAudioStreamUrl(String youtubeUrl) async {
    if (_ytdlpPath == null && !await isYtdlpAvailable()) {
      throw Exception('yt-dlp not found. Please install yt-dlp.');
    }
    
    final result = await Process.run(_ytdlpPath!, [
      '-f', 'bestaudio',
      '-g',
      '--no-playlist',
      youtubeUrl,
    ]);
    
    if (result.exitCode != 0) {
      throw Exception('Failed to get audio stream: ${result.stderr}');
    }
    
    return result.stdout.toString().trim();
  }
  
  static Future<String> getVideoTitle(String youtubeUrl) async {
    if (_ytdlpPath == null && !await isYtdlpAvailable()) {
      throw Exception('yt-dlp not found');
    }
    
    final result = await Process.run(_ytdlpPath!, [
      '--get-title',
      '--no-playlist',
      youtubeUrl,
    ]);
    
    if (result.exitCode == 0) {
      return result.stdout.toString().trim();
    }
    return 'YouTube Audio';
  }

  static Future<String?> downloadAutoTranslatedSubtitles(
    String youtubeUrl,
    String outputDir,
    String sourceLang,
    String targetLang,
  ) async {
    if (_ytdlpPath == null && !await isYtdlpAvailable()) {
      throw Exception('yt-dlp not found');
    }
    
    await _cleanupOldSubtitles(outputDir);
    
    final title = await getVideoTitle(youtubeUrl);
    final safeTitle = YouTubeService.sanitizeFilename(title);
    
    print('Downloading auto-translated subtitle: $sourceLang -> $targetLang');
    print('Safe title: $safeTitle');
    print('Output dir: $outputDir');
    
    final result = await Process.run(_ytdlpPath!, [
      '--write-auto-sub',
      '--sub-lang', targetLang,
      '--sub-format', 'vtt',
      '--skip-download',
      '--no-playlist',
      '-o', path.join(outputDir, '$safeTitle.%(ext)s'),
      youtubeUrl,
    ]);
    
    print('Download exit code: ${result.exitCode}');
    print('stdout: ${result.stdout}');
    print('stderr: ${result.stderr}');
    
    final stdoutStr = result.stdout.toString();
    final stderrStr = result.stderr.toString();
    
    if (stdoutStr.contains('There are no subtitles for the requested languages')) {
      print('No subtitles available for $targetLang');
      return null;
    }
    
    if (stderrStr.contains('429') || stderrStr.contains('Too Many Requests')) {
      print('Rate limited by YouTube. Please wait a moment and try again.');
      return null;
    }
    
    await Future.delayed(const Duration(seconds: 1));
    
    String? subtitlePath;
    
    await for (final entity in Directory(outputDir).list()) {
      if (entity is File) {
        final name = path.basename(entity.path);
        
        if (name.endsWith('.$targetLang.vtt') && !name.contains('.ytfixed')) {
          subtitlePath = entity.path;
          print('Found subtitle file: $subtitlePath');
          break;
        }
      }
    }
    
    if (subtitlePath == null) {
      print('Could not find downloaded subtitle file');
      return null;
    }
    
    try {
      final fixedPath = await fixYouTubeSubtitles(subtitlePath);
      print('Fixed subtitle path: $fixedPath');
      return fixedPath;
    } catch (e) {
      print('Error fixing subtitles: $e');
      return subtitlePath;
    }
  }
  
  static Future<String?> downloadAndFixSubtitles(
    String youtubeUrl, 
    String outputDir,
    {String lang = 'en', String? translateTo}
  ) async {
    if (_ytdlpPath == null && !await isYtdlpAvailable()) {
      throw Exception('yt-dlp not found');
    }
    
    await _cleanupOldSubtitles(outputDir);
    
    final title = await getVideoTitle(youtubeUrl);
    final safeTitle = YouTubeService.sanitizeFilename(title);
    
    print('Attempting to download subtitle: $lang');
    if (translateTo != null) {
      print('With auto-translate to: $translateTo');
    }
    print('Safe title: $safeTitle');
    
    ProcessResult? result;
    
    final subLangArg = translateTo != null ? '$translateTo-$lang' : lang;
    
    result = await Process.run(_ytdlpPath!, [
      '--write-auto-sub',
      '--sub-lang', subLangArg,
      '--sub-format', 'vtt',
      '--skip-download',
      '--no-playlist',
      '--no-warnings',
      '-o', path.join(outputDir, '$safeTitle.%(ext)s'),
      youtubeUrl,
    ]);
    
    final autoStdout = result.stdout.toString();
    
    print('Auto-sub exit code: ${result.exitCode}');
    
    bool downloadedAuto = autoStdout.contains('Writing video subtitles') || 
                         autoStdout.contains('Downloading subtitles');
    
    if (!downloadedAuto) {
      print('Auto-sub output: $autoStdout');
      print('Trying manual subtitles...');
      
      result = await Process.run(_ytdlpPath!, [
        '--write-sub',
        '--sub-lang', subLangArg,
        '--sub-format', 'vtt',
        '--skip-download',
        '--no-playlist',
        '--no-warnings',
        '-o', path.join(outputDir, '$safeTitle.%(ext)s'),
        youtubeUrl,
      ]);
      
      final manualStdout = result.stdout.toString();
      print('Manual sub exit code: ${result.exitCode}');
      print('Manual sub output: $manualStdout');
      
      if (!manualStdout.contains('Writing video subtitles') && 
          !manualStdout.contains('Downloading subtitles')) {
        print('No subtitles were actually downloaded');
        return null;
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    final searchLang = translateTo ?? lang;
    print('Looking for subtitle files with pattern: $safeTitle.*.$searchLang*.vtt');
    final dir = Directory(outputDir);
    String? subtitlePath;
    
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = path.basename(entity.path);
        
        if (name.startsWith(safeTitle) && 
            name.endsWith('.vtt') &&
            !name.contains('.ytfixed') &&
            (name.contains('.$searchLang.') || 
             name.contains('.$searchLang-') ||
             name.contains('-$searchLang.'))) {
          subtitlePath = entity.path;
          print('Found subtitle file: $subtitlePath');
          break;
        }
      }
    }
    
    if (subtitlePath == null) {
      print('Could not find downloaded subtitle file');
      return null;
    }
    
    try {
      final fixedPath = await fixYouTubeSubtitles(subtitlePath);
      print('Fixed subtitle path: $fixedPath');
      return fixedPath;
    } catch (e) {
      print('Error fixing subtitles: $e');
      return subtitlePath;
    }
  }
  
  static Future<void> _cleanupOldSubtitles(String outputDir, {String? keepTitle}) async {
    try {
      final dir = Directory(outputDir);
      if (!await dir.exists()) {
        return;
      }
      
      final now = DateTime.now();
      final files = await dir.list().toList();
      
      print('Cleaning up old subtitle files (${files.length} files)...');
      
      int deletedCount = 0;
      for (final entity in files) {
        if (entity is File) {
          try {
            final name = path.basename(entity.path);
            
            if (keepTitle != null && name.startsWith(keepTitle)) {
              continue;
            }
            
            final stat = await entity.stat();
            final age = now.difference(stat.modified);
            
            if (age.inHours > 24) {
              await entity.delete();
              deletedCount++;
            }
          } catch (e) {
            print('Error deleting file ${entity.path}: $e');
          }
        }
      }
      
      if (deletedCount > 0) {
        print('Deleted $deletedCount old subtitle files');
      }
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  static Future<List<Map<String, dynamic>>?> getVideoChapters(String youtubeUrl) async {
    if (_ytdlpPath == null && !await isYtdlpAvailable()) {
      return null;
    }
    
    try {
      final result = await Process.run(_ytdlpPath!, [
        '--dump-json',
        '--no-playlist',
        youtubeUrl,
      ]);
      
      if (result.exitCode != 0) {
        return null;
      }
      
      final jsonStr = result.stdout.toString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      if (data.containsKey('chapters') && data['chapters'] != null) {
        return List<Map<String, dynamic>>.from(data['chapters']);
      }
      
      return null;
    } catch (e) {
      print('Error getting chapters: $e');
      return null;
    }
  }

  static Future<List<Map<String, String>>> getAvailableSubtitles(
    String youtubeUrl,
    List<String> enabledLanguages,
  ) async {
    if (_ytdlpPath == null && !await isYtdlpAvailable()) {
      throw Exception('yt-dlp not found');
    }
    
    final subtitles = <Map<String, String>>[];
    
    for (final langCode in enabledLanguages) {
      final langName = _getLanguageName(langCode);
      subtitles.add({
        'code': langCode,
        'name': langName,
        'type': 'user-enabled',
      });
    }
    
    return subtitles;
  }
  
  static String _getLanguageName(String code) {
    const nameMap = {
      'en': 'English',
      'ar': 'Arabic',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese (Simplified)',
      'zh-Hant': 'Chinese (Traditional)',
      'ru': 'Russian',
      'pt': 'Portuguese',
      'hi': 'Hindi',
      'it': 'Italian',
      'tr': 'Turkish',
      'nl': 'Dutch',
      'pl': 'Polish',
      'uk': 'Ukrainian',
      'vi': 'Vietnamese',
      'th': 'Thai',
      'id': 'Indonesian',
      'he': 'Hebrew',
      'iw': 'Hebrew',
      'fa': 'Persian',
      'ur': 'Urdu',
      'bn': 'Bengali',
      'ta': 'Tamil',
      'te': 'Telugu',
      'sw': 'Swahili',
    };
    
    return nameMap[code] ?? code.toUpperCase();
  }
  
  static Future<String> fixYouTubeSubtitles(String inputPath) async {
    final content = await File(inputPath).readAsString();
    final lines = content.split('\n');
    
    final cues = <_SubtitleCue>[];
    String? currentStart;
    String? currentEnd;
    final textBuffer = <String>[];
    
    for (var line in lines) {
      line = line.trim();
      
      if (line == 'WEBVTT' || line.startsWith('NOTE') || line.startsWith('Kind:') || line.startsWith('Language:')) {
        continue;
      }
      
      if (RegExp(r'^\d+$').hasMatch(line)) {
        continue;
      }
      
      if (line.contains('-->')) {
        if (currentStart != null && textBuffer.isNotEmpty) {
          final text = textBuffer.join(' ').trim();
          if (text.isNotEmpty) {
            cues.add(_SubtitleCue(
              startTime: _normalizeTimecode(currentStart!),
              endTime: _normalizeTimecode(currentEnd!),
              text: _cleanText(text),
            ));
          }
        }
        
        final parts = line.split('-->');
        if (parts.length == 2) {
          currentStart = parts[0].trim().split(' ')[0];
          currentEnd = parts[1].trim().split(' ')[0];
        }
        textBuffer.clear();
      } else if (line.isNotEmpty && currentStart != null) {
        textBuffer.add(line);
      }
    }
    
    if (currentStart != null && textBuffer.isNotEmpty) {
      final text = textBuffer.join(' ').trim();
      if (text.isNotEmpty) {
        cues.add(_SubtitleCue(
          startTime: _normalizeTimecode(currentStart!),
          endTime: _normalizeTimecode(currentEnd!),
          text: _cleanText(text),
        ));
      }
    }
    
    var baseName = path.basenameWithoutExtension(inputPath);
    final dir = path.dirname(inputPath);
    
    while (baseName.contains('.ytfixed')) {
      baseName = baseName.replaceAll('.ytfixed', '');
    }
    
    final outputPath = path.join(dir, '$baseName.ytfixed.vtt');
    
    if (cues.isEmpty) {
      final output = StringBuffer();
      output.writeln('WEBVTT');
      output.writeln();
      await File(outputPath).writeAsString(output.toString());
      return outputPath;
    }
    
    final processedCues = <_SubtitleCue>[];
    
    for (int i = 0; i < cues.length; i++) {
      final current = cues[i];
      String newText = current.text;
      
      if (i > 0 && newText.isNotEmpty) {
        final prev = cues[i - 1];
        
        if (prev.text.isNotEmpty) {
          int overlapLength = 0;
          final prevLen = prev.text.length;
          final currLen = current.text.length;
          final maxOverlap = prevLen < currLen ? prevLen : currLen;
          
          for (int len = maxOverlap; len >= 3; len--) {
            if (len <= prevLen && len <= currLen) {
              final suffix = prev.text.substring(prevLen - len);
              if (current.text.startsWith(suffix)) {
                overlapLength = len;
                break;
              }
            }
          }
          
          if (overlapLength > 0 && overlapLength < currLen) {
            newText = current.text.substring(overlapLength).trim();
          }
        }
      }
      
      if (newText.isNotEmpty) {
        processedCues.add(_SubtitleCue(
          startTime: current.startTime,
          endTime: current.endTime,
          text: newText,
        ));
      }
    }
    
    final mergedCues = <_SubtitleCue>[];
    for (final cue in processedCues) {
      if (mergedCues.isEmpty) {
        mergedCues.add(cue);
      } else {
        final lastCue = mergedCues.last;
        if (lastCue.text == cue.text) {
          mergedCues[mergedCues.length - 1] = _SubtitleCue(
            startTime: lastCue.startTime,
            endTime: cue.endTime,
            text: lastCue.text,
          );
        } else {
          mergedCues.add(cue);
        }
      }
    }
    
    final output = StringBuffer();
    output.writeln('WEBVTT');
    output.writeln();
    
    for (final cue in mergedCues) {
      output.writeln('${cue.startTime} --> ${cue.endTime}');
      output.writeln(cue.text);
      output.writeln();
    }
    
    await File(outputPath).writeAsString(output.toString());
    
    return outputPath;
  }
  
  static String _normalizeTimecode(String timecode) {
    timecode = timecode.trim();
    
    final colonCount = ':'.allMatches(timecode).length;
    
    if (colonCount == 1) {
      // MM:SS.mmm format -> add 00:
      return '00:$timecode';
    } else if (colonCount == 2) {
      // Already HH:MM:SS.mmm format
      return timecode;
    }
    
    return timecode;
  }
  
  static String _cleanText(String text) {
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    
    text = text.replaceAll(RegExp(r'<\d{2}:\d{2}:\d{2}\.\d{3}>'), '');
    
    text = text
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&lsquo;', ''')
        .replaceAll('&rsquo;', ''')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"')
        .replaceAll('&hellip;', '…');
    
    // Decode numeric HTML entities (&#123; or &#x7B;)
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1)!);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });
    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });
    
    text = text.replaceAll(RegExp(r'^[>\s]+'), '');
    text = text.replaceAll(RegExp(r'\s*>>\s*'), ' ');
    
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    
    text = text.trim();
    
    return text;
  }

  static String sanitizeFilename(String filename) {
    final sanitized = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    
    return sanitized.length > 100 
        ? sanitized.substring(0, 100) 
        : sanitized;
  }
  
  static bool isYouTubeUrl(String text) {
    final patterns = [
      RegExp(r'^https?://(www\.)?youtube\.com/watch\?v='),
      RegExp(r'^https?://youtu\.be/'),
      RegExp(r'^https?://(www\.)?youtube\.com/shorts/'),
      RegExp(r'^https?://music\.youtube\.com/watch\?v='),
      RegExp(r'^https?://(www\.)?youtube\.com/@[^/]+/videos'),
      RegExp(r'^https?://(www\.)?youtube\.com/c/[^/]+/videos'),
      RegExp(r'^https?://(www\.)?youtube\.com/channel/[^/]+/videos'),
      RegExp(r'^https?://(www\.)?youtube\.com/user/[^/]+/videos'),
      RegExp(r'^https?://(www\.)?youtube\.com/playlist\?list='), 
    ];
    
    return patterns.any((pattern) => pattern.hasMatch(text.trim()));
  }
  
  static String? extractVideoId(String url) {
    var match = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (match != null) return match.group(1);
    
    match = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (match != null) return match.group(1);
    
    match = RegExp(r'shorts/([a-zA-Z0-9_-]{11})').firstMatch(url);
    if (match != null) return match.group(1);
    
    return null;
  }
}

class _SubtitleCue {
  final String startTime;
  final String endTime;
  final String text;
  
  _SubtitleCue({
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}