import 'package:flutter/material.dart';

class ConnectionItem {
  final String ar;
  final String en;
  final String ref;
  final String verseArabic;
  final String verseEn;

  ConnectionItem({
    required this.ar,
    required this.en,
    required this.ref,
    required this.verseArabic,
    required this.verseEn,
  });

  factory ConnectionItem.fromJson(Map<String, dynamic> json) {
    return ConnectionItem(
      ar: json['ar'] as String? ?? '',
      en: json['en'] as String? ?? '',
      ref: json['ref'] as String? ?? '',
      verseArabic: json['verse'] as String? ?? '',
      verseEn: json['verseEn'] as String? ?? '',
    );
  }
}

class ConnectionCategory {
  final String name;
  final String nameEn;
  final String colorName;
  final List<ConnectionItem> items;

  ConnectionCategory({
    required this.name,
    required this.nameEn,
    required this.colorName,
    required this.items,
  });

  Color get color {
    switch (colorName) {
      case 'yellow':
        return Colors.amber;
      case 'green':
        return Colors.greenAccent;
      case 'blue':
        return Colors.lightBlueAccent;
      case 'purple':
        return const Color(0xFFCB93F5);
      default:
        return Colors.white70;
    }
  }

  factory ConnectionCategory.fromJson(Map<String, dynamic> json) {
    return ConnectionCategory(
      name: json['name'] as String? ?? '',
      nameEn: json['nameEn'] as String? ?? '',
      colorName: json['color'] as String? ?? '',
      items: (json['items'] as List? ?? [])
          .map((e) => ConnectionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      // Note: the top-level per-category "verse" field is intentionally
      // ignored — it's inconsistent across days (missing after 2026-02-23)
      // and isn't used by this panel.
    );
  }
}

class ConnectionsData {
  final List<ConnectionCategory> categories;

  ConnectionsData({required this.categories});

  static ConnectionsData? tryParse(Map<String, dynamic> dayJson) {
    final c = dayJson['connections'];
    if (c == null) return null;
    final cats = c['categories'];
    if (cats == null) return null;
    return ConnectionsData(
      categories: (cats as List)
          .map((e) => ConnectionCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ScrambleData {
  final String reference;
  final String hint;
  final String arabic;
  final String verseEn;
  final String? verseRef;

  ScrambleData({
    required this.reference,
    required this.hint,
    required this.arabic,
    required this.verseEn,
    required this.verseRef,
  });

  static ScrambleData? tryParse(Map<String, dynamic> dayJson) {
    final s = dayJson['scramble'];
    if (s == null) return null;
    return ScrambleData(
      reference: s['reference'] as String? ?? '',
      hint: s['hint'] as String? ?? '',
      arabic: s['arabic'] as String? ?? '',
      verseEn: s['verseEn'] as String? ?? '',
      verseRef: s['verseRef'] as String?,
    );
  }
}
