import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'quran_tokenizers.dart';

enum ZipExtractMode { all, rangeCsvsOnly, languagesOnly }
typedef ProgressFn = void Function(String status, double progress);

class QuranPipelineService {
  QuranPipelineService({required this.tokenizers, required this.log});

  final QuranTokenizers tokenizers;
  final LogFn log;

  static const List<String> ranges = [
    '001-006', '007-015', '016-024', '025-036', '037-049', '050-069', '070-114',
  ];
  static const List<(int, int)> rangeBounds = [
    (1, 6), (7, 15), (16, 24), (25, 36), (37, 49), (50, 69), (70, 114),
  ];
  static const Map<String, List<String>> _protected = {
    'thai': ['เราะซูล', 'แท้จริง', 'พวกเจ้า', 'พวกเขา', 'ชัยฏอน', 'อัลลอฮ์', 'มลาอิกะฮ์', 'มุฮัมหมัด'],
    'khmer': ['ស្ហៃតន', 'ម៉ាឡាអ៊ីកាត់', 'អ៊ីព្លីស'],
    'japanese': ['シャイターン', 'イブリース', 'アーダム'],
  };

  static const Map<String, String> replacements = {
    'Qur\u2019an': 'Quran',
    "Qur'an": 'Quran',
    'Qur\u2019ân': 'Quran',
    "Qur'ân": 'Quran',
    'Allâh': 'Allah',
    'Allāh': 'Allah',
    'صلى الله عليه وسلم': '﵇',
    '\u0101': 'a', '\u0100': 'A', '\u012B': 'i', '\u012A': 'I',
    '\u016B': 'u', '\u016A': 'U', '\u1E63': 's', '\u1E62': 'S',
    '\u1E0D': 'd', '\u1E0C': 'D', '\u1E6D': 't', '\u1E6C': 'T',
    '\u1E93': 'z', '\u1E92': 'Z', '\u1E25': 'h', '\u1E24': 'H',
    '\u1E0F': 'dh', '\u1E0E': 'Dh', '\u1E6F': 'th', '\u1E6E': 'Th',
    '\u0121': 'gh', '\u0120': 'Gh', '\u1E2B': 'kh', '\u1E2A': 'Kh',
    '\u02BF': "'", '\u02BE': "'",
    '\u00E2': 'a', '\u00C2': 'A', '\u00EE': 'i', '\u00CE': 'I',
    '\u00FB': 'u', '\u00DB': 'U',
  };

  static const Map<String, int> targetChars = {
    'latin': 80, 'arabic': 80, 'chinese': 26, 'japanese': 26,
    'korean': 26, 'thai': 66, 'khmer': 66,
  };
  static const int? maxSplitParts = null;
  static const String englishFolder = 'a English saheeh';

