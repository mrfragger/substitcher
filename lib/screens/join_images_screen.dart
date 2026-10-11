// lib/screens/join_images_screen.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:avif_native/avif_native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _rasterExts = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif', '.bmp'};
const _maxCanvasDim = 16384;

/// Top-level on purpose: the closure passed to Isolate.run must not capture
/// the State object (which holds dart:ui Images that can't be sent).
Future<Uint8List> _encodeInIsolate(
    TransferableTypedData ttd, int fw, int fh, String format, int threads) {
  return Isolate.run<Uint8List>(() {
    final rgba = ttd.materialize().asUint8List();
    if (format == 'avif') {
      return encodeAvifFrames(
        width: fw,
        height: fh,
        frames: [
          AvifEncodeFrame(rgba: rgba, duration: const Duration(milliseconds: 100))
        ],
        options: AvifEncodeOptions(
          speed: 8,
          minQuantizer: 32, // quality 50
          maxQuantizer: 32,
          maxThreads: threads,
        ),
      );
    }
    final im = img.Image.fromBytes(
        width: fw, height: fh, bytes: rgba.buffer, numChannels: 4);
    return Uint8List.fromList(img.encodeJpg(im, quality: 85));
  });
}

class _Src {
  final String path;
  final String name;
  final int size;
  final ui.Image image;
  final int id;
  _Src(this.id, this.path, this.name, this.size, this.image);
}

/// One placed image: source rect (sx..sh) -> destination rect (x,y,dw,dh).
class _Placed {
  final ui.Image image;
  double sx = 0, sy = 0, sw, sh;
  double dw, dh, x = 0, y = 0;
  _Placed(this.image, this.dw, this.dh)
      : sw = image.width.toDouble(),
        sh = image.height.toDouble();
}

const _sizingOptions = <String, String>{
  'none': 'Keep original sizes',
  'fit-width': 'Match widest (scale to fit width)',
  'fit-height': 'Match tallest (scale to fit height)',
  'fit-smallest': 'Match smallest (scale all to smallest)',
  'crop-uniform': 'Crop to uniform size',
  'stretch-uniform': 'Stretch to uniform size (may distort)',
  'masonry-2': 'Masonry - 2 columns',
  'masonry-3': 'Masonry - 3 columns',
  'masonry-4': 'Masonry - 4 columns',
  'masonry-5': 'Masonry - 5 columns',
  'masonry-6': 'Masonry - 6 columns',
};

class JoinImagesScreen extends StatefulWidget {
  /// Optional folder to pre-load images from (e.g. the folder of the image
  /// currently open in the player).
  final String? initialFolder;
  const JoinImagesScreen({super.key, this.initialFolder});

  @override
  State<JoinImagesScreen> createState() => _JoinImagesScreenState();
}

class _JoinImagesScreenState extends State<JoinImagesScreen> {
  final List<_Src> _images = [];
  int _nextId = 0;

  String _layout = 'vertical';
  String _sizing = 'none';
  bool _sizingTouched = false; // user picked a sizing manually
  double _padding = 10;
  double _borderWidth = 0;
  Color _bg = Colors.black;
  Color _borderColor = Colors.black;

  ui.Image? _preview;
  int _canvasW = 0, _canvasH = 0;
  int _gen = 0;
  String? _error;

  bool _loading = false;
  bool _exporting = false;
  String? _status;
  String? _lastOutput;
  String? _lastOutputInfo;

