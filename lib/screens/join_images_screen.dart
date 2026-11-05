// lib/screens/join_images_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:avif_native/avif_native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

const _rasterExts = {'.jpg', '.jpeg', '.png', '.webp', '.avif', '.gif', '.bmp'};
const _maxCanvasDim = 16384;

/// Top-level on purpose: the closure passed to Isolate.run must not capture
/// the State object (which holds dart:ui Images that can't be sent).
Future<Uint8List> _encodeInIsolate(
    TransferableTypedData ttd, int fw, int fh, String format, int threads) {
  return Isolate.run<Uint8List>(() {
    final rgba = ttd.materialize().asUint8List();
    if (format == 'avif') {
      return encodeAvifFrames(
        width: fw,
        height: fh,
        frames: [
          AvifEncodeFrame(rgba: rgba, duration: const Duration(milliseconds: 100))
        ],
        options: AvifEncodeOptions(
          speed: 8,
          minQuantizer: 32, // quality 50
          maxQuantizer: 32,
          maxThreads: threads,
        ),
      );
    }
    final im = img.Image.fromBytes(
        width: fw, height: fh, bytes: rgba.buffer, numChannels: 4);
    return Uint8List.fromList(img.encodeJpg(im, quality: 85));
  });
}

// ───────────────────────── tour editor (zoom + slideshow sections) ─────────────────────────

/// (label, width, height)
const _tourRatios = <(String, int, int)>[
  ('16:9', 16, 9),
  ('3:2', 3, 2),
  ('4:3', 4, 3),
  ('1:1', 1, 1),
  ('4:5', 4, 5),
  ('3:4', 3, 4),
  ('9:16', 9, 16),
  ('21:9', 21, 9),
];

/// A zoom area: centre (cx, cy) and visible width w, all as 0..1 of the image.
/// Height is derived from the chosen aspect ratio.
class _TourStop {
  double cx, cy, w;
  String desc; // optional caption shown while this zoom area is on screen
  _TourStop(this.cx, this.cy, this.w, [this.desc = '']);
}

enum _PageKind { combined, source, file }

/// A section is either a zoom tour (each image has zoom areas) or a
/// slideshow (images cross-fade as you scroll).
enum _SecKind { zoom, slideshow }

/// One image of a section. [stops] only matter in zoom sections; [desc] is an
/// optional caption (blank = the section header is used instead).
class _TourPage {
  final _PageKind kind;
  final int? srcId; // _Src.id for kind == source
  final String? path; // file path for kind == file
  final String name;
  final ui.Image image; // used for display in the editor only
  final List<_TourStop> stops;
  String desc;
  _TourPage({
    required this.kind,
    this.srcId,
    this.path,
    required this.name,
    required this.image,
    List<_TourStop>? stops,
    this.desc = '',
  }) : stops = stops ?? [];

  /// Independent copy (own zoom areas); shares the decoded image.
  _TourPage clone() => _TourPage(
        kind: kind,
        srcId: srcId,
        path: path,
        name: name,
        image: image,
        stops: [for (final s in stops) _TourStop(s.cx, s.cy, s.w, s.desc)],
        desc: desc,
      );
}

/// Editor-side state of one section.
class _Section {
  final _SecKind kind;
  final List<_TourPage> pages;
  final TextEditingController header = TextEditingController();
  int ratioIdx = 0;
  bool overview = true;
  double vh = 100;
  double hold = 0.15;
  int cur = 0; // selected image (zoom sections)
  int? sel; // selected zoom area on that image

  _Section(this.kind, {List<_TourPage>? pages}) : pages = pages ?? [] {
    hold = kind == _SecKind.zoom ? 0.15 : 0.25;
  }

  void dispose() => header.dispose();
}

/// Immutable snapshot of a section, handed to the exporter.
class _SecConfig {
  final _SecKind kind;
  final String header;
  final List<_TourPage> pages;
  final int arW, arH;
  final String arLabel;
  final double vh;
  final double hold;
  final bool overview;
  const _SecConfig({
    required this.kind,
    required this.header,
    required this.pages,
    required this.arW,
    required this.arH,
    required this.arLabel,
    required this.vh,
    required this.hold,
    required this.overview,
  });
}

class _TourConfig {
  final List<_SecConfig> sections;
  final String format;
  const _TourConfig({required this.sections, required this.format});
}

class _ExportResult {
  final bool ok;
  final String message;
  final String? path; // index.html when ok
  const _ExportResult.ok(this.message, this.path) : ok = true;
  const _ExportResult.fail(this.message)
      : ok = false,
        path = null;
}

/// "Add from the joined images" picker. [countOf] says how many times an
/// image is already in the target; [onAdd] adds one more.
Future<void> _showJoinedPicker(
  BuildContext context, {
  required ui.Image combined,
  required List<_Src> sources,
  required int Function(_PageKind kind, int? srcId) countOf,
  required void Function(_TourPage page) onAdd,
}) {
  const green = Color(0xFF00FF26);
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
      Widget tile(String label, ui.Image im, _PageKind k, int? id) {
        final n = countOf(k, id);
        return Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              onAdd(_TourPage(kind: k, srcId: id, name: label, image: im));
              setD(() {});
            },
            child: Stack(fit: StackFit.expand, children: [
              Container(
                decoration: BoxDecoration(
                    border: Border.all(color: n > 0 ? green : Colors.white24, width: 2),
                    borderRadius: BorderRadius.circular(6)),
                clipBehavior: Clip.antiAlias,
                child: RawImage(image: im, fit: BoxFit.cover),
              ),
              if (n > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                      radius: 10,
                      backgroundColor: green,
                      child: Text('$n',
                          style: const TextStyle(fontSize: 11, color: Colors.black))),
                ),
            ]),
          ),
        );
      }

      return AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Add images (tap to add, tap again to repeat)'),
        content: SizedBox(
          width: 600,
          height: 420,
          child: GridView.extent(
            maxCrossAxisExtent: 110,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              tile('Combined image', combined, _PageKind.combined, null),
              for (final s in sources) tile(s.name, s.image, _PageKind.source, s.id),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
        ],
      );
    }),
  );
}

class _TourEditor extends StatefulWidget {
  /// The joined (combined) image preview.
  final ui.Image combined;

  /// The individual images loaded in the Join Images screen.
  final List<_Src> sources;
  final Future<List<String>> Function() pickFiles;
  final Future<ui.Image> Function(String path) decode;

  /// Runs the export. The editor stays open afterwards.
  final Future<_ExportResult> Function(_TourConfig cfg) onExport;
  final Future<void> Function(String path) onOpenFile;
  final Future<void> Function(String dir) onOpenFolder;

  /// Progress text while exporting.
  final ValueListenable<String?> status;
  const _TourEditor({
    required this.combined,
    required this.sources,
    required this.pickFiles,
    required this.decode,
    required this.onExport,
    required this.onOpenFile,
    required this.onOpenFolder,
    required this.status,
  });

  @override
  State<_TourEditor> createState() => _TourEditorState();
}

class _TourEditorState extends State<_TourEditor> {
  static const _green = Color(0xFF00FF26);

  final List<_Section> _secs = [];
  final List<ui.Image> _owned = []; // decoded from picked files; freed with the editor
  final Map<_TourPage, TextEditingController> _descCtl = {};
  final Map<_TourStop, TextEditingController> _stopCtl = {};
  int? _hoverPage; // zoom thumbnail under the mouse (shows its remove button)
  int _si = 0;
  double? _lastW; // size of the zoom area last drawn / resized; new areas reuse it
  bool _copyOnAdd = true;
  bool _addingFiles = false;
  bool _busy = false;
  _ExportResult? _result;
  String _format = 'avif';

