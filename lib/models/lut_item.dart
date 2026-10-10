enum LUTFilter {
  abigailgonzalez,
  alexjordan,
  berat,
  creative,
  editingcorp,
  ericellerbrock,
  filmsColorslide,
  filmsNegativeColor,
  filmsPrintFuji,
  filmsPrintKodak,
  fujixtransiii,
  inavision,
  jtsemple,
  kylerholland,
  ohadperetz,
  others,
  picturefx,
  pixlsus,
  shamoonabbasi,
  toddblankenship,
  youssefhossam;

  String get prefix => switch (this) {
        LUTFilter.filmsColorslide    => 'films colorslide',
        LUTFilter.filmsNegativeColor => 'films negative color',
        LUTFilter.filmsPrintFuji     => 'films print fuji',
        LUTFilter.filmsPrintKodak    => 'films print kodak',
        _ => name,
      };

  String get label => switch (this) {
        LUTFilter.filmsColorslide    => 'films colorslide',
        LUTFilter.filmsNegativeColor => 'films negative color',
        LUTFilter.filmsPrintFuji     => 'films print fuji',
        LUTFilter.filmsPrintKodak    => 'films print kodak',
        _ => name,
      };
}

class LutItem {
  final String name;
  final String path;

  LutItem({required this.name, required this.path});

  /// e.g. "alexjordan dream 85.cube" → "dream 85"
  String get displayName {
    final withoutCube = name.replaceAll('.cube', '');
    final spaceIdx = withoutCube.indexOf(' ');
    return spaceIdx == -1 ? withoutCube : withoutCube.substring(spaceIdx + 1);
  }

  LUTFilter get category {
    final ordered = LUTFilter.values
        .where((f) => f != LUTFilter.others)
        .toList()
      ..sort((a, b) => b.prefix.length.compareTo(a.prefix.length));

    for (final f in ordered) {
      if (name.startsWith('${f.prefix} ')) return f;
    }
    return LUTFilter.others;
  }
}
