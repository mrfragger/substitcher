import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class SubtitleManagerDialog extends StatelessWidget {
  final List<String> availableSubtitles;
  final String? primarySubtitle;
  final String? secondarySubtitle;
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
    required this.onPrimarySelected,
    required this.onSecondarySelected,
    required this.onSwap,
    required this.onClearPrimary,
    required this.onClearSecondary,
  });

  Future<void> _browseForSubtitle(BuildContext context, bool isPrimary) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      dialogTitle: 'Select Subtitle File',
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
        onPrimarySelected(subtitlePath);
      } else {
        onSecondarySelected(subtitlePath);
      }
      
    } catch (e) {
      print('Error loading subtitle: $e');
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
        final convertedLine = line.replaceAll(',', '.');
        vttLines.add(convertedLine);
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
    return Dialog(
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
              'Found ${availableSubtitles.length} subtitle files',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (primarySubtitle != null)
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
                                  path.basename(primarySubtitle!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                onPressed: onClearPrimary,
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
                            border: Border.all(color: Colors.white24, width: 1),
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
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    if (primarySubtitle != null || secondarySubtitle != null)
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 32),
                            onPressed: () {
                              onClearPrimary();
                              onClearSecondary();
                            },
                            tooltip: 'Clear both',
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ElevatedButton(
                      onPressed: onSwap,
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
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (secondarySubtitle != null)
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
                                  path.basename(secondarySubtitle!),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                                onPressed: onClearSecondary,
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
                            border: Border.all(color: Colors.white24, width: 1),
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
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
                  itemCount: availableSubtitles.length,
                  itemBuilder: (context, index) {
                    final subtitle = availableSubtitles[index];
                    final fileName = path.basename(subtitle);
                    final isPrimary = subtitle == primarySubtitle;
                    final isSecondary = subtitle == secondarySubtitle;
                    
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
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          if (isSecondary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SECONDARY',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          if (!isPrimary && !isSecondary) ...[
                            TextButton(
                              onPressed: () => onPrimarySelected(subtitle),
                              child: const Text('Primary'),
                            ),
                            TextButton(
                              onPressed: () => onSecondarySelected(subtitle),
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
    );
  }
}