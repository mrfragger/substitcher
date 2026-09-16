// lib/quran/quran_word_audio_index.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

String audioAssetPath(String canonicalAudioId) =>
    'assets/audioword/$canonicalAudioId.opus';

class QuranWordAudioIndex {
  final Map<int, String> _byDocId; // docId -> canonical audio id (no ext)
  const QuranWordAudioIndex._(this._byDocId);

  static int _docId(int surah, int ayah, int word) =>
      surah * 1000000 + ayah * 1000 + word;

  String? getAudioId(int surah, int ayah, int word) =>
      _byDocId[_docId(surah, ayah, word)];

  static Future<QuranWordAudioIndex> load(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final view = ByteData.sublistView(bytes);

    if (bytes[0] != 0x51 || bytes[1] != 0x57 || bytes[2] != 0x41 || bytes[3] != 0x55) {
      throw FormatException('Bad magic in $assetPath');
    }
    int cursor = 4;
    final version = view.getUint16(cursor, Endian.little); cursor += 2;
    if (version != 1) throw FormatException('Unsupported version $version');
    final entryCount = view.getUint32(cursor, Endian.little); cursor += 4;
    final audioCount = view.getUint32(cursor, Endian.little); cursor += 4;

    final audioTable = List<String>.generate(audioCount, (i) {
      final start = cursor + i * 11;
      return ascii.decode(bytes.sublist(start, start + 11));
    });
    cursor += audioCount * 11;

    final map = <int, String>{};
    for (int i = 0; i < entryCount; i++) {
      final surah = bytes[cursor]; cursor += 1;
      final ayah = view.getUint16(cursor, Endian.little); cursor += 2;
      final word = bytes[cursor]; cursor += 1;
      final audioIdx = view.getUint16(cursor, Endian.little); cursor += 2;
      map[_docId(surah, ayah, word)] = audioTable[audioIdx];
    }

    return QuranWordAudioIndex._(map);
  }
}
