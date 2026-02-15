import '../models/lut_item.dart';
import '../data/lut_list.dart';

class LutManager {
  static List<LutItem> _cachedLuts = [];
  
  static Future<List<LutItem>> scanLuts() async {
    if (_cachedLuts.isNotEmpty) return _cachedLuts;
    
    final luts = lutList.map((data) => LutItem(
      name: data['name']!,
      path: data['path']!,
    )).toList();
    
    luts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    
    _cachedLuts = luts;
    print('Loaded ${luts.length} LUTs from hardcoded list');
    return luts;
  }
  
  static void clearCache() {
    _cachedLuts.clear();
  }
}