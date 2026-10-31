// lib/services/svg_palette_service.dart
//
// Image -> recolorable SVG gallery (macOS only).
//
//   decode / orient / Vision cutout / resize / smooth : native (MethodChannel, CoreImage + Vision)
//   k-means quantize, flat PNG, AVIF thumbnail         : Dart isolate (same libaom call as the AVIF gallery)
//   shape tracing                                      : bundled vtracer binary
//   SVG slotting + HTML pages                          : Dart
//
// Fixed on purpose: 5 colour groups, AVIF thumbnails with exactly the parameters used by
// AvifGalleryOptions (quality 50 -> quantizer 32, speed 8, 1 thread, 350 px). No JPEG fallback:
// if an AVIF thumbnail fails, that image fails and is logged.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:avif_native/avif_native.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'avif_gallery_service.dart' show AvifGalleryOptions, CancelToken;
import 'svg_palette_color.dart';
import 'svg_palette_html.dart';
import 'svg_palette_svg.dart';

export 'svg_palette_svg.dart' show SvgPaletteException;

const _avif = AvifGalleryOptions(); // quality 50, speed 8, thumbMaxDim 350

const Set<String> kSvgPaletteExts = {
  'jpg', 'jpeg', 'png', 'heic', 'heif', 'avif', 'tif', 'tiff', 'webp', 'bmp', 'gif', 'svg'
};

/// Images directly inside [dir] (not recursive), sorted by file name.
List<File> listSvgPaletteImages(String dir) {
  final out = <File>[];
  try {
    for (final e in Directory(dir).listSync(followLinks: false)) {
      if (e is! File) continue;
      final name = p.basename(e.path);
      if (name.startsWith('.')) continue;
      if (kSvgPaletteExts.contains(p.extension(name).replaceFirst('.', '').toLowerCase())) {
        out.add(e);
      }
    }
  } catch (_) {}
  out.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  return out;
}

class SvgPaletteOptions {
  /// Palette slots per image. Fixed.
  static const int colors = 5;

  final int size; // longest side before tracing
  final int jobs; // images processed in parallel
  final int speckle; // vtracer filter_speckle: drop shapes smaller than this
  final int smooth; // median-filter passes before quantizing (kills JPEG noise)
  final double simplify; // vtracer curve simplification tolerance in px (0 = off)
  final int pathPrecision; // decimal places in path coordinates
  final bool stacked; // overlapping layers instead of seam-free cutout + real <g> groups
  final bool watershed; // edge-aware regions snapped to the palette
  final int watershedDetail;
  final bool makeBackground;
  final bool makeCutout;
  final bool makeCrop; // Vision saliency: crop to the most interesting region
  final bool makeFaces; // Vision face detection: per face a crop (face) and a background-removed crop (facecut)
  final bool makeOriginal; // the source image as the usual AVIF thumbnail, to compare against the SVGs
  final bool makeOcr; // Vision text recognition: an item only when the image contains text
  final bool makeMasks; // Vision instance masks: one item per separate subject (Mask 1, 2, ...)
  final String outputRoot; // run folders (yyyy_MM_dd_HH_mm_ss) are created inside

  const SvgPaletteOptions({
    required this.outputRoot,
    this.size = 640,
    this.jobs = 8,
    this.speckle = 2,
    this.smooth = 1,
    this.simplify = 1.5,
    this.pathPrecision = 2,
    this.stacked = false,
    this.watershed = false,
    this.watershedDetail = 232,
    this.makeBackground = true,
    this.makeCutout = true,
    this.makeCrop = true,
    this.makeFaces = true,
    this.makeOriginal = true,
    this.makeOcr = true,
    this.makeMasks = true,
  });

  /// Upper limit of Mask N items per image.
  static const int maxMasks = 8;

  /// Upper limit of face crops per image.
  static const int maxFaces = 8;
}

class SvgPaletteSummary {
  final String indexPath;
  final String runDir;
  final int ok; // SVG pages written
  final int images; // source images attempted
  final int seconds;
  SvgPaletteSummary(this.indexPath, this.runDir, this.ok, this.images, this.seconds);
}

