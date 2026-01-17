class Bookmark {
  final String audiobookPath;
  final String audiobookTitle;
  final String chapterTitle;
  final int chapterIndex;
  final Duration position;
  final DateTime created;
  final String? note;
  final int? pinNumber;

  Bookmark({
    required this.audiobookPath,
    required this.audiobookTitle,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.position,
    required this.created,
    this.note,
    this.pinNumber,
  });

  Bookmark copyWith({
    String? audiobookPath,
    String? audiobookTitle,
    String? chapterTitle,
    int? chapterIndex,
    Duration? position,
    DateTime? created,
    String? note,
    int? pinNumber,
    bool clearPin = false,
  }) {
    return Bookmark(
      audiobookPath: audiobookPath ?? this.audiobookPath,
      audiobookTitle: audiobookTitle ?? this.audiobookTitle,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      position: position ?? this.position,
      created: created ?? this.created,
      note: note ?? this.note,
      pinNumber: clearPin ? null : (pinNumber ?? this.pinNumber),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audiobookPath': audiobookPath,
      'audiobookTitle': audiobookTitle,
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex,
      'position': position.inMilliseconds,
      'created': created.toIso8601String(),
      'note': note,
      'pinNumber': pinNumber,
    };
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      audiobookPath: json['audiobookPath'] as String,
      audiobookTitle: json['audiobookTitle'] as String,
      chapterTitle: json['chapterTitle'] as String,
      chapterIndex: json['chapterIndex'] as int,
      position: Duration(milliseconds: json['position'] as int),
      created: DateTime.parse(json['created'] as String),
      note: json['note'] as String?,
      pinNumber: json['pinNumber'] as int?,
    );
  }
}