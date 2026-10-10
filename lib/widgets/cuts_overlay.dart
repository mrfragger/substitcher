import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../services/video_edit_service.dart';

class CutsOverlay extends StatefulWidget {
  final String cutsDirectory;
  final String sourceVideoPath;
  final List<String> cutFiles;
  final Function(List<String>, EncodeSettings) onCombine;
  final Function(VideoCodec) onCutCodecChanged;
  final VoidCallback onOpenDirectory;
  final VoidCallback onClose;

  const CutsOverlay({
    super.key,
    required this.cutsDirectory,
    required this.sourceVideoPath,
    required this.cutFiles,
    required this.onCombine,
    required this.onCutCodecChanged,
    required this.onOpenDirectory,
    required this.onClose,
  });

  @override
  State<CutsOverlay> createState() => _CutsOverlayState();
}

class _CutsOverlayState extends State<CutsOverlay> {
  // Order of this list is the order cuts are combined in.
  late List<String> _selectedCuts;

  int _selectedResolution = 720;
  VideoCodec _selectedFinalCodec = VideoCodec.x265;
  VideoCodec _selectedCutCodec =
      Platform.isMacOS ? VideoCodec.videotoolbox : VideoCodec.nvenc;
  int _selectedCrf = 28;
  AudioCodec _selectedAudioCodec = AudioCodec.opus;
  String _selectedAudioBitrate = '16k';
  int? _selectedFps;

  bool _filterBW = false;
  String? _filterCropRatio;
  bool _filterFlipH = false;
  bool _filterFlipV = false;

  final Map<String, int> _fileSizes = {};
  final Map<String, double> _fileDurations = {};
  final Map<String, String> _thumbs = {};
  bool _loadingMetadata = false;

  final ScrollController _scroll = ScrollController();
  final GlobalKey _gridKey = GlobalKey();
  final ValueNotifier<String?> _hovered = ValueNotifier<String?>(null);

  String? _previewingCutPath;
  Player? _previewPlayer;
  VideoController? _previewController;
  bool _previewPlaying = false;
  double _previewPosition = 0.0;
  double _previewDuration = 0.0;
  bool _previewInitializing = false;

  @override
  void initState() {
    super.initState();
    _selectedCuts = List.from(widget.cutFiles);
    _loadFileMetadata().then((_) => _loadThumbnails());
  }

  @override
  void dispose() {
    _disposePreviewPlayer();
    _scroll.dispose();
    _hovered.dispose();
    super.dispose();
  }

  // ───────────────────────── metadata + thumbnails ─────────────────────────

  Future<void> _loadFileMetadata() async {
    setState(() => _loadingMetadata = true);
    for (final f in List<String>.from(_selectedCuts)) {
      if (!mounted) return;
      try {
        _fileSizes[f] = File(f).lengthSync();
      } catch (_) {}
      final duration = await VideoEditService.getFileDuration(f);
      if (duration != null && mounted) {
        setState(() => _fileDurations[f] = duration);
      }
    }
    if (mounted) setState(() => _loadingMetadata = false);
  }

  Future<void> _loadThumbnails() async {
    if (!mounted) return;
    final ffmpeg = await VideoEditService.findSystemFfmpeg();
    if (ffmpeg == null) return;
    final tmp = await getTemporaryDirectory();
    final dir = Directory(path.join(tmp.path, 'cut_thumbs'));
    await dir.create(recursive: true);

    setState(() => _loadingMetadata = true);
    for (final f in List<String>.from(_selectedCuts)) {
      if (!mounted) return;
      if (_thumbs.containsKey(f)) continue;
      final thumb = await _makeThumbnail(f, ffmpeg, dir);
      if (thumb != null && mounted) {
        setState(() => _thumbs[f] = thumb);
      }
    }
    if (mounted) setState(() => _loadingMetadata = false);
  }

