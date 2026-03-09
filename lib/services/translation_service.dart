import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static const int _port = 18033;
  static const String _baseUrl = 'http://127.0.0.1:$_port';

  Process? _serverProcess;
  bool _serverRunning = false;
  String? _llamaExecutablePath;
  String? _modelPath;

  String sourceLanguage = 'English';
  String fallbackSourceLanguage = 'Arabic';
  List<String> selectedLanguages = [];

  static const List<String> availableLanguages = [
    'English',
    'Arabic',
    'Dutch',
    'French',
    'German',
    'Italian', 
    'Portuguese', 
    'Spanish',
    'Swedish',
    'Russian', 
    'Chinese',
    'Japanese', 
    'Korean',
    'Thai',
    'Vietnamese',
    // 'Filipino',
    'Indonesian',
    'Bengali',
    // 'Hindi',
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _llamaExecutablePath = prefs.getString('llama_executable_path');
    _modelPath = prefs.getString('translation_model_path');
    sourceLanguage = prefs.getString('translation_source_language') ?? 'English';
  
    final saved = prefs.getStringList('translation_selected_languages') ?? [];
    selectedLanguages = saved
        .where((lang) => availableLanguages.contains(lang))
        .toList();
  
    if (_llamaExecutablePath == null || !File(_llamaExecutablePath!).existsSync()) {
      _llamaExecutablePath = await _autoDetectLlama();
    }
  
    await saveSettings();
  }
  
  Future<String?> _autoDetectLlama() async {
    final bundled = getBundledLlamaPath();
    if (bundled != null && File(bundled).existsSync()) return bundled;
  
    final candidates = Platform.isWindows
        ? [
            r'C:\Program Files\llama.cpp\llama-server.exe',
            r'C:\llama.cpp\llama-server.exe',
          ]
        : [
            '/usr/local/bin/llama-server',
            '/usr/bin/llama-server',
            '/opt/homebrew/bin/llama-server',
          ];
  
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
  
    if (!Platform.isWindows) {
      final result = await Process.run('which', ['llama-server']);
      if (result.exitCode == 0) {
        final p = (result.stdout as String).trim();
        if (p.isNotEmpty && File(p).existsSync()) return p;
      }
    }
  
    return null;
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (_llamaExecutablePath != null) {
      prefs.setString('llama_executable_path', _llamaExecutablePath!);
    }
    if (_modelPath != null) {
      prefs.setString('translation_model_path', _modelPath!);
    }
    prefs.setString('translation_source_language', sourceLanguage);
    prefs.setStringList('translation_selected_languages', selectedLanguages);
  }

  String? get llamaExecutablePath => _llamaExecutablePath;
  String? get modelPath => _modelPath;
  bool get serverRunning => _serverRunning;

  Future<void> setLlamaExecutable(String p) async {
    _llamaExecutablePath = p;
    await saveSettings();
  }

  Future<void> setModelPath(String p) async {
    _modelPath = p;
    await saveSettings();
  }

  String? getBundledLlamaPath() {
    if (Platform.isMacOS) {
      final execDir = path.dirname(Platform.resolvedExecutable);
      return path.join(execDir, '..', 'Resources', 'llama', 'llama-server');
    } else if (Platform.isLinux) {
      final execDir = path.dirname(Platform.resolvedExecutable);
      return path.join(execDir, 'llama', 'llama-server');
    } else if (Platform.isWindows) {
      final execDir = path.dirname(Platform.resolvedExecutable);
      return path.join(execDir, 'llama', 'llama-server.exe');
    }
    return null;
  }

  Future<bool> startServer() async {
    if (_serverRunning) return true;

    final execPath = _llamaExecutablePath ?? getBundledLlamaPath();
    if (execPath == null || !File(execPath).existsSync()) {
      throw Exception('llama-server executable not found at: $execPath');
    }
    if (_modelPath == null || !File(_modelPath!).existsSync()) {
      throw Exception('Translation model not found at: $_modelPath');
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', execPath]);
    }

    _serverProcess = await Process.start(
      execPath,
      [
        '--model', _modelPath!,
        '--no-jinja',
        '--chat-template', 'chatml',
        '--ctx-size', '2048',
        '--host', '127.0.0.1',
        '--port', '$_port',
        '--flash-attn', 'on',
        '-ngl', '99',
        '--parallel', '1',
        '--no-cache-prompt',
        '--cache-ram', '0',
      ],
      environment: Platform.isMacOS
          ? {'GGML_METAL_PATH_RESOURCES': path.dirname(execPath)}
          : null,
    );

    _serverProcess!.stdout.drain();
    _serverProcess!.stderr.drain();

    final client = HttpClient();
    for (int i = 0; i < 240; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        final req = await client.get('127.0.0.1', _port, '/health')
            .timeout(const Duration(seconds: 1));
        final resp = await req.close();
        if (resp.statusCode == 200) {
          _serverRunning = true;
          client.close();
          return true;
        }
      } catch (_) {}
    }
    client.close();
    throw Exception('llama-server did not start within 120 seconds');
  }

  Future<void> stopServer() async {
    if (_serverProcess != null) {
      _serverProcess!.kill(ProcessSignal.sigterm);
      await Future.delayed(const Duration(seconds: 1));
      _serverProcess!.kill(ProcessSignal.sigkill);
      _serverProcess = null;
    }
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/IM', 'llama-server.exe']);
    } else {
      await Process.run('pkill', ['-9', 'llama-server']);
    }
    _serverRunning = false;
  }


  String _cacheKey(String text, String language, String modelName) {
    final input = '$text|$language|$modelName';
    return md5.convert(utf8.encode(input)).toString();
  }

  String _modelSafeName() {
    if (_modelPath == null) return 'unknown';
    return path.basenameWithoutExtension(_modelPath!)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  }

  Future<File> _getCacheFile(String vttPath) async {
    final dir = path.dirname(vttPath);
    final cacheDir = Directory(path.join(dir, 'translation_cache'));
    await cacheDir.create(recursive: true);
    final base = path.basenameWithoutExtension(vttPath);
    return File(path.join(cacheDir.path, '${base}_cache.jsonl'));
  }

  Future<Map<String, String>> _loadCache(String vttPath) async {
    final file = await _getCacheFile(vttPath);
    if (!file.existsSync()) return {};
    final result = <String, String>{};
    for (final line in await file.readAsLines()) {
      try {
        final obj = jsonDecode(line) as Map<String, dynamic>;
        result[obj['key'] as String] = obj['value'] as String;
      } catch (_) {}
    }
    return result;
  }

  Future<void> _appendToCache(
      String vttPath, String key, String value) async {
    final file = await _getCacheFile(vttPath);
    await file.writeAsString(
      '${jsonEncode({'key': key, 'value': value})}\n',
      mode: FileMode.append,
    );
  }

  String cacheKeyPublic(String text, String language) =>
      _cacheKey(text, language, _modelSafeName());
  
  Future<Map<String, String>> loadCachePublic(String vttPath) =>
      _loadCache(vttPath);

  Future<bool> isHuggingFaceCliAvailable() async {
    final result = await Process.run('which', ['huggingface-cli']);
    return result.exitCode == 0;
  }
  
  Future<Process> startModelDownload(String outputDir) async {
    final useHfCli = await isHuggingFaceCliAvailable();
  
    if (useHfCli) {
      return Process.start('huggingface-cli', [
        'download',
        'mradermacher/translategemma-4b-it-GGUF',
        'translategemma-4b-it.Q4_K_M.gguf',
        '--local-dir', outputDir,
      ]);
    } else {
      return Process.start('wget', [
        '-c',
        'https://huggingface.co/mradermacher/translategemma-4b-it-GGUF/resolve/main/translategemma-4b-it.Q4_K_M.gguf',
        '-O', '$outputDir/translategemma-4b-it.Q4_K_M.gguf',
      ]);
    }
  }

  String _cleanTranslation(String text) {
    var cleaned = text
        .replaceAll('/no_think', '')
        .replaceAll('<|im_end|>', '')
        .replaceAll('<|im_start|>', '')
        .replaceAll('<end_of_turn>', '')
        .replaceAll('<eos>', '')
        .replaceAll('</s>', '')
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .trim();
    
    if (cleaned.length > 300) {
      cleaned = cleaned.substring(0, 300).trim();
    }
    
    return cleaned;
  }
  
  Future<Map<String, String>> translateLine(
    String text,
    List<String> languages,
    String vttPath,
    Map<String, String> cache,
  ) async {
      final result = <String, String>{};
      final model = _modelSafeName();
  
      final needTranslation = <String>[];
      for (final lang in languages) {
        final key = _cacheKey(text, lang, model);
        if (cache.containsKey(key)) {
          result[lang] = cache[key]!;
        } else {
          needTranslation.add(lang);
        }
      }
  
      if (needTranslation.isEmpty) return result;
  
      if (!_serverRunning) {
        throw Exception('Translation server is not running');
      }
  
      final langList = needTranslation.join(', ');
      
      final prompt =
          'Translate the following subtitle line from $sourceLanguage into these languages: $langList\n\n'
          'For each language, provide the translation on a separate line in this exact format:\n'
          'Language: Translation\n\n'
          'Maintain the original meaning and natural conversational tone. '
          'Do not add romanization, transliteration or pronunciation guides in parentheses. '
          'Do not add any extra text, notes or explanations.\n\n'
          'Subtitle line:\n$text';
  
      final client = HttpClient();
      try {
        final req = await client
            .post('127.0.0.1', _port, '/v1/chat/completions')
            .timeout(const Duration(seconds: 240));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'model': 'translategemma',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
          'stream': false,
          'max_tokens': 800,  // 26 languages × ~30 tokens each = ~780 max
          
        }));
  
        final resp = await req.close().timeout(const Duration(seconds: 240));
        final body = await resp.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final content = json['choices'][0]['message']['content'] as String;
  
        for (final line in content.split('\n')) {
          final colonIdx = line.indexOf(':');
          if (colonIdx < 0) continue;
          final langName = line.substring(0, colonIdx).trim();
          final translation = _cleanTranslation(line.substring(colonIdx + 1));
          if (translation.isEmpty) continue;
  
          String? matched;
          for (final requested in needTranslation) {
            if (langName.toLowerCase() == requested.toLowerCase() ||
                langName.toLowerCase().contains(requested.toLowerCase()) ||
                requested.toLowerCase().contains(langName.toLowerCase())) {
              matched = requested;
              break;
            }
          }
          if (matched != null) {
            result[matched] = translation;
            final key = _cacheKey(text, matched, model);
            cache[key] = translation;
            await _appendToCache(vttPath, key, translation);
          }
        }
  
        for (final lang in needTranslation) {
          result.putIfAbsent(lang, () => text);
        }
      } finally {
        client.close();
      }
  
      return result;
    }
 
  List<Map<String, String>> parseVtt(String content) {
    final cues = <Map<String, String>>[];
    final lines = content.split('\n');
    int i = 0;

    while (i < lines.length && !lines[i].trim().startsWith('WEBVTT')) {
      i++;
    }
    i++;

    while (i < lines.length) {
      final line = lines[i].trim();

      if (line.isEmpty) {
        i++;
        continue;
      }

      String? indexLine;
      String? timestampLine;

      if (line.contains('-->')) {
        timestampLine = line;
      } else {
        indexLine = line;
        i++;
        if (i < lines.length && lines[i].trim().contains('-->')) {
          timestampLine = lines[i].trim();
        } else {
          i++;
          continue;
        }
      }
      i++;

      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        textLines.add(lines[i].trim());
        i++;
      }

      if (timestampLine != null && textLines.isNotEmpty) {
        cues.add({
          'index': indexLine ?? '',
          'timestamp': timestampLine,
          'text': textLines.join('\n'),
        });
      }
    }

    return cues;
  }

  Future<void> writeTranslatedVtt(
    String originalVttPath,
    String language,
    List<Map<String, String>> cues,
    Map<int, String> translations, // cue index -> translated text
  ) async {
    final langSafe = language
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final base = path.basenameWithoutExtension(originalVttPath);
    final dir = path.dirname(originalVttPath);
    final outDir = Directory(path.join(dir, 'translated_vtt'));
    await outDir.create(recursive: true);
    final outPath = path.join(outDir.path, '$base.$langSafe.vtt');

    final buf = StringBuffer();
    buf.writeln('WEBVTT');
    buf.writeln();

    for (int i = 0; i < cues.length; i++) {
      final cue = cues[i];
      if (cue['index']!.isNotEmpty) {
        buf.writeln(cue['index']);
      }
      buf.writeln(cue['timestamp']);
      buf.writeln(translations[i] ?? cue['text']);
      buf.writeln();
    }

    await File(outPath).writeAsString(buf.toString());
  }

  Future<String> testServer() async {
    final execPath = _llamaExecutablePath ?? getBundledLlamaPath();
    if (execPath == null) return 'No llama-server path configured';
    if (!File(execPath).existsSync()) return 'File not found: $execPath';

    try {
      final result = await Process.run(execPath, ['--version'],
          stdoutEncoding: utf8, stderrEncoding: utf8);
      return 'Path: $execPath\n'
          'Exit: ${result.exitCode}\n'
          'stdout: ${result.stdout}\n'
          'stderr: ${result.stderr}';
    } catch (e) {
      return 'Error running binary: $e';
    }
  }
}