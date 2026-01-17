import 'dart:io';
import '../models/frequency_item.dart';

class FrequencyAnalyzer {
  static const Set<String> _commonWords = {
    'about', 'actually', 'after', 'aha', 'ala', 'all', 'also', 'always', 'and',
    'another', 'any', 'are', 'ask', 'away', 'because', 'been', 'before', 'but',
    'came', 'can', 'come', 'could', 'day', 'did', "didn't", 'does', "doesn't",
    'doing', "don't", 'even', 'every', 'everything', 'find', 'for', 'from',
    'get', 'going', 'got', 'had', 'has', 'have', 'her', 'here', 'him', 'his',
    'how', "i'm", 'ibn', 'indeed', 'into', 'just', 'know', 'let', "let's",
    'like', 'look', 'made', 'make', 'many', 'may', 'maybe', 'mean', 'more',
    'most', 'much', 'need', 'never', 'nor', 'not', 'now', 'okay', 'one',
    'only', 'other', 'our', 'out', 'over', 'put', 'rather', 'really',
    'right', 'said', 'same', 'say', 'saying', 'says', 'see', 'she', 'some',
    'something', 'sort', 'still', 'sure', 'take', 'than', 'that', "that's",
    'the', 'their', 'them', 'then', 'there', 'these', 'they', 'thing', 'things',
    'think', 'this', 'those', 'through', 'too', 'two', 'until',
    'upon', 'very', 'want', 'was', 'way', 'well', 'were', 'what', 'when',
    'where', 'which', 'who', 'why', 'will', 'with', 'would', 'yeah', 'yet',
    'you', "you're", 'your', 'yourself', 'each', 'amongst', 'except',
    'should', 'whom', 'new', 'both', 'best', 'abu', 'first', 'yes', 'great',
    'three', 'back', 'likewise', 'next', 'whoever', 'comes', 'between',
    'beautiful', 'better', 'whatever', 'went', 'last', 'gave', 'its',
    'four', 'others', 'subhanahu', 'bin', 'around', 'ahl', 'allahu',
    "it's", "you'll", "he's", "they're", "there's",
    'clear', "we'll", 'understand', 'word', 'within', 'keep', 'though',
    'goes', 'however', 'based', "what's", "we're", 'anything',
    'means', 'used', 'such', 'far', 'part', 'call', 'against',
    'stop', 'become', 'became', 'down', 'lot', 'clearly', 'form',
    'known', 'off', "i'll", 'else', 'anyone', "who's", 'without', 'end',
    'try', 'own', 'brought', 'knows', 'due', 'given', 'someone',
    'today', 'bring', 'already', 'might', 'use', 'either', 'during',
    'themselves', 'again', 'days', "can't", 'inshallah', 'cannot',
    'important', "they'll", 'able', 'non', 'coming', 'left', 'having',
    'little', 'third', 'done', 'whether', 'wants', 'once', 'becomes',
    'exactly', 'sees', 'later', 'ones', 'absolute', 'absolutely', 'cause',
    'long', 'takes', 'ago', "i've", "we've", "wasn't", 'knew', 'anyway',
    'tell', "he'll", 'asked', 'abdul', "one's", 'time', 'type', 'being', 'called',
    'order', 'course', 'place', 'certain', 'himself', 'different', 'proper',
    'talk', 'similar', 'give', 'nothing', 'correct', 'mention', 'happened',
    'talked', 'hear', 'greatest', 'heard', 'especially', 'seen', 'wanted',
    'talking', 'true', 'happen', 'fell', 'complete', 'times', 'high', 'past',
    'close', 'read', 'show', 'greater', 'set', 'year', 'everywhere',
    'taken', 'self', 'totally', 'under', 'gives', 'makes', 'took', 'brings',
    'years', 'people', 'person', 'mentioned', 'mentions', 'meaning',
    'told', 'must', 'therefore', 'itself', 
  };

