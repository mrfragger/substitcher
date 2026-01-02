import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import '../services/ffmpeg_service.dart';
import '../models/audiobook_metadata.dart';

class AudiobookMetadataEdit {
  String author;
  String title;
  String? year;
  List<Chapter> chapters;

  AudiobookMetadataEdit({
    required this.author,
    required this.title,
    this.year,
    required this.chapters,
  });
}

class MetadataEditorScreen extends StatefulWidget {
  const MetadataEditorScreen({super.key});

  @override
  State<MetadataEditorScreen> createState() => _MetadataEditorScreenState();
}

class _MetadataEditorScreenState extends State<MetadataEditorScreen> {
  final FFmpegService _ffmpeg = FFmpegService();
  
  String? _currentFilePath;
  AudiobookMetadataEdit? _metadata;
  bool _loading = false;
  bool _saving = false;
  
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  
  String _originalAuthor = '';
  String _originalTitle = '';
  List<String> _originalChapterTitles = [];
  
  String _debugInfo = '';

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadAudiobook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['opus', 'm4a', 'm4b'],
      dialogTitle: 'Select Audiobook',
    );
    
    if (result == null || result.files.isEmpty) return;
    
    final filePath = result.files.first.path!;
    
    setState(() {
      _loading = true;
      _currentFilePath = filePath;
      _debugInfo = '';
    });
    
    try {
      final metadata = await _extractMetadata(filePath);
      
      setState(() {
        _metadata = metadata;
        _originalAuthor = metadata.author;
        _originalTitle = metadata.title;
        _originalChapterTitles = metadata.chapters.map((c) => c.title).toList();
        _authorController.text = metadata.author;
        _titleController.text = metadata.title;
        _yearController.text = metadata.year ?? '';
        _loading = false;
      });
      
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load metadata: $e');
    }
  }

  Future<AudiobookMetadataEdit> _extractMetadata(String filePath) async {
    final metadataResult = await Process.run('ffprobe', [
      filePath,
    ]);
    
    if (metadataResult.exitCode != 0 && metadataResult.stderr.toString().isEmpty) {
      throw Exception('Failed to extract metadata');
    }
    
    final output = metadataResult.stderr as String;
    
    setState(() {
      _debugInfo = 'RAW FFPROBE OUTPUT:\n$output\n\n';
    });
    
    String artist = 'Unknown Artist';
    String albumArtist = 'Unknown Artist';
    String album = 'Unknown Album';
    String title = 'Unknown Album';
    String? year;
    
    final lines = output.split('\n');
    bool inMetadata = false;
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.startsWith('Metadata:')) {
        inMetadata = true;
        continue;
      }
      
      if (trimmed.startsWith('Stream #')) {
        inMetadata = false;
        continue;
      }
      
      if (inMetadata && trimmed.contains(':')) {
        final parts = trimmed.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim().toLowerCase();
          final value = parts.sublist(1).join(':').trim();
          
          if (value.isEmpty) continue;
          
          if (key == 'artist') {
            artist = value;
          } else if (key == 'album artist') {
            albumArtist = value;
          } else if (key == 'album') {
            album = value;
          } else if (key == 'title') {
            title = value;
          } else if (key == 'year' || key == 'date') {
            year = value;
          }
        }
      }
    }
    
    if (albumArtist == 'Unknown Artist' && artist != 'Unknown Artist') {
      albumArtist = artist;
    }
    
    if (artist == 'Unknown Artist' && albumArtist != 'Unknown Artist') {
      artist = albumArtist;
    }
    
    final finalAuthor = artist != 'Unknown Artist' ? artist : albumArtist;
    final finalTitle = album != 'Unknown Album' ? album : title;
    
    setState(() {
      _debugInfo += 'FOUND METADATA:\n';
      _debugInfo += '  Artist: $artist\n';
      _debugInfo += '  Album Artist: $albumArtist\n';
      _debugInfo += '  Album: $album\n';
      _debugInfo += '  Title: $title\n';
      _debugInfo += '  Year: ${year ?? 'not found'}\n';
      _debugInfo += '\nFINAL PARSED VALUES:\n';
      _debugInfo += '  Author (will be used): $finalAuthor\n';
      _debugInfo += '  Title (will be used): $finalTitle\n';
      _debugInfo += '  Year: ${year ?? 'not found'}\n';
    });
    
    print(_debugInfo);
    
    final chapters = await _extractChapters(filePath);
    
    return AudiobookMetadataEdit(
      author: finalAuthor,
      title: finalTitle,
      year: year,
      chapters: chapters,
    );
  }

  String? _findTag(Map<String, dynamic> tags, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (tags.containsKey(key) && tags[key] != null && tags[key].toString().isNotEmpty) {
        return tags[key].toString();
      }
    }
    return null;
  }

  Future<List<Chapter>> _extractChapters(String filePath) async {
    final tempFile = '${Directory.systemTemp.path}/temp_ffmetadata.txt';
    
    final result = await Process.run('ffmpeg', [
      '-i', filePath,
      '-f', 'ffmetadata',
      '-y',
      tempFile,
    ]);
    
    if (result.exitCode != 0) {
      return [];
    }
    
    final content = await File(tempFile).readAsString();
    await File(tempFile).delete();
    
    return _parseChaptersFromMetadata(content);
  }

  List<Chapter> _parseChaptersFromMetadata(String content) {
    final chapters = <Chapter>[];
    final lines = content.split('\n');
    
    int chapterIndex = 0;
    int? startMs;
    int? endMs;
    String? title;
    
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line == '[CHAPTER]') {
        if (startMs != null && endMs != null && title != null) {
          final startTime = Duration(milliseconds: startMs);
          final endTime = Duration(milliseconds: endMs);
          final duration = endTime - startTime;
          
          chapters.add(Chapter(
            index: chapterIndex,
            title: title,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
          ));
          chapterIndex++;
        }
        startMs = null;
        endMs = null;
        title = null;
        continue;
      }
      
      if (line.startsWith('TIMEBASE=')) continue;
      if (line.startsWith('START=')) {
        startMs = int.tryParse(line.substring(6));
      } else if (line.startsWith('END=')) {
        endMs = int.tryParse(line.substring(4));
      } else if (line.toUpperCase().startsWith('TITLE=')) {
        title = line.substring(6);
      }
    }
    
    if (startMs != null && endMs != null && title != null) {
      final startTime = Duration(milliseconds: startMs);
      final endTime = Duration(milliseconds: endMs);
      final duration = endTime - startTime;
      
      chapters.add(Chapter(
        index: chapterIndex,
        title: title,
        startTime: startTime,
        endTime: endTime,
        duration: duration,
      ));
    }
    
    return chapters;
  }

  String _titleCaseString(String text) {
    final smallWords = RegExp(r'^(a|an|and|as|at|but|by|en|for|if|in|nor|of|on|or|per|the|to|up|v\.?|vs\.?|via|with)$', caseSensitive: false);
    
    final parts = <String>[];
    final regex = RegExp(r'(\S+|\s+)');
    for (final match in regex.allMatches(text)) {
      parts.add(match.group(0)!);
    }
    
    final nonWhitespace = parts.where((p) => p.trim().isNotEmpty).toList();
    
    return parts.map((part) {
      if (part.trim().isEmpty) return part;
      
      final word = part;
      final isFirstWord = word == nonWhitespace.first;
      final isLastWord = word == nonWhitespace.last;
      
      if (RegExp(r'^[Aa][dlnstrz]-').hasMatch(word)) {
        final prefix = word.substring(0, 3);
        final rest = word.substring(3);
        if (rest.isNotEmpty) {
          return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase() + 
                 rest[0].toUpperCase() + rest.substring(1).toLowerCase();
        }
        return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
      }
      
      if (word.contains('(')) {
        return word.split('').asMap().entries.map((e) {
          if (e.value == '(' && e.key + 1 < word.length) return e.value;
          if (e.key > 0 && word[e.key - 1] == '(') return e.value.toUpperCase();
          return e.value.toLowerCase();
        }).join('');
      }
      
      if (isFirstWord || isLastWord) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      
      if (smallWords.hasMatch(word)) {
        return word.toLowerCase();
      }
      
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join('');
  }

  void _applyTitleCase() {
    setState(() {
      _authorController.text = _titleCaseString(_authorController.text);
      _titleController.text = _titleCaseString(_titleController.text);
      
      if (_metadata != null) {
        _metadata!.chapters = _metadata!.chapters.map((chapter) {
          return Chapter(
            index: chapter.index,
            title: _titleCaseString(chapter.title),
            startTime: chapter.startTime,
            endTime: chapter.endTime,
            duration: chapter.duration,
          );
        }).toList();
      }
    });
  }

  Future<void> _saveMetadata() async {
    if (_currentFilePath == null || _metadata == null) return;
    
    setState(() {
      _saving = true;
    });
    
    try {
      final metadataContent = _createFFMetadataContent();
      final tempMetadataFile = '${Directory.systemTemp.path}/editing_metadata.txt';
      
      print('SAVE PROCESS STARTED\n');
      print('Created metadata content:\n$metadataContent\n');
      
      await File(tempMetadataFile).writeAsString(metadataContent);
      
      print('Wrote metadata to: $tempMetadataFile\n');
      
      final ext = path.extension(_currentFilePath!).toLowerCase();
      final tempOutputFile = '${Directory.systemTemp.path}/temp_no_metadata$ext';
      
      print('Step 1: Stripping original metadata...');
      
      final stripResult = await Process.run('ffmpeg', [
        '-i', _currentFilePath!,
        '-map_metadata', '-1',
        '-map_chapters', '-1',
        '-c:a', 'copy',
        '-c:v', 'copy',
        '-v', 'warning',
        '-y',
        tempOutputFile,
      ]);
      
      print('Strip result: exit code ${stripResult.exitCode}');
      if (stripResult.stderr.toString().isNotEmpty) {
        print('Strip stderr: ${stripResult.stderr}');
      }
      
      if (stripResult.exitCode != 0) {
        throw Exception('Failed to strip metadata: ${stripResult.stderr}');
      }
      
      print('Step 2: Applying new metadata...');
      
      final applyResult = await Process.run('ffmpeg', [
        '-i', tempOutputFile,
        '-i', tempMetadataFile,
        '-map', '0',
        '-map_metadata', '1',
        '-map_chapters', '1',
        '-c', 'copy',
        '-v', 'warning',
        '-y',
        _currentFilePath!,
      ]);
      
      print('Apply result: exit code ${applyResult.exitCode}');
      if (applyResult.stderr.toString().isNotEmpty) {
        print('Apply stderr: ${applyResult.stderr}');
      }
      
      await File(tempOutputFile).delete();
      await File(tempMetadataFile).delete();
      
      if (applyResult.exitCode == 0) {
        setState(() {
          _saving = false;
        });
        print('SUCCESS: Metadata saved successfully!');
        _showSuccess('Metadata saved successfully!');
      } else {
        throw Exception('Failed to apply metadata: ${applyResult.stderr}');
      }
      
    } catch (e) {
      setState(() {
        _saving = false;
      });
      print('ERROR: $e');
      _showError('Failed to save metadata: $e');
    }
  }
  
  String _createFFMetadataContent() {
    final buffer = StringBuffer();
    
    buffer.writeln(';FFMETADATA1');
    
    buffer.writeln('Artist=${_authorController.text}');
    buffer.writeln('Album Artist=${_authorController.text}');
    buffer.writeln('Album=${_titleController.text}');
    buffer.writeln('Title=${_titleController.text}');
    
    if (_yearController.text.isNotEmpty) {
      buffer.writeln('Year=${_yearController.text}');
    }
    
    if (_currentFilePath!.toLowerCase().endsWith('.opus')) {
      const base64Png = 'AAAAAwAAAAlpbWFnZS9wbmcAAAALRnJvbnQgQ292ZXIAAAAQAAAACQAAACAAAAAAAAAAU4lQTkcNChoKAAAADUlIRFIAAAAQAAAACQgGAAAAOyqsMgAAABpJREFUeJxjZGBg+M9AAWCiRPOoARAwDAwAAFmzARHg40/fAAAAAElFTkSuQmCC';
      buffer.writeln('\nMETADATA_BLOCK_PICTURE=$base64Png');
    }
    
    buffer.writeln();
    
    if (_metadata!.chapters.isNotEmpty) {
      for (final chapter in _metadata!.chapters) {
        buffer.writeln('[CHAPTER]');
        buffer.writeln('TIMEBASE=1/1000');
        buffer.writeln('START=${chapter.startTime.inMilliseconds}');
        buffer.writeln('END=${chapter.endTime.inMilliseconds}');
        buffer.writeln('title=${chapter.title}');
        buffer.writeln();
      }
    }
    
    return buffer.toString();
  }

  Future<void> _addBlack16x9Cover() async {
    if (_currentFilePath == null) return;
    
    setState(() => _saving = true);
    
    try {
      final baseName = path.basenameWithoutExtension(_currentFilePath!);
      final dir = path.dirname(_currentFilePath!);
      final ext = path.extension(_currentFilePath!);
      
      String outputPath = path.join(dir, '${baseName}_black16x9cover$ext');
      
      int counter = 1;
      while (await File(outputPath).exists()) {
        outputPath = path.join(dir, '${baseName}_black16x9cover_$counter$ext');
        counter++;
      }
      
      const base64_16x9_black = 'AAAAAwAAAAlpbWFnZS9wbmcAAAALRnJvbnQgQ292ZXIAAAAQAAAACQAAACAAAAAAAAAAU4lQTkcNChoKAAAADUlIRFIAAAAQAAAACQgGAAAAOyqsMgAAABpJREFUeJxjZGBg+M9AAWCiRPOoARAwDAwAAFmzARHg40/fAAAAAElFTkSuQmCC';
      
      final result = await Process.run('ffmpeg', [
        '-i', _currentFilePath!,
        '-metadata:s:a', 'METADATA_BLOCK_PICTURE=$base64_16x9_black',
        '-c', 'copy',
        '-v', 'quiet',
        '-y',
        outputPath,
      ]);
      
      setState(() => _saving = false);
      
      if (result.exitCode == 0) {
        _showSuccess('Created file with 16:9 black cover:\n${path.basename(outputPath)}');
      } else {
        throw Exception('FFmpeg failed');
      }
      
    } catch (e) {
      setState(() => _saving = false);
      _showError('Failed to add cover: $e');
    }
  }

  void _editChapterTitle(int index) {
    final controller = TextEditingController(
      text: _metadata!.chapters[index].title,
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Chapter ${index + 1}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Chapter Title',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                final chapter = _metadata!.chapters[index];
                _metadata!.chapters[index] = Chapter(
                  index: chapter.index,
                  title: controller.text,
                  startTime: chapter.startTime,
                  endTime: chapter.endTime,
                  duration: chapter.duration,
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildTitleWithHighlights(String displayText, String originalText) {
    if (displayText == originalText) {
      return Text(
        displayText,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }
    
    final spans = <InlineSpan>[];
    
    for (int i = 0; i < displayText.length; i++) {
      final char = displayText[i];
      final isChanged = i < originalText.length && 
                       char != originalText[i] &&
                       char.toLowerCase() == originalText[i].toLowerCase();
      
      spans.add(TextSpan(
        text: char,
        style: TextStyle(
          fontSize: 14,
          color: isChanged ? Colors.green : Colors.white,
          fontWeight: isChanged ? FontWeight.bold : null,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_metadata != null) _buildMetadataHeader(),
                
                Expanded(
                  child: _metadata == null
                      ? _buildEmptyState()
                      : _buildChapterList(),
                ),
                
                _buildActionButtons(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.edit_note, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'No audiobook loaded',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              const SizedBox(height: 8),
              const Text(
                'Click "Load Audiobook" to edit metadata',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close, color: Colors.white),
            iconSize: 32,
            tooltip: 'Close',
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24)),
        color: Color(0xFF1E1E1E),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  path.basename(_currentFilePath!),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _applyTitleCase,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Apply Title Case'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close, color: Colors.white),
                iconSize: 32,
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Author (Artist & Album Artist)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _authorController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Title (Album & Title)',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Year',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _yearController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.text,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChapterList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _metadata!.chapters.length,
      itemBuilder: (context, index) {
        final chapter = _metadata!.chapters[index];
        final originalTitle = index < _originalChapterTitles.length 
            ? _originalChapterTitles[index] 
            : chapter.title;
        
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF006064),
            radius: 16,
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: _buildTitleWithHighlights(chapter.title, originalTitle),
              ),
              Text(
                _formatDuration(chapter.duration),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          subtitle: Text(
            'Start: ${_formatDuration(chapter.startTime)}',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          onTap: () => _editChapterTitle(index),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _loadAudiobook,
              icon: const Icon(Icons.folder_open),
              label: const Text('Load Audiobook'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (_metadata != null) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveMetadata,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Metadata'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _addBlack16x9Cover,
                icon: const Icon(Icons.image),
                label: const Text('Add 16:9 Black Cover'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyMetadataToClipboard() async {
    if (_currentFilePath == null) {
      _showError('No audiobook loaded');
      return;
    }
    
    try {
      final author = _authorController.text.isNotEmpty 
          ? _authorController.text 
          : 'Unknown Artist';
      final title = _titleController.text.isNotEmpty 
          ? _titleController.text 
          : 'Unknown Title';
      final year = _yearController.text.isNotEmpty 
          ? _yearController.text 
          : 'Unknown Year';
      
      final file = File(_currentFilePath!);
      final fileSize = await file.length();
      final formattedFileSize = _formatFileSize(fileSize);
      
      final metadataResult = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        _currentFilePath!,
      ]);
      
      Duration duration = Duration.zero;
      if (metadataResult.exitCode == 0) {
        final durationSeconds = double.tryParse(metadataResult.stdout.toString().trim());
        if (durationSeconds != null) {
          duration = Duration(seconds: durationSeconds.round());
        }
      }
      
      final formattedDuration = _formatDuration(duration);
      
      final clipboardText = '$author - $title ($year) $formattedFileSize $formattedDuration';
      
      await Clipboard.setData(ClipboardData(text: clipboardText));
      
      _showSuccess('Copied to clipboard:\n$clipboardText');
      
    } catch (e) {
      _showError('Failed to copy metadata: $e');
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KiB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MiB';
  }
}

