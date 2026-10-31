// lib/services/svg_palette_svg.dart
//
// SVG rewriting for the palette tool (ports of Themify.swift and ImportSVG.swift).
//  - themify():          vtracer output  -> N colour slots, class="cN" / <g id="cN">
//  - themifyExisting():  any SVG file    -> every colour becomes var(--cN, original)
// Pure Dart; safe to run inside Isolate.run.
import 'svg_palette_color.dart';

class SvgPaletteException implements Exception {
  final String message;
  SvgPaletteException(this.message);
  @override
  String toString() => message;
}

class ThemedSvg {
  final String svg;
  final int width, height, pathCount;
  const ThemedSvg(this.svg, this.width, this.height, this.pathCount);
}

class ImportedSvg {
  final String svg;
  final int width, height;
  final List<Rgb> palette;
  final Map<String, int> slotMap; // '#rrggbb' of every original colour -> 0-based slot
  const ImportedSvg(this.svg, this.width, this.height, this.palette, this.slotMap);
}

// ───────────────────────── helpers ─────────────────────────

List<List<String>> _captures(RegExp re, String s) => [
      for (final m in re.allMatches(s))
        [for (var i = 0; i <= m.groupCount; i++) m.group(i) ?? '']
    ];

final RegExp _attrPair = RegExp(r'([A-Za-z_:][\w:.-]*)\s*=\s*"([^"]*)"', dotAll: true);

Map<String, String> _attributes(String tag) =>
    {for (final m in _captures(_attrPair, tag)) m[1]: m[2]};

Rgb? _parseTraceColor(String s) {
  final t = s.trim().toLowerCase();
  if (t.startsWith('#')) {
    var h = t.substring(1);
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Rgb((v >> 16) & 255, (v >> 8) & 255, v & 255);
  }
  if (t.startsWith('rgb')) {
    final n = _captures(RegExp(r'(\d+)'), t).map((m) => int.parse(m[1])).toList();
    if (n.length < 3) return null;
    return Rgb(n[0].clamp(0, 255).toInt(), n[1].clamp(0, 255).toInt(), n[2].clamp(0, 255).toInt());
  }
  return null;
}

int _closestSlot(Rgb c, List<Rgb> palette) {
  var best = 0, bd = 1 << 62;
  for (var i = 0; i < palette.length; i++) {
    final p = palette[i];
    final dr = c.r - p.r, dg = c.g - p.g, db = c.b - p.b;
    final d = dr * dr + dg * dg + db * db;
    if (d < bd) {
      bd = d;
      best = i;
    }
  }
  return best;
}

// ───────────────────────── traced SVG ─────────────────────────

final RegExp _sizeAttrs = RegExp(
    r'<svg\b[^>]*?\bwidth="(\d+(?:\.\d+)?)(?:px)?"[^>]*?\bheight="(\d+(?:\.\d+)?)(?:px)?"',
    dotAll: true);
final RegExp _viewBoxSize = RegExp(
    r'viewBox="\s*[-\d.]+[ ,]+[-\d.]+[ ,]+(\d+(?:\.\d+)?)[ ,]+(\d+(?:\.\d+)?)"',
    dotAll: true);
final RegExp _pathTag = RegExp(r'<path\b([^>]*?)/?>', dotAll: true);