  static Future<List<FrequencyItem>> analyzeSubtitleFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      
      return await _analyzeContent(content);
    } catch (e) {
      print('Error analyzing subtitle file: $e');
      return [];
    }
  }

  static Future<List<FrequencyItem>> _analyzeContent(String content) async {
    final words = await _processWords(content);
    
    final allPhrases = <FrequencyItem>[];
    for (int length = 3; length <= 7; length++) {
      final phrases = await _processPhrases(content, length);
      allPhrases.addAll(phrases);
    }
    
    final deduplicated = await _deduplicatePhrases(allPhrases);
    
    final results = [...words, ...deduplicated];
    
    results.sort((a, b) {
      if (a.wordCount == 1 && b.wordCount != 1) return -1;
      if (a.wordCount != 1 && b.wordCount == 1) return 1;
      
      if (a.wordCount != b.wordCount) {
        return b.wordCount.compareTo(a.wordCount);
      }
      
      return b.frequency.compareTo(a.frequency);
    });
    
    return results;
  }

  static Future<List<FrequencyItem>> _processWords(String content) async {
    final cleaned = content.replaceAll(RegExp(r"[^A-Za-z']"), ' ').toLowerCase();
    
    final words = cleaned.split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toList();
    
    final wordFreq = <String, int>{};
    for (final word in words) {
      if (!_commonWords.contains(word)) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
    }
    
    return wordFreq.entries
        .where((e) => e.value >= 4)
        .map((e) => FrequencyItem(
              text: e.key,
              frequency: e.value,
              wordCount: 1,
            ))
        .toList();
  }

  static Future<List<FrequencyItem>> _processPhrases(String content, int phraseLength) async {
    final cleaned = content.replaceAll(RegExp(r"[^A-Za-z']"), ' ').toLowerCase();
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    
    final phraseFreq = <String, int>{};
    
    for (int i = 0; i <= words.length - phraseLength; i++) {
      final phrase = words.sublist(i, i + phraseLength).join(' ');
      if (phrase.trim().isNotEmpty) {
        phraseFreq[phrase] = (phraseFreq[phrase] ?? 0) + 1;
      }
    }
    
    return phraseFreq.entries
        .where((e) => e.value >= 4)
        .map((e) => FrequencyItem(
              text: e.key,
              frequency: e.value,
              wordCount: phraseLength,
            ))
        .toList();
  }

  static Future<List<FrequencyItem>> _deduplicatePhrases(List<FrequencyItem> phrases) async {
    if (phrases.isEmpty) return [];
    
    phrases.sort((a, b) {
      final lenCompare = b.wordCount.compareTo(a.wordCount);
      if (lenCompare != 0) return lenCompare;
      return b.frequency.compareTo(a.frequency);
    });
    
    final groups = <List<FrequencyItem>>[];
    final assigned = <int>{};
    
    for (int i = 0; i < phrases.length; i++) {
      if (assigned.contains(i)) continue;
      
      final group = [phrases[i]];
      assigned.add(i);
      
      for (int j = i + 1; j < phrases.length; j++) {
        if (assigned.contains(j)) continue;
        if (phrases[j].wordCount != phrases[i].wordCount) continue;
        
        if (_areSimilar(phrases[i], phrases[j])) {
          group.add(phrases[j]);
          assigned.add(j);
        }
      }
      
      groups.add(group);
    }
    
    final filtered = <FrequencyItem>[];
    for (final group in groups) {
      if (group.length == 1) {
        filtered.add(group[0]);
      } else {
        group.sort((a, b) => b.frequency.compareTo(a.frequency));
        filtered.add(group[0]);
      }
    }
    
    return filtered;
  }

  static bool _areSimilar(FrequencyItem p1, FrequencyItem p2) {
    final words1 = p1.text.split(' ');
    final words2 = p2.text.split(' ');
    
    final content1 = words1.where((w) => w.length >= 3).toList();
    final content2 = words2.where((w) => w.length >= 3).toList();
    
    if (content1.isEmpty || content2.isEmpty) return false;
    
    final set1 = content1.toSet();
    final set2 = content2.toSet();
    
    final intersection = set1.intersection(set2).length;
    final union = set1.union(set2).length;
    
    if (union == 0) return false;
    
    final contentOverlap = intersection / union;
    if (contentOverlap >= 0.5) return true;
    
    final text1 = p1.text;
    final text2 = p2.text;
    
    if (text1.contains(text2) || text2.contains(text1)) {
      return true;
    }
    
    int maxSequentialMatch = 0;
    
    for (int offset = -(words2.length - 1); offset < words1.length; offset++) {
      int matches = 0;
      for (int i = 0; i < words2.length; i++) {
        final pos1 = i + offset;
        if (pos1 >= 0 && pos1 < words1.length && words1[pos1] == words2[i]) {
          matches++;
        }
      }
      if (matches > maxSequentialMatch) {
        maxSequentialMatch = matches;
      }
    }
    
    final minLength = words1.length < words2.length ? words1.length : words2.length;
    final sequentialOverlap = maxSequentialMatch / minLength;
    
    if (sequentialOverlap >= 0.6) return true;
    
    if (content1.length >= 2 && content2.length >= 2) {
      final lcs = _longestCommonSubsequence(content1, content2);
      final lcsRatio = lcs / (content1.length < content2.length ? content1.length : content2.length);
      
      if (lcsRatio >= 0.5) return true;
    }
    
    return false;
  }
  
  static int _longestCommonSubsequence(List<String> a, List<String> b) {
    final m = a.length;
    final n = b.length;
    
    if (m == 0 || n == 0) return 0;
    
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1] + 1;
        } else {
          dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
        }
      }
    }
    
    return dp[m][n];
  }
}