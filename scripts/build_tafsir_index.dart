// scripts/build_tafsir_index.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../lib/tafsir/tafsir_arabic_katheer.dart';
import '../lib/tafsir/tafsir_english_ibn_kathir.dart';
import '../lib/tafsir/tafsir_arabic_baghawi.dart';
import '../lib/quran/quran_index.dart'; // for quranVerseCounts
import '../lib/tafsir_index/varint.dart';

List<String> tokenize(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((t) => t.isNotEmpty)
      .toList();
}

void buildIndex(String sourceName, String? Function(int, int) getText,
    String outPath, {bool includeAyah0 = false}) {
  final invertedIndex = <String, List<(int docId, int tf)>>{};
  final docLengths = <int, int>{};
  int totalDocs = 0;
  int totalLength = 0;

  for (int surah = 1; surah <= 114; surah++) {
    final maxAyah = quranVerseCounts[surah]!;
    final startAyah = includeAyah0 ? 0 : 1;
    for (int ayah = startAyah; ayah <= maxAyah; ayah++) {
      final text = getText(surah, ayah);
      if (text == null || text.isEmpty) continue;
      final tokens = tokenize(text);
      if (tokens.isEmpty) continue;

      final docId = surah * 1000 + ayah;
      final termCounts = <String, int>{};
      for (final t in tokens) {
        termCounts[t] = (termCounts[t] ?? 0) + 1;
      }
      for (final entry in termCounts.entries) {
        invertedIndex.putIfAbsent(entry.key, () => []).add((docId, entry.value));
      }
      docLengths[docId] = tokens.length;
      totalLength += tokens.length;
      totalDocs++;
    }
  }

  final avgDocLength = totalDocs == 0 ? 0.0 : totalLength / totalDocs;

  final writer = ByteWriter();
  writer.writeBytes(utf8.encode('TFXI'));
  writer.writeVarint(totalDocs);
  final avgBytes = ByteData(8)..setFloat64(0, avgDocLength, Endian.little);
  writer.writeBytes(avgBytes.buffer.asUint8List());

  final sortedTerms = invertedIndex.keys.toList()..sort();
  writer.writeVarint(sortedTerms.length);
  for (final term in sortedTerms) {
    final termBytes = utf8.encode(term);
    writer.writeVarint(termBytes.length);
    writer.writeBytes(termBytes);
    final postings = invertedIndex[term]!;
    writer.writeVarint(postings.length);
    for (final (docId, tf) in postings) {
      writer.writeVarint(docId);
      writer.writeVarint(tf);
    }
  }

  writer.writeVarint(docLengths.length);
  docLengths.forEach((docId, len) {
    writer.writeVarint(docId);
    writer.writeVarint(len);
  });

  File(outPath).writeAsBytesSync(writer.bytes);
  final sizeMb = writer.bytes.length / (1024 * 1024);
  stdout.writeln(
      '$sourceName: $totalDocs docs, ${sortedTerms.length} terms, '
      '${sizeMb.toStringAsFixed(2)} MB -> $outPath');
}

void main() {
  Directory('assets/tafsir_index').createSync(recursive: true);

  buildIndex('Katheer', getTafsirKatheer,
      'assets/tafsir_index/katheer.bin');
  buildIndex('Kathir', getTafsirKathirEnglish,
      'assets/tafsir_index/kathir.bin');
  buildIndex('Baghawi', getTafsirBaghawi,
      'assets/tafsir_index/baghawi.bin');
}