  Rect _imgRect = Rect.zero;
  bool _drawing = false;
  int? _moving;
  int? _resizing;
  int _hx = 0, _vy = 0; // which edge(s) are being dragged: -1 / 0 / 1
  Offset _grab = Offset.zero;
  Offset _anchor = Offset.zero;
  MouseCursor _cursor = SystemMouseCursors.precise;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _secs.add(_newZoomSection(withCombined: true));
  }

  @override
  void dispose() {
    _focus.dispose();
    for (final i in _owned) {
      i.dispose();
    }
    for (final c in _descCtl.values) {
      c.dispose();
    }
    for (final c in _stopCtl.values) {
      c.dispose();
    }
    for (final s in _secs) {
      s.dispose();
    }
    super.dispose();
  }

  _TourPage _combinedPage() =>
      _TourPage(kind: _PageKind.combined, name: 'Combined image', image: widget.combined);

  _Section _newZoomSection({bool withCombined = false}) =>
      _Section(_SecKind.zoom, pages: [if (withCombined) _combinedPage()]);

  /// A new slideshow starts with every loaded image, in the current order.
  _Section _newSlideSection() {
    final pages = <_TourPage>[
      for (final s in widget.sources)
        _TourPage(kind: _PageKind.source, srcId: s.id, name: s.name, image: s.image)
    ];
    if (pages.isEmpty) pages.add(_combinedPage());
    return _Section(_SecKind.slideshow, pages: pages);
  }

  // ── current section / page helpers ──

  _Section get _sec => _secs[_si];
  bool get _isZoom => _sec.kind == _SecKind.zoom;
  int get _cur => _sec.cur;
  int? get _sel => _sec.sel;
  set _sel(int? v) => _sec.sel = v;

  _TourPage get _page => _sec.pages[_sec.cur];
  List<_TourStop> get _stops => _page.stops;
  ui.Image get _img => _page.image;
  double get _iw => _img.width.toDouble();
  double get _ih => _img.height.toDouble();
  double get _ar => _tourRatios[_sec.ratioIdx].$2 / _tourRatios[_sec.ratioIdx].$3;
  double _maxWFor(_TourPage pg) => min(1.0, _ar * pg.image.height / pg.image.width);
  double get _maxW => _maxWFor(_page);
  double get _minW => min(0.03, _maxW * 0.5);
  double _hN(double w, [_TourPage? pg]) {
    final im = (pg ?? _page).image;
    return w * im.width / (im.height * _ar);
  }

  double _cl(double v, double lo, double hi) =>
      hi < lo ? (lo + hi) / 2 : v.clamp(lo, hi).toDouble();

  /// Keeps a box inside its image at the current aspect ratio.
  void _clampStop(_TourStop s, [_TourPage? pg]) {
    final page = pg ?? _page;
    final mx = _maxWFor(page);
    final mn = min(0.03, mx * 0.5);
    s.w = _cl(s.w, mn, mx);
    s.cx = _cl(s.cx, s.w / 2, 1 - s.w / 2);
    final h = _hN(s.w, page);
    s.cy = _cl(s.cy, h / 2, 1 - h / 2);
  }

  TextEditingController _ctl(_TourPage pg) =>
      _descCtl.putIfAbsent(pg, () => TextEditingController(text: pg.desc));

  TextEditingController _stopCtlFor(_TourStop st) =>
      _stopCtl.putIfAbsent(st, () => TextEditingController(text: st.desc));

  void _resetInteraction() {
    _drawing = false;
    _moving = null;
    _resizing = null;
  }

  // ── sections ──

  void _selectSection(int i) => setState(() {
        _si = i;
        _resetInteraction();
      });

  void _addSection(_SecKind k) => setState(() {
        _secs.add(k == _SecKind.zoom ? _newZoomSection() : _newSlideSection());
        _si = _secs.length - 1;
        _resetInteraction();
      });

  void _removeSection(int i) {
    if (_secs.length <= 1) return;
    setState(() {
      _secs.removeAt(i).dispose();
      if (i < _si || _si >= _secs.length) _si = max(0, _si - 1);
      _resetInteraction();
    });
  }

  void _moveSection(int dir) {
    final j = _si + dir;
    if (j < 0 || j >= _secs.length) return;
    setState(() {
      final t = _secs[_si];
      _secs[_si] = _secs[j];
      _secs[j] = t;
      _si = j;
    });
  }

  void _duplicateSection() => setState(() {
        final s = _sec;
        final c = _Section(s.kind, pages: [for (final pg in s.pages) pg.clone()])
          ..header.text = s.header.text
          ..ratioIdx = s.ratioIdx
          ..overview = s.overview
          ..vh = s.vh
          ..hold = s.hold;
        _secs.insert(_si + 1, c);
        _si++;
        _resetInteraction();
      });

  // ── pages (images) of the current section ──

  void _selectPage(int i) {
    setState(() {
      _sec.cur = i;
      _sel = null;
      _resetInteraction();
    });
  }

  _TourStop _copyOf(_TourStop s, _TourPage dst) {
    final c = _TourStop(s.cx, s.cy, s.w);
    _clampStop(c, dst);
    return c;
  }

  /// Adds [pg] to the current section. In a zoom section it starts from a copy
  /// of the previous image's zoom areas (if enabled) so the same move can be reused.
  void _addPage(_TourPage pg) {
    final s = _sec;
    if (s.kind == _SecKind.zoom) {
      if (_copyOnAdd && s.pages.isNotEmpty) {
        pg.stops.addAll([for (final z in s.pages.last.stops) _copyOf(z, pg)]);
      }
      s.pages.add(pg);
      s.cur = s.pages.length - 1;
      s.sel = null;
    } else {
      s.pages.add(pg);
    }
  }

  void _removePage(int i) {
    final s = _sec;
    setState(() {
      _hoverPage = null;
      s.pages.removeAt(i);
      if (s.cur >= s.pages.length) {
        s.cur = max(0, s.pages.length - 1);
      } else if (i < s.cur) {
        s.cur--;
      }
      s.sel = null;
    });
  }

  void _movePage(int i, int dir) {
    final s = _sec;
    final j = i + dir;
    if (j < 0 || j >= s.pages.length) return;
    setState(() {
      final t = s.pages[i];
      s.pages[i] = s.pages[j];
      s.pages[j] = t;
      if (s.cur == i) {
        s.cur = j;
      } else if (s.cur == j) {
        s.cur = i;
      }
    });
  }

  void _copyStops(int from, int to) {
    final src = _sec.pages[from], dst = _sec.pages[to];
    dst.stops
      ..clear()
      ..addAll([for (final s in src.stops) _copyOf(s, dst)]);
  }

  Future<void> _addFromJoined() => _showJoinedPicker(
        context,
        combined: widget.combined,
        sources: widget.sources,
        countOf: (k, id) =>
            _sec.pages.where((pg) => pg.kind == k && pg.srcId == id).length,
        onAdd: (pg) => setState(() => _addPage(pg)),
      );

  Future<void> _addFiles() async {
    if (_addingFiles) return;
    final target = _sec; // the section that was open when the button was pressed
    setState(() => _addingFiles = true);
    try {
      final paths = await widget.pickFiles();
      for (final path in paths) {
        final im = await widget.decode(path);
        if (!mounted) {
          im.dispose();
          return;
        }
        _owned.add(im);
        final pg = _TourPage(
            kind: _PageKind.file, path: path, name: p.basename(path), image: im);
        setState(() {
          if (identical(target, _sec)) {
            _addPage(pg);
          } else {
            target.pages.add(pg);
          }
        });
      }
    } catch (e) {
      debugPrint('Could not add image: $e');
    } finally {
      if (mounted) setState(() => _addingFiles = false);
    }
  }

  // ── keyboard ──

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Only when the image area has focus (not while typing in a text field).
    if (!node.hasPrimaryFocus || !_isZoom || _sec.pages.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.delete)) {
      final i = _sel;
      if (i != null && i < _stops.length) {
        setState(() {
          _stops.removeAt(i);
          _sel = null;
        });
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // ── box hit-testing / editing ──

  Offset _toNorm(Offset local) => Offset((local.dx - _imgRect.left) / _imgRect.width,
      (local.dy - _imgRect.top) / _imgRect.height);

  bool _inside(Offset n) => n.dx >= 0 && n.dx <= 1 && n.dy >= 0 && n.dy <= 1;

  /// Finds the box under [n]. Returns (stop index, hx, vy) where hx / vy say
  /// which edge(s) are grabbed (-1 left/top, 1 right/bottom, 0 none);
  /// (i, 0, 0) means the inside of the box (move).
  (int, int, int)? _pickAt(Offset n) {
    (int, int, int)? test(int i) {
      final s = _stops[i];
      final h = _hN(s.w);
      final l = s.cx - s.w / 2, r = s.cx + s.w / 2;
      final t = s.cy - h / 2, b = s.cy + h / 2;
      final tx = min(9 / _imgRect.width, s.w / 3); // ~9px grab zone
      final ty = min(9 / _imgRect.height, h / 3);
      if (n.dx < l - tx || n.dx > r + tx || n.dy < t - ty || n.dy > b + ty) {
        return null;
      }
      final hx = (n.dx - l).abs() <= tx ? -1 : ((n.dx - r).abs() <= tx ? 1 : 0);
      final vy = (n.dy - t).abs() <= ty ? -1 : ((n.dy - b).abs() <= ty ? 1 : 0);
      return (i, hx, vy);
    }

    // The selected box's edges win over boxes stacked on top of it.
    final sel = _sel;
    if (sel != null && sel < _stops.length) {
      final r = test(sel);
      if (r != null && (r.$2 != 0 || r.$3 != 0)) return r;
    }
    for (var i = _stops.length - 1; i >= 0; i--) {
      final r = test(i);
      if (r != null) return r;
    }
    return null;
  }

  void _beginResize(int i, int hx, int vy) {
    final s = _stops[i];
    final h = _hN(s.w);
    // Fixed point = the opposite corner / edge (centre line for pure edge drags).
    final ax = hx < 0 ? s.cx + s.w / 2 : (hx > 0 ? s.cx - s.w / 2 : s.cx);
    final ay = vy < 0 ? s.cy + h / 2 : (vy > 0 ? s.cy - h / 2 : s.cy);
    _anchor = Offset(ax, ay);
    _resizing = i;
    _hx = hx;
    _vy = vy;
  }

  /// Resizes a box from the grabbed edge / corner, aspect ratio locked.
  void _applyResize(_TourStop s, Offset n) {
    final a = _anchor;
    final c = Offset(n.dx.clamp(0.0, 1.0).toDouble(), n.dy.clamp(0.0, 1.0).toDouble());
    final toW = _ih * _ar / _iw; // height -> width
    double w, lim;
    if (_hx != 0 && _vy != 0) {
      w = max((c.dx - a.dx) * _hx, (c.dy - a.dy) * _vy * toW);
      lim = min(_maxW, min(_hx > 0 ? 1 - a.dx : a.dx, (_vy > 0 ? 1 - a.dy : a.dy) * toW));
    } else if (_hx != 0) {
      w = (c.dx - a.dx) * _hx;
      lim = min(_maxW,
          min(_hx > 0 ? 1 - a.dx : a.dx, 2 * min(a.dy, 1 - a.dy) * toW));
    } else {
      w = (c.dy - a.dy) * _vy * toW;
      lim = min(_maxW,
          min((_vy > 0 ? 1 - a.dy : a.dy) * toW, 2 * min(a.dx, 1 - a.dx)));
    }
    w = max(_minW, min(w, lim));
    s.w = w;
    s.cx = _hx != 0 ? a.dx + _hx * w / 2 : a.dx;
    s.cy = _vy != 0 ? a.dy + _vy * _hN(w) / 2 : a.dy;
    _clampStop(s);
  }

  MouseCursor _cursorFor(Offset local) {
    final r = _pickAt(_toNorm(local));
    if (r == null) return SystemMouseCursors.precise;
    final hx = r.$2, vy = r.$3;
    if (hx != 0 && vy != 0) {
      return hx == vy
          ? SystemMouseCursors.resizeUpLeftDownRight
          : SystemMouseCursors.resizeUpRightDownLeft;
    }
    if (hx != 0) return SystemMouseCursors.resizeLeftRight;
    if (vy != 0) return SystemMouseCursors.resizeUpDown;
    return SystemMouseCursors.move;
  }

  void _onTap(Offset local) {
    _focus.requestFocus();
    final n = _toNorm(local);
    final pick = _pickAt(n);
    if (pick == null && !_inside(n)) return;
    final hit = pick?.$1;
    setState(() {
      if (hit != null) {
        _sel = hit;
      } else {
        final s = _TourStop(n.dx, n.dy, _lastW ?? min(0.25, _maxW));
        _clampStop(s);
        _stops.add(s);
        _sel = _stops.length - 1;
      }
    });
  }

  void _onPanStart(Offset local) {
    _focus.requestFocus();
    final n = _toNorm(local);
    final pick = _pickAt(n);
    if (pick == null && !_inside(n)) return;
    final hit = pick?.$1;
    setState(() {
      if (hit != null) {
        _sel = hit;
        if (pick!.$2 != 0 || pick.$3 != 0) {
          _beginResize(hit, pick.$2, pick.$3);
        } else {
          _moving = hit;
          _grab = Offset(n.dx - _stops[hit].cx, n.dy - _stops[hit].cy);
        }
      } else {
        _drawing = true;
        _anchor = n;
        _stops.add(_TourStop(n.dx, n.dy, 0.001));
        _sel = _stops.length - 1;
      }
    });
  }

  void _onPanUpdate(Offset local) {
    final n = _toNorm(local);
    setState(() {
      if (_drawing) {
        _resize(_stops.last, n);
      } else if (_resizing != null && _resizing! < _stops.length) {
        _applyResize(_stops[_resizing!], n);
      } else if (_moving != null && _moving! < _stops.length) {
        final s = _stops[_moving!];
        s.cx = n.dx - _grab.dx;
        s.cy = n.dy - _grab.dy;
        _clampStop(s);
      }
    });
  }

  /// Drag-to-draw with the aspect ratio locked: the corner follows the pointer.
  void _resize(_TourStop s, Offset n) {
    final a = _anchor;
    final c = Offset(n.dx.clamp(0.0, 1.0).toDouble(), n.dy.clamp(0.0, 1.0).toDouble());
    final sx = c.dx >= a.dx ? 1.0 : -1.0;
    final sy = c.dy >= a.dy ? 1.0 : -1.0;
    final availX = sx > 0 ? 1 - a.dx : a.dx;
    final availY = sy > 0 ? 1 - a.dy : a.dy;
    final toW = _ih * _ar / _iw; // height -> width
    var w = max((c.dx - a.dx).abs(), (c.dy - a.dy).abs() * toW);
    w = min(w, min(_maxW, min(availX, availY * toW)));
    w = max(w, 0.001);
    s.w = w;
    s.cx = a.dx + sx * w / 2;
    s.cy = a.dy + sy * _hN(w) / 2;
  }

  void _onPanEnd() {
    setState(() {
      if (_drawing && _stops.isNotEmpty && _stops.last.w < 0.04) {
        _stops.removeLast(); // accidental tiny drag
        _sel = null;
      } else if (_drawing || _resizing != null) {
        final i = _drawing ? _stops.length - 1 : _resizing!;
        if (i >= 0 && i < _stops.length) _lastW = _stops[i].w;
      }
      _resetInteraction();
    });
  }

  void _setRatio(int i) {
    setState(() {
      _sec.ratioIdx = i;
      for (final pg in _sec.pages) {
        for (final s in pg.stops) {
          _clampStop(s, pg);
        }
      }
    });
  }

  void _swap(int i, int j) {
    setState(() {
      final t = _stops[i];
      _stops[i] = _stops[j];
      _stops[j] = t;
      _sel = j;
    });
  }

  // ── export (the editor stays open) ──

  _TourConfig _config() => _TourConfig(
        format: _format,
        sections: [
          for (final s in _secs)
            if (s.pages.isNotEmpty)
              _SecConfig(
                kind: s.kind,
                header: s.header.text.trim(),
                pages: [for (final pg in s.pages) pg.clone()],
                arW: _tourRatios[s.ratioIdx].$2,
                arH: _tourRatios[s.ratioIdx].$3,
                arLabel: _tourRatios[s.ratioIdx].$1,
                vh: s.vh,
                hold: s.hold,
                overview: s.overview,
              )
        ],
      );

  Future<void> _export() async {
    if (_busy) return;
    final cfg = _config();
    if (cfg.sections.isEmpty) return;
    setState(() {
      _busy = true;
      _result = null;
    });
    _ExportResult res;
    try {
      res = await widget.onExport(cfg);
    } catch (e) {
      res = _ExportResult.fail('Export failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = res;
    });
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final total = _secs.fold<int>(0, (a, s) => a + s.pages.length);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(
              'Scroll Page  •  ${_secs.length} section${_secs.length == 1 ? '' : 's'}, $total image${total == 1 ? '' : 's'}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: total > 0 && !_busy ? _export : null,
                icon: const Icon(Icons.code),
                label: Text(_busy ? 'Exporting…' : 'Export HTML'),
              ),
            ),
          ],
        ),
        body: Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Column(
            children: [
              _sectionBar(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _isZoom
                          ? Column(children: [
                              Expanded(child: _imageArea()),
                              _strip(),
                            ])
                          : _slideList(),
                    ),
                    Container(width: 310, color: const Color(0xFF2D2D2D), child: _panel()),
                  ],
                ),
              ),
              _statusBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionBar() => Container(
        height: 52,
        color: const Color(0xFF252525),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _secs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _secTab(i),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _addSection(_SecKind.zoom),
            icon: const Icon(Icons.zoom_in, size: 16),
            label: const Text('Add zoom section'),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => _addSection(_SecKind.slideshow),
            icon: const Icon(Icons.slideshow, size: 16),
            label: const Text('Add slideshow section'),
          ),
        ]),
      );

  Widget _secTab(int i) {
    final s = _secs[i];
    final selected = i == _si;
    final kind = s.kind == _SecKind.zoom ? 'Zoom' : 'Slideshow';
    return OutlinedButton(
      onPressed: () => _selectSection(i),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0x3300FF26) : null,
        side: BorderSide(color: selected ? _green : Colors.white24),
        foregroundColor: selected ? _green : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(0, 34),
      ),
      child: Text('${i + 1}  $kind (${s.pages.length})'),
    );
  }

  Widget _statusBar() {
    if (!_busy && _result == null) return const SizedBox.shrink();
    final r = _result;
    return Container(
      width: double.infinity,
      color: const Color(0xFF252525),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: _busy
          ? ValueListenableBuilder<String?>(
              valueListenable: widget.status,
              builder: (_, v, __) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v ?? 'Exporting…',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  const LinearProgressIndicator(),
                ],
              ),
            )
          : Row(children: [
              Expanded(
                child: SelectableText(r!.message,
                    style: TextStyle(
                        color: r.ok ? _green : Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              if (r.path != null) ...[
                TextButton(
                    onPressed: () => widget.onOpenFile(r.path!),
                    child: const Text('Open page')),
                TextButton(
                    onPressed: () => widget.onOpenFolder(p.dirname(r.path!)),
                    child: const Text('Open folder')),
              ],
              IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Dismiss',
                  onPressed: () => setState(() => _result = null),
                  icon: const Icon(Icons.close, size: 18)),
            ]),
    );
  }

  // ── zoom section: image area + strip ──

  Widget _imageArea() {
    if (_sec.pages.isEmpty) {
      return const Center(
          child: Text('No images in this section yet. Add some below.',
              style: TextStyle(color: Colors.white38)));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(builder: (ctx, c) {
        final scale = min(c.maxWidth / _iw, c.maxHeight / _ih);
        final w = _iw * scale, h = _ih * scale;
        _imgRect = Rect.fromLTWH((c.maxWidth - w) / 2, (c.maxHeight - h) / 2, w, h);
        return MouseRegion(
          cursor: _cursor,
          onHover: (e) {
            if (_drawing || _moving != null || _resizing != null) return;
            final cur = _cursorFor(e.localPosition);
            if (cur != _cursor) setState(() => _cursor = cur);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(d.localPosition),
            onPanStart: (d) => _onPanStart(d.localPosition),
            onPanUpdate: (d) => _onPanUpdate(d.localPosition),
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: _onPanEnd,
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: _imgRect,
                  child: RawImage(
                      image: _img,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium),
                ),
                Positioned.fill(
                  child: CustomPaint(
                      painter: _TourPainter(_stops, _sel, _imgRect, _ar, _iw, _ih)),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Thumbnails of the section's images (in order) plus the add buttons.
  Widget _strip() => Container(
        height: 98,
        color: const Color(0xFF252525),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sec.pages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _pageThumb(i),
            ),
          ),
          const SizedBox(width: 10),
          _addButtons(vertical: true),
        ]),
      );

  Widget _addButtons({required bool vertical}) {
    final a = OutlinedButton.icon(
      onPressed: _addFromJoined,
      icon: const Icon(Icons.add_photo_alternate, size: 16),
      label: const Text('From joined images'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
    );
    final b = OutlinedButton.icon(
      onPressed: _addingFiles ? null : _addFiles,
      icon: const Icon(Icons.folder_open, size: 16),
      label: const Text('From files…'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
    );
    return vertical
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [a, const SizedBox(height: 4), b])
        : Wrap(spacing: 8, runSpacing: 6, children: [a, b]);
  }

  Widget _pageThumb(int i) {
    final pg = _sec.pages[i];
    final selected = i == _cur;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverPage = i),
      onExit: (_) => setState(() {
        if (_hoverPage == i) _hoverPage = null;
      }),
      child: GestureDetector(
      onTap: () => _selectPage(i),
      child: Tooltip(
        message: pg.name,
        child: SizedBox(
          width: 100,
          child: Stack(fit: StackFit.expand, children: [
            Container(
              decoration: BoxDecoration(
                  border: Border.all(
                      color: selected ? _green : Colors.white24, width: selected ? 3 : 1),
                  borderRadius: BorderRadius.circular(6)),
              clipBehavior: Clip.antiAlias,
              child: RawImage(
                  image: pg.image, fit: BoxFit.cover, filterQuality: FilterQuality.low),
            ),
            Positioned(
              left: 4,
              bottom: 4,
              child: CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF29B6F6),
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.white))),
            ),
            if (_hoverPage == i)
              Positioned(
                right: 3,
                top: 3,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _removePage(i),
                  child: const Tooltip(
                    message: 'Remove image',
                    child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Color(0xFFEF4444),
                        child: Icon(Icons.close, size: 13, color: Colors.white)),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Text('${pg.stops.length} zoom${pg.stops.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    ));
  }

  // ── slideshow section: list of images with descriptions ──

  Widget _slideList() {
    final pages = _sec.pages;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
              'Each image is shown full-size and cross-fades to the next one as you scroll. '
              'After the last image the page scrolls on to the next section.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
        if (pages.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('No images yet. Add some below.',
                style: TextStyle(color: Colors.white38)),
          ),
        for (var i = 0; i < pages.length; i++) _slideRow(i),
        _addButtons(vertical: false),
      ],
    );
  }

  Widget _slideRow(int i) {
    final pg = _sec.pages[i];
    final pages = _sec.pages;
    final fallback = _sec.header.text.trim();
    return Container(
      key: ObjectKey(pg),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration:
          BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 150,
          height: 100,
          child: Stack(fit: StackFit.expand, children: [
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(6)),
              clipBehavior: Clip.antiAlias,
              child: RawImage(
                  image: pg.image, fit: BoxFit.cover, filterQuality: FilterQuality.low),
            ),
            Positioned(
              left: 4,
              top: 4,
              child: CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF29B6F6),
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.white))),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pg.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _ctl(pg),
              onChanged: (v) => pg.desc = v,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: 'Description (optional)',
                hintText: fallback.isEmpty
                    ? 'Blank = no caption'
                    : 'Blank = section header: $fallback',
                hintMaxLines: 1,
                hintStyle: const TextStyle(color: Colors.white30),
              ),
            ),
          ]),
        ),
        Column(children: [
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Move up',
              onPressed: i > 0 ? () => _movePage(i, -1) : null,
              icon: const Icon(Icons.arrow_upward, size: 18)),
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Move down',
              onPressed: i < pages.length - 1 ? () => _movePage(i, 1) : null,
              icon: const Icon(Icons.arrow_downward, size: 18)),
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove image',
              onPressed: () => _removePage(i),
              icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444))),
        ]),
      ]),
    );
  }

  // ── right panel ──

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t,
            style: const TextStyle(
                color: _green, fontWeight: FontWeight.bold, fontSize: 14)),
      );

  Widget _slider(String label, double v, double lo, double hi, ValueChanged<double> cb) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Slider(value: v.clamp(lo, hi).toDouble(), min: lo, max: hi, onChanged: cb),
        ],
      );

  Widget _smallBtn(String label, VoidCallback? onTap) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 32),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );

  Widget _panel() {
    final s = _sec;
    return ListView(
      key: ValueKey(s), // fresh scroll position per section
      padding: const EdgeInsets.all(14),
      children: [
        _label('Section ${_si + 1}: ${_isZoom ? 'Zoom' : 'Slideshow'}'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _smallBtn('◀ Move', _si > 0 ? () => _moveSection(-1) : null),
          _smallBtn('Move ▶', _si < _secs.length - 1 ? () => _moveSection(1) : null),
          _smallBtn('Duplicate', _duplicateSection),
          _smallBtn('Delete section', _secs.length > 1 ? () => _removeSection(_si) : null),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: s.header,
          onChanged: (_) => setState(() {}),
          minLines: 1,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            labelText: 'Section header (optional)',
            helperText: 'Shown on images of this section that have no description of their own',
            helperMaxLines: 3,
          ),
        ),
        if (_isZoom) ..._zoomPanel() else ..._slidePanel(),
        _label('Image format (whole export)'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'avif', label: Text('AVIF')),
            ButtonSegment(value: 'jpg', label: Text('JPG')),
          ],
          selected: {_format},
          onSelectionChanged: (v) => setState(() => _format = v.first),
        ),
      ],
    );
  }

  List<Widget> _slidePanel() {
    final s = _sec;
    return [
      _label('Scrolling'),
      _slider('Scroll per image: ${s.vh.round()} vh', s.vh, 40, 250,
          (v) => setState(() => s.vh = v)),
      _slider('Pause on each image: ${(s.hold * 100).round()}%', s.hold, 0, 0.4,
          (v) => setState(() => s.hold = v)),
    ];
  }

  List<Widget> _zoomPanel() {
    final s = _sec;
    if (s.pages.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text('No images in this section. Use the buttons under the image area to add some.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ];
    }
    final pg = _page;
    final sel = _sel != null && _sel! < _stops.length ? _stops[_sel!] : null;
    final last = s.pages.length - 1;
    final fallback = s.header.text.trim();
    return [
      _label('Image ${_cur + 1} of ${s.pages.length}'),
      Text(pg.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _smallBtn('◀ Move', _cur > 0 ? () => _movePage(_cur, -1) : null),
        _smallBtn('Move ▶', _cur < last ? () => _movePage(_cur, 1) : null),
        _smallBtn('Remove image', () => _removePage(_cur)),
      ]),
      const SizedBox(height: 10),
      TextField(
        key: ObjectKey(pg),
        controller: _ctl(pg),
        onChanged: (v) => pg.desc = v,
        minLines: 1,
        maxLines: 3,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: 'Description (optional)',
          hintText: fallback.isEmpty ? 'Blank = no caption' : 'Blank = section header',
          hintStyle: const TextStyle(color: Colors.white30),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _smallBtn(
            'Copy zooms from previous image',
            _cur > 0
                ? () => setState(() {
                      _copyStops(_cur - 1, _cur);
                      _sel = null;
                    })
                : null),
        _smallBtn(
            'Apply these zooms to all following',
            _cur < last
                ? () => setState(() {
                      for (var j = _cur + 1; j <= last; j++) {
                        _copyStops(_cur, j);
                      }
                    })
                : null),
      ]),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        value: _copyOnAdd,
        onChanged: (v) => setState(() => _copyOnAdd = v ?? true),
        title: const Text('New images start with a copy of the previous image’s zooms',
            style: TextStyle(color: Colors.white, fontSize: 12)),
      ),
      _label('Aspect ratio (locked, this section)'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var i = 0; i < _tourRatios.length; i++)
          OutlinedButton(
            onPressed: () => _setRatio(i),
            style: OutlinedButton.styleFrom(
              backgroundColor: i == s.ratioIdx ? const Color(0x3300FF26) : null,
              side: BorderSide(color: i == s.ratioIdx ? _green : Colors.white24),
              foregroundColor: i == s.ratioIdx ? _green : null,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              minimumSize: const Size(0, 34),
            ),
            child: Text(_tourRatios[i].$1),
          ),
      ]),
      const SizedBox(height: 6),
      const Text(
          'Click the image to add a zoom area, or drag to draw one. '
          'Give each area an optional description to explain what you are zooming in on. '
          'A blank one shows the image description, then the section header. '
          'Drag a box or its edges to move / resize it (Backspace deletes). '
          'Numbers are the order within this image; the page then scrolls on to the next image.',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
      _label('Zoom areas on this image (${_stops.length})'),
      if (_stops.isEmpty)
        const Text('None yet: this image is shown whole',
            style: TextStyle(color: Colors.white38)),
      for (var i = 0; i < _stops.length; i++)
        InkWell(
          onTap: () => setState(() => _sel = i),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: i == _sel ? _green : Colors.transparent),
            ),
            child: Column(children: [
            Row(children: [
              CircleAvatar(
                  radius: 11,
                  backgroundColor: const Color(0xFF29B6F6),
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 12, color: Colors.white))),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('${(1 / _stops[i].w).toStringAsFixed(1)}× zoom',
                      style: const TextStyle(color: Colors.white))),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Move up',
                  onPressed: i > 0 ? () => _swap(i, i - 1) : null,
                  icon: const Icon(Icons.arrow_upward, size: 18)),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Move down',
                  onPressed: i < _stops.length - 1 ? () => _swap(i, i + 1) : null,
                  icon: const Icon(Icons.arrow_downward, size: 18)),
              IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete',
                  onPressed: () => setState(() {
                        _stops.removeAt(i);
                        _sel = null;
                      }),
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444))),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
              child: TextField(
                key: ObjectKey(_stops[i]),
                controller: _stopCtlFor(_stops[i]),
                onChanged: (v) => _stops[i].desc = v,
                onTap: () => setState(() => _sel = i),
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Description (optional)',
                  hintStyle: TextStyle(color: Colors.white30),
                ),
              ),
            ),
            ]),
          ),
        ),
      if (sel != null)
        _slider('Selected area size: ${(1 / sel.w).toStringAsFixed(1)}× zoom', sel.w,
            _minW, _maxW, (v) => setState(() {
                  sel.w = v;
                  _clampStop(sel);
                  _lastW = sel.w;
                })),
      _label('Playback (this section)'),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        value: s.overview,
        onChanged: (v) => setState(() => s.overview = v ?? true),
        title: const Text('Start each image zoomed out (whole image)',
            style: TextStyle(color: Colors.white, fontSize: 13)),
      ),
      _slider('Scroll per stop: ${s.vh.round()} vh', s.vh, 40, 250,
          (v) => setState(() => s.vh = v)),
      _slider('Pause on each stop: ${(s.hold * 100).round()}%', s.hold, 0, 0.4,
          (v) => setState(() => s.hold = v)),
    ];
  }
}

