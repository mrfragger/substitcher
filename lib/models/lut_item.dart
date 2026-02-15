class LutItem {
  final String name;
  final String path;
  
  LutItem({
    required this.name,
    required this.path,
  });
  
  String get displayName => name.replaceAll('.cube', '');
}