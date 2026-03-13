import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:media_kit/media_kit.dart';
import 'transcribe_screen.dart';
import 'translate_screen.dart';
import 'repeats_screen.dart';
import 'metadata_editor_screen.dart';
import 'anki_converter_screen.dart';
import 'trim_audio_screen.dart';
import 'denoise_screen.dart';
import '../models/audio_file.dart';
import '../models/encoding_config.dart';
import '../services/ffmpeg_service.dart';
import '../services/whisper_service.dart';


class EncoderScreen extends StatefulWidget {
  final String? currentAudiobookPath;
  
  const EncoderScreen({
    super.key,
    this.currentAudiobookPath,
  });

  @override
  State<EncoderScreen> createState() => _EncoderScreenState();
}

class _EncoderScreenState extends State<EncoderScreen> {
  final FFmpegService _ffmpeg = FFmpegService();
  List<AudioFile> _files = [];
  bool _loading = false;
  bool _encoding = false;
  bool _cancelEncoding = false;
  double _progress = 0.0;
  String _statusMessage = '';
  int _completedFiles = 0;
  bool _useFilenames = true;
  List<AudioFile>? _titleCaseHistory;
  String? _lastEncodedPath;
  String? _lastEncodingTime;
  bool _extracting = false;
  String _extractionStatus = '';

  final WhisperService _whisperService = WhisperService();

  bool _showSearchReplace = false;
  bool _useRegex = false;
  final _searchController = TextEditingController();
  final _replaceController = TextEditingController();
  bool _isPreviewingReplace = false;
  Map<int, String> _originalReplaceValues = {};
  
  int _bitrate = 16;
  bool _removeSilence = false;
  int _silenceDb = 34;
  bool _removeHiss = false;
  final _authorController = TextEditingController();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController(
    text: DateTime.now().year.toString()
  );

  Duration? _lastOriginalDuration;
  Duration? _lastFinalDuration;

  bool _showHissPreview = false;
  bool _generatingHissPreview = false;
  String _hissPreviewStatus = '';
  String? _originalPreviewPath;
  String? _hissReducedPreviewPath;
  
  final Player _originalPlayer = Player();
  final Player _hissReducedPlayer = Player();
  bool _originalPlaying = false;
  bool _hissReducedPlaying = false;
  Duration _originalPosition = Duration.zero;
  Duration _hissReducedPosition = Duration.zero;
  Duration _originalDuration = Duration.zero;
  Duration _hissReducedDuration = Duration.zero;

  bool _showPasteList = false;
  final _pasteListController = TextEditingController();
  List<String> _parsedNames = [];
  String _lastPastedList = '';
  String _secondLastPastedList = '';
  bool _isPreviewingPastedList = false;
  Map<int, String> _originalPastedListTitles = {};

  static const String _surahList = '''001 Al-Fatiha (The Opener)
  002 Al-Baqarah (The Cow)
  003 Al-Imran (Family of Imran)
  004 An-Nisa (The Women)
  005 Al-Ma'idah (The Table Spread)
  006 Al-Anam (The Cattle)
  007 Al-A'raf (The Heights)
  008 Al-Anfal (The Spoils of War)
  009 At-Taubah (The Repentance)
  010 Yunus (Jonah)
  011 Hud (Hud)
  012 Yusuf (Joseph)
  013 Ar-Ra'd (Thunder)
  014 Ibrahim (Abraham)
  015 Al-Hijr (The Rocky Tract)
  016 An-Nahl (The Bee)
  017 Al-Isra (The Night Journey)
  018 Al-Kahf (The Cave)
  019 Maryam (Mary)
  020 Ta-Ha
  021 Al-Anbiya (The Prophets)
  022 Al-Hajj (The Pilgrimage)
  023 Al-Mu'minun (The Believers)
  024 An-Nur (The Light)
  025 Al-Furqan (The Criterion)
  026 Ash-Shu'ara (The Poets)
  027 An-Naml (The Ant)
  028 Al-Qasas (The Stories)
  029 Al-Ankabut (The Spider)
  030 Ar-Rum (The Romans)
  031 Luqman
  032 As-Sajdah (Prostration)
  033 Al-Ahzab (The Confederates)
  034 Saba (Sheba)
  035 Fatir (The Originator of Creation)
  036 Ya-Sin
  037 As-Saffat (Those Arranged in Ranks)
  038 Saad
  039 Az-Zumar (The Groups)
  040 Ghafir (The Forgiver or The Believer)
  041 Fussilat (Explained in Detail)
  042 Ash-Shura (The Consultation)
  043 Az-Zukhruf (The Gold Ornaments)
  044 Ad-Dukhan (The Smoke)
  045 Al-Jathiyah (The Kneeling)
  046 Al-Ahqaf (The Wind Curved Sandhill)
  047 Muhammad (The Fighting)
  048 Al-Fath (The Victory)
  049 Al-Hujurat (The Dwellings)
  050 Qaf (Qaf)
  051 Adh-Dhariyat (The Winds That Scatter)
  052 At-Tur (The Mount)
  053 An-Najm (The Star)
  054 Al-Qamar (The Moon)
  055 Ar-Rahman (The Most Gracious)
  056 Al-Waqi'ah (The Event)
  057 Al-Hadid (The Iron)
  058 Al-Mujadila (The Woman Who Disputes)
  059 Al-Hashr (The Exile)
  060 Al-Mumtahanah (The Woman to Be Examined)
  061 As-Saff (The Ranks)
  062 Al-Jumu'ah (Friday)
  063 Al-Munafiqun (The Hypocrites)
  064 At-Taghabun (Mutual Loss or Gain)
  065 At-Talaq (The Divorce)
  066 At-Tahrim (The Prohibition)
  067 Al-Mulk (Dominion)
  068 Al-Qalam (The Pen)
  069 Al-Haqqah (The Inevitable)
  070 Al-Ma'arij (The Ways of Ascent)
  071 Nuh (Noah)
  072 Al-Jinn (The Jinn)
  073 Al-Muzzammil (The Enshrouded One)
  074 Al-Muddaththir (The Cloaked One)
  075 Al-Qiyamah (The Resurrection)
  076 Al-Insan (Man or Time)
  077 Al-Mursalat (The Emissaries)
  078 An-Naba (The Tidings)
  079 An-Nazi'at (Those Who Pull Out)
  080 Abasa (He Frowned)
  081 At-Takwir (The Overthrowing)
  082 Al-Infitar (The Cleaving)
  083 Al-Mutaffifin (Those Who Deal in Fraud)
  084 Al-Inshiqaq (The Splitting Asunder)
  085 Al-Buruj (The Mansions of the Stars)
  086 At-Tariq (The Night Comer)
  087 Al-Ala (The Most High)
  088 Al-Ghashiyah (The Overwhelming)
  089 Al-Fajr (The Dawn)
  090 Al-Balad (The City)
  091 Ash-Shams (The Sun)
  092 Al-Lail (The Night)
  093 Ad-Duha (The Forenoon - After Sunrise)
  094 Ash-Sharh (The Opening Forth)
  095 At-Tin (The Fig)
  096 Al-Alaq (The Clot)
  097 Al-Qadr (The Night of Decree)
  098 Al-Bayyina (The Clear Evidence)
  099 Az-Zalzalah (The Earthquake)
  100 Al-Adiyat (The Courser)
  101 Al-Qari'ah (The Calamity)
  102 At-Takathur (Vying for Worldly Increase)
  103 Al-Asr (The Declining Day)
  104 Al-Humazah (The Slanderer)
  105 Al-Fil (The Elephant)
  106 Quraysh
  107 Al-Ma'un (The Small Kindness)
  108 Al-Kawthar (The Abundance)
  109 Al-Kafirun (The Disbelievers)
  110 An-Nasr (The Divine Support)
  111 Al-Masad (The Palm Fiber)
  112 Al-Ikhlas (The Sincerity)
  113 Al-Falaq (The Daybreak)
  114 An-Nas (The Mankind)''';
  
