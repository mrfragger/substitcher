import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_lemma.dart';
import '../models/root_card.dart';
import '../services/quran_vocab_loader.dart';

class QuranListPanel extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<QuranLemma>? onSearchInQuran;
  final void Function(RootCard card)? onOpenRoot;

  const QuranListPanel({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchQuery,
    required this.onSearchChanged,
    this.onSearchInQuran,
    this.onOpenRoot,
  });

  @override
  State<QuranListPanel> createState() => _QuranListPanelState();
}

enum _PosFilter { all, noun, verb, particle, adj, names }
enum _TierFilter { all, platinum, gold, silver, bronze, common }
enum _GlossLang { en, ur, ps }
enum _SortMode { frequency, az }

class _QuranListPanelState extends State<QuranListPanel> {
  late Future<QuranVocabData> _future;

  _PosFilter _posFilter = _PosFilter.all;
  _SortMode _sortMode = _SortMode.frequency;
  _TierFilter _tierFilter = _TierFilter.all;
  _GlossLang _glossLang = _GlossLang.en;

  final Map<int, int> _rankById = {};

  final ScrollController _scrollController = ScrollController();
  int? _pendingScrollId;
  bool _didAttemptScrollToLastClicked = false;

  static const _prefTier = 'quran_list_tier';
  static const _prefPos = 'quran_list_pos';
  static const _prefSort = 'quran_list_sort';
  static const _prefLang = 'quran_list_lang';
  static const _prefLastClicked = 'quran_list_last_clicked_id';

  static const double _rowLabelWidth = 40;

  static const Map<_PosFilter, String> _filterLabels = {
    _PosFilter.all: 'All',
    _PosFilter.noun: 'Nouns',
    _PosFilter.verb: 'Verbs',
    _PosFilter.particle: 'Particles',
    _PosFilter.adj: 'Adjectives',
    _PosFilter.names: 'Names',
  };

  static const Map<_TierFilter, String> _tierLabels = {
    _TierFilter.all: 'All',
    _TierFilter.platinum: 'Platinum',
    _TierFilter.gold: 'Gold',
    _TierFilter.silver: 'Silver',
    _TierFilter.bronze: 'Bronze',
    _TierFilter.common: 'Common',
  };

  static const Map<_TierFilter, String> _tierTooltips = {
    _TierFilter.all:
        '4,832 unique words (lemmas) ~100% of Quran',
    _TierFilter.platinum:
        '18 words (500+ occurrences)',
    _TierFilter.gold:
        '87 words (100–499 occurrences)',
    _TierFilter.silver:
        '122 words (50–99 occurrences)',
    _TierFilter.bronze:
        '628 words (10–49 occurrences)',
    _TierFilter.common:
        '3,977 words (1–9 occurrences)',
  };

  static const Map<_GlossLang, String> _langLabels = {
    _GlossLang.en: 'English',
    _GlossLang.ur: 'Urdu',
    _GlossLang.ps: 'Pashto',
  };

  @override
  void initState() {
    super.initState();
    _future = QuranVocabLoader.load().then((data) {
      final byFreq = [...data.lemmas]..sort((a, b) => b.count.compareTo(a.count));
      for (int i = 0; i < byFreq.length; i++) {
        _rankById[byFreq[i].id] = i + 1;
      }
      return data;
    });
    _loadPrefs();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final tierName = prefs.getString(_prefTier);
    final posName = prefs.getString(_prefPos);
    final sortName = prefs.getString(_prefSort);
    final langName = prefs.getString(_prefLang);
    final lastId = prefs.getInt(_prefLastClicked);
    setState(() {
      if (tierName != null) {
        _tierFilter = _TierFilter.values
            .firstWhere((e) => e.name == tierName, orElse: () => _TierFilter.all);
      }
      if (posName != null) {
        _posFilter = _PosFilter.values
            .firstWhere((e) => e.name == posName, orElse: () => _PosFilter.all);
      }
      if (sortName != null) {
        _sortMode = _SortMode.values
            .firstWhere((e) => e.name == sortName, orElse: () => _SortMode.frequency);
      }
      if (langName != null) {
        _glossLang = _GlossLang.values
            .firstWhere((e) => e.name == langName, orElse: () => _GlossLang.en);
      }
      _pendingScrollId = lastId;
    });
  }

