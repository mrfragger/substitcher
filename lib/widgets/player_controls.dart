import 'package:flutter/material.dart';
import '../models/audiobook_metadata.dart';
import '../models/pause_mode.dart';
import '../models/color_palette.dart';
import 'package:path/path.dart' as path;

class PlayerControls extends StatelessWidget {
  final AudiobookMetadata audiobook;
  final int currentChapterIndex;
  final Duration currentPosition;
  final Duration totalDuration;
  final bool isPlaying;
  final double playbackSpeed;
  final int fileSize;
  final int averageBitrate;
  final bool shuffleEnabled;
  final String conversionType;
  final List<Chapter> playedChapters;
  final String selectedFont;
  final ColorPalette? currentColorPalette;
  final String currentSubtitleText;
  final double subtitleFontSize;
  final String secondarySubtitleText;
  final double secondarySubtitleFontSize;
  final String secondarySubtitleFont;
  final ColorPalette? secondaryColorPalette;
  final Duration? sleepDuration;
  final double? sliderHoverPosition;
  final String? hoveredChapterTitle;
  final String defaultFont;
  final String defaultConversionType;
  final String? defaultColorPalette;
  
  final VoidCallback onTogglePlayPause;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final Function(int) onJumpToChapter;
  final VoidCallback onSkipBackward;
  final VoidCallback onSkipForward;
  final VoidCallback onIncreaseSpeed;
  final VoidCallback onDecreaseSpeed;
  final VoidCallback onToggleShuffle;
  final VoidCallback onAddBookmark;
  final VoidCallback onTogglePanel;
  final Function(Duration?) onSetSleepTimer;
  final Function(Duration) onSeekTo;
  final Function(double) onSliderHover;
  final VoidCallback onSliderExit;
  final Function(BuildContext, String) onSettingsMenuSelected;
  final PauseMode pauseMode;
  final Function(PauseMode) onPauseModeChanged;
  final VoidCallback onOpenSubtitleManager;
  final TextSpan Function(String text, {double? fontSize, String? fontFamily, ColorPalette? palette}) buildColoredTextSpan;
  
  const PlayerControls({
    super.key,
    required this.audiobook,
    required this.currentChapterIndex,
    required this.currentPosition,
    required this.totalDuration,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.fileSize,
    required this.averageBitrate,
    required this.shuffleEnabled,
    required this.conversionType,
    required this.playedChapters,
    required this.selectedFont,
    required this.currentColorPalette,
    required this.currentSubtitleText,
    required this.subtitleFontSize,
    required this.secondarySubtitleText,
    required this.secondarySubtitleFontSize,
    required this.secondarySubtitleFont,
    required this.secondaryColorPalette,
    required this.sleepDuration,
    required this.sliderHoverPosition,
    required this.hoveredChapterTitle,
    required this.onTogglePlayPause,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onJumpToChapter,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.onIncreaseSpeed,
    required this.onDecreaseSpeed,
    required this.onToggleShuffle,
    required this.onAddBookmark,
    required this.onTogglePanel,
    required this.onSetSleepTimer,
    required this.onSeekTo,
    required this.onSliderHover,
    required this.onSliderExit,
    required this.onSettingsMenuSelected,
    required this.pauseMode,
    required this.onPauseModeChanged,
    required this.onOpenSubtitleManager,
    required this.buildColoredTextSpan,
    required this.defaultFont,
    required this.defaultConversionType,
    this.defaultColorPalette,
  });