class _TourPainter extends CustomPainter {
  final List<_TourStop> stops;
  final int? sel;
  final Rect imgRect;
  final double ar, iw, ih;
  _TourPainter(this.stops, this.sel, this.imgRect, this.ar, this.iw, this.ih);

  static const _blue = Color(0xFF29B6F6);
  static const _green = Color(0xFF00FF26);

  Offset _centre(_TourStop s) =>
      Offset(imgRect.left + s.cx * imgRect.width, imgRect.top + s.cy * imgRect.height);

  @override
  void paint(Canvas canvas, Size size) {
    if (stops.length > 1) {
      final path = Path()..moveTo(_centre(stops.first).dx, _centre(stops.first).dy);
      for (final s in stops.skip(1)) {
        final c = _centre(s);
        path.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = _blue.withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final selected = i == sel;
      final hN = s.w * iw / (ih * ar);
      final rect = Rect.fromCenter(
          center: _centre(s), width: s.w * imgRect.width, height: hN * imgRect.height);
      if (selected) {
        canvas.drawRect(rect, Paint()..color = _green.withValues(alpha: 0.12));
      }
      canvas.drawRect(
          rect,
          Paint()
            ..color = selected ? _green : _blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 3 : 2);
      if (selected) {
        final hp = Paint()..color = _green;
        for (final pt in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
          rect.topCenter,
          rect.bottomCenter,
          rect.centerLeft,
          rect.centerRight,
        ]) {
          canvas.drawRect(Rect.fromCenter(center: pt, width: 8, height: 8), hp);
        }
      }
      final c = _centre(s);
      canvas.drawCircle(c, 13, Paint()..color = _blue.withValues(alpha: 0.9));
      final tp = TextPainter(
        text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TourPainter old) => true;
}

class _Src {
  final String path;
  final String name;
  final int size;
  final ui.Image image;
  final int id;
  _Src(this.id, this.path, this.name, this.size, this.image);
}

/// One placed image: source rect (sx..sh) -> destination rect (x,y,dw,dh).
class _Placed {
  final ui.Image image;
  double sx = 0, sy = 0, sw, sh;
  double dw, dh, x = 0, y = 0;
  _Placed(this.image, this.dw, this.dh)
      : sw = image.width.toDouble(),
        sh = image.height.toDouble();
}

const _sizingOptions = <String, String>{
  'none': 'Keep original sizes',
  'fit-width': 'Match widest (scale to fit width)',
  'fit-height': 'Match tallest (scale to fit height)',
  'fit-smallest': 'Match smallest (scale all to smallest)',
  'crop-uniform': 'Crop to uniform size',
  'stretch-uniform': 'Stretch to uniform size (may distort)',
  'masonry-2': 'Masonry - 2 columns',
  'masonry-3': 'Masonry - 3 columns',
  'masonry-4': 'Masonry - 4 columns',
  'masonry-5': 'Masonry - 5 columns',
  'masonry-6': 'Masonry - 6 columns',
};

class JoinImagesScreen extends StatefulWidget {
  /// Optional folder to pre-load images from (e.g. the folder of the image
  /// currently open in the player).
  final String? initialFolder;
  const JoinImagesScreen({super.key, this.initialFolder});

  @override
  State<JoinImagesScreen> createState() => _JoinImagesScreenState();
}

class _JoinImagesScreenState extends State<JoinImagesScreen> {
  final List<_Src> _images = [];
  int _nextId = 0;

  String _layout = 'vertical';
  String _sizing = 'none';
  bool _sizingTouched = false; // user picked a sizing manually
  double _padding = 10;
  double _borderWidth = 0;
  Color _bg = Colors.black;
  Color _borderColor = Colors.black;

  ui.Image? _preview;
  int _canvasW = 0, _canvasH = 0;
  int _gen = 0;
  String? _error;

  bool _loading = false;
  bool _exporting = false;
  // Backed by a notifier so the tour editor can show export progress.
  final ValueNotifier<String?> _statusN = ValueNotifier<String?>(null);
  String? get _status => _statusN.value;
  set _status(String? v) => _statusN.value = v;
  String? _lastOutput;
  String? _lastOutputInfo;

  @override
  void initState() {
    super.initState();
    final d = widget.initialFolder;
    if (d != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _addFolder(d));
    }
  }

  @override
  void dispose() {
    for (final s in _images) {
      s.image.dispose();
    }
    _preview?.dispose();
    _statusN.dispose();
    super.dispose();
  }

  // ───────────────────────── loading ─────────────────────────

  Future<ui.Image> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    if (p.extension(path).toLowerCase() == '.avif') {
      final d = decodeAvif(bytes);
      final c = Completer<ui.Image>();
      ui.decodeImageFromPixels(
          d.frames.first.rgba, d.width, d.height, ui.PixelFormat.rgba8888, c.complete);
      return c.future;
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<void> _addPaths(List<String> paths) async {
    paths = paths
        .where((f) => _rasterExts.contains(p.extension(f).toLowerCase()))
        .toList();
    if (paths.isEmpty) return;
    setState(() => _loading = true);
    var n = 0;
    for (final f in paths) {
      try {
        final image = await _decode(f);
        final size = await File(f).length();
        _images.add(_Src(_nextId++, f, p.basename(f), size, image));
        n++;
        if (n % 5 == 0 && mounted) {
          setState(() => _status = 'Loading $n / ${paths.length}…');
        }
      } catch (e) {
        // ignore: avoid_print
        print('Skipped $f: $e');
      }
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _status = 'Loaded $n image(s)';
      _autoSizing();
    });
    _refresh();
  }

  Future<void> _addImages() async {
    final res = await FilePicker.pickFiles(
        type: FileType.any, dialogTitle: 'Select Images to Combine');
    if (res.isEmpty) return;
    await _addPaths([for (final f in res) if (f.path != null) f.path!]);
  }

  Future<void> _addFolder([String? given]) async {
    final dir = given ?? await FilePicker.getDirectoryPath();
    if (dir == null) return;
    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .map((f) => f.path)
        .toList()
      ..sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
    await _addPaths(files);
  }

  void _remove(int i) {
    _images.removeAt(i).image.dispose();
    setState(_autoSizing);
    _refresh();
  }

  void _reset() {
    for (final s in _images) {
      s.image.dispose();
    }
    _images.clear();
    _preview?.dispose();
    _preview = null;
    setState(() {
      _layout = 'vertical';
      _sizing = 'none';
      _sizingTouched = false;
      _padding = 10;
      _borderWidth = 0;
      _bg = Colors.black;
      _borderColor = Colors.black;
      _error = null;
      _status = 'Reset complete';
      _lastOutput = null;
    });
  }

  void _sort(String type) {
    switch (type) {
      case 'name-asc':
        _images.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'name-desc':
        _images.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      case 'size-asc':
        _images.sort((a, b) => a.size.compareTo(b.size));
      case 'size-desc':
        _images.sort((a, b) => b.size.compareTo(a.size));
      case 'shuffle':
        _images.shuffle();
    }
    setState(() {});
    _refresh();
  }

  // ───────────────────────── layout engine ─────────────────────────

  bool get _isMasonry => _sizing.startsWith('masonry-');
  int get _masonryCols => int.tryParse(_sizing.split('-').last) ?? 3;

  List<_Placed> _prepare() {
    final ims = _images.map((s) => s.image).toList();
    if (ims.isEmpty) return [];
    if (_isMasonry) return _masonry(_masonryCols);

    List<_Placed> mk(double Function(ui.Image) w, double Function(ui.Image) h) =>
        [for (final i in ims) _Placed(i, w(i), h(i))];

    switch (_sizing) {
      case 'fit-width':
        final mw = ims.map((i) => i.width).reduce(max).toDouble();
        return mk((i) => mw, (i) => i.height * mw / i.width);
      case 'fit-height':
        final mh = ims.map((i) => i.height).reduce(max).toDouble();
        return mk((i) => i.width * mh / i.height, (i) => mh);
      case 'fit-smallest':
        final minW = ims.map((i) => i.width).reduce(min).toDouble();
        final minH = ims.map((i) => i.height).reduce(min).toDouble();
        return [
          for (final i in ims)
            () {
              final s = min(minW / i.width, minH / i.height);
              return _Placed(i, i.width * s, i.height * s);
            }()
        ];
      case 'crop-uniform':
        final mw = ims.map((i) => i.width).reduce(max).toDouble();
        final mh = ims.map((i) => i.height).reduce(max).toDouble();
        final target = mw / mh;
        return [
          for (final i in ims)
            () {
              final pl = _Placed(i, mw, mh);
              final src = i.width / i.height;
              if (src > target) {
                pl.sh = i.height.toDouble();
                pl.sw = i.height * target;
                pl.sx = (i.width - pl.sw) / 2;
              } else {
                pl.sw = i.width.toDouble();
                pl.sh = i.width / target;
                pl.sy = (i.height - pl.sh) / 2;
              }
              return pl;
            }()
        ];
      case 'stretch-uniform':
        final mw = ims.map((i) => i.width).reduce(max).toDouble();
        final mh = ims.map((i) => i.height).reduce(max).toDouble();
        return mk((i) => mw, (i) => mh);
      default:
        return mk((i) => i.width.toDouble(), (i) => i.height.toDouble());
    }
  }

  List<_Placed> _masonry(int cols) {
    const canvasWidth = 1600.0;
    final pad = _padding;
    final items = [
      for (final s in _images) _Placed(s.image, s.image.width.toDouble(), s.image.height.toDouble())
    ]..sort((a, b) => b.dh.compareTo(a.dh));
    final colW = (canvasWidth - (cols - 1) * pad) / cols;
    final heights = List<double>.filled(cols, 0);
    for (final it in items) {
      final scale = colW / it.dw;
      it.dw = colW;
      it.dh = it.dh * scale;
      var c = 0;
      for (var i = 1; i < cols; i++) {
        if (heights[i] < heights[c]) c = i;
      }
      it.x = c * (colW + pad);
      it.y = heights[c];
      heights[c] += it.dh + pad;
    }
    return items;
  }

  /// Lays items out; returns canvas size and mutates item x/y.
  (double, double) _arrange(List<_Placed> items) {
    final bw = _borderWidth;
    final pad = _padding;
    if (items.isEmpty) return (800, 600);
    if (_isMasonry) {
      final mx = items.map((i) => i.x + i.dw).reduce(max);
      final my = items.map((i) => i.y + i.dh).reduce(max);
      for (final i in items) {
        i.x += bw;
        i.y += bw;
      }
      return (mx + bw * 2, my + bw * 2);
    }
    switch (_layout) {
      case 'horizontal':
        var x = bw;
        var mh = 0.0;
        for (final i in items) {
          i.x = x;
          i.y = bw;
          x += i.dw + pad;
          mh = max(mh, i.dh);
        }
        return (x - pad + bw, mh + bw * 2);
      case 'grid':
        final cols = sqrt(items.length).ceil();
        final rows = (items.length / cols).ceil();
        final cw = items.map((i) => i.dw).reduce(max);
        final ch = items.map((i) => i.dh).reduce(max);
        for (var n = 0; n < items.length; n++) {
          items[n].x = bw + (n % cols) * (cw + pad);
          items[n].y = bw + (n ~/ cols) * (ch + pad);
        }
        return (cw * cols + (cols - 1) * pad + bw * 2,
            ch * rows + (rows - 1) * pad + bw * 2);
      default: // vertical
        var y = bw;
        var mw = 0.0;
        for (final i in items) {
          i.x = bw;
          i.y = y;
          y += i.dh + pad;
          mw = max(mw, i.dw);
        }
        return (mw + bw * 2, y - pad + bw);
    }
  }

  ui.Image _render(double scale, List<_Placed> items, double w, double h) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.scale(scale);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _bg);
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;
    for (final it in items) {
      c.drawImageRect(it.image, Rect.fromLTWH(it.sx, it.sy, it.sw, it.sh),
          Rect.fromLTWH(it.x, it.y, it.dw, it.dh), paint);
    }
    if (_borderWidth > 0) {
      c.drawRect(
          Rect.fromLTWH(_borderWidth / 2, _borderWidth / 2, w - _borderWidth,
              h - _borderWidth),
          Paint()
            ..color = _borderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = _borderWidth);
    }
    final pic = rec.endRecording();
    final out = pic.toImageSync(max(1, (w * scale).ceil()), max(1, (h * scale).ceil()));
    pic.dispose();
    return out;
  }

  Future<void> _refresh() async {
    final gen = ++_gen;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (gen != _gen || !mounted) return;
    if (_images.isEmpty) {
      setState(() {
        _preview?.dispose();
        _preview = null;
      });
      return;
    }
    final items = _prepare();
    final (w, h) = _arrange(items);
    if (w > _maxCanvasDim || h > _maxCanvasDim) {
      setState(() {
        _preview?.dispose();
        _preview = null;
        _canvasW = w.ceil();
        _canvasH = h.ceil();
        _error = 'Result would be ${w.ceil()}×${h.ceil()} px — max is $_maxCanvasDim per side. '
            'Try Grid, a Masonry option or "Match smallest".';
      });
      return;
    }
    final scale = min(1.0, 1400 / max(w, h));
    final im = _render(scale, items, w, h);
    if (gen != _gen || !mounted) {
      im.dispose();
      return;
    }
    setState(() {
      _preview?.dispose();
      _preview = im;
      _canvasW = w.ceil();
      _canvasH = h.ceil();
      _error = null;
    });
  }

  // ───────────────────────── export ─────────────────────────

  Future<void> _export(String format) async {
    if (_images.isEmpty || _exporting) return;
    final items = _prepare();
    final (w, h) = _arrange(items);
    if (w > _maxCanvasDim || h > _maxCanvasDim) {
      setState(() => _error = 'Image too large to export (${w.ceil()}×${h.ceil()}).');
      return;
    }
    setState(() {
      _exporting = true;
      _status = 'Rendering…';
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final full = _render(1, items, w, h);
      final fw = full.width, fh = full.height;
      final outDir = p.join(p.dirname(_images.first.path), 'joined_images');
      await Directory(outDir).create(recursive: true);
      final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
      final outPath = p.join(outDir, 'combined-image-$ts.$format');
      final sw = Stopwatch()..start();

      await _writeEncoded(full, format, outPath);
      full.dispose();
      final len = await File(outPath).length();
      if (!mounted) return;
      setState(() {
        _lastOutput = outPath;
        _lastOutputInfo =
            '${format.toUpperCase()} • ${fw}×$fh • ${_fmt(len)} • ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
        _status = 'Saved ${p.basename(outPath)}';
      });
    } catch (e) {
      if (mounted) setState(() => _status = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Encodes [full] as png / avif / jpg and writes it to [outPath].
  Future<void> _writeEncoded(ui.Image full, String format, String outPath,
      {String prefix = ''}) async {
    if (format == 'png') {
      setState(() => _status = '${prefix}Encoding PNG…');
      final data = await full.toByteData(format: ui.ImageByteFormat.png);
      await File(outPath).writeAsBytes(data!.buffer.asUint8List());
    } else {
      final raw = await full.toByteData(format: ui.ImageByteFormat.rawRgba);
      final ttd = TransferableTypedData.fromList([raw!.buffer.asUint8List()]);
      setState(() => _status = format == 'avif'
          ? '${prefix}Encoding AVIF… (this may take a moment)'
          : '${prefix}Encoding JPG…');
      final threads = max(1, Platform.numberOfProcessors);
      final bytes = await _encodeInIsolate(ttd, full.width, full.height, format, threads);
      await File(outPath).writeAsBytes(bytes);
    }
  }

  // ───────────────────────── zoom + slideshow page (HTML) ─────────────────────────

  Future<void> _openTourEditor() async {
    final prev = _preview;
    if (prev == null || _exporting) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => _TourEditor(
              combined: prev,
              sources: List.of(_images),
              pickFiles: _pickImagePaths,
              decode: _decode,
              onExport: _exportTour,
              onOpenFile: _openFile,
              onOpenFolder: _openFolder,
              status: _statusN,
            )));
  }

  Future<List<String>> _pickImagePaths() async {
    final res = await FilePicker.pickFiles(
        type: FileType.any, dialogTitle: 'Select Images');
    if (res.isEmpty) return [];
    return [
      for (final f in res)
        if (f.path != null && _rasterExts.contains(p.extension(f.path!).toLowerCase()))
          f.path!
    ];
  }

  /// Exports every section into one index.html (+ images). The editor stays
  /// open, so the result can be adjusted and exported again.
  Future<_ExportResult> _exportTour(_TourConfig cfg) async {
    if (_images.isEmpty || _exporting || cfg.sections.isEmpty) {
      return const _ExportResult.fail('Nothing to export.');
    }
    var items = <_Placed>[];
    var cw = 0.0, ch = 0.0;
    if (cfg.sections.any((s) => s.pages.any((pg) => pg.kind == _PageKind.combined))) {
      items = _prepare();
      (cw, ch) = _arrange(items);
      if (cw > _maxCanvasDim || ch > _maxCanvasDim) {
        return _ExportResult.fail(
            'Combined image too large to export (${cw.ceil()}×${ch.ceil()}).');
      }
    }
    setState(() {
      _exporting = true;
      _status = 'Rendering…';
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final ts = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
      final outDir = p.join(p.dirname(_images.first.path), 'joined_images', 'scroll-$ts');
      await Directory(p.join(outDir, cfg.format)).create(recursive: true);
      final sw = Stopwatch()..start();
      final html = StringBuffer();
      final written = <String, String>{}; // image key -> file name (reused images are encoded once)
      final total = cfg.sections.fold<int>(0, (a, s) => a + s.pages.length);
      var done = 0, zooms = 0, nZoom = 0, nSlide = 0;
      _imgMeta.clear();
      for (var si = 0; si < cfg.sections.length; si++) {
        final sec = cfg.sections[si];
        final names = <String>[];
        for (final pg in sec.pages) {
          done++;
          names.add(await _writePageImage(
              pg, outDir, cfg.format, written, items, cw, ch, 'Image $done/$total: '));
        }
        if (sec.kind == _SecKind.zoom) {
          nZoom++;
          for (var i = 0; i < sec.pages.length; i++) {
            zooms += sec.pages[i].stops.length;
            html.write(_zoomSection(sec, sec.pages[i], names[i], si));
          }
        } else {
          nSlide++;
          html.write(_slideSection(sec, names, si));
        }
      }
      final htmlPath = p.join(outDir, 'index.html');
      await File(htmlPath).writeAsString(_buildTourHtml(html.toString()));
      final bytes = await _sumSizes(outDir, written.values);
      final info =
          '$nZoom zoom + $nSlide slideshow section${nZoom + nSlide == 1 ? '' : 's'} • $total image${total == 1 ? '' : 's'} • $zooms zooms • ${cfg.format.toUpperCase()} ${_fmt(bytes)} • ${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s';
      if (mounted) {
        setState(() {
          _lastOutput = htmlPath;
          _lastOutputInfo = 'SCROLL PAGE • $info';
          _status = 'Saved: upload the whole folder (index.html + images)';
        });
      }
      await _openFile(htmlPath);
      return _ExportResult.ok('Saved • $info', htmlPath);
    } catch (e) {
      final m = 'Export failed: $e';
      if (mounted) setState(() => _status = m);
      return _ExportResult.fail(m);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Per exported image file: width, height and a tiny inline preview (data URI).
  final Map<String, (int, int, String)> _imgMeta = {};

  static String _attr(String s) => const HtmlEscape(HtmlEscapeMode.attribute).convert(s);

  /// One scroll section (sticky canvas) for one image of a zoom section.
  /// [secIdx] is the section's position, used by the page to load sections ahead of time.
  String _zoomSection(_SecConfig sec, _TourPage pg, String imgName, int secIdx) {
    String r(double v) => v.toStringAsFixed(5);
    // Caption: the area's own description, else the image's, else the section header.
    final base = pg.desc.trim().isNotEmpty ? pg.desc.trim() : sec.header.trim();
    final stopsJson = jsonEncode([
      for (final s in pg.stops)
        {
          'cx': double.parse(r(s.cx)),
          'cy': double.parse(r(s.cy)),
          'w': double.parse(r(s.w)),
          'd': s.desc.trim().isNotEmpty ? s.desc.trim() : base,
        }
    ]);
    final anyCap = base.isNotEmpty || pg.stops.any((s) => s.desc.trim().isNotEmpty);
    final overview = sec.overview || pg.stops.length <= 1;
    final n = max(1, pg.stops.length + (overview ? 1 : 0));
    final heightVh = ((n - 1) * sec.vh + 100).round();
    final ar = '${sec.arW} / ${sec.arH}';
    final m = _imgMeta[imgName]!;
    // 90% of the screen width and height (minus the caption strip when there is one).
    final availH = anyCap ? '(100vh - 72px)' : '100vh';
    return '<section class="zt-scroller" style="height:${heightVh}vh" data-sec="$secIdx" '
        'data-src="${_attr(imgName)}" data-w="${m.$1}" data-h="${m.$2}" data-thumb="${_attr(m.$3)}" '
        'data-hold="${sec.hold.toStringAsFixed(3)}" '
        'data-overview="$overview" data-ocap="${_attr(base)}" data-stops="${_attr(stopsJson)}">\n'
        '  <div class="zt-stage${anyCap ? ' hc' : ''}"><canvas class="zt-canvas" '
        'style="aspect-ratio:$ar;width:min(90vw,calc($availH * 0.9 * ${sec.arW} / ${sec.arH}))"></canvas>'
        '${anyCap ? '<div class="cap"><span></span></div>' : ''}</div>\n'
        '</section>\n';
  }

  /// One tall scroll section with a sticky full-screen canvas that cross-fades
  /// through the images. Captions change with the image.
  String _slideSection(_SecConfig sec, List<String> names, int secIdx) {
    final n = names.length;
    final heightVh = ((n - 1) * sec.vh + 100).round();
    final caps = [
      for (final pg in sec.pages) pg.desc.trim().isNotEmpty ? pg.desc.trim() : sec.header.trim()
    ];
    final anyCap = caps.any((c) => c.isNotEmpty);
    final cap = anyCap ? '<div class="cap"><span></span></div>' : '';
    final dims = [for (final nm in names) [_imgMeta[nm]!.$1, _imgMeta[nm]!.$2]];
    final thumbs = [for (final nm in names) _imgMeta[nm]!.$3];
    return '<section class="fb" style="height:${heightVh}vh" data-sec="$secIdx" '
        'data-hold="${sec.hold.toStringAsFixed(3)}" data-cap="$anyCap" '
        'data-imgs="${_attr(jsonEncode(names))}" data-dims="${_attr(jsonEncode(dims))}" '
        'data-thumbs="${_attr(jsonEncode(thumbs))}" data-caps="${_attr(jsonEncode(caps))}">\n'
        '  <div class="fb-stage"><canvas class="fb-canvas"></canvas>$cap</div>\n'
        '</section>\n';
  }

  String _buildTourHtml(String sectionsHtml) {
    final bg = '#${_bg.toARGB32().toRadixString(16).substring(2)}';
    return _tourTemplate.replaceAll('__BG__', bg).replaceAll('__SECTIONS__', sectionsHtml);
  }

  static const _tourTemplate = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Scroll Page</title>
<style>
  html, body { margin: 0; background: __BG__; }
  .zt-scroller, .fb { position: relative; }
  .zt-stage { position: sticky; top: 0; height: 100vh; height: 100dvh;
              display: flex; align-items: center; justify-content: center; overflow: hidden; }
  .zt-stage.hc { box-sizing: border-box; padding-bottom: 72px; }
  .zt-canvas { display: block; height: auto; }
  .fb-stage { position: sticky; top: 0; height: 100vh; height: 100dvh; overflow: hidden; }
  .fb-canvas { display: block; width: 100%; height: 100%; }
  .cap { position: absolute; left: 0; right: 0; bottom: 0; height: 72px; margin: 0;
         padding: 0 6vw; box-sizing: border-box; display: flex; align-items: center;
         justify-content: center; text-align: center; overflow: hidden; white-space: pre-line;
         color: #fff; font: 600 1.1rem/1.3 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
         text-shadow: 0 1px 3px rgba(0, 0, 0, .65); pointer-events: none; }
</style>
</head>
<body>
__SECTIONS__
<script>
(function () {
  var BG = '__BG__';
  var CAP = 72;          // px kept free at the bottom of slideshow sections with captions (see .cap)
  var queued = false;
  var cache = {};        // full-size images used by several sections are loaded once
  var groups = {};       // section index -> image files of that section

  function lerp(a, b, t) { return a + (b - a) * t; }
  function ease(t) { return t * t * (3 - 2 * t); }
  function hold(f, H) {
    if (f <= H) return 0;
    if (f >= 1 - H) return 1;
    return ease((f - H) / (1 - 2 * H));
  }
  function get(src) {
    var im = cache[src];
    if (!im) { im = cache[src] = new Image(); im.addEventListener('load', schedule); im.src = src; }
    return im;
  }
  function ready(im) { return im && im.complete && im.naturalWidth > 0; }
  // Tiny inline preview shown until the full image has loaded (never a blank canvas).
  function preview(uri) { var im = new Image(); im.addEventListener('load', schedule); im.src = uri; return im; }
  function reg(g, src) { (groups[g] = groups[g] || []).push(src); }
  function loadGroup(g) { (groups[g] || []).forEach(get); }

  function sizeCanvas(canvas) {
    var cw = canvas.clientWidth, ch = canvas.clientHeight;
    if (!cw || !ch) return null;
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var bw = Math.round(cw * dpr), bh = Math.round(ch * dpr);
    if (canvas.width !== bw || canvas.height !== bh) { canvas.width = bw; canvas.height = bh; }
    return { cw: cw, ch: ch, bw: bw, bh: bh, dpr: dpr };
  }
  function progress(el, rect) {
    var range = el.offsetHeight - window.innerHeight;
    return range > 0 ? Math.min(1, Math.max(0, -rect.top / range)) : 0;
  }
  // Caption follows the camera / image: fade out the old text, fade in the new one.
  function setCap(box, el, ta, tb, t) {
    var text, op;
    if (ta === tb) { text = ta; op = 1; }
    else if (t < 0.5) { text = ta; op = 1 - 2 * t; }
    else { text = tb; op = 2 * t - 1; }
    if (el.textContent !== text) el.textContent = text;
    box.style.opacity = op;
  }

  // ── zoom sections: one per image, scrolling through its zoom stops ──
  var zooms = Array.prototype.map.call(document.querySelectorAll('.zt-scroller'), function (el) {
    var canvas = el.querySelector('canvas');
    var s = {
      el: el, canvas: canvas, ctx: canvas.getContext('2d'),
      sec: parseInt(el.getAttribute('data-sec'), 10),
      src: el.getAttribute('data-src'),
      W: parseInt(el.getAttribute('data-w'), 10), H: parseInt(el.getAttribute('data-h'), 10),
      ph: preview(el.getAttribute('data-thumb')),
      hold: parseFloat(el.getAttribute('data-hold')),
      stops: JSON.parse(el.getAttribute('data-stops')), // cx, cy = centre, w = visible width (0..1 of image), d = caption
      overview: el.getAttribute('data-overview') === 'true', // start zoomed out on the whole image
      ocap: el.getAttribute('data-ocap') || '',
      capBox: el.querySelector('.cap'), capText: el.querySelector('.cap span')
    };
    reg(s.sec, s.src);
    return s;
  });

  function drawZoom(s, rect) {
    var full = get(s.src);
    var im = ready(full) ? full : (ready(s.ph) ? s.ph : null);
    var W = s.W, H = s.H;                      // original size; a preview has the same shape
    var sz = sizeCanvas(s.canvas); if (!sz) return;
    var ctx = s.ctx, bw = sz.bw, bh = sz.bh;
    ctx.globalAlpha = 1;
    ctx.fillStyle = BG;
    ctx.fillRect(0, 0, bw, bh);

    var vAR = sz.cw / sz.ch;
    var cams = s.stops.slice();
    if (s.overview) cams.unshift({ cx: 0.5, cy: 0.5, w: Math.max(1, H * vAR / W), d: s.ocap });
    if (!cams.length) return;

    var p = progress(s.el, rect);
    var n = cams.length;
    var seg = n > 1 ? p * (n - 1) : 0;
    var i = n > 1 ? Math.min(n - 2, Math.floor(seg)) : 0;
    var a = cams[i], b = cams[n > 1 ? i + 1 : i];
    var t = n > 1 ? hold(seg - i, s.hold) : 0;
    if (s.capBox) setCap(s.capBox, s.capText, a.d || '', b.d || '', t);
    if (!im) return;

    var w = Math.exp(lerp(Math.log(a.w), Math.log(b.w), t));
    var cx = lerp(a.cx, b.cx, t), cy = lerp(a.cy, b.cy, t);
    var vw = w * W, vh = vw / vAR;            // visible region in original image pixels
    var sx = cx * W - vw / 2, sy = cy * H - vh / 2;

    var x0 = Math.max(0, sx), y0 = Math.max(0, sy);
    var x1 = Math.min(W, sx + vw), y1 = Math.min(H, sy + vh);
    if (x1 <= x0 || y1 <= y0) return;
    var k = bw / vw;
    var fx = im.naturalWidth / W, fy = im.naturalHeight / H;   // original px -> loaded image px
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(im, x0 * fx, y0 * fy, (x1 - x0) * fx, (y1 - y0) * fy,
                  (x0 - sx) * k, (y0 - sy) * k, (x1 - x0) * k, (y1 - y0) * k);
  }

  // ── slideshow sections: cross-fade through the images ──
  var books = Array.prototype.map.call(document.querySelectorAll('.fb'), function (el) {
    var c = el.querySelector('canvas');
    var b = { el: el, canvas: c, ctx: c.getContext('2d'),
              sec: parseInt(el.getAttribute('data-sec'), 10),
              srcs: JSON.parse(el.getAttribute('data-imgs')),
              dims: JSON.parse(el.getAttribute('data-dims')),
              caps: JSON.parse(el.getAttribute('data-caps')),
              hold: parseFloat(el.getAttribute('data-hold')),
              hasCap: el.getAttribute('data-cap') === 'true',
              capBox: el.querySelector('.cap'), capText: el.querySelector('.cap span') };
    b.phs = JSON.parse(el.getAttribute('data-thumbs')).map(preview);
    b.srcs.forEach(function (src) { reg(b.sec, src); });
    return b;
  });

  // Full image if loaded, otherwise its preview.
  function pick(b, k) {
    var full = get(b.srcs[k]);
    return ready(full) ? full : (ready(b.phs[k]) ? b.phs[k] : null);
  }
  // As large as possible within 90% of the width and 90% of the height, centred.
  function drawImg(ctx, im, dim, bw, availH) {
    if (!im) return;
    var s = Math.min(bw * 0.9 / dim[0], availH * 0.9 / dim[1]);
    var w = dim[0] * s, h = dim[1] * s;
    ctx.drawImage(im, (bw - w) / 2, (availH - h) / 2, w, h);
  }

  function drawBook(b, rect) {
    var sz = sizeCanvas(b.canvas); if (!sz) return;
    var ctx = b.ctx, bw = sz.bw, bh = sz.bh;
    var availH = bh - (b.hasCap ? Math.round(CAP * sz.dpr) : 0);

    var n = b.srcs.length;
    var p = progress(b.el, rect);
    var pos = n > 1 ? p * (n - 1) : 0;
    var i = n > 1 ? Math.min(n - 2, Math.floor(pos)) : 0;
    var t = n > 1 ? hold(pos - i, b.hold) : 0;

    ctx.globalAlpha = 1;
    ctx.fillStyle = BG;
    ctx.fillRect(0, 0, bw, bh);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';

    if (n <= 1 || t <= 0) {
      drawImg(ctx, pick(b, i), b.dims[i], bw, availH);
    } else if (t >= 1) {
      drawImg(ctx, pick(b, i + 1), b.dims[i + 1], bw, availH);
    } else {                                   // cross-fade
      ctx.globalAlpha = 1 - t * t * t; drawImg(ctx, pick(b, i), b.dims[i], bw, availH);
      ctx.globalAlpha = t; drawImg(ctx, pick(b, i + 1), b.dims[i + 1], bw, availH);
      ctx.globalAlpha = 1;
    }

    if (b.capBox) setCap(b.capBox, b.capText, b.caps[i] || '', (n > 1 ? b.caps[i + 1] : b.caps[i]) || '', t);
  }

  function frame() {
    queued = false;
    var vh = window.innerHeight;
    var seen = {};
    var vis = [];
    zooms.concat(books).forEach(function (s) {
      var r = s.el.getBoundingClientRect();
      if (r.bottom > 0 && r.top < vh) { seen[s.sec] = true; vis.push([s, r]); }
    });
    // A section in view loads its own images first, then every image of the next section.
    Object.keys(seen).forEach(function (g) { loadGroup(+g); });
    Object.keys(seen).forEach(function (g) { loadGroup(+g + 1); });
    vis.forEach(function (v) { if (v[0].srcs) drawBook(v[0], v[1]); else drawZoom(v[0], v[1]); });
  }

  function schedule() { if (!queued) { queued = true; requestAnimationFrame(frame); } }

  window.addEventListener('scroll', schedule, { passive: true });
  window.addEventListener('resize', schedule);
  schedule();
})();
</script>
</body>
</html>
''';

  /// Opens a file with the system default app (an .html file opens in the default browser).
  Future<void> _openFile(String path) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  /// Encodes the image of [pg] into [outDir] and returns its file name. Images
  /// used more than once (same source) are encoded a single time.
  Future<String> _writePageImage(_TourPage pg, String outDir, String format,
      Map<String, String> written, List<_Placed> items, double cw, double ch,
      String prefix) async {
    final key = '${pg.kind.name}|${pg.srcId}|${pg.path}';
    final have = written[key];
    if (have != null) return have;
    ui.Image full;
    var own = true; // dispose after encoding?
    if (pg.kind == _PageKind.combined) {
      full = _render(1, items, cw, ch);
    } else if (pg.kind == _PageKind.source) {
      full = _images.firstWhere((s) => s.id == pg.srcId).image;
      own = false;
    } else {
      full = await _decode(pg.path!);
    }
    // Images go in a sub-folder named after the format (avif/ or jpg/); the page refers to them by that relative path.
    final name = '$format/image-${written.length + 1}.$format';
    await _writeEncoded(full, format, p.join(outDir, name), prefix: prefix);
    _imgMeta[name] = (full.width, full.height, await _thumbDataUri(full));
    if (own) full.dispose();
    written[key] = name;
    return name;
  }

  /// ~40px preview of [full] as a PNG data URI, shown by the page until the real image loads.
  Future<String> _thumbDataUri(ui.Image full) async {
    const maxDim = 40;
    final k = min(1.0, maxDim / max(full.width, full.height));
    final w = max(1, (full.width * k).round()), h = max(1, (full.height * k).round());
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(
        full,
        Rect.fromLTWH(0, 0, full.width.toDouble(), full.height.toDouble()),
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..filterQuality = FilterQuality.medium);
    final pic = rec.endRecording();
    final im = await pic.toImage(w, h);
    pic.dispose();
    final data = await im.toByteData(format: ui.ImageByteFormat.png);
    im.dispose();
    return 'data:image/png;base64,${base64Encode(data!.buffer.asUint8List())}';
  }

  Future<int> _sumSizes(String dir, Iterable<String> names) async {
    var t = 0;
    for (final n in names) {
      t += await File(p.join(dir, n)).length();
    }
    return t;
  }

  Future<void> _openFolder(String dir) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [dir]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [dir]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [dir]);
      }
    } catch (_) {}
  }

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KiB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MiB';
  }


  Widget _thumbBox(_Src s) => Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white24, width: 2),
            borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: RawImage(
            image: s.image,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.low),
      );

  /// Grid tile: drag onto another tile to move it to that position.
  Widget _thumb(int i, bool busy) {
    final s = _images[i];
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != i,
      onAcceptWithDetails: (d) {
        final item = _images.removeAt(d.data);
        _images.insert(i, item);
        setState(() {});
        _refresh();
      },
      builder: (_, candidate, __) => Draggable<int>(
        data: i,
        maxSimultaneousDrags: busy ? 0 : 1,
        feedback: Opacity(
            opacity: 0.8, child: SizedBox(width: 100, height: 100, child: _thumbBox(s))),
        childWhenDragging: Opacity(opacity: 0.3, child: _thumbBox(s)),
        child: Tooltip(
          message: s.name,
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Container(
                foregroundDecoration: candidate.isNotEmpty
                    ? BoxDecoration(
                        border: Border.all(color: _green, width: 2),
                        borderRadius: BorderRadius.circular(6))
                    : null,
                child: _thumbBox(s),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: busy ? null : () => _remove(i),
                  child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(0xFFEF4444),
                      child: Icon(Icons.close, size: 13, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pill-style toggle button (same look as the sort buttons).
  Widget _pill(String label, bool selected, bool disabled, VoidCallback onTap) =>
      OutlinedButton(
        onPressed: disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? const Color(0x3300FF26) : null,
          side: BorderSide(color: selected ? _green : Colors.white24),
          foregroundColor: selected ? _green : null,
        ),
        child: Text(label),
      );

  /// Default sizing by image count, until the user chooses one themselves.
  void _autoSizing() {
    if (_sizingTouched) return;
    final n = _images.length;
    _sizing = n > 24
        ? 'masonry-6'
        : n > 15
            ? 'masonry-5'
            : n > 12
                ? 'masonry-4'
                : n > 9
                    ? 'masonry-3'
                    : 'none';
  }

  // ───────────────────────── UI ─────────────────────────

  static const _green = Color(0xFF00FF26);

  Widget _card(String title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _green, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _colorRow(String label, Color value, ValueChanged<Color> onChanged) {
    const swatches = [
      Colors.black,
      Colors.white,
      Color(0xFF808080),
      Color(0xFF1E1E1E),
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.purple,
    ];
    final hex = '#${value.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label  $hex', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in swatches)
            GestureDetector(
              onTap: () {
                onChanged(c);
                _refresh();
              },
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: c == value ? _green : Colors.white38,
                      width: c == value ? 2 : 1),
                ),
              ),
            ),
        ]),
      ],
    );
  }

  Widget _kv(String label, double v, double max, ValueChanged<double> cb) => Row(
        children: [
          SizedBox(
              width: 130,
              child: Text('$label ${v.round()}px',
                  softWrap: false, style: const TextStyle(color: Colors.white))),
          Expanded(
              child: Slider(
                  value: v,
                  min: 0,
                  max: max,
                  divisions: max.round(),
                  onChanged: (x) {
                    cb(x);
                    _refresh();
                  })),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _exporting;
    final canExport = _images.isNotEmpty && _error == null && !busy;
    const sortLabels = {
      'name-asc': '📝 Name A-Z',
      'name-desc': '📝 Name Z-A',
      'size-asc': '📏 Size ↑',
      'size-desc': '📏 Size ↓',
      'shuffle': '🔀 Shuffle',
    };
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Join Images, Zoom + Slideshow'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                '1. Select Images to Combine',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ElevatedButton.icon(
                          onPressed: busy ? null : _addImages,
                          icon: const Icon(Icons.image),
                          label: const Text('Add Images')),
                      ElevatedButton.icon(
                          onPressed: busy ? null : () => _addFolder(),
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Add Folder')),
                      TextButton(
                          onPressed: busy || _images.isEmpty ? null : _reset,
                          child: const Text('🔄 Reset')),
                    ]),
                    const SizedBox(height: 6),
                    const Text('jpg, png, webp, avif, static gif, bmp',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    if (_loading) const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator()),
                  ],
                ),
              ),
              if (_images.isNotEmpty) ...[
                _card(
                  '2. Arrange Your Images (${_images.length}) — drag onto another to reorder',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        for (final e in sortLabels.entries)
                          OutlinedButton(
                              onPressed: busy ? null : () => _sort(e.key),
                              child: Text(e.value)),
                      ]),
                      const SizedBox(height: 10),
                      LayoutBuilder(builder: (ctx, c) {
                        const tile = 110.0, gap = 10.0;
                        final cols = max(1, ((c.maxWidth + gap) / (tile + gap)).floor());
                        final rows = (_images.length / cols).ceil();
                        final h = min(rows * (tile + gap), 440.0);
                        return SizedBox(
                          height: h,
                          child: GridView.builder(
                            padding: const EdgeInsets.only(top: 8, right: 8),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: tile,
                              mainAxisSpacing: gap,
                              crossAxisSpacing: gap,
                            ),
                            itemCount: _images.length,
                            itemBuilder: (_, i) => _thumb(i, busy),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                _card(
                  '3. Choose Layout Style',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'horizontal',
                              icon: Icon(Icons.view_column),
                              label: Text('Horizontal')),
                          ButtonSegment(
                              value: 'vertical',
                              icon: Icon(Icons.view_agenda),
                              label: Text('Vertical')),
                          ButtonSegment(
                              value: 'grid',
                              icon: Icon(Icons.grid_view),
                              label: Text('Grid')),
                        ],
                        selected: {_layout},
                        onSelectionChanged: (v) {
                          setState(() => _layout = v.first);
                          _refresh();
                        },
                      ),
                      const SizedBox(height: 4),
                      if (_isMasonry)
                        const Text('Masonry ignores the layout buttons.',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      const SizedBox(height: 10),
                      _kv('Padding', _padding, 50, (v) => setState(() => _padding = v)),
                      _kv('Border Width', _borderWidth, 20,
                          (v) => setState(() => _borderWidth = v)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 40, runSpacing: 12, children: [
                        _colorRow('Background', _bg, (c) => setState(() => _bg = c)),
                        _colorRow('Border Color', _borderColor,
                            (c) => setState(() => _borderColor = c)),
                      ]),
                      const SizedBox(height: 12),
                      const Text('Image Sizing',
                          style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        for (final e in _sizingOptions.entries)
                          if (!e.key.startsWith('masonry-'))
                            _pill(e.value, _sizing == e.key, busy, () {
                              setState(() {
                                _sizing = e.key;
                                _sizingTouched = true;
                              });
                              _refresh();
                            }),
                        const Text('Masonry Columns:',
                            style: TextStyle(color: Colors.white)),
                        for (var n = 2; n <= 6; n++)
                          _pill('$n', _sizing == 'masonry-$n', busy, () {
                            setState(() {
                              _sizing = 'masonry-$n';
                              _sizingTouched = true;
                            });
                            _refresh();
                          }),
                      ]),
                    ],
                  ),
                ),
                _card(
                  '4. Preview Combined Image'
                  '${_canvasW > 0 ? '  ($_canvasW × $_canvasH px)' : ''}',
                  Container(
                    constraints: const BoxConstraints(minHeight: 200, maxHeight: 520),
                    alignment: Alignment.center,
                    child: _error != null
                        ? SelectableText(_error!,
                            style: const TextStyle(color: Colors.redAccent))
                        : _preview == null
                            ? const CircularProgressIndicator()
                            : RawImage(image: _preview, fit: BoxFit.contain),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                        onPressed: canExport ? () => _export('avif') : null,
                        child: const Text('✨ Save AVIF (smallest)')),
                    ElevatedButton(
                        onPressed: canExport ? () => _export('jpg') : null,
                        child: const Text('📷 Save JPG (85%)')),
                    ElevatedButton(
                        onPressed: canExport ? () => _export('png') : null,
                        child: const Text('🖼️ Save PNG (lossless)')),
                    ElevatedButton(
                        onPressed: canExport && _preview != null ? _openTourEditor : null,
                        child: const Text('🔍 Zoom + Slideshow (HTML)')),
                  ],
                ),
                if (_exporting) const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator()),
              ],
              if (_status != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SelectableText(_status!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
              if (_lastOutput != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0x1A00FF26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x4D00FF26)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_lastOutputInfo ?? '',
                          style: const TextStyle(
                              color: _green, fontWeight: FontWeight.bold)),
                      Row(children: [
                        Expanded(
                            child: Text(_lastOutput!,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                                overflow: TextOverflow.ellipsis)),
                        TextButton(
                            onPressed: () => _openFolder(p.dirname(_lastOutput!)),
                            child: const Text('Open folder')),
                      ]),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
