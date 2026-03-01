import 'dart:io';
import 'package:flutter/services.dart';

/// Normalised (0-1) bounding box per video frame.
class TrackedFrame {
  final int frameIndex;
  final double x, y, w, h;   // top-left origin, normalised to video dims

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

  /// Returns true only on macOS — other platforms have no implementation.
  static bool get isAvailable => Platform.isMacOS;

  /// Track a region across all frames of [videoPath].
  ///
  /// [x], [y], [w], [h] are normalised (0-1) relative to the video frame,
  /// top-left origin — matching the same coordinate space used by [BlurRegion].
  ///
  /// Returns one [TrackedFrame] per video frame that Vision successfully tracked.
  /// Throws if the platform channel call fails.
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