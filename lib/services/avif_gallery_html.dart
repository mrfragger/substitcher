// lib/services/avif_gallery_html.dart
// HTML generators ported from masonryavif.js (generateGalleryHTML / generateIndexHTML).
import 'dart:convert';

class GalleryItem {
  final String fileName; // sanitized base name (no extension for raster, full name for svg)
  final int width;
  final int height;
  final bool isSvg;
  const GalleryItem(this.fileName, this.width, this.height, {this.isSvg = false});
}

String _esc(String s) => const HtmlEscape().convert(s);

String generateGalleryHtml(String dirName, List<GalleryItem> items, String titleOption) {
  final images = items
      .map((i) => i.isSvg ? 'images/${i.fileName}' : 'images/${i.fileName}.avif')
      .toList();

  final thumbs = StringBuffer();
  for (var idx = 0; idx < items.length; idx++) {
    final it = items[idx];
    final display = _esc(
        it.fileName.replaceAll('_', ' ').replaceFirst(RegExp(r'^\d+\s*'), ''));
    final thumbSrc = it.isSvg ? 'images/${it.fileName}' : 'th/${it.fileName}.avif';
    final full = it.isSvg ? 'images/${it.fileName}' : 'images/${it.fileName}.avif';
    thumbs.writeln('<div class="item"><div class="image-wrapper"><img src="$thumbSrc" '
        'data-index="$idx" data-fullsize="$full" width="${it.width}" height="${it.height}" '
        'loading="lazy" class="gallery-thumb"><div class="image-name">$display</div></div></div>');
  }

  final titleCss = titleOption == '2' ? _titleBelow : _titleOverlay;

  return _galleryTemplate
      .replaceAll('__TITLE_CSS__', titleCss)
      .replaceAll('__DIRNAME__', _esc(dirName))
      .replaceAll('__TOTAL__', '${items.length}')
      .replaceAll('__THUMBS__', thumbs.toString())
      // keep "</" out of the inline script
      .replaceAll('__IMAGES_JSON__', jsonEncode(images).replaceAll('</', r'<\/'))
      .replaceAll('__TITLE_OPTION__', titleOption)
      .replaceAll('__DIRNAME_JS__', jsonEncode(dirName).replaceAll('</', r'<\/'));
}

String generateIndexHtml(Map<String, int> galleries) {
  final links = StringBuffer();
  galleries.forEach((name, count) {
    links.writeln('''
 <a href="${Uri.encodeComponent(name)}/index.html" class="gallery-link">
   <div class="gallery-header">
     <div class="gallery-title">${_esc(name)}</div>
     <div class="gallery-count">$count images</div>
   </div>
 </a>''');
  });
  return _indexTemplate
      .replaceAll('__LINKS__', links.toString())
      .replaceAll('__GENERATED__', DateTime.now().toString());
}

const _titleBelow = r'''
.container .item .image-name {
  position: relative;
  color: #f1f1f1;
  font-size: 11px;
  padding: 4px 6px;
  margin-top: 4px;
  background: rgba(0, 0, 0, 0.5);
  border-radius: 4px;
}''';

const _titleOverlay = r'''
.container .item .image-name {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  color: #f1f1f1;
  font-size: 11px;
  padding: 4px 6px;
  border-radius: 0 0 .75rem .75rem;
  text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.8);
}''';

