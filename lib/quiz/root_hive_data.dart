class RootHiveRoot {
  final String letters;
  final String display;
  final String translit;
  final String meaning;
  final int occurrences;
  final int lemmaCount;

  RootHiveRoot({
    required this.letters,
    required this.display,
    required this.translit,
    required this.meaning,
    required this.occurrences,
    required this.lemmaCount,
  });

  factory RootHiveRoot.fromJson(Map<String, dynamic> j) => RootHiveRoot(
        letters: j['letters'] as String? ?? '',
        display: j['display'] as String? ?? '',
        translit: j['translit'] as String? ?? '',
        meaning: j['meaning'] as String? ?? '',
        occurrences: (j['occurrences'] as num?)?.toInt() ?? 0,
        lemmaCount: (j['lemmaCount'] as num?)?.toInt() ?? 0,
      );
}

class RootHiveSense {
  final String lemma;
  final String gloss;
  final String type;
  final String root;
  final int count;
  final String ref;
  final int? form;
  final List<String> alt;

  RootHiveSense({
    required this.lemma,
    required this.gloss,
    required this.type,
    required this.root,
    required this.count,
    required this.ref,
    this.form,
    this.alt = const [],
  });

  factory RootHiveSense.fromJson(Map<String, dynamic> j) => RootHiveSense(
        lemma: j['lemma'] as String? ?? '',
        gloss: j['gloss'] as String? ?? '',
        type: j['type'] as String? ?? '',
        root: j['root'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        ref: j['ref'] as String? ?? '',
        form: (j['form'] as num?)?.toInt(),
        alt: List<String>.from(j['alt'] as List? ?? const []),
      );
}

class RootHiveWord {
  final String word;
  final bool family;
  final int points;
  final List<RootHiveSense> senses;

  RootHiveWord({
    required this.word,
    required this.family,
    required this.points,
    required this.senses,
  });

  factory RootHiveWord.fromJson(Map<String, dynamic> j) => RootHiveWord(
        word: j['w'] as String? ?? '',
        family: j['family'] as bool? ?? false,
        points: (j['points'] as num?)?.toInt() ?? 0,
        senses: (j['senses'] as List? ?? [])
            .whereType<Map>()
            .map((e) => RootHiveSense.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class RootHiveData {
  final String center;
  final List<String> outer;
  final RootHiveRoot root;
  final List<RootHiveWord> words;
  final int maxScore;

  RootHiveData({
    required this.center,
    required this.outer,
    required this.root,
    required this.words,
    required this.maxScore,
  });

  List<RootHiveWord> get familyWords =>
      words.where((w) => w.family).toList();
  List<RootHiveWord> get otherWords =>
      words.where((w) => !w.family).toList();

  /// Returns null on days without Root Hive data (before 2026-10-03).
  static RootHiveData? tryParse(Map<String, dynamic> dayJson) {
    final raw = dayJson['roothive'];
    if (raw is! Map) return null;
    try {
      final j = Map<String, dynamic>.from(raw);
      return RootHiveData(
        center: j['center'] as String? ?? '',
        outer: List<String>.from(j['outer'] as List? ?? const []),
        root: RootHiveRoot.fromJson(
            Map<String, dynamic>.from(j['root'] as Map)),
        words: (j['words'] as List? ?? [])
            .whereType<Map>()
            .map((e) => RootHiveWord.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        maxScore: (j['maxScore'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