// ───────────────────────── native bridge (CoreImage + Vision) ─────────────────────────

class SvgPaletteNative {
  static const MethodChannel _ch = MethodChannel('substitcher/svgpalette');

  /// True when the image already has a transparent background (>2% transparent at 128 px).
  static Future<bool> alreadyCutOut(String input) async =>
      (await _ch.invokeMethod<bool>('probe', {'input': input})) ?? false;

  /// Number of faces Vision finds (large and confident enough to be worth a card).
  static Future<int> faceCount(String input) async =>
      (await _ch.invokeMethod<int>('faces', {'input': input})) ?? 0;

  /// Number of separate foreground subjects Vision finds (0 before macOS 14).
  static Future<int> instanceCount(String input) async =>
      (await _ch.invokeMethod<int>('instances', {'input': input})) ?? 0;

  /// Text recognised in [input] by Apple Vision, lines joined with '\n'. Empty when none.
  static Future<String> recognizeText(String input) async =>
      (await _ch.invokeMethod<String>('ocr', {'input': input})) ?? '';

  /// Loads [input] (EXIF orientation applied), then depending on [mode]:
  ///   orig     the image untouched, only shrunk to fit [maxSide] (no smoothing)
  ///   bg       the image as is
  ///   cut      background removed with Apple Vision (cropped to the subject)
  ///   crop     cropped to the most salient region (Vision saliency)
  ///   cropcut  the same crop, then the background removed
  ///   face     crop around face number [instance] (1-based, Vision face detection)
  ///   facecut  the same crop with the background removed (only that face's subject is kept)
  ///   mask     only subject number [instance] (1-based, Vision instance masks)
  /// [cutout] says whether bg/cut must run the Vision cutout (false when the image is
  /// already transparent). Then scales the longest side to [maxSide] (Lanczos), applies [smooth]
  /// median-filter passes and writes an RGBA PNG to [output].
  static Future<void> render({
    required String input,
    required String output,
    required int maxSide,
    required int smooth,
    required bool cutout,
    String mode = 'bg',
    int instance = 1,
  }) async {
    await _ch.invokeMethod<void>('render', {
      'input': input,
      'output': output,
      'maxSide': maxSide,
      'smooth': smooth,
      'cutout': cutout,
      'mode': mode,
      'instance': instance,
    });
  }
}

// ───────────────────────── vtracer (bundled) ─────────────────────────

/// vtracer ships as a Flutter asset (a universal macOS binary, see tool/build_vtracer_universal.sh).
/// On first use it is copied to Application Support, made executable and, if macOS refuses to
/// run it (unsigned arm64 binaries get killed), ad-hoc signed.
class Vtracer {
  static String? _cached;

  /// <App>.app/Contents/Resources/vtracer/vtracer, copied there by the Run Script build phase.
  static String get _bundledPath => p.normalize(p.join(
      p.dirname(Platform.resolvedExecutable), '..', 'Resources', 'vtracer', 'vtracer'));

  /// Path of a working vtracer, or throws [SvgPaletteException].
  static Future<String> resolve({bool forceRecheck = false}) async {
    final c = _cached;
    if (!forceRecheck && c != null && File(c).existsSync()) return c;
    _cached = null;

    final bundled = File(_bundledPath);
    if (bundled.existsSync()) {
      final err = await _check(bundled.path);
      if (err != null) throw SvgPaletteException('The bundled vtracer does not run: $err');
      return _cached = bundled.path;
    }

    // Development fallback: a cargo / Homebrew install.
    final home = Platform.environment['HOME'] ?? '';
    final dirs = [
      ...(Platform.environment['PATH'] ?? '').split(':'),
      '$home/.cargo/bin',
      '/opt/homebrew/bin',
      '/usr/local/bin',
    ];
    for (final d in dirs) {
      final f = File('$d/vtracer');
      if (d.isNotEmpty && f.existsSync() && await _check(f.path) == null) {
        return _cached = f.path;
      }
    }
    throw SvgPaletteException(
        'vtracer not found. Put it at macos/Runner/Resources/vtracer/vtracer and rebuild.');
  }

