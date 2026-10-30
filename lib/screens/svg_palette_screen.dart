// lib/screens/svg_palette_screen.dart
//
// Image -> recolorable SVG gallery. macOS only (Apple Vision does the background removal),
// so callers must only offer it when SvgPaletteScreen.isSupported.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/avif_gallery_service.dart' show CancelToken;
import '../services/svg_palette_service.dart';

class SvgPaletteScreen extends StatefulWidget {
  /// Pre-selects a folder (e.g. the folder of the image currently shown).
  final String? initialFolder;
  const SvgPaletteScreen({super.key, this.initialFolder});

  /// The tool needs Apple Vision + CoreImage, so it is macOS only.
  static bool get isSupported => Platform.isMacOS;

  static Future<void> open(BuildContext context, {String? initialFolder}) =>
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SvgPaletteScreen(initialFolder: initialFolder)),
      );

  /// Ready-made shortcut button. Wrap the call site in `if (SvgPaletteScreen.isSupported)`.
  static Widget shortcutButton(BuildContext context, {bool enabled = true}) =>
      ElevatedButton.icon(
        onPressed: enabled ? () => open(context) : null,
        icon: const Icon(Icons.palette),
        label: const Text('Image to Animated SVG'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
      );

  @override
  State<SvgPaletteScreen> createState() => _SvgPaletteScreenState();
}

class _SvgPaletteScreenState extends State<SvgPaletteScreen> {
  static const _green = Color(0xFF00FF26);

  // input
  String? _folder;
  List<File> _files = [];
  bool _scanning = false;
  String? _outputParent; // null = <input>/output

  // options (persisted). Colour groups are fixed at 5; AVIF thumbnails are fixed.
  bool _makeBackground = true;
  bool _makeCutout = true;
  bool _stacked = false;
  bool _watershed = false;
  int _size = 512;
  int _smooth = 1;
  int _speckle = 6;
  int _pathPrecision = 2;
  int _watershedDetail = 128;
  int _jobs = 6;
  double _simplify = 1.5;

  // vtracer
  String _vtracerInfo = 'Checking…';
  bool _vtracerOK = false;

