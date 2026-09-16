// lib/quran/quran_word_by_word.dart
class QuranWordInfo {
  final String arabic;          // c
  final String transliteration; // d
  final String english;         // e
  const QuranWordInfo({
    required this.arabic,
    required this.transliteration,
    required this.english,
  });

  factory QuranWordInfo.fromJson(Map<String, dynamic> j) => QuranWordInfo(
        arabic: j['c'] as String,
        transliteration: j['d'] as String,
        english: j['e'] as String,
      );
}

class QuranAyahWordByWord {
  final List<QuranWordInfo> words;
  final String? ayahGloss; // a.g — full ayah translation
  const QuranAyahWordByWord({required this.words, this.ayahGloss});

  factory QuranAyahWordByWord.fromJson(Map<String, dynamic> j) {
    final wordsJson = (j['w'] as List<dynamic>? ?? const []);
    final gloss = (j['a'] as Map<String, dynamic>?)?['g'] as String?;
    return QuranAyahWordByWord(
      words: wordsJson
          .map((w) => QuranWordInfo.fromJson(w as Map<String, dynamic>))
          .toList(),
      ayahGloss: gloss,
    );
  }
}
