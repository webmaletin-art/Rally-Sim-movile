/* ═══ GSKORP RALLY — menús ═══
   Pantallas DOM sobre el showroom 3D. Toda acción de juego pasa por `api` (lo provee Game). */
import {CAR_META,CAR_ORDER,COMING_SOON,UPGRADES,TIRES,TIRE_BY_ID,TUNE_GROUPS,TUNE_ITEMS,PAINTS,FINISHES,ACHIEVEMENTS,xpForLevel} from './data.js';
import {TIERS,EVENTS,TYPE_INFO,TARGETS,lowerIsBetter,rewardFor} from './events.js';
import {classOf,unlocksOf,defaultTune} from './carbuild.js';
import {PRESET_INFO} from './post.js';

const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
export const fmtCr=n=>'$ '+Math.round(n).toLocaleString('es-AR');
export const fmtTime=s=>{if(s==null||!isFinite(s))return '--:--.--';const m=Math.floor(s/60),ss=Math.floor(s%60),cc=Math.floor((s*100)%100);return `${String(m).padStart(2,'0')}:${String(ss).padStart(2,'0')}.${String(cc).padStart(2,'0')}`;};
const MEDAL=['','b','s','g'],MEDAL_N=['Sin medalla','Bronce','Plata','Oro'];
const SKY_N={day:'☀️ Día',sunset:'🌇 Atardecer',overcast:'☁️ Nublado',dusk:'🌆 Anochecer',rain:'🌧️ Lluvia'};
function clsBadge(pi){const c=classOf(pi);return `<span class="cls"><b style="background:${c.col}">${c.c}</b><span>${pi}</span></span>`;}
function medals(m){return `<span class="medals">${[1,2,3].map(i=>`<i class="medal ${m>=i?MEDAL[i]:''}"></i>`).join('')}</span>`;}

export class UI{
 constructor(api){
  this.api=api;this.P=api.profile;this.root=document.getElementById('ui');this.cur=null;this.tier='debut';this.wsCat='engine';this.tuneInfo={};
  this.root.addEventListener('click',e=>{const b=e.target.closest('[data-a]');if(!b||b.disabled)return;e.preventDefault();this.api.sfx('click');this.act(b.dataset.a,b.dataset,b);});
  this.P.on(()=>this.refreshTop());}
 /* ─── utilidades ─── */
 mount(html,cls){this.root.innerHTML=`<div class="scr ${cls||''}">${html}</div>`;return this.root.firstChild;}
 top(extra,gear){const d=this.P.d,need=xpForLevel(d.level);
  return `<div class="topbar">${extra||''}<div class="logo">GSKORP <b>RALLY</b><small>SIMULACIÓN</small></div><div class="spacer"></div>
   <div class="pill"><span class="ic">⭐</span><div class="lvl"><span>NIVEL <b id="tLvl">${d.level}</b></span><div class="xpbar"><i id="tXp" style="width:${Math.min(100,d.xp/need*100)}%"></i></div></div></div>
   <div class="pill"><span class="ic">💰</span><span id="tCr">${fmtCr(d.credits)}</span></div>${gear?'<button class="iconbtn" data-a="go" data-s="options">⚙️</button>':''}</div>`;}
 refreshTop(){const d=this.P.d,a=document.getElementById('tCr');if(a)a.textContent=fmtCr(d.credits);const l=document.getElementById('tLvl');if(l)l.textContent=d.level;const x=document.getElementById('tXp');if(x)x.style.width=Math.min(100,d.xp/xpForLevel(d.level)*100)+'%';}
 toast(msg,cls){const t=document.createElement('div');t.className='toast '+(cls||'');t.textContent=msg;document.getElementById('toasts').appendChild(t);setTimeout(()=>t.remove(),2700);}
 sheet(html){const bg=document.createElement('div');bg.className='sheetBg';bg.innerHTML=`<div class="sheet">${html}</div>`;bg.addEventListener('click',e=>{if(e.target===bg)bg.remove();});(this.root.firstChild||this.root).appendChild(bg);return bg;}
 closeSheet(){const s=this.root.querySelector('.sheetBg');if(s)s.remove();}
 stars(){let n=0;for(const k in this.P.d.events)n+=this.P.d.events[k].medal||0;return n;}
 carInfo(id,state){const perf=this.api.perf(id,state);const m=CAR_META[id];
  return {perf,html:`<div class="carName"><small>${m.brand}</small>${m.model}</div><div class="row"><span class="kind">${m.kind} · ${m.drive}</span>${clsBadge(perf.pi)}</div>`};}
 statBlock(perf,cmp){const B=[['speed','Velocidad'],['accel','Aceleración'],['handling','Manejo'],['braking','Frenado'],['offroad','Todoterreno']];
  return `<div class="stats">${B.map(([k,n])=>{const v=perf.bars[k],c=cmp?cmp.bars[k]:v;const lo=Math.min(v,c),hi=Math.max(v,c);
   return `<div class="stat">${n}<div class="bar"><i style="width:${lo*100}%"></i>${hi>lo+0.004?`<i class="${c>v?'up':'dn'}" style="left:${lo*100}%;width:${(hi-lo)*100}%"></i>`:''}</div><em>${(c*10).toFixed(1)}</em></div>`}).join('')}</div>`;}
 specs(perf){return `<div class="specs"><div class="spec"><b>${perf.hp}</b><span>cv</span></div><div class="spec"><b>${perf.kg}</b><span>kg</span></div><div class="spec"><b>${perf.vmax}</b><span>km/h</span></div></div>`;}

