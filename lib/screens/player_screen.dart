import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show compute;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'metadata_editor_screen.dart';
import '../models/audiobook_metadata.dart';
import '../models/font_category.dart';
import '../models/color_palette.dart';
import '../models/frequency_item.dart';
import '../models/history_item.dart';
import '../models/bookmark.dart';
import '../models/subtitle_cue.dart';
import '../models/pause_mode.dart';
import '../services/cjk_tokenizer.dart';
import '../services/ffmpeg_service.dart';
import '../services/font_loader.dart';
import '../services/font_database.dart';
import '../services/subtitle_transformer.dart';
import '../services/font_alternates_data.dart';
import '../services/subtitle_organizer.dart';
import '../services/frequency_analyzer.dart';
import '../services/stats_manager.dart';
import '../widgets/subtitle_manager_dialog.dart';
import '../widgets/side_panel.dart';
import '../widgets/player_controls.dart';
import '../widgets/word_overlay.dart';
import 'encoder_screen.dart';

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

class _PlayerScreenState extends State<PlayerScreen> {
  final FFmpegService _ffmpeg = FFmpegService();
  final player = Player();
  final ScrollController _chapterScrollController = ScrollController();
  final ScrollController _playlistScrollController = ScrollController();
  final ScrollController _historyScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
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

  DateTime? _wordOverlayClosedTime;
  Timer? _dictionaryModeExitTimer;
  
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