const _galleryTemplate = r'''<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="icon" href="data:,">
<title>Gallery - __DIRNAME__</title>
<style>
body {background-color: #212121;}
.container {position: relative; margin: 5px auto 0; padding: 2rem;}
.container .item {position: absolute; text-align: center; cursor: pointer; transition: transform 0.2s ease; visibility: hidden;}
.container .item.positioned {visibility: visible;}
.container .item .image-wrapper {position: relative; display: block; width: 100%;}
.container .item img {width: 100%; height: 100%; border-radius: .75rem; display: block; object-fit: fill;}
.container .item img:hover {transform: scale(1.02)}
__TITLE_CSS__
.container .item .image-name {word-break: break-word; overflow-wrap: break-word; hyphens: auto; white-space: normal; line-height: 1.2;}
#scroll {height: 20px; position: fixed; bottom: 10px; right: 10px; background: rgba(34,34,34,0.8); color: rgb(0,255,38); padding: 2px 8px; border-radius: 3px; font-size: 12px; z-index: 100; backdrop-filter: blur(5px); pointer-events: none;}
.back-link {position: fixed; top: 10px; left: 10px; background: rgba(34,34,34,0.8); color: #f1f1f1; padding: 8px 12px; border-radius: 3px; text-decoration: none; font-size: 12px; z-index: 100; backdrop-filter: blur(5px);}
.back-link:hover {background: rgba(68,68,68,0.8);}
.theme-toggle, .slideshow-btn {position: fixed; right: 10px; background: rgba(34,34,34,0.8); color: #f1f1f1; border: none; padding: 8px 12px; border-radius: 3px; cursor: pointer; font-size: 16px; z-index: 100; backdrop-filter: blur(5px); transition: background 0.3s ease;}
.theme-toggle {top: 10px;}
.slideshow-btn {top: 45px;}
.theme-toggle:hover, .slideshow-btn:hover {background: rgba(68,68,68,0.8);}
body.light-mode {background-color: #f5f5f5;}
body.light-mode .container .item .image-name {color: #333; text-shadow: 1px 1px 2px rgba(255,255,255,0.8);}
body.light-mode .theme-toggle, body.light-mode .slideshow-btn, body.light-mode .back-link {background: rgba(255,255,255,0.9); color: #333;}
body.light-mode .theme-toggle:hover, body.light-mode .slideshow-btn:hover, body.light-mode .back-link:hover {background: rgba(230,230,230,0.9);}
body.light-mode #scroll {background: rgba(255,255,255,0.9); color: #333;}
.lightbox {display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.95); cursor: pointer; transition: background-color 0.3s ease;}
.lightbox-content {position: absolute; top: 0; left: 0; width: 100%; height: 100%; cursor: pointer;}
.lightbox-content img {width: 100%; height: 100%; object-fit: contain; transition: background-color 0.3s ease;}
.lightbox-content img[src$=".svg"] {background-color: #1a1a1a; padding: 20px; border-radius: 8px;}
body.light-mode .lightbox {background-color: rgba(255,255,255,0.95);}
body.light-mode .lightbox-content img[src$=".svg"] {background-color: #f5f5f5;}
#slideshow-container {position: fixed; top: 0; left: 0; width: 100vw; height: 100vh; background: #000; z-index: 2000; display: none;}
#slideshow-container:not(:empty) {display: block;}
.slideshow-slide {position: absolute; top: 0; left: 0; width: 100%; height: 100%; opacity: 0; transition: opacity 0.5s ease-in-out; overflow: hidden;}
.slideshow-slide.active {opacity: 1;}
.slideshow-slide img {position: absolute; top: 50%; left: 50%; width: 100%; height: 100%; transform: translate(-50%, -50%); object-fit: cover; will-change: transform;}
.slideshow-counter {position: fixed; bottom: 5px; left: 50%; transform: translateX(-50%); z-index: 2001; color: #f1f1f1; font-size: 12px;}
</style>
</head>
<body>
<a href="../index.html" class="back-link">← Back to Gallery Index</a>
<button class="theme-toggle" onclick="toggleTheme()">🌙</button>
<button class="slideshow-btn" onclick="startSlideshow()">▶️</button>
<div style="color:#f1f1f1;font-size:14px;text-align:center;padding:10px;background-color:#333;margin-bottom:10px;">
 <span style="color:#4caf50;font-weight:bold;">__TOTAL__ Images :</span> <span style="color:#ffd600;">← → spacebar</span> <span style="color:#fff;">previous / next image</span> <span style="color:#ffd600;">click image / ESC</span> <span style="color:#fff;">back to index</span>
</div>
<div id="scroll">scroll %</div>
<div class="container">
__THUMBS__
</div>
<div id="lightbox" class="lightbox">
<div class="lightbox-content"><img id="lightbox-img" src="" alt=""></div>
</div>
<div id="slideshow-container"></div>
<div id="slideshow-counter" class="slideshow-counter" style="display: none;"></div>
<script>
const images = __IMAGES_JSON__;
const GALLERY_NAME = __DIRNAME_JS__;
const TITLE_OPTION = '__TITLE_OPTION__';
let currentIndex = 0;
let layoutQueued = false;
let columnConfig = {columns: 1, columnWidth: 0, gap: 0};

const SLIDE_DURATION = 5000;
const PAN_AMOUNT = 0.12;
const ZOOM_START = 2.8;
const ZOOM_END = 1.3;

let currentSlideIndex = 0;
let currentSlidePattern = 1;
let slideTimer = null;
let shuffledSlideImages = [];
let isSlideshowPlaying = false;

function shuffleArray(array) {
  const arr = [...array];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function getKenBurnsPattern(pattern) {
  const patterns = {
    1: { startX: PAN_AMOUNT, startY: -PAN_AMOUNT, endX: -PAN_AMOUNT, endY: PAN_AMOUNT },
    2: { startX: PAN_AMOUNT, startY: 0, endX: -PAN_AMOUNT, endY: 0 },
    3: { startX: 0, startY: PAN_AMOUNT, endX: 0, endY: -PAN_AMOUNT },
    4: { startX: PAN_AMOUNT, startY: PAN_AMOUNT, endX: -PAN_AMOUNT, endY: -PAN_AMOUNT },
    5: { startX: -PAN_AMOUNT, startY: 0, endX: PAN_AMOUNT, endY: 0 },
    6: { startX: -PAN_AMOUNT, startY: -PAN_AMOUNT, endX: PAN_AMOUNT, endY: PAN_AMOUNT },
    7: { startX: 0, startY: -PAN_AMOUNT, endX: 0, endY: PAN_AMOUNT },
    8: { startX: -PAN_AMOUNT, startY: PAN_AMOUNT, endX: PAN_AMOUNT, endY: -PAN_AMOUNT }
  };
  return patterns[pattern];
}

function applyKenBurnsEffect(slide, pattern) {
  const img = slide.querySelector('img');
  const p = getKenBurnsPattern(pattern);
  const startPanX = p.startX * 100, startPanY = p.startY * 100;
  const endPanX = p.endX * 100, endPanY = p.endY * 100;
  const animationName = 'kenburns-' + pattern;
  const keyframes = '@keyframes ' + animationName + ' { 0% { transform: translate(calc(-50% + ' + startPanX + '%), calc(-50% + ' + startPanY + '%)) scale(' + ZOOM_START + '); } 75% { transform: translate(calc(-50% + ' + endPanX + '%), calc(-50% + ' + endPanY + '%)) scale(' + ZOOM_END + '); } 100% { transform: translate(calc(-50% + ' + endPanX + '%), calc(-50% + ' + endPanY + '%)) scale(' + ZOOM_END + '); } }';
  let styleSheet = document.getElementById('kenburns-styles');
  if (!styleSheet) {
    styleSheet = document.createElement('style');
    styleSheet.id = 'kenburns-styles';
    document.head.appendChild(styleSheet);
  }
  if (!styleSheet.textContent.includes(animationName)) styleSheet.textContent += keyframes;
  img.style.animation = animationName + ' ' + SLIDE_DURATION + 'ms ease-in-out forwards';
}

function showNextSlideInShow() {
  if (!isSlideshowPlaying) return;
  if (currentSlideIndex >= shuffledSlideImages.length) { stopSlideshow(); return; }
  const slideshowContainer = document.getElementById('slideshow-container');
  slideshowContainer.querySelectorAll('.slideshow-slide').forEach(slide => {
    if (slide.classList.contains('active')) {
      slide.classList.remove('active');
      setTimeout(() => slide.remove(), 500);
    } else slide.remove();
  });
  const slide = document.createElement('div');
  slide.className = 'slideshow-slide';
  const img = document.createElement('img');
  img.src = shuffledSlideImages[currentSlideIndex];
  img.alt = 'Slide ' + (currentSlideIndex + 1);
  slide.appendChild(img);
  slideshowContainer.appendChild(slide);
  img.onload = () => {
    requestAnimationFrame(() => {
      slide.classList.add('active');
      applyKenBurnsEffect(slide, currentSlidePattern);
    });
  };
  currentSlidePattern++;
  if (currentSlidePattern > 8) currentSlidePattern = 1;
  currentSlideIndex++;
  const counter = document.getElementById('slideshow-counter');
  if (counter) {
    counter.textContent = currentSlideIndex + '/' + shuffledSlideImages.length;
    counter.style.display = 'block';
  }
  slideTimer = setTimeout(showNextSlideInShow, SLIDE_DURATION);
}

function startSlideshow() {
  if (isSlideshowPlaying || images.length === 0) return;
  isSlideshowPlaying = true;
  currentSlideIndex = 0;
  currentSlidePattern = 1;
  shuffledSlideImages = shuffleArray(images);
  const c = document.getElementById('slideshow-container');
  if (c) c.innerHTML = '';
  const btn = document.querySelector('.slideshow-btn');
  if (btn) btn.style.display = 'none';
  const counter = document.getElementById('slideshow-counter');
  if (counter) counter.style.display = 'block';
  showNextSlideInShow();
}

function stopSlideshow() {
  isSlideshowPlaying = false;
  if (slideTimer) { clearTimeout(slideTimer); slideTimer = null; }
  const c = document.getElementById('slideshow-container');
  if (c) c.innerHTML = '';
  const counter = document.getElementById('slideshow-counter');
  if (counter) counter.style.display = 'none';
  const btn = document.querySelector('.slideshow-btn');
  if (btn) btn.style.display = 'block';
}

document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    if (isSlideshowPlaying) stopSlideshow();
    else if (lightbox.style.display === 'block') closeLightbox();
  }
  if (lightbox.style.display === 'block') {
    switch(e.key) {
      case 'ArrowLeft': showPrevious(); break;
      case 'ArrowRight':
      case ' ': e.preventDefault(); showNext(); break;
    }
  }
});

function updateColumnConfig() {
  const container = document.querySelector('.container');
  const width = window.innerWidth;
  let columns = 1;
  if (width >= 1792) columns = 7;
  else if (width >= 1536) columns = 6;
  else if (width >= 1280) columns = 5;
  else if (width >= 1024) columns = 4;
  else if (width >= 768) columns = 3;
  else if (width >= 512) columns = 2;
  const containerWidth = container.offsetWidth - 64;
  columnConfig = { columns, columnWidth: containerWidth / columns, gap: 0 };
}

function positionItem(item, columnHeights) {
  const img = item.querySelector('img');
  const imgWidth = parseInt(img.getAttribute('width'));
  const imgHeight = parseInt(img.getAttribute('height'));
  if (!imgWidth || !imgHeight) return false;
  const itemHeight = columnConfig.columnWidth * (imgHeight / imgWidth);
  const titleHeight = TITLE_OPTION === '2' ? 25 : 0;
  const minHeight = Math.min(...columnHeights);
  const minColumn = columnHeights.indexOf(minHeight);
  item.style.left = (minColumn * columnConfig.columnWidth) + 'px';
  item.style.top = columnHeights[minColumn] + 'px';
  item.style.width = columnConfig.columnWidth + 'px';
  item.querySelector('.image-wrapper').style.height = itemHeight + 'px';
  item.classList.add('positioned');
  columnHeights[minColumn] += itemHeight + titleHeight;
  return true;
}

function layoutItems() {
  if (layoutQueued) return;
  layoutQueued = true;
  requestAnimationFrame(() => {
    const container = document.querySelector('.container');
    const items = container.querySelectorAll('.item');
    updateColumnConfig();
    const columnHeights = new Array(columnConfig.columns).fill(0);
    items.forEach(item => positionItem(item, columnHeights));
    container.style.height = Math.max(...columnHeights) + 'px';
    layoutQueued = false;
  });
}

document.addEventListener('scroll', function(){
  var h = document.documentElement, b = document.body, st = 'scrollTop', sh = 'scrollHeight';
  var percent = ((h[st]||b[st]) / ((h[sh]||b[sh]) - h.clientHeight) * 100).toFixed(1);
  document.getElementById('scroll').textContent = percent + '%';
});

const lightbox = document.getElementById('lightbox');
const lightboxImg = document.getElementById('lightbox-img');
let savedScrollPosition = 0;
let originalThumbnailElement = null;

document.querySelectorAll('.item').forEach(item => {
  item.addEventListener('click', function() {
    const thumb = this.querySelector('.gallery-thumb');
    if (thumb) {
      savedScrollPosition = window.pageYOffset;
      originalThumbnailElement = this;
      currentIndex = parseInt(thumb.dataset.index);
      showImage(currentIndex);
      lightbox.style.display = 'block';
    }
  });
});

lightboxImg.addEventListener('click', function(e) { e.stopPropagation(); closeLightbox(); });
lightbox.addEventListener('click', function(e) { if (e.target === lightbox) closeLightbox(); });

function showImage(index) {
  if (index >= 0 && index < images.length) {
    lightboxImg.src = images[index];
    currentIndex = index;
    const imageName = images[index].split('/').pop().split('.')[0];
    const displayName = imageName.replace(/_/g, ' ').replace(/^\d+\s*/, '');
    document.title = displayName + ' - Gallery - ' + GALLERY_NAME;
  }
}
function showNext() { if (currentIndex + 1 < images.length) showImage(currentIndex + 1); }
function showPrevious() { if (currentIndex - 1 >= 0) showImage(currentIndex - 1); }

function closeLightbox() {
  lightbox.style.display = 'none';
  document.title = 'Gallery - ' + GALLERY_NAME;
  const thumbnails = document.querySelectorAll('.gallery-thumb');
  if (currentIndex >= 0 && currentIndex < images.length && thumbnails[currentIndex]) {
    const target = thumbnails[currentIndex].closest('.item');
    if (target && target !== originalThumbnailElement) {
      target.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } else {
      window.scrollTo({ top: savedScrollPosition, behavior: 'smooth' });
    }
  } else {
    window.scrollTo({ top: savedScrollPosition, behavior: 'smooth' });
  }
}

function toggleTheme() {
  const body = document.body;
  const toggle = document.querySelector('.theme-toggle');
  try {
    if (body.classList.contains('light-mode')) {
      body.classList.remove('light-mode'); toggle.textContent = '🌙'; localStorage.setItem('theme', 'dark');
    } else {
      body.classList.add('light-mode'); toggle.textContent = '☀️'; localStorage.setItem('theme', 'light');
    }
  } catch (e) {}
}

document.addEventListener('DOMContentLoaded', function() {
  const toggle = document.querySelector('.theme-toggle');
  let saved = null;
  try { saved = localStorage.getItem('theme'); } catch (e) {}
  if (saved === 'light') { document.body.classList.add('light-mode'); toggle.textContent = '☀️'; }
  else toggle.textContent = '🌙';
});

window.addEventListener('load', () => { layoutItems(); });

let resizeTimeout;
window.addEventListener('resize', () => {
  clearTimeout(resizeTimeout);
  resizeTimeout = setTimeout(() => { layoutItems(); }, 150);
});
</script>
</body>
</html>''';

