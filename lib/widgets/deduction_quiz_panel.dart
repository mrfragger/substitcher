import 'package:flutter/material.dart';
import '../quiz/deduction_model.dart';
import '../quiz/daily_quiz_index.dart';
import '../quran/quran_index.dart';
import '../services/allah_highlighter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class DeductionQuizPanel extends StatefulWidget {
  final bool isQuranLoaded;
  final Function(QuranVerseRef, int)? onVerseSelected;

  const DeductionQuizPanel({
    super.key,
    required this.isQuranLoaded,
    this.onVerseSelected,
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

  Future<void> _init() async {
    final entries = await DailyQuizIndex.availableEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loadingList = false;
    });
    if (entries.isEmpty) return;

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
      final dayJson = await DailyQuizIndex.loadDay(date);
      final data = DeductionData.tryParse(dayJson);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loadingDay = false;
      });
      if (data != null) {
        final saved = await QuizSelectionPrefs.loadSelections(date);
        if (saved != null && mounted) {
          setState(() {
            for (final cat in data.categories) {
              final answer = saved[cat.key];
              if (answer != null) {
                _selections[cat.key] = answer;
              }
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
      QuizSelectionPrefs.saveSelections(
          _selectedDate!, Map<String, String>.from(_selections));
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
                  ? const Center(
                      child: Text('No deduction puzzle for this day',
                          style: TextStyle(color: Colors.white38)))
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
        return InkWell(
          onTap: () => _selectDate(e.date),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isSelected ? Colors.deepPurple.withAlpha(60) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtDate(e.date),
                    style: TextStyle(
                      color: isSelected ? Colors.purple[200] : Colors.white38,
                      fontSize: 11,
                    )),
                const SizedBox(height: 2),
                Text(e.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
              ],
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
              child: Text('Reveal Hint ${revealedCount + 1} of $total'),
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
              '$_revealedHints hint${_revealedHints == 1 ? '' : 's'} used',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildQuiz() {
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
            if (_selections.isNotEmpty)
              TextButton.icon(
                onPressed: _clearGuesses,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                label: const Text('Clear Guesses',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(data.intro, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
                    const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                  ),
                ),
              ),
              if (data.verseRef != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: canNavigate ? _onVerseTapped : null,
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
                          color: canNavigate ? Colors.lightBlueAccent : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!canNavigate)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('Load a Quran Verse by Verse audiobook to navigate to this verse',
                        style: TextStyle(color: Colors.white24, fontSize: 11)),
                  ),
              ],
            ],
          ),
        ),
      );
    }
}
