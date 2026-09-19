class QuranLemma {
  final int id;
  final String arabic;
  final String translit;
  final String? root;
  final bool hasRootCard;
  final String pos;
  final int count;
  final String tier;
  final String en;
  final String ur;
  final String ps;

  const QuranLemma({
    required this.id,
    required this.arabic,
    required this.translit,
    required this.root,
    required this.hasRootCard,
    required this.pos,
    required this.count,
    required this.tier,
    required this.en,
    required this.ur,
    required this.ps,
  });

  factory QuranLemma.fromJson(Map<String, dynamic> j) => QuranLemma(
        id: j['id'] as int,
        arabic: j['ar'] as String,
        translit: (j['tr'] as String?) ?? '',
        root: j['root'] as String?,
        hasRootCard: (j['has_root_card'] as bool?) ?? false,
        pos: (j['pos'] as String?) ?? '',
        count: (j['count'] as int?) ?? 0,
        tier: (j['tier'] as String?) ?? 'common',
        en: (j['en'] as String?) ?? '',
        ur: (j['ur'] as String?) ?? '',
        ps: (j['ps'] as String?) ?? '',
      );
}
