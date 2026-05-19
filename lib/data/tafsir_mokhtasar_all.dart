import 'tafsir_mokhtasar.dart';
import 'tafsir_mokhtasar_azerbaijani.dart';
import 'tafsir_mokhtasar_bengali.dart';
import 'tafsir_mokhtasar_bosnian.dart';
import 'tafsir_mokhtasar_chinese.dart';
import 'tafsir_mokhtasar_french.dart';
import 'tafsir_mokhtasar_indonesian.dart';
import 'tafsir_mokhtasar_italian.dart';
import 'tafsir_mokhtasar_japanese.dart';
import 'tafsir_mokhtasar_khmer.dart';
import 'tafsir_mokhtasar_kurdish.dart';
import 'tafsir_mokhtasar_kyrgyz.dart';
import 'tafsir_mokhtasar_persian.dart';
import 'tafsir_mokhtasar_serbian.dart';
import 'tafsir_mokhtasar_spanish.dart';
import 'tafsir_mokhtasar_tagalog.dart';
import 'tafsir_mokhtasar_thai.dart';
import 'tafsir_mokhtasar_turkish.dart';
import 'tafsir_mokhtasar_uyghur.dart';
import 'tafsir_mokhtasar_uzbek.dart';
import 'tafsir_mokhtasar_vietnamese.dart';

const List<String> mokhtasarLanguages = [
  'English',
  'Azerbaijani',
  'Bengali',
  'Bosnian',
  'Chinese',
  'French',
  'Indonesian',
  'Italian',
  'Japanese',
  'Khmer',
  'Kurdish',
  'Kyrgyz',
  'Persian',
  'Serbian',
  'Spanish',
  'Tagalog',
  'Thai',
  'Turkish',
  'Uyghur',
  'Uzbek',
  'Vietnamese',
];

String? getTafsirMokhtasarForLanguage(String language, int surah, int ayah) {
  switch (language) {
    case 'Azerbaijani':return getTafsirMokhtasarAzerbaijani(surah, ayah);
    case 'Bengali':    return getTafsirMokhtasarBengali(surah, ayah);
    case 'Bosnian':    return getTafsirMokhtasarBosnian(surah, ayah);
    case 'Chinese':    return getTafsirMokhtasarChinese(surah, ayah);
    case 'French':     return getTafsirMokhtasarFrench(surah, ayah);
    case 'Indonesian': return getTafsirMokhtasarIndonesian(surah, ayah);
    case 'Italian':    return getTafsirMokhtasarItalian(surah, ayah);
    case 'Japanese':   return getTafsirMokhtasarJapanese(surah, ayah);
    case 'Khmer':      return getTafsirMokhtasarKhmer(surah, ayah);
    case 'Kurdish':    return getTafsirMokhtasarKurdish(surah, ayah);
    case 'Kyrgyz':     return getTafsirMokhtasarKyrgyz(surah, ayah);
    case 'Persian':    return getTafsirMokhtasarPersian(surah, ayah);
    case 'Serbian':    return getTafsirMokhtasarSerbian(surah, ayah);
    case 'Spanish':    return getTafsirMokhtasarSpanish(surah, ayah);
    case 'Tagalog':    return getTafsirMokhtasarTagalog(surah, ayah);
    case 'Thai':       return getTafsirMokhtasarThai(surah, ayah);
    case 'Turkish':    return getTafsirMokhtasarTurkish(surah, ayah);
    case 'Uyghur':     return getTafsirMokhtasarUyghur(surah, ayah);
    case 'Uzbek':      return getTafsirMokhtasarUzbek(surah, ayah);
    case 'Vietnamese': return getTafsirMokhtasarVietnamese(surah, ayah);
    default:           return getTafsirMokhtasar(surah, ayah); // English
  }
}