  static final _timecodeRe =
      RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}\.\d{3}');
  static final _tagRe = RegExp(r'<[^>]+>');
  static final _verseNumRe = RegExp(r'^\d+\.\s+');
  static final _zhRe = RegExp(r'[\u4E00-\u9FFF]');
  static final _jaRe = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]');
  static final _koRe = RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]');
  static final _arRe = RegExp(r'[\u0600-\u06FF]');
  static final _thRe = RegExp(r'[\u0E00-\u0E7F]');
  static final _kmRe = RegExp(r'[\u1780-\u17FF]');

  // ───────────────────────── helpers ─────────────────────────

  static String detectScript(String text) {
    final total = text.trim().length;
    if (total == 0) return 'latin';
    int c(RegExp r) => r.allMatches(text).length;
    final zh = c(_zhRe), ja = c(_jaRe), ko = c(_koRe);
    final ar = c(_arRe), th = c(_thRe), km = c(_kmRe);
    if (ja > 0) return 'japanese';
    if (zh > 10 && zh / total > 0.2) return 'chinese';
    if (ko > 10 && ko / total > 0.2) return 'korean';
    if (th > 10 && th / total > 0.2) return 'thai';
    if (km > 10 && km / total > 0.2) return 'khmer';
    if (ar > 10 && ar / total > 0.2) return 'arabic';
    return 'latin';
  }

  static int computeNumParts(int length, int target) {
    if (length <= target) return 0;
    var parts = (length / target).ceil();
    if (parts < 2) parts = 2;
    if (maxSplitParts != null && parts > maxSplitParts!) parts = maxSplitParts!;
    return parts;
  }

  static String detectPrefix(String filename) =>
      p.basenameWithoutExtension(filename).replaceAll(RegExp(r'_v\d.*$'), '');

  static String prefixToLabel(String prefix) => prefix
      .split('_')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static List<String> findLanguageDirs(String root) {
    final dirs = <String>[];
    for (final e in Directory(root).listSync()) {
      if (e is! Directory) continue;
      final name = p.basename(e.path);
      if (name.startsWith('.') || name == 'zsplit' || name == 'z_bismillah') continue;
      if (e.listSync().whereType<File>().any((f) => f.path.toLowerCase().endsWith('.csv'))) {
        dirs.add(name);
      }
    }
    dirs.sort();
    return dirs;
  }

  List<File> _files(String dir, bool Function(String name) test) {
    final out = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => test(p.basename(f.path)))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  Future<List<List<String>>> _readCsv(String path) async {
    var txt = await File(path).readAsString();
    if (txt.startsWith('\uFEFF')) txt = txt.substring(1);
    return Csv().decode(txt).map((r) => r.map((e) => e.toString()).toList()).toList();
  }

  Future<void> _writeCsv(String path, List<List<String>> rows) =>
      File(path).writeAsString(Csv().encode(rows));

  List<String> _linesKeepEnds(String s) {
    final out = <String>[];
    var start = 0;
    for (var i = 0; i < s.length; i++) {
      if (s.codeUnitAt(i) == 10) {
        out.add(s.substring(start, i + 1));
        start = i + 1;
      }
    }
    if (start < s.length) out.add(s.substring(start));
    return out;
  }

  Future<void> _yield() => Future<void>.delayed(Duration.zero);

  // ───────────────────────── organize mp3 ─────────────────────────

  /// Moves NNNNNN.mp3 files from [sourceDir] into quran_saheehXXX-XXX_media
  /// folders created next to it. Ayah 000 files go to z_bismillah.
  Future<void> organizeMedia(String sourceDir) async {
    log('=== Organize MP3 media into range subdirectories ===');
    final src = Directory(sourceDir);
    final root = p.dirname(sourceDir);
    final mp3s = _files(sourceDir, (n) => n.toLowerCase().endsWith('.mp3'));
    if (mp3s.isEmpty) {
      log('ERROR: No mp3 files found in $sourceDir');
      return;
    }

    final targets = <String, String>{};
    for (final r in ranges) {
      final d = p.join(root, 'quran_saheeh${r}_media');
      await Directory(d).create(recursive: true);
      targets[r] = d;
    }
    final bismillahDir = p.join(root, 'z_bismillah');
    final nameRe = RegExp(r'^(\d{3})_?(\d{3})\.mp3$', caseSensitive: false);

    var moved = 0, skipped = 0, bism = 0;
    var sampleCopied = false;
    for (final f in mp3s) {
      final name = p.basename(f.path);
      final m = nameRe.firstMatch(name);
      if (m == null) {
        log('  WARNING: Skipping unrecognized filename: $name');
        skipped++;
        continue;
      }
      final cleanName = '${m.group(1)}${m.group(2)}.mp3';
      if (cleanName == '002163.mp3') {
        await f.copy(p.join(root, '002163 sample.mp3'));
        sampleCopied = true;
      }
      final sura = int.parse(m.group(1)!);
      if (m.group(2) == '000') {
        await Directory(bismillahDir).create(recursive: true);
        await f.rename(p.join(bismillahDir, cleanName));
        bism++;
        continue;
      }
      String? target;
      for (var i = 0; i < ranges.length; i++) {
        final (s, e) = rangeBounds[i];
        if (sura >= s && sura <= e) {
          target = ranges[i];
          break;
        }
      }
      if (target == null) {
        log('  WARNING: Sura $sura out of range, skipping: $name');
        skipped++;
        continue;
      }
      await f.rename(p.join(targets[target]!, cleanName));
      moved++;
    }

    log('Moved $moved mp3 files into range subdirectories.');
    if (sampleCopied) {
      log('Copied 002163.mp3 to root as "002163 sample.mp3"');
    } else {
      log('WARNING: 002163.mp3 not found, no sample copied');
    }
    if (bism > 0) log('Moved $bism bismillah file(s) to z_bismillah/');
    if (skipped > 0) log('Skipped $skipped file(s) — see warnings above.');
    for (final r in ranges) {
      final n = _files(targets[r]!, (x) => x.toLowerCase().endsWith('.mp3')).length;
      log('  quran_saheeh${r}_media/: $n files');
    }

    final remaining = src.listSync();
    if (remaining.isEmpty) {
      await src.delete();
      log('Deleted empty source directory: ${p.basename(sourceDir)}');
    } else {
      log('WARNING: ${p.basename(sourceDir)} still has ${remaining.length} item(s) — not deleting.');
    }
  }

  // ───────────────────────── CSV steps ─────────────────────────

  Future<void> _cleanCsv(String path) async {
    log('  Step 0: Clean CSV');
    final raw = await File(path).readAsString();
    final data = StringBuffer();
    var found = false, inQuotes = false;

    for (final line in _linesKeepEnds(raw)) {
      final startsOutside = !inQuotes;
      if ('"'.allMatches(line).length.isOdd) inQuotes = !inQuotes;
      if (startsOutside) {
        final stripped = line.trim().replaceAll(RegExp(r'^"+|"+$'), '');
        if (stripped.startsWith('#') ||
            stripped.toLowerCase().startsWith('translation info')) {
          continue;
        }
        if (stripped.replaceAll(',', '').trim().isEmpty) continue;
        if (!found && stripped.toLowerCase().startsWith('id,')) {
          found = true;
          continue;
        }
      }
      if (found) data.write(line);
    }
    if (data.isEmpty) {
      final firstCell = raw.trimLeft().split(RegExp(r'[,\r\n]')).first.toLowerCase();
      if (firstCell == 'sura') {
        log('    Already sura,aya,text format — nothing to clean');
        return;
      }
      log('    ERROR: No data rows found after removing header info');
      return;
    }
    final rows = Csv().decode(data.toString());
    final out = <List<String>>[
      ['sura', 'aya', 'translation'],
    ];
    for (final r in rows) {
      if (r.length < 4) continue;
      out.add([r[1].toString().trim(), r[2].toString().trim(), r[3].toString().trim()]);
    }
    await _writeCsv(path, out);
    log('    Data rows: ${out.length - 1}');
  }

  Future<void> _normalizeCsv(String path) async {
    log('  Step 1: Normalize, remove reference & verse numbers');
    final rows = await _readCsv(path);
    if (rows.isEmpty) {
      log('    ERROR: CSV is empty');
      return;
    }
    final found = <String>{};
    // Japanese translations carry '*' footnote markers. The footnotes are
    // dropped in step 0, so the markers are meaningless. Strip them.
    final sampleText = rows
        .skip(1)
        .take(20)
        .where((r) => r.length > 2)
        .map((r) => r[2])
        .join(' ');
    final stripStars = detectScript(sampleText) == 'japanese';
    if (stripStars) log('    Japanese: removing * footnote markers');
    final out = <List<String>>[rows.first];
    for (final row in rows.skip(1)) {
      if (row.length < 3) {
        out.add(row);
        continue;
      }
      final aya = row[1];
      var t = row[2];
      for (final src in replacements.keys) {
        if (t.contains(src)) found.add(src);
      }
      replacements.forEach((k, v) => t = t.replaceAll(k, v));
            if (stripStars) t = t.replaceAll('*', '');
      t = t.replaceAll(RegExp(r' \[\d+\]'), '').replaceAll(RegExp(r'\[\d+\]'), '');
      final m = RegExp(r'^(\d+)[\.\,:]?\s*(.*)$', dotAll: true).firstMatch(t);
      if (m != null) {
        final n = int.tryParse(m.group(1)!);
        final a = int.tryParse(aya.trim());
        if (n != null && a != null && n == a) t = m.group(2)!;
      }
      out.add([row[0], row[1], t, ...row.skip(3)]);
    }
    await _writeCsv(path, out);
    if (found.isNotEmpty) log('    Replaced: ${found.toList()..sort()}');
  }

  Future<void> _splitRanges(String workingCsv, String subdir, String prefix) async {
    log('  Step 2: Split into 7 range files');
    final rows = await _readCsv(workingCsv);
    if (rows.isEmpty) {
      log('    ERROR: CSV is empty');
      return;
    }
    List<String>? header;
    var data = rows;
    if (const {'sura', 'surah', 'chapter'}.contains(rows.first[0].trim().toLowerCase())) {
      header = rows.first;
      data = rows.skip(1).toList();
    }
    for (var i = 0; i < ranges.length; i++) {
      final (start, end) = rangeBounds[i];
      final filtered = <List<String>>[if (header != null) header];
      for (final row in data) {
        if (row.isEmpty) continue;
        final n = int.tryParse(row[0].trim().replaceAll('\uFEFF', ''));
        if (n != null && n >= start && n <= end) filtered.add(row);
      }
      await _writeCsv(p.join(subdir, '$prefix${ranges[i]}.csv'), filtered);
      log('    ${prefix}${ranges[i]}.csv: ${filtered.length - (header != null ? 1 : 0)} rows');
    }
  }

  Future<void> _addArabicAudio(String root, String subdir, String prefix) async {
    log('  Step 3: Add Arabic text & audio');
    for (final suffix in ranges) {
      final sourcePath = p.join(root, 'quran_saheeh$suffix.csv');
      final targetPath = p.join(subdir, '$prefix$suffix.csv');
      if (!await File(sourcePath).exists()) {
        log('    WARNING: Source not found: quran_saheeh$suffix.csv — skipping');
        continue;
      }
      if (!await File(targetPath).exists()) {
        log('    WARNING: Target not found: $prefix$suffix.csv — skipping');
        continue;
      }
      final src = await _readCsv(sourcePath);
      final sh = src.first.map((e) => e.trim().toLowerCase()).toList();
      final si = sh.indexOf('sura'), ai = sh.indexOf('aya');
      final ari = sh.indexOf('arabic'), aui = sh.indexOf('audio');
      final lookup = <String, (String, String)>{};
      for (final r in src.skip(1)) {
        if (r.length <= [si, ai, ari, aui].reduce((a, b) => a > b ? a : b)) continue;
        lookup['${r[si].trim()}|${r[ai].trim()}'] = (r[ari], r[aui]);
      }
      final tgt = await _readCsv(targetPath);
      final th = tgt.first.map((e) => e.trim().toLowerCase()).toList();
      final ti = th.indexOf('translation') >= 0 ? th.indexOf('translation') : th.indexOf('text');
      final out = <List<String>>[
        ['sura', 'aya', 'translation', 'arabic', 'audio'],
      ];
      for (final r in tgt.skip(1)) {
        if (r.length < 2) continue;
        final sura = r[0].trim().replaceAll('\uFEFF', '');
        final aya = r[1].trim();
        final (ar, au) = lookup['$sura|$aya'] ?? ('', '');
        out.add([r[0], r[1], ti >= 0 && ti < r.length ? r[ti] : '', ar, au]);
      }
      await _writeCsv(targetPath, out);
      log('    Updated: $prefix$suffix.csv');
    }
  }

  // ───────────────────────── VTT helpers ─────────────────────────

  static int _parseMs(String ts) {
    final parts = ts.trim().split(':');
    final sp = parts[2].split('.');
    return int.parse(parts[0]) * 3600000 +
        int.parse(parts[1]) * 60000 +
        int.parse(sp[0]) * 1000 +
        int.parse(sp[1].substring(0, 3));
  }

  static String _fmtMs(int ms) {
    final h = ms ~/ 3600000;
    ms %= 3600000;
    final m = ms ~/ 60000;
    ms %= 60000;
    final s = ms ~/ 1000;
    ms %= 1000;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(h)}:${two(m)}:${two(s)}.${ms.toString().padLeft(3, '0')}';
  }

  static final _newline = RegExp(r'\r?\n');

  (List<String>, List<(String, List<String>)>) _parseVttBlocks(String content) {
    final lines = content.split(_newline);
    final header = <String>[];
    var i = 0;
    while (i < lines.length && !_timecodeRe.hasMatch(lines[i].trim())) {
      header.add(lines[i]);
      i++;
    }
    final blocks = <(String, List<String>)>[];
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        i++;
        continue;
      }
      if (_timecodeRe.hasMatch(line)) {
        i++;
        final text = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          text.add(lines[i].trim());
          i++;
        }
        blocks.add((line, text));
      } else {
        i++;
      }
    }
    return (header, blocks);
  }

  String _buildVtt(List<String> header, List<(String, List<String>)> blocks) {
    final parts = <String>[...header];
    if (header.isNotEmpty && header.last.trim().isNotEmpty) parts.add('');
    for (final (tc, text) in blocks) {
      parts.add(tc);
      parts.addAll(text);
      parts.add('');
    }
    return parts.join('\n');
  }

  File? _findVtt(String root, String suffix) {
    for (final f in _files(root, (n) => n.toLowerCase().endsWith('.vtt'))) {
      if (p.basename(f.path).contains(suffix)) return f;
    }
    return null;
  }

  // ───────────────────────── splitting ─────────────────────────

  static int _findWordBoundary(String text, int pos) {
    for (var j = 0; j < 50; j++) {
      if (pos + j < text.length && text[pos + j] == ' ') return pos + j;
      if (pos - j >= 0 && pos - j < text.length && text[pos - j] == ' ') return pos - j;
    }
    return pos;
  }

  List<String> _splitWords(String text, int numParts) {
    final b = <int>[0];
    for (var k = 1; k < numParts; k++) {
      final pos = _findWordBoundary(text, text.length * k ~/ numParts);
      if (pos > b.last) b.add(pos);
    }
    b.add(text.length);
    final parts = <String>[];
    for (var i = 0; i < b.length - 1; i++) {
      final s = text.substring(b[i], b[i + 1]).trim();
      if (s.isNotEmpty) parts.add(s);
    }
    while (parts.length < numParts) {
      parts.add('');
    }
    return parts;
  }

  Future<List<String>> _splitTokenized(String text, int numParts, String script) async {
    final tokens = await tokenizers.tokenize(text, script);

    // Map tokens back onto the original string so dropped tokens (spaces,
    // punctuation) can't make offsets drift.
    final spans = <(int, int, String)>[];
    var pos = 0;
    for (final t in tokens) {
      if (t.isEmpty) continue;
      final idx = text.indexOf(t, pos);
      if (idx < 0) continue;
      pos = idx + t.length;
      spans.add((idx, pos, t));
    }

    // Fold punctuation-only tokens (incl. footnote *) into the previous token.
    final punctOnly = RegExp(r'^[\s*。，、；：！？）】」』》〕”’…—.,;:!?)]+$');
    final merged = <(int, int, String)>[];
    for (final s in spans) {
      if (merged.isNotEmpty && punctOnly.hasMatch(s.$3)) {
        final last = merged.removeLast();
        merged.add((last.$1, s.$2, last.$3 + s.$3));
      } else {
        merged.add(s);
      }
    }

    // Japanese: don't cut in front of tiny kana tokens or suffix kanji.
    final trailPunct = RegExp(r'[\s*。，、；：！？）】」』》〕”’…—.,;:!?)]+$');
    final jaCont = RegExp(r'^([\u3040-\u309F\u30FC]{1,3}|[方達者])$');
    final ends = <int>[];
    for (var i = 0; i < merged.length; i++) {
      if (script == 'japanese' && i + 1 < merged.length) {
        final next = merged[i + 1].$3.replaceAll(trailPunct, '');
        if (jaCont.hasMatch(next)) continue;
      }
      ends.add(merged[i].$2);
    }

    // Thai/Khmer: real spaces are always safe candidate boundaries.
    if (script == 'thai' || script == 'khmer') {
      for (var i = 0; i < text.length; i++) {
        if (text[i] == ' ') ends.add(i);
      }
    }

    final protRanges = <(int, int)>[];
    for (final w in _protected[script] ?? const <String>[]) {
      var i = text.indexOf(w);
      while (i >= 0) {
        protRanges.add((i, i + w.length));
        i = text.indexOf(w, i + 1);
      }
    }
    bool inProt(int x) => protRanges.any((r) => x > r.$1 && x < r.$2);
    ends.removeWhere(inProt);

    final total = text.length;
    final b = <int>[0];
    for (var k = 1; k < numParts; k++) {
      final target = total * k ~/ numParts;
      var best = 0, bestDiff = target;
      for (final e in ends) {
        final d = (e - target).abs();
        if (d < bestDiff) {
          bestDiff = d;
          best = e;
        }
      }

      if (script == 'thai' || script == 'khmer') {
        final tol = (total / numParts * 0.3).round();
        int? sp;
        var spDiff = tol + 1;
        for (var i = 0; i < text.length; i++) {
          if (text[i] == ' ') {
            final d = (i - target).abs();
            if (d < spDiff) {
              spDiff = d;
              sp = i;
            }
          }
        }
        if (sp != null) best = sp;
      }
      // Nothing close enough: use the target and let the safety pass fix it.
      if (best == 0 || bestDiff > total / numParts * 0.4) best = target;
      if (best > b.last) b.add(best);
    }

    // Keep punctuation with the text it belongs to: push boundaries past
    // closing punctuation, and pull them back before an opening quote/bracket.
    const closing = '。，、；：！？）】」』》〕”’…—.,;:!?)*';
    const opening = '（【「『《〔“‘(';
    for (var k = 1; k < b.length; k++) {
      var x = b[k];
      while (x + 1 < total && closing.contains(text[x])) {
        x++;
      }
      if (x > 0 && opening.contains(text[x - 1])) x--;
      if (x > b[k - 1] && (k == b.length - 1 || x < b[k + 1])) b[k] = x;
    }
    b.add(total);

    // Never cut before a combining mark, after a Thai leading vowel,
    // or right after a Khmer coeng.
    final mark = RegExp(r'\p{M}', unicode: true);
    const leadVowels = 'เแโใไ';
    bool unsafe(int x) =>
        x > 0 &&
        x < total &&
        (mark.hasMatch(text[x]) ||
            leadVowels.contains(text[x - 1]) ||
            text[x - 1] == '\u17D2' ||
            inProt(x));
    for (var k = 1; k < b.length; k++) {
      var x = b[k];
      while (x < total && unsafe(x)) {
        x++;
      }
      if (x > b[k - 1] && x < total && (k == b.length - 1 || x < b[k + 1])) b[k] = x;
    }

    final parts = <String>[];
    for (var i = 0; i < b.length - 1; i++) {
      final s = text.substring(b[i], b[i + 1]).trim();
      if (s.isNotEmpty) parts.add(s);
    }
    while (parts.length < numParts) {
      parts.add('');
    }
    return parts.take(numParts).toList();
  }

  Future<int> splitVttLongSubs(String inPath, String outPath) async {
    final lines = (await File(inPath).readAsString()).split(_newline);
    final out = <String>[];
    var splitCount = 0, i = 0;

    while (i < lines.length) {
      final line = lines[i];
      if (_timecodeRe.hasMatch(line.trim())) {
        final parts = line.split('-->');
        final startMs = _parseMs(parts[0]);
        final endMs = _parseMs(parts[1]);
        final textLines = <String>[];
        i++;
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i]);
          i++;
        }
        final original = textLines.map((t) => t.trim()).join(' ');
        final clean = original.replaceAll(_tagRe, '').replaceFirst(_verseNumRe, '');
        final script = detectScript(clean);
        final numParts = computeNumParts(clean.length, targetChars[script] ?? 80);

        if (numParts > 0) {
          final List<String> textParts;
          if (const {'chinese', 'japanese', 'korean', 'thai', 'khmer'}.contains(script)) {
            textParts = await _splitTokenized(clean, numParts, script);
          } else {
            // Arabic keeps inline tags; everything else splits the cleaned text.
            textParts = _splitWords(script == 'arabic' ? original : clean, numParts);
          }
          final dur = endMs - startMs;
          for (var idx = 0; idx < numParts; idx++) {
            final s = startMs + dur * idx ~/ numParts;
            final e = startMs + dur * (idx + 1) ~/ numParts;
            out.add('${_fmtMs(s)} --> ${_fmtMs(e)}');
            out.add(idx < textParts.length ? textParts[idx] : '');
            out.add('');
          }
          splitCount++;
        } else {
          out.add(line.trim());
          out.add(script == 'arabic' ? original : clean);
          out.add('');
        }
      } else {
        out.add(line);
        i++;
      }
    }
    final result = out.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    await File(outPath).writeAsString(result);
    return splitCount;
  }

  // ───────────────────────── VTT steps ─────────────────────────

  Future<void> backupSourceVtts(String root) async {
    log('=== Backing up / restoring original source VTT files ===');
    final dir = p.join(root, 'zsplit', 'zsourcevtt');
    await Directory(dir).create(recursive: true);
    var backed = 0, restored = 0;
    for (final s in ranges) {
      final f = _findVtt(root, s);
      if (f == null) {
        log('  WARNING: No source VTT for range $s — skipping backup');
        continue;
      }
      final backup = File(p.join(dir, p.basename(f.path)));
      if (await backup.exists()) {
        await backup.copy(f.path);
        restored++;
      } else {
        await f.copy(backup.path);
        backed++;
      }
    }
    log('  Backed up $backed, restored $restored original VTT files');
  }

  List<(String, List<String>)> _mergeCuesByVerse(List<(String, List<String>)> blocks) {
    final labelRe = RegExp(r'^\d+,\d+\s');
    final out = <(String, List<String>)>[];
    String? start, end;
    var text = <String>[];
    void flush() {
      if (start != null) out.add(('$start --> $end', text));
    }

    for (final (tc, lines) in blocks) {
      final parts = tc.split('-->');
      final s = parts[0].trim(), e = parts[1].trim();
      final first = lines.isEmpty ? '' : lines.first;
      if (start == null || labelRe.hasMatch(first)) {
        flush();
        start = s;
        text = lines;
      }
      end = e;
    }
    flush();
    return out;
  }

  Future<List<String>> _translateVtts(
      String root, String subdir, String prefix) async {
    log('  Step 4: Generate translated VTT files');
    var sample = '';
    final base = File(p.join(subdir, '$prefix.csv'));
    if (await base.exists()) {
      final rows = await _readCsv(base.path);
      final h = rows.first.map((e) => e.trim().toLowerCase()).toList();
      final ti = h.indexOf('translation');
      if (ti >= 0) {
        sample = rows
            .skip(1)
            .take(10)
            .where((r) => ti < r.length)
            .map((r) => r[ti].trim())
            .join(' ');
      }
    }
    final script = sample.isEmpty ? 'latin' : detectScript(sample);
    final noSep = const {'chinese', 'japanese', 'korean'}.contains(script);

    final created = <String>[];
    for (final suffix in ranges) {
      final srcVtt = _findVtt(root, suffix);
      if (srcVtt == null) continue;
      final csvPath = p.join(subdir, '$prefix$suffix.csv');
      if (!await File(csvPath).exists()) {
        log('    WARNING: CSV not found: $prefix$suffix.csv — skipping');
        continue;
      }
      final rows = await _readCsv(csvPath);
      final h = rows.first.map((e) => e.trim().toLowerCase()).toList();
      final si = h.indexOf('sura'), ai = h.indexOf('aya'), ti = h.indexOf('translation');
      final translations = rows.skip(1).where((r) => r.length > ti).toList();

      final (header, rawBlocks) = _parseVttBlocks(await srcVtt.readAsString());
      final blocks = _mergeCuesByVerse(rawBlocks);
      if (translations.length != blocks.length) {
        log('    WARNING: ${translations.length} translations != ${blocks.length} VTT cues '
            '(range $suffix)');
      }
      final newBlocks = <(String, List<String>)>[];
      for (var i = 0; i < blocks.length; i++) {
        final (tc, old) = blocks[i];
        if (i < translations.length) {
          final t = translations[i];
          final label = '${t[si]},${t[ai]}';
          newBlocks.add((tc, ['$label ${t[ti]}'.trim()]));
        } else {
          newBlocks.add((tc, old));
        }
      }
      final outPath = p.join(subdir, p.basename(srcVtt.path));
      await File(outPath).writeAsString(_buildVtt(header, newBlocks));
      log('    Created: ${p.basename(outPath)}');
      created.add(outPath);
      await _yield();
    }
    if (created.isEmpty) log('    No source VTT files found — skipping VTT generation.');
    return created;
  }

  Future<void> _splitCreated(String root, String subdir, List<String> vtts) async {
    log('  Step 4b: Split long subtitles');
    final lang = _capitalize(p.basename(subdir));
    final dir = p.join(root, 'zsplit', lang);
    await Directory(dir).create(recursive: true);
    for (final v in vtts) {
      final name = p.basename(v);
      final n = await splitVttLongSubs(v, p.join(dir, name));
      log('    $name: split $n long cues');
      await _yield();
    }
  }

  Future<void> copyAndSplitSourceVtts(String root) async {
    log('=== Splitting source English VTT files ===');
    final dir = p.join(root, 'zsplit', englishFolder);
    await Directory(dir).create(recursive: true);
    var n = 0;
    for (final s in ranges) {
      final f = _findVtt(root, s);
      if (f == null) continue;
      final c = await splitVttLongSubs(f.path, p.join(dir, p.basename(f.path)));
      log('  ${p.basename(f.path)}: split $c long cues');
      n++;
    }
    log('  Split $n source VTT files to zsplit/$englishFolder/');
  }

  Future<void> deploySplitSourceVtts(String root) async {
    log('=== Deploying split source VTT files to root ===');
    final dir = p.join(root, 'zsplit', englishFolder);
    if (!await Directory(dir).exists()) {
      log('  WARNING: zsplit/$englishFolder not found — skipping deploy');
      return;
    }
    final files = _files(dir, (n) => n.toLowerCase().endsWith('.vtt'));
    for (final f in files) {
      await f.copy(p.join(root, p.basename(f.path)));
    }
    log('  Deployed ${files.length} split VTT files to root directory.');
  }

  // ───────────────────────── unzip ─────────────────────────

  static final _rangeCsvRe =
      RegExp(r'^quran_saheeh\d{3}-\d{3}\.csv$', caseSensitive: false);

  static Future<int> extractZipInIsolate(
    Uint8List bytes,
    String root, {
    ZipExtractMode mode = ZipExtractMode.all,
  }) =>
      Isolate.run(() => extractZipBytes(bytes, root, mode: mode));

  static int extractZipBytes(
    Uint8List bytes,
    String root, {
    ZipExtractMode mode = ZipExtractMode.all,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);

    bool junk(String n) =>
        n.startsWith('__MACOSX') ||
        n.contains('/__MACOSX/') ||
        p.basename(n) == '.DS_Store';

    final entries = archive.files.where((f) => !junk(f.name)).toList();

    final tops = entries.map((f) => f.name.split('/').first).toSet();
    final hasTopLevelFile = entries.any((f) => f.isFile && !f.name.contains('/'));
    final prefix = (tops.length == 1 && !hasTopLevelFile) ? '${tops.first}/' : null;

    final rootNorm = p.normalize(p.absolute(root));
    var count = 0;
    for (final f in entries) {
      if (!f.isFile) continue;
      var name = f.name;
      if (prefix != null && name.startsWith(prefix)) name = name.substring(prefix.length);
      if (name.isEmpty) continue;

      // The 7 quran_saheehXXX-XXX.csv files sit at the top level of the zip.
      final isRangeCsv = !name.contains('/') && _rangeCsvRe.hasMatch(name);
      if (mode == ZipExtractMode.rangeCsvsOnly && !isRangeCsv) continue;
      if (mode == ZipExtractMode.languagesOnly && isRangeCsv) continue;

      final dest = p.normalize(p.join(rootNorm, name));
      if (!p.isWithin(rootNorm, dest)) continue;
      Directory(p.dirname(dest)).createSync(recursive: true);
      File(dest).writeAsBytesSync(f.content as List<int>);
      count++;
    }
    return count;
  }

  // ───────────────────────── orchestration ─────────────────────────

  Future<void> processLanguage(String root, String language,
      {required bool doVtt}) async {
    final subdir = p.join(root, language);
    var csvs = _files(subdir, (n) => n.toLowerCase().endsWith('.csv') && n.contains('_v'));
    if (csvs.isEmpty) csvs = _files(subdir, (n) => n.toLowerCase().endsWith('.csv'));
    if (csvs.isEmpty) {
      log('ERROR: No CSV files found in $language');
      return;
    }
    final source = csvs.first;
    final prefix = detectPrefix(source.path);
    log('\n${'=' * 50}\nProcessing: ${prefixToLabel(prefix)}  ($language)\n${'=' * 50}');

    final working = p.join(subdir, '$prefix.csv');
    if (source.path != working) await source.copy(working);

    await _cleanCsv(working);
    await _normalizeCsv(working);
    await _splitRanges(working, subdir, prefix);
    await _addArabicAudio(root, subdir, prefix);

    if (doVtt) {
      final vtts = await _translateVtts(root, subdir, prefix);
      if (vtts.isNotEmpty) await _splitCreated(root, subdir, vtts);
    }
  }

  Future<void> moveLanguageDirsToTemp(String root, List<String> langDirs) async {
    log('=== Moving language folders to tempcsvs ===');
    final temp = p.join(root, 'tempcsvs');
    await Directory(temp).create(recursive: true);
    var n = 0;
    for (final name in langDirs) {
      final src = Directory(p.join(root, name));
      if (!await src.exists()) continue;
      await _moveReplacing(src, p.join(temp, name));
      n++;
    }
    log('  Moved $n language folders into tempcsvs/');
  }

  Future<void> runBatch(String root,
      {required bool doVtt, ProgressFn? onProgress}) async {
    final dirs = findLanguageDirs(root);
    if (dirs.isEmpty) {
      log('ERROR: No subdirectories with CSV files found.');
      return;
    }
    if (doVtt) {
      await restorePackagedSources(root);
      await backupSourceVtts(root);
    }
    final width = dirs.length.toString().length;
    for (var i = 0; i < dirs.length; i++) {
      onProgress?.call(
        'Processing (${(i + 1).toString().padLeft(width, '0')}/${dirs.length}) ${dirs[i]}',
        i / dirs.length,
      );
      try {
        await processLanguage(root, dirs[i], doVtt: doVtt);
      } catch (e) {
        log('ERROR processing ${dirs[i]}: $e — continuing');
      }
      await _yield();
    }
    if (doVtt) {
      onProgress?.call('Splitting source VTTs...', 0.97);
      await copyAndSplitSourceVtts(root);
      await deploySplitSourceVtts(root);
      onProgress?.call('Packaging output...', 0.99);
      await packageOutput(root);
      await moveLanguageDirsToTemp(root, dirs);
    }
  }

  // ───────────────────────── packaging ─────────────────────────

  static final _rangeInNameRe = RegExp(r' \d{3}-\d{3}(?= )');

  Future<void> _moveReplacing(FileSystemEntity e, String dest) async {
    switch (FileSystemEntity.typeSync(dest)) {
      case FileSystemEntityType.directory:
        await Directory(dest).delete(recursive: true);
      case FileSystemEntityType.file:
        await File(dest).delete();
      default:
        break;
    }
    await e.rename(dest);
  }

  /// Moves everything produced by the batch into one folder named like the
  /// audiobooks but without the surah range, e.g.
  /// "Quran Arabic - (Fares Abbad) Verse by Verse":
  ///  - every language folder in zsplit/ (incl. "a English saheeh" and zsourcevtt)
  ///  - the range .opus and .vtt files sitting in root
  /// Returns the folder path, or null if the name could not be derived.
  Future<String?> packageOutput(String root) async {
    log('=== Packaging output ===');

    final rootFiles = _files(root, (n) {
      final l = n.toLowerCase();
      if (!l.endsWith('.opus') && !l.endsWith('.vtt')) return false;
      final m = _rangeInNameRe.firstMatch(n);
      return m != null && ranges.contains(m.group(0)!.trim());
    });

    if (rootFiles.isEmpty) {
      log('  WARNING: No range .opus/.vtt files found in root — cannot name the '
          'output folder, skipping packaging');
      return null;
    }

    final base = p.basenameWithoutExtension(rootFiles.first.path);
    final folderName = base.replaceFirst(_rangeInNameRe, '');
    final dest = p.join(root, folderName);
    await Directory(dest).create(recursive: true);

    var dirs = 0, files = 0;

    final zsplit = Directory(p.join(root, 'zsplit'));
    if (await zsplit.exists()) {
      for (final e in zsplit.listSync()) {
        await _moveReplacing(e, p.join(dest, p.basename(e.path)));
        dirs++;
      }
      if (zsplit.listSync().isEmpty) await zsplit.delete();
    } else {
      log('  WARNING: zsplit not found — only moving root files');
    }

    for (final f in rootFiles) {
      await _moveReplacing(f, p.join(dest, p.basename(f.path)));
      files++;
    }

    log('  Moved $dirs folders and $files files into "$folderName"');
    return dest;
  }

  /// If a previous run packaged the output, bring the original source VTTs back
  /// so the pipeline can run again. Only fills in what is missing.
  Future<void> restorePackagedSources(String root) async {
    for (final d in Directory(root).listSync().whereType<Directory>()) {
      final src = Directory(p.join(d.path, 'zsourcevtt'));
      if (!await src.exists()) continue;

      final backupDir = Directory(p.join(root, 'zsplit', 'zsourcevtt'));
      await backupDir.create(recursive: true);
      var n = 0;
      for (final f in src.listSync().whereType<File>()) {
        final name = p.basename(f.path);
        final inBackup = File(p.join(backupDir.path, name));
        final inRoot = File(p.join(root, name));
        if (!await inBackup.exists()) await f.copy(inBackup.path);
        if (!await inRoot.exists()) await f.copy(inRoot.path);
        n++;
      }
      log('Restored $n original source VTT(s) from ${p.basename(d.path)}/zsourcevtt');
      return;
    }
  }
}
