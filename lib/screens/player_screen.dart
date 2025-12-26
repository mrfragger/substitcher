import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import '../models/audiobook_metadata.dart';
import '../services/ffmpeg_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'encoder_screen.dart';

enum PanelMode { chapters, history, playlist, bookmarks }

class HistoryItem {
  final String audiobookPath;
  final String audiobookTitle;
  final String chapterTitle;
  final int lastChapter;
  final Duration lastPosition;
  final DateTime lastPlayed;
  final bool shuffleEnabled;
  final List<int> playedChapters;

  HistoryItem({
    required this.audiobookPath,
    required this.audiobookTitle,
    required this.chapterTitle,
    required this.lastChapter,
    required this.lastPosition,
    required this.lastPlayed,
    this.shuffleEnabled = false,
    this.playedChapters = const [],
  });

  Map<String, dynamic> toJson() => {
    'audiobookPath': audiobookPath,
    'audiobookTitle': audiobookTitle,
    'chapterTitle': chapterTitle,
    'lastChapter': lastChapter,
    'lastPosition': lastPosition.inMilliseconds,
    'lastPlayed': lastPlayed.toIso8601String(),
    'shuffleEnabled': shuffleEnabled,
    'playedChapters': playedChapters,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      audiobookPath: json['audiobookPath'],
      audiobookTitle: json['audiobookTitle'] ?? '',
      chapterTitle: json['chapterTitle'] ?? 'Unknown Chapter',
      lastChapter: json['lastChapter'],
      lastPosition: Duration(milliseconds: json['lastPosition']),
      lastPlayed: DateTime.parse(json['lastPlayed']),
      shuffleEnabled: json['shuffleEnabled'] ?? false,
      playedChapters: (json['playedChapters'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }
}

class Bookmark {
  final String audiobookPath;
  final String audiobookTitle;
  final String chapterTitle;
  final int chapterIndex;
  final Duration position;
  final DateTime created;
  final String? note;

  Bookmark({
    required this.audiobookPath,
    required this.audiobookTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.position,
    required this.created,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'audiobookPath': audiobookPath,
    'audiobookTitle': audiobookTitle,
    'chapterTitle': chapterTitle,
    'chapterIndex': chapterIndex,
    'position': position.inMilliseconds,
    'created': created.toIso8601String(),
    'note': note,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      audiobookPath: json['audiobookPath'],
      audiobookTitle: json['audiobookTitle'] ?? '',
      chapterTitle: json['chapterTitle'] ?? 'Unknown Chapter',
      chapterIndex: json['chapterIndex'] ?? 0,
      position: Duration(milliseconds: json['position']),
      created: DateTime.parse(json['created']),
      note: json['note'],
    );
  }
}

class SubtitleCue {
  final Duration startTime;
  final Duration endTime;
  final String text;

  SubtitleCue({
    required this.startTime,
    required this.endTime,
    required this.text,
  });
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FFmpegService _ffmpeg = FFmpegService();
  final player = Player();
  final ScrollController _chapterScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  AudiobookMetadata? _currentAudiobook;
  int _currentChapterIndex = 0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  bool _showPanel = false;
  PanelMode _panelMode = PanelMode.chapters;
  double _playbackSpeed = 1.0;
  int _fileSize = 0;
  bool _shuffleEnabled = false;
  List<int> _playedChapters = [];
  Timer? _sleepTimer;
  Timer? _positionTimer;
  Duration? _sleepDuration;
  bool _showEncoderScreen = false;

  List<HistoryItem> _history = [];
  List<String> _playlist = [];
  String? _playlistRootDir;
  List<SubtitleCue> _subtitles = [];
  String _currentSubtitleText = '';
  String? _subtitleFilePath;
  double _subtitleFontSize = 44.0;
  double? _sliderHoverPosition;
  String? _hoveredChapterTitle;

  List<Bookmark> _bookmarks = [];
  String _searchQuery = '';
  bool _searchUseAnd = true;
  String _excludeTerms = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _excludeController = TextEditingController();

  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
    _loadHistory().then((_) {
      if (_history.isNotEmpty && mounted) {
        _openAudiobook(_history.first.audiobookPath).then((_) {
          if (mounted) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.history;
            });
          }
        });
      }
    });
    _loadPlaylist();
    _loadBookmarks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _sleepTimer?.cancel();
    _positionTimer?.cancel();
    player.dispose();
    _chapterScrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    player.stream.position.listen((position) {
      setState(() {
        _currentPosition = position;
      });
      _checkChapterBoundary(position);
      _checkSleepTimer();
      _updateCurrentSubtitle();

      if (_isPlaying && position.inSeconds % 10 == 0) {
        _saveToHistory();
      }
    });

    player.stream.duration.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    player.stream.playing.listen((playing) {
      setState(() {
        _isPlaying = playing;
      });

      if (playing) {
        _saveToHistory();
      } else {
        _saveToHistory();
      }
    });
  }

  void _checkChapterBoundary(Duration position) {
    if (_currentAudiobook == null) return;

    final chapter = _currentAudiobook!.chapters[_currentChapterIndex];

    if (position >= chapter.endTime && _currentChapterIndex < _currentAudiobook!.chapters.length - 1) {
      if (!_playedChapters.contains(_currentChapterIndex)) {
        _playedChapters.add(_currentChapterIndex);
      }
      _nextChapter();
    }
  }

  void _checkSleepTimer() {
    if (_sleepDuration == null) return;

    if (_sleepDuration == Duration.zero) {
      final chapter = _currentAudiobook!.chapters[_currentChapterIndex];
      if (_currentPosition >= chapter.endTime) {
        player.pause();
        setState(() {
          _sleepDuration = null;
        });
      }
    }
  }

  void _setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();

    if (duration == null) {
      setState(() {
        _sleepDuration = null;
      });
      return;
    }

    if (duration == Duration.zero) {
      setState(() {
        _sleepDuration = Duration.zero;
      });
      return;
    }

    setState(() {
      _sleepDuration = duration;
    });

    _sleepTimer = Timer(duration, () {
      player.pause();
      setState(() {
        _sleepDuration = null;
      });
    });
  }

  void _scrollToCurrentChapter() {
    if (_showPanel && _panelMode == PanelMode.chapters) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chapterScrollController.hasClients) {
          const itemHeight = 72.0;
          final viewportHeight = _chapterScrollController.position.viewportDimension;
          final targetOffset = (_currentChapterIndex * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);
          final maxScroll = _chapterScrollController.position.maxScrollExtent;
          final minScroll = _chapterScrollController.position.minScrollExtent;

          final clampedScroll = targetOffset.clamp(minScroll, maxScroll);

          _chapterScrollController.animateTo(
            clampedScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('history') ?? [];

    setState(() {
      _history = historyJson
          .map((jsonStr) {
            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              return HistoryItem.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .whereType<HistoryItem>()
          .toList();
    });
  }

  Future<void> _saveToHistory() async {
    if (_currentAudiobook == null) return;

    _history.removeWhere((h) => h.audiobookPath == _currentAudiobook!.path);

    final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];

    _history.insert(0, HistoryItem(
      audiobookPath: _currentAudiobook!.path,
      audiobookTitle: _currentAudiobook!.title,
      chapterTitle: currentChapter.title,
      lastChapter: _currentChapterIndex,
      lastPosition: _currentPosition,
      lastPlayed: DateTime.now(),
      shuffleEnabled: _shuffleEnabled,
      playedChapters: _playedChapters,
    ));

    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      _history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> _removeFromHistory(int index) async {
    setState(() {
      _history.removeAt(index);
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      _history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final rootDir = prefs.getString('playlistRootDir');

    if (rootDir != null && await Directory(rootDir).exists()) {
      setState(() {
        _playlistRootDir = rootDir;
      });
      await _scanPlaylist(rootDir);
    }
  }

  Future<void> _scanPlaylist(String dirPath) async {
    final files = <String>[];
    final dir = Directory(dirPath);

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.opus')) {
        files.add(entity.path);
      }
    }

    files.sort();

    setState(() {
      _playlist = files;
      _playlistRootDir = dirPath;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlistRootDir', dirPath);
  }

  Future<void> _setPlaylistDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    
    if (result == null) return;
    
    await _scanPlaylist(result);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist directory set to: ${path.basename(result)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getRelativePath(String fullPath) {
    if (_playlistRootDir == null) return fullPath;

    if (fullPath.startsWith(_playlistRootDir!)) {
      return fullPath.substring(_playlistRootDir!.length + 1);
    }
    return fullPath;
  }

  Future<int> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).floor()}KiB';
    return '${(bytes / (1024 * 1024)).floor()}MiB';
  }

  Duration _getChapterRemainingTime() {
    if (_currentAudiobook == null) return Duration.zero;
    final chapter = _currentAudiobook!.chapters[_currentChapterIndex];
    final elapsed = _currentPosition - chapter.startTime;
    return chapter.duration - elapsed;
  }

  Duration _getAudiobookRemainingTime() {
    if (_currentAudiobook == null) return Duration.zero;
    return _totalDuration - _currentPosition;
  }

  Future<void> _increaseSpeed() async {
    if (_playbackSpeed < 3.0) {
      setState(() {
        _playbackSpeed = (_playbackSpeed + 0.1).clamp(0.5, 3.0);
      });
      await player.setRate(_playbackSpeed);
    }
  }

  Future<void> _decreaseSpeed() async {
    if (_playbackSpeed > 0.5) {
      setState(() {
        _playbackSpeed = (_playbackSpeed - 0.1).clamp(0.5, 3.0);
      });
      await player.setRate(_playbackSpeed);
    }
  }

  void _increaseFontSize() {
    setState(() {
      _subtitleFontSize = (_subtitleFontSize + 4).clamp(20.0, 80.0);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _subtitleFontSize = (_subtitleFontSize - 4).clamp(20.0, 80.0);
    });
  }

  void _toggleShuffle() {
    setState(() {
      _shuffleEnabled = !_shuffleEnabled;
      if (!_shuffleEnabled) {
        _playedChapters.clear();
      }
    });
    _saveToHistory();
  }

  int _getNextShuffleChapter() {
    if (_currentAudiobook == null) return 0;

    final totalChapters = _currentAudiobook!.chapters.length;
    final unplayedChapters = List.generate(totalChapters, (i) => i)
        .where((i) => !_playedChapters.contains(i))
        .toList();

    if (unplayedChapters.isEmpty) {
      _playedChapters.clear();
      return Random().nextInt(totalChapters);
    }

    return unplayedChapters[Random().nextInt(unplayedChapters.length)];
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getStringList('bookmarks') ?? [];

    setState(() {
      _bookmarks = bookmarksJson
          .map((jsonStr) {
            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              return Bookmark.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .whereType<Bookmark>()
          .toList();
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bookmarks',
      _bookmarks.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  Future<void> _addBookmark() async {
    if (_currentAudiobook == null) return;

    final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
    final timeUntilChapterEnd = currentChapter.endTime - _currentPosition;
    
    Duration bookmarkPosition = _currentPosition;
    int bookmarkChapterIndex = _currentChapterIndex;
    String bookmarkChapterTitle = currentChapter.title;
    
    if (timeUntilChapterEnd.inSeconds <= 10 && 
        _currentChapterIndex < _currentAudiobook!.chapters.length - 1) {
      bookmarkChapterIndex = _currentChapterIndex + 1;
      final nextChapter = _currentAudiobook!.chapters[bookmarkChapterIndex];
      bookmarkPosition = nextChapter.startTime;
      bookmarkChapterTitle = nextChapter.title;
    }

    final bookmark = Bookmark(
      audiobookPath: _currentAudiobook!.path,
      audiobookTitle: _currentAudiobook!.title,
      chapterTitle: bookmarkChapterTitle,
      chapterIndex: bookmarkChapterIndex,
      position: bookmarkPosition,
      created: DateTime.now(),
    );

    setState(() {
      _bookmarks.insert(0, bookmark);
    });

    await _saveBookmarks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bookmark added'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _removeBookmark(int index) async {
    setState(() {
      _bookmarks.removeAt(index);
    });
    await _saveBookmarks();
  }

  Future<void> _jumpToBookmark(Bookmark bookmark) async {
    if (_currentAudiobook?.path != bookmark.audiobookPath) {
      await _openAudiobook(bookmark.audiobookPath);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    await _seekTo(bookmark.position);
    setState(() {
      _showPanel = false;
    });
  }

  bool _matchesSearch(String text, String query, List<String> excludeTerms) {
    final lowerText = text.toLowerCase();
    final searchTerms = query.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
    
    for (final excludeTerm in excludeTerms) {
      if (lowerText.contains(excludeTerm.toLowerCase())) {
        return false;
      }
    }
    
    if (searchTerms.isEmpty) return true;
    
    if (_searchUseAnd) {
      return searchTerms.every((term) => lowerText.contains(term));
    } else {
      return searchTerms.any((term) => lowerText.contains(term));
    }
  }

  List<Chapter> _getFilteredChapters() {
    if (_currentAudiobook == null) return [];
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _currentAudiobook!.chapters;
    }
    
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    
    return _currentAudiobook!.chapters.where((chapter) {
      return _matchesSearch(chapter.title, _searchQuery, excludeList);
    }).toList();
  }

  List<HistoryItem> _getFilteredHistory() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _history;
    }
    
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    
    return _history.where((item) {
      final searchText = '${item.audiobookTitle} ${item.chapterTitle}';
      return _matchesSearch(searchText, _searchQuery, excludeList);
    }).toList();
  }

  List<String> _getFilteredPlaylist() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _playlist;
    }
    
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    
    return _playlist.where((filePath) {
      final fileName = path.basename(filePath);
      return _matchesSearch(fileName, _searchQuery, excludeList);
    }).toList();
  }

  List<Bookmark> _getFilteredBookmarks() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _bookmarks;
    }
    
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    
    return _bookmarks.where((bookmark) {
      final searchText = '${bookmark.audiobookTitle} ${bookmark.chapterTitle} ${bookmark.note ?? ''}';
      return _matchesSearch(searchText, _searchQuery, excludeList);
    }).toList();
  }

  Future<void> _loadSubtitles(String audiobookPath) async {
    final dir = path.dirname(audiobookPath);
    final baseName = path.basenameWithoutExtension(audiobookPath);

    String? subtitlePath;
    for (final ext in ['.vtt', '.srt']) {
      final testPath = path.join(dir, '$baseName$ext');
      if (await File(testPath).exists()) {
        subtitlePath = testPath;
        break;
      }
    }

    if (subtitlePath == null) {
      setState(() {
        _subtitles = [];
        _subtitleFilePath = null;
        _currentSubtitleText = '';
      });
      return;
    }

    try {
      final content = await File(subtitlePath).readAsString();
      final subtitles = subtitlePath.endsWith('.vtt') 
          ? _parseVTT(content) 
          : _parseSRT(content);

      setState(() {
        _subtitles = subtitles;
        _subtitleFilePath = subtitlePath;
      });

      print('Loaded ${_subtitles.length} subtitles from $subtitlePath');
    } catch (e) {
      print('Error loading subtitles: $e');
      setState(() {
        _subtitles = [];
        _subtitleFilePath = null;
        _currentSubtitleText = '';
      });
    }
  }

  List<SubtitleCue> _parseVTT(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final startTime = _parseVTTTime(parts[0].trim());
          final endTime = _parseVTTTime(parts[1].trim().split(' ')[0]);

          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }

          if (startTime != null && endTime != null && textLines.isNotEmpty) {
            cues.add(SubtitleCue(
              startTime: startTime,
              endTime: endTime,
              text: textLines.join('\n'),
            ));
          }
        }
      }
    }

    return cues;
  }

  List<SubtitleCue> _parseSRT(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final startTime = _parseSRTTime(parts[0].trim());
          final endTime = _parseSRTTime(parts[1].trim());

          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }

          if (startTime != null && endTime != null && textLines.isNotEmpty) {
            cues.add(SubtitleCue(
              startTime: startTime,
              endTime: endTime,
              text: textLines.join('\n'),
            ));
          }
        }
      }
    }

    return cues;
  }

  Duration? _parseVTTTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) 
            : 0;

        return Duration(
          hours: hours, 
          minutes: minutes, 
          seconds: seconds, 
          milliseconds: milliseconds
        );
      } else if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) 
            : 0;

        return Duration(
          minutes: minutes, 
          seconds: seconds, 
          milliseconds: milliseconds
        );
      }
    } catch (e) {
      print('Error parsing VTT time "$timeStr": $e');
      return null;
    }
    return null;
  }

  Duration? _parseSRTTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split(',');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 ? int.parse(secondsParts[1]) : 0;

        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      }
    } catch (e) {
      print('Error parsing SRT time "$timeStr": $e');
      return null;
    }
    return null;
  }

  void _updateCurrentSubtitle() {
    if (_subtitles.isEmpty) {
      if (_currentSubtitleText.isNotEmpty) {
        setState(() {
          _currentSubtitleText = '';
        });
      }
      return;
    }

    for (final cue in _subtitles) {
      if (_currentPosition >= cue.startTime && _currentPosition < cue.endTime) {
        if (_currentSubtitleText != cue.text) {
          setState(() {
            _currentSubtitleText = cue.text;
          });
        }
        return;
      }
    }

    if (_currentSubtitleText.isNotEmpty) {
      setState(() {
        _currentSubtitleText = '';
      });
    }
  }

