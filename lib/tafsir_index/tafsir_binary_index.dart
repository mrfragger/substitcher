// lib/tafsir_index/tafsir_binary_index.dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'varint.dart';

class BinaryPosting {
  final int docId;
  final int termFreq;
  const BinaryPosting(this.docId, this.termFreq);
}

class TafsirBinaryIndex {
  final Map<String, List<BinaryPosting>> invertedIndex;
  final Map<int, int> docLengths; // docId -> token length
  final int totalDocs;
  final double avgDocLength;

  TafsirBinaryIndex._(
      this.invertedIndex, this.docLengths, this.totalDocs, this.avgDocLength);

  static Future<TafsirBinaryIndex> load(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final reader = ByteReader(bytes);

    final magic = String.fromCharCodes(reader.readBytes(4));
    assert(magic == 'TFXI', 'Bad index file: $assetPath');

    final totalDocs = reader.readVarint();
    final avgBytes = reader.readBytes(8);
    final avgDocLength =
        ByteData.sublistView(Uint8List.fromList(avgBytes)).getFloat64(0, Endian.little);

    final termCount = reader.readVarint();
    final invertedIndex = <String, List<BinaryPosting>>{};
    for (int i = 0; i < termCount; i++) {
      final termLen = reader.readVarint();
      final term = String.fromCharCodes(reader.readBytes(termLen));
      final postingCount = reader.readVarint();
      final postings = <BinaryPosting>[];
      for (int j = 0; j < postingCount; j++) {
        final docId = reader.readVarint();
        final tf = reader.readVarint();
        postings.add(BinaryPosting(docId, tf));
      }
      invertedIndex[term] = postings;
    }

    final docLengthCount = reader.readVarint();
    final docLengths = <int, int>{};
    for (int i = 0; i < docLengthCount; i++) {
      final docId = reader.readVarint();
      final len = reader.readVarint();
      docLengths[docId] = len;
    }

    return TafsirBinaryIndex._(invertedIndex, docLengths, totalDocs, avgDocLength);
  }
}
