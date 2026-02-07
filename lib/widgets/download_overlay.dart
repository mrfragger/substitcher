import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../services/download_service.dart';
import '../services/youtube_service.dart';
import 'dart:async';

class DownloadOverlay extends StatefulWidget {
  final String? youtubeUrl;
  
  const DownloadOverlay({
    super.key,
    this.youtubeUrl,
  });
  
  @override
  State<DownloadOverlay> createState() => _DownloadOverlayState();
}

class _DownloadOverlayState extends State<DownloadOverlay> {
  final TextEditingController _urlController = TextEditingController();
  String? _downloadDirectory;
  bool _isDownloading = false;
  bool _isFetchingFormats = false;
  bool _isPlaylist = false;
  bool _reversePlaylist = true;
  bool _noPlaylist = false;
  bool _splitChapters = false;
  bool _enableSleepInterval = false;
  bool _downloadAllPlaylists = false;
  String? _playlistItemsRange;
  String? _channelName;
  String? _playlistTitle;
  String? _urlError;
  bool _resumeMode = false;
  bool _autoScrollEnabled = true;
  Timer? _scrollResumeTimer;
  
  final List<String> _progressMessages = [];
  final List<String> _availableFormats = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _formatController = TextEditingController(text: '139');
  final TextEditingController _playlistItemsController = TextEditingController();

  final TextEditingController _channelNameController = TextEditingController();
  final TextEditingController _playlistTitleController = TextEditingController();
  bool _showManualPlaylistInfo = false;
  
  final Map<String, String> _formatExamples = {
    '139': 'half size 140',
    '140': 'AAC (ones after 2020)',
    '251': 'WebM opus',
    'opus': 'opus audio',
    'mp3': 'mp3 audio',
    'm4a': 'm4a audio',
    '18': '360p video/audio',
  };
  
  @override
  void initState() {
    super.initState();
    _loadSavedDirectory();
    
    if (widget.youtubeUrl != null) {
      _urlController.text = widget.youtubeUrl!;
      _checkIfPlaylist();
    } else {
      _pasteFromClipboard();
    }
  }

  @override
  void dispose() {
    _scrollResumeTimer?.cancel();
    _urlController.dispose();
    _scrollController.dispose();
    _formatController.dispose();
    _playlistItemsController.dispose();
    _channelNameController.dispose();
    _playlistTitleController.dispose();
    super.dispose();
  }
  
  void _onUserScroll() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >= 
                         _scrollController.position.maxScrollExtent - 50;
      
