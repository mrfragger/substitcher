// lib/screens/avif_gallery_screen.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/avif_gallery_service.dart';

class AvifGalleryScreen extends StatefulWidget {
  /// Pre-selects a folder (e.g. the folder of the image currently shown in image mode).
  final String? initialFolder;
  const AvifGalleryScreen({super.key, this.initialFolder});

  @override
  State<AvifGalleryScreen> createState() => _AvifGalleryScreenState();
}

class _AvifGalleryScreenState extends State<AvifGalleryScreen> {
  final List<String> _folders = [];
  final List<String> _files = [];
  Map<String, List<File>> _galleries = {};
  String? _outputParent;
  String _titleOption = '1';
  static const int _quality = 50;
  static const int _speed = 8;
  bool _busy = false;
  bool _scanning = false;
  CancelToken? _cancel;
  GalleryProgress? _progress;
  GalleryStats? _stats;
  String? _error;
  final _sw = Stopwatch();

  @override
  void initState() {
    super.initState();
    if (widget.initialFolder != null) {
      _folders.add(widget.initialFolder!);
      _rescan();
    }
  }

  static String _safe(String s) => s
      .replaceAll(RegExp(r'[^a-zA-Z0-9._()-]'), '_')
      .replaceAll(RegExp(r'_{2,}'), '_');

  /// <parent of first source folder>/<foldername>_gallery  (or the first loose
  /// image's folder). Runs go inside it as avif_gallery_<timestamp>_<speed>.
  String? get _defaultOutputParent {
    if (_folders.isNotEmpty) {
      final f = _folders.first;
      return p.join(p.dirname(f), '${_safe(p.basename(f))}_gallery');
    }
    if (_files.isNotEmpty) {
      final d = p.dirname(_files.first);
      return p.join(p.dirname(d), '${_safe(p.basename(d))}_gallery');
    }
    return null;
  }

  int get _imageCount => _galleries.values.fold(0, (n, l) => n + l.length);

  Future<void> _rescan() async {
    setState(() => _scanning = true);
    final g = await collectGalleries(folders: _folders, looseFiles: _files);
    if (!mounted) return;
    setState(() {
      _galleries = g;
      _scanning = false;
    });
  }

