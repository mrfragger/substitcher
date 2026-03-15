import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'dart:io';

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
  });

  @override
  State<SubtitleManagerDialog> createState() => _SubtitleManagerDialogState();
}

class _SubtitleManagerDialogState extends State<SubtitleManagerDialog> {
  late String? _primarySubtitle;
  late String? _secondarySubtitle;

  @override
  void initState() {
    super.initState();
    _primarySubtitle = widget.primarySubtitle;
    _secondarySubtitle = widget.secondarySubtitle;
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
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Found ${widget.availableSubtitles.length} subtitle files',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
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
              const Text(
                'Available Subtitles',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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