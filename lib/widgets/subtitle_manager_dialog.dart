import 'dart:io';
import '../quran/quran_index.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class SubtitleManagerDialog extends StatefulWidget {
  final List<String> availableSubtitles;
  final String? primarySubtitle;
  final String? secondarySubtitle;
  final String? currentAudiobookPath;
  final Function(String) onPrimarySelected;
  final Function(String) onSecondarySelected;
  final VoidCallback onSwap;
  final VoidCallback onClearPrimary;
  final VoidCallback onClearSecondary;
  final Function(String)? onVttShowCreated;

  const SubtitleManagerDialog({
    super.key,
    required this.availableSubtitles,
    required this.primarySubtitle,
    required this.secondarySubtitle,
    this.currentAudiobookPath,
    required this.onPrimarySelected,
    required this.onSecondarySelected,
    required this.onSwap,
    required this.onClearPrimary,
    required this.onClearSecondary,
    this.onVttShowCreated,
  });

  @override
  State<SubtitleManagerDialog> createState() => _SubtitleManagerDialogState();
}

class _SubtitleManagerDialogState extends State<SubtitleManagerDialog> {
  late String? _primarySubtitle;
  late String? _secondarySubtitle;
  String? _lastVttShowPath;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final ItemScrollController _subtitleScrollController = ItemScrollController();

