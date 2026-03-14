import 'package:shared_preferences/shared_preferences.dart';

class AdhanSettings {
  String cityName;
  double volume;
  String fajrAdhan;
  String sunriseAdhan;
  String dhuhrAdhan;
  String asrAdhan;
  String maghribAdhan;
  String ishaAdhan;
  String midnightAdhan;
  String tahajjudAdhan;
  bool autoIpLookup;
  bool showOsd;
  int notificationDuration;
  int checkInterval;
  String asrMethod;
  bool debugLogging;
  bool adhanClockEnabled;
  bool showOnAppStart;
  String calculationMethod;
  double? latitude;
  double? longitude;
  bool showWhiteDays;
  
  AdhanSettings({
    this.cityName = 'My City',
    this.volume = 80,
    this.fajrAdhan = 'Fajr_Azan_by_Shaykh_Ali_Ahmed_Mullah_4m35s.opus',
    this.sunriseAdhan = 'z_As-Salatu_Khayrun_Minan_Nawm_0m28s.opus',
    this.dhuhrAdhan = 'Turkish_Style_by_Remzi_Er_4m08s.opus',
    this.asrAdhan = 'Heartwarming_Azan_Recitation_3m47s.opus',
    this.maghribAdhan = 'Makkah_Al-Mukarramah_Style_3m44s.opus',
    this.ishaAdhan = 'Masjid_Al-Aqsa_Style_4m07s.opus',
    this.midnightAdhan = 'Ottoman_Style_by_Mawlana_Shaykh_Nazim_2m38s.opus',
    this.tahajjudAdhan = 'Masjid_Al-Aqsa_Style_4m07s.opus',
    this.autoIpLookup = true,
    this.showOsd = true,
    this.notificationDuration = 5,
    this.checkInterval = 15,
    this.asrMethod = 'Standard',
    this.debugLogging = false,
    this.adhanClockEnabled = false,
    this.showOnAppStart = false,
    this.calculationMethod = 'ISNA',
    this.latitude,
    this.longitude,
    this.showWhiteDays = true,
  });
  
  static Future<AdhanSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AdhanSettings(
      cityName: prefs.getString('adhan_city_name') ?? 'My City',
      volume: prefs.getDouble('adhan_volume') ?? 80,
      fajrAdhan: prefs.getString('adhan_fajr') ?? 'Fajr_Azan_by_Shaykh_Ali_Ahmed_Mullah_4m35s.opus',
      sunriseAdhan: prefs.getString('adhan_sunrise') ?? 'z_As-Salatu_Khayrun_Minan_Nawm_0m28s.opus',
      dhuhrAdhan: prefs.getString('adhan_dhuhr') ?? 'Turkish_Style_by_Remzi_Er_4m08s.opus',
      asrAdhan: prefs.getString('adhan_asr') ?? 'Heartwarming_Azan_Recitation_3m47s.opus',
      maghribAdhan: prefs.getString('adhan_maghrib') ?? 'Makkah_Al-Mukarramah_Style_3m44s.opus',
      ishaAdhan: prefs.getString('adhan_isha') ?? 'Masjid_Al-Aqsa_Style_4m07s.opus',
      midnightAdhan: prefs.getString('adhan_midnight') ?? 'Ottoman_Style_by_Mawlana_Shaykh_Nazim_2m38s.opus',
      tahajjudAdhan: prefs.getString('adhan_tahajjud') ?? 'Masjid_Al-Aqsa_Style_4m07s.opus',
      autoIpLookup: prefs.getBool('adhan_auto_ip') ?? true,
      showOsd: prefs.getBool('adhan_show_osd') ?? true,
      notificationDuration: prefs.getInt('adhan_notification_duration') ?? 5,
      checkInterval: prefs.getInt('adhan_check_interval') ?? 15,
      asrMethod: prefs.getString('adhan_asr_method') ?? 'Standard',
      debugLogging: prefs.getBool('adhan_debug') ?? false,
      adhanClockEnabled: prefs.getBool('adhan_enabled') ?? false,
      showOnAppStart: prefs.getBool('adhan_show_on_start') ?? false,
      calculationMethod: prefs.getString('adhan_calculation_method') ?? 'ISNA',
      latitude: prefs.getDouble('adhan_latitude'),
      longitude: prefs.getDouble('adhan_longitude'),
      showWhiteDays: prefs.getBool('adhan_show_white_days') ?? true,
    );
  }
  
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('adhan_city_name', cityName);
    await prefs.setDouble('adhan_volume', volume);
    await prefs.setString('adhan_fajr', fajrAdhan);
    await prefs.setString('adhan_sunrise', sunriseAdhan);
    await prefs.setString('adhan_dhuhr', dhuhrAdhan);
    await prefs.setString('adhan_asr', asrAdhan);
    await prefs.setString('adhan_maghrib', maghribAdhan);
    await prefs.setString('adhan_isha', ishaAdhan);
    await prefs.setString('adhan_midnight', midnightAdhan);
    await prefs.setString('adhan_tahajjud', tahajjudAdhan);
    await prefs.setBool('adhan_auto_ip', autoIpLookup);
    await prefs.setBool('adhan_show_osd', showOsd);
    await prefs.setInt('adhan_notification_duration', notificationDuration);
    await prefs.setInt('adhan_check_interval', checkInterval);
    await prefs.setString('adhan_asr_method', asrMethod);
    await prefs.setBool('adhan_debug', debugLogging);
    await prefs.setBool('adhan_enabled', adhanClockEnabled);
    await prefs.setBool('adhan_show_on_start', showOnAppStart);
    await prefs.setString('adhan_calculation_method', calculationMethod);
    if (latitude != null) await prefs.setDouble('adhan_latitude', latitude!);
    if (longitude != null) await prefs.setDouble('adhan_longitude', longitude!);
    await prefs.setBool('adhan_show_white_days', showWhiteDays);
  }
}