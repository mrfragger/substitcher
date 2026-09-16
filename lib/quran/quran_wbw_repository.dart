// lib/quran/quran_wbw_repository.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'quran_word_by_word.dart';

class QuranWbwRepository {
  QuranWbwRepository._();
  static final QuranWbwRepository instance = QuranWbwRepository._();

  final Map<int, Map<int, QuranAyahWordByWord>> _surahCache = {};

  Future<Map<int, QuranAyahWordByWord>> _loadSurah(int surah) async {
    final cached = _surahCache[surah];
    if (cached != null) return cached;

    final padded = surah.toString().padLeft(3, '0');
    final raw = await rootBundle.loadString('assets/quran_wbw/$padded.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    final ayahMap = <int, QuranAyahWordByWord>{};
    decoded.forEach((ayahKey, value) {
      final ayah = int.parse(ayahKey);
      ayahMap[ayah] = QuranAyahWordByWord.fromJson(value as Map<String, dynamic>);
    });

    _surahCache[surah] = ayahMap;
    return ayahMap;
  }

  Future<QuranAyahWordByWord?> getAyah(int surah, int ayah) async {
    final surahData = await _loadSurah(surah);
    return surahData[ayah];
  }

  Future<List<QuranWordInfo>> getWords(int surah, int ayah) async {
    final a = await getAyah(surah, ayah);
    return a?.words ?? const [];
  }
}