/// Rewrites vtracer output so every shape belongs to one of N palette slots.
///
/// Every slot gets `.cN { fill: var(--cN, #hex) }` in a <style> block, so a page (or any CSS)
/// can retheme the SVG by setting --c1 ... --cN on the <svg> or an ancestor, while editors that
/// ignore CSS variables still see the real fill colours.
///
/// grouped (vtracer cutout = seam-free, non-overlapping): shapes are collected into one real
///   <g id="cN" class="cN" fill="#hex"> per slot.
/// stacked: shapes keep vtracer's paint order, each tagged class="cN" fill="#hex".
ThemedSvg themify(String raw, List<Rgb> palette, {required bool grouped}) {
  var w = 0, h = 0;
  final sm = _captures(_sizeAttrs, raw);
  if (sm.isNotEmpty && double.tryParse(sm.first[1]) != null && double.tryParse(sm.first[2]) != null) {
    w = double.parse(sm.first[1]).round();
    h = double.parse(sm.first[2]).round();
  } else {
    final vm = _captures(_viewBoxSize, raw);
    if (vm.isNotEmpty && double.tryParse(vm.first[1]) != null && double.tryParse(vm.first[2]) != null) {
      w = double.parse(vm.first[1]).round();
      h = double.parse(vm.first[2]).round();
    }
  }
  if (w <= 0 || h <= 0) {
    throw SvgPaletteException('unexpected SVG: no width/height or viewBox on <svg>');
  }

  final shapes = <({int slot, String d, String transform, String fillRule})>[];
  var skipped = 0;
  for (final m in _captures(_pathTag, raw)) {
    final a = _attributes(m[1]);
    final d = a['d'];
    final fill = a['fill'];
    final color = fill == null ? null : _parseTraceColor(fill);
    if (d == null || color == null) {
      skipped++;
      continue;
    }
    var t = a['transform'] ?? '';
    if (t.replaceAll(' ', '') == 'translate(0,0)') t = '';
    shapes.add((
      slot: _closestSlot(color, palette),
      d: d,
      transform: t,
      fillRule: a['fill-rule'] ?? '',
    ));
  }
  if (shapes.isEmpty) {
    final head = (raw.length > 300 ? raw.substring(0, 300) : raw).replaceAll('\n', ' ');
    throw SvgPaletteException(
        'unexpected SVG: no <path> with d= and fill= found (skipped $skipped). Start of file: $head');
  }

  String pathTag(({int slot, String d, String transform, String fillRule}) s,
      {required bool withFill}) {
    final out = StringBuffer('<path');
    if (withFill) out.write(' class="c${s.slot + 1}" fill="${palette[s.slot].hex}"');
    out.write(' d="${s.d}"');
    if (s.transform.isNotEmpty) out.write(' transform="${s.transform}"');
    if (s.fillRule.isNotEmpty) out.write(' fill-rule="${s.fillRule}"');
    out.write('/>');
    return out.toString();
  }

  final css = [
    for (var i = 0; i < palette.length; i++)
      '.c${i + 1}{fill:var(--c${i + 1},${palette[i].hex})}'
  ].join();

  final body = StringBuffer();
  if (grouped) {
    final buckets = List.generate(palette.length, (_) => <String>[]);
    for (final s in shapes) {
      buckets[s.slot].add(pathTag(s, withFill: false));
    }
    for (var i = 0; i < buckets.length; i++) {
      if (buckets[i].isEmpty) continue;
      body.write('<g id="c${i + 1}" class="c${i + 1}" fill="${palette[i].hex}">\n');
      body.write('${buckets[i].join('\n')}\n</g>\n');
    }
  } else {
    body.write(shapes.map((s) => pathTag(s, withFill: true)).join('\n'));
  }

  final svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $w $h" width="$w" height="$h">\n'
      '<style>$css</style>\n'
      '$body\n'
      '</svg>';
  return ThemedSvg(svg, w, h, shapes.length);
}

// ───────────────────────── imported SVG ─────────────────────────
//
// SVG input: reduce the file's colours to N slots and rewrite every colour to
//   var(--cN, <original colour>)
// inside style attributes / <style> blocks. The result themes exactly like a traced image,
// and with no variables set it still shows the original colours.

const _colorProps = ['fill', 'stroke', 'stop-color', 'flood-color', 'lighting-color'];
const _shapeTags = {'path', 'rect', 'circle', 'ellipse', 'polygon', 'polyline', 'text'};

