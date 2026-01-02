import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class SubtitleManagerDialog extends StatefulWidget {
  final List<String> availableSubtitles;
  final String? primarySubtitle;
  final String? secondarySubtitle;
  final Function(String) onPrimarySelected;
  final Function(String) onSecondarySelected;
  final VoidCallback onSwap;
  final VoidCallback onClearPrimary;
  final VoidCallback onClearSecondary;

  const SubtitleManagerDialog({
    super.key,
    required this.availableSubtitles,
    required this.primarySubtitle,
    required this.secondarySubtitle,
    required this.onPrimarySelected,
    required this.onSecondarySelected,
    required this.onSwap,
    required this.onClearPrimary,
    required this.onClearSecondary,
  });

  @override
  State<SubtitleManagerDialog> createState() => _SubtitleManagerDialogState();
}

class _SubtitleManagerDialogState extends State<SubtitleManagerDialog> {
  String? _selectedPrimary;
  String? _selectedSecondary;

  @override
  void initState() {
    super.initState();
    _selectedPrimary = widget.primarySubtitle;
    _selectedSecondary = widget.secondarySubtitle;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Subtitle Manager',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Found ${widget.availableSubtitles.length} subtitle files',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PRIMARY (Bottom)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_selectedPrimary != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedPrimary = null;
                                });
                                widget.onClearPrimary();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedPrimary != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(51),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Text(
                            path.basename(_selectedPrimary!),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            'No primary subtitle selected',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: (_selectedPrimary != null || _selectedSecondary != null)
                          ? () {
                              final temp = _selectedPrimary;
                              setState(() {
                                _selectedPrimary = _selectedSecondary;
                                _selectedSecondary = temp;
                              });
                              widget.onSwap();
                            }
                          : null,
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Swap Primary '),
                              Icon(Icons.swap_vert, size: 14),
                            ],
                          ),
                          Text('Secondary (x)'),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SECONDARY (Top)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_selectedSecondary != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red, size: 20),
                              onPressed: () {
                                setState(() {
                                  _selectedSecondary = null;
                                });
                                widget.onClearSecondary();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedSecondary != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(51),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Text(
                            path.basename(_selectedSecondary!),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            'No secondary subtitle selected',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Available Subtitles',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.availableSubtitles.length,
                itemBuilder: (context, index) {
                  final subtitle = widget.availableSubtitles[index];
                  final filename = path.basename(subtitle);
                  final isPrimary = _selectedPrimary == subtitle;
                  final isSecondary = _selectedSecondary == subtitle;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? Colors.blue.withAlpha(51)
                          : isSecondary
                              ? Colors.orange.withAlpha(51)
                              : Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: isPrimary
                          ? Border.all(color: Colors.blue, width: 2)
                          : isSecondary
                              ? Border.all(color: Colors.orange, width: 2)
                              : null,
                    ),
                    child: ListTile(
                      title: Text(
                        filename,
                        style: TextStyle(
                          color: isPrimary || isSecondary ? Colors.white : Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          if (isSecondary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SECONDARY',
                                style: TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, color: Colors.blue, size: 20),
                            tooltip: 'Set as Primary (Bottom)',
                            onPressed: () {
                              setState(() {
                                _selectedPrimary = subtitle;
                              });
                              widget.onPrimarySelected(subtitle);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, color: Colors.orange, size: 20),
                            tooltip: 'Set as Secondary (Top)',
                            onPressed: () {
                              setState(() {
                                _selectedSecondary = subtitle;
                              });
                              widget.onSecondarySelected(subtitle);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}