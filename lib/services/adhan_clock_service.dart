import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/adhan_settings.dart';
import '../models/prayer_times.dart';
import 'location_service.dart';

class AdhanClockService {
  bool _isInitialized = false;
  AdhanSettings? _settings;
  PrayerTimes? _prayerTimes;
  Timer? _updateTimer;
  Timer? _checkTimer;
  late final Player _audioPlayer;
  Future<void> Function()? _mainPlayerCallback;
  
  double? _latitude;
  double? _longitude;
  String? _cityName;
  String? _coordinatesSource;
  
  PrayerTimes? get prayerTimes => _prayerTimes;
  String? get cityName => _cityName;
  String? get coordinatesSource => _coordinatesSource;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  
  final _prayerTimesController = StreamController<PrayerTimes?>.broadcast();
  Stream<PrayerTimes?> get prayerTimesStream => _prayerTimesController.stream;

  bool get shouldShowOnStart => _settings?.showOnAppStart ?? false;

  AdhanClockService() {
    _audioPlayer = Player();
  }

 Future<void> initialize() async {
     if (_isInitialized) {
       print('🕌 Already initialized, skipping');
       return;
     }
     _isInitialized = true;
     
     _settings = await AdhanSettings.load();
     
     if (_settings?.adhanClockEnabled != true) {
       print('🕌 Adhan Clock is disabled, skipping initialization');
       return;
     }
     
     await _loadCoordinates();
     
     if (_latitude != null && _longitude != null) {
       await _calculatePrayerTimes();
       _startPeriodicUpdates();
     }
   }
 
 Future<void> _loadCoordinates() async {
   if (!_settings!.autoIpLookup &&
       _settings!.latitude != null && 
       _settings!.longitude != null &&
       _settings!.latitude!.abs() > 0.001 && 
       _settings!.longitude!.abs() > 0.001) {
     _latitude = _settings!.latitude;
     _longitude = _settings!.longitude;
     _cityName = _settings!.cityName;
     _coordinatesSource = 'MANUAL';
     print('🕌 Using manual coordinates: $_cityName ($_latitude, $_longitude)');
     return;
   }
   
   if (_settings!.autoIpLookup) {
     print('🕌 Auto-detect enabled, checking for location...');
     final detected = await LocationService.detectLocationFromIP();
     if (detected != null) {
       _latitude = detected['lat'];
       _longitude = detected['lon'];
       _cityName = detected['city'];
       _coordinatesSource = detected['source'];
       final source = detected['source'] as String;
       print('🕌 Location loaded: ($_latitude, $_longitude) [$source]');
       return;
     }
   }
   
   if (_settings!.latitude != null && 
       _settings!.longitude != null &&
       _settings!.latitude!.abs() > 0.001 && 
       _settings!.longitude!.abs() > 0.001) {
     _latitude = _settings!.latitude;
     _longitude = _settings!.longitude;
     _cityName = _settings!.cityName;
     _coordinatesSource = 'MANUAL (fallback)';
     print('🕌 Using manual coordinates as fallback: $_cityName');
     return;
   }
   
   _coordinatesSource = 'NOT CONFIGURED';
   print('🕌 No location available');
 }
  
  Future<void> autoDetectLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('adhan_ip_cache_date');
    
