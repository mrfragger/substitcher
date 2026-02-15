import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:image/image.dart' as img;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'metadata_editor_screen.dart';
import 'encoder_screen.dart';
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
import '../services/lut_processor.dart';
import '../services/lut_manager.dart';
import '../widgets/adhan_clock_overlay.dart';
import '../widgets/subtitle_manager_dialog.dart';
import '../widgets/side_panel.dart';
import '../widgets/stats_panel.dart';
import '../widgets/player_controls.dart';
import '../widgets/word_overlay.dart';
import '../widgets/download_overlay.dart';


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

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final WindowListener _windowListener;
  final FFmpegService _ffmpeg = FFmpegService();
  final player = Player();
  final ScrollController _chapterScrollController = ScrollController();
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
  Timer? _sleepTimer;
  Duration? _sleepDuration;
  ColorPalette? _currentColorPalette;
  int _selectedColorIndex = 0;
  final ScrollController _colorScrollController = ScrollController();
  bool _showEncoderScreen = false;
  final List<int> _cueWordStarts = [];

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
  final TextEditingController _chapterSearchController = TextEditingController();
  final FocusNode _chapterSearchFocusNode = FocusNode();

  List<HistoryItem> _history = [];
  List<Bookmark> _bookmarks = [];
  List<String> _playlist = [];
  String? _playlistRootDir;
  List<String> _playlistDirectories = [];
  int? _activePlaylistIndex;
  final Map<String, String> _playlistDurationCache = {};

  Timer? _frequencyGenerationTimer;

  int? _currentSubtitleIndex;
  List<SubtitleCue> _subtitles = [];
  String _currentSubtitleText = '';
  String? _subtitleFilePath;
  double _subtitleFontSize = 86.0;

  List<SubtitleCue> _originalSubtitles = [];
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

  String _defaultFont = 'System Default';
  String? _defaultColorPalette;
  String _defaultConversionType = 'none';
  String _selectedFont = 'System Default';
  int _selectedFontIndex = -1;
  final ScrollController _fontScrollController = ScrollController();
  String? _customFontDirectory;
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
  final TextEditingController _chapterExcludeController = TextEditingController();
  final FocusNode _chapterExcludeFocusNode = FocusNode();

  String _skipTrackingTerms = '';
  final TextEditingController _skipTrackingController = TextEditingController();
  final FocusNode _skipTrackingFocusNode = FocusNode();

  PauseMode _pauseMode = PauseMode.disabled;
  Timer? _pauseModeTimer;
  Duration? _nextPauseTime;

  final StatsManager _statsManager = StatsManager();
  Timer? _cacheFlushTimer;

  late AdhanClockService _adhanClockService;
  bool _showAdhanOverlay = false;

  static const platform = MethodChannel('com.substitcher/open_file');

  bool _showSleepTimerCountdown = false;
  int _sleepTimerCountdownSeconds = 120;
  Timer? _sleepTimerCountdownTimer;

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
  bool _isLoadingAudioStreams = false;
  DateTime? _lastAudioStreamFetch;
  String? _currentAudioFormat;

  bool _autoConvertAlternates = false;
  bool _autoConvertMissing = false;
  Set<String> _favoriteFonts = {};

  Set<String> _favoriteColorPalettes = {};
  String _colorFilterMode = 'favorites';
  bool _subtitleTransparencyMode = false;
  bool _subtitleIncreasedShadow = false;
  bool _defaultSubtitleTransparencyMode = false;

  List<LutItem> _availableLuts = [];
  List<List<List<List<int>>>>? _loadedLutData;
  String? _selectedLutPath;
  String? _selectedLutName;
  Set<String> _favoriteLuts = {};
  String _lutFilterMode = 'all'; // 'all' or 'favorites'
  int _selectedLutIndex = -1;
  bool _showingLuts = false;
  
  
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
    CustomFontLoader.loadFonts();
    CustomFontMetadataManager.load();
    _loadSkipChapterTerms();
    _loadCustomFontDirectory();
    _loadDefaultSettings();
    _loadPlaylistDirectories().then((_) {
      _loadChapterIndex();
    });
    _loadDurationCache();
    _loadInitialStats();
    _loadHistory();
    _loadPlaylist();
    _loadSubtitlePreferences();
    _loadAutoConversionSettings();
    _loadBookmarks();
    _loadFavoriteFonts();
    _loadFavoriteColorPalettes();
    _loadSkipTrackingTerms();
    _startCacheFlushTimer();
    _loadFavoriteLuts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _adhanClockService.checkNow();
    });
  }
  
  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    windowManager.removeListener(_windowListener);
    _cacheFlushTimer?.cancel();
    _frequencyGenerationTimer?.cancel();
    _sleepTimerCountdownTimer?.cancel();
    _adhanClockService.dispose();
    if (_currentAudiobook != null) {
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
        _statsManager.recordChapterEnd(
          path.basenameWithoutExtension(_currentAudiobook!.path),
          currentChapter.title,
          false,
        );
        _statsManager.flushCacheToLog();
      }
    }
    _sleepTimer?.cancel();
    _pauseModeTimer?.cancel();
    player.dispose();
    _chapterScrollController.dispose();
    _fontScrollController.dispose();
    _colorScrollController.dispose();
    _playlistScrollController.dispose();
    _historyScrollController.dispose();
    _focusNode.dispose();
    _searchController.dispose();
    _excludeController.dispose();
    _searchFocusNode.dispose();
    _excludeFocusNode.dispose();
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
    _skipTrackingController.dispose();
    _skipTrackingFocusNode.dispose();
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
        _updateWakelock();
      }
      if (playing) {
        if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook?.path ?? ''))) {
          _statsManager.onPlaybackStart();
        }
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
        if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook?.path ?? ''))) {
          _statsManager.onPlaybackPause();
        }
        _saveToHistory();
      }
    });
  }

 Future<void> _saveDefaultSettings() async {
   final prefs = await SharedPreferences.getInstance();
   await prefs.setString('defaultFont', _defaultFont);
   await prefs.setString('defaultConversionType', _defaultConversionType);
   await prefs.setBool('defaultSubtitleTransparencyMode', _defaultSubtitleTransparencyMode);
   if (_defaultColorPalette != null) {
     await prefs.setString('defaultColorPalette', _defaultColorPalette!);
   }
 }
 
 Future<void> _loadDefaultSettings() async {
   final prefs = await SharedPreferences.getInstance();
   setState(() {
     _defaultFont = prefs.getString('defaultFont') ?? 'System Default';
     _defaultConversionType = prefs.getString('defaultConversionType') ?? 'none';
     _defaultSubtitleTransparencyMode = prefs.getBool('defaultSubtitleTransparencyMode') ?? false;
     _defaultColorPalette = prefs.getString('defaultColorPalette');
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
     _defaultSubtitleTransparencyMode = _subtitleTransparencyMode;
   });
   
   await _saveDefaultSettings();
   
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(
           'Set as default:\n'
           'Font: $_defaultFont\n'
           'Conversion: $_defaultConversionType\n'
           'Color: ${_defaultColorPalette ?? 'None'}\n'
           'Dim Mode: ${_defaultSubtitleTransparencyMode ? 'On' : 'Off'}'
         ),
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
     
     _conversionType = _defaultConversionType;
     _subtitleTransparencyMode = _defaultSubtitleTransparencyMode;
     
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
   });
   
   await _saveFontSettings();
   await _applyConversion();
   
   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text(
           'Applied defaults:\n'
           'Font: $_defaultFont\n'
           'Conversion: $_defaultConversionType\n'
           'Color: ${_defaultColorPalette ?? 'None'}\n'
           'Dim Mode: ${_defaultSubtitleTransparencyMode ? 'On' : 'Off'}'
         ),
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
        final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
        if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
          _statsManager.recordChapterEnd(
            path.basenameWithoutExtension(_currentAudiobook!.path),
            currentChapter.title,
            false,
          );
          await _statsManager.flushCacheToLog().timeout(const Duration(milliseconds: 500));
        }
      }
      
      await _saveToHistory().timeout(const Duration(milliseconds: 500));
      await player.stop().timeout(const Duration(milliseconds: 500));
      
    } catch (e) {
      print('Error during window close: $e');
    }
  }

  void _startCacheFlushTimer() {
    _cacheFlushTimer?.cancel();
    _cacheFlushTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_statsManager.statsEnabled && _statsManager.chapterStartTime != null && _currentAudiobook != null) {
        final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
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
    if (_currentAudiobook == null || _currentAudiobook!.chapters.isEmpty) return;
    
    if (_currentChapterIndex >= _currentAudiobook!.chapters.length) return;
    
    final chapter = _currentAudiobook!.chapters[_currentChapterIndex];

    if (position >= chapter.endTime) {  
        if (!_isYouTubeStream && !_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
          final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
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
        _triggerSleepTimerCountdown();
        return;
      }
      
      if (_shuffleEnabled && !_isYouTubeStream) {
        final unplayedChapters = List.generate(_currentAudiobook!.chapters.length, (i) => i)
            .where((i) => !_playedChapters.contains(i) && !_shouldSkipChapter(_currentAudiobook!.chapters[i].title))
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
          
          if (nextIndex < 0 || nextIndex >= _currentAudiobook!.chapters.length) {
            return;
          }
          
          final nextChapter = _currentAudiobook!.chapters[nextIndex];

          setState(() {
              _currentChapterIndex = nextIndex;
              if (!_playedChapters.contains(nextIndex)) {
                _playedChapters.add(nextIndex);
              }
            });
          
          player.seek(nextChapter.startTime + const Duration(milliseconds: 100));
        }
      } else {
        int nextIndex = _currentChapterIndex + 1;
        if (!_isYouTubeStream) {
          while (nextIndex < _currentAudiobook!.chapters.length) {
            if (!_shouldSkipChapter(_currentAudiobook!.chapters[nextIndex].title)) {
              break;
            }
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
          
          setState(() {
            _currentChapterIndex = nextIndex;
          });
        } else {
          if (nextIndex >= _currentAudiobook!.chapters.length) {
            player.pause();
            return;
          }
          
          setState(() {
            _currentChapterIndex = nextIndex;
          });
        }
      }
      
      if (_currentAudiobook != null && 
          !_isYouTubeStream && 
          _currentChapterIndex < _currentAudiobook!.chapters.length &&
          !_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
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
        const SnackBar(content: Text('Load subtitles and select a demo font first')),
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
            SnackBar(content: Text('Original subtitle not found: ${path.basename(originalSubtitlePath)}')),
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
              content: Text('Converted with ligature fixes: ${path.basename(outputPath)}'),
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
    if (_currentAudiobook == null) return;
    
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
    
    final dir = Directory(audiobookDir);
    await for (final entity in dir.list()) {
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
    
    subtitleFiles.sort((a, b) => path.basename(a).compareTo(path.basename(b)));
    
    setState(() {
      _availableSubtitles = subtitleFiles;
    });
  }

  Future<void> _openSubtitleManager() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }
    
    await _scanAvailableSubtitles();
    
    if (_availableSubtitles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No subtitle files found')),
        );
      }
      return;
    }
    
    if (_subtitleFilePath != null && _primarySubtitlePath == null) {
      setState(() {
        _primarySubtitlePath = _subtitleFilePath;
      });
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => SubtitleManagerDialog(
        availableSubtitles: _availableSubtitles,
        primarySubtitle: _primarySubtitlePath,
        secondarySubtitle: _secondarySubtitlePath,
        currentAudiobookPath: _currentAudiobook?.path,
        onPrimarySelected: (path) async {
          setState(() {
            _primarySubtitlePath = path;
            _subtitleFilePath = path;
          });
          await _applyConversion();
        },        
        onSecondarySelected: (path) async {
          setState(() {
            _secondarySubtitlePath = path;
            _secondarySubtitleFilePath = path;
            if (_secondarySubtitleFont == 'System Default' && _selectedFont != 'System Default') {
              _secondarySubtitleFont = _selectedFont;
            }
            if (_secondaryColorPalette == null && _currentColorPalette != null) {
              _secondaryColorPalette = _currentColorPalette;
            }
            if (_secondarySubtitleFontSize == 86.0) {
              _secondarySubtitleFontSize = _subtitleFontSize;
            }
          });
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
            
            _selectedFont = _secondarySubtitleFont;
            _subtitleFontSize = _secondarySubtitleFontSize;
            _currentColorPalette = _secondaryColorPalette;
            _conversionType = _secondaryConversionType;
            
            _secondarySubtitleFont = tempFont;
            _secondarySubtitleFontSize = tempSize;
            _secondaryColorPalette = tempPalette;
            _secondaryConversionType = tempConversion;
          });
        },
        onClearPrimary: () {
          setState(() {
            _primarySubtitlePath = null;
            _subtitleFilePath = null;
            _subtitles = [];
            _currentSubtitleText = '';
            _currentSubtitleIndex = null;
          });
        },
        onClearSecondary: () {
          setState(() {
            _secondarySubtitlePath = null;
            _secondarySubtitleFilePath = null;
            _secondarySubtitles = [];
            _secondarySubtitleText = '';
            _currentSecondarySubtitleIndex = null;
          });
        },
      ),
    );
  }
  
  Future<void> _loadSubtitles(String audiobookPath) async {
    try {
      final dir = path.dirname(audiobookPath);
      final audiobookBase = path.basenameWithoutExtension(audiobookPath);
      final vttDir = path.join(dir, '${audiobookBase}_vtt');
      
      String? subtitlePath;
      
      if (await Directory(vttDir).exists()) {
        subtitlePath = await SubtitleOrganizer.findSubtitleInDirectory(audiobookPath);
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
        });
        _updateWakelock();
        return;
      }
      
      setState(() {
        _subtitleFilePath = subtitlePath;
      });
      
      final content = await File(subtitlePath).readAsString();
      
      final originalCues = _parseVTT(content);
      setState(() {
        _originalSubtitles = originalCues;
        _paragraphItems = _createParagraphs(originalCues);
      });
      
      await _applyConversion();
      _updateWakelock();
      _scheduleFrequencyGeneration();
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
  
  static Future<List<FrequencyItem>> _analyzeFrequenciesIsolate(String subtitlePath) async {
    return await FrequencyAnalyzer.analyzeSubtitleFile(subtitlePath);
  }

  List<Chapter> _getFilteredChapters() {
    if (_currentAudiobook == null) return [];
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _currentAudiobook!.chapters;
    }
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
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
    
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return fontsToShow.where((font) {
      return _matchesSearch(font, _searchQuery, excludeList);
    }).toList();
  }

  List<ColorPalette> _getFilteredColors() {
    List<ColorPalette> palettes = ColorPalette.presets;
    
    if (_colorFilterMode == 'favorites') {
      palettes = palettes.where((p) => _favoriteColorPalettes.contains(p.name)).toList();
    }
    
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
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
      setState(() {
        _sleepDuration = Duration.zero;
      });
      _sleepTimer = Timer(timeUntilChapterEnd, () {
        _triggerSleepTimerCountdown();
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
      _sleepTimer = Timer(timeUntilBookEnd, () {
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
    if (_isPlaying) {
      player.pause();
    }
    
    setState(() {
      _showSleepTimerCountdown = true;
      _sleepTimerCountdownSeconds = 120;
    });
    
    _sleepTimerCountdownTimer?.cancel();
    _sleepTimerCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _sleepTimerCountdownSeconds--;
      });
      
      if (_sleepTimerCountdownSeconds <= 0) {
        timer.cancel();
        windowManager.close();
      }
    });
  }

  void _cancelSleepTimerCountdown() {
    _sleepTimerCountdownTimer?.cancel();
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
    
    return _applyLutToColor(color);
  }

  void _scrollToSelectedColorPalette() {
    if (_showPanel && _panelMode == PanelMode.colors && _currentColorPalette != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_colorScrollController.hasClients) {
          final paletteIndex = ColorPalette.presets.indexWhere((p) => p.name == _currentColorPalette!.name);
          if (paletteIndex == -1) return;
          setState(() {
            _selectedColorIndex = paletteIndex;
          });
          final maxScroll = _colorScrollController.position.maxScrollExtent;
          if (maxScroll <= 0) return;
          final totalItems = ColorPalette.presets.length;
          if (totalItems <= 1) return;
          final percentage = paletteIndex / (totalItems - 1);
          final targetScroll = maxScroll * percentage;
          _colorScrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _scrollToCurrentChapter() {
    if (_showPanel && _panelMode == PanelMode.chapters && _currentAudiobook != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chapterScrollController.hasClients) {
          final maxScroll = _chapterScrollController.position.maxScrollExtent;
          if (maxScroll <= 0) return;
          final totalItems = _currentAudiobook!.chapters.length;
          if (totalItems <= 1) return;
          final percentage = _currentChapterIndex / (totalItems - 1);
          final targetScroll = maxScroll * percentage;
          _chapterScrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
  
  void _scrollToCurrentPlaylistItem() {
    if (_showPanel && _panelMode == PanelMode.playlist && _currentAudiobook != null) {
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
    if (_showPanel && (_panelMode == PanelMode.history || _panelMode == PanelMode.bookmarks)) {
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
    if (_currentAudiobook == null || _isYouTubeStream) return;
    
    _history.removeWhere((h) => h.audiobookPath == _currentAudiobook!.path);
    
    final chapterTitle = _currentAudiobook!.chapters.isEmpty 
        ? 'No chapters'
        : _currentAudiobook!.chapters[_currentChapterIndex].title;
    
    final chapterIndex = _currentAudiobook!.chapters.isEmpty 
        ? 0 
        : _currentChapterIndex;
    
    _history.insert(0, HistoryItem(
      audiobookPath: _currentAudiobook!.path,
      audiobookTitle: _currentAudiobook!.title,
      chapterTitle: chapterTitle,
      lastChapter: chapterIndex,
      lastPosition: _currentPosition,
      lastPlayed: DateTime.now(),
      shuffleEnabled: _shuffleEnabled,
      playedChapters: _playedChapters,
    ));
    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
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
        const SnackBar(content: Text('Maximum 10 playlist directories allowed')),
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
          content: Text('Added playlist directory: ${path.basename(directoryToAdd)}'),
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
      } else if (_activePlaylistIndex != null && _activePlaylistIndex! > index) {
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
          content: Text('Active playlist: ${path.basename(_playlistDirectories[index])}'),
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
    final home = Platform.environment['HOME'] ?? '/Users/${Platform.environment['USER']}';
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
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
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
          final abbreviations = ['Mr.', 'Dr.', 'Mrs.', 'Ms.', 'Prof.', 'Sr.', 'Jr.'];
          final isAbbreviation = abbreviations.any((abbr) => 
            currentSentence.trim().endsWith(abbr));
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
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    
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
      final timeSinceLastFetch = DateTime.now().difference(_lastAudioStreamFetch!);
      if (timeSinceLastFetch.inSeconds < 3) {
        final remainingSeconds = 3 - timeSinceLastFetch.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait $remainingSeconds more second${remainingSeconds != 1 ? 's' : ''}...'),
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
                      contentPadding: const EdgeInsets.only(left: 32, right: 16),
                      title: Text(
                        stream['description'],
                        style: const TextStyle(color: Colors.white),
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
              _currentAudioFormat = streams.firstWhere((s) => s['id'] == selectedFormatId)['description'];
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
                          style: const TextStyle(fontSize: 12, color: Colors.white),
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
                              text: _highlightSearchTerm(result.chapterTitle, _chapterSearchQuery),
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
                        await _seekTo(result.time + const Duration(milliseconds: 200));
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
                              text: _highlightSearchTerm(result.text, _subsSearchQuery),
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
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
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
                              text: _highlightSearchTerm(para.text, _subsSearchQuery),
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
      final exportPath = path.join(audiobookDir, '${audiobookBase}_paragraphs.md');
  
      final chapters = _currentAudiobook!.chapters;
      final mdContent = StringBuffer();
      
      mdContent.writeln('# $audiobookBase\n');
      
      for (int chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
        final chapter = chapters[chapterIndex];
        
        setState(() {
          _exportStatus = 'Processing chapter ${chapterIndex + 1}/${chapters.length}: ${chapter.title}';
        });
  
        mdContent.writeln('## Chapter ${chapterIndex + 1}: ${chapter.title}\n');
  
        final chapterSubs = _originalSubtitles.where((sub) {
          return sub.startTime >= chapter.startTime && sub.startTime < chapter.endTime;
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
            content: Text('Exported ${chapters.length} chapters to:\n${path.basename(exportPath)}'),
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
        final abbreviations = ['Mr.', 'Dr.', 'Mrs.', 'Ms.', 'Prof.', 'Sr.', 'Jr.', 'St.'];
        final isAbbreviation = abbreviations.any((abbr) => 
          currentSentence.trim().endsWith(abbr));
        
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
      final pattern = RegExp(r'\b' + RegExp.escape(lowerWord) + r'\b', caseSensitive: false);
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
      if (entity is File && path.extension(entity.path).toLowerCase() == '.opus') {
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
      print('DEBUG: Error caching single file duration for ${path.basename(filePath)}: $e');
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

  Future<void> _saveSkipTrackingTerms() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('skipTrackingTerms', _skipTrackingTerms);
  }
  
  Future<void> _loadSkipTrackingTerms() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTerms = prefs.getString('skipTrackingTerms');
    setState(() {
      if (savedTerms != null) {
        _skipTrackingTerms = savedTerms;
        _skipTrackingController.text = savedTerms;
      } else {
        _skipTrackingTerms = '';
        _skipTrackingController.text = '';
      }
    });
  }
  
  bool _shouldSkipTracking(String audiobookTitle) {
    if (_skipTrackingTerms.isEmpty) return false;
    
    final lowerTitle = audiobookTitle.toLowerCase();
    final exactPhrases = <String>[];
    final regularTerms = <String>[];
    
    int i = 0;
    while (i < _skipTrackingTerms.length) {
      if (_skipTrackingTerms[i] == '"') {
        final endQuote = _skipTrackingTerms.indexOf('"', i + 1);
        if (endQuote != -1) {
          final quoted = _skipTrackingTerms.substring(i + 1, endQuote);
          exactPhrases.add(quoted.toLowerCase());
          i = endQuote + 1;
        } else {
          i++;
        }
      } else if (_skipTrackingTerms[i] != ' ') {
        final nextSpace = _skipTrackingTerms.indexOf(' ', i);
        if (nextSpace == -1) {
          regularTerms.add(_skipTrackingTerms.substring(i).toLowerCase());
          break;
        } else {
          regularTerms.add(_skipTrackingTerms.substring(i, nextSpace).toLowerCase());
          i = nextSpace;
        }
      } else {
        i++;
      }
    }
        
    for (final phrase in exactPhrases) {
      if (lowerTitle.contains(phrase)) {
        return true;
      }
    }
    
    for (final term in regularTerms) {
      if (term.isNotEmpty && lowerTitle.contains(term)) {
        return true;
      }
    }
    
    return false;
  }
  
  int _getNextShuffleChapter() {
    if (_currentAudiobook == null) return 0;
    final totalChapters = _currentAudiobook!.chapters.length;
    final unplayedChapters = List.generate(totalChapters, (i) => i)
        .where((i) => !_playedChapters.contains(i) && !_shouldSkipChapter(_currentAudiobook!.chapters[i].title))
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
      _subtitleFontSize = (_subtitleFontSize + 1).clamp(40, 150);
    });
  }
  
  void _decreaseFontSize() {
    setState(() {
      _subtitleFontSize = (_subtitleFontSize - 1).clamp(40, 150);
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
    }
    else if (timeUntilChapterEnd.inSeconds <= 10 && 
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
          content: Text(
            timeFromChapterStart.inSeconds <= 10 || timeUntilChapterEnd.inSeconds <= 10
                ? 'Bookmark added (snapped to chapter start)'
                : 'Bookmark added'
          ),
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
    
    CustomFontLoader.customFonts.clear();
    
    await CustomFontLoader.loadCustomFonts(_customFontDirectory!);
    
    setState(() {});
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${CustomFontLoader.customFonts.length} custom fonts'),
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
    await prefs.setDouble('fontSize_${_currentAudiobook!.path}', _subtitleFontSize);
    await prefs.setString('conversionType_${_currentAudiobook!.path}', _conversionType);
    await prefs.setDouble('lineSpacing_${_currentAudiobook!.path}', _subtitleLineSpacing);
    if (_currentColorPalette != null) {
      await prefs.setString('colorPalette_${_currentAudiobook!.path}', _currentColorPalette!.name);
    }
  }
  
  Future<void> _loadFontSettings(String audiobookPath) async {
    final prefs = await SharedPreferences.getInstance();
    final savedFont = prefs.getString('font_$audiobookPath');
    final savedFontSize = prefs.getDouble('fontSize_$audiobookPath');
    final savedColorPalette = prefs.getString('colorPalette_$audiobookPath');
    final savedConversionType = prefs.getString('conversionType_$audiobookPath');
    final savedLineSpacing = prefs.getDouble('lineSpacing_$audiobookPath');
    if (savedLineSpacing != null) {
      _subtitleLineSpacing = savedLineSpacing;
    }
    
    setState(() {
      if (savedFont != null) {
        _selectedFont = savedFont;
        final filteredFonts = _getFilteredFonts();
        _selectedFontIndex = filteredFonts.indexOf(savedFont);
        if (_selectedFontIndex == -1) _selectedFontIndex = 0;
      } else {
        _selectedFont = _defaultFont;
        final filteredFonts = _getFilteredFonts();
        _selectedFontIndex = filteredFonts.indexOf(_defaultFont);
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: _buildGlyphViewer(),
      ),
    );
  }
  
  Widget _buildGlyphViewer() {
    final displayFont = _selectedFont == 'System Default' ? null : _selectedFont;
    
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
        future: _filterValidGlyphs(allGlyphs, displayFont),
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
                    Text(
                      'Font: $_selectedFont (${glyphs.length} glyphs)',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const Spacer(),
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
  
  Future<List<String>> _filterValidGlyphs(List<String> allGlyphs, String? fontFamily) async {
    final validGlyphs = <String>[];
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );
    
    for (final char in allGlyphs) {
      if (char.trim().isEmpty) continue;
      
      final codePoint = char.codeUnitAt(0);
      
      // Always include Basic Latin (32-126) - A-Z, a-z, 0-9, punctuation
      if (codePoint >= 32 && codePoint <= 126) {
        validGlyphs.add(char);
        continue;
      }
      
      // For PUA range, filter using width comparison
      textPainter.text = TextSpan(
        text: char,
        style: TextStyle(
          fontSize: 48,
          fontFamily: fontFamily,
        ),
      );
      textPainter.layout();
      
      if (textPainter.width > 0) {
        final testPainter = TextPainter(textDirection: TextDirection.ltr);
        testPainter.text = TextSpan(
          text: '�',
          style: TextStyle(fontSize: 48, fontFamily: fontFamily),
        );
        testPainter.layout();
        
        // If widths are significantly different, it's probably a valid glyph
        if ((textPainter.width - testPainter.width).abs() > 5) {
          validGlyphs.add(char);
        }
      }
    }
    
    return validGlyphs;
  }

  Future<void> _loadFavoriteColorPalettes() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteColorPalettes = (prefs.getStringList('favoriteColorPalettes') ?? []).toSet();
    });
  }
  
  Future<void> _addColorPaletteToFavorites(String paletteName) async {
    setState(() {
      _favoriteColorPalettes.add(paletteName);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteColorPalettes', _favoriteColorPalettes.toList());
    
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
    await prefs.setStringList('favoriteColorPalettes', _favoriteColorPalettes.toList());
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$paletteName" from favorites'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _selectLut(String? lutPath, String? lutName) async {
    if (lutPath == null) {
      setState(() {
        _selectedLutName = null;
        _loadedLutData = null;
      });
      return;
    }
    
    try {
      final lutData = await rootBundle.loadString(lutPath);
      final parsedLut = await LutProcessor.parseCubeLutFromString(lutData);
      
      setState(() {
        _selectedLutName = lutName;
        _loadedLutData = parsedLut;
      });
      
    } catch (e) {
      print('Error loading LUT: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load LUT: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanAvailableLuts() async {
    print('DEBUG: Starting LUT scan...');
    final luts = await LutManager.scanLuts();
    print('DEBUG: Scanned ${luts.length} LUTs');
    setState(() {
      _availableLuts = luts;
    });
    print('DEBUG: _availableLuts now has ${_availableLuts.length} items');
  }
  
  Future<void> _loadFavoriteLuts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteLuts = (prefs.getStringList('favoriteLuts') ?? []).toSet();
    });
  }
  
  Future<void> _saveFavoriteLuts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoriteLuts', _favoriteLuts.toList());
  }

  Future<void> _addLutToFavorites(String lutName) async {
    setState(() {
      _favoriteLuts.add(lutName);
    });
    await _saveFavoriteLuts();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$lutName" to favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
  
  Future<void> _removeLutFromFavorites(String lutName) async {
    setState(() {
      _favoriteLuts.remove(lutName);
    });
    await _saveFavoriteLuts();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$lutName" from favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
  
  List<LutItem> _getFilteredLuts() {
    List<LutItem> lutsToShow;
    
    if (_lutFilterMode == 'favorites') {
      lutsToShow = _availableLuts.where((lut) => _favoriteLuts.contains(lut.displayName)).toList();
    } else {
      lutsToShow = _availableLuts;
    }
    
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return lutsToShow;
    }
        
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    final filtered = lutsToShow.where((lut) {
      final matches = _matchesSearch(lut.displayName, _searchQuery, excludeList);
      if (_searchQuery.length <= 3) {
        print('DEBUG checking "${lut.displayName}" against "$_searchQuery" = $matches');
      }
      return matches;
    }).toList();
    
    return filtered;
  }
  
  Color _applyLutToColor(Color color) {
    if (_loadedLutData == null) return color;
    
    try {
      final imgColor = img.ColorRgb8(color.red, color.green, color.blue);
      final transformed = LutProcessor.lookupLut(imgColor, _loadedLutData!);
      
      return Color.fromARGB(255, transformed.r.toInt(), transformed.g.toInt(), transformed.b.toInt());
    } catch (e) {
      print('Error applying LUT: $e');
      return color;
    }
  }

  Future<void> _setCustomFontDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    
    CustomFontLoader.customFonts.clear();
    
    setState(() {
      _customFontDirectory = result;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('customFontDirectory', result);
    await CustomFontLoader.loadCustomFonts(result);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loaded ${CustomFontLoader.customFonts.length} custom fonts. Restart to fully apply.'),
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
      await CustomFontLoader.loadCustomFonts(savedDir);
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
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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

  bool _matchesSearch(String text, String query, List<String> excludeTerms, {bool? useAnd}) {
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
      final pattern = RegExp(r'\b' + RegExp.escape(exactWord) + r'\b', caseSensitive: false);
      if (!pattern.hasMatch(lowerText)) {
        return false;
      }
    }
    
    if (terms.isEmpty) return (exactWords.isNotEmpty || exactPhrases.isNotEmpty);
    
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
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _history.where((item) {
      final searchText = '${item.audiobookTitle} ${item.chapterTitle}';
      return _matchesSearch(searchText, _searchQuery, excludeList);
    }).toList();
  }

  List<String> _getFilteredPlaylist() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _playlist;
    }
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _playlist.where((filePath) {
      final fileName = path.basename(filePath);
      return _matchesSearch(fileName, _searchQuery, excludeList);
    }).toList();
  }

  List<Bookmark> _getFilteredBookmarks() {
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return _bookmarks;
    }
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return _bookmarks.where((bookmark) {
      final searchText = '${bookmark.audiobookTitle} ${bookmark.chapterTitle} ${bookmark.note ?? ''}';
      return _matchesSearch(searchText, _searchQuery, excludeList);
    }).toList();
  }

  List<SubtitleCue> _parseVTT(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
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
          milliseconds: milliseconds
        );
      } else if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) 
            : 0;
        return Duration(
          minutes: minutes, 
          seconds: seconds, 
          milliseconds: milliseconds
        );
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
        final milliseconds = secondsParts.length > 1 ? int.parse(secondsParts[1]) : 0;
        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
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
            
      if (activeIndex != null && _currentSecondarySubtitleIndex != activeIndex) {
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
          if (_secondarySubtitleFont == 'System Default' && _selectedFont != 'System Default') {
            _secondarySubtitleFont = _selectedFont;
          }
          if (_secondaryColorPalette == null && _currentColorPalette != null) {
            _secondaryColorPalette = _currentColorPalette;
          }
          if (_secondarySubtitleFontSize == 86.0) {
            _secondarySubtitleFontSize = _subtitleFontSize;
          }
        });
        
        await _applySecondaryConversion();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${_secondarySubtitles.length} secondary subtitle cues'),
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
      String convertedContent = content;
      
      switch (_secondaryConversionType) {
        case 'demo':
          convertedContent = await SubtitleTransformer.convertToDemoInMemory(content, _secondarySubtitleFont);
          break;
        case 'demoUpper':
          convertedContent = await SubtitleTransformer.convertToDemoUpperInMemory(content, _secondarySubtitleFont);
          break;
        case 'alternates':
          convertedContent = await SubtitleTransformer.convertToAlternatesInMemory(content, _secondarySubtitleFont);
          break;
        case 'missing':
          convertedContent = await SubtitleTransformer.fixMissingLigaturesInMemory(content, _secondarySubtitleFont);
          break;
        case 'uppercase':
          convertedContent = SubtitleTransformer.convertToUppercaseInMemory(content);
          break;
        case 'seesawcase':
          convertedContent = SubtitleTransformer.convertToSeesawCaseInMemory(content);
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

  double _calculateDynamicFontSize(String text, double baseFontSize) {
    final textLength = _getEffectiveTextLength(text);
    
    double multiplier = 1.0;
    
    if (textLength >= 1 && textLength <= 60) {
      final effectiveLength = textLength < 10 ? 10 : textLength;
      multiplier = 1.0 + ((60 - effectiveLength) / 100.0);
    }
    
    final finalSize = baseFontSize * multiplier;
    
    if (text != _lastDebuggedSubtitle) {
      // print(' Font Adjust: len=$textLength, base=$baseFontSize, ×${multiplier.toStringAsFixed(3)} = ${finalSize.toStringAsFixed(1)}');
      _lastDebuggedSubtitle = text;
    }
    
    return finalSize;
  }

  int _getEffectiveTextLength(String text) {
    final cleanedText = text.replaceAll(RegExp(r'<[^>]+>'), '');
    int length = 0;
    
    for (int i = 0; i < cleanedText.length; i++) {
      final char = cleanedText.codeUnitAt(i);
      // CJK characters (double-byte) count as 2
      if ((char >= 0x4E00 && char <= 0x9FFF) ||   // CJK Unified Ideographs
          (char >= 0x3040 && char <= 0x309F) ||   // Hiragana
          (char >= 0x30A0 && char <= 0x30FF) ||   // Katakana
          (char >= 0xAC00 && char <= 0xD7AF)) {   // Hangul
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
  }) {
    final baseFontSize = fontSize ?? _subtitleFontSize;
    final effectiveFont = fontFamily ?? (_selectedFont == 'System Default' ? null : _selectedFont);
    final effectivePalette = palette ?? _currentColorPalette;
    final effectiveLineSpacing = lineSpacing ?? _subtitleLineSpacing;
    final cleanedText = text.replaceAll(RegExp(r'<[^>]+>'), '');
    final effectiveFontSize = _calculateDynamicFontSize(cleanedText, baseFontSize);
  
    final fontFamilyFallback = effectiveFont != null 
        ? [effectiveFont, 'Scheherazade New']
        : ['Scheherazade New'];
    
    if (effectivePalette == null) {
      return TextSpan(
        text: cleanedText,
        style: TextStyle(
          color: _subtitleTransparencyMode 
              ? Colors.transparent 
              : Colors.black26,
          fontSize: effectiveFontSize,
          height: effectiveLineSpacing,
          fontFamily: effectiveFont,
          fontFamilyFallback: fontFamilyFallback,
          shadows: [
            Shadow(
              offset: Offset(
                    _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? 6.0 : 2.0),
                    _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? 6.0 : 2.0)
                  ),
              blurRadius: 0,
              color: _subtitleTransparencyMode 
                  ? Colors.black26
                  : _parseColor('000000'),
            ),
          ],
        ),
      );
    }
    
    if (effectivePalette.isSimplePreset) {
      final fontColor = _parseColor(effectivePalette.colors[0]);
      final shadowColor = _parseColor(effectivePalette.subShadowColor!);
      
      return TextSpan(
        text: cleanedText,
        style: TextStyle(
          color: _subtitleTransparencyMode 
              ? Colors.black26
              : fontColor,
          fontSize: effectiveFontSize,
          height: effectiveLineSpacing,
          fontFamily: effectiveFont,
          fontFamilyFallback: fontFamilyFallback,
          shadows: [
            Shadow(
              offset: Offset(
                _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? (palette?.shadowOffset ?? 6.0) : 2.0),
                _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? (palette?.shadowOffset ?? 6.0) : 2.0)
              ),
              blurRadius: 0,
              color: _subtitleTransparencyMode
                  ? fontColor
                  : shadowColor,
            ),
          ],
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
      final color = _adjustColorIfBright(effectivePalette.colors[colorIndex]);
      final shadowColor = _parseColor(effectivePalette.shadowColor);
      wordIndex++;
      
      spans.add(TextSpan(
        text: word,
        style: TextStyle(
          color: _subtitleTransparencyMode 
              ? Colors.black26
              : color,
          fontSize: effectiveFontSize,
          height: effectiveLineSpacing,
          fontFamily: effectiveFont,
          fontFamilyFallback: fontFamilyFallback,
          shadows: [
            Shadow(
              offset: Offset(
                _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? (palette?.shadowOffset ?? 6.0) : 2.0),
                _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? (palette?.shadowOffset ?? 6.0) : 2.0)
              ),
              blurRadius: 0,
              color: _subtitleTransparencyMode 
                  ? color
                  : shadowColor,
            ),
          ],
        ),
      ));
      
      if (space.isNotEmpty) {
        spans.add(TextSpan(
          text: space,
          style: TextStyle(
            color: _subtitleTransparencyMode 
                ? Colors.transparent 
                : Colors.black26,
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
          (code >= 0xAC00 && code <= 0xD7AF)) { // Hangul
        hasCJK = true;
      } else if ((code >= 0x0041 && code <= 0x005A) || // A-Z
                 (code >= 0x0061 && code <= 0x007A)) { // a-z
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
    ) {
      final spans = <TextSpan>[];
      int wordIndex = startWordIndex;
      final shadowColor = _parseColor(palette.shadowColor);
      
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
            spans.add(TextSpan(
              text: word,
              style: TextStyle(
                color: _subtitleTransparencyMode ? Colors.black26 : color,
                fontSize: fontSize,
                height: lineSpacing,
                fontFamily: fontFamily,
                fontFamilyFallback: fontFamilyFallback,
                shadows: [
                  Shadow(
                    offset: Offset(
                      _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0),
                      _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0)
                    ),
                    blurRadius: 0,
                    color: _subtitleTransparencyMode ? color : shadowColor,
                  ),
                ],
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
            
            spans.add(TextSpan(
              text: word,
              style: TextStyle(
                color: _subtitleTransparencyMode ? Colors.black26 : color,
                fontSize: fontSize,
                height: lineSpacing,
                fontFamily: fontFamily,
                fontFamilyFallback: fontFamilyFallback,
                shadows: [
                  Shadow(
                    offset: Offset(
                      _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0),
                      _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0)
                    ),
                    blurRadius: 0,
                    color: _subtitleTransparencyMode ? color : shadowColor,
                  ),
                ],
              ),
            ));
            
            if (space.isNotEmpty) {
              spans.add(TextSpan(
                text: space,
                style: TextStyle(
                  color: _subtitleTransparencyMode ? Colors.transparent : Colors.white,
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
    ) {
      final spans = <TextSpan>[];
      int colorIndex = startIndex;
      final shadowColor = _parseColor(palette.shadowColor);
      
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        
        if (char == ' ' || char == '\n' || char == '\t') {
          spans.add(TextSpan(
            text: char,
            style: TextStyle(
              color: _subtitleTransparencyMode ? Colors.transparent : Colors.white,
              fontSize: fontSize,
              height: lineSpacing,
              fontFamily: fontFamily,
              fontFamilyFallback: fontFamilyFallback,
            ),
          ));
          continue;
        }
        
        final color = _adjustColorIfBright(palette.colors[colorIndex % palette.colors.length]);
        colorIndex++;
        
        spans.add(TextSpan(
          text: char,
          style: TextStyle(
            color: _subtitleTransparencyMode ? Colors.black26 : color,
            fontSize: fontSize,
            height: lineSpacing,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            shadows: [
              Shadow(
                offset: Offset(
                  _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0),
                  _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0)
                ),
                blurRadius: 0,
                color: _subtitleTransparencyMode ? color : shadowColor,
              ),
            ],
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
    ) {
      final fontFamilyFallback = fontFamily != null 
            ? [fontFamily, 'Scheherazade New']
            : ['Scheherazade New'];
      final shadowColor = _parseColor(palette.shadowColor);
    
      final words = CJKTokenizer.tokenize(text);
      final spans = <TextSpan>[];
      int wordIndex = startWordIndex;
      for (final word in words) {
        final colorIndex = wordIndex % palette.colors.length;
        final color = _adjustColorIfBright(palette.colors[colorIndex]);
        spans.add(TextSpan(
          text: word,
          style: TextStyle(
            color: _subtitleTransparencyMode ? Colors.black26 : color,
            fontSize: fontSize,
            height: lineSpacing,
            fontFamily: fontFamily,
            fontFamilyFallback: fontFamilyFallback,
            shadows: [
              Shadow(
                offset: Offset(
                  _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0),
                  _subtitleTransparencyMode ? 6.0 : (_subtitleIncreasedShadow ? palette.shadowOffset : 2.0)
                ),
                blurRadius: 0,
                color: _subtitleTransparencyMode ? color : shadowColor,
              ),
            ],
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
  
  int _calculateWordIndexAtPosition(Duration position) {
    if (_subtitles.isEmpty || _currentColorPalette == null || _cueWordStarts.isEmpty) {
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
    if (_activePlaylistIndex == null || _activePlaylistIndex! >= _playlistDirectories.length) {
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
    if (_activePlaylistIndex == null || _activePlaylistIndex! >= _playlistDirectories.length) {
      return;
    }
    final playlistDir = _playlistDirectories[_activePlaylistIndex!];
    final prefs = await SharedPreferences.getInstance();
    final indexKey = 'chapterIndex_$playlistDir';
    final indexData = <String, dynamic>{};
    _playlistChapterIndex.forEach((audioPath, chapters) {
      indexData[audioPath] = chapters.map((chapter) => {
        'index': chapter.index,
        'title': chapter.title,
        'startTime': chapter.startTime.inMilliseconds,
        'endTime': chapter.endTime.inMilliseconds,
        'duration': chapter.duration.inMilliseconds,
      }).toList();
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
          _indexingStatus = 'Skipping ${path.basename(audioPath)} (already indexed)';
        });
        skippedFiles++;
        await Future.delayed(const Duration(milliseconds: 10));
        continue;
      }
      setState(() {
        _indexedFiles = i + 1;
        _indexingStatus = 'Indexing ${path.basename(audioPath)} ($i/${_playlist.length})';
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
          content: Text(
            'Chapter indexing complete!\n'
            'Total: ${_playlist.length} audiobooks\n'
            'New: $newFiles, Skipped: $skippedFiles\n'
            'Time: ${minutes}m ${seconds}s'
          ),
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
    final excludeList = _chapterExcludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    _playlistChapterIndex.forEach((audioPath, chapters) {
      final audioTitle = path.basenameWithoutExtension(audioPath);
      for (int i = 0; i < chapters.length; i++) {
        final chapter = chapters[i];
        if (_matchesSearch(chapter.title, query, excludeList, useAnd: _chapterSearchUseAnd)) {
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
        _shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path)),
      );
      if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
        await _statsManager.flushCacheToLog();
      }
      
      final chapter = _currentAudiobook!.chapters[_currentChapterIndex - 1];
      await _seekTo(chapter.startTime);
      if (_currentAudiobook != null && !_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
        _statsManager.recordChapterStart();
      }
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
        _shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path)),
      );
      if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
        await _statsManager.flushCacheToLog();
      }
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
    if (_currentAudiobook != null && !_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
    _statsManager.recordChapterStart();
    }
    if (_isPlaying) {
      _statsManager.onPlaybackStart();
    }
  }
  
  Future<void> _jumpToChapter(int index) async {
    if (_currentAudiobook != null && index >= 0 && index < _currentAudiobook!.chapters.length) {
      if (_currentChapterIndex != index) {
        final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
        await _statsManager.recordChapterEnd(
          path.basenameWithoutExtension(_currentAudiobook!.path),
          currentChapter.title,
          _shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path)),
        );
        if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
          _statsManager.flushCacheToLog();
        }
      }
      final chapter = _currentAudiobook!.chapters[index];
      await _seekTo(chapter.startTime);
      setState(() {
        _currentChapterIndex = index;
        _showPanel = false;
      });
      if (_currentAudiobook != null && !_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
      _statsManager.recordChapterStart();
      }
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
      milliseconds: newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds)
    );
    await _seekTo(clampedPosition);
  }
  
  Future<void> _skipBackward() async {
    final newPosition = _currentPosition - const Duration(seconds: 10);
    final clampedPosition = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds)
    );
    await _seekTo(clampedPosition);
  }

  Future<void> _skipBackward1() async {
    final newPosition = _currentPosition - const Duration(seconds: 1);
    final clampedPosition = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds)
    );
    
    await _seekTo(clampedPosition);
    
    final replayStart = clampedPosition - const Duration(milliseconds: 900);
    final safeReplayStart = replayStart < Duration.zero ? Duration.zero : replayStart;
    
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
      milliseconds: newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds)
    );
    
    final replayStart = clampedPosition - const Duration(milliseconds: 900);
    final safeReplayStart = replayStart < Duration.zero ? Duration.zero : replayStart;
    
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
      milliseconds: newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds)
    );
    await _seekTo(clampedPosition);
  }
  
  Future<void> _skipBackward3() async {
    final newPosition = _currentPosition - const Duration(seconds: 3);
    final clampedPosition = Duration(
      milliseconds: newPosition.inMilliseconds.clamp(0, _totalDuration.inMilliseconds)
    );
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
  

  void _setInPoint() {
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
    
    await _sliceCut();
  }
  
  Future<void> _sliceCut() async {
    if (_inPoint == null || _outPoint == null || _currentAudiobook == null) return;
    
    final audiobookDir = path.dirname(_currentAudiobook!.path);
    final audiobookName = path.basenameWithoutExtension(_currentAudiobook!.path);
    
    final cutsDir = path.join(audiobookDir, '${audiobookName}_cuts');
    await Directory(cutsDir).create(recursive: true);
    
    String chapterName = 'Unknown';
    for (final chapter in _currentAudiobook!.chapters) {
      if (_inPoint! >= chapter.startTime && _inPoint! < chapter.endTime) {
        chapterName = chapter.title;
        break;
      }
    }
    
    String formatTime(Duration d) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      final seconds = d.inSeconds.remainder(60);
      return '${hours.toString().padLeft(2, '0')}∶${minutes.toString().padLeft(2, '0')}∶${seconds.toString().padLeft(2, '0')}';
    }
    
    final inTimeStr = formatTime(_inPoint!);
    final outTimeStr = formatTime(_outPoint!);
    
    final cutName = '$inTimeStr-$outTimeStr ($chapterName).opus';
    final outputPath = path.join(cutsDir, cutName);
    
    final duration = _outPoint! - _inPoint!;
    
    try {
      await _ffmpeg.ensureBinaries();
      
      if (_ffmpeg.ffmpegPath == null) {
        throw Exception('FFmpeg not found');
      }
  
      final args = [
        _ffmpeg.ffmpegPath!,
        '-y',
        '-ss', (_inPoint!.inMilliseconds / 1000).toStringAsFixed(3),
        '-i', _currentAudiobook!.path,
        '-t', (duration.inMilliseconds / 1000).toStringAsFixed(3),
        '-vn',
        '-sn',
        '-c:a', 'copy',
        '-avoid_negative_ts', 'make_zero',
        '-fflags', '+genpts+igndts',
        outputPath,
      ];
  
      print('Slicing: ${_formatDurationWithMs(_inPoint!)} → ${_formatDurationWithMs(_outPoint!)}');
  
      final process = await Process.start(args[0], args.sublist(1));
      
      await process.stderr.drain();
      await process.stdout.drain();
      
      final exitCode = await process.exitCode;
      
      if (exitCode != 0) {
        throw Exception('FFmpeg slicing failed');
      }
  
      if (!await File(outputPath).exists()) {
        throw Exception('Output file was not created');
      }
  
      final fileSize = await File(outputPath).length();
      print('Created: ${path.basename(outputPath)} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cut saved: ${_formatDuration(duration)}'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      setState(() {
        _inPoint = null;
        _outPoint = null;
      });
      
    } catch (e) {
      print('ERROR: Failed to slice cut: $e');
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
    
    final bitrateKbps = ((_fileSize * 8) / _totalDuration.inSeconds / 1000).floor();
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
          allowedExtensions: ['opus'],
          initialDirectory: initialDir,
        );
        if (result == null || result.files.isEmpty) {
          return;
        }
        selectedPath = result.files.first.path!;
      }
  
      if (!await File(selectedPath).exists()) {
        print('File no longer exists: $selectedPath');
        
        final historyIndex = _history.indexWhere((h) => h.audiobookPath == selectedPath);
        if (historyIndex != -1) {
          await _removeFromHistory(historyIndex);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File no longer exists and was removed from history'),
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

  if (_currentAudiobook != null && _currentAudiobook!.path != selectedPath) {
    if (_currentAudiobook!.chapters.isNotEmpty) {
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
        await _statsManager.recordChapterEnd(
          path.basenameWithoutExtension(_currentAudiobook!.path),
          currentChapter.title,
          false,
        );
        await _statsManager.flushCacheToLog();
      }
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
  
  int chapterToLoad = historyItem.lastChapter.clamp(0, metadata.chapters.length - 1);
  Duration positionToLoad = historyItem.lastPosition;
  
  final loadedChapter = metadata.chapters[chapterToLoad];
  if (_shouldSkipChapter(loadedChapter.title)) {
    print('Loaded chapter should be skipped, finding next valid chapter...');
    
    for (int i = chapterToLoad; i < metadata.chapters.length; i++) {
      if (!_shouldSkipChapter(metadata.chapters[i].title)) {
        chapterToLoad = i;
        positionToLoad = metadata.chapters[i].startTime;
        print('Will skip to chapter ${i + 1}: ${metadata.chapters[i].title}');
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

      if (_currentAudiobook != null && !_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
        _statsManager.recordChapterStart();
      }
      
      if (_isPlaying) {
        _statsManager.onPlaybackStart();
      }
      
      await _calculateBitrate();
      
      _cacheSingleFileDuration(selectedPath);
      
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
        final vttPath = subtitlePath.replaceAll(RegExp(r'\.srt$', caseSensitive: false), '.vtt');
        
        if (!await File(vttPath).exists()) {
          final srtContent = await File(subtitlePath).readAsString();
          final vttContent = _convertSrtToVtt(srtContent);
          await File(vttPath).writeAsString(vttContent);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Converted SRT to VTT: ${path.basename(vttPath)}'),
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
      _updateCurrentSubtitle();
      _scheduleFrequencyGeneration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded ${_subtitles.length} subtitle cues from ${path.basename(subtitlePath)}'),
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

  void _onEditingMenuSelected(BuildContext context, String value) {
    switch (value) {
      case 'set_in':
        _setInPoint();
        break;
      case 'set_out':
        _setOutPoint();
        break;
      case 'seekToSubtitleEnd':
        _setOutPoint();
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

  Future<void> _navigateFonts(int direction) async {
    final filteredFonts = _getFilteredFonts();
    if (filteredFonts.isEmpty) return;
    setState(() {
      _selectedFontIndex = (_selectedFontIndex + direction).clamp(0, filteredFonts.length - 1).toInt();
      _selectedFont = filteredFonts[_selectedFontIndex];
    });
    _scrollToSelectedFont();
    await _saveFontSettings();
    
    if (_autoConvertAlternates && FontAlternatesData.hasFontAlternates(_selectedFont)) {
      setState(() {
        _conversionType = 'alternates';
      });
      await _applyConversion();
    } else if (_autoConvertMissing) {
      final metadata = FontDatabase.getMetadata(_selectedFont);
      if (metadata != null && metadata.hasMissingLigatures()) {
        setState(() {
          _conversionType = 'missing';
        });
        await _applyConversion();
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
        final targetOffset = (itemTop) - (viewportHeight / 2) + (itemHeight / 2);
        final maxScroll = _fontScrollController.position.maxScrollExtent;
        final minScroll = _fontScrollController.position.minScrollExtent;
        final clampedScroll = targetOffset.clamp(minScroll, maxScroll);
        _fontScrollController.animateTo(
          clampedScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      } else if (itemBottom > viewportBottom) {
        final targetOffset = (itemTop) - (viewportHeight / 2) + (itemHeight / 2);
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
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && _showPanel && _panelMode == PanelMode.subs && _searchFocusNode.hasFocus) {
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
            _skipTrackingFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyV && 
              (HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed)) {
            return KeyEventResult.ignored;
          }
  
         if (event.logicalKey == LogicalKeyboardKey.escape && event is KeyDownEvent) {
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
          } else if (event.logicalKey == LogicalKeyboardKey.keyC && 
                   HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
            _copyChaptersList();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyC && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.chapters;
            });
            _scrollToCurrentChapter();
            return KeyEventResult.handled;
         } else if (event.logicalKey == LogicalKeyboardKey.keyU && 
                    HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
           _copyCurrentSubtitleInMemory();
           return KeyEventResult.handled;
         } else if (event.logicalKey == LogicalKeyboardKey.keyU && event is KeyDownEvent) {
           _copyCurrentSubtitle();
           return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.keyH && 
                       HardwareKeyboard.instance.isShiftPressed && 
                       event is KeyDownEvent) {
              setState(() {
                _hideChapterTitle = !_hideChapterTitle;
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyH && event is KeyDownEvent) {
              setState(() {
                _showPanel = true;
                _panelMode = PanelMode.history;
              });
              _scrollToTopOfHistory();
              return KeyEventResult.handled;        
          } else if (event.logicalKey == LogicalKeyboardKey.keyP && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.playlist;
            });
            _scrollToCurrentPlaylistItem();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              if (event is KeyDownEvent) {
                setState(() {
                  _subtitleIncreasedShadow = !_subtitleIncreasedShadow;
                });
              }
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent) {
              setState(() {
                _showPanel = true;
                _panelMode = PanelMode.bookmarks;
              });
              _scrollToTopOfHistory();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF && 
                      HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
            _addFontToFavorites(_selectedFont);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.fonts;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyR && 
                      HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
            if (_currentColorPalette != null) {
              _addColorPaletteToFavorites(_currentColorPalette!.name);
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyR && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.colors;
              _showingLuts = false;
            });
            if (_availableLuts.isEmpty) {
               _scanAvailableLuts();
             }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyW && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.words;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.subs;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyT && 
                      HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
            setState(() {
              _subtitleTransparencyMode = !_subtitleTransparencyMode;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyT && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.stats;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.slash && event is KeyDownEvent) {
            if (_showPanel) {
              if (_panelMode == PanelMode.subs) {
                _searchFocusNode.requestFocus();
              } else if (_panelMode != PanelMode.words) {
                _searchFocusNode.requestFocus();
              }
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.backspace && 
                     (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) &&
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
          } else if ((event.logicalKey == LogicalKeyboardKey.digit0 || event.logicalKey == LogicalKeyboardKey.numpad0) && event is KeyDownEvent) {
            _adhanClockService.stopAdhan();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyG && event is KeyDownEvent) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              setState(() {
                _pauseMode = PauseMode.disabled;
                _nextPauseTime = null;
                _pauseModeTimer?.cancel();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pause Mode: Disabled'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            } else {
              setState(() {
                _pauseMode = PauseMode.pause2s;
                if (_currentSubtitleIndex != null && _currentSubtitleIndex! < _subtitles.length) {
                  final cue = _subtitles[_currentSubtitleIndex!];
                  _nextPauseTime = cue.endTime - const Duration(milliseconds: 200);
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
          } else if (event.logicalKey == LogicalKeyboardKey.keyL && HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
              _openAudiobookDirectory();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyL && event is KeyDownEvent) {
              _openAudiobook();
              return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyM && 
                   HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
            _copyCurrentMetadata();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyM && event is KeyDownEvent) {
            setState(() {
              _showAdhanOverlay = !_showAdhanOverlay;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.bracketLeft && event is KeyDownEvent) {
            _decreaseSpeed();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.bracketRight && event is KeyDownEvent) {
            _increaseSpeed();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY && 
                   HardwareKeyboard.instance.isShiftPressed && 
                   event is KeyDownEvent) {
            if (Platform.isAndroid || Platform.isIOS) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('YouTube audio streaming is only available on desktop'),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              _showYouTubeDialog();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY && event is KeyDownEvent) {
            _toggleFullscreen();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyZ && 
                   HardwareKeyboard.instance.isShiftPressed && event is KeyDownEvent) {
            _setSleepTimer(null);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyZ && event is KeyDownEvent) {
            _setSleepTimer(Duration.zero);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyQ && event is KeyDownEvent) {
            _setCurrentAsDefault();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.equal && event is KeyDownEvent) {
            _showGlyphViewerOverlay();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyA && event is KeyDownEvent) {
            _applyDefaultSettings();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.backquote && event is KeyDownEvent) {
            if (_showPanel) {
              setState(() {
                _panelCollapsed = !_panelCollapsed;
              });
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
            setState(() {
              _showEncoderScreen = true;
            });
            return KeyEventResult.handled;
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
                      if (_currentSubtitleIndex != null && _currentSubtitleIndex! < _subtitles.length) {
                        final cue = _subtitles[_currentSubtitleIndex!];
                        _nextPauseTime = cue.endTime - const Duration(milliseconds: 200);
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
               _subtitleLineSpacing = ((_subtitleLineSpacing * 100).round() + 1) / 100;
               _subtitleLineSpacing = _subtitleLineSpacing.clamp(0.5, 2.5);
             });
             return KeyEventResult.handled;
           } else if (HardwareKeyboard.instance.isShiftPressed) {
             return KeyEventResult.ignored;
           } else if (_showPanel && _panelMode == PanelMode.colors) {
             if (_showingLuts) {
               _navigateLuts(-1);
             } else {
               _navigateColors(-1);
             }
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
               _subtitleLineSpacing = ((_subtitleLineSpacing * 100).round() - 1) / 100;
               _subtitleLineSpacing = _subtitleLineSpacing.clamp(0.5, 2.5);
             });
             return KeyEventResult.handled;
           } else if (HardwareKeyboard.instance.isShiftPressed) {
             return KeyEventResult.ignored;
           } else if (_showPanel && _panelMode == PanelMode.colors) {
             if (_showingLuts) {
               _navigateLuts(1);
             } else {
               _navigateColors(1);
             }
             return KeyEventResult.handled;
           } else if (_showPanel && _panelMode == PanelMode.fonts) {
             _navigateFonts(1);
             return KeyEventResult.handled;
           } else {
             _decreaseFontSize();
             return KeyEventResult.handled;
           }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _previousChapter();
              return KeyEventResult.handled;
            } else if (_subtitles.isNotEmpty) {
              _skipToPreviousSubtitle();
            } else {
              _skipBackward3();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _nextChapter();
              return KeyEventResult.handled;
            } else if (_subtitles.isNotEmpty) {
              _skipToNextSubtitle();
            } else {
              _skipForward3();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyI && event is KeyDownEvent) {
            _setInPoint();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyO && event is KeyDownEvent) {
            _setOutPoint();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.semicolon && event is KeyDownEvent) {
            _seekToSubtitleEnd();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyJ && event is KeyDownEvent) {
            _skipBackward1();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyK && event is KeyDownEvent) {
            _skipForward1();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.comma && event is KeyDownEvent) {
            _replaySegmentBack();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.period && event is KeyDownEvent) {
            _replaySegmentForward();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyN && event is KeyDownEvent) {
            _addBookmark();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyV && event is KeyDownEvent) {
            _openSubtitleManager();
            return KeyEventResult.handled;
          } else if (_showPanel && _panelMode == PanelMode.bookmarks) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
              _jumpToPinnedBookmark(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
              _jumpToPinnedBookmark(2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
              setState(() {
                _colorFilterMode = 'all';
                _showingLuts = false;
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
              setState(() {
                _colorFilterMode = 'favorites';
                _showingLuts = false;
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
              _jumpToPinnedBookmark(5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) {
              _jumpToPinnedBookmark(6);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) {
              _jumpToPinnedBookmark(7);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit8 || event.logicalKey == LogicalKeyboardKey.numpad8) {
              _jumpToPinnedBookmark(8);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit9 || event.logicalKey == LogicalKeyboardKey.numpad9) {
              _jumpToPinnedBookmark(9);
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.history) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
              _jumpToHistoryItem(0);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
              _jumpToHistoryItem(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
              _jumpToHistoryItem(2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
              _jumpToHistoryItem(3);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
              _jumpToHistoryItem(4);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) {
              _jumpToHistoryItem(5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) {
              _jumpToHistoryItem(6);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit8 || event.logicalKey == LogicalKeyboardKey.numpad8) {
              _jumpToHistoryItem(7);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit9 || event.logicalKey == LogicalKeyboardKey.numpad9) {
              _jumpToHistoryItem(8);
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.playlist) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
              _jumpToPlaylistItem(0);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
              _jumpToPlaylistItem(1);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
              _jumpToPlaylistItem(2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
              _jumpToPlaylistItem(3);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
              _jumpToPlaylistItem(4);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) {
              _jumpToPlaylistItem(5);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) {
              _jumpToPlaylistItem(6);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit8 || event.logicalKey == LogicalKeyboardKey.numpad8) {
              _jumpToPlaylistItem(7);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit9 || event.logicalKey == LogicalKeyboardKey.numpad9) {
              _jumpToPlaylistItem(8);
              return KeyEventResult.handled;
            }
          } else if (_showPanel && _panelMode == PanelMode.fonts) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
              _resetConversion();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
              _convertToDemo();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
              _convertToDemoUpper();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
              _convertToAlternates();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
              _convertToMissing();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) {
              _convertToUppercase();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) {
              _convertToSeesawCase();
              return KeyEventResult.handled;
            }
            } else if (_showPanel && _panelMode == PanelMode.colors) {
              if (event.logicalKey == LogicalKeyboardKey.digit1 || event.logicalKey == LogicalKeyboardKey.numpad1) {
                setState(() {
                  _coloringMode = ColoringMode.words;
                  _showingLuts = false;
                });
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit2 || event.logicalKey == LogicalKeyboardKey.numpad2) {
                setState(() {
                  _coloringMode = ColoringMode.letters;
                  _showingLuts = false;
                });
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit3 || event.logicalKey == LogicalKeyboardKey.numpad3) {
                setState(() {
                  _colorFilterMode = 'all';
                  _showingLuts = false;
                });
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
                setState(() {
                  _colorFilterMode = 'favorites';
                  _showingLuts = false;
                });
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit5 || event.logicalKey == LogicalKeyboardKey.numpad5) {
                setState(() {
                  _lutFilterMode = 'all';
                  _showingLuts = true;
                });
                if (_availableLuts.isEmpty) {
                  _scanAvailableLuts();
                }
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit6 || event.logicalKey == LogicalKeyboardKey.numpad6) {
                setState(() {
                  _lutFilterMode = 'favorites';
                  _showingLuts = true;
                });
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.digit7 || event.logicalKey == LogicalKeyboardKey.numpad7) {
                if (event is KeyDownEvent) {
                  setState(() {
                    _selectedLutName = null;
                    _loadedLutData = null;
                    _selectedLutPath = null;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('LUT removed'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
                return KeyEventResult.handled;
              }
          } else if (event.logicalKey == LogicalKeyboardKey.keyX && event is KeyDownEvent) {
            if (_primarySubtitlePath != null || _secondarySubtitlePath != null) {
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
              
              if (_showPanel && (_currentAudiobook != null || 
                  _isYouTubeStream ||
                  _panelMode == PanelMode.history || 
                  _panelMode == PanelMode.playlist || 
                  _panelMode == PanelMode.bookmarks || 
                  _panelMode == PanelMode.stats))
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
                  isExportingMarkdown: _isExportingMarkdown,
                  exportStatus: _exportStatus,
                  onExportMarkdown: _exportMarkdownParagraphs,
                  onClose: () {
                    setState(() {
                      _showPanel = false;
                    });
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
                    } else if (mode == PanelMode.history || mode == PanelMode.bookmarks) {
                      _scrollToTopOfHistory();
                    } else if (mode == PanelMode.colors) {
                      if (_showingLuts) {
                        _scrollToSelectedLut();
                      } else {
                        _scrollToSelectedColorPalette();
                      }
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
                      if (_autoConvertAlternates && FontAlternatesData.hasFontAlternates(fontName)) {
                        setState(() {
                          _conversionType = 'alternates';
                        });
                        await _applyConversion();
                      } else if (_autoConvertMissing) {
                        final metadata = FontDatabase.getMetadata(fontName);
                        if (metadata != null && metadata.hasMissingLigatures()) {
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
                  colorScrollController: _colorScrollController,
                  onColorPaletteSelected: (palette, index) {
                    setState(() {
                      _selectedColorIndex = index;
                    });
                    _applyColorPalette(palette);
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
                  onRemoveColorPaletteFavorite: _removeColorPaletteFromFavorites,
                  onAddColorPaletteFavorite: _addColorPaletteToFavorites,

                  showingLuts: _showingLuts,
                  lutFilterMode: _lutFilterMode,
                  availableLuts: _availableLuts,
                  onToggleLutMode: (show) {
                    setState(() {
                      _showingLuts = show;
                    });
                    if (show) {
                      _scrollToSelectedLut();
                    } else {
                      _scrollToSelectedColorPalette();
                    }
                  },
                  onLutFilterChanged: (mode) {
                    setState(() {
                      _lutFilterMode = mode;
                    });
                  },
                  getFilteredLuts: _getFilteredLuts,
                  onLutSelected: (lut, index) async {
                    final actualIndex = _availableLuts.indexWhere((l) => l.path == lut.path);
                    setState(() {
                      _selectedLutIndex = actualIndex;
                    });
                    if (lut.path.isEmpty) {
                      setState(() {
                        _selectedLutName = null;
                        _loadedLutData = null;
                        _selectedLutPath = null;
                      });
                    } else {
                      await _selectLut(lut.path, lut.displayName);
                    }
                  },
                  selectedLutIndex: _selectedLutIndex,
                  favoriteLuts: _favoriteLuts,
                  onAddLutFavorite: _addLutToFavorites,
                  onRemoveLutFavorite: _removeLutFromFavorites,
                  
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
                  statsCount: _statsManager.statsEntries.where((entry) {
                    if (_skipTrackingTerms.trim().isEmpty) return true;
                    final filename = (entry['filename'] as String? ?? '').toLowerCase();
                    final skipTerms = _skipTrackingTerms
                        .toLowerCase()
                        .split(' ')
                        .where((t) => t.isNotEmpty)
                        .toList();
                    for (final term in skipTerms) {
                      if (filename.contains(term)) return false;
                    }
                    return true;
                  }).length,
                  statsEntries: _statsManager.statsEntries.where((entry) {
                    if (_skipTrackingTerms.trim().isEmpty) return true;
                    final filename = (entry['filename'] as String? ?? '').toLowerCase();
                    final skipTerms = _skipTrackingTerms
                        .toLowerCase()
                        .split(' ')
                        .where((t) => t.isNotEmpty)
                        .toList();
                    for (final term in skipTerms) {
                      if (filename.contains(term)) return false;
                    }
                    return true;
                  }).toList(),
                  statsEnabled: _statsManager.statsEnabled,
                  onStatsEnabledChanged: (value) {
                    _statsManager.saveStatsEnabled(value);
                  },
                  onRefreshStats: () {
                    _statsManager.loadAllStatsEntries();
                  },
                  skipTrackingTerms: _skipTrackingTerms,
                  skipTrackingController: _skipTrackingController,
                  skipTrackingFocusNode: _skipTrackingFocusNode,
                  onSkipTrackingChanged: (value) {
                    setState(() {
                      _skipTrackingTerms = value;
                    });
                    _saveSkipTrackingTerms();
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
                ),
              
              if (_showWordOverlay && _currentSubtitleText.isNotEmpty)
                WordOverlay(
                  subtitle: _currentSubtitleIndex != null && _currentSubtitleIndex! < _originalSubtitles.length
                      ? _originalSubtitles[_currentSubtitleIndex!].text
                      : _currentSubtitleText,
                  colorPalette: _currentColorPalette?.colors,
                  startWordIndex: _calculateWordIndexAtPosition(_currentPosition),
                  onClose: () {
                    setState(() {
                      _showWordOverlay = false;
                    });
                    
                    _dictionaryModeExitTimer?.cancel();
                    _dictionaryModeExitTimer = Timer(const Duration(seconds: 3), () {
                      if (!_showWordOverlay && _pauseMode == PauseMode.dictionary) {
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
              
              if (_showSleepTimerCountdown)
                _buildSleepTimerCountdown(),
            ],
          ),
        ),
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

  void _navigateColors(int direction) {
    final filteredColors = _getFilteredColors();
    if (filteredColors.isEmpty) return;
    final currentPalette = _selectedColorIndex >= 0 && _selectedColorIndex < ColorPalette.presets.length
        ? ColorPalette.presets[_selectedColorIndex]
        : null;
    int filteredIndex = currentPalette != null ? filteredColors.indexOf(currentPalette) : 0;
    if (filteredIndex == -1) filteredIndex = 0;
    filteredIndex = (filteredIndex + direction).clamp(0, filteredColors.length - 1);
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
    
    final currentLut = _selectedLutIndex >= 0 && _selectedLutIndex < _availableLuts.length
        ? _availableLuts[_selectedLutIndex]
        : null;
    
    int filteredIndex = currentLut != null ? filteredLuts.indexOf(currentLut) : 0;
    if (filteredIndex == -1) filteredIndex = 0;
    
    filteredIndex = (filteredIndex + direction).clamp(0, filteredLuts.length - 1);
    
    final newLut = filteredLuts[filteredIndex];
    final actualIndex = _availableLuts.indexOf(newLut);
    
    setState(() {
      _selectedLutIndex = actualIndex;
    });
    
    _selectLut(newLut.path, newLut.displayName);
    _scrollToSelectedLut();
  }
  
  void _scrollToSelectedLut() {
    if (!_colorScrollController.hasClients) return;
    
    final filteredLuts = _getFilteredLuts();
    final currentLut = _selectedLutIndex >= 0 && _selectedLutIndex < _availableLuts.length
        ? _availableLuts[_selectedLutIndex]
        : null;
    
    if (currentLut == null) return;
    
    final filteredIndex = filteredLuts.indexOf(currentLut);
    if (filteredIndex == -1) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_colorScrollController.hasClients) return;
      
      const itemHeight = 56.0;
      final viewportHeight = _colorScrollController.position.viewportDimension;
      final currentScroll = _colorScrollController.offset;
      final itemTop = filteredIndex * itemHeight;
      final itemBottom = itemTop + itemHeight;
      final viewportTop = currentScroll;
      final viewportBottom = currentScroll + viewportHeight;
      
      if (itemTop < viewportTop || itemBottom > viewportBottom) {
        final targetOffset = (itemTop) - (viewportHeight / 2) + (itemHeight / 2);
        final maxScroll = _colorScrollController.position.maxScrollExtent;
        final minScroll = _colorScrollController.position.minScrollExtent;
        final clampedScroll = targetOffset.clamp(minScroll, maxScroll);
        
        _colorScrollController.animateTo(
          clampedScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }
  
  void _scrollToSelectedColor() {
    if (!_colorScrollController.hasClients) return;
    final filteredColors = _getFilteredColors();
    final currentPalette = _selectedColorIndex >= 0 && _selectedColorIndex < ColorPalette.presets.length
        ? ColorPalette.presets[_selectedColorIndex]
        : null;
    if (currentPalette == null) return;
    final filteredIndex = filteredColors.indexOf(currentPalette);
    if (filteredIndex == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_colorScrollController.hasClients) return;
      const itemHeight = 56.0;
      final viewportHeight = _colorScrollController.position.viewportDimension;
      final currentScroll = _colorScrollController.offset;
      final itemTop = filteredIndex * itemHeight;
      final itemBottom = itemTop + itemHeight;
      final viewportTop = currentScroll;
      final viewportBottom = currentScroll + viewportHeight;
      if (itemTop < viewportTop || itemBottom > viewportBottom) {
        final targetOffset = (itemTop) - (viewportHeight / 2) + (itemHeight / 2);
        final maxScroll = _colorScrollController.position.maxScrollExtent;
        final minScroll = _colorScrollController.position.minScrollExtent;
        final clampedScroll = targetOffset.clamp(minScroll, maxScroll);
        _colorScrollController.animateTo(
          clampedScroll,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Widget _buildPlayer() {
    return PlayerControls(
      audiobook: _currentAudiobook ?? AudiobookMetadata(
        path: '',
        title: _youtubeTitle ?? 'YouTube Audio',
        author: _youtubeChannelName ?? 'Unknown',
        year: '',
        duration: Duration.zero,
        chapters: [],
      ),
      currentChapterIndex: _isYouTubeStream ? 0 : _currentChapterIndex,
      currentPosition: _currentPosition,
      totalDuration: _totalDuration,
      isPlaying: _isPlaying,
      playbackSpeed: _playbackSpeed,
      selectedLutName: _selectedLutName,
      fileSize: _fileSize,
      averageBitrate: _averageBitrate,
      shuffleEnabled: _shuffleEnabled,
      conversionType: _displayConversionType,
      currentAudioFormat: _currentAudioFormat,
      playedChapters: _isYouTubeStream 
          ? []
          : _currentAudiobook?.chapters.where((c) => _playedChapters.contains(_currentAudiobook!.chapters.indexOf(c))).toList() ?? [],
      selectedFont: _selectedFont,
      defaultFont: _defaultFont,
      defaultConversionType: _defaultConversionType,
      defaultColorPalette: _defaultColorPalette,
      currentColorPalette: _currentColorPalette,
      currentSubtitleText: _currentSubtitleText,
      subtitleFontSize: _subtitleFontSize,
      subtitleLineSpacing: _subtitleLineSpacing,
      secondarySubtitleText: _secondarySubtitleText,
      secondarySubtitleFontSize: _secondarySubtitleFontSize,
      secondarySubtitleFont: _secondarySubtitleFont,
      secondaryColorPalette: _secondaryColorPalette,
      secondarySubtitleLineSpacing: _secondarySubtitleLineSpacing,
      sleepDuration: _sleepDuration,
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
          if (totalMillis > 0 && _currentAudiobook != null && _currentAudiobook!.chapters.isNotEmpty) {
            final hoverTime = Duration(
              milliseconds: ((position / sliderWidth) * totalMillis).toInt()
            );
            for (final chapter in _currentAudiobook!.chapters) {
              if (hoverTime >= chapter.startTime && hoverTime < chapter.endTime) {
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
          case 'toggle_shadow_offset':
            setState(() {
              _subtitleIncreasedShadow = !_subtitleIncreasedShadow;
            });
            break;
          case 'toggle_subtitle_dim':
            setState(() {
              _subtitleTransparencyMode = !_subtitleTransparencyMode;
            });
            break;
          case 'hideChapterTitle':
            setState(() {
              _hideChapterTitle = !_hideChapterTitle;
            });
            break;
          case 'copyCurrentSubtitler':
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
            if (_currentSubtitleIndex != null && _currentSubtitleIndex! < _subtitles.length) {
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
      isYouTubeStream: _isYouTubeStream,
      youtubeTitle: _youtubeTitle,
      youtubeChannelName: _youtubeChannelName,
      onShowSubtitlePreferences: _showSubtitlePreferencesDialog,
      onShowDownload: _showDownloadDialog,
      onShowYouTubeDialog: _showYouTubeDialog,
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
    if (_currentSubtitleIndex != null && _currentSubtitleIndex! < _originalSubtitles.length) {
      textToCopy = _originalSubtitles[_currentSubtitleIndex!].text;
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
    if (_currentSubtitleIndex != null && _currentSubtitleIndex! < _subtitles.length) {
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
  
      final metadataResult = await Process.run(_ffmpeg.ffprobePath!, [
        _currentAudiobook!.path,
      ]);
      
      final output = metadataResult.stderr as String;
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
      final clipboardText = '$artist - $finalTitle ($year) $ltr$formattedFileSize $formattedDuration';
      
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
              'Saved to: ${path.basename(chaptersPath)}'
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Copied to clipboard but failed to save file: $e'
            ),
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
  
  Future<void> _convertToAlternates() async {
    if (_subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load subtitles first')),
      );
      return;
    }
    
    if (!FontAlternatesData.hasFontAlternates(_selectedFont)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No alternates defined for $_selectedFont')),
      );
      return;
    }
    
    setState(() {
      _conversionType = 'alternates';
    });
    
    await _applyConversion();
    await _saveFontSettings();
  }
  
  Future<void> _convertToMissing() async {
    if (_subtitleFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Load subtitles first')),
      );
      return;
    }
    
    final metadata = FontDatabase.getMetadata(_selectedFont);
    if (metadata == null || !metadata.hasMissingLigatures()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_selectedFont does not have missing ligature data')),
      );
      return;
    }
    
    setState(() {
      _conversionType = 'missing';
    });
    
    await _applyConversion();
    await _saveFontSettings();
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

  Future<void> _applyConversion() async {
    if (_subtitleFilePath == null) {
      print('_applyConversion: No subtitle file path');
      return;
    }
    
    if (_isDisposed || !mounted) return;
          
    try {
      final content = await File(_subtitleFilePath!).readAsString();
      if (_isDisposed || !mounted) return;
      
      String convertedContent = content;
      
      switch (_conversionType) {
        case 'demo':
          convertedContent = await SubtitleTransformer.convertToDemoInMemory(content, _selectedFont);
          break;
        case 'demoUpper':
          convertedContent = await SubtitleTransformer.convertToDemoUpperInMemory(content, _selectedFont);
          break;
        case 'alternates':
          convertedContent = await SubtitleTransformer.convertToAlternatesInMemory(content, _selectedFont);
          break;
        case 'missing':
          convertedContent = await SubtitleTransformer.fixMissingLigaturesInMemory(content, _selectedFont);
          break;
        case 'uppercase':
          convertedContent = SubtitleTransformer.convertToUppercaseInMemory(content);
          break;
        case 'seesawcase':
          convertedContent = SubtitleTransformer.convertToSeesawCaseInMemory(content);
          break;
        case 'none':
        default:
          convertedContent = content;
          break;
      }
      
      if (_isDisposed || !mounted) return;
      
      final subtitles = _parseVTT(convertedContent);
      
      if (_isDisposed || !mounted) return;
      
      setState(() {
        _subtitles = subtitles;
      });
      
      _updateCurrentSubtitle();
      
      if (!_isPlaying && _currentSubtitleIndex != null && _currentSubtitleIndex! > 0) {
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
    final terms = _skipChapterTerms.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
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
  
  Future<Map<String, dynamic>> _getHistoryDurationAndProgress(String filePath, Duration lastPosition) async {
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
  
  Future<String> _calculateProgress(String filePath, Duration lastPosition) async {
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
      final percentage = (lastPosition.inSeconds / totalDuration.inSeconds) * 100;
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
      b.created == targetBookmark.created
    );
    
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
        _bookmarks[actualIndex] = _bookmarks[actualIndex].copyWith(clearPin: true);
      } else {
        _bookmarks[actualIndex] = _bookmarks[actualIndex].copyWith(pinNumber: pinNumber);
      }
    });
    
    await _saveBookmarks();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pinNumber == null 
              ? 'Bookmark unpinned: ${targetBookmark.chapterTitle}' 
              : 'Bookmark pinned to $pinNumber: ${targetBookmark.chapterTitle}'
          ),
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
    if (_subtitles.isEmpty) return;
    
    int currentIndex = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].startTime <= _currentPosition && 
          (i == _subtitles.length - 1 || _subtitles[i + 1].startTime > _currentPosition)) {
        currentIndex = i;
        break;
      }
    }
    
    if (currentIndex > 0) {
      final seekPosition = _subtitles[currentIndex - 1].startTime + const Duration(milliseconds: 10);
      await _seekTo(seekPosition);
    } else if (currentIndex == 0) {
      final seekPosition = _subtitles[0].startTime + const Duration(milliseconds: 10);
      await _seekTo(seekPosition);
    }
  }
  
  Future<void> _skipToNextSubtitle() async {
    if (_subtitles.isEmpty) return;
    
    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].startTime > _currentPosition + const Duration(milliseconds: 10)) {
        final seekPosition = _subtitles[i].startTime + const Duration(milliseconds: 10);
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
          (i == _subtitles.length - 1 || _subtitles[i + 1].startTime > _currentPosition)) {
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
    final safeReplayStart = replayStart < Duration.zero ? Duration.zero : replayStart;
    
    await player.seek(safeReplayStart);
    await player.play();
    
    Timer(const Duration(milliseconds: 900), () async {
      await player.pause();
      await player.seek(subtitleEndTime);
    });
  }

  Future<void> _jumpToStatsResult(String filename, String chapterTitle, Duration startTime) async {
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
      final chapterIndex = chapters.indexWhere((ch) => ch.title == chapterTitle);
      
      if (chapterIndex != -1) {
        if (_currentAudiobook?.path != audiobookPath) {
          setState(() {
            _frequencyItems = [];
            _isAnalyzingFrequencies = false;
          });
          await _openAudiobook(audiobookPath);
          await Future.delayed(const Duration(milliseconds: 500));
        }
        await _seekTo(chapters[chapterIndex].startTime + const Duration(milliseconds: 200));
        setState(() {
          _showPanel = false;
        });
      }
    }
  }

  Future<void> _downloadYouTubeSubtitles(String url, String title) async {
    try {
      print('=== Starting subtitle download for: $title ===');
      
      final tempDir = Directory.systemTemp.path;
      final ytSubDir = path.join(tempDir, 'substitcher_yt_subs');
      await Directory(ytSubDir).create(recursive: true);
      
      String? subtitlePath;
      String selectedLang = _subtitlePreferences.defaultLanguage;
      
      print('Attempting to download default language: $selectedLang');
      
      subtitlePath = await YouTubeService.downloadAndFixSubtitles(
        url,
        ytSubDir,
        lang: selectedLang,
      );
      
      if (subtitlePath == null) {
        print('Default language $selectedLang failed, showing language selection...');
        
        if (!mounted) return;
        
        final availableSubs = await YouTubeService.getAvailableSubtitles(
          url,
          _subtitlePreferences.enabledLanguages,
        );
         
         final selected = await showDialog<String>(
           context: context,
           builder: (context) => AlertDialog(
             backgroundColor: const Color(0xFF2D2D2D),
             title: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text(
                   'Select Subtitle Language',
                   style: TextStyle(color: Colors.white),
                 ),
                 IconButton(
                   icon: const Icon(Icons.settings, color: Colors.white54, size: 20),
                   onPressed: () {
                     Navigator.pop(context);
                     _showSubtitlePreferencesDialog();
                   },
                   tooltip: 'Configure languages',
                 ),
               ],
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
                       'Default language "$selectedLang" not available.\nSelect an alternative:',
                       style: const TextStyle(color: Colors.orange, fontSize: 12),
                       textAlign: TextAlign.center,
                     ),
                   ),
                   const SizedBox(height: 16),
                   Flexible(
                     child: ListView.builder(
                       shrinkWrap: true,
                       itemCount: availableSubs.length,
                       itemBuilder: (context, index) {
                         final sub = availableSubs[index];
                         return ListTile(
                           title: Text(
                             sub['name']!,
                             style: const TextStyle(color: Colors.white),
                           ),
                           subtitle: Text(
                             sub['code']!,
                             style: const TextStyle(color: Colors.white54),
                           ),
                           onTap: () => Navigator.pop(context, sub['code']),
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
         
         if (selected == null) {
           print('User cancelled subtitle selection');
           return;
         }
         
         selectedLang = selected;
         print('User selected alternative: $selectedLang');
         
         subtitlePath = await YouTubeService.downloadAndFixSubtitles(
           url,
           ytSubDir,
           lang: selectedLang,
         );
       }
       
       print('Subtitle path result: $subtitlePath');
       
       if (subtitlePath != null && mounted) {
         print('Loading subtitle file: $subtitlePath');
         final content = await File(subtitlePath).readAsString();
         final originalSubtitles = _parseVTT(content);
         print('Parsed ${originalSubtitles.length} subtitle cues');
         
         setState(() {
           _originalSubtitles = originalSubtitles;
           _subtitleFilePath = subtitlePath;
           _paragraphItems = _createParagraphs(originalSubtitles);
         });
         
         if (_conversionType != 'none' && _subtitleFilePath != null) {
           print('Applying conversion: $_conversionType');
           await _applyConversion();
         } else {
           setState(() {
             _subtitles = originalSubtitles;
           });
         }
         
         _updateCurrentSubtitle();
         _precalculateWordPositions();
         
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text(
                 'Loaded ${_subtitles.length} subtitle cues ($selectedLang)${_conversionType != 'none' ? ' • $_conversionType' : ''}',
               ),
               duration: const Duration(seconds: 3),
             ),
           );
         }
       } else if (mounted) {
         print('Failed to download subtitle');
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('No $selectedLang subtitles available for this video'),
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

  Future<void> _handleYouTubeUrl(String url) async {
    if (!YouTubeService.isSupportedUrl(url)) return;
    
    final isLive = await YouTubeService.isActiveLiveStream(url);
    
    if (isLive && mounted) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: const Text('Active Live Stream', style: TextStyle(color: Colors.white)),
          content: const Text(
            'This is currently a live stream. Live streams don\'t have subtitles yet.\n\n'
            'You can stream without subtitles now, or wait until the stream finishes to download with subtitles.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
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
      if (!await YouTubeService.isYtdlpAvailable()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('yt-dlp not found. Install with: brew install yt-dlp'),
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
      
      final audioUrl = await YouTubeService.getAudioStreamUrl(url, formatId: 'worstaudio[format_note*=DRC]/worstaudio[acodec=opus]/worstaudio');
      
      if (audioUrl == null) {
        throw Exception('Could not get audio stream URL');
      }
      
      if (_currentAudiobook != null && 
          _currentAudiobook!.chapters.isNotEmpty &&
          _currentChapterIndex < _currentAudiobook!.chapters.length) {
        final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
        if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
          _statsManager.recordChapterEnd(
            path.basenameWithoutExtension(_currentAudiobook!.path),
            currentChapter.title,
            false,
          );
          await _statsManager.flushCacheToLog();
        }
      }
      
      await player.stop();
      
      List<Chapter> youtubeChapters = [];
      if (chapters != null && chapters.isNotEmpty) {
        for (int i = 0; i < chapters.length; i++) {
          final chapterData = chapters[i];
          final startTime = Duration(seconds: (chapterData['start_time'] as num).toInt());
          
          Duration endTime;
          if (i < chapters.length - 1) {
            endTime = Duration(seconds: (chapters[i + 1]['start_time'] as num).toInt());
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
      
      await player.open(Media(audioUrl));
      await player.setRate(_playbackSpeed);
      
      if (youtubeChapters.isNotEmpty) {
        await player.stream.duration.first;
        
        if (_totalDuration > Duration.zero) {
          final lastChapter = youtubeChapters.last;
          youtubeChapters[youtubeChapters.length - 1] = Chapter(
            index: lastChapter.index,
            title: lastChapter.title,
            startTime: lastChapter.startTime,
            endTime: _totalDuration,
            duration: _totalDuration - lastChapter.startTime,
          );
          
          setState(() {
            _currentAudiobook = AudiobookMetadata(
              path: url,
              title: title,
              author: channelName ?? 'Unknown',
              year: '',
              duration: _totalDuration,
              chapters: youtubeChapters,
            );
          });
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
            content: Text('Now playing: $title${youtubeChapters.isNotEmpty ? ' (${youtubeChapters.length} chapters)' : ''}'),
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
            'Subtitle Language Preferences',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 500,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Default Language: (auto-downloads subs if available)',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
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
                        setDialogState(() {
                          prefs.defaultLanguage = value;
                        });
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                const Text(
                  'Enabled Languages (check up to 10):',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView(
                      children: SubtitlePreferences.availableLanguages.entries.map((entry) {
                        final isEnabled = prefs.enabledLanguages.contains(entry.key);
                        return CheckboxListTile(
                          title: Text(
                            entry.value,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            entry.key,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          value: isEnabled,
                          onChanged: (value) {
                            if (value == true && prefs.enabledLanguages.length < 10) {
                              setDialogState(() {
                                prefs.enabledLanguages.add(entry.key);
                              });
                            } else if (value == false) {
                              setDialogState(() {
                                prefs.enabledLanguages.remove(entry.key);
                              });
                            }
                          },
                          activeColor: Colors.deepPurple,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${prefs.enabledLanguages.length}/10 languages selected',
                  style: TextStyle(
                    color: prefs.enabledLanguages.length >= 10 ? Colors.orange : Colors.white54,
                    fontSize: 12,
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
            ElevatedButton(
              onPressed: () async {
                await prefs.save();
                setState(() {
                  _subtitlePreferences = prefs;
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subtitle preferences saved'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showYouTubeDialog() async {
    final controller = TextEditingController();
    
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && YouTubeService.isSupportedUrl(clipboardData!.text!)) {
      controller.text = clipboardData.text!;
    }
    
    if (!mounted) return;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2D2D2D),
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.headphones, color: Colors.red, size: 40),
                  SizedBox(width: 16),
                  Text(
                    'YouTube Audio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Paste a YouTube URL to stream audio only\nSubtitles will be downloaded automatically if available',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.link, color: Colors.white54),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste, color: Colors.white54),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        controller.text = data!.text!;
                      }
                    },
                  ),
                  hintText: 'https://youtube.com/watch?v=...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (value) {
                  if (YouTubeService.isSupportedUrl(value)) {
                    Navigator.pop(context, {'action': 'stream', 'url': value});
                  }
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Requires yt-dlp installed on your system\n\n'
                '(Mac) brew install yt-dlp (Linux) sudo apt install yt-dlp (Windows) choco install yt-dlp',
                style: TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text('Download Only (⇧D)'),
                    onPressed: () {
                      Navigator.pop(context, {'action': 'download'});
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.deepPurple),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 24),
                    label: const Text('Stream Audio'),
                    onPressed: () {
                      final url = controller.text.trim();
                      if (YouTubeService.isSupportedUrl(url)) {
                        Navigator.pop(context, {'action': 'stream', 'url': url});
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid YouTube URL'),
                            backgroundColor: Colors.deepPurple,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    if (result != null) {
      if (result['action'] == 'stream' && result['url'] != null) {
        await _handleYouTubeUrl(result['url']);
      } else if (result['action'] == 'download') {
        _showDownloadDialog();
      }
    }
    
    _focusNode.requestFocus();
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
      skipTrackingTerms: _skipTrackingTerms,
      skipTrackingController: _skipTrackingController,
      skipTrackingFocusNode: _skipTrackingFocusNode,
      onSkipTrackingChanged: (value) {
        setState(() {
          _skipTrackingTerms = value;
        });
        _saveSkipTrackingTerms();
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
  
  List<Map<String, dynamic>> _groupEntriesByAudiobook(List<Map<String, dynamic>> entries) {
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
      grouped[filename]![chapterName] = grouped[filename]![chapterName]! + duration;
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
        0, 
        (sum, e) => sum + (e['listened_duration'] as num).toInt()
      );
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
    
    result.sort((a, b) => 
      (b['percentage'] as int).compareTo(a['percentage'] as int)
    );
    
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
                    style: TextStyle(color: Color(0xFFF5D38A), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (open 1st audiobook in history)\n '),
                  TextSpan(
                    text: 'p 3',
                    style: TextStyle(color: Color(0xFFF5D38A), fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (open 3rd audiobook in playlist)\n '),
                  TextSpan(
                    text: 'b 6',
                    style: TextStyle(color: Color(0xFFF5D38A), fontWeight: FontWeight.bold),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _setPlaylistDirectory,
                      icon: const Icon(Icons.folder_special),
                      label: const Text('Set Playlist Directory'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
                      label: const Text('Encode Audiobook (e)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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