  @override
  void initState() {
    super.initState();
    _primarySubtitle = widget.primarySubtitle;
    _secondarySubtitle = widget.secondarySubtitle;
    _loadLastVttShow();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_primarySubtitle != null) _scrollToSubtitle(_primarySubtitle!);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLastVttShow() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastVttShowPath = prefs.getString('lastVttShowPath');
    });
  }

  bool get _isQuranVerseByVerse =>
      isQuranVerseByVersePath(widget.currentAudiobookPath);

  List<String> _filteredSubtitles() {
    if (_searchQuery.isEmpty) return widget.availableSubtitles;

    return widget.availableSubtitles.where((sub) {
      final segments = sub.split(RegExp(r'[/\\]'));

      final searchSegments = _isQuranVerseByVerse
          ? segments.sublist(0, segments.length - 1)
          : segments;

      return searchSegments.any((segment) => segment.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  void _scrollToSubtitle(String subtitlePath) {
    final filtered = _filteredSubtitles();
    final index = filtered.indexOf(subtitlePath);
    if (index == -1 || !_subtitleScrollController.isAttached) return;

    _subtitleScrollController.scrollTo(
      index: index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.3,
    );
  }

  Future<void> _browseForSubtitle(BuildContext context, bool isPrimary) async {
    String? initialDirectory;

    if (widget.currentAudiobookPath != null) {
      final audiobookDir = path.dirname(widget.currentAudiobookPath!);
      final audiobookBase = path.basenameWithoutExtension(widget.currentAudiobookPath!);
      final vttDir = path.join(audiobookDir, '${audiobookBase}_vtt');

      if (await Directory(vttDir).exists()) {
        initialDirectory = vttDir;
      } else {
        initialDirectory = audiobookDir;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      dialogTitle: 'Select Subtitle File',
      initialDirectory: initialDirectory,
    );

    if (result == null || result.files.isEmpty) return;

    var subtitlePath = result.files.first.path!;

    if (subtitlePath.contains('_vttshow')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastVttShowPath', subtitlePath);
    }

    try {
      if (path.extension(subtitlePath).toLowerCase() == '.srt') {
        final vttPath = subtitlePath.replaceAll(RegExp(r'\.srt$', caseSensitive: false), '.vtt');

        if (!await File(vttPath).exists()) {
          final srtContent = await File(subtitlePath).readAsString();
          final vttContent = _convertSrtToVtt(srtContent);
          await File(vttPath).writeAsString(vttContent);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Converted SRT to VTT: ${path.basename(vttPath)}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
        subtitlePath = vttPath;
      }

      if (isPrimary) {
        setState(() => _primarySubtitle = subtitlePath);
        widget.onPrimarySelected(subtitlePath);
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSubtitle(subtitlePath));
      } else {
        setState(() => _secondarySubtitle = subtitlePath);
        widget.onSecondarySelected(subtitlePath);
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load subtitle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadVttShow(String filePath) {
    setState(() {
      _primarySubtitle = filePath;
      _secondarySubtitle = null;
    });
    if (widget.onVttShowCreated != null) {
      widget.onVttShowCreated!(filePath);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSubtitle(filePath));
  }

  String _convertSrtToVtt(String srtContent) {
    final lines = srtContent.split('\n');
    final vttLines = <String>['WEBVTT', ''];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        vttLines.add(line.replaceAll(',', '.'));
      } else if (line.isEmpty || RegExp(r'^\d+$').hasMatch(line)) {
        if (line.isEmpty && vttLines.last.isNotEmpty) {
          vttLines.add('');
        }
      } else {
        vttLines.add(line);
      }
    }
    return vttLines.join('\n');
  }

  Future<void> _createNewVttShow(BuildContext context) async {
    String? initialDirectory;
    String suggestedName = 'presentation_vttshow.vtt';
    if (widget.currentAudiobookPath != null) {
      initialDirectory = path.dirname(widget.currentAudiobookPath!);
      final base = path.basenameWithoutExtension(widget.currentAudiobookPath!);
      suggestedName = '${base}_vttshow.vtt';
    }
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'New VttShow File',
      fileName: suggestedName,
      allowedExtensions: ['vtt'],
      type: FileType.custom,
      initialDirectory: initialDirectory,
    );
    if (savePath == null) return;
    final finalPath = savePath.endsWith('_vttshow.vtt')
        ? savePath
        : savePath.replaceAll(RegExp(r'\.vtt$'), '_vttshow.vtt');

    const template = 'WEBVTT\n\n'
        '00:00:00.000 --> 00:00:10.000\n'
        'New slide\n\n'
        'VTTSHOW\n'
        '00:00:00.000 --> 00:00:10.000 {},{},{},{},{},{},{},{}\n';

    await File(finalPath).writeAsString(template);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastVttShowPath', finalPath);

    _loadVttShow(finalPath);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created: ${path.basename(finalPath)}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _splitLongSubs(BuildContext context) async {
    final sourcePath = _primarySubtitle;
    if (sourcePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No primary subtitle selected to split'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final content = await File(sourcePath).readAsString();
      final lines = content.split('\n');
      final output = <String>[];
      int splitCount = 0;
      int i = 0;

      while (i < lines.length) {
        final line = lines[i];

        if (line.contains('-->')) {
          final parts = line.split('-->');
          final startMs = _parseTimestamp(parts[0].trim());
          final endMs = _parseTimestamp(parts[1].trim());

          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i]);
            i++;
          }

          final text = textLines.join(' ');
          final clean = text.replaceAll(RegExp(r'<[^>]+>'), '');
          final isLatin = !RegExp(r'[\u0600-\u06FF\u3040-\u9FFF\uAC00-\uD7AF]').hasMatch(clean);

          if (clean.length > 480 && isLatin) {
            final sixth = clean.length ~/ 6;
            int s1 = _findWordBoundary(clean, sixth);
            int s2 = _findWordBoundary(clean, sixth * 2);
            int s3 = _findWordBoundary(clean, sixth * 3);
            int s4 = _findWordBoundary(clean, sixth * 4);
            int s5 = _findWordBoundary(clean, sixth * 5);
            final p1 = clean.substring(0, s1).trim();
            final p2 = clean.substring(s1, s2).trim();
            final p3 = clean.substring(s2, s3).trim();
            final p4 = clean.substring(s3, s4).trim();
            final p5 = clean.substring(s4, s5).trim();
            final p6 = clean.substring(s5).trim();
            final dur = endMs - startMs;
            final m1 = startMs + dur ~/ 6;
            final m2 = startMs + dur * 2 ~/ 6;
            final m3 = startMs + dur * 3 ~/ 6;
            final m4 = startMs + dur * 4 ~/ 6;
            final m5 = startMs + dur * 5 ~/ 6;
            output.add('${_formatTimestamp(startMs)} --> ${_formatTimestamp(m1)}'); output.add(p1); output.add('');
            output.add('${_formatTimestamp(m1)} --> ${_formatTimestamp(m2)}'); output.add(p2); output.add('');
            output.add('${_formatTimestamp(m2)} --> ${_formatTimestamp(m3)}'); output.add(p3); output.add('');
            output.add('${_formatTimestamp(m3)} --> ${_formatTimestamp(m4)}'); output.add(p4); output.add('');
            output.add('${_formatTimestamp(m4)} --> ${_formatTimestamp(m5)}'); output.add(p5); output.add('');
            output.add('${_formatTimestamp(m5)} --> ${_formatTimestamp(endMs)}'); output.add(p6); output.add('');
            splitCount++;
          } else if (clean.length > 400 && isLatin) {
            final fifth = clean.length ~/ 5;
            int s1 = _findWordBoundary(clean, fifth);
            int s2 = _findWordBoundary(clean, fifth * 2);
            int s3 = _findWordBoundary(clean, fifth * 3);
            int s4 = _findWordBoundary(clean, fifth * 4);
            final p1 = clean.substring(0, s1).trim();
            final p2 = clean.substring(s1, s2).trim();
            final p3 = clean.substring(s2, s3).trim();
            final p4 = clean.substring(s3, s4).trim();
            final p5 = clean.substring(s4).trim();
            final dur = endMs - startMs;
            final m1 = startMs + dur ~/ 5;
            final m2 = startMs + dur * 2 ~/ 5;
            final m3 = startMs + dur * 3 ~/ 5;
            final m4 = startMs + dur * 4 ~/ 5;
            output.add('${_formatTimestamp(startMs)} --> ${_formatTimestamp(m1)}'); output.add(p1); output.add('');
            output.add('${_formatTimestamp(m1)} --> ${_formatTimestamp(m2)}'); output.add(p2); output.add('');
            output.add('${_formatTimestamp(m2)} --> ${_formatTimestamp(m3)}'); output.add(p3); output.add('');
            output.add('${_formatTimestamp(m3)} --> ${_formatTimestamp(m4)}'); output.add(p4); output.add('');
            output.add('${_formatTimestamp(m4)} --> ${_formatTimestamp(endMs)}'); output.add(p5); output.add('');
            splitCount++;
          } else if (clean.length > 320 && isLatin) {
            final quarter = clean.length ~/ 4;
            int s1 = _findWordBoundary(clean, quarter);
            int s2 = _findWordBoundary(clean, clean.length ~/ 2);
            int s3 = _findWordBoundary(clean, quarter * 3);

            final p1 = clean.substring(0, s1).trim();
            final p2 = clean.substring(s1, s2).trim();
            final p3 = clean.substring(s2, s3).trim();
            final p4 = clean.substring(s3).trim();

            final dur = endMs - startMs;
            final m1 = startMs + dur ~/ 4;
            final m2 = startMs + dur ~/ 2;
            final m3 = startMs + dur * 3 ~/ 4;

            output.add('${_formatTimestamp(startMs)} --> ${_formatTimestamp(m1)}'); output.add(p1); output.add('');
            output.add('${_formatTimestamp(m1)} --> ${_formatTimestamp(m2)}'); output.add(p2); output.add('');
            output.add('${_formatTimestamp(m2)} --> ${_formatTimestamp(m3)}'); output.add(p3); output.add('');
            output.add('${_formatTimestamp(m3)} --> ${_formatTimestamp(endMs)}'); output.add(p4); output.add('');
            splitCount++;

          } else if (clean.length > 240 && isLatin) {
            int s1 = _findWordBoundary(clean, clean.length ~/ 3);
            int s2 = _findWordBoundary(clean, clean.length * 2 ~/ 3);

            final p1 = clean.substring(0, s1).trim();
            final p2 = clean.substring(s1, s2).trim();
            final p3 = clean.substring(s2).trim();

            final dur = endMs - startMs;
            final m1 = startMs + dur ~/ 3;
            final m2 = startMs + dur * 2 ~/ 3;

            output.add('${_formatTimestamp(startMs)} --> ${_formatTimestamp(m1)}'); output.add(p1); output.add('');
            output.add('${_formatTimestamp(m1)} --> ${_formatTimestamp(m2)}'); output.add(p2); output.add('');
            output.add('${_formatTimestamp(m2)} --> ${_formatTimestamp(endMs)}'); output.add(p3); output.add('');
            splitCount++;

          } else if (clean.length > 160 && isLatin) {
            int s1 = _findWordBoundary(clean, clean.length ~/ 2);

            final p1 = clean.substring(0, s1).trim();
            final p2 = clean.substring(s1).trim();

            final midMs = startMs + (endMs - startMs) ~/ 2;

            output.add('${_formatTimestamp(startMs)} --> ${_formatTimestamp(midMs)}'); output.add(p1); output.add('');
            output.add('${_formatTimestamp(midMs)} --> ${_formatTimestamp(endMs)}'); output.add(p2); output.add('');
            splitCount++;

          } else {
            output.add(line);
            for (final t in textLines) output.add(t);
            output.add('');
          }
        } else {
          output.add(line);
          i++;
        }
      }

      final base = path.basenameWithoutExtension(sourcePath);
      final dir = path.dirname(sourcePath);
      final outputPath = path.join(dir, '${base}_split.vtt');
      final result = output.join('\n');
      final cleaned = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');
      await File(outputPath).writeAsString(cleaned);

      setState(() => _primarySubtitle = outputPath);
      widget.onPrimarySelected(outputPath);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSubtitle(outputPath));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Split $splitCount cues → ${path.basename(outputPath)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _displayPath(String fullPath) {
    final parts = fullPath.split(Platform.pathSeparator);
    if (parts.length >= 2) {
      return '${parts[parts.length - 2]}/${parts.last}';
    }
    return parts.last;
  }


  int _findWordBoundary(String text, int pos) {
    for (int j = 0; j < 50; j++) {
      if (pos + j < text.length && text[pos + j] == ' ') return pos + j;
      if (pos - j >= 0 && text[pos - j] == ' ') return pos - j;
    }
    return pos;
  }

  int _parseTimestamp(String ts) {
    final parts = ts.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final sParts = parts[2].split('.');
    final s = int.parse(sParts[0]);
    final ms = int.parse(sParts[1]);
    return h * 3600000 + m * 60000 + s * 1000 + ms;
  }

  String _formatTimestamp(int ms) {
    final h = ms ~/ 3600000; ms %= 3600000;
    final m = ms ~/ 60000; ms %= 60000;
    final s = ms ~/ 1000; ms %= 1000;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}.${ms.toString().padLeft(3,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyX) {
          setState(() {
            final temp = _primarySubtitle;
            _primarySubtitle = _secondarySubtitle;
            _secondarySubtitle = temp;
          });
          widget.onSwap();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.slash) {
          _searchFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Container(
          width: 960,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Subtitle Manager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: () => _createNewVttShow(context),
                    icon: const Icon(Icons.add, size: 13),
                    label: const Text('New vttShow'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.withValues(alpha: 0.85),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (_lastVttShowPath != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (!await File(_lastVttShowPath!).exists()) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Last vttshow file no longer exists'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                          return;
                        }
                        _loadVttShow(_lastVttShowPath!);
                      },
                      icon: const Icon(Icons.history, size: 13),
                      label: Text(
                        'Last: ${path.basename(_lastVttShowPath!)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        foregroundColor: Colors.white70,
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Found ${widget.availableSubtitles.length} subtitle files',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'vttshow mode — press TAB to edit text',
                    style: TextStyle(color: Colors.orange.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Header row: labels, browse buttons, clear-both
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Primary (Bottom)',
                      style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _browseForSubtitle(context, true),
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: const Text('Browse vtt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const Spacer(),
                  if (_primarySubtitle != null || _secondarySubtitle != null)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _primarySubtitle = null;
                          _secondarySubtitle = null;
                        });
                        widget.onClearPrimary();
                        widget.onClearSecondary();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.85),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('Clear both subs'),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Secondary (Top)',
                      style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _browseForSubtitle(context, false),
                    icon: const Icon(Icons.folder_open, size: 14),
                    label: const Text('Browse vtt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Content row: subtitle boxes + swap button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // PRIMARY box
                  Expanded(
                    child: _primarySubtitle != null
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue, width: 2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayPath(_primarySubtitle!),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() => _primarySubtitle = null);
                                    widget.onClearPrimary();
                                  },
                                  tooltip: 'Clear primary',
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              'No primary subtitle selected',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ),
                  ),

                  const SizedBox(width: 16),

                  // SWAP
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final temp = _primarySubtitle;
                        _primarySubtitle = _secondarySubtitle;
                        _secondarySubtitle = temp;
                      });
                      widget.onSwap();
                      if (_primarySubtitle != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSubtitle(_primarySubtitle!));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Column(
                      children: [
                        Text('Swap Primary ⇅'),
                        Text('Secondary (x)'),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // SECONDARY box
                  Expanded(
                    child: _secondarySubtitle != null
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange, width: 2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayPath(_secondarySubtitle!),
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() => _secondarySubtitle = null);
                                    widget.onClearSecondary();
                                  },
                                  tooltip: 'Clear secondary',
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Text(
                              'No secondary subtitle selected',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    _searchQuery.isEmpty
                        ? 'Available Subtitles (${widget.availableSubtitles.length})'
                        : 'Available Subtitles (${_filteredSubtitles().length} of ${widget.availableSubtitles.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Tooltip(
                    message: 'Splits lines with characters over 160 (1/2), 240 (1/3), 320 (1/4), 400 (1/5), 480 (1/6) and duration.',
                    child: ElevatedButton.icon(
                      onPressed: _primarySubtitle != null ? () => _splitLongSubs(context) : null,
                      icon: const Icon(Icons.call_split, size: 16),
                      label: const Text('Split Long Subs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      autofocus: false,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '/ Search language…',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white38),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim().toLowerCase());
                        if (_subtitleScrollController.isAttached) {
                          _subtitleScrollController.jumpTo(index: 0);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final filtered = _filteredSubtitles();

                  return Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: filtered.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'No subtitles match',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ),
                            )
                          : ScrollablePositionedList.builder(
                              itemScrollController: _subtitleScrollController,
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final subtitle = filtered[index];
                                final parts = subtitle.split(Platform.pathSeparator);
                                final displayName = parts.length >= 2
                                    ? '${parts[parts.length - 2]} / ${parts.last}'
                                    : parts.last;
                                final isPrimary = subtitle == _primarySubtitle;
                                final isSecondary = subtitle == _secondarySubtitle;

                                return Container(
                                  color: isPrimary
                                      ? Colors.blue.withValues(alpha: 0.15)
                                      : isSecondary
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : (index.isEven
                                              ? Colors.white.withValues(alpha: 0.03)
                                              : Colors.transparent),
                                  child: ListTile(
                                    dense: true,
                                    visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    title: Text(
                                      displayName,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: isPrimary
                                            ? Colors.blue
                                            : isSecondary
                                                ? Colors.orange
                                                : Colors.white70,
                                        fontWeight: isPrimary || isSecondary
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPrimary)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Primary',
                                                style: TextStyle(color: Colors.white, fontSize: 9)),
                                          ),
                                        if (isSecondary)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('Secondary',
                                                style: TextStyle(color: Colors.white, fontSize: 9)),
                                          ),
                                        if (!isPrimary && !isSecondary) ...[
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              textStyle: const TextStyle(fontSize: 11),
                                            ),
                                            onPressed: () {
                                              setState(() => _primarySubtitle = subtitle);
                                              widget.onPrimarySelected(subtitle);
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) => _scrollToSubtitle(subtitle));
                                            },
                                            child: const Text('Primary'),
                                          ),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              textStyle: const TextStyle(fontSize: 11),
                                            ),
                                            onPressed: () {
                                              setState(() => _secondarySubtitle = subtitle);
                                              widget.onSecondarySelected(subtitle);
                                            },
                                            child: const Text('Secondary'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
