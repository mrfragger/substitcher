import 'dart:io';
import '../models/subtitle_cue.dart';
import '../models/vtt_show_style.dart';

class VttShowService {
  static const String spacerDelimiter = '|||';
  static const String renderedSpacer = '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';

  static String renderSpacers(String text) {
    return text.replaceAll(spacerDelimiter, renderedSpacer);
  }

  static String unrenderSpacers(String text) {
    return text.replaceAll(renderedSpacer, spacerDelimiter);
  }

  static Future<Map<String, VttShowStyle>> load(String vttPath) async {
    final result = <String, VttShowStyle>{};
    final content = await File(vttPath).readAsString();

    final markerIndex = content.indexOf('\nVTTSHOW');
    if (markerIndex == -1) return result;

    final vttShowContent = content.substring(markerIndex + 1);
    final lines = vttShowContent.split('\n');

    final timecodeRegex = RegExp(
      r'^(\d{2}:\d{2}:\d{2}\.\d{3})\s+-->\s+(\d{2}:\d{2}:\d{2}\.\d{3})\s+(.+)$',
    );

    for (final line in lines) {
      final trimmed = line.trim();
      final match = timecodeRegex.firstMatch(trimmed);
      if (match == null) continue;

      final start = match.group(1)!;
      final end = match.group(2)!;
      final key = '$start --> $end';
      final styleStr = match.group(3)!;

      final style = _parseStyle(styleStr);
      if (style != null) {
        result[key] = style;
      }
    }

    return result;
  }

  /// Reconcile styles with current cues after external edits.
  /// If timecodes still match, keeps them. Otherwise remaps by position.
  static Map<String, VttShowStyle> reconcile({
    required Map<String, VttShowStyle> styles,
    required List<SubtitleCue> cues,
  }) {
    if (styles.isEmpty || cues.isEmpty) return styles;

    final cueKeys = cues.map((c) => c.timecodeKey).toSet();

    // If all style keys match existing cues, nothing to fix
    if (styles.keys.every((k) => cueKeys.contains(k))) {
      return styles;
    }

    // Orphaned styles — remap by position order
    final sortedStyleEntries = styles.entries.toList()
      ..sort((a, b) =>
          _parseStartTime(a.key).compareTo(_parseStartTime(b.key)));

    final sortedCues = List<SubtitleCue>.from(cues)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final result = <String, VttShowStyle>{};

    for (int i = 0;
        i < sortedStyleEntries.length && i < sortedCues.length;
        i++) {
      result[sortedCues[i].timecodeKey] = sortedStyleEntries[i].value;
    }

    return result;
  }

  static VttShowStyle? _parseStyle(String styleStr) {
    final fieldRegex = RegExp(r'\{([^}]*)\}');
    final matches = fieldRegex.allMatches(styleStr).toList();
    if (matches.isEmpty) return null;

    String? get(int index) {
      if (index >= matches.length) return null;
      final val = matches[index].group(1)!.trim();
      return val.isEmpty ? null : val;
    }

    return VttShowStyle(
      font:              get(0),
      conversion:        get(1),
      fontColorOverride: get(2),
      colorPalette:      get(3),
      fontSize:          get(4) != null ? double.tryParse(get(4)!) : null,
      lineSpacing:       get(5) != null ? double.tryParse(get(5)!) : null,
      coloringMode:      get(6),
      blurShadow:        get(7),
    );
  }

  static String? vttShowPathFor(String vttPath) {
    try {
      final content = File(vttPath).readAsStringSync();
      return content.contains('\nVTTSHOW') ? vttPath : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save({
    required String vttPath,
    required Map<String, VttShowStyle> styles,
    required List<String> subtitleCueKeys,
    String? vttContent,
  }) async {
    final file = File(vttPath);
    final existing = await file.readAsString();
    final markerIndex = existing.indexOf('\nVTTSHOW');

    final vttOnly = vttContent ?? (markerIndex != -1
        ? existing.substring(0, markerIndex)
        : existing);

    final validEntries = styles.entries
        .where((e) => subtitleCueKeys.contains(e.key))
        .toList();

    validEntries.sort((a, b) {
      final aTime = _parseStartTime(a.key);
      final bTime = _parseStartTime(b.key);
      return aTime.compareTo(bTime);
    });

    if (validEntries.isEmpty) {
      await file.writeAsString(vttOnly.trimRight() + '\n');
      return;
    }

    final buffer = StringBuffer();
    buffer.write(vttOnly.trimRight());
    buffer.write('\n\nVTTSHOW\n');

    for (final entry in validEntries) {
      final style = entry.value;
      final font         = style.font ?? '';
      final conversion   = style.conversion ?? '';
      final fontColor    = style.fontColorOverride ?? '';
      final colorPalette = style.colorPalette ?? '';
      final fontSize     = style.fontSize != null
          ? style.fontSize!.toStringAsFixed(0)
          : '';
      final lineSpacing  = style.lineSpacing != null
          ? style.lineSpacing!.toStringAsFixed(2)
          : '';
      final coloringMode = style.coloringMode ?? '';
      final blurShadow   = style.blurShadow ?? '';
      buffer.writeln(
        '${entry.key} {$font},{$conversion},{$fontColor},{$colorPalette},{$fontSize},{$lineSpacing},{$coloringMode},{$blurShadow}',
      );
    }

    await file.writeAsString(buffer.toString());
  }

  static Duration _parseStartTime(String timecodeKey) {
    final start = timecodeKey.split(' --> ').first.trim();
    final parts = start.split(':');
    if (parts.length != 3) return Duration.zero;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final sParts = parts[2].split('.');
    final s = int.tryParse(sParts[0]) ?? 0;
    final ms = int.tryParse(sParts.length > 1 ? sParts[1] : '0') ?? 0;
    return Duration(hours: h, minutes: m, seconds: s, milliseconds: ms);
  }
}