const Map<String, (int, int, int)> _namedColors = {
  'black': (0, 0, 0), 'white': (255, 255, 255), 'red': (255, 0, 0), 'lime': (0, 255, 0),
  'blue': (0, 0, 255), 'yellow': (255, 255, 0), 'cyan': (0, 255, 255), 'aqua': (0, 255, 255),
  'magenta': (255, 0, 255), 'fuchsia': (255, 0, 255), 'silver': (192, 192, 192),
  'gray': (128, 128, 128), 'grey': (128, 128, 128), 'maroon': (128, 0, 0), 'olive': (128, 128, 0),
  'green': (0, 128, 0), 'purple': (128, 0, 128), 'teal': (0, 128, 128), 'navy': (0, 0, 128),
  'orange': (255, 165, 0), 'pink': (255, 192, 203), 'brown': (165, 42, 42), 'gold': (255, 215, 0),
  'indigo': (75, 0, 130), 'violet': (238, 130, 238), 'tan': (210, 180, 140), 'beige': (245, 245, 220),
  'ivory': (255, 255, 240), 'khaki': (240, 230, 140), 'coral': (255, 127, 80), 'salmon': (250, 128, 114),
  'crimson': (220, 20, 60), 'turquoise': (64, 224, 208), 'lavender': (230, 230, 250),
  'darkgray': (169, 169, 169), 'darkgrey': (169, 169, 169), 'lightgray': (211, 211, 211),
  'lightgrey': (211, 211, 211), 'dimgray': (105, 105, 105), 'gainsboro': (220, 220, 220),
  'whitesmoke': (245, 245, 245), 'darkblue': (0, 0, 139), 'darkgreen': (0, 100, 0),
  'darkred': (139, 0, 0), 'skyblue': (135, 206, 235), 'lightblue': (173, 216, 230),
  'royalblue': (65, 105, 225), 'steelblue': (70, 130, 180), 'orangered': (255, 69, 0),
  'chocolate': (210, 105, 30), 'sienna': (160, 82, 45), 'peru': (205, 133, 63),
  'goldenrod': (218, 165, 32), 'plum': (221, 160, 221), 'orchid': (218, 112, 214),
  'hotpink': (255, 105, 180), 'deeppink': (255, 20, 147), 'limegreen': (50, 205, 50),
  'forestgreen': (34, 139, 34), 'seagreen': (46, 139, 87), 'slategray': (112, 128, 144),
  'slategrey': (112, 128, 144),
};

Rgb? parseCssColor(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.isEmpty) return null;
  if (t.startsWith('#')) {
    var h = t.substring(1);
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length != 6) return null; // 4/8-digit (alpha) left untouched
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Rgb((v >> 16) & 255, (v >> 8) & 255, v & 255);
  }
  if (t.startsWith('rgb(') || t.startsWith('rgba(')) {
    final m = RegExp(r'(\d+(?:\.\d+)?)(%?)').allMatches(t).toList();
    if (m.length < 3) return null;
    int channel(int i) {
      final v = double.tryParse(m[i].group(1)!) ?? 0;
      final pct = (m[i].group(2) ?? '').isNotEmpty;
      return (pct ? v * 2.55 : v).round().clamp(0, 255).toInt();
    }

    return Rgb(channel(0), channel(1), channel(2));
  }
  final n = _namedColors[t];
  return n == null ? null : Rgb(n.$1, n.$2, n.$3);
}

final RegExp _declRegex = RegExp(
    r'''(?<![\w-])(fill|stroke|stop-color|flood-color|lighting-color)(\s*:\s*)([^;"'}{!]+)''');

/// Rewrites `prop: <colour>` declarations inside CSS / style attribute text.
String _mapDeclarations(String text, String Function(Rgb) color) {
  return text.replaceAllMapped(_declRegex, (m) {
    final value = m.group(3)!;
    final rgb = parseCssColor(value);
    if (rgb == null) return m.group(0)!;
    final trailing = value.endsWith(' ') ? ' ' : '';
    return '${m.group(1)}${m.group(2)}${color(rgb)}$trailing';
  });
}

