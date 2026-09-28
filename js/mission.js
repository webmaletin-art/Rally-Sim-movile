/* ═══ Misiones del modo historia (capítulos 2 en adelante) ═══
   - Escena de presentación antes de largar: los autos quietos en la grilla, planos de cámara y el diálogo con voces y subtítulos.
   - Durante la misión: frases según lo que pasa (rival cerca, auto dañado, mitad del tramo, radar...).
   - Al terminar: frases de victoria o derrota (y el gancho del capítulo), estrellas y recompensas.
   - Misiones "cinemática": la IA maneja tu auto por la ruta mientras se cuenta la historia. */
import * as THREE from 'three';
import {SPEAKERS,CHAPTERS,MISSIONS,MISSION_BY_ID} from './story_data.js';

export const lineId=(mid,part,k)=>`${mid}_${part}_${k}`;

/* ─── voces de los personajes: misma voz base, distinto ritmo y "radio" según quién habla ─── */
const PRESET={tano:{rate:1.04,fx:'intercom'},viejo:{rate:0.92,fx:'cassette'},buitre:{rate:0.86,fx:'radio'},hiena:{rate:1.14,fx:'radio'},
 tanque:{rate:0.78,fx:'radio'},sombra:{rate:0.96,fx:'radio'},aldo:{rate:0.95,fx:'radio'},cuervo:{rate:1.02,fx:'radio'}};
export class StoryVoice{
 constructor(){this.idx=null;this.cache=new Map();this.chains={};this.cur=[];}
 load(ctx){if(this.loading||!ctx)return this.loading;this.ctx=ctx;this.loading=fetch('audio/st.json').then(r=>r.json()).then(j=>{this.idx=j;}).catch(e=>{console.warn('voces historia',e);this.failed=true;});return this.loading;}
 dur(id,who){const it=this.idx&&this.idx[id];const r=(PRESET[who]||PRESET.tano).rate;return it?it[0][2]/r:2.5;}
 chain(kind){if(this.chains[kind])return this.chains[kind];const c=this.ctx;const hp=c.createBiquadFilter(),lp=c.createBiquadFilter(),pk=c.createBiquadFilter(),sh=c.createWaveShaper(),out=c.createGain();
  hp.type='highpass';lp.type='lowpass';pk.type='peaking';
  if(kind==='radio'){hp.frequency.value=420;lp.frequency.value=3000;pk.frequency.value=1500;pk.Q.value=1.2;pk.gain.value=7;}
  else if(kind==='cassette'){hp.frequency.value=160;lp.frequency.value=2800;pk.frequency.value=900;pk.Q.value=0.7;pk.gain.value=3;}
  else{hp.frequency.value=320;lp.frequency.value=3600;pk.frequency.value=1800;pk.Q.value=0.9;pk.gain.value=5;}
  const k=kind==='radio'?2.4:kind==='cassette'?1.3:1.6,cv=new Float32Array(512);for(let i=0;i<512;i++){const x=i/255.5-1;cv[i]=Math.tanh(x*k)/Math.tanh(k);}sh.curve=cv;
  out.gain.value=0.9;hp.connect(lp).connect(pk).connect(sh).connect(out).connect(c.destination);return this.chains[kind]={in:hp,out};}
 noise(dur){const c=this.ctx,n=Math.floor(c.sampleRate*dur),b=c.createBuffer(1,n,c.sampleRate),d=b.getChannelData(0);for(let i=0;i<n;i++)d[i]=(Math.random()*2-1);return b;}
 play(id,who,vol=1){if(!this.idx||!this.ctx||this.ctx.state!=='running')return false;const it=this.idx[id];if(!it)return false;const P=PRESET[who]||PRESET.tano,ch=this.chain(P.fx),c=this.ctx;
  let pr=this.cache.get(it[0][0]);if(!pr){pr=fetch('audio/st/'+it[0][0]).then(r=>r.arrayBuffer()).then(ab=>new Promise((res,rej)=>{const p=c.decodeAudioData(ab,res,rej);if(p&&p.then)p.then(res,rej);}));this.cache.set(it[0][0],pr);}
  pr.then(buf=>{const t=c.currentTime+0.02;ch.out.gain.setValueAtTime(0.95*vol,t);
   /* "kssh" de radio al apretar el botón / soplido de cinta */
   if(P.fx!=='intercom'){const nb=c.createBufferSource(),ng=c.createGain();nb.buffer=this.noise(P.fx==='cassette'?buf.duration/P.rate+0.3:0.12);ng.gain.value=P.fx==='cassette'?0.025:0.12;nb.connect(ng).connect(ch.in);nb.start(t);this.cur.push(nb);}
   const s=c.createBufferSource();s.buffer=buf;s.playbackRate.value=P.rate;s.connect(ch.in);s.start(t+(P.fx==='radio'?0.1:0));this.cur.push(s);s.onended=()=>{this.cur=this.cur.filter(x=>x!==s);};}).catch(()=>{});
  return true;}
 stop(){for(const s of this.cur)try{s.stop();}catch(e){}this.cur=[];}
}

