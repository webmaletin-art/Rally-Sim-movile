/* ═══ Arma la física final de un auto: fábrica + piezas + ajuste fino + ayudas ═══ */
import {UPGRADES,TIRE_BY_ID,TUNE_GROUPS} from './data.js';

export function defaultTune(base){
 const t={};for(const g of TUNE_GROUPS)for(const i of g.items)t[i.k]=i.def;
 t.bias=Math.round(base.brakeBiasFront*100);t.split=Math.round(base.frontDriveRatio*100);
 return t;}

export function unlocksOf(upg){
 const s=new Set();
 for(const u of UPGRADES){const lvl=(upg&&upg[u.id])||0;for(let i=1;i<=lvl;i++)(u.levels[i].unlock||[]).forEach(x=>s.add(x));}
 return s;}

function effectsOf(upg){
 const e={power:0,rpm:0,inertia:0,mass:0,com:0,yaw:0,brake:0,freq:0,arb:0,damp:0,travel:0,clutch:0,shift:0,lsd:0,aeroF:0,aeroR:0,drag:0,nitro:0,nitroBoost:0,steer:0,vgov:0};
 for(const u of UPGRADES){const lvl=(upg&&upg[u.id])||0;if(!lvl)continue;const eff=u.levels[lvl].eff||{};for(const k in eff)e[k]+=eff[k];}
 return e;}

/* base: preset de fábrica · car: estado guardado del auto · assists: ayudas globales */
export function buildParams(base,car,assists){
 const V=structuredClone(base),e=effectsOf(car.upg),un=unlocksOf(car.upg);V.turboLvl=(car.upg&&car.upg.turbo)||0;
 const tu={...defaultTune(base),...(car.tune||{})};
 const has=k=>un.has(k),pct=(k)=>tu[k]/100;
 /* motor */
 V.powerScale=1+e.power;V.vGov=base.vGov?(e.vgov>=500?0:base.vGov+e.vgov):0;
 V.maxRpm=base.maxRpm*(1+e.rpm);V.shiftUpRpm=base.shiftUpRpm*(1+e.rpm);V.engineInertia=base.engineInertia*(1+e.inertia);
 /* peso */
 const mm=1+e.mass;V.mass=base.mass*mm;V.Ixx=base.Ixx*mm;V.Iyy=base.Iyy*mm;V.Izz=base.Izz*(mm+e.yaw);V.comHeight=base.comHeight*(1+e.com);
 /* frenos */
 V.brakeTorque=base.brakeTorque*(1+e.brake)*pct('bpress');V.brakeBiasFront=tu.bias/100;
 /* suspensión */
 V.freqF=base.freqF*(1+e.freq)*(has('springs')?pct('springF'):1);V.freqR=base.freqR*(1+e.freq)*(has('springs')?pct('springR'):1);
 V.zetaBump=base.zetaBump*(1+e.damp)*(has('damp')?pct('bump'):1);V.zetaRebound=base.zetaRebound*(1+e.damp)*(has('damp')?pct('rebound'):1);
 V.arbF=base.arbF*(1+e.arb)*(has('arb')?pct('arbF'):1);V.arbR=base.arbR*(1+e.arb)*(has('arb')?pct('arbR'):1);
 V.travel=base.travel*(1+e.travel);
 if(has('height'))V.comHeight+=tu.height/1000;
 V.rideOffset=(base.rideOffset||0)+(has('height')?tu.height/1000:0);
 /* alineación */
 V.camberF=has('camber')?tu.camberF:-1.0;V.camberR=has('camber')?tu.camberR:-0.5;
 if(has('stance')){V.camberF-=tu.stanceCamber;V.camberR-=tu.stanceCamber;}
 V.toeF=has('toe')?tu.toeF:0;V.toeR=has('toe')?tu.toeR:0.1;
 V.maxSteer=base.maxSteer*(1+e.steer)*pct('steer');
 /* transmisión */
 V.clutchTime=base.clutchTime*(1+e.clutch);V.shiftTime=base.shiftTime*(1+e.shift);
 V.lsd=base.lsd*(1+e.lsd)*(has('lsd')?pct('lsd'):1);
 const sp=Math.max(0,Math.min(100,tu.split));V.frontDriveRatio=sp/100;V.rearDriveRatio=1-sp/100;V.driveType=sp<=0?'RWD':sp>=100?'FWD':'AWD';
 V.finalDrive=base.finalDrive*(has('final')?pct('final'):1);
 /* aerodinámica: ClA (m²) por eje */
 V.aeroF=e.aeroF*(has('aero')?tu.aeroF/50:0);V.aeroR=e.aeroR*(has('aero')?tu.aeroR/60:0);
 V.dragCoef=base.dragCoef*(1+e.drag*(has('aero')?0.5+tu.aeroR/120:0));
 /* nitro */
 V.nitroCap=e.nitro;V.nitroBoost=e.nitroBoost;
 /* neumáticos */
 const tire=TIRE_BY_ID[car.tires]||TIRE_BY_ID.street;V.tireId=tire.id;
 V.surfGrip={};for(const k in base.surfGrip)V.surfGrip[k]=base.surfGrip[k]*(tire.s[k]||1);
 if(tire.falloff)V.tireFalloff=base.tireFalloff*tire.falloff;
 V.pressF=tu.pressF;V.pressR=tu.pressR;
 /* diversión */
 V.gripFront=pct('gripF');V.gripRear=pct('gripR');
 /* ayudas globales */
 const A=assists||{abs:true,tc:50,stab:30};
 V.abs=!!A.abs;V.tractionControl=A.tc>0;V.tcSlip=base.tcSlip*(1.6-A.tc/100);V.stabilityAssist=A.stab/100;
 return V;}

