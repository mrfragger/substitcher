import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import '../models/audiobook_metadata.dart';
import '../models/color_palette.dart';
import '../models/frequency_item.dart';
import '../models/history_item.dart';
import '../models/bookmark.dart';
import '../models/font_category.dart';
import 'stats_panel.dart';

enum PanelMode { chapters, history, playlist, bookmarks, fonts, colors, words, subs, stats }
enum ColoringMode { words, letters }

class SidePanel extends StatelessWidget {
  static const ltr = '\u200E';
  final PanelMode panelMode;
  final bool isCollapsed;
  final AudiobookMetadata? currentAudiobook;
  final int currentChapterIndex;
  final String searchQuery;
  final bool searchUseAnd;
  final String excludeTerms;
  final TextEditingController searchController;
  final TextEditingController excludeController;
  final FocusNode searchFocusNode;
  final FocusNode excludeFocusNode;
  final VoidCallback onClose;
  final VoidCallback onToggleCollapse;
  final Function(PanelMode) onPanelModeChanged;
  final Function(String) onSearchChanged;
  final Function(String) onExcludeChanged;
  final VoidCallback onSearchAndSelected;
  final VoidCallback onSearchOrSelected;
  
  final List<Chapter> Function() getFilteredChapters;
  final Function(int) onJumpToChapter;
  final ScrollController chapterScrollController;
  final String skipChapterTerms;
  final TextEditingController skipChapterController;
  final FocusNode skipChapterFocusNode;
  final Function(String) onSkipChapterChanged;
  final bool Function(String) shouldSkipChapter;
  
  final List<HistoryItem> Function() getFilteredHistory;
  final Function(int) onRemoveFromHistory;
  final Function(String) onOpenAudiobook;
  final ScrollController historyScrollController;
  final Future<Map<String, dynamic>> Function(String, Duration) getHistoryDurationAndProgress;
  
  final List<String> Function() getFilteredPlaylist;
  final ScrollController playlistScrollController;
  final Future<String> Function(String) getAudiobookDuration;
  
  final List<Bookmark> Function() getFilteredBookmarks;
  final Function(int) onRemoveBookmark;
  final Function(Bookmark) onJumpToBookmark;
  final Function(int, int?) onSetPinNumber;
  
  final List<String> Function() getFilteredFonts;
  final String selectedFont;
  final int selectedFontIndex;
  final ScrollController fontScrollController;
  final Function(String, int) onFontSelected;
  final String selectedMainCategory;
  final String? selectedSubCategory;
  final String? selectedStudio;
  final Function(String, String?, String?) onCategorySelected;
  final String? customFontDirectory;
  final VoidCallback onSetCustomFontDirectory;
  final List<String> playlistDirectories;
  final int? activePlaylistIndex;
  final VoidCallback onAddPlaylistDirectory;
  final Function(int) onRemovePlaylistDirectory;
  final Function(int) onSetActivePlaylist;
  final String Function(String) shortenPath;
  final VoidCallback onResetConversion;
  final VoidCallback onConvertToDemo;
  final VoidCallback onConvertToDemoUpper;
  final VoidCallback onConvertToAlternates;
  final VoidCallback onConvertToMissing;
  final VoidCallback onConvertToUppercase;
  final VoidCallback onConvertToSeesawCase;
  final String conversionType;
  
  final List<ColorPalette> Function() getFilteredColors;
  final int selectedColorIndex;
  final ScrollController colorScrollController;
  final Function(ColorPalette, int) onColorPaletteSelected;
  final Color Function(String) parseColor;
  
  final List<FrequencyItem> frequencyItems;
  final bool isAnalyzingFrequencies;
  final VoidCallback? onAnalyzeFrequencies;
  final String? subtitleFilePath;
  final Function(String) onWordSearch;
  final Function(String) onPhraseSearch;
  
  final String subsSearchQuery;
  final TextEditingController subsSearchController;
  final FocusNode subsSearchFocusNode;
  final Function(String) onSearchSubtitles;
  final Widget Function() buildSearchContent;
  final bool isIndexingChapters;
  final String indexingStatus;
  final int indexedFiles;
  final int totalFilesToIndex;
  final bool hasChapterIndex;
  final VoidCallback? onIndexPlaylistChapters;
  final String chapterSearchQuery;
  final TextEditingController chapterSearchController;
  final FocusNode chapterSearchFocusNode;
  final Function(String) onSearchPlaylistChapters;
  final bool chapterSearchUseAnd;
  final VoidCallback onChapterSearchAndSelected;
  final VoidCallback onChapterSearchOrSelected;
  final String chapterExcludeTerms;
  final TextEditingController chapterExcludeController;
  final FocusNode chapterExcludeFocusNode;
  final Function(String) onChapterExcludeChanged;
  
