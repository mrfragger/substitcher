import 'package:characters/characters.dart';
import 'package:tiny_segmenter_dart/tiny_segmenter_dart.dart';

enum TextLanguage { japanese, korean, chinese, arabic, english, unknown }

class CJKTokenizer {
  static final _tinySegmenter = TinySegmenter();
  
  static const Set<String> _commonWords = {
    "los", "las", "del", "con", "esa", "que",
    "about", "absolutely", "absolute", "abu", "actually", "after", "again", "against", "ago", "aha", "ahl", "all", "allahu", "also", "always", "amongst", "and", "another", "any", "anyone", "anything", "anyway", "are", "around", "ask", "asked", "away", "back", "based", "beautiful", "became", "because", "become", "becomes", "been", "before", "being", "better", "between", "bin", "both", "brings", "brought", "but", "call", "called", "came", "can", "can't", "cannot", "cause", "certain", "clear", "clearly", "close", "comes", "coming", "complete", "correct", "could", "course", "day", "days", "did", "didn't", "different", "does", "doesn't", "doing", "don't", "done", "down", "during", "each", "else", "end", "even", "every", "everything", "everywhere", "exactly", "except", "far", "fell", "few", "find", "first", "for", "form", "four", "from", "full", "gave", "get", "give", "gives", "goes", "going", "got", "great", "had", "has", "have", "having", "hear", "heard", "he'll", "he's", "her", "here", "high", "him", "himself", "his", "happen", "happened", "how", "however", "i'll", "i'm", "i've", "ibn", "important", "indeed", "into", "it's", "its", "just", "keep", "knew", "know", "known", "knows", "last", "later", "left", "let", "let's", "like", "little", "long", "look", "lot", "made", "make", "makes", "many", "may", "maybe", "mean", "means", "might", "more", "most", "much", "need", "never", "new", "next", "non", "nor", "not", "now", "okay", "one", "one's", "only", "order", "other", "others", "our", "out", "over", "own", "part", "past", "proper", "put", "rather", "really", "right", "said", "same", "say", "saying", "says", "see", "sees", "self", "set", "she", "should", "show", "similar", "some", "someone", "something", "sort", "still", "stop", "such", "sure", "take", "taken", "takes", "talk", "talked", "talking", "tell", "than", "that", "that's", "the", "their", "them", "then", "there", "there's", "these", "they", "they'll", "they're", "thing", "things", "think", "third", "this", "those", "though", "today", "too", "took", "true", "try", "two", "type", "under", "understand", "until", "upon", "use", "used", "very", "want", "wants", "was", "wasn't", "way", "we'll", "we're", "we've", "well", "went", "were", "what", "what's", "when", "where", "which", "while", "who", "who's", "whoever", "whom", "why", "will", "with", "within", "without", "word", "would", "year", "years", "yes", "yet", "you", "you'll", "you're", "your", "yourself",
  };

  static bool isCommonWord(String word) {
    final lower = word.toLowerCase().replaceAll("'", "'").replaceAll('`', "'");
    return _commonWords.contains(lower);
  }

  static bool shouldExcludeFromColoring(String word, {TextLanguage? language}) {
    final detectedLang = language ?? detectLanguage(word);
    
    if (detectedLang == TextLanguage.japanese || 
        detectedLang == TextLanguage.chinese || 
        detectedLang == TextLanguage.korean) {
      return false;
    }
    
    return isCommonWord(word) || word.length < 3;
  }
  
  static Future<void> initialize() async {
    print('TinySegmenter ready');
  }
  
  static TextLanguage detectLanguage(String text) {
    bool hasJapanese = false;
    bool hasKorean = false;
    bool hasChinese = false;
    bool hasArabic = false;
    bool hasLatin = false;
    
    for (final char in text.characters) {
      final code = char.runes.first;
      
      if ((code >= 0x3040 && code <= 0x309F) || (code >= 0x30A0 && code <= 0x30FF)) {
        hasJapanese = true;
      } else if ((code >= 0xAC00 && code <= 0xD7AF) || 
                 (code >= 0x1100 && code <= 0x11FF) || 
                 (code >= 0x3130 && code <= 0x318F)) {
        hasKorean = true;
      } else if (code >= 0x4E00 && code <= 0x9FFF) {
        hasChinese = true;
      } else if ((code >= 0x0600 && code <= 0x06FF) || 
                 (code >= 0x0750 && code <= 0x077F) ||
                 (code >= 0xFB50 && code <= 0xFDFF) ||
                 (code >= 0xFE70 && code <= 0xFEFF)) {
        hasArabic = true;
      } else if ((code >= 0x0041 && code <= 0x005A) ||  // A-Z
                 (code >= 0x0061 && code <= 0x007A)) {  // a-z
        hasLatin = true;
      }
    }
    
    TextLanguage detected;
    if (hasJapanese) {
      detected = TextLanguage.japanese;
    } else if (hasKorean) {
      detected = TextLanguage.korean;
    } else if (hasChinese) {
      detected = TextLanguage.chinese;
    } else if (hasArabic && hasLatin) {
      detected = TextLanguage.arabic;
    } else if (hasLatin) {
      detected = TextLanguage.english;
    } else if (hasArabic) {
      detected = TextLanguage.arabic;
    } else {
      detected = TextLanguage.unknown;
    }
    
    // print('🔍 Language Detection: "${text.substring(0, text.length > 50 ? 50 : text.length)}" -> $detected (hasArabic: $hasArabic, hasLatin: $hasLatin)');
    
    return detected;
  }

