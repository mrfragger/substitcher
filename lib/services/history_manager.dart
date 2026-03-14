import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';
import '../models/bookmark.dart';

class HistoryManager {
  List<HistoryItem> history = [];
  List<Bookmark> bookmarks = [];
  
  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList('history') ?? [];

    history = historyJson
        .map((jsonStr) {
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            return HistoryItem.fromJson(json);
          } catch (e) {
            return null;
          }
        })
        .whereType<HistoryItem>()
        .toList();
  }

  Future<void> saveToHistory(HistoryItem item) async {
    history.removeWhere((h) => h.audiobookPath == item.audiobookPath);
    history.insert(0, item);

    if (history.length > 20) {
      history = history.sublist(0, 20);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }

  Future<void> removeFromHistory(int index) async {
    history.removeAt(index);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'history',
      history.map((h) => jsonEncode(h.toJson())).toList(),
    );
  }
  
  Future<void> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarksJson = prefs.getStringList('bookmarks') ?? [];

    bookmarks = bookmarksJson
        .map((jsonStr) {
          try {
            final json = jsonDecode(jsonStr) as Map<String, dynamic>;
            return Bookmark.fromJson(json);
          } catch (e) {
            return null;
          }
        })
        .whereType<Bookmark>()
        .toList();
  }

  Future<void> saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'bookmarks',
      bookmarks.map((b) => jsonEncode(b.toJson())).toList(),
    );
  }

  Future<void> addBookmark(Bookmark bookmark) async {
    bookmarks.insert(0, bookmark);
    await saveBookmarks();
  }

  Future<void> removeBookmark(int index) async {
    bookmarks.removeAt(index);
    await saveBookmarks();
  }
  
  Future<void> updateBookmark(int index, Bookmark bookmark) async {
    bookmarks[index] = bookmark;
    await saveBookmarks();
  }
  
  Bookmark? findPinnedBookmark(int pinNumber) {
    try {
      return bookmarks.firstWhere((b) => b.pinNumber == pinNumber);
    } catch (e) {
      return null;
    }
  }
}