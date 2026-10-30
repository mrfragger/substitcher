const String kThemePageTemplate = r'''<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="icon" href="data:,">
<title>__NAME__</title>
<style>
:root{color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;font:14px/1.4 -apple-system,system-ui,sans-serif;background:#1b1b1d;color:#eee;display:grid;grid-template-columns:1fr 290px;grid-template-rows:auto 1fr;height:100vh}
header{grid-column:1/-1;display:flex;gap:16px;align-items:center;padding:10px 16px;border-bottom:1px solid #333}
header a{color:#9bd}
header .tag{background:#333;border-radius:4px;padding:1px 8px;font-size:12px}
#stage{display:flex;align-items:center;justify-content:center;padding:24px;min-height:0;min-width:0;background:var(--bg,#2a2a2e)}
#stage[data-bg=light]{--bg:#f4f1ea}
#stage[data-bg=mid]{--bg:#8a8a90}
#stage[data-bg=check]{--bg:repeating-conic-gradient(#ccc 0 25%,#eee 0 50%) 50%/24px 24px}
#stage svg{width:100%;height:100%;max-width:100%;max-height:100%}
aside{padding:16px;border-left:1px solid #333;display:flex;flex-direction:column;gap:14px;overflow:auto}
#swatches{display:flex;gap:2px;flex-wrap:nowrap}
#swatches label{display:flex;flex-direction:column;align-items:center;gap:3px;font-size:11px;color:#aaa}
#swatches input{width:22px;height:18px;border:0;padding:0;background:none;cursor:pointer}
#swatches input::-webkit-color-swatch-wrapper{padding:0}
#swatches input::-webkit-color-swatch{border:0;border-radius:3px}
#swatches input::-moz-color-swatch{border:0;border-radius:3px}
.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
button,select,.btn{background:#2d2d31;color:#eee;border:1px solid #444;border-radius:6px;padding:6px 10px;font:inherit;cursor:pointer;text-decoration:none}
button:hover,.btn:hover{background:#3a3a40}
small{color:#888}
#pick{position:relative}
#pickbtn{display:flex;align-items:center;gap:8px;width:100%;text-align:left}
#pickname{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.caret{color:#999}
.mini{display:flex;gap:2px;flex:none}
.mini i{width:14px;height:14px;border-radius:3px;display:block}
#picklist{position:fixed;z-index:10;overflow:auto;background:#232326;border:1px solid #555;border-radius:8px;box-shadow:0 8px 24px #0008;padding:4px}
#picklist[hidden]{display:none}
.opt{display:flex;align-items:center;gap:8px;padding:4px 6px;border-radius:5px;cursor:pointer;white-space:nowrap}
.opt:hover{background:#34343a}
.opt.sel{background:#4a5fa8}
#swatches label{cursor:grab}
#swatches label.drag{opacity:.35}
#swatches label.over input{outline:2px solid #8ab4ff;outline-offset:2px}
svg.fade [class]{transition:fill 1.5s ease}
#favs{display:flex;flex-direction:column;gap:6px}
.fav{display:flex;align-items:center;gap:8px;padding:5px 8px;border:1px solid #444;border-radius:6px;cursor:pointer}
.fav:hover{background:#34343a}
.fav .mini i{width:22px;height:18px}
.fav .x{margin-left:auto;background:none;border:0;color:#999;padding:0 4px;font-size:16px}
button:disabled{opacity:.4;cursor:default}
</style>
</head>
<body>
<header><a href="../index.html">&larr; Gallery</a><b>__NAME__</b><span class="tag">__TAGLABEL__</span></header>
<div id="stage" data-bg="dark">
__SVG__
</div>
<aside>
  <div id="swatches"></div>
  <div id="pick">
    <button id="pickbtn" type="button" aria-haspopup="listbox"><span class="mini" id="pickmini"></span><span id="pickname">Original</span><span class="caret">&#9662;</span></button>
    <div id="picklist" role="listbox" hidden></div>
  </div>
  <div class="row"><button id="prev" title="P">&lsaquo; (P)rev palette</button><button id="next" title="N">(N)ext palette &rsaquo;</button></div>
  <div class="row"><button id="random">Random palette (space)</button></div>
  <div class="row"><button id="move" title="Space">(M)ove colors</button>
  <div class="row"><button id="flip">Flip</button><button id="reset">Reset</button></div>
  <div class="row"><button id="fav">&#9734; (F)avorite</button><button id="cycle">&#9654; (C)ycle favorites</button></div>
  <div id="favs"></div>
  <div class="row"><button id="bg">Background</button><button id="anim">Animated SVG</button></div>
  <div class="row"><button id="dl">Themed SVG</button><button id="themable">Themable SVG</button></div>
  <small>Drag the color boxes to reorder them. Slot 1 is the darkest color, the last slot the lightest. A palette is applied dark to light; Move colors (Space) shifts every color one slot along.<br>
  The original colors are the first favorite (remove it with &times; if you don't want it). Save up to 5 (F)avorites, then "(C)ycle favorites" previews them and "Animated SVG" downloads an SVG that fades to the next favorite every 9 seconds (for browsers).<br>
  "Themed SVG" downloads an SVG with the current colors baked in; "Themable SVG" downloads the original with CSS variables <code>--c1</code> &hellip; <code>--cN</code>.</small>
</aside>
<script src="../palettes.js"></script>
<script>
const defaults=[__DEFAULTS__];
const K=defaults.length;
const svg=document.querySelector('#stage svg');
let cur=defaults.slice();

const PALETTES=window.PALETTES||[];
const lum=h=>{const v=[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));return .2126*v[0]+.7152*v[1]+.0722*v[2];};
function interpolate(p,k){
  const rgb=p.map(h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16)));
  return Array.from({length:k},(_,i)=>{
    const t=k===1?0:i*(p.length-1)/(k-1), a=Math.floor(t), b=Math.min(a+1,p.length-1), f=t-a;
    return '#'+[0,1,2].map(c=>Math.round(rgb[a][c]*(1-f)+rgb[b][c]*f).toString(16).padStart(2,'0')).join('');
  });
}
// Fit a dark->light list to this image's slot count (some images have fewer than 10 slots).
function fit(p,k){
  if(k===p.length) return p.slice();
  if(k<p.length) return Array.from({length:k},(_,i)=>p[Math.round(i*(p.length-1)/Math.max(k-1,1))]);
  return interpolate(p,k);
}

const sw=document.getElementById('swatches'), inputs=[], labels=[];
let dragFrom=null;
const clearOver=()=>labels.forEach(l=>l.classList.remove('over','drag'));
for(let i=0;i<K;i++){
  const l=document.createElement('label'), inp=document.createElement('input');
  inp.type='color';
  inp.addEventListener('input',()=>{cur[i]=inp.value;apply();});
  l.draggable=true;
  l.addEventListener('dragstart',e=>{dragFrom=i;l.classList.add('drag');e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain',String(i));});
  l.addEventListener('dragend',()=>{dragFrom=null;clearOver();});
  l.addEventListener('dragover',e=>{e.preventDefault();e.dataTransfer.dropEffect='move';l.classList.add('over');});
  l.addEventListener('dragleave',()=>l.classList.remove('over'));
  l.addEventListener('drop',e=>{
    e.preventDefault();
    const from=dragFrom; dragFrom=null; clearOver();
    if(from===null||from===i) return;
    const c=cur.slice(); const x=c.splice(from,1)[0]; c.splice(i,0,x); set(c);
  });
  l.append(inp,document.createTextNode(String(i+1)));
  sw.append(l); inputs.push(inp); labels.push(l);
}
function apply(){
  cur.forEach((c,i)=>{svg.style.setProperty('--c'+(i+1),c); inputs[i].value=c;});
}
function set(p){cur=p.slice();apply();}

let curPal={name:'Original',colors:defaults.slice()}, curIdx=-1;
const btn=document.getElementById('pickbtn'), list=document.getElementById('picklist'),
      pname=document.getElementById('pickname'), pmini=document.getElementById('pickmini'), N=PALETTES.length;
const miniHTML=cols=>cols.map(c=>'<i style="background:'+c+'"></i>').join('');
pmini.innerHTML=miniHTML(defaults);

function usePalette(p){
  curPal=p; pname.textContent=p.name; pmini.innerHTML=miniHTML(p.colors);
  set(fit(p.colors.slice().sort((a,b)=>lum(a)-lum(b)),K));
}
function moveColors(){ if(K>1) set([cur[K-1]].concat(cur.slice(0,K-1))); }   // 1->2, 2->3 ... last->1

const opts=PALETTES.map((p,i)=>{
  const d=document.createElement('div'); d.className='opt'; d.setAttribute('role','option');
  const m=document.createElement('span'); m.className='mini'; m.innerHTML=miniHTML(p.colors);
  const n=document.createElement('span'); n.textContent=p.name;
  d.append(m,n);
  d.addEventListener('click',()=>{setIndex(i);closeList();});
  list.append(d); return d;
});
function highlight(){
  opts.forEach((o,i)=>o.classList.toggle('sel',i===curIdx));
  if(curIdx>=0&&!list.hidden) opts[curIdx].scrollIntoView({block:'nearest'});
}
function setIndex(i){ if(!N) return; curIdx=((i%N)+N)%N; usePalette(PALETTES[curIdx]); highlight(); }
function stepIndex(d){ setIndex(curIdx<0?(d>0?0:N-1):Math.min(N-1,Math.max(0,curIdx+d))); }
function openList(){
  if(!N) return;
  const r=btn.getBoundingClientRect();
  Object.assign(list.style,{left:r.left+'px',top:(r.bottom+4)+'px',width:r.width+'px',
    maxHeight:Math.max(160,Math.min(420,innerHeight-r.bottom-16))+'px'});
  list.hidden=false; highlight();
}
function closeList(){list.hidden=true;}
btn.addEventListener('click',()=>list.hidden?openList():closeList());
document.addEventListener('mousedown',e=>{if(!list.hidden&&!list.contains(e.target)&&!btn.contains(e.target))closeList();});
window.addEventListener('resize',closeList);
document.querySelector('aside').addEventListener('scroll',closeList);

function randomIndex(){
  if(N<2) return 0;
  let i; do{i=Math.floor(Math.random()*N);}while(i===curIdx);
  return i;
}
document.getElementById('random').onclick=()=>setIndex(randomIndex());
document.getElementById('move').onclick=moveColors;
document.getElementById('next').onclick=()=>setIndex(curIdx+1);
document.getElementById('prev').onclick=()=>setIndex(curIdx<0?N-1:curIdx-1);
document.getElementById('flip').onclick=()=>set(cur.slice().reverse());
document.getElementById('reset').onclick=()=>{curIdx=-1;usePalette({name:'Original',colors:defaults.slice()});highlight();};
const stage=document.getElementById('stage'), modes=['dark','mid','light','check'];
document.getElementById('bg').onclick=()=>{stage.dataset.bg=modes[(modes.indexOf(stage.dataset.bg)+1)%modes.length];};

document.addEventListener('keydown',e=>{
  const t=e.target.tagName;
  if(t==='INPUT'||t==='SELECT') return;
  if(N&&(!list.hidden||document.activeElement===btn)){
    const step={ArrowDown:1,ArrowUp:-1,PageDown:8,PageUp:-8}[e.key];
    if(step){e.preventDefault();stepIndex(step);return;}
    if(e.key==='Home'){e.preventDefault();setIndex(0);return;}
    if(e.key==='End'){e.preventDefault();setIndex(N-1);return;}
    if(!list.hidden&&(e.key==='Escape'||e.key==='Enter')){e.preventDefault();closeList();return;}
  }

  if(e.code==='Space'){e.preventDefault();setIndex(randomIndex());}
  else if(e.key==='n'||e.key==='N'){setIndex(curIdx+1);}
  else if(e.key==='p'||e.key==='P'){setIndex(curIdx<0?N-1:curIdx-1);}
  else if(e.key==='r'||e.key==='R'){setIndex(randomIndex());}
  else if(e.key==='m'||e.key==='M'){moveColors();}
  else if(e.key==='f'||e.key==='F'){addFavorite();}
  else if(e.key==='c'||e.key==='C'){toggleCycle();}
});

// ---- favorites (max 5, remembered in this browser) ----
const FAVKEY='svgpalette:favorites', MAXFAV=5;
let favs=[];
try{
  const f=JSON.parse(localStorage.getItem(FAVKEY)||'[]');
  if(Array.isArray(f)) favs=f.filter(a=>Array.isArray(a)&&a.length&&a.every(c=>/^#[0-9a-f]{6}$/i.test(c))).slice(0,MAXFAV);
}catch(e){}
// The image's original colors are always the first favorite until the user removes them (remembered per image).
const ORIGKEY='svgpalette:noorig:__NAME__';
let origOn=true;
try{ if(localStorage.getItem(ORIGKEY)==='1') origOn=false; }catch(e){}
const allFavs=()=>(origOn?[defaults.slice()]:[]).concat(favs);
const favBox=document.getElementById('favs'), favBtn=document.getElementById('fav'),
      cycleBtn=document.getElementById('cycle'), animBtn=document.getElementById('anim');
function saveFavs(){try{localStorage.setItem(FAVKEY,JSON.stringify(favs));}catch(e){} renderFavs();}
function renderFavs(){
  favBox.innerHTML='';
  const list=allFavs();
  list.forEach((f,i)=>{
    const isOrig=origOn&&i===0;
    const d=document.createElement('div'); d.className='fav'; d.title='Apply this favorite';
    const m=document.createElement('span'); m.className='mini'; m.innerHTML=miniHTML(f);
    const x=document.createElement('button'); x.className='x'; x.innerHTML='&times;'; x.title='Remove this favorite';
    x.addEventListener('click',e=>{
      e.stopPropagation();
      if(isOrig){origOn=false;try{localStorage.setItem(ORIGKEY,'1');}catch(err){} renderFavs();}
      else{favs.splice(i-(origOn?1:0),1);saveFavs();}
    });
    d.append(m,x);
    d.addEventListener('click',()=>{
      curPal={name:isOrig?'Original':'Favorite '+(i+(origOn?0:1)),colors:f.slice()}; curIdx=-1; highlight();
      pname.textContent=curPal.name; pmini.innerHTML=miniHTML(f);
      set(fit(f,K));
    });
    favBox.append(d);
  });
  const full=list.length>=MAXFAV;
  favBtn.disabled=full; favBtn.title=full?'5 favorites is the maximum. Remove one first.':'F';
  animBtn.disabled=list.length<2; animBtn.title='Needs at least 2 favorites';
  cycleBtn.disabled=list.length<2; cycleBtn.title=list.length<2?'Needs at least 2 favorites':'C';
  if(list.length<2) stopCycle();
}
function addFavorite(){
  if(allFavs().length>=MAXFAV||allFavs().some(f=>f.join()===cur.join())) return;
  favs.push(cur.slice()); saveFavs();
}
favBtn.onclick=addFavorite;

// ---- live preview: intro reveal, then cycle colors ----
let cycTimer=null, cycIdx=-1;

function startCycle(){
  const L = allFavs();
  if(L.length < 2) return;

  cycleBtn.innerHTML='&#9632; Stop cycling';
  cycIdx = 0;

  // 1. Apply the first favorite's colors immediately
  set(fit(L[0], K));

  // 2. Inject the intro reveal CSS dynamically
  let styleTag = document.getElementById('cycle-intro-style');
  if (!styleTag) {
    styleTag = document.createElement('style');
    styleTag.id = 'cycle-intro-style';
    document.head.appendChild(styleTag);
  }

  const introCss = `
    svg.cycling g[id^="c"] { opacity: 0; animation: intro-reveal 1s ease forwards; }
    svg.cycling #c1 { animation-delay: 0s; }
    svg.cycling #c2 { animation-delay: 1s; }
    svg.cycling #c3 { animation-delay: 2s; }
    svg.cycling #c4 { animation-delay: 3s; }
    svg.cycling #c5 { animation-delay: 4s; }
    @keyframes intro-reveal { to { opacity: 1; } }
    svg.cycling [class] { transition: fill 0.3s ease; }
  `;
  styleTag.textContent = introCss;

  // 3. Add the class to trigger the CSS
  svg.classList.add('cycling');

  // 4. Wait 8 seconds (5s reveal + 3s hold), then advance immediately and start the interval
  cycTimer = setTimeout(() => {
    const advance = () => {
      cycIdx++;
      const nextColors = fit(L[cycIdx % L.length], K);
      set(nextColors);

      if (cycIdx >= L.length) {
        stopCycle();
      }
    };

    advance(); // Fire immediately at t=8s
    cycTimer = setInterval(advance, 3000);
  }, 8000);
}

function stopCycle(){
  if(cycTimer){
    clearTimeout(cycTimer);
    clearInterval(cycTimer);
    cycTimer=null;
  }

  svg.classList.remove('cycling');
  cycleBtn.innerHTML='&#9654; (C)ycle favorites';

  // Clean up the injected CSS after a brief delay so the visual state doesn't jump
  setTimeout(() => {
    const styleTag = document.getElementById('cycle-intro-style');
    if (styleTag && !svg.classList.contains('cycling')) {
      styleTag.remove();
    }
  }, 100);
}

function toggleCycle(){
  if(allFavs().length<2) return;
  // If it's already running, stop it
  if (cycTimer || svg.classList.contains('cycling')) {
    stopCycle();
  } else {
    startCycle();
  }
}
cycleBtn.onclick=toggleCycle;


function revealCascadeCSS(F, K) {
  const REVEAL = 1.0;               // 1 second per group (5s total for 5 groups)
  const HOLD   = 3.0;               // 3 seconds to hold a color
  const slices = F.length > 1 ? F.concat([F[0]]) : F.slice(); // favorites + encore of F1

  // 1. Intro phase: 5s reveal
  const introDuration = K * REVEAL;

  // 2. First hold: wait 3s on favorite 1 before starting the cycle
  const cycleStart = introDuration + HOLD;

  // 3. Cycle phase: holds each color for HOLD seconds
  // Note: We subtract HOLD from the cycle length because the first favorite's hold
  // is already accounted for before the cycle officially starts.
  const cycleDuration = slices.length * HOLD;
  const total = introDuration + cycleDuration; // Same total duration

  const pct = s => (100 * s / total).toFixed(4) + '%';
  const out = [];

  // OPACITY TRACKS (Intro Reveal only)
  for (let g = 0; g < K; g++) {
    out.push('@keyframes reveal-c' + (g + 1) + '{');
    out.push('0%{opacity:0}');
    const start = g * REVEAL;
    const end = start + REVEAL;
    out.push(pct(start) + '{opacity:0}');
    out.push(pct(end)   + '{opacity:1}');
    out.push('100%{opacity:1}'); // stay visible for the rest of the animation
    out.push('}');
  }

  // FILL TRACKS (Intro + Hold + Cycle)
  for (let g = 0; g < K; g++) {
    out.push('@keyframes fill-c' + (g + 1) + '{');

    // A. Intro phase (reveal using Favorite 1)
    out.push('0%{fill:' + F[0][g] + '}');

    // B. The first Hold (3s) - we stay on F[0]
    out.push(pct(cycleStart) + '{fill:' + F[0][g] + '}');

    // C. Cycle phase
    for (let f = 0; f < slices.length; f++) {
      const start = cycleStart + (f * HOLD);
      const color = slices[f][g];

      // 300ms crossfade between colors
      const fade = 0.3;
      out.push(pct(start)        + '{fill:' + color + '}');
      out.push(pct(start + fade) + '{fill:' + color + '}');
    }
    out.push('}');
  }

  // BIND ANIMATIONS
  for (let g = 0; g < K; g++) {
    out.push('#c' + (g + 1) + '{animation:' +
      'reveal-c' + (g + 1) + ' ' + total + 's linear both,' +
      'fill-c'   + (g + 1) + ' ' + total + 's linear both}');
  }
  return out.join('');
}
const NS='http://www.w3.org/2000/svg';
const imported=svg.getAttribute('data-input')==='svg';
function exportSVG(mode){
  const clone=svg.cloneNode(true);
  clone.removeAttribute('style'); clone.removeAttribute('class'); clone.removeAttribute('data-input');
  const ttl=document.createElementNS(NS,'title');
  ttl.textContent='__NAME__-'+({baked:'themed',themable:'themable',animated:'animated'})[mode];
  clone.insertBefore(ttl,clone.firstChild);
  if(mode==='baked'&&!imported){
    // traced SVGs: swap the class/CSS-variable styling for plain fill attributes
    clone.querySelectorAll('style').forEach(s=>s.remove());
    clone.querySelectorAll('[class]').forEach(el=>{
      const m=(el.getAttribute('class')||'').match(/^c(\d+)$/);
      if(m){el.setAttribute('fill',cur[+m[1]-1]);el.removeAttribute('class');}
    });
  }
  if(mode==='animated'){
    clone.querySelectorAll('style').forEach(s=>s.remove());
    const st=document.createElementNS(NS,'style');
    st.textContent = revealCascadeCSS(allFavs().map(f=>fit(f,K)), K);
    clone.insertBefore(st,ttl.nextSibling);
  }
  let xml=new XMLSerializer().serializeToString(clone);
  if(mode==='baked') xml=xml.replace(/var\(--c(\d+),\s*#[0-9a-fA-F]{3,8}\)/g,(m,n)=>cur[+n-1]||m);
  const blob=new Blob([xml],{type:'image/svg+xml'});
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');
  a.href=url; a.download='__NAME__-'+({baked:'themed',themable:'themable',animated:'animated'})[mode]+'.svg';
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),60000);
}
document.getElementById('dl').onclick=()=>exportSVG('baked');
document.getElementById('themable').onclick=()=>exportSVG('themable');
animBtn.onclick=()=>{if(allFavs().length>=2) exportSVG('animated');};

renderFavs();
apply();
</script>
</body>
</html>''';