  Future<String?> _makeThumbnail(
      String cutPath, String ffmpeg, Directory cacheDir) async {
    try {
      final stat = File(cutPath).statSync();
      final key = md5
          .convert(utf8.encode(
              '${cutPath}_${stat.size}_${stat.modified.millisecondsSinceEpoch}'))
          .toString();
      final out = path.join(cacheDir.path, '$key.jpg');
      if (File(out).existsSync()) return out;

      final dur = _fileDurations[cutPath] ?? 0.0;
      final seek = dur > 1 ? dur * 0.25 : 0.0;
      final r = await Process.run(ffmpeg, [
        '-hide_banner',
        '-loglevel', 'error',
        '-ss', seek.toStringAsFixed(3),
        '-i', cutPath,
        '-frames:v', '1',
        '-vf', 'scale=480:-2',
        '-q:v', '4',
        '-y',
        out,
      ]);
      if (r.exitCode != 0 || !File(out).existsSync()) return null;
      return out;
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────────── preview player ─────────────────────────────

  Future<void> _disposePreviewPlayer() async {
    await _previewPlayer?.stop();
    await _previewPlayer?.dispose();
    _previewPlayer = null;
    _previewController = null;
  }

  Future<void> _startPreview(String cutPath) async {
    if (_previewInitializing) return;
    setState(() => _previewInitializing = true);

    await _disposePreviewPlayer();

    final player = Player();
    final controller = VideoController(player);

    player.stream.playing.listen((playing) {
      if (mounted) setState(() => _previewPlaying = playing);
    });
    player.stream.position.listen((pos) {
      if (mounted) {
        setState(() => _previewPosition = pos.inMilliseconds.toDouble());
      }
    });
    player.stream.duration.listen((dur) {
      if (mounted) {
        setState(() => _previewDuration = dur.inMilliseconds.toDouble());
      }
    });

    await player.open(Media(cutPath), play: false);

    if (mounted) {
      setState(() {
        _previewPlayer = player;
        _previewController = controller;
        _previewingCutPath = cutPath;
        _previewPosition = 0.0;
        _previewDuration = (_fileDurations[cutPath] ?? 0.0) * 1000;
        _previewInitializing = false;
      });
    }
  }

  Future<void> _stopPreview() async {
    await _previewPlayer?.stop();
    await _disposePreviewPlayer();
    if (mounted) {
      setState(() {
        _previewingCutPath = null;
        _previewPlaying = false;
        _previewPosition = 0.0;
        _previewDuration = 0.0;
      });
    }
  }

  // ───────────────────────── rename / delete / reorder ─────────────────────────

  Future<void> _renameCut(String cutPath) async {
    final currentName = path.basenameWithoutExtension(cutPath);
    final ext = path.extension(cutPath);
    final controller = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Rename Cut', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            suffixText: ext,
            suffixStyle: const TextStyle(color: Colors.white54),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.deepPurple),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.deepPurpleAccent),
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename',
                style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    final newPath = path.join(path.dirname(cutPath), '$newName$ext');
    try {
      await File(cutPath).rename(newPath);
      final idx = _selectedCuts.indexOf(cutPath);
      if (idx != -1 && mounted) {
        setState(() {
          _selectedCuts[idx] = newPath;
          final size = _fileSizes.remove(cutPath);
          final dur = _fileDurations.remove(cutPath);
          final thumb = _thumbs.remove(cutPath);
          if (size != null) _fileSizes[newPath] = size;
          if (dur != null) _fileDurations[newPath] = dur;
          if (thumb != null) _thumbs[newPath] = thumb;
          if (_previewingCutPath == cutPath) _previewingCutPath = newPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Rename failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDelete(String cutPath) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete cut?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${path.basename(cutPath)} will be permanently deleted from disk.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteCut(cutPath);
  }

  Future<void> _deleteCut(String cutPath) async {
    if (_previewingCutPath == cutPath) await _stopPreview();
    try {
      await File(cutPath).delete();
      if (!mounted) return;
      setState(() {
        _selectedCuts.remove(cutPath);
        _fileSizes.remove(cutPath);
        _fileDurations.remove(cutPath);
        _thumbs.remove(cutPath);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted: ${path.basename(cutPath)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  /// The dragged cut takes the target's slot; the cuts in between shift over.
  void _moveCut(String from, int toIndex) {
    final fromIndex = _selectedCuts.indexOf(from);
    if (fromIndex == -1 || fromIndex == toIndex) return;
    setState(() {
      final item = _selectedCuts.removeAt(fromIndex);
      _selectedCuts.insert(toIndex, item);
    });
  }

  void _autoScrollWhileDragging(Offset globalPos) {
    final box = _gridKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final local = box.globalToLocal(globalPos);
    const edge = 60.0;
    double delta = 0;
    if (local.dy < edge) {
      delta = -16;
    } else if (local.dy > box.size.height - edge) {
      delta = 16;
    }
    if (delta == 0) return;
    final target = (_scroll.offset + delta)
        .clamp(0.0, _scroll.position.maxScrollExtent)
        .toDouble();
    _scroll.jumpTo(target);
  }

  // ─────────────────────────────── formatting ───────────────────────────────

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(double secs) {
    final d = Duration(milliseconds: (secs * 1000).round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String _formatMs(double ms) => _formatDuration(ms / 1000);

  double get _totalDuration =>
      _selectedCuts.fold(0.0, (sum, f) => sum + (_fileDurations[f] ?? 0.0));
  int get _totalSize =>
      _selectedCuts.fold(0, (sum, f) => sum + (_fileSizes[f] ?? 0));

  // ─────────────────────────────── encode settings ───────────────────────────────

  String? _buildVfFilter() {
    final filters = <String>[];
    if (_filterCropRatio != null) {
      filters.add(switch (_filterCropRatio!) {
        '16:9' => 'crop=in_h*16/9:in_h',
        '4:5' => 'crop=in_h*4/5:in_h',
        '9:16' => 'crop=in_w:in_w*16/9',
        '4:3' => 'crop=in_h*4/3:in_h',
        '1:1' => 'crop=in_h:in_h',
        _ => '',
      });
    }
    if (_filterFlipH) filters.add('hflip');
    if (_filterFlipV) filters.add('vflip');
    if (_filterBW) filters.add('format=gray');
    final joined = filters.where((f) => f.isNotEmpty).join(',');
    return joined.isEmpty ? null : joined;
  }

  EncodeSettings _buildEncodeSettings() => EncodeSettings(
        mode: EncodeMode.encodeVideo,
        codec: _selectedFinalCodec,
        resolution: _selectedResolution,
        crf: _selectedCrf,
        container: 'mp4',
        audioCodec: _selectedAudioCodec,
        audioBitrate: _selectedAudioBitrate,
        fps: _selectedFps,
        vfFilter: _buildVfFilter(),
      );

  // ───────────────────────────── option dropdowns ─────────────────────────────

  Widget _optionsRow(List<Widget> children) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      );

  Widget _buildOptionsPanel() {
    final isMac = Platform.isMacOS;
    final cutCodecs = isMac
        ? [VideoCodec.videotoolbox]
        : [VideoCodec.nvenc, VideoCodec.amf, VideoCodec.qsv];
    const cutLabels = {
      VideoCodec.videotoolbox: 'VideoToolbox',
      VideoCodec.nvenc: 'NVENC',
      VideoCodec.amf: 'AMF',
      VideoCodec.qsv: 'QuickSync',
    };

    final flipValue = _filterFlipH && _filterFlipV
        ? 'both'
        : _filterFlipH
            ? 'h'
            : _filterFlipV
                ? 'v'
                : 'none';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Row 1 — video
          _optionsRow([
            _OptionDropdown<VideoCodec>(
              label: 'CUTS ENCODER',
              value: _selectedCutCodec,
              items: <(VideoCodec, String)>[
                for (final c in cutCodecs) (c, cutLabels[c]!),
              ],
              onChanged: isMac
                  ? null
                  : (c) {
                      setState(() => _selectedCutCodec = c);
                      widget.onCutCodecChanged(c);
                    },
            ),
            _OptionDropdown<int>(
              label: 'OUTPUT RESOLUTION',
              value: _selectedResolution,
              items: const <(int, String)>[
                (720, '720p HD'),
                (1080, '1080p Full HD'),
                (1440, '1440p 2K'),
                (2160, '2160p 4K'),
              ],
              onChanged: (v) => setState(() => _selectedResolution = v),
            ),
            _OptionDropdown<VideoCodec>(
              label: 'FINAL ENCODE CODEC',
              value: _selectedFinalCodec,
              items: const <(VideoCodec, String)>[
                (VideoCodec.x265, 'x265 · smaller files'),
                (VideoCodec.x264, 'x264 · most compatible'),
              ],
              onChanged: (v) => setState(() => _selectedFinalCodec = v),
            ),
            _OptionDropdown<int>(
              label: 'CRF QUALITY',
              value: _selectedCrf,
              items: const <(int, String)>[
                (28, '28 · smaller file'),
                (23, '23 · balanced'),
                (18, '18 · high quality'),
              ],
              onChanged: (v) => setState(() => _selectedCrf = v),
            ),
            _OptionDropdown<int>(
              label: 'FPS',
              value: _selectedFps ?? 0,
              items: const <(int, String)>[
                (0, 'Source'),
                (5, '5'),
                (24, '24'),
                (30, '30'),
                (60, '60'),
              ],
              onChanged: (v) =>
                  setState(() => _selectedFps = v == 0 ? null : v),
            ),
          ]),
          const SizedBox(height: 12),
          // Row 2 — audio + look
          _optionsRow([
            _OptionDropdown<AudioCodec>(
              label: 'AUDIO CODEC',
              value: _selectedAudioCodec,
              items: const <(AudioCodec, String)>[
                (AudioCodec.opus, 'opus · best for speech'),
                (AudioCodec.aac, 'aac · compatible'),
              ],
              onChanged: (v) => setState(() => _selectedAudioCodec = v),
            ),
            _OptionDropdown<String>(
              label: 'AUDIO BITRATE',
              value: _selectedAudioBitrate,
              items: const <(String, String)>[
                ('16k', '16k · speech, smallest'),
                ('32k', '32k · speech + highs'),
                ('192k', '192k · uploads'),
              ],
              onChanged: (v) => setState(() => _selectedAudioBitrate = v),
            ),
            _OptionDropdown<String>(
              label: 'CROP RATIO',
              value: _filterCropRatio ?? 'none',
              items: const <(String, String)>[
                ('none', 'None'),
                ('16:9', '16:9 · landscape'),
                ('4:5', '4:5 · portrait feed'),
                ('1:1', '1:1 · square'),
                ('9:16', '9:16 · vertical'),
                ('4:3', '4:3 · classic'),
              ],
              onChanged: (v) =>
                  setState(() => _filterCropRatio = v == 'none' ? null : v),
            ),
            _OptionDropdown<String>(
              label: 'COLOR',
              value: _filterBW ? 'bw' : 'color',
              items: const <(String, String)>[
                ('color', 'Normal'),
                ('bw', 'B&W'),
              ],
              onChanged: (v) => setState(() => _filterBW = v == 'bw'),
            ),
            _OptionDropdown<String>(
              label: 'FLIP',
              value: flipValue,
              items: const <(String, String)>[
                ('none', 'None'),
                ('h', 'Horizontal'),
                ('v', 'Vertical'),
                ('both', 'Both'),
              ],
              onChanged: (v) => setState(() {
                _filterFlipH = v == 'h' || v == 'both';
                _filterFlipV = v == 'v' || v == 'both';
              }),
            ),
          ]),
        ],
      ),
    );
  }

  // ─────────────────────────────── cut grid ───────────────────────────────

  Widget _cellAction(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
      ),
    );
  }

  Widget _thumbBox(String cutPath, int index, {bool showActions = true}) {
    final thumb = _thumbs[cutPath];
    final isPreviewing = _previewingCutPath == cutPath;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPreviewing ? Colors.deepPurpleAccent : Colors.white12,
            width: isPreviewing ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null)
              Image.file(
                File(thumb),
                fit: BoxFit.contain,
                cacheWidth: 480,
                gaplessPlayback: true,
              )
            else
              const Center(
                child: Icon(Icons.movie, color: Colors.white24, size: 32),
              ),
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                width: 26,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            if (showActions)
              Positioned(
                top: 4,
                right: 4,
                child: ValueListenableBuilder<String?>(
                  valueListenable: _hovered,
                  builder: (_, hovered, __) {
                    final show = hovered == cutPath || isPreviewing;
                    return AnimatedOpacity(
                      opacity: show ? 1 : 0,
                      duration: const Duration(milliseconds: 120),
                      child: IgnorePointer(
                        ignoring: !show,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _cellAction(
                              isPreviewing ? Icons.stop : Icons.play_arrow,
                              isPreviewing ? 'Stop preview' : 'Preview',
                              () => isPreviewing
                                  ? _stopPreview()
                                  : _startPreview(cutPath),
                            ),
                            const SizedBox(width: 4),
                            _cellAction(Icons.drive_file_rename_outline,
                                'Rename', () => _renameCut(cutPath)),
                            const SizedBox(width: 4),
                            _cellAction(Icons.delete, 'Delete this cut',
                                () => _confirmDelete(cutPath)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCutCell(int index, String cutPath, double width) {
    final dur = _fileDurations[cutPath];
    final size = _fileSizes[cutPath];
    final meta = [
      if (dur != null) _formatDuration(dur),
      if (size != null) _formatSize(size),
    ].join('  ·  ');

    final content = MouseRegion(
      onEnter: (_) => _hovered.value = cutPath,
      onExit: (_) {
        if (_hovered.value == cutPath) _hovered.value = null;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _thumbBox(cutPath, index),
          const SizedBox(height: 5),
          Text(
            path.basename(cutPath),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            meta.isEmpty ? ' ' : meta,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != cutPath,
      onAcceptWithDetails: (d) => _moveCut(d.data, index),
      builder: (context, candidate, _) {
        final hot = candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: width,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: hot ? Colors.deepPurple.withAlpha(50) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hot ? Colors.deepPurpleAccent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Draggable<String>(
            data: cutPath,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragUpdate: (d) => _autoScrollWhileDragging(d.globalPosition),
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.9,
                child: SizedBox(
                  width: 200,
                  child: _thumbBox(cutPath, index, showActions: false),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: content),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildGrid() {
    if (_selectedCuts.isEmpty) {
      return const Center(
        child: Text(
          'No cuts available',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            const scrollbarSpace = 14.0;
            final usable = constraints.maxWidth - scrollbarSpace;
            final cols = (usable / 240).floor().clamp(2, 8);
            final cellW = (usable - (cols - 1) * gap) / cols;

            return Scrollbar(
              key: _gridKey,
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.only(right: scrollbarSpace),
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < _selectedCuts.length; i++)
                      _buildCutCell(i, _selectedCuts[i], cellW),
                  ],
                ),
              ),
            );
          },
        ),
        if (_previewingCutPath != null)
          Positioned(
            right: 16,
            bottom: 8,
            width: 380,
            child: _buildMiniPlayer(),
          ),
      ],
    );
  }

  Widget _buildMiniPlayer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.deepPurple, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  path.basename(_previewingCutPath!),
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                onPressed: _stopPreview,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (_previewInitializing)
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                    color: Colors.deepPurple, strokeWidth: 2),
              ),
            )
          else if (_previewController != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(controller: _previewController!),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.deepPurple,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.deepPurpleAccent,
                    overlayColor: Colors.deepPurple.withAlpha(60),
                  ),
                  child: Slider(
                    value: _previewDuration > 0
                        ? _previewPosition.clamp(0, _previewDuration)
                        : 0,
                    min: 0,
                    max: _previewDuration > 0 ? _previewDuration : 1,
                    onChanged: (v) {
                      _previewPlayer?.seek(Duration(milliseconds: v.round()));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatMs(_previewPosition),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _previewPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.deepPurple,
                            size: 22,
                          ),
                          onPressed: () {
                            if (_previewPlaying) {
                              _previewPlayer?.pause();
                            } else {
                              _previewPlayer?.play();
                            }
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.stop,
                              color: Colors.deepPurple, size: 22),
                          onPressed: _stopPreview,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text(
                      _previewDuration > 0 ? _formatMs(_previewDuration) : '--',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────── build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.movie_filter,
                    color: Colors.deepPurple, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Video Cuts',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.cutsDirectory,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_loadingMetadata)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white38),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: widget.onClose,
                  tooltip: 'Close (ESC)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildOptionsPanel(),
            const SizedBox(height: 12),
            Expanded(child: _buildGrid()),
            const SizedBox(height: 12),
            Row(
              children: [
                if (_selectedCuts.isNotEmpty) ...[
                  Text(
                    '${_selectedCuts.length} cuts',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  if (_totalDuration > 0) ...[
                    const Text('  ·  ',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                    Text(
                      _formatDuration(_totalDuration),
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                  if (_totalSize > 0) ...[
                    const Text('  ·  ',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
                    Text(
                      _formatSize(_totalSize),
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                  const Text('  ·  ',
                      style: TextStyle(color: Colors.white24, fontSize: 12)),
                  const Text(
                    'Drag cuts to reorder',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: widget.onOpenDirectory,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: const Text('Open Cuts Directory'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => widget.onCombine(
                      [widget.sourceVideoPath], _buildEncodeSettings()),
                  icon: const Icon(Icons.compress, size: 18),
                  label: const Text('Encode Whole Current Video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _selectedCuts.isEmpty
                      ? null
                      : () => widget.onCombine(
                          List<String>.from(_selectedCuts),
                          _buildEncodeSettings()),
                  icon: const Icon(Icons.merge, size: 20),
                  label: Text(
                    _selectedCuts.isEmpty
                        ? 'No cuts to combine'
                        : 'Combine ${_selectedCuts.length} Cut${_selectedCuts.length == 1 ? '' : 's'}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact labeled dropdown used for every encode option.
class _OptionDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> items;

  /// Null disables the dropdown (e.g. the Mac-only VideoToolbox encoder).
  final ValueChanged<T>? onChanged;

  const _OptionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: enabled ? Colors.deepPurple : Colors.white12,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              isDense: true,
              value: value,
              dropdownColor: const Color(0xFF1E1E1E),
              iconEnabledColor: Colors.white70,
              iconDisabledColor: Colors.white24,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white54,
                fontSize: 12,
              ),
              items: [
                for (final (v, text) in items)
                  DropdownMenuItem<T>(
                    value: v,
                    child: Text(text, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: enabled
                  ? (v) {
                      if (v != null) onChanged!(v);
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