  /// "vtracer 1.0.0-alpha.4", or null if it cannot be run.
  static Future<String?> versionText(String exe) async {
    try {
      final r = await Process.run(exe, ['--version']).timeout(const Duration(seconds: 10));
      final text = '${r.stdout}${r.stderr}'.trim();
      return r.exitCode == 0 && text.isNotEmpty ? text : null;
    } catch (_) {
      return null;
    }
  }

  /// Needs the 1.0 engine (seam-free cutout, --simplify). Returns an error message, or null if OK.
  static Future<String?> _check(String exe) async {
    final text = await versionText(exe);
    if (text == null) return 'could not run $exe';
    final m = RegExp(r'(\d+)\.\d+').firstMatch(text);
    if (m == null) return 'could not read the vtracer version ($text)';
    return int.parse(m.group(1)!) >= 1 ? null : 'found $text, need 1.0 or newer';
  }
}

class _Trace {
  final int speckle, pathPrecision;
  final bool cutout;
  final double simplify;
  final int? watershedDetail; // null = default colour clustering on the pre-flattened image
  final List<String> palette; // snapped to when watershed is on
  _Trace(this.speckle, this.pathPrecision, this.cutout, this.simplify, this.watershedDetail,
      this.palette);
}

/// The input PNG is already flat-coloured (exactly N colours), so vtracer only has to find
/// shapes and fit curves. cutout = seam-free mosaic; stacked = overlapping layers.
Future<void> _runVtracer(String exe, String input, String output, _Trace q) async {
  final args = <String>[
    '-i', input, '-o', output,
    '--hierarchical', q.cutout ? 'cutout' : 'stacked',
    '-m', 'spline',
    '-f', '${q.speckle}',
    '-p', '8',
    '-g', '2',
    '--path-precision', '${q.pathPrecision}',
    if (q.simplify > 0) ...['--simplify', '${q.simplify}'],
    if (q.watershedDetail != null) ...[
      '--clustering', 'watershed',
      '--watershed-detail', '${q.watershedDetail}',
      if (q.palette.isNotEmpty) ...['--palette', q.palette.join(',')],
    ],
  ];
  final r = await Process.run(exe, args);
  if (r.exitCode != 0) throw SvgPaletteException('vtracer failed: ${r.stderr}');
}

// ───────────────────────── isolate work ─────────────────────────

/// Runs `fn(arg)` in a fresh isolate. The closure lives in this tiny scope on purpose, so
/// nothing but [fn] and [arg] is ever copied across (callers' variables stay behind).
Future<R> _inIsolate<A, R>(R Function(A) fn, A arg) => Isolate.run(() => fn(arg));

(int, int) _fit(int w, int h, int maxDim) {
  final s = maxDim / max(w, h);
  return (max(1, (w * s).round()), max(1, (h * s).round()));
}

img.Image _toImage(Uint8List rgba, int w, int h) => img.Image.fromBytes(
      width: w,
      height: h,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

class _PrepIn {
  final String srcPng, flatPng, thumbAvif;
  final int colors, thumbSize, quantizer, speed;
  final bool watershed;
  _PrepIn(this.srcPng, this.flatPng, this.thumbAvif, this.colors, this.thumbSize,
      this.quantizer, this.speed, this.watershed);
}

class _PrepOut {
  final List<Rgb> palette;
  _PrepOut(this.palette);
}

/// Rendered PNG -> k-means palette -> flat PNG for vtracer + AVIF thumbnail (flat image over the
/// card colour, so no alpha is needed). Throws if the AVIF encode fails.
_PrepOut _prepare(_PrepIn a) {
  final decoded = img.decodePng(File(a.srcPng).readAsBytesSync());
  if (decoded == null) throw SvgPaletteException('could not read the rendered image');
  final src = (decoded.numChannels == 4 && decoded.format == img.Format.uint8)
      ? decoded
      : decoded.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
  final w = src.width, h = src.height;
  final rgba = Uint8List.fromList(src.getBytes(order: img.ChannelOrder.rgba));

  final q = quantize(rgba, w, h, a.colors);
  if (q == null) throw SvgPaletteException('image has no opaque pixels');
  final flat = flatten(rgba, w, h, q);

  final traceInput = a.watershed ? binarizeAlpha(rgba, w, h) : flat;
  File(a.flatPng).writeAsBytesSync(img.encodePng(_toImage(traceInput, w, h), level: 1));

  // Thumbnail: flat colours over the same dark as the gallery card (42, 42, 46).
  final over = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    if (flat[o + 3] == 0) {
      over[o] = 42;
      over[o + 1] = 42;
      over[o + 2] = 46;
    } else {
      over[o] = flat[o];
      over[o + 1] = flat[o + 1];
      over[o + 2] = flat[o + 2];
    }
    over[o + 3] = 255;
  }
  _writeAvif(over, w, h, a.thumbSize, a.quantizer, a.speed, a.thumbAvif);
  return _PrepOut(q.palette);
}

