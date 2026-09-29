/* ═══ Duelos en el mundo abierto ═══
   Los rivales de la historia viven en sus bases (trompos, saltos, ochos). Te acercás despacio → botón RETAR.
   Escena corta con voces (autos quietos), cuenta regresiva y a buscar arcos: sale uno por vez en el mapa,
   al pasarlo aparece el siguiente. El que pasa primero por todos gana; si ganás vos, cobrás. */
import * as THREE from 'three';
import {DUEL_RIVALS,TANO_DUEL,duelLineId} from './duel_data.js';
import {SPEAKERS} from './story_data.js';
import {StoryVoice,storyProgress} from './mission.js';

const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const ARCH_R=6.5,PASS_R=7.2,WAKE_R=280;

/* ─── piloto de campo abierto: de un punto a otro esquivando árboles y rocas; en su base hace acrobacias ─── */
export class FreeDriver{
 constructor(phys,track,o={}){this.p=phys;this.tr=track;this.skill=o.skill||0.9;this.base=o.base;this.stunt=o.stunt||'donas';this.ramp=o.ramp||null;
  this.inp={throttle:0,brake:0,steer:0,handbrake:false,nitro:false};this.mode='stunt';this.target=null;this.vmax=40;this.boost=1;
  this.stuckT=0;this.revT=0;this.stuckN=0;this.t=Math.random()*10;this.wp=0;this.passive=true;this.enabled=true;this.dir=Math.random()<0.5?-1:1;
  const V=phys.V;if(V.vGov)this.vmax=Math.min(this.vmax,V.vGov/3.6-1);
  /* recorrido de la acrobacia (saltos: ida por la rampa, vuelta por el costado · ocho: dos círculos) */
  const b=this.base,wp=this.wps=[];if(this.stunt==='saltos'&&this.ramp){const ax=Math.sin(this.ramp.yaw),az=Math.cos(this.ramp.yaw),lx=Math.cos(this.ramp.yaw),lz=-Math.sin(this.ramp.yaw);
   wp.push({x:b.x-ax*40,z:b.z-az*40,v:12,r:7},{x:b.x+ax*40,z:b.z+az*40,v:20,r:8},{x:b.x+lx*24+ax*10,z:b.z+lz*24+az*10,v:10,r:8},{x:b.x+lx*24-ax*22,z:b.z+lz*24-az*22,v:10,r:8});}
  else if(this.stunt==='ocho'){for(let i=0;i<8;i++){const s=i<4?1:-1,a=(i%4)/4*Math.PI*2*s,cx=b.x+s*11;wp.push({x:cx-s*Math.cos(a)*9,z:b.z+Math.sin(a)*9,v:11,r:5});}}}
 /* obstáculos adelante: devuelve cuánto torcer (positivo = izquierda) */
 avoid(fx,fz,lx,lz,sp,alphaT){const cols=this.tr.colliders;if(!cols)return 0;const p=this.p,L=Math.min(26,7+sp*1.1);let bias=0;const seen=this._seen||(this._seen=new Set());seen.clear();
  for(const dd of [4,L*0.5,L]){const cx=p.px+fx*dd,cz=p.pz+fz*dd,ix=Math.floor(cx/12),iz=Math.floor(cz/12);
   for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++){const k=(ix+a)+','+(iz+b);if(seen.has(k))continue;seen.add(k);const list=cols.get(k);if(!list)continue;
    for(const [ox,oz,r] of list){const dx=ox-p.px,dz=oz-p.pz,f=dx*fx+dz*fz,l=dx*lx+dz*lz;if(f<1||f>L)continue;const clr=r+1.7;if(Math.abs(l)>clr)continue;
     const w=(1-f/L)*(1-Math.abs(l)/clr);const side=Math.abs(l)<0.3?(alphaT>=0?1:-1):Math.sign(l);bias-=side*w*1.4;}}}
  return clamp(bias,-1.1,1.1);}
 steerTo(x,z,vt,h){const p=this.p,V=p.V,inp=this.inp,sp=Math.hypot(p.vx,p.vz);const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw);
  const dx=x-p.px,dz=z-p.pz;let alpha=Math.atan2(dx*lx+dz*lz,dx*fx+dz*fz);alpha+=this.avoid(fx,fz,lx,lz,sp,alpha);
  const slip=sp>4?Math.atan2(p.vLat||0,Math.max(1,Math.abs(p.vLong||0))):0;const delta=alpha*1.15+slip*0.5;
  const sf=p.steerScale?p.steerScale(sp):1-0.45*Math.min(1,sp/40);inp.steer=clamp(-delta/(V.maxSteer*sf),-1,1);
  const a=Math.abs(alpha),tv=Math.min(vt,a>1.3?6:a>0.7?11:a>0.35?18:vt),err=tv-sp;
  if(err>0){inp.throttle=Math.min(1,0.4+err*0.2);inp.brake=0;}else{inp.throttle=err>-1.5?0.2:0;inp.brake=err<-1.5?Math.min(1,-err*0.15):0;}
  inp.handbrake=false;inp.nitro=false;return alpha;}
 update(h){const p=this.p,inp=this.inp,sp=Math.hypot(p.vx,p.vz);this.t+=h;
  if(!this.enabled||this.mode==='hold'){inp.throttle=0;inp.brake=1;inp.steer=0;inp.handbrake=true;return inp;}
  /* destrabarse: marcha atrás girando al revés */
  if(this.revT>0){this.revT-=h;inp.throttle=0;inp.brake=1;inp.handbrake=false;inp.steer=-this.revS;return inp;}
  const b=this.base;
  if(this.mode==='duel'&&this.target){const al=this.steerTo(this.target.x,this.target.z,this.vmax*(0.86+0.14*this.skill)*this.boost,h);
   /* derrape con freno de mano en giros cerrados, como un piloto */
   if(Math.abs(al)>0.9&&sp>11){inp.handbrake=true;inp.throttle=Math.max(inp.throttle,0.5);inp.brake=0;}}
  else if(this.mode==='home'||Math.hypot(p.px-b.x,p.pz-b.z)>(this.stunt==='saltos'?60:26)){this.steerTo(b.x,b.z,14,h);if(Math.hypot(p.px-b.x,p.pz-b.z)<12)this.mode='stunt';}
  else if(this.stunt==='donas'){/* trompos: gas, volante a fondo y tirones de freno de mano */
   inp.throttle=0.85;inp.brake=0;inp.steer=this.dir;inp.handbrake=(this.t%2.6)<0.35;if(sp>13)inp.throttle=0.4;if((this.t%23)<0.02)this.dir=-this.dir;}
  else if(this.wps.length){const w=this.wps[this.wp%this.wps.length];const al=this.steerTo(w.x,w.z,w.v,h);
   if(this.stunt==='ocho'&&Math.abs(al)>0.6&&sp>8){inp.handbrake=true;inp.throttle=0.6;inp.brake=0;}
   if(Math.hypot(p.px-w.x,p.pz-w.z)<w.r)this.wp++;}
  else{inp.throttle=0;inp.brake=1;inp.handbrake=true;}
  /* ¿trabado? */
  if(sp<1.2&&inp.throttle>0.3&&!inp.handbrake)this.stuckT+=h;else this.stuckT=Math.max(0,this.stuckT-h*2);
  if(this.stuckT>1.4){this.stuckT=0;this.revT=1.3;this.revS=inp.steer||this.dir;this.stuckN++;}
  if(sp>6)this.stuckN=Math.max(0,this.stuckN-h*0.2);
  return inp;}
}

