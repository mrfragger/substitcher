/// Model and matching utilities for the "Root of the Day" (harf) feature.
///
/// Data can appear under either the "harf" key (current) or the "wordle"
/// key (legacy files) in a daily quiz JSON — both are accepted.
class HarfItem {
  final String word; // undiacritized root letters, e.g. "سحر"
  final String display; // diacritized root, e.g. "سِحْر"
  final String hint;
  final String? verseRef; // e.g. "20:66" — explicit or derived from `verse`
  final String arabicVerse; // full diacritized verse containing the word
  final String verse; // English reference + translation, e.g. "20:66 - ..."

  /// Exact diacritized substring (copy-pasted verbatim from `arabicVerse`)
  /// to highlight, for cases where the bare root can't be located as a
  /// contiguous substring of the derived word — e.g. broken plurals
  /// (جبل → جِبَال), hollow roots, or elided letters. When present, this
  /// takes priority over automatic root matching.
  final String? matchOverride;

  HarfItem({
    required this.word,
    required this.display,
    required this.hint,
    required this.verseRef,
    required this.arabicVerse,
    required this.verse,
    this.matchOverride,
  });

  static final _refPattern = RegExp(r'(\d+:\d+(?:-\d+)?)');

  factory HarfItem.fromJson(Map<String, dynamic> j) {
    final verse = j['verse'] as String;
    // Prefer an explicit verseRef field; older "wordle" entries embed
    // the ref inside the verse string instead, e.g. "Al-Imran 3:3 — ...".
    final explicitRef = j['verseRef'] as String?;
    final derivedRef = explicitRef ?? _refPattern.firstMatch(verse)?.group(1);

    return HarfItem(
      word: j['word'] as String,
      display: j['display'] as String,
      hint: j['hint'] as String,
      verseRef: derivedRef,
      arabicVerse: j['arabicVerse'] as String,
      verse: verse,
      matchOverride: j['matchOverride'] as String?,
    );
  }
}

class HarfData {
  final List<HarfItem> items;
  HarfData(this.items);

  static HarfData? tryParse(Map<String, dynamic> dayJson) {
    // Older files used "wordle" for the same shape; accept either key.
    final raw = dayJson['harf'] ?? dayJson['wordle'];
    try {
      if (raw is List) {
        final items = raw
            .whereType<Map>()
            .map((e) => HarfItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return items.isEmpty ? null : HarfData(items);
      }
      if (raw is Map) {
        return HarfData([HarfItem.fromJson(Map<String, dynamic>.from(raw))]);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

/// Locates a root's derived word inside a diacritized Quranic verse, and
/// marks which part of that word is the root vs. an affix — for
/// beginner-friendly "root inside its inflected clothing" highlighting.
class RootHighlighter {
  static bool _isTatweel(int cp) => cp == 0x0640;
  static bool _isDaggerAlif(int cp) => cp == 0x0670;

  // Broad set of Arabic combining marks: standard harakat/tanwin/shadda/
  // sukun plus the extra Quranic recitation marks (sakta, small high seen,
  // etc.) that appear throughout Uthmani-script text. These are skipped
  // when locating letter clusters, but their span is folded into the
  // preceding letter so highlighting still covers them visually.
  static bool _isCombiningMark(int cp) {
    if (cp >= 0x0610 && cp <= 0x061A) return true;
    if (cp >= 0x064B && cp <= 0x065F) return true;
    if (cp >= 0x06D6 && cp <= 0x06ED) return true;
    if (cp >= 0x08D3 && cp <= 0x08E1) return true;
    if (cp >= 0x08E3 && cp <= 0x08FF) return true;
    return false;
  }

  static const Map<String, String> _normalize = {
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
    'ؤ': 'و', 'ئ': 'ي',
    'ى': 'ي', // alif maksura
    'ة': 'ت', // ta marbuta — also matches its construct-state ت form
  };

  static bool _isBoundary(String ch) {
    if (ch.trim().isEmpty) return true;
    const punct = 'ۚۖۗ۠ۛ۩.,؟!:؛-–—«»"“”()[]۝';
    return punct.contains(ch);
  }

  static List<_Cluster> _buildClusters(String text) {
    final clusters = <_Cluster>[];
    for (int i = 0; i < text.length; i++) {
      final cp = text.codeUnitAt(i);
      if (_isTatweel(cp)) continue; // pure elongation, ignore entirely
      if (_isDaggerAlif(cp)) {
        // Acts as a real letter (a hidden alif), not a diacritic.
        clusters.add(_Cluster(norm: 'ا', start: i, end: i + 1));
        continue;
      }
      if (_isCombiningMark(cp)) {
        if (clusters.isNotEmpty) clusters.last.end = i + 1;
        continue;
      }
      final ch = text[i];
      clusters.add(_Cluster(norm: _normalize[ch] ?? ch, start: i, end: i + 1));
    }
    return clusters;
  }

  /// Returns null if the root can't be located as a contiguous substring
  /// (common with hollow/weak roots, broken plurals, or dropped letters —
  /// flag these for a manual `matchOverride` rather than guessing).
  static WordMatch? findWholeWordMatch(String verse, String root) {
    final verseClusters = _buildClusters(verse);
    final rootLetters = _buildClusters(root).map((c) => c.norm).toList();
    if (rootLetters.isEmpty) return null;

    for (int s = 0; s <= verseClusters.length - rootLetters.length; s++) {
      var match = true;
      for (int k = 0; k < rootLetters.length; k++) {
        if (verseClusters[s + k].norm != rootLetters[k]) {
          match = false;
          break;
        }
      }
      if (!match) continue;

      final rootStart = verseClusters[s].start;
      final rootEnd = verseClusters[s + rootLetters.length - 1].end;

      int wordStart = rootStart;
      while (wordStart > 0 && !_isBoundary(verse[wordStart - 1])) {
        wordStart--;
      }
      int wordEnd = rootEnd;
      while (wordEnd < verse.length && !_isBoundary(verse[wordEnd])) {
        wordEnd++;
      }

      return WordMatch(
        wordStart: wordStart,
        wordEnd: wordEnd,
        word: verse.substring(wordStart, wordEnd),
        rootStartInWord: rootStart - wordStart,
        rootEndInWord: rootEnd - wordStart,
      );
    }
    return null;
  }

  /// Entry point used by the UI: prefers a manually curated `override`
  /// (an exact substring of `verse`) when provided, falling back to
  /// automatic root matching otherwise. Manually overridden matches bold
  /// the entire matched word, since the root/affix split isn't meaningful
  /// for irregular forms (broken plurals, elisions, etc.).
  static WordMatch? findMatch(String verse, String root, {String? override}) {
    if (override != null && override.isNotEmpty) {
      final idx = verse.indexOf(override);
      if (idx != -1) {
        return WordMatch(
          wordStart: idx,
          wordEnd: idx + override.length,
          word: override,
          rootStartInWord: 0,
          rootEndInWord: override.length,
        );
      }
      return null; // override string doesn't actually appear — data bug
    }
    return findWholeWordMatch(verse, root);
  }
}

class _Cluster {
  final String norm;
  final int start;
  int end;
  _Cluster({required this.norm, required this.start, required this.end});
}

class WordMatch {
  final int wordStart;
  final int wordEnd;
  final String word;
  final int rootStartInWord;
  final int rootEndInWord;
  WordMatch({
    required this.wordStart,
    required this.wordEnd,
    required this.word,
    required this.rootStartInWord,
    required this.rootEndInWord,
  });
}
