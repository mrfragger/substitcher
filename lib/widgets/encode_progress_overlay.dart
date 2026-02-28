import 'package:flutter/material.dart';

class EncodeProgressOverlay extends StatelessWidget {
  final bool isEncoding;
  final double progress;
  final String step;
  final DateTime? startTime;
  final DateTime? finishTime;
  final VoidCallback onDismiss;
  final VoidCallback? onCancel;


  const EncodeProgressOverlay({
    super.key,
    required this.isEncoding,
    required this.progress,
    required this.step,
    required this.startTime,
    required this.finishTime,
    required this.onDismiss,
    this.onCancel,
  });

  String _formatElapsed(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';
    } else if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

@override
  Widget build(BuildContext context) {
    final isDone = finishTime != null && !isEncoding;
    final elapsed = startTime != null
        ? (finishTime ?? DateTime.now()).difference(startTime!)
        : Duration.zero;

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDone ? Colors.green : Colors.deepPurple,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.movie_filter,
                  color: isDone ? Colors.green : Colors.deepPurple,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDone ? 'Encode Complete' : 'Encoding...',
                    style: TextStyle(
                      color: isDone ? Colors.green : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isDone)
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(Icons.close, color: Colors.white54, size: 16),
                  ),
                if (!isDone && onCancel != null)
                  Tooltip(
                    message: 'Cancel Encode',
                    child: GestureDetector(
                      onTap: onCancel,
                      child: const Icon(Icons.cancel, color: Colors.red, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isDone) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${progress.toStringAsFixed(1)}%  ·  ${_formatElapsed(elapsed)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                step,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              Text(
                'Finished at ${_formatTime(finishTime!)}  ·  ${_formatElapsed(elapsed)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}