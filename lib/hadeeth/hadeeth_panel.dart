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
                        Text(
                          entry.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
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
              iconColor: Colors.amber,
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
                      color: Colors.orangeAccent, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Benefits',
                    style: TextStyle(
                      color: Colors.orangeAccent,
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
                              color: Colors.orangeAccent, fontSize: 13),
                        ),
                        Expanded(
                          child: SelectableText(
                            h,
                            textDirection: textDir,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
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
  }) {
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
        SelectableText(
          text,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, height: 1.6),
        ),
      ],
    );
  }
}
