import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

class RepeatsScreen extends StatefulWidget {
  const RepeatsScreen({super.key});

  @override
  State<RepeatsScreen> createState() => _RepeatsScreenState();
}

class _RepeatsScreenState extends State<RepeatsScreen> {
  String? _selectedVttPath;
  bool _isProcessing = false;
  String _statusMessage = '';
  String? _outputPath;
  String _debugInfo = '';
  int _iterationCount = 0;

  final List<Map<String, String>> _preserveWords = [
    {'pattern': r'\bno no\b', 'temp': 'no333no', 'restore': 'no no'},
    {'pattern': r'\bha ha\b', 'temp': 'ha333ha', 'restore': 'ha ha'},
    {'pattern': r'\bher her\b', 'temp': 'her333her', 'restore': 'her her'},
    {'pattern': r'\bbye bye\b', 'temp': 'byebye', 'restore': 'bye bye'},
    {'pattern': r'\breally really\b', 'temp': 'reallyreally', 'restore': 'really really'},
    {'pattern': r'\bstuff stuff\b', 'temp': 'stuffstuff', 'restore': 'stuff stuff'},
    {'pattern': r'\bmany many\b', 'temp': 'manymany', 'restore': 'many many'},
    {'pattern': r'\bvery very\b', 'temp': 'veryvery', 'restore': 'very very'},
    {'pattern': r'\bhad had\b', 'temp': 'hadhad', 'restore': 'had had'},
    {'pattern': r'\bblah blah\b', 'temp': 'blahblah', 'restore': 'blah blah'},
    {'pattern': r'\bilai ilai\b', 'temp': 'ilaiilai', 'restore': 'ilai ilai'},
    {'pattern': r'\bre re\b', 'temp': 'rere', 'restore': 're re'},
    {'pattern': r'\bthis this\b', 'temp': 'thisthis', 'restore': 'this this'},
    {'pattern': r'\bthat that\b', 'temp': 'thatthat', 'restore': 'that that'},
    {'pattern': r'\bever ever\b', 'temp': 'everever', 'restore': 'ever ever'},
    {'pattern': r'\byou you\b', 'temp': 'youyou', 'restore': 'you you'},
    {'pattern': r'\bso so\b', 'temp': 'soso', 'restore': 'so so'},
    {'pattern': r'\bbeing being\b', 'temp': 'beingbeing', 'restore': 'being being'},
    {'pattern': r'\bat\s+At\b', 'temp': 'atAt', 'restore': 'at At'},
    {'pattern': r'\bas\s+as\b', 'temp': 'asasasas', 'restore': 'as as'},
    {'pattern': r'\bas\s+As\b', 'temp': 'asasAsAs', 'restore': 'as As'},
    {'pattern': r'\bwa\s+wa\b', 'temp': 'wawawawa', 'restore': 'wa wa'},
    {'pattern': r'\bSaid said\b', 'temp': 'Saidsaid', 'restore': 'Said said'},
    {'pattern': r'\bthere there\b', 'temp': 'therethere', 'restore': 'there there'},
    {'pattern': r'\bgreat great\b', 'temp': 'greatgreat', 'restore': 'great great'},
  ];

