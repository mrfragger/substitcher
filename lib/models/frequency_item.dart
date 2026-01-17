class FrequencyItem {
  final String text;
  final int frequency;
  final int wordCount;

  FrequencyItem({
    required this.text,
    required this.frequency,
    required this.wordCount,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'frequency': frequency,
    'wordCount': wordCount,
  };

  factory FrequencyItem.fromJson(Map<String, dynamic> json) {
    return FrequencyItem(
      text: json['text'],
      frequency: json['frequency'],
      wordCount: json['wordCount'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrequencyItem &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          frequency == other.frequency;

  @override
  int get hashCode => text.hashCode ^ frequency.hashCode;
}