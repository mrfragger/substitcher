import 'dart:typed_data';

class LigatureReader {
  /// codePoint of ligature glyph -> "re" (or "ri / rï" if several sequences)
  static Map<int, String> read(Uint8List bytes) {
    try {
      return _read(bytes);
    } catch (_) {
      return {};
    }
  }

  static Map<int, String> _read(Uint8List bytes) {
    final d = ByteData.sublistView(bytes);
    int base = 0;
    if (d.getUint32(0) == 0x74746366) base = d.getUint32(12); // .ttc: first font
    final numTables = d.getUint16(base + 4);
    final tables = <String, int>{};
    for (var i = 0; i < numTables; i++) {
      final rec = base + 12 + i * 16;
      tables[String.fromCharCodes(bytes.sublist(rec, rec + 4))] =
          d.getUint32(rec + 8);
    }
    final cmapOff = tables['cmap'];
    final gsubOff = tables['GSUB'];
    if (cmapOff == null || gsubOff == null) return {};

    final glyphToCps = _readCmap(d, cmapOff);
    final ligs = _readLigatures(d, gsubOff); // (ligGlyph, components)

    String? charFor(int g) {
      final cps = glyphToCps[g];
      if (cps == null || cps.isEmpty) return null;
      return String.fromCharCode(cps.first);
    }

    final out = <int, String>{};
    for (final (ligGlyph, comps) in ligs) {
      final parts = comps.map(charFor).toList();
      if (parts.contains(null)) continue;
      final label = parts.join();
      for (final cp in glyphToCps[ligGlyph] ?? const <int>[]) {
        final existing = out[cp];
        if (existing == null) {
          out[cp] = label;
        } else if (!existing.split(' / ').contains(label)) {
          out[cp] = '$existing / $label';
        }
      }
    }
    return out;
  }

  // glyph id -> code points (ascending)
  static Map<int, List<int>> _readCmap(ByteData d, int cmap) {
    final n = d.getUint16(cmap + 2);
    int? best;
    int bestRank = -1;
    for (var i = 0; i < n; i++) {
      final r = cmap + 4 + i * 8;
      final plat = d.getUint16(r);
      final enc = d.getUint16(r + 2);
      final off = cmap + d.getUint32(r + 4);
      final fmt = d.getUint16(off);
      int rank = -1;
      if (fmt == 12 && (plat == 3 && enc == 10 || plat == 0)) rank = 3;
      else if (fmt == 4 && plat == 3 && enc == 1) rank = 2;
      else if (fmt == 4 && plat == 0) rank = 1;
      if (rank > bestRank) {
        bestRank = rank;
        best = off;
      }
    }
    final result = <int, List<int>>{};
    if (best == null) return result;
    void add(int g, int c) {
      if (g != 0) (result[g] ??= []).add(c);
    }

    final o = best;
    if (d.getUint16(o) == 12) {
      final groups = d.getUint32(o + 12);
      for (var i = 0; i < groups; i++) {
        final p = o + 16 + i * 12;
        final s = d.getUint32(p), e = d.getUint32(p + 4), g = d.getUint32(p + 8);
        for (var c = s; c <= e; c++) {
          add(g + (c - s), c);
        }
      }
    } else {
      final segCount = d.getUint16(o + 6) ~/ 2;
      final endB = o + 14;
      final startB = endB + segCount * 2 + 2;
      final deltaB = startB + segCount * 2;
      final rangeB = deltaB + segCount * 2;
      for (var s = 0; s < segCount; s++) {
        final end = d.getUint16(endB + s * 2);
        final start = d.getUint16(startB + s * 2);
        final delta = d.getUint16(deltaB + s * 2);
        final ro = d.getUint16(rangeB + s * 2);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          int g;
          if (ro == 0) {
            g = (c + delta) & 0xFFFF;
          } else {
            g = d.getUint16(rangeB + s * 2 + ro + (c - start) * 2);
            if (g != 0) g = (g + delta) & 0xFFFF;
          }
          add(g, c);
        }
      }
    }
    return result;
  }

  static List<(int, List<int>)> _readLigatures(ByteData d, int gsub) {
    final result = <(int, List<int>)>[];
    final lookupList = gsub + d.getUint16(gsub + 8);
    final lookupCount = d.getUint16(lookupList);
    for (var i = 0; i < lookupCount; i++) {
      final lookup = lookupList + d.getUint16(lookupList + 2 + i * 2);
      final type = d.getUint16(lookup);
      final subCount = d.getUint16(lookup + 4);
      for (var s = 0; s < subCount; s++) {
        var sub = lookup + d.getUint16(lookup + 6 + s * 2);
        var t = type;
        if (t == 7) {
          t = d.getUint16(sub + 2);
          sub = sub + d.getUint32(sub + 4);
        }
        if (t != 4) continue;
        final coverage = _readCoverage(d, sub + d.getUint16(sub + 2));
        final setCount = d.getUint16(sub + 4);
        for (var k = 0; k < setCount && k < coverage.length; k++) {
          final set = sub + d.getUint16(sub + 6 + k * 2);
          final ligCount = d.getUint16(set);
          for (var l = 0; l < ligCount; l++) {
            final lig = set + d.getUint16(set + 2 + l * 2);
            final ligGlyph = d.getUint16(lig);
            final compCount = d.getUint16(lig + 2);
            final comps = <int>[coverage[k]];
            for (var c = 0; c < compCount - 1; c++) {
              comps.add(d.getUint16(lig + 4 + c * 2));
            }
            result.add((ligGlyph, comps));
          }
        }
      }
    }
    return result;
  }

  static List<int> _readCoverage(ByteData d, int o) {
    final fmt = d.getUint16(o);
    final count = d.getUint16(o + 2);
    final glyphs = <int>[];
    if (fmt == 1) {
      for (var i = 0; i < count; i++) {
        glyphs.add(d.getUint16(o + 4 + i * 2));
      }
    } else {
      for (var i = 0; i < count; i++) {
        final r = o + 4 + i * 6;
        final s = d.getUint16(r), e = d.getUint16(r + 2);
        for (var g = s; g <= e; g++) {
          glyphs.add(g);
        }
      }
    }
    return glyphs;
  }
}
