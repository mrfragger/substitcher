import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/white_days.dart';

class WhiteDaysService {
  static const _cacheKey = 'white_days_cache';
  static const _timestampKey = 'white_days_timestamp';
  static const _cacheDuration = Duration(days: 7);
  
  static Future<WhiteDays?> getWhiteDays() async {
    final cached = await _getCachedWhiteDays();
    if (cached != null) {
      return cached;
    }
    
    return await _fetchWhiteDays();
  }

  static Future<DateTime?> getCacheTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_timestampKey);
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }
  
  static Future<WhiteDays?> _getCachedWhiteDays() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_timestampKey);
    final cacheJson = prefs.getString(_cacheKey);
    
    if (timestamp == null || cacheJson == null) return null;
    
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    
    if (now.difference(cacheTime) < _cacheDuration) {
      try {
        final json = jsonDecode(cacheJson) as Map<String, dynamic>;
        final whiteDays = WhiteDays.fromJson(json);
        
        final lastDay = whiteDays.days.last;
        final lastDate = DateTime.parse(lastDay.formattedDate);
        final daysSinceLastWhiteDay = now.difference(lastDate).inDays;
        
        if (daysSinceLastWhiteDay <= 1) {
          return whiteDays;
        }
      } catch (e) {
        print('Error parsing cached white days: $e');
      }
    }
    
    return null;
  }
  
  static Future<WhiteDays?> _fetchWhiteDays() async {
    try {
      final today = DateTime.now();
      final todayStr = '${today.day.toString().padLeft(2, '0')}-${today.month.toString().padLeft(2, '0')}-${today.year}';
      
      final gToHUrl = 'http://api.aladhan.com/v1/gToH?date=$todayStr';
      final gToHResponse = await http.get(Uri.parse(gToHUrl));
      
      if (gToHResponse.statusCode != 200) return null;
      
      final gToHData = jsonDecode(gToHResponse.body);
      final hijriData = gToHData['data']['hijri'];
      final hijriDay = int.parse(hijriData['day']);
      final hijriMonth = hijriData['month']['number'] as int;
      final hijriYear = hijriData['year'] as String;
      final hijriMonthName = hijriData['month']['en'] as String;
      
      int targetMonth;
      int targetYear;
      String targetMonthName;
      
      if (hijriDay > 15) {
        targetMonth = hijriMonth < 12 ? hijriMonth + 1 : 1;
        targetYear = hijriMonth < 12 ? int.parse(hijriYear) : int.parse(hijriYear) + 1;
        
        final hToGUrl = 'http://api.aladhan.com/v1/hToG?date=1-$targetMonth-$targetYear';
        final hToGResponse = await http.get(Uri.parse(hToGUrl));
        
        if (hToGResponse.statusCode != 200) return null;
        
        final hToGData = jsonDecode(hToGResponse.body);
        targetMonthName = hToGData['data']['hijri']['month']['en'] as String;
      } else {
        targetMonth = hijriMonth;
        targetYear = int.parse(hijriYear);
        targetMonthName = hijriMonthName;
      }
      
      final whiteDays = <WhiteDay>[];
      
      for (final day in [13, 14, 15]) {
        final hijriDate = '$day-$targetMonth-$targetYear';
        final hToGUrl = 'http://api.aladhan.com/v1/hToG?date=$hijriDate';
        final hToGResponse = await http.get(Uri.parse(hToGUrl));
        
        if (hToGResponse.statusCode != 200) continue;
        
        final hToGData = jsonDecode(hToGResponse.body);
        final gregorianInfo = hToGData['data']['gregorian'];
        
        final originalDate = gregorianInfo['date'] as String;
        final parts = originalDate.split('-');
        final formattedDate = '${parts[2]}-${parts[1]}-${parts[0]}';
        
        final weekdayFull = gregorianInfo['weekday']['en'] as String;
        final weekdayAbbr = weekdayFull.substring(0, 3);
        
        whiteDays.add(WhiteDay(
          hijriDay: day,
          weekdayAbbr: weekdayAbbr,
          formattedDate: formattedDate,
        ));
      }
      
      final result = WhiteDays(
        monthName: targetMonthName,
        year: targetYear,
        days: whiteDays,
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(result.toJson()));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      
      return result;
    } catch (e) {
      print('Error fetching white days: $e');
      return null;
    }
  }
}