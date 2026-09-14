import '../models/font_category.dart';

class FontDatabase {
  static final Map<String, FontMetadata> _fonts = {

    // ==================== free/ligatures/Gluk ====================
    'FoglihtenNo07': FontMetadata(fontName: 'FoglihtenNo07', mainCategory: FontCategory.free, subCategories: [FontCategory.ligatures], studio: FontCategory.gluk),
    'Galberik': FontMetadata(fontName: 'Galberik', mainCategory: FontCategory.free, subCategories: [FontCategory.ligatures], studio: FontCategory.gluk),
    'QumpellkaNo12': FontMetadata(fontName: 'QumpellkaNo12', mainCategory: FontCategory.free, subCategories: [FontCategory.ligatures], studio: FontCategory.gluk),
    'ZnikomitNo24': FontMetadata(fontName: 'ZnikomitNo24', mainCategory: FontCategory.free, subCategories: [FontCategory.ligatures], studio: FontCategory.gluk),

    // ==================== free/Various ====================
    'Apollo Asm': FontMetadata(fontName: 'Apollo Asm', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Aw_Siam  English Not Thai': FontMetadata(fontName: 'Aw_Siam  English Not Thai', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Becker': FontMetadata(fontName: 'Becker', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Bisten': FontMetadata(fontName: 'Bisten', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Chicle': FontMetadata(fontName: 'Chicle', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Chrisye': FontMetadata(fontName: 'Chrisye', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Cofenauts': FontMetadata(fontName: 'Cofenauts', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Devinne Swash': FontMetadata(fontName: 'Devinne Swash', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Heavy Heap rg': FontMetadata(fontName: 'Heavy Heap rg', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'History of Wawa': FontMetadata(fontName: 'History of Wawa', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Ketupat Ramadhan': FontMetadata(fontName: 'Ketupat Ramadhan', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Kingthings Chimaera': FontMetadata(fontName: 'Kingthings Chimaera', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Kingthings Lickorishe': FontMetadata(fontName: 'Kingthings Lickorishe', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Kingthings Sans': FontMetadata(fontName: 'Kingthings Sans', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Marhey': FontMetadata(fontName: 'Marhey', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Sinistre Dark': FontMetadata(fontName: 'Sinistre Dark', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Slugfest': FontMetadata(fontName: 'Slugfest', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Spicy Rice': FontMetadata(fontName: 'Spicy Rice', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Spongeboytt2': FontMetadata(fontName: 'Spongeboytt2', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'TannenbergFett': FontMetadata(fontName: 'TannenbergFett', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Trickster': FontMetadata(fontName: 'Trickster', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),
    'Yang Bagus': FontMetadata(fontName: 'Yang Bagus', mainCategory: FontCategory.free, subCategories: [], studio: FontCategory.various),

    // ==================== free/ligatures/UPPERCASE ====================
    'Durendal & Oliphant': FontMetadata(fontName: 'Durendal & Oliphant', mainCategory: FontCategory.free, subCategories: [FontCategory.ligatures, FontCategory.uppercase], studio: null),
    'Syntetic Asrocuus': FontMetadata(fontName: 'Syntetic Asrocuus', mainCategory: FontCategory.free, subCategories: [FontCategory.ligatures, FontCategory.uppercase], studio: null),

 // ==================== free/foreign/languages ====================
     'Noto Sans SC': FontMetadata(fontName: 'Noto Sans SC', mainCategory: FontCategory.free, subCategories: [FontCategory.foreign], studio: null),
     'Noto Sans JP': FontMetadata(fontName: 'Noto Sans JP', mainCategory: FontCategory.free, subCategories: [FontCategory.foreign], studio: null),
     'IBM Plex Sans KR': FontMetadata(fontName: 'IBM Plex Sans KR', mainCategory: FontCategory.free, subCategories: [FontCategory.foreign], studio: null),
     'Gentium': FontMetadata(fontName: 'Gentium', mainCategory: FontCategory.free, subCategories: [FontCategory.foreign], studio: null),
     '0xProto': FontMetadata(fontName: '0xProto', mainCategory: FontCategory.free, subCategories: [FontCategory.foreign], studio: null),
     'Lato': FontMetadata(fontName: 'Lato', mainCategory: FontCategory.free, subCategories: [FontCategory.foreign], studio: null),
     'Scheherazade New': FontMetadata(fontName: 'Scheherazade New', mainCategory: FontCategory.free, subCategories: [FontCategory.foreign], studio: null),

     // ==================== demo/sEeSaWcAsE ====================
       'Devo': FontMetadata(fontName: 'Devo', mainCategory: FontCategory.demo, subCategories: [FontCategory.seesawcase], studio: null),
       'Harquil': FontMetadata(fontName: 'Harquil', mainCategory: FontCategory.demo, subCategories: [FontCategory.seesawcase], studio: null),
       'Sidethree': FontMetadata(fontName: 'Sidethree', mainCategory: FontCategory.demo, subCategories: [FontCategory.seesawcase], studio: null),
       'Zigzageo': FontMetadata(fontName: 'Zigzageo', mainCategory: FontCategory.demo, subCategories: [FontCategory.seesawcase], studio: null),

     // ==================== demo/ligatures/177studio ====================
     'Creating Families demo': FontMetadata(fontName: 'Creating Families demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.studio177),
     'Reminder According demo': FontMetadata(fontName: 'Reminder According demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.studio177),
     'Roommate Surrealism demo': FontMetadata(fontName: 'Roommate Surrealism demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.studio177),
     'Salvador Abstract demo': FontMetadata(fontName: 'Salvador Abstract demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.studio177),
     'Traditional Civilization demo': FontMetadata(fontName: 'Traditional Civilization demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.studio177),

     // ==================== demo/ligatures/Various123 ====================
     'Axaria': FontMetadata(fontName: 'Axaria', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.various123),
     'Carevo': FontMetadata(fontName: 'Carevo', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.various123),
     'Chocolate Chips': FontMetadata(fontName: 'Chocolate Chips', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.various123),
     'Sophia Melanie': FontMetadata(fontName: 'Sophia Melanie', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.various123),
     'Zentaro': FontMetadata(fontName: 'Zentaro', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.various123),

     // ==================== demo/ligatures/Various ====================
     'Rocket Raccoon free': FontMetadata(fontName: 'Rocket Raccoon free', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.various),
     'Souther Daleska demo version': FontMetadata(fontName: 'Souther Daleska demo version', mainCategory: FontCategory.demo, subCategories: [FontCategory.ligatures], studio: FontCategory.various),

     // ==================== demo/missingligatures/177studio ====================
     'Abstract Settings demo': FontMetadata(fontName: 'Abstract Settings demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.missingLigatures], studio: FontCategory.studio177, ligaturePairs: ["as", "be", "de", "es", "ha", "le", "ly", "ne", "of", "op", "pr", "rt", "so", "ur", "ic", "is"]),
     'Creates Presence demo': FontMetadata(fontName: 'Creates Presence demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.missingLigatures], studio: FontCategory.studio177, ligaturePairs: ["ac", "ar", "av", "ch", "di", "ee", "ep", "fe", "ha", "ic", "io", "ju", "li", "ma", "nd", "ns", "om", "or", "pa", "rt", "so", "te", "tr", "ur"]),
     'Coastline Classical demo': FontMetadata(fontName: 'Coastline Classical demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.missingLigatures], studio: FontCategory.studio177, ligaturePairs: ["ac", "ar", "di", "ee", "ha", "me", "ot", "se", "ve"]),
     'Engaging Realities demo': FontMetadata(fontName: 'Engaging Realities demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.missingLigatures], studio: FontCategory.studio177, ligaturePairs: ["ar", "be", "de", "ee", "er", "ge", "ic", "ir", "le", "ma", "mi", "ne", "nt", "of", "or", "pr", "rs", "ss", "ur"]),
     'Titanium Galleries demo': FontMetadata(fontName: 'Titanium Galleries demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.missingLigatures], studio: FontCategory.studio177, ligaturePairs: ["be", "ct", "ed", "er", "fr", "ho", "ir", "ly", "ne", "oc", "ot", "rd", "rt", "st", "tt", "ur"]),

     // ==================== demo/alternates ====================
    'Aloevera': FontMetadata(fontName: 'Aloevera', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),
    'Bentley Vintage': FontMetadata(fontName: 'Bentley Vintage', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),
    'Bisque Veloute demo': FontMetadata(fontName: 'Bisque Veloute demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),
    'Bremlin': FontMetadata(fontName: 'Bremlin', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),
    'Dantene': FontMetadata(fontName: 'Dantene', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),
    'Kambegi': FontMetadata(fontName: 'Kambegi', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),
    'Mount Hills': FontMetadata(fontName: 'Mount Hills', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),
    'Sorean': FontMetadata(fontName: 'Sorean', mainCategory: FontCategory.demo, subCategories: [FontCategory.alternates]),

 // ==================== demo/MustBeUPPERCASE/177studio ====================
     'Children Interests demo': FontMetadata(fontName: 'Children Interests demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.mustBeUppercase], studio: FontCategory.studio177),
     'Intricate Narrative demo': FontMetadata(fontName: 'Intricate Narrative demo', mainCategory: FontCategory.demo, subCategories: [FontCategory.mustBeUppercase], studio: FontCategory.studio177),
    };

   static FontMetadata? getMetadata(String fontName) => _fonts[fontName];

   static List<String> getAllFonts() => _fonts.keys.toList()..sort();

   static List<String> getFontsByMainCategory(String category) {
     return _fonts.entries
         .where((e) => e.value.mainCategory == category)
         .map((e) => e.key)
         .toList()
       ..sort();
   }

   static List<String> getFontsByPath(String mainCat, {String? subCat, String? studio}) {
     return _fonts.entries.where((e) {
       if (e.value.mainCategory != mainCat) return false;
       if (subCat != null && !e.value.subCategories.contains(subCat)) return false;
       if (studio != null && e.value.studio != studio) return false;
       return true;
     }).map((e) => e.key).toList()..sort();
   }

   static Map<String, dynamic> getCategoryTree() {
     final tree = <String, Map<String, Map<String, List<String>>>>{};

     for (var entry in _fonts.entries) {
       final font = entry.value;
       tree.putIfAbsent(font.mainCategory, () => {});

       final subKey = font.subCategories.isEmpty ? 'default' : font.subCategories.first;
       tree[font.mainCategory]!.putIfAbsent(subKey, () => {});

       final studioKey = font.studio ?? 'default';
       tree[font.mainCategory]![subKey]!.putIfAbsent(studioKey, () => []);
       tree[font.mainCategory]![subKey]![studioKey]!.add(entry.key);
     }

     return tree;
   }
 }
