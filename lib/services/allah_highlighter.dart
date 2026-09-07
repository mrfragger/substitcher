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
  /// - [brackets] in cyan (highlighted even when nested inside quotes)
  /// - (parens) in amber (highlighted even when nested inside quotes)
  /// - Allah/Lord/Rabb occurrences in purple, including inside the above
  static List<TextSpan> spans(String text, TextStyle baseStyle,
      {bool isArabic = false}) {
    const pinkColor = Color(0xFFFFB6C1);
    const amberColor = Colors.amber;
    const bracketColor = Colors.cyan;
    const allahColor = Color(0xFFCB93F5);

    final quoteStyle = baseStyle.copyWith(color: pinkColor);
    final bracketStyle = baseStyle.copyWith(color: bracketColor);
    final parenStyle = baseStyle.copyWith(color: amberColor);
    final allahStyle = baseStyle.copyWith(color: allahColor);

    final quotePattern = r'"[^"]*"';
    final parenPattern = r'\([^)]*\)';
    final bracketPattern = r'\[[^\]]*\]';

    // Top-level pattern matches quotes, parens, and brackets.
    final topPattern =
        RegExp('($quotePattern)|($parenPattern)|($bracketPattern)');
    // Nested pattern (used inside a quote) matches only parens/brackets,
    // so we don't try to re-match quote delimiters inside a quote.
    final nestedPattern = RegExp('($parenPattern)|($bracketPattern)');

    List<TextSpan> applyAllah(String segment, TextStyle style) {
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

    // Recursively processes [text] for quote/paren/bracket spans, using
    // [pattern] to find delimiters at this level, and [style] as the
    // fallback style for plain text. Quotes are only matched at the top
    // level (isTopLevel) to avoid ambiguous nested-quote matching.
    List<TextSpan> process(String text, TextStyle style, RegExp pattern,
        {required bool isTopLevel}) {
      final result = <TextSpan>[];
      int cursor = 0;
      for (final m in pattern.allMatches(text)) {
        if (m.start > cursor) {
          result.addAll(applyAllah(text.substring(cursor, m.start), style));
        }
        final matched = m.group(0)!;
        if (isTopLevel && m.group(1) != null) {
          // "quote" — recurse for nested brackets/parens only.
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '"', style: quoteStyle));
          result.addAll(
              process(inner, quoteStyle, nestedPattern, isTopLevel: false));
          result.add(TextSpan(text: '"', style: quoteStyle));
        } else {
          final groupIndex = isTopLevel ? m.group(2) : m.group(1);
          final isParen = groupIndex != null;
          if (isParen) {
            // (paren) — recurse for nested brackets.
            final inner = matched.substring(1, matched.length - 1);
            result.add(TextSpan(text: '(', style: parenStyle));
            result.addAll(
                process(inner, parenStyle, nestedPattern, isTopLevel: false));
            result.add(TextSpan(text: ')', style: parenStyle));
          } else {
            // [bracket] — recurse for nested parens.
            final inner = matched.substring(1, matched.length - 1);
            result.add(TextSpan(text: '[', style: bracketStyle));
            result.addAll(process(inner, bracketStyle, nestedPattern,
                isTopLevel: false));
            result.add(TextSpan(text: ']', style: bracketStyle));
          }
        }
        cursor = m.end;
      }
      if (cursor < text.length) {
        result.addAll(applyAllah(text.substring(cursor), style));
      }
      return result;
    }

    return process(text, baseStyle, topPattern, isTopLevel: true);
  }
}
