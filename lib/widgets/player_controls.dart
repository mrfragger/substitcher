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
  final double subtitleLineSpacing;
  final double secondarySubtitleLineSpacing;
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
  final bool hideChapterTitle;
  final bool hoveringPrevChapter;
  final bool hoveringNextChapter;
  final Function(bool) onPrevChapterHover;
  final Function(bool) onNextChapterHover;
  
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
  final TextSpan Function(String text, {double? fontSize, String? fontFamily, ColorPalette? palette, double? lineSpacing}) buildColoredTextSpan;
  
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
    required this.subtitleLineSpacing,
    required this.secondarySubtitleLineSpacing,
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
    required this.hideChapterTitle,
    required this.hoveringPrevChapter,
    required this.hoveringNextChapter,
    required this.onPrevChapterHover,
    required this.onNextChapterHover,   
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
                        ),
                        children: [
                          TextSpan(
                            text: hideChapterTitle 
                                ? '↳ ${currentChapterIndex + 1}/${audiobook.chapters.length}'
                                : '↳ ${currentChapterIndex + 1}/${audiobook.chapters.length}: ${currentChapter.title}',
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
        if (secondarySubtitleText.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.80,
                ),
                child: SingleChildScrollView(
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
                        lineSpacing: secondarySubtitleLineSpacing,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        if (currentSubtitleText.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.80,
                ),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: buildColoredTextSpan(currentSubtitleText, lineSpacing: subtitleLineSpacing,),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 2),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final sliderWidth = constraints.maxWidth;
                  
                  return Column(
                    children: [
                      MouseRegion(
                        onHover: (event) {
                          final localX = event.localPosition.dx;
                          onSliderHover(localX);
                        },
                        onExit: (_) => onSliderExit(),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GestureDetector(
                              onTapDown: (details) {
                                final localX = details.localPosition.dx;
                                final clickTime = Duration(
                                  milliseconds: ((localX / sliderWidth) * totalDuration.inMilliseconds).toInt()
                                );
                                onSeekTo(clickTime);
                              },
                              child: SizedBox(
                                height: 32,
                                child: CustomPaint(
                                  painter: ProgressBarPainter(
                                    currentPosition: currentPosition,
                                    totalDuration: totalDuration,
                                  ),
                                  size: Size(sliderWidth, 32),
                                ),
                              ),
                            ),
                            if (hoveredChapterTitle != null && sliderHoverPosition != null)
                              Positioned(
                                left: () {
                                  final tooltipWidth = 250.0;
                                  var leftPos = sliderHoverPosition! - (tooltipWidth / 2);
                                  if (leftPos < 0) {
                                    leftPos = 0;
                                  } else if (leftPos + tooltipWidth > sliderWidth) {
                                    leftPos = sliderWidth - tooltipWidth;
                                  }
                                  return leftPos;
                                }(),
                                top: -70,
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
                                          milliseconds: ((sliderHoverPosition! / sliderWidth) * totalDuration.inMilliseconds).toInt()
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
                    ],
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
                        '$progressPercent% ${_formatDuration(currentPosition)} / ${_formatDuration(totalDuration)} • $selectedFont • ${conversionType == 'none' ? 'Original' : conversionType}${currentColorPalette != null ? ' • ${currentColorPalette!.name}' : ''} • ${subtitleFontSize.toInt()} • ${subtitleLineSpacing.toStringAsFixed(2)}',
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
                          [
                            if (pauseMode != PauseMode.disabled && pauseMode != PauseMode.dictionary)
                              '${_getPauseModeText(pauseMode)} • ',
                            '${playbackSpeed.toStringAsFixed(1)}x',
                          ].join(),
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
        const SizedBox(height: 2),
        _buildControls(context),
        const SizedBox(height: 1),
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
        MouseRegion(
          onEnter: (_) => onPrevChapterHover(true),
          onExit: (_) => onPrevChapterHover(false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onPreviousChapter,
                icon: const Icon(Icons.skip_previous),
                color: Colors.white,
                iconSize: 28,
              ),
              if (hoveringPrevChapter && currentChapterIndex > 0)
                Positioned(
                  bottom: 50,
                  left: -100,
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
                          'Prev Chapter (Shift+←)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          audiobook.chapters[currentChapterIndex - 1].title,
                          textAlign: TextAlign.center,
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
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSkipBackward,
          icon: const Icon(Icons.arrow_back_ios_outlined),
          color: Colors.white,
          iconSize: 24,
          tooltip: 'Prev Sub ←',
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
          icon: const Icon(Icons.arrow_forward_ios_outlined),
          color: Colors.white,
          iconSize: 24,
          tooltip: 'Next Sub →',
        ),
        const SizedBox(width: 8),
        MouseRegion(
          onEnter: (_) => onNextChapterHover(true),
          onExit: (_) => onNextChapterHover(false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNextChapter,
                icon: const Icon(Icons.skip_next),
                color: Colors.white,
                iconSize: 28,
              ),
              if (hoveringNextChapter && currentChapterIndex < audiobook.chapters.length - 1)
                Positioned(
                  bottom: 50,
                  left: -100,
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
                          'Next Chapter (Shift+→)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          audiobook.chapters[currentChapterIndex + 1].title,
                          textAlign: TextAlign.center,
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
              value: Duration(seconds: -1), 
              child: Text('Off (Z)'),
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
              child: Text('Chapter end (z)'),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Add Bookmark (n)',
          child: IconButton(
            onPressed: onAddBookmark,
            icon: const Icon(Icons.bookmark_add),
            color: Colors.white,
            iconSize: 24,
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Chapters (c)',
          child: IconButton(
            icon: const Icon(Icons.view_timeline),
            color: Colors.white,
            iconSize: 28,
            onPressed: onTogglePanel,
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.text_fields, color: Colors.white, size: 24),
          tooltip: 'Appearance & Subtitles',
          onSelected: (value) => onSettingsMenuSelected(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              enabled: false,
              child: Text('Font Line Space (Ctrl+↑/↓)'),
            ),
            const PopupMenuItem<String>(
              enabled: false,
              child: Text('Font Size (↑/↓)'),
            ),
            const PopupMenuItem(
              value: 'hideChapterTitle',
              child: Text('Chapter Title Hide/Show ( . )'),
            ),
            const PopupMenuItem(
              value: 'hideChapterTitle',
              child: Text('Copy Current Subtitle (u)'),
            ),
            const PopupMenuItem(
              value: 'set_default',
              child: Text('Set Font/Color as Default (q)'),
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
              value: 'subtitle_manager',
              child: Text('Subtitle Manager (v)'),
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
                        const Text('Disable Pause Mode (G)'),
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
                        const Text('Pause Mode 2s (g)'),
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
              value: 'adhan_clock',
              child: Text('Adhan Clock (m)'),
            ),
             const PopupMenuItem(
              value: 'fullscreen',
              child: Text('Fullscreen (y)'),
            ),
            const PopupMenuItem(
              value: 'encoder',
              child: Text('Encode Audiobook (e)'),
            ),
            const PopupMenuItem(
              value: 'copy_metadata',
              child: Text('Copy Metadata (i)'),
            ),
            const PopupMenuItem(
              value: 'copy_chapters',
              child: Text('Copy Chapters List & .txt (r)'),
            ),
            const PopupMenuItem(
              value: 'open_dir',
              child: Text('Open Dir of Audiobook (j)'),
            ),
            const PopupMenuItem(
              value: 'load',
              child: Text('Load Audiobook (l)'),
            ),
          ],
        ),
      ],
    );
  }

  Duration _getChapterRemainingTime() {
    final chapter = audiobook.chapters[currentChapterIndex];
    final remaining = chapter.endTime - currentPosition;
    
    return Duration(
      milliseconds: (remaining.inMilliseconds / playbackSpeed).round()
    );
  }
  
  Duration _getAudiobookRemainingTime() {
    final remaining = totalDuration - currentPosition;
    return Duration(
      milliseconds: (remaining.inMilliseconds / playbackSpeed).round()
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatChapterRemaining(Duration d) {
    const ltrEmbed = '\u202A';
    const popDir = '\u202C';
    
    if (d.inHours > 0) {
      final hours = d.inHours;
      final minutes = d.inMinutes.remainder(60);
      final seconds = d.inSeconds.remainder(60);
      final timeString = '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      return '$ltrEmbed$timeString$popDir';
    } else {
      final minutes = d.inMinutes;
      final seconds = d.inSeconds.remainder(60);
      final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';
      return '$ltrEmbed$timeString$popDir';
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).floor()}KiB';
    return '${(bytes / (1024 * 1024)).floor()}MiB';
  }
}

String _getPauseModeText(PauseMode mode) {
  switch (mode) {
    case PauseMode.pause2s:
      return 'Pause 2s';
    case PauseMode.pause3s:
      return 'Pause 3s';
    case PauseMode.pause5s:
      return 'Pause 5s';
    case PauseMode.pause10s:
      return 'Pause 10s';
    case PauseMode.dictionary:
      return 'Dict';
    case PauseMode.disabled:
      return '';
  }
}

class ProgressBarPainter extends CustomPainter {
  final Duration currentPosition;
  final Duration totalDuration;

  ProgressBarPainter({
    required this.currentPosition,
    required this.totalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final totalMillis = totalDuration.inMilliseconds;
    if (totalMillis == 0) return;
  
    final barHeight = 4.0;
    final yOffset = (size.height - barHeight) / 2;
    
    final trackPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, yOffset, size.width, barHeight),
      trackPaint,
    );
  
    final progress = (currentPosition.inMilliseconds / totalMillis) * size.width;
    final progressPaint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, yOffset, progress, barHeight),
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(ProgressBarPainter oldDelegate) {
    return oldDelegate.currentPosition != currentPosition ||
           oldDelegate.totalDuration != totalDuration;
  }
}