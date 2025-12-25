class AudioFile {
  final String path;
  final String filename;
  final Duration duration;
  final String originalTitle;
  String editedTitle;
  
  AudioFile({
    required this.path,
    required this.filename,
    required this.duration,
    required this.originalTitle,
    String? editedTitle,
  }) : editedTitle = editedTitle ?? originalTitle;
  
  String get displayTitle => editedTitle;
  
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