      if (!isAtBottom) {
        setState(() {
          _autoScrollEnabled = false;
        });
        
        _scrollResumeTimer?.cancel();
        _scrollResumeTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _autoScrollEnabled = true;
            });
          }
        });
      } else {
        setState(() {
          _autoScrollEnabled = true;
        });
      }
    }
  }
  
  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData != null && clipboardData.text != null) {
      final text = clipboardData.text!.trim();
      if (YouTubeService.isSupportedUrl(text)) {
        final cleanedUrl = YouTubeService.cleanUrl(text);
        _urlController.text = cleanedUrl;
        _checkIfPlaylist();
      }
    }
  }
  
  Future<void> _loadSavedDirectory() async {
    final dir = await DownloadService.getSavedDownloadDirectory() ??
               await DownloadService.getDefaultDownloadDirectory();
    setState(() {
      _downloadDirectory = dir;
    });
  }
  
  Future<void> _checkIfPlaylist() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !YouTubeService.isSupportedUrl(url)) {
      setState(() {
        _isPlaylist = false;
        _channelName = null;
        _playlistTitle = null;
      });
      return;
    }
    
    final cleanedUrl = YouTubeService.cleanUrl(url);
    if (cleanedUrl != url) {
      _urlController.text = cleanedUrl;
    }
    
    final isPlaylist = await DownloadService.isPlaylist(cleanedUrl);
    if (mounted) {
      setState(() {
        _isPlaylist = isPlaylist;
        _urlError = null;
      });
      if (isPlaylist) {
        _fetchPlaylistInfo();
      }
    }
  }
  
  Future<void> _fetchPlaylistInfo() async {
    final info = await DownloadService.getPlaylistInfo(_urlController.text.trim());
    if (mounted && info != null) {
      final channel = info['channel'] ?? 'Unknown';
      final title = info['title'] ?? 'Playlist';
      
      setState(() {
        _channelName = channel;
        _playlistTitle = title;
        
        if (channel == 'Unknown' || title == 'Playlist') {
          _showManualPlaylistInfo = true;
          _channelNameController.text = channel == 'Unknown' ? '' : channel;
          _playlistTitleController.text = title == 'Playlist' ? '' : title;
        } else {
          _showManualPlaylistInfo = false;
        }
      });
    }
  }
  
  Future<void> _fetchAvailableFormats() async {
    final url = _urlController.text.trim();
    
    if (url.isEmpty || !YouTubeService.isSupportedUrl(url)) {
      setState(() {
        _urlError = 'Please enter a valid YouTube URL first';
      });
      return;
    }
    
    setState(() {
      _isFetchingFormats = true;
      _availableFormats.clear();
      _urlError = null;
    });
    
    final formats = await DownloadService.getAvailableFormats(
      url,
      playlistItem: _isPlaylist ? 3 : null,
    );
    
    if (mounted) {
      setState(() {
        _availableFormats.addAll(formats);
        _isFetchingFormats = false;
      });
      
      _showFormatsDialog();
    }
  }
  
  void _showFormatsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2D2D2D),
        child: Container(
          width: 700,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Audio Formats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Audio-only formats (recommended):',
                style: TextStyle(color: Colors.green, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListView.builder(
                    itemCount: _availableFormats.length,
                    itemBuilder: (context, index) {
                      final format = _availableFormats[index];
                      final isAudioOnly = format.contains('audio only') || 
                                         format.contains('m4a') ||
                                         format.contains('webm');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          format,
                          style: TextStyle(
                            color: isAudioOnly ? Colors.green[300] : Colors.white70,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Common choices: 139, 140 (AAC), 251 (smallest), opus, mp3, m4a',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Future<void> _pickDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      await DownloadService.saveDownloadDirectory(result);
      setState(() {
        _downloadDirectory = result;
      });
    }
  }
  
  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    
    if (url.isEmpty) {
      setState(() {
        _urlError = 'Please enter a YouTube URL';
      });
      return;
    }
    
    if (!YouTubeService.isSupportedUrl(url)) {
      setState(() {
        _urlError = 'Invalid URL (YouTube, SoundCloud, or Spreaker only)';
      });
      return;
    }
    
    if (_downloadDirectory == null) return;
    
    setState(() {
      _isDownloading = true;
      _progressMessages.clear();
      _urlError = null;
      _autoScrollEnabled = true;
    });
    
    final format = _formatController.text.trim();
    if (format.isEmpty) {
      setState(() {
        _progressMessages.add('ERROR: Please enter a format');
        _isDownloading = false;
      });
      return;
    }
    
    final success = await DownloadService.downloadYouTubeAudio(
      youtubeUrl: url,
      customDirectory: _downloadDirectory,
      format: format,
      isPlaylist: _isPlaylist,
      reversePlaylist: _reversePlaylist,
      noPlaylist: _noPlaylist,
      splitChapters: _splitChapters,
      enableSleepInterval: _enableSleepInterval,
      downloadAllPlaylists: _downloadAllPlaylists,
      playlistItemsRange: _playlistItemsRange,
      channelName: _channelName,
      playlistTitle: _playlistTitle,
      resumeMode: _resumeMode,
      onProgress: (message) {
        if (mounted) {
          setState(() {
            _progressMessages.add(message);
          });
          
          if (_autoScrollEnabled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _progressMessages.add('ERROR: $error');
          });
        }
      },
    );
    
    if (mounted) {
      setState(() {
        _isDownloading = false;
      });
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2D2D2D),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPlaylist 
                        ? 'Download ${YouTubeService.getPlatformName(_urlController.text)} Playlist' 
                        : 'Download ${YouTubeService.getPlatformName(_urlController.text)} Audio',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isPlaylist && _channelName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Channel: $_channelName',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (_playlistTitle != null)
                        Text(
                          'Playlist: $_playlistTitle',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YouTube URL',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      enabled: !_isDownloading,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E1E1E),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        hintText: 'Paste YouTube, SoundCloud, or Spreaker URL',
                        hintStyle: const TextStyle(color: Colors.white38),
                        errorText: _urlError,
                        errorStyle: const TextStyle(color: Colors.red),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste, color: Colors.white54),
                          onPressed: _isDownloading ? null : _pasteFromClipboard,
                          tooltip: 'Paste from clipboard',
                        ),
                      ),
                      onChanged: (_) {
                        _checkIfPlaylist();
                        if (_urlError != null) {
                          setState(() {
                            _urlError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Supported: YouTube (videos/playlists) | SoundCloud (tracks/sets) | Spreaker (episodes/podcasts)',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Download Directory',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _downloadDirectory ?? 'Loading...',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Change'),
                          onPressed: _isDownloading ? null : _pickDirectory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Audio Format ID',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _formatController,
                                enabled: !_isDownloading,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: '139, 140, 251, opus, mp3, m4a, 18',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: ElevatedButton.icon(
                            icon: _isFetchingFormats
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.list, size: 18),
                            label: Text(_isFetchingFormats ? 'Loading...' : 'Show Formats'),
                            onPressed: _isDownloading || _isFetchingFormats 
                                ? null 
                                : _fetchAvailableFormats,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _formatExamples.entries.map((entry) {
                        return InkWell(
                          onTap: _isDownloading ? null : () {
                            _formatController.text = entry.key;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _formatController.text == entry.key
                                    ? Colors.deepPurple
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    if (_isPlaylist) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Playlist Options',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_showManualPlaylistInfo) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Please provide playlist information',
                                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Channel/Creator Name',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _channelNameController,
                                enabled: !_isDownloading,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: 'e.g., Podcast Creator Name',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                ),
                                onChanged: (value) {
                                  _channelName = value.trim().isEmpty ? 'Unknown' : value.trim();
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Playlist/Show Title',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _playlistTitleController,
                                enabled: !_isDownloading,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: 'e.g., My Podcast Series',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                ),
                                onChanged: (value) {
                                  _playlistTitle = value.trim().isEmpty ? 'Playlist' : value.trim();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      CheckboxListTile(
                        title: const Text(
                          'Download in reverse order',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Enable if newest video is first in playlist',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        value: _reversePlaylist,
                        onChanged: _isDownloading ? null : (value) {
                          setState(() {
                            _reversePlaylist = value ?? true;
                          });
                        },
                        activeColor: Colors.deepPurple,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      CheckboxListTile(
                        title: const Text(
                          'Download single item only (not entire playlist)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Only download one video/audio from the playlist',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        value: _noPlaylist,
                        onChanged: _isDownloading ? null : (value) {
                          setState(() {
                            _noPlaylist = value ?? false;
                          });
                        },
                        activeColor: Colors.deepPurple,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      CheckboxListTile(
                        title: const Text(
                          'Split chapters',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Not recommended for long playlists',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        value: _splitChapters,
                        onChanged: _isDownloading ? null : (value) {
                          setState(() {
                            _splitChapters = value ?? false;
                          });
                        },
                        activeColor: Colors.deepPurple,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      CheckboxListTile(
                        title: const Text(
                          'Enable sleep intervals (5-10 seconds)',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Recommended for large playlists (300+ items) to prevent rate limiting',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        value: _enableSleepInterval,
                        onChanged: _isDownloading ? null : (value) {
                          setState(() {
                            _enableSleepInterval = value ?? false;
                          });
                        },
                        activeColor: Colors.deepPurple,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      CheckboxListTile(
                        title: const Text(
                          'Download ALL playlists from this channel',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Videos organized by: channel/playlist/filename',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        value: _downloadAllPlaylists,
                        onChanged: _isDownloading ? null : (value) {
                          setState(() {
                            _downloadAllPlaylists = value ?? false;
                          });
                        },
                        activeColor: Colors.deepPurple,
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      const Text(
                        'Download specific playlist items (optional)',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _playlistItemsController,
                        enabled: !_isDownloading,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1E1E1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          hintText: 'e.g., 5:10, 17,20,25:52, 105:-1',
                          hintStyle: const TextStyle(color: Colors.white38),
                        ),
                        onChanged: (value) {
                          _playlistItemsRange = value.trim().isEmpty ? null : value.trim();
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Examples: 5:10 (items 5-10), 17,20,25:52 (items 17,20,25-52), 105:-1 (105 to end)',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Note: Audio will be saved in a subdirectory named after the video title',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_progressMessages.isNotEmpty) ...[
              Container(
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is UserScrollNotification) {
                      _onUserScroll();
                    }
                    return true;
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _progressMessages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _progressMessages[index],
                          style: TextStyle(
                            color: _progressMessages[index].startsWith('ERROR')
                                ? Colors.red[300]
                                : Colors.green[300],
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (!_autoScrollEnabled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'Auto-scroll paused',
                        style: TextStyle(color: Colors.orange, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _autoScrollEnabled = true;
                          });
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOut,
                          );
                        },
                        child: const Text(
                          'Resume',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
            
            if (_isPlaylist && !_noPlaylist) ...[
              CheckboxListTile(
                title: const Text(
                  'Resume Download (only missing items)',
                  style: TextStyle(color: Colors.deepOrange, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Automatically detect and download only missing items from playlist',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                value: _resumeMode,
                onChanged: _isDownloading ? null : (value) {
                  setState(() {
                    _resumeMode = value ?? false;
                  });
                },
                activeColor: Colors.orange,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
            ],
            
            Row(
              children: [
                if (_isDownloading)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Download'),
                      onPressed: () {
                        DownloadService.cancelDownload();
                        setState(() {
                          _progressMessages.add('');
                          _progressMessages.add('Canceling download...');
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(_resumeMode ? Icons.refresh : Icons.download),
                      label: Text(_resumeMode ? 'Resume Download' : 'Download'),
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _resumeMode ? Colors.deepOrange : Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}