/// Opaque RGBA -> (resized to fit [maxDim]) -> AVIF file. Same encoder settings for every image.
void _writeAvif(Uint8List opaqueRgba, int w, int h, int maxDim, int quantizer, int speed,
    String path) {
  final (tw, th) = _fit(w, h, maxDim);
  var thumb = _toImage(opaqueRgba, w, h);
  if (tw != w || th != h) {
    thumb = img.copyResize(thumb,
        width: tw,
        height: th,
        interpolation: tw < w ? img.Interpolation.average : img.Interpolation.cubic);
  }
  final thumbRgba = Uint8List.fromList(thumb.getBytes(order: img.ChannelOrder.rgba));
  final bytes = encodeAvifFrames(
    width: thumb.width,
    height: thumb.height,
    frames: [AvifEncodeFrame(rgba: thumbRgba, duration: const Duration(milliseconds: 100))],
    options: AvifEncodeOptions(
      speed: speed,
      minQuantizer: quantizer,
      maxQuantizer: quantizer,
      maxThreads: 1, // parallelism comes from several images at once
    ),
  );
  File(path).writeAsBytesSync(bytes);
}

class _OrigIn {
  final String srcPng, avif;
  final int maxDim, quantizer, speed;
  _OrigIn(this.srcPng, this.avif, this.maxDim, this.quantizer, this.speed);
}

/// The untouched image (already shrunk natively) -> AVIF. Transparent parts are blended over the
/// gallery card colour (42, 42, 46) so the AVIF needs no alpha.
void _encodeOriginal(_OrigIn a) {
  final decoded = img.decodePng(File(a.srcPng).readAsBytesSync());
  if (decoded == null) throw SvgPaletteException('could not read the original image');
  final src = (decoded.numChannels == 4 && decoded.format == img.Format.uint8)
      ? decoded
      : decoded.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
  final w = src.width, h = src.height;
  final rgba = src.getBytes(order: img.ChannelOrder.rgba);
  final over = Uint8List(w * h * 4);
  const bg = [42, 42, 46];
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    final al = rgba[o + 3];
    for (var c = 0; c < 3; c++) {
      // Straight (non-premultiplied) alpha, as the native side writes it.
      over[o + c] = ((rgba[o + c] * al + bg[c] * (255 - al)) / 255).round();
    }
    over[o + 3] = 255;
  }
  _writeAvif(over, w, h, a.maxDim, a.quantizer, a.speed, a.avif);
}

class _ThemifyIn {
  final String raw;
  final List<Rgb> palette;
  final bool grouped;
  _ThemifyIn(this.raw, this.palette, this.grouped);
}

ThemedSvg _themifyJob(_ThemifyIn a) => themify(a.raw, a.palette, grouped: a.grouped);

class _ImportIn {
  final String raw;
  final int colors;
  _ImportIn(this.raw, this.colors);
}

ImportedSvg _importJob(_ImportIn a) => themifyExisting(a.raw, a.colors);

// ───────────────────────── pipeline ─────────────────────────

class _Job {
  final SvgPaletteOptions opts;
  final String vtracer;
  final String thumbDir, pageDir, workDir, failedDir;
  final CancelToken cancel;
  final void Function(String) log;
  _Job(this.opts, this.vtracer, this.thumbDir, this.pageDir, this.workDir, this.failedDir,
      this.cancel, this.log);
}

