import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

class CustomFontMetadata {
  final String fontName;
  final String baseType; // 'original', 'demo', 'demo123'
  final String caseType; // '', 'UPPERCASE', 'MustBeUppercase'
  
  CustomFontMetadata({
    required this.fontName,
    required this.baseType,
    required this.caseType,
  });
  
  String get displayLabel {
    if (caseType.isEmpty) {
      return baseType;
    }
    return '$baseType → $caseType';
  }
  
  Map<String, dynamic> toJson() => {
    'fontName': fontName,
    'baseType': baseType,
    'caseType': caseType,
  };
  
  factory CustomFontMetadata.fromJson(Map<String, dynamic> json) {
    return CustomFontMetadata(
      fontName: json['fontName'] as String,
      baseType: json['baseType'] as String,
      caseType: json['caseType'] as String? ?? '',
    );
  }
}

class CustomFontMetadataManager {
  static const String _filename = 'custom_font_metadata.json';
  static Map<String, CustomFontMetadata> _metadata = {};
  
  static String get _metadataPath {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return '';
    return path.join(home, '.config', 'substitcher', _filename);
  }
  
  static Future<void> load() async {
    final filePath = _metadataPath;
    if (filePath.isEmpty) return;
    
    final file = File(filePath);
    if (!await file.exists()) return;
    
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      
      _metadata.clear();
      json.forEach((fontName, data) {
        _metadata[fontName] = CustomFontMetadata.fromJson(data as Map<String, dynamic>);
      });
    } catch (e) {
      print('Error loading custom font metadata: $e');
    }
  }
  
  static Future<void> save() async {
    final filePath = _metadataPath;
    if (filePath.isEmpty) return;
    
    final file = File(filePath);
    await file.parent.create(recursive: true);
    
    final json = <String, dynamic>{};
    _metadata.forEach((fontName, metadata) {
      json[fontName] = metadata.toJson();
    });
    
    await file.writeAsString(jsonEncode(json));
  }
  
  static CustomFontMetadata? getMetadata(String fontName) {
    return _metadata[fontName];
  }
  
  static Future<void> setMetadata(String fontName, String baseType, String caseType) async {
    _metadata[fontName] = CustomFontMetadata(
      fontName: fontName,
      baseType: baseType,
      caseType: caseType,
    );
    await save();
  }
  
  static Future<void> removeMetadata(String fontName) async {
    _metadata.remove(fontName);
    await save();
  }
}