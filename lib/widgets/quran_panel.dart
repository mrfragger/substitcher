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
      // Allah
      'خوای', 'الله',
      // Lord/God (Sorani Kurdish)
      'پەروەردگاری', 'پەروەردگار',
      'خودای', 'خودا',
      // Compound with possessive
      'خوداوەند', 'خوداوەندی',
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
    'Bengali': ['আল্লাহর', 'আল্লাহ্', 'আল্লাহ', 'রব', 'প্রতিপালক'],
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
    'Chinese': ['安拉', '真主'],
    'French': [
      'qu\u2019Allah',
      'qu\'Allah',
      'd\u2019Allah',
      'd\'Allah',
      'Allah',
      'Seigneur'
    ],
    'Fulani': ['Alla', 'Joomi'],
    'Hindi': ['अल्लाह', 'रब्ब', 'परवरदिगार'],
    'Indonesian': ['Allahlah', 'Allah', 'Rabb', 'Tuhan'],
    'Italian': ['Allāh', 'Allah', 'Dio'],
    'Japanese': ['アッラー', '主よ', '主に'],
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
    'Malayalam': [
      'അല്ലാഹുവിൻ്റെ',
      'അല്ലാഹുവിന്റെ',
      'അല്ലാഹുവിനെ',
      'അല്ലാഹുവെ',
      'അല്ലാഹുവിന്',
      'അല്ലാഹു',
      'റബ്ബ്'
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
    'Uzbek': [
      'Аллоҳдирки',
      'Аллоҳгадир',
      'Аллоҳгагина',
      'Аллоҳдир',
      'Аллоҳнинг',
      'Аллоҳдан',
      'Аллоҳга',
      'Аллоҳни',
      'Аллоҳим',
      'Аллоҳа',
      'Аллоҳ',
      'Ибодат'
    ],
    'Vietnamese': ['Thượng Đế', 'Allah'],
    'Afar': ['Yalli', 'Alla', 'Allah'],
    'Akan': ['Onyame', 'Allah', 'Allaahu'],
    'Amharic': ['አላህ', 'አምላክ', 'ጌታ'],
    'German': ['Allah', 'Gott', 'Herr'],
    'Hausa': ['Allahu', 'Allah', 'Ubangiji'],
    'Korean': ['알라', '하나님', '주님'],
    'Malagasy': ['Tompo', 'Allah', 'Andriamanitra'],
    'Nepali': ['अल्लाह', 'पालनकर्ता'],
    'Oromo': [
      'Rabbiitiin',
      'Rabbiin',
      'Rabbiif',
      'Rabbitti',
      'Rabbi',
      'Allah',
      'Waaqayyo'
    ],
    'Portuguese': ['Allah', 'Senhor', 'Deus'],
    'Swahili': ['Allah', 'Mwenyezi Mungu', 'Bwana'],
    'Tajik': ['Аллоҳ', 'Худо', 'Парвардигор'],
  };
  static const Map<String, String> _scriptRanges = {
    'latin': r'a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ',
    'cyrillic': r'а-яёА-ЯЁҳқғўӯ',
    'arabic': r'\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF',
    'hebrew': r'\u0590-\u05FF',
    'nko': r'\u07C0-\u07FF',
    'bengali': r'\u0980-\u09FF',
    'devanagari': r'\u0900-\u097F', // Hindi
    'tamil': r'\u0B80-\u0BFF',
    'telugu': r'\u0C00-\u0C7F',
    'malayalam': r'\u0D00-\u0D7F',
    'sinhala': r'\u0D80-\u0DFF',
    'thai': r'\u0E00-\u0E7F',
    'khmer': r'\u1780-\u17FF',
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
    final cyanStyle = baseStyle.copyWith(color: Colors.cyanAccent);
    final purpleStyle = baseStyle.copyWith(color: const Color(0xFFCB93F5));

    final allahWords =
        (_allahByLanguage[widget.selectedLanguage] ?? _allahByLanguage['English']!)
            .toList()
          ..sort((a, b) {
            final c = b.length.compareTo(a.length);
            return c != 0 ? c : a.compareTo(b);
          });

    const noBoundaryScripts = {
      'cjk', 'thai', 'khmer', 'arabic', 'hangul', 'ethiopic', 'devanagari'
    };

    final patterns = <String>[];
    for (final w in allahWords) {
      final escaped = RegExp.escape(w);
      if (RegExp(r"^[a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ'\u2018\u2019]+$").hasMatch(w)) {
        final range = _scriptRanges['latin']!;
        patterns.add('(?<![$range])$escaped(?![$range])');
      } else {
        final script = _detectScript(w);
        if (noBoundaryScripts.contains(script)) {
          patterns.add(escaped);
        } else {
          final range = _scriptRanges[script] ?? _scriptRanges['cyrillic']!;
          patterns.add('(?<![$range])$escaped(?![$range])');
        }
      }
    }
    final allahPattern = patterns.join('|');
    final combined = RegExp('(?:$allahPattern)|(\\([^)]*\\))');

    final result = <TextSpan>[];
    int cursor = 0;
    for (final m in combined.allMatches(text)) {
      if (m.start > cursor) {
        result.add(TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
      }
      final matched = m.group(0)!;
      result.add(TextSpan(
        text: matched,
        style: m.group(1) != null ? cyanStyle : purpleStyle,
      ));
      cursor = m.end;
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
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(width: 10),
                  const Text('* no vtt',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                  const SizedBox(width: 4),
                  Tooltip(
                    message:
                        'csv needs to be downloadable on quranenc.com for an available vtt',
                    preferBelow: true,
                    textStyle:
                        const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.info_outline,
                        color: Colors.white38, size: 14),
                  ),
                  if (widget.isQuranLoaded) ...[
                    const SizedBox(width: 16),
                    const Tooltip(
                      message: 'next ayah',
                      child: Text('⇧Q',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 120,
                      height: 28,
                      child: TextField(
                        controller: _refInputController,
                        focusNode: _refInputFocusNode,
                        autofocus: true,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: '38:36-40',
                          hintStyle: const TextStyle(
                              color: Colors.white24, fontSize: 12),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                                color: Colors.deepPurple.withAlpha(160)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                                color: Colors.deepPurple.withAlpha(100)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                const BorderSide(color: Colors.deepPurple),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search,
                                color: Colors.deepPurple, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: widget.isQuranLoaded
                                ? () => _playRefFromInput(context)
                                : null,
                          ),
                        ),
                        onSubmitted: widget.isQuranLoaded
                            ? (_) => _playRefFromInput(context)
                            : null,
                      ),
                    ),
                  ],
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
                    if (widget.selectedLanguage == 'English')
                      const SizedBox(width: 4),
                      _quickFilterChip('=phrase', 'phrases'), ...[
                    ],
                  const Spacer(),
                  TextButton(
                    onPressed: () => _showSurahListPopup(context),
                    child: const Text('Surahs',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: _expandedIndices.isEmpty
                        ? 'Expand all'
                        : 'Collapse all',
                    child: IconButton(
                      onPressed: () => setState(() {
                        if (_expandedIndices.length >= widget.entries.length) {
                          _expandedIndices.clear();
                        } else {
                          _expandedIndices.addAll(
                              List.generate(widget.entries.length, (i) => i));
                        }
                      }),
                      icon: Icon(
                        _expandedIndices.isEmpty
                            ? Icons.unfold_more
                            : Icons.unfold_less,
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
      'devanagari'
    };

    final patterns = <String>[];
    for (final w in allahWords) {
      final escaped = RegExp.escape(w);
      if (RegExp(r"^[a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ'\u2018\u2019]+$").hasMatch(w)) {
        final range = _scriptRanges['latin']!;
        patterns.add('(?<![$range])$escaped(?![$range])');
      } else {
        final script = _detectScript(w);
        if (noBoundaryScripts.contains(script)) {
          patterns.add(escaped);
        } else {
          final range = _scriptRanges[script] ?? _scriptRanges['cyrillic']!;
          patterns.add('(?<![$range])$escaped(?![$range])');
        }
      }
    }
    final allahPattern = patterns.join('|');
    final verseRegex = RegExp(r'\b\d{1,3}:\d{1,3}(?:-\d{1,3})?\b');

    final quotePattern = RegExp(r'"(?:[^"\\]|\\.)*"'
        r'|\u201c(?:[^\u201d])*\u201d');

    List<TextSpan> parseWithAllah(String t, TextStyle base) {
      final inner = <TextSpan>[];
      final combined = RegExp(
          '(?:$allahPattern)|\\b\\d{1,3}:\\d{1,3}(?:-\\d{1,3})?\\b|\\([^)]*\\)|\\[[^\\]]*\\]');
      int c = 0;
      for (final m in combined.allMatches(t)) {
        if (m.start > c)
          inner.add(TextSpan(text: t.substring(c, m.start), style: base));
        final word = m.group(0)!;
        if (verseRegex.hasMatch(word)) {
          inner.add(TextSpan(
            text: word,
            style: verseStyle,
            recognizer: onVerseTapped != null
                ? (TapGestureRecognizer()..onTap = () => onVerseTapped(word))
                : null,
          ));
        } else if (word.startsWith('(')) {
          inner.add(TextSpan(text: word, style: cyanStyle));
        } else if (word.startsWith('[')) {
          inner.add(TextSpan(text: word, style: amber));
        } else {
          inner.add(TextSpan(text: word, style: purple));
        }
        c = m.end;
      }
      if (c < t.length) inner.add(TextSpan(text: t.substring(c), style: base));
      return inner;
    }

    final pattern = RegExp(
      r'("(?:[^"\\]|\\.)*"' // "..."
      r'|\u201c(?:[^\u201d])*\u201d)' // "..."
      r'|(\[[^\]]*\])' // [...]
      r'|(\([^)]*\))' // (...)
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
        final parenPattern = RegExp(r'\([^)]*\)');
        int innerCursor = 0;
        for (final p in parenPattern.allMatches(m)) {
          if (p.start > innerCursor) {
            spans.addAll(
                parseWithAllah(m.substring(innerCursor, p.start), amber));
          }
          spans.addAll(parseWithAllah(p.group(0)!, cyanStyle));
          innerCursor = p.end;
        }
        if (innerCursor < m.length) {
          spans.addAll(parseWithAllah(m.substring(innerCursor), amber));
        }
      } else if (match.group(3) != null) {
        int innerCursor = 0;
        for (final q in quotePattern.allMatches(m)) {
          if (q.start > innerCursor) {
            spans.addAll(
                parseWithAllah(m.substring(innerCursor, q.start), cyanStyle));
          }
          spans.addAll(parseWithAllah(q.group(0)!, quoteStyle));
          innerCursor = q.end;
        }
        if (innerCursor < m.length) {
          spans.addAll(parseWithAllah(m.substring(innerCursor), cyanStyle));
        }
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
        final footnotesText = '\n\n' + text.substring(footnotesIdx);
        for (final match
            in RegExp(r'(\[[^\]]*\])|([^\[]+)').allMatches(footnotesText)) {
          final m = match.group(0) ?? '';
          if (match.group(1) != null) {
            if (RegExp(r'^\[\d+\]$').hasMatch(m)) {
              spans.add(TextSpan(
                  text: m,
                  style: const TextStyle(
                      color: Colors.orangeAccent, fontSize: 14, height: 1.55)));
            } else {
              spans.add(TextSpan(
                  text: m,
                  style: const TextStyle(
                      color: Colors.amber, fontSize: 14, height: 1.55)));
            }
          } else {
            spans.addAll(_parseMainText(m,
                baseStyleOverride: const TextStyle(
                    color: Colors.greenAccent, fontSize: 14, height: 1.55),
                onVerseTapped: _onTafsirVerseTapped,
                language: _mokhtasarLanguage));
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