  static List<String> tokenize(String text, {TextLanguage? language}) {
    final detectedLang = language ?? detectLanguage(text);
    
    switch (detectedLang) {
      case TextLanguage.japanese:
        return _tokenizeJapanese(text);
      case TextLanguage.korean:
        return _tokenizeKorean(text);
      case TextLanguage.chinese:
        return _tokenizeChinese(text);
      case TextLanguage.arabic:
        return _tokenizeArabic(text);
      case TextLanguage.english:
      case TextLanguage.unknown:
        return _tokenizeEnglish(text);
    }
  }

  static bool _isSmallKana(String text) {
    if (text.isEmpty) return false;
    for (final char in text.characters) {
      final code = char.runes.first;
      if (code == 0x3041 || code == 0x3043 || code == 0x3045 || code == 0x3047 || code == 0x3049 ||
          code == 0x3083 || code == 0x3085 || code == 0x3087 || code == 0x308E || code == 0x3063 ||
          code == 0x30A1 || code == 0x30A3 || code == 0x30A5 || code == 0x30A7 || code == 0x30A9 ||
          code == 0x30E3 || code == 0x30E5 || code == 0x30E7 || code == 0x30EE || code == 0x30C3) {
        return true;
      }
    }
    return false;
  }

  static bool _startsWithSmallKana(String text) {
    if (text.isEmpty) return false;
    final firstChar = text.characters.first;
    final code = firstChar.runes.first;
    return (code == 0x3041 || code == 0x3043 || code == 0x3045 || code == 0x3047 || code == 0x3049 ||
            code == 0x3083 || code == 0x3085 || code == 0x3087 || code == 0x308E || code == 0x3063 ||
            code == 0x30A1 || code == 0x30A3 || code == 0x30A5 || code == 0x30A7 || code == 0x30A9 ||
            code == 0x30E3 || code == 0x30E5 || code == 0x30E7 || code == 0x30EE || code == 0x30C3);
  }