  @override
  void initState() {
    super.initState();
    final d = widget.initialFolder;
    if (d != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addFolder(d));
    }
  }

  @override
  void dispose() {
    for (final s in _images) {
      s.image.dispose();
    }
    _preview?.dispose();
    super.dispose();
  }

  // ───────────────────────── loading ─────────────────────────

  Future<ui.Image> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    if (p.extension(path).toLowerCase() == '.avif') {
      final d = decodeAvif(bytes);
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(
          d.frames.first.rgba, d.width, d.height, ui.PixelFormat.rgba8888, c.complete);
      return c.future;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<void> _addPaths(List<String> paths) async {
    paths = paths
        .where((f) => _rasterExts.contains(p.extension(f).toLowerCase()))
        .toList();
    if (paths.isEmpty) return;
    setState(() => _loading = true);
    var n = 0;
    for (final f in paths) {
      try {
        final image = await _decode(f);
        final size = await File(f).length();
        _images.add(_Src(_nextId++, f, p.basename(f), size, image));
        n++;
        if (n % 5 == 0 && mounted) {
          setState(() => _status = 'Loading $n / ${paths.length}…');
        }
      } catch (e) {
        // ignore: avoid_print
        print('Skipped $f: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = 'Loaded $n image(s)';
      _autoSizing();
    });
    _refresh();
  }

  Future<void> _addImages() async {
    final res = await FilePicker.pickFiles(
        type: FileType.any, dialogTitle: 'Select Images to Combine');
    if (res.isEmpty) return;
    await _addPaths([for (final f in res) if (f.path != null) f.path!]);
  }

  Future<void> _addFolder([String? given]) async {
    final dir = given ?? await FilePicker.getDirectoryPath();
    if (dir == null) return;
    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList()
      ..sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
    await _addPaths(files);
  }

  void _remove(int i) {
    _images.removeAt(i).image.dispose();
    setState(_autoSizing);
    _refresh();
  }

  void _reset() {
    for (final s in _images) {
      s.image.dispose();
    }
    _images.clear();
    _preview?.dispose();
    _preview = null;
    setState(() {
      _layout = 'vertical';
      _sizing = 'none';
      _sizingTouched = false;
      _padding = 10;
      _borderWidth = 0;
      _bg = Colors.black;
      _borderColor = Colors.black;
      _error = null;
      _status = 'Reset complete';
      _lastOutput = null;
    });
  }

  void _sort(String type) {
    switch (type) {
      case 'name-asc':
        _images.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'name-desc':
        _images.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'size-asc':
        _images.sort((a, b) => a.size.compareTo(b.size));
      case 'size-desc':
        _images.sort((a, b) => b.size.compareTo(a.size));
      case 'shuffle':
        _images.shuffle();
    }
    setState(() {});
    _refresh();
  }

  // ───────────────────────── layout engine ─────────────────────────

  bool get _isMasonry => _sizing.startsWith('masonry-');
  int get _masonryCols => int.tryParse(_sizing.split('-').last) ?? 3;

  List<_Placed> _prepare() {
    final ims = _images.map((s) => s.image).toList();
    if (ims.isEmpty) return [];
    if (_isMasonry) return _masonry(_masonryCols);

    List<_Placed> mk(double Function(ui.Image) w, double Function(ui.Image) h) =>
        [for (final i in ims) _Placed(i, w(i), h(i))];

    switch (_sizing) {
      case 'fit-width':
        final mw = ims.map((i) => i.width).reduce(max).toDouble();
        return mk((i) => mw, (i) => i.height * mw / i.width);
      case 'fit-height':
        final mh = ims.map((i) => i.height).reduce(max).toDouble();
        return mk((i) => i.width * mh / i.height, (i) => mh);
      case 'fit-smallest':
        final minW = ims.map((i) => i.width).reduce(min).toDouble();
        final minH = ims.map((i) => i.height).reduce(min).toDouble();
        return [
          for (final i in ims)
            () {
              final s = min(minW / i.width, minH / i.height);
              return _Placed(i, i.width * s, i.height * s);
            }()
        ];
      case 'crop-uniform':
        final mw = ims.map((i) => i.width).reduce(max).toDouble();
        final mh = ims.map((i) => i.height).reduce(max).toDouble();
        final target = mw / mh;
        return [
          for (final i in ims)
            () {
              final pl = _Placed(i, mw, mh);
              final src = i.width / i.height;
              if (src > target) {
                pl.sh = i.height.toDouble();
                pl.sw = i.height * target;
                pl.sx = (i.width - pl.sw) / 2;
              } else {
                pl.sw = i.width.toDouble();
                pl.sh = i.width / target;
                pl.sy = (i.height - pl.sh) / 2;
              }
              return pl;
            }()
        ];
      case 'stretch-uniform':
        final mw = ims.map((i) => i.width).reduce(max).toDouble();
        final mh = ims.map((i) => i.height).reduce(max).toDouble();
        return mk((i) => mw, (i) => mh);
      default:
        return mk((i) => i.width.toDouble(), (i) => i.height.toDouble());
    }
  }

  List<_Placed> _masonry(int cols) {
    const canvasWidth = 1600.0;
    final pad = _padding;
    final items = [
      for (final s in _images) _Placed(s.image, s.image.width.toDouble(), s.image.height.toDouble())
    ]..sort((a, b) => b.dh.compareTo(a.dh));
    final colW = (canvasWidth - (cols - 1) * pad) / cols;
    final heights = List<double>.filled(cols, 0);
    for (final it in items) {
      final scale = colW / it.dw;
      it.dw = colW;
      it.dh = it.dh * scale;
      var c = 0;
      for (var i = 1; i < cols; i++) {
        if (heights[i] < heights[c]) c = i;
      }
      it.x = c * (colW + pad);
      it.y = heights[c];
      heights[c] += it.dh + pad;
    }
    return items;
  }

  /// Lays items out; returns canvas size and mutates item x/y.
  (double, double) _arrange(List<_Placed> items) {
    final bw = _borderWidth;
    final pad = _padding;
    if (items.isEmpty) return (800, 600);
    if (_isMasonry) {
      final mx = items.map((i) => i.x + i.dw).reduce(max);
      final my = items.map((i) => i.y + i.dh).reduce(max);
      for (final i in items) {
        i.x += bw;
        i.y += bw;
      }
      return (mx + bw * 2, my + bw * 2);
    }
    switch (_layout) {
      case 'horizontal':
        var x = bw;
        var mh = 0.0;
        for (final i in items) {
          i.x = x;
          i.y = bw;
          x += i.dw + pad;
          mh = max(mh, i.dh);
        }
        return (x - pad + bw, mh + bw * 2);
      case 'grid':
        final cols = sqrt(items.length).ceil();
        final rows = (items.length / cols).ceil();
        final cw = items.map((i) => i.dw).reduce(max);
        final ch = items.map((i) => i.dh).reduce(max);
        for (var n = 0; n < items.length; n++) {
          items[n].x = bw + (n % cols) * (cw + pad);
          items[n].y = bw + (n ~/ cols) * (ch + pad);
        }
        return (cw * cols + (cols - 1) * pad + bw * 2,
            ch * rows + (rows - 1) * pad + bw * 2);
      default: // vertical
        var y = bw;
        var mw = 0.0;
        for (final i in items) {
          i.x = bw;
          i.y = y;
          y += i.dh + pad;
          mw = max(mw, i.dw);
        }
        return (mw + bw * 2, y - pad + bw);
    }
  }

  ui.Image _render(double scale, List<_Placed> items, double w, double h) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(scale);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _bg);
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    for (final it in items) {
      c.drawImageRect(it.image, Rect.fromLTWH(it.sx, it.sy, it.sw, it.sh),
          Rect.fromLTWH(it.x, it.y, it.dw, it.dh), paint);
    }
    if (_borderWidth > 0) {
      c.drawRect(
          Rect.fromLTWH(_borderWidth / 2, _borderWidth / 2, w - _borderWidth,
              h - _borderWidth),
          Paint()
            ..color = _borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = _borderWidth);
    }
    final pic = rec.endRecording();
    final out = pic.toImageSync(max(1, (w * scale).ceil()), max(1, (h * scale).ceil()));
    pic.dispose();
    return out;
  }

  Future<void> _refresh() async {
    final gen = ++_gen;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (gen != _gen || !mounted) return;
    if (_images.isEmpty) {
      setState(() {
        _preview?.dispose();
        _preview = null;
      });
      return;
    }
    final items = _prepare();
    final (w, h) = _arrange(items);
    if (w > _maxCanvasDim || h > _maxCanvasDim) {
      setState(() {
        _preview?.dispose();
        _preview = null;
        _canvasW = w.ceil();
        _canvasH = h.ceil();
        _error = 'Result would be ${w.ceil()}×${h.ceil()} px — max is $_maxCanvasDim per side. '
            'Try Grid, a Masonry option or "Match smallest".';
      });
      return;
    }
    final scale = min(1.0, 1400 / max(w, h));
    final im = _render(scale, items, w, h);
    if (gen != _gen || !mounted) {
      im.dispose();
      return;
    }
    setState(() {
      _preview?.dispose();
      _preview = im;
      _canvasW = w.ceil();
      _canvasH = h.ceil();
      _error = null;
    });
  }

  // ───────────────────────── export ─────────────────────────

  Future<void> _export(String format) async {
    if (_images.isEmpty || _exporting) return;
    final items = _prepare();
    final (w, h) = _arrange(items);
    if (w > _maxCanvasDim || h > _maxCanvasDim) {
      setState(() => _error = 'Image too large to export (${w.ceil()}×${h.ceil()}).');
      return;
    }
    setState(() {
      _exporting = true;
      _status = 'Rendering…';
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final full = _render(1, items, w, h);
      final fw = full.width, fh = full.height;
      final outDir = p.join(p.dirname(_images.first.path), 'joined_images');
      await Directory(outDir).create(recursive: true);
      final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
      final outPath = p.join(outDir, 'combined-image-$ts.$format');
      final sw = Stopwatch()..start();

      if (format == 'png') {
        setState(() => _status = 'Encoding PNG…');
        final data = await full.toByteData(format: ui.ImageByteFormat.png);
        await File(outPath).writeAsBytes(data!.buffer.asUint8List());
      } else {
        final raw = await full.toByteData(format: ui.ImageByteFormat.rawRgba);
        final ttd = TransferableTypedData.fromList([raw!.buffer.asUint8List()]);
        setState(() => _status =
            format == 'avif' ? 'Encoding AVIF… (this may take a moment)' : 'Encoding JPG…');
        final threads = max(1, Platform.numberOfProcessors);
        final bytes = await _encodeInIsolate(ttd, fw, fh, format, threads);
        await File(outPath).writeAsBytes(bytes);
      }
      full.dispose();
      final len = await File(outPath).length();
      if (!mounted) return;
      setState(() {
        _lastOutput = outPath;
        _lastOutputInfo =
            '${format.toUpperCase()} • ${fw}×$fh • ${_fmt(len)} • ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
        _status = 'Saved ${p.basename(outPath)}';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openFolder(String dir) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [dir]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [dir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      }
    } catch (_) {}
  }

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KiB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MiB';
  }


  Widget _thumbBox(_Src s) => Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 2),
            borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: RawImage(
            image: s.image,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.low),
      );

  /// Grid tile: drag onto another tile to move it to that position.
  Widget _thumb(int i, bool busy) {
    final s = _images[i];
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != i,
      onAcceptWithDetails: (d) {
        final item = _images.removeAt(d.data);
        _images.insert(i, item);
        setState(() {});
        _refresh();
      },
      builder: (_, candidate, __) => Draggable<int>(
        data: i,
        maxSimultaneousDrags: busy ? 0 : 1,
        feedback: Opacity(
            opacity: 0.8, child: SizedBox(width: 100, height: 100, child: _thumbBox(s))),
        childWhenDragging: Opacity(opacity: 0.3, child: _thumbBox(s)),
        child: Tooltip(
          message: s.name,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Container(
                foregroundDecoration: candidate.isNotEmpty
                    ? BoxDecoration(
                        border: Border.all(color: _green, width: 2),
                        borderRadius: BorderRadius.circular(6))
                    : null,
                child: _thumbBox(s),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: busy ? null : () => _remove(i),
                  child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xFFEF4444),
                      child: Icon(Icons.close, size: 13, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill-style toggle button (same look as the sort buttons).
  Widget _pill(String label, bool selected, bool disabled, VoidCallback onTap) =>
      OutlinedButton(
        onPressed: disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? const Color(0x3300FF26) : null,
          side: BorderSide(color: selected ? _green : Colors.white24),
          foregroundColor: selected ? _green : null,
        ),
        child: Text(label),
      );

  /// Default sizing by image count, until the user chooses one themselves.
  void _autoSizing() {
    if (_sizingTouched) return;
    final n = _images.length;
    _sizing = n > 24
        ? 'masonry-6'
        : n > 15
            ? 'masonry-5'
            : n > 12
                ? 'masonry-4'
                : n > 9
                    ? 'masonry-3'
                    : 'none';
  }

  // ───────────────────────── UI ─────────────────────────

  static const _green = Color(0xFF00FF26);

  Widget _card(String title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _green, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _colorRow(String label, Color value, ValueChanged<Color> onChanged) {
    const swatches = [
      Colors.black,
      Colors.white,
      Color(0xFF808080),
      Color(0xFF1E1E1E),
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
    ];
    final hex = '#${value.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  $hex', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in swatches)
            GestureDetector(
              onTap: () {
                onChanged(c);
                _refresh();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: c == value ? _green : Colors.white38,
                      width: c == value ? 2 : 1),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _kv(String label, double v, double max, ValueChanged<double> cb) => Row(
        children: [
          SizedBox(
              width: 130,
              child: Text('$label ${v.round()}px',
                  softWrap: false, style: const TextStyle(color: Colors.white))),
          Expanded(
              child: Slider(
                  value: v,
                  min: 0,
                  max: max,
                  divisions: max.round(),
                  onChanged: (x) {
                    cb(x);
                    _refresh();
                  })),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _exporting;
    final canExport = _images.isNotEmpty && _error == null && !busy;
    const sortLabels = {
      'name-asc': '📝 Name A-Z',
      'name-desc': '📝 Name Z-A',
      'size-asc': '📏 Size ↑',
      'size-desc': '📏 Size ↓',
      'shuffle': '🔀 Shuffle',
    };
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Join Images'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                '1. Select Images to Combine',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: busy ? null : _addImages,
                          icon: const Icon(Icons.image),
                          label: const Text('Add Images')),
                      ElevatedButton.icon(
                          onPressed: busy ? null : () => _addFolder(),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Add Folder')),
                      TextButton(
                          onPressed: busy || _images.isEmpty ? null : _reset,
                          child: const Text('🔄 Reset')),
                    ]),
                    const SizedBox(height: 6),
                    const Text('jpg, png, webp, avif, static gif, bmp',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    if (_loading) const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator()),
                  ],
                ),
              ),
              if (_images.isNotEmpty) ...[
                _card(
                  '2. Arrange Your Images (${_images.length}) — drag onto another to reorder',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        for (final e in sortLabels.entries)
                          OutlinedButton(
                              onPressed: busy ? null : () => _sort(e.key),
                              child: Text(e.value)),
                      ]),
                      const SizedBox(height: 10),
                      LayoutBuilder(builder: (ctx, c) {
                        const tile = 110.0, gap = 10.0;
                        final cols = max(1, ((c.maxWidth + gap) / (tile + gap)).floor());
                        final rows = (_images.length / cols).ceil();
                        final h = min(rows * (tile + gap), 440.0);
                        return SizedBox(
                          height: h,
                          child: GridView.builder(
                            padding: const EdgeInsets.only(top: 8, right: 8),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: tile,
                              mainAxisSpacing: gap,
                              crossAxisSpacing: gap,
                            ),
                            itemCount: _images.length,
                            itemBuilder: (_, i) => _thumb(i, busy),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                _card(
                  '3. Choose Layout Style',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'horizontal',
                              icon: Icon(Icons.view_column),
                              label: Text('Horizontal')),
                          ButtonSegment(
                              value: 'vertical',
                              icon: Icon(Icons.view_agenda),
                              label: Text('Vertical')),
                          ButtonSegment(
                              value: 'grid',
                              icon: Icon(Icons.grid_view),
                              label: Text('Grid')),
                        ],
                        selected: {_layout},
                        onSelectionChanged: (v) {
                          setState(() => _layout = v.first);
                          _refresh();
                        },
                      ),
                      const SizedBox(height: 4),
                      if (_isMasonry)
                        const Text('Masonry ignores the layout buttons.',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 10),
                      _kv('Padding', _padding, 50, (v) => setState(() => _padding = v)),
                      _kv('Border Width', _borderWidth, 20,
                          (v) => setState(() => _borderWidth = v)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 40, runSpacing: 12, children: [
                        _colorRow('Background', _bg, (c) => setState(() => _bg = c)),
                        _colorRow('Border Color', _borderColor,
                            (c) => setState(() => _borderColor = c)),
                      ]),
                      const SizedBox(height: 12),
                      const Text('Image Sizing',
                          style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        for (final e in _sizingOptions.entries)
                          if (!e.key.startsWith('masonry-'))
                            _pill(e.value, _sizing == e.key, busy, () {
                              setState(() {
                                _sizing = e.key;
                                _sizingTouched = true;
                              });
                              _refresh();
                            }),
                        const Text('Masonry Columns:',
                            style: TextStyle(color: Colors.white)),
                        for (var n = 2; n <= 6; n++)
                          _pill('$n', _sizing == 'masonry-$n', busy, () {
                            setState(() {
                              _sizing = 'masonry-$n';
                              _sizingTouched = true;
                            });
                            _refresh();
                          }),
                      ]),
                    ],
                  ),
                ),
                _card(
                  '4. Preview Combined Image'
                  '${_canvasW > 0 ? '  ($_canvasW × $_canvasH px)' : ''}',
                  Container(
                    constraints: const BoxConstraints(minHeight: 200, maxHeight: 520),
                    alignment: Alignment.center,
                    child: _error != null
                        ? SelectableText(_error!,
                            style: const TextStyle(color: Colors.redAccent))
                        : _preview == null
                            ? const CircularProgressIndicator()
                            : RawImage(image: _preview, fit: BoxFit.contain),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                        onPressed: canExport ? () => _export('avif') : null,
                        child: const Text('✨ Save AVIF (smallest)')),
                    ElevatedButton(
                        onPressed: canExport ? () => _export('jpg') : null,
                        child: const Text('📷 Save JPG (85%)')),
                    ElevatedButton(
                        onPressed: canExport ? () => _export('png') : null,
                        child: const Text('🖼️ Save PNG (lossless)')),
                  ],
                ),
                if (_exporting) const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator()),
              ],
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SelectableText(_status!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
              if (_lastOutput != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x1A00FF26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x4D00FF26)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_lastOutputInfo ?? '',
                          style: const TextStyle(
                              color: _green, fontWeight: FontWeight.bold)),
                      Row(children: [
                        Expanded(
                            child: Text(_lastOutput!,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                                overflow: TextOverflow.ellipsis)),
                        TextButton(
                            onPressed: () => _openFolder(p.dirname(_lastOutput!)),
                            child: const Text('Open folder')),
                      ]),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
