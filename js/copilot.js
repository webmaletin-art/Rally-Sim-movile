/* ═══ El copiloto que habla según lo que pasa ═══
   756 frases grabadas (audio/cd/*.ogg + audio/cd.json). Mira la carrera y, según la situación,
   elige UNA frase al azar de esa situación, sin repetir hasta usarlas todas.
   - Avisos urgentes (frená, rival al lado, golpe fuerte) cortan lo que esté diciendo.
   - La charla solo aparece en silencio, en recta y sin nadie cerca.
   - Las notas de ruta (curvas) siempre tienen prioridad: cuando cantan una, el copiloto se calla.
   - Cada situación tiene su pausa para que no repita el mismo aviso seguido. */
import {speedProfile} from './ai.js';

/* prioridad (3 urgente · 2 aviso · 1 comentario) y pausa mínima en segundos entre dos frases de la misma situación */
const K={
 largada:[2,0],rival_atras:[2,20],rival_izquierda:[3,10],rival_derecha:[3,10],nos_pasaron:[2,10],pasamos_rival:[2,10],
 vamos_primeros:[1,45],vamos_segundos:[1,45],vamos_terceros:[1,45],vamos_cuartos:[1,45],vamos_quintos:[1,45],vamos_ultimos:[1,45],
 primero_con_ventaja:[1,60],cerca_del_de_adelante:[2,25],ultima_vuelta:[2,0],falta_poco:[2,0],
 acelera_mas:[1,35],frena_ya:[3,7],buena_curva:[1,30],buen_derrape:[1,18],trompo:[3,10],fuera_de_pista:[2,15],volver_a_pista:[1,12],
 sentido_contrario:[3,8],quietos:[2,25],muy_rapido:[1,60],nitro:[2,25],cambio_superficie_tierra:[1,30],cambio_superficie_asfalto:[1,30],
 salto:[2,10],aterrizaje_fuerte:[2,10],tunel:[1,40],lluvia:[1,0],choque_leve:[2,6],choque_fuerte:[3,6],pared:[2,8],nos_chocaron:[3,6],
 auto_danado:[2,30],reaparecer:[2,5],ganamos:[3,0],podio:[3,0],perdimos:[3,0],record:[3,0],vamos_ganando_tiempo:[1,25],vamos_perdiendo_tiempo:[1,25],
 drift_combo_alto:[1,12],drift_combo_cortado:[1,12],radar_cerca:[2,0],bandera_tomada:[1,4],poco_tiempo:[2,0],estacionar_despacio:[1,0],
 cartel_roto:[1,6],charla_recta:[1,40],animo:[1,90]};
/* en el modo historia el director ya reacciona a golpes, perseguidores y final: el copiloto no lo pisa */
const STORY_SKIP=new Set(['choque_leve','choque_fuerte','nos_chocaron','rival_atras','charla_recta','animo','ganamos','perdimos','podio','largada','auto_danado']);
/* frases que conviene tener ya decodificadas (tienen que sonar al instante) */
const HOT=['frena_ya','rival_izquierda','rival_derecha','rival_atras','choque_fuerte','nos_chocaron','pared','trompo','salto'];

