import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/adhan_clock_service.dart';
import '../models/prayer_times.dart';
import '../models/adhan_settings.dart';
import '../models/white_days.dart';
import '../services/white_days_service.dart';
import 'dart:math' as math;
import 'dart:async';

class AdhanClockOverlay extends StatefulWidget {
  final AdhanClockService adhanService;
  final VoidCallback? onToggleVisibility;
  
  const AdhanClockOverlay({
    super.key,
    required this.adhanService,
    this.onToggleVisibility,
  });
  
  @override
  State<AdhanClockOverlay> createState() => _AdhanClockOverlayState();
}

class _AdhanClockOverlayState extends State<AdhanClockOverlay> {
  PrayerTimes? _prayerTimes;
  Timer? _displayUpdateTimer;
  bool _showSettings = false;
  bool _showLocationDetails = false;
  String _selectedMethod = 'ISNA';
  String _selectedAsrMethod = 'Standard';
  bool _autoDetectEnabled = true;
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  AdhanSettings? _settings;
  WhiteDays? _whiteDays;
  DateTime? _whiteDaysCacheDate;
  DateTime? _ipCacheDate;
  
  final _methods = [
    'ISNA',
    'MWL',
    'Egypt',
    'Makkah',
    'Karachi',
    'Tehran',
    'Kuwait',
    'Qatar',
    'Algeria',
    'JAKIM',
  ];
  
