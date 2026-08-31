import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'hadeeth_index.dart';

class HadeethPanel extends StatefulWidget {
  final String initialLanguage;
  final FocusNode searchFocusNode;
  final FocusNode excludeFocusNode;

  const HadeethPanel({
    super.key,
    this.initialLanguage = 'English',
    required this.searchFocusNode,
    required this.excludeFocusNode,
  });

  @override
  State<HadeethPanel> createState() => _HadeethPanelState();
}

class _HadeethPosting {
  final int id;
  final int termFreq;
  const _HadeethPosting(this.id, this.termFreq);
}

class _HadeethBm25Index {
  final Map<String, List<_HadeethPosting>> invertedIndex = {};
  final Map<int, int> docLengths = {};
  int totalDocs = 0;
  double avgDocLength = 0;
}

List<String> _tokenizeHadeeth(String text) {
  return text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((t) => t.isNotEmpty)
      .toList();
}

class _HadeethPanelState extends State<HadeethPanel> {
  static String _language = 'English';
  static List<HadeethEntry> _allEntries = [];
  static bool _loading = true;
  static bool _categoryMode = false;
  static final TextEditingController _searchController = TextEditingController();
  static final TextEditingController _excludeController = TextEditingController();
  static List<String> _searchTerms = [];
  static List<String> _excludeTerms = [];
  static final Map<int, bool> _categoryExpanded = {};
  static final Set<int> _expandedIds = {};
  static double _hadeethFontSize = 14.0;
  static List<String> _searchHistory = [];
  final ScrollController _hadeethScrollController = ScrollController();

  FocusNode get _searchFocus => widget.searchFocusNode;
  FocusNode get _excludeFocus => widget.excludeFocusNode;

  @override
  void initState() {
    super.initState();
    if (_allEntries.isEmpty) {
      _loadLanguage(_language);
    } else {
      if (_loading) _loading = false;
    }
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    if (_searchFocus.hasFocus || _excludeFocus.hasFocus) {
      _searchFocus.unfocus();
      _excludeFocus.unfocus();
    }
    _hadeethScrollController.dispose();
    super.dispose();
  }


  void _loadLanguage(String lang) {
    setState(() => _loading = true);
    Future.microtask(() {
      final entries = getHadeethForLanguage(lang);
      if (mounted) {
        setState(() {
          _allEntries = entries;
          _loading = false;
          _categoryExpanded.clear();
          _expandedIds.clear();
          _recomputeSearchResults();
        });
      }
    });
  }

  static const double _k1 = 1.5;
  static const double _b = 0.75;
  static List<HadeethEntry> _searchResultsCache = [];
  static Map<int, double> _searchScores = {};

  _HadeethBm25Index _buildHadeethBm25Index(List<HadeethEntry> entries) {
    final index = _HadeethBm25Index();
    int totalLength = 0;
    for (final e in entries) {
      final text =
          '${e.title} ${e.hadeeth} ${e.category} ${e.explanation} ${e.hints.join(' ')}';
      final tokens = _tokenizeHadeeth(text);
      if (tokens.isEmpty) continue;
      final termCounts = <String, int>{};
      for (final t in tokens) {
        termCounts[t] = (termCounts[t] ?? 0) + 1;
      }
      for (final entry in termCounts.entries) {
        index.invertedIndex
            .putIfAbsent(entry.key, () => [])
            .add(_HadeethPosting(e.id, entry.value));
      }
      index.docLengths[e.id] = tokens.length;
      totalLength += tokens.length;
      index.totalDocs++;
    }
    index.avgDocLength = index.totalDocs == 0 ? 0 : totalLength / index.totalDocs;
    return index;
  }

