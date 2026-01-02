import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

class CustomFontLoader {
  static final Map<String, String> _loadedFonts = {};
  static final Set<String> _customFonts = {};
  
  static List<String> get loadedFonts => _loadedFonts.keys.toList()..sort();
  static List<String> get customFonts => _customFonts.toList()..sort();

  static Future<void> loadFonts() async {
    try {
      
      if (Platform.isAndroid) {
        await _loadFontsFromAssets();
      } else {
        await _loadFontsFromFileSystem();
      }
      
      print('Successfully loaded ${_loadedFonts.length} fonts');
    } catch (e, stackTrace) {
      print('Error in loadFonts: $e');
      print('Stack trace: $stackTrace');
    }
  }

  static Future<void> loadCustomFonts(String directory) async {
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
      
      print('Found ${fontFiles.length} custom font files');
      
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
          _customFonts.add(fontName);
          
          print('Loaded custom font: $fontName');
        } catch (e) {
          print('Error loading ${path.basename(fontFile.path)}: $e');
        }
      }
      
      print('Loaded ${_customFonts.length} custom fonts');
    } catch (e) {
      print('Error loading custom fonts: $e');
      rethrow;
    }
  }

  static Future<void> _loadFontsFromAssets() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      
      final fontPaths = <String>[];
      final regex = RegExp(r'"([^"]*\.(?:ttf|otf|ttc))"');
      final matches = regex.allMatches(manifestContent);
      
      for (final match in matches) {
        final fontPath = match.group(1);
        if (fontPath != null && !fontPath.startsWith('packages/')) {
          fontPaths.add(fontPath);
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
          
          if (loaded % 500 == 0) {
            print('Loaded $loaded fonts...');
          }
        } catch (e) {
          print('Error loading font $fontPath: $e');
        }
      }
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
    
    print('Found ${fontFiles.length} font files');
    
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
          print('Loaded $loaded fonts...');
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
      final resourcesDir = Directory(path.join(appDir.parent.path, 'Resources', 'fonts'));
      
      if (await resourcesDir.exists()) {
        return resourcesDir.path;
      }
    } else if (Platform.isLinux) {
      final executablePath = Platform.resolvedExecutable;
      final appDir = path.dirname(executablePath);
      
      var fontsDir = Directory(path.join(appDir, '..', 'data', 'fonts'));
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
      final fontsDir = Directory(path.join(appDir, 'data', 'fonts'));
      
      if (await fontsDir.exists()) {
        return fontsDir.path;
      }
    }
    
    return null;
  }

  static String _extractFontName(String fontPath) {
    final fileName = path.basenameWithoutExtension(fontPath);
    
    final cleaned = fileName.trim();
    
    return cleaned.isNotEmpty ? cleaned : fileName;
  }

  static List<String> getAvailableFonts() {
    return loadedFonts;
  }
}