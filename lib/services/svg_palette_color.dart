// lib/services/svg_palette_color.dart
//
// Colour quantizing for the SVG palette tool (port of Quantize.swift).
// Pure Dart on typed lists, so it can run inside Isolate.run.
import 'dart:math' as math;
import 'dart:typed_data';

class Rgb {
  final int r, g, b;
  const Rgb(this.r, this.g, this.b);

  String get hex => '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is Rgb && other.r == r && other.g == g && other.b == b;

  @override
  int get hashCode => (r << 16) | (g << 8) | b;
}

class Quantized {
  /// Sorted dark -> light, so slot 1 is always the darkest.
  final List<Rgb> palette;

  /// Per pixel; 255 = transparent.
  final Uint8List indices;
  Quantized(this.palette, this.indices);
}

final List<double> _srgbToLinear = List<double>.generate(256, (i) {
  final c = i / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}, growable: false);

double _f(double t) =>
    t > 0.008856 ? math.pow(t, 1.0 / 3.0).toDouble() : 7.787 * t + 16.0 / 116.0;

/// sRGB -> CIE Lab, written into [out] at [o], [o+1], [o+2].
void _rgbToLab(int r, int g, int b, Float64List out, int o) {
  final R = _srgbToLinear[r], G = _srgbToLinear[g], B = _srgbToLinear[b];
  final x = (0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047;
  final y = 0.2126729 * R + 0.7151522 * G + 0.0721750 * B;
  final z = (0.0193339 * R + 0.1191920 * G + 0.9503041 * B) / 1.08883;
  final fx = _f(x), fy = _f(y), fz = _f(z);
  out[o] = 116 * fy - 16;
  out[o + 1] = 500 * (fx - fy);
  out[o + 2] = 200 * (fy - fz);
}

double _lightness(Rgb c) {
  final t = Float64List(3);
  _rgbToLab(c.r, c.g, c.b, t, 0);
  return t[0];
}

double _dist2(double l1, double a1, double b1, double l2, double a2, double b2) {
  final dl = l1 - l2, da = a1 - a2, db = b1 - b2;
  return dl * dl + da * da + db * db;
}

/// Index of the centre nearest to (l, a, b). Centres are packed [l, a, b, l, a, b, ...].
int _nearest(double l, double a, double b, Float64List centers, int count) {
  var best = 0;
  var bd = double.infinity;
  for (var j = 0; j < count; j++) {
    final d = _dist2(l, a, b, centers[j * 3], centers[j * 3 + 1], centers[j * 3 + 2]);
    if (d < bd) {
      bd = d;
      best = j;
    }
  }
  return best;
}

class _SplitMix {
  int state;
  _SplitMix(this.state);

  int next() {
    state += 0x9E3779B97F4A7C15; // wraps in 64 bits on the Dart VM
    var z = state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    return z ^ (z >>> 31);
  }

  /// next() % n, treating next() as unsigned.
  int nextBelow(int n) =>
      (BigInt.from(next()).toUnsigned(64) % BigInt.from(n)).toInt();

  double unit() => (next() >>> 40) / 16777216.0;
}

/// k-means (k-means++ init) in CIE Lab. Deterministic for a given image.
/// [px] is straight RGBA8, top row first. Returns null when nothing is opaque.
Quantized? quantize(Uint8List px, int w, int h, int k) {
  final n = w * h;
  final labs = Float64List(n * 3);
  final opaque = <int>[];
  for (var i = 0; i < n; i++) {
    if (px[i * 4 + 3] >= 128) {
      _rgbToLab(px[i * 4], px[i * 4 + 1], px[i * 4 + 2], labs, i * 3);
      opaque.add(i);
    }
  }
  if (opaque.isEmpty) return null;

  final step = math.max(1, opaque.length ~/ 20000);
  final samples = <int>[]; // pixel indices
  for (var s = 0; s < opaque.length; s += step) {
    samples.add(opaque[s]);
  }

  final rng = _SplitMix(42);
  final centers = Float64List(k * 3);
  var count = 0;
  void addCenter(int pix) {
    centers[count * 3] = labs[pix * 3];
    centers[count * 3 + 1] = labs[pix * 3 + 1];
    centers[count * 3 + 2] = labs[pix * 3 + 2];
    count++;
  }

  addCenter(samples[rng.nextBelow(samples.length)]);
  final d2 = Float64List(samples.length);
  while (count < k) {
    var total = 0.0;
    for (var s = 0; s < samples.length; s++) {
      final p = samples[s];
      var best = double.infinity;
      for (var j = 0; j < count; j++) {
        final d = _dist2(labs[p * 3], labs[p * 3 + 1], labs[p * 3 + 2],
            centers[j * 3], centers[j * 3 + 1], centers[j * 3 + 2]);
        if (d < best) best = d;
      }
      d2[s] = best;
      total += best;
    }
    if (total <= 0) break;
    var r = rng.unit() * total;
    var pick = samples.length - 1;
    for (var s = 0; s < samples.length; s++) {
      r -= d2[s];
      if (r <= 0) {
        pick = s;
        break;
      }
    }
    addCenter(samples[pick]);
  }

  for (var iter = 0; iter < 12; iter++) {
    final sum = Float64List(count * 3);
    final cnt = List<int>.filled(count, 0);
    for (final p in samples) {
      final j = _nearest(labs[p * 3], labs[p * 3 + 1], labs[p * 3 + 2], centers, count);
      sum[j * 3] += labs[p * 3];
      sum[j * 3 + 1] += labs[p * 3 + 1];
      sum[j * 3 + 2] += labs[p * 3 + 2];
      cnt[j]++;
    }
    for (var j = 0; j < count; j++) {
      if (cnt[j] > 0) {
        centers[j * 3] = sum[j * 3] / cnt[j];
        centers[j * 3 + 1] = sum[j * 3 + 1] / cnt[j];
        centers[j * 3 + 2] = sum[j * 3 + 2] / cnt[j];
      }
    }
  }

  // Assign every pixel; the palette colour is the mean sRGB of its members.
  final raw = Uint8List(n)..fillRange(0, n, 255);
  final sumR = List<int>.filled(count, 0);
  final sumG = List<int>.filled(count, 0);
  final sumB = List<int>.filled(count, 0);
  final members = List<int>.filled(count, 0);
  for (final i in opaque) {
    final j = _nearest(labs[i * 3], labs[i * 3 + 1], labs[i * 3 + 2], centers, count);
    raw[i] = j;
    sumR[j] += px[i * 4];
    sumG[j] += px[i * 4 + 1];
    sumB[j] += px[i * 4 + 2];
    members[j]++;
  }

  // Drop empty clusters, sort dark -> light by centre lightness.
  final live = <int>[for (var j = 0; j < count; j++) if (members[j] > 0) j]
    ..sort((a, b) => centers[a * 3].compareTo(centers[b * 3]));
  final remap = Uint8List(count)..fillRange(0, count, 255);
  final palette = <Rgb>[];
  for (var newIdx = 0; newIdx < live.length; newIdx++) {
    final old = live[newIdx];
    remap[old] = newIdx;
    palette.add(Rgb(sumR[old] ~/ members[old], sumG[old] ~/ members[old],
        sumB[old] ~/ members[old]));
  }
  for (final i in opaque) {
    raw[i] = remap[raw[i]];
  }
  return Quantized(palette, raw);
}

/// Flat-colour bitmap: every opaque pixel snapped to its palette colour, binary alpha.
Uint8List flatten(Uint8List px, int w, int h, Quantized q) {
  final out = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final idx = q.indices[i];
    if (idx == 255) continue; // already 0,0,0,0
    final c = q.palette[idx];
    out[i * 4] = c.r;
    out[i * 4 + 1] = c.g;
    out[i * 4 + 2] = c.b;
    out[i * 4 + 3] = 255;
  }
  return out;
}

