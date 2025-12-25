class AudiobookMetadata {
  final String path;
  final String title;
  final String author;
  final String year;
  final Duration duration;
  final List<Chapter> chapters;
  
  AudiobookMetadata({
    required this.path,
    required this.title,
    required this.author,
    required this.year,
    required this.duration,
    required this.chapters,
  });
  
  factory AudiobookMetadata.fromJson(Map<String, dynamic> json) {
    return AudiobookMetadata(
      path: json['path'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      year: json['year'] as String,
      duration: Duration(milliseconds: (json['duration'] as num).toInt()),
      chapters: (json['chapters'] as List)
          .map((c) => Chapter.fromJson(c))
          .toList(),
    );
  }
}

class Chapter {
  final int index;
  final String title;
  final Duration startTime;
  final Duration endTime;
  final Duration duration;
  
  Chapter({
    required this.index,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.duration,
  });
  
  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      index: json['index'] as int,
      title: json['title'] as String,
      startTime: Duration(milliseconds: ((json['start_time'] as num) * 1000).toInt()),
      endTime: Duration(milliseconds: ((json['end_time'] as num) * 1000).toInt()),
      duration: Duration(milliseconds: ((json['duration'] as num) * 1000).toInt()),
    );
  }
  
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }
}