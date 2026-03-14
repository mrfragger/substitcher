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

  /// e.g. "alexjordan dream 85" → "alexjordan"
  String get category {
    final withoutCube = name.replaceAll('.cube', '');
    final spaceIdx = withoutCube.indexOf(' ');
    return spaceIdx == -1 ? withoutCube : withoutCube.substring(0, spaceIdx);
  }
}