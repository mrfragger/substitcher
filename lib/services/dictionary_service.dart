import 'dart:io';
import 'package:flutter/services.dart';
import 'cjk_tokenizer.dart';

class DictionaryService {
  static Future<void> lookupWord(String word, TextLanguage language) async {
    if (word.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: word));
    
    if (Platform.isMacOS) {
      try {
        final encoded = Uri.encodeComponent(word);
        await Process.run('open', ['dict://$encoded']);
        
        // await Future.delayed(const Duration(milliseconds: 3000));
        // await Process.run('osascript', [
        //   '-e',
        //   'tell application "System Events" to set frontmost of process "substitcher" to true'
        // ]);
      } catch (e) {
        print('Error opening dictionary: $e');
      }
    }
  }
}