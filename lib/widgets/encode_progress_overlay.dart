import 'package:flutter/material.dart';
import '../services/video_edit_service.dart';

class EncodeProgressOverlay extends StatelessWidget {
  final bool isEncoding;
  final double progress;
  final String step;
  final DateTime? startTime;
  final DateTime? finishTime;
  final VoidCallback onDismiss;
  final VoidCallback? onCancel;
  final EncodeSettings? encodeSettings;
  final int? inputBytes;
  final int? outputBytes;
  final int? sourceBytes;
  final double? sourceSeconds;
  final double? outputSeconds;


  const EncodeProgressOverlay({
    super.key,
    required this.isEncoding,
    required this.progress,
    required this.step,
    required this.startTime,
    required this.finishTime,
    required this.onDismiss,
    this.onCancel,
    this.encodeSettings,
    this.inputBytes,
    this.outputBytes,
    this.sourceBytes,
    this.sourceSeconds,
    this.outputSeconds,
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

  String _formatSize(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }

  List<Widget> _buildOriginalRows() {
    final srcB = sourceBytes;
    final srcS = sourceSeconds;
    final outB = outputBytes;
    final outS = outputSeconds;
    if (srcB == null || srcS == null || outB == null || outS == null) {
      return const [];
    }
    if (srcB <= 0 || srcS <= 0 || outS <= 0) return const [];

    // The original file's size for just this much footage
    final originalShare = srcB * (outS / srcS);
    final pct = (1 - outB / originalShare) * 100;
    final smaller = pct >= 0;

    return [
      const SizedBox(height: 4),
      Text(
        'Original, same ${_formatElapsed(Duration(seconds: outS.round()))}'
        ' ≈ ${_formatSize(originalShare.round())}',
        style: const TextStyle(color: Colors.white54, fontSize: 11),
      ),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${_formatSize(outB)} is ',
              style: const TextStyle(color: Colors.white54),
            ),
            TextSpan(
              text: smaller
                  ? '${pct.toStringAsFixed(0)}% smaller'
                  : '${(-pct).toStringAsFixed(0)}% larger',
              style: TextStyle(
                color: smaller ? Colors.greenAccent : Colors.orangeAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        style: const TextStyle(fontSize: 11),
      ),
    ];
  }

  Widget? _buildSizeRow() {
    final inB = inputBytes;
    final outB = outputBytes;
    if (outB == null) return null;

    final sizeText = (inB != null && inB > 0)
        ? '${_formatSize(inB)} → ${_formatSize(outB)}'
        : _formatSize(outB);

    String? change;
    Color changeColor = Colors.greenAccent;
    if (inB != null && inB > 0) {
      final pct = (1 - outB / inB) * 100;
      if (pct >= 0) {
        change = '${pct.toStringAsFixed(0)}% smaller';
      } else {
        change = '${(-pct).toStringAsFixed(0)}% larger';
        changeColor = Colors.orangeAccent;
      }
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: sizeText,
            style: const TextStyle(color: Colors.white70),
          ),
          if (change != null) ...[
            const TextSpan(
              text: '  ·  ',
              style: TextStyle(color: Colors.white38),
            ),
            TextSpan(
              text: change,
              style: TextStyle(
                color: changeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
      style: const TextStyle(fontSize: 12),
    );
  }

  String _buildSettingsSummary(EncodeSettings s) {
      final codec = switch (s.codec) {
        VideoCodec.x265 => 'x265',
        VideoCodec.x264 => 'x264',
        VideoCodec.videotoolbox => 'VideoToolbox',
        VideoCodec.nvenc => 'NVENC',
        VideoCodec.amf => 'AMF',
        VideoCodec.qsv => 'QuickSync',
      };

      final audioCodec = switch (s.audioCodec) {
        AudioCodec.opus => 'opus',
        AudioCodec.aac => 'aac',
        AudioCodec.mp3 => 'mp3',
        AudioCodec.copy => 'copy',
      };

      final fps = s.fps != null ? ' fps${s.fps}' : '';
      final line1 = '${s.resolution}p $codec crf${s.crf}$fps';
      final line2 = '$audioCodec ${s.audioBitrate}';

      final extras = <String>[];
      if (s.vfFilter != null) {
        if (s.vfFilter!.contains('crop=in_h*16/9')) extras.add('16:9');
        else if (s.vfFilter!.contains('crop=in_h*4/5')) extras.add('4:5');
        else if (s.vfFilter!.contains('crop=in_w:in_w')) extras.add('9:16');
        else if (s.vfFilter!.contains('crop=in_h*4/3')) extras.add('4:3');
        else if (s.vfFilter!.contains('crop=in_h:in_h')) extras.add('1:1');
        if (s.vfFilter!.contains('format=gray')) extras.add('B&W');
        if (s.vfFilter!.contains('hflip')) extras.add('flip H');
        if (s.vfFilter!.contains('vflip')) extras.add('flip V');
      }

      if (extras.isEmpty) return '$line1\n$line2';
      return '$line1\n$line2\n${extras.join('  ')}';
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
                    isDone ? 'Encode Complete (⇧L open dir)' : 'Encoding...',
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
                    message: 'Cancel Encoding',
                    child: GestureDetector(
                      onTap: onCancel,
                      child: const Icon(Icons.cancel, color: Colors.white54, size: 16),
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
                '${progress.toStringAsFixed(1)}%  ·  elapsed ${_formatElapsed(elapsed)}',
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
                'Finished at ${_formatTime(finishTime!)}  ·  took ${_formatElapsed(elapsed)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (_buildSizeRow() case final row?) ...[
                const SizedBox(height: 4),
                row,
              ],
              ..._buildOriginalRows(),
              if (encodeSettings != null) ...[
                const SizedBox(height: 6),
                Text(
                  _buildSettingsSummary(encodeSettings!),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
