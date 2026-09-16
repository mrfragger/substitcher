// lib/quran/quran_word_audio_player.dart
import 'package:media_kit/media_kit.dart';

class QuranWordAudioPlayer {
  QuranWordAudioPlayer._();
  static final QuranWordAudioPlayer instance = QuranWordAudioPlayer._();

  final Player _player = Player();
  Future<void> Function()? _mainPlayerPauseCallback;

  void setMainPlayerPauseCallback(Future<void> Function() callback) {
    _mainPlayerPauseCallback = callback;
  }

  Future<void> playWord(String canonicalAudioId) async {
    if (_mainPlayerPauseCallback != null) {
      await _mainPlayerPauseCallback!();
    }

    final assetPath = 'assets/audioword/$canonicalAudioId.opus';
    try {
      await _player.open(Media('asset:///$assetPath'));
      await _player.play();
    } catch (e) {
      print('Error playing word audio ($canonicalAudioId): $e');
    }
  }

  void dispose() => _player.dispose();
}