final RegExp _attrRegex =
    RegExp(r'''([A-Za-z_:][\w:.-]*)\s*=\s*(?:"([^"]*)"|'([^']*)')''');
final RegExp _tagRegex = RegExp(r'<([A-Za-z][\w:.-]*)([^<>]*?)(/?)>');
final RegExp _styleBlockRegex = RegExp(r'<style\b[^>]*>.*?</style>', dotAll: true);

class _Rewritten {
  final String text;
  final int width, height, unfilledShapes;
  final bool groupFill, rootFill;
  _Rewritten(this.text, this.width, this.height, this.unfilledShapes, this.groupFill,
      this.rootFill);
}

String _trimChars(String s, String chars) {
  var a = 0, b = s.length;
  while (a < b && chars.contains(s[a])) {
    a++;
  }
  while (b > a && chars.contains(s[b - 1])) {
    b--;
  }
  return s.substring(a, b);
}

/// One full rewrite pass. [color] decides what each colour literal becomes.
/// [blackFill] (pass 2 only): a default root fill so shapes without any fill become themable.
_Rewritten _rewrite(String source, String Function(Rgb) color, {String? blackFill}) {
  var s = source;
  void strip(RegExp re) => s = s.replaceAll(re, '');
  strip(RegExp(r'<\?xml[^>]*\?>'));
  strip(RegExp(r'<!DOCTYPE[^>\[]*(\[.*?\])?\s*>', dotAll: true));
  strip(RegExp(r'<!--.*?-->', dotAll: true));
  strip(RegExp(r'<script\b.*?</script>', dotAll: true));
  strip(RegExp(r'<metadata\b.*?</metadata>', dotAll: true));

  // <style> blocks are protected from the tag pass, then recoloured separately.
  final styleBlocks = <String>[];
  final tmp = StringBuffer();
  var last = 0;
  for (final m in _styleBlockRegex.allMatches(s)) {
    tmp.write(s.substring(last, m.start));
    tmp.write('\u0001S${styleBlocks.length}\u0001');
    styleBlocks.add(_mapDeclarations(m.group(0)!, color));
    last = m.end;
  }
  tmp.write(s.substring(last));
  s = tmp.toString();

  final out = StringBuffer();
  last = 0;
  var seenRoot = false;
  var width = 0, height = 0;
  var unfilled = 0;
  var groupFill = false;
  var rootFill = false;

  for (final m in _tagRegex.allMatches(s)) {
    out.write(s.substring(last, m.start));
    last = m.end;

    final name = m.group(1)!;
    final attrText = m.group(2)!;
    final selfClose = m.group(3)!;
    final lname = name.toLowerCase();

    final attrs = <(String, String)>[];
    for (final a in _attrRegex.allMatches(attrText)) {
      attrs.add((a.group(1)!, a.group(2) ?? a.group(3) ?? ''));
    }

    final hadFill = attrs.any((a) => a.$1 == 'fill');
    final hadClass = attrs.any((a) => a.$1 == 'class');
    String? styleValue;
    for (final a in attrs) {
      if (a.$1 == 'style') {
        styleValue = a.$2;
        break;
      }
    }
    final styleHasFill = styleValue?.contains('fill') ?? false;
    if (lname == 'g' && (hadFill || styleHasFill)) groupFill = true;
    if (_shapeTags.contains(lname) && !hadFill && !styleHasFill && !hadClass) unfilled++;

    // presentation attributes -> style declarations
    final moved = <String>[];
    final kept = <(String, String)>[];
    for (final (k, v) in attrs) {
      final rgb = _colorProps.contains(k) ? parseCssColor(v) : null;
      if (rgb != null) {
        moved.add('$k:${color(rgb)}');
      } else if (k == 'style') {
        styleValue = _mapDeclarations(v, color);
      } else {
        kept.add((k, v));
      }
    }

    if (lname == 'svg' && !seenRoot) {
      seenRoot = true;
      rootFill = hadFill || styleHasFill;
      var minX = '0', minY = '0';
      String? attr(String key) {
        for (final a in kept) {
          if (a.$1 == key) return a.$2;
        }
        return null;
      }

      final vb = attr('viewBox');
      if (vb != null) {
        final n = vb
            .split(RegExp(r'[ ,]+'))
            .where((e) => e.isNotEmpty)
            .map(double.tryParse)
            .whereType<double>()
            .toList();
        if (n.length == 4 && n[2] > 0 && n[3] > 0) {
          minX = n[0].toString();
          minY = n[1].toString();
          width = n[2].round();
          height = n[3].round();
        }
      }
      if (width == 0) {
        int? numAttr(String key) {
          final v = attr(key);
          if (v == null) return null;
          final r = RegExp(r'^\s*\d+(\.\d+)?').firstMatch(v);
          if (r == null) return null;
          return double.tryParse(r.group(0)!.trim())?.round();
        }

        width = numAttr('width') ?? 100;
        height = numAttr('height') ?? width;
      }
      width = width < 1 ? 1 : width;
      height = height < 1 ? 1 : height;
      kept.removeWhere((a) => const ['width', 'height', 'viewBox', 'x', 'y'].contains(a.$1));
      kept.add(('viewBox', '$minX $minY $width $height'));
      kept.add(('width', '$width'));
      kept.add(('height', '$height'));
      kept.add(('data-input', 'svg'));
      if (!kept.any((a) => a.$1 == 'xmlns')) {
        kept.insert(0, ('xmlns', 'http://www.w3.org/2000/svg'));
      }
      if (source.contains('xlink:') && !kept.any((a) => a.$1 == 'xmlns:xlink')) {
        kept.add(('xmlns:xlink', 'http://www.w3.org/1999/xlink'));
      }
      if (blackFill != null && !rootFill) moved.add('fill:$blackFill');
    }

    var style = styleValue == null ? '' : _trimChars(styleValue, '; ');
    if (moved.isNotEmpty) style += (style.isEmpty ? '' : ';') + moved.join(';');
    if (style.isNotEmpty) kept.add(('style', style));

    final tag = StringBuffer('<$name');
    for (final (k, v) in kept) {
      tag.write(' $k="${v.replaceAll('"', '&quot;')}"');
    }
    out.write('$tag$selfClose>');
  }
  out.write(s.substring(last));

  var text = out.toString();
  for (var i = 0; i < styleBlocks.length; i++) {
    text = text.replaceAll('\u0001S$i\u0001', styleBlocks[i]);
  }
  return _Rewritten(text, width, height, unfilled, groupFill, rootFill);
}

ImportedSvg themifyExisting(String source, int k) {
  if (!RegExp('<svg', caseSensitive: false).hasMatch(source)) {
    throw SvgPaletteException('unexpected SVG: not an SVG file');
  }

  // Pass 1: collect colours.
  final counts = <Rgb, int>{};
  final first = _rewrite(source, (c) {
    counts[c] = (counts[c] ?? 0) + 1;
    return c.hex;
  });
  const black = Rgb(0, 0, 0);
  final needsBlack = first.unfilledShapes > 0 && !first.groupFill && !first.rootFill;
  if (needsBlack) counts[black] = (counts[black] ?? 0) + first.unfilledShapes;
  if (counts.isEmpty) {
    throw SvgPaletteException('unexpected SVG: no fill/stroke colors found to theme');
  }

  final q = quantizeColors(
      [for (final e in counts.entries) (color: e.key, weight: e.value)], k);

  // Pass 2: rewrite every colour literal to var(--cN, original).
  String varFor(Rgb c) => 'var(--c${(q.slot[c] ?? 0) + 1},${c.hex})';
  final second = _rewrite(source, varFor, blackFill: needsBlack ? varFor(black) : null);
  final slotMap = {for (final e in q.slot.entries) e.key.hex: e.value};
  return ImportedSvg(second.text, second.width, second.height, q.palette, slotMap);
}
