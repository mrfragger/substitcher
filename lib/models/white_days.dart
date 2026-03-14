class WhiteDays {
  final String monthName;
  final int year;
  final List<WhiteDay> days;
  
  WhiteDays({
    required this.monthName,
    required this.year,
    required this.days,
  });
  
  factory WhiteDays.fromJson(Map<String, dynamic> json) {
    return WhiteDays(
      monthName: json['month_name'] as String,
      year: json['year'] as int,
      days: (json['days'] as List)
          .map((d) => WhiteDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'month_name': monthName,
    'year': year,
    'days': days.map((d) => d.toJson()).toList(),
  };
}

class WhiteDay {
  final int hijriDay;
  final String weekdayAbbr;
  final String formattedDate;
  
  WhiteDay({
    required this.hijriDay,
    required this.weekdayAbbr,
    required this.formattedDate,
  });
  
  factory WhiteDay.fromJson(Map<String, dynamic> json) {
    return WhiteDay(
      hijriDay: json['hijri_day'] as int,
      weekdayAbbr: json['weekday_abbr'] as String,
      formattedDate: json['formatted_date'] as String,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'hijri_day': hijriDay,
    'weekday_abbr': weekdayAbbr,
    'formatted_date': formattedDate,
  };
}