  @override
  void initState() {
    super.initState();
    CJKTokenizer.initialize();
    _setupAudioPlayer();
    _loadSkipChapterTerms();
    _loadCustomFontDirectory();
    _loadDefaultSettings();
    _loadPlaylistDirectories().then((_) {
      _loadChapterIndex();
    });
    _loadDurationCache();
   _statsManager.initialize();
    _loadHistory().then((_) {
      if (_history.isNotEmpty && mounted) {
        _openAudiobook(_history.first.audiobookPath).then((_) {
          if (mounted) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.history;
            });
          }
        });
      }
    });
    _loadPlaylist();
    _loadBookmarks();
    _loadSkipTrackingTerms();
    _startCacheFlushTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _cacheFlushTimer?.cancel();
    _frequencyGenerationTimer?.cancel();
    if (_currentAudiobook != null) {
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      _statsManager.recordChapterEnd(
        path.basenameWithoutExtension(_currentAudiobook!.path),
        currentChapter.title,
      );
    }
    _statsManager.flushCacheToLog();
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

  void _setupAudioPlayer() {
    player.stream.position.listen((position) {
      setState(() {
        _currentPosition = position;
      });
      _checkChapterBoundary(position);
      _checkSleepTimer();
      _checkPauseTrigger();
      _updateCurrentSubtitle();
      if (_isPlaying && position.inSeconds % 10 == 0) {
        _saveToHistory();
      }
    });

    player.stream.duration.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    player.stream.playing.listen((playing) {
      setState(() {
        _isPlaying = playing;
      });
      if (playing) {
        if (!_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook?.path ?? ''))) {
          _statsManager.onPlaybackStart();
        }
        _saveToHistory();
      } else {
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
    if (_defaultColorPalette != null) {
      await prefs.setString('defaultColorPalette', _defaultColorPalette!);
    }
  }
  
  Future<void> _loadDefaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultFont = prefs.getString('defaultFont') ?? 'System Default';
      _defaultConversionType = prefs.getString('defaultConversionType') ?? 'none';
      _defaultColorPalette = prefs.getString('defaultColorPalette');
    });
  }
  
  Future<void> _setCurrentAsDefault() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }
    
    setState(() {
      _defaultFont = _selectedFont;
      _defaultConversionType = _conversionType;
      _defaultColorPalette = _currentColorPalette?.name;
    });
    
    await _saveDefaultSettings();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Set as default:\n'
            'Font: $_defaultFont\n'
            'Conversion: $_defaultConversionType\n'
            'Color: ${_defaultColorPalette ?? 'None'}'
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _applyDefaultSettings() async {
    if (_currentAudiobook == null) {
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
            'Color: ${_defaultColorPalette ?? 'None'}'
          ),
          duration: const Duration(seconds: 2),
        ),
      );
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
    if (_currentAudiobook == null) return;
    final chapter = _currentAudiobook!.chapters[_currentChapterIndex];
    if (position >= chapter.endTime && _currentChapterIndex < _currentAudiobook!.chapters.length - 1) {
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      _statsManager.recordChapterEnd(
        path.basenameWithoutExtension(_currentAudiobook!.path),
        currentChapter.title,
      );
      
      if (!_playedChapters.contains(_currentChapterIndex)) {
        _playedChapters.add(_currentChapterIndex);
      }
      _nextChapter(fromBoundary: true);
      if (_currentAudiobook != null && !_shouldSkipTracking(path.basenameWithoutExtension(_currentAudiobook!.path))) {
      _statsManager.recordChapterStart();
      }
    }
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
          if (ext == '.vtt' || ext == '.srt' || ext == '.vtc') {
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
          if (ext == '.vtt' || ext == '.srt' || ext == '.vtc') {
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
    if (_searchQuery.isEmpty && _excludeTerms.isEmpty) {
      return ColorPalette.presets;
    }
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    return ColorPalette.presets.where((palette) {
      return _matchesSearch(palette.name, _searchQuery, excludeList);
    }).toList();
  }

  void _checkSleepTimer() {
    if (_sleepDuration == null) return;
    if (_sleepDuration == Duration.zero) {
      final chapter = _currentAudiobook!.chapters[_currentChapterIndex];
      if (_currentPosition >= chapter.endTime) {
        exit(0);
      }
    } else if (_sleepDuration!.inMinutes == -1) {
      if (_currentPosition >= _totalDuration) {
        exit(0);
      }
    }
  }

  void _setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null) {
      setState(() {
        _sleepDuration = null;
      });
      return;
    }
    if (duration == Duration.zero) {
      setState(() {
        _sleepDuration = Duration.zero;
      });
      return;
    }
    if (duration.inMinutes == -1) {
      setState(() {
        _sleepDuration = Duration(minutes: -1);
      });
      return;
    }
    setState(() {
      _sleepDuration = duration;
    });
    _sleepTimer = Timer(duration, () {
      exit(0);
    });
  }

  Color _adjustColorIfBright(String hexColor) {
    final hex = hexColor.replaceAll('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    
    if (luminance > 0.7) {
      final darkenFactor = 0.8;
      final newR = (r * darkenFactor).round().clamp(0, 255);
      final newG = (g * darkenFactor).round().clamp(0, 255);
      final newB = (b * darkenFactor).round().clamp(0, 255);
      
      return Color.fromARGB(255, newR, newG, newB);
    }
    
    return _parseColor(hexColor);
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
    if (_currentAudiobook == null) return;
    _history.removeWhere((h) => h.audiobookPath == _currentAudiobook!.path);
    final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
    _history.insert(0, HistoryItem(
      audiobookPath: _currentAudiobook!.path,
      audiobookTitle: _currentAudiobook!.title,
      chapterTitle: currentChapter.title,
      lastChapter: _currentChapterIndex,
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
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    if (_playlistDirectories.contains(result)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Directory already added')),
      );
      return;
    }
    setState(() {
      _playlistDirectories.add(result);
      if (_activePlaylistIndex == null) {
        _activePlaylistIndex = 0;
      }
    });
    await _savePlaylistDirectories();
    if (_activePlaylistIndex == _playlistDirectories.length - 1) {
      await _scanPlaylist(result);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added playlist directory: ${path.basename(result)}'),
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
  
  TextSpan _highlightSearchTerm(String text, String searchTerm) {
    if (searchTerm.isEmpty) {
      return TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
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
    
    if (matches.isEmpty) {
      return TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      );
    }
    
    matches.sort((a, b) => a['start']!.compareTo(b['start']!));
    final mergedMatches = <Map<String, int>>[];
    for (final match in matches) {
      if (mergedMatches.isEmpty || match['start']! > mergedMatches.last['end']!) {
        mergedMatches.add(match);
      } else {
        mergedMatches.last['end'] = 
          mergedMatches.last['end']! > match['end']! 
            ? mergedMatches.last['end']! 
            : match['end']!;
      }
    }
    
    final spans = <TextSpan>[];
    int lastPos = 0;
    for (final match in mergedMatches) {
      if (match['start']! > lastPos) {
        spans.add(TextSpan(
          text: text.substring(lastPos, match['start']!),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match['start']!, match['end']!),
        style: const TextStyle(
          color: Colors.green,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ));
      lastPos = match['end']!;
    }
    if (lastPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastPos),
        style: const TextStyle(color: Colors.white, fontSize: 14),
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
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlistRootDir', dirPath);
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

  String _getRelativePath(String fullPath) {
    if (_playlistRootDir != null && fullPath.startsWith(_playlistRootDir!)) {
      return fullPath.substring(_playlistRootDir!.length + 1);
    }
    return path.basename(fullPath);
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

  Duration _getChapterRemainingTime() {
    if (_currentAudiobook == null) return Duration.zero;
    final chapter = _currentAudiobook!.chapters[_currentChapterIndex];
    return chapter.endTime - _currentPosition;
  }
  
  Duration _getAudiobookRemainingTime() {
    return _totalDuration - _currentPosition;
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
    final terms = _skipTrackingTerms.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
    final lowerTitle = audiobookTitle.toLowerCase();
    return terms.any((term) => lowerTitle.contains(term));
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
      _playbackSpeed = (_playbackSpeed + 0.1).clamp(0.5, 3.0);
    });
    await player.setRate(_playbackSpeed);
  }
  
  Future<void> _decreaseSpeed() async {
    setState(() {
      _playbackSpeed = (_playbackSpeed - 0.1).clamp(0.5, 3.0);
    });
    await player.setRate(_playbackSpeed);
  }
  
  void _increaseFontSize() {
    setState(() {
      _subtitleFontSize = (_subtitleFontSize + 2).clamp(20, 150);
    });
  }
  
  void _decreaseFontSize() {
    setState(() {
      _subtitleFontSize = (_subtitleFontSize - 2).clamp(20, 150);
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
    final timeUntilChapterEnd = currentChapter.endTime - _currentPosition;
    Duration bookmarkPosition = _currentPosition;
    int bookmarkChapterIndex = _currentChapterIndex;
    String bookmarkChapterTitle = currentChapter.title;
    if (timeUntilChapterEnd.inSeconds <= 10 && 
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
        const SnackBar(
          content: Text('Bookmark added'),
          duration: Duration(seconds: 1),
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
  
  Future<void> _saveFontSettings() async {
    if (_currentAudiobook == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('font_${_currentAudiobook!.path}', _selectedFont);
    await prefs.setDouble('fontSize_${_currentAudiobook!.path}', _subtitleFontSize);
    await prefs.setString('conversionType_${_currentAudiobook!.path}', _conversionType);
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

  Future<void> _setCustomFontDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
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
    
    // Update secondary subtitle
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
      allowedExtensions: ['srt', 'vtt', 'vtc'],
      dialogTitle: 'Select Secondary Subtitle File',
      initialDirectory: vttDir,
    );
    
    if (result == null || result.files.isEmpty) return;
    
    final subtitlePath = result.files.first.path!;
    
    try {
      setState(() {
        _secondarySubtitleFilePath = subtitlePath;
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

    print('📝 _applySecondaryConversion called with _secondarySubtitleFilePath: $_secondarySubtitleFilePath');
    
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
      // Cap at 10 - anything below 10 gets the same boost as 10
      final effectiveLength = textLength < 10 ? 10 : textLength;
      // Single smooth curve: 1.5x at len=10, gradually down to 1.0x at len=60
      multiplier = 1.0 + ((60 - effectiveLength) / 100.0);
    }
    
    final finalSize = baseFontSize * multiplier;
    
    if (text != _lastDebuggedSubtitle) {
      // print('📏 Font Adjust: len=$textLength, base=$baseFontSize, ×${multiplier.toStringAsFixed(3)} = ${finalSize.toStringAsFixed(1)}');
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
  }) {
    final baseFontSize = fontSize ?? _subtitleFontSize;
    final effectiveFont = fontFamily ?? (_selectedFont == 'System Default' ? null : _selectedFont);
    final effectivePalette = palette ?? _currentColorPalette;
    final cleanedText = text.replaceAll(RegExp(r'<[^>]+>'), '');
    final effectiveFontSize = _calculateDynamicFontSize(cleanedText, baseFontSize);
    
    if (effectivePalette == null) {
      return TextSpan(
        text: cleanedText,
        style: TextStyle(
          color: Colors.white,
          fontSize: effectiveFontSize,
          height: 1.4,
          fontFamily: effectiveFont,
          shadows: [
            Shadow(
              offset: Offset(5.0, 5.0),
              blurRadius: 0,
              color: _parseColor('000000'),
            ),
          ],
        ),
      );
    }
    
    if (effectivePalette.isSimplePreset) {
      return TextSpan(
        text: cleanedText,
        style: TextStyle(
          color: _parseColor(effectivePalette.colors[0]),
          fontSize: effectiveFontSize,
          height: 1.4,
          fontFamily: effectiveFont,
          shadows: [
            Shadow(
              offset: Offset(effectivePalette.shadowOffset, effectivePalette.shadowOffset),
              blurRadius: 0,
              color: _parseColor(effectivePalette.subShadowColor!),
            ),
          ],
        ),
      );
    }
    
    final startWordIndex = _calculateWordIndexAtPosition(_currentPosition);
    final language = CJKTokenizer.detectLanguage(cleanedText);
    if (language == TextLanguage.japanese || 
        language == TextLanguage.chinese || 
        language == TextLanguage.korean) {
      return _buildCJKColoredTextSpan(cleanedText, startWordIndex, effectiveFontSize, effectiveFont, effectivePalette);
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
      wordIndex++;
      
      spans.add(TextSpan(
        text: word,
        style: TextStyle(
          color: color,
          fontSize: effectiveFontSize,
          height: 1.4,
          fontFamily: effectiveFont,
          shadows: [
            Shadow(
              offset: Offset(effectivePalette.shadowOffset, effectivePalette.shadowOffset),
              blurRadius: 0,
              color: _parseColor(effectivePalette.shadowColor),
            ),
          ],
        ),
      ));
      if (space.isNotEmpty) {
        spans.add(TextSpan(
          text: space,
          style: TextStyle(
            color: Colors.white,
            fontSize: effectiveFontSize,
            height: 1.4,
            fontFamily: effectiveFont,
          ),
        ));
      }
    }
    return TextSpan(children: spans);
  }
  
  TextSpan _buildCJKColoredTextSpan(
    String text, 
    int startWordIndex,
    double fontSize,
    String? fontFamily,
    ColorPalette palette,
  ) {
    final words = CJKTokenizer.tokenize(text);
    final spans = <TextSpan>[];
    int wordIndex = startWordIndex;
    for (final word in words) {
      final colorIndex = wordIndex % palette.colors.length;
      final color = _adjustColorIfBright(palette.colors[colorIndex]);
      spans.add(TextSpan(
        text: word,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          height: 1.4,
          fontFamily: fontFamily,
          shadows: [
            Shadow(
              offset: Offset(palette.shadowOffset, palette.shadowOffset),
              blurRadius: 0,
              color: _parseColor(palette.shadowColor),
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
    if (_currentChapterIndex > 0) {
      final currentChapter = _currentAudiobook!.chapters[_currentChapterIndex];
      await _statsManager.recordChapterEnd(
        path.basenameWithoutExtension(_currentAudiobook!.path),
        currentChapter.title,
      );
      _statsManager.flushCacheToLog();
      
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
      );
      _statsManager.flushCacheToLog();
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
        );
        _statsManager.flushCacheToLog();
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

  String _formatChapterRemaining(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      final seconds = d.inSeconds.remainder(60);
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds.remainder(60);
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
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
      final metadata = await _ffmpeg.loadAudiobook(selectedPath);
      final fileSize = await _getFileSize(selectedPath);
      await player.stop();
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
      setState(() {
        _currentAudiobook = metadata;
        _currentChapterIndex = historyItem.lastChapter;
        _currentPosition = historyItem.lastPosition;
        _fileSize = fileSize;
        _shuffleEnabled = historyItem.shuffleEnabled;
        _playedChapters = List.from(historyItem.playedChapters);
        _frequencyItems = [];
        _isAnalyzingFrequencies = false;
      });
      await _loadFontSettings(selectedPath);
      final fileDir = path.dirname(selectedPath);
      bool isInPlaylistDir = false;
      if (_playlistRootDir != null) {
        isInPlaylistDir = selectedPath.startsWith(_playlistRootDir!);
      }
      if (!isInPlaylistDir) {
        print('File outside playlist directory, creating local playlist for: $fileDir');
        await _scanPlaylist(fileDir);
      }
      await player.open(Media(selectedPath));
      await player.setRate(_playbackSpeed);
      await _loadSubtitles(selectedPath);
      _precalculateWordPositions();
      await Future.delayed(const Duration(milliseconds: 100));
      if (historyItem.lastPosition.inSeconds > 0) {
        await player.seek(historyItem.lastPosition);
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
    if (!await Directory(vttDir).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Directory not found: ${audiobookBase}_vtt')),
        );
      }
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt', 'vtc'],
      dialogTitle: 'Select Subtitle File',
      initialDirectory: vttDir,
    );
    if (result == null || result.files.isEmpty) return;
    final subtitlePath = result.files.first.path!;
    try {
      final content = await File(subtitlePath).readAsString();
      final ext = path.extension(subtitlePath).toLowerCase();
      List<SubtitleCue> subtitles;
      if (ext == '.vtt' || ext == '.vtc') {
        subtitles = _parseVTT(content);
      } else if (ext == '.srt') {
        subtitles = _parseSRT(content);
      } else {
        throw Exception('Unsupported subtitle format');
      }
      setState(() {
        _subtitles = subtitles;
        _subtitleFilePath = subtitlePath;
        _currentSubtitleText = '';
      });
      _updateCurrentSubtitle();
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

  void _navigateFonts(int direction) {
    final filteredFonts = _getFilteredFonts();
    if (filteredFonts.isEmpty) return;
    setState(() {
      _selectedFontIndex = (_selectedFontIndex + direction).clamp(0, filteredFonts.length - 1).toInt();
      _selectedFont = filteredFonts[_selectedFontIndex];
    });
    _scrollToSelectedFont();
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

  int _findNearestChapter(double position) {
    if (_currentAudiobook == null) return -1;
    final positionDuration = Duration(milliseconds: position.toInt());
    final totalMillis = _totalDuration.inMilliseconds;
    if (totalMillis == 0) return -1;
    const snapDistancePx = 2.0;
    for (var i = 0; i < _currentAudiobook!.chapters.length; i++) {
      final chapter = _currentAudiobook!.chapters[i];
      final chapterPositionPx = (chapter.startTime.inMilliseconds / totalMillis) * MediaQuery.of(context).size.width;
      final clickPositionPx = (position / totalMillis) * MediaQuery.of(context).size.width;
      if ((clickPositionPx - chapterPositionPx).abs() <= snapDistancePx) {
        return i;
      }
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (_showEncoderScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const EncoderScreen(),
            Positioned(
              top: 8,
              right: 8,
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
        if (_searchFocusNode.hasFocus || _excludeFocusNode.hasFocus || _skipChapterFocusNode.hasFocus || _subsSearchFocusNode.hasFocus || _chapterSearchFocusNode.hasFocus || _chapterExcludeFocusNode.hasFocus || _statsSearchFocusNode.hasFocus || _skipTrackingFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            if (_showPanel) {
              setState(() {
                _showPanel = false;
              });
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.bracketLeft && event is KeyDownEvent) {
            _decreaseSpeed();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.bracketRight && event is KeyDownEvent) {
            _increaseSpeed();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyY && event is KeyDownEvent) {
            _toggleFullscreen();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyA && event is KeyDownEvent) {
            _applyDefaultSettings();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyF && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.fonts;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyD && event is KeyDownEvent) {
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
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyO && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.colors;
            });
            _scrollToSelectedColorPalette();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_showPanel && _panelMode == PanelMode.colors) {
              _navigateColors(-1);
            } else if (_showPanel && _panelMode == PanelMode.fonts) {
              _navigateFonts(-1);
            } else {
              _increaseFontSize();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            if (_showPanel && _panelMode == PanelMode.colors) {
              _navigateColors(1);
            } else if (_showPanel && _panelMode == PanelMode.fonts) {
              _navigateFonts(1);
            } else {
              _decreaseFontSize();
            }        
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyC && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.chapters;
            });
            _scrollToCurrentChapter();
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
          } else if (event.logicalKey == LogicalKeyboardKey.keyB && event is KeyDownEvent) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              _addBookmark();
            } else {
              setState(() {
                _showPanel = true;
                _panelMode = PanelMode.bookmarks;
              });
              _scrollToTopOfHistory();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyW && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.words;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyU && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.subs;
            });
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
              _jumpToPinnedBookmark(3);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit4 || event.logicalKey == LogicalKeyboardKey.numpad4) {
              _jumpToPinnedBookmark(4);
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
          } else if (event.logicalKey == LogicalKeyboardKey.keyL && event is KeyDownEvent) {
            _openAudiobook();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.keyS && event is KeyDownEvent) {
            setState(() {
              _showPanel = true;
              _panelMode = PanelMode.subs;
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (_subtitles.isNotEmpty) {
              _skipToPreviousSubtitle();
            } else {
              _skipBackward3();
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (_subtitles.isNotEmpty) {
              _skipToNextSubtitle();
            } else {
              _skipForward3();
            }
            return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyT && event is KeyDownEvent) {
              setState(() {
                _showPanel = true;
                _panelMode = PanelMode.stats;
              });
              return KeyEventResult.handled;
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
              if (_currentAudiobook == null)
                _buildNoAudiobook()
              else
                _buildPlayer(),
              if (_showPanel && _currentAudiobook != null)
                _buildPanel(),
             if (_showWordOverlay && _currentSubtitleText.isNotEmpty)
               WordOverlay(
                 subtitle: _currentSubtitleIndex != null && _currentSubtitleIndex! < _originalSubtitles.length
                     ? _originalSubtitles[_currentSubtitleIndex!].text
                     : _currentSubtitleText,  // Fallback to current if original not available
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
            ],
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
      audiobook: _currentAudiobook!,
      currentChapterIndex: _currentChapterIndex,
      currentPosition: _currentPosition,
      totalDuration: _totalDuration,
      isPlaying: _isPlaying,
      playbackSpeed: _playbackSpeed,
      fileSize: _fileSize,
      averageBitrate: _averageBitrate,
      shuffleEnabled: _shuffleEnabled,
      conversionType: _conversionType,
      playedChapters: _currentAudiobook!.chapters.where((c) => _playedChapters.contains(_currentAudiobook!.chapters.indexOf(c))).toList(),
      selectedFont: _selectedFont,
      defaultFont: _defaultFont,
      defaultConversionType: _defaultConversionType,
      defaultColorPalette: _defaultColorPalette,
      currentColorPalette: _currentColorPalette,
      currentSubtitleText: _currentSubtitleText,
      subtitleFontSize: _subtitleFontSize,
      secondarySubtitleText: _secondarySubtitleText,
      secondarySubtitleFontSize: _secondarySubtitleFontSize,
      secondarySubtitleFont: _secondarySubtitleFont,
      secondaryColorPalette: _secondaryColorPalette,
      sleepDuration: _sleepDuration,
      sliderHoverPosition: _sliderHoverPosition,
      hoveredChapterTitle: _hoveredChapterTitle,
      pauseMode: _pauseMode,
      onTogglePlayPause: _togglePlayPause,
      onPreviousChapter: _previousChapter,
      onNextChapter: _nextChapter,
      onSkipBackward: _skipBackward,
      onSkipForward: _skipForward,
      onIncreaseSpeed: _increaseSpeed,
      onDecreaseSpeed: _decreaseSpeed,
      onToggleShuffle: _toggleShuffle,
      onAddBookmark: _addBookmark,
      onTogglePanel: () {
        setState(() {
          _showPanel = !_showPanel;
          _panelMode = PanelMode.chapters;
        });
        if (_showPanel) {
          _scrollToCurrentChapter();
        }
      },
      onSetSleepTimer: _setSleepTimer,
      onSeekTo: _seekTo,
      onSliderHover: (position) {
        setState(() {
          _sliderHoverPosition = position;
          final sliderWidth = MediaQuery.of(context).size.width - 64;
          final totalMillis = _totalDuration.inMilliseconds;
          if (totalMillis > 0 && _currentAudiobook != null) {
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
          case 'subtitle_manager':
            _openSubtitleManager();
            break;
          case 'fullscreen':
            _toggleFullscreen();
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
    );
  }

  Widget _buildPanel() {
    return SidePanel(
      panelMode: _panelMode,
      currentAudiobook: _currentAudiobook,
      currentChapterIndex: _currentChapterIndex,
      searchQuery: _searchQuery,
      searchUseAnd: _searchUseAnd,
      excludeTerms: _excludeTerms,
      searchController: _searchController,
      excludeController: _excludeController,
      searchFocusNode: _searchFocusNode,
      excludeFocusNode: _excludeFocusNode,
      onClose: () {
        setState(() {
          _showPanel = false;
        });
      },
      onPanelModeChanged: (mode) {
        setState(() {
          _panelMode = mode;
        });
        // Scroll to appropriate positions based on mode
        if (mode == PanelMode.chapters) {
          _scrollToCurrentChapter();
        } else if (mode == PanelMode.playlist) {
          _scrollToCurrentPlaylistItem();
        } else if (mode == PanelMode.history || mode == PanelMode.bookmarks) {
          _scrollToTopOfHistory();
        } else if (mode == PanelMode.colors) {
          _scrollToSelectedColorPalette();
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
      
      // Chapter panel
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
      
      // History panel
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
      
      // Playlist panel
      getFilteredPlaylist: _getFilteredPlaylist,
      playlistScrollController: _playlistScrollController,
      getAudiobookDuration: _getAudiobookDuration,
      
      // Bookmarks panel
      getFilteredBookmarks: _getFilteredBookmarks,
      onRemoveBookmark: _removeBookmark,
      onJumpToBookmark: _jumpToBookmark,
      onSetPinNumber: _setPinNumber,
      
      // Fonts panel
      getFilteredFonts: _getFilteredFonts,
      selectedFont: _selectedFont,
      selectedFontIndex: _selectedFontIndex,
      fontScrollController: _fontScrollController,
      onFontSelected: (fontName, index) {
        setState(() {
          _selectedFont = fontName;
          _selectedFontIndex = index;
        });
        _scrollToSelectedFont();
        _saveFontSettings();
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
      
      // Colors panel
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
      
      // Words panel
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
      
      // Subs panel
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
      
      // Stats panel
      buildStatsPanel: _buildStatsPanel,
      
      // Counts for badges
      historyCount: _history.length,
      playlistCount: _playlist.length,
      bookmarksCount: _bookmarks.length,
      fontsCount: CustomFontLoader.loadedFonts.length,
      subsCount: _subtitles.length,
      statsCount: _statsManager.statsEntries.length,
    );
  }
  
  Future<void> _resetConversion() async {
    setState(() {
      _conversionType = 'none';
    });
    await _applyConversion();
    await _saveFontSettings();
  }

  Future<void> _copyCurrentMetadata() async {
    if (_currentAudiobook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audiobook loaded')),
      );
      return;
    }
    try {
      final metadataResult = await Process.run('ffprobe', [
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
            }
          }
        }
      }
      final finalTitle = album != 'Unknown Album' ? album : title;
      final file = File(_currentAudiobook!.path);
      final fileSize = await file.length();
      final formattedFileSize = _formatFileSize(fileSize);
      final duration = _totalDuration;
      final formattedDuration = _formatDuration(duration);
      final clipboardText = '$artist - $finalTitle ($year) $formattedFileSize $formattedDuration';
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
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied ${_currentAudiobook!.chapters.length} chapter titles to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
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

  Future<void> _applyConversion() async {
    if (_currentAudiobook == null || _subtitleFilePath == null) return;
      
    try {
      final content = await File(_subtitleFilePath!).readAsString();
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
      
      final subtitles = _parseVTT(convertedContent);
      setState(() {
        _subtitles = subtitles;
      });
      
      _updateCurrentSubtitle();
      
      if (_currentSubtitleIndex != null && _currentSubtitleIndex! > 0) {
        final savedPosition = _currentPosition;
        
        await _skipToPreviousSubtitle();
        await Future.delayed(const Duration(milliseconds: 150));
        
        await player.seek(savedPosition);
        setState(() {
          _currentPosition = savedPosition;
        });
        _updateCurrentSubtitle();
      }
      
      _scheduleFrequencyGeneration();
      
      if (mounted && _conversionType != 'none') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied $_conversionType conversion'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error applying conversion: $e');
      if (mounted) {
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
    return Color(int.parse('FF$hex', radix: 16));
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
      final itemToRemove = _history.firstWhere(
        (h) => h.audiobookPath == filePath,
        orElse: () => _history.first,
      );
      if (itemToRemove.audiobookPath == filePath) {
        final index = _history.indexOf(itemToRemove);
        await _removeFromHistory(index);
      }
      return {'duration': '', 'progress': ''};
    }
    if (_playlistDurationCache.containsKey(filePath)) {
      final durationStr = _playlistDurationCache[filePath]!;
      final progress = await _calculateProgress(filePath, lastPosition);
      return {'duration': durationStr, 'progress': progress};
    }
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        filePath,
      ]);
      if (result.exitCode == 0) {
        final durationSeconds = double.parse(result.stdout.toString().trim());
        final duration = Duration(seconds: durationSeconds.round());
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
        final percentage = ((lastPosition.inSeconds / duration.inSeconds) * 100).round();
        final progress = '$percentage%';
        return {'duration': formatted, 'progress': progress};
      }
    } catch (e) {
      print('Error getting duration for $filePath: $e');
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
    if (totalDuration == null) {
      try {
        final result = await Process.run('ffprobe', [
          '-v', 'error',
          '-show_entries', 'format=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          filePath,
        ]);
        if (result.exitCode == 0) {
          final durationSeconds = double.parse(result.stdout.toString().trim());
          totalDuration = Duration(seconds: durationSeconds.round());
          final hours = totalDuration.inHours;
          final minutes = totalDuration.inMinutes.remainder(60);
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
        }
      } catch (e) {
        print('Error calculating progress: $e');
        return '';
      }
    }
    if (totalDuration != null && totalDuration.inSeconds > 0) {
      final percentage = ((lastPosition.inSeconds / totalDuration.inSeconds) * 100).round();
      return '$percentage%';
    }
    return '';
  }

  
  
  Future<String> _getAudiobookDuration(String filePath) async {
    if (_playlistDurationCache.containsKey(filePath)) {
      return _playlistDurationCache[filePath]!;
    }
    try {
      final result = await Process.run('ffprobe', [
        '-v', 'error',
        '-show_entries', 'format=duration',
        '-of', 'default=noprint_wrappers=1:nokey=1',
        filePath,
      ]);
      if (result.exitCode == 0) {
        final durationSeconds = double.parse(result.stdout.toString().trim());
        final duration = Duration(seconds: durationSeconds.round());
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
        return formatted;
      }
    } catch (e) {
      print('Error getting duration for $filePath: $e');
    }
    return '';
  }

  Future<void> _setPinNumber(int bookmarkIndex, int? pinNumber) async {
    final bookmark = _bookmarks[bookmarkIndex].copyWith(pinNumber: pinNumber);
    setState(() {
      _bookmarks[bookmarkIndex] = bookmark;
    });
    await _saveBookmarks();
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
    
    // Find current subtitle index first
    int currentIndex = -1;
    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].startTime <= _currentPosition && 
          (i == _subtitles.length - 1 || _subtitles[i + 1].startTime > _currentPosition)) {
        currentIndex = i;
        break;
      }
    }
    
    // Go to previous subtitle if it exists
    if (currentIndex > 0) {
      await _seekTo(_subtitles[currentIndex - 1].startTime);
    } else if (currentIndex == 0) {
      // If at first subtitle, go to its start
      await _seekTo(_subtitles[0].startTime);
    }
  }
  
  Future<void> _skipToNextSubtitle() async {
    if (_subtitles.isEmpty) return;
    
    for (int i = 0; i < _subtitles.length; i++) {
      if (_subtitles[i].startTime > _currentPosition + const Duration(milliseconds: 100)) {
        await _seekTo(_subtitles[i].startTime);
        return;
      }
    }
  }

  Widget _buildStatsPanel() {
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
                    flex: 3,
                    child: TextField(
                      controller: _skipTrackingController,
                      focusNode: _skipTrackingFocusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Skip tracking: words in audiobook titles...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.block, color: Colors.white54, size: 20),
                        suffixIcon: _skipTrackingTerms.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                                onPressed: () {
                                  _skipTrackingController.clear();
                                  setState(() {
                                    _skipTrackingTerms = '';
                                  });
                                  _saveSkipTrackingTerms();
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
                      onChanged: (value) {
                        setState(() {
                          _skipTrackingTerms = value;
                        });
                        _saveSkipTrackingTerms();
                      },
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Text(
                        'Enable Tracking',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _statsManager.statsEnabled,
                        onChanged: (value) {
                          _statsManager.saveStatsEnabled(value);
                        },
                        activeColor: Colors.deepPurple,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _statsManager.loadAllStatsEntries,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildStatsSearchResults()
              : _buildStatsContent(),
        ),
      ],
    );
  }

  Widget _buildStatsSearchResults() {
    final resultsMap = <String, StatsSearchResult>{};
    final searchTerms = _searchQuery.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
    final excludeList = _excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    
    if (searchTerms.isEmpty) {
      return const Center(
        child: Text(
          'Enter search terms',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    for (final entry in _statsManager.statsEntries) {
      final filename = entry['filename'] as String? ?? '';
      final chapterName = entry['chapter_name'] as String? ?? '';
      
      final searchText = '$filename $chapterName';
      
      if (_matchesSearch(searchText, _searchQuery, excludeList)) {
        final audiobookPath = _playlist.firstWhere(
          (p) => path.basenameWithoutExtension(p) == filename,
          orElse: () => '',
        );
        
        if (audiobookPath.isNotEmpty && _playlistChapterIndex.containsKey(audiobookPath)) {
          final chapters = _playlistChapterIndex[audiobookPath]!;
          final chapterIndex = chapters.indexWhere((ch) => ch.title == chapterName);
          
          if (chapterIndex != -1) {
            final key = '$audiobookPath|$chapterName';
            if (!resultsMap.containsKey(key)) {
              resultsMap[key] = StatsSearchResult(
                audiobookPath: audiobookPath,
                audiobookTitle: filename,
                chapterTitle: chapterName,
                startTime: chapters[chapterIndex].startTime,
              );
            }
          }
        }
      }
    }
    
    final results = resultsMap.values.toList();
    
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Stats Search Results (${results.length})',
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
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return InkWell(
                onTap: () => _jumpToStatsResult(result),
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
                              text: _highlightSearchTerm(result.chapterTitle, _statsSearchQuery),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(result.startTime),
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

  Future<void> _jumpToStatsResult(StatsSearchResult result) async {
    if (_currentAudiobook?.path != result.audiobookPath) {
      setState(() {
        _frequencyItems = [];
        _isAnalyzingFrequencies = false;
      });
      await _openAudiobook(result.audiobookPath);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await _seekTo(result.startTime + const Duration(milliseconds: 200));
    setState(() {
      _showPanel = false;
    });
  }
  
  Widget _buildStatsContent() {
    if (_statsManager.statsEntries.isEmpty) {
      return const Center(
        child: Text(
          'No statistics data yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatisticsSummary(),
        _buildDayStats('Today', _filterEntriesByDate(now)),
        const SizedBox(height: 24),
        _buildDayStats('Yesterday', _filterEntriesByDate(now.subtract(const Duration(days: 1)))),
        const SizedBox(height: 24),
        for (int i = 2; i <= 10; i++) ...[
          _buildDayStats('$i days ago', _filterEntriesByDate(now.subtract(Duration(days: i)))),
          const SizedBox(height: 24),
        ],
        _buildPeriodSummary('Last 7 Days', _filterEntriesByDays(7)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 2 Weeks', _filterEntriesByDays(14)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 3 Weeks', _filterEntriesByDays(21)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 1 Month', _filterEntriesByDays(30)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 2 Months', _filterEntriesByDays(60)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 3 Months', _filterEntriesByDays(90)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 6 Months', _filterEntriesByDays(180)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last Year', _filterEntriesByDays(365)),
        const SizedBox(height: 24),
        _buildPeriodSummary('All Time', _statsManager.statsEntries),
        const SizedBox(height: 32),
        _buildTop50Section(),
        const SizedBox(height: 32),
        _buildActiveDaysChart(),
      ],
    );
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
  
  Widget _buildDayStats(String title, List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final stats = _calculateStats(entries);
    final audiobookStats = _groupEntriesByAudiobook(entries);
    
    final dateMatch = RegExp(r'(\d+) days ago').firstMatch(title);
    DateTime displayDate;
    if (title == 'Today') {
      displayDate = DateTime.now();
    } else if (title == 'Yesterday') {
      displayDate = DateTime.now().subtract(const Duration(days: 1));
    } else if (dateMatch != null) {
      final daysAgo = int.parse(dateMatch.group(1)!);
      displayDate = DateTime.now().subtract(Duration(days: daysAgo));
    } else {
      displayDate = DateTime.now();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.lightBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDurationCompact(Duration(seconds: stats['totalTime'])),
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Listening Time',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['uniqueFiles']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Audios',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['totalChapters']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Chapters',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDurationCompact(Duration(seconds: stats['avgChapter'])),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Average Chapter',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...audiobookStats.map((audiobookData) {
          final audiobookTitle = audiobookData['title'] as String;
          final audiobookDuration = audiobookData['duration'] as String;
          final percentage = audiobookData['percentage'] as int;
          final chapters = audiobookData['chapters'] as List<Map<String, dynamic>>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13),
                          children: [
                            TextSpan(
                              text: audiobookTitle,
                              style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: ' $audiobookDuration ',
                              style: const TextStyle(color: Colors.green),
                            ),
                            TextSpan(
                              text: '$percentage%',
                              style: const TextStyle(color: Colors.yellow),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () async {
                        await _statsManager.deleteAudiobookFromDate(audiobookTitle, displayDate);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...chapters.map((chapter) {
                  final chapterTitle = chapter['title'] as String;
                  final chapterTime = chapter['time'] as int;
                  final timestamp = chapter['timestamp'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(left: 0, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                chapterTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              _formatDurationCompact(Duration(seconds: chapterTime)),
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          timestamp,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildPeriodSummary(String title, List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final stats = _calculateStats(entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.lightBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDurationCompact(Duration(seconds: stats['totalTime'])),
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Listening Time',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['uniqueFiles']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Audios',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['totalChapters']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Chapters',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDurationCompact(Duration(seconds: stats['avgChapter'])),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Average Chapter',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _groupEntriesByAudiobook(List<Map<String, dynamic>> entries) {
    final Map<String, Map<String, List<Map<String, dynamic>>>> grouped = {};
    for (final entry in entries) {
      final filename = entry['filename'] as String;
      final chapterName = entry['chapter_name'] as String;
      grouped.putIfAbsent(filename, () => {});
      grouped[filename]!.putIfAbsent(chapterName, () => []).add(entry);
    }
    final result = <Map<String, dynamic>>[];
    for (final filename in grouped.keys) {
      final chapters = grouped[filename]!;
      int audiobookTotalTime = 0;
      final chapterData = <Map<String, dynamic>>[];
      for (final chapterName in chapters.keys) {
        final chapterEntries = chapters[chapterName]!;
        final chapterTime = chapterEntries.fold<int>(0, (sum, entry) => sum + (entry['listened_duration'] as num).toInt());
        audiobookTotalTime += chapterTime;
        chapterEntries.sort((a, b) => (a['datetime'] as String).compareTo(b['datetime'] as String));
        final firstTimestamp = chapterEntries.first['datetime'] as String;
        chapterData.add({
          'title': chapterName,
          'time': chapterTime,
          'timestamp': firstTimestamp,
        });
      }
      chapterData.sort((a, b) => (b['time'] as int).compareTo(a['time'] as int));
      result.add({
        'title': filename,
        'totalTime': audiobookTotalTime,
        'duration': _formatDurationCompact(Duration(seconds: audiobookTotalTime)),
        'percentage': 0,
        'chapters': chapterData,
        'chapterCount': chapters.length,
      });
    }
    result.sort((a, b) => (b['totalTime'] as int).compareTo(a['totalTime'] as int));
    final totalTime = result.fold<int>(0, (sum, ab) => sum + (ab['totalTime'] as int));
    for (final ab in result) {
      ab['percentage'] = totalTime > 0 ? ((ab['totalTime'] as int) / totalTime * 100).round() : 0;
    }
    return result;
  }

  Widget _buildStatisticsSummary() {
    if (_statsManager.statsEntries.isEmpty) {
      return const SizedBox.shrink();
    }
  
    final Map<String, int> dailyTimes = {};
    for (final entry in _statsManager.statsEntries) {
      final datetime = entry['datetime'] as String?;
      if (datetime == null) continue;
      try {
        final date = datetime.split(' ')[0];
        final duration = (entry['listened_duration'] as num).toInt();
        dailyTimes[date] = (dailyTimes[date] ?? 0) + duration;
      } catch (e) {
        continue;
      }
    }
  
    final activeDays = <MapEntry<String, int>>[];
    dailyTimes.forEach((date, time) {
      if (time >= 1800) {
        activeDays.add(MapEntry(date, time));
      }
    });
    activeDays.sort((a, b) => b.key.compareTo(a.key));
  
    int currentStreak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dailyTimes[dateStr] != null && dailyTimes[dateStr]! >= 1800) {
        currentStreak++;
      } else {
        break;
      }
    }
  
    int longestStreak = 0;
    String longestStreakEndDate = '';
    int tempStreak = 0;
    String tempStreakEnd = '';
    for (int i = 0; i < 365; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dailyTimes[dateStr] != null && dailyTimes[dateStr]! >= 1800) {
        if (tempStreak == 0) {
          tempStreakEnd = dateStr;
        }
        tempStreak++;
      } else {
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
          longestStreakEndDate = tempStreakEnd;
        }
        tempStreak = 0;
        tempStreakEnd = '';
      }
    }
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
      longestStreakEndDate = tempStreakEnd;
    }
  
    int calcAverage(int dayCount) {
      if (activeDays.isEmpty) return 0;
      final subset = activeDays.take(dayCount).toList();
      if (subset.isEmpty) return 0;
      final sum = subset.fold<int>(0, (total, day) => total + day.value);
      return sum ~/ subset.length;
    }
  
    final avg10 = calcAverage(10);
    final avg20 = calcAverage(20);
    final avg30 = calcAverage(30);
  
    final sortedDays = dailyTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDays = sortedDays.where((e) => e.value > 0).take(3).toList();
  
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Active Day is =>30m/day',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    _formatDurationCompact(Duration(seconds: avg10)),
                    style: const TextStyle(color: Colors.lightBlue, fontSize: 18),
                  ),
                  const Text(
                    'Last 10 Active Days Average',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    _formatDurationCompact(Duration(seconds: avg20)),
                    style: const TextStyle(color: Colors.lightBlue, fontSize: 18),
                  ),
                  const Text(
                    'Last 20 Active Days Average',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    _formatDurationCompact(Duration(seconds: avg30)),
                    style: const TextStyle(color: Colors.lightBlue, fontSize: 18),
                  ),
                  const Text(
                    'Last 30 Active Days Average',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$currentStreak',
                    style: const TextStyle(color: Color(0xFFE3E82B), fontSize: 18),
                  ),
                  const Text(
                    'Active Daily Streak',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$longestStreak',
                    style: const TextStyle(color: Color(0xFFFF3F3F), fontSize: 18),
                  ),
                  const Text(
                    'Longest Daily Streak',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Ended $longestStreakEndDate',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${activeDays.length}',
                    style: const TextStyle(color: Color(0xFFD7B9A3), fontSize: 18),
                  ),
                  const Text(
                    'Total Active Days',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: topDays.asMap().entries.map((entry) {
            final idx = entry.key;
            final day = entry.value;
            final label = idx == 0 ? 'Longest Day' : '${idx + 1}${idx == 1 ? 'nd' : 'rd'} Longest Day';
            return Expanded(
              child: Column(
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Color(0xFFAE4FF7), fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    _formatDurationCompact(Duration(seconds: day.value)),
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    day.key,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
  
  Widget _buildTop50Section() {
    final fileTimes = _getFileListenTimes(_statsManager.statsEntries);
    final sortedFiles = fileTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top50 = sortedFiles.take(50).where((e) => e.value >= 1200).toList();
    if (top50.isEmpty) {
      return const SizedBox.shrink();
    }
    final totalTime = top50.fold<int>(0, (sum, e) => sum + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 50 Audiobooks Most Listened Duration >= 20m',
          style: TextStyle(
            color: Colors.lightBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...top50.asMap().entries.map((entry) {
          final index = entry.key;
          final fileEntry = entry.value;
          final percentage = totalTime > 0 ? ((fileEntry.value / totalTime) * 100).round() : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    fileEntry.key,
                    style: const TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDurationCompact(Duration(seconds: fileEntry.value)),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildActiveDaysChart() {
    final Map<String, int> dailyTimes = {};
    for (final entry in _statsManager.statsEntries) {
      final datetime = entry['datetime'] as String?;
      if (datetime == null) continue;
      try {
        final date = datetime.split(' ')[0];
        final duration = (entry['listened_duration'] as num).toInt();
        dailyTimes[date] = (dailyTimes[date] ?? 0) + duration;
      } catch (e) {
        continue;
      }
    }
    final sortedDays = dailyTimes.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final activeDays = sortedDays.where((e) => e.value > 0).take(30).toList();
    if (activeDays.isEmpty) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final daysAgo = <int, int>{};
    for (final entry in activeDays) {
      try {
        final entryDate = DateTime.parse(entry.key);
        final diff = now.difference(entryDate).inDays;
        daysAgo[diff] = entry.value;
      } catch (e) {
        continue;
      }
    }
    final maxTime = daysAgo.values.reduce((a, b) => a > b ? a : b);
    final sortedDaysAgo = daysAgo.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '(Days Ago) — Last 30 Active Days Listening Duration',
          style: TextStyle(
            color: Colors.lightBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedDaysAgo.map((entry) {
          final days = entry.key;
          final time = entry.value;
          final barWidth = (time / maxTime * 700).clamp(50.0, 700.0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '$days',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: barWidth,
                  height: 20,
                  decoration: BoxDecoration(
                    color: days <= 1
                        ? Colors.grey
                        : days <= 7
                            ? Colors.orange
                            : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    _formatDurationCompact(Duration(seconds: time)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
  
  Widget _buildNoAudiobook() {
    return Center(
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
          const Text(
            'Open the History, Set Playlist Directory, or Load an audiobook to get started',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 32),
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
                label: const Text('Open History'),
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
                label: const Text('Load Audiobook'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}