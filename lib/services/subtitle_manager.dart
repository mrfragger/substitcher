import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/subtitle_cue.dart';
import 'subtitle_organizer.dart';

class SubtitleManager {
  List<SubtitleCue> subtitles = [];
  String currentSubtitleText = '';
  String? subtitleFilePath;
  double subtitleFontSize = 44.0;
  
  Future<void> loadSubtitles(String audiobookPath) async {
    try {
      final dir = path.dirname(audiobookPath);
      await SubtitleOrganizer.organizeAllSubtitlesInDirectory(dir);
      
      final subtitlePath = await SubtitleOrganizer.findSubtitleInDirectory(audiobookPath);
      
      if (subtitlePath == null) {
        print('No subtitle file found for: ${path.basename(audiobookPath)}');
        clear();
        return;
      }
        
      final content = await File(subtitlePath).readAsString();
      final ext = path.extension(subtitlePath).toLowerCase();
      
      subtitles = (ext == '.vtt' || ext == '.vtc')
          ? _parseVTT(content) 
          : _parseSRT(content);

      subtitleFilePath = subtitlePath;
      print('Loaded ${subtitles.length} subtitle cues');
  
    } catch (e) {
      print('Error loading subtitles: $e');
      clear();
    }
  }
  
  void updateCurrentSubtitle(Duration position) {
    if (subtitles.isEmpty) {
      if (currentSubtitleText.isNotEmpty) {
        currentSubtitleText = '';
      }
      return;
    }
  
    for (final cue in subtitles) {
      if (position >= cue.startTime && position < cue.endTime) {
        if (currentSubtitleText != cue.text) {
          currentSubtitleText = cue.text;
        }
        return;
      }
    }
  
    if (currentSubtitleText.isNotEmpty) {
      currentSubtitleText = '';
    }
  }
  
  SubtitleCue? findPreviousSubtitle(Duration position) {
    SubtitleCue? currentCue;
    int currentCueIndex = -1;
    
    for (var i = 0; i < subtitles.length; i++) {
      final cue = subtitles[i];
      if (position >= cue.startTime && position < cue.endTime) {
        currentCue = cue;
        currentCueIndex = i;
        break;
      }
    }
    
    if (currentCue != null) {
      final timeSinceStart = position - currentCue.startTime;
      
      if (timeSinceStart.inMilliseconds > 500) {
        return currentCue;
      } else if (currentCueIndex > 0) {
        return subtitles[currentCueIndex - 1];
      }
    } else {
      for (var i = subtitles.length - 1; i >= 0; i--) {
        if (position > subtitles[i].endTime) {
          return subtitles[i];
        }
      }
      
      if (subtitles.isNotEmpty) {
        return subtitles[0];
      }
    }
    
    return null;
  }
  
  SubtitleCue? findNextSubtitle(Duration position) {
    for (var i = 0; i < subtitles.length; i++) {
      final cue = subtitles[i];
      if (position < cue.startTime) {
        return cue;
      }
    }
    
    if (subtitles.isNotEmpty) {
      return subtitles.last;
    }
    
    return null;
  }
  
  void increaseFontSize() {
    subtitleFontSize = (subtitleFontSize + 4).clamp(20.0, 150.0);
  }
  
  void decreaseFontSize() {
    subtitleFontSize = (subtitleFontSize - 4).clamp(20.0, 150.0);
  }
  
  void clear() {
    subtitles = [];
    subtitleFilePath = null;
    currentSubtitleText = '';
  }
  
  List<SubtitleCue> _parseVTT(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');
  
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final startTime = _parseVTTTime(parts[0].trim());
          final endTime = _parseVTTTime(parts[1].trim().split(' ')[0]);
  
          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }
  
          if (startTime != null && endTime != null && textLines.isNotEmpty) {
            cues.add(SubtitleCue(
              startTime: startTime,
              endTime: endTime,
              text: textLines.join('\n'),
            ));
          }
        }
      }
    }
  
    return cues;
  }

  List<SubtitleCue> _parseSRT(String content) {
    final cues = <SubtitleCue>[];
    final lines = content.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('-->')) {
        final parts = line.split('-->');
        if (parts.length == 2) {
          final startTime = _parseSRTTime(parts[0].trim());
          final endTime = _parseSRTTime(parts[1].trim());

          final textLines = <String>[];
          i++;
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            textLines.add(lines[i].trim());
            i++;
          }

          if (startTime != null && endTime != null && textLines.isNotEmpty) {
            cues.add(SubtitleCue(
              startTime: startTime,
              endTime: endTime,
              text: textLines.join('\n'),
            ));
          }
        }
      }
    }

    return cues;
  }

  Duration? _parseVTTTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) 
            : 0;

        return Duration(
          hours: hours, 
          minutes: minutes, 
          seconds: seconds, 
          milliseconds: milliseconds
        );
      } else if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final secondsParts = parts[1].split('.');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 
            ? int.parse(secondsParts[1].padRight(3, '0').substring(0, 3)) 
            : 0;

        return Duration(
          minutes: minutes, 
          seconds: seconds, 
          milliseconds: milliseconds
        );
      }
    } catch (e) {
      print('Error parsing VTT time "$timeStr": $e');
      return null;
    }
    return null;
  }

  Duration? _parseSRTTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final secondsParts = parts[2].split(',');
        final seconds = int.parse(secondsParts[0]);
        final milliseconds = secondsParts.length > 1 ? int.parse(secondsParts[1]) : 0;

        return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
      }
    } catch (e) {
      print('Error parsing SRT time "$timeStr": $e');
      return null;
    }
    return null;
  }
}