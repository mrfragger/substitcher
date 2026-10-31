// lib/services/svg_palette_html.dart
//
// Page builders for the SVG palette gallery (ports of themePage / galleryPage / palettesJS
// in Pages.swift and Palettes.swift). The HTML/JS itself lives in svg_palette_templates.dart
// and the palettes in svg_palette_data.dart; this file only fills in the blanks.
import 'dart:convert';

import 'svg_palette_data.dart';
import 'svg_palette_templates.dart';

class SvgGalleryItem {
  final int index;
  final String name; // file stem, e.g. "mycat-3-cut" (only [A-Za-z0-9-])
  final String tag; // 'bg', 'cut' or 'svg'
  final int w, h;
  final List<String> palette; // '#rrggbb', dark -> light
  final String thumbExt; // 'avif', or 'svg' (SVG sources use the original file)
  final int variant; // 1-based instance number for 'mask' items, otherwise 0
  final String? thumbName; // file stem in th/ when it differs from [name] (OCR reuses the original)
  final String text; // recognised text, 'ocr' items only
  final int bytes; // size shown on the card: the SVG text, or the AVIF file for 'orig' (0 = none)

  const SvgGalleryItem({
    required this.index,
    required this.name,
    required this.tag,
    required this.w,
    required this.h,
    required this.palette,
    required this.thumbExt,
    this.variant = 0,
    this.thumbName,
    this.text = '',
    this.bytes = 0,
  });

  /// Order of the tags in the gallery.
  static const tagOrder = ['orig', 'ocr', 'bg', 'cut', 'crop', 'cropcut', 'face', 'facecut', 'mask', 'svg'];

  /// Sort rank of the tag; face and facecut share one so they can be paired by number.
  int get tagRank => tagOrder.indexOf(tag == 'facecut' ? 'face' : tag);

  /// Original and text cards have no theme page.
  bool get hasPage => tag != 'orig' && tag != 'ocr';

  String get tagLabel => switch (tag) {
        'orig' => 'original',
        'ocr' => 'text',
        'bg' => 'with background',
        'cut' => 'background removed',
        'crop' => 'smart crop',
        'cropcut' => 'smart crop, background removed',
        'face' => variant > 0 ? 'face $variant' : 'face',
        'facecut' => variant > 0 ? 'face $variant, background removed' : 'face, background removed',
        'mask' => 'mask $variant',
        _ => 'SVG source',
      };

  /// Short text on the gallery card ("mask 2" rather than just "mask").
  String get cardLabel => switch (tag) {
        'mask' => 'mask $variant',
        'face' => variant > 0 ? 'face $variant' : 'face',
        'facecut' => variant > 0 ? 'facecut $variant' : 'facecut',
        _ => tag,
      };
}

/// Per-image page: live palette editor with the traced SVG embedded.
String themePage(SvgGalleryItem item, String svg, {Map<String, int> slotMap = const {}}) {
  final defaults = item.palette.map((c) => '"$c"').join(',');
  return kThemePageTemplate
      .replaceAll('__NAME__', item.name)
      .replaceAll('__TAGLABEL__', item.tagLabel)
      .replaceAll('__DEFAULTS__', defaults)
      .replaceAll('__SLOTMAP__', jsonEncode(slotMap))
      // Last, so the SVG (arbitrary text) is never scanned for placeholders.
      .replaceAll('__SVG__', svg);
}

/// "512 B", "64KB", "1.2MB".
String _fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).round()}KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(1)}MB';
}

/// index.html: one card per item with filter buttons and "keep" stars.
String galleryPage(List<SvgGalleryItem> items) {
  final cards = items.map((it) {
    final thumb = 'th/${it.thumbName ?? it.name}.${it.thumbExt}';
    final img = '<img src="$thumb" width="${it.w}" height="${it.h}" loading="lazy" alt="">';
    final dots = it.palette.map((c) => '<i style="background:$c"></i>').join();
    final ocr = it.tag == 'ocr'
        ? '<pre class="ocr" title="Click to copy">${_esc(it.text)}</pre>'
        : '';
    // SVG cards open their theme page; original and text cards are plain (right-click saves the AVIF).
    // The recognised text is overlaid on the bottom of the image, so every card has the same height.
    final pic = switch (it.tag) {
      'orig' || 'ocr' => '<div class="pic">$img$ocr</div>',
      _ => '<a href="pages/${it.name}.html">$img</a>',
    };
    return '<div class="card" data-tag="${it.tag}" data-name="${it.name}">'
        '$pic'
        '<div class="meta"><span class="tag">${it.cardLabel}</span><span class="dots">$dots</span>'
        '<span class="size">${it.bytes > 0 ? _fmtSize(it.bytes) : ''}</span>'
        '<button class="star" title="Keep">&#9733;</button></div></div>';
  }).join('\n');
  return kGalleryPageTemplate.replaceAll('__CARDS__', cards);
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Written next to index.html and loaded by every page via <script src="../palettes.js">.
String palettesJs() {
  final list = [
    for (final p in expandedPalettes()) {'name': p.name, 'colors': p.colors}
  ];
  return 'window.PALETTES=${jsonEncode(list)};\n';
}