/* ─── estrellas y progreso ─── */
export function missionStars(m,r){const s=m.stars;if(!r.ok)return 0;
 if(s.auto)return 3;
 if(s.hp)return s.hp.filter(v=>r.hp>=v).length;
 if(s.pos1hp)return r.pos===1?s.pos1hp.filter(v=>r.hp>=v).length:0;
 if(s.time)return s.time.filter(v=>r.time<=v).length;
 if(s.kmh)return s.kmh.filter(v=>r.kmh>=v).length;
 if(s.left)return s.left.filter(v=>r.left>=v).length;
 if(s.park)return s.park.filter(v=>v===0||r.park<=v).length;
 return 1;}
export function starText(m){const s=m.stars;const f=x=>Math.floor(x/60)+':'+String(Math.round(x%60)).padStart(2,'0');
 if(s.auto)return ['Mirá la escena completa'];
 if(s.hp)return [`Llegar con el auto al ${s.hp[0]}% o más`,`Llegar con el auto al ${s.hp[1]}% o más`,`Llegar con el auto al ${s.hp[2]}% o más`];
 if(s.pos1hp)return ['Terminar primero',`Primero y con el auto al ${s.pos1hp[1]}%`,`Primero y con el auto al ${s.pos1hp[2]}%`];
 if(s.time)return [`Terminar en menos de ${f(s.time[0])}`,`Menos de ${f(s.time[1])}`,`Menos de ${f(s.time[2])}`];
 if(s.kmh)return [`Pasar el radar a ${s.kmh[0]} km/h`,`A ${s.kmh[1]} km/h`,`A ${s.kmh[2]} km/h`];
 if(s.left)return ['Juntar todas antes de que se termine el tiempo',`Con ${s.left[1]} s de sobra`,`Con ${s.left[2]} s de sobra`];
 if(s.park)return ['Estacionar sin tocar nada',`En menos de ${s.park[1]} s`,`En menos de ${s.park[2]} s`];
 return ['Completar'];}
export function storyProgress(P){const d=P.d.story||(P.d.story={});d.m=d.m||{};return d;}
export function missionUnlocked(P,id){const d=storyProgress(P);const i=MISSIONS.findIndex(m=>m.id===id);if(i<0)return false;if(i===0)return (d.ch1||0)>0;return ((d.m[MISSIONS[i-1].id]||{}).stars||0)>0;}
export function nextMission(id){const i=MISSIONS.findIndex(m=>m.id===id);return MISSIONS[i+1]||null;}
export function chapterStars(P,n){const d=storyProgress(P);if(n===1){const hp=d.ch1||0;return hp>0?[1,50,80].filter(v=>hp>=v).length:0;}const c=CHAPTERS.find(c=>c.n===n);return c?c.missions.reduce((a,m)=>a+((d.m[m.id]||{}).stars||0),0):0;}

