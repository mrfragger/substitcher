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
    'af': 'Afrikaans',
    'sq': 'Albanian (Shqip)',
    'am': 'Amharic (አማርኛ)',
    'ar': 'Arabic (العربية)',
    'hy': 'Armenian (Հայերեն)',
    'az': 'Azerbaijani (Azərbaycan)',
    'be': 'Belarusian (Беларуская)',
    'bn': 'Bengali (বাংলা)',
    'bho': 'Bhojpuri (भोजपुरी)',
    'bs': 'Bosnian (Bosanski)',
    'bg': 'Bulgarian (Български)',
    'my': 'Burmese (မြန်မာ)',
    'ca': 'Catalan (Català)',
    'zh': 'Chinese - Simplified (简体)',
    'zh-hant': 'Chinese - Traditional (繁體)',
    'yue': 'Chinese - Cantonese (粵語)',
    'hr': 'Croatian (Hrvatski)',
    'cs': 'Czech (Čeština)',
    'da': 'Danish (Dansk)',
    'nl': 'Dutch (Nederlands)',
    'et': 'Estonian (Eesti)',
    'fil': 'Filipino (Tagalog)',
    'fi': 'Finnish (Suomi)',
    'fr': 'French (Français)',
    'ka': 'Georgian (ქართული)',
    'de': 'German (Deutsch)',
    'el': 'Greek (Ελληνικά)',
    'gu': 'Gujarati (ગુજરાતી)',
    'ha': 'Hausa (هَرْشٜىٰن هَوْسَا)',
    'he': 'Hebrew (עברית)',
    'iw': 'Hebrew (עברית)',
    'hi': 'Hindi (हिन्दी)',
    'hu': 'Hungarian (Magyar)',
    'is': 'Icelandic (Íslenska)',
    'id': 'Indonesian (Bahasa Indonesia)',
    'it': 'Italian (Italiano)',
    'ja': 'Japanese (日本語)',
    'jv': 'Javanese (Basa Jawa)',
    'kn': 'Kannada (ಕನ್ನಡ)',
    'kk': 'Kazakh (Қазақ тілі)',
    'ko': 'Korean (한국어)',
    'ky': 'Kyrgyz (Кыргызча)',
    'lo': 'Lao (ລາວ)',
    'lv': 'Latvian (Latviešu)',
    'lt': 'Lithuanian (Lietuvių)',
    'mk': 'Macedonian (Македонски)',
    'ms': 'Malay (Bahasa Melayu)',
    'ml': 'Malayalam (മലയാളം)',
    'mt': 'Maltese (Malti)',
    'mr': 'Marathi (मराठी)',
    'mn': 'Mongolian (Монгол)',
    'ne': 'Nepali (नेपाली)',
    'nb': 'Norwegian (Norsk bokmål)',
    'fa': 'Persian (فارسی)',
    'pl': 'Polish (Polski)',
    'pt': 'Portuguese (Português)',
    'pt-br': 'Portuguese - Brazil (Português Brasil)',
    'pt-pt': 'Portuguese - Portugal (Português Portugal)',
    'pa': 'Punjabi (ਪੰਜਾਬੀ)',
    'ro': 'Romanian (Română)',
    'ru': 'Russian (Русский)',
    'sr': 'Serbian (Српски)',
    'sk': 'Slovak (Slovenčina)',
    'sl': 'Slovenian (Slovenščina)',
    'es': 'Spanish (Español)',
    'sw': 'Swahili (Kiswahili)',
    'sv': 'Swedish (Svenska)',
    'tg': 'Tajik (Тоҷикӣ)',
    'ta': 'Tamil (தமிழ்)',
    'te': 'Telugu (తెలుగు)',
    'th': 'Thai (ไทย)',
    'tr': 'Turkish (Türkçe)',
    'tk': 'Turkmen (Türkmençe)',
    'uk': 'Ukrainian (Українська)',
    'ur': 'Urdu (اردو)',
    'ug': 'Uyghur (ئۇيغۇرچە)',
    'uz': 'Uzbek (Oʻzbekcha)',
    'vi': 'Vietnamese (Tiếng Việt)',
  };
}