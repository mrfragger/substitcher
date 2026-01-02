import 'dart:io';
import 'package:path/path.dart' as path;
import 'font_database.dart';
import 'font_alternates_data.dart';
import '../models/color_palette.dart';

class SubtitleTransformer {
  static const _arabicToTibetan = {
    '0': '༳', '1': '༪', '2': '༫', '3': '༬', '4': '༭',
    '5': '༮', '6': '༯', '7': '༰', '8': '༱', '9': '༲',
  };
  
  static const _arabicToEasternArabic = {
    '0': '٠', '1': '١', '2': '٢', '3': '٣', '4': '٤',
    '5': '٥', '6': '٦', '7': '٧', '8': '٨', '9': '٩',
  };
  
  static Future<String> convertToDemo(String inputPath, String fontName) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Subtitle file not found: $inputPath');
    }
    
    final dir = path.dirname(inputPath);
    final baseName = path.basenameWithoutExtension(inputPath);
    final ext = path.extension(inputPath);
    final outputPath = path.join(dir, '$baseName.demofont$ext');
    
    final lines = await file.readAsLines();
    final outputLines = <String>[];
    
    for (var line in lines) {
      outputLines.add(_replaceTextForDemo(line));
    }
    
    final outputFile = File(outputPath);
    await outputFile.writeAsString(outputLines.join('\n'));
    
    return outputPath;
  }
  
  static Future<String> fixMissingLigatures(String inputPath, String fontName) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Subtitle file not found: $inputPath');
    }
    
    final metadata = FontDatabase.getMetadata(fontName);
    if (metadata == null || !metadata.hasMissingLigatures()) {
      throw Exception('Font $fontName does not have missing ligature data');
    }
    
    final dir = path.dirname(inputPath);
    final baseName = path.basenameWithoutExtension(inputPath);
    final ext = path.extension(inputPath);
    final outputPath = path.join(dir, '$baseName.demomiss$ext');
    
    final lines = await file.readAsLines();
    final outputLines = <String>[];
    
    for (var line in lines) {
      var processedLine = _replaceTextForDemo(line);
      processedLine = _fixLigatures(processedLine, metadata.ligaturePairs!);
      outputLines.add(processedLine);
    }
    
    final outputFile = File(outputPath);
    await outputFile.writeAsString(outputLines.join('\n'));
    
    return outputPath;
  }

  static Future<String> convertToUppercase(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Subtitle file not found: $inputPath');
    }
    
    final dir = path.dirname(inputPath);
    final baseName = path.basenameWithoutExtension(inputPath);
    final ext = path.extension(inputPath);
    final outputPath = path.join(dir, '$baseName.uppercase$ext');
    
    final lines = await file.readAsLines();
    final outputLines = <String>[];
    
    for (var line in lines) {
      outputLines.add(line.toUpperCase());
    }
    
    final outputFile = File(outputPath);
    await outputFile.writeAsString(outputLines.join('\n'));
    
    return outputPath;
  }

  static Future<String> convertToDemoUpper(String inputPath, String fontName) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Subtitle file not found: $inputPath');
    }
    
    final dir = path.dirname(inputPath);
    final baseName = path.basenameWithoutExtension(inputPath);
    final ext = path.extension(inputPath);
    final outputPath = path.join(dir, '$baseName.demofontupper$ext');
    
    final lines = await file.readAsLines();
    final outputLines = <String>[];
    
    final metadata = FontDatabase.getMetadata(fontName);
    
    for (var line in lines) {
      var processedLine = _replaceTextForDemo(line).toUpperCase();
      if (metadata?.hasMissingLigatures() ?? false) {
        processedLine = _fixLigatures(processedLine, metadata!.ligaturePairs!);
      }
      outputLines.add(processedLine);
    }
    
    final outputFile = File(outputPath);
    await outputFile.writeAsString(outputLines.join('\n'));
    
    return outputPath;
  }

  static Future<String> convertToSeesawCase(String inputPath) async {
    final file = File(inputPath);
    if (!await file.exists()) {
      throw Exception('Subtitle file not found: $inputPath');
    }
    
    final dir = path.dirname(inputPath);
    final baseName = path.basenameWithoutExtension(inputPath);
    final ext = path.extension(inputPath);
    final outputPath = path.join(dir, '$baseName.seesawcase$ext');
    
    final lines = await file.readAsLines();
    final outputLines = <String>[];
    
    for (var line in lines) {
      outputLines.add(_seesawCaseTransform(line));
    }
    
    final outputFile = File(outputPath);
    await outputFile.writeAsString(outputLines.join('\n'));
    
    return outputPath;
  }
  
  static String _replaceTextForDemo(String input) {
    input = input.replaceAllMapped(
      RegExp(r'^(\d\d):(\d\d)\.(\d\d\d) --> (\d\d):(\d\d)\.(\d\d\d)'),
      (match) => '00:${match[1]}:${match[2]}.${match[3]} --> 00:${match[4]}:${match[5]}.${match[6]}',
    );
    
    input = input.replaceAllMapped(
      RegExp(r'^(\d\d):(\d\d)\.(\d\d\d) --> (\d\d):(\d\d):(\d\d)\.(\d\d\d)'),
      (match) => '00:${match[1]}:${match[2]}.${match[3]} --> ${match[4]}:${match[5]}:${match[6]}.${match[7]}',
    );
    
    input = input
        .replaceAll(' 0 ', ' zero ')
        .replaceAll(' 1 ', ' one ')
        .replaceAll(' 2 ', ' two ')
        .replaceAll(' 3 ', ' three ')
        .replaceAll(' 4 ', ' four ')
        .replaceAll(' 5 ', ' five ')
        .replaceAll(' 6 ', ' six ')
        .replaceAll(' 7 ', ' seven ')
        .replaceAll(' 8 ', ' eight ')
        .replaceAll(' 9 ', ' nine ')
        .replaceAll(' 10 ', ' ten ');
    
    input = input
        .replaceAll(' 1st ', ' first ')
        .replaceAll(' 2nd ', ' second ')
        .replaceAll(' 3rd ', ' third ')
        .replaceAll(' 4th ', ' fourth ')
        .replaceAll(' 5th ', ' fifth ')
        .replaceAll(' 6th ', ' sixth ')
        .replaceAll(' 7th ', ' seventh ')
        .replaceAll(' 8th ', ' eighth ')
        .replaceAll(' 9th ', ' ninth ')
        .replaceAll(' 10th ', ' tenth ');
    
    input = input
        .replaceAllMapped(RegExp(r'(:)(\d\d)(\.)(\d\d\d)'), 
            (m) => '${m[1]}${m[2]}PERIODPERIOD${m[4]}')
        .replaceAllMapped(RegExp(r'(\d\d)(:)(\d\d)(:)(\d\d)'),
            (m) => '${m[1]}COLONCOLON${m[3]}COLONCOLON${m[5]}');
    
    final isTimestamp = input.contains(RegExp(
      r'^\d\dCOLONCOLON\d\dCOLONCOLON\d\dPERIODPERIOD\d\d\d --> \d\dCOLONCOLON\d\dCOLONCOLON\d\dPERIODPERIOD\d\d\d'
    ));
    
    if (isTimestamp) {
      input = _replaceWithTibetan(input);
    } else {
      input = _replaceWithEasternArabic(input);
    }
    
    input = input
        .replaceAll(RegExp(r'[#&*+\^,]'), '،')
        .replaceAll('/', '|')
        .replaceAll('%', '÷')
        .replaceAll(r'$', '¥')
        .replaceAll(RegExp(r'[!.]'), '¸')
        .replaceAll(RegExp(r'[:;]'), '؛')
        .replaceAll('?', '؟')
        .replaceAll(RegExp(r'[[\(<]'), '{')
        .replaceAll(' --> ', 'HYPHENHYPHEN')
        .replaceAll("'", '`')
        .replaceAll(RegExp(r'[\])>]'), '}')
        .replaceAll('-', '~')
        .replaceAll('"', '˝')
        .replaceAll('COLONCOLON', ':')
        .replaceAll('HYPHENHYPHEN', ' --> ')
        .replaceAll('PERIODPERIOD', '.');
    
    for (var entry in _arabicToTibetan.entries) {
      input = input.replaceAll(entry.value, entry.key);
    }
    
    return input;
  }

  static Future<String> convertToAlternates(String inputPath, String fontName) async {
      final file = File(inputPath);
      if (!await file.exists()) {
        throw Exception('Subtitle file not found: $inputPath');
      }
      
      if (!FontAlternatesData.hasFontAlternates(fontName)) {
        throw Exception('No alternate characters defined for font: $fontName');
      }
      
      final dir = path.dirname(inputPath);
      final baseName = path.basenameWithoutExtension(inputPath);
      final ext = path.extension(inputPath);
      final outputPath = path.join(dir, '$baseName.alternates$ext');
      
      final lines = await file.readAsLines();
      final outputLines = <String>[];
      
      final metadata = FontDatabase.getMetadata(fontName);
      
      for (var line in lines) {
        var processedLine = _applyFontAlternates(line, fontName);
        
        if (metadata?.hasMissingLigatures() ?? false) {
          processedLine = _fixLigatures(processedLine, metadata!.ligaturePairs!);
        }
        
        outputLines.add(processedLine);
      }
      
      final outputFile = File(outputPath);
      await outputFile.writeAsString(outputLines.join('\n'));
      
      return outputPath;
    }
  
    static String _applyFontAlternates(String input, String fontName) {
      if (input.startsWith('WEBVTT') || 
          RegExp(r'^\d\d:\d\d:\d\d\.\d\d\d -->').hasMatch(input)) {
        return input;
      }
      
      var result = input;
      
      final anyPos = FontAlternatesData.anyPosition[fontName];
      if (anyPos != null) {
        for (var entry in anyPos.entries) {
          result = result.replaceAll(entry.key, entry.value);
        }
      }
      
      final notEnd = FontAlternatesData.notAtEnd[fontName];
      if (notEnd != null) {
        for (var entry in notEnd.entries) {
          result = result.replaceAllMapped(
            RegExp('${RegExp.escape(entry.key)}(?=[^\\s\\p{P}])', unicode: true),
            (match) => entry.value,
          );
        }
      }
      
      final onlyEnd = FontAlternatesData.onlyAtEnd[fontName];
      if (onlyEnd != null) {
        for (var entry in onlyEnd.entries) {
          result = result.replaceAllMapped(
            RegExp('${RegExp.escape(entry.key)}(?=[\\s\\p{P}]|\$)', unicode: true),
            (match) => entry.value,
          );
        }
      }
      
      return result;
    } 

  static String _seesawCaseTransform(String text) {
    if (text.startsWith('WEBVTT')) {
      return text;
    }
    
    if (RegExp(r'^\d\d:\d\d:\d\d\.\d\d\d -->').hasMatch(text)) {
      return text;
    }
    
    final result = StringBuffer();
    bool uppercase = true;
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
        result.write(uppercase ? char.toUpperCase() : char.toLowerCase());
        uppercase = !uppercase;
      } else {
        result.write(char);
      }
    }
    
    return result.toString();
  }
  
  static String _replaceWithTibetan(String input) {
    for (var entry in _arabicToTibetan.entries) {
      input = input.replaceAll(entry.key, entry.value);
    }
    return input;
  }
  
  static String _replaceWithEasternArabic(String input) {
    for (var entry in _arabicToEasternArabic.entries) {
      input = input.replaceAll(entry.key, entry.value);
    }
    return input;
  }
  
  static String _fixLigatures(String input, List<String> ligaturePairs) {
    const zeroWidthNonJoiner = '\u200C';
    
    for (var pair in ligaturePairs) {
      if (pair.length == 2) {
        final replacement = '${pair[0]}$zeroWidthNonJoiner${pair[1]}';
        input = input.replaceAll(pair, replacement);
      }
    }
    
    return input;
  }
  
  static Future<String> convertToDemoInMemory(String vttContent, String fontName) async {
    final lines = vttContent.split('\n');
    final result = <String>[];
    
    for (var line in lines) {
      result.add(_replaceTextForDemo(line));
    }
    
    return result.join('\n');
  }
  
  static Future<String> convertToDemoUpperInMemory(String vttContent, String fontName) async {
    final lines = vttContent.split('\n');
    final result = <String>[];
    
    final metadata = FontDatabase.getMetadata(fontName);
    
    for (var line in lines) {
      var processedLine = _replaceTextForDemo(line).toUpperCase();
      if (metadata?.hasMissingLigatures() ?? false) {
        processedLine = _fixLigatures(processedLine, metadata!.ligaturePairs!);
      }
      result.add(processedLine);
    }
    
    return result.join('\n');
  }
  
  static Future<String> convertToAlternatesInMemory(String vttContent, String fontName) async {
    if (!FontAlternatesData.hasFontAlternates(fontName)) {
      return vttContent;
    }
    
    final lines = vttContent.split('\n');
    final result = <String>[];
    
    final metadata = FontDatabase.getMetadata(fontName);
    
    for (var line in lines) {
      var processedLine = _applyFontAlternates(line, fontName);
      
      if (metadata?.hasMissingLigatures() ?? false) {
        processedLine = _fixLigatures(processedLine, metadata!.ligaturePairs!);
      }
      
      result.add(processedLine);
    }
    
    return result.join('\n');
  }
  
  static Future<String> fixMissingLigaturesInMemory(String vttContent, String fontName) async {
    final metadata = FontDatabase.getMetadata(fontName);
    if (metadata == null || !metadata.hasMissingLigatures()) {
      return vttContent;
    }
    
    final lines = vttContent.split('\n');
    final result = <String>[];
    
    for (var line in lines) {
      var processedLine = _replaceTextForDemo(line);
      processedLine = _fixLigatures(processedLine, metadata.ligaturePairs!);
      result.add(processedLine);
    }
    
    return result.join('\n');
  }
  
  static String convertToUppercaseInMemory(String vttContent) {
    final lines = vttContent.split('\n');
    final result = <String>[];
    
    for (var line in lines) {
      result.add(line.toUpperCase());
    }
    
    return result.join('\n');
  }
  
  static String convertToSeesawCaseInMemory(String vttContent) {
    final lines = vttContent.split('\n');
    final result = <String>[];
    
    for (var line in lines) {
      result.add(_seesawCaseTransform(line));
    }
    
    return result.join('\n');
  }
}