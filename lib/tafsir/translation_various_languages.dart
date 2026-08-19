import 'translation_various_belarusian.dart';
import 'translation_various_bulgarian.dart';
import 'translation_various_cebuano.dart';
import 'translation_various_chichewa.dart';
import 'translation_various_croatian.dart';
import 'translation_various_dagbani.dart';
import 'translation_various_dari.dart';
import 'translation_various_dutch.dart';
import 'translation_various_greek.dart';
import 'translation_various_gujarati.dart';
import 'translation_various_hebrew.dart';
import 'translation_various_iranun.dart';
import 'translation_various_kannada.dart';
import 'translation_various_kazakh.dart';
import 'translation_various_kinyarwanda.dart';
import 'translation_various_kirundi.dart';
import 'translation_various_lingala.dart';
import 'translation_various_lithuanian.dart';
import 'translation_various_luganda.dart';
import 'translation_various_luhya.dart';
import 'translation_various_macedonian.dart';
import 'translation_various_maguindanaon.dart';
import 'translation_various_malay.dart';
import 'translation_various_marathi.dart';
import 'translation_various_moore.dart';
import 'translation_various_punjabi.dart';
import 'translation_various_romanian.dart';
import 'translation_various_somali.dart';
import 'translation_various_swedish.dart';
import 'translation_various_ukrainian.dart';
import 'translation_various_yao.dart';
import 'translation_various_yoruba.dart';

const List<String> variousTranslationLanguages = [
  'Belarusian',
  'Bulgarian',
  'Cebuano',
  'Chichewa',
  'Croatian',
  'Dagbani',
  'Dari',
  'Dutch',
  'Greek',
  'Gujarati',
  'Hebrew',
  'Iranun',
  'Kannada',
  'Kazakh',
  'Kinyarwanda',
  'Kirundi',
  'Lingala',
  'Lithuanian',
  'Luganda',
  'Luhya',
  'Macedonian',
  'Maguindanaon',
  'Malay',
  'Marathi',
  'Moore',
  'Punjabi',
  'Romanian',
  'Somali',
  'Swedish',
  'Ukrainian',
  'Yao',
  'Yoruba',
];

String? getVariousTranslation(String language, int surah, int ayah) {
  switch (language) {
    case 'Belarusian':   return getVariousTranslationBelarusian(surah, ayah);
    case 'Bulgarian':    return getVariousTranslationBulgarian(surah, ayah);
    case 'Cebuano':      return getVariousTranslationCebuano(surah, ayah);
    case 'Chichewa':     return getVariousTranslationChichewa(surah, ayah);
    case 'Croatian':     return getVariousTranslationCroatian(surah, ayah);
    case 'Dagbani':      return getVariousTranslationDagbani(surah, ayah);
    case 'Dari':         return getVariousTranslationDari(surah, ayah);
    case 'Dutch':        return getVariousTranslationDutch(surah, ayah);
    case 'Greek':        return getVariousTranslationGreek(surah, ayah);
    case 'Gujarati':     return getVariousTranslationGujarati(surah, ayah);
    case 'Hebrew':       return getVariousTranslationHebrew(surah, ayah);
    case 'Iranun':       return getVariousTranslationIranun(surah, ayah);
    case 'Kannada':      return getVariousTranslationKannada(surah, ayah);
    case 'Kazakh':       return getVariousTranslationKazakh(surah, ayah);
    case 'Kinyarwanda':  return getVariousTranslationKinyarwanda(surah, ayah);
    case 'Kirundi':      return getVariousTranslationKirundi(surah, ayah);
    case 'Lingala':      return getVariousTranslationLingala(surah, ayah);
    case 'Lithuanian':   return getVariousTranslationLithuanian(surah, ayah);
    case 'Luganda':      return getVariousTranslationLuganda(surah, ayah);
    case 'Luhya':        return getVariousTranslationLuhya(surah, ayah);
    case 'Macedonian':   return getVariousTranslationMacedonian(surah, ayah);
    case 'Maguindanaon': return getVariousTranslationMaguindanaon(surah, ayah);
    case 'Malay':        return getVariousTranslationMalay(surah, ayah);
    case 'Marathi':      return getVariousTranslationMarathi(surah, ayah);
    case 'Moore':        return getVariousTranslationMoore(surah, ayah);
    case 'Punjabi':      return getVariousTranslationPunjabi(surah, ayah);
    case 'Romanian':     return getVariousTranslationRomanian(surah, ayah);
    case 'Somali':       return getVariousTranslationSomali(surah, ayah);
    case 'Swedish':      return getVariousTranslationSwedish(surah, ayah);
    case 'Ukrainian':    return getVariousTranslationUkrainian(surah, ayah);
    case 'Yao':          return getVariousTranslationYao(surah, ayah);
    case 'Yoruba':       return getVariousTranslationYoruba(surah, ayah);
    default: return null;
  }
}

const Set<String> rtlVariousTranslationLanguages = {
  'Dari',
  'Hebrew',
};

bool isVariousTranslationRtl(String language) =>
    rtlVariousTranslationLanguages.contains(language);
