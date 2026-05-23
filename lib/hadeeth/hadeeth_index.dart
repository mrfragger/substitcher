import 'hadeeth_Albanian.dart';
import 'hadeeth_Amharic.dart';
import 'hadeeth_Arabic.dart';
import 'hadeeth_Assamese.dart';
import 'hadeeth_Bangla.dart';
import 'hadeeth_Bosnian.dart';
import 'hadeeth_Burmese.dart';
import 'hadeeth_Chinese.dart';
import 'hadeeth_Dutch.dart';
import 'hadeeth_English.dart';
import 'hadeeth_Filipino.dart';
import 'hadeeth_French.dart';
import 'hadeeth_Georgian.dart';
import 'hadeeth_German.dart';
import 'hadeeth_Gujarati.dart';
import 'hadeeth_Hausa.dart';
import 'hadeeth_Hindi.dart';
import 'hadeeth_Hungarian.dart';
import 'hadeeth_Indonesian.dart';
import 'hadeeth_Italian.dart';
import 'hadeeth_Japanese.dart';
import 'hadeeth_Kannada.dart';
import 'hadeeth_Khmer.dart';
import 'hadeeth_Kurdish.dart';
import 'hadeeth_Macedonian.dart';
import 'hadeeth_Malagasy.dart';
import 'hadeeth_Malayalam.dart';
import 'hadeeth_Marathi.dart';
import 'hadeeth_Mossi.dart';
import 'hadeeth_Persian.dart';
import 'hadeeth_PersianAfghan.dart';
import 'hadeeth_Pashto.dart';
import 'hadeeth_Portuguese.dart';
import 'hadeeth_Punjabi.dart';
import 'hadeeth_Romanian.dart';
import 'hadeeth_Russian.dart';
import 'hadeeth_Serbian.dart';
import 'hadeeth_Sinhala.dart';
import 'hadeeth_Spanish.dart';
import 'hadeeth_Swahili.dart';
import 'hadeeth_Swedish.dart';
import 'hadeeth_Tamil.dart';
import 'hadeeth_Telugu.dart';
import 'hadeeth_Thai.dart';
import 'hadeeth_Turkish.dart';
import 'hadeeth_Ukrainian.dart';
import 'hadeeth_Urdu.dart';
import 'hadeeth_Uyghur.dart';
import 'hadeeth_Vietnamese.dart';

class HadeethEntry {
  final int id;
  final int categoryId;
  final String category;
  final String title;
  final String hadeeth;
  final String explanation;
  final List<String> hints;
  final String grade;
  final String attribution;
  const HadeethEntry({
    required this.id,
    required this.categoryId,
    required this.category,
    required this.title,
    required this.hadeeth,
    required this.explanation,
    required this.hints,
    required this.grade,
    required this.attribution,
  });
}

const List<String> availableHadeethLanguages = [
  'Albanian',
  'Amharic',
  'Arabic',
  'Assamese',
  'Bangla',
  'Bosnian',
  'Burmese',
  'Chinese',
  'Dutch',
  'English',
  'Filipino',
  'French',
  'Georgian',
  'German',
  'Gujarati',
  'Hausa',
  'Hindi',
  'Hungarian',
  'Indonesian',
  'Italian',
  'Japanese',
  'Kannada',
  'Khmer',
  'Kurdish',
  'Macedonian',
  'Malagasy',
  'Malayalam',
  'Marathi',
  'Mossi',
  'Pashto',
  'Persian',
  'PersianAfghan',
  'Portuguese',
  'Punjabi',
  'Romanian',
  'Russian',
  'Serbian',
  'Sinhala',
  'Spanish',
  'Swahili',
  'Swedish',
  'Tamil',
  'Telugu',
  'Thai',
  'Turkish',
  'Ukrainian',
  'Urdu',
  'Uyghur',
  'Vietnamese',
];

List<HadeethEntry> getHadeethForLanguage(String language) {
  final raw = switch (language) {
    'Albanian' => hadithAlbanianRaw,
    'Amharic' => hadithAmharicRaw,
    'Arabic' => hadithArabicRaw,
    'Assamese' => hadithAssameseRaw,
    'Bangla' => hadithBanglaRaw,
    'Bosnian' => hadithBosnianRaw,
    'Burmese' => hadithBurmeseRaw,
    'Chinese' => hadithChineseRaw,
    'Dutch' => hadithDutchRaw,
    'Filipino' => hadithFilipinoRaw,
    'French' => hadithFrenchRaw,
    'Georgian' => hadithGeorgianRaw,
    'German' => hadithGermanRaw,
    'Gujarati' => hadithGujaratiRaw,
    'Hausa' => hadithHausaRaw,
    'Hindi' => hadithHindiRaw,
    'Hungarian' => hadithHungarianRaw,
    'Indonesian' => hadithIndonesianRaw,
    'Italian' => hadithItalianRaw,
    'Japanese' => hadithJapaneseRaw,
    'Kannada' => hadithKannadaRaw,
    'Khmer' => hadithKhmerRaw,
    'Kurdish' => hadithKurdishRaw,
    'Macedonian' => hadithMacedonianRaw,
    'Malagasy' => hadithMalagasyRaw,
    'Malayalam' => hadithMalayalamRaw,
    'Marathi' => hadithMarathiRaw,
    'Mossi' => hadithMossiRaw,
    'Pashto' => hadithPashtoRaw,
    'Persian' => hadithPersianRaw,
    'PersianAfghan' => hadithPersianAfghanRaw,
    'Portuguese' => hadithPortugueseRaw,
    'Punjabi' => hadithPunjabiRaw,
    'Romanian' => hadithRomanianRaw,
    'Russian' => hadithRussianRaw,
    'Serbian' => hadithSerbianRaw,
    'Sinhala' => hadithSinhalaRaw,
    'Spanish' => hadithSpanishRaw,
    'Swahili' => hadithSwahiliRaw,
    'Swedish' => hadithSwedishRaw,
    'Tamil' => hadithTamilRaw,
    'Telugu' => hadithTeluguRaw,
    'Thai' => hadithThaiRaw,
    'Turkish' => hadithTurkishRaw,
    'Ukrainian' => hadithUkrainianRaw,
    'Urdu' => hadithUrduRaw,
    'Uyghur' => hadithUyghurRaw,
    'Vietnamese' => hadithVietnameseRaw,
    _ => hadithEnglishRaw,
  };
  return _parseHadeeth(raw);
}

const Set<String> rtlHadeethLanguages = {
  'Arabic',
  'Dari',
  'Hebrew',
  'Kurdish',
  'Pashto',
  'Persian',
  'PersianAfghan',
  'Urdu',
  'Uyghur',
};

bool isRtlHadeethLanguage(String language) =>
    rtlHadeethLanguages.contains(language);

List<HadeethEntry> _parseHadeeth(Map<int, Map<String, Object>> raw) {
  return raw.entries.map((e) {
    final v = e.value;
    return HadeethEntry(
      id: e.key,
      categoryId: (v['category_id'] as int?) ?? 0,
      category: (v['category'] as String?) ?? '',
      title: (v['title'] as String?) ?? '',
      hadeeth: (v['hadeeth'] as String?) ?? '',
      explanation: (v['explanation'] as String?) ?? '',
      hints: ((v['hints'] as List?)?.cast<String>()) ?? [],
      grade: (v['grade'] as String?) ?? '',
      attribution: (v['attribution'] as String?) ?? '',
    );
  }).toList();
}
