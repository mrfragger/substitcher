import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static Future<Map<String, dynamic>?> detectLocationFromIP() async {
    final cached = await getCachedLocation();
    if (cached != null) {
      print('🕌 Using cached location (valid for 30 days)');
      return cached;
    }
    
    print('🕌 Cache expired or missing, performing IP lookup...');
    
    final services = [
      _IPApiService(),
      _IPInfoService(),
      _KeyCDNService(),
    ];
    
    for (final service in services) {
      try {
        final result = await service.detect();
        if (result != null) {
          await cacheLocation(result['lat'], result['lon'], result['city']);
          return result;
        }
      } catch (e) {
        print('Location service ${service.runtimeType} failed: $e');
      }
    }
    
    return null;
  }
  
  static Future<Map<String, dynamic>?> getCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheDate = prefs.getString('adhan_ip_cache_date');
    
    if (cacheDate != null) {
      final cached = DateTime.parse(cacheDate);
      final now = DateTime.now();
      final daysDiff = now.difference(cached).inDays;
      
      if (daysDiff < 30) {  // Cache valid for 30 days
        final lat = prefs.getDouble('adhan_ip_cache_lat');
        final lon = prefs.getDouble('adhan_ip_cache_lon');
        final city = prefs.getString('adhan_ip_cache_city');
        
        if (lat != null && lon != null) {
          return {'lat': lat, 'lon': lon, 'city': city, 'source': 'CACHED'};
        }
      }
    }
    
    return null;
  }
  
  static Future<void> cacheLocation(double lat, double lon, String? city) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();  // Full timestamp for 30-day calculation
    
    await prefs.setString('adhan_ip_cache_date', now);
    await prefs.setDouble('adhan_ip_cache_lat', lat);
    await prefs.setDouble('adhan_ip_cache_lon', lon);
    if (city != null) await prefs.setString('adhan_ip_cache_city', city);
  }
}

abstract class _LocationDetectionService {
  Future<Map<String, dynamic>?> detect();
}

class _IPApiService extends _LocationDetectionService {
  @override
  Future<Map<String, dynamic>?> detect() async {
    final response = await http.get(
      Uri.parse('http://ip-api.com/json/'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'lat': data['lat'],
        'lon': data['lon'],
        'city': data['city'],
        'source': 'ip-api.com',
      };
    }
    return null;
  }
}

class _IPInfoService extends _LocationDetectionService {
  @override
  Future<Map<String, dynamic>?> detect() async {
    final response = await http.get(
      Uri.parse('https://ipinfo.io/json'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final loc = (data['loc'] as String).split(',');
      return {
        'lat': double.parse(loc[0]),
        'lon': double.parse(loc[1]),
        'city': data['city'],
        'source': 'ipinfo.io',
      };
    }
    return null;
  }
}

class _KeyCDNService extends _LocationDetectionService {
  @override
  Future<Map<String, dynamic>?> detect() async {
    final response = await http.get(
      Uri.parse('https://tools.keycdn.com/geo.json'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final geoData = data['data']['geo'];
      return {
        'lat': geoData['latitude'],
        'lon': geoData['longitude'],
        'city': geoData['city'],
        'source': 'keycdn.com',
      };
    }
    return null;
  }
}