String _safeName(String path, int index) {
  var stem = p.basenameWithoutExtension(path).replaceAll(RegExp(r'[^A-Za-z0-9-]+'), '');
  if (stem.length > 50) stem = stem.substring(0, 50);
  return '$stem-$index';
}

/// One variant of a source image that becomes one gallery item.
class _Variant {
  final String tag; // bg, cut, crop, cropcut, face, facecut, mask
  final bool cutout; // run the Vision cutout (bg/cut)
  final int instance; // 1-based, face, facecut and mask only
  const _Variant(this.tag, {this.cutout = false, this.instance = 0});
  String get suffix => tag == 'mask' || tag == 'face' || tag == 'facecut' ? '$tag$instance' : tag;
}

/// The source image as an AVIF thumbnail (same size as the others, never enlarged) so it can be
/// compared with the SVG variants.
/// Writes `th/<base>-orig.avif` and returns its gallery item, or null on failure.
Future<SvgGalleryItem?> _processOriginal(File file, int index, String base, _Job job) async {
  final name = '$base-orig';
  final srcPng = p.join(job.workDir, '$name.src.png');
  try {
    await SvgPaletteNative.render(
        input: file.path,
        output: srcPng,
        maxSide: _avif.thumbMaxDim,
        smooth: 0,
        cutout: false,
        mode: 'orig');
    final avifPath = p.join(job.thumbDir, '$name.avif');
    await _inIsolate(
        _encodeOriginal,
        _OrigIn(srcPng, avifPath, _avif.thumbMaxDim, _avif.quantizer, _avif.speed));
    final size = await _pngSize(srcPng);
    return SvgGalleryItem(
      index: index,
      name: name,
      tag: 'orig',
      w: size.$1,
      h: size.$2,
      palette: const [],
      thumbExt: 'avif',
      bytes: File(avifPath).lengthSync(),
    );
  } catch (e) {
    job.log('${p.basename(file.path)}: no original ($e)');
    return null;
  } finally {
    try {
      File(srcPng).deleteSync();
    } catch (_) {}
  }
}

/// Pixel size of a PNG (read from its header, no full decode).
Future<(int, int)> _pngSize(String png) async {
  final raf = await File(png).open();
  try {
    final head = await raf.read(24); // 8 signature + 4 length + 4 'IHDR' + 4 width + 4 height
    final b = ByteData.sublistView(Uint8List.fromList(head));
    return (b.getUint32(16), b.getUint32(20));
  } finally {
    await raf.close();
  }
}

/// OCR: an item only when Vision finds text. It reuses the original's AVIF (same image).
Future<SvgGalleryItem?> _processOcr(
    File file, int index, String base, SvgGalleryItem? orig, _Job job) async {
  try {
    final text = (await SvgPaletteNative.recognizeText(file.path)).trim();
    if (text.isEmpty) return null;
    return SvgGalleryItem(
      index: index,
      name: '$base-ocr',
      tag: 'ocr',
      w: orig?.w ?? _avif.thumbMaxDim,
      h: orig?.h ?? _avif.thumbMaxDim,
      palette: const [],
      thumbExt: 'avif',
      thumbName: orig?.name,
      text: text,
    );
  } catch (e) {
    job.log('${p.basename(file.path)}: no OCR ($e)');
    return null;
  }
}

