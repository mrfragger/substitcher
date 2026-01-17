class PrayerTimes {
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime midnight;
  final DateTime tahajjud;
  
  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.midnight,
    required this.tahajjud,
  });
  
  String getNextPrayer() {
    final now = DateTime.now();
    final prayers = [
      ('Fajr', fajr),
      ('Sunrise', sunrise),
      ('Dhuhr', dhuhr),
      ('Asr', asr),
      ('Maghrib', maghrib),
      ('Isha', isha),
      ('Midnight', midnight),
      ('Tahajjud', tahajjud),
    ];
    
    for (final prayer in prayers) {
      if (now.isBefore(prayer.$2)) {
        return prayer.$1;
      }
    }
    
    return 'Fajr';
  }
  
  DateTime? getTimeForPrayer(String prayer) {
    switch (prayer) {
      case 'Fajr': return fajr;
      case 'Sunrise': return sunrise;
      case 'Dhuhr': return dhuhr;
      case 'Asr': return asr;
      case 'Maghrib': return maghrib;
      case 'Isha': return isha;
      case 'Midnight': return midnight;
      case 'Tahajjud': return tahajjud;
      default: return null;
    }
  }
}