/* ─── rampa de la base (la física la pisa: OffroadTrack.rampY) ─── */
export function rampHeight(R,x,z){const ax=Math.sin(R.yaw),az=Math.cos(R.yaw),dx=x-R.x,dz=z-R.z;const u=dx*ax+dz*az,v=Math.abs(dx*az-dz*ax);
 const L=R.len,W=R.w/2;if(v>W+1.5||u<-L-1||u>5)return 0;let y;if(u<-1)y=R.h*(u+L+1)/L;else if(u<1)y=R.h;else y=R.h*(1-(u-1)/4);return y*clamp((W+1.5-v)/1.5,0,1);}

let cssDone=false;
function css(){if(cssDone)return;cssDone=true;const s=document.createElement('style');s.textContent=`
#duelBtn{position:fixed;left:50%;top:calc(104px + env(safe-area-inset-top));transform:translateX(-50%);z-index:24;display:none;padding:10px 18px;border-radius:24px;border:2px solid #fff3;
 background:linear-gradient(180deg,#ff7a1a,#d9480f);color:#fff;font:900 15px system-ui,sans-serif;letter-spacing:.5px;box-shadow:0 4px 18px #0008;pointer-events:auto}
#duelBtn.on{display:block;animation:duelPulse 1.2s ease-in-out infinite}#duelBtn.lock{background:linear-gradient(180deg,#4a4f58,#2c3037)}#duelBtn.stop{background:linear-gradient(180deg,#59606b,#343a42);animation:none;font-size:12px;padding:6px 12px;left:calc(12px + env(safe-area-inset-left));top:calc(88px + env(safe-area-inset-top));transform:none}
#duelBtn small{display:block;font:700 11px system-ui;opacity:.85}
@keyframes duelPulse{50%{transform:translateX(-50%) scale(1.06)}}
#duelHud{position:fixed;left:calc(12px + env(safe-area-inset-left));top:calc(48px + env(safe-area-inset-top));z-index:23;display:none;align-items:center;gap:10px;padding:6px 14px;border-radius:14px;
 background:rgba(8,12,18,.72);color:#fff;font:800 13px system-ui,sans-serif;pointer-events:none;white-space:nowrap}
#duelHud.on{display:flex}#duelHud .arr{width:30px;height:30px;display:flex;align-items:center;justify-content:center;font-size:24px;color:#ff3448;transition:transform .08s linear}
#duelHud .me{color:#ff8a3d}#duelHud .dist{opacity:.8;font-weight:700}
body.cine #duelHud,body.cine #duelBtn{visibility:hidden}`;document.head.appendChild(s);}

