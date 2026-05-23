import 'hadeeth_Amharic.dart';
import 'hadeeth_Arabic.dart';
import 'hadeeth_Assamese.dart';
import 'hadeeth_Bangla.dart';
import 'hadeeth_Bosnian.dart';
import 'hadeeth_Chinese.dart';
import 'hadeeth_Dutch.dart';
import 'hadeeth_English.dart';
import 'hadeeth_Filipino.dart';
import 'hadeeth_French.dart';
import 'hadeeth_Georgian.dart';
import 'hadeeth_Gujarati.dart';
import 'hadeeth_Hausa.dart';
import 'hadeeth_Hindi.dart';
import 'hadeeth_Hungarian.dart';
import 'hadeeth_Indonesian.dart';
import 'hadeeth_Japanese.dart';
import 'hadeeth_Kannada.dart';
import 'hadeeth_Khmer.dart';
import 'hadeeth_Kurdish.dart';
import 'hadeeth_Macedonian.dart';
import 'hadeeth_Malayalam.dart';
import 'hadeeth_Marathi.dart';
import 'hadeeth_Persian.dart';
import 'hadeeth_PersianAfghan.dart';
import 'hadeeth_Pashto.dart';
import 'hadeeth_Portuguese.dart';
import 'hadeeth_Punjabi.dart';
import 'hadeeth_Romanian.dart';
import 'hadeeth_Russian.dart';
import 'hadeeth_Sinhala.dart';
import 'hadeeth_Spanish.dart';
import 'hadeeth_Swahili.dart';
import 'hadeeth_Telugu.dart';
import 'hadeeth_Thai.dart';
import 'hadeeth_Turkish.dart';
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
  'Amharic',
  'Arabic',
  'Assamese',
  'Bangla',
  'Bosnian',
  'Chinese',
  'Dutch',
  'English',
  'Filipino',
  'French',
  'Georgian',
  'Gujarati',
  'Hausa',
  'Hindi',
  'Hungarian',
  'Indonesian',
  'Japanese',
  'Kannada',
  'Khmer',
  'Kurdish',
  'Macedonian',
  'Malayalam',
  'Marathi',
  'Pashto',
  'Persian',
  'PersianAfghan',
  'Portuguese',
  'Punjabi',
  'Romanian',
  'Russian',
  'Sinhala',
  'Spanish',
  'Swahili',
  'Telugu',
  'Thai',
  'Turkish',
  'Urdu',
  'Uyghur',
  'Vietnamese',
];

List<HadeethEntry> getHadeethForLanguage(String language) {
  final raw = switch (language) {
    'Amharic' => hadithAmharicRaw,
    'Arabic' => hadithArabicRaw,
    'Assamese' => hadithAssameseRaw,
    'Bangla' => hadithBanglaRaw,
    'Bosnian' => hadithBosnianRaw,
    'Chinese' => hadithChineseRaw,
    'Dutch' => hadithDutchRaw,
    'Filipino' => hadithFilipinoRaw,
    'French' => hadithFrenchRaw,
    'Georgian' => hadithGeorgianRaw,
    'Gujarati' => hadithGujaratiRaw,
    'Hausa' => hadithHausaRaw,
    'Hindi' => hadithHindiRaw,
    'Hungarian' => hadithHungarianRaw,
    'Indonesian' => hadithIndonesianRaw,
    'Japanese' => hadithJapaneseRaw,
    'Kannada' => hadithKannadaRaw,
    'Khmer' => hadithKhmerRaw,
    'Kurdish' => hadithKurdishRaw,
    'Macedonian' => hadithMacedonianRaw,
    'Malayalam' => hadithMalayalamRaw,
    'Marathi' => hadithMarathiRaw,
    'Pashto' => hadithPashtoRaw,
    'Persian' => hadithPersianRaw,
    'PersianAfghan' => hadithPersianAfghanRaw,
    'Portuguese' => hadithPortugueseRaw,
    'Punjabi' => hadithPunjabiRaw,
    'Romanian' => hadithRomanianRaw,
    'Russian' => hadithRussianRaw,
    'Sinhala' => hadithSinhalaRaw,
    'Spanish' => hadithSpanishRaw,
    'Swahili' => hadithSwahiliRaw,
    'Telugu' => hadithTeluguRaw,
    'Thai' => hadithThaiRaw,
    'Turkish' => hadithTurkishRaw,
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
  'PersianAfgan',
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