  // run
  bool _busy = false;
  CancelToken? _cancel;
  int _done = 0;
  int _total = 0;
  final List<String> _log = [];
  SvgPaletteSummary? _summary;
  String? _error;
  final _sw = Stopwatch();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkVtracer();
    if (widget.initialFolder != null) _setFolder(widget.initialFolder!);
  }

  // ───────────── prefs ─────────────

  Future<void> _loadPrefs() async {
    final sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _makeBackground = sp.getBool('svgp_bg') ?? _makeBackground;
      _makeCutout = sp.getBool('svgp_cut') ?? _makeCutout;
      _stacked = sp.getBool('svgp_stacked') ?? _stacked;
      _watershed = sp.getBool('svgp_watershed') ?? _watershed;
      _size = sp.getInt('svgp_size') ?? _size;
      _smooth = sp.getInt('svgp_smooth') ?? _smooth;
      _speckle = sp.getInt('svgp_speckle') ?? _speckle;
      _pathPrecision = sp.getInt('svgp_precision') ?? _pathPrecision;
      _watershedDetail = sp.getInt('svgp_wsdetail') ?? _watershedDetail;
      _jobs = sp.getInt('svgp_jobs') ?? _jobs;
      _simplify = sp.getDouble('svgp_simplify') ?? _simplify;
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('svgp_bg', _makeBackground);
    await sp.setBool('svgp_cut', _makeCutout);
    await sp.setBool('svgp_stacked', _stacked);
    await sp.setBool('svgp_watershed', _watershed);
    await sp.setInt('svgp_size', _size);
    await sp.setInt('svgp_smooth', _smooth);
    await sp.setInt('svgp_speckle', _speckle);
    await sp.setInt('svgp_precision', _pathPrecision);
    await sp.setInt('svgp_wsdetail', _watershedDetail);
    await sp.setInt('svgp_jobs', _jobs);
    await sp.setDouble('svgp_simplify', _simplify);
  }

  void _set(VoidCallback fn) {
    setState(fn);
    _savePrefs();
  }

  // ───────────── actions ─────────────

  Future<void> _checkVtracer() async {
    setState(() {
      _vtracerInfo = 'Checking…';
      _vtracerOK = false;
    });
    try {
      final exe = await Vtracer.resolve(forceRecheck: true);
      final v = await Vtracer.versionText(exe);
      if (!mounted) return;
      setState(() {
        _vtracerInfo = '${v ?? 'vtracer'}  ·  bundled';
        _vtracerOK = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vtracerInfo = '$e';
        _vtracerOK = false;
      });
    }
  }

  Future<void> _setFolder(String dir) async {
    setState(() {
      _folder = dir;
      _scanning = true;
    });
    final files = listSvgPaletteImages(dir);
    if (!mounted) return;
    setState(() {
      _files = files;
      _scanning = false;
    });
  }

  Future<void> _chooseFolder() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) await _setFolder(dir);
  }

  Future<void> _pickOutput() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) setState(() => _outputParent = dir);
  }

  Future<void> _tryOne() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: kSvgPaletteExts.toList(),
      dialogTitle: 'Try one image',
    );
    final path = f?.path;
    if (path == null) return;
    await _run([File(path)], p.join(p.dirname(path), 'output'));
  }

  Future<void> _generate() async {
    final folder = _folder;
    if (folder == null || _files.isEmpty) return;
    await _run(_files, _outputParent ?? p.join(folder, 'output'));
  }

  Future<void> _run(List<File> files, String outputRoot) async {
    if (_busy || files.isEmpty) return;
    final cancel = CancelToken();
    setState(() {
      _busy = true;
      _cancel = cancel;
      _summary = null;
      _error = null;
      _done = 0;
      _total = files.length;
      _log.clear();
    });
    _sw
      ..reset()
      ..start();
    try {
      final summary = await runSvgPalette(
        files: files,
        options: SvgPaletteOptions(
          outputRoot: outputRoot,
          size: _size,
          jobs: _jobs,
          speckle: _speckle,
          smooth: _smooth,
          simplify: _simplify,
          pathPrecision: _pathPrecision,
          stacked: _stacked,
          watershed: _watershed,
          watershedDetail: _watershedDetail,
          makeBackground: _makeBackground,
          makeCutout: _makeCutout,
        ),
        cancel: cancel,
        onProgress: (d, t) {
          if (mounted) {
            setState(() {
              _done = d;
              _total = t;
            });
          }
        },
        onLog: (line) {
          if (mounted) setState(() => _log.add(line));
        },
      );
      if (!mounted) return;
      setState(() => _summary = summary);
      if (summary.ok > 0) _open(summary.indexPath);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String path) async {
    try {
      await Process.run('open', [path]);
    } catch (_) {}
  }

  Future<void> _reveal(String path) async {
    try {
      await Process.run('open', ['-R', path]);
    } catch (_) {}
  }

  // ───────────── build ─────────────

  @override
  Widget build(BuildContext context) {
    if (!SvgPaletteScreen.isSupported) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        appBar: AppBar(backgroundColor: Colors.black, title: const Text('Image to Animated SVG')),
        body: const Center(
          child: Text('This tool is only available on macOS.',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final canRun = !_busy && _vtracerOK && _files.isNotEmpty && (_makeBackground || _makeCutout);
    final outputShown = _outputParent ??
        (_folder == null ? '(choose a folder first)' : p.join(_folder!, 'output'));

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Image to Animated SVG'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Traces images into SVGs with 5 color groups, plus a gallery to recolor them '
                'with 752 palettes.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _chooseFolder,
                    icon: const Icon(Icons.create_new_folder),
                    label: const Text('Choose Folder'),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_busy || !_vtracerOK) ? null : _tryOne,
                    icon: const Icon(Icons.image),
                    label: const Text('Try One Image'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _folder = null;
                              _files = [];
                              _summary = null;
                              _error = null;
                            }),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_scanning) const LinearProgressIndicator(),
              if (_folder != null)
                _box(
                  null,
                  Text(
                    '${_files.length} ${_files.length == 1 ? 'image' : 'images'} in '
                    '${p.basename(_folder!)}',
                    style: const TextStyle(color: _green, fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 4),
              _box(
                'Variants',
                Column(children: [
                  _check('With background', _makeBackground,
                      (v) => _set(() => _makeBackground = v)),
                  _check('Background removed (Apple Vision)', _makeCutout,
                      (v) => _set(() => _makeCutout = v)),
                ]),
              ),
              _box(
                'Image',
                Column(children: [
                  _slider('Image size (px)', _size.toDouble(), 256, 2048, 28, '$_size',
                      'Longest side before tracing. Bigger = more detail and slower.',
                      (v) => _set(() => _size = v.round())),
                  _slider('Smoothing passes', _smooth.toDouble(), 0, 4, 4, '$_smooth',
                      'Median-filter passes before reducing colors. Removes JPEG noise; too many blurs detail.',
                      (v) => _set(() => _smooth = v.round())),
                ]),
              ),
              _box(
                'Tracing (vtracer)',
                Column(children: [
                  Row(
                    children: [
                      const Text('Shape layout:', style: TextStyle(color: Colors.white)),
                      Radio<bool>(
                          value: false,
                          groupValue: _stacked,
                          onChanged: _busy ? null : (v) => _set(() => _stacked = v!)),
                      const Text('seam-free mosaic', style: TextStyle(color: Colors.white70)),
                      Radio<bool>(
                          value: true,
                          groupValue: _stacked,
                          onChanged: _busy ? null : (v) => _set(() => _stacked = v!)),
                      const Text('stacked layers', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  _slider('Filter speckle', _speckle.toDouble(), 0, 128, 128, '$_speckle',
                      'Discard patches smaller than this many pixels (0–128).',
                      (v) => _set(() => _speckle = v.round())),
                  _slider('Simplify', _simplify, 0, 5, 50, _simplify.toStringAsFixed(1),
                      'Curve simplification tolerance in px. Higher = fewer nodes and smaller files, 0 = off. Try 1–2.5.',
                      (v) => _set(() => _simplify = (v * 10).round() / 10)),
                  _slider('Path precision', _pathPrecision.toDouble(), 0, 8, 8,
                      '$_pathPrecision', 'Decimal places in path coordinates. Lower = smaller files.',
                      (v) => _set(() => _pathPrecision = v.round())),
                  _check('Watershed regions (experimental)', _watershed,
                      (v) => _set(() => _watershed = v)),
                  if (_watershed)
                    _slider('Watershed detail', _watershedDetail.toDouble(), 0, 512, 64,
                        '$_watershedDetail', 'Higher = more regions.',
                        (v) => _set(() => _watershedDetail = (v / 8).round() * 8)),
                  _slider('Images in parallel', _jobs.toDouble(), 1, 8, 7, '$_jobs',
                      'Each image uses its own isolate and vtracer process.',
                      (v) => _set(() => _jobs = v.round())),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text('vtracer: $_vtracerInfo',
                            style: TextStyle(
                                color: _vtracerOK ? Colors.white54 : Colors.redAccent,
                                fontSize: 12),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ),
                      TextButton(
                          onPressed: _busy ? null : _checkVtracer, child: const Text('Re-check')),
                    ],
                  ),
                ]),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Output folder: $outputShown${_outputParent == null ? '  (auto)' : ''}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                      onPressed: _busy ? null : _pickOutput, child: const Text('Choose…')),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: canRun ? _generate : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CC1F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Generate SVG Gallery'),
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _cancel?.cancelled = true),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                    child: Text(_cancel?.cancelled == true
                        ? 'Stopping after the current images…'
                        : 'Cancel'),
                  ),
                ),
              if (_busy || _summary != null) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                    value: _total == 0 ? 0 : _done / _total, minHeight: 14),
                const SizedBox(height: 6),
                Text('$_done/$_total images',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (_busy && _done > 0)
                  Text(
                    '${(_done / (_sw.elapsedMilliseconds / 60000)).round()} img/min • '
                    '${_sw.elapsed.inSeconds}s elapsed',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              if (_log.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  height: 90,
                  decoration: BoxDecoration(
                      color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _log.length > 50 ? _log.sublist(_log.length - 50).join('\n') : _log.join('\n'),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              if (_summary != null) _buildSummary(_summary!),
              const SizedBox(height: 20),
              _buildInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(SvgPaletteSummary s) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x1A00FF26),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x4D00FF26)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.ok} SVGs from ${s.images} images in ${s.seconds}s',
                style: const TextStyle(color: _green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(s.runDir,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
              TextButton(onPressed: () => _open(s.indexPath), child: const Text('Open gallery')),
              TextButton(
                  onPressed: () => _reveal(s.indexPath), child: const Text('Show in Finder')),
            ]),
          ],
        ),
      );

  // ───────────── small widgets ─────────────

  Widget _box(String? title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title,
                  style: const TextStyle(
                      color: _green, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      );

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) => CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xFF00CC1F),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        value: value,
        onChanged: _busy ? null : (v) => onChanged(v ?? false),
      );

  Widget _slider(String title, double value, double min, double max, int divisions,
          String shown, String help, ValueChanged<double> onChanged) =>
      Tooltip(
        message: help,
        child: Row(
          children: [
            SizedBox(
              width: 170,
              child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            Expanded(
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                activeColor: const Color(0xFF00CC1F),
                onChanged: _busy ? null : onChanged,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(shown,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _buildInfo() {
    const bullets = [
      'Every image becomes an SVG whose shapes are grouped into 5 color slots, so a palette can recolor it.',
      'Two variants per image: with background, and background removed (Apple Vision, the same technology as Finder\'s Remove Background).',
      'Open any SVG in the gallery to try 752 palettes, shuffle and move colors, save favorites and export an animated SVG.',
      'SVG files keep their look: their colors are grouped into 5 slots and rewritten as var(--cN, original). The original file is used as the thumbnail.',
      'Gallery thumbnails are AVIF.',
      'Output goes to <folder>/output/<date_time>/ with index.html, pages/, th/ and palettes.js.',
    ];
    const style = TextStyle(color: Colors.white70, fontSize: 13);
    return _box(
      'What it does',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: style),
                  Expanded(child: Text(b, style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