    final detected = await LocationService.detectLocationFromIP();
    if (detected != null) {
      _latitude = detected['lat'];
      _longitude = detected['lon'];
      _cityName = detected['city'];
      _coordinatesSource = detected['source'];
      print('🕌 Fresh location detected: $_cityName');
      await _calculatePrayerTimes();
    }
  }

  Future<void> applyManualCoordinates(double latitude, double longitude) async {
    _latitude = latitude;
    _longitude = longitude;
    _coordinatesSource = 'MANUAL';
    
    await _calculatePrayerTimes();
  }
  
  void _startPeriodicUpdates() {
    _updateTimer?.cancel();
    _checkTimer?.cancel();
    
    _updateTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      final now = DateTime.now();
      if (now.hour == 0 && now.minute < 5) {
        _calculatePrayerTimes();
      }
    });
    
    _checkTimer = Timer.periodic(Duration(seconds: _settings!.checkInterval), (timer) {
      _checkForPrayerTime();
    });
  }
  
  Future<void> _calculatePrayerTimes() async {
    if (_latitude == null || _longitude == null) return;
    
    final now = DateTime.now();
    final calculator = _PrayerTimeCalculator(
      latitude: _latitude!,
      longitude: _longitude!,
      method: _settings!.calculationMethod,
      asrMethod: _settings!.asrMethod,
    );
    
    _prayerTimes = await calculator.calculate(now);
    _prayerTimesController.add(_prayerTimes);
  }
  
  DateTime? _lastPlayedPrayer;
  
  void _checkForPrayerTime() {
    if (_prayerTimes == null || _settings?.adhanClockEnabled != true) return;
    
    final now = DateTime.now();
    final currentMinute = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    
    if (_lastPlayedPrayer != null && currentMinute == _lastPlayedPrayer) {
      return;
    }
    
    final prayers = [
      ('Fajr', _prayerTimes!.fajr),
      ('Dhuhr', _prayerTimes!.dhuhr),
      ('Asr', _prayerTimes!.asr),
      ('Maghrib', _prayerTimes!.maghrib),
      ('Isha', _prayerTimes!.isha),
      ('Midnight', _prayerTimes!.midnight),
      ('Tahajjud', _prayerTimes!.tahajjud),
    ];
    
    for (final prayer in prayers) {
      final prayerMinute = DateTime(
        prayer.$2.year,
        prayer.$2.month,
        prayer.$2.day,
        prayer.$2.hour,
        prayer.$2.minute,
      );
      
      if (currentMinute == prayerMinute) {
        _lastPlayedPrayer = currentMinute;
        _playAdhan(prayer.$1);
        break;
      }
    }
  }

  void setMainPlayerPauseCallback(Future<void> Function() callback) {
    _mainPlayerCallback = callback;
  }
  
  Future<void> _playAdhan(String prayerName) async {
    if (_settings == null) return;
    
    String? adhanFile;
    switch (prayerName) {
      case 'Fajr': adhanFile = _settings!.fajrAdhan; break;
      case 'Sunrise': adhanFile = _settings!.sunriseAdhan; break;
      case 'Dhuhr': adhanFile = _settings!.dhuhrAdhan; break;
      case 'Asr': adhanFile = _settings!.asrAdhan; break;
      case 'Maghrib': adhanFile = _settings!.maghribAdhan; break;
      case 'Isha': adhanFile = _settings!.ishaAdhan; break;
      case 'Midnight': adhanFile = _settings!.midnightAdhan; break;
      case 'Tahajjud': adhanFile = _settings!.tahajjudAdhan; break;
    }
    
    if (adhanFile == null) return;
    
    String bundlePath;
    
    if (Platform.isMacOS || Platform.isIOS) {
      final executablePath = Platform.resolvedExecutable;
      final appDir = path.dirname(path.dirname(executablePath));
      bundlePath = path.join(
        appDir,
        'Frameworks',
        'App.framework',
        'Resources',
        'flutter_assets',
        'assets',
        'adhanclock',
        adhanFile
      );
    } else if (Platform.isLinux) {
      final executablePath = Platform.resolvedExecutable;
      final appDir = path.dirname(executablePath);
      bundlePath = path.join(appDir, 'data', 'flutter_assets', 'assets', 'adhanclock', adhanFile);
    } else if (Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      final appDir = path.dirname(executablePath);
      bundlePath = path.join(appDir, 'data', 'flutter_assets', 'assets', 'adhanclock', adhanFile);
    } else {
      bundlePath = path.join('assets', 'adhanclock', adhanFile);
    }
    
    print('🕌 Looking for adhan at: $bundlePath');
    
    if (!await File(bundlePath).exists()) {
      print('Adhan file not found: $bundlePath');
      return;
    }
    
    try {
      if (_mainPlayerCallback != null) {
        await _mainPlayerCallback!();
      }
      
      await _audioPlayer.stop();
      
      await _audioPlayer.setVolume(_settings!.volume * 100);
      
      await _audioPlayer.open(Media(bundlePath));
      await _audioPlayer.play();
    } catch (e) {
      print('Error playing adhan: $e');
    }
  }

  Future<void> playTestAdhan(String prayerName) async {
    if (_mainPlayerCallback != null) {
      await _mainPlayerCallback!();
    }
    
    await _playAdhan(prayerName);
  }
  
  Future<void> stopAdhan() async {
    await _audioPlayer.stop();
  }
  
  void dispose() {
    _updateTimer?.cancel();
    _checkTimer?.cancel();
    _audioPlayer.dispose();
    _prayerTimesController.close();
  }
}

class _PrayerTimeCalculator {
  final double latitude;
  final double longitude;
  final String method;
  final String asrMethod;
  
  _PrayerTimeCalculator({
    required this.latitude,
    required this.longitude,
    required this.method,
    required this.asrMethod,
  });
  
  static const _methods = {
    'ISNA': {'fajr': 15.0, 'isha': 15.0},
    'MWL': {'fajr': 18.0, 'isha': 17.0},
    'Egypt': {'fajr': 19.5, 'isha': 17.5},
    'Makkah': {'fajr': 18.5, 'isha_minutes': 90.0},
    'Karachi': {'fajr': 18.0, 'isha': 18.0},
    'Tehran': {'fajr': 17.7, 'isha': 14.0},
  };
  
