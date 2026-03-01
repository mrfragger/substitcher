import 'dart:io';
import 'package:flutter/services.dart';

class TrackedFrame {
  final int frameIndex;
  final double x, y, w, h;

  const TrackedFrame({
    required this.frameIndex,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}

class VisionTrackingService {
  static const _channel = MethodChannel('com.substitcher/vision_tracker');

  static bool get isAvailable => Platform.isMacOS;

  static Future<List<TrackedFrame>> trackRegion({
    required String videoPath,
    required double x,
    required double y,
    required double w,
    required double h,
  }) async {
    if (!isAvailable) {
      throw UnsupportedError(
          'VisionTrackingService is only available on macOS');
    }

    final raw = await _channel.invokeMethod<List>('trackRegion', {
      'videoPath': videoPath,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
    });

    if (raw == null) return [];

    return raw.map((entry) {
      final row = (entry as List).cast<double>();
      return TrackedFrame(
        frameIndex: row[0].round(),
        x: row[1],
        y: row[2],
        w: row[3],
        h: row[4],
      );
    }).toList();
  }
}