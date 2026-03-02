import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/lut_list.dart';
import '../models/lut_item.dart';
import '../services/lut_thumbnail_service.dart';
import '../services/lut_favorites_service.dart';
import '../services/video_edit_service.dart';

const List<String> kLutCategories = [
  'Favorites',
  'All',
  'abigailgonzalez',
  'alexjordan',
  'berat',
  'creative',
  'editingcorp',
  'editingcorpw',
  'ericellerbrock',
  'films colorslide',
  'films negative color',
  'films print',
  'fujixtransiii',
  'inavision',
  'jtsemple',
  'kylerholland',
  'ohadperetz',
  'others',
  'picturefx',
  'pixlsus',
  'shamoonabbasi',
  'toddblankenship',
  'youssefhossam',
];

List<LutItem> _lutsForCategory(String category, Set<String> favorites) {
  final all = lutList
      .map((e) => LutItem(name: e['name']!, path: e['path']!))
      .toList();
  if (category == 'Favorites') {
    return all.where((l) => favorites.contains(l.name)).toList();
  }
  if (category == 'All') return all;
  return all.where((l) => l.name.startsWith(category)).toList();
}


class LutPickerOverlay extends StatefulWidget {
  final String videoPath;
  final Duration currentPosition;

  final void Function(LutItem? lut) onLutSelected;

  final String? currentLutName;

  const LutPickerOverlay({
    super.key,
    required this.videoPath,
    required this.currentPosition,
    required this.onLutSelected,
    this.currentLutName,
  });

  @override
  State<LutPickerOverlay> createState() => _LutPickerOverlayState();
}

class _LutPickerOverlayState extends State<LutPickerOverlay> {
  static const int _pageSize = 5;

  String _selectedCategory = 'All';
  int _currentPage = 0;
  bool _showFavoritesTab = false;

  List<LutItem> _categoryLuts = [];
  Set<String> _favorites = {};
  bool _favoritesLoaded = false;
  bool _serviceReady = false;

  List<_ThumbEntry> _thumbs = [];
  bool _loadingPage = false;

  List<_ThumbEntry>? _nextPageThumbs;

  String? _selectedLutName;

  @override
  void initState() {
    super.initState();
    _selectedLutName = widget.currentLutName;
    _initService();
  }

  Future<void> _initService() async {
    final ffmpeg = await VideoEditService.findSystemFfmpeg();
    if (ffmpeg == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ffmpeg not found — LUT previews unavailable'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    await LutThumbnailService.instance.init(ffmpeg);
    _favorites = await LutFavoritesService.instance.getFavorites();
    if (mounted) {
      setState(() {
        _serviceReady = true;
        _favoritesLoaded = true;
      });
      _rebuildCategory();
    }
  }

  void _rebuildCategory() {
    _categoryLuts = _lutsForCategory(_selectedCategory, _favorites);
    _currentPage = 0;
    _nextPageThumbs = null;
    _loadPage(0);
  }

  int get _totalPages => (_categoryLuts.length / _pageSize).ceil();

  List<LutItem> _lutsOnPage(int page) {
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, _categoryLuts.length);
    return _categoryLuts.sublist(start, end);
  }

  Future<void> _loadPage(int page, {bool preload = true}) async {
    if (!_serviceReady) return;
    setState(() => _loadingPage = true);

    final luts = _lutsOnPage(page);
    final entries = await _generateEntries(luts);

    if (!mounted) return;
    setState(() {
      _thumbs = entries;
      _loadingPage = false;
    });

    if (preload && page + 1 < _totalPages) {
      _preloadNextPage(page + 1);
    }
  }

  Future<void> _preloadNextPage(int page) async {
    final luts = _lutsOnPage(page);
    final entries = await _generateEntries(luts);
    if (mounted) _nextPageThumbs = entries;
  }

