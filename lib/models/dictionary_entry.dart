class DictionaryEntry {
  final String word;
  final String reading;
  final List<String> meanings;
  final String? partOfSpeech;
  final int frequency;

  DictionaryEntry({
    required this.word,
    required this.reading,
    required this.meanings,
    this.partOfSpeech,
    this.frequency = 0,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      word: json['word'] as String,
      reading: json['reading'] as String,
      meanings: (json['meanings'] as String).split('|'),
      partOfSpeech: json['pos'] as String?,
      frequency: json['frequency'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'reading': reading,
    'meanings': meanings.join('|'),
    'pos': partOfSpeech,
    'frequency': frequency,
  };
}