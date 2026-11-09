import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../quiz/deduction_model.dart';
import '../quiz/deduction_strings.dart';
import '../quiz/daily_quiz_index.dart';
import '../quran/quran_index.dart';
import '../services/allah_highlighter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class DeductionQuizPanel extends StatefulWidget {
  final bool isQuranLoaded;
  final Function(QuranVerseRef, int)? onVerseSelected;
  final Function(String ref)? onLoadTafsirRef;

  const DeductionQuizPanel({
    super.key,
    required this.isQuranLoaded,
    this.onVerseSelected,
    this.onLoadTafsirRef,
  });

  @override
  State<DeductionQuizPanel> createState() => _DeductionQuizPanelState();
}

class _DeductionQuizPanelState extends State<DeductionQuizPanel> {
  List<DailyQuizEntry> _entries = [];
  DateTime? _selectedDate;
  DeductionData? _data;
  bool _loadingList = true;
  bool _loadingDay = false;

  final ItemScrollController _entryScrollController = ItemScrollController();

  final Map<String, String> _selections = {};
  bool _showArabic = false;
  int _revealedHints = 0;

  // --- Languages ---
  // Assets live in assets/deduction_<Language>/<date>.<Language>.json (plus the
  // English source in assets/deduction_all/<date>.json). The set of languages
  // available for each date is discovered from the asset manifest.
  static const String _defaultLanguage = 'English';
  static const String _languagePrefKey = 'deduction_language';
  Map<String, Set<String>> _languagesByDate = {};
  String _preferredLanguage = _defaultLanguage; // remembered choice
  String _activeLanguage = _defaultLanguage;    // what is shown right now
  DeductionData? _englishData; // used to keep saved guesses language-independent

  // Titles for the left-hand list in the chosen language (date -> title).
  // Dates without a translation fall back to the English title from DailyQuizEntry.
  final Map<String, Map<String, String>> _titleCache = {}; // language -> titles
  Map<String, String> _titles = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  static const List<Color> _categoryColors = [
    Colors.amber,
    Colors.green,
    Colors.lightBlueAccent,
    Color(0xFFCB93F5),
  ];

  Color _categoryColor(int index) => _categoryColors[index % _categoryColors.length];

