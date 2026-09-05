import 'package:flutter/material.dart';
import '../quiz/connections_model.dart';
import '../quiz/daily_quiz_index.dart';
import '../quran/quran_index.dart';
import '../services/allah_highlighter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class RelatedConnectionsPanel extends StatefulWidget {
  final bool isQuranLoaded;
  final Function(QuranVerseRef, int)? onVerseSelected;

  const RelatedConnectionsPanel({
    super.key,
    required this.isQuranLoaded,
    this.onVerseSelected,
  });

  @override
  State<RelatedConnectionsPanel> createState() => _RelatedConnectionsPanelState();
}

class _RelatedConnectionsPanelState extends State<RelatedConnectionsPanel> {
  List<ConnectionsEntry> _entries = [];
  DateTime? _selectedDate;
  ConnectionsData? _data;
  ScrambleData? _scramble;
  bool _loadingList = true;
  bool _loadingDay = false;

  final ItemScrollController _entryScrollController = ItemScrollController();

  String? _activeCategoryName;
  ConnectionItem? _activeItem;

  @override
  void initState() {
    super.initState();
    _init();
  }

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
    });
    try {
      final dayJson = await DailyQuizIndex.loadDay(date);
      final data = ConnectionsData.tryParse(dayJson);
      final scramble = ScrambleData.tryParse(dayJson);
      if (!mounted) return;
      setState(() {
        _data = data;
        _scramble = scramble;
        _loadingDay = false;
      });
      if (data != null) {
        final saved = await ConnectionsSelectionPrefs.loadSelection(date);
        if (saved != null) {
          for (final cat in data.categories) {
            final match = cat.items.where((i) => i.ref == saved).firstOrNull;
            if (match != null) {
              if (mounted) {
                setState(() {
                  _activeCategoryName = cat.name;
                  _activeItem = match;
                });
              }
              break;
            }
          }
        }
      }
      await ConnectionsPrefs.saveLastDate(date);
      _scrollToSelectedEntry();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDay = false);
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
        SizedBox(width: 180, child: _buildEntryList()),
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
            child: Text(_fmtDate(e.date),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    final data = _data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...data.categories.map((cat) => _buildCategoryCard(cat)),
        if (_scramble != null) _buildScrambleCard(_scramble!),
      ],
    );
  }

  Widget _buildCategoryCard(ConnectionCategory cat) {
    final canNavigate = widget.isQuranLoaded && widget.onVerseSelected != null;
    final isActiveCategory = _activeCategoryName == cat.name;
    final activeItemHere = isActiveCategory ? _activeItem : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cat.color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cat.color.withAlpha(120)),
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
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: cat.items.map((item) {
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
                style: TextStyle(color: cat.color, fontSize: 15)),
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
              onTap: canNavigate ? () => _playRef(item.ref) : null,
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
                        color: canNavigate ? Colors.lightBlueAccent : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildScrambleCard(ScrambleData scramble) {
        final canNavigate = widget.isQuranLoaded &&
            widget.onVerseSelected != null &&
            scramble.verseRef != null;
        const orange = Colors.orange;
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
                child: Text(scramble.hint, style: const TextStyle(color: orange, fontSize: 13)),
              ),
              const SizedBox(height: 10),
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
                  onTap: canNavigate ? () => _playRef(scramble.verseRef) : null,
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
                            color: canNavigate ? Colors.lightBlueAccent : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      }
}
