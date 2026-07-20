import 'dart:io';
import 'package:path/path.dart' as path;
import 'quran_index.dart';

class QuranAyahText {
  final int surah;
  final int ayah;
  final String text;
  QuranAyahText({required this.surah, required this.ayah, required this.text});
}

class QuranAyahSearchHit {
  final int surah;
  final int ayah;
  final String text;
  QuranAyahSearchHit({required this.surah, required this.ayah, required this.text});
}

class QuranVerseSearchIndex {
  List<QuranAyahText> _entries = [];
  String? _cachedLangKey;

  bool get isReady => _entries.isNotEmpty;
  bool get isBuiltFor => _cachedLangKey != null;

  Future<void> buildFromCurrentFile({
    required String currentVttPath,
    required String currentOpusPath,
  }) async {
    final vttDir = path.dirname(currentVttPath);
    final langSubdir = path.basename(vttDir);

    if (_cachedLangKey == langSubdir && _entries.isNotEmpty) return;

    final opusDir = path.dirname(currentOpusPath);
    final reciterSuffix = path.basename(currentOpusPath).replaceFirst(
      RegExp(r'^.*?\d{3}-\d{3} '),
      '',
    );

    final allEntries = <QuranAyahText>[];

    for (final rangeKey in quranFileRanges.keys) {
      final targetOpusName = 'Quran Arabic - $rangeKey $reciterSuffix';
      final targetOpusPath = path.join(opusDir, targetOpusName);
      final vttPath = await _findSiblingVtt(currentVttPath, targetOpusPath);
      if (vttPath == null) continue;

      try {
        final content = await File(vttPath).readAsString();
        final blocks = _extractVttTextBlocks(content);
        allEntries.addAll(_mergeBlocksToAyahs(blocks));
      } catch (_) {
      }
    }

    _entries = allEntries;
    _cachedLangKey = langSubdir;
  }

  void clear() {
    _entries = [];
    _cachedLangKey = null;
  }

  List<QuranAyahSearchHit> search(String query, {int limit = 100}) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return [];

    final results = <QuranAyahSearchHit>[];
    for (final e in _entries) {
      final lower = e.text.toLowerCase();
      if (terms.every((t) => lower.contains(t))) {
        results.add(QuranAyahSearchHit(surah: e.surah, ayah: e.ayah, text: e.text));
        if (results.length >= limit) break;
      }
    }
    return results;
  }

  Future<String?> _findSiblingVtt(
      String currentVttPath, String targetOpusPath) async {
    final vttDir = path.dirname(currentVttPath);
    final langSubdir = path.basename(vttDir);
    final vttParentDir = path.dirname(vttDir);

    final targetOpusDir = path.dirname(targetOpusPath);
    final targetOpusBase = path.basenameWithoutExtension(targetOpusPath);
    final targetVttName = '$targetOpusBase.vtt';

    final candidate1 = path.join(vttParentDir, langSubdir, targetVttName);
    final candidate2 = path.join(
        targetOpusDir, '${targetOpusBase}_vtt', langSubdir, targetVttName);
    final candidate3 = path.join(targetOpusDir, targetVttName);

    for (final c in [candidate1, candidate2, candidate3]) {
      if (await File(c).exists()) return c;
    }
    return null;
  }

  List<String> _extractVttTextBlocks(String content) {
    final blocks = <String>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line == 'VTTSHOW') break;
      if (line.contains('-->')) {
        final textLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }
        if (textLines.isNotEmpty) blocks.add(textLines.join(' '));
      }
    }
    return blocks;
  }

  List<QuranAyahText> _mergeBlocksToAyahs(List<String> blocks) {
    final result = <QuranAyahText>[];
    final versePattern = RegExp(r'^(\d+),(\d+)\s+(.*)$');
    for (final block in blocks) {
      final match = versePattern.firstMatch(block);
      if (match != null) {
        result.add(QuranAyahText(
          surah: int.parse(match.group(1)!),
          ayah: int.parse(match.group(2)!),
          text: match.group(3)!.trim(),
        ));
      } else if (result.isNotEmpty) {
        final last = result.removeLast();
        result.add(QuranAyahText(
          surah: last.surah,
          ayah: last.ayah,
          text: '${last.text} $block'.trim(),
        ));
      }
    }
    return result;
  }
}
