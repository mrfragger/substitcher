import 'dart:async';
import 'package:media_kit/media_kit.dart';
import '../models/audiobook_metadata.dart';

class PlayerStateManager {
  final Player player;
  
  AudiobookMetadata? currentAudiobook;
  int currentChapterIndex = 0;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;
  bool isPlaying = false;
  double playbackSpeed = 1.0;
  int fileSize = 0;
  bool shuffleEnabled = false;
  List<int> playedChapters = [];
  
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _stateSubscription;
  
  PlayerStateManager(this.player);
  
  void setupListeners({
    required Function(Duration) onPositionChanged,
    required Function(Duration) onDurationChanged,
    required Function(bool) onPlayingChanged,
  }) {
    _positionSubscription = player.stream.position.listen((position) {
      currentPosition = position;
      onPositionChanged(position);
    });

    _durationSubscription = player.stream.duration.listen((duration) {
      totalDuration = duration;
      onDurationChanged(duration);
    });

    _stateSubscription = player.stream.playing.listen((playing) {
      isPlaying = playing;
      onPlayingChanged(playing);
    });
  }
  
  Future<void> setPlaybackSpeed(double speed) async {
    playbackSpeed = speed.clamp(0.5, 3.0);
    await player.setRate(playbackSpeed);
  }
  
  Future<void> increaseSpeed() async {
    if (playbackSpeed < 3.0) {
      playbackSpeed = (playbackSpeed + 0.1).clamp(0.5, 3.0);
      await player.setRate(playbackSpeed);
    }
  }
  
  Future<void> decreaseSpeed() async {
    if (playbackSpeed > 0.5) {
      playbackSpeed = (playbackSpeed - 0.1).clamp(0.5, 3.0);
      await player.setRate(playbackSpeed);
    }
  }
  
  Future<void> togglePlayPause() async {
    await player.playOrPause();
  }
  
  Future<void> seekTo(Duration position) async {
    await player.seek(position);
  }
  
  Future<void> skipForward(Duration duration) async {
    final newPosition = currentPosition + duration;
    await seekTo(newPosition);
  }
  
  Future<void> skipBackward(Duration duration) async {
    final newPosition = currentPosition - duration;
    await seekTo(newPosition > Duration.zero ? newPosition : Duration.zero);
  }
  
  Duration getChapterRemainingTime() {
    if (currentAudiobook == null) return Duration.zero;
    final chapter = currentAudiobook!.chapters[currentChapterIndex];
    final elapsed = currentPosition - chapter.startTime;
    return chapter.duration - elapsed;
  }
  
  Duration getAudiobookRemainingTime() {
    return totalDuration - currentPosition;
  }
  
  void toggleShuffle() {
    shuffleEnabled = !shuffleEnabled;
    if (!shuffleEnabled) {
      playedChapters.clear();
    }
  }
  
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
  }
}