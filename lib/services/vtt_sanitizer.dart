/// Final-pass VTT timecode sanitizer. It never deletes or moves text.
///
/// Guarantees on the output:
///  - every timestamp has milliseconds in 0..999 (overflow is carried into seconds)
///  - every cue has end > start
///  - every cue start >= previous cue start
///  - no cue overlaps the previous one (prev.end <= start)
///
/// Zero-duration cues (whisper.cpp artifact at segment joins) are fixed like so:
///  1. If the NEXT cue starts later, the cue's end becomes that start.
///  2. Otherwise the cue is given a 1 second duration BEFORE its old start,
///     and the previous cue is shortened so it ends where this cue now begins:
///        A 13.080-22.080, B 22.080-22.080, C 22.080-26.580
///        -> A 13.080-21.080, B 21.080-22.080, C 22.080-26.580
///  3. If there's no usable previous cue (first cue, or it's too short to
///     shorten), the cue gets 1 second AFTER its start and the next cue's
///     start is pushed to match.
class VttCue {
  int start;
  int end;
  List<String> text;
  VttCue(this.start, this.end, this.text);
}

class VttSanitizeResult {
  final String content;
  final int fixes;
  VttSanitizeResult(this.content, this.fixes);
}

class VttSanitizer {
  /// Duration given to a zero-duration cue that can't just be extended.
  static const int fallbackMs = 1000;

  static final RegExp _timeRe = RegExp(
    r'^\s*(?:(\d+):)?(\d+):(\d+)[.,](\d+)\s+-->\s+(?:(\d+):)?(\d+):(\d+)[.,](\d+)',
  );

  static int _toMs(String? h, String m, String s, String ms) {
    final msVal = int.parse(ms.length > 3 ? ms.substring(0, 3) : ms.padRight(3, '0'));
    return ((int.parse(h ?? '0') * 60 + int.parse(m)) * 60 + int.parse(s)) * 1000 + msVal;
  }

  static String formatMs(int total) {
    if (total < 0) total = 0;
    final ms = total % 1000;
    final totalSec = total ~/ 1000;
    final s = totalSec % 60;
    final m = (totalSec ~/ 60) % 60;
    final h = totalSec ~/ 3600;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  static List<VttCue> parse(String content) {
    final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final cues = <VttCue>[];
    int i = 0;
    while (i < lines.length) {
      final match = _timeRe.firstMatch(lines[i]);
      if (match == null) {
        i++;
        continue;
      }
      final start = _toMs(match.group(1), match.group(2)!, match.group(3)!, match.group(4)!);
      final end = _toMs(match.group(5), match.group(6)!, match.group(7)!, match.group(8)!);
      final text = <String>[];
      i++;
      while (i < lines.length && lines[i].trim().isNotEmpty && !_timeRe.hasMatch(lines[i])) {
        text.add(lines[i]);
        i++;
      }
      cues.add(VttCue(start, end, text));
    }
    return cues;
  }

  static VttSanitizeResult sanitize(String content) {
    final cues = parse(content);
    int fixes = 0;

    for (int i = 0; i < cues.length; i++) {
      final cur = cues[i];

      if (i > 0) {
        final prev = cues[i - 1];

        // Start must never be earlier than the previous start.
        if (cur.start < prev.start) {
          cur.start = prev.start;
          fixes++;
        }

        // No overlap with the previous cue.
        if (cur.start < prev.end) {
          if (cur.start > prev.start) {
            prev.end = cur.start; // trim previous cue
          } else {
            cur.start = prev.end; // same start: push this one after previous
          }
          fixes++;
        }
      }

      // End must be strictly after start.
      if (cur.end <= cur.start) {
        final hasNext = i + 1 < cues.length;
        final prev = i > 0 ? cues[i - 1] : null;

        if (hasNext && cues[i + 1].start > cur.start) {
          // 1) end = start of the next cue
          cur.end = cues[i + 1].start;
        } else if (prev != null && (cur.start - prev.start) >= 2) {
          // 2) borrow time from the previous cue (up to 1s, never more than half of it)
          final room = cur.start - prev.start;
          final shift = room ~/ 2 < fallbackMs ? room ~/ 2 : fallbackMs;
          final oldStart = cur.start;
          cur.start = oldStart - shift;
          cur.end = oldStart;
          if (prev.end > cur.start) prev.end = cur.start;
        } else {
          // 3) give it a duration; next cue's start gets pushed by the overlap rule
          cur.end = cur.start + fallbackMs;
        }
        fixes++;
      }
    }

    // Verification pass (safety net).
    for (int k = 0; k < cues.length; k++) {
      final c = cues[k];
      if (c.end <= c.start) c.end = c.start + 1;
      if (k > 0 && cues[k - 1].end > c.start) cues[k - 1].end = c.start;
      if (k > 0 && cues[k - 1].end <= cues[k - 1].start) {
        c.start = cues[k - 1].start + 1;
        cues[k - 1].end = c.start;
        if (c.end <= c.start) c.end = c.start + 1;
      }
    }

    final buf = StringBuffer('WEBVTT\n\n');
    for (final c in cues) {
      buf.writeln('${formatMs(c.start)} --> ${formatMs(c.end)}');
      for (final t in c.text) {
        buf.writeln(t);
      }
      buf.writeln();
    }
    return VttSanitizeResult(buf.toString().trimRight() + '\n', fixes);
  }
}
