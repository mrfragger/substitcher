import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StatsManager {
  bool statsEnabled = true;
  String statsDataDir = '';
  Map<String, int> chapterTimeCache = {};
  List<Map<String, dynamic>> statsEntries = [];
  DateTime? chapterStartTime;
  DateTime? sessionStartTime;
  int accumulatedSeconds = 0;
  
  Future<void> initialize() async {
    await loadStatsEnabled();
    await initStatsDirectory();
    await loadCacheFromPrefs();
    await flushCacheToLog();
    await loadAllStatsEntries();
  }
  
  Future<void> initStatsDirectory() async {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return;
    
    statsDataDir = '$home/.config/substitcher/watch_tracking_time';
    
    final dir = Directory(statsDataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
  
  Future<void> loadStatsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    statsEnabled = prefs.getBool('statsEnabled') ?? true;
  }
  
  Future<void> saveStatsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('statsEnabled', enabled);
    statsEnabled = enabled;
  }
  
  String getDateString() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  }
  
  String getLogFilePath() {
    return '$statsDataDir/${getDateString()}_tracked_time.jsonl';
  }
  
  Future<void> appendToStatsLog(Map<String, dynamic> entry) async {
    if (!statsEnabled) return;
    
    final logPath = getLogFilePath();
    final file = File(logPath);
    
    try {
      final jsonStr = jsonEncode(entry);
      await file.writeAsString('$jsonStr\n', mode: FileMode.append);
    } catch (e) {
      print('Error writing stats log: $e');
    }
  }
  
  Future<void> saveCacheToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = jsonEncode(chapterTimeCache);
    await prefs.setString('chapterTimeCache', cacheJson);
  }
  
  Future<void> loadCacheFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString('chapterTimeCache');
    
    if (cacheJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cacheJson);
        chapterTimeCache.clear();
        decoded.forEach((key, value) {
          chapterTimeCache[key] = value as int;
        });
      } catch (e) {
        print('Error loading cache: $e');
      }
    }
  }
  
  Future<void> flushCacheToLog() async {
    if (chapterTimeCache.isEmpty) return;
    
    final logPath = getLogFilePath();
    final file = File(logPath);
    
    try {
      final buffer = StringBuffer();
      final keysToRemove = <String>[]; 
      
      for (final cacheKey in chapterTimeCache.keys) {
        final duration = chapterTimeCache[cacheKey]!;
        
        if (duration >= 30) {
          final parts = cacheKey.split('|');
          if (parts.length == 3) {
            final entry = {
              'filename': parts[0],
              'chapter_name': parts[1],
              'listened_duration': duration,
              'datetime': parts[2],
            };
            
            buffer.writeln(jsonEncode(entry));
            print('📊 Flushed from cache: ${entry['chapter_name']} - ${entry['listened_duration']}s');
            keysToRemove.add(cacheKey); 
          }
        }
      }
      
      if (buffer.isNotEmpty) {
        await file.writeAsString(buffer.toString(), mode: FileMode.append, flush: true);
      }
      
      // Only remove the keys that were actually flushed
      for (final key in keysToRemove) {
        chapterTimeCache.remove(key);
      }
      
      await saveCacheToPrefs();
    } catch (e) {
      print('Error flushing cache: $e');
    }
  }
  
  String generateCacheKey(String audiobookPath, String chapterTitle, DateTime? startTime) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(startTime ?? DateTime.now());
    return '${audiobookPath}|$chapterTitle|$timestamp';
  }
  
  Future<void> loadAllStatsEntries() async {
    final dir = Directory(statsDataDir);
    if (!await dir.exists()) {
      statsEntries = [];
      return;
    }
    
    final entries = <Map<String, dynamic>>[];
    
    await for (final file in dir.list()) {
      if (file is File && file.path.endsWith('_tracked_time.jsonl')) {
        try {
          final lines = await file.readAsLines();
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            final entry = jsonDecode(line) as Map<String, dynamic>;
            entries.add(entry);
          }
        } catch (e) {
          print('Error reading stats file ${file.path}: $e');
        }
      }
    }
    
    statsEntries = entries;
  }
  
  void recordChapterStart() {
    chapterStartTime = DateTime.now();
    accumulatedSeconds = 0;
    sessionStartTime = null;
  }
  
  void onPlaybackStart() {
    if (!statsEnabled || chapterStartTime == null) return;
    sessionStartTime = DateTime.now();
  }
  
  void onPlaybackPause() {
    if (!statsEnabled || sessionStartTime == null) return;
    final elapsed = DateTime.now().difference(sessionStartTime!);
    accumulatedSeconds += elapsed.inSeconds;
    sessionStartTime = null;
  }
  
  int getCurrentAccumulatedTime() {
    int total = accumulatedSeconds;
    if (sessionStartTime != null) {
      final currentSession = DateTime.now().difference(sessionStartTime!);
      total += currentSession.inSeconds;
    }
    return total;
  }
  
  Future<void> recordChapterEnd(String audiobookPath, String chapterTitle) async {
    if (!statsEnabled || chapterStartTime == null) return;
    
    if (sessionStartTime != null) {
      final elapsed = DateTime.now().difference(sessionStartTime!);
      accumulatedSeconds += elapsed.inSeconds;
      sessionStartTime = null;
    }
    
    if (accumulatedSeconds >= 30) {
      final cacheKey = generateCacheKey(audiobookPath, chapterTitle, chapterStartTime);
      chapterTimeCache[cacheKey] = accumulatedSeconds;
      await saveCacheToPrefs();
    }
    
    accumulatedSeconds = 0;
  }

  String getLogFilePathForDate(DateTime date) {
    final dateString = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return '$statsDataDir/${dateString}_tracked_time.jsonl';
  }
  
  Future<void> deleteAudiobookFromDate(String filename, DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final logPath = getLogFilePathForDate(date);
    final file = File(logPath);
    
    if (!await file.exists()) return;
    
    try {
      final lines = await file.readAsLines();
      final filteredLines = <String>[];
      
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        try {
          final entry = jsonDecode(line) as Map<String, dynamic>;
          final entryFilename = entry['filename'] as String?;
          final entryDatetime = entry['datetime'] as String?;
          
          if (entryFilename != filename || 
              entryDatetime == null || 
              !entryDatetime.startsWith(dateStr)) {
            filteredLines.add(line);
          }
        } catch (e) {
          filteredLines.add(line);
        }
      }
      
      if (filteredLines.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(filteredLines.join('\n') + '\n');
      }
      
      await loadAllStatsEntries();
    } catch (e) {
      print('Error deleting audiobook entries: $e');
    }
  }
}