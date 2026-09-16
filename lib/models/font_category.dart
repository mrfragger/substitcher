class FontCategory {
  static const String demo123 = 'demo123';
  static const String demo = 'demo';
  static const String free = 'free';
  static const String favorites = 'favorites';
  static const String custom = 'custom';
  static const String custom2 = 'custom2';

  static const String ligatures = 'ligatures';
  static const String missingLigatures = 'missingligatures';
  static const String uppercase = 'uppercase';
  static const String mustBeUppercase = 'mustbeuppercase';
  static const String seesawcase = 'seesawcase';
  static const String foreign = 'foreign';
  static const String alternates = 'alternates';

  static const String studio177 = '177studio';
  static const String gluk = 'Gluk';
  static const String various = 'various';
  static const String various123 = 'various123';
}

class FontMetadata {
  final String fontName;
  final String mainCategory;
  final List<String> subCategories;
  final String? studio;
  final List<String>? ligaturePairs;

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
