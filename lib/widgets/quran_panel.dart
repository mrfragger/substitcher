import 'dart:math' as math;
import '../models/history_item.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../quran/quran_index.dart';
import '../quran/surah_names.dart';
import '../quran/quran_verse_search_index.dart';
import '../quran/juz_duration_calculator.dart';
import '../quran/quran_wbw_repository.dart';
import '../quran/quran_word_by_word.dart';
import '../quran/quran_word_audio_index.dart';
import '../quran/quran_word_audio_player.dart';
import '../tafsir_index/tafsir_binary_index.dart';
import '../tafsir/tafsir_mokhtasar_all.dart';
import '../tafsir/tafsir_english_hilali_khan.dart';
import '../tafsir/tafsir_english_rowwad.dart';
import '../tafsir/tafsir_english_noor.dart';
import '../tafsir/tafsir_english_yacob.dart';
import '../tafsir/tafsir_english_ibn_kathir.dart';
import '../tafsir/tafsir_arabic_quran.dart';
import '../tafsir/tafsir_arabic_saadi.dart';
import '../tafsir/tafsir_arabic_moyassar.dart';
import '../tafsir/tafsir_arabic_baghawi.dart';
import '../tafsir/tafsir_arabic_yaseer.dart';
import '../tafsir/tafsir_arabic_siraj.dart';
import '../tafsir/tafsir_arabic_nafahat.dart';
import '../tafsir/tafsir_arabic_katheer.dart';
import '../tafsir/translation_various_languages.dart';
import '../hadeeth/hadeeth_panel.dart';
import '../services/allah_highlighter.dart';


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
  final List<int>? juzDurations;
  final Function(String) onLanguageChanged;
  final Function(List<QuranVerseRef> refs, int filteredIndex)? onPlayAllRequested;
  final Function(QuranVerseRef range, int repeatCount)? onRepeatRangeRequested;
  final HistoryItem? lastQuranAudiobook;
  final Function(String)? onOpenAudiobook;

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
    this.onRepeatRangeRequested,
    this.juzDurations,
    this.lastQuranAudiobook,
    this.onOpenAudiobook,
  });

  @override
  State<QuranPanel> createState() => _QuranPanelState();
}

class _Posting {
  final int surah;
  final int ayah;
  final String source;
  final int termFreq;
  const _Posting(this.surah, this.ayah, this.source, this.termFreq);
}

class _TafsirIndex {
  final Map<String, List<_Posting>> invertedIndex = {};
  final Map<String, int> docLengths = {}; // key: "surah:ayah:source"
  final Map<String, String> docText = {};  // key: "surah:ayah:source"
  int totalDocs = 0;
  double avgDocLength = 0;
}

final RegExp _arabicDiacritics = RegExp(
  r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC'
  r'\u06DF-\u06E8\u06EA-\u06ED\u08D3-\u08E1\u08E3-\u08FF]',
);

// Matches Arabic diacritics (tashkeel/harakat) plus tatweel (kashida), so
// Quranic text — which is conventionally fully vocalized and sometimes
// justified with tatweel — can still be matched against plain,
// undiacritized dictionary entries like 'الله' or 'ربكم'.
final RegExp _arabicDiacriticsPattern = RegExp(
  r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED\u08D3-\u08E1\u08E3-\u08FF\u0640]',
);