const _indexTemplate = r'''<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="icon" href="data:,">
<title>Gallery Index</title>
<style>
body {background-color: #212121; color: #f1f1f1; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; transition: background-color 0.3s ease, color 0.3s ease;}
.container {max-width: 800px; margin: 0 auto; padding: 20px;}
h1 {text-align: center; color: #f1f1f1; margin-bottom: 30px;}
.gallery-links {display: grid; gap: 20px; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));}
.gallery-link {background: rgba(68,68,68,0.3); border: 1px solid rgba(255,255,255,0.1); border-radius: 8px; padding: 20px; text-decoration: none; color: #f1f1f1; transition: all 0.3s ease; display: block;}
.gallery-link:hover {background: rgba(68,68,68,0.5); transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,0.3);}
.gallery-header {display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;}
.gallery-title {font-size: 18px; font-weight: bold; text-transform: capitalize;}
.gallery-count {font-size: 14px; color: #999; background: rgba(0,0,0,0.3); padding: 4px 8px; border-radius: 4px;}
.timestamp {text-align: center; color: #666; font-size: 12px; margin-top: 30px;}
.theme-toggle {position: fixed; top: 20px; right: 20px; background: rgba(34,34,34,0.8); color: #f1f1f1; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; font-size: 16px; z-index: 100; backdrop-filter: blur(5px);}
body.light-mode {background-color: #f5f5f5; color: #333;}
body.light-mode h1 {color: #333;}
body.light-mode .gallery-link {background: rgba(255,255,255,0.9); border: 1px solid rgba(0,0,0,0.1); color: #333;}
body.light-mode .gallery-count {background: rgba(0,0,0,0.05); color: #666;}
body.light-mode .timestamp {color: #999;}
body.light-mode .theme-toggle {background: rgba(255,255,255,0.9); color: #333;}
</style>
</head>
<body>
<button class="theme-toggle" onclick="toggleTheme()">🌙</button>
<div class="container">
<h1>AVIF Masonry Gallery Index</h1>
<div class="gallery-links">
__LINKS__
</div>
<div class="timestamp">Generated on __GENERATED__</div>
</div>
<script>
function toggleTheme() {
  const body = document.body, toggle = document.querySelector('.theme-toggle');
  try {
    if (body.classList.contains('light-mode')) { body.classList.remove('light-mode'); toggle.textContent = '🌙'; localStorage.setItem('theme', 'dark'); }
    else { body.classList.add('light-mode'); toggle.textContent = '☀️'; localStorage.setItem('theme', 'light'); }
  } catch (e) {}
}
document.addEventListener('DOMContentLoaded', function() {
  const toggle = document.querySelector('.theme-toggle');
  let saved = null;
  try { saved = localStorage.getItem('theme'); } catch (e) {}
  if (saved === 'light') { document.body.classList.add('light-mode'); toggle.textContent = '☀️'; }
  else toggle.textContent = '🌙';
});
</script>
</body>
</html>''';
