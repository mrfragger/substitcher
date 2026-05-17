import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../data/quran_index.dart';
import '../data/surah_names.dart';

class QuranPanel extends StatefulWidget {
  final List<QuranIndexEntry> entries;
  final bool isQuranLoaded;
  final QuranVerseRef? activeRef;
  final Function(QuranVerseRef, int) onVerseSelected;
  final FocusNode searchFocusNode;
  final FocusNode quranExcludeFocusNode;
  final ItemScrollController itemScrollController;
  final String searchQuery;
  final String excludeQuery;
  final TextEditingController searchController;
  final TextEditingController excludeController;
  final Function(String) onSearchChanged;
  final Function(String) onExcludeChanged;
  final String selectedLanguage;
  final Function(String) onLanguageChanged;

  const QuranPanel({
    super.key,
    required this.entries,
    required this.isQuranLoaded,
    required this.activeRef,
    required this.onVerseSelected,
    required this.searchFocusNode,
    required this.quranExcludeFocusNode,
    required this.itemScrollController,
    required this.searchQuery,
    required this.excludeQuery,
    required this.searchController,
    required this.excludeController,
    required this.onSearchChanged,
    required this.onExcludeChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,

  });

  @override
  State<QuranPanel> createState() => _QuranPanelState();
}

class _QuranPanelState extends State<QuranPanel> {
  final Set<int> _expandedIndices = {};
  final TextEditingController _refInputController = TextEditingController();
  final FocusNode _refInputFocusNode = FocusNode();
  FocusNode get _searchFocusNode => widget.searchFocusNode;
  FocusNode get _excludeFocusNode => widget.quranExcludeFocusNode;
  ItemScrollController get _itemScrollController => widget.itemScrollController;
  String get _searchQuery => widget.searchQuery;
  String get _excludeQuery => widget.excludeQuery;
  TextEditingController get _searchController => widget.searchController;
  TextEditingController get _excludeController => widget.excludeController;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _refInputFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _refInputController.dispose();
    _refInputFocusNode.dispose();
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
        currentMainMatches = (_searchQuery.isEmpty || topicLower.contains(_searchQuery)) &&
            (_excludeQuery.isEmpty || !topicLower.contains(_excludeQuery));
        if (currentMainMatches) {
          result.add(entry);
        }
      } else {
        final topicLower = entry.topic.toLowerCase();
        final subtopicMatches = (_searchQuery.isEmpty || topicLower.contains(_searchQuery)) &&
            (_excludeQuery.isEmpty || !topicLower.contains(_excludeQuery));
        if (currentMainMatches) {
          result.add(entry);
        } else if (subtopicMatches) {
          if (result.isEmpty || result.last.topic != currentMainTopic || result.last.isSubtopic) {
            final parentEntry = widget.entries.firstWhere(
              (e) => !e.isSubtopic && e.topic == currentMainTopic,
              orElse: () => entry,
            );
            if (!result.any((e) => !e.isSubtopic && e.topic == parentEntry.topic)) {
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

  String _getSurahName(int surahNumber) {
    final surahs = getSurahsForLanguage(widget.selectedLanguage);
    final match = surahs.where((s) => s.number == surahNumber).firstOrNull;
    return match?.name ?? '';
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

    final match = RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(normalized.trim());
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not parse: "$text"'),
          duration: const Duration(seconds: 2),
        ),
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
          const SnackBar(content: Text('Invalid surah number'), duration: Duration(seconds: 2)),
        );
        return;
      }

      final maxAyah = quranVerseCounts[surah];
      if (fromAyah < 1 || fromAyah > maxAyah) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Surah $surah only has $maxAyah verses'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (toAyah != null && (toAyah < fromAyah || toAyah > maxAyah)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid range: Surah $surah has $maxAyah verses'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

    final ref = QuranVerseRef(
      surah: surah,
      fromAyah: fromAyah,
      toAyah: toAyah,
      isFullSurah: false,
    );

    _refInputController.clear();
    widget.onVerseSelected(ref, 0);
    _refInputFocusNode.requestFocus();
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
                      const Text(
                        'Surah List',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
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
                                child: Text(
                                  '${s.number}',
                                  style: const TextStyle(
                                    color: Colors.lightGreenAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Directionality(
                                  textDirection:
                                      isRtl ? TextDirection.rtl : TextDirection.ltr,
                                  child: Text(
                                    s.name,
                                    style: TextStyle(
                                      color: widget.isQuranLoaded
                                          ? Colors.lightBlueAccent
                                          : Colors.yellow,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(
                                  left: isRtl ? 8 : 0,
                                  right: isRtl ? 0 : 8,
                                ),
                                child: Text(
                                  '${quranVerseCounts[s.number]}',
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 11,
                                  ),
                                ),
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
            _refInputFocusNode.hasFocus) {
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
          // Search + Exclude + Language row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '/ Search topics...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => widget.onSearchChanged(v.trim().toLowerCase()),
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
                      prefixIcon: const Icon(Icons.block, color: Colors.white54, size: 20),
                      suffixIcon: _excludeQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => widget.onExcludeChanged(v.trim().toLowerCase()),
                  ),
                ),
                // Language dropdown — only shows if more than one language available
                if (availableQuranIndexLanguages.length > 1) ...[
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: widget.selectedLanguage,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    underline: const SizedBox(),
                    isDense: true,
                    items: availableQuranIndexLanguages.map((lang) =>
                      DropdownMenuItem(
                        value: lang,
                        child: Text(lang),
                      )
                    ).toList(),
                    onChanged: (lang) {
                      if (lang != null) widget.onLanguageChanged(lang);
                    },
                  ),
                ],
              ],
            ),
          ),

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
                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                        children: [
                          const TextSpan(
                            text: 'Load a Quran Verse by Verse audiobook to enable navigation — ',
                          ),
                          TextSpan(
                            text: 'https://t.me/AllahAudiobooks',
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () async {
                                final uri = Uri.parse('https://t.me/AllahAudiobooks');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
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

          // Entry count + expand/collapse
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} topics',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(width: 10),
                const Text(
                  '* no vtt subs',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'csv needs to be downloadable on quranenc.com \ncheck back in 2028',
                  preferBelow: true,
                  textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Colors.white38,
                    size: 14,
                  ),
                ),
                if (widget.isQuranLoaded) ...[
                  const SizedBox(width: 16),
                  const Text(
                    '⇧Q next reference',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  height: 28,
                  child: TextField(
                    controller: _refInputController,
                    focusNode: _refInputFocusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '38:36-40',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(
                          color: Colors.deepPurple.withAlpha(160),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.deepPurple.withAlpha(100)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Colors.deepPurple),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.deepPurple, size: 16),
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
                if (widget.selectedLanguage == 'English') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (_searchQuery == 'juz') {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      } else {
                        _searchController.text = 'juz';
                        widget.onSearchChanged('juz');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _searchQuery == 'juz'
                            ? Colors.deepPurple
                            : Colors.deepPurple.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.deepPurple.withAlpha(160)),
                      ),
                      child: Text(
                        'Juz',
                        style: TextStyle(
                          color: _searchQuery == 'juz' ? Colors.white : Colors.purple[200],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      if (_searchQuery == 'hizb') {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      } else {
                        _searchController.text = 'hizb';
                        widget.onSearchChanged('hizb');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _searchQuery == 'hizb'
                            ? Colors.deepPurple
                            : Colors.deepPurple.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.deepPurple.withAlpha(160)),
                      ),
                      child: Text(
                        'Hizb',
                        style: TextStyle(
                          color: _searchQuery == 'hizb' ? Colors.white : Colors.purple[200],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () {
                      if (_searchQuery == 'rub') {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      } else {
                        _searchController.text = 'rub';
                        widget.onSearchChanged('rub');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _searchQuery == 'rub'
                            ? Colors.deepPurple
                            : Colors.deepPurple.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.deepPurple.withAlpha(160)),
                      ),
                      child: Text(
                        'Rub',
                        style: TextStyle(
                          color: _searchQuery == 'rub' ? Colors.white : Colors.purple[200],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => _showSurahListPopup(context),
                  child: const Text(
                    'Surah List',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() {
                    if (_expandedIndices.length >= widget.entries.length) {
                      _expandedIndices.clear();
                    } else {
                      _expandedIndices.addAll(
                        List.generate(widget.entries.length, (i) => i),
                      );
                    }
                  }),
                  child: Text(
                    _expandedIndices.isEmpty ? 'Expand all' : 'Collapse all',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Topic list
          Expanded(
            child: ScrollablePositionedList.builder(
              itemScrollController: _itemScrollController,
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final entry = filtered[index];
                final globalIndex = widget.entries.indexOf(entry);
                final hasActiveRef = entry.refs.any(_isActiveRef);

                if (entry.refs.isEmpty && entry.isSubtopic) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(48, 2, 16, 2),
                    child: Directionality(
                      textDirection: isRtlQuranLanguage(widget.selectedLanguage)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Text(
                        entry.topic,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
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
                            for (int i = globalIndex + 1; i < widget.entries.length; i++) {
                              if (widget.entries[i].isSubtopic &&
                                  widget.entries[i].parentTopic == entry.topic) {
                                _expandedIndices.remove(i);
                              } else if (!widget.entries[i].isSubtopic) {
                                break;
                              }
                            }
                          }
                        } else {
                          _expandedIndices.add(globalIndex);
                          if (!entry.isSubtopic) {
                            for (int i = globalIndex + 1; i < widget.entries.length; i++) {
                              if (widget.entries[i].isSubtopic &&
                                  widget.entries[i].parentTopic == entry.topic) {
                                _expandedIndices.add(i);
                              } else if (!widget.entries[i].isSubtopic) {
                                break;
                              }
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
                            Expanded(
                              child: Directionality(
                                textDirection: isRtlQuranLanguage(widget.selectedLanguage)
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                child: Text(
                                  entry.topic,
                                  style: TextStyle(
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
                            const SizedBox(width: 10),
                            Text(
                               '${entry.refs.length} ref${entry.refs.length == 1 ? '' : 's'}',
                               style: const TextStyle(color: Colors.white24, fontSize: 11),
                             ),
                          ],
                        ),
                      ),
                    ),

                    if (isExpanded)
                      Padding(
                        padding: EdgeInsets.fromLTRB(entry.isSubtopic ? 56 : 40, 0, 16, 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: entry.refs.map((ref) {
                            final isActive = _isActiveRef(ref);
                            return Tooltip(
                              message: _getSurahName(ref.surah),
                              preferBelow: true,
                              verticalOffset: 32,
                              textStyle: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: GestureDetector(
                                onTap: widget.isQuranLoaded
                                    ? () {
                                        widget.onVerseSelected(ref, index);
                                        _refInputFocusNode.requestFocus();
                                      }
                                    : null,
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
                                              ? Colors.lightBlue.withAlpha(120)
                                              : Colors.deepOrange.withAlpha(80),
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
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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
      ),
    );
  }
}