 /* ─── acciones ─── */
 act(a,ds,btn){const A=this.api,P=this.P;
  switch(a){
   case 'go':this.show(ds.s,ds.p);break;
   case 'home':this.show('home');break;
   case 'tap':A.unlockAudio();if(!P.d.current)this.show('starter');else{this.show('home');this.daily();}break;
   case 'starterPick':this.starterSel=ds.id;A.showCar(ds.id);this.show('starter');break;
   case 'starterOk':{const id=this.starterSel||'t1plus';P.give(id);P.select(id);this.toast(`¡${CAR_META[id].brand} ${CAR_META[id].model} es tuyo!`,'green');this.show('home');this.daily();break;}
   case 'tier':{const t=TIERS.find(x=>x.id===ds.id);if(!this.tierOpen(t)){A.sfx('error');this.toast(t.car&&!P.owns(t.car)?'Necesitás el '+CAR_META[t.car].brand+' '+CAR_META[t.car].model:`Necesitás ${t.stars} ⭐ para abrir esta copa`);break;}this.tier=ds.id;this.show('career');break;}
   case 'ev':{const ev=EVENTS.find(e=>e.id===ds.id);const lk=this.evLocked(ev);if(lk){A.sfx('error');this.toast('🔒 '+lk);break;}this.eventSheet(ev);break;}
   case 'nextEv':this.openNext();break;
   case 'evRun':{const ev=EVENTS.find(e=>e.id===ds.id);this.closeSheet();A.startEvent(ev);break;}
   case 'close':this.closeSheet();break;
   case 'selCar':P.select(ds.id);A.showCar(ds.id);this.show(this.cur);break;
   case 'dealerPick':this.dealerSel=ds.id;A.showCar(ds.id,null);this.show('dealer');break;
   case 'buyCar':{const id=ds.id,m=CAR_META[id];if(P.credits<m.price){A.sfx('error');this.toast('No te alcanza la plata');break;}
    const s=this.sheet(`<h3>¿Comprar ${m.brand} ${m.model}?</h3><p>${fmtCr(m.price)} · te quedan ${fmtCr(P.credits-m.price)}</p><div class="row"><button class="bigbtn green" data-a="buyCarOk" data-id="${id}"><span class="bi">✔</span><span class="bt">Comprar</span></button><button class="back" data-a="close">Cancelar</button></div>`);break;}
   case 'buyCarOk':if(P.buyCar(ds.id)){A.sfx('buy');this.closeSheet();this.toast('¡Auto nuevo en el garaje!','green');A.showCar(ds.id);this.show('garage');}break;
   case 'testDrive':A.testDrive(ds.id);break;
   case 'wsCat':this.wsCat=ds.id;this.show('workshop');break;
   case 'buyPart':{const id=P.d.current,cat=ds.cat,lvl=+ds.l;const ok=P.buyUpgrade(id,cat,lvl);if(ok){A.sfx(lvl>0?'buy':'click');A.carChanged();this.show('workshop');}else{A.sfx('error');this.toast('No te alcanza la plata');}break;}
   case 'buyTire':{const ok=P.buyTires(P.d.current,ds.id);if(ok){A.sfx('buy');A.carChanged();this.show('workshop');}else{A.sfx('error');this.toast('No te alcanza la plata');}break;}
   case 'tuneReset':{const car=P.car;car.tune={};P.save();A.carChanged();this.show('tuning');break;}
   case 'tunePreset':{const car=P.car;car.tune={...(car.tune||{}),...PRESETS[ds.id]};P.save();A.carChanged();this.toast('Preset "'+ds.n+'" aplicado','blue');this.show('tuning');break;}
   case 'tq':{const k=ds.k;this.tuneInfo[k]=!this.tuneInfo[k];btn.closest('.tr').classList.toggle('info');break;}
   case 'paint':{const car=P.car;car.paint[ds.slot]=ds.c;P.save();A.carChanged();this.show('paint');break;}
   case 'finish':{const car=P.car;car.paint.finish=ds.id;P.save();A.carChanged();this.show('paint');break;}
   case 'set':{const s=P.d.settings;let v=ds.v;if(v==='true')v=true;else if(v==='false')v=false;else if(!isNaN(+v))v=+v;s[ds.k]=v;P.save();A.applySettings();this.show('options');break;}
   case 'gyro':A.toggleGyro().then(r=>{if(r&&r.err)this.toast(r.err);this.show(this.cur==='pause'?'pause':'options');});break;
   case 'gyroCal':A.recalGyro();this.toast('Acelerómetro recalibrado','blue');break;
   case 'resetAll':this.sheet(`<h3>¿Borrar todo el progreso?</h3><p>Se pierden autos, dinero y medallas. No se puede deshacer.</p><div class="row"><button class="bigbtn" data-a="resetOk"><span class="bt">Borrar</span></button><button class="back" data-a="close">Cancelar</button></div>`);break;
   case 'resetOk':P.reset();location.reload();break;
   case 'quick':this.quickRun();break;
   case 'testTrack':this.api.startQuick({mode:'timetrial',map:'descent',laps:1,ai:0,skill:1,sky:'day',seg:[0,0.47]});break;
   case 'qset':this.q[ds.k]=isNaN(+ds.v)?ds.v:+ds.v;this.show('quick');break;
   case 'world':A.openWorld();break;
   case 'claim':{const a=ACHIEVEMENTS.find(x=>x.id===ds.id),d=P.d;d.claimed=d.claimed||{};if(a&&!d.claimed[a.id]&&a.test(d)){d.claimed[a.id]=1;P.earn(a.cr);A.sfx('buy');this.toast(`${a.icon} ${a.n} · +${fmtCr(a.cr)}`,'green');}this.show('goals');break;}
   case 'resume':A.resume();break;
   case 'respawn':A.respawn();break;
   case 'restart':A.restart();break;
   case 'quit':A.quit();break;
   case 'cam':A.nextCam();break;
   case 'resOk':A.afterResults(ds.next);break;
   case 'retry':A.retry();break;
  }}
 statsBlock(){const st=this.P.d.stats,d=this.P.d;const traps=Object.values(st.traps||{});const cups=Object.keys(d.cups||{}).length;
  const k=[['🛣️',Math.round(st.km)+' km','recorridos'],['🏁',st.races,'carreras'],['🥇',st.wins,'victorias'],['🏆',st.podiums,'podios'],['⚡',st.topSpeed+' km/h','vel. máxima'],['🌀',(st.driftBest||0).toLocaleString('es-AR'),'mejor drift'],['💥',Object.keys(st.boards||{}).length+'/12','carteles'],['📸',traps.length?Math.max(...traps)+' km/h':'—','mejor radar'],['⭐',this.stars(),'estrellas'],['👑',cups+'/5','copas']];
  return `<h4 class="ttl" style="font-size:12px;color:var(--acc2);margin-top:12px">Récords del piloto</h4><div class="kv">${k.map(([i,v,n])=>`<div><span>${i} ${n}</span><b>${v}</b></div>`).join('')}</div>`;}
 goalsReady(){const d=this.P.d,cl=d.claimed||{};return ACHIEVEMENTS.filter(a=>!cl[a.id]&&a.test(d)).length;}
 s_goals(){const d=this.P.d,cl=d.claimed||{};const done=ACHIEVEMENTS.filter(a=>cl[a.id]).length;
  this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="head"><h2>Logros<small>${done}/${ACHIEVEMENTS.length} cobrados</small></h2></div><div class="body"><div class="grid">${ACHIEVEMENTS.map(a=>{const ok=a.test(d),got=cl[a.id];
   return `<div class="ev ${got?'':ok?'final':'locked'}" style="min-height:96px"><span class="bgic">${a.icon}</span><span class="et">${a.icon} ${got?'COBRADO':ok?'¡LISTO PARA COBRAR!':'EN PROGRESO'}</span><span class="en">${a.n}</span><span class="em">${a.d}</span><span class="er"><span style="color:var(--gold)">${fmtCr(a.cr)}</span>${ok&&!got?`<button class="buy" data-a="claim" data-id="${a.id}">COBRAR</button>`:got?'<span style="color:var(--ok)">✔</span>':''}</span></div>`}).join('')}</div></div>`,'dim');}
 evLocked(ev){const list=EVENTS.filter(e=>e.tier===ev.tier),i=list.indexOf(ev),m=id=>(this.P.eventResult(id)||{}).medal||0;if(i<=0)return null;
  if(ev.final){const miss=list.slice(0,i).filter(e=>m(e.id)<1);return miss.length?`Conseguí medalla en todas las anteriores (faltan ${miss.length})`:null;}
  return m(list[i-1].id)>=1?null:`Conseguí medalla en "${list[i-1].name}"`;}
 nextMission(){for(const t of TIERS){if(!this.tierOpen(t))continue;for(const e of EVENTS.filter(x=>x.tier===t.id))if(!this.evLocked(e)&&!((this.P.eventResult(e.id)||{}).medal>0))return e;}
  for(const t of TIERS){if(!this.tierOpen(t))continue;for(const e of EVENTS.filter(x=>x.tier===t.id))if(!this.evLocked(e)&&((this.P.eventResult(e.id)||{}).medal||0)<3)return e;}return null;}
 openNext(){const e=this.nextMission();if(!e){this.show('career');this.toast('¡Completaste todo lo disponible! Juntá estrellas para abrir otra copa','blue');return;}this.tier=e.tier;this.show('career');this.eventSheet(e);}
 tierOpen(t){if(t.car&&!this.P.owns(t.car))return false;return this.stars()>=t.stars;}
 daily(){const r=this.P.dailyCheck();if(r){this.api.sfx('buy');this.sheet(`<h3>🎁 Bonus diario</h3><p>Día ${r.streak} seguido jugando. Volvé mañana y el premio crece.</p><div class="rew"><div><b>${fmtCr(r.amount)}</b><span>créditos</span></div></div><button class="bigbtn green" data-a="close"><span class="bt">¡Gracias!</span></button>`);}}

 /* ─── pantallas ─── */
 show(name,arg){this.cur=name;this.api.onScreen(name);const f=this['s_'+name];if(f)f.call(this,arg);}
 s_splash(){this.mount(`<div class="stripe" style="top:30%"></div><div class="stripe" style="top:72%"></div>
  <div class="big">GSKORP <b>RALLY</b><small>SIMULACIÓN DE MANEJO</small></div><div class="load"><i id="loadBar"></i></div><div class="tap off" id="tapGo" data-a="tap">Tocá para empezar</div>
  <div class="muted" style="position:absolute;bottom:calc(12px + var(--safe-b));font-size:10px;letter-spacing:2px">FÍSICA REAL · TALLER COMPLETO · MODO CARRERA</div>`,'splash');
  this.root.firstChild.dataset.a='';}
 splashProgress(p,done){const b=document.getElementById('loadBar');if(b)b.style.width=Math.round(p*100)+'%';if(done){const t=document.getElementById('tapGo');if(t){t.classList.remove('off');this.root.firstChild.setAttribute('data-a','tap');}}}
 s_starter(){const sel=this.starterSel||'t1plus';const ids=CAR_ORDER.filter(i=>CAR_META[i].starter);const {perf,html}=this.carInfo(sel,null);
  this.mount(`${this.top()}<div class="split"><div class="panelBox">
   <h2 class="ttl" style="font-size:20px">Elegí tu primer auto</h2><p class="muted" style="font-size:12px;margin:4px 0 10px">Es un regalo. Los demás los vas a ganar corriendo.</p>
   <div class="cars" style="grid-template-columns:1fr 1fr">${ids.map(id=>{const m=CAR_META[id];return `<button class="car ${id===sel?'sel':''}" data-a="starterPick" data-id="${id}"><span class="cb">${m.brand}</span><span class="cn">${m.model}</span><span class="kind">${m.kind}</span></button>`}).join('')}</div>
   <div style="margin-top:12px">${html}<p class="muted" style="font-size:12px;margin:6px 0">${CAR_META[sel].desc}</p>${this.statBlock(perf)}</div>
   <button class="bigbtn" style="margin-top:12px;width:100%" data-a="starterOk"><span class="bi">🔑</span><span class="bt">Este es el mío</span></button></div><div></div></div>`,'fade');}
 s_home(){const P=this.P,id=P.d.current,car=P.car;if(!id||!car)return this.show('starter');const {perf,html}=this.carInfo(id,car);const st=this.stars();
  this.api.showCar(id,car);
  this.mount(`${this.top('',true)}<div class="home"><div class="homeL">
    ${(()=>{const nx=this.nextMission();return nx?`<button class="bigbtn green" data-a="nextEv"><span class="bi">▶</span><span class="bt">Siguiente misión<span class="bs">${esc(nx.name)} · ${TYPE_INFO[nx.type].n} · ${TIERS.find(t=>t.id===nx.tier).name}</span></span></button>`:''})()}
    <button class="bigbtn" data-a="go" data-s="career"><span class="bi">🏆</span><span class="bt">Modo carrera<span class="bs">${st} ⭐ · 5 copas · ${EVENTS.length} eventos</span></span></button>
    <button class="bigbtn blue" data-a="world"><span class="bi">🗺️</span><span class="bt">Mundo abierto<span class="bs">Carteles, radares y libertad total</span></span></button>
    <button class="bigbtn dark" data-a="testTrack"><span class="bi">⛰️</span><span class="bt">Pista de pruebas<span class="bs">Bajada de asfalto con badenes largos · probá frenos, aceleración y dirección</span></span></button>
    <button class="bigbtn dark" data-a="go" data-s="quick"><span class="bi">⚡</span><span class="bt">Evento rápido<span class="bs">Armá tu carrera: pista, rivales, clima</span></span></button>
    <div class="homeTiles">
     <button class="tile" data-a="go" data-s="garage"><span class="ti">🚘</span>Garaje</button>
     <button class="tile" data-a="go" data-s="workshop"><span class="ti">🔧</span>Taller</button>
     <button class="tile" data-a="go" data-s="tuning"><span class="ti">🎛️</span>Ajuste fino</button>
     <button class="tile" data-a="go" data-s="paint"><span class="ti">🎨</span>Pintura</button>
     <button class="tile" data-a="go" data-s="dealer"><span class="ti">🏪</span>Concesionaria</button>
     <button class="tile" data-a="go" data-s="goals" style="position:relative"><span class="ti">🎯</span>Logros${this.goalsReady()?`<b style="position:absolute;top:4px;right:6px;background:var(--bad);border-radius:9px;padding:1px 6px;font-size:10px">${this.goalsReady()}</b>`:''}</button>
    </div></div><div class="homeC"></div>
   <div class="carCard">${html}${this.statBlock(perf)}${this.specs(perf)}<div class="kind">Neumáticos: <b style="color:#fff">${TIRE_BY_ID[car.tires].n}</b> · ${Math.round(car.km)} km recorridos</div></div></div>
   <div class="rot-hint">⟲ deslizá para girar el auto</div>`,'fade');}
 s_career(){if(!this.P.car)return this.show('starter');const P=this.P,tier=TIERS.find(t=>t.id===this.tier),evs=EVENTS.filter(e=>e.tier===tier.id);const st=this.stars();
  const cur=this.api.perf(P.d.current,P.car);
  this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="head"><h2>Modo carrera<small>${st} ⭐ ganadas</small></h2></div>
   <div class="tabs">${TIERS.map(t=>`<button class="tab ${t.id===tier.id?'on':''} ${this.tierOpen(t)?'':'lock'}" data-a="tier" data-id="${t.id}">${t.icon} ${t.name}${this.tierOpen(t)?((P.d.cups||{})[t.id]?' ✔':''):' 🔒 '+t.stars+'⭐'}</button>`).join('')}</div>
   <div class="body"><p class="muted" style="font-size:12px;margin-bottom:8px">${tier.sub} · ${tier.car?'Auto obligatorio: '+CAR_META[tier.car].model:'Clase máxima '+classOf(tier.maxPI).c+' (PI '+tier.maxPI+')'} · Tu auto: ${clsBadge(cur.pi)}</p>
   <div class="grid">${evs.map(e=>{const r=P.eventResult(e.id),ti=TYPE_INFO[e.type],rw=rewardFor(e,3,tier);
    const lk=this.evLocked(e),num=evs.indexOf(e)+1;
    return `<button class="ev ${e.final?'final':''} ${lk?'locked':''}" data-a="ev" data-id="${e.id}"><span class="bgic">${lk?'🔒':ti.icon}</span><span class="et">${num}. ${ti.icon} ${ti.n}${e.final?' · FINAL':''}${lk?' · 🔒':''}</span><span class="en">${esc(e.name)}</span><span class="em">${this.api.mapName(e.map)} · ${SKY_N[e.sky]||''}</span>
     <span class="er">${medals(r?r.medal:0)}<span style="color:var(--gold)">${fmtCr(rw.cr)}</span></span></button>`}).join('')}</div></div>`,'dim');}
 eventSheet(ev){const P=this.P,tier=TIERS.find(t=>t.id===ev.tier),r=P.eventResult(ev.id),ti=TYPE_INFO[ev.type];const perf=this.api.perf(P.d.current,P.car);
  let block='';if(tier.car&&P.d.current!==tier.car)block=`Este evento es solo con el ${CAR_META[tier.car].brand} ${CAR_META[tier.car].model}. Elegilo en el garaje.`;
  else if(perf.pi>tier.maxPI)block=`Tu auto es clase ${classOf(perf.pi).c} (PI ${perf.pi}). Esta copa admite hasta clase ${classOf(tier.maxPI).c} (PI ${tier.maxPI}). Bajá piezas en el taller o usá otro auto.`;
  const t=TARGETS[ev.id],lib=lowerIsBetter(ev.type);const fmtV=v=>ev.type==='drift'?Math.round(v).toLocaleString('es-AR')+' pts':ev.type==='trap'?v+' km/h':ev.type==='rush'?v+' s restantes':fmtTime(v);
  const goal=ev.type==='race'?'1° oro · 2° plata · 3° bronce':t?`🥇 ${fmtV(t[0])} · 🥈 ${fmtV(t[1])} · 🥉 ${fmtV(t[2])}`:'';
  const len=ev.laps?`${ev.laps} vuelta${ev.laps>1?'s':''}`:ev.seg?'Tramo':ev.flags?ev.flags+' banderas':ev.time?ev.time+' s':'—';
  const rw=[3,2,1].map(m=>rewardFor(ev,m,tier));
  this.sheet(`<div class="et" style="color:var(--acc2);font-size:11px;font-weight:800;letter-spacing:1.5px">${ti.icon} ${ti.n.toUpperCase()} · ${tier.name.toUpperCase()}</div><h3>${esc(ev.name)}</h3><p>${esc(ev.desc)}</p>
   <div class="kv"><div><span>Pista</span><b>${this.api.mapName(ev.map)}</b></div><div><span>Formato</span><b>${len}</b></div><div><span>Rivales</span><b>${ev.ai||'—'}</b></div><div><span>Clima</span><b>${SKY_N[ev.sky]||'-'}</b></div><div><span>Récord</span><b>${r&&r.best!=null?fmtV(r.best):'—'}</b></div><div><span>Medalla</span><b>${MEDAL_N[r?r.medal:0]}</b></div></div>
   <p style="font-size:12px"><b>Medallas:</b> ${goal}<br><b>Premio:</b> ${fmtCr(rw[0].cr)} / ${fmtCr(rw[1].cr)} / ${fmtCr(rw[2].cr)} + XP</p>
   ${block?`<div class="warn">${block}</div>`:''}
   <div class="row" style="margin-top:8px"><button class="bigbtn" data-a="evRun" data-id="${ev.id}" ${block?'disabled':''}><span class="bi">🏁</span><span class="bt">Correr</span></button><button class="back" data-a="close">Volver</button></div>`);}
 s_quick(){const q=this.q||(this.q={mode:'race',map:'lake',laps:2,ai:3,skill:1,sky:'day'});
  const MODES=[['race','🏁 Carrera'],['timetrial','⏱️ Contrarreloj'],['drift','🌀 Drift'],['free','🚗 Libre']];
  const maps=this.api.mapList().filter(m=>q.mode==='drift'?(m.kind==='drift'||m.kind==='route'):q.mode==='free'?true:m.kind==='route');
  if(!maps.find(m=>m.id===q.map))q.map=maps[0].id;const segBtn=(k,v,n)=>`<button class="${q[k]==v?'on':''}" data-a="qset" data-k="${k}" data-v="${v}">${n}</button>`;
  this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="head"><h2>Evento rápido<small>Premio reducido · ideal para probar setups</small></h2></div><div class="body"><div class="panelBox">
   <div class="opt">Modo<div class="seg">${MODES.map(([v,n])=>segBtn('mode',v,n)).join('')}</div></div>
   <div class="opt col">Pista<div class="seg wrap">${maps.map(m=>segBtn('map',m.id,m.icon+' '+m.name)).join('')}</div></div>
   ${q.mode==='race'||q.mode==='timetrial'?`<div class="opt">Vueltas<div class="seg">${[1,2,3,5].map(v=>segBtn('laps',v,v)).join('')}</div></div>`:''}
   ${q.mode==='race'?`<div class="opt">Rivales<div class="seg">${[1,3,5].map(v=>segBtn('ai',v,v)).join('')}</div></div><div class="opt">Dificultad<div class="seg">${segBtn('skill',0.9,'Fácil')}${segBtn('skill',1,'Normal')}${segBtn('skill',1.06,'Difícil')}</div></div>`:''}
   <div class="opt">Clima<div class="seg">${Object.keys(SKY_N).map(k=>segBtn('sky',k,SKY_N[k])).join('')}</div></div>
   <button class="bigbtn" style="margin-top:12px" data-a="quick"><span class="bi">▶</span><span class="bt">Largar</span></button></div></div>`,'dim');}
 quickRun(){const q=this.q;this.api.startQuick({...q});}
 s_garage(){if(!this.P.car)return this.show('starter');const P=this.P,ids=CAR_ORDER.filter(i=>P.owns(i)),cur=P.d.current;const {perf,html}=this.carInfo(cur,P.car);this.api.showCar(cur,P.car);
  this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="split"><div class="panelBox"><h2 class="ttl" style="font-size:18px">Mi garaje <span class="muted" style="font-size:12px;font-style:normal">${ids.length} auto${ids.length>1?'s':''}</span></h2>
   <div class="cars" style="margin-top:8px">${ids.map(id=>{const m=CAR_META[id],pf=this.api.perf(id,P.d.owned[id]);return `<button class="car ${id===cur?'sel':''}" data-a="selCar" data-id="${id}"><span class="cb">${m.brand}</span><span class="cn">${m.model}</span><span class="cp">${clsBadge(pf.pi)}<span>${id===cur?'✔ EN USO':''}</span></span></button>`}).join('')}
   <button class="car soon" data-a="go" data-s="dealer"><span class="ci">＋</span><span class="cn">Comprar más</span><span class="kind">Concesionaria</span></button></div>
   <div style="margin-top:12px">${html}${this.statBlock(perf)}${this.specs(perf)}</div>
   ${this.statsBlock()}
   <div class="row" style="margin-top:10px"><button class="tile" style="flex:1" data-a="go" data-s="workshop"><span class="ti">🔧</span>Taller</button><button class="tile" style="flex:1" data-a="go" data-s="tuning"><span class="ti">🎛️</span>Ajuste</button><button class="tile" style="flex:1" data-a="go" data-s="paint"><span class="ti">🎨</span>Pintura</button></div></div><div></div></div>`,'fade');}
 s_dealer(){const P=this.P,sel=this.dealerSel||CAR_ORDER.find(i=>!P.owns(i))||CAR_ORDER[0];const m=CAR_META[sel];const {perf,html}=this.carInfo(sel,null);this.api.showCar(sel,null);
  const owned=P.owns(sel);
  this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="split"><div class="panelBox"><h2 class="ttl" style="font-size:18px">Concesionaria</h2>
   <div class="cars" style="margin-top:8px">${CAR_ORDER.map(id=>{const c=CAR_META[id];return `<button class="car ${id===sel?'sel':''}" data-a="dealerPick" data-id="${id}"><span class="cb">${c.brand}</span><span class="cn">${c.model}</span><span class="cp"><span>${P.owns(id)?'<span style="color:var(--ok)">✔ TUYO</span>':fmtCr(c.price)}</span></span></button>`}).join('')}
   ${COMING_SOON.map(c=>`<div class="car soon"><span class="ci">${c.icon}</span><span class="cb">PRÓXIMAMENTE</span><span class="cn">${c.name}</span><span class="kind">${c.kind}</span></div>`).join('')}</div>
   <div style="margin-top:12px">${html}<p class="muted" style="font-size:12px;margin:6px 0">${m.desc} · ${m.engine}</p>${this.statBlock(perf)}${this.specs(perf)}</div>
   <div class="row" style="margin-top:10px">${owned?'<span class="muted">Ya está en tu garaje</span>':`<button class="bigbtn" data-a="buyCar" data-id="${sel}" ${P.credits<m.price?'disabled':''}><span class="bi">💳</span><span class="bt">Comprar ${fmtCr(m.price)}</span></button>`}
   <button class="bigbtn dark" data-a="testDrive" data-id="${sel}"><span class="bi">🔑</span><span class="bt">Probar</span></button></div></div><div></div></div>`,'fade');}
 s_workshop(){if(!this.P.car)return this.show('starter');const P=this.P,id=P.d.current,car=P.car;const perf=this.api.perf(id,car);const cat=this.wsCat;this.api.showCar(id,car);
  let right='';
  if(cat==='tires'){right=`<h3 class="ttl" style="font-size:16px">🛞 Neumáticos</h3><p class="muted" style="font-size:12px;margin:4px 0 8px">Cada compuesto cambia el agarre según la superficie. Comprás una vez y después los cambiás gratis.</p>`+
   TIRES.map(t=>{const own=car.tiresOwned.includes(t.id),on=car.tires===t.id;const pf=this.api.perf(id,{...car,tires:t.id});const d=pf.pi-perf.pi;
    return `<div class="part ${on?'cur':''}"><span style="font-size:20px">${t.icon}</span><span class="pn">${t.n}<small>${t.info} · Asfalto ${Math.round(t.s.asphalt*100)}% · Tierra ${Math.round(t.s.dirt*100)}% · Barro ${Math.round(t.s.mud*100)}%</small></span>
     <span class="piDelta ${d>0?'up':d<0?'dn':''}">${d?(d>0?'+':'')+d:''}</span>
     ${on?'<button class="buy done" disabled>EN USO</button>':own?`<button class="buy inst" data-a="buyTire" data-id="${t.id}">PONER</button>`:`<button class="buy" data-a="buyTire" data-id="${t.id}" ${P.credits<t.cost?'disabled':''}>${fmtCr(t.cost)}</button>`}</div>`}).join('');}
  else{const u=UPGRADES.find(x=>x.id===cat),lvl=car.upg[cat]||0;
   right=`<h3 class="ttl" style="font-size:16px">${u.icon} ${u.name}</h3><p class="muted" style="font-size:12px;margin:4px 0 8px">${u.info}</p>`+u.levels.map((L,i)=>{const own=P.partOwned(id,cat,i),on=lvl===i;
    const pf=this.api.perf(id,{...car,upg:{...car.upg,[cat]:i}});const d=pf.pi-perf.pi;
    return `<div class="part ${on?'cur':''}"><span class="pips">${u.levels.slice(1).map((_,k)=>`<i class="pip ${k<i?'on':''}"></i>`).join('')}</span><span class="pn">${L.n}<small>${i===0?'De fábrica':'Nivel '+i}${L.unlock?' · habilita ajustes':''}</small></span>
     <span class="piDelta ${d>0?'up':d<0?'dn':''}">${d?(d>0?'+':'')+d+' PI':''}</span>
     ${on?'<button class="buy done" disabled>INSTALADO</button>':own?`<button class="buy inst" data-a="buyPart" data-cat="${cat}" data-l="${i}">INSTALAR</button>`:`<button class="buy" data-a="buyPart" data-cat="${cat}" data-l="${i}" ${P.credits<(L.cost||0)?'disabled':''}>${fmtCr(L.cost||0)}</button>`}</div>`}).join('');}
  const cats=[...UPGRADES.map(u=>({id:u.id,icon:u.icon,n:u.name,max:u.levels.length-1,l:car.upg[u.id]||0})),{id:'tires',icon:'🛞',n:'Neumáticos',max:0,l:0}];
  this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="split ws"><div class="panelBox wsCats">
   <div class="wsCar" style="margin-bottom:8px">${this.carInfo(id,car).html}</div>${cats.map(c=>`<button class="cat ${c.id===cat?'on':''}" data-a="wsCat" data-id="${c.id}"><span class="ci2">${c.icon}</span><span class="cn2">${c.n}</span>${c.max?`<span class="pips">${Array.from({length:c.max},(_,k)=>`<i class="pip ${k<c.l?'on':''}"></i>`).join('')}</span>`:`<span class="kind">${TIRE_BY_ID[car.tires].n}</span>`}</button>`).join('')}</div>
   <div class="panelBox">${right}<div style="margin-top:10px">${this.statBlock(perf)}</div></div><div></div></div>`,'fade');}
 s_tuning(){if(!this.P.car)return this.show('starter');const P=this.P,id=P.d.current,car=P.car,base=this.api.base(id);const un=unlocksOf(car.upg);const tu={...defaultTune(base),...(car.tune||{})};this.api.showCar(id,car);
  const V=this.api.params(id,car);const lockName={springs:'Suspensión Nv1',damp:'Suspensión Nv1',arb:'Suspensión Nv1',height:'Coilovers (Suspensión Nv3)',camber:'Coilovers (Suspensión Nv3)',toe:'Coilovers (Suspensión Nv3)',lsd:'Diferencial Nv1',final:'Transmisión Nv2',aero:'Aerodinámica Nv1',stance:'Kit stance (Estilo)'};
  const show=(it,v)=>{if(it.unit==='k'){const f=it.k==='springF'?V.freqF:V.freqR,mc=V.mass*9.81*(it.k==='springF'?V.weightFront:1-V.weightFront)/2/9.81;return Math.round(mc*Math.pow(2*Math.PI*f,2)/1000)+' N/mm';}
   if(it.k==='final')return (V.finalDrive).toFixed(2)+':1';if(it.k==='split')return v+'% / '+(100-v)+'%';return (Math.round(v*10)/10)+' '+it.u;};
  const groups=TUNE_GROUPS.map(g=>`<div class="tg"><h4>${g.g}</h4>${g.items.map(it=>{const lk=it.req&&!un.has(it.req);const v=tu[it.k];
   return `<div class="tr ${lk?'locked':''} ${this.tuneInfo[it.k]?'info':''}"><div class="th"><span>${it.n}<button class="qb" data-a="tq" data-k="${it.k}">?</button></span>${lk?`<span class="lk">🔒 ${lockName[it.req]||''}</span>`:`<span class="tv" id="tv_${it.k}">${show(it,v)}</span>`}</div>
    <input type="range" min="${it.min}" max="${it.max}" step="${it.step}" value="${v}" data-k="${it.k}" ${lk?'disabled':''}><div class="ti2">${it.info}</div></div>`}).join('')}</div>`).join('');
  const el=this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="split tn"><div class="panelBox" id="tuneBox">
   <div class="row" style="justify-content:space-between"><h2 class="ttl" style="font-size:18px">Ajuste fino</h2><button class="back" data-a="tuneReset">↺ Fábrica</button></div>
   <div class="row" style="margin:8px 0"><span class="kind">Presets:</span>${Object.keys(PRESETS).map(k=>`<button class="tab" data-a="tunePreset" data-id="${k}" data-n="${PRESET_N[k]}">${PRESET_N[k]}</button>`).join('')}</div>
   <div id="tunePI" style="margin-bottom:6px">${this.carInfo(id,car).html}</div>${groups}</div><div></div></div>`,'fade');
  const box=el.querySelector('#tuneBox');const sc=this.tuneScroll||0;box.scrollTop=sc;box.addEventListener('scroll',()=>{this.tuneScroll=box.scrollTop;});
  let tmr=null;
  el.querySelectorAll('input[type=range]').forEach(inp=>inp.addEventListener('input',()=>{const k=inp.dataset.k,it=TUNE_ITEMS[k];car.tune=car.tune||{};car.tune[k]=+inp.value;
   const V2=this.api.params(id,car);Object.assign(V,V2);const tv=document.getElementById('tv_'+k);if(tv)tv.textContent=show(it,+inp.value);
   clearTimeout(tmr);tmr=setTimeout(()=>{P.save();this.api.carChanged();const pi=document.getElementById('tunePI');if(pi)pi.innerHTML=this.carInfo(id,car).html;},180);}));}
 s_paint(){if(!this.P.car)return this.show('starter');const P=this.P,id=P.d.current,car=P.car,p=car.paint;this.api.showCar(id,car);
  const sw=slot=>`<div class="sw">${PAINTS.map(c=>`<button style="background:${c}" class="${p[slot]===c?'on':''}" data-a="paint" data-slot="${slot}" data-c="${c}"></button>`).join('')}</div>`;
  this.mount(`${this.top('<button class="back" data-a="home">←</button>')}<div class="split"><div class="panelBox"><h2 class="ttl" style="font-size:18px">Pintura</h2>
   <h4 class="ttl" style="font-size:12px;margin-top:10px;color:var(--acc2)">Color principal</h4>${sw('body')}
   <h4 class="ttl" style="font-size:12px;color:var(--acc2)">Color de detalles</h4>${sw('accent')}
   <h4 class="ttl" style="font-size:12px;color:var(--acc2)">Llantas</h4>${sw('rim')}
   <h4 class="ttl" style="font-size:12px;color:var(--acc2)">Terminación</h4><div class="seg" style="margin-top:6px">${FINISHES.map(f=>`<button class="${p.finish===f.id?'on':''}" data-a="finish" data-id="${f.id}">${f.n}</button>`).join('')}</div>
   <p class="muted" style="font-size:11px;margin-top:10px">La pintura es gratis: cambiala cuando quieras.</p></div><div></div></div>`,'fade');}
 s_options(){const s=this.P.d.settings,A=this.api;const seg=(k,opts)=>`<div class="seg">${opts.map(([v,n])=>`<button class="${s[k]==v?'on':''}" data-a="set" data-k="${k}" data-v="${v}">${n}</button>`).join('')}</div>`;
  const back=this.inRace?'<button class="back" data-a="go" data-s="pause">←</button>':'<button class="back" data-a="home">←</button>';
  this.mount(`${this.inRace?'<div class="topbar">'+back+'<div class="spacer"></div></div>':this.top(back)}<div class="head"><h2>Opciones</h2></div><div class="body"><div class="panelBox">
   <div class="tg"><h4>Estilo visual</h4>${A.postSupported()?'':'<div class="warn">Tu teléfono no soporta el postprocesado HDR: se usa el modo Normal.</div>'}
    <p class="muted" style="font-size:11px;margin:-2px 0 8px">Efectos de cámara sobre el juego (el HUD no se toca). Recomendado: <b style="color:var(--acc)">✨ Claude · Realidad</b>. Si baja el rendimiento, se aliviana solo.</p>
    <div class="grid" style="grid-template-columns:repeat(auto-fill,minmax(150px,1fr))">${PRESET_INFO.map(([id,ic,n,d])=>`<button class="ev ${s.visual===id?'final':''}" style="min-height:84px;${s.visual===id?'border-color:var(--acc)':''}" data-a="set" data-k="visual" data-v="${id}" ${A.postSupported()||id==='none'?'':'disabled'}><span class="bgic">${ic}</span><span class="en" style="font-size:13px">${ic} ${n}${s.visual===id?' ✔':''}</span><span class="em" style="font-size:10.5px">${d}</span></button>`).join('')}</div>
    <div class="opt"><span>Sombras reales<small>Sombras de los autos sobre el piso (calidad media o alta)</small></span>${seg('shadows',[[true,'Sí'],[false,'No']])}</div></div>
   <div class="tg"><h4>Controles</h4>
    <div class="opt"><span>Dirección<small>Volante circular o palanca horizontal</small></span>${seg('steerMode',[['wheel','🎡 Volante'],['slider','↔️ Palanca']])}</div>
    <div class="opt"><span>Acelerómetro<small>Girá inclinando el teléfono</small></span><div class="row"><button class="buy ${A.gyroOn()?'':'inst'}" data-a="gyro">${A.gyroOn()?'DESACTIVAR':'ACTIVAR'}</button>${A.gyroOn()?'<button class="back" data-a="gyroCal">Recalibrar</button>':''}</div></div>
    <div class="opt"><span>Sensibilidad del acelerómetro</span>${seg('gyroSens',[[25,'Suave'],[50,'Media'],[80,'Nerviosa']])}</div>
    <div class="opt"><span>Notas del copiloto<small>Te canta cada curva: 1 = muy cerrada … 6 = casi recta</small></span>${seg('notes',[[true,'Sí'],[false,'No']])}</div>
    <div class="opt"><span>Voz del copiloto<small>Si el teléfono tiene voz en español</small></span>${seg('copilot',[[true,'Sí'],[false,'No']])}</div>
    <div class="opt"><span>Vibración<small>En golpes y saltos</small></span>${seg('vibrate',[[true,'Sí'],[false,'No']])}</div></div>
   <div class="tg"><h4>Ayudas de manejo</h4>
    <div class="opt"><span>ABS<small>Evita que se bloqueen las ruedas al frenar</small></span>${seg('abs',[[true,'Sí'],[false,'No']])}</div>
    <div class="opt"><span>Control de tracción<small>Corta potencia si patinan las ruedas</small></span>${seg('tc',[[0,'No'],[30,'Bajo'],[50,'Medio'],[85,'Alto']])}</div>
    <div class="opt"><span>Control de estabilidad<small>Corrige trompos solo. 0 = física pura</small></span>${seg('stab',[[0,'No'],[30,'Bajo'],[60,'Medio'],[90,'Alto']])}</div>
    <div class="opt"><span>Velocidad del juego<small>100% = tiempo real. Menos = cámara lenta, más fácil</small></span>${seg('gameSpeed',[[60,'60%'],[80,'80%'],[100,'100%']])}</div></div>
   <div class="tg"><h4>Gráficos y sonido</h4>
    <div class="opt"><span>Calidad gráfica<small>Bajala si el teléfono se calienta o va lento</small></span>${seg('quality',[['baja','Baja'],['media','Media'],['alta','Alta']])}</div>
    <div class="opt"><span>Música en menús</span>${seg('music',[[true,'Sí'],[false,'No']])}</div>
    <div class="opt"><span>Volumen</span>${seg('volume',[[0,'🔇'],[40,'40%'],[80,'80%'],[100,'100%']])}</div>
    <div class="opt"><span>Unidades</span>${seg('units',[['kmh','km/h'],['mph','mph']])}</div></div>
   ${this.inRace?'':'<div class="tg"><h4>Progreso</h4><div class="opt"><span>Borrar partida<small>Empezar de cero</small></span><button class="buy" style="background:var(--bad)" data-a="resetAll">BORRAR</button></div></div>'}
   <p class="muted" style="font-size:10.5px;margin-top:8px">GSkorp Rally · física de simulación propia · hecho con IA</p></div></div>`,'dim');}
 s_pause(){this.mount(`<div class="pauseBox"><div class="resT" style="font-size:34px;margin-bottom:6px">Pausa</div>
   <button class="bigbtn" data-a="resume"><span class="bi">▶</span><span class="bt">Continuar</span></button>
   ${this.api.canRespawn()?'<button class="bigbtn dark" data-a="respawn"><span class="bi">🔄</span><span class="bt">Volver a la pista</span></button>':''}
   <button class="bigbtn dark" data-a="restart"><span class="bi">↺</span><span class="bt">Reiniciar</span></button>
   <button class="bigbtn dark" data-a="cam"><span class="bi">🎥</span><span class="bt">Cambiar cámara</span></button>
   <button class="bigbtn dark" data-a="go" data-s="options"><span class="bi">⚙️</span><span class="bt">Opciones</span></button>
   <button class="bigbtn dark" data-a="quit"><span class="bi">🚪</span><span class="bt">Salir al menú</span></button></div>`,'pause');}
 s_results(r){const cls=r.medal===3?'gold':r.medal===2?'silver':r.medal===1?'bronze':'';const icon=['🏳️','🥉','🥈','🥇'][r.medal||0];
  const rows=r.standings?`<table class="standings">${r.standings.map((s,i)=>`<tr class="${s.me?'me':''}"><td>${i+1}</td><td>${esc(s.name)}</td><td>${s.dnf?'—':fmtTime(s.time)}</td></tr>`).join('')}</table>`:'';
  this.mount(`<div class="resBox"><div class="muted" style="letter-spacing:3px;font-size:11px;font-weight:800">${esc(r.eventName||'')}</div><div class="resT ${cls}">${esc(r.title)}</div>
   ${r.medal!=null&&r.showMedal!==false?`<div class="bigMedal" style="background:${['rgba(255,255,255,.08)','radial-gradient(circle at 35% 30%,#ffd9b0,#b06a2c)','radial-gradient(circle at 35% 30%,#fff,#9aa6b4)','radial-gradient(circle at 35% 30%,#fff3b0,#e0a500)'][r.medal||0]}">${icon}</div>`:''}
   <div style="font-size:14px;font-weight:800">${esc(r.line||'')}</div>${r.sub?`<div class="muted" style="font-size:12px;margin-top:4px">${esc(r.sub)}</div>`:''}${rows}
   <div class="rew"><div><b id="rCr">${fmtCr(0)}</b><span>créditos</span></div><div><b id="rXp">+0</b><span>experiencia</span></div>${r.record?'<div style="border-color:var(--gold)"><b>🏆</b><span>nuevo récord</span></div>':''}</div>
   <div>${r.cupMsg?`<span class="lvup" style="background:linear-gradient(90deg,#c98a00,#ffc83d);color:#1a1200">${esc(r.cupMsg)}</span>`:''}${(r.levelUps||[]).map(l=>`<span class="lvup">⭐ NIVEL ${l.level} · +${fmtCr(l.bonus)}</span>`).join('')}</div>
   <div class="row" style="justify-content:center;margin-top:10px"><button class="bigbtn" data-a="resOk" data-next="${r.next||'career'}"><span class="bt">Continuar</span></button><button class="bigbtn dark" data-a="retry"><span class="bi">↺</span><span class="bt">Reintentar</span></button>${r.next==='career'?'<button class="bigbtn green" data-a="resOk" data-next="nextEv"><span class="bt">Siguiente misión ▶</span></button>':''}</div></div>`,'res');
  const t0=performance.now(),cr=r.cr||0,xp=r.xp||0;const tick=()=>{const k=Math.min(1,(performance.now()-t0)/1200);const e=1-Math.pow(1-k,3);const a=document.getElementById('rCr'),b=document.getElementById('rXp');if(!a)return;a.textContent=fmtCr(cr*e);b.textContent='+'+Math.round(xp*e);if(k<1)requestAnimationFrame(tick);};requestAnimationFrame(tick);}
}
/* presets de ajuste rápido */
const PRESETS={
 asfalto:{pressF:32,pressR:32,camberF:-2.2,camberR:-1.4,toeF:-0.05,toeR:0.15,height:-30,springF:125,springR:120,bump:115,rebound:120,arbF:120,arbR:115,aeroF:70,aeroR:70,gripF:100,gripR:100},
 tierra:{pressF:25,pressR:25,camberF:-1.0,camberR:-0.6,toeF:0,toeR:0.2,height:40,springF:85,springR:85,bump:90,rebound:95,arbF:80,arbR:85,aeroF:40,aeroR:50,gripF:100,gripR:100},
 drift:{pressF:30,pressR:36,camberF:-3.5,camberR:-0.5,toeF:-0.3,toeR:0,height:-20,springF:120,springR:110,arbF:130,arbR:90,split:10,lsd:220,steer:125,gripF:100,gripR:78},
 salto:{pressF:28,pressR:28,height:80,springF:95,springR:95,bump:125,rebound:110,arbF:90,arbR:90},
};
const PRESET_N={asfalto:'Asfalto',tierra:'Tierra',drift:'Drift',salto:'Saltos'};
