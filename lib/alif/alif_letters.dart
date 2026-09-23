import 'package:flutter/material.dart';

class AlifLetterForms {
  final String isolated;
  final String initial;
  final String medial;
  final String finalForm;
  const AlifLetterForms({
    required this.isolated,
    required this.initial,
    required this.medial,
    required this.finalForm,
  });
}

class AlifLetter {
  final int id;
  final String letter;
  final String name;
  final String transliteration;
  final String audioAsset;
  final AlifLetterForms forms;
  final String exampleWord;
  final String exampleMeaning;
  const AlifLetter({
    required this.id,
    required this.letter,
    required this.name,
    required this.transliteration,
    required this.audioAsset,
    required this.forms,
    required this.exampleWord,
    required this.exampleMeaning,
  });
}

const List<AlifLetter> alifAlphabet = [
  AlifLetter(id: 1, letter: "أ", name: "'alif", transliteration: "a", audioAsset: "01alif",
    forms: AlifLetterForms(isolated: "ا", initial: "ا", medial: "ـا", finalForm: "ـا"),
    exampleWord: "أَسَد", exampleMeaning: "lion"),
  AlifLetter(id: 2, letter: "ب", name: "Bā'", transliteration: "b", audioAsset: "02ba",
    forms: AlifLetterForms(isolated: "ب", initial: "بـ", medial: "ـبـ", finalForm: "ـب"),
    exampleWord: "بَاب", exampleMeaning: "door"),
  AlifLetter(id: 3, letter: "ت", name: "Tā'", transliteration: "t", audioAsset: "03ta",
    forms: AlifLetterForms(isolated: "ت", initial: "تـ", medial: "ـتـ", finalForm: "ـت"),
    exampleWord: "تُفَّاح", exampleMeaning: "apple"),
  AlifLetter(id: 4, letter: "ث", name: "Thā'", transliteration: "th", audioAsset: "04tha",
    forms: AlifLetterForms(isolated: "ث", initial: "ثـ", medial: "ـثـ", finalForm: "ـث"),
    exampleWord: "ثَلْج", exampleMeaning: "snow"),
  AlifLetter(id: 5, letter: "ج", name: "Jīm", transliteration: "j", audioAsset: "05jim",
    forms: AlifLetterForms(isolated: "ج", initial: "جـ", medial: "ـجـ", finalForm: "ـج"),
    exampleWord: "جَمَل", exampleMeaning: "camel"),
  AlifLetter(id: 6, letter: "ح", name: "Ḥā'", transliteration: "h", audioAsset: "06ha",
    forms: AlifLetterForms(isolated: "ح", initial: "حـ", medial: "ـحـ", finalForm: "ـح"),
    exampleWord: "حَلِيب", exampleMeaning: "milk"),
  AlifLetter(id: 7, letter: "خ", name: "Khā'", transliteration: "ch", audioAsset: "07kha",
    forms: AlifLetterForms(isolated: "خ", initial: "خـ", medial: "ـخـ", finalForm: "ـخ"),
    exampleWord: "خُبْز", exampleMeaning: "bread"),
  AlifLetter(id: 8, letter: "د", name: "Dāl", transliteration: "d", audioAsset: "08dal",
    forms: AlifLetterForms(isolated: "د", initial: "د", medial: "ـد", finalForm: "ـد"),
    exampleWord: "دَار", exampleMeaning: "house"),
  AlifLetter(id: 9, letter: "ذ", name: "Dhāl", transliteration: "dh", audioAsset: "09dhal",
    forms: AlifLetterForms(isolated: "ذ", initial: "ذ", medial: "ـذ", finalForm: "ـذ"),
    exampleWord: "ذَهَب", exampleMeaning: "gold"),
  AlifLetter(id: 10, letter: "ر", name: "Rā'", transliteration: "r", audioAsset: "10ra",
    forms: AlifLetterForms(isolated: "ر", initial: "ر", medial: "ـر", finalForm: "ـر"),
    exampleWord: "رُز", exampleMeaning: "rice"),
  AlifLetter(id: 11, letter: "ز", name: "Zāy", transliteration: "z", audioAsset: "11zay",
    forms: AlifLetterForms(isolated: "ز", initial: "ز", medial: "ـز", finalForm: "ـز"),
    exampleWord: "زَهْرَة", exampleMeaning: "flower"),
  AlifLetter(id: 12, letter: "س", name: "Sīn", transliteration: "s", audioAsset: "12seen",
    forms: AlifLetterForms(isolated: "س", initial: "سـ", medial: "ـسـ", finalForm: "ـس"),
    exampleWord: "سَمَك", exampleMeaning: "fish"),
  AlifLetter(id: 13, letter: "ش", name: "Shīn", transliteration: "sh", audioAsset: "13sin",
    forms: AlifLetterForms(isolated: "ش", initial: "شـ", medial: "ـشـ", finalForm: "ـش"),
    exampleWord: "شَمْس", exampleMeaning: "sun"),
  AlifLetter(id: 14, letter: "ص", name: "Ṣād", transliteration: "s", audioAsset: "14sad",
    forms: AlifLetterForms(isolated: "ص", initial: "صـ", medial: "ـصـ", finalForm: "ـص"),
    exampleWord: "صَبَاح", exampleMeaning: "morning"),
  AlifLetter(id: 15, letter: "ض", name: "Ḍād", transliteration: "d", audioAsset: "15dad",
    forms: AlifLetterForms(isolated: "ض", initial: "ضـ", medial: "ـضـ", finalForm: "ـض"),
    exampleWord: "ضَوْء", exampleMeaning: "light"),
  AlifLetter(id: 16, letter: "ط", name: "Ṭā'", transliteration: "t", audioAsset: "16taa",
    forms: AlifLetterForms(isolated: "ط", initial: "طـ", medial: "ـطـ", finalForm: "ـط"),
    exampleWord: "طَائِر", exampleMeaning: "bird"),
  AlifLetter(id: 17, letter: "ظ", name: "Ẓā'", transliteration: "z", audioAsset: "17zaa",
    forms: AlifLetterForms(isolated: "ظ", initial: "ظـ", medial: "ـظـ", finalForm: "ـظ"),
    exampleWord: "ظِل", exampleMeaning: "shadow"),
  AlifLetter(id: 18, letter: "ع", name: "ayn", transliteration: "c", audioAsset: "18ayn",
    forms: AlifLetterForms(isolated: "ع", initial: "عـ", medial: "ـعـ", finalForm: "ـع"),
    exampleWord: "عَيْن", exampleMeaning: "eye"),
  AlifLetter(id: 19, letter: "غ", name: "Ghayn", transliteration: "gh", audioAsset: "19ghayn",
    forms: AlifLetterForms(isolated: "غ", initial: "غـ", medial: "ـغـ", finalForm: "ـغ"),
    exampleWord: "غَابَة", exampleMeaning: "forest"),
  AlifLetter(id: 20, letter: "ف", name: "Fā'", transliteration: "f", audioAsset: "20fa",
    forms: AlifLetterForms(isolated: "ف", initial: "فـ", medial: "ـفـ", finalForm: "ـف"),
    exampleWord: "فِيل", exampleMeaning: "elephant"),
  AlifLetter(id: 21, letter: "ق", name: "Qāf", transliteration: "q", audioAsset: "21qaf",
    forms: AlifLetterForms(isolated: "ق", initial: "قـ", medial: "ـقـ", finalForm: "ـق"),
    exampleWord: "قَمَر", exampleMeaning: "moon"),
  AlifLetter(id: 22, letter: "ك", name: "Kāf", transliteration: "k", audioAsset: "22kaf",
    forms: AlifLetterForms(isolated: "ك", initial: "كـ", medial: "ـكـ", finalForm: "ـك"),
    exampleWord: "كِتَاب", exampleMeaning: "book"),
  AlifLetter(id: 23, letter: "ل", name: "Lām", transliteration: "l", audioAsset: "23lam",
    forms: AlifLetterForms(isolated: "ل", initial: "لـ", medial: "ـلـ", finalForm: "ـل"),
    exampleWord: "لَيْل", exampleMeaning: "night"),
  AlifLetter(id: 24, letter: "م", name: "Mīm", transliteration: "m", audioAsset: "24mim",
    forms: AlifLetterForms(isolated: "م", initial: "مـ", medial: "ـمـ", finalForm: "ـم"),
    exampleWord: "مَاء", exampleMeaning: "water"),
  AlifLetter(id: 25, letter: "ن", name: "Nūn", transliteration: "n", audioAsset: "25nun",
    forms: AlifLetterForms(isolated: "ن", initial: "نـ", medial: "ـنـ", finalForm: "ـن"),
    exampleWord: "نَجْم", exampleMeaning: "star"),
  AlifLetter(id: 26, letter: "ه", name: "Hā'", transliteration: "h", audioAsset: "26ha2",
    forms: AlifLetterForms(isolated: "ه", initial: "هـ", medial: "ـهـ", finalForm: "ـه"),
    exampleWord: "هَوَاء", exampleMeaning: "air"),
  AlifLetter(id: 27, letter: "و", name: "Wāw", transliteration: "w", audioAsset: "27waw",
    forms: AlifLetterForms(isolated: "و", initial: "و", medial: "ـو", finalForm: "ـو"),
    exampleWord: "وَرْد", exampleMeaning: "rose"),
  AlifLetter(id: 28, letter: "ي", name: "Yā'", transliteration: "y", audioAsset: "28ya",
    forms: AlifLetterForms(isolated: "ي", initial: "يـ", medial: "ـيـ", finalForm: "ـي"),
    exampleWord: "يَد", exampleMeaning: "hand"),
];

