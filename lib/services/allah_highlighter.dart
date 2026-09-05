import 'package:flutter/material.dart';

/// Shared Allah/Lord/Rabb + bracket/paren/quote highlighting for English
/// and Arabic verse text, extracted from QuranPanel's tafsir styling so it
/// can be reused in the Quiz and Related tabs.
class AllahHighlighter {
  static const List<String> _englishWords = [
    'Allah\u2019s', 'Allāh\u2019s', 'Allâh\u2019s',
    'Allah\u02BCs', 'Allāh\u02BCs', 'Allâh\u02BCs',
    "Allah's", "Allāh's", "Allâh's",
    'Allah', 'Allāh', 'Allâh',
    'Lord\u2019s', 'Lord\u02BCs', "Lord's", 'Lord',
  ];

  static const List<String> _arabicWords = [
    'بالله', 'تالله', 'والله', 'فالله', 'لله', 'الله',
    'لربكم', 'لربهم', 'لربنا', 'لربه', 'لربك', 'لربي',
    'بربكم', 'بربهم', 'بربنا', 'بربه', 'بربك', 'بربي',
    'ربكم', 'ربهم', 'ربنا', 'ربه', 'ربها', 'ربك', 'ربي',
  ];

  static final RegExp _arabicDiacriticsPattern = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u08D3-\u08E1\u08E3-\u08FF]',
  );

  static (String, List<int>) _stripArabicDiacritics(String text) {
    final buffer = StringBuffer();
    final indexMap = <int>[];
    for (int i = 0; i < text.length; i++) {
      if (!_arabicDiacriticsPattern.hasMatch(text[i])) {
        buffer.write(text[i]);
        indexMap.add(i);
      }
    }
    return (buffer.toString(), indexMap);
  }

  static List<(int, int)> _findArabicAllahRanges(String text) {
    final pattern = _arabicWords.map(RegExp.escape).join('|');
    final (stripped, indexMap) = _stripArabicDiacritics(text);
    final regex = RegExp(pattern);
    final ranges = <(int, int)>[];
    for (final m in regex.allMatches(stripped)) {
      if (m.start >= m.end) continue;
      final origStart = indexMap[m.start];
      final origEnd = indexMap[m.end - 1] + 1;
      ranges.add((origStart, origEnd));
    }
    return ranges;
  }

  static List<(int, int)> _findEnglishAllahRanges(String text) {
    final sorted = [..._englishWords]..sort((a, b) => b.length.compareTo(a.length));
    const range = r"a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ'\u2018\u2019";
    final pattern =
        sorted.map((w) => '(?<![$range])${RegExp.escape(w)}(?![$range])').join('|');
    if (pattern.isEmpty) return [];
    final regex = RegExp(pattern);
    return [for (final m in regex.allMatches(text)) (m.start, m.end)];
  }

  /// Returns [text] as spans with:
  /// - "quotes" in pink
  /// - [brackets] in amber
  /// - (parens) in amber/orange
  /// - Allah/Lord/Rabb occurrences in purple, including inside the above
  static List<TextSpan> spans(String text, TextStyle baseStyle,
      {bool isArabic = false}) {
    const pinkColor = Color(0xFFFFB6C1);
    const amberColor = Colors.amber;
    const allahColor = Color(0xFFCB93F5);
    const cyanColor = Colors.cyan;

    final quoteStyle = baseStyle.copyWith(color: pinkColor);
    final bracketStyle = baseStyle.copyWith(color: cyanColor);
    final parenStyle = baseStyle.copyWith(color: amberColor);
    final allahStyle = baseStyle.copyWith(color: allahColor);

    // Simple pattern for matching quoted text
    final quotePattern = RegExp(r'"[^"]*"');
    const parenPattern = r'\([^)]*\)';
    final bracketPattern = RegExp(r'\[[^\]]*\]');

    // Combined pattern
    final combined = RegExp('(${quotePattern.pattern})|($parenPattern)|(${bracketPattern.pattern})');

    List<TextSpan> _applyAllah(String segment, TextStyle style) {
      final allahRanges = isArabic
          ? _findArabicAllahRanges(segment)
          : _findEnglishAllahRanges(segment);
      if (allahRanges.isEmpty) return [TextSpan(text: segment, style: style)];
      allahRanges.sort((a, b) => a.$1.compareTo(b.$1));
      final out = <TextSpan>[];
      int cursor = 0;
      for (final r in allahRanges) {
        if (r.$1 < cursor) continue;
        if (r.$1 > cursor) {
          out.add(TextSpan(text: segment.substring(cursor, r.$1), style: style));
        }
        out.add(TextSpan(
          text: segment.substring(r.$1, r.$2),
          style: allahStyle.copyWith(fontSize: style.fontSize, height: style.height),
        ));
        cursor = r.$2;
      }
      if (cursor < segment.length) {
        out.add(TextSpan(text: segment.substring(cursor), style: style));
      }
      return out;
    }

    final result = <TextSpan>[];
    int cursor = 0;
    for (final m in combined.allMatches(text)) {
      if (m.start > cursor) {
        result.addAll(_applyAllah(text.substring(cursor, m.start), baseStyle));
      }
      final matched = m.group(0)!;
      if (m.group(1) != null) {
        // "quote"
        result.add(TextSpan(text: '"', style: quoteStyle));
        result.addAll(_applyAllah(matched.substring(1, matched.length - 1), quoteStyle));
        result.add(TextSpan(text: '"', style: quoteStyle));
      } else if (m.group(2) != null) {
        // (paren)
        result.add(TextSpan(text: '(', style: parenStyle));
        result.addAll(_applyAllah(matched.substring(1, matched.length - 1), parenStyle));
        result.add(TextSpan(text: ')', style: parenStyle));
      } else {
        // [bracket]
        result.add(TextSpan(text: '[', style: bracketStyle));
        result.addAll(_applyAllah(matched.substring(1, matched.length - 1), bracketStyle));
        result.add(TextSpan(text: ']', style: bracketStyle));
      }
      cursor = m.end;
    }
    if (cursor < text.length) {
      result.addAll(_applyAllah(text.substring(cursor), baseStyle));
    }
    return result;
  }
}