export class CoPilot{
 constructor(){this.idx=null;this.bags={};this.buf=new Map();this.order=[];this.last={};this.busyUntil=0;this.cur=null;this.curPri=0;this.lastTalk=-99;this.st={};}
 load(ctx){if(this.loading||!ctx)return this.loading;this.ctx=ctx;
  this.loading=fetch('audio/cd.json').then(r=>r.json()).then(j=>{this.idx=j;this.chain();for(const k of HOT)this.prep(k);}).catch(e=>{console.warn('copiloto',e);this.failed=true;});return this.loading;}
 get ready(){return !!this.idx;}
 chain(){const c=this.ctx;/* mismo intercom que las notas de ruta */
  const hp=c.createBiquadFilter();hp.type='highpass';hp.frequency.value=320;const lp=c.createBiquadFilter();lp.type='lowpass';lp.frequency.value=3600;
  const pk=c.createBiquadFilter();pk.type='peaking';pk.frequency.value=1800;pk.Q.value=0.9;pk.gain.value=5;
  const sh=c.createWaveShaper(),cv=new Float32Array(512);for(let i=0;i<512;i++){const x=i/255.5-1;cv[i]=Math.tanh(x*1.6)/Math.tanh(1.6);}sh.curve=cv;
  this.out=c.createGain();this.out.gain.value=0.9;hp.connect(lp).connect(pk).connect(sh).connect(this.out).connect(c.destination);this.input=hp;}
 /* bolsa mezclada por situación: no se repite ninguna hasta usarlas todas (y la última no sale primera en la vuelta siguiente) */
 next(key){const L=this.idx[key];if(!L||!L.length)return -1;let b=this.bags[key];
  if(!b||!b.length){b=this.bags[key]=L.map((_,i)=>i);for(let i=b.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[b[i],b[j]]=[b[j],b[i]];}if(b.length>1&&b[b.length-1]===this.last[key])[b[0],b[b.length-1]]=[b[b.length-1],b[0]];}
  return b.pop();}
 decode(file){const hit=this.buf.get(file);if(hit)return hit;
  const pr=fetch('audio/cd/'+file).then(r=>r.arrayBuffer()).then(ab=>new Promise((res,rej)=>{const p=this.ctx.decodeAudioData(ab,res,rej);if(p&&p.then)p.then(res,rej);}));
  this.buf.set(file,pr);this.order.push(file);if(this.order.length>60)this.buf.delete(this.order.shift());return pr;}
 prep(key){if(!this.idx||!this.idx[key])return;const i=this.next(key);if(i<0)return;const it=this.idx[key][i];this.st['p_'+key]=i;this.decode(it[0]);}
 /* key: situación · pri: 3 corta todo, 2 espera turno corto, 1 solo en silencio */
 say(key,o={}){if(!this.idx||!this.enabled||!this.ctx||this.ctx.state!=='running')return false;if(this.storyMode&&STORY_SKIP.has(key))return false;
  const [p0,cool]=K[key]||[1,20],pri=o.pri||p0,now=this.ctx.currentTime;if(this.minPri&&pri<this.minPri)return false;
  if(cool&&this.last['t_'+key]!=null&&now-this.last['t_'+key]<cool)return false;
  if(now<this.busyUntil){if(pri>=3&&pri>this.curPri)this.stop();else return false;}
  if(pri<=1&&now-this.lastTalk<(this.gap||6))return false;
  const L=this.idx[key];if(!L)return false;let i=this.st['p_'+key];if(i==null)i=this.next(key);delete this.st['p_'+key];const it=L[i];if(!it)return false;
  this.last[key]=i;this.last['t_'+key]=now;this.curPri=pri;this.busyUntil=now+it[2]/1.05+0.25;this.lastTalk=now;
  const vol=this.volume??1;this.decode(it[0]).then(b=>{if(this.ctx.currentTime>this.busyUntil+0.5)return;/* llegó tarde: ya no sirve */
   const s=this.ctx.createBufferSource();s.buffer=b;s.playbackRate.value=1.05;s.connect(this.input);this.out.gain.setValueAtTime(0.95*vol,this.ctx.currentTime);s.start();this.cur=s;s.onended=()=>{if(this.cur===s)this.cur=null;};}).catch(()=>{});
  if(HOT.includes(key))this.prep(key);return true;}
 stop(){if(this.cur)try{this.cur.stop();}catch(e){}this.cur=null;this.busyUntil=0;this.curPri=0;}
 /* las notas de ruta hablan: el copiloto se calla y espera */
 hold(until){if(this.curPri<3)this.stop();this.busyUntil=Math.max(this.busyUntil,until);this.curPri=2;}

