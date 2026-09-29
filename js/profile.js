/* ═══ Perfil del jugador: guardado local, dinero, experiencia, autos ═══ */
import {CAR_META,UPG_BY_ID,TIRE_BY_ID,xpForLevel} from './data.js';

const KEY='gskorp_rally_profile_v1';
export const DEFAULT_SETTINGS={visual:'none',shadows:true,mirrors:true,rearCam:false,notes:true,copilot:true,chatter:'normal',steerMode:'wheel',gyroSens:50,gameSpeed:100,quality:'auto',gearbox:'auto',volume:80,volEngine:100,volSurf:30,volWind:30,rawShake:25,music:true,
 units:'kmh',abs:true,tc:50,stab:30,camera:1,hud:'full',vibrate:true};

export function newCarState(id){
 const m=CAR_META[id];
 return {upg:{},tires:'street',tiresOwned:['street'],tune:{},paint:{...m.paint,finish:'metal'},km:0,bought:Date.now()};}

export function defaultProfile(){
 return {v:1,name:'Piloto',credits:15000,xp:0,level:1,owned:{},current:null,events:{},
  stats:{km:0,races:0,wins:0,podiums:0,events:0,driftBest:0,topSpeed:0,boards:{},traps:{},time:0},
  settings:{...DEFAULT_SETTINGS},daily:{day:'',streak:0},created:Date.now(),tutorial:false};}

export class Profile{
 constructor(){this.d=this.load();this.listeners=[];}
 load(){try{const raw=localStorage.getItem(KEY);if(raw){const d=JSON.parse(raw);const def=defaultProfile();
   d.settings={...def.settings,...(d.settings||{})};if(!d.settings._q2){d.settings._q2=1;if(d.settings.quality==='media')d.settings.quality='auto';}d.stats={...def.stats,...(d.stats||{})};d.daily=d.daily||def.daily;d.events=d.events||{};d.owned=d.owned||{};
   for(const id in d.owned){if(!CAR_META[id])delete d.owned[id];else d.owned[id]={...newCarState(id),...d.owned[id]};}
   if(d.current&&!d.owned[d.current])d.current=Object.keys(d.owned)[0]||null;
   return d;}}catch(e){console.warn('perfil',e)}
  return defaultProfile();}
 save(){try{localStorage.setItem(KEY,JSON.stringify(this.d));}catch(e){}this.emit();}
 on(fn){this.listeners.push(fn);}emit(){for(const f of this.listeners)try{f(this.d)}catch(e){console.warn(e)}}
 get credits(){return this.d.credits;}
 get car(){return this.d.current?this.d.owned[this.d.current]:null;}
 owns(id){return !!this.d.owned[id];}
 give(id){if(!this.d.owned[id])this.d.owned[id]=newCarState(id);if(!this.d.current)this.d.current=id;this.save();}
 select(id){if(this.d.owned[id]){this.d.current=id;this.save();}}
 spend(n){if(this.d.credits<n)return false;this.d.credits-=n;this.save();return true;}
 earn(n){this.d.credits+=Math.round(n);this.save();}
 buyCar(id){const m=CAR_META[id];if(!m||this.owns(id))return false;if(!this.spend(m.price))return false;this.give(id);this.d.current=id;this.save();return true;}
 sellValue(id){return Math.round(CAR_META[id].price*0.5);}
 /* piezas */
 upgradeLevel(id,cat){return (this.d.owned[id].upg[cat])||0;}
 buyUpgrade(id,cat,level){const u=UPG_BY_ID[cat],car=this.d.owned[id];if(!u||!car)return false;const L=u.levels[level];if(!L)return false;
  const cur=car.upg[cat]||0;if(level===cur)return false;
  if(level<cur){car.upg[cat]=level;this.save();return true;} /* bajar de nivel: gratis (las piezas quedan guardadas) */
  const owned=car.owned||(car.owned={});const key=cat+':'+level;
  if(!owned[key]){if(!this.spend(L.cost||0))return false;owned[key]=1;}
  car.upg[cat]=level;this.save();return true;}
 partOwned(id,cat,level){const car=this.d.owned[id];if(!car)return false;return level===0||!!(car.owned&&car.owned[cat+":"+level])||(car.upg[cat]||0)===level;}
 buyTires(id,tid){const car=this.d.owned[id],t=TIRE_BY_ID[tid];if(!car||!t)return false;
  if(!car.tiresOwned.includes(tid)){if(!this.spend(t.cost))return false;car.tiresOwned.push(tid);}
  car.tires=tid;this.save();return true;}
 /* experiencia */
 addXP(n){const d=this.d;d.xp+=Math.round(n);const ups=[];while(d.xp>=xpForLevel(d.level)){d.xp-=xpForLevel(d.level);d.level++;const bonus=1000+d.level*400;d.credits+=bonus;ups.push({level:d.level,bonus});}this.save();return ups;}
 /* resultados de eventos */
 eventResult(eid){return this.d.events[eid]||null;}
 recordEvent(eid,res){const cur=this.d.events[eid]||{medal:0,best:null};const better=res.lowerIsBetter?(cur.best==null||res.value<cur.best):(cur.best==null||res.value>cur.best);
  if(better)cur.best=res.value;const firstMedal=res.medal>cur.medal;cur.medal=Math.max(cur.medal,res.medal);cur.done=true;cur.plays=(cur.plays||0)+1;this.d.events[eid]=cur;this.save();return {improved:better,firstMedal};}
 /* bonus diario */
 dailyCheck(){const today=new Date().toISOString().slice(0,10);const dl=this.d.daily;if(dl.day===today)return null;
  const y=new Date(Date.now()-864e5).toISOString().slice(0,10);dl.streak=dl.day===y?Math.min(7,dl.streak+1):1;dl.day=today;const amount=1000+dl.streak*750;this.d.credits+=amount;this.save();return {amount,streak:dl.streak};}
 reset(){this.d=defaultProfile();this.save();}
}
