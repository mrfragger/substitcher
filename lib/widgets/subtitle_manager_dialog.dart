import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


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

  @override
  void initState() {
    super.initState();
    _primarySubtitle = widget.primarySubtitle;
    _secondarySubtitle = widget.secondarySubtitle;
    _loadLastVttShow();
  }

  Future<void> _loadLastVttShow() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastVttShowPath = prefs.getString('lastVttShowPath');
    });
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
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        child: Container(
          width: 800,
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _createNewVttShow(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New VttShow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
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
                    icon: const Icon(Icons.history, size: 16),
                    label: Text(
                      'Last: ${path.basename(_lastVttShowPath!)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Found ${widget.availableSubtitles.length} subtitle files',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'vttshow mode — press TAB to edit text',
                    style: TextStyle(color: Colors.orange, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PRIMARY
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'PRIMARY (Bottom)',
                            style: TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_primarySubtitle != null)
                          Container(
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
                                    path.basename(_primarySubtitle!),
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
                        else
                          Container(
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
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _browseForSubtitle(context, true),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Browse vtt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // SWAP / CLEAR BOTH
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      if (_primarySubtitle != null || _secondarySubtitle != null)
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red, size: 32),
                              onPressed: () {
                                setState(() {
                                  _primarySubtitle = null;
                                  _secondarySubtitle = null;
                                });
                                widget.onClearPrimary();
                                widget.onClearSecondary();
                              },
                              tooltip: 'Clear both',
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            final temp = _primarySubtitle;
                            _primarySubtitle = _secondarySubtitle;
                            _secondarySubtitle = temp;
                          });
                          widget.onSwap();
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
                    ],
                  ),

                  const SizedBox(width: 16),

                  // SECONDARY
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'SECONDARY (Top)',
                            style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_secondarySubtitle != null)
                          Container(
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
                                    path.basename(_secondarySubtitle!),
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
                        else
                          Container(
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
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _browseForSubtitle(context, false),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Browse vtt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Available Subtitles',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 16),
                  Tooltip(
                    message: 'Splits lines with characters over 160 (1/2) , 240 (1/3), 320 (1/4), 400 (1/5), 480 (1/6) and duration.',
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
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.availableSubtitles.length,
                    itemBuilder: (context, index) {
                      final subtitle = widget.availableSubtitles[index];
                      final fileName = path.basename(subtitle);
                      final isPrimary = subtitle == _primarySubtitle;
                      final isSecondary = subtitle == _secondarySubtitle;

                      return ListTile(
                        title: Text(
                          fileName,
                          style: TextStyle(
                            color: isPrimary ? Colors.blue :
                                   isSecondary ? Colors.orange :
                                   Colors.white,
                            fontWeight: isPrimary || isSecondary ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPrimary)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('PRIMARY', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                            if (isSecondary)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('SECONDARY', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ),
                            if (!isPrimary && !isSecondary) ...[
                              TextButton(
                                onPressed: () {
                                  setState(() => _primarySubtitle = subtitle);
                                  widget.onPrimarySelected(subtitle);
                                },
                                child: const Text('Primary'),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _secondarySubtitle = subtitle);
                                  widget.onSecondarySelected(subtitle);
                                },
                                child: const Text('Secondary'),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