    static const String _surahArabicList = '''001 الفاتحة Al-Fatiha (The Opening)
  002 البقرة Al-Baqarah (The Cow)
  003 آل عمران Aal-E-Imran (The Family of Imran)
  004 النساء An-Nisa' (The Women)
  005 المائدة Al-Ma'idah (The Table Spread)
  006 الأنعام Al-An'am (The Cattle)
  007 الأعراف Al-A'raf (The Heights)
  008 الأنفال Al-Anfal (The Spoils of War)
  009 التوبة At-Tawbah (The Repentance)
  010 يونس Yunus (Jonah)
  011 هود Hud
  012 يوسف Yusuf (Joseph)
  013 الرعد Ar-Ra'd (The Thunder)
  014 إبراهيم Ibrahim (Abraham)
  015 الحجر Al-Hijr (The Rocky Tract)
  016 النحل An-Nahl (The Bee)
  017 الإسراء Al-Isra' (The Night Journey)
  018 الكهف Al-Kahf (The Cave)
  019 مريم Maryam (Mary)
  020 طه Ta-Ha
  021 الأنبياء Al-Anbiya' (The Prophets)
  022 الحج Al-Hajj (The Pilgrimage)
  023 المؤمنون Al-Mu'minun (The Believers)
  024 النور An-Nur (The Light)
  025 الفرقان Al-Furqan (The Criterion)
  026 الشعراء Ash-Shu'ara (The Poets)
  027 النمل An-Naml (The Ant)
  028 القصص Al-Qasas (The Stories)
  029 العنكبوت Al-Ankabut (The Spider)
  030 الروم Ar-Rum (The Romans)
  031 لقمان Luqman
  032 السجدة As-Sajda (The Prostration)
  033 الأحزاب Al-Ahzab (The Combined Forces)
  034 سبأ Saba' (Sheba)
  035 فاطر Fatir (The Originator of Creation)
  036 يس Ya-Sin
  037 الصافات As-Saffat (Those Arranged in Ranks)
  038 ص Saad
  039 الزمر Az-Zumar (The Groups)
  040 غافر Ghafir (The Forgiver or The Believer)
  041 فصلت Fussilat (Explained in Detail)
  042 الشورى Ash-Shura (The Consultation)
  043 الزخرف Az-Zukhruf (The Gold Adornments)
  044 الدخان Ad-Dukhan (The Smoke)
  045 الجاثية Al-Jathiya (The Kneeling)
  046 الأحقاف Al-Ahqaf (The Wind-Curved Sandhills)
  047 محمد Muhammad (The Fighting)
  048 الفتح Al-Fath (The Victory)
  049 الحجرات Al-Hujurat (The Dwellings)
  050 ق Qaf
  051 الذاريات Adh-Dhariyat (The Winds That Scatter)
  052 الطور At-Tur (The Mount)
  053 النجم An-Najm (The Star)
  054 القمر Al-Qamar (The Moon)
  055 الرحمن Ar-Rahman (The Most Gracious)
  056 الواقعة Al-Waqi'a (The Inevitable)
  057 الحديد Al-Hadid (The Iron)
  058 المجادلة Al-Mujadila (The Woman Who Disputes)
  059 الحشر Al-Hashr (The Exile)
  060 الممتحنة Al-Mumtahina (The Woman to Be Examined)
  061 الصف As-Saff (The Row or the Rank)
  062 الجمعة Al-Jumu'a (Friday)
  063 المنافقون Al-Munafiqun (The Hypocrites)
  064 التغابن At-Taghabun (The Mutual Loss or Gain)
  065 الطلاق At-Talaq (The Divorce)
  066 التحريم At-Tahrim (The Prohibition)
  067 الملك Al-Mulk (Dominion)
  068 القلم Al-Qalam (The Pen)
  069 الحاقة Al-Haqqah (The Inevitable)
  070 المعارج Al-Ma'arij (The Ways of Ascent)
  071 نوح Nuh (Noah)
  072 الجن Al-Jinn (The Jinn)
  073 المزمل Al-Muzzammil (The Enshrouded One)
  074 المدثر Al-Muddathir (The Cloaked One)
  075 القيامة Al-Qiyama (The Resurrection)
  076 الإنسان Al-Insan (Man or Time)
  077 المرسلات Al-Mursalat (The Emissaries)
  078 النبأ An-Naba' (The Tidings)
  079 النازعات An-Nazi'at (Those Who Pull Out)
  080 عبس Abasa (He Frowned)
  081 التكوير At-Takwir (The Overthrowing)
  082 الإنفطار Al-Infitar (The Cleaving)
  083 المطففين Al-Mutaffifin (Those Who Deal in Fraud)
  084 الإنشقاق Al-Inshiqaq (The Splitting Asunder)
  085 البروج Al-Burooj (The Mansions of the Stars)
  086 الطارق At-Tariq (The Morning Star)
  087 الأعلى Al-A'la (The Most High)
  088 الغاشية Al-Ghashiyah (The Overwhelming)
  089 الفجر Al-Fajr (The Dawn)
  090 البلد Al-Balad (The City)
  091 الشمس Ash-Shams (The Sun)
  092 الليل Al-Lail (The Night)
  093 الضحى Ad-Duha (The Forenoon -  After Sunrise)
  094 الشرح Ash-Sharh (The Opening Forth)
  095 التين At-Tin (The Fig)
  096 العلق Al-Alaq (The Clot)
  097 القدر Al-Qadr (The Night of Decree)
  098 البينة Al-Bayyina (The Clear Evidence)
  099 الزلزلة Az-Zalzalah (The Earthquake)
  100 العاديات Al-Adiyat (Those That Run)
  101 القارعة Al-Qari'a (The Calamity)
  102 التكاثر At-Takathur (Vying for Worldly Increase)
  103 العصر Al-Asr (The Declining Day)
  104 الهمزة Al-Humazah (The Slanderer)
  105 الفيل Al-Fil (The Elephant)
  106 قريش Quraysh
  107 الماعون Al-Ma'un (The Small Kindnesses)
  108 الكوثر Al-Kawthar (The Abundance)
  109 الكافرون Al-Kafirun (The Disbelievers)
  110 النصر An-Nasr (The Divine Support)
  111 المسد Al-Masad (The Palm Fiber)
  112 الإخلاص Al-Ikhlas (The Sincerity)
  113 الفلق Al-Falaq (The Daybreak)
  114 الناس An-Nas (The Mankind)''';
  
  @override
  void initState() {
    super.initState();
    _checkFFmpeg();
    _whisperService.initialize();
  }
  
  @override
  void dispose() {
    _authorController.dispose();
    _titleController.dispose();
    _yearController.dispose();
    _searchController.dispose();
    _replaceController.dispose();
    _hissReducedPlayer.dispose();
    _pasteListController.dispose();
    super.dispose();
  }
  
  Future<void> _checkFFmpeg() async {
    final available = await _ffmpeg.checkFFmpegAvailable();
    if (!available && mounted) {
      _showError('FFmpeg not found!\n\nInstall:\nMac: brew install ffmpeg\nLinux: sudo apt install ffmpeg\nWindows: choco install ffmpeg');
    }
  }
  
  String _getFilenameWithoutExt(String filepath) {
    return filepath.split('/').last.replaceAll(RegExp(r'\.[^.]+$'), '');
  }
  
