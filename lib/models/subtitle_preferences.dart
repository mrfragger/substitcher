import 'package:shared_preferences/shared_preferences.dart';

class SubtitlePreferences {
  static const String _defaultLangKey = 'subtitle_default_language';
  static const String _enabledLangsKey = 'subtitle_enabled_languages';
  static const String _autoTranslateKey = 'subtitle_auto_translate';
  static const String _translateTargetKey = 'subtitle_translate_target';
  
  String defaultLanguage;
  List<String> enabledLanguages;
  bool autoTranslate;
  String translateTarget;
  
  SubtitlePreferences({
    this.defaultLanguage = 'en',
    this.enabledLanguages = const ['en', 'ar', 'es', 'fr', 'de', 'ja', 'ko', 'ru', 'pt', 'hi'],
    this.autoTranslate = false,
    this.translateTarget = 'en',
  });
  
  static Future<SubtitlePreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    final defaultLang = prefs.getString(_defaultLangKey) ?? 'en';
    final enabledLangs = prefs.getStringList(_enabledLangsKey) ?? 
                        ['en', 'ar', 'es', 'fr', 'de', 'ja', 'ko', 'ru', 'pt', 'hi'];
    final autoTranslate = prefs.getBool(_autoTranslateKey) ?? false;
    final translateTarget = prefs.getString(_translateTargetKey) ?? 'en';
    
    return SubtitlePreferences(
      defaultLanguage: defaultLang,
      enabledLanguages: enabledLangs,
      autoTranslate: autoTranslate,
      translateTarget: translateTarget,
    );
  }
  
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultLangKey, defaultLanguage);
    await prefs.setStringList(_enabledLangsKey, enabledLanguages);
    await prefs.setBool(_autoTranslateKey, autoTranslate);
    await prefs.setString(_translateTargetKey, translateTarget);
  }
  
  static const Map<String, String> availableLanguages = {
    'en': 'English',
    'ar': 'Arabic',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese (Simplified)',
    'zh-Hant': 'Chinese (Traditional)',
    'ru': 'Russian',
    'pt': 'Portuguese',
    'hi': 'Hindi',
    'it': 'Italian',
    'tr': 'Turkish',
    'nl': 'Dutch',
    'pl': 'Polish',
    'uk': 'Ukrainian',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'id': 'Indonesian',
    'he': 'Hebrew',
    'fa': 'Persian',
    'ur': 'Urdu',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'sw': 'Swahili',
  };
}