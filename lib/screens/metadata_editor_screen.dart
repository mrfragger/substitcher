import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
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
  final String? currentlyLoadedPath;

  const MetadataEditorScreen({super.key, this.currentlyLoadedPath});

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

  bool _showSearchReplace = false;
  bool _useRegex = false;
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  bool _isPreviewingReplace = false;
  Map<int, String> _originalReplaceValues = {};

  AudiobookMetadataEdit? _titleCaseHistory;
  String? _titleCaseAuthor;
  String? _titleCaseTitle;

  @override
  void initState() {
    super.initState();
    if (widget.currentlyLoadedPath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoLoad(widget.currentlyLoadedPath!);
      });
    }
  }

  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _yearController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    super.dispose();
  }

  Future<void> _autoLoad(String filePath) async {
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
      await _ffmpeg.ensureBinaries();

      final process = await Process.start(
        _ffmpeg.ffprobePath ?? 'ffprobe',
        [filePath],
      );

      final stderrBytes = <int>[];
      await for (final chunk in process.stderr) {
        stderrBytes.addAll(chunk);
      }
      await process.exitCode;

      String output;
      try {
        output = utf8.decode(stderrBytes);
      } catch (_) {
        output = latin1.decode(stderrBytes);
      }

      setState(() {
        _debugInfo = 'RAW FFPROBE OUTPUT:\n$output\n\n';
      });

      String artist = 'Unknown Artist';
      String albumArtist = 'Unknown Artist';
      String album = 'Unknown Album';
      String title = 'Unknown Album';
      String? year;

      final lines = output.split('\n');
      bool inAudioStreamMetadata = false;

      for (final line in lines) {
        final trimmed = line.trim();

        if (trimmed.startsWith('Stream #0:0: Audio:')) {
          inAudioStreamMetadata = false;
          continue;
        }

        if (trimmed.startsWith('Stream #0:1:') || trimmed.startsWith('Stream #0:2:')) {
          break;
        }

        if (trimmed.startsWith('Metadata:')) {
          inAudioStreamMetadata = true;
          continue;
        }

        if (inAudioStreamMetadata && trimmed.contains(':')) {
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
      final finalTitle = album != 'Unknown Album' ? album : 'Unknown Title';

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

      List<Chapter> chapters = [];
      try {
        chapters = await _extractChapters(filePath);
      } catch (e) {
        print('WARNING: Chapter extraction failed: $e');
      }

      return AudiobookMetadataEdit(
        author: finalAuthor,
        title: finalTitle,
        year: year,
        chapters: chapters,
      );
    }

    Future<List<Chapter>> _extractChapters(String filePath) async {
        await _ffmpeg.ensureBinaries();

        final tempFile = '${Directory.systemTemp.path}/temp_ffmetadata.txt';

        final process = await Process.start(
          _ffmpeg.ffmpegPath ?? 'ffmpeg',
          ['-i', filePath, '-f', 'ffmetadata', '-y', tempFile],
        );

        await process.stderr.drain();
        await process.stdout.drain();
        final exitCode = await process.exitCode;

        if (exitCode != 0) return [];

        final bytes = await File(tempFile).readAsBytes();
        String content;
        try {
          content = utf8.decode(bytes);
        } catch (_) {
          content = latin1.decode(bytes);
        }

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

    return parts.asMap().entries.map((entry) {
      final idx = entry.key;
      final part = entry.value;

      if (part.trim().isEmpty) return part;

      final word = part;
      final isFirstWord = word == nonWhitespace.first;
      final isLastWord = word == nonWhitespace.last;

      // Check if previous non-whitespace word ends with digits
      if (idx > 0) {
        for (int i = idx - 1; i >= 0; i--) {
          if (parts[i].trim().isNotEmpty) {
            if (RegExp(r'\d$').hasMatch(parts[i])) {
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            }
            break;
          }
        }
      }

      if (idx > 0) {
        final prevPart = parts[idx - 1];
        if (prevPart.contains(':') || prevPart.contains('：') ||
            (idx > 1 && (parts[idx - 2].contains(':') || parts[idx - 2].contains('：')))) {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }
      }

      if (word.startsWith('"') || word.startsWith('＂')) {
        if (word.length > 1) {
          final openQuote = word[0];
          return openQuote + word[1].toUpperCase() + word.substring(2).toLowerCase();
        }
      }

      if (idx > 0) {
        final prevPart = parts[idx - 1];
        if (prevPart == '"' || prevPart == '＂' ||
            (prevPart.trim().isEmpty && idx > 1 && (parts[idx - 2] == '"' || parts[idx - 2] == '＂'))) {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }
      }

      if (!isFirstWord && nonWhitespace.isNotEmpty) {
        final prevIndex = nonWhitespace.indexOf(word) - 1;
        if (prevIndex >= 0) {
          final prevWord = nonWhitespace[prevIndex];
          if (prevWord == nonWhitespace.first &&
              RegExp(r'^\d+\.?$').hasMatch(prevWord)) {
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }

          if (prevWord.contains(':') || prevWord.contains('：')) {
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }

          if (prevWord == '"' || prevWord == '＂' || prevWord.endsWith('"') || prevWord.endsWith('＂')) {
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }
        }
      }

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
      if (_titleCaseHistory != null) {
        setState(() {
          _metadata = _titleCaseHistory;
          _titleCaseHistory = null;

          if (_titleCaseAuthor != null) {
            _authorController.text = _titleCaseAuthor!;
            _titleCaseAuthor = null;
          }
          if (_titleCaseTitle != null) {
            _titleController.text = _titleCaseTitle!;
            _titleCaseTitle = null;
          }
        });
        return;
      }

      setState(() {
        _titleCaseHistory = AudiobookMetadataEdit(
          author: _metadata!.author,
          title: _metadata!.title,
          year: _metadata!.year,
          chapters: _metadata!.chapters.map((c) => Chapter(
            index: c.index,
            title: c.title,
            startTime: c.startTime,
            endTime: c.endTime,
            duration: c.duration,
          )).toList(),
        );
        _titleCaseAuthor = _authorController.text;
        _titleCaseTitle = _titleController.text;

        _authorController.text = _titleCaseString(_authorController.text);
        _titleController.text = _titleCaseString(_titleController.text);

        _metadata!.author = _authorController.text;
        _metadata!.title = _titleController.text;

        _metadata!.chapters = _metadata!.chapters.map((chapter) {
          return Chapter(
            index: chapter.index,
            title: _titleCaseString(chapter.title),
            startTime: chapter.startTime,
            endTime: chapter.endTime,
            duration: chapter.duration,
          );
        }).toList();
      });
    }

  void _toggleReplacePreview() {
    if (_searchController.text.isEmpty) {
      _showError('Please enter a search term');
      return;
    }

    if (_metadata == null || _metadata!.chapters.isEmpty) {
      _showError('No chapters to preview');
      return;
    }

    setState(() {
      if (_isPreviewingReplace) {
        for (final entry in _originalReplaceValues.entries) {
          final chapter = _metadata!.chapters[entry.key];
          _metadata!.chapters[entry.key] = Chapter(
            index: chapter.index,
            title: entry.value,
            startTime: chapter.startTime,
            endTime: chapter.endTime,
            duration: chapter.duration,
          );
        }
        _originalReplaceValues.clear();
        _isPreviewingReplace = false;
      } else {
        _originalReplaceValues.clear();

        for (int i = 0; i < _metadata!.chapters.length; i++) {
          final chapter = _metadata!.chapters[i];
          final currentTitle = chapter.title;

          String newTitle;
          if (_useRegex) {
            try {
              final regex = RegExp(_searchController.text);
              if (regex.hasMatch(currentTitle)) {
                _originalReplaceValues[i] = currentTitle;
                newTitle = currentTitle.replaceAllMapped(
                  regex,
                  (match) {
                    String result = _replaceController.text;
                    for (int j = 0; j <= match.groupCount; j++) {
                      result = result.replaceAll('\$$j', match.group(j) ?? '');
                    }
                    return result;
                  },
                );
                _metadata!.chapters[i] = Chapter(
                  index: chapter.index,
                  title: newTitle,
                  startTime: chapter.startTime,
                  endTime: chapter.endTime,
                  duration: chapter.duration,
                );
              }
            } catch (e) {
              _showError('Invalid regex pattern: $e');
              setState(() {
                for (final entry in _originalReplaceValues.entries) {
                  final ch = _metadata!.chapters[entry.key];
                  _metadata!.chapters[entry.key] = Chapter(
                    index: ch.index,
                    title: entry.value,
                    startTime: ch.startTime,
                    endTime: ch.endTime,
                    duration: ch.duration,
                  );
                }
                _originalReplaceValues.clear();
                _isPreviewingReplace = false;
              });
              return;
            }
          } else {
            if (currentTitle.contains(_searchController.text)) {
              _originalReplaceValues[i] = currentTitle;
              newTitle = currentTitle.replaceAll(_searchController.text, _replaceController.text);
              _metadata!.chapters[i] = Chapter(
                index: chapter.index,
                title: newTitle,
                startTime: chapter.startTime,
                endTime: chapter.endTime,
                duration: chapter.duration,
              );
            }
          }
        }

        _isPreviewingReplace = true;
      }
    });
  }

  void _applySearchReplace() {
    if (_searchController.text.isEmpty) {
      _showError('Please enter a search term');
      return;
    }

    if (_metadata == null || _metadata!.chapters.isEmpty) {
      _showError('No chapters to modify');
      return;
    }

    setState(() {
      if (!_isPreviewingReplace) {
        for (int i = 0; i < _metadata!.chapters.length; i++) {
          final chapter = _metadata!.chapters[i];
          final currentTitle = chapter.title;

          String newTitle;
          if (_useRegex) {
            try {
              final regex = RegExp(_searchController.text);
              newTitle = currentTitle.replaceAllMapped(
                regex,
                (match) {
                  String result = _replaceController.text;
                  for (int j = 0; j <= match.groupCount; j++) {
                    result = result.replaceAll('\$$j', match.group(j) ?? '');
                  }
                  return result;
                },
              );
            } catch (e) {
              _showError('Invalid regex pattern: $e');
              return;
            }
          } else {
            newTitle = currentTitle.replaceAll(_searchController.text, _replaceController.text);
          }

          _metadata!.chapters[i] = Chapter(
            index: chapter.index,
            title: newTitle,
            startTime: chapter.startTime,
            endTime: chapter.endTime,
            duration: chapter.duration,
          );
        }
      }

      _originalReplaceValues.clear();
      _isPreviewingReplace = false;
    });

    _showSuccess('Replacements applied');
  }

  void _showRegexHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Search & Replace Examples'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Simple Pattern Matching',
                [
                  _HelpExample('Chapter \\d+', 'Matches "Chapter " + any number'),
                  _HelpExample('Part \\d+', 'Matches "Part " + any number'),
                  _HelpExample('^\\d+', 'Matches numbers at start of title'),
                  _HelpExample('\\d+\\.', 'Matches numbers with a period'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Simple Text Changes',
                [
                  _HelpExample('Search: \\sThe\\s', 'Replace: " the " - Change "The" to "the" (middle only)'),
                  _HelpExample('Search: \\sAnd\\s', 'Replace: " and " - Change "And" to "and" (middle only)'),
                  _HelpExample('Search: (?<!^)\\bThe\\b(?!\$)', 'Replace: the - Change "The" to "the" (not at start/end)'),
                  _HelpExample('Search: (?<!^)\\bAnd\\b(?!\$)', 'Replace: and - Change "And" to "and" (not at start/end)'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Removing Unwanted Text',
                [
                  _HelpExample(' - Copy\$', 'Remove " - Copy" at the end'),
                  _HelpExample('^\\d+\\s*-\\s*', 'Remove "01 - " from start'),
                  _HelpExample('\\(.*?\\)', 'Remove anything in ( )'),
                  _HelpExample('\\[.*?\\]', 'Remove anything in [ ]'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Adding/Formatting',
                [
                  _HelpExample('Search: ^(\\d+)', 'Replace: Chapter \$1'),
                  _HelpExample('Search: ^', 'Replace: Part 1 - '),
                  _HelpExample('Search: \$', 'Replace:  (Unabridged)'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Cleaning Up',
                [
                  _HelpExample('\\s+ → (space)', 'Multiple spaces to one'),
                  _HelpExample('_ → (space)', 'Underscores to spaces'),
                  _HelpExample('- →  -  ', 'Add spaces around dashes'),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Use \\d for any digit (0-9)\n'
                '• Use ^ for start of text\n'
                '• Use \$ for end of text\n'
                '• Use \\s for whitespace\n'
                '• Use . for any character\n'
                '• Use * for zero or more\n'
                '• Use + for one or more\n'
                '• Use ? for zero or one\n'
                '• Use \\. \\? \\* to match literal characters\n'
                '• Use (group) and \$1 in replace for capture groups',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, List<_HelpExample> examples) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 8),
        ...examples.map((example) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    children: [
                      TextSpan(
                        text: example.pattern,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' - '),
                      TextSpan(text: example.description),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildSearchReplacePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        border: Border.all(color: Colors.deepPurple),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _useRegex ? 'Search (regex mode)' : 'Search (plain text)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.help_outline, size: 20, color: Colors.white70),
                      onPressed: _showRegexHelp,
                      tooltip: 'Show regex examples',
                    ),
                  ),
                  onChanged: (_) {
                    if (_isPreviewingReplace) {
                      setState(() {
                        for (final entry in _originalReplaceValues.entries) {
                          final chapter = _metadata!.chapters[entry.key];
                          _metadata!.chapters[entry.key] = Chapter(
                            index: chapter.index,
                            title: entry.value,
                            startTime: chapter.startTime,
                            endTime: chapter.endTime,
                            duration: chapter.duration,
                          );
                        }
                        _originalReplaceValues.clear();
                        _isPreviewingReplace = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _replaceController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Replace',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_isPreviewingReplace) {
                      setState(() {
                        for (final entry in _originalReplaceValues.entries) {
                          final chapter = _metadata!.chapters[entry.key];
                          _metadata!.chapters[entry.key] = Chapter(
                            index: chapter.index,
                            title: entry.value,
                            startTime: chapter.startTime,
                            endTime: chapter.endTime,
                            duration: chapter.duration,
                          );
                        }
                        _originalReplaceValues.clear();
                        _isPreviewingReplace = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _toggleReplacePreview,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: _isPreviewingReplace ? Colors.orange : null,
                  foregroundColor: _isPreviewingReplace ? Colors.white : null,
                ),
                child: Text(_isPreviewingReplace ? 'Undo Preview' : 'Preview'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applySearchReplace,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _useRegex,
                onChanged: (value) {
                  setState(() {
                    _useRegex = value ?? false;
                    if (_isPreviewingReplace) {
                      for (final entry in _originalReplaceValues.entries) {
                        final chapter = _metadata!.chapters[entry.key];
                        _metadata!.chapters[entry.key] = Chapter(
                          index: chapter.index,
                          title: entry.value,
                          startTime: chapter.startTime,
                          endTime: chapter.endTime,
                          duration: chapter.duration,
                        );
                      }
                      _originalReplaceValues.clear();
                      _isPreviewingReplace = false;
                    }
                  });
                },
              ),
              const Text('Use Regular Expressions', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveMetadata() async {
      if (_currentFilePath == null || _metadata == null) return;

      setState(() => _saving = true);

      try {
        await _ffmpeg.ensureBinaries();

        final metadataContent = _createFFMetadataContent();
        final tempMetadataFile = path.join(Directory.systemTemp.path, 'editing_metadata.txt');

        await File(tempMetadataFile).writeAsBytes(
          utf8.encode(metadataContent),
          flush: true,
        );

        final ext = path.extension(_currentFilePath!).toLowerCase();
        final dir = path.dirname(_currentFilePath!);
        final baseName = path.basenameWithoutExtension(_currentFilePath!);
        final tempOutputFile = path.join(dir, '${baseName}_temp_meta$ext');

        final result = await Process.run(
          _ffmpeg.ffmpegPath ?? 'ffmpeg',
          [
            '-i', _currentFilePath!,
            '-i', tempMetadataFile,
            '-map', '0:a',
            '-map_chapters', '1',
            '-map_metadata', '1',
            '-c', 'copy',
            '-v', 'warning',
            '-y',
            tempOutputFile,
          ],
        );

        if (result.exitCode != 0) {
          try { await File(tempOutputFile).delete(); } catch (_) {}
          try { await File(tempMetadataFile).delete(); } catch (_) {}
          throw Exception('Failed to apply metadata: ${result.stderr}');
        }

        await File(_currentFilePath!).delete();
        await File(tempOutputFile).rename(_currentFilePath!);
        await File(tempMetadataFile).delete();

        setState(() => _saving = false);
        _showSuccess('Metadata saved successfully!');

      } catch (e) {
        setState(() => _saving = false);
        _showError('Failed to save metadata: $e');
      }
    }

    String _createFFMetadataContent() {
        final buffer = StringBuffer();

        buffer.writeln(';FFMETADATA1');
        buffer.writeln('Artist=${_escapeFFMetadata(_authorController.text)}');
        buffer.writeln('Album Artist=${_escapeFFMetadata(_authorController.text)}');
        buffer.writeln('Album=${_escapeFFMetadata(_titleController.text)}');
        buffer.writeln('Title=${_escapeFFMetadata(_titleController.text)}');

        if (_yearController.text.isNotEmpty) {
          buffer.writeln('Year=${_yearController.text}');
        }

        if (_currentFilePath!.toLowerCase().endsWith('.opus')) {
          const base64Png = 'AAAAAwAAAAlpbWFnZS9wbmcAAAALRnJvbnQgQ292ZXIAAAAQAAAACQAAACAAAAAAAAAAU4lQTkcNChoKAAAADUlIRFIAAAAQAAAACQgGAAAAOyqsMgAAABpJREFUeJxjZGBg+M9AAWCiRPOoARAwDAwAAFmzARHg40/fAAAAAElFTkSuQmCC';
          buffer.writeln('\nMETADATA_BLOCK_PICTURE=$base64Png');
        }

        buffer.writeln();

        for (final chapter in _metadata!.chapters) {
          buffer.writeln('[CHAPTER]');
          buffer.writeln('TIMEBASE=1/1000');
          buffer.writeln('START=${chapter.startTime.inMilliseconds}');
          buffer.writeln('END=${chapter.endTime.inMilliseconds}');
          buffer.writeln('title=${_escapeFFMetadata(chapter.title)}');
          buffer.writeln();
        }

        return buffer.toString();
      }

      String _escapeFFMetadata(String value) {
        return value
            .replaceAll('\\', '\\\\')
            .replaceAll('=', '\\=')
            .replaceAll(';', '\\;')
            .replaceAll('#', '\\#')
            .replaceAll('\n', '\\\n');
      }

  Future<void> _addBlack16x9Cover() async {
    if (_currentFilePath == null) return;

    setState(() => _saving = true);

    try {
      await _ffmpeg.ensureBinaries();

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

      final result = await Process.run(_ffmpeg.ffmpegPath ?? 'ffmpeg', [
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

  Widget _buildTitleWithHighlights(String displayTitle, String originalTitle) {
    if (displayTitle == originalTitle) {
      return Text(
        displayTitle,
        style: const TextStyle(fontSize: 14),
      );
    }

    final isCaseOnlyChange = displayTitle.toLowerCase() == originalTitle.toLowerCase();

    if (isCaseOnlyChange) {
      final spans = <InlineSpan>[];

      for (int i = 0; i < displayTitle.length; i++) {
        final char = displayTitle[i];
        final isChanged = i < originalTitle.length &&
                         char != originalTitle[i] &&
                         char.toLowerCase() == originalTitle[i].toLowerCase();

        spans.add(TextSpan(
          text: char,
          style: TextStyle(
            fontSize: 14,
            color: isChanged ? Colors.green : null,
            fontWeight: isChanged ? FontWeight.bold : null,
          ),
        ));
      }

      return RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          children: spans,
        ),
      );
    } else {
      final spans = <InlineSpan>[];
      final displayWords = displayTitle.split(' ');
      final originalWords = originalTitle.split(' ');

      for (int i = 0; i < displayWords.length; i++) {
        final displayWord = displayWords[i];
        final originalWord = i < originalWords.length ? originalWords[i] : '';

        if (i > 0) {
          spans.add(const TextSpan(text: ' '));
        }

        if (displayWord == originalWord) {
          spans.add(TextSpan(
            text: displayWord,
            style: const TextStyle(fontSize: 14),
          ));
        } else {
          spans.add(TextSpan(
            text: displayWord,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.green.withValues(alpha: 0.2),
            ),
          ));
        }
      }

      return RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          children: spans,
        ),
      );
    }
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
                if (_showSearchReplace) _buildSearchReplacePanel(),

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
                  onPressed: () {
                    setState(() {
                      _showSearchReplace = !_showSearchReplace;
                      if (!_showSearchReplace && _isPreviewingReplace) {
                        for (final entry in _originalReplaceValues.entries) {
                          final chapter = _metadata!.chapters[entry.key];
                          _metadata!.chapters[entry.key] = Chapter(
                            index: chapter.index,
                            title: entry.value,
                            startTime: chapter.startTime,
                            endTime: chapter.endTime,
                            duration: chapter.duration,
                          );
                        }
                        _originalReplaceValues.clear();
                        _isPreviewingReplace = false;
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: _showSearchReplace ? Colors.deepPurple : null,
                  ),
                  child: const Text('Replace'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyTitleCase,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(150, 36),
                  ),
                  child: Text(_titleCaseHistory != null ? 'Undo Title Case' : 'Apply Title Case'),
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
}

class _HelpExample {
  final String pattern;
  final String description;

  _HelpExample(this.pattern, this.description);
}
