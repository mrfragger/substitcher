class FontCategory {
  // Main categories
  static const String demo123 = 'demo123';
  static const String demo = 'demo';
  static const String free = 'free';
  static const String custom = 'custom';
  
  // Sub-categories
  static const String ligatures = 'ligatures';
  static const String missingLigatures = 'missingligatures';
  static const String uppercase = 'uppercase';
  static const String mustBeUppercase = 'mustbeuppercase';
  static const String seesawcase = 'seesawcase';
  static const String foreign = 'foreign';
  static const String alternates = 'alternates';
  
  // Studios/Collections
  static const String studio177 = '177studio';
  static const String putracetol = 'putracetol';
  static const String erifqizefont = 'erifqizefont';
  static const String gluk = 'gluk';
  static const String various = 'various';
  static const String favorites = 'favorites';
}

class FontMetadata {
  final String fontName;
  final String mainCategory; // demo123, demo, free
  final List<String> subCategories; // ligatures, uppercase, etc.
  final String? studio; // 177studio, putracetol, etc.
  final List<String>? ligaturePairs; // For missing ligature fixes
  
  FontMetadata({
    required this.fontName,
    required this.mainCategory,
    this.subCategories = const [],
    this.studio,
    this.ligaturePairs,
  });
  
  bool isDemo() => mainCategory == FontCategory.demo;
  bool isDemo123() => mainCategory == FontCategory.demo123;
  bool isFree() => mainCategory == FontCategory.free;
  
  bool hasLigatures() => subCategories.contains(FontCategory.ligatures);
  bool hasMissingLigatures() => subCategories.contains(FontCategory.missingLigatures);
  bool mustBeUppercase() => subCategories.contains(FontCategory.mustBeUppercase);
  bool isSeesawCase() => subCategories.contains(FontCategory.seesawcase);
  bool hasAlternates() => subCategories.contains(FontCategory.alternates);
  
  String get displayPath {
    final parts = <String>[mainCategory];
    if (subCategories.isNotEmpty) parts.addAll(subCategories);
    if (studio != null) parts.add(studio!);
    parts.add(fontName);
    return parts.join(' > ');
  }
}