  Future<void> _addFolder() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null || _folders.contains(dir)) return;
    _folders.add(dir);
    await _rescan();
  }

  Future<void> _addImages() async {
    // file_picker 13: pickFiles is already multi-select and returns a List
    // (empty when cancelled).
    final res = await FilePicker.pickFiles(
      type: FileType.any,
      dialogTitle: 'Select Images',
    );
    if (res.isEmpty) return;
    for (final f in res) {
      if (f.path != null && isGalleryImage(f.path!) && !_files.contains(f.path)) {
        _files.add(f.path!);
      }
    }
    await _rescan();
  }

  Future<void> _pickOutput() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) setState(() => _outputParent = dir);
  }

  Future<void> _generate() async {
    if (_galleries.isEmpty || _busy) return;
    final parent = _outputParent ?? _defaultOutputParent;
    if (parent == null) return;

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .substring(0, 19);
    final outDir = p.join(parent, 'avif_gallery_${ts}_$_speed');
    await Directory(outDir).create(recursive: true);

    setState(() {
      _busy = true;
      _stats = null;
      _error = null;
      _progress = GalleryProgress(0, _imageCount, 'Starting…');
      _cancel = CancelToken();
    });
    _sw
      ..reset()
      ..start();

    try {
      final stats = await generateAvifGalleries(
        galleries: _galleries,
        outputRoot: outDir,
        options: AvifGalleryOptions(
            quality: _quality, speed: _speed, titleOption: _titleOption),
        cancel: _cancel!,
        onProgress: (pr) {
          if (mounted) setState(() => _progress = pr);
        },
      );
      if (mounted && !_cancel!.cancelled) setState(() => _stats = stats);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (b < 1024 * 1024 * 1024) return '${(b / 1048576).toStringAsFixed(1)} MiB';
    return '${(b / 1073741824).toStringAsFixed(2)} GiB';
  }

  @override
  Widget build(BuildContext context) {
    final pr = _progress;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('avif Masonry Gallery Generator'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Writes an avif gallery folder straight to disk — no image-count limit.',
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
                      onPressed: _busy ? null : _addFolder,
                      icon: const Icon(Icons.create_new_folder),
                      label: const Text('Add Folder')),
                  ElevatedButton.icon(
                      onPressed: _busy ? null : _addImages,
                      icon: const Icon(Icons.image),
                      label: const Text('Add Images')),
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              _folders.clear();
                              _files.clear();
                              _rescan();
                            },
                      child: const Text('Clear')),
                ],
              ),
              const SizedBox(height: 12),
              if (_scanning) const LinearProgressIndicator(),
              if (_galleries.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_imageCount images in ${_galleries.length} ${_galleries.length == 1 ? 'gallery' : 'galleries'}',
                          style: const TextStyle(
                              color: Color(0xFF00FF26), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      for (final e in _galleries.entries.take(12))
                        Text('${e.key}  (${e.value.length})',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (_galleries.length > 12)
                        Text('… and ${_galleries.length - 12} more',
                            style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Image titles:', style: TextStyle(color: Colors.white)),
                  Radio<String>(
                      value: '1',
                      groupValue: _titleOption,
                      onChanged: _busy ? null : (v) => setState(() => _titleOption = v!)),
                  const Text('overlay', style: TextStyle(color: Colors.white70)),
                  Radio<String>(
                      value: '2',
                      groupValue: _titleOption,
                      onChanged: _busy ? null : (v) => setState(() => _titleOption = v!)),
                  const Text('below', style: TextStyle(color: Colors.white70)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Output folder: ${_outputParent ?? _defaultOutputParent ?? '(add images first)'}'
                      '${_outputParent == null ? '  (auto)' : ''}',
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
                onPressed: (_busy || _galleries.isEmpty) ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00CC1F),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Generate Masonry Gallery'),
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton(
                    onPressed: () => setState(() => _cancel?.cancelled = true),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
                    child: const Text('Cancel'),
                  ),
                ),
              if (pr != null && (_busy || _stats != null)) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                    value: pr.total == 0 ? 0 : pr.done / pr.total, minHeight: 14),
                const SizedBox(height: 6),
                Text('${pr.done}/${pr.total} • ${pr.label}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                if (_busy && pr.done > 0)
                  Text(
                    '${(pr.done / (_sw.elapsedMilliseconds / 60000)).round()} img/min • '
                    '${_sw.elapsed.inSeconds}s elapsed',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              if (_stats != null)
                Container(
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
                      Text(
                          '${_stats!.images} images • original ${_fmt(_stats!.originalBytes)}',
                          style: const TextStyle(color: Colors.white)),
                      Text(
                          '${_fmt(_stats!.convertedBytes)} converted • ${_stats!.reductionPercent}% reduction'
                          '${_stats!.smallerFactor > 0 ? ' • ${_stats!.smallerFactor.toStringAsFixed(1)}x smaller' : ''}',
                          style: const TextStyle(
                              color: Color(0xFF00FF26), fontWeight: FontWeight.bold)),
                      Text('Total time: ${_stats!.elapsed.inSeconds}s',
                          style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: Text(_stats!.outputDir,
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                overflow: TextOverflow.ellipsis)),
                        TextButton(
                            onPressed: () => _openFolder(_stats!.outputDir),
                            child: const Text('Open folder')),
                      ]),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              _buildInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Color(0xFF00FF26),
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _buildInfo() {
    const bullets = [
      "All images don't exceed 1280x1280 but stay proportional",
      'This extension prioritizes file size over speed. Your images will be 2-4x smaller than jpg usually.',
      'Best to keep image galleries under 20000 images even though they are lazy loaded.',
      'Process up to one million images at once.',
      "svg files don't need any conversion at all. Extremely fast as it just generates a gallery in html",
      'Random Slideshow',
    ];
    const rows = [
      ['3 separate folders', '3 galleries (folder names)'],
      ['1 folder with 3 subfolders', '3 galleries (subfolder names)'],
      ['1 folder with images only', '1 gallery (folder name)'],
      ['Multiple loose images', '1 gallery ("gallery")'],
    ];
    const style = TextStyle(color: Colors.white70, fontSize: 13);
    return Column(
      children: [
        _infoBox(
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
        ),
        _infoBox(
          'Gallery Organization',
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
            },
            children: [
              const TableRow(children: [
                Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('When You Drop',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
                Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('Result',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold))),
              ]),
              for (final r in rows)
                TableRow(children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(r[0], style: style)),
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(r[1], style: style)),
                ]),
            ],
          ),
        ),
      ],
    );
  }
}
