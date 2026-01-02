import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;

class PlaylistManager {
  List<String> playlist = [];
  String? playlistRootDir;
  List<String> playlistDirectories = [];
  int? activePlaylistIndex;
  Map<String, String> durationCache = {};
  
  Future<void> loadPlaylistDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    final dirs = prefs.getStringList('playlistDirectories') ?? [];
    final activeIndex = prefs.getInt('activePlaylistIndex');
    
    playlistDirectories = dirs;
    activePlaylistIndex = activeIndex;
    
    if (activePlaylistIndex != null && 
        activePlaylistIndex! < playlistDirectories.length) {
      await scanPlaylist(playlistDirectories[activePlaylistIndex!]);
    }
  }
  
  Future<void> savePlaylistDirectories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('playlistDirectories', playlistDirectories);
    if (activePlaylistIndex != null) {
      await prefs.setInt('activePlaylistIndex', activePlaylistIndex!);
    } else {
      await prefs.remove('activePlaylistIndex');
    }
  }
  
  Future<void> addPlaylistDirectory(String dirPath) async {
    if (playlistDirectories.length >= 10) {
      throw Exception('Maximum 10 playlist directories allowed');
    }
    
    if (playlistDirectories.contains(dirPath)) {
      throw Exception('Directory already added');
    }
    
    playlistDirectories.add(dirPath);
    if (activePlaylistIndex == null) {
      activePlaylistIndex = 0;
    }
    
    await savePlaylistDirectories();
    
    if (activePlaylistIndex == playlistDirectories.length - 1) {
      await scanPlaylist(dirPath);
    }
  }
  
  Future<void> removePlaylistDirectory(int index) async {
    playlistDirectories.removeAt(index);
    
    if (activePlaylistIndex == index) {
      activePlaylistIndex = playlistDirectories.isNotEmpty ? 0 : null;
      if (activePlaylistIndex != null) {
        await scanPlaylist(playlistDirectories[activePlaylistIndex!]);
      } else {
        playlist.clear();
      }
    } else if (activePlaylistIndex != null && activePlaylistIndex! > index) {
      activePlaylistIndex = activePlaylistIndex! - 1;
    }
    
    await savePlaylistDirectories();
  }
  
  Future<void> setActivePlaylist(int index) async {
    if (index >= playlistDirectories.length) return;
    
    activePlaylistIndex = index;
    await savePlaylistDirectories();
    await scanPlaylist(playlistDirectories[index]);
  }
  
  Future<void> scanPlaylist(String dirPath) async {
    final files = <String>[];
    final dir = Directory(dirPath);
  
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.opus')) {
        files.add(entity.path);
      }
    }
  
    files.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  
    playlist = files;
    playlistRootDir = dirPath;
  }
  
  Future<void> loadDurationCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString('durationCache');
    
    if (cacheJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(cacheJson);
        durationCache.clear();
        decoded.forEach((key, value) {
          durationCache[key] = value.toString();
        });
      } catch (e) {
        print('Error loading duration cache: $e');
      }
    }
  }
  
  Future<void> saveDurationCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = <String, String>{};
    
    durationCache.forEach((key, value) {
      cacheData[key] = value;
    });
    
    await prefs.setString('durationCache', jsonEncode(cacheData));
  }
  
  String getRelativePath(String fullPath) {
    if (playlistRootDir == null) return fullPath;

    if (fullPath.startsWith(playlistRootDir!)) {
      return fullPath.substring(playlistRootDir!.length + 1);
    }
    return fullPath;
  }
  
  String shortenPath(String fullPath) {
    final home = Platform.environment['HOME'] ?? '/Users/${Platform.environment['USER']}';
    if (fullPath.startsWith(home)) {
      return fullPath.replaceFirst(home, '~');
    }
    return fullPath;
  }
}