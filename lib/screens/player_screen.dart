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

enum PanelMode { chapters, history, playlist }

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
});

final prefs = await SharedPreferences.getInstance();
await prefs.setString('playlistRootDir', dirPath);
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

    await player.open(Media(selectedPath));
    await player.setRate(_playbackSpeed);

    await _loadSubtitles(selectedPath);

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
    if (_playlistRootDir == null || !selectedPath.startsWith(_playlistRootDir!)) {
      await _scanPlaylist(fileDir);
    }

    if (historyItem.lastPosition.inSeconds > 0) {
      await player.seek(historyItem.lastPosition);
    }
  
    await player.play();

    _focusNode.requestFocus();

  } catch (e, stackTrace) {
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
                Expanded(
                  child: Text(
                    '↳ ${_currentChapterIndex + 1}/${_currentAudiobook!.chapters.length}: ${currentChapter.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '-${_formatChapterRemaining(chapterRemaining)}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
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
                color: Colors.black.withOpacity(0.7),
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
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: ChapterMarkerPainter(
                          chapters: _currentAudiobook!.chapters,
                          totalDuration: _totalDuration,
                        ),
                      ),
                    ),
                    Slider(
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
                      inactiveColor: Colors.transparent,
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
                        ' / ${_formatFileSize(_fileSize)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        ' / -${_formatDuration(audiobookRemaining)}',
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
            icon: Text(
              '${_currentAudiobook!.chapters.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            label: const Text('Chapters', style: TextStyle(fontSize: 12)),
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
child: Row(
children: [
Expanded(
child: Row(
children: [
_buildTabButton('Chapters', PanelMode.chapters),
_buildTabButton('History', PanelMode.history),
_buildTabButton('Playlist', PanelMode.playlist),
],
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
),
child: Text(label),
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
}
}

Widget _buildChapterList() {
return ListView.builder(
controller: _chapterScrollController,
itemCount: _currentAudiobook!.chapters.length,
itemBuilder: (context, index) {
final chapter = _currentAudiobook!.chapters[index];
final isActive = index == _currentChapterIndex;

return ListTile(
leading: CircleAvatar(
backgroundColor: isActive ? Colors.deepPurple : const Color(0xFF006064),
radius: 16,
child: Text(
'${index + 1}',
style: const TextStyle(fontSize: 12, color: Colors.white),
),
),
title: Text(
chapter.title,
style: TextStyle(
color: isActive ? Colors.deepPurple : Colors.white,
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
onTap: () => _jumpToChapter(index),
tileColor: isActive ? Colors.deepPurple.withAlpha(51) : null,
);
},
);
}

Widget _buildHistoryList() {
if (_history.isEmpty) {
return const Center(
child: Text(
'No history yet',
style: TextStyle(color: Colors.white54),
),
);
}

return ListView.builder(
itemCount: _history.length,
itemBuilder: (context, index) {
final item = _history[index];

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
onPressed: () => _removeFromHistory(index),
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

Future<AudiobookMetadata?> _loadAudiobookMetadata(String filePath) async {
try {
return await _ffmpeg.loadAudiobook(filePath);
} catch (e) {
return null;
}
}

Widget _buildPlaylistList() {
if (_playlist.isEmpty) {
return const Center(
child: Text(
'No playlist loaded',
style: TextStyle(color: Colors.white54),
),
);
}

return ListView.builder(
itemCount: _playlist.length,
itemBuilder: (context, index) {
final filePath = _playlist[index];
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
'Open the History or Load an audiobook to get started',
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

ChapterMarkerPainter({
required this.chapters,
required this.totalDuration,
});

@override
void paint(Canvas canvas, Size size) {
final paint = Paint()
..color = Colors.deepPurple
..strokeWidth = 2;

final totalMillis = totalDuration.inMilliseconds;
if (totalMillis == 0) return;

for (final chapter in chapters) {
final position = (chapter.startTime.inMilliseconds / totalMillis) * size.width;
canvas.drawLine(
Offset(position, 0),
Offset(position, size.height),
paint,
);
}
}

@override
bool shouldRepaint(ChapterMarkerPainter oldDelegate) {
return oldDelegate.chapters != chapters || oldDelegate.totalDuration != totalDuration;
}
}