const List<int> alifBlankSlotPositions = [5, 15, 20, 25, 30];

List<AlifLetter?> buildAlifDisplayItems({
  List<int> blankPositions = alifBlankSlotPositions,
}) {
  final blanks = blankPositions.toSet();
  final result = <AlifLetter?>[];
  var pos = 1;
  for (final letter in alifAlphabet) {
    while (blanks.contains(pos)) {
      result.add(null);
      pos++;
    }
    result.add(letter);
    pos++;
  }
  return result;
}

/// Maps a letter's id to its shape-group index (0-7).
/// Letters not sharing a base shape with others (alif, fa-qaf-kaf-lam-mim-nun-ha-waw-ya)
/// are intentionally left out and get no group color.
const Map<int, int> alifGroupIndexById = {
  2: 0, 3: 0, 4: 0,   // ب ت ث
  5: 1, 6: 1, 7: 1,   // ج ح خ
  8: 2, 9: 2,         // د ذ
  10: 3, 11: 3,       // ر ز
  12: 4, 13: 4,       // س ش
  14: 5, 15: 5,       // ص ض
  16: 6, 17: 6,       // ط ظ
  18: 7, 19: 7,       // ع غ
};

const List<Color> alifGroupColors = [
  Color(0xFF00B9E5),
  Color(0xFF38D430),
  Color(0xFFE3E82B),
  Color(0xFFFFAB4D),
  Color(0xFFFF3F3F),
  Color(0xFFEF2BC1),
  Color(0xFFBC13FE),
  Color(0xFFF7CB9A),
];

/// Returns this letter's neon group color, or null if it isn't part of a
/// colored group.
Color? alifGroupColorForLetter(AlifLetter? letter) {
  if (letter == null) return null;
  final idx = alifGroupIndexById[letter.id];
  if (idx == null) return null;
  return alifGroupColors[idx];
}
