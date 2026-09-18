import 'package:media_kit/media_kit.dart';

class AlifAudioPlayer {
  AlifAudioPlayer._();
  static final AlifAudioPlayer instance = AlifAudioPlayer._();

  final Player _player = Player();

  Future<void> playLetter(String audioAsset) async {
    if (audioAsset.isEmpty) return;
    final assetPath = 'assets/alif/$audioAsset.opus';
    try {
      await _player.open(Media('asset:///$assetPath'));
      await _player.play();
    } catch (e) {
      print('Error playing alif audio ($audioAsset): $e');
    }
  }

  void dispose() => _player.dispose();
}
