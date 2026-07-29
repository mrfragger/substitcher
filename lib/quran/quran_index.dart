import 'quran_index_Afar.dart';
import 'quran_index_Albanian.dart';
import 'quran_index_Amharic.dart';
import 'quran_index_Arabic.dart';
import 'quran_index_AsanteTwi.dart';
import 'quran_index_Assamese.dart';
import 'quran_index_Azerbaijani.dart';
import 'quran_index_Belarusian.dart';
import 'quran_index_Bengali.dart';
import 'quran_index_Bosnian.dart';
import 'quran_index_Bulgarian.dart';
import 'quran_index_Burmese.dart';
import 'quran_index_Cebuano.dart';
import 'quran_index_Chichewa.dart';
import 'quran_index_Chinese.dart';
import 'quran_index_ChineseTrad.dart';
import 'quran_index_Circassian.dart';
import 'quran_index_Croatian.dart';
import 'quran_index_Czech.dart';
import 'quran_index_Danish.dart';
import 'quran_index_Dari.dart';
import 'quran_index_Dagbani.dart';
import 'quran_index_Dutch.dart';
import 'quran_index_Finnish.dart';
import 'quran_index_French.dart';
import 'quran_index_Fula.dart';
import 'quran_index_Georgian.dart';
import 'quran_index_German.dart';
import 'quran_index_Greek.dart';
import 'quran_index_Gujarati.dart';
import 'quran_index_Hausa.dart';
import 'quran_index_Hebrew.dart';
import 'quran_index_Hindi.dart';
import 'quran_index_Hungarian.dart';
import 'quran_index_Indonesian.dart';
import 'quran_index_Iranun.dart';
import 'quran_index_Italian.dart';
import 'quran_index_Japanese.dart';
import 'quran_index_Kannada.dart';
import 'quran_index_Kazakh.dart';
import 'quran_index_Khmer.dart';
import 'quran_index_Kinyarwanda.dart';
import 'quran_index_Kirundi.dart';
import 'quran_index_Korean.dart';
import 'quran_index_Kurdish.dart';
import 'quran_index_Kyrgyz.dart';
import 'quran_index_Lingala.dart';
import 'quran_index_Lithuanian.dart';
import 'quran_index_Luhya.dart';
import 'quran_index_Luganda.dart';
import 'quran_index_Macedonian.dart';
import 'quran_index_Maguindanaon.dart';
import 'quran_index_Malagasy.dart';
import 'quran_index_Malay.dart';
import 'quran_index_Malayalam.dart';
import 'quran_index_Marathi.dart';
import 'quran_index_Moore.dart';
import 'quran_index_Mongolian.dart';
import 'quran_index_Nepali.dart';
import 'quran_index_Norwegian.dart';
import 'quran_index_Odia.dart';
import 'quran_index_Oromo.dart';
import 'quran_index_Pashto.dart';
import 'quran_index_Persian.dart';
import 'quran_index_Polish.dart';
import 'quran_index_Portuguese.dart';
import 'quran_index_Punjabi.dart';
import 'quran_index_Romanian.dart';
import 'quran_index_Russian.dart';
import 'quran_index_Serbian.dart';
import 'quran_index_Shona.dart';
import 'quran_index_Sinhalese.dart';
import 'quran_index_Slovak.dart';
import 'quran_index_Somali.dart';
import 'quran_index_Spanish.dart';
import 'quran_index_Swahili.dart';
import 'quran_index_Swedish.dart';
import 'quran_index_Tagalog.dart';
import 'quran_index_Tajik.dart';
import 'quran_index_Tamil.dart';
import 'quran_index_Telugu.dart';
import 'quran_index_Thai.dart';
import 'quran_index_Turkish.dart';
import 'quran_index_Ukrainian.dart';
import 'quran_index_Urdu.dart';
import 'quran_index_Uyghur.dart';
import 'quran_index_Uzbek.dart';
import 'quran_index_Vietnamese.dart';
import 'quran_index_Yao.dart';
import 'quran_index_Yoruba.dart';
import 'quran_index_Xhosa.dart';
import 'quran_index_Zulu.dart';

/// Verse counts per surah (1-indexed, index 0 is unused)
const List<int> quranVerseCounts = [
  0, // placeholder for index 0
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, // 1-10
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135, // 11-20
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, // 21-30
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85, // 31-40
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, // 41-50
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13, // 51-60
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, // 61-70
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42, // 71-80
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, // 81-90
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11, // 91-100
  11, 8, 4, 5, 7, 3, 6, 3, 5, 4, // 101-110
  5, 4, 5, 6, // 111-114
];

const Map<String, List<int>> quranFileRanges = {
  '001-006': [1, 2, 3, 4, 5, 6],
  '007-015': [7, 8, 9, 10, 11, 12, 13, 14, 15],
  '016-024': [16, 17, 18, 19, 20, 21, 22, 23, 24],
  '025-036': [25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36],
  '037-049': [37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49],
  '050-069': [
    50,
    51,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    62,
    63,
    64,
    65,
    66,
    67,
    68,
    69
  ],
  '070-114': [
    70,
    71,
    72,
    73,
    74,
    75,
    76,
    77,
    78,
    79,
    80,
    81,
    82,
    83,
    84,
    85,
    86,
    87,
    88,
    89,
    90,
    91,
    92,
    93,
    94,
    95,
    96,
    97,
    98,
    99,
    100,
    101,
    102,
    103,
    104,
    105,
    106,
    107,
    108,
    109,
    110,
    111,
    112,
    113,
    114
  ],
};

String? getRangeKeyForSurah(int surah) {
  for (final entry in quranFileRanges.entries) {
    if (entry.value.contains(surah)) return entry.key;
  }
  return null;
}

class QuranVerseRef {
  final int surah;
  final int fromAyah;
  final int? toAyah;
  final bool isFullSurah;

  const QuranVerseRef({
    required this.surah,
    required this.fromAyah,
    this.toAyah,
    this.isFullSurah = false,
  });

  int get endAyah => toAyah ?? fromAyah;

  String get chapterIdStart =>
      '${surah.toString().padLeft(3, '0')}${fromAyah.toString().padLeft(3, '0')}';

  String get chapterIdEnd =>
      '${surah.toString().padLeft(3, '0')}${endAyah.toString().padLeft(3, '0')}';

  String get displayLabel {
    if (isFullSurah) return 'S.$surah';
    if (toAyah != null && toAyah != fromAyah) return '$surah:$fromAyah-$toAyah';
    return '$surah:$fromAyah';
  }
}

class QuranIndexEntry {
  final String topic;
  final List<QuranVerseRef> refs;
  final bool isSubtopic;
  final String? parentTopic;

  const QuranIndexEntry({
    required this.topic,
    required this.refs,
    this.isSubtopic = false,
    this.parentTopic,
  });
}

const Set<String> rtlQuranIndexLanguages = {
  'Arabic',
  'Dari',
  'Dhivehi *',
  'Hebrew',
  'Kurdish',
  'Nko',
  'Pashto',
  'Persian',
  'Urdu',
  'Uyghur',
};

bool isRtlQuranLanguage(String language) =>
    rtlQuranIndexLanguages.contains(language);

List<QuranIndexEntry> parseQuranIndex(String raw) {
  final normalized = raw
      .replaceAll('；', ';')
      .replaceAll('：', ':')
      .replaceAll('，', ',')
      .replaceAll('。', '.')
      .replaceAll('、', ',');
  final entries = <QuranIndexEntry>[];
  final lines = raw.split('\n');
  final blocks = <String>[];
  final buffer = StringBuffer();

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final startsNewBlock =
        (RegExp(r"^[A-Za-z'\u2018\u2019\-]").hasMatch(trimmed) ||
                RegExp(r'^\p{L}', unicode: true).hasMatch(trimmed)) &&
            !RegExp(r'^[\d,;]').hasMatch(trimmed) &&
            !trimmed.startsWith('- ') &&
            !trimmed.startsWith('-');

    if (startsNewBlock && buffer.isNotEmpty) {
      blocks.add(buffer.toString().trim());
      buffer.clear();
    }
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(trimmed);
  }
  if (buffer.isNotEmpty) blocks.add(buffer.toString().trim());

  String? currentMainTopic;

  for (final block in blocks) {
    final lines = block.split('\n');

    final mainEntry = _parseBlock(lines.first);
    if (mainEntry == null) continue;

    currentMainTopic = mainEntry.topic;
    entries.add(QuranIndexEntry(
      topic: mainEntry.topic,
      refs: mainEntry.refs,
      isSubtopic: false,
    ));

    for (int i = 1; i < lines.length; i++) {
      final subLine = lines[i].trim();
      if (subLine.startsWith('- ') || subLine.startsWith('-')) {
        final cleaned = subLine.replaceFirst(RegExp(r'^-\s*'), '');
        final refStart = RegExp(r'(\d+:\d+|S\.\d+)').firstMatch(cleaned);

        String subTopic;
        List<QuranVerseRef> subRefs;

        if (refStart == null) {
          subTopic = cleaned.replaceAll(RegExp(r'[,;]+$'), '');
          subRefs = [];
        } else {
          subTopic = cleaned
              .substring(0, refStart.start)
              .trim()
              .replaceAll(RegExp(r'[,;]+$'), '');
          subRefs = _parseRefs(cleaned.substring(refStart.start));
        }

        if (subTopic.isNotEmpty) {
          entries.add(QuranIndexEntry(
            topic: subTopic,
            refs: subRefs,
            isSubtopic: true,
            parentTopic: currentMainTopic,
          ));
        }
      }
    }
  }
  return entries;
}

bool _isSubtopicBlock(String block) {
  final trimmed = block.trim();
  return RegExp(r'^[a-z]').hasMatch(trimmed) ||
      trimmed.startsWith('- ') ||
      trimmed.startsWith('-');
}

QuranIndexEntry? _parseBlock(String block) {
  final lines = block.split('\n');
  final mainLine = lines.first.trim();

  final trimmed = mainLine;
  final cleanBlock = trimmed;

  final refStart = RegExp(r'(\d+:\d+|S\.\d+)').firstMatch(cleanBlock);

  String topic;
  List<QuranVerseRef> refs;

  if (refStart == null) {
    topic = cleanBlock.replaceAll(RegExp(r'[,;]+$'), '');
    if (topic.isEmpty) return null;
    refs = [];
  } else {
    topic = cleanBlock
        .substring(0, refStart.start)
        .trim()
        .replaceAll(RegExp(r'[,;]+$'), '');
    refs = _parseRefs(cleanBlock.substring(refStart.start));
  }

  return QuranIndexEntry(
    topic: topic,
    refs: refs,
    isSubtopic: false,
  );
}

List<QuranVerseRef> _parseRefs(String text) {
  final refs = <QuranVerseRef>[];
  final text2 =
      text.replaceAll('；', ';').replaceAll('：', ':').replaceAll('，', ',');

  final normalized = text.replaceAllMapped(
    RegExp(r'S\.(\d+)'),
    (m) => '__SURAH__${m[1]}__',
  );

  final surahGroups = normalized.split(';');

  int? currentSurah;

  for (final group in surahGroups) {
    final trimmed = group.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.contains('__SURAH__')) {
      final match = RegExp(r'__SURAH__(\d+)__').firstMatch(trimmed);
      if (match != null) {
        refs.add(QuranVerseRef(
          surah: int.parse(match[1]!),
          fromAyah: 1,
          toAyah: null,
          isFullSurah: true,
        ));
      }
      continue;
    }

    final surahAyahMatch = RegExp(r'^(\d+):(.+)$').firstMatch(trimmed);
    if (surahAyahMatch != null) {
      currentSurah = int.tryParse(surahAyahMatch[1]!);
      final ayahPart = surahAyahMatch[2]!;
      _parseAyahList(currentSurah!, ayahPart, refs);
    } else if (currentSurah != null) {
      if (RegExp(r'^\d').hasMatch(trimmed)) {
        _parseAyahList(currentSurah, trimmed, refs);
      }
    }
  }

  return refs;
}

void _parseAyahList(int surah, String ayahText, List<QuranVerseRef> refs) {
  final parts = ayahText.split(',');
  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final cleaned = trimmed
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll(RegExp(r'[^\d\-]'), '');
    if (cleaned.isEmpty) continue;

    if (cleaned.contains('-')) {
      final rangeParts = cleaned.split('-');
      final from = int.tryParse(rangeParts[0]);
      final to = int.tryParse(rangeParts[1]);
      if (from != null &&
          to != null &&
          surah <= 114 &&
          from <= (quranVerseCounts[surah])) {
        refs.add(QuranVerseRef(surah: surah, fromAyah: from, toAyah: to));
      }
    } else {
      final ayah = int.tryParse(cleaned);
      if (ayah != null && surah <= 114 && ayah <= (quranVerseCounts[surah])) {
        refs.add(QuranVerseRef(surah: surah, fromAyah: ayah));
      }
    }
  }
}

const List<String> availableQuranIndexLanguages = [
  'English', // always first
  'Afar',
  'Albanian',
  'Amharic',
  'Arabic',
  'AsanteTwi',
  'Assamese',
  'Azerbaijani',
  'Belarusian',
  'Bengali',
  'Bosnian',
  'Bulgarian',
  'Burmese *',
  'Cebuano',
  'Chichewa',
  'Chinese',
  'ChineseTrad *',
  'Circassian *',
  'Croatian',
  'Czech *',
  'Dagbani',
  'Danish *',
  'Dari',
  'Dutch',
  'Finnish *',
  'French',
  'Fula',
  'Georgian *',
  'German',
  'Greek',
  'Gujarati',
  'Hausa',
  'Hebrew',
  'Hindi',
  'Hungarian *',
  'Indonesian',
  'Iranun',
  'Italian',
  'Japanese',
  'Kannada',
  'Kazakh',
  'Khmer',
  'Kinyarwanda',
  'Kirundi',
  'Korean',
  'Kurdish',
  'Kyrgyz',
  'Lingala',
  'Lithuanian',
  'Luganda',
  'Luhya',
  'Macedonian',
  'Maguindanaon',
  'Malagasy',
  'Malay',
  'Malayalam',
  'Marathi',
  'Moore',
  'Mongolian *',
  'Nepali *',
  'Norwegian *',
  'Odia *',
  'Oromo',
  'Pashto',
  'Persian',
  'Polish *',
  'Portuguese',
  'Punjabi',
  'Romanian',
  'Russian',
  'Serbian',
  'Shona *',
  'Sinhalese',
  'Slovak *',
  'Somali',
  'Spanish',
  'Swahili',
  'Swedish',
  'Tagalog',
  'Tajik',
  'Tamil',
  'Telugu',
  'Thai',
  'Turkish',
  'Ukrainian',
  'Urdu',
  'Uyghur',
  'Uzbek',
  'Vietnamese',
  'Xhosa *',
  'Yao',
  'Yoruba',
  'Zulu *',
];

String getQuranIndexRaw(String language) {
  switch (language) {
    case 'Afar':
      return quranIndexAfarRaw;
    case 'Albanian':
      return quranIndexAlbanianRaw;
    case 'Amharic':
      return quranIndexAmharicRaw;
    case 'Arabic':
      return quranIndexArabicRaw;
    case 'AsanteTwi':
      return quranIndexAsanteTwiRaw;
    case 'Assamese':
      return quranIndexAssameseRaw;
    case 'Azerbaijani':
      return quranIndexAzerbaijaniRaw;
    case 'Belarusian':
      return quranIndexBelarusianRaw;
    case 'Bengali':
      return quranIndexBengaliRaw;
    case 'Bosnian':
      return quranIndexBosnianRaw;
    case 'Bulgarian':
      return quranIndexBulgarianRaw;
    case 'Burmese *':
      return quranIndexBurmeseRaw;
    case 'Cebuano':
      return quranIndexCebuanoRaw;
    case 'Chichewa':
      return quranIndexChichewaRaw;
    case 'Chinese':
      return quranIndexChineseRaw;
    case 'ChineseTrad *':
      return quranIndexChineseTradRaw;
    case 'Circassian *':
      return quranIndexCircassianRaw;
    case 'Croatian':
      return quranIndexCroatianRaw;
    case 'Czech *':
      return quranIndexCzechRaw;
    case 'Dagbani':
      return quranIndexDagbaniRaw;
    case 'Danish *':
      return quranIndexDanishRaw;
    case 'Dari':
      return quranIndexDariRaw;
    case 'Dutch':
      return quranIndexDutchRaw;
    case 'Finnish *':
      return quranIndexFinnishRaw;
    case 'French':
      return quranIndexFrenchRaw;
    case 'Fula':
      return quranIndexFulaRaw;
    case 'Georgian *':
      return quranIndexGeorgianRaw;
    case 'German':
      return quranIndexGermanRaw;
    case 'Greek':
      return quranIndexGreekRaw;
    case 'Gujarati':
      return quranIndexGujaratiRaw;
    case 'Hausa':
      return quranIndexHausaRaw;
    case 'Hebrew':
      return quranIndexHebrewRaw;
    case 'Hindi':
      return quranIndexHindiRaw;
    case 'Hungarian *':
      return quranIndexHungarianRaw;
    case 'Indonesian':
      return quranIndexIndonesianRaw;
    case 'Iranun':
      return quranIndexIranunRaw;
    case 'Italian':
      return quranIndexItalianRaw;
    case 'Japanese':
      return quranIndexJapaneseRaw;
    case 'Kannada':
      return quranIndexKannadaRaw;
    case 'Kazakh':
      return quranIndexKazakhRaw;
    case 'Khmer':
      return quranIndexKhmerRaw;
    case 'Kinyarwanda':
      return quranIndexKinyarwandaRaw;
    case 'Kirundi':
      return quranIndexKirundiRaw;
    case 'Korean':
      return quranIndexKoreanRaw;
    case 'Kurdish':
      return quranIndexKurdishRaw;
    case 'Kyrgyz':
      return quranIndexKyrgyzRaw;
    case 'Lingala':
      return quranIndexLingalaRaw;
    case 'Lithuanian':
      return quranIndexLithuanianRaw;
    case 'Luganda':
      return quranIndexLugandaRaw;
    case 'Luhya':
      return quranIndexLuhyaRaw;
    case 'Macedonian':
      return quranIndexMacedonianRaw;
    case 'Maguindanaon':
      return quranIndexMaguindanaonRaw;
    case 'Malagasy':
      return quranIndexMalagasyRaw;
    case 'Malay':
      return quranIndexMalayRaw;
    case 'Malayalam':
      return quranIndexMalayalamRaw;
    case 'Marathi':
      return quranIndexMarathiRaw;
    case 'Moore':
      return quranIndexMooreRaw;
    case 'Mongolian *':
      return quranIndexMongolianRaw;
    case 'Nepali *':
      return quranIndexNepaliRaw;
    case 'Norwegian *':
      return quranIndexNorwegianRaw;
    case 'Odia *':
      return quranIndexOdiaRaw;
    case 'Oromo':
      return quranIndexOromoRaw;
    case 'Pashto':
      return quranIndexPashtoRaw;
    case 'Persian':
      return quranIndexPersianRaw;
    case 'Polish *':
      return quranIndexPolishRaw;
    case 'Portuguese':
      return quranIndexPortugueseRaw;
    case 'Punjabi':
      return quranIndexPunjabiRaw;
    case 'Romanian':
      return quranIndexRomanianRaw;
    case 'Russian':
      return quranIndexRussianRaw;
    case 'Serbian':
      return quranIndexSerbianRaw;
    case 'Shona *':
      return quranIndexShonaRaw;
    case 'Sinhalese':
      return quranIndexSinhaleseRaw;
    case 'Slovak *':
      return quranIndexSlovakRaw;
    case 'Somali':
      return quranIndexSomaliRaw;
    case 'Spanish':
      return quranIndexSpanishRaw;
    case 'Swahili':
      return quranIndexSwahiliRaw;
    case 'Swedish':
      return quranIndexSwedishRaw;
    case 'Tagalog':
      return quranIndexTagalogRaw;
    case 'Tajik':
      return quranIndexTajikRaw;
    case 'Tamil':
      return quranIndexTamilRaw;
    case 'Telugu':
      return quranIndexTeluguRaw;
    case 'Thai':
      return quranIndexThaiRaw;
    case 'Turkish':
      return quranIndexTurkishRaw;
    case 'Ukrainian':
      return quranIndexUkrainianRaw;
    case 'Urdu':
      return quranIndexUrduRaw;
    case 'Uyghur':
      return quranIndexUyghurRaw;
    case 'Uzbek':
      return quranIndexUzbekRaw;
    case 'Vietnamese':
      return quranIndexVietnameseRaw;
    case 'Xhosa *':
      return quranIndexXhosaRaw;
    case 'Yao':
      return quranIndexYaoRaw;
    case 'Yoruba':
      return quranIndexYorubaRaw;
    case 'Zulu *':
      return quranIndexZuluRaw;
    default:
      return quranIndexRaw;
  }
}

