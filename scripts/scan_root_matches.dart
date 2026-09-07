// Run with: dart scripts/scan_root_matches.dart <path-to-json-dir>
// Example:  dart scripts/scan_root_matches.dart assets/daily_quiz

import 'dart:convert';
import 'dart:io';

// ---- Mirrors RootHighlighter in lib/quiz/harf_model.dart ----

bool _isTatweel(int cp) => cp == 0x0640;
bool _isDaggerAlif(int cp) => cp == 0x0670;

bool _isCombiningMark(int cp) {
  if (cp >= 0x0610 && cp <= 0x061A) return true;
  if (cp >= 0x064B && cp <= 0x065F) return true;
  if (cp >= 0x06D6 && cp <= 0x06ED) return true;
  if (cp >= 0x08D3 && cp <= 0x08E1) return true;
  if (cp >= 0x08E3 && cp <= 0x08FF) return true;
  return false;
}

const Map<String, String> _normalize = {
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا',
  'ؤ': 'و', 'ئ': 'ي',
  'ى': 'ي', // alif maksura
  'ة': 'ت', // ta marbuta
};

bool _isBoundary(String ch) {
  if (ch.trim().isEmpty) return true;
  const punct = 'ۚۖۗ۠ۛ۩.,؟!:؛-–—«»"“”()[]۝';
  return punct.contains(ch);
}

class _Cluster {
  final String norm;
  final int start;
  int end;
  _Cluster({required this.norm, required this.start, required this.end});
}

List<_Cluster> _buildClusters(String text) {
  final clusters = <_Cluster>[];
  for (int i = 0; i < text.length; i++) {
    final cp = text.codeUnitAt(i);
    if (_isTatweel(cp)) continue;
    if (_isDaggerAlif(cp)) {
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

class WordMatch {
  final int wordStart, wordEnd, rootStartInWord, rootEndInWord;
  final String word;
  WordMatch(this.wordStart, this.wordEnd, this.word, this.rootStartInWord,
      this.rootEndInWord);
}

WordMatch? findWholeWordMatch(String verse, String root) {
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

    return WordMatch(wordStart, wordEnd, verse.substring(wordStart, wordEnd),
        rootStart - wordStart, rootEnd - wordStart);
  }
  return null;
}

// Replace the body of suggestOverride with this stricter version.
// Only accept a suggestion if it covers at least ~75% of the root's
// letters — short coincidental overlaps (e.g. 2 shared letters out of 4)
// are more likely to be false positives than real words.
String? suggestOverride(String verse, String root) {
  final verseClusters = _buildClusters(verse);
  final rootClusters = _buildClusters(root);
  if (verseClusters.isEmpty || rootClusters.isEmpty) return null;

  int bestLen = 0;
  int bestVerseStart = -1;

  final dp = List.generate(
      rootClusters.length + 1, (_) => List.filled(verseClusters.length + 1, 0));
  for (int i = 1; i <= rootClusters.length; i++) {
    for (int j = 1; j <= verseClusters.length; j++) {
      if (rootClusters[i - 1].norm == verseClusters[j - 1].norm) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
        if (dp[i][j] > bestLen) {
          bestLen = dp[i][j];
          bestVerseStart = j - bestLen;
        }
      }
    }
  }

  // Require the matched run to cover most of the root — otherwise it's
  // probably a coincidental overlap with an unrelated word.
  final minAcceptable = (rootClusters.length * 0.75).ceil();
  if (bestLen < minAcceptable || bestVerseStart == -1) return null;

  final matchStart = verseClusters[bestVerseStart].start;
  final matchEnd = verseClusters[bestVerseStart + bestLen - 1].end;

  int wordStart = matchStart;
  while (wordStart > 0 && !_isBoundary(verse[wordStart - 1])) {
    wordStart--;
  }
  int wordEnd = matchEnd;
  while (wordEnd < verse.length && !_isBoundary(verse[wordEnd])) {
    wordEnd++;
  }

  return verse.substring(wordStart, wordEnd);
}

// ---- Scanner ----

void main(List<String> args) {
  final dirPath = args.isNotEmpty ? args[0] : 'assets/daily_quiz';
  final dir = Directory(dirPath);
  if (!dir.existsSync()) {
    stderr.writeln('Directory not found: $dirPath');
    exit(1);
  }

  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  int total = 0;
  int failed = 0;
  final failures = <String>[];

  for (final file in files) {
    Map<String, dynamic> dayJson;
    try {
      dayJson = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      failures.add('${file.uri.pathSegments.last}: FILE FAILED TO PARSE ($e)');
      continue;
    }

    final raw = dayJson['harf'] ?? dayJson['wordle'];
    if (raw == null) continue;

    final items = <Map<String, dynamic>>[];
    if (raw is List) {
      items.addAll(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    } else if (raw is Map) {
      items.add(Map<String, dynamic>.from(raw));
    }

    for (final item in items) {
      total++;
      final word = item['word'] as String?;
      final arabicVerse = item['arabicVerse'] as String?;
      final display = item['display'] as String? ?? '';
      final hint = item['hint'] as String? ?? '';

      if (word == null || arabicVerse == null) {
        failed++;
        failures.add(
            '${file.uri.pathSegments.last}: MISSING word/arabicVerse (display="$display")');
        continue;
      }

      final override = item['matchOverride'] as String?;
      WordMatch? match;

      if (override != null && override.isNotEmpty) {
        final idx = arabicVerse.indexOf(override);
        if (idx == -1) {
          failed++;
          final suggestion = suggestOverride(arabicVerse, word);
          final buf = StringBuffer();
          buf.writeln(
              '${file.uri.pathSegments.last}: OVERRIDE NOT FOUND  override="$override"  display="$display"');
          buf.writeln('    verse: $arabicVerse');
          if (suggestion != null) {
            buf.writeln('    💡 suggested matchOverride (copy-paste exactly): "$suggestion"');
          }
          failures.add(buf.toString());
          continue;
        }
        match = WordMatch(idx, idx + override.length, override, 0, override.length);
      } else {
        match = findWholeWordMatch(arabicVerse, word);
        if (match == null) {
          failed++;
          final buf = StringBuffer();
          buf.writeln(
              '${file.uri.pathSegments.last}: NO MATCH  word="$word"  display="$display"  hint="$hint"');
          buf.writeln('    verse: $arabicVerse');
          if (arabicVerse.trim().isEmpty) {
            buf.writeln('    ⚠ arabicVerse is EMPTY — data error, not a matching bug.');
          } else {
            final suggestion = suggestOverride(arabicVerse, word);
            if (suggestion != null) {
              buf.writeln('    💡 suggested matchOverride (copy-paste exactly): "$suggestion"');
            }
          }
          final cps = word.runes
              .map((r) => 'U+${r.toRadixString(16).padLeft(4, '0')}')
              .join(' ');
          buf.writeln('    word codepoints: $cps');
          failures.add(buf.toString());
        }
      }
    }
  }

  print('Scanned ${files.length} files, $total harf/wordle entries.\n');
  if (failures.isEmpty) {
    print('✅ All entries matched successfully.');
  } else {
    print('❌ $failed entr${failed == 1 ? 'y' : 'ies'} failed to auto-match:\n');
    for (final f in failures) {
      print('- $f');
    }
  }
}
