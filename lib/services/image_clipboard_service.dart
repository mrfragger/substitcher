import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:avif_native/avif_native.dart';
import 'package:image/image.dart' as img;
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

enum ExportFormat {
  avif('AVIF', 'avif'),
  jpg('JPG', 'jpg'),
  png('PNG', 'png');

  final String label;
  final String ext;
  const ExportFormat(this.label, this.ext);
}

const _imageExts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.avif'};
const _videoExts = {'.mkv', '.mp4', '.webm', '.avi', '.mov', '.m4v'};

/// Top-level so the isolate closure doesn't capture any State/ui objects.
Future<Uint8List> _encodeInIsolate(
    TransferableTypedData ttd, int w, int h, ExportFormat format, int threads) {
  return Isolate.run<Uint8List>(() {
    final rgba = ttd.materialize().asUint8List();
    if (format == ExportFormat.avif) {
      return encodeAvifFrames(
        width: w,
        height: h,
        frames: [
          AvifEncodeFrame(rgba: rgba, duration: const Duration(milliseconds: 100))
        ],
        options: AvifEncodeOptions(
          speed: 8,
          minQuantizer: 32,
          maxQuantizer: 32,
          maxThreads: threads,
        ),
      );
    }
    final im = img.Image.fromBytes(
        width: w, height: h, bytes: rgba.buffer, numChannels: 4);
    return Uint8List.fromList(img.encodeJpg(im, quality: 85));
  });
}

class ImageClipboardService {
  static const _prefKey = 'clipboardImageFormat';

  static Directory get _tempRoot =>
      Directory(p.join(Directory.systemTemp.path, 'substitcher_clipboard'));

  /// True if [path] lives in the folder where pasted images are stored.
  static bool isPastedPath(String path) => p.isWithin(_tempRoot.path, path);

  // ─────────── default format for "Copy to clipboard" ───────────

  static Future<ExportFormat> getDefaultFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefKey);
    return ExportFormat.values.firstWhere((f) => f.name == name,
        orElse: () => ExportFormat.png);
  }

  static Future<void> setDefaultFormat(ExportFormat f) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, f.name);
  }

  // ─────────── paste ───────────

  /// Returns a file path for whatever image/video is on the clipboard,
  /// or null if there is nothing usable. Raw image data is saved to a temp file.
  static Future<String?> pathFromClipboard() async {
    // 1) Files copied in Finder / Explorer / file manager
    try {
      final files = await Pasteboard.files();
      for (final f in files) {
        final ext = p.extension(f).toLowerCase();
        if (_imageExts.contains(ext) || _videoExts.contains(ext)) return f;
      }
    } catch (_) {}

    // 2) Raw image data (screenshots, "Copy image" from a browser, ...)
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;

    final isJpeg = bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    final ext = isJpeg ? 'jpg' : 'png';
    await _tempRoot.create(recursive: true);
    final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final out = p.join(_tempRoot.path, 'pasted-$ts.$ext');
    await File(out).writeAsBytes(bytes);
    return out;
  }

  // ─────────── decode / encode ───────────

  static Future<ui.Image> decodeFile(String path) async {
    final bytes = await File(path).readAsBytes();
    if (p.extension(path).toLowerCase() == '.avif') {
      final d = decodeAvif(bytes);
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(d.frames.first.rgba, d.width, d.height,
          ui.PixelFormat.rgba8888, c.complete);
      return c.future;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  static Future<Uint8List> encode(ui.Image image, ExportFormat format) async {
    if (format == ExportFormat.png) {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    }
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final ttd = TransferableTypedData.fromList([raw!.buffer.asUint8List()]);
    return _encodeInIsolate(ttd, image.width, image.height, format,
        max(1, Platform.numberOfProcessors));
  }

  // ─────────── export / copy ───────────

  static Future<String> saveTo(
      ui.Image image, ExportFormat format, String dir, String baseName) async {
    await Directory(dir).create(recursive: true);
    final out = p.join(dir, '$baseName.${format.ext}');
    await File(out).writeAsBytes(await encode(image, format));
    return out;
  }

  /// Encodes to [format], writes a temp file and puts it on the clipboard
  /// as a file (works for AVIF too). Returns the temp path, or null on failure.
  static Future<String?> copyToClipboard(
      ui.Image image, ExportFormat format) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path =
        await saveTo(image, format, _tempRoot.path, 'clipboard-$ts');
    final ok = await Pasteboard.writeFiles([path]);
    return ok ? path : null;
  }
}