  double _bm25ScoreHadeeth(_HadeethBm25Index index, int id, List<String> terms) {
    final docLen = index.docLengths[id] ?? 0;
    if (docLen == 0 || index.avgDocLength == 0) return 0;
    double score = 0;
    for (final term in terms) {
      final postings = index.invertedIndex[term];
      if (postings == null) continue;
      final df = postings.length;
      final idf = math.log(1 + (index.totalDocs - df + 0.5) / (df + 0.5));
      final posting = postings.firstWhere(
        (p) => p.id == id,
        orElse: () => const _HadeethPosting(-1, 0),
      );
      final tf = posting.termFreq;
      if (tf == 0) continue;
      final numerator = tf * (_k1 + 1);
      final denominator =
          tf + _k1 * (1 - _b + _b * (docLen / index.avgDocLength));
      score += idf * (numerator / denominator);
    }
    return score;
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


  List<HadeethEntry> _bm25SearchEntries(List<String> terms, {String? phrase}) {
    final index = _buildHadeethBm25Index(_allEntries);

    Set<int>? candidateIds;
    for (final term in terms) {
      final postings = index.invertedIndex[term];
      final ids = postings?.map((p) => p.id).toSet() ?? <int>{};
      candidateIds =
          candidateIds == null ? ids : candidateIds.intersection(ids);
      if (candidateIds.isEmpty) return [];
    }
    if (candidateIds == null) return [];

    final normalizedPhrase = phrase != null ? _normalizeForPhraseMatch(phrase) : null;

    final byId = {for (final e in _allEntries) e.id: e};
    final scored = <MapEntry<HadeethEntry, double>>[];
    for (final id in candidateIds) {
      final e = byId[id];
      if (e == null) continue;
      if (normalizedPhrase != null) {
        final fullText =
            '${e.title} ${e.hadeeth} ${e.category} ${e.explanation} ${e.hints.join(' ')}';
        if (!_normalizeForPhraseMatch(fullText).contains(normalizedPhrase)) continue;
      }
      if (_excludeTerms.isNotEmpty) {
        final haystack =
            '${e.title} ${e.hadeeth} ${e.category} ${e.id}'.toLowerCase();
        if (_excludeTerms.any((t) => haystack.contains(t))) continue;
      }
      scored.add(MapEntry(e, _bm25ScoreHadeeth(index, id, terms)));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    _searchScores = {for (final s in scored) s.key.id: s.value};
    return scored.map((e) => e.key).toList();
  }

  void _scrollHadeethListToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hadeethScrollController.hasClients) {
        _hadeethScrollController.jumpTo(0);
      }
    });
  }

  void _performHadeethSearch() {
    final trimmed = _searchController.text.trim();
    final phrase = _extractQuotedPhrase(trimmed);
    setState(() {
      _searchTerms = (phrase ?? trimmed)
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      if (_searchTerms.isNotEmpty) {
        _categoryExpanded.clear();
        _searchHistory.remove(trimmed);
        _searchHistory.insert(0, trimmed);
        if (_searchHistory.length > 20) {
          _searchHistory.removeRange(20, _searchHistory.length);
        }
      }
      _recomputeSearchResults();
    });
  }

  void _recomputeSearchResults() {
    if (_searchTerms.isEmpty) {
      _searchResultsCache = [];
      _searchScores = {};
      _scrollHadeethListToTop();
      return;
    }
    final idHits =
        _allEntries.where((e) => _searchTerms.contains(e.id.toString())).toList();
    if (idHits.isNotEmpty) {
      _searchResultsCache = idHits;
      _searchScores = {};
      _scrollHadeethListToTop();
      return;
    }
    final rawQuery = _searchController.text.trim();
    final phrase = _extractQuotedPhrase(rawQuery);
    final terms = _tokenizeHadeeth(phrase ?? rawQuery);
    _searchResultsCache = _bm25SearchEntries(terms, phrase: phrase);
    _scrollHadeethListToTop();
  }

  bool _entryMatches(HadeethEntry e) {
    if (_searchTerms.isEmpty && _excludeTerms.isEmpty) return true;
    final haystack =
        '${e.title} ${e.hadeeth} ${e.category} ${e.id}'.toLowerCase();
    for (final t in _searchTerms) {
      if (t == e.id.toString()) return true;
      if (!haystack.contains(t)) return false;
    }
    for (final t in _excludeTerms) {
      if (haystack.contains(t)) return false;
    }
    return true;
  }

  void _cycleHadeethFontSize() {
    setState(() {
      if (_hadeethFontSize == 14.0) {
        _hadeethFontSize = 16.0;
      } else if (_hadeethFontSize == 16.0) {
        _hadeethFontSize = 18.0;
      } else {
        _hadeethFontSize = 14.0;
      }
    });
  }

  Widget _buildHadeethFontSizeButton() {
    final fontSizeLabel = _hadeethFontSize.toInt().toString();
    return InkWell(
      onTap: _cycleHadeethFontSize,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 28,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.orange.withAlpha(160),
          ),
        ),
        child: Text(
          fontSizeLabel,
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<HadeethEntry> get _filtered {
    if (_searchTerms.isEmpty && _excludeTerms.isEmpty) return _allEntries;
    if (_searchTerms.isNotEmpty) return _searchResultsCache;
    return _allEntries.where(_entryMatches).toList();
  }

  Widget _buildSearchHistoryButton() {
    final hasHistory = _searchHistory.isNotEmpty;
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
                  color: Colors.orange.withAlpha(hasHistory ? 160 : 40),
                ),
              ),
              child: Icon(
                Icons.arrow_left,
                size: 20,
                color: hasHistory ? Colors.orange : Colors.white24,
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
        for (final term in _searchHistory)
          PopupMenuItem<String>(
            value: term,
            height: 32,
            child: Text(term, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
      ],
    ).then((selected) {
      if (selected != null) {
        _searchController.text = selected;
        _searchController.selection =
            TextSelection.fromPosition(TextPosition(offset: selected.length));
        _searchFocus.requestFocus();
      }
    });
  }

  Map<String, List<HadeethEntry>> _groupByCategory(List<HadeethEntry> entries) {
    final map = <String, List<HadeethEntry>>{};
    for (final e in entries) {
      map.putIfAbsent(e.category, () => []).add(e);
    }
    return map;
  }

  Color _gradeColor(String grade) {
    final g = grade.toLowerCase();
    if (g.contains('authentic')) return Colors.greenAccent;
    if (g.contains('good') || g.contains('hasan')) return Colors.lightBlueAccent;
    if (g.contains('weak')) return Colors.orangeAccent;
    return Colors.white54;
  }

  static const Map<String, List<String>> _allahWords = {
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
      'ئاللاھقا', 'ئاللاھنىڭ', 'ئاللاھتىن', 'ئاللاھتا', 'ئاللاھنى', 'ئاللاھ',
      'پەرۋەردىگارىڭلار', 'پەرۋەردىگارىڭنىڭ', 'پەرۋەردىگارىنىڭ',
      'پەرۋەردىگارىڭ', 'پەرۋەردىگارىم', 'پەرۋەردىگارى', 'پەرۋەردىگار',
      'رەببىڭنىڭ', 'رەببىنىڭ', 'رەببىڭ', 'رەببىم', 'رەببى', 'رەبب',
      'الله', 'اﷲ',
    ],
    'PersianAfghan': [
      'بالله', 'والله', 'لله', 'الله',
      'خداوندا', 'خداوندی', 'خداوند',
      'خدایا', 'خدای', 'خدا',
      'پروردگارا', 'پروردگاری', 'پروردگار',
    ],
    'English': [
      'Allah\u2019s', 'Allāh\u2019s', 'Allâh\u2019s',
      'Allah\u02BCs', 'Allāh\u02BCs', 'Allâh\u02BCs',
      "Allah's", "Allāh's", "Allâh's",
      'Allah', 'Allāh', 'Allâh',
      'Lord\u2019s', 'Lord\u02BCs', "Lord's", 'Lord',
    ],
    'Albanian': [
      'All-llahun', 'All-llahut', 'All-llahu',
      'Allahun', 'Allahut', 'Allahu',
      'Zotin', 'Zotit', 'Zoti',
    ],
    'Assamese': [
      'আল্লাহৰ', 'আল্লাহে', 'আল্লাহক', 'আল্লাহ্', 'আল্লাহ',
      'প্ৰতিপালকৰ', 'প্ৰতিপালক', 'ৰব',
    ],
    'Bangla': ['আল্লাহর', 'আল্লাহ্', 'আল্লাহ', 'রব', 'প্রতিপালক'],
    'Burmese': ['အလ္လာဟ်အရှင်မြတ်', 'အလ္လာဟ်', 'အရှင်မြတ်', 'အရှင်'],
    'Bosnian': [
      'Allahovoj', 'Allahova', 'Allahovog', 'Allahovom', 'Allahovih',
      'Allahove', 'Allahovu', 'Allahovi', 'Allahov', 'Allahu', 'Allaha', 'Allah',
    ],
    'Chinese': ['安拉', '真主'],
    'Dutch': ['Allah', 'Heer'],
    'Filipino': ['Allāh', 'Allah', 'Panginoon'],
    'French': ['qu\u2019Allah', 'qu\'Allah', 'd\u2019Allah', 'd\'Allah', 'Allah', 'Seigneur'],
    'Georgian': [
      'ალაჰისათვის', 'ალაჰისგან', 'ალაჰზე', 'ალაჰმა', 'ალაჰსა', 'ალაჰის',
      'ალაჰთან', 'ალაჰს', 'ალაჰი', 'ალაჰისა',
      'უფლისაგან', 'უფლის', 'უფალო', 'უფალს', 'უფალი',
    ],
    'German': ['Allah', 'Herr'],
    'Gujarati': ['અલ્લાહ', 'પાલનહાર', 'પાલનહારનો', 'પાલનહારની', 'પાલનહારનું', 'રબ્બ'],
    'Hausa': ['Allahu', 'Allah', 'Ubangiji'],
    'Hindi': ['अल्लाह', 'रब्ब', 'परवरदिगार'],
    'Hungarian': [
      'Allahnak', 'Allahtól', 'Allahot', 'Allah',
      'Uram', 'Urunk', 'Uratok', 'Uruk', 'Úrnak', 'Úr',
    ],
    'Indonesian': ['Allahlah', 'Allah', 'Rabb', 'Tuhan'],
    'Italian': ['Allāh', 'Allah'],
    'Japanese': [
      'アッラー', 'アッラーの', 'アッラーに', 'アッラーは', 'アッラーが', 'アッラーを', 'アッラーと',
      '主',
    ],
    'Kannada': ['ಅಲ್ಲಾಹ', 'ಅಲ್ಲಾಹನ', 'ಒಡೆಯ', 'ಒಡೆಯನ', 'ಪ್ರಭು'],
    'Khmer': ['អល់ឡោះ', 'ម្ចាស់'],
    'Macedonian': [
      'Аллаховото', 'Аллахови', 'Аллахова', 'Аллахово', 'Аллахов',
      'Аллахот', 'Аллаха', 'Аллаху', 'Аллах',
      'Господарот', 'Господаро', 'Господару', 'Господаров', 'Господа', 'Господ', 'Господар',
    ],
    'Malagasy': ['Tompo', 'Allah', 'Andriamanitra'],
    'Malayalam': [
      'അല്ലാഹുവിൻ്റെ', 'അല്ലാഹുവിന്റെ', 'അല്ലാഹുവിനെ',
      'അല്ലാഹുവെ', 'അല്ലാഹുവിന്', 'അല്ലാഹു', 'റബ്ബ്',
    ],
    'Marathi': [
      'पालनहर्त्याकडून', 'पालनहर्त्याकडे', 'पालनहर्त्याचा', 'पालनहर्त्याची',
      'पालनहर्त्याचे', 'पालनहर्त्यास', 'पालनहर्त्या', 'पालनहर्ता',
      'अल्लाहकडून', 'अल्लाहबद्दल', 'अल्लाहकडे', 'अल्लाहसाठी', 'अल्लाहच्या',
      'अल्लाहचा', 'अल्लाहची', 'अल्लाहचे', 'अल्लाहने', 'अल्लाहला', 'अल्लाहवर', 'अल्लाहशी', 'अल्लाह',
      'प्रभु', 'प्रभू',
    ],
    'Mossi': [
      'Wẽnnaam', 'Allah', 'Alla', 'Wẽnd',
      'M Dũnni', 'fo Dũnni', 'a Dũnni', 'tõnd Dũnni', 'yãmb Dũnni', 'b Dũnni',
      'Dũnia', 'Dũnni', 'Naam',
    ],
    'Punjabi': [
      'ਅੱਲਾਹ', 'ਅੱਲਾਹ ਦੀ', 'ਅੱਲਾਹ ਦਾ', 'ਅੱਲਾਹ ਦੇ', 'ਅੱਲਾਹ ਨੂੰ', 'ਅੱਲਾਹ ਤੋਂ',
      'ਅੱਲਾਹ ਵੱਲ', 'ਅੱਲਾਹ ਉੱਤੇ', 'ਅੱਲਾਹ ਕੋਲ', 'ਅੱਲਾਹ ਲਈ', 'ਅੱਲਾਹ ਨਾਲ', 'ਅੱਲਾਹ ਬਾਰੇ',
      'ਰੱਬ', 'ਰੱਬ ਵੱਲੋਂ', 'ਰੱਬ ਦਾ', 'ਰੱਬ ਦੀ', 'ਰੱਬ ਦੇ', 'ਰੱਬ ਨੂੰ', 'ਰੱਬ ਤੋਂ',
    ],
    'Romanian': ['Allah', 'Domnul', 'Domn'],
    'Russian': ['Аллахом', 'Аллахе', 'Аллаху', 'Аллаха', 'Аллах', 'Господом', 'Господу', 'Господа', 'Господь'],
    'Serbian': [
      'Аллаховим', 'Аллахови', 'Аллахов', 'Аллаховом', 'Аллахових', 'Аллахову',
      'Аллахово', 'Аллахове', 'Аллахова', 'Аллаху', 'Аллаха', 'Аллах',
      'Господара', 'Господару', 'Алаха', 'Алаху', 'Алах', 'Господар',
    ],
    'Sinhala': ['අල්ලාහ්ගෙන්', 'අල්ලාහ්ගේ', 'අල්ලාහ්ට', 'අල්ලාහ්ද', 'අල්ලාහ්', 'රබ්'],
    'Spanish': ['Al\u2011lah', 'Al-lah', 'Allāh', 'Allah', 'Señor'],
    'Swahili': ['Allah', 'Mwenyezi Mungu', 'Bwana'],
    'Swedish': [
      'världarnas Herres', 'världarnas Herre', 'Herrens', 'Herren',
      'Allahs', 'Herres', 'Allah', 'Herre',
    ],
    'Tamil': ['அல்லாஹ்வுக்கும்', 'அல்லாஹ்வுக்கு', 'அல்லாஹ்வின்', 'அல்லாஹ்வை', 'அல்லாஹை', 'அல்லாஹின்', 'அல்லாஹ்', 'ரப்'],
    'Telugu': ['అల్లాహ్', 'రబ్బ్'],
    'Thai': ['พระผู้อภิบาล', 'อัลลอฮ์'],
    'Turkish': [
      'Allah\u2019adır', 'Allah\u2019tır', 'Allah\u2019tan', 'Allah\u2019ım',
      'Allah\u2019ın', 'Allah\u2019ı', 'Allah\u2019a',
      "Allah'adır", "Allah'tır", "Allah'tan", "Allah'ım", "Allah'ın", "Allah'ı", "Allah'a",
      'Allah',
    ],
    'Ukrainian': ['Господа світів', 'Господь', 'Господа', 'Господи', 'Аллахом', 'Аллаха', 'Аллах'],
    'Vietnamese': ['Thượng Đế', 'Allah'],
    'Portuguese': ['Allah', 'Senhor'],
  };

  List<TextSpan> _colorParensAndAllah(String text, TextStyle baseStyle) {
    final words = (_allahWords[_language] ?? _allahWords['English']!).toList()
      ..sort((a, b) {
        final c = b.length.compareTo(a.length);
        return c != 0 ? c : a.compareTo(b);
      });

    final patterns = <String>[];
    for (final w in words) {
      final escaped = RegExp.escape(w);
      if (RegExp(r"^[a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ'\u2018\u2019]+$").hasMatch(w)) {
        patterns.add(
            "(?<![a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ])$escaped(?![a-zA-ZÀ-ÿçÇğĞıİöÖşŞüÜ])");
      } else {
        patterns.add(escaped);
      }
    }
    final allahPattern = patterns.join('|');

    return _styleRunWithAllahPattern(text, baseStyle, allahPattern);
  }

  List<TextSpan> _styleRunWithAllahPattern(
        String text, TextStyle baseStyle, String allahPattern,
        {int parenDepth = 0}) {
      final cyanStyle = baseStyle.copyWith(color: Colors.cyanAccent);
      final greenStyle = baseStyle.copyWith(color: Colors.greenAccent);
      final purpleStyle = baseStyle.copyWith(color: const Color(0xFFCB93F5));
      final amberStyle = baseStyle.copyWith(color: Colors.amber);
      final quoteStyle = baseStyle.copyWith(color: const Color(0xFFFFB6C1));

      final parenColor = parenDepth.isEven ? cyanStyle : greenStyle;

      final quotePattern = r'"(?:[^"\\]|\\.)*"' r'|\u201c(?:[^\u201d])*\u201d';
      // supports one level of nested parens: (...(...)...)
      const parenPattern = r'\((?:[^()]|\([^()]*\))*\)';
      // supports one level of nested curly braces: {...{...}...}
      const curlyPattern = r'\{(?:[^{}]|\{[^{}]*\})*\}';

      final combined = RegExp(
        '($quotePattern)' // group 1: quotes
        '|($parenPattern)' // group 2: parens (with 1 level of nesting)
        '|($curlyPattern)' // group 3: curly braces (with 1 level of nesting)
        '|(\\[[^\\]]*\\])' // group 4: brackets
        '|(?:$allahPattern)', // Allah words (unnamed)
      );

      final result = <TextSpan>[];
      int cursor = 0;
      for (final m in combined.allMatches(text)) {
        if (m.start > cursor) {
          result.add(TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
        }
        final matched = m.group(0)!;
        if (m.group(1) != null) {
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: matched[0], style: quoteStyle));
          result.addAll(_styleRunWithAllahPattern(
              inner, quoteStyle, allahPattern, parenDepth: parenDepth));
          result.add(TextSpan(text: matched[matched.length - 1], style: quoteStyle));
        } else if (m.group(2) != null) {
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '(', style: parenColor));
          result.addAll(_styleRunWithAllahPattern(
              inner, parenColor, allahPattern, parenDepth: parenDepth + 1));
          result.add(TextSpan(text: ')', style: parenColor));
        } else if (m.group(3) != null) {
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '{', style: parenColor));
          result.addAll(_styleRunWithAllahPattern(
              inner, parenColor, allahPattern, parenDepth: parenDepth + 1));
          result.add(TextSpan(text: '}', style: parenColor));
        } else if (m.group(4) != null) {
          final inner = matched.substring(1, matched.length - 1);
          result.add(TextSpan(text: '[', style: amberStyle));
          result.addAll(_styleRunWithAllahPattern(
              inner, amberStyle, allahPattern, parenDepth: parenDepth));
          result.add(TextSpan(text: ']', style: amberStyle));
        } else {
          result.add(TextSpan(text: matched, style: purpleStyle));
        }
        cursor = m.end;
      }
      if (cursor < text.length) {
        result.add(TextSpan(text: text.substring(cursor), style: baseStyle));
      }
      return result;
    }

  List<TextSpan> _highlightTerms(List<TextSpan> spans, List<String> terms) {
    if (terms.isEmpty) return spans;

    final pattern = RegExp(terms.map(RegExp.escape).join('|'), caseSensitive: false);

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

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.slash &&
            !_searchFocus.hasFocus &&
            !_excludeFocus.hasFocus) {
          _searchFocus.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildToolbar(),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.tealAccent,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final filtered = _filtered;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildHadeethFontSizeButton(),
              const SizedBox(width: 8),
              _buildSearchHistoryButton(),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search hadiths "trials of the grave"',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: InkWell(
                        onTap: _performHadeethSearch,
                        child: const Icon(Icons.search,
                            color: Colors.white38, size: 18),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white38, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchTerms = [];
                                  _recomputeSearchResults();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onSubmitted: (_) => _performHadeethSearch(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _excludeController,
                    focusNode: _excludeFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Exclude...',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.block,
                          color: Colors.white38, size: 18),
                      suffixIcon: _excludeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _excludeController.clear();
                                setState(() {
                                  _excludeTerms = [];
                                  _recomputeSearchResults();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                    onSubmitted: (v) => setState(() {
                      _excludeTerms = v
                          .trim()
                          .toLowerCase()
                          .split(RegExp(r'\s+'))
                          .where((t) => t.isNotEmpty)
                          .toList();
                      _recomputeSearchResults();
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _language,
                dropdownColor: const Color(0xFF2A2A2A),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                underline: const SizedBox(),
                isDense: true,
                items: availableHadeethLanguages
                    .map((l) =>
                        DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (l) {
                  if (l != null && l != _language) {
                    setState(() => _language = l);
                    _loadLanguage(l);
                  }
                },
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: _categoryMode
                    ? 'Switch to list view'
                    : 'Switch to category view',
                child: GestureDetector(
                  onTap: () => setState(() => _categoryMode = !_categoryMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _categoryMode
                          ? Colors.teal.withAlpha(60)
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: _categoryMode
                              ? Colors.teal
                              : Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryMode
                              ? Icons.folder_open
                              : Icons.list,
                          color:
                              _categoryMode ? Colors.tealAccent : Colors.white54,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _categoryMode ? 'Categories' : 'List',
                          style: TextStyle(
                            color: _categoryMode
                                ? Colors.tealAccent
                                : Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${filtered.length} of ${_allEntries.length} hadiths',
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }


  Widget _buildList() {
    final entries = _filtered;
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No hadiths found.',
              style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    if (_categoryMode) return _buildCategoryView(entries);

    return ListView.separated(
      controller: _hadeethScrollController,
      itemCount: entries.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (_, i) => _buildHadeethTile(entries[i]),
    );
  }

  Widget _buildCategoryView(List<HadeethEntry> entries) {
     final grouped = _groupByCategory(entries);
     final categories = grouped.keys.toList();

     return ListView.builder(
       controller: _hadeethScrollController,
       itemCount: categories.length,
       itemBuilder: (_, i) {
         final cat = categories[i];
         final items = grouped[cat]!;
         final catId = items.first.categoryId;
         final isExpanded =
             _categoryExpanded[catId] ?? _searchTerms.isNotEmpty;

         return Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             InkWell(
               onTap: () => setState(() =>
                   _categoryExpanded[catId] = !(isExpanded)),
               child: Container(
                 padding: const EdgeInsets.symmetric(
                     horizontal: 16, vertical: 10),
                 color: Colors.white.withAlpha(8),
                 child: Row(
                   children: [
                     Icon(
                       isExpanded
                           ? Icons.expand_less
                           : Icons.expand_more,
                       color: Colors.tealAccent,
                       size: 16,
                     ),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Directionality(
                         textDirection: isRtlHadeethLanguage(_language)
                             ? TextDirection.rtl
                             : TextDirection.ltr,
                         child: Text(
                           cat,
                           style: const TextStyle(
                             color: Colors.tealAccent,
                             fontSize: 13,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                       ),
                     ),
                     Text(
                       '${items.length} hadith${items.length == 1 ? '' : 's'}',
                       style: const TextStyle(
                           color: Colors.white24, fontSize: 11),
                     ),
                   ],
                 ),
               ),
             ),
             if (isExpanded)
               ...items.map((e) => _buildHadeethTile(e, indent: true)),
             const Divider(color: Colors.white12, height: 1),
           ],
         );
       },
     );
   }

  Widget _buildHadeethTile(HadeethEntry entry, {bool indent = false}) {
    final isExpanded = _expandedIds.contains(entry.id) || _searchTerms.isNotEmpty;
    final isRtl = isRtlHadeethLanguage(_language);
    final textDir = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (_expandedIds.contains(entry.id)) {
              _expandedIds.remove(entry.id);
            } else {
              _expandedIds.add(entry.id);
            }
          }),
          child: Directionality(
            textDirection: textDir,
            child: Padding(
              padding: EdgeInsets.only(
                left: indent ? 32 : 16,
                right: 16,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: _highlightTerms(
                              _colorParensAndAllah(
                                entry.title,
                                TextStyle(
                                  color: Colors.white,
                                  fontSize: _hadeethFontSize,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                              _searchTerms,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (!_categoryMode)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withAlpha(30),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                      color: Colors.teal.withAlpha(80)),
                                ),
                                child: Text(
                                  entry.category,
                                  style: const TextStyle(
                                      color: Colors.tealAccent, fontSize: 10),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _gradeColor(entry.grade).withAlpha(20),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                    color:
                                        _gradeColor(entry.grade).withAlpha(80)),
                              ),
                              child: Text(
                                entry.grade,
                                style: TextStyle(
                                    color: _gradeColor(entry.grade),
                                    fontSize: 10),
                              ),
                            ),
                            Text(
                              entry.attribution,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10),
                            ),
                            const SizedBox(width: 6),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '#${entry.id}',
                                    style: const TextStyle(color: Colors.orange, fontSize: 10),
                                  ),
                                  if (_searchScores.containsKey(entry.id))
                                    TextSpan(
                                      text: ' (score ${_searchScores[entry.id]!.toStringAsFixed(1)})',
                                      style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded) _buildHadeethDetail(entry, indent: indent),
        if (!indent) const Divider(color: Colors.white10, height: 1),
      ],
    );
  }

  Widget _buildHadeethDetail(HadeethEntry entry, {bool indent = false}) {
    final isRtl = isRtlHadeethLanguage(_language);
    final textDir = isRtl ? TextDirection.rtl : TextDirection.ltr;

    return Directionality(
      textDirection: textDir,
      child: Container(
        margin: EdgeInsets.only(
          left: indent ? 32 : 16,
          right: 16,
          bottom: 10,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailSection(
              icon: Icons.format_quote,
              iconColor: Colors.orangeAccent,
              label: 'Hadith',
              text: entry.hadeeth,
              isRtl: isRtl,
            ),
            if (entry.explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),
              _detailSection(
                icon: Icons.lightbulb_outline,
                iconColor: Colors.lightBlueAccent,
                label: 'Explanation',
                text: entry.explanation,
                isRtl: isRtl,
                // textColor: Colors.amber,
              ),
            ],
            if (entry.hints.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              Row(
                textDirection: textDir,
                children: [
                  const Icon(Icons.tips_and_updates_outlined,
                      color: Colors.deepPurpleAccent, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Benefits',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...entry.hints.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: textDir,
                      children: [
                        Text(
                          isRtl ? '• ' : '• ',
                          style: const TextStyle(
                              color: Colors.deepPurpleAccent, fontSize: 13),
                        ),
                        Expanded(
                          child: SelectableText.rich(
                            TextSpan(
                              children: _highlightTerms(
                                _colorParensAndAllah(
                                  h,
                                  TextStyle(
                                    // color: Colors.greenAccent,
                                    fontSize: _hadeethFontSize,
                                    height: 1.5,
                                  ),
                                ),
                                _searchTerms,
                              ),
                            ),
                            textDirection: textDir,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.copy, color: Colors.white24, size: 14),
                tooltip: 'Copy hadith',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: [
                      entry.hadeeth,
                      if (entry.explanation.isNotEmpty)
                        '\nExplanation:\n${entry.explanation}',
                      if (entry.hints.isNotEmpty)
                        '\nBenefits:\n${entry.hints.map((h) => '• $h').join('\n')}',
                      '\n${entry.attribution} #${entry.id}',
                    ].join('\n'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String text,
    bool isRtl = false,
    Color textColor = Colors.white,
  }) {
    final baseStyle = TextStyle(color: textColor, fontSize: _hadeethFontSize, height: 1.6);
    final spans = _highlightTerms(
      _colorParensAndAllah(text, baseStyle),
      _searchTerms,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        SelectableText.rich(
          TextSpan(children: spans),
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        ),
      ],
    );
  }
}
