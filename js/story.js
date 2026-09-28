/* ═══ Modo historia · Capítulo 1 "La Fuga" ═══
   Cinemática SIN video: la IA maneja tu auto (misma física que el juego) perseguida por 3 autos.
   El director elige los planos según por dónde va el auto: interior con la mano metiendo los cambios,
   los dos autos juntos, cámara fija al costado de la curva, helicóptero, el salto en cámara lenta,
   de frente con los perseguidores atrás… Al entrar al túnel de la mina te da el control. */
import * as THREE from 'three';

export const STORY_LINES={
 intro:'Nos encontraron. Arrancá ya, vamos, vamos.',rapido:'¡Más rápido, más rápido!',cerca:'¡Se acercan, los tenemos pegados atrás!',
 frena:'¡Frená, frená, te pasás de largo!',choque:'¡Nos chocaron! Aguantá.',cuidado:'¡Cuidado, nos quieren encerrar!',rampa:'¡Agarrate, viene la rampa!',
 salto:'¡Qué salto! Seguí, seguí.',derrape:'¡Cruzalo, cruzalo! Así.',tierra:'Tierra suelta, abrí las manos.',tunel:'¡A la mina, metete al túnel!',
 control:'Ahora manejás vos. Sacanos de acá.',aguanta:'No los dejes pasar, tapales el camino.',dano:'¡El auto no aguanta mucho más!',
 salida:'Ya se ve la salida, dale.',lolograste:'¡Salimos! Lo logramos, los perdimos.',fallo:'Se acabó. Nos atraparon.',proximamente:'Siguiente misión, próximamente.'};

/* planos: [hasta la fracción de pista, tipo, dato] — 'rig' usa las cámaras del juego (0 interior, 1 media, 3 baja, 6 detrás del piloto) */
const SHOTS=[[0.030,'rig',0],[0.064,'pair'],[0.101,'track',0.100],[0.132,'rig',0],[0.192,'heli'],[0.238,'ramp'],[0.29,'rig',3],[0.333,'track',0.314],
 [0.372,'rig',6],[0.422,'front'],[0.462,'track',0.455],[1,'rig',1]];
/* frases por posición (una vez cada una) */
const CUES=[[0.05,'rapido'],[0.078,'tierra'],[0.093,'frena'],[0.112,'derrape'],[0.199,'rampa'],[0.283,'frena'],[0.302,'derrape'],[0.40,'cuidado'],[0.492,'tunel']];
export const HANDOFF=0.519;

