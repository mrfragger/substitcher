import 'package:flutter/material.dart';
import '../quiz/connections_model.dart';
import '../quiz/daily_quiz_index.dart';
import '../quiz/harf_model.dart';
import '../quran/quran_index.dart';
import '../services/allah_highlighter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class _PoolEntry {
  final int categoryIndex;
  final int itemIndex;
  final ConnectionItem item;
  _PoolEntry({
    required this.categoryIndex,
    required this.itemIndex,
    required this.item,
  });
  String get key => '$categoryIndex:$itemIndex';
}

class RelatedConnectionsPanel extends StatefulWidget {
  final bool isQuranLoaded;
  final Function(QuranVerseRef, int)? onVerseSelected;
  final Function(String ref)? onLoadTafsirRef;

  const RelatedConnectionsPanel({
    super.key,
    required this.isQuranLoaded,
    this.onVerseSelected,
    this.onLoadTafsirRef,
  });

  @override
  State<RelatedConnectionsPanel> createState() => _RelatedConnectionsPanelState();
}

class _RelatedConnectionsPanelState extends State<RelatedConnectionsPanel> {
  List<ConnectionsEntry> _entries = [];
  DateTime? _selectedDate;
  ConnectionsData? _data;
  ScrambleData? _scramble;
  HarfData? _harf;
  Set<int> _harfRevealed = {};
  bool _loadingList = true;
  bool _loadingDay = false;

  final ItemScrollController _entryScrollController = ItemScrollController();
  final ScrollController _contentScrollController = ScrollController();

  String? _activeCategoryName;
  ConnectionItem? _activeItem;

  // --- connections game state ---
  Set<String> _solvedKeys = {};
  List<_PoolEntry> _pool = [];
  Set<String> _wrongFlashKeys = {};

  // --- scramble game state ---
  int _scrambleSolvedCount = 0;
  List<int> _scramblePool = [];
  Set<int> _scrambleWrongFlash = {};

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  bool get _scrambleGameActive =>
      _scramble != null &&
      _scramble!.words.isNotEmpty &&
      _scramble!.words.length == _scramble!.translations.length;