/// Folds Arabic letter-shape variants that should be treated as equivalent
/// for matching purposes (alef forms, taa marbuta/haa, alef maksura/yaa).
/// Always maps exactly one character to one character, so callers that
/// rely on a 1:1 index mapping (like [_normalizeArabic]) stay valid.
String _foldArabicChar(String ch) {
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

/// Strips Arabic diacritics/tatweel from [text] and folds letter-shape
/// variants, returning the normalized string plus a map from each index
/// in the normalized string back to its original index in [text] (needed
/// so highlighted spans still cover the original text, not the stripped
/// copy).
(String, List<int>) _normalizeArabic(String text) {
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

List<String> _tokenize(String text) {
  final (normalized, _) = _normalizeArabic(text);
  return normalized
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((t) => t.isNotEmpty)
      .toList();
}

(String query, bool isPhrase) _extractHighlightQuery(String raw) {
  final trimmed = raw.trim();
  final phraseMatch = RegExp(
    r'["\u201C\u2018](.+?)["\u201D\u2019]',
  ).firstMatch(trimmed);
  if (phraseMatch != null) {
    return (phraseMatch.group(1)!.trim(), true);
  }
  return (trimmed, false);
}

class _QuranPanelState extends State<QuranPanel> {
  final Set<int> _expandedIndices = {};
  final TextEditingController _refInputController = TextEditingController();
  final FocusNode _refInputFocusNode = FocusNode();
  int _rangeRepeatCount = 1;
  final TextEditingController _rangeRepeatCountController =
      TextEditingController(text: '1');
  final FocusNode _rangeRepeatCountFocusNode = FocusNode();

  Set<int> _completedJuz = {};
  Set<int> _completedHizb = {};
  Set<int> _completedRub = {};

  Set<int> _completedJuz2 = {};
  Set<int> _completedHizb2 = {};
  Set<int> _completedRub2 = {};

  final ItemScrollController _quranVerseSearchScrollController = ItemScrollController();

  static bool _hadeethExpanded = false;
  static bool _tafsirExpanded = false;
  static bool _tafsirMokhtasar = true;
  static bool _tafsirHilali = false;
  static bool _tafsirRowwadEnglish = false;
  static bool _tafsirNoorEnglish = false;
  static bool _tafsirYacobEnglish = false;
  static bool _tafsirKathir = false;
  static bool _tafsirQuran = false;
  static bool _tafsirMoyassar = false;
  static bool _tafsirSaadi = false;
  static bool _tafsirBaghawi = false;
  static bool _tafsirYaseer = false;
  static bool _tafsirSiraj = false;
  static bool _tafsirNafahat = false;
  static bool _tafsirKatheer = false;
  static bool _tafsirVarious = false;
  static bool _wordByWordMode = false;
  QuranWordAudioIndex? _wordAudioIndex;
  bool _wordAudioIndexLoading = false;
  static double _tafsirFontSize = 14.0;
  static const double _headerFontSize = 14.0;
  static String _variousLanguage = variousTranslationLanguages.first;
  static String _mokhtasarLanguage = 'English';
  static QuranVerseRef? _lastTafsirRef;
  static int? _lastTafsirIndex;
  static List<Map<String, dynamic>> _tafsirResults = [];
  static List<String> _tafsirRefHistory = [];
  static List<String> _verseRefHistory = [];
  static List<String> _tafsirSearchHistory = [];
  static int? _lastTafsirSearchSurah;
  static int? _lastTafsirSearchAyah;
  static String? _lastTafsirSearchSource;
  static String? _lastTafsirTapListType; // 'browse' or 'search'
  static const Set<String> _quizSupportedLanguages = {'English', 'Spanish'};

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
    'rub ',
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

  TafsirBinaryIndex? _katheerIndex;
  TafsirBinaryIndex? _kathirIndex;
  TafsirBinaryIndex? _baghawiIndex;
  bool _katheerIndexLoading = false;
  bool _kathirIndexLoading = false;
  bool _baghawiIndexLoading = false;

  static bool _tafsirSearchMode = false;
  static List<Map<String, dynamic>> _tafsirSearchResults = [];
  static bool _tafsirSearchTruncated = false;

  final TextEditingController _tafsirRefController = TextEditingController();
  final FocusNode _tafsirRefFocusNode = FocusNode();
  final ScrollController _tafsirScrollController = ScrollController();
  final ScrollController _tafsirSearchScrollController = ScrollController();
  final ItemScrollController _tafsirSearchItemScrollController = ItemScrollController();
  final ItemScrollController _tafsirBrowseItemScrollController = ItemScrollController();

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
    _loadCompletionState();
    _loadTafsirFontSize();

    if (_wordByWordMode) {
      _loadWordAudioIndexIfNeeded();
    }

    _rangeRepeatCountFocusNode.addListener(() {
      if (_rangeRepeatCountFocusNode.hasFocus) {
        if (_rangeRepeatCountController.text == '1') {
          _rangeRepeatCountController.clear();
        }
      } else {
        if (_rangeRepeatCountController.text.trim().isEmpty) {
          _rangeRepeatCountController.text = '1';
          setState(() => _rangeRepeatCount = 1);
        }
      }
    });

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
    _scrollToLastTafsirSearchTap();
    _scrollToActiveTafsirBrowseResult();
  }

  @override
  void dispose() {
    _refInputController.dispose();
    _refInputFocusNode.dispose();
    _tafsirRefController.dispose();
    _tafsirRefFocusNode.dispose();
    _tafsirScrollController.dispose();
    _tafsirSearchScrollController.dispose();
    _rangeRepeatCountController.dispose();
    _rangeRepeatCountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTafsirFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble('tafsir_font_size');
    if (saved != null && mounted) {
      setState(() => _tafsirFontSize = saved);
    }
  }

  Future<void> _saveTafsirFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tafsir_font_size', _tafsirFontSize);
  }

  bool _isDayPlanHeader(String topic) =>
      topic.startsWith('14Day ') ||
      topic.startsWith('10Day ') ||
      topic == '14Day' ||
      topic == '10Day' ;

  Widget _buildCompletionCheckbox(String topic) {
    final parsed = _parseJuzHizbRubTopic(topic);
    if (parsed == null) return const SizedBox.shrink();
    final (category, number) = parsed;
    final isDone1 = _completionSetFor(category).contains(number);
    final isDone2 = _completionSetFor(category, track: 1).contains(number);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _toggleCompletion(category, number),
          child: Icon(
            isDone1 ? Icons.check_box : Icons.check_box_outline_blank,
            color: isDone1 ? Colors.greenAccent : Colors.white38,
            size: 20,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => _toggleCompletion(category, number, track: 1),
          child: Icon(
            isDone2 ? Icons.check_box : Icons.check_box_outline_blank,
            color: isDone2 ? Colors.lightBlueAccent : Colors.white38,
            size: 20,
          ),
        ),
      ],
    );
  }

  Future<void> _openAllahAudiobooksLink() async {
    final uri = Uri.parse('https://t.me/AllahAudiobooks');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  List<InlineSpan> _completionHeaderSpans(String topic) {
    final category = _categoryForHeaderTopic(topic);
    if (category == null) return const [];
    final total = switch (category) {
      'Juz' => 30,
      'Hizb' => 60,
      _ => 240,
    };
    final count1 = _completionSetFor(category).length;
    final count2 = _completionSetFor(category, track: 1).length;

    final spans = <InlineSpan>[
      TextSpan(
        text: ' ✓ $count1/$total',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      TextSpan(
        text: '  ✓ $count2/$total',
        style: const TextStyle(
          color: Colors.lightBlueAccent,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];

    if (category == 'Juz') {
      final totalDuration = formatTotalJuzDuration(widget.juzDurations);
      if (totalDuration.isNotEmpty) {
        spans.add(TextSpan(
          text: '  $totalDuration',
          style: TextStyle(
            color: Colors.amber[200],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ));
      }

      final divisor = _averageDivisorForTopic(topic);
      if (divisor != null) {
        final avgLabel = formatAverageJuzDuration(widget.juzDurations, divisor);
        if (avgLabel.isNotEmpty) {
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Average per day',
                child: Text(
                  '($avgLabel)',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ));
        }
      }
    }

    return spans;
  }

  String? _categoryForHeaderTopic(String topic) => switch (topic) {
        'Juz' => 'Juz',
        'Hizb (1/2)' => 'Hizb',
        'Rub (1/8)' => 'Rub',
        '14Day' => 'Juz',
        '10Day' => 'Juz',
        _ => null,
      };

  int? _averageDivisorForTopic(String topic) {
    switch (topic) {
      case 'Juz':
        return 30;
      case '14Day':
        return 14;
      case '10Day':
        return 10;
      default:
        return null;
    }
  }

  Set<int> _completionSetFor(String category, {int track = 0}) {
    if (track == 1) {
      return switch (category) {
        'Juz' => _completedJuz2,
        'Hizb' => _completedHizb2,
        _ => _completedRub2,
      };
    }
    return switch (category) {
      'Juz' => _completedJuz,
      'Hizb' => _completedHizb,
      _ => _completedRub,
    };
  }

  Future<void> _loadCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final juz = (prefs.getStringList('completed_juz') ?? []).map(int.parse).toSet();
    final hizb = (prefs.getStringList('completed_hizb') ?? []).map(int.parse).toSet();
    final rub = (prefs.getStringList('completed_rub') ?? []).map(int.parse).toSet();
    final juz2 = (prefs.getStringList('completed_juz2') ?? []).map(int.parse).toSet();
    final hizb2 = (prefs.getStringList('completed_hizb2') ?? []).map(int.parse).toSet();
    final rub2 = (prefs.getStringList('completed_rub2') ?? []).map(int.parse).toSet();
    if (mounted) {
      setState(() {
        _completedJuz = juz;
        _completedHizb = hizb;
        _completedRub = rub;
        _completedJuz2 = juz2;
        _completedHizb2 = hizb2;
        _completedRub2 = rub2;
      });
    }
  }

  Future<void> _saveCompletionState(String category, {int track = 0}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = track == 1
        ? 'completed_${category.toLowerCase()}2'
        : 'completed_${category.toLowerCase()}';
    await prefs.setStringList(
        key, _completionSetFor(category, track: track).map((e) => e.toString()).toList());
  }

  void _toggleCompletion(String category, int number, {int track = 0}) {
    setState(() {
      final set = _completionSetFor(category, track: track);
      if (set.contains(number)) {
        set.remove(number);
      } else {
        set.add(number);
      }
    });
    _saveCompletionState(category, track: track);
  }

  void _resetCompletion(String category, {int track = 0}) {
    setState(() {
      _completionSetFor(category, track: track).clear();
    });
    _saveCompletionState(category, track: track);
  }

  (String, int)? _parseJuzHizbRubTopic(String topic) {
    final m = RegExp(r'^(Juz|Hizb|Rub) (\d+)$').firstMatch(topic);
    if (m == null) return null;
    return (m.group(1)!, int.parse(m.group(2)!));
  }

  Color _quranLanguageColor(String lang) {
    final isNoVtt = lang.endsWith(' *');
    final baseName = isNoVtt ? lang.substring(0, lang.length - 2) : lang;
    final hasMokhtasar = mokhtasarLanguages.contains(baseName);

    if (hasMokhtasar) return Colors.greenAccent;
    if (isNoVtt) return Colors.lightBlueAccent;
    return Colors.amber;
  }

  void _cycleTafsirFontSize() {
    setState(() {
      if (_tafsirFontSize == 14.0) {
        _tafsirFontSize = 16.0;
      } else if (_tafsirFontSize == 16.0) {
        _tafsirFontSize = 18.0;
      } else if (_tafsirFontSize == 18.0) {
        _tafsirFontSize = 20.0;
      } else if (_tafsirFontSize == 20.0) {
        _tafsirFontSize = 22.0;
      } else if (_tafsirFontSize == 22.0) {
        _tafsirFontSize = 24.0;
      } else {
        _tafsirFontSize = 14.0;
      }
    });
    _saveTafsirFontSize();
  }

  (int, int)? _parseDayPlanJuzRange(String topic) {
    final m = RegExp(r'\(Juz (\d+)(?:-(\d+))?\)').firstMatch(topic);
    if (m == null) return null;
    final start = int.parse(m.group(1)!);
    final end = m.group(2) != null ? int.parse(m.group(2)!) : start;
    return (start, end);
  }

  List<InlineSpan> _dayPlanDurationSpans(String topic, bool isSubtopic) {
    final range = _parseDayPlanJuzRange(topic);
    if (range == null) return const [];
    final label = formatJuzRangeDuration(widget.juzDurations, range.$1, range.$2);
    if (label.isEmpty) return const [];
    return [
      TextSpan(
        text: '  $label',
        style: TextStyle(
          color: Colors.amber[200],
          fontSize: isSubtopic ? 13 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ];
  }

  List<QuranIndexEntry> get _filtered {
      if (_searchQuery == 'quizzes') {
        return widget.entries.where((e) => e.topic.contains('{{{')).toList();
      }
      if (_searchQuery.isEmpty && _excludeQuery.isEmpty) return widget.entries;
      final result = <QuranIndexEntry>[];
      String? currentMainTopic;
      bool currentMainMatches = false;
      for (final entry in widget.entries) {
        if (!entry.isSubtopic) {
          currentMainTopic = entry.topic;
          final topicLower = entry.topic.toLowerCase();
          currentMainMatches =
              (_searchQuery.isEmpty || _matchesQuery(topicLower, _searchQuery)) &&
                  (_excludeQuery.isEmpty || !_matchesQuery(topicLower, _excludeQuery));
          if (currentMainMatches) result.add(entry);
        } else {
          final topicLower = entry.topic.toLowerCase();
          final subtopicMatches =
              (_searchQuery.isEmpty || _matchesQuery(topicLower, _searchQuery)) &&
                  (_excludeQuery.isEmpty || !_matchesQuery(topicLower, _excludeQuery));
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

    static const Set<String> _wholeWordQueries = {
      'juz', 'hizb', 'rub',
    };

    bool _matchesQuery(String topicLower, String query) {
      if (_wholeWordQueries.contains(query)) {
        return RegExp(r'\b' + RegExp.escape(query) + r'\b').hasMatch(topicLower);
      }
      return topicLower.contains(query);
    }

  final Map<String, bool> _revealedQuizWords = {};

  String _maskWord(String word) {
    if (word.length <= 2) return word;
    return word[0] + ('_' * (word.length - 2)) + word[word.length - 1];
  }

  String _maskPhrase(String phrase) => phrase.split(' ').map(_maskWord).join(' ');

  List<TextSpan> _quizStyledSpans(String topic, TextStyle baseStyle, int globalIndex) {
    final pattern = RegExp(r'\{\{\{(.*?)\}\}\}');
    final maskedStyle = baseStyle.copyWith(
        color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1);
    final revealedStyle =
        baseStyle.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold);

    final spans = <TextSpan>[];
    int cursor = 0;
    int wordIdx = 0;
    for (final m in pattern.allMatches(topic)) {
      if (m.start > cursor) {
        spans.addAll(AllahHighlighter.spans(
            topic.substring(cursor, m.start), baseStyle,
            language: widget.selectedLanguage));
      }
      final phrase = m.group(1)!;
      final key = '$globalIndex:$wordIdx';
      wordIdx++;
      final isRevealed = _revealedQuizWords[key] ?? false;
      spans.add(TextSpan(
        text: isRevealed ? phrase : _maskPhrase(phrase),
        style: isRevealed ? revealedStyle : maskedStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () => setState(() => _revealedQuizWords[key] = !isRevealed),
      ));
      cursor = m.end;
    }
    if (cursor < topic.length) {
      spans.addAll(AllahHighlighter.spans(
          topic.substring(cursor), baseStyle,
          language: widget.selectedLanguage));
    }
    return spans;
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

  void _scrollToLastTafsirSearchTap() {
    if (_lastTafsirTapListType != 'search') return;
    if (_lastTafsirSearchSurah == null || _tafsirSearchResults.isEmpty) return;
    final index = _tafsirSearchResults.indexWhere((r) =>
        r['surah'] == _lastTafsirSearchSurah &&
        r['ayah'] == _lastTafsirSearchAyah &&
        r['source'] == _lastTafsirSearchSource);
    if (index == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptScrollToTafsirSearchIndex(index, attemptsLeft: 10);
    });
  }

  void _attemptScrollToTafsirSearchIndex(int index, {required int attemptsLeft}) {
      if (!mounted || attemptsLeft <= 0) return;
      if (_tafsirSearchItemScrollController.isAttached) {
        _tafsirSearchItemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          _attemptScrollToTafsirSearchIndex(index, attemptsLeft: attemptsLeft - 1);
        });
      }
    }

    void _scrollToActiveTafsirBrowseResult() {
      if (_lastTafsirTapListType != 'browse' ||
          _lastTafsirSearchSurah == null ||
          _tafsirResults.isEmpty) {
        return;
      }
      final index = _tafsirResults.indexWhere((r) =>
          r['surah'] == _lastTafsirSearchSurah &&
          r['ayah'] == _lastTafsirSearchAyah &&
          r['source'] == _lastTafsirSearchSource);
      if (index == -1) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _attemptScrollToTafsirBrowseIndex(index, attemptsLeft: 10);
      });
    }

    void _attemptScrollToTafsirBrowseIndex(int index, {required int attemptsLeft}) {
      if (!mounted || attemptsLeft <= 0) return;
      if (_tafsirBrowseItemScrollController.isAttached) {
        _tafsirBrowseItemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 300),
          alignment: 0.3,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 100), () {
          _attemptScrollToTafsirBrowseIndex(index, attemptsLeft: attemptsLeft - 1);
        });
      }
    }

  Widget _buildRefHistoryButton() {
    final hasHistory = _tafsirRefHistory.isNotEmpty;
    return Builder(
      builder: (btnContext) {
        return Tooltip(
          message: hasHistory ? 'Recent references' : 'No recent references yet',
          child: InkWell(
            onTap: hasHistory ? () => _showRefHistoryMenu(btnContext) : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 24,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.teal.withAlpha(hasHistory ? 160 : 40),
                ),
              ),
              child: Icon(
                Icons.arrow_left,
                size: 20,
                color: hasHistory ? Colors.teal : Colors.white24,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRefHistoryMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2A2A2A),
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 170),
      items: [
        for (final ref in _tafsirRefHistory)
          PopupMenuItem<String>(
            value: ref,
            height: 32,
            child: Text(ref, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
      ],
    ).then((selected) {
      if (selected != null) {
        _tafsirRefController.text = selected;
        _tafsirRefController.selection =
            TextSelection.fromPosition(TextPosition(offset: selected.length));
        _tafsirRefFocusNode.requestFocus();
      }
    });
  }

  Widget _buildSearchHistoryButton() {
    final hasHistory = _tafsirSearchHistory.isNotEmpty;
    return Builder(
      builder: (btnContext) {
        return Tooltip(
          message: hasHistory ? 'Recent searches' : 'No recent searches yet',
          child: InkWell(
            onTap: hasHistory ? () => _showSearchHistoryMenu(btnContext) : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 24,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.teal.withAlpha(hasHistory ? 160 : 40),
                ),
              ),
              child: Icon(
                Icons.arrow_left,
                size: 20,
                color: hasHistory ? Colors.teal : Colors.white24,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSearchHistoryMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2A2A2A),
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 170),
      items: [
        for (final term in _tafsirSearchHistory)
          PopupMenuItem<String>(
            value: term,
            height: 32,
            child: Text(term, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
      ],
    ).then((selected) {
      if (selected != null) {
        _tafsirSearchController.text = selected;
        _tafsirSearchController.selection =
            TextSelection.fromPosition(TextPosition(offset: selected.length));
        _tafsirSearchFocusNode.requestFocus();
      }
    });
  }

  Widget _buildPlayAllChips(List<QuranVerseRef> refs, int index) {
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

    final active = widget.activeRef;
    final activeIdx = active == null
        ? -1
        : refs.indexWhere((r) => _isSameRef(r, active));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
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
        ),
        if (activeIdx != -1) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => widget.onPlayAllRequested
                ?.call(playableRefs.sublist(activeIdx), index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.deepPurple.withAlpha(160)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.play_circle_outline, size: 14, color: Colors.purpleAccent),
                  SizedBox(width: 4),
                  Text(
                    'Resume',
                    style: TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Finds Allah/Rabb matches in [text] ignoring Arabic diacritics and
  /// letter-shape variants. Returns (start, end) ranges in ORIGINAL [text]
  /// coordinates (end exclusive), sorted by start position.
  // List<(int, int)> _findDiacriticInsensitiveAllahRanges(
  //     String text, String arabicAllahPattern) {
  //   if (arabicAllahPattern.isEmpty) return [];
  //   final (stripped, indexMap) = _normalizeArabic(text);
  //   final pattern = RegExp(arabicAllahPattern);
  //   final ranges = <(int, int)>[];
  //   for (final m in pattern.allMatches(stripped)) {
  //     if (m.start >= m.end) continue;
  //     final origStart = indexMap[m.start];
  //     final origEnd = indexMap[m.end - 1] + 1;
  //     ranges.add((origStart, origEnd));
  //   }
  //   return ranges;
  // }

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
            SizedBox(
              height: 520,
              child: HadeethPanel(
                initialLanguage: 'English',
                searchFocusNode: widget.hadeethSearchFocusNode,
                excludeFocusNode: widget.hadeethExcludeFocusNode,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWordByWordText(int surah, int ayah, double fontSize, {String? highlightQuery}) {
      if (ayah == 0) {
        return const SizedBox.shrink();
      }

      final trimmedQuery = highlightQuery?.trim() ?? '';
      final normalizedQuery =
          trimmedQuery.isNotEmpty ? _normalizeArabic(trimmedQuery).$1 : '';

      return FutureBuilder<List<QuranWordInfo>>(
        future: QuranWbwRepository.instance.getWords(surah, ayah),
        builder: (context, snapshot) {
          final words = snapshot.data;
          if (words == null) {
            return const SizedBox(
              height: 24,
              child: Center(
                child: SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.cyanAccent),
                ),
              ),
            );
          }
          if (words.isEmpty) {
            return const Text('No word-by-word data for this ayah',
                style: TextStyle(color: Colors.white38, fontSize: 12));
          }
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(words.length, (i) {
                final word = words[i];
                final wordIndex = i + 1;
                final isMatch = normalizedQuery.isNotEmpty &&
                    _normalizeArabic(word.arabic).$1 == normalizedQuery;
                return _WordByWordChip(
                  arabic: word.arabic,
                  english: word.english,
                  fontSize: fontSize,
                  highlighted: isMatch,
                  onTap: () {
                    final audioId = _wordAudioIndex?.getAudioId(surah, ayah, wordIndex);
                    if (audioId != null) {
                      QuranWordAudioPlayer.instance.playWord(audioId);
                    }
                  },
                  onSearchIconTap: () => _searchForWord(word.arabic),
                );
              }),
            ),
          );
        },
      );
    }

    void searchWordInTafsir(String arabicWord) {
      setState(() {
        _tafsirSearchMode = true;
        if (!_wordByWordMode) {
          _wordByWordMode = true;
          _tafsirQuran = true;
        }
      });
      if (_wordAudioIndex == null && !_wordAudioIndexLoading) {
        _loadWordAudioIndexIfNeeded();
      }
      _tafsirSearchController.text = arabicWord;
      _tafsirSearchFocusNode.requestFocus();
      _searchTafsirText(arabicWord);
    }

  void _searchForWord(String arabicWord) {
    setState(() {
      _tafsirSearchMode = true;
    });
    _tafsirSearchController.text = arabicWord;
    _tafsirSearchFocusNode.requestFocus();
    _searchTafsirText(arabicWord);
  }

  void _submitRangeRepeat(BuildContext context) {
      final raw = _refInputController.text.trim();
      if (raw.isEmpty) return;

      final cleaned = raw.replaceAll(RegExp(r'[(){}\[\]]'), '');
      final normalized = cleaned
          .replaceAll(RegExp(r'\s*:\s*'), ':')
          .replaceAll(RegExp(r'\s*-\s*'), '-');

      QuranVerseRef range;

      final surahOnly = RegExp(r'^(\d+)$').firstMatch(normalized);
      if (surahOnly != null) {
        final s = int.parse(surahOnly.group(1)!);
        if (s < 1 || s > 114) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid surah number'), duration: Duration(seconds: 2)),
          );
          return;
        }
        range = QuranVerseRef(surah: s, fromAyah: 1, toAyah: quranVerseCounts[s], isFullSurah: false);
      } else {
        final m = RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(normalized);
        if (m == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not parse: "$raw"'), duration: const Duration(seconds: 2)),
          );
          return;
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
            const SnackBar(content: Text('Invalid surah number'), duration: Duration(seconds: 2)),
          );
          return;
        }
        final maxAyah = quranVerseCounts[s];
        if (from < 1 || from > maxAyah || to < from || to > maxAyah) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Surah $s has $maxAyah verses'), duration: const Duration(seconds: 2)),
          );
          return;
        }
        range = QuranVerseRef(surah: s, fromAyah: from, toAyah: to, isFullSurah: false);
      }

      widget.onRepeatRangeRequested?.call(range, _rangeRepeatCount);
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

        QuranVerseRef ref;

        final surahOnly = RegExp(r'^(\d+)$').firstMatch(normalized);
        if (surahOnly != null) {
          final surah = int.parse(surahOnly.group(1)!);
          if (surah < 1 || surah > 114) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Invalid surah number'),
                  duration: Duration(seconds: 2)),
            );
            return;
          }
          ref = QuranVerseRef(
              surah: surah, fromAyah: 1, toAyah: quranVerseCounts[surah], isFullSurah: false);
        } else {
          final match =
              RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(normalized);
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

          ref = QuranVerseRef(
              surah: surah, fromAyah: fromAyah, toAyah: toAyah, isFullSurah: false);
        }

        _recordVerseHistory(ref);
        _refInputController.clear();
        widget.onVerseSelected(ref, 0);
        _refInputFocusNode.requestFocus();
      }

    String _formatVerseRefLabel(QuranVerseRef ref) {
      if (ref.isFullSurah) return '${ref.surah}';
      if (ref.toAyah != null && ref.toAyah != ref.fromAyah) {
        return '${ref.surah}:${ref.fromAyah}-${ref.toAyah}';
      }
      return '${ref.surah}:${ref.fromAyah}';
    }

    void _recordVerseHistory(QuranVerseRef ref) {
      final label = _formatVerseRefLabel(ref);
      setState(() {
        _verseRefHistory.remove(label);
        _verseRefHistory.insert(0, label);
        if (_verseRefHistory.length > 20) {
          _verseRefHistory.removeRange(20, _verseRefHistory.length);
        }
      });
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

  void loadTafsirRef(String ref) {
    setState(() {
      _tafsirSearchMode = false;
    });
    _tafsirRefController.text = ref;
    _tafsirRefFocusNode.requestFocus();
  }

  void _lookupTafsir(BuildContext context) {
    final range = _parseTafsirRef(context, _tafsirRefController.text);
    if (range == null) return;

    final results = <Map<String, dynamic>>[];

    String _formatRefLabel(_TafsirRange range) {
      if (range.from == 0) return '${range.surah}';
      if (range.to > range.from) return '${range.surah}:${range.from}-${range.to}';
      return '${range.surah}:${range.from}';
    }

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
      if (_tafsirHilali) {
        final text = getTafsirHilali(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Hilali',
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
      if (_tafsirKathir) {
        final text = getTafsirKathirEnglish(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Kathir',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirVarious) {
        final text = getVariousTranslation(_variousLanguage, range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Various ($_variousLanguage)',
            'surah': range.surah,
            'ayah': ayah,
            'text': text
          });
        }
      }
      if (_tafsirQuran) {
        final text = getTafsirQuran(range.surah, ayah);
        if (text != null && text.isNotEmpty) {
          results.add({
            'source': 'Quran',
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

    final label = _formatRefLabel(range);
    setState(() {
      _tafsirResults = results;
      _tafsirRefHistory.remove(label);
      _tafsirRefHistory.insert(0, label);
      if (_tafsirRefHistory.length > 20) {
        _tafsirRefHistory.removeRange(20, _tafsirRefHistory.length);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tafsirScrollController.hasClients) {
        _tafsirScrollController.jumpTo(0);
      }
    });
    _tafsirRefFocusNode.requestFocus();
  }

  _TafsirIndex _buildIndexForSource(
      String sourceName, String? Function(int surah, int ayah) getText) {
    final index = _TafsirIndex();
    int totalLength = 0;

    for (int surah = 1; surah <= 114; surah++) {
      final maxAyah = quranVerseCounts[surah]!;
      final startAyah = sourceName == 'Mokhtasar' ? 0 : 1;
      for (int ayah = startAyah; ayah <= maxAyah; ayah++) {
        final text = getText(surah, ayah);
        if (text == null || text.isEmpty) continue;
        final tokens = _tokenize(text);
        if (tokens.isEmpty) continue;

        final docId = '$surah:$ayah:$sourceName';
        final termCounts = <String, int>{};
        for (final t in tokens) {
          termCounts[t] = (termCounts[t] ?? 0) + 1;
        }
        for (final entry in termCounts.entries) {
          index.invertedIndex
              .putIfAbsent(entry.key, () => [])
              .add(_Posting(surah, ayah, sourceName, entry.value));
        }
        index.docLengths[docId] = tokens.length;
        index.docText[docId] = text;
        totalLength += tokens.length;
        index.totalDocs++;
      }
    }
    index.avgDocLength = index.totalDocs == 0 ? 0 : totalLength / index.totalDocs;
    return index;
  }

  static const double _k1 = 1.5;
  static const double _b = 0.75;

  double _bm25Score(_TafsirIndex index, String docId, List<String> terms) {
    final docLen = index.docLengths[docId] ?? 0;
    if (docLen == 0) return 0;
    double score = 0;
    for (final term in terms) {
      final postings = index.invertedIndex[term];
      if (postings == null) continue;
      final df = postings.length; // docs containing this term
      final idf = math.log(1 + (index.totalDocs - df + 0.5) / (df + 0.5));
      final posting = postings.firstWhere(
        (p) => '${p.surah}:${p.ayah}:${p.source}' == docId,
        orElse: () => const _Posting(0, 0, '', 0),
      );
      final tf = posting.termFreq;
      if (tf == 0) continue;
      final numerator = tf * (_k1 + 1);
      final denominator = tf + _k1 * (1 - _b + _b * (docLen / index.avgDocLength));
      score += idf * (numerator / denominator);
    }
    return score;
  }

  double _bm25ScoreBinary(TafsirBinaryIndex index, int docId, List<String> terms) {
    final docLen = index.docLengths[docId] ?? 0;
    if (docLen == 0) return 0;
    double score = 0;
    for (final term in terms) {
      final postings = index.invertedIndex[term];
      if (postings == null) continue;
      final df = postings.length;
      final idf = math.log(1 + (index.totalDocs - df + 0.5) / (df + 0.5));
      final posting = postings.firstWhere(
          (p) => p.docId == docId, orElse: () => const BinaryPosting(-1, 0));
      final tf = posting.termFreq;
      if (tf == 0) continue;
      final numerator = tf * (_k1 + 1);
      final denominator =
          tf + _k1 * (1 - _b + _b * (docLen / index.avgDocLength));
      score += idf * (numerator / denominator);
    }
    return score;
  }

  Future<void> _loadWordAudioIndexIfNeeded() async {
    if (_wordAudioIndex != null || _wordAudioIndexLoading) return;
    setState(() => _wordAudioIndexLoading = true);
    final idx = await QuranWordAudioIndex.load('assets/quran_index/word_audio.bin');
    if (!mounted) return;
    setState(() {
      _wordAudioIndex = idx;
      _wordAudioIndexLoading = false;
    });
  }

  Future<void> _loadHeavyIndex(String source) async {
    Future<void> load(
        TafsirBinaryIndex? Function() getCurrent,
        void Function(TafsirBinaryIndex?) setIndex,
        void Function(bool) setLoading,
        String assetPath) async {
      if (getCurrent() != null) return;
      setState(() => setLoading(true));
      final idx = await TafsirBinaryIndex.load(assetPath);
      if (!mounted) return;
      setState(() {
        setIndex(idx);
        setLoading(false);
      });
    }

    switch (source) {
      case 'Katheer':
        if (_katheerIndex != null || _katheerIndexLoading) return;
        await load(() => _katheerIndex, (v) => _katheerIndex = v,
            (v) => _katheerIndexLoading = v, 'assets/tafsir_index/katheer.bin');
        break;
      case 'Kathir':
        if (_kathirIndex != null || _kathirIndexLoading) return;
        await load(() => _kathirIndex, (v) => _kathirIndex = v,
            (v) => _kathirIndexLoading = v, 'assets/tafsir_index/kathir.bin');
        break;
      case 'Baghawi':
        if (_baghawiIndex != null || _baghawiIndexLoading) return;
        await load(() => _baghawiIndex, (v) => _baghawiIndex = v,
            (v) => _baghawiIndexLoading = v, 'assets/tafsir_index/baghawi.bin');
        break;
    }
  }

  String? _extractQuotedPhrase(String text) {
    if (text.length < 2) return null;
    const pairs = [
      ['"', '"'],
      ['\u201C', '\u201D'], // “ ”
      ["'", "'"],
    ];
    for (final pair in pairs) {
      if (text.startsWith(pair[0]) && text.endsWith(pair[1])) {
        final inner = text.substring(1, text.length - 1).trim();
        return inner.isEmpty ? null : inner;
      }
    }
    return null;
  }

  String _normalizeForPhraseMatch(String text) =>
      text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

      void _addHeavySourceMatches(
          TafsirBinaryIndex? index,
          String sourceName,
          String? Function(int surah, int ayah) getText,
          List<String> terms,
          List<Map<String, dynamic>> scored,
          {String? phrase}) {
        if (index == null) return;

        Set<int>? candidateDocIds;
        for (final term in terms) {
          final postings = index.invertedIndex[term];
          final docIds = postings?.map((p) => p.docId).toSet() ?? <int>{};
          candidateDocIds =
              candidateDocIds == null ? docIds : candidateDocIds.intersection(docIds);
          if (candidateDocIds.isEmpty) return;
        }
        if (candidateDocIds == null) return;

        final normalizedPhrase = phrase != null ? _normalizeForPhraseMatch(phrase) : null;

        for (final docId in candidateDocIds) {
          final surah = docId ~/ 1000;
          final ayah = docId % 1000;
          final text = getText(surah, ayah);
          if (text == null || text.isEmpty) continue;
          final tokenSet = _tokenize(text).toSet();
          if (!terms.every((t) => tokenSet.contains(t))) continue;
          if (normalizedPhrase != null &&
              !_normalizeForPhraseMatch(text).contains(normalizedPhrase)) {
            continue;
          }
          scored.add({
            'source': sourceName,
            'surah': surah,
            'ayah': ayah,
            'text': text,
            'score': _bm25ScoreBinary(index, docId, terms),
          });
        }
      }

  Widget _buildTafsirFontSizeButton() {
    final fontSizeLabel = _tafsirFontSize.toInt().toString();
    return InkWell(
      onTap: _cycleTafsirFontSize,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.teal.withAlpha(160),
          ),
        ),
        child: Text(
          fontSizeLabel,
          style: const TextStyle(
            color: Colors.teal,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _searchTafsirText(String query) {
    final trimmedQuery = query.trim();
    final phrase = _extractQuotedPhrase(trimmedQuery);
    final terms = _tokenize(phrase ?? query);
    if (terms.isEmpty) {
      setState(() => _tafsirSearchResults = []);
      return;
    }

    final scored = <Map<String, dynamic>>[];

    if (_tafsirKatheer) {
      _addHeavySourceMatches(
          _katheerIndex, 'Katheer', getTafsirKatheer, terms, scored, phrase: phrase);
    }
    if (_tafsirKathir) {
      _addHeavySourceMatches(
          _kathirIndex, 'Kathir', getTafsirKathirEnglish, terms, scored, phrase: phrase);
    }
    if (_tafsirBaghawi) {
      _addHeavySourceMatches(
          _baghawiIndex, 'Baghawi', getTafsirBaghawi, terms, scored, phrase: phrase);
    }

    final lightSources = <String, String? Function(int, int)>{};
    if (_tafsirMokhtasar) {
      lightSources['Mokhtasar'] =
          (s, a) => getTafsirMokhtasarForLanguage(_mokhtasarLanguage, s, a);
    }
    if (_tafsirHilali) lightSources['Hilali'] = getTafsirHilali;
    if (_tafsirRowwadEnglish) lightSources['Rowwad'] = getTafsirRowwadEnglish;
    if (_tafsirNoorEnglish) lightSources['Noor'] = getTafsirNoorEnglish;
    if (_tafsirYacobEnglish) lightSources['Yacob'] = getTafsirYacobEnglish;
    if (_tafsirQuran) lightSources['Quran'] = getTafsirQuran;
    if (_tafsirMoyassar) lightSources['Moyassar'] = getTafsirMoyassar;
    if (_tafsirSaadi) lightSources['Saadi'] = getTafsirSaadi;
    if (_tafsirYaseer) lightSources['Yaseer'] = getTafsirYaseer;
    if (_tafsirNafahat) lightSources['Nafahat'] = getTafsirNafahat;
    if (_tafsirSiraj) lightSources['Siraj'] = getTafsirSiraj;
    if (_tafsirVarious) {
      lightSources['Various (${_variousLanguage})'] =
          (s, a) => getVariousTranslation(_variousLanguage, s, a);
    }

    final normalizedPhrase = phrase != null ? _normalizeForPhraseMatch(phrase) : null;

    for (final entry in lightSources.entries) {
      final index = _buildIndexForSource(entry.key, entry.value);
      final candidateDocIds = <String>{};
      for (final term in terms) {
        final postings = index.invertedIndex[term];
        if (postings == null) continue;
        for (final p in postings) {
          candidateDocIds.add('${p.surah}:${p.ayah}:${p.source}');
        }
      }
      for (final docId in candidateDocIds) {
        final text = index.docText[docId]!;
        final tokenSet = _tokenize(text).toSet();
        if (!terms.every((t) => tokenSet.contains(t))) continue;
        if (normalizedPhrase != null &&
            !_normalizeForPhraseMatch(text).contains(normalizedPhrase)) {
          continue;
        }
        final parts = docId.split(':');
        scored.add({
          'source': parts.sublist(2).join(':'),
          'surah': int.parse(parts[0]),
          'ayah': int.parse(parts[1]),
          'text': text,
          'score': _bm25Score(index, docId, terms),
        });
      }
    }

    scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    final top = scored.take(300).toList();

    setState(() {
      _tafsirSearchResults = top;
      _tafsirSearchTruncated = scored.length > 300;
      _tafsirSearchHistory.remove(trimmedQuery);
      _tafsirSearchHistory.insert(0, trimmedQuery);
      if (_tafsirSearchHistory.length > 20) {
        _tafsirSearchHistory.removeRange(20, _tafsirSearchHistory.length);
      }
    });

    if (_tafsirSearchScrollController.hasClients) {
      _tafsirSearchScrollController.jumpTo(0);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_tafsirSearchScrollController.hasClients) {
          _tafsirSearchScrollController.jumpTo(0);
        }
      });
    }
  }

  void _jumpToSearchResult(Map<String, dynamic> r) {
    final surah = r['surah'] as int;
    final ayah = r['ayah'] as int;
    final source = r['source'] as String;
    final refString = '$surah:${ayah == 0 ? 1 : ayah}';
    _lastTafsirSearchSurah = surah;
    _lastTafsirSearchAyah = ayah;
    _lastTafsirSearchSource = source;
    _lastTafsirTapListType = 'search';
    setState(() => _tafsirSearchMode = false);
    _tafsirRefController.text = refString;
    _tafsirRefFocusNode.requestFocus();
    _lookupTafsir(context);
  }

  Widget _buildVerseRefHistoryButton() {
    final hasHistory = _verseRefHistory.isNotEmpty;
    return Builder(
      builder: (btnContext) {
        return Tooltip(
          message: hasHistory ? 'Recent references' : 'No recent references yet',
          child: InkWell(
            onTap: hasHistory ? () => _showVerseRefHistoryMenu(btnContext) : null,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: 20,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.deepPurple.withAlpha(hasHistory ? 160 : 40),
                ),
              ),
              child: Icon(
                Icons.arrow_left,
                size: 18,
                color: hasHistory ? Colors.deepPurple[200] : Colors.white24,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVerseRefHistoryMenu(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset(0, button.size.height), ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF2A2A2A),
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 150),
      items: [
        for (final ref in _verseRefHistory)
          PopupMenuItem<String>(
            value: ref,
            height: 32,
            child: Text(ref, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
      ],
    ).then((selected) {
      if (selected != null) {
        _refInputController.text = selected;
        _refInputController.selection =
            TextSelection.fromPosition(TextPosition(offset: selected.length));
        _refInputFocusNode.requestFocus();
      }
    });
  }

  /// Highlights the query inside the given spans.
  ///
  /// - For Arabic queries with [wholeWord] = true: matches whole words
  ///   diacritic-insensitively (so `وَقُولُوا` highlights `وَقُولُوا۟` too).
  /// - For non-Arabic or wholeWord = false: falls back to the original
  ///   substring/word-based highlight (case-insensitive).
  List<TextSpan> _highlightQuery(
    List<TextSpan> spans,
    String query, {
    bool isPhrase = false,
    bool wholeWord = false,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return spans;

    // Arabic query + whole-word mode → use diacritic-insensitive whole-word match.
    final isArabic = RegExp(r'[\u0600-\u06FF\u0750-\u077F]').hasMatch(trimmedQuery);
    if (wholeWord && isArabic) {
      return _highlightArabicWholeWord(spans, trimmedQuery);
    }

    // NEW: Latin / non-Arabic whole-word branch
    if (wholeWord && !isArabic) {
      final escaped = RegExp.escape(trimmedQuery);
      final pattern = RegExp(r'(?<!\w)' + escaped + r'(?!\w)', caseSensitive: false);
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
            result.add(TextSpan(
              text: text.substring(cursor, m.start),
              style: span.style,
              recognizer: span.recognizer,
            ));
          }
          result.add(TextSpan(
            text: text.substring(m.start, m.end),
            style: (span.style ?? const TextStyle()).copyWith(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
            recognizer: span.recognizer,
          ));
          cursor = m.end;
        }
        if (cursor < text.length) {
          result.add(TextSpan(
            text: text.substring(cursor),
            style: span.style,
            recognizer: span.recognizer,
          ));
        }
      }
      return result;
    }

    // ---- Original (non-Arabic / phrase) behavior ----
    final words = trimmedQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (words.isEmpty) return spans;

    final pattern = RegExp(
      isPhrase
          ? words.map(RegExp.escape).join(r'\s+')
          : words.map(RegExp.escape).join('|'),
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
          result.add(TextSpan(
            text: text.substring(cursor, m.start),
            style: span.style,
            recognizer: span.recognizer,
          ));
        }
        result.add(TextSpan(
          text: text.substring(m.start, m.end),
          style: (span.style ?? const TextStyle()).copyWith(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
          recognizer: span.recognizer,
        ));
        cursor = m.end;
      }
      if (cursor < text.length) {
        result.add(TextSpan(
          text: text.substring(cursor),
          style: span.style,
          recognizer: span.recognizer,
        ));
      }
    }
    return result;
  }

  /// Highlights whole-word matches of [query] in each span, ignoring Arabic
  /// diacritics. Uses the existing `_normalizeArabic` helper (which
  /// returns the stripped string plus a map from stripped-index → original-index).
  List<TextSpan> _highlightArabicWholeWord(List<TextSpan> spans, String query) {
    final (queryStripped, _) = _normalizeArabic(query);
    for (final span in spans) {
      if (span.text != null && span.text!.contains(query.substring(0,1))) {
        final (stripped, _) = _normalizeArabic(span.text!);
      }
    }
    final needles = queryStripped
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (needles.isEmpty) return spans;

    // A "word character" for boundary purposes: Arabic block + letters/digits
    // in any script. Diacritics are already stripped from both sides, so we
    // only need to check letters/digits here.
    final wordChar = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF\p{L}\p{N}]',
      unicode: true,
    );

    final out = <TextSpan>[];
    for (final span in spans) {
      final text = span.text;
      if (text == null || text.isEmpty) {
        out.add(span);
        continue;
      }

      final (stripped, indexMap) = _normalizeArabic(text);
      final ranges = <(int, int)>[];

      for (final needle in needles) {
        int start = 0;
        while (true) {
          final idx = stripped.indexOf(needle, start);
          if (idx == -1) break;

          final beforeOk = idx == 0 || !wordChar.hasMatch(stripped[idx - 1]);
          final endIdx = idx + needle.length;
          final afterOk =
              endIdx >= stripped.length || !wordChar.hasMatch(stripped[endIdx]);

          if (beforeOk && afterOk) {
            // Map stripped indices back to original text indices, so the
            // highlight covers the original diacritic-containing word.
            final origStart = indexMap[idx];
            final origEnd = indexMap[endIdx - 1] + 1;
            ranges.add((origStart, origEnd));
          }
          start = idx + 1;
        }
      }

      if (ranges.isEmpty) {
        out.add(span);
        continue;
      }

      // Sort and merge overlapping ranges.
      ranges.sort((a, b) => a.$1.compareTo(b.$1));
      final merged = <(int, int)>[];
      for (final r in ranges) {
        if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
          merged[merged.length - 1] = (
            merged.last.$1,
            r.$2 > merged.last.$2 ? r.$2 : merged.last.$2,
          );
        } else {
          merged.add(r);
        }
      }

      int cursor = 0;
      for (final r in merged) {
        if (r.$1 > cursor) {
          out.add(TextSpan(
            text: text.substring(cursor, r.$1),
            style: span.style,
            recognizer: span.recognizer,
          ));
        }
        out.add(TextSpan(
          text: text.substring(r.$1, r.$2),
          style: (span.style ?? const TextStyle()).copyWith(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
          ),
          recognizer: span.recognizer,
        ));
        cursor = r.$2;
      }
      if (cursor < text.length) {
        out.add(TextSpan(
          text: text.substring(cursor),
          style: span.style,
          recognizer: span.recognizer,
        ));
      }
    }
    return out;
  }

  List<TextSpan> _styledTopicSpans(String topic, TextStyle style, [int globalIndex = -1]) {
    if (topic.contains('{{{')) {
      return _quizStyledSpans(topic, style, globalIndex);
    }
    final base = AllahHighlighter.spans(topic, style, language: widget.selectedLanguage);
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
                                _recordVerseHistory(ref);
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
                      style: const TextStyle(color: Colors.white, fontSize: 16),
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
                  const SizedBox(width: 10),
                  Tooltip(
                    message: '* no vtt - csv not on quranenc.com',
                    preferBelow: true,
                    textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('*',
                        style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13)),
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
                          .map((lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(
                                  lang,
                                  style: TextStyle(
                                    color: _quranLanguageColor(lang),
                                    fontSize: 13,
                                  ),
                                ),
                              ))
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
                             Text('${filtered.length}',
                                 style: const TextStyle(color: Colors.white38, fontSize: 12)),
                             if (widget.isQuranLoaded) ...[
                               const SizedBox(width: 8),
                               Tooltip(
                                 message: 'next ayah',
                                 preferBelow: true,
                                 textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                                 decoration: BoxDecoration(
                                   color: const Color(0xFF2A2A2A),
                                   borderRadius: BorderRadius.circular(6),
                                 ),
                                 child: const Text('⇧Q',
                                     style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                               ),
                             ],
                             const SizedBox(width: 6),
                             if (widget.isQuranLoaded) ...[
                               _buildVerseRefHistoryButton(),
                               const SizedBox(width: 2),
                               SizedBox(
                                 width: 220,
                                 height: 32,
                                 child: TextField(
                                   controller: _refInputController,
                                   focusNode: _refInputFocusNode,
                                   autofocus: true,
                                   style: const TextStyle(color: Colors.white, fontSize: 12),
                                   decoration: InputDecoration(
                                     hintText: '4:12 / 38:36-40',
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
                                       onPressed: () => _playRefFromInput(context),
                                     ),
                                   ),
                                   onSubmitted: (_) => _playRefFromInput(context),
                                 ),
                               ),
                               const SizedBox(width: 8),
                             ],
                             if (widget.isQuranLoaded) ...[
                               SizedBox(
                                 width: 52,
                                 height: 32,
                                 child: TextField(
                                   controller: _rangeRepeatCountController,
                                   focusNode: _rangeRepeatCountFocusNode,
                                   textAlign: TextAlign.center,
                                   keyboardType: TextInputType.number,
                                   inputFormatters: [
                                     FilteringTextInputFormatter.digitsOnly,
                                   ],
                                   style: const TextStyle(
                                     color: Colors.teal,
                                     fontSize: 13,
                                     fontWeight: FontWeight.bold,
                                   ),
                                   decoration: InputDecoration(
                                     isDense: true,
                                     contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                     filled: true,
                                     fillColor: Colors.black26,
                                     suffixText: 'x',
                                     suffixStyle: const TextStyle(
                                       color: Colors.teal,
                                       fontSize: 13,
                                       fontWeight: FontWeight.bold,
                                     ),
                                     border: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(4),
                                       borderSide: BorderSide(color: Colors.teal.withAlpha(160)),
                                     ),
                                     enabledBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(4),
                                       borderSide: BorderSide(color: Colors.teal.withAlpha(160)),
                                     ),
                                     focusedBorder: OutlineInputBorder(
                                       borderRadius: BorderRadius.circular(4),
                                       borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                                     ),
                                   ),
                                   onChanged: (value) {
                                     final parsed = int.tryParse(value);
                                     setState(() {
                                       _rangeRepeatCount = (parsed == null || parsed < 1) ? 1 : parsed;
                                     });
                                   },
                                   onSubmitted: (value) {
                                     final parsed = int.tryParse(value);
                                     final clamped = (parsed == null || parsed < 1) ? 1 : parsed;
                                     setState(() => _rangeRepeatCount = clamped);
                                     _rangeRepeatCountController.text = '$clamped';
                                   },
                                 ),
                               ),
                               const SizedBox(width: 4),
                               IconButton(
                                 icon: const Icon(Icons.repeat, color: Colors.teal, size: 18),
                                 tooltip: 'Play ${_refInputController.text.trim().isEmpty ? "" : _refInputController.text.trim()} repeated',
                                 padding: EdgeInsets.zero,
                                 constraints: const BoxConstraints(),
                                 onPressed: () => _submitRangeRepeat(context),
                               ),
                               const SizedBox(width: 8),
                             ],
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
                                     hintText: 'Search loaded vtt verse text \"exact phrase\"',
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
                         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                         decoration: BoxDecoration(
                           color: Colors.orange.withAlpha(30),
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.orange.withAlpha(80)),
                         ),
                         child: Row(
                           children: [
                             Tooltip(
                               message: 'Load a Quran Verse by Verse audiobook to enable navigation —\n'
                                   'https://t.me/AllahAudiobooks\n'
                                   '(click icon to open link)',
                               waitDuration: const Duration(milliseconds: 200),
                               textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                               decoration: BoxDecoration(
                                 color: const Color(0xFF2A2A2A),
                                 borderRadius: BorderRadius.circular(6),
                               ),
                               child: InkWell(
                                 onTap: _openAllahAudiobooksLink,
                                 child: const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               child: Align(
                                 alignment: Alignment.centerLeft,
                                 child: (widget.lastQuranAudiobook != null &&
                                         widget.onOpenAudiobook != null)
                                     ? InkWell(
                                         onTap: () => widget.onOpenAudiobook!(
                                             widget.lastQuranAudiobook!.audiobookPath),
                                         child: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             const Icon(Icons.play_circle_outline,
                                                 color: Colors.lightBlueAccent, size: 14),
                                             const SizedBox(width: 4),
                                             Flexible(
                                               child: Text(
                                                 'Load last ${widget.lastQuranAudiobook!.audiobookTitle}',
                                                 maxLines: 1,
                                                 overflow: TextOverflow.ellipsis,
                                                 style: const TextStyle(
                                                   color: Colors.lightBlueAccent,
                                                   fontSize: 12,
                                                   decoration: TextDecoration.underline,
                                                 ),
                                               ),
                                             ),
                                           ],
                                         ),
                                       )
                                     : const Text(
                                         'Load a Quran Verse by Verse audiobook',
                                         style: TextStyle(color: Colors.orange, fontSize: 12),
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
                    const SizedBox(width: 8),
                    _quickFilterChip('Schemas', 'schemas'),
                    const SizedBox(width: 8),
                    _quickFilterChip('Juz', 'juz'),
                    const SizedBox(width: 4),
                    _quickFilterChip('14', '14day'),
                    const SizedBox(width: 4),
                    _quickFilterChip('10', '10day'),
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
                    if (_quizSupportedLanguages.contains(widget.selectedLanguage)) ...[
                      const SizedBox(width: 4),
                      _quickFilterChip('Quiz', 'quizzes'),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showSurahListPopup(context),
                      child: Text('Surahs',
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
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

                                            final baseStyle = TextStyle(
                                              color: Colors.white70,
                                              fontSize: _tafsirFontSize,
                                              height: 1.4,
                                            );

                                            final (hlQuery, hlIsPhrase) = _extractHighlightQuery(
                                              widget.quranVerseSearchController.text,
                                            );
                                            final spans = _highlightQuery(
                                              [TextSpan(text: hit.text, style: baseStyle)],
                                              hlQuery,
                                              isPhrase: hlIsPhrase,
                                              wholeWord: hlIsPhrase,
                                            );

                                            return Directionality(
                                              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                                              child: Container(
                                                color: isActive ? Colors.deepPurple.withAlpha(40) : null,
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        GestureDetector(
                                                          onTap: () => widget.onQuranVerseSearchResultTap(hit),
                                                          behavior: HitTestBehavior.opaque,
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              const Icon(Icons.play_circle_fill,
                                                                  size: 14, color: Colors.lightBlueAccent),
                                                              const SizedBox(width: 3),
                                                              Text(
                                                                '${hit.surah}:${hit.ayah}',
                                                                style: TextStyle(
                                                                  color: Colors.lightBlueAccent,
                                                                  fontSize: _tafsirFontSize + 1,
                                                                  fontWeight: FontWeight.w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        GestureDetector(
                                                          onTap: () {
                                                            Clipboard.setData(ClipboardData(text: hit.text));
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('Verse copied'),
                                                                duration: Duration(seconds: 1),
                                                              ),
                                                            );
                                                          },
                                                          child: const Icon(
                                                            Icons.copy,
                                                            color: Colors.white38,
                                                            size: 16,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    SelectableText.rich(
                                                      TextSpan(children: spans),
                                                    ),
                                                  ],
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
                                                        AllahHighlighter.spans(
                                                          entry.topic,
                                                          TextStyle(
                                                              color: Colors.white38,
                                                              fontSize: _tafsirFontSize,
                                                              fontStyle: FontStyle.italic),
                                                          language: widget.selectedLanguage,
                                                        ),
                                                        _searchQuery,
                                                      )
                                                    : AllahHighlighter.spans(
                                                        entry.topic,
                                                        TextStyle(
                                                            color: Colors.white38,
                                                            fontSize: _tafsirFontSize,
                                                            fontStyle: FontStyle.italic),
                                                        language: widget.selectedLanguage,
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
                                            isExpanded ? Icons.expand_less : Icons.expand_more,
                                            color: Colors.white38,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          if (entry.isSubtopic && _parseJuzHizbRubTopic(entry.topic) != null) ...[
                                            Flexible(
                                              child: Directionality(
                                                textDirection: isRtlQuranLanguage(widget.selectedLanguage)
                                                    ? TextDirection.rtl
                                                    : TextDirection.ltr,
                                                child: Text.rich(
                                                  TextSpan(
                                                    children: _styledTopicSpans(
                                                      entry.topic,
                                                      TextStyle(
                                                        color: hasActiveRef ? Colors.purple[200] : Colors.white70,
                                                        fontSize: _headerFontSize,
                                                        fontWeight: hasActiveRef ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                      globalIndex,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _buildCompletionCheckbox(entry.topic),
                                            Builder(builder: (_) {
                                              final parsed = _parseJuzHizbRubTopic(entry.topic);
                                              if (parsed == null || parsed.$1 != 'Juz') return const SizedBox.shrink();
                                              final label = formatJuzDuration(widget.juzDurations, parsed.$2);
                                              if (label.isEmpty) return const SizedBox.shrink();
                                              return Padding(
                                                padding: const EdgeInsets.only(left: 6),
                                                child: Text(
                                                  label,
                                                  style: TextStyle(color: Colors.amber[200], fontSize: 11),
                                                ),
                                              );
                                            }),
                                            const Spacer(),
                                          ] else ...[
                                            Expanded(
                                              child: Directionality(
                                                textDirection: isRtlQuranLanguage(widget.selectedLanguage)
                                                    ? TextDirection.rtl
                                                    : TextDirection.ltr,
                                                child: Text.rich(
                                                  TextSpan(
                                                    children: [
                                                      ..._styledTopicSpans(
                                                        entry.topic,
                                                        TextStyle(
                                                          color: hasActiveRef
                                                              ? Colors.purple[200]
                                                              : entry.isSubtopic
                                                                  ? Colors.white70
                                                                  : Colors.white,
                                                          fontSize: (_categoryForHeaderTopic(entry.topic) != null ||
                                                                  _isDayPlanHeader(entry.topic))
                                                              ? _headerFontSize
                                                              : (entry.isSubtopic ? _tafsirFontSize - 1 : _tafsirFontSize),
                                                          fontWeight: hasActiveRef
                                                              ? FontWeight.bold
                                                              : entry.isSubtopic
                                                                  ? FontWeight.normal
                                                                  : FontWeight.w600,
                                                        ),
                                                        globalIndex,
                                                      ),
                                                      if (_categoryForHeaderTopic(entry.topic) != null)
                                                        ..._completionHeaderSpans(entry.topic)
                                                      else if (_parseDayPlanJuzRange(entry.topic) != null)
                                                        ..._dayPlanDurationSpans(entry.topic, entry.isSubtopic),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (_categoryForHeaderTopic(entry.topic) != null)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () => _resetCompletion(_categoryForHeaderTopic(entry.topic)!),
                                                      child: const Text('Reset',
                                                          style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    GestureDetector(
                                                      onTap: () => _resetCompletion(_categoryForHeaderTopic(entry.topic)!, track: 1),
                                                      child: const Text('Reset',
                                                          style: TextStyle(color: Colors.lightBlueAccent, fontSize: 12)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                          Text(
                                            '${entry.refs.length} ref${entry.refs.length == 1 ? '' : 's'}',
                                            style: const TextStyle(color: Colors.white24, fontSize: 14),
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
                                            _buildPlayAllChips(entry.refs, index),
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
                                                  _recordVerseHistory(ref);
                                                  widget.onVerseSelected(ref, index);
                                                  _refInputFocusNode.requestFocus();
                                                } else {
                                                  final effectiveTo =
                                                      ref.isFullSurah ? quranVerseCounts[ref.surah] : ref.toAyah;
                                                  final refString = (effectiveTo != null && effectiveTo != ref.fromAyah)
                                                      ? '${ref.surah}:${ref.fromAyah}-$effectiveTo'
                                                      : '${ref.surah}:${ref.fromAyah}';
                                                  setState(() {
                                                    _lastTafsirRef = ref;
                                                    _lastTafsirIndex = index;
                                                    _tafsirSearchMode = false;
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
                                                    fontSize: 12,
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
            fontSize: 13,
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
          Row(
            children: [
              _buildTafsirFontSizeButton(),
              const SizedBox(width: 6),
              _modeChip('Browse', !_tafsirSearchMode, () {
                setState(() => _tafsirSearchMode = false);
                _tafsirRefFocusNode.requestFocus();
              }),
              const SizedBox(width: 6),
              _modeChip('Search', _tafsirSearchMode, () {
                setState(() => _tafsirSearchMode = true);
                _tafsirSearchFocusNode.requestFocus();
                _scrollToLastTafsirSearchTap();
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
                            const SizedBox(width: 6),
                            _tafsirCheckbox('wbw', _wordByWordMode, (v) {
                              setState(() {
                                _wordByWordMode = v ?? false;
                                if (_wordByWordMode) _tafsirQuran = true;
                              });
                              if (_wordByWordMode) _loadWordAudioIndexIfNeeded();
                            }, Colors.cyanAccent),
                            if (_wordAudioIndexLoading)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: SizedBox(width: 10, height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.cyanAccent)),
                              ),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Quran', _tafsirQuran, (v) {
                              setState(() => _tafsirQuran = v ?? false);
                            }, Colors.white70),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Moyassar', _tafsirMoyassar, (v) {
                              setState(() => _tafsirMoyassar = v ?? false);
                            }, Colors.pinkAccent),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Saadi', _tafsirSaadi, (v) {
                              setState(() => _tafsirSaadi = v ?? false);
                            }, Colors.amber),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Yaseer', _tafsirYaseer, (v) {
                              setState(() => _tafsirYaseer = v ?? false);
                            }, Colors.tealAccent),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Nafahat', _tafsirNafahat, (v) {
                              setState(() => _tafsirNafahat = v ?? false);
                            }, Colors.limeAccent),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Siraj', _tafsirSiraj, (v) {
                              setState(() => _tafsirSiraj = v ?? false);
                            }, Colors.indigoAccent),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Baghawi', _tafsirBaghawi, (v) {
                              setState(() => _tafsirBaghawi = v ?? false);
                              if (_tafsirBaghawi) _loadHeavyIndex('Baghawi');
                            }, Colors.deepOrangeAccent),
                            const SizedBox(width: 6),
                            _tafsirCheckbox('Katheer', _tafsirKatheer, (v) {
                              setState(() => _tafsirKatheer = v ?? false);
                              if (_tafsirKatheer) _loadHeavyIndex('Katheer');
                            }, Colors.brown),
                            if (_katheerIndexLoading)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: SizedBox(width: 10, height: 10,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.brown)),
                              ),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchHistoryButton(),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 220,
                          height: 32,
                          child: TextField(
                            controller: _tafsirSearchController,
                            focusNode: _tafsirSearchFocusNode,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Search tafsir "exact text',
                              hintStyle: const TextStyle(
                                  color: Colors.white24, fontSize: 12),
                              prefixIcon: InkWell(
                                onTap: () => _searchTafsirText(_tafsirSearchController.text),
                                child: const Icon(Icons.search,
                                    color: Colors.teal, size: 16),
                              ),
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
                        ),
                      ],
                    )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRefHistoryButton(),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 144,
                            height: 32,
                            child: TextField(
                              controller: _tafsirRefController,
                              focusNode: _tafsirRefFocusNode,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: '2:255/2:2-4',
                                hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(color: Colors.teal.withAlpha(160)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(color: Colors.teal.withAlpha(80)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Colors.teal),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.search, color: Colors.teal, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _lookupTafsir(context),
                                ),
                              ),
                              onSubmitted: (_) => _lookupTafsir(context),
                            ),
                          ),
                        ],
                      ),
                  const SizedBox(width: 8),
                  _tafsirCheckbox('Mokhtasar', _tafsirMokhtasar, (v) {
                    setState(() => _tafsirMokhtasar = v ?? false);
                  }, Colors.greenAccent),
                  const SizedBox(width: 8),
                  if (_tafsirMokhtasar)
                    DropdownButton<String>(
                      value: _mokhtasarLanguage,
                      dropdownColor: const Color(0xFF2A2A2A),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      underline: const SizedBox(),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.greenAccent, size: 18),
                      items: mokhtasarLanguages
                          .map((lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(
                                  lang,
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                                ),
                              ))
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
                    const SizedBox(width: 7),
                    _tafsirCheckbox('Hilali', _tafsirHilali, (v) {
                      setState(() => _tafsirHilali = v ?? false);
                    }, Colors.lightBlueAccent),
                    const SizedBox(width: 7),
                    _tafsirCheckbox('Rowwad', _tafsirRowwadEnglish, (v) {
                      setState(() => _tafsirRowwadEnglish = v ?? false);
                    }, Colors.orangeAccent),
                    const SizedBox(width: 7),
                    _tafsirCheckbox('Noor', _tafsirNoorEnglish, (v) {
                      setState(() => _tafsirNoorEnglish = v ?? false);
                    }, Colors.redAccent),
                    const SizedBox(width: 7),
                    _tafsirCheckbox('Yacob', _tafsirYacobEnglish, (v) {
                      setState(() => _tafsirYacobEnglish = v ?? false);
                    }, Colors.purpleAccent),
                    const SizedBox(width: 7),
                    _tafsirCheckbox('Kathir', _tafsirKathir, (v) {
                      setState(() => _tafsirKathir = v ?? false);
                      if (_tafsirKathir) _loadHeavyIndex('Kathir');
                    }, Colors.brown),
                    const SizedBox(width: 6),
                    _selectAllCheckbox(
                        _allEnglishTafsirsSelected, _toggleAllEnglishTafsirs),
                    const SizedBox(width: 7),
                    _tafsirCheckbox('', _tafsirVarious, (v) {
                      setState(() => _tafsirVarious = v ?? false);
                    }, Colors.indigoAccent),
                    const SizedBox(width: 6),
                    _tafsirVarious
                        ? DropdownButton<String>(
                            value: _variousLanguage,
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: const TextStyle(color: Colors.indigoAccent, fontSize: 12),
                            underline: const SizedBox(),
                            isDense: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.amber, size: 18),
                            items: variousTranslationLanguages
                                .map((lang) => DropdownMenuItem(
                                      value: lang,
                                      child: Text(lang, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                                    ))
                                .toList(),
                            onChanged: (lang) {
                              if (lang != null) {
                                setState(() => _variousLanguage = lang);
                                if (_tafsirRefController.text.isNotEmpty) _lookupTafsir(context);
                              }
                            },
                          )
                        : const Text('None',
                            style: TextStyle(color: Colors.white24, fontSize: 12)),
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
                  child: ScrollablePositionedList.separated(
                    itemScrollController: _tafsirSearchItemScrollController,
                    itemCount: _tafsirSearchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white12, height: 12),
                    itemBuilder: (_, i) {
                      final r = _tafsirSearchResults[i];
                      final rawQuery = _tafsirSearchController.text.trim();
                      final phrase = _extractQuotedPhrase(rawQuery);
                      return InkWell(
                        onTap: () => _jumpToSearchResult(r),
                        child: _buildTafsirCard(
                          r,
                          highlightQuery: phrase ?? rawQuery,
                          highlightIsPhrase: phrase != null,
                          highlightWholeWord: RegExp(r'[\u0600-\u06FF\u0750-\u077F]')
                              .hasMatch(phrase ?? rawQuery),
                          fontSize: _tafsirFontSize + 4,
                          isSearchResult: true,
                        ),
                      );
                    },
                  ),
                ),
            ] else if (_tafsirResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Expanded(
                child: ScrollablePositionedList.separated(
                  itemScrollController: _tafsirBrowseItemScrollController,
                  itemCount: _tafsirResults.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 12),
                  itemBuilder: (_, i) =>
                      _buildTafsirCard(_tafsirResults[i], isSearchResult: false),
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
        _tafsirQuran &&
        _tafsirMoyassar &&
        _tafsirSaadi &&
        _tafsirYaseer &&
        _tafsirNafahat &&
        _tafsirSiraj &&
        _tafsirBaghawi &&
        _tafsirKatheer;

    bool get _allEnglishTafsirsSelected =>
        _tafsirHilali &&
        _tafsirRowwadEnglish &&
        _tafsirNoorEnglish &&
        _tafsirYacobEnglish &&
        _tafsirKathir;

    void _toggleAllArabicTafsirs(bool? value) {
      final v = value ?? false;
      setState(() {
        _tafsirQuran = v;
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
        _tafsirHilali = v;
        _tafsirRowwadEnglish = v;
        _tafsirNoorEnglish = v;
        _tafsirYacobEnglish = v;
        _tafsirKathir = v;
      });
    }

    Widget _selectAllCheckbox(bool value, ValueChanged<bool?> onChanged) {
        return SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.lime,
            side: const BorderSide(color: Colors.lime, width: 1.0),
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

  Widget _buildTafsirCard(
    Map<String, dynamic> r, {
    String? highlightQuery,
    bool highlightIsPhrase = false,
    bool highlightWholeWord = false,
    double? fontSize,
    bool isSearchResult = false,
  }) {
      final source = r['source'] as String;
      final surah = r['surah'] as int;
      final ayah = r['ayah'] as int;
      final text = r['text'] as String;
      final effectiveFontSize = fontSize ?? _tafsirFontSize;
      final isRtl = source == 'Mokhtasar Ar' ||
          isMokhtasarRtl(_mokhtasarLanguage) ||
          (source.startsWith('Various') && isVariousTranslationRtl(_variousLanguage)) ||
          source == 'Quran' ||
          source == 'Moyassar' ||
          source == 'Saadi' ||
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
        'Kathir' => Colors.brown,
        'Quran' => Colors.white70,
        'Moyassar' => Colors.pinkAccent,
        'Saadi' => Colors.amber,
        'Yaseer' => Colors.tealAccent,
        'Siraj' => Colors.indigoAccent,
        'Nafahat' => Colors.limeAccent,
        'Baghawi' => Colors.deepOrangeAccent,
        'Katheer' => Colors.brown,
        _ when source.startsWith('Various') => Colors.indigoAccent,
        _ => Colors.greenAccent,
      };
      final ayahLabel = ayah == 0 ? '$surah:intro' : '$surah:$ayah';
      final score = r['score'] as double?;
      final isActiveCard = _lastTafsirTapListType ==
              (isSearchResult ? 'search' : 'browse') &&
          _lastTafsirSearchSurah == surah &&
          _lastTafsirSearchAyah == ayah &&
          _lastTafsirSearchSource == source;
      return Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActiveCard
                ? Colors.deepPurple.withAlpha(40)
                : Colors.white.withAlpha(6),
            borderRadius: BorderRadius.circular(6),
            border: isActiveCard
                ? Border.all(color: Colors.deepPurple.withAlpha(160))
                : null,
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
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: ayahLabel,
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                        ),
                        if (score != null)
                          TextSpan(
                            text: ' (score ${score.toStringAsFixed(1)})',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (widget.isQuranLoaded && ayah != 0) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        _lastTafsirSearchSurah = surah;
                        _lastTafsirSearchAyah = ayah;
                        _lastTafsirSearchSource = source;
                        _lastTafsirTapListType = isSearchResult ? 'search' : 'browse';
                        _onTafsirVerseTapped('$surah:$ayah');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_fill,
                              size: 14, color: Colors.lightBlueAccent),
                          const SizedBox(width: 3),
                          Text(
                            '$surah:$ayah',
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
              source == 'Quran' && _wordByWordMode
                  ? _buildWordByWordText(surah, ayah, effectiveFontSize, highlightQuery: highlightQuery)
                  : _buildTafsirText(text, isRtl,
                      isIntro: ayah == 0,
                      highlightQuery: highlightQuery,
                      highlightIsPhrase: highlightIsPhrase,
                      highlightWholeWord: highlightWholeWord,
                      fontSize: effectiveFontSize,
                    )
            ],
          ),
        ),
      );
    }

    Widget _buildTafsirText(
      String text,
      bool isRtl, {
      bool isIntro = false,
      String? highlightQuery,
      bool highlightIsPhrase = false,
      bool highlightWholeWord = false,
      double fontSize = 14.0,
    }) {
      if (isIntro) {
        return SelectableText(
          text,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
          style: TextStyle(color: Colors.amber, fontSize: fontSize, height: 1.55),
        );
      }

      final orangeStyle =
          TextStyle(color: Colors.orangeAccent, fontSize: fontSize, height: 1.55);

      final lowerText = text.toLowerCase();
      const beneficialMarker = '• beneficial points:';
      const footnotesMarker = 'footnotes:';

      final beneficialIdx = lowerText.indexOf(beneficialMarker);
      final footnotesIdx = lowerText.indexOf(footnotesMarker);

      if (beneficialIdx == -1 && footnotesIdx == -1) {
        var spans = AllahHighlighter.spans(
          text,
          TextStyle(color: Colors.white, fontSize: fontSize, height: 1.55),
          language: _mokhtasarLanguage,
          includeVerseRefs: true,
          onVerseTapped: _onTafsirVerseTapped,
          verseStyle: TextStyle(
              color: Colors.lightBlueAccent, fontSize: fontSize, height: 1.55),
        );
        if (highlightQuery != null && highlightQuery.isNotEmpty) {
          spans = _highlightQuery(
            spans,
            highlightQuery,
            isPhrase: highlightIsPhrase,
            wholeWord: highlightWholeWord,
          );
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
        spans.addAll(AllahHighlighter.spans(
          mainText,
          TextStyle(color: Colors.white, fontSize: fontSize, height: 1.55),
          language: _mokhtasarLanguage,
          includeVerseRefs: true,
          onVerseTapped: _onTafsirVerseTapped,
          verseStyle: TextStyle(
              color: Colors.lightBlueAccent, fontSize: fontSize, height: 1.55),
        ));
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
        spans.addAll(AllahHighlighter.spans(
          afterMarker,
          TextStyle(color: Colors.greenAccent, fontSize: fontSize, height: 1.55),
          language: _mokhtasarLanguage,
          includeVerseRefs: true,
          onVerseTapped: _onTafsirVerseTapped,
          verseStyle: TextStyle(
              color: Colors.lightBlueAccent, fontSize: fontSize, height: 1.55),
        ));
      }

      if (footnotesIdx != -1) {
        final labelEnd = footnotesIdx + footnotesMarker.length;
        final label = text.substring(footnotesIdx, labelEnd);
        spans.add(
          TextSpan(
            text: '\n\n$label',
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: fontSize,
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
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: fontSize,
                    height: 1.55,
                  ),
                ),
              );
            } else {
              spans.add(
                TextSpan(
                  text: m,
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: fontSize,
                    height: 1.55,
                  ),
                ),
              );
            }
          } else {
            spans.addAll(AllahHighlighter.spans(
              m,
              TextStyle(color: Colors.white, fontSize: fontSize, height: 1.55),
              language: _mokhtasarLanguage,
              includeVerseRefs: true,
              onVerseTapped: _onTafsirVerseTapped,
              verseStyle: TextStyle(
                  color: Colors.lightBlueAccent, fontSize: fontSize, height: 1.55),
            ));
          }
        }
      }

      var finalSpans = spans;
      if (highlightQuery != null && highlightQuery.isNotEmpty) {
        finalSpans = _highlightQuery(
          finalSpans,
          highlightQuery,
          isPhrase: highlightIsPhrase,
          wholeWord: highlightWholeWord,
        );
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

class _WordByWordChip extends StatefulWidget {
  final String arabic;
  final String english;
  final double fontSize;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback? onSearchIconTap;
  const _WordByWordChip({
    required this.arabic,
    required this.english,
    required this.fontSize,
    this.highlighted = false,
    required this.onTap,
    this.onSearchIconTap,
  });

  @override
  State<_WordByWordChip> createState() => _WordByWordChipState();
}

class _WordByWordChipState extends State<_WordByWordChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: Tooltip(
              message: widget.english,
              preferBelow: false,
              textStyle: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: _hovering ? Colors.cyanAccent.withAlpha(30) : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.arabic,
                  style: TextStyle(
                    color: widget.highlighted
                        ? Colors.yellow
                        : (_hovering ? Colors.cyanAccent : Colors.white),
                    fontWeight: widget.highlighted ? FontWeight.bold : FontWeight.normal,
                    fontSize: widget.fontSize + 4,
                  ),
                ),
              ),
            ),
          ),
          if (widget.onSearchIconTap != null)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _hovering ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_hovering,
                child: InkWell(
                  onTap: widget.onSearchIconTap,
                  child: const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.search, size: 13, color: Colors.white38),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