/// One source image -> several gallery items (original, background, cutout, smart crop, faces, masks, text).
Future<List<SvgGalleryItem>> _processImage(File file, int index, _Job job) async {
  if (job.cancel.cancelled) return [];
  if (p.extension(file.path).toLowerCase() == '.svg') return _processSvg(file, index, job);

  final o = job.opts;
  final base = _safeName(file.path, index);
  final results = <SvgGalleryItem>[];
  final fileName = p.basename(file.path);
  try {
    // The OCR card shows the original's AVIF, so it is made whenever either is wanted.
    SvgGalleryItem? orig;
    if (o.makeOriginal || o.makeOcr) {
      orig = await _processOriginal(file, index, base, job);
      if (orig != null && o.makeOriginal) results.add(orig);
    }
    if (o.makeOcr && orig != null) {
      final ocr = await _processOcr(file, index, base, orig, job);
      if (ocr != null) results.add(ocr);
    }

    final alreadyCut = await SvgPaletteNative.alreadyCutOut(file.path);
    final variants = <_Variant>[];
    var faceTotal = 0;
    if (alreadyCut) {
      if (o.makeCutout) variants.add(const _Variant('cut'));
    } else {
      if (o.makeBackground) variants.add(const _Variant('bg'));
      if (o.makeCutout) variants.add(const _Variant('cut', cutout: true));
    }
    if (o.makeCrop) {
      variants.add(const _Variant('crop'));
      // Only when there is a crop; an already transparent image would just repeat it.
      if (!alreadyCut) variants.add(const _Variant('cropcut', cutout: true));
    }
    if (o.makeFaces) {
      try {
        faceTotal = min(await SvgPaletteNative.faceCount(file.path), SvgPaletteOptions.maxFaces);
        for (var i = 1; i <= faceTotal; i++) {
          variants.add(_Variant('face', instance: i));
          variants.add(_Variant('facecut', instance: i));
        }
      } catch (e) {
        job.log('$fileName: no faces ($e)');
      }
    }
    if (o.makeMasks) {
      try {
        final n = await SvgPaletteNative.instanceCount(file.path);
        // One subject would just repeat the cutout.
        if (n >= 2) {
          for (var i = 1; i <= min(n, SvgPaletteOptions.maxMasks); i++) {
            variants.add(_Variant('mask', instance: i));
          }
        }
      } catch (e) {
        job.log('$fileName: no masks ($e)');
      }
    }

    var cropFailed = false;
    for (final v in variants) {
      final tag = v.tag;
      if (tag == 'cropcut' && cropFailed) continue; // no useful crop, so no cropcut either
      final name = '$base-${v.suffix}';
      final srcPng = p.join(job.workDir, '$name.src.png');
      final flatPng = p.join(job.workDir, '$name.png');
      final rawSvg = p.join(job.workDir, '$name.svg');
      try {
        try {
          await SvgPaletteNative.render(
              input: file.path,
              output: srcPng,
              maxSide: o.size,
              smooth: o.smooth,
              cutout: v.cutout,
              mode: tag,
              instance: v.instance);
        } catch (e) {
          if (tag == 'crop') cropFailed = true;
          if (tag != 'bg') {
            job.log('$fileName: no $tag variant ($e)');
            continue; // the other variants are still kept
          }
          rethrow;
        }

        final prep = await _inIsolate(
            _prepare,
            _PrepIn(srcPng, flatPng, p.join(job.thumbDir, '$name.avif'),
                SvgPaletteOptions.colors, _avif.thumbMaxDim, _avif.quantizer, _avif.speed,
                o.watershed));

        await _runVtracer(
            job.vtracer,
            flatPng,
            rawSvg,
            _Trace(o.speckle, o.pathPrecision, !o.stacked, o.simplify,
                o.watershed ? o.watershedDetail : null, prep.palette.map((c) => c.hex).toList()));

        final rawText = await File(rawSvg).readAsString();
        final ThemedSvg themed;
        try {
          themed = await _inIsolate(_themifyJob, _ThemifyIn(rawText, prep.palette, !o.stacked));
        } catch (e) {
          // Keep the raw vtracer output so the unexpected format can be inspected.
          try {
            await Directory(job.failedDir).create(recursive: true);
            await File(p.join(job.failedDir, '$name.svg')).writeAsString(rawText);
          } catch (_) {}
          rethrow;
        }

        final item = SvgGalleryItem(
          index: index,
          name: name,
          tag: tag,
          w: themed.width,
          h: themed.height,
          palette: prep.palette.map((c) => c.hex).toList(),
          thumbExt: 'avif',
          // A single face is just 'face' / 'facecut'; several are 'face 1', 'facecut 1', 'face 2', ...
          variant: (v.tag == 'face' || v.tag == 'facecut') && faceTotal == 1 ? 0 : v.instance,
          bytes: utf8.encode(themed.svg).length,
        );
        await File(p.join(job.pageDir, '$name.html')).writeAsString(themePage(item, themed.svg));
        results.add(item);
      } finally {
        for (final f in [srcPng, flatPng, rawSvg]) {
          try {
            File(f).deleteSync();
          } catch (_) {}
        }
      }
    }
  } catch (e) {
    job.log('FAILED $fileName: $e');
  }
  return results;
}

