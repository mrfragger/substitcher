class HistoryItem {
  final String audiobookPath;
  final String audiobookTitle;
  final String chapterTitle;
  final int lastChapter;
  final Duration lastPosition;
  final DateTime lastPlayed;
  final bool shuffleEnabled;
  final List<int> playedChapters;

  HistoryItem({
    required this.audiobookPath,
    required this.audiobookTitle,
    required this.chapterTitle,
    required this.lastChapter,
    required this.lastPosition,
    required this.lastPlayed,
    required this.shuffleEnabled,
    required this.playedChapters,
  });

  Map<String, dynamic> toJson() {
    return {
      'audiobookPath': audiobookPath,
      'audiobookTitle': audiobookTitle,
      'chapterTitle': chapterTitle,
      'lastChapter': lastChapter,
      'lastPosition': lastPosition.inMilliseconds,
      'lastPlayed': lastPlayed.toIso8601String(),
      'shuffleEnabled': shuffleEnabled,
      'playedChapters': playedChapters,
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      audiobookPath: json['audiobookPath'] as String,
      audiobookTitle: json['audiobookTitle'] as String,
      chapterTitle: json['chapterTitle'] as String,
      lastChapter: json['lastChapter'] as int,
      lastPosition: Duration(milliseconds: json['lastPosition'] as int),
      lastPlayed: DateTime.parse(json['lastPlayed'] as String),
      shuffleEnabled: json['shuffleEnabled'] as bool? ?? false,
      playedChapters: (json['playedChapters'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }
}