  Future<void> _selectVttFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['vtt'],
      dialogTitle: 'Select VTT file to process',
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedVttPath = result.files.first.path!;
        _statusMessage = 'Selected: ${path.basename(_selectedVttPath!)}';
        _outputPath = null;
      });
    }
  }

  Map<String, dynamic> _fixCrossSubtitleHonorifics(String content) {
    final lines = content.split('\n');
    final result = <String>[];
    final fixedLinePairs = <Map<String, int>>[];
    int fixCount = 0;
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      
      if (line.trim().isNotEmpty && 
          !line.contains('-->') && 
          !RegExp(r'^\d+$').hasMatch(line.trim())) {
        
        // Pattern 1: Ends with sallallahu/salallahu (with optional alayhi/alaihi)
        final endsWithSallallahu = RegExp(
          r"(sallallahu|salallahu|sal\s+allahu|salla\s+allahu|shallallahu)(\s+(alayhi|alaihi|'alayhi))?\s*$",
          caseSensitive: false,
        );
        
        // Pattern 2: Ends with "alayhi wa" or "alaihi wa"
        final endsWithAlayhiWa = RegExp(
          r"(sallallahu|salallahu|sal\s+allahu|salla\s+allahu|shallallahu)\s+(alayhi|alaihi|'alayhi)\s+wa\s*$",
          caseSensitive: false,
        );
        
        // Pattern 3: Ends with just "alayhi" or "alaihi" (after previous line had sallallahu)
        final endsWithAlayhi = RegExp(
          r"\s+(alayhi|alaihi|'alayhi)\s*$",
          caseSensitive: false,
        );
        
        // Pattern 4: Ends with subhanahu
        final endsWithSubhanahu = RegExp(
          r'(Allah|allah)\s+(subhanahu|Subhanahu)\s*$',
          caseSensitive: false,
        );
        
        var sallallahuMatch = endsWithSallallahu.firstMatch(line);
        var alayhiWaMatch = endsWithAlayhiWa.firstMatch(line);
        var alayhiMatch = endsWithAlayhi.firstMatch(line);
        var subhanahuMatch = endsWithSubhanahu.firstMatch(line);
        
        if (sallallahuMatch != null || alayhiWaMatch != null || alayhiMatch != null || subhanahuMatch != null) {
          for (int j = i + 1; j < lines.length; j++) {
            String nextLine = lines[j];
            
            if (nextLine.trim().isEmpty || nextLine.contains('-->') || RegExp(r'^\d+$').hasMatch(nextLine.trim())) {
              continue;
            }
            
            // Handle sallallahu pattern - next line might have: alayhi wasallam, wasallam, alaihi wasallam, etc.
            if (sallallahuMatch != null) {
              final startsWithRest = RegExp(
                r"^\s*((alayhi|alaihi|'alayhi)\s+)?(wa\s*)?(sallam|salaam|salam|wasallam|wasalam)",
                caseSensitive: false,
              );
              
              final nextMatch = startsWithRest.firstMatch(nextLine);
              
              if (nextMatch != null) {
                line = line.replaceAll(endsWithSallallahu, 'ﷺ ');
                
                final leadingSpace = RegExp(r'^\s+').firstMatch(nextLine)?.group(0) ?? '';
                lines[j] = leadingSpace + nextLine.replaceFirst(startsWithRest, '').trimLeft();
                
                fixedLinePairs.add({'first': i, 'second': j});
                fixCount++;
                break;
              }
            }
            
            // Handle "alayhi wa" pattern - next line should start with sallam
            if (alayhiWaMatch != null) {
              final startsWithSallam = RegExp(
                r"^\s*(sallam|salaam|salam|wasallam|wasalam)",
                caseSensitive: false,
              );
              
              final nextMatch = startsWithSallam.firstMatch(nextLine);
              
              if (nextMatch != null) {
                line = line.replaceAll(endsWithAlayhiWa, 'ﷺ ');
                
                final leadingSpace = RegExp(r'^\s+').firstMatch(nextLine)?.group(0) ?? '';
                lines[j] = leadingSpace + nextLine.replaceFirst(startsWithSallam, '').trimLeft();
                
                fixedLinePairs.add({'first': i, 'second': j});
                fixCount++;
                break;
              }
            }
            
            // Handle standalone "alayhi" at end - next line might have "wasallam"
            if (alayhiMatch != null) {
              final startsWithWasallam = RegExp(
                r"^\s*(wa\s*)?(sallam|salaam|salam|wasallam|wasalam)",
                caseSensitive: false,
              );
              
              final nextMatch = startsWithWasallam.firstMatch(nextLine);
              
              if (nextMatch != null) {
                line = line.replaceAll(endsWithAlayhi, ' ﷺ ');
                
                final leadingSpace = RegExp(r'^\s+').firstMatch(nextLine)?.group(0) ?? '';
                lines[j] = leadingSpace + nextLine.replaceFirst(startsWithWasallam, '').trimLeft();
                
                fixedLinePairs.add({'first': i, 'second': j});
                fixCount++;
                break;
              }
            }
            
            // Handle subhanahu pattern
            if (subhanahuMatch != null) {
              final startsWithWaTaala = RegExp(
                r"^\s*(wa\s+)?(ta'ala|taala|Ta'ala|Taala)",
                caseSensitive: false,
              );
              
              final nextMatch = startsWithWaTaala.firstMatch(nextLine);
              
              if (nextMatch != null) {
                line = line.replaceAll(endsWithSubhanahu, 'Allah ﷾ ');
                
                final leadingSpace = RegExp(r'^\s+').firstMatch(nextLine)?.group(0) ?? '';
                lines[j] = leadingSpace + nextLine.replaceFirst(startsWithWaTaala, '').trimLeft();
                
                fixedLinePairs.add({'first': i, 'second': j});
                fixCount++;
                break;
              }
            }
            
            break;
          }
        }
      }
      
      result.add(line);
    }
    
    _debugInfo = 'Cross-subtitle honorific fixes: $fixCount';
    print(_debugInfo);
    
    return {
      'content': result.join('\n'),
      'fixedLinePairs': fixedLinePairs,
      'fixCount': fixCount,
    };
  }

 Future<void> _processVttFile() async {
   if (_selectedVttPath == null) {
     setState(() {
       _statusMessage = 'Please select a VTT file first';
     });
     return;
   }
 
   setState(() {
     _isProcessing = true;
     _statusMessage = 'Step 1/4: Removing repeating words...';
   });
 
   try {
     final file = File(_selectedVttPath!);
     final originalContent = await file.readAsString();
     String content = originalContent;
 
     for (final word in _preserveWords) {
       content = content.replaceAll(
         RegExp(word['pattern']!, caseSensitive: false),
         word['temp']!,
       );
     }
 
     bool foundRepeats = true;
     int maxIterations = 20;
     int iterations = 0;
     
     while (foundRepeats && iterations < maxIterations) {
       final beforePass = content;
       
       content = content.replaceAllMapped(
         RegExp(r'(\s|^)(\w+)(\s)\2(\s|$)', caseSensitive: false),
         (match) {
           return '${match.group(1)}${match.group(2)}${match.group(4)}';
         },
       );
       
       foundRepeats = (content != beforePass);
       iterations++;
     }

     _iterationCount = iterations;
 
     for (final word in _preserveWords) {
       content = content.replaceAll(word['temp']!, word['restore']!);
     }
 
     content = _removeEmptyLines(content);
     
     final dir = path.dirname(_selectedVttPath!);
     final baseName = path.basenameWithoutExtension(_selectedVttPath!);
     final repeatsPath = path.join(dir, '${baseName}_repeats.vtt');
     
     await File(repeatsPath).writeAsString(content);
     
     setState(() {
       _statusMessage = 'Step 2/4: Fixing cross-subtitle honorifics...';
     });
     
     final beforeHonorifics = content;
     final honorificResult = _fixCrossSubtitleHonorifics(content);
     content = honorificResult['content'] as String;
     final fixedLinePairs = honorificResult['fixedLinePairs'] as List<Map<String, int>>;
     
     setState(() {
       _statusMessage = 'Step 3/4: Applying single-line honorifics...';
     });
     
     final beforeSingleLine = content;
     content = _applySingleLineHonorifics(content);
     
     setState(() {
       _statusMessage = 'Step 4/4: Capitalizing proper nouns...';
     });
     
     final beforeProperNouns = content;
     content = _capitalizeProperNouns(content);
     content = _capitalizeSentenceStarts(content);
     
     final outputPath = path.join(dir, '${baseName}_propernoun.vtt');
     await File(outputPath).writeAsString(content);
     
     final repeatsHtmlPath = path.join(dir, '${baseName}_repeats_changes.html');
     await _generateDiffHtml('Repeats Removed', originalContent, beforeHonorifics, repeatsHtmlPath);
     
     final honorificsHtmlPath = path.join(dir, '${baseName}_honorifics_changes.html');
     await _generateDiffHtml('Cross-Subtitle Honorific Fixes', beforeHonorifics, beforeSingleLine, honorificsHtmlPath, fixedLinePairs: fixedLinePairs);
     
     final singleLineHtmlPath = path.join(dir, '${baseName}_singleline_honorifics.html');
     await _generateDiffHtml('Single-Line Honorifics', beforeSingleLine, beforeProperNouns, singleLineHtmlPath);
     
     final properNounsHtmlPath = path.join(dir, '${baseName}_propernoun_changes.html');
     await _generateDiffHtml('Proper Nouns Capitalized', beforeProperNouns, content, properNounsHtmlPath);
 
     await Future.delayed(const Duration(milliseconds: 100));
     
     final repeatsChanges = _countHtmlChanges(repeatsHtmlPath);
     final singleLineChanges = _countHtmlChanges(singleLineHtmlPath);
     final honorificsChanges = _countHtmlChanges(honorificsHtmlPath);
     final properNounChanges = _countHtmlChanges(properNounsHtmlPath);
     final totalChanges = repeatsChanges + singleLineChanges + honorificsChanges + properNounChanges;
 
     setState(() {
       _isProcessing = false;
       _outputPath = outputPath;
       _statusMessage = 'Success! Created:\n'
           '1. ${path.basename(repeatsPath)}\n'
           '2. ${path.basename(outputPath)}\n'
           '3. ${path.basename(repeatsHtmlPath)}\n'
           '4. ${path.basename(singleLineHtmlPath)}\n'
           '5. ${path.basename(honorificsHtmlPath)}\n'
           '6. ${path.basename(properNounsHtmlPath)}\n\n'
           'Repeats removed: $repeatsChanges changes ($iterations passes)\n'
           'Single-line honorifics: $singleLineChanges changes\n'
           'Cross-subtitle honorifics: $honorificsChanges changes\n'
           'Proper nouns: $properNounChanges changes\n'
           'Total changes: $totalChanges';
     });
 
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text(
               'Processing complete!\n'
               'Repeats: $repeatsChanges, Single-line: $singleLineChanges, Cross-subtitle: $honorificsChanges, Proper nouns: $properNounChanges\n'
               'Total: $totalChanges changes\n'
               'HTML reports generated'),
           duration: const Duration(seconds: 4),
           backgroundColor: Colors.green,
         ),
       );
     }
   } catch (e) {
     setState(() {
       _isProcessing = false;
       _statusMessage = 'Error: $e';
     });
 
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error processing file: $e'),
           backgroundColor: Colors.red,
         ),
       );
     }
   }
 }
 
 String _applySingleLineHonorifics(String content) {
   final honorificPatterns = [
     // Longest patterns first
     r'sallallahu alayhi wa sallallahu alayhi wa sallamhu',
     r'Sallallahu Alaihi Wasallallahu Alaihi Wasallam',
     r'\(Sallallahu alayhi wa sallam\)',
     r'salla Allahu alayhi wa salama',
     r'salla Allahu alayhi wa salam',
     r'sallallahu alayhi wa sallamihi',
     r'Sallallahu alayhi wa sallamih',
     r'sallallahu alayhi wa sallamhi',
     r'sallallahu alayhi wa sallamh',
     r'sallallahu alayhi wa sallamim',
     r'sallallahu alayhi wa sallami',
     r"sallallahu alayhi wa ta'ala",
     r'sallallahu alayhi wa sallamuhu',
     r'sallallahu alayhi wa sallamu',
     r'sallallahu alayhi wa sallamakala',
     r'sallallahu alayhi wa sallamakal',
     r'sallallahu alayhi wa sallamaka',
     r'sallallahu alayhi wa sallamahe',
     r'sallallahu alayhi wa sallamayhi',
     r'sallallahu alayhi wa sallamahu',
     r'sallallahu alayhi wa sallamah',
     r'sallallahu alayhi wa sallama',
     r'sallallahu alaihi wa sallamahi',
     r'sallallahu alaihi wa sallamhi',
     r'sallallahu alaihi wa sallamahu',
     r'sallallahu alaihi wa sallamah',
     r'sallallahu alaihi wa sallama',
     r'salallahu alayhi wa sallamah',
     r'salallahu alayhi wa sallamahu',
     r'salallahu alayhi wa sallama',
     r'salallahu alaihi wa sallamah',
     r'salallahu alaihi wa sallama',
     r'sallallahu alayhi wa salami',
     r'sallallahu alayhi wa salamah',
     r'sallallahu alayhi wa salama',
     r'sallallahu alaihi wa salamah',
     r'sallallahu alaihi wa salamat',
     r'sallallahu alaihi wa salama',
     r'salallahu alayhi wa salamat',
     r'salallahu alayhi wa salamul',
     r'salallahu alayhi wa salamah',
     r'salallahu alayhi wa salamma',
     r'salallahu alayhi wa salama',
     r'salallahu alaihi wa salamah',
     r'salallahu alaihi wa salama',
     r'shallallahu alaihi wasallam',
     r'shallallahu alaihi wa sallam',
     r'sal allahu alayhi wa sallam',
     r'sal allahu alayhi wasallam',
     r'sal allahu alaihi wa sallam',
     r'sal allahu alaihi wasallam',
     r"sallallahu 'alayhi wa sallam",
     r"Sallallahu 'alayhi wa sallam",
     r'salallahu alayhi wa salami',
     r'salallahu alayhi wa salam',
     r'salallahu alaihi wasalam',
     r'shallallahu alayhi wa sallam',
     r'sallallahu wa alayhi wa sallam',
     r'sallallahu alayhi wasalam',
     r'salallahu alaihi wa salam',
     r'salallahu alaihi wasallam',
     r'salallahu alayhi wa sallamu',
     r'salallahu alayhi wa sallam',
     r'salallahu alayhi wasallamah',
     r'salallahu alayhi wasallama',
     r'salallahu alayhi wasalam',
     r'salallahu alayhi wasallam',
     r'Sallallahu Alaihi Wasallamu',
     r'sallallahu alaihi wasallamah',
     r'sallallahu alaihi wasallam',
     r'sallallahu alaihi wa sallamu',
     r'sallallahu alaihi wa sallam',
     r'sallallahu alayhi wa sallam',
     r'sallallahu alayhi wa salam',
     r'sallallahu alayhi wasallamah',
     r'sallallahu alayhi wasallam',
     r'sal alahu alayhi wa salama',
     r'sal allahu alayhi wa salama',
     r'sal allahu alayhi wa salam',
     r"alayhi salamu wa ta'ala",
     r'sallallahu alayhi sallam',
     r'alayhi salamu alayhi sallam',
     r'alayhi wa sallamu alayhi',
     r'alayhi wa sallamah',
     r'alayhi wa sallamu',
     r'Alayhi As-Salaam',
     r'alayhi wa salaam',
     r'alayhi wa sallam',
     r'alayhi salatu wasalam',
     r'alayhi salatu salam',
     r'alayhi salaam',
     r'alayhi sallam',
     r'alayhi salami',
     r'alayhi salam',
     r'alayhi as-salam',
   ];
 
   for (final pattern in honorificPatterns) {
     content = content.replaceAll(
       RegExp(r'\b' + pattern + r'\b', caseSensitive: false),
       ' ﷺ ',
     );
   }
 
   return content;
 }

  int _countHtmlChanges(String htmlPath) {
      try {
        final htmlContent = File(htmlPath).readAsStringSync();
        final changeItems = RegExp(r'<div class="change-item">').allMatches(htmlContent).length;
        return changeItems;
      } catch (e) {
        return 0;
      }
    }


    int _getIterationCount() {
      return _iterationCount;
    }
  
  String _removeEmptyLines(String content) {
    final lines = content.split('\n');
    final output = <String>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.trim().isNotEmpty || 
          (i + 1 < lines.length && lines[i + 1].trim().isNotEmpty)) {
        output.add(line);
      }
    }
  
    return output.join('\n');
  }
  
  Future<void> _generateDiffHtml(
    String title, 
    String original, 
    String modified, 
    String outputPath,
    {List<Map<String, int>>? fixedLinePairs}
  ) async {
    final changes = <Map<String, dynamic>>[];
    final originalLines = original.split('\n');
    final modifiedLines = modified.split('\n');
    
    // Create a set of line indices that are part of paired fixes
    final pairedLines = <int>{};
    if (fixedLinePairs != null) {
      for (final pair in fixedLinePairs) {
        pairedLines.add(pair['first']!);
        pairedLines.add(pair['second']!);
      }
    }
    
    int changeNumber = 1;
    for (int i = 0; i < originalLines.length && i < modifiedLines.length; i++) {
      if (originalLines[i] != modifiedLines[i]) {
        // Check if this is part of a paired fix
        if (pairedLines.contains(i)) {
          // Check if this is the first line of a pair
          final isPairStart = fixedLinePairs?.any((pair) => pair['first'] == i) ?? false;
          
          if (isPairStart) {
            // Find the second line of the pair
            final pair = fixedLinePairs!.firstWhere((p) => p['first'] == i);
            final secondLineIndex = pair['second']!;
            
            changes.add({
              'original': '${originalLines[i]}\n${originalLines[secondLineIndex]}',
              'modified': '${modifiedLines[i]}\n${modifiedLines[secondLineIndex]}',
              'index': i,
              'isPaired': true,
              'label': '${changeNumber}a + ${changeNumber}b',
            });
            changeNumber++;
          }
          // Skip the second line of pairs as it's already included
          continue;
        }
        
        changes.add({
          'original': originalLines[i],
          'modified': modifiedLines[i],
          'index': i,
          'isPaired': false,
          'label': '$changeNumber',
        });
        changeNumber++;
      }
    }
    
    final fontBase64 = await _getFontBase64();
    
    final html = '''
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="UTF-8">
    <title>$title - Changes Preview</title>
    <style>
      @font-face {
        font-family: 'Scheherazade New';
        src: url('data:fonts/woff2;base64,$fontBase64') format('woff2');
        font-weight: normal;
        font-style: normal;
      }
      
      body {
        background: #1a1a1a;
        color: #e0e0e0;
        font-family: 'Scheherazade New', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        margin: 0;
        padding: 20px;
        line-height: 1.6;
      }
      h1 {
        color: #ffffff;
        border-bottom: 2px solid #673ab7;
        padding-bottom: 10px;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      }
      .stats {
        background: #2a2a2a;
        padding: 15px;
        border-radius: 8px;
        margin-bottom: 20px;
        border-left: 4px solid #673ab7;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      }
      .change-item {
        background: #2a2a2a;
        margin-bottom: 15px;
        padding: 15px;
        border-radius: 8px;
        border: 1px solid #444;
      }
      .change-number {
        color: #9575cd;
        font-weight: bold;
        margin-bottom: 8px;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        font-size: 14px;
      }
      .line {
        font-family: 'Scheherazade New', 'Courier New', monospace;
        padding: 4px 8px;
        border-radius: 2px;
        margin-bottom: 5px;
        word-wrap: break-word;
        font-size: 18px;
        white-space: pre-wrap;
      }
      .removed {
        color: #cb7f7f;
      }
      .added {
        color: #7dab7f;
      }
      .removed-highlight {
        background: #3e0909;
        color: #cb7f7f;
        padding: 0px 2px;
        border-radius: 1px;
        display: inline;
      }
      .added-highlight {
        background: #063c08;
        color: #7dab7f;
        padding: 0px 2px;
        border-radius: 1px;
        display: inline;
      }
      .prefix {
        font-weight: bold;
        margin-right: 8px;
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      }
    </style>
  </head>
  <body>
    <h1>$title</h1>
    <div class="stats">
      <strong>Total Changes:</strong> ${changes.length}
    </div>
    ${changes.isEmpty ? '<p style="color: #888;">No changes detected</p>' : ''}
    ${changes.asMap().entries.map((entry) {
      final index = entry.key;
      final change = entry.value;
      final label = change['label'] ?? '${index + 1}';
      final highlightedDiff = _highlightDifferences(change['original']!, change['modified']!);
      return '''
      <div class="change-item">
        <div class="change-number">#$label</div>
        <div class="line removed"><span class="prefix">-</span>${highlightedDiff['original']}</div>
        <div class="line added"><span class="prefix">+</span>${highlightedDiff['modified']}</div>
      </div>
      ''';
    }).join('\n')}
  </body>
  </html>
  ''';
    
    await File(outputPath).writeAsString(html);
  }
  
  Future<String> _getFontBase64() async {
    try {
      final fontData = await rootBundle.load('fonts/ScheherazadeNew-Regular.woff2');
      final bytes = fontData.buffer.asUint8List();
      return base64Encode(bytes);
    } catch (e) {
      print('Warning: Could not load font, using fallback. Error: $e');
      return '';
    }
  }
  
  Map<String, String> _highlightDifferences(String original, String modified) {
    final originalWords = original.split(' ');
    final modifiedWords = modified.split(' ');
    
    final alignment = _alignWords(originalWords, modifiedWords);
    
    final highlightedOriginal = <String>[];
    final highlightedModified = <String>[];
    
    for (final pair in alignment) {
      if (pair['orig'] != null && pair['mod'] != null) {
        if (pair['orig'] == pair['mod']) {
          highlightedOriginal.add(_escapeHtml(pair['orig']!));
          highlightedModified.add(_escapeHtml(pair['mod']!));
        } else {
          highlightedOriginal.add('<span class="removed-highlight">${_escapeHtml(pair['orig']!)}</span>');
          highlightedModified.add('<span class="added-highlight">${_escapeHtml(pair['mod']!)}</span>');
        }
      } else if (pair['orig'] != null) {
        highlightedOriginal.add('<span class="removed-highlight">${_escapeHtml(pair['orig']!)}</span>');
      } else if (pair['mod'] != null) {
        highlightedModified.add('<span class="added-highlight">${_escapeHtml(pair['mod']!)}</span>');
      }
    }
    
    return {
      'original': highlightedOriginal.join(' '),
      'modified': highlightedModified.join(' '),
    };
  }
  
  List<Map<String, String?>> _alignWords(List<String> original, List<String> modified) {
    final result = <Map<String, String?>>[];
    int i = 0;
    int j = 0;
    
    while (i < original.length || j < modified.length) {
      if (i >= original.length) {
        result.add({'orig': null, 'mod': modified[j]});
        j++;
      } else if (j >= modified.length) {
        result.add({'orig': original[i], 'mod': null});
        i++;
      } else if (original[i] == modified[j]) {
        result.add({'orig': original[i], 'mod': modified[j]});
        i++;
        j++;
      } else {
        bool foundMatch = false;
        
        for (int lookahead = 1; lookahead <= 10 && i + lookahead < original.length; lookahead++) {
          if (original[i + lookahead] == modified[j]) {
            for (int k = 0; k < lookahead; k++) {
              result.add({'orig': original[i + k], 'mod': null});
            }
            i += lookahead;
            foundMatch = true;
            break;
          }
        }
        
        if (!foundMatch) {
          for (int lookahead = 1; lookahead <= 10 && j + lookahead < modified.length; lookahead++) {
            if (original[i] == modified[j + lookahead]) {
              for (int k = 0; k < lookahead; k++) {
                result.add({'orig': null, 'mod': modified[j + k]});
              }
              j += lookahead;
              foundMatch = true;
              break;
            }
          }
        }
        
        if (!foundMatch) {
          result.add({'orig': original[i], 'mod': modified[j]});
          i++;
          j++;
        }
      }
    }
    
    return result;
  }
  
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _capitalizeProperNouns(String content) {
    content = _applyIslamicHonorifics(content);
    content = _applyGeographicNames(content);
    content = _applyPersonNames(content);
    content = _applyDatesAndDays(content);
    content = _applyMiscCapitalizations(content);
    
    return content;
  }

  String _applyIslamicHonorifics(String content) {
    content = content.replaceAllMapped(
      RegExp(
        r'\b(the\s+)?(prophet)\s+(peace be upon him|peace be upon them|'
        r'\(pbuh\)|\(saw\)|\(s\.a\.w\.?\)|'
        r's\.a\.w\.?|pbuh|saw|'
        r'sallallahu alayhi wa sallam)\b',
        caseSensitive: false
      ),
      (m) {
        final thePrefix = m.group(1);
        if (thePrefix != null) {
          final isUpperThe = thePrefix.trim() == 'The';
          return isUpperThe ? '___THE_PROPHET_PBUH_TEMP___' : '___the_PROPHET_PBUH_TEMP___';
        }
        return '___PROPHET_PBUH_TEMP___';
      },
    );
    
    final compoundPhrases = [
      [r"insha'Allah [Tt]a'ala", "inshaAllah ﷾"],
      [r"in [Ss]ha'Allah [Tt]a'ala", "inshaAllah ﷾"],
      [r"Allah subhanahu wa'ala", "Allah ﷾"],
      [r"Allah Subhanahu Ta'ala", "Allah ﷾"],
      [r"Allah Tawaraka wa Ta'ala", "Allah ﷾"],
      [r"Allah tabaraka wa ta'ala", "Allah ﷾"],
      [r"Allah tabarak wa ta'ala", "Allah ﷾"],
      [r"subhanahu wa'ta'ala", "﷾"],
      [r"subhanahu wa ta'ala", "﷾"],
      [r"wa'ta'ala", "﷾"],
      [r"wa ta'ala", "﷾"],
    ];
    
    for (final item in compoundPhrases) {
      content = content.replaceAllMapped(
        RegExp(item[0]),
        (m) => item[1],
      );
    }
  
    final swtVariations = [
      ["Allah subhanahu wa ta'ala Subhanahu wa ta'ala", 'Allah ﷾ '],
      ["Allah subhanahu alayhi wa sallamah Subhanahu Wa Ta'ala", 'Allah ﷾ '],
      ["Allah Subhanahu Wa Ta-A'la", 'Allah ﷾ '],
      ["Allah subhanahu wa ta'ala", 'Allah ﷾ '],
      ["Allah Subhanahu Wa Ta'ala", 'Allah ﷾ '],
      [r'Allah subhanahu wa taala', 'Allah ﷾ '],
      [r'Allah Subh\.anaHu Wa Ta-A\.la', 'Allah ﷾ '],
      [r'Allah Subh\.anaHu Wa Ta-Ala', 'Allah ﷾ '],
      [r'Allah subhanahu Allah Ta\.ala', 'Allah ﷾ '],
      [r'Allah Subh\.anaHu Wa Ta\.ala', 'Allah ﷾ '],
      ["Allah wa ta'ala", 'Allah ﷾ '],
      ["Allah sallallahu wa ta'ala", 'Allah ﷾ '],
      [r'Allah T\.W\.T\.', 'Allah ﷾ '],
      [r'allah swt\b', 'Allah ﷾ '],
      [r'Allah swt\b', 'Allah ﷾ '],
      [r'Allah \(SWT\)', 'Allah ﷾ '],
      [r'Allah s\.w\.t\.', 'Allah ﷾ '],
      [r'Allah s\.w\.w\.t\.', 'Allah ﷾ '],
      [r'Allah \(s\.w\.t\)', 'Allah ﷾ '],
      ["subhanahu wa ta'ala Subhanahu wa ta'ala", ' ﷾ '],
      ["subhanahu alayhi wa sallamah Subhanahu Wa Ta'ala", ' ﷾ '],
      ["Subhanahu Wa Ta-A'la", ' ﷾ '],
      ["subhanahu wa ta'ala", ' ﷾ '],
      ["Subhanahu Wa Ta'ala", ' ﷾ '],
      [r'subhanahu wa taala', ' ﷾ '],
      [r's\.w\.t\.', ' ﷾ '],
      [r'\(swt\)', ' ﷾ '],
    ];
    
    for (final item in swtVariations) {
      content = content.replaceAllMapped(
        RegExp(item[0], caseSensitive: false),
        (m) => item[1],
      );
    }
  
    final azzaVariations = [
      r"Azza wa ta'ala",
      r'Azza wa Alayhi',
      r'Azza wa Jaih',
      r'Azza wa Jai',
      r'azza wa jalanih wa sallam',
      r"azza wa jalani wa ta'ala",
      r"azza wa jalaihi wa ta'ala",
      r"azza wa jalanyahu wa ta'ala",
      r'azza wa jalani wa',
      r'azza wa jalani',
      r'azza wa jalla',
      r'azza wa jill',
      r'azza wa jall',
      r'azza wa jalal',
      r'azza wa jala',
      r'azza wa jail',
      r'azza wa jil',
      r'azza wa jal',
      r'azza wa jah',
      r'Azza wa Jal',
      r'azzawajal',
      r'Azzawajil',
      r'Azzawah',
      r'Azzawajan',
      r'Azawajil',
      r'azawajal',
      r'Azawajah',
      r'azawajib',
    ];
  
    for (final variation in azzaVariations) {
      content = content.replaceAllMapped(
        RegExp(r'\b' + variation + r'\b', caseSensitive: false),
        (m) => ' ﷿ ',
      );
    }
  
    final pbuhVariations = [
      r's\.a\.w\.a\.',
      r's\.a\.w\.',
      r'\(s\.a\.w\.\)',
      r'\(s\.a\.w\)',
      r'\(SAW\)',
      r'\(PBUH\)',
      r'\(S\. A\. W\)',
      r'wa ala alihi wa sahbihi wa sallam',
      r'sallallahu alayhi wa sallallahu alayhi wa sallamhu',
      r'Sallallahu Alaihi Wasallallahu Alaihi Wasallam',
      r'sallallahu alayhi wa sallamihi',
      r'Sallallahu alayhi wa sallamih',
      r'sallallahu alayhi wa sallamhi',
      r'sallallahu alayhi wa sallamh',
      r'sallallahu alayhi wa sallamim',
      r'sallallahu alayhi wa sallami',
      r"sallallahu alayhi wa ta'ala",
      r'sallallahu alayhi wa sallamuhu',
      r'sallallahu alayhi wa sallamu',
      r'sallallahu alayhi wa sallamakala',
      r'sallallahu alayhi wa sallamakal',
      r'sallallahu alayhi wa sallamaka',
      r'sallallahu alayhi wa sallamahe',
      r'sallallahu alayhi wa sallamayhi',
      r'sallallahu alayhi wa sallamahu',
      r'sallallahu alayhi wa sallamah',
      r'sallallahu alayhi wa sallama',
      r'sallallahu alaihi wa sallamahi',
      r'sallallahu alaihi wa sallamhi',
      r'sallallahu alaihi wa sallamahu',
      r'sallallahu alaihi wa sallamah',
      r'sallallahu alaihi wa sallama',
      r'salallahu alayhi wa sallamah',
      r'salallahu alayhi wa sallamahu',
      r'salallahu alayhi wa sallama',
      r'salallahu alaihi wa sallamah',
      r'salallahu alaihi wa sallama',
      r'sallallahu alayhi wa salami',
      r'sallallahu alayhi wa salamah',
      r'sallallahu alayhi wa salama',
      r'sallallahu alaihi wa salamah',
      r'sallallahu alaihi wa salamat',
      r'sallallahu alaihi wa salama',
      r'salallahu alayhi wa salamat',
      r'salallahu alayhi wa salamul',
      r'salallahu alayhi wa salamah',
      r'salallahu alayhi wa salamma',
      r'salallahu alayhi wa salama',
      r'salallahu alaihi wa salamah',
      r'salallahu alaihi wa salama',
      r'shallallahu alaihi wasallam',
      r'shallallahu alaihi wa sallam',
      r'sal allahu alayhi wa sallam',
      r'sal allahu alayhi wasallam',
      r'sal allahu alaihi wa sallam',
      r'sal allahu alaihi wasallam',
      r"sallallahu 'alayhi wa sallam",
      r"Sallallahu 'alayhi wa sallam",
      r'salallahu alayhi wa salami',
      r'salallahu alayhi wa salam',
      r'salallahu alaihi wasalam',
      r'shallallahu alayhi wa sallam',
      r'sallallahu wa sallam',
      r'sallallahu wa alayhi wa sallam',
      r'sallallahu alayhi wasalam',
      r'salallahu alaihi wa salam',
      r'salallahu alaihi wasallam',
      r'salallahu alayhi wa sallamu',
      r'salallahu alayhi wa sallam',
      r'salallahu alayhi wasallamah',
      r'salallahu alayhi wasallama',
      r'salallahu alayhi wasalam',
      r'salallahu alayhi wasallam',
      r'Sallallahu Alaihi Wasallamu',
      r'sallallahu alaihi wasallamah',
      r'sallallahu alaihi wasallam',
      r'sallallahu alaihi wa sallamu',
      r'sallallahu alaihi wa sallam',
      r'sallallahu alayhi wa sallam',
      r'sallallahu alayhi wa salam',
      r'sallallahu alayhi wasallamah',
      r'sallallahu alayhi wasallam',
      r'sal alahu alayhi wa salama',
      r'sal allahu alayhi wa salama',
      r'sal allahu alayhi wa salam',
      r"alayhi salamu wa ta'ala",
      r'sallallahu alayhi sallam',
      r'alayhi salamu alayhi sallam',
      r'alayhi wa sallamu alayhi',
      r'alayhi wa sallamah',
      r'alayhi wa sallamu',
      r'Alayhi As-Salaam',
      r'alayhi wa salaam',
      r'alayhi wa sallam',
      r'alayhi salatu wasalam',
      r'alayhi salatu salam',
      r'alayhi salaam',
      r'alayhi sallam',
      r'alayhi salami',
      r'alayhi salam',
      r'alayhi as-salam',
      r'salla Allahu alayhi wa salama',
      r'salla Allahu alayhi wa salam',
      r'peace be upon him',
      r'please be upon him',
      r'\(Sallallahu alayhi wa sallam\)',
      r'pbuh',
      r'PBUH',
      r'\(saw\)',
      r'\(SAW\)',
      r'\bSAW\b',
      r'\bSAWS\b',
    ];
  
    for (final variation in pbuhVariations) {
      final hasDotsOrParens = variation.contains(r'\.') || variation.contains(r'\(');
      final isSawsAcronym = variation == r'\bSAW\b' || variation == r'\bSAWS\b';
      
      if (hasDotsOrParens || isSawsAcronym) {
        content = content.replaceAllMapped(
          RegExp(variation),
          (m) => ' ﷺ ',
        );
      } else {
        content = content.replaceAllMapped(
          RegExp(r'\b' + variation + r'\b', caseSensitive: false),
          (m) => ' ﷺ ',
        );
      }
    }
  
    final prophetHonorifics = [
      [r'Ibrahim alayhi wa salam', 'Ibrahim ﵇ '],
      [r'Dawud alayhi wa salam', 'Dawud ﵇ '],
      [r'Musa alayhi wa salam', 'Musa ﵇ '],
      [r'Jibreel alayhi wa salam', 'Jibreel ﵇ '],
      [r'Harun alayhi wa salatu wa salam', 'Harun ﵇ '],
      [r'Isa alayhi wa salam', 'Isa ﵇ '],
      [r'Nuh alayhi wa salam', 'Nuh ﵇ '],
      [r'alayhi salatu wa salam', ' ﵇ '],
      [r'Alayhim wa salatu wa salam', ' ﵇ '],
      [r'alayhimu salatu wa salam', ' ﵈ '],
      [r'alayhi wa salatu wa salam', ' ﵈ '],
      [r'\(as\)', ' ﵇ '],
      [r'\(AS\)', ' ﵇ '],
      [r'a\.s\.', ' ﵇ '],
      [r'A\.S\.', ' ﵇ '],
    ];
  
    for (final item in prophetHonorifics) {
      content = content.replaceAllMapped(
        RegExp(item[0], caseSensitive: false),
        (m) => item[1],
      );
    }

    content = content.replaceAll('___THE_PROPHET_PBUH_TEMP___', 'The Prophet ﷺ ');
    content = content.replaceAll('___the_PROPHET_PBUH_TEMP___', 'the Prophet ﷺ ');
    content = content.replaceAll('___PROPHET_PBUH_TEMP___', 'Prophet ﷺ ');
  
    content = content.replaceAllMapped(
      RegExp(r'\bprophet muhammad\b', caseSensitive: false),
      (m) => 'Prophet Muhammad',
    );
  
    final radiyallahuVariations = [
      [r"rahimahum Allah ta'ala", ' ﵏ '],
      [r"rahimahum allahu wa ta'ala", ' ﵏ '],
      [r"rahimahu allahu ta'ala", ' ﵏ '],
      [r'radiallahu alayhi wa sallamah', ' ﵏ '],
      [r"radiallahu ta'ala anhumma", ' ﵄ '],
      [r"radiallahu ta'ala anhu", ' ﵄ '],
      [r"radiyallahu ta'ala anhu", ' ﵏ '],
      [r'radiallahu anhuma annahu', ' ﵄ '],
      [r'radiallahu anhuma anna', ' ﵄ '],
      [r'radiallahu anhumma', ' ﵄ '],
      [r'radiallahu anhumah', ' ﵄ '],
      [r'radhiallahu anhumma', ' ﵄ '],
      [r'radhiallahu anhumah', ' ﵄ '],
      [r'radiallahu anhuma', ' ﵄ '],
      [r'radiyallahu anhuma', ' ﵄ '],
      [r'radiyanhu ma', ' ﵄ '],
      [r'radiallahu anhum', ' ﵃ '],
      [r'radiyallahu anhum', ' ﵄ '],
      [r'radiallahu wa anhu', ' ﵁ '],
      [r'radiallahu anhu', ' ﵁ '],
      [r'radiyallahu anhu', ' ﵄ '],
      [r'radiallahu anha', ' ﵂ '],
      [r'radhiallahu anha', ' ﵂ '],
      [r'radiyallahu anha', ' ﵂ '],
      [r'radiya anha', ' ﵂ '],
      [r'rahimahullah qatada', ' ﵂ '],
      [r'radiya allah wanhu', ' ﵁ '],
      [r'radiyaanhu', ' ﵁ '],
      [r'radiyaanahu', ' ﵁ '],
      [r'radiyaan', ' ﵁ '],
      [r'radiyanha', ' ﵁ '],
      [r'radiyanhu', ' ﵁ '],
      [r'radiyanahu', ' ﵁ '],
      [r'radiyan', ' ﵁ '],
      [r'r\.a\.', ' ﵁ '],
      [r'\(ra\)', ' ﵁ '],
      [r'\(RA\)', ' ﵁ '],
    ];
  
    for (final item in radiyallahuVariations) {
      content = content.replaceAllMapped(
        RegExp(item[0], caseSensitive: false),
        (m) => item[1],
      );
    }
  
    final rahimahullahVariations = [
      r"rahimahallahu ta'ala",
      r"rahimahallahu wa ta'ala",
      r"rahimahullah wa ta'ala",
      r"rahimahullahu wa ta'ala",
      r"rahimahullahum ta'ala",
      r"rahimahullahu ta'ala",
      r"rahimahullah ta'ala",
      r"rahimahu wa ta'ala",
      r"rahimah wa ta'ala",
      r"rahimah Allah wa ta'ala",
      r'rahmatullah alayhumah',
      r'rahmatullah al-alayhi',
      r'rahmatullah alayhi',
      r'rahmatullah alayh',
      r'rahimahullah',
    ];
  
    for (final variation in rahimahullahVariations) {
      content = content.replaceAllMapped(
        RegExp(r'\b' + variation + r'\b', caseSensitive: false),
        (m) => ' ﵀ ',
      );
    }
  
    final bismillahVariations = [
      r'Bismillah ar-Rahman ar-Rahim',
      r'Bismillahirrahmanirrahim',
      r'Bismillahir Rahmanir Raheem',
      r'Bismillahir Rahmanir Rahim',
    ];
  
    for (final variation in bismillahVariations) {
      content = content.replaceAllMapped(
        RegExp(variation, caseSensitive: false),
        (m) => ' ﷽ ',
      );
    }
  
    final taalaVariations = [
      r"Allah ta'ala",
      r"Allahu ta'ala",
    ];
  
    for (final variation in taalaVariations) {
      content = content.replaceAllMapped(
        RegExp(r'\b' + variation + r'\b', caseSensitive: false),
        (m) => ' ﷾ ',
      );
    }
  
    content = content.replaceAll(RegExp(r'Messenger of Allah ﷺ', caseSensitive: false), '___MESSENGER_TEMP___');
    content = content.replaceAll(RegExp(r'Allah ﷺ'), 'Allah ﷾ ');
    content = content.replaceAll('___MESSENGER_TEMP___', 'Messenger of Allah ﷺ ');
  
    content = content.replaceAllMapped(
      RegExp(r'\bfuck\b|\bshit\b|\basshole\b|\bbitch\b|\bfucking\b', caseSensitive: false),
      (m) => '~~~~',
    );
  
    final islamicTerms = [
      [r"\ballah's\b", "Allah's"],
      [r'\ballah\b', 'Allah'],
      [r'al-Saadi', "As-Sa'di"],
      [r'As-Said', "As-Sa'di"],
      [r'\babraham\b', 'Abraham'],
      [r'\bapraham\b', 'Abraham'],
      [r'\bephraim\b', 'Ephraim'],
      [r'\bezekiel\b', 'Ezekiel'],
      [r'\bgurun\b', 'Quran'],
      [r'Hal al', 'Halal'],
      [r'hal al', 'halal'],
      [r'\bHarar\b', 'halal'],
      [r'\bharal\b', 'halal'],
      [r'\bhashim\b', 'Hashim'],
      [r'\bibrahim\b', 'Ibrahim'],
      [r"insha'Allah", 'inshaAllah'],
      [r"in Sha'Allah", 'inshaAllah'],
      [r'\bisiah\b', 'Isaiah'],
      [r'\bislam\b', 'Islam'],
      [r'\bislamic\b', 'Islamic'],
      [r'\bismail\b', 'Ismail'],
      [r'\bjesus\b', 'Jesus'],
      [r'\bjibril\b', 'Jibril'],
      [r'\bkadija\b', 'Khadija'],
      [r'\bkhadija\b', 'Khadija'],
      [r'\bKithir\b', 'Kathir'],
      [r'\bKuran\b', 'Quran'],
      [r'\bmaqab\b', 'maghrib'],
      [r'\bMaqab\b', 'Maghrib'],
      [r'\bmaryam\b', 'Maryam'],
      [r'message of Allah', 'Messenger of Allah'],
      [r'\bmohammed\b', 'Mohammed'],
      [r'\bmoses\b', 'Moses'],
      [r'\bmuhammad\b', 'Muhammad'],
      [r'\bmusa\b', 'Musa'],
      [r'\bmuslim\b', 'Muslim'],
      [r'\bnuh\b', 'Nuh'],
      [r'\bqibbeh\b', 'qiblah'],
      [r'\bquran\b', 'Quran'],
      [r'\bramadan\b', 'Ramadan'],
      [r'\brasulullah\b', 'Rasulullah'],
      [r'\bseera\b', 'seerah'],
      [r'\bSeera\b', 'Seerah'],
      [r'\bSira\b', 'Seerah'],
      [r'\bsirah\b', 'seerah'],
      [r'\bSirah\b', 'Seerah'],
      [r'\btajwid\b', 'tajweed'],
      [r'\btarheed\b', 'tawheed'],
      [r'\btayyib\b', 'Tayyib'],
      [r"To'heed", 'tawheed'],
      [r'\btoheed\b', 'tawheed'],
      [r'\btuahid\b', 'tawheed'],
      [r'\btuheed\b', 'tawheed'],
      [r'\bulemaa\b', 'ulema'],
      [r'\byahweh\b', 'Yahweh'],
      [r'\byeshua\b', 'Yeshua'],
      [r'\byusuf\b', 'Yusuf'],
    ];
  
    for (final item in islamicTerms) {
      content = content.replaceAllMapped(
        RegExp(item[0], caseSensitive: false),
        (m) => item[1],
      );
    }
  
    content = content.replaceAll('O Muhammad, except as a mercy to the Lord', '');
  
    return content;
  }
  
  
  
  String _applyMiscCapitalizations(String content) {
    final Map<String, String> misc = {
      r'\bmr\b\.?': 'Mr.',
      r'\bmrs\b\.?': 'Mrs.',
      r'\bdr\b\.?': 'Dr.',
      r'\b i \b': ' I ',
      r"\bi'm\b": "I'm", 
    };
  
    misc.forEach((pattern, replacement) {
      content = content.replaceAllMapped(
        RegExp(pattern, caseSensitive: false),
        (m) => replacement,
      );
    });
  
    return content;
  }

  String _applyGeographicNames(String content) {
    final Map<String, String> geographic = {
           r"\babuja\b": "Abuja",
           r"\babu dhabi\b": "Abu Dhabi",
           r"\babu bakr\b": "Abu Bakr",
           r"\baccra\b": "Accra",
           r"\badamstown\b": "Adamstown",
           r"\baddis ababa\b": "Addis Ababa",
           r"\bafghanistan\b": "Afghanistan",
           r"\bafrica\b": "Africa",
           r"\balabama\b": "Alabama",
           r"\balaska\b": "Alaska",
           r"\balbany\b": "Albany",
           r"\balbania\b": "Albania",
           r"\balexandria\b": "Alexandria",
           r"\balgeria\b": "Algeria",
           r"\balgiers\b": "Algiers",
           r"\balofi\b": "Alofi",
           r"\bamman\b": "Amman",
           r"\bamsterdam\b": "Amsterdam",
           r"\bandorra\b": "Andorra",
           r"\bandorra la vella\b": "Andorra La Vella",
           r"\bangola\b": "Angola",
           r"\bankara\b": "Ankara",
           r"\bannapolis\b": "Annapolis",
           r"\bantananarivo\b": "Antananarivo",
           r"\bantarctica\b": "Antarctica",
           r"\bantigua\b": "Antigua",
           r"\bapia\b": "Apia",
           r"\baramathia\b": "Aramathia",
           r"\barctic ocean\b": "Arctic Ocean",
           r"\bargentina\b": "Argentina",
           r"\barizona\b": "Arizona",
           r"\barkansas\b": "Arkansas",
           r"\barmenia\b": "Armenia",
           r"\bashgabat\b": "Ashgabat",
           r"\basia\b": "Asia",
           r"\basmara\b": "Asmara",
           r"\bastana\b": "Astana",
           r"\basuncion\b": "Asuncion",
           r"\bathens\b": "Athens",
           r"\batlanta\b": "Atlanta",
           r"\batlantic ocean\b": "Atlantic Ocean",
           r"\baugusta\b": "Augusta",
           r"\baustin\b": "Austin",
           r"\baustralia\b": "Australia",
           r"\baustria\b": "Austria",
           r"\bavarua\b": "Avarua",
           r"\bazerbaijan\b": "Azerbaijan",
           r"\bbabylon\b": "Babylon",
           r"\bbaghdad\b": "Baghdad",
           r"\bbahamas\b": "Bahamas",
           r"\bbahrain\b": "Bahrain",
           r"\bbaku\b": "Baku",
           r"\bbaltic\b": "Baltic",
           r"\bbamako\b": "Bamako",
           r"\bbandar seri begawan\b": "Bandar Seri Begawan",
           r"\bbangkok\b": "Bangkok",
           r"\bbangladesh\b": "Bangladesh",
           r"\bbangui\b": "Bangui",
           r"\bbanjul\b": "Banjul",
           r"\bbarbados\b": "Barbados",
           r"\bbarbuda\b": "Barbuda",
           r"\bbasse terre\b": "Basse Terre",
           r"\bbasseterre\b": "Basseterre",
           r"\bbaton rouge\b": "Baton Rouge",
           r"\bbeijing\b": "Beijing",
           r"\bbeirut\b": "Beirut",
           r"\bbelarus\b": "Belarus",
           r"\bbelgium\b": "Belgium",
           r"\bbelgrade\b": "Belgrade",
           r"\bbelize\b": "Belize",
           r"\bbelmopan\b": "Belmopan",
           r"\bbengaluru\b": "Bengaluru",
           r"\bbenin\b": "Benin",
           r"\bberlin\b": "Berlin",
           r"\bbern\b": "Bern",
           r"\bbhutan\b": "Bhutan",
           r"\bbishkek\b": "Bishkek",
           r"\bbismarck\b": "Bismarck",
           r"\bbissau\b": "Bissau",
           r"\bbogota\b": "Bogota",
           r"\bboise\b": "Boise",
           r"\bbolivia\b": "Bolivia",
           r"\bbosnia\b": "Bosnia",
           r"\bboston\b": "Boston",
           r"\bbotswana\b": "Botswana",
           r"\bbrasilia\b": "Brasilia",
           r"\bbratislava\b": "Bratislava",
           r"\bbrazil\b": "Brazil",
           r"\bbrazzaville\b": "Brazzaville",
           r"\bbridgetown\b": "Bridgetown",
           r"\bbritain\b": "Britain",
           r"\bbrunei\b": "Brunei",
           r"\bbrussels\b": "Brussels",
           r"\bbucharest\b": "Bucharest",
           r"\bbudapest\b": "Budapest",
           r"\bbuenos aires\b": "Buenos Aires",
           r"\bbujumbura\b": "Bujumbura",
           r"\bbulgaria\b": "Bulgaria",
           r"\bburundi\b": "Burundi",
           r"\bcairo\b": "Cairo",
           r"\bcalifornia\b": "California",
           r"\bcambodia\b": "Cambodia",
           r"\bcameroon\b": "Cameroon",
           r"\bcanaan\b": "Canaan",
           r"\bcanada\b": "Canada",
           r"\bcanberra\b": "Canberra",
           r"\bcape verde\b": "Cape Verde",
           r"\bcaracas\b": "Caracas",
           r"\bcarson city\b": "Carson City",
           r"\bcastries\b": "Castries",
           r"\bcayenne\b": "Cayenne",
           r"\bchad\b": "Chad",
           r"\bcharleston\b": "Charleston",
           r"\bcharlotte\b": "Charlotte",
           r"\bcharlotte amalie\b": "Charlotte Amalie",
           r"\bchengdu\b": "Chengdu",
           r"\bcheyenne\b": "Cheyenne",
           r"\bchicago\b": "Chicago",
           r"\bchile\b": "Chile",
           r"\bchina\b": "China",
           r"\bchisinau\b": "Chisinau",
           r"\bchongqing\b": "Chongqing",
           r"\bcity of san marino\b": "City of San Marino",
           r"\bcity of victoria\b": "City of Victoria",
           r"\bcockburn town\b": "Cockburn Town",
           r"\bcolombia\b": "Colombia",
           r"\bcolombo\b": "Colombo",
           r"\bcolorado\b": "Colorado",
           r"\bcolumbia\b": "Columbia",
           r"\bcolumbus\b": "Columbus",
           r"\bcomoros\b": "Comoros",
           r"\bconakry\b": "Conakry",
           r"\bconcord\b": "Concord",
           r"\bcongo\b": "Congo",
           r"\bconnecticut\b": "Connecticut",
           r"\bconstantinople\b": "Constantinople",
           r"\bcopenhagen\b": "Copenhagen",
           r"\bcosta rica\b": "Costa Rica",
           r"\bcroatia\b": "Croatia",
           r"\bcuba\b": "Cuba",
           r"\bcyprus\b": "Cyprus",
           r"\bczech republic\b": "Czech Republic",
           r"\bdakar\b": "Dakar",
           r"\bdamascus\b": "Damascus",
           r"\bdanzig\b": "Danzig",
           r"\bdelaware\b": "Delaware",
           r"\bdenmark\b": "Denmark",
           r"\bdenver\b": "Denver",
           r"\bdes moines\b": "Des Moines",
           r"\bdhaka\b": "Dhaka",
           r"\bdiego garcia\b": "Diego Garcia",
           r"\bdili\b": "Dili",
           r"\bdjibouti\b": "Djibouti",
           r"\bdodoma\b": "Dodoma",
           r"\bdoha\b": "Doha",
           r"\bdominican republic\b": "Dominican Republic",
           r"\bdover\b": "Dover",
           r"\bdubai\b": "Dubai",
           r"\bdublin\b": "Dublin",
           r"\bdushanbe\b": "Dushanbe",
           r"\beast timor\b": "East Timor",
           r"\becuador\b": "Ecuador",
           r"\begypt\b": "Egypt",
           r"\bel salvador\b": "El Salvador",
           r"\bengland\b": "England",
           r"\beritrea\b": "Eritrea",
           r"\bestonia\b": "Estonia",
           r"\beswatini\b": "Eswatini",
           r"\bethiopia\b": "Ethiopia",
           r"\beurope\b": "Europe",
           r"\bfakaofo\b": "Fakaofo",
           r"\bfiji\b": "Fiji",
           r"\bfinland\b": "Finland",
           r"\bflying fish cove\b": "Flying Fish Cove",
           r"\bflorida\b": "Florida",
           r"\bfort de france\b": "Fort De France",
           r"\bfrance\b": "France",
           r"\bfrankfurt\b": "Frankfurt",
           r"\bfreetown\b": "Freetown",
           r"\bfunafuti\b": "Funafuti",
           r"\bgabon\b": "Gabon",
           r"\bgaborone\b": "Gaborone",
           r"\bgambia\b": "Gambia",
           r"\bgeorge town\b": "George Town",
           r"\bgeorgetown\b": "Georgetown",
           r"\bgeorgia\b": "Georgia",
           r"\bgermany\b": "Germany",
           r"\bghana\b": "Ghana",
           r"\bgibraltar\b": "Gibraltar",
           r"\bgreece\b": "Greece",
           r"\bgrenada\b": "Grenada",
           r"\bguangzhou\b": "Guangzhou",
           r"\bguatemala\b": "Guatemala",
           r"\bguatemala city\b": "Guatemala City",
           r"\bguinea\b": "Guinea",
           r"\bguinea bissau\b": "Guinea Bissau",
           r"\bgustavia\b": "Gustavia",
           r"\bguyana\b": "Guyana",
           r"\bhagatna\b": "Hagatna",
           r"\bhaiti\b": "Haiti",
           r"\bhamburg\b": "Hamburg",
           r"\bhanoi\b": "Hanoi",
           r"\bharare\b": "Harare",
           r"\bharrisburg\b": "Harrisburg",
           r"\bhartford\b": "Hartford",
           r"\bhavana\b": "Havana",
           r"\bhawaii\b": "Hawaii",
           r"\bhelena\b": "Helena",
           r"\bhelsinki\b": "Helsinki",
           r"\bherzegovina\b": "Herzegovina",
           r"\bho chi minh\b": "Ho Chi Minh",
           r"\bhonduras\b": "Honduras",
           r"\bhong kong\b": "Hong Kong",
           r"\bhoniara\b": "Honiara",
           r"\bhonolulu\b": "Honolulu",
           r"\bhungary\b": "Hungary",
           r"\biceland\b": "Iceland",
           r"\bidaho\b": "Idaho",
           r"\billinois\b": "Illinois",
           r"\bindia\b": "India",
           r"\bindian ocean\b": "Indian Ocean",
           r"\bindiana\b": "Indiana",
           r"\bindianapolis\b": "Indianapolis",
           r"\bindonesia\b": "Indonesia",
           r"\biowa\b": "Iowa",
           r"\biran\b": "Iran",
           r"\biraq\b": "Iraq",
           r"\bireland\b": "Ireland",
           r"\bislamabad\b": "Islamabad",
           r"\bisrael\b": "Israel",
           r"\bistanbul\b": "Istanbul",
           r"\bitaly\b": "Italy",
           r"\bivory coast\b": "Ivory Coast",
           r"\bjakarta\b": "Jakarta",
           r"\bjamaica\b": "Jamaica",
           r"\bjapan\b": "Japan",
           r"\bjefferson city\b": "Jefferson City",
           r"\bjerusalem\b": "Jerusalem",
           r"\bjordan\b": "Jordan",
           r"\bjuba\b": "Juba",
           r"\bjudaea\b": "Judaea",
           r"\bjuneau\b": "Juneau",
           r"\bkabul\b": "Kabul",
           r"\bkampala\b": "Kampala",
           r"\bkansas\b": "Kansas",
           r"\bkarachi\b": "Karachi",
           r"\bkathmandu\b": "Kathmandu",
           r"\bkazakhstan\b": "Kazakhstan",
           r"\bkentucky\b": "Kentucky",
           r"\bkenya\b": "Kenya",
           r"\bkhartoum\b": "Khartoum",
           r"\bkiev\b": "Kiev",
           r"\bkigali\b": "Kigali",
           r"\bking edward point\b": "King Edward Point",
           r"\bkingston\b": "Kingston",
           r"\bkingstown\b": "Kingstown",
           r"\bkinshasa\b": "Kinshasa",
           r"\bkiribati\b": "Kiribati",
           r"\bkorea\b": "Korea",
           r"\bkuala\b": "Kuala",
           r"\bkuala lumpur\b": "Kuala Lumpur",
           r"\bkuwait\b": "Kuwait",
           r"\bkuwait city\b": "Kuwait City",
           r"\bkyrgyzstan\b": "Kyrgyzstan",
           r"\blaayoune\b": "Laayoune",
           r"\blagos\b": "Lagos",
           r"\blahore\b": "Lahore",
           r"\blansing\b": "Lansing",
           r"\blaos\b": "Laos",
           r"\blatvia\b": "Latvia",
           r"\blebanon\b": "Lebanon",
           r"\blesotho\b": "Lesotho",
           r"\bliberia\b": "Liberia",
           r"\blibreville\b": "Libreville",
           r"\blibya\b": "Libya",
           r"\bliechtenstein\b": "Liechtenstein",
           r"\blilongwe\b": "Lilongwe",
           r"\blincoln\b": "Lincoln",
           r"\blisbon\b": "Lisbon",
           r"\blithuania\b": "Lithuania",
           r"\blittle rock\b": "Little Rock",
           r"\bljubljana\b": "Ljubljana",
           r"\blobamba\b": "Lobamba",
           r"\blome\b": "Lome",
           r"\blondon\b": "London",
           r"\blongyearbyen\b": "Longyearbyen",
           r"\blouisiana\b": "Louisiana",
           r"\bluanda\b": "Luanda",
           r"\blusaka\b": "Lusaka",
           r"\bluxembourg\b": "Luxembourg",
           r"\bmadagascar\b": "Madagascar",
           r"\bmadison\b": "Madison",
           r"\bmadrid\b": "Madrid",
           r"\bmaine\b": "Maine",
           r"\bmajuro\b": "Majuro",
           r"\bmakkah\b": "Makkah",
           r"\bmalabo\b": "Malabo",
           r"\bmalawi\b": "Malawi",
           r"\bmalaysia\b": "Malaysia",
           r"\bmaldives\b": "Maldives",
           r"\bmali\b": "Mali",
           r"\bmalta\b": "Malta",
           r"\bmamoudzou\b": "Mamoudzou",
           r"\bmanagua\b": "Managua",
           r"\bmanama\b": "Manama",
           r"\bmanila\b": "Manila",
           r"\bmaputo\b": "Maputo",
           r"\bmariehamn\b": "Mariehamn",
           r"\bmarigot\b": "Marigot",
           r"\bmaryland\b": "Maryland",
           r"\bmaseru\b": "Maseru",
           r"\bmassachusetts\b": "Massachusetts",
           r"\bmata utu\b": "Mata Utu",
           r"\bmauritania\b": "Mauritania",
           r"\bmauritius\b": "Mauritius",
           r"\bmecca\b": "Mecca",
           r"\bmedina\b": "Medina",
           r"\bmesopotamia\b": "Mesopotamia",
           r"\bmexico\b": "Mexico",
           r"\bmexico city\b": "Mexico City",
           r"\bmichigan\b": "Michigan",
           r"\bmiddle east\b": "Middle East",
           r"\bminnesota\b": "Minnesota",
           r"\bminsk\b": "Minsk",
           r"\bmississippi\b": "Mississippi",
           r"\bmissouri\b": "Missouri",
           r"\bmogadishu\b": "Mogadishu",
           r"\bmoldova\b": "Moldova",
           r"\bmonaco\b": "Monaco",
           r"\bmongolia\b": "Mongolia",
           r"\bmonrovia\b": "Monrovia",
           r"\bmontana\b": "Montana",
           r"\bmontenegro\b": "Montenegro",
           r"\bmontevideo\b": "Montevideo",
           r"\bmontgomery\b": "Montgomery",
           r"\bmontpelier\b": "Montpelier",
           r"\bmorocco\b": "Morocco",
           r"\bmoroni\b": "Moroni",
           r"\bmoscow\b": "Moscow",
           r"\bmozambique\b": "Mozambique",
           r"\bmumbai\b": "Mumbai",
           r"\bmunich\b": "Munich",
           r"\bmuscat\b": "Muscat",
           r"\bmyanmar\b": "Myanmar",
           r"\bn'djamena\b": "N'djamena",
           r"\bnairobi\b": "Nairobi",
           r"\bnamibia\b": "Namibia",
           r"\bnashville\b": "Nashville",
           r"\bnassau\b": "Nassau",
           r"\bnauru\b": "Nauru",
           r"\bnay pyi taw\b": "Nay Pyi Taw",
           r"\bnebraska\b": "Nebraska",
           r"\bnepal\b": "Nepal",
           r"\bnetherlands\b": "Netherlands",
           r"\bnevada\b": "Nevada",
           r"\bnew delhi\b": "New Delhi",
           r"\bnew hampshire\b": "New Hampshire",
           r"\bnew jersey\b": "New Jersey",
           r"\bnew mexico\b": "New Mexico",
           r"\bnew york\b": "New York",
           r"\bnew zealand\b": "New Zealand",
           r"\bngerulmud\b": "Ngerulmud",
           r"\bniamey\b": "Niamey",
           r"\bnicaragua\b": "Nicaragua",
           r"\bnicosia\b": "Nicosia",
           r"\bniger\b": "Niger",
           r"\bnigeria\b": "Nigeria",
           r"\bningbo\b": "Ningbo",
           r"\bnormandy\b": "Normandy",
           r"\bnorth america\b": "North America",
           r"\bnorth carolina\b": "North Carolina",
           r"\bnorth dakota\b": "North Dakota",
           r"\bnorth korea\b": "North Korea",
           r"\bnorth macedonia\b": "North Macedonia",
           r"\bnorway\b": "Norway",
           r"\bnouakchott\b": "Nouakchott",
           r"\bnoumea\b": "Noumea",
           r"\bnuuk\b": "Nuuk",
           r"\bohio\b": "Ohio",
           r"\boklahoma\b": "Oklahoma",
           r"\boklahoma city\b": "Oklahoma City",
           r"\bolympia\b": "Olympia",
           r"\boman\b": "Oman",
           r"\boranjestad\b": "Oranjestad",
           r"\boregon\b": "Oregon",
           r"\bosaka\b": "Osaka",
           r"\boslo\b": "Oslo",
           r"\bottawa\b": "Ottawa",
           r"\bouagadougou\b": "Ouagadougou",
           r"\bpacific ocean\b": "Pacific Ocean",
           r"\bpago pago\b": "Pago Pago",
           r"\bpakistan\b": "Pakistan",
           r"\bpalau\b": "Palau",
           r"\bpalestine\b": "Palestine",
           r"\bpalikir\b": "Palikir",
           r"\bpanama\b": "Panama",
           r"\bpanama city\b": "Panama City",
           r"\bpapeete\b": "Papeete",
           r"\bpapua new guinea\b": "Papua New Guinea",
           r"\bparaguay\b": "Paraguay",
           r"\bparamaribo\b": "Paramaribo",
           r"\bparis\b": "Paris",
           r"\bpattaya\b": "Pattaya",
           r"\bpennsylvania\b": "Pennsylvania",
           r"\bperu\b": "Peru",
           r"\bphilippines\b": "Philippines",
           r"\bphilipsburg\b": "Philipsburg",
           r"\bphnom penh\b": "Phnom Penh",
           r"\bphoenix\b": "Phoenix",
           r"\bphuket\b": "Phuket",
           r"\bpierre\b": "Pierre",
           r"\bplymouth\b": "Plymouth",
           r"\bpodgorica\b": "Podgorica",
           r"\bpoland\b": "Poland",
           r"\bport au prince\b": "Port Au Prince",
           r"\bport aux francais\b": "Port Aux Francais",
           r"\bport louis\b": "Port Louis",
           r"\bport moresby\b": "Port Moresby",
           r"\bport of spain\b": "Port of Spain",
           r"\bport vila\b": "Port Vila",
           r"\bporto novo\b": "Porto Novo",
           r"\bportugal\b": "Portugal",
           r"\bprague\b": "Prague",
           r"\bpraia\b": "Praia",
           r"\bpretoria\b": "Pretoria",
           r"\bprinceton\b": "Princeton",
           r"\bpristina\b": "Pristina",
           r"\bprussia\b": "Prussia",
           r"\bpyongyang\b": "Pyongyang",
           r"\bqatar\b": "Qatar",
           r"\bquito\b": "Quito",
           r"\brabat\b": "Rabat",
           r"\braleigh\b": "Raleigh",
           r"\breykjavik\b": "Reykjavik",
           r"\brhode island\b": "Rhode Island",
           r"\brichmond\b": "Richmond",
           r"\briga\b": "Riga",
           r"\briyadh\b": "Riyadh",
           r"\broad town\b": "Road Town",
           r"\bromania\b": "Romania",
           r"\brome\b": "Rome",
           r"\broseau\b": "Roseau",
           r"\brussia\b": "Russia",
           r"\brwanda\b": "Rwanda",
           r"\bsacramento\b": "Sacramento",
           r"\bsaint denis\b": "Saint Denis",
           r"\bsaint johns\b": "Saint John's",
           r"\bsaint pierre\b": "Saint Pierre",
           r"\bsaipan\b": "Saipan",
           r"\bsalem\b": "Salem",
           r"\bsalt lake city\b": "Salt Lake City",
           r"\bsamoa\b": "Samoa",
           r"\bsan jose\b": "San Jose",
           r"\bsan juan\b": "San Juan",
           r"\bsan marino\b": "San Marino",
           r"\bsan salvador\b": "San Salvador",
           r"\bsanaa\b": "Sanaa",
           r"\bsanta fe\b": "Santa Fe",
           r"\bsantiago\b": "Santiago",
           r"\bsanto domingo\b": "Santo Domingo",
           r"\bsao paulo\b": "Sao Paulo",
           r"\bsao tome\b": "Sao Tome",
           r"\bsarajevo\b": "Sarajevo",
           r"\bsaudi arabia\b": "Saudi Arabia",
           r"\bsenegal\b": "Senegal",
           r"\bseoul\b": "Seoul",
           r"\bserbia\b": "Serbia",
           r"\bseychelles\b": "Seychelles",
           r"\bsham\b": "Sham",
           r"\bshanghai\b": "Shanghai",
           r"\bshenzhen\b": "Shenzhen",
           r"\bsierra leone\b": "Sierra Leone",
           r"\bsingapore\b": "Singapore",
           r"\bskopje\b": "Skopje",
           r"\bslovakia\b": "Slovakia",
           r"\bslovenia\b": "Slovenia",
           r"\bsofia\b": "Sofia",
           r"\bsolomon islands\b": "Solomon Islands",
           r"\bsomalia\b": "Somalia",
           r"\bsouth africa\b": "South Africa",
           r"\bsouth america\b": "South America",
           r"\bsouth carolina\b": "South Carolina",
           r"\bsouth dakota\b": "South Dakota",
           r"\bsouth korea\b": "South Korea",
           r"\bsouth sudan\b": "South Sudan",
           r"\bsouth tarawa\b": "South Tarawa",
           r"\bsoviet union\b": "Soviet Union",
           r"\bspain\b": "Spain",
           r"\bspringfield\b": "Springfield",
           r"\bsri lanka\b": "Sri Lanka",
           r"\bstalingrad\b": "Stalingrad",
           r"\bstockholm\b": "Stockholm",
           r"\bsucre\b": "Sucre",
           r"\bsudan\b": "Sudan",
           r"\bsuriname\b": "Suriname",
           r"\bsuva\b": "Suva",
           r"\bsweden\b": "Sweden",
           r"\bswitzerland\b": "Switzerland",
           r"\bsyria\b": "Syria",
           r"\btaipei\b": "Taipei",
           r"\btaiwan\b": "Taiwan",
           r"\btajikistan\b": "Tajikistan",
           r"\btallahassee\b": "Tallahassee",
           r"\btallinn\b": "Tallinn",
           r"\btanzania\b": "Tanzania",
           r"\btashkent\b": "Tashkent",
           r"\btbilisi\b": "Tbilisi",
           r"\btegucigalpa\b": "Tegucigalpa",
           r"\btehran\b": "Tehran",
           r"\btennessee\b": "Tennessee",
           r"\btexas\b": "Texas",
           r"\bthailand\b": "Thailand",
           r"\bthimphu\b": "Thimphu",
           r"\btianjin\b": "Tianjin",
           r"\btirana\b": "Tirana",
           r"\btobago\b": "Tobago",
           r"\btogo\b": "Togo",
           r"\btokyo\b": "Tokyo",
           r"\btonga\b": "Tonga",
           r"\btopeka\b": "Topeka",
           r"\btorshavn\b": "Torshavn",
           r"\btrenton\b": "Trenton",
           r"\btrinidad\b": "Trinidad",
           r"\btripoli\b": "Tripoli",
           r"\btunis\b": "Tunis",
           r"\btunisia\b": "Tunisia",
           r"\bturkmenistan\b": "Turkmenistan",
           r"\btuvalu\b": "Tuvalu",
           r"\buganda\b": "Uganda",
           r"\bukraine\b": "Ukraine",
           r"\bulan bator\b": "Ulan Bator",
           r"\bunited arab emirates\b": "United Arab Emirates",
           r"\bunited kingdom\b": "United Kingdom",
           r"\bunited states\b": "United States",
           r"\buruguay\b": "Uruguay",
           r"\busa\b": "U.S.A.",
           r"\bu\.s\.?\b": "U.S.",
           r"\butah\b": "Utah",
           r"\buzbekistan\b": "Uzbekistan",
           r"\bvaduz\b": "Vaduz",
           r"\bvalletta\b": "Valletta",
           r"\bvanuatu\b": "Vanuatu",
           r"\bvatican\b": "Vatican",
           r"\bvatican city\b": "Vatican City",
           r"\bvenezuela\b": "Venezuela",
           r"\bvermont\b": "Vermont",
           r"\bvictoria\b": "Victoria",
           r"\bvienna\b": "Vienna",
           r"\bvientiane\b": "Vientiane",
           r"\bvietnam\b": "Vietnam",
           r"\bvilnius\b": "Vilnius",
           r"\bvirginia\b": "Virginia",
           r"\bwarsaw\b": "Warsaw",
           r"\bwashington\b": "Washington",
           r"\bwashington dc\b": "Washington DC",
           r"\bwellington\b": "Wellington",
           r"\bwest island\b": "West Island",
           r"\bwest virginia\b": "West Virginia",
           r"\bwillemstad\b": "Willemstad",
           r"\bwindhoek\b": "Windhoek",
           r"\bwisconsin\b": "Wisconsin",
           r"\bwyoming\b": "Wyoming",
           r"\byamoussoukro\b": "Yamoussoukro",
           r"\byaounde\b": "Yaounde",
           r"\byaren\b": "Yaren",
           r"\byemen\b": "Yemen",
           r"\byerevan\b": "Yerevan",
           r"\bzagreb\b": "Zagreb",
           r"\bzambia\b": "Zambia",
           r"\bzimbabwe\b": "Zimbabwe",
    };

    geographic.forEach((pattern, replacement) {
      content = content.replaceAllMapped(
        RegExp(pattern, caseSensitive: false),
        (m) => replacement,
      );
    });

    return content;
  }

  String _applyPersonNames(String content) {
    final Map<String, String> names = {
        r'\baaron\b': 'Aaron',
        r'\babbas\b': 'Abbas',
        r'\babigail\b': 'Abigail',
        r'\badam\b': 'Adam',
        r'\badams\b': 'Adams',
        r'\badolf\b': 'Adolf',
        r'\badonis\b': 'Adonis',
        r'\balan\b': 'Alan',
        r'\balbert\b': 'Albert',
        r'\balexander\b': 'Alexander',
        r'\balexis\b': 'Alexis',
        r'\bali\b': 'Ali',
        r'\balice\b': 'Alice',
        r'\ballen\b': 'Allen',
        r'\bamanda\b': 'Amanda',
        r'\bamber\b': 'Amber',
        r'\banderson\b': 'Anderson',
        r'\bandrea\b': 'Andrea',
        r'\bandrew\b': 'Andrew',
        r'\bangela\b': 'Angela',
        r'\bann\b': 'Ann',
        r'\banne\b': 'Anne',
        r'\banthony\b': 'Anthony',
        r'\bantoinette\b': 'Antoinette',
        r'\baristotle\b': 'Aristotle',
        r'\barmstrong\b': 'Armstrong',
        r'\barthur\b': 'Arthur',
        r'\bashley\b': 'Ashley',
        r'\baugustine\b': 'Augustine',
        r'\baugustus\b': 'Augustus',
        r'\bbailey\b': 'Bailey',
        r'\bbarbara\b': 'Barbara',
        r'\bbarnes\b': 'Barnes',
        r'\bbenjamin\b': 'Benjamin',
        r'\bbennett\b': 'Bennett',
        r'\bbetty\b': 'Betty',
        r'\bbeverly\b': 'Beverly',
        r'\bbilly\b': 'Billy',
        r'\bbobby\b': 'Bobby',
        r'\bbradley\b': 'Bradley',
        r'\bbrandon\b': 'Brandon',
        r'\bbrenda\b': 'Brenda',
        r'\bbrian\b': 'Brian',
        r'\bbrittany\b': 'Brittany',
        r'\bbruce\b': 'Bruce',
        r'\bbryan\b': 'Bryan',
        r'\bbuddha\b': 'Buddha',
        r'\bbukhari\b': 'Bukhari',
        r'\bcaesar\b': 'Caesar',
        r'\bcampbell\b': 'Campbell',
        r'\bcarl\b': 'Carl',
        r'\bcarol\b': 'Carol',
        r'\bcarolyn\b': 'Carolyn',
        r'\bcarter\b': 'Carter',
        r'\bcatherine\b': 'Catherine',
        r'\bchad\b': 'Chad',
        r'\bcharles\b': 'Charles',
        r'\bcharlotte\b': 'Charlotte',
        r'\bcheryl\b': 'Cheryl',
        r'\bchrist\b': 'Christ',
        r'\bchristina\b': 'Christina',
        r'\bchristine\b': 'Christine',
        r'\bchristopher\b': 'Christopher',
        r'\bchurchill\b': 'Churchill',
        r'\bclark\b': 'Clark',
        r'\bcleopatra\b': 'Cleopatra',
        r'\bcollins\b': 'Collins',
        r'\bconstantine\b': 'Constantine',
        r'\bcooper\b': 'Cooper',
        r'\bcox\b': 'Cox',
        r'\bcraig\b': 'Craig',
        r'\bcruz\b': 'Cruz',
        r'\bcynthia\b': 'Cynthia',
        r'\bdaniel\b': 'Daniel',
        r'\bdanielle\b': 'Danielle',
        r'\bdarwin\b': 'Darwin',
        r'\bdave\b': 'Dave',
        r'\bdavid\b': 'David',
        r'\bdavis\b': 'Davis',
        r'\bdawud\b': 'Dawud',
        r'\bdeborah\b': 'Deborah',
        r'\bdebra\b': 'Debra',
        r'\bdenise\b': 'Denise',
        r'\bdennis\b': 'Dennis',
        r'\bdiana\b': 'Diana',
        r'\bdiane\b': 'Diane',
        r'\bdiaz\b': 'Diaz',
        r'\bdonald\b': 'Donald',
        r'\bdonna\b': 'Donna',
        r'\bdoris\b': 'Doris',
        r'\bdorothy\b': 'Dorothy',
        r'\bdouglas\b': 'Douglas',
        r'\bdylan\b': 'Dylan',
        r'\bedison\b': 'Edison',
        r'\bedward\b': 'Edward',
        r'\bedwards\b': 'Edwards',
        r'\beinstein\b': 'Einstein',
        r'\belijah\b': 'Elijah',
        r'\belizabeth\b': 'Elizabeth',
        r'\bemily\b': 'Emily',
        r'\bemma\b': 'Emma',
        r'\beric\b': 'Eric',
        r'\bethan\b': 'Ethan',
        r'\beugene\b': 'Eugene',
        r'\bevans\b': 'Evans',
        r'\bevelyn\b': 'Evelyn',
        r'\bfatima\b': 'Fatima',
        r'\bfisher\b': 'Fisher',
        r'\bflores\b': 'Flores',
        r'\bfrances\b': 'Frances',
        r'\bfrancisco\b': 'Francisco',
        r'\bfranco\b': 'Franco',
        r'\bfranklin\b': 'Franklin',
        r'\bgabriel\b': 'Gabriel',
        r'\bgarcia\b': 'Garcia',
        r'\bgary\b': 'Gary',
        r'\bgenghis\b': 'Genghis',
        r'\bgeorge\b': 'George',
        r'\bgerald\b': 'Gerald',
        r'\bgloria\b': 'Gloria',
        r'\bgomez\b': 'Gomez',
        r'\bgonzalez\b': 'Gonzalez',
        r'\bgregory\b': 'Gregory',
        r'\bgutierrez\b': 'Gutierrez',
        r'\bhamza\b': 'Hamza',
        r'\bhamilton\b': 'Hamilton',
        r'\bhannah\b': 'Hannah',
        r'\bhannibal\b': 'Hannibal',
        r'\bharold\b': 'Harold',
        r'\bharris\b': 'Harris',
        r'\bheather\b': 'Heather',
        r'\bhelen\b': 'Helen',
        r'\bhenry\b': 'Henry',
        r'\bhernandez\b': 'Hernandez',
        r'\bhitler\b': 'Hitler',
        r'\bhoward\b': 'Howard',
        r'\bhughes\b': 'Hughes',
        r'\bisa\b': 'Isa',
        r'\bisaac\b': 'Isaac',
        r'\bisabella\b': 'Isabella',
        r'\bisaiah\b': 'Isaiah',
        r'\bismail\b': 'Ismail',
        r'\bjack\b': 'Jack',
        r'\bjackson\b': 'Jackson',
        r'\bjacob\b': 'Jacob',
        r'\bjacqueline\b': 'Jacqueline',
        r'\bjames\b': 'James',
        r'\bjanet\b': 'Janet',
        r'\bjanice\b': 'Janice',
        r'\bjason\b': 'Jason',
        r'\bjay\b': 'Jay',
        r'\bjean\b': 'Jean',
        r'\bjeffrey\b': 'Jeffrey',
        r'\bjenkins\b': 'Jenkins',
        r'\bjennifer\b': 'Jennifer',
        r'\bjenny\b': 'Jenny',
        r'\bjeremy\b': 'Jeremy',
        r'\bjerry\b': 'Jerry',
        r'\bjesse\b': 'Jesse',
        r'\bjessica\b': 'Jessica',
        r'\bjibreel\b': 'Jibreel',
        r'\bjoan\b': 'Joan',
        r'\bjoan of arc\b': 'Joan of Arc',
        r'\bjoe\b': 'Joe',
        r'\bjoel\b': 'Joel',
        r'\bjohn\b': 'John',
        r'\bjohnson\b': 'Johnson',
        r'\bjonah\b': 'Jonah',
        r'\bjonathan\b': 'Jonathan',
        r'\bjones\b': 'Jones',
        r'\bjordan\b': 'Jordan',
        r'\bjose\b': 'Jose',
        r'\bjoseph\b': 'Joseph',
        r'\bjosh\b': 'Josh',
        r'\bjoshua\b': 'Joshua',
        r'\bjoyce\b': 'Joyce',
        r'\bjuan\b': 'Juan',
        r'\bjudith\b': 'Judith',
        r'\bjudy\b': 'Judy',
        r'\bjulia\b': 'Julia',
        r'\bjulie\b': 'Julie',
        r'\bjulius\b': 'Julius',
        r'\bjustin\b': 'Justin',
        r'\bkaren\b': 'Karen',
        r'\bkarl\b': 'Karl',
        r'\bkatherine\b': 'Katherine',
        r'\bkathir\b': 'Kathir',
        r'\bkathleen\b': 'Kathleen',
        r'\bkathryn\b': 'Kathryn',
        r'\bkayla\b': 'Kayla',
        r'\bkeith\b': 'Keith',
        r'\bkelly\b': 'Kelly',
        r'\bkennedy\b': 'Kennedy',
        r'\bkenneth\b': 'Kenneth',
        r'\bkevin\b': 'Kevin',
        r'\bkhan\b': 'Khan',
        r'\bkimberly\b': 'Kimberly',
        r'\bkyle\b': 'Kyle',
        r'\blarry\b': 'Larry',
        r'\blaura\b': 'Laura',
        r'\blauren\b': 'Lauren',
        r'\blawrence\b': 'Lawrence',
        r'\blee\b': 'Lee',
        r'\blenin\b': 'Lenin',
        r'\bleonardo\b': 'Leonardo',
        r'\bleslie\b': 'Leslie',
        r'\blewis\b': 'Lewis',
        r'\blinda\b': 'Linda',
        r'\blisa\b': 'Lisa',
        r'\blogan\b': 'Logan',
        r'\blopez\b': 'Lopez',
        r'\blori\b': 'Lori',
        r'\blouis\b': 'Louis',
        r'\bluther\b': 'Luther',
        r'\bmadison\b': 'Madison',
        r'\bmandela\b': 'Mandela',
        r'\bmargaret\b': 'Margaret',
        r'\bmaria\b': 'Maria',
        r'\bmarie\b': 'Marie',
        r'\bmarilyn\b': 'Marilyn',
        r'\bmartha\b': 'Martha',
        r'\bmartin\b': 'Martin',
        r'\bmartinez\b': 'Martinez',
        r'\bmarx\b': 'Marx',
        r'\bmary\b': 'Mary',
        r'\bmason\b': 'Mason',
        r'\bmatthew\b': 'Matthew',
        r'\bmedici\b': 'Medici',
        r'\bmegan\b': 'Megan',
        r'\bmelissa\b': 'Melissa',
        r'\bmichael\b': 'Michael',
        r'\bmichelle\b': 'Michelle',
        r'\bmiller\b': 'Miller',
        r'\bmitchell\b': 'Mitchell',
        r'\bmoore\b': 'Moore',
        r'\bmorales\b': 'Morales',
        r'\bmorgan\b': 'Morgan',
        r'\bmorris\b': 'Morris',
        r'\bmoses\b': 'Moses',
        r'\bmosley\b': 'Mosley',
        r'\bmurphy\b': 'Murphy',
        r'\bmusa\b': 'Musa',
        r'\bmussolini\b': 'Mussolini',
        r'\bmyers\b': 'Myers',
        r'\bnancy\b': 'Nancy',
        r'\bnapoleon\b': 'Napoleon',
        r'\bnatalie\b': 'Natalie',
        r'\bnathan\b': 'Nathan',
        r'\bnelson\b': 'Nelson',
        r'\bnguyen\b': 'Nguyen',
        r'\bnicholas\b': 'Nicholas',
        r'\bnicole\b': 'Nicole',
        r'\bnoah\b': 'Noah',
        r'\bnorman\b': 'Norman',
        r'\bolivia\b': 'Olivia',
        r'\bortiz\b': 'Ortiz',
        r'\boswald\b': 'Oswald',
        r'\bpamela\b': 'Pamela',
        r'\bparker\b': 'Parker',
        r'\bpatricia\b': 'Patricia',
        r'\bpatrick\b': 'Patrick',
        r'\bpaul\b': 'Paul',
        r'\bperez\b': 'Perez',
        r'\bperry\b': 'Perry',
        r'\bpeter\b': 'Peter',
        r'\bpeterson\b': 'Peterson',
        r'\bphilip\b': 'Philip',
        r'\bphillips\b': 'Phillips',
        r'\bplato\b': 'Plato',
        r'\bpowell\b': 'Powell',
        r'\brabb\b': 'Rabb',
        r'\brab\b': 'Rabb',
        r'\brachel\b': 'Rachel',
        r'\bralph\b': 'Ralph',
        r'\bramirez\b': 'Ramirez',
        r'\brandy\b': 'Randy',
        r'\braymond\b': 'Raymond',
        r'\brebecca\b': 'Rebecca',
        r'\breyes\b': 'Reyes',
        r'\brichard\b': 'Richard',
        r'\brichardson\b': 'Richardson',
        r'\brivera\b': 'Rivera',
        r'\brobert\b': 'Robert',
        r'\broberts\b': 'Roberts',
        r'\brobinson\b': 'Robinson',
        r'\brodriguez\b': 'Rodriguez',
        r'\broger\b': 'Roger',
        r'\brogers\b': 'Rogers',
        r'\bronald\b': 'Ronald',
        r'\broosevelt\b': 'Roosevelt',
        r'\bross\b': 'Ross',
        r'\broy\b': 'Roy',
        r'\brussell\b': 'Russell',
        r'\bruth\b': 'Ruth',
        r'\bryan\b': 'Ryan',
        r'\bsamantha\b': 'Samantha',
        r'\bsamuel\b': 'Samuel',
        r'\bsanchez\b': 'Sanchez',
        r'\bsanders\b': 'Sanders',
        r'\bsandra\b': 'Sandra',
        r'\bsara\b': 'Sara',
        r'\bsarah\b': 'Sarah',
        r'\bscott\b': 'Scott',
        r'\bsean\b': 'Sean',
        r'\bshakespeare\b': 'Shakespeare',
        r'\bsharon\b': 'Sharon',
        r'\bshirley\b': 'Shirley',
        r'\bsmith\b': 'Smith',
        r'\bsophia\b': 'Sophia',
        r'\bstalin\b': 'Stalin',
        r'\bstanley\b': 'Stanley',
        r'\bstephanie\b': 'Stephanie',
        r'\bstephen\b': 'Stephen',
        r'\bsteven\b': 'Steven',
        r'\bstewart\b': 'Stewart',
        r'\bsullivan\b': 'Sullivan',
        r'\bsusan\b': 'Susan',
        r'\btaylor\b': 'Taylor',
        r'\bteresa\b': 'Teresa',
        r'\bterry\b': 'Terry',
        r'\btheresa\b': 'Theresa',
        r'\bthomas\b': 'Thomas',
        r'\bthompson\b': 'Thompson',
        r'\btimothy\b': 'Timothy',
        r'\btorres\b': 'Torres',
        r'\btyler\b': 'Tyler',
        r'\bvincent\b': 'Vincent',
        r'\bvinci\b': 'Vinci',
        r'\bvladimir\b': 'Vladimir',
        r'\bwalker\b': 'Walker',
        r'\bwalter\b': 'Walter',
        r'\bwatson\b': 'Watson',
        r'\bwayne\b': 'Wayne',
        r'\bwilliam\b': 'William',
        r'\bwilliams\b': 'Williams',
        r'\bwillie\b': 'Willie',
        r'\bwilson\b': 'Wilson',
        r'\bwinston\b': 'Winston',
        r'\bwright\b': 'Wright',
        r'\bzachary\b': 'Zachary',
    };

    names.forEach((pattern, replacement) {
      content = content.replaceAllMapped(
        RegExp(pattern, caseSensitive: false),
        (m) => replacement,
      );
    });

    return content;
  }

  String _applyDatesAndDays(String content) {
    final Map<String, String> dates = {
      // Days of the week and holidays
            r'\bmonday\b': 'Monday',
            r'\btuesday\b': 'Tuesday',
            r'\bwednesday\b': 'Wednesday',
            r'\bthursday\b': 'Thursday',
            r'\bfriday\b': 'Friday',
            r'\bsaturday\b': 'Saturday',
            r'\bsunday\b': 'Sunday',
            r'\bjanuary\b': 'January',
            r'\bfebruary\b': 'February',
            r'\bapril\b': 'April',
            r'\bjune\b': 'June',
            r'\bjuly\b': 'July',
            r'\baugust\b': 'August',
            r'\bseptember\b': 'September',
            r'\boctober\b': 'October',
            r'\bnovember\b': 'November',
            r'\bdecember\b': 'December',
            r'\bapril fools day\b': 'April Fools\' Day',
            r'\bchristmas\b': 'Christmas',
            r'\bchristmas day\b': 'Christmas Day',
            r'\bchristmas eve\b': 'Christmas Eve',
            r'\beaster\b': 'Easter',
            r'\beid\b': 'Eid',
            r'\bhalloween\b': 'Halloween',
            r'\bhanukkah\b': 'Hanukkah',
            r'\bhappy new year\b': 'Happy New Year',
            r'\bindependence day\b': 'Independence Day',
            r'\blabor day\b': 'Labor Day',
            r'\bnew years day\b': 'New Year\'s Day',
            r'\bnew years eve\b': 'New Year\'s Eve',
            r'\bpassover\b': 'Passover',
            r'\bpurim\b': 'Purim',
            r'\bramadan\b': 'Ramadan',
            r'\bsaint patricks day\b': 'Saint Patrick\'s Day',
            r'\bshabbat\b': 'Shabbat',
            r'\bthanksgiving\b': 'Thanksgiving',
            r'\bthanksgiving day\b': 'Thanksgiving Day',
            r'\bvalentines day\b': 'Valentine\'s Day',
            r'\bwinter solstice\b': 'Winter Solstice',
            r'\byom kippur\b': 'Yom Kippur',
    };

    dates.forEach((pattern, replacement) {
      content = content.replaceAllMapped(
        RegExp(pattern, caseSensitive: false),
        (m) => replacement,
      );
    });

    return content;
  }

  String _capitalizeSentenceStarts(String content) {
    content = content.replaceAllMapped(
      RegExp(r'([a-z0-9])([\?\.!] )([a-z])'),
      (match) => '${match.group(1)}${match.group(2)}${match.group(3)!.toUpperCase()}',
    );

    return content;
  }

  @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('VTT Processing: Repeats + Proper Nouns'),
          backgroundColor: Colors.grey[900],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Process VTT Subtitles',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will:\n'
                '1. Remove repeating words (the the → the)\n'
                '2. Apply single-line honorifics\n'
                '3. Fix cross-subtitle honorifics\n'
                '4. Capitalize proper nouns\n'
                '5. Generate HTML change reports\n'
                '6. Repeat fixes only use audiobookname_repeats.vtt as final subtitles\n'
                '7. Repeat fixes, pronouns, honorifics and use audiobookname_pronouns.vtt as final subtitles\n'
                '8. Use _repeats.vtt as final vtt if only want repeats corrections\n'
                '9. Use _propernoun.vtt as final vtt includes repeats and proper noun, honorific corrections',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _selectVttFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Select VTT File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedVttPath != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected file:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        path.basename(_selectedVttPath!),
                        style: const TextStyle(
                          color: Colors.lightBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processVttFile,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(_isProcessing ? 'Processing...' : 'Process VTT (Repeats + Proper Nouns)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 16),
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ],
              if (_outputPath != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final htmlPath = path.join(
                            path.dirname(_outputPath!),
                            '${path.basenameWithoutExtension(_selectedVttPath!)}_repeats_changes.html'
                          );
                          await _openFileInBrowser(htmlPath);
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: Text('Repeats ${_countHtmlChanges(path.join(path.dirname(_outputPath!), '${path.basenameWithoutExtension(_selectedVttPath!)}_repeats_changes.html'))} (${_getIterationCount()} passes)'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: Colors.deepOrange[900],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final htmlPath = path.join(
                            path.dirname(_outputPath!),
                            '${path.basenameWithoutExtension(_selectedVttPath!)}_honorifics_changes.html'
                          );
                          await _openFileInBrowser(htmlPath);
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: Text('Cross-Subtitle ${_countHtmlChanges(path.join(path.dirname(_outputPath!), '${path.basenameWithoutExtension(_selectedVttPath!)}_honorifics_changes.html'))}'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: Colors.purple[900],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final htmlPath = path.join(
                            path.dirname(_outputPath!),
                            '${path.basenameWithoutExtension(_selectedVttPath!)}_singleline_honorifics.html'
                          );
                          await _openFileInBrowser(htmlPath);
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: Text('Single-Line ${_countHtmlChanges(path.join(path.dirname(_outputPath!), '${path.basenameWithoutExtension(_selectedVttPath!)}_singleline_honorifics.html'))}'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: Colors.purple[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final htmlPath = path.join(
                            path.dirname(_outputPath!),
                            '${path.basenameWithoutExtension(_selectedVttPath!)}_propernoun_changes.html'
                          );
                          await _openFileInBrowser(htmlPath);
                        },
                        icon: const Icon(Icons.open_in_browser),
                        label: Text('Proper Nouns ${_countHtmlChanges(path.join(path.dirname(_outputPath!), '${path.basenameWithoutExtension(_selectedVttPath!)}_propernoun_changes.html'))}'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          backgroundColor: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final dir = path.dirname(_outputPath!);
                    try {
                      if (Platform.isMacOS) {
                        await Process.run('open', [dir]);
                      } else if (Platform.isLinux) {
                        await Process.run('xdg-open', [dir]);
                      } else if (Platform.isWindows) {
                        await Process.run('explorer', [dir]);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error opening directory: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Output Directory'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.deepPurple.withAlpha(128)),
                  ),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  
  Future<void> _openFileInBrowser(String filePath) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', filePath]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }    
}