Future<void> _openAudiobook([String? filePath]) async {
    try {
      String? selectedPath = filePath;

      if (selectedPath == null) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['opus'],
        );

        if (result == null || result.files.isEmpty) {
          return;
        }
        selectedPath = result.files.first.path!;
      }

      final metadata = await _ffmpeg.loadAudiobook(selectedPath);
      final fileSize = await _getFileSize(selectedPath);

      await player.stop();

      final historyItem = _history.firstWhere(
        (h) => h.audiobookPath == selectedPath,
        orElse: () => HistoryItem(
          audiobookPath: selectedPath!,
          audiobookTitle: metadata.title,
          chapterTitle: metadata.chapters[0].title,
          lastChapter: 0,
          lastPosition: Duration.zero,
          lastPlayed: DateTime.now(),
          shuffleEnabled: false,
          playedChapters: [],
        ),
      );

      setState(() {
        _currentAudiobook = metadata;
        _currentChapterIndex = historyItem.lastChapter;
        _currentPosition = historyItem.lastPosition;
        _fileSize = fileSize;
        _shuffleEnabled = historyItem.shuffleEnabled;
        _playedChapters = List.from(historyItem.playedChapters);
      });

      final fileDir = path.dirname(selectedPath);
      bool isInPlaylistDir = false;
      
      if (_playlistRootDir != null) {
        isInPlaylistDir = selectedPath.startsWith(_playlistRootDir!);
      }
      
      if (!isInPlaylistDir) {
        print('File outside playlist directory, creating local playlist for: $fileDir');
        await _scanPlaylist(fileDir);
      }

      await player.open(Media(selectedPath));
      await player.setRate(_playbackSpeed);

      await _loadSubtitles(selectedPath);

      await Future.delayed(const Duration(milliseconds: 100));

      if (historyItem.lastPosition.inSeconds > 0) {
        await player.seek(historyItem.lastPosition);
        await Future.delayed(const Duration(milliseconds: 50));
      }
    
      await player.play();

      _focusNode.requestFocus();

    } catch (e, stackTrace) {
      print('Error opening audiobook: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open audiobook: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    await player.playOrPause();
  }

  Future<void> _seekTo(Duration position) async {
    await player.seek(position);
    
    if (_currentAudiobook != null) {
      for (var i = 0; i < _currentAudiobook!.chapters.length; i++) {
        final chapter = _currentAudiobook!.chapters[i];
        if (position >= chapter.startTime && position < chapter.endTime) {
          setState(() {
            _currentChapterIndex = i;
          });
          break;
        }
      }
    }

    _updateCurrentSubtitle();
  }

  Future<void> _skipForward() async {
    final newPosition = _currentPosition + const Duration(seconds: 10);
    await _seekTo(newPosition);
  }

  Future<void> _skipBackward() async {
    final newPosition = _currentPosition - const Duration(seconds: 10);
    await _seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
  }

  Future<void> _previousChapter() async {
    if (_currentChapterIndex > 0) {
      final chapter = _currentAudiobook!.chapters[_currentChapterIndex - 1];
      await _seekTo(chapter.startTime);
    }
  }

  Future<void> _nextChapter() async {
    if (_currentAudiobook == null) return;

    if (_shuffleEnabled) {
      final nextIndex = _getNextShuffleChapter();
      final chapter = _currentAudiobook!.chapters[nextIndex];
      await _seekTo(chapter.startTime);
    } else {
      if (_currentChapterIndex < _currentAudiobook!.chapters.length - 1) {
        final chapter = _currentAudiobook!.chapters[_currentChapterIndex + 1];
        await _seekTo(chapter.startTime);
      }
    }
  }

  Future<void> _jumpToChapter(int index) async {
    if (_currentAudiobook != null && index >= 0 && index < _currentAudiobook!.chapters.length) {
      final chapter = _currentAudiobook!.chapters[index];
      await _seekTo(chapter.startTime);
      setState(() {
        _showPanel = false;
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatChapterRemaining(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      final seconds = d.inSeconds.remainder(60);
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds.remainder(60);
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _decreaseFontSize();
      } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
        _increaseFontSize();
      }
    } else if (event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        _decreaseFontSize();
      } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
        _increaseFontSize();
      }
    }
  }

  int _findNearestChapter(double position) {
    if (_currentAudiobook == null) return -1;

    final positionDuration = Duration(milliseconds: position.toInt());
    final totalMillis = _totalDuration.inMilliseconds;
    if (totalMillis == 0) return -1;

    const snapDistancePx = 2.0;

    for (var i = 0; i < _currentAudiobook!.chapters.length; i++) {
      final chapter = _currentAudiobook!.chapters[i];
      final chapterPositionPx = (chapter.startTime.inMilliseconds / totalMillis) * MediaQuery.of(context).size.width;
      final clickPositionPx = (position / totalMillis) * MediaQuery.of(context).size.width;

      if ((clickPositionPx - chapterPositionPx).abs() <= snapDistancePx) {
        return i;
      }
    }

    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (_showEncoderScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const EncoderScreen(),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                iconSize: 32,
                onPressed: () {
                  setState(() {
                    _showEncoderScreen = false;
                  });
                  _focusNode.requestFocus();
                },
              ),
            ),
          ],
        ),
      );
    }

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyPress,
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            if (_showPanel) {
              setState(() {
                _showPanel = false;
              });
            }
            _focusNode.requestFocus();
          },
          child: Stack(
            children: [
              if (_currentAudiobook == null)
                _buildNoAudiobook()
              else
                _buildPlayer(),

              if (_showPanel && _currentAudiobook != null)
                _buildPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
    final fileName = path.basename(_currentAudiobook!.path);
    final chapterRemaining = _getChapterRemainingTime();
    final audiobookRemaining = _getAudiobookRemainingTime();
    final progressPercent = (_totalDuration.inMilliseconds > 0 ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds * 100).toInt() : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Flexible(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '↳ ${_currentChapterIndex + 1}/${_currentAudiobook!.chapters.length}: ${currentChapter.title}',
                          ),
                          TextSpan(
                            text: ' -${_formatChapterRemaining(chapterRemaining)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Spacer(),

        if (_currentSubtitleText.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentSubtitleText,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _subtitleFontSize,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 2),
          child: Column(
            children: [
              MouseRegion(
                onHover: (event) {
                  final localX = event.localPosition.dx;
                  final sliderWidth = MediaQuery.of(context).size.width - 64;
                  
                  setState(() {
                    _sliderHoverPosition = localX;
                    
                    final totalMillis = _totalDuration.inMilliseconds;
                    if (totalMillis > 0 && _currentAudiobook != null) {
                      final hoverTime = Duration(
                        milliseconds: ((localX / sliderWidth) * totalMillis).toInt()
                      );
                      
                      for (final chapter in _currentAudiobook!.chapters) {
                        if (hoverTime >= chapter.startTime && hoverTime < chapter.endTime) {
                          _hoveredChapterTitle = chapter.title;
                          break;
                        }
                      }
                    }
                  });
                },
                onExit: (_) {
                  setState(() {
                    _sliderHoverPosition = null;
                    _hoveredChapterTitle = null;
                  });
                },
                child: GestureDetector(
                  onTapDown: (details) {
                    final localX = details.localPosition.dx;
                    final sliderWidth = MediaQuery.of(context).size.width - 64;
                    final totalMillis = _totalDuration.inMilliseconds;
                    
                    if (totalMillis > 0 && _currentAudiobook != null) {
                      final clickTime = Duration(
                        milliseconds: ((localX / sliderWidth) * totalMillis).toInt()
                      );
                      
                      for (var i = 0; i < _currentAudiobook!.chapters.length; i++) {
                        final chapter = _currentAudiobook!.chapters[i];
                        final chapterPosX = (chapter.startTime.inMilliseconds / totalMillis) * sliderWidth;
                        
                        if ((localX - chapterPosX).abs() < 15) {
                          _jumpToChapter(i);
                          return;
                        }
                      }
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            height: 20,
                            child: CustomPaint(
                              painter: ChapterMarkerPainter(
                                chapters: _currentAudiobook!.chapters,
                                totalDuration: _totalDuration,
                                hoverPosition: _sliderHoverPosition,
                              ),
                              size: Size(MediaQuery.of(context).size.width - 64, 20),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: _totalDuration.inMilliseconds > 0 
                                  ? _currentPosition.inMilliseconds.toDouble().clamp(0, _totalDuration.inMilliseconds.toDouble())
                                  : 0,
                              max: _totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds.toDouble() : 1,
                              onChanged: (value) {
                                final nearestChapter = _findNearestChapter(value);
                                if (nearestChapter >= 0) {
                                  final chapter = _currentAudiobook!.chapters[nearestChapter];
                                  _seekTo(chapter.startTime);
                                } else {
                                  _seekTo(Duration(milliseconds: value.toInt()));
                                }
                              },
                              activeColor: Colors.white70,
                              inactiveColor: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                      if (_hoveredChapterTitle != null && _sliderHoverPosition != null)
                        Positioned(
                          left: () {
                            final sliderWidth = MediaQuery.of(context).size.width - 64;
                            final tooltipWidth = 250.0;
                            var leftPos = _sliderHoverPosition! - (tooltipWidth / 2);
                            
                            if (leftPos < 0) {
                              leftPos = 0;
                            } else if (leftPos + tooltipWidth > sliderWidth) {
                              leftPos = sliderWidth - tooltipWidth;
                            }
                            
                            return leftPos;
                          }(),
                          top: -80,
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _hoveredChapterTitle!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$progressPercent% ${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_playbackSpeed.toStringAsFixed(1)}x',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          ' ${_formatFileSize(_fileSize)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          ' -${_formatDuration(audiobookRemaining)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _decreaseSpeed,
              icon: const Icon(Icons.hourglass_bottom),
              color: Colors.white,
              iconSize: 20,
              tooltip: 'Decrease speed',
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _increaseSpeed,
              icon: const Icon(Icons.hourglass_top),
              color: Colors.white,
              iconSize: 20,
              tooltip: 'Increase speed',
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: _previousChapter,
              icon: const Icon(Icons.skip_previous),
              color: Colors.white,
              iconSize: 28,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _skipBackward,
              icon: const Icon(Icons.replay_10),
              color: Colors.white,
              iconSize: 24,
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _togglePlayPause,
              icon: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle),
              color: Colors.deepPurple,
              iconSize: 28,
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _skipForward,
              icon: const Icon(Icons.forward_10),
              color: Colors.white,
              iconSize: 24,
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _nextChapter,
              icon: const Icon(Icons.skip_next),
              color: Colors.white,
              iconSize: 28,
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: _toggleShuffle,
              icon: const Icon(Icons.shuffle),
              color: _shuffleEnabled ? Colors.deepPurple : Colors.white,
              iconSize: 24,
              tooltip: _shuffleEnabled ? 'Shuffle ${_playedChapters.length}/${_currentAudiobook!.chapters.length}' : 'Shuffle off',
            ),
            const SizedBox(width: 8),
            PopupMenuButton<Duration?>(
              icon: Icon(
                Icons.access_time,
                color: _sleepDuration != null ? Colors.deepPurple : Colors.white,
                size: 24,
              ),
              tooltip: 'Sleep Timer',
              onSelected: _setSleepTimer,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('Off'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 15),
                  child: Text('15 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 30),
                  child: Text('30 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 45),
                  child: Text('45 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 60),
                  child: Text('60 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 90),
                  child: Text('90 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 120),
                  child: Text('120 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 150),
                  child: Text('150 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration(minutes: 180),
                  child: Text('180 minutes'),
                ),
                const PopupMenuItem(
                  value: Duration.zero,
                  child: Text('Chapter end'),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Add Bookmark',
              child: IconButton(
                onPressed: _addBookmark,
                icon: const Icon(Icons.bookmark_add),
                color: Colors.white,
                iconSize: 24,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showPanel = !_showPanel;
                  _panelMode = PanelMode.chapters;
                });
                if (_showPanel) {
                  _scrollToCurrentChapter();
                }
              },
              label: Text(
                'Chapters ${_currentAudiobook!.chapters.length}',
                style: const TextStyle(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Encoder',
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _showEncoderScreen = true;
                  });
                },
                icon: const Icon(Icons.tune),
                color: Colors.white,
                iconSize: 24,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Set Playlist Directory',
              child: IconButton(
                onPressed: _setPlaylistDirectory,
                icon: const Icon(Icons.folder_special),
                color: _playlistRootDir != null ? Colors.deepPurple : Colors.white,
                iconSize: 24,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Load Audiobook',
              child: IconButton(
                onPressed: () async {
                  await _openAudiobook();
                },
                icon: const Icon(Icons.folder_open),
                color: Colors.white,
                iconSize: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPanel() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: 800,
      child: Container(
        color: const Color(0xFF1E1E1E),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabButton('Chapters', PanelMode.chapters),
                              _buildTabButton('History', PanelMode.history),
                              _buildTabButton('Playlist', PanelMode.playlist),
                              _buildTabButton('Bookmarks', PanelMode.bookmarks),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showPanel = false;
                          });
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('AND', style: TextStyle(fontSize: 12)),
                        selected: _searchUseAnd,
                        onSelected: (selected) {
                          setState(() {
                            _searchUseAnd = true;
                          });
                        },
                        selectedColor: Colors.deepPurple,
                        labelStyle: TextStyle(
                          color: _searchUseAnd ? Colors.white : Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ChoiceChip(
                        label: const Text('OR', style: TextStyle(fontSize: 12)),
                        selected: !_searchUseAnd,
                        onSelected: (selected) {
                          setState(() {
                            _searchUseAnd = false;
                          });
                        },
                        selectedColor: Colors.deepPurple,
                        labelStyle: TextStyle(
                          color: !_searchUseAnd ? Colors.white : Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _excludeController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Exclude...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.block, color: Colors.white54, size: 20),
                            suffixIcon: _excludeTerms.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                                    onPressed: () {
                                      _excludeController.clear();
                                      setState(() {
                                        _excludeTerms = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _excludeTerms = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildPanelContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, PanelMode mode) {
    final isActive = _panelMode == mode;
    
    int count = 0;
    switch (mode) {
      case PanelMode.chapters:
        count = _currentAudiobook?.chapters.length ?? 0;
        break;
      case PanelMode.history:
        count = _history.length;
        break;
      case PanelMode.playlist:
        count = _playlist.length;
        break;
      case PanelMode.bookmarks:
        count = _bookmarks.length;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: () {
          setState(() {
            _panelMode = mode;
          });
          if (mode == PanelMode.chapters) {
            _scrollToCurrentChapter();
          }
        },
        style: TextButton.styleFrom(
          backgroundColor: isActive ? Colors.deepPurple : Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text(
          '$label $count',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    switch (_panelMode) {
      case PanelMode.chapters:
        return _buildChapterList();
      case PanelMode.history:
        return _buildHistoryList();
      case PanelMode.playlist:
        return _buildPlaylistList();
      case PanelMode.bookmarks:
        return _buildBookmarksList();
    }
  }

  Widget _buildChapterList() {
    final filteredChapters = _getFilteredChapters();
    
    if (filteredChapters.isEmpty) {
      return const Center(
        child: Text(
          'No chapters match search',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      controller: _chapterScrollController,
      itemCount: filteredChapters.length,
      itemBuilder: (context, index) {
        final chapter = filteredChapters[index];
        final actualIndex = _currentAudiobook!.chapters.indexOf(chapter);
        final isActive = actualIndex == _currentChapterIndex;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isActive ? Colors.deepPurple : const Color(0xFF006064),
            radius: 16,
            child: Text(
              '${actualIndex + 1}',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          title: Text(
            chapter.title,
            style: TextStyle(
              color: isActive ? Colors.purple[200] : Colors.white,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: Text(
            chapter.formattedDuration,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          onTap: () => _jumpToChapter(actualIndex),
          tileColor: isActive ? Colors.deepPurple.withAlpha(51) : null,
        );
      },
    );
  }

  Widget _buildHistoryList() {
    final filteredHistory = _getFilteredHistory();
    
    if (filteredHistory.isEmpty) {
      return const Center(
        child: Text(
          'No history matches search',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredHistory.length,
      itemBuilder: (context, index) {
        final item = filteredHistory[index];
        final actualIndex = _history.indexOf(item);

        return ListTile(
          title: Text(
            item.audiobookTitle,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            '${item.chapterTitle} • ${_formatDuration(item.lastPosition)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.white54),
            onPressed: () => _removeFromHistory(actualIndex),
          ),
          onTap: () async {
            setState(() {
              _showPanel = false;
            });
            await _openAudiobook(item.audiobookPath);
          },
        );
      },
    );
  }

Widget _buildPlaylistList() {
    final filteredPlaylist = _getFilteredPlaylist();
    
    if (filteredPlaylist.isEmpty) {
      return const Center(
        child: Text(
          'No playlist items match search',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredPlaylist.length,
      itemBuilder: (context, index) {
        final filePath = filteredPlaylist[index];
        final fileName = path.basename(filePath);
        final isActive = _currentAudiobook?.path == filePath;

        return ListTile(
          title: Text(
            fileName,
            style: TextStyle(
              color: isActive ? Colors.deepPurple : Colors.white,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () async {
            setState(() {
              _showPanel = false;
            });
            await _openAudiobook(filePath);
          },
          tileColor: isActive ? Colors.deepPurple.withAlpha(51) : null,
        );
      },
    );
  }

  Widget _buildBookmarksList() {
    final filteredBookmarks = _getFilteredBookmarks();
    
    if (filteredBookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No bookmarks yet',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            if (_currentAudiobook != null)
              ElevatedButton.icon(
                onPressed: _addBookmark,
                icon: const Icon(Icons.bookmark_add),
                label: const Text('Add Bookmark'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredBookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = filteredBookmarks[index];
        final actualIndex = _bookmarks.indexOf(bookmark);

        return ListTile(
          leading: const Icon(Icons.bookmark, color: Colors.deepPurple, size: 20),
          title: Text(
            bookmark.audiobookTitle,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          subtitle: Text(
            '${bookmark.chapterTitle} • ${_formatDuration(bookmark.position)}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.white54),
            onPressed: () => _removeBookmark(actualIndex),
          ),
          onTap: () => _jumpToBookmark(bookmark),
        );
      },
    );
  }

  Widget _buildNoAudiobook() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.headphones, size: 100, color: Colors.white54),
          const SizedBox(height: 32),
          const Text(
            'No audiobook loaded',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
          const SizedBox(height: 16),
          const Text(
            'Open the History, Set Playlist Directory, or Load an audiobook to get started',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPanel = true;
                    _panelMode = PanelMode.history;
                  });
                },
                icon: const Icon(Icons.history),
                label: const Text('Open History'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _setPlaylistDirectory,
                icon: const Icon(Icons.folder_special),
                label: const Text('Set Playlist Directory'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  await _openAudiobook();
                },
                icon: const Icon(Icons.folder_open),
                label: const Text('Load Audiobook'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChapterMarkerPainter extends CustomPainter {
  final List<Chapter> chapters;
  final Duration totalDuration;
  final double? hoverPosition;

  ChapterMarkerPainter({
    required this.chapters,
    required this.totalDuration,
    this.hoverPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalMillis = totalDuration.inMilliseconds;
    if (totalMillis == 0) return;

    for (final chapter in chapters) {
      final position = (chapter.startTime.inMilliseconds / totalMillis) * size.width;
      
      final isHovered = hoverPosition != null && 
                        (position - hoverPosition!).abs() < 10;
      
      final diamondSize = isHovered ? 8.0 : 6.0;
      
      final paint = Paint()
        ..color = Colors.deepPurple
        ..style = PaintingStyle.fill;
      
      final path = Path();
      path.moveTo(position, size.height / 2 - diamondSize);
      path.lineTo(position + diamondSize, size.height / 2);
      path.lineTo(position, size.height / 2 + diamondSize);
      path.lineTo(position - diamondSize, size.height / 2);
      path.close();
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ChapterMarkerPainter oldDelegate) {
    return oldDelegate.chapters != chapters || 
           oldDelegate.totalDuration != totalDuration ||
           oldDelegate.hoverPosition != hoverPosition;
  }
}