/// Smoothed image with binary alpha (watershed mode: vtracer sees the real colours).
Uint8List binarizeAlpha(Uint8List px, int w, int h) {
  final out = Uint8List.fromList(px);
  for (var i = 0; i < w * h; i++) {
    if (px[i * 4 + 3] >= 128) {
      out[i * 4 + 3] = 255;
    } else {
      out[i * 4] = 0;
      out[i * 4 + 1] = 0;
      out[i * 4 + 2] = 0;
      out[i * 4 + 3] = 0;
    }
  }
  return out;
}

/// Weighted k-means over a small set of distinct colours (used for SVG input).
/// Fewer distinct colours than [k] keeps every colour exactly. Slots are sorted dark -> light.
({List<Rgb> palette, Map<Rgb, int> slot}) quantizeColors(
    List<({Rgb color, int weight})> items, int k) {
  final lightness = <Rgb, double>{for (final it in items) it.color: _lightness(it.color)};
  final sorted = [...items]..sort((a, b) {
      final c = lightness[a.color]!.compareTo(lightness[b.color]!);
      return c != 0 ? c : a.color.hex.compareTo(b.color.hex);
    });
  final slot = <Rgb, int>{};
  if (sorted.length <= k) {
    for (var i = 0; i < sorted.length; i++) {
      slot[sorted[i].color] = i;
    }
    return (palette: [for (final s in sorted) s.color], slot: slot);
  }

  final m = sorted.length;
  final pts = Float64List(m * 3);
  for (var i = 0; i < m; i++) {
    final c = sorted[i].color;
    _rgbToLab(c.r, c.g, c.b, pts, i * 3);
  }
  final w = [for (final s in sorted) math.max(s.weight, 1).toDouble()];

  final rng = _SplitMix(7);
  final centers = Float64List(k * 3);
  var count = 0;
  void addCenter(int i) {
    centers[count * 3] = pts[i * 3];
    centers[count * 3 + 1] = pts[i * 3 + 1];
    centers[count * 3 + 2] = pts[i * 3 + 2];
    count++;
  }

  addCenter(0);
  final d2 = Float64List(m);
  while (count < k) {
    var total = 0.0;
    for (var i = 0; i < m; i++) {
      var best = double.infinity;
      for (var j = 0; j < count; j++) {
        final d = _dist2(pts[i * 3], pts[i * 3 + 1], pts[i * 3 + 2],
            centers[j * 3], centers[j * 3 + 1], centers[j * 3 + 2]);
        if (d < best) best = d;
      }
      d2[i] = w[i] * best;
      total += d2[i];
    }
    if (total <= 0) break;
    var r = rng.unit() * total;
    var pick = m - 1;
    for (var i = 0; i < m; i++) {
      r -= d2[i];
      if (r <= 0) {
        pick = i;
        break;
      }
    }
    addCenter(pick);
  }
  for (var iter = 0; iter < 20; iter++) {
    final sum = Float64List(count * 3);
    final tot = List<double>.filled(count, 0);
    for (var i = 0; i < m; i++) {
      final j = _nearest(pts[i * 3], pts[i * 3 + 1], pts[i * 3 + 2], centers, count);
      sum[j * 3] += pts[i * 3] * w[i];
      sum[j * 3 + 1] += pts[i * 3 + 1] * w[i];
      sum[j * 3 + 2] += pts[i * 3 + 2] * w[i];
      tot[j] += w[i];
    }
    for (var j = 0; j < count; j++) {
      if (tot[j] > 0) {
        centers[j * 3] = sum[j * 3] / tot[j];
        centers[j * 3 + 1] = sum[j * 3 + 1] / tot[j];
        centers[j * 3 + 2] = sum[j * 3 + 2] / tot[j];
      }
    }
  }

  final sumR = List<double>.filled(count, 0);
  final sumG = List<double>.filled(count, 0);
  final sumB = List<double>.filled(count, 0);
  final tot = List<double>.filled(count, 0);
  final assign = List<int>.filled(m, 0);
  for (var i = 0; i < m; i++) {
    final j = _nearest(pts[i * 3], pts[i * 3 + 1], pts[i * 3 + 2], centers, count);
    assign[i] = j;
    final c = sorted[i].color;
    sumR[j] += c.r * w[i];
    sumG[j] += c.g * w[i];
    sumB[j] += c.b * w[i];
    tot[j] += w[i];
  }
  final live = <int>[for (var j = 0; j < count; j++) if (tot[j] > 0) j]
    ..sort((a, b) => centers[a * 3].compareTo(centers[b * 3]));
  final remap = <int, int>{};
  final palette = <Rgb>[];
  for (var n = 0; n < live.length; n++) {
    final old = live[n];
    remap[old] = n;
    palette.add(Rgb((sumR[old] / tot[old]).round(), (sumG[old] / tot[old]).round(),
        (sumB[old] / tot[old]).round()));
  }
  for (var i = 0; i < m; i++) {
    slot[sorted[i].color] = remap[assign[i]] ?? 0;
  }
  return (palette: palette, slot: slot);
}
