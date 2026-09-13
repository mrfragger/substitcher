import 'dart:async';
import 'dart:io';

class JuzSegment {
  final int surah;
  final int from;
  final int to;
  const JuzSegment(this.surah, this.from, this.to);
}

/// Index 0 = Juz 1 ... index 29 = Juz 30.
const List<List<JuzSegment>> juzSegments = [
  [JuzSegment(1, 1, 7), JuzSegment(2, 1, 141)],
  [JuzSegment(2, 142, 252)],
  [JuzSegment(2, 253, 286), JuzSegment(3, 1, 92)],
  [JuzSegment(3, 93, 200), JuzSegment(4, 1, 23)],
  [JuzSegment(4, 24, 147)],
  [JuzSegment(4, 148, 176), JuzSegment(5, 1, 81)],
  [JuzSegment(5, 82, 120), JuzSegment(6, 1, 110)],
  [JuzSegment(6, 111, 165), JuzSegment(7, 1, 87)],
  [JuzSegment(7, 88, 206), JuzSegment(8, 1, 40)],
  [JuzSegment(8, 41, 75), JuzSegment(9, 1, 92)],
  [JuzSegment(9, 93, 129), JuzSegment(10, 1, 109), JuzSegment(11, 1, 5)],
  [JuzSegment(11, 6, 123), JuzSegment(12, 1, 52)],
  [JuzSegment(12, 53, 111), JuzSegment(13, 1, 43), JuzSegment(14, 1, 52)],
  [JuzSegment(15, 1, 99), JuzSegment(16, 1, 128)],
  [JuzSegment(17, 1, 111), JuzSegment(18, 1, 74)],
  [JuzSegment(18, 75, 110), JuzSegment(19, 1, 98), JuzSegment(20, 1, 135)],
  [JuzSegment(21, 1, 112), JuzSegment(22, 1, 78)],
  [JuzSegment(23, 1, 118), JuzSegment(24, 1, 64), JuzSegment(25, 1, 20)],
  [JuzSegment(25, 21, 77), JuzSegment(26, 1, 227), JuzSegment(27, 1, 55)],
  [JuzSegment(27, 56, 93), JuzSegment(28, 1, 88), JuzSegment(29, 1, 45)],
  [
    JuzSegment(29, 46, 69), JuzSegment(30, 1, 60), JuzSegment(31, 1, 34),
    JuzSegment(32, 1, 30), JuzSegment(33, 1, 30),
  ],
  [
    JuzSegment(33, 31, 73), JuzSegment(34, 1, 54), JuzSegment(35, 1, 45),
    JuzSegment(36, 1, 27),
  ],
  [
    JuzSegment(36, 28, 83), JuzSegment(37, 1, 182), JuzSegment(38, 1, 88),
    JuzSegment(39, 1, 31),
  ],
  [JuzSegment(39, 32, 75), JuzSegment(40, 1, 85), JuzSegment(41, 1, 46)],
  [
    JuzSegment(41, 47, 54), JuzSegment(42, 1, 53), JuzSegment(43, 1, 89),
    JuzSegment(44, 1, 59), JuzSegment(45, 1, 37),
  ],
  [
    JuzSegment(46, 1, 35), JuzSegment(47, 1, 38), JuzSegment(48, 1, 29),
    JuzSegment(49, 1, 18), JuzSegment(50, 1, 45), JuzSegment(51, 1, 30),
  ],
  [
    JuzSegment(51, 31, 60), JuzSegment(52, 1, 49), JuzSegment(53, 1, 62),
    JuzSegment(54, 1, 55), JuzSegment(55, 1, 78), JuzSegment(56, 1, 96),
    JuzSegment(57, 1, 29),
  ],
  [
    JuzSegment(58, 1, 22), JuzSegment(59, 1, 24), JuzSegment(60, 1, 13),
    JuzSegment(61, 1, 14), JuzSegment(62, 1, 11), JuzSegment(63, 1, 11),
    JuzSegment(64, 1, 18), JuzSegment(65, 1, 12), JuzSegment(66, 1, 12),
  ],
  [
    JuzSegment(67, 1, 30), JuzSegment(68, 1, 52), JuzSegment(69, 1, 52),
    JuzSegment(70, 1, 44), JuzSegment(71, 1, 28), JuzSegment(72, 1, 28),
    JuzSegment(73, 1, 20), JuzSegment(74, 1, 56), JuzSegment(75, 1, 40),
    JuzSegment(76, 1, 31), JuzSegment(77, 1, 50),
  ],
  [
    JuzSegment(78, 1, 40), JuzSegment(79, 1, 46), JuzSegment(80, 1, 42),
    JuzSegment(81, 1, 29), JuzSegment(82, 1, 19), JuzSegment(83, 1, 36),
    JuzSegment(84, 1, 25), JuzSegment(85, 1, 22), JuzSegment(86, 1, 17),
    JuzSegment(87, 1, 19), JuzSegment(88, 1, 26), JuzSegment(89, 1, 30),
    JuzSegment(90, 1, 20), JuzSegment(91, 1, 15), JuzSegment(92, 1, 21),
    JuzSegment(93, 1, 11), JuzSegment(94, 1, 8), JuzSegment(95, 1, 8),
    JuzSegment(96, 1, 19), JuzSegment(97, 1, 5), JuzSegment(98, 1, 8),
    JuzSegment(99, 1, 8), JuzSegment(100, 1, 11), JuzSegment(101, 1, 11),
    JuzSegment(102, 1, 8), JuzSegment(103, 1, 3), JuzSegment(104, 1, 9),
    JuzSegment(105, 1, 5), JuzSegment(106, 1, 4), JuzSegment(107, 1, 7),
    JuzSegment(108, 1, 3), JuzSegment(109, 1, 6), JuzSegment(110, 1, 3),
    JuzSegment(111, 1, 5), JuzSegment(112, 1, 4), JuzSegment(113, 1, 5),
    JuzSegment(114, 1, 6),
  ],
];

