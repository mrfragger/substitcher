// lib/services/avif_gallery_service.dart
//
// Streams AVIF-encoded masonry galleries straight to disk (no ZIP, no memory
// ceiling). Encoding runs in an isolate pool; decoding/resizing stays on the
// main isolate because dart:ui is only reliable there.
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:avif_native/avif_native.dart';
import 'package:path/path.dart' as p;

import 'avif_gallery_html.dart';

const kRasterExts = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif', '.bmp'};
const kGalleryExts = {...kRasterExts, '.svg'};

bool isGalleryImage(String path) =>
    kGalleryExts.contains(p.extension(path).toLowerCase());

class AvifGalleryOptions {
  /// 0-100, higher = better. Mapped to a fixed AV1 quantizer (0-63).
  final int quality;

  /// libaom cpu-used. 0 = slowest/smallest, 10 = fastest.
  final int speed;
  final int fullMaxDim;
  final int thumbMaxDim;
  final String titleOption; // '1' overlay, '2' below
  final int workers;

  const AvifGalleryOptions({
    this.quality = 50,
    this.speed = 8,
    this.fullMaxDim = 1280,
    this.thumbMaxDim = 350,
    this.titleOption = '1',
    int? workers,
  }) : workers = workers ?? 0;

  int get quantizer => (63 * (1 - quality / 100)).round().clamp(0, 63);
}

class GalleryProgress {
  final int done;
  final int total;
  final String label;
  GalleryProgress(this.done, this.total, this.label);
}

class GalleryStats {
  final int images;
  final int galleries;
  final int originalBytes;
  final int convertedBytes;
  final Duration elapsed;
  final String outputDir;
  GalleryStats(this.images, this.galleries, this.originalBytes,
      this.convertedBytes, this.elapsed, this.outputDir);
  int get reductionPercent => originalBytes == 0
      ? 0
      : (((originalBytes - convertedBytes) / originalBytes) * 100).round();
  double get smallerFactor =>
      convertedBytes == 0 ? 0 : originalBytes / convertedBytes;
}

class CancelToken {
  bool cancelled = false;
}

