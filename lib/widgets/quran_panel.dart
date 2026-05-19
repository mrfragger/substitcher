import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../data/quran_index.dart';
import '../data/surah_names.dart';
import '../data/tafsir_sadi_arabic.dart';
import '../data/tafsir_moyassar_arabic.dart';
import '../data/tafsir_mokhtasar_arabic.dart';
import '../data/tafsir_mokhtasar_all.dart';

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

  static bool _tafsirExpanded = false;
  static bool _tafsirMokhtasar = true;
  static bool _tafsirMokhtasarAr = false;
  static bool _tafsirSadiAr = false;
  static bool _tafsirMoyassarAr = false;
  static String _mokhtasarLanguage = 'English';
  static List<Map<String, dynamic>> _tafsirResults = [];
  static final TextEditingController _tafsirRefController = TextEditingController();
  final FocusNode _tafsirRefFocusNode = FocusNode();

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
    _tafsirRefController.dispose();
    _tafsirRefFocusNode.dispose();
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
        if (currentMainMatches) result.add(entry);
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
        SnackBar(content: Text('Could not parse: "$text"'), duration: const Duration(seconds: 2)),
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
        SnackBar(content: Text('Surah $surah only has $maxAyah verses'), duration: const Duration(seconds: 2)),
      );
      return;
    }
    if (toAyah != null && (toAyah < fromAyah || toAyah > maxAyah)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid range: Surah $surah has $maxAyah verses'), duration: const Duration(seconds: 2)),
      );
      return;
    }

    final ref = QuranVerseRef(surah: surah, fromAyah: fromAyah, toAyah: toAyah, isFullSurah: false);
    _refInputController.clear();
    widget.onVerseSelected(ref, 0);
    _refInputFocusNode.requestFocus();
  }


  _TafsirRange? _parseTafsirRef(BuildContext context, String raw) {
    final text = raw.trim().replaceAll(RegExp(r'[(){}\[\]]'), '');
    if (text.isEmpty) return null;

    final surahOnly = RegExp(r'^(\d+)$').firstMatch(text);
    if (surahOnly != null) {
      final s = int.parse(surahOnly.group(1)!);
      if (s < 1 || s > 114) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid surah number'), duration: Duration(seconds: 2)),
        );
        return null;
      }
      return _TafsirRange(s, 0, quranVerseCounts[s]);
    }

    final m = RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(text);
    if (m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not parse: "$text"'), duration: const Duration(seconds: 2)),
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
        const SnackBar(content: Text('Invalid surah'), duration: Duration(seconds: 2)),
      );
      return null;
    }
    final max = quranVerseCounts[s];
    if (from < 0 || from > max || to < from || (to > 0 && to > max)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Surah $s has $max verses'), duration: const Duration(seconds: 2)),
      );
      return null;
    }
    return _TafsirRange(s, from, to);
  }

  void _lookupTafsir(BuildContext context) {
    final range = _parseTafsirRef(context, _tafsirRefController.text);
    if (range == null) return;

    final results = <Map<String, dynamic>>[];

    for (int ayah = range.from; ayah <= range.to; ayah++) {
      if (_tafsirMokhtasar) {
        final text = getTafsirMokhtasarForLanguage(_mokhtasarLanguage, range.surah, ayah);
        if (text != null) {
          results.add({'source': 'Mokhtasar', 'surah': range.surah, 'ayah': ayah, 'text': text});
        }
      }
      if (_tafsirMokhtasarAr) {
        final text = getTafsirMokhtasarArabic(range.surah, ayah);
        if (text != null) {
          results.add({'source': 'Mokhtasar Ar', 'surah': range.surah, 'ayah': ayah, 'text': text});
        }
      }
      if (_tafsirMoyassarAr) {
        final text = getTafsirMoyassarArabic(range.surah, ayah);
        if (text != null) {
          results.add({'source': 'Moyassar Ar', 'surah': range.surah, 'ayah': ayah, 'text': text});
        }
      }
      if (_tafsirSadiAr) {
        final text = getTafsirSadiArabic(range.surah, ayah);
        if (text != null) {
          results.add({'source': 'Sadi Ar', 'surah': range.surah, 'ayah': ayah, 'text': text});
        }
      }
    }

    setState(() => _tafsirResults = results);
    _tafsirRefFocusNode.requestFocus();
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
                      const Text('Surah List',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text('${s.number}',
                                    style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 12)),
                              ),
                              Expanded(
                                child: Directionality(
                                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                                  child: Text(s.name,
                                      style: TextStyle(
                                        color: widget.isQuranLoaded ? Colors.lightBlueAccent : Colors.yellow,
                                        fontSize: 13,
                                      )),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(left: isRtl ? 8 : 0, right: isRtl ? 0 : 8),
                                child: Text('${quranVerseCounts[s.number]}',
                                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
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
            _tafsirRefFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.slash) {
          _searchFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                if (availableQuranIndexLanguages.length > 1) ...[
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: widget.selectedLanguage,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    underline: const SizedBox(),
                    isDense: true,
                    items: availableQuranIndexLanguages
                        .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                        .toList(),
                    onChanged: (lang) {
                      if (lang != null) widget.onLanguageChanged(lang);
                    },
                  ),
                ],
              ],
            ),
          ),

          _buildTafsirSection(context),

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
                              text: 'Load a Quran Verse by Verse audiobook to enable navigation — '),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('${filtered.length} topics',
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 10),
                const Text('* no vtt subs',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'csv needs to be downloadable on quranenc.com for vtt',
                  preferBelow: true,
                  textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.info_outline, color: Colors.white38, size: 14),
                ),
                if (widget.isQuranLoaded) ...[
                  const SizedBox(width: 16),
                  const Text('⇧Q next reference',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search, color: Colors.deepPurple, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: widget.isQuranLoaded ? () => _playRefFromInput(context) : null,
                        ),
                      ),
                      onSubmitted: widget.isQuranLoaded ? (_) => _playRefFromInput(context) : null,
                    ),
                  ),
                ],
                if (widget.selectedLanguage == 'English') ...[
                  const SizedBox(width: 8),
                  _quickFilterChip('Juz', 'juz'),
                  const SizedBox(width: 4),
                  _quickFilterChip('Hizb', 'hizb'),
                  const SizedBox(width: 4),
                  _quickFilterChip('Rub', 'rub'),
                  const SizedBox(width: 4),
                  _quickFilterChip('months', 'islamic months'),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => _showSurahListPopup(context),
                  child: const Text('Surah List',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() {
                    if (_expandedIndices.length >= widget.entries.length) {
                      _expandedIndices.clear();
                    } else {
                      _expandedIndices.addAll(List.generate(widget.entries.length, (i) => i));
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
                      child: Text(entry.topic,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic)),
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
                              } else if (!widget.entries[i].isSubtopic) break;
                            }
                          }
                        } else {
                          _expandedIndices.add(globalIndex);
                          if (!entry.isSubtopic) {
                            for (int i = globalIndex + 1; i < widget.entries.length; i++) {
                              if (widget.entries[i].isSubtopic &&
                                  widget.entries[i].parentTopic == entry.topic) {
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            fontSize: 12,
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
                SizedBox(
                  width: 180,
                  height: 32,
                  child: TextField(
                    controller: _tafsirRefController,
                    focusNode: _tafsirRefFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '2:255 or 2:1-5',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
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
                const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear_all, color: Colors.deepOrange, size: 18),
                    tooltip: 'Clear tafsir',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _tafsirResults = []),
                  ),
                const SizedBox(width: 8),
                _tafsirCheckbox('Mokhtasar', _tafsirMokhtasar, (v) {
                  setState(() => _tafsirMokhtasar = v ?? false);
                }),
                const SizedBox(width: 8),
                if (_tafsirMokhtasar)
                  DropdownButton<String>(
                    value: _mokhtasarLanguage,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    underline: const SizedBox(),
                    isDense: true,
                    items: mokhtasarLanguages
                        .map((lang) => DropdownMenuItem(value: lang, child: Text(lang)))
                        .toList(),
                    onChanged: (lang) {
                      if (lang != null) setState(() => _mokhtasarLanguage = lang);
                    },
                  ),
                const SizedBox(width: 12),
                _tafsirCheckbox('Mokhtasar Ar', _tafsirMokhtasarAr, (v) {
                  setState(() => _tafsirMokhtasarAr = v ?? false);
                }),
                const SizedBox(width: 12),
                _tafsirCheckbox('Moyassar Ar', _tafsirMoyassarAr, (v) {
                  setState(() => _tafsirMoyassarAr = v ?? false);
                }),
                const SizedBox(width: 12),
                _tafsirCheckbox('Sadi Ar', _tafsirSadiAr, (v) {
                  setState(() => _tafsirSadiAr = v ?? false);
                }),
              ],
            ),
            if (_tafsirResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tafsirResults.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white12, height: 12),
                  itemBuilder: (_, i) => _buildTafsirCard(_tafsirResults[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tafsirCheckbox(String label, bool value, ValueChanged<bool?> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.teal,
            side: const BorderSide(color: Colors.white38),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _buildTafsirCard(Map<String, dynamic> r) {
    final source = r['source'] as String;
    final surah = r['surah'] as int;
    final ayah = r['ayah'] as int;
    final text = r['text'] as String;

    final sourceColor = source == 'Mokhtasar' ? Colors.lightBlueAccent : Colors.greenAccent;
    final ayahLabel = ayah == 0 ? '$surah:intro' : '$surah:$ayah';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sourceColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: sourceColor.withAlpha(100)),
                ),
                child: Text(source,
                    style: TextStyle(color: sourceColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(ayahLabel,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
          SelectableText(
            text,
            textDirection: (source == 'Sadi Ar' || source == 'Moyassar Ar' || source == 'Mokhtasar Ar')
                ? TextDirection.rtl
                : TextDirection.ltr,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _TafsirRange {
  final int surah;
  final int from;
  final int to;
  const _TafsirRange(this.surah, this.from, this.to);
}