/* ─── el director de cada misión ─── */
export class MissionDirector{
 constructor(g,S,m){this.g=g;this.S=S;this.m=m;this.t=0;this.q=[];this.next=0;this.done=new Set();this.cnt={};this.shotI=-1;this.shotT=0;this.snap=true;
  this.pos=new THREE.Vector3();this.look=new THREE.Vector3();this.userCam=g.getCam();
  this.phase=m.type==='cinematica'?'cine':'intro';S.introHold=this.phase==='intro';
  document.body.classList.add('story','cine');document.body.classList.toggle('nohp',m.type!=='escape');
  const el=this.el={sub:document.getElementById('cineSub'),title:document.getElementById('cineTitle'),skip:document.getElementById('cineSkip')};
  const ch=CHAPTERS.find(c=>c.n===m.chapter);el.title.innerHTML=`<small>CAPÍTULO ${m.chapter} · ${(ch?ch.title:'').toUpperCase()}</small>${m.title.toUpperCase()}`;el.title.classList.remove('show');void el.title.offsetWidth;el.title.classList.add('show');
  el.skip.onclick=e=>{e.preventDefault();this.skip();};
  this.enqueue(m.intro.map((l,k)=>[l[0],l[1],lineId(m.id,'intro',k)]));this.next=1.2;
  if(this.phase==='cine')g.physics.manual=false;}
 get voice(){return this.g.storyVoice;}
 enqueue(lines){for(const l of lines)this.q.push(l);}
 /* una frase: voz + subtítulo con el nombre de quien habla */
 speak([who,text,id,scene]){const sp=SPEAKERS[who]||{n:'',c:'#fff'};const e=this.el.sub;e.innerHTML=`<b style="color:${sp.c}">${sp.n}:</b> ${text}`;e.classList.add('on');
  /* en carrera solo se escucha al copiloto; las demás voces, solo en las escenas (el resto queda como texto de radio) */
  const voiced=who==='tano'||scene||this.phase==='intro'||this.phase==='cine';const vol=Math.min(1,(this.g.settingsVolume?this.g.settingsVolume():80)/80);if(voiced&&this.voice)this.voice.play(id,who,vol);const d=this.voice?this.voice.dur(id,who):2.5;
  if(!voiced){this.subOff=this.t+Math.max(2.2,d*0.8);return Math.min(d,2.4);}
  this.subOff=this.t+Math.max(2.2,d+0.4);if(this.g.copilot&&this.g.audio.ctx)this.g.copilot.hold(this.g.audio.ctx.currentTime+d+0.3);return d;}
 busy(){return this.q.length>0||this.t<this.next;}
 update(dt,realDt){const g=this.g,S=this.S,m=this.m,p=S.player.phys;this.t+=realDt;
  if(this.voice&&!this.voice.idx&&g.audio.ctx)this.voice.load(g.audio.ctx);
  if(this.q.length&&this.t>=this.next){const l=this.q.shift();if(l[3])document.body.classList.add('cine');const d=this.speak(l);this.next=this.t+d+0.45;}
  if(this.subOff&&this.t>this.subOff&&this.t>=this.next-0.3){this.el.sub.classList.remove('on');this.subOff=0;}
  if(this.t>3.8)this.el.title.classList.remove('show');
  if(this.phase==='intro'){this.camera(dt,p);if(!this.q.length&&this.t>=this.next+0.3)this.endIntro();return;}
  if(this.phase==='cine'){this.camera(dt,p);return;}
  if(S.state!=='run')return;this.triggers();}
 endIntro(){if(this.phase!=='intro')return;this.phase='play';this.q=[];this.voice&&this.voice.stop();this.el.sub.classList.remove('on');this.el.title.classList.remove('show');
  document.body.classList.remove('cine');this.S.introHold=false;this.g.setCam(this.userCam);this.playT=this.t;}
 skip(){if(this.phase==='intro')this.endIntro();else if(this.phase==='cine'){this.q=[];this.voice&&this.voice.stop();this.S.finishCinematic&&this.S.finishCinematic();}}
 say(tr){const L=this.m.during&&this.m.during[tr];if(!L||!L.length)return;const n=this.cnt[tr]||0;if(n>=(tr==='rival_cerca'?2:1))return;this.cnt[tr]=n+1;
  const k=n%L.length;if(this.q.length<2)this.q.push([L[k][0],L[k][1],lineId(this.m.id,'d_'+tr,k)]);}
 triggers(){const S=this.S,m=this.m,pl=S.player,p=pl.phys,t=this.t-this.playT;
  if(t>1.4&&!this.done.has('inicio')){this.done.add('inicio');this.say('inicio');}
  let near=1e9;for(const c of S.cars)if(c.ai)near=Math.min(near,Math.hypot(c.phys.px-p.px,c.phys.pz-p.pz));
  if(near<12&&t>5&&this.t-(this.lastRival||-99)>20){this.lastRival=this.t;this.say('rival_cerca');}
  if((p.damage||0)>=0.5)this.say('dano50');
  const L=S.raceLen;if(S.route&&L){const f=pl.prog/L;if(f>0.5)this.say('mitad');if(L-pl.prog<250&&L-pl.prog>0)this.say('final_cerca');
   if(S.type==='trap'&&L-pl.prog<300)this.say('radar');
   if(m.stars.time&&f>0.45&&!this.done.has('tm')){this.done.add('tm');if(S.time>m.stars.time[0]*f*0.97)this.say('tiempo_mal');}}
  if(S.type==='rush'&&S.cfg.time&&S.cfg.time-S.time<25)this.say('poco_tiempo');}
 /* al terminar: frases de victoria/derrota y, si cierra el capítulo, el gancho */
 end(ok){const wasCine=this.phase==='cine';this.phase='end';if(!wasCine)this.q=[];document.body.classList.remove('cine');const m=this.m;
  const L=(ok?m.win:m.lose).map((l,k)=>[l[0],l[1],lineId(m.id,ok?'win':'lose',k)]);
  const ch=CHAPTERS.find(c=>c.n===m.chapter);if(ok&&ch&&ch.missions[ch.missions.length-1].id===m.id){this.hookScene=true;L.push(...ch.hook.map((l,k)=>[l[0],l[1],lineId('ch'+ch.n,'hook',k),true]));}
  this.enqueue(L);this.next=Math.max(this.t,this.next)+(wasCine?0:0.6);let tot=Math.max(0,this.next-this.t)+0.6;for(const l of this.q)tot+=(this.voice?this.voice.dur(l[2],l[0]):2.5)+0.45;return tot;}
 /* ─── planos: con los autos quietos (presentación) o andando (cinemática) ─── */
 camera(dt,p){const m=this.m,shots=m.shots&&m.shots.length?m.shots:['persecucion_lejos'],len=this.phase==='cine'?5.5:3.6;
  this.shotT+=dt;if(this.shotI<0||this.shotT>len){this.shotT=0;this.shotI=(this.shotI+1)%shots.length;this.snap=true;this.shotOrb=Math.random()*6.28;
   const RIG={interior:0,detras_piloto:6,persecucion_cerca:2,persecucion_lejos:3,aerea:4,capo:7,paragolpes:8};const sh=shots[this.shotI];this.rig=RIG[sh];this.g.setCam(this.rig!=null?this.rig:1);
   if(sh==='costado_pista'){const tr=this.S.track,fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw),ahead=this.phase==='cine'?40:22,side=(Math.random()<0.5?-1:1)*7;
    const x=p.px+fx*ahead+lx*side,z=p.pz+fz*ahead+lz*side;this.fix=new THREE.Vector3(x,(tr.ground?tr.ground(x,z):p.py)+1.5,z);}}
  if(this.rig!=null)return;
  const sh=shots[this.shotI],c=this.g.camera,S=this.S;const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw);
  let near=null,nd=1e9;for(const o of S.cars)if(o.ai){const d=Math.hypot(o.phys.px-p.px,o.phys.pz-p.pz);if(d<nd){nd=d;near=o.phys;}}
  const W=this._w||(this._w=new THREE.Vector3()),Lk=this._l||(this._l=new THREE.Vector3());let fov=50,kp=3,kl=6;const orb=this.shotOrb+this.shotT*0.12;
  if(sh==='dos_autos'&&near){const mx=(p.px+near.px)/2,mz=(p.pz+near.pz)/2,sep=Math.hypot(p.px-near.px,p.pz-near.pz);const off=Math.min(14,5+sep*0.6);W.set(mx+lx*off+fx*Math.sin(orb)*2,p.py+1.8,mz+lz*off+fz*Math.sin(orb)*2);Lk.set(mx,p.py+0.3,mz);fov=46;}
  else if(sh==='de_frente'||sh==='salto_camara_lenta'||(sh==='dos_autos'&&!near)){W.set(p.px+fx*9+lx*Math.sin(orb)*2.5,p.py+1.2,p.pz+fz*9+lz*Math.sin(orb)*2.5);Lk.set(p.px-fx*4,p.py+0.4,p.pz-fz*4);fov=44;}
  else if(sh==='costado_pista'&&this.fix){W.copy(this.fix);Lk.set(p.px,p.py+0.4,p.pz);const d=W.distanceTo(Lk);fov=THREE.MathUtils.clamp(2*Math.atan(5/d)*57.3,18,55);kp=100;}
  else{/* helicóptero: órbita alta y lenta */W.set(p.px+Math.sin(orb)*16,p.py+11,p.pz+Math.cos(orb)*16);Lk.set(p.px,p.py,p.pz);fov=48;}
  const tr=S.track;if(tr&&tr.ground){const gy=tr.ground(W.x,W.z)+0.8;if(W.y<gy)W.y=gy;}
  if(this.snap){this.pos.copy(W);this.look.copy(Lk);this.snap=false;}else{this.pos.lerp(W,1-Math.exp(-dt*kp));this.look.lerp(Lk,1-Math.exp(-dt*kl));}
  c.position.copy(this.pos);c.up.set(0,1,0);c.lookAt(this.look);c.fov+=(fov-c.fov)*Math.min(1,dt*5);c.near=0.15;c.updateProjectionMatrix();}
 dispose(){document.body.classList.remove('story','cine','nohp');this.voice&&this.voice.stop();this.el.skip.onclick=null;this.el.sub.classList.remove('on');this.el.title.classList.remove('show');if(this.phase!=='play'&&this.phase!=='end'&&this.g.getCam()!==this.userCam)this.g.setCam(this.userCam);}
}
export {CHAPTERS,MISSIONS,MISSION_BY_ID};