/// Group files into galleries.
/// - Each root folder: images directly in it -> gallery named after the folder;
///   images in immediate subfolders (any depth) -> gallery named after that subfolder.
/// - Loose files -> "gallery".
Future<Map<String, List<File>>> collectGalleries({
  List<String> folders = const [],
  List<String> looseFiles = const [],
}) async {
  final out = <String, List<File>>{};
  void add(String name, File f) => (out[name] ??= []).add(f);

  for (final root in folders) {
    final rootName = p.basename(root);
    await for (final e in Directory(root).list(recursive: true, followLinks: false)) {
      if (e is! File || !isGalleryImage(e.path)) continue;
      final rel = p.split(p.relative(e.path, from: root));
      if (rel.any((s) => s.startsWith('.'))) continue;
      add(rel.length > 1 ? rel.first : rootName, e);
    }
  }
  for (final f in looseFiles) {
    if (isGalleryImage(f)) add('gallery', File(f));
  }
  for (final l in out.values) {
    l.sort((a, b) =>
        p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
  }
  return out;
}

String _sanitizeName(String s) => s
    .replaceAll(RegExp(r'[^a-zA-Z0-9._()-]'), '_')
    .replaceAll(RegExp(r'_{2,}'), '_');

String _sanitizeFile(String name) {
  final s = _sanitizeName(name.replaceFirst(RegExp(r'\.[^.]+$'), ''));
  return s.length > 90 ? s.substring(0, 90) : s;
}

// ───────────────────────── isolate encoder pool ─────────────────────────

class _Job {
  final int id;
  final TransferableTypedData rgba;
  final int w, h, quantizer, speed;
  final String outPath;
  _Job(this.id, this.rgba, this.w, this.h, this.quantizer, this.speed, this.outPath);
}

void _encodeWorker(SendPort main) {
  final rp = ReceivePort();
  main.send(rp.sendPort);
  rp.listen((msg) {
    if (msg == null) {
      rp.close();
      return;
    }
    final job = msg as _Job;
    try {
      final rgba = job.rgba.materialize().asUint8List();
      final bytes = encodeAvifFrames(
        width: job.w,
        height: job.h,
        frames: [AvifEncodeFrame(rgba: rgba, duration: const Duration(milliseconds: 100))],
        options: AvifEncodeOptions(
          speed: job.speed,
          minQuantizer: job.quantizer,
          maxQuantizer: job.quantizer,
          maxThreads: 1, // parallelism comes from the pool
        ),
      );
      File(job.outPath).writeAsBytesSync(bytes, flush: false);
      main.send(<Object?>[job.id, bytes.length, null]);
    } catch (e) {
      main.send(<Object?>[job.id, 0, e.toString()]);
    }
  });
}

class _Pending {
  final _Job job;
  final Completer<int> done = Completer<int>();
  _Pending(this.job);
}

class _EncoderPool {
  final int size;
  _EncoderPool(this.size);

  final _recv = ReceivePort();
  final _isolates = <Isolate>[];
  final _idle = Queue<SendPort>();
  final _queue = Queue<_Pending>();
  final _inFlight = <int, (_Pending, SendPort)>{};
  int _nextId = 0;

  Future<void> start() async {
    final ready = Completer<void>();
    _recv.listen((msg) {
      if (msg is SendPort) {
        _idle.add(msg);
        if (_idle.length == size && !ready.isCompleted) ready.complete();
        _pump();
      } else if (msg is List) {
        final entry = _inFlight.remove(msg[0] as int);
        if (entry == null) return;
        _idle.add(entry.$2);
        if (msg[2] != null) {
          entry.$1.done.completeError(Exception(msg[2]));
        } else {
          entry.$1.done.complete(msg[1] as int);
        }
        _pump();
      }
    });
    for (var i = 0; i < size; i++) {
      _isolates.add(await Isolate.spawn(_encodeWorker, _recv.sendPort));
    }
    await ready.future;
  }

  /// Encodes [rgba] to [outPath]; returns the AVIF byte size.
  Future<int> encode(Uint8List rgba, int w, int h, int quantizer, int speed,
      String outPath) {
    final job = _Job(_nextId++, TransferableTypedData.fromList([rgba]), w, h,
        quantizer, speed, outPath);
    final pending = _Pending(job);
    _queue.add(pending);
    _pump();
    return pending.done.future;
  }

  void _pump() {
    while (_idle.isNotEmpty && _queue.isNotEmpty) {
      final port = _idle.removeFirst();
      final pending = _queue.removeFirst();
      _inFlight[pending.job.id] = (pending, port);
      port.send(pending.job);
    }
  }

  void dispose() {
    for (final i in _isolates) {
      i.kill(priority: Isolate.immediate);
    }
    _recv.close();
  }
}

// ───────────────────────── decode / resize ─────────────────────────

class _Rgba {
  final int w, h;
  final Uint8List bytes;
  _Rgba(this.w, this.h, this.bytes);
}

(int, int) _fit(int w, int h, int maxDim) {
  final s = min(1.0, maxDim / max(w, h));
  return (max(1, (w * s).round()), max(1, (h * s).round()));
}

Future<_Rgba> _resizeRgba(Uint8List rgba, int w, int h, int maxDim) async {
  final (tw, th) = _fit(w, h, maxDim);
  if (tw == w && th == h) return _Rgba(w, h, rgba);
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, c.complete,
      targetWidth: tw, targetHeight: th);
  final img = await c.future;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final out = _Rgba(img.width, img.height, data!.buffer.asUint8List());
  img.dispose();
  return out;
}

