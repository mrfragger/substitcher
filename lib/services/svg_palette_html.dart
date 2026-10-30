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

  const SvgGalleryItem({
    required this.index,
    required this.name,
    required this.tag,
    required this.w,
    required this.h,
    required this.palette,
    required this.thumbExt,
  });

  String get tagLabel => switch (tag) {
        'bg' => 'with background',
        'cut' => 'background removed',
        _ => 'SVG source',
      };
}

/// Per-image page: live palette editor with the traced SVG embedded.
String themePage(SvgGalleryItem item, String svg) {
  final defaults = item.palette.map((c) => '"$c"').join(',');
  return kThemePageTemplate
      .replaceAll('__NAME__', item.name)
      .replaceAll('__TAGLABEL__', item.tagLabel)
      .replaceAll('__DEFAULTS__', defaults)
      // Last, so the SVG (arbitrary text) is never scanned for placeholders.
      .replaceAll('__SVG__', svg);
}

/// index.html: one card per item with filter buttons and "keep" stars.
String galleryPage(List<SvgGalleryItem> items) {
  final cards = items.map((it) {
    final dots = it.palette.map((c) => '<i style="background:$c"></i>').join();
    return '<div class="card" data-tag="${it.tag}" data-name="${it.name}">'
        '<a href="pages/${it.name}.html"><img src="th/${it.name}.${it.thumbExt}" '
        'width="${it.w}" height="${it.h}" loading="lazy" alt=""></a>'
        '<div class="meta"><span class="tag">${it.tag}</span><span class="dots">$dots</span>'
        '<button class="star" title="Keep">&#9733;</button></div></div>';
  }).join('\n');
  return kGalleryPageTemplate.replaceAll('__CARDS__', cards);
}

/// Written next to index.html and loaded by every page via <script src="../palettes.js">.
String palettesJs() {
  final list = [
    for (final p in expandedPalettes()) {'name': p.name, 'colors': p.colors}
  ];
  return 'window.PALETTES=${jsonEncode(list)};\n';
}