  Future<void> _saveStringPref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _saveLastClickedId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefLastClicked, id);
  }

  bool _matchesTierFilter(QuranLemma l) {
    if (_tierFilter == _TierFilter.all) return true;
    final tier = l.tier.toLowerCase().trim();
    switch (_tierFilter) {
      case _TierFilter.platinum:
        return tier == 'platinum';
      case _TierFilter.gold:
        return tier == 'gold';
      case _TierFilter.silver:
        return tier == 'silver';
      case _TierFilter.bronze:
        return tier == 'bronze';
      case _TierFilter.common:
        return tier == 'common';
      case _TierFilter.all:
        return true;
    }
  }

  bool _matchesPosFilter(QuranLemma l) {
    if (_posFilter == _PosFilter.all) return true;
    final pos = l.pos;
    switch (_posFilter) {
      case _PosFilter.noun:
        return pos == 'noun';
      case _PosFilter.verb:
        return pos == 'verb';
      case _PosFilter.particle:
        return pos == 'particle';
      case _PosFilter.adj:
        return pos == 'adjective';
      case _PosFilter.names:
        return pos == 'proper noun';
      case _PosFilter.all:
        return true;
    }
  }

  Color _posColor(String pos) {
    switch (pos) {
      case 'noun':
        return const Color(0xFFCB93F5);
      case 'verb':
        return Colors.amber;
      case 'particle':
        return Colors.grey[300]!;
      case 'adjective':
        return Colors.brown[300]!;
      case 'proper noun':
        return Colors.lightGreenAccent;
      case 'conjunction':
        return Colors.orangeAccent;
      case 'relative pronoun':
        return Colors.tealAccent;
      case 'demonstrative':
        return Colors.pinkAccent;
      case 'preposition':
        return Colors.indigoAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }

  List<QuranLemma> _filtered(List<QuranLemma> lemmas) {
    final q = widget.searchQuery.trim();
    Iterable<QuranLemma> result =
        lemmas.where(_matchesPosFilter).where(_matchesTierFilter);

    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      result = result.where((l) {
        return l.arabic.contains(q) ||
            l.translit.toLowerCase().contains(lower) ||
            l.en.toLowerCase().contains(lower) ||
            l.ur.contains(q) ||
            l.ps.contains(q) ||
            (l.root?.contains(q) ?? false);
      });
    }
    final list = result.toList();
    if (_sortMode == _SortMode.az) {
      list.sort((a, b) {
        final at = a.translit.isNotEmpty ? a.translit : a.en;
        final bt = b.translit.isNotEmpty ? b.translit : b.en;
        return at.toLowerCase().compareTo(bt.toLowerCase());
      });
    } else {
      list.sort((a, b) => b.count.compareTo(a.count));
    }
    return list;
  }

  int _crossAxisCountFor(double maxWidth) {
    const maxCrossAxisExtent = 230.0;
    const crossAxisSpacing = 12.0;
    final count = (maxWidth / (maxCrossAxisExtent + crossAxisSpacing)).ceil();
    return count < 1 ? 1 : count;
  }

  void _maybeScrollToLastClicked(List<QuranLemma> filtered, double maxWidth) {
    if (_didAttemptScrollToLastClicked || _pendingScrollId == null) return;
    final index = filtered.indexWhere((l) => l.id == _pendingScrollId);
    _didAttemptScrollToLastClicked = true;
    if (index == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptScrollToGridIndex(index, maxWidth);
    });
  }

  void _attemptScrollToGridIndex(int index, double maxWidth, {int attemptsLeft = 10}) {
    if (!mounted || attemptsLeft <= 0) return;
    if (!_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _attemptScrollToGridIndex(index, maxWidth, attemptsLeft: attemptsLeft - 1);
      });
      return;
    }
    const mainAxisExtent = 220.0;
    const mainAxisSpacing = 12.0;
    final crossAxisCount = _crossAxisCountFor(maxWidth);
    final row = index ~/ crossAxisCount;
    final offset = row * (mainAxisExtent + mainAxisSpacing);
    final maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      offset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Color _tierFilterColor(_TierFilter tier) {
    switch (tier) {
      case _TierFilter.platinum:
        return const Color(0xFFCB93F5);
      case _TierFilter.gold:
        return Colors.amber;
      case _TierFilter.silver:
        return Colors.grey[300]!;
      case _TierFilter.bronze:
        return Colors.brown[300]!;
      case _TierFilter.common:
        return Colors.lightGreenAccent;
      case _TierFilter.all:
        return Colors.lightBlueAccent;
    }
  }

  Color _posFilterColor(_PosFilter pos) {
    switch (pos) {
      case _PosFilter.all:
        return Colors.lightBlueAccent;
      case _PosFilter.noun:
        return const Color(0xFFCB93F5); // matches Platinum
      case _PosFilter.verb:
        return Colors.amber; // matches Gold
      case _PosFilter.particle:
        return Colors.grey[300]!; // matches Silver
      case _PosFilter.adj:
        return Colors.brown[300]!; // matches Bronze
      case _PosFilter.names:
        return Colors.lightGreenAccent; // matches Common
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuranVocabData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.deepPurple),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load vocab data:\n${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          );
        }

        final data = snapshot.data!;
        final filtered = _filtered(data.lemmas);

        return Column(
          children: [
            // Pass the count to the top row
            _buildTierAndLangRow(filtered.length),
            const SizedBox(height: 8),
            _buildFilterAndSortRow(),
            const SizedBox(height: 8), // Adjusted spacing
            // Removed the old word count row from here
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No matches',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        _maybeScrollToLastClicked(filtered, constraints.maxWidth);
                        return GridView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230,
                            mainAxisExtent: 220,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final lemma = filtered[index];
                            return _LemmaGridCard(
                              lemma: lemma,
                              rank: _rankById[lemma.id] ?? (index + 1),
                              glossLang: _glossLang,
                              onTap: () {
                                _saveLastClickedId(lemma.id);
                                widget.onSearchInQuran?.call(lemma);
                              },
                              onRootTap: () {
                                final card = data.rootFor(lemma);
                                if (card == null) return;
                                widget.onOpenRoot?.call(card);
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTierAndLangRow(int wordCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(
                      width: _rowLabelWidth,
                      child: Text('Tier',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 4),
                    for (final entry in _tierLabels.entries) ...[
                      Tooltip(
                        message: _tierTooltips[entry.key] ?? '',
                        preferBelow: true,
                        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _coloredPillButton(
                          label: entry.value,
                          selected: _tierFilter == entry.key,
                          color: _tierFilterColor(entry.key),
                          onTap: () {
                            setState(() => _tierFilter = entry.key);
                            _saveStringPref(_prefTier, entry.key.name);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$wordCount words',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 340,
            height: 36,
            child: TextField(
              controller: widget.searchController,
              focusNode: widget.searchFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '/ Search lemma, root, or gloss...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: Colors.white54, size: 18),
                suffixIcon: widget.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white54, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          widget.searchController.clear();
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
                    horizontal: 10, vertical: 8),
              ),
              onChanged: widget.onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _langToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in _langLabels.entries)
            GestureDetector(
              onTap: () {
                setState(() => _glossLang = entry.key);
                _saveStringPref(_prefLang, entry.key.name);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _glossLang == entry.key
                      ? Colors.amber.withAlpha(40)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: _glossLang == entry.key
                        ? Colors.amber
                        : Colors.white54,
                    fontSize: 12,
                    fontWeight: _glossLang == entry.key
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(
                width: _rowLabelWidth,
                child: Text('Type',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 4),
              for (final entry in _filterLabels.entries) ...[
                _coloredPillButton(
                  label: entry.value,
                  selected: _posFilter == entry.key,
                  color: _posFilterColor(entry.key),
                  onTap: () {
                    setState(() => _posFilter = entry.key);
                    _saveStringPref(_prefPos, entry.key.name);
                  },
                ),
                const SizedBox(width: 8),
              ],
              const SizedBox(width: 6),
              const Text('Sort',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              _pillButton(
                label: 'Frequency',
                selected: _sortMode == _SortMode.frequency,
                onTap: () {
                  setState(() => _sortMode = _SortMode.frequency);
                  _saveStringPref(_prefSort, _SortMode.frequency.name);
                },
              ),
              const SizedBox(width: 8),
              _pillButton(
                label: 'A\u2013Z',
                selected: _sortMode == _SortMode.az,
                onTap: () {
                  setState(() => _sortMode = _SortMode.az);
                  _saveStringPref(_prefSort, _SortMode.az.name);
                },
              ),
              const SizedBox(width: 12),
              _langToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.amber.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.amber : Colors.white24,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.amber : Colors.white70,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _coloredPillButton({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(selected ? 45 : 30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withAlpha(selected ? 255 : 140),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _LemmaGridCard extends StatelessWidget {
  final QuranLemma lemma;
  final int rank;
  final _GlossLang glossLang;
  final VoidCallback? onTap;
  final VoidCallback? onRootTap;

  const _LemmaGridCard({
    required this.lemma,
    required this.rank,
    required this.glossLang,
    this.onTap,
    this.onRootTap,
  });

  String get _gloss {
    switch (glossLang) {
      case _GlossLang.en:
        return lemma.en;
      case _GlossLang.ur:
        return lemma.ur;
      case _GlossLang.ps:
        return lemma.ps;
    }
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'platinum':
        return const Color(0xFFCB93F5);
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey[300]!;
      case 'bronze':
        return Colors.brown[300]!;
      case 'common':
        return Colors.lightGreenAccent;
      default:
        return Colors.lightGreenAccent;
    }
  }

  Color _posColor(String pos) {
    switch (pos) {
      case 'noun':
        return const Color(0xFFCB93F5);
      case 'verb':
        return Colors.amber;
      case 'particle':
        return Colors.grey[300]!;
      case 'adjective':
        return Colors.brown[300]!;
      case 'proper noun':
        return Colors.lightGreenAccent;
      default:
        return Colors.lightBlueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(lemma.tier);
    final posColor = _posColor(lemma.pos);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('#$rank',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                if (lemma.hasRootCard)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: onRootTap,
                      child: const Icon(Icons.account_tree,
                          color: Colors.teal, size: 16),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: tierColor.withAlpha(140)),
                  ),
                  child: Text(
                    lemma.tier.toUpperCase(),
                    style: TextStyle(
                      color: tierColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
            width: double.infinity,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                lemma.arabic,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontFamily: 'Amiri Quran',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (lemma.translit.isNotEmpty)
              Text(
                lemma.translit,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              if (_gloss.isNotEmpty)
                Directionality(
                  textDirection: glossLang == _GlossLang.en
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  child: Text(
                    _gloss,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: posColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: posColor.withAlpha(140)),
                  ),
                  child: Text(
                    lemma.pos.toLowerCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: posColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '\u00d7${lemma.count}',
                  style: const TextStyle(
                    color: Colors.cyan,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RootPanel extends StatelessWidget {
  final RootCard card;
  final bool isCollapsed;
  final VoidCallback onClose;

  final ValueChanged<String>? onSearchLemma;

  const RootPanel({
    super.key,
    required this.card,
    required this.isCollapsed,
    required this.onClose,
    this.onSearchLemma,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: isCollapsed ? null : 0,
      width: 990,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            border: Border(left: BorderSide(color: Colors.white12)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: onClose,
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              card.root,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontFamily: 'Amiri Quran',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            card.root,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontFamily: 'Amiri Quran',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(card.rootBw,
                style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                card.family,
                style: const TextStyle(color: Colors.tealAccent, fontSize: 12),
              ),
            ),
            const Spacer(),
            Text('\u00d7${card.frequency}',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          card.meaning,
          style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white24),
        const SizedBox(height: 8),
        Text(
          '${card.vocab.length} lemma${card.vocab.length == 1 ? '' : 's'}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ...card.vocab.expand((v) => [
              InkWell(
                onTap: onSearchLemma != null
                    ? () => onSearchLemma!(v.lemma)
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withAlpha(40),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          v.lemma,
                          style: TextStyle(
                            color: Colors.purple[200],
                            fontSize: 38,
                            fontFamily: 'Amiri Quran',
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text('\u00d7${v.frequency}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              ...v.forms.map((f) => InkWell(
                    onTap: onSearchLemma != null
                        ? () => onSearchLemma!(f.diacritized ?? f.form)
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              f.diacritized ?? f.form,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 38,
                                fontFamily: 'Amiri Quran',
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text('\u00d7${f.count}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 16)),
                        ],
                      ),
                    ),
                  )),
            ]),
      ],
    );
  }
}
