import 'package:shared_preferences/shared_preferences.dart';

class LutFavoritesService {
  static const _key = 'lut_favorites';

  static LutFavoritesService? _instance;
  static LutFavoritesService get instance =>
      _instance ??= LutFavoritesService._();
  LutFavoritesService._();

  Set<String> _favorites = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _favorites = (prefs.getStringList(_key) ?? []).toSet();
    _loaded = true;
  }

  Future<Set<String>> getFavorites() async {
    await _ensureLoaded();
    return Set.unmodifiable(_favorites);
  }

  bool isFavorite(String lutName) => _favorites.contains(lutName);

  Future<void> toggle(String lutName) async {
    await _ensureLoaded();
    if (_favorites.contains(lutName)) {
      _favorites.remove(lutName);
    } else {
      _favorites.add(lutName);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favorites.toList());
  }

  Future<void> remove(String lutName) async {
    await _ensureLoaded();
    _favorites.remove(lutName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favorites.toList());
  }
}