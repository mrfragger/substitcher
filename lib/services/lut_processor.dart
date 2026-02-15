import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

class LutProcessor {
  static Future<List<List<List<List<int>>>>> parseCubeLut(String lutPath, {bool isAsset = false}) async {
    List<String> lines;
    
    if (isAsset) {
      final data = await rootBundle.loadString(lutPath);
      lines = data.split('\n');
    } else {
      final file = File(lutPath);
      if (!await file.exists()) {
        throw Exception('LUT file not found: $lutPath');
      }
      lines = await file.readAsLines();
    }
        
    int size = 0;
    final List<double> values = [];
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      // Skip comments and empty lines
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      // Get LUT size
      if (trimmed.startsWith('LUT_3D_SIZE')) {
        size = int.parse(trimmed.split(' ')[1]);
        continue;
      }
      
      // Parse RGB values
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length == 3) {
        try {
          values.add(double.parse(parts[0]));
          values.add(double.parse(parts[1]));
          values.add(double.parse(parts[2]));
        } catch (e) {
          continue;
        }
      }
    }
    
    // Build 3D LUT structure: [r][g][b] = [R, G, B]
    final lut = List.generate(
      size,
      (r) => List.generate(
        size,
        (g) => List.generate(
          size,
          (b) {
            final index = (r * size * size + g * size + b) * 3;
            if (index + 2 < values.length) {
              return [
                (values[index] * 255).round(),
                (values[index + 1] * 255).round(),
                (values[index + 2] * 255).round(),
              ];
            }
            return [0, 0, 0];
          },
        ),
      ),
    );
    
    return lut;
  }
  
  static img.Color lookupLut(img.Color color, List<List<List<List<int>>>> lut) {
    final size = lut.length;
    
    // Normalize RGB to LUT coordinates
    final r = (color.r / 255.0 * (size - 1)).clamp(0.0, size - 1.0);
    final g = (color.g / 255.0 * (size - 1)).clamp(0.0, size - 1.0);
    final b = (color.b / 255.0 * (size - 1)).clamp(0.0, size - 1.0);
    
    // Get indices for trilinear interpolation
    final r0 = r.floor().clamp(0, size - 1);
    final g0 = g.floor().clamp(0, size - 1);
    final b0 = b.floor().clamp(0, size - 1);
    final r1 = (r0 + 1).clamp(0, size - 1);
    final g1 = (g0 + 1).clamp(0, size - 1);
    final b1 = (b0 + 1).clamp(0, size - 1);
    
    // Interpolation weights
    final rFrac = r - r0;
    final gFrac = g - g0;
    final bFrac = b - b0;
    
    // Get the 8 corner RGB values
    final c000 = lut[r0][g0][b0];
    final c001 = lut[r0][g0][b1];
    final c010 = lut[r0][g1][b0];
    final c011 = lut[r0][g1][b1];
    final c100 = lut[r1][g0][b0];
    final c101 = lut[r1][g0][b1];
    final c110 = lut[r1][g1][b0];
    final c111 = lut[r1][g1][b1];
    
    // Trilinear interpolation for each channel
    int interpolate(int channelIndex) {
      final c00 = c000[channelIndex] * (1 - rFrac) + c100[channelIndex] * rFrac;
      final c01 = c001[channelIndex] * (1 - rFrac) + c101[channelIndex] * rFrac;
      final c10 = c010[channelIndex] * (1 - rFrac) + c110[channelIndex] * rFrac;
      final c11 = c011[channelIndex] * (1 - rFrac) + c111[channelIndex] * rFrac;
      
      final c0 = c00 * (1 - gFrac) + c10 * gFrac;
      final c1 = c01 * (1 - gFrac) + c11 * gFrac;
      
      return (c0 * (1 - bFrac) + c1 * bFrac).round().clamp(0, 255);
    }
    
    return img.ColorRgb8(
      interpolate(0),
      interpolate(1),
      interpolate(2),
    );
  }
  
  static Future<List<List<List<List<int>>>>> parseCubeLutFromString(String lutContent) async {
    final lines = lutContent.split('\n');
    int size = 0;
    final List<double> values = [];
    
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      
      if (trimmed.startsWith('LUT_3D_SIZE')) {
        size = int.parse(trimmed.split(' ')[1]);
        continue;
      }
      
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length == 3) {
        try {
          values.add(double.parse(parts[0]));
          values.add(double.parse(parts[1]));
          values.add(double.parse(parts[2]));
        } catch (e) {
          continue;
        }
      }
    }
    
    final lut = List.generate(
      size,
      (r) => List.generate(
        size,
        (g) => List.generate(
          size,
          (b) {
            final index = (r * size * size + g * size + b) * 3;
            if (index + 2 < values.length) {
              return [
                (values[index] * 255).round(),
                (values[index + 1] * 255).round(),
                (values[index + 2] * 255).round(),
              ];
            }
            return [0, 0, 0];
          },
        ),
      ),
    );
    
    return lut;
  }

  static Future<img.Image> applyLutToImage(img.Image image, String lutPath, bool isAsset) async {
    final lutData = await parseCubeLut(lutPath, isAsset: isAsset);
    final result = image.clone();
    
    for (int y = 0; y < result.height; y++) {
      for (int x = 0; x < result.width; x++) {
        final pixel = result.getPixel(x, y);
        final newPixel = lookupLut(pixel, lutData);
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }

  static Future<img.Image> createBlackBackground(int width, int height) async {
    return img.Image(width: width, height: height)
      ..clear(img.ColorRgb8(0, 0, 0));
  }

  static img.Image drawText(
    img.Image image,
    String text,
    int x,
    int y,
    img.Color color,
    {int fontSize = 48}
  ) {
    // Use built-in arial font
    img.drawString(
      image,
      text,
      font: img.arial48,
      x: x,
      y: y,
      color: color,
    );
    return image;
  }
}