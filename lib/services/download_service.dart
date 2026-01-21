import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'youtube_service.dart';

class DownloadService {
  static const String _downloadDirKey = 'download_directory';
  static Process? _currentProcess;
  static bool _cancelRequested = false;
  
  static Future<String?> getSavedDownloadDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_downloadDirKey);
  }
  
  static Future<void> saveDownloadDirectory(String dir) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_downloadDirKey, dir);
  }
  
  static Future<String> getDefaultDownloadDirectory() async {
    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      return path.join(home!, 'Downloads');
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      return path.join(userProfile!, 'Downloads');
    }
    return Directory.current.path;
  }
  
  static void cancelDownload() {
    _cancelRequested = true;
    _currentProcess?.kill();
  }
  
  static Future<bool> isPlaylist(String url) async {
    return url.contains('list=') || 
           url.contains('/playlist') || 
           url.contains('/videos');
  }
  
  static Future<Map<String, String>?> getPlaylistInfo(String url) async {
    try {
      if (YouTubeService.ytdlpPath == null && 
          !await YouTubeService.isYtdlpAvailable()) {
        return null;
      }
      
      final result = await Process.run(
        YouTubeService.ytdlpPath!,
        [
          '--flat-playlist',
          '--dump-single-json',
          url,
        ],
      );
      
      if (result.exitCode == 0) {
        final json = jsonDecode(result.stdout.toString());
        return {
          'channel': json['channel'] ?? json['uploader'] ?? 'Unknown',
          'title': (json['title'] ?? 'Playlist').replaceAll('/', ' - '),
        };
      }
    } catch (e) {
      print('Error getting playlist info: $e');
    }
    return null;
  }
  
  static Future<List<String>> getAvailableFormats(
    String url, {
    int? playlistItem,
  }) async {
    try {
      if (YouTubeService.ytdlpPath == null && 
          !await YouTubeService.isYtdlpAvailable()) {
        return ['Error: yt-dlp not found'];
      }
      
      final args = ['-F'];
      
      if (playlistItem != null) {
        args.addAll(['--playlist-items', playlistItem.toString()]);
      }
      
      args.add(url);
      
      final result = await Process.run(
        YouTubeService.ytdlpPath!,
        args,
      );
      
      if (result.exitCode == 0) {
        return result.stdout.toString().split('\n').where((line) => 
          line.trim().isNotEmpty && !line.startsWith('[')
        ).toList();
      }
    } catch (e) {
      print('Error getting formats: $e');
    }
    return ['Error: Could not fetch formats'];
  }
  
  static Future<Map<String, dynamic>> _findMissingItems(String outputDir, String url, bool reversePlaylist) async {
    final dir = Directory(outputDir);
    if (!await dir.exists()) {
      return {'missing': <String>[], 'nextStart': 1, 'hasMore': true};
    }
    
    final files = await dir.list().toList();
    final numbers = <int>[];
    
    for (final file in files) {
      if (file is File) {
        final filename = path.basename(file.path);
        final match = RegExp(r'^(\d+)\s').firstMatch(filename);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null) {
            numbers.add(num);
          }
        }
      }
    }
    
    if (numbers.isEmpty) {
      return {'missing': <String>[], 'nextStart': 1, 'hasMore': true};
    }
    
    numbers.sort();
    final minNum = numbers.first;
    final maxNum = numbers.last;
    final missing = <String>[];
    
    List<String> currentRange = [];
    
    for (int i = minNum; i <= maxNum; i++) {
      if (!numbers.contains(i)) {
        if (currentRange.isEmpty) {
          currentRange.add(i.toString());
        } else {
          final lastNum = int.parse(currentRange.last.split(':').last);
          if (lastNum == i - 1) {
            currentRange[0] = '${currentRange[0].split(':').first}:$i';
          } else {
            missing.add(currentRange.last);
            currentRange = [i.toString()];
          }
        }
      } else if (currentRange.isNotEmpty) {
        missing.add(currentRange.last);
        currentRange = [];
      }
    }
    
    if (currentRange.isNotEmpty) {
      missing.add(currentRange.last);
    }
    
    int? totalItems;
    try {
      if (YouTubeService.ytdlpPath != null) {
        final result = await Process.run(
          YouTubeService.ytdlpPath!,
          [
            '--flat-playlist',
            '--dump-single-json',
            url,
          ],
        );
        
        if (result.exitCode == 0) {
          final json = jsonDecode(result.stdout.toString());
          totalItems = json['playlist_count'] ?? (json['entries'] as List?)?.length;
        }
      }
    } catch (e) {
      print('Error getting playlist count: $e');
    }
    
    final hasMore = totalItems != null && maxNum < totalItems;
    
    return {
      'missing': missing,
      'nextStart': maxNum + 1,
      'minDownloaded': minNum,
      'maxDownloaded': maxNum,
      'totalItems': totalItems,
      'hasMore': hasMore,
      'downloadedCount': numbers.length,
    };
  }
  
  static Future<bool> downloadYouTubeAudio({
    required String youtubeUrl,
    String? customDirectory,
    String format = '139',
    bool isPlaylist = false,
    bool reversePlaylist = true,
    bool noPlaylist = false,
    bool splitChapters = false,
    bool enableSleepInterval = false,
    bool downloadAllPlaylists = false,
    String? playlistItemsRange,
    String? channelName,
    String? playlistTitle,
    bool resumeMode = false,
    Function(String)? onProgress,
    Function(String)? onError,
  }) async {
    _cancelRequested = false;
    _currentProcess = null;
    
    try {
      if (YouTubeService.ytdlpPath == null && 
          !await YouTubeService.isYtdlpAvailable()) {
        throw Exception('yt-dlp not found. Please install yt-dlp.');
      }
      
      String downloadDir;
      if (customDirectory != null) {
        downloadDir = customDirectory;
      } else {
        downloadDir = await getSavedDownloadDirectory() ?? 
                     await getDefaultDownloadDirectory();
      }
      
      String outputDir;
      String outputTemplate;
      
      if (isPlaylist) {
        final channel = channelName ?? 'Unknown_Channel';
        final playlist = playlistTitle ?? 'Playlist';
        
        if (downloadAllPlaylists) {
          outputDir = path.join(downloadDir, 'playlistaudio', channel);
          outputTemplate = '%(playlist)s/%(playlist_autonumber)s %(title)s %(upload_date)s.%(ext)s';
        } else {
          outputDir = path.join(downloadDir, 'playlistaudio', channel, playlist);
          outputTemplate = '%(playlist_autonumber)s %(title)s %(upload_date)s.%(ext)s';
        }
      } else {
        final title = await YouTubeService.getVideoTitle(youtubeUrl);
        final safeTitle = YouTubeService.sanitizeFilename(title);
        outputDir = path.join(downloadDir, safeTitle);
        outputTemplate = '%(title)s.%(ext)s';
      }
      
      await Directory(outputDir).create(recursive: true);
      
      final archiveFile = path.join(outputDir, '.yt-dlp-archive.txt');
      
      String? effectivePlaylistRange = playlistItemsRange;
      if (resumeMode && isPlaylist) {
        onProgress?.call('Checking for missing items...');
        final missingInfo = await _findMissingItems(outputDir, youtubeUrl, reversePlaylist);
        final missingRanges = missingInfo['missing'] as List<String>;
        final nextStart = missingInfo['nextStart'] as int;
        final maxDownloaded = missingInfo['maxDownloaded'] as int?;
        final downloadedCount = missingInfo['downloadedCount'] as int;
        final totalItems = missingInfo['totalItems'] as int?;
        final hasMore = missingInfo['hasMore'] as bool;
        
        if (missingRanges.isEmpty && !hasMore) {
          onProgress?.call('No missing items found. All files appear to be downloaded.');
          if (totalItems != null) {
            onProgress?.call('Downloaded: $downloadedCount / $totalItems items');
          }
          return true;
        }
        
        final rangesToDownload = <String>[];
        
        if (missingRanges.isNotEmpty) {
          rangesToDownload.addAll(missingRanges);
          onProgress?.call('Found missing items within downloaded range: ${missingRanges.join(', ')}');
        }
        
        if (hasMore && totalItems != null && maxDownloaded != null) {
          final remaining = '$nextStart:$totalItems';
          rangesToDownload.add(remaining);
          final remainingCount = totalItems - maxDownloaded;
          
          if (reversePlaylist) {
            onProgress?.call('Downloaded $downloadedCount items (newest $downloadedCount videos)');
            onProgress?.call('Found $remainingCount remaining items (older videos): $remaining');
          } else {
            onProgress?.call('Downloaded $downloadedCount items (oldest $downloadedCount videos)');
            onProgress?.call('Found $remainingCount remaining items (newer videos): $remaining');
          }
        }
        
        if (rangesToDownload.isEmpty) {
          onProgress?.call('All items downloaded!');
          return true;
        }
        
        effectivePlaylistRange = rangesToDownload.join(',');
        onProgress?.call('Will attempt to download: $effectivePlaylistRange');
      }
      
      onProgress?.call('Downloading to: $outputDir');
      onProgress?.call('Format: $format');
      
      final args = <String>[
        '-f', format,
        '-o', path.join(outputDir, outputTemplate),
        '--download-archive', archiveFile,
        '--no-overwrites',
        '--ignore-errors',
        '--no-abort-on-error',
      ];
      
      if (isPlaylist) {
        if (reversePlaylist && !noPlaylist) {
          args.add('--playlist-reverse');
        }
        
        if (noPlaylist) {
          args.add('--no-playlist');
        }
        
        if (splitChapters) {
          args.add('--split-chapters');
        }
        
        if (enableSleepInterval) {
          args.addAll([
            '--sleep-interval', '5',
            '--max-sleep-interval', '10',
          ]);
        }
        
        if (effectivePlaylistRange != null && effectivePlaylistRange.isNotEmpty) {
          args.addAll(['--playlist-items', effectivePlaylistRange]);
        }
      } else {
        args.add('--no-playlist');
      }
      
      args.add(youtubeUrl);
      
      if (resumeMode) {
        onProgress?.call('RESUME MODE: Downloading missing items only');
      }
      onProgress?.call('Starting download...');
      onProgress?.call('Command: yt-dlp ${args.join(' ')}');
      onProgress?.call('');
      
      _currentProcess = await Process.start(
        YouTubeService.ytdlpPath!,
        args,
      );
      
      int successCount = 0;
      int errorCount = 0;
      int skippedCount = 0;
      
      _currentProcess!.stdout.transform(utf8.decoder).listen((data) {
        if (_cancelRequested) return;
        
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onProgress?.call(line.trim());
            
            if (line.contains('has already been downloaded')) {
              skippedCount++;
            } else if (line.contains('has already been recorded in the archive')) {
              skippedCount++;
            } else if (line.contains('[download]') && line.contains('Destination:')) {
              successCount++;
            } else if (line.contains('ERROR:')) {
              errorCount++;
            }
          }
        }
      });
      
      _currentProcess!.stderr.transform(utf8.decoder).listen((data) {
        if (_cancelRequested) return;
        
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            if (line.contains('ERROR')) {
              errorCount++;
            }
            onProgress?.call(line.trim());
          }
        }
      });
      
      final exitCode = await _currentProcess!.exitCode;
      
      if (_cancelRequested) {
        onProgress?.call('');
        onProgress?.call('⚠ Download canceled by user');
        return false;
      }
      
      onProgress?.call('');
      onProgress?.call('Download process completed.');
      
      if (skippedCount > 0) {
        onProgress?.call('⚠ $skippedCount items were already downloaded (skipped)');
      }
      
      if (errorCount > 0) {
        onProgress?.call('⚠ $errorCount items failed or were unavailable');
        onProgress?.call('You can try Resume Download to attempt missing items again');
      }
      
      if (exitCode == 0 || successCount > 0) {
        onProgress?.call('✓ Download completed!');
        onProgress?.call('Location: $outputDir');
        
        if (isPlaylist && !noPlaylist) {
          final missingInfo = await _findMissingItems(outputDir, youtubeUrl, reversePlaylist);
          final stillMissing = missingInfo['missing'] as List<String>;
          final hasMore = missingInfo['hasMore'] as bool;
          final totalItems = missingInfo['totalItems'] as int?;
          final downloadedCount = missingInfo['downloadedCount'] as int;
          
          if (stillMissing.isNotEmpty) {
            onProgress?.call('');
            onProgress?.call('Note: Some items are still missing: ${stillMissing.join(', ')}');
          }
          
          if (totalItems != null) {
            onProgress?.call('Progress: $downloadedCount / $totalItems items downloaded');
            
            if (hasMore) {
              final remaining = totalItems - downloadedCount;
              onProgress?.call('$remaining items remaining');
            }
          }
          
          if (stillMissing.isNotEmpty || hasMore) {
            onProgress?.call('Use Resume Download to continue');
          } else if (totalItems != null && downloadedCount == totalItems) {
            onProgress?.call('✓ All $totalItems items downloaded!');
          }
        }
        
        return true;
      } else {
        onError?.call('Download failed with exit code: $exitCode');
        return false;
      }
      
    } catch (e) {
      if (_cancelRequested) {
        onProgress?.call('Download canceled');
        return false;
      }
      onError?.call('Error: $e');
      return false;
    } finally {
      _currentProcess = null;
      _cancelRequested = false;
    }
  }
}