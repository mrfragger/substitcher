class DeductionCategory {
  final String key;
  final String label;
  final List<String> options;
  final String answer;

  DeductionCategory({
    required this.key,
    required this.label,
    required this.options,
    required this.answer,
  });

  factory DeductionCategory.fromJson(String key, Map<String, dynamic> json) {
    return DeductionCategory(
      key: key,
      label: json['label'] as String,
      options: List<String>.from(json['options'] as List),
      answer: json['answer'] as String,
    );
  }
}

class DeductionData {
  final String title;
  final String intro;
  final List<String> clues;
  final List<DeductionCategory> categories;
  final String verseEn;
  final String verseArabic;
  final String? verseRef; // e.g. "27:44", parsed out of the verseEn text

  DeductionData({
    required this.title,
    required this.intro,
    required this.clues,
    required this.categories,
    required this.verseEn,
    required this.verseArabic,
    required this.verseRef,
  });

  factory DeductionData.fromJson(Map<String, dynamic> json) {
    final catJson = json['categories'] as Map<String, dynamic>;
    final verseEn = json['verse'] as String? ?? '';
    String? verseRef = json['verseRef'] as String?;
    if (verseRef == null) {
      final refMatch = RegExp(r'(\d{1,3}:\d{1,3}(?:-\d{1,3})?)\)?\s*$').firstMatch(verseEn);
      verseRef = refMatch?.group(1);
    }
    return DeductionData(
      title: json['title'] as String? ?? '',
      intro: json['intro'] as String? ?? '',
      clues: List<String>.from(json['clues'] as List? ?? []),
      categories: catJson.entries
          .map((e) => DeductionCategory.fromJson(
              e.key, e.value as Map<String, dynamic>))
          .toList(),
      verseEn: verseEn,
      verseArabic: json['arabic'] as String? ?? '',
      verseRef: verseRef,
    );
  }

  /// Returns null if this day's file has no deduction puzzle.
  static DeductionData? tryParse(Map<String, dynamic> dayJson) {
    final d = dayJson['deduction'];
    if (d == null) return null;
    return DeductionData.fromJson(d as Map<String, dynamic>);
  }
}
