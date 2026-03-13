import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../services/translation_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TranslationService _service = TranslationService();
  final ScrollController _scrollController = ScrollController();

  String? _vttPath;
  List<Map<String, String>> _cues = [];
  int _totalCues = 0;

  bool _isTranslating = false;
  bool _serverStarting = false;
  bool _serverRunning = false;
  String _statusMessage = '';
  int _currentCueIndex = -1;
  DateTime? _startTime;
  DateTime? _lastUserScrollTime;

  final Map<int, Map<String, String>> _translationResults = {};

  int _cacheHits = 0;
  int _apiCalls = 0;

  bool _cancelled = false;

  Process? _downloadProcess;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _lastUserScrollTime = DateTime.now();
      }
    });
    _service.initialize().then((_) {
      if (mounted) {
        setState(() {
          if (_service.isTranslating) {
            _isTranslating = true;
            _vttPath = _service.vttPath;
            _cues = _service.cues;
            _startProgressTimer();
          }
        });
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _startServer() async {
    if (_service.modelPath == null) {
      _showSnack('Please select a TranslateGemma GGUF model first', isError: true);
      return;
    }
    setState(() {
      _serverStarting = true;
      _statusMessage = 'Loading model... 0s';
    });

    final loadTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Loading model... ${t.tick}s';
        });
      }
    });

    _service.startServer().then((_) {
      loadTimer.cancel();
      if (mounted) {
        setState(() {
          _serverRunning = true;
          _serverStarting = false;
          _statusMessage = 'Server ready';
        });
      }
    }).catchError((e) {
      loadTimer.cancel();
      if (mounted) {
        setState(() {
          _serverStarting = false;
          _statusMessage = 'Server failed: $e';
        });
        _showSnack('Failed to start server: $e', isError: true);
      }
    });
  }

  Future<void> _stopServer() async {
    await _service.stopServer();
    setState(() {
      _serverRunning = false;
      _statusMessage = 'Server stopped';
    });
  }

  Future<void> _useLastVttFile() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVtt = prefs.getString('lastVttFilePath');
    if (lastVtt != null && File(lastVtt).existsSync()) {
      final content = await File(lastVtt).readAsString();
      final cues = _service.parseVtt(content);
      setState(() {
        _vttPath = lastVtt;
        _cues = cues;
        _totalCues = cues.length;
        _translationResults.clear();
        _currentCueIndex = -1;
        _statusMessage = 'Loaded ${cues.length} subtitle cues';
        _cacheHits = 0;
        _apiCalls = 0;
      });
      _showSnack('Restored: ${path.basename(lastVtt)}');
    } else {
      _showSnack('No previous VTT file found', isError: true);
    }
  }

  Future<void> _pickVttFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select VTT file to translate',
      type: FileType.custom,
      allowedExtensions: ['vtt'],
    );
    if (result == null || result.files.isEmpty) return;
    final p = result.files.first.path!;
    final content = await File(p).readAsString();
    final cues = _service.parseVtt(content);
  
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastVttFilePath', p);
  
    setState(() {
      _vttPath = p;
      _cues = cues;
      _totalCues = cues.length;
      _translationResults.clear();
      _currentCueIndex = -1;
      _statusMessage = 'Loaded ${cues.length} subtitle cues';
      _cacheHits = 0;
      _apiCalls = 0;
    });
  }

  Future<void> _pickModel() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select TranslateGemma GGUF model',
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    if (result == null || result.files.isEmpty) return;
    await _service.setModelPath(result.files.first.path!);
    setState(() {});
    _showSnack('Model set: ${path.basename(result.files.first.path!)}');
  }

  Future<void> _pickLlamaExecutable() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select llama-server executable',
    );
    if (result == null || result.files.isEmpty) return;
    await _service.setLlamaExecutable(result.files.first.path!);
    setState(() {});
    _showSnack('llama-server set');
  }

  Future<void> _startModelDownload() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to save model',
    );
    if (dir == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Starting download...';
    });

    _showDownloadDialog();

    try {
      _downloadProcess = await _service.startModelDownload(dir);

      _downloadProcess!.stdout.transform(utf8.decoder).listen((data) {
        if (mounted) setState(() => _downloadStatus = data.trim());
      });

      _downloadProcess!.stderr.transform(utf8.decoder).listen((data) {
        final pctMatch = RegExp(r'(\d+)%').firstMatch(data);
        if (pctMatch != null) {
          final pct = int.tryParse(pctMatch.group(1)!) ?? 0;
          if (mounted) {
            setState(() {
              _downloadProgress = pct / 100.0;
              _downloadStatus = data.trim();
            });
          }
        } else if (data.trim().isNotEmpty) {
          if (mounted) setState(() => _downloadStatus = data.trim());
        }
      });

      final exitCode = await _downloadProcess!.exitCode;

      if (mounted) {
        if (exitCode == 0) {
          final modelFile = '$dir/translategemma-4b-it.Q4_K_M.gguf';
          await _service.setModelPath(modelFile);
          setState(() {
            _isDownloading = false;
            _downloadProgress = 1.0;
            _downloadStatus = 'Download complete!';
          });
          Navigator.of(context).pop();
          _showSnack('Model downloaded and selected!');
        } else {
          setState(() {
            _isDownloading = false;
            _downloadStatus = 'Download failed (exit $exitCode)';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadStatus = 'Error: $e';
        });
      }
    }
  }

  void _cancelDownload() {
    _downloadProcess?.kill();
    setState(() {
      _isDownloading = false;
      _downloadStatus = 'Cancelled';
    });
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) setDialogState(() {});
          });
          return AlertDialog(
            backgroundColor: const Color(0xFF2A2A2A),
            title: const Row(children: [
              Icon(Icons.download, color: Colors.teal),
              SizedBox(width: 8),
              Text('Downloading Model',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ]),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'translategemma-4b-it.Q4_K_M.gguf',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'From: mradermacher/translategemma-4b-it-GGUF',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    backgroundColor: Colors.white12,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.teal),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    if (_downloadProgress > 0)
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: Colors.tealAccent, fontSize: 12),
                      ),
                    const Spacer(),
                    Text(
                      _isDownloading ? 'Downloading...' : _downloadStatus,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _downloadStatus.isNotEmpty ? _downloadStatus : 'Waiting...',
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontFamily: 'monospace'),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_isDownloading)
                TextButton.icon(
                  onPressed: () {
                    _cancelDownload();
                    Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.stop, color: Colors.red, size: 16),
                  label: const Text('Cancel',
                      style: TextStyle(color: Colors.red)),
                )
              else
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white70)),
                ),
            ],
          );
        },
      ),
    );
  }
  
  Future<void> _startTranslation() async {
    if (_vttPath == null || _cues.isEmpty) {
      _showSnack('Please select a VTT file first', isError: true);
      return;
    }
    if (_service.selectedLanguages.isEmpty) {
      _showSnack('Please select at least one target language', isError: true);
      return;
    }
    if (!_serverRunning) {
      _showSnack('Please start the translation server first', isError: true);
      return;
    }
  
    // Hand data to the service
    _service.vttPath = _vttPath;
    _service.cues = _cues;
  
    // Fire and forget — service owns the work
    _service.runTranslation().then((_) {
      if (mounted && !_service.cancelled) {
        _showSnack('Translation complete! Files saved to translated_vtt/');
      }
    });
  
    _startProgressTimer();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_service.isTranslating) {
        timer.cancel();
      }
      if (mounted) {
        setState(() {
          _isTranslating = _service.isTranslating;
          _statusMessage = _service.statusMessage;
          _currentCueIndex = _service.currentCueIndex;
          _totalCues = _service.totalCues;
          _cacheHits = _service.cacheHits;
          _apiCalls = _service.apiCalls;
          _startTime = _service.startTime;
          // Copy results reference for the feed
          _translationResults
            ..clear()
            ..addAll(_service.translationResults);
        });
  
        // Auto-scroll logic
        if (_isTranslating && _scrollController.hasClients) {
          if (_lastUserScrollTime == null ||
              DateTime.now().difference(_lastUserScrollTime!).inSeconds >= 20) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      }
    });
  }
  
  void _cancel() {
    _service.cancelTranslation();
  }
  

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
  }

  String _elapsedString() {
    if (_startTime == null) return '';
    return _formatDuration(DateTime.now().difference(_startTime!));
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('VTT Translation'),
        backgroundColor: Colors.grey[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Translate Subtitles vtt',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),

            if (_cues.isNotEmpty || _statusMessage.isNotEmpty) ...[
              _buildProgressSection(),
              const SizedBox(height: 16),
            ],

            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    _buildServerSection(),
                    const SizedBox(height: 20),
                    _buildVttSection(),
                    const SizedBox(height: 20),
                    _buildLanguageSection(),
                    const SizedBox(height: 20),
                    if (_translationResults.isNotEmpty) _buildTranslationFeed(),
                  ],
                ),
              ),
            ),

            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.memory, color: Colors.teal, size: 20),
            SizedBox(width: 8),
            Text('Translation Engine',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),

          if (_service.modelPath != null)
            _infoRow(Icons.check_circle, Colors.green,
                path.basename(_service.modelPath!))
          else
            _warningRow('No GGUF model selected'),
          const SizedBox(height: 8),

          if (_service.llamaExecutablePath != null)
            _infoRow(Icons.check_circle, Colors.green,
                'Binary: ${path.basename(_service.llamaExecutablePath!)}')
          else
            _infoRow(Icons.info_outline, Colors.blue,
                'Using bundled llama-server'),
          const SizedBox(height: 12),

          Row(children: [
            ElevatedButton.icon(
              onPressed: _pickModel,
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('Select .gguf Model'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isDownloading ? null : _startModelDownload,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download Model 2.5GB'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[800],
                  foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _pickLlamaExecutable,
              icon: const Icon(Icons.terminal, size: 16),
              label: const Text('Select llama-server'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await _service.testServer();
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('llama-server Diagnostic'),
                      content: SingleChildScrollView(
                          child: SelectableText(result,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 11))),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'))
                      ],
                    ),
                  );
                }
              },
              icon: const Icon(Icons.bug_report, size: 16),
              label: const Text('Test'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white),
            ),
          ]),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _serverRunning
                    ? Colors.greenAccent
                    : _serverStarting
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _serverRunning
                  ? 'Server running on :18033'
                  : _serverStarting
                      ? 'Loading model...'
                      : 'Server stopped',
              style: TextStyle(
                color: _serverRunning ? Colors.greenAccent : Colors.white60,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            if (!_serverRunning && !_serverStarting)
              ElevatedButton.icon(
                onPressed: _service.modelPath != null ? _startServer : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Server'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white),
              )
            else if (_serverRunning)
              ElevatedButton.icon(
                onPressed: _isTranslating ? null : _stopServer,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Stop Server'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildVttSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.subtitles, color: Colors.purple, size: 20),
            SizedBox(width: 8),
            Text('Source VTT File',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          if (_vttPath != null) ...[
            _infoRow(Icons.check_circle, Colors.green,
                path.basename(_vttPath!)),
            const SizedBox(height: 4),
            Text('$_totalCues subtitle cues loaded',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ] else
            _warningRow('No VTT file selected'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _isTranslating ? null : _pickVttFile,
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Select VTT File'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _isTranslating ? null : _useLastVttFile,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Last Used VTT File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.translate, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text('Languages',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),

          Row(children: [
            const Text('Source: ',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _service.sourceLanguage,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              items: [
                'English',
                'Arabic',
                'Dutch',
                'French',
                'German',
                'Italian',
                'Portuguese',
                'Spanish',
                'Swedish',
                'Russian',
                'Chinese',
                'Japanese',
                'Korean',
                'Thai',
                'Vietnamese',
                'Indonesian',
                'Bengali',
              ]
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: _isTranslating
                  ? null
                  : (v) {
                      setState(() => _service.sourceLanguage = v!);
                      _service.saveSettings();
                    },
            ),
          ]),
          const SizedBox(height: 12),

          const Text('Target languages:',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('All', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                side: const BorderSide(color: Colors.orange),
                onPressed: _isTranslating
                    ? null
                    : () {
                        setState(() {
                          _service.selectedLanguages =
                              List.from(TranslationService.availableLanguages);
                        });
                        _service.saveSettings();
                      },
              ),
              ActionChip(
                label: const Text('None', style: TextStyle(fontSize: 12)),
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                side: const BorderSide(color: Colors.red),
                onPressed: _isTranslating
                    ? null
                    : () {
                        setState(() => _service.selectedLanguages = []);
                        _service.saveSettings();
                      },
              ),
              ...TranslationService.availableLanguages.map((lang) {
                final selected = _service.selectedLanguages.contains(lang);
                return FilterChip(
                  label: Text(lang,
                      style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.black : Colors.white70)),
                  selected: selected,
                  selectedColor: Colors.orangeAccent,
                  backgroundColor: const Color(0xFF3A3A3A),
                  checkmarkColor: Colors.black,
                  onSelected: _isTranslating
                      ? null
                      : (val) {
                          setState(() {
                            if (val) {
                              _service.selectedLanguages.add(lang);
                            } else {
                              _service.selectedLanguages.remove(lang);
                            }
                          });
                          _service.saveSettings();
                        },
                );
              }),
            ],
          ),
          if (_service.selectedLanguages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${_service.selectedLanguages.length} language(s) selected',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final done = _translationResults.length;
    final progress = _totalCues > 0 ? done / _totalCues : 0.0;
    final pct = (progress * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: _isTranslating ? Colors.orange : Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (_isTranslating)
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange)))
                  else
                    const Icon(Icons.info_outline, color: Colors.white54, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage.isNotEmpty ? _statusMessage : 'Ready',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 6,
                ),
                const SizedBox(height: 6),
                Text('$done / $_totalCues cues  ($pct%)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isTranslating)
                Text('Elapsed: ${_elapsedString()}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
              if (!_isTranslating && _cacheHits + _apiCalls > 0)
                Text('$_cacheHits cached  •  $_apiCalls API calls',
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationFeed() {
    final entries = _translationResults.entries.toList();
    final display = entries.length > 40
        ? entries.sublist(entries.length - 40)
        : entries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Translation Feed',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ...display.map((entry) {
          final cueIdx = entry.key;
          final translations = entry.value;
          final originalText = _cues[cueIdx]['text'] ?? '';
          final timestamp = _cues[cueIdx]['timestamp'] ?? '';
          final isCurrentlyCue = cueIdx == _currentCueIndex && _isTranslating;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCurrentlyCue
                  ? const Color(0xFF2A2A1A)
                  : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrentlyCue
                    ? Colors.orange.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    timestamp,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 8),
                  Text('#${cueIdx + 1}',
                      style: const TextStyle(
                          color: Colors.white24, fontSize: 10)),
                  const Spacer(),
                  if (isCurrentlyCue)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: const Text('translating',
                          style: TextStyle(
                              color: Colors.orange, fontSize: 10)),
                    ),
                ]),
                const SizedBox(height: 8),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(right: 8, top: 1),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _service.sourceLanguage.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(originalText,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

                if (translations.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ...(() {
                    final sorted = translations.entries.toList()
                      ..sort((a, b) =>
                          TranslationService.availableLanguages.indexOf(a.key)
                              .compareTo(TranslationService.availableLanguages
                                  .indexOf(b.key)));
                    return sorted.map((t) {
                      final color = _languageColor(t.key);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 88,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 8, top: 1),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t.key,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(t.value,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 13)),
                            ),
                          ],
                        ),
                      );
                    });
                  })(),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildControls() {
    final canTranslate = _vttPath != null &&
        _cues.isNotEmpty &&
        _service.selectedLanguages.isNotEmpty &&
        _serverRunning &&
        !_isTranslating;

    return Row(children: [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: canTranslate ? _startTranslation : null,
          icon: const Icon(Icons.play_arrow, size: 22),
          label: const Text('Start Translation', style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            disabledBackgroundColor: Colors.grey[800],
          ),
        ),
      ),
      if (_isTranslating) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () async {
                if (_service.paused) {
                  if (_service.unloaded) {
                    setState(() {});
                    await _service.resumeAndReload();
                  } else {
                    _service.resumeTranslation();
                  }
                } else {
                  _service.pauseTranslation();
                }
                setState(() {});
              },
              icon: Icon(_service.paused ? Icons.play_arrow : Icons.pause, size: 22),
              label: Text(
                _service.paused ? 'Resume' : 'Pause',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _service.paused ? Colors.green[700] : Colors.amber[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
              ),
            ),
            if (_service.paused && !_service.unloaded && !_service.translatingCurrentCue) ...[  
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  await _service.pauseAndUnload();
                  setState(() {});
                },
                icon: const Icon(Icons.memory, size: 22),
                label: const Text('Unload Model', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
                ),
              ),
            ],
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                _service.cancelTranslation();
                setState(() {});
              },
              icon: const Icon(Icons.stop, size: 22),
              label: const Text('Cancel', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
              ),
            ),
          ],
    ]);
  }

  Color _languageColor(String lang) {
    const colors = [
      Colors.greenAccent,
      Colors.pinkAccent,
      Colors.cyanAccent,
      Colors.yellowAccent,
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.redAccent,
      Colors.amberAccent,
      Colors.deepPurpleAccent,
      Colors.orangeAccent,
      Colors.indigoAccent,
      Colors.limeAccent,
      Colors.lightBlueAccent,
      Colors.deepOrangeAccent,
    ];
    final idx = TranslationService.availableLanguages.indexOf(lang);
    return colors[idx % colors.length];
  }

  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _warningRow(String text) {
    return Row(children: [
      const Icon(Icons.warning, color: Colors.orange, size: 16),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(color: Colors.orange, fontSize: 12)),
    ]);
  }
}