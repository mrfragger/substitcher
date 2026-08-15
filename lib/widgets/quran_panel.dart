import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../quran/quran_index.dart';
import '../quran/surah_names.dart';
import '../quran/quran_verse_search_index.dart';
import '../tafsir/tafsir_mokhtasar_all.dart';
import '../tafsir/tafsir_english_hilali_khan.dart';
import '../tafsir/tafsir_english_rowwad.dart';
import '../tafsir/tafsir_english_noor.dart';
import '../tafsir/tafsir_english_yacob.dart';
import '../tafsir/tafsir_english_ibn_kathir.dart';
import '../tafsir/tafsir_arabic_saadi.dart';
import '../tafsir/tafsir_arabic_moyassar.dart';
import '../tafsir/tafsir_arabic_baghawi.dart';
import '../tafsir/tafsir_arabic_yaseer.dart';
import '../tafsir/tafsir_arabic_siraj.dart';
import '../tafsir/tafsir_arabic_nafahat.dart';
import '../tafsir/tafsir_arabic_katheer.dart';
import '../hadeeth/hadeeth_panel.dart';

class QuranPanel extends StatefulWidget {
  final List<QuranIndexEntry> entries;
  final bool isQuranLoaded;
  final QuranVerseRef? activeRef;
  final Function(QuranVerseRef, int) onVerseSelected;
  final FocusNode searchFocusNode;
  final FocusNode quranExcludeFocusNode;
  final FocusNode hadeethSearchFocusNode;
  final FocusNode hadeethExcludeFocusNode;
  final TextEditingController tafsirSearchController;
  final FocusNode tafsirSearchFocusNode;
  final TextEditingController quranVerseSearchController;
  final FocusNode quranVerseSearchFocusNode;
  final List<QuranAyahSearchHit> quranVerseSearchResults;
  final bool quranVerseIndexBuilding;
  final Function(String) onQuranVerseSearchChanged;
  final Function(QuranAyahSearchHit) onQuranVerseSearchResultTap;
  final ItemScrollController itemScrollController;
  final String searchQuery;
  final String excludeQuery;
  final TextEditingController searchController;
  final TextEditingController excludeController;
  final Function(String) onSearchChanged;
  final Function(String) onExcludeChanged;
  final String selectedLanguage;
  final Function(String) onLanguageChanged;
  final Function(List<QuranVerseRef> refs, int filteredIndex)? onPlayAllRequested;

  const QuranPanel({
    super.key,
    required this.entries,
    required this.isQuranLoaded,
    required this.activeRef,
    required this.onVerseSelected,
    required this.searchFocusNode,
    required this.quranExcludeFocusNode,
    required this.hadeethSearchFocusNode,
    required this.hadeethExcludeFocusNode,
    required this.tafsirSearchController,
    required this.tafsirSearchFocusNode,
    required this.quranVerseSearchController,
    required this.quranVerseSearchFocusNode,
    required this.quranVerseSearchResults,
    required this.quranVerseIndexBuilding,
    required this.onQuranVerseSearchChanged,
    required this.onQuranVerseSearchResultTap,
    required this.itemScrollController,
    required this.searchQuery,
    required this.excludeQuery,
    required this.searchController,
    required this.excludeController,
    required this.onSearchChanged,
    required this.onExcludeChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    this.onPlayAllRequested,
  });

  @override
  State<QuranPanel> createState() => _QuranPanelState();
}

class _QuranPanelState extends State<QuranPanel> {
  final Set<int> _expandedIndices = {};
  final TextEditingController _refInputController = TextEditingController();
  final FocusNode _refInputFocusNode = FocusNode();
  final ItemScrollController _quranVerseSearchScrollController = ItemScrollController();

