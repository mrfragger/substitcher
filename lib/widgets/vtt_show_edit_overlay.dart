import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subtitle_cue.dart';

class VttShowEditOverlay extends StatefulWidget {
  final List<SubtitleCue> subtitles;
  final int currentIndex;
  final FocusNode line1FocusNode;
  final FocusNode line2FocusNode;
  final VoidCallback onClose;
  final VoidCallback onSave;
  final Function(int) onNavigate;
  final Function(int) onDeleteCue;
  final Function(int) onAddCueAfter;
  final Function(int, String, String) onCueTextChanged;

  const VttShowEditOverlay({
    super.key,
    required this.subtitles,
    required this.currentIndex,
    required this.line1FocusNode,
    required this.line2FocusNode,
    required this.onClose,
    required this.onSave,
    required this.onNavigate,
    required this.onDeleteCue,
    required this.onAddCueAfter,
    required this.onCueTextChanged,
  });

  @override
  State<VttShowEditOverlay> createState() => VttShowEditOverlayState();
}

class VttShowEditOverlayState extends State<VttShowEditOverlay> {
  late TextEditingController _line1Controller;
  late TextEditingController _line2Controller;
  late int _currentIndex;
  bool _shortcutModeActive = false;
  bool _alignLeft = false;
  final Map<int, (String, String)> _localEdits = {};
  bool get _isInShortcutMode =>
      !widget.line1FocusNode.hasFocus && !widget.line2FocusNode.hasFocus;


