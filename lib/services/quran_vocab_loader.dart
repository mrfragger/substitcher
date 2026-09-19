import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/quran_lemma.dart';
import '../models/root_card.dart';

class QuranVocabData {
  final List<QuranLemma> lemmas;
  final Map<String, RootCard> roots;

  const QuranVocabData({required this.lemmas, required this.roots});

  RootCard? rootFor(QuranLemma lemma) {
    if (lemma.root == null) return null;
    return roots[lemma.root];
  }
}

class QuranVocabLoader {
  static const _vocabPath = 'assets/quranroots/vocab.json';
  static const _rootsPath = 'assets/quranroots/roots.json';

  static QuranVocabData? _cached;
  static Future<QuranVocabData>? _inflight;

  static int cachedLemmaCount = 0;

  static Future<QuranVocabData> load() {
    if (_cached != null) return Future.value(_cached);
    return _inflight ??= _load();
  }

  static Future<QuranVocabData> _load() async {
    final results = await Future.wait([
      rootBundle.loadString(_vocabPath),
      rootBundle.loadString(_rootsPath),
    ]);

    final lemmasJson = jsonDecode(results[0]) as List;
    final rootsJson = jsonDecode(results[1]) as Map<String, dynamic>;

    final lemmas = lemmasJson
        .map((j) => QuranLemma.fromJson(j as Map<String, dynamic>))
        .toList();

    final roots = rootsJson.map(
      (key, value) => MapEntry(
        key,
        RootCard.fromJson(value as Map<String, dynamic>),
      ),
    );

    final data = QuranVocabData(lemmas: lemmas, roots: roots);
    _cached = data;
    cachedLemmaCount = lemmas.length;
    return data;
  }
}
