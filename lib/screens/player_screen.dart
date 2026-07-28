import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:image/image.dart' as img;
import 'package:substitcher/models/pause_mode.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math';
import 'metadata_editor_screen.dart';
import 'encoder_screen.dart';
import '../data/lut_list.dart';
import '../models/adhan_settings.dart';
import '../models/audiobook_metadata.dart';
import '../models/font_category.dart';
import '../models/color_palette.dart';
import '../models/frequency_item.dart';
import '../models/history_item.dart';
import '../models/bookmark.dart';
import '../models/subtitle_cue.dart';
import '../models/pause_mode.dart';
import '../models/subtitle_preferences.dart';
import '../models/lut_item.dart';
import '../models/vtt_show_style.dart';
import '../services/vtt_show_service.dart';
import '../services/cjk_tokenizer.dart';
import '../services/ffmpeg_service.dart';
import '../services/font_loader.dart';
import '../services/custom_font_metadata.dart';
import '../services/font_database.dart';
import '../services/subtitle_transformer.dart';
import '../services/font_alternates_data.dart';
import '../services/subtitle_organizer.dart';
import '../services/frequency_analyzer.dart';
import '../services/stats_manager.dart';
import '../services/adhan_clock_service.dart';
import '../services/youtube_service.dart';
import '../services/video_edit_service.dart';
import '../services/vision_tracking_service.dart';
import '../services/lut_thumbnail_service.dart';
import '../services/lut_processor.dart';
import '../services/vtt_show_service.dart';
import '../widgets/adhan_clock_overlay.dart';
import '../widgets/subtitle_manager_dialog.dart';
import '../widgets/side_panel.dart';
import '../widgets/stats_panel.dart';
import '../widgets/player_controls.dart';
import '../widgets/word_overlay.dart';
import '../widgets/download_overlay.dart';
import '../widgets/cuts_overlay.dart';
import '../widgets/encode_progress_overlay.dart';
import '../widgets/lut_picker_overlay.dart';
import '../widgets/vtt_show_edit_overlay.dart';
import '../widgets/youtube_dialog.dart';
import '../widgets/quran_panel.dart';
import '../quran/quran_index.dart';
import '../quran/quran_verse_search_index.dart';

enum FontColorOverride { none, black, white }

class SubtitleSearchResult {
  final Duration time;
  final String text;

  SubtitleSearchResult({
    required this.time,
    required this.text,
  });
}

class ParagraphItem {
  final int chapterNumber;
  final int paragraphNumber;
  final String text;

  ParagraphItem({
    required this.chapterNumber,
    required this.paragraphNumber,
    required this.text,
  });
}

class ChapterSearchResult {
  final String audiobookPath;
  final String audiobookTitle;
  final int chapterIndex;
  final String chapterTitle;
  final Duration startTime;

  ChapterSearchResult({
    required this.audiobookPath,
    required this.audiobookTitle,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.startTime,
  });
}

class StatsSearchResult {
  final String audiobookPath;
  final String audiobookTitle;
  final String chapterTitle;
  final Duration startTime;

  StatsSearchResult({
    required this.audiobookPath,
    required this.audiobookTitle,
    required this.chapterTitle,
    required this.startTime,
  });
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  static const double _universalShadowOffset = 6.0;
  static const double _universalStrokeWidth = 3.0;
  FontColorOverride _fontColorOverride = FontColorOverride.none;
  FontColorOverride _secondaryFontColorOverride = FontColorOverride.none;
  bool _secondaryBlurShadowEnabled = false;
  late final WindowListener _windowListener;
  final FFmpegService _ffmpeg = FFmpegService();
  final player = Player();
  late final VideoController _videoController;
  final ItemScrollController _chapterScrollController = ItemScrollController();
  final ScrollController _playlistScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  int _activeFfprobeCount = 0;
  final int _maxConcurrentFfprobe = 3;

  AudiobookMetadata? _currentAudiobook;
  int _currentChapterIndex = 0;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  int _fileSize = 0;
  int _averageBitrate = 0;
  bool _shuffleEnabled = false;
  String _conversionType = 'none';
  List<int> _playedChapters = [];

  bool _showPanel = false;
  PanelMode _panelMode = PanelMode.chapters;
  bool _panelCollapsed = false;
  ColorPalette? _currentColorPalette;
  int _selectedColorIndex = 0;
  final ItemScrollController _colorItemScrollController =
      ItemScrollController();
  final ItemScrollController _lutItemScrollController = ItemScrollController();
  bool _showEncoderScreen = false;
  final List<int> _cueWordStarts = [];

  final ItemScrollController _quranItemScrollController =
      ItemScrollController();

  bool _showWordOverlay = false;
  double? _sliderHoverPosition;
  String? _hoveredChapterTitle;

  Map<String, List<Chapter>> _playlistChapterIndex = {};
  bool _isIndexingChapters = false;
  String _indexingStatus = '';
  int _indexedFiles = 0;
  int _totalFilesToIndex = 0;
  List<ChapterSearchResult> _chapterSearchResults = [];
  String _chapterSearchQuery = '';
  final TextEditingController _chapterSearchController =
      TextEditingController();
  final FocusNode _chapterSearchFocusNode = FocusNode();

  List<HistoryItem> _history = [];
  List<Bookmark> _bookmarks = [];
  List<String> _playlist = [];
  String? _playlistRootDir;
  List<String> _playlistDirectories = [];
  int? _activePlaylistIndex;
  final Map<String, String> _playlistDurationCache = {};
  int? _youtubePlaylistCurrentIndex; // 0-based
  int? _youtubePlaylistTotal;

  Timer? _frequencyGenerationTimer;

  int? _currentSubtitleIndex;
  List<SubtitleCue> _subtitles = [];
  String _currentSubtitleText = '';
  String? _subtitleFilePath;
  double _subtitleFontSize = 86.0;

  List<SubtitleCue> _originalSubtitles = [];
  List<SubtitleCue> _secondaryOriginalSubtitles = [];
  String? _lastDebuggedSubtitle;

  Timer? _dictionaryModeExitTimer;
  bool _hideChapterTitle = false;

  String _statsSearchQuery = '';
  final TextEditingController _statsSearchController = TextEditingController();
  final FocusNode _statsSearchFocusNode = FocusNode();

  String _searchQuery = '';
  bool _searchUseAnd = true;
  String _excludeTerms = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _excludeController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _excludeFocusNode = FocusNode();
  final FocusNode _quranSearchFocusNode = FocusNode();
  final FocusNode _quranExcludeFocusNode = FocusNode();
  final FocusNode _hadeethSearchFocusNode = FocusNode();
  final FocusNode _hadeethExcludeFocusNode = FocusNode();
  final FocusNode _tafsirSearchFocusNode = FocusNode();

  String _quranSearchQuery = '';
  String _quranExcludeQuery = '';
  final TextEditingController _tafsirSearchController = TextEditingController();
  final TextEditingController _quranSearchController = TextEditingController();
  final TextEditingController _quranExcludeController = TextEditingController();
  int? _activeQuranFilteredIndex;
  String _quranIndexLanguage = 'English';
  final FocusNode _quranRefInputFocusNode = FocusNode();

  final QuranVerseSearchIndex _quranVerseSearchIndex = QuranVerseSearchIndex();
  bool _quranVerseSearchMode = false;
  final TextEditingController _quranVerseSearchController = TextEditingController();
  final FocusNode _quranVerseSearchFocusNode = FocusNode();
  List<QuranAyahSearchHit> _quranVerseSearchResults = [];
  bool _quranVerseIndexBuilding = false;

  String _defaultFont = 'System Default';
  String? _defaultColorPalette;
  String _defaultConversionType = 'none';
  ColorPaletteFilter _defaultColorCategoryFilter = ColorPaletteFilter.all;
  bool _defaultColorCycleActive = false;
  String _selectedFont = 'System Default';
  int _selectedFontIndex = -1;
  final ScrollController _fontScrollController = ScrollController();
  String? _customFontDirectory;
  String? _customFontDirectory2;
  String _selectedMainCategory = 'all';
  String? _selectedSubCategory;
  String? _selectedStudio;

  double _subtitleLineSpacing = 1.4;
  double _secondarySubtitleLineSpacing = 1.4;

  String _secondarySubtitleText = '';
  List<SubtitleCue> _secondarySubtitles = [];
  int? _currentSecondarySubtitleIndex;
  String? _secondarySubtitleFilePath;

  String _secondarySubtitleFont = 'System Default';
  double _secondarySubtitleFontSize = 86.0;
  ColorPalette? _secondaryColorPalette;
  String _secondaryConversionType = 'none';

  List<String> _availableSubtitles = [];
  String? _primarySubtitlePath;
  String? _secondarySubtitlePath;

  List<SubtitleSearchResult> _subtitleSearchResults = [];
  List<ParagraphItem> _paragraphItems = [];
  String _subsSearchQuery = '';
  final TextEditingController _subsSearchController = TextEditingController();
  final FocusNode _subsSearchFocusNode = FocusNode();

  List<FrequencyItem> _frequencyItems = [];
  bool _isAnalyzingFrequencies = false;

  String _skipChapterTerms = '';
  final TextEditingController _skipChapterController = TextEditingController();
  final FocusNode _skipChapterFocusNode = FocusNode();

  bool _chapterSearchUseAnd = true;
  String _chapterExcludeTerms = '';
  final TextEditingController _chapterExcludeController =
      TextEditingController();
  final FocusNode _chapterExcludeFocusNode = FocusNode();

  PauseMode _pauseMode = PauseMode.disabled;
  Timer? _pauseModeTimer;
  Duration? _nextPauseTime;

  final StatsManager _statsManager = StatsManager();
  Timer? _cacheFlushTimer;

  late AdhanClockService _adhanClockService;
  bool _showAdhanOverlay = false;

  static const platform = MethodChannel('com.substitcher/open_file');

  Timer? _sleepTimer;
  Duration? _sleepDuration;
  bool _showSleepTimerCountdown = false;
  int _sleepTimerCountdownSeconds = 120;
  Timer? _sleepTimerCountdownTimer;
  SleepTimerAction _sleepTimerAction = SleepTimerAction.closeApp;

  ColoringMode _coloringMode = ColoringMode.words;
  bool _showPlaylistDirectories = false;

  bool _hoveringPrevChapter = false;
  bool _hoveringNextChapter = false;

  bool _isExportingMarkdown = false;
  String _exportStatus = '';

  bool _isYouTubeStream = false;
  String? _youtubeTitle;
  bool _isLoadingYouTube = false;
  String? _currentYouTubeUrl;
  String? _youtubeChannelName;
  SubtitlePreferences _subtitlePreferences = SubtitlePreferences();

  bool _isDisposed = false;
  Duration? _inPoint;
  Duration? _outPoint;
  Duration? _lastOutPoint;

  List<BlurRegion> _blurRegions = [];
  bool _blurDrawMode = false;
  Offset? _blurDragStart;
  Offset? _blurDragCurrent;
  final GlobalKey _videoStackKey = GlobalKey();

  bool _isLoadingAudioStreams = false;
  DateTime? _lastAudioStreamFetch;
  String? _currentAudioFormat;

  bool _autoConvertAlternates = false;
  bool _autoConvertMissing = false;
  Set<String> _favoriteFonts = {};

  String? _pendingCycleFont;
  String? _pendingCycleConversionType;
  bool _pendingCycleReady = false;

  Set<String> _favoriteColorPalettes = {};
  String _colorFilterMode = 'all';
  ColorPaletteFilter _colorFilter = ColorPaletteFilter.all;

  bool _blurShadowEnabled = false;

  bool _isVideoFile = false;
  bool _videoEditingMode = false;
  String? _systemFfmpegPath;
  bool _ffmpegAvailable = false;
  bool _showCutsOverlay = false;
  bool _isCutting = false;

  VideoCodec _selectedCutCodec =
      Platform.isMacOS ? VideoCodec.videotoolbox : VideoCodec.nvenc;

  bool _isCombining = false;
  bool _combineCancelled = false;
  double _combineProgress = 0.0;
  String _combineStep = '';
  DateTime? _combineStartTime;
  DateTime? _combineFinishTime;
  Process? _combineProcess;
  EncodeSettings? _lastEncodeSettings;

  String? _videoResolution;
  double? _videoFps;

  bool _isDefiningTrackedBlur = false;
  Offset? _trackedBlurStart;
  Offset? _trackedBlurEnd;

  bool _isTracking = false;
  String _trackingStatus = '';
  List<List<double>> _trackedCoords = [];
  bool _trackedBlurInverted = false;

  LutItem? _selectedLut;
  List<List<List<List<int>>>>? _loadedLutData;
  String? _selectedLutName;
  Set<String> _favoriteLuts = {};
  List<LutItem> _availableLuts = [];
  String _lutFilterMode = 'all';
  int _selectedLutIndex = -1;

  List<QuranIndexEntry> _quranEntries = [];
  QuranVerseRef? _activeQuranRef;
  QuranVerseRef? _pendingStopRef;
  String? _activeQuranTopic;

  List<QuranVerseRef>? _quranQueue;
  int _quranQueueFilteredIndex = 0;
  bool _navigatingFromQueue = false;

  bool _fontCycleActive = false;
  int _fontCycleInterval = 4;
  int _fontCycleCueCounter = 0;

  bool _colorCycleActive = false;
  int _colorCycleInterval = 4;
  int _colorCycleCueCounter = 0;

  Map<String, VttShowStyle> _vttShowStyles = {};
  bool _vttShowActive = false;
  int _vttShowRevealedLines = 1;
  String? _vttShowCurrentKey;
  bool _vttShowApplying = false;
  bool _vttShowEditMode = false;
  final FocusNode _vttEditLine1FocusNode = FocusNode();
  final FocusNode _vttEditLine2FocusNode = FocusNode();
  final GlobalKey<VttShowEditOverlayState> _vttEditKey =
      GlobalKey<VttShowEditOverlayState>();

  @override
  void initState() {
    super.initState();
    _windowListener = _WindowCloseListener(
      onClose: _handleWindowClose,
    );

    windowManager.addListener(_windowListener);
    _adhanClockService = AdhanClockService();
    _adhanClockService.initialize();
    _adhanClockService.setMainPlayerPauseCallback(() async {
      if (_isPlaying) {
        await player.pause();
      }
    });
    _checkShowOnStart();
    platform.setMethodCallHandler(_handleOpenFile);
    _checkForInitialFile();
    CJKTokenizer.initialize();
    _setupAudioPlayer();
    _videoController = VideoController(player);
    CustomFontLoader.loadFonts();
    CustomFontMetadataManager.load();
    _loadSkipChapterTerms();
    _loadCustomFontDirectory();
    _loadPlaylistDirectories().then((_) {
      _loadChapterIndex();
    });
    _loadDurationCache();
    _loadInitialStats();
    _loadHistory();
    _loadPlaylist();
    _loadQuranLanguage();
    _loadSubtitlePreferences();
    _loadAutoConversionSettings();
    _loadBookmarks();
    _loadFavoriteFonts();
    _loadFavoriteColorPalettes();
    _startCacheFlushTimer();
    _loadFavoriteLuts();
    _loadSavedLut();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _adhanClockService.checkNow();
      _loadDefaultSettings();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _saveDefaultSettings();
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    windowManager.removeListener(_windowListener);
    _cacheFlushTimer?.cancel();
    _frequencyGenerationTimer?.cancel();
    _sleepTimerCountdownTimer?.cancel();
    _adhanClockService.dispose();
    if (_currentAudiobook != null) {
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      _statsManager.recordChapterEnd(
        path.basenameWithoutExtension(_currentAudiobook!.path),
        currentChapter.title,
        false,
      );
      _statsManager.flushCacheToLog();
    }
    _sleepTimer?.cancel();
    _pauseModeTimer?.cancel();
    player.dispose();
    _fontScrollController.dispose();
    _playlistScrollController.dispose();
    _historyScrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _excludeController.dispose();
    _searchFocusNode.dispose();
    _excludeFocusNode.dispose();
    _tafsirSearchController.dispose();
    _tafsirSearchFocusNode.dispose();
    _quranSearchFocusNode.dispose();
    _quranExcludeFocusNode.dispose();
    _quranVerseSearchController.dispose();
    _quranVerseSearchFocusNode.dispose();
    _hadeethSearchFocusNode.dispose();
    _hadeethExcludeFocusNode.dispose();
    _quranRefInputFocusNode.dispose();
    _skipChapterController.dispose();
    _skipChapterFocusNode.dispose();
    _subsSearchController.dispose();
    _subsSearchFocusNode.dispose();
    _chapterSearchController.dispose();
    _chapterSearchFocusNode.dispose();
    _chapterExcludeController.dispose();
    _chapterExcludeFocusNode.dispose();
    _statsSearchController.dispose();
    _statsSearchFocusNode.dispose();
    _vttEditLine1FocusNode.dispose();
    _vttEditLine2FocusNode.dispose();
    LutThumbnailService.instance.clearCache();
    super.dispose();
  }

  Future<void> _checkForInitialFile() async {
    try {
      final String? filePath = await platform.invokeMethod('getInitialFile');
      if (filePath != null && filePath.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _openAudiobook(filePath);
      }
    } catch (e) {
      print('Error getting initial file: $e');
    }
  }

  Future<void> _checkShowOnStart() async {
    final settings = await AdhanSettings.load();
    if (settings.adhanClockEnabled && settings.showOnAppStart) {
      setState(() {
        _showAdhanOverlay = true;
      });
    }
  }

