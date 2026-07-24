import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/youtube_service.dart';

Future<Map<String, dynamic>?> showYouTubeDialog(BuildContext context) async {
  final controller = TextEditingController();

  final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
  if (clipboardData?.text != null &&
      YouTubeService.isSupportedUrl(clipboardData!.text!)) {
    controller.text = clipboardData.text!;
  }

  List<Map<String, String>> playlistVideos = [];
  bool isFetchingPlaylist = false;
  String? playlistError;
  String? loadedPlaylistUrl;

  final prefs = await SharedPreferences.getInstance();

  List<Map<String, String>> _loadQueue() {
    final raw = prefs.getStringList('youtube_queue') ?? [];
    return raw.map((s) {
      try {
        final decoded = jsonDecode(s) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      } catch (e) {
        // Backward compatibility: old queue entries were plain URL strings
        return {'url': s, 'title': s, 'channel': '', 'duration': ''};
      }
    }).where((m) => (m['url'] ?? '').isNotEmpty).toList();
  }

  List<Map<String, String>> queueItems = _loadQueue();
  bool isAddingToQueue = false;

  Future<void> saveQueue(List<Map<String, String>> queue) async {
    await prefs.setStringList(
      'youtube_queue',
      queue.map((e) => jsonEncode(e)).toList(),
    );
  }

  Future<void> fetchPlaylist(String url, StateSetter setState) async {
    if (loadedPlaylistUrl == url) return;
    setState(() {
      isFetchingPlaylist = true;
      playlistError = null;
      playlistVideos = [];
    });
    try {
      final videos = await YouTubeService.getPlaylistVideos(url);
      setState(() {
        playlistVideos = videos;
        loadedPlaylistUrl = url;
      });
    } catch (e) {
      setState(() {
        playlistError = 'Failed to fetch playlist: $e';
      });
    } finally {
      setState(() {
        isFetchingPlaylist = false;
      });
    }
  }

  Future<void> addToQueue(StateSetter setState) async {
    final trimmed = controller.text.trim();
    if (trimmed.isEmpty) return;

    if (!YouTubeService.isSupportedUrl(trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL to queue'),
          backgroundColor: Colors.deepPurple,
        ),
      );
      return;
    }

    if (queueItems.any((item) => item['url'] == trimmed)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already in queue'),
          backgroundColor: Colors.deepPurple,
        ),
      );
      return;
    }

    setState(() {
      isAddingToQueue = true;
    });

    final info = await YouTubeService.getVideoInfo(trimmed);

    final newItem = {
      'url': trimmed,
      'title': info?['title'] ?? trimmed,
      'channel': info?['channel'] ?? '',
      'duration': info?['duration'] ?? '',
    };

    setState(() {
      queueItems = List<Map<String, String>>.from(queueItems)..add(newItem);
      isAddingToQueue = false;
      controller.clear();
    });
    await saveQueue(queueItems);
  }

  Future<void> removeFromQueue(int index, StateSetter setState) async {
    setState(() {
      queueItems = List<Map<String, String>>.from(queueItems)
        ..removeAt(index);
    });
    await saveQueue(queueItems);
  }

  // Auto-fetch if clipboard already had a playlist URL — handled after dialog opens
  String? pendingFetchUrl;
  if (YouTubeService.isPlaylistUrl(controller.text)) {
    pendingFetchUrl = controller.text;
  }

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        // Trigger initial fetch if needed
        if (pendingFetchUrl != null) {
          final url = pendingFetchUrl!;
          pendingFetchUrl = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            fetchPlaylist(url, setState);
          });
        }

        final hasPlaylist = playlistVideos.isNotEmpty;
        final hasQueue = queueItems.isNotEmpty;

        return Dialog(
          backgroundColor: const Color(0xFF2D2D2D),
          child: Container(
            width: 800,
            constraints: BoxConstraints(
              maxHeight: hasPlaylist || isFetchingPlaylist
                  ? 800
                  : (hasQueue ? 720 : 520),
            ),
            padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.headphones, color: Colors.red, size: 40),
                      SizedBox(width: 16),
                      Text(
                        'YouTube Audio',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Paste a YouTube URL or playlist to stream audio only\nSubtitles will be downloaded automatically if available',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // URL input
                  TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.link, color: Colors.white54),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFetchingPlaylist || isAddingToQueue)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          IconButton(
                            icon: const Icon(Icons.playlist_add,
                                color: Colors.white54),
                            tooltip: 'Add to Queue',
                            onPressed:
                                isAddingToQueue ? null : () => addToQueue(setState),
                          ),
                          IconButton(
                            icon: const Icon(Icons.content_paste,
                                color: Colors.white54),
                            onPressed: () async {
                              final data = await Clipboard.getData(
                                  Clipboard.kTextPlain);
                              if (data?.text != null) {
                                controller.text = data!.text!;
                                final trimmed = data.text!.trim();
                                if (YouTubeService.isPlaylistUrl(trimmed)) {
                                  fetchPlaylist(trimmed, setState);
                                } else {
                                  setState(() {
                                    playlistVideos = [];
                                    playlistError = null;
                                    loadedPlaylistUrl = null;
                                  });
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      hintText:
                          'https://youtube.com/watch?v=... or playlist URL',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (value) {
                      final trimmed = value.trim();
                      if (YouTubeService.isPlaylistUrl(trimmed) &&
                          trimmed != loadedPlaylistUrl) {
                        fetchPlaylist(trimmed, setState);
                      } else if (!YouTubeService.isPlaylistUrl(trimmed)) {
                        setState(() {
                          playlistVideos = [];
                          playlistError = null;
                          loadedPlaylistUrl = null;
                        });
                      }
                    },
                    onSubmitted: (value) {
                      if (YouTubeService.isSupportedUrl(value) &&
                          !YouTubeService.isPlaylistUrl(value)) {
                        Navigator.pop(
                            context, {'action': 'stream', 'url': value});
                      }
                    },
                  ),

                  // Playlist error
                  if (playlistError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      playlistError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 13),
                    ),
                  ],

                  // Playlist video list
                  if (hasPlaylist) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.queue_music,
                            color: Colors.white54, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${playlistVideos.length} videos — tap one to stream',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: playlistVideos.length,
                        itemBuilder: (context, index) {
                          final video = playlistVideos[index];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Navigator.pop(context, {
                                'action': 'stream',
                                'url': video['url'],
                                'playlistIndex': index,
                                'playlistTotal': playlistVideos.length,
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.deepPurple.withAlpha(160),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      video['title']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (video['duration'] != null &&
                                      video['duration']!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      video['duration']!,
                                      style: const TextStyle(
                                        color: Colors.lightBlue,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white38,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Footer note + Queue (only shown outside of playlist browsing)
                  if (!hasPlaylist) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '(Mac) brew install yt-dlp  (Linux) sudo apt install yt-dlp  (Windows) choco install yt-dlp',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),

                    if (hasQueue) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.playlist_play,
                              color: Colors.white54, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Queue (${queueItems.length}) — tap to play & remove',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: queueItems.length,
                          itemBuilder: (context, index) {
                            final item = queueItems[index];
                            final title = item['title']?.isNotEmpty == true
                                ? item['title']!
                                : item['url'] ?? '';
                            final channel = item['channel'] ?? '';
                            final duration = item['duration'] ?? '';

                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                final url = item['url']!;
                                await removeFromQueue(index, setState);
                                Navigator.pop(
                                    context, {'action': 'stream', 'url': url});
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 2),
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white38,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (channel.isNotEmpty ||
                                              duration.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              [
                                                if (channel.isNotEmpty)
                                                  channel,
                                                if (duration.isNotEmpty)
                                                  duration,
                                              ].join('  •  '),
                                              style: const TextStyle(
                                                color: Colors.lightBlue,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white38, size: 18),
                                      tooltip: 'Remove from queue',
                                      onPressed: () =>
                                          removeFromQueue(index, setState),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.download, size: 20),
                        label: const Text('Download Only (⇧D)'),
                        onPressed: () {
                          Navigator.pop(context, {'action': 'download'});
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.purple,
                          side: const BorderSide(color: Colors.deepPurple),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 24),
                        label: const Text('Stream Audio'),
                        onPressed: () {
                          final url = controller.text.trim();
                          if (YouTubeService.isSupportedUrl(url) &&
                              !YouTubeService.isPlaylistUrl(url)) {
                            Navigator.pop(
                                context, {'action': 'stream', 'url': url});
                          } else if (!YouTubeService.isPlaylistUrl(url)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please enter a valid YouTube URL'),
                                backgroundColor: Colors.deepPurple,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  controller.dispose();
  return result;
}
