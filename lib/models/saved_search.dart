class SavedSearch {
  final String name;
  final String query;
  final String exclude;

  const SavedSearch({
    required this.name,
    required this.query,
    this.exclude = '',
  });

  Map<String, dynamic> toJson() =>
      {'name': name, 'query': query, 'exclude': exclude};

  factory SavedSearch.fromJson(Map<String, dynamic> j) => SavedSearch(
        name: j['name'] as String,
        query: j['query'] as String,
        exclude: (j['exclude'] as String?) ?? '',
      );
}
