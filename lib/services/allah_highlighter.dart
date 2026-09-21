import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Single source of truth for Allah/Lord/Rabb and Muhammad/Messenger/ﷺ
/// highlighting, plus quote/paren/curly/bracket coloring and optional
/// verse-ref detection. Used by QuranPanel, HadeethPanel, the deduction
/// quiz panel, and the related-connections panel.
class AllahHighlighter {
  static const Color muhammadColor = Colors.greenAccent;

  static const List<String> muhammadWords = [
    'Muhammad صلى الله عليه وسلم',
    'Messenger صلى الله عليه وسلم',
    'Prophet Muhammad (ﷺ)',
    "Prophet Muhammad’s",
    'Prophet Muhammad ﷺ',
    'Messenger Muhammad',
    'Prophet Muhammad',
    'Prophet said ﷺ',
    'Muhammad (ﷺ)',
    'Messenger ﷺ',
    'Messenger of',
    "Muhammad's",
    'Prophet ﷺ',
    'Messengers',
    'Messenger',
    'Muhammad',
    'ﷺ',
  ];

  // ---------------------------------------------------------------------
  // Script ranges / detection (kept self-contained here; QuranPanel keeps
  // its own copy too since it uses it for unrelated RTL text-direction
  // detection outside of highlighting).
  // ---------------------------------------------------------------------
  static const Map<String, String> _scriptRanges = {
    'latin': r'a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜɔɛƆƐɣŋʒƔŊƷɩƖʋƲ',
    'cyrillic': r'а-яёА-ЯЁҳқғўЎіӯӀәӘғҒқҚңҢөӨұҰүҮһҺіІ',
    'georgian': r'\u10A0-\u10FF',
    'greek': r'\u0370-\u03FF',
    'arabic': r'\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF',
    'hebrew': r'\u0590-\u05FF',
    'nko': r'\u07C0-\u07FF',
    'bengali': r'\u0980-\u09FF',
    'devanagari': r'\u0900-\u097F',
    'gujarati': r'\u0A80-\u0AFF',
    'kannada': r'\u0C80-\u0CFF',
    'tamil': r'\u0B80-\u0BFF',
    'telugu': r'\u0C00-\u0C7F',
    'malayalam': r'\u0D00-\u0D7F',
    'sinhala': r'\u0D80-\u0DFF',
    'thai': r'\u0E00-\u0E7F',
    'khmer': r'\u1780-\u17FF',
    'myanmar': r'\u1000-\u109F',
    'cjk': r'\u4E00-\u9FFF\u3040-\u30FF',
    'hangul': r'\uAC00-\uD7AF\u1100-\u11FF',
    'ethiopic': r'\u1200-\u137F',
  };

  static const Set<String> _noBoundaryScripts = {
    'cjk', 'thai', 'khmer', 'arabic', 'hangul', 'ethiopic', 'devanagari',
    'gujarati', 'kannada', 'myanmar', 'georgian'
  };

  static String _detectScript(String word) {
    for (final entry in _scriptRanges.entries) {
      if (entry.key == 'latin') continue;
      if (RegExp('[${entry.value}]').hasMatch(word)) return entry.key;
    }
    return 'latin';
  }

