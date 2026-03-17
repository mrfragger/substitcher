import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class CustomFontLoader {
  static final Map<String, String> _loadedFonts = {};
  static final Set<String> _customFonts = {};
  static final Set<String> _customFonts2 = {};
  
  static List<String> get loadedFonts => _loadedFonts.keys.toList()..sort();
  static List<String> get customFonts => _customFonts.toList()..sort();
  static List<String> get customFonts2 => _customFonts2.toList()..sort();

  static Future<void> loadFonts() async {
    try {
      if (Platform.isAndroid) {
        await _loadFontsFromAssets();
      } else {
        await _loadFontsFromFileSystem();
      }
    } catch (e, stackTrace) {
      print('Error in loadFonts: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> loadCustomFonts(String directory, {int slot = 1}) async {
    try {
      final dir = Directory(directory);
      final fontFiles = <File>[];
      
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (ext == '.ttf' || ext == '.otf') {
            fontFiles.add(entity);
          }
        }
      }
      
      for (final fontFile in fontFiles) {
        try {
          final fontName = _extractFontName(fontFile.path);
          
          if (_loadedFonts.containsKey(fontName)) {
            continue;
          }
          
          final fontLoader = FontLoader(fontName);
          final bytes = await fontFile.readAsBytes();
          fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
          await fontLoader.load();
          
          _loadedFonts[fontName] = fontFile.path;
          if (slot == 2) {
            _customFonts2.add(fontName);
          } else {
            _customFonts.add(fontName);
          }
          
        } catch (e) {
          print('Error loading ${path.basename(fontFile.path)}: $e');
        }
      }
      
    } catch (e) {
      print('Error loading custom fonts: $e');
      rethrow;
    }
  }
  
  static void clearCustomFonts({int slot = 1}) {
    if (slot == 2) {
      for (final fontName in _customFonts2) {
        _loadedFonts.remove(fontName);
      }
      _customFonts2.clear();
    } else {
      for (final fontName in _customFonts) {
        _loadedFonts.remove(fontName);
      }
      _customFonts.clear();
    }
  }

  static Future<void> _loadFontsFromAssets() async {
    try {
      final String manifestJson = await rootBundle.loadString('AssetManifest.bin.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);
      
      final fontPaths = <String>[];
      
      for (final key in manifest.keys) {
        if (key.startsWith('assets/fonts/') && 
            (key.endsWith('.ttf') || key.endsWith('.otf') || key.endsWith('.ttc'))) {
          fontPaths.add(key);
        }
      }
      
      print('Found ${fontPaths.length} font files in assets');
      
      int loaded = 0;
      for (final fontPath in fontPaths) {
        try {
          final fontName = _extractFontName(fontPath);
          
          if (_loadedFonts.containsKey(fontName)) {
            continue;
          }
          
          final fontLoader = FontLoader(fontName);
          final fontData = await rootBundle.load(fontPath);
          fontLoader.addFont(Future.value(fontData.buffer.asByteData()));
          await fontLoader.load();
          
          _loadedFonts[fontName] = fontPath;
          loaded++;
          
          if (loaded % 100 == 0) {
            print('Loaded $loaded fonts...');
          }
        } catch (e) {
          print('Error loading font $fontPath: $e');
        }
      }
      
      print('Successfully loaded $loaded fonts from assets');
    } catch (e) {
      print('Error loading fonts from assets: $e');
    }
  }

  static Future<void> _loadFontsFromFileSystem() async {
    String? fontsPath = await _getFontsPath();
    
    if (fontsPath == null) {
      print('Fonts directory not found in app bundle');
      return;
    }
    
    print('Loading fonts from: $fontsPath');
    
    final fontsDir = Directory(fontsPath);
    final fontFiles = <File>[];
    
    await for (final entity in fontsDir.list(recursive: false)) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (ext == '.ttf' || ext == '.otf' || ext == '.ttc') {
          fontFiles.add(entity);
        }
      }
    }
        
    int loaded = 0;
    int skipped = 0;
    
    for (final fontFile in fontFiles) {
      try {
        final fontName = _extractFontName(fontFile.path);
        
        if (_loadedFonts.containsKey(fontName)) {
          skipped++;
          continue;
        }
        
        final fontLoader = FontLoader(fontName);
        final bytes = await fontFile.readAsBytes();
        fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await fontLoader.load();
        
        _loadedFonts[fontName] = fontFile.path;
        loaded++;
        
        if (loaded % 500 == 0) {
        }
      } catch (e) {
        print('Error loading ${path.basename(fontFile.path)}: $e');
      }
    }
    
    print('Loaded $loaded fonts (skipped $skipped duplicates)');
  }

  static Future<String?> _getFontsPath() async {
    if (Platform.isMacOS) {
      final executablePath = Platform.resolvedExecutable;
      final appDir = Directory(path.dirname(executablePath));
      
      final flutterAssetsDir = Directory(path.join(
        appDir.parent.path,
        'Frameworks',
        'App.framework',
        'Versions',
        'A',
        'Resources',
        'flutter_assets',
        'assets',
        'fonts'
      ));
      
      print('DEBUG: Looking for fonts at: ${flutterAssetsDir.path}');
      print('DEBUG: Directory exists: ${await flutterAssetsDir.exists()}');
      
      if (await flutterAssetsDir.exists()) {
        final files = await flutterAssetsDir.list().toList();
        print('DEBUG: Found ${files.length} files in fonts directory');
        return flutterAssetsDir.path;
      } else {
        print('DEBUG: Fonts directory NOT found!');
      }
    } else if (Platform.isLinux) {
      final executablePath = Platform.resolvedExecutable;
      final appDir = path.dirname(executablePath);
      
      var fontsDir = Directory(path.join(appDir, 'data', 'flutter_assets', 'assets', 'fonts'));
      if (await fontsDir.exists()) {
        return fontsDir.path;
      }
      
      fontsDir = Directory(path.join(appDir, 'data', 'flutter_assets', 'fonts'));
      if (await fontsDir.exists()) {
        return fontsDir.path;
      }
      
      fontsDir = Directory(path.join(appDir, '..', 'data', 'fonts'));
      if (await fontsDir.exists()) {
        return fontsDir.path;
      }
      
      fontsDir = Directory(path.join(appDir, 'data', 'fonts'));
      if (await fontsDir.exists()) {
        return fontsDir.path;
      }
    } else if (Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      final appDir = path.dirname(executablePath);
      
      final fontsDir = Directory(path.join(appDir, 'data', 'flutter_assets', 'assets', 'fonts'));
      
      print('Windows fonts path: ${fontsDir.path}');
      print('Fonts directory exists: ${await fontsDir.exists()}');
      
      if (await fontsDir.exists()) {
        return fontsDir.path;
      }
      
      print('ERROR: Fonts directory not found at expected location');
    }
    
    return null;
  }

  static String _extractFontName(String fontPath) {
    final fileName = path.basenameWithoutExtension(fontPath);
    
    final decoded = Uri.decodeComponent(fileName);
    
    final cleaned = decoded.trim();
    
    return cleaned.isNotEmpty ? cleaned : fileName;
  }

  static List<String> getAvailableFonts() {
    return loadedFonts;
  }
}