  Future<void> _loadQuranLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final language = prefs.getString('quranIndexLanguage') ?? 'English';
    setState(() {
      _quranIndexLanguage = language;
      _quranEntries = parseQuranIndex(getQuranIndexRaw(language));
    });
  }

  void _onQuranLanguageChanged(String language) {
    setState(() {
      _quranIndexLanguage = language;
      _quranEntries = parseQuranIndex(getQuranIndexRaw(language));
      _activeQuranRef = null;
      _activeQuranFilteredIndex = null;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('quranIndexLanguage', language);
    });
  }

  bool get _isQuranVerseByVerse {
    final p = _currentAudiobook?.path ?? '';
    return p.contains('Verse by Verse') && p.contains('Quran');
  }

  Future<void> _navigateToQuranVerse(
      QuranVerseRef ref, int filteredIndex) async {
    if (!_navigatingFromQueue) {
      _quranQueue = null;
    }
    _navigatingFromQueue = false;
    setState(() {
      _activeQuranRef = ref;
      _activeQuranFilteredIndex = filteredIndex;
    });
    final rangeKey = getRangeKeyForSurah(ref.surah);
    if (rangeKey == null) return;
    final currentPath = _currentAudiobook?.path;
    if (currentPath == null) return;
    final parentDir = path.dirname(currentPath);
    final currentBase = path.basename(currentPath);
    final reciterSuffix = currentBase.replaceFirst(
      RegExp(r'^.*?\d{3}-\d{3} '),
      '',
    );
    final targetOpusName = 'Quran Arabic - $rangeKey $reciterSuffix';
    final targetOpusPath = path.join(parentDir, targetOpusName);
    if (!await File(targetOpusPath).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File not found: $targetOpusName')),
        );
      }
      return;
    }
    final needsNewFile = currentPath != targetOpusPath;
    if (needsNewFile) {
      await _loadQuranVttForFile(targetOpusPath);
      await _openAudiobook(targetOpusPath);
      await Future.delayed(const Duration(milliseconds: 800));
    }
    final startId = ref.chapterIdStart;
    final chapters = _currentAudiobook?.chapters ?? [];
    final chapterIndex = chapters.indexWhere(
      (c) => c.title.startsWith(startId),
    );
    if (chapterIndex == -1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verse $startId not found in chapters')),
        );
      }
      return;
    }
    if (!ref.isFullSurah) {
      setState(() => _pendingStopRef = ref);
    } else {
      final lastAyah = quranVerseCounts[ref.surah];
      final effectiveStopRef = QuranVerseRef(
        surah: ref.surah,
        fromAyah: 1,
        toAyah: lastAyah,
        isFullSurah: false,
      );
      setState(() => _pendingStopRef = effectiveStopRef);
    }
    await _jumpToChapter(chapterIndex);
    await player.play();
    setState(() => _showPanel = false);
  }

  void _playNextQuranRef() {
    final active = _activeQuranRef;
    if (active == null) return;

    QuranIndexEntry? ownerEntry;
    int refIndexInEntry = -1;

    for (final entry in _quranEntries) {
      for (int i = 0; i < entry.refs.length; i++) {
        final r = entry.refs[i];
        if (r.surah == active.surah &&
            r.fromAyah == active.fromAyah &&
            r.toAyah == active.toAyah &&
            r.isFullSurah == active.isFullSurah) {
          ownerEntry = entry;
          refIndexInEntry = i;
          break;
        }
      }
      if (ownerEntry != null) break;
    }

    if (ownerEntry == null || refIndexInEntry == -1) return;
    if (refIndexInEntry >= ownerEntry.refs.length - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('End of "${ownerEntry.topic}"'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    final nextRef = ownerEntry.refs[refIndexInEntry + 1];
    _navigateToQuranVerse(nextRef, _activeQuranFilteredIndex ?? 0);
  }

  Future<void> _loadQuranVttForFile(String targetOpusPath) async {
    final currentVtt = _subtitleFilePath;
    if (currentVtt == null) return;

    final vttDir = path.dirname(currentVtt);
    final langSubdir = path.basename(vttDir);
    final vttParentDir = path.dirname(vttDir);

    final targetBase = path.basenameWithoutExtension(targetOpusPath);
    final targetVttName = '$targetBase.vtt';

    final targetOpusDir = path.dirname(targetOpusPath);
    final targetOpusBase = path.basenameWithoutExtension(targetOpusPath);

    final candidate1 = path.join(vttParentDir, langSubdir, targetVttName);
    final candidate2 = path.join(
      targetOpusDir,
      '${targetOpusBase}_vtt',
      langSubdir,
      targetVttName,
    );
    final candidate3 = path.join(targetOpusDir, targetVttName);

    String? foundVtt;
    for (final candidate in [candidate1, candidate2, candidate3]) {
      if (await File(candidate).exists()) {
        foundVtt = candidate;
        break;
      }
    }

    if (foundVtt != null) {
      await SubtitlePreferences.saveLastUsedVttPath(targetOpusPath, foundVtt);
    }
  }

  Future<void> _buildQuranVerseSearchIndexIfNeeded() async {
    if (!_isQuranVerseByVerse) return;
    final vttPath = _subtitleFilePath;
    final opusPath = _currentAudiobook?.path;
    if (vttPath == null || opusPath == null) return;

    setState(() => _quranVerseIndexBuilding = true);
    await _quranVerseSearchIndex.buildFromCurrentFile(
      currentVttPath: vttPath,
      currentOpusPath: opusPath,
    );
    if (mounted) {
      setState(() => _quranVerseIndexBuilding = false);
    }
  }

  void _searchQuranVerseText(String query) {
    final hits = _quranVerseSearchIndex.search(query);
    setState(() => _quranVerseSearchResults = hits);
  }

  void _jumpToQuranVerseSearchResult(QuranAyahSearchHit hit) {
    final ref = QuranVerseRef(
      surah: hit.surah,
      fromAyah: hit.ayah,
      toAyah: hit.ayah,
      isFullSurah: false,
    );
    setState(() {
      _quranVerseSearchMode = false;
      _showPanel = false;
    });
    _navigateToQuranVerse(ref, 0);
  }

  void _playAllQuranRefs(List<QuranVerseRef> refs, int filteredIndex) {
    if (refs.isEmpty) return;
    _quranQueue = List<QuranVerseRef>.from(refs)..removeAt(0);
    _quranQueueFilteredIndex = filteredIndex;
    _navigatingFromQueue = true;
    _navigateToQuranVerse(refs.first, filteredIndex);
  }

  void _cancelQuranQueue() => setState(() => _quranQueue = null);

  Future<void> _loadFavoriteLuts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteLuts = (prefs.getStringList('favoriteLuts') ?? []).toSet();
    });
  }

  Future<void> _selectLut(String? lutPath, String? lutName) async {
    final prefs = await SharedPreferences.getInstance();
    if (lutPath == null) {
      setState(() {
        _selectedLutName = null;
        _loadedLutData = null;
      });
      await prefs.remove('selectedLutPath');
      await prefs.remove('selectedLutName');
      return;
    }
    try {
      final lutData = await rootBundle.loadString(lutPath);
      final parsedLut = await LutProcessor.parseCubeLutFromString(lutData);
      setState(() {
        _selectedLutName = lutName;
        _loadedLutData = parsedLut;
      });
      await prefs.setString('selectedLutPath', lutPath);
      await prefs.setString('selectedLutName', lutName!);
    } catch (e) {
      print('Error loading LUT: $e');
    }
  }

  Future<void> _loadSavedLut() async {
    final prefs = await SharedPreferences.getInstance();
    final lutPath = prefs.getString('selectedLutPath');
    final lutName = prefs.getString('selectedLutName');
    if (lutPath != null && lutName != null) {
      await _selectLut(lutPath, lutName);
    }
  }

  Future<void> _scanAvailableLuts() async {
    final luts = lutList
        .map((e) => LutItem(name: e['name']!, path: e['path']!))
        .toList();
    setState(() {
      _availableLuts = luts;
    });
  }

  List<LutItem> _getFilteredLuts() {
    List<LutItem> lutsToShow = _lutFilterMode == 'favorites'
        ? _availableLuts
            .where((lut) => _favoriteLuts.contains(lut.name))
            .toList()
        : _availableLuts;

    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) return lutsToShow;

    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return lutsToShow
        .where((lut) => _matchesSearch(
            lut.name.replaceAll('.cube', ''), _searchQuery, excludeList))
        .toList();
  }

  Future<void> _addLutToFavorites(String lutName) async {
    setState(() => _favoriteLuts.add(lutName));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteLuts', _favoriteLuts.toList());
  }

  Future<void> _removeLutFromFavorites(String lutName) async {
    setState(() => _favoriteLuts.remove(lutName));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteLuts', _favoriteLuts.toList());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _adhanClockService.checkNow();
    }
  }

  void _updateWakelock() {
    if (_isPlaying && (_subtitles.isNotEmpty || _isYouTubeStream)) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Future<dynamic> _handleOpenFile(MethodCall call) async {
    if (call.method == 'openFile') {
      final String filePath = call.arguments as String;
      await _openAudiobook(filePath);
    }
  }

  Future<void> _loadInitialStats() async {
    await _statsManager.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  void _setupAudioPlayer() {
    player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
      _checkChapterBoundary(position);
      _checkPauseTrigger();
      _updateCurrentSubtitle();
      if (_isPlaying && position.inSeconds % 10 == 0) {
        _saveToHistory();
      }
    });

    player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() {
          _isPlaying = playing;
        });
        if (playing && _vttShowActive) {
          player.pause();
          return;
        }
        _updateWakelock();
      }
      if (playing) {
        _statsManager.onPlaybackStart();
        _saveToHistory();
      } else {
        if (_sleepDuration != null) {
          _setSleepTimer(null);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sleep timer cancelled due to pause'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        _statsManager.onPlaybackPause();
        _saveToHistory();
      }
    });
  }

  Future<void> _saveDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultFont', _defaultFont);
    await prefs.setString('defaultConversionType', _defaultConversionType);
    if (_defaultColorPalette != null) {
      await prefs.setString('defaultColorPalette', _defaultColorPalette!);
    }
    await prefs.setInt('fontColorOverride', _fontColorOverride.index);
    await prefs.setString('sleepTimerAction',
        _sleepTimerAction == SleepTimerAction.closeApp ? 'close' : 'pause');
    await prefs.setInt(
        'defaultColorCategoryFilter', _defaultColorCategoryFilter.index);
    await prefs.setBool('defaultColorCycleActive', _defaultColorCycleActive);
  }

  Future<void> _loadDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final fontColorOverride =
        FontColorOverride.values[prefs.getInt('fontColorOverride') ?? 0];
    final sleepTimerAction = prefs.getString('sleepTimerAction') ?? 'pause';
    setState(() {
      _defaultFont = prefs.getString('defaultFont') ?? 'System Default';
      _defaultConversionType =
          prefs.getString('defaultConversionType') ?? 'none';
      _defaultColorPalette = prefs.getString('defaultColorPalette');
      _fontColorOverride = fontColorOverride;
      _defaultColorCategoryFilter = ColorPaletteFilter
          .values[prefs.getInt('defaultColorCategoryFilter') ?? 0];
      _defaultColorCycleActive =
          prefs.getBool('defaultColorCycleActive') ?? false;
      _sleepTimerAction = sleepTimerAction == 'close'
          ? SleepTimerAction.closeApp
          : SleepTimerAction.pauseOnly;
      _colorFilter =
          ColorPaletteFilter.values[prefs.getInt('colorCategoryFilter') ?? 0];
      _colorCycleActive = prefs.getBool('colorCycleActive') ?? false;
      _colorCycleInterval = prefs.getInt('colorCycleInterval') ?? 4;
    });
  }

  Future<void> _setCurrentAsDefault() async {
    if (!_isYouTubeStream && _currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }

    setState(() {
      _defaultFont = _selectedFont;
      _defaultConversionType = _conversionType;
      _defaultColorPalette = _currentColorPalette?.name;
      _defaultColorCategoryFilter = _colorFilter;
      _defaultColorCycleActive = _colorCycleActive;

      _secondarySubtitleFont = _selectedFont;
      _secondaryColorPalette = _currentColorPalette;
    });

    await _saveDefaultSettings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Set as default:\n'
              'Font: $_defaultFont\n'
              'Conversion: $_defaultConversionType\n'
              'Color: ${_defaultColorPalette ?? 'None'}\n'
              'Filter: ${_defaultColorCategoryFilter.name}\n'
              'Cycling: $_defaultColorCycleActive\n'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _applyDefaultSettings() async {
    if (!_isYouTubeStream && _currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }

    setState(() {
      _selectedFont = _defaultFont;
      final filteredFonts = _getFilteredFonts();
      _selectedFontIndex = filteredFonts.indexOf(_defaultFont);
      if (_selectedFontIndex == -1) _selectedFontIndex = 0;

      _colorFilter = _defaultColorCategoryFilter;
      _colorCycleActive = _defaultColorCycleActive;

      _conversionType = _defaultConversionType;

      if (_defaultColorPalette != null) {
        final palette = ColorPalette.presets.firstWhere(
          (p) => p.name == _defaultColorPalette,
          orElse: () => ColorPalette.presets.first,
        );
        _currentColorPalette = palette;
        _selectedColorIndex = ColorPalette.presets.indexOf(palette);
      } else {
        _currentColorPalette = null;
      }

      _secondarySubtitleFont = _defaultFont;
      _secondaryColorPalette = _currentColorPalette;
    });

    await _saveFontSettings();
    await _applyConversion();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Applied defaults:\n'
              'Font: $_defaultFont\n'
              'Conversion: $_defaultConversionType\n'
              'Color: ${_defaultColorPalette ?? 'None'}\n'
              'Filter: ${_defaultColorCategoryFilter.name}\n'
              'Cycling: $_defaultColorCycleActive\n'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleWindowClose() async {
    try {
      _isDisposed = true;

      if (_isPlaying) {
        await player.pause().timeout(const Duration(milliseconds: 500));
      }

      if (_currentAudiobook != null) {
        final currentChapter =
            _currentAudiobook!.chapters[_currentChapterIndex];
        _statsManager.recordChapterEnd(
          path.basenameWithoutExtension(_currentAudiobook!.path),
          currentChapter.title,
          false,
        );
        await _statsManager
            .flushCacheToLog()
            .timeout(const Duration(milliseconds: 500));
      }

      await _saveDefaultSettings().timeout(const Duration(milliseconds: 500));
      await _saveToHistory().timeout(const Duration(milliseconds: 500));
      await player.stop().timeout(const Duration(milliseconds: 500));
    } catch (e) {
      print('Error during window close: $e');
    }
  }

  void _startCacheFlushTimer() {
    _cacheFlushTimer?.cancel();
    _cacheFlushTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_statsManager.statsEnabled &&
          _statsManager.chapterStartTime != null &&
          _currentAudiobook != null) {
        final currentChapter =
            _currentAudiobook!.chapters[_currentChapterIndex];
        final accumulatedTime = _statsManager.getCurrentAccumulatedTime();
        final cacheKey = _statsManager.generateCacheKey(
          path.basenameWithoutExtension(_currentAudiobook!.path),
          currentChapter.title,
          _statsManager.chapterStartTime,
        );
        if (cacheKey.isNotEmpty) {
          setState(() {
            _statsManager.chapterTimeCache[cacheKey] = accumulatedTime;
          });
          _statsManager.saveCacheToPrefs();
        }
      }
    });
  }

  void _checkChapterBoundary(Duration position) {
    if (_currentAudiobook == null || _currentAudiobook!.chapters.isEmpty)
      return;
    if (_currentChapterIndex >= _currentAudiobook!.chapters.length) return;
    final chapter = _currentAudiobook!.chapters[_currentChapterIndex];
    if (position >= chapter.endTime) {
      if (_pendingStopRef != null) {
        final endId = _pendingStopRef!.chapterIdEnd;
        final currentTitle =
            _currentAudiobook!.chapters[_currentChapterIndex].title;
        if (currentTitle.startsWith(endId)) {
          player.pause();
          setState(() => _pendingStopRef = null);
          if (_quranQueue != null && _quranQueue!.isNotEmpty) {
            final next = _quranQueue!.removeAt(0);
            _navigatingFromQueue = true;
            _navigateToQuranVerse(next, _quranQueueFilteredIndex);
          } else {
            _quranQueue = null;
          }
          return;
        }
      }
      if (!_isYouTubeStream) {
        final currentChapter =
            _currentAudiobook!.chapters[_currentChapterIndex];
        _statsManager.recordChapterEnd(
          path.basenameWithoutExtension(_currentAudiobook!.path),
          currentChapter.title,
          false,
        );
      }
      if (!_playedChapters.contains(_currentChapterIndex)) {
        _playedChapters.add(_currentChapterIndex);
      }
      if (_sleepDuration == Duration.zero) {
        if (_sleepTimer == null) {
          _triggerSleepTimerCountdown();
        }
        return;
      }
      if (_shuffleEnabled && !_isYouTubeStream) {
        final unplayedChapters =
            List.generate(_currentAudiobook!.chapters.length, (i) => i)
                .where((i) =>
                    !_playedChapters.contains(i) &&
                    !_shouldSkipChapter(_currentAudiobook!.chapters[i].title))
                .toList();
        if (unplayedChapters.isEmpty) {
          player.pause();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All chapters played in shuffle mode'),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        } else {
          final nextIndex = _getNextShuffleChapter();
          if (nextIndex < 0 || nextIndex >= _currentAudiobook!.chapters.length)
            return;
          final nextChapter = _currentAudiobook!.chapters[nextIndex];
          setState(() {
            _currentChapterIndex = nextIndex;
            if (!_playedChapters.contains(nextIndex)) {
              _playedChapters.add(nextIndex);
            }
          });
          if (_showPanel && _panelMode == PanelMode.chapters)
            _scrollToCurrentChapter();
          player
              .seek(nextChapter.startTime + const Duration(milliseconds: 100));
        }
      } else {
        int nextIndex = _currentChapterIndex + 1;
        if (!_isYouTubeStream) {
          while (nextIndex < _currentAudiobook!.chapters.length) {
            if (!_shouldSkipChapter(
                _currentAudiobook!.chapters[nextIndex].title)) break;
            nextIndex++;
          }
          if (nextIndex >= _currentAudiobook!.chapters.length) {
            player.pause();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Finished audiobook'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
          setState(() => _currentChapterIndex = nextIndex);
          if (_showPanel && _panelMode == PanelMode.chapters)
            _scrollToCurrentChapter();
        } else {
          if (nextIndex >= _currentAudiobook!.chapters.length) {
            player.pause();
            return;
          }
          setState(() => _currentChapterIndex = nextIndex);
          print('YT chapter advanced to $nextIndex: ${_currentAudiobook!.chapters[nextIndex].title}');
          if (_showPanel && _panelMode == PanelMode.chapters)
            _scrollToCurrentChapter();
        }
      }
      if (!_isYouTubeStream &&
          _currentChapterIndex < _currentAudiobook!.chapters.length) {
        _statsManager.recordChapterStart();
      }
    }
  }

  Future<void> _loadAutoConversionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoConvertAlternates = prefs.getBool('autoConvertAlternates') ?? false;
      _autoConvertMissing = prefs.getBool('autoConvertMissing') ?? false;
    });
  }

  Future<void> _saveAutoConversionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoConvertAlternates', _autoConvertAlternates);
    await prefs.setBool('autoConvertMissing', _autoConvertMissing);
  }

  String get _displayConversionType {
    if (_selectedMainCategory == FontCategory.favorites) {
      final metadata = FontDatabase.getMetadata(_selectedFont);
      if (metadata != null && metadata.subCategories.isNotEmpty) {
        return metadata.subCategories.first;
      }
      return 'favorite';
    }
    return _conversionType == 'none' ? 'original' : _conversionType;
  }

  Future<void> _convertSubtitleToDemo() async {
    if (_subtitleFilePath == null || _selectedFont == 'System Default') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Load subtitles and select a demo font first')),
      );
      return;
    }
    final metadata = FontDatabase.getMetadata(_selectedFont);
    if (metadata == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_selectedFont is not in the font database')),
      );
      return;
    }
    try {
      final audiobookPath = _currentAudiobook!.path;
      final audiobookDir = path.dirname(audiobookPath);
      final audiobookBase = path.basenameWithoutExtension(audiobookPath);
      final vttDir = path.join(audiobookDir, '${audiobookBase}_vtt');
      await Directory(vttDir).create(recursive: true);
      final originalSubtitlePath = path.join(vttDir, '${audiobookBase}.vtt');
      if (!await File(originalSubtitlePath).exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Original subtitle not found: ${path.basename(originalSubtitlePath)}')),
          );
        }
        return;
      }
      String outputPath;
      if (metadata.hasMissingLigatures()) {
        outputPath = await SubtitleTransformer.fixMissingLigatures(
          originalSubtitlePath,
          _selectedFont,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Converted with ligature fixes: ${path.basename(outputPath)}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (metadata.isDemo()) {
        outputPath = await SubtitleTransformer.convertToDemo(
          originalSubtitlePath,
          _selectedFont,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Converted to demo: ${path.basename(outputPath)}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This font does not need conversion')),
          );
        }
        return;
      }
      final content = await File(outputPath).readAsString();
      final subtitles = _parseVTT(content);
      setState(() {
        _subtitles = subtitles;
        _subtitleFilePath = outputPath;
      });
    } catch (e) {
      print('Error converting subtitle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to convert: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanAvailableSubtitles() async {
    if (_currentAudiobook == null) {
      setState(() {
        _availableSubtitles = [];
      });
      return;
    }

    if (_isYouTubeStream) {
      final tempDir = Directory.systemTemp.path;
      final ytSubDir = path.join(tempDir, 'substitcher_yt_subs');
      final subtitleFiles = <String>[];

      if (await Directory(ytSubDir).exists()) {
        await for (final entity in Directory(ytSubDir).list()) {
          if (entity is File) {
            final ext = path.extension(entity.path).toLowerCase();
            if (ext == '.vtt') {
              subtitleFiles.add(entity.path);
            }
          }
        }
      }

      subtitleFiles.sort((a, b) => path
          .basename(a)
          .toLowerCase()
          .compareTo(path.basename(b).toLowerCase()));

      setState(() {
        _availableSubtitles = subtitleFiles;
      });
      return;
    }

    final audiobookPath = _currentAudiobook!.path;
    final audiobookDir = path.dirname(audiobookPath);
    final audiobookBase = path.basenameWithoutExtension(audiobookPath);
    final vttDir = path.join(audiobookDir, '${audiobookBase}_vtt');

    final subtitleFiles = <String>[];

    if (await Directory(vttDir).exists()) {
      final dir = Directory(vttDir);
      await for (final entity in dir.list()) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (ext == '.vtt' || ext == '.srt') {
            subtitleFiles.add(entity.path);
          }
        }
      }
    }

    final audiobookDirEntity = Directory(audiobookDir);
    await for (final entity in audiobookDirEntity.list()) {
      if (entity is File) {
        final name = path.basename(entity.path);
        if (name.startsWith(audiobookBase)) {
          final ext = path.extension(entity.path).toLowerCase();
          if (ext == '.vtt' || ext == '.srt') {
            if (!subtitleFiles.contains(entity.path)) {
              subtitleFiles.add(entity.path);
            }
          }
        }
      }
    }

    await for (final entity in audiobookDirEntity.list(followLinks: false)) {
      if (entity is Directory) {
        if (entity.path == vttDir) continue;

        bool foundTwoLevel = false;

        await for (final subEntity in entity.list(followLinks: false)) {
          if (subEntity is Directory) {
            await for (final file in subEntity.list(followLinks: false)) {
              if (file is File) {
                final ext = path.extension(file.path).toLowerCase();
                if (ext != '.vtt' && ext != '.srt') continue;
                final baseName = path.basenameWithoutExtension(file.path);
                if (baseName == audiobookBase) {
                  if (!subtitleFiles.contains(file.path)) {
                    subtitleFiles.add(file.path);
                    foundTwoLevel = true;
                  }
                }
              }
            }
          }
        }

        if (!foundTwoLevel) {
          await for (final file in entity.list(followLinks: false)) {
            if (file is File) {
              final ext = path.extension(file.path).toLowerCase();
              if (ext != '.vtt' && ext != '.srt') continue;
              final baseName = path.basenameWithoutExtension(file.path);
              if (baseName == audiobookBase) {
                if (!subtitleFiles.contains(file.path)) {
                  subtitleFiles.add(file.path);
                }
              }
            }
          }
        }
      }
    }

    subtitleFiles.sort((a, b) {
      final aParentDir = path.dirname(a);
      final bParentDir = path.dirname(b);
      final aIsSameDir = aParentDir == audiobookDir;
      final bIsSameDir = bParentDir == audiobookDir;

      if (aIsSameDir && !bIsSameDir) return -1;
      if (!aIsSameDir && bIsSameDir) return 1;

      final aParts = a.split(Platform.pathSeparator);
      final bParts = b.split(Platform.pathSeparator);
      final aParent =
          aParts.length >= 2 ? aParts[aParts.length - 2].toLowerCase() : '';
      final bParent =
          bParts.length >= 2 ? bParts[bParts.length - 2].toLowerCase() : '';
      final parentCmp = aParent.compareTo(bParent);
      if (parentCmp != 0) return parentCmp;
      return path
          .basename(a)
          .toLowerCase()
          .compareTo(path.basename(b).toLowerCase());
    });

    setState(() {
      _availableSubtitles = subtitleFiles;
    });
  }

  Future<void> _openSubtitleManager() async {
    if (_currentAudiobook != null) {
      await _scanAvailableSubtitles();
    }

    if (_subtitleFilePath != null && _primarySubtitlePath == null) {
      setState(() {
        _primarySubtitlePath = _subtitleFilePath;
      });
    }

    if (_secondarySubtitleFilePath != null && _secondarySubtitlePath == null) {
      setState(() {
        _secondarySubtitlePath = _secondarySubtitleFilePath;
      });
    }

    if (!mounted) return;

    final audiobookPath = _currentAudiobook?.path;

    showDialog(
      context: context,
      builder: (context) => SubtitleManagerDialog(
        availableSubtitles: _availableSubtitles,
        primarySubtitle: _primarySubtitlePath,
        secondarySubtitle: _secondarySubtitlePath,
        currentAudiobookPath: _currentAudiobook?.path,
        onPrimarySelected: (filePath) async {
          setState(() {
            _primarySubtitlePath = filePath;
            _subtitleFilePath = filePath;
          });

          if (audiobookPath != null) {
            await SubtitlePreferences.saveLastUsedVttPath(
                audiobookPath, filePath);
          }

          final vttShowPath = VttShowService.vttShowPathFor(filePath);
          if (vttShowPath != null) {
            final styles = await VttShowService.load(vttShowPath);
            final content = await File(filePath).readAsString();
            final cues = _parseVTT(content);
            final reconciledStyles = VttShowService.reconcile(
              styles: styles,
              cues: cues,
            );
            setState(() {
              _vttShowStyles = styles;
              _vttShowActive = true;
              _vttShowRevealedLines = 1;
              _vttShowCurrentKey = null;
              _vttShowApplying = false;
              _subtitles = cues;
              _originalSubtitles = cues;
            });
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) await _loadVttShowSilentAudio();
          } else {
            await _applyConversion();
          }
          _buildQuranVerseSearchIndexIfNeeded();
        },
        onSecondarySelected: (path) async {
          setState(() {
            _secondarySubtitlePath = path;
            _secondarySubtitleFilePath = path;
            if (_secondarySubtitleFont == 'System Default' &&
                _selectedFont != 'System Default') {
              _secondarySubtitleFont = _selectedFont;
            }
            if (_secondaryColorPalette == null &&
                _currentColorPalette != null) {
              _secondaryColorPalette = _currentColorPalette;
            }
            if (_secondarySubtitleFontSize == 86.0) {
              _secondarySubtitleFontSize = _subtitleFontSize;
            }
          });

          if (audiobookPath != null) {
            await SubtitlePreferences.saveLastUsedSecondaryVttPath(
                audiobookPath, path);
          }

          await _applySecondaryConversion();
        },
        onSwap: () {
          setState(() {
            final temp = _primarySubtitlePath;
            _primarySubtitlePath = _secondarySubtitlePath;
            _secondarySubtitlePath = temp;

            _subtitleFilePath = _primarySubtitlePath;
            _secondarySubtitleFilePath = _secondarySubtitlePath;

            final tempSubtitles = _subtitles;
            final tempText = _currentSubtitleText;
            final tempIndex = _currentSubtitleIndex;

            _subtitles = _secondarySubtitles;
            _currentSubtitleText = _secondarySubtitleText;
            _currentSubtitleIndex = _currentSecondarySubtitleIndex;

            _secondarySubtitles = tempSubtitles;
            _secondarySubtitleText = tempText;
            _currentSecondarySubtitleIndex = tempIndex;

            final tempFont = _selectedFont;
            final tempSize = _subtitleFontSize;
            final tempPalette = _currentColorPalette;
            final tempConversion = _conversionType;

            final tempOriginal = _originalSubtitles;
            _originalSubtitles = _secondaryOriginalSubtitles;
            _secondaryOriginalSubtitles = tempOriginal;

            _selectedFont = _secondarySubtitleFont;
            _subtitleFontSize = _secondarySubtitleFontSize;
            _currentColorPalette = _secondaryColorPalette;
            _conversionType = _secondaryConversionType;

            _secondarySubtitleFont = tempFont;
            _secondarySubtitleFontSize = tempSize;
            _secondaryColorPalette = tempPalette;
            _secondaryConversionType = tempConversion;
          });

          if (audiobookPath != null) {
            if (_primarySubtitlePath != null) {
              SubtitlePreferences.saveLastUsedVttPath(
                  audiobookPath, _primarySubtitlePath!);
            }
            if (_secondarySubtitlePath != null) {
              SubtitlePreferences.saveLastUsedSecondaryVttPath(
                  audiobookPath, _secondarySubtitlePath!);
            }
          }
        },
        onClearPrimary: () {
          setState(() {
            _primarySubtitlePath = null;
            _subtitleFilePath = null;
            _subtitles = [];
            _currentSubtitleText = '';
            _currentSubtitleIndex = null;
          });
          if (audiobookPath != null) {
            SubtitlePreferences.clearLastUsedVttPath(audiobookPath);
          }
        },
        onClearSecondary: () {
          setState(() {
            _secondarySubtitlePath = null;
            _secondarySubtitleFilePath = null;
            _secondarySubtitles = [];
            _secondarySubtitleText = '';
            _currentSecondarySubtitleIndex = null;
            _secondaryOriginalSubtitles = [];
          });
          if (audiobookPath != null) {
            SubtitlePreferences.clearLastUsedSecondaryVttPath(audiobookPath);
          }
        },
        onVttShowCreated: (filePath) async {
          setState(() {
            _primarySubtitlePath = filePath;
            _subtitleFilePath = filePath;
            _availableSubtitles = [];
          });
          final vttShowPath = VttShowService.vttShowPathFor(filePath);
          if (vttShowPath != null) {
            final styles = await VttShowService.load(vttShowPath);
            final content = await File(filePath).readAsString();
            final cues = _parseVTT(content);
            final reconciledStyles = VttShowService.reconcile(
              styles: styles,
              cues: cues,
            );
            setState(() {
              _vttShowStyles = styles;
              _vttShowActive = true;
              _vttShowRevealedLines = 1;
              _vttShowCurrentKey = null;
              _vttShowApplying = false;
              _subtitles = cues;
              _originalSubtitles = cues;
            });
          }
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            await _loadVttShowSilentAudio();
          }
        },
      ),
    );
  }

  Future<void> _loadSubtitles(String audiobookPath) async {
    try {
      setState(() {
        _primarySubtitlePath = null;
        _secondarySubtitleFilePath = null;
        _secondarySubtitlePath = null;
        _secondarySubtitles = [];
        _secondarySubtitleText = '';
        _currentSecondarySubtitleIndex = null;
        _currentSubtitleIndex = null;
        _currentSubtitleText = '';
        _vttShowStyles = {};
        _vttShowActive = false;
        _vttShowRevealedLines = 1;
        _vttShowCurrentKey = null;
        _vttShowApplying = false;
      });

      final dir = path.dirname(audiobookPath);
      final audiobookBase = path.basenameWithoutExtension(audiobookPath);
      final vttDir = path.join(dir, '${audiobookBase}_vtt');

      String? subtitlePath;

      final lastUsed =
          await SubtitlePreferences.loadLastUsedVttPath(audiobookPath);
      if (lastUsed != null && await File(lastUsed).exists()) {
        subtitlePath = lastUsed;
      }

      if (subtitlePath == null && await Directory(vttDir).exists()) {
        subtitlePath =
            await SubtitleOrganizer.findSubtitleInDirectory(audiobookPath);
      }

      if (subtitlePath == null) {
        final basePath = path.join(dir, audiobookBase);
        for (final ext in ['.vtt', '.srt']) {
          final testPath = '$basePath$ext';
          if (await File(testPath).exists()) {
            subtitlePath = testPath;
            break;
          }
        }
      }

      if (subtitlePath == null) {
        print('No subtitle file found for: ${path.basename(audiobookPath)}');
        setState(() {
          _subtitles = [];
          _originalSubtitles = [];
          _subtitleFilePath = null;
          _currentSubtitleText = '';
          _paragraphItems = [];
          _vttShowStyles = {};
          _vttShowActive = false;
          _vttShowRevealedLines = 1;
          _vttShowCurrentKey = null;
        });
        _updateWakelock();
        return;
      }

      String content = await File(subtitlePath).readAsString();
      if (subtitlePath.toLowerCase().endsWith('.srt')) {
        final vttPath = subtitlePath.replaceAll(
            RegExp(r'\.srt$', caseSensitive: false), '.vtt');
        final converted = _convertSrtToVtt(content);
        await File(vttPath).writeAsString(converted);
        subtitlePath = vttPath;
        content = converted;
      }

      setState(() {
        _subtitleFilePath = subtitlePath;
      });

      final originalCues = _parseVTT(content);
      setState(() {
        _originalSubtitles = originalCues;
        _paragraphItems = _createParagraphs(originalCues);
      });

      final vttShowPath = VttShowService.vttShowPathFor(subtitlePath);
      if (vttShowPath != null) {
        final styles = await VttShowService.load(vttShowPath);
        setState(() {
          _vttShowStyles = styles;
          _vttShowActive = true;
          _vttShowRevealedLines = 1;
          _vttShowCurrentKey = null;
          _vttShowApplying = false;
        });
        await player.pause();
      } else {
        setState(() {
          _vttShowStyles = {};
          _vttShowActive = false;
          _vttShowRevealedLines = 1;
          _vttShowCurrentKey = null;
          _vttShowApplying = false;
        });
      }

      final lastSecondary =
          await SubtitlePreferences.loadLastUsedSecondaryVttPath(audiobookPath);
      if (lastSecondary != null && await File(lastSecondary).exists()) {
        setState(() {
          _secondarySubtitleFilePath = lastSecondary;
        });
        await _applySecondaryConversion();
      }

      await _applyConversion();
      _updateWakelock();
      _scheduleFrequencyGeneration();
      _buildQuranVerseSearchIndexIfNeeded();
    } catch (e) {
      print('Error loading subtitles: $e');
      setState(() {
        _subtitles = [];
        _originalSubtitles = [];
        _subtitleFilePath = null;
        _currentSubtitleText = '';
        _paragraphItems = [];
      });
      _updateWakelock();
    }
  }

  VttShowStyle _captureCurrentVttShowStyle() {
    return VttShowStyle(
      font: _selectedFont,
      conversion: _conversionType == 'none' ? 'original' : _conversionType,
      fontColorOverride: switch (_fontColorOverride) {
        FontColorOverride.black => 'black',
        FontColorOverride.white => 'white',
        FontColorOverride.none => 'none',
      },
      fontSize: _subtitleFontSize,
      lineSpacing: _subtitleLineSpacing,
      colorPalette: _currentColorPalette?.name,
      coloringMode: _coloringMode == ColoringMode.letters ? 'letters' : 'words',
      blurShadow: _blurShadowEnabled ? 'blur_on' : 'blur_off',
    );
  }

  String? _currentVttShowKey() {
    if (_currentSubtitleIndex == null) return null;
    if (_currentSubtitleIndex! >= _subtitles.length) return null;
    final cue = _subtitles[_currentSubtitleIndex!];
    return '${_formatVttTime(cue.startTime)} --> ${_formatVttTime(cue.endTime)}';
  }

  List<String> _allSubtitleCueKeys() {
    return _subtitles
        .map((cue) =>
            '${_formatVttTime(cue.startTime)} --> ${_formatVttTime(cue.endTime)}')
        .toList();
  }

  void _vttShowCaptureIfChanged() {
    if (!_vttShowActive || _subtitleFilePath == null) return;
    final key = _currentVttShowKey();
    if (key == null) return;

    final current = _captureCurrentVttShowStyle();
    final existing = _vttShowStyles[key];

    final changed = existing == null ||
        existing.font != current.font ||
        existing.conversion != current.conversion ||
        existing.fontColorOverride != current.fontColorOverride ||
        existing.fontSize != current.fontSize ||
        existing.lineSpacing != current.lineSpacing ||
        existing.colorPalette != current.colorPalette ||
        existing.coloringMode != current.coloringMode ||
        existing.blurShadow != current.blurShadow;

    if (changed) {
      _vttShowStyles[key] = current;
    }
  }

  void _addCueAfter(int index) {
    const gap = Duration(seconds: 3);
    final current = _subtitles[index];

    final oldKeys = <int, String>{};
    for (int i = index + 1; i < _subtitles.length; i++) {
      oldKeys[i] = _subtitles[i].timecodeKey;
    }

    for (int i = index + 1; i < _subtitles.length; i++) {
      _subtitles[i] = _subtitles[i].copyWith(
        startTime: _subtitles[i].startTime + gap,
        endTime: _subtitles[i].endTime + gap,
      );
      _originalSubtitles[i] = _originalSubtitles[i].copyWith(
        startTime: _originalSubtitles[i].startTime + gap,
        endTime: _originalSubtitles[i].endTime + gap,
      );
    }

    for (final entry in oldKeys.entries) {
      final oldKey = entry.value;
      final newKey = _subtitles[entry.key].timecodeKey;
      if (oldKey != newKey && _vttShowStyles.containsKey(oldKey)) {
        _vttShowStyles[newKey] = _vttShowStyles.remove(oldKey)!;
      }
    }

    final newCue = SubtitleCue(
      startTime: current.endTime,
      endTime: current.endTime + gap,
      text: '',
    );

    setState(() {
      _subtitles.insert(index + 1, newCue);
      _originalSubtitles.insert(index + 1, newCue);
      _currentSubtitleIndex = index + 1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vttEditKey.currentState?.jumpToIndex(index + 1);
    });
  }

  Future<void> _applyVttShowStyle(String timecodeKey) async {
    if (!_vttShowActive) return;
    if (_vttShowApplying) {
      return;
    }
    if (_vttShowCurrentKey == timecodeKey) {
      return;
    }

    _vttShowApplying = true;
    _vttShowCurrentKey = timecodeKey;

    try {
      final style = _vttShowStyles[timecodeKey];
      if (style == null) return;

      bool needsConversion = false;

      setState(() {
        if (style.font != null) {
          _selectedFont = style.font!;
          final allFonts = CustomFontLoader.getAvailableFonts();
          _selectedFontIndex = allFonts.indexOf(style.font!);
          if (_selectedFontIndex == -1) _selectedFontIndex = 0;
        }
        if (style.fontSize != null) _subtitleFontSize = style.fontSize!;
        if (style.lineSpacing != null)
          _subtitleLineSpacing = style.lineSpacing!;
        if (style.fontColorOverride != null) {
          _fontColorOverride = switch (style.fontColorOverride!) {
            'black' => FontColorOverride.black,
            'white' => FontColorOverride.white,
            _ => FontColorOverride.none,
          };
        }
        if (style.colorPalette != null) {
          final palette = ColorPalette.presets.firstWhere(
            (p) => p.name == style.colorPalette,
            orElse: () => _currentColorPalette ?? ColorPalette.presets.first,
          );
          _currentColorPalette = palette;
          _selectedColorIndex = ColorPalette.presets.indexOf(palette);
        }
        if (style.conversion != null && style.conversion != _conversionType) {
          _conversionType = style.conversion!;
          needsConversion = true;
        }
        if (style.coloringMode != null) {
          _coloringMode = style.coloringMode == 'letters'
              ? ColoringMode.letters
              : ColoringMode.words;
        }
        if (style.blurShadow != null) {
          _blurShadowEnabled = style.blurShadow == 'blur_on';
        }
      });

      if (needsConversion) {
        switch (_conversionType) {
          case 'alternates':
            await _convertToAlternates(fromVttShow: true);
            break;
          case 'demo':
            await _convertToDemo();
            break;
          case 'missing':
            await _convertToMissing(fromVttShow: true);
            break;
          default:
            await _applyConversion();
        }
      }
    } finally {
      _vttShowApplying = false;
    }
  }

  void _scheduleFrequencyGeneration() {
    _frequencyGenerationTimer?.cancel();
    _frequencyGenerationTimer = Timer(const Duration(seconds: 20), () {
      _generateFrequenciesInBackground();
    });
  }

  Future<void> _generateFrequenciesInBackground() async {
    if (_subtitleFilePath == null) return;

    setState(() {
      _isAnalyzingFrequencies = true;
    });

    try {
      final results = await compute(
        _analyzeFrequenciesIsolate,
        _subtitleFilePath!,
      );

      setState(() {
        _frequencyItems = results;
        _isAnalyzingFrequencies = false;
      });
    } catch (e) {
      print('Error analyzing frequencies: $e');
      setState(() {
        _isAnalyzingFrequencies = false;
      });
    }
  }

  static Future<List<FrequencyItem>> _analyzeFrequenciesIsolate(
      String subtitlePath) async {
    return await FrequencyAnalyzer.analyzeSubtitleFile(subtitlePath);
  }

  List<Chapter> _getFilteredChapters() {
    if (_currentAudiobook == null) return [];
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _currentAudiobook!.chapters;
    }
    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _currentAudiobook!.chapters.where((chapter) {
      return _matchesSearch(chapter.title, _searchQuery, excludeList);
    }).toList();
  }

  List<String> _getFilteredFonts() {
    List<String> fontsToShow;

    if (_selectedMainCategory == 'all') {
      fontsToShow = ['System Default', ...CustomFontLoader.getAvailableFonts()];
    } else if (_selectedMainCategory == FontCategory.favorites) {
      fontsToShow = _favoriteFonts.toList()..sort();
    } else if (_selectedMainCategory == FontCategory.custom) {
      fontsToShow = CustomFontLoader.customFonts;
    } else if (_selectedMainCategory == FontCategory.custom2) {
      fontsToShow = CustomFontLoader.customFonts2;
    } else if (_selectedStudio != null) {
      fontsToShow = FontDatabase.getFontsByPath(
        _selectedMainCategory,
        subCat: _selectedSubCategory,
        studio: _selectedStudio,
      );
    } else if (_selectedSubCategory != null) {
      fontsToShow = FontDatabase.getFontsByPath(
        _selectedMainCategory,
        subCat: _selectedSubCategory,
      );
    } else {
      fontsToShow = FontDatabase.getFontsByMainCategory(_selectedMainCategory);
    }

    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return fontsToShow.where((font) {
      return _matchesSearch(font, _searchQuery, excludeList);
    }).toList();
  }

  List<ColorPalette> _getFilteredColors() {
    List<ColorPalette> palettes = ColorPalette.presets;

    switch (_colorFilter) {
      case ColorPaletteFilter.all:
        break;
      case ColorPaletteFilter.twentyColors:
        palettes = palettes.where((p) => p.colors.length == 20).toList();
        break;
      case ColorPaletteFilter.twelveColors:
        palettes = palettes.where((p) => p.colors.length == 12).toList();
        break;
      case ColorPaletteFilter.twentyTwelveColors:
        palettes = palettes
            .where((p) => p.colors.length == 20 || p.colors.length == 12)
            .toList();
        break;
      case ColorPaletteFilter.same:
        palettes = palettes.where((p) => p.name.startsWith('same')).toList();
        break;
      case ColorPaletteFilter.three:
        palettes = palettes.where((p) => p.name.startsWith('three')).toList();
        break;
      case ColorPaletteFilter.samethree:
        palettes = palettes
            .where(
                (p) => p.name.startsWith('same') || p.name.startsWith('three'))
            .toList();
        break;
      case ColorPaletteFilter.fontWhite:
        palettes =
            palettes.where((p) => p.name.startsWith('font (white)')).toList();
        break;
      case ColorPaletteFilter.fontBlack:
        palettes =
            palettes.where((p) => p.name.startsWith('font (black)')).toList();
        break;
      case ColorPaletteFilter.borderWhite:
        palettes =
            palettes.where((p) => p.name.startsWith('border (white)')).toList();
        break;
      case ColorPaletteFilter.borderBlack:
        palettes =
            palettes.where((p) => p.name.startsWith('border (black)')).toList();
        break;
    }

    if (_colorFilterMode == 'favorites') {
      palettes = palettes
          .where((p) => _favoriteColorPalettes.contains(p.name))
          .toList();
    }

    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return palettes.where((palette) {
      return _matchesSearch(palette.name, _searchQuery, excludeList);
    }).toList();
  }

  void _setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (duration == null || duration.inSeconds == -1) {
      setState(() {
        _sleepDuration = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer off'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    if (!_isPlaying) {
      player.play();
    }
    if (duration == Duration.zero) {
      if (_currentAudiobook == null) return;
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      final timeUntilChapterEnd = currentChapter.endTime - _currentPosition;
      if (timeUntilChapterEnd < const Duration(seconds: 15)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Too close to chapter end — wait till next chapter starts'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      setState(() {
        _sleepDuration = Duration.zero;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer: Chapter end'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    if (duration.inMinutes == -1) {
      if (_currentAudiobook == null) return;
      final lastChapter = _currentAudiobook!.chapters.last;
      final timeUntilBookEnd = lastChapter.endTime - _currentPosition;
      setState(() {
        _sleepDuration = Duration(minutes: -1);
      });
      final realTimeUntilBookEnd = Duration(
        microseconds:
            (timeUntilBookEnd.inMicroseconds / _playbackSpeed).round(),
      );
      _sleepTimer = Timer(realTimeUntilBookEnd, () {
        _sleepTimer = null;
        _triggerSleepTimerCountdown();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer: End of audiobook'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    setState(() {
      _sleepDuration = duration;
    });
    _sleepTimer = Timer(duration, () {
      _sleepTimer = null;
      _triggerSleepTimerCountdown();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer: ${duration.inMinutes} minutes'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _triggerSleepTimerCountdown() {
    if (_showSleepTimerCountdown || _sleepTimerCountdownTimer != null) {
      return;
    }

    if (_isPlaying) {
      player.pause();
    }
    if (_sleepTimerAction == SleepTimerAction.pauseOnly) {
      setState(() {
        _sleepDuration = null;
      });
      _sleepTimer?.cancel();
      _sleepTimer = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer: Paused playback'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    setState(() {
      _showSleepTimerCountdown = true;
      _sleepTimerCountdownSeconds = 300;
    });
    _sleepTimerCountdownTimer?.cancel();
    _sleepTimerCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      if (_sleepTimerCountdownSeconds <= 1) {
        timer.cancel();
        _sleepTimerCountdownTimer = null;
        setState(() {
          _sleepTimerCountdownSeconds = 0;
          _showSleepTimerCountdown = false;
        });
        windowManager.close();
        return;
      }
      setState(() {
        _sleepTimerCountdownSeconds--;
      });
    });
  }

  void _cancelSleepTimerCountdown() {
    _sleepTimerCountdownTimer?.cancel();
    _sleepTimerCountdownTimer = null;
    setState(() {
      _showSleepTimerCountdown = false;
      _sleepTimerCountdownSeconds = 60;
    });
  }

  Color _adjustColorIfBright(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);

    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    Color color;
    if (luminance > 0.7) {
      final darkenFactor = 0.8;
      final newR = (r * darkenFactor).round().clamp(0, 255);
      final newG = (g * darkenFactor).round().clamp(0, 255);
      final newB = (b * darkenFactor).round().clamp(0, 255);
      color = Color.fromARGB(255, newR, newG, newB);
    } else {
      color = _parseColor(hexColor);
    }

    return color;
  }

  void _scrollToSelectedColorPalette() {
    if (_currentColorPalette == null) return;
    final filteredColors = _getFilteredColors();
    final paletteIndex =
        filteredColors.indexWhere((p) => p.name == _currentColorPalette!.name);
    if (paletteIndex == -1) return;
    setState(() => _selectedColorIndex =
        ColorPalette.presets.indexOf(filteredColors[paletteIndex]));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_colorItemScrollController.isAttached) {
        _colorItemScrollController.scrollTo(
          index: paletteIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          if (_colorItemScrollController.isAttached) {
            _colorItemScrollController.jumpTo(
              index: paletteIndex,
              alignment: 0.1,
            );
          }
        });
      }
    });
  }

  void _scrollToCurrentChapter() {
    if (_currentAudiobook == null) return;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_chapterScrollController.isAttached) {
        _chapterScrollController.scrollTo(
          index: _currentChapterIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          if (_chapterScrollController.isAttached) {
            _chapterScrollController.jumpTo(
              index: _currentChapterIndex,
              alignment: 0.1,
            );
          }
        });
      }
    });
  }

  void _scrollToCurrentPlaylistItem() {
    if (_showPanel &&
        _panelMode == PanelMode.playlist &&
        _currentAudiobook != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_playlistScrollController.hasClients) {
          final currentIndex = _playlist.indexOf(_currentAudiobook!.path);
          if (currentIndex == -1) return;
          final maxScroll = _playlistScrollController.position.maxScrollExtent;
          if (maxScroll <= 0) return;
          final totalItems = _playlist.length;
          if (totalItems <= 1) return;
          final percentage = currentIndex / (totalItems - 1);
          final targetScroll = maxScroll * percentage;
          _playlistScrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _scrollToTopOfHistory() {
    if (_showPanel &&
        (_panelMode == PanelMode.history ||
            _panelMode == PanelMode.bookmarks)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_historyScrollController.hasClients) {
          _historyScrollController.jumpTo(0);
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('history') ?? [];
    setState(() {
      _history = historyJson
          .map((jsonStr) {
            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              return HistoryItem.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .whereType<HistoryItem>()
          .toList();
    });
  }

  Future<void> _saveToHistory() async {
    if (_currentAudiobook == null) return;

    _history.removeWhere((h) => h.audiobookPath == _currentAudiobook!.path);

    final chapterTitle = _currentAudiobook!.chapters.isEmpty
        ? (_isYouTubeStream ? 'YouTube Stream' : 'No chapters')
        : _currentAudiobook!.chapters[_currentChapterIndex].title;

    final chapterIndex =
        _currentAudiobook!.chapters.isEmpty ? 0 : _currentChapterIndex;

    _history.insert(
      0,
      HistoryItem(
        audiobookPath: _currentAudiobook!.path,
        audiobookTitle: _currentAudiobook!.title,
        chapterTitle: chapterTitle,
        lastChapter: chapterIndex,
        lastPosition: _currentPosition,
        lastPlayed: DateTime.now(),
        shuffleEnabled: _shuffleEnabled,
        playedChapters: _playedChapters,
        isYouTube: _isYouTubeStream,
      ),
    );

    if (_history.length > 200) {
      _history = _history.sublist(0, 200);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      _history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> _removeFromHistory(int index) async {
    setState(() {
      _history.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      _history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final rootDir = prefs.getString('playlistRootDir');
    if (rootDir != null && await Directory(rootDir).exists()) {
      setState(() {
        _playlistRootDir = rootDir;
      });
      await _scanPlaylist(rootDir);
    }
  }

  Future<void> _addPlaylistDirectory() async {
    if (_playlistDirectories.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Maximum 10 playlist directories allowed')),
      );
      return;
    }

    String? directoryToAdd;

    if (_currentAudiobook != null) {
      final currentDir = path.dirname(_currentAudiobook!.path);
      final currentDirName = path.basename(currentDir);

      final shouldUseCurrentDir = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Add Playlist Directory',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add current audiobook directory?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentDirName,
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Choose Different Directory'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add This Directory'),
            ),
          ],
        ),
      );

      if (shouldUseCurrentDir == true) {
        directoryToAdd = currentDir;
      } else if (shouldUseCurrentDir == false) {
        directoryToAdd = await FilePicker.platform.getDirectoryPath();
      } else {
        return;
      }
    } else {
      directoryToAdd = await FilePicker.platform.getDirectoryPath();
    }

    if (directoryToAdd == null) return;

    if (_playlistDirectories.contains(directoryToAdd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Directory already in playlists')),
      );
      return;
    }

    setState(() {
      _playlistDirectories.add(directoryToAdd!);
      if (_activePlaylistIndex == null) {
        _activePlaylistIndex = 0;
      }
    });

    await _savePlaylistDirectories();

    if (_activePlaylistIndex == _playlistDirectories.length - 1) {
      await _scanPlaylist(directoryToAdd);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Added playlist directory: ${path.basename(directoryToAdd)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removePlaylistDirectory(int index) async {
    setState(() {
      _playlistDirectories.removeAt(index);
      if (_activePlaylistIndex == index) {
        _activePlaylistIndex = _playlistDirectories.isNotEmpty ? 0 : null;
        if (_activePlaylistIndex != null) {
          _scanPlaylist(_playlistDirectories[_activePlaylistIndex!]);
        } else {
          _playlist.clear();
        }
      } else if (_activePlaylistIndex != null &&
          _activePlaylistIndex! > index) {
        _activePlaylistIndex = _activePlaylistIndex! - 1;
      }
    });
    await _savePlaylistDirectories();
  }

  Future<void> _setActivePlaylist(int index) async {
    if (index >= _playlistDirectories.length) return;
    setState(() {
      _activePlaylistIndex = index;
      _playlistChapterIndex.clear();
      _chapterSearchQuery = '';
      _chapterSearchResults = [];
      _chapterSearchController.clear();
    });
    await _savePlaylistDirectories();
    await _scanPlaylist(_playlistDirectories[index]);
    await _loadChapterIndex();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Active playlist: ${path.basename(_playlistDirectories[index])}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _savePlaylistDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('playlistDirectories', _playlistDirectories);
    if (_activePlaylistIndex != null) {
      await prefs.setInt('activePlaylistIndex', _activePlaylistIndex!);
    } else {
      await prefs.remove('activePlaylistIndex');
    }
  }

  Future<void> _loadPlaylistDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    final dirs = prefs.getStringList('playlistDirectories') ?? [];
    final activeIndex = prefs.getInt('activePlaylistIndex');
    setState(() {
      _playlistDirectories = dirs;
      _activePlaylistIndex = activeIndex;
    });
    if (_activePlaylistIndex != null &&
        _activePlaylistIndex! < _playlistDirectories.length) {
      await _scanPlaylist(_playlistDirectories[_activePlaylistIndex!]);
    }
  }

  String _shortenPath(String fullPath) {
    final home = Platform.environment['HOME'] ??
        '/Users/${Platform.environment['USER']}';
    if (fullPath.startsWith(home)) {
      return fullPath.replaceFirst(home, '~');
    }
    return fullPath;
  }

  Future<void> _saveDurationCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('durationCache', jsonEncode(_playlistDurationCache));
  }

  Future<void> _loadDurationCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString('durationCache');
    if (cacheJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cacheJson);
        setState(() {
          _playlistDurationCache.clear();
          decoded.forEach((key, value) {
            _playlistDurationCache[key] = value.toString();
          });
        });
      } catch (e) {
        print('Error loading duration cache: $e');
      }
    }
  }

  Future<void> _analyzeFrequencies() async {
    if (_subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subtitle file loaded')),
      );
      return;
    }

    _frequencyGenerationTimer?.cancel();
    await _generateFrequenciesInBackground();
  }

  List<FrequencyItem> _getFilteredFrequencies() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _frequencyItems;
    }
    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _frequencyItems.where((item) {
      return _matchesSearch(item.text, _searchQuery, excludeList);
    }).toList();
  }

  List<ParagraphItem> _createParagraphs(List<SubtitleCue> subtitles) {
    if (subtitles.isEmpty) return [];
    final paragraphs = <ParagraphItem>[];
    final sentences = <String>[];
    for (final cue in subtitles) {
      final text = cue.text.replaceAll('\n', ' ').trim();
      if (text.isEmpty) continue;
      final words = text.split(RegExp(r'\s+'));
      var currentSentence = '';
      for (final word in words) {
        currentSentence += word + ' ';
        if (word.endsWith('.') || word.endsWith('?') || word.endsWith('!')) {
          final abbreviations = [
            'Mr.',
            'Dr.',
            'Mrs.',
            'Ms.',
            'Prof.',
            'Sr.',
            'Jr.'
          ];
          final isAbbreviation = abbreviations
              .any((abbr) => currentSentence.trim().endsWith(abbr));
          if (!isAbbreviation) {
            sentences.add(currentSentence.trim());
            currentSentence = '';
          }
        }
      }
      if (currentSentence.trim().isNotEmpty) {
        sentences.add(currentSentence.trim());
      }
    }
    int paraNum = 1;
    for (int i = 0; i < sentences.length; i += 9) {
      final paragraphSentences = sentences.skip(i).take(9).toList();
      if (paragraphSentences.isNotEmpty) {
        final paragraphText = paragraphSentences.join(' ');
        paragraphs.add(ParagraphItem(
          chapterNumber: 0,
          paragraphNumber: paraNum,
          text: paragraphText,
        ));
        paraNum++;
      }
    }
    return paragraphs;
  }

  void _searchSubtitles(String query) {
    if (query.isEmpty) {
      setState(() {
        _subsSearchQuery = '';
        _subtitleSearchResults = [];
      });
      return;
    }

    final results = <SubtitleSearchResult>[];
    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();

    for (final cue in _originalSubtitles) {
      if (_matchesSearch(cue.text, query, excludeList)) {
        results.add(SubtitleSearchResult(
          time: cue.startTime,
          text: cue.text,
        ));
      }
    }

    setState(() {
      _subsSearchQuery = query;
      _subtitleSearchResults = results;
    });
  }

  Future<void> _showAudioStreamPicker(String youtubeUrl) async {
    if (_isLoadingAudioStreams) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading audio streams, patience...'),
          duration: Duration(seconds: 9),
        ),
      );
      return;
    }

    if (_lastAudioStreamFetch != null) {
      final timeSinceLastFetch =
          DateTime.now().difference(_lastAudioStreamFetch!);
      if (timeSinceLastFetch.inSeconds < 3) {
        final remainingSeconds = 3 - timeSinceLastFetch.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Please wait $remainingSeconds more second${remainingSeconds != 1 ? 's' : ''}...'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoadingAudioStreams = true;
      _lastAudioStreamFetch = DateTime.now();
    });

    try {
      final streams = await YouTubeService.getAvailableAudioStreams(youtubeUrl);

      if (streams.isEmpty) {
        _showError('No audio streams found');
        return;
      }

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final stream in streams) {
        final lang = stream['language'] as String;
        grouped.putIfAbsent(lang, () => []).add(stream);
      }

      if (!mounted) return;

      final selectedFormatId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Audio Stream',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'DRC (Dynamic Range Compression) makes quiet and loud parts more even in volume',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 500,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final lang = grouped.keys.elementAt(index);
                final langStreams = grouped[lang]!;

                return ExpansionTile(
                  title: Text(
                    lang,
                    style: TextStyle(
                      fontWeight: langStreams.first['isOriginal']
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: langStreams.first['isOriginal']
                          ? Colors.green
                          : Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    '${langStreams.length} formats available',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  initiallyExpanded: langStreams.first['isOriginal'],
                  children: langStreams.map((stream) {
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.only(left: 32, right: 16),
                      title: Text(
                        stream['description'],
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'id: ${stream['id']}',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      trailing: Text(
                        stream['ext'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, stream['id']),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (selectedFormatId != null) {
        final savedPosition = _currentPosition;

        final audioUrl = await YouTubeService.getAudioStreamUrl(
          youtubeUrl,
          formatId: selectedFormatId,
        );

        if (audioUrl != null) {
          await player.pause();
          await player.open(Media(audioUrl));
          await player.setRate(_playbackSpeed);
          await player.stream.duration.first;
          await player.seek(savedPosition);
          await player.play();

          setState(() {
            _currentAudioFormat = streams
                .firstWhere((s) => s['id'] == selectedFormatId)['description'];
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Switched to format: $selectedFormatId'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudioStreams = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildSearchContent() {
    if (_chapterSearchQuery.isNotEmpty) {
      return _buildChapterSearchResults();
    } else if (_subsSearchQuery.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: _buildSubtitlesSection(),
          ),
          Container(
            width: 1,
            color: Colors.white24,
          ),
          Expanded(
            child: _buildParagraphsSection(),
          ),
        ],
      );
    } else {
      return const Center(
        child: Text(
          'Enter search terms above',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
  }

  Widget _buildChapterSearchResults() {
    if (_chapterSearchResults.isEmpty) {
      return const Center(
        child: Text(
          'No chapters found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Playlist Chapters (${_chapterSearchResults.length})',
            style: TextStyle(
              color: Colors.purple[200],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _chapterSearchResults.length,
            itemBuilder: (context, index) {
              final result = _chapterSearchResults[index];
              return InkWell(
                onTap: () => _jumpToChapterResult(result),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF006064),
                        radius: 12,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result.audiobookTitle,
                              style: const TextStyle(
                                color: Colors.lightBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: _highlightSearchTerm(
                                  result.chapterTitle, _chapterSearchQuery),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Chapter ${result.chapterIndex + 1} • ${_formatDuration(result.startTime)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildSubtitlesSection() {
    final filteredSubs = _subtitleSearchResults;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Subtitles (${filteredSubs.length})',
            style: TextStyle(
              color: Colors.purple[200],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: filteredSubs.isEmpty
              ? const Center(
                  child: Text(
                    'No subtitles match',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredSubs.length,
                  itemBuilder: (context, index) {
                    final result = filteredSubs[index];
                    return InkWell(
                      onTap: () async {
                        await _seekTo(
                            result.time + const Duration(milliseconds: 200));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDuration(result.time),
                              style: const TextStyle(
                                color: Colors.lightBlue,
                                fontSize: 12,
                                height: 1.0,
                                fontFamilyFallback: const [
                                  '.AppleSystemUIFont',
                                  'Segoe UI',
                                  'Roboto',
                                  'Scheherazade New',
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: _highlightSearchTerm(
                                  result.text, _subsSearchQuery),
                            ),
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

  Widget _buildParagraphsSection() {
    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    final filteredParas = _paragraphItems.where((para) {
      return _matchesSearch(para.text, _subsSearchQuery, excludeList);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Paragraphs (${filteredParas.length})',
            style: TextStyle(
              color: Colors.purple[200],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: filteredParas.isEmpty
              ? const Center(
                  child: Text(
                    'No paragraphs match',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredParas.length,
                  itemBuilder: (context, index) {
                    final para = filteredParas[index];
                    return InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: para.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Paragraph copied to clipboard'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${para.paragraphNumber}',
                              style: const TextStyle(
                                color: Colors.lightBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: _highlightSearchTerm(
                                  para.text, _subsSearchQuery),
                            ),
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

  Future<void> _exportMarkdownParagraphs() async {
    if (_currentAudiobook == null || _originalSubtitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook or subtitles loaded')),
      );
      return;
    }

    setState(() {
      _isExportingMarkdown = true;
      _exportStatus = 'Starting export...';
    });

    try {
      final audiobookPath = _currentAudiobook!.path;
      final audiobookDir = path.dirname(audiobookPath);
      final audiobookBase = path.basenameWithoutExtension(audiobookPath);
      final exportPath =
          path.join(audiobookDir, '${audiobookBase}_paragraphs.md');

      final chapters = _currentAudiobook!.chapters;
      final mdContent = StringBuffer();

      mdContent.writeln('# $audiobookBase\n');

      for (int chapterIndex = 0;
          chapterIndex < chapters.length;
          chapterIndex++) {
        final chapter = chapters[chapterIndex];

        setState(() {
          _exportStatus =
              'Processing chapter ${chapterIndex + 1}/${chapters.length}: ${chapter.title}';
        });

        mdContent.writeln('## Chapter ${chapterIndex + 1}: ${chapter.title}\n');

        final chapterSubs = _originalSubtitles.where((sub) {
          return sub.startTime >= chapter.startTime &&
              sub.startTime < chapter.endTime;
        }).toList();

        if (chapterSubs.isEmpty) {
          mdContent.writeln('*No subtitles available for this chapter*\n');
          continue;
        }

        final paragraphs = _createParagraphsFromSubs(chapterSubs);

        for (final paragraph in paragraphs) {
          mdContent.writeln(paragraph);
          mdContent.writeln();
        }

        mdContent.writeln();
      }

      await File(exportPath).writeAsString(mdContent.toString());

      setState(() {
        _isExportingMarkdown = false;
        _exportStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Exported ${chapters.length} chapters to:\n${path.basename(exportPath)}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isExportingMarkdown = false;
        _exportStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<MapEntry<String, String>> _extractQuranVerseTexts(
      List<SubtitleCue> cues) {
    final result = <MapEntry<String, String>>[];
    final pattern = RegExp(r'^(\d+)\s*,\s*(\d+)\s+(.*)$', dotAll: true);

    String? currentKey;
    final currentText = StringBuffer();

    for (final cue in cues) {
      final raw = cue.text.replaceAll('\n', ' ').trim();
      if (raw.isEmpty) continue;
      final match = pattern.firstMatch(raw);

      if (match != null) {
        final key = '${match.group(1)}:${match.group(2)}';
        final text = match.group(3)!.trim();
        if (currentKey != null && currentKey != key) {
          result.add(MapEntry(currentKey!, currentText.toString().trim()));
          currentText.clear();
        }
        currentKey = key;
        if (currentText.isNotEmpty) currentText.write(' ');
        currentText.write(text);
      } else if (currentKey != null) {
        // Continuation line for the same verse (no leading "surah,ayah")
        if (currentText.isNotEmpty) currentText.write(' ');
        currentText.write(raw);
      }
    }
    if (currentKey != null) {
      result.add(MapEntry(currentKey!, currentText.toString().trim()));
    }
    return result;
  }

  Future<void> _exportQuranCombinedMarkdown() async {
    if (_currentAudiobook == null || _subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook or subtitles loaded')),
      );
      return;
    }

    setState(() {
      _isExportingMarkdown = true;
      _exportStatus = 'Starting Quran export...';
    });

    try {
      final currentOpusPath = _currentAudiobook!.path;
      final opusDir = path.dirname(currentOpusPath);
      final reciterSuffix = path
          .basename(currentOpusPath)
          .replaceFirst(RegExp(r'^.*?\d{3}-\d{3} '), '');

      final currentVttPath = _subtitleFilePath!;
      final vttDir = path.dirname(currentVttPath);
      final langSubdir = path.basename(vttDir);
      final vttParentDir = path.dirname(vttDir);

      final languageName = path.basename(opusDir);
      final exportPath = path.join(opusDir, '$languageName.md');

      final mdContent = StringBuffer();
      mdContent.writeln('# $languageName\n');

      final rangeKeys = quranFileRanges.keys.toList();

      for (int i = 0; i < rangeKeys.length; i++) {
        final rangeKey = rangeKeys[i];
        setState(() {
          _exportStatus =
              'Processing range $rangeKey (${i + 1}/${rangeKeys.length})...';
        });

        final targetOpusName = 'Quran Arabic - $rangeKey $reciterSuffix';
        final targetBase = path.basenameWithoutExtension(targetOpusName);
        final targetVttName = '$targetBase.vtt';

        final candidate1 = path.join(vttParentDir, langSubdir, targetVttName);
        final candidate2 = path.join(
          opusDir,
          '${targetBase}_vtt',
          langSubdir,
          targetVttName,
        );
        final candidate3 = path.join(opusDir, targetVttName);

        String? foundVtt;
        for (final candidate in [candidate1, candidate2, candidate3]) {
          if (await File(candidate).exists()) {
            foundVtt = candidate;
            break;
          }
        }

        if (foundVtt == null) {
          mdContent.writeln(
              '*Missing subtitle file for range $rangeKey: $targetVttName*\n');
          continue;
        }

        final vttContent = await File(foundVtt).readAsString();
        final rangeSubs = _parseVTT(vttContent);
        final verses = _extractQuranVerseTexts(rangeSubs);

        for (final entry in verses) {
          mdContent.writeln('## ${entry.key}\n');
          mdContent.writeln(entry.value);
          mdContent.writeln();
        }
      }

      await File(exportPath).writeAsString(mdContent.toString());

      setState(() {
        _isExportingMarkdown = false;
        _exportStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Exported combined Quran translation to:\n${path.basename(exportPath)}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isExportingMarkdown = false;
        _exportStatus = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<String> _createParagraphsFromSubs(List<SubtitleCue> subs) {
    if (subs.isEmpty) return [];

    final allText = subs
        .map((cue) => cue.text.replaceAll('\n', ' ').trim())
        .where((text) => text.isNotEmpty)
        .join(' ');

    final sentences = <String>[];
    final words = allText.split(RegExp(r'\s+'));
    var currentSentence = '';

    for (final word in words) {
      currentSentence += word + ' ';

      if (word.endsWith('.') || word.endsWith('?') || word.endsWith('!')) {
        final abbreviations = [
          'Mr.',
          'Dr.',
          'Mrs.',
          'Ms.',
          'Prof.',
          'Sr.',
          'Jr.',
          'St.'
        ];
        final isAbbreviation =
            abbreviations.any((abbr) => currentSentence.trim().endsWith(abbr));

        if (!isAbbreviation) {
          sentences.add(currentSentence.trim());
          currentSentence = '';
        }
      }
    }

    if (currentSentence.trim().isNotEmpty) {
      sentences.add(currentSentence.trim());
    }

    final paragraphs = <String>[];
    for (int i = 0; i < sentences.length; i += 9) {
      final paragraphSentences = sentences.skip(i).take(9).toList();
      if (paragraphSentences.isNotEmpty) {
        var paragraph = paragraphSentences.join(' ');

        if (paragraph.isNotEmpty) {
          paragraph = paragraph[0].toUpperCase() + paragraph.substring(1);
        }

        paragraphs.add(paragraph);
      }
    }

    return paragraphs;
  }

  TextSpan _highlightSearchTerm(String text, String searchTerm) {
    if (searchTerm.isEmpty) {
      return TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamilyFallback: [
            '.AppleSystemUIFont',
            'Segoe UI',
            'Roboto',
            'Scheherazade New',
          ],
        ),
      );
    }

    final exactPhrases = <String>[];
    final exactWords = <String>[];
    final regularTerms = <String>[];

    int i = 0;
    while (i < searchTerm.length) {
      if (searchTerm[i] == '"') {
        final endQuote = searchTerm.indexOf('"', i + 1);
        if (endQuote != -1) {
          final quoted = searchTerm.substring(i + 1, endQuote);
          if (quoted.contains(' ')) {
            exactPhrases.add(quoted);
          } else {
            exactWords.add(quoted);
          }
          i = endQuote + 1;
        } else {
          i++;
        }
      } else if (searchTerm[i] != ' ') {
        final nextSpace = searchTerm.indexOf(' ', i);
        if (nextSpace == -1) {
          regularTerms.add(searchTerm.substring(i));
          break;
        } else {
          regularTerms.add(searchTerm.substring(i, nextSpace));
          i = nextSpace;
        }
      } else {
        i++;
      }
    }

    final lowerText = text.toLowerCase();
    final matches = <Map<String, int>>[];

    for (final phrase in exactPhrases) {
      final lowerPhrase = phrase.toLowerCase();
      int start = 0;
      while (true) {
        final index = lowerText.indexOf(lowerPhrase, start);
        if (index == -1) break;
        matches.add({
          'start': index,
          'end': index + phrase.length,
        });
        start = index + 1;
      }
    }

    for (final word in exactWords) {
      final lowerWord = word.toLowerCase();
      final pattern = RegExp(r'\b' + RegExp.escape(lowerWord) + r'\b',
          caseSensitive: false);
      for (final match in pattern.allMatches(lowerText)) {
        matches.add({
          'start': match.start,
          'end': match.end,
        });
      }
    }

    for (final term in regularTerms) {
      final lowerTerm = term.toLowerCase();
      int start = 0;
      while (true) {
        final index = lowerText.indexOf(lowerTerm, start);
        if (index == -1) break;
        matches.add({
          'start': index,
          'end': index + term.length,
        });
        start = index + 1;
      }
    }

    matches.sort((a, b) => a['start']!.compareTo(b['start']!));
    final mergedMatches = <Map<String, int>>[];
    for (final match in matches) {
      if (mergedMatches.isEmpty) {
        mergedMatches.add(match);
      } else {
        final last = mergedMatches.last;
        if (match['start']! <= last['end']!) {
          last['end'] = max(last['end']!, match['end']!);
        } else {
          mergedMatches.add(match);
        }
      }
    }

    final spans = <TextSpan>[];
    int lastPos = 0;
    for (final match in mergedMatches) {
      if (match['start']! > lastPos) {
        spans.add(TextSpan(
          text: text.substring(lastPos, match['start']!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamilyFallback: [
              '.AppleSystemUIFont',
              'Segoe UI',
              'Roboto',
              'Scheherazade New',
            ],
          ),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match['start']!, match['end']!),
        style: const TextStyle(
          color: Colors.green,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamilyFallback: [
            '.AppleSystemUIFont',
            'Segoe UI',
            'Roboto',
            'Scheherazade New',
          ],
        ),
      ));
      lastPos = match['end']!;
    }
    if (lastPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastPos),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamilyFallback: [
            '.AppleSystemUIFont',
            'Segoe UI',
            'Roboto',
            'Scheherazade New',
          ],
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  Future<void> _scanPlaylist(String dirPath) async {
    final dir = Directory(dirPath);
    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File &&
          path.extension(entity.path).toLowerCase() == '.opus') {
        final segments = path.split(entity.path);
        if (segments.any((s) => s.startsWith('.'))) continue;
        files.add(entity.path);
      }
    }
    files.sort();
    setState(() {
      _playlist = files;
      _playlistRootDir = dirPath;

      bool foundMatch = false;
      for (int i = 0; i < _playlistDirectories.length; i++) {
        if (dirPath.startsWith(_playlistDirectories[i])) {
          _activePlaylistIndex = i;
          foundMatch = true;
          break;
        }
      }

      if (!foundMatch) {
        _activePlaylistIndex = null;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlistRootDir', dirPath);

    _startBackgroundDurationCaching(files);
  }

  Future<void> _startBackgroundDurationCaching(List<String> files) async {
    try {
      await _ffmpeg.ensureBinaries();
    } catch (e) {
      print('FFmpeg not available for duration caching: $e');
      return;
    }

    for (final filePath in files) {
      if (_playlistDurationCache.containsKey(filePath)) {
        continue;
      }

      while (_activeFfprobeCount >= _maxConcurrentFfprobe) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _activeFfprobeCount++;

      try {
        final duration = await _ffmpeg.getAudioDuration(filePath);

        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        String formatted;
        if (hours > 0) {
          formatted = '${hours}h ${minutes}m';
        } else {
          formatted = '${minutes}m';
        }
        if (mounted) {
          setState(() {
            _playlistDurationCache[filePath] = formatted;
          });
        }
      } catch (e) {
        print('Error caching duration for $filePath: $e');
      } finally {
        _activeFfprobeCount--;
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }

    await _saveDurationCache();
  }

  Future<void> _cacheSingleFileDuration(String filePath) async {
    if (_playlistDurationCache.containsKey(filePath)) {
      return;
    }

    try {
      await _ffmpeg.ensureBinaries();
      final duration = await _ffmpeg.getAudioDuration(filePath);

      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      String formatted;
      if (hours > 0) {
        formatted = '${hours}h ${minutes}m';
      } else {
        formatted = '${minutes}m';
      }

      setState(() {
        _playlistDurationCache[filePath] = formatted;
      });

      await _saveDurationCache();
    } catch (e) {
      print(
          'DEBUG: Error caching single file duration for ${path.basename(filePath)}: $e');
    }
  }

  Future<void> _setPlaylistDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    await _scanPlaylist(result);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playlist directory set to: ${path.basename(result)}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<int> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      return await file.length();
    } catch (e) {
      return 0;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).floor()}KiB';
    return '${(bytes / (1024 * 1024)).floor()}MiB';
  }

  int _getNextShuffleChapter() {
    if (_currentAudiobook == null) return 0;
    final totalChapters = _currentAudiobook!.chapters.length;
    final unplayedChapters = List.generate(totalChapters, (i) => i)
        .where((i) =>
            !_playedChapters.contains(i) &&
            !_shouldSkipChapter(_currentAudiobook!.chapters[i].title))
        .toList();
    if (unplayedChapters.isEmpty) {
      return _currentChapterIndex;
    }
    return unplayedChapters[Random().nextInt(unplayedChapters.length)];
  }

  Future<void> _increaseSpeed() async {
    setState(() {
      _playbackSpeed = (_playbackSpeed + 0.1).clamp(0.5, 2.0);
    });
    await player.setRate(_playbackSpeed);

    if (_sleepDuration != null) {
      _setSleepTimer(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer cancelled due to speed change'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _decreaseSpeed() async {
    setState(() {
      _playbackSpeed = (_playbackSpeed - 0.1).clamp(0.5, 2.0);
    });
    await player.setRate(_playbackSpeed);

    if (_sleepDuration != null) {
      _setSleepTimer(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer cancelled due to speed change'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _increaseFontSize() {
    setState(() {
      _subtitleFontSize = (_subtitleFontSize + 1).clamp(40, 170);
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _subtitleFontSize = (_subtitleFontSize - 1).clamp(40, 170);
    });
  }

  void _toggleShuffle() {
    setState(() {
      _shuffleEnabled = !_shuffleEnabled;
      if (_shuffleEnabled && !_playedChapters.contains(_currentChapterIndex)) {
        _playedChapters.add(_currentChapterIndex);
      }
    });
    _saveToHistory();
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getStringList('bookmarks') ?? [];
    setState(() {
      _bookmarks = bookmarksJson
          .map((jsonStr) {
            try {
              final json = jsonDecode(jsonStr) as Map<String, dynamic>;
              return Bookmark.fromJson(json);
            } catch (e) {
              return null;
            }
          })
          .whereType<Bookmark>()
          .toList();
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bookmarks',
      _bookmarks.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  Future<void> _addBookmark() async {
    if (_currentAudiobook == null) return;

    final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
    final timeFromChapterStart = _currentPosition - currentChapter.startTime;
    final timeUntilChapterEnd = currentChapter.endTime - _currentPosition;

    Duration bookmarkPosition = _currentPosition;
    int bookmarkChapterIndex = _currentChapterIndex;
    String bookmarkChapterTitle = currentChapter.title;

    if (timeFromChapterStart.inSeconds <= 10) {
      bookmarkPosition = currentChapter.startTime;
      bookmarkChapterTitle = currentChapter.title;
      bookmarkChapterIndex = _currentChapterIndex;
    } else if (timeUntilChapterEnd.inSeconds <= 10 &&
        _currentChapterIndex < _currentAudiobook!.chapters.length - 1) {
      bookmarkChapterIndex = _currentChapterIndex + 1;
      final nextChapter = _currentAudiobook!.chapters[bookmarkChapterIndex];
      bookmarkPosition = nextChapter.startTime;
      bookmarkChapterTitle = nextChapter.title;
    }

    final bookmark = Bookmark(
      audiobookPath: _currentAudiobook!.path,
      audiobookTitle: _currentAudiobook!.title,
      chapterTitle: bookmarkChapterTitle,
      chapterIndex: bookmarkChapterIndex,
      position: bookmarkPosition,
      created: DateTime.now(),
    );

    setState(() {
      _bookmarks.insert(0, bookmark);
    });
    await _saveBookmarks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(timeFromChapterStart.inSeconds <= 10 ||
                  timeUntilChapterEnd.inSeconds <= 10
              ? 'Bookmark added (snapped to chapter start)'
              : 'Bookmark added'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _removeBookmark(int index) async {
    setState(() {
      _bookmarks.removeAt(index);
    });
    await _saveBookmarks();
  }

  Future<void> _jumpToBookmark(Bookmark bookmark) async {
    if (_currentAudiobook?.path != bookmark.audiobookPath) {
      await _openAudiobook(bookmark.audiobookPath);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await _seekTo(bookmark.position);
    setState(() {
      _showPanel = false;
    });
  }

  void _refreshPlaylistDirectory() async {
    if (_activePlaylistIndex != null &&
        _activePlaylistIndex! < _playlistDirectories.length) {
      final dir = _playlistDirectories[_activePlaylistIndex!];
      setState(() {
        _playlist.clear();
        _playlistDurationCache.clear();
      });
      await _scanPlaylist(dir);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist refreshed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _refreshCustomFonts() async {
    if (_customFontDirectory == null) return;

    CustomFontLoader.clearCustomFonts(slot: 1);
    await CustomFontLoader.loadCustomFonts(_customFontDirectory!, slot: 1);

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Loaded ${CustomFontLoader.customFonts.length} custom1 fonts'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _refreshCustomFonts2() async {
    if (_customFontDirectory2 == null) return;

    CustomFontLoader.clearCustomFonts(slot: 2);
    await CustomFontLoader.loadCustomFonts(_customFontDirectory2!, slot: 2);

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Loaded ${CustomFontLoader.customFonts2.length} custom2 fonts'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _jumpToHistoryItem(int index) async {
    final filteredHistory = _getFilteredHistory();

    if (index >= filteredHistory.length) return;

    final historyItem = filteredHistory[index];
    setState(() {
      _showPanel = false;
    });
    await _openAudiobook(historyItem.audiobookPath);
  }

  Future<void> _jumpToPlaylistItem(int index) async {
    final filteredPlaylist = _getFilteredPlaylist();

    if (index >= filteredPlaylist.length) return;

    final playlistPath = filteredPlaylist[index];
    setState(() {
      _showPanel = false;
    });
    await _openAudiobook(playlistPath);
  }

  Future<void> _saveFontSettings() async {
    if (_currentAudiobook == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_${_currentAudiobook!.path}', _selectedFont);
    await prefs.setDouble(
        'fontSize_${_currentAudiobook!.path}', _subtitleFontSize);
    await prefs.setString(
        'conversionType_${_currentAudiobook!.path}', _conversionType);
    await prefs.setDouble(
        'lineSpacing_${_currentAudiobook!.path}', _subtitleLineSpacing);
    if (_currentColorPalette != null) {
      await prefs.setString('colorPalette_${_currentAudiobook!.path}',
          _currentColorPalette!.name);
    }
  }

  Future<void> _loadFontSettings(String audiobookPath) async {
    final prefs = await SharedPreferences.getInstance();
    final savedFont = prefs.getString('font_$audiobookPath');
    final savedFontSize = prefs.getDouble('fontSize_$audiobookPath');
    final savedColorPalette = prefs.getString('colorPalette_$audiobookPath');
    final savedConversionType =
        prefs.getString('conversionType_$audiobookPath');
    final savedLineSpacing = prefs.getDouble('lineSpacing_$audiobookPath');
    if (savedLineSpacing != null) {
      _subtitleLineSpacing = savedLineSpacing;
    }

    setState(() {
      if (savedFont != null) {
        _selectedFont = savedFont;
        final allFonts = CustomFontLoader.getAvailableFonts();
        _selectedFontIndex = allFonts.indexOf(savedFont);
        if (_selectedFontIndex == -1) _selectedFontIndex = 0;
      } else {
        _selectedFont = _defaultFont;
        final allFonts = CustomFontLoader.getAvailableFonts();
        _selectedFontIndex = allFonts.indexOf(_defaultFont);
        if (_selectedFontIndex == -1) _selectedFontIndex = 0;
      }

      if (savedFontSize != null) {
        _subtitleFontSize = savedFontSize;
      }

      if (savedColorPalette != null) {
        final palette = ColorPalette.presets.firstWhere(
          (p) => p.name == savedColorPalette,
          orElse: () => ColorPalette.presets.first,
        );
        _currentColorPalette = palette;
        _selectedColorIndex = ColorPalette.presets.indexOf(palette);
      } else if (_defaultColorPalette != null) {
        final palette = ColorPalette.presets.firstWhere(
          (p) => p.name == _defaultColorPalette,
          orElse: () => ColorPalette.presets.first,
        );
        _currentColorPalette = palette;
        _selectedColorIndex = ColorPalette.presets.indexOf(palette);
      }

      if (savedConversionType != null) {
        _conversionType = savedConversionType;
      } else {
        _conversionType = _defaultConversionType;
      }
    });
  }

  Future<void> _loadFavoriteFonts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteFonts = (prefs.getStringList('favoriteFonts') ?? []).toSet();
    });
  }

  Future<void> _addFontToFavorites(String fontName) async {
    setState(() {
      _favoriteFonts.add(fontName);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteFonts', _favoriteFonts.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$fontName" to favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeFontFromFavorites(String fontName) async {
    setState(() {
      _favoriteFonts.remove(fontName);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteFonts', _favoriteFonts.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$fontName" from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showGlyphViewerOverlay() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(40),
          child: _buildGlyphViewer(setDialogState),
        ),
      ),
    );
  }

  Widget _buildGlyphViewer(StateSetter setDialogState) {
    final displayFont =
        _selectedFont == 'System Default' ? null : _selectedFont;
    final filteredFonts = _getFilteredFonts();
    final currentIndex = filteredFonts.indexOf(_selectedFont);

    final allGlyphs = <String>[];

    // Basic Latin (32-126)
    for (int i = 32; i <= 126; i++) {
      allGlyphs.add(String.fromCharCode(i));
    }

    // Private Use Area (E000-F6FF)
    for (int i = 0xE000; i <= 0xF6FF; i++) {
      allGlyphs.add(String.fromCharCode(i));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.deepPurple, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: FutureBuilder<List<String>>(
        future: _filterValidGlyphs(
          allGlyphs,
          displayFont,
          knownCodePoints: _getKnownCodePoints(_selectedFont),
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final glyphs = snapshot.data!;

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: currentIndex > 0
                          ? () async {
                              await _navigateFonts(-1);
                              setDialogState(() {});
                            }
                          : null,
                      tooltip: 'Previous font',
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_forward, color: Colors.white),
                      onPressed: currentIndex < filteredFonts.length - 1
                          ? () async {
                              await _navigateFonts(1);
                              setDialogState(() {});
                            }
                          : null,
                      tooltip: 'Next font',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Font: $_selectedFont (${glyphs.length} glyphs)',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      tooltip: 'Close (ESC)',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: glyphs.length,
                  itemBuilder: (context, index) {
                    final char = glyphs[index];
                    final codePoint = char.codeUnitAt(0);

                    return Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                char,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontFamily: displayFont,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.grey[900],
                            child: Text(
                              'U+${codePoint.toRadixString(16).toUpperCase().padLeft(4, '0')}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<String>> _filterValidGlyphs(
    List<String> allGlyphs,
    String? fontFamily, {
    Set<int>? knownCodePoints,
  }) async {
    final validGlyphs = <String>[];

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Measure a clearly-missing glyph once
    textPainter.text = TextSpan(
      text: '\uFFFF',
      style: TextStyle(fontSize: 48, fontFamily: fontFamily),
    );
    textPainter.layout();
    final missingWidth = textPainter.width;

    for (final char in allGlyphs) {
      if (char.trim().isEmpty) continue;

      final codePoint = char.codeUnitAt(0);

      // Always include Basic Latin
      if (codePoint >= 32 && codePoint <= 126) {
        validGlyphs.add(char);
        continue;
      }

      if (knownCodePoints != null && knownCodePoints.contains(codePoint)) {
        validGlyphs.add(char);
        continue;
      }

      textPainter.text = TextSpan(
        text: char,
        style: TextStyle(fontSize: 48, fontFamily: fontFamily),
      );
      textPainter.layout();

      if (textPainter.width > 0 &&
          (textPainter.width - missingWidth).abs() > 2) {
        validGlyphs.add(char);
      }
    }

    return validGlyphs;
  }

  Set<int> _getKnownCodePoints(String fontName) {
    final codePoints = <int>{};

    for (final map in [
      FontAlternatesData.anyPosition,
      FontAlternatesData.notAtEnd,
      FontAlternatesData.onlyAtEnd,
    ]) {
      final fontMap = map[fontName];
      if (fontMap != null) {
        for (final value in fontMap.values) {
          codePoints.add(value.runes.first);
        }
      }
    }

    return codePoints;
  }

  Future<void> _loadFavoriteColorPalettes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteColorPalettes =
          (prefs.getStringList('favoriteColorPalettes') ?? []).toSet();
    });
  }

  Future<void> _addColorPaletteToFavorites(String paletteName) async {
    setState(() {
      _favoriteColorPalettes.add(paletteName);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'favoriteColorPalettes', _favoriteColorPalettes.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$paletteName" to favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _removeColorPaletteFromFavorites(String paletteName) async {
    setState(() {
      _favoriteColorPalettes.remove(paletteName);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'favoriteColorPalettes', _favoriteColorPalettes.toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$paletteName" from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _setCustomFontDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    CustomFontLoader.clearCustomFonts(slot: 1);

    setState(() {
      _customFontDirectory = result;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customFontDirectory', result);
    await CustomFontLoader.loadCustomFonts(result, slot: 1);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Loaded ${CustomFontLoader.customFonts.length} custom1 fonts. Restart to fully apply.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _setCustomFontDirectory2() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;

    CustomFontLoader.clearCustomFonts(slot: 2);

    setState(() {
      _customFontDirectory2 = result;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customFontDirectory2', result);
    await CustomFontLoader.loadCustomFonts(result, slot: 2);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Loaded ${CustomFontLoader.customFonts2.length} custom2 fonts. Restart to fully apply.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadCustomFontDirectory() async {
    final prefs = await SharedPreferences.getInstance();

    final savedDir = prefs.getString('customFontDirectory');
    if (savedDir != null && await Directory(savedDir).exists()) {
      _customFontDirectory = savedDir;
      await CustomFontLoader.loadCustomFonts(savedDir, slot: 1);
    }

    final savedDir2 = prefs.getString('customFontDirectory2');
    if (savedDir2 != null && await Directory(savedDir2).exists()) {
      _customFontDirectory2 = savedDir2;
      await CustomFontLoader.loadCustomFonts(savedDir2, slot: 2);
    }
  }

  Future<void> _loadCustomFonts() async {
    if (_customFontDirectory == null) return;
    try {
      final dir = Directory(_customFontDirectory!);
      final fontFiles = <String>[];
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (ext == '.ttf' || ext == '.otf') {
            fontFiles.add(entity.path);
          }
        }
      }
      for (final fontPath in fontFiles) {
        final fontName = path.basenameWithoutExtension(fontPath);
        try {
          final fontData = await File(fontPath).readAsBytes();
          final fontLoader = FontLoader(fontName);
          fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
          await fontLoader.load();
          if (!CustomFontLoader.loadedFonts.contains(fontName)) {
            CustomFontLoader.loadedFonts.add(fontName);
          }
        } catch (e) {
          print('Error loading font $fontName: $e');
        }
      }
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${fontFiles.length} custom fonts'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error loading custom fonts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load custom fonts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return {
        'totalTime': 0,
        'uniqueFiles': 0,
        'totalEntries': 0,
        'totalChapters': 0,
        'avgChapter': 0,
      };
    }
    int totalTime = 0;
    final uniqueFiles = <String>{};
    int totalChapters = 0;
    for (final entry in entries) {
      totalTime += (entry['listened_duration'] as num).toInt();
      uniqueFiles.add(entry['filename'] as String);
      totalChapters++;
    }
    final avgChapter = totalChapters > 0 ? totalTime ~/ totalChapters : 0;
    return {
      'totalTime': totalTime,
      'uniqueFiles': uniqueFiles.length,
      'totalEntries': entries.length,
      'totalChapters': totalChapters,
      'avgChapter': avgChapter,
    };
  }

  List<Map<String, dynamic>> _filterEntriesByDate(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _statsManager.statsEntries.where((entry) {
      final datetime = entry['datetime'] as String?;
      if (datetime == null) return false;
      return datetime.startsWith(dateStr);
    }).toList();
  }

  List<Map<String, dynamic>> _filterEntriesByDays(int days) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days));
    return _statsManager.statsEntries.where((entry) {
      final datetime = entry['datetime'] as String?;
      if (datetime == null) return false;
      try {
        final entryDate = DateTime.parse(datetime.split(' ')[0]);
        return entryDate.isAfter(cutoff) || entryDate.isAtSameMomentAs(cutoff);
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Map<String, int> _getFileListenTimes(List<Map<String, dynamic>> entries) {
    final fileTimes = <String, int>{};
    for (final entry in entries) {
      final filename = entry['filename'] as String;
      final duration = (entry['listened_duration'] as num).toInt();
      fileTimes[filename] = (fileTimes[filename] ?? 0) + duration;
    }
    return fileTimes;
  }

  bool _matchesSearch(String text, String query, List<String> excludeTerms,
      {bool? useAnd}) {
    final lowerText = text.toLowerCase();

    for (final excludeTerm in excludeTerms) {
      if (lowerText.contains(excludeTerm.toLowerCase())) {
        return false;
      }
    }

    if (query.isEmpty) return true;

    final terms = <String>[];
    final exactWords = <String>[];
    final exactPhrases = <String>[];

    int i = 0;
    while (i < query.length) {
      if (query[i] == '"') {
        final endQuote = query.indexOf('"', i + 1);
        if (endQuote != -1) {
          final quoted = query.substring(i + 1, endQuote);
          if (quoted.contains(' ')) {
            exactPhrases.add(quoted.toLowerCase());
          } else {
            exactWords.add(quoted.toLowerCase());
          }
          i = endQuote + 1;
        } else {
          i++;
        }
      } else if (query[i] != ' ') {
        final nextSpace = query.indexOf(' ', i);
        if (nextSpace == -1) {
          terms.add(query.substring(i).toLowerCase());
          break;
        } else {
          terms.add(query.substring(i, nextSpace).toLowerCase());
          i = nextSpace;
        }
      } else {
        i++;
      }
    }

    for (final phrase in exactPhrases) {
      if (!lowerText.contains(phrase)) {
        return false;
      }
    }

    for (final exactWord in exactWords) {
      final pattern = RegExp(r'\b' + RegExp.escape(exactWord) + r'\b',
          caseSensitive: false);
      if (!pattern.hasMatch(lowerText)) {
        return false;
      }
    }

    if (terms.isEmpty)
      return (exactWords.isNotEmpty || exactPhrases.isNotEmpty);

    final shouldUseAnd = useAnd ?? _searchUseAnd;
    if (shouldUseAnd) {
      return terms.every((term) => lowerText.contains(term));
    } else {
      return terms.any((term) => lowerText.contains(term));
    }
  }

  List<HistoryItem> _getFilteredHistory() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _history;
    }
    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _history.where((item) {
      final searchText = '${item.audiobookTitle} ${item.chapterTitle}';
      return _matchesSearch(searchText, _searchQuery, excludeList);
    }).toList();
  }

  List<String> _getFilteredPlaylist() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _playlist;
    }
    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _playlist.where((filePath) {
      final fileName = path.basename(filePath);
      return _matchesSearch(fileName, _searchQuery, excludeList);
    }).toList();
  }

  List<Bookmark> _getFilteredBookmarks() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _bookmarks;
    }
    final excludeList =
        _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _bookmarks.where((bookmark) {
      final searchText =
          '${bookmark.audiobookTitle} ${bookmark.chapterTitle} ${bookmark.note ?? ''}';
      return _matchesSearch(searchText, _searchQuery, excludeList);
    }).toList();
  }

  List<SubtitleCue> _parseVTT(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line == 'VTTSHOW') break;
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final startTime = _parseVTTTime(parts[0].trim());
          final endTime = _parseVTTTime(parts[1].trim().split(' ')[0]);
          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }
          if (startTime != null && endTime != null && textLines.isNotEmpty) {
            cues.add(SubtitleCue(
              startTime: startTime,
              endTime: endTime,
              text: textLines.join('\n'),
            ));
          }
        }
      }
    }
    _precalculateWordPositions();
    return cues;
  }

  List<SubtitleCue> _parseSRT(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final startTime = _parseSRTTime(parts[0].trim());
          final endTime = _parseSRTTime(parts[1].trim());
          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }
          if (startTime != null && endTime != null && textLines.isNotEmpty) {
            cues.add(SubtitleCue(
              startTime: startTime,
              endTime: endTime,
              text: textLines.join('\n'),
            ));
          }
        }
      }
    }
    return cues;
  }

  Duration? _parseVTTTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds);
      } else if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3))
            : 0;
        return Duration(
            minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      }
    } catch (e) {
      print('Error parsing VTT time "$timeStr": $e');
      return null;
    }
    return null;
  }

  Duration? _parseSRTTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split(',');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds =
            secondsParts.length > 1 ? int.parse(secondsParts[1]) : 0;
        return Duration(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds);
      }
    } catch (e) {
      print('Error parsing SRT time "$timeStr": $e');
      return null;
    }
    return null;
  }

  void _checkPauseTrigger() {
    if (_pauseMode == PauseMode.disabled || _nextPauseTime == null) return;

    if (_currentPosition >= _nextPauseTime!) {
      _nextPauseTime = null;
      player.pause();

      Duration pauseDuration;
      switch (_pauseMode) {
        case PauseMode.pause2s:
          pauseDuration = const Duration(seconds: 2);
          break;
        case PauseMode.pause3s:
          pauseDuration = const Duration(seconds: 3);
          break;
        case PauseMode.pause5s:
          pauseDuration = const Duration(seconds: 5);
          break;
        case PauseMode.pause10s:
          pauseDuration = const Duration(seconds: 10);
          break;
        case PauseMode.dictionary:
          pauseDuration = const Duration(seconds: 9999);
          break;
        case PauseMode.disabled:
          return;
      }

      _pauseModeTimer = Timer(pauseDuration, () {
        player.play();
      });
    }
  }

  void _updateCurrentSubtitle() {
    if (_subtitles.isEmpty) {
      if (_currentSubtitleText.isNotEmpty) {
        setState(() {
          _currentSubtitleText = '';
          _currentSubtitleIndex = null;
        });
      }
    } else {
      int? activeIndex;
      for (int i = 0; i < _subtitles.length; i++) {
        final cue = _subtitles[i];
        if (_currentPosition >= cue.startTime) {
          activeIndex = i;
        } else {
          break;
        }
      }

      if (activeIndex != null) {
        final cue = _subtitles[activeIndex];
        if (_currentSubtitleIndex != activeIndex) {
          final oldText = _currentSubtitleText;
          setState(() {
            _currentSubtitleText = cue.text;
            _currentSubtitleIndex = activeIndex;
          });

          if (_vttShowActive && activeIndex != null) {
            final cue = _subtitles[activeIndex];
            final key =
                '${_formatVttTime(cue.startTime)} --> ${_formatVttTime(cue.endTime)}';
            _applyVttShowStyle(key);
            setState(() {
              _vttShowRevealedLines = 1;
            });
          }

          if (_fontCycleActive) {
            _fontCycleCueCounter++;

            if (_fontCycleInterval > 1 &&
                _fontCycleCueCounter == _fontCycleInterval - 1) {
              unawaited(_preloadNextCycleFont());
            }

            if (_fontCycleCueCounter >= _fontCycleInterval) {
              _fontCycleCueCounter = 0;
              _navigateFonts(1, fromCycle: true);
            }
          }

          if (_colorCycleActive) {
            _colorCycleCueCounter++;
            if (_colorCycleCueCounter >= _colorCycleInterval) {
              _colorCycleCueCounter = 0;
              _navigateColors(1, fromCycle: true);
            }
          }

          if (_showWordOverlay && oldText.isNotEmpty) {
            setState(() {
              _showWordOverlay = false;
            });
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) {
                setState(() {
                  _showWordOverlay = true;
                });
              }
            });
          }

          if (_pauseMode != PauseMode.disabled) {
            _nextPauseTime = cue.endTime - const Duration(milliseconds: 200);
          }
        }
      } else {
        if (_currentSubtitleText.isNotEmpty) {
          setState(() {
            _currentSubtitleText = '';
            _currentSubtitleIndex = null;
          });
        }
      }
    }

    if (_secondarySubtitles.isEmpty) {
      if (_secondarySubtitleText.isNotEmpty) {
        setState(() {
          _secondarySubtitleText = '';
          _currentSecondarySubtitleIndex = null;
        });
      }
    } else {
      int? activeIndex;
      for (int i = 0; i < _secondarySubtitles.length; i++) {
        final cue = _secondarySubtitles[i];
        if (_currentPosition >= cue.startTime) {
          activeIndex = i;
        } else {
          break;
        }
      }

      if (activeIndex != null &&
          _currentSecondarySubtitleIndex != activeIndex) {
        final text = _secondarySubtitles[activeIndex!].text;
        setState(() {
          _secondarySubtitleText = text;
          _currentSecondarySubtitleIndex = activeIndex;
        });
      } else if (activeIndex == null && _secondarySubtitleText.isNotEmpty) {
        setState(() {
          _secondarySubtitleText = '';
          _currentSecondarySubtitleIndex = null;
        });
      }
    }
  }

  Future<void> _loadSecondarySubtitle() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }
    final audiobookPath = _currentAudiobook!.path;
    final audiobookDir = path.dirname(audiobookPath);
    final audiobookBase = path.basenameWithoutExtension(audiobookPath);
    final vttDir = path.join(audiobookDir, '${audiobookBase}_vtt');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      dialogTitle: 'Select Secondary Subtitle File',
      initialDirectory: vttDir,
    );

    if (result == null || result.files.isEmpty) return;

    final subtitlePath = result.files.first.path!;

    try {
      setState(() {
        _secondarySubtitleFilePath = subtitlePath;
        if (_secondarySubtitleFont == 'System Default' &&
            _selectedFont != 'System Default') {
          _secondarySubtitleFont = _selectedFont;
        }
        if (_secondaryColorPalette == null && _currentColorPalette != null) {
          _secondaryColorPalette = _currentColorPalette;
        }
        if (_secondarySubtitleFontSize == 86.0) {
          _secondarySubtitleFontSize = _subtitleFontSize;
        }
      });

      await SubtitlePreferences.saveLastUsedSecondaryVttPath(
          audiobookPath, subtitlePath);

      await _applySecondaryConversion();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Loaded ${_secondarySubtitles.length} secondary subtitle cues'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error loading secondary subtitles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load secondary subtitles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applySecondaryConversion() async {
    if (_secondarySubtitleFilePath == null) return;

    try {
      final content = await File(_secondarySubtitleFilePath!).readAsString();
      _secondaryOriginalSubtitles = _parseVTT(content);

      String convertedContent = content;

      switch (_secondaryConversionType) {
        case 'demo':
          convertedContent = await SubtitleTransformer.convertToDemoInMemory(
              content, _secondarySubtitleFont);
          break;
        case 'demoUpper':
          convertedContent =
              await SubtitleTransformer.convertToDemoUpperInMemory(
                  content, _secondarySubtitleFont);
          break;
        case 'alternates':
          convertedContent =
              await SubtitleTransformer.convertToAlternatesInMemory(
                  content, _secondarySubtitleFont);
          break;
        case 'missing':
          convertedContent =
              await SubtitleTransformer.fixMissingLigaturesInMemory(
                  content, _secondarySubtitleFont);
          break;
        case 'uppercase':
          convertedContent =
              SubtitleTransformer.convertToUppercaseInMemory(content);
          break;
        case 'seesawcase':
          convertedContent =
              SubtitleTransformer.convertToSeesawCaseInMemory(content);
          break;
        case 'none':
        default:
          convertedContent = content;
          break;
      }

      final subtitles = _parseVTT(convertedContent);
      setState(() {
        _secondarySubtitles = subtitles;
      });

      _updateCurrentSubtitle();
    } catch (e) {
      print('Error applying secondary conversion: $e');
    }
  }

  Future<void> _preloadNextCycleFont() async {
    _pendingCycleReady = false;
    final filteredFonts = _getFilteredFonts();
    if (filteredFonts.isEmpty) return;

    final nextIndex = (_selectedFontIndex + 1) % filteredFonts.length;
    final nextFont = filteredFonts[nextIndex];

    await CustomFontLoader.loadFonts();

    String? conversionType;
    if (_autoConvertAlternates && FontAlternatesData.hasFontAlternates(nextFont)) {
      conversionType = 'alternates';
    } else if (_autoConvertMissing) {
      final metadata = FontDatabase.getMetadata(nextFont);
      if (metadata != null && metadata.hasMissingLigatures()) {
        conversionType = 'missing';
      }
    }

    _pendingCycleFont = nextFont;
    _pendingCycleConversionType = conversionType;
    _pendingCycleReady = true;
  }

  double _calculateDynamicFontSize(String text, double baseFontSize) {
    final textLength = _getEffectiveTextLength(text);
    double multiplier = 1.0;

    if (textLength >= 1 && textLength <= 60) {
      final effectiveLength = textLength < 10 ? 10 : textLength;
      multiplier = 1.0 + ((60 - effectiveLength) / 100.0);
    } else if (textLength > 60) {
      final stepsOver60 = (textLength - 60) / 30.0;
      multiplier = (1.0 - stepsOver60 * 0.04).clamp(0.58, 1.0);
    }

    final finalSize =
        (baseFontSize * multiplier).clamp(16.0, baseFontSize * 1.6);

    if (text != _lastDebuggedSubtitle) {
      // print('Font Adjust: len=$textLength, base=$baseFontSize, ×${multiplier.toStringAsFixed(3)} = ${finalSize.toStringAsFixed(1)}');
      // _lastDebuggedSubtitle = text;
    }
    return finalSize;
  }

  int _getEffectiveTextLength(String text) {
    final cleanedText = text.replaceAll(RegExp(r'<[^>]+>'), '');
    int length = 0;

    for (int i = 0; i < cleanedText.length; i++) {
      final char = cleanedText.codeUnitAt(i);
      // CJK characters (double-byte) count as 2
      if ((char >= 0x4E00 && char <= 0x9FFF) || // CJK Unified Ideographs
          (char >= 0x3040 && char <= 0x309F) || // Hiragana
          (char >= 0x30A0 && char <= 0x30FF) || // Katakana
          (char >= 0xAC00 && char <= 0xD7AF)) {
        // Hangul
        length += 2;
      } else {
        length += 1;
      }
    }

    return length;
  }

  TextSpan _buildColoredTextSpan(
    String text, {
    double? fontSize,
    String? fontFamily,
    ColorPalette? palette,
    double? lineSpacing,
    bool isStroke = false,
    bool useShadowColor = false,
    bool useBlurShadow = false,
    FontColorOverride? fontColorOverrideParam,
  }) {
    final effectiveFontColorOverride =
        fontColorOverrideParam ?? _fontColorOverride;
    final baseFontSize = fontSize ?? _subtitleFontSize;
    final effectiveFont = fontFamily ??
        (_selectedFont == 'System Default' ? null : _selectedFont);
    final effectivePalette = palette ?? _currentColorPalette;
    final effectiveLineSpacing = lineSpacing ?? _subtitleLineSpacing;
    final cleanedText = text.replaceAll(RegExp(r'<[^>]+>'), '');
    final effectiveFontSize =
        _calculateDynamicFontSize(cleanedText, baseFontSize);

    final fontFamilyFallback = effectiveFont != null
        ? [effectiveFont, 'Scheherazade New']
        : ['Scheherazade New'];

    if (effectivePalette == null) {
      Paint? foreground;
      Color? color;

      if (isStroke) {
        foreground = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _universalStrokeWidth
          ..color = useShadowColor ? Colors.black87 : Colors.white70;
        color = null;
      } else {
        color = useShadowColor ? Colors.black : Colors.black;
        foreground = null;
      }

      return TextSpan(
        text: cleanedText,
        style: TextStyle(
          color: color,
          foreground: foreground,
          fontSize: effectiveFontSize,
          height: effectiveLineSpacing,
          fontFamily: effectiveFont,
          fontFamilyFallback: fontFamilyFallback,
          shadows: (!isStroke && !useShadowColor && useBlurShadow)
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: Offset.zero,
                  ),
                ]
              : [],
        ),
      );
    }

    if (effectivePalette.isSimplePreset) {
      Paint? foreground;
      Color? color;

      if (isStroke) {
        foreground = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _universalStrokeWidth
          ..color = useShadowColor
              ? _parseColor(effectivePalette.effectiveShadowColor(0))
              : _getDarkenedStrokeColor(
                  effectivePalette.colors[0], effectivePalette);
        color = null;
      } else {
        final fontColor = _parseColor(effectivePalette.colors[0]);
        final baseColor = useShadowColor
            ? _parseColor(effectivePalette.effectiveShadowColor(0))
            : fontColor;

        color = !useShadowColor &&
                effectiveFontColorOverride != FontColorOverride.none
            ? (effectiveFontColorOverride == FontColorOverride.black
                ? Colors.black87
                : Colors.white70)
            : baseColor;
        foreground = null;
      }

      return TextSpan(
        text: cleanedText,
        style: TextStyle(
          color: color,
          foreground: foreground,
          fontSize: effectiveFontSize,
          height: effectiveLineSpacing,
          fontFamily: effectiveFont,
          fontFamilyFallback: fontFamilyFallback,
          shadows: (!isStroke && !useShadowColor && useBlurShadow)
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: Offset.zero,
                  ),
                ]
              : [],
        ),
      );
    }

    final startWordIndex = _calculateWordIndexAtPosition(_currentPosition);

    if (_coloringMode == ColoringMode.letters) {
      return _buildLetterColoredTextSpan(
        cleanedText,
        startWordIndex,
        effectiveFontSize,
        effectiveFont,
        effectivePalette,
        fontFamilyFallback,
        effectiveLineSpacing,
        isStroke,
        useShadowColor,
        useBlurShadow,
        effectiveFontColorOverride,
      );
    }

    if (_hasMixedLanguages(cleanedText)) {
      return _buildMixedLanguageTextSpan(
        cleanedText,
        startWordIndex,
        effectiveFontSize,
        effectiveFont,
        effectivePalette,
        fontFamilyFallback,
        effectiveLineSpacing,
        isStroke,
        useShadowColor,
        useBlurShadow,
        effectiveFontColorOverride,
      );
    }

    final language = CJKTokenizer.detectLanguage(cleanedText);
    if (language == TextLanguage.japanese ||
        language == TextLanguage.chinese ||
        language == TextLanguage.korean) {
      return _buildCJKColoredTextSpan(
        cleanedText,
        startWordIndex,
        effectiveFontSize,
        effectiveFont,
        effectivePalette,
        effectiveLineSpacing,
        isStroke,
        useShadowColor,
        useBlurShadow,
        effectiveFontColorOverride,
      );
    }

    final pattern = RegExp(r'(\S+)(\s*)');
    final matches = pattern.allMatches(text);
    final spans = <TextSpan>[];
    int wordIndex = startWordIndex;

    for (final match in matches) {
      final word = match.group(1)!;
      final space = match.group(2) ?? '';

      final colorIndex = wordIndex % effectivePalette.colors.length;
      final fillColorHex = effectivePalette.colors[colorIndex];
      final color = _adjustColorIfBright(fillColorHex);
      wordIndex++;

      Paint? foreground;
      Color? textColor;

      if (isStroke) {
        foreground = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _universalStrokeWidth
          ..color = useShadowColor
              ? _parseColor(effectivePalette.effectiveShadowColor(colorIndex))
              : _getDarkenedStrokeColor(fillColorHex, effectivePalette);
        textColor = null;
      } else {
        final baseColor = useShadowColor
            ? _parseColor(effectivePalette.effectiveShadowColor(colorIndex))
            : color;

        textColor = !useShadowColor &&
                effectiveFontColorOverride != FontColorOverride.none
            ? (effectiveFontColorOverride == FontColorOverride.black
                ? Colors.black87
                : Colors.white70)
            : baseColor;
        foreground = null;
      }

      spans.add(TextSpan(
        text: word,
        style: TextStyle(
          color: textColor,
          foreground: foreground,
          fontSize: effectiveFontSize,
          height: effectiveLineSpacing,
          fontFamily: effectiveFont,
          fontFamilyFallback: fontFamilyFallback,
          shadows: (!isStroke && !useShadowColor && useBlurShadow)
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: Offset.zero,
                  ),
                ]
              : [],
        ),
      ));

      if (space.isNotEmpty) {
        spans.add(TextSpan(
          text: space,
          style: TextStyle(
            color: Colors.black26,
            fontSize: effectiveFontSize,
            height: effectiveLineSpacing,
            fontFamily: effectiveFont,
            fontFamilyFallback: fontFamilyFallback,
          ),
        ));
      }
    }
    return TextSpan(children: spans);
  }

  bool _hasMixedLanguages(String text) {
    bool hasCJK = false;
    bool hasLatin = false;

    for (final char in text.characters) {
      final code = char.runes.first;

      if ((code >= 0x3040 && code <= 0x309F) || // Hiragana
          (code >= 0x30A0 && code <= 0x30FF) || // Katakana
          (code >= 0x4E00 && code <= 0x9FFF) || // CJK Unified Ideographs
          (code >= 0xAC00 && code <= 0xD7AF)) {
        // Hangul
        hasCJK = true;
      } else if ((code >= 0x0041 && code <= 0x005A) || // A-Z
          (code >= 0x0061 && code <= 0x007A)) {
        // a-z
        hasLatin = true;
      }

      if (hasCJK && hasLatin) return true;
    }

    return false;
  }

  TextSpan _buildMixedLanguageTextSpan(
    String text,
    int startWordIndex,
    double fontSize,
    String? fontFamily,
    ColorPalette palette,
    List<String> fontFamilyFallback,
    double lineSpacing,
    bool isStroke,
    bool useShadowColor,
    bool useBlurShadow,
    FontColorOverride fontColorOverride,
  ) {
    const double strokeWidth = _universalStrokeWidth;

    final spans = <TextSpan>[];
    int wordIndex = startWordIndex;

    final segments = <Map<String, dynamic>>[];
    StringBuffer currentSegment = StringBuffer();
    TextLanguage? currentLang;

    for (final char in text.characters) {
      final charLang = CJKTokenizer.detectLanguage(char);

      if (currentLang == null) {
        currentLang = charLang;
        currentSegment.write(char);
      } else if (currentLang == charLang ||
          char == ' ' ||
          charLang == TextLanguage.unknown) {
        currentSegment.write(char);
      } else {
        if (currentSegment.isNotEmpty) {
          segments.add({
            'text': currentSegment.toString(),
            'language': currentLang,
          });
          currentSegment.clear();
        }
        currentLang = charLang;
        currentSegment.write(char);
      }
    }

    if (currentSegment.isNotEmpty) {
      segments.add({
        'text': currentSegment.toString(),
        'language': currentLang,
      });
    }

    for (final segment in segments) {
      final segmentText = segment['text'] as String;
      final segmentLang = segment['language'] as TextLanguage;

      if (segmentLang == TextLanguage.japanese ||
          segmentLang == TextLanguage.chinese ||
          segmentLang == TextLanguage.korean) {
        final words = CJKTokenizer.tokenize(segmentText, language: segmentLang);
        for (final word in words) {
          final colorIndex = wordIndex % palette.colors.length;
          final color = _adjustColorIfBright(palette.colors[colorIndex]);

          Paint? foreground;
          Color? textColor;

          if (isStroke) {
            foreground = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = useShadowColor
                  ? _parseColor(palette.effectiveShadowColor(colorIndex))
                  : _getDarkenedStrokeColor(
                      palette.colors[colorIndex % palette.colors.length],
                      palette);
            textColor = null;
          } else {
            final baseColor = useShadowColor
                ? _parseColor(palette.effectiveShadowColor(colorIndex))
                : color;

            textColor =
                !useShadowColor && fontColorOverride != FontColorOverride.none
                    ? (fontColorOverride == FontColorOverride.black
                        ? Colors.black87
                        : Colors.white70)
                    : baseColor;
            foreground = null;
          }

          spans.add(TextSpan(
            text: word,
            style: TextStyle(
              color: textColor,
              foreground: foreground,
              fontSize: fontSize,
              height: lineSpacing,
              fontFamily: fontFamily,
              fontFamilyFallback: fontFamilyFallback,
              shadows: (!isStroke && !useShadowColor && useBlurShadow)
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: Offset.zero,
                      ),
                    ]
                  : [],
            ),
          ));
          wordIndex++;
        }
      } else {
        final pattern = RegExp(r'(\S+)(\s*)');
        final matches = pattern.allMatches(segmentText);

        for (final match in matches) {
          final word = match.group(1)!;
          final space = match.group(2) ?? '';

          final colorIndex = wordIndex % palette.colors.length;
          final color = _adjustColorIfBright(palette.colors[colorIndex]);
          wordIndex++;

          Paint? foreground;
          Color? textColor;

          if (isStroke) {
            foreground = Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = useShadowColor
                  ? _parseColor(palette.effectiveShadowColor(colorIndex))
                  : _getDarkenedStrokeColor(
                      palette.colors[colorIndex % palette.colors.length],
                      palette);
            textColor = null;
          } else {
            final baseColor = useShadowColor
                ? _parseColor(palette.effectiveShadowColor(colorIndex))
                : color;

            textColor =
                !useShadowColor && fontColorOverride != FontColorOverride.none
                    ? (fontColorOverride == FontColorOverride.black
                        ? Colors.black87
                        : Colors.white70)
                    : baseColor;
            foreground = null;
          }

          spans.add(TextSpan(
            text: word,
            style: TextStyle(
              color: textColor,
              foreground: foreground,
              fontSize: fontSize,
              height: lineSpacing,
              fontFamily: fontFamily,
              fontFamilyFallback: fontFamilyFallback,
              shadows: (!isStroke && !useShadowColor && useBlurShadow)
                  ? [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: Offset.zero,
                      ),
                    ]
                  : [],
            ),
          ));

          if (space.isNotEmpty) {
            spans.add(TextSpan(
              text: space,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                height: lineSpacing,
                fontFamily: fontFamily,
                fontFamilyFallback: fontFamilyFallback,
              ),
            ));
          }
        }
      }
    }

    return TextSpan(children: spans);
  }

  TextSpan _buildLetterColoredTextSpan(
    String text,
    int startIndex,
    double fontSize,
    String? fontFamily,
    ColorPalette palette,
    List<String> fontFamilyFallback,
    double lineSpacing,
    bool isStroke,
    bool useShadowColor,
    bool useBlurShadow,
    FontColorOverride fontColorOverride,
  ) {
    const double strokeWidth = _universalStrokeWidth;

    final spans = <TextSpan>[];
    int colorIndex = startIndex;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (char == ' ' || char == '\n' || char == '\t') {
        spans.add(TextSpan(
          text: char,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            height: lineSpacing,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
          ),
        ));
        continue;
      }

      final currentColorIndex = colorIndex % palette.colors.length;
      final color = _adjustColorIfBright(palette.colors[currentColorIndex]);
      colorIndex++;

      Paint? foreground;
      Color? textColor;

      if (isStroke) {
        foreground = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = useShadowColor
              ? _parseColor(palette.effectiveShadowColor(currentColorIndex))
              : _getDarkenedStrokeColor(
                  palette.colors[currentColorIndex], palette);
        textColor = null;
      } else {
        textColor = useShadowColor
            ? _parseColor(palette.effectiveShadowColor(currentColorIndex))
            : color;

        if (!useShadowColor && fontColorOverride != FontColorOverride.none) {
          textColor = fontColorOverride == FontColorOverride.black
              ? Colors.black87
              : Colors.white70;
        }
        foreground = null;
      }

      spans.add(TextSpan(
        text: char,
        style: TextStyle(
          color: textColor,
          foreground: foreground,
          fontSize: fontSize,
          height: lineSpacing,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          shadows: (!isStroke && !useShadowColor && useBlurShadow)
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: Offset.zero,
                  ),
                ]
              : [],
        ),
      ));
    }

    return TextSpan(children: spans);
  }

  TextSpan _buildCJKColoredTextSpan(
    String text,
    int startWordIndex,
    double fontSize,
    String? fontFamily,
    ColorPalette palette,
    double lineSpacing,
    bool isStroke,
    bool useShadowColor,
    bool useBlurShadow,
    FontColorOverride fontColorOverride,
  ) {
    const double strokeWidth = _universalStrokeWidth;

    final fontFamilyFallback = fontFamily != null
        ? [fontFamily, 'Scheherazade New']
        : ['Scheherazade New'];

    final words = CJKTokenizer.tokenize(text);
    final spans = <TextSpan>[];
    int wordIndex = startWordIndex;

    for (final word in words) {
      final colorIndex = wordIndex % palette.colors.length;
      final color = _adjustColorIfBright(palette.colors[colorIndex]);

      Paint? foreground;
      Color? textColor;

      if (isStroke) {
        foreground = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = useShadowColor
              ? _parseColor(palette.effectiveShadowColor(colorIndex))
              : _getDarkenedStrokeColor(
                  palette.colors[colorIndex % palette.colors.length], palette);
        textColor = null;
      } else {
        final baseColor = useShadowColor
            ? _parseColor(palette.effectiveShadowColor(colorIndex))
            : color;

        textColor =
            !useShadowColor && fontColorOverride != FontColorOverride.none
                ? (fontColorOverride == FontColorOverride.black
                    ? Colors.black87
                    : Colors.white70)
                : baseColor;
        foreground = null;
      }

      spans.add(TextSpan(
        text: word,
        style: TextStyle(
          color: textColor,
          foreground: foreground,
          fontSize: fontSize,
          height: lineSpacing,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          shadows: (!isStroke && !useShadowColor && useBlurShadow)
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    blurRadius: 8,
                    offset: const Offset(2, 2),
                  ),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: Offset.zero,
                  ),
                ]
              : [],
        ),
      ));
      wordIndex++;
    }

    return TextSpan(children: spans);
  }

  void _precalculateWordPositions() {
    _cueWordStarts.clear();
    int wordCount = 0;
    for (final cue in _subtitles) {
      _cueWordStarts.add(wordCount);
      final cleanedText = cue.text.replaceAll(RegExp(r'<[^>]+>'), '');
      final language = CJKTokenizer.detectLanguage(cleanedText);
      if (language == TextLanguage.japanese ||
          language == TextLanguage.chinese ||
          language == TextLanguage.korean) {
        final words = CJKTokenizer.tokenize(cleanedText);
        wordCount += words.length;
      } else {
        final words = cleanedText.split(RegExp(r'\s+'));
        wordCount += words.where((w) => w.isNotEmpty).length;
      }
    }
  }

  Color _getDarkenedStrokeColor(String fillColor, ColorPalette palette) {
    if (palette.strokeColor != null) {
      return _parseColor(palette.strokeColor!);
    }
    final color = fillColor.replaceAll('#', '');
    final r = int.parse(color.substring(0, 2), radix: 16);
    final g = int.parse(color.substring(2, 4), radix: 16);
    final b = int.parse(color.substring(4, 6), radix: 16);
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    final factor = luminance > 0.6
        ? 0.65
        : luminance > 0.4
            ? 0.5
            : 0.3;
    final newR = (r * (1 - factor)).clamp(0, 255).round();
    final newG = (g * (1 - factor)).clamp(0, 255).round();
    final newB = (b * (1 - factor)).clamp(0, 255).round();
    return Color.fromARGB(255, newR, newG, newB);
  }

  int _calculateWordIndexAtPosition(Duration position) {
    if (_subtitles.isEmpty ||
        _currentColorPalette == null ||
        _cueWordStarts.isEmpty) {
      return 0;
    }
    int left = 0;
    int right = _subtitles.length - 1;
    while (left <= right) {
      int mid = (left + right) ~/ 2;
      final cue = _subtitles[mid];
      if (position >= cue.startTime && position < cue.endTime) {
        if (mid >= _cueWordStarts.length) {
          return 0;
        }
        return _cueWordStarts[mid];
      } else if (position < cue.startTime) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    if (right >= 0 && right < _cueWordStarts.length) {
      return _cueWordStarts[right];
    }
    return 0;
  }

  Future<void> _loadChapterIndex() async {
    if (_activePlaylistIndex == null ||
        _activePlaylistIndex! >= _playlistDirectories.length) {
      return;
    }
    final playlistDir = _playlistDirectories[_activePlaylistIndex!];
    final prefs = await SharedPreferences.getInstance();
    final indexKey = 'chapterIndex_$playlistDir';
    final indexJson = prefs.getString(indexKey);
    if (indexJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(indexJson);
        final loadedIndex = <String, List<Chapter>>{};
        decoded.forEach((audioPath, chaptersData) {
          final chaptersList = (chaptersData as List).map((chapterJson) {
            return Chapter(
              index: chapterJson['index'],
              title: chapterJson['title'],
              startTime: Duration(milliseconds: chapterJson['startTime']),
              endTime: Duration(milliseconds: chapterJson['endTime']),
              duration: Duration(milliseconds: chapterJson['duration']),
            );
          }).toList();
          loadedIndex[audioPath] = chaptersList;
        });
        setState(() {
          _playlistChapterIndex = loadedIndex;
        });
      } catch (e) {
        print('Error loading chapter index: $e');
      }
    }
  }

  Future<void> _saveChapterIndex() async {
    if (_activePlaylistIndex == null ||
        _activePlaylistIndex! >= _playlistDirectories.length) {
      return;
    }
    final playlistDir = _playlistDirectories[_activePlaylistIndex!];
    final prefs = await SharedPreferences.getInstance();
    final indexKey = 'chapterIndex_$playlistDir';
    final indexData = <String, dynamic>{};
    _playlistChapterIndex.forEach((audioPath, chapters) {
      indexData[audioPath] = chapters
          .map((chapter) => {
                'index': chapter.index,
                'title': chapter.title,
                'startTime': chapter.startTime.inMilliseconds,
                'endTime': chapter.endTime.inMilliseconds,
                'duration': chapter.duration.inMilliseconds,
              })
          .toList();
    });
    await prefs.setString(indexKey, jsonEncode(indexData));
  }

  Future<void> _indexPlaylistChapters() async {
    if (_playlist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No playlist loaded')),
      );
      return;
    }
    setState(() {
      _isIndexingChapters = true;
      _indexingStatus = 'Starting chapter indexing...';
      _indexedFiles = 0;
      _totalFilesToIndex = _playlist.length;
    });
    final startTime = DateTime.now();
    int newFiles = 0;
    int skippedFiles = 0;
    for (int i = 0; i < _playlist.length; i++) {
      final audioPath = _playlist[i];
      if (_playlistChapterIndex.containsKey(audioPath)) {
        setState(() {
          _indexedFiles = i + 1;
          _indexingStatus =
              'Skipping ${path.basename(audioPath)} (already indexed)';
        });
        skippedFiles++;
        await Future.delayed(const Duration(milliseconds: 10));
        continue;
      }
      setState(() {
        _indexedFiles = i + 1;
        _indexingStatus =
            'Indexing ${path.basename(audioPath)} ($i/${_playlist.length})';
      });
      try {
        final metadata = await _ffmpeg.loadAudiobook(audioPath);
        setState(() {
          _playlistChapterIndex[audioPath] = metadata.chapters;
        });
        newFiles++;
        if (newFiles % 10 == 0) {
          await _saveChapterIndex();
        }
      } catch (e) {
        print('Error indexing $audioPath: $e');
      }
    }
    await _saveChapterIndex();
    final elapsed = DateTime.now().difference(startTime);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60);
    setState(() {
      _isIndexingChapters = false;
      _indexingStatus = '';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chapter indexing complete!\n'
              'Total: ${_playlist.length} audiobooks\n'
              'New: $newFiles, Skipped: $skippedFiles\n'
              'Time: ${minutes}m ${seconds}s'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _searchPlaylistChapters(String query) {
    if (query.isEmpty) {
      setState(() {
        _chapterSearchQuery = '';
        _chapterSearchResults = [];
      });
      return;
    }
    final results = <ChapterSearchResult>[];
    final excludeList =
        _chapterExcludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    _playlistChapterIndex.forEach((audioPath, chapters) {
      final audioTitle = path.basenameWithoutExtension(audioPath);
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        if (_matchesSearch(chapter.title, query, excludeList,
            useAnd: _chapterSearchUseAnd)) {
          results.add(ChapterSearchResult(
            audiobookPath: audioPath,
            audiobookTitle: audioTitle,
            chapterIndex: i,
            chapterTitle: chapter.title,
            startTime: chapter.startTime,
          ));
        }
      }
    });
    setState(() {
      _chapterSearchQuery = query;
      _chapterSearchResults = results;
    });
  }

  Future<void> _jumpToChapterResult(ChapterSearchResult result) async {
    if (_currentAudiobook?.path != result.audiobookPath) {
      setState(() {
        _frequencyItems = [];
        _isAnalyzingFrequencies = false;
      });
      await _openAudiobook(result.audiobookPath);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await _seekTo(result.startTime + const Duration(milliseconds: 200));
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> _seekTo(Duration position) async {
    await player.seek(position);
    if (_currentAudiobook != null) {
      for (var i = 0; i < _currentAudiobook!.chapters.length; i++) {
        final chapter = _currentAudiobook!.chapters[i];
        if (position >= chapter.startTime && position < chapter.endTime) {
          setState(() {
            _currentChapterIndex = i;
          });
          break;
        }
      }
    }
    _updateCurrentSubtitle();
  }

  Future<void> _previousChapter() async {
    if (_currentAudiobook == null) return;

    final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
    final timeIntoChapter = _currentPosition - currentChapter.startTime;

    if (timeIntoChapter.inSeconds > 10) {
      await _seekTo(currentChapter.startTime);
      return;
    }

    if (_currentChapterIndex > 0) {
      await _statsManager.recordChapterEnd(
        path.basenameWithoutExtension(_currentAudiobook!.path),
        currentChapter.title,
        false,
      );
      await _statsManager.flushCacheToLog();

      final chapter = _currentAudiobook!.chapters[_currentChapterIndex - 1];
      await _seekTo(chapter.startTime);
      _statsManager.recordChapterStart();
      if (_isPlaying) {
        _statsManager.onPlaybackStart();
      }
    }
  }

  Future<void> _nextChapter({bool fromBoundary = false}) async {
    if (_currentAudiobook == null) return;
    if (!fromBoundary) {
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      await _statsManager.recordChapterEnd(
        path.basenameWithoutExtension(_currentAudiobook!.path),
        currentChapter.title,
        false,
      );
      await _statsManager.flushCacheToLog();
    }
    if (_shuffleEnabled) {
      final nextIndex = _getNextShuffleChapter();
      final chapter = _currentAudiobook!.chapters[nextIndex];
      await _seekTo(chapter.startTime + const Duration(milliseconds: 100));
    } else {
      int nextIndex = _currentChapterIndex + 1;
      while (nextIndex < _currentAudiobook!.chapters.length) {
        final nextChapter = _currentAudiobook!.chapters[nextIndex];
        if (!_shouldSkipChapter(nextChapter.title)) {
          await _seekTo(nextChapter.startTime);
          break;
        }
        nextIndex++;
      }
    }
    _statsManager.recordChapterStart();
    if (_isPlaying) {
      _statsManager.onPlaybackStart();
    }
  }

  Future<void> _jumpToChapter(int index) async {
    if (_currentAudiobook != null &&
        index >= 0 &&
        index < _currentAudiobook!.chapters.length) {
      if (_currentChapterIndex != index) {
        final currentChapter =
            _currentAudiobook!.chapters[_currentChapterIndex];
        await _statsManager.recordChapterEnd(
          path.basenameWithoutExtension(_currentAudiobook!.path),
          currentChapter.title,
          false,
        );
        _statsManager.flushCacheToLog();
      }
      final chapter = _currentAudiobook!.chapters[index];
      await _seekTo(chapter.startTime);
      setState(() {
        _currentChapterIndex = index;
      });
      _statsManager.recordChapterStart();
      if (_isPlaying) {
        _statsManager.onPlaybackStart();
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDurationWithMs(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final ms = d.inMilliseconds.remainder(1000);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';
  }

  Future<void> _skipForward() async {
    final newPosition = _currentPosition + const Duration(seconds: 10);
    final clampedPosition = Duration(
        milliseconds:
            newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));
    await _seekTo(clampedPosition);
  }

  Future<void> _skipBackward() async {
    final newPosition = _currentPosition - const Duration(seconds: 10);
    final clampedPosition = Duration(
        milliseconds:
            newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));
    await _seekTo(clampedPosition);
  }

  Future<void> _skipBackward1() async {
    final newPosition = _currentPosition - const Duration(seconds: 1);
    final clampedPosition = Duration(
        milliseconds:
            newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));

    await _seekTo(clampedPosition);

    final replayStart = clampedPosition - const Duration(milliseconds: 900);
    final safeReplayStart =
        replayStart < Duration.zero ? Duration.zero : replayStart;

    await player.seek(safeReplayStart);
    await player.play();

    Timer(const Duration(milliseconds: 900), () async {
      await player.pause();
      await player.seek(clampedPosition);
    });
  }

  Future<void> _skipForward1() async {
    final newPosition = _currentPosition + const Duration(seconds: 1);
    final clampedPosition = Duration(
        milliseconds:
            newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));

    final replayStart = clampedPosition - const Duration(milliseconds: 900);
    final safeReplayStart =
        replayStart < Duration.zero ? Duration.zero : replayStart;

    await player.seek(safeReplayStart);
    await player.play();

    Timer(const Duration(milliseconds: 900), () async {
      await player.pause();
      await player.seek(clampedPosition);
    });
  }

  Future<void> _skipForward3() async {
    final newPosition = _currentPosition + const Duration(seconds: 3);
    final clampedPosition = Duration(
        milliseconds:
            newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));
    await _seekTo(clampedPosition);
  }

  Future<void> _skipBackward3() async {
    final newPosition = _currentPosition - const Duration(seconds: 3);
    final clampedPosition = Duration(
        milliseconds:
            newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds));
    await _seekTo(clampedPosition);
  }

  Future<void> _replaySegmentBack() async {
    final currentTime = _currentPosition;
    final startTime = currentTime - const Duration(milliseconds: 900);

    await player.seek(startTime < Duration.zero ? Duration.zero : startTime);
    await player.play();

    Timer(const Duration(milliseconds: 800), () async {
      await player.pause();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Replaying segment (back 100ms)'),
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  Future<void> _replaySegmentForward() async {
    final currentTime = _currentPosition;

    final startTime = currentTime - const Duration(milliseconds: 900);
    final safeStartTime = startTime < Duration.zero ? Duration.zero : startTime;

    await player.seek(safeStartTime);
    await player.play();

    Timer(const Duration(milliseconds: 900), () async {
      await player.pause();
      await player.seek(currentTime);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Replaying segment (before position)'),
          duration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  void _setInPointToLastOutPoint() {
    if (_lastOutPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No previous out point recorded'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() {
      _inPoint = _lastOutPoint;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'In point set to last out point: ${_formatDurationWithMs(_inPoint!)}'),
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _setInPoint() {
    if (_isCutting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cut in progress — wait until complete before setting new In point'),
          duration: Duration(seconds: 10),
        ),
      );
      return;
    }

    setState(() {
      _inPoint = _currentPosition;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('In point set: ${_formatDurationWithMs(_inPoint!)}'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _setOutPoint() async {
    if (_inPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set In point first (i)'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _outPoint = _currentPosition;
    });

    if (_outPoint! <= _inPoint!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Out point must be after In point'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _outPoint = null;
      });
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Out point set: ${_formatDurationWithMs(_outPoint!)}'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
        ),
      );
    }

    if (_isVideoFile) {
      await _cutVideoSegment();
    } else {
      await _sliceCut();
    }
  }

  Future<void> _sliceCut() async {
    if (_inPoint == null || _outPoint == null || _currentAudiobook == null)
      return;

    if (_isVideoFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use video editing menu for video files'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final audiobookDir = path.dirname(_currentAudiobook!.path);
    final audiobookName =
        path.basenameWithoutExtension(_currentAudiobook!.path);

    final cutsDir = path.join(audiobookDir, '${audiobookName}_cuts');
    await Directory(cutsDir).create(recursive: true);

    final existingCuts = Directory(cutsDir)
        .listSync()
        .whereType<File>()
        .where((f) => path.extension(f.path) == '.opus')
        .length;

    final cutNumber = (existingCuts + 1).toString().padLeft(4, '0');
    final cutName = '$cutNumber.opus';
    final outputPath = path.join(cutsDir, cutName);

    final duration = _outPoint! - _inPoint!;

    try {
      await _ffmpeg.ensureBinaries();

      if (_ffmpeg.ffmpegPath == null) {
        throw Exception('Bundled ffmpeg not found');
      }

      final args = [
        _ffmpeg.ffmpegPath!,
        '-y',
        '-ss',
        (_inPoint!.inMilliseconds / 1000).toStringAsFixed(3),
        '-i',
        _currentAudiobook!.path,
        '-t',
        (duration.inMilliseconds / 1000).toStringAsFixed(3),
        '-vn',
        '-sn',
        '-c:a',
        'copy',
        '-avoid_negative_ts',
        'make_zero',
        '-fflags',
        '+genpts+igndts',
        outputPath,
      ];

      print(
          'Audio slice (lossless): ${_formatDurationWithMs(_inPoint!)} → ${_formatDurationWithMs(_outPoint!)}');

      final process = await Process.start(args[0], args.sublist(1));

      await process.stderr.drain();
      await process.stdout.drain();

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw Exception('FFmpeg audio slicing failed');
      }

      if (!await File(outputPath).exists()) {
        throw Exception('Output file was not created');
      }

      final fileSize = await File(outputPath).length();
      print(
          'Created: ${path.basename(outputPath)} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Audio cut saved: ${_formatDuration(duration)} (lossless)'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _lastOutPoint = _outPoint ?? _currentPosition;
        _inPoint = null;
        _outPoint = null;
      });
    } catch (e, stackTrace) {
      print('ERROR: Failed to slice audio cut: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to slice cut: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _calculateBitrate() async {
    if (_fileSize == 0 || _totalDuration.inSeconds == 0) return;

    final bitrateKbps =
        ((_fileSize * 8) / _totalDuration.inSeconds / 1000).floor();
    setState(() {
      _averageBitrate = bitrateKbps;
    });
  }

  Future<void> _openAudiobook([String? filePath]) async {
    try {
      String? selectedPath = filePath;
      if (selectedPath == null) {
        String? initialDir;
        if (_currentAudiobook != null) {
          final audiobookPath = _currentAudiobook!.path;
          final audiobookDir = path.dirname(audiobookPath);
          final audiobookBase = path.basenameWithoutExtension(audiobookPath);
          final vttDir = path.join(audiobookDir, '${audiobookBase}_vtt');
          if (await Directory(vttDir).exists()) {
            initialDir = vttDir;
          } else {
            initialDir = audiobookDir;
          }
        }
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'opus',
            'mkv',
            'mp4',
            'webm',
            'avi',
            'mov',
            'm4v'
          ],
          initialDirectory: initialDir,
        );
        if (result == null || result.files.isEmpty) {
          return;
        }
        selectedPath = result.files.first.path!;
      }

      if (YouTubeService.isSupportedUrl(selectedPath!)) {
        final historyItem = _history.firstWhere(
          (h) => h.audiobookPath == selectedPath,
          orElse: () => HistoryItem(
            audiobookPath: selectedPath!,
            audiobookTitle: 'YouTube Stream',
            chapterTitle: 'YouTube Stream',
            lastChapter: 0,
            lastPosition: Duration.zero,
            lastPlayed: DateTime.now(),
            shuffleEnabled: false,
            playedChapters: [],
            isYouTube: true,
          ),
        );
        await _handleYouTubeUrl(selectedPath, resumePosition: historyItem.lastPosition);
        return;
      }

      if (!await File(selectedPath).exists()) {
        print('File no longer exists: $selectedPath');

        final historyIndex =
            _history.indexWhere((h) => h.audiobookPath == selectedPath);
        if (historyIndex != -1) {
          await _removeFromHistory(historyIndex);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('File no longer exists and was removed from history'),
                duration: Duration(seconds: 2),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      if (_isYouTubeStream) {
        await player.stop();
        setState(() {
          _isYouTubeStream = false;
          _youtubeTitle = null;
          _youtubeChannelName = null;
          _currentYouTubeUrl = null;
          _currentAudioFormat = null;
        });
      }

      _isVideoFile = VideoEditService.isVideoFile(selectedPath);
      if (_isVideoFile && !Platform.isAndroid) {
        final info = await VideoEditService.getVideoInfo(selectedPath);
        setState(() {
          _videoResolution = info.resolution;
          _videoFps = info.fps;
        });
      } else {
        setState(() {
          _videoResolution = null;
          _videoFps = null;
        });
      }
      if (_isVideoFile && !Platform.isAndroid) {
        _ffmpegAvailable = await VideoEditService.isAvailable();
      }

      if (_currentAudiobook != null &&
          _currentAudiobook!.path != selectedPath) {
        if (_currentAudiobook!.chapters.isNotEmpty) {
          final currentChapter =
              _currentAudiobook!.chapters[_currentChapterIndex];
          await _statsManager.recordChapterEnd(
            path.basenameWithoutExtension(_currentAudiobook!.path),
            currentChapter.title,
            false,
          );
          await _statsManager.flushCacheToLog();
        }
      }

      final metadata = await _ffmpeg.loadAudiobook(selectedPath);
      final fileSize = await _getFileSize(selectedPath);
      await player.stop();

      if (metadata.chapters.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Audiobook has no chapters'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final historyItem = _history.firstWhere(
        (h) => h.audiobookPath == selectedPath,
        orElse: () => HistoryItem(
          audiobookPath: selectedPath!,
          audiobookTitle: metadata.title,
          chapterTitle: metadata.chapters[0].title,
          lastChapter: 0,
          lastPosition: Duration.zero,
          lastPlayed: DateTime.now(),
          shuffleEnabled: false,
          playedChapters: [],
        ),
      );

      int chapterToLoad =
          historyItem.lastChapter.clamp(0, metadata.chapters.length - 1);
      Duration positionToLoad = historyItem.lastPosition;

      final loadedChapter = metadata.chapters[chapterToLoad];
      if (_shouldSkipChapter(loadedChapter.title)) {
        print(
            'Loaded chapter should be skipped, finding next valid chapter...');

        for (int i = chapterToLoad; i < metadata.chapters.length; i++) {
          if (!_shouldSkipChapter(metadata.chapters[i].title)) {
            chapterToLoad = i;
            positionToLoad = metadata.chapters[i].startTime;
            print(
                'Will skip to chapter ${i + 1}: ${metadata.chapters[i].title}');
            break;
          }
        }
      }

      setState(() {
        _currentAudiobook = metadata;
        _currentChapterIndex = chapterToLoad;
        _currentPosition = positionToLoad;
        _fileSize = fileSize;
        _shuffleEnabled = historyItem.shuffleEnabled;
        _playedChapters = List.from(historyItem.playedChapters);
        _frequencyItems = [];
        _isAnalyzingFrequencies = false;
      });


      if (!_isQuranVerseByVerse) {
        setState(() {
          _quranVerseSearchResults = [];
        });
        _quranVerseSearchController.clear();
        _quranVerseSearchIndex.clear();
      }

      await _loadFontSettings(selectedPath);
      await player.open(Media(selectedPath), play: false);
      await player.setRate(_playbackSpeed);
      await _loadSubtitles(selectedPath);
      _precalculateWordPositions();

      await Future.delayed(const Duration(milliseconds: 100));

      if (positionToLoad.inSeconds > 0) {
        await player.seek(positionToLoad);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      await player.play();

      if (_currentAudiobook != null) {
        _statsManager.recordChapterStart();
      }

      if (_isPlaying) {
        _statsManager.onPlaybackStart();
      }

      await _calculateBitrate();

      _cacheSingleFileDuration(selectedPath);

      if (_showPanel && _panelMode == PanelMode.chapters) {
        _scrollToCurrentChapter();
      }

      _focusNode.requestFocus();
    } catch (e, stackTrace) {
      print('Error opening audiobook: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open audiobook: $e'),
            backgroundColor: Colors.red,
          ),
        );
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _openAudiobookDirectory() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }
    final audiobookDir = path.dirname(_currentAudiobook!.path);
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [audiobookDir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [audiobookDir]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [audiobookDir]);
      }
    } catch (e) {
      print('Error opening directory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open directory: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openLutPicker() {
    if (_currentAudiobook == null) return;
    if (!VideoEditService.isVideoFile(_currentAudiobook!.path)) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => LutPickerOverlay(
        videoPath: _currentAudiobook!.path,
        currentPosition: _currentPosition,
        currentLutName: _selectedLut?.name,
        onLutSelected: (lut) => setState(() => _selectedLut = lut),
      ),
    );
  }

  Future<void> _loadSubtitleFromVttDir() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }
    final audiobookPath = _currentAudiobook!.path;
    final audiobookDir = path.dirname(audiobookPath);
    final audiobookBase = path.basenameWithoutExtension(audiobookPath);
    final vttDir = path.join(audiobookDir, '${audiobookBase}_vtt');

    String initialDirectory = audiobookDir;
    if (await Directory(vttDir).exists()) {
      initialDirectory = vttDir;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
      dialogTitle: 'Select Subtitle File',
      initialDirectory: initialDirectory,
    );

    if (result == null || result.files.isEmpty) return;

    var subtitlePath = result.files.first.path!;

    try {
      if (path.extension(subtitlePath).toLowerCase() == '.srt') {
        final vttPath = subtitlePath.replaceAll(
            RegExp(r'\.srt$', caseSensitive: false), '.vtt');

        if (!await File(vttPath).exists()) {
          final srtContent = await File(subtitlePath).readAsString();
          final vttContent = _convertSrtToVtt(srtContent);
          await File(vttPath).writeAsString(vttContent);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Converted SRT to VTT: ${path.basename(vttPath)}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }

        subtitlePath = vttPath;
      }

      final content = await File(subtitlePath).readAsString();
      final subtitles = _parseVTT(content);

      setState(() {
        _subtitles = subtitles;
        _subtitleFilePath = subtitlePath;
        _currentSubtitleText = '';
        _originalSubtitles = subtitles;
        _paragraphItems = _createParagraphs(subtitles);
      });

      await SubtitlePreferences.saveLastUsedVttPath(
          audiobookPath, subtitlePath);

      _updateCurrentSubtitle();
      _scheduleFrequencyGeneration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Loaded ${_subtitles.length} subtitle cues from ${path.basename(subtitlePath)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error loading subtitles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load subtitles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveVttShowFile() async {
    if (_subtitleFilePath == null) return;
    _vttShowCaptureIfChanged();

    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();
    for (final cue in _originalSubtitles) {
      buffer.writeln(
          '${_formatVttTime(cue.startTime)} --> ${_formatVttTime(cue.endTime)}');
      buffer.writeln(cue.text);
      buffer.writeln();
    }

    await VttShowService.save(
      vttPath: _subtitleFilePath!,
      styles: _vttShowStyles,
      subtitleCueKeys: _allSubtitleCueKeys(),
      vttContent: buffer.toString(),
    );
  }

  Future<void> _loadVttShowSilentAudio() async {
    try {
      String bundlePath;

      if (Platform.isMacOS || Platform.isIOS) {
        final executablePath = Platform.resolvedExecutable;
        final appDir = path.dirname(path.dirname(executablePath));
        bundlePath = path.join(
          appDir,
          'Frameworks',
          'App.framework',
          'Resources',
          'flutter_assets',
          'assets',
          'adhanclock',
          'substitcher_vttshow.opus',
        );
      } else if (Platform.isLinux) {
        final executablePath = Platform.resolvedExecutable;
        final appDir = path.dirname(executablePath);
        bundlePath = path.join(appDir, 'data', 'flutter_assets', 'assets',
            'adhanclock', 'substitcher_vttshow.opus');
      } else if (Platform.isWindows) {
        final executablePath = Platform.resolvedExecutable;
        final appDir = path.dirname(executablePath);
        bundlePath = path.join(appDir, 'data', 'flutter_assets', 'assets',
            'adhanclock', 'substitcher_vttshow.opus');
      } else {
        bundlePath =
            path.join('assets', 'adhanclock', 'substitcher_vttshow.opus');
      }

      print('VttShow silent audio: $bundlePath');

      if (!await File(bundlePath).exists()) {
        print('VttShow silent audio not found: $bundlePath');
        return;
      }

      final metadata = await _ffmpeg.loadAudiobook(bundlePath);
      final fileSize = await _getFileSize(bundlePath);

      await player.stop();
      await player.open(Media(bundlePath), play: false);
      await player.setRate(_playbackSpeed);

      setState(() {
        _currentAudiobook = metadata;
        _currentChapterIndex = 0;
        _currentPosition = Duration.zero;
        _fileSize = fileSize;
        _isVideoFile = false;
      });

      await player.pause();
    } catch (e) {
      print('Error loading vttshow silent audio: $e');
    }
  }

  void _onEditingMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'set_in':
        _setInPoint();
        break;
      case 'set_out':
        _setOutPoint();
        break;
      case 'handleBlurCycle':
        _handleBlurCycle();
        break;
      case 'open_lut_picker':
        _openLutPicker();
        break;
      case 'startDefiningTrackedBlur':
        _startDefiningTrackedBlur();
        break;
      case 'set_in_last_out':
        _setInPointToLastOutPoint();
        break;
      case 'seekToSubtitleEnd':
        _seekToSubtitleEnd();
        break;
      case 'seek_back_1s':
        _skipBackward1();
        break;
      case 'seek_forward_1s':
        _skipForward1();
        break;
      case 'replay_back':
        _replaySegmentBack();
        break;
      case 'replay_forward':
        _replaySegmentForward();
        break;
      case 'cut_segment':
        if (_isVideoFile) {
          _cutVideoSegment();
        } else {
          _setOutPoint();
        }
        break;
      case 'combine_cuts':
        _combineVideoCuts();
        break;
      case 'open_cuts_dir':
        _openCutsDirectory();
        break;
    }
  }

  String _convertSrtToVtt(String srtContent) {
    final lines = srtContent.split('\n');
    final vttLines = <String>['WEBVTT', ''];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.contains('-->')) {
        final convertedLine = line.replaceAll(',', '.');
        vttLines.add(convertedLine);
      } else if (line.isEmpty || RegExp(r'^\d+$').hasMatch(line)) {
        if (line.isEmpty && vttLines.last.isNotEmpty) {
          vttLines.add('');
        }
      } else {
        vttLines.add(line);
      }
    }

    return vttLines.join('\n');
  }

  Future<void> _cutVideoSegment() async {
    if (_isCutting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cut in progress, please wait…'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_inPoint == null || _currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set In point first (i)')),
      );
      return;
    }

    final outPoint = _outPoint ?? _currentPosition;
    if (outPoint <= _inPoint!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Out point must be after In point')),
      );
      return;
    }

    final ffmpeg = await VideoEditService.findSystemFfmpeg();
    if (ffmpeg == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'System ffmpeg not found. Install with: brew install ffmpeg (Mac), sudo apt install ffmpeg (Linux), choco install ffmpeg (Windows)'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 10),
          ),
        );
      }
      return;
    }

    final cutsDir = VideoEditService.getCutsDirectory(_currentAudiobook!.path);
    await Directory(cutsDir).create(recursive: true);

    final ext = path.extension(_currentAudiobook!.path).toLowerCase();
    final existingCuts = Directory(cutsDir)
        .listSync()
        .whereType<File>()
        .where((f) => path.extension(f.path).toLowerCase() == ext)
        .length;

    final cutNumber = (existingCuts + 1).toString().padLeft(4, '0');
    final cutName = '$cutNumber$ext';
    final outputPath = path.join(cutsDir, cutName);

    final videoWidth =
        int.tryParse(_videoResolution?.split('x').firstOrNull ?? '1920') ??
            1920;
    final videoHeight =
        int.tryParse(_videoResolution?.split('x').lastOrNull ?? '1080') ?? 1080;
    final hasPendingTrackedBlur =
        _trackedBlurStart != null && _trackedBlurEnd != null;

    setState(() => _isCutting = true);

    try {
      await VideoEditService.cutVideo(
        inputPath: _currentAudiobook!.path,
        outputPath: outputPath,
        start: _inPoint!,
        end: outPoint,
        cutCodec: _selectedCutCodec,
        blurRegions: hasPendingTrackedBlur ? [] : _blurRegions,
        trackedCoords: const [],
        videoWidth: videoWidth,
        videoHeight: videoHeight,
        videoFps: _videoFps ?? 30.0,
        lutAssetPath: _selectedLut?.path,
        onProgress: (msg) {
          print(msg);
          if (mounted &&
              msg.startsWith('Cut complete') &&
              !hasPendingTrackedBlur) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      );

      if (hasPendingTrackedBlur) {
        if (mounted) {
          setState(() => _isTracking = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cut complete. Now tracking motion…'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }

        final x = min(_trackedBlurStart!.dx, _trackedBlurEnd!.dx);
        final y = min(_trackedBlurStart!.dy, _trackedBlurEnd!.dy);
        final w = (_trackedBlurEnd!.dx - _trackedBlurStart!.dx).abs();
        final h = (_trackedBlurEnd!.dy - _trackedBlurStart!.dy).abs();

        final frames = await VisionTrackingService.trackRegion(
          videoPath: outputPath,
          x: x,
          y: y,
          w: w,
          h: h,
        );

        if (mounted) setState(() => _isTracking = false);

        if (frames.isNotEmpty) {
          final trackedCoords = frames
              .map((f) => [f.frameIndex.toDouble(), f.x, f.y, f.w, f.h])
              .toList();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Tracking complete. Now encoding motion-tracking blur…'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }

          final blurredPath = path.join(cutsDir, 'tmp_blurred_$cutName');

          await VideoEditService.cutVideo(
            inputPath: outputPath,
            outputPath: blurredPath,
            start: Duration.zero,
            end: outPoint - _inPoint!,
            cutCodec: _selectedCutCodec,
            blurRegions: const [],
            trackedCoords: trackedCoords,
            videoWidth: videoWidth,
            videoHeight: videoHeight,
            videoFps: _videoFps ?? 30.0,
            invertTrackedBlur: _trackedBlurInverted,
            lutAssetPath: _selectedLut?.path,
            onProgress: (msg) {
              print(msg);
              if (mounted && msg.startsWith('Cut complete')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Motion-tracking blur complete ✓'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          );

          await File(outputPath).delete();
          await File(blurredPath).rename(outputPath);
        }
      }

      setState(() {
        _lastOutPoint = _outPoint ?? _currentPosition;
        _inPoint = null;
        _outPoint = null;
        _blurRegions = [];
        _blurDrawMode = false;
        _trackedCoords = [];
        _trackedBlurStart = null;
        _trackedBlurEnd = null;
        _trackedBlurInverted = false;
        _isTracking = false;
      });
    } catch (e) {
      print('CUT ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cut failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 15),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCutting = false);
    }
  }

  Future<void> _combineAllCuts() async {
    _combineVideoCuts();
  }

  void _startDefiningTrackedBlur() {
    if (_inPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set In point first (i)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!VisionTrackingService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Motion tracking is only available on macOS'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() {
      _isDefiningTrackedBlur = true;
      _trackedBlurStart = null;
      _trackedBlurEnd = null;
      _trackedCoords = [];
      _isTracking = false;
    });
  }

  Future<void> _skipBackward1Frame() async {
    if (_isPlaying) await player.pause();
    final fps = _videoFps ?? 30.0;
    final frameDuration = Duration(microseconds: (1000000 / fps).round());
    final newPosition = _currentPosition - frameDuration;
    final clampedPosition = Duration(
      milliseconds:
          newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds),
    );
    await _seekTo(clampedPosition);
  }

  Future<void> _skipForward1Frame() async {
    if (_isPlaying) await player.pause();
    final fps = _videoFps ?? 30.0;
    final frameDuration = Duration(microseconds: (1000000 / fps).round());
    final newPosition = _currentPosition + frameDuration;
    final clampedPosition = Duration(
      milliseconds:
          newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds),
    );
    await _seekTo(clampedPosition);
  }

  Future<void> _combineVideoCuts() async {
    if (_currentAudiobook == null) return;

    final systemFfmpeg = await VideoEditService.findSystemFfmpeg();
    if (systemFfmpeg == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'brew install ffmpeg (Mac), sudo apt install ffmpeg (Linux), choco install ffmpeg (Windows)'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 10),
          ),
        );
      }
      return;
    }

    setState(() {
      _showCutsOverlay = true;
    });
  }

  Future<void> _openCutsDirectory() async {
    if (_currentAudiobook == null) return;
    final cutsDir = VideoEditService.getCutsDirectory(_currentAudiobook!.path);
    await Directory(cutsDir).create(recursive: true);
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [cutsDir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [cutsDir]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [cutsDir]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open cuts directory: $e')),
        );
      }
    }
  }

  Future<void> _performCombine(
      List<String> cutFiles, EncodeSettings settings) async {
    final baseName = path.basenameWithoutExtension(_currentAudiobook!.path);
    final sourceDir = path.dirname(_currentAudiobook!.path);
    final cutsDir = VideoEditService.getCutsDirectory(_currentAudiobook!.path);

    final isWholeVideo =
        cutFiles.length == 1 && cutFiles.first == _currentAudiobook!.path;
    final outputPath = isWholeVideo
        ? path.join(sourceDir, '${baseName}_encoded.mp4')
        : path.join(cutsDir, '${baseName}_combined.mp4');
    final finalPath = isWholeVideo
        ? outputPath
        : path.join(sourceDir, '${baseName}_combined.mp4');

    setState(() {
      _showCutsOverlay = false;
      _lastEncodeSettings = settings;
      _isCombining = true;
      _combineCancelled = false;
      _combineProgress = 0.0;
      _combineStep = 'Starting...';
      _combineStartTime = DateTime.now();
      _combineFinishTime = null;
    });

    try {
      await for (final progress in VideoEditService.stitchAndEncode(
        segmentFiles: cutFiles,
        outputPath: outputPath,
        settings: settings,
        onProcessStarted: (p) => _combineProcess = p,
      )) {
        if (_combineCancelled) {
          _combineProcess?.kill();
          _combineProcess = null;
          break;
        }
        if (_combineCancelled) break;
        if (mounted) {
          setState(() {
            _combineProgress = progress.percent;
            _combineStep = progress.step;
          });
        }
      }

      if (_combineCancelled) {
        try {
          await File(outputPath).delete();
        } catch (_) {}
        if (mounted) {
          setState(() {
            _isCombining = false;
            _combineFinishTime = null;
            _combineProgress = 0.0;
            _combineStep = '';
            _combineStartTime = null;
          });
        }
        return;
      }

      if (!isWholeVideo) await File(outputPath).rename(finalPath);
      _combineProcess = null;

      if (mounted) {
        setState(() {
          _isCombining = false;
          _combineFinishTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCombining = false;
          _combineFinishTime = null;
          _combineProgress = 0.0;
          _combineStep = '';
          _combineStartTime = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Combine failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 30),
          ),
        );
      }
    }
  }

  bool _isTextFieldFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;
    bool found = false;
    context.visitAncestorElements((element) {
      if (element.widget is TextField) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  Future<void> _navigateFonts(int direction, {bool fromCycle = false}) async {
    if (!fromCycle && _fontCycleActive) {
      setState(() {
        _fontCycleActive = false;
      });
    }
    _fontCycleCueCounter = 0;
    final filteredFonts = _getFilteredFonts();
    if (filteredFonts.isEmpty) return;

    setState(() {
      _selectedFontIndex =
          ((_selectedFontIndex + direction) % filteredFonts.length +
                  filteredFonts.length) %
              filteredFonts.length;
      _selectedFont = filteredFonts[_selectedFontIndex];
    });
    _scrollToSelectedFont();

    final usePending = fromCycle &&
        _pendingCycleReady &&
        _pendingCycleFont == _selectedFont;

    if (usePending) {
      if (_pendingCycleConversionType != null) {
        setState(() => _conversionType = _pendingCycleConversionType!);
        await _applyConversion();
      }
      _pendingCycleReady = false;
    } else {
      if (_autoConvertAlternates &&
          FontAlternatesData.hasFontAlternates(_selectedFont)) {
        setState(() => _conversionType = 'alternates');
        await _applyConversion();
      } else if (_autoConvertMissing) {
        final metadata = FontDatabase.getMetadata(_selectedFont);
        if (metadata != null && metadata.hasMissingLigatures()) {
          setState(() => _conversionType = 'missing');
          await _applyConversion();
        }
      }
    }
  }

  void _scrollToSelectedFont() {
    if (!_fontScrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_fontScrollController.hasClients) return;
      const itemHeight = 56.0;
      final viewportHeight = _fontScrollController.position.viewportDimension;
      final currentScroll = _fontScrollController.offset;
      final itemTop = _selectedFontIndex * itemHeight;
      final itemBottom = itemTop + itemHeight;
      final viewportTop = currentScroll;
      final viewportBottom = currentScroll + viewportHeight;
      if (itemTop < viewportTop) {
        final targetOffset =
            (itemTop) - (viewportHeight / 2) + (itemHeight / 2);
        final maxScroll = _fontScrollController.position.maxScrollExtent;
        final minScroll = _fontScrollController.position.minScrollExtent;
        final clampedScroll = targetOffset.clamp(minScroll, maxScroll);
        _fontScrollController.animateTo(
          clampedScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (itemBottom > viewportBottom) {
        final targetOffset =
            (itemTop) - (viewportHeight / 2) + (itemHeight / 2);
        final maxScroll = _fontScrollController.position.maxScrollExtent;
        final minScroll = _fontScrollController.position.minScrollExtent;
        final clampedScroll = targetOffset.clamp(minScroll, maxScroll);
        _fontScrollController.animateTo(
          clampedScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showEncoderScreen) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            EncoderScreen(currentAudiobookPath: _currentAudiobook?.path),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                iconSize: 32,
                onPressed: () {
                  setState(() {
                    _showEncoderScreen = false;
                  });
                  _focusNode.requestFocus();
                },
              ),
            ),
          ],
        ),
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            _showPanel &&
            _panelMode == PanelMode.subs &&
            _searchFocusNode.hasFocus) {
          _searchSubtitles(_searchQuery);
          return KeyEventResult.handled;
        }

        if (_searchFocusNode.hasFocus ||
            _excludeFocusNode.hasFocus ||
            _skipChapterFocusNode.hasFocus ||
            _subsSearchFocusNode.hasFocus ||
            _chapterSearchFocusNode.hasFocus ||
            _chapterExcludeFocusNode.hasFocus ||
            _statsSearchFocusNode.hasFocus ||
            _vttEditLine1FocusNode.hasFocus ||
            _vttEditLine2FocusNode.hasFocus ||
            _quranSearchFocusNode.hasFocus ||
            _quranExcludeFocusNode.hasFocus ||
            _quranRefInputFocusNode.hasFocus ||
            _hadeethSearchFocusNode.hasFocus ||
            _hadeethExcludeFocusNode.hasFocus ||
            _tafsirSearchFocusNode.hasFocus ||
            _quranVerseSearchFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }

        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyV &&
              (HardwareKeyboard.instance.isMetaPressed ||
                  HardwareKeyboard.instance.isControlPressed)) {
            return KeyEventResult.ignored;
          }

          if (event.logicalKey == LogicalKeyboardKey.escape &&
              event is KeyDownEvent) {
            if (_vttShowEditMode) {
              setState(() {
                _vttShowEditMode = false;
              });
              _focusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (_showCutsOverlay) {
              setState(() => _showCutsOverlay = false);
              return KeyEventResult.handled;
            }
            if (_blurDrawMode) {
              setState(() {
                _blurDrawMode = false;
                _blurDragStart = null;
                _blurDragCurrent = null;
              });
              _focusNode.requestFocus();
              return KeyEventResult.handled;
            }
            if (_inPoint != null && _isVideoFile) {
              setState(() => _inPoint = null);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('In point cleared'),
                  duration: Duration(seconds: 2),
                ),
              );
              return KeyEventResult.handled;
            }
            if (_showSleepTimerCountdown) {
              _cancelSleepTimerCountdown();
              return KeyEventResult.handled;
            }
            if (_showPanel) {
              setState(() {
                _showPanel = false;
              });
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.backquote &&
              event is KeyDownEvent) {
            final wasCollapsed = _panelCollapsed;
            setState(() {
              _panelCollapsed = !_panelCollapsed;
            });
            if (wasCollapsed &&
                _showPanel &&
                _panelMode == PanelMode.chapters) {
              _scrollToCurrentChapter();
            }
            if (wasCollapsed && _showPanel && _panelMode == PanelMode.quran) {
              _scrollToActiveQuranRef();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyC &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _copyChaptersList();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyC &&
              event is KeyDownEvent) {
            if (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed) {
              return KeyEventResult.ignored;
            }
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.chapters;
            });
            _scrollToCurrentChapter();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyU &&
              HardwareKeyboard.instance.isControlPressed &&
              event is KeyDownEvent) {
            _copyCurrentSubtitleInMemory();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyU &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _copySecondarySubtitle();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyU &&
              event is KeyDownEvent) {
            _copyCurrentSubtitle();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyH &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            setState(() {
              _hideChapterTitle = !_hideChapterTitle;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyH &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.history;
            });
            _scrollToTopOfHistory();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyP &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.playlist;
            });
            _scrollToCurrentPlaylistItem();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyB &&
              HardwareKeyboard.instance.isShiftPressed) {
            if (event is KeyDownEvent) {
              setState(() {
                _fontColorOverride = switch (_fontColorOverride) {
                  FontColorOverride.none => FontColorOverride.black,
                  FontColorOverride.black => FontColorOverride.white,
                  FontColorOverride.white => FontColorOverride.none,
                };
              });
              _saveDefaultSettings();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyB &&
              HardwareKeyboard.instance.isControlPressed) {
            if (event is KeyDownEvent) {
              setState(() {
                _blurShadowEnabled = !_blurShadowEnabled;
              });
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
            if (event is KeyDownEvent) {
              setState(() {
                _showPanel = true;
                _panelMode = PanelMode.bookmarks;
              });
              _scrollToTopOfHistory();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _addFontToFavorites(_selectedFont);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.fonts;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyR &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            if (_currentColorPalette != null) {
              _addColorPaletteToFavorites(_currentColorPalette!.name);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyR &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.colors;
            });
            _scrollToSelectedColorPalette();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyW &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.words;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            if (_vttShowActive && _subtitleFilePath != null) {
              _vttEditKey.currentState?.flushEdits();
              Future.delayed(const Duration(milliseconds: 50), () {
                _saveVttShowFile().then((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Saved ✓'),
                        duration: Duration(seconds: 1),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                });
              });
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyT &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.luts;
            });
            if (_availableLuts.isEmpty) {
              _scanAvailableLuts();
            }
            _scrollToSelectedLut();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.subs;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyT &&
              event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.stats;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.home &&
              event is KeyDownEvent) {
            player.seek(Duration.zero);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.end &&
              event is KeyDownEvent) {
            if (_currentAudiobook != null) {
              player.seek(_currentAudiobook!.duration);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.slash &&
              event is KeyDownEvent) {
            if (_showPanel) {
              if (_panelMode == PanelMode.subs) {
                _searchFocusNode.requestFocus();
              } else if (_panelMode == PanelMode.quran) {
                _quranSearchFocusNode.requestFocus();
              } else if (_panelMode != PanelMode.words) {
                _searchFocusNode.requestFocus();
              }
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.space &&
              event is KeyDownEvent) {
            if (player.state.playing) {
              player.pause();
            } else {
              player.play();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
              (HardwareKeyboard.instance.isControlPressed ||
                  HardwareKeyboard.instance.isMetaPressed) &&
              event is KeyDownEvent) {
            if (_showPanel && _panelMode != PanelMode.words) {
              _searchController.clear();
              _excludeController.clear();
              setState(() {
                _searchQuery = '';
                _excludeTerms = '';
              });
              if (_panelMode == PanelMode.subs) {
                _subsSearchController.clear();
                setState(() {
                  _subsSearchQuery = '';
                  _subtitleSearchResults = [];
                });
              }
            }
            return KeyEventResult.handled;
          } else if ((event.logicalKey == LogicalKeyboardKey.digit0 ||
                  event.logicalKey == LogicalKeyboardKey.numpad0) &&
              event is KeyDownEvent) {
            if (_isTextFieldFocused()) return KeyEventResult.ignored;
            _adhanClockService.stopAdhan();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyG &&
              event is KeyDownEvent) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              setState(() {
                _pauseMode = PauseMode.disabled;
                _nextPauseTime = null;
                _pauseModeTimer?.cancel();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pause Mode >: Disabled'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            } else {
              setState(() {
                _pauseMode = PauseMode.pause2s;
                if (_currentSubtitleIndex != null &&
                    _currentSubtitleIndex! < _subtitles.length) {
                  final cue = _subtitles[_currentSubtitleIndex!];
                  _nextPauseTime =
                      cue.endTime - const Duration(milliseconds: 200);
                }
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pause Mode: 2s'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyL &&
              HardwareKeyboard.instance.isControlPressed &&
              event is KeyDownEvent) {
            _openLutPicker();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyL &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _openAudiobookDirectory();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyL &&
              event is KeyDownEvent) {
            _openAudiobook();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyM &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _copyCurrentMetadata();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyM &&
              event is KeyDownEvent) {
            setState(() {
              _showAdhanOverlay = !_showAdhanOverlay;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.bracketLeft &&
              event is KeyDownEvent) {
            _decreaseSpeed();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.bracketRight &&
              event is KeyDownEvent) {
            _increaseSpeed();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            if (Platform.isAndroid || Platform.isIOS) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'YouTube audio streaming is only available on desktop'),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              _showYouTubeDialog();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY &&
              event is KeyDownEvent) {
            _toggleFullscreen();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _setSleepTimer(null);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
              event is KeyDownEvent) {
            _setSleepTimer(Duration.zero);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyQ &&
              event is KeyDownEvent) {
            if (HardwareKeyboard.instance.isControlPressed) {
              _applyDefaultSettings();
            } else if (HardwareKeyboard.instance.isShiftPressed) {
              _playNextQuranRef();
            } else {
              setState(() {
                _showPanel = true;
                _panelMode = PanelMode.quran;
                _panelCollapsed = false;
              });
              _scrollToActiveQuranRef();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.equal &&
              event is KeyDownEvent) {
            _showGlyphViewerOverlay();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyA &&
              HardwareKeyboard.instance.isControlPressed &&
              event is KeyDownEvent) {
            if (_vttShowEditMode && _currentSubtitleIndex != null) {
              final index = _currentSubtitleIndex!;
              final cue = _subtitles[index];
              if (cue.text.trim().isEmpty) return KeyEventResult.handled;
              _vttEditKey.currentState?.flushEdits();
              _addCueAfter(index);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (event.logicalKey == LogicalKeyboardKey.keyA &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _combineAllCuts();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyA &&
              event is KeyDownEvent) {
            _applyDefaultSettings();
            return KeyEventResult.handled;
          } else if ((event.logicalKey == LogicalKeyboardKey.minus ||
                  event.logicalKey == LogicalKeyboardKey.underscore) &&
              event is KeyDownEvent) {
            if (_isVideoFile) {
              if (HardwareKeyboard.instance.isShiftPressed) {
                _startDefiningTrackedBlur();
              } else {
                _handleBlurCycle();
              }
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.tab &&
              event is KeyDownEvent) {
            if (_vttShowActive) {
              if (_vttShowEditMode) {
                if (!_vttEditLine1FocusNode.hasFocus &&
                    !_vttEditLine2FocusNode.hasFocus) {
                  _vttEditLine1FocusNode.requestFocus();
                }
              } else {
                if (_currentAudiobook == null) {
                  _loadVttShowSilentAudio();
                }
                setState(() {
                  _vttShowEditMode = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final idx = _currentSubtitleIndex ?? 0;
                  _vttEditKey.currentState?.jumpToIndex(idx);
                });
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
            setState(() {
              _showEncoderScreen = true;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyD &&
              HardwareKeyboard.instance.isControlPressed &&
              event is KeyDownEvent) {
            if (_vttShowEditMode && _currentSubtitleIndex != null) {
              final index = _currentSubtitleIndex!;
              setState(() {
                _subtitles.removeAt(index);
                _originalSubtitles.removeAt(index);
              });
              final newIndex = (index - 1).clamp(0, _subtitles.length - 1);
              final cue = _subtitles[newIndex];
              _seekTo(cue.startTime + const Duration(milliseconds: 10));
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _showDownloadDialog();
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent) {
              if (_currentSubtitleText.isNotEmpty) {
                if (!_showWordOverlay) {
                  if (_isPlaying) {
                    player.pause();
                  }
                  if (_pauseMode != PauseMode.dictionary) {
                    setState(() {
                      _pauseMode = PauseMode.dictionary;
                      if (_currentSubtitleIndex != null &&
                          _currentSubtitleIndex! < _subtitles.length) {
                        final cue = _subtitles[_currentSubtitleIndex!];
                        _nextPauseTime =
                            cue.endTime - const Duration(milliseconds: 200);
                      }
                    });
                  }
                }
                setState(() {
                  _showWordOverlay = !_showWordOverlay;
                });
                if (!_showWordOverlay && _pauseMode == PauseMode.dictionary) {
                  setState(() {
                    _pauseMode = PauseMode.disabled;
                  });
                }
              }
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (HardwareKeyboard.instance.isControlPressed) {
              setState(() {
                _subtitleLineSpacing =
                    ((_subtitleLineSpacing * 100).round() + 1) / 100;
                _subtitleLineSpacing = _subtitleLineSpacing.clamp(0.5, 2.5);
              });
              return KeyEventResult.handled;
            } else if (HardwareKeyboard.instance.isAltPressed) {
              _increaseFontSize();
              return KeyEventResult.handled;
            } else if (HardwareKeyboard.instance.isShiftPressed) {
              return KeyEventResult.ignored;
            } else if (_showPanel && _panelMode == PanelMode.luts) {
              _navigateLuts(-1);
              return KeyEventResult.handled;
            } else if (_showPanel && _panelMode == PanelMode.colors) {
              _navigateColors(-1);
              return KeyEventResult.handled;
            } else if (_showPanel && _panelMode == PanelMode.fonts) {
              _navigateFonts(-1);
              return KeyEventResult.handled;
            } else {
              _increaseFontSize();
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (HardwareKeyboard.instance.isControlPressed) {
              setState(() {
                _subtitleLineSpacing =
                    ((_subtitleLineSpacing * 100).round() - 1) / 100;
                _subtitleLineSpacing = _subtitleLineSpacing.clamp(0.5, 2.5);
              });
              return KeyEventResult.handled;
            } else if (HardwareKeyboard.instance.isAltPressed) {
              _decreaseFontSize();
              return KeyEventResult.handled;
            } else if (HardwareKeyboard.instance.isShiftPressed) {
              return KeyEventResult.ignored;
            } else if (_showPanel && _panelMode == PanelMode.luts) {
              _navigateLuts(1);
              return KeyEventResult.handled;
            } else if (_showPanel && _panelMode == PanelMode.colors) {
              _navigateColors(1);
              return KeyEventResult.handled;
            } else if (_showPanel && _panelMode == PanelMode.fonts) {
              _navigateFonts(1);
              return KeyEventResult.handled;
            } else {
              _decreaseFontSize();
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _nextChapter();
              return KeyEventResult.handled;
            }
            if (_vttShowActive && _subtitles.isNotEmpty) {
              final currentLines = _currentSubtitleText.split('\n').length;
              if (_vttShowRevealedLines < currentLines) {
                setState(() => _vttShowRevealedLines++);
              } else {
                _skipToNextSubtitle();
              }
              return KeyEventResult.handled;
            }
            if (_subtitles.isNotEmpty) {
              _skipToNextSubtitle();
            } else {
              _skipForward3();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _previousChapter();
              return KeyEventResult.handled;
            }
            if (_vttShowActive && _subtitles.isNotEmpty) {
              if (_vttShowRevealedLines > 1) {
                setState(() => _vttShowRevealedLines--);
              } else {
                _skipToPreviousSubtitle();
              }
              return KeyEventResult.handled;
            }
            if (_subtitles.isNotEmpty) {
              _skipToPreviousSubtitle();
            } else {
              _skipBackward3();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyI &&
              HardwareKeyboard.instance.isShiftPressed &&
              event is KeyDownEvent) {
            _setInPointToLastOutPoint();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyI &&
              event is KeyDownEvent) {
            _setInPoint();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyO &&
              event is KeyDownEvent) {
            _setOutPoint();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.semicolon &&
              event is KeyDownEvent) {
            _seekToSubtitleEnd();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyJ &&
              event is KeyDownEvent) {
            _skipBackward1();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyK &&
              event is KeyDownEvent) {
            _skipForward1();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.comma &&
              event is KeyDownEvent) {
            if (_isVideoFile) {
              _skipBackward1Frame();
            } else {
              _replaySegmentBack();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.period &&
              event is KeyDownEvent) {
            if (_isVideoFile) {
              _skipForward1Frame();
            } else {
              _replaySegmentForward();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyN &&
              event is KeyDownEvent) {
            _addBookmark();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyV &&
              event is KeyDownEvent) {
            _openSubtitleManager();
            return KeyEventResult.handled;
          } else if (_showPanel && _panelMode == PanelMode.bookmarks) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.numpad1) {
              _jumpToPinnedBookmark(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.numpad2) {
              _jumpToPinnedBookmark(2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.numpad3) {
              _jumpToPinnedBookmark(3);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                event.logicalKey == LogicalKeyboardKey.numpad4) {
              _jumpToPinnedBookmark(4);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 ||
                event.logicalKey == LogicalKeyboardKey.numpad5) {
              _jumpToPinnedBookmark(5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 ||
                event.logicalKey == LogicalKeyboardKey.numpad6) {
              _jumpToPinnedBookmark(6);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 ||
                event.logicalKey == LogicalKeyboardKey.numpad7) {
              _jumpToPinnedBookmark(7);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit8 ||
                event.logicalKey == LogicalKeyboardKey.numpad8) {
              _jumpToPinnedBookmark(8);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit9 ||
                event.logicalKey == LogicalKeyboardKey.numpad9) {
              _jumpToPinnedBookmark(9);
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.history) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.numpad1) {
              _jumpToHistoryItem(0);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.numpad2) {
              _jumpToHistoryItem(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.numpad3) {
              _jumpToHistoryItem(2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                event.logicalKey == LogicalKeyboardKey.numpad4) {
              _jumpToHistoryItem(3);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 ||
                event.logicalKey == LogicalKeyboardKey.numpad5) {
              _jumpToHistoryItem(4);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 ||
                event.logicalKey == LogicalKeyboardKey.numpad6) {
              _jumpToHistoryItem(5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 ||
                event.logicalKey == LogicalKeyboardKey.numpad7) {
              _jumpToHistoryItem(6);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit8 ||
                event.logicalKey == LogicalKeyboardKey.numpad8) {
              _jumpToHistoryItem(7);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit9 ||
                event.logicalKey == LogicalKeyboardKey.numpad9) {
              _jumpToHistoryItem(8);
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.playlist) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.numpad1) {
              _jumpToPlaylistItem(0);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.numpad2) {
              _jumpToPlaylistItem(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.numpad3) {
              _jumpToPlaylistItem(2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                event.logicalKey == LogicalKeyboardKey.numpad4) {
              _jumpToPlaylistItem(3);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 ||
                event.logicalKey == LogicalKeyboardKey.numpad5) {
              _jumpToPlaylistItem(4);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 ||
                event.logicalKey == LogicalKeyboardKey.numpad6) {
              _jumpToPlaylistItem(5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 ||
                event.logicalKey == LogicalKeyboardKey.numpad7) {
              _jumpToPlaylistItem(6);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit8 ||
                event.logicalKey == LogicalKeyboardKey.numpad8) {
              _jumpToPlaylistItem(7);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit9 ||
                event.logicalKey == LogicalKeyboardKey.numpad9) {
              _jumpToPlaylistItem(8);
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.fonts) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.numpad1) {
              _resetConversion();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.numpad2) {
              _convertToDemo();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.numpad3) {
              _convertToDemoUpper();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                event.logicalKey == LogicalKeyboardKey.numpad4) {
              _convertToAlternates();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 ||
                event.logicalKey == LogicalKeyboardKey.numpad5) {
              _convertToMissing();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 ||
                event.logicalKey == LogicalKeyboardKey.numpad6) {
              _convertToUppercase();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 ||
                event.logicalKey == LogicalKeyboardKey.numpad7) {
              _convertToSeesawCase();
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.colors) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.numpad1) {
              setState(() {
                _coloringMode = ColoringMode.words;
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.numpad2) {
              setState(() {
                _coloringMode = ColoringMode.letters;
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.numpad3) {
              setState(() {
                _colorFilterMode = 'all';
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                event.logicalKey == LogicalKeyboardKey.numpad4) {
              setState(() {
                _colorFilterMode = 'favorites';
              });
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.luts) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.numpad1) {
              setState(() => _lutFilterMode = 'all');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.numpad2) {
              setState(() => _lutFilterMode = 'favorites');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.numpad3) {
              setState(() {
                _selectedLutIndex = -1;
                _selectedLutName = null;
                _loadedLutData = null;
              });
              SharedPreferences.getInstance().then((prefs) {
                prefs.remove('selectedLutPath');
                prefs.remove('selectedLutName');
                _quranSearchQuery = prefs.getString('quran_search_query') ?? '';
                _quranExcludeQuery =
                    prefs.getString('quran_exclude_query') ?? '';
                _quranSearchController.text = _quranSearchQuery;
                _quranExcludeController.text = _quranExcludeQuery;
              });
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.keyX &&
              event is KeyDownEvent) {
            if (_primarySubtitlePath != null ||
                _secondarySubtitlePath != null) {
              setState(() {
                final temp = _primarySubtitlePath;
                _primarySubtitlePath = _secondarySubtitlePath;
                _secondarySubtitlePath = temp;

                _subtitleFilePath = _primarySubtitlePath;
                _secondarySubtitleFilePath = _secondarySubtitlePath;

                final tempSubtitles = _subtitles;
                final tempText = _currentSubtitleText;
                final tempIndex = _currentSubtitleIndex;

                _subtitles = _secondarySubtitles;
                _currentSubtitleText = _secondarySubtitleText;
                _currentSubtitleIndex = _currentSecondarySubtitleIndex;

                _secondarySubtitles = tempSubtitles;
                _secondarySubtitleText = tempText;
                _currentSecondarySubtitleIndex = tempIndex;

                final tempFont = _selectedFont;
                final tempSize = _subtitleFontSize;
                final tempPalette = _currentColorPalette;
                final tempConversion = _conversionType;

                _selectedFont = _secondarySubtitleFont;
                _subtitleFontSize = _secondarySubtitleFontSize;
                _currentColorPalette = _secondaryColorPalette;
                _conversionType = _secondaryConversionType;

                _secondarySubtitleFont = tempFont;
                _secondarySubtitleFontSize = tempSize;
                _secondaryColorPalette = tempPalette;
                _secondaryConversionType = tempConversion;

                final tempBlur = _blurShadowEnabled;
                _blurShadowEnabled = _secondaryBlurShadowEnabled;
                _secondaryBlurShadowEnabled = tempBlur;

                final tempFontColor = _fontColorOverride;
                _fontColorOverride = _secondaryFontColorOverride;
                _secondaryFontColorOverride = tempFontColor;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Swapped primary ↔ secondary subtitles'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            if (_showPanel) {
              setState(() {
                _showPanel = false;
              });
            }
            _focusNode.requestFocus();
          },
          child: Stack(
            children: [
              if (_currentAudiobook == null && !_isYouTubeStream)
                _buildNoAudiobook()
              else
                _buildPlayer(),
              if (_showAdhanOverlay)
                AdhanClockOverlay(
                  adhanService: _adhanClockService,
                  onToggleVisibility: () {
                    setState(() {
                      _showAdhanOverlay = false;
                    });
                  },
                ),
              if (_showCutsOverlay && _currentAudiobook != null)
                CutsOverlay(
                  cutsDirectory: VideoEditService.getCutsDirectory(
                      _currentAudiobook!.path),
                  sourceVideoPath: _currentAudiobook!.path,
                  cutFiles: () {
                    final cutsDir = VideoEditService.getCutsDirectory(
                        _currentAudiobook!.path);
                    final dir = Directory(cutsDir);
                    if (!dir.existsSync()) return <String>[];
                    return dir
                        .listSync()
                        .whereType<File>()
                        .where((f) =>
                            path.extension(f.path).toLowerCase() ==
                            path
                                .extension(_currentAudiobook!.path)
                                .toLowerCase())
                        .map((f) => f.path)
                        .toList()
                      ..sort();
                  }(),
                  onCombine: _performCombine,
                  onCutCodecChanged: (codec) {
                    setState(() => _selectedCutCodec = codec);
                  },
                  onOpenDirectory: _openCutsDirectory,
                  onClose: () {
                    setState(() {
                      _showCutsOverlay = false;
                    });
                  },
                ),
              if (_isCombining || _combineFinishTime != null)
                EncodeProgressOverlay(
                  isEncoding: _isCombining,
                  progress: _combineProgress,
                  step: _combineStep,
                  startTime: _combineStartTime,
                  finishTime: _combineFinishTime,
                  encodeSettings: _lastEncodeSettings,
                  onCancel: _isCombining
                      ? () {
                          setState(() => _combineCancelled = true);
                        }
                      : null,
                  onDismiss: () {
                    setState(() {
                      _combineFinishTime = null;
                      _combineProgress = 0.0;
                      _combineStep = '';
                      _combineStartTime = null;
                    });
                  },
                ),
              if (_showPanel &&
                  (_currentAudiobook != null ||
                      _isYouTubeStream ||
                      _panelMode == PanelMode.history ||
                      _panelMode == PanelMode.playlist ||
                      _panelMode == PanelMode.bookmarks ||
                      _panelMode == PanelMode.stats ||
                      _panelMode == PanelMode.quran))
                SidePanel(
                  panelMode: _panelMode,
                  isCollapsed: _panelCollapsed,
                  currentAudiobook: _currentAudiobook,
                  currentChapterIndex: _currentChapterIndex,
                  searchQuery: _searchQuery,
                  searchUseAnd: _searchUseAnd,
                  excludeTerms: _excludeTerms,
                  searchController: _searchController,
                  excludeController: _excludeController,
                  searchFocusNode: _searchFocusNode,
                  excludeFocusNode: _excludeFocusNode,
                  hadeethSearchFocusNode: _hadeethSearchFocusNode,
                  hadeethExcludeFocusNode: _hadeethExcludeFocusNode,
                  tafsirSearchController: _tafsirSearchController,
                  tafsirSearchFocusNode: _tafsirSearchFocusNode,
                  quranVerseSearchController: _quranVerseSearchController,
                  quranVerseSearchFocusNode: _quranVerseSearchFocusNode,
                  quranVerseSearchResults: _quranVerseSearchResults,
                  quranVerseIndexBuilding: _quranVerseIndexBuilding,
                  onQuranVerseSearchChanged: _searchQuranVerseText,
                  onQuranVerseSearchResultTap: _jumpToQuranVerseSearchResult,
                  isExportingMarkdown: _isExportingMarkdown,
                  exportStatus: _exportStatus,
                  onExportMarkdown: _isQuranVerseByVerse
                      ? _exportQuranCombinedMarkdown
                      : _exportMarkdownParagraphs,
                  onClose: () {
                    setState(() {
                      _showPanel = false;
                    });
                    _focusNode.requestFocus();
                  },
                  onToggleCollapse: () {
                    setState(() {
                      _panelCollapsed = !_panelCollapsed;
                    });
                  },
                  onPanelModeChanged: (mode) {
                    setState(() {
                      _panelMode = mode;
                    });
                    if (mode == PanelMode.chapters) {
                      _scrollToCurrentChapter();
                    } else if (mode == PanelMode.playlist) {
                      _scrollToCurrentPlaylistItem();
                    } else if (mode == PanelMode.history ||
                        mode == PanelMode.bookmarks) {
                      _scrollToTopOfHistory();
                    } else if (mode == PanelMode.colors) {
                      _scrollToSelectedColorPalette();
                    } else if (mode == PanelMode.luts) {
                      if (_availableLuts.isEmpty) {
                        _scanAvailableLuts();
                      }
                      _scrollToSelectedLut();
                    }
                  },
                  onSearchChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onExcludeChanged: (value) {
                    setState(() {
                      _excludeTerms = value;
                    });
                  },
                  onSearchAndSelected: () {
                    setState(() {
                      _searchUseAnd = true;
                    });
                  },
                  onSearchOrSelected: () {
                    setState(() {
                      _searchUseAnd = false;
                    });
                  },
                  getFilteredChapters: _getFilteredChapters,
                  onJumpToChapter: _jumpToChapter,
                  chapterScrollController: _chapterScrollController,
                  skipChapterTerms: _skipChapterTerms,
                  skipChapterController: _skipChapterController,
                  skipChapterFocusNode: _skipChapterFocusNode,
                  onSkipChapterChanged: (value) {
                    setState(() {
                      _skipChapterTerms = value;
                    });
                    _saveSkipChapterTerms();
                  },
                  shouldSkipChapter: _shouldSkipChapter,
                  getFilteredHistory: _getFilteredHistory,
                  onRemoveFromHistory: _removeFromHistory,
                  onOpenAudiobook: (path) async {
                    setState(() {
                      _showPanel = false;
                    });
                    await _openAudiobook(path);
                  },
                  historyScrollController: _historyScrollController,
                  getHistoryDurationAndProgress: _getHistoryDurationAndProgress,
                  getFilteredPlaylist: _getFilteredPlaylist,
                  playlistScrollController: _playlistScrollController,
                  getAudiobookDuration: _getAudiobookDuration,
                  showPlaylistDirectories: _showPlaylistDirectories,
                  onRefreshPlaylistDirectory: _refreshPlaylistDirectory,
                  onRefreshCustomFonts: _refreshCustomFonts,
                  onTogglePlaylistDirectories: (value) {
                    setState(() {
                      _showPlaylistDirectories = value;
                    });
                  },
                  getFilteredBookmarks: _getFilteredBookmarks,
                  onRemoveBookmark: _removeBookmark,
                  onJumpToBookmark: _jumpToBookmark,
                  onSetPinNumber: _setPinNumber,
                  onShowGlyphViewer: _showGlyphViewerOverlay,
                  getFilteredFonts: _getFilteredFonts,
                  selectedFont: _selectedFont,
                  selectedFontIndex: _selectedFontIndex,
                  fontScrollController: _fontScrollController,
                  favoriteFonts: _favoriteFonts,
                  onRemoveFavorite: _removeFontFromFavorites,
                  onFontSelected: (fontName, index) async {
                    setState(() {
                      _selectedFont = fontName;
                      _selectedFontIndex = index;
                    });
                    _scrollToSelectedFont();
                    await _saveFontSettings();

                    if (_selectedMainCategory != FontCategory.favorites) {
                      if (_autoConvertAlternates &&
                          FontAlternatesData.hasFontAlternates(fontName)) {
                        setState(() {
                          _conversionType = 'alternates';
                        });
                        await _applyConversion();
                      } else if (_autoConvertMissing) {
                        final metadata = FontDatabase.getMetadata(fontName);
                        if (metadata != null &&
                            metadata.hasMissingLigatures()) {
                          setState(() {
                            _conversionType = 'missing';
                          });
                          await _applyConversion();
                        } else {
                          setState(() {
                            _conversionType = 'none';
                          });
                        }
                      } else {
                        setState(() {
                          _conversionType = 'none';
                        });
                      }
                    }
                  },
                  fontCycleActive: _fontCycleActive,
                  fontCycleInterval: _fontCycleInterval,
                  onFontCycleToggled: () {
                    setState(() {
                      _fontCycleActive = !_fontCycleActive;
                      _fontCycleCueCounter = 0;
                    });
                  },
                  onFontCycleIntervalChanged: (val) {
                    setState(() {
                      _fontCycleInterval = val;
                      _fontCycleCueCounter = 0;
                    });
                  },
                  selectedMainCategory: _selectedMainCategory,
                  selectedSubCategory: _selectedSubCategory,
                  selectedStudio: _selectedStudio,
                  onCategorySelected: (category, subCat, studio) {
                    setState(() {
                      _selectedMainCategory = category;
                      _selectedSubCategory = subCat;
                      _selectedStudio = studio;
                      _selectedFontIndex = 0;
                    });
                    _scrollToSelectedFont();
                  },
                  autoConvertAlternates: _autoConvertAlternates,
                  onAutoConvertAlternatesChanged: (value) async {
                    setState(() {
                      _autoConvertAlternates = value ?? false;
                    });
                    await _saveAutoConversionSettings();
                  },
                  autoConvertMissing: _autoConvertMissing,
                  onAutoConvertMissingChanged: (value) async {
                    setState(() {
                      _autoConvertMissing = value ?? false;
                    });
                    await _saveAutoConversionSettings();
                  },
                  customFontDirectory: _customFontDirectory,
                  onSetCustomFontDirectory: _setCustomFontDirectory,
                  customFontDirectory2: _customFontDirectory2,
                  onSetCustomFontDirectory2: _setCustomFontDirectory2,
                  onRefreshCustomFonts2: _refreshCustomFonts2,
                  playlistDirectories: _playlistDirectories,
                  activePlaylistIndex: _activePlaylistIndex,
                  onAddPlaylistDirectory: _addPlaylistDirectory,
                  onRemovePlaylistDirectory: _removePlaylistDirectory,
                  onSetActivePlaylist: _setActivePlaylist,
                  shortenPath: _shortenPath,
                  onResetConversion: _resetConversion,
                  onConvertToDemo: _convertToDemo,
                  onConvertToDemoUpper: _convertToDemoUpper,
                  onConvertToAlternates: _convertToAlternates,
                  onConvertToMissing: _convertToMissing,
                  onConvertToUppercase: _convertToUppercase,
                  onConvertToSeesawCase: _convertToSeesawCase,
                  conversionType: _conversionType,
                  getFilteredColors: _getFilteredColors,
                  selectedColorIndex: _selectedColorIndex,
                  colorItemScrollController: _colorItemScrollController,
                  onColorPaletteSelected: (palette, index) {
                    setState(() {
                      _selectedColorIndex = index;
                    });
                    _applyColorPalette(palette);
                  },
                  colorCycleActive: _colorCycleActive,
                  colorCycleInterval: _colorCycleInterval,
                  onColorCycleIntervalChanged: (val) {
                    setState(() {
                      _colorCycleInterval = val;
                      _colorCycleCueCounter = 0;
                    });
                    _saveColorSettings();
                  },
                  parseColor: _parseColor,
                  coloringMode: _coloringMode,
                  onColoringModeChanged: (mode) {
                    setState(() {
                      _coloringMode = mode;
                    });
                  },
                  colorFilterMode: _colorFilterMode,
                  onColorFilterModeChanged: (mode) {
                    setState(() {
                      _colorFilterMode = mode;
                    });
                  },
                  favoriteColorPalettes: _favoriteColorPalettes,
                  onRemoveColorPaletteFavorite:
                      _removeColorPaletteFromFavorites,
                  onAddColorPaletteFavorite: _addColorPaletteToFavorites,
                  colorCategoryFilter: _colorFilter,
                  onColorCategoryFilterChanged: (filter) {
                    setState(() {
                      _colorFilter = filter as ColorPaletteFilter;
                      _colorCycleCueCounter = 0;
                      final filtered = _getFilteredColors();
                      if (filtered.isNotEmpty) {
                        final newPalette = filtered.first;
                        _selectedColorIndex =
                            ColorPalette.presets.indexOf(newPalette);
                        _applyColorPalette(newPalette);
                      }
                    });
                    if (_colorItemScrollController.isAttached) {
                      _colorItemScrollController.jumpTo(
                          index: 0, alignment: 0.0);
                    }
                    _saveColorSettings();
                  },
                  onColorCycleToggled: () {
                    setState(() {
                      _colorCycleActive = !_colorCycleActive;
                      _colorCycleCueCounter = 0;
                    });
                    _saveColorSettings();
                  },
                  onClearLut: () {
                    setState(() {
                      _selectedLutIndex = -1;
                      _selectedLutName = null;
                      _loadedLutData = null;
                    });
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.remove('selectedLutPath');
                      prefs.remove('selectedLutName');
                      _quranSearchQuery =
                          prefs.getString('quran_search_query') ?? '';
                      _quranExcludeQuery =
                          prefs.getString('quran_exclude_query') ?? '';
                      _quranSearchController.text = _quranSearchQuery;
                      _quranExcludeController.text = _quranExcludeQuery;
                    });
                  },
                  quranEntries: _quranEntries,
                  isQuranLoaded: _isQuranVerseByVerse,
                  activeQuranRef: _activeQuranRef,
                  onQuranVerseSelected: _navigateToQuranVerse,
                  onQuranPlayAllRequested: _playAllQuranRefs,
                  quranSearchFocusNode: _quranSearchFocusNode,
                  quranExcludeFocusNode: _quranExcludeFocusNode,
                  quranItemScrollController: _quranItemScrollController,
                  lutItemScrollController: _lutItemScrollController,
                  quranSearchQuery: _quranSearchQuery,
                  quranExcludeQuery: _quranExcludeQuery,
                  quranSearchController: _quranSearchController,
                  quranExcludeController: _quranExcludeController,
                  onQuranSearchChanged: (v) {
                    setState(() => _quranSearchQuery = v);
                    SharedPreferences.getInstance()
                        .then((p) => p.setString('quran_search_query', v));
                  },
                  onQuranExcludeChanged: (v) {
                    setState(() => _quranExcludeQuery = v);
                    SharedPreferences.getInstance()
                        .then((p) => p.setString('quran_exclude_query', v));
                  },
                  quranIndexLanguage: _quranIndexLanguage,
                  onQuranLanguageChanged: _onQuranLanguageChanged,
                  frequencyItems: _frequencyItems,
                  isAnalyzingFrequencies: _isAnalyzingFrequencies,
                  onAnalyzeFrequencies: _analyzeFrequencies,
                  subtitleFilePath: _subtitleFilePath,
                  onWordSearch: (word) {
                    setState(() {
                      _searchQuery = word;
                      _searchController.text = word;
                      _panelMode = PanelMode.subs;
                    });
                    _searchSubtitles(word);
                  },
                  onPhraseSearch: (phrase) {
                    setState(() {
                      _subsSearchQuery = phrase;
                      _subsSearchController.text = phrase;
                      _panelMode = PanelMode.subs;
                    });
                    _searchSubtitles(phrase);
                  },
                  subsSearchQuery: _subsSearchQuery,
                  subsSearchController: _subsSearchController,
                  subsSearchFocusNode: _subsSearchFocusNode,
                  onSearchSubtitles: _searchSubtitles,
                  buildSearchContent: _buildSearchContent,
                  isIndexingChapters: _isIndexingChapters,
                  indexingStatus: _indexingStatus,
                  indexedFiles: _indexedFiles,
                  totalFilesToIndex: _totalFilesToIndex,
                  hasChapterIndex: _playlistChapterIndex.isNotEmpty,
                  onIndexPlaylistChapters: _indexPlaylistChapters,
                  chapterSearchQuery: _chapterSearchQuery,
                  chapterSearchController: _chapterSearchController,
                  chapterSearchFocusNode: _chapterSearchFocusNode,
                  onSearchPlaylistChapters: _searchPlaylistChapters,
                  chapterSearchUseAnd: _chapterSearchUseAnd,
                  onChapterSearchAndSelected: () {
                    setState(() {
                      _chapterSearchUseAnd = true;
                    });
                    if (_chapterSearchQuery.isNotEmpty) {
                      _searchPlaylistChapters(_chapterSearchQuery);
                    }
                  },
                  onChapterSearchOrSelected: () {
                    setState(() {
                      _chapterSearchUseAnd = false;
                    });
                    if (_chapterSearchQuery.isNotEmpty) {
                      _searchPlaylistChapters(_chapterSearchQuery);
                    }
                  },
                  chapterExcludeTerms: _chapterExcludeTerms,
                  chapterExcludeController: _chapterExcludeController,
                  chapterExcludeFocusNode: _chapterExcludeFocusNode,
                  onChapterExcludeChanged: (value) {
                    setState(() {
                      _chapterExcludeTerms = value;
                    });
                    if (_chapterSearchQuery.isNotEmpty) {
                      _searchPlaylistChapters(_chapterSearchQuery);
                    }
                  },
                  historyCount: _history.length,
                  playlistCount: _playlist.length,
                  bookmarksCount: _bookmarks.length,
                  fontsCount: CustomFontLoader.loadedFonts.length,
                  subsCount: _subtitles.length,
                  statsCount: _statsManager.statsEntries.length,
                  statsEntries: _statsManager.statsEntries,
                  statsEnabled: _statsManager.statsEnabled,
                  onStatsEnabledChanged: (value) {
                    _statsManager.saveStatsEnabled(value);
                  },
                  onRefreshStats: () {
                    _statsManager.loadAllStatsEntries();
                  },
                  filterEntriesByDate: _filterEntriesByDate,
                  filterEntriesByDays: _filterEntriesByDays,
                  getFileListenTimes: _getFileListenTimes,
                  groupEntriesByAudiobook: _groupEntriesByAudiobook,
                  formatDurationCompact: _formatDurationCompact,
                  formatDuration: _formatDuration,
                  deleteAudiobookFromDate: (title, date) async {
                    await _statsManager.deleteAudiobookFromDate(title, date);
                    setState(() {});
                  },
                  highlightSearchTerm: _highlightSearchTerm,
                  jumpToStatsResult: (filename, chapterTitle, startTime) {
                    _jumpToStatsResult(filename, chapterTitle, startTime);
                  },
                  availableLuts: _availableLuts,
                  getFilteredLuts: _getFilteredLuts,
                  selectedLutIndex: _selectedLutIndex,
                  onLutSelected: (lut, index) async {
                    if (lut.path.isEmpty) {
                      setState(() {
                        _selectedLutIndex = -1;
                        _selectedLutName = null;
                        _loadedLutData = null;
                      });
                    } else {
                      final actualIndex =
                          _availableLuts.indexWhere((l) => l.path == lut.path);
                      setState(() => _selectedLutIndex = actualIndex);
                      await _selectLut(
                          lut.path, lut.name.replaceAll('.cube', ''));
                    }
                  },
                  favoriteLuts: _favoriteLuts,
                  lutFilterMode: _lutFilterMode,
                  onLutFilterModeChanged: (mode) =>
                      setState(() => _lutFilterMode = mode),
                  onAddLutFavorite: _addLutToFavorites,
                  onRemoveLutFavorite: _removeLutFromFavorites,
                  selectedLutName: _selectedLutName,
                ),
              if (_showWordOverlay && _currentSubtitleText.isNotEmpty)
                WordOverlay(
                  subtitle: _currentSubtitleIndex != null &&
                          _currentSubtitleIndex! < _originalSubtitles.length
                      ? _originalSubtitles[_currentSubtitleIndex!].text
                      : _currentSubtitleText,
                  colorPalette: _currentColorPalette?.colors,
                  startWordIndex:
                      _calculateWordIndexAtPosition(_currentPosition),
                  onClose: () {
                    setState(() {
                      _showWordOverlay = false;
                    });

                    _dictionaryModeExitTimer?.cancel();
                    _dictionaryModeExitTimer =
                        Timer(const Duration(seconds: 3), () {
                      if (!_showWordOverlay &&
                          _pauseMode == PauseMode.dictionary) {
                        setState(() {
                          _pauseMode = PauseMode.disabled;
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Exited Dictionary Mode'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      }
                    });
                  },
                ),
              if (_vttShowActive &&
                  _vttShowEditMode &&
                  _currentSubtitleIndex != null)
                VttShowEditOverlay(
                  key: _vttEditKey,
                  subtitles: _subtitles,
                  originalSubtitles: _originalSubtitles,
                  currentIndex: _currentSubtitleIndex!,
                  line1FocusNode: _vttEditLine1FocusNode,
                  line2FocusNode: _vttEditLine2FocusNode,
                  onClose: () {
                    setState(() {
                      _vttShowEditMode = false;
                    });
                    _focusNode.requestFocus();
                  },
                  onSave: () {
                    _vttEditKey.currentState?.flushEdits();
                    Future.delayed(const Duration(milliseconds: 50), () {
                      _saveVttShowFile().then((_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved ✓'),
                              duration: Duration(seconds: 1),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      });
                    });
                  },
                  onNavigate: (newIndex) {
                    final cue = _subtitles[newIndex];
                    _seekTo(cue.startTime + const Duration(milliseconds: 10));
                  },
                  onCueTextChanged: (index, line1, line2) {
                    final cue = _subtitles[index];
                    final newText = line2.isEmpty ? line1 : '$line1\n$line2';
                    setState(() {
                      _subtitles[index] = SubtitleCue(
                        startTime: cue.startTime,
                        endTime: cue.endTime,
                        text: newText,
                      );
                      _originalSubtitles[index] = SubtitleCue(
                        startTime: cue.startTime,
                        endTime: cue.endTime,
                        text: newText,
                      );
                    });
                  },
                  onDeleteCue: (index) {
                    setState(() {
                      _subtitles.removeAt(index);
                      _originalSubtitles.removeAt(index);
                      final key = index < _subtitles.length
                          ? '${_formatVttTime(_subtitles[index].startTime)} --> ${_formatVttTime(_subtitles[index].endTime)}'
                          : null;
                      if (key != null) _vttShowStyles.remove(key);
                    });
                  },
                  onAddCueAfter: (index) {
                    _addCueAfter(index);
                  },
                ),
              if (_showSleepTimerCountdown) _buildSleepTimerCountdown(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTimerActionToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'When timer ends:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(width: 12),
        ToggleButtons(
          isSelected: [
            _sleepTimerAction == SleepTimerAction.pauseOnly,
            _sleepTimerAction == SleepTimerAction.closeApp,
          ],
          onPressed: (index) {
            setState(() {
              _sleepTimerAction = index == 0
                  ? SleepTimerAction.pauseOnly
                  : SleepTimerAction.closeApp;
            });
          },
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Colors.deepPurple,
          color: Colors.white70,
          constraints: const BoxConstraints(minHeight: 36, minWidth: 100),
          children: const [
            Text('Pause'),
            Text('Close App'),
          ],
        ),
      ],
    );
  }

  Widget _buildSleepTimerCountdown() {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepPurple, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bedtime,
                  size: 64,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sleep Timer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Closing app in $_sleepTimerCountdownSeconds seconds',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _cancelSleepTimerCountdown,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel closing app'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveColorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('colorCategoryFilter', _colorFilter.index);
    await prefs.setBool('colorCycleActive', _colorCycleActive);
    await prefs.setInt('colorCycleInterval', _colorCycleInterval);
  }

  void _navigateColors(int direction, {bool fromCycle = false}) {
    if (!fromCycle && _colorCycleActive) {
      setState(() {
        _colorCycleActive = false;
      });
    }
    _colorCycleCueCounter = 0;

    final filteredColors = _getFilteredColors();
    if (filteredColors.isEmpty) return;
    final currentPalette = _selectedColorIndex >= 0 &&
            _selectedColorIndex < ColorPalette.presets.length
        ? ColorPalette.presets[_selectedColorIndex]
        : null;
    int filteredIndex =
        currentPalette != null ? filteredColors.indexOf(currentPalette) : 0;
    if (filteredIndex == -1) filteredIndex = 0;

    filteredIndex = (filteredIndex + direction) % filteredColors.length;

    final newPalette = filteredColors[filteredIndex];
    final actualIndex = ColorPalette.presets.indexOf(newPalette);
    setState(() {
      _selectedColorIndex = actualIndex;
    });
    _applyColorPalette(newPalette);
    _scrollToSelectedColor();
  }

  void _navigateLuts(int direction) {
    final filteredLuts = _getFilteredLuts();
    if (filteredLuts.isEmpty) return;
    final currentLut =
        _selectedLutIndex >= 0 && _selectedLutIndex < _availableLuts.length
            ? _availableLuts[_selectedLutIndex]
            : null;
    int filteredIndex =
        currentLut != null ? filteredLuts.indexOf(currentLut) : 0;
    if (filteredIndex == -1) filteredIndex = 0;
    filteredIndex =
        (filteredIndex + direction).clamp(0, filteredLuts.length - 1);
    final newLut = filteredLuts[filteredIndex];
    final actualIndex = _availableLuts.indexOf(newLut);
    setState(() {
      _selectedLutIndex = actualIndex;
    });
    _selectLut(newLut.path, newLut.name.replaceAll('.cube', ''));
    _scrollToSelectedLut();
  }

  void _scrollToSelectedLut() {
    if (_selectedLutIndex < 0) return;
    final filteredLuts = _getFilteredLuts();
    if (_selectedLutIndex >= _availableLuts.length) return;
    final currentLut = _availableLuts[_selectedLutIndex];
    final filteredIndex = filteredLuts.indexOf(currentLut);
    if (filteredIndex == -1) return;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_lutItemScrollController.isAttached) {
        _lutItemScrollController.scrollTo(
          index: filteredIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          if (_lutItemScrollController.isAttached) {
            _lutItemScrollController.jumpTo(
                index: filteredIndex, alignment: 0.1);
          }
        });
      }
    });
  }

  void _scrollToSelectedColor() {
    if (_selectedColorIndex < 0 ||
        _selectedColorIndex >= ColorPalette.presets.length) return;
    final filteredColors = _getFilteredColors();
    final currentPalette = ColorPalette.presets[_selectedColorIndex];
    final filteredIndex = filteredColors.indexOf(currentPalette);
    if (filteredIndex == -1) return;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (_colorItemScrollController.isAttached) {
        _colorItemScrollController.scrollTo(
          index: filteredIndex,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      } else {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          if (_colorItemScrollController.isAttached) {
            _colorItemScrollController.jumpTo(
              index: filteredIndex,
              alignment: 0.1,
            );
          }
        });
      }
    });
  }

  List<QuranIndexEntry> _getFilteredQuranEntries() {
    if (_quranSearchQuery.isEmpty && _quranExcludeQuery.isEmpty)
      return _quranEntries;
    final result = <QuranIndexEntry>[];
    String? currentMainTopic;
    bool currentMainMatches = false;
    for (final entry in _quranEntries) {
      if (!entry.isSubtopic) {
        currentMainTopic = entry.topic;
        final topicLower = entry.topic.toLowerCase();
        currentMainMatches = (_quranSearchQuery.isEmpty ||
                topicLower.contains(_quranSearchQuery)) &&
            (_quranExcludeQuery.isEmpty ||
                !topicLower.contains(_quranExcludeQuery));
        if (currentMainMatches) result.add(entry);
      } else {
        final topicLower = entry.topic.toLowerCase();
        final subtopicMatches = (_quranSearchQuery.isEmpty ||
                topicLower.contains(_quranSearchQuery)) &&
            (_quranExcludeQuery.isEmpty ||
                !topicLower.contains(_quranExcludeQuery));
        if (currentMainMatches) {
          result.add(entry);
        } else if (subtopicMatches) {
          if (!result
              .any((e) => !e.isSubtopic && e.topic == currentMainTopic)) {
            final parentEntry = _quranEntries.firstWhere(
              (e) => !e.isSubtopic && e.topic == currentMainTopic,
              orElse: () => entry,
            );
            result.add(parentEntry);
          }
          result.add(entry);
        }
      }
    }
    return result;
  }

  void _scrollToActiveQuranRef() {
    if (_activeQuranRef == null) return;
    if (_activeQuranFilteredIndex == null) return;

    final activeIndex = _activeQuranFilteredIndex!;

    void doScroll() {
      if (!mounted) return;
      if (_quranItemScrollController.isAttached) {
        _quranItemScrollController.scrollTo(
          index: activeIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    }

    Future.delayed(const Duration(milliseconds: 300), () => doScroll());
    // Future.delayed(const Duration(milliseconds: 500), () => doScroll());
    // Future.delayed(const Duration(milliseconds: 1000), () => doScroll());
    // Future.delayed(const Duration(milliseconds: 2000), () => doScroll());
  }

  Widget _buildPlayer() {
    if (_isVideoFile && !Platform.isAndroid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_vttShowActive)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    path.basename(_currentAudiobook!.path),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_currentAudiobook!.chapters.isNotEmpty)
                    Text(
                      '-${_formatChapterRemaining(_getChapterRemainingTime())}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  if (_currentAudiobook!.chapters.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        children: [
                          TextSpan(
                            text: _hideChapterTitle
                                ? '↳ ${_currentChapterIndex + 1}/${_currentAudiobook!.chapters.length}'
                                : '↳ ${_currentChapterIndex + 1}/${_currentAudiobook!.chapters.length}',
                          ),
                          if (!_hideChapterTitle)
                            TextSpan(
                              text:
                                  ': ${_currentAudiobook!.chapters[_currentChapterIndex].title}',
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Video(
                    controller: _videoController,
                    fit: BoxFit.contain,
                    controls: NoVideoControls,
                  ),
                  if (_secondarySubtitleText.isNotEmpty)
                    Positioned(
                      bottom: 80,
                      left: 32,
                      right: 32,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Stack(
                            children: [
                              if (_secondaryColorPalette?.strokeColor != null)
                                Transform.translate(
                                  offset: Offset(_universalShadowOffset,
                                      _universalShadowOffset),
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: _buildColoredTextSpan(
                                        _secondarySubtitleText,
                                        fontSize: _secondarySubtitleFontSize,
                                        fontFamily: _secondarySubtitleFont,
                                        palette: _secondaryColorPalette,
                                        lineSpacing:
                                            _secondarySubtitleLineSpacing,
                                        isStroke: true,
                                        useShadowColor: true,
                                        fontColorOverrideParam:
                                            _secondaryFontColorOverride),
                                  ),
                                ),
                              RichText(
                                textAlign: TextAlign.center,
                                text: _buildColoredTextSpan(
                                    _secondarySubtitleText,
                                    fontSize: _secondarySubtitleFontSize,
                                    fontFamily: _secondarySubtitleFont,
                                    palette: _secondaryColorPalette,
                                    lineSpacing: _secondarySubtitleLineSpacing,
                                    isStroke: false,
                                    useBlurShadow: _secondaryBlurShadowEnabled,
                                    fontColorOverrideParam:
                                        _secondaryFontColorOverride),
                              ),
                              if (_secondaryColorPalette?.strokeColor != null)
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: _buildColoredTextSpan(
                                      _secondarySubtitleText,
                                      fontSize: _secondarySubtitleFontSize,
                                      fontFamily: _secondarySubtitleFont,
                                      palette: _secondaryColorPalette,
                                      lineSpacing:
                                          _secondarySubtitleLineSpacing,
                                      isStroke: true,
                                      fontColorOverrideParam:
                                          _secondaryFontColorOverride),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_currentSubtitleText.isNotEmpty)
                    Positioned(
                      bottom: 16,
                      left: 32,
                      right: 32,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Stack(
                            children: [
                              Transform.translate(
                                offset: Offset(_universalShadowOffset,
                                    _universalShadowOffset),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: _buildColoredTextSpan(
                                      _vttShowDisplayText,
                                      lineSpacing: _subtitleLineSpacing,
                                      isStroke: true,
                                      useShadowColor: true),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(_universalShadowOffset,
                                    _universalShadowOffset),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: _buildColoredTextSpan(
                                      _vttShowDisplayText,
                                      lineSpacing: _subtitleLineSpacing,
                                      isStroke: false,
                                      useShadowColor: true),
                                ),
                              ),
                              RichText(
                                textAlign: TextAlign.center,
                                text: _buildColoredTextSpan(_vttShowDisplayText,
                                    lineSpacing: _subtitleLineSpacing,
                                    isStroke: false,
                                    useBlurShadow: _blurShadowEnabled),
                              ),
                              RichText(
                                textAlign: TextAlign.center,
                                text: _buildColoredTextSpan(_vttShowDisplayText,
                                    lineSpacing: _subtitleLineSpacing,
                                    isStroke: true),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_isVideoFile) _buildBlurOverlay(constraints),
                ],
              ),
            ),
          ),
          PlayerControls(
            hideTitle: _vttShowActive ? true : _hideChapterTitle,
            audiobook: _currentAudiobook ??
                AudiobookMetadata(
                  path: '',
                  title: _youtubeTitle ?? 'YouTube Audio',
                  author: _youtubeChannelName ?? 'Unknown',
                  year: '',
                  duration: Duration.zero,
                  chapters: [],
                ),
            youtubePlaylistCurrentIndex: _youtubePlaylistCurrentIndex,
            youtubePlaylistTotal: _youtubePlaylistTotal,
            currentChapterIndex: _currentChapterIndex,
            currentPosition: _currentPosition,
            totalDuration: _totalDuration,
            isPlaying: _isPlaying,
            playbackSpeed: _playbackSpeed,
            videoResolution: _videoResolution,
            videoFps: _videoFps,
            fileSize: _fileSize,
            averageBitrate: _averageBitrate,
            shuffleEnabled: _shuffleEnabled,
            conversionType: _displayConversionType,
            currentAudioFormat: _currentAudioFormat,
            playedChapters: _isYouTubeStream
                ? []
                : _currentAudiobook?.chapters
                        .where((c) => _playedChapters
                            .contains(_currentAudiobook!.chapters.indexOf(c)))
                        .toList() ??
                    [],
            selectedFont: _selectedFont,
            defaultFont: _defaultFont,
            defaultConversionType: _defaultConversionType,
            defaultColorPalette: _defaultColorPalette,
            currentColorPalette: _currentColorPalette,
            currentSubtitleText: _vttShowDisplayText,
            subtitleFontSize: _subtitleFontSize,
            subtitleLineSpacing: _subtitleLineSpacing,
            secondarySubtitleText: _secondarySubtitleText,
            secondarySubtitleFontSize: _secondarySubtitleFontSize,
            secondarySubtitleFont: _secondarySubtitleFont,
            secondaryColorPalette: _secondaryColorPalette,
            secondarySubtitleLineSpacing: _secondarySubtitleLineSpacing,
            sleepDuration: _sleepDuration,
            sleepTimerAction: _sleepTimerAction,
            onSetSleepTimerAction: (action) {
              setState(() {
                _sleepTimerAction = action;
              });
              _saveDefaultSettings();
            },
            sliderHoverPosition: _sliderHoverPosition,
            hoveredChapterTitle: _hoveredChapterTitle,
            pauseMode: _pauseMode,
            onTogglePlayPause: _togglePlayPause,
            onPreviousChapter: _previousChapter,
            onNextChapter: _nextChapter,
            onSkipBackward: _skipBackward,
            onSkipForward: _skipForward,
            skipToPreviousSubtitle: _skipToPreviousSubtitle,
            skipToNextSubtitle: _skipToNextSubtitle,
            onIncreaseSpeed: _increaseSpeed,
            onDecreaseSpeed: _decreaseSpeed,
            onToggleShuffle: _toggleShuffle,
            onAddBookmark: _addBookmark,
            hideChapterTitle: _hideChapterTitle,
            hoveringPrevChapter: _hoveringPrevChapter,
            hoveringNextChapter: _hoveringNextChapter,
            onEditingMenuSelected: _onEditingMenuSelected,
            onTogglePanel: () {
              setState(() {
                _showPanel = !_showPanel;
                _panelMode = PanelMode.chapters;
              });
              if (_showPanel && !_isYouTubeStream) {
                _scrollToCurrentChapter();
              }
            },
            onSetSleepTimer: _setSleepTimer,
            onSeekTo: _seekTo,
            onSliderHover: (position) {
              setState(() {
                _sliderHoverPosition = position;
                _hoveredChapterTitle = '';

                final sliderWidth = MediaQuery.of(context).size.width - 64;
                final totalMillis = _totalDuration.inMilliseconds;
                if (totalMillis > 0 &&
                    _currentAudiobook != null &&
                    _currentAudiobook!.chapters.isNotEmpty) {
                  final hoverTime = Duration(
                      milliseconds:
                          ((position / sliderWidth) * totalMillis).toInt());
                  for (final chapter in _currentAudiobook!.chapters) {
                    if (hoverTime >= chapter.startTime &&
                        hoverTime < chapter.endTime) {
                      _hoveredChapterTitle = chapter.title;
                      break;
                    }
                  }
                  if (_inPoint != null && _isVideoFile) {
                    final cutDuration = hoverTime - _inPoint!;
                    if (cutDuration > Duration.zero) {
                      _hoveredChapterTitle =
                          '${_hoveredChapterTitle?.isNotEmpty == true ? '$_hoveredChapterTitle  ·  ' : ''}cut ${_formatDurationWithMs(cutDuration)}';
                    }
                  }
                }
              });
            },
            onSliderExit: () {
              setState(() {
                _sliderHoverPosition = null;
                _hoveredChapterTitle = null;
              });
            },
            onPrevChapterHover: (hovering) {
              setState(() {
                _hoveringPrevChapter = hovering;
              });
            },
            onNextChapterHover: (hovering) {
              setState(() {
                _hoveringNextChapter = hovering;
              });
            },
            onSettingsMenuSelected: (context, value) {
              switch (value) {
                case 'encoder':
                  setState(() {
                    _showEncoderScreen = true;
                  });
                  break;
                case 'metadata':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MetadataEditorScreen(),
                    ),
                  );
                  break;
                case 'copy_metadata':
                  _copyCurrentMetadata();
                  break;
                case 'copy_chapters':
                  _copyChaptersList();
                  break;
                case 'set_default':
                  _setCurrentAsDefault();
                  break;
                case 'apply_default':
                  _applyDefaultSettings();
                  break;
                case 'open_dir':
                  _openAudiobookDirectory();
                  break;
                case 'load':
                  _openAudiobook();
                  break;
                case 'load_subtitle':
                  _loadSubtitleFromVttDir();
                  break;
                case 'hideChapterTitle':
                  setState(() {
                    _hideChapterTitle = !_hideChapterTitle;
                  });
                  break;
                case 'useBlurShadow':
                  setState(() {
                    _blurShadowEnabled = !_blurShadowEnabled;
                  });
                  break;
                case 'editvttshow':
                  if (_vttShowActive) {
                    setState(() {
                      _vttShowEditMode = !_vttShowEditMode;
                    });
                  }
                  break;
                case 'useBlackFont':
                  setState(() {
                    _fontColorOverride = switch (_fontColorOverride) {
                      FontColorOverride.none => FontColorOverride.black,
                      FontColorOverride.black => FontColorOverride.white,
                      FontColorOverride.white => FontColorOverride.none,
                    };
                  });
                  break;
                case 'copyCurrentSubtitle':
                  _copyCurrentSubtitle();
                  break;
                case 'subtitle_manager':
                  _openSubtitleManager();
                  break;
                case 'fullscreen':
                  _toggleFullscreen();
                  break;
                case 'youtube_dialog':
                  _showYouTubeDialog();
                  break;
                case 'select_audio_stream':
                  if (_isYouTubeStream && _currentYouTubeUrl != null) {
                    _showAudioStreamPicker(_currentYouTubeUrl!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Only available for YouTube streams'),
                      ),
                    );
                  }
                  break;
                case 'adhan_clock':
                  setState(() {
                    _showAdhanOverlay = !_showAdhanOverlay;
                  });
                  break;
              }
            },
            onPauseModeChanged: (mode) {
              setState(() {
                _pauseMode = mode;
                _pauseModeTimer?.cancel();

                if (mode == PauseMode.dictionary) {
                  if (_currentSubtitleIndex != null &&
                      _currentSubtitleIndex! < _subtitles.length) {
                    final cue = _subtitles[_currentSubtitleIndex!];
                    _nextPauseTime =
                        cue.endTime - const Duration(milliseconds: 200);
                  }
                } else {
                  _nextPauseTime = null;
                }
              });
            },
            onOpenSubtitleManager: _openSubtitleManager,
            onJumpToChapter: _jumpToChapter,
            buildColoredTextSpan: _buildColoredTextSpan,
            shadowOffset: _universalShadowOffset,
            blurShadowEnabled: _blurShadowEnabled,
            isVideoFile: _isVideoFile,
            isYouTubeStream: _isYouTubeStream,
            youtubeTitle: _youtubeTitle,
            youtubeChannelName: _youtubeChannelName,
            onShowSubtitlePreferences: _showSubtitlePreferencesDialog,
            onShowDownload: _showDownloadDialog,
            onShowYouTubeDialog: _showYouTubeDialog,
            onDownloadSubtitles: _isYouTubeStream && _currentYouTubeUrl != null
                ? () => _downloadYouTubeSubtitles(
                      _currentYouTubeUrl!,
                      _youtubeTitle ?? '',
                      showPicker: true,
                    )
                : null,
            onShowAudioStreams: _isYouTubeStream && _currentYouTubeUrl != null
                ? () => _showAudioStreamPicker(_currentYouTubeUrl!)
                : null,
            onCloseYouTube: () async {
              await player.stop();
              setState(() {
                _currentAudiobook = null;
                _currentChapterIndex = 0;
                _isYouTubeStream = false;
                _youtubeTitle = null;
                _youtubeChannelName = null;
                _currentYouTubeUrl = null;
                _subtitles = [];
                _originalSubtitles = [];
                _currentSubtitleText = '';
                _currentSubtitleIndex = null;
                _subtitleFilePath = null;
              });
            },
          ),
        ],
      );
    }

    return PlayerControls(
      hideTitle: _vttShowActive ? true : _hideChapterTitle,
      audiobook: _currentAudiobook ??
          AudiobookMetadata(
            path: '',
            title: _youtubeTitle ?? 'YouTube Audio',
            author: _youtubeChannelName ?? 'Unknown',
            year: '',
            duration: Duration.zero,
            chapters: [],
          ),
      youtubePlaylistCurrentIndex: _youtubePlaylistCurrentIndex,
      youtubePlaylistTotal: _youtubePlaylistTotal,
      currentChapterIndex: _currentChapterIndex,
      currentPosition: _currentPosition,
      totalDuration: _totalDuration,
      isPlaying: _isPlaying,
      playbackSpeed: _playbackSpeed,
      fileSize: _fileSize,
      averageBitrate: _averageBitrate,
      shuffleEnabled: _shuffleEnabled,
      conversionType: _displayConversionType,
      currentAudioFormat: _currentAudioFormat,
      playedChapters: _isYouTubeStream
          ? []
          : _currentAudiobook?.chapters
                  .where((c) => _playedChapters
                      .contains(_currentAudiobook!.chapters.indexOf(c)))
                  .toList() ??
              [],
      selectedFont: _selectedFont,
      defaultFont: _defaultFont,
      defaultConversionType: _defaultConversionType,
      defaultColorPalette: _defaultColorPalette,
      currentColorPalette: _currentColorPalette,
      currentSubtitleText: _vttShowDisplayText,
      subtitleFontSize: _subtitleFontSize,
      videoResolution: _videoResolution,
      videoFps: _videoFps,
      subtitleLineSpacing: _subtitleLineSpacing,
      secondarySubtitleText: _secondarySubtitleText,
      secondarySubtitleFontSize: _secondarySubtitleFontSize,
      secondarySubtitleFont: _secondarySubtitleFont,
      secondaryColorPalette: _secondaryColorPalette,
      secondarySubtitleLineSpacing: _secondarySubtitleLineSpacing,
      sleepDuration: _sleepDuration,
      sleepTimerAction: _sleepTimerAction,
      onSetSleepTimerAction: (action) {
        setState(() {
          _sleepTimerAction = action;
        });
        _saveDefaultSettings();
      },
      sliderHoverPosition: _sliderHoverPosition,
      hoveredChapterTitle: _hoveredChapterTitle,
      pauseMode: _pauseMode,
      onTogglePlayPause: _togglePlayPause,
      onPreviousChapter: _previousChapter,
      onNextChapter: _nextChapter,
      onSkipBackward: _skipBackward,
      onSkipForward: _skipForward,
      skipToPreviousSubtitle: _skipToPreviousSubtitle,
      skipToNextSubtitle: _skipToNextSubtitle,
      onIncreaseSpeed: _increaseSpeed,
      onDecreaseSpeed: _decreaseSpeed,
      onToggleShuffle: _toggleShuffle,
      onAddBookmark: _addBookmark,
      hideChapterTitle: _hideChapterTitle,
      hoveringPrevChapter: _hoveringPrevChapter,
      hoveringNextChapter: _hoveringNextChapter,
      onEditingMenuSelected: _onEditingMenuSelected,
      onTogglePanel: () {
        setState(() {
          _showPanel = !_showPanel;
          _panelMode = PanelMode.chapters;
        });
        if (_showPanel && !_isYouTubeStream) {
          _scrollToCurrentChapter();
        }
      },
      onSetSleepTimer: _setSleepTimer,
      onSeekTo: _seekTo,
      onSliderHover: (position) {
        setState(() {
          _sliderHoverPosition = position;
          _hoveredChapterTitle = '';

          final sliderWidth = MediaQuery.of(context).size.width - 64;
          final totalMillis = _totalDuration.inMilliseconds;
          if (totalMillis > 0 &&
              _currentAudiobook != null &&
              _currentAudiobook!.chapters.isNotEmpty) {
            final hoverTime = Duration(
                milliseconds: ((position / sliderWidth) * totalMillis).toInt());
            for (final chapter in _currentAudiobook!.chapters) {
              if (hoverTime >= chapter.startTime &&
                  hoverTime < chapter.endTime) {
                _hoveredChapterTitle = chapter.title;
                break;
              }
            }
          }
        });
      },
      onSliderExit: () {
        setState(() {
          _sliderHoverPosition = null;
          _hoveredChapterTitle = null;
        });
      },
      onPrevChapterHover: (hovering) {
        setState(() {
          _hoveringPrevChapter = hovering;
        });
      },
      onNextChapterHover: (hovering) {
        setState(() {
          _hoveringNextChapter = hovering;
        });
      },
      onSettingsMenuSelected: (context, value) {
        switch (value) {
          case 'encoder':
            setState(() {
              _showEncoderScreen = true;
            });
            break;
          case 'metadata':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MetadataEditorScreen(),
              ),
            );
            break;
          case 'copy_metadata':
            _copyCurrentMetadata();
            break;
          case 'copy_chapters':
            _copyChaptersList();
            break;
          case 'set_default':
            _setCurrentAsDefault();
            break;
          case 'apply_default':
            _applyDefaultSettings();
            break;
          case 'open_dir':
            _openAudiobookDirectory();
            break;
          case 'load':
            _openAudiobook();
            break;
          case 'load_subtitle':
            _loadSubtitleFromVttDir();
            break;
          case 'hideChapterTitle':
            setState(() {
              _hideChapterTitle = !_hideChapterTitle;
            });
            break;
          case 'useBlurShadow':
            setState(() {
              _blurShadowEnabled = !_blurShadowEnabled;
            });
            break;
          case 'editvttshow':
            if (_vttShowActive) {
              setState(() {
                _vttShowEditMode = !_vttShowEditMode;
              });
            }
            break;
          case 'useBlackFont':
            setState(() {
              _fontColorOverride = switch (_fontColorOverride) {
                FontColorOverride.none => FontColorOverride.black,
                FontColorOverride.black => FontColorOverride.white,
                FontColorOverride.white => FontColorOverride.none,
              };
            });
            break;
          case 'copyCurrentSubtitle':
            _copyCurrentSubtitle();
            break;
          case 'subtitle_manager':
            _openSubtitleManager();
            break;
          case 'fullscreen':
            _toggleFullscreen();
            break;
          case 'youtube_dialog':
            _showYouTubeDialog();
            break;
          case 'select_audio_stream':
            if (_isYouTubeStream && _currentYouTubeUrl != null) {
              _showAudioStreamPicker(_currentYouTubeUrl!);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Only available for YouTube streams'),
                ),
              );
            }
            break;
          case 'adhan_clock':
            setState(() {
              _showAdhanOverlay = !_showAdhanOverlay;
            });
            break;
        }
      },
      onPauseModeChanged: (mode) {
        setState(() {
          _pauseMode = mode;
          _pauseModeTimer?.cancel();

          if (mode == PauseMode.dictionary) {
            if (_currentSubtitleIndex != null &&
                _currentSubtitleIndex! < _subtitles.length) {
              final cue = _subtitles[_currentSubtitleIndex!];
              _nextPauseTime = cue.endTime - const Duration(milliseconds: 200);
            }
          } else {
            _nextPauseTime = null;
          }
        });
      },
      onOpenSubtitleManager: _openSubtitleManager,
      onJumpToChapter: _jumpToChapter,
      buildColoredTextSpan: _buildColoredTextSpan,
      shadowOffset: _universalShadowOffset,
      blurShadowEnabled: _blurShadowEnabled,
      isVideoFile: _isVideoFile,
      isYouTubeStream: _isYouTubeStream,
      youtubeTitle: _youtubeTitle,
      youtubeChannelName: _youtubeChannelName,
      onShowSubtitlePreferences: _showSubtitlePreferencesDialog,
      onShowDownload: _showDownloadDialog,
      onShowYouTubeDialog: _showYouTubeDialog,
      onDownloadSubtitles: _isYouTubeStream && _currentYouTubeUrl != null
          ? () => _downloadYouTubeSubtitles(
                _currentYouTubeUrl!,
                _youtubeTitle ?? '',
                showPicker: true,
              )
          : null,
      onShowAudioStreams: _isYouTubeStream && _currentYouTubeUrl != null
          ? () => _showAudioStreamPicker(_currentYouTubeUrl!)
          : null,
      onCloseYouTube: () async {
        await player.stop();
        setState(() {
          _currentAudiobook = null;
          _currentChapterIndex = 0;
          _isYouTubeStream = false;
          _youtubeTitle = null;
          _youtubeChannelName = null;
          _currentYouTubeUrl = null;
          _subtitles = [];
          _originalSubtitles = [];
          _currentSubtitleText = '';
          _currentSubtitleIndex = null;
          _subtitleFilePath = null;
        });
      },
    );
  }

  String _formatChapterRemaining(Duration d) {
    const ltrEmbed = '\u202A';
    const popDir = '\u202C';

    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      final seconds = d.inSeconds.remainder(60);
      final timeString =
          '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      return '$ltrEmbed$timeString$popDir';
    } else {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds.remainder(60);
      final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';
      return '$ltrEmbed$timeString$popDir';
    }
  }

  Duration _getChapterRemainingTime() {
    if (_currentAudiobook == null || _currentAudiobook!.chapters.isEmpty) {
      return Duration.zero;
    }

    final chapter = _currentAudiobook!.chapters[_currentChapterIndex];
    final remaining = chapter.endTime - _currentPosition;

    return Duration(
        milliseconds: (remaining.inMilliseconds / _playbackSpeed).round());
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadOverlay(
        youtubeUrl: _isYouTubeStream ? _currentYouTubeUrl : null,
      ),
    );
  }

  Future<void> _resetConversion() async {
    setState(() {
      _conversionType = 'none';
    });
    await _applyConversion();
    await _saveFontSettings();
  }

  Future<void> _copyCurrentSubtitle() async {
    if (_currentSubtitleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitle to copy'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    String textToCopy = _currentSubtitleText;
    if (_currentSubtitleIndex != null &&
        _currentSubtitleIndex! < _subtitles.length) {
      final currentCue = _subtitles[_currentSubtitleIndex!];
      final originalCue = _originalSubtitles
          .where((c) => c.startTime == currentCue.startTime)
          .firstOrNull;
      textToCopy = originalCue?.text ?? currentCue.text;
    }

    await Clipboard.setData(ClipboardData(text: textToCopy));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _copySecondarySubtitle() async {
    if (_secondarySubtitleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No secondary subtitle to copy'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    String textToCopy = _secondarySubtitleText;
    if (_currentSecondarySubtitleIndex != null &&
        _currentSecondarySubtitleIndex! < _secondaryOriginalSubtitles.length) {
      textToCopy =
          _secondaryOriginalSubtitles[_currentSecondarySubtitleIndex!].text;
    }

    await Clipboard.setData(ClipboardData(text: textToCopy));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secondary subtitle copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _copyCurrentSubtitleInMemory() async {
    if (_currentSubtitleText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitle to copy'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    String textToCopy = _currentSubtitleText;
    if (_currentSubtitleIndex != null &&
        _currentSubtitleIndex! < _subtitles.length) {
      textToCopy = _subtitles[_currentSubtitleIndex!].text;
    }

    await Clipboard.setData(ClipboardData(text: textToCopy));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('In-memory subtitle copied to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _copyCurrentMetadata() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }
    try {
      await _ffmpeg.ensureBinaries();
      if (_ffmpeg.ffprobePath == null) {
        throw Exception('ffprobe not found');
      }

      final process = await Process.start(
        _ffmpeg.ffprobePath!,
        [_currentAudiobook!.path],
      );

      final stderrBytes = <int>[];
      await for (final chunk in process.stderr) {
        stderrBytes.addAll(chunk);
      }
      await process.stdout.drain();
      await process.exitCode;

      String output;
      try {
        output = utf8.decode(stderrBytes);
      } catch (_) {
        output = latin1.decode(stderrBytes);
      }

      String artist = 'Unknown Artist';
      String album = 'Unknown Album';
      String title = 'Unknown Title';
      String year = 'Unknown Year';
      final lines = output.split('\n');
      bool inMetadata = false;
      bool isAttachedPic = false;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.contains('(attached pic)')) {
          isAttachedPic = true;
          continue;
        }
        if (trimmed.startsWith('Stream #')) {
          isAttachedPic = false;
          inMetadata = false;
          continue;
        }
        if (trimmed.startsWith('Metadata:')) {
          inMetadata = true;
          continue;
        }
        if (inMetadata && !isAttachedPic && trimmed.contains(':')) {
          final parts = trimmed.split(':');
          if (parts.length >= 2) {
            final key = parts[0].trim().toLowerCase();
            final value = parts.sublist(1).join(':').trim();
            if (value.isEmpty) continue;
            if (key == 'artist') {
              artist = value;
            } else if (key == 'album') {
              album = value;
            } else if (key == 'title' && value != 'Front Cover') {
              title = value;
            } else if (key == 'year') {
              year = value;
            } else if (key == 'date' && year == 'Unknown Year') {
              final rangeMatch = RegExp(r'^\d{4}-\d{4}').firstMatch(value);
              if (rangeMatch != null) {
                year = rangeMatch.group(0)!;
              } else {
                final yearMatch = RegExp(r'^\d{4}').firstMatch(value);
                if (yearMatch != null) {
                  year = yearMatch.group(0)!;
                }
              }
            }
          }
        }
      }
      final finalTitle = album != 'Unknown Album' ? album : title;
      final file = File(_currentAudiobook!.path);
      final fileSize = await file.length();
      final formattedFileSize = _formatFileSize(fileSize);
      final duration = _totalDuration;
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      String formattedDuration;
      if (hours > 0) {
        formattedDuration = '${hours}h ${minutes}m';
      } else if (minutes > 0) {
        formattedDuration = '${minutes}m';
      } else {
        final seconds = duration.inSeconds.remainder(60);
        formattedDuration = '${seconds}s';
      }
      const ltr = '\u200E';
      final clipboardText =
          '$artist - $finalTitle ($year) $ltr$formattedFileSize $formattedDuration';
      await Clipboard.setData(ClipboardData(text: clipboardText));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied to clipboard:\n$clipboardText'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy metadata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyChaptersList() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }

    final chapters = _currentAudiobook!.chapters
        .map((chapter) => '${chapter.title}\n')
        .join('\n');

    await Clipboard.setData(ClipboardData(text: chapters));

    try {
      final audiobookPath = _currentAudiobook!.path;
      final dir = path.dirname(audiobookPath);
      final baseName = path.basenameWithoutExtension(audiobookPath);
      final chaptersPath = path.join(dir, '${baseName}_chapters.txt');

      await File(chaptersPath).writeAsString(chapters);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Copied ${_currentAudiobook!.chapters.length} chapter titles to clipboard\n'
                'Saved to: ${path.basename(chaptersPath)}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied to clipboard but failed to save file: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _convertToDemo() async {
    if (_subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load subtitles first')),
      );
      return;
    }

    setState(() {
      _conversionType = 'demo';
    });

    await _applyConversion();
    await _saveFontSettings();
  }

  Future<void> _convertToDemoUpper() async {
    if (_subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load subtitles first')),
      );
      return;
    }

    setState(() {
      _conversionType = 'demoUpper';
    });

    await _applyConversion();
    await _saveFontSettings();
  }

  Future<void> _convertToAlternates({bool fromVttShow = false}) async {
    if (_subtitleFilePath == null) {
      if (!fromVttShow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Load subtitles first')),
        );
      }
      return;
    }
    if (!fromVttShow && !FontAlternatesData.hasFontAlternates(_selectedFont)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No alternates defined for $_selectedFont')),
      );
      return;
    }
    setState(() {
      _conversionType = 'alternates';
    });
    await _applyConversion();
    if (!fromVttShow) await _saveFontSettings();
  }

  Future<void> _convertToMissing({bool fromVttShow = false}) async {
    if (_subtitleFilePath == null) {
      if (!fromVttShow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Load subtitles first')),
        );
      }
      return;
    }
    final metadata = FontDatabase.getMetadata(_selectedFont);
    if (!fromVttShow && (metadata == null || !metadata.hasMissingLigatures())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('$_selectedFont does not have missing ligature data')),
      );
      return;
    }
    setState(() {
      _conversionType = 'missing';
    });
    await _applyConversion();
    if (!fromVttShow) await _saveFontSettings();
  }

  Future<void> _convertToUppercase() async {
    if (_subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load subtitles first')),
      );
      return;
    }

    setState(() {
      _conversionType = 'uppercase';
    });

    await _applyConversion();
    await _saveFontSettings();
  }

  Future<void> _convertToSeesawCase() async {
    if (_subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load subtitles first')),
      );
      return;
    }

    setState(() {
      _conversionType = 'seesawcase';
    });

    await _applyConversion();
    await _saveFontSettings();
  }

  String _getDisplayConversionType() {
    if (_selectedMainCategory == FontCategory.favorites) {
      final metadata = FontDatabase.getMetadata(_selectedFont);
      if (metadata != null && metadata.subCategories.isNotEmpty) {
        return metadata.subCategories.first;
      }
      return 'favorite';
    }
    return _conversionType == 'none' ? 'original' : _conversionType;
  }

  int _conversionCallCount = 0;

  Future<void> _applyConversion() async {
    _conversionCallCount++;
    final callId = _conversionCallCount;

    if (_subtitleFilePath == null) {
      return;
    }
    if (_isDisposed || !mounted) {
      return;
    }

    try {
      final rawContent = await File(_subtitleFilePath!).readAsString();

      String content;
      String vttShowSection = '';
      final vttShowMarker = rawContent.indexOf('\nVTTSHOW');
      if (vttShowMarker != -1) {
        content = rawContent.substring(0, vttShowMarker);
        vttShowSection = rawContent.substring(vttShowMarker);
      } else {
        content = rawContent;
      }
      if (_isDisposed || !mounted) return;

      String convertedContent = content;

      switch (_conversionType) {
        case 'demo':
          convertedContent = await SubtitleTransformer.convertToDemoInMemory(
              content, _selectedFont);
          break;
        case 'demoUpper':
          convertedContent =
              await SubtitleTransformer.convertToDemoUpperInMemory(
                  content, _selectedFont);
          break;
        case 'alternates':
          convertedContent =
              await SubtitleTransformer.convertToAlternatesInMemory(
                  content, _selectedFont);
          break;
        case 'missing':
          convertedContent =
              await SubtitleTransformer.fixMissingLigaturesInMemory(
                  content, _selectedFont);
          break;
        case 'uppercase':
          convertedContent =
              SubtitleTransformer.convertToUppercaseInMemory(content);
          break;
        case 'seesawcase':
          convertedContent =
              SubtitleTransformer.convertToSeesawCaseInMemory(content);
          break;
        case 'none':
        default:
          convertedContent = content;
          break;
      }

      if (_isDisposed || !mounted) return;

      final finalContent = vttShowSection.isNotEmpty
          ? convertedContent + vttShowSection
          : convertedContent;
      final subtitles = _parseVTT(finalContent);

      if (_isDisposed || !mounted) return;

      setState(() {
        _subtitles = subtitles;
        if (_currentSubtitleIndex != null &&
            _currentSubtitleIndex! < _subtitles.length) {
          _currentSubtitleText = _subtitles[_currentSubtitleIndex!].text;
        }
      });

      _updateCurrentSubtitle();

      if (!_isPlaying &&
          _currentSubtitleIndex != null &&
          _currentSubtitleIndex! > 0) {
        final savedPosition = _currentPosition;

        await _skipToPreviousSubtitle();
        if (_isDisposed || !mounted) return;

        await Future.delayed(const Duration(milliseconds: 150));
        if (_isDisposed || !mounted) return;

        await player.seek(savedPosition);
        if (_isDisposed || !mounted) return;

        setState(() {
          _currentPosition = savedPosition;
        });
        _updateCurrentSubtitle();
        _updateWakelock();
      }

      _scheduleFrequencyGeneration();

      if (mounted && !_isDisposed && _conversionType != 'none') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied $_conversionType conversion'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('=== _applyConversion #$callId ERROR: $e ===');
      print('Error applying conversion: $e');
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply conversion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFullscreen() async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final isFullscreen = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFullscreen);
    }
  }

  Color _applyLutToColor(Color color) {
    if (_loadedLutData == null) return color;
    try {
      final r = (color.r * 255.0).round().clamp(0, 255);
      final g = (color.g * 255.0).round().clamp(0, 255);
      final b = (color.b * 255.0).round().clamp(0, 255);
      final imgColor = img.ColorRgb8(r, g, b);
      final transformed = LutProcessor.lookupLut(imgColor, _loadedLutData!);
      return Color.fromARGB(255, transformed.r.toInt(), transformed.g.toInt(),
          transformed.b.toInt());
    } catch (e) {
      print('Error applying LUT: $e');
      return color;
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    final baseColor = Color(int.parse('FF$hex', radix: 16));
    return _applyLutToColor(baseColor);
  }

  Future<void> _applyColorPalette(ColorPalette palette) async {
    setState(() {
      _currentColorPalette = palette;
    });
    await _saveFontSettings();
  }

  bool _shouldSkipChapter(String chapterTitle) {
    if (_skipChapterTerms.isEmpty) return false;
    final terms = _skipChapterTerms
        .toLowerCase()
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
    final lowerTitle = chapterTitle.toLowerCase();
    return terms.any((term) => lowerTitle.contains(term));
  }

  Future<void> _saveSkipChapterTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skipChapterTerms', _skipChapterTerms);
  }

  Future<void> _loadSkipChapterTerms() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTerms = prefs.getString('skipChapterTerms');
    setState(() {
      if (savedTerms != null) {
        _skipChapterTerms = savedTerms;
        _skipChapterController.text = savedTerms;
      } else {
        _skipChapterTerms = '';
        _skipChapterController.text = '';
      }
    });
  }

  Future<Map<String, dynamic>> _getHistoryDurationAndProgress(
      String filePath, Duration lastPosition) async {
    if (!await File(filePath).exists()) {
      return {'duration': '', 'progress': ''};
    }

    if (_playlistDurationCache.containsKey(filePath)) {
      final durationStr = _playlistDurationCache[filePath]!;
      final progress = await _calculateProgress(filePath, lastPosition);
      return {'duration': durationStr, 'progress': progress};
    }

    return {'duration': '', 'progress': ''};
  }

  Future<String> _calculateProgress(
      String filePath, Duration lastPosition) async {
    Duration? totalDuration;
    if (_playlistDurationCache.containsKey(filePath)) {
      final cached = _playlistDurationCache[filePath]!;
      final parts = cached.replaceAll('h', '').replaceAll('m', '').split(' ');
      if (parts.length == 2) {
        final hours = int.tryParse(parts[0].trim()) ?? 0;
        final minutes = int.tryParse(parts[1].trim()) ?? 0;
        totalDuration = Duration(hours: hours, minutes: minutes);
      } else if (parts.length == 1) {
        final minutes = int.tryParse(parts[0].trim()) ?? 0;
        totalDuration = Duration(minutes: minutes);
      }
    }

    if (totalDuration != null && totalDuration.inSeconds > 0) {
      final percentage =
          (lastPosition.inSeconds / totalDuration.inSeconds) * 100;
      return '${percentage.toStringAsFixed(1)}%';
    }

    return '';
  }

  Future<String> _getAudiobookDuration(String filePath) async {
    if (!await File(filePath).exists()) {
      return '';
    }

    if (_playlistDurationCache.containsKey(filePath)) {
      return _playlistDurationCache[filePath]!;
    }

    return '';
  }

  Future<void> _setPinNumber(int displayIndex, int? pinNumber) async {
    final filteredBookmarks = _getFilteredBookmarks();

    if (displayIndex >= filteredBookmarks.length) return;

    final targetBookmark = filteredBookmarks[displayIndex];

    final actualIndex = _bookmarks.indexWhere((b) =>
        b.audiobookPath == targetBookmark.audiobookPath &&
        b.chapterIndex == targetBookmark.chapterIndex &&
        b.position == targetBookmark.position &&
        b.created == targetBookmark.created);

    if (actualIndex == -1) return;

    setState(() {
      if (pinNumber != null) {
        for (int i = 0; i < _bookmarks.length; i++) {
          if (i != actualIndex && _bookmarks[i].pinNumber == pinNumber) {
            _bookmarks[i] = _bookmarks[i].copyWith(clearPin: true);
          }
        }
      }

      if (pinNumber == null) {
        _bookmarks[actualIndex] =
            _bookmarks[actualIndex].copyWith(clearPin: true);
      } else {
        _bookmarks[actualIndex] =
            _bookmarks[actualIndex].copyWith(pinNumber: pinNumber);
      }
    });

    await _saveBookmarks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pinNumber == null
              ? 'Bookmark unpinned: ${targetBookmark.chapterTitle}'
              : 'Bookmark pinned to $pinNumber: ${targetBookmark.chapterTitle}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _jumpToPinnedBookmark(int pinNumber) async {
    final bookmark = _bookmarks.firstWhere(
      (b) => b.pinNumber == pinNumber,
      orElse: () => _bookmarks.first,
    );
    if (bookmark.pinNumber == pinNumber) {
      await _jumpToBookmark(bookmark);
    }
  }

  Future<void> _skipToPreviousSubtitle() async {
    if (_vttShowActive) _vttShowCaptureIfChanged();
    if (_subtitles.isEmpty) return;

    int currentIndex = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].startTime <= _currentPosition &&
          (i == _subtitles.length - 1 ||
              _subtitles[i + 1].startTime > _currentPosition)) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex > 0) {
      final seekPosition = _subtitles[currentIndex - 1].startTime +
          const Duration(milliseconds: 10);
      await _seekTo(seekPosition);
    } else if (currentIndex == 0) {
      final seekPosition =
          _subtitles[0].startTime + const Duration(milliseconds: 10);
      await _seekTo(seekPosition);
    }
  }

  Future<void> _skipToNextSubtitle() async {
    if (_vttShowActive) _vttShowCaptureIfChanged();
    if (_subtitles.isEmpty) return;

    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].startTime >
          _currentPosition + const Duration(milliseconds: 10)) {
        final seekPosition =
            _subtitles[i].startTime + const Duration(milliseconds: 10);
        await _seekTo(seekPosition);
        return;
      }
    }
  }

  Future<void> _seekToSubtitleEnd() async {
    if (_subtitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitles available'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int currentIndex = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].startTime <= _currentPosition &&
          (i == _subtitles.length - 1 ||
              _subtitles[i + 1].startTime > _currentPosition)) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No current subtitle found'),
          duration: Duration(seconds: 1),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final subtitleEndTime = _subtitles[currentIndex].endTime;

    final replayStart = subtitleEndTime - const Duration(milliseconds: 900);
    final safeReplayStart =
        replayStart < Duration.zero ? Duration.zero : replayStart;

    await player.seek(safeReplayStart);
    await player.play();

    Timer(const Duration(milliseconds: 900), () async {
      await player.pause();
      await player.seek(subtitleEndTime);
    });
  }

  void _handleBlurCycle() {
    if (_blurDrawMode) return;

    if (_blurRegions.isEmpty) {
      setState(() => _blurDrawMode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draw blur region — click to starting point'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.deepPurple,
        ),
      );
    } else if (_blurRegions.length == 1) {
      setState(() => _blurDrawMode = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Draw second blur region — or press - again to clear all'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.deepPurple,
        ),
      );
    } else {
      setState(() {
        _blurRegions = [];
        _blurDrawMode = false;
        _blurDragStart = null;
        _blurDragCurrent = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blur regions cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildBlurOverlay(BoxConstraints constraints) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;

    return Stack(
      children: [
        for (final region in _blurRegions)
          Positioned(
            left: region.x * w,
            top: region.y * h,
            width: region.width * w,
            height: region.height * h,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withAlpha(204),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_blurDrawMode && _blurDragStart != null && _blurDragCurrent != null)
          () {
            final x = min(_blurDragStart!.dx, _blurDragCurrent!.dx);
            final y = min(_blurDragStart!.dy, _blurDragCurrent!.dy);
            final rw = (_blurDragCurrent!.dx - _blurDragStart!.dx).abs();
            final rh = (_blurDragCurrent!.dy - _blurDragStart!.dy).abs();
            return Positioned(
              left: x * w,
              top: y * h,
              width: rw * w,
              height: rh * h,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(13),
                      border: Border.all(
                        color: Colors.greenAccent.withAlpha(230),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }(),
        if (_trackedCoords.isNotEmpty &&
            _trackedBlurStart != null &&
            _trackedBlurEnd != null)
          () {
            final x = min(_trackedBlurStart!.dx, _trackedBlurEnd!.dx);
            final y = min(_trackedBlurStart!.dy, _trackedBlurEnd!.dy);
            final rw = (_trackedBlurEnd!.dx - _trackedBlurStart!.dx).abs();
            final rh = (_trackedBlurEnd!.dy - _trackedBlurStart!.dy).abs();
            return Positioned(
              left: x * w,
              top: y * h,
              width: rw * w,
              height: rh * h,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(13),
                      border: Border.all(
                        color: Colors.orangeAccent.withAlpha(204),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }(),
        if (_trackedBlurStart != null &&
            _trackedBlurEnd != null &&
            !_isDefiningTrackedBlur)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () =>
                  setState(() => _trackedBlurInverted = !_trackedBlurInverted),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _trackedBlurInverted ? Colors.orange : Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orangeAccent),
                ),
                child: Text(
                  _trackedBlurInverted ? 'Invert mode ✓' : 'Invert mode',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        if (_isDefiningTrackedBlur &&
            _trackedBlurStart != null &&
            _trackedBlurEnd != null)
          () {
            final x = min(_trackedBlurStart!.dx, _trackedBlurEnd!.dx);
            final y = min(_trackedBlurStart!.dy, _trackedBlurEnd!.dy);
            final rw = (_trackedBlurEnd!.dx - _trackedBlurStart!.dx).abs();
            final rh = (_trackedBlurEnd!.dy - _trackedBlurStart!.dy).abs();
            return Positioned(
              left: x * w,
              top: y * h,
              width: rw * w,
              height: rh * h,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  border: Border.all(
                    color: Colors.orangeAccent.withAlpha(230),
                    width: 1.5,
                  ),
                ),
              ),
            );
          }(),
        if (_blurDrawMode)
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (event) {
                if (_blurDragStart != null) {
                  setState(() {
                    _blurDragCurrent = Offset(
                      (event.localPosition.dx / w).clamp(0.0, 1.0),
                      (event.localPosition.dy / h).clamp(0.0, 1.0),
                    );
                  });
                }
              },
              child: GestureDetector(
                onTapDown: (d) {
                  final pos = Offset(
                    (d.localPosition.dx / w).clamp(0.0, 1.0),
                    (d.localPosition.dy / h).clamp(0.0, 1.0),
                  );
                  if (_blurDragStart == null) {
                    setState(() {
                      _blurDragStart = pos;
                      _blurDragCurrent = pos;
                    });
                  } else {
                    final x = min(_blurDragStart!.dx, _blurDragCurrent!.dx);
                    final y = min(_blurDragStart!.dy, _blurDragCurrent!.dy);
                    final rw =
                        (_blurDragCurrent!.dx - _blurDragStart!.dx).abs();
                    final rh =
                        (_blurDragCurrent!.dy - _blurDragStart!.dy).abs();
                    if (rw > 0.02 && rh > 0.02) {
                      setState(() {
                        _blurRegions
                            .add(BlurRegion(x: x, y: y, width: rw, height: rh));
                        _blurDrawMode = false;
                        _blurDragStart = null;
                        _blurDragCurrent = null;
                      });
                    } else {
                      setState(() {
                        _blurDragStart = pos;
                        _blurDragCurrent = pos;
                      });
                    }
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        if (_isDefiningTrackedBlur)
          Positioned.fill(
            child: MouseRegion(
              cursor: SystemMouseCursors.precise,
              onHover: (event) {
                if (_trackedBlurStart != null) {
                  setState(() {
                    _trackedBlurEnd = Offset(
                      (event.localPosition.dx / w).clamp(0.0, 1.0),
                      (event.localPosition.dy / h).clamp(0.0, 1.0),
                    );
                  });
                }
              },
              child: GestureDetector(
                onTapDown: (d) {
                  final pos = Offset(
                    (d.localPosition.dx / w).clamp(0.0, 1.0),
                    (d.localPosition.dy / h).clamp(0.0, 1.0),
                  );
                  if (_trackedBlurStart == null) {
                    setState(() {
                      _trackedBlurStart = pos;
                      _trackedBlurEnd = pos;
                    });
                  } else {
                    final rw =
                        (_trackedBlurEnd!.dx - _trackedBlurStart!.dx).abs();
                    final rh =
                        (_trackedBlurEnd!.dy - _trackedBlurStart!.dy).abs();
                    if (rw > 0.02 && rh > 0.02) {
                      setState(() {
                        _isDefiningTrackedBlur = false;
                        _blurRegions.clear();
                      });
                      _runTracking();
                    } else {
                      setState(() {
                        _trackedBlurStart = pos;
                        _trackedBlurEnd = pos;
                      });
                    }
                  }
                },
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        if (_blurDrawMode)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _blurDragStart == null
                      ? (_blurRegions.isEmpty
                          ? 'Click to set first corner of blur region 1'
                          : 'Click to set first corner of blur region 2')
                      : 'Click to confirm blur region',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        if (_isDefiningTrackedBlur)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _trackedBlurStart == null
                      ? 'Click to set first corner of tracked blur region'
                      : 'Click to confirm tracked blur region',
                  style:
                      const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
              ),
            ),
          ),
        if (_isTracking)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tracking motion…',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        if (!_isTracking && _trackedCoords.isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '✓ ${_trackedCoords.length} frames tracked',
                style:
                    const TextStyle(color: Colors.orangeAccent, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _runTracking() async {
    if (_trackedBlurStart == null || _trackedBlurEnd == null) return;

    final currentPath = _currentAudiobook?.path;
    if (currentPath == null) return;

    final x = min(_trackedBlurStart!.dx, _trackedBlurEnd!.dx);
    final y = min(_trackedBlurStart!.dy, _trackedBlurEnd!.dy);
    final w = (_trackedBlurEnd!.dx - _trackedBlurStart!.dx).abs();
    final h = (_trackedBlurEnd!.dy - _trackedBlurStart!.dy).abs();

    setState(() {
      _isTracking = true;
      _trackedCoords = [];
      _trackingStatus = '';
    });

    try {
      final frames = await VisionTrackingService.trackRegion(
        videoPath: currentPath,
        x: x,
        y: y,
        w: w,
        h: h,
      );

      setState(() {
        _trackedCoords = frames
            .map((f) => [f.frameIndex.toDouble(), f.x, f.y, f.w, f.h])
            .toList();
        _isTracking = false;
      });
    } catch (e) {
      setState(() {
        _isTracking = false;
        _trackedCoords = [];
        _trackedBlurStart = null;
        _trackedBlurEnd = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tracking failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _jumpToStatsResult(
      String filename, String chapterTitle, Duration startTime) async {
    final audiobookPath = _playlist.firstWhere(
      (p) => path.basenameWithoutExtension(p) == filename,
      orElse: () => '',
    );

    if (audiobookPath.isEmpty) return;

    if (chapterTitle.isEmpty) {
      setState(() {
        _showPanel = false;
      });
      await _openAudiobook(audiobookPath);
      return;
    }

    if (_playlistChapterIndex.containsKey(audiobookPath)) {
      final chapters = _playlistChapterIndex[audiobookPath]!;
      final chapterIndex =
          chapters.indexWhere((ch) => ch.title == chapterTitle);

      if (chapterIndex != -1) {
        if (_currentAudiobook?.path != audiobookPath) {
          setState(() {
            _frequencyItems = [];
            _isAnalyzingFrequencies = false;
          });
          await _openAudiobook(audiobookPath);
          await Future.delayed(const Duration(milliseconds: 500));
        }
        await _seekTo(chapters[chapterIndex].startTime +
            const Duration(milliseconds: 200));
        setState(() {
          _showPanel = false;
        });
      }
    }
  }

  Future<void> _downloadYouTubeSubtitles(String url, String title,
      {bool showPicker = false}) async {
    try {
      print('=== Starting subtitle download for: $title ===');

      final tempDir = Directory.systemTemp.path;
      final ytSubDir = path.join(tempDir, 'substitcher_yt_subs');
      await Directory(ytSubDir).create(recursive: true);

      String? subtitlePath;
      String selectedLang = _subtitlePreferences.defaultLanguage;
      String? translateTo;
      bool isAutoTranslated = false;

      if (!showPicker) {
        print('Attempting to download default language: $selectedLang');
        subtitlePath = await YouTubeService.downloadAndFixSubtitles(
          url,
          ytSubDir,
          lang: selectedLang,
          cookiesFilePath: _subtitlePreferences.cookiesFilePath,
          isAutoTranslate: isAutoTranslated,
        );
      }

      if (subtitlePath == null) {
        print(
            'Default language $selectedLang failed, showing language selection...');
        if (!mounted) return;

        final availableSubs = await YouTubeService.getAvailableSubtitles(url);

        final selected = await showDialog<String>(
          context: context,
          builder: (context) {
            final searchController = TextEditingController();
            List<Map<String, String>> filtered = List.from(availableSubs);
            bool autoTranslate = false;

            return StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                backgroundColor: const Color(0xFF2D2D2D),
                title: const Text(
                  'Select Subtitle Language',
                  style: TextStyle(color: Colors.white),
                ),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          showPicker
                              ? 'Select subtitle language:'
                              : 'Default language "$selectedLang" not available.\nSelect an alternative:',
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: autoTranslate,
                              activeColor: Colors.deepPurple,
                              onChanged: (val) {
                                if (val == true) {
                                  Navigator.pop(context, 'translate:auto');
                                } else {
                                  setDialogState(() => autoTranslate = false);
                                }
                              },
                            ),
                            Expanded(
                              child: Text(
                                'Auto-translate to ${SubtitlePreferences.availableLanguages[_subtitlePreferences.defaultLanguage] ?? _subtitlePreferences.defaultLanguage}\n(requires Firefox cookie with youtube.com visited)',
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: autoTranslate
                              ? 'Search source language...'
                              : 'Search languages...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon:
                              const Icon(Icons.search, color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (query) {
                          setDialogState(() {
                            filtered = availableSubs.where((sub) {
                              final q = query.toLowerCase();
                              return sub['name']!.toLowerCase().contains(q) ||
                                  sub['code']!.toLowerCase().contains(q);
                            }).toList();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: filtered.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No languages match your search',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final sub = filtered[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      sub['name']!,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      sub['code']!,
                                      style: const TextStyle(
                                          color: Colors.white54),
                                    ),
                                    onTap: () => Navigator.pop(
                                      context,
                                      autoTranslate
                                          ? 'translate:${sub['code']}'
                                          : sub['code'],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            );
          },
        );

        if (selected == null) {
          print('User cancelled subtitle selection');
          return;
        }

        if (selected.startsWith('translate:')) {
          isAutoTranslated = true;
          final source = selected.replaceFirst('translate:', '');
          if (source == 'auto') {
            selectedLang = _subtitlePreferences.defaultLanguage;
            translateTo = null;
            print('User selected auto-translate: yt-dlp will detect source');
          } else {
            selectedLang = source;
            translateTo = _subtitlePreferences.defaultLanguage;
            print(
                'User selected auto-translate: $selectedLang -> $translateTo');
          }
        } else {
          selectedLang = selected;
          print('User selected alternative: $selectedLang');
        }

        subtitlePath = await YouTubeService.downloadAndFixSubtitles(
          url,
          ytSubDir,
          lang: selectedLang,
          translateTo: translateTo,
          cookiesFilePath: _subtitlePreferences.cookiesFilePath,
          isAutoTranslate: isAutoTranslated,
        );
      }

      print('Subtitle path result: $subtitlePath');

      if (subtitlePath != null && mounted) {
        print('Loading subtitle file: $subtitlePath');
        final content = await File(subtitlePath).readAsString();
        final parsedSubs = _parseVTT(content);
        print('Parsed ${parsedSubs.length} subtitle cues');

        if (isAutoTranslated) {
          if (_subtitleFilePath == null) {
            setState(() {
              _originalSubtitles = parsedSubs;
              _subtitleFilePath = subtitlePath;
              _primarySubtitlePath = subtitlePath;
              _paragraphItems = _createParagraphs(parsedSubs);
              _secondarySubtitleFont = _defaultFont;
              _secondaryColorPalette = _currentColorPalette;
            });
            await _applyConversion();
            _updateCurrentSubtitle();
            _precalculateWordPositions();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Loaded ${parsedSubs.length} auto-translated cues as primary ($selectedLang → ${_subtitlePreferences.defaultLanguage})',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            setState(() {
              _secondarySubtitleFilePath = subtitlePath;
              _secondarySubtitlePath = subtitlePath;
              _secondaryOriginalSubtitles = parsedSubs;
              _secondarySubtitles = parsedSubs;
              _secondarySubtitleText = '';
              _currentSecondarySubtitleIndex = null;
              _secondarySubtitleFont = _defaultFont;
              _secondaryColorPalette = _currentColorPalette;
            });
            await _applySecondaryConversion();
            _updateCurrentSubtitle();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Loaded ${parsedSubs.length} auto-translated cues as secondary ($selectedLang → ${_subtitlePreferences.defaultLanguage})',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          setState(() {
            _subtitles = parsedSubs;
            _originalSubtitles = parsedSubs;
            _subtitleFilePath = subtitlePath;
            _primarySubtitlePath = subtitlePath;
            _paragraphItems = _createParagraphs(parsedSubs);
            _secondarySubtitleFont = _defaultFont;
            _secondaryColorPalette = _currentColorPalette;
          });
          await _applyConversion();
          _updateCurrentSubtitle();
          _precalculateWordPositions();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Loaded ${parsedSubs.length} subtitle cues ($selectedLang)',
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else if (mounted) {
        print('Failed to download subtitle');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('No $selectedLang subtitles available for this video'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Error downloading YouTube subtitles: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subtitle download failed: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleYouTubeUrl(String url,
      {int? playlistIndex, int? playlistTotal, Duration? resumePosition}) async {
      if (!YouTubeService.isSupportedUrl(url)) return;

      final isLive = await YouTubeService.isActiveLiveStream(url);

      if (isLive && mounted) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D2D2D),
            title: const Text('Active Live Stream',
                style: TextStyle(color: Colors.white)),
            content: const Text(
              'This is currently a live stream. Live streams don\'t have subtitles yet.\n\n'
              'You can stream without subtitles now, or wait until the stream finishes to download with subtitles.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
                child: const Text('Stream Without Subs'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) {
          return;
        }
      }

      setState(() {
        _isLoadingYouTube = true;
        _currentYouTubeUrl = url;
      });

      try {
        final ytSubDir =
            path.join(Directory.systemTemp.path, 'substitcher_yt_subs');
        if (await Directory(ytSubDir).exists()) {
          await Directory(ytSubDir).delete(recursive: true);
          await Directory(ytSubDir).create();
        }
      } catch (e) {
        print('Error clearing subtitle temp dir: $e');
      }

      try {
        if (!await YouTubeService.isYtdlpAvailable()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('yt-dlp not found. Install with: brew install yt-dlp'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() {
            _isLoadingYouTube = false;
          });
          return;
        }

        final title = await YouTubeService.getVideoTitle(url);
        final channelName = await YouTubeService.getChannelName(url);
        final chapters = await YouTubeService.getVideoChapters(url);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loading: $title'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        final audioUrl = await YouTubeService.getAudioStreamUrl(url,
            formatId:
                'worstaudio[format_note*=DRC]/worstaudio[acodec=opus]/worstaudio');

        if (audioUrl == null) {
          throw Exception('Could not get audio stream URL');
        }

        if (_currentAudiobook != null &&
            _currentAudiobook!.chapters.isNotEmpty &&
            _currentChapterIndex < _currentAudiobook!.chapters.length) {
          final currentChapter =
              _currentAudiobook!.chapters[_currentChapterIndex];
          _statsManager.recordChapterEnd(
            path.basenameWithoutExtension(_currentAudiobook!.path),
            currentChapter.title,
            false,
          );
          await _statsManager.flushCacheToLog();
        }

        await player.stop();

        List<Chapter> youtubeChapters = [];
        if (chapters != null && chapters.isNotEmpty) {
          for (int i = 0; i < chapters.length; i++) {
            final chapterData = chapters[i];
            final startTime =
                Duration(seconds: (chapterData['start_time'] as num).toInt());

            Duration endTime;
            if (i < chapters.length - 1) {
              endTime = Duration(
                  seconds: (chapters[i + 1]['start_time'] as num).toInt());
            } else {
              endTime = const Duration(hours: 24);
            }

            youtubeChapters.add(Chapter(
              index: i,
              title: chapterData['title'] as String? ?? 'Chapter ${i + 1}',
              startTime: startTime,
              endTime: endTime,
              duration: endTime - startTime,
            ));
          }
        }

        setState(() {
          _currentAudiobook = AudiobookMetadata(
            path: url,
            title: title,
            author: channelName ?? 'Unknown',
            year: '',
            duration: Duration.zero,
            chapters: youtubeChapters,
          );
          _currentChapterIndex = 0;
          _isYouTubeStream = true;
          _youtubeTitle = title;
          _youtubeChannelName = channelName;
          _currentAudioFormat = 'lowest bitrate';
          _subtitles = [];
          _originalSubtitles = [];
          _currentSubtitleText = '';
          _currentSubtitleIndex = null;
          _subtitleFilePath = null;
          _primarySubtitlePath = null;
          _secondarySubtitlePath = null;
          _secondarySubtitleFilePath = null;
          _secondarySubtitles = [];
          _secondaryOriginalSubtitles = [];
          _secondarySubtitleText = '';
          _currentSecondarySubtitleIndex = null;
          _selectedFont = _defaultFont;
          _conversionType = _defaultConversionType;
          if (_defaultColorPalette != null) {
            final palette = ColorPalette.presets.firstWhere(
              (p) => p.name == _defaultColorPalette,
              orElse: () => ColorPalette.presets.first,
            );
            _currentColorPalette = palette;
            _selectedColorIndex = ColorPalette.presets.indexOf(palette);
          }
        });

        await player.open(Media(audioUrl), play: false);
        await player.setRate(_playbackSpeed);

        Duration? loadedDuration;
        try {
          loadedDuration = await player.stream.duration
              .firstWhere((d) => d > Duration.zero)
              .timeout(const Duration(seconds: 30));
        } catch (e) {
          print('Timed out waiting for YouTube stream duration: $e');
          loadedDuration = null;
        }

        if (loadedDuration != null && loadedDuration > Duration.zero) {
          if (_totalDuration != loadedDuration && mounted) {
            setState(() {
              _totalDuration = loadedDuration!;
            });
          }

          if (youtubeChapters.isNotEmpty) {
            final lastChapter = youtubeChapters.last;
            youtubeChapters[youtubeChapters.length - 1] = Chapter(
              index: lastChapter.index,
              title: lastChapter.title,
              startTime: lastChapter.startTime,
              endTime: loadedDuration,
              duration: loadedDuration - lastChapter.startTime,
            );
            setState(() {
              _currentAudiobook = AudiobookMetadata(
                path: url,
                title: title,
                author: channelName ?? 'Unknown',
                year: '',
                duration: loadedDuration!,
                chapters: youtubeChapters,
              );
            });
          }

          if (resumePosition != null && resumePosition.inSeconds > 0) {
            await player.seek(resumePosition);
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }

        setState(() {
          _isPlaying = true;
        });

        await player.play();

        _updateWakelock();

        _downloadYouTubeSubtitles(url, title);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Now playing: $title${youtubeChapters.isNotEmpty ? ' (${youtubeChapters.length} chapters)' : ''}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e, stackTrace) {
        print('Error loading YouTube audio: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load YouTube audio: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        setState(() {
          _isLoadingYouTube = false;
        });
      }
    }

  Future<void> _loadSubtitlePreferences() async {
    final prefs = await SubtitlePreferences.load();
    setState(() {
      _subtitlePreferences = prefs;
    });
  }

  Future<void> _showSubtitlePreferencesDialog() async {
    final prefs = _subtitlePreferences;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text(
            'Subtitle Preferences',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Default Language',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Auto-downloaded when a YouTube video is loaded and sets auto-translate language',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: prefs.defaultLanguage,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  underline: Container(),
                  items: SubtitlePreferences.availableLanguages.entries
                      .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => prefs.defaultLanguage = value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'YouTube Cookies File',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Required for auto-translated subtitles:\n'
                '1. Open Firefox and visit youtube.com\n'
                '2. In Firefox Settings → Privacy, add youtube.com as a cookie exception so it persists after close\n'
                '3. Auto-translate will then work without needing a cookies file',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        prefs.cookiesFilePath ?? 'No cookies file selected',
                        style: TextStyle(
                          color: prefs.cookiesFilePath != null
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.file_open, color: Colors.white70),
                    tooltip: 'Select cookies.txt file',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['txt'],
                        dialogTitle: 'Select YouTube cookies.txt',
                      );
                      if (result != null) {
                        setDialogState(() {
                          prefs.cookiesFilePath = result.files.single.path;
                        });
                      }
                    },
                  ),
                  if (prefs.cookiesFilePath != null)
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white38),
                      tooltip: 'Remove cookies file',
                      onPressed: () {
                        setDialogState(() => prefs.cookiesFilePath = null);
                      },
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await prefs.save();
                setState(() => _subtitlePreferences = prefs);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preferences saved'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    _focusNode.requestFocus();
  }

  Future<void> _showYouTubeDialog() async {
    if (!mounted) return;

    final result = await showYouTubeDialog(context);

    if (result != null) {
      if (result['action'] == 'stream' && result['url'] != null) {
        if (result['playlistIndex'] != null) {
          setState(() {
            _youtubePlaylistCurrentIndex = result['playlistIndex'] as int;
            _youtubePlaylistTotal = result['playlistTotal'] as int;
          });
        } else {
          setState(() {
            _youtubePlaylistCurrentIndex = null;
            _youtubePlaylistTotal = null;
          });
        }
        await _handleYouTubeUrl(
          result['url'],
          playlistIndex: result['playlistIndex'] as int?,
          playlistTotal: result['playlistTotal'] as int?,
        );
      } else if (result['action'] == 'download') {
        _showDownloadDialog();
      }
    }

    _focusNode.requestFocus();
  }

  String _formatVttTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get _vttShowDisplayText {
    if (!_vttShowActive || _currentSubtitleText.isEmpty) {
      return _currentSubtitleText;
    }
    final lines = _currentSubtitleText.split('\n');
    return lines.take(_vttShowRevealedLines).join('\n');
  }

  String _formatDurationCompact(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      if (seconds > 0) {
        return '${hours}h ${minutes}m ${seconds}s';
      } else if (minutes > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${hours}h';
      }
    } else if (minutes > 0) {
      if (seconds > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${minutes}m';
      }
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildStatsPanel() {
    return StatsPanel(
      statsEntries: _statsManager.statsEntries,
      statsEnabled: _statsManager.statsEnabled,
      onStatsEnabledChanged: (value) {
        _statsManager.saveStatsEnabled(value);
      },
      onRefreshStats: () {
        _statsManager.loadAllStatsEntries();
      },
      searchQuery: _statsSearchQuery,
      excludeTerms: _excludeTerms,
      filterEntriesByDate: _filterEntriesByDate,
      filterEntriesByDays: _filterEntriesByDays,
      getFileListenTimes: _getFileListenTimes,
      groupEntriesByAudiobook: _groupEntriesByAudiobook,
      formatDurationCompact: _formatDurationCompact,
      formatDuration: _formatDuration,
      deleteAudiobookFromDate: (title, date) async {
        await _statsManager.deleteAudiobookFromDate(title, date);
        setState(() {});
      },
      highlightSearchTerm: _highlightSearchTerm,
      jumpToStatsResult: (filename, chapterTitle, startTime) {
        _jumpToStatsResult(filename, chapterTitle, startTime);
      },
    );
  }

  List<Map<String, dynamic>> _groupEntriesByAudiobook(
      List<Map<String, dynamic>> entries) {
    final Map<String, Map<String, int>> grouped = {};

    for (final entry in entries) {
      final filename = entry['filename'] as String;
      final chapterName = entry['chapter_name'] as String;
      final duration = (entry['listened_duration'] as num).toInt();

      if (!grouped.containsKey(filename)) {
        grouped[filename] = {};
      }

      if (!grouped[filename]!.containsKey(chapterName)) {
        grouped[filename]![chapterName] = 0;
      }
      grouped[filename]![chapterName] =
          grouped[filename]![chapterName]! + duration;
    }

    final result = <Map<String, dynamic>>[];

    grouped.forEach((filename, chapters) {
      int totalTime = 0;
      final chaptersList = <Map<String, dynamic>>[];

      chapters.forEach((chapterName, duration) {
        totalTime += duration;

        final matchingEntry = entries.lastWhere(
          (e) => e['filename'] == filename && e['chapter_name'] == chapterName,
        );

        chaptersList.add({
          'title': chapterName,
          'time': duration,
          'timestamp': matchingEntry['datetime'] as String,
        });
      });

      chaptersList.sort((a, b) {
        final titleA = a['title'] as String;
        final titleB = b['title'] as String;

        final numA = int.tryParse(titleA.split(' ')[0]);
        final numB = int.tryParse(titleB.split(' ')[0]);

        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }

        return titleA.compareTo(titleB);
      });

      final totalEntriesTime = entries.fold<int>(
          0, (sum, e) => sum + (e['listened_duration'] as num).toInt());
      final percentage = totalEntriesTime > 0
          ? ((totalTime / totalEntriesTime) * 100).round()
          : 0;

      result.add({
        'title': filename,
        'duration': _formatDurationCompact(Duration(seconds: totalTime)),
        'percentage': percentage,
        'chapters': chaptersList,
      });
    });

    result.sort(
        (a, b) => (b['percentage'] as int).compareTo(a['percentage'] as int));

    return result;
  }

  Widget _buildNoAudiobook() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focusNode.requestFocus();
      },
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.headphones, size: 100, color: Colors.white54),
            const SizedBox(height: 32),
            const Text(
              'No audiobook loaded',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(color: Colors.white54, fontSize: 16),
                children: [
                  TextSpan(
                    text: 'h 1',
                    style: TextStyle(
                        color: Color(0xFFF5D38A), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (open 1st audiobook in history)\n '),
                  TextSpan(
                    text: 'p 3',
                    style: TextStyle(
                        color: Color(0xFFF5D38A), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (open 3rd audiobook in playlist)\n '),
                  TextSpan(
                    text: 'b 6',
                    style: TextStyle(
                        color: Color(0xFFF5D38A), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (open 6th bookmark in bookmarks)'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPanel = true;
                          _panelMode = PanelMode.history;
                        });
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('History (h)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPanel = true;
                          _panelMode = PanelMode.bookmarks;
                        });
                      },
                      icon: const Icon(Icons.bookmark),
                      label: const Text('Bookmarks (b)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPanel = true;
                          _panelMode = PanelMode.playlist;
                        });
                      },
                      icon: const Icon(Icons.playlist_play),
                      label: const Text('Playlist (p)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _openSubtitleManager,
                      icon: const Icon(Icons.slideshow),
                      label: const Text('vttshow (v)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPanel = true;
                          _panelMode = PanelMode.stats;
                        });
                      },
                      icon: const Icon(Icons.bar_chart),
                      label: const Text('Stats (t)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _setPlaylistDirectory,
                      icon: const Icon(Icons.folder_special),
                      label: const Text('Set Playlist Directory'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _openAudiobook();
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Load Audiobook (l)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showPanel = true;
                          _panelMode = PanelMode.quran;
                        });
                      },
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Quran (q)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!Platform.isAndroid && !Platform.isIOS) ...[
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _showYouTubeDialog,
                        icon: const Icon(Icons.headphones),
                        label: const Text('YouTube Audio (⇧Y)'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EncoderScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.build),
                      label: const Text(
                          'Encode Audiobook | Transcribe/Translate (e)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowCloseListener extends WindowListener {
  final Future<void> Function() onClose;

  _WindowCloseListener({required this.onClose});

  @override
  Future<void> onWindowClose() async {
    await onClose();
    await windowManager.destroy();
  }
}
