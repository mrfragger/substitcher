class SavedSearch {
  final String name;
  final String query;
  final String exclude;
  final bool useAnd;

  const SavedSearch({
    required this.name,
    required this.query,
    this.exclude = '',
    this.useAnd = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'query': query,
        'exclude': exclude,
        'useAnd': useAnd,
      };

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
        name: j['name'] as String,
        query: j['query'] as String,
        exclude: (j['exclude'] as String?) ?? '',
        useAnd: (j['useAnd'] as bool?) ?? true,
      );
}
