import 'dart:io';

import 'package:betto_icu/betto_icu.dart';
import 'package:characters/characters.dart';
import 'package:dart_jieba/dart_jieba.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tiny_segmenter_dart/tiny_segmenter_dart.dart';
import 'package:word_thai_split/word_thai_split.dart';

typedef LogFn = void Function(String message);

class QuranTokenizers {
  QuranTokenizers({required this.log});

  final LogFn log;

  static const String _jiebaAsset = 'assets/jieba/dict.dgz';
  static const String _jiebaTempName = 'jieba_dict.dgz';

  JiebaSegmenter? _jieba;
  TinySegmenter? _tiny;
  IcuTokenizer? _icu;
  bool _icuFailed = false;
  bool _khmerSampleLogged = false;
  final Set<String> _warned = {};

  void _warnOnce(String script, Object e) {
    if (_warned.add(script)) {
      log('  WARNING: $script tokenizer failed ($e) — using fallback');
    }
  }

  /// Fallback for Khmer: split on spaces so cuts never land inside a word.
  List<String> _khmerSpaceTokens(String text) =>
      text.split(RegExp(r'[ ​]+')).where((w) => w.isNotEmpty).toList();

  Future<List<String>> tokenize(String text, String script) async {
    try {
      switch (script) {
        case 'chinese':
          _jieba ??= await _loadJieba();
          return _jieba!.cut(text).map((e) => e.toString()).toList();
        case 'japanese':
          _tiny ??= TinySegmenter();
          final jt = _tiny!.segment(text);
          if (_warned.add('japanese-sample')) {
            log('  Japanese sample tokens (${jt.length}): ${jt.take(10).join(' | ')}');
          }
          return jt;
        case 'korean':
          return text.split(' ');
        case 'thai':
          final t = await WordThaiSplit.split(text);
          if (_warned.add('thai-sample')) {
            log('  Thai sample tokens (${t.length}): ${t.take(10).join(' | ')}');
          }
          return t;
        case 'khmer':
          return _khmer(text);
      }
    } catch (e) {
      _warnOnce(script, e);
    }
    return script == 'khmer' ? _khmerSpaceTokens(text) : text.characters.toList();
  }

  Future<JiebaSegmenter> _loadJieba() async {
    final tmp = await getTemporaryDirectory();
    final file = File(p.join(tmp.path, _jiebaTempName));
    if (!await file.exists() || await file.length() == 0) {
      await file.parent.create(recursive: true);
      final data = await rootBundle.load(_jiebaAsset);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    final j = JiebaSegmenter();
    j.initializeSync(dictPath: file.path);
    log('  Chinese tokenizer loaded (jieba)');
    return j;
  }

  /// betto_icu returns bare word spans: it trims spaces, punctuation AND
  /// trailing Khmer vowel signs / bantoc (e.g. ចំពោះ -> ចំព, ទ្រង់ -> ទ្រង).
  /// Re-attach everything between one word's start and the next word's start,
  /// so the tokens concatenate back to exactly [text].
  static List<String> _tileTokens(String text, List<String> raw) {
    final starts = <int>[];
    var cursor = 0;
    for (final t in raw) {
      if (t.isEmpty) continue;
      final i = text.indexOf(t, cursor);
      if (i < 0) continue;
      starts.add(i);
      cursor = i + t.length;
    }
    if (starts.isEmpty) return [text];
    final out = <String>[];
    for (var k = 0; k < starts.length; k++) {
      final from = k == 0 ? 0 : starts[k];
      final to = k + 1 < starts.length ? starts[k + 1] : text.length;
      out.add(text.substring(from, to));
    }
    return out;
  }

  /// Khmer word segmentation via the system ICU library (betto_icu).
  /// No Python needed. Falls back to splitting on spaces if ICU can't load.
  List<String> _khmer(String text) {
    if (_icuFailed) return _khmerSpaceTokens(text);
    try {
      _icu ??= IcuTokenizer();
      final tokens = _tileTokens(text, _icu!.tokenise(text));
      if (!_khmerSampleLogged) {
        _khmerSampleLogged = true;
        log('  Khmer tokenizer: ICU (${tokens.length} tokens in first cue): '
            '${tokens.take(8).join(' | ')}');
      }
      return tokens;
    } catch (e) {
      _icuFailed = true;
      _warnOnce('khmer', e);
      return _khmerSpaceTokens(text);
    }
  }

  void dispose() {}
}
