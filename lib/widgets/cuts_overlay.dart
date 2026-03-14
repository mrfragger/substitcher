import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;
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
  late List<String> _selectedCuts;
  int _selectedResolution = 720;
  VideoCodec _selectedFinalCodec = VideoCodec.x265;
  VideoCodec _selectedCutCodec = Platform.isMacOS
      ? VideoCodec.videotoolbox
      : VideoCodec.nvenc;
  int _selectedCrf = 28;
  AudioCodec _selectedAudioCodec = AudioCodec.opus;
  String _selectedAudioBitrate = '16k';
  int? _selectedFps;

  bool _filterBW = false;
  String? _filterCropRatio;
  bool _filterFlipH = false;
  bool _filterFlipV = false;

  Map<String, int> _fileSizes = {};
  Map<String, double> _fileDurations = {};
  bool _loadingMetadata = false;

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
    _loadFileMetadata();
  }

  @override
  void dispose() {
    _disposePreviewPlayer();
    super.dispose();
  }

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
      if (mounted) setState(() => _previewPosition = pos.inMilliseconds.toDouble());
    });

    player.stream.duration.listen((dur) {
      if (mounted) setState(() => _previewDuration = dur.inMilliseconds.toDouble());
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
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename', style: TextStyle(color: Colors.deepPurpleAccent)),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == currentName) return;

    final newPath = path.join(path.dirname(cutPath), '$newName$ext');
    try {
      await File(cutPath).rename(newPath);
      final idx = _selectedCuts.indexOf(cutPath);
      if (idx != -1) {
        setState(() {
          _selectedCuts[idx] = newPath;
          final size = _fileSizes.remove(cutPath);
          final dur = _fileDurations.remove(cutPath);
          if (size != null) _fileSizes[newPath] = size;
          if (dur != null) _fileDurations[newPath] = dur;
          if (_previewingCutPath == cutPath) _previewingCutPath = newPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rename failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadFileMetadata() async {
    setState(() => _loadingMetadata = true);
    for (final f in _selectedCuts) {
      try {
        _fileSizes[f] = File(f).lengthSync();
      } catch (_) {}
      final duration = await VideoEditService.getFileDuration(f);
      if (duration != null) {
        if (mounted) setState(() => _fileDurations[f] = duration);
      }
    }
    if (mounted) setState(() => _loadingMetadata = false);
  }

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

  String _formatMs(double ms) {
    return _formatDuration(ms / 1000);
  }

  double get _totalDuration => _fileDurations.values.fold(0.0, (sum, d) => sum + d);
  int get _totalSize => _fileSizes.values.fold(0, (sum, s) => sum + s);

  String? _buildVfFilter() {
    final filters = <String>[];
    if (_filterCropRatio != null) {
      filters.add(switch (_filterCropRatio!) {
        '16:9' => 'crop=in_h*16/9:in_h',
        '4:5'  => 'crop=in_h*4/5:in_h',
        '9:16' => 'crop=in_w:in_w*16/9',
        '4:3'  => 'crop=in_h*4/3:in_h',
        '1:1'  => 'crop=in_h:in_h',
        _      => '',
      });
    }
    if (_filterFlipH) filters.add('hflip');
    if (_filterFlipV) filters.add('vflip');
    if (_filterBW)    filters.add('format=gray');
    final joined = filters.where((f) => f.isNotEmpty).join(',');
    return joined.isEmpty ? null : joined;
  }

  Future<void> _deleteCut(String cutPath) async {
    if (_previewingCutPath == cutPath) await _stopPreview();
    try {
      await File(cutPath).delete();
      setState(() {
        _selectedCuts.remove(cutPath);
        _fileSizes.remove(cutPath);
        _fileDurations.remove(cutPath);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted: ${path.basename(cutPath)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
      ),
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
                child: CircularProgressIndicator(color: Colors.deepPurple, strokeWidth: 2),
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
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
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
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
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
                          icon: const Icon(Icons.stop, color: Colors.deepPurple, size: 22),
                          onPressed: _stopPreview,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Text(
                      _previewDuration > 0 ? _formatMs(_previewDuration) : '--',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
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

  Widget _buildCutEncoderSection() {
    final isMac = Platform.isMacOS;
    final codecs = isMac
        ? [VideoCodec.videotoolbox]
        : [VideoCodec.nvenc, VideoCodec.amf, VideoCodec.qsv];
    final tooltips = {
      VideoCodec.videotoolbox: 'Apple hardware encoder — always used on Mac',
      VideoCodec.nvenc: 'Nvidia GPU encoder',
      VideoCodec.amf: 'AMD GPU encoder',
      VideoCodec.qsv: 'Intel QuickSync encoder',
    };
    final labels = {
      VideoCodec.videotoolbox: 'VideoToolbox',
      VideoCodec.nvenc: 'NVENC',
      VideoCodec.amf: 'AMF',
      VideoCodec.qsv: 'QuickSync',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('CUTS ENCODER'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: codecs.map((codec) {
            final isSelected = codec == _selectedCutCodec;
            return Tooltip(
              message: tooltips[codec]!,
              child: ChoiceChip(
                label: Text(labels[codec]!),
                selected: isSelected,
                onSelected: isMac ? null : (selected) {
                  if (selected) {
                    setState(() => _selectedCutCodec = codec);
                    widget.onCutCodecChanged(codec);
                  }
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
        if (!isMac)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'If your GPU encoder fails, video editing is not supported on your system.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildResolutionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('OUTPUT RESOLUTION'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [720, 1080, 1440, 2160].map((res) {
            final isSelected = res == _selectedResolution;
            return Tooltip(
              message: switch (res) {
                720  => '720p HD',
                1080 => '1080p Full HD',
                1440 => '1440p 2K',
                2160 => '2160p 4K',
                _    => '',
              },
              child: ChoiceChip(
                label: Text('${res}p'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedResolution = res);
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFinalCodecSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('FINAL ENCODE CODEC'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            (VideoCodec.x265, 'x265', 'HEVC — smaller file sizes, slower encode (recommended)'),
            (VideoCodec.x264, 'x264', 'H.264 — larger files, faster encode, universal compatibility'),
          ].map((entry) {
            final (codec, label, tooltip) = entry;
            final isSelected = codec == _selectedFinalCodec;
            return Tooltip(
              message: tooltip,
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedFinalCodec = codec);
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCrfSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('CRF QUALITY'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            (28, 'Smaller file, lower quality'),
            (23, 'Balanced quality and size'),
            (18, 'High quality, larger file'),
          ].map((entry) {
            final (crf, tooltip) = entry;
            final isSelected = crf == _selectedCrf;
            return Tooltip(
              message: tooltip,
              child: ChoiceChip(
                label: Text('$crf'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCrf = crf);
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAudioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('AUDIO'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            (AudioCodec.opus, 'opus', 'opus — best quality per bitrate, ideal for speech'),
            (AudioCodec.aac, 'aac', 'aac — universal compatibility'),
          ].map((entry) {
            final (codec, label, tooltip) = entry;
            final isSelected = codec == _selectedAudioCodec;
            return Tooltip(
              message: tooltip,
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedAudioCodec = codec);
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('16k', 'Speech — smallest file size'),
            ('32k', 'Speech with high frequencies'),
            ('192k', 'High bitrate — YouTube/TikTok uploads'),
          ].map((entry) {
            final (bitrate, tooltip) = entry;
            final isSelected = bitrate == _selectedAudioBitrate;
            return Tooltip(
              message: tooltip,
              child: ChoiceChip(
                label: Text(bitrate),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedAudioBitrate = bitrate);
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFpsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('FPS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            (null, 'Source', 'Keep original FPS from source video'),
            (5, '5', 'Minimum FPS — smallest file, useful for speech-only with subs'),
            (24, '24', '24fps — cinematic'),
            (30, '30', '30fps — standard'),
            (60, '60', '60fps — sports'),
          ].map((entry) {
            final (fps, label, tooltip) = entry;
            final isSelected = fps == _selectedFps;
            return Tooltip(
              message: tooltip,
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _selectedFps = fps);
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBWSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('COLOR'),
        const SizedBox(height: 10),
        Tooltip(
          message: 'Converts output to grayscale (-vf format=gray)',
          child: ChoiceChip(
            label: const Text('B&W'),
            selected: _filterBW,
            onSelected: (selected) => setState(() => _filterBW = selected),
            selectedColor: Colors.deepPurple,
            backgroundColor: Colors.black45,
            labelStyle: TextStyle(
              color: _filterBW ? Colors.white : Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCropRatioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('CROP RATIO'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            (null,   'None',  'No crop — keep original dimensions'),
            ('16:9', '16:9',  'Landscape — YouTube, standard uploads'),
            ('4:5',  '4:5',   'Portrait feed — Instagram feed'),
            ('1:1',  '1:1',   'Square — Instagram feed, some TikTok styles'),
            ('9:16', '9:16',  'Vertical — TikTok, YouTube Shorts, Instagram Reels'),
            ('4:3',  '4:3',   'Classic — legacy format'),
          ].map((entry) {
            final (ratio, label, tooltip) = entry;
            final isSelected = ratio == _filterCropRatio;
            return Tooltip(
              message: tooltip,
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) setState(() => _filterCropRatio = ratio);
                },
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFlipSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('FLIP'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ('H', 'Flip Horizontal — mirrors left/right', _filterFlipH, () => setState(() => _filterFlipH = !_filterFlipH)),
            ('V', 'Flip Vertical — flips upside down',    _filterFlipV, () => setState(() => _filterFlipV = !_filterFlipV)),
          ].map((entry) {
            final (label, tooltip, isSelected, onTap) = entry;
            return Tooltip(
              message: tooltip,
              child: ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => onTap(),
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.black45,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.black87,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
               Row(
                 children: [
                   const Icon(Icons.movie_filter, color: Colors.deepPurple, size: 24),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         const Text(
                           'Video Cuts ',
                           style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                         ),
                         Text(
                           widget.cutsDirectory,
                           style: const TextStyle(color: Colors.white54, fontSize: 12),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ],
                     ),
                   ),
                   const Spacer(),
                   if (_loadingMetadata)
                     const Padding(
                       padding: EdgeInsets.only(right: 12),
                       child: SizedBox(
                         width: 14, height: 14,
                         child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38),
                       ),
                     ),
                   IconButton(
                     icon: const Icon(Icons.close, color: Colors.white70),
                     onPressed: widget.onClose,
                     tooltip: 'Close (ESC)',
                   ),
                 ],
               ),
               
                const SizedBox(height: 16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _selectedCuts.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No cuts available',
                                        style: TextStyle(color: Colors.white54, fontSize: 16),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: _selectedCuts.length,
                                      itemBuilder: (context, index) {
                                        final cutPath = _selectedCuts[index];
                                        final fileName = path.basename(cutPath);
                                        final isPreviewing = _previewingCutPath == cutPath;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isPreviewing ? Colors.deepPurple.withAlpha(40) : Colors.black26,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isPreviewing ? Colors.deepPurple : Colors.white12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
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
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  fileName,
                                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (_fileDurations[cutPath] != null || _fileSizes[cutPath] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: Text(
                                                    [
                                                      if (_fileDurations[cutPath] != null)
                                                        _formatDuration(_fileDurations[cutPath]!),
                                                      if (_fileSizes[cutPath] != null)
                                                        _formatSize(_fileSizes[cutPath]!),
                                                    ].join('  ·  '),
                                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                  ),
                                                ),
                                              IconButton(
                                                icon: Icon(
                                                  isPreviewing ? Icons.stop : Icons.play_arrow,
                                                  color: Colors.deepPurple,
                                                  size: 18,
                                                ),
                                                onPressed: () {
                                                  if (isPreviewing) {
                                                    _stopPreview();
                                                  } else {
                                                    _startPreview(cutPath);
                                                  }
                                                },
                                                tooltip: isPreviewing ? 'Stop preview' : 'Preview',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.drive_file_rename_outline,
                                                    color: Colors.white54, size: 18),
                                                onPressed: () => _renameCut(cutPath),
                                                tooltip: 'Rename',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.white54, size: 18),
                                                onPressed: () => _deleteCut(cutPath),
                                                tooltip: 'Delete this cut',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                visualDensity: VisualDensity.compact,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                            if (_previewingCutPath != null) ...[
                              const SizedBox(height: 12),
                              _buildMiniPlayer(),
                            ],
                            if (_selectedCuts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_selectedCuts.length} cuts',
                                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                                    ),
                                    if (_totalDuration > 0) ...[
                                      const Text('  ·  ', style: TextStyle(color: Colors.white24, fontSize: 12)),
                                      Text(
                                        _formatDuration(_totalDuration),
                                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    ],
                                    if (_totalSize > 0) ...[
                                      const Text('  ·  ', style: TextStyle(color: Colors.white24, fontSize: 12)),
                                      Text(
                                        _formatSize(_totalSize),
                                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCutEncoderSection(),
                                    const SizedBox(height: 20),
                                    _buildResolutionSection(),
                                    const SizedBox(height: 20),
                                    _buildFinalCodecSection(),
                                    const SizedBox(height: 20),
                                    _buildCrfSection(),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAudioSection(),
                                    const SizedBox(height: 20),
                                    _buildFpsSection(),
                                    const SizedBox(height: 20),
                                    _buildCropRatioSection(),
                                    const SizedBox(height: 20),
                                    _buildBWSection(),
                                    const SizedBox(height: 20),
                                    _buildFlipSection(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onOpenDirectory,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Open Cuts Directory'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => widget.onCombine([widget.sourceVideoPath], _buildEncodeSettings()),
                      icon: const Icon(Icons.compress, size: 18),
                      label: const Text('Encode Whole Current Video'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _selectedCuts.isEmpty
                          ? null
                          : () => widget.onCombine(_selectedCuts, _buildEncodeSettings()),
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}