/* ─── Índice de rendimiento (PI) y clase ─── */
function torqueAt(V,rpm){const c=V.torqueCurve;if(rpm<=c[0][0])return c[0][1];for(let i=1;i<c.length;i++)if(rpm<=c[i][0]){const u=(rpm-c[i-1][0])/(c[i][0]-c[i-1][0]);return c[i-1][1]+(c[i][1]-c[i-1][1])*u}return c[c.length-1][1];}
export function perfOf(V){
 let kw=0;for(let r=V.idleRpm;r<=V.maxRpm;r+=100)kw=Math.max(kw,V.peakTorque*V.powerScale*torqueAt(V,r)*r/9549);
 const hp=kw*1.341,pw=hp/(V.mass/1000);
 const g=V.gears[V.gears.length-1]*V.finalDrive,vGear=V.maxRpm*2*Math.PI/60*V.wheelRadius/g,vDrag=Math.cbrt(kw*1000*V.efficiency/Math.max(0.3,V.dragCoef));
 const vmax=Math.min(vGear*3.6,vDrag*3.6,V.vGov||1e9);
 const tire=(V.surfGrip.asphalt+V.surfGrip.dirt)/2,grip=V.mu*tire*((V.gripFront+V.gripRear)/2);
 const decel=Math.min(V.brakeTorque/(V.wheelRadius*V.mass),grip*9.81*1.1);
 const aero=(V.aeroF||0)+(V.aeroR||0);
 const cl=x=>Math.max(0,Math.min(1,x));
 const sAcc=cl(Math.log(pw/60)/Math.log(700/60)),sSpd=cl((vmax-90)/(300-90)),sGrip=cl((grip-0.55)/(1.25-0.55)),sBrk=cl((decel-4)/(12-4)),sAero=cl(aero/2);
 const sOff=cl(((V.travel-0.2)/0.25)*0.35+((V.surfGrip.dirt*V.mu)-0.5)/0.7*0.4+(V.wheelRadius-0.3)/0.3*0.25);
 const pi=Math.round(100+320*sAcc+190*sSpd+200*sGrip+100*sBrk+90*sAero);
 return {pi:Math.min(999,pi),hp:Math.round(hp),kg:Math.round(V.mass),vmax:Math.round(vmax),pw:Math.round(pw),
  bars:{speed:sSpd,accel:sAcc,handling:cl(sGrip*0.8+sAero*0.2),braking:sBrk,offroad:sOff}};}
export const CLASSES=[{c:'D',min:0,col:'#37b6ff'},{c:'C',min:400,col:'#f7d23e'},{c:'B',min:500,col:'#ff8a1f'},{c:'A',min:600,col:'#ff3b4f'},{c:'S',min:700,col:'#b15cff'},{c:'X',min:800,col:'#3dff9a'}];
export function classOf(pi){let r=CLASSES[0];for(const k of CLASSES)if(pi>=k.min)r=k;return r;}