  @override
  Widget build(BuildContext context) {
    final currentChapter = audiobook.chapters[currentChapterIndex];
    final fileName = path.basename(audiobook.path);
    final chapterRemaining = _getChapterRemainingTime();
    final audiobookRemaining = _getAudiobookRemainingTime();
    final progressPercent = (totalDuration.inMilliseconds > 0 
        ? (currentPosition.inMilliseconds / totalDuration.inMilliseconds * 100).toInt() 
        : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Flexible(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: '↳ ${currentChapterIndex + 1}/${audiobook.chapters.length}: ${currentChapter.title}',
                          ),
                          TextSpan(
                            text: ' -${_formatChapterRemaining(chapterRemaining)}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        // Secondary subtitle (on top)
        if (secondarySubtitleText.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: buildColoredTextSpan(
                    secondarySubtitleText,
                    fontSize: secondarySubtitleFontSize,
                    fontFamily: secondarySubtitleFont,
                    palette: secondaryColorPalette,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Primary subtitle (on bottom)
        if (currentSubtitleText.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: buildColoredTextSpan(currentSubtitleText),
                ),
              ),
            ),
          ),
        const Spacer(),
        // Slider and progress
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 2),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final actualSliderWidth = constraints.maxWidth;
                  
                  return MouseRegion(
                    onHover: (event) {
                      final localX = event.localPosition.dx;
                      
                      // Check if hovering over a chapter bar or marker
                      Duration? hoverTime;
                      String? hoverChapter;
                      
                      for (final chapter in audiobook.chapters) {
                        final startX = (chapter.startTime.inMilliseconds / totalDuration.inMilliseconds) * actualSliderWidth;
                        final endX = (chapter.endTime.inMilliseconds / totalDuration.inMilliseconds) * actualSliderWidth;
                        
                        if (localX >= startX && localX < endX) {
                          hoverTime = chapter.startTime;
                          hoverChapter = chapter.title;
                          break;
                        }
                      }
                      
                      if (hoverTime == null) {
                        hoverTime = Duration(
                          milliseconds: ((localX / actualSliderWidth) * totalDuration.inMilliseconds).toInt()
                        );
                        for (final chapter in audiobook.chapters) {
                          if (hoverTime >= chapter.startTime && hoverTime < chapter.endTime) {
                            hoverChapter = chapter.title;
                            break;
                          }
                        }
                      }
                      
                      onSliderHover(localX);
                    },
                    onExit: (_) => onSliderExit(),
                    child: GestureDetector(
                      onTapDown: (details) {
                        final localX = details.localPosition.dx;
                        
                        // Check if clicking on a chapter diamond
                        bool clickedDiamond = false;
                        for (int i = 0; i < audiobook.chapters.length; i++) {
                          final chapter = audiobook.chapters[i];
                          final diamondX = (chapter.startTime.inMilliseconds / totalDuration.inMilliseconds) * actualSliderWidth;
                          
                          if ((localX - diamondX).abs() < 15) {
                            onJumpToChapter(i);
                            clickedDiamond = true;
                            break;
                          }
                        }
                        
                        // If not clicking a diamond, seek to exact position
                        if (!clickedDiamond) {
                          final clickTime = Duration(
                            milliseconds: ((localX / actualSliderWidth) * totalDuration.inMilliseconds).toInt()
                          );
                          onSeekTo(clickTime);
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SizedBox(
                            height: 20,
                            child: CustomPaint(
                              painter: ChapterMarkerPainter(
                                chapters: audiobook.chapters,
                                totalDuration: totalDuration,
                                currentPosition: currentPosition,
                                hoverPosition: sliderHoverPosition,
                              ),
                              size: Size(actualSliderWidth, 20),
                            ),
                          ),
                          if (hoveredChapterTitle != null && sliderHoverPosition != null)
                            Positioned(
                              left: () {
                                final tooltipWidth = 250.0;
                                var leftPos = sliderHoverPosition! - (tooltipWidth / 2);
                                if (leftPos < 0) {
                                  leftPos = 0;
                                } else if (leftPos + tooltipWidth > actualSliderWidth) {
                                  leftPos = actualSliderWidth - tooltipWidth;
                                }
                                return leftPos;
                              }(),
                              top: -80,
                              child: Container(
                                width: 250,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _formatDuration(Duration(
                                        milliseconds: ((sliderHoverPosition! / actualSliderWidth) * totalDuration.inMilliseconds).toInt()
                                      )),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      hoveredChapterTitle!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$progressPercent% ${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)} • $selectedFont • ${conversionType == 'none' ? 'Original' : conversionType}${currentColorPalette != null ? ' • ${currentColorPalette!.name}' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        if (shuffleEnabled)
                          Text(
                            '${playedChapters.length}/${audiobook.chapters.length} ',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        Text(
                          '${playbackSpeed.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          ' ${_formatFileSize(fileSize)}${averageBitrate > 0 ? ' ${averageBitrate}kbps' : ''}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          ' -${_formatDuration(audiobookRemaining)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _buildControls(context),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildControls(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: onDecreaseSpeed,
          icon: const Icon(Icons.hourglass_bottom),
          color: Colors.white,
          iconSize: 20,
          tooltip: 'Decrease speed [',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onIncreaseSpeed,
          icon: const Icon(Icons.hourglass_top),
          color: Colors.white,
          iconSize: 20,
          tooltip: 'Increase speed ]',
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onPreviousChapter,
          icon: const Icon(Icons.skip_previous),
          color: Colors.white,
          iconSize: 28,
          tooltip: 'Prev Chapter',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSkipBackward,
          icon: const Icon(Icons.replay_10),
          color: Colors.white,
          iconSize: 24,
          tooltip: 'back 3s ←',
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onTogglePlayPause,
          icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle),
          color: Colors.deepPurple,
          iconSize: 28,
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: onSkipForward,
          icon: const Icon(Icons.forward_10),
          color: Colors.white,
          iconSize: 24,
          tooltip: 'forward 3s →',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onNextChapter,
          icon: const Icon(Icons.skip_next),
          color: Colors.white,
          iconSize: 28,
          tooltip: 'Next Chapter',
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onToggleShuffle,
          icon: const Icon(Icons.shuffle),
          color: shuffleEnabled ? Colors.deepPurple : Colors.white,
          iconSize: 24,
          tooltip: shuffleEnabled ? 'Shuffle ${playedChapters.length}/${audiobook.chapters.length}' : 'Shuffle off',
        ),
        const SizedBox(width: 8),
        PopupMenuButton<Duration?>(
          icon: Icon(
            Icons.access_time,
            color: sleepDuration != null ? Colors.deepPurple : Colors.white,
            size: 24,
          ),
          tooltip: 'Sleep Timer',
          onSelected: onSetSleepTimer,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: null,
              child: Text('Off'),
            ),
            const PopupMenuItem(
              value: Duration(minutes: 15),
              child: Text('15 minutes'),
            ),
            const PopupMenuItem(
              value: Duration(minutes: 30),
              child: Text('30 minutes'),
            ),
            const PopupMenuItem(
              value: Duration(minutes: 45),
              child: Text('45 minutes'),
            ),
            const PopupMenuItem(
              value: Duration(minutes: 60),
              child: Text('60 minutes'),
            ),
            const PopupMenuItem(
              value: Duration(minutes: 90),
              child: Text('90 minutes'),
            ),
            const PopupMenuItem(
              value: Duration(minutes: 120),
              child: Text('120 minutes'),
            ),
            const PopupMenuItem(
              value: Duration(minutes: -1),
              child: Text('End of Audiobook'),
            ),
            const PopupMenuItem(
              value: Duration.zero,
              child: Text('Chapter end'),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Add Bookmark',
          child: IconButton(
            onPressed: onAddBookmark,
            icon: const Icon(Icons.bookmark_add),
            color: Colors.white,
            iconSize: 24,
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onTogglePanel,
          label: const Text(
            'Chapters',
            style: TextStyle(fontSize: 12),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.text_fields, color: Colors.white, size: 24),
          tooltip: 'Appearance & Subtitles',
          onSelected: (value) => onSettingsMenuSelected(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'set_default',
              child: Text('Set Font/Color as Default'),
            ),
            PopupMenuItem(
              value: 'apply_default',
              child: Tooltip(
                message: 'Default: $defaultFont, $defaultConversionType${defaultColorPalette != null ? ', $defaultColorPalette' : ', No Color'}',
                waitDuration: const Duration(milliseconds: 100),
                child: const Text('Apply Font/Color Default (a)'),
              ),
            ),
            const PopupMenuItem(
              value: 'load_subtitle',
              child: Text('Load Subtitles'),
            ),
            const PopupMenuItem(
              value: 'subtitle_manager',
              child: Text('Bilingual Subtitles (v)'),
            ),
            PopupMenuItem(
              enabled: false,
              child: PopupMenuButton<PauseMode>(
                child: const Text('Pause Mode'),
                onSelected: onPauseModeChanged,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: PauseMode.disabled,
                    child: Row(
                      children: [
                        if (pauseMode == PauseMode.disabled)
                          const Icon(Icons.check, size: 16),
                        if (pauseMode == PauseMode.disabled)
                          const SizedBox(width: 8),
                        const Text('Disable Pause Mode'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: PauseMode.pause2s,
                    child: Row(
                      children: [
                        if (pauseMode == PauseMode.pause2s)
                          const Icon(Icons.check, size: 16),
                        if (pauseMode == PauseMode.pause2s)
                          const SizedBox(width: 8),
                        const Text('Pause Mode 2s'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: PauseMode.pause3s,
                    child: Row(
                      children: [
                        if (pauseMode == PauseMode.pause3s)
                          const Icon(Icons.check, size: 16),
                        if (pauseMode == PauseMode.pause3s)
                          const SizedBox(width: 8),
                        const Text('Pause Mode 3s'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: PauseMode.pause5s,
                    child: Row(
                      children: [
                        if (pauseMode == PauseMode.pause5s)
                          const Icon(Icons.check, size: 16),
                        if (pauseMode == PauseMode.pause5s)
                          const SizedBox(width: 8),
                        const Text('Pause Mode 5s'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: PauseMode.pause10s,
                    child: Row(
                      children: [
                        if (pauseMode == PauseMode.pause10s)
                          const Icon(Icons.check, size: 16),
                        if (pauseMode == PauseMode.pause10s)
                          const SizedBox(width: 8),
                        const Text('Pause Mode 10s'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: PauseMode.dictionary,
                    child: Row(
                      children: [
                        if (pauseMode == PauseMode.dictionary)
                          const Icon(Icons.check, size: 16),
                        if (pauseMode == PauseMode.dictionary)
                          const SizedBox(width: 8),
                        const Text('Dictionary Mode (d)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.settings, color: Colors.white, size: 24),
          tooltip: 'Settings',
          onSelected: (value) => onSettingsMenuSelected(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'fullscreen',
              child: Text('Fullscreen (y)'),
            ),
            const PopupMenuItem(
              value: 'encoder',
              child: Text('Audiobook Encoder'),
            ),
            const PopupMenuItem(
              value: 'metadata',
              child: Text('Edit Metadata'),
            ),
            const PopupMenuItem(
              value: 'copy_metadata',
              child: Text('Copy Metadata'),
            ),
            const PopupMenuItem(
              value: 'copy_chapters',
              child: Text('Copy Chapters List'),
            ),
            const PopupMenuItem(
              value: 'open_dir',
              child: Text('Open Directory of Audiobook'),
            ),
            const PopupMenuItem(
              value: 'load',
              child: Text('Load Audiobook'),
            ),
          ],
        ),
      ],
    );
  }

  Duration _getChapterRemainingTime() {
    final chapter = audiobook.chapters[currentChapterIndex];
    return chapter.endTime - currentPosition;
  }
  
  Duration _getAudiobookRemainingTime() {
    return totalDuration - currentPosition;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatChapterRemaining(Duration d) {
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      final seconds = d.inSeconds.remainder(60);
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds.remainder(60);
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).floor()}KiB';
    return '${(bytes / (1024 * 1024)).floor()}MiB';
  }
}

class ChapterMarkerPainter extends CustomPainter {
  final List<Chapter> chapters;
  final Duration totalDuration;
  final Duration currentPosition;
  final double? hoverPosition;

  ChapterMarkerPainter({
    required this.chapters,
    required this.totalDuration,
    required this.currentPosition,
    this.hoverPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalMillis = totalDuration.inMilliseconds;
    if (totalMillis == 0) return;
  
    // Draw background track at bottom (inactive/gray)
    final trackPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 4, size.width, 4),
      trackPaint,
    );
  
    // Draw progress at bottom (active/white)
    final progress = (currentPosition.inMilliseconds / totalMillis) * size.width;
    final progressPaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 4, progress, 4),
      progressPaint,
    );
  
    // Draw chapter markers (diamonds)
    for (final chapter in chapters) {
      final position = (chapter.startTime.inMilliseconds / totalMillis) * size.width;
      final isHovered = hoverPosition != null && 
                        (position - hoverPosition!).abs() < 10;
      final diamondSize = isHovered ? 8.0 : 6.0;
      final paint = Paint()
        ..color = Colors.deepPurple
        ..style = PaintingStyle.fill;
      final path = Path();
      path.moveTo(position, size.height / 2 - diamondSize);
      path.lineTo(position + diamondSize, size.height / 2);
      path.lineTo(position, size.height / 2 + diamondSize);
      path.lineTo(position - diamondSize, size.height / 2);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(ChapterMarkerPainter oldDelegate) {
    return oldDelegate.chapters != chapters || 
           oldDelegate.totalDuration != totalDuration ||
           oldDelegate.currentPosition != currentPosition ||
           oldDelegate.hoverPosition != hoverPosition;
  }
}