import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:characters/characters.dart';
import 'package:dart_jieba/dart_jieba.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tiny_segmenter_dart/tiny_segmenter_dart.dart';
import 'package:word_thai_split/word_thai_split.dart';
import 'package:betto_icu/betto_icu.dart';

typedef LogFn = void Function(String message);

class QuranTokenizers {
  QuranTokenizers({required this.pythonExecutable, required this.log});

  final String pythonExecutable;
  final LogFn log;

  static const String _jiebaAsset = 'assets/jieba/dict.dgz';
  static const String _jiebaTempName = 'jieba_dict.dgz';

  JiebaSegmenter? _jieba;
  TinySegmenter? _tiny;
  Process? _khmerProc;
  StreamIterator<String>? _khmerLines;
  bool _khmerFailed = false;
  bool _khmerSampleLogged = false;
  final Set<String> _warned = {};
  IcuTokenizer? _icu;
  bool _icuFailed = true; // ICU drops Khmer combining marks; use Python instead
  bool _icuSampleLogged = false;

  // khmer_segmenter.tokenize() returns a space-separated STRING, not a list,
  // so split it here and always send a JSON list back to Dart.
  static const String _khmerScript = r'''
import sys, json, re
sys.stdin.reconfigure(encoding='utf-8')
sys.stdout.reconfigure(encoding='utf-8')
from khmer_segmenter import Tokenizer
t = Tokenizer(seg_type="com")
for line in sys.stdin:
    text = line.rstrip("\n")
    r = t.tokenize(text)
    if isinstance(r, str):
        r = [w for w in re.split("[\u200b ]+", r) if w]
    print(json.dumps(list(r), ensure_ascii=False), flush=True)
''';

  void _warnOnce(String script, Object e) {
    if (_warned.add(script)) {
      log('  WARNING: $script tokenizer failed ($e) — using fallback');
    }
  }

  /// Fallback for Khmer: split on spaces so cuts never land inside a word.
  List<String> _khmerSpaceTokens(String text) =>
      text.split(RegExp(r'[ \u200b]+')).where((w) => w.isNotEmpty).toList();

  Future<List<String>> tokenize(String text, String script) async {
    try {
      switch (script) {
        case 'chinese':
          _jieba ??= await _loadJieba();
          return _jieba!.cut(text).map((e) => e.toString()).toList();
        case 'japanese':
          _tiny ??= TinySegmenter();
          return _tiny!.segment(text);
        case 'korean':
          return text.split(' ');
        case 'thai':
          final t = await WordThaiSplit.split(text);
          if (_warned.add('thai-sample')) {
            log('  Thai sample tokens (${t.length}): ${t.take(10).join(' | ')}');
          }
          return t;
        case 'khmer':
          return await _khmer(text);
      }
    } catch (e) {
      _warnOnce(script, e);
    }
    return script == 'khmer' ? _khmerSpaceTokens(text) : text.characters.toList();
  }

  /// dart_jieba reads its dictionary from the filesystem, so copy the bundled
  /// asset to the temp directory once and point it there.
  Future<JiebaSegmenter> _loadJieba() async {
    final tmp = await getTemporaryDirectory();
    final file = File(p.join(tmp.path, _jiebaTempName));
    if (!await file.exists() || await file.length() == 0) {
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

  Future<List<String>> _khmer(String text) async {
    if (!_icuFailed) {
      try {
        _icu ??= IcuTokenizer();
        final t = _icu!.tokenise(text).toList(); // VERIFY: method name per README
        if (!_icuSampleLogged) {
          _icuSampleLogged = true;
          log('  Khmer ICU sample tokens (${t.length}): ${t.take(8).join(' | ')}');
        }
        if (t.isNotEmpty) return t;
      } catch (e) {
        _icuFailed = true;
        log('  WARNING: ICU tokenizer failed ($e) — falling back to Python khmer-segmenter');
      }
    }
    if (_khmerFailed) return _khmerSpaceTokens(text);
    try {
      if (_khmerProc == null) {
        final check = await Process.run(pythonExecutable, ['-c', 'import khmer_segmenter']);
        if (check.exitCode != 0) {
          log('  Installing khmer-segmenter...');
          final pip = await Process.run(
            Platform.isWindows ? 'pip' : 'pip3',
            ['install', 'khmer-segmenter'],
          );
          if (pip.exitCode != 0) {
            throw Exception('khmer-segmenter not installed. Run: pip install khmer-segmenter');
          }
        }
        final proc = await Process.start(
          pythonExecutable,
          ['-u', '-c', _khmerScript],
          environment: {'PYTHONIOENCODING': 'utf-8'},
        );
        proc.stderr.drain<void>();
        _khmerProc = proc;
        _khmerLines = StreamIterator(
          proc.stdout.transform(utf8.decoder).transform(const LineSplitter()),
        );
      }
      _khmerProc!.stdin.writeln(text.replaceAll('\n', ' '));
      await _khmerProc!.stdin.flush();
      if (!await _khmerLines!.moveNext()) throw Exception('Python tokenizer closed');
      final tokens = (jsonDecode(_khmerLines!.current) as List).cast<String>();
      if (!_khmerSampleLogged) {
        _khmerSampleLogged = true;
        log('  Khmer sample tokens (${tokens.length}): ${tokens.take(8).join(' | ')}');
      }
      return tokens;
    } catch (e) {
      _khmerFailed = true;
      _warnOnce('khmer', e);
      return _khmerSpaceTokens(text);
    }
  }

  void dispose() {
    _khmerProc?.kill();
    _khmerProc = null;
  }
}