  Future<void> _init() async {
    final entries = await ConnectionsIndex.availableEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loadingList = false;
    });
    if (entries.isEmpty) return;

    final lastDate = await ConnectionsPrefs.loadLastDate();
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
      _scramble = null;
      _activeCategoryName = null;
      _activeItem = null;
      _solvedKeys = {};
      _pool = [];
      _wrongFlashKeys = {};
      _scrambleSolvedCount = 0;
      _scramblePool = [];
      _scrambleWrongFlash = {};
      _harfRevealed = {};
    });
    try {
      final dayJson = await DailyQuizIndex.loadDay(date);
      final data = ConnectionsData.tryParse(dayJson);
      final scramble = ScrambleData.tryParse(dayJson);
      final harf = HarfData.tryParse(dayJson);
      if (!mounted) return;
      setState(() {
        _data = data;
        _scramble = scramble;
        _harf = harf;
        _loadingDay = false;
      });
      if (data != null) {
        final solved = await ConnectionsGamePrefs.loadSolved(date);
        _initGame(data, solved);

        final saved = await ConnectionsSelectionPrefs.loadSelection(date);
        if (saved != null) {
          for (int c = 0; c < data.categories.length; c++) {
            final cat = data.categories[c];
            for (int i = 0; i < cat.items.length; i++) {
              final item = cat.items[i];
              if (item.ref == saved && solved.contains('$c:$i')) {
                if (mounted) {
                  setState(() {
                    _activeCategoryName = cat.name;
                    _activeItem = item;
                  });
                }
                break;
              }
            }
          }
        }
      }
      if (scramble != null &&
          scramble.words.isNotEmpty &&
          scramble.words.length == scramble.translations.length) {
        final solvedCount = await ScrambleGamePrefs.loadSolvedCount(date);
        _initScrambleGame(scramble, solvedCount.clamp(0, scramble.words.length));
      }
      await ConnectionsPrefs.saveLastDate(date);
      _scrollToSelectedEntry();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDay = false);
    }
  }

  void _initGame(ConnectionsData data, Set<String> solved) {
    final pool = <_PoolEntry>[];
    for (int c = 0; c < data.categories.length; c++) {
      final cat = data.categories[c];
      for (int i = 0; i < cat.items.length; i++) {
        final key = '$c:$i';
        if (!solved.contains(key)) {
          pool.add(_PoolEntry(categoryIndex: c, itemIndex: i, item: cat.items[i]));
        }
      }
    }
    pool.shuffle();
    if (!mounted) return;
    setState(() {
      _solvedKeys = solved;
      _pool = pool;
    });
  }

  void _initScrambleGame(ScrambleData scramble, int solvedCount) {
    final pool = <int>[];
    for (int i = solvedCount; i < scramble.words.length; i++) {
      pool.add(i);
    }
    pool.shuffle();
    if (!mounted) return;
    setState(() {
      _scrambleSolvedCount = solvedCount;
      _scramblePool = pool;
      _scrambleWrongFlash = {};
    });
  }

  /// First category (in file order) that isn't fully solved yet. Null once
  /// every category is complete. Guessing is locked to this category —
  /// tapping a pool item from a different, not-yet-reached category always
  /// counts as wrong, even if it happens to be correct for its own category.
  int? get _activeCategoryIndex {
    if (_data == null) return null;
    for (int c = 0; c < _data!.categories.length; c++) {
      final cat = _data!.categories[c];
      final done = List.generate(cat.items.length, (i) => '$c:$i')
          .every(_solvedKeys.contains);
      if (!done) return c;
    }
    return null;
  }

  void _guess(_PoolEntry entry) {
    final active = _activeCategoryIndex;
    if (active == null) return;

    if (entry.categoryIndex == active) {
      setState(() {
        _solvedKeys = {..._solvedKeys, entry.key};
        _pool = _pool.where((e) => e.key != entry.key).toList();
      });
      if (_selectedDate != null) {
        ConnectionsGamePrefs.saveSolved(_selectedDate!, _solvedKeys);
      }
    } else {
      setState(() => _wrongFlashKeys = {..._wrongFlashKeys, entry.key});
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() {
          _wrongFlashKeys = {..._wrongFlashKeys}..remove(entry.key);
        });
      });
    }
  }

  void _guessScramble(int wordIndex) {
    if (!_scrambleGameActive) return;
    if (wordIndex == _scrambleSolvedCount) {
      setState(() {
        _scrambleSolvedCount++;
        _scramblePool = _scramblePool.where((i) => i != wordIndex).toList();
      });
      if (_selectedDate != null) {
        ScrambleGamePrefs.saveSolvedCount(_selectedDate!, _scrambleSolvedCount);
      }
    } else {
      setState(() => _scrambleWrongFlash = {..._scrambleWrongFlash, wordIndex});
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        setState(() {
          _scrambleWrongFlash = {..._scrambleWrongFlash}..remove(wordIndex);
        });
      });
    }
  }

  void _resetGame() {
    if (_data != null) {
      setState(() {
        _solvedKeys = {};
        _activeCategoryName = null;
        _activeItem = null;
        _wrongFlashKeys = {};
      });
      _initGame(_data!, {});
      if (_selectedDate != null) {
        ConnectionsGamePrefs.clearSolved(_selectedDate!);
        ConnectionsSelectionPrefs.saveSelection(_selectedDate!, '');
      }
    }
    if (_scrambleGameActive) {
      _initScrambleGame(_scramble!, 0);
      if (_selectedDate != null) {
        ScrambleGamePrefs.clearSolvedCount(_selectedDate!);
      }
    }
  }

  void _solveAll() {
    if (_data != null) {
      final allKeys = <String>{};
      for (int c = 0; c < _data!.categories.length; c++) {
        for (int i = 0; i < _data!.categories[c].items.length; i++) {
          allKeys.add('$c:$i');
        }
      }
      setState(() {
        _solvedKeys = allKeys;
        _pool = [];
        _wrongFlashKeys = {};
      });
      if (_selectedDate != null) {
        ConnectionsGamePrefs.saveSolved(_selectedDate!, _solvedKeys);
      }
    }
    if (_scrambleGameActive) {
      setState(() {
        _scrambleSolvedCount = _scramble!.words.length;
        _scramblePool = [];
        _scrambleWrongFlash = {};
      });
      if (_selectedDate != null) {
        ScrambleGamePrefs.saveSolvedCount(_selectedDate!, _scrambleSolvedCount);
      }
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _playRef(String? ref) {
    if (ref == null || ref.isEmpty) return;
    if (widget.onVerseSelected == null || !widget.isQuranLoaded) return;
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

  @override
  Widget build(BuildContext context) {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('No related-words puzzles found', style: TextStyle(color: Colors.white38)),
      );
    }
    return Row(
      children: [
        SizedBox(width: 260, child: _buildEntryList()),
        Container(width: 1, color: Colors.white12),
        Expanded(
          child: _loadingDay
              ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
              : _data == null
                  ? const Center(
                      child: Text('No related-words puzzle for this day',
                          style: TextStyle(color: Colors.white38)))
                  : _buildContent(),
        ),
      ],
    );
  }

  Color _colorForName(String colorName) {
    switch (colorName) {
      case 'yellow':
        return Colors.amber;
      case 'green':
        return Colors.greenAccent;
      case 'blue':
        return Colors.lightBlueAccent;
      case 'purple':
        return const Color(0xFFCB93F5);
      default:
        return Colors.white70;
    }
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
                Text(
                  _fmtDate(e.date),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white38,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 4),
                for (final cat in e.categories) ...[
                  Text(
                    cat.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _colorForName(cat.colorName),
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadTafsirPrompt() {
    return Tooltip(
      message: 'Load a Quran Verse by Verse audiobook to navigate to this verse',
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
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final connectionsUnsolved = _pool.isNotEmpty;
    final scrambleUnsolved =
        _scrambleGameActive && _scrambleSolvedCount < _scramble!.words.length;
    final connectionsProgress = _solvedKeys.isNotEmpty;
    final scrambleProgress = _scrambleGameActive && _scrambleSolvedCount > 0;

    return ListView(
      controller: _contentScrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Match each term to its category',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            if (connectionsUnsolved || scrambleUnsolved)
              TextButton.icon(
                onPressed: _solveAll,
                icon: const Icon(Icons.visibility, size: 16, color: Colors.white54),
                label: const Text('Solve', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            if (connectionsProgress || scrambleProgress)
              TextButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                label: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...data.categories.asMap().entries.map((e) => _buildCategorySlot(e.key, e.value)),
        if (connectionsUnsolved) _buildPool(),
        if (_scramble != null) _buildScrambleCard(_scramble!),
        if (_harf != null)
          ..._harf!.items.asMap().entries.map(
            (e) => _buildHarfCard(e.value, e.key),
          ),
      ],
    );
  }

  Widget _buildCategorySlot(int index, ConnectionCategory cat) {
    final solvedItems = <ConnectionItem>[];
    for (int i = 0; i < cat.items.length; i++) {
      if (_solvedKeys.contains('$index:$i')) solvedItems.add(cat.items[i]);
    }
    final isFullySolved = solvedItems.length == cat.items.length;
    final isActive = _activeCategoryIndex == index;

    if (!isFullySolved && !isActive) {
      // Locked — not reached yet, no spoilers.
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 16, color: Colors.white24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(cat.nameEn,
                  style: const TextStyle(color: Colors.white24, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
    }

    final canNavigate = widget.isQuranLoaded && widget.onVerseSelected != null;
    final isActiveCategoryForVerse = _activeCategoryName == cat.name;
    final activeItemHere = isActiveCategoryForVerse ? _activeItem : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cat.color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cat.color.withAlpha(isFullySolved ? 120 : 200),
          width: isFullySolved ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(cat.name,
                style: TextStyle(color: cat.color, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 2),
          Text(cat.nameEn,
              style: TextStyle(color: cat.color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 12),
          if (solvedItems.isEmpty)
            Text(
              'Find the ${cat.items.length} matching terms below',
              style: TextStyle(color: cat.color.withAlpha(150), fontSize: 12, fontStyle: FontStyle.italic),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: solvedItems.map((item) {
                final isSelected = activeItemHere == item;
                return _buildItemColumn(cat, item, isSelected, canNavigate);
              }).toList(),
            ),
          if (activeItemHere != null) ...[
            const SizedBox(height: 12),
            _buildVerseCard(activeItemHere, canNavigate),
          ],
        ],
      ),
    );
  }

  Widget _buildPool() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: _pool.map((entry) => _buildPoolItem(entry)).toList(),
      ),
    );
  }

  Widget _buildPoolItem(_PoolEntry entry) {
    final isWrong = _wrongFlashKeys.contains(entry.key);
    final color = isWrong ? Colors.redAccent : Colors.white70;
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(entry.item.ar,
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 24)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _guess(entry),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isWrong ? Colors.redAccent.withAlpha(40) : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isWrong ? Colors.redAccent : Colors.white38),
              ),
              child: Text(entry.item.en,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemColumn(
      ConnectionCategory cat, ConnectionItem item, bool isSelected, bool canNavigate) {
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(item.ar,
                textAlign: TextAlign.center,
                style: TextStyle(color: cat.color, fontSize: 24)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _activeCategoryName = cat.name;
                _activeItem = item;
              });
              if (_selectedDate != null) {
                ConnectionsSelectionPrefs.saveSelection(_selectedDate!, item.ref);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? cat.color.withAlpha(70) : cat.color.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: cat.color.withAlpha(isSelected ? 255 : 140),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(item.en,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cat.color,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseCard(ConnectionItem item, bool canNavigate) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text.rich(
              TextSpan(
                children: AllahHighlighter.spans(
                  item.verseArabic,
                  const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
                  isArabic: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: AllahHighlighter.spans(
                item.verseEn,
                const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: canNavigate
                ? () => _playRef(item.ref)
                : (widget.onLoadTafsirRef != null
                    ? () => widget.onLoadTafsirRef!(item.ref)
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
                Text(item.ref,
                    style: TextStyle(
                      color: canNavigate
                          ? Colors.lightBlueAccent
                          : (widget.onLoadTafsirRef != null
                              ? Colors.amber
                              : Colors.white38),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    )),
                if (!canNavigate) ...[
                  const SizedBox(width: 6),
                  _buildLoadTafsirPrompt(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrambleCard(ScrambleData scramble) {
    const orange = Colors.orange;
    final gameActive = _scrambleGameActive;
    final isComplete = !gameActive || _scrambleSolvedCount >= scramble.words.length;

    final canNavigate = widget.isQuranLoaded &&
        widget.onVerseSelected != null &&
        scramble.verseRef != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: orange.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: orange.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: orange.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: orange.withAlpha(140)),
            ),
            child: Text(scramble.hint, style: const TextStyle(color: orange, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          if (gameActive) ...[
            if (_scrambleSolvedCount > 0) ...[
              Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 16,
                    runSpacing: 12,
                    children: List.generate(
                      _scrambleSolvedCount,
                      (i) => _buildScrambleWordColumn(scramble, i, solved: true),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (!isComplete) ...[
              Text(
                'Tap the words in order (${_scrambleSolvedCount + 1} of ${scramble.words.length})',
                style: TextStyle(color: orange.withAlpha(180), fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 8),
              Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 16,
                    runSpacing: 12,
                    children: _scramblePool
                        .map((i) => _buildScrambleWordColumn(scramble, i, solved: false))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ],
          if (isComplete) ...[
            const SizedBox(height: 4),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text.rich(
                TextSpan(
                  children: AllahHighlighter.spans(
                    scramble.arabic,
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
                  scramble.verseEn,
                  const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(scramble.reference,
                style: const TextStyle(color: orange, fontSize: 12, fontWeight: FontWeight.bold)),
            if (scramble.verseRef != null) ...[
              const SizedBox(height: 2),
              GestureDetector(
                onTap: canNavigate
                    ? () => _playRef(scramble.verseRef)
                    : (widget.onLoadTafsirRef != null
                        ? () => widget.onLoadTafsirRef!(scramble.verseRef!)
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
                    Text(scramble.verseRef!,
                        style: TextStyle(
                          color: canNavigate
                              ? Colors.lightBlueAccent
                              : (widget.onLoadTafsirRef != null
                                  ? Colors.amber
                                  : Colors.white38),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        )),
                    if (!canNavigate) ...[
                      const SizedBox(width: 6),
                      _buildLoadTafsirPrompt(),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildScrambleWordColumn(ScrambleData scramble, int wordIndex, {required bool solved}) {
    const orange = Colors.orange;
    final isWrong = _scrambleWrongFlash.contains(wordIndex);
    final color = isWrong ? Colors.redAccent : (solved ? orange : Colors.white70);
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(scramble.words[wordIndex],
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontSize: 32)),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: solved ? null : () => _guessScramble(wordIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isWrong
                    ? Colors.redAccent.withAlpha(40)
                    : (solved ? orange.withAlpha(25) : Colors.white.withAlpha(20)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isWrong
                      ? Colors.redAccent
                      : (solved ? orange.withAlpha(140) : Colors.white38),
                ),
              ),
              child: Text(scramble.translations[wordIndex],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarfCard(HarfItem harf, int index) {
    final pillColor = Colors.deepPurple;
    final revealed = _harfRevealed.contains(index);

    final match = RootHighlighter.findMatch(
      harf.arabicVerse,
      harf.word,
      override: harf.matchOverride,
    );
    final ref = harf.verseRef;
    final canNavigate =
        widget.isQuranLoaded && widget.onVerseSelected != null && ref != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pillColor.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pillColor.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: pillColor.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pillColor.withAlpha(160)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    harf.display,
                    style: TextStyle(
                      color: Colors.purple.shade300,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  harf.hint,
                  style: TextStyle(color: Colors.purple.shade100, fontSize: 14, height: 1.3),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    harf.word,
                    style: TextStyle(
                      color: Colors.purple.shade100,
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (revealed) {
                      _harfRevealed = {..._harfRevealed}..remove(index);
                    } else {
                      _harfRevealed = {..._harfRevealed, index};
                    }
                  });
                  if (!revealed) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || !_contentScrollController.hasClients) return;
                      _contentScrollController.animateTo(
                        _contentScrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    });
                  }
                },
                icon: Icon(
                  revealed ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                  color: Colors.purple.shade200,
                ),
                label: Text(
                  revealed ? 'Hide' : 'Highlight',
                  style: TextStyle(color: Colors.purple.shade200, fontSize: 12),
                ),
              ),
            ],
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text.rich(
              TextSpan(
                children: _buildVerseSpans(
                  harf.arabicVerse,
                  match,
                  Colors.purple.shade100,
                  revealed: revealed,
                ),
              ),
              style: const TextStyle(fontSize: 40, height: 1.7),
            ),
          ),
          if (match != null && revealed) ...[
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text.rich(
                TextSpan(children: _buildWordBreakdownSpans(match, Colors.purple.shade300)),
                style: const TextStyle(fontSize: 44, height: 1.3),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(harf.verse,
              style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
          const SizedBox(height: 6),
          if (ref != null)
            GestureDetector(
              onTap: canNavigate
                  ? () => _playRef(ref)
                  : (widget.onLoadTafsirRef != null
                      ? () => widget.onLoadTafsirRef!(ref)
                      : null),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canNavigate) ...[
                    const Icon(Icons.play_circle_outline, size: 14, color: Colors.lightBlueAccent),
                    const SizedBox(width: 4),
                  ],
                  Text(ref,
                      style: TextStyle(
                        color: canNavigate
                            ? Colors.lightBlueAccent
                            : (widget.onLoadTafsirRef != null ? Colors.amber : Colors.white38),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      )),
                  if (!canNavigate) ...[
                    const SizedBox(width: 6),
                    _buildLoadTafsirPrompt(),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<InlineSpan> _buildVerseSpans(String verse, WordMatch? match, Color highlight, {required bool revealed}) {
    if (match == null || !revealed) {
      return [TextSpan(text: verse, style: const TextStyle(color: Colors.white))];
    }
    return [
      TextSpan(text: verse.substring(0, match.wordStart), style: const TextStyle(color: Colors.white)),
      TextSpan(
        text: verse.substring(match.wordStart, match.wordEnd),
        style: TextStyle(
          color: Colors.purple.shade500,
          fontWeight: FontWeight.bold,
        ),
      ),
      TextSpan(text: verse.substring(match.wordEnd), style: const TextStyle(color: Colors.white)),
    ];
  }

  List<InlineSpan> _buildWordBreakdownSpans(WordMatch match, Color rootColor) {
    final w = match.word;
    return [
      TextSpan(text: w.substring(0, match.rootStartInWord), style: const TextStyle(color: Colors.white38)),
      TextSpan(
        text: w.substring(match.rootStartInWord, match.rootEndInWord),
        style: TextStyle(color: rootColor, fontWeight: FontWeight.w900),
      ),
      TextSpan(text: w.substring(match.rootEndInWord), style: const TextStyle(color: Colors.white38)),
    ];
  }
}