  @override
  void initState() {
    super.initState();
    _prayerTimes = widget.adhanService.prayerTimes;
    _loadSettings();
    _loadWhiteDays();
    _loadCacheDate();
    _loadIpCacheDate();
    widget.adhanService.prayerTimesStream.listen((times) {
      if (mounted) {
        setState(() => _prayerTimes = times);
      }
    });

    _displayUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {
        });
      }
    });
  }

  @override
  void dispose() {
    _displayUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadIpCacheDate() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheDate = prefs.getString('adhan_ip_cache_date');
    if (mounted && cacheDate != null) {
      try {
        final date = DateTime.parse(cacheDate);
        setState(() {
          _ipCacheDate = date;
        });
      } catch (e) {
        print('Error parsing IP cache date: $e');
      }
    }
  }

  Future<void> _loadCacheDate() async {
    final cacheDate = await WhiteDaysService.getCacheTimestamp();
    if (mounted) {
      setState(() {
        _whiteDaysCacheDate = cacheDate;
      });
    }
  }

   Future<void> _loadSettings() async {
     _settings = await AdhanSettings.load();
     if (mounted) {
       setState(() {
         _autoDetectEnabled = _settings?.autoIpLookup ?? true;
         if (_settings?.latitude != null) {
           _latController.text = _settings!.latitude.toString();
         }
         if (_settings?.longitude != null) {
           _lonController.text = _settings!.longitude.toString();
         }
       });
     }
   }

   Future<void> _loadWhiteDays() async {
     _whiteDays = await WhiteDaysService.getWhiteDays();
     if (mounted) setState(() {});
   }
  
  @override
  Widget build(BuildContext context) {
    if (_showSettings) {
      return _buildSettingsOverlay();
    }
    
    if (_settings?.adhanClockEnabled != true) {
      return Positioned(
        right: 16,
        top: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Adhan Clock Disabled',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                'm   hide/show',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.settings, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                color: Colors.white70,
                onPressed: () {
                  setState(() => _showSettings = true);
                },
                tooltip: 'Adhan Settings',
              ),
            ],
          ),
        ),
      );
    }
    
    if (_prayerTimes == null) {
      return Positioned(
        right: 16,
        top: 16,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Location not configured',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.settings, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                color: Colors.white70,
                onPressed: () {
                  setState(() => _showSettings = true);
                },
                tooltip: 'Adhan Settings',
              ),
            ],
          ),
        ),
      );
    }
  
    
    final now = DateTime.now();
    String nextPrayer = '';
    DateTime? nextTime;
    
    final prayers = [
      ('Fajr', _prayerTimes!.fajr),
      ('Sunrise', _prayerTimes!.sunrise),
      ('Dhuhr', _prayerTimes!.dhuhr),
      ('Asr', _prayerTimes!.asr),
      ('Maghrib', _prayerTimes!.maghrib),
      ('Isha', _prayerTimes!.isha),
      ('Midnight', _prayerTimes!.midnight),
      ('Tahajjud', _prayerTimes!.tahajjud),
    ];
    
    final sortedPrayers = List<(String, DateTime)>.from(prayers);
    sortedPrayers.sort((a, b) {
      var timeA = a.$2;
      var timeB = b.$2;
      
      if (timeA.isBefore(_prayerTimes!.fajr)) {
        timeA = timeA.add(const Duration(days: 1));
      }
      if (timeB.isBefore(_prayerTimes!.fajr)) {
        timeB = timeB.add(const Duration(days: 1));
      }
      
      return timeA.compareTo(timeB);
    });
    
    bool foundNext = false;
    for (final prayer in sortedPrayers) {
      var prayerTime = prayer.$2;
      
      if (prayerTime.isBefore(_prayerTimes!.fajr)) {
        prayerTime = prayerTime.add(const Duration(days: 1));
      }
      
      if (now.isBefore(prayerTime)) {
        nextPrayer = prayer.$1;
        nextTime = prayerTime;
        foundNext = true;
        break;
      }
    }
    
    if (!foundNext) {
      nextPrayer = 'Fajr';
      nextTime = _prayerTimes!.fajr.add(const Duration(days: 1));
    }
    
    String timeRemaining = '';
    if (nextTime != null) {
      final diff = nextTime.difference(now);
      final hours = diff.inHours;
      final minutes = diff.inMinutes.remainder(60);
      
      if (hours > 0) {
        timeRemaining = minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
      } else {
        if (minutes > 0) {
          timeRemaining = '${minutes}m';
        } else {
          final seconds = diff.inSeconds.remainder(60);
          timeRemaining = '${seconds}s';
        }
      }
    }
    
    final hijriDate = _getHijriDate();
    final elapsed = _getElapsedTime(now);
    final currentPrayer = _getCurrentPrayerName(now);
    
    return Positioned(
      right: 16,
      top: 16,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_settings?.showWhiteDays == true && _whiteDays != null)
                  Tooltip(
                    richMessage: TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        const TextSpan(
                          text: 'White Days ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '${_whiteDays!.monthName} ',
                          style: const TextStyle(color: Color(0xFF60a5fa), fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: '(13, 14, 15) ',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '${_whiteDays!.year}\n',
                          style: const TextStyle(color: Color(0xFF60a5fa), fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '(${_whiteDays!.days[0].weekdayAbbr}, ${_whiteDays!.days[1].weekdayAbbr}, ${_whiteDays!.days[2].weekdayAbbr}) ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '${_getGregorianMonth(_whiteDays!.days[0].formattedDate)} ',
                          style: const TextStyle(color: Color(0xFF87cffb)),
                        ),
                        TextSpan(
                          text: '(${_getDay(_whiteDays!.days[0].formattedDate)}, ${_getDay(_whiteDays!.days[1].formattedDate)}, ${_getDay(_whiteDays!.days[2].formattedDate)}) ',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: _getYear(_whiteDays!.days[0].formattedDate),
                          style: const TextStyle(color: Color(0xFF87cffb)),
                        ),
                      ],
                    ),
                    waitDuration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text(
                      'w',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.settings, size: 16),
                  onPressed: () {
                    setState(() => _showSettings = !_showSettings);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                _buildPrayerTime('Fajr', _prayerTimes!.fajr, currentPrayer == 'Fajr'),
                const SizedBox(width: 8),
                _buildPrayerTime('Sunrise', _prayerTimes!.sunrise, currentPrayer == 'Sunrise', isSunrise: true),
                const SizedBox(width: 8),
                _buildPrayerTime('Dhuhr', _prayerTimes!.dhuhr, currentPrayer == 'Dhuhr'),
                const SizedBox(width: 8),
                _buildPrayerTime('Asr', _prayerTimes!.asr, currentPrayer == 'Asr'),
                const SizedBox(width: 8),
                _buildPrayerTime('Maghrib', _prayerTimes!.maghrib, currentPrayer == 'Maghrib'),
                const SizedBox(width: 8),
                _buildPrayerTime('Isha', _prayerTimes!.isha, currentPrayer == 'Isha'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Hide/Show Adhan Clock (m)',
                  waitDuration: const Duration(milliseconds: 300),
                  child: InkWell(
                    onTap: () {
                      widget.onToggleVisibility?.call();
                    },
                    child: const Text(
                      'm',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  hijriDate,
                  style: const TextStyle(
                    color: Color(0xFFF5D38A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                _buildPrayerTime('Midnight', _prayerTimes!.midnight, currentPrayer == 'Midnight'),
                const SizedBox(width: 8),
                _buildPrayerTime('Tahajjud', _prayerTimes!.tahajjud, currentPrayer == 'Tahajjud'),
                if (elapsed != null) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'Elapsed ',
                    style: TextStyle(
                      color: Color(0xFFF5D38A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    elapsed,
                    style: const TextStyle(
                      color: Color(0xFFD78700),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  '$nextPrayer in ',
                  style: const TextStyle(
                    color: Color(0xFFF5D38A),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  timeRemaining,
                  style: TextStyle(
                    color: _shouldHighlightNext(nextTime) 
                        ? const Color(0xFFE56243)
                        : const Color(0xFFB287EB),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingsOverlay() {
      final qibla = widget.adhanService.latitude != null && widget.adhanService.longitude != null
          ? _calculateQibla(widget.adhanService.latitude!, widget.adhanService.longitude!)
          : null;
  
      String _getGregorianMonth(String formattedDate) {
        final parts = formattedDate.split('-');
        final month = int.parse(parts[1]);
        const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                        'July', 'August', 'September', 'October', 'November', 'December'];
        return months[month - 1];
      }
      
      String _getDay(String formattedDate) {
        final parts = formattedDate.split('-');
        return int.parse(parts[2]).toString();
      }
      
      String _getYear(String formattedDate) {
        final parts = formattedDate.split('-');
        return parts[0];
      }
      
      return Positioned(
        right: 16,
        top: 16,
        child: Container(
          width: 450,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Adhan Clock Settings',
                    style: TextStyle(
                      color: Color(0xFFF5D38A),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () {
                      setState(() => _showSettings = false);
                    },
                    padding: const EdgeInsets.only(right: 20),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _settings?.adhanClockEnabled ?? false,
                            onChanged: (value) async {
                              final settings = await AdhanSettings.load();
                              settings.adhanClockEnabled = value!;
                              await settings.save();
                              await _loadSettings();
                              
                              if (value) {
                                await widget.adhanService.initialize();
                              }
                            },
                          ),
                          const Text(
                            'Enable Adhan Clock',
                            style: TextStyle(color: Color(0xFF48A868), fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          Checkbox(
                            value: _settings?.showOnAppStart ?? false,
                            onChanged: (value) async {
                              final settings = await AdhanSettings.load();
                              settings.showOnAppStart = value!;
                              await settings.save();
                              await _loadSettings();
                            },
                          ),
                          const Text(
                            'Show on App Start',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),

                      ElevatedButton.icon(
                        onPressed: () async {
                          await widget.adhanService.autoDetectLocation();
                          await _loadSettings();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Location detected and updated')),
                            );
                          }
                        },
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('Auto-detect Location Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF48A868),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      if (_settings?.showWhiteDays == true && _whiteDays != null) ...[
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12),
                            children: [
                              const TextSpan(
                                text: 'White Days ',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '${_whiteDays!.monthName} ',
                                style: const TextStyle(color: Color(0xFF60a5fa), fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(
                                text: '(13, 14, 15) ',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '${_whiteDays!.year}',
                                style: const TextStyle(color: Color(0xFF60a5fa), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 12),
                            children: [
                              TextSpan(
                                text: '(${_whiteDays!.days[0].weekdayAbbr}, ${_whiteDays!.days[1].weekdayAbbr}, ${_whiteDays!.days[2].weekdayAbbr}) ',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: _getGregorianMonth(_whiteDays!.days[0].formattedDate),
                                style: const TextStyle(color: Color(0xFF87cffb)),
                              ),
                              const TextSpan(
                                text: ' ',
                                style: TextStyle(color: Color(0xFF87cffb)),
                              ),
                              TextSpan(
                                text: '(${_getDay(_whiteDays!.days[0].formattedDate)}, ${_getDay(_whiteDays!.days[1].formattedDate)}, ${_getDay(_whiteDays!.days[2].formattedDate)}) ',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: _getYear(_whiteDays!.days[0].formattedDate),
                                style: const TextStyle(color: Color(0xFF87cffb)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Valid for 30 days',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        if (_whiteDaysCacheDate != null)
                          Text(
                            'Cached on ${_whiteDaysCacheDate!.year}-${_whiteDaysCacheDate!.month.toString().padLeft(2, '0')}-${_whiteDaysCacheDate!.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white54, fontSize: 10),
                          ),
                        const SizedBox(height: 8),
                      ],
                      
                      if (_autoDetectEnabled && widget.adhanService.coordinatesSource != null) 
                        Text('Auto-detect Location (valid for 30 days)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      if (_autoDetectEnabled && _ipCacheDate != null)
                        Text(
                          'Cached on ${_ipCacheDate!.year}-${_ipCacheDate!.month.toString().padLeft(2, '0')}-${_ipCacheDate!.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      
                      if (qibla != null)
                        Text('Qibla: ${qibla.toStringAsFixed(1)}°', style: const TextStyle(color: Colors.white70, fontSize: 12)),
  
                      const SizedBox(height: 8),
                      
                      ElevatedButton.icon(
                        onPressed: () {
                          widget.adhanService.stopAdhan();
                        },
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('Stop Adhan Playing (0)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                                                  
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Method: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          DropdownButton<String>(
                            value: _selectedMethod,
                            dropdownColor: Colors.black87,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            items: _methods.map((method) {
                              return DropdownMenuItem(value: method, child: Text(method));
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedMethod = value!);
                            },
                          ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          const Text('Asr Calculation: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          DropdownButton<String>(
                            value: _selectedAsrMethod,
                            dropdownColor: Colors.black87,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            items: ['Standard', 'Hanafi'].map((method) {
                              return DropdownMenuItem(value: method, child: Text(method));
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedAsrMethod = value!);
                            },
                          ),
                        ],
                      ),
                      
                      Text(
                        'Timezone: ${DateTime.now().timeZoneOffset.inHours.toStringAsFixed(1)} hours',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() => _showLocationDetails = !_showLocationDetails);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          _showLocationDetails ? 'Hide Location Details' : 'Show Location Details',
                          style: const TextStyle(color: Color(0xFF48A868), fontSize: 12),
                        ),
                      ),
                      
                      if (_showLocationDetails && widget.adhanService.cityName != null) ...[
                        const SizedBox(height: 8),
                        Text('City: ${widget.adhanService.cityName}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Source: ${widget.adhanService.coordinatesSource}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Latitude: ${widget.adhanService.latitude!.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('Longitude: ${widget.adhanService.longitude!.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                      
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      
                      const Text('Adhan Files', style: TextStyle(color: Color(0xFFF5D38A), fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      
                      _buildAdhanSelector('Fajr'),
                      _buildAdhanSelector('Sunrise'),
                      _buildAdhanSelector('Dhuhr'),
                      _buildAdhanSelector('Asr'),
                      _buildAdhanSelector('Maghrib'),
                      _buildAdhanSelector('Isha'),
                      _buildAdhanSelector('Midnight'),
                      _buildAdhanSelector('Tahajjud'),
                      
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Checkbox(
                            value: _autoDetectEnabled,
                            onChanged: (value) async {
                              setState(() => _autoDetectEnabled = value!);
                              final settings = await AdhanSettings.load();
                              settings.autoIpLookup = value!;
                              await settings.save();
                            },
                          ),
                          const Text('Auto-detect Location', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
  
                      Row(
                        children: [
                          Checkbox(
                            value: _settings?.showWhiteDays ?? true,
                            onChanged: (value) async {
                              final settings = await AdhanSettings.load();
                              settings.showWhiteDays = value!;
                              await settings.save();
                              await _loadSettings();
                            },
                          ),
                          const Text('Show White Days', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      
                      if (!_autoDetectEnabled) ...[
                        const SizedBox(height: 8),
                        InkWell(
                            onTap: () async {
                              final url = Uri.parse('https://www.lat-long-coordinates.com');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: const Text(
                              'https://www.lat-long-coordinates.com',
                              style: TextStyle(
                                color: Color(0xFF60a5fa),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        const Text('Manual Coordinates:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Latitude: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _latController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.all(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Longitude: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _lonController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.all(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final lat = double.tryParse(_latController.text);
                            final lon = double.tryParse(_lonController.text);
                            
                            if (lat != null && lon != null) {
                              final settings = await AdhanSettings.load();
                              settings.latitude = lat;
                              settings.longitude = lon;
                              settings.autoIpLookup = false;
                              await settings.save();
                              
                              await widget.adhanService.applyManualCoordinates(lat, lon);
                              await _loadSettings();
                              
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Manual coordinates saved and applied')),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid coordinates - please enter valid numbers')),
                                );
                              }
                            }
                          },
                          child: const Text('Save Manual Coordinates'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _showSettings = false);
                  },
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Close Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    String _getGregorianMonth(String formattedDate) {
      final parts = formattedDate.split('-');
      final month = int.parse(parts[1]);
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 
                      'July', 'August', 'September', 'October', 'November', 'December'];
      return months[month - 1];
    }
    
    String _getDay(String formattedDate) {
      final parts = formattedDate.split('-');
      return int.parse(parts[2]).toString();
    }
    
    String _getYear(String formattedDate) {
      final parts = formattedDate.split('-');
      return parts[0];
    }
  
  Widget _buildAdhanSelector(String prayerName) {
    final availableAdhans = [
      'Azan-Dua.opus',
      'Bosnian_Style_by_Eldin_Huseinbegovic_3m11s.opus',
      'Dubai_Style_by_Abdulrahman_Al-Hindi_2m32s.opus',
      'Egyptian_Style_3m25s.opus',
      'Fajr_Azan_by_Mansoor_Az-Zahrani_3m26s.opus',
      'Fajr_Azan_by_Mishary_Al-Afasy_3m24s.opus',
      'Fajr_Azan_by_Shaykh_Ali_Ahmed_Mullah_4m35s.opus',
      'Heartwarming_Azan_Recitation_3m47s.opus',
      'Madina_Fajr_Azan_by_Shaykh_Surayhi_4m54s.opus',
      'Makkah_Al-Mukarramah_Style_3m44s.opus',
      'Masjid_Al-Aqsa_Style_4m07s.opus',
      'Mishary_Al-Afasy_4m17s.opus',
      'Muhammad_Al-Sharif_3m29s.opus',
      'Ottoman_Style_by_Mawlana_Shaykh_Nazim_2m38s.opus',
      'Turkish_Style_by_Remzi_Er_4m08s.opus',
      'z_As-Salatu_Khayrun_Minan_Nawm_0m28s.opus',
      'z_Bismillahirrahmanirrahim_0m05s.opus',
      'z_silence_1m0s.opus',
      'z_Soft_Beep_Sound_0m01s.opus',
    ];
    
    String getCurrentAdhan(String prayer) {
      switch (prayer) {
        case 'Fajr': return _settings?.fajrAdhan ?? availableAdhans[6];
        case 'Sunrise': return _settings?.sunriseAdhan ?? availableAdhans[15];
        case 'Dhuhr': return _settings?.dhuhrAdhan ?? availableAdhans[14];
        case 'Asr': return _settings?.asrAdhan ?? availableAdhans[7];
        case 'Maghrib': return _settings?.maghribAdhan ?? availableAdhans[9];
        case 'Isha': return _settings?.ishaAdhan ?? availableAdhans[10];
        case 'Midnight': return _settings?.midnightAdhan ?? availableAdhans[13];
        case 'Tahajjud': return _settings?.tahajjudAdhan ?? availableAdhans[10];
        default: return availableAdhans[0];
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24),
            onPressed: () {
              widget.adhanService.playTestAdhan(prayerName);
            },
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              '$prayerName:',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          Expanded(
            child: DropdownButton<String>(
              value: getCurrentAdhan(prayerName),
              isExpanded: true,
              dropdownColor: Colors.black87,
              style: const TextStyle(color: Colors.white, fontSize: 10),
              menuMaxHeight: 400,
              selectedItemBuilder: (BuildContext context) {
                return availableAdhans.map((adhan) {
                  return Text(
                    adhan,
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  );
                }).toList();
              },
              items: availableAdhans.map((adhan) {
                return DropdownMenuItem(
                  value: adhan,
                  child: SizedBox(
                    width: 500,
                    child: Text(
                      adhan,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  await _saveAdhanSelection(prayerName, value);
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _saveAdhanSelection(String prayerName, String adhanFile) async {
    final settings = await AdhanSettings.load();
    
    switch (prayerName) {
      case 'Fajr': settings.fajrAdhan = adhanFile; break;
      case 'Sunrise': settings.sunriseAdhan = adhanFile; break;
      case 'Dhuhr': settings.dhuhrAdhan = adhanFile; break;
      case 'Asr': settings.asrAdhan = adhanFile; break;
      case 'Maghrib': settings.maghribAdhan = adhanFile; break;
      case 'Isha': settings.ishaAdhan = adhanFile; break;
      case 'Midnight': settings.midnightAdhan = adhanFile; break;
      case 'Tahajjud': settings.tahajjudAdhan = adhanFile; break;
    }
    
    await settings.save();
  }
  
  Widget _buildPrayerTime(String name, DateTime time, bool isCurrent, {bool isSunrise = false, bool small = false}) {
    final timeStr = DateFormat('HH:mm').format(time);
    
    Color timeColor;
    if (isCurrent) {
      timeColor = const Color(0xFF90EE90);
    } else if (isSunrise) {
      timeColor = const Color(0xFFD78700);
    } else {
      timeColor = const Color(0xFF87CEEB);
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontSize: small ? 10 : 12,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          timeStr,
          style: TextStyle(
            color: timeColor,
            fontSize: small ? 10 : 12,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
  
  String _getNextPrayerName(DateTime now) {
    final prayers = [
      ('Fajr', _prayerTimes!.fajr),
      ('Sunrise', _prayerTimes!.sunrise),
      ('Dhuhr', _prayerTimes!.dhuhr),
      ('Asr', _prayerTimes!.asr),
      ('Maghrib', _prayerTimes!.maghrib),
      ('Isha', _prayerTimes!.isha),
      ('Midnight', _prayerTimes!.midnight),
      ('Tahajjud', _prayerTimes!.tahajjud),
    ];
    
    for (final prayer in prayers) {
      if (now.isBefore(prayer.$2)) {
        return prayer.$1;
      }
    }
    
    return 'Fajr';
  }
  
  String _getCurrentPrayerName(DateTime now) {
    final prayers = [
      ('Tahajjud', _prayerTimes!.tahajjud),
      ('Fajr', _prayerTimes!.fajr),
      ('Sunrise', _prayerTimes!.sunrise),
      ('Dhuhr', _prayerTimes!.dhuhr),
      ('Asr', _prayerTimes!.asr),
      ('Maghrib', _prayerTimes!.maghrib),
      ('Isha', _prayerTimes!.isha),
      ('Midnight', _prayerTimes!.midnight),
    ];
    
    prayers.sort((a, b) => a.$2.compareTo(b.$2));
    
    String current = prayers.last.$1;
    for (final prayer in prayers) {
      if (now.isBefore(prayer.$2)) {
        break;
      }
      current = prayer.$1;
    }
    
    return current;
  }
  
  bool _shouldHighlightNext(DateTime? nextTime) {
    if (nextTime == null) return false;
    final diff = nextTime.difference(DateTime.now());
    return diff.inMinutes <= 30;
  }
  
  String _getHijriDate() {
    final now = DateTime.now();
    final refDate = DateTime(2026, 1, 6);
    final refHijriDay = 17;
    final refHijriMonth = 7;
    final refHijriYear = 1447;
    
    final daysDiff = now.difference(refDate).inDays;
    
    int hijriDay = refHijriDay + daysDiff;
    int hijriMonth = refHijriMonth;
    int hijriYear = refHijriYear;
    
    final monthLengths = [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29];
    
    while (hijriDay > monthLengths[hijriMonth - 1]) {
      hijriDay -= monthLengths[hijriMonth - 1];
      hijriMonth++;
      if (hijriMonth > 12) {
        hijriMonth = 1;
        hijriYear++;
      }
    }
    
    while (hijriDay <= 0) {
      hijriMonth--;
      if (hijriMonth <= 0) {
        hijriMonth = 12;
        hijriYear--;
      }
      hijriDay += monthLengths[hijriMonth - 1];
    }
    
    const months = [
      'Muharram', 'Safar', "Rabi' al-Awwal", "Rabi' al-Thani",
      'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', "Sha'ban",
      'Ramadan', 'Shawwal', 'Dhu al-Qidah', 'Dhu al-Hijjah'
    ];
    
    return '$hijriDay ${months[hijriMonth - 1]} $hijriYear';
  }
  
  String? _getElapsedTime(DateTime now) {
    if (_prayerTimes == null) return null;
    
    final prayers = [
      ('Fajr', _prayerTimes!.fajr),
      ('Sunrise', _prayerTimes!.sunrise),
      ('Dhuhr', _prayerTimes!.dhuhr),
      ('Asr', _prayerTimes!.asr),
      ('Maghrib', _prayerTimes!.maghrib),
      ('Isha', _prayerTimes!.isha),
      ('Midnight', _prayerTimes!.midnight),
      ('Tahajjud', _prayerTimes!.tahajjud),
    ];
    
    DateTime? lastPrayer;
    for (final prayer in prayers) {
      if (now.isAfter(prayer.$2)) {
        if (lastPrayer == null || prayer.$2.isAfter(lastPrayer)) {
          lastPrayer = prayer.$2;
        }
      }
    }
    
    if (lastPrayer == null) {
      for (final prayer in prayers.reversed) {
        final yesterdayPrayer = prayer.$2.subtract(const Duration(days: 1));
        if (now.isAfter(yesterdayPrayer)) {
          lastPrayer = yesterdayPrayer;
          break;
        }
      }
    }
    
    if (lastPrayer == null) return null;
    
    final diff = now.difference(lastPrayer);
    
    if (diff.inHours >= 24) return null;
    
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
  
  double _calculateQibla(double lat, double lon) {
    const meccaLat = 21.4225;
    const meccaLon = 39.8262;
    
    final latRad = lat * math.pi / 180;
    final meccaLatRad = meccaLat * math.pi / 180;
    final deltaLon = (meccaLon - lon) * math.pi / 180;
    
    final y = math.sin(deltaLon) * math.cos(meccaLatRad);
    final x = math.cos(latRad) * math.sin(meccaLatRad) -
              math.sin(latRad) * math.cos(meccaLatRad) * math.cos(deltaLon);
    
    final qibla = math.atan2(y, x) * 180 / math.pi;
    return (qibla + 360) % 360;
  }
}