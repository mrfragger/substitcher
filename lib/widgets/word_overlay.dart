import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/cjk_tokenizer.dart';
import '../services/dictionary_service.dart';

class WordOverlay extends StatefulWidget {
  final String subtitle;
  final VoidCallback onClose;
  final List<String>? colorPalette; 
  final int startWordIndex; 

  const WordOverlay({
    super.key,
    required this.subtitle,
    required this.onClose,
    this.colorPalette, 
    this.startWordIndex = 0, 
  });

  @override
  State<WordOverlay> createState() => _WordOverlayState();
}

class _WordOverlayState extends State<WordOverlay> {
  List<String> _words = [];
  String? _copiedWord;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tokenizeSubtitle();
  }

  Future<void> _tokenizeSubtitle() async {
    final cleanedText = widget.subtitle.replaceAll(RegExp(r'<[^>]+>'), '');
    final words = CJKTokenizer.tokenize(cleanedText);
    setState(() {
      _words = words;
      _isLoading = false;
    });
    print('Tokenized ${_words.length} words: $_words');
  }
  
  bool _isPunctuation(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return true;
    
    final punctuationPattern = RegExp(r'^[\s\|\\,،・]+$');
    return punctuationPattern.hasMatch(trimmed);
  }

  Future<void> _handleWordClick(String word) async {
    
    final language = CJKTokenizer.detectLanguage(word);
    await DictionaryService.lookupWord(word, language);
    
    setState(() {
      _copiedWord = word;
    });
    
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _copiedWord = null;
      });
    }
  }

  Color _parseColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      final hexColor = colorStr.substring(1);
      return Color(int.parse('FF$hexColor', radix: 16));
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final overlayWidth = screenWidth * 0.45;

    return Stack(
      children: [
        Positioned(
          left: 20,
          top: 45,
          width: overlayWidth,
          child: Material(
            color: Colors.transparent,
            child: IntrinsicHeight(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepPurple, width: 2),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Platform.isMacOS
                                ? 'Click word to copy & open Dictionary.app • ESC to close'
                                : 'Click word to copy to clipboard • ESC to close',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (!_isLoading)
                          Text(
                            'Found ${_words.length} words',
                            style: const TextStyle(
                              color: Colors.cyan,
                              fontSize: 11,
                            ),
                          ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          iconSize: 20,
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(
                            color: Colors.cyan,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _words.asMap().entries.where((entry) {
                              final language = CJKTokenizer.detectLanguage(widget.subtitle);
                              return !_isPunctuation(entry.value) && !CJKTokenizer.shouldExcludeFromColoring(entry.value, language: language);
                            }).map((entry) {
                              final displayIndex = entry.key;
                              final word = entry.value;
                              
                              Color color;
                              if (widget.colorPalette != null && widget.colorPalette!.isNotEmpty) {
                                final language = CJKTokenizer.detectLanguage(widget.subtitle);
                                final visibleWords = _words.where((w) => !_isPunctuation(w) && !CJKTokenizer.shouldExcludeFromColoring(w, language: language)).toList();
                                final actualIndex = visibleWords.indexOf(word);
                                final colorIndex = actualIndex % widget.colorPalette!.length;
                                color = _parseColor(widget.colorPalette![colorIndex]);
                              } else {
                                final language = CJKTokenizer.detectLanguage(widget.subtitle);
                                final visibleWords = _words.where((w) => !_isPunctuation(w) && !CJKTokenizer.shouldExcludeFromColoring(w, language: language)).toList();
                                final actualIndex = visibleWords.indexOf(word);
                                final colors = [
                                  Colors.cyan,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.orange,
                                  Colors.pink,
                                  Colors.purple,
                                  Colors.blue,
                                  Colors.red,
                                ];
                                color = colors[actualIndex % colors.length];
                              }
                              
                              return MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => _handleWordClick(word),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      word,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (_copiedWord != null)
          Positioned(
            bottom: 100,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      Platform.isMacOS
                          ? 'Copied "$_copiedWord" & opened Dictionary'
                          : 'Copied "$_copiedWord" to clipboard',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}