  // ---------------------------------------------------------------------
  // Arabic diacritic stripping + letter-shape folding, so verse text with
  // full tashkeel still matches plain dictionary entries.
  // ---------------------------------------------------------------------
  static final RegExp _arabicDiacriticsPattern = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC'
    r'\u06DF-\u06E8\u06EA-\u06ED\u08D3-\u08E1\u08E3-\u08FF\u0640]',
  );

  static String _foldArabicChar(String ch) {
    switch (ch) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
        return 'ا';
      case 'ة':
        return 'ه';
      case 'ى':
        return 'ي';
      default:
        return ch;
    }
  }

  static (String, List<int>) _normalizeArabic(String text) {
    final buffer = StringBuffer();
    final indexMap = <int>[];
    for (int i = 0; i < text.length; i++) {
      if (!_arabicDiacriticsPattern.hasMatch(text[i])) {
        buffer.write(_foldArabicChar(text[i]));
        indexMap.add(i);
      }
    }
    return (buffer.toString(), indexMap);
  }

  static List<(int, int)> _findDiacriticInsensitiveArabicRanges(
      String text, String arabicPattern) {
    if (arabicPattern.isEmpty) return [];
    final (stripped, indexMap) = _normalizeArabic(text);
    final pattern = RegExp(arabicPattern);
    final ranges = <(int, int)>[];
    for (final m in pattern.allMatches(stripped)) {
      if (m.start >= m.end) continue;
      final origStart = indexMap[m.start];
      final origEnd = indexMap[m.end - 1] + 1;
      ranges.add((origStart, origEnd));
    }
    return ranges;
  }

  // ---------------------------------------------------------------------
  // "He"/"His" exclusion logic (only meaningful for English), preventing
  // false positives like "He (Muhammad) said" from being colored as Allah.
  // ---------------------------------------------------------------------
  static const Set<String> _heSingleWordSuppressors = {
    'said', 'asked', 'then', 'takes', 'kept', 'will', 'trusts', 'was',
    'changes', 'wakes', 'replied', 'also',
  };
  static const Set<String> _hePhraseSuppressors = {
    'is devious', 'is deceptive', 'is cunning', '(Muhammad)', '(Muhammad )',
  };
  static const Map<String, String> _allahWordExclusions = {
    'His': r'(?!\s+(?:actual|parents)\b)',
  };

  static const Map<String, String> _muhammadWordExclusions = {
    'Muhammad': r'(?!\s+(?:bin|ibn|b\.)\b)',
  };

  static String get _heExclusionPattern {
    final singles = _heSingleWordSuppressors.map(RegExp.escape).join('|');
    final phrases = _hePhraseSuppressors.map((p) {
      final words = p.split(' ').where((w) => w.isNotEmpty).map(RegExp.escape);
      return words.join(r'\s+');
    }).join('|');
    return '(?!\\s+(?:$singles)\\b)(?!\\s+(?:$phrases)\\b)';
  }

  static String _exclusionFor(String w) {
    if (w == 'He') return _heExclusionPattern;
    return _allahWordExclusions[w] ?? '';
  }

  static const String _latinRange =
      r"a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜɔɛƆƐɣŋʒƔŊƷɩƖʋƲ";

  static String _latinWordPattern(String w) {
    final escaped = RegExp.escape(w);
    final exclusion = _exclusionFor(w);
    return '(?<![$_latinRange])$escaped$exclusion(?![$_latinRange])';
  }

  static String muhammadWordPattern() {
    final words = [...muhammadWords]..sort((a, b) => b.length.compareTo(a.length));
    final patterns = <String>[];
    for (final w in words) {
      final escaped = RegExp.escape(w);
      final exclusion = _muhammadWordExclusions[w] ?? '';
      final startsLatin = RegExp(r'^[a-zA-Z]').hasMatch(w);
      final endsLatin = RegExp(r'[a-zA-Z]$').hasMatch(w);
      final lookbehind = startsLatin ? '(?<![$_latinRange])' : '';
      final lookahead = endsLatin ? '(?![$_latinRange])' : '';
      patterns.add('$lookbehind$escaped$exclusion$lookahead');
    }
    return patterns.join('|');
  }

  // ---------------------------------------------------------------------
  // Word lists by language.
  // ---------------------------------------------------------------------
  static const List<String> _englishBaseWords = [
    'Allah\u2019s', 'Allāh\u2019s', 'Allâh\u2019s',
    'Allah\u02BCs', 'Allāh\u02BCs', 'Allâh\u02BCs',
    "Allah's", "Allāh's", "Allâh's",
    'Allah', 'Allāh', 'Allâh',
    'Lord\u2019s', 'Lord\u02BCs', "Lord's", 'Lord',
  ];
  static const List<String> _englishPronounWords = ['Our', 'Him', 'His', 'He', 'Me'];

  static const Map<String, List<String>> allahWordsByLanguage = {
    'Arabic': [
      'بالله', 'تالله', 'والله', 'فالله', 'لله', 'الله',
      'لربكم', 'لربهم', 'لربنا', 'لربه', 'لربك', 'لربي',
      'بربكم', 'بربهم', 'بربنا', 'بربه', 'بربك', 'بربي',
      'ربكم', 'ربهم', 'ربنا', 'ربه', 'ربها', 'ربك', 'ربي',
    ],
    'Urdu': ['اللہ', 'اللّٰہ', 'پروردگار', 'خدا', 'ربّ', 'رب'],
    'Kurdish': [
      'خوای', 'الله', 'پەروەردگاری', 'پەروەردگار',
      'خودای', 'خودا', 'خوداوەند', 'خوداوەندی',
      'Xwedayê', 'Xwedê',
    ],
    'Pashto': [
      'بالله', 'والله', 'لله', 'الله',
      'خدایه', 'خدای', 'پالونکی',
      'ربه', 'ربك', 'رب',
    ],
    'Persian': [
      'بالله', 'والله', 'لله', 'الله',
      'خداوندا', 'خداوندی', 'خداوند',
      'خدایا', 'خدای', 'خدا',
      'پروردگارا', 'پروردگاری', 'پروردگار',
    ],
    'Uyghur': [
      'ئاللاھقا', 'ئاللاھنىڭ', 'ئاللاھتىن', 'ئاللاھتا', 'ئاللاھقا', 'ئاللاھنى',
      'ئاللاھ',
      'پەرۋەردىگارىڭلار', 'پەرۋەردىگارىڭنىڭ', 'پەرۋەردىگارىنىڭ',
      'پەرۋەردىگارىڭ', 'پەرۋەردىگارىم', 'پەرۋەردىگارى', 'پەرۋەردىگار',
      'رەببىڭنىڭ', 'رەببىنىڭ', 'رەببىڭ', 'رەببىم', 'رەببى', 'رەبب',
      'الله', 'اﷲ',
    ],
    'Hebrew': [
      'אללה',
      'ריבוני', 'ריבונך', 'ריבונו', 'ריבון',
      'ריבי', 'ריבם', 'ריבך', 'ריבנו', 'ריבכם',
      'אלוהי', 'אלוהיו', 'אלוהינו', 'אלוהיך', 'אלוהיכם',
      'אלוה', 'אלוהים',
      'אדוני', 'אדונינו', 'אדוניך', 'אדוניכם',
      'אדון',
      'א-להים', 'א-להיך',
      'השם',
    ],
    'Dari': [
      'بالله', 'والله', 'لله', 'الله',
      'خداوندا', 'خداوندی', 'خداوند',
      'خدایا', 'خدای', 'خدا',
      'پروردگارا', 'پروردگاری', 'پروردگار',
    ],
    'English': [..._englishBaseWords, ..._englishPronounWords],
    'Albanian': [
      'All-llahun', 'All-llahut', 'All-llahu',
      'Allahun', 'Allahut', 'Allahu',
      'Zotin', 'Zotit', 'Zoti',
    ],
    'AkanAsante': ['Nyankopɔn', 'Awurade', 'Wura Nyankopɔn', 'Onyame', 'Allah', 'Allaahu'],
    'Assamese': [
      'আল্লাহৰ', 'আল্লাহে', 'আল্লাহক', 'আল্লাহ্', 'আল্লাহ',
      'প্ৰতিপালকৰ', 'প্ৰতিপালক', 'ৰব',
    ],
    'Azerbaijani': [
      'Allahından', 'Allahınıza', 'Allahınız', 'Allahıma', 'Allahından',
      'Allahdan', 'Allahına', 'Allahını', 'Allahадır', 'Allahadır',
      'Allahım', 'Allahın', 'Allaha', 'Allah',
    ],
    'Belarusian': [
      'Аллаха', 'Аллах',
      'Госпада', 'Госпаду', 'Госпадам', 'Госпадзе', 'Госпад',
    ],
    'Bengali': ['আল্লাহর', 'আল্লাহ্', 'আল্লাহ', 'রব', 'প্রতিপালক'],
    'Bulgarian': ['Аллах', 'Господа', 'Господи', 'Господ', 'Бог'],
    'Burmese': ['အလ္လာဟ်အရှင်မြတ်', 'အလ္လာဟ်', 'အရှင်မြတ်', 'အရှင်'],
    'Bosnian': [
      'Allahovoj', 'Allahova', 'Allahovog', 'Allahovom', 'Allahovih',
      'Allahove', 'Allahovu', 'Allahovi', 'Allahov', 'Allahu', 'Allaha', 'Allah',
    ],
    'Chichewa': ['Allah', 'Mulungu', 'Mbuye'],
    'Chinese': ['安拉', '真主'],
    'ChineseTrad': ['安拉', '真主'],
    'Circassian': [
      'Аллахым', 'Аллах',
      'Аллаhыр', 'Аллаhым', 'Аллаhми', 'Аллаhм',
      'Тхьэм', 'Тхьэр', 'Тхьэ',
    ],
    'Czech': [
      'Alláhovo', 'Alláhův', 'Alláhovu', 'Alláhovi', 'Alláhem', 'Alláha', 'Alláh',
      'Allahovi', 'Allaha',
      'Bůh', 'Boha', 'Bohu',
      'Pána', 'Pánu', 'Pane', 'Pán',
    ],
    'Dagbani': ['Naawuni', 'Duuma'],
    'Finnish': [
      'Allahkin', 'Allahilta', 'Allahille', 'Allahia', 'Allahin', 'Allah',
      'Jumalanne', 'Jumalasta', 'Jumalaa', 'Jumalan', 'Jumala',
      'Herralleni', 'Herraansa', 'Herralleen', 'Herranne', 'Herralta',
      'Herraan', 'Herrani', 'Herrasi', 'Herran', 'Herra',
    ],
    'French': [
      'qu\u2019Allah', 'qu\'Allah', 'd\u2019Allah', 'd\'Allah', 'Allah', 'Seigneur',
    ],
    'Fula': ['Alla', 'Joomi'],
    'Fulani': ['Alla', 'Joomi'],
    'Georgian': [
      'ალაჰისათვის', 'ალაჰისგან', 'ალაჰზე', 'ალაჰმა', 'ალაჰსა', 'ალაჰის',
      'ალაჰთან', 'ალაჰს', 'ალაჰი', 'ალაჰისა',
      'უფლისაგან', 'უფლის', 'უფალო', 'უფალს', 'უფალი',
    ],
    'Gujarati': ['અલ્લાહ', 'પાલનહાર', 'પાલનહારનો', 'પાલનહારની', 'પાલનહારનું', 'રબ્બ'],
    'Greek': ['Αλλάχ', 'Θεός', 'Κύριός', 'Κύριος', 'Κυρίου', 'Κύριό', 'Κύριε', 'Κύριέ', 'Κύριο'],
    'Hindi': ['अल्लाह', 'रब्ब', 'परवरदिगार'],
    'Indonesian': ['Allahlah', 'Allah', 'Rabb', 'Tuhan'],
    'Italian': ['Allāh', 'Allah', 'Dio'],
    'Japanese': [
      'アッラー', 'アッラーの', 'アッラーに', 'アッラーは', 'アッラーが', 'アッラーを', 'アッラーと', '主',
    ],
    'Kannada': ['ಅಲ್ಲಾಹ', 'ಅಲ್ಲಾಹನ', 'ಒಡೆಯ', 'ಒಡೆಯನ', 'ಪ್ರಭು'],
    'Kazakh': [
      'Аллаһ', 'Аллаһқа', 'Аллаһты', 'Аллаһтан', 'Аллаһтың', 'Аллаһта',
      'Раббы', 'Раббысы', 'Раббысына', 'Раббысынан', 'Раббысының',
      'Раббым', 'Раббың', 'Раббыңа', 'Раббыңнан', 'Раббыңның', 'Раббыңыз',
      'Раббымыз', 'Раббылары', 'Раббыларына', 'Раббыларынан', 'Раббыларың',
      'Раббыларыңа', 'Раббыларының', 'Раббымызға', 'Раббымыздан', 'Раббымыздың',
      'Құдай', 'Құдайға', 'Құдайды', 'Құдайдан', 'Құдайдың',
      'Рубұбияһ', 'Рубұбияһын', 'Иелік',
    ],
    'Khmer': ['អល់ឡោះ', 'ម្ចាស់'],
    'Kyrgyz': [
      'Аллахтын', 'Аллахты', 'Аллахтан', 'Аллахка', 'Алланын', 'Аллага',
      'Алладан', 'Аллах', 'Алла',
    ],
    'Lithuanian': ['Alachas', 'Allahas', 'Alacho', 'Allaho', 'Viešpats', 'Viešpaties'],
    'Luganda': [
      'Mukama wammwe', 'Mukama wange', 'Mukama waffe', 'Mukama wabwe',
      'Ruboobiyyah', 'Mukama', 'Katonda', "Allah'", 'Allah', 'Obukama',
    ],
    'Luhya': [
      'Nyasaye wabwene', 'Nyasaye wabandu', 'Nyasaye wabwo', 'Nyasaye wafwe',
      'Nyasaye wabwe', 'Nyasaye wanyu', 'Nyasaye Wase', 'Nyasaye Wowo',
      'Nyasaye', "Allah'", 'Allah', 'Ruboobiyyah', 'Obukama', 'Omukali', 'Omukhasi',
    ],
    'Macedonian': [
      'Аллаховото', 'Аллахови', 'Аллахова', 'Аллахово', 'Аллахов', 'Аллахот',
      'Аллаха', 'Аллаху', 'Аллах',
      'Господарот', 'Господаро', 'Господару', 'Господаров', 'Господа', 'Господ',
      'Господар мој', 'Господ мој', 'својот Господ', 'мојот Господ',
      'твојот Господ', 'неговиот Господ', 'нејзиниот Господ', 'нашиот Господ',
      'вашиот Господ', 'нивниот Господ', 'Рубобијјата', 'Рубобијја',
    ],
    'Malayalam': [
      'അല്ലാഹുവിൻ്റെ', 'അല്ലാഹുവിന്റെ', 'അല്ലാഹുവിനെ', 'അല്ലാഹുവെ',
      'അല്ലാഹുവിന്', 'അല്ലാഹു', 'റബ്ബ്',
    ],
    'Marathi': [
      'पालनहर्त्याकडून', 'पालनहर्त्याकडे', 'पालनहर्त्याचा', 'पालनहर्त्याची',
      'पालनहर्त्याचे', 'पालनहर्त्यास', 'पालनहर्त्या', 'पालनहर्ता',
      'माझ्या पालनहर्त्या', 'माझा पालनहर्ता', 'तुमचा पालनहर्ता', 'आपला पालनहर्ता',
      'त्यांचा पालनहर्ता', 'त्याचा पालनहर्ता', 'तिचा पालनहर्ता',
      'अल्लाहकडून', 'अल्लाहबद्दल', 'अल्लाहकडे', 'अल्लाहसाठी', 'अल्लाहच्या',
      'अल्लाहचा', 'अल्लाहची', 'अल्लाहचे', 'अल्लाहने', 'अल्लाहला', 'अल्लाहवर',
      'अल्लाहशी', 'अल्लाह', 'रुबूबिय्याह', 'प्रभु', 'प्रभू',
    ],
    'Mongolian': [
      'Аллах', 'Аллахын', 'Аллахийн', 'Аллахад', 'Аллахыг', 'Аллахаас',
      'Эзэн', 'Эзэнийхээ', 'Эзэндээ', 'Эзнийхээ', 'Эзэнд', 'Эзэнээс', 'Эзний',
      'Эзэний', 'Эзэн минь', 'Эзэн маань', 'Таны Эзэн', 'Та нарын Эзэн',
      'түүний Эзэн', 'Бурхан', 'Бурхны', 'Бурханд', 'Бурханыг', 'Бурханаас',
      'Рубүбийях',
    ],
    'Moore': [
      'Wẽnnaam', 'Rububiyya', 'Allah', 'Alla', 'Wẽnd',
      'M Dũnni', 'fo Dũnni', 'a Dũnni', 'tõnd Dũnni', 'yãmb Dũnni', 'b Dũnni',
      'Dũnia', 'Dũnni', 'Naam',
    ],
    'Nepali': [
      'अल्लाहबाट', 'अल्लाहलाई', 'अल्लाहमा', 'अल्लाहको', 'अल्लाहले', 'अल्लाह',
      'उनीहरूको पालनकर्ता', 'तपाईंको पालनकर्ता', 'पालनकर्ताबाट', 'पालनकर्तालाई',
      'पालनकर्ताको', 'पालनकर्ताले', 'पालनकर्तामा',
      'हाम्रो पालनकर्ता', 'तिम्रो पालनकर्ता', 'मेरो पालनकर्ता', 'उसको पालनकर्ता',
      'पालनकर्ता', 'सर्वशक्तिमान', 'प्रभु', 'रब्ब',
    ],
    'Odia': [
      'ଆଲ୍ଲାହଙ୍କଠାରୁ', 'ଆଲ୍ଲାହଙ୍କଠାରେ', 'ଆଲ୍ଲାହଙ୍କଦ୍ୱାରା', 'ଆଲ୍ଲାହଙ୍କ ପ୍ରତି',
      'ଆଲ୍ଲାହଙ୍କ ନିକଟରେ', 'ଆଲ୍ଲାହଙ୍କ ପାଇଁ', 'ଆଲ୍ଲାହଙ୍କ ସହିତ', 'ଆଲ୍ଲାହଙ୍କ ବିଷୟରେ',
      'ଆଲ୍ଲାହଙ୍କ', 'ଆଲ୍ଲାହଙ୍କୁ', 'ଆଲ୍ଲାହଙ୍କର', 'ଆଲ୍ଲାହ',
      'ସମଗ୍ର ବିଶ୍ୱର ପ୍ରଭୁଙ୍କ', 'ସମଗ୍ର ବିଶ୍ୱର ପ୍ରଭୁ', 'ତୁମ୍ଭମାନଙ୍କର ପ୍ରଭୁ',
      'ସେମାନଙ୍କର ପ୍ରଭୁ', 'ଆପଣଙ୍କର ପ୍ରଭୁ', 'ପ୍ରଭୁଙ୍କଠାରୁ', 'ପ୍ରଭୁଙ୍କଠାରେ',
      'ପ୍ରଭୁଙ୍କଦ୍ୱାରା', 'ମୋର ପ୍ରଭୁଙ୍କ', 'ଆମର ପ୍ରଭୁ', 'ନିଜର ପ୍ରଭୁ', 'ତୁମ୍ଭର ପ୍ରଭୁ',
      'ମୋର ପ୍ରଭୁ', 'ପ୍ରଭୁଙ୍କ', 'ପ୍ରଭୁଙ୍କୁ', 'ପ୍ରଭୁଙ୍କର', 'ପ୍ରଭୁ',
      'ମହାନ୍ ପ୍ରଭୁ', 'ପରାକ୍ରମଶାଳୀ', 'ରୁବୂବିଯ୍ୟା', 'ଦେବତା',
    ],
    'Punjabi': [
      'ਅੱਲਾਹ', 'ਅੱਲਾਹ ਦੀ', 'ਅੱਲਾਹ ਦਾ', 'ਅੱਲਾਹ ਦੇ', 'ਅੱਲਾਹ ਨੂੰ', 'ਅੱਲਾਹ ਤੋਂ',
      'ਅੱਲਾਹ ਵੱਲ', 'ਅੱਲਾਹ ਉੱਤੇ', 'ਅੱਲਾਹ ਕੋਲ', 'ਅੱਲਾਹ ਲਈ', 'ਅੱਲਾਹ ਨਾਲ', 'ਅੱਲਾਹ ਬਾਰੇ',
      'ਸਾਰੇ ਸੰਸਾਰ ਦਾ ਰੱਬ', 'ਸਾਰੇ ਸੰਸਾਰ ਦੇ ਰੱਬ', 'ਸਾਰੇ ਸੰਸਾਰ ਦੇ ਰੱਬ ਵੱਲੋਂ',
      'ਤੁਹਾਡੇ ਰੱਬ', 'ਆਪਣੇ ਰੱਬ', 'ਉਹਨਾਂ ਦਾ ਰੱਬ', 'ਉਹਨਾਂ ਦੇ ਰੱਬ',
      'ਮੇਰੇ ਰੱਬ', 'ਮੇਰਾ ਰੱਬ', 'ਤੇਰੇ ਰੱਬ', 'ਤੇਰਾ ਰੱਬ', 'ਸਾਡੇ ਰੱਬ', 'ਸਾਡਾ ਰੱਬ',
      'ਰੱਬ ਵੱਲੋਂ', 'ਰੱਬ ਦਾ', 'ਰੱਬ ਦੀ', 'ਰੱਬ ਦੇ', 'ਰੱਬ ਨੂੰ', 'ਰੱਬ ਤੋਂ', 'ਰੱਬ',
    ],
    'Somali': [
      'Allaah ka', 'Allaah ku', 'Allaah u', 'Allaah la', 'Allaah ha', 'Allaahna',
      'Allaah', 'Ilaahaygu', 'Ilaahaygunu',
      'Rabbiga adduunyada', 'Rabbiga adduunka', 'Rabbigaygu', 'Rabbigood',
      'Rabbigiisa', 'Rabbigaa', 'Rabbigiinna', 'Rabbigay', 'Rabbigiis',
      'Rabbigayada', 'Rabbigeed', 'Rabbigiina', 'Rabbigi', 'Rabbigu', 'Rabbaha',
      'Rabbi', 'Rabb',
    ],
    'Slovak': [
      'Allaha', 'Allahovi', 'Allahom', 'Alahom', 'Allahu', 'Alláha', 'Alláhovmu',
      'Alláhovi', 'Alláhom', 'Alláhu', 'Allah', 'Alláh',
      'Boha', 'Bohovi', 'Bohom', 'Bohu', 'Boží', 'Božích', 'Boh',
      'Pána svetov', 'Pánovi', 'Pánom', 'Pána', 'Pane', 'Pánu', 'Pán',
      'svojho Pána', 'svojmu Pánovi', 'svojho Pána Veľkého',
    ],
    'Russian': [
      'Аллахом', 'Аллахе', 'Аллаху', 'Аллаха', 'Аллах',
      'Господом', 'Господу', 'Господа', 'Господь',
    ],
    'Serbian': [
      'Аллаховим', 'Аллахови', 'Аллахов', 'Аллаховом', 'Аллахових', 'Аллахову',
      'Аллахово', 'Аллахове', 'Аллахова', 'Аллаху', 'Аллаха', 'Аллах',
      'Господара', 'Господару', 'Алаха', 'Алаху', 'Алах', 'Господар',
    ],
    'Sinhalese': [
      'අල්ලාහ්ගෙන්', 'අල්ලාහ්ගේ', 'අල්ලාහ්ට', 'අල්ලාහ්ද', 'අල්ලාහ්', 'රබ්',
    ],
    'Spanish': ['Al\u2011lah', 'Al-lah', 'Allāh', 'Allah', 'Señor'],
    'Swedish': [
      'världarnas Herres', 'världarnas Herre', 'Herrens', 'Herren',
      'Allahs', 'Herres', 'Allah', 'Herre', 'Guds', 'Gud',
    ],
    'Tagalog': ['Allāh', 'Allah', 'Panginoon'],
    'Tamil': [
      'அல்லாஹ்வுக்கும்', 'அல்லாஹ்வுக்கு', 'அல்லாஹ்வின்', 'அல்லாஹ்வை',
      'அல்லாஹை', 'அல்லாஹின்', 'அல்லாஹ்', 'ரப்',
    ],
    'Telugu': ['అల్లాహ్', 'రబ్బ్'],
    'Thai': ['พระผู้อภิบาล', 'อัลลอฮ์'],
    'Turkish': [
      'Allah\u2019adır', 'Allah\u2019tır', 'Allah\u2019tan', 'Allah\u2019ım',
      'Allah\u2019ın', 'Allah\u2019ı', 'Allah\u2019a',
      'Allah\u2018adır', 'Allah\u2018tır', 'Allah\u2018tan', 'Allah\u2018ım',
      'Allah\u2018ın', 'Allah\u2018ı', 'Allah\u2018a',
      "Allah'adır", "Allah'tır", "Allah'tan", "Allah'ım", "Allah'ın",
      "Allah'ı", "Allah'a", 'Allah',
    ],
    'Ukrainian': [
      'Господа світів', 'Господь', 'Господа', 'Господи',
      'Аллахом', 'Аллаха', 'Аллах',
    ],
    'Uzbek': [
      'Alloh', 'Allohning', 'Rabb', 'Robb', 'Robbisi', 'Robbing', 'Robbim',
      'Rabbisiga',
    ],
    'Xhosa': [
      'Allah', 'uAllah', 'u-Allah', 'kuAllah', 'ngoAllah', 'nguAllah',
      'kaAllah', 'ka-Allah', 'Nkosi', 'iNkosi', 'kwiNkosi', 'yeNkosi', 'eNkosini',
    ],
    'Yoruba': ['Allāhu', 'Allah', 'Allàh', 'Olúwa'],
    'Zulu': [
      'Allah', 'uAllah', 'u-Allah', 'kuAllah', 'kaAllah', 'ka-Allah',
      'Nkosi', 'iNkosi', 'eNkosini', 'yeNkosi',
    ],
    'Vietnamese': ['Thượng Đế', 'Allah'],
    'Afar': ['Yalli', 'Alla', 'Allah'],
    'Amharic': ['አላህ', 'አምላክ', 'ጌታ'],
    'German': ['Allah', 'Gott', 'Herr'],
    'Hausa': ['Allahu', 'Allah', 'Ubangiji'],
    'Korean': ['알라', '하나님', '주님'],
    'Malagasy': ['Tompo', 'Allah', 'Andriamanitra'],
    'Oromo': [
      'Rabbiitiin', 'Rabbiitiif', 'Rabbiinis', 'Rabbiiti', 'Rabbiin', 'Rabbiif',
      'Rabbitti', 'Rabbii', 'Rabbi', 'Allaahi', 'Allaahn', 'Allahi', 'Allah', 'Waaqayyo',
    ],
    'Portuguese': ['Allah', 'Senhor', 'Deus'],
    'Swahili': ['Allah', 'Mwenyezi Mungu', 'Bwana'],
    'Tajik': ['Аллоҳ', 'Худо', 'Парвардигор'],
    // Languages that only existed in hadeeth_panel's list:
    'Hungarian': [
      'Allahnak', 'Allahtól', 'Allahot', 'Allah',
      'Uram', 'Urunk', 'Uratok', 'Uruk', 'Úrnak', 'Úr',
    ],
    'Dutch': ['Allah', 'Heer'],
    'Romanian': ['Allah', 'Domnul', 'Domn'],
  };

  static const Map<String, String> _languageAliases = {
    'Bangla': 'Bengali',
    'Filipino': 'Tagalog',
    'PersianAfghan': 'Persian',
    'Mossi': 'Moore',
    'Sinhala': 'Sinhalese',
  };

  static String _canonicalLanguage(String language) {
    final stripped = language.endsWith(' *')
        ? language.substring(0, language.length - 2)
        : language;
    return _languageAliases[stripped] ?? stripped;
  }

  static List<String> _wordsForLanguage(String language, bool includePronouns) {
    final canonical = _canonicalLanguage(language);
    if (canonical == 'English') {
      return includePronouns
          ? [..._englishBaseWords, ..._englishPronounWords]
          : _englishBaseWords;
    }
    return allahWordsByLanguage[canonical] ?? _englishBaseWords;
  }

  static ({String latin, String arabic}) _allahPatternsFor(
      String language, bool includePronouns) {
    final words = _wordsForLanguage(language, includePronouns).toList()
      ..sort((a, b) {
        final c = b.length.compareTo(a.length);
        return c != 0 ? c : a.compareTo(b);
      });

    final patterns = <String>[];
    final arabicPatterns = <String>[];
    for (final w in words) {
      final escaped = RegExp.escape(w);
      if (RegExp(r"^[a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ'\u2018\u2019]+$").hasMatch(w)) {
        patterns.add(_latinWordPattern(w));
      } else {
        final script = _detectScript(w);
        if (script == 'arabic') {
          arabicPatterns.add(escaped);
        } else if (_noBoundaryScripts.contains(script)) {
          patterns.add(escaped);
        } else {
          final range = _scriptRanges[script] ?? _scriptRanges['cyrillic']!;
          patterns.add('(?<![$range])$escaped(?![$range])');
        }
      }
    }
    return (latin: patterns.join('|'), arabic: arabicPatterns.join('|'));
  }

  // ---------------------------------------------------------------------
  // Public entry point.
  // ---------------------------------------------------------------------

  /// Builds colored spans for [text]:
  /// - "quotes" pink
  /// - (parens) cyan/green alternating by nesting depth
  /// - {curly braces} same coloring as parens, if [includeCurlyBraces]
  /// - [brackets] amber
  /// - `12:34`-style verse refs (tappable via [onVerseTapped]), if [includeVerseRefs]
  /// - Allah/Lord/Rabb terms for [language] (or Arabic if [isArabic]) in purple
  /// - Muhammad/Messenger/ﷺ terms in lime
  ///
  /// [includePronouns] controls whether bare "Him"/"His"/"He"/"Me" count as
  /// Allah references (English only) — defaults to true for Quran text,
  /// pass false for contexts (like hadith narration) where "He" more often
  /// refers to a person.
  static List<TextSpan> spans(
    String text,
    TextStyle baseStyle, {
    String language = 'English',
    bool isArabic = false,
    bool includePronouns = true,
    bool includeCurlyBraces = false,
    bool includeVerseRefs = false,
    void Function(String)? onVerseTapped,
    TextStyle? verseStyle,
    int parenDepth = 0,
  }) {
    final effectiveLanguage = isArabic ? 'Arabic' : language;
    final patterns = _allahPatternsFor(effectiveLanguage, includePronouns);
    return _run(
      text,
      baseStyle,
      allahPattern: patterns.latin,
      arabicAllahPattern: patterns.arabic,
      muhammadPattern: muhammadWordPattern(),
      parenDepth: parenDepth,
      includeCurlyBraces: includeCurlyBraces,
      includeVerseRefs: includeVerseRefs,
      onVerseTapped: onVerseTapped,
      verseStyle: verseStyle ?? baseStyle.copyWith(color: Colors.lightBlueAccent),
    );
  }

  static List<TextSpan> _run(
    String text,
    TextStyle baseStyle, {
    required String allahPattern,
    required String arabicAllahPattern,
    required String muhammadPattern,
    required int parenDepth,
    required bool includeCurlyBraces,
    required bool includeVerseRefs,
    required void Function(String)? onVerseTapped,
    required TextStyle verseStyle,
  }) {
    final cyanStyle = baseStyle.copyWith(color: Colors.cyanAccent);
    final redStyle = baseStyle.copyWith(color: Colors.red.shade300);
    final purpleStyle = baseStyle.copyWith(color: const Color(0xFFCB93F5));
    final amberStyle = baseStyle.copyWith(color: Colors.amber);
    final quoteStyle = baseStyle.copyWith(color: const Color(0xFFFFB6C1));
    final muhammadStyle = baseStyle.copyWith(color: muhammadColor);

    final parenColor = parenDepth.isEven ? cyanStyle : redStyle;

    const quotePattern = r'"(?:[^"\\]|\\.)*"' r'|\u201c(?:[^\u201d])*\u201d';
    const parenPattern = r'\((?:[^()]|\([^()]*\))*\)';
    const curlyPattern = r'\{(?:[^{}]|\{[^{}]*\})*\}';

    final curlyGroupSrc = includeCurlyBraces ? curlyPattern : r'[^\s\S]';
    final verseGroupSrc =
        includeVerseRefs ? r'\b\d{1,3}:\d{1,3}(?:-\d{1,3})?\b' : r'[^\s\S]';
    final muhammadGroupSrc =
        muhammadPattern.isNotEmpty ? muhammadPattern : r'[^\s\S]';
    final allahGroupSrc = allahPattern.isNotEmpty ? allahPattern : r'[^\s\S]';

    final combined = RegExp(
      '($quotePattern)' // 1
      '|($parenPattern)' // 2
      '|($curlyGroupSrc)' // 3
      '|(\\[[^\\]]*\\])' // 4 bracket
      '|($verseGroupSrc)' // 5 verse
      '|($muhammadGroupSrc)' // 6 muhammad
      '|($allahGroupSrc)', // 7 allah
    );

    // kind: 0 quote, 1 paren, 2 curly, 3 bracket, 4 verse, 5 muhammad, 6 allah
    final ranges = <(int, int, int)>[];
    for (final m in combined.allMatches(text)) {
      if (m.group(1) != null) {
        ranges.add((m.start, m.end, 0));
      } else if (m.group(2) != null) {
        ranges.add((m.start, m.end, 1));
      } else if (m.group(3) != null) {
        ranges.add((m.start, m.end, 2));
      } else if (m.group(4) != null) {
        ranges.add((m.start, m.end, 3));
      } else if (m.group(5) != null) {
        ranges.add((m.start, m.end, 4));
      } else if (m.group(6) != null) {
        ranges.add((m.start, m.end, 5));
      } else if (m.group(7) != null) {
        ranges.add((m.start, m.end, 6));
      }
    }

    if (arabicAllahPattern.isNotEmpty) {
      final arabicRanges =
          _findDiacriticInsensitiveArabicRanges(text, arabicAllahPattern);
      for (final r in arabicRanges) {
        final overlaps = ranges.any((e) => r.$1 < e.$2 && e.$1 < r.$2);
        if (!overlaps) ranges.add((r.$1, r.$2, 6));
      }
    }

    ranges.sort((a, b) => a.$1.compareTo(b.$1));

    List<TextSpan> recurse(String inner, TextStyle style, {required int depth}) =>
        _run(
          inner,
          style,
          allahPattern: allahPattern,
          arabicAllahPattern: arabicAllahPattern,
          muhammadPattern: muhammadPattern,
          parenDepth: depth,
          includeCurlyBraces: includeCurlyBraces,
          includeVerseRefs: includeVerseRefs,
          onVerseTapped: onVerseTapped,
          verseStyle: verseStyle,
        );

    final result = <TextSpan>[];
    int cursor = 0;
    for (final r in ranges) {
      final start = r.$1, end = r.$2, kind = r.$3;
      if (start < cursor) continue;
      if (start > cursor) {
        result.add(TextSpan(text: text.substring(cursor, start), style: baseStyle));
      }
      final matched = text.substring(start, end);
      switch (kind) {
        case 0: // quote
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: matched[0], style: quoteStyle));
          result.addAll(recurse(inner, quoteStyle, depth: parenDepth));
          result.add(TextSpan(text: matched[matched.length - 1], style: quoteStyle));
          break;
        case 1: // paren
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '(', style: parenColor));
          result.addAll(recurse(inner, parenColor, depth: parenDepth + 1));
          result.add(TextSpan(text: ')', style: parenColor));
          break;
        case 2: // curly
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '{', style: parenColor));
          result.addAll(recurse(inner, parenColor, depth: parenDepth + 1));
          result.add(TextSpan(text: '}', style: parenColor));
          break;
        case 3: // bracket
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '[', style: amberStyle));
          result.addAll(recurse(inner, amberStyle, depth: parenDepth));
          result.add(TextSpan(text: ']', style: amberStyle));
          break;
        case 4: // verse ref
          result.add(TextSpan(
            text: matched,
            style: verseStyle,
            recognizer: onVerseTapped != null
                ? (TapGestureRecognizer()..onTap = () => onVerseTapped(matched))
                : null,
          ));
          break;
        case 5: // muhammad
          result.add(TextSpan(text: matched, style: muhammadStyle));
          break;
        default: // allah
          result.add(TextSpan(text: matched, style: purpleStyle));
      }
      cursor = end;
    }
    if (cursor < text.length) {
      result.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return result;
  }
}