/* ═══ el administrador de duelos (hace de "director" de la sesión de mundo abierto) ═══ */
export class WorldDuels{
 constructor(g,S,api){this.g=g;this.S=S;this.api=api;this.t=0;this.duel=null;this.rivals=[];this.cool={};this.near=null;this.lockSaid={};this.userCam=g.getCam();
  css();const mk=(tag,id)=>{let e=document.getElementById(id);if(!e){e=document.createElement(tag);e.id=id;document.body.appendChild(e);}return e;};
  this.btn=mk('button','duelBtn');this.hud=mk('div','duelHud');this.hud.innerHTML='<span class="arr">▲</span><span class="txt"></span><span class="dist"></span>';
  this.btn.onclick=e=>{e.preventDefault();e.stopPropagation();this.press();};
  this.el={sub:document.getElementById('cineSub'),title:document.getElementById('cineTitle'),skip:document.getElementById('cineSkip')};
  const pv=S.player.phys.V;
  for(const R of DUEL_RIVALS){const car=api.makeCar(R.car,R.paint,R.name);const ph=car.phys,V=ph.V;
   /* mismo nivel que tu auto: igualar potencia/peso y el limitador */
   const pw=v=>api.pw(v);ph.powerMul=clamp(pw(pv)/pw(V),0.35,1.8)*(0.9+0.12*R.skill);V.vGov=pv.vGov||0;
   car.ai=new FreeDriver(ph,S.track,{skill:R.skill,base:{x:R.x,z:R.z},stunt:R.stunt,ramp:R.ramp?{...R.ramp,x:R.x,z:R.z}:null});
   ph.reset({x:R.x+(R.stunt==='saltos'?-Math.sin(R.ramp.yaw)*30:8),z:R.z+(R.stunt==='saltos'?-Math.cos(R.ramp.yaw)*30:0),yaw:R.ramp?R.ramp.yaw:0});car.rival=R;car.sleep=false;S.cars.push(car);this.rivals.push(car);}
  this.buildBases();this.buildArch();this.sleepCheck(true);}
 get voice(){if(!this.g.storyVoice)this.g.storyVoice=new StoryVoice();const v=this.g.storyVoice;if(!v.idx&&this.g.audio.ctx)v.load(this.g.audio.ctx);return v;}
 unlocked(R){if(!R.unlock)return true;const d=storyProgress(this.api.profile);return ((d.m[R.unlock]||{}).stars||0)>0;}
 wins(R){const st=this.api.profile.d.stats;return ((st.duels||{})[R.id]||0);}
 prize(R){return this.wins(R)?Math.round(R.reward*0.25/50)*50:R.reward;}
 /* ─── bases: ronda de cubiertas, cartel con el nombre, haz de luz de color y la rampa ─── */
 buildBases(){const tr=this.S.track,G=this.grp=new THREE.Group();tr.group.add(G);
  const tireGeo=new THREE.CylinderGeometry(0.46,0.46,0.95,10),tireM=new THREE.MeshStandardMaterial({color:0x1d1f22,roughness:0.95});const N=12*DUEL_RIVALS.length;const tires=new THREE.InstancedMesh(tireGeo,tireM,N);const d=new THREE.Object3D();let n=0;
  for(const R of DUEL_RIVALS){const c=SPEAKERS[R.who].c;const rad=R.stunt==='saltos'?48:R.stunt==='ocho'?30:24;
   for(let i=0;i<12;i++){if(i%3===2)continue;const a=i/12*Math.PI*2+0.3,x=R.x+Math.sin(a)*rad,z=R.z+Math.cos(a)*rad;d.position.set(x,tr.ground(x,z)+0.47,z);d.rotation.set(0,a,0);d.updateMatrix();tires.setMatrixAt(n++,d.matrix);this.api.addCollider(x,z,0.55);}
   const bx=R.x+rad*0.72,bz=R.z-rad*0.72,y=tr.ground(bx,bz);const sg=this.api.canvasTex(512,128,(x,w,h)=>{x.fillStyle='#0c0f14';x.fillRect(0,0,w,h);x.fillStyle=c;x.fillRect(0,h-16,w,16);x.fillRect(0,0,14,h);x.fillStyle='#fff';x.font='italic 900 60px system-ui,sans-serif';x.textAlign='center';x.textBaseline='middle';x.fillText(R.name.toUpperCase(),w/2+6,h/2-6);});
   const sign=new THREE.Mesh(new THREE.PlaneGeometry(6,1.5),new THREE.MeshBasicMaterial({map:sg,side:THREE.DoubleSide}));sign.position.set(bx,y+3.3,bz);sign.rotation.y=Math.atan2(R.x-bx,R.z-bz)+Math.PI;G.add(sign);
   const pm=new THREE.MeshStandardMaterial({color:0x3a3f46});for(const s of [-1,1]){const post=new THREE.Mesh(new THREE.CylinderGeometry(0.08,0.08,3.3,6),pm);const a=sign.rotation.y;post.position.set(bx+Math.cos(a)*2.8*s,y+1.65,bz-Math.sin(a)*2.8*s);G.add(post);}
   const beam=new THREE.Mesh(new THREE.CylinderGeometry(2.4,2.4,70,14,1,true),new THREE.MeshBasicMaterial({color:new THREE.Color(c),transparent:true,opacity:0.13,depthWrite:false}));beam.position.set(R.x,tr.ground(R.x,R.z)+35,R.z);G.add(beam);
   if(R.ramp)G.add(this.rampMesh({...R.ramp,x:R.x,z:R.z}));}
  tires.count=n;tires.instanceMatrix.needsUpdate=true;G.add(tires);}
 rampMesh(R){const tr=this.S.track,ax=Math.sin(R.yaw),az=Math.cos(R.yaw),lx=az,lz=-ax;const NU=26,NV=8,P=[],UV=[],I=[];
  for(let i=0;i<=NU;i++){const u=-R.len-1.2+(R.len+6.4)*i/NU;for(let j=0;j<=NV;j++){const v=(-R.w/2-1.5)+(R.w+3)*j/NV;const x=R.x+ax*u+lx*v,z=R.z+az*u+lz*v;P.push(x,tr.ground(x,z)+0.04,z);UV.push(v/2,u/2);}}
  for(let i=0;i<NU;i++)for(let j=0;j<NV;j++){const a=i*(NV+1)+j,b=a+1,c=a+NV+1,d=c+1;I.push(a,b,c,b,d,c);}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(P,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(UV,2));g.setIndex(I);g.computeVertexNormals();
  const t=this.api.canvasTex(128,128,(x,w,h)=>{x.fillStyle='#7a5a36';x.fillRect(0,0,w,h);for(let k=0;k<8;k++){x.fillStyle=k%2?'#6c4f2f':'#85633d';x.fillRect(0,k*16,w,15);}x.fillStyle='rgba(20,12,4,.5)';for(let k=0;k<8;k++)x.fillRect(0,k*16+15,w,1);});t.wrapS=t.wrapT=THREE.RepeatWrapping;
  const m=new THREE.Mesh(g,new THREE.MeshLambertMaterial({map:t,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-2,polygonOffsetUnits:-2}));m.receiveShadow=true;return m;}
 /* el arco de control: medio aro rojo + haz de luz para verlo de lejos */
 buildArch(){const G=this.arch=new THREE.Group();const m=new THREE.MeshBasicMaterial({color:0xff2a3a}),m2=new THREE.MeshBasicMaterial({color:0xffffff});
  const ring=new THREE.Mesh(new THREE.TorusGeometry(ARCH_R,0.42,8,36,Math.PI),m);G.add(ring);
  const ring2=new THREE.Mesh(new THREE.TorusGeometry(ARCH_R-0.62,0.12,6,36,Math.PI),m2);G.add(ring2);
  for(const s of [-1,1]){const leg=new THREE.Mesh(new THREE.CylinderGeometry(0.42,0.5,3,8),m);leg.position.set(s*ARCH_R,-1.4,0);G.add(leg);}
  const beam=new THREE.Mesh(new THREE.CylinderGeometry(1.4,1.4,90,12,1,true),new THREE.MeshBasicMaterial({color:0xff3040,transparent:true,opacity:0.2,depthWrite:false}));beam.position.y=45;G.add(beam);
  G.visible=false;this.S.track.group.add(G);}
 placeArch(pt,from){const tr=this.S.track,G=this.arch;G.position.set(pt.x,tr.ground(pt.x,pt.z)-0.2,pt.z);G.rotation.y=Math.atan2(pt.x-from.x,pt.z-from.z);G.visible=true;G.scale.setScalar(0.01);this.archT=0;}
 /* ¿hay árbol o roca cerca de un punto? */
 blocked(x,z,r){const cols=this.S.track.colliders;if(!cols)return false;const ix=Math.floor(x/12),iz=Math.floor(z/12);
  for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++){const l=cols.get((ix+a)+','+(iz+b));if(!l)continue;for(const [ox,oz,orr] of l)if(Math.hypot(ox-x,oz-z)<r+orr)return true;}
  const P=this.S.track.portal;if(P&&Math.hypot(P.x-x,P.z-z)<30)return true;
  for(const R of DUEL_RIVALS)if(Math.hypot(R.x-x,R.z-z)<(R.ramp?55:32))return true;return false;}
 genPoints(n,sx,sz,yaw){const pts=[];let px=sx,pz=sz,dir=yaw;
  for(let i=0;i<n;i++){let ok=null;for(let k=0;k<80&&!ok;k++){const a=dir+(Math.random()-0.5)*(i===0?1.2:(k<40?2.4:5.5)),d=(i===0?75:95)+Math.random()*80;const x=px+Math.sin(a)*d,z=pz+Math.cos(a)*d;
    if(Math.abs(x)>395||Math.abs(z)>395||this.blocked(x,z,8))continue;ok={x,z,a};}
   if(!ok){const a=Math.atan2(-px,-pz);ok={x:px+Math.sin(a)*100,z:pz+Math.cos(a)*100,a};}
   pts.push({x:ok.x,z:ok.z});px=ok.x;pz=ok.z;dir=ok.a;}
  return pts;}
 /* los rivales lejanos duermen (sin física ni dibujo) */
 sleepCheck(force){const p=this.S.player.phys;for(const c of this.rivals){const R=c.rival;const busy=this.duel&&this.duel.car===c;const far=!busy&&Math.hypot(p.px-R.x,p.pz-R.z)>WAKE_R;
  if(far===c.sleep&&!force)continue;c.sleep=far;c.vis.group.visible=!far;if(c.shadow)c.shadow.visible=!far;
  if(far){c.ai.mode='stunt';const q=c.phys;if(Math.hypot(q.px-R.x,q.pz-R.z)>60)q.reset({x:R.x+8,z:R.z,yaw:0});}}}
 /* ─── botón ─── */
 press(){const D=this.duel;if(D){if(D.phase==='run')this.finish(false,true);return;}const c=this.near;if(!c)return;if(!this.unlocked(c.rival)){this.g.toast('🔒 '+c.rival.lock,'');return;}this.start(c);}
 showBtn(mode,c){const b=this.btn;if(mode===this._bm&&c===this._bc)return;this._bm=mode;this._bc=c;b.className=mode?'on '+(mode==='lock'?'lock':mode==='stop'?'stop':''):'';
  if(mode==='go'){const R=c.rival,w=this.wins(R);b.innerHTML=`⚔ ${w?'REVANCHA':'RETAR'} A ${R.name.toUpperCase()}<small>${R.n} arcos · premio $${this.prize(R).toLocaleString('es-AR')}</small>`;}
  else if(mode==='lock')b.innerHTML=`🔒 ${c.rival.name.toUpperCase()}<small>Todavía no te acepta un duelo</small>`;
  else if(mode==='stop')b.innerHTML='✖ Abandonar duelo';}
 /* ─── subtítulos y voces (mismo sistema que la historia) ─── */
 speak(who,text,id,voiced){const sp=SPEAKERS[who]||{n:'',c:'#fff'},e=this.el.sub;e.innerHTML=`<b style="color:${sp.c}">${sp.n}:</b> ${text}`;e.classList.add('on');
  const v=this.voice,vol=Math.min(1,(this.g.settingsVolume?this.g.settingsVolume():80)/80);let d=voiced&&id?v.dur(id,who):2.4;if(voiced&&id)v.play(id,who,vol);
  this.subOff=this.t+Math.max(2.2,d+0.4);if(voiced&&this.g.copilot&&this.g.audio.ctx)this.g.copilot.hold(this.g.audio.ctx.currentTime+d+0.3);return d;}
 scene(on,title){document.body.classList.toggle('story',on||!!this.duel);document.body.classList.add('nohp');document.body.classList.toggle('cine',on);
  if(on&&title){const el=this.el.title;el.innerHTML=title;el.classList.remove('show');void el.offsetWidth;el.classList.add('show');this.titleT=this.t;}
  if(on){this.userCam=this.g.getCam();this.g.setCam(1);this.el.skip.onclick=e=>{e.preventDefault();this.skip();};this.shotOrb=Math.random()*6.28;this.snap=true;}
  else{this.el.title.classList.remove('show');this.g.setCam(this.userCam);}}
 skip(){const D=this.duel;if(!D||!D.q)return;D.q=[];this.voice.stop();D.next=this.t;}
 /* ─── empezar ─── */
 start(c){const R=c.rival,S=this.S,pl=S.player.phys;const first=!this.wins(R)&&!this.cool['met_'+R.id];this.cool['met_'+R.id]=1;
  /* el rival se pone al lado tuyo, mirando para el mismo lado */
  const lx=Math.cos(pl.yaw),lz=-Math.sin(pl.yaw);let spot=null;for(const s of [1,-1,1.6,-1.6]){const x=pl.px+lx*5.2*s,z=pl.pz+lz*5.2*s;if(!this.blocked(x,z,2.2)||Math.abs(s)>1.5){spot={x,z};if(!this.blocked(x,z,2.2))break;}}
  c.phys.reset({x:spot.x,z:spot.z,yaw:pl.yaw});c.sleep=false;c.vis.group.visible=true;c.ai.mode='hold';c.ai.passive=true;
  const pts=this.genPoints(R.n,pl.px,pl.pz,pl.yaw);
  const id=(part,k)=>duelLineId(R.id,part,k),last=R.intro.length-1;
  const lines=first?R.intro.map((l,k)=>[l[0],l[1],id('intro',k)]):[...R.again.map((l,k)=>[l[0],l[1],id('again',k)]),[R.intro[last][0],R.intro[last][1],id('intro',last)]];
  this.duel={car:c,R,pts,k:0,rk:0,phase:'intro',q:lines,next:this.t+0.9,t0:this.t,lastTano:-99,lastTaunt:this.t,lead:0};
  S.playerHold=true;this.showBtn(null);this.scene(true,`<small>DUELO · ${R.n} ARCOS</small>${R.name.toUpperCase()}`);}
 finish(win,quit){const D=this.duel;if(!D||D.phase==='end')return;const R=D.R,P=this.api.profile;D.phase='end';this.arch.visible=false;this.hud.classList.remove('on');D.car.ai.passive=true;this.showBtn(null);
  if(quit){D.car.ai.mode='home';this.g.toast('Abandonaste el duelo','');this.close();return;}
  let msg='';if(win){const pay=this.prize(R);const st=P.d.stats;st.duels=st.duels||{};st.duels[R.id]=(st.duels[R.id]||0)+1;P.earn(pay);const ups=P.addXP(win?Math.round(R.reward/8):40);this.g.sfx('coin');
   msg=`+$${pay.toLocaleString('es-AR')}`;for(const u of ups)this.g.toast(`⭐ ¡Nivel ${u.level}! +$${u.bonus}`,'blue');}else P.save();
  this.g.bigMsg(win?'¡GANASTE EL DUELO!':'PERDISTE EL DUELO',win?'go':'');if(msg)setTimeout(()=>this.g.toast(`⚔ ${R.name} · ${msg}`,'green'),900);
  /* escena corta: los dos autos frenan y hablan */
  D.car.ai.mode='hold';this.S.playerHold=true;D.q=(win?R.win:R.lose).map((l,k)=>[l[0],l[1],duelLineId(R.id,win?'win':'lose',k)]);D.next=this.t+1.4;D.endScene=true;
  setTimeout(()=>{if(this.duel===D&&D.phase==='end')this.scene(true,null);},1000);}
 close(){const D=this.duel;if(!D)return;this.cool[D.R.id]=this.t+25;D.car.ai.mode='home';D.car.ai.passive=true;this.S.playerHold=false;this.duel=null;this.el.sub.classList.remove('on');this.arch.visible=false;this.hud.classList.remove('on');this.scene(false);document.body.classList.remove('story');this.showBtn(null);}
 /* ─── cada cuadro (lo llama el juego como "director") ─── */
 update(dt,realDt){const S=this.S,g=this.g,p=S.player.phys;this.t+=realDt;
  if(this.subOff&&this.t>this.subOff){this.el.sub.classList.remove('on');this.subOff=0;}if(this.titleT&&this.t-this.titleT>3.4){this.el.title.classList.remove('show');this.titleT=0;}
  this._sc=(this._sc||0)+realDt;if(this._sc>0.5){this._sc=0;this.sleepCheck();}
  const D=this.duel;
  if(!D){/* ¿cerca de un rival? */let best=null,bd=1e9;const sp=Math.hypot(p.vx,p.vz);
   for(const c of this.rivals){if(c.sleep)continue;const R=c.rival,d=Math.min(Math.hypot(c.phys.px-p.px,c.phys.pz-p.pz),Math.hypot(R.x-p.px,R.z-p.pz)+4);if(d<bd){bd=d;best=c;}
    if(d<70&&!this.cool['hi_'+R.id]){this.cool['hi_'+R.id]=1;g.toast(this.unlocked(R)?`⚔ ${R.name} está en su base. Acercate despacio para retarlo`:`🔒 ${R.name} · ${R.lock}`,this.unlocked(R)?'blue':'');}}
   const ok=best&&bd<24&&sp<9&&S.state==='run'&&this.g.state==='race'&&!(this.cool[best.rival.id]>this.t);this.near=ok?best:null;this.showBtn(ok?(this.unlocked(best.rival)?'go':'lock'):null,best);return;}
  const c=D.car,q=c.phys,ai=c.ai;
  /* frases en cola */
  if(D.q&&D.q.length&&this.t>=D.next){const l=D.q.shift();const d=this.speak(l[0],l[1],l[2],true);D.next=this.t+d+0.45;}
  if(D.phase==='intro'){this.camera(dt,p,q);if(!D.q.length&&this.t>=D.next+0.2){D.phase='count';D.cd=3.4;D.beep=4;this.scene(false);this.el.sub.classList.remove('on');}return;}
  if(D.phase==='count'){D.cd-=realDt;const k=Math.ceil(D.cd);if(k<D.beep&&k>0){D.beep=k;g.bigMsg(String(k));g.sfx('beep');}
   if(D.cd<=0){D.phase='run';S.playerHold=false;ai.mode='duel';ai.passive=false;ai.target=D.pts[0];ai.stuckN=0;g.bigMsg('¡YA!','go');g.sfx('go');if(g.copilot)g.copilot.say('largada',{pri:3});this.placeArch(D.pts[0],{x:p.px,z:p.pz});this.hud.classList.add('on');this.showBtn('stop');}
   return;}
  if(D.phase==='end'){if(D.endScene&&document.body.classList.contains('cine'))this.camera(dt,p,q);if(!D.q.length&&this.t>=D.next+0.6)this.close();return;}
  /* ─── en carrera ─── */
  this.archT+=realDt;const A=this.arch;A.scale.setScalar(Math.min(1,0.01+this.archT*2.2));A.children[0].material.color.setHSL(0.99,1,0.5+0.12*Math.sin(this.t*6));
  const pt=D.pts[D.k];
  if(Math.hypot(p.px-pt.x,p.pz-pt.z)<PASS_R){D.k++;g.sfx('coin');
   if(D.k>=D.pts.length){this.finish(true);return;}
   this.placeArch(D.pts[D.k],pt);g.toast(`✔ Arco ${D.k}/${D.pts.length}`,'green');
   if(this.t-D.lastTano>7){const last=D.k===D.pts.length-1;const L=last?TANO_DUEL.last:TANO_DUEL.cp;if(last||Math.random()<0.55){const i=Math.floor(Math.random()*L.length);D.lastTano=this.t;this.speak('tano',L[i],duelLineId('tano',last?'last':'cp',i),true);}}}
  const rp=D.pts[D.rk];if(Math.hypot(q.px-rp.x,q.pz-rp.z)<PASS_R){D.rk++;if(D.rk>=D.pts.length){this.finish(false);return;}ai.target=D.pts[D.rk];ai.stuckN=0;}
  /* goma elástica y comentarios de Tano según quién va adelante */
  const dist=(a,b)=>Math.hypot(a.px-b.x,a.pz-b.z);const lead=(D.rk-D.k)+(D.rk===D.k?(dist(p,pt)-dist(q,rp))/150:0);
  ai.boost=lead>1.4?0.78:lead>0.6?0.9:lead<-1.4?1.14:lead<-0.6?1.06:1;
  const li=Math.round(D.rk-D.k);if(li!==D.lead){const was=D.lead;D.lead=li;if(this.t-D.lastTano>9){if(li>was&&li>0){const i=Math.floor(Math.random()*TANO_DUEL.behind.length);D.lastTano=this.t;this.speak('tano',TANO_DUEL.behind[i],duelLineId('tano','behind',i),true);}
    else if(li<was&&li<0){const i=Math.floor(Math.random()*TANO_DUEL.ahead.length);D.lastTano=this.t;this.speak('tano',TANO_DUEL.ahead[i],duelLineId('tano','ahead',i),true);}}}
  /* el rival te grita cosas (solo texto: en carrera se escucha únicamente a tu copiloto) */
  if(Math.hypot(q.px-p.px,q.pz-p.pz)<16&&this.t-D.lastTaunt>22&&this.t-D.lastTano>3){D.lastTaunt=this.t;const T=D.R.taunt;this.speak(D.R.who,T[Math.floor(Math.random()*T.length)],null,false);}
  /* rival trabado de verdad: aparece más adelante, fuera de cámara */
  if(ai.stuckN>=3||(Math.hypot(q.vx,q.vz)<1&&(this._still=(this._still||0)+realDt)>7)){const cam=g.camera.position;const tx=ai.target.x-q.px,tz=ai.target.z-q.pz,tl=Math.hypot(tx,tz)||1;const x=q.px+tx/tl*Math.min(25,tl*0.5),z=q.pz+tz/tl*Math.min(25,tl*0.5);
   if(!g.inView(x,q.py,z,3)||Math.hypot(cam.x-x,cam.z-z)>90){q.reset({x,z,yaw:Math.atan2(tx,tz)});ai.stuckN=0;this._still=0;}}else if(Math.hypot(q.vx,q.vz)>=1)this._still=0;
  /* HUD: flecha al arco, marcador y distancia */
  const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw),dx=pt.x-p.px,dz=pt.z-p.pz;const ang=Math.atan2(dx*lx+dz*lz,dx*fx+dz*fz);
  const h=this.hud;h.children[0].style.transform=`rotate(${(-ang).toFixed(3)}rad)`;const n=D.pts.length;const txt=`⚔ <span class="me">Vos ${D.k}/${n}</span> · ${D.R.name} ${D.rk}/${n}`;if(txt!==this._ht){this._ht=txt;h.children[1].innerHTML=txt;}
  const dm=Math.round(Math.hypot(dx,dz))+' m';if(dm!==this._hd){this._hd=dm;h.children[2].textContent=dm;}}
 /* plano de los dos autos (presentación y final del duelo) */
 camera(dt,p,q){const c=this.g.camera,W=this._w||(this._w=new THREE.Vector3()),Lk=this._l||(this._l=new THREE.Vector3());
  const mx=(p.px+q.px)/2,mz=(p.pz+q.pz)/2,my=(p.py+q.py)/2,sep=Math.hypot(p.px-q.px,p.pz-q.pz),fx=Math.sin(p.yaw),fz=Math.cos(p.yaw);const orb=this.shotOrb+(this.t*0.1);
  const off=Math.min(18,7+sep*0.5);W.set(mx+fx*off*Math.cos(orb*0.3)+Math.sin(orb)*3,my+2.2,mz+fz*off*Math.cos(orb*0.3)+Math.cos(orb)*3);Lk.set(mx,my+0.5,mz);
  const tr=this.S.track;if(tr&&tr.ground){const gy=tr.ground(W.x,W.z)+1;if(W.y<gy)W.y=gy;}
  if(!this.camPos||this.snap){this.camPos=W.clone();this.camLook=Lk.clone();this.snap=false;}else{this.camPos.lerp(W,1-Math.exp(-dt*2.5));this.camLook.lerp(Lk,1-Math.exp(-dt*5));}
  c.position.copy(this.camPos);c.up.set(0,1,0);c.lookAt(this.camLook);c.fov+=(46-c.fov)*Math.min(1,dt*5);c.near=0.15;c.updateProjectionMatrix();}
 /* minimapa: bases y arco actual */
 drawMini(ctx,P){for(const c of this.rivals){const R=c.rival,[u,v]=P(R.x,R.z);ctx.save();ctx.translate(u,v);ctx.rotate(Math.PI/4);ctx.fillStyle=this.unlocked(R)?SPEAKERS[R.who].c:'#666';ctx.strokeStyle='#000';ctx.lineWidth=1;ctx.fillRect(-4,-4,8,8);ctx.strokeRect(-4,-4,8,8);ctx.restore();}
  const D=this.duel;if(D&&D.phase==='run'){const pt=D.pts[D.k],[u,v]=P(pt.x,pt.z),r=5+1.5*Math.sin(this.t*6);ctx.strokeStyle='#ff2a3a';ctx.lineWidth=3;ctx.beginPath();ctx.arc(u,v,r,0,7);ctx.stroke();ctx.fillStyle='#fff';ctx.beginPath();ctx.arc(u,v,2,0,7);ctx.fill();}}
 dispose(){if(this.duel){this.S.playerHold=false;this.duel=null;}this.btn.className='';this.btn.onclick=null;this.hud.classList.remove('on');this.el.sub.classList.remove('on');this.el.title.classList.remove('show');this.el.skip.onclick=null;
  document.body.classList.remove('story','cine','nohp');}
}