Future<_Rgba> _loadScaled(File f, int maxDim) async {
  final bytes = await f.readAsBytes();
  if (p.extension(f.path).toLowerCase() == '.avif') {
    final decoded = decodeAvif(bytes);
    return _resizeRgba(
        decoded.frames.first.rgba, decoded.width, decoded.height, maxDim);
  }
  final buf = await ui.ImmutableBuffer.fromUint8List(bytes);
  final desc = await ui.ImageDescriptor.encoded(buf);
  final (tw, th) = _fit(desc.width, desc.height, maxDim);
  final scaled = tw != desc.width || th != desc.height;
  final codec = await desc.instantiateCodec(
      targetWidth: scaled ? tw : null, targetHeight: scaled ? th : null);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final out = _Rgba(frame.image.width, frame.image.height, data!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  desc.dispose();
  buf.dispose();
  return out;
}

// ───────────────────────── pipeline ─────────────────────────

Future<GalleryStats> generateAvifGalleries({
  required Map<String, List<File>> galleries,
  required String outputRoot,
  required AvifGalleryOptions options,
  required CancelToken cancel,
  required void Function(GalleryProgress) onProgress,
}) async {
  final sw = Stopwatch()..start();
  final poolSize =
      options.workers > 0 ? options.workers : max(1, Platform.numberOfProcessors - 1);
  final pool = _EncoderPool(poolSize);
  await pool.start();

  final total = galleries.values
      .fold<int>(0, (n, l) => n + l.length);
  var done = 0;
  var origBytes = 0;
  var convBytes = 0;
  final indexEntries = <String, int>{};

  try {
    for (final entry in galleries.entries) {
      if (cancel.cancelled) break;
      final dirName = _sanitizeName(entry.key);
      final galleryDir = p.join(outputRoot, dirName);
      await Directory(p.join(galleryDir, 'th')).create(recursive: true);
      await Directory(p.join(galleryDir, 'images')).create(recursive: true);

      final files = entry.value;
      final items = List<GalleryItem?>.filled(files.length, null);
      final used = <String>{};
      final names = <String>[];
      for (final f in files) {
        final isSvg = p.extension(f.path).toLowerCase() == '.svg';
        var base = isSvg ? _sanitizeName(p.basename(f.path)) : _sanitizeFile(p.basename(f.path));
        var unique = base;
        var n = 1;
        while (!used.add(unique)) {
          unique = '${base}_${n++}';
        }
        names.add(unique);
      }

      var cursor = 0;
      Future<void> worker() async {
        while (!cancel.cancelled) {
          final i = cursor++;
          if (i >= files.length) return;
          final f = files[i];
          final name = names[i];
          try {
            // NB: never write `x += await ...` with concurrent workers: x is read
            // before the await, so parallel updates overwrite each other.
            final srcLen = await f.length();
            origBytes += srcLen;
            if (p.extension(f.path).toLowerCase() == '.svg') {
              await f.copy(p.join(galleryDir, 'images', name));
              items[i] = GalleryItem(name, 350, 350, isSvg: true);
              convBytes += srcLen;
            } else {
              final full = await _loadScaled(f, options.fullMaxDim);
              final thumb = await _resizeRgba(
                  full.bytes, full.w, full.h, options.thumbMaxDim);
              final fullJob = pool.encode(full.bytes, full.w, full.h,
                  options.quantizer, options.speed,
                  p.join(galleryDir, 'images', '$name.avif'));
              final thumbJob = pool.encode(thumb.bytes, thumb.w, thumb.h,
                  options.quantizer, options.speed,
                  p.join(galleryDir, 'th', '$name.avif'));
              final fullLen = await fullJob; // images/ only, not th/
              await thumbJob;
              convBytes += fullLen;
              items[i] = GalleryItem(name, thumb.w, thumb.h);
            }
          } catch (e) {
            // Skip unreadable/undecodable files rather than abort the run.
            // ignore: avoid_print
            print('Skipped ${f.path}: $e');
          }
          done++;
          onProgress(GalleryProgress(done, total, '$dirName: ${p.basename(f.path)}'));
        }
      }

      // pool size + 1 so decoding of the next image overlaps with encoding
      await Future.wait(List.generate(poolSize + 1, (_) => worker()));
      if (cancel.cancelled) break;

      final ok = items.whereType<GalleryItem>().toList();
      await File(p.join(galleryDir, 'index.html'))
          .writeAsString(generateGalleryHtml(entry.key, ok, options.titleOption));
      indexEntries[dirName] = ok.length;
    }

    if (!cancel.cancelled) {
      await File(p.join(outputRoot, 'index.html'))
          .writeAsString(generateIndexHtml(indexEntries));
    }
  } finally {
    pool.dispose();
  }

  return GalleryStats(done, indexEntries.length, origBytes, convBytes, sw.elapsed,
      outputRoot);
}
