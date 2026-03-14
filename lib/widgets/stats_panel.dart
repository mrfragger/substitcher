import 'package:flutter/material.dart';

class StatsPanel extends StatelessWidget {
  static const ltr = '\u200E';
  final List<Map<String, dynamic>> statsEntries;
  final bool statsEnabled;
  final Function(bool) onStatsEnabledChanged;
  final VoidCallback onRefreshStats;
  final String searchQuery;
  final String excludeTerms;
  final Function(DateTime) filterEntriesByDate;
  final Function(int) filterEntriesByDays;
  final Map<String, int> Function(List<Map<String, dynamic>>) getFileListenTimes;
  final List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) groupEntriesByAudiobook;
  final Function(Duration) formatDurationCompact;
  final Function(Duration) formatDuration;
  final Function(String, DateTime) deleteAudiobookFromDate;
  final TextSpan Function(String, String) highlightSearchTerm;
  final Function(String, String, Duration) jumpToStatsResult;

  const StatsPanel({
    super.key,
    required this.statsEntries,
    required this.statsEnabled,
    required this.onStatsEnabledChanged,
    required this.onRefreshStats,
    required this.searchQuery,
    required this.excludeTerms,
    required this.filterEntriesByDate,
    required this.filterEntriesByDays,
    required this.getFileListenTimes,
    required this.groupEntriesByAudiobook,
    required this.formatDurationCompact,
    required this.formatDuration,
    required this.deleteAudiobookFromDate,
    required this.highlightSearchTerm,
    required this.jumpToStatsResult,
  });

  Map<String, dynamic> _calculateStats(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return {
        'totalTime': 0,
        'uniqueFiles': 0,
        'totalEntries': 0,
        'totalChapters': 0,
        'avgChapter': 0,
      };
    }
    int totalTime = 0;
    final uniqueFiles = <String>{};
    int totalChapters = 0;
    for (final entry in entries) {
      totalTime += (entry['listened_duration'] as num).toInt();
      uniqueFiles.add(entry['filename'] as String);
      totalChapters++;
    }
    final avgChapter = totalChapters > 0 ? totalTime ~/ totalChapters : 0;
    return {
      'totalTime': totalTime,
      'uniqueFiles': uniqueFiles.length,
      'totalEntries': entries.length,
      'totalChapters': totalChapters,
      'avgChapter': avgChapter,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: searchQuery.isNotEmpty
              ? _buildStatsSearchResults()
              : _buildStatsContent(),
        ),
      ],
    );
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    final r = (backgroundColor.r * 255.0).round().clamp(0, 255);
    final g = (backgroundColor.g * 255.0).round().clamp(0, 255);
    final b = (backgroundColor.b * 255.0).round().clamp(0, 255);
    
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Enable Tracking',
            child: Switch(
              value: statsEnabled,
              onChanged: onStatsEnabledChanged,
              activeThumbColor: Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 16),
          Tooltip(
            message: 'Refresh',
            child: IconButton(
              onPressed: onRefreshStats,
              icon: const Icon(Icons.refresh, size: 20, color: Colors.white70),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSearchResults() {
    final resultsMap = <String, Map<String, dynamic>>{};
    final searchTerms = searchQuery.toLowerCase().split(' ').where((t) => t.isNotEmpty).toList();
    final excludeList = excludeTerms.split(' ').where((t) => t.isNotEmpty).toList();
    
    if (searchTerms.isEmpty) {
      return const Center(
        child: Text(
          'Enter search terms',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    for (final entry in statsEntries) {
      final filename = entry['filename'] as String? ?? '';
      final chapterName = entry['chapter_name'] as String? ?? '';
      
      final searchText = '$filename $chapterName';
      
      bool matches = false;
      for (final term in searchTerms) {
        if (searchText.toLowerCase().contains(term)) {
          matches = true;
          break;
        }
      }
      
      if (matches) {
        bool excluded = false;
        for (final excludeTerm in excludeList) {
          if (searchText.toLowerCase().contains(excludeTerm)) {
            excluded = true;
            break;
          }
        }
        
        if (!excluded) {
          final key = '$filename|$chapterName';
          if (!resultsMap.containsKey(key)) {
            resultsMap[key] = {
              'filename': filename,
              'chapterName': chapterName,
            };
          }
        }
      }
    }
    
    final results = resultsMap.values.toList();
    
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Stats Search Results (${results.length})',
            style: TextStyle(
              color: Colors.purple[200],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              final filename = result['filename'] as String;
              final chapterName = result['chapterName'] as String;
              
              return InkWell(
                onTap: () => jumpToStatsResult(filename, chapterName, Duration.zero),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF006064),
                        radius: 12,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$ltr$filename',
                              style: const TextStyle(
                                color: Colors.lightBlue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: highlightSearchTerm('$ltr$chapterName', searchQuery),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsContent() {
    if (statsEntries.isEmpty) {
      return const Center(
        child: Text(
          'No statistics data yet',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatisticsSummary(),
        _buildDayStats('Today', filterEntriesByDate(now)),
        const SizedBox(height: 24),
        _buildDayStats('Yesterday', filterEntriesByDate(now.subtract(const Duration(days: 1)))),
        const SizedBox(height: 24),
        for (int i = 2; i <= 30; i++) ...[
          _buildDayStats('$i days ago', filterEntriesByDate(now.subtract(Duration(days: i)))),
          const SizedBox(height: 24),
        ],
        _buildPeriodSummary('Last 7 Days', filterEntriesByDays(7)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 2 Weeks', filterEntriesByDays(14)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 3 Weeks', filterEntriesByDays(21)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 1 Month', filterEntriesByDays(30)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 2 Months', filterEntriesByDays(60)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 3 Months', filterEntriesByDays(90)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last 6 Months', filterEntriesByDays(180)),
        const SizedBox(height: 24),
        _buildPeriodSummary('Last Year', filterEntriesByDays(365)),
        const SizedBox(height: 24),
        _buildPeriodSummary('All Time', statsEntries),
        const SizedBox(height: 32),
        _buildTop50Section(),
        const SizedBox(height: 32),
        _buildActiveDaysChart(),
      ],
    );
  }

  Widget _buildStatisticsSummary() {
    if (statsEntries.isEmpty) {
      return const SizedBox.shrink();
    }
  
    final Map<String, int> dailyTimes = {};
    for (final entry in statsEntries) {
      final datetime = entry['datetime'] as String?;
      if (datetime == null) continue;
      try {
        final date = datetime.split(' ')[0];
        final duration = (entry['listened_duration'] as num).toInt();
        dailyTimes[date] = (dailyTimes[date] ?? 0) + duration;
      } catch (e) {
        continue;
      }
    }
  
    final activeDays = <MapEntry<String, int>>[];
    dailyTimes.forEach((date, time) {
      if (time >= 1800) {
        activeDays.add(MapEntry(date, time));
      }
    });
    activeDays.sort((a, b) => b.key.compareTo(a.key));
  
    int currentStreak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dailyTimes[dateStr] != null && dailyTimes[dateStr]! >= 1800) {
        currentStreak++;
      } else {
        break;
      }
    }
  
    int longestStreak = 0;
    String longestStreakEndDate = '';
    int tempStreak = 0;
    String tempStreakEnd = '';
    for (int i = 0; i < 365; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateStr = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dailyTimes[dateStr] != null && dailyTimes[dateStr]! >= 1800) {
        if (tempStreak == 0) {
          tempStreakEnd = dateStr;
        }
        tempStreak++;
      } else {
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
          longestStreakEndDate = tempStreakEnd;
        }
        tempStreak = 0;
        tempStreakEnd = '';
      }
    }
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
      longestStreakEndDate = tempStreakEnd;
    }
  
    int calcAverage(int dayCount) {
      if (activeDays.isEmpty) return 0;
      final subset = activeDays.take(dayCount).toList();
      if (subset.isEmpty) return 0;
      final sum = subset.fold<int>(0, (total, day) => total + day.value);
      return sum ~/ subset.length;
    }
  
    final avg10 = calcAverage(10);
    final avg20 = calcAverage(20);
    final avg30 = calcAverage(30);
  
    final sortedDays = dailyTimes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topDays = sortedDays.where((e) => e.value > 0).take(3).toList();
  
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Active Day is =>30m/day',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    formatDurationCompact(Duration(seconds: avg10)),
                    style: const TextStyle(color: Colors.lightBlue, fontSize: 18),
                  ),
                  const Text(
                    'Last 10 Active Days Average',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    formatDurationCompact(Duration(seconds: avg20)),
                    style: const TextStyle(color: Colors.lightBlue, fontSize: 18),
                  ),
                  const Text(
                    'Last 20 Active Days Average',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    formatDurationCompact(Duration(seconds: avg30)),
                    style: const TextStyle(color: Colors.lightBlue, fontSize: 18),
                  ),
                  const Text(
                    'Last 30 Active Days Average',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$currentStreak',
                    style: const TextStyle(color: Color(0xFFE3E82B), fontSize: 18),
                  ),
                  const Text(
                    'Active Daily Streak',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$longestStreak',
                    style: const TextStyle(color: Color(0xFFFF3F3F), fontSize: 18),
                  ),
                  const Text(
                    'Longest Daily Streak',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Ended $longestStreakEndDate',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${activeDays.length}',
                    style: const TextStyle(color: Color(0xFFD7B9A3), fontSize: 18),
                  ),
                  const Text(
                    'Total Active Days',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: topDays.asMap().entries.map((entry) {
            final idx = entry.key;
            final day = entry.value;
            final label = idx == 0 ? 'Longest Day' : '${idx + 1}${idx == 1 ? 'nd' : 'rd'} Longest Day';
            return Expanded(
              child: Column(
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: Color(0xFFAE4FF7), fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    formatDurationCompact(Duration(seconds: day.value)),
                    style: const TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    day.key,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDayStats(String title, List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final stats = _calculateStats(entries);
    final audiobookStats = groupEntriesByAudiobook(entries);
    
    final dateMatch = RegExp(r'(\d+) days ago').firstMatch(title);
    DateTime displayDate;
    if (title == 'Today') {
      displayDate = DateTime.now();
    } else if (title == 'Yesterday') {
      displayDate = DateTime.now().subtract(const Duration(days: 1));
    } else if (dateMatch != null) {
      final daysAgo = int.parse(dateMatch.group(1)!);
      displayDate = DateTime.now().subtract(Duration(days: daysAgo));
    } else {
      displayDate = DateTime.now();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.lightBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDurationCompact(Duration(seconds: stats['totalTime'])),
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Listening Time',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['uniqueFiles']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Audios',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['totalChapters']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Chapters',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDurationCompact(Duration(seconds: stats['avgChapter'])),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Average Chapter',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...audiobookStats.map((audiobookData) {
          final audiobookTitle = audiobookData['title'] as String;
          final audiobookDuration = audiobookData['duration'] as String;
          final percentage = audiobookData['percentage'] as int;
          final chapters = audiobookData['chapters'] as List<Map<String, dynamic>>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => jumpToStatsResult(audiobookTitle, '', Duration.zero),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13),
                            children: [
                              TextSpan(
                                text: audiobookTitle,
                                style: const TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: '  \u200E$audiobookDuration ',
                                style: const TextStyle(color: Colors.green),
                              ),
                              TextSpan(
                                text: '\u200E$percentage%',
                                style: const TextStyle(color: Colors.yellow),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white54, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Delete All Stats for Audiobook',
                      onPressed: () => deleteAudiobookFromDate(audiobookTitle, displayDate),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...chapters.map((chapter) {
                  final chapterTitle = chapter['title'] as String;
                  final chapterTime = chapter['time'] as int;
                  final timestamp = chapter['timestamp'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(left: 0, top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '$ltr$chapterTitle',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              formatDurationCompact(Duration(seconds: chapterTime)),
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          timestamp,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPeriodSummary(String title, List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final stats = _calculateStats(entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.lightBlue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDurationCompact(Duration(seconds: stats['totalTime'])),
                  style: const TextStyle(
                    color: Colors.lightBlue,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Listening Time',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['uniqueFiles']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Audios',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              children: [
                Text(
                  '${stats['totalChapters']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Total Chapters',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDurationCompact(Duration(seconds: stats['avgChapter'])),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Text(
                  'Average Chapter',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTop50Section() {
    final fileTimes = getFileListenTimes(statsEntries);
    final sortedFiles = fileTimes.entries.toList();
    sortedFiles.sort((MapEntry<String, int> a, MapEntry<String, int> b) => 
      b.value.compareTo(a.value)
    );
    final top50 = sortedFiles.take(50).where((e) => e.value >= 1200).toList();
    if (top50.isEmpty) {
      return const SizedBox.shrink();
    }
    final totalTime = top50.fold<int>(0, (sum, e) => sum + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top 50 Audiobooks Most Listened Duration >= 20m',
          style: TextStyle(
            color: Colors.lightBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...top50.asMap().entries.map((entry) {
          final index = entry.key;
          final fileEntry = entry.value;
          final percentage = totalTime > 0 ? ((fileEntry.value / totalTime) * 100).round() : 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '$ltr${fileEntry.key}',
                    style: const TextStyle(
                      color: Colors.lightBlue,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDurationCompact(Duration(seconds: fileEntry.value)),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActiveDaysChart() {
    final Map<String, int> dailyTimes = {};
    for (final entry in statsEntries) {
      final datetime = entry['datetime'] as String?;
      if (datetime == null) continue;
      try {
        final date = datetime.split(' ')[0];
        final duration = (entry['listened_duration'] as num).toInt();
        dailyTimes[date] = (dailyTimes[date] ?? 0) + duration;
      } catch (e) {
        continue;
      }
    }
    final sortedDays = dailyTimes.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    final activeDays = sortedDays.where((e) => e.value >= 1800).take(30).toList();
    if (activeDays.isEmpty) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final daysAgo = <int, int>{};
    for (final entry in activeDays) {
      try {
        final entryDate = DateTime.parse(entry.key);
        final diff = now.difference(entryDate).inDays;
        daysAgo[diff] = entry.value;
      } catch (e) {
        continue;
      }
    }
    final maxTime = daysAgo.values.reduce((a, b) => a > b ? a : b);
    final sortedDaysAgo = daysAgo.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final colors = [
      const Color(0xFF1E90FF), const Color(0xFF00CED1), const Color(0xFF20B2AA),
      const Color(0xFFFF6347), const Color(0xFFFFD700), const Color(0xFF5D3A9B),
      const Color(0xFF662D91), const Color(0xFF8B008B), const Color(0xFFCC00CC),
      const Color(0xFFFF00FF), const Color(0xFFFFD700), const Color(0xFFFFA500),
      const Color(0xFFFF4500), const Color(0xFFFF1493), const Color(0xFF9370DB),
      const Color(0xFFC19A6B), const Color(0xFFCD853F), const Color(0xFFDEB887),
      const Color(0xFFF4A460), const Color(0xFFD2B48C), const Color(0xFF00B9E5),
      const Color(0xFF38D430), const Color(0xFFE3E82B), const Color(0xFFFFAB4D),
      const Color(0xFFFF3F3F), const Color(0xFFEF2BC1), const Color(0xFFBC13FE),
      const Color(0xFFF7CB9A), const Color(0xFFF6C1A7), const Color(0xFFB6C796),
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '(Days Ago) — Last 30 Active Days Listening Duration',
          style: TextStyle(
            color: Colors.lightBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...sortedDaysAgo.asMap().entries.map((entry) {
          final index = entry.key;
          final days = entry.value.key;
          final time = entry.value.value;
          final barWidth = (time / maxTime * 700).clamp(50.0, 700.0);
          final barColor = colors[index % colors.length];
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '$days',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: barWidth,
                  height: 20,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    formatDurationCompact(Duration(seconds: time)),
                    style:  TextStyle(
                      color: _getContrastingTextColor(barColor),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}