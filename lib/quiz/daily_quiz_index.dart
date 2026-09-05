import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:shared_preferences/shared_preferences.dart';

class DailyQuizEntry {
  final DateTime date;
  final String title;
  DailyQuizEntry({required this.date, required this.title});
}

class DailyQuizIndex {
  static const String _assetDir = 'assets/daily_quiz';
  static List<DateTime>? _cachedDates;
  static List<DailyQuizEntry>? _cachedEntries;

  static Future<List<DateTime>> _availableDates() async {
    if (_cachedDates != null) return _cachedDates!;
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    final dateRe = RegExp(r'(\d{4}-\d{2}-\d{2})\.json$');
    final dates = <DateTime>[];
    for (final key in assets) {
      if (!key.startsWith(_assetDir)) continue;
      final m = dateRe.firstMatch(key);
      if (m == null) continue;
      final parsed = DateTime.tryParse(m.group(1)!);
      if (parsed != null) dates.add(parsed);
    }
    dates.sort();
    _cachedDates = dates;
    return dates;
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static Future<Map<String, dynamic>> loadDay(DateTime date) async {
    final path = '$_assetDir/${_fmt(date)}.json';
    final str = await rootBundle.loadString(path);
    return json.decode(str) as Map<String, dynamic>;
  }

  static Future<List<DailyQuizEntry>> availableEntries() async {
    if (_cachedEntries != null) return _cachedEntries!;
    final dates = await _availableDates();
    final entries = <DailyQuizEntry>[];
    for (final d in dates) {
      try {
        final dayJson = await loadDay(d);
        final ded = dayJson['deduction'];
        if (ded is Map && ded['title'] != null) {
          entries.add(DailyQuizEntry(date: d, title: ded['title'] as String));
        }
      } catch (_) {
        // skip malformed/missing files
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    _cachedEntries = entries;
    return entries;
  }
}

class DailyQuizPrefs {
  static const _key = 'lastQuizDate';

  static Future<void> saveLastDate(DateTime d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DailyQuizIndex._fmt(d));
  }

  static Future<DateTime?> loadLastDate() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }
}

class ConnectionsEntry {
  final DateTime date;
  final int categoryCount;
  ConnectionsEntry({required this.date, required this.categoryCount});
}

class ConnectionsIndex {
  static List<ConnectionsEntry>? _cachedEntries;

  static Future<List<ConnectionsEntry>> availableEntries() async {
    if (_cachedEntries != null) return _cachedEntries!;
    final dates = await DailyQuizIndex._availableDates();
    final entries = <ConnectionsEntry>[];
    for (final d in dates) {
      try {
        final dayJson = await DailyQuizIndex.loadDay(d);
        final conn = dayJson['connections'];
        final cats = conn is Map ? conn['categories'] : null;
        if (cats is List && cats.isNotEmpty) {
          entries.add(ConnectionsEntry(date: d, categoryCount: cats.length));
        }
      } catch (_) {
        // skip malformed/missing files
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    _cachedEntries = entries;
    return entries;
  }
}

class ConnectionsPrefs {
  static const _key = 'lastConnectionsDate';

  static Future<void> saveLastDate(DateTime d) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, DailyQuizIndex._fmt(d));
  }

  static Future<DateTime?> loadLastDate() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_key);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }
}

class QuizSelectionPrefs {
  static String _key(DateTime date) =>
      'quizSel_${DailyQuizIndex._fmt(date)}';

  static Future<void> saveSelections(
      DateTime date, Map<String, String> selections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(date), json.encode(selections));
  }

  static Future<Map<String, String>?> loadSelections(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(date));
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSelections(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(date));
  }
}

class ConnectionsSelectionPrefs {
  static String _key(DateTime date) =>
      'connSel_${DailyQuizIndex._fmt(date)}';

  static Future<void> saveSelection(DateTime date, String itemRef) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(date), itemRef);
  }

  static Future<String?> loadSelection(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(date));
  }
}