  Future<void> _loadLanguageIndex() async {
    final map = <String, Set<String>>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final perLanguage =
          RegExp(r'^assets/deduction_([^/]+)/(\d{4}-\d{2}-\d{2})\.(.+)\.json$');
      final englishSource = RegExp(r'^assets/deduction_all/(\d{4}-\d{2}-\d{2})\.json$');
      for (final path in manifest.listAssets()) {
        final a = englishSource.firstMatch(path);
        if (a != null) {
          map.putIfAbsent(a.group(1)!, () => {}).add(_defaultLanguage);
          continue;
        }
        final m = perLanguage.firstMatch(path);
        // English always comes from deduction_all, never a per-language folder.
        if (m != null && m.group(1) == m.group(3) && m.group(1) != _defaultLanguage) {
          map.putIfAbsent(m.group(2)!, () => {}).add(m.group(1)!);
        }
      }
    } catch (_) {
      // No manifest / unreadable: fall back to English only.
    }
    _languagesByDate = map;
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferredLanguage = prefs.getString(_languagePrefKey) ?? _defaultLanguage;
    } catch (_) {}
  }

  List<String> _languagesFor(DateTime date) {
    final others = (_languagesByDate[_fmtDate(date)] ?? <String>{})
        .where((l) => l != _defaultLanguage)
        .toList()
      ..sort();
    return [_defaultLanguage, ...others];
  }

  String _languageLabel(String l) => l.replaceAll('_', ' ');

  Future<DeductionData?> _loadLanguage(DateTime date, String lang) async {
    final d = _fmtDate(date);
    final paths = lang == _defaultLanguage
        ? ['assets/deduction_all/$d.json']
        : ['assets/deduction_$lang/$d.$lang.json'];
    for (final p in paths) {
      try {
        final decoded = jsonDecode(await rootBundle.loadString(p));
        if (decoded is Map<String, dynamic>) {
          // Extracted files hold just the deduction object; the model expects
          // the full day structure, so re-wrap it.
          final parsed = DeductionData.tryParse({'deduction': decoded});
          if (parsed != null) return parsed;
        }
      } catch (_) {
        // try next path
      }
    }
    if (lang == _defaultLanguage) {
      // Legacy: pull English straight from the daily quiz file.
      try {
        return DeductionData.tryParse(await DailyQuizIndex.loadDay(date));
      } catch (_) {}
    }
    return null;
  }

  DeductionCategory? _catByKey(DeductionData? d, String key) =>
      d?.categories.where((c) => c.key == key).firstOrNull;

  /// Maps an option from one language to the same-position option in another.
  /// Uses the file order (originalOptions), since displayed options are shuffled.
  String? _convertOption(DeductionCategory? from, DeductionCategory? to, String option) {
    if (from == null || to == null) return null;
    final i = from.originalOptions.indexOf(option);
    if (i < 0 || i >= to.originalOptions.length) return null;
    return to.originalOptions[i];
  }

  /// Guesses are saved in English so they survive language switches.
  Map<String, String> _selectionsForSave() {
    final out = <String, String>{};
    _selections.forEach((key, value) {
      if (_activeLanguage == _defaultLanguage) {
        out[key] = value;
        return;
      }
      final eng = _convertOption(_catByKey(_data, key), _catByKey(_englishData, key), value);
      if (eng != null) out[key] = eng;
    });
    return out;
  }

  Future<void> _loadTitles(String lang) async {
    if (lang == _defaultLanguage) {
      if (mounted) setState(() => _titles = {});
      return;
    }
    var titles = _titleCache[lang];
    if (titles == null) {
      final loaded = <String, String>{};
      await Future.wait(_entries.map((e) async {
        final d = _fmtDate(e.date);
        if (!(_languagesByDate[d]?.contains(lang) ?? false)) return;
        try {
          final decoded =
              jsonDecode(await rootBundle.loadString('assets/deduction_$lang/$d.$lang.json'));
          final t = decoded is Map ? decoded['title'] : null;
          if (t is String && t.trim().isNotEmpty) loaded[d] = t;
        } catch (_) {}
      }));
      titles = loaded;
      _titleCache[lang] = titles;
    }
    // Ignore if the user switched language again while this was loading.
    if (!mounted || lang != _preferredLanguage) return;
    setState(() => _titles = titles!);
  }

  Future<void> _changeLanguage(String lang) async {
    final date = _selectedDate;
    if (date == null || lang == _activeLanguage) return;
    final newData = (lang == _defaultLanguage ? _englishData : null) ??
        await _loadLanguage(date, lang);
    if (newData == null || !mounted) return;
    final old = _data;
    setState(() {
      final remapped = <String, String>{};
      _selections.forEach((key, value) {
        final m = _convertOption(_catByKey(old, key), _catByKey(newData, key), value);
        if (m != null) remapped[key] = m;
      });
      _selections
        ..clear()
        ..addAll(remapped);
      _data = newData;
      _activeLanguage = lang;
      _preferredLanguage = lang;
    });
    _loadTitles(lang);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePrefKey, lang);
    } catch (_) {}
  }

  Future<void> _init() async {
    await _loadLanguageIndex();
    final entries = await DailyQuizIndex.availableEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loadingList = false;
    });
    if (entries.isEmpty) return;
    _loadTitles(_preferredLanguage); // fire and forget; list shows English meanwhile

    final lastDate = await DailyQuizPrefs.loadLastDate();
    final resumeEntry = lastDate != null
        ? entries.where((e) => _sameDay(e.date, lastDate)).firstOrNull
        : null;
    await _selectDate((resumeEntry ?? entries.first).date);
    _scrollToSelectedEntry();
  }

  void _scrollToSelectedEntry() {
    if (_selectedDate == null) return;
    final index = _entries.indexWhere((e) => _sameDay(e.date, _selectedDate!));
    if (index == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entryScrollController.isAttached) {
        _entryScrollController.jumpTo(index: index);
      }
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _loadingDay = true;
      _selectedDate = date;
      _data = null;
      _selections.clear();
      _revealedHints = 0;
    });
    try {
      final english = await _loadLanguage(date, _defaultLanguage);
      final wanted = _languagesFor(date).contains(_preferredLanguage)
          ? _preferredLanguage
          : _defaultLanguage;
      var shown = wanted;
      DeductionData? data;
      if (wanted == _defaultLanguage) {
        data = english;
      } else {
        data = await _loadLanguage(date, wanted);
        if (data == null) {
          data = english;
          shown = _defaultLanguage;
        }
      }
      if (!mounted) return;
      setState(() {
        _englishData = english;
        _data = data;
        _activeLanguage = shown;
        _loadingDay = false;
      });
      if (data != null) {
        // Saved guesses are stored in English; convert to the language on screen.
        final saved = await QuizSelectionPrefs.loadSelections(date);
        if (saved != null && mounted) {
          setState(() {
            for (final cat in data!.categories) {
              final englishAnswer = saved[cat.key];
              if (englishAnswer == null) continue;
              final answer = shown == _defaultLanguage
                  ? englishAnswer
                  : _convertOption(_catByKey(english, cat.key), cat, englishAnswer);
              if (answer != null) _selections[cat.key] = answer;
            }
          });
        }
      }
      await DailyQuizPrefs.saveLastDate(date);
      _scrollToSelectedEntry();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDay = false);
    }
  }

  void _clearGuesses() {
    setState(() {
      _selections.clear();
      _revealedHints = 0;
    });
    if (_selectedDate != null) {
      QuizSelectionPrefs.clearSelections(_selectedDate!);
    }
  }

  void _selectOption(String categoryKey, String option) {
    setState(() => _selections[categoryKey] = option);
    if (_selectedDate != null) {
      QuizSelectionPrefs.saveSelections(_selectedDate!, _selectionsForSave());
    }
  }

  bool get _allAnswered =>
      _data != null && _data!.categories.every((c) => _selections[c.key] != null);

  bool get _allCorrect =>
      _data != null &&
      _data!.categories.every((c) => _selections[c.key] == c.answer);

      void _onVerseTapped() {
        final ref = _data?.verseRef;
        if (ref == null || widget.onVerseSelected == null || !widget.isQuranLoaded) {
          return;
        }
        final m = RegExp(r'(\d+):(\d+)(?:-(\d+))?').firstMatch(ref);
        if (m == null) return;
        final surah = int.parse(m.group(1)!);
        final fromAyah = int.parse(m.group(2)!);
        final toAyah = m.group(3) != null ? int.parse(m.group(3)!) : fromAyah;
        widget.onVerseSelected!(
          QuranVerseRef(surah: surah, fromAyah: fromAyah, toAyah: toAyah, isFullSurah: false),
          0,
        );
      }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('No quiz files found', style: TextStyle(color: Colors.white38)),
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: _buildEntryList(),
        ),
        Container(width: 1, color: Colors.white12),
        Expanded(
          child: _loadingDay
              ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
              : _data == null
                  ? Center(
                      child: Text(DeductionStrings.noPuzzle(_activeLanguage),
                          style: const TextStyle(color: Colors.white38)))
                  : _buildQuiz(),
        ),
      ],
    );
  }

  Widget _buildEntryList() {
    return ScrollablePositionedList.builder(
      itemScrollController: _entryScrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];
        final isSelected = _selectedDate != null && _sameDay(e.date, _selectedDate!);
        final title = _titles[_fmtDate(e.date)] ?? e.title;
        // Only flip layout when this row's title really is in the RTL language.
        final rtl = _titles.containsKey(_fmtDate(e.date)) &&
            _isRtlLanguage(_preferredLanguage);
        return InkWell(
          onTap: () => _selectDate(e.date),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isSelected ? Colors.deepPurple.withAlpha(60) : null,
            child: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fmtDate(e.date),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: isSelected ? Colors.purple[200] : Colors.white38,
                        fontSize: 11,
                      )),
                  const SizedBox(height: 2),
                  Text(title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHintsSection(DeductionData data) {
    final total = data.clues.length;
    final revealAll = _allCorrect;
    final revealedCount = revealAll ? total : _revealedHints;
    final hasMore = revealedCount < total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMore && !revealAll)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => setState(() => _revealedHints++),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple[200],
                side: BorderSide(color: Colors.deepPurple.withAlpha(160)),
              ),
              child: Text(DeductionStrings.revealHint(
                  _activeLanguage, revealedCount + 1, total)),
            ),
          ),
        for (int i = 0; i < revealedCount; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.deepPurple,
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(data.clues[i],
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        if (revealAll)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              DeductionStrings.hintsUsed(_activeLanguage, _revealedHints),
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
      ],
    );
  }

  // Languages written right-to-left. Reuses the app-wide set and adds the two
  // translation names it doesn't cover (Kurdish_Sorani, Yiddish).
  bool _isRtlLanguage(String lang) =>
      isRtlQuranLanguage(lang) ||
      lang == 'Kurdish_Sorani' ||
      lang == 'Yiddish' ||
      lang == 'Dhivehi';

  Widget _buildQuiz() {
    return Directionality(
      textDirection:
          _isRtlLanguage(_activeLanguage) ? TextDirection.rtl : TextDirection.ltr,
      child: _buildQuizContent(),
    );
  }

  Widget _buildQuizContent() {
    final data = _data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(data.title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            _buildLanguagePicker(),
            if (_selections.isNotEmpty)
              TextButton.icon(
                onPressed: _clearGuesses,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                label: Text(DeductionStrings.clearGuesses(_activeLanguage),
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(data.intro, style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 16),
        _buildHintsSection(data),
        if (_allCorrect) _buildVerseReveal(data),
        const SizedBox(height: 16),
        ...data.categories
            .asMap()
            .entries
            .map((e) => _buildCategory(e.value, _categoryColor(e.key))),
      ],
    );
  }

  Widget _buildLanguagePicker() {
    final date = _selectedDate;
    if (date == null) return const SizedBox.shrink();
    final langs = _languagesFor(date);
    if (langs.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: DropdownButton<String>(
        value: langs.contains(_activeLanguage) ? _activeLanguage : _defaultLanguage,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: const Color(0xFF2A2A2A),
        icon: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.language, size: 16, color: Colors.white54),
        ),
        style: const TextStyle(color: Colors.white70, fontSize: 12),
        items: [
          for (final l in langs)
            DropdownMenuItem<String>(value: l, child: Text(_languageLabel(l))),
        ],
        onChanged: (l) {
          if (l != null) _changeLanguage(l);
        },
      ),
    );
  }

  Widget _buildCategory(DeductionCategory cat, Color themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cat.label.toUpperCase(),
              style: TextStyle(
                  color: themeColor, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cat.options.map((opt) {
              final currentSelection = _selections[cat.key];
              final isSelected = currentSelection == opt;
              final reveal = _allAnswered;
              final isLockedCorrect = reveal && currentSelection == cat.answer;

              Color bg = themeColor.withAlpha(20);
              Color border = themeColor.withAlpha(140);
              Color text = themeColor;

              if (!reveal) {
                if (isSelected) {
                  bg = Colors.deepPurple.withAlpha(80);
                  border = Colors.deepPurple;
                  text = Colors.white;
                }
              } else {
                if (isSelected && opt == cat.answer) {
                  bg = Colors.green.withAlpha(60);
                  border = Colors.greenAccent;
                  text = Colors.greenAccent;
                } else if (isSelected) {
                  bg = Colors.red.withAlpha(60);
                  border = Colors.redAccent;
                  text = Colors.redAccent;
                }
                // unselected options stay themed — never reveal the answer
              }

              return GestureDetector(
                onTap: isLockedCorrect
                    ? null
                    : () => _selectOption(cat.key, opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Text(opt, style: TextStyle(color: text, fontSize: 13)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseReveal(DeductionData data) {
        final canNavigate =
            data.verseRef != null && widget.isQuranLoaded && widget.onVerseSelected != null;
        final canLoadTafsir = data.verseRef != null && widget.onLoadTafsirRef != null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.greenAccent.withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text.rich(
                    TextSpan(
                      children: AllahHighlighter.spans(
                        data.verseArabic,
                        const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
                        isArabic: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: AllahHighlighter.spans(
                      data.verseEn,
                      const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                    ),
                  ),
                ),
                if (data.verseRef != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: canNavigate
                        ? _onVerseTapped
                        : (canLoadTafsir
                            ? () => widget.onLoadTafsirRef!(data.verseRef!)
                            : null),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canNavigate) ...[
                          const Icon(
                            Icons.play_circle_outline,
                            size: 14,
                            color: Colors.lightBlueAccent,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          data.verseRef!,
                          style: TextStyle(
                            color: canNavigate
                                ? Colors.lightBlueAccent
                                : (canLoadTafsir ? Colors.amber : Colors.white38),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!canNavigate) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message:
                                'Load a Quran Verse by Verse audiobook to navigate to this verse',
                            preferBelow: true,
                            textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }
}
