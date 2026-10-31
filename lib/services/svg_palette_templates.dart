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
.row.two button{flex:1 1 110px}
button,select,.btn{background:#2d2d31;color:#eee;border:1px solid #444;border-radius:6px;padding:6px 10px;font:inherit;cursor:pointer;text-decoration:none}
button:hover,.btn:hover{background:#3a3a40}
small{color:#fff}
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
.top{display:flex;align-items:flex-start;justify-content:space-between;gap:8px}
.top button{flex:none}
</style>
</head>
<body>
<header><a href="../index.html">&larr; Gallery</a><b>__NAME__</b><span class="tag">__TAGLABEL__</span></header>
<div id="stage" data-bg="dark">
__SVG__
</div>
<aside>
  <div class="top"><div id="swatches"></div><button id="bg">Background</button></div>
  <div id="pick">
    <button id="pickbtn" type="button" aria-haspopup="listbox"><span class="mini" id="pickmini"></span><span id="pickname">Original</span><span class="caret">&#9662;</span></button>
    <div id="picklist" role="listbox" hidden></div>
  </div>
  <div class="row"><button id="prev" title="P">&lsaquo; (P)rev palette</button><button id="next" title="N">(N)ext palette &rsaquo;</button></div>
  <div class="row"><button id="random">Random palette (space)</button></div>
  <div class="row"><button id="move" title="Space">(M)ove colors</button><button id="fav">&#9734; (F)avorite</button></div>
  <div class="row"><button id="flip">(C)olors Flip</button><button id="reset">(R)eset</button></div>
  <div id="favs"></div>
  <div class="row"><button id="strokeplay">&#9654; (A)nimated Stroke</button></div>
  <div class="row"><button id="stroke">(S)ave Animated svg</button></div>
  <small>Drag the color boxes to reorder them. Slot 1 is the darkest color, the last slot the lightest. A palette is applied dark to light; Move colors (Space) shifts every color one slot along.<br>
  The original colors are the first favorite (remove it with &times; if you don't want it). Save up to 5 (F)avorites.<br>
  "(A)nimated Stroke" previews the stroke-draw reveal: each group's outline draws in, then its fill fades in. With two or more favorites the colors then cross-fade through them and back to the first; with just one favorite in the list it holds that one. "(S)ave Animated Stroke svg" downloads that animation for use in a browser.</small>
</aside>
<script src="../palettes.js"></script>
<script>
const defaults=[__DEFAULTS__];
const K=defaults.length;
const SLOTMAP=__SLOTMAP__;   // original colour (#rrggbb) -> slot index, SVG sources only
const SHAPES='path,rect,circle,ellipse,polygon,polyline,line';
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
function set(p){
  if(strokeShown()) stopStroke();   // a held Stroke frame would hide the new colors
  cur=p.slice();apply();
}

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
  else if(e.key==='r'||e.key==='R'){curIdx=-1;usePalette({name:'Original',colors:defaults.slice()});highlight();}
  else if(e.key==='m'||e.key==='M'){moveColors();}
  else if(e.key==='c'||e.key==='C'){set(cur.slice().reverse());}
  else if(e.key==='f'||e.key==='F'){addFavorite();}
  else if(e.key==='a'||e.key==='A'){toggleStroke();}
  else if(e.key==='s'||e.key==='S'){saveStroke();}
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
      strokePlayBtn=document.getElementById('strokeplay'), strokeBtn=document.getElementById('stroke');
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
  strokePlayBtn.title='A'; strokeBtn.title='S';
}
function addFavorite(){
  if(allFavs().length>=MAXFAV||allFavs().some(f=>f.join()===cur.join())) return;
  favs.push(cur.slice()); saveFavs();
}
favBtn.onclick=addFavorite;

// ---- stroke reveal: each group's outline draws in, its fill fades in, then favorites cycle ----
const strokeDraw=1.0, strokeOverlap=33;   // seconds per group, % of a group's draw time that overlaps the next

// One timeline shared by the preview and the export.
// Group g starts at g * draw * (1 - overlap). Its fill fades in right after its own draw ends.
function strokeTimes(nFav,K,draw,overlap){
  const FADE=0.6, HOLD=3.0, XFADE=0.5;
  const starts=Array.from({length:K},(_,g)=>g*draw*(1-overlap/100));
  const intro=starts[K-1]+draw+FADE;                       // last group's fill has finished
  const slices=nFav>1?nFav+1:1;                            // favorites + encore of the first
  const total=intro+(slices>1?(slices-1)*HOLD:0);          // one favorite: nothing to wait for after the fills
  return {FADE,HOLD,XFADE,starts,intro,slices,total};
}
function strokeWidthPx(){
  const vb=svg.viewBox&&svg.viewBox.baseVal;
  const m=vb&&vb.width?Math.max(vb.width,vb.height):512;
  return +(2*m/512).toFixed(2);                            // 2px at the default 512px trace
}
function strokeFavs(){
  // Identical favorites (e.g. a saved one equal to the original) would only add a hold and a no-op fade.
  // Every favorite in the list takes part, the first one (normally the original colors) draws the
  // strokes, the others cross-fade in turn and it ends back on the first.
  const pool=allFavs();
  const seen=new Set(), F=[];
  pool.map(f=>fit(f,K)).forEach(f=>{const k=f.join();if(!seen.has(k)){seen.add(k);F.push(f);}});
  return F.length?F:[cur.slice()];
}
// Traced SVGs only hold <path>; SVG sources may hold any basic shape (tagged .sk / .cN by tagSlots()).
function shapeSel(scope,suffix){
  return (imported?SHAPES.split(','):['path']).map(t=>scope+t+suffix).join(',');
}
// [scope] prefixes every selector (the live preview uses '#stage svg '; the export uses none).
function strokeCascadeCSS(F,K,draw,overlap,sw,scope){
  scope=scope||'';
  const T=strokeTimes(F.length,K,draw,overlap);
  const slices=F.length>1?F.concat([F[0]]):F.slice();
  const pct=s=>(100*s/T.total).toFixed(4)+'%';
  const sec=s=>s.toFixed(3)+'s';
  const out=[];

  out.push(shapeSel(scope,imported?'.sk':'')+'{stroke-linecap:butt;stroke-linejoin:bevel;stroke-width:'+sw+
           ';stroke-dasharray:1;stroke-dashoffset:1}');
  if(imported) out.push(shapeSel(scope,'.so')+'{stroke-dasharray:1;stroke-dashoffset:1}');
  out.push('@keyframes sk-draw{to{stroke-dashoffset:0}}');
  out.push('@keyframes sk-fillin{from{fill-opacity:0}to{fill-opacity:1}}');
  // The outline only exists to draw the shape in. Once a group's fill is in it fades away, so the final
  // frame is the plain fill (an outline in the fill colour would swell every shape and blur fine detail).
  out.push('@keyframes sk-strokeout{to{stroke-opacity:0}}');

  for(let g=1;g<=K;g++){
    const start=T.starts[g-1];
    const drawA='sk-draw '+sec(draw)+' ease-out '+sec(start)+' both';
    const fillA='sk-fillin '+sec(T.FADE)+' ease-in '+sec(start+draw)+' both';
    const colA='sk-col-c'+g+' '+sec(T.total)+' linear both';
    const outA='sk-strokeout 0.5s ease-in-out '+sec(start+draw+T.FADE)+' both';
    // seam-free mode: the stroke draws on every path in the group; fill + colour live on the <g>
    out.push(scope+'g#c'+g+' path{animation:'+drawA+'}');
    out.push(scope+'g#c'+g+'{fill-opacity:0;animation:'+fillA+','+colA+','+outA+'}');
    // SVG sources, stroke-only shapes (fill none): draw, and cross-fade only the stroke (keep their own width)
    if(imported) out.push(shapeSel(scope,'.so'+g)+'{animation:'+drawA+',sk-scol-c'+g+' '+sec(T.total)+' linear both}');
    // stacked mode: each path carries class cN and gets everything itself
    if(imported){
      // SVG sources: shapes that had a stroke of their own (.ns = "no stroke" is missing) keep it
      out.push(shapeSel(scope,'.c'+g+':not(.ns)')+'{fill-opacity:0;animation:'+drawA+','+fillA+','+colA+'}');
      out.push(shapeSel(scope,'.c'+g+'.ns')+'{fill-opacity:0;animation:'+drawA+','+fillA+','+colA+','+outA+'}');
    }else{
      out.push(shapeSel(scope,'.c'+g)+'{fill-opacity:0;animation:'+drawA+','+fillA+','+colA+','+outA+'}');
    }

    // colour track: fill and stroke together, real crossfade between favorites
    // (stroke-only shapes of SVG sources get the same track with the stroke alone)
    const tracks=[['sk-col-c',c=>'fill:'+c+';stroke:'+c]];
    if(imported) tracks.push(['sk-scol-c',c=>'stroke:'+c]);
    tracks.forEach(([name,decl])=>{
      out.push('@keyframes '+name+g+'{');
      out.push('0%{'+decl(slices[0][g-1])+'}');
      for(let f=1;f<slices.length;f++){
        const t=T.intro+T.HOLD*f-T.XFADE;
        const prev=slices[f-1][g-1], next=slices[f][g-1];
        out.push(pct(t)+'{'+decl(prev)+'}');
        out.push(pct(t+T.XFADE)+'{'+decl(next)+'}');
      }
      out.push('100%{'+decl(slices[slices.length-1][g-1])+'}');
      out.push('}');
    });
  }
  return out.join('');
}

let strokeTimer=null, strokeOn=false;
function strokeShown(){return !!document.getElementById('stroke-prev-style');}
// Back to the plain colored shapes (user pressed Stop, changed the palette, or started the other preview).
function stopStroke(){
  if(strokeTimer){clearTimeout(strokeTimer);strokeTimer=null;}
  strokeOn=false;
  const st=document.getElementById('stroke-prev-style'); if(st) st.remove();
  strokePlayBtn.innerHTML='&#9654; (A)nimated Stroke';
}
// The animation reached its end: leave the final frame on screen (exactly what the exported SVG holds)
// instead of snapping back. The button becomes "replay"; changing the palette clears it.
function finishStroke(){
  strokeTimer=null; strokeOn=false;
  strokePlayBtn.innerHTML='&#9654; (A)nimated Stroke';
}
function startStroke(){
  const old=document.getElementById('stroke-prev-style'); if(old) old.remove();
  svg.querySelectorAll(SHAPES).forEach(p=>p.setAttribute('pathLength','1'));
  void svg.getBoundingClientRect();                        // flush so the animation restarts from 0
  const F=strokeFavs();
  const st=document.createElement('style'); st.id='stroke-prev-style';
  st.textContent=strokeCascadeCSS(F,K,strokeDraw,strokeOverlap,strokeWidthPx(),'#stage svg ');
  document.head.appendChild(st);
  strokeOn=true;
  strokePlayBtn.innerHTML='&#9632; (A) Stop Animation';
  if(strokeTimer) clearTimeout(strokeTimer);
  strokeTimer=setTimeout(finishStroke,(strokeTimes(F.length,K,strokeDraw,strokeOverlap).total+0.1)*1000);
}
function toggleStroke(){ if(strokeOn) stopStroke(); else startStroke(); }
function saveStroke(){ exportSVG('stroke'); }
strokePlayBtn.onclick=toggleStroke;

const NS='http://www.w3.org/2000/svg';
const imported=svg.getAttribute('data-input')==='svg';
function exportSVG(mode){
  const clone=svg.cloneNode(true);
  clone.removeAttribute('style'); clone.removeAttribute('class'); clone.removeAttribute('data-input');
  const ttl=document.createElementNS(NS,'title');
  ttl.textContent='__NAME__-animated-stroke';
  clone.insertBefore(ttl,clone.firstChild);
  if(mode==='stroke'){
    if(!imported) clone.querySelectorAll('style').forEach(s=>s.remove());   // SVG sources keep theirs (classes, gradients)
    clone.querySelectorAll(SHAPES).forEach(p=>p.setAttribute('pathLength','1'));
    const st=document.createElementNS(NS,'style');
    st.textContent=strokeCascadeCSS(strokeFavs(),K,strokeDraw,strokeOverlap,strokeWidthPx(),'');
    clone.insertBefore(st,ttl.nextSibling);
  }
  let xml=new XMLSerializer().serializeToString(clone);
  const blob=new Blob([xml],{type:'image/svg+xml'});
  const url=URL.createObjectURL(blob);
  const a=document.createElement('a');
  a.href=url; a.download='__NAME__-animated-stroke.svg';
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(()=>URL.revokeObjectURL(url),60000);
}
strokeBtn.onclick=saveStroke;

// SVG sources: put every flat-filled shape into its colour slot (class cN) so the stroke reveal can
// treat the slots as groups. Shapes with no flat fill (gradients, patterns, stroke-only, text) stay
// as they are.
function nearestSlot(hex){
  const v=h=>[1,3,5].map(i=>parseInt(h.slice(i,i+2),16));
  const c=v(hex); let best=0,bd=1e9;
  defaults.forEach((d,i)=>{const p=v(d),dd=(c[0]-p[0])**2+(c[1]-p[1])**2+(c[2]-p[2])**2; if(dd<bd){bd=dd;best=i;}});
  return best;
}
function slotOfCss(c){
  const m=c&&c.indexOf('rgb')===0?c.match(/\d+(\.\d+)?/g):null;
  if(!m||m.length<3) return -1;
  const hex='#'+m.slice(0,3).map(n=>Math.round(+n).toString(16).padStart(2,'0')).join('');
  return Object.prototype.hasOwnProperty.call(SLOTMAP,hex)?SLOTMAP[hex]:nearestSlot(hex);
}
function tagSlots(){
  svg.querySelectorAll(SHAPES).forEach(el=>{
    if(el.closest('defs,clipPath,mask,symbol,pattern,marker')) return;
    const cs=getComputedStyle(el);
    const fs=slotOfCss(cs.fill);
    if(fs>=0){
      el.classList.add('c'+(fs+1),'sk');
      if(cs.stroke==='none'||!(parseFloat(cs.strokeWidth)>0)) el.classList.add('ns');   // no stroke of its own
      return;
    }
    // No flat fill: a line / outline shape. Follow its stroke colour and animate only the stroke.
    const ss=slotOfCss(cs.stroke);
    if(ss>=0&&parseFloat(cs.strokeWidth)>0) el.classList.add('so','so'+(ss+1));
  });
}
if(imported) tagSlots();

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
.bar{position:sticky;top:0;z-index:2;display:flex;flex-wrap:wrap;gap:8px;align-items:center;padding:10px 16px;background:#1b1b1dee;border-bottom:1px solid #333;backdrop-filter:blur(8px)}
.bar button{background:#2d2d31;color:#eee;border:1px solid #444;border-radius:6px;padding:5px 12px;font:inherit;cursor:pointer}
.bar button.on{background:#e8e8ee;color:#111}
.bar span{margin-left:auto;color:#888}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px;padding:16px}
.card{background:#2a2a2e;border-radius:10px;overflow:hidden;display:flex;flex-direction:column}
.card a,.card .pic{display:flex;align-items:center;justify-content:center;aspect-ratio:1;background:#2a2a2e;padding:8px}
.card img{width:100%;height:100%;object-fit:contain}
.card a:hover{outline:2px solid #5a6fb8;outline-offset:-2px}
.card .pic{position:relative}
.ocr{position:absolute;left:0;right:0;bottom:0;margin:0;padding:6px 10px;white-space:pre-wrap;word-break:break-word;font:13px/1.4 ui-monospace,Menlo,monospace;color:#fff;background:rgba(20,20,22,.78);backdrop-filter:blur(4px);cursor:copy;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;transition:background .2s}
.ocr:hover{background:rgba(44,44,49,.88)}
.ocr.done{background:rgba(46,125,50,.9)}
.meta{display:flex;align-items:center;gap:8px;padding:6px 8px}
.tag{font-size:11px;background:#3a3a40;border-radius:4px;padding:0 6px}
.dots{display:flex;gap:2px}
.size{margin-right:auto;font-size:11px;color:#999;white-space:nowrap}
.dots i{width:9px;height:9px;border-radius:50%;display:block}
.star{background:none;border:0;color:#555;font-size:18px;cursor:pointer;padding:0}
.card.starred .star{color:#f5c542}
.hide{display:none}
</style>
</head>
<body>
<div class="bar">
  <button data-f="all" class="on">All</button>
  <button data-f="orig">Original</button>
  <button data-f="ocr">Text</button>
  <button data-f="bg">With background</button>
  <button data-f="cut">(cut) Background removed</button>
  <button data-f="crop">Smart crop</button>
  <button data-f="face">Faces</button>
  <button data-f="mask">Masks</button>
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
try{const f=localStorage.getItem(FKEY); if(['all','orig','ocr','bg','cut','crop','face','mask','svg','star'].includes(f)) filter=f;}catch(e){}
function render(){
  let n=0;
  cards.forEach(c=>{
    c.classList.toggle('starred',stars.has(c.dataset.name));
    const show=filter==='all'||(filter==='star'?stars.has(c.dataset.name):filter==='face'?c.dataset.tag.startsWith('face'):c.dataset.tag===filter);
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
// OCR cards: click the text to copy all of it (the card only shows two lines).
async function copyText(t){
  try{await navigator.clipboard.writeText(t);return true;}catch(e){}
  try{
    const ta=document.createElement('textarea'); ta.value=t; ta.style.position='fixed'; ta.style.opacity='0';
    document.body.appendChild(ta); ta.select(); const ok=document.execCommand('copy'); ta.remove(); return ok;
  }catch(e){return false;}
}
cards.forEach(c=>{
  const pre=c.querySelector('.ocr');
  if(!pre) return;
  pre.onclick=async()=>{
    if(String(getSelection()).length>0) return;   // dragging to select text does not copy
    const ok=await copyText(pre.textContent);
    pre.classList.toggle('done',ok); setTimeout(()=>pre.classList.remove('done'),700);
  };
});
render();
// Coming back from a page: restore the scroll position once the filtered layout exists.
try{history.scrollRestoration='manual';}catch(e){}
try{const y=parseInt(localStorage.getItem(SKEY)||'0',10); if(y>0) requestAnimationFrame(()=>window.scrollTo(0,y));}catch(e){}
addEventListener('pagehide',()=>{try{localStorage.setItem(SKEY,String(window.scrollY));}catch(e){}});
</script>
</body>
</html>''';
