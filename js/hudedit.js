/* ═══ Editor de controles en pantalla: mover y agrandar volante, pedal, cambios, botones, velocímetro y mapa ═══
   Se abre desde la pausa. Tocar un control lo selecciona, arrastrar lo mueve, la barra cambia el tamaño.
   Se guarda como fracción de la pantalla (sirve en cualquier teléfono) y se aplica con las propiedades CSS
   "translate" y "scale", que se suman a la posición original sin romperla. El volante sigue girando igual:
   su centro se calcula con el rectángulo real en pantalla. */
export const HUD_ITEMS=[['steering','Volante'],['steerTrack','Barra de dirección'],['pedalSingle','Pedal'],['gearPad','Cambios'],
 ['handbrakeBtn','Freno de mano'],['nitroBtn','Nitro'],['speedPanel','Velocímetro'],['minimap','Mapa']];

export function applyHud(layout){for(const [id] of HUD_ITEMS){const el=document.getElementById(id);if(!el)continue;const L=layout&&layout[id];
 el.style.translate=L&&(L.x||L.y)?`${(L.x||0)*innerWidth}px ${(L.y||0)*innerHeight}px`:'';el.style.scale=L&&L.s&&L.s!==1?String(L.s):'';}}

let cssDone=false;
function css(){if(cssDone)return;cssDone=true;const s=document.createElement('style');s.textContent=`
#hudEdit{position:fixed;inset:0;z-index:70;background:rgba(4,8,14,.35);touch-action:none}
#hudEdit .hb{position:fixed;border:2px dashed rgba(255,255,255,.55);border-radius:10px;pointer-events:none;box-sizing:border-box}
#hudEdit .hb.sel{border:3px solid #ff7a1a;box-shadow:0 0 0 3px rgba(255,122,26,.25)}
#hudEdit .hb b{position:absolute;left:4px;top:-20px;font:800 11px system-ui,sans-serif;color:#fff;background:rgba(0,0,0,.6);padding:1px 6px;border-radius:6px;white-space:nowrap}
#hudEdit .bar{position:fixed;left:50%;top:calc(8px + env(safe-area-inset-top));transform:translateX(-50%);display:flex;align-items:center;gap:10px;padding:8px 12px;border-radius:14px;
 background:rgba(8,12,18,.92);color:#fff;font:700 13px system-ui,sans-serif;box-shadow:0 6px 20px #0008;pointer-events:auto;white-space:nowrap}
#hudEdit .bar input{width:150px;accent-color:#ff7a1a}
#hudEdit .bar button{border:0;border-radius:10px;padding:8px 12px;font:800 13px system-ui,sans-serif;color:#fff;background:#39414d}
#hudEdit .bar button.ok{background:linear-gradient(180deg,#ff7a1a,#d9480f)}
#hudEdit .hint{position:fixed;left:50%;bottom:calc(8px + env(safe-area-inset-bottom));transform:translateX(-50%);color:#fff;font:700 12px system-ui,sans-serif;background:rgba(0,0,0,.55);padding:5px 12px;border-radius:10px;pointer-events:none;text-align:center}`;
 document.head.appendChild(s);}

export class HudEditor{
 constructor(profile,onClose){this.P=profile;this.onClose=onClose;}
 get layout(){const s=this.P.d.settings;return s.hudLayout||(s.hudLayout={});}
 visible(){return HUD_ITEMS.filter(([id])=>{const el=document.getElementById(id);if(!el)return false;const r=el.getBoundingClientRect();return r.width>4&&r.height>4&&getComputedStyle(el).visibility!=='hidden';});}
 open(){css();const o=this.el=document.createElement('div');o.id='hudEdit';document.body.appendChild(o);this.sel=null;
  o.innerHTML=`<div class="bar"><span class="nm">Tocá un control</span><span>Tamaño</span><input type="range" min="50" max="220" step="5" value="100"><button data-a="reset">Restablecer</button><button class="ok" data-a="done">Listo</button></div><div class="hint">Arrastrá para mover · la barra cambia el tamaño · el volante sigue funcionando igual</div>`;
  this.bar=o.querySelector('.bar');this.rng=o.querySelector('input');this.nm=o.querySelector('.nm');
  this.bar.addEventListener('pointerdown',e=>e.stopPropagation());
  this.rng.addEventListener('input',()=>{if(!this.sel)return;const L=this.layout[this.sel]||(this.layout[this.sel]={x:0,y:0,s:1});L.s=this.rng.value/100;applyHud(this.layout);this.draw();});
  this.bar.addEventListener('click',e=>{const a=e.target.dataset&&e.target.dataset.a;if(a==='reset'){if(this.sel)delete this.layout[this.sel];else this.P.d.settings.hudLayout={};applyHud(this.layout);this.rng.value=100;this.draw();}if(a==='done')this.close();});
  o.addEventListener('pointerdown',e=>{e.preventDefault();const hit=this.visible().map(([id,n])=>[id,n,document.getElementById(id).getBoundingClientRect()]).filter(([,,r])=>e.clientX>=r.left-10&&e.clientX<=r.right+10&&e.clientY>=r.top-10&&e.clientY<=r.bottom+10)
    .sort((a,b)=>a[2].width*a[2].height-b[2].width*b[2].height)[0];
   if(!hit){this.select(null);return;}this.select(hit[0]);const L=this.layout[hit[0]]||(this.layout[hit[0]]={x:0,y:0,s:1});this.drag={id:e.pointerId,x0:e.clientX,y0:e.clientY,lx:L.x||0,ly:L.y||0};try{o.setPointerCapture(e.pointerId)}catch(_){}});
  o.addEventListener('pointermove',e=>{const d=this.drag;if(!d||d.id!==e.pointerId)return;const L=this.layout[this.sel];L.x=d.lx+(e.clientX-d.x0)/innerWidth;L.y=d.ly+(e.clientY-d.y0)/innerHeight;applyHud(this.layout);this.draw();});
  const up=()=>{this.drag=null;};o.addEventListener('pointerup',up);o.addEventListener('pointercancel',up);
  this.draw();}
 select(id){this.sel=id;const n=HUD_ITEMS.find(x=>x[0]===id);this.nm.textContent=n?n[1]:'Tocá un control';const L=id&&this.layout[id];this.rng.value=Math.round(((L&&L.s)||1)*100);this.rng.disabled=!id;this.draw();}
 draw(){if(!this.el)return;this.el.querySelectorAll('.hb').forEach(x=>x.remove());
  for(const [id,n] of this.visible()){const r=document.getElementById(id).getBoundingClientRect(),b=document.createElement('div');b.className='hb'+(id===this.sel?' sel':'');
   Object.assign(b.style,{left:r.left+'px',top:r.top+'px',width:r.width+'px',height:r.height+'px'});b.innerHTML=`<b>${n}</b>`;this.el.appendChild(b);}}
 close(){if(!this.el)return;this.P.save();this.el.remove();this.el=null;if(this.onClose)this.onClose();}
}