  final List<Map<String, dynamic>> statsEntries;
  final bool statsEnabled;
  final Function(bool) onStatsEnabledChanged;
  final VoidCallback onRefreshStats;
  final String skipTrackingTerms;
  final TextEditingController skipTrackingController;
  final FocusNode skipTrackingFocusNode;
  final Function(String) onSkipTrackingChanged;
  final List<Map<String, dynamic>> Function(DateTime) filterEntriesByDate;
  final List<Map<String, dynamic>> Function(int) filterEntriesByDays;
  final Map<String, int> Function(List<Map<String, dynamic>>) getFileListenTimes;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) groupEntriesByAudiobook;
  final String Function(Duration) formatDurationCompact;
  final String Function(Duration) formatDuration;
  final Function(String, DateTime) deleteAudiobookFromDate;
  final TextSpan Function(String, String) highlightSearchTerm;
  final Function(String, String, Duration) jumpToStatsResult;

  final ColoringMode coloringMode;
  final Function(ColoringMode) onColoringModeChanged;
  
  final int historyCount;
  final int playlistCount;
  final int bookmarksCount;
  final int fontsCount;
  final int subsCount;
  final int statsCount;

  final bool showPlaylistDirectories;
  final Function(bool) onTogglePlaylistDirectories;

  final bool isExportingMarkdown;
  final String exportStatus;
  final VoidCallback onExportMarkdown;

  final bool autoConvertAlternates;
  final Function(bool?) onAutoConvertAlternatesChanged;
  final bool autoConvertMissing;
  final Function(bool?) onAutoConvertMissingChanged;

  final VoidCallback onRefreshPlaylistDirectory;
  final VoidCallback onRefreshCustomFonts;
  
  const SidePanel({
    super.key,
    required this.panelMode,
    required this.isCollapsed,
    required this.currentAudiobook,
    required this.currentChapterIndex,
    required this.searchQuery,
    required this.searchUseAnd,
    required this.excludeTerms,
    required this.searchController,
    required this.excludeController,
    required this.searchFocusNode,
    required this.excludeFocusNode,
    required this.onClose,
    required this.onToggleCollapse,
    required this.onPanelModeChanged,
    required this.onSearchChanged,
    required this.onExcludeChanged,
    required this.onSearchAndSelected,
    required this.onSearchOrSelected,
    required this.getFilteredChapters,
    required this.onJumpToChapter,
    required this.chapterScrollController,
    required this.skipChapterTerms,
    required this.skipChapterController,
    required this.skipChapterFocusNode,
    required this.onSkipChapterChanged,
    required this.shouldSkipChapter,
    required this.getFilteredHistory,
    required this.onRemoveFromHistory,
    required this.onOpenAudiobook,
    required this.historyScrollController,
    required this.getHistoryDurationAndProgress,
    required this.getFilteredPlaylist,
    required this.playlistScrollController,
    required this.getAudiobookDuration,
    required this.getFilteredBookmarks,
    required this.onRemoveBookmark,
    required this.onJumpToBookmark,
    required this.onSetPinNumber,
    required this.getFilteredFonts,
    required this.selectedFont,
    required this.selectedFontIndex,
    required this.fontScrollController,
    required this.onFontSelected,
    required this.selectedMainCategory,
    required this.selectedSubCategory,
    required this.selectedStudio,
    required this.onCategorySelected,
    required this.customFontDirectory,
    required this.onSetCustomFontDirectory,
    required this.playlistDirectories,
    required this.activePlaylistIndex,
    required this.onAddPlaylistDirectory,
    required this.onRemovePlaylistDirectory,
    required this.onSetActivePlaylist,
    required this.shortenPath,
    required this.onResetConversion,
    required this.onConvertToDemo,
    required this.onConvertToDemoUpper,
    required this.onConvertToAlternates,
    required this.onConvertToMissing,
    required this.onConvertToUppercase,
    required this.onConvertToSeesawCase,
    required this.conversionType,
    required this.getFilteredColors,
    required this.selectedColorIndex,
    required this.colorScrollController,
    required this.onColorPaletteSelected,
    required this.parseColor,
    required this.frequencyItems,
    required this.isAnalyzingFrequencies,
    required this.onAnalyzeFrequencies,
    required this.subtitleFilePath,
    required this.onWordSearch,
    required this.onPhraseSearch,
    required this.subsSearchQuery,
    required this.subsSearchController,
    required this.subsSearchFocusNode,
    required this.onSearchSubtitles,
    required this.buildSearchContent,
    required this.isIndexingChapters,
    required this.indexingStatus,
    required this.indexedFiles,
    required this.totalFilesToIndex,
    required this.hasChapterIndex,
    required this.onIndexPlaylistChapters,
    required this.chapterSearchQuery,
    required this.chapterSearchController,
    required this.chapterSearchFocusNode,
    required this.onSearchPlaylistChapters,
    required this.chapterSearchUseAnd,
    required this.onChapterSearchAndSelected,
    required this.onChapterSearchOrSelected,
    required this.chapterExcludeTerms,
    required this.chapterExcludeController,
    required this.chapterExcludeFocusNode,
    required this.onChapterExcludeChanged,
    required this.statsEntries,
    required this.statsEnabled,
    required this.onStatsEnabledChanged,
    required this.onRefreshStats,
    required this.skipTrackingTerms,
    required this.skipTrackingController,
    required this.skipTrackingFocusNode,
    required this.onSkipTrackingChanged,
    required this.filterEntriesByDate,
    required this.filterEntriesByDays,
    required this.getFileListenTimes,
    required this.groupEntriesByAudiobook,
    required this.formatDurationCompact,
    required this.formatDuration,
    required this.deleteAudiobookFromDate,
    required this.highlightSearchTerm,
    required this.jumpToStatsResult,
    required this.historyCount,
    required this.playlistCount,
    required this.bookmarksCount,
    required this.fontsCount,
    required this.subsCount,
    required this.statsCount,
    required this.coloringMode,
    required this.onColoringModeChanged,
    required this.showPlaylistDirectories,
    required this.onTogglePlaylistDirectories,
    required this.isExportingMarkdown,
    required this.exportStatus,
    required this.onExportMarkdown,
    required this.autoConvertAlternates,
    required this.onAutoConvertAlternatesChanged,
    required this.autoConvertMissing,
    required this.onAutoConvertMissingChanged,
    required this.onRefreshPlaylistDirectory,
    required this.onRefreshCustomFonts,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: isCollapsed ? null : 0,
      width: 800,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          color: const Color(0xFF1E1E1E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              if (!isCollapsed) ...[
                if (panelMode == PanelMode.chapters ||
                    panelMode == PanelMode.history ||
                    panelMode == PanelMode.playlist ||
                    panelMode == PanelMode.bookmarks ||
                    panelMode == PanelMode.fonts ||
                    panelMode == PanelMode.colors ||
                    panelMode == PanelMode.subs ||
                    panelMode == PanelMode.stats) ...[
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: _buildPanelContent(context),
                ),
                if (panelMode == PanelMode.fonts) _buildConversionButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildHeader(BuildContext context) {
   return Container(
     padding: const EdgeInsets.all(16),
     decoration: const BoxDecoration(
       border: Border(
         bottom: BorderSide(color: Colors.white24),
       ),
     ),
     child: Row(
       mainAxisAlignment: MainAxisAlignment.spaceBetween,
       children: [
         Tooltip(
           message: '( ` )',
           waitDuration: const Duration(milliseconds: 500),
           child: IconButton(
             icon: Icon(
               isCollapsed ? Icons.expand_more : Icons.expand_less,
               color: Colors.white,
               size: 20,
             ),
             onPressed: onToggleCollapse,
           ),
         ),
         Expanded(
           child: SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             child: Row(
               children: [
                 _buildTabButton(context, 'Chapters', PanelMode.chapters, currentAudiobook?.chapters.length ?? 0),
                 _buildTabButton(context, 'History', PanelMode.history, historyCount),
                 _buildTabButton(context, 'Playlist', PanelMode.playlist, playlistCount),
                 _buildTabButton(context, 'Bookmarks', PanelMode.bookmarks, bookmarksCount),
                 _buildTabButton(context, 'Fonts', PanelMode.fonts, fontsCount),
                 _buildTabButton(context, 'Colors', PanelMode.colors, ColorPalette.presets.length),
                 _buildTabButton(context, 'Words', PanelMode.words, frequencyItems.length),
                 _buildTabButton(context, 'Subs', PanelMode.subs, subsCount),
                 _buildTabButton(context, 'Stats', PanelMode.stats, statsCount),
               ],
             ),
           ),
         ),
         IconButton(
           icon: const Icon(Icons.close, color: Colors.white),
           onPressed: onClose,
           tooltip: 'Close (Esc)',
         ),
       ],
     ),
   );
 }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: '/ Search... (Ctrl/⌘)⌫',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
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
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('AND', style: TextStyle(fontSize: 12)),
            selected: searchUseAnd,
            onSelected: (selected) => onSearchAndSelected(),
            selectedColor: Colors.deepPurple,
            labelStyle: TextStyle(
              color: searchUseAnd ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(width: 4),
          ChoiceChip(
            label: const Text('OR', style: TextStyle(fontSize: 12)),
            selected: !searchUseAnd,
            onSelected: (selected) => onSearchOrSelected(),
            selectedColor: Colors.deepPurple,
            labelStyle: TextStyle(
              color: !searchUseAnd ? Colors.white : Colors.white54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: excludeController,
              focusNode: excludeFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Exclude...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.block, color: Colors.white54, size: 20),
                suffixIcon: excludeTerms.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                        onPressed: () {
                          excludeController.clear();
                          onExcludeChanged('');
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
              onChanged: onExcludeChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String label, PanelMode mode, int count) {
    final isActive = panelMode == mode;
    
    final isSpecialCollapsed = isCollapsed && 
        (mode == PanelMode.fonts || mode == PanelMode.colors);
    
    int? underlineIndex;
    switch (mode) {
      case PanelMode.chapters:
        underlineIndex = 0;
        break;
      case PanelMode.history:
        underlineIndex = 0;
        break;
      case PanelMode.playlist:
        underlineIndex = 0;
        break;
      case PanelMode.bookmarks:
        underlineIndex = 0;
        break;
      case PanelMode.fonts:
        underlineIndex = 0;
        break;
      case PanelMode.colors:
        underlineIndex = 4;
        break;
      case PanelMode.words:
        underlineIndex = 0;
        break;
      case PanelMode.subs:
        underlineIndex = 0;
        break;
      case PanelMode.stats:
        underlineIndex = 1;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: () => onPanelModeChanged(mode),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? Colors.deepPurple : Colors.transparent,
          foregroundColor: isSpecialCollapsed ? Colors.teal : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: _buildLabelWithUnderline(label, underlineIndex, isSpecialCollapsed),
            ),
            const SizedBox(height: 2),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10, 
                color: isSpecialCollapsed ? Colors.teal[200] : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildLabelWithUnderline(String text, int underlineIndex, bool isSpecialCollapsed) {
    final children = <TextSpan>[];
    final textColor = isSpecialCollapsed ? Colors.teal : Colors.white;
    
    for (int i = 0; i < text.length; i++) {
      children.add(TextSpan(
        text: text[i],
        style: TextStyle(
          color: textColor,
          decoration: i == underlineIndex ? TextDecoration.underline : null,
          decorationColor: textColor,
          decorationThickness: 1.5,
        ),
      ));
    }
    return TextSpan(children: children);
  }

  Widget _buildPanelContent(BuildContext context) {
    switch (panelMode) {
      case PanelMode.chapters:
        return _buildChapterList(context);
      case PanelMode.history:
        return _buildHistoryList(context);
      case PanelMode.playlist:
        return _buildPlaylistList(context);
      case PanelMode.bookmarks:
        return _buildBookmarksList(context);
      case PanelMode.fonts:
        return _buildFontsList(context);
      case PanelMode.colors:
        return _buildColorsList(context);
      case PanelMode.words:
        return _buildWordsList(context);
      case PanelMode.subs:
        return _buildSubsPanel(context);
      case PanelMode.stats:
        return StatsPanel(
          statsEntries: statsEntries,
          statsEnabled: statsEnabled,
          onStatsEnabledChanged: onStatsEnabledChanged,
          onRefreshStats: onRefreshStats,
          skipTrackingTerms: skipTrackingTerms,
          skipTrackingController: skipTrackingController,
          skipTrackingFocusNode: skipTrackingFocusNode,
          onSkipTrackingChanged: onSkipTrackingChanged,
          searchQuery: searchQuery,
          excludeTerms: excludeTerms,
          filterEntriesByDate: filterEntriesByDate,
          filterEntriesByDays: filterEntriesByDays,
          getFileListenTimes: getFileListenTimes,
          groupEntriesByAudiobook: groupEntriesByAudiobook,
          formatDurationCompact: formatDurationCompact,
          formatDuration: formatDuration,
          deleteAudiobookFromDate: deleteAudiobookFromDate,
          highlightSearchTerm: highlightSearchTerm,
          jumpToStatsResult: jumpToStatsResult,
        );
    }
  }

  Widget _buildChapterList(BuildContext context) {
    final filteredChapters = getFilteredChapters();
    if (filteredChapters.isEmpty) {
      return const Center(
        child: Text(
          'No chapters match search',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: Row(
            children: [
              const Text(
                'Skip Chapters:',
                style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: skipChapterController,
                  focusNode: skipChapterFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'any of these terms',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.skip_next, color: Colors.white54, size: 20),
                    suffixIcon: skipChapterTerms.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                            onPressed: () {
                              skipChapterController.clear();
                              onSkipChapterChanged('');
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
                  onChanged: onSkipChapterChanged,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: chapterScrollController,
            itemCount: filteredChapters.length,
            itemBuilder: (context, index) {
              final chapter = filteredChapters[index];
              final actualIndex = currentAudiobook!.chapters.indexOf(chapter);
              final isActive = actualIndex == currentChapterIndex;
              final shouldSkip = shouldSkipChapter(chapter.title);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: shouldSkip 
                      ? Colors.red.withAlpha(128)
                      : (isActive ? Colors.deepPurple : const Color(0xFF006064)),
                  radius: 12,
                  child: Text(
                    '${actualIndex + 1}',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                title: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: shouldSkip
                          ? Colors.red.withAlpha(179)
                          : (isActive ? Colors.purple[200] : Colors.white),
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    children: [
                      TextSpan(text: '$ltr${chapter.title}'),
                      TextSpan(
                        text: ' ${chapter.formattedDuration}',
                        style: TextStyle(
                          color: shouldSkip ? Colors.red.withAlpha(128) : Colors.lightBlue,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () => onJumpToChapter(actualIndex),
                tileColor: isActive ? Colors.deepPurple.withAlpha(51) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  double _parseProgress(String progressStr) {
    final cleaned = progressStr.replaceAll('%', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  Widget _buildHistoryList(BuildContext context) {
    final filteredHistory = getFilteredHistory();
    if (filteredHistory.isEmpty) {
      return const Center(
        child: Text(
          'No history matches search',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return ListView.builder(
      controller: historyScrollController,
      itemCount: filteredHistory.length,
      itemBuilder: (context, index) {
        final item = filteredHistory[index];
        return FutureBuilder<Map<String, dynamic>>(
          future: getHistoryDurationAndProgress(item.audiobookPath, item.lastPosition),
          builder: (context, snapshot) {
            return ListTile(
              leading: index < 9
                  ? Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : CircleAvatar(
                      backgroundColor: const Color(0xFF006064),
                      radius: 12,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                    ),
              title: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  children: [
                    TextSpan(text: item.audiobookTitle),
                    if (snapshot.hasData) ...[
                      TextSpan(
                        text: ' \u200E${snapshot.data!['duration']}',
                        style: const TextStyle(color: Colors.lightBlue),
                      ),
                      if (snapshot.data!['progress'] != null && 
                          snapshot.data!['progress'].toString().isNotEmpty &&
                          _parseProgress(snapshot.data!['progress'].toString()) > 0.9)
                        TextSpan(
                          text: ' \u200E${snapshot.data!['progress']}',
                          style: TextStyle(color: Colors.purple[200]),
                        ),
                    ],
                  ],
                ),
              ),
              subtitle: Text(
                '$ltr${item.chapterTitle} • ${_formatDuration(item.lastPosition)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.white54, size: 18),
                onPressed: () => onRemoveFromHistory(index),
              ),
              onTap: () => onOpenAudiobook(item.audiobookPath),
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistList(BuildContext context) {
    final filteredPlaylist = getFilteredPlaylist();
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => onTogglePlaylistDirectories(!showPlaylistDirectories),
                child: Row(
                  children: [
                    Icon(
                      showPlaylistDirectories ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Set Playlist Directories',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
                      onPressed: onRefreshPlaylistDirectory,
                      tooltip: 'Refresh playlist',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${playlistDirectories.length}/10',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (showPlaylistDirectories) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: onAddPlaylistDirectory,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('Add Playlist Directory (${playlistDirectories.length}/10)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (playlistDirectories.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...playlistDirectories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dir = entry.value;
                    final isActive = activePlaylistIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tooltip(
                        message: shortenPath(dir),
                        waitDuration: const Duration(milliseconds: 500),
                        child: InkWell(
                          onTap: () => onSetActivePlaylist(index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.deepPurple.withAlpha(102) : Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                              border: isActive ? Border.all(color: Colors.deepPurple, width: 2) : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    path.basename(dir),
                                    style: TextStyle(
                                      color: isActive ? Colors.purple[200] : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.white54),
                                  iconSize: 16,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => onRemovePlaylistDirectory(index),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
        Expanded(
          child: filteredPlaylist.isEmpty
              ? const Center(
                  child: Text(
                    'No playlist items',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  controller: playlistScrollController,
                  itemCount: filteredPlaylist.length,
                  itemBuilder: (context, index) {
                    final filePath = filteredPlaylist[index];
                    final fileName = path.basenameWithoutExtension(filePath);
                    final isActive = currentAudiobook?.path == filePath;
                    return FutureBuilder<String>(
                      future: getAudiobookDuration(filePath),
                      builder: (context, snapshot) {
                        return ListTile(
                          leading: index < 9
                              ? Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: isActive ? Colors.deepPurple : const Color(0xFF006064),
                                  radius: 12,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 10, color: Colors.white),
                                  ),
                                ),
                          title: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: isActive ? Colors.purple[200] : Colors.white,
                                fontSize: 14,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                              children: [
                                TextSpan(text: fileName),
                                if (snapshot.hasData)
                                  TextSpan(
                                    text: ' ${snapshot.data}',
                                    style: const TextStyle(
                                      color: Colors.lightBlue,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          onTap: () => onOpenAudiobook(filePath),
                          tileColor: isActive ? Colors.deepPurple.withAlpha(51) : null,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookmarksList(BuildContext context) {
      final filteredBookmarks = getFilteredBookmarks();
      if (filteredBookmarks.isEmpty) {
        return const Center(
          child: Text(
            'No bookmarks yet\nPress n to add',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54),
          ),
        );
      }
    
      final pinnedBookmarks = filteredBookmarks.where((b) => b.pinNumber != null).toList()
        ..sort((a, b) => a.pinNumber!.compareTo(b.pinNumber!));
      
      final unpinnedBookmarks = filteredBookmarks.where((b) => b.pinNumber == null).toList()
        ..sort((a, b) {
          final pathCompare = a.audiobookPath.compareTo(b.audiobookPath);
          if (pathCompare != 0) return pathCompare;
          return a.chapterTitle.compareTo(b.chapterTitle);
        });
    
      final Map<String, List<Bookmark>> groupedUnpinned = {};
      for (final bookmark in unpinnedBookmarks) {
        groupedUnpinned.putIfAbsent(bookmark.audiobookPath, () => []).add(bookmark);
      }
    
      final usedPinNumbers = pinnedBookmarks.map((b) => b.pinNumber!).toSet();
      final availablePinNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
          .where((num) => !usedPinNumbers.contains(num))
          .toList();
      final nextAvailablePin = availablePinNumbers.isNotEmpty ? availablePinNumbers.first : null;
    
      return ListView(
        controller: historyScrollController,
        children: [
          ...pinnedBookmarks.map((bookmark) {
            final audiobookName = path.basenameWithoutExtension(bookmark.audiobookPath);
            final actualIndex = filteredBookmarks.indexOf(bookmark);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                dense: true,
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      '${bookmark.pinNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  audiobookName,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${bookmark.chapterTitle} • ${_formatDuration(bookmark.position)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.push_pin, color: Colors.deepPurple, size: 18),
                      onPressed: () => onSetPinNumber(actualIndex, null),
                      tooltip: 'Unpin',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white54, size: 18),
                      onPressed: () => onRemoveBookmark(actualIndex),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                onTap: () => onJumpToBookmark(bookmark),
              ),
            );
          }),
          
          if (pinnedBookmarks.isNotEmpty && unpinnedBookmarks.isNotEmpty)
            const Divider(color: Colors.white24, thickness: 2, height: 32),
          
          ...groupedUnpinned.entries.toList().asMap().entries.map((groupEntry) {
            final groupIndex = groupEntry.key;
            final entry = groupEntry.value;
            final audiobookPath = entry.key;
            final bookmarks = entry.value;
            final audiobookName = path.basenameWithoutExtension(audiobookPath);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.grey[850],
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFF006064),
                        radius: 12,
                        child: Text(
                          '${groupIndex + 1}',
                          style: const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          audiobookName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ...bookmarks.asMap().entries.map((bookmarkEntry) {
                  final bookmark = bookmarkEntry.value;
                  final actualIndex = filteredBookmarks.indexOf(bookmark);
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      title: Text(
                        bookmark.chapterTitle,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatDuration(bookmark.position),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (nextAvailablePin != null)
                            IconButton(
                              icon: const Icon(Icons.push_pin_outlined, color: Colors.white54, size: 18),
                              onPressed: () => onSetPinNumber(actualIndex, nextAvailablePin),
                              tooltip: 'Pin to slot $nextAvailablePin',
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white54, size: 18),
                            onPressed: () => onRemoveBookmark(actualIndex),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                      onTap: () => onJumpToBookmark(bookmark),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            );
          }),
        ],
      );
    }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours == 0 && minutes == 0) {
      return '';
    }
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildConversionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white24)),
        color: Color(0xFF252525),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Convert subtitle to:',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (conversionType != 'none')
                Text(
                  'Current: $conversionType',
                  style: const TextStyle(color: Colors.lightBlue, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _buildConversionButton('1original', onResetConversion),
              _buildConversionButton('2demo', onConvertToDemo),
              _buildConversionButton('3demoUppercase', onConvertToDemoUpper),
              _buildConversionButton('4alternates', onConvertToAlternates),
              _buildConversionButton('5missing', onConvertToMissing),
              _buildConversionButton('6Uppercase', onConvertToUppercase),
              _buildConversionButton('7SeEsAwCaSe', onConvertToSeesawCase),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversionButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

 Widget _buildColorsList(BuildContext context) {
   final filteredColors = getFilteredColors();
   if (filteredColors.isEmpty) {
     return const Center(
       child: Text(
         'No color palettes match search',
         style: TextStyle(color: Colors.white54),
       ),
     );
   }
   
   return Column(
     children: [
       Padding(
         padding: const EdgeInsets.all(16.0),
         child: Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             _buildColoringModeButton(ColoringMode.words, ' (1) Words', null),
             const SizedBox(width: 12),
             _buildColoringModeButton(ColoringMode.letters, '(2) Letters', 'breaks on ligature fonts'),
           ],
         ),
       ),
       const Divider(color: Colors.white24, height: 1),
       Expanded(
         child: ListView.builder(
           controller: colorScrollController,
           padding: const EdgeInsets.all(16),
           itemCount: filteredColors.length,
           itemBuilder: (context, index) {
             final palette = filteredColors[index];
             final actualIndex = ColorPalette.presets.indexOf(palette);
             final isSelected = selectedColorIndex == actualIndex;
             
             return InkWell(
               onTap: () => onColorPaletteSelected(palette, actualIndex),
               child: Container(
                 margin: const EdgeInsets.only(bottom: 12),
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: isSelected ? Colors.deepPurple.withAlpha(51) : Colors.black26,
                   borderRadius: BorderRadius.circular(8),
                   border: isSelected 
                       ? Border.all(color: Colors.deepPurple, width: 2)
                       : null,
                 ),
                 child: Row(
                   children: [
                     Expanded(
                       child: Text(
                         palette.name,
                         style: TextStyle(
                           color: isSelected ? Colors.purple[200] : Colors.white,
                           fontSize: 14,
                           fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                         ),
                       ),
                     ),
                     const SizedBox(width: 12),
                     if (palette.isSimplePreset)
                       Container(
                         width: 280,
                         height: 20,
                         decoration: BoxDecoration(
                           color: parseColor(palette.colors[0]),
                           border: Border.all(
                             color: parseColor(palette.subShadowColor!),
                             width: 4,
                           ),
                           borderRadius: BorderRadius.circular(4),
                         ),
                       )
                     else
                       ...palette.colors.map((color) => Container(
                         width: 20,
                         height: 20,
                         margin: const EdgeInsets.only(left: 4),
                         decoration: BoxDecoration(
                           color: parseColor(color),
                           borderRadius: BorderRadius.circular(4),
                           border: Border.all(color: Colors.white24),
                         ),
                       )),
                   ],
                 ),
               ),
             );
           },
         ),
       ),
     ],
   );
 }
 
 Widget _buildColoringModeButton(ColoringMode mode, String label, String? tooltip) {
   final isActive = coloringMode == mode;
   
   final button = ElevatedButton(
     onPressed: () => onColoringModeChanged(mode),
     style: ElevatedButton.styleFrom(
       backgroundColor: isActive ? const Color(0xFF667eea) : const Color(0xFF4D2C86),
       foregroundColor: isActive ? Colors.white : const Color(0xFF667EEA),
       side: const BorderSide(
         color: Color(0xFF667eea),
         width: 2,
       ),
       padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(8),
       ),
       elevation: isActive ? 2 : 0,
     ),
     child: Text(
       label,
       style: const TextStyle(
         fontSize: 16,
         fontWeight: FontWeight.w600,
       ),
     ),
   );
   
   if (tooltip != null) {
     return Tooltip(
       message: tooltip,
       child: button,
     );
   }
   
   return button;
 }

  Widget _buildWordsList(BuildContext context) {
    if (isAnalyzingFrequencies) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Analyzing subtitle frequencies...\nThis runs in the background.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    
    if (frequencyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No frequency data yet',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            if (subtitleFilePath != null && onAnalyzeFrequencies != null)
              ElevatedButton.icon(
                onPressed: onAnalyzeFrequencies,
                icon: const Icon(Icons.analytics),
                label: const Text('Analyze Frequencies Now'),
              )
            else
              const Text(
                'Load subtitles first',
                style: TextStyle(color: Colors.white38),
              ),
          ],
        ),
      );
    }
  
    final groupedByWordCount = <int, List<FrequencyItem>>{};
    for (final item in frequencyItems) {
      groupedByWordCount.putIfAbsent(item.wordCount, () => []).add(item);
    }
    
    final orderedKeys = groupedByWordCount.keys.toList()..sort((a, b) {
      if (a == 1) return -1;
      if (b == 1) return 1;
      return b.compareTo(a);
    });
    
    final limitedGroups = <int, List<FrequencyItem>>{};
    
    for (final key in orderedKeys) {
      final items = groupedByWordCount[key]!;
      if (key == 1) {
        limitedGroups[key] = items.take(500).toList();
      } else {
        limitedGroups[key] = items.take(200).toList();
      }
    }
    
    return _WordsPanel(
      orderedKeys: orderedKeys,
      limitedGroups: limitedGroups,
      hasSearchQuery: false,
      onWordSearch: onWordSearch,
      onPhraseSearch: onPhraseSearch,
    );
  }

  Widget _buildSubsPanel(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onSearchSubtitles(subsSearchQuery),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Search Subtitles & Paragraphs'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: isExportingMarkdown ? null : onExportMarkdown,
                    icon: isExportingMarkdown 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.file_download),
                    label: const Text('Export md'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Tooltip(
                      message: hasChapterIndex 
                          ? 'Chapter index loaded'
                          : 'Index all chapters in current playlist',
                      child: ElevatedButton.icon(
                        onPressed: isIndexingChapters ? null : (hasChapterIndex ? null : onIndexPlaylistChapters),
                        icon: isIndexingChapters
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                hasChapterIndex ? Icons.check_circle : Icons.manage_search,
                                color: Colors.white,
                              ),
                        label: Text(hasChapterIndex 
                            ? 'Search Playlist Chapters' 
                            : 'Index Playlist Chapters'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isExportingMarkdown) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          exportStatus,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isIndexingChapters) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: totalFilesToIndex > 0 ? indexedFiles / totalFilesToIndex : 0,
                ),
                const SizedBox(height: 4),
                Text(
                  indexingStatus,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
              if (hasChapterIndex) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: chapterSearchController,
                        focusNode: chapterSearchFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search playlist chapters...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                          suffixIcon: chapterSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                                  onPressed: () {
                                    chapterSearchController.clear();
                                    onSearchPlaylistChapters('');
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
                        onChanged: onSearchPlaylistChapters,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('AND', style: TextStyle(fontSize: 12)),
                      selected: chapterSearchUseAnd,
                      onSelected: (selected) => onChapterSearchAndSelected(),
                      selectedColor: Colors.lightBlue,
                      labelStyle: TextStyle(
                        color: chapterSearchUseAnd ? Colors.white : Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ChoiceChip(
                      label: const Text('OR', style: TextStyle(fontSize: 12)),
                      selected: !chapterSearchUseAnd,
                      onSelected: (selected) => onChapterSearchOrSelected(),
                      selectedColor: Colors.lightBlue,
                      labelStyle: TextStyle(
                        color: !chapterSearchUseAnd ? Colors.white : Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: chapterExcludeController,
                        focusNode: chapterExcludeFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Exclude...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.block, color: Colors.white54, size: 20),
                          suffixIcon: chapterExcludeTerms.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                                  onPressed: () {
                                    chapterExcludeController.clear();
                                    onChapterExcludeChanged('');
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
                        onChanged: onChapterExcludeChanged,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: buildSearchContent(),
        ),
      ],
    );
  }

  Widget _buildFontsList(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              if (subsSearchQuery.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Load subtitles to preview fonts. Use ↑↓ arrow keys.',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: _buildFontListView(context),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          color: Colors.white24,
        ),
        Expanded(
          flex: 2,
          child: _buildCategoryTree(context),
        ),
      ],
    );
  }

  Widget _buildFontListView(BuildContext context) {
    final filteredFonts = getFilteredFonts();
    if (filteredFonts.isEmpty) {
      return const Center(
        child: Text('No fonts match', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      controller: fontScrollController,
      itemCount: filteredFonts.length,
      itemExtent: 56.0,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final fontName = filteredFonts[index];
        final isSelected = fontName == selectedFont;
        
        return ListTile(
          dense: true,
          leading: Icon(
            isSelected ? Icons.check_circle : Icons.font_download,
            color: isSelected ? Colors.deepPurple : Colors.white54,
            size: 18,
          ),
          title: Text(
            fontName,
            style: TextStyle(
              color: isSelected ? Colors.purple[200] : Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          onTap: () => onFontSelected(fontName, index),
          tileColor: isSelected ? Colors.deepPurple.withAlpha(51) : null,
        );
      },
    );
  }

  Widget _buildCategoryTree(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        _buildCategoryButton('All Fonts', 'all', null, null),
        const Divider(color: Colors.white24),
        _buildCategoryButton('demo123', FontCategory.demo123, null, null),
        if (selectedMainCategory == FontCategory.demo123) ...[
          _buildSubCategoryButton('ligatures', FontCategory.ligatures),
          if (selectedSubCategory == FontCategory.ligatures) ...[
            _buildStudioButton('177studio', FontCategory.studio177),
            _buildStudioButton('Dhabee', FontCategory.dhabee),
            _buildStudioButton('Putracetol', FontCategory.putracetol),
            _buildStudioButton('Various', FontCategory.various),
          ],
          _buildSubCategoryButton('Dhabee123', null, studio: FontCategory.dhabee123),
          _buildSubCategoryButton('Erifqizefont123', null, studio: FontCategory.erifqizefont123),
          _buildSubCategoryButton('Putracetol123', null, studio: FontCategory.putracetol123),
          _buildSubCategoryButton('Various', null, studio: FontCategory.various),
          _buildSubCategoryButton('UPPERCASE', FontCategory.uppercase),
          _buildSubCategoryButton('MustBeUPPERCASE', FontCategory.mustBeUppercase),
          if (selectedSubCategory == FontCategory.mustBeUppercase) ...[
            _buildStudioButton('Putracetol', FontCategory.putracetol),
          ],
          _buildSubCategoryButton('sEeSaWcAsE', FontCategory.seesawcase),
        ],
        const Divider(color: Colors.white24),
        _buildCategoryButton('demo', FontCategory.demo, null, null),
        if (selectedMainCategory == FontCategory.demo) ...[
          _buildSubCategoryButton('ligatures', FontCategory.ligatures),
          if (selectedSubCategory == FontCategory.ligatures) ...[
            _buildStudioButton('Putracetol', FontCategory.putracetol),
            _buildStudioButton('177studio', FontCategory.studio177),
            _buildStudioButton('Various', FontCategory.various),
          ],
          _buildSubCategoryButton('missingligatures', FontCategory.missingLigatures),
          if (selectedSubCategory == FontCategory.missingLigatures) ...[
            _buildStudioButton('177studio', FontCategory.studio177),
          ],
          _buildSubCategoryButton('alternates', FontCategory.alternates),
          _buildSubCategoryButton('UPPERCASE', FontCategory.uppercase),
          if (selectedSubCategory == FontCategory.uppercase) ...[
            _buildStudioButton('177studio', FontCategory.studio177),
          ],
          _buildSubCategoryButton('MustBeUPPERCASE', FontCategory.mustBeUppercase),
          if (selectedSubCategory == FontCategory.mustBeUppercase) ...[
            _buildStudioButton('177studio', FontCategory.studio177),
          ],
        ],
        const Divider(color: Colors.white24),
        _buildCategoryButton('free', FontCategory.free, null, null),
        if (selectedMainCategory == FontCategory.free) ...[
          _buildSubCategoryButton('ligatures', FontCategory.ligatures),
          if (selectedSubCategory == FontCategory.ligatures) ...[
            _buildStudioButton('Gluk', FontCategory.gluk),
          ],
          _buildSubCategoryButton('Various', null, studio: FontCategory.various),
          _buildSubCategoryButton('foreign', FontCategory.foreign),
        ],
        if (customFontDirectory != null) ...[
          const Divider(color: Colors.white24),
          _buildCategoryButton('custom', FontCategory.custom, null, null),
        ],
        const Divider(color: Colors.white24),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Automatic Conversion',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text(
                  'alternates',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                value: autoConvertAlternates,
                onChanged: onAutoConvertAlternatesChanged,
                activeColor: Colors.deepPurple,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              CheckboxListTile(
                title: const Text(
                  'missing',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                value: autoConvertMissing,
                onChanged: onAutoConvertMissingChanged,
                activeColor: Colors.deepPurple,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onSetCustomFontDirectory,
                icon: const Icon(Icons.folder, size: 16),
                label: const Text('Set Font Directory'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
              ),
              if (customFontDirectory != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: shortenPath(customFontDirectory!),
                        waitDuration: const Duration(milliseconds: 500),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            path.basename(customFontDirectory!),
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
                      onPressed: onRefreshCustomFonts,
                      tooltip: 'Refresh fonts',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

 Widget _buildCategoryButton(String label, String category, String? subCat, String? studio) {
    final isSelected = selectedMainCategory == category && 
                       selectedSubCategory == subCat && 
                       selectedStudio == studio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextButton(
        onPressed: () => onCategorySelected(category, subCat, studio),
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? Colors.deepPurple : Colors.transparent,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildSubCategoryButton(String label, String? subCat, {String? studio}) {
    final isSelected = selectedSubCategory == subCat && selectedStudio == studio;
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
      child: TextButton(
        onPressed: () => onCategorySelected(selectedMainCategory, subCat, studio),
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? Colors.deepPurple.withAlpha(128) : Colors.transparent,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
  
  Widget _buildStudioButton(String label, String studio) {
    final isSelected = selectedStudio == studio;
    return Padding(
      padding: const EdgeInsets.only(left: 32, top: 2, bottom: 2),
      child: TextButton(
        onPressed: () => onCategorySelected(selectedMainCategory, selectedSubCategory, studio),
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? Colors.deepPurple.withAlpha(64) : Colors.transparent,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _WordsPanel extends StatefulWidget {
  final List<int> orderedKeys;
  final Map<int, List<FrequencyItem>> limitedGroups;
  final bool hasSearchQuery;
  final Function(String) onWordSearch;
  final Function(String) onPhraseSearch;

  const _WordsPanel({
    required this.orderedKeys,
    required this.limitedGroups,
    required this.hasSearchQuery,
    required this.onWordSearch,
    required this.onPhraseSearch,
  });

  @override
  State<_WordsPanel> createState() => _WordsPanelState();
}

class _WordsPanelState extends State<_WordsPanel> {
  int? _selectedCategory = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAllCategories = widget.hasSearchQuery || _selectedCategory == null;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white24)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...widget.orderedKeys.map((wordCount) {
                final label = wordCount == 1 ? 'Words' : '$wordCount-Word';
                final count = widget.limitedGroups[wordCount]?.length ?? 0;
                final isSelected = _selectedCategory == wordCount;
                return TextButton(
                  onPressed: widget.hasSearchQuery ? null : () {
                    setState(() {
                      _selectedCategory = wordCount;
                    });
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: widget.hasSearchQuery
                        ? Colors.deepPurple.withAlpha(64)
                        : (isSelected ? Colors.deepPurple : Colors.deepPurple.withAlpha(64)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    disabledBackgroundColor: Colors.deepPurple.withAlpha(64),
                  ),
                  child: Text(
                    '$label ($count)',
                    style: TextStyle(
                      color: widget.hasSearchQuery ? Colors.white54 : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        Expanded(
          child: _buildCategoryContent(showAllCategories),
        ),
      ],
    );
  }

  Widget _buildCategoryContent(bool showAll) {
    if (showAll) {
      return _buildAllCategoriesList();
    } else if (_selectedCategory != null) {
      return _buildSingleCategoryList(_selectedCategory!);
    } else {
      return _buildAllCategoriesList();
    }
  }

  Widget _buildAllCategoriesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: widget.orderedKeys.fold<int>(
        0,
        (sum, key) => sum + widget.limitedGroups[key]!.length + 1,
      ),
      itemBuilder: (context, index) {
        int currentIndex = 0;
        for (final wordCount in widget.orderedKeys) {
          final items = widget.limitedGroups[wordCount]!;
          if (index == currentIndex) {
            final label = wordCount == 1
                ? 'Top 500 Words (${items.length})'
                : '$wordCount-Word Phrases (${items.length})';
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.purple[200],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          currentIndex++;
          final sectionItemIndex = index - currentIndex;
          if (sectionItemIndex >= 0 && sectionItemIndex < items.length) {
            final item = items[sectionItemIndex];
            return _buildFrequencyItem(item);
          }
          currentIndex += items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSingleCategoryList(int wordCount) {
    final items = widget.limitedGroups[wordCount] ?? [];
    final label = wordCount == 1
        ? 'Top 500 Words (${items.length})'
        : '$wordCount-Word Phrases (${items.length})';

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.purple[200],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }
        return _buildFrequencyItem(items[index - 1]);
      },
    );
  }

  Widget _buildFrequencyItem(FrequencyItem item) {
    final isSingleWord = item.wordCount == 1;
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: item.text));
        
        if (isSingleWord) {
          widget.onWordSearch(item.text);
        } else {
          widget.onPhraseSearch('"${item.text}"');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${item.frequency}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              isSingleWord ? Icons.search : Icons.manage_search,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}