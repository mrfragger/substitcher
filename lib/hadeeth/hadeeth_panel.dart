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
  }

  @override
  void dispose() {
    if (_searchFocus.hasFocus || _excludeFocus.hasFocus) {
      _searchFocus.unfocus();
      _excludeFocus.unfocus();
    }
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
        });
      }
    });
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

  List<HadeethEntry> get _filtered {
    if (_searchTerms.isEmpty && _excludeTerms.isEmpty) return _allEntries;
    return _allEntries.where(_entryMatches).toList();
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

    final combined = RegExp(
      '($quotePattern)' // group 1: quotes
      '|($parenPattern)' // group 2: parens (with 1 level of nesting)
      '|(\\[[^\\]]*\\])' // group 3: brackets
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
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.tealAccent,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            _buildList(),
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
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search hadiths (Enter to search)...',
                      hintStyle:
                          const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.search,
                          color: Colors.white38, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white38, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchTerms = []);
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
                      _searchTerms = v
                          .trim()
                          .toLowerCase()
                          .split(RegExp(r'\s+'))
                          .where((t) => t.isNotEmpty)
                          .toList();
                      if (_searchTerms.isNotEmpty) {
                        _categoryExpanded.clear();
                      }
                    }),
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
                              icon: const Icon(Icons.clear,
                                  color: Colors.white38, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _excludeController.clear();
                                setState(() => _excludeTerms = []);
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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
                            Text(
                              '#${entry.id}',
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 10),
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
                textColor: Colors.amber,
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
                                  const TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 13,
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
    final baseStyle = TextStyle(color: textColor, fontSize: 13, height: 1.6);
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
