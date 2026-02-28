import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../models/lut_item.dart';
import '../data/lut_list.dart';

class LutManager {
  static final LutManager _instance = LutManager._internal();
  factory LutManager() => _instance;
  LutManager._internal();

  final Map<String, List<List<List<List<double>>>>> _lutCache = {};

  List<LutItem> get availableLuts => lutList
      .map((e) => LutItem(name: e['name']!, path: e['path']!))
      .toList();

  Future<List<List<List<List<double>>>>> loadLut(String assetPath) async {
    if (_lutCache.containsKey(assetPath)) {
      return _lutCache[assetPath]!;
    }

    final String content = await rootBundle.loadString(assetPath);
    final lines = content.split('\n');

    int size = 33;
    final List<List<double>> rgbValues = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') || trimmed.isEmpty) continue;
      if (trimmed.startsWith('LUT_3D_SIZE')) {
        size = int.parse(trimmed.split(RegExp(r'\s+')).last);
        continue;
      }
      if (trimmed.startsWith('TITLE') ||
          trimmed.startsWith('DOMAIN_MIN') ||
          trimmed.startsWith('DOMAIN_MAX')) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length == 3) {
        final r = double.tryParse(parts[0]);
        final g = double.tryParse(parts[1]);
        final b = double.tryParse(parts[2]);
        if (r != null && g != null && b != null) {
          rgbValues.add([r, g, b]);
        }
      }
    }

    // Build 3D table [r][g][b] -> [r, g, b]
    final lut = List.generate(
      size,
      (r) => List.generate(
        size,
        (g) => List.generate(
          size,
          (b) {
            final idx = r + g * size + b * size * size;
            if (idx < rgbValues.length) return rgbValues[idx];
            return [0.0, 0.0, 0.0];
          },
        ),
      ),
    );

    _lutCache[assetPath] = lut;
    return lut;
  }

  /// Apply a loaded LUT to raw RGBA pixel bytes (Uint8List).
  Uint8List applyLutToPixels(
      Uint8List pixels, List<List<List<List<double>>>> lut) {
    final size = lut.length;
    final maxIndex = size - 1;
    final result = Uint8List(pixels.length);

    for (int i = 0; i < pixels.length; i += 4) {
      final r = pixels[i] / 255.0;
      final g = pixels[i + 1] / 255.0;
      final b = pixels[i + 2] / 255.0;

      final ri = (r * maxIndex).clamp(0, maxIndex).toInt();
      final gi = (g * maxIndex).clamp(0, maxIndex).toInt();
      final bi = (b * maxIndex).clamp(0, maxIndex).toInt();

      final mapped = lut[ri][gi][bi];
      result[i] = (mapped[0] * 255).round().clamp(0, 255);
      result[i + 1] = (mapped[1] * 255).round().clamp(0, 255);
      result[i + 2] = (mapped[2] * 255).round().clamp(0, 255);
      result[i + 3] = pixels[i + 3];
    }

    return result;
  }

  void clearCache() => _lutCache.clear();
}