const String kGalleryPageTemplate = r'''<!doctype html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="icon" href="data:,">
<title>SVG Palette Gallery</title>
<style>
:root{color-scheme:dark}
body{margin:0;font:14px/1.4 -apple-system,system-ui,sans-serif;background:#1b1b1d;color:#eee}
.bar{position:sticky;top:0;z-index:2;display:flex;gap:8px;align-items:center;padding:10px 16px;background:#1b1b1dee;border-bottom:1px solid #333;backdrop-filter:blur(8px)}
.bar button{background:#2d2d31;color:#eee;border:1px solid #444;border-radius:6px;padding:5px 12px;font:inherit;cursor:pointer}
.bar button.on{background:#e8e8ee;color:#111}
.bar span{margin-left:auto;color:#888}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px;padding:16px}
.card{background:#2a2a2e;border-radius:10px;overflow:hidden;display:flex;flex-direction:column}
.card a{display:flex;align-items:center;justify-content:center;aspect-ratio:1;background:#2a2a2e;padding:8px}
.card img{width:100%;height:100%;object-fit:contain}
.card a:hover{outline:2px solid #5a6fb8;outline-offset:-2px}
.meta{display:flex;align-items:center;gap:8px;padding:6px 8px}
.tag{font-size:11px;background:#3a3a40;border-radius:4px;padding:0 6px}
.dots{display:flex;gap:2px;margin-right:auto}
.dots i{width:9px;height:9px;border-radius:50%;display:block}
.star{background:none;border:0;color:#555;font-size:18px;cursor:pointer;padding:0}
.card.starred .star{color:#f5c542}
.hide{display:none}
</style>
</head>
<body>
<div class="bar">
  <button data-f="all" class="on">All</button>
  <button data-f="bg">With background</button>
  <button data-f="cut">Background removed</button>
  <button data-f="svg">SVG sources</button>
  <button data-f="star">&#9733; Kept</button>
  <span id="count"></span>
</div>
<div class="grid">
__CARDS__
</div>
<script>
const KEY='svgpalette:'+location.pathname;
let stars=new Set();
try{stars=new Set(JSON.parse(localStorage.getItem(KEY)||'[]'));}catch(e){}
const save=()=>{try{localStorage.setItem(KEY,JSON.stringify([...stars]));}catch(e){}};
const cards=[...document.querySelectorAll('.card')];
const FKEY=KEY+':filter', SKEY=KEY+':scroll';
let filter='all';
try{const f=localStorage.getItem(FKEY); if(['all','bg','cut','svg','star'].includes(f)) filter=f;}catch(e){}
function render(){
  let n=0;
  cards.forEach(c=>{
    c.classList.toggle('starred',stars.has(c.dataset.name));
    const show=filter==='all'||(filter==='star'?stars.has(c.dataset.name):c.dataset.tag===filter);
    c.classList.toggle('hide',!show); if(show)n++;
  });
  document.querySelectorAll('.bar button').forEach(x=>x.classList.toggle('on',x.dataset.f===filter));
  document.getElementById('count').textContent=n+' shown · '+stars.size+' kept';
}
document.querySelectorAll('.bar button').forEach(b=>b.onclick=()=>{
  filter=b.dataset.f;
  try{localStorage.setItem(FKEY,filter);}catch(e){}
  render();
});
cards.forEach(c=>c.querySelector('.star').onclick=()=>{
  const n=c.dataset.name; stars.has(n)?stars.delete(n):stars.add(n); save(); render();
});
render();
// Coming back from a page: restore the scroll position once the filtered layout exists.
try{history.scrollRestoration='manual';}catch(e){}
try{const y=parseInt(localStorage.getItem(SKEY)||'0',10); if(y>0) requestAnimationFrame(()=>window.scrollTo(0,y));}catch(e){}
addEventListener('pagehide',()=>{try{localStorage.setItem(SKEY,String(window.scrollY));}catch(e){}});
</script>
</body>
</html>''';