 /* ─── al empezar una sesión ─── */
 configure(settings){const lvl=settings.chatter||'normal';this.enabled=settings.copilot!==false&&lvl!=='nada';this.minPri=lvl==='poco'?2:0;this.gap=lvl==='poco'?12:6;this.volume=Math.min(1,(settings.volume??80)/80);}
 begin(S,settings){this.S=S;this.st={};this.storyMode=S.type==='story';this.configure(settings);
  const p=S.player.phys,V=p.V;this.prof=null;
  if(S.route){const surf=S.track.mode==='asphalt'?'asphalt':'dirt';const mu=V.mu*(V.surfGrip[surf]||0.8)*Math.min(V.gripFront,V.gripRear)*0.98;this.prof=speedProfile(S.track,Math.round(mu*50)/50);}}
 /* eventos que avisa la sesión */
 event(name,d={}){if(!this.S||!this.ctx)return;const S=this.S;
  switch(name){
   case 'go':if(!['free','world','test','story'].includes(S.type))this.say('largada');this.st.goT=S.time;break;
   case 'pos':{const now=this.ctx.currentTime;if(now-(this.st.posSaid||-99)<8)break;if(this.say(d.to<d.from?'pasamos_rival':'nos_pasaron'))this.st.posSaid=now;break;}
   case 'lastlap':this.say('ultima_vuelta');break;
   case 'hit':{if(d.wall){this.say(d.imp>9?'choque_fuerte':'pared');}else if(d.byRival&&d.imp>3)this.say('nos_chocaron');else this.say(d.imp>=5?'choque_fuerte':'choque_leve');break;}
   case 'split':this.say(d.d<0?'vamos_ganando_tiempo':'vamos_perdiendo_tiempo');break;
   case 'flag':this.say('bandera_tomada');break;
   case 'board':this.say('cartel_roto');break;
   case 'respawn':this.say('reaparecer');break;
   case 'finish':{this.stop();const k=d.record?'record':S.type==='race'?(d.pos===1?'ganamos':d.pos<=3?'podio':'perdimos'):d.ok?(S.type==='timetrial'?'record':'ganamos'):'perdimos';
    this.say(k,{pri:3});break;}}}
 /* cada cuadro: mirar la carrera */
 update(dt,S,input){if(!this.idx||!this.enabled||S!==this.S||S.state!=='run'||S.cine)return;const st=this.st;st.acc=(st.acc||0)+dt;if(st.acc<0.1)return;const h=st.acc;st.acc=0;
  const pl=S.player,p=pl.phys,sp=Math.hypot(p.vx,p.vz),t=S.type,tr=S.track,N=tr.samples?tr.samples.length:1;
  const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw);
  /* rivales alrededor */
  let side=null,behind=false,ahead=false,near=1e9;
  for(const c of S.cars){if(!c.ai||c.ai.passive||c.sleep)continue;const q=c.phys,dx=q.px-p.px,dz=q.pz-p.pz,f=dx*fx+dz*fz,l=dx*lx+dz*lz,d=Math.hypot(dx,dz);near=Math.min(near,d);
   if(Math.abs(f)<3.5&&Math.abs(l)>1.6&&Math.abs(l)<5)side=l>0?'rival_izquierda':'rival_derecha';
   else if(f<-3.5&&f>-14&&Math.abs(l)<2.8)behind=true;
   else if(f>5&&f<20&&Math.abs(l)<4&&(sp-(q.vx*fx+q.vz*fz))>1)ahead=true;}
  if(side)this.say(side);else if(behind)this.say('rival_atras');else if(ahead&&t==='race')this.say('cerca_del_de_adelante');
  /* la ruta: curvas, velocidad, salidas */
  if(S.route&&this.prof){const i=pl.idx||0,v=this.prof.v,kap=this.prof.kap;
   let dist=0,minV=1e9,j=i;const Ld=sp*1.6+10;while(dist<Ld){const k=(j+1)%N;dist+=tr.samples[j].distanceTo(tr.samples[k]);j=k;minV=Math.min(minV,v[j]);}
   if(sp>14&&minV<30&&sp>minV*1.28&&(input.brake||0)<0.3)this.say('frena_ya');
   let far=1e9;dist=0;j=i;while(dist<130){const k=(j+1)%N;dist+=tr.samples[j].distanceTo(tr.samples[k]);j=k;far=Math.min(far,v[j]);}
   st.slowT=(far>sp+12&&sp<25&&(input.throttle||0)<0.6)?(st.slowT||0)+h:0;if(st.slowT>2&&['race','timetrial','story','trap'].includes(t))this.say('acelera_mas');
   /* curva bien hecha: entrar, mantener buen ritmo y salir sin tocar nada */
   const kc=kap[i];if(kc>1/70){if(!st.inC){st.inC=true;st.cMin=9;st.cBad=false;}st.cMin=Math.min(st.cMin,sp/Math.max(1,v[i]));}
   else if(st.inC&&kc<1/150){st.inC=false;if(st.cMin>0.85&&!st.cBad&&Math.random()<0.6)this.say('buena_curva');}
   const hw=tr.hwA?tr.hwA[i]:tr.halfWidth+(tr.shoulder||0);const off=Math.abs(pl.lat||0)>hw+1.5;
   st.offT=off?(st.offT||0)+h:0;if(st.offT>0.7&&!st.wasOff){st.wasOff=true;st.cBad=true;this.say('fuera_de_pista');}
   if(st.wasOff&&!off&&Math.abs(pl.lat||0)<hw-0.5){st.wasOff=false;this.say('volver_a_pista');}
   if(tr.inTunnel){tr._hint=p.trackHint;const inT=tr.inTunnel(p.px,p.pz);if(inT&&!st.tun)this.say('tunel');st.tun=inT;}
   if(!st.finNear&&S.raceLen&&S.raceLen-pl.prog<220&&S.raceLen-pl.prog>0&&['race','timetrial','story'].includes(t)){st.finNear=true;this.say('falta_poco');}
   if(!st.radar&&t==='trap'&&S.raceLen-pl.prog<350){st.radar=true;this.say('radar_cerca');}
   if(S.wrongShown&&!st.wrong)this.say('sentido_contrario');st.wrong=S.wrongShown;}
  /* superficie (asfalto / tierra) */
  {let a=0,d=0;for(const w of p.wheels)if(w.contact){if(w.surf==='asphalt')a++;else if(w.surf==='dirt')d++;}const s=a>=3?'asphalt':d>=3?'dirt':null;
   if(s&&s!==st.surf){st.surfT=(st.surfT||0)+h;if(st.surfT>0.8){if(st.surf&&sp>8)this.say(s==='dirt'?'cambio_superficie_tierra':'cambio_superficie_asfalto');st.surf=s;st.surfT=0;}}else st.surfT=0;}
  /* derrape, trompo */
  const beta=Math.abs(Math.atan2(p.vLat||0,Math.abs(p.vLong||0)));
  if(sp>5&&((p.vLong||0)<-2||beta>1.9)){if(!st.spin){st.spin=true;st.cBad=true;this.say('trompo');}}else if(sp<3||beta<0.3)st.spin=false;
  if(t!=='drift'){if(beta>0.3&&sp>10&&p.contacts>=2&&!st.spin)st.dT=(st.dT||0)+h;else if(beta<0.12){if((st.dT||0)>1.2&&!st.spin)this.say('buen_derrape');st.dT=0;}}
  else{const d=S.drift;if(d){if(d.mult>=4&&!st.hiC){st.hiC=true;this.say('drift_combo_alto');}if(d.combo===0&&(st.lastCombo||0)>4)this.say('drift_combo_cortado');if(d.combo===0)st.hiC=false;st.lastCombo=d.combo;}}
  /* saltos */
  const air=p.wheels.every(w=>!w.contact);if(air){st.airT=(st.airT||0)+h;if(st.airT>0.35&&!st.jumped){st.jumped=true;this.say('salto');}}
  else{if((st.airT||0)>0.8&&Math.random()<0.6)this.say('aterrizaje_fuerte');st.airT=0;st.jumped=false;}
  /* parado, rápido, nitro, daño */
  st.stopT=(sp<1&&(input.throttle||0)<0.1&&t!=='parking')?(st.stopT||0)+h:0;if(st.stopT>7)this.say('quietos');
  if(sp*3.6>185)this.say('muy_rapido');
  if(p.nitroActive&&!st.nitro&&Math.random()<0.6)this.say('nitro');st.nitro=p.nitroActive;
  const dm=p.damage||0;if(dm>=0.5&&!st.d50){st.d50=true;this.say('auto_danado');}if(dm>=0.8&&!st.d80){st.d80=true;this.say('auto_danado',{pri:3});}
  /* tiempo y modos */
  if(!st.rain&&S.time>3.5&&S.cfg.sky==='rain'&&t!=='world'){st.rain=true;this.say('lluvia');}
  if(!st.lowT&&(t==='rush'||t==='drift')&&S.cfg.time&&S.cfg.time-S.time<12){st.lowT=true;this.say('poco_tiempo');}
  if(!st.park&&t==='parking'&&S.time>1.5){st.park=true;this.say('estacionar_despacio');}
  /* posición en carrera (de vez en cuando) y ánimo */
  if(t==='race'&&S.time>12){st.posT=(st.posT||0)+h;if(st.posT>38+Math.random()*20){const std=S.standings(),pos=std.indexOf(pl)+1,n=std.length;let k=null;
    if(pos===1){const gap=pl.prog-(std[1]?std[1].prog:0);k=gap>150?'primero_con_ventaja':'vamos_primeros';}else if(pos===n&&n>=3)k='vamos_ultimos';else k=['','','vamos_segundos','vamos_terceros','vamos_cuartos','vamos_quintos'][pos]||null;
    if(k&&this.say(k))st.posT=0;if(pos===n&&n>=3&&S.time>45)this.say('animo');}}
  /* charla: en silencio, en recta, sin nadie cerca */
  if(this.ctx.currentTime-this.lastTalk>22&&sp>12&&near>25&&!air){st.chatT=(st.chatT||0)+h;if(st.chatT>3){st.chatT=0;let straight=true;if(S.route&&this.prof){const i=pl.idx||0;for(let k=0;k<25;k++)if(this.prof.kap[(i+k)%N]>1/120){straight=false;break;}}if(straight&&Math.random()<0.5)this.say('charla_recta');}}}
}