class _Cue {
  final Duration start;
  final Duration end;
  final String text;
  _Cue(this.start, this.end, this.text);
}

final RegExp _timestampRe = RegExp(
  r'^(\d{2}):(\d{2}):(\d{2})\.(\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})\.(\d{3})',
);
final RegExp _labelRe = RegExp(r'^(\d{1,3}),(\d{1,3})\b');

Duration _dur(String h, String m, String s, String ms) => Duration(
      hours: int.parse(h),
      minutes: int.parse(m),
      seconds: int.parse(s),
      milliseconds: int.parse(ms),
    );

List<_Cue> _parseVtt(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final cues = <_Cue>[];
  int i = 0;
  while (i < lines.length) {
    final m = _timestampRe.firstMatch(lines[i].trim());
    if (m != null) {
      final start = _dur(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!);
      final end = _dur(m.group(5)!, m.group(6)!, m.group(7)!, m.group(8)!);
      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        textLines.add(lines[i].trim());
        i++;
      }
      cues.add(_Cue(start, end, textLines.join(' ')));
    } else {
      i++;
    }
  }
  return cues;
}

void _accumulateAyahDurations(List<_Cue> cues, Map<String, Duration> out) {
  String? currentKey;
  Duration? currentStart;
  Duration? currentEnd;

  void flush() {
    if (currentKey != null && currentStart != null && currentEnd != null) {
      out[currentKey!] = currentEnd! - currentStart!;
    }
  }

  for (final cue in cues) {
    final m = _labelRe.firstMatch(cue.text);
    if (m != null) {
      flush();
      currentKey = '${m.group(1)}:${m.group(2)}';
      currentStart = cue.start;
      currentEnd = cue.end;
    } else if (currentKey != null) {
      currentEnd = cue.end;
    }
  }
  flush();
}

// dirPath -> 30 Juz durations (seconds), cached for the session.
final Map<String, List<int>> _juzDurationsCache = {};
final Map<String, Future<List<int>?>> _juzDurationsInFlight = {};

/// Computes (or returns cached) Juz durations in seconds from every .vtt
/// file directly inside [dirPath]. Returns null if no .vtt files found.
Future<List<int>?> computeJuzDurationsForDirectory(String dirPath) {
  final cached = _juzDurationsCache[dirPath];
  if (cached != null) return Future.value(cached);

  final inFlight = _juzDurationsInFlight[dirPath];
  if (inFlight != null) return inFlight;

  final future = _computeJuzDurationsForDirectoryUncached(dirPath);
  _juzDurationsInFlight[dirPath] = future;
  future.then((result) {
    _juzDurationsInFlight.remove(dirPath);
    if (result != null) _juzDurationsCache[dirPath] = result;
  });
  return future;
}

Future<List<int>?> _computeJuzDurationsForDirectoryUncached(
    String dirPath) async {
  final dir = Directory(dirPath);
  if (!await dir.exists()) return null;

  final entries = await dir.list().toList();
  final vttFiles = entries
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.vtt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (vttFiles.isEmpty) return null;

  final ayahDurations = <String, Duration>{};
  for (final f in vttFiles) {
    final content = await f.readAsString();
    final cues = _parseVtt(content);
    _accumulateAyahDurations(cues, ayahDurations);
  }

  final result = <int>[];
  for (final segments in juzSegments) {
    Duration total = Duration.zero;
    for (final seg in segments) {
      for (int ayah = seg.from; ayah <= seg.to; ayah++) {
        final d = ayahDurations['${seg.surah}:$ayah'];
        if (d != null) total += d;
      }
    }
    result.add(total.inSeconds);
  }
  return result;
}

String formatJuzDuration(List<int>? juzDurations, int juzNumber) {
  if (juzDurations == null || juzNumber < 1 || juzNumber > juzDurations.length) {
    return '';
  }
  final mins = (juzDurations[juzNumber - 1] / 60).round();
  return mins >= 60 ? '${mins ~/ 60}h ${mins % 60}m' : '${mins}m';
}

String formatTotalJuzDuration(List<int>? juzDurations) {
  if (juzDurations == null || juzDurations.isEmpty) return '';
  final totalSeconds = juzDurations.fold<int>(0, (sum, s) => sum + s);
  final mins = (totalSeconds / 60).round();
  final hours = mins ~/ 60;
  final remMins = mins % 60;
  return '${hours}h ${remMins}m';
}

String formatJuzRangeDuration(List<int>? juzDurations, int fromJuz, int toJuz) {
  if (juzDurations == null) return '';
  if (fromJuz < 1 || toJuz > juzDurations.length || fromJuz > toJuz) return '';
  int totalSeconds = 0;
  for (int i = fromJuz; i <= toJuz; i++) {
    totalSeconds += juzDurations[i - 1];
  }
  final mins = (totalSeconds / 60).round();
  final hours = mins ~/ 60;
  final remMins = mins % 60;
  return hours > 0 ? '${hours}h ${remMins}m' : '${mins}m';
}