  Future<List<_ThumbEntry>> _generateEntries(List<LutItem> luts) async {
    final requests = [
      (name: 'Original', assetPath: ''),
      ...luts.map((l) => (name: l.name, assetPath: l.path)),
    ];

    final results = await LutThumbnailService.instance.generatePage(
      videoPath: widget.videoPath,
      position: widget.currentPosition,
      luts: requests,
    );

    return List.generate(results.length, (i) {
      final (label, imgPath) = results[i];
      final lutItem = i == 0 ? null : luts[i - 1];
      return _ThumbEntry(
        label: i == 0 ? 'Original' : lutItem!.displayName,
        imagePath: imgPath,
        lutItem: lutItem,
      );
    });
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _totalPages) return;
    if (_nextPageThumbs != null && page == _currentPage + 1) {
      setState(() {
        _thumbs = _nextPageThumbs!;
        _nextPageThumbs = null;
        _currentPage = page;
      });
      _preloadNextPage(page + 1);
    } else {
      setState(() => _currentPage = page);
      _loadPage(page);
    }
  }

  Future<void> _toggleFavorite(String lutName) async {
    await LutFavoritesService.instance.toggle(lutName);
    final updated = await LutFavoritesService.instance.getFavorites();
    setState(() => _favorites = updated);
    // If in Favorites category, rebuild
    if (_selectedCategory == 'Favorites') _rebuildCategory();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKey,
      child: Material(
        color: Colors.black.withAlpha(235),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildCategoryBar(),
              Expanded(child: _buildGrid()),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) _goToPage(_currentPage + 1);
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _goToPage(_currentPage - 1);
    if (event.logicalKey == LogicalKeyboardKey.escape) Navigator.of(context).pop();
  }


  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          const Text('LUT Picker',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          if (_selectedLutName != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                'Selected: ${_selectedLutName!.replaceAll('.cube', '')}',
                style: const TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ),
          TextButton(
            onPressed: () {
              widget.onLutSelected(null);
              Navigator.of(context).pop();
            },
            child:
                const Text('No LUT', style: TextStyle(color: Colors.white54)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          _CategoryChip(
            label: '★ Favorites',
            selected: _selectedCategory == 'Favorites',
            onTap: () => setState(() {
              _selectedCategory = 'Favorites';
              _rebuildCategory();
            }),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: kLutCategories.contains(_selectedCategory) &&
                        _selectedCategory != 'Favorites'
                    ? _selectedCategory
                    : 'All',
                itemHeight: 32,
                dropdownColor: const Color(0xFF1E1E1E),
                style:
                    const TextStyle(color: Colors.white, fontSize: 10),
                icon: const Icon(Icons.arrow_drop_down,
                    color: Colors.white54),
                items: kLutCategories
                    .where((c) => c != 'Favorites')
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _selectedCategory = val;
                    _rebuildCategory();
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_categoryLuts.length} LUTs',
            style:
                const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }


  Widget _buildGrid() {
    if (!_serviceReady) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_categoryLuts.isEmpty) {
      return const Center(
        child: Text('No LUTs in this category',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(6),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 16 / 11,
          ),
          itemCount: _thumbs.isEmpty ? 9 : _thumbs.length,
          itemBuilder: (context, index) {
            if (_thumbs.isEmpty || _loadingPage) {
              return _buildLoadingCell();
            }
            if (index >= _thumbs.length) return const SizedBox();
            return _buildThumbCell(_thumbs[index]);
          },
        ),
        if (_loadingPage)
          const Center(
              child: CircularProgressIndicator(color: Colors.amber)),
      ],
    );
  }

  Widget _buildLoadingCell() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white38))),
    );
  }

  Widget _buildThumbCell(_ThumbEntry entry) {
    final isSelected = entry.lutItem != null &&
        entry.lutItem!.name == _selectedLutName;
    final isOriginal = entry.lutItem == null;
    final isFav = entry.lutItem != null &&
        LutFavoritesService.instance.isFavorite(entry.lutItem!.name);

    return GestureDetector(
      onTap: () {
        setState(() => _selectedLutName = entry.lutItem?.name);
        widget.onLutSelected(entry.lutItem);
        Navigator.of(context).pop();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: entry.imagePath != null
                ? Image.file(File(entry.imagePath!), fit: BoxFit.cover)
                : Container(color: Colors.white10),
          ),

          if (isSelected)
            DecoratedBox(
              decoration: BoxDecoration(
                border:
                    Border.all(color: Colors.amber, width: 2.5),
                borderRadius: BorderRadius.circular(6),
              ),
            ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(210),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(6)),
              ),
              child: Text(
                isOriginal ? 'Original' : entry.lutItem!.name.replaceAll('.cube', ''),
                style: TextStyle(
                  color: isSelected ? Colors.amber : Colors.white,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                    Shadow(color: Colors.black, blurRadius: 8),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          if (!isOriginal)
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _toggleFavorite(entry.lutItem!.name),
                child: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  color: isFav ? Colors.amber : Colors.white54,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildFooter() {
    if (_totalPages <= 1) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed:
                _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
          ),
          Text(
            'Page ${_currentPage + 1} / $_totalPages',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            onPressed: _currentPage < _totalPages - 1
                ? () => _goToPage(_currentPage + 1)
                : null,
          ),
          const SizedBox(width: 16),
          // Jump to page
          SizedBox(
            width: 55,
            height: 32,
            child: TextField(
              style:
                  const TextStyle(color: Colors.white, fontSize: 13),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Go',
                hintStyle:
                    const TextStyle(color: Colors.white38, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                isDense: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide:
                      const BorderSide(color: Colors.amber),
                ),
              ),
              onSubmitted: (val) {
                final pg = int.tryParse(val);
                if (pg != null) _goToPage(pg - 1);
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? Colors.amber : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}


class _ThumbEntry {
  final String label;
  final String? imagePath;
  final LutItem? lutItem;

  _ThumbEntry({
    required this.label,
    required this.imagePath,
    required this.lutItem,
  });
}