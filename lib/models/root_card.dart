class RootForm {
  final String form;
  final String? diacritized;
  final int count;

  const RootForm({
    required this.form,
    this.diacritized,
    required this.count,
  });

  factory RootForm.fromJson(Map<String, dynamic> j) => RootForm(
        form: j['form'] as String,
        diacritized: j['d'] as String?,
        count: (j['c'] as int?) ?? 0,
      );
}

class RootLemma {
  final String lemma;
  final int frequency;
  final List<RootForm> forms;

  const RootLemma({
    required this.lemma,
    required this.frequency,
    required this.forms,
  });

  factory RootLemma.fromJson(Map<String, dynamic> j) => RootLemma(
        lemma: j['lemma'] as String,
        frequency: (j['frequency'] as int?) ?? 0,
        forms: ((j['forms'] as List?) ?? const [])
            .map((f) => RootForm.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
}

class RootCard {
  final String root;
  final String rootBw;
  final String meaning;
  final String family;
  final int frequency;
  final List<RootLemma> vocab;

  const RootCard({
    required this.root,
    required this.rootBw,
    required this.meaning,
    required this.family,
    required this.frequency,
    required this.vocab,
  });

  factory RootCard.fromJson(Map<String, dynamic> j) => RootCard(
        root: j['root'] as String,
        rootBw: (j['root_bw'] as String?) ?? '',
        meaning: (j['meaning'] as String?) ?? '',
        family: (j['family'] as String?) ?? '',
        frequency: (j['frequency'] as int?) ?? 0,
        vocab: ((j['vocab'] as List?) ?? const [])
            .map((v) => RootLemma.fromJson(v as Map<String, dynamic>))
            .toList(),
      );
}