  static bool _hadeethExpanded = false;
  static bool _tafsirExpanded = false;
  static bool _tafsirMokhtasar = true;
  static bool _tafsirHilaliKhan = false;
  static bool _tafsirRowwadEnglish = false;
  static bool _tafsirNoorEnglish = false;
  static bool _tafsirYacobEnglish = false;
  static bool _tafsirIbnKathir = false;
  static bool _tafsirSaadi = false;
  static bool _tafsirMoyassar = false;
  static bool _tafsirBaghawi = false;
  static bool _tafsirYaseer = false;
  static bool _tafsirSiraj = false;
  static bool _tafsirNafahat = false;
  static bool _tafsirKatheer = false;
  static String _mokhtasarLanguage = 'English';
  static QuranVerseRef? _lastTafsirRef;
  static int? _lastTafsirIndex;
  static List<Map<String, dynamic>> _tafsirResults = [];
  static const Map<String, List<String>> _allahByLanguage = {
    'Arabic': [
      'بالله',
      'تالله',
      'والله',
      'فالله',
      'لله',
      'الله',
      'لربكم',
      'لربهم',
      'لربنا',
      'لربه',
      'لربك',
      'لربي',
      'بربكم',
      'بربهم',
      'بربنا',
      'بربه',
      'بربك',
      'بربي',
      'ربكم',
      'ربهم',
      'ربنا',
      'ربه',
      'ربها',
      'ربك',
      'ربي',
    ],
    'Urdu': [
      'اللہ',
      'اللّٰہ',
      'پروردگار',
      'خدا',
      'ربّ',
      'رب',
    ],
    'Kurdish': [
      // Sorani (Arabic script)
      'خوای', 'الله',
      'پەروەردگاری', 'پەروەردگار',
      'خودای', 'خودا',
      'خوداوەند', 'خوداوەندی',
      // Kurmanji (Latin script)
      'Xwedayê', 'Xwedê',
    ],
    'Pashto': [
      // Allah (Pashto often uses الله directly)
      'بالله', 'والله', 'لله', 'الله',
      // Lord/God
      'خدایه', 'خدای', 'پالونکی',
      // Rabb forms (Arabic loanword usage)
      'ربه', 'ربك', 'رب',
    ],
    'Persian': [
      // Allah
      'بالله', 'والله', 'لله', 'الله',
      // God (most common Persian terms)
      'خداوندا', 'خداوندی', 'خداوند',
      'خدایا', 'خدای', 'خدا',
      // Lord/Sustainer
      'پروردگارا', 'پروردگاری', 'پروردگار',
    ],
    'Uyghur': [
      // Allah - Uyghur spelling (this is the main form!)
      'ئاللاھقا', 'ئاللاھنىڭ', 'ئاللاھتىن', 'ئاللاھتا', 'ئاللاھقا', 'ئاللاھنى',
      'ئاللاھ',
      // Lord/Sustainer with suffixes
      'پەرۋەردىگارىڭلار', 'پەرۋەردىگارىڭنىڭ', 'پەرۋەردىگارىنىڭ',
      'پەرۋەردىگارىڭ', 'پەرۋەردىگارىم', 'پەرۋەردىگارى', 'پەرۋەردىگار',
      // Rabb forms
      'رەببىڭنىڭ', 'رەببىنىڭ', 'رەببىڭ', 'رەببىم', 'رەببى', 'رەبب',
      // Fallback Arabic forms (in case any verse uses them)
      'الله', 'اﷲ',
    ],
    'Hebrew': [
      // Allah
      'אללה',
      // Lord/Rabb variations
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
    'English': [
      'Allah\u2019s',
      'Allāh\u2019s',
      'Allâh\u2019s',
      'Allah\u02BCs',
      'Allāh\u02BCs',
      'Allâh\u02BCs',
      'Allah\'s',
      'Allāh\'s',
      'Allâh\'s',
      'Allah',
      'Allāh',
      'Allâh',
      'Lord\u2019s',
      'Lord\u02BCs',
      'Lord\'s',
      'Lord',
    ],
    'Albanian': [
      'All-llahun', 'All-llahut', 'All-llahu',
      'Allahun', 'Allahut', 'Allahu',
      'Zotin', 'Zotit', 'Zoti',
    ],
    'AsanteTwi': ['Nyankopɔn', 'Awurade', 'Wura Nyankopɔn'],
    'Assamese': [
      'আল্লাহৰ',
      'আল্লাহে',
      'আল্লাহক',
      'আল্লাহ্',
      'আল্লাহ',
      'প্ৰতিপালকৰ',
      'প্ৰতিপালক',
      'ৰব'
    ],
    'Azerbaijani': [
      'Allahından',
      'Allahınıza',
      'Allahınız',
      'Allahıma',
      'Allahından',
      'Allahdan',
      'Allahına',
      'Allahını',
      'Allahадır',
      'Allahadır',
      'Allahım',
      'Allahın',
      'Allaha',
      'Allah'
    ],
    'Belarusian': [
      'Аллаха', 'Аллах',
      'Госпада', 'Госпаду', 'Госпадам', 'Госпадзе', 'Госпад',
    ],
    'Bengali': ['আল্লাহর', 'আল্লাহ্', 'আল্লাহ', 'রব', 'প্রতিপালক'],
    'Bulgarian': ['Аллах', 'Господа', 'Господи', 'Господ', 'Бог'],
    'Burmese *': ['အလ္လာဟ်အရှင်မြတ်', 'အလ္လာဟ်', 'အရှင်မြတ်', 'အရှင်'],
    'Bosnian': [
      'Allahovoj',
      'Allahova',
      'Allahovog',
      'Allahovom',
      'Allahovih',
      'Allahove',
      'Allahovu',
      'Allahovi',
      'Allahov',
      'Allahu',
      'Allaha',
      'Allah'
    ],
    'Chichewa': ['Allah', 'Mulungu', 'Mbuye'],
    'Chinese': ['安拉', '真主'],
    'ChineseTrad *': ['安拉', '真主'],
    'Circassian *': [
      'Аллахым', 'Аллах',
      'Аллаhыр', 'Аллаhым', 'Аллаhми', 'Аллаhм',
      'Тхьэм', 'Тхьэр', 'Тхьэ',
    ],
    'Czech *': [
      'Alláhovo', 'Alláhův', 'Alláhovu', 'Alláhovi', 'Alláhem', 'Alláha', 'Alláh',
      'Allahovi', 'Allaha',
      'Bůh', 'Boha', 'Bohu',
      'Pána', 'Pánu', 'Pane', 'Pán',
    ],
    'Dagbani': ['Naawuni', 'Duuma'],
    'Finnish *': [
      'Allahkin', 'Allahilta', 'Allahille', 'Allahia', 'Allahin', 'Allah',
      'Jumalanne', 'Jumalasta', 'Jumalaa', 'Jumalan', 'Jumala',
      'Herralleni', 'Herraansa', 'Herralleen', 'Herranne', 'Herralta',
      'Herraan', 'Herrani', 'Herrasi', 'Herran', 'Herra',
    ],
    'French': [
      'qu\u2019Allah',
      'qu\'Allah',
      'd\u2019Allah',
      'd\'Allah',
      'Allah',
      'Seigneur'
    ],
    'Fula': ['Alla', 'Joomi'],
    'Fulani': ['Alla', 'Joomi'],
    'Georgian *': [
      'ალაჰისათვის', 'ალაჰისგან', 'ალაჰზე', 'ალაჰმა', 'ალაჰსა', 'ალაჰის', 'ალაჰთან', 'ალაჰს', 'ალაჰი', 'ალაჰისა',
      'უფლისაგან', 'უფლის', 'უფალო', 'უფალს', 'უფალი',
    ],
    'Gujarati': ['અલ્લાહ', 'પાલનહાર', 'પાલનહારનો', 'પાલનહારની', 'પાલનહારનું', 'રબ્બ'],
    'Greek': ['Αλλάχ', 'Θεός', 'Κύριός', 'Κύριος', 'Κυρίου', 'Κύριό', 'Κύριε', 'Κύριέ', 'Κύριο'],
    'Hindi': ['अल्लाह', 'रब्ब', 'परवरदिगार'],
    'Indonesian': ['Allahlah', 'Allah', 'Rabb', 'Tuhan'],
    'Italian': ['Allāh', 'Allah', 'Dio'],
    'Japanese': ['アッラー', '主'],
    'Kannada': ['ಅಲ್ಲಾಹ', 'ಅಲ್ಲಾಹನ', 'ಒಡೆಯ', 'ಒಡೆಯನ', 'ಪ್ರಭು'],
    'Kazakh': [
      // ===== ALLAH (Аллаһ) with all suffixes =====
      // Base forms
      'Аллаһ',           // Base form
      'Аллаһқа',         // To Allah (dative)
      'Аллаһты',          // Allah (accusative)
      'Аллаһтан',         // From Allah (ablative)
      'Аллаһтың',         // Allah's (genitive)
      'Аллаһта',          // In/on Allah (locative)

      // ===== LORD (Раббы - Rabb) with possessive suffixes =====
      // Base forms
      'Раббы',            // Lord (base/nominative)
      'Раббысы',          // His/Her Lord (3rd person)
      'Раббысына',        // To his/her Lord (dative)
      'Раббысынан',       // From his/her Lord (ablative)
      'Раббысының',       // His/her Lord's (genitive)

      // Possessive forms (from your samples!)
      'Раббым',           // My Lord
      'Раббың',           // Your Lord (singular)
      'Раббыңа',          // To your Lord (dative)
      'Раббыңнан',        // From your Lord (ablative)
      'Раббыңның',        // Your Lord's (genitive)
      'Раббыңыз',         // Your Lord (plural/formal)
      'Раббымыз',         // Our Lord
      'Раббылары',        // Their Lord
      'Раббыларына',      // To their Lord (dative)
      'Раббыларынан',     // From their Lord (ablative)
      'Раббыларың',       // Your (plural) Lord
      'Раббыларыңа',      // To your (plural) Lord

      // ===== LORD with other forms =====
      'Раббыларының',     // Their Lord's (genitive)
      'Раббымызға',       // To our Lord (dative)
      'Раббымыздан',      // From our Lord (ablative)
      'Раббымыздың',      // Our Lord's (genitive)

      // ===== GOD (Құдай) variations =====
      'Құдай',            // God
      'Құдайға',          // To God (dative)
      'Құдайды',          // God (accusative)
      'Құдайдан',         // From God (ablative)
      'Құдайдың',         // God's (genitive)

      // ===== OTHER TERMS =====
      'Рубұбияһ',         // Rububiyyah (Lordship)
      'Рубұбияһын',       // Rububiyyah (with possessive)
      'Иелік',            // Lordship/dominion
    ],
    'Khmer': ['អល់ឡោះ', 'ម្ចាស់'],
    'Kyrgyz': [
      'Аллахтын',
      'Аллахты',
      'Аллахтан',
      'Аллахка',
      'Алланын',
      'Аллага',
      'Алладан',
      'Аллах',
      'Алла'
    ],
    'Lithuanian': ['Alachas', 'Allahas', 'Alacho', 'Allaho', 'Viešpats', 'Viešpaties'],
    'Luganda': [
      'Mukama wammwe',
      'Mukama wange',
      'Mukama waffe',
      'Mukama wabwe',
      'Ruboobiyyah',
      'Mukama',
      'Katonda',
      "Allah'",
      'Allah',
      'Obukama',
    ],
    'Luhya': [
      // Longest first - possessive phrases
      'Nyasaye wabwene',
      'Nyasaye wabandu',
      'Nyasaye wabwo',
      'Nyasaye wafwe',
      'Nyasaye wabwe',
      'Nyasaye wanyu',
      // Possessive with linking vowels
      'Nyasaye Wase',
      'Nyasaye Wowo',
      // Base form
      'Nyasaye',
      "Allah'",
      'Allah',
      // Other terms
      'Ruboobiyyah',
      'Obukama',
      'Omukali',
      'Omukhasi',
    ],
    'Macedonian': [
      // Longest first - Allah forms
      'Аллаховото',
      'Аллахови',
      'Аллахова',
      'Аллахово',
      'Аллахов',
      'Аллахот',
      'Аллаха',
      'Аллаху',
      'Аллах',
      // Lord forms with definite article and cases
      'Господарот',
      'Господаро',
      'Господару',
      'Господаров',
      'Господа',
      'Господ',
      // Господар variations
      'Господарот',
      'Господару',
      'Господар',
      // Lord with possessives (multi-word)
      'Господару мој',
      'Господ мој',
      'својот Господ',
      'мојот Господ',
      'твојот Господ',
      'неговиот Господ',
      'нејзиниот Господ',
      'нашиот Господ',
      'вашиот Господ',
      'нивниот Господ',
      // Other terms
      'Рубобијјата',
      'Рубобијја',
    ],
    'Malayalam': [
      'അല്ലാഹുവിൻ്റെ',
      'അല്ലാഹുവിന്റെ',
      'അല്ലാഹുവിനെ',
      'അല്ലാഹുവെ',
      'അല്ലാഹുവിന്',
      'അല്ലാഹു',
      'റബ്ബ്'
    ],
    'Marathi': [
      // Longest first - Lord (पालनहर्ता) forms
      'पालनहर्त्याकडून',
      'पालनहर्त्याकडे',
      'पालनहर्त्याचा',
      'पालनहर्त्याची',
      'पालनहर्त्याचे',
      'पालनहर्त्यास',
      'पालनहर्त्या',
      'पालनहर्ता',
      // Lord with possessives
      'माझ्या पालनहर्त्या',
      'माझा पालनहर्ता',
      'तुमचा पालनहर्ता',
      'आपला पालनहर्ता',
      'त्यांचा पालनहर्ता',
      'त्याचा पालनहर्ता',
      'तिचा पालनहर्ता',
      // Allah with postpositions (longest first)
      'अल्लाहकडून',
      'अल्लाहबद्दल',
      'अल्लाहकडे',
      'अल्लाहसाठी',
      'अल्लाहच्या',
      'अल्लाहचा',
      'अल्लाहची',
      'अल्लाहचे',
      'अल्लाहने',
      'अल्लाहला',
      'अल्लाहवर',
      'अल्लाहशी',
      'अल्लाह',
      // Other terms
      'रुबूबिय्याह',
      'प्रभु',
      'प्रभू',
    ],
    'Mongolian *': [
      // Primary term for Allah
      'Аллах',
      'Аллахын',      // Allah's (genitive)
      'Аллахийн',     // Allah's (alternative genitive)
      'Аллахад',      // To Allah (dative)
      'Аллахыг',      // Allah (accusative)
      'Аллахаас',     // From Allah (ablative)
      // Terms for Lord (Эзэн) with various suffixes
      'Эзэн',          // Lord (base form)
      'Эзэнийхээ',     // His/Her Lord's
      'Эзэндээ',       // To his/her Lord
      'Эзнийхээ',      // Of his Lord
      'Эзэнд',         // To the Lord
      'Эзэнээс',       // From the Lord
      'Эзний',         // Of the Lord
      'Эзэний',        // Of the Lord (alternative)
      'Эзэн минь',     // My Lord
      'Эзэн маань',    // Our Lord
      'Таны Эзэн',     // Your Lord (formal)
      'Та нарын Эзэн', // Your (plural) Lord
      'түүний Эзэн',   // His Lord
      // Terms for God (Бурхан)
      'Бурхан',        // God
      'Бурхны',        // God's (genitive)
      'Бурханд',       // To God (dative)
      'Бурханыг',      // God (accusative)
      'Бурханаас',     // From God (ablative)
      // Arabic loanword
      'Рубүбийях',     // Rububiyyah (Lordship)
    ],
    'Moore': [
      // Longest first
      'Wẽnnaam',
      'Rububiyya',
      // Allah forms with concords
      'Allah',
      'Alla',
      'Wẽnd',
      // Lord with possessives
      'M Dũnni',
      'fo Dũnni',
      'a Dũnni',
      'tõnd Dũnni',
      'yãmb Dũnni',
      'b Dũnni',
      'Dũnia',
      'Dũnni',
      'Naam',
    ],
    'Nepali *': [
      // ===== ALLAH (अल्लाह) with all suffixes =====
      'अल्लाहबाट',         // From Allah (ablative) - length: 7
      'अल्लाहलाई',          // To Allah (dative) - length: 7
      'अल्लाहमा',           // In/on Allah (locative) - length: 6
      'अल्लाहको',           // Allah's / of Allah (genitive) - length: 6
      'अल्लाहले',           // Allah (ergative) - length: 6
      'अल्लाह',             // Base form - length: 5

      // ===== LORD (पालनकर्ता) with all suffixes =====
      'उनीहरूको पालनकर्ता', // Their Lord - length: 17
      'तपाईंको पालनकर्ता',  // Your Lord (plural/formal) - length: 16
      'पालनकर्ताबाट',       // From the Lord (ablative) - length: 11
      'पालनकर्तालाई',       // To the Lord (dative) - length: 11
      'पालनकर्ताको',        // Lord's / of the Lord (genitive) - length: 10
      'पालनकर्ताले',        // Lord (ergative) - length: 10
      'पालनकर्तामा',         // In/on the Lord (locative) - length: 10

      // Lord with possessive pronouns
      'हाम्रो पालनकर्ता',    // Our Lord - length: 14
      'तिम्रो पालनकर्ता',    // Your Lord (singular/informal) - length: 14
      'मेरो पालनकर्ता',      // My Lord - length: 12
      'उसको पालनकर्ता',      // His/Her Lord - length: 13
      'पालनकर्ता',           // Lord (base form) - length: 8

      // ===== OTHER TERMS =====
      'सर्वशक्तिमान',        // Almighty - length: 10
      'प्रभु',               // Lord (alternative) - length: 4
      'रब्ब',                // Rabb (Arabic loanword) - length: 3
    ],
    'Odia *': [
      // ===== ALLAH (ଆଲ୍ଲାହ) with all suffixes =====
      // Longest first - Allah with full phrases
      'ଆଲ୍ଲାହଙ୍କଠାରୁ',     // From Allah (ablative) - length: 11
      'ଆଲ୍ଲାହଙ୍କଠାରେ',     // In/on Allah (locative) - length: 11
      'ଆଲ୍ଲାହଙ୍କଦ୍ୱାରା',    // By Allah (instrumental) - length: 12
      'ଆଲ୍ଲାହଙ୍କ ପ୍ରତି',    // Towards Allah - length: 10
      'ଆଲ୍ଲାହଙ୍କ ନିକଟରେ',  // Near Allah - length: 14
      'ଆଲ୍ଲାହଙ୍କ ପାଇଁ',     // For Allah - length: 9
      'ଆଲ୍ଲାହଙ୍କ ସହିତ',    // With Allah - length: 10
      'ଆଲ୍ଲାହଙ୍କ ବିଷୟରେ',  // About Allah - length: 13

      // Allah with case suffixes
      'ଆଲ୍ଲାହଙ୍କ',          // Allah's / of Allah (genitive) - length: 7
      'ଆଲ୍ଲାହଙ୍କୁ',         // To Allah (dative) - length: 7
      'ଆଲ୍ଲାହଙ୍କର',         // Allah's (alternative genitive) - length: 7
      'ଆଲ୍ଲାହ',             // Base form - length: 4

      // ===== LORD (ପ୍ରଭୁ) with all suffixes =====
      // Longest first - Lord with full phrases
      'ସମଗ୍ର ବିଶ୍ୱର ପ୍ରଭୁଙ୍କ', // Lord of all the worlds (genitive) - length: 18
      'ସମଗ୍ର ବିଶ୍ୱର ପ୍ରଭୁ',   // Lord of all the worlds - length: 16
      'ତୁମ୍ଭମାନଙ୍କର ପ୍ରଭୁ',    // Your Lord (plural) - length: 15
      'ସେମାନଙ୍କର ପ୍ରଭୁ',       // Their Lord - length: 13
      'ଆପଣଙ୍କର ପ୍ରଭୁ',        // Your Lord (formal) - length: 12

      // Lord with possessive pronouns
      'ପ୍ରଭୁଙ୍କଠାରୁ',         // From the Lord (ablative) - length: 10
      'ପ୍ରଭୁଙ୍କଠାରେ',         // In/on the Lord (locative) - length: 10
      'ପ୍ରଭୁଙ୍କଦ୍ୱାରା',        // By the Lord (instrumental) - length: 11
      'ମୋର ପ୍ରଭୁଙ୍କ',          // My Lord's - length: 9
      'ଆମର ପ୍ରଭୁ',            // Our Lord - length: 8
      'ନିଜର ପ୍ରଭୁ',            // His/Her/Their own Lord - length: 9
      'ତୁମ୍ଭର ପ୍ରଭୁ',          // Your Lord (singular) - length: 9
      'ମୋର ପ୍ରଭୁ',             // My Lord - length: 7

      // Lord with case suffixes
      'ପ୍ରଭୁଙ୍କ',             // Lord's / of the Lord (genitive) - length: 6
      'ପ୍ରଭୁଙ୍କୁ',            // To the Lord (dative) - length: 6
      'ପ୍ରଭୁଙ୍କର',            // Lord's (alternative genitive) - length: 6
      'ପ୍ରଭୁ',                // Lord (base form) - length: 3

      // ===== OTHER TERMS =====
      'ମହାନ୍ ପ୍ରଭୁ',          // Great Lord - length: 8
      'ପରାକ୍ରମଶାଳୀ',          // Almighty - length: 8
      'ରୁବୂବିଯ୍ୟା',           // Rububiyyah (Lordship) - length: 8
      'ଦେବତା',               // God/Deity - length: 4
    ],
    'Punjabi': [
      // ===== ALLAH (ਅੱਲਾਹ / اللہ) with all suffixes =====
      // Longest first - Allah with full phrases
      'ਅੱਲਾਹ',           // Base form - length: 5
      'ਅੱਲਾਹ ਦੀ',         // Allah's (feminine) - length: 7
      'ਅੱਲਾਹ ਦਾ',         // Allah's (masculine) - length: 7
      'ਅੱਲਾਹ ਦੇ',         // Allah's (oblique) - length: 7
      'ਅੱਲਾਹ ਨੂੰ',         // To Allah (dative) - length: 7
      'ਅੱਲਾਹ ਤੋਂ',         // From Allah (ablative) - length: 7
      'ਅੱਲਾਹ ਵੱਲ',         // Towards Allah - length: 7
      'ਅੱਲਾਹ ਉੱਤੇ',        // Upon Allah - length: 8
      'ਅੱਲਾਹ ਕੋਲ',         // Near Allah - length: 7
      'ਅੱਲਾਹ ਲਈ',          // For Allah - length: 6
      'ਅੱਲਾਹ ਨਾਲ',         // With Allah - length: 7
      'ਅੱਲਾਹ ਬਾਰੇ',        // About Allah - length: 7

      // ===== LORD (ਰੱਬ) with all suffixes =====
      // Longest first - Lord with full phrases
      'ਸਾਰੇ ਸੰਸਾਰ ਦਾ ਰੱਬ', // Lord of all the worlds - length: 16
      'ਸਾਰੇ ਸੰਸਾਰ ਦੇ ਰੱਬ', // Lord of all the worlds (oblique) - length: 16
      'ਸਾਰੇ ਸੰਸਾਰ ਦੇ ਰੱਬ ਵੱਲੋਂ', // From the Lord of all worlds - length: 21
      'ਤੁਹਾਡੇ ਰੱਬ',       // Your Lord (plural/formal) - length: 9
      'ਆਪਣੇ ਰੱਬ',         // Your own Lord - length: 7
      'ਉਹਨਾਂ ਦਾ ਰੱਬ',      // Their Lord - length: 10
      'ਉਹਨਾਂ ਦੇ ਰੱਬ',      // Their Lord (oblique) - length: 10

      // Lord with possessive pronouns
      'ਮੇਰੇ ਰੱਬ',          // My Lord - length: 7
      'ਮੇਰਾ ਰੱਬ',          // My Lord (alternative) - length: 7
      'ਤੇਰੇ ਰੱਬ',          // Your Lord (singular) - length: 7
      'ਤੇਰਾ ਰੱਬ',          // Your Lord (singular) - length: 7
      'ਸਾਡੇ ਰੱਬ',          // Our Lord - length: 7
      'ਸਾਡਾ ਰੱਬ',          // Our Lord - length: 7

      // Lord with case suffixes
      'ਰੱਬ ਵੱਲੋਂ',         // From the Lord - length: 7
      'ਰੱਬ ਦਾ',            // Lord's / of the Lord (masculine) - length: 5
      'ਰੱਬ ਦੀ',            // Lord's / of the Lord (feminine) - length: 5
      'ਰੱਬ ਦੇ',            // Lord's / of the Lord (oblique) - length: 5
      'ਰੱਬ ਨੂੰ',            // To the Lord (dative) - length: 5
      'ਰੱਬ ਤੋਂ',            // From the Lord (ablative) - length: 5
      'ਰੱਬ',               // Lord (base form) - length: 3
    ],
    'Somali': [
      // ===== ALLAH (Allaah) with all suffixes =====
      // Longest first - Allah with full phrases
      'Allaah ka',          // From Allah - length: 8
      'Allaah ku',          // In/on Allah - length: 8
      'Allaah u',           // To/for Allah - length: 7
      'Allaah la',          // With Allah - length: 8
      'Allaah ha',          // By Allah - length: 7
      'Allaahna',           // Allah (with emphasis) - length: 7
      'Allaah',             // Base form - length: 6

      // Also with article/demonstrative
      'Ilaahaygu',          // My God/Allah - length: 9
      'Ilaahaygunu',        // My God (with emphasis) - length: 10

      // ===== LORD (Rabbi) with all suffixes =====
      // Longest first - Lord with full phrases
      'Rabbiga adduunyada',  // Lord of the worlds - length: 19
      'Rabbiga adduunka',    // Lord of the world - length: 17
      'Rabbigaygu',          // My Lord (with emphasis) - length: 10
      'Rabbigood',           // Their Lord - length: 9
      'Rabbigiisa',
      'Rabbigaa',            // Your Lord (singular) - length: 8
      'Rabbigiinna',         // Your Lord (plural/formal) - length: 11
      'Rabbigay',            // My Lord - length: 8
      'Rabbigiis',           // His Lord - length: 9
      'Rabbigayada',         // Our Lord - length: 10

      // Lord with case suffixes
      'Rabbigiisa',          // Lord's / of His Lord - length: 10
      'Rabbigeed',           // Her Lord - length: 9
      'Rabbigiina',          // Your Lord (plural) - length: 10
      'Rabbigi',             // Lord (base with suffix) - length: 7
      'Rabbigu',             // Lord (nominative) - length: 7
      'Rabbaha',             // Lord (definite) - length: 7

      // Base form - keep at end
      'Rabbi',               // Lord (base form) - length: 5
      'Rabb',                // Lord (short form) - length: 4
    ],
    'Slovak *': [
      // ===== ALLAH (Allah / Boh) with all suffixes =====
      // Longest first - Allah with full phrases
      'Allaha',             // Allah (genitive/accusative) - length: 6
      'Allahovi',           // To/for Allah (dative) - length: 8
      'Allahom',            // With/by Allah (instrumental) - length: 7
      'Alahom',
      'Allahu',             // Allah (vocative/nominative) - length: 6
      'Alláha',             // Allah (genitive/accusative with diacritic) - length: 6
      'Alláhovmu',          // Allah's / of Allah (genitive) - length: 9
      'Alláhovi',           // To/for Allah (dative) - length: 8
      'Alláhom',            // With/by Allah (instrumental) - length: 7
      'Alláhu',             // Allah (vocative/nominative) - length: 6
      'Allah',              // Base form - length: 5
      'Alláh',              // Base form with diacritic - length: 5

      // ===== GOD (Boh) with all suffixes =====
      // Longest first - God with full phrases
      'Boha',               // God (genitive/accusative) - length: 4
      'Bohovi',             // To/for God (dative) - length: 6
      'Bohom',              // With/by God (instrumental) - length: 5
      'Bohu',               // God (dative/locative) - length: 4
      'Boží',               // God's / of God (possessive) - length: 4
      'Božích',             // God's / of God (possessive plural) - length: 6
      'Boh',                // Base form - length: 3

      // ===== LORD (Pán) with all suffixes =====
      // Longest first - Lord with full phrases
      'Pána svetov',        // Lord of the worlds - length: 11
      'Pánovi',             // To/for the Lord (dative) - length: 6
      'Pánom',              // With/by the Lord (instrumental) - length: 5
      'Pána',               // Lord (genitive/accusative) - length: 4
      'Pane',               // Lord (vocative) - length: 4
      'Pánu',               // Lord (dative/locative) - length: 4
      'Pán',                // Base form - length: 3

      // ===== LORD with possessive pronouns =====
      // Longest first
      'svojho Pána',        // His/Her/Their own Lord - length: 10
      'svojmu Pánovi',      // To his/her own Lord - length: 13
      'svojho Pána Veľkého', // His Great Lord - length: 18
    ],
    'Russian': [
      'Аллахом',
      'Аллахе',
      'Аллаху',
      'Аллаха',
      'Аллах',
      'Господом',
      'Господу',
      'Господа',
      'Господь'
    ],
    'Serbian': [
      'Аллаховим',
      'Аллахови',
      'Аллахов',
      'Аллаховом',
      'Аллахових',
      'Аллахову',
      'Аллахово',
      'Аллахове',
      'Аллахова',
      'Аллаху',
      'Аллаха',
      'Аллах',
      'Господара',
      'Господару',
      'Алаха',
      'Алаху',
      'Алах',
      'Господар'
    ],
    'Sinhalese': [
      'අල්ලාහ්ගෙන්',
      'අල්ලාහ්ගේ',
      'අල්ලාහ්ට',
      'අල්ලාහ්ද',
      'අල්ලාහ්',
      'රබ්'
    ],
    'Spanish': ['Al\u2011lah', 'Al-lah', 'Allāh', 'Allah', 'Señor'],
    'Swedish': [
      'världarnas Herres',
      'världarnas Herre',
      'Herrens',
      'Herren',
      'Allahs',
      'Herres',
      'Allah',
      'Herre',
      'Guds',
      'Gud',
    ],
    'Tagalog': ['Allāh', 'Allah', 'Panginoon'],
    'Tamil': [
      'அல்லாஹ்வுக்கும்',
      'அல்லாஹ்வுக்கு',
      'அல்லாஹ்வின்',
      'அல்லாஹ்வை',
      'அல்லாஹை',
      'அல்லாஹின்',
      'அல்லாஹ்',
      'ரப்'
    ],
    'Telugu': ['అల్లాహ్', 'రబ్బ్'],
    'Thai': ['พระผู้อภิบาล', 'อัลลอฮ์'],
    'Turkish': [
      'Allah\u2019adır',
      'Allah\u2019tır',
      'Allah\u2019tan',
      'Allah\u2019ım',
      'Allah\u2019ın',
      'Allah\u2019ı',
      'Allah\u2019a',
      'Allah\u2018adır',
      'Allah\u2018tır',
      'Allah\u2018tan',
      'Allah\u2018ım',
      'Allah\u2018ın',
      'Allah\u2018ı',
      'Allah\u2018a',
      "Allah'adır",
      "Allah'tır",
      "Allah'tan",
      "Allah'ım",
      "Allah'ın",
      "Allah'ı",
      "Allah'a",
      'Allah',
    ],
    'Ukrainian': [
      'Господа світів',
      'Господь',
      'Господа',
      'Господи',
      'Аллахом',
      'Аллаха',
      'Аллах',
    ],
    'Uzbek': [
      'Alloh',
      'Allohning',
      'Rabb',
      'Robb',
      'Robbisi',      // His Lord / Lord of (fused)
      'Robbing',      // your Lord (fused)
      'Robbim',       // my Lord (fused)
      'Rabbisiga',    // to His Lord (fused, dative)
    ],
    'Xhosa *': [
      'Allah', 'uAllah', 'u-Allah',   // subject-class prefix, fused
      'kuAllah',                       // "to/at Allah" (locative concord, fused)
      'ngoAllah',                      // "about/through Allah" (fused)
      'nguAllah',
      'kaAllah', 'ka-Allah',           // "of Allah" (genitive concord, fused) — e.g. "abakhonzi bakaAllah"
      'Nkosi', 'iNkosi',               // Lord, base + class prefix
      'kwiNkosi',                      // "to/at the Lord" (locative concord, fused)
      'yeNkosi',                       // "of the Lord" (genitive concord, fused) — e.g. "iNkosi yamahlabathi"
      'eNkosini',                      // "from/in the Lord" (locative, fused) — e.g. "evela eNkosini yabo"
    ],
    'Yoruba': ['Allāhu', 'Allah', 'Allàh','Olúwa'],
    'Zulu *': [
      'Allah', 'uAllah', 'u-Allah',   // subject-class prefix, fused
      'kuAllah',                       // "to/at Allah" (locative concord, fused)
      'kaAllah', 'ka-Allah',           // "of Allah" (genitive concord, fused) — e.g. "izinceku zikaAllah"
      'Nkosi', 'iNkosi',               // Lord, base + class prefix
      'eNkosini',                      // "from/at the Lord" (locative, fused) — e.g. "evela eNkosini yabo"
      'yeNkosi',                       // "of the Lord" (genitive concord, fused) — e.g. "iNkosi yemihlaba"
    ],
    'Vietnamese': ['Thượng Đế', 'Allah'],
    'Afar': ['Yalli', 'Alla', 'Allah'],
    'Akan': ['Onyame', 'Allah', 'Allaahu'],
    'Amharic': ['አላህ', 'አምላክ', 'ጌታ'],
    'German': ['Allah', 'Gott', 'Herr'],
    'Hausa': ['Allahu', 'Allah', 'Ubangiji'],
    'Korean': ['알라', '하나님', '주님'],
    'Malagasy': ['Tompo', 'Allah', 'Andriamanitra'],
    'Oromo': [
      'Rabbiitiin',
      'Rabbiitiif',
      'Rabbiinis',
      'Rabbiiti',
      'Rabbiin',
      'Rabbiif',
      'Rabbitti',
      'Rabbii',
      'Rabbi',
      'Allaahi',
      'Allaahn',
      'Allahi',
      'Allah',
      'Waaqayyo'
    ],
    'Portuguese': ['Allah', 'Senhor', 'Deus'],
    'Swahili': ['Allah', 'Mwenyezi Mungu', 'Bwana'],
    'Tajik': ['Аллоҳ', 'Худо', 'Парвардигор'],
  };
  static const Map<String, String> _scriptRanges = {
    'latin': r'a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜɔɛƆƐɣŋʒƔŊƷɩƖʋƲ',
    'cyrillic': r'а-яёА-ЯЁҳқғўЎіӯӀәӘғҒқҚңҢөӨұҰүҮһҺіІ',
    'georgian': r'\u10A0-\u10FF',
    'greek': r'\u0370-\u03FF',
    'arabic': r'\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF',
    'hebrew': r'\u0590-\u05FF',
    'nko': r'\u07C0-\u07FF',
    'bengali': r'\u0980-\u09FF',
    'devanagari': r'\u0900-\u097F', // Hindi
    'gujarati': r'\u0A80-\u0AFF',
    'kannada': r'\u0C80-\u0CFF',
    'tamil': r'\u0B80-\u0BFF',
    'telugu': r'\u0C00-\u0C7F',
    'malayalam': r'\u0D00-\u0D7F',
    'sinhala': r'\u0D80-\u0DFF',
    'thai': r'\u0E00-\u0E7F',
    'khmer': r'\u1780-\u17FF',
    'myanmar': r'\u1000-\u109F',
    'cjk': r'\u4E00-\u9FFF\u3040-\u30FF', // Chinese + Japanese kana
    'hangul': r'\uAC00-\uD7AF\u1100-\u11FF',
    'ethiopic': r'\u1200-\u137F',
  };

  static const Set<String> _nonHighlightableQueries = {
    'schemas',
    'juz',
    'hizb',
    'rub',
    '#',
    '=',
    'phrases',
    'cmds',
    'quizzes',
  };

  String _detectScript(String word) {
    for (final entry in _scriptRanges.entries) {
      if (entry.key == 'latin') continue;
      if (RegExp('[${entry.value}]').hasMatch(word)) return entry.key;
    }
    return 'latin';
  }

  bool get _shouldHighlightTopicSearch =>
      _searchQuery.isNotEmpty && !_nonHighlightableQueries.contains(_searchQuery);

  static const Set<String> _rtlScripts = {'arabic', 'hebrew', 'nko'};

  bool _isRtlText(String text) => _rtlScripts.contains(_detectScript(text));

  bool _tafsirSearchMode = false;
  List<Map<String, dynamic>> _tafsirSearchResults = [];

  final TextEditingController _tafsirRefController = TextEditingController();
  final FocusNode _tafsirRefFocusNode = FocusNode();
  final ScrollController _tafsirScrollController = ScrollController();

  FocusNode get _searchFocusNode => widget.searchFocusNode;
  FocusNode get _excludeFocusNode => widget.quranExcludeFocusNode;
  ItemScrollController get _itemScrollController => widget.itemScrollController;
  String get _searchQuery => widget.searchQuery;
  String get _excludeQuery => widget.excludeQuery;
  TextEditingController get _searchController => widget.searchController;
  TextEditingController get _excludeController => widget.excludeController;
  FocusNode get _tafsirSearchFocusNode => widget.tafsirSearchFocusNode;
  TextEditingController get _tafsirSearchController => widget.tafsirSearchController;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        if (widget.isQuranLoaded) {
          _refInputFocusNode.requestFocus();
        } else {
          _tafsirRefFocusNode.requestFocus();
        }
      }
    });
    _scrollToActiveVerseSearchResult();
  }

  @override
  void dispose() {
    _refInputController.dispose();
    _refInputFocusNode.dispose();
    _tafsirRefController.dispose();
    _tafsirRefFocusNode.dispose();
    _tafsirScrollController.dispose();
    super.dispose();
  }

  List<QuranIndexEntry> get _filtered {
    if (_searchQuery.isEmpty && _excludeQuery.isEmpty) return widget.entries;
    final result = <QuranIndexEntry>[];
    String? currentMainTopic;
    bool currentMainMatches = false;
    for (final entry in widget.entries) {
      if (!entry.isSubtopic) {
        currentMainTopic = entry.topic;
        final topicLower = entry.topic.toLowerCase();
        currentMainMatches =
            (_searchQuery.isEmpty || topicLower.contains(_searchQuery)) &&
                (_excludeQuery.isEmpty || !topicLower.contains(_excludeQuery));
        if (currentMainMatches) result.add(entry);
      } else {
        final topicLower = entry.topic.toLowerCase();
        final subtopicMatches =
            (_searchQuery.isEmpty || topicLower.contains(_searchQuery)) &&
                (_excludeQuery.isEmpty || !topicLower.contains(_excludeQuery));
        if (currentMainMatches) {
          result.add(entry);
        } else if (subtopicMatches) {
          if (result.isEmpty ||
              result.last.topic != currentMainTopic ||
              result.last.isSubtopic) {
            final parentEntry = widget.entries.firstWhere(
              (e) => !e.isSubtopic && e.topic == currentMainTopic,
              orElse: () => entry,
            );
            if (!result
                .any((e) => !e.isSubtopic && e.topic == parentEntry.topic)) {
              result.add(parentEntry);
            }
          }
          result.add(entry);
        }
      }
    }
    return result;
  }

  bool _isActiveRef(QuranVerseRef ref) {
    final active = widget.activeRef;
    if (active == null) return false;
    return active.surah == ref.surah &&
        active.fromAyah == ref.fromAyah &&
        active.toAyah == ref.toAyah &&
        active.isFullSurah == ref.isFullSurah;
  }

  bool _isSameRef(QuranVerseRef a, QuranVerseRef b) {
    return a.surah == b.surah &&
        a.fromAyah == b.fromAyah &&
        a.toAyah == b.toAyah &&
        a.isFullSurah == b.isFullSurah;
  }

  String _getSurahName(int surahNumber) {
    final surahs = getSurahsForLanguage(widget.selectedLanguage);
    final match = surahs.where((s) => s.number == surahNumber).firstOrNull;
    return match?.name ?? '';
  }

  void _scrollToActiveVerseSearchResult() {
    if (widget.activeRef == null || widget.quranVerseSearchResults.isEmpty) {
      return;
    }
    final index = widget.quranVerseSearchResults.indexWhere((hit) =>
        hit.surah == widget.activeRef!.surah &&
        hit.ayah == widget.activeRef!.fromAyah);
    if (index == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptScrollToVerseSearchIndex(index, attemptsLeft: 10);
    });
  }

  void _attemptScrollToVerseSearchIndex(int index, {required int attemptsLeft}) {
    if (!mounted || attemptsLeft <= 0) return;
    if (_quranVerseSearchScrollController.isAttached) {
      _quranVerseSearchScrollController.scrollTo(
        index: index,
        duration: const Duration(milliseconds: 300),
        alignment: 0.3,
      );
    } else {
      Future.delayed(const Duration(milliseconds: 100), () {
        _attemptScrollToVerseSearchIndex(index, attemptsLeft: attemptsLeft - 1);
      });
    }
  }

  Widget _buildPlayAllChip(List<QuranVerseRef> refs, int index) {
    final playableRefs = refs.map((r) {
      if (r.isFullSurah) {
        return QuranVerseRef(
          surah: r.surah,
          fromAyah: 1,
          toAyah: quranVerseCounts[r.surah],
          isFullSurah: false,
        );
      }
      return r;
    }).toList();

    return GestureDetector(
      onTap: () => widget.onPlayAllRequested?.call(playableRefs, index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha(40),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.green.withAlpha(160)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.playlist_play, size: 14, color: Colors.greenAccent),
            SizedBox(width: 4),
            Text(
              'All',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Matches Arabic diacritics (tashkeel/harakat) so Quranic text — which is
  // conventionally fully vocalized — can still be matched against plain,
  // undiacritized dictionary entries like 'الله' or 'ربكم'.
  static final RegExp _arabicDiacriticsPattern = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u08D3-\u08E1\u08E3-\u08FF]',
  );

  /// Strips Arabic diacritics from [text], returning the stripped string
  /// plus a map from each index in the stripped string back to its
  /// original index in [text] (needed so highlighted spans still cover the
  /// original diacritic-containing text, not the stripped copy).
  (String, List<int>) _stripArabicDiacritics(String text) {
    final buffer = StringBuffer();
    final indexMap = <int>[];
    for (int i = 0; i < text.length; i++) {
      if (!_arabicDiacriticsPattern.hasMatch(text[i])) {
        buffer.write(text[i]);
        indexMap.add(i);
      }
    }
    return (buffer.toString(), indexMap);
  }

  /// Finds Allah/Rabb matches in [text] ignoring Arabic diacritics.
  /// Returns (start, end) ranges in ORIGINAL [text] coordinates (end
  /// exclusive), sorted by start position.
  List<(int, int)> _findDiacriticInsensitiveAllahRanges(
      String text, String arabicAllahPattern) {
    if (arabicAllahPattern.isEmpty) return [];
    final (stripped, indexMap) = _stripArabicDiacritics(text);
    final pattern = RegExp(arabicAllahPattern);
    final ranges = <(int, int)>[];
    for (final m in pattern.allMatches(stripped)) {
      if (m.start >= m.end) continue;
      final origStart = indexMap[m.start];
      final origEnd = indexMap[m.end - 1] + 1;
      ranges.add((origStart, origEnd));
    }
    return ranges;
  }

  Widget _buildHadeethSectionWrapper(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              if (_hadeethExpanded) {
                widget.hadeethSearchFocusNode.unfocus();
                widget.hadeethExcludeFocusNode.unfocus();
              }
              setState(() => _hadeethExpanded = !_hadeethExpanded);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _hadeethExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.amber.withAlpha(180),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hadith',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'hadeethenc.com',
                    style: TextStyle(color: Colors.white24, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (_hadeethExpanded) ...[
            const Divider(color: Colors.white12, height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                child: HadeethPanel(
                  initialLanguage: 'English',
                  searchFocusNode: widget.hadeethSearchFocusNode,
                  excludeFocusNode: widget.hadeethExcludeFocusNode,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _playRefFromInput(BuildContext context) async {
    String text = _refInputController.text.trim();
    if (text.isEmpty) {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      text = clipboardData?.text?.trim() ?? '';
    }
    if (text.isEmpty) return;

    text = text.replaceAll(RegExp(r'[(){}\[\]]'), '');
    final normalized = text
        .replaceAll(RegExp(r'\s*:\s*'), ':')
        .replaceAll(RegExp(r'\s*-\s*'), '-');

    final match =
        RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(normalized.trim());
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not parse: "$text"'),
            duration: const Duration(seconds: 2)),
      );
      return;
    }

    final surah = int.parse(match.group(1)!);
    final fromAyah = int.parse(match.group(2)!);
    int? toAyah = match.group(3) != null ? int.parse(match.group(3)!) : null;

    if (toAyah != null && toAyah < fromAyah) {
      final fromStr = fromAyah.toString();
      final toStr = toAyah.toString();
      if (toStr.length < fromStr.length) {
        final prefix = fromStr.substring(0, fromStr.length - toStr.length);
        toAyah = int.tryParse(prefix + toStr) ?? toAyah;
      }
    }

    if (surah < 1 || surah > 114) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid surah number'),
            duration: Duration(seconds: 2)),
      );
      return;
    }
    final maxAyah = quranVerseCounts[surah];
    if (fromAyah < 1 || fromAyah > maxAyah) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Surah $surah only has $maxAyah verses'),
            duration: const Duration(seconds: 2)),
      );
      return;
    }
    if (toAyah != null && (toAyah < fromAyah || toAyah > maxAyah)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invalid range: Surah $surah has $maxAyah verses'),
            duration: const Duration(seconds: 2)),
      );
      return;
    }

    final ref = QuranVerseRef(
        surah: surah, fromAyah: fromAyah, toAyah: toAyah, isFullSurah: false);
    _refInputController.clear();
    widget.onVerseSelected(ref, 0);
    _refInputFocusNode.requestFocus();
  }

  _TafsirRange? _parseTafsirRef(BuildContext context, String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[(){}\[\]]'), '');
    if (text.isEmpty) return null;

    final surahOnly = RegExp(r'^(\d+)$').firstMatch(text);
    if (surahOnly != null) {
      final s = int.parse(surahOnly.group(1)!);
      if (s < 1 || s > 114) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid surah number'),
              duration: Duration(seconds: 2)),
        );
        return null;
      }
      return _TafsirRange(s, 0, quranVerseCounts[s]);
    }

    final m = RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(text);
    if (m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Could not parse: "$text"'),
            duration: const Duration(seconds: 2)),
      );
      return null;
    }
    final s = int.parse(m.group(1)!);
    final from = int.parse(m.group(2)!);
    int to = m.group(3) != null ? int.parse(m.group(3)!) : from;

    if (to < from) {
      final fromStr = from.toString();
      final toStr = to.toString();
      if (toStr.length < fromStr.length) {
        final prefix = fromStr.substring(0, fromStr.length - toStr.length);
        to = int.tryParse(prefix + toStr) ?? to;
      }
    }

    if (s < 1 || s > 114) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Invalid surah'), duration: Duration(seconds: 2)),
      );
      return null;
    }
    final max = quranVerseCounts[s];
    if (from < 0 || from > max || to < from || (to > 0 && to > max)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Surah $s has $max verses'),
            duration: const Duration(seconds: 2)),
      );
      return null;
    }
    return _TafsirRange(s, from, to);
  }

  void _lookupTafsir(BuildContext context) {
    final range = _parseTafsirRef(context, _tafsirRefController.text);
    if (range == null) return;

    final results = <Map<String, dynamic>>[];

    for (int ayah = range.from; ayah <= range.to; ayah++) {
      if (_tafsirMokhtasar) {
        final text = getTafsirMokhtasarForLanguage(
            _mokhtasarLanguage, range.surah, ayah);
        if (text != null) {
          results.add({
            'source': 'Mokhtasar',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirHilaliKhan) {
        final text = getTafsirHilaliKhan(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Hilali-Khan',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirRowwadEnglish) {
        final text = getTafsirRowwadEnglish(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Rowwad',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirNoorEnglish) {
        final text = getTafsirNoorEnglish(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Noor',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirYacobEnglish) {
        final text = getTafsirYacobEnglish(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Yacob',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirIbnKathir) {
        final text = getTafsirIbnKathirEnglish(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'IbnKathir',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirMoyassar) {
        final text = getTafsirMoyassar(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Moyassar',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirSaadi) {
        final text = getTafsirSaadi(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Saadi',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirYaseer) {
        final text = getTafsirYaseer(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Yaseer',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirNafahat) {
        final text = getTafsirNafahat(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Nafahat',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirSiraj) {
        final text = getTafsirSiraj(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Siraj',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirBaghawi) {
        final text = getTafsirBaghawi(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Baghawi',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirKatheer) {
        final text = getTafsirKatheer(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Katheer',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
    }

    setState(() => _tafsirResults = results);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tafsirScrollController.hasClients) {
        _tafsirScrollController.jumpTo(0);
      }
    });
    _tafsirRefFocusNode.requestFocus();
  }

  void _searchTafsirText(String query) {
    final terms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) {
      setState(() => _tafsirSearchResults = []);
      return;
    }

    bool matches(String? text) {
      if (text == null || text.isEmpty) return false;
      final lower = text.toLowerCase();
      return terms.every((t) => lower.contains(t));
    }

    final results = <Map<String, dynamic>>[];

    for (int surah = 1; surah <= 114; surah++) {
      final maxAyah = quranVerseCounts[surah]!;
      for (int ayah = 0; ayah <= maxAyah; ayah++) {
        if (_tafsirMokhtasar) {
          final text =
              getTafsirMokhtasarForLanguage(_mokhtasarLanguage, surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Mokhtasar', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (ayah == 0) continue;
        if (_tafsirHilaliKhan) {
          final text = getTafsirHilaliKhan(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Hilali-Khan', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirRowwadEnglish) {
          final text = getTafsirRowwadEnglish(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Rowwad', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirNoorEnglish) {
          final text = getTafsirNoorEnglish(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Noor', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirYacobEnglish) {
          final text = getTafsirYacobEnglish(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Yacob', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirIbnKathir) {
          final text = getTafsirIbnKathirEnglish(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'IbnKathir', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirMoyassar) {
          final text = getTafsirMoyassar(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Moyassar', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirSaadi) {
          final text = getTafsirSaadi(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Saadi', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirYaseer) {
          final text = getTafsirYaseer(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Yaseer', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirNafahat) {
          final text = getTafsirNafahat(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Nafahat', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirSiraj) {
          final text = getTafsirSiraj(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Siraj', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirBaghawi) {
          final text = getTafsirBaghawi(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Baghawi', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
        if (_tafsirKatheer) {
          final text = getTafsirKatheer(surah, ayah);
          if (matches(text)) {
            results.add({'source': 'Katheer', 'surah': surah, 'ayah': ayah, 'text': text!});
          }
        }
      }
      if (results.length >= 200) break;
    }

    setState(() => _tafsirSearchResults = results);
  }

  void _jumpToSearchResult(Map<String, dynamic> r) {
    final surah = r['surah'] as int;
    final ayah = r['ayah'] as int;
    final refString = '$surah:${ayah == 0 ? 1 : ayah}';
    setState(() => _tafsirSearchMode = false);
    _tafsirRefController.text = refString;
    _tafsirRefFocusNode.requestFocus();
    _lookupTafsir(context);
  }

  List<TextSpan> _highlightQuery(List<TextSpan> spans, String query) {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return spans;

    final pattern = RegExp(
      terms.map(RegExp.escape).join('|'),
      caseSensitive: false,
    );

    final result = <TextSpan>[];
    for (final span in spans) {
      final text = span.text;
      if (text == null || text.isEmpty || !pattern.hasMatch(text)) {
        result.add(span);
        continue;
      }
      int cursor = 0;
      for (final m in pattern.allMatches(text)) {
        if (m.start > cursor) {
          result.add(TextSpan(text: text.substring(cursor, m.start), style: span.style, recognizer: span.recognizer));
        }
        result.add(TextSpan(
          text: text.substring(m.start, m.end),
          style: (span.style ?? const TextStyle()).copyWith(
            backgroundColor: Colors.yellow,
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          recognizer: span.recognizer,
        ));
        cursor = m.end;
      }
      if (cursor < text.length) {
        result.add(TextSpan(text: text.substring(cursor), style: span.style, recognizer: span.recognizer));
      }
    }
    return result;
  }

  List<TextSpan> _colorParens(String text, TextStyle baseStyle) {
    final cyanStyle = baseStyle.copyWith(color: Colors.cyanAccent);
    final pattern = RegExp(r'\([^)]*\)');
    final result = <TextSpan>[];
    int cursor = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > cursor) {
        result.add(TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
      }
      result.add(TextSpan(text: text.substring(m.start, m.end), style: cyanStyle));
      cursor = m.end;
    }
    if (cursor < text.length) {
      result.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return result;
  }

  List<TextSpan> _colorParensAndAllah(String text, TextStyle baseStyle) {
    final allahWords =
        (_allahByLanguage[widget.selectedLanguage] ?? _allahByLanguage['English']!)
            .toList()
          ..sort((a, b) {
            final c = b.length.compareTo(a.length);
            return c != 0 ? c : a.compareTo(b);
          });

    const noBoundaryScripts = {
      'cjk', 'thai', 'khmer', 'arabic', 'hangul', 'ethiopic', 'devanagari',
      'gujarati', 'kannada', 'myanmar', 'georgian'
    };

    final patterns = <String>[];
    final arabicPatterns = <String>[];
    for (final w in allahWords) {
      final escaped = RegExp.escape(w);
      if (RegExp(r"^[a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ'\u2018\u2019]+$").hasMatch(w)) {
        final range = _scriptRanges['latin']!;
        patterns.add('(?<![$range])$escaped(?![$range])');
      } else {
        final script = _detectScript(w);
        if (script == 'arabic') {
          // Matched diacritic-insensitively in a separate pass below.
          arabicPatterns.add(escaped);
        } else if (noBoundaryScripts.contains(script)) {
          patterns.add(escaped);
        } else {
          final range = _scriptRanges[script] ?? _scriptRanges['cyrillic']!;
          patterns.add('(?<![$range])$escaped(?![$range])');
        }
      }
    }
    final allahPattern = patterns.join('|');
    final arabicAllahPattern = arabicPatterns.join('|');

    return _styleRunWithAllahPattern(text, baseStyle, allahPattern,
        arabicAllahPattern: arabicAllahPattern);
  }

  List<TextSpan> _styleRunWithAllahPattern(
      String text, TextStyle baseStyle, String allahPattern,
      {int parenDepth = 0, String arabicAllahPattern = ''}) {
    final cyanStyle = baseStyle.copyWith(color: Colors.cyanAccent);
    final greenStyle = baseStyle.copyWith(color: Colors.greenAccent);
    final purpleStyle = baseStyle.copyWith(color: const Color(0xFFCB93F5));
    final amberStyle = baseStyle.copyWith(color: Colors.amber);
    final quoteStyle = baseStyle.copyWith(color: const Color(0xFFFFB6C1));

    final parenColor = parenDepth.isEven ? cyanStyle : greenStyle;

    final quotePattern = r'"(?:[^"\\]|\\.)*"' r'|\u201c(?:[^\u201d])*\u201d';
    const parenPattern = r'\((?:[^()]|\([^()]*\))*\)';

    final combined = RegExp(
      '($quotePattern)'
      '|($parenPattern)'
      '|(\\[[^\\]]*\\])'
      '${allahPattern.isNotEmpty ? '|(?:$allahPattern)' : ''}',
    );

    // kind: 0 = quote, 1 = paren, 2 = bracket, 3 = allah word (non-Arabic)
    final ranges = <(int, int, int)>[];
    for (final m in combined.allMatches(text)) {
      if (m.group(1) != null) {
        ranges.add((m.start, m.end, 0));
      } else if (m.group(2) != null) {
        ranges.add((m.start, m.end, 1));
      } else if (m.group(3) != null) {
        ranges.add((m.start, m.end, 2));
      } else {
        ranges.add((m.start, m.end, 3));
      }
    }

    if (arabicAllahPattern.isNotEmpty) {
      final arabicRanges =
          _findDiacriticInsensitiveAllahRanges(text, arabicAllahPattern);
      for (final r in arabicRanges) {
        final overlaps =
            ranges.any((e) => r.$1 < e.$2 && e.$1 < r.$2);
        if (!overlaps) ranges.add((r.$1, r.$2, 3));
      }
    }

    ranges.sort((a, b) => a.$1.compareTo(b.$1));

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
        case 0:
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: matched[0], style: quoteStyle));
          result.addAll(_styleRunWithAllahPattern(
              inner, quoteStyle, allahPattern,
              parenDepth: parenDepth, arabicAllahPattern: arabicAllahPattern));
          result.add(TextSpan(text: matched[matched.length - 1], style: quoteStyle));
          break;
        case 1:
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '(', style: parenColor));
          result.addAll(_styleRunWithAllahPattern(
              inner, parenColor, allahPattern,
              parenDepth: parenDepth + 1, arabicAllahPattern: arabicAllahPattern));
          result.add(TextSpan(text: ')', style: parenColor));
          break;
        case 2:
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '[', style: amberStyle));
          result.addAll(_styleRunWithAllahPattern(
              inner, amberStyle, allahPattern,
              parenDepth: parenDepth, arabicAllahPattern: arabicAllahPattern));
          result.add(TextSpan(text: ']', style: amberStyle));
          break;
        default:
          result.add(TextSpan(text: matched, style: purpleStyle));
      }
      cursor = end;
    }
    if (cursor < text.length) {
      result.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return result;
  }

  List<TextSpan> _styledTopicSpans(String topic, TextStyle style) {
    final base = _colorParensAndAllah(topic, style);
    return _shouldHighlightTopicSearch
        ? _highlightQuery(base, _searchQuery)
        : base;
  }

  void _showSurahListPopup(BuildContext context) {
    final surahs = getSurahsForLanguage(widget.selectedLanguage);
    final isRtl = isRtlQuranLanguage(widget.selectedLanguage);

    showDialog(
      context: context,
      builder: (ctx) => Align(
        alignment: const Alignment(0.85, 0.0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            height: 520,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                  child: Row(
                    children: [
                      const Text('Surahs',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white54, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: surahs.length,
                    itemBuilder: (_, i) {
                      final s = surahs[i];
                      return InkWell(
                        onTap: widget.isQuranLoaded
                            ? () {
                                Navigator.of(ctx).pop();
                                final ref = QuranVerseRef(
                                  surah: s.number,
                                  fromAyah: 1,
                                  toAyah: quranVerseCounts[s.number],
                                  isFullSurah: true,
                                );
                                widget.onVerseSelected(ref, 0);
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text('${s.number}',
                                    style: const TextStyle(
                                        color: Colors.lightGreenAccent,
                                        fontSize: 12)),
                              ),
                              Expanded(
                                child: Directionality(
                                  textDirection: isRtl
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  child: Text(s.name,
                                      style: TextStyle(
                                        color: widget.isQuranLoaded
                                            ? Colors.lightBlueAccent
                                            : Colors.yellow,
                                        fontSize: 13,
                                      )),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(
                                    left: isRtl ? 8 : 0, right: isRtl ? 0 : 8),
                                child: Text('${quranVerseCounts[s.number]}',
                                    style: const TextStyle(
                                        color: Colors.white24, fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (_searchFocusNode.hasFocus ||
            _excludeFocusNode.hasFocus ||
            _refInputFocusNode.hasFocus ||
            _tafsirRefFocusNode.hasFocus ||
            _tafsirSearchFocusNode.hasFocus ||
            widget.quranVerseSearchFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.slash) {
          _searchFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          _buildHadeethSectionWrapper(context),
          if (_tafsirResults.isNotEmpty ||
          (_tafsirSearchMode && _tafsirSearchResults.isNotEmpty))
            Expanded(child: _buildTafsirSection(context))
          else ...[
            _buildTafsirSection(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: '/ Search topics...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white54, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white54, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onChanged: (v) =>
                          widget.onSearchChanged(v.trim().toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _excludeController,
                      focusNode: _excludeFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Exclude...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.block,
                            color: Colors.white54, size: 20),
                        suffixIcon: _excludeQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white54, size: 20),
                                onPressed: () {
                                  _excludeController.clear();
                                  widget.onExcludeChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onChanged: (v) =>
                          widget.onExcludeChanged(v.trim().toLowerCase()),
                    ),
                  ),
                  if (availableQuranIndexLanguages.length > 1) ...[
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: widget.selectedLanguage,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                      underline: const SizedBox(),
                      isDense: true,
                      items: availableQuranIndexLanguages
                          .map((lang) =>
                              DropdownMenuItem(value: lang, child: Text(lang)))
                          .toList(),
                      onChanged: (lang) {
                        if (lang != null) {
                          widget.onLanguageChanged(lang);
                          widget.onSearchChanged(widget.searchQuery);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (widget.isQuranLoaded) ...[
                       Padding(
                         padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                         child: Row(
                           children: [
                             Expanded(
                               child: SizedBox(
                                 height: 32,
                                 child: TextField(
                                   controller: widget.quranVerseSearchController,
                                   focusNode: widget.quranVerseSearchFocusNode,
                                   textDirection: _isRtlText(widget.quranVerseSearchController.text)
                                       ? TextDirection.rtl
                                       : TextDirection.ltr,
                                   style: const TextStyle(color: Colors.white, fontSize: 13),
                                   decoration: InputDecoration(
                                     hintText: 'Search verse text…',
                                     hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                                     prefixIcon: const Icon(Icons.menu_book, color: Colors.amber, size: 16),
                                     suffixIcon: widget.quranVerseSearchController.text.isNotEmpty
                                         ? IconButton(
                                             icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                                             padding: EdgeInsets.zero,
                                             constraints: const BoxConstraints(),
                                             onPressed: () {
                                               widget.quranVerseSearchController.clear();
                                               widget.onQuranVerseSearchChanged('');
                                             },
                                           )
                                         : null,
                                     filled: true,
                                     fillColor: Colors.black26,
                                     border: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(4),
                                       borderSide: BorderSide(color: Colors.amber.withAlpha(100)),
                                     ),
                                     contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                   ),
                                   onSubmitted: widget.onQuranVerseSearchChanged,
                                 ),
                               ),
                             ),
                             if (widget.quranVerseIndexBuilding) ...[
                               const SizedBox(width: 8),
                               const SizedBox(
                                 width: 12, height: 12,
                                 child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                               ),
                               const SizedBox(width: 4),
                               const Text('Indexing…',
                                   style: TextStyle(color: Colors.white38, fontSize: 11)),
                             ],
                           ],
                         ),
                       ),
                     ],
            if (!widget.isQuranLoaded)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12),
                          children: [
                            const TextSpan(
                                text:
                                    'Load a Quran Verse by Verse audiobook to enable navigation — '),
                            TextSpan(
                              text: 'https://t.me/AllahAudiobooks',
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () async {
                                  final uri =
                                      Uri.parse('https://t.me/AllahAudiobooks');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text('${filtered.length} topics',
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(width: 10),
                    const Text('*vtt',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: '* no vtt - csv needs to be downloadable on quranenc.com for an available vtt'
                          '${widget.isQuranLoaded ? '\n⇧Q = next ayah' : ''}',
                      preferBelow: true,
                      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.info_outline, color: Colors.white38, size: 14),
                    ),
                    SizedBox(
                      width: 120,
                      height: 28,
                      child: TextField(
                        controller: _refInputController,
                        focusNode: _refInputFocusNode,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: '38:36-40',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.deepPurple.withAlpha(160)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.deepPurple.withAlpha(100)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Colors.deepPurple),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: Colors.deepPurple, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed:
                                widget.isQuranLoaded ? () => _playRefFromInput(context) : null,
                          ),
                        ),
                        onSubmitted:
                            widget.isQuranLoaded ? (_) => _playRefFromInput(context) : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _quickFilterChip('Schemas', 'schemas'),
                    const SizedBox(width: 8),
                    _quickFilterChip('Juz', 'juz'),
                    const SizedBox(width: 4),
                    _quickFilterChip('Hizb', 'hizb'),
                    const SizedBox(width: 4),
                    _quickFilterChip('Rub', 'rub'),
                    const SizedBox(width: 4),
                    _quickFilterChip('months', 'islamic months'),
                    const SizedBox(width: 4),
                    _quickFilterChip('99names', '#'),
                    const SizedBox(width: 4),
                    _quickFilterChip('=ayah', '\='),
                    const SizedBox(width: 4),
                    _quickFilterChip('=phrase', 'phrases'),
                    const SizedBox(width: 4),
                    _quickFilterChip('cmds', 'cmds'),
                    const SizedBox(width: 4),
                    _quickFilterChip('Quiz', 'quizzes'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showSurahListPopup(context),
                      child: const Text('Surahs',
                          style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message: _expandedIndices.isEmpty ? 'Expand all' : 'Collapse all',
                      child: IconButton(
                        onPressed: () => setState(() {
                          if (_expandedIndices.length >= widget.entries.length) {
                            _expandedIndices.clear();
                          } else {
                            _expandedIndices
                                .addAll(List.generate(widget.entries.length, (i) => i));
                          }
                        }),
                        icon: Icon(
                          _expandedIndices.isEmpty ? Icons.unfold_more : Icons.unfold_less,
                          color: Colors.white38,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(color: Colors.white12, height: 1),
                        if (widget.quranVerseSearchController.text.isNotEmpty) ...[
                          Expanded(
                            child: widget.quranVerseSearchResults.isEmpty
                                ? const Center(
                                    child: Text('No matches',
                                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                                  )
                                  : ScrollablePositionedList.separated(
                                      itemScrollController: _quranVerseSearchScrollController,
                                      itemCount: widget.quranVerseSearchResults.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(color: Colors.white12, height: 12),
                                          itemBuilder: (_, i) {
                                            final hit = widget.quranVerseSearchResults[i];
                                            final isActive = widget.activeRef != null &&
                                                widget.activeRef!.surah == hit.surah &&
                                                widget.activeRef!.fromAyah == hit.ayah;
                                            final isRtl = _isRtlText(hit.text);
                                            const baseStyle =
                                                TextStyle(color: Colors.white70, fontSize: 13, height: 1.4);
                                            final spans = _highlightQuery(
                                              [TextSpan(text: hit.text, style: baseStyle)],
                                              widget.quranVerseSearchController.text,
                                            );
                                            return InkWell(
                                              onTap: () => widget.onQuranVerseSearchResultTap(hit),
                                              child: Directionality(
                                                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                                                child: Container(
                                                  color: isActive ? Colors.deepPurple.withAlpha(40) : null,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Text('${hit.surah}:${hit.ayah}',
                                                              style: TextStyle(
                                                                  color: isActive
                                                                      ? Colors.lightBlueAccent
                                                                      : Colors.amber,
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w600)),
                                                          if (isActive) ...[
                                                            const SizedBox(width: 6),
                                                            const Icon(Icons.play_circle_fill,
                                                                color: Colors.lightBlueAccent, size: 14),
                                                          ],
                                                          const Spacer(),
                                                          Icon(
                                                            isRtl ? Icons.chevron_left : Icons.chevron_right,
                                                            color: Colors.white24,
                                                            size: 16,
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text.rich(
                                                        TextSpan(children: spans),
                                                        maxLines: 3,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                  ),
                          ),
                        ] else
                          Expanded(
                          child: ScrollablePositionedList.builder(
                            itemScrollController: _itemScrollController,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final entry = filtered[index];
                              final globalIndex = widget.entries.indexOf(entry);
                              final hasActiveRef = entry.refs.any((r) =>
                                  _isActiveRef(r) ||
                                  (!widget.isQuranLoaded &&
                                      _lastTafsirRef != null &&
                                      _isSameRef(_lastTafsirRef!, r)));

                              if (entry.refs.isEmpty && entry.isSubtopic) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(48, 2, 16, 2),
                                  child: Directionality(
                                    textDirection:
                                        isRtlQuranLanguage(widget.selectedLanguage)
                                            ? TextDirection.rtl
                                            : TextDirection.ltr,
                                            child: Text.rich(
                                              TextSpan(
                                                children: _shouldHighlightTopicSearch
                                                    ? _highlightQuery(
                                                        _colorParensAndAllah(
                                                          entry.topic,
                                                          const TextStyle(
                                                              color: Colors.white38,
                                                              fontSize: 13,
                                                              fontStyle: FontStyle.italic),
                                                        ),
                                                        _searchQuery,
                                                      )
                                                    : _colorParensAndAllah(
                                                        entry.topic,
                                                        const TextStyle(
                                                            color: Colors.white38,
                                                            fontSize: 13,
                                                            fontStyle: FontStyle.italic),
                                                      ),
                                              ),
                                            ),
                                  ),
                                );
                              }

                              final isExpanded = _expandedIndices.contains(globalIndex) ||
                                  _searchQuery.isNotEmpty ||
                                  hasActiveRef;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: () => setState(() {
                                      if (_expandedIndices.contains(globalIndex)) {
                                        _expandedIndices.remove(globalIndex);
                                        if (!entry.isSubtopic) {
                                          for (int i = globalIndex + 1;
                                              i < widget.entries.length;
                                              i++) {
                                            if (widget.entries[i].isSubtopic &&
                                                widget.entries[i].parentTopic ==
                                                    entry.topic) {
                                              _expandedIndices.remove(i);
                                            } else if (!widget.entries[i].isSubtopic) break;
                                          }
                                        }
                                      } else {
                                        _expandedIndices.add(globalIndex);
                                        if (!entry.isSubtopic) {
                                          for (int i = globalIndex + 1;
                                              i < widget.entries.length;
                                              i++) {
                                            if (widget.entries[i].isSubtopic &&
                                                widget.entries[i].parentTopic ==
                                                    entry.topic) {
                                              _expandedIndices.add(i);
                                            } else if (!widget.entries[i].isSubtopic) break;
                                          }
                                        }
                                      }
                                    }),
                                    child: Container(
                                      padding: EdgeInsets.only(
                                        left: entry.isSubtopic ? 32 : 16,
                                        right: 16,
                                        top: entry.isSubtopic ? 6 : 10,
                                        bottom: entry.isSubtopic ? 6 : 10,
                                      ),
                                      color: hasActiveRef
                                          ? Colors.deepPurple.withAlpha(40)
                                          : entry.isSubtopic
                                              ? Colors.black12
                                              : Colors.transparent,
                                      child: Row(
                                        children: [
                                          Icon(
                                            isExpanded
                                                ? Icons.expand_less
                                                : Icons.expand_more,
                                            color: Colors.white38,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Directionality(
                                              textDirection: isRtlQuranLanguage(
                                                      widget.selectedLanguage)
                                                  ? TextDirection.rtl
                                                  : TextDirection.ltr,
                                                  child: Text.rich(
                                                    TextSpan(
                                                      children: _styledTopicSpans(
                                                        entry.topic,
                                                        TextStyle(
                                                          color: hasActiveRef
                                                              ? Colors.purple[200]
                                                              : entry.isSubtopic
                                                                  ? Colors.white70
                                                                  : Colors.white,
                                                          fontSize: entry.isSubtopic ? 13 : 14,
                                                          fontWeight: hasActiveRef
                                                              ? FontWeight.bold
                                                              : entry.isSubtopic
                                                                  ? FontWeight.normal
                                                                  : FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            '${entry.refs.length} ref${entry.refs.length == 1 ? '' : 's'}',
                                            style: const TextStyle(
                                                color: Colors.white24, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          entry.isSubtopic ? 56 : 40, 0, 16, 8),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if (widget.isQuranLoaded && widget.onPlayAllRequested != null && entry.refs.length > 1)
                                            _buildPlayAllChip(entry.refs, index),
                                          ...entry.refs.map((ref) {
                                          final isActive = _isActiveRef(ref) ||
                                              (!widget.isQuranLoaded &&
                                                  _lastTafsirRef != null &&
                                                  _isSameRef(_lastTafsirRef!, ref));
                                          return Tooltip(
                                            message: _getSurahName(ref.surah),
                                            preferBelow: true,
                                            verticalOffset: 32,
                                            textStyle: const TextStyle(
                                                color: Colors.white, fontSize: 13),
                                            decoration: BoxDecoration(
                                              color: Colors.deepPurple,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: GestureDetector(
                                              onTap: () {
                                                if (widget.isQuranLoaded) {
                                                  widget.onVerseSelected(ref, index);
                                                  _refInputFocusNode.requestFocus();
                                                } else {
                                                  final refString = (ref.toAyah != null &&
                                                          ref.toAyah != ref.fromAyah)
                                                      ? '${ref.surah}:${ref.fromAyah}-${ref.toAyah}'
                                                      : '${ref.surah}:${ref.fromAyah}';
                                                  setState(() {
                                                    _lastTafsirRef = ref;
                                                    _lastTafsirIndex = index;
                                                  });
                                                  _tafsirRefController.text = refString;
                                                  _tafsirRefFocusNode.requestFocus();
                                                  _lookupTafsir(context);
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: isActive
                                                      ? Colors.deepPurple
                                                      : widget.isQuranLoaded
                                                          ? Colors.blueGrey[900]
                                                          : Colors.deepOrange.withAlpha(40),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isActive
                                                        ? Colors.purple
                                                        : widget.isQuranLoaded
                                                            ? Colors.lightBlue
                                                                .withAlpha(120)
                                                            : Colors.deepOrange
                                                                .withAlpha(80),
                                                  ),
                                                ),
                                                child: Text(
                                                  ref.displayLabel,
                                                  style: TextStyle(
                                                    color: isActive
                                                        ? Colors.white
                                                        : widget.isQuranLoaded
                                                            ? Colors.lightBlueAccent
                                                            : Colors.yellow,
                                                    fontSize: 13,
                                                    fontWeight: isActive
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        ],
                                      ),
                                    ),
                                  if (index < filtered.length - 1)
                                    const Divider(color: Colors.white10, height: 1),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

  Widget _quickFilterChip(String label, String query) {
    final isActive = _searchQuery == query;
    return GestureDetector(
      onTap: () {
        if (isActive) {
          _searchController.clear();
          widget.onSearchChanged('');
        } else {
          _searchController.text = query;
          widget.onSearchChanged(query);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isActive ? Colors.deepPurple : Colors.deepPurple.withAlpha(40),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.deepPurple.withAlpha(160)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.purple[200],
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTafsirSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Mode toggle: Browse by reference vs. Search text
          Row(
            children: [
              _modeChip('Browse', !_tafsirSearchMode, () {
                setState(() => _tafsirSearchMode = false);
                _tafsirRefFocusNode.requestFocus();
              }),
              const SizedBox(width: 6),
              _modeChip('Search', _tafsirSearchMode, () {
                setState(() => _tafsirSearchMode = true);
                _tafsirSearchFocusNode.requestFocus();
              }),
              const SizedBox(width: 6),
              GestureDetector(
                              onTap: () {
                                setState(() {
                                  _tafsirResults = [];
                                  _tafsirSearchResults = [];
                                  _tafsirSearchController.clear();
                                });
                                if (_lastTafsirIndex != null) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_itemScrollController.isAttached) {
                                      _itemScrollController.scrollTo(
                                        index: _lastTafsirIndex!,
                                        duration: const Duration(milliseconds: 300),
                                      );
                                    }
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.deepOrange.withAlpha(160)),
                                ),
                                child: const Text('Clear',
                                    style: TextStyle(color: Colors.deepOrange, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('Arabic:',
                                style: TextStyle(color: Colors.white38, fontSize: 12)),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Moyassar', _tafsirMoyassar, (v) {
                              setState(() => _tafsirMoyassar = v ?? false);
                            }, Colors.pinkAccent),
                            const SizedBox(width: 10),
                            _tafsirCheckbox('Saadi', _tafsirSaadi, (v) {
                              setState(() => _tafsirSaadi = v ?? false);
                            }, Colors.amber),
                            const SizedBox(width: 10),
                            _tafsirCheckbox('Yaseer', _tafsirYaseer, (v) {
                              setState(() => _tafsirYaseer = v ?? false);
                            }, Colors.tealAccent),
                            const SizedBox(width: 10),
                            _tafsirCheckbox('Nafahat', _tafsirNafahat, (v) {
                              setState(() => _tafsirNafahat = v ?? false);
                            }, Colors.limeAccent),
                            const SizedBox(width: 10),
                            _tafsirCheckbox('Siraj', _tafsirSiraj, (v) {
                              setState(() => _tafsirSiraj = v ?? false);
                            }, Colors.indigoAccent),
                            const SizedBox(width: 10),
                            _tafsirCheckbox('Baghawi', _tafsirBaghawi, (v) {
                              setState(() => _tafsirBaghawi = v ?? false);
                            }, Colors.deepOrangeAccent),
                            const SizedBox(width: 10),
                            _tafsirCheckbox('Katheer', _tafsirKatheer, (v) {
                              setState(() => _tafsirKatheer = v ?? false);
                            }, Colors.brown),
                            const SizedBox(width: 6),
                            _selectAllCheckbox(
                              _allArabicTafsirsSelected, _toggleAllArabicTafsirs),
                          ],
                        ),
          const SizedBox(height: 6),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_tafsirSearchMode)
                    SizedBox(
                      width: 220,
                      height: 32,
                      child: TextField(
                        controller: _tafsirSearchController,
                        focusNode: _tafsirSearchFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search tafsir text…',
                          hintStyle: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                          prefixIcon: const Icon(Icons.search,
                              color: Colors.teal, size: 16),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                        onSubmitted: _searchTafsirText,
                      ),
                    )
                  else
                    SizedBox(
                      width: 180,
                      height: 32,
                      child: TextField(
                        controller: _tafsirRefController,
                        focusNode: _tafsirRefFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: '2:255 or 2:1-5',
                          hintStyle: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                BorderSide(color: Colors.teal.withAlpha(160)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                BorderSide(color: Colors.teal.withAlpha(80)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: const BorderSide(color: Colors.teal),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search,
                                color: Colors.teal, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _lookupTafsir(context),
                          ),
                        ),
                        onSubmitted: (_) => _lookupTafsir(context),
                      ),
                    ),
                  const SizedBox(width: 8),
                  _tafsirCheckbox('Mokhtasar', _tafsirMokhtasar, (v) {
                    setState(() => _tafsirMokhtasar = v ?? false);
                  }, Colors.lightBlueAccent),
                  const SizedBox(width: 8),
                  if (_tafsirMokhtasar)
                    DropdownButton<String>(
                      value: _mokhtasarLanguage,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      underline: const SizedBox(),
                      isDense: true,
                      items: mokhtasarLanguages
                          .map((lang) =>
                              DropdownMenuItem(value: lang, child: Text(lang)))
                          .toList(),
                      onChanged: (lang) {
                        if (lang != null) {
                          setState(() => _mokhtasarLanguage = lang);
                          if (_tafsirRefController.text.isNotEmpty) {
                            _lookupTafsir(context);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _tafsirCheckbox('Hilali-Khan', _tafsirHilaliKhan, (v) {
                      setState(() => _tafsirHilaliKhan = v ?? false);
                    }, Colors.greenAccent),
                    const SizedBox(width: 12),
                    _tafsirCheckbox('Rowwad', _tafsirRowwadEnglish, (v) {
                      setState(() => _tafsirRowwadEnglish = v ?? false);
                    }, Colors.orangeAccent),
                    const SizedBox(width: 12),
                    _tafsirCheckbox('Noor', _tafsirNoorEnglish, (v) {
                      setState(() => _tafsirNoorEnglish = v ?? false);
                    }, Colors.redAccent),
                    const SizedBox(width: 12),
                    _tafsirCheckbox('Yacob', _tafsirYacobEnglish, (v) {
                      setState(() => _tafsirYacobEnglish = v ?? false);
                    }, Colors.purpleAccent),
                    const SizedBox(width: 12),
                    _tafsirCheckbox('IbnKathir', _tafsirIbnKathir, (v) {
                      setState(() => _tafsirIbnKathir = v ?? false);
                    }, Colors.brown),
                    const SizedBox(width: 6),
                    _selectAllCheckbox(
                        _allEnglishTafsirsSelected, _toggleAllEnglishTafsirs),
                ],
              ),
            ),
            if (_tafsirSearchMode) ...[
              const SizedBox(height: 8),
              if (_tafsirSearchResults.isEmpty &&
                  _tafsirSearchController.text.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No matches',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                )
              else if (_tafsirSearchResults.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _tafsirSearchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 12),
                    itemBuilder: (_, i) {
                      final r = _tafsirSearchResults[i];
                      return InkWell(
                        onTap: () => _jumpToSearchResult(r),
                        child: _buildTafsirCard(r, highlightQuery: _tafsirSearchController.text),
                      );
                    },
                  ),
                ),
            ] else if (_tafsirResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: _tafsirScrollController,
                  itemCount: _tafsirResults.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 12),
                  itemBuilder: (_, i) => _buildTafsirCard(_tafsirResults[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.teal : Colors.teal.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.teal.withAlpha(160)),
        ),
        child: Text(label,
            style: TextStyle(color: active ? Colors.white : Colors.teal[200], fontSize: 12)),
      ),
    );
  }

  Widget _tafsirCheckbox(
      String label, bool value, ValueChanged<bool?> onChanged, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: color,
            side: const BorderSide(color: Colors.white38),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  bool get _allArabicTafsirsSelected =>
        _tafsirMoyassar &&
        _tafsirSaadi &&
        _tafsirYaseer &&
        _tafsirNafahat &&
        _tafsirSiraj &&
        _tafsirBaghawi &&
        _tafsirKatheer;

    bool get _allEnglishTafsirsSelected =>
        _tafsirHilaliKhan &&
        _tafsirRowwadEnglish &&
        _tafsirNoorEnglish &&
        _tafsirYacobEnglish &&
        _tafsirIbnKathir;

    void _toggleAllArabicTafsirs(bool? value) {
      final v = value ?? false;
      setState(() {
        _tafsirMoyassar = v;
        _tafsirSaadi = v;
        _tafsirYaseer = v;
        _tafsirNafahat = v;
        _tafsirSiraj = v;
        _tafsirBaghawi = v;
        _tafsirKatheer = v;
      });
    }

    void _toggleAllEnglishTafsirs(bool? value) {
      final v = value ?? false;
      setState(() {
        _tafsirHilaliKhan = v;
        _tafsirRowwadEnglish = v;
        _tafsirNoorEnglish = v;
        _tafsirYacobEnglish = v;
        _tafsirIbnKathir = v;
      });
    }

    Widget _selectAllCheckbox(bool value, ValueChanged<bool?> onChanged) {
        return SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blueGrey,
            side: const BorderSide(color: Colors.blueGrey, width: 1.0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }

  void _onTafsirVerseTapped(String ref) {
    final match = RegExp(r'(\d+):(\d+)(?:-(\d+))?').firstMatch(ref);
    if (match == null) return;
    final surah = int.parse(match.group(1)!);
    final fromAyah = int.parse(match.group(2)!);
    final toAyah = match.group(3) != null ? int.parse(match.group(3)!) : null;
    if (widget.isQuranLoaded) {
      final verseRef = QuranVerseRef(
        surah: surah,
        fromAyah: fromAyah,
        toAyah: toAyah,
        isFullSurah: false,
      );
      widget.onVerseSelected(verseRef, 0);
    } else {
      final refString =
          toAyah != null ? '$surah:$fromAyah-$toAyah' : '$surah:$fromAyah';
      _tafsirRefController.text = refString;
      _tafsirRefFocusNode.requestFocus();
    }
  }

  Widget _buildTafsirCard(Map<String, dynamic> r, {String? highlightQuery}) {
      final source = r['source'] as String;
      final surah = r['surah'] as int;
      final ayah = r['ayah'] as int;
      final text = r['text'] as String;
      final isRtl = source == 'Mokhtasar Ar' ||
          isMokhtasarRtl(_mokhtasarLanguage) ||
          source == 'Saadi' ||
          source == 'Moyassar' ||
          source == 'Baghawi' ||
          source == 'Yaseer' ||
          source == 'Siraj' ||
          source == 'Nafahat' ||
          source == 'Katheer';
      final sourceColor = switch (source) {
        'Mokhtasar' => Colors.lightBlueAccent,
        'Rowwad' => Colors.orangeAccent,
        'Noor' => Colors.redAccent,
        'Yacob' => Colors.purpleAccent,
        'IbnKathir' => Colors.brown,
        'Moyassar' => Colors.pinkAccent,
        'Saadi' => Colors.amber,
        'Yaseer' => Colors.tealAccent,
        'Siraj' => Colors.indigoAccent,
        'Nafahat' => Colors.limeAccent,
        'Baghawi' => Colors.deepOrangeAccent,
        'Katheer' => Colors.brown,
        _ => Colors.greenAccent,
      };
      final ayahLabel = ayah == 0 ? '$surah:intro' : '$surah:$ayah';
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(6),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: sourceColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: sourceColor.withAlpha(100)),
                    ),
                    child: Text(source,
                        style: TextStyle(
                            color: sourceColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(ayahLabel,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white24, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copy text',
                    onPressed: () => Clipboard.setData(ClipboardData(text: text)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildTafsirText(text, isRtl, isIntro: ayah == 0, highlightQuery: highlightQuery),
            ],
          ),
        ),
      );
    }

    List<TextSpan> _parseMainText(
      String text, {
      TextStyle? baseStyleOverride,
      void Function(String)? onVerseTapped,
      String language = 'English',
      int parenDepth = 0,
    }) {
      final spans = <TextSpan>[];
      final baseStyle = baseStyleOverride ??
          const TextStyle(color: Colors.white, fontSize: 14, height: 1.55);
      const amber = TextStyle(color: Colors.amber, fontSize: 14, height: 1.55);
      const purple =
          TextStyle(color: Color(0xFFCB93F5), fontSize: 14, height: 1.55);
      const quoteStyle =
          TextStyle(color: Color(0xFFFFB6C1), fontSize: 14, height: 1.55);
      const verseStyle =
          TextStyle(color: Colors.lightBlueAccent, fontSize: 14, height: 1.55);
      const cyanStyle =
          TextStyle(color: Colors.cyanAccent, fontSize: 14, height: 1.55);
      const nestedParenStyle =
          TextStyle(color: Colors.greenAccent, fontSize: 14, height: 1.55);

      final parenColor = parenDepth.isEven ? cyanStyle : nestedParenStyle;

      final allahWords =
          (_allahByLanguage[language] ?? _allahByLanguage['English']!).toList()
            ..sort((a, b) {
              final c = b.length.compareTo(a.length);
              return c != 0 ? c : a.compareTo(b);
            });

      const noBoundaryScripts = {
        'cjk',
        'thai',
        'khmer',
        'arabic',
        'hangul',
        'ethiopic',
        'devanagari',
        'gujarati',
        'kannada',
        'myanmar',
        'georgian'
      };

      final patterns = <String>[];
      final arabicPatterns = <String>[];
      for (final w in allahWords) {
        final escaped = RegExp.escape(w);
        if (RegExp(r"^[a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ'\u2018\u2019]+$").hasMatch(w)) {
          final range = _scriptRanges['latin']!;
          patterns.add('(?<![$range])$escaped(?![$range])');
        } else {
          final script = _detectScript(w);
          if (script == 'arabic') {
            arabicPatterns.add(escaped);
          } else if (noBoundaryScripts.contains(script)) {
            patterns.add(escaped);
          } else {
            final range = _scriptRanges[script] ?? _scriptRanges['cyrillic']!;
            patterns.add('(?<![$range])$escaped(?![$range])');
          }
        }
      }
      final allahPattern = patterns.join('|');
      final arabicAllahPattern = arabicPatterns.join('|');
      final verseRegex = RegExp(r'\b\d{1,3}:\d{1,3}(?:-\d{1,3})?\b');

      final quotePattern = RegExp(r'"(?:[^"\\]|\\.)*"'
          r'|\u201c(?:[^\u201d])*\u201d');

      // supports one level of nested parens: (...(...)...)
      const nestedParenPattern = r'\((?:[^()]|\([^()]*\))*\)';

      List<TextSpan> parseWithAllah(String t, TextStyle base, {int depth = 0}) {
        final inner = <TextSpan>[];
        final combined = RegExp(
            '${allahPattern.isNotEmpty ? '(?:$allahPattern)|' : ''}\\b\\d{1,3}:\\d{1,3}(?:-\\d{1,3})?\\b|($nestedParenPattern)|\\[[^\\]]*\\]');

        // kind: 0 = paren, 1 = bracket, 2 = verse ref, 3 = allah word (non-Arabic)
        final ranges = <(int, int, int)>[];
        for (final m in combined.allMatches(t)) {
          final word = m.group(0)!;
          if (verseRegex.hasMatch(word)) {
            ranges.add((m.start, m.end, 2));
          } else if (m.group(1) != null) {
            ranges.add((m.start, m.end, 0));
          } else if (word.startsWith('[')) {
            ranges.add((m.start, m.end, 1));
          } else {
            ranges.add((m.start, m.end, 3));
          }
        }

        if (arabicAllahPattern.isNotEmpty) {
          final arabicRanges =
              _findDiacriticInsensitiveAllahRanges(t, arabicAllahPattern);
          for (final r in arabicRanges) {
            final overlaps = ranges.any((e) => r.$1 < e.$2 && e.$1 < r.$2);
            if (!overlaps) ranges.add((r.$1, r.$2, 3));
          }
        }

        ranges.sort((a, b) => a.$1.compareTo(b.$1));

        int c = 0;
        for (final r in ranges) {
          final start = r.$1, end = r.$2, kind = r.$3;
          if (start < c) continue;
          if (start > c) {
            inner.add(TextSpan(text: t.substring(c, start), style: base));
          }
          final word = t.substring(start, end);
          switch (kind) {
            case 2:
              inner.add(TextSpan(
                text: word,
                style: verseStyle,
                recognizer: onVerseTapped != null
                    ? (TapGestureRecognizer()..onTap = () => onVerseTapped(word))
                    : null,
              ));
              break;
            case 0:
              final pColor = depth.isEven ? cyanStyle : nestedParenStyle;
              final pInner = word.substring(1, word.length - 1);
              inner.add(TextSpan(text: '(', style: pColor));
              inner.addAll(parseWithAllah(pInner, pColor, depth: depth + 1));
              inner.add(TextSpan(text: ')', style: pColor));
              break;
            case 1:
              inner.add(TextSpan(text: word, style: amber));
              break;
            default:
              inner.add(TextSpan(text: word, style: purple));
          }
          c = end;
        }
        if (c < t.length) inner.add(TextSpan(text: t.substring(c), style: base));
        return inner;
      }

      final pattern = RegExp(
        r'("(?:[^"\\]|\\.)*"' // "..."
        r'|\u201c(?:[^\u201d])*\u201d)' // "..."
        r'|(\[[^\]]*\])' // [...]
        r'|(' '$nestedParenPattern' r')' // (...) with 1 level nesting
        r'|\b\d{1,3}:\d{1,3}(?:-\d{1,3})?\b', // verse refs
      );

      int cursor = 0;
      for (final match in pattern.allMatches(text)) {
        if (match.start > cursor) {
          spans.addAll(
              parseWithAllah(text.substring(cursor, match.start), baseStyle));
        }
        final m = match.group(0) ?? '';
        if (match.group(1) != null) {
          spans.addAll(parseWithAllah(m, quoteStyle));
        } else if (match.group(2) != null) {
          final bracketInner = m.substring(1, m.length - 1);
          spans.add(TextSpan(text: '[', style: amber));
          spans.addAll(parseWithAllah(bracketInner, amber));
          spans.add(TextSpan(text: ']', style: amber));
        } else if (match.group(3) != null) {
          final pInner = m.substring(1, m.length - 1);
          spans.add(TextSpan(text: '(', style: parenColor));
          spans.addAll(parseWithAllah(pInner, parenColor, depth: parenDepth + 1));
          spans.add(TextSpan(text: ')', style: parenColor));
        } else if (verseRegex.hasMatch(m)) {
          spans.add(TextSpan(
            text: m,
            style: verseStyle,
            recognizer: onVerseTapped != null
                ? (TapGestureRecognizer()..onTap = () => onVerseTapped(m))
                : null,
          ));
        } else {
          spans.add(TextSpan(text: m, style: purple));
        }
        cursor = match.end;
      }
      if (cursor < text.length) {
        spans.addAll(parseWithAllah(text.substring(cursor), baseStyle));
      }
      return spans;
    }

  Widget _buildTafsirText(String text, bool isRtl, {bool isIntro = false, String? highlightQuery}) {
      if (isIntro) {
        return SelectableText(
          text,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
          style: const TextStyle(color: Colors.amber, fontSize: 14, height: 1.55),
        );
      }

      const orangeStyle =
          TextStyle(color: Colors.orangeAccent, fontSize: 14, height: 1.55);
      const greenStyle =
          TextStyle(color: Colors.greenAccent, fontSize: 14, height: 1.55);

      final lowerText = text.toLowerCase();
      const beneficialMarker = '• beneficial points:';
      const footnotesMarker = 'footnotes:';

      final beneficialIdx = lowerText.indexOf(beneficialMarker);
      final footnotesIdx = lowerText.indexOf(footnotesMarker);

      if (beneficialIdx == -1 && footnotesIdx == -1) {
        var spans = _parseMainText(text,
            onVerseTapped: _onTafsirVerseTapped,
            language: _mokhtasarLanguage);
        if (highlightQuery != null && highlightQuery.isNotEmpty) {
          spans = _highlightQuery(spans, highlightQuery);
        }
        return SelectableText.rich(
          TextSpan(children: spans),
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
        );
      }

      final spans = <TextSpan>[];

      int mainEnd = text.length;
      if (beneficialIdx != -1 && beneficialIdx < mainEnd) mainEnd = beneficialIdx;
      if (footnotesIdx != -1 && footnotesIdx < mainEnd) mainEnd = footnotesIdx;

      if (mainEnd > 0) {
        String mainText = text.substring(0, mainEnd).trimRight();
        mainText = mainText.replaceAll(r'\n', '\n').trimRight();
        spans.addAll(_parseMainText(mainText,
            onVerseTapped: _onTafsirVerseTapped, language: _mokhtasarLanguage));
      }

      if (beneficialIdx != -1) {
        final end = (footnotesIdx != -1 && footnotesIdx > beneficialIdx)
            ? footnotesIdx
            : text.length;
        final markerText = text.substring(
            beneficialIdx, beneficialIdx + beneficialMarker.length);
        final afterMarker =
            text.substring(beneficialIdx + beneficialMarker.length, end);
        spans.add(TextSpan(text: '\n\n$markerText', style: orangeStyle));
        spans.addAll(_parseMainText(afterMarker,
            baseStyleOverride: greenStyle,
            onVerseTapped: _onTafsirVerseTapped,
            language: _mokhtasarLanguage));
      }

      if (footnotesIdx != -1) {
              final labelEnd = footnotesIdx + footnotesMarker.length;
              final label = text.substring(footnotesIdx, labelEnd);
              spans.add(
                TextSpan(
                  text: '\n\n$label',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );

              final footnotesText = text.substring(labelEnd);
              for (final match
                  in RegExp(r'(\[[^\]]*\])|([^\[]+)').allMatches(footnotesText)) {
                final m = match.group(0) ?? '';
                if (match.group(1) != null) {
                  if (RegExp(r'^\[\d+\]$').hasMatch(m)) {
                    spans.add(
                      TextSpan(
                        text: m,
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    );
                  } else {
                    spans.add(
                      TextSpan(
                        text: m,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                          height: 1.55,
                        ),
                      ),
                    );
                  }
                } else {
                  spans.addAll(
                    _parseMainText(
                      m,
                      onVerseTapped: _onTafsirVerseTapped,
                      language: _mokhtasarLanguage,
                    ),
                  );
                }
              }
            }

      var finalSpans = spans;
      if (highlightQuery != null && highlightQuery.isNotEmpty) {
        finalSpans = _highlightQuery(finalSpans, highlightQuery);
      }

      return SelectableText.rich(
        TextSpan(children: finalSpans),
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: isRtl ? TextAlign.right : TextAlign.left,
      );
    }
}

class _TafsirRange {
  final int surah;
  final int from;
  final int to;
  const _TafsirRange(this.surah, this.from, this.to);
}