export class Director{
 constructor(g,S){this.g=g;this.S=S;this.tr=S.track;this.t=0;this.cine=true;this.shot=-1;this.cues=new Set();this.cd={};this.pending=null;this.subT=0;this.hpShown=-1;
  this.userCam=g.getCam();this.cam=g.camera;this.pos=new THREE.Vector3();this.look=new THREE.Vector3();this.fix=new THREE.Vector3();this.snap=true;this.air=0;this.flying=false;this.slow=1;
  document.body.classList.add('story','cine');this.el={sub:document.getElementById('cineSub'),title:document.getElementById('cineTitle'),hp:document.getElementById('storyHp'),skip:document.getElementById('cineSkip')};
  this.el.skip.onclick=e=>{e.preventDefault();this.skip();};
  this.el.title.classList.remove('show');void this.el.title.offsetWidth;this.el.title.classList.add('show');
  g.physics.manual=false;/* en la cinemática la caja la maneja la IA (secuencial automática) */}
 get vo(){return this.g.storyVO;}
 frac(){const S=this.S,pl=S.player,tr=this.tr;const i=pl.idx??S.s0;return tr.cum[i]/tr.length;}
 /* voz + subtítulo (si el audio todavía no cargó, reintenta un rato) */
 line(k,cool){const now=this.t;if(cool&&this.cd[k]&&now-this.cd[k]<cool)return;this.cd[k]=now;
  const ok=this.vo&&this.vo.say([k]);if(!ok)this.pending={k,until:now+4};
  const e=this.el.sub;e.textContent=STORY_LINES[k]||'';e.classList.add('on');this.subT=now+Math.max(2.4,(STORY_LINES[k]||'').length*0.075);}
 onHit(imp,o){if(imp<2.2)return;this.line('choque',this.cine?7:6);}
 setRig(i){if(this.g.getCam()!==i)this.g.setCam(i);}
 update(dt,realDt){const g=this.g,S=this.S,pl=S.player,p=pl.phys;this.t+=realDt;
  if(this.vo&&!this.vo.ready&&g.audio.ctx)this.vo.load(g.audio.ctx);
  if(this.pending){if(this.vo&&this.vo.say([this.pending.k]))this.pending=null;else if(this.t>this.pending.until)this.pending=null;}
  if(this.subT&&this.t>this.subT){this.el.sub.classList.remove('on');this.subT=0;}
  if(this.t>3.6)this.el.title.classList.remove('show');
  const f=this.frac();
  /* perseguidores cerca */
  let near=null,nd=1e9;for(const c of S.cars)if(c.ai){const d=Math.hypot(c.phys.px-p.px,c.phys.pz-p.pz);if(d<nd){nd=d;near=c;}}
  if(this.cine){
   if(this.t>0.5&&!this.cues.has('intro')){this.cues.add('intro');this.line('intro');}
   for(const [at,k] of CUES)if(f>=at&&f<at+0.05&&!this.cues.has(at)){this.cues.add(at);this.line(k);}
   if(near&&nd<11&&this.t>6)this.line('cerca',16);
   /* salto: cámara lenta mientras vuela */
   const air=p.wheels.every(w=>!w.contact);this.air=air?this.air+dt:0;const rampZone=f>0.205&&f<0.232;
   if(air&&this.air>0.08&&rampZone)this.flying=true;if(this.flying&&!air){this.flying=false;this.line('salto');}
   const want=this.flying?0.38:1;this.slow+=(want-this.slow)*(1-Math.exp(-realDt*(want<1?9:4)));g.timeScale=this.slow;
   /* vigilante: si el auto quedó trabado (choque, isla) se lo reubica más adelante con un corte de cámara */
   this.wd=this.wd||{t:0,prog:pl.prog};this.wd.t+=dt;if(this.wd.t>3){if(pl.prog-this.wd.prog<8&&this.t>6)this.recover(f);this.wd.t=0;this.wd.prog=pl.prog;}
   this.camera(dt,f,p,near);
   if(f>=HANDOFF&&f<HANDOFF+0.1)this.handoff();}
  else{/* el jugador maneja */
   const dm=p.damage||0,hp=Math.max(0,Math.round(100-dm*100));if(hp!==this.hpShown){this.hpShown=hp;this.el.hp.querySelector('b').style.width=hp+'%';this.el.hp.querySelector('em').textContent=hp+'%';this.el.hp.classList.toggle('low',hp<40);this.el.hp.classList.remove('hit');void this.el.hp.offsetWidth;if(hp<100)this.el.hp.classList.add('hit');}
   if(S.state==='run'){
    if(this.t-this.handT>7&&!this.cues.has('aguanta')){this.cues.add('aguanta');this.line('aguanta');}
    if(near&&nd<9)this.line('cerca',18);
    if(near&&nd<6){const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),dx=near.phys.px-p.px,dz=near.phys.pz-p.pz;if(Math.abs(dx*fx+dz*fz)<3)this.line('cuidado',15);}
    if(dm>0.6&&!this.cues.has('dano')){this.cues.add('dano');this.line('dano');}
    if(f>0.775&&!this.cues.has('salida')){this.cues.add('salida');this.line('salida');}}}}
 /* ─── planos de cámara ─── */
 camera(dt,f,p,near){let k=SHOTS.length-1;for(let i=0;i<SHOTS.length;i++)if(f<SHOTS[i][0]){k=i;break;}
  const sh=SHOTS[k],c=this.cam,tr=this.tr,N=tr.samples.length;if(k!==this.shot){this.shot=k;this.snap=true;this.setRig(sh[1]==='rig'?sh[2]:1);
   if(sh[1]==='track'||sh[1]==='ramp'){/* cámara fija sobre el borde, del lado de afuera de la curva */const i=sh[1]==='ramp'?Math.min(N-1,((tr.ramps&&tr.ramps[0].top)||Math.floor(0.214*N))+7):Math.floor(sh[2]*N);
     const a=tr.tangents[(i-12+N)%N],b=tr.tangents[(i+12)%N],turn=a.x*b.z-a.z*b.x,side=sh[1]==='ramp'?1:(turn>0?1:-1),L=tr.laterals[i],s=tr.samples[i],off=tr.hwA[i]+(sh[1]==='ramp'?-0.8:1.2);
     const x=s.x+L.x*off*side,z=s.z+L.z*off*side;this.fix.set(x,Math.max(tr.ry[i]+(sh[1]==='ramp'?1.0:tr.D[i]+1.6),tr.ground(x,z)+1.2),z);}}
  if(sh[1]==='rig')return;
  const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw);const P=this._P||(this._P=new THREE.Vector3());P.set(p.px,p.py+0.5,p.pz);
  const want=this._W||(this._W=new THREE.Vector3()),look=this._L||(this._L=new THREE.Vector3());let fov=55,kp=5,kl=10;
  if(sh[1]==='track'||sh[1]==='ramp'){want.copy(this.fix);look.copy(P);const d=want.distanceTo(P);fov=THREE.MathUtils.clamp(2*Math.atan(5.5/d)*180/Math.PI,16,58);kp=100;kl=14;}
  else if(sh[1]==='pair'){/* los dos autos juntos: de costado, entre el jugador y el perseguidor más cercano */const q=near?near.phys:p;const sep=Math.hypot(p.px-q.px,p.pz-q.pz),w=sep>28?0.25:0.5;/* si el perseguidor viene lejos, el encuadre se centra en vos y lo muestra atrás */
   const mx=p.px+(q.px-p.px)*w,mz=p.pz+(q.pz-p.pz)*w,my=p.py+(q.py-p.py)*w,off=Math.min(16,7+sep*0.35),i=p.trackHint||0;want.set(mx+lx*off+fx*2,my+Math.max(2.6,(tr.D?tr.D[i]:0)+1.4),mz+lz*off+fz*2);look.set(mx,my+0.4,mz);fov=THREE.MathUtils.clamp(28+sep*0.6,34,50);kp=4;kl=8;}
  else if(sh[1]==='heli'){/* helicóptero: alto y de costado, se ven todos derrapando en fila */want.set(p.px-fx*16+lx*12,p.py+15,p.pz-fz*16+lz*12);look.set(p.px-fx*10,p.py,p.pz-fz*10);fov=50;kp=2.2;kl=4;}
  else if(sh[1]==='front'){/* de frente: el auto viene a cámara con los perseguidores atrás */const v=Math.hypot(p.vx,p.vz)>3?Math.atan2(p.vx,p.vz):p.yaw,vx=Math.sin(v),vz=Math.cos(v);want.set(p.px+vx*12+Math.cos(v)*1.6,p.py+1.6,p.pz+vz*12-Math.sin(v)*1.6);look.set(p.px-vx*6,p.py+0.3,p.pz-vz*6);fov=48;kp=7;kl=10;}
  if(tr.clampCam&&sh[1]==='front'){tr._hint=p.trackHint;const y=want.y;tr.clampCam(want);want.y=y;}
  {tr._hint=p.trackHint;const gy=tr.ground(want.x,want.z)+0.8;if(want.y<gy)want.y=gy;}
  if(this.snap){this.pos.copy(want);this.look.copy(look);this.snap=false;}
  else{this.pos.lerp(want,1-Math.exp(-dt*kp));this.look.lerp(look,1-Math.exp(-dt*kl));}
  c.position.copy(this.pos);c.up.set(0,1,0);c.lookAt(this.look);if(Math.abs(c.fov-fov)>0.05||c.near!==0.15){c.fov+=(fov-c.fov)*Math.min(1,dt*6);c.near=0.15;c.updateProjectionMatrix();}}
 recover(f){if(f>0.43){this.skip();return;}const S=this.S,tr=this.tr,N=tr.samples.length,c=S.player;let i=((c.idx??S.s0)+12)%N;const lo=tr.laneFix?tr.laneFix(i,0,0):0,L=tr.laterals[i],s=tr.samples[i],t=tr.tangents[i],yaw=Math.atan2(t.x,t.z);
  c.phys.reset({x:s.x+L.x*lo,z:s.z+L.z*lo,yaw});c.phys.vx=Math.sin(yaw)*12;c.phys.vz=Math.cos(yaw)*12;c.phys.trackHint=i;if(S.auto){S.auto.hint=i;S.auto.stuckT=0;S.auto.unstickT=0;}const a=S.arcPos(c);c.prog+=((a.s-c.lastS)%tr.length+tr.length)%tr.length;c.lastS=a.s;this.snap=true;this.shot=-1;}
 /* saltar la cinemática: todos a la boca del túnel, lanzados */
 skip(){if(!this.cine)return;const S=this.S,tr=this.tr,N=tr.samples.length;const i0=Math.floor((HANDOFF-0.004)*N);
  const place=(c,back,lat,v)=>{let i=i0,acc=0;while(acc<back){const j=(i-1+N)%N;acc+=tr.samples[i].distanceTo(tr.samples[j]);i=j;}const s=tr.samples[i],L=tr.laterals[i],t=tr.tangents[i],yaw=Math.atan2(t.x,t.z);
   const lo=tr.laneFix?tr.laneFix(i,lat):lat;c.phys.reset({x:s.x+L.x*lo,z:s.z+L.z*lo,yaw});c.phys.vx=Math.sin(yaw)*v;c.phys.vz=Math.cos(yaw)*v;c.phys.trackHint=i;if(c.ai)c.ai.hint=i;
   const a=S.arcPos(c);c.prog=a.s-tr.cum[S.s0];c.lastS=a.s;c.idx=a.idx;};
  let k=0;for(const c of S.cars){if(c.isPlayer)place(c,0,0,19);else{place(c,26+k*9,[-2.2,2.2,0][k%3],19);k++;}}
  if(S.auto)S.auto.hint=i0;this.g.fx.reset&&this.g.fx.reset();this.handoff();}
 handoff(){if(!this.cine)return;this.cine=false;this.handT=this.t;const g=this.g,S=this.S;S.cine=false;g.timeScale=1;this.slow=1;
  g.physics.manual=g.gearboxManual();this.setRig(this.userCam);document.body.classList.remove('cine');this.el.title.classList.remove('show');
  this.cues.add('aguanta_wait');this.line('control');g.bigMsg('¡TU TURNO!','go');g.toast('Llegá a la salida de la mina. Si el auto llega a 0% te atrapan.','blue');}
 end(ok){this.g.timeScale=1;if(this.cine)this.handoff();this.line(ok?'lolograste':'fallo');}
 dispose(){document.body.classList.remove('story','cine');this.g.timeScale=1;this.el.skip.onclick=null;this.el.sub.classList.remove('on');this.el.title.classList.remove('show');if(this.cine&&this.g.getCam()!==this.userCam)this.g.setCam(this.userCam);}
}
