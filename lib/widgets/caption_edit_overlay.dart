import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CaptionEditOverlay extends StatefulWidget {
  final String initialText;
  final FocusNode line1FocusNode;
  final FocusNode line2FocusNode;
  final Future<void> Function(String line1, String line2) onSubmit;
  final VoidCallback onClose;

  const CaptionEditOverlay({
    super.key,
    required this.initialText,
    required this.line1FocusNode,
    required this.line2FocusNode,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  State<CaptionEditOverlay> createState() => _CaptionEditOverlayState();
}

class _CaptionEditOverlayState extends State<CaptionEditOverlay> {
  late final TextEditingController _l1;
  late final TextEditingController _l2;

  @override
  void initState() {
    super.initState();
    final lines = widget.initialText.split('\n');
    _l1 = TextEditingController(text: lines.isNotEmpty ? lines[0] : '');
    _l2 = TextEditingController(text: lines.length > 1 ? lines[1] : '');
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.line1FocusNode.requestFocus());
  }

  @override
  void dispose() {
    _l1.dispose();
    _l2.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmit(_l1.text.trim(), _l2.text.trim());

  KeyEventResult _onKey(FocusNode n, KeyEvent e, FocusNode? tabTo) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      _submit();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.tab && tabTo != null) {
      tabTo.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: Colors.black26,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 640,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.deepPurple, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(
                onKeyEvent: (n, e) => _onKey(n, e, widget.line2FocusNode),
                child: TextField(
                  controller: _l1,
                  focusNode: widget.line1FocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _dec('Line 1'),
                ),
              ),
              const SizedBox(height: 8),
              Focus(
                onKeyEvent: (n, e) => _onKey(n, e, widget.line1FocusNode),
                child: TextField(
                  controller: _l2,
                  focusNode: widget.line2FocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _dec('Line 2 (optional)'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter = apply · Tab = switch line · Esc = hide · Ctrl+⌘+arrows = move caption',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