  static List<String> _tokenizeJapanese(String text) {
    try {
      final segments = _tinySegmenter.segment(text);
      
      final merged = <String>[];
      for (int i = 0; i < segments.length; i++) {
        final current = segments[i].trim();
        if (current.isEmpty) continue;
        
        if (!RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF\w]').hasMatch(current)) {
          continue;
        }
        
        if (merged.isEmpty) {
          merged.add(current);
          continue;
        }
        
        if (_startsWithSmallKana(current) || current == 'ん' || current == 'ン') {
          merged[merged.length - 1] = merged.last + current;
        } else {
          merged.add(current);
        }
      }
      
      return merged;
    } catch (e) {
      print('TinySegmenter error: $e');
      return [text];
    }
  }

  static List<String> _tokenizeChinese(String text) {
    final words = <String>[];
    final chars = text.characters.toList();
    
    int i = 0;
    while (i < chars.length) {
      if (!_isChineseChar(chars[i])) {
        if (RegExp(r'[a-zA-Z0-9]').hasMatch(chars[i])) {
          final buffer = StringBuffer(chars[i]);
          i++;
          while (i < chars.length && RegExp(r'[a-zA-Z0-9]').hasMatch(chars[i])) {
            buffer.write(chars[i]);
            i++;
          }
          words.add(buffer.toString());
        } else {
          i++;
        }
        continue;
      }
      
      int maxMatchLen = 0;
      String? bestMatch;
      
      for (int len = 4; len >= 1; len--) {
        if (i + len > chars.length) continue;
        
        final candidate = chars.sublist(i, i + len).join();
        if (_isCommonChineseWord(candidate, len)) {
          maxMatchLen = len;
          bestMatch = candidate;
          break;
        }
      }
      
      if (bestMatch != null && maxMatchLen > 0) {
        words.add(bestMatch);
        i += maxMatchLen;
      } else {
        words.add(chars[i]);
        i++;
      }
    }
    
    return words.where((w) => w.trim().isNotEmpty).toList();
  }

  static bool _isChineseChar(String char) {
    final code = char.runes.first;
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  static bool _isCommonChineseWord(String word, int len) {
    if (len == 4) return _chinese4CharWords.contains(word);
    if (len == 3) return _chinese3CharWords.contains(word);
    if (len == 2) return _chinese2CharWords.contains(word);
    return false;
  }

  static final Set<String> _chinese2CharWords = {
    '你们', '他们', '她们', '我们', '咱们', '人们', '大家', '自己', '别人',
    '什么', '怎么', '为什', '这个', '那个', '哪个', '这些', '那些', '哪些',
    '可以', '应该', '必须', '需要', '希望', '想要', '喜欢', '觉得', '认为',
    '知道', '明白', '了解', '理解', '相信', '以为', '听说', '看见', '遇到',
    '时候', '地方', '方面', '情况', '问题', '事情', '东西', '方法', '办法',
    '已经', '还是', '或者', '而且', '但是', '因为', '所以', '如果', '虽然',
    '非常', '很多', '一些', '几个', '一点', '有点', '太多', '更多', '最多',
    '今天', '明天', '昨天', '现在', '以前', '以后', '刚才', '马上', '立刻',
    '中国', '美国', '日本', '英国', '法国', '德国', '俄国', '韩国', '印度',
    '开始', '结束', '继续', '停止', '发生', '出现', '存在', '产生', '进行',
    '工作', '学习', '生活', '旅行', '运动', '休息', '睡觉', '吃饭', '喝水',
    '学校', '公司', '医院', '银行', '商店', '饭店', '酒店', '机场', '车站',
    '朋友', '家人', '父母', '孩子', '老师', '学生', '同事', '邻居', '客人',
    '手机', '电脑', '网络', '视频', '音乐', '电影', '书籍', '报纸', '杂志',
    '窗户', '厨房', '门也', '没关', '看窗', '关系',
  };

  static final Set<String> _chinese3CharWords = {
    '怎么样', '为什么', '没关系', '不客气', '对不起', '没什么', '不知道',
    '很高兴', '太好了', '真不错', '没问题', '当然了', '可能是', '应该是',
    '好朋友', '老朋友', '新朋友', '好孩子', '小孩子', '年轻人', '老年人',
    '中学生', '大学生', '研究生', '留学生', '外国人', '中国人', '美国人',
    '互联网', '图书馆', '火车站', '汽车站', '飞机场', '出租车',
  };

  static final Set<String> _chinese4CharWords = {
    '智能手机', '电子邮件', '社交媒体', '人工智能',
  };

  static List<String> _tokenizeKorean(String text) {
    final words = <String>[];
    final buffer = StringBuffer();
    bool inHangul = false;
    
    for (final char in text.characters) {
      final charCode = char.runes.first;
      
      if ((charCode >= 0xAC00 && charCode <= 0xD7AF) ||
          (charCode >= 0x1100 && charCode <= 0x11FF) ||
          (charCode >= 0x3130 && charCode <= 0x318F)) {
        buffer.write(char);
        inHangul = true;
      }
      else if (RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        if (inHangul && buffer.isNotEmpty) {
          words.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(char);
        inHangul = false;
      }
      else {
        if (buffer.isNotEmpty) {
          words.add(buffer.toString());
          buffer.clear();
        }
        inHangul = false;
      }
    }
    
    if (buffer.isNotEmpty) {
      words.add(buffer.toString());
    }
    
    return words.where((w) => w.trim().isNotEmpty).toList();
  }

  static List<String> _tokenizeArabic(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]'), '')
        .trim();
    
    final words = cleaned
        .split(RegExp(r'\s+'))
        .map((word) {

          return word.replaceAll(RegExp(r'^[.,!?;:\-،؟؛٪۔\s]+|[.,!?;:\-،؟؛٪۔\s]+$'), '');
        })
        .where((w) => w.isNotEmpty)
        .toList();
    
    print('📝 Tokenized Arabic: ${words.length} words: $words');
    return words;
  }

  static List<String> _tokenizeEnglish(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]'), '')
        .trim();
    
    final words = cleaned
        .split(RegExp(r'\s+'))
        .map((word) {
          return word.replaceAll(RegExp(r"^[^\w`'\-]+|[^\w`'\-]+$"), '');
        })
        .where((w) => w.isNotEmpty)
        .toList();
    
    print('📝 Tokenized English: ${words.length} words: $words');
    return words;
  }

  static List<String> getLongerVariations(List<String> words, String text, int startIndex) {
    final variations = <String>[words[startIndex]];
    
    if (startIndex + 1 < words.length) {
      variations.add('${words[startIndex]} ${words[startIndex + 1]}');
    }
    
    if (startIndex + 2 < words.length) {
      variations.add('${words[startIndex]} ${words[startIndex + 1]} ${words[startIndex + 2]}');
    }
    
    return variations;
  }
}