/// SVG input: re-slot its colours and embed it in a theme page (recolor + stroke animation).
/// The original file is the thumbnail.
Future<List<SvgGalleryItem>> _processSvg(File file, int index, _Job job) async {
  final name = '${_safeName(file.path, index)}-svg';
  try {
    final raw = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    final imported = await _inIsolate(_importJob, _ImportIn(raw, SvgPaletteOptions.colors));

    final thumb = File(p.join(job.thumbDir, '$name.svg'));
    if (thumb.existsSync()) thumb.deleteSync();
    await file.copy(thumb.path);

    final item = SvgGalleryItem(
      index: index,
      name: name,
      tag: 'svg',
      w: imported.width,
      h: imported.height,
      palette: imported.palette.map((c) => c.hex).toList(),
      thumbExt: 'svg',
      bytes: utf8.encode(imported.svg).length,
    );
    await File(p.join(job.pageDir, '$name.html'))
        .writeAsString(themePage(item, imported.svg, slotMap: imported.slotMap));
    return [item];
  } catch (e) {
    job.log('FAILED ${p.basename(file.path)}: $e');
    return [];
  }
}

// ───────────────────────── engine ─────────────────────────

String _stamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}_${two(t.month)}_${two(t.day)}_${two(t.hour)}_${two(t.minute)}_${two(t.second)}';
}

/// Traces [files], writes th/, pages/, palettes.js and index.html into
/// `<outputRoot>/<timestamp>/`. Running images finish on cancel; no new ones start.
Future<SvgPaletteSummary> runSvgPalette({
  required List<File> files,
  required SvgPaletteOptions options,
  required CancelToken cancel,
  required void Function(int done, int total) onProgress,
  required void Function(String line) onLog,
}) async {
  final vtracer = await Vtracer.resolve();
  final sw = Stopwatch()..start();

  final runDir = p.join(options.outputRoot, _stamp(DateTime.now()));
  final work = await Directory.systemTemp.createTemp('svgpalette-');
  final job = _Job(options, vtracer, p.join(runDir, 'th'), p.join(runDir, 'pages'), work.path,
      p.join(runDir, 'failed'), cancel, onLog);
  await Directory(job.thumbDir).create(recursive: true);
  await Directory(job.pageDir).create(recursive: true);
  await File(p.join(runDir, 'palettes.js')).writeAsString(palettesJs());

  final items = <SvgGalleryItem>[];
  var done = 0;
  var cursor = 0;

  Future<void> worker() async {
    while (!cancel.cancelled) {
      final i = cursor++;
      if (i >= files.length) return;
      final result = await _processImage(files[i], i, job);
      items.addAll(result);
      done++;
      onProgress(done, files.length);
    }
  }

  try {
    await Future.wait(List.generate(max(1, options.jobs), (_) => worker()));
    items.sort((a, b) {
      final c = a.index.compareTo(b.index);
      if (c != 0) return c;
      final r = a.tagRank.compareTo(b.tagRank);
      if (r != 0) return r;
      // Faces pair up: face 1, facecut 1, face 2, facecut 2 ...
      final v = a.variant.compareTo(b.variant);
      if (v != 0) return v;
      return SvgGalleryItem.tagOrder.indexOf(a.tag)
          .compareTo(SvgGalleryItem.tagOrder.indexOf(b.tag));
    });
    final indexPath = p.join(runDir, 'index.html');
    await File(indexPath).writeAsString(galleryPage(items));
    // Original and text cards are not SVGs.
    final svgCount = items.where((it) => it.tag != 'orig' && it.tag != 'ocr').length;
    return SvgPaletteSummary(indexPath, runDir, svgCount, files.length, sw.elapsed.inSeconds);
  } finally {
    try {
      await work.delete(recursive: true);
    } catch (_) {}
  }
}