  String _titleCaseString(String text) {
        final smallWords = RegExp(r'^(a|an|and|as|at|but|by|en|for|if|in|nor|of|on|or|per|the|to|up|v\.?|vs\.?|via|with)$', caseSensitive: false);
        
        final parts = <String>[];
        final regex = RegExp(r'(\S+|\s+)');
        for (final match in regex.allMatches(text)) {
          parts.add(match.group(0)!);
        }
        
        final nonWhitespace = parts.where((p) => p.trim().isNotEmpty).toList();
        
        return parts.asMap().entries.map((entry) {
          final idx = entry.key;
          final part = entry.value;
          
          if (part.trim().isEmpty) return part;
          
          final word = part;
          final isFirstWord = word == nonWhitespace.first;
          final isLastWord = word == nonWhitespace.last;
          
          if (idx > 0) {
            final prevPart = parts[idx - 1];
            if (prevPart.contains(':') || prevPart.contains('：') || 
                (idx > 1 && (parts[idx - 2].contains(':') || parts[idx - 2].contains('：')))) {
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            }
          }
          
          if (word.startsWith('"') || word.startsWith('＂')) {
            if (word.length > 1) {
              final openQuote = word[0];
              return openQuote + word[1].toUpperCase() + word.substring(2).toLowerCase();
            }
          }
          
          if (idx > 0) {
            final prevPart = parts[idx - 1];
            if (prevPart == '"' || prevPart == '＂' || 
                (prevPart.trim().isEmpty && idx > 1 && (parts[idx - 2] == '"' || parts[idx - 2] == '＂'))) {
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            }
          }
          
          if (!isFirstWord && nonWhitespace.isNotEmpty) {
            final prevIndex = nonWhitespace.indexOf(word) - 1;
            if (prevIndex >= 0) {
              final prevWord = nonWhitespace[prevIndex];
              if (prevWord == nonWhitespace.first && 
                  RegExp(r'^\d+\.?$').hasMatch(prevWord)) {
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }
              
              if (prevWord.contains(':') || prevWord.contains('：')) {
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }
              
              if (prevWord == '"' || prevWord == '＂' || prevWord.endsWith('"') || prevWord.endsWith('＂')) {
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }
            }
          }
          
          if (RegExp(r'^[Aa][dlnstrz]-').hasMatch(word)) {
            final prefix = word.substring(0, 3);
            final rest = word.substring(3);
            if (rest.isNotEmpty) {
              return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase() + 
                     rest[0].toUpperCase() + rest.substring(1).toLowerCase();
            }
            return prefix[0].toUpperCase() + prefix.substring(1).toLowerCase();
          }
          
          if (word.contains('(')) {
            return word.split('').asMap().entries.map((e) {
              if (e.value == '(' && e.key + 1 < word.length) return e.value;
              if (e.key > 0 && word[e.key - 1] == '(') return e.value.toUpperCase();
              return e.value.toLowerCase();
            }).join('');
          }
          
          if (isFirstWord || isLastWord) {
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }
          
          if (smallWords.hasMatch(word)) {
            return word.toLowerCase();
          }
          
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join('');
      }
    
  void _toggleReplacePreview() {
      if (_searchController.text.isEmpty) {
        _showError('Please enter a search term');
        return;
      }
      
      setState(() {
        if (_isPreviewingReplace) {
          for (final entry in _originalReplaceValues.entries) {
            _files[entry.key].editedTitle = entry.value;
          }
          _originalReplaceValues.clear();
          _isPreviewingReplace = false;
        } else {
          _originalReplaceValues.clear();
          
          for (int i = 0; i < _files.length; i++) {
            final currentTitle = _files[i].editedTitle.isNotEmpty 
                ? _files[i].editedTitle 
                : (_useFilenames ? _getFilenameWithoutExt(_files[i].path) : _files[i].originalTitle);
            
            String newTitle;
            if (_useRegex) {
              try {
                final regex = RegExp(_searchController.text);
                if (regex.hasMatch(currentTitle)) {
                  _originalReplaceValues[i] = currentTitle;
                  newTitle = currentTitle.replaceAllMapped(
                    regex,
                    (match) {
                      String result = _replaceController.text;
                      for (int j = 0; j <= match.groupCount; j++) {
                        result = result.replaceAll('\$$j', match.group(j) ?? '');
                      }
                      return result;
                    },
                  );
                  _files[i].editedTitle = newTitle;
                }
              } catch (e) {
                _showError('Invalid regex pattern: $e');
                setState(() {
                  for (final entry in _originalReplaceValues.entries) {
                    _files[entry.key].editedTitle = entry.value;
                  }
                  _originalReplaceValues.clear();
                  _isPreviewingReplace = false;
                });
                return;
              }
            } else {
              if (currentTitle.contains(_searchController.text)) {
                _originalReplaceValues[i] = currentTitle;
                newTitle = currentTitle.replaceAll(_searchController.text, _replaceController.text);
                _files[i].editedTitle = newTitle;
              }
            }
          }
          
          _isPreviewingReplace = true;
        }
      });
    }
    
    void _applySearchReplace() {
      if (_searchController.text.isEmpty) {
        _showError('Please enter a search term');
        return;
      }
      
      setState(() {
        if (!_isPreviewingReplace) {
          for (int i = 0; i < _files.length; i++) {
            final currentTitle = _files[i].editedTitle.isNotEmpty 
                ? _files[i].editedTitle 
                : (_useFilenames ? _getFilenameWithoutExt(_files[i].path) : _files[i].originalTitle);
            
            String newTitle;
            if (_useRegex) {
              try {
                final regex = RegExp(_searchController.text);
                newTitle = currentTitle.replaceAllMapped(
                  regex,
                  (match) {
                    String result = _replaceController.text;
                    for (int j = 0; j <= match.groupCount; j++) {
                      result = result.replaceAll('\$$j', match.group(j) ?? '');
                    }
                    return result;
                  },
                );
              } catch (e) {
                _showError('Invalid regex pattern: $e');
                return;
              }
            } else {
              newTitle = currentTitle.replaceAll(_searchController.text, _replaceController.text);
            }
            
            _files[i].editedTitle = newTitle;
          }
        }
        
        _originalReplaceValues.clear();
        _isPreviewingReplace = false;
      });
      
      _showSuccess('Replacements applied');
    }

   void _loadPredefinedList(String list) {
     setState(() {
       _pasteListController.text = list;
       _parseList();
     });
   }
   
   void _parseList() {
     final text = _pasteListController.text.trim();
     if (text.isEmpty) {
       setState(() {
         _parsedNames = [];
       });
       return;
     }
   
     final lines = text.split('\n')
         .where((line) => line.trim().isNotEmpty)
         .map((line) => line.trim())
         .toList();
   
     setState(() {
       _parsedNames = lines;
     });
   }
   
   void _applyPastedList() {
     if (_parsedNames.length != _files.length) {
       _showError('List has ${_parsedNames.length} lines but you have ${_files.length} files');
       return;
     }
   
     setState(() {
       if (_pasteListController.text.trim().isNotEmpty) {
         _secondLastPastedList = _lastPastedList;
         _lastPastedList = _pasteListController.text.trim();
       }
   
       for (int i = 0; i < _files.length; i++) {
         final newName = _parsedNames[i];
         _files[i].editedTitle = newName;
       }
       
       _isPreviewingPastedList = false;
     });
   
     _showSuccess('Names applied from list');
   } 

  void _applyTitleCase() {
    if (_titleCaseHistory != null) {
      setState(() {
        _files = _titleCaseHistory!;
        _titleCaseHistory = null;
      });
      return;
    }

    setState(() {
      _titleCaseHistory = List.from(_files);
      _files = _files.map((file) {
        final currentTitle = file.editedTitle.isNotEmpty 
            ? file.editedTitle 
            : (_useFilenames ? _getFilenameWithoutExt(file.path) : file.originalTitle);
        final titleCased = _titleCaseString(currentTitle);
        return AudioFile(
          path: file.path,
          filename: file.filename,
          duration: file.duration,
          originalTitle: file.originalTitle,
          editedTitle: titleCased,
        );
      }).toList();
    });
  }
  
  void _toggleTitleSource() {
    setState(() {
      _useFilenames = !_useFilenames;
      _files = _files.map((file) => AudioFile(
        path: file.path,
        filename: file.filename,
        duration: file.duration,
        originalTitle: file.originalTitle,
        editedTitle: _useFilenames 
            ? _getFilenameWithoutExt(file.path) 
            : file.originalTitle,
      )).toList();
    });
  }

  Future<void> _extractChapters() async {
    String? filePath;
    
    if (widget.currentAudiobookPath != null) {
      final audiobookName = path.basename(widget.currentAudiobookPath!);
      
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            'Extract Chapters',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Extract chapters from which audiobook?',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.audiotrack, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Currently loaded:\n$audiobookName',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'select'),
              child: const Text('Choose Audiobook'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'current'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
              ),
              child: const Text('Use Current Loaded Audiobook'),
            ),
          ],
        ),
      );
      
      if (choice == null || choice == 'cancel') return;
      
      if (choice == 'current') {
        filePath = widget.currentAudiobookPath;
      }
    }
    
    if (filePath == null) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['opus', 'm4a', 'm4b', 'ogg', 'mkv'],
      );
      
      if (result == null || result.files.isEmpty) return;
      
      filePath = result.files.first.path!;
    }
    
    final ext = path.extension(filePath).toLowerCase();
    
    if (ext != '.opus' && ext != '.m4a' && ext != '.m4b' && ext != '.mkv' && ext != '.ogg') {
      _showError('Please select an .opus, .m4a, .m4b, .ogg or .mkv file');
      return;
    }
    
    setState(() {
      _extracting = true;
      _extractionStatus = 'Starting extraction...';
    });
    
    final startTime = DateTime.now();
    
    try {
      await _ffmpeg.extractChapters(
        audiobookPath: filePath,
        onProgress: (message) {
          if (mounted) {
            setState(() {
              _extractionStatus = message;
            });
          }
        },
      );
      
      final elapsed = DateTime.now().difference(startTime);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds.remainder(60);
      
      setState(() {
        _extracting = false;
        _extractionStatus = 'Complete!';
      });
      
      _showSuccess('Chapters extracted in ${minutes}m ${seconds}s');
    } catch (e) {
      setState(() {
        _extracting = false;
        _extractionStatus = 'Error: $e';
      });
      _showError('Extraction failed: $e');
    }
  }
  
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'aac', 'opus', 'ogg', 'flac', 'wav', 'wma', 'webm', 'mkv', 'mp4'],
      );
      
      if (result == null) return;
      
      setState(() => _loading = true);
      
      final audioFiles = <AudioFile>[];
      for (final file in result.files) {
        if (file.path == null) continue;
        
        try {
          final info = await _ffmpeg.getAudioInfo(file.path!);
          audioFiles.add(AudioFile(
            path: info.path,
            filename: info.filename,
            duration: info.duration,
            originalTitle: info.originalTitle,
            editedTitle: _useFilenames 
                ? _getFilenameWithoutExt(info.path) 
                : info.originalTitle,
          ));
        } catch (e) {
          print('Error loading ${file.name}: $e');
        }
      }
      
      audioFiles.sort((a, b) => a.path.compareTo(b.path));
      
      setState(() {
        _files = audioFiles;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error picking files: $e');
    }
  }
  
  Future<void> _pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      
      if (result == null) return;
      
      setState(() => _loading = true);
      
      final audioFiles = await _ffmpeg.listAudioFilesInDirectory(result);
      final processedFiles = audioFiles.map((file) => AudioFile(
        path: file.path,
        filename: file.filename,
        duration: file.duration,
        originalTitle: file.originalTitle,
        editedTitle: _useFilenames 
            ? _getFilenameWithoutExt(file.path) 
            : file.originalTitle,
      )).toList();
      
      setState(() {
        _files = processedFiles;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showError('Error loading folder: $e');
    }
  }
  
  void _editTitle(int index) {
    final controller = TextEditingController(text: _files[index].editedTitle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Chapter Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Chapter Title',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _files[index].editedTitle = controller.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateHissPreview() async {
    if (_files.isEmpty) {
      _showError('No files selected');
      return;
    }
    
    setState(() {
      _generatingHissPreview = true;
      _hissPreviewStatus = 'Generating preview...';
      _showHissPreview = true;
    });
    
    try {
      final random = Random();
      final randomFile = _files[random.nextInt(_files.length)];
      
      final firstFilePath = _files[0].path;
      final sourceDir = path.dirname(firstFilePath);
      final previewDir = path.join(sourceDir, 'hiss_preview');
      
      final dir = Directory(previewDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      await dir.create(recursive: true);
      
      final originalPath = path.join(previewDir, 'original.opus');
      final hissReducedPath = path.join(previewDir, 'hiss_reduced.opus');
      
      setState(() {
        _hissPreviewStatus = 'Encoding original: ${path.basename(randomFile.path)}';
      });
      
      await _ffmpeg.encodeChapter(
        inputPath: randomFile.path,
        outputPath: originalPath,
        config: EncodingConfig(
          bitrate: _bitrate,
          removeSilence: false,
          removeHiss: false,
          author: 'Preview',
          title: 'Original',
          year: '2024',
        ),
        onProgress: (_) {},
      );
      
      setState(() {
        _hissPreviewStatus = 'Encoding with hiss reduction...';
      });
      
      await _ffmpeg.encodeChapter(
        inputPath: randomFile.path,
        outputPath: hissReducedPath,
        config: EncodingConfig(
          bitrate: _bitrate,
          removeSilence: false,
          removeHiss: true,
          author: 'Preview',
          title: 'Hiss Reduced',
          year: '2026',
        ),
        onProgress: (_) {},
      );
      
      _originalPlayer.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _originalDuration = duration;
          });
        }
      });
      
      _originalPlayer.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _originalPosition = position;
          });
        }
      });
      
      _originalPlayer.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _originalPlaying = playing;
          });
        }
      });
      
      _hissReducedPlayer.stream.duration.listen((duration) {
        if (mounted) {
          setState(() {
            _hissReducedDuration = duration;
          });
        }
      });
      
      _hissReducedPlayer.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            _hissReducedPosition = position;
          });
        }
      });
      
      _hissReducedPlayer.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _hissReducedPlaying = playing;
          });
        }
      });
      
      await _originalPlayer.open(Media(originalPath), play: false);
      await _hissReducedPlayer.open(Media(hissReducedPath), play: false);
      
      setState(() {
        _originalPreviewPath = originalPath;
        _hissReducedPreviewPath = hissReducedPath;
        _generatingHissPreview = false;
        _hissPreviewStatus = 'Preview ready: ${path.basename(randomFile.path)}';
      });
      
    } catch (e) {
      setState(() {
        _generatingHissPreview = false;
        _hissPreviewStatus = 'Error: $e';
      });
      _showError('Preview failed: $e');
    }
  }
  
  Future<void> _playPauseOriginal() async {
    if (_originalPlaying) {
      await _originalPlayer.pause();
    } else {
      await _originalPlayer.play();
    }
  }
  
  Future<void> _playPauseHissReduced() async {
    if (_hissReducedPlaying) {
      await _hissReducedPlayer.pause();
    } else {
      await _hissReducedPlayer.play();
    }
  }
  
  Future<void> _seekOriginal(Duration position) async {
    await _originalPlayer.seek(position);
  }
  
  Future<void> _seekHissReduced(Duration position) async {
    await _hissReducedPlayer.seek(position);
  }

  String _formatTime(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildHissPreviewPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.preview, color: Colors.deepOrange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Hiss Reduction Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _generatingHissPreview ? null : _generateHissPreview,
                    icon: const Icon(Icons.shuffle, size: 16),
                    label: const Text('Random Chapter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () {
                      setState(() {
                        _showHissPreview = false;
                      });
                    },
                    tooltip: 'Close preview',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_generatingHissPreview)
            Column(
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  _hissPreviewStatus,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            )
          else if (_originalPreviewPath != null && _hissReducedPreviewPath != null) ...[
            Text(
              _hissPreviewStatus,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPreviewPlayer(
                    title: 'Original',
                    isPlaying: _originalPlaying,
                    position: _originalPosition,
                    duration: _originalDuration,
                    onPlayPause: _playPauseOriginal,
                    onSeek: _seekOriginal,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildPreviewPlayer(
                    title: 'Hiss Reduced',
                    isPlaying: _hissReducedPlaying,
                    position: _hissReducedPosition,
                    duration: _hissReducedDuration,
                    onPlayPause: _playPauseHissReduced,
                    onSeek: _seekHissReduced,
                    color: Colors.deepOrange,
                  ),
                ),
              ],
            ),
          ] else
            const Text(
              'Click "Random Chapter" to generate a preview',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
        ],
      ),
    );
  }
  
  Widget _buildPreviewPlayer({
    required String title,
    required bool isPlaying,
    required Duration position,
    required Duration duration,
    required VoidCallback onPlayPause,
    required Function(Duration) onSeek,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: color,
                  size: 40,
                ),
                onPressed: onPlayPause,
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(position),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: duration.inMilliseconds > 0
                        ? position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble())
                        : 0,
                    max: duration.inMilliseconds.toDouble() > 0 ? duration.inMilliseconds.toDouble() : 1,
                    activeColor: color,
                    inactiveColor: Colors.white24,
                    onChanged: (value) {
                      onSeek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startEncoding() async {
    if (_files.isEmpty) {
      _showError('No files selected');
      return;
    }
    
    if (_authorController.text.isEmpty || _titleController.text.isEmpty) {
      _showError('Please enter author and title');
      return;
    }
    
    final totalHours = _totalDuration.inHours;
    final needsSplit = totalHours >= 100 || _files.length > 999;
    
    if (needsSplit) {
      final splitPlan = _calculateSplitPlan();
      final shouldContinue = await _showSplitConfirmationDialog(splitPlan);
      if (!shouldContinue) return;
    }
    
    final startTime = DateTime.now();
    
    setState(() {
      _encoding = true;
      _cancelEncoding = false;
      _progress = 0.0;
      _completedFiles = 0;
      _statusMessage = 'Starting...';
    });
    
    try {
      final config = EncodingConfig(
        bitrate: _bitrate,
        removeSilence: _removeSilence,
        silenceDb: _removeSilence ? _silenceDb : null,
        removeHiss: _removeHiss,
        author: _authorController.text,
        title: _titleController.text,
        year: _yearController.text,
      );
      
      final firstFilePath = _files[0].path;
      final sourceDir = path.dirname(firstFilePath);
      
      final now = DateTime.now();
      final timestamp = '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}_${now.minute.toString().padLeft(2, '0')}_${now.second.toString().padLeft(2, '0')}';
      
      final outputDir = path.join(sourceDir, 'substitcher', timestamp);
      final encodedChaptersDir = path.join(outputDir, 'encodedchapters');
      
      Directory(encodedChaptersDir).createSync(recursive: true);
      
      setState(() {
        _statusMessage = 'Encoding chapters in parallel...';
      });
      
      final cpuCount = Platform.numberOfProcessors;
      final maxConcurrent = (cpuCount * 0.75).round().clamp(1, 8);
      
      print('Encoding with $maxConcurrent concurrent processes (detected $cpuCount CPUs)');
      
      final encodedFilesMap = <int, String>{};
      final semaphore = _Semaphore(maxConcurrent);
      final futures = <Future>[];
      
      for (var i = 0; i < _files.length; i++) {
        if (_cancelEncoding) {
          setState(() {
            _encoding = false;
            _statusMessage = 'Encoding cancelled';
          });
          _showError('Encoding cancelled by user');
          return;
        }
        
        final file = _files[i];
        final index = i;
        final titleForDisplay = file.displayTitle;
        var displayTitle = file.displayTitle;
        
        displayTitle = displayTitle
            .replaceAll('/', '-')
            .replaceAll("'", '`')
            .replaceAll('"', '`')
            .replaceAll(':', '-')
            .replaceAll('\\', '-')
            .replaceAll('|', '-')
            .replaceAll('?', '')
            .replaceAll('*', '')
            .replaceAll('<', '')
            .replaceAll('>', '');
        
        final outputPath = '$encodedChaptersDir/$displayTitle.opus';
        
        final future = semaphore.acquire().then((_) async {
          if (_cancelEncoding) {
            semaphore.release();
            return;
          }
          
          try {
            await _ffmpeg.encodeChapter(
              inputPath: file.path,
              outputPath: outputPath,
              config: config,
              onProgress: (chapterProgress) {
              },
            );
            
            encodedFilesMap[index] = outputPath;
            
            if (mounted) {
              setState(() {
                _completedFiles++;
                _progress = _completedFiles / _files.length;
                _statusMessage = 'Encoded $_completedFiles/${_files.length}: $titleForDisplay';
              });
            }
          } finally {
            semaphore.release();
          }
        });
        
        futures.add(future);
      }
      
      await Future.wait(futures);
      
      if (_cancelEncoding) {
        setState(() {
          _encoding = false;
          _statusMessage = 'Encoding cancelled';
        });
        _showError('Encoding cancelled by user');
        return;
      }
      
      final encodedFiles = List.generate(
        _files.length,
        (i) => encodedFilesMap[i]!,
      );
  
      Duration totalEncodedDuration = Duration.zero;
      for (final encodedPath in encodedFiles) {
        final dur = await _ffmpeg.getAudioDuration(encodedPath);
        totalEncodedDuration += dur;
      }
      
      final splits = _calculateAudiobookSplits(encodedFiles);
      
      if (splits.length > 1) {
        setState(() {
          _statusMessage = 'Organizing chapters into subdirectories...';
        });
        
        for (int splitIndex = 0; splitIndex < splits.length; splitIndex++) {
          final split = splits[splitIndex];
          final splitDir = path.join(outputDir, 'encodedchapters_${splitIndex + 1}');
          Directory(splitDir).createSync(recursive: true);
          
          for (final filePath in split['files']) {
            final fileName = path.basename(filePath);
            final newPath = path.join(splitDir, fileName);
            await File(filePath).rename(newPath);
            
            final fileIndex = (split['files'] as List<String>).indexOf(filePath);
            (split['files'] as List<String>)[fileIndex] = newPath;
          }
        }
        
        await Directory(encodedChaptersDir).delete();
      }
      
      for (int splitIndex = 0; splitIndex < splits.length; splitIndex++) {
        final split = splits[splitIndex];
        final splitTitle = splits.length > 1 
            ? '${config.title}_${splitIndex + 1}'
            : config.title;
        
        setState(() {
          _statusMessage = splits.length > 1
              ? 'Creating audiobook ${splitIndex + 1}/${splits.length}...'
              : 'Creating final audiobook...';
          _progress = 0.99;
        });
        
        final finalPath = path.join(outputDir, '${config.author} - $splitTitle.opus');
        
        await _ffmpeg.concatenateWithChapters(
          opusFiles: split['files'],
          outputPath: finalPath,
          config: config.copyWith(title: splitTitle),
          onProgress: (message) {
            setState(() => _statusMessage = message);
          },
        );
      }
  
      final originalDuration = _totalDuration;
      final finalDuration = totalEncodedDuration;
      
      setState(() {
        _encoding = false;
        _progress = 1.0;
        _statusMessage = 'Complete!';
      });
      
      final elapsed = DateTime.now().difference(startTime);
      final minutes = elapsed.inMinutes;
      final seconds = elapsed.inSeconds.remainder(60);
      
      if (mounted) {
        setState(() {
          _lastEncodedPath = path.join(outputDir, '${config.author} - ${config.title}${splits.length > 1 ? '_1' : ''}.opus');
          _lastEncodingTime = '${minutes}m ${seconds}s';
          _lastOriginalDuration = originalDuration;
          _lastFinalDuration = finalDuration;
        });
      }
      
      _showSuccess(splits.length > 1 
          ? 'Created ${splits.length} audiobooks successfully!'
          : 'Audiobook created successfully!');
      
    } catch (e) {
      setState(() {
        _encoding = false;
        _statusMessage = 'Error: $e';
      });
      _showError('Encoding failed: $e');
    }
  }  
  
  Map<String, dynamic> _calculateSplitPlan() {
    final totalHours = _totalDuration.inHours;
    final totalChapters = _files.length;
    
    int numBooks = 1;
    int targetHoursPerBook = totalHours;
    
    if (totalHours >= 100) {
      numBooks = (totalHours / 100).ceil();
      targetHoursPerBook = (totalHours / numBooks).ceil();
    }
    
    if (totalChapters > 999) {
      final booksNeededForChapters = (totalChapters / 999).ceil();
      if (booksNeededForChapters > numBooks) {
        numBooks = booksNeededForChapters;
        targetHoursPerBook = (totalHours / numBooks).ceil();
      }
    }
    
    return {
      'numBooks': numBooks,
      'targetHoursPerBook': targetHoursPerBook,
      'totalHours': totalHours,
      'totalChapters': totalChapters,
    };
  }
  
  Future<bool> _showSplitConfirmationDialog(Map<String, dynamic> plan) async {
    final totalDuration = _totalDuration;
    final numBooks = plan['numBooks'] as int;
    final targetDurationPerBook = totalDuration ~/ numBooks;
    
    final splitPreviews = <Map<String, dynamic>>[];
    int currentStartIndex = 0;
    
    for (int bookIndex = 0; bookIndex < numBooks; bookIndex++) {
      final isLastBook = bookIndex == numBooks - 1;
      int currentEndIndex = currentStartIndex;
      Duration bookDuration = Duration.zero;
      
      for (int i = currentStartIndex; i < _files.length; i++) {
        final chapterDuration = _files[i].duration;
        final potentialDuration = bookDuration + chapterDuration;
        
        if (isLastBook) {
          currentEndIndex = i;
          bookDuration = potentialDuration;
        } else {
          if (potentialDuration > targetDurationPerBook && i > currentStartIndex) {
            final smartEndIndex = _findSmartSplitPoint(i - 1, targetDurationPerBook, bookDuration);
            currentEndIndex = smartEndIndex;
            
            bookDuration = Duration.zero;
            for (int j = currentStartIndex; j <= currentEndIndex; j++) {
              bookDuration += _files[j].duration;
            }
            break;
          } else {
            currentEndIndex = i;
            bookDuration = potentialDuration;
          }
        }
      }
      
      final chapterCount = currentEndIndex - currentStartIndex + 1;
      
      splitPreviews.add({
        'bookNumber': bookIndex + 1,
        'startIndex': currentStartIndex,
        'endIndex': currentEndIndex,
        'startChapter': _files[currentStartIndex].displayTitle,
        'endChapter': _files[currentEndIndex].displayTitle,
        'chapterCount': chapterCount,
        'duration': bookDuration,
      });
      
      currentStartIndex = currentEndIndex + 1;
      if (currentStartIndex >= _files.length) break;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(
          children: [
            Icon(Icons.splitscreen, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Multiple Audiobooks Required',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your content will be split into ${plan['numBooks']} audiobooks:',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Duration:',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            '${plan['totalHours']}h',
                            style: const TextStyle(color: Colors.lightBlue, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Chapters:',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            '${plan['totalChapters']}',
                            style: const TextStyle(color: Colors.lightBlue, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Target per book:',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
                            '~${plan['targetHoursPerBook']}h',
                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Split Preview:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...splitPreviews.map((split) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Audiobook ${split['bookNumber']}',
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${split['chapterCount']} chapters • ${_formatDuration(split['duration'] as Duration)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox(
                            width: 60,
                            child: Text(
                              'First:',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${split['startIndex'] + 1}. ${split['startChapter']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const SizedBox(
                            width: 60,
                            child: Text(
                              'Last:',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${split['endIndex'] + 1}. ${split['endChapter']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Splits will avoid breaking multi-part chapters when possible',
                          style: TextStyle(color: Colors.blue, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  List<Map<String, dynamic>> _calculateAudiobookSplits(List<String> encodedFiles) {
    final totalDuration = _totalDuration;
    final totalHours = totalDuration.inHours;
    final totalChapters = encodedFiles.length;
    
    if (totalHours < 100 && totalChapters <= 999) {
      return [
        {
          'files': encodedFiles,
          'startIndex': 0,
          'endIndex': encodedFiles.length - 1,
        }
      ];
    }
    
    int numBooks = 1;
    
    if (totalHours >= 100) {
      numBooks = (totalHours / 100).ceil();
    }
    
    if (totalChapters > 999) {
      final booksNeededForChapters = (totalChapters / 999).ceil();
      if (booksNeededForChapters > numBooks) {
        numBooks = booksNeededForChapters;
      }
    }
    
    final targetDurationPerBook = totalDuration ~/ numBooks;
    final splits = <Map<String, dynamic>>[];
    
    int currentStartIndex = 0;
    
    for (int bookIndex = 0; bookIndex < numBooks; bookIndex++) {
      final isLastBook = bookIndex == numBooks - 1;
      int currentEndIndex = currentStartIndex;
      Duration bookDuration = Duration.zero;
      
      for (int i = currentStartIndex; i < _files.length; i++) {
        final chapterDuration = _files[i].duration;
        final potentialDuration = bookDuration + chapterDuration;
        
        if (isLastBook) {
          currentEndIndex = i;
          bookDuration = potentialDuration;
        } else {
          if (potentialDuration > targetDurationPerBook && i > currentStartIndex) {
            final smartEndIndex = _findSmartSplitPoint(i - 1, targetDurationPerBook, bookDuration);
            currentEndIndex = smartEndIndex;
            
            bookDuration = Duration.zero;
            for (int j = currentStartIndex; j <= currentEndIndex; j++) {
              bookDuration += _files[j].duration;
            }
            break;
          } else {
            currentEndIndex = i;
            bookDuration = potentialDuration;
          }
        }
      }
      
      final chapterCount = currentEndIndex - currentStartIndex + 1;
      if (chapterCount > 999) {
        print('WARNING: Split has $chapterCount chapters, exceeding 999 limit');
      }
      if (bookDuration.inHours >= 100) {
        print('WARNING: Split has ${bookDuration.inHours} hours, at/exceeding 100 hour limit');
      }
      
      splits.add({
        'files': encodedFiles.sublist(currentStartIndex, currentEndIndex + 1),
        'startIndex': currentStartIndex,
        'endIndex': currentEndIndex,
        'duration': bookDuration,
        'chapterCount': chapterCount,
      });
      
      currentStartIndex = currentEndIndex + 1;
      
      if (currentStartIndex >= _files.length) break;
    }
    
    return splits;
  }
  
  int _findSmartSplitPoint(int proposedEndIndex, Duration targetDuration, Duration currentDuration) {
    final lookbackRange = 10.clamp(0, proposedEndIndex);
    
    for (int i = proposedEndIndex; i > proposedEndIndex - lookbackRange && i >= 0; i--) {
      final nextTitle = i + 1 < _files.length ? _files[i + 1].displayTitle.toLowerCase() : '';
      
      final isMultiPartPattern = RegExp(r'part\s*\d+|pt\s*\d+|\(\d+\)|\[\d+\]', caseSensitive: false);
      final hasPartNumber = isMultiPartPattern.hasMatch(nextTitle);
      
      if (!hasPartNumber) {
        Duration adjustedDuration = Duration.zero;
        for (int j = 0; j <= i; j++) {
          adjustedDuration += _files[j].duration;
        }
        
        final variance = (adjustedDuration - targetDuration).abs();
        if (variance.inHours <= 5) {
          print('Smart split: Adjusted from index $proposedEndIndex to $i to avoid breaking multi-part chapter');
          return i;
        }
      }
    }
    
    return proposedEndIndex;
  }
  
  String _shortenPath(String path) {
    final home = Platform.environment['HOME'] ?? '/Users/${Platform.environment['USER']}';
    if (path.startsWith(home)) {
      return path.replaceFirst(home, '~');
    }
    return path;
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
  
  Duration get _totalDuration => _files.fold(
    Duration.zero,
    (sum, file) => sum + file.duration,
  );

   @override
   Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(
         title: Row(
           children: [
             if (_files.isNotEmpty) ...[
              const SizedBox(width: 32),
               ElevatedButton(
                 onPressed: _toggleTitleSource,
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 ),
                 child: Text(_useFilenames ? 'Using Filenames' : 'Using Metadata'),
               ),
               const SizedBox(width: 8),
               ElevatedButton(
                 onPressed: () {
                   setState(() {
                     _showPasteList = !_showPasteList;
                     if (!_showPasteList && _isPreviewingPastedList) {
                       for (final entry in _originalPastedListTitles.entries) {
                         _files[entry.key].editedTitle = entry.value;
                       }
                       _originalPastedListTitles.clear();
                       _isPreviewingPastedList = false;
                     }
                   });
                 },
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   backgroundColor: _showPasteList ? Colors.blue : null,
                 ),
                 child: const Text('Paste List'),
               ),
             ],
             const Expanded(
               child: Center(
                 child: Text('SubStitcher - Audiobook Encoder'),
               ),
             ),
             if (_files.isNotEmpty) ...[
               ElevatedButton(
                 onPressed: () {
                   setState(() {
                     _showSearchReplace = !_showSearchReplace;
                     if (!_showSearchReplace && _isPreviewingReplace) {
                       for (final entry in _originalReplaceValues.entries) {
                         _files[entry.key].editedTitle = entry.value;
                       }
                       _originalReplaceValues.clear();
                       _isPreviewingReplace = false;
                     }
                   });
                 },
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                 ),
                 child: const Text('Replace'),
               ),
               const SizedBox(width: 8),
               ElevatedButton(
                 onPressed: _applyTitleCase,
                 style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                   minimumSize: const Size(150, 36),
                 ),
                 child: Text(_titleCaseHistory != null ? 'Undo Title Case' : 'Apply Title Case'),
               ),
               const SizedBox(width: 30),
             ],
           ],
         ),
         backgroundColor: Theme.of(context).colorScheme.primaryContainer,
       ),
       body: _loading
           ? const Center(child: CircularProgressIndicator())
           : Column(
               children: [
                 if (_showSearchReplace) _buildSearchReplacePanel(),
                 if (_showPasteList) _buildPasteListPanel(),
                 if (_files.isNotEmpty) _buildFileListHeader(),
                 if (_showHissPreview) _buildHissPreviewPanel(),
                 
                 Expanded(
                   child: _files.isEmpty
                       ? _buildEmptyState()
                       : _buildFileList(),
                 ),
                 
                 if (_files.isNotEmpty) _buildConfigPanel(),
                 if (_encoding) _buildProgress(),
                 _buildActions(),
               ],
             ),
     );
   } 
  
  Widget _buildSearchReplacePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: _useRegex ? 'Search (regex mode)' : 'Search (plain text)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: _showRegexHelp,
                      tooltip: 'Show regex examples',
                    ),
                  ),
                  onChanged: (_) {
                    if (_isPreviewingReplace) {
                      setState(() {
                        for (final entry in _originalReplaceValues.entries) {
                          _files[entry.key].editedTitle = entry.value;
                        }
                        _originalReplaceValues.clear();
                        _isPreviewingReplace = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _replaceController,
                  decoration: const InputDecoration(
                    labelText: 'Replace',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    if (_isPreviewingReplace) {
                      setState(() {
                        for (final entry in _originalReplaceValues.entries) {
                          _files[entry.key].editedTitle = entry.value;
                        }
                        _originalReplaceValues.clear();
                        _isPreviewingReplace = false;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _toggleReplacePreview,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: _isPreviewingReplace ? Colors.orange : null,
                  foregroundColor: _isPreviewingReplace ? Colors.white : null,
                ),
                child: Text(_isPreviewingReplace ? 'Undo Preview' : 'Preview'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applySearchReplace,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _useRegex,
                onChanged: (value) {
                  setState(() {
                    _useRegex = value ?? false;
                    if (_isPreviewingReplace) {
                      for (final entry in _originalReplaceValues.entries) {
                        _files[entry.key].editedTitle = entry.value;
                      }
                      _originalReplaceValues.clear();
                      _isPreviewingReplace = false;
                    }
                  });
                },
              ),
              const Text('Use Regular Expressions'),
            ],
          ),
        ],
      ),
    );
  }
  
  void _showRegexHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Search & Replace Examples'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Simple Pattern Matching',
                [
                  _HelpExample('Chapter \\d+', 'Matches "Chapter " + any number'),
                  _HelpExample('Part \\d+', 'Matches "Part " + any number'),
                  _HelpExample('^\\d+', 'Matches numbers at start of title'),
                  _HelpExample('\\d+\\.', 'Matches numbers with a period'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Simple Text Changes',
                [
                  _HelpExample('Search: \\sThe\\s', 'Replace: " the " - Change "The" to "the" (middle only)'),
                  _HelpExample('Search: \\sAnd\\s', 'Replace: " and " - Change "And" to "and" (middle only)'),
                  _HelpExample('Search: (?<!^)\\bThe\\b(?!\$)', 'Replace: the - Change "The" to "the" (not at start/end)'),
                  _HelpExample('Search: (?<!^)\\bAnd\\b(?!\$)', 'Replace: and - Change "And" to "and" (not at start/end)'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Removing Unwanted Text',
                [
                  _HelpExample(' - Copy\$', 'Remove " - Copy" at the end'),
                  _HelpExample('^\\d+\\s*-\\s*', 'Remove "01 - " from start'),
                  _HelpExample('\\(.*?\\)', 'Remove anything in ( )'),
                  _HelpExample('\\[.*?\\]', 'Remove anything in [ ]'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Adding/Formatting',
                [
                  _HelpExample('Search: ^(\\d+)', 'Replace: Chapter \$1'),
                  _HelpExample('Search: ^', 'Replace: Part 1 - '),
                  _HelpExample('Search: \$', 'Replace:  (Unabridged)'),
                ],
              ),
              const Divider(height: 24),
              _buildHelpSection(
                'Cleaning Up',
                [
                  _HelpExample('\\s+ → (space)', 'Multiple spaces to one'),
                  _HelpExample('_ → (space)', 'Underscores to spaces'),
                  _HelpExample('- →  -  ', 'Add spaces around dashes'),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Use \\d for any digit (0-9)\n'
                '• Use ^ for start of text and position at start\n'
                '• Use \$ for end of text and position at end\n'
                '• Use \\s for whitespace\n'
                '• Use . for any character\n'
                '• Use * for zero or more\n'
                '• Use + for one or more\n'
                '• Use ? for zero or one\n'
                '• Use \\. \\? \\* to match literal characters\n'
                '• Use (group) and \$1 in replace for capture groups',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHelpSection(String title, List<_HelpExample> examples) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.purple,
          ),
        ),
        const SizedBox(height: 8),
        ...examples.map((example) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    children: [
                      TextSpan(
                        text: example.pattern,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: ' - '),
                      TextSpan(text: example.description),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.audiotrack, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No audio files selected',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Add Files" or "Add Folder" to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileListHeader() {
    final averageDuration = _files.isNotEmpty 
        ? Duration(milliseconds: (_totalDuration.inMilliseconds / _files.length).round())
        : Duration.zero;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_files.length} chapters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Row(
            children: [
              Text(
                'Average Chapter: ${_formatDuration(averageDuration)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                'Total: ${_formatDuration(_totalDuration)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFileList() {
      return ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final originalTitle = _useFilenames 
              ? _getFilenameWithoutExt(file.path) 
              : file.originalTitle;
          
          String displayTitle = file.displayTitle;
          String comparisonTitle = _isPreviewingReplace && _originalReplaceValues.containsKey(index)
              ? _originalReplaceValues[index]!
              : originalTitle;
          
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF006064),
              radius: 16,
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: _buildTitleWithHighlights(displayTitle, comparisonTitle),
                ),
                Text(
                  file.formattedDuration,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            onTap: () => _editTitle(index),
          );
        },
      );
    }
  
  
  Widget _buildTitleWithHighlights(String displayTitle, String originalTitle) {
    if (displayTitle == originalTitle) {
      return Text(
        displayTitle,
        style: const TextStyle(fontSize: 14),
      );
    }
    
    final isCaseOnlyChange = displayTitle.toLowerCase() == originalTitle.toLowerCase();
    
    if (isCaseOnlyChange) {
      final spans = <InlineSpan>[];
      
      for (int i = 0; i < displayTitle.length; i++) {
        final char = displayTitle[i];
        final isChanged = i < originalTitle.length && 
                         char != originalTitle[i] &&
                         char.toLowerCase() == originalTitle[i].toLowerCase();
        
        spans.add(TextSpan(
          text: char,
          style: TextStyle(
            fontSize: 14,
            color: isChanged ? Colors.green : null,
            fontWeight: isChanged ? FontWeight.bold : null,
          ),
        ));
      }
      
      return RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          children: spans,
        ),
      );
    } else {
      final spans = <InlineSpan>[];
      final displayWords = displayTitle.split(' ');
      final originalWords = originalTitle.split(' ');
      
      for (int i = 0; i < displayWords.length; i++) {
        final displayWord = displayWords[i];
        final originalWord = i < originalWords.length ? originalWords[i] : '';
        
        if (i > 0) {
          spans.add(const TextSpan(text: ' '));
        }
        
        if (displayWord == originalWord) {
          spans.add(TextSpan(
            text: displayWord,
            style: const TextStyle(fontSize: 14),
          ));
        } else {
          spans.add(TextSpan(
            text: displayWord,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.green.withValues(alpha: 0.2),
            ),
          ));
        }
      }
      
      return RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          children: spans,
        ),
      );
    }
  }
  
  Widget _buildConfigPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Audiobook Metadata', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _authorController,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: _yearController,
                  decoration: const InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Bitrate:'),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('16 kbps'),
                selected: _bitrate == 16,
                onSelected: (selected) {
                  if (selected) setState(() => _bitrate = 16);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('32 kbps'),
                selected: _bitrate == 32,
                onSelected: (selected) {
                  if (selected) setState(() => _bitrate = 32);
                },
              ),
              const SizedBox(width: 24),
              Checkbox(
                value: _removeSilence,
                onChanged: (value) {
                  setState(() => _removeSilence = value ?? false);
                },
              ),
              const Text('Remove Silence'),
              if (_removeSilence) ...[
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _silenceDb,
                  isDense: true,
                  items: [
                    const DropdownMenuItem(
                      value: 26,
                      child: Text('-26 dB: deep cleaning of silence'),
                    ),
                    const DropdownMenuItem(
                      value: 30,
                      child: Text('-30 dB: aggressive removes almost all silence'),
                    ),
                    const DropdownMenuItem(
                      value: 34,
                      child: Text('-34 dB: medium removes quite a bit'),
                    ),
                    const DropdownMenuItem(
                      value: 38,
                      child: Text('-38 dB: [recommended] a tad conservative'),
                    ),
                    const DropdownMenuItem(
                      value: 42,
                      child: Text('-42 dB: quite conservative and just removes a bit'),
                    ),
                    const DropdownMenuItem(
                      value: 46,
                      child: Text('-46 dB: kinda too strict and barely removes stuff'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _silenceDb = value ?? 34);
                  },
                ),
              ],
              const SizedBox(width: 24),
              Checkbox(
                value: _removeHiss,
                onChanged: (value) {
                  setState(() => _removeHiss = value ?? false);
                },
              ),
              const Text('Remove Hiss'),
              if (_files.isNotEmpty) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _generateHissPreview,
                  icon: const Icon(Icons.preview, size: 16),
                  label: const Text('Preview'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          LinearProgressIndicator(value: _progress.isNaN ? 0.0 : _progress.clamp(0.0, 1.0)),
          const SizedBox(height: 8),
          Text(_statusMessage),
        ],
      ),
    );
  }

  void _editAudiobookMetadata() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MetadataEditorScreen(),
      ),
    );
  }
  
  Widget _buildActions() {
  return Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        // Row 1: Main actions
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: 'Hold ⌘ (Mac) or Ctrl (Win/Linux) to select multiple files',
                child: ElevatedButton.icon(
                  onPressed: (_encoding || _extracting) ? null : _pickFiles,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Files'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : _pickFolder,
                icon: const Icon(Icons.folder),
                label: const Text('Add Folder'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _encoding 
                  ? ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _cancelEncoding = true;
                        });
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text('Cancel Encoding'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: (_extracting || _files.isEmpty) ? null : _startEncoding,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Encode Audiobook'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DenoiseScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.cleaning_services),
                          label: const Text('Denoise Audio'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TranslateScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.translate),
                          label: const Text('Translate vtt'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
        
        const SizedBox(height: 16),
                
        // Row 2: Utility actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TranscribeScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.subtitles),
                label: const Text('Transcribe'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RepeatsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.repeat),
                label: const Text('Repeats VTT'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrimAudioScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.cut),
                label: const Text('Trim Audio Beginning/End'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        
        // Row 3: Advanced actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : _extractChapters,
                icon: const Icon(Icons.splitscreen),
                label: const Text('Extract Chapters from opus, m4b, m4a, ogg, mkv'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),

            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_encoding || _extracting) ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MetadataEditorScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Audiobook Metadata'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AnkiConverterScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.school),
                label: const Text('Anki Convert to Audiobook'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        
        if (_extracting) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _extractionStatus,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ),
          ),
        ],
        
        if (_lastEncodedPath != null && _lastEncodingTime != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildEncodingSummary(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _shortenPath(_lastEncodedPath!),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildEncodingSummary() {
    final parts = <String>['Encoding took $_lastEncodingTime'];
    
    if (_lastOriginalDuration != null && _lastFinalDuration != null) {
      final difference = _lastOriginalDuration! - _lastFinalDuration!;
      
      if (difference.inSeconds > 0) {
        parts.add('Duration ${_formatDuration(_lastFinalDuration!)}');
        parts.add('Reduced by ${_formatDuration(difference)} (silence removed or badly encoded originals)');
      } else {
        parts.add('Duration ${_formatDuration(_lastFinalDuration!)}');
      }
    }
    
    return Text(
      'Audiobook: ${parts.join(', ')}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
  
  Widget _buildPasteListPanel() {
    final canPreview = _parsedNames.length == _files.length;
    final countMatch = _parsedNames.length == _files.length;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.list, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Paste List to Rename Files',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _showPasteList = false;
                    _isPreviewingPastedList = false;
                  });
                },
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick load buttons
          Row(
            children: [
              const Text('Quick Load: ', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _loadPredefinedList(_surahList),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Surahs'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _loadPredefinedList(_surahArabicList),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Surahs Arabic'),
              ),
              const SizedBox(width: 16),
              if (_lastPastedList.isNotEmpty) ...[
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _pasteListController.text = _lastPastedList;
                      _parseList();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Last List'),
                ),
              ],
              if (_secondLastPastedList.isNotEmpty) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _pasteListController.text = _secondLastPastedList;
                      _parseList();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('2nd Last List'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _pasteListController,
            decoration: InputDecoration(
              labelText: 'Paste your list here (one name per line, without file extensions)',
              labelStyle: const TextStyle(color: Colors.white70),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.black26,
              hintText: 'e.g.:\n001 Al-Fatiha (The opener)\n002 Al-Baqarah (The cow)\n...',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            style: const TextStyle(color: Colors.white),
            maxLines: 8,
            onChanged: (_) {
              _parseList();
              if (_isPreviewingPastedList) {
                setState(() {
                  _isPreviewingPastedList = false;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: countMatch ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: countMatch ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      countMatch ? Icons.check_circle : Icons.error,
                      color: countMatch ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'List: ${_parsedNames.length} lines | Files: ${_files.length}',
                      style: TextStyle(
                        color: countMatch ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: canPreview ? () {
                  setState(() {
                    _isPreviewingPastedList = !_isPreviewingPastedList;
                  });
                } : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: _isPreviewingPastedList ? Colors.orange : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(_isPreviewingPastedList ? 'Hide Preview' : 'Show Preview'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: canPreview ? _applyPastedList : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
          
          if (!countMatch && _parsedNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Count mismatch! Adjust your list to have exactly ${_files.length} lines.',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Preview area
          if (_isPreviewingPastedList && countMatch) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.preview, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Preview: Current → New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final currentTitle = file.editedTitle.isNotEmpty 
                      ? file.editedTitle 
                      : (_useFilenames ? _getFilenameWithoutExt(file.path) : file.originalTitle);
                  final newTitle = _parsedNames[index];
                  final ext = path.extension(file.path);
                  final isDifferent = currentTitle != newTitle;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${index + 1}.',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Current: ',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      currentTitle + ext,
                                      style: TextStyle(
                                        color: isDifferent ? Colors.red.shade300 : Colors.white70,
                                        fontSize: 12,
                                        decoration: isDifferent ? TextDecoration.lineThrough : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'New:     ',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      newTitle + ext,
                                      style: TextStyle(
                                        color: isDifferent ? Colors.green.shade300 : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isDifferent ? FontWeight.bold : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isDifferent)
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.green,
                            size: 16,
                          )
                        else
                          const Icon(
                            Icons.check,
                            color: Colors.white38,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HelpExample {
  final String pattern;
  final String description;
  
  _HelpExample(this.pattern, this.description);
}

class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final _queue = <Completer<void>>[];
  
  _Semaphore(this.maxCount);
  
  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    
    final completer = Completer<void>();
    _queue.add(completer);
    return completer.future;
  }
  
  void release() {
    _currentCount--;
    if (_queue.isNotEmpty) {
      final completer = _queue.removeAt(0);
      _currentCount++;
      completer.complete();
    }
  }
}