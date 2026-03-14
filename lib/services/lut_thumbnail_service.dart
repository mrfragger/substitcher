import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class LutThumbnailService {
  static LutThumbnailService? _instance;
  static LutThumbnailService get instance =>
      _instance ??= LutThumbnailService._();
  LutThumbnailService._();

  String? _ffmpegPath;
  String? _cacheDir;

  Future<void> init(String ffmpegPath) async {
    _ffmpegPath = ffmpegPath;
    final tmp = await getTemporaryDirectory();
    _cacheDir = p.join(tmp.path, 'lut_thumbs');
    await Directory(_cacheDir!).create(recursive: true);
    await _enforceCacheLimit();
  }
  
  Future<void> _enforceCacheLimit() async {
    const maxBytes = 200 * 1024 * 1024; // 200MB cap
    final dir = Directory(_cacheDir!);
    if (!dir.existsSync()) return;
  
    final files = dir.listSync().whereType<File>().toList();
    
    int totalSize = 0;
    for (final f in files) {
      totalSize += await f.length();
    }
  
    if (totalSize <= maxBytes) return;
  
    files.sort((a, b) =>
        a.statSync().modified.compareTo(b.statSync().modified));
  
    for (final f in files) {
      if (totalSize <= maxBytes) break;
      final size = await f.length();
      await f.delete().catchError((_) {});
      totalSize -= size;
    }
  }

  Future<String?> extractFrame(String videoPath, Duration position) async {
    if (_ffmpegPath == null || _cacheDir == null) return null;

    final ms = position.inMilliseconds;
    final key = md5.convert(utf8.encode('frame_${videoPath}_$ms')).toString();
    final framePath = p.join(_cacheDir!, '$key.png');

    if (File(framePath).existsSync()) return framePath;

    final secs = position.inMilliseconds / 1000.0;
    final result = await Process.run(_ffmpegPath!, [
      '-ss', secs.toStringAsFixed(3),
      '-i', videoPath,
      '-frames:v', '1',
      '-vf', 'scale=320:-1',
      '-y',
      framePath,
    ]);
    if (result.exitCode != 0) return null;
    return framePath;
  }

  Future<String?> applyLut(
    String framePng,
    String lutAssetPath,
    String cacheKey,
  ) async {
    if (_ffmpegPath == null || _cacheDir == null) return null;

    final outPath = p.join(_cacheDir!, '$cacheKey.png');
    if (File(outPath).existsSync()) return outPath;

    final lutTmp = p.join(_cacheDir!, '${cacheKey}_lut.cube');
    if (!File(lutTmp).existsSync()) {
      final bytes = await rootBundle.load(lutAssetPath);
      await File(lutTmp).writeAsBytes(bytes.buffer.asUint8List());
    }

    final result = await Process.run(_ffmpegPath!, [
      '-i', framePng,
      '-vf', 'lut3d=$lutTmp',
      '-frames:v', '1',
      '-y',
      outPath,
    ]);

    if (result.exitCode != 0) return null;
    return outPath;
  }

  Future<List<(String, String?)>> generatePage({
    required String videoPath,
    required Duration position,
    required List<({String name, String assetPath})> luts,
  }) async {
    final ms = position.inMilliseconds;
    final framePng = await extractFrame(videoPath, position);
    if (framePng == null) {
      return luts.map((l) => (l.name, null as String?)).toList();
    }

    final futures = luts.map((l) async {
      if (l.assetPath.isEmpty) return (l.name, framePng);
      final key = md5
          .convert(utf8.encode('lut_${videoPath}_${ms}_${l.name}'))
          .toString();
      final out = await applyLut(framePng, l.assetPath, key);
      return (l.name, out);
    });

    return Future.wait(futures);
  }

  Future<void> clearCache() async {
    if (_cacheDir != null) {
      final dir = Directory(_cacheDir!);
      if (dir.existsSync()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    }
  }
}