  Future<PrayerTimes> calculate(DateTime date) async {
    final jd = _julianDay(date);
    final eqt = _equationOfTime(jd);
    final decl = _sunDeclination(jd);
    
    final tzOffset = date.timeZoneOffset.inMinutes / 60.0;
    final solarNoon = 12 - eqt - (longitude / 15) + tzOffset;
    
    final methodData = _methods[method] ?? _methods['ISNA']!;
    
    final fajrAngle = methodData['fajr']!;
    final fajrHA = _hourAngle(decl, -fajrAngle);
    final fajrTime = solarNoon - fajrHA;
    
    final sunriseHA = _hourAngle(decl, -0.833);
    final sunriseTime = solarNoon - sunriseHA;
    
    final dhuhrTime = solarNoon + (1 / 60);
    
    final shadowFactor = asrMethod == 'Hanafi' ? 2.0 : 1.0;
    final asrHA = _asrHourAngle(decl, shadowFactor);
    final asrTime = solarNoon + asrHA;
    
    final maghribTime = solarNoon + sunriseHA;
    
    double ishaTime;
    if (methodData.containsKey('isha_minutes')) {
      ishaTime = maghribTime + (methodData['isha_minutes']! / 60);
    } else {
      final ishaAngle = methodData['isha']!;
      final ishaHA = _hourAngle(decl, -ishaAngle);
      ishaTime = solarNoon + ishaHA;
    }
    
    final nightDuration = (fajrTime < maghribTime) ? (fajrTime + 24) - maghribTime : fajrTime - maghribTime;
    final midnightTime = maghribTime + (nightDuration / 2);
    final tahajjudTime = maghribTime + (nightDuration * 2 / 3);
    
    return PrayerTimes(
      fajr: _timeToDateTime(date, fajrTime),
      sunrise: _timeToDateTime(date, sunriseTime),
      dhuhr: _timeToDateTime(date, dhuhrTime),
      asr: _timeToDateTime(date, asrTime),
      maghrib: _timeToDateTime(date, maghribTime),
      isha: _timeToDateTime(date, ishaTime),
      midnight: _timeToDateTime(date, midnightTime >= 24 ? midnightTime - 24 : midnightTime),
      tahajjud: _timeToDateTime(date, tahajjudTime >= 24 ? tahajjudTime - 24 : tahajjudTime),
    );
  }
  
  double _julianDay(DateTime date) {
    int year = date.year;
    int month = date.month;
    int day = date.day;
    
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    
    return (365.25 * (year + 4716)).floor() +
           (30.6001 * (month + 1)).floor() +
           day + b - 1524.5;
  }
  
  double _equationOfTime(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * math.sin(_degToRad(g)) + 0.020 * math.sin(_degToRad(2 * g)));
    final e = 23.439 - 0.00000036 * d;
    final ra = math.atan2(math.cos(_degToRad(e)) * math.sin(_degToRad(l)), math.cos(_degToRad(l)));
    final eqt = (q / 15) - (_radToDeg(ra) / 15);
    return _fixHour(eqt);
  }
  
  double _sunDeclination(double jd) {
    final d = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * d);
    final q = _fixAngle(280.459 + 0.98564736 * d);
    final l = _fixAngle(q + 1.915 * math.sin(_degToRad(g)) + 0.020 * math.sin(_degToRad(2 * g)));
    final e = 23.439 - 0.00000036 * d;
    return math.asin(math.sin(_degToRad(e)) * math.sin(_degToRad(l)));
  }
  
  double _hourAngle(double declination, double sunAltitude) {
    final latRad = _degToRad(latitude);
    final altRad = _degToRad(sunAltitude);
    
    final cosH = (math.sin(altRad) - math.sin(declination) * math.sin(latRad)) /
                 (math.cos(declination) * math.cos(latRad));
    
    if (cosH > 1 || cosH < -1) return 0;
    
    return _radToDeg(math.acos(cosH)) / 15;
  }

  double _asrHourAngle(double declination, double shadowFactor) {
    final latRad = _degToRad(latitude);
    final cotAltitude = shadowFactor + math.tan((latitude - _radToDeg(declination)).abs() * math.pi / 180);
    final altitude = _radToDeg(math.atan(1 / cotAltitude));
    return _hourAngle(declination, altitude);
  }
  
  double _degToRad(double degrees) => degrees * math.pi / 180;
  double _radToDeg(double radians) => radians * 180 / math.pi;
  
  double _fixAngle(double angle) => angle - 360 * (angle / 360).floor();
  
  double _fixHour(double hour) {
    final h = hour - 24 * (hour / 24).floor();
    return h > 12 ? h - 24 : h;
  }
  
  DateTime _timeToDateTime(DateTime date, double hourDecimal) {
    int hours = hourDecimal.floor();
    int minutes = ((hourDecimal - hours) * 60).floor();
    
    if (hours >= 24) hours -= 24;
    if (hours < 0) hours += 24;
    
    return DateTime(date.year, date.month, date.day, hours, minutes);
  }
}