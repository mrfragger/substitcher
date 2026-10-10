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

/// Which chip a LUT belongs to (longest matching prefix wins).
String? _groupOfLut(String name) {
  String? best;
  for (final c in kLutCategories) {
    if (c == 'Favorites' || c == 'All') continue;
    if (name.startsWith('$c ') && (best == null || c.length > best.length)) {
      best = c;
    }
  }
  return best;
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
    final start = (page * _pageSize).clamp(0, _categoryLuts.length);
    final end = (start + _pageSize).clamp(0, _categoryLuts.length);
    return _categoryLuts.sublist(start, end);
  }

  /// Start page (1-based, in "All" mode) and LUT count for each group.
  late final Map<String, ({int page, int count})> _groupInfo = _buildGroupInfo();

  Map<String, ({int page, int count})> _buildGroupInfo() {
    final info = <String, ({int page, int count})>{};
    for (var i = 0; i < lutList.length; i++) {
      final g = _groupOfLut(lutList[i]['name']!);
      if (g == null) continue;
      final prev = info[g];
      info[g] = (
        page: prev?.page ?? (i ~/ _pageSize) + 1,
        count: (prev?.count ?? 0) + 1,
      );
    }
    return info;
  }

  Set<String> get _visibleGroups {
    if (_selectedCategory != 'All') return const {};
    return {
      for (final lut in _lutsOnPage(_currentPage))
        if (_groupOfLut(lut.name) case final g?) g,
    };
  }

  Future<void> _loadPage(int page, {bool preload = true}) async {
    if (!_serviceReady) return;
    setState(() => _loadingPage = true);

    final snapshot = _categoryLuts;
    final luts = _lutsOnPage(page);
    final entries = await _generateEntries(luts);

    // Ignore results if the category changed while thumbnails were generating
    if (!mounted || !identical(snapshot, _categoryLuts)) return;
    setState(() {
      _thumbs = entries;
      _loadingPage = false;
    });

    if (preload && page + 1 < _totalPages) {
      _preloadNextPage(page + 1);
    }
  }

  Future<void> _preloadNextPage(int page) async {
    if (page < 0 || page >= _totalPages) return;
    final snapshot = _categoryLuts;
    final luts = _lutsOnPage(page);
    final entries = await _generateEntries(luts);
    if (mounted && identical(snapshot, _categoryLuts)) {
      _nextPageThumbs = entries;
    }
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
      if (page + 1 < _totalPages) _preloadNextPage(page + 1);
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


  Widget _smallIconButton(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: Colors.white,
      disabledColor: Colors.white24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      onPressed: onPressed,
    );
  }

  List<Widget> _buildPager() => [
        _smallIconButton(Icons.chevron_left,
            _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null),
        Text('Page ${_currentPage + 1} / $_totalPages',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        _smallIconButton(
            Icons.chevron_right,
            _currentPage < _totalPages - 1
                ? () => _goToPage(_currentPage + 1)
                : null),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 26,
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 12),
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Go',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              isDense: true,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.white24),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: Colors.amber),
              ),
            ),
            onSubmitted: (val) {
              final pg = int.tryParse(val);
              if (pg != null) _goToPage(pg - 1);
            },
          ),
        ),
      ];

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 4, 0),
      child: Row(
        children: [
          const Text('LUT Picker',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text('${_categoryLuts.length} LUTs',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          if (_totalPages > 1) ...[
            const SizedBox(width: 12),
            ..._buildPager(),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _selectedLutName == null
                  ? const SizedBox()
                  : Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'Selected: ${_selectedLutName!.replaceAll('.cube', '')}',
                        style:
                            const TextStyle(color: Colors.amber, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              widget.onLutSelected(null);
              Navigator.of(context).pop();
            },
            child: const Text('No LUT',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          _smallIconButton(Icons.close, () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  Widget _buildCategoryBar() {
    final visible = _visibleGroups;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final c in kLutCategories)
            _CategoryChip(
              label: c == 'Favorites' ? '★ Favorites' : c,
              selected: _selectedCategory == c,
              highlighted: visible.contains(c),
              tooltip: _groupInfo[c] == null
                  ? null
                  : 'Starts at page ${_groupInfo[c]!.page} in All'
                    ' · ${_groupInfo[c]!.count} LUTs',
              onTap: () => setState(() {
                _selectedCategory = c;
                _rebuildCategory();
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (!_serviceReady) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_categoryLuts.isEmpty) {
      return const Center(
        child: Text('No LUTs in this category',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      const pad = 6.0, gap = 4.0;
      // Size cells so exactly 2 rows x 3 columns fill the space, titles included
      final cellW = (constraints.maxWidth - pad * 2 - gap * 2) / 3;
      final cellH = (constraints.maxHeight - pad * 2 - gap - 1) / 2;
      final ratio = (cellW > 0 && cellH > 0) ? cellW / cellH : 16 / 11;

      return Stack(
        children: [
          GridView.builder(
            padding: const EdgeInsets.all(pad),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: gap,
              mainAxisSpacing: gap,
              childAspectRatio: ratio,
            ),
            itemCount: _thumbs.isEmpty ? 6 : _thumbs.length,
            itemBuilder: (context, index) {
              if (_thumbs.isEmpty || _loadingPage) return _buildLoadingCell();
              if (index >= _thumbs.length) return const SizedBox();
              return _buildThumbCell(_thumbs[index]);
            },
          ),
          if (_loadingPage)
            const Center(child: CircularProgressIndicator(color: Colors.amber)),
        ],
      );
    });
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
}


class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final String? tooltip;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.highlighted = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected || highlighted;

    final chip = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? Colors.amber
              : highlighted
                  ? Colors.lightBlueAccent
                  : Colors.white10,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );

    if (tooltip == null) return chip;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 250),
      child: chip,
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