  void flushEdits() {
    _commitCurrentCue();
    _localEdits.forEach((index, edit) {
      final (line1, line2) = edit;
      widget.onCueTextChanged(index, line1, line2);
    });
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _line1Controller = TextEditingController();
    _line2Controller = TextEditingController();
    _loadCue(_currentIndex);
    widget.line1FocusNode.addListener(_onFocusChange);
    widget.line2FocusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.line1FocusNode.requestFocus();
    });
  }

  void _onFocusChange() {
    if (widget.line1FocusNode.hasFocus || widget.line2FocusNode.hasFocus) {
      setState(() {
        _shortcutModeActive = false;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(VttShowEditOverlay old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != _currentIndex) {
      _currentIndex = widget.currentIndex;
      _loadCue(_currentIndex);
    }
    if (_currentIndex >= widget.subtitles.length) {
      _currentIndex = (widget.subtitles.length - 1).clamp(0, widget.subtitles.length - 1);
      _loadCue(_currentIndex);
    }
  }

  @override
  void dispose() {
    _line1Controller.dispose();
    _line2Controller.dispose();
    widget.line1FocusNode.removeListener(_onFocusChange);
    widget.line2FocusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _loadCue(int index) {
    if (index < 0 || index >= widget.subtitles.length) return;

    if (_localEdits.containsKey(index)) {
      final (line1, line2) = _localEdits[index]!;
      _line1Controller.text = line1;
      _line2Controller.text = line2;
      return;
    }

    final lines = widget.subtitles[index].text.split('\n');
    _line1Controller.text = lines.isNotEmpty ? lines[0] : '';
    _line2Controller.text = lines.length > 1 ? lines[1] : '';
  }

  void jumpToIndex(int index) {
    if (index < 0 || index >= widget.subtitles.length) return;
    setState(() {
      _currentIndex = index;
    });
    _loadCue(_currentIndex);
    widget.line1FocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _line1Controller.selection = TextSelection.collapsed(
          offset: _line1Controller.text.length);
    });
  }

  void _commitCurrentCue() {
    final line1 = _line1Controller.text.trim();
    final line2 = _line2Controller.text.trim();
    _localEdits[_currentIndex] = (line1, line2);
    widget.onCueTextChanged(_currentIndex, line1, line2);
  }

  void _navigateTo(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.subtitles.length) return;
    _commitCurrentCue();
    widget.onSave();
    setState(() {
      _currentIndex = newIndex;
    });
    _loadCue(_currentIndex);
    widget.onNavigate(newIndex);
    widget.line1FocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.line1FocusNode.requestFocus();
      _line1Controller.selection = TextSelection.collapsed(
          offset: _line1Controller.text.length);
    });
  }

  String _formatTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < widget.subtitles.length - 1;
    final currentCue = _currentIndex < widget.subtitles.length
        ? widget.subtitles[_currentIndex]
        : null;

    return Positioned(
      bottom: 0,
      left: _alignLeft ? 0 : null,
      right: _alignLeft ? null : 0,
      width: 640,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
          } else if (event.logicalKey == LogicalKeyboardKey.keyS &&
              HardwareKeyboard.instance.isShiftPressed) {
            widget.onSave();
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onSave();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Header ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF252525),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // ← nav
                    _navButton(
                      icon: Icons.arrow_back,
                      label: '',
                      enabled: hasPrev,
                      onTap: () => _navigateTo(_currentIndex - 1),
                    ),
                    const SizedBox(width: 6),
                    // toggle left/right
                    InkWell(
                      onTap: () {
                        setState(() {
                          _alignLeft = !_alignLeft;
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Icon(
                          _alignLeft ? Icons.align_horizontal_left : Icons.align_horizontal_right,
                          color: Colors.orange,
                          size: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () async {
                        final controller = TextEditingController(
                            text: '${_currentIndex + 1}')
                          ..selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: '${_currentIndex + 1}'.length);
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: const Text('Go to slide',
                                style: TextStyle(color: Colors.white)),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: '1 - ${widget.subtitles.length}',
                                hintStyle: const TextStyle(color: Colors.white38),
                                filled: true,
                                fillColor: Colors.black26,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onSubmitted: (value) {
                                Navigator.pop(ctx);
                                final index = (int.tryParse(value) ?? 1) - 1;
                                final clamped = index.clamp(0, widget.subtitles.length - 1);
                                _navigateTo(clamped);
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  final index = (int.tryParse(controller.text) ?? 1) - 1;
                                  final clamped = index.clamp(0, widget.subtitles.length - 1);
                                  _navigateTo(clamped);
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple),
                                child: const Text('Go'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Text(
                        'Edit  ${_currentIndex + 1} / ${widget.subtitles.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // TAB hint
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 10),
                        children: [
                          TextSpan(
                            text: 'TAB → line2 → unfocus → shortcuts → line1',
                            style: TextStyle(
                              color: _isInShortcutMode ? Colors.yellow : Colors.white24,
                              fontWeight: _isInShortcutMode
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // ⇧S save
                    Tooltip(
                      message: 'font properties before exiting',
                      child: InkWell(
                        onTap: widget.onSave,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Text(
                            '⇧S save',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // + Add
                    Tooltip(
                      message: 'Ctrl+A',
                      child: InkWell(
                        onTap: () {
                          final line1 = _line1Controller.text.trim();
                          if (line1.isEmpty) return;
                          if (_currentIndex + 1 < widget.subtitles.length &&
                              widget.subtitles[_currentIndex + 1].startTime ==
                              widget.subtitles[_currentIndex].endTime) return;
                          _commitCurrentCue();
                          widget.onAddCueAfter(_currentIndex);
                          _navigateTo(_currentIndex + 1);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: Colors.deepPurple.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 12, color: Colors.deepPurple),
                              SizedBox(width: 3),
                              Text('Add',
                                  style: TextStyle(
                                      color: Colors.deepPurple, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // 🗑 Delete
                    Tooltip(
                      message: 'Ctrl+D',
                      child: InkWell(
                        onTap: () {
                          widget.onDeleteCue(_currentIndex);
                          final newIndex = (_currentIndex - 1)
                              .clamp(0, widget.subtitles.length - 2);
                          _navigateTo(newIndex);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          child: Icon(Icons.delete_outline,
                              size: 16,
                              color: Colors.red.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // X close
                    InkWell(
                      onTap: widget.onClose,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Icon(Icons.close,
                            size: 14, color: Colors.white38),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // → nav
                    _navButton(
                      icon: Icons.arrow_forward,
                      label: '',
                      enabled: hasNext,
                      onTap: () => _navigateTo(_currentIndex + 1),
                    ),
                  ],
                ),
              ),

              // ── Timecode ──
              if (currentCue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  child: Text(
                    '${_formatTime(currentCue.startTime)} → ${_formatTime(currentCue.endTime)}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ),

              // ── Line 1 field ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.tab) {
                      widget.line2FocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      widget.onSave();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _line1Controller,
                    focusNode: widget.line1FocusNode,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    decoration: _fieldDecoration('Line 1'),
                  ),
                ),
              ),

              // ── Line 2 field ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.tab) {
                      widget.line2FocusNode.unfocus();
                      widget.line1FocusNode.unfocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter) {
                      widget.onSave();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _line2Controller,
                    focusNode: widget.line2FocusNode,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 1,
                    decoration: _fieldDecoration('Line 2 (optional)'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.black26,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      isDense: true,
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: enabled ? Colors.white54 : Colors.white12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white54 : Colors.white12,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