const String quranIndexRaw = r"""
Manzil Prayers (dua) 1:1-7; 2:1-5, 163, 255-257, 284-286; 3:18, 26-27; 7:54-56, 117-122; 17:110-111; 23:115-118; 37:1-11; 55:33-40; 59:21-24; 72:1-4; 109:1-6; 112:1-4; 113:1-5; 114:1-6
Our Lord Prayers (Rabbana dua)  2:127-128, 201, 250, 286; 3:8-9, 16, 53, 147, 191-194; 5:83, 114; 7:23, 47, 89, 126, 155; 10:85-88; 11:47; 12:101; 14:38-41; 17:80; 18:10; 20:114; 23:109, 118; 25:65-66, 74; 28:24; 40:7-9; 59:10; 60:4-7; 66:8
My Lord Prayers (Rabbi dua) 3:38; 12:33; 14:35-36; 19:3-6; 20:25-28, 45, 114; 21:83, 87, 89; 23:26, 29, 93-94, 97-98; 26:83-87, 169; 27:19; 28:16-17, 21; 29:30; 37:100; 38:35, 41; 46:15, 71:26-28
Aaron (Harun) 2:248; 4:163; 6:84; 7:122, 142; 10:75; 19:28, 53; 20:30, 70, 90, 92; 21:48; 23:45; 25:35; 26:13, 48; 28:34; 37:114, 120
'Abasa, S.80; 74:22
Ablutions (Wudu), 4:43; 5:6
Abraham (Ibrahim) S.14; 2:135-136, 148; 3:33, 84, 95; 4:54, 125, 163; 6:161; 9:70, 114; 12:6, 38; 16:120; 19:58; 21:51, 60, 62, 69; 22:43, 78; 26:69; 29:31; 33:7; 37:83, 104, 109; 38:45; 42:13; 43:26; 51:24; 53:37; 57:26; 60:4; 87:19
- neither Jew nor Christian, 3:67-68
- stood in first temple at Bakkah, 3:97; 26:123
- raises the foundations of the Ka'bah 2:124-129
- calls his people to the worship of the One True God 2:130-133; 26:69-89; 29:16; 29:24-27
- debates arrogant king 2:258
- inquires about resurrection 2:260
- neither Jew nor Christian 3:65-68
- refutes celestial worship 6:74-87
- receives news of the birth of Isaac 11:69-76; 51:24-30
- his prayer at the Ka'bah 14:35-41
- visited by angels 15:51-56
- a role model 16:123
- calls his father to the truth 19:41-50
- destroys idols and is saved from the fire 21:51-73; 37:83-113
- calls all to the pilgrimage 22:26
Abrar, 3:193, 198; 76:5; 82:13; 83:18-22
Abrogation, 2:106, 16:101
Abu Lahab, 111:1-5
'Ad people, 7:65-74; 9:70; 11:59; 14:9; 22:42; 25:38; 26:123; 29:38; 38:12; 40:31; 41:13, 15; 46:21; 50:13; 51:41; 53:50; 54:18; 69:4-6; 89:6
Adam, 3:33, 59; 5:27; 7:26-27, 31, 35, 172; 17:70; 19:58; 36:60
- angels to prostrate before, 2:34; 7:11
- tree of knowledge, 2:35; 7:19-20; 20:120-121
- banishment from Garden (no blame on Eve), 2:36; 7:24
- honoured by Allah, tempted by Satan 2:30-38; 7:11-25; 17:61-65; 18:50; 20:115-123; 38:71-85
- forgiven by Allah 2:37; 20:122
'Adiyat, S.100
'Adn Paradise, 9:72; 13:23; 16:31; 18:31; 19:61; 20:76; 35:33; 38:50; 40:8; 61:12; 98:8
Adversity
- not burdened with another's burden, 6:164; 17:15; 35:18; 39:7; 53:38
- not burdened beyond capability to withstand, 2:286; 6:152; 7:42; 23:62
- patience during, 2:153; 2:155; 2:177; 2:250; 3:17; 3:125; 3:142; 3:146; 3:186; 3:200; 7:87; 7:126; 7:128; 7:137; 8:46; 8:65; 8:66; 10:109; 11:11; 11:49; 11:115; 12:18; 12:83; 12:90;13:22; 16:96; 16:110; 16:126; 21:85; 22:35; 23:111; 28:54; 29:59; 30:60; 31:17; 31:31;37:102; 38:44; 39:10; 40:55; 40:77; 41:35; 42:33; 46:35; 47:31; 70:5; 76:12; 90:17; 103:3
Aging, 16:70; 22:5; 30:54; 36:68
- behavior towards aging parents in your care, 17:23
Ahmad, 61:6
Ahqaf, S.46; 46:21
Ahzab, S.33; 11:17; 13:36; 19:37; 38:11, 13;40:5, 30; 43:65
Aikah, dwellers of, 15:78; 26:176; 38:13; 50:14
A'la S.87; 87:1; 92:20
'Alaq, S.96
Al-Imran, S.3
Allah
- a day for Him is fifty thousand years, 70:4
- a day for Him is a thousand human years, 22:47; 32:5
- ability to do anything, 2:106; 2:117; 3:165; 3:189; 8:41; 9:116; 11:4; 16:40; 40:68; 41:39;42:49; 57:2
- best of all judges, 95:8
- beyond definition, 43:82; 67:12
- brings disbelievers schemes to nought, 8:30; 8:36
- cause human beings to disappear and bring forth other beings, 4:133; 14:19; 35:16
- causes laughter and crying, 53:43
- caused a man to sleep for a century, 2:259
- enemy of those who deny the truth, 2:98
- extol his glory from morning until night, 33:42
- false daughters of, 16:57; 17:40; 43:16; 52:39; 53:21-22
- by name, 53:19-20
- gives humans free will, 36:67
- giving it all up for him, 4:66-68; 4:125
- good and evil are from Him, 4:78
- grants life and death, 44:8; 53:44; 57:2; 67:2
- hard strivers rewarded better, 4:95-96; 5:54; 9:120; 49:15; 61:11
- has no consort, 72:3
- has no son, 43:81; 72:3; 112:3
- has not forsaken you during your hard times, 93:3
- is everywhere in knowledge, 2:115; 2:142; 2:177; 4:126
- is the First and the Last (alpha and omega), 57:3
- is the Outward and Inward, 57:3
- knows that beyond comprehension, 6:59; 6:73; 9:94; 9:105; 13:9; 32:6; 34:48; 35:38-39:46;49:18; 59:22; 62:8; 64:18; 72:26; 74:31; 87:7
- loves those who behave equitably, 49:9
- made no laws regarding that of which He didn't speak, 5:101; 6:140; 6:148; 7:32
- mercy towards prisoners of war who have good in them, 8:70
- nature of, 2:255
- no human is a divinity, 3:64; 3:151
- not a trinity, 4:171
- refuge from evil with, 113:1-5; 114:1-6
- remembering him standing, sitting, lying down, 3:191; 4:103; 10:12; 25:64
- shapes you in the womb, 3:6
- throne rests upon the water, 11:7
- will create things of which you have no knowledge, 16:8
- wills no wrong to His creation, 3:108; 4:40; 17:71; 21:47; 22:10; 26:209; 40:31; 41:46;45:22; 50:29; 64:11
Alliances, 8:72; 9:7
- Christians and Jews, 5:51
- forbidden with disbelieving kin, 9:23-24
- forbidden with hypocrites, 4:88-89; 4:139; 4:144
Alyasa', (see Elisha)
Amanah, Trust and Allah prescribed duties etc., 2:283; 4:58; 8:27
- see Trust
Angels, 2:30-34; 2:98; 2:285; 4:97; 8:50; 13:23; 21:108; 22:75; 25:22; 25:25; 32:11; 33:43; 33:56;34:40; 35:1; 37:150; 38:71; 39:75; 41:14; 41:30; 42:5; 43:53; 43:60; 47:27; 53:26; 66:4; 66:6;69:17; 70:4; 89:22; 97:4
- created from fire, 7:12; 38:76
- eight will bear Allah's throne aloft on Judgement Day, 69:17
- false claim that they are female, 43:19; 53:27
- guardian 82:10-12; 86:4
- nineteen lord over hell, 74:30-31
- not sent to satisfy whims, 15:7-8
- sent to inspire, 16:2
Anger, withhold, 3:134
'Ankabut, S.29
Ants, 27:18
Apes, 5:60
- despicable, 2:65; 7:166
Apostacy, 3:72; 3:86-88; 3:90-91; 3:167; 4:137; 5:54; 9:74; 9:107; 16:106; 33:14
- do not ask for speedy doom for apostates, 46:35
- Allah alone will punish them, 73:11; 74:11
- punishment in the hereafter, 2:217; 9:74
- rejection by others, 3:87
- repentence, 3:89; 5:34; 9:5; 9:11
- on Judgement Day is too late, 40:85
- under duress, 16:106
Apostates,47:25
A'raf, S.7; 7:46, 48
Arafat, 2:198
Argue
- not on behalf of those who deceive themselves, 4:107
- you argued for them in this world, but who will on the Day of Resurrection, 4:109
Arguments/Attacks
- respond in kind, 8:58
- being patient is far better, 16:126
Armor, 16:81
'Asr,S.103
Ayat Al-Kursi, 2:255
Backbiter, 49:12; 104:1
Badr (battle of), 3:13
- lessons from, 8:5-19, 42-48
Al-Bait-ul-Ma mur, 52:4
Bakkah (Makkah), 3:96
B'al, 37:125
Balad, S.90
Balance, 7:8-9; 17:35; 21:47; 55:7-9; 57:25;101:6-9
Banu An-Nadir, 59:2-6, 13
Baqarah, S.2
Bara'a (See Taubah), S.9
Barzakh,(Barrier), 23:100; 25:53; 55:20
- also see 18:94-97; 34:54; 36:9
Baiyinah, S.98
Beast (of the Last Days), 27:82
Bedouins, 9:90, 97-99, 101, 120; 48:11, 16; 49:14
Bee, 16:68-69
Behavior
- argue in a kindly manner with those given earlier revelation, 16:125, 29:46
- avoid becoming involved in matters you know nothing of, 17:36
- avoid grave sins and shameful deeds, 53:32
- avoid guesswork about one another, don't spy on nor speak ill about each other 49:12
- be just in your opinions, 6:152
- community should be moderate, 2:143; 25:67
- conceit discouraged, 4:36, 57:23
- don't chide those who seek your help, 93:10
- don't consider yourself pure, 53:32
- don't deride others, 49:11; 104:1
- don't mention evil things openly, 4:148
- don't speak ill of each other, 104:1
- each group given a law and way of life, 2:148; 5:48; 10:47; 10:74; 13:38; 16:36; 16:63;16:84
- and a way of worship, 22:67
- Allah could have made them one community, 5:48; 11:118; 16:93; 42:8
- one community under Allah, 21:92
- forgive Jews, 5:13
- forgive non-believers, 31:15; 45:14
- forgive readily, 42:37
- rulers make decisions after consultations, 42:38
- and a prophet, 10:47; 16:36
- maligning believers is sinful, 33:58
- men (toward women), 24:30
- peacemakers rewarded, 42:40
- speak justly toward those in want, if you can do nothing else, 17:28
- towards aging parents in your care, 17:23
- towards other Muslims, 33:6
- towards others, 17:26-29; 17:35; 17:53; 60:8
- towards parents, 46:15
- towards slaves, 4:36; 24:33
- treat non-belligerent non-believers with equity, 60:8
- wives of the Prophet, 33:28-34
- women (toward men), 24:31
- in all revelations, 2:136; 2:285
- nature of, 49:14-15
Believers, 2:2-5; 2:285; 8:2-4; 8:24
Bequest, 2:180, 240; 4:7, 12; 36:50
Betray (deceive, fraud), 2:187; 4:107; 5:13;8:27, 58, 71; 12:52; 22:38; 66:10
Bible, 5:64, 5:65, 5:68
- distortion of, 3:78; 5:14-15
Birds, 2:260; 3:49; 5:110; 6:38; 12:36, 41; 16:79; 21:79; 22:31; 24:41; 27:16-17, 20; 34:10; 38:19; 56:21; 67:19; 105:3
Blood-money (Diya), 2:178-179; 4:92; 17:33
Booty, war, 4:94. 8:41; 59:6-8
- taking illegally, 3:162
- see spoils
Bribery, 2:188
Budn, 22:36
Burden
- of another, no bearer of burdens shall bear the, 35:18; 39:7; 53:38
- disbelievers will bear also the burdens of others, 16:25; 29:13
- evil indeed are the burdens that they will bear, 6:31, 164
- Allah burdens not a person beyond his scope, 2:286; 7:42; 23:62
Buruj (Big stars), S.85; 85:1; 15:16; 25:61
Camel, 6:144; 7:40; 77:33; 88:17
Captives, 4:25; 8:67, 70, 71; 9:60; 33:26-27; 76:8
- see also Prisoners of war
Cattle, 3:14; 4:119; 5:1; 6:136, 138, 139, 142; 7:179; 10:24; 16:5-8, 10, 66, 80; 20:54; 22:28, 30, 34; 23:21; 25:44, 49; 26:133; 32:27; 35:28; 36:71-73; 39:6; 40:79; 42:11; 43:12-13; 47:12; 79:33; 80:32
Cave of Thawr, 9:40
Cave, people of the 18:9-22, 25-26
Certainty with truth, 56:95; 69:51
Charity, (Sadaqah), 2:196, 263, 264, 270, 271, 273; 4:114; 9:58, 75, 76-79, 103, 104; 57:18;58:12-13
- objects of charity and Zakat, 2:273; 9:60
Children 2:233; 42:49-50
- lost are they who have killed their, from folly, without knowledge, 6:140
Christ, (see Jesus)
Christians, 5:14, 19, 64-65, 69; 22:17
- asked not to deify Jesus, 4:171
- come closest to feeling affection to Muslims, 5:82
- most have forgotten what they've been told to bear in mind, 5:14
- now comes to you a messenger, 5:15, 19
- righteous will be rewarded, 2:62; 5:65; 5:69
- say "Jesus is Allah's son", 9:30
Cities overthrown, 69:9
City of security, 95:3
Clothing, 7:26; 16:81
- of fire, 22:19
- the veil or women's clothing in non-household situations, 24:31
- women's outer garments prevent harassment by hypocrites, 33:59-60
Confederates, 33:9, 22
- see Ahzab Consultation, mutual, 42:38
Creation
- begins and repeated, 10:4; 21:104; 27:64; 29:19-20
- a new, 17:49, 98; 35:16
- with truth, 15:85; 16:3; 29:44; 39:5; 44:39;45:22; 46:3
- not for play, 21:16-17; 23:115
- every living thing made from, 21:30; 24:45;25:54
- of man, 4:1; 6:2; 15:26, 28, 33; 16:4; 21:30;22:5; 23:12-14; 25:54; 32:7-9; 35:11; 36:77-78; 37:11; 39:6; 40:67; 49:13; 55:14; 56:57-59; 75:37-40; 76:1-2; 77:20-23; 80:18-19; 86:5-8; 96:2
- the first form of 56:62
- in six Days, 7:54; 11:7; 32:4; 50:38; 57:4
- in pairs, 13:3; 30:8; 36:36; 42:11; 43:12; 51:9,49; 53:45
- variety in, 35:27-28
- Allah commands "Be!" — and it is, 2:117;16:40; 36:82; 40:68
- as the twinkling of an eye, 54:50
- night and day, sun and moon, 39:5
- of heaven and earth earth greater than, of mankind, 40:57; 79:27
- purpose of, 51:56
Crow, 5:31
Criterion, 2:53, 185; 3:4; 8:29, 41; 21:48; 25:1
Dahr, (see Insan,) S.76; 45:24
- time, 76:1; 103:1
David, 5:78; 6:84; 17:55; 34:10, 13; 38:17-30
- given the Psalms 4:163
- fights and kills Goliath, 2:251
- passes a judgment 21:78-80
- blessed with knowledge and prophethood 27:15-16
- mountains and birds join him in praising Allah 34:10; 38:17-20
- judges between two people 38:21-26
Dawabb or Dabbah (moving living creature, etc.) 2:164; 6:38; 8:22, 55; 11:6, 56; 16:49, 61; 22:18; 24:45; 27:82; 29:60;31:10; 34:14; 35:28, 45; 42:29; 45:4
Dead will be raised up, 6:36
Death, 3:185; 3:193; 4:78; 6:61; 6:93; 21:35; 23:99-108; 31:34; 32:11; 33:19; 33:23; 44:56; 47:27;  50:19-20; 56:60-62; 56:83-96; 75:29; 75:26-35
- and flight from battle, 33:16
- in Allah's cause, 3:195; 22:58; 47:4
- those communities who have no revelation will not be destroyed, 6:131; 9:115; 10:47; 11:117; 15:4; 16:119; 17:15; 28:59
- those slain in Allah's cause are alive, 2:154; 3:169
- while fleeing evil towards Allah, 4:100
- cannot be stopped or delayed 63:10-11
- twin brother of sleep 6:60; 39:42
- believers and disbelievers at the time of death 8:50; 16:27-32; 41:30
- punishment in the grave 40:46
Debts, 2:280, 282; 4:11-12
Decree
- for each and every matter, there is a, 13:38
- never did We destroy a township but there was a known, for it, 15:4
- of every matter is from Allah, 44:5
- when He decrees a matter, He says only,"Be!" — and it is, 2:117; 36:82; 40:68
Deeds
- evil, beautified for them, 47:14
- to us our, to you your deeds, 28:55; 42:15; 45:15
- good and bad, are for and against his ownself, 41:46
- fastened man's, to his own neck, 17:13
Degrees, according to what they did, 6:132
Desire, those follow their evil, 47:14, 16
- who has taken as his god his own, 25:43
Despair not of the Mercy of Allah, 39:53; 21:87-88; 68:48-50
- see also Jonah
Dhariyat, S.51
Dhikr, 7:205; 15:6, 9
Dhul-Kifi, 21:85; 38:48
Dhul-Qarain, 18:83-98
Dhun-Nun (Companion of the Fish)
Disbelievers (see also Hypocrites)
- ask Muhammad ( ﷺ ) to invoke Allah's wrath upon them as proof, 6:57-58; 8:32; 10:49-52
- bear their company in kindness, 31:15
- bear what they say in patience, 20:130; 50:39
- covenants with, 8:56; 8:72; 9:4, 7
- breaking of covenants, 8:58; 9:12
- Allah brings their scheming to nought, 8:30, 36
- leave company of those in the act of mocking Allah's law, 4:140; 6:68
- protect them if they ask you to, 9:6
- punishment during war, 8:12, 50, 59
- punishment in the hereafter, 8:37
- should not visit or take care of mosques, 9:17
- speak kindly to them, 17:53
- striving hard against, 9:73; 25:52; 66:9
- treat non-belligerents with equity, 60:8
- will only ally with other disbelievers, 8:72
Disciples (of Jesus), 3:52; 61:14
Disease in the hearts of hypocrites and disbelievers, 2:10; 5:52; 8:49; 9:125; 22:53; 24:50; 33:12, 32, 60; 47:20, 29; 74:31
Distress, after it there is security, 3:154
Distribution of war-booty, 8:41; 59:7-8
Ditch, people of the, 85:4-10
Diversity
- of humans, 30:22, 35:27-28
- of life, 35:27-28
Divorce, 2:228-232, 236-237, 241; 4:35, 130; 65:1-7
- after waiting period, dissolve or reconcile, 2:231; 65:2
- two witnesses, 65:2
- alimony, 2:233, 241
- extends to ex-husband's heir, 2:233
- can be revoked twice, 2:229
- dowry status, 2:229, 236-237
- find wet-nurse if necessary, 65:6
- see also Zihar
Divorce, Man
- divorce one woman for another - don't take back what you gave first, 4:20
- don't harass wife, 65:6
- don't hold wives against their will, 4:19
- four months to change his mind, 2:226
- support wife fully during her pregnancy and waiting period, 65:6
- support wife fully if she's nursing your child, 65:6
- mother shouldn't suffer because of her fatherless child, 2:233
- pre-Islamic, 58:2
- contrition to reconcile fast for 2 consecutive months, 58:4
- contrition to reconcile feed 60 needy people, 58:4
- contrition to reconcile free a slave, 58:3
- reconciliation attempt, 4:35
- sinless if marriage unconsummated, 2:236
- bride entitled to half of the dowry, 2:237
Divorce, Woman
- after third divorce (this one from another husband) can return to original husband, 2:229
- entitled to maintenance, 2:241; 65:1
- equal right to divorce, 2:228
- fear ill treatment by husband, 4:128
- may keep what her husband gave her, 2:229
- not to be expelled from their homes, 65:1
- three menstruation wait to disprove pregnancy, 2:228
- three month wait for those free of menstruation, 65:4
- unless marriage unconsummated, 33:49
Dogs, 7:176
Donkeys (Ass), 2:259; 16:8; 31:19; 62:5; 74:50
Drink
- alcoholic, 2:219; 5:90
- pure and white delicious, 37:45-46; 76:21
- pure sealed wine, 83:25
Duha, S.93
Dukhan, S.44
Elephant army, 105:1-5
Elias (Elijah; Ilyasin) 6:85; 37:123-132
Elisha, (Alyasa') 6:86; 38:48
Enoch, (see Idris)
Event, 56:1; 69:15
Evil, 4:123; 10:27-30; 19:83; 59:15
- should not be uttered in public, 4:148
- comes from ourselves, but good good from Allah, 4:79; 42:48
- pardon an, 4:149
- recompensed, 6:160; 42:40
- who devise, plots, 16:45-47
- was the end, 30:10
- has appeared on land and sea, 30:41
- repel/defend, with good, 13:22; 23:96; 41:34
- changed, for the good, 7:95
- those follow their, desires, 47:14, 16
- deeds beautified for them, 47:14
Excess
- forbidden in food, 5:87
- in religion, 4:171; 5:77-81
Eyes, ears and skins will bear witness against sinners, 41:20-23
Ezra, (Uzair) 9:30
Face or Countenance of Allah, 2:115, 272; 6:52; 13:22; 18:28; 28:88; 30:38-39; 55:27; 76:9; 92:20
Fair-seeming
- Allah has made, to each people its own doings, 6:108
Faith (Belief), 2:108; 3:167, 177, 193; 5:5; 9:23; 16:106; 30:56; 40:10; 42:52; 49:7, 11, 14; 52:21; 58:22; 59:9-10
- rejectors of, 3:116
- increase in, 3:173
- with certainty, 44:7; 45:4, 20; 51:20
- He has guided you to the, 49:17
Fajr, S.89
Falaq, S.113
False conversation about Verses of Quran, 6:68
False gods
- besides Allah, idols and so-called partners 7:194-198; 16:20-21, 72, 86; 21:22, 24; 34:22, 27; 41:47-48; 46:5-6; 53:19-24; 71:23-24
- insult not those whom they worship besides Allah, 6:108
- see also Taghut
Falsehood (Batil), 2:42; 3:71; 8:8; 9:24; 13:17; 17:81; 21:18; 22:62; 29:52, 67; 31:30; 34:49; 40:5; 41:42; 42:24; 47:3
Fastened man's deeds to his own neck,17:13
Fasting, 2:178, 183, 184-185, 187, 196; 4:92; 5:89, 95; 19:26; 33:35
- eat and drink until white thread appears distinct from the black thread, 2:187
Fath, S.48
Fatihah, S.1
Fatir, S.35
Fidyah (ransom), of fast, 2:196
- for freeing the captives, 8:67
- ransom offered by disbelievers, 3:91; 5:36,37; 10:54; 13:18
Fig, 95:1
Fighting
- in the way of Allah, against disbelievers, 2:190-193, 244; 4:84, 95; 8:72, 74, 75; 9:12-16, 20, 24, 36, 123; 47:4; 61:11
- ordained, 2:216
- in sacred months, 2:217; 9:5
- by Children of Israel, 2:246-251
- in the Cause of Allah, and oppressed men and women, 4:74-76
- till no more Fitnah, 8:39
- twenty overcoming two hundred, 8:65
- against those who believe not in Allah, 9:29
- permission against those who are wronged,22:39-41
- and the hypocrites, 47:20
- exemptions from, 48:17
Fil, S.105
Firdaus Paradise, 18:107; 23:11
Fire, 56:71, 100:2
Fly, 22:73
Food
- lawful and unlawful, (Halal and Haram), 2:168, 172, 173; 5:1, 3-5, 88; 6:118-119, 121, 145-146; 16:114-118; 23:51
- no sin for what ate in the past, 5:93
- transgress not, 5:87
- make not unlawful which Allah has made lawful, 5:87; 7:32; 16:116
Forbidden conduct, 6:151-152; 7:33
Forgiveness, 2:109; 4:48, 110, 116; 5:74; 7:199; 39:53; 42:5, 40-43; 45:14; 53:32; 57:21
- a duty of Believers, 42:37; 45:14
- by Believers, for people of the Scripture,2:109
- Allah forgives to whom He pleases, 4:48
- Allah forgives not setting up partners in worship with Him, 4:48, 116
- whoever seeks Allah's, 4:110
- not to ask Allah's, for the Mushrikun, 9:113
- Allah forgives all sins, 39:53
- angels ask for, for those on the earth, 42:5
- forgive, when they are angry, 42:37
- forgive and make reconciliation, 42:40
- Believers to forgive those who hope not for the Days of Allah, 45:14
- for those who avoid great sins and the Fawahish, 53:32
- race one with another in hastening towards, 57:21
- evil deeds changed into good deeds 25:68-71
Fraud, (see Betray) 83:1-6
Free will
- limited by Allah's Will, 6:107; 10:99; 74:56;76:31; 81:28-29
- whosoever wills, let him: believe and disbelieve, 18:29
- take a path to his Lord, 76:29
- walk straight, 81:28
Friday prayers, 62:9-11
Fruits, 6:41; 16:11
- in Paradise, in plenty, 43:73
- every kind of, 47:15
- as they desire, 77:42
Fujjar, 82:14-16; 83:7
Furqan, S.25
Fussilat (see Ha Mim), S.41
Gabriel, (Jibril) 2:97-98; 26:193; 66:4; 81:19-21
- Ruh, 26:193; 67:12; 70:4; 78:38; 97:4
- Ruh-ul-Qudus, 2:87, 253; 5:110; 16:102
Gambling, 2:219; 5:90
Game, in a state of Ihram, 5:94-96
Ghafir (see Mu'min), S.40
Ghashiyah, S.88
Ghusl, 4:43; 5:6
Gifts, 30:39
Goliath, (Jalut) 2:249-251
Good (Days), 3:140
- you dislike a thing which is, and like which is bad, 2:216
- to be rewarded, 4:85; 28:54
- rewarded double, 4:40; 28:54
- rewarded ten times, 6:160
- increased, 42:23
- for those who do, there is good and the home of Hereafter, 16:30
- is for those who do good in this world, 39:10
- Allah rewards those who do, with what is best, 53:31
- is there any reward for, other than good, 55:60
- do, as Allah has been good to you, 28:77
Good and Evil
- good is from Allah and evil is from yourself,4:79
- if you do good, for your ownselves and if you do evil, against yourselves, 17:7;41:46
- repel evil with good, 23:96; 28:54; 41:34
- good and the evil deed cannot be equal,41:34
- every person will be confronted with all the, he has done, 3:30
- see also Muhsinun
Good deed
- disclose or conceal it, 4:149
- strive as in a race in, 5:48
Gospel, 3:3, 48, 65; 5:46-47, 66, 68, 110;7:157; 9:111; 48:29; 57:27
Great News, 78:1-5
Greeting, 4:86; 10:10; 14:23; 33:44; 25:75; 24:61
Hadid, S.57
Hady (animal for sacrifice), 2:196, 200
Hajj (Pilgrimage), 2:158, 196-203; 3:97; 5:2;22:30
Hajj, S.22
Haman, 28:6, 38; 29:39; 40:24, 36, 37
Hands and legs will bear witness, 36:65
Haggah, S.69
Hardship, there is relief with every, 94:5-6
Harun, (Aaron)
Harut, 2:102
Hashr, S.59
Hearts
- hardened, 2:74; 22:53; 39:22; 57:16
- sealed, 7:100-101; 40:35; 47:16; 63:3
- covered, 17:46; 41:5
- locked up, 47:24
- divided, 59:14
- filled with fear, 22:35
- in whose, there is a disease, 2:10; 5:52; 8:49; 9:125; 22:53; 24:50; 33:12, 32, 60; 47:20, 29;74:31
Heavens
- to Allah belong the unseen of the, 16:77
- created not for a play, 21:16
- and the earth were joined together, 21:30
- there is nothing hidden in the, 27:75
- created without any pillars, 31:10
- will be rolled up in His Right Hand, 39:67
- creation of seven heavens in two days, 41:12
- adorned nearest heaven with lamps, 41:12
- to Allah belongs all that is in the, 45:27;53:31
- seven heavens, one above another, 67:3
Hell (the fire, the blazing flame) 2:24, 119, 161, 166, 201; 3:10, 12, 116, 131, 151, 162, 192; 4:55-56, 93, 97, 114, 121, 169; 5:10, 37, 72, 86; 6:27, 70, 128; 7:18, 36, 38, 41, 50, 179; 8:16, 36, 50; 9:17, 35, 49, 63, 68, 73, 81, 95, 109, 113; 10:8, 27; 11:16-17, 11:98, 106, 113, 119; 13:5, 18, 35; 14:16, 49; 15:43; 16:29, 62; 17:8, 18, 39, 63, 97, 129; 18:53, 100, 106; 19:68, 70, 86; 20:74, 21:39, 21:98, 22:4, 22:9, 51, 72; 24:57, 25:11-13, 34, 65; 26:91, 94; 27:90, 28:41, 29:25, 54, 68; 31:21; 32:13, 20; 33:64, 66; 34:12, 42; 35:6, 36; 36:63, 37:10, 23, 55, 63, 68, 163; 38:27, 56, 59, 61, 64, 85; 39:8, 16, 19, 32, 60, 71, 72; 40:6-7, 41-43, 46, 47-49, 60, 72, 76; 41:19, 24, 28, 40; 42:7, 44:47, 56; 45:10, 34-35; 46:20, 34; 47:12, 15; 48:6, 13; 50:24, 30; 51:13, 52:13-16, 18; 54:48, 55:43, 56:94, 57:15, 19; 58:8, 17; 59:3, 17, 20; 64:10, 66:9-10, 67:5-10, 69:31, 70:15, 71:25, 72:15, 23; 73:12-13, 74:26-31, 42; 76:4, 77:31, 78:21, 79:36, 39; 81:12; 82:14; 83:16; 84:12; 85:10; 87:12; 88:4; 89:23; 90:20; 92:14; 98:6; 101:9-11; 102:6; 104:6-9; 111:3
- burning and boiling water 22:19-22; 23:103-104
- pus 14:14-17; 38:55-58; 69:35-37
- tree of Zaqqum 37:62-70; 44:43-50; 56:41-56
- residents' inability to live or die 87:13
- blame throwing 26:91-101; 34:31-33
- calls for instant destruction 25:13-14; 43:74-78
- fervent cries 35:36-37
- Fire growling and roaring 25:11-12; 67:6-11
- roasted skins replaced with new ones 4:56
- shackles and clothes of tar 14:48-50
- maces of iron 22:19-22
- chains 13:5
- keepers of Hell 39:71; 40:49-50; 43:77; 66:6; 67:8; 74:30-31; 96:18
- no ransom accepted 5:36-37
- intercession denied 6:94; 26:100; 30:13; 74:48
- burning despair and ice cold darkness in, 38:57
- chain of 70 cubits, 69:32
- stay for a limited duration, 78:23
Hereafter
- better is the house in the, 6:32; 7:169
- which will be the end in the, 6:135
- Zalimun will not be successful (in), 6:135
- home of the, 12:109; 16:30; 28:83; 29:64
- who believe not in the, 17:10
- reward of the, 42:20
- better than silver and gold, 43:33-35
- only for the Muttaqun, 43:35
- punishment of, 68:33
- better and more lasting, 87:17
- better than the present, 93:4
Highways, broad, 21:31
Hijr (Rocky Tract), 15:80-85
Hijr, S.15
Homosexuality 26:165-166; 27:55; 29:28-29
Horses, 16:8
Hour
- the knowledge of it is with Allah only, 7:187; 31:34; 33:63; 41:47; 68:26; 79:42-46
- all of a sudden it is on them, 6:31; 7:187;12:107; 43:66
- comes upon you, 6:40; 12:107; 20:15; 34:3
- has drawn near, 54:1-5
- as a twinkling of the eye, or even nearer,16:77
- earthquake of the, 22:1
- will be established, on the Day, 30:12, 14
- surely coming, there is no doubt, 40:59;45:32; 51:5-6
- signs 21:96; 27:82; 43:61; 47:18; 54:1-2
- names 1:3; 2:4; 3:55; 19:39; 30:56; 37:21; 40:15; 41:47; 42:7; 50:20; 56:1; 64:9; 69:1; 79:34; 80:33; 88:1; 101:1-3
- will take people by surprise 6:31; 7:187
- Trumpet will be blown 6:73; 23:101; 39:68
Houses, manners about entering, 24:27-29
Hud, 7:65-72; 11:50-60; 26:123-140; 46:21-26
Hud, S.11
Hujurat, S.49
Humazah, S.104
Hunain (battle), 9:25
Hur (females in Paradise), 44:54; 52:20
Hypocrites
- say: we believe in Allah and the Last Day, but in fact believe not, 2:8
- deceive themselves, 2:9
- disease in their hearts, 2:10; 8:49; 22:53;33:12; 47:29
- make mischief, 2:11-12
- fools and mockers, 2:13-15
- purchased error for guidance, 2:16
- deaf, dumb and blind, 2:17-18
- in fear of death and darkness, 2:19-20
- pleasing speech, 2:204-206
- refuse to fight, 3:167-168
- Allah knows what is in their hearts, 3:167;4:63
- go for judgement to false judges, turn away from Revelation, come when a catastrophe befalls, 4:60-62
- in misfortune and in a great success, 4:72-73
- Allah has cast them back, 4:88
- not to be taken as friends, 4:89; 58:14-19
- if they turn back, kill them wherever you find them, 4:89
- they wait and watch for your victory or disbelievers success, 4:141
- seek to deceive Allah, they pray with laziness and to be seen of men, 4:142
- belong neither to these nor to those, 4:143
- in lowest depths of Fire; no helper, 4:145
- afraid of being found out, 9:64-65
- not to pray for, 9:84
- men and women are from one another; losers; Curse of Allah, 9:67-69
- in Bedouins, 9:101
- wherever found, they shall be seized and killed, 33:61
- Allah will punish the, 33:73
- liars; turning their backs; their hearts are divided, 59:11-14
- liars; made their oaths a screen; their hearts are sealed; beware of them, 63:1-4
- comprehend not, know not, 63:7-8
- to strive hard against, 66:9
Iblis (Satan), 2:34; 7:11-18; 15:31-44; 17:61-65; 18:50; 20:116-120; 34:20-21; 38:71-85
- see also Satan
Ibrahim, (see Abraham)
Ibrahim, S.14
'Iddah (divorce prescribed period of women), 2:228, 231, 232, 234, 235; 33:49;65:1-7
Idris (Enoch), 19:56-57; 21:85; 96:4
Ihram, 2:197; 5:2, 95
Ihsan, 16:90
Ikhlas, S.112
Ilah, only One, 2:163; 6:19; 16:22, 51; 23:91; 37:4; 38:65
Illegal sexual intercourse; evidence of witnesses, 4:15-18; 24:2, 19
Illiyyun, 83:18-21
Impure (Najas) 9:28
'Imran
- wife of, 3:35
- daughter of, 66:12
Inevitable, 69:1-3
Infitar, S.82
Inheritance, 2:180, 240; 4:7-9, 11-12, 19, 33,176; 5:106-108
Injustice, to whom has been done, 4:30, 148
Insan (see Dahr), S.76
Inshiqaq, S.84
Inshirah (see Sharh), S.94
Inspiration, 6:93; 10:2, 109; 12:102; 17:86;40:15; 42:3, 7, 51-52; 53:4, 10
Intercession/Intercessor, 6:51, 70, 93-94;10:3; 19:87; 20:106, 109; 30:13; 34:23;39:44; 40:18; 43:86; 53:26; 74:48
Intoxicants, 5:90, 2:219
Iqamat-as-Salat, 2:3, 43, 83, 110, 177, 277; 4:77, 102-103; 5:12, 55; 6:72; 7:170; 8:3;9:5, 11, 18, 71; 10:87; 11:114; 13:22; 14:31,37; 17:78; 20:14; 22:41, 78; 24:56; 27:3; 29:45; 30:31; 31:4, 17; 33:33; 35:18, 29;42:38; 58:13; 73:20; 98:5
Iqra' (see 'Alaq), S.96
Iram, 89:7
Iron, 57:25
'Isa, see Jesus
Isaac, (Ishaq) 2:133; 4:163; 6:84; 19:49;21:72; 29:27; 37:112-113
Ishmael (Isma'il), 2:125-129, 133; 4:163;6:86; 19:54-55; 21:85; 38:48
raises foundations of the Ka’bah with his father 2:125-140
story of the sacrifice 37:100-113
Islam, 3:19, 85; 5:3; 6:125; 39:22; 61:7
- first of those who submit as Muslims, 6:14,163; 39:12
- first to embrace, 9:100
- breast opened to, 39:22
- as a favour, 49:17
Isra', S.17
Israel, Children of, 2:40-86
- favour bestowed, 2:47-53, 60, 122; 45:16-17
- rebelling against Allah's obedience, 2:54-59, 61, 63-74; 5:71; 7:138-141
- their relations with Muslims, 2:75-79
- their arrogance, 2:80, 88, 91
- their covenants, 2:80, 83-86, 93, 100; 5:12-13, 70
- bought the life of this world at the price of Hereafter, 2:86
- greediest of mankind for life, 2:96
- ask for a king, 2:246-251
- exceeded the limits; broken into various groups; monkeys, 7:161-171
- promised twice, 17:4-8
- delivered from enemy, 20:80-82
- given Scripture and leaders, 32:23-25; 40:53-54
- the learned scholars of, knew it (Quran as true), 26:197
Istawa (rose over), 2:29; 7:54; 10:3; 13:2;20:5; 32:4; 41:11; 57:4
I'tikaf, 2:187
Jacob, (Ya'qub) 2:132-133; 4:163; 6:84;12:18; 19:49; 21:72; 29:27
- Asbat (twelve sons of Jacob), 2:140; 3:84;4:163
Jalut, (see Goliath)
Jamarat, 2:200
Jathiyah, S.45
Jesus, Isa son of Mary
- mother chosen over all women of the world 3:42
- bears witness on Resurrection Day, 4:159
- glad tidings of birth, 3:45-47; 19:22-23
- Messenger to the Children of Israel, 3:49-51
- disciples, 3:52-53; 5:111-115
- disciples as Allah's helpers, 3:52; 61:14
- raised up, 3:55-59; 4:157-159
- likeness of Adam, 3:59
- neither killed nor crucified, 4:157
- inspired, 4:163
- no more than Messenger (not to deify him), 4:171-172; 5:75; 19:30, 43:63-64
- they have disbelieved who say, 5:17, 72; 9:30
- Our Messenger (Muhammad ﷺ ) has come, 5:19
- gave the Gospel, 5:46
- disciples said: we are Muslims, 5:111
- Table spread with food, 5:114
- taught no false worship, 5:116-118
- a righteous Prophet, 6:85
- as a Sign, 23:50
- his second coming 43:61
- divergent views about, 43:65
- no more than a slave and an example to the Children of Israel, 43:59
- glad tidings of a Messenger whose name shall be Ahmed, 61:6
- his virgin birth, message, and miracles 3:45-51; 19:16-38
- reminded of Allah's favours 5:110-115
- denies being divine 5:116-120
- compassion and grace in the hearts of his followers 5:82; 57:27
Jews and Christians, 2:140; 4:153-161, 171; 5:18
- listen to falsehood, 5:41-42
- accursed for what they uttered, 5:64
- enmity to the believers (Muslims), 5:82
- who embraced Islam, 26:197; 28:53; 29:47
Jibril, (see Gabriel)
Jihad, (Fighting, Striving) 2:216; 9:24; 22:78; 25:52
Jinn, S.72
Jinn, 6:100, 112; 15:27; 34:41; 38:37; 46:18,29; 55:33, 39
Jinn, created from fire 15:25; 55:15
- believing and disbelieving jinn 72:1-15
- some believed in the message of the Quran 46:29-32
- humans and jinn created for a purpose 51:56-58
Job, 4:163; 6:84; 21:83-84; 38:41-44
John, (Yahya, John the Baptist)
- glad tidings of, 3:38-41; 19:7-11; 21:90
- righteous, 6:85
- wise, sympathetic, dutiful, 19:12-15
Jonah (Jonas or Yunus), 4:163; 6:86; 10:98;21:87; 37:139-148
- (Dhu n-Nun) 21:87; 68:48-50
Joseph (Yusuf), 6:84; 12:4-101
- best of stories 12:1-3
- young Yusuf's dream 12:4-6
- conspiracy by his brothers 12:7-18
- sold into slavery 12:19-20
- raised in Egypt's Chief Minister's house 12:21-22
- Chief Minster's wife tries to seduce him 12:23-29
- banquet incident 12:30-32
- goes to jail 12:33-35
- the two inmates 12:36-42
- King's dream 12:43-53
- becomes Chief Minister 12:54-57
- brothers come to him for supplies 12:58-68
- takes his brother Benjamin 12:69-82
- his father's renewed grief 12:83-87
- reveals his true identity 12:88-98
- old dream comes true 12:99-100
- concluding prayer 12:101
Judi, Mount, 11:44
Jumu'ah, S.62
Justice (Adl), 2:282; 4:58, 135; 7:29; 16:90; 57:25 (
- see also 4:65, 105
Ka'bah
- built by Abraham, 2:125-127
- no killing of game, 5:94-96
- asylum of security, 5:97
- going round in naked state, 7:28
- while praying and going round, 2:200; 7:29, 31
Kafirun, S.109
Kafur, cup mixed with, 76:5
Kahf, S.18
Kanz, 9:34-35
Kauthar (river in Paradise), 108:1
Kauthar, S.108
Keys
of the heavens and the earth, 39:63; 42:12
of the Ghaib, 6:59
Khaulah bint Tha labah, 58:1
Killing
- if anyone killed a person, he killed all mankind, 5:32
- do not kill anyone, 17:33
Kind words are better than charity, 2:263
Kindred, rights of, 2:83, 177, 215; 4:7-9, 36;8:41; 16:90; 17:26; 24:22; 29:8; 30:38; 42:23
Kiraman-Ratibin, 82:11
Knowledge
- not a leaf falls, but He knows it, 6:59
- lost are they who have killed their children from folly, without, 6:140
- of five things, with Allah Alone, 31:34
- with certainty, 102:5-7
Korah (Qarun), 28:76-82; 29:39; 40:24
Kursi, 2:255
Lahab (See Masad), S.111
Lail, S.92
Lamp, 25:61; 67:5; 71:16; 78:13
Languages
- difference in, and colors of men, 30:22
Lat, 53:19
Law, prescribed, 5:48
Laws from Allah, 2:219; 98:3
Liars, 26:221-223
Life, if anyone saved a person, he saved the life of all mankind, 5:32
Life of this world
- bought the, at the price of Hereafter, 2:86
- is only the enjoyment of deception, 3:185
- sell the, for the Hereafter, 4:74
- is nothing but amusement and play, 6:32; 29:64; 47:36; 57:20
- deceives, 6:130
- little is the enjoyment of the, than the Hereafter, 9:38; 13:26; 28:60
- likeness of, is as the rain, 10:24
- glad tidings in the, 10:64
- whoever desires, gets therein; but then there will be no portion in the Hereafter, 11:15-16; 17:18; 42:20
- who love the present, and neglect the Hereafter, 75:20-21; 76:27
- you prefer the, 87:16
Light
- manifest, 4:174
- and darkness, 6:1
- parable of, 24:35
- goes before and with the Believers, 57:12-15; 66:8
- given by Allah, that the Believers may walk straight, 57:2
Limits set by Allah, 2:173, 187, 190, 230;9:112; 58:4; 65:1; 78:22
- these are the, 2:187; 229-230; 4:13; 58:4; 65:1
- transgress not the, 2:190, 229
- whosoever transgresses, 2:229; 4:14; 78:22
- but forced by necessity, nor transgressing the, 2:173; 6:145
- do not exceed the, in your religion, 4:171; 5:77
- when they exceeded the, (became monkeys), 7:166
- who observe the, 9:112
Lion, 74:51
Loan
- lend to Allah a goodly, 2:245; 73:20
- increased manifold, 57:11, 18
- doubled, 64:17
Loss, manifest, 39:15
Lot, (Lut) 6:86; 7:80; 11:70, 74, 77, 81, 89; 15:59, 61; 21:71, 74; 22:43; 26:160-161, 167; 27:54-56; 29:26, 28, 32-33; 37:133; 38:13;50:13; 54:33-34; 66:10
- his disobedient wife, 11:81; 15:60; 66:10
Lote tree, 34:16; 53:14-16; 56:28
Luqman, 31:12-14
Luqman, S.31
Ma'arij, S.70
Madinah (Yathrib), 9:120; 33:13, 60; 63:8
Madyan, 7:85-93; 11:84-95; 20:40; 22:44; 28:22-23; 29:36-37
- see also Aikah Wood
Mahr (bridal-money), 2:229, 236-237; 4:4,19-21, 24-25; 5:5; 33:50; 60:10-11
Ma'idah, S.5
Makkah (Bakkah), 3:96;90:1-2
- City of Security, 95:3
Man
- generations after generations on earth, 2:30;6:165
- made successor, 35:39
- duty, 2:83-84, 88, 177; 4:1-36; 8:41; 16:90;17:23-39; 24:22; 29:8-9; 30:38;33:33;42:23; 64:14; 70:22-35
- tested by Allah, 2:155; 3:186; 47:31; 57:25
- things men covet, 3:14
- created from, 4:1; 6:2; 15:26, 28, 33; 16:4;21:30; 22:5; 23:12-14; 25:54; 30:20; 32:7-9;35:11; 36:77-78; 37:11; 39:6; 40:67; 49:13;55:14; 56:57-59; 75:37-40; 76:1-2; 77:20-23;80:18-19; 86:5-8; 96:2
- created and decreed a stated term, 6:2; 15:26
- reconciliation between, and wife, 4:35
- losers who denied their Meeting with Allah,6:31
- the return, 6:60, 72, 164; 10:45-46
- plots against ownself, 6:123
- shall not bear the burden of another, 6:164
- is ungrateful, 7:10; 11:9; 30:34; 32:9; 80:17;100:6
- warned against Satan, 7:27
- wife and children, 7:189-190
- when harm or evil touches, 10:12; 11:9-10;16:53-55; 17:67; 29:10; 30:33; 31:32; 39:8,49; 41:49-51; 42:48; 70:19-21; 89:16
- returning towards the Lord, 10:23; 84:6; 96:8
- wrong themselves, 10:44
- is exultant and boastful, 11:10
- invokes for evil, 17:11
- is ever hasty, 17:11
- his deeds fastened to his neck, 17:13
- whoever goes astray, to his own loss and goes right, only for his ownself, 17:15
- not be dealt unjustly, 17:71
- death and resurrection, 23:15-16
- have broken their religion into sects, each rejoicing in its belief, 23:53
- tongues, hands and feet will bear witness against, 24:24
- witness against himself, 75:14
- who has taken as his god his own desire,25:43
- kindred by blood and marriage, 25:54
- Allah has subjected for you whatsoever is in the heaven and earth, 31:20
- whosoever submits his face to Allah, 31:22
- not two hearts inside his body, 33:4
- to worship Allah, 39:64-66
- misfortunes because of what his hands have earned, 42:30, 48
- angels recording his doings, 50:17-18, 23;85:11
- angels guarding him, 13:11; 86:4
- sorted out into three classes, 56:7-56
- those nearest to Allah, 56:10-11
- companions of Right Hand, 56:27-40
- companions of Left Hand, 56:41-56
- to be transfigured and created in forms unknown, 56:60-62
- made shapes good, 64:3
- wealth and children are only a trial, 64:15
- created and endowed with, 67:23-24; 74:12-15; 90:8-10
- is impatient, 70:19-21
- devoted to prayers, 70:22-35
- desires more, 74:15
- witness against himself, 75:14-15
- his arrogance, 75:31-40; 90:5-7
- loves the present life of this world, 76:27
- more difficult to create, or is the heaven,79:28
- careless concerning the Lord, 82:6-12
- fashioned perfectly and given due proportion, 82:7
- travels from stage to stage, 84:19
- love of wealth, 89:20
- created in toil, 90:4
- efforts and deeds are diverse, 92:4
- smooth for him the path of Ease, and Evil,92:7, 10
- created of the best stature (moulds), 95:4
- then reduced to the lowest of the low, 96:5
- transgresses all bounds, 96:6-7
Manasik (duties) of Hajj, 2:128, 200; 22:30
Manat, 53:20
Mankind
- witnesses over, 2:143
- one community, 2:213; 10:19
- created from single pair, 4:1; 39:6; 49:13
- rebellion against ownselves, 10:23
- heedless though Reckoning is near, 21:1-3
- created on Fitrah, 30:30
- most honourable of, 49:13
- made into nations and tribes, 49:13
Manna and the quails, 2:57
Manners
- about entering houses, 24:27-29
- in the home, 24:58-61
- in the Prophet's houses, 33:53
- to greet and send Salat on the Prophet, 33:56
- not to annoy Allah and His Messenger or believing men or women, 33:57-58
- verify news before belief, 49:6
- not to scoff another, 49:11
- in assemblies, 58:11
Marriage, 2:232, 234
- to disbelievers or slaves, 2:221
- to how many, lawful, 4:3
- Mahr not to be taken back (in case of divorce), 4:20-21
- forbidden are for, 4:22-24
- if no means to wed free believing women,4:25
- if breach feared, two arbitrators to be appointed, 4:35
- if wife fears cruelty or desertion, make terms of peace, 4:128
- not incline too much to one wife so as to leave the other hanging, 4:129
- of adulterers, 24:3
- to those who are poor, 24:32
- those who find not the financial means for marriage, 24:33
- wives made lawful to the Prophet, 33:50-52
- before sexual intercourse, no Iddah on divorce, 33:49
Martyrs
- not dead, 2:154; 3:169
- rejoice in Grace and Bounty from Allah,3:170-171
- receive forgiveness and mercy, 3:157-158
- will receive good provision, 22:58-59
Marut, 2:102
Mary (mother of Jesus), birth, 3:35-7
- glad tidings of Jesus, 3:42-51; 19:16-21
- in childbirth, 19:23-26
- brought the babe to her people, 19:27-33
- false charge, 4:156
- guarded her chastity, 21:91; 66:12
Maryam, S.19
Masad, S.111
- Al-Masjid-al-Agsa, 17:1
- Al-Masjid-al-Haram, 2:144, 149-150, 191, 196, 217; 5:2; 9:19, 28; 17:1; 48:25, 27
- Al-Mash'ar-al-Harăm, 2:198
Maun, S.107
Ma'wa Paradise, 53:15
Measure and weight, give full, 11:85; 17:35;83:1-5
Meeting
- with Allah, 6:31
- of Great Day, 19:37
- of the Hereafter, 30:16
Messengers, 2:253; 4:164-165; 40:78; 57:27
- succession of, 2:87
- series of, 5:19; 23:44
- killed, 3:183
- threatened, 14:13
- mocked, 6:10; 13:32; 15:11; 21:41
- denied and rejected,3:184; 6:34;25:37;34:45; 51:52
- believing in some and rejecting others,4:150-152
- gathering of the, 5:109
- sent as givers of glad tidings and warners,6:48; 14:4-8
- as a witness from every nation, 16:89
- for every nation, there is a, 10:47; 16:36
- reciting Allah's Verses, 7:35-36
- an angel as a, 17:95; 25:7
- no more than human beings,14:10-12;17:94; 21:8; 25:7-8, 20
- and their wives and offspring, 13:38
- see also Prophets
Miraj, 17:1; 53:12
Miserliness/Misers, 57:24
Misfortune, because of your hands, 42:30
Monasticism, not prescribed, 57:27
Monkeys, transgressors became as, 2:65;5:60; 7:166
Miraj, 17:1; 53:12
Months, number of, 9:36-37
Moon, 7:54; 10:5; 16:12; 22:18; 25:61; 36:39-40; 71:16; 91:2
- splitting of; 54:1
Moses
- and his people, 2:51-61; 7:138-141,159-162; 14:5-8; 61:5
- and Pharaoh, 2:49-50; 17:101-103; 20:17-53, 56-79;23:45-49; 25:31-42; 40:23-46; 43:46-56; 51:38-40; 73:16;79:15-26
- guided by Allah, 6:84
- mountain and Lord's appearance, 7:142-145
- rebukes his people for calf-worship, 7:148-156;20:83-99
- his Book, differences arose therein, 11:110
- given the Scripture, 17:2
- nine Clear Signs, 7:133; 17:101
- to the junction of the two seas, 18:60-82
- fateful encounter at the burning bush 20:9-36; 27:7-14; 28:29-35
- called and given Messengership, 19:51-53;20:9-56
- his childhood, mother and sister, 20:38-40;28:7-13
- magicians converted, 20:70-73; 26:46-52
- in Madyan, 20:40; 28:22-28
- granted the Criterion, 21:48
- and the mystic fire, 27:7-12; 28:29-35
- kills an Egyptian by mistake in the city 28:14-21
- came with clear Ayat, 29:39
- story with Pharaoh 7:103-137; 10:75-92; 11:96-99; 26:10-69
- nine signs for Pharaoh and his people 7:130-133; 20:17-22; 17:101
- defeats Pharaoh's magicians 20:70-73; 26:46-52
- escape to Midian and marriage 28:22-28
- receives the Tablets 7:142-154
- asks to see Allah on the Mount 7:142-145
- honoured by Allah 33:69
- Allah's favours to Israelites 2:47-61
- Israelites refuse to enter Jerusalem 5:20-29
- guided to the Right Path, 37:114-122
- Scripture of, 53:36; 87:19
Mosque (of Jerusalem), 17:7
Mosque (of Quba), 9:107-108
Mosques, 2:187; 9:17-19
- to maintain, of Allah, 9:17-18
Mosquito, a parable, 2:26
Mountains, 15:19; 16:15; 20:105-107; 21:31;22:18; 31:10; 42:32-33; 59:21; 73:14; 77:10,27; 81:3; 101:5
Muddaththir, S.74
Muhajir (Emigrants), 4:100; 9:100, 107, 117;22:58-59; 24:22; 33:6; 59:8-9
- women, 60:10-12
Muhammad ﷺ
- mocked, 2:104; 4:46; 25:41-42; 34:78
- respect the Messenger, 2:104; 4:46; 49:1-5
- covenant to believe in, 3:81
- a witnesses over believers, 2:143
- no more than a Messenger, 3:144
- dealing gently, 3:159
- his work, 3:164; 7:157; 36:6; 52:29; 74:1-7
- sent as a great favour to the believers, 3:164
- sent with the truth, 4:170
- not made a watcher, 6:107
- unlettered, 7:157; 62:2
- sent to the mankind as the Messenger of Allah, 7:158; 48:9, 29
- a plain warner, 7:184, 188; 11:2; 15:89; 53:56
- not a madman, 7:184; 68:2; 81:22
- who accuse you, 9:58
- men who hurt the Prophet, a mercy to the Believers, 9:61
- only follow that which is revealed, 10:15-16; 11:12-14; 46:9
- his sayings, 11:2-4; 12:108; 34:46-50
- Allah is Witness over him, 13:43; 29:52; 46:8
- sent as a witness, bearer of glad tidings and a warner, 11:2; 15:89; 26:194; 33:45; 34:28;48:8
- not to be distressed, 15:97; 16:127; 18:6
- sent to be a witness, 16:89; 22:78; 73:15
- to invite with wisdom and fair preaching, and argue in a better way, 16:125
- Maqamu Mahmud, 17:79
- inspired, 18:110
- mercy for the 'Alamin, 21:107
- asks no reward, 25:57; 38:86; 42:23
- has been commanded to, 27:91-93;30:30;66:9
- as a mercy from Allah, 28:46-47
- close to the believers, 33:6
- good example to follow, 33:21
- last of the Prophets, 33:40
- send Salat on, 33:56
- sent to all mankind, 34:28
- wage is from Allah only, 34:47
- only a human being, 41:6
- sent as a protector, 42:48
- not a new thing in the Messengers, 46:9
- witness from among the Children of Israel,46:10
- Bai'ah (pledge) to him is Bai'ah (pledge) to Allah, 48:10, 18
- saw Gabriel, 53:4-18; 81:22-25
- oppose him not, 58:20-22
- foretold by Jesus, 61:6
- to make Religion of Truth victorious over all religions, 61:9
- from the darkness to the light, 65:11
- to strive hard against disbelievers and hypocrites, 66:9
- exalted standard of character, 68:4
- not a poet or soothsayer, 69:41-42
- devoted to prayer, 73:1-8, 20; 74:3
- and the blind man, 80:1-12
- to prostrate and draw near to Allah, 96:19
- reciting pure pages, 98:2
- Ayat regarding family of, 24:11-17; 33:28-34,50-53, 55, 59; 66:1, 3-6; 108:3
- see also Messengers; Prophets
Muhammad ( ﷺ ), S.47
Muhsinun (Good-doers), 2:117, 195; 4:125,128; 10:12-16; 16:128
- Allah loves the, 3:134, 148; 5:93
- Allah loses not the reward of the, 5:85;9:120; 11:115; 18:30
- We reward the, 12:22; 37:80, 105, 110; 39:34;77:44
- glad tidings to the, 22:37; 46:12
- Allah's Mercy is near to the, 7:56
- Allah is with the, 29:69
- dutiful and good to parents, 2:83
- patient in performing duties to Allah, 16:90
- see also Good and Evil
Mujadilah, S.58
Mules, 16:8
Mulk, S.67
Mumin (see Ghafir), S.40
Mu'minun, S.23
Mumtahanah, S.60
Munafigun, S.63
Murder, 2:178-179
Mursalat, S.77
Muslims
- first of the, 6:14, 163; 9:100; 39:12
- Who has named, 22:78
- forgiveness and a great reward for them who, 33:35-36
Mutaffifin, S.83
Muzzammil, S.73
Naba', S.78
Nadir, Banu-an-, (Jews), 59:2, 9, 13
Nahl, S.16
Najas (impure) 9:28
Najm, S.53
Najwa (See Secret)
Names
to Him belong the Most Beautiful, 7:180
to Him belong the Best, 17:110; 20:8; 59:24
Necessity, if one is forced by, 2:173; 6:145
Neighbour, 4:36
New moons, 2:189
News, to be tested 4:83
Niggardliness 3:180; 4:37; 17:29; 25:67;47:38; 57:24; 92:8
Night, (as a symbol), for rest, 10:67
- as a covering, 13:3; 78:10
- to be of service, 14:32
- Night of Al-Qadr (Decree), 44:3-4; 97:1-5
Nisa', S.4
Noah, 3:33; 4:163; 6:84; 9:70; 10:71;11:25, 32, 36, 42, 45-46, 48, 89; 17:3; 21:76; 25:37; 26:105; 29:14; 37:75; 51:46;54:9; 69:11
- mocked 11:38
- the Deluge (severe flood), 29:14
- the Ark and the Flood 7:59-69, 11:25-48; 23:23-31; 26:105-122; 71:1-28
- unrighteous son not saved, 11:42-48
- unrighteous wife, 14:9; 17:3, 17;19:58;21:76; 22:42; 26:105-106, 116; 33:7; 37:75,79; 38:12; 42:13; 40:5, 31; 42:13;50:12;53:52; 57:26; 66:10; 71:1, 21, 26
Nuh, S.71
Nur,S.24
Oath, 2:224-227; 3:77; 5:89; 6:109; 16:38, 91-92, 94; 24:22, 53; 66:2; 68:10, 39; 77:3
Obedience, 3:132; 4:59, 64, 66, 80-81; 5:95;18:46; 24:51=52, 54; 47:33; 64:12
Obligations to be fulfilled, 5:1
Offspring,4:9; 42:49-50
- He bestows male and female, upon whom He wills, 42:49
Olive, 6:141; 16:11; 23:20; 24:35; 95:1
Only One Mah, 2:163; 6:19; 16:22, 51; 23:91;37:4; 38:65
Orphans, 2:83, 177, 215, 220; 4:2-3, 6, 8, 10, 36, 127; 6:152; 8:41; 17:34; 18:82; 59:7;76:8; 89:17; 90:15; 93:6; 107:2
- guardians of, 4:6
Own doings, made fair-seeming to each people, 6:108
Pairs, in all creatures, 13:3; 30:8; 36:36;42:11; 43:12; 51:9, 49; 53:45
Palm tree, 13:4; 19:25; 20:71; 59:5
Parables, (likeness, example, similitudes)
- who kindled a fire, 2:17-18
- rain storm from the sky, 2:19-20
- mosquito, 2:26
- who shout, 2:171
- a town all in utter ruins, 2:259
- grain of corn, 2:261
- smooth rock, 2:264
- garden, 2:265-266
- rope, 3:103
- cold wind, 3:117
- resurrection 7:57; 22:5; 41:39
- dog who lolls his tongue out, 7:176
- brink of a precipice, 9:109-110
- rain, 10:24
- clean-mown harvest, 10:24
- blind and deaf, 11:24
- Allah versus false gods 13:14; 16:76
- truth versus falsehood 13:17
- ashes on which the wind blows furiously,14:18
- goodly tree, 14:24-25
- evil tree, 14:26
- slave and a man, 16:75
- dumb man who is a burden to his master,16:76
- woman undoing the thread, 16:92
- township, secure and well content, 16:112-113
- two men with gardens of grapes, 18:32-44
- life of this world like water from the sky,18:45
- fallen from the sky and snatched by birds,22:31
- a fly, 22:73
- Light is as a niche, 24:35-36
- mirage, 24:39
- darkness in a vast deep sea, 24:40
- spider, 29:41
- partners, 30:28
- dwellers of the town, 36:13-32
- crops of different colours, 39:21
- a man belonging to many partners, 39:29
- seed growing, 48:29
- hardened hearts 57:16-17
- vegetation after rain, 57:20
- mountain humbling itself, 59:21
- donkey, 62:5
- water were to be sunk away, 67:30
- people of the garden, 68:17-33
Paradise
- of Abode, (Ma'wa Paradise), 53:15
- Firdaus Paradise, 18:107; 23:11
- Gardens under which rivers flow, 3:15, 198;4:57; 5:119; 7:43; 9:72; 18:31; 22:23; 39:20;57:12; 64:9; 98:8
- Everlasting Gardens ('Adn Paradise) 9:72;13:23; 18:31; 19:61; 20:76
- Gardens of Eternity ('Adn Paradise), 16:31;35:33; 98:8
- Gardens of delight, 37:43; 56:12, 89
- Gardens with everlasting delights, 9:21
- Gardens and grapeyards, 78:32
- fruits of two gardens, 55:54, 62
- fruits of all kinds as desired, in plenty, 36:57; 37:42; 43:73; 44:55; 47:15; 55:52, 68;56:20, 29, 32; 77:42
- fruits will be near at hand, 55:54; 69:23
- fruit and meat, 52:22
- flesh of fowls, 56:21
- thornless lote trees and Talh (banana trees),56:28-29
- unbeneficial knowledge, donkey with books 62:5
- a running spring, 88:12
- spring called Salsabil, 76:18
- a spring called Kafur, 76:5
- a spring Tasnim, 83:27-28
- a river in Paradise, Kauthar, 108:1
- rivers of wine, milk, clarified honey, 47:15
- pure sealed wine, white, delicious, 37:45-46; 56:18; 76:21; 83:25
- cup, mixed with, Zanjabil, 76:17; 78:34
- water, 76:5
- trays of gold and cups, 43:71
- vessels of silver and cups of crystal, 76:15-16
- green garments of fine and thick silk, 18:31;22:23; 35:33; 44:53; 76:12, 21
- adorned with bracelets of gold and pearls,18:31; 22:23; 35:33; 76:21
- coaches lined with silk brocade, 55:54
- green cushions and rich beautifulmattresses, set in row, 55:76; 88:15
- thrones woven with gold and precious stones, raised high 56:15; 88:13
- rich carpets spread out, 88:16
- beautiful mansions, lofty rooms, one above another, 9:72; 39:20
- abiding therein forever, 3:198; 4:57; 5:119;9:22, 72; 11:108; 43:71; 57:12; 98:8
- eternal home, 3:15; 35:35
- facing one another on thrones, 15:47; 37:44;44:53; 56:16
- never taste death therein, 44:56
- nor they (ever) be asked to leave it, 15:48
- hatred or sense of injury removed from their hearts, 7:43; 15:47
- all grief removed, 35:34
- no sense of fatigue, toil or weariness, 15:48;35:35
- neither will be any hurt, abdominal pain, headache nor intoxication, 37:47; 56:19
- no vain speaking nor sinful speech, 19:62;56:25
- neither harmful speech nor falsehood,78:35; 88:11
- free from sin, 37:47; 52:23
- neither excessive heat nor bitter cold, 76:13
- there will be a known provision, 37:41;56:89
- in peace and security, 15:46; 44:51, 55; 50:34
- home of peace, 6:127
- greetings in, 7:46; 10:10; 13:24; 14:23; 16:32;19:62; 36:58; 39:73; 56:26
- whoever does righteous deeds will enter,4:124; 42:22; 44:51
- who kept their duty to their Lord will be led in groups, 39:73
- been made to inherit because of deeds,43:72
- Allah is pleased with them and they with Him, 5:119
- My Paradise, 89:30
- the greatest bliss, 9:72
- the great success, 57:12; 64:9
- the supreme success, 9:72; 44:57
- for believers are Gardens as an entertainment, 32:19
- dwellers of Paradise will be busy in joyful things that Day, 36:35
- will be amidst gardens and water springs, 15:45; 19:63; 44:52; 52:17; 54:54; 55:46
- see the angels surrounding the Throne,39:75
- near the Omnipotent King, 54:55
- they will have all that they desire, 50:35
- Hurs, chaste females with wide and beautiful eyes, as if preserved eggs, 37:48-49; 44:54; 52:20; 55:58, 70; 56:22-23
- pure wives, 3:15
- wives in pleasant shade, reclining on thrones, 36:55
- young full-breasted maidens of equal age,78:33
- immortal boy-servants to serve them, as scattered pearls, 52:24; 56:17; 76:19
- as vast as the heavens and the earth 3:133, 57:21
- running water, cool shade, delicacies, and pure mates 2:25; 4:57; 36:55-58; 37:40-49; 38:50-54; 44:51-57; 52:17-24; 69:19-24; 76:5-22
- reward of the believers 55:46-78; 56:10-40
- rivers of honey, milk, water, and wine 47:15
- prayers and greetings 10:9-10; 39:73-74
- saluted with greetings of peace 13:23-24; 14:32
- everlasting stay in Bliss 11:108
- never asked to leave 15:45-48
- light shining ahead of them and on their right 57:12
- no heat or cold 76:13
- all wishes granted 16:30-32; 41:31-32
- bracelets of gold and clothes of fine silk 18:30-31; 22:23-24; 44:51-53
- trays of golden cups 43:67-73
- silver vessels and fruits hanging within reach 76:14-16
- reclining on thrones 15:47; 37:44; 52:20
- believers will see their Lord 75:22-23
Parents, kindness to, 2:83, 215; 4:36; 16:90;17:23; 29:8; 31:14; 46:15-17
Partners of Allah, a falsehood,4:116;10:34-35, 66; 16:86; 28:62-64, 71-75; 30:40;42:21
Pasturage, 87:4-5
Path, 5:77; 16:94; 42:52-53; 43:43; 90:11-12
- see also Way
Patience, 3:186, 200; 10:109; 11:115; 16:126-127; 20:130; 40:55, 77; 42:43; 46:35; 70:5;73:10
- seek help in, and prayer, 2:45, 153; 20:132;50:39
Patient
- will receive reward in full, 39:10
- Allah is with those who are, 8:46
- and be, 11:115
- in performing duties to Allah, 16:90
- to be, at the time of anger, 41:34
Peace, incline to, 8:61
Pearl and coral, preserved, 52:24; 55:22; 56:23
Pen, 68:1; 96:4
Person
- Allah burdens not a, beyond his scope,2:286; 7:42
- Allah tax not any, except according to his capacity, 23:62
- no, knows what he will earn tomorrow and in what land he will die, 31:34
- every, will be confronted with all the good and evil he has done 3:30
- every, will come up pleading for himself,16:111
- every, is a pledge for what he has earned,74:38
- Allah swears by the self-reproaching, 75:2
Pharaoh, 28:6; 40:24
- people of, 2:49; 3:11; 7:141; 44:17-33
- drowned, 2:50
- dealings with Moses, 7:103-137; 10:75-92
- dead body out from sea, 10:90-92
- transgressed beyond bounds; committed sins and disobeyed, 20:24; 69:9; 73:16;85:17-20; 89:10-14
- righteous wife, 28:8-9
- claims to be god, 28:38; 79:24
- destroyed, 29:39
- a believing man from Pharaoh's family,40:28-44
- building of a tower, 40:36-37
- see also Moses
Piling up of the worldly things, 102:1-4
Pledge (Bai'ah)
- for Islam, 16:91
- to the Messenger is Bai'ah (pledge) to Allah, 48:10
- of the Believers, 48:18; 60:12
Pledge (Mortgaging), let there be a, 2:283
- every person is a, for that which he has earned, 52:21; 74:38
Poetry, 36:69
Poets, 26:224-227; 69:41
Pomegranates, 6:141
Poor, 2:88, 177, 215, 273; 4:8, 36; 8:41; 9:60;17:26; 24:22, 32; 30:38; 47:38; 51:19; 59:7-8; 69:34; 74:44; 76:8; 89:18; 90:16; 93:8;107:3
Prayer, 1:1-7; 3:8, 26-27, 147, 191-194; 4:103;17:80; 23:118
- neither aloud nor in a low voice, 17:110
- invocation for disbelievers, 9:113-114
- invocation of disbelievers, 13:14
- He answers (the invocation of) those, 42:26
- seek help in patience and, 2:45, 153; 20:132;50:39
- perform Iqamat-as-Salat, facing towards Qiblah, 2:142-145, 149-150
- guard strictly the, 2:238
- in travel and attack, 2:239; 4:101-102
- approach not when in a drunken state, 4:43
- nor in a state of Janabah, 4:43
- purifying for, 4:43; 5:6
- when finished the, 4:103
- times of, 11:114; 17:78-79; 20:130; 30:17-18;50:39-40; 52:48-49; 73:1-6, 20
- prostration for Allah Alone, 13:15
Prayers, Friday, 62:9-11
Precautions in danger, 4:71
Prisoners of war, 8:67-71
- see also Captives
Promise of Truth, 46:16-17
Property, 2:188; 3:186; 4:5, 7, 29; 51:19; 59:7-9; 70:25
Prophets, 3:33-34, 146; 4:163; 5:20; 6:84-90;23:23-50; 57:26
- covenants of the, 3:81; 33:7-8
- illegal for, 3:161
- an enemy for every, 6:112; 25:31
- see also Messengers
Prostration
- to Allah falls in, whoever in the heavens and the earth and so do their shadows, 13:15
Provision, 10:59; 13:26; 14:32; 16:73; 34:36,39; 42:12; 51:57; 67:21; 79:33
Psalms, 4:163
Punishment
- postponing of, 3:178
- cutting of hands or feet, 5:33
- punish them with the like of that with which you were afflicted, 16:126
- of this life and Hereafter, 24:19; 68:33
Purifying
- bodily,4:43; 5:6
- spiritually (from impurities), 87:14; 91:9
Qadar, 5:5; 64:11
Qadr, S.97
Qaf, S.50
Qalam, S.68
Qamar, S.54
Qari'ah, S.101
Qarun (Korah), 28:76-82; 29:39
Qasas,S.28
Qiblah, 2:142-145, 149
Qisas (Law of equality in punishment), 2:178-179, 194; 5:45; 16:126; 17:33; 22:60;42:40
Quran
- described, 13:31, 36, 37; 14:1; 56:77-80
- is not such as could ever be produced by other than Allah, 2:23; 10:38; 11:13; 17:88
- had it been from other than Allah, therein have been much contradictions, 4:82
- a manifest light, 4:174; 42:52
- revealed, 6:19
- Allah is Witness to it, 6:19
- clear proof, 6:157
- false conversation about Verses of, 6:68
- a Reminder, 7:63; 12:104; 18:101; 20:3, 99, 124; 25:29; 36:11, 69; 43:44; 50:8; 65:10;72:17
- when recited, listen and be silent, 7:204
- Dhikr, 7:205; 15:6, 9
- Book of Wisdom, 10:1; 31:2; 36:2
- inspired Message, 10:2, 109; 42:52
- those reject it, 11:17
- in Arabic, 12:2; 13:37; 16:103; 20:113; 26:195;39:28; 41:3, 44; 42:7; 43:3; 44:58; 46:12
- made into parts, and revealed in stages, 15:91; 17:106; 25:32; 76:23
- change of a Verse, 16:10
- when you want to recite the, 16:98
- guides, 17:9
- glad tidings and warning, 17:9-10
- and the disbelievers, 17:45-47
- recitation in the early dawn is ever witnessed (by the angels), 17:78
- healing and mercy, 17:82
- fully explained to mankind, every kind of similitude and example, but most refuse,17:89; 18:54; 39:27
- easy, 19:97; 44:58; 54:17, 22, 32, 40
- my people deserted this Quran, 25:30
- confirmed by the Scriptures, 26:196
- narrates to the Children of Israel about which they differ, 27:76
- recite and pray, 29:45
- Truth from Allah, 32:3; 35:31
- on a blessed Night, 44:3
- therein is decreed every matter of ordainments, 44:4
- think deeply in the, 47:24
- warn by the, 50:45
- taught by Allah, 55:1
- and honourable recital, well-guarded, 56:77-78
- none can touch but who are pure, 56:79
- if sent down on a mountain, 59:21
- an anguish for the disbelievers, 69:50
- an absolute truth with certainty, 69:51
- recite in a slow style, 73:4
- in Records held in honour, kept pure and holy, 80:13-16
- a Reminder to (all) the 'Alamin, 81:27
- disbelievers belie, 84:22
- in Tablet preserved, 85:22
- Word that separates the truth from falsehood, 86:13
- reciting pure pages, 98:2
- see also Book; Revelation
Quraish, S.106
Quraish
- disbelievers of, 54:43-46, 51
- taming of, 106:1-4
Rabbis and monks, 9:31, 34
Race, strive as in a, in good deeds, 5:48
Ra'd, S.13
Rahman, S.55
Raiment of righteousness is better, 7:26
Rain
- Allah's Gift, 56:68-70
- of stones, 27:58
Ramadan, 2:185
Ramy, 2:200
Ransom
- no, shall be taken, 57:15
- offered by disbelievers, 3:91; 10:54; 13:18
Fidyah, of fast, 2:196
- for freeing the captives, 8:67
Rass, dwellers of the, 25:38; 50:12
Recompense
- the Day of, 1:4; 37:20; 51:12; 56:56; 82:17-18; 96:7
- deniers of, 107:1-7
- of an evil is an evil like thereof, 42:40
Reconciliation
- whoever forgives and makes, 42:40
- between man and wife, 4:35
- between believers, 49:9-10
Record
- a Register inscribed, 83:7-9, 18-21
- each nation will be called to its, 45:28-29
- written pages of deeds of every person,81:10
- which speaks the truth, 23:62
- in right hand, 69:19; 84:7-9
- in left hand, 69:25
- behind the back, 84:10-15
Recording angels, 50:17-18, 23; 85:11
Relief, with the hardship, 94:5-6
Religion
- no compulsion in, 2:256
- is Islam, 3:19
- of Allah, 3:83-84
- other than Islam, 3:85
- do not exceed the limits in, 4:171; 5:77
- perfected, 5:3
- who take, as play and amusement, 6:70
- who divide their, and break up into sects, 6:159; 30:32
- see also 42:13-14; 43:65; 45:17
- men have broken their, into sects, each group rejoicing in its belief, 23:53; 30:32
- not laid in, any hardship, 22:78
- mankind created on the, 30:30
- same, for all Prophets, 42:13-15
- ancestral, 43:22-24
Remembrance of Allah, 63:9
- in the, hearts find rest, 13:28
Repentance
- accepted if evil done in ignorance and repent soon afterwards, 4:17; 6:54
- and of no effect is the, if evil deeds are continued, 4:18
- He accepts, and forgives sins, 4:25
Respite for evil, 3:178; 10:11; 12:110; 14:42,44; 29:53-55; 86:15-17
Resurrection, 2:28, 7:53; 14:21; 16:38-40; 22:5-7; 23:15-16; 31:28, 41:39, 46:33-34; 50:3,20-29, 41-44; 64:7, 75:1-15; 79:10-12; 86:5-8
- example in the story of Ezra 2:259
- Abraham 2:260
- people of the cave 18:9-26
- warning to resurrection deniers 17:49-52, 17:97-100, 19:66-72, 37:11-27, 50:1-15, 80:17-42
Resurrection Day, 7:89; 20:100-101, 124
- the True Day, 78:39
- paid your wages in full 3:185
- written pages of deeds shall be laid open,81:11
- every person will know what he has brought, 81:14
- every person will be confronted with all the good and evil he has done, 3:30
- a person will know what he has sent forward and left behind, 82:5
- no fear of injustice, 20:112
- balances of justice, 21:47
- scales of deeds, 23:102-103
- whosoever does good or evil equal to the weight of an atom, shall see it, 100:7-8
- all the secrets will be examined, 86:9
Record given in right hand, 69:19; 84:7-9
Record given in left hand, 69:25
Record given behind back, 84:10-15
- hard day, for the disbelievers, 25:26; 54:8; 74:9
- a heavy day, 76:27
- bear a heavy burden, 20:100-101
- not permitted to put forth any excuse, 77:36
- wrong-doer will bite at his hands, 25:27
- wrong-doers assembled with their companions and idols, 37:22
- destruction with deep regrets, sorrows and despair, 30:12
- the female buried alive shall be questioned,81:8-9
- the greatest terror, 21:103
- the caller will call, to a terrible thing, 50:41;54:6-8
- a single (shout), 36:29, 49, 53; 38:15; 50:42
- Zajrah (shout), 37:19; 79:13
- a near torment, 78:40
- the heaven will shake with a dreadful shaking, 52:9; 56:4
- heaven is split asunder, 84:1-2
- heaven cleft asunder, 77:9; 82:1
- heaven shall be rent asunder with clouds,25:25
- heaven will be rolled up, in His Right Hand,21:104; 39:67
- all in heaven and on the earth will swoon away, 39:68
- heaven shall be opened, it will become as gates, 78:19
- sky will be like the boiling filth of oil, 70:8
- stars shall fall, 81:2; 82:2
- stars will lose their lights, 77:8
- sun will lose its light, 81:1
- seas shall become as blazing Fire, 81:6
- seas are burst forth, 82:3
- earthquake of the Hour, 22:1; 99:1
- mountains will move away, 18:47; 27:88;52:10; 77:9; 78:20; 81:3
- powdered to dust 20:105; 56:5
- like flakes of wool, 70:9;101:5
- earth and the mountains will be shaken violently, 73:14; 79:6
- earth is ground to powder, 89:21
- earth will be changed to another earth and so will be the heavens, 14:48
- earth is stretched forth, 84:3-5
- earth as a lavelled plain 18:47; 20:106
- earth throws out its burdens, 84:4; 99:2
- graves turned upside down, 82:4
- resurrection from the graves, 21:97; 70:43
- over the earth alive after death, 79:14
- wild beasts shall be gathered together, 81:5
- raised up blind, 20:124-125
- Trumpet will be blown, 6:73; 18:99; 20:102;23:101; 27:87; 36:51; 39:68; 50:20; 69:13;74:8; 78:18; 79:7
- Sakhkhah, 80:33
- the souls shall be joined with their bodies,81:7
- stay not longer than ten days, 20:103
- stay no longer than a day, 20:104
- or part of a day, 23:112-114
- Day of Gathering, 64:9
- Day of Judgement, 37:21
- Day of Decision, 77:38; 78:17
- Day of Sorting out, 77:13-14
- Day of Grief and Regrets, 19:39
- deniers of, 77:15-50
- mankind will be like moths scattered about,101:4
- mankind will proceed in scattered groups,100:6
- mankind as in a drunken state, 22:2
- every pregnant will drop her load, 22:2
- pregnant she-camels shall be neglected,81:4
- nursing mother will forget her nursling,22:2
- relatives shall be made to see one another,70:11
- a man shall flee from his relatives,80:34-37
- no friend will ask of a friend, 70:10
- there will be no friend nor an intercessor,40:18
- no person shall have power to do anything for another, 82:19
- will have no power, nor any helper, 87:10
- no fear on believers, 43:68
- believers will be amidst shades and springs, and fruits, 77:41-43
- dwellers of Paradise and their wives, 36:55-58
- angels will be sent down with a grand descending, 25:25
- Shin shall be laid bare, 68:42-43
- Paradise shall be brought near, 81:13
- Hell will be brought near, 89:23
- Hell-Fire shall be stripped off, kindled to fierce ablaze, 81:11-12
- Retaliation by way of charity will be an expiation, 5:45
Revelation
- if you are in doubt, 2:23-24
- abrogated or forgotten Verse, 2:106
- right guidance, 3:73
- from the Lord, so be not of those who doubt, 6:114
- for people who understand, 6:98
- a Guidance and a Mercy, 7:203; 16:64; 31:3
- through Ruh-ul-Qudus, 16:102; 26:192-193
- explained in detail, 6:98; 41:2-4
- of the Book is from Allah, 46:2
- see also Book and Quran
Revenge of oppressive wrong done to them, 42:39-43
Reward
- according to the best of deeds, and even more, 24:38; 29:7; 39:35
- as a reward 25:15
- Allah rewards those who do good, with what is best, 53:31
- for good, no reward other than good, 55:60
Riba (See usury)
Righteous
- company of the, 4:69
- shall inherit the land, 21:105
- in Paradise, 51:15-19; 76:5-12
- see also Good
Righteousness, 2:177, 207-208, 212; 3:16-17, 92, 133-135, 191-195; 4:36, 125; 5:93; 7:42-43; 16:97
- steep path of, 90:11-18
Right guidance is the Guidance of Allah,3:73
Roads, way, 43:10
Rocky Tract (Hijr), dwellers of, 15:80-85
Romans, 30:2-5
Roof, the heaven, 21:32
Ruh (Gabriel), 26:193; 67:12; 70:4; 78:38;97:4
Ruh-ul-Qudus, 2:87, 253; 5:110; 16:102
- see also Gabriel
Ruh (soul, spirit), 15:29; 17:85; 58:22
Rum, S.30
Saba' (Sheba), 27:22-44; 34:15-21
Saba', S.34
Sabbath
- transgressors of, 2:65; 4:154; 7:163-166
- prescribed only for, 16:124
Sabians, 5:69; 22:17
Sacrifice, 2:196, 200; 22:34-37
Sad, S.38
Sadaqah (Charity), 2:196, 263-264, 270-271, 273; 4:114; 9:60, 75-76, 79, 103-104; 57:18; 58:12-13
- concealing is better than showing, 2:271
Safa and Marwah, 2:158
Saff, S.61
Saffat, S.37
Sail Al-'Arim (flood released from Ma'rib Dam), 34:16
Sajdah, S.32
Sakinah (calmness and tranquillity), 2:248;9:26, 40; 48:4, 18, 26
Salih, 7:73-79; 11:61-68; 26:141-159; 27:45-53; 91:13
Salsabil (spring in Paradise), 76:18
Samiri, 20:85, 95-97
Samuel, 2:247
Satan, 2:36, 168, 208, 268, 275; 3:36, 155, 175;4:38, 60, 76, 83, 119-120; 5:80, 91; 6:43, 68,142; 7:20, 22, 27, 175, 200-201; 8:48; 16:63,98;20:120; 24:21; 25:29;27:24; 41:36;58:10, 19; 82:25
- excites enmity and hatred, 5:91
- evil whispers from, 7:200-201
- deceives, 8:48
- betrayed, 14:22
- has no power over believers, 16:99-100
- throws falsehood, 22:52-53
- is an enemy, 12:5; 35:6; 36:60
- arrogance 2:34; 7:11-27; 15:26-43; 17:61-65; 38:73-85
- a jinn 18:50-51
- Adam's temptation and fall 7:20-23; 20:116-121
- has no authority over the believers 16:98-100
- his goal 35:6-8
- a sworn enemy to humanity 12:5; 17:53
- his party 53:14-19
- his handiwork 5:90-91
- discourages good deeds 2:268
- believers seek refuge in Allah from him 7:200-202
- his schemes are weak 4:76
- lets his followers down 8:48
- talk to his followers in Hell 14:22
- see also Iblis
Scale, successful, whose will be heavy, 7:8-9
- see also balance
Scripture
- people of the, (Jews and Christians), 2:109;3:64-65, 69-72, 75, 98-99, 110, 113,199; 4:47, 153-161; 5:59-60, 68; 98:1
- what they were hiding, 5:61-63
- among them who are on the right course,5:66
- they recognise but not believe, 6:20
Seas, 42:32-33; 45:12
- the two, 18:60; 25:53; 35:12; 55:19-20
- when, are burst forth, 82:3
Secret (Najwa)
- talks, 4:114
- counsel of three, 58:7
- counsels, 58:8, 10
- private consultation, 58:12-13
Sects and divisions in religion, 6:15; 23:53;30:32; 42:13-14; 43:65; 45:17
Security, after the distress, He sent down,3:154
Seed, Who makes it grow, 56:63-67
Senses, 23:78
Seven, created
- heavens, 2:29; 23:17; 65:12; 67:3; 71:15
- and of the earth like there of, 65:12
Shadow
- to Allah falls in prostration, 13:15; 16:48
spread of, 25:45
Shams, S.91
She-camel as a clear sign to Thamud people, 7:73; 17:59; 26:155-158
Ship, sailing of, as a Sign; to be of service; to be grateful; to seek His Bounty, 2:164;14:32; 16:14; 17:66; 22:65; 31:31; 35:12;42:32-33; 43:12; 45:12; 55:24
Shu'aib, 7:85-93; 11:84-95; 29:36-37
Shu'ara, S.26
Shura, S.42
Sidrat-ul-Muntaha, 53:14
Siege of Al-Madinah, 33:9-27
Sijjin, 88:7-9
Sin, 7:100; 74:43-6
- illegal sexual intercourse, 4:15-16; 24:2, 19
- if greater, are avoided, small sins are remitted, 4:31
- they may hide from men, but cannot hide from Allah, 4:108
- whoever earns, he earns it only against himself, 4:111
- whoever earns a, and then throws on to someone innocent, 4:112
- Allah forgives not setting up partners in worship with Him, but forgives whom He pleases other sins than that, 4:116
- those who commit, will get due recompense,6:120
- sinners will never be successful, 10:17
- Allah forgives all, 39:53
- greater sins, 42:37
Sinai, Mount, 19:52; 23:20; 95:2
Sinners, their ears, eyes, and skins will testify against them, 41:20-23
Sirat Bridge, 66:8
Slanderer, 68:11-12; 104:1
Slaves, 2:177-178; 4:25, 36, 92; 5:89; 24:33; 58:3; 90:13
- see also Prisoners of war; Captives
Sleep, a thing for rest, 78:9
Sodom, 29:31; 37:136
Sodomy, 7:80-82; 11:77-83; 15:61-77; 29:28-29
Solomon, 2:102; 4:163; 6:84
- helps his father David reach a fairer judgment 21:78-82
- and the ants, 27:15-19
- and the hoopoe, 27:20-26
- and the Queen of Saba', 27:22-44; 34:15
- Allah's favours upon him 34:12-14, 38:34-40
- his love for fine horses 38:30-33
Son, adopted, 33:4-5
Soul (spirit, Ruh), 15:29; 17:85; 58:22
Spend, in Allah's Cause, 2:195, 215, 254, 262, 265, 267, 274; 3:92, 134; 8:3; 9:99; 13:22; 14:31;22:35; 32:16;35:29; 36:47; 47:38; 57:7;63:10; 64:16
- which is beyond your needs, 2:219
- likeness of those who, their wealth in the Way of Allah, 2:261
- to be seen of men, 2:264; 4:38
- whatever you, in Allah's cause, it will be repaid to you, 2:272; 8:60; 34:39
- not with extravagance, or wastefully, 6:141;17:26
- neither extravagant nor niggardly, 25:67
- who close hands from spending in Allah's Cause, 9:67
Spirit (soul, Ruh), 15:29
- its knowledge is with Allah, 17:85
- Allah strengthens believers with, 58:22
Spoils of war, 8:41, 69; 48:15, 19-20; 48:15
- see also Booty
Spying, 49:12
Star, 53:1, 49; 86:1-4
Stars, 7:54; 15:16; 16:12, 16; 22:18; 25:61;37:6-10; 56:75; 77:8; 81:2; 82:2
Straight, Way, 1:6
- etc. Path, 6:153
- etc. Striving, 4:95; 8:72, 74, 75; 9:20, 24, 81; 22:78; 25:52; 29:69:69; 47:3; 60:1; 61:11
Suckling, the term of, foster mother, 2:233
Suffering, poverty, loss of health and calamities; prosperity and wealth, 7:94-96
Sun, 7:54; 10:5; 14:32; 16:12; 22:18; 25:61;36:38, 40; 71:16; 81:1; 91:1
Supreme success, 9:72; 44:57
Surah, 10:38; 11:13; 47:20
- its revelation increases faith, 9:124-127
Suspicions, 49:12
Sustenance, 19:62
- see also Provision; Providence
Suwa', 71:23
Tabuk, 9:40-59, 81-99, 117-118, 120-122
Taghabun, S.64
Taghut, 2:256-257; 4:51-60, 76; 5:60; 16:36;17:39
- see alse false gods
Ta-Ha, S.20
Tahrim, S.66
Takathur, S.102
Takwir, S.81
Talaq, S.65
Talh (banana tree), 56:29
Talut (Saul), 2:247-249
Tariq, S.86
Tasnim (spring), 83:27-28
Taubah, S.9
Tawaf (going round the Ka'ba), 2:200; 7:29,31
Tayammum, 4:43; 5:6
Term, every nation has its appointed, no can anticipate nor delay it, 7:34; 10:49;15:4-5; 16:61; 20:129
Territory, guard your, by army units, 3:200
Test, by Allah, 3:154; 34:21
Thamud, 7:73-79; 11:61-68; 17:59; 25:38;26:141-159; 27:45-53; 29:38; 41:17; 51:43-45;54:23-31; 69:4-8; 85:17-20; 89:9-14;91:11-15
Thief, punishment, 5:38-39
Throne, 7:54, 58; 9:129; 10:3; 13:2; 20:5;23:86, 116; 32:4; 40:15; 57:4; 85:15
- on water, 11:7
- eight angels bearing the, 39:75; 40:7; 69:17
Time, 45:24; 76:1; 103:1
Tin, S.95
Torment,3:188; 6:15-16; 10:50-53; 11:10;13:34; 16:88; 46:20; 70:1-2
Township, never did We destroy a, but there was a known decree for it, 15:4
Trade and property, 4:29
Travel, have they not traveled through the earth, 6:11; 10:22; 12:109; 22:46; 27:69;29:20; 30:9, 42; 34:18; 35:44; 40:21, 82;47:10
Treachery, 8:58; 22:38
- see Betray
Treasure hoarded, 9:35
Treasures of Allah, 6:50
Tree of Eternity, 20:120
Trees, 22:18
Trials, 2:214-218; 64:15
Trumpet, on the Day of Resurrection, 6:73;18:99; 20:102; 23:101; 27:87; 36:51; 39:68;50:20; 69:13; 74:8; 78:18; 79:7
Sakhkhah,80:33
Trust offered to heavens, earth and mountains, but undertaken by man,33:72-73
Trusts (Amanah),2:283; 4:58; 8:27; 23:8;33:72; 70:32
Truth, 5:48; 23:70-71, 90; 25:33; 69:51
- mix not with falsehood nor conceal, 2:42
- has come and falsehood has vanished, 17:81
- promise of, 46:16-17
Tubba', people of, 44:37; 50:14
Tur (Mount), 28:29, 46
Tur, S.52
Tuwa, valley of, 20:12; 79:16
Uhud, battle of, 3:121-128, 140-180
Ummah (community, nation), 2:143-144;10:47, 49; 11:118; 16:36, 120
'Umrah, 2:128, 158, 196
Usury (Riba), 2:275-276, 278-280; 3:130;4:161; 30:39
'Uzair, (see Ezra)
'Uzza, 53:19
Veil, an invisible, 17:45-46
Veiling, 24:31; 33:59
Verses, Sab' Al-Mathani, 15:87
Victory
- given by Allah, 48:1
- through help from Allah, 61:13
Virtues, (see Righteousness; Believers)
Wadd, 71:23
- "Wait you, we too are waiting", 7:71; 9:52; 10:102; 11:122; 20:135; 44:59; 52:31
Waqi'ah, S.56
War against Allah, 5:33-34
Waste not by extravagance, 6:141; 7:31; 17:26
Water, every living thing made from, 21:30;24:45; 25:54
- two seas, 18:60; 25:53; 35:12; 55:19-20
- Allah's Throne on the, 11:7
- rain, 23:18
Way, the, 1:6; 42:52-53; 90:10
- etc. easy, make easy, 87:8
- see also Path
Wayfarer, 2:177, 215; 8:41; 17:26; 29:29;30:38; 59:7
Wealth
- who has gathered, 104:2-4
- spending in Allah's Cause (see Spend)
Wealth and children, adornment of the life of this world, 18:46
Weight and Measure, give full, 11:85; 17:35;83:1-5
Widows, 2:234-235, 240
Will of Allah, 10:99-100; 30:5; 81:29; 82:8
Will of man, to walk straight, unless Allah wills, 28:29
Winds, 77:1-3
- as heralds of glad tidings, 7:57; 30:46
- raising clouds, causing water, 15:22; 30:48
- turning yellow, 30:51
Wine (in Paradise)
- pure drinks, 37:45; 76:21
- white, delicious, 37:46
- rivers of, 47:15
- pure sealed, 83:25
Wish not for the things in which Allah has made some to excel others, 4:32
Witnesses
- to covenant of the Prophets, 3:81
- over mankind, 2:143; 22:78
- for a contract, 2:282
- two women against one man, 2:282
- to illegal sexual intercourse, 4:16; 24:2
- be just, 5:8
- hands and legs will bear witness, 36:65
- man against himself, 75:14
Witnessing Day and Witnessed Day, 85:3
Wives
- are a tilth for you, 2:223
- cover for you, 2:187
- of your own kind, 16:72
Woman, the disputing, 58:1-2
Women, 2:222-223; 4:15, 19-22, 34, 127
- who accuse chaste, 24:4-5, 11-17, 23-26
- veiling, 24:31; 33:59
- believing, as emigrants, 60:10-12
- not making clear herself in dispute, 43:17-18
Wood, dwellers of the, 15:78; 38:13; 50:14
- see also Aikah; Madyan 26:176-191
World, life of this
- is nothing but play and amusement, 6:32;29:64; 47:36; 57:20
- deceives men, 6:130
- little is the enjoyment of the, than the Hereafter, 9:38; 13:26; 28:60-61
- whoever desires, gets therein, but then there will be no portion in the Hereafter, 11:15-16; 17:18; 42:20
- wealth and children, adornment of the,18:46
- who love the present, and leave the Hereafter, 75:20-21; 76:27
Writing, for contracts, 2:282
Wrongdoers,11:18-22, 101-104, 116-117;39:47
- see also Disbelievers
Wudu' (Ablutions), 4:43; 5:6
Yaghuth, 71:23
Yahya (John)
- glad tidings of, 3:39; 21:90
- righteous, 6:85
- wise; sympathetic; dutiful, 19:12-15
Ya-Sin, S.36
Yathrib (Al-Madinah), people of, 33:13
Ya'uq, 71:23
Yunus (Jonah), S.10
Yusuf (Joseph), S.12
Zabur, 21:105
Zachariah (Zakariyya), 3:37-41; 6:85; 19:2-11; 21:89-90
Zaid Ibn Harithah, slave of the Prophet, 33:37-38
Zakat, 2:3, 43, 83, 110, 177, 277; 3:85; 4:77, 162; 5:12, 55; 6:141; 7:156; 9:5, 11, 18, 71;19:31, 55; 21:73; 22:41, 78; 23:4; 24:37, 56;27:3; 30:39; 31:4; 33:33; 41:7; 58:13; 73:20;98:5
- objects of Zakat and charity, 2:273; 9:60
Zanjabil, 76:17
Zalzalah, S.99
Zaqqum, 17:60; 37:62-66; 44:43-46; 56:52
Zihar, 33:4; 58:2-4
Zukhruf, S.43
Zumar, S.39
Basic tenets
- Faith perfected 5:3
- only Way accepted by Allah 3:19, 85
- no compulsion in accepting Islam 2:256
- one religion with different faiths and codes of law 5:48; 22:67-70; 42:13-14
- prophets of Islam 2:135-136; 3:84; 4:163-165
- commandments (have faith in Allah and do good) 4:36; 6:151-154;17:23-39;18:107-108
- five objectives of Sharia: protecting faith 5:54
- protecting life 5:32;6:151
- protecting wealth 5:38
- protecting honour 5:5;24:4
- protecting one's ability to think 5:90.
Belief in Allah 2:255
- Divine qualities, Beautiful Names 57:1-6; 59:22-24; 85:13-16; 112:1-4
- only god worthy of worship 1:1-4; 2:285; 6:3; 43:84
- all authority belongs to Him 3:26; His Throne ('Arsh) 7:54; 11:7
- His Kursi (footstool or chair) 2:255
- countless favours upon humanity 14:32-34; 2:164; 16:2-93; 31:20; 55:1-25
- gives life and causes death 44:8; 53:44; 57:2; 67:2
- brings about joy and sadness 53:43
- gives abundant or limited provisions 13:26; 17:30; 29:62
- Best of all judges 95:8
- Most Merciful of the merciful 12:92
- loves the righteous 85:14
- full of Forgiveness and severe in punishment 13:6, 40:3
- the First and Last 57:3
- all honour and power belongs to Him 35:10
- knows the unknown and sees the unseen 6:59,73; 9:94, 105; 13:8-10; 31:34; 32:6; 34:48; 35:38; 39:46; 49:18; 59:22; 62:8; 64:18; 72:26; 74:31; 87:7
- knows best what is hidden in the heart 5:7; 11:5; 31:23
- knows what happened and what yet to come 2:255
- wrote everything in the Record (or the Preserved Tablet) 6:38; 13:39; 36:12
- able to do anything 2:117; 3:189; 8:41; 9:116; 11:4; 16:40; 40:68; 41:39; 42:49;57:2
- His infinite power 3:26-27; 24:45; 31:28-30
- created the heavens and earth in six Days and never got tired 46:33; 50:38
- creates with the word ‘Be!’ 36:81-83
- never unjust to His creation 3:108; 4:40; 17:71; 21:47; 22:10; 26:209; 40:31; 41:46; 45:22; 50:29; 64:11; 78:6-16
- everything submits to His Will 3:83; 22:18; 30:26
- all stand in need of Him 11:6; 35:15; 55:29
- trust in Him 10:84-85; 12:67; 25:58
- forms of divine communication 42:51
- worthy to be mindful of 2:21; 3:102; 4:1; 33:70-71; 59:18
- wisdom is a gift from Him 2:269
- He is not in need of any one 3:97; 6:133; 112:2
- not one in a Trinity 4:171
- has no mate 6:101
- has no children 10:68; 19:35; 43:81; 72:3; 112:3
- has no partners or associate-gods 6:94; 7:191-195; 46:4-5
- nothing like Him 42:11; 112:4
Order to reflect on the marvels of His creation 3:190; 6:99; 10:5-6; 13:3-4; 16:10-16; 88:17-20
Signs in creation 2:164; 6:95-99; 7:57-58; 10:5-6; 13:2-4; 16:10-13, 65-69, 79; 23:27-30; 27:60-65; 30:19-25; 50:6-11
- created everything for a purpose 10:5-6; 15:85; 16:3; 23:115; 29:44; 30:8; 38:27; 44:38-39; 75:36
- universe perfected 67:3-4
- merges day into night 3:27
- diversity 30:22; 35:27-28
- honey 16:68-69
- milk 16:66
- gift of children 42:49-50
- planets and orbits 21:33; 36:38-44
- constellations 25:61; 85:1
- stars 37:6-7; 67:5
- clouds 7:57;30:48
- earthquake 7:78; 7:155
- landslide 28:81; 29:40
- storm 10:22
- drizzle, hail and rain 2:265; 6:99; 24:43; 50:9-11
- thunder and lightning 13:12-13
Scientific references
- humans created from male and female gametes 76:2
- formation and developmental phases of an embryo 22:5; 23:12-14
- fetus in three layers of darkness 39:6
- brackish water 25:53-54; 35:12; 55:19-20
- wind pollination 15:22
- fingerprints 75:3-4
- mountains as pegs 78:7
- iron sent down 57:25
- pain receptors 4:56
- the sun as a radiant source and the moon as a reflected light 10:5
- moon splitting 54:1
- sky as a well-protected canopy 21:32
- all beings created from water 21:30; 24:45
- ants communicate 27:17-19
- internal waves 24:40
Living beings
- angels 39:75
- humans (an authority on earth) 2:30; 6:165; 16:4
- jinn 72:1-15
- animals belong to communities like humans 6:38
- calf 11:69
- camel 7:40
- dog 18:22
- elephant 105:1
- horses, mules, and donkeys 16:8
- lion and zebras 74:50-51
- monkeys 2:65
- pigs 2:173
- she-camel 7:73
- sheep and goats 6:143
- wolf 12:17
- frogs 7:133
- snake 7:107
- birds 24:41
- crow 5:31
- hoopoe 27:20
- quails 2:57
- fish 18:61
- whale 37:142
- ants 27:18
- bees 16:68
- mosquito 2:26
- fly 22:73
- lice and locusts 7:133
- spider 29:41
- others unknown to us 16:8
Plants and fruits 6:99; 13:4; 16:11; 36:33-35
- bananas 56:29
- dates 19:25
- herbs, cucumbers, garlic, lentils, and onions 2:61
- grapes 80:28
- olives 6:99
- fig 95:1
- pomegranates 55:68
- squash 37:146
Belief in Muḥammad
- Qualities, only a prophet 3:144; 6:50; 7:188; 18:110
- to deliver the truth 2:119; 35:24; 42:48
- seal of prophets 33:40
- noble character 3:159; 68:4
- a role model 33:21
- as a favour to the believers 3:164
- a mercy to the whole world 21:107
- a universal messenger 4:170; 7:157-158; 34:28
- leads to the Straight Path 42:52-53
- cares about people 9:129
- as a witness on Judgment Day 4:42; 16:89
- unlettered prophet 7:157-158; 29:48; 62:2
- prophesied in the Torah and Gospel 7:157
- foretold by Jesus 61:6
Challenges faced by the Prophet ( ﷺ )
- pagans’ meaningless demands 8:32; 15:7; 17:89-93; 25:7-8
- false accusations 10:2; 11:13; 21:5; 24:11-26; 25:4-6; 37:36; 38:4; 52:29-30
- attempts on his life 8:30; 9:74
- warning to those who harm or oppose him 4:115; 8:13; 9:61; 15:95; 33:57; 47:32; 96:9-19
- ordered to respond to denial with patience 20:130; 30:60; 46:35; 70:5
- ordered reassured by Allah 5:67; 93:1-11; 94:1-8
Lessons from the life of the Prophet ( ﷺ )
- from his emigration ( hijrah ) to Battle of Badr 3:121-129; 8:42-44; 8:65-71
- Battle of Uhud 3:151-180
- Battle of the Trench 33:9-27
- Battle of Hunain 9:25-27
- Medina 9:40
- Tabuk 9:38-123
- Banu An-Naḍîr 59:2-6
- Hamra' Al-Asad 3:172-175
- Truce of Hudaibiyah 48:1-7; 48:10-29
Honours bestowed on the Prophet ( ﷺ )
- Allah and His angels bless him 33:56
- night journey from Mecca to Jerusalem 17:1
- journey to the heavens 53:1-18
- honoured in this life and the next 17:79; 66:8; 108:1
- obedience to him is obedience to Allah 4:80
- reward of obedience to Allah and His Messenger 4:69
- his family purified 33:33-34
- sees Gabriel in his true form 53:1-18
- believers ordered to obey him 59:7
- etiquette of speaking to him 49:1-5
- etiquette of visiting him 33:53
- etiquette of dealing with his wives 33:53
- Allah is pleased with him and his companions 9:100; 9:117
- excellence of his faith-community 2:143; 3:110
Prayer (salah) 2:45; 9:103; 51:18; 70:22-23; 75:31; 96:10; 108:2
- Friday congregation 62:9
- direction of prayer ( qiblah) 2:144; 2:149-150
- should deter one from evil deeds 29:45
- times 11:114; 17:78; 17:79; 20:130; 24:36; 24:58; 30:17-18; 32:16; 38:18; 50:39-40; 51:17; 52:48-49; 73:2-4; 76:25-26
- while in danger or on a journey 2:239; 4:101-102
- warning to those who neglect prayers 19:59; 74:38-47; 107:5-7
- hypocrites' prayers 4:142; 9:54
Purification, ablution (wudu) 5:6
- full bath (ghusl) 2:222; 4:43
- dry ablution (tayammum) 4:43; 5:6
Supplications (du'a)
- of Abraham 2:126-129; 2:126-129; 14:35-41; 26:83-89
- Adam and Eve 7:23
- Jesus 5:114
- Job 21:83; 21:83
- Jonah 21:87
- Joseph 12:33; 12:101
- Moses 10:88-89; 20:25-35
- Muhammad 17:80; 20:114
- Noah 23:26; 26:117-118; 54:9-10; 71:26; 71:28
- Solomon 38:35
- Shuaib 7:89
- Zachariah 3:38; 19:2-6; 21:89-90
- angels 40:8-9
- Mary's mother 3:35-36
- Pharaoh's wife 66:11
- Pharaoh's magicians 7:126
- King Saul and the believers with him 2:250
- the believers of the Children of Israel 10:85-86
- the people of the cave 18:10
- the righteous 2:285-286; 3:8-9; 3:16; 3:147; 3:191-194; 25:74; 59:10
- the oppressed 4:75
Prostration verses
- sajadat, plural of sajdah, 7:206; 13:15; 16:49; 17:109; 19:58; 22:18; 22:77; 25:60; 27:26; 32:15; 38:24; 41:37; 53:62; 84:21; 96:19
Alms-tax (zakah), as an obligation 2:110; 2:177; 2:277; 6:141
- one of the qualities of the believers 22:41; 23:4; 51:19
- recipients 9:60
- charity (sadaqah) 2:177; 2:261-263; 2:267-274; 3:92; 63:10
- warning to those who withhold 3:180; 9:34; 47:38
Fasting (sawm)
- in Ramadan 2:183-185
- hours of fasting 2:187
- exemptions 2:184-185
- intimate relations during the night preceding the fast 2:187
- fasting during pilgrimage 2:196
Pilgrimage (hajj)
- an obligation one those who can afford it 3:97
- rituals and rulings 2:158; 2:189; 2:196-203; 5:2; 22:26-37
- sacrificial offerings 2:196; 22:36-37
- prohibition of hunting on land while on pilgrimage 5:1; 5:94-95
- permissibility of hunting at sea 5:96
- Minor pilgrimage (’umrah) 2:158; 2:196
Faith-communities
- Muslims 2:132-136; 3:64; 3:84; 5:111; 22:77-78; 33:35; 41:33; 43:67-70; 72:14-15
- guardians of one another 3:28; 9:71
- Christians 2:62; 2:111-140; 4:171-172; 5:14-19; 5:82-86; 5:116-120; 9:30-31; 22:17
- Jews 2:62, 111-140; 5:44-45; 6:146; 22:17; 62:6-8
- Children of Israel 2:40-103, 122-123, 246-251; 3:49; 3:93-94; 5:12-13, 20-26, 32, 70-71, 78-81; 7:137-141, 148-153,159-171; 10:83-93; 14:5-8; 17:2-8, 104; 20:80-98; 26:52-67, 197; 27:76; 44:23-33; 45:16-17; 46:10; 61:5-6
- People of the Book (mainly Jews and Christians) 2:109; 3:64-115, 199; 4:123-172; 5:15-77; 6:20-21; 13:36; 28:52-55; 29:46-47; 57:16, 28-29; 74:31; 98:1-5
- Muslims can eat from animals sacrificed by them and marry their women 5:5
- foods forbidden to Jews 6:146
- Sabians 2:62; 22:17
- Magi 22:17
- polytheists (pagans, idol worshippers) 3:186; 6:148; 9:6, 17; 10:28; 16:86; 22:17; 53:19-30
- pagan superstitious practices 2:189; 5:103; 6:138-144
- atheists 52:35-36
Pagan practices outlawed
- burying daughters alive 16:58-59; 81:8-9
- killing children for fear of poverty 6:137; 6:151; 17:31
- whistling and clapping around the Ka'bah 8:35
- dedicating camels to idols 5:103; 6:136
- sacrificing in the name of idols 6:121
- zihar divorce 33:4; 58:2-4
- ila' (for more than four months) 2:226-227
- drawing lots for decisions 5:3
- circling the Ka'bah while naked 7:26-28
- entering homes from backdoors after pilgrimage 2:189
Objects of worship
- angels (among some pagan Arabs) 34:40
- Al-Aykah (among the people of Shu'aib) 26:176
- Ba'l (among the people of Elias 37:125
- Jesus (in Christianity) 5:17
- idols (among the people of Abraham) 21:52-53
- the idols of Lat, 'Uzza, and Manat (among Arab pagans) 53:19-20
- the idols of Wadd, Suwa', Yaghuth, Ya'uq, and Nasr (among the people of Noah) 71:23
- the sun (the people of Sheba) 27:24
- Sirius (among some pagan Arabs) 53:49
- Pharaoh (in ancient Egypt) 26:29; 28:38; 79:24
- desires 25:43-44; 45:23
- belief in multiple gods refuted 17:42-43; 21:21-24; 25:3
Places of worship, mosques 9:18
- churches, synagogues, and monasteries 22:40
- sanctuary 3:39; 38:21
- temple 17:7
- Religious titles, priests, monks, and rabbis 5:44; 5:63; 5:82; 9:31-34
Angels
- inquire about the creation of Adam 2:30-34
- never disobey Allah 21:26-27; 66:6
- are not the daughters of Allah 21:26; 43:16-19
- guarding angels 13:11
- two recording angels 50:16-18; 82:10-12
- eight carrying Allah's Throne on Judgment Day 69:17
- nineteen keepers of Hell 74:26-31
- Angels of Death 6:93; 16:28; 32:11
- Gabriel 2:97; 66:4; 26:192-195; 53:1-14
- Michael 2:98
- Malik 43:77
Messengers
- from among angels and humans 22:75
- Messengers of Firm Resolve (Abraham, Noah, Moses, Jesus, and Muhammad ﷺ ) 33:7; 42:13; 46:35
Scriptures
- Quran, a revelation from Allah 12:2-3; 20:2-4; 26:192-195; 32:2-3
- a reminder to the whole world 68:51-52
- guides to the most upright way of life 17:9
- revelation started in the month of Ramadân 2:185
- on a blessed night 44:3;97:1-5
- revealed in stages 17:105-106
- made easy to remember 54:17
- confirms the truth in previous revelations 3:3-4
- a supreme authority on earlier scriptures 5:48
- no doubt in it 2:2; 10:37
- no contradictions 4:82
- not fabricated 10:37-39
- not copied from the Bible 25:4-6
- not revealed by devils 26:210-212
- no one can produce something like it 17:88; 2:23-24;10:13-14; 11:13
- protected from corruption 15:9
- protected in the Preserved Tablet 56:75-80
- cannot be proven false 41:42
- foretells future events 30:1-7; 48:27
- moves the believers to tears 5:83; 17:107-109
- touches hearts 39:23
- brilliant light 4:174; 42:52
- healing and mercy for the believers 17:82
- Torah 3:3; 3:93; 5:46; 5:66-68, 110; 7:157; 9:111; 48:29; 61:6; 62:5
- Gospel 3:3, 48; 5:46-47, 66-68, 77, 110; 7:157; 9:111; 48:29; 57:27
- Psalms 4:163; 17:55
- Scrolls of Abraham 53:36-44; 87:14-19
Fate and destiny 3:145; 9:51; 10:107; 11:6; 54:49; 67:30
- free choice 6:148-150; 11:118-119; 16:93; 33:72-73; 39:41; 76:1-3; 91:1-10
Day of Judgment
- no injustice 2:281; 18:49; 40:17
- horrors of the apocalypse 22:1-2; 27:82-84, 87; 40:18; 52:11-16; 69:13-18; 70:8-18; 73:17-18; 75:7-15; 77:8-15; 78:17-20; 79:34-36; 80:33-42; 81:1-14; 82:1-5; 84:1-5; 87:17-40; 99:1-8; 101:1-11
- the righteous and the wicked on that Day 11:105-108; 16:27-33, 84-89; 18:52-53; 20:100-111; 25:24-29; 30:12-16; 33:63-68; 39:68-75; 50:20-35; 55:37-41; 83:4-36
- intercession (shafa'ah) 2:48, 255; 6:51, 70; 10:3; 21:28; 32:4; 36:23; 39:43-44; 43:86; 53:26;74:48
Records of deeds 17:13; 18:49
- believers receive their record with their right hand 69:19-24; 84:7-9
- disbelievers receive their record with their left hand 69:25-37; 84:10-15
- nothing will be hidden from Allah 21:47; 40:16
- weighing of deeds 7:8; 23:102-104; 101:1-11
- testimony of bodily organs 41:19-24; 24:24
- reward for good and evil deeds 6:160; 27:89-90; 28:84
Types of people
- believers 18:107-108
- disbelievers 4:167-169
- hypocrites 4:145; 57:13-15
- residents of Paradise, foremost believers 55:46-61; 56:10-26
- residents of Paradise, people of the right 55:62-78; 56:27-40
- residents of Hell, people of the left 55:31-45; 56:41-56
- people on the heights 7:46-49
Financial
- Business guidelines 2:188; 2:275; 2:282-283; 4:29; 4:58; 6:152; 17:34-35; 24:36-37; 26:182; 30:39; 55:7-9; 62:9
- Bequests , optional bequests to non-heirs 2:180-183; 4:11-12
before death while on a journey 5:106-108
- Bribery 2:188
- Debts, kindness in collecting debts 2:280
- writing and witnessing a debt contract 2:282
- taking collateral 2:283
- Inheritance, guidelines 4:7; 4:32-33; 8:75
- shares of offspring and parents 4:11
- spouses and maternal siblings 4:12
- full siblings 4:176
- warning to those who don't comply 4:13-14
- Interest, prohibition and warning 2:275-281; 3:130-132
- rendered profitless 30:39
Legal
- treason law (hirabah) 5:33-34
- Justice, standing up for justice 4:135; 5:8; 16:90-91
- standing up for the rights of orphans and women 4:127
- justice to a Jew 4:105-112
- justice to a pagan 4:58
- fairness with non-Muslims 60:8-9
- Retaliation through legal channels (with the option to forgive) 2:178-179; 5:45; 16:126; 17:33; 42:37-43
- Separation between husband and wife, khul' 2:229
- lian (accuse of adultery) 24:6-10
Political
- Conducting affairs by consultation (shura) 3:159; 42:38
- Fighting in self-defence (jihad), etiquette 2:190-192; 2:216; 22:38-40
- not to attack indiscriminately 4:94
- fighting for oppressed men, women, and children 4:75
- protecting places of worship 22:37
- reward of martyrs 2:154; 3:169-171; 9:111; 57:19
- military might deters potential enemies 8:60
- opting for peace 2:192; 8:61
- Making peace between parties 49:9-10
- Prisoners of war, treatment 8:70; 47:4; 76:8
Social
- Adoption 33:4-5
- Caring for orphans 2:220; 4:2-10; 4:127; 6:152; 17:34
- Divorce, arbitration and reconciliation 4:35; 4:128
- etiquette of divorce 2:229-231; 65:1-2
- dowry and waiting period 2:226-241; 4:19-21; 33:49; 65:1-7
- husband not to take back anything of the dowry 4:20
- wife not be harassed 65:6
- wife to be supported financially during pregnancy 65:6
- during her waiting period 65:6
- if she nurses ex-husband's child, 65:6
- no parent should suffer because of their child 2:233
- opting for wet-nurse 65:6
- Encouraging good and forbidding evil 3:104; 3:110; 7:157; 9:71-72; 31:17
- Equity of human beings 49:13
- men and women before Allah and the law, 3:195; 4:124; 5:38; 16:97; 24:2; 40:40
- men have a degree of responsibility above women 2:228
- Feeding the poor, orphans, and captives 76:8-9
- Forgiveness and anger control 3:134; 42:40
- Freeing slaves and helping them 4:92; 5:89; 9:60; 24:33; 58:3; 90:13
- Honouring one's own parents 4:36; 17:23-25; 31:14-15
- Humility 17:37; 31:18-19
- Interpretation of dreams of Abraham 37:102
- Interpretation of dreams of Joseph 12:4; 12:36; 12:43
- Interpretation of dreams of Muhammad 8:43; 48:27
- Kindness to non-Muslims 60:8
- Marriage 4:3; 4:129; 16:72; 30:21
- lawful and unlawful women to marry 4:22-24
- etiquette of intimacy 2:222-223
- pregnancy and nursing 2:233; 31:4; 46:15; 65:6
- remarrying one's own ex-wife 2:230
- helping singles to marry 24:32
- subtly showing interest during the waiting period 2:235
- Oaths 2:224-225; 16:91-92; 16:94
- making up for a broken oath 5:89
- Patience in difficult times 2:45; 2:153-157; 3:186; 12:18; 12:83; 16:127-128; 70:5
- Permission to come in 24:58-60
- entering people's homes 24:27-28
- entering public places 24:29
- Social etiquette, verifying news 4:83; 49:6
- respect for all 49:11-12
- etiquette of gatherings 58:11
- private talks 4:114; 58:9
- Vows 2:270; 9:75-77; 22:29; 76:7
- Wasting and stinginess 7:31; 17:29; 25:67
Other stories
- Abel and Cain 5:27-31
- Al-Khadir and Moses 18:60-82
- Army of the Elephant 105:1-4
- the believer from Pharaoh's people 40:28-46
- birth of Mary 3:35-36
- Cow of the Children of Israel 2:67-74
- Ezra 2:259
- garden owners 68:17-32
- Harut and Marut 2:102
- Korah 28:76-82
- Luqman's advice to his son 31:12-19
- owner of the two gardens 18:32-44
- people of Sheba 34:15-19
- people of the cave 18:9-26
- people of the trench 85:1-8
- Sabbath-breakers 7:163-165
- Samiri and the Golden Calf 20:83-97
- Saul and Samuel 2:247-251
- Zul-Qarnain 18:83-98
Devils 2:102; 6:71; 6:112; 6:121; 7:27; 7:30; 17:27; 19:68; 19:83; 22:3-4; 23:97-98; 26:210; 37:7-10; 38:37-38; 67:5
- devilish humans and jinn 6:112;114:6
- heaven protected against devils 15:16-18
Regrets
- not following the Prophet 25:27
- not obeying Allah and His Messenger 4:41-42; 33:64-68
- taking evil friends 25:28-29; 26:96-102; 43:36-39
- denying Allah's signs 6:27-30
- not working for the Hereafter 89:23-24
Desperate pleas
- begging for return to the world 2:167; 6:27-28; 32:12-14; 42:44
- for a second chance 35:36-37
- to be removed from the Fire 40:10-12
- for food and water 7:51-52
- for intercessors 7:52-53
- to be leveled to dust 4:41-42; 78:40
- for death 43:74-78
Qualities of the righteous
- observing the rights of the Creator and His creation 3:133-136; 4:36; 4:69-70; 6:151-154; 8:2-4; 13:19-24; 17:23-39;18:107-108; 23:1-11; 25:63-76; 42:36-43
Qualities of the wicked
- ungrateful 14:34
- stingy 17:100
- hasty 21:37
- remember Allah only in difficult times 10:12; 41:51
- impatient 70:19
- argumentative 18:54
Major Sins
- associating others with Allah in worship (shirk) 4:48; 4:116; 5:72; 6:19; 31:13
- abusing one's own parents 4:36; 6:151; 17:23
- neglecting or abandoning obligatory prayers 19:59-60
- not paying alms-tax 41:6-7
- murder 6:151; 17:33
- killing a believer intentionally 4:93
- theft 5:38
- fraud 7:85; 11:85; 26:182-183; 83:1-6
- lying 2:10; 9:77; 39:60
- lying about Allah 6:93; 29:68; 61:7
- prohibited sexual relations 2:222; 17:32; 24:2; 25:68; 29:28-30
- false accusations of adultery 24:4-5
- apostasy 2:217; 5:54
- eating swine and other forbidden foods (carrion, blood, etc.) 5:3; 6:145
- alcohol and gambling 5:90-91
- backbiting 49:11
- false testimony 22:30
- magic 2:102; 10:77; 20:69
Islamic months
- 1st Muharram sacred month; fast 9th (Tasu'a) and 10th (Ashura) sunnah 9:36
- 2nd Safar
- 3rd Rabi al-Awwal
- 4th Rabi al-Thani
- 5th Jumada al-Awwal
- 6th Jumada al-Thani
- 7th Rajab sacred month
- 8th Sha'ban fast most of month (sunnah)
- 9th Ramadan obligatory fasting; Laylat al-Qadr 2:183-185, 187; 97:1-5
- 10th Shawwal Eid al-Fitr (1st); six days sunnah fasting
- 11th Dhul Qa'dah sacred month
- 12th Dhul Hijjah best ten days of year; fast first 9 days (sunnah); Day of Arafah (9th); Eid al-Adha (10th) forbidden to fast; Ayyam al-Tashriq (11th-13th) forbidden to fast 2:196-203; 22:27-28
- Fast Mondays and Thursdays (sunnah)
- Fast white days 13th, 14th, 15th every month (Ayyam al-Bid)
- Hajj during Shawwal, Dhul Qaa'dah and 10 days of Dhul Hijjah of Dhul Hijjah 2:197
Juz
- Juz 1 1:1-7; 2:1-141
- Juz 2 2:142-252
- Juz 3 2:253-286; 3:1-92
- Juz 4 3:93-200; 4:1-23
- Juz 5 4:24-147
- Juz 6 4:148-176; 5:1-81
- Juz 7 5:82-120; 6:1-110
- Juz 8 6:111-165; 7:1-87
- Juz 9 7:88-206; 8:1-40
- Juz 10 8:41-75; 9:1-92
- Juz 11 9:93-129; 10:1-109; 11:1-5
- Juz 12 11:6-123; 12:1-52
- Juz 13 12:53-111; 13:1-43; 14:1-52
- Juz 14 15:1-99; 16:1-128
- Juz 15 17:1-111; 18:1-74
- Juz 16 18:75-110; 19:1-98; 20:1-135
- Juz 17 21:1-112; 22:1-78
- Juz 18 23:1-118; 24:1-64; 25:1-20
- Juz 19 25:21-77; 26:1-227; 27:1-55
- Juz 20 27:56-93; 28:1-88; 29:1-45
- Juz 21 29:46-69; 30:1-60; 31:1-34; 32:1-30; 33:1-30
- Juz 22 33:31-73; 34:1-54; 35:1-45; 36:1-27
- Juz 23 36:28-83; 37:1-182; 38:1-88; 39:1-31
- Juz 24 39:32-75; 40:1-85; 41:1-46
- Juz 25 41:47-54; 42:1-53; 43:1-89; 44:1-59; 45:1-37
- Juz 26 46:1-35; 47:1-38; 48:1-29; 49:1-18; 50:1-45; 51:1-30
- Juz 27 51:31-60; 52:1-49; 53:1-62; 54:1-55; 55:1-78; 56:1-96; 57:1-29
- Juz 28 58:1-22; 59:1-24; 60:1-13; 61:1-14; 62:1-11; 63:1-11; 64:1-18; 65:1-12; 66:1-12
- Juz 29 67:1-30; 68:1-52; 69:1-52; 70:1-44; 71:1-28; 72:1-28; 73:1-20; 74:1-56; 75:1-40; 76:1-31; 77:1-50
- Juz 30 78:1-40; 79:1-46; 80:1-42; 81:1-29; 82:1-19; 83:1-36; 84:1-25; 85:1-22; 86:1-17; 87:1-19; 88:1-26; 89:1-30; 90:1-20; 91:1-15; 92:1-21; 93:1-11; 94:1-8; 95:1-8; 96:1-19; 97:1-5; 98:1-8; 99:1-8; 100:1-11; 101:1-11; 102:1-8; 103:1-3; 104:1-9; 105:1-5; 106:1-4; 107:1-7; 108:1-3; 109:1-6; 110:1-3; 111:1-5; 112:1-4; 113:1-5; 114:1-6
Hizb (1/2)
- Hizb 1 1:1-7; 2:1-74
- Hizb 2 2:75-141
- Hizb 3 2:142-202
- Hizb 4 2:203-252
- Hizb 5 2:253-286; 3:1-14
- Hizb 6 3:15-92
- Hizb 7 3:93-170
- Hizb 8 3:171-200; 4:1-23
- Hizb 9 4:24-87
- Hizb 10 4:88-147
- Hizb 11 4:148-176; 5:1-26
- Hizb 12 5:27-81
- Hizb 13 5:82-120; 6:1-35
- Hizb 14 6:36-110
- Hizb 15 6:111-165
- Hizb 16 7:1-87
- Hizb 17 7:88-170
- Hizb 18 7:171-206; 8:1-40
- Hizb 19 8:41-75; 9:1-33
- Hizb 20 9:34-92
- Hizb 21 9:93-129; 10:1-25
- Hizb 22 10:26-109; 11:1-5
- Hizb 23 11:6-83
- Hizb 24 11:84-123; 12:1-52
- Hizb 25 12:53-111; 13:1-18
- Hizb 26 13:19-43; 14:1-52
- Hizb 27 15:1-99; 16:1-50
- Hizb 28 16:51-128
- Hizb 29 17:1-98
- Hizb 30 17:99-111; 18:1-74
- Hizb 31 18:75-110; 19:1-98
- Hizb 32 20:1-135
- Hizb 33 21:1-112
- Hizb 34 22:1-78
- Hizb 35 23:1-88; 24:1-20
- Hizb 36 24:21-64; 25:1-20
- Hizb 37 25:21-77; 26:1-110
- Hizb 38 26:111-227; 27:1-55
- Hizb 39 27:56-93; 28:1-50
- Hizb 40 28:51-88; 29:1-45
- Hizb 41 29:46-69; 30:1-60; 31:1-21
- Hizb 42 31:22-34; 32:1-30; 33:1-30
- Hizb 43 33:31-73; 34:1-23
- Hizb 44 34:24-54; 35:1-45; 36:1-27
- Hizb 45 36:28-83; 37:1-144
- Hizb 46 37:145-182; 38:1-88; 39:1-31
- Hizb 47 39:32-75; 40:1-40
- Hizb 48 40:41-85; 41:1-46
- Hizb 49 41:47-54; 42:1-53; 43:1-23
- Hizb 50 43:24-89; 44:1-59; 45:1-37
- Hizb 51 46:1-35; 47:1-38; 48:1-17
- Hizb 52 48:18-29; 49:1-18; 50:1-30
- Hizb 53 50:31-45; 51:1-60; 52:1-49; 53:1-62; 54:1-55
- Hizb 54 55:1-78; 56:1-96; 57:1-29
- Hizb 55 58:1-22; 59:1-24; 60:1-13; 61:1-14
- Hizb 56 62:1-11; 63:1-11; 64:1-18; 65:1-12; 66:1-12
- Hizb 57 67:1-30; 68:1-52; 69:1-52; 70:1-44; 71:1-28
- Hizb 58 72:1-28; 73:1-20; 74:1-56; 75:1-40; 76:1-31; 77:1-50
- Hizb 59 78:1-40; 79:1-46; 80:1-42; 81:1-29; 82:1-19; 83:1-36
- Hizb 60 84:1-25; 85:1-22; 86:1-17; 87:1-19; 88:1-26; 89:1-30; 90:1-20; 91:1-15; 92:1-21; 93:1-11; 94:1-8; 95:1-8; 96:1-19; 97:1-5; 98:1-8; 99:1-8; 100:1-11; 101:1-11; 102:1-8; 103:1-3; 104:1-9; 105:1-5; 106:1-4; 107:1-7; 108:1-3; 109:1-6; 110:1-3; 111:1-5; 112:1-4; 113:1-5; 114:1-6
Rub (1/8)
- Rub 1 1:1-7; 2:1-25
- Rub 2 2:26-43
- Rub 3 2:44-59
- Rub 4 2:60-74
- Rub 5 2:75-91
- Rub 6 2:92-105
- Rub 7 2:106-123
- Rub 8 2:124-141
- Rub 9 2:142-157
- Rub 10 2:158-176
- Rub 11 2:177-188
- Rub 12 2:189-202
- Rub 13 2:203-218
- Rub 14 2:219-232
- Rub 15 2:233-242
- Rub 16 2:243-252
- Rub 17 2:253-262
- Rub 18 2:263-271
- Rub 19 2:272-282
- Rub 20 2:283-286; 3:1-14
- Rub 21 3:15-32
- Rub 22 3:33-51
- Rub 23 3:52-74
- Rub 24 3:75-92
- Rub 25 3:93-112
- Rub 26 3:113-132
- Rub 27 3:133-152
- Rub 28 3:153-170
- Rub 29 3:171-185
- Rub 30 3:186-200
- Rub 31 4:1-11
- Rub 32 4:12-23
- Rub 33 4:24-35
- Rub 34 4:36-57
- Rub 35 4:58-73
- Rub 36 4:74-87
- Rub 37 4:88-99
- Rub 38 4:100-113
- Rub 39 4:114-134
- Rub 40 4:135-147
- Rub 41 4:148-162
- Rub 42 4:163-176
- Rub 43 5:1-11
- Rub 44 5:12-26
- Rub 45 5:27-40
- Rub 46 5:41-50
- Rub 47 5:51-66
- Rub 48 5:67-81
- Rub 49 5:82-96
- Rub 50 5:97-108
- Rub 51 5:109-120; 6:1-12
- Rub 52 6:13-35
- Rub 53 6:36-58
- Rub 54 6:59-73
- Rub 55 6:74-94
- Rub 56 6:95-110
- Rub 57 6:111-126
- Rub 58 6:127-140
- Rub 59 6:141-150
- Rub 60 6:151-165
- Rub 61 7:1-30
- Rub 62 7:31-46
- Rub 63 7:47-64
- Rub 64 7:65-87
- Rub 65 7:88-116
- Rub 66 7:117-141
- Rub 67 7:142-155
- Rub 68 7:156-170
- Rub 69 7:171-188
- Rub 70 7:189-206
- Rub 71 8:1-21
- Rub 72 8:22-40
- Rub 73 8:41-60
- Rub 74 8:61-75
- Rub 75 9:1-18
- Rub 76 9:19-33
- Rub 77 9:34-45
- Rub 78 9:46-59
- Rub 79 9:60-74
- Rub 80 9:75-92
- Rub 81 9:93-110
- Rub 82 9:111-121
- Rub 83 9:122-129; 10:1-10
- Rub 84 10:11-25
- Rub 85 10:26-52
- Rub 86 10:53-70
- Rub 87 10:71-89
- Rub 88 10:90-109; 11:1-5
- Rub 89 11:6-23
- Rub 90 11:24-40
- Rub 91 11:41-60
- Rub 92 11:61-83
- Rub 93 11:84-107
- Rub 94 11:108-123; 12:1-6
- Rub 95 12:7-29
- Rub 96 12:30-52
- Rub 97 12:53-76
- Rub 98 12:77-100
- Rub 99 12:101-111; 13:1-4
- Rub 100 13:5-18
- Rub 101 13:19-34
- Rub 102 13:35-43; 14:1-9
- Rub 103 14:10-27
- Rub 104 14:28-52
- Rub 105 15:1-48
- Rub 106 15:49-99
- Rub 107 16:1-29
- Rub 108 16:30-50
- Rub 109 16:51-74
- Rub 110 16:75-89
- Rub 111 16:90-110
- Rub 112 16:111-128
- Rub 113 17:1-22
- Rub 114 17:23-49
- Rub 115 17:50-69
- Rub 116 17:70-98
- Rub 117 17:99-111; 18:1-16
- Rub 118 18:17-31
- Rub 119 18:32-50
- Rub 120 18:51-74
- Rub 121 18:75-98
- Rub 122 18:99-110; 19:1-21
- Rub 123 19:22-58
- Rub 124 19:59-98
- Rub 125 20:1-54
- Rub 126 20:55-82
- Rub 127 20:83-110
- Rub 128 20:111-135
- Rub 129 21:1-28
- Rub 130 21:29-50
- Rub 131 21:51-82
- Rub 132 21:83-112
- Rub 133 22:1-18
- Rub 134 22:19-37
- Rub 135 22:38-59
- Rub 136 22:60-78
- Rub 137 23:1-35
- Rub 138 23:36-74
- Rub 139 23:75-118
- Rub 140 24:1-20
- Rub 141 24:21-34
- Rub 142 24:35-52
- Rub 143 24:53-64
- Rub 144 25:1-20
- Rub 145 25:21-52
- Rub 146 25:53-77
- Rub 147 26:1-51
- Rub 148 26:52-110
- Rub 149 26:111-180
- Rub 150 26:181-227
- Rub 151 27:1-26
- Rub 152 27:27-55
- Rub 153 27:56-81
- Rub 154 27:82-93; 28:1-11
- Rub 155 28:12-28
- Rub 156 28:29-50
- Rub 157 28:51-75
- Rub 158 28:76-88
- Rub 159 29:1-25
- Rub 160 29:26-45
- Rub 161 29:46-69
- Rub 162 30:1-30
- Rub 163 30:31-53
- Rub 164 30:54-60; 31:1-21
- Rub 165 31:22-34; 32:1-10
- Rub 166 32:11-30
- Rub 167 33:1-17
- Rub 168 33:18-30
- Rub 169 33:31-50
- Rub 170 33:51-59
- Rub 171 33:60-73; 34:1-9
- Rub 172 34:10-23
- Rub 173 34:24-45
- Rub 174 34:46-54; 35:1-14
- Rub 175 35:15-40
- Rub 176 35:41-45; 36:1-27
- Rub 177 36:28-59
- Rub 178 36:60-83; 37:1-21
- Rub 179 37:22-82
- Rub 180 37:83-144
- Rub 181 37:145-182; 38:1-20
- Rub 182 38:21-51
- Rub 183 38:52-88; 39:1-7
- Rub 184 39:8-31
- Rub 185 39:32-52
- Rub 186 39:53-75
- Rub 187 40:1-20
- Rub 188 40:21-40
- Rub 189 40:41-65
- Rub 190 40:66-85; 41:1-8
- Rub 191 41:9-24
- Rub 192 41:25-46
- Rub 193 41:47-54; 42:1-12
- Rub 194 42:13-26
- Rub 195 42:27-50
- Rub 196 42:51-53; 43:1-23
- Rub 197 43:24-56
- Rub 198 43:57-89; 44:1-16
- Rub 199 44:17-59; 45:1-11
- Rub 200 45:12-37
- Rub 201 46:1-20
- Rub 202 46:21-35; 47:1-9
- Rub 203 47:10-32
- Rub 204 47:33-38; 48:1-17
- Rub 205 48:18-29
- Rub 206 49:1-13
- Rub 207 49:14-18; 50:1-26
- Rub 208 50:27-45; 51:1-30
- Rub 209 51:31-60; 52:1-23
- Rub 210 52:24-49; 53:1-25
- Rub 211 53:26-62; 54:1-8
- Rub 212 54:9-55
- Rub 213 55:1-78
- Rub 214 56:1-74
- Rub 215 56:75-96; 57:1-15
- Rub 216 57:16-29
- Rub 217 58:1-13
- Rub 218 58:14-22; 59:1-10
- Rub 219 59:11-24; 60:1-6
- Rub 220 60:7-13; 61:1-14
- Rub 221 62:1-11; 63:1-3
- Rub 222 63:4-11; 64:1-18
- Rub 223 65:1-12
- Rub 224 66:1-12
- Rub 225 67:1-30
- Rub 226 68:1-52
- Rub 227 69:1-52; 70:1-18
- Rub 228 70:19-44; 71:1-28
- Rub 229 72:1-28; 73:1-19
- Rub 230 73:20; 74:1-56
- Rub 231 75:1-40; 76:1-18
- Rub 232 76:19-31; 77:1-50
- Rub 233 78:1-40; 79:1-46
- Rub 234 80:1-42; 81:1-29
- Rub 235 82:1-19; 83:1-36
- Rub 236 84:1-25; 85:1-22; 86:1-17
- Rub 237 87:1-19; 88:1-26; 89:1-30
- Rub 238 90:1-20; 91:1-15; 92:1-21; 93:1-11
- Rub 239 94:1-8; 95:1-8; 96:1-19; 97:1-5; 98:1-8; 99:1-8; 100:1-8
- Rub 240 100:9-11; 101:1-11; 102:1-8; 103:1-3; 104:1-9; 105:1-5; 106:1-4; 107:1-7; 108:1-3; 109:1-6; 110:1-3; 111:1-5; 112:1-4; 113:1-5; 114:1-6
The 99 Names of Allah
- #0 Best of Names 7:180; 20:8; 59:24
- #1 Ar Rahmaan 	The Most Compassionate 1:3; 17:110
- #2 Ar Raheem 	The Most Merciful 2:163; 3:31; 4:100; 5:3
- #3 Al Malik 	The King, The Sovereign 20:114; 23:116; 59:23; 62:1
- #4 Al Quddus 	The Absolutely Pure 59:23; 62:1
- #5 As Salaam 	The Source of Peace 59:23
- #6 Al Mu'min 	The Giver of Faith and Security 59:23
- #7 Al Muhaymin 	The Guardian, The Protector 59:23
- #8 Al Azeez 	The Almighty 3:6; 4:158; 9:40; 48:7
- #9 Al Jabbaar 	The Compeller, The Restorer 59:23
- #10 Al Mutakabbir 	The Supreme, The Majestic 59:23
- #11 Al Khaaliq 	The Creator 6:102; 13:16; 39:62; 40:62; 59:24
- #12 Al Baari 	The Maker from Nothing 59:24
- #13 Al Musawwir 	The Fashioner 59:24
- #14 Al Ghaffaar 	The All-Forgiving 20:82; 38:66; 39:5; 40:42; 71:10
- #15 Al Qahhaar 	The Subduer 13:16; 14:48; 38:65; 39:4; 40:16
- #16 Al Wahhaab 	The Bestower 3:8; 38:9; 38:35
- #17 Ar Razzaaq 	The Provider 51:58
- #18 Al Fattaah 	The Opener 34:26
- #19 Al 'Aleem 	The All-Knowing 2:158; 3:92; 4:35; 24:41; 33:40
- #20 Al Qaabid 	The Withholder 2:245
- #21 Al Baasit   The Expander  2:245
- #22 Al Khaafid  The Abaser 95:5
- #23 Ar Raafi'   The Exalter 58:11; 6:83
- #24 Al Mu'izz   The Honorer  3:26
- #25 Al Mudhil   The Humbler  3:26
- #26 As Samee'   The All-Hearing 2:127; 2:256; 8:17; 49:1
- #27 Al Baseer   The All-Seeing  4:58; 17:1; 42:11; 42:27
- #28 Al Hakam    The Judge 22:69
- #29 Al Adl      The Just  6:115
- #30 Al Lateef   The Subtle, The Gentle 6:103; 22:63; 31:16; 33:34
- #31 Al Khabeer  The All-Aware 6:18; 17:30; 49:13; 59:18
- #32 Al Haleem   The Forbearing  2:235; 17:44; 22:59; 35:41
- #33 Al 'Azeem   The Magnificent 2:255; 42:4; 56:96
- #34 Al Ghafoor  The Great Forgiver  2:173; 8:69; 16:110; 41:32
- #35 Ash Shakoor The Appreciative  35:30; 35:34; 42:23; 64:17
- #36 Al Aliyy    The Most High 4:34; 31:30; 42:4; 42:51
- #37 Al Kabeer   The Greatest  13:9; 22:62; 31:30
- #38 Al Hafeez   The Preserver 11:57; 34:21; 42:6
- #39 Al Muqeet   The Sustainer 4:85
- #40 Al Haseeb   The Reckoner  4:6; 4:86; 33:39
- #41 Al Jaleel   The Majestic  55:27; 39:14; 7:143
- #42 Al Kareem   The Generous  27:40; 82:6
- #43 Ar Raqeeb   The Watchful  4:1; 5:117
- #44 Al Mujeeb   The Responsive 11:61
- #45 Al Waasi'   The All-Encompassing 2:268; 3:73; 5:54
- #46 Al Hakeem   The All-Wise  31:27; 46:2; 57:1; 66:2
- #47 Al Wudood   The Most Loving 11:90; 85:14
- #48 Al Majeed   The Glorious  11:73
- #49 Al Baa'ith  The Resurrector 22:7
- #50 Ash Shaheed The Witness 4:166; 22:17; 41:53; 48:28
- #51 Al Haqq     The Truth 6:62; 22:6; 23:116; 24:25
- #52 Al Wakeel   The Trustee 3:173; 4:171; 28:28; 73:9
- #53 Al Qawiyy   The Strong  22:40; 22:74; 42:19; 57:25
- #54 Al Mateen   The Firm  51:58
- #55 Al Waliyy   The Protecting Friend 4:45; 7:196; 42:28; 45:19
- #56 Al Hameed   The Praiseworthy  14:8; 31:12; 31:26; 41:42
- #57 Al Muhsi    The Counter 72:28; 78:29; 82:10-12
- #58 Al Mubdi    The Originator 10:34; 27:64; 29:19; 85:13
- #59 Al Mu'eed   The Restorer  10:34; 27:64; 29:19; 85:13
- #60 Al Muhiy    The Giver of Life 7:158; 15:23; 30:50; 57:2
- #61 Al Mumeet   The Bringer of Death  3:156; 7:158; 15:23; 57:2
- #62 Al Haiyy    The Ever-Living 2:255; 3:2; 25:58; 40:65
- #63 Al Qayyoom  The Self-Subsisting 2:255; 3:2; 20:111
- #64 Al Waajid   The Finder 38:44
- #65 Al Maajid   The Noble 11:73
- #66 Al Waahid   The One 2:163; 5:73; 9:31; 18:110
- #67 Al Ahad     The Unique One  112:1
- #68 As Samad    The Eternal Refuge   112:2
- #69 Al Qaadir   The Able  6:65; 36:81; 46:33; 75:40
- #70 Al Muqtadir The Powerful  18:45; 54:42; 54:55
- #71 Al Muqaddim The Expediter 16:61; 17:34
- #72 Al Mu’akhir The Delayer  71:4
- #73 Al Awwal    The First 57:3
- #74 Al Aakhir   The Last 57:3
- #75 Az Zaahir   The Manifest  57:3
- #76 Al Baatin   The Hidden 57:3
- #77 Al Waali    The Governor  13:11; 22:7
- #78 Al Muta’ali The Most Exalted 13:9
- #79 Al Barr     The Source of Goodness 52:28
- #80 At Tawwaab  The Acceptor of Repentance 2:128; 4:64; 49:12; 110:3
- #81 Al Muntaqim The Avenger 32:22; 43:41; 44:16
- #82 Al Afuww    The Pardoner 4:99; 4:149; 22:60
- #83 Ar Ra’oof   The Most Kind 3:30; 9:117; 57:9; 59:10
- #84 Maalik Ul Mulk  Master of the Kingdom 3:26
- #85 Dhu Al Jalaali Wa Al Ikraam,  Lord of Majesty and Honor 55:27; 55:78
- #86 Al Muqsit   The Just One 3:18; 7:29
- #87 Al Jaami'   The Gatherer  3:9
- #88 Al Ghaniyy  The Self-Sufficient 3:97; 39:7; 47:38; 57:24
- #89 Al Mughni   The Enricher  9:28
- #90 Al Maani'   The Preventer 67:21
- #91 Ad Daaarr   The Distresser 6:17
- #92 An Naafi’   The Benefactor  30:37
- #93 An Noor     The Light 24:35
- #94 Al Haadi    The Guide 25:31
- #95 Al Badi'    The Originator  2:117; 6:101
- #96 Al Baaqi    The Everlasting 55:27
- #97 Al Waarith  The Inheritor 15:23
- #98 Ar Rasheed  The Guide to the Right Path 2:256
- #99 As Saboor   The Patient 2:153; 3:200; 103:3
Matching Ayahs
- = Alif, Lām, Meem. 2:1; 3:1; 29:1; 30:1; 31:1; 32:1
- = Those are upon right guidance from their Lord, and it is those who are the successful. 2:5; 31:5
- = O Children of Israel, remember My favor that I have bestowed upon you and that I preferred you over the worlds i.e., peoples. 2:47; 2:122
- = That was a nation which has passed on. It will have the consequence of what it earned, and you will have what you have earned. And you will not be asked about what they used to do. 2:134; 2:141
- = Abiding eternally therein. The punishment will not be lightened for them, nor will they be reprieved. 2:162; 3:88
- = Except for those who repent after that and correct themselves. For indeed, Allāh is Forgiving and Merciful. 3:89; 24:5
- = But those who disbelieve and deny Our signs - those are the companions of Hellfire. 5:10; 5:86
- = And no sign comes to them from the signs of their Lord except that they turn away therefrom. 6:4; 36:46
- = And already were messengers ridiculed before you, but those who mocked them were enveloped by that which they used to ridicule. 6:10; 21:41
- = Say, "Indeed I fear, if I should disobey my Lord, the punishment of a tremendous Day." 6:15; 39:13
- = So the earthquake seized them, and they became within their home [corpses] fallen prone. 7:78; 7:91
- = So he threw his staff, and behold, it was a serpent, manifest. 7:107; 26:32
- = And he drew out his hand; thereupon it was white [with radiance] for the observers. 7:108; 26:33
- = They said, "We have believed in the Lord of the worlds." 7:121; 26:47
- = The Lord of Moses and Aaron. 7:122; 26:48
- = And I will give them time. For indeed, My plan is firm. 7:183; 68:45
- = It is He who sent His Messenger with guidance and the religion of truth to manifest it over all religion, although those who associate others with Allah dislike it. 9:33; 61:9
- = O Prophet, fight against the disbelievers and the hypocrites and be harsh upon them. And their refuge is Hell, and wretched is the destination. 9:73; 66:9
- = And they say, "When is this promise, if you should be truthful?" 10:48; 21:38; 27:71; 34:29; 36:48; 67:25
- = And We certainly sent Moses with Our signs and a clear authority. 11:96; 40:23
- = And We had certainly given Moses the Scripture, but it came under disagreement. And if not for a word that preceded from your Lord, it would have been concluded between them. And indeed they are, concerning it, in disquieting doubt. 11:110; 41:45
- = That is not difficult for Allah. 14:20; 35:17
- = And when I have proportioned him and breathed into him of My [created] soul, then fall down to him in prostration." 15:29; 38:72
- = So the angels prostrated - all of them entirely. 15:30; 38:73
- = [ Allah ] said, "Then get out of it, for indeed, you are expelled." 15:34; 38:77
- = He said, "My Lord, then reprieve me until the Day they are resurrected." 15:36; 38:79
- = [ Allah ] said, "So indeed, you are of those reprieved." 15:37; 38:80
- = Until the Day of the time well-known." 15:38; 38:81
- = Except Your chosen servants among them. 15:40; 38:83
- = Indeed, the righteous will be in gardens and springs. 15:45; 51:15
- = He said, "Then what is your business [here], O messengers?" 15:57; 51:31
- = They said, "Indeed, we have been sent to a people of criminals." 15:58; 51:32
- = Those who have believed and are not confounding their belief with injustice - those will have security, and they are [rightly] guided. 16:42; 29:59
- = So that they will deny what We have given them. So enjoy yourselves, for you are going to know. 16:55; 30:34
- = Then he followed a way. 18:89; 18:92
- = Go to Pharaoh. Indeed, he has transgressed. 20:24; 79:17
- = And they who guard their private parts. 23:5; 70:29
- = Except from their wives or those their right hands possess, for indeed, they are not to be blamed. 23:6; 70:30
- = But whoever seeks beyond that, then those are the transgressors. 23:7; 70:31
- = And they who are to their trusts and their promises attentive. 23:8; 70:32
- = He said, "My Lord, support me because they have denied me." 23:26; 23:39
- = Ta, Seen, Meem. 26:1; 28:1
- = These are the verses of the clear Book. 26:2; 28:2
- = Indeed in that is a sign, and most of them were not to be believers. 26:8; 26:67; 26:103; 26:121; 26:174; 26:190
- = And indeed, your Lord - He is the Exalted in Might, the Merciful. 26:9; 26:68; 26:104; 26:122; 26:140; 26:159; 26:175; 26:191
- = And We drowned the others. 26:66; 37:82
- = Indeed, I am to you a trustworthy messenger. 26:107; 26:125; 26:143; 26:162; 26:178
- = So fear Allah and obey me. 26:108; 26:110; 26:126; 26:131; 26:144; 26:150; 26:163; 26:179
- = And I do not ask you for it any payment. My payment is only from the Lord of the worlds. 26:109; 26:127; 26:145; 26:164; 26:180
- = In gardens and springs. 26:147; 44:52
- = They said, "You are only of those affected by magic." 26:153; 26:185
- = Except his wife - We determined her to be of those who remained behind. 26:171; 37:135
- = Then We destroyed the others. 26:172; 37:136
- = And We rained upon them a rain [of stones], and evil was the rain of those who were warned. 26:173; 27:58
- = So for the punishment to be hastened? 26:204; 37:176
- = Who establish prayer and give zakah, and they, concerning the Hereafter, are certain [in faith]. 27:3; 31:4
- = And [mention, O Muhammad], the Day when He will call them and say, "Where are My 'partners' which you used to claim?" 28:62; 28:74
- = And our forefathers? 37:17; 56:48
- = And they will approach one another, questioning each other. 37:27; 52:25
- = But [they will be] the chosen servants of Allah. 37:40; 37:74; 37:128; 37:160
- = In the Gardens of Pleasure. 37:43; 56:12
- = And We left for him [favorable mention] among later generations: 37:78; 37:108; 37:129
- = Indeed, We thus reward the doers of good. 37:80; 37:121; 37:131; 77:44
- = Indeed, he was of Our believing servants. 37:81; 37:111; 37:132
- = What is [wrong] with you? How do you judge? 37:154; 68:36
- = It is nothing but a reminder to the worlds. 38:87; 81:27
- = The revelation of the Book is from Allah, the Exalted in Might, the Wise. 39:1; 45:2; 46:2
- = Ha, Meem. 40:1; 41:1; 42:1; 43:1; 44:1; 45:1; 46:1
- = By the clear Book. 43:2; 44:2
- = So leave them to converse vainly and amuse themselves until they meet their Day which they are promised. 43:83; 70:42
- = [They will be told], "Eat and drink in satisfaction for what you used to do." 52:19; 77:43
- = Or do you ask of them a payment, so they are by debt burdened down? 52:40; 68:46
- = Or do they have [knowledge of] the unseen, so they write [it] down? 52:41; 68:47
- = And how [severe] were My punishment and warning. 54:16; 54:21; 54:30
- = And We have certainly made the Quran easy to remember. So is there any who will remember? 54:17; 54:22; 54:32; 54:40
- = So which of the favors of your Lord would you deny? 55:13; 55:16; 55:18; 55:21; 55:23; 55:25; 55:28; 55:30; 55:32; 55:34; 55:36; 55:38; 55:40; 55:42; 55:45; 55:47; 55:49; 55:51; 55:53; 55:55; 55:57; 55:59; 55:61; 55:63; 55:65; 55:67; 55:69; 55:71; 55:73; 55:75; 55:77
- = A [large] company of the former peoples. 56:13; 56:39
- = And we had been [therefore] deprived? 56:67; 68:27
- = So exalt the name of your Lord, the Most Great. 56:74; 56:96; 69:52
- = [It is] a revelation from the Lord of the worlds. 56:80; 69:43
- = Whatever is in the heavens and whatever is on the earth exalts Allah, and He is the Exalted in Might, the Wise. 59:1; 61:1
- = When Our verses are recited to him, he says, "Legends of the former peoples." 68:15; 83:13
- = So he will be in a pleasant life. 69:21; 101:7
- = In a lofty garden. 69:22; 88:10
- = And does not encourage the feeding of the poor. 69:34; 107:3
- = [That] indeed, the Qur'an is the word of a noble Messenger. 69:40; 81:19
- = Indeed, this is a reminder, so whoever wills may take to his Lord a way. 73:19; 76:29
- = So whoever wills may remember it. 74:55; 80:12
- = Woe, that Day, to the deniers. 77:15; 77:19; 77:24; 77:28; 77:34; 77:37; 77:40; 77:45; 77:47; 77:49; 83:10
- = Indeed, the righteous will be in pleasure. 82:13; 83:22
- = It is a register inscribed. 83:9; 83:20
- = On adorned couches, observing. 83:23; 83:35
- = And has listened to its Lord and has been obligated [to do so]. 84:2; 84:5
- = Nor am I a worshiper of what you worship. 109:3; 109:5
noblequran.com Schemas
- The Mushriks of Makkah Affirmed Allah's Ruboobiyyah (Lordship) 10:31; 23:84; 29:61, 63; 31:25; 39:38; 43:9; 43:87
- The Book and the Wisdom (the Sunnah) 2:129; 2:151; 2:231; 3:164; 4:113; 33:34; 62:2
- Following the Way of One's (Misguided) Forefathers Condemned 2:170; 31:21; 43:22
- The Messenger of Allah Was Human 10:2; 16:43; 17:93; 18:110; 21:3; 21:34; 25:7; 25:20; 41:6
- The Mushriks Called Upon Allah Alone in Times of Hardship 10:22; 17:16; 29:65; 31:32
- Splitting in the Religion is Forbidden and Censured 3:103, 105; 6:159; 30:31; 42:13-14; 98:4
- The Attribute of Istiwaa for Allah 2:29; 7:57; 10:3; 13:2; 20:5; 25:59; 32:4; 41:11; 57:4
- The Increase (and Decrease) of Imaan (Faith) 3:173; 8:2; 9:124; 33:22; 48:4; 74:31
- The Messenger and None from the Creation Know The Unseen Independently 2:33; 3:44; 3:179; 5:109; 5:116; 6:50, 59; 7:188; 10:20; 11:31, 123; 11:49; 12:102; 18:26; 27:65; 31:34; 34:3, 14, 48; 72:26
- Allah Enlarges and Restricts Provision for Whom He Wills 17:30; 28:82; 29:62; 30:37; 34:36, 39; 39:52; 42:12, 27
- The Quran Revealed in Clear Arabic Language 12:2; 13:37; 16:103; 20:113; 26:195; 39:28; 41:3, 44; 43:3; 46:12
- Allah Does Not Burden a Soul More Than It Can Bear 2:233, 286; 6:152; 7:42; 23:62; 65:7
- No One Shall Bear the Burden of Another 6:164; 17:15; 35:18; 39:7; 53:38
- If Allah Inflicts With You With Harm, None Can Remove It But Allah 6:17; 10:107
- And Who Is More Unjust Than the One Who... 2:114, 140; 6:21, 93, 144, 157; 7:37; 10:17; 11:18; 18:15, 57; 29:68; 32:22; 39:32; 61:7
- Man Is Ungrateful in Prosperity and Submissive When in Need 10:12, 21; 11:9; 17:83; 30:33, 36; 39:8, 49
- Establishment (Tathbeet) Is Sought From and Granted by Allah 2:250; 3:147; 8:12, 45; 11:120; 14:27; 16:102; 25:32; 47:7
- All Differences to Be Referred Back to Allah and His Messenger 4:59, 65, 115; 24:51, 63; 33:36; 42:10
- The Dispute Between the Inhabitants of Hellfire 26:96-102; 38:58-64; 40:47-50
- The Obligation of Giving Obedience (Taa'ah) to Allah's Messenger 3:32, 132; 4:13, 59, 64, 69, 80; 5:92; 8:1, 20, 24, 46; 9:71; 24:51-52, 54, 56; 33:33, 66, 71; 47:33; 48:17; 49:14; 64:12
- The Verses of Prostration in the Quran 7:206; 13:15; 16:49; 19:58; 22:18, 77; 25:60; 27:26; 32:15; 41:38; 53:62; 84:21; 96:19
- All Calamities in the Ummah Are Due to Disobedience 3:165; 4:79; 22:10; 30:36, 41; 42:30, 48; 16:112
- Whomsoever Allah Misguides, There Is None to Guide 13:33; 39:23, 26; 40:33; 7:186; 18:17
- All the Prophets Began Rectification With Tawheed of Ibaadah 5:72, 11:50, 61, 84; 16:36; 21:25; 23:23; 29:16
- Success and Prosperity Linked to Tazkiyah (Purification) of the Soul 20:76; 35:18; 87:14; 91:9; 92:18;
- All Honour and Might ('Izzah) Belongs to Allah 4:139; 10:65; 35:10; 63:8
- The Obligation to Call Upon Allah Alone Purely and Sincerely 2:186; 6:41; 7:29, 55-56, 180; 17:110; 40:14, 60, 65;
- The Prohibition of Calling Upon Others Alongside Allah 10:106; 23:117; 25:68; 26:213; 28:88; 72:18;
- All Prophets Ordered Taqwa of Allah and Obedience (to Themselves) 43:63; 71:1-28
- Concerning Hijrah (Emigration) 2:218; 3:195; 4:97, 100; 8:72, 74-75; 9:20; 16:41, 110; 22:58; 29:26, 56; 39:10
- There Is No True Protector nor Aider for the Creation Except Allah 2:107, 120; 9:74, 116; 29:22; 42:31
- Those Whose Hearts Allah Places a Seal Over 4:155; 7:100-101; 9:87, 93; 10:74; 16:108; 30:59; 40:35; 48:16; 63:3
- Imaan Is Between Fear and Hope 17:57; 32:16; 39:9
- On the Nullification of All Action by Way of Kufr, Shirk and Nifaaq 2:217; 3:22; 5:5, 53; 6:88; 7:147; 9:17, 69; 11:16; 18:105; 33:19; 39:65; 47:9, 28, 32; 49:2
- The Revelations and Prophets of Allah Are the Lights of Guidance, Knowledge and Faith 5:44, 46; 6:91, 122; 7:157; 14:1, 5; 21:48; 22:8; 35:25; 39:22; 42:52; 57:9, 12, 19, 28; 64:8; 66:8
- Those Who Distort the Words Are the Yahood and the People of Ta'weel (Tahreef) 2:75; 4:46; 5:13; 5:41
- The Life of the World Is Merely a Temporary Pleasure and Enjoyment 3:185; 6:32; 9:38; 10:24; 13:26; 18:45-46; 28:60; 42:36; 47:36; 57:26
- The Dahriyyah (Atheists) 45:24; 6:29; 23:37
- Allah Sent Muhammad With the Deen to Prevail Over All Other (Abrogated or False) Religions 9:33; 48:28; 61:9
- About the Taaghoot and the Necessity of Rejecting of the Taaghoot 2:256-257; 4:51, 60, 76; 5:60; 16:36; 39:17
- They Plot and Allah Too Plots and He Is the Best of Plotters 3:54; 6:123; 7:99; 8:30; 10:21; 13:42; 16:26, 45, 127; 14:46; 27:50-51; 70; 35:43
- The Knowledge of the Final Hour Is With Allah 7:187; 33:63; 41:47
- The Furqaan (Criterion) 2:53, 185; 3:4; 8:29, 41; 21:48; 25:1
- Repelling the Evil With That Which Is Best 23:96; 28:54; 41:34
- The Final Hour Is Close at Hand 16:77; 17:51; 21:1; 42:17; 54:1; 70:7
- And From Amongst His Signs... 20:46; 30:20-25; 41:37, 39; 42:29; 42:32
- Allah Explains His Signs so That You May... 2:73, 187, 221, 242; 3:103; 5:89
- Allah Is the Creator of Everything 6:73, 101-102; 13:16; 14:10; 21:33; 24:45; 25:2, 59; 37:96; 39:62; 40:62
- Allah Did Not Create the Creation in Falsehood or in Jest 21:16; 38:27; 44:38; 46:3
- Allah Created Mankind That They May Worship Him Alone and to Test Them As to Who Is Best in Deed 11:7; 18:7; 51:56; 67:2;
- Allah Sent Messengers to Call to His Worship, to Be Obeyed, and As Givers of Glad Tidings and Warners 2:213; 4:64, 165; 6:48; 16:36; 18:56; 21:25
- The Four Levels of al-Qadr 5:97; 6:59; 10:61; 22:70; 27:75; 30:54; 37:96; 39:62; 57:22; 76:30; 81:29;
- The Forms and Types of Worship 1:5; 2:150; 3:19, 85, 185; 4:125, 136; 5:23; 6:162; 8:9; 17:110; 18:110; 21:90; 22:34; 23:117; 31:22; 39:54; 40:60; 64:8; 65:3; 76:7; 108:2; 113:1; 114:1
- Allah Guides and Misguides Whom He Wills 14:4; 16:93; 35:8; 74:31
- Those Whom Allah Misguides 2:26; 9:115; 14:27; 40:34, 74; 45:23
- None Can Guide Whomever Allah Misguides 4:88; 7:178; 13:33; 18:17; 30:29; 39:23, 36; 40:33; 42:44, 46
- Negation of Any Likeness for Allah 2:22; 19:65; 42:11; 112:4
- Allah Does Not Wrong Anyone, but They Wrong Their Own Souls 3:182; 8:51; 10:44; 16:33, 118; 22:10; 30:9; 41:46; 50:29; 11:101
- The Obligation of Following the Salaf (the Sahaabah) 2:137; 9:100; 4:115; 48:18, 29
- The Methodology of Giving Da'wah 12:108; 16:125; 29:46
- Shirk Is Not Limited to Idols and Includes Seeking Intercession Through Prophets, Angels, Jinns, and the Righteous 5:116; 10:18; 17:57; 26:69; 34:40; 35:14; 39:3;
- The Factors That Constitute Marriageable Age 4:6; 6:152; 24:59
- Jibrīl Is the Holy, Trustworthy Spirit Who Brought the Qurʾān From Allah to the Prophet 2:97; 16:102; 26:192
- Aid, Victory and Domination Is for Allah and His Messengers 30:47; 37:171-173; 40:51; 58:21
Matching Phrases 13 words
- وَلَقَدِ اسْتُهْزِئَ بِرُسُلٍ مِّن قَبْلِكَ فَحَاقَ بِالَّذِينَ سَخِرُوا مِنْهُم مَّا كَانُوا بِهِ يَسْتَهْزِئُونَ	6:10; 21:41
- وَإِلَى مَدْيَنَ أَخَاهُمْ شُعَيْبًا قَالَ يَاقَوْمِ اعْبُدُوا اللَّهَ مَا لَكُم مِّنْ إِلَهٍ غَيْرُهُ	7:85; 11:84
- وَإِلَى ثَمُودَ أَخَاهُمْ صَالِحًا قَالَ يَاقَوْمِ اعْبُدُوا اللَّهَ مَا لَكُم مِّنْ إِلَهٍ غَيْرُهُ	7:73; 11:61
- أَنَّ اللَّهَ يَبْسُطُ الرِّزْقَ لِمَن يَشَاءُ وَيَقْدِرُ إِنَّ فِي ذَلِكَ لَآيَاتٍ لِّقَوْمٍ يُؤْمِنُونَ	30:37; 39:52
- وَإِلَى عَادٍ أَخَاهُمْ هُودًا قَالَ يَاقَوْمِ اعْبُدُوا اللَّهَ مَا لَكُم مِّنْ إِلَهٍ غَيْرُهُ	7:65; 11:50
- وَالَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ سَنُدْخِلُهُمْ جَنَّاتٍ تَجْرِي مِن تَحْتِهَا الْأَنْهَارُ خَالِدِينَ فِيهَا أَبَدًا	4:57; 4:122
- تَجْرِي مِن تَحْتِهَا الْأَنْهَارُ خَالِدِينَ فِيهَا أَبَدًا رَّضِيَ اللَّهُ عَنْهُمْ وَرَضُوا عَنْهُ ذَلِكَ	5:119; 98:8
- قُلْ إِنَّمَا أَنَا بَشَرٌ مِّثْلُكُمْ يُوحَى إِلَيَّ أَنَّمَا إِلَهُكُمْ إِلَهٌ وَاحِدٌ	18:110; 41:6
- وَمِنَ النَّاسِ مَن يُجَادِلُ فِي اللَّهِ بِغَيْرِ عِلْمٍ وَلَا هُدًى وَلَا كِتَابٍ مُّنِيرٍ	22:8; 31:20
- يُولِجُ اللَّيْلَ فِي النَّهَارِ وَيُولِجُ النَّهَارَ فِي اللَّيْلِ وَسَخَّرَ الشَّمْسَ وَالْقَمَرَ كُلٌّ يَجْرِي	31:29; 35:13
- مِنَ السَّمَاءِ مَاءً فَأَحْيَا بِهِ الْأَرْضَ بَعْدَ مَوْتِهَا إِنَّ فِي ذَلِكَ لَآيَةً لِّقَوْمٍ	16:65; 30:24
- إِنَّ الَّذِينَ كَفَرُوا لَن تُغْنِيَ عَنْهُمْ أَمْوَالُهُمْ وَلَا أَوْلَادُهُم مِّنَ اللَّهِ شَيْئًا وَأُولَئِكَ	3:10; 3:116
- الَّذِي خَلَقَ السَّمَاوَاتِ وَالْأَرْضَ وَمَا بَيْنَهُمَا فِي سِتَّةِ أَيَّامٍ ثُمَّ اسْتَوَى عَلَى الْعَرْشِ	25:59; 32:4
Matching Phrases 12 words
- أَوَلَمْ يَسِيرُوا فِي الْأَرْضِ فَيَنظُرُوا كَيْفَ كَانَ عَاقِبَةُ الَّذِينَ مِن قَبْلِهِمْ كَانُوا	30:9; 35:44; 40:82
- إِنَّ اللَّهَ يُدْخِلُ الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ جَنَّاتٍ تَجْرِي مِن تَحْتِهَا الْأَنْهَارُ	22:14; 22:23; 47:12
- إِنَّ وَعْدَ اللَّهِ حَقٌّ فَلَا تَغُرَّنَّكُمُ الْحَيَاةُ الدُّنْيَا وَلَا يَغُرَّنَّكُم بِاللَّهِ الْغَرُورُ	31:33; 35:5
- فَمَنِ اهْتَدَى فَإِنَّمَا يَهْتَدِي لِنَفْسِهِ وَمَن ضَلَّ فَإِنَّمَا يَضِلُّ عَلَيْهَا	10:108; 17:15
- وَأَلْقِ عَصَاكَ فَلَمَّا رَآهَا تَهْتَزُّ كَأَنَّهَا جَانٌّ وَلَّى مُدْبِرًا وَلَمْ يُعَقِّبْ يَامُوسَى	27:10; 28:31
- سِيرُوا فِي الْأَرْضِ فَانظُرُوا كَيْفَ كَانَ عَاقِبَةُ الَّذِينَ مِن قَبْلُ كَانَ أَكْثَرُهُم	30:42; 40:82
- فَاصْبِرْ عَلَى مَا يَقُولُونَ وَسَبِّحْ بِحَمْدِ رَبِّكَ قَبْلَ طُلُوعِ الشَّمْسِ وَقَبْلَ غُرُوبِهَا	20:130; 50:39
- وَلَا تَقْرَبُوا مَالَ الْيَتِيمِ إِلَّا بِالَّتِي هِيَ أَحْسَنُ حَتَّى يَبْلُغَ أَشُدَّهُ وَأَوْفُوا	6:152; 17:34
- لَّيْسَ عَلَى الْأَعْمَى حَرَجٌ وَلَا عَلَى الْأَعْرَجِ حَرَجٌ وَلَا عَلَى الْمَرِيضِ حَرَجٌ	24:61; 48:17
- أَلَيْسَ هَذَا بِالْحَقِّ قَالُوا بَلَى وَرَبِّنَا قَالَ فَذُوقُوا الْعَذَابَ بِمَا كُنتُمْ تَكْفُرُونَ	6:30; 46:34
- فَقَالَ الضُّعَفَاءُ لِلَّذِينَ اسْتَكْبَرُوا إِنَّا كُنَّا لَكُمْ تَبَعًا فَهَلْ أَنتُم مُّغْنُونَ عَنَّا	14:21; 40:47
- إِلَّا أَسْمَاءً سَمَّيْتُمُوهَا أَنتُمْ وَآبَاؤُكُم مَّا أَنزَلَ اللَّهُ بِهَا مِن سُلْطَانٍ إِنِ	12:40; 53:23
- قَبْلِكَ إِلَّا رِجَالًا نُّوحِي إِلَيْهِمْ فَاسْأَلُوا أَهْلَ الذِّكْرِ إِن كُنتُمْ لَا تَعْلَمُونَ	16:43; 21:7
- قَالَ آمَنتُمْ لَهُ قَبْلَ أَنْ آذَنَ لَكُمْ إِنَّهُ لَكَبِيرُكُمُ الَّذِي عَلَّمَكُمُ السِّحْرَ	20:71; 26:49
- وَلَا تَزِرُ وَازِرَةٌ وِزْرَ أُخْرَى ثُمَّ إِلَى رَبِّكُم مَّرْجِعُكُمْ فَيُنَبِّئُكُم بِمَا كُنتُمْ	6:164; 39:7
- وَقُلْنَا اهْبِطُوا بَعْضُكُمْ لِبَعْضٍ عَدُوٌّ وَلَكُمْ فِي الْأَرْضِ مُسْتَقَرٌّ وَمَتَاعٌ إِلَى حِينٍ	2:36; 7:24
- اثْنَيْنِ قُلْ آلذَّكَرَيْنِ حَرَّمَ أَمِ الْأُنثَيَيْنِ أَمَّا اشْتَمَلَتْ عَلَيْهِ أَرْحَامُ الْأُنثَيَيْنِ	6:143; 6:144
""";
