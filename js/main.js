import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
import {CAR_META,CAR_ORDER,UPG_BY_ID,PAINTS,PRESETS} from './data.js';
import {buildParams,perfOf} from './carbuild.js';
import {Profile,newCarState} from './profile.js';
import {AIDriver} from './ai.js';
import {Director} from './story.js';
import {MissionDirector,StoryVoice,MISSION_BY_ID,missionStars,starText,storyProgress,nextMission} from './mission.js';
import {tipsFor} from './tips.js';
import {CoPilot} from './copilot.js';
import {WorldDuels,rampHeight} from './duels.js';
import {DUEL_RIVALS} from './duel_data.js';
import {HudEditor,applyHud} from './hudedit.js';
import {TIERS,EVENTS,TARGETS,medalFor,rewardFor,lowerIsBetter} from './events.js';
import {UI,fmtTime} from './ui.js';
import {PostFX} from './post.js';
import {Cockpit,Crew} from './cockpit.js';
import {buildPaceNotes,noteSpeech,noteShort,noteColor} from './pacenotes.js';
import {CoDriver,noteKeys} from './codriver.js';
import {loadPilot,loadPilotLo} from './pilot.js';
const VEHICLES={
 genesis:{
  name:'Genesis X Skorpio Concept',visualType:'genesis',icon:'🦂',tagline:'Prototipo híbrido AWD · el equilibrado',firingOrder:4,
  mass:2140,weightFront:0.48,comHeight:0.88,Ixx:950,Iyy:3700,Izz:4400,
  wheelBase:2.95,trackF:1.86,trackR:1.86,wheelRadius:0.508,rimRadius:0.2286,tireWidth:0.34,wheelInertia:9.0,rideOffset:0.34,
  hardpointY:0.0,travel:0.36,freqF:1.30,freqR:1.40,zetaBump:0.30,zetaRebound:0.55,arbF:5000,arbR:2500,
  bumpStopK:320000,bumpStopC:9000,antiSquat:0.60,antiDive:0.40,rollCenter:0.20,
  mu:1.02,gripFront:1.0,gripRear:1.0,slipPeakLong:0.12,slipPeakLat:0.16,tireFalloff:1.45,rolling:0.016,
  surfGrip:{asphalt:1.0,dirt:0.62,shoulder:0.72,grass:0.45,outside:0.40,mud:0.35},
  peakTorque:1152,idleRpm:1000,launchRpm:3600,maxRpm:7200,
  torqueCurve:[[0,0.45],[1000,0.55],[2000,0.78],[3000,0.93],[4000,1.0],[6800,1.0],[7200,0.9],[7600,0.6]],
  engineInertia:0.28,engineBrake:190,
  gears:[3.10,2.15,1.62,1.28,1.03],reverseRatio:3.0,finalDrive:4.30,efficiency:0.88,
  clutchTime:1.3,shiftUpRpm:6800,shiftDownRpm:3000,shiftTime:0.16,
  driveType:'AWD',frontDriveRatio:0.40,rearDriveRatio:0.60,centerDiffBias:0.35,lsd:900,
  tractionControl:true,tcSlip:0.20,
  brakeTorque:13000,brakeBiasFront:0.62,abs:true,absSlip:0.14,
  maxSteer:0.54,steerResponse:9.5,dragCoef:0.95,
  stabilityAssist:0.30,powerScale:1.0
 },
 pickup:{
  name:'Titan Raptor X',visualType:'pickup',icon:'🛻',tagline:'Pick-up 4x4 · potencia bruta',firingOrder:8,
  mass:2700,weightFront:0.54,comHeight:0.85,Ixx:1050,Iyy:7420,Izz:7710,
  wheelBase:3.685,trackF:1.73,trackR:1.73,wheelRadius:0.44,rimRadius:0.229,tireWidth:0.325,wheelInertia:10.0,
  hardpointY:0.0,travel:0.33,freqF:1.22,freqR:1.18,zetaBump:0.32,zetaRebound:0.58,arbF:6900,arbR:3450,
  bumpStopK:442000,bumpStopC:12400,antiSquat:0.55,antiDive:0.35,rollCenter:0.25,
  mu:0.95,gripFront:1.0,gripRear:1.0,slipPeakLong:0.14,slipPeakLat:0.18,tireFalloff:1.35,rolling:0.020,
  surfGrip:{asphalt:0.90,dirt:0.80,shoulder:0.78,grass:0.55,outside:0.42,mud:0.50},
  peakTorque:691,idleRpm:750,launchRpm:2500,maxRpm:6500,vGov:170,
  torqueCurve:[[0,0.55],[1000,0.75],[2000,0.92],[3000,1.0],[4000,1.0],[5000,0.97],[6000,0.88],[6500,0.65]],
  engineInertia:0.35,engineBrake:160,
  gears:[4.70,2.99,2.15,1.77,1.52,1.28,1.00,0.85],reverseRatio:4.87,finalDrive:4.10,efficiency:0.85,
  clutchTime:0.9,shiftUpRpm:6200,shiftDownRpm:2200,shiftTime:0.25,
  driveType:'AWD',frontDriveRatio:0.40,rearDriveRatio:0.60,centerDiffBias:0.30,lsd:1400,
  tractionControl:true,tcSlip:0.22,
  brakeTorque:17000,brakeBiasFront:0.60,abs:true,absSlip:0.16,
  maxSteer:0.46,steerResponse:7.0,dragCoef:1.35,
  stabilityAssist:0.30,powerScale:1.0
 },
 truck:{
  name:'Colossus Master 6x6',visualType:'truck',icon:'🚛',tagline:'Camión Dakar · gigante imparable',firingOrder:2,
  mass:10200,weightFront:0.50,comHeight:1.30,Ixx:5300,Iyy:25000,Izz:27000,
  wheelBase:4.2,trackF:2.1,trackR:2.1,wheelRadius:0.55,rimRadius:0.254,tireWidth:0.40,wheelInertia:32.0,
  hardpointY:0.0,travel:0.38,freqF:1.20,freqR:1.18,zetaBump:0.38,zetaRebound:0.65,arbF:24300,arbR:12150,
  bumpStopK:1554000,bumpStopC:43700,antiSquat:0.40,antiDive:0.30,rollCenter:0.35,
  mu:0.90,gripFront:1.0,gripRear:1.0,slipPeakLong:0.16,slipPeakLat:0.20,tireFalloff:1.25,rolling:0.028,
  surfGrip:{asphalt:0.75,dirt:0.88,shoulder:0.80,grass:0.55,outside:0.45,mud:0.58},
  peakTorque:3500,idleRpm:600,launchRpm:1200,maxRpm:2400,
  torqueCurve:[[0,0.60],[400,0.75],[800,0.92],[1200,1.0],[1800,1.0],[2200,0.95],[2400,0.85]],
  engineInertia:0.65,engineBrake:380,
  gears:[7.50,5.20,3.80,2.70,2.00,1.50,1.15,0.90],reverseRatio:6.5,finalDrive:5.5,efficiency:0.80,
  clutchTime:2.0,shiftUpRpm:2200,shiftDownRpm:900,shiftTime:0.45,
  driveType:'AWD',frontDriveRatio:0.50,rearDriveRatio:0.50,centerDiffBias:0.50,lsd:3000,
  tractionControl:false,tcSlip:0.30,
  brakeTorque:45000,brakeBiasFront:0.55,abs:true,absSlip:0.18,
  maxSteer:0.35,steerResponse:4.5,dragCoef:2.2,
  stabilityAssist:0.35,powerScale:1.0
 },
 t1plus:{
  name:'Volt Raid Ultimate',visualType:'t1plus',icon:'⚡',tagline:'Prototipo T1+ híbrido · ágil en dunas',firingOrder:6,
  mass:2200,weightFront:0.48,comHeight:0.70,Ixx:831,Iyy:4008,Izz:4508,
  wheelBase:2.9,trackF:2.02,trackR:2.02,wheelRadius:0.40,rimRadius:0.23,tireWidth:0.33,wheelInertia:6.5,
  hardpointY:0.0,travel:0.28,freqF:1.40,freqR:1.45,zetaBump:0.38,zetaRebound:0.65,arbF:3200,arbR:1800,
  bumpStopK:330000,bumpStopC:9200,antiSquat:0.65,antiDive:0.45,rollCenter:0.18,
  mu:1.05,gripFront:1.0,gripRear:1.0,slipPeakLong:0.13,slipPeakLat:0.17,tireFalloff:1.45,rolling:0.022,
  surfGrip:{asphalt:0.85,dirt:0.78,shoulder:0.75,grass:0.60,outside:0.50,mud:0.45},
  peakTorque:950,idleRpm:500,launchRpm:800,maxRpm:7600,vGov:170,
  torqueCurve:[[0,0.95],[500,1.0],[3000,1.0],[6000,0.85],[7600,0.6],[8200,0.35]],
  engineInertia:0.10,engineBrake:140,
  gears:[5.64,3.90,3.03,2.51,2.18,1.90],reverseRatio:5.6,finalDrive:3.23,efficiency:0.93,
  clutchTime:0.3,shiftUpRpm:7000,shiftDownRpm:3400,shiftTime:0.10,
  driveType:'AWD',frontDriveRatio:0.50,rearDriveRatio:0.50,centerDiffBias:0.50,lsd:1100,
  tractionControl:true,tcSlip:0.16,
  brakeTorque:15000,brakeBiasFront:0.52,abs:true,absSlip:0.13,
  maxSteer:0.50,steerResponse:10.5,dragCoef:0.80,
  stabilityAssist:0.25,powerScale:1.0
 }
};
const VEHICLE_ORDER=['genesis','pickup','truck','t1plus'];
let currentVehicleId='genesis';
let VEH=structuredClone(VEHICLES.genesis);
let BASE=structuredClone(VEHICLES.genesis);
const clampP=(v,a,b)=>Math.max(a,Math.min(b,v));
function tireCurve(s,C){const B=Math.tan(Math.PI/(2*C));return Math.sin(C*Math.atan(B*s));}
class Physics{
 constructor(track,Vp){this.V=Vp||VEH;this.track=track;this.trackHint=null;this.setup();this.reset();}
 setup(){const V=this.V,g=9.81,wb=V.wheelBase;this.a=wb*(1-V.weightFront);this.b=wb*V.weightFront;
  const def=[[V.trackF/2,this.a,true,true],[-V.trackF/2,this.a,true,false],[V.trackR/2,-this.b,false,true],[-V.trackR/2,-this.b,false,false]];
  const old=this.wheels;
  this.wheels=def.map(([x,z,front,left],i)=>{
   const load=V.mass*g*(front?V.weightFront:1-V.weightFront)/2,mc=load/g;
   const f=front?V.freqF:V.freqR,k=mc*Math.pow(2*Math.PI*f,2),cc=2*Math.sqrt(k*mc);
   const xs=load/k,ss=V.comHeight-V.wheelRadius+V.hardpointY,sMax=ss+xs,sMin=Math.max(0.03,sMax-V.travel);
   const w={Fz0:load,x,z,front,left,k,cB:V.zetaBump*cc,cR:V.zetaRebound*cc,sMax,sMin,sStatic:ss,comp:xs,s:ss,contact:true,Fz:load,Ftire:load,jack:0,omega:0,drive:0,brake:0,kappa:0,alpha:0,gy:0,surf:'asphalt',wx:0,wz:0,fl:0,slip:0,impact:0,vl:0};
   const cam=(front?V.camberF:V.camberR)||0,gc=-cam;w.camber=cam;
   w.latMul=cam>0?1-0.04*cam:(gc<=5?1+0.07*(1-Math.pow((gc-2.5)/2.5,2)):Math.max(0.6,1-0.035*(gc-5)));w.longMul=1-0.012*Math.abs(cam);
   w.toeRad=((front?V.toeF:V.toeR)||0)*Math.PI/180*(left?-1:1);w.press=(front?V.pressF:V.pressR)||30;w.pkLat=clampP(1-0.006*(w.press-30),0.85,1.15);
   if(old&&old[i]){w.omega=old[i].omega;w.comp=old[i].comp;w.s=old[i].s;}
   return w;});
  this.nitro=V.nitroCap||0;}
 reset(pose){const t=this.track,p=t.samples[0],tg=t.tangents[0],lat=t.laterals[0];pose=pose||this.pose;if(pose){this.px=pose.x;this.pz=pose.z;this.yaw=pose.yaw;}else{this.px=p.x+lat.x*0.35;this.pz=p.z+lat.z*0.35;this.yaw=Math.atan2(tg.x,tg.z);}t._hint=null;this.trackHint=null;/* altura de largada: la rueda más alta apenas apoyada (sin clavarse en pendientes ni baches) */{const fx=Math.sin(this.yaw),fz=Math.cos(this.yaw),lx=Math.cos(this.yaw),lz=-Math.sin(this.yaw);let gy=t.groundInfo(this.px,this.pz).y;for(const w of this.wheels)gy=Math.max(gy,t.groundInfo(this.px+fx*w.z+lx*w.x,this.pz+fz*w.z+lz*w.x).y);t._hint=null;this.py=gy+this.V.comHeight+0.01;}this.pitch=0;this.roll=0;this.vx=0;this.vy=0;this.vz=0;this.yawRate=0;this.pitchRate=0;this.rollRate=0;this.vLong=0;this.vLat=0;this.aLong=0;this.aLat=0;this.steerAngle=0;this.rpm=this.V.idleRpm;this.gear=1;this.shiftT=0;this.clutchLocked=false;this.tc=1;this.load=0;this.limiter=false;this.events=[];this.revT=0;this.airTime=0;this.slip=0;this.contacts=4;this.nitro=this.V.nitroCap||0;this.nitroActive=false;for(const w of this.wheels){w.comp=w.sMax-w.sStatic;w.s=w.sStatic;w.omega=0;w.contact=true;w.jack=0;}this.position={x:this.px,y:this.py,z:this.pz};}
 torqueAt(rpm){const c=this.V.torqueCurve;if(rpm<=c[0][0])return c[0][1];for(let i=1;i<c.length;i++){if(rpm<=c[i][0]){const u=(rpm-c[i-1][0])/(c[i][0]-c[i-1][0]);return c[i-1][1]+(c[i][1]-c[i-1][1])*u}}return c[c.length-1][1];}
 step(dt,input){if(input&&input.shift)this.reqShift=input.shift;const n=2,h=dt/n;for(let i=0;i<n;i++)this.sub(h,input);
  if(!isFinite(this.px+this.py+this.pz+this.vx+this.vy+this.vz+this.yaw+this.pitch+this.roll+this.yawRate)){console.warn('physics NaN → recover');this.reset(this._good||this.pose);}else if(!this._gt||(this._gt=(this._gt+1)%60)===0){this._good={x:this.px,z:this.pz,yaw:this.yaw};this._gt=this._gt||1;}this.position.x=this.px;this.position.y=this.py;this.position.z=this.pz;}
 /* dirección sensible a la velocidad: a fondo el volante da lo justo para el límite de agarre
    (radio mínimo + ángulo de deriva pico) y un extra si el auto va cruzado para poder contravolantear */
 steerScale(spd){const V=this.V,b=Math.abs(Math.atan2(this.vLat||0,Math.max(1,Math.abs(this.vLong||0))));
  const lim=V.wheelBase*V.mu*9.81/(spd*spd+4)*1.1+V.slipPeakLat*0.35+Math.min(0.35,b*1.0);return clampP(lim/V.maxSteer,0.12,1);}
 sub(h,inp){this.track._hint=this.trackHint;this._sub(h,inp);this.trackHint=this.track._hint;}
 _sub(h,inp){const V=this.V,g=9.81,W=this.wheels,R=V.wheelRadius,m=V.mass,tr=this.track;
  let thr=inp.throttle||0,brk=inp.brake||0;const spd=Math.hypot(this.vx,this.vz);
  /* caja automática: frenando parado pasa a reversa y el pedal de freno la maneja; en manual la reversa y el neutro los elige el piloto */
  if(!this.manual){if(this.gear===0)this.gear=1;if(this.gear>0&&brk>0.5&&thr<0.05&&spd<0.6&&this.vLong<0.4){this.revT+=h;if(this.revT>0.35){this.gear=-1;this.revT=0}}else if(this.gear>0)this.revT=0;
  if(this.gear===-1){if(thr>0.1&&this.vLong>-0.6){this.gear=1}else{const t=thr;thr=brk;brk=t}}}
  const sf=this.steerScale(spd);const tgt=-(inp.steer||0)*V.maxSteer*sf;this.steerAngle+=(tgt-this.steerAngle)*(1-Math.exp(-h*V.steerResponse));
  const sy=Math.sin(this.yaw),cy=Math.cos(this.yaw),fx=sy,fz=cy,lx=cy,lz=-sy;const vLong=this.vx*fx+this.vz*fz,vLat=this.vx*lx+this.vz*lz;const sp=Math.sin(this.pitch),sr=Math.sin(this.roll);
  let contacts=0;
  for(const w of W){w.wx=this.px+fx*w.z+lx*w.x;w.wz=this.pz+fz*w.z+lz*w.x;const gi=tr.groundInfo(w.wx,w.wz);w.gy=gi.y;w.surf=gi.surf;const ay=this.py+V.hardpointY+w.x*sr-w.z*sp;const d=ay-(gi.y+R);const prevContact=w.contact,prevComp=w.comp;
   if(d>=w.sMax){w.contact=false;w.comp=0;w.s=w.sMax;w.Fz=0;w.cv=0;}else{w.contact=true;contacts++;const comp=w.sMax-d;const cv=prevContact?(comp-prevComp)/h:Math.min(6,-this.vy+0);w.comp=comp;w.cv=cv;w.s=Math.max(d,w.sMin);let F=w.k*comp+(cv>0?w.cB:w.cR)*cv;if(d<w.sMin){F+=V.bumpStopK*(w.sMin-d)+(cv>0?V.bumpStopC*cv:0);}w.Fz=Math.max(0,F);if(!prevContact||cv>1.0)w.impact=Math.max(w.impact,Math.abs(cv)*(d<w.sMin?1.6:1));}}
  for(const [L,Rw,k] of [[W[0],W[1],V.arbF],[W[2],W[3],V.arbR]]){if(L.contact&&Rw.contact){const df=k*(L.comp-Rw.comp);L.Fz=Math.max(0,L.Fz+df);Rw.Fz=Math.max(0,Rw.Fz-df);}}
  this.contacts=contacts;this.brake=brk;this.hbIn=!!inp.handbrake;this.nitroOn=!!inp.nitro;this.engine(h,thr,brk,vLong,!!inp.handbrake);
  let FL=0,FT=0,Mz=0,tauP=0,tauR=0,FzSum=0,maxSlip=0;const hgt=Math.max(0.3,this.py-(W[0].gy+W[1].gy+W[2].gy+W[3].gy)/4);
  for(const w of W){const I=V.wheelInertia+(w.inertiaExtra||0);let fl=0,k=0;
   if(w.contact){const Ft0=Math.max(0,w.Fz+w.jack);const vpl=vLat+this.yawRate*w.z,vpg=vLong-this.yawRate*w.x;const dl=(w.front?this.steerAngle:0)+w.toeRad,cs=Math.cos(dl),sn=Math.sin(dl);const vl=vpl*sn+vpg*cs,vt=vpl*cs-vpg*sn;w.vl=vl;const den=Math.max(Math.abs(vl),2.5);const kap=(w.omega*R-vl)/den,alp=Math.atan2(vt,den);w.kappa=kap;w.alpha=alp;const po=w.surf==='asphalt'?32:26,mu=(tr.gripMul||1)*V.mu*(V.surfGrip[w.surf]||0.4)*(w.front?V.gripFront:V.gripRear)*(1-0.0009*(w.press-po)*(w.press-po));const sx=kap/V.slipPeakLong,sy2=alp/(V.slipPeakLat*w.pkLat),s=Math.hypot(sx,sy2);let F=0,Ft=0;
    const lsens=clampP(1-0.12*(Ft0/(w.Fz0||Ft0||1)-1),0.74,1.12);if(s>1e-6){F=mu*lsens*Ft0*tireCurve(s,V.tireFalloff);fl=F*sx/s*w.longMul;Ft=-F*sy2/s*w.latMul;const d1=(tireCurve(s+0.02,V.tireFalloff)-tireCurve(s,V.tireFalloff))/0.02;k=mu*Ft0*Math.max(0.08,d1*Math.abs(sx)/s+(s<1?0.3:0))/V.slipPeakLong*R/den;}else{k=mu*Ft0*2.0/V.slipPeakLong*R/den;}
    const rr=V.rolling*Ft0*clampP(vl/0.5,-1,1);const flT=fl-rr;const fbLat=flT*sn+Ft*cs,fbLong=flT*cs-Ft*sn;FL+=fbLong;FT+=fbLat;Mz+=w.z*fbLat-w.x*fbLong;
    const anti=w.front?(fbLong<0?V.antiDive:0.15):(fbLong>0?V.antiSquat:0.2);tauP+=-fbLong*hgt*(1-anti);tauR+=fbLat*(hgt-V.rollCenter);w.jackTau=-fbLong*hgt*anti;w.jackLat=fbLat*V.rollCenter;w.slip=s;maxSlip=Math.max(maxSlip,s);w.fl=fl;
   }else{w.slip=0;w.kappa=0;w.alpha=0;w.jackTau=0;w.jackLat=0;w.fl=0;}
   FzSum+=w.Fz;tauP+=-w.Fz*w.z;tauR+=w.Fz*w.x;
   const T=w.drive;let om=(w.omega+h/I*(T-R*fl+R*k*w.omega))/(1+h/I*R*k);const bd=w.brake*h/I;if(Math.abs(om)<=bd)om=0;else om-=Math.sign(om)*bd;if(!w.contact)om*=Math.exp(-h*0.3);w.omega=om;}
  let jF=0,jR=0,jLF=0,jLR=0;for(const w of W){if(w.front){jF+=w.jackTau;jLF+=w.jackLat}else{jR+=w.jackTau;jLR+=w.jackLat}}
  const jt=(jF+jR)/V.wheelBase/2;for(const w of W){const lat=(w.front?jLF/V.trackF:jLR/V.trackR)/2;w.jack=(w.front?jt:-jt)+(w.left?-lat:lat);}
  this.slip=Math.max(0,maxSlip-1);
  const slL=((W[0].gy+W[1].gy)-(W[2].gy+W[3].gy))/2/V.wheelBase;const slT=((W[0].gy+W[2].gy)-(W[1].gy+W[3].gy))/2/((V.trackF+V.trackR)/2);
  const drag=V.dragCoef*spd;let Fx=fx*FL+lx*FT-drag*this.vx-FzSum*(fx*slL+lx*slT);let Fzw=fz*FL+lz*FT-drag*this.vz-FzSum*(fz*slL+lz*slT);
  let DF=0,DR=0;if(V.aeroF||V.aeroR){const q=0.6*spd*spd;DF=q*(V.aeroF||0);DR=q*(V.aeroR||0);tauP+=DF*this.a-DR*this.b;}
  this.vx+=Fx/m*h;this.vz+=Fzw/m*h;this.vy+=((FzSum-DF-DR)/m-g)*h;
  const kinYaw=vLong*Math.tan(this.steerAngle)/V.wheelBase;const yMax=V.mu*9.81*0.95/Math.max(spd,3),yT=clampP(kinYaw,-yMax,yMax);
  if(contacts>0&&(Math.abs(this.yawRate)>Math.abs(yT)||this.yawRate*yT<0))Mz+=-V.stabilityAssist*V.Izz*3.0*(this.yawRate-yT)*clampP(spd/8,0,1);
  if(contacts>0&&spd<3)Mz+=-V.Izz*2*(this.yawRate-kinYaw)*(1-spd/3);
  this.yawRate+=Mz/V.Izz*h;this.pitchRate+=tauP/V.Iyy*h;this.rollRate+=tauR/V.Ixx*h;
  if(contacts===0){this.pitchRate*=Math.exp(-h*0.4);this.rollRate*=Math.exp(-h*0.4);this.yawRate*=Math.exp(-h*0.2);this.airTime+=h}else{if(this.airTime>0.25)this.events.push({type:'land',v:Math.max(...W.map(w=>w.impact))});this.airTime=0}
  this.px+=this.vx*h;this.py+=this.vy*h;this.pz+=this.vz*h;this.yaw+=this.yawRate*h;this.pitch+=this.pitchRate*h;this.roll+=this.rollRate*h;
  if(Math.abs(this.pitch)>0.6){this.pitch=Math.sign(this.pitch)*0.6;this.pitchRate=0}if(Math.abs(this.roll)>0.6){this.roll=Math.sign(this.roll)*0.6;this.rollRate=0}
  const gc=tr.groundInfo(this.px,this.pz).y;if(this.py<gc+0.3){this.py=gc+0.3;if(this.vy<0)this.vy=0}
  if(spd<0.25&&thr<0.05&&contacts===4){this.vx*=0.8;this.vz*=0.8;this.yawRate*=0.8;for(const w of W)w.omega*=0.8}
  const nL=this.vx*fx+this.vz*fz,nT=this.vx*lx+this.vz*lz;this.aLong+=(((nL-vLong)/h)-this.aLong)*(1-Math.exp(-h*12));this.aLat+=((FT/m)-this.aLat)*(1-Math.exp(-h*12));this.vLong=nL;this.vLat=nT;}
 engine(h,thr,brk,vLong,handbrake){const V=this.V,W=this.wheels;let fr=V.frontDriveRatio,rr=V.rearDriveRatio;if(V.driveType==='RWD'){fr=0;rr=1}else if(V.driveType==='FWD'){fr=1;rr=0}const tot=fr+rr||1;fr/=tot;rr/=tot;
  const wF=(W[0].omega+W[1].omega)/2,wR=(W[2].omega+W[3].omega)/2,wAvg=wF*fr+wR*rr;const ratio=this.gear>0?V.gears[this.gear-1]*V.finalDrive:(this.gear<0?-V.reverseRatio*V.finalDrive:0);const rpmW=Math.abs(wAvg*ratio)*60/(2*Math.PI);
  if(this.shiftT>0)this.shiftT-=h;
  /* neutro: el motor gira libre (se puede acelerar parado hasta el corte) */
  if(this.gear===0){this.clutchLocked=false;this.engage=0;this.cutT=Math.max(0,(this.cutT||0)-h);const tgt=this.cutT>0?V.idleRpm:V.idleRpm+thr*(V.maxRpm*1.02-V.idleRpm);this.rpm+=(tgt-this.rpm)*(1-Math.exp(-h*(tgt>this.rpm?7:2.5)));if(this.rpm>=V.maxRpm){this.rpm=V.maxRpm;this.cutT=0.07;}}
  else if(!this.clutchLocked){if(thr>0.05)this.engage=Math.min(1,(this.engage||0)+h/V.clutchTime);else this.engage=0;const free=V.idleRpm+thr*(V.launchRpm-V.idleRpm);const target=Math.max(rpmW,free+(Math.max(rpmW,V.idleRpm)-free)*this.engage);this.rpm+=(target-this.rpm)*(1-Math.exp(-h*(thr>0.05?10:4)));if(thr>0.05&&(rpmW>=this.rpm*0.97||this.engage>=1))this.clutchLocked=true;if(thr<0.05&&rpmW>V.idleRpm*1.2)this.clutchLocked=true;}else{this.rpm+=(Math.max(V.idleRpm*0.85,rpmW)-this.rpm)*(1-Math.exp(-h*30));if(rpmW<V.idleRpm*0.8&&(thr<0.05||brk>0.3)){this.clutchLocked=false;this.engage=0;}}
  this.limiter=this.rpm>=V.maxRpm;let Te;const Tmax=V.peakTorque*V.powerScale*this.torqueAt(this.rpm);
  if(this.shiftT>0)Te=0;else if(this.clutchLocked){Te=thr*Tmax-(1-thr)*V.engineBrake*(this.rpm/V.maxRpm);if(this.limiter)Te=Math.min(Te,-V.engineBrake*0.5);}else Te=thr*Tmax;
  /* limitador de velocidad de fábrica (se libera con la ECU / motor de competición del taller) */
  if(V.vGov&&this.gear>0&&Te>0){const kmh=Math.abs(vLong)*3.6;if(kmh>V.vGov-4)Te*=Math.max(0,Math.min(1,(V.vGov-kmh)/4));}
  if(this.limiter&&!this.wasLimiter)this.events.push({type:'limiter'});this.wasLimiter=this.limiter;
  let mk=0;for(const w of W)if(w.contact&&((w.front&&fr>0)||(!w.front&&rr>0)))mk=Math.max(mk,w.kappa*Math.sign(ratio||1));
  if(V.tractionControl&&thr>0.05){if(mk>V.tcSlip)this.tc=Math.max(0.2,this.tc-h*6);else this.tc=Math.min(1,this.tc+h*2.5)}else this.tc=Math.min(1,this.tc+h*4);
  this.nitroActive=false;if(V.nitroCap>0){if(this.nitroOn&&this.nitro>0.02&&thr>0.3&&this.gear>0){this.nitro=Math.max(0,this.nitro-h);this.nitroActive=true;}else if(!this.nitroOn)this.nitro=Math.min(V.nitroCap,this.nitro+h*V.nitroCap/35);}
  if(Te>0)Te*=this.tc*(this.nitroActive?1+V.nitroBoost:1)*(1-0.35*(this.damage||0))*(this.powerMul||1);const Tw=Te*ratio*V.efficiency;const couple=V.centerDiffBias*600*(wF-wR);const Tf=Tw*fr-(fr>0&&rr>0?couple:0),Tr=Tw*rr+(fr>0&&rr>0?couple:0);
  const ie=this.clutchLocked?V.engineInertia*ratio*ratio:0;const cap=0.45*V.wheelInertia/h,lsdT=d=>Math.sign(d)*Math.min(V.lsd*Math.abs(d),cap*Math.abs(d));const lF=lsdT(W[0].omega-W[1].omega),lR=lsdT(W[2].omega-W[3].omega);
  for(const w of W){w.drive=(w.front?Tf:Tr)/2-(w.front?lF:lR)*(w.left?1:-1)*(this.clutchLocked||thr>0.05?1:0.3);w.inertiaExtra=ie*(w.front?fr:rr)/2;
   if(V.abs&&brk>0.05){if(w.kappa*Math.sign(w.vl||1)<-V.absSlip)w.absF=Math.max(0.25,(w.absF||1)-h*9);else w.absF=Math.min(1,(w.absF||1)+h*4)}else w.absF=1;
   w.brake=brk*w.absF*V.brakeTorque*(w.front?V.brakeBiasFront:1-V.brakeBiasFront)/2;
   if(handbrake&&!w.front)w.brake=Math.max(w.brake,V.brakeTorque*0.55);}
  /* caja secuencial: sube por velocidad real (no por patinar), un cambio por vez con tiempo mínimo en cada marcha,
     y al frenar reduce de a una sin pasar de vueltas (se ve al piloto meter cada cambio) */
  /* caja manual: el piloto pide el cambio; se niega a reducir si pasaría de vueltas */
  if(this.manual&&this.reqShift){const d=this.reqShift;this.reqShift=0;const wr=Math.abs(this.vLong)/V.wheelRadius*V.finalDrive*9.549;
   if(d>0){if(this.gear===-1)this.gear=0;else if(this.gear===0)this.gear=1;else if(this.gear<V.gears.length&&this.shiftT<=0){this.gear++;this.shiftT=V.shiftTime;this.inGearT=0;this.events.push({type:'shift',up:true});}}
   else{if(this.gear>1&&this.shiftT<=0){if(wr*V.gears[this.gear-2]<V.maxRpm*1.03){this.gear--;this.shiftT=V.shiftTime*0.6;this.inGearT=0;this.events.push({type:'shift',up:false});}else this.events.push({type:'shiftDenied'});}else if(this.gear===1)this.gear=0;else if(this.gear===0&&Math.abs(this.vLong)<1.2)this.gear=-1;}}
  if(!this.manual&&this.gear>0&&this.clutchLocked&&this.shiftT<=0){this.inGearT=(this.inGearT||0)+h;const wr=Math.abs(this.vLong)/V.wheelRadius*V.finalDrive*9.549,rIn=g=>wr*V.gears[g-1];
   const up=this.gear<V.gears.length&&thr>0.1&&this.contacts>=2&&this.inGearT>0.45&&((this.rpm>V.shiftUpRpm&&rIn(this.gear)>V.shiftUpRpm*0.8)||rIn(this.gear)>V.maxRpm*0.99);
   const brkDown=brk>0.25&&this.gear>1&&this.inGearT>0.28&&rIn(this.gear)<V.shiftDownRpm*1.7&&rIn(this.gear-1)<V.shiftUpRpm*0.92;
   const lugDown=this.gear>1&&this.rpm<V.shiftDownRpm*(thr>0.6?1:0.6)&&this.inGearT>0.2&&rIn(this.gear-1)<V.shiftUpRpm*0.95;
   if(up){this.gear++;this.shiftT=V.shiftTime;this.inGearT=0;this.events.push({type:'shift',up:true});}
   else if(brkDown||lugDown){this.gear--;this.shiftT=V.shiftTime*0.6;this.inGearT=0;this.events.push({type:'shift',up:false});}}
  const l=this.clutchLocked?(Te>0?Te/Math.max(1,Tmax):0):thr*0.7;this.load+=(l-this.load)*(1-Math.exp(-h*10));this.throttle=thr;}
}
const CFG=VEH;
const STATE={throttle:0,brake:0,steer:0,started:false,debug:false,lap:1,totalLaps:3,lapTime:0,best:0,lapArmed:false,prevCross:0};
const $=id=>document.getElementById(id),clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t;
const fmt=s=>{const m=Math.floor(s/60),ss=Math.floor(s%60),cc=Math.floor((s*100)%100);return `${String(m).padStart(2,'0')}:${String(ss).padStart(2,'0')}.${String(cc).padStart(2,'0')}`};
let GYRO_TILT_FOR_FULL=35;
const CAM_CUSTOM_INDEX=5;
const CAMERAS=[
  {name:'Onboard (casco)',mode:'onboard',fov:70},
  {name:'Media',mode:'chase',dist:7.5,height:2.2,look:3.6,lookH:0.75,fov:58},
  {name:'Cerca/Alta',mode:'chase',dist:4.8,height:2.9,look:3.0,lookH:0.6,fov:64},
  {name:'Lejos/Baja',mode:'chase',dist:11.0,height:1.2,look:4.5,lookH:1.0,fov:54},
  {name:'Aérea',mode:'chase',dist:15.0,height:6.0,look:2.0,lookH:0.2,fov:50},
  {name:'Cámara libre',mode:'custom',fov:60},
  {name:'Interior (atrás del piloto)',mode:'rearcabin',fov:68},
  {name:'Capó',mode:'hood',fov:66},
  {name:'Paragolpes',mode:'bumper',fov:70},
];
let CAM_INDEX=1;

class Input{
 constructor(){this.keys={};
  this.wheelTarget=0;this.wheelRotation=0;this.wheelVisual=0;this.wheelTouchAngle=null;this.wheelTouchId=null;
  this.sliderTarget=0;this.sliderTouchId=null;
  this.gasTarget=0;this.brakeTarget=0;this.gas=0;this.brake=0;this.steer=0;this.throttle=0;
  this.pedalTouchId=null;this.activePointers=new Map();
  this.gyroEnabled=false;this.gyroSteer=0;this.gyroRaw=0;this.gyroCalib=null;this.gyroHandler=null;
  this.handbrakeTouch=false;this.handbrake=false;
  addEventListener('keydown',e=>{this.keys[e.code]=true;if(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Space'].includes(e.code))e.preventDefault();});
  addEventListener('keyup',e=>{this.keys[e.code]=false;});
  this.shiftQueue=0;this.shift=0;
  this.bindWheel();this.bindSlider();this.bindPedalSingle();this.bindHandbrake();this.bindGearPad();
 }
 /* tira de cambios: deslizar arriba/abajo (cada 30 px = un cambio, se pueden encadenar) o tocar ▲ / ▼; multitáctil */
 bindGearPad(){const el=$('gearPad');if(!el)return;const act=new Map();const up=$('gearUp'),dn=$('gearDn');
  const flash=b=>{b.classList.add('active');setTimeout(()=>b.classList.remove('active'),140);};
  const shift=d=>{this.shiftQueue=Math.max(-3,Math.min(3,this.shiftQueue+d));flash(d>0?up:dn);if(navigator.vibrate&&PROFILE.d.settings.vibrate)try{navigator.vibrate(12)}catch(e){}};
  el.addEventListener('pointerdown',e=>{e.preventDefault();try{el.setPointerCapture(e.pointerId)}catch(_){}act.set(e.pointerId,{y0:e.clientY,moved:false,t:e.target});},{passive:false});
  el.addEventListener('pointermove',e=>{const a=act.get(e.pointerId);if(!a)return;e.preventDefault();const dy=e.clientY-a.y0;if(Math.abs(dy)>30){shift(dy<0?1:-1);a.y0=e.clientY;a.moved=true;}},{passive:false});
  const end=e=>{const a=act.get(e.pointerId);if(!a)return;act.delete(e.pointerId);if(!a.moved){const r=el.getBoundingClientRect();shift(e.clientY<r.top+r.height/2?1:-1);}};
  el.addEventListener('pointerup',end);el.addEventListener('pointercancel',e=>act.delete(e.pointerId));
  addEventListener('keydown',e=>{if(e.code==='KeyE')shift(1);if(e.code==='KeyQ')shift(-1);});}
 bindHandbrake(){const el=$('handbrakeBtn');if(!el)return;
  const on=e=>{e.preventDefault();this.handbrakeTouch=true;el.classList.add('active');};
  const off=e=>{this.handbrakeTouch=false;el.classList.remove('active');};
  el.addEventListener('pointerdown',on,{passive:false});el.addEventListener('pointerup',off);el.addEventListener('pointercancel',off);el.addEventListener('pointerleave',off);
 }
 bindWheel(){const el=$('steering');
  const getAngle=e=>{const r=el.getBoundingClientRect();const cx=r.left+r.width/2,cy=r.top+r.height/2;return Math.atan2(e.clientY-cy,e.clientX-cx);};
  const angleDelta=(a,b)=>{let d=a-b;while(d>Math.PI)d-=Math.PI*2;while(d<-Math.PI)d+=Math.PI*2;return d;};
  const begin=e=>{if(this.gyroEnabled)return;e.preventDefault();if(this.activePointers.has(e.pointerId))return;this.activePointers.set(e.pointerId,'wheel');this.wheelTouchAngle=getAngle(e);try{el.setPointerCapture(e.pointerId)}catch(_){}};
  const move=e=>{if(this.gyroEnabled)return;if(this.activePointers.get(e.pointerId)!=='wheel')return;e.preventDefault();const a=getAngle(e);const d=angleDelta(a,this.wheelTouchAngle);this.wheelTouchAngle=a;this.wheelRotation=clamp(this.wheelRotation+d*1.35,-Math.PI*3,Math.PI*3);this.wheelTarget=clamp(this.wheelRotation/Math.PI,-1,1);};
  const end=e=>{if(this.activePointers.get(e.pointerId)!=='wheel')return;this.activePointers.delete(e.pointerId);this.wheelTouchAngle=null;this.wheelTarget=0;};
  el.addEventListener('pointerdown',begin,{passive:false});el.addEventListener('pointermove',move,{passive:false});el.addEventListener('pointerup',end);el.addEventListener('pointercancel',end);el.addEventListener('lostpointercapture',end);
  el.addEventListener('touchstart',e=>{if(this.gyroEnabled)return;e.preventDefault();const t=e.changedTouches[0];if(!t)return;this.wheelTouchId=t.identifier;this.wheelTouchAngle=getAngle(t);},{passive:false});
  el.addEventListener('touchmove',e=>{if(this.gyroEnabled)return;e.preventDefault();const id=this.wheelTouchId;for(const t of e.changedTouches){if(t.identifier!==id)continue;const a=getAngle(t);const d=angleDelta(a,this.wheelTouchAngle);this.wheelTouchAngle=a;this.wheelRotation=clamp(this.wheelRotation+d*1.35,-Math.PI*3,Math.PI*3);this.wheelTarget=clamp(this.wheelRotation/Math.PI,-1,1);}},{passive:false});
  const touchEnd=e=>{for(const t of e.changedTouches){if(t.identifier===this.wheelTouchId){this.wheelTouchId=null;this.wheelTouchAngle=null;this.wheelTarget=0;}}};
  el.addEventListener('touchend',touchEnd,{passive:false});el.addEventListener('touchcancel',touchEnd,{passive:false});}
 bindSlider(){const el=$('steerTrack');
  const indicator=el.querySelector('.steer-indicator');
  const leftFill=el.querySelector('.steer-left-fill');
  const rightFill=el.querySelector('.steer-right-fill');
  const setFromX=clientX=>{
   const r=el.getBoundingClientRect();
   const rel=clamp((clientX-r.left)/r.width,0,1);
   const v=clamp((rel-0.5)*2,-1,1);
   this.sliderTarget=v;
   if(v<=0){leftFill.style.width=(-v*50)+'%';rightFill.style.width='0%';}
   else{leftFill.style.width='0%';rightFill.style.width=(v*50)+'%';}
   indicator.style.left=`calc(${50+v*38}% - 23px)`;
  };
  const reset=()=>{this.sliderTarget=0;leftFill.style.width='0%';rightFill.style.width='0%';indicator.style.left='calc(50% - 23px)';};
  reset();
  el.addEventListener('pointerdown',e=>{if(this.gyroEnabled)return;e.preventDefault();if(this.activePointers.has(e.pointerId))return;this.activePointers.set(e.pointerId,'slider');setFromX(e.clientX);try{el.setPointerCapture(e.pointerId)}catch(_){}},{passive:false});
  el.addEventListener('pointermove',e=>{if(this.activePointers.get(e.pointerId)!=='slider')return;e.preventDefault();setFromX(e.clientX);},{passive:false});
  const endPointer=e=>{if(this.activePointers.get(e.pointerId)!=='slider')return;this.activePointers.delete(e.pointerId);reset();};
  el.addEventListener('pointerup',endPointer);el.addEventListener('pointercancel',endPointer);el.addEventListener('lostpointercapture',endPointer);
  el.addEventListener('touchstart',e=>{if(this.gyroEnabled)return;e.preventDefault();const t=e.changedTouches[0];if(!t)return;this.sliderTouchId=t.identifier;setFromX(t.clientX);},{passive:false});
  el.addEventListener('touchmove',e=>{if(this.gyroEnabled)return;e.preventDefault();const id=this.sliderTouchId;for(const t of e.changedTouches)if(t.identifier===id)setFromX(t.clientX);},{passive:false});
  const touchEnd=e=>{for(const t of e.changedTouches){if(t.identifier===this.sliderTouchId){this.sliderTouchId=null;reset();}}};
  el.addEventListener('touchend',touchEnd,{passive:false});el.addEventListener('touchcancel',touchEnd,{passive:false});}
 bindPedalSingle(){const el=$('pedalSingle');
  const indicator=el.querySelector('.pedal-indicator');
  const gasFill=el.querySelector('.pedal-gas-fill');
  const brakeFill=el.querySelector('.pedal-brake-fill');
  const setFromY=clientY=>{
   const r=el.getBoundingClientRect();
   const rel=clamp((r.bottom-clientY)/r.height,0,1);
   const v=clamp((rel-0.5)*2,-1,1);
   if(v>=0){this.gasTarget=v;this.brakeTarget=0;gasFill.style.height=(v*50)+'%';brakeFill.style.height='0%';}
   else{this.gasTarget=0;this.brakeTarget=-v;gasFill.style.height='0%';brakeFill.style.height=((-v)*50)+'%';}
   indicator.style.bottom=`calc(${50+v*38}% - 20px)`;
  };
  const reset=()=>{this.gasTarget=0;this.brakeTarget=0;gasFill.style.height='0%';brakeFill.style.height='0%';indicator.style.bottom='calc(50% - 20px)';};
  reset();
  el.addEventListener('pointerdown',e=>{e.preventDefault();if(this.activePointers.has(e.pointerId))return;this.activePointers.set(e.pointerId,'pedal');setFromY(e.clientY);try{el.setPointerCapture(e.pointerId)}catch(_){}},{passive:false});
  el.addEventListener('pointermove',e=>{if(this.activePointers.get(e.pointerId)!=='pedal')return;e.preventDefault();setFromY(e.clientY);},{passive:false});
  const endPointer=e=>{if(this.activePointers.get(e.pointerId)!=='pedal')return;this.activePointers.delete(e.pointerId);reset();};
  el.addEventListener('pointerup',endPointer);el.addEventListener('pointercancel',endPointer);el.addEventListener('lostpointercapture',endPointer);
  el.addEventListener('touchstart',e=>{e.preventDefault();const t=e.changedTouches[0];if(!t)return;this.pedalTouchId=t.identifier;setFromY(t.clientY);},{passive:false});
  el.addEventListener('touchmove',e=>{e.preventDefault();const id=this.pedalTouchId;for(const t of e.changedTouches)if(t.identifier===id)setFromY(t.clientY);},{passive:false});
  const touchEnd=e=>{for(const t of e.changedTouches){if(t.identifier===this.pedalTouchId){this.pedalTouchId=null;reset();}}};
  el.addEventListener('touchend',touchEnd,{passive:false});el.addEventListener('touchcancel',touchEnd,{passive:false});}
 gyroOrientation(){let a=0;if(screen.orientation&&typeof screen.orientation.angle==='number')a=screen.orientation.angle;else if(typeof window.orientation==='number')a=window.orientation;a=((a%360)+360)%360;if(a===90)return 'landscape-primary';if(a===270)return 'landscape-secondary';if(a===180)return 'portrait-secondary';return 'portrait-primary';}
 gyroAxisValue(e){const o=this.gyroOrientation();const beta=(typeof e.beta==='number'&&isFinite(e.beta))?e.beta:0;const gamma=(typeof e.gamma==='number'&&isFinite(e.gamma))?e.gamma:0;if(o==='landscape-primary')return -beta;if(o==='landscape-secondary')return beta;if(o==='portrait-secondary')return -gamma;return gamma;}
 /* inclinar el teléfono: usa el ACELERÓMETRO (gravedad), que tienen todos los teléfonos; si no manda datos, prueba la orientación */
 async enableGyro(){if(location.protocol==='file:')return {ok:false,err:'Abrilo por HTTPS o servidor local para usar el acelerómetro.'};
  for(const E of [window.DeviceMotionEvent,window.DeviceOrientationEvent]){if(E&&typeof E.requestPermission==='function'){try{const r=await E.requestPermission();if(r!=='granted')return {ok:false,err:'Permiso denegado para el sensor de movimiento.'};}catch(e){return {ok:false,err:'Error pidiendo permiso: '+e.message};}}}
  let events=0;this.gyroCalib=null;this.gyroRaw=0;this.gyroSteer=0;
  const feed=cur=>{events++;if(this.gyroCalib===null){this.gyroCalib=cur;return;}let delta=cur-this.gyroCalib;if(delta>180)delta-=360;if(delta<-180)delta+=360;this.gyroRaw+=(delta-this.gyroRaw)*0.22;this.gyroSteer=clamp((this.gyroInvert?-1:1)*this.gyroRaw/GYRO_TILT_FOR_FULL,-1,1);};
  /* gravedad en el plano de la pantalla: girar el teléfono como un volante (cualquier apaisado) */
  this.motionHandler=e=>{const g=e.accelerationIncludingGravity;if(!g||g.x==null||g.y==null)return;if(Math.hypot(g.x,g.y)<3)return;feed(Math.atan2(g.y,g.x)*180/Math.PI);};
  if('DeviceMotionEvent' in window)window.addEventListener('devicemotion',this.motionHandler,{passive:true});
  await new Promise(r=>setTimeout(r,600));
  if(events<2){window.removeEventListener('devicemotion',this.motionHandler);this.motionHandler=null;
   if(!('DeviceOrientationEvent' in window))return {ok:false,err:'Tu teléfono no manda datos del acelerómetro.'};
   this.gyroHandler=e=>{if(e.beta==null&&e.gamma==null&&e.alpha==null)return;feed(this.gyroAxisValue(e));};window.addEventListener('deviceorientation',this.gyroHandler,{passive:true});
   await new Promise(r=>setTimeout(r,600));
   if(events<2){window.removeEventListener('deviceorientation',this.gyroHandler);this.gyroHandler=null;return {ok:false,err:'El sensor no está enviando datos. Probá mover el teléfono.'};}}
  this.gyroEnabled=true;document.body.classList.add('gyro-on');this.wheelTarget=0;this.sliderTarget=0;return {ok:true};}
 disableGyro(){if(this.gyroHandler){window.removeEventListener('deviceorientation',this.gyroHandler);this.gyroHandler=null;}if(this.motionHandler){window.removeEventListener('devicemotion',this.motionHandler);this.motionHandler=null;}this.gyroEnabled=false;this.gyroSteer=0;this.gyroRaw=0;this.gyroCalib=null;this.wheelTarget=0;this.sliderTarget=0;document.body.classList.remove('gyro-on');}
 recalibrateGyro(){this.gyroCalib=null;this.gyroRaw=0;this.gyroSteer=0;}
 update(dt){let kbSteer=0;if(this.keys.KeyA||this.keys.ArrowLeft)kbSteer-=1;if(this.keys.KeyD||this.keys.ArrowRight)kbSteer+=1;
  let desiredSteer;
  if(this.gyroEnabled){desiredSteer=this.gyroSteer;}
  else if(tune.steerMode==='slider'){const hasSlider=(this.sliderTouchId!=null)||[...this.activePointers.values()].includes('slider');desiredSteer=hasSlider?this.sliderTarget:kbSteer;}
  else{const hasWheelContact=(this.wheelTouchId!=null)||[...this.activePointers.values()].includes('wheel');desiredSteer=hasWheelContact?this.wheelTarget:kbSteer;}
  const steerRate=desiredSteer===0?13.0:9.5;
  this.steer+=(desiredSteer-this.steer)*(1-Math.exp(-dt*steerRate));
  if(tune.steerMode==='wheel'){
   if(this.gyroEnabled){this.wheelRotation+=(this.gyroSteer*Math.PI*0.75-this.wheelRotation)*(1-Math.exp(-dt*15));}
   else{const hasWheelContact=(this.wheelTouchId!=null)||[...this.activePointers.values()].includes('wheel');if(!hasWheelContact){const targetRot=kbSteer!==0?kbSteer*Math.PI*0.75:0;this.wheelRotation+=(targetRot-this.wheelRotation)*(1-Math.exp(-dt*5.5));}}
   this.wheelVisual+=(this.wheelRotation-this.wheelVisual)*(1-Math.exp(-dt*10));
   $('wheelSvg').style.transform=`rotate(${this.wheelVisual*180/Math.PI}deg)`;
  }
  const kbGas=(this.keys.KeyW||this.keys.ArrowUp)?1:0;
  const kbBrake=(this.keys.KeyS||this.keys.ArrowDown)?1:0;
  const pedalActive=(this.pedalTouchId!=null)||[...this.activePointers.values()].includes('pedal');
  if(!pedalActive){if(kbGas>0){this.gasTarget=kbGas;this.brakeTarget=0;}else if(kbBrake>0){this.gasTarget=0;this.brakeTarget=kbBrake;}else{this.gasTarget=0;this.brakeTarget=0;}}
  this.gas=this.gasTarget;this.brake=this.brakeTarget;this.throttle=this.gas;
  this.handbrake=this.handbrakeTouch||!!this.keys.Space;
  this.shift=this.shiftQueue>0?1:this.shiftQueue<0?-1:0;this.shiftQueue-=this.shift;
 }
}

/* ═══ HILL CLIMB TRACK ═══ */
/* ═══ RUTAS: bosque de tierra (grande, muy sinuosa) y asfalto de montaña (larga, curvas abiertas) ═══ */
const TRACK_ROUTES={
 forest:{halfWidth:3.4,shoulder:2.2,points:[
  [727,67,0],[558,64,81],[498,58,149],[531,49,254],[530,40,374],[414,32,424],[234,26,363],[95,22,257],
  [26,19,221],[-36,17,297],[-155,14,421],[-319,12,496],[-473,11,484],[-586,11,413],[-663,13,318],[-704,17,211],
  [-688,21,100],[-624,24,0],[-561,26,-81],[-542,28,-163],[-545,30,-261],[-508,31,-358],[-401,32,-411],[-260,33,-405],
  [-138,33,-375],[-43,32,-363],[44,30,-367],[132,28,-358],[215,28,-334],[317,32,-325],[481,39,-340],[699,48,-335],
  [869,57,-260],[876,64,-127]
 ]},
 lake:{halfWidth:5.2,shoulder:1.8,points:[[518,18,0],[508,19,93],[421,19,162],[330,18,211],[252,17,253],[170,17,283],[88,17,309],[0,18,336],[-93,19,325],[-158,19,263],[-205,19,206],[-282,17,180],[-366,15,141],[-392,12,72],[-386,10,0],[-415,9,-76],[-449,9,-173],[-417,10,-266],[-322,11,-323],[-205,11,-341],[-91,11,-318],[0,10,-260],[64,9,-224],[139,9,-231],[228,9,-228],[289,11,-184],[340,13,-131],[433,16,-79]]},
 quarry:{halfWidth:3.9,shoulder:2.0,points:[[355,32,0],[328,30,74],[267,29,128],[217,28,175],[156,28,205],[77,25,185],[20,20,150],[-22,16,162],[-84,13,202],[-166,13,219],[-250,13,202],[-313,13,149],[-325,12,73],[-302,14,0],[-287,18,-64],[-255,21,-122],[-185,22,-149],[-122,21,-160],[-84,22,-201],[-33,24,-247],[33,25,-246],[88,26,-211],[138,25,-182],[190,25,-153],[246,28,-117],[313,31,-70]]},
 /* bajada de asfalto para probar física: 150 m de desnivel, curvas rápidas y badenes largos; vuelve por la ladera de enfrente */
 descent:{halfWidth:5.4,shoulder:2.0,dips:[{from:0.04,to:0.17,amp:0.8,wave:85},{from:0.21,to:0.33,amp:1.2,wave:120},{from:0.36,to:0.44,amp:0.7,wave:95}],points:[
  [0,172,-1100],[28,162,-900],[-12,148,-700],[18,131,-500],[55,113,-300],[30,96,-100],[-20,79,100],[5,63,300],[48,48,500],[30,36,700],[-8,27,880],[35,20,1050],
  [150,17,1170],[285,21,1120],[335,30,950],[360,48,700],[305,68,450],[385,90,200],[335,113,-50],[395,133,-300],[335,150,-600],[365,164,-850],[285,172,-1060],[140,175,-1170]
 ]},
 asphaltLong:{halfWidth:4.8,shoulder:1.6,points:[
  [510,29,0],[516,24,152],[493,19,317],[374,14,432],[210,11,459],[68,12,471],[-69,18,480],[-193,29,423],
  [-291,43,336],[-424,57,273],[-581,68,171],[-637,75,0],[-554,77,-163],[-421,73,-270],[-302,64,-348],[-195,55,-427],
  [-72,45,-501],[75,38,-520],[213,34,-467],[333,32,-384],[442,32,-284],[504,31,-148]
 ]}
};
class Track{
 constructor(scene,mode,routeId,opts){opts=opts||{};this.scene=scene;this.mode=mode;this.routeId=routeId;const route=TRACK_ROUTES[routeId];this.routeDef=route;this.halfWidth=route.halfWidth;this.shoulder=route.shoulder;this._control=opts.reverse?[route.points[0],...route.points.slice(1).reverse()]:route.points;this.opts=opts;this.samples=[];this.tangents=[];this.laterals=[];this.length=0;this.tapeNodes=[];this.lapEnabled=true;this.kind=routeId;
  this.group=new THREE.Group();scene.add(this.group);this.build();}
 control(){return this._control;}
 /* badenes: ondas largas de altura sobre tramos del recorrido (fracciones de la vuelta) */
 applyDips(){const S=this.samples,N=S.length;const cum=[0];for(let i=1;i<N;i++)cum[i]=cum[i-1]+Math.hypot(S[i].x-S[i-1].x,S[i].z-S[i-1].z);
  for(const d of this.routeDef.dips){const i0=Math.floor(d.from*N),i1=Math.floor(d.to*N),s0=cum[i0],s1=cum[i1];
   for(let i=i0;i<=i1;i++){const u=(cum[i]-s0)/Math.max(1,s1-s0),win=Math.min(1,u*6,(1-u)*6);S[i].y+=-d.amp*win*0.5*(1-Math.cos(2*Math.PI*(cum[i]-s0)/d.wave));}}}
 getYAt(t){const v=this.control();let i=Math.floor(t*v.length)%v.length,u=(t*v.length)%1,a=v[i],b=v[(i+1)%v.length];return a[1]+(b[1]-a[1])*u+0.20*Math.sin(t*Math.PI*6)+0.10*Math.sin(t*Math.PI*15);}
 build(){const raw=this.control().map(p=>new THREE.Vector3(p[0],p[1],p[2]));
  const curve=new THREE.CatmullRomCurve3(raw,true,'catmullrom',0.5);
  const N=1100;this.samples=curve.getSpacedPoints(N).slice(0,N);/* curva cerrada: sin el punto repetido del final (escalón en la unión) */
  for(let i=0;i<N;i++){const t=i/N;this.samples[i].y=this.getYAt(t);}
  /* perfil de altura suavizado (media móvil circular): sin quiebres de pendiente que lancen el auto en las crestas */
  {let y=this.samples.map(p=>p.y);for(const W of [6,6,4]){const o=new Array(N);for(let i=0;i<N;i++){let s=0;for(let j=-W;j<=W;j++)s+=y[(i+j+N)%N];o[i]=s/(2*W+1);}y=o;}this.samples.forEach((p,i)=>p.y=y[i]);}
  if(this.routeDef.dips&&!window.__NODIPS)this.applyDips();
  this.tangents=this.samples.map((p,i)=>this.samples[(i+1)%N].clone().sub(this.samples[(i+N-1)%N]).normalize());
  this.laterals=this.tangents.map(t=>new THREE.Vector3().crossVectors(t,new THREE.Vector3(0,1,0)).normalize());
  this.cum=[0];for(let i=1;i<=N;i++)this.cum[i]=this.cum[i-1]+this.samples[i-1].distanceTo(this.samples[i%N]);
  this.length=this.cum[N];
  this.buildRoad();this.buildTerrain();this.buildTape();this.buildStart();this.buildScenery();}
 roadOffset(i){const t=i/this.samples.length;return 0.06+0.10*Math.sin(t*Math.PI*5)+0.04*Math.sin(t*Math.PI*13)-0.25*Math.exp(-Math.pow((t-0.43)/0.045,2))+0.18*Math.exp(-Math.pow((t-0.73)/0.06,2));}
 terrainBase(x,z,roadY){const rY=(typeof roadY==='number'&&isFinite(roadY))?roadY:0;return rY - 0.25 + 0.7*Math.sin(x*.020+z*.018) + 0.35*Math.sin(x*.045-z*.038+1.3) + 0.18*Math.sin(x*.11+z*.09+2.7);}
 _scan(x,z,i0,cnt){const N=this.samples.length;for(let k=0;k<cnt;k++){const i=((i0+k)%N+N)%N,a=this.samples[i],b=this.samples[(i+1)%N],abx=b.x-a.x,abz=b.z-a.z,apx=x-a.x,apz=z-a.z,den=abx*abx+abz*abz;const t=den?clamp((apx*abx+apz*abz)/den,0,1):0;const dx=x-(a.x+abx*t),dz=z-(a.z+abz*t),d=dx*dx+dz*dz;if(d<this._bd){this._bd=d;this._bi=i;this._bt=t}}}
 /* tramo más cercano: desde la pista "hint" se camina cuesta abajo (en vez de revisar 71 tramos por rueda y por paso) y se afina ±4 */
 _segD(x,z,i){const S=this.samples,N=S.length,a=S[i],b=S[(i+1)%N],abx=b.x-a.x,abz=b.z-a.z,den=abx*abx+abz*abz;const t=den?clamp(((x-a.x)*abx+(z-a.z)*abz)/den,0,1):0;const dx=x-(a.x+abx*t),dz=z-(a.z+abz*t);return dx*dx+dz*dz;}
 nearest(x,z){const N=this.samples.length,Wd=35,h=this._hint;this._bd=Infinity;this._bi=0;this._bt=0;
  if(h!=null){let i=h,d=this._segD(x,z,i),k=0;for(const st of [1,-1]){k=0;while(k++<Wd){const j=(i+st+N)%N,dj=this._segD(x,z,j);if(dj<d){i=j;d=dj;}else break;}if(i!==h)break;}
   this._scan(x,z,i-4,9);/* lejos del camino puede haber varios mínimos: ahí se revisa la ventana completa como antes (misma altura que el terreno dibujado) */if(this._bd>225||this._trust){this._bd=Infinity;this._scan(x,z,h-Wd,2*Wd+1);}let off=this._bi-h;if(off>N/2)off-=N;if(off<-N/2)off+=N;if(Math.abs(off)>=Wd-1||(this._bd>900&&!this._trust)){this._bd=Infinity;this._scan(x,z,0,N)}}else this._scan(x,z,0,N);
  const bi=this._bi,bt=this._bt;this._hint=bi;const a=this.samples[bi],b=this.samples[(bi+1)%N],centerY=lerp(a.y+this.roadOffset(bi),b.y+this.roadOffset((bi+1)%N),bt);const lat=this.laterals[bi],dx=x-(a.x+(b.x-a.x)*bt),dz=z-(a.z+(b.z-a.z)*bt);const o=this._n||(this._n={});o.dist=Math.sqrt(this._bd);o.idx=bi;o.t=bt;o.y=centerY;o.lateral=dx*lat.x+dz*lat.z;o.tan=this.tangents[bi];o.lat=lat;return o}
 /* dip continuo desde la banquina hacia afuera: vale 0 justo en el borde (se), así no hay escalón/pared invisible al volver a la pista */
 ditchDip(d,se){const dd=Math.max(0,d-se);const s=dd*dd/(dd*dd+9);return 0.28*s*Math.exp(-dd/15);}
 groundInfo(x,z){const n=this.nearest(x,z),d=Math.abs(n.lateral),edge=this.halfWidth,se=edge+this.shoulder,o=this._gi||(this._gi={y:0,surf:'asphalt'});let y;
  if(d<=edge){y=n.y+(1-Math.min(d/edge,1)**2)*0.03}else{const base=this.terrainBase(x,z,n.y);if(d<=se){const t=(d-edge)/this.shoulder;y=n.y*(1-t)+base*t+0.10*Math.sin(t*Math.PI)}else y=base-this.ditchDip(d,se)}
  o.surf=d<=edge?(this.mode==='asphalt'?'asphalt':'dirt'):d<=se?'shoulder':d<12?'grass':'outside';o.y=y+microBump(x,z,o.surf);return o}
 ground(x,z){const n=this.nearest(x,z),d=Math.abs(n.lateral),edge=this.halfWidth,se=edge+this.shoulder;
  const base=this.terrainBase(x,z,n.y);
  if(d<=edge){const crown=(1-Math.min(d/edge,1)**2)*0.03;return n.y+crown}
  if(d<=se){const t=(d-edge)/this.shoulder;return n.y*(1-t)+base*t+0.10*Math.sin(t*Math.PI)}
  return base-this.ditchDip(d,se);}
 surface(x,z){const n=this.nearest(x,z),d=Math.abs(n.lateral);if(d<=this.halfWidth)return this.mode==='asphalt'?'asphalt':'dirt';if(d<=this.halfWidth+this.shoulder)return 'shoulder';return d<12?'grass':'outside'}
 buildRoad(){const N=this.samples.length,pos=[],nor=[],uv=[],idx=[];
  for(let i=0;i<N;i++){const p=this.samples[i],lat=this.laterals[i],y=p.y+this.roadOffset(i),l=p.clone().addScaledVector(lat,-this.halfWidth);const r=p.clone().addScaledVector(lat,this.halfWidth);l.y=y;r.y=y;pos.push(l.x,l.y+.015,l.z,r.x,r.y+.015,r.z);nor.push(0,1,0,0,1,0);uv.push(0,i*.22,1,i*.22)}
  for(let i=0;i<N;i++){const j=(i+1)%N,a=i*2,b=i*2+1,c=j*2,d=j*2+1;idx.push(a,b,c,b,d,c)}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.setAttribute('normal',new THREE.Float32BufferAttribute(nor,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));g.setIndex(idx);
  const tex=document.createElement('canvas');tex.width=512;tex.height=512;const c=tex.getContext('2d');c.fillStyle=this.mode==='asphalt'?'#33363a':'#5b4a38';c.fillRect(0,0,512,512);
  for(let i=0;i<14000;i++){const q=35+Math.random()*45;c.fillStyle=`rgb(${q},${q},${q+3})`;c.fillRect(Math.random()*512,Math.random()*512,1,1)}
  for(let i=0;i<40;i++){const x=Math.random()*512,y=Math.random()*512,r=20+Math.random()*60;c.fillStyle='rgba(20,22,26,.18)';c.beginPath();c.arc(x,y,r,0,7);c.fill();}
  if(this.mode==='asphalt'){c.fillStyle='rgba(236,236,228,.88)';c.fillRect(16,0,12,512);c.fillRect(484,0,12,512);c.fillStyle='rgba(245,205,70,.92)';c.fillRect(250,0,12,256);}
  else{c.fillStyle='rgba(40,30,20,.25)';for(const x of [150,362])for(let y=0;y<512;y+=4)c.fillRect(x+Math.sin(y*.05)*6-18,y,36,3);}
  const t=new THREE.CanvasTexture(tex);t.wrapS=t.wrapT=THREE.RepeatWrapping;t.repeat.set(1,4);t.anisotropy=4;
  const m=new THREE.MeshLambertMaterial({map:t,color:0xffffff,polygonOffset:true,polygonOffsetFactor:-4,polygonOffsetUnits:-4});
  this.group.add(new THREE.Mesh(g,m));
  /* banquina + franja exterior que copia exactamente ground() (lo que pisa la física) y tapa el terreno hundido */
  const TD=this.terrainDims(),EXT=TD.cell*2.95+1;const F=[0,1,1.6,3.2,6,10,16,23,EXT].filter((v,k,a)=>v<=EXT&&(k===0||v>a[k-1]));const RW=F.length;
  const sp=[],sc=[],si=[];const cSh=new THREE.Color(0x7a6b57),cGr=new THREE.Color(0x48663d);
  for(let i=0;i<N;i++){const p=this.samples[i],lat=this.laterals[i],y=p.y+this.roadOffset(i);for(const s of [-1,1])for(let k=0;k<RW;k++){const f=F[k];let x,z,yy;
    if(f===0){x=p.x+lat.x*s*this.halfWidth;z=p.z+lat.z*s*this.halfWidth;yy=y+0.01;}else if(f===1){x=p.x+lat.x*s*(this.halfWidth+this.shoulder);z=p.z+lat.z*s*(this.halfWidth+this.shoulder);yy=this.ground(x,z)+0.03;}
    else{const o=this.halfWidth+this.shoulder+(f-1);x=p.x+lat.x*s*o;z=p.z+lat.z*s*o;const e=(f-1)/(EXT-1);yy=this.ground(x,z)+0.02-0.24*e*e;}
    sp.push(x,yy,z);const c=f<=1?cSh:cSh.clone().lerp(cGr,Math.min(1,(f-1)/3.5));sc.push(c.r,c.g,c.b);}}
  for(let i=0;i<N;i++){const ni=(i+1)%N;for(let side=0;side<2;side++)for(let k=0;k<RW-1;k++){const a=i*RW*2+side*RW+k,b=a+1,c=ni*RW*2+side*RW+k,d=c+1;si.push(a,b,c,b,d,c);}}
  upFacing(sp,si);const shoulderG=new THREE.BufferGeometry();shoulderG.setAttribute('position',new THREE.Float32BufferAttribute(sp,3));shoulderG.setAttribute('color',new THREE.Float32BufferAttribute(sc,3));shoulderG.setIndex(si);shoulderG.computeVertexNormals();
  const sm=new THREE.Mesh(shoulderG,new THREE.MeshLambertMaterial({vertexColors:true,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1}));sm.receiveShadow=true;this.group.add(sm);}
 /* grilla del terreno: celdas de ≤ 10 m */
 terrainDims(){if(this._td)return this._td;const xs=this._control.map(p=>p[0]),zs=this._control.map(p=>p[2]);const minX=Math.min(...xs)-180,maxX=Math.max(...xs)+180,minZ=Math.min(...zs)-180,maxZ=Math.max(...zs)+180;
  const R=Math.max(150,Math.min(280,Math.ceil(Math.max(maxX-minX,maxZ-minZ)/10)));return this._td={minX,maxX,minZ,maxZ,R,cell:Math.max(maxX-minX,maxZ-minZ)/R};}
 buildTerrain(){const {minX,maxX,minZ,maxZ,R,cell}=this.terrainDims();const SR=this.halfWidth+cell*1.45;const pos=[],col=[],idx=[];
  /* búsqueda del camino acelerada: primero una muestra de cada 6 (aproximado) y después la exacta alrededor (carga mucho más rápida) */
  const S=this.samples,NS=S.length,coarse=[];for(let i=0;i<NS;i+=6)coarse.push(i);const near0=(x,z)=>{let bi=0,bd=1e18;for(const i of coarse){const dx=S[i].x-x,dz=S[i].z-z,dd=dx*dx+dz*dz;if(dd<bd){bd=dd;bi=i;}}return bi;};this._trust=true;
  for(let iz=0;iz<=R;iz++){const z=lerp(minZ,maxZ,iz/R);for(let ix=0;ix<=R;ix++){const x=lerp(minX,maxX,ix/R);this._hint=near0(x,z);const y0=this.ground(x,z)-0.25;const n=this.nearest(x,z),d=Math.abs(n.lateral);/* cerca del camino el terreno se hunde bajo la franja: ningún triángulo asoma */pos.push(x,y0-(d<SR?0.6:0),z);const cc=new THREE.Color(d<this.halfWidth+this.shoulder?0x74634c:0x48663d);cc.offsetHSL(0,(Math.random()-.5)*.08,(Math.random()-.5)*.08);col.push(cc.r,cc.g,cc.b)}}
  this._trust=false;this._hint=null;
  for(let iz=0;iz<R;iz++)for(let ix=0;ix<R;ix++){const a=iz*(R+1)+ix,b=a+1,c=a+R+1,d=c+1;idx.push(a,c,b,b,c,d)}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.setAttribute('color',new THREE.Float32BufferAttribute(col,3));g.setIndex(idx);g.computeVertexNormals();
  this.group.add(terrainMesh(g));}
 addGate(idx,label,color){const N=this.samples.length;idx=((idx%N)+N)%N;const p=this.samples[idx],lat=this.laterals[idx],tg=this.tangents[idx],w=this.halfWidth+this.shoulder*0.6,gy=this.ground(p.x,p.z);
  const g=new THREE.Group();const pm=new THREE.MeshStandardMaterial({color:0x22262c,metalness:0.6,roughness:0.4});
  for(const sd of [-1,1]){const pole=new THREE.Mesh(new THREE.BoxGeometry(0.35,5.2,0.35),pm);pole.position.set(p.x+lat.x*w*sd,gy+2.6,p.z+lat.z*w*sd);g.add(pole);}
  const tx=canvasTex(512,64,(c,W,H)=>{c.fillStyle=color||'#0d1117';c.fillRect(0,0,W,H);for(let i=0;i<W;i+=32){c.fillStyle=(i/32)%2?'#fff':'#111';c.fillRect(i,0,32,8);c.fillRect(i+16,H-8,32,8);}c.fillStyle='#fff';c.font='900 34px system-ui,sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText(label,W/2,H/2+1);});
  const ban=new THREE.Mesh(new THREE.PlaneGeometry(w*2,1.1),new THREE.MeshBasicMaterial({map:tx,side:THREE.DoubleSide}));ban.position.set(p.x,gy+4.7,p.z);ban.rotation.y=Math.atan2(tg.x,tg.z)+Math.PI;g.add(ban);
  const ck=canvasTex(128,16,(c,W,H)=>{for(let x=0;x<W;x+=8)for(let y=0;y<H;y+=8){c.fillStyle=((x+y)/8)%2?'#f4f4f4':'#141414';c.fillRect(x,y,8,8);}});
  const line=new THREE.Mesh(new THREE.PlaneGeometry(this.halfWidth*2,1.2),new THREE.MeshBasicMaterial({map:ck,polygonOffset:true,polygonOffsetFactor:-6}));line.position.set(p.x,this.ground(p.x,p.z)+0.05,p.z);line.rotation.x=-Math.PI/2;line.rotation.z=-Math.atan2(tg.x,tg.z);g.add(line);
  this.group.add(g);return g;}
 buildStart(){const p=this.samples[0],mat=new THREE.MeshBasicMaterial({color:0xffffff,side:THREE.DoubleSide});const line=new THREE.Mesh(new THREE.PlaneGeometry(this.halfWidth*2,.9),mat);line.position.copy(p);line.position.y=this.ground(p.x,p.z)+.045;line.rotation.x=-Math.PI/2;line.rotation.z=-Math.atan2(this.tangents[0].x,this.tangents[0].z);this.group.add(line)}
 /* cinta de rally: un nodo cada ~5 m siguiendo la curva, estaca cada ~15 m, cerrada en toda la vuelta.
    Solo se simulan los tramos que el auto toca (el resto queda quieto). */
 buildTape(){const N=this.samples.length,step=Math.max(1,Math.round(5/(this.length/N)));const pm=carCut(new THREE.MeshStandardMaterial({color:0xd8d8d2,roughness:0.6}));
  const tex=document.createElement('canvas');tex.width=128;tex.height=32;const tc=tex.getContext('2d');tc.fillStyle='#f2f2ea';tc.fillRect(0,0,128,32);tc.fillStyle='#e21e1e';for(let x=-32;x<160;x+=32){tc.beginPath();tc.moveTo(x,32);tc.lineTo(x+18,0);tc.lineTo(x+30,0);tc.lineTo(x+12,32);tc.fill();}
  const postGeo=new THREE.CylinderGeometry(.035,.045,1.2,6);
  for(const side of [-1,1]){const nodes=[];for(let i=0;i<N;i+=step){const p=this.samples[i],lat=this.laterals[i],off=this.halfWidth+this.shoulder+.9;const base=p.clone().addScaledVector(lat,side*off);base.y=this.ground(base.x,base.z)+1.0;nodes.push({base:base.clone(),pos:base.clone(),vel:new THREE.Vector3(),active:false});}
   const M=nodes.length,posts=nodes.filter((n,k)=>k%3===0);const pi=new THREE.InstancedMesh(postGeo,pm,posts.length);const d=new THREE.Object3D();posts.forEach((n,k)=>{d.position.set(n.base.x,n.base.y-0.42,n.base.z);d.updateMatrix();pi.setMatrixAt(k,d.matrix);});this.group.add(pi);
   const arr=new Float32Array(M*2*3),uv=new Float32Array(M*2*2),ind=[];let u=0;for(let k=0;k<M;k++){if(k)u+=nodes[k].base.distanceTo(nodes[k-1].base);uv[k*4]=u/1.2;uv[k*4+1]=1;uv[k*4+2]=u/1.2;uv[k*4+3]=0;const a=k*2,b=a+1,c=((k+1)%M)*2,dd=c+1;ind.push(a,b,c,b,dd,c);}
   const geo=new THREE.BufferGeometry();geo.setAttribute('position',new THREE.BufferAttribute(arr,3));geo.setAttribute('uv',new THREE.BufferAttribute(uv,2));geo.setIndex(ind);
   const t=new THREE.CanvasTexture(tex);t.wrapS=t.wrapT=THREE.RepeatWrapping;t.colorSpace=THREE.SRGBColorSpace;const mesh=new THREE.Mesh(geo,carCut(new THREE.MeshBasicMaterial({map:t,side:THREE.DoubleSide})));mesh.frustumCulled=false;this.group.add(mesh);
   const tape={nodes,geo,mesh};for(let k=0;k<M;k++)this.writeTape(tape,k);geo.attributes.position.needsUpdate=true;this.tapeNodes.push(tape);}}
 writeTape(tape,k){const a=tape.geo.attributes.position.array,n=tape.nodes[k].pos,p=k*6;a[p]=n.x;a[p+1]=n.y+0.06;a[p+2]=n.z;a[p+3]=n.x;a[p+4]=n.y-0.07;a[p+5]=n.z;}
 updateTape(car){const t=performance.now()*.002;for(const tape of this.tapeNodes){let dirty=false;const nodes=tape.nodes;for(let k=0;k<nodes.length;k++){const n=nodes[k];const dx=n.pos.x-car.x,dz=n.pos.z-car.z;
   if(!n.active&&(Math.abs(dx)>6||Math.abs(dz)>6))continue;const dist=Math.hypot(dx,dz);if(dist<4.2)n.active=true;if(!n.active)continue;
   const push=dist<4?Math.pow(1-dist/4,2)*1.6:0;const ux=dist>0.01?dx/dist:1,uz=dist>0.01?dz/dist:0;const tx=n.base.x+ux*push-n.pos.x,ty=n.base.y+Math.sin(t+n.base.x*.03)*.03-n.pos.y,tz=n.base.z+uz*push-n.pos.z;
   n.vel.x=(n.vel.x+tx*0.2)*0.9;n.vel.y=(n.vel.y+ty*0.2)*0.9;n.vel.z=(n.vel.z+tz*0.2)*0.9;n.pos.x+=n.vel.x*0.016;n.pos.y+=n.vel.y*0.016;n.pos.z+=n.vel.z*0.016;
   if(push===0&&Math.abs(tx)+Math.abs(tz)<0.01&&n.vel.lengthSq()<1e-4){n.pos.copy(n.base);n.vel.set(0,0,0);n.active=false;}
   this.writeTape(tape,k);dirty=true;}
  if(dirty)tape.geo.attributes.position.needsUpdate=true;}}
 buildScenery(){const rockGeo=new THREE.DodecahedronGeometry(.55,0),rockMat=new THREE.MeshStandardMaterial({color:0x77736b,roughness:1});const rocks=new THREE.InstancedMesh(rockGeo,rockMat,260);
  const bushGeo=new THREE.IcosahedronGeometry(.65,0),bushMat=new THREE.MeshStandardMaterial({color:0x314e2e,roughness:1});const bushes=new THREE.InstancedMesh(bushGeo,bushMat,200);
  const trunkGeo=new THREE.CylinderGeometry(.18,.25,2.6,6);const trunkMat=new THREE.MeshStandardMaterial({color:0x5a3f28,roughness:1});
  const crownGeo=pineGeo(),crownMat=pineMat();
  const TREE_COUNT=Math.round(420*QF());const trunks=new THREE.InstancedMesh(trunkGeo,trunkMat,TREE_COUNT);const crowns=new THREE.InstancedMesh(crownGeo,crownMat,TREE_COUNT);
  const d=new THREE.Object3D();
  /* ubicar al costado de la pista sin caer sobre otro tramo (curvas cerradas / cruces): se mide contra todo el trazado */
  const SS=this.samples,edge=this.halfWidth+this.shoulder;const clear=(x,z,m)=>{const r2=(edge+m)*(edge+m);for(let j=0;j<SS.length;j+=2){const dx=SS[j].x-x,dz=SS[j].z-z;if(dx*dx+dz*dz<r2)return false;}return true;};
  const place=(min,span,m)=>{for(let t=0;t<8;t++){const idx=Math.floor(Math.random()*SS.length),p=SS[idx],lat=this.laterals[idx],side=Math.random()<.5?-1:1,off=edge+min+Math.random()*span,x=p.x+lat.x*off*side,z=p.z+lat.z*off*side;if(clear(x,z,m))return [x,z,false];}const p=SS[0];return [p.x,p.z,true];};
  for(let i=0;i<260;i++){const [x,z,hid]=place(6,30,4),y=this.ground(x,z)-(hid?50:0);d.position.set(x,y+.3,z);d.scale.setScalar(hid?0:.4+Math.random()*1.3);if(d.scale.x>0.85)addCollider(this,x,z,0.5*d.scale.x);d.rotation.set(Math.random(),Math.random(),Math.random());d.updateMatrix();rocks.setMatrixAt(i,d.matrix)}
  for(let i=0;i<200;i++){const [x,z,hid]=place(4,22,2.5),y=this.ground(x,z)-(hid?50:0);d.position.set(x,y+.45,z);d.scale.set(.8+Math.random()*1.5,.65+Math.random()*1.2,.8+Math.random()*1.5);if(hid)d.scale.setScalar(0);d.updateMatrix();bushes.setMatrixAt(i,d.matrix)}
  for(let i=0;i<TREE_COUNT;i++){const [x,z,hid]=place(7,35,5),y=this.ground(x,z)-(hid?50:0);const sc=hid?0:0.7+Math.random()*0.8;
   d.position.set(x,y+1.3*sc,z);d.scale.setScalar(sc);d.rotation.set(0,Math.random()*6,0);d.updateMatrix();trunks.setMatrixAt(i,d.matrix);if(sc)addCollider(this,x,z,0.28*sc);
   d.position.set(x,y+3.4*sc,z);d.scale.setScalar(sc);d.rotation.set(0,Math.random()*6,0);d.updateMatrix();crowns.setMatrixAt(i,d.matrix)}
  rocks.instanceMatrix.needsUpdate=true;bushes.instanceMatrix.needsUpdate=true;trunks.instanceMatrix.needsUpdate=true;crowns.instanceMatrix.needsUpdate=true;
  tintInstances(crowns);tintInstances(bushes,0.08);
  this.group.add(rocks,bushes,trunks,crowns);
  this.group.add(grassField(Math.round(1400*QF()),()=>{const idx=Math.floor(Math.random()*this.samples.length),p=this.samples[idx],lat=this.laterals[idx],side=Math.random()<.5?-1:1,off=this.halfWidth+this.shoulder+0.4+Math.random()*Math.random()*16;const x=p.x+lat.x*off*side,z=p.z+lat.z*off*side;return [x,this.ground(x,z),z];}));}
 dispose(){this.group.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){if(Array.isArray(o.material))o.material.forEach(m=>{if(m.map&&!m.map.userData.keep)m.map.dispose();m.dispose();});else{if(o.material.map&&!o.material.map.userData.keep)o.material.map.dispose();o.material.dispose();}}});this.scene.remove(this.group);}
}

/* ═══ DRIFT PLAZA — asfalto #606f72 ═══ */
/* ═══════════════════════════════════════════════════════════════════
   LA TRINCHERA — red de caminos hundidos entre paredes de roca (una mina vieja).
   Ancha para dos autos, asfalto y tierra mezclados, tramos donde el camino se abre
   en 2 o 3 carriles alrededor de islas de roca y se vuelve a unir, túneles de mina
   con puntales de madera y lámparas. Las paredes y las islas chocan de verdad.
   ═══════════════════════════════════════════════════════════════════ */
TRACK_ROUTES.trinchera={halfWidth:7,shoulder:0.6,trench:{depth:7.5,
 splits:[{from:0.095,to:0.19,n:2,surf:['asphalt','dirt']},{from:0.455,to:0.56,n:3,surf:['asphalt','dirt','asphalt']},{from:0.775,to:0.865,n:2,surf:['dirt','asphalt']}],
 tunnels:[{from:0.215,to:0.30},{from:0.475,to:0.535},{from:0.635,to:0.705}],
 dirt:[[0.30,0.44],[0.59,0.74]]},points:[
 [0,30,-600],[180,32,-560],[340,36,-470],[450,40,-330],[480,44,-150],[430,48,20],[330,50,150],[300,52,300],[360,50,450],[330,46,600],[200,42,680],[40,38,650],
 [-80,36,560],[-150,34,420],[-280,32,380],[-420,30,440],[-540,28,360],[-560,27,200],[-470,26,60],[-500,26,-100],[-420,27,-260],[-300,28,-380],[-160,29,-520]]};
/* Modo historia · Capítulo 1 "La Fuga": cumbre → curvas de tierra → rampa → bajada de asfalto → trinchera y túneles de la mina → salida */
TRACK_ROUTES.escape={halfWidth:7,shoulder:0.6,trench:{depth:7.5,
 depthK:[[0,1.7],[0.43,1.7],[0.49,7.5],[0.79,7.5],[0.835,1.7],[1,1.7]],
 ramps:[{at:0.214,len:16,h:1.6}],
 splits:[{from:0.575,to:0.64,n:2,surf:['dirt','asphalt']},{from:0.715,to:0.765,n:2,surf:['asphalt','dirt']}],
 tunnels:[{from:0.518,to:0.56},{from:0.655,to:0.70}],
 dirt:[[0.07,0.228],[0.64,0.71]]},points:[
 [-700,165,-520],[-560,164,-520],[-430,162,-515],
 [-330,158,-485],[-270,154,-420],[-280,150,-340],[-210,146,-280],[-120,142,-270],
 [-20,138,-280],[100,134,-285],
 [200,128,-260],[260,120,-190],[240,112,-110],[170,104,-60],[140,96,20],[190,88,90],[280,80,110],[350,72,170],[350,64,260],
 [290,56,340],[190,50,390],[70,46,420],
 [-60,44,440],[-200,42,440],[-320,41,470],[-440,40,560],[-580,40,590],[-700,41,530],[-760,42,420],[-740,44,300],[-690,48,190],
 [-760,60,80],[-880,85,-60],[-920,115,-220],[-880,145,-400],[-800,160,-500]]};
class TrenchTrack extends Track{
 constructor(scene,route){super(scene,'asphalt',route||'trinchera',{});}
 build(){const raw=this.control().map(p=>new THREE.Vector3(p[0],p[1],p[2]));const curve=new THREE.CatmullRomCurve3(raw,true,'catmullrom',0.5);
  const N=Math.max(1100,Math.round(curve.getLength()/4.2));this.samples=curve.getSpacedPoints(N).slice(0,N);/* curva cerrada: sin el punto repetido del final (escalón en la unión) */
  {let y=this.samples.map(p=>p.y);for(const W of [8,8,5]){const o=new Array(N);for(let i=0;i<N;i++){let s=0;for(let j=-W;j<=W;j++)s+=y[(i+j+N)%N];o[i]=s/(2*W+1);}y=o;}this.samples.forEach((p,i)=>p.y=y[i]);}
  this.tangents=this.samples.map((p,i)=>this.samples[(i+1)%N].clone().sub(this.samples[(i+N-1)%N]).normalize());
  this.laterals=this.tangents.map(t=>new THREE.Vector3().crossVectors(t,new THREE.Vector3(0,1,0)).normalize());
  this.cum=[0];for(let i=1;i<=N;i++)this.cum[i]=this.cum[i-1]+this.samples[i-1].distanceTo(this.samples[i%N]);this.length=this.cum[N];
  this.features();this.buildRoad();this.buildTerrain();this.buildStart();this.buildScenery();}
 roadOffset(i){return 0.04+0.05*Math.sin(i*0.021)+(this.rampA?this.rampA[i]:0);}
 /* por muestra: ancho, islas, túnel, superficie, profundidad */
 features(){const T=this.routeDef.trench,N=this.samples.length,L=this.length;const s=i=>this.cum[i];
  const win=(i,a,b,m)=>{const x=s(i),sa=a*L,sb=b*L;if(x<sa||x>sb)return 0;const u=Math.min((x-sa)/m,(sb-x)/m,1);return u*u*(3-2*u);};
  /* rampas de salto: la calzada sube y corta de golpe (el auto sale volando) */
  if(T.ramps){this.rampA=new Float32Array(N);this.ramps=[];for(const R of T.ramps){const s0=R.at*L;let top=0;for(let i=0;i<N;i++){const u=(s(i)-s0)/R.len;if(u>=0&&u<=1){this.rampA[i]=R.h*Math.pow(u,1.25);top=i;}}this.ramps.push({i0:Math.floor(R.at*N),top,h:R.h});}}
  const dK=T.depthK,depthAt=f=>{if(!dK)return T.depth;for(let k=1;k<dK.length;k++)if(f<=dK[k][0]){const a=dK[k-1],b=dK[k],u=(f-a[0])/Math.max(1e-6,b[0]-a[0]),w=u*u*(3-2*u);return a[1]+(b[1]-a[1])*w;}return dK[dK.length-1][1];};
  this.hwA=new Float32Array(N);this.isl=[];this.tun=new Uint8Array(N);this.surfA=[];this.split=[];this.D=new Float32Array(N);this.ry=new Float32Array(N);
  for(let i=0;i<N;i++){const f=s(i)/L;let hw=7,isl=[],sp=null;
   /* primero se ensancha el camino y recién después, ya ancho, aparece la isla (sin "punta" en medio del tráfico) */
   for(const S of T.splits){const w=win(i,S.from,S.to,55);if(w>0){const wi=win(i,S.from+65/L,S.to-65/L,60);if(S.n===2){hw=7+5.5*w;isl=[{c:0,w:2.9*wi}];}else{hw=7+6.8*w;const iw=1.8*wi;isl=[{c:-4.7,w:iw},{c:4.7,w:iw}];}sp=S.surf;}}
   this.hwA[i]=hw;this.isl.push(isl.filter(x=>x.w>0.04));this.split.push(sp);
   this.tun[i]=T.tunnels.some(t=>f>=t.from&&f<=t.to)?1:0;
   this.surfA.push(T.dirt.some(([a,b])=>f>=a&&f<=b)?'dirt':'asphalt');
   {const b=depthAt(f);this.D[i]=b+(1.2*Math.sin(i*0.013)+0.6*Math.sin(i*0.047))*Math.min(1,b/7.5);}this.ry[i]=this.samples[i].y+this.roadOffset(i);}}
 surfAt(i,lat){const sp=this.split[i];if(sp&&this.isl[i].length){let k=0;for(const is of this.isl[i])if(lat>is.c)k++;return sp[k]||this.surfA[i];}return this.surfA[i];}
 gColor(x,z){return new THREE.Color(0x56683b).lerp(new THREE.Color(0x857a52),0.5+0.5*Math.sin(x*0.007+z*0.005)).offsetHSL(0,0,(Math.random()-.5)*.04);}
 rimY(x,z,i){return this.ry[i]+this.D[i]+0.6*Math.sin(x*.02+z*.018)+0.3*Math.sin(x*.045-z*.038+1.3);}
 groundInfo(x,z){const n=this.nearest(x,z),i=n.idx,d=Math.abs(n.lateral),hw=this.hwA[i],o=this._gi||(this._gi={y:0,surf:'asphalt'});
  if(d<=hw+2.6){o.surf=this.surfAt(i,n.lateral);o.y=n.y+(d<hw?(1-(d/hw)**2)*0.03:0)+microBump(x,z,o.surf);}else{o.surf='outside';o.y=this.rimY(x,z,i);}
  o.tunnel=!!this.tun[i]&&d<hw+2.6;return o;}
 ground(x,z){const n=this.nearest(x,z),i=n.idx,d=Math.abs(n.lateral),hw=this.hwA[i];return d<=hw+2.6?n.y+(d<hw?(1-(d/hw)**2)*0.03:0):this.rimY(x,z,i);}
 surface(x,z){return this.groundInfo(x,z).surf;}
 inTunnel(x,z){const n=this.nearest(x,z);return !!this.tun[n.idx]&&Math.abs(n.lateral)<this.hwA[n.idx]+2.6;}
 /* pared o isla que toca un círculo (x,z,r): normal de empuje y penetración */
 wallPush(x,z,r){const n=this.nearest(x,z),i=n.idx,lat=n.lateral,hw=this.hwA[i],L=this.laterals[i];let best=null;const lim=hw-0.1;
  if(Math.abs(lat)+r>lim){const sg=Math.sign(lat)||1;best={nx:-L.x*sg,nz:-L.z*sg,pen:Math.abs(lat)+r-lim};}
  for(const is of this.isl[i]){const dd=lat-is.c;if(Math.abs(dd)<is.w+r){const sg=Math.sign(dd)||1,pen=is.w+r-Math.abs(dd);if(!best||pen>best.pen)best={nx:L.x*sg,nz:L.z*sg,pen};}}
  return best;}
 /* la IA elige un carril libre (entre las islas) */
 laneFix(i,lane,pref){const N=this.samples.length;i=((i%N)+N)%N;const hw=this.hwA[i]-1.3;let iv=[[-hw,hw]];
  for(const is of this.isl[i]){const a=is.c-is.w-1.9,b=is.c+is.w+1.9;const nx=[];for(const [l,r] of iv){if(b<=l||a>=r){nx.push([l,r]);continue;}if(a>l)nx.push([l,a]);if(b<r)nx.push([b,r]);}iv=nx;}
  if(!iv.length)return lane;if(pref!=null&&iv.length>1){/* carril preferido: izquierda / centro / derecha */const k=pref<0?0:pref>0?iv.length-1:Math.floor(iv.length/2),[l,r]=iv[k];return clamp(lane,l,r);}
  for(const [l,r] of iv)if(lane>=l&&lane<=r)return lane;let best=lane,bd=1e9;for(const [l,r] of iv){const c=clamp(lane,l,r),d=Math.abs(c-lane);if(d<bd){bd=d;best=c;}}return best;}
 /* la cámara no atraviesa las paredes */
 clampCam(pos){const n=this.nearest(pos.x,pos.z),hw=this.hwA[n.idx]-0.7;if(Math.abs(n.lateral)>hw){const L=this.laterals[n.idx],ex=(Math.abs(n.lateral)-hw)*Math.sign(n.lateral);pos.x-=L.x*ex;pos.z-=L.z*ex;}}
 buildRoad(){const S=this.samples,N=S.length,G=this.group;
  const rockTex=canvasTex(256,256,(c,w,h)=>{c.fillStyle='#b3a491';c.fillRect(0,0,w,h);for(let i=0;i<2600;i++){const q=120+Math.random()*80;c.fillStyle=`rgba(${q+15},${q+5},${q-8},.5)`;c.fillRect(Math.random()*w,Math.random()*h,2+Math.random()*6,1+Math.random()*3);}for(let y=0;y<h;y+=18+Math.random()*14){c.fillStyle='rgba(40,32,26,.35)';c.fillRect(0,y,w,2+Math.random()*3);}});rockTex.wrapS=rockTex.wrapT=THREE.RepeatWrapping;
  const mk=(P,I,mat,C,UV)=>{const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(P,3));if(C)g.setAttribute('color',new THREE.Float32BufferAttribute(C,3));if(UV)g.setAttribute('uv',new THREE.Float32BufferAttribute(UV,2));g.setIndex(I);g.computeVertexNormals();const m=new THREE.Mesh(g,mat);m.receiveShadow=true;G.add(m);return m;};
  /* calzada: asfalto y tierra en mallas separadas */
  const FR=[-1,-0.75,-0.5,-0.25,0,0.25,0.5,0.75,1],RW=FR.length,P=[],UV=[],IA=[],ID=[];
  for(let i=0;i<N;i++){const p=S[i],l=this.laterals[i],hw=this.hwA[i];for(const f of FR){const o=f*hw;P.push(p.x+l.x*o,this.ry[i]+(1-f*f)*0.03+0.02,p.z+l.z*o);UV.push(o/6+0.5,this.cum[i]/8);}}
  for(let i=0;i<N;i++){const j=(i+1)%N;for(let k=0;k<RW-1;k++){const a=i*RW+k,b=a+1,c=j*RW+k,d=c+1;const lat=(FR[k]+FR[k+1])/2*this.hwA[i];(this.surfAt(i,lat)==='dirt'?ID:IA).push(a,b,c,b,d,c);}}
  upFacing(P,IA);upFacing(P,ID);
  const asph=canvasTex(512,512,(c,w,h)=>{c.fillStyle='#34373b';c.fillRect(0,0,w,h);for(let i=0;i<16000;i++){const q=38+Math.random()*45;c.fillStyle=`rgb(${q},${q},${q+3})`;c.fillRect(Math.random()*w,Math.random()*h,1.3,1.3);}for(let i=0;i<30;i++){c.fillStyle='rgba(18,20,24,.16)';c.beginPath();c.ellipse(Math.random()*w,Math.random()*h,20+Math.random()*50,40+Math.random()*80,0,0,7);c.fill();}c.fillStyle='rgba(235,235,225,.8)';c.fillRect(252,0,8,300);});
  const dirt=canvasTex(512,512,(c,w,h)=>{c.fillStyle='#6a5139';c.fillRect(0,0,w,h);for(let i=0;i<18000;i++){const q=72+Math.random()*55;c.fillStyle=`rgb(${q},${q*0.8},${q*0.58})`;c.fillRect(Math.random()*w,Math.random()*h,1.6,1.6);}c.fillStyle='rgba(40,30,20,.25)';for(const x of [150,360])for(let y=0;y<h;y+=4)c.fillRect(x+Math.sin(y*.05)*7-20,y,40,3);});
  for(const t of [asph,dirt]){t.wrapS=t.wrapT=THREE.RepeatWrapping;t.anisotropy=4;}
  mk(P,IA,new THREE.MeshLambertMaterial({map:asph,polygonOffset:true,polygonOffsetFactor:-3,polygonOffsetUnits:-3}),null,UV);
  mk(P,ID,new THREE.MeshLambertMaterial({map:dirt,polygonOffset:true,polygonOffsetFactor:-3,polygonOffsetUnits:-3}),null,UV);
  /* paredes de roca + borde superior (tapa el terreno hundido) */
  const {cell}=this.terrainDims();const EXT=2.6+cell*2.95+2;const WR=[[0,0],[0.25,0.22],[1.1,0.55],[1.9,0.86],[2.6,1],[5,1],[9,1],[EXT,1]];const WP=[],WC=[],WU=[],WI=[];
  const cRock=new THREE.Color(0xd2c2ad),cGrass=new THREE.Color(0x6d8248);
  for(let i=0;i<N;i++){const p=S[i],l=this.laterals[i],hw=this.hwA[i];for(const sd of [-1,1])for(let k=0;k<WR.length;k++){const [off,hf]=WR[k];const o=sd*(hw+off);const x=p.x+l.x*o,z=p.z+l.z*o;
    const nz=(k>0&&k<4)?(Math.sin(i*0.9+k*2.1+sd)*0.25+Math.sin(i*0.23+k)*0.2):0;const y=k>=4?this.rimY(x,z,i):this.ry[i]+this.D[i]*hf;
    WP.push(x+l.x*sd*nz,y,z+l.z*sd*nz);const c=k<4?cRock.clone().offsetHSL(0,0,(Math.sin(y*1.7)*0.05)+(Math.random()-0.5)*0.05):k===4?cRock.clone().lerp(this.gColor(x,z),0.5):this.gColor(x,z);WC.push(c.r,c.g,c.b);WU.push(k*0.5,this.cum[i]/6);}}
  const WN=WR.length;for(let i=0;i<N;i++){const j=(i+1)%N;for(let sd=0;sd<2;sd++)for(let k=0;k<WN-1;k++){const a=i*WN*2+sd*WN+k,b=a+1,c=j*WN*2+sd*WN+k,d=c+1;if(sd)WI.push(a,c,b,b,c,d);else WI.push(a,b,c,b,d,c);}}
  mk(WP,WI,new THREE.MeshLambertMaterial({map:rockTex,vertexColors:true,side:THREE.DoubleSide}),WC,WU).castShadow=true;
  /* islas de roca (donde el camino se abre) */
  const IP=[],IC=[],IU=[],II=[];let base=0;
  const runs=[];let cur=null;for(let i=0;i<N;i++){const n=this.isl[i].length;if(n&&cur&&cur.n===n&&cur.end===i-1){cur.end=i;}else if(n){cur={s:i,end:i,n};runs.push(cur);}}
  for(const r of runs)for(let q=0;q<r.n;q++){const start=IP.length/3;for(let i=r.s;i<=r.end;i++){const is=this.isl[i][q],p=S[i],l=this.laterals[i],y=this.ry[i],D=this.D[i];
    for(const [f,hf] of [[-1,0],[-0.85,0.5],[-0.35,0.9],[0.35,0.9],[0.85,0.5],[1,0]]){const o=is.c+f*is.w;IP.push(p.x+l.x*o,y+D*hf*Math.min(1,is.w/0.9)+(hf>0.85?Math.sin(i*0.7+q)*0.25:0),p.z+l.z*o);const c=cRock.clone().offsetHSL(0,0,(Math.random()-0.5)*0.06-0.04);IC.push(c.r,c.g,c.b);IU.push(f,this.cum[i]/6);}}
   const cnt=r.end-r.s+1;for(let i=0;i<cnt-1;i++)for(let k=0;k<5;k++){const a=start+i*6+k,b=a+1,c=a+6,d=c+1;II.push(a,c,b,b,c,d);}}
  if(II.length)mk(IP,II,new THREE.MeshLambertMaterial({map:rockTex,vertexColors:true,side:THREE.DoubleSide}),IC,IU).castShadow=true;
  /* túneles: bóveda, puntales de madera y lámparas */
  const TP=[],TI=[],TU=[];const AR=9;const truns=[];cur=null;for(let i=0;i<N;i++){if(this.tun[i]){if(cur&&cur.end===i-1)cur.end=i;else{cur={s:i,end:i};truns.push(cur);}}}
  for(const r of truns){const start=TP.length/3;for(let i=r.s;i<=r.end;i++){const p=S[i],l=this.laterals[i],hw=this.hwA[i]+2.7,y=this.ry[i],D=this.D[i];for(let k=0;k<AR;k++){const f=-1+2*k/(AR-1),o=f*hw;TP.push(p.x+l.x*o,y+D*0.5+D*0.4*Math.cos(f*Math.PI/2)+Math.sin(i*0.8+k)*0.12,p.z+l.z*o);TU.push(f*2,this.cum[i]/6);}}
   const cnt=r.end-r.s+1;for(let i=0;i<cnt-1;i++)for(let k=0;k<AR-1;k++){const a=start+i*AR+k,b=a+1,c=a+AR,d=c+1;TI.push(a,b,c,b,d,c);}}
  this.tunnelRuns=truns;
  /* tapa del túnel (suelo de arriba, al nivel del borde) y fachada de roca sobre cada boca */
  {const LP=[],LC=[],LI=[],FP=[],FI=[];const LR=7;
   for(const r of truns){const st=LP.length/3;const a=Math.max(0,r.s-1),b=Math.min(N-1,r.end+1);for(let i=a;i<=b;i++){const p=S[i],l=this.laterals[i],hw=this.hwA[i]+2.7;for(let k=0;k<LR;k++){const f=-1+2*k/(LR-1),o=f*hw,x=p.x+l.x*o,z=p.z+l.z*o;LP.push(x,this.rimY(x,z,i)+0.02,z);const c=this.gColor(x,z);LC.push(c.r,c.g,c.b);}}
    const cnt=b-a+1;for(let i=0;i<cnt-1;i++)for(let k=0;k<LR-1;k++){const q=st+i*LR+k;LI.push(q,q+1,q+LR,q+1,q+LR+1,q+LR);}
    for(const i of [r.s,r.end]){const fs=FP.length/3,p=S[i],l=this.laterals[i],hw=this.hwA[i]+2.7,y=this.ry[i],D=this.D[i];for(let k=0;k<AR;k++){const f=-1+2*k/(AR-1),o=f*hw,x=p.x+l.x*o,z=p.z+l.z*o;FP.push(x,y+D*0.5+D*0.4*Math.cos(f*Math.PI/2)-0.05,z,x,this.rimY(x,z,i)+0.05,z);}
     for(let k=0;k<AR-1;k++){const q=fs+k*2;FI.push(q,q+2,q+1,q+1,q+2,q+3);}}}
   if(LI.length){upFacing(LP,LI);mk(LP,LI,new THREE.MeshLambertMaterial({vertexColors:true}),LC,null);}
   if(FI.length)mk(FP,FI,new THREE.MeshLambertMaterial({map:rockTex,color:0xb09f8a,side:THREE.DoubleSide}),null,FP.map((v,k)=>k%3===0?v*0.2:v*0.2).filter((v,k)=>k%3!==2));}
  if(TI.length){const tm=mk(TP,TI,new THREE.MeshLambertMaterial({map:rockTex,color:0x9a8c7c,side:THREE.DoubleSide}),null,TU);tm.castShadow=true;}
  const wood=new THREE.MeshLambertMaterial({color:0x5b3e22}),lampM=new THREE.MeshBasicMaterial({color:0xffc27a});const posts=[],beams=[],lamps=[];
  for(const r of truns)for(let i=r.s;i<=r.end;i+=3){const p=S[i],l=this.laterals[i],t=this.tangents[i],hw=this.hwA[i],y=this.ry[i],h=this.D[i]*0.62;const yaw=Math.atan2(t.x,t.z);
   for(const sd of [-1,1]){const o=sd*(hw+0.25);posts.push([p.x+l.x*o,y+h/2,p.z+l.z*o,yaw,h]);}beams.push([p.x,y+h,p.z,yaw,hw*2+0.6]);if(((i-r.s)/3)%3===0)lamps.push([p.x+l.x*(hw-0.1),y+h-0.35,p.z+l.z*(hw-0.1)]);}
  const d=new THREE.Object3D();const inst=(geo,mat,list,fn)=>{if(!list.length)return;const m=new THREE.InstancedMesh(geo,mat,list.length);list.forEach((e,k)=>{fn(e);d.updateMatrix();m.setMatrixAt(k,d.matrix);});G.add(m);};
  inst(new THREE.BoxGeometry(0.28,1,0.28),wood,posts,e=>{d.position.set(e[0],e[1],e[2]);d.rotation.set(0,e[3],0);d.scale.set(1,e[4],1);});
  inst(new THREE.BoxGeometry(1,0.3,0.32),wood,beams,e=>{d.position.set(e[0],e[1],e[2]);d.rotation.set(0,e[3],0);d.scale.set(e[4],1,1);});
  inst(new THREE.BoxGeometry(0.22,0.3,0.22),lampM,lamps,e=>{d.position.set(e[0],e[1],e[2]);d.rotation.set(0,0,0);d.scale.set(1,1,1);});
  /* carteles de entrada a los túneles */
  for(const r of truns){const i=r.s,p=S[i],t=this.tangents[i],y=this.ry[i];const sg=canvasTex(512,96,(c,w,h)=>{c.fillStyle='#2b1c10';c.fillRect(0,0,w,h);c.strokeStyle='#e0a040';c.lineWidth=6;c.strokeRect(6,6,w-12,h-12);c.fillStyle='#f5c26b';c.font='900 52px system-ui,sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('⛏ MINA · GALERÍA '+(truns.indexOf(r)+1),w/2,h/2+2);});
   const m=new THREE.Mesh(new THREE.PlaneGeometry(7,1.3),new THREE.MeshBasicMaterial({map:sg,side:THREE.DoubleSide}));m.position.set(p.x,y+this.D[i]*0.62+1.0,p.z);m.rotation.y=Math.atan2(t.x,t.z)+Math.PI;G.add(m);}}
 /* terreno: el borde del cañón arriba, hundido (oculto) dentro de la trinchera salvo en los túneles (techo) */
 buildTerrain(){const {minX,maxX,minZ,maxZ,R,cell}=this.terrainDims();const S=this.samples,N=S.length,SR=2.6+cell*1.45;const pos=[],col=[],idx=[];
  const coarse=[];for(let i=0;i<N;i+=6)coarse.push(i);
  for(let iz=0;iz<=R;iz++){const z=lerp(minZ,maxZ,iz/R);for(let ix=0;ix<=R;ix++){const x=lerp(minX,maxX,ix/R);let bi=0,bd=1e18;for(const i of coarse){const dx=S[i].x-x,dz=S[i].z-z,dd=dx*dx+dz*dz;if(dd<bd){bd=dd;bi=i;}}
    let i=bi,lat=Math.sqrt(bd);if(lat<this.hwA[bi]+SR+40){this._hint=bi;const n=this.nearest(x,z);i=n.idx;lat=Math.abs(n.lateral);}
    const inside=lat<this.hwA[i]+SR;const y=inside?this.ry[i]-2.5:this.rimY(x,z,i);pos.push(x,y,z);
    const cc=this.gColor(x,z);col.push(cc.r,cc.g,cc.b);}}
  for(let iz=0;iz<R;iz++)for(let ix=0;ix<R;ix++){const a=iz*(R+1)+ix,b=a+1,c=a+R+1,d=c+1;idx.push(a,c,b,b,c,d);}
  this._hint=null;const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.setAttribute('color',new THREE.Float32BufferAttribute(col,3));g.setIndex(idx);g.computeVertexNormals();this.group.add(terrainMesh(g));}
 buildTape(){}
 /* pinos y rocas arriba, sobre el borde; cajones y restos de la mina en la largada */
 buildScenery(){const S=this.samples,N=S.length,G=this.group;const d=new THREE.Object3D();
  const clear=(x,z,m)=>{for(let j=0;j<N;j+=3){const dx=S[j].x-x,dz=S[j].z-z,r=this.hwA[j]+m;if(dx*dx+dz*dz<r*r)return false;}return true;};
  const place=(min,span,m)=>{for(let t=0;t<8;t++){const i=Math.floor(Math.random()*N),p=S[i],l=this.laterals[i],sd=Math.random()<.5?-1:1,off=this.hwA[i]+min+Math.random()*span,x=p.x+l.x*off*sd,z=p.z+l.z*off*sd;if(clear(x,z,m))return [x,z,i];}return null;};
  const TREE=Math.round(320*QF());const trunks=new THREE.InstancedMesh(new THREE.CylinderGeometry(.18,.25,2.6,6),new THREE.MeshStandardMaterial({color:0x5a3f28,roughness:1}),TREE),crowns=new THREE.InstancedMesh(pineGeo(),pineMat(),TREE);
  for(let k=0;k<TREE;k++){const r=place(6,60,5);const sc=r?0.7+Math.random()*0.8:0;const [x,z,i]=r||[S[0].x,S[0].z,0];const y=r?this.rimY(x,z,i):-99;
   d.position.set(x,y+1.3*sc,z);d.scale.setScalar(sc);d.rotation.set(0,Math.random()*6,0);d.updateMatrix();trunks.setMatrixAt(k,d.matrix);d.position.set(x,y+3.4*sc,z);d.updateMatrix();crowns.setMatrixAt(k,d.matrix);}
  G.add(trunks,crowns);
  const rocks=new THREE.InstancedMesh(new THREE.DodecahedronGeometry(.8,0),new THREE.MeshStandardMaterial({color:0x7d7266,roughness:1}),200);
  for(let k=0;k<200;k++){const r=place(3,40,3);const [x,z,i]=r||[S[0].x,S[0].z,0];const y=r?this.rimY(x,z,i):-99;d.position.set(x,y+0.3,z);d.scale.setScalar(r?0.5+Math.random()*1.6:0);d.rotation.set(Math.random(),Math.random(),Math.random());d.updateMatrix();rocks.setMatrixAt(k,d.matrix);}
  G.add(rocks);
  /* restos de mina junto a la largada (contra las paredes, fuera de la calzada útil) */
  const crate=new THREE.MeshLambertMaterial({color:0x7a5530});for(let k=0;k<6;k++){const i=(N-30+k*9)%N,p=S[i],l=this.laterals[i],sd=k%2?1:-1,hw=this.hwA[i];const b=new THREE.Mesh(new THREE.BoxGeometry(1.1,1.1,1.1),crate);b.position.set(p.x+l.x*sd*(hw+0.9),this.ry[i]+0.55+(k%3===0?1.1:0),p.z+l.z*sd*(hw+0.9));b.rotation.y=k;G.add(b);}}
}
/* pista del Capítulo 1: la trinchera con la rampa de madera y carteles */
class StoryTrack extends TrenchTrack{
 buildScenery(){super.buildScenery();const G=this.group,S=this.samples,N=S.length;const wood=new THREE.MeshLambertMaterial({color:0x7a5530}),dark=new THREE.MeshLambertMaterial({color:0x4a3220});
  for(const R of this.ramps||[]){/* tablones a los costados y borde del salto */for(let i=R.i0;i<=R.top;i++){const p=S[i],q=S[Math.min(N-1,i+1)],l=this.laterals[i],hw=this.hwA[i],y=this.ry[i];const len=p.distanceTo(q)+0.05,pitch=Math.atan2(this.ry[Math.min(N-1,i+1)]-y,len);
    for(const sd of [-1,1]){const b=new THREE.Mesh(new THREE.BoxGeometry(0.35,0.5,len),wood);b.position.set((p.x+q.x)/2+l.x*sd*(hw-0.2),(y+this.ry[Math.min(N-1,i+1)])/2+0.25,(p.z+q.z)/2+l.z*sd*(hw-0.2));b.rotation.set(0,0,0);b.lookAt(q.x+l.x*sd*(hw-0.2),this.ry[Math.min(N-1,i+1)]+0.25,q.z+l.z*sd*(hw-0.2));G.add(b);}}
   const p=S[R.top],t=this.tangents[R.top],l=this.laterals[R.top],hw=this.hwA[R.top],y=this.ry[R.top];const lip=new THREE.Mesh(new THREE.BoxGeometry(hw*2,0.18,0.5),dark);lip.position.set(p.x,y-0.05,p.z);lip.rotation.y=Math.atan2(t.x,t.z);G.add(lip);
   /* frente del salto: pared de tablones hasta el piso */
   const face=new THREE.Mesh(new THREE.BoxGeometry(hw*2,R.h,0.3),dark);face.position.set(p.x+t.x*0.9,y-R.h/2,p.z+t.z*0.9);face.rotation.y=Math.atan2(t.x,t.z);G.add(face);
   const sg=canvasTex(512,128,(c,w,h)=>{c.fillStyle='#f2c230';c.fillRect(0,0,w,h);c.fillStyle='#111';for(let x=-40;x<w;x+=64){c.beginPath();c.moveTo(x,0);c.lineTo(x+32,0);c.lineTo(x+64,h);c.lineTo(x+32,h);c.fill();}c.fillStyle='#111';c.fillRect(90,26,332,76);c.fillStyle='#f2c230';c.font='900 60px system-ui,sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('¡SALTO!',256,66);});
   const i2=Math.max(0,R.i0-14),p2=S[i2],t2=this.tangents[i2];const m=new THREE.Mesh(new THREE.PlaneGeometry(5,1.25),new THREE.MeshBasicMaterial({map:sg,side:THREE.DoubleSide}));m.position.set(p2.x+this.laterals[i2].x*(this.hwA[i2]+0.8),this.ry[i2]+2.6,p2.z+this.laterals[i2].z*(this.hwA[i2]+0.8));m.rotation.y=Math.atan2(t2.x,t2.z)+Math.PI;G.add(m);
   for(const sd of [-1,1]){const post=new THREE.Mesh(new THREE.BoxGeometry(0.15,2.6,0.15),dark);post.position.set(m.position.x+this.laterals[i2].x*sd*2.3,this.ry[i2]+1.3,m.position.z+this.laterals[i2].z*sd*2.3);G.add(post);}}}
}
/* ═══ Conos con física: al chocarlos salen despedidos, giran, se caen y quedan desparramados ═══ */
class ConeField{
 constructor(group,positions,groundFn,coneGeo,coneMat,baseGeo,baseMat){this.ground=groundFn;const g=new THREE.BufferGeometry();
  /* cono + base en una sola malla con el origen en el piso */
  const cg=coneGeo.clone();cg.translate(0,0.44,0);const bg=baseGeo.clone();bg.translate(0,0.03,0);
  this.mC=new THREE.InstancedMesh(cg,coneMat,positions.length);this.mB=new THREE.InstancedMesh(bg,baseMat,positions.length);
  this.c=positions.map(([x,z])=>({x,z,y:groundFn(x,z),vx:0,vy:0,vz:0,q:new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,1,0),Math.random()*6.28),w:new THREE.Vector3(),awake:false,tip:0,ax:new THREE.Vector3(1,0,0)}));
  this.d=new THREE.Object3D();for(let i=0;i<this.c.length;i++)this.write(i);group.add(this.mC,this.mB);this.mC.castShadow=true;}
 write(i){const c=this.c[i],d=this.d;d.position.set(c.x,c.y,c.z);d.quaternion.copy(c.q);d.updateMatrix();this.mC.setMatrixAt(i,d.matrix);this.mB.setMatrixAt(i,d.matrix);this.mC.instanceMatrix.needsUpdate=true;this.mB.instanceMatrix.needsUpdate=true;}
 /* choque auto-cono (círculos del auto) */
 collide(p,circles){for(const c of this.c){if(Math.abs(c.x-p.px)>5||Math.abs(c.z-p.pz)>5)continue;for(const [cx,cz,r] of circles){const dx=c.x-cx,dz=c.z-cz,d=Math.hypot(dx,dz),mn=r+0.34;if(d>=mn||d<1e-4)continue;
   const nx=dx/d,nz=dz/d,vn=p.vx*nx+p.vz*nz;const sp=Math.hypot(p.vx,p.vz);c.x+=nx*(mn-d);c.z+=nz*(mn-d);
   /* un solo golpe por cono: sale despedido más rápido que el auto (no se lo vuelve a llevar por delante) */
   const now=performance.now();if(c.hitT&&now-c.hitT<400)continue;c.hitT=now;const k=Math.max(vn,0.5);
   c.vx=p.vx*1.12+nx*k*0.7+(Math.random()-.5)*sp*0.12;c.vz=p.vz*1.12+nz*k*0.7+(Math.random()-.5)*sp*0.12;c.vy=Math.min(8,1.2+sp*0.16+Math.random()*1.4);
   c.w.set((Math.random()-.5)*sp*1.2,(Math.random()-.5)*sp*0.8,(Math.random()-.5)*sp*1.2);c.awake=true;/* el cono pesa 3 kg: casi no frena al auto */p.vx*=0.997;p.vz*=0.997;break;}}}
 update(dt){dt=Math.min(dt,0.05);const tq=this._t||(this._t=new THREE.Quaternion()),up=this._u||(this._u=new THREE.Vector3()),ax=this._a||(this._a=new THREE.Vector3());
  for(let i=0;i<this.c.length;i++){const c=this.c[i];if(!c.awake)continue;c.vy-=9.81*dt;c.x+=c.vx*dt;c.y+=c.vy*dt;c.z+=c.vz*dt;
   const w=c.w.length();if(w>1e-3){ax.copy(c.w).divideScalar(w);tq.setFromAxisAngle(ax,w*dt);c.q.premultiply(tq);}
   up.set(0,1,0).applyQuaternion(c.q);const lift=0.3*Math.max(0,1-Math.abs(up.y));/* acostado apoya sobre el costado */
   const gy=this.ground(c.x,c.z)+lift;if(c.y<=gy){c.y=gy;if(c.vy<0)c.vy=-c.vy*0.25;c.vx*=Math.exp(-dt*3.2);c.vz*=Math.exp(-dt*3.2);c.w.multiplyScalar(Math.exp(-dt*4.5));
    if(Math.hypot(c.vx,c.vz)<0.08&&Math.abs(c.vy)<0.4&&w<0.35){/* reposo: parado si cayó derecho, si no acostado de costado */
     if(up.y>0.85)c.q.setFromAxisAngle(ax.set(0,1,0),Math.atan2(up.x,up.z));else{let hx=up.x,hz=up.z;const hl=Math.hypot(hx,hz)||1;const tgt=ax.set(hx/hl*0.97,0.24,hz/hl*0.97).normalize();c.q.setFromUnitVectors(new THREE.Vector3(0,1,0),tgt);}
     up.set(0,1,0).applyQuaternion(c.q);c.y=this.ground(c.x,c.z)+0.3*Math.max(0,1-Math.abs(up.y));c.awake=false;c.vx=c.vz=c.vy=0;c.w.set(0,0,0);}}
   this.write(i);}}
}
class DriftTrack{
 constructor(scene){
  this.scene=scene;this.kind='drift';this.mode='asphalt';this.lapEnabled=false;
  this.halfWidth=120;this.shoulder=0;this.length=2*Math.PI*25;
  this.samples=[new THREE.Vector3(0,0,80)];
  this.tangents=[new THREE.Vector3(0,0,-1)];
  this.laterals=[new THREE.Vector3(1,0,0)];
  this.cum=[0,0];
  this.tapeNodes=[];
  this._n={dist:0,idx:0,t:0,y:0,lateral:0,tan:this.tangents[0],lat:this.laterals[0]};
  this._gi={y:0,surf:'asphalt'};
  this._hint=null;
  this.group=new THREE.Group();scene.add(this.group);
  this.build();
 }
 nearest(){const o=this._n;o.dist=0;o.y=0;o.lateral=0;return o;}
 groundInfo(){const o=this._gi;o.y=0;o.surf='asphalt';return o;}
 ground(){return 0;}
 surface(){return 'asphalt';}
 updateTape(){}
 build(){
  const SIZE=260;
  const cvs=document.createElement('canvas');cvs.width=cvs.height=2048;
  const ctx=cvs.getContext('2d');
  const CX=1024, CY=1024;
  const SCALE=2048/SIZE;
  // Color de asfalto #606f72
  ctx.fillStyle='#606f72';ctx.fillRect(0,0,2048,2048);
  // Grano: mezcla de puntos oscuros y claros
  for(let i=0;i<90000;i++){
   const darker=Math.random()<0.5;
   const q=darker?(70+Math.random()*25):(110+Math.random()*30);
   ctx.fillStyle=`rgb(${q},${q+5},${q+8})`;
   ctx.fillRect(Math.random()*2048,Math.random()*2048,1.2,1.2);
  }
  // Manchas oscuras sutiles
  for(let i=0;i<120;i++){const x=Math.random()*2048,y=Math.random()*2048,r=20+Math.random()*90;ctx.fillStyle='rgba(40,48,52,.18)';ctx.beginPath();ctx.arc(x,y,r,0,7);ctx.fill();}
  // Marcas de derrape
  for(let i=0;i<10;i++){
   const r=(22+Math.random()*8)*SCALE;
   ctx.strokeStyle=`rgba(30,35,40,${0.22+Math.random()*0.14})`;
   ctx.lineWidth=0.35*SCALE;
   ctx.beginPath();ctx.arc(CX,CY,r,Math.random()*Math.PI*2,Math.random()*Math.PI*2+Math.PI);ctx.stroke();
  }
  // Rotonda blanca
  ctx.strokeStyle='#f0f0f0';ctx.lineWidth=0.30*SCALE;ctx.beginPath();ctx.arc(CX,CY,25*SCALE,0,Math.PI*2);ctx.stroke();
  ctx.strokeStyle='#e8e8e8';ctx.lineWidth=0.20*SCALE;ctx.beginPath();ctx.arc(CX,CY,12*SCALE,0,Math.PI*2);ctx.stroke();
  ctx.strokeStyle='#e0e0e0';ctx.lineWidth=0.20*SCALE;ctx.beginPath();ctx.arc(CX,CY,45*SCALE,0,Math.PI*2);ctx.stroke();
  ctx.strokeStyle='#d0d0d0';ctx.lineWidth=0.22*SCALE;ctx.beginPath();ctx.arc(CX,CY,95*SCALE,0,Math.PI*2);ctx.stroke();
  ctx.lineWidth=0.20*SCALE;
  for(let i=0;i<12;i++){const a=i*Math.PI/6;ctx.beginPath();ctx.moveTo(CX+Math.cos(a)*30*SCALE,CY+Math.sin(a)*30*SCALE);ctx.lineTo(CX+Math.cos(a)*43*SCALE,CY+Math.sin(a)*43*SCALE);ctx.stroke();}
  ctx.lineWidth=0.25*SCALE;
  ctx.beginPath();ctx.moveTo(CX-3*SCALE,CY);ctx.lineTo(CX+3*SCALE,CY);ctx.moveTo(CX,CY-3*SCALE);ctx.lineTo(CX,CY+3*SCALE);ctx.stroke();
  ctx.save();ctx.translate(CX,CY);ctx.fillStyle='rgba(240,240,240,.15)';ctx.font=`bold ${3*SCALE}px sans-serif`;ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('DRIFT',0,-55*SCALE);ctx.restore();

  const tex=new THREE.CanvasTexture(cvs);tex.anisotropy=8;tex.colorSpace=THREE.SRGBColorSpace;
  const geo=new THREE.PlaneGeometry(SIZE,SIZE,1,1);geo.rotateX(-Math.PI/2);
  const plane=new THREE.Mesh(geo,new THREE.MeshLambertMaterial({map:tex}));
  plane.position.y=0;
  this.group.add(plane);

  const coneGeo=new THREE.ConeGeometry(0.32,0.85,10);
  const coneMat=new THREE.MeshStandardMaterial({color:0xff5511,roughness:.7});
  const baseGeo=new THREE.CylinderGeometry(0.42,0.42,0.06,12);
  const baseMat=new THREE.MeshStandardMaterial({color:0x101010,roughness:.85});
  const positions=[];
  const R_CIRCLE=26,N_CIRCLE=46;
  for(let i=0;i<N_CIRCLE;i++){const a=i*Math.PI*2/N_CIRCLE;positions.push([Math.cos(a)*R_CIRCLE,Math.sin(a)*R_CIRCLE]);}
  for(let i=0;i<12;i++){const side=(i%2===0)?-1:1;positions.push([side*3.5,-100+i*5]);}
  for(let i=0;i<12;i++){const side=(i%2===0)?1:-1;positions.push([side*3.5,45+i*5]);}
  for(let i=0;i<16;i++){const a=i*Math.PI*2/16;positions.push([Math.cos(a)*8,Math.sin(a)*8]);}
  this.cones=new ConeField(this.group,positions,()=>0,coneGeo,coneMat,baseGeo,baseMat);

  const R_EDGE=SIZE/2-6;
  const wallGeo=new THREE.CylinderGeometry(R_EDGE+0.3,R_EDGE+0.3,0.6,64,1,true);
  const wallMat=new THREE.MeshStandardMaterial({color:0x909090,roughness:.6,side:THREE.DoubleSide});
  const wall=new THREE.Mesh(wallGeo,wallMat);wall.position.y=0.3;this.group.add(wall);

  // Fondo lejano, tono gris para acompañar el #606f72
  const farGeo=new THREE.CircleGeometry(600,48);farGeo.rotateX(-Math.PI/2);
  const far=new THREE.Mesh(farGeo,new THREE.MeshLambertMaterial({color:0x2a2d30}));far.position.y=-0.05;this.group.add(far);
 }
 dispose(){this.group.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){if(Array.isArray(o.material))o.material.forEach(m=>{if(m.map&&!m.map.userData.keep)m.map.dispose();m.dispose();});else{if(o.material.map&&!o.material.map.userData.keep)o.material.map.dispose();o.material.dispose();}}});this.scene.remove(this.group);}
}

/* ═══ OFF-ROAD LIBRE: terreno grande y ondulado para pasear, sin vuelta cronometrada ═══ */
/* micro-relieve del piso que siente la suspensión (siempre hacia arriba: la rueda nunca queda bajo la superficie dibujada) */
const BUMP_AMP={asphalt:0.005,dirt:0.03,shoulder:0.035,grass:0.045,outside:0.05,mud:0.03,gravel:0.035};
/* ondas largas (7–30 m) con poco rizado corto: la cubierta "envuelve" lo chico, la suspensión trabaja con lo grande */
function microBump(x,z,surf){if(window.__NOBUMP)return 0;const A=BUMP_AMP[surf]??0.03;const n=Math.sin(x*0.71+z*0.53)*Math.sin(x*0.29-z*0.83+1.3)*0.6+Math.sin(x*1.9+z*1.3+0.7)*0.15+Math.sin(x*0.17+z*0.13+2.1)*0.25;return A*(0.5+0.5*n);}
/* orienta cada triángulo hacia arriba (franjas que se pliegan en curvas cerradas) */
function upFacing(P,I){for(let t=0;t<I.length;t+=3){const a=I[t]*3,b=I[t+1]*3,c=I[t+2]*3;const ux=P[b]-P[a],uz=P[b+2]-P[a+2],vx=P[c]-P[a],vz=P[c+2]-P[a+2];if(uz*vx-ux*vz<0){const k=I[t+1];I[t+1]=I[t+2];I[t+2]=k;}}}
function smoothstep01(e0,e1,x){const t=clamp((x-e0)/(e1-e0),0,1);return t*t*(3-2*t);}
class OffroadTrack{
 constructor(scene){
  this.scene=scene;this.kind='offroad';this.mode='dirt';this.lapEnabled=false;
  this.halfWidth=9999;this.shoulder=0;
  this.samples=[new THREE.Vector3(0,0,40)];
  this.tangents=[new THREE.Vector3(0,0,-1)];
  this.laterals=[new THREE.Vector3(1,0,0)];
  this.cum=[0,0];this.tapeNodes=[];
  this._n={dist:0,idx:0,t:0,y:0,lateral:0,tan:this.tangents[0],lat:this.laterals[0]};
  this._gi={y:0,surf:'dirt'};
  this.mudPatches=[{x:-120,z:-140,r:38},{x:200,z:220,r:32}];
  /* bases de los rivales (duelos): campo limpio y, en alguna, rampa de saltos */
  this.bases=DUEL_RIVALS.map(r=>({x:r.x,z:r.z,r:r.ramp?58:34}));this.ramps=DUEL_RIVALS.filter(r=>r.ramp).map(r=>({...r.ramp,x:r.x,z:r.z}));
  this.roads=[
   {surf:'asphalt',halfW:4.5,pts:[[-380,-320],[-200,-180],[-40,-40],[120,60],[260,180],[380,300]]},
   {surf:'dirtroad',halfW:3.6,pts:[[-380,260],[-220,140],[-60,20],[80,-80],[240,-200],[380,-320]]}
  ];
  for(const road of this.roads)this.prepRoad(road);this.levelCrossings();
  this.group=new THREE.Group();scene.add(this.group);
  this.build();
 }
 /* camino denso (cada ~3 m) con altura suavizada: sin quiebres de pendiente que hagan volar el auto */
 prepRoad(road){const c=this.chaikin(road.pts,3);const pts=[];for(let i=0;i<c.length-1;i++){const a=c[i],b=c[i+1],L=Math.hypot(b[0]-a[0],b[1]-a[1]),n=Math.max(1,Math.ceil(L/3));for(let k=0;k<n;k++){const t=k/n;pts.push([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t]);}}pts.push(c[c.length-1]);
  let y=pts.map(p=>this.naturalHillY(p[0],p[1]));for(const W of [14,14,10]){const o=y.slice();for(let i=0;i<y.length;i++){let s=0,n=0;for(let j=-W;j<=W;j++){const k=i+j;if(k<0||k>=y.length)continue;s+=y[k];n++;}o[i]=s/n;}y=o;}
  road.pts=pts;road.baseY=y;
  /* grilla espacial de segmentos (celdas de 16 m) */
  const G=road.grid=new Map(),CS=16;for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];const x0=Math.floor(Math.min(a[0],b[0])/CS),x1=Math.floor(Math.max(a[0],b[0])/CS),z0=Math.floor(Math.min(a[1],b[1])/CS),z1=Math.floor(Math.max(a[1],b[1])/CS);for(let gx=x0;gx<=x1;gx++)for(let gz=z0;gz<=z1;gz++){const k=gx*100003+gz;let l=G.get(k);if(!l)G.set(k,l=[]);l.push(i);}}}
 /* cruces de caminos: los dos a la misma altura en el cruce (antes quedaba una loma que hacía volar el auto) */
 levelCrossings(){const R=this.roads;for(let a=0;a<R.length;a++)for(let b=a+1;b<R.length;b++){const A=R[a].pts,B=R[b].pts;
  for(let i=0;i<A.length-1;i++)for(let j=0;j<B.length-1;j++){const p=A[i],q=A[i+1],r=B[j],t=B[j+1];const d1x=q[0]-p[0],d1z=q[1]-p[1],d2x=t[0]-r[0],d2z=t[1]-r[1],den=d1x*d2z-d1z*d2x;if(Math.abs(den)<1e-9)continue;
   const u=((r[0]-p[0])*d2z-(r[1]-p[1])*d2x)/den,v=((r[0]-p[0])*d1z-(r[1]-p[1])*d1x)/den;if(u<0||u>1||v<0||v>1)continue;
   const ya=R[a].baseY[i]+(R[a].baseY[i+1]-R[a].baseY[i])*u,yb=R[b].baseY[j]+(R[b].baseY[j+1]-R[b].baseY[j])*v,y=(ya+yb)/2;
   for(const [rd,k0,y0] of [[R[a],i,ya],[R[b],j,yb]]){const P=rd.pts;let acc=0;for(const st of [1,-1]){acc=0;for(let k=k0+(st>0?1:0);k>=0&&k<P.length;k+=st){const w=0.5+0.5*Math.cos(Math.PI*Math.min(1,acc/60));rd.baseY[k]+=(y-y0)*w;const n=k+st;if(n<0||n>=P.length||acc>60)break;acc+=Math.hypot(P[n][0]-P[k][0],P[n][1]-P[k][1]);}}}}}}
 chaikin(pts,iterations){let cur=pts.map(p=>[p[0],p[1]]);for(let it=0;it<iterations;it++){const next=[cur[0]];for(let i=0;i<cur.length-1;i++){const a=cur[i],b=cur[i+1];next.push([a[0]*0.75+b[0]*0.25,a[1]*0.75+b[1]*0.25]);next.push([a[0]*0.25+b[0]*0.75,a[1]*0.25+b[1]*0.75]);}next.push(cur[cur.length-1]);cur=next;}return cur;}
 naturalHillY(x,z){return 2+7*Math.sin(x*0.012+0.4)*Math.cos(z*0.010-0.3)+3*Math.sin(x*0.03-z*0.025+1.7)+1.2*Math.sin(x*0.07+z*0.065+3.1)
  +5*Math.exp(-((x-160)*(x-160)+(z-90)*(z-90))/2200)+4*Math.exp(-((x+140)*(x+140)+(z-220)*(z-220))/1800)+4.5*Math.exp(-((x-60)*(x-60)+(z+200)*(z+200))/2000);}
 distToRoad(x,z,road){let best=Infinity,roadY=0;const pts=road.pts,CS=16,gx=Math.floor(x/CS),gz=Math.floor(z/CS);const seen=this._seen||(this._seen=new Set());seen.clear();
  for(let ox=-1;ox<=1;ox++)for(let oz=-1;oz<=1;oz++){const l=road.grid.get((gx+ox)*100003+gz+oz);if(!l)continue;for(const i of l){if(seen.has(i))continue;seen.add(i);const a=pts[i],b=pts[i+1];
   const abx=b[0]-a[0],abz=b[1]-a[1],apx=x-a[0],apz=z-a[1],den=abx*abx+abz*abz;
   const t=den?clamp((apx*abx+apz*abz)/den,0,1):0;const px=a[0]+abx*t,pz=a[1]+abz*t;const d=Math.hypot(x-px,z-pz);
   if(d<best){best=d;roadY=road.baseY[i]+(road.baseY[i+1]-road.baseY[i])*t;}}}
  return {dist:best,roadY};}
 roadInfluence(x,z){let best=Infinity,surf=null;
  for(const road of this.roads){const r=this.distToRoad(x,z,road);if(r.dist<best){best=r.dist;surf=road.surf;}}
  return {dist:best,surf};}
 groundY(x,z){const natural=this.naturalHillY(x,z);let maxT=0,sumW=0,sumWY=0;
  for(const road of this.roads){const r=this.distToRoad(x,z,road);const t=1-smoothstep01(road.halfW+0.3,road.halfW+20,r.dist);
   if(t>maxT)maxT=t;if(t>0){sumW+=t;sumWY+=r.roadY*t;}}
  if(sumW<=0)return natural;
  return natural*(1-maxT)+(sumWY/sumW)*maxT;}
 /* entrada a La Trinchera: boca de mina al final del camino de tierra */
 buildPortal(){const road=this.roads[1],P=road.pts,n=P.length;let acc=0,k=n-1;while(k>1&&acc<45){acc+=Math.hypot(P[k][0]-P[k-1][0],P[k][1]-P[k-1][1]);k--;}
  const a=P[k],b=P[Math.min(n-1,k+3)];let tx=b[0]-a[0],tz=b[1]-a[1];const tl=Math.hypot(tx,tz)||1;tx/=tl;tz/=tl;const x=a[0],z=a[1],y=this.groundY(x,z),yaw=Math.atan2(tx,tz);
  this.portal={x,z,tx,tz,exit:{x:x-tx*18,z:z-tz*18,yaw:Math.atan2(-tx,-tz)}};
  const G=new THREE.Group();G.position.set(x,y,z);G.rotation.y=yaw;this.group.add(G);
  const rock=new THREE.MeshStandardMaterial({color:0x8a7c6a,roughness:1,flatShading:true});
  const mound=new THREE.Mesh(new THREE.DodecahedronGeometry(1,1),rock);mound.scale.set(16,8,13);mound.position.set(0,1.5,13);G.add(mound);
  for(const [sx,sz,r] of [[-9,6,5],[9,7,6],[-4,15,7],[6,17,6]]){const m=new THREE.Mesh(new THREE.DodecahedronGeometry(r,0),rock);m.position.set(sx,r*0.35,sz);m.rotation.set(sx,sz,r);G.add(m);}
  const hole=new THREE.Mesh(new THREE.CircleGeometry(4.2,24,0,Math.PI),new THREE.MeshBasicMaterial({color:0x050505}));hole.scale.set(1.15,1.2,1);hole.position.set(0,0.02,-0.9);hole.rotation.y=Math.PI;G.add(hole);
  const wood=new THREE.MeshLambertMaterial({color:0x5b3e22});for(const sd of [-1,1]){const post=new THREE.Mesh(new THREE.BoxGeometry(0.5,5.6,0.5),wood);post.position.set(sd*4.9,2.8,-1.1);G.add(post);}
  const beam=new THREE.Mesh(new THREE.BoxGeometry(11,0.6,0.6),wood);beam.position.set(0,5.7,-1.1);G.add(beam);
  const sg=canvasTex(512,96,(c,w,h)=>{c.fillStyle='#2b1c10';c.fillRect(0,0,w,h);c.strokeStyle='#e0a040';c.lineWidth=6;c.strokeRect(6,6,w-12,h-12);c.fillStyle='#f5c26b';c.font='900 56px system-ui,sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('⛏ LA TRINCHERA',w/2,h/2+2);});
  const sign=new THREE.Mesh(new THREE.PlaneGeometry(8,1.5),new THREE.MeshBasicMaterial({map:sg,side:THREE.DoubleSide}));sign.position.set(0,6.9,-1.3);sign.rotation.y=Math.PI;G.add(sign);
  const beacon=new THREE.Mesh(new THREE.CylinderGeometry(3,3,60,16,1,true),new THREE.MeshBasicMaterial({color:0xffa24a,transparent:true,opacity:0.12,depthWrite:false}));beacon.position.set(0,30,-2);G.add(beacon);}
 /* color de pasto con ruido suave (sin "tablero" de vértices) y barro con borde difuso */
 terrainColor(x,z){let mud=0;for(const m of this.mudPatches)mud=Math.max(mud,1-smoothstep01(m.r-10,m.r+4,Math.hypot(x-m.x,z-m.z)));
  const nz=0.5+0.5*Math.sin(x*0.021+z*0.017)*Math.cos(x*0.013-z*0.024),dry=0.5+0.5*Math.sin(x*0.006-z*0.009+1.1);
  const C=this._tc||(this._tc=[new THREE.Color(0x7c7a4a),new THREE.Color(0x4f6436),new THREE.Color(0x4a3a26)]);return new THREE.Color(0x5d6e3f).lerp(C[0],dry*0.45).lerp(C[1],nz*0.35).lerp(C[2],mud);}
 nearest(){return this._n;}
 rampY(x,z){let y=0;for(const R of this.ramps)y=Math.max(y,rampHeight(R,x,z));return y;}
 groundInfo(x,z){const o=this._gi;o.y=this.groundY(x,z);const rp=this.ramps.length?this.rampY(x,z):0;if(rp>0.02){o.y+=rp;o.surf='asphalt';return o;}const info=this.roadInfluence(x,z);
  const road=info.surf?this.roads.find(r=>r.surf===info.surf):null;
  if(road&&info.dist<=road.halfW)o.surf=info.surf==='dirtroad'?'dirt':'asphalt';
  else{o.surf='dirt';for(const m of this.mudPatches){if(Math.hypot(x-m.x,z-m.z)<m.r){o.surf='mud';break;}}}
  o.y+=microBump(x,z,o.surf==='dirt'&&!(road&&info.dist<=road.halfW)?'grass':o.surf);return o;}
 ground(x,z){return this.groundY(x,z)+(this.ramps.length?this.rampY(x,z):0);}
 surface(x,z){return this.groundInfo(x,z).surf;}
 updateTape(){}
 /* calzada + banquinas densas que copian exactamente groundY (lo mismo que pisa la física) */
 buildRoadMesh(road,ri){const pts=road.pts,N=pts.length,hw=road.halfW,EXT=14.5;
  const lanes=[0,0.5,1];const sh=[0,0.12,0.3,0.55,0.8,1];/* fracciones de la banquina */
  const P=[],UV=[],IDX=[],SP=[],SC=[],SIDX=[];const asph=road.surf==='asphalt';
  const cRoad=new THREE.Color(asph?0x55585c:0x7a6045),cGrass=new THREE.Color(0x5d6e3f),cDirt=new THREE.Color(asph?0x7a6a52:0x6e5a40);let along=0;
  for(let i=0;i<N;i++){const a=pts[i],prev=pts[Math.max(0,i-1)],next=pts[Math.min(N-1,i+1)];let tx=next[0]-prev[0],tz=next[1]-prev[1];const tl=Math.hypot(tx,tz)||1;tx/=tl;tz/=tl;const lx=-tz,lz=tx;
   if(i>0)along+=Math.hypot(a[0]-pts[i-1][0],a[1]-pts[i-1][1]);
   for(const sd of [-1,1])for(const f of lanes){if(sd===1&&f===0)continue;const o=sd*f*hw,x=a[0]+lx*o,z=a[1]+lz*o;P.push(x,this.groundY(x,z)+0.035,z);UV.push(0.5+sd*f*0.5,along/8);}
   for(const sd of [-1,1])for(const f of sh){const o=sd*(hw+f*EXT),x=a[0]+lx*o,z=a[1]+lz*o;SP.push(x,this.groundY(x,z)+0.02,z);const gc=this.terrainColor(x,z);const c=f<0.12?cDirt.clone():f<0.5?cDirt.clone().lerp(gc,(f-0.12)/0.38):gc;c.offsetHSL(0,0,(Math.random()-.5)*0.03);SC.push(c.r,c.g,c.b);}}
  /* orden por fila: -1(f=0,.5,1) , +1(.5,1) → 5 vértices: [-hw..0..+hw] reordenados */
  const RW=5,ord=[2,1,0,3,4];/* índices dentro de la fila: -1f0=0(centro) -1f.5=1 -1f1=2 +1f.5=3 +1f1=4 → de izq a der: 2,1,0,3,4 */
  for(let i=0;i<N-1;i++)for(let k=0;k<RW-1;k++){const a=i*RW+ord[k],b=i*RW+ord[k+1],c=(i+1)*RW+ord[k],d=(i+1)*RW+ord[k+1];IDX.push(a,b,c,b,d,c);}
  const SW=sh.length;for(const side of [0,1])for(let i=0;i<N-1;i++)for(let k=0;k<SW-1;k++){const base=side*SW;const a=i*SW*2+base+k,b=a+1,c=a+SW*2,d=c+1;if(side)SIDX.push(a,b,c,b,d,c);else SIDX.push(a,c,b,b,c,d);}
  upFacing(P,IDX);upFacing(SP,SIDX);const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(P,3));g.setAttribute('uv',new THREE.Float32BufferAttribute(UV,2));g.setIndex(IDX);g.computeVertexNormals();
  const tex=document.createElement('canvas');tex.width=256;tex.height=512;const c=tex.getContext('2d');
  if(asph){c.fillStyle='#3b3e42';c.fillRect(0,0,256,512);for(let i=0;i<9000;i++){const q=42+Math.random()*40;c.fillStyle=`rgb(${q},${q},${q+2})`;c.fillRect(Math.random()*256,Math.random()*512,1.2,1.2);}
   for(let i=0;i<14;i++){c.fillStyle='rgba(18,20,24,.16)';c.beginPath();c.ellipse(Math.random()*256,Math.random()*512,18+Math.random()*30,30+Math.random()*60,0,0,7);c.fill();}
   c.fillStyle='rgba(236,236,228,.85)';c.fillRect(8,0,7,512);c.fillRect(241,0,7,512);c.fillStyle='rgba(240,240,232,.9)';c.fillRect(125,0,6,300);}
  else{c.fillStyle='#6b5138';c.fillRect(0,0,256,512);for(let i=0;i<12000;i++){const q=70+Math.random()*55;c.fillStyle=`rgb(${q},${q*0.82},${q*0.6})`;c.fillRect(Math.random()*256,Math.random()*512,1.5,1.5);}
   c.fillStyle='rgba(40,30,20,.28)';for(const x of [70,186])for(let y=0;y<512;y+=3)c.fillRect(x+Math.sin(y*.04)*5-14,y,28,2);}
  const t=new THREE.CanvasTexture(tex);t.colorSpace=THREE.SRGBColorSpace;t.wrapS=t.wrapT=THREE.RepeatWrapping;t.anisotropy=4;
  const rm=new THREE.Mesh(g,new THREE.MeshLambertMaterial({map:t,polygonOffset:true,polygonOffsetFactor:asph?-4:-3,polygonOffsetUnits:asph?-4:-3}));rm.receiveShadow=true;rm.renderOrder=asph?2:1;this.group.add(rm);
  const sg=new THREE.BufferGeometry();sg.setAttribute('position',new THREE.Float32BufferAttribute(SP,3));sg.setAttribute('color',new THREE.Float32BufferAttribute(SC,3));sg.setIndex(SIDX);sg.computeVertexNormals();
  const sm=new THREE.Mesh(sg,new THREE.MeshLambertMaterial({vertexColors:true,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1}));sm.receiveShadow=true;this.group.add(sm);}
 build(){
  const SZ=900,R=150;const pos=[],col=[],idx=[];
  for(let iz=0;iz<=R;iz++){const z=lerp(-SZ/2,SZ/2,iz/R);for(let ix=0;ix<=R;ix++){const x=lerp(-SZ/2,SZ/2,ix/R);const rd=this.roadInfluence(x,z).dist,rw=rd<10.5?1:0;/* bajo la calzada/banquina el terreno se hunde: nunca asoma por encima */const y=this.groundY(x,z)-rw*0.45;pos.push(x,y,z);
   const cc=this.terrainColor(x,z);cc.offsetHSL(0,0,(Math.random()-.5)*.03);col.push(cc.r,cc.g,cc.b);}}
  for(let iz=0;iz<R;iz++)for(let ix=0;ix<R;ix++){const a=iz*(R+1)+ix,b=a+1,c=a+R+1,d=c+1;idx.push(a,c,b,b,c,d);}
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute(pos,3));g.setAttribute('color',new THREE.Float32BufferAttribute(col,3));g.setIndex(idx);g.computeVertexNormals();
  this.group.add(terrainMesh(g));
  this.roads.forEach((r,i)=>this.buildRoadMesh(r,i));
  this.buildPortal();
  const rndAway=()=>{let x,z;do{x=Math.random()*SZ-SZ/2;z=Math.random()*SZ-SZ/2;}while(Math.hypot(x,z-40)<32||this.roadInfluence(x,z).dist<9||this.bases.some(b=>Math.hypot(x-b.x,z-b.z)<b.r));return [x,z];};
  const rockGeo=new THREE.DodecahedronGeometry(.6,0),rockMat=new THREE.MeshStandardMaterial({color:0x77736b,roughness:1});const rocks=new THREE.InstancedMesh(rockGeo,rockMat,220);
  const bushGeo=new THREE.IcosahedronGeometry(.7,0),bushMat=new THREE.MeshStandardMaterial({color:0x3a5c34,roughness:1});const bushes=new THREE.InstancedMesh(bushGeo,bushMat,160);
  const trunkGeo=new THREE.CylinderGeometry(.18,.25,2.6,6),trunkMat=new THREE.MeshStandardMaterial({color:0x5a3f28,roughness:1});
  const crownGeo=pineGeo(),crownMat=pineMat();
  const TREE=Math.round(180*QF());const trunks=new THREE.InstancedMesh(trunkGeo,trunkMat,TREE),crowns=new THREE.InstancedMesh(crownGeo,crownMat,TREE);
  const d=new THREE.Object3D();
  for(let i=0;i<220;i++){const [x,z]=rndAway(),y=this.groundY(x,z);d.position.set(x,y+.3,z);d.scale.setScalar(.4+Math.random()*1.3);if(d.scale.x>0.85)addCollider(this,x,z,0.5*d.scale.x);d.rotation.set(Math.random(),Math.random(),Math.random());d.updateMatrix();rocks.setMatrixAt(i,d.matrix);}
  for(let i=0;i<160;i++){const [x,z]=rndAway(),y=this.groundY(x,z);d.position.set(x,y+.45,z);d.scale.set(.8+Math.random()*1.5,.65+Math.random()*1.2,.8+Math.random()*1.5);d.rotation.set(0,0,0);d.updateMatrix();bushes.setMatrixAt(i,d.matrix);}
  for(let i=0;i<TREE;i++){const [x,z]=rndAway();const y=this.groundY(x,z);const sc=0.7+Math.random()*0.8;
   d.position.set(x,y+1.3*sc,z);d.scale.setScalar(sc);d.rotation.set(0,Math.random()*6,0);d.updateMatrix();trunks.setMatrixAt(i,d.matrix);addCollider(this,x,z,0.28*sc);
   d.position.set(x,y+3.4*sc,z);d.scale.setScalar(sc);d.rotation.set(0,Math.random()*6,0);d.updateMatrix();crowns.setMatrixAt(i,d.matrix);}
  rocks.instanceMatrix.needsUpdate=true;bushes.instanceMatrix.needsUpdate=true;trunks.instanceMatrix.needsUpdate=true;crowns.instanceMatrix.needsUpdate=true;
  tintInstances(crowns);tintInstances(bushes,0.08);
  this.group.add(rocks,bushes,trunks,crowns);
  this.group.add(grassField(Math.round(1800*QF()),()=>{const x=Math.random()*SZ-SZ/2,z=Math.random()*SZ-SZ/2;return [x,this.groundY(x,z),z];}));
 }
 dispose(){this.group.traverse(o=>{if(o.isInstancedMesh){o.geometry.dispose();o.material.dispose();return}if(o.geometry)o.geometry.dispose();if(o.material){if(o.material.map&&!o.material.map.userData.keep)o.material.map.dispose();o.material.dispose();}});this.scene.remove(this.group);}
}

/* ═══ ESTACIONAMIENTO: cochera angosta ajustada al ancho del vehículo elegido, con check al lograrlo ═══ */
class ParkingTrack{
 constructor(scene){
  this.scene=scene;this.kind='parking';this.mode='asphalt';this.lapEnabled=false;
  this.halfWidth=9999;this.shoulder=0;
  const carW=VEH.trackF+0.6,carL=VEH.wheelBase+1.8;
  this.bay={x:0,z:0,heading:0,halfW:carW*0.62,halfL:carL*0.58};
  const spawnDist=carL*2.4;
  this.samples=[new THREE.Vector3(spawnDist*0.30,0,spawnDist)];
  this.tangents=[new THREE.Vector3(-0.35,0,-0.94).normalize()];
  this.laterals=[new THREE.Vector3().crossVectors(this.tangents[0],new THREE.Vector3(0,1,0)).normalize()];
  this.cum=[0,0];this.tapeNodes=[];
  this._n={dist:0,idx:0,t:0,y:0,lateral:0,tan:this.tangents[0],lat:this.laterals[0]};
  this._gi={y:0,surf:'asphalt'};
  this.group=new THREE.Group();scene.add(this.group);
  this.build(carW,carL);
 }
 nearest(){return this._n;}
 groundInfo(){const o=this._gi;o.y=0;o.surf='asphalt';return o;}
 ground(){return 0;}
 surface(){return 'asphalt';}
 updateTape(){}
 checkParked(px,pz,yaw,speed){
  const b=this.bay,dx=px-b.x,dz=pz-b.z,ch=Math.cos(-b.heading),sh=Math.sin(-b.heading);
  const lx=dx*ch-dz*sh,lz=dx*sh+dz*ch;
  const inPos=Math.abs(lx)<(b.halfW-0.12)&&Math.abs(lz)<(b.halfL-0.18);
  const dAng=Math.atan2(Math.sin(yaw-b.heading),Math.cos(yaw-b.heading));
  const dAng180=Math.atan2(Math.sin(dAng+Math.PI),Math.cos(dAng+Math.PI));
  const angOk=Math.abs(dAng)<0.17||Math.abs(dAng180)<0.17;
  return inPos&&angOk&&Math.abs(speed)<0.35;
 }
 build(carW,carL){
  const LOT=40;
  const cvs=document.createElement('canvas');cvs.width=cvs.height=1024;const ctx=cvs.getContext('2d');
  const SCALE=1024/LOT,CX=512,CZ=512;
  ctx.fillStyle='#54585c';ctx.fillRect(0,0,1024,1024);
  for(let i=0;i<50000;i++){const q=68+Math.random()*28;ctx.fillStyle=`rgb(${q},${q},${q+3})`;ctx.fillRect(Math.random()*1024,Math.random()*1024,1.2,1.2);}
  const bw=this.bay.halfW,bl=this.bay.halfL;
  ctx.strokeStyle='#f4d13a';ctx.lineWidth=0.12*SCALE;
  ctx.strokeRect(CX-bw*SCALE,CZ-bl*SCALE,bw*2*SCALE,bl*2*SCALE);
  ctx.save();ctx.translate(CX,CZ-bl*SCALE-0.55*SCALE);ctx.fillStyle='#f4d13a';ctx.font=`bold ${0.9*SCALE}px sans-serif`;ctx.textAlign='center';ctx.fillText('P',0,0);ctx.restore();
  const tex=new THREE.CanvasTexture(cvs);tex.colorSpace=THREE.SRGBColorSpace;
  const geo=new THREE.PlaneGeometry(LOT,LOT,1,1);geo.rotateX(-Math.PI/2);
  this.group.add(new THREE.Mesh(geo,new THREE.MeshLambertMaterial({map:tex})));
  const dummyMat=new THREE.MeshStandardMaterial({color:0x2e3238,roughness:0.6});
  const dummyGeo=new THREE.BoxGeometry(carW*0.92,1.3,carL*0.92);
  this.obstacles=[];for(const side of [-1,1]){const car=new THREE.Mesh(dummyGeo,dummyMat);car.position.set(side*(bw+carW*0.46),0.65,0);this.group.add(car);this.obstacles.push({x:side*(bw+carW*0.46),z:0,hw:carW*0.46,hl:carL*0.46});}
  const wall=new THREE.Mesh(new THREE.BoxGeometry(bw*2+carW*1.4,0.5,0.4),new THREE.MeshStandardMaterial({color:0x8a8f94}));
  wall.position.set(0,0.25,-(bl+0.5));this.group.add(wall);this.obstacles.push({x:0,z:-(bl+0.5),hw:bw+carW*0.7,hl:0.2});
  const far=new THREE.Mesh(new THREE.CircleGeometry(400,40),new THREE.MeshLambertMaterial({color:0x3a3d40}));far.rotation.x=-Math.PI/2;far.position.y=-0.05;this.group.add(far);
 }
 dispose(){this.group.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){if(o.material.map&&!o.material.map.userData.keep)o.material.map.dispose();o.material.dispose();}});this.scene.remove(this.group);}
}

/* colisionadores estáticos (árboles, rocas) en grilla espacial de 12 m */
function addCollider(o,x,z,r){if(!o.colliders)o.colliders=new Map();const k=Math.floor(x/12)+','+Math.floor(z/12);let a=o.colliders.get(k);if(!a)o.colliders.set(k,a=[]);a.push([x,z,r]);}
/* pinos con 3 niveles de copa y variación de color; matas de pasto */
let _pine=null,_grassTex=null;
function pineGeo(){if(_pine)return _pine.clone();const parts=[[1.75,2.0,-0.9],[1.35,1.9,0.25],[0.9,1.7,1.3]].map(([r,h,y],k)=>{const g=new THREE.ConeGeometry(r,h,8,1);g.translate(0,y,0);const c=new Float32Array(g.attributes.position.count*3);for(let i=0;i<g.attributes.position.count;i++){const yy=g.attributes.position.getY(i)-y;const t=(yy/h)+0.5;const v=0.55+0.45*t+k*0.05;c[i*3]=0.16*v;c[i*3+1]=0.36*v;c[i*3+2]=0.15*v;}g.setAttribute('color',new THREE.BufferAttribute(c,3));return g.index?g.toNonIndexed():g;});
 _pine=mergeGeometries(parts,false);_pine.computeVertexNormals();return _pine.clone();}
function pineMat(){return new THREE.MeshStandardMaterial({vertexColors:true,roughness:0.95,color:0xffffff});}
function tintInstances(im,amt){amt=amt||0.12;const c=new THREE.Color();for(let i=0;i<im.count;i++){c.setHSL(0.28+(Math.random()-0.5)*0.08,0.35+Math.random()*0.25,0.62+Math.random()*amt*3-amt);c.r=c.g=c.b=0;c.setRGB(0.8+Math.random()*0.35,0.85+Math.random()*0.3,0.75+Math.random()*0.3);im.setColorAt(i,c);}if(im.instanceColor)im.instanceColor.needsUpdate=true;}
/* recorte con la forma del auto del jugador: pasto y cinta que caen dentro del auto no se dibujan
   (si no, se ven atravesando el habitáculo en las cámaras interiores y de capó) */
const CAR_CUT={uCutInv:{value:new THREE.Matrix4()},uCutHalf:{value:new THREE.Vector3(1,1,2)},uCutOn:{value:0}};
function carCut(m){m.customProgramCacheKey=()=>'carcut';m.onBeforeCompile=sh=>{Object.assign(sh.uniforms,CAR_CUT);
  sh.vertexShader='varying vec3 vCutW;\n'+sh.vertexShader.replace('#include <project_vertex>','#include <project_vertex>\n{vec4 cw=vec4(transformed,1.0);\n#ifdef USE_INSTANCING\ncw=instanceMatrix*cw;\n#endif\nvCutW=(modelMatrix*cw).xyz;}');
  sh.fragmentShader='varying vec3 vCutW;uniform mat4 uCutInv;uniform vec3 uCutHalf;uniform float uCutOn;\n'+sh.fragmentShader.replace('#include <clipping_planes_fragment>','#include <clipping_planes_fragment>\nif(uCutOn>0.5){vec3 lc=(uCutInv*vec4(vCutW,1.0)).xyz;if(abs(lc.x)<uCutHalf.x&&abs(lc.z)<uCutHalf.z&&lc.y>-uCutHalf.y&&lc.y<2.4)discard;}');};return m;}
function grassField(n,place){if(!_grassTex){_grassTex=canvasTex(128,128,(c,w,h)=>{c.clearRect(0,0,w,h);for(let i=0;i<46;i++){const x=10+Math.random()*(w-20),hh=h*(0.45+Math.random()*0.55),lean=(Math.random()-0.5)*26;const g=Math.floor(90+Math.random()*80);c.strokeStyle=`rgb(${Math.floor(g*0.55)},${g},${Math.floor(g*0.35)})`;c.lineWidth=2+Math.random()*2;c.beginPath();c.moveTo(x,h);c.quadraticCurveTo(x+lean*0.3,h-hh*0.6,x+lean,h-hh);c.stroke();}});_grassTex.userData.keep=true;}
 const a=new THREE.PlaneGeometry(1.3,0.75);a.translate(0,0.36,0);const b=a.clone();b.rotateY(Math.PI/2);const geo=mergeGeometries([a,b],false);
 const m=carCut(new THREE.MeshLambertMaterial({map:_grassTex,alphaTest:0.45,side:THREE.DoubleSide,color:0xb8c6a0}));m.userData.keepMap=true;
 const im=new THREE.InstancedMesh(geo,m,n);const d=new THREE.Object3D();for(let i=0;i<n;i++){const [x,y,z]=place();d.position.set(x,y-0.05,z);d.rotation.set(0,Math.random()*3,0);const k=0.6+Math.random()*0.9;d.scale.set(k,k*(0.7+Math.random()*0.6),k);d.updateMatrix();im.setMatrixAt(i,d.matrix);}
 im.instanceMatrix.needsUpdate=true;tintInstances(im,0.1);return im;}
/* terreno: UV de mundo + textura de detalle (pasto/tierra) compartida */
let _detailTex=null;
function terrainMesh(g){const P=g.attributes.position,uv=new Float32Array(P.count*2);for(let i=0;i<P.count;i++){uv[i*2]=P.getX(i)/7;uv[i*2+1]=P.getZ(i)/7;}g.setAttribute('uv',new THREE.BufferAttribute(uv,2));
 if(!_detailTex){_detailTex=canvasTex(256,256,(c,w,h)=>{c.fillStyle='#f0f0f0';c.fillRect(0,0,w,h);for(let i=0;i<9000;i++){const v=200+Math.random()*55;c.fillStyle=`rgb(${v},${v},${v})`;const x=Math.random()*w,y=Math.random()*h;c.fillRect(x,y,1+Math.random()*1.5,2+Math.random()*4);}
  for(let i=0;i<40;i++){c.fillStyle=`rgba(${Math.random()<.5?'80,70,50':'255,255,240'},0.07)`;c.beginPath();c.arc(Math.random()*w,Math.random()*h,10+Math.random()*30,0,7);c.fill();}});_detailTex.wrapS=_detailTex.wrapT=THREE.RepeatWrapping;_detailTex.anisotropy=4;_detailTex.userData.keep=true;}
 const m=new THREE.MeshLambertMaterial({vertexColors:true,map:_detailTex});m.userData.keepMap=true;return new THREE.Mesh(g,m);}
function canvasTex(w,h,draw){const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;return t}
/* ═══ Modelos GLB (Volt Raid): carrocería + rueda, cargados desde models/ ═══ */
const ASSETS={voltBody:null,voltWheel:null,voltBodyLo:null,voltWheelLo:null,genBody:null,genBodyLo:null,genRim:null,genRimLo:null};let ASSET_PROGRESS=0;
const VOLT_META={archR:0.461,archY:0.516,hw:1.206,zf:1.508,zr:-1.392,yb:0.15,belt:1.034,cab0:-1.921,cab1:0.692,H:1.489,R:0.40};
function loadGLB(url){return new Promise(res=>{try{new GLTFLoader().load(url,g=>res(g.scene),undefined,e=>{console.warn('GLB',url,e);res(null)})}catch(e){console.warn(e);res(null)}});}
const _track=pr=>pr.then(v=>{ASSET_PROGRESS++;return v;});
const ASSETS_READY=Promise.all([_track(loadPilot('models/pilot.glb',{helmet:true})),_track(loadGLB('models/volt_body.glb')),_track(loadGLB('models/volt_wheel.glb')),_track(loadGLB('models/volt_body_lo.glb')),_track(loadGLB('models/volt_wheel_lo.glb')),_track(loadGLB('models/genesis_body.glb')),_track(loadGLB('models/genesis_body_lo.glb')),_track(loadGLB('models/genesis_rim.glb')),_track(loadGLB('models/genesis_rim_lo.glb')),_track(loadPilotLo('models/pilot_lo.glb'))]).then(([,b,w,bl,wl,gb,gbl,gr,grl])=>{ASSETS.voltBody=b;ASSETS.voltWheel=w;ASSETS.voltBodyLo=bl||b;ASSETS.voltWheelLo=wl||w;ASSETS.genBody=gb;ASSETS.genBodyLo=gbl||gb;ASSETS.genRim=gr;ASSETS.genRimLo=grl||gr;
});
function glbParts(root){const out={};root.traverse(o=>{if(o.isMesh)out[o.material.name]=o.geometry;});return out;}
/* pintura con decoración naranja dibujada por píxel (bordes nítidos sin importar la malla) */
function voltPaintMaterial(paint){const K=VOLT_META,f=v=>v.toFixed(4);const U={uPaint:{value:new THREE.Color(paint&&paint.body||'#1a4fe0')},uAccent:{value:new THREE.Color(paint&&paint.accent||'#ff6a08')}};
 const m=new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,metalness:0.32,roughness:0.32,envMapIntensity:1.15,side:THREE.DoubleSide});
 m.onBeforeCompile=sh=>{
  sh.uniforms.uPaint=U.uPaint;sh.uniforms.uAccent=U.uAccent;
  sh.vertexShader=sh.vertexShader.replace('#include <common>','#include <common>\nvarying vec3 vOP;').replace('#include <begin_vertex>','#include <begin_vertex>\nvOP=position;');
  sh.fragmentShader=sh.fragmentShader.replace('#include <common>','#include <common>\nvarying vec3 vOP;\nuniform vec3 uPaint;\nuniform vec3 uAccent;\nfloat bnd(float x,float a,float b,float e){return smoothstep(a-e,a+e,x)*(1.0-smoothstep(b-e,b+e,x));}')
   .replace('#include <color_fragment>',`#include <color_fragment>
  if(!gl_FrontFacing)diffuseColor.rgb*=0.07; /* cara interna de la carrocería = habitáculo oscuro */
  {vec3 p=vOP;float ax=abs(p.x);float e=0.010;float o=0.0;
   float d1=length(vec2(p.z-(${f(K.zf)}),p.y-(${f(K.archY)}))),d2=length(vec2(p.z-(${f(K.zr)}),p.y-(${f(K.archY)})));
   float sd=step(${f(0.62*K.hw)},ax)*step(${f(K.archY-0.10)},p.y);
   o=max(o,sd*max(bnd(d1,${f(K.archR*1.05)},${f(K.archR*1.25)},e),bnd(d2,${f(K.archR*1.05)},${f(K.archR*1.25)},e)));
   float mid=step(${f(K.zr+K.archR*1.3)},p.z)*step(p.z,${f(K.zf-K.archR*1.3)})*step(${f(0.8*K.hw)},ax);
   o=max(o,mid*bnd(p.y,${f(K.yb+0.27)},${f(K.yb+0.39)},e));
   float st=bnd(ax,${f(0.17*K.hw-0.065)},${f(0.17*K.hw+0.065)},e);
   float hood=step(${f(K.cab1-0.05)},p.z)*step(${f(K.belt-0.28)},p.y);
   float roof=step(${f(K.H-0.2)},p.y)*step(${f(K.cab0)},p.z)*step(p.z,${f(K.cab1)});
   o=max(o,st*max(hood,roof));
   float paint=smoothstep(0.25,0.45,vColor.b);
   diffuseColor.rgb=mix(diffuseColor.rgb,uPaint,paint);
   diffuseColor.rgb=mix(diffuseColor.rgb,uAccent,o*paint);}`);};
 m.userData.U=U;m.customProgramCacheKey=()=>'voltpaint';
 return m;}
/* el Genesis conceptual (hecho en código) queda guardado: true = volver a usarlo */
const GENESIS_CONCEPT=false;
/* cubierta limpia hecha en código: carcasa torneada + tacos parejos en dos filas intercaladas y hombros (sin las deformidades del modelo) */
const _tireCache=new Map();
function cleanTireGeometry(R,W,rIn,lo){const key=[R,W,rIn,lo].join('_');if(_tireCache.has(key))return _tireCache.get(key);
 const h=R*0.055,rc=R-h,pts=[[rIn,-0.47*W],[rIn+(rc-rIn)*0.45,-0.52*W],[rc-0.03*R,-0.5*W],[rc,-0.42*W],[rc,0.42*W],[rc-0.03*R,0.5*W],[rIn+(rc-rIn)*0.45,0.52*W],[rIn,0.47*W]].map(([r,y])=>new THREE.Vector2(r,y));
 const lathe=new THREE.LatheGeometry(pts,lo?20:44);lathe.rotateZ(-Math.PI/2);const parts=[lathe.toNonIndexed()];
 const nB=lo?0:26,pitch=2*Math.PI/nB,d=new THREE.Object3D();
 const block=(ax,aw,ang,ht,len,tilt)=>{const g=new THREE.BoxGeometry(aw,ht,len);d.position.set(0,0,0);d.rotation.set(0,0,0);d.updateMatrix();
  const m=new THREE.Matrix4().makeRotationX(ang).multiply(new THREE.Matrix4().makeTranslation(ax,rc+ht/2-0.004,0)).multiply(new THREE.Matrix4().makeRotationY(tilt||0));g.applyMatrix4(m);parts.push(g.toNonIndexed());};
 for(let i=0;i<nB;i++){const a=i*pitch,L=pitch*R*0.58;
  block(-0.2*W,0.34*W,a,h,L,0.12);block(0.2*W,0.34*W,a+pitch/2,h,L,-0.12);
  block(-0.43*W,0.14*W,a+pitch/2,h*0.85,L*0.9,0);block(0.43*W,0.14*W,a,h*0.85,L*0.9,0);}
 for(const g of parts){for(const n of Object.keys(g.attributes))if(n!=='position'&&n!=='normal')g.deleteAttribute(n);}
 const geo=mergeGeometries(parts,false);geo.computeVertexNormals();_tireCache.set(key,geo);return geo;}
function helixGeometry(turns,r,tube){const pts=[];const N=turns*14;for(let i=0;i<=N;i++){const t=i/N,a=t*turns*Math.PI*2;pts.push(new THREE.Vector3(Math.cos(a)*r,t-0.5,Math.sin(a)*r));}
 return new THREE.TubeGeometry(new THREE.CatmullRomCurve3(pts),N,tube,5,false);}
class VehicleVisual{
 constructor(type,Vp,opts){this.V=Vp||VEH;this.opts=opts||{};this.type=type||'genesis';this.group=new THREE.Group();this.body=new THREE.Group();this.glassGroup=new THREE.Group();this.body.add(this.glassGroup);this.group.add(this.body);this.wheels=[];this.shocks=[];const V=this.V;this.a=V.wheelBase*(1-V.weightFront);this.b=V.wheelBase*V.weightFront;
  this.mat={paint:new THREE.MeshStandardMaterial({color:0x15181d,metalness:0.55,roughness:0.42,envMapIntensity:1.1}),dark:new THREE.MeshStandardMaterial({color:0x0b0d10,metalness:0.3,roughness:0.7}),trim:new THREE.MeshStandardMaterial({color:0x22262c,metalness:0.6,roughness:0.35}),glass:new THREE.MeshStandardMaterial({color:0x0a1218,metalness:0.2,roughness:0.08,transparent:true,opacity:0.58,depthWrite:false,envMapIntensity:1.6,polygonOffset:true,polygonOffsetFactor:2,polygonOffsetUnits:2}),white:new THREE.MeshBasicMaterial({color:0xeaf6ff}),red:new THREE.MeshBasicMaterial({color:0x661015}),reverse:new THREE.MeshBasicMaterial({color:0x242426}),shock:new THREE.MeshStandardMaterial({color:0xb03a22,metalness:0.5,roughness:0.4}),shaft:new THREE.MeshStandardMaterial({color:0xc9ced6,metalness:0.9,roughness:0.2})};
  this.buildBody();this.buildWheels();this.buildLights();this.body.position.y=-V.comHeight+(V.rideOffset||0);this.applyPaint(this.opts.paint);this.mergeStatic();}
 /* une las piezas fijas de la carrocería por material → muchas menos llamadas de dibujo */
 mergeStatic(){this._merge(this.body);this._merge(this.glassGroup);}
 _merge(root){const skip=new Set();for(const sh of this.shocks)for(const k of ['sh','sf','spring','axle','armF','armB','upF','upB'])if(sh[k])skip.add(sh[k]);
  const byMat=new Map();for(const o of [...root.children]){if(!o.isMesh||o.isInstancedMesh||skip.has(o)||o.userData.shared||o.children.length)continue;const k=o.material.uuid;if(!byMat.has(k))byMat.set(k,[]);byMat.get(k).push(o);}
  for(const [,list] of byMat){if(list.length<2)continue;try{const geos=list.map(o=>{o.updateMatrix();let g=o.geometry.index?o.geometry.toNonIndexed():o.geometry.clone();g.applyMatrix4(o.matrix);for(const n of Object.keys(g.attributes))if(!['position','normal','uv'].includes(n))g.deleteAttribute(n);if(!g.attributes.uv){g.setAttribute('uv',new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count*2),2));}if(!g.attributes.normal)g.computeVertexNormals();return g;});
    const m=mergeGeometries(geos,false);if(!m){geos.forEach(g=>g.dispose());continue;}const mesh=new THREE.Mesh(m,list[0].material);root.add(mesh);for(const o of list){root.remove(o);o.geometry.dispose();}geos.forEach(g=>g.dispose());}catch(e){console.warn('merge',e);}}}
 applyPaint(p){if(!p)return;const M=this.mat;const fin={gloss:[0.25,0.22],metal:[0.62,0.3],matte:[0.08,0.78],chrome:[1,0.06]}[p.finish||'metal'];
  if(M.paint.userData.U){M.paint.userData.U.uPaint.value.set(p.body);M.paint.userData.U.uAccent.value.set(p.accent);M.paint.metalness=fin[0]*0.8;M.paint.roughness=fin[1];}
  else{M.paint.color.set(p.body);M.paint.metalness=fin[0];M.paint.roughness=fin[1];if(p.accent)M.trim.color.set(p.accent);}
  if(this.wheelMats&&p.rim)this.wheelMats.ring.color.set(p.rim);}
 setGlassVisible(v){this.glassGroup.visible=v;}
 buildBody(){if(this.type==='pickup')return this.buildBodyPickup();if(this.type==='truck')return this.buildBodyTruck();if(this.type==='t1plus')return (ASSETS.voltBody&&ASSETS.voltWheel)?this.buildBodyVoltGLB():this.buildBodyT1();return (!GENESIS_CONCEPT&&ASSETS.genBody&&ASSETS.genRim)?this.buildBodyGenesisGLB():this.buildBodyGenesis();}
 buildLights(){if(this.type==='pickup')return this.buildLightsPickup();if(this.type==='truck')return this.buildLightsTruck();if(this.type==='t1plus')return this.glb?this.buildLightsVoltGLB():this.buildLightsT1();return this.glbGen?this.buildLightsGenesisGLB():this.buildLightsGenesis();}
 nameplate(text,y,z){const tx=canvasTex(256,32,(c,w,h)=>{c.clearRect(0,0,w,h);c.fillStyle='#c9ced6';c.font='bold 20px sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText(text,w/2,h/2+1)});const lab=new THREE.Mesh(new THREE.PlaneGeometry(0.62,0.08),new THREE.MeshBasicMaterial({map:tx,transparent:true}));lab.position.set(0,y,z);lab.rotation.y=Math.PI;this.body.add(lab);}
 dispose(){this.group.traverse(o=>{if(o.isInstancedMesh){o.geometry.dispose();if(Array.isArray(o.material))o.material.forEach(m=>m.dispose());else o.material.dispose();return}if(o.geometry&&!o.userData.shared)o.geometry.dispose();if(o.material){const mats=Array.isArray(o.material)?o.material:[o.material];for(const m of mats){if(m.map&&!m.map.userData.keep)m.map.dispose();m.dispose();}}});}
 profileShape(){const s=new THREE.Shape();s.moveTo(2.50,0.64);s.lineTo(2.28,0.52);s.lineTo(-2.30,0.52);s.lineTo(-2.46,0.74);s.lineTo(-2.50,1.06);s.lineTo(-2.38,1.14);s.lineTo(-1.60,1.20);s.lineTo(0.95,1.22);s.lineTo(1.70,1.12);s.lineTo(2.30,1.02);s.lineTo(2.52,0.92);s.lineTo(2.56,0.76);s.lineTo(2.50,0.64);return s;}
 extrude(shape,depth,bevel,mat){const g=new THREE.ExtrudeGeometry(shape,{depth,bevelEnabled:true,bevelThickness:bevel,bevelSize:0.03,bevelSegments:2,curveSegments:14});g.rotateY(-Math.PI/2);g.translate(depth/2,0,0);g.computeVertexNormals();return new THREE.Mesh(g,mat);}
 buildBodyGenesis(){const M=this.mat,B=this.body,a=this.a,b=-this.b,R=this.V.wheelRadius;M.glass.side=THREE.DoubleSide;
  B.add(this.extrude(this.profileShape(),1.40,0.08,M.paint));
  const c=new THREE.Shape();c.moveTo(-2.36,1.13);c.lineTo(-1.25,1.50);c.lineTo(-0.55,1.63);c.lineTo(0.15,1.66);c.lineTo(0.55,1.60);c.lineTo(1.12,1.21);c.lineTo(-2.36,1.13);B.add(this.extrude(c,1.26,0.06,M.paint));
  const ws=new THREE.Mesh(new THREE.PlaneGeometry(1.24,0.70),M.glass);ws.position.set(0,1.43,0.87);ws.rotation.x=-0.97;this.glassGroup.add(ws);
  for(const sd of [-1,1]){const sw=new THREE.Shape();sw.moveTo(-1.05,1.24);sw.lineTo(-0.50,1.55);sw.lineTo(0.18,1.58);sw.lineTo(0.95,1.25);sw.lineTo(-1.05,1.24);const g=new THREE.ShapeGeometry(sw);g.rotateY(-Math.PI/2);const m=new THREE.Mesh(g,M.glass);m.position.x=sd*0.705;this.glassGroup.add(m);}
  const rg=new THREE.Mesh(new THREE.PlaneGeometry(1.0,0.62),M.glass);rg.position.set(0,1.60,-0.90);rg.rotation.x=-1.75;this.glassGroup.add(rg);
  const scoop=new THREE.Mesh(new THREE.BoxGeometry(0.46,0.14,0.62),M.dark);scoop.position.set(0,1.74,0.05);B.add(scoop);
  const scoopF=new THREE.Mesh(new THREE.BoxGeometry(0.40,0.09,0.02),M.trim);scoopF.position.set(0,1.74,0.37);B.add(scoopF);
  const podG=new THREE.CylinderGeometry(0.70,0.70,0.40,22,1,true,Math.PI*0.5-Math.PI*0.64,Math.PI*1.28);podG.rotateZ(Math.PI/2);
  const lipG=new THREE.TorusGeometry(0.70,0.035,6,22,Math.PI*1.28);lipG.rotateZ(Math.PI*0.5-Math.PI*0.64);lipG.rotateY(Math.PI/2);
  const capG=new THREE.RingGeometry(0.5,0.70,22,1,Math.PI*0.5-Math.PI*0.64,Math.PI*1.28);capG.rotateY(Math.PI/2);
  const pm=M.paint.clone();pm.side=THREE.DoubleSide;
  for(const z of [a,b])for(const sd of [-1,1]){const pod=new THREE.Mesh(podG,pm);pod.position.set(sd*0.96,R,z);B.add(pod);const lip=new THREE.Mesh(lipG,M.trim);lip.position.set(sd*1.16,R,z);B.add(lip);const cap=new THREE.Mesh(capG,M.dark);cap.material.side=THREE.DoubleSide;cap.position.set(sd*0.765,R,z);B.add(cap);const fair=new THREE.Mesh(new THREE.BoxGeometry(0.30,0.10,1.0),pm);fair.position.set(sd*0.86,R+0.62,z);fair.rotation.z=-sd*0.25;B.add(fair);}
  const skid=new THREE.Mesh(new THREE.BoxGeometry(1.3,0.08,1.0),M.trim);skid.position.set(0,0.50,2.02);skid.rotation.x=-0.2;B.add(skid);
  const diff=new THREE.Mesh(new THREE.BoxGeometry(1.3,0.22,0.35),M.dark);diff.position.set(0,0.66,-2.36);B.add(diff);
  for(const sd of [-1,1]){const m=new THREE.Mesh(new THREE.BoxGeometry(0.2,0.1,0.14),M.paint);m.position.set(sd*0.84,1.30,0.80);B.add(m)}
  for(const sd of [-1,1]){const e=new THREE.Mesh(new THREE.CylinderGeometry(0.055,0.055,0.14,10),M.trim);e.rotation.x=Math.PI/2;e.position.set(sd*0.32,0.64,-2.50);B.add(e)}}
 buildLightsGenesis(){const M=this.mat,B=this.body;
  for(const sd of [-1,1]){for(const [dy,len] of [[0,0.72],[0.07,0.76]]){const l=new THREE.Mesh(new THREE.BoxGeometry(len,0.024,0.03),M.white);l.position.set(sd*0.39,0.86+dy,2.575);l.rotation.z=sd*0.22;B.add(l);}
   for(const dy of [0,0.06]){const l=new THREE.Mesh(new THREE.BoxGeometry(0.02,0.02,0.55),M.white);l.position.set(sd*0.795,1.0+dy,1.95);B.add(l)}
   const hs=new THREE.Mesh(new THREE.BoxGeometry(0.24,0.24,0.06),M.dark);hs.position.set(sd*0.58,0.70,2.555);B.add(hs);}
  const lamp=new THREE.InstancedMesh(new THREE.BoxGeometry(0.075,0.075,0.03),M.white,8);const d=new THREE.Object3D();let k=0;
  for(const sd of [-1,1])for(const ix of [-1,1])for(const iy of [-1,1]){d.position.set(sd*0.58+ix*0.055,0.70+iy*0.055,2.59);d.updateMatrix();lamp.setMatrixAt(k++,d.matrix)}B.add(lamp);
  for(const dy of [0,0.075]){const l=new THREE.Mesh(new THREE.BoxGeometry(1.46,0.022,0.03),M.red);l.position.set(0,0.98+dy,-2.545);B.add(l)}
  for(const sd of [-1,1])for(const dy of [0,0.06]){const l=new THREE.Mesh(new THREE.BoxGeometry(0.02,0.02,0.45),M.red);l.position.set(sd*0.795,1.02+dy,-1.75);B.add(l)}
  {const r=new THREE.Mesh(new THREE.BoxGeometry(0.30,0.05,0.03),M.reverse);r.position.set(0,0.90,-2.545);B.add(r);}
  this.nameplate('G E N E S I S',1.015,-2.56);}
 addFlares(color){const M=this.mat,V=this.V,R=V.wheelRadius,B=this.body;
  const mat=color?new THREE.MeshStandardMaterial({color,metalness:0.35,roughness:0.6}):M.paint;
  const archG=new THREE.CylinderGeometry(R*1.14,R*1.14,V.tireWidth*1.85,16,1,true,Math.PI*0.06,Math.PI*0.88);archG.rotateZ(Math.PI/2);
  for(const z of [this.a,-this.b])for(const sd of [-1,1]){const arch=new THREE.Mesh(archG,mat);arch.position.set(sd*(V.trackF/2),R*1.03,z);B.add(arch);}}
 /* ═══ PICK-UP: cabina + caja separada, guardabarros anchos ═══ */
 profileShapePickup(){const s=new THREE.Shape();
  s.moveTo(2.40,0.62);s.lineTo(2.20,0.50);s.lineTo(-3.15,0.50);s.lineTo(-3.34,0.56);s.lineTo(-3.34,0.94);s.lineTo(-3.10,0.98);
  s.lineTo(-0.55,0.98);s.lineTo(-0.50,1.58);s.lineTo(1.05,1.62);s.lineTo(1.45,1.56);s.lineTo(1.55,1.05);s.lineTo(2.30,0.98);s.lineTo(2.42,0.80);s.lineTo(2.40,0.62);
  return s;}
 buildBodyPickup(){const M=this.mat,B=this.body;M.glass.side=THREE.DoubleSide;M.paint.color.set(0xb31f24);
  B.add(this.extrude(this.profileShapePickup(),1.42,0.06,M.paint));
  const ws=new THREE.Mesh(new THREE.PlaneGeometry(1.30,0.62),M.glass);ws.position.set(0,1.30,1.30);ws.rotation.x=-1.05;this.glassGroup.add(ws);
  for(const sd of [-1,1]){const sw=new THREE.Shape();sw.moveTo(-0.50,1.00);sw.lineTo(-0.05,1.55);sw.lineTo(0.85,1.58);sw.lineTo(1.45,1.10);sw.lineTo(-0.50,1.00);const g=new THREE.ShapeGeometry(sw);g.rotateY(-Math.PI/2);const m=new THREE.Mesh(g,M.glass);m.position.x=sd*0.72;this.glassGroup.add(m);}
  const rw=new THREE.Mesh(new THREE.PlaneGeometry(1.10,0.55),M.glass);rw.position.set(0,1.32,-0.52);rw.rotation.x=1.15;this.glassGroup.add(rw);
  const bedFloor=new THREE.Mesh(new THREE.BoxGeometry(1.55,0.06,2.75),M.dark);bedFloor.position.set(0,0.52,-1.95);B.add(bedFloor);
  for(const sd of [-1,1]){const rail=new THREE.Mesh(new THREE.BoxGeometry(0.06,0.10,2.75),M.trim);rail.position.set(sd*0.76,0.95,-1.95);B.add(rail);}
  const grille=new THREE.Mesh(new THREE.BoxGeometry(1.15,0.30,0.05),M.dark);grille.position.set(0,0.72,2.40);B.add(grille);
  const bar=new THREE.Mesh(new THREE.BoxGeometry(1.30,0.05,0.20),M.trim);bar.position.set(0,1.68,1.05);B.add(bar);
  for(let i=-2;i<=2;i++){const lp=new THREE.Mesh(new THREE.BoxGeometry(0.05,0.05,0.05),M.white);lp.position.set(i*0.24,1.72,1.05);B.add(lp);}
  for(const sd of [-1,1]){const step=new THREE.Mesh(new THREE.BoxGeometry(0.14,0.06,2.6),M.dark);step.position.set(sd*1.02,0.46,-0.3);B.add(step);}
  this.addFlares(0x121316);}
 buildLightsPickup(){const M=this.mat,B=this.body;
  for(const sd of [-1,1]){const l=new THREE.Mesh(new THREE.BoxGeometry(0.42,0.16,0.03),M.white);l.position.set(sd*0.55,0.85,2.43);B.add(l);
   const t=new THREE.Mesh(new THREE.BoxGeometry(0.10,0.32,0.03),M.red);t.position.set(sd*0.76,0.80,-3.36);B.add(t);}
  {const r=new THREE.Mesh(new THREE.BoxGeometry(0.24,0.10,0.03),M.reverse);r.position.set(0,0.80,-3.36);B.add(r);}
  this.nameplate('T I T A N',0.98,-3.37);}
 /* ═══ CAMIÓN: cabina sobre motor, plataforma trasera larga ═══ */
 profileShapeTruck(){const s=new THREE.Shape();
  s.moveTo(2.42,0.60);s.lineTo(2.42,1.75);s.lineTo(1.50,1.80);s.lineTo(1.20,1.06);s.lineTo(-3.55,1.06);
  s.lineTo(-3.75,1.00);s.lineTo(-3.75,0.55);s.lineTo(2.20,0.50);s.lineTo(2.42,0.60);
  return s;}
 buildBodyTruck(){const M=this.mat,B=this.body;M.glass.side=THREE.DoubleSide;M.paint.color.set(0xe8e6df);M.paint.roughness=0.6;
  B.add(this.extrude(this.profileShapeTruck(),1.75,0.05,M.paint));
  const ws=new THREE.Mesh(new THREE.PlaneGeometry(1.55,0.85),M.glass);ws.position.set(0,1.35,2.30);ws.rotation.x=-1.30;this.glassGroup.add(ws);
  for(const sd of [-1,1]){const sw=new THREE.Mesh(new THREE.PlaneGeometry(0.62,0.62),M.glass);sw.position.set(sd*0.88,1.35,1.60);sw.rotation.y=sd*0.55;this.glassGroup.add(sw);}
  const deck=new THREE.Mesh(new THREE.BoxGeometry(1.95,0.08,5.1),M.dark);deck.position.set(0,1.10,-1.30);B.add(deck);
  for(const dz of [-0.4,-1.9,-3.3]){const drum=new THREE.Mesh(new THREE.CylinderGeometry(0.34,0.34,0.86,14),M.trim);drum.rotation.z=Math.PI/2;drum.position.set(0.55,1.55,dz);B.add(drum);
   const spare=new THREE.Mesh(new THREE.TorusGeometry(0.5,0.16,10,20),M.dark);spare.position.set(-0.85,1.65,dz);B.add(spare);}
  const grille=new THREE.Mesh(new THREE.BoxGeometry(1.55,0.55,0.06),M.dark);grille.position.set(0,0.95,2.44);B.add(grille);
  const bumper=new THREE.Mesh(new THREE.BoxGeometry(1.9,0.28,0.30),M.trim);bumper.position.set(0,0.55,2.55);B.add(bumper);
  const roofBar=new THREE.Mesh(new THREE.BoxGeometry(1.7,0.08,0.22),M.trim);roofBar.position.set(0,1.88,1.35);B.add(roofBar);
  const roundLampG=new THREE.CylinderGeometry(0.075,0.075,0.05,12);
  for(let i=-3;i<=3;i++){const lp=new THREE.Mesh(roundLampG,M.white);lp.rotation.x=Math.PI/2;lp.position.set(i*0.24,1.94,1.40);B.add(lp);}
  for(const sd of [-1,1]){const snorkel=new THREE.Mesh(new THREE.CylinderGeometry(0.06,0.06,1.5,8),M.dark);snorkel.position.set(sd*0.95,1.55,1.9);B.add(snorkel);}
  this.addFlares(0x2a2d31);}
 buildLightsTruck(){const M=this.mat,B=this.body;
  for(const sd of [-1,1]){const l=new THREE.Mesh(new THREE.BoxGeometry(0.30,0.30,0.05),M.white);l.position.set(sd*0.62,0.95,2.46);B.add(l);
   const t=new THREE.Mesh(new THREE.BoxGeometry(0.12,0.40,0.05),M.red);t.position.set(sd*0.90,1.15,-3.78);B.add(t);}
  {const r=new THREE.Mesh(new THREE.BoxGeometry(0.30,0.14,0.05),M.reverse);r.position.set(0,1.15,-3.78);B.add(r);}
  this.nameplate('C O L O S S U S',1.30,-3.79);}
 /* ═══ BUGGY T1+: baja, ancha, alerón trasero grande ═══ */
 profileShapeT1(){const s=new THREE.Shape();
  s.moveTo(2.10,0.58);s.lineTo(1.85,0.50);s.lineTo(-1.95,0.50);s.lineTo(-2.15,0.58);s.lineTo(-2.15,0.80);
  s.lineTo(-1.35,0.98);s.lineTo(-0.45,1.28);s.lineTo(0.05,1.32);s.lineTo(0.55,1.22);s.lineTo(1.15,0.92);s.lineTo(1.85,0.72);s.lineTo(2.10,0.58);
  return s;}
 buildBodyT1(){const M=this.mat,B=this.body;M.glass.side=THREE.DoubleSide;M.paint.color.set(0x1a4fb3);
  B.add(this.extrude(this.profileShapeT1(),1.46,0.05,M.paint));
  const ws=new THREE.Mesh(new THREE.PlaneGeometry(0.95,0.55),M.glass);ws.position.set(0,1.12,0.15);ws.rotation.x=-0.85;this.glassGroup.add(ws);
  for(const sd of [-1,1]){const strut=new THREE.Mesh(new THREE.BoxGeometry(0.06,0.9,0.10),M.trim);strut.position.set(sd*0.62,1.35,-2.05);B.add(strut);}
  const wing=new THREE.Mesh(new THREE.BoxGeometry(1.55,0.05,0.42),M.dark);wing.position.set(0,1.85,-2.10);B.add(wing);
  const wingEnd=new THREE.Mesh(new THREE.BoxGeometry(0.05,0.30,0.42),M.dark);
  for(const sd of [-1,1]){const we=wingEnd.clone();we.position.set(sd*0.78,1.72,-2.10);B.add(we);}
  const scoop=new THREE.Mesh(new THREE.BoxGeometry(0.34,0.16,0.55),M.dark);scoop.position.set(0,1.42,-0.55);B.add(scoop);
  const arm1=new THREE.CylinderGeometry(0.035,0.035,0.9,6);
  for(const z of [this.a,-this.b])for(const sd of [-1,1]){const arm=new THREE.Mesh(arm1,M.trim);arm.rotation.z=Math.PI/2.4*sd;arm.position.set(sd*0.55,this.V.wheelRadius*0.9,z+(z>0?0.35:-0.35));B.add(arm);}
  const nose=new THREE.Mesh(new THREE.BoxGeometry(0.9,0.08,0.05),M.trim);nose.position.set(0,0.60,2.12);B.add(nose);
  this.addFlares();}
 /* Genesis X Skorpio: modelo 3D del usuario (tools/glb/build_genesis.mjs). Blanco = pintura, oscuro = partes negras (colores por vértice) */
 buildBodyGenesisGLB(){const M=this.mat,B=this.body,G=glbParts(this.opts.lo?ASSETS.genBodyLo:ASSETS.genBody);this.glbGen=true;
  M.paint.vertexColors=true;M.paint.needsUpdate=true;
  M.glass=new THREE.MeshStandardMaterial({color:0x6d7f93,vertexColors:true,metalness:0.6,roughness:0.08,envMapIntensity:1.4,transparent:true,opacity:0.8,depthWrite:false,polygonOffset:true,polygonOffsetFactor:2,polygonOffsetUnits:2,side:THREE.DoubleSide});
  const add=(geo,mat,parent)=>{if(!geo)return null;const m=new THREE.Mesh(geo,mat);m.userData.shared=true;parent.add(m);return m;};
  this.shell=add(G.body,M.paint,B);add(G.glass,M.glass,this.glassGroup);}
 buildLightsGenesisGLB(){const M=this.mat,B=this.body,rc=new THREE.Raycaster();
  const stick=(x,y,front,w,h,mat)=>{rc.set(new THREE.Vector3(x,y,front?8:-8),new THREE.Vector3(0,0,front?-1:1));const hit=this.shell&&rc.intersectObject(this.shell,false)[0];if(!hit)return null;
   const n=hit.face.normal.clone();if((n.z>0)!==front)n.negate();n.y*=0.4;n.normalize();const m=new THREE.Mesh(new THREE.PlaneGeometry(w,h),mat);m.position.copy(hit.point).addScaledVector(n,0.02);m.lookAt(this.tmpA.copy(m.position).add(n));B.add(m);return m;};
  this.tmpA=this.tmpA||new THREE.Vector3();
  for(const sd of [-1,1]){stick(sd*0.72,0.62,true,0.30,0.06,M.white);stick(sd*0.62,0.50,true,0.20,0.03,M.white);stick(sd*0.78,0.78,false,0.34,0.05,M.red);stick(sd*0.30,0.62,false,0.14,0.05,M.reverse);}
  stick(0,0.86,false,1.1,0.03,M.red);}
 buildBodyVoltGLB(){const M=this.mat,B=this.body,G=glbParts(this.opts.lo?ASSETS.voltBodyLo:ASSETS.voltBody);this.glb=true;this.cabinOpen=true;
  M.paint.dispose();M.paint=voltPaintMaterial(this.opts.paint);
  M.glass=new THREE.MeshStandardMaterial({color:0x8aa0b8,vertexColors:true,metalness:0.55,roughness:0.10,envMapIntensity:1.2,transparent:true,opacity:0.78,depthWrite:false,polygonOffset:true,polygonOffsetFactor:2,polygonOffsetUnits:2});
  const add=(geo,mat,parent)=>{if(!geo)return null;const m=new THREE.Mesh(geo,mat);m.userData.shared=true;parent.add(m);return m;};
  this.shell=add(G.body,M.paint,B);add(G.glass,M.glass,this.glassGroup);}
 buildLightsVoltGLB(){const M=this.mat,B=this.body,rc=new THREE.Raycaster();
  /* luces "pegadas" a la carrocería: rayo desde adelante/atrás hasta la superficie */
  const stick=(x,y,front,w,h,mat,off=0.03)=>{rc.set(new THREE.Vector3(x,y,front?6:-6),new THREE.Vector3(0,0,front?-1:1));const hit=this.shell&&rc.intersectObjects([this.shell,...this.glassGroup.children],false)[0];if(!hit||(front?hit.point.z<VOLT_META.zf:hit.point.z>VOLT_META.zr))return null;
   const n=hit.face.normal.clone();if((n.z>0)!==front)n.negate();n.y*=0.5;n.normalize();const m=new THREE.Mesh(new THREE.PlaneGeometry(w,h),mat);m.position.copy(hit.point).addScaledVector(n,off);m.lookAt(this.tmpA.copy(m.position).add(n));B.add(m);return m;};
  for(const sd of [-1,1]){stick(sd*0.60,0.80,true,0.34,0.07,M.white);stick(sd*0.62,0.70,true,0.26,0.025,M.white);
   stick(sd*0.74,0.96,false,0.30,0.07,M.red);stick(sd*0.34,0.64,false,0.16,0.05,M.reverse);}
  stick(0,1.02,false,0.9,0.025,M.red);
  stick(0,0.90,false,0.62,0.08,new THREE.MeshBasicMaterial({map:canvasTex(256,32,(c,w,h)=>{c.clearRect(0,0,w,h);c.fillStyle='#e8ecf2';c.font='bold 20px sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('V O L T',w/2,h/2+1)}),transparent:true}));}
 buildLightsT1(){const M=this.mat,B=this.body;
  for(const sd of [-1,1]){const l=new THREE.Mesh(new THREE.BoxGeometry(0.26,0.10,0.03),M.white);l.position.set(sd*0.52,0.72,2.13);B.add(l);
   const t=new THREE.Mesh(new THREE.BoxGeometry(0.08,0.20,0.03),M.red);t.position.set(sd*0.75,1.05,-2.16);B.add(t);}
  {const r=new THREE.Mesh(new THREE.BoxGeometry(0.20,0.08,0.03),M.reverse);r.position.set(0,1.05,-2.16);B.add(r);}
  this.nameplate('V O L T',1.30,-2.17);}
 buildWheels(){const V=this.V,R=V.wheelRadius,M=this.mat;
  const tread=canvasTex(64,256,(c,w,h)=>{c.fillStyle='#15171a';c.fillRect(0,0,w,h);c.fillStyle='#2b2e33';for(let y=0;y<h;y+=16){const o=(y/16)%2?6:0;c.fillRect(4+o,y+2,22,9);c.fillRect(36-o,y+6,22,9)}});
  tread.wrapS=tread.wrapT=THREE.RepeatWrapping;tread.repeat.set(1,3);
  const side=canvasTex(256,256,(c,w,h)=>{const cx=w/2,cy=h/2;c.fillStyle='#16181b';c.fillRect(0,0,w,h);c.fillStyle='#232629';c.beginPath();c.arc(cx,cy,126,0,7);c.fill();c.strokeStyle='rgba(200,205,210,.35)';c.lineWidth=3;for(let i=0;i<14;i++){const a=i*Math.PI/7;c.beginPath();c.arc(cx,cy,104,a,a+0.16);c.stroke()}
   c.fillStyle='#0d0e10';c.beginPath();c.arc(cx,cy,58,0,7);c.fill();c.fillStyle=(this.opts.paint&&this.opts.paint.rim)||'#1c1e21';c.beginPath();c.arc(cx,cy,56,0,7);c.fill();c.fillStyle='#08090a';for(let i=0;i<10;i++){const a=i*Math.PI/5;c.save();c.translate(cx,cy);c.rotate(a);c.fillRect(-5,12,10,36);c.restore()}
   c.fillStyle='#3a3e44';for(let i=0;i<20;i++){const a=i*Math.PI/10;c.beginPath();c.arc(cx+Math.cos(a)*52,cy+Math.sin(a)*52,2,0,7);c.fill()}
   c.fillStyle='#2a2d31';c.beginPath();c.arc(cx,cy,12,0,7);c.fill()});
  const tMat=new THREE.MeshStandardMaterial({map:tread,roughness:0.95,color:0xbbbbbb}),sMat=new THREE.MeshStandardMaterial({map:side,roughness:0.85});
  const geo=new THREE.CylinderGeometry(R,R,V.tireWidth,28,1);geo.rotateZ(Math.PI/2);
  const shockG=new THREE.CylinderGeometry(0.06,0.06,1,8),shaftG=new THREE.CylinderGeometry(0.025,0.025,1,6);
  const W=[[V.trackF/2,this.a,true],[-V.trackF/2,this.a,true],[V.trackR/2,-this.b,false],[-V.trackR/2,-this.b,false]];
  let glbWheel=null;
  if(this.glb){const wg=glbParts(this.opts.lo?ASSETS.voltWheelLo:ASSETS.voltWheel),wm={tire:new THREE.MeshStandardMaterial({color:0x151618,roughness:0.93,metalness:0}),rim:new THREE.MeshStandardMaterial({color:0x2e3238,metalness:0.85,roughness:0.28,envMapIntensity:1.4}),ring:new THREE.MeshStandardMaterial({color:new THREE.Color(this.opts.paint&&this.opts.paint.rim||'#ff6a08'),metalness:0.35,roughness:0.3,envMapIntensity:1.2})};this.wheelMats=wm;
   const k=R/VOLT_META.R;glbWheel=x=>{const g=new THREE.Group();for(const n of ['tire','rim','ring'])if(wg[n]){const m=new THREE.Mesh(wg[n],wm[n]);m.userData.shared=true;g.add(m);}g.scale.set(x<0?-k:k,k,k);return g;};
   M.arm=new THREE.MeshStandardMaterial({color:0x1d2126,metalness:0.6,roughness:0.45});M.axle=new THREE.MeshStandardMaterial({color:0x5a6068,metalness:0.9,roughness:0.3});
   M.spring=new THREE.MeshStandardMaterial({color:0xd4161b,metalness:0.4,roughness:0.35});}
  if(this.glbGen){const rim=this.opts.lo?ASSETS.genRimLo:ASSETS.genRim,rg=glbParts(rim);const rimGeo=rg.rim||Object.values(rg)[0];
   const wm={tire:new THREE.MeshStandardMaterial({color:0x17181a,roughness:0.94,metalness:0}),ring:new THREE.MeshStandardMaterial({color:new THREE.Color(this.opts.paint&&this.opts.paint.rim||'#2a2d33'),metalness:0.85,roughness:0.28,envMapIntensity:1.3})};this.wheelMats=wm;
   const rIn=Math.max(R*0.45,(V.rimRadius||R*0.585)+0.01),rk=rIn/0.585;const tg=cleanTireGeometry(R,V.tireWidth,rIn,!!this.opts.lo);
   glbWheel=x=>{const g=new THREE.Group();const t=new THREE.Mesh(tg,wm.tire);t.userData.shared=true;g.add(t);if(rimGeo){const r=new THREE.Mesh(rimGeo,wm.ring);r.userData.shared=true;r.scale.set(x<0?-rk:rk,rk,rk);g.add(r);}return g;};}
  const full=this.glb&&!this.opts.lo;const springG=full?helixGeometry(7,0.075,0.013):null,rodG=new THREE.CylinderGeometry(1,1,1,8),hubG=new THREE.CylinderGeometry(0.085,0.1,0.09,12);hubG.rotateZ(Math.PI/2);
  for(const [x,z,front] of W){const steer=new THREE.Group();steer.position.set(x,R,z);const spin=new THREE.Group();steer.add(spin);spin.add(glbWheel?glbWheel(x):new THREE.Mesh(geo,[tMat,sMat,sMat]));this.body.add(steer);
   const sh=new THREE.Mesh(shockG,M.shock),sf=new THREE.Mesh(shaftG,M.shaft);if(!this.opts.lo)this.body.add(sh,sf);
   this.wheels.push({steer,spin,front,x,z,omega:0,angle:0});
   const sg=Math.sign(x),S={sh,sf,x,z,sg,top:this.glb?new THREE.Vector3(x-sg*(V.tireWidth/2+0.07),0.92,z-(front?0.05:-0.05)):this.glbGen?new THREE.Vector3(x-sg*(V.tireWidth/2+0.09),0.60,z-(front?0.08:-0.08)):new THREE.Vector3(x*0.74,1.05,z-(front?0.14:-0.14))};
   if(full){const mk=(r,mat)=>{const m=new THREE.Mesh(rodG,mat);m.userData.r=r;this.body.add(m);return m;};
    S.spring=new THREE.Mesh(springG,M.spring);this.body.add(S.spring);
    S.axle=mk(0.032,M.axle);S.armF=mk(0.024,M.arm);S.armB=mk(0.024,M.arm);S.upF=mk(0.02,M.arm);S.upB=mk(0.02,M.arm);
    const hub=new THREE.Mesh(hubG,M.axle);hub.position.x=-sg*(V.tireWidth/2+0.035);steer.add(hub);}
   this.shocks.push(S);}
  this.tmpA=new THREE.Vector3();this.tmpB=new THREE.Vector3();this.tmpC=new THREE.Vector3();this.tmpD=new THREE.Vector3();this.up=new THREE.Vector3(0,1,0);}
 link(m,A,B){const d=this.tmpD.subVectors(B,A),L=d.length()||1e-4;m.position.copy(A).addScaledVector(d,0.5);m.quaternion.setFromUnitVectors(this.up,d.multiplyScalar(1/L));const r=m.userData.r||1;m.scale.set(r,L,r);}
 update(p,dt){this.group.position.set(p.px,p.py,p.pz);this.group.rotation.set(0,0,0);this.group.rotateY(p.yaw);this.group.rotateX(p.pitch);this.group.rotateZ(p.roll);
  const V=this.V,base=V.comHeight+V.hardpointY-(V.rideOffset||0),R0=V.wheelRadius;const wyMax=VOLT_META.archY+VOLT_META.archR-R0-0.02;
  for(let i=0;i<4;i++){const w=this.wheels[i],pw=p.wheels[i];const wy=this.glb?Math.min(base-pw.s,wyMax):base-pw.s;w.steer.position.y=wy;if(w.front)w.steer.rotation.y=p.steerAngle;w.steer.rotation.z=-((w.front?V.camberF:V.camberR)||0)*0.01745*Math.sign(w.x);w.angle+=pw.omega*dt;w.spin.rotation.x=w.angle;
   const s=this.shocks[i];
   if(s.axle){const T=this.tmpA,H=this.tmpB,cz=w.z;const hx=w.x-s.sg*(V.tireWidth/2+0.07);
    this.link(s.axle,T.set(s.sg*0.30,R0,cz),H.set(hx,wy,cz));
    this.link(s.armF,T.set(s.sg*0.40,R0-0.13,cz+0.22),H.set(hx+s.sg*0.02,wy-0.11,cz));this.link(s.armB,T.set(s.sg*0.40,R0-0.13,cz-0.22),H.set(hx+s.sg*0.02,wy-0.11,cz));
    this.link(s.upF,T.set(s.sg*0.46,R0+0.17,cz+0.17),H.set(hx+s.sg*0.01,wy+0.13,cz));this.link(s.upB,T.set(s.sg*0.46,R0+0.17,cz-0.17),H.set(hx+s.sg*0.01,wy+0.13,cz));
    this.link(s.spring,s.top,this.tmpC.lerpVectors(s.top,H.set(hx+s.sg*0.03,wy+0.02,cz),0.72));s.spring.scale.x=s.spring.scale.z=1;}
   const A=this.tmpA.copy(s.top),Bv=this.tmpB.set(s.axle?w.x-s.sg*(V.tireWidth/2+0.045):w.x*0.86,wy+(s.axle?0.02:0.06),w.z);const len=A.distanceTo(Bv);const mid=A.add(Bv).multiplyScalar(0.5);s.sh.position.copy(mid);s.sf.position.copy(mid);
   const dir=this.tmpB.sub(s.top).normalize();s.sh.quaternion.setFromUnitVectors(this.up,dir);s.sf.quaternion.copy(s.sh.quaternion);s.sh.scale.set(1,len*0.55,1);s.sf.scale.set(1,len,1);s.sh.position.addScaledVector(dir,-len*0.2);}
  const braking=clamp((p.brake||0)*1.3,0,1);this.mat.red.color.setRGB(0.40+0.60*braking,0.06+0.09*braking,0.08+0.02*braking);
  const reversing=p.gear===-1?1:0;this.mat.reverse.color.setRGB(0.14+0.74*reversing,0.14+0.74*reversing,0.15+0.75*reversing);}}
class Effects{
 constructor(scene){this.N=220;const N=this.N;this.pos=new Float32Array(N*3);this.col=new Float32Array(N*3);this.alpha=new Float32Array(N);this.size=new Float32Array(N);this.vel=new Float32Array(N*3);this.life=new Float32Array(N);this.max=new Float32Array(N);this.grow=new Float32Array(N);this.grav=new Float32Array(N);this.a0=new Float32Array(N);
  const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.BufferAttribute(this.pos,3));g.setAttribute('color',new THREE.BufferAttribute(this.col,3));g.setAttribute('alpha',new THREE.BufferAttribute(this.alpha,1));g.setAttribute('size',new THREE.BufferAttribute(this.size,1));
  const m=new THREE.ShaderMaterial({transparent:true,depthWrite:false,uniforms:{scale:{value:innerHeight*0.6},maxPx:{value:innerHeight*0.22}},vertexShader:'attribute float alpha;attribute float size;attribute vec3 color;varying float vA;varying vec3 vC;uniform float scale;uniform float maxPx;void main(){vC=color;vec4 mv=modelViewMatrix*vec4(position,1.0);float z=max(0.5,-mv.z);float ps=size*scale/z;vA=alpha*smoothstep(1.2,4.5,z)*clamp(maxPx/ps,0.35,1.0);gl_PointSize=min(ps,maxPx);gl_Position=projectionMatrix*mv;}',fragmentShader:'varying float vA;varying vec3 vC;void main(){vec2 d=gl_PointCoord-0.5;float r=dot(d,d)*4.0;if(r>1.0)discard;gl_FragColor=vec4(vC,vA*(1.0-r));}'});
  /* humo liviano para el celular: tamaño en pantalla con tope, se desvanece pegado a la cámara (sin tapar la pantalla entera) y cantidad según la calidad */
  this.pts=new THREE.Points(g,m);this.pts.frustumCulled=false;scene.add(this.pts);this.geo=g;this.mat=m;this.next=0;this.cap=N;this.colDirty=false;
  this.MK=500;const mg=new THREE.PlaneGeometry(1,1);mg.rotateX(-Math.PI/2);this.marks=new THREE.InstancedMesh(mg,new THREE.MeshBasicMaterial({color:0x0c0c0c,transparent:true,opacity:0.42,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-3}),this.MK);this.marks.frustumCulled=false;const d=new THREE.Object3D();d.scale.set(0,0,0);d.updateMatrix();for(let i=0;i<this.MK;i++)this.marks.setMatrixAt(i,d.matrix);scene.add(this.marks);
  this.mk=0;this.d=d;this.last=[null,null,null,null];this.acc=[0,0,0,0];}
 reset(){const d=this.d;d.position.set(0,-999,0);d.scale.set(0,0,0);d.updateMatrix();for(let i=0;i<this.MK;i++)this.marks.setMatrixAt(i,d.matrix);this.marks.instanceMatrix.needsUpdate=true;this.mk=0;this.last=[null,null,null,null];this.life.fill(0);this.alpha.fill(0);this.geo.attributes.alpha.needsUpdate=true;}
 spawn(x,y,z,vx,vy,vz,r,g,b,a,size,life,grow,grav){const i=this.next%this.cap;this.next=(i+1)%this.cap;this.colDirty=true;this.pos[i*3]=x;this.pos[i*3+1]=y;this.pos[i*3+2]=z;this.vel[i*3]=vx;this.vel[i*3+1]=vy;this.vel[i*3+2]=vz;this.col[i*3]=r;this.col[i*3+1]=g;this.col[i*3+2]=b;this.a0[i]=a;this.alpha[i]=a;this.size[i]=size;this.life[i]=life;this.max[i]=life;this.grow[i]=grow;this.grav[i]=grav;}
 emitFrom(p,dt){this.cap=QUALITY==='baja'?70:QUALITY==='alta'?150:110;const qk=QUALITY==='baja'?0.3:QUALITY==='alta'?0.6:0.45;const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw);
  for(let i=0;i<4;i++){const w=p.wheels[i];if(!w.contact){this.last[i]=null;continue}
   const loose=w.surf!=='asphalt';const sp=Math.abs(w.vl);const sl=Math.max(0,Math.abs(w.kappa)-0.06)+Math.max(0,Math.abs(w.alpha)-0.09);
   const x=w.wx,z=w.wz,y=w.gy+0.08;const side=w.left?1:-1;let rate=0,kind=0;
   if(loose){rate=sp*0.9+sl*90;kind=1}else if(sl>0.14){rate=(sl-0.14)*120*Math.min(1,sp/3+0.3);kind=2}
   this.acc[i]=Math.min(this.acc[i]+rate*qk*dt,2);let nS=0;
   while(this.acc[i]>=1&&nS++<2){this.acc[i]-=1;const rnd=Math.random;const back=-(1.5+sp*0.25+Math.abs(w.kappa)*6),up=0.6+rnd()*1.2;
    if(kind===1){const c=0.55+rnd()*0.1;this.spawn(x+(rnd()-.5)*.3,y,z+(rnd()-.5)*.3,fx*back+lx*side*(rnd()*1.5)+(rnd()-.5),up,fz*back+lz*side*(rnd()*1.5)+(rnd()-.5),c*0.86,c*0.72,c*0.55,0.42,0.7+rnd()*0.5,0.9+rnd()*0.7,1.6,-0.4);
     if(rnd()<0.18)this.spawn(x,y,z,fx*back*0.8+(rnd()-.5)*2,1.5+rnd()*2,fz*back*0.8+(rnd()-.5)*2,0.18,0.15,0.12,1.0,0.07,0.6,0,-9.8);}
    else{const c=0.78+rnd()*0.1;this.spawn(x+(rnd()-.5)*.3,y+0.1,z+(rnd()-.5)*.3,fx*back*0.3+(rnd()-.5)*0.8,0.5+rnd()*0.5,fz*back*0.3+(rnd()-.5)*0.8,c,c,c*1.02,0.36,0.8+rnd()*0.6,1.4+rnd(),2.2,0.25);}}
   const mark=!loose&&sl>0.22;
   /* huellas pegadas al piso DIBUJADO (sin micro-relieve) y con la pendiente del camino: nunca quedan en el aire */
   const tr=p.track,gv=(X,Z)=>{if(!tr)return w.gy;const h=tr._hint;const y=tr.ground(X,Z);tr._hint=h;return y;};
   if(mark&&this.last[i]){const L=this.last[i],dx=x-L.x,dz=z-L.z,dd=Math.hypot(dx,dz);
    if(dd>0.35&&dd<3){const y1=gv(x,z),d=this.d;d.position.set((x+L.x)/2,(y1+L.y)/2+0.025,(z+L.z)/2);d.rotation.set(0,0,0);d.rotation.order='YXZ';d.rotation.y=Math.atan2(dx,dz);d.rotation.x=-Math.atan2(y1-L.y,dd);d.scale.set((p.V||VEH).tireWidth*0.9,1,Math.hypot(dd,y1-L.y));d.updateMatrix();this.marks.setMatrixAt(this.mk,d.matrix);this.mk=(this.mk+1)%this.MK;this.marks.instanceMatrix.needsUpdate=true;L.x=x;L.z=z;L.y=y1}
    else if(dd>=3){L.x=x;L.z=z;L.y=gv(x,z);}}
   else if(mark)this.last[i]={x,z,y:gv(x,z)};else this.last[i]=null;}}
 update(dt){const N=this.N,P=this.pos,Vv=this.vel;
  for(let i=0;i<N;i++){if(this.life[i]<=0){if(this.alpha[i]!==0){this.alpha[i]=0}continue}
   this.life[i]-=dt;const k=this.life[i]/this.max[i];Vv[i*3+1]+=this.grav[i]*dt;const drag=Math.exp(-dt*1.6);Vv[i*3]*=drag;Vv[i*3+2]*=drag;
   P[i*3]+=Vv[i*3]*dt;P[i*3+1]+=Vv[i*3+1]*dt;P[i*3+2]+=Vv[i*3+2]*dt;this.size[i]=Math.min(4.5,this.size[i]+this.grow[i]*dt*0.9);this.alpha[i]=Math.max(0,this.a0[i]*k)}
  const A=this.geo.attributes;A.position.needsUpdate=true;A.alpha.needsUpdate=true;A.size.needsUpdate=true;if(this.colDirty){A.color.needsUpdate=true;this.colDirty=false;}}
 setScale(h,pr){const u=this.mat.uniforms;u.scale.value=h*0.6*pr;u.maxPx.value=h*0.22*pr;}}

/* ═══ CÁMARA: 5 presets + 1 personalizable con desplazamiento libre ═══ */
class CameraRig{
 constructor(cam,track){
  this.cam=cam;this.track=track;
  this.pos=new THREE.Vector3();this.look=new THREE.Vector3();
  this.ready=false;this.yaw=0;this.bank=0;this.dist=CAMERAS[CAM_INDEX].dist||7;
  this.shake=0;
  // Parámetros de cámara personalizada
  this.customYawOff=0;      // rotación alrededor del auto
  this.customElev=0.28;     // elevación
  this.customDist=7.5;      // distancia radial
  this.customPanF=0;        // desplazamiento hacia adelante (car frame)
  this.customPanR=0;        // desplazamiento lateral (car frame)
  this.customPanU=0;        // desplazamiento vertical
  this.customTgtY=0.6;      // altura del punto de mira
  this._q=new THREE.Quaternion();this._qy=new THREE.Quaternion();this._qx=new THREE.Quaternion();this._qz=new THREE.Quaternion();
  this._v1=new THREE.Vector3();this._v2=new THREE.Vector3();
 }
 setPreset(i){this.ready=false;this.yaw=0;this.bank=0;if(CAMERAS[i].dist)this.dist=CAMERAS[i].dist;}
 update(dt,p){
  const cam=CAMERAS[CAM_INDEX];
  if((cam.mode==='hood'||cam.mode==='bumper')&&this.mount){this._updateMounted(p,cam);return;}
  if(cam.mode!=='onboard'&&cam.mode!=='rearcabin'&&this.cam.near!==0.15){this.cam.near=0.15;this.cam.updateProjectionMatrix();}
  if((cam.mode==='onboard'||cam.mode==='rearcabin')&&this.cockpit){this.cockpit.applyCamera(this.cam,cam.mode,p,this.info||{time:0,rough:0});return;}
  if(cam.mode==='fps'||cam.mode==='onboard'||cam.mode==='rearcabin'||cam.mode==='hood'||cam.mode==='bumper')this._updateChase(dt,p,CAMERAS[1]);
  else if(cam.mode==='custom')this._updateCustom(dt,p,cam);
  else this._updateChase(dt,p,cam);
 }
 /* cámaras montadas en la carrocería (capó / paragolpes): rígidas, con vibración del camino */
 _updateMounted(p,cam){const M=this.mount,g=M.group;g.updateWorldMatrix(true,false);const m=M[cam.mode],t=(this.info&&this.info.time)||0,rough=(this.info&&this.info.rough)||0;
  const vib=(cam.mode==='bumper'?0.006:0.003)*(0.4+rough*1.6)*Math.min(1,Math.abs(p.vLong)/20);
  const pos=this._v1.set(Math.sin(t*39.7)*vib,m.y+Math.sin(t*47.3)*vib,m.z),look=this._v2.set(0,m.y+m.ly,m.z+12);
  g.localToWorld(pos);g.localToWorld(look);const up=this._up||(this._up=new THREE.Vector3());up.set(0,1,0).applyQuaternion(g.getWorldQuaternion(this._q));
  this.cam.position.copy(pos);this.cam.up.copy(up);this.cam.lookAt(look);this.cam.up.set(0,1,0);
  const fov=cam.fov+Math.min(Math.hypot(p.vx,p.vz)/50,1)*5;if(Math.abs(this.cam.fov-fov)>0.05||this.cam.near!==0.08){this.cam.fov=fov;this.cam.near=0.08;this.cam.updateProjectionMatrix();}}
 _updateChase(dt,p,cam){
  const spd=Math.hypot(p.vx,p.vz);let heading=p.yaw;
  if(spd>5){const vh=Math.atan2(p.vx,p.vz);let d=vh-p.yaw;d=Math.atan2(Math.sin(d),Math.cos(d));if(p.vLong<0)d=0;heading=p.yaw+d*0.5}
  if(!this.ready){this.yaw=heading}
  let dy=heading-this.yaw;dy=Math.atan2(Math.sin(dy),Math.cos(dy));this.yaw+=dy*(1-Math.exp(-dt*2.3));
  const fx=Math.sin(this.yaw),fz=Math.cos(this.yaw);
  const targetD=cam.dist+clamp(spd*0.018,0,1.1)-clamp(p.aLong*0.07,-0.4,0.7);
  this.dist+=(targetD-this.dist)*(1-Math.exp(-dt*3));
  const ix=p.px-fx*this.dist,iz=p.pz-fz*this.dist;
  let iy=p.py+cam.height;
  const gy=this.track.groundInfo(ix,iz).y+0.7;if(iy<gy)iy=gy;
  if(!this.ready){this.pos.set(ix,iy,iz);this.ready=true}
  const k=1-Math.exp(-dt*9),kh=1-Math.exp(-dt*5);
  this.pos.x+=(ix-this.pos.x)*k;this.pos.z+=(iz-this.pos.z)*k;this.pos.y+=(iy-this.pos.y)*kh;
  if(this.track.clampCam){const h=this.track._hint;this.track._hint=p.trackHint;this.track.clampCam(this.pos);this.track._hint=h;}
  this.look.set(p.px+fx*cam.look,p.py+cam.lookH,p.pz+fz*cam.look);
  const rough=p.wheels.some(w=>w.contact&&w.surf!=='asphalt')?2.2:1;this.shake+=dt*37;
  const sa=Math.min(1,spd/40)*0.012*rough;
  this.cam.position.set(this.pos.x,this.pos.y+Math.sin(this.shake)*sa,this.pos.z);
  this.cam.lookAt(this.look);
  const bt=clamp(-p.aLat*0.010,-0.07,0.07);this.bank+=(bt-this.bank)*(1-Math.exp(-dt*3));this.cam.rotateZ(this.bank);
  this.cam.fov=cam.fov+Math.min(spd/45,1)*8;this.cam.updateProjectionMatrix();
 }
 _updateFPS(p,cam){
  this._qy.setFromAxisAngle(new THREE.Vector3(0,1,0),p.yaw);
  this._qx.setFromAxisAngle(new THREE.Vector3(1,0,0),p.pitch);
  this._qz.setFromAxisAngle(new THREE.Vector3(0,0,1),p.roll);
  this._q.copy(this._qy).multiply(this._qx).multiply(this._qz);
  this._v1.set(cam.localPos.x,cam.localPos.y,cam.localPos.z).applyQuaternion(this._q);
  this._v1.x+=p.px;this._v1.y+=p.py;this._v1.z+=p.pz;
  this._v2.set(cam.localLook.x,cam.localLook.y,cam.localLook.z).applyQuaternion(this._q);
  this._v2.x+=p.px;this._v2.y+=p.py;this._v2.z+=p.pz;
  this.cam.position.copy(this._v1);this.cam.lookAt(this._v2);
  this.cam.fov=cam.fov;this.cam.updateProjectionMatrix();
 }
 /* ═══ PERSONALIZADA: órbita + desplazamiento libre en frame del auto ═══ */
 _updateCustom(dt,p,cam){
  const ang=p.yaw+Math.PI+this.customYawOff;
  const cosE=Math.cos(this.customElev),sinE=Math.sin(this.customElev);
  const ox=Math.sin(ang)*this.customDist*cosE;
  const oz=Math.cos(ang)*this.customDist*cosE;
  const oy=this.customDist*sinE;
  // Pan en frame del auto: forward=(sin,0,cos), right=(cos,0,-sin)
  const cy=Math.cos(p.yaw),sy=Math.sin(p.yaw);
  const panX=cy*this.customPanR+sy*this.customPanF;
  const panZ=-sy*this.customPanR+cy*this.customPanF;
  const tx=p.px+ox+panX;
  const tz=p.pz+oz+panZ;
  let ty=p.py+oy+this.customPanU;
  const gy=this.track.groundInfo(tx,tz).y+0.25;
  if(ty<gy)ty=gy;
  const target=new THREE.Vector3(tx,ty,tz);
  if(!this.ready){this.pos.copy(target);this.ready=true}
  this.pos.lerp(target,1-Math.exp(-dt*14));
  this.cam.position.copy(this.pos);
  const lookAt=new THREE.Vector3(p.px,p.py+this.customTgtY,p.pz);
  this.cam.lookAt(lookAt);
  this.cam.fov=cam.fov;this.cam.updateProjectionMatrix();
 }
}
const SND={master:0.55,engine:0.62,tires:0.35,squeal:0.28,gravel:0.45,wind:0.25,turbo:0.10,pops:0.35,impacts:0.8,firingOrder:4};
class AudioEngine{
 constructor(){this.ctx=null;this.on=false;this.prevThr=0}
 init(){if(this.on)return;try{const C=window.AudioContext||window.webkitAudioContext;const ctx=this.ctx=new C();
  const comp=ctx.createDynamicsCompressor();comp.threshold.value=-14;comp.ratio.value=4;comp.connect(ctx.destination);
  this.master=ctx.createGain();this.master.gain.value=SND.master;this.master.connect(comp);
  const nb=ctx.createBuffer(1,ctx.sampleRate*2,ctx.sampleRate),d=nb.getChannelData(0);for(let i=0;i<d.length;i++)d[i]=Math.random()*2-1;this.noiseBuf=nb;
  const noise=()=>{const s=ctx.createBufferSource();s.buffer=nb;s.loop=true;s.start(0,Math.random()*1.5);return s};
  const filt=(type,f,q)=>{const x=ctx.createBiquadFilter();x.type=type;x.frequency.value=f;x.Q.value=q;return x};
  const gain=v=>{const g=ctx.createGain();g.gain.value=v;return g};
  this.eng=gain(0);this.engF=filt('lowpass',600,0.8);
  const shp=ctx.createWaveShaper(),cv=new Float32Array(1024);for(let i=0;i<1024;i++){const x=i/511.5-1;cv[i]=Math.tanh(x*2.2)}shp.curve=cv;
  this.oscs=[];const mix=gain(1);
  for(const [type,mul,g] of [['sawtooth',1,0.45],['sawtooth',0.5,0.35],['square',2,0.08],['sine',0.25,0.45],['triangle',1.5,0.10]]){const o=ctx.createOscillator();o.type=type;o.frequency.value=60*mul;const gg=gain(g);o.connect(gg).connect(mix);o.start();this.oscs.push({o,mul})}
  this.am=gain(0.75);this.lfo=ctx.createOscillator();this.lfo.type='sine';this.lfoG=gain(0.25);this.lfo.connect(this.lfoG).connect(this.am.gain);this.lfo.start();
  mix.connect(this.am).connect(shp).connect(this.engF).connect(this.eng).connect(this.master);
  this.engN=gain(0);this.engNF=filt('bandpass',300,1.5);noise().connect(this.engNF).connect(this.engN).connect(this.eng);
  this.roll=gain(0);noise().connect(filt('bandpass',380,0.7)).connect(this.roll).connect(this.master);
  this.sq=gain(0);this.sqF=filt('bandpass',1150,7);noise().connect(this.sqF).connect(this.sq).connect(this.master);
  this.grav=gain(0);noise().connect(filt('highpass',900,0.7)).connect(filt('bandpass',2500,0.8)).connect(this.grav).connect(this.master);
  this.wind=gain(0);this.windF=filt('bandpass',700,0.5);noise().connect(this.windF).connect(this.wind).connect(this.master);
  this.tb=gain(0);this.tbF=filt('bandpass',3600,4);noise().connect(this.tbF).connect(this.tb).connect(this.master);
  this.on=true;}catch(e){}}
 resume(){if(this.ctx&&this.ctx.state==='suspended')this.ctx.resume()}
 aiUpdate(d,rpm,fo){if(!this.on)return;const ctx=this.ctx,t=ctx.currentTime;if(!this.aiG){this.aiG=ctx.createGain();this.aiG.gain.value=0;const f=ctx.createBiquadFilter();f.type='lowpass';f.frequency.value=900;this.aiO=[];for(const mul of [1,0.5]){const o=ctx.createOscillator();o.type='sawtooth';o.frequency.value=80;o.connect(f);o.start();this.aiO.push({o,mul});}f.connect(this.aiG).connect(this.master);}
  const g=d==null?0:0.16*Math.max(0,1-d/55)**1.5;this.aiG.gain.setTargetAtTime(g,t,0.08);const f0=(rpm||1000)/60*(fo||4)*0.5;for(const x of this.aiO)x.o.frequency.setTargetAtTime(f0*x.mul,t,0.05);}
 rainSet(on){if(!this.on)return;const ctx=this.ctx;if(!this.rainG){this.rainG=ctx.createGain();this.rainG.gain.value=0;const s=ctx.createBufferSource();s.buffer=this.noiseBuf;s.loop=true;const f=ctx.createBiquadFilter();f.type='highpass';f.frequency.value=1800;s.connect(f).connect(this.rainG).connect(this.master);s.start();}this.rainG.gain.setTargetAtTime(on?0.10:0,ctx.currentTime,0.4);}
 burst(t,dur,f,q,amp,type='bandpass'){const ctx=this.ctx,s=ctx.createBufferSource();s.buffer=this.noiseBuf;const fl=ctx.createBiquadFilter();fl.type=type;fl.frequency.value=f;fl.Q.value=q;const g=ctx.createGain();g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(amp,t+0.004);g.gain.exponentialRampToValueAtTime(0.0008,t+dur);s.connect(fl).connect(g).connect(this.master);s.start(t,Math.random()*1.5);s.stop(t+dur+0.05)}
 thump(strength){if(!this.on)return;const ctx=this.ctx,t=ctx.currentTime,a=Math.min(1,strength)*SND.impacts;
  const o=ctx.createOscillator();o.frequency.setValueAtTime(75,t);o.frequency.exponentialRampToValueAtTime(38,t+0.22);const g=ctx.createGain();g.gain.setValueAtTime(a*0.9,t);g.gain.exponentialRampToValueAtTime(0.001,t+0.28);o.connect(g).connect(this.master);o.start(t);o.stop(t+0.3);this.burst(t,0.12,180,0.7,a*0.6,'lowpass');}
 pops(n){if(!this.on)return;const t=this.ctx.currentTime;for(let i=0;i<n;i++)this.burst(t+0.03+Math.random()*0.35,0.03+Math.random()*0.03,700+Math.random()*700,1.2,SND.pops*(0.5+Math.random()*0.5))}
 update(p,dt){if(!this.on)return;const ctx=this.ctx,t=ctx.currentTime,V=VEH;
  const rpm=p.rpm,rn=clamp((rpm-V.idleRpm)/(V.maxRpm-V.idleRpm),0,1),load=clamp(p.load,0,1);
  const f0=rpm/60*(VEH.firingOrder||SND.firingOrder);for(const o of this.oscs)o.o.frequency.setTargetAtTime(f0*o.mul,t,0.012);this.lfo.frequency.setTargetAtTime(f0*0.125,t,0.02);
  const cut=260+load*1500+rn*1600;this.engF.frequency.setTargetAtTime(cut,t,0.03);
  const eg=SND.engine*((this.mix&&this.mix.eng)||1)*(0.35+0.25*rn)*(0.62+0.38*load)*(p.limiter?0.7:1);this.eng.gain.setTargetAtTime(eg,t,0.03);
  this.engNF.frequency.setTargetAtTime(f0,t,0.02);this.engN.gain.setTargetAtTime(0.25*load,t,0.05);
  let sp=Math.hypot(p.vx,p.vz),asf=0,loose=0,sl=0,dirt=0,nl=0;
  for(const w of p.wheels){if(!w.contact)continue;if(w.surf!=='asphalt'){nl++;if(w.surf==='dirt'||w.surf==='mud')dirt++;}const s2=Math.max(0,Math.abs(w.kappa)-0.08)+Math.max(0,Math.abs(w.alpha)-0.1);if(w.surf==='asphalt'){asf+=0.25;sl=Math.max(sl,s2)}else loose+=0.25+s2}
  this.dirtK=nl?dirt/nl:0;
  this.roll.gain.setTargetAtTime(SND.tires*asf*Math.min(1,sp/30),t,0.08);
  this.sq.gain.setTargetAtTime(SND.squeal*clamp((sl-0.08)*3,0,1),t,0.05);this.sqF.frequency.setTargetAtTime(1000+sl*400+Math.random()*120,t,0.03);
  /* pasto/tierra: nada parado, sube con la velocidad; el pasto suena más suave que la tierra/ripio (ajustable en Opciones) */
  const mx=this.mix||{eng:1,surf:0.3,wind:0.3},mv=clamp((sp-0.8)/12,0,1);
  this.grav.gain.setTargetAtTime(SND.gravel*mx.surf*Math.min(1,loose)*(0.35+0.65*this.dirtK)*mv*mv*(0.8+Math.random()*0.4),t,0.03);
  this.wind.gain.setTargetAtTime(SND.wind*mx.wind*Math.pow(clamp((sp-6)/42,0,1),2),t,0.1);this.windF.frequency.setTargetAtTime(500+sp*18,t,0.1);
  this.tb.gain.setTargetAtTime(SND.turbo*load*rn,t,0.08);this.tbF.frequency.setTargetAtTime(2600+rn*2400,t,0.05);
  const thr=p.throttle||0;if(this.prevThr>0.6&&thr<0.15&&rpm>4200)this.pops(2+Math.floor(Math.random()*4));this.prevThr=thr;
  for(const e of p.events){if(e.type==='shift'&&e.up)this.pops(1);if(e.type==='limiter')this.pops(2);if(e.type==='land')this.thump(e.v/4)}
  for(const w of p.wheels){if(w.impact>1.4)this.thump((w.impact-1.2)/5);w.impact=0}}}
/* ═══════════════════════════════════════════════════════════════════
   AJUSTES GLOBALES (puente con Input / loop) — se cargan del perfil
   ═══════════════════════════════════════════════════════════════════ */
const tune={steerMode:'wheel',gameSpeed:100,gyroSensitivity:50};
let QUALITY='media';
function QF(){return {baja:0.45,media:1,alta:1.35}[QUALITY]||1;}
/* calidad automática: estimación inicial por el hardware y luego se ajusta con los FPS reales (se recuerda) */
function guessQuality(){try{const mem=navigator.deviceMemory||4,cores=navigator.hardwareConcurrency||4,px=screen.width*screen.height*(devicePixelRatio||1)**2;
  if(mem<=3||cores<=4)return 'baja';if(mem>=6&&cores>=8&&px<4.5e6)return 'alta';return 'media';}catch(e){return 'media';}}
function effQuality(s){return s.quality==='auto'?(s.autoLevel||guessQuality()):s.quality;}
const PROFILE=new Profile();
function assistsOf(s){return {abs:s.abs,tc:s.tc,stab:s.stab};}
function paramsFor(id,state){return buildParams(VEHICLES[id],state||newCarState(id),assistsOf(PROFILE.d.settings));}
function setPlayerCar(id,state){currentVehicleId=id;const V=paramsFor(id,state);for(const k in VEH)delete VEH[k];Object.assign(VEH,V);BASE=structuredClone(VEHICLES[id]);}

/* ═══ MAPAS ═══ */
const MAPS={
 forest:{name:'Bosque de Tierra',icon:'🌲',kind:'route',route:'forest',mode:'dirt'},
 forestRev:{name:'Bosque (inverso)',icon:'🌲',kind:'route',route:'forest',mode:'dirt',reverse:true},
 asphaltLong:{name:'Montaña Asfalto',icon:'🏔️',kind:'route',route:'asphaltLong',mode:'asphalt'},
 descent:{name:'Bajada de los Badenes',icon:'⛰️',kind:'route',route:'descent',mode:'asphalt'},
 trinchera:{name:'La Trinchera',icon:'⛏️',kind:'route',route:'trinchera',mode:'asphalt',trench:true},
 escape:{name:'La Fuga · Capítulo 1',icon:'📖',kind:'route',route:'escape',mode:'asphalt',trench:true,hidden:true},
 asphaltRev:{name:'Montaña (inversa)',icon:'🏔️',kind:'route',route:'asphaltLong',mode:'asphalt',reverse:true},
 lake:{name:'Circuito del Lago',icon:'🌊',kind:'route',route:'lake',mode:'asphalt'},
 quarry:{name:'Cantera Roja',icon:'⛏️',kind:'route',route:'quarry',mode:'dirt'},
 quarryRev:{name:'Cantera (inversa)',icon:'⛏️',kind:'route',route:'quarry',mode:'dirt',reverse:true},
 drift:{name:'Drift Plaza',icon:'🛞',kind:'drift'},
 offroad:{name:'Valle Abierto',icon:'🏞️',kind:'offroad'},
 parking:{name:'Estacionamiento',icon:'🅿️',kind:'parking'},
};
function buildTrack(scene,id){const m=MAPS[id]||MAPS.forest;
 if(m.kind==='drift')return new DriftTrack(scene);if(m.kind==='offroad')return new OffroadTrack(scene);if(m.kind==='parking')return new ParkingTrack(scene);
 if(m.trench)return m.route==='escape'?new StoryTrack(scene,'escape'):new TrenchTrack(scene,m.route);
 return new Track(scene,m.mode,m.route,{reverse:m.reverse});}

/* ═══ CIELOS / HORA DEL DÍA ═══ */
const SKIES={
 day:{bg:'#9ec0d2',zen:'#4a86c8',fog:[180,900],hemi:['#d9e9ff','#4b4132',1.1],sun:['#fff0d2',1.6],sunPos:[120,160,80],exp:1.05,env:['#b9d4e8','#e8eef2','#4a5a3a','#2a2a22'],disc:'rgba(255,250,235,.9)'},
 sunset:{bg:'#e9a576',zen:'#34457a',fog:[140,760],hemi:['#ffd2b0','#3d2c26',0.95],sun:['#ffb070',1.75],sunPos:[-220,55,140],exp:1.0,env:['#f2a26a','#ffd8a8','#4a3b2b','#1c140e'],disc:'rgba(255,200,120,.95)'},
 overcast:{bg:'#9aa4ad',zen:'#7b8792',fog:[90,560],hemi:['#d2d9e0','#4b4a44',1.25],sun:['#e8ecf0',0.55],sunPos:[60,200,40],exp:1.08,env:['#aab4bd','#c9d0d6','#4d5448','#26281f'],disc:'rgba(230,235,240,.4)'},
 rain:{bg:'#6d7780',zen:'#4d5760',fog:[55,340],hemi:['#aab4be','#34332f',1.0],sun:['#c8d0d8',0.35],sunPos:[40,200,60],exp:1.0,env:['#6d7780','#9aa3ab','#3a3d38','#1b1c19'],disc:'rgba(200,210,220,.2)',rain:true},
 dusk:{bg:'#5b6a8f',zen:'#141b36',fog:[110,620],hemi:['#9fb0d8','#2a2530',0.8],sun:['#ff9a6a',1.0],sunPos:[-160,30,-180],exp:1.15,env:['#4d5b86','#c58f8a','#2d3130','#121210'],disc:'rgba(255,170,140,.9)'},
};

/* ═══ SHOWROOM 3D (menús) ═══ */
class Showroom{
 constructor(renderer){this.r=renderer;const S=this.scene=new THREE.Scene();S.background=new THREE.Color(0x07090d);S.fog=new THREE.Fog(0x07090d,14,34);
  this.cam=new THREE.PerspectiveCamera(34,innerWidth/innerHeight,0.1,100);
  const pm=new THREE.PMREMGenerator(renderer);S.environment=pm.fromScene(new RoomEnvironment(),0.04).texture;pm.dispose();
  S.add(new THREE.HemisphereLight(0xcfe2ff,0x1a1410,0.55));
  const key=new THREE.DirectionalLight(0xffffff,2.2);key.position.set(4,7,5);S.add(key);
  const rim=new THREE.DirectionalLight(0xff8a3a,0.9);rim.position.set(-6,3,-5);S.add(rim);
  const blue=new THREE.DirectionalLight(0x3a9bff,1.2);blue.position.set(6,2,-6);S.add(blue);
  const floor=new THREE.Mesh(new THREE.CircleGeometry(30,64),new THREE.MeshStandardMaterial({color:0x0a0c10,metalness:0.35,roughness:0.48}));floor.rotation.x=-Math.PI/2;S.add(floor);
  const disc=new THREE.Mesh(new THREE.CylinderGeometry(3.6,3.7,0.08,72),new THREE.MeshStandardMaterial({color:0x14181f,metalness:0.8,roughness:0.25}));disc.position.y=0.04;S.add(disc);this.disc=disc;
  const ring=new THREE.Mesh(new THREE.TorusGeometry(3.66,0.025,6,120),new THREE.MeshBasicMaterial({color:0xff6a08}));ring.rotation.x=Math.PI/2;ring.position.y=0.085;S.add(ring);
  const ring2=new THREE.Mesh(new THREE.TorusGeometry(5.2,0.012,6,120),new THREE.MeshBasicMaterial({color:0x37b6ff}));ring2.rotation.x=Math.PI/2;ring2.position.y=0.01;S.add(ring2);
  const wall=canvasTex(1024,256,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,'#05070a');g.addColorStop(0.55,'#111722');g.addColorStop(1,'#07090d');c.fillStyle=g;c.fillRect(0,0,w,h);
   for(let i=0;i<24;i++){const x=i*w/24;c.fillStyle='rgba(255,255,255,.035)';c.fillRect(x,h*0.18,w/48,h*0.5);}c.fillStyle='rgba(255,106,8,.55)';c.fillRect(0,h*0.72,w,2);});
  const cyl=new THREE.Mesh(new THREE.CylinderGeometry(22,22,12,64,1,true),new THREE.MeshBasicMaterial({map:wall,side:THREE.BackSide}));cyl.position.y=5.5;S.add(cyl);
  this.holder=new THREE.Group();S.add(this.holder);this.car=null;this.ang=0.6;this.auto=true;this.drag=null;this.dist=8;this.tAng=0.6;this.key='';}
 setCar(id,state){const key=id+JSON.stringify(state||{})+(ASSETS.voltBody?'g':'');if(key===this.key&&this.car)return;this.key=key;
  if(this.car){this.car.dispose();this.holder.remove(this.car.group);}
  const V=paramsFor(id,state);const vis=new VehicleVisual(VEHICLES[id].visualType,V,{paint:(state&&state.paint)||{...CAR_META[id].paint,finish:'metal'}});
  const pose={px:0,py:V.comHeight+0.085,pz:0,yaw:0,pitch:0,roll:0,steerAngle:-0.28,brake:0,gear:1,wheels:[0,1,2,3].map(()=>({s:V.comHeight-V.wheelRadius,omega:0}))};
  vis.update(pose,0);vis.update(pose,0);this.car=vis;this.holder.add(vis.group);
  const box=new THREE.Box3().setFromObject(vis.group),sz=box.getSize(new THREE.Vector3());this.size=sz;this.dist=Math.max(7,Math.max(sz.z,sz.x*1.6)*1.55+2);this.lookY=sz.y*0.42;}
 pointer(e,type){if(type==='down'){this.drag={x:e.clientX,a:this.tAng};this.auto=false;}else if(type==='move'&&this.drag){this.tAng=this.drag.a-(e.clientX-this.drag.x)*0.008;}else if(type==='up'){this.drag=null;clearTimeout(this._t);this._t=setTimeout(()=>this.auto=true,3500);}}
 render(dt){if(this.auto)this.tAng+=dt*0.16;this.ang+=(this.tAng-this.ang)*(1-Math.exp(-dt*6));
  const wide=innerWidth/innerHeight>1.2;const off=wide?(this.off??-0.9):0;
  this.cam.aspect=innerWidth/innerHeight;this.cam.fov=wide?30:44;this.cam.updateProjectionMatrix();
  const d=this.dist;this.cam.position.set(Math.sin(this.ang)*d,1.9+d*0.12,Math.cos(this.ang)*d);
  const right=new THREE.Vector3(Math.cos(this.ang),0,-Math.sin(this.ang));this.cam.lookAt(right.x*off,this.lookY||0.8,right.z*off);
  if(this.car&&this.car.mat.red)this.car.mat.red.color.setRGB(0.4,0.06,0.08);
  this.r.render(this.scene,this.cam);}
}

/* ═══ SONIDOS DE INTERFAZ (sintetizados) ═══ */
function sfxPlay(audio,name){if(!audio.on)return;const ctx=audio.ctx,t=ctx.currentTime,o=ctx.createOscillator(),g=ctx.createGain();o.connect(g).connect(audio.master);
 const P={click:[880,0.04,'triangle',0.12],buy:[660,0.18,'sine',0.2],error:[160,0.2,'square',0.12],beep:[660,0.16,'sine',0.35],go:[1320,0.5,'sine',0.35],coin:[1500,0.12,'sine',0.2],finish:[523,0.6,'triangle',0.3]}[name]||[600,0.05,'sine',0.1];
 o.type=P[2];o.frequency.setValueAtTime(P[0],t);if(name==='buy'||name==='coin')o.frequency.exponentialRampToValueAtTime(P[0]*2,t+P[1]);if(name==='finish'){o.frequency.setValueAtTime(523,t);o.frequency.setValueAtTime(659,t+0.15);o.frequency.setValueAtTime(784,t+0.3);}
 g.gain.setValueAtTime(P[3],t);g.gain.exponentialRampToValueAtTime(0.0005,t+P[1]);o.start(t);o.stop(t+P[1]+0.05);}

/* ═══ MÚSICA DE MENÚ (sintetizada, loop synthwave suave) ═══ */
/* ═══ Vista previa de los efectos de cámara (desde el menú): tu auto andando por un camino, con el efecto puesto ═══ */
class FxStage{
 constructor(){const S=this.scene=new THREE.Scene();S.background=new THREE.Color(0x9ec0d2);S.fog=new THREE.Fog(0x9ec0d2,70,420);
  this.cam=new THREE.PerspectiveCamera(56,innerWidth/innerHeight,0.15,1200);
  S.add(new THREE.HemisphereLight(0xd9e9ff,0x4b4132,1.1));const sun=new THREE.DirectionalLight(0xfff0d2,1.6);sun.position.set(120,160,80);S.add(sun);this.sunDir=sun.position.clone().normalize();
  const sky=canvasTex(512,256,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h/2);g.addColorStop(0,'#4a86c8');g.addColorStop(1,'#9ec0d2');c.fillStyle=g;c.fillRect(0,0,w,h);});
  const dome=new THREE.Mesh(new THREE.SphereGeometry(900,24,12),new THREE.MeshBasicMaterial({map:sky,side:THREE.BackSide,fog:false,depthWrite:false}));dome.renderOrder=-1;S.add(dome);
  const asph=canvasTex(256,512,(c,w,h)=>{c.fillStyle='#3a3d41';c.fillRect(0,0,w,h);for(let i=0;i<5000;i++){const q=40+Math.random()*45;c.fillStyle=`rgb(${q},${q},${q+3})`;c.fillRect(Math.random()*w,Math.random()*h,1.4,1.4);}c.fillStyle='rgba(235,235,225,.85)';c.fillRect(124,0,8,260);c.fillRect(6,0,5,h);c.fillRect(w-11,0,5,h);});
  asph.wrapS=asph.wrapT=THREE.RepeatWrapping;asph.repeat.set(1,60);this.asph=asph;
  const road=new THREE.Mesh(new THREE.PlaneGeometry(11,1200),new THREE.MeshLambertMaterial({map:asph}));road.rotation.x=-Math.PI/2;road.position.set(0,0.04,300);road.renderOrder=1;S.add(road);
  const grassT=canvasTex(256,256,(c,w,h)=>{c.fillStyle='#4d6b3a';c.fillRect(0,0,w,h);for(let i=0;i<6000;i++){const q=Math.random();c.fillStyle=q<.5?'rgba(90,120,60,.6)':'rgba(60,82,40,.6)';c.fillRect(Math.random()*w,Math.random()*h,2,2);}});grassT.wrapS=grassT.wrapT=THREE.RepeatWrapping;grassT.repeat.set(40,120);this.grassT=grassT;
  const grass=new THREE.Mesh(new THREE.PlaneGeometry(400,1200),new THREE.MeshLambertMaterial({map:grassT,polygonOffset:true,polygonOffsetFactor:2,polygonOffsetUnits:2}));grass.rotation.x=-Math.PI/2;grass.position.set(0,0,300);S.add(grass);
  /* árboles: un patrón que se repite cada 120 m y se corre hacia atrás (sensación de velocidad) */
  this.P=120;this.trees=new THREE.Group();S.add(this.trees);const n=70,d=new THREE.Object3D(),crowns=new THREE.InstancedMesh(pineGeo(),pineMat(),n*6),trunks=new THREE.InstancedMesh(new THREE.CylinderGeometry(.18,.25,2.6,6),new THREE.MeshLambertMaterial({color:0x5a3f28}),n*6);
  let k=0;for(let rep=0;rep<6;rep++)for(let i=0;i<n;i++){const r=(i*9301+49297)%233280/233280,r2=(i*7919+104729)%1000/1000;const x=(r<0.5?-1:1)*(9+r2*55),z=(i/n)*this.P+rep*this.P-60,sc=0.8+((i*37)%10)/12;
   d.position.set(x,1.3*sc,z);d.scale.setScalar(sc);d.rotation.set(0,i,0);d.updateMatrix();trunks.setMatrixAt(k,d.matrix);d.position.y=3.4*sc;d.updateMatrix();crowns.setMatrixAt(k,d.matrix);k++;}
  this.trees.add(trunks,crowns);this.t=0;this.car=null;this.key='';}
 setCar(id,state){const key=id+JSON.stringify(state||{});if(key===this.key&&this.car)return;this.key=key;if(this.car){this.car.dispose();this.scene.remove(this.car.group);}
  const V=paramsFor(id,state);this.V=V;this.car=new VehicleVisual(VEHICLES[id].visualType,V,{paint:(state&&state.paint)||{...CAR_META[id].paint}});this.scene.add(this.car.group);
  this.pose={px:0,py:V.comHeight,pz:0,yaw:0,pitch:0,roll:0,steerAngle:0,brake:0,gear:3,wheels:[0,1,2,3].map(()=>({s:V.comHeight-V.wheelRadius,omega:0}))};}
 render(dt,g){const v=26,t=(this.t+=dt),P=this.pose,V=this.V;if(!this.car)return;
  /* el auto "anda": ruedas girando, suspensión y un poco de balanceo; el mundo se corre para atrás */
  for(const w of P.wheels){w.omega=v/V.wheelRadius;w.s=V.comHeight-V.wheelRadius+Math.sin(t*9+w.omega)*0.012;}P.steerAngle=Math.sin(t*0.5)*0.05;P.roll=Math.sin(t*0.5)*0.012;P.pitch=Math.sin(t*1.7)*0.004;P.px=Math.sin(t*0.5)*0.9;P.yaw=Math.cos(t*0.5)*0.03;
  this.car.update(P,dt);this.asph.offset.y=-(t*v/20)%1;this.grassT.offset.y=-(t*v/10)%1;this.trees.position.z=-((t*v)%this.P);
  const c=this.cam,wide=innerWidth/innerHeight>1.2;c.aspect=innerWidth/innerHeight;c.fov=wide?48:62;c.updateProjectionMatrix();
  /* encuadre: el auto a la derecha de la pantalla (el menú queda a la izquierda) */
  c.position.set(P.px+1.2+Math.sin(t*0.23)*0.25,2.1,-8.2);c.lookAt(P.px+(wide?2.8:0.3),wide?-0.9:0.6,3.5);
  this.scene.environment=g.scene.environment;
  g.renderPost(this.scene,c,{time:t,speed:0.5,rough:0.15,rain:0,sunDir:this.sunDir,sunPower:1,focus:c.position.distanceTo(this.car.group.position),hazeColor:g.hazeCol});}
}
class Music{
 constructor(audio){this.a=audio;this.on=false;this.step=0;this.timer=null;}
 start(){const A=this.a;if(!A.on||this.on)return;this.on=true;const ctx=A.ctx;if(!this.out){this.out=ctx.createGain();this.out.gain.value=0;const f=ctx.createBiquadFilter();f.type='lowpass';f.frequency.value=2400;this.out.connect(f).connect(A.master);}
  this.out.gain.setTargetAtTime(0.55,ctx.currentTime,0.8);this.next=ctx.currentTime+0.1;this.timer=setInterval(()=>this.sched(),60);}
 stop(){if(!this.on)return;this.on=false;clearInterval(this.timer);const ctx=this.a.ctx;this.out.gain.setTargetAtTime(0,ctx.currentTime,0.4);}
 note(t,f,d,type,g,dest){const ctx=this.a.ctx,o=ctx.createOscillator(),e=ctx.createGain();o.type=type;o.frequency.value=f;e.gain.setValueAtTime(0,t);e.gain.linearRampToValueAtTime(g,t+0.02);e.gain.exponentialRampToValueAtTime(0.0008,t+d);o.connect(e).connect(dest||this.out);o.start(t);o.stop(t+d+0.05);}
 sched(){const ctx=this.a.ctx,spb=60/96/2;const prog=[[57,60,64],[53,57,60],[48,52,55],[55,59,62]];const hz=m=>440*Math.pow(2,(m-69)/12);
  while(this.next<ctx.currentTime+0.25){const s=this.step,bar=Math.floor(s/8)%4,ch=prog[bar],t=this.next;
   this.note(t,hz(ch[0]-24),spb*0.9,'sawtooth',0.07);if(s%2===0)this.note(t,hz(ch[0]-12),spb*1.8,'triangle',0.05);
   if(s%8===0)for(const m of ch)this.note(t,hz(m),spb*7.5,'sine',0.028);
   if([0,3,5,6].includes(s%8))this.note(t,hz(ch[(s>>1)%3]+12),spb*0.7,'square',0.012);
   if(s%2===1){const b=ctx.createBufferSource();b.buffer=this.a.noiseBuf;const hp=ctx.createBiquadFilter();hp.type='highpass';hp.frequency.value=7000;const e=ctx.createGain();e.gain.setValueAtTime(0.03,t);e.gain.exponentialRampToValueAtTime(0.0005,t+0.05);b.connect(hp).connect(e).connect(this.out);b.start(t,Math.random());b.stop(t+0.06);}
   if(s%4===0){const o=ctx.createOscillator(),e=ctx.createGain();o.frequency.setValueAtTime(120,t);o.frequency.exponentialRampToValueAtTime(40,t+0.12);e.gain.setValueAtTime(0.12,t);e.gain.exponentialRampToValueAtTime(0.001,t+0.18);o.connect(e).connect(this.out);o.start(t);o.stop(t+0.2);}
   this.step++;this.next+=spb;}}
}

/* ═══ NOMBRES Y AUTOS DE LA IA ═══ */
const AI_NAMES=['M. Kovac','L. Ferreyra','S. Okafor','T. Nakamura','R. Álvarez','J. Lindqvist','C. Duarte','A. Moreau','P. Rossi','K. Bauer','D. Sosa','E. Varga'];
function aiCarsFor(n,maxPI,only,surface){
 const pool=only?[only]:CAR_ORDER.filter(id=>id!=='truck'&&perfOf(paramsFor(id,null)).pi<=maxPI+30);if(!pool.length)pool.push('pickup');
 const cats=['engine','turbo','weight','brakes','suspension','gearbox','diff','aero'];const out=[];
 for(let i=0;i<n;i++){const id=pool[i%pool.length];const st=newCarState(id);st.tires=surface==='asphalt'?'sport':'gravel';
  const target=Math.min(maxPI,999)-30-Math.random()*45;let guard=0;
  while(guard++<40){const pf=perfOf(buildParams(VEHICLES[id],st,{abs:true,tc:50,stab:40}));if(pf.pi>=target)break;const c=cats[Math.floor(Math.random()*cats.length)];const u=UPG_BY_ID[c];if((st.upg[c]||0)<u.levels.length-1)st.upg[c]=(st.upg[c]||0)+1;}
  while(perfOf(buildParams(VEHICLES[id],st,{abs:true,tc:50,stab:40})).pi>maxPI){const c=cats.find(c=>st.upg[c]>0);if(!c)break;st.upg[c]--;}
  st.paint={body:PAINTS[(i*7+3)%PAINTS.length],accent:PAINTS[(i*5+11)%PAINTS.length],rim:'#2a2d33',finish:['gloss','metal','matte'][i%3]};
  out.push({id,state:st});}
 return out;}

/* ═══ SESIÓN: una carrera / evento en curso ═══ */
class Session{
 constructor(game,cfg){this.g=game;this.cfg=cfg;this.type=cfg.type;this.cars=[];this.time=0;this.state='countdown';this.cd=3.6;this.lastBeep=4;this.result=null;this.touches=0;this.touchCd=0;
  const S=game.scene;this.track=buildTrack(S,cfg.map);const tr=this.track;this.route=tr instanceof Track;
  const N=this.route?tr.samples.length:1;
  /* tramo / vueltas */
  if(this.route){this.L=tr.length;this.s0=cfg.seg?Math.floor(cfg.seg[0]*N):0;
   if(cfg.seg){const s1=Math.floor(cfg.seg[1]*N);this.s1=s1;let d=tr.cum[s1]-tr.cum[this.s0];if(d<=0)d+=this.L;this.raceLen=d;this.laps=1;}
   else{this.laps=cfg.laps||1;this.raceLen=this.laps*this.L;this.s1=this.s0;}
   if(this.type==='story')tr.addGate(this.s1,'⛏ SALIDA','#8a1010');
   else if(['race','timetrial','trap','drift'].includes(this.type)||cfg.seg){tr.addGate(this.s0,cfg.seg?'LARGADA':'GSKORP RALLY','#0d1117');if(cfg.seg)tr.addGate(this.s1,this.type==='trap'?'📸 RADAR':'META','#8a1010');}}
  /* jugador */
  const pl={name:PROFILE.d.name||'Vos',isPlayer:true,phys:new Physics(tr,VEH),vis:game.car,color:'#ff6a08'};this.cars.push(pl);this.player=pl;
  /* rivales */
  if((this.type==='race'||this.type==='story')&&cfg.ai>0){const picks=aiCarsFor(cfg.ai,cfg.maxPI||999,cfg.aiCar,tr.mode);
   picks.forEach((c,i)=>{const V=buildParams(VEHICLES[c.id],c.state,{abs:true,tc:50,stab:45});const ph=new Physics(tr,V);const vis=new VehicleVisual(VEHICLES[c.id].visualType,V,{paint:c.state.paint,lo:true});S.add(vis.group);
    const lane=((i%3)-1)*1.6;const boss=cfg.bossName&&i===0;const car={name:boss?cfg.bossName:AI_NAMES[(i+(cfg.seed||0))%AI_NAMES.length],phys:ph,vis,color:c.state.paint.body,ai:new AIDriver(tr,ph,{skill:boss&&cfg.bossSkill?cfg.bossSkill:Math.min(1.08,(cfg.skill||0.9)*(0.96+Math.random()*0.06)),lane,aggr:Math.random()})};
    car.shadow=game.makeShadow();
    /* tripulación propia (cada una con su física de cuello/cuerpo) */
    try{const cr=vis.cabinOpen?new Crew(VEHICLES[c.id].visualType,i+(cfg.seed||0)):{ok:false};if(cr.ok){cr.group.position.y=-V.comHeight+(V.rideOffset||0);vis.group.add(cr.group);car.crew=cr;}}catch(e){console.warn('tripulación',e);}
    const tag=new THREE.Sprite(new THREE.SpriteMaterial({map:canvasTex(256,64,(c2,W,H)=>{c2.fillStyle='rgba(8,12,18,.72)';c2.fillRect(4,8,W-8,H-16);c2.fillStyle=c.state.paint.body;c2.fillRect(14,22,8,20);c2.fillStyle='#fff';c2.font='800 26px system-ui';c2.textBaseline='middle';c2.fillText(car.name,32,33);}),depthTest:false,transparent:true}));
    tag.scale.set(3.2,0.8,1);tag.renderOrder=5;S.add(tag);car.tag=tag;if(this.type==='story'){car.ai.hunt=true;car.ai.target=pl.phys;car.ai.show=true;ph.powerMul=1.18;car.ai.huntK=cfg.hunterK||1.08+i*0.03;car.ai.pref=[-1,1,0][i%3];}this.cars.push(car);});}
  this.placeGrid();
  for(const c of this.cars){c.prog=0;c.lastS=null;c.finished=false;c.finishTime=null;c.maxKmh=0;}
  if(this.route)for(const c of this.cars)this.initProg(c);
  /* objetivos especiales */
  if(this.type==='rush'||this.type==='world')this.buildFlags(cfg);
  if(this.type==='world'){this.buildWorld();this.duels=new WorldDuels(game,this,{profile:PROFILE,makeCar:(id,paint,name)=>this.makeCar(id,paint,name),pw:V=>perfOf(V).pw,addCollider:(x,z,r)=>addCollider(tr,x,z,r),canvasTex});this.director=this.duels;}
  if(this.type==='drift')this.drift={cur:0,mult:1,combo:0,idle:0,total:0};
  if(this.type==='free'||this.type==='world'||this.type==='test'||(this.type==='story'&&!cfg.mission)||cfg.cinematic){this.cd=0.01;}
  /* modo historia: la IA maneja el auto del jugador durante la cinemática */
  if(this.type==='story'&&(cfg.chapter1||cfg.cinematic)){this.cine=true;this.auto=new AIDriver(tr,pl.phys,{skill:1,lane:0,aggr:0.2});this.auto.show=!cfg.cinematic;this.auto.showK=1.2;this.auto.pref=0;}
  this.track.gripMul=(SKIES[cfg.sky]||{}).rain?0.86:1;
  this.notes=this.route&&['race','timetrial','trap'].includes(this.type)?buildPaceNotes(this.track):null;this.called=new Set();this.noteKey='';
  this.ghostKey=this.type==='timetrial'?'gskorp_ghost_'+(cfg.event?cfg.event.id:'q_'+cfg.map+'_'+(cfg.laps||1)):null;this.rec=[];this.recT=0;
  this.splits=[];this.splitIdx=0;this.ghostSplits=null;
  if(this.ghostKey){try{const gd=JSON.parse(localStorage.getItem(this.ghostKey)||'null');if(gd&&VEHICLES[gd.car]){this.makeGhost(gd);this.ghostSplits=gd.splits||null;}}catch(e){}}
  this.minimapBase=null;}
 makeGhost(gd){const V=paramsFor(gd.car,null);const vis=new VehicleVisual(VEHICLES[gd.car].visualType,V,{paint:gd.paint,lo:true});
  const cl=m=>{const c=m.clone();c.transparent=true;c.opacity=0.33;c.depthWrite=false;return c;};vis.group.traverse(o=>{if(o.isMesh)o.material=Array.isArray(o.material)?o.material.map(cl):cl(o.material);});
  this.g.scene.add(vis.group);this.ghost={gd,vis,V,pose:{px:0,py:0,pz:0,yaw:0,pitch:0,roll:0,steerAngle:0,brake:0,gear:1,wheels:[0,1,2,3].map(()=>({s:V.comHeight-V.wheelRadius,omega:0}))}};vis.group.visible=false;}
 updateGhost(dt){const G=this.ghost,f=G.gd.f,n=f.length/6;const k=this.time/G.gd.dt;const i=Math.floor(k);if(this.state==='countdown'||i>=n-1){G.vis.group.visible=this.state==='countdown'&&n>0;if(this.state==='countdown'&&n>0){const P=G.pose;P.px=f[0];P.py=f[1];P.pz=f[2];P.yaw=f[3];G.vis.update(P,0);}return;}
  const u=k-i,a=i*6,b=a+6,P=G.pose;const L=(x,y)=>x+(y-x)*u;P.px=L(f[a],f[b]);P.py=L(f[a+1],f[b+1]);P.pz=L(f[a+2],f[b+2]);let dy=f[b+3]-f[a+3];dy=Math.atan2(Math.sin(dy),Math.cos(dy));P.yaw=f[a+3]+dy*u;P.pitch=L(f[a+4],f[b+4]);P.roll=L(f[a+5],f[b+5]);
  const sp=Math.hypot(f[b]-f[a],f[b+2]-f[a+2])/G.gd.dt;for(const w of P.wheels)w.omega=sp/G.V.wheelRadius;G.vis.group.visible=Math.hypot(P.px-this.player.phys.px,P.pz-this.player.phys.pz)>2.5;G.vis.update(P,dt);}
 placeGrid(){const tr=this.track,N=tr.samples?tr.samples.length:1;
  if(this.type==='story'){/* el jugador adelante; los perseguidores atrás, en fila */let k=0;for(const c of this.cars){const back=c.isPlayer?0:16+k*9,lat=c.isPlayer?0:[-2.2,2.2,0][k%3];if(!c.isPlayer)k++;let i=this.s0,acc=0;while(acc<back){const j=(i-1+N)%N;acc+=tr.samples[i].distanceTo(tr.samples[j]);i=j;}
    const s=tr.samples[i],l=tr.laterals[i],tg=tr.tangents[i];c.pose={x:s.x+l.x*lat,z:s.z+l.z*lat,yaw:Math.atan2(tg.x,tg.z)};c.phys.pose=c.pose;c.phys.reset(c.pose);if(c.ai)c.ai.hint=i;}if(this.auto)this.auto.hint=this.s0;return;}
  if(!this.route){const pl=this.player.phys;const sp=this.cfg.spawn||null;pl.pose=sp;pl.reset(sp);pl.pose=null;return;}
  const idxBack=m=>{let i=this.s0,acc=0;while(acc<m){const j=(i-1+N)%N;acc+=tr.samples[i].distanceTo(tr.samples[j]);i=j;}return i;};
  const n=this.cars.length;const order=[...this.cars.slice(1),this.cars[0]];/* el jugador larga último */
  order.forEach((c,k)=>{const row=Math.floor(k/2),col=k%2;const back=6+row*8.5+(col?3:0);const i=idxBack(back);const s=tr.samples[i],l=tr.laterals[i],tg=tr.tangents[i];
   const side=(n===1?0:(col?1:-1))*Math.min(tr.halfWidth*0.5,2.2);c.pose={x:s.x+l.x*side,z:s.z+l.z*side,yaw:Math.atan2(tg.x,tg.z)};c.phys.pose=c.pose;c.phys.reset(c.pose);if(c.ai)c.ai.hint=i;});}
 arcPos(c){const tr=this.track;tr._hint=c.phys.trackHint;const n=tr.nearest(c.phys.px,c.phys.pz);c.phys.trackHint=tr._hint;const i=n.idx,N=tr.samples.length;return {s:tr.cum[i]+n.t*(tr.cum[i+1]-tr.cum[i]),lat:n.lateral,idx:i};}
 initProg(c){const a=this.arcPos(c);let d=a.s-this.track.cum[this.s0];if(d>this.L/2)d-=this.L;if(d<-this.L/2)d+=this.L;c.prog=d;c.lastS=a.s;}
 updateProg(c,h){const a=this.arcPos(c);c.lat=a.lat;c.idx=a.idx;let ds=a.s-c.lastS;if(ds<-this.L/2)ds+=this.L;if(ds>this.L/2)ds-=this.L;const sp=Math.hypot(c.phys.vx,c.phys.vz);ds=Math.min(ds,sp*h*1.3+0.6);c.prog+=ds;c.lastS=a.s;}
 /* ─── banderas (rush / mundo abierto) ─── */
 /* auto extra manejado por la sesión (rivales del mundo abierto) */
 makeCar(id,paint,name){const game=this.g,st=newCarState(id);st.paint={...st.paint,...paint};st.tires='gravel';const V=buildParams(VEHICLES[id],st,{abs:true,tc:50,stab:45});const ph=new Physics(this.track,V);
  const vis=new VehicleVisual(VEHICLES[id].visualType,V,{paint:st.paint,lo:true});game.scene.add(vis.group);const car={name,phys:ph,vis,color:st.paint.body};car.shadow=game.makeShadow();
  try{const cr=vis.cabinOpen?new Crew(VEHICLES[id].visualType,this.cars.length+5):{ok:false};if(cr.ok){cr.group.position.y=-V.comHeight+(V.rideOffset||0);vis.group.add(cr.group);car.crew=cr;}}catch(e){console.warn('tripulación',e);}
  const tag=new THREE.Sprite(new THREE.SpriteMaterial({map:canvasTex(256,64,(c2,W,H)=>{c2.fillStyle='rgba(8,12,18,.72)';c2.fillRect(4,8,W-8,H-16);c2.fillStyle=st.paint.body;c2.fillRect(14,22,8,20);c2.fillStyle='#fff';c2.font='800 26px system-ui';c2.textBaseline='middle';c2.fillText(name,32,33);}),depthTest:false,transparent:true}));
  tag.scale.set(3.2,0.8,1);tag.renderOrder=5;game.scene.add(tag);car.tag=tag;return car;}
 buildFlags(cfg){const tr=this.track;this.flags=[];const n=cfg.flags||0;if(!n)return;let seed=(cfg.seed||7)*9301;const rnd=()=>{seed=(seed*9301+49297)%233280;return seed/233280;};
  const pts=[];let tries=0;while(pts.length<n&&tries++<600){const x=(rnd()*2-1)*360,z=(rnd()*2-1)*360;if(Math.hypot(x,z-40)<60)continue;if(pts.some(p=>Math.hypot(p.x-x,p.z-z)<90))continue;pts.push({x,z});}
  const poleM=new THREE.MeshStandardMaterial({color:0xdddddd,metalness:0.5,roughness:0.4});const flagM=new THREE.MeshBasicMaterial({color:0xff6a08,side:THREE.DoubleSide});const beamM=new THREE.MeshBasicMaterial({color:0xffa24a,transparent:true,opacity:0.18,depthWrite:false});
  for(const p of pts){const g=new THREE.Group();const y=tr.ground(p.x,p.z);g.position.set(p.x,y,p.z);
   const pole=new THREE.Mesh(new THREE.CylinderGeometry(0.07,0.09,5,6),poleM);pole.position.y=2.5;g.add(pole);
   const fl=new THREE.Mesh(new THREE.PlaneGeometry(1.6,1),flagM);fl.position.set(0.8,4.4,0);g.add(fl);
   const beam=new THREE.Mesh(new THREE.CylinderGeometry(2.2,2.2,70,16,1,true),beamM);beam.position.y=35;g.add(beam);
   tr.group.add(g);this.flags.push({x:p.x,z:p.z,g,fl,got:false});}}
 /* ─── mundo abierto: carteles rompibles y radares ─── */
 buildWorld(){const tr=this.track,st=PROFILE.d.stats;this.boards=[];this.traps=[];
  const BP=[[-300,-250],[-150,-60],[40,170],[210,-40],[320,120],[-250,190],[90,-260],[-60,300],[280,-300],[-340,40],[150,330],[0,-120]];
  const bt=canvasTex(256,128,(c,w,h)=>{c.fillStyle='#0d1117';c.fillRect(0,0,w,h);c.fillStyle='#ff6a08';c.fillRect(0,h-18,w,18);c.fillStyle='#fff';c.font='italic 900 44px system-ui';c.textAlign='center';c.fillText('GSKORP',w/2,62);c.font='800 18px system-ui';c.fillStyle='#37b6ff';c.fillText('RALLY',w/2,90);});
  const bm=new THREE.MeshBasicMaterial({map:bt,side:THREE.DoubleSide}),legM=new THREE.MeshStandardMaterial({color:0x444a52});
  BP.forEach(([x,z],i)=>{if(st.boards[i])return;const y=tr.ground(x,z);const g=new THREE.Group();g.position.set(x,y,z);g.rotation.y=i*1.3;
   const pan=new THREE.Mesh(new THREE.PlaneGeometry(3.2,1.6),bm);pan.position.y=2.2;g.add(pan);for(const sd of [-1,1]){const leg=new THREE.Mesh(new THREE.BoxGeometry(0.12,1.6,0.12),legM);leg.position.set(sd*1.2,0.8,0);g.add(leg);}
   tr.group.add(g);this.boards.push({i,x,z,g,pan,hit:false,vy:0,vx:0,vz:0,spin:0});});
  const TP=[[-200,-180,'asphalt'],[120,60,'asphalt'],[-220,140,'dirt'],[240,-200,'dirt']];
  TP.forEach(([x,z],i)=>{const y=tr.ground(x,z);const g=new THREE.Group();g.position.set(x+6,y,z);const pole=new THREE.Mesh(new THREE.CylinderGeometry(0.08,0.08,3.2,6),legM);pole.position.y=1.6;g.add(pole);
   const cam=new THREE.Mesh(new THREE.BoxGeometry(0.5,0.35,0.6),new THREE.MeshStandardMaterial({color:0xffc83d}));cam.position.y=3.2;g.add(cam);tr.group.add(g);this.traps.push({i,x,z,cool:0});});}
 /* ─── colisiones entre autos y contra obstáculos ─── */
 collide(){const cs=this.cars;
  const circ=c=>{const p=c.phys,V=p.V,f=[Math.sin(p.yaw),Math.cos(p.yaw)],r=Math.max(V.trackF,1.6)/2+0.2,half=(V.wheelBase+1.3)/2-r;return [[p.px+f[0]*half,p.pz+f[1]*half,r],[p.px-f[0]*half,p.pz-f[1]*half,r]];};
  for(let i=0;i<cs.length;i++)for(let j=i+1;j<cs.length;j++){const A=cs[i].phys,B=cs[j].phys;if(Math.abs(A.px-B.px)>9||Math.abs(A.pz-B.pz)>9)continue;
   const ca=circ(cs[i]),cb=circ(cs[j]);for(const a of ca)for(const b of cb){const dx=b[0]-a[0],dz=b[1]-a[1],d=Math.hypot(dx,dz),min=a[2]+b[2];if(d>=min||d<1e-4)continue;
    const nx=dx/d,nz=dz/d,pen=min-d,ma=A.V.mass,mb=B.V.mass,wa=mb/(ma+mb),wb=ma/(ma+mb);A.px-=nx*pen*wa;A.pz-=nz*pen*wa;B.px+=nx*pen*wb;B.pz+=nz*pen*wb;
    const vn=(B.vx-A.vx)*nx+(B.vz-A.vz)*nz;if(vn<0){const jn=-(1.25)*vn/(1/ma+1/mb);A.vx-=jn/ma*nx;A.vz-=jn/ma*nz;B.vx+=jn/mb*nx;B.vz+=jn/mb*nz;
     const cx=(a[0]+b[0])/2,cz=(a[1]+b[1])/2;A.yawRate+=((cz-A.pz)*(-jn*nx)-(cx-A.px)*(-jn*nz))/A.V.Izz;B.yawRate+=((cz-B.pz)*(jn*nx)-(cx-B.px)*(jn*nz))/B.V.Izz;
     if(cs[i].isPlayer||cs[j].isPlayer){this.g.hitFx(Math.abs(vn));{const P=cs[i].isPlayer?A:B,O=cs[i].isPlayer?B:A,sg=cs[i].isPlayer?1:-1,vp=(P.vx*nx+P.vz*nz)*sg,vo=-(O.vx*nx+O.vz*nz)*sg;if(-vn>1.2)this.g.copilot.event('hit',{imp:-vn,byRival:vo>vp+1});}if(this.type==='story'){const o=cs[i].isPlayer?cs[j]:cs[i];if(o.ai&&-vn>1.2)o.ai.ramCd=1.6+Math.random();if(this.onHit)this.onHit(-vn,o);
      if(!this.cine&&this.state==='run'){this.hurt(this.player.phys,Math.max(0,-vn-1)*0.026);}}}}}}
  const cols=this.track.colliders;if(cols){for(const car of cs){const p=car.phys;for(const [cx,cz,r] of circ(car)){const ix=Math.floor(cx/12),iz=Math.floor(cz/12);
    for(let a=-1;a<=1;a++)for(let b=-1;b<=1;b++){const list=cols.get((ix+a)+','+(iz+b));if(!list)continue;for(const [tx,tz,tr] of list){const dx=cx-tx,dz=cz-tz,d=Math.hypot(dx,dz),mn=r+tr;if(d>=mn||d<1e-4)continue;
     const nx=dx/d,nz=dz/d;p.px+=nx*(mn-d);p.pz+=nz*(mn-d);const vn=p.vx*nx+p.vz*nz;if(vn<0){const tx2=-nz,tz2=nx,vt=p.vx*tx2+p.vz*tz2;p.vx-=1.15*vn*nx;p.vz-=1.15*vn*nz;p.vx-=tx2*vt*0.35;p.vz-=tz2*vt*0.35;
      p.yawRate+=((cz-p.pz)*(-vn*nx)-(cx-p.px)*(-vn*nz))*p.V.mass/p.V.Izz*0.6;
      if(car.isPlayer&&-vn>2){const imp=-vn;this.g.hitFx(imp*1.5);this.g.copilot.event('hit',{imp,wall:true});if(this.cfg.type!=='free'&&this.cfg.type!=='test'&&this.cfg.type!=='world'&&!this.cine){this.hurt(p,Math.max(0,imp-3)*0.022);}if(imp>9&&!this.cine)this.g.toast(imp>16?'💥 ¡Golpe fuerte!':'💥 ¡Golpe!','');}}}}}}}
  /* paredes e islas de la trinchera: rebote seco, raspón y daño */
  const tr=this.track;if(tr.wallPush){for(const car of cs){const p=car.phys;tr._hint=p.trackHint;for(const [cx,cz,r] of circ(car)){const w=tr.wallPush(cx,cz,r*0.9);if(!w)continue;
    p.px+=w.nx*w.pen;p.pz+=w.nz*w.pen;const vn=p.vx*w.nx+p.vz*w.nz;if(vn<0){const tx=-w.nz,tz=w.nx,vt=p.vx*tx+p.vz*tz;p.vx-=1.2*vn*w.nx;p.vz-=1.2*vn*w.nz;p.vx-=tx*vt*0.08;p.vz-=tz*vt*0.08;
     p.yawRate+=((cz-p.pz)*(-vn*w.nx)-(cx-p.px)*(-vn*w.nz))*p.V.mass/p.V.Izz*0.5;
     if(car.isPlayer&&-vn>2){const imp=-vn;this.g.hitFx(imp*1.3);this.g.copilot.event('hit',{imp,wall:true});if(this.cfg.type!=='free'&&this.cfg.type!=='test'&&this.cfg.type!=='world'&&!this.cine){this.hurt(p,Math.max(0,imp-3)*0.018);}if(imp>9&&!this.cine)this.g.toast(imp>16?'💥 ¡Contra la pared!':'💥 ¡Rozaste la pared!','');}}}}}
  if(tr.cones)for(const car of cs)tr.cones.collide(car.phys,circ(car));
  const obs=this.track.obstacles;if(obs){const pl=this.player,p=pl.phys;for(const [cx,cz,r] of circ(pl))for(const o of obs){const qx=Math.max(o.x-o.hw,Math.min(cx,o.x+o.hw)),qz=Math.max(o.z-o.hl,Math.min(cz,o.z+o.hl));const dx=cx-qx,dz=cz-qz,d=Math.hypot(dx,dz);
    if(d<r&&d>1e-4){const nx=dx/d,nz=dz/d;p.px+=nx*(r-d);p.pz+=nz*(r-d);const vn=p.vx*nx+p.vz*nz;if(vn<0){p.vx-=1.3*vn*nx;p.vz-=1.3*vn*nz;}
     if(this.touchCd<=0){this.touches++;this.touchCd=1.0;this.g.hitFx(Math.abs(vn)+1);this.g.toast(this.cfg.hard?'¡Tocaste! Evento perdido':'¡Toque! +3 s','');if(this.cfg.hard&&this.state==='run')this.finish(false);}}}}}
 /* daño al auto del jugador (en la historia: tope por golpe y medio segundo de gracia entre golpes) */
 hurt(p,d){if(d<=0)return;if(this.type==='story'){if((this.hurtCd||0)>0)return;d=Math.min(0.22,d);this.hurtCd=0.5;}p.damage=Math.min(1,(p.damage||0)+d);}
 /* ─── paso fijo ─── */
 fixed(h,input){const pl=this.player;
  if(this.introHold){for(const c of this.cars){c.phys.step(h,{throttle:0,brake:0,steer:0,handbrake:true});c.phys.vx*=0.5;c.phys.vz*=0.5;}return;}
  if(this.state==='countdown'){this.cd-=h;const k=Math.ceil(this.cd);if(k<this.lastBeep&&k>0){this.lastBeep=k;this.g.bigMsg(String(k));this.g.sfx('beep');}
   if(this.cd<=0){this.state='run';if(this.auto)this.auto.enabled=true;if(this.cfg.type!=='free'&&this.cfg.type!=='world'&&this.cfg.type!=='test'&&this.cfg.type!=='story'){this.g.bigMsg('¡YA!','go');this.g.sfx('go');if(this.g.copilot.ready&&this.g.copilot.enabled)this.g.copilot.event('go');else if(this.notes&&this.notes.length)this.g.voice(['vamos'],'vamos');}for(const c of this.cars)if(c.ai)c.ai.enabled=true;}}
  const running=this.state==='run'||this.state==='done';
  if(this.state==='countdown'){for(const c of this.cars){c.phys.step(h,{throttle:0,brake:0,steer:0,handbrake:true});c.phys.vx*=0.5;c.phys.vz*=0.5;}return;}
  for(const c of this.cars){let inp;if(c.sleep)continue;
   if(c.isPlayer&&this.playerHold)inp={throttle:0,brake:1,steer:0,handbrake:true};
   else if(c.isPlayer&&this.cine&&this.state==='run'){inp=this.auto.update(h,this.cars.map(o=>o.phys),this.time);}
   else if(c.isPlayer){inp=this.state==='countdown'?{throttle:input.throttle,brake:1,steer:input.steer,handbrake:true}:(this.state==='done'&&this.cfg.type!=='world'?{throttle:0,brake:0.4,steer:input.steer}:input);}
   else inp=(this.type==='story'&&this.time<0.9)?{throttle:0,brake:1,steer:0,handbrake:false}:c.ai.update(h,this.cars.map(o=>o.phys),this.time);
   c.phys.step(h,inp);}
  this.collide();if(this.touchCd>0)this.touchCd-=h;if(this.hurtCd>0)this.hurtCd-=h;
  if(!running)return;
  this.time+=h;
  if(this.ghostKey&&this.state==='run'){this.recT+=h;if(this.recT>=0.1-1e-6){this.recT-=0.1;const q=pl.phys,r=v=>Math.round(v*100)/100;this.rec.push(r(q.px),r(q.py),r(q.pz),r(q.yaw),r(q.pitch),r(q.roll));}}
  const sp=Math.hypot(pl.phys.vx,pl.phys.vz);pl.maxKmh=Math.max(pl.maxKmh,sp*3.6);this.g.odo+=sp*h;
  if(this.route&&this.ghostKey&&this.state==='run'){while(this.splitIdx<9&&pl.prog>=this.raceLen*(this.splitIdx+1)/10){this.splits.push(this.time);const gs=this.ghostSplits&&this.ghostSplits[this.splitIdx];if(gs!=null){const d=this.time-gs;this.lastDelta=d;this.g.splitMsg(d);this.g.copilot.event('split',{d});}this.splitIdx++;}}
  if(this.route&&this.type==='race'&&this.state==='run'){const pos=this.standings().indexOf(pl)+1;if(this.lastPos&&pos!==this.lastPos&&this.time>3){if(pos<this.lastPos)this.g.toast(`⬆ ¡Pasaste! Vas ${pos}°`,'green');else this.g.toast(`⬇ Te pasaron · ${pos}°`,'');this.g.copilot.event('pos',{from:this.lastPos,to:pos});}this.lastPos=pos;
   if(this.laps>1&&!this.lastLapShown&&pl.prog>=this.L*(this.laps-1)){this.lastLapShown=true;this.g.bigMsg('ÚLTIMA VUELTA');this.g.copilot.event('lastlap');}}
  if(this.route)for(const c of this.cars){if(c.finished)continue;this.updateProg(c,h);
   if(['race','timetrial','trap'].includes(this.type)&&c.prog>=this.raceLen){c.finished=true;c.finishTime=this.time;if(c.isPlayer){if(this.type==='trap'){this.trapKmh=Math.round(sp*3.6);}this.finish(true);}}
   if(c.ai){/* goma elástica suave: nadie se escapa demasiado */const gap=c.prog-pl.prog;c.ai.boost=this.type==='story'?(gap>4?0.82:gap<-90?1.2:gap<-35?1.15:1):gap>140?0.93:gap<-160?1.05:1;}}
  /* cinemática: tu auto (IA) no se escapa de los perseguidores, así se ven juntos */
  if(this.cine&&this.auto&&this.cars.some(c=>c.ai)){let gmin=1e9,hv=0;for(const c of this.cars)if(c.ai){const gp=pl.prog-c.prog;if(gp<gmin){gmin=gp;hv=Math.hypot(c.phys.vx,c.phys.vz);}}this.auto.boost=gmin>45?0.85:gmin>28?0.92:1;this.auto.maxV=this.time<2?0:gmin>40?Math.max(12,hv-3):gmin>24?hv+0.5:0;}
  /* modo historia: el perseguidor que quedó muy lejos reaparece atrás tuyo (fuera de cámara) */
  if(this.type==='story'&&this.state==='run'&&this.time>3){this.catchT=(this.catchT||0)+h;if(this.catchT>1){this.catchT=0;const tr=this.track,N=tr.samples.length,psp=Math.hypot(pl.phys.vx,pl.phys.vz);
   for(const c of this.cars){if(c.ai)c.ai.gentle=this.cine;if(!c.ai||pl.prog-c.prog<(this.cine?110:80))continue;const back=(this.cine?62:48)+Math.random()*10;let i=pl.idx||0,acc=0;while(acc<back){const j=(i-1+N)%N;acc+=tr.samples[i].distanceTo(tr.samples[j]);i=j;}
    if(this.cars.some(o=>o!==c&&Math.hypot(o.phys.px-tr.samples[i].x,o.phys.pz-tr.samples[i].z)<8))continue;const cp=this.g.camera.position;if(Math.hypot(cp.x-tr.samples[i].x,cp.z-tr.samples[i].z)<45)continue;
    const lo=tr.laneFix?tr.laneFix(i,c.ai.laneT||0,c.ai.pref):0,L=tr.laterals[i],s=tr.samples[i],t=tr.tangents[i],yaw=Math.atan2(t.x,t.z);c.phys.reset({x:s.x+L.x*lo,z:s.z+L.z*lo,yaw});c.phys.vx=Math.sin(yaw)*psp;c.phys.vz=Math.cos(yaw)*psp;c.phys.trackHint=i;c.ai.hint=i;c.ai.ramCd=0;
    const a=this.arcPos(c);c.prog=pl.prog-acc;c.lastS=a.s;break;}}}
  if(this.type==='story'&&this.state==='run'){if(!this.cine&&(pl.phys.damage||0)>=1){this.failed=true;this.finish(false);}else if(pl.prog>=this.raceLen){pl.finished=true;pl.finishTime=this.time;this.finish(true);}}
  if(this.route&&this.state==='run'){const i=pl.idx||0,tg=this.track.tangents[i],v=pl.phys.vx*tg.x+pl.phys.vz*tg.z;this.wrongT=v<-3?(this.wrongT||0)+h:0;const w=this.wrongT>1;if(w!==this.wrongShown){this.wrongShown=w;$('subMsg').textContent=w?'⚠ SENTIDO CONTRARIO':'';}}
  if(this.type==='drift')this.driftStep(h);
  if(this.type==='parking'&&this.state==='run'){const p=pl.phys,sp2=Math.hypot(p.vx,p.vz);const ok=this.track.checkParked(p.px,p.pz,p.yaw,sp2);this.parkT=ok?(this.parkT||0)+h:0;$('parkOk').classList.toggle('show',this.parkT>0.1);if(this.parkT>0.6)this.finish(true);}
  if(this.flags&&this.flags.length){for(const f of this.flags){if(f.got)continue;if(Math.hypot(pl.phys.px-f.x,pl.phys.pz-f.z)<7){f.got=true;f.g.visible=false;this.g.sfx('coin');this.g.copilot.event('flag');const left=this.flags.filter(x=>!x.got).length;this.g.toast(left?`🚩 Bandera · faltan ${left}`:'🚩 ¡Todas las banderas!','green');if(this.type==='rush'&&!left)this.finish(true);}}}
  if(this.cfg.mission&&this.type==='timetrial'&&this.state==='run'&&this.cfg.timeLimit&&this.time>this.cfg.timeLimit){this.finish(false);}
  if(this.type==='rush'&&this.state==='run'&&this.time>=this.cfg.time)this.finish(false);
  if(this.type==='drift'&&this.state==='run'&&this.time>=this.cfg.time){this.bankDrift();this.finish(true);}
  if(this.type==='world')this.worldStep(h);
  if(this.state==='done'){this.doneT+=h;if(this.doneT>Math.max(this.type==='race'?3.2:2.2,this.holdResults||0)&&!this.result)this.buildResult();}}
 driftStep(h){const d=this.drift,p=this.player.phys,sp=Math.hypot(p.vx,p.vz);const beta=Math.abs(Math.atan2(p.vLat,Math.max(0.5,Math.abs(p.vLong))));
  let off=false;if(this.route){const hw=this.track.halfWidth+this.track.shoulder;off=Math.abs(this.player.lat||0)>hw+1;}
  if(this.state!=='run')return;
  if(off&&d.cur>0){d.cur=0;d.mult=1;d.combo=0;this.g.toast('Afuera: combo perdido','');}
  if(sp>6&&beta>0.17&&beta<1.7&&p.contacts>=2&&!off){d.cur+=h*sp*beta*57.3*0.11*d.mult;d.combo+=h;d.idle=0;d.mult=Math.min(5,1+Math.floor(d.combo/2.2));}
  else{d.idle+=h;if(d.idle>0.8&&d.cur>0)this.bankDrift();}}
 bankDrift(){const d=this.drift;if(!d||d.cur<=0)return;const pts=Math.round(d.cur);d.total+=pts;if(pts>600)this.g.toast(`🌀 +${pts.toLocaleString('es-AR')} pts`,'blue');d.cur=0;d.mult=1;d.combo=0;}
 worldStep(h){const p=this.player.phys,st=PROFILE.d.stats;const sp=Math.hypot(p.vx,p.vz);
  for(const b of this.boards){if(b.hit){b.g.position.x+=b.vx*h;b.g.position.z+=b.vz*h;b.g.position.y+=b.vy*h;b.vy-=9.8*h;b.g.rotation.x+=b.spin*h;b.t=(b.t||0)+h;if(b.t>2.5)b.g.visible=false;continue;}
   if(Math.hypot(p.px-b.x,p.pz-b.z)<3.6&&sp>4){b.hit=true;this.g.copilot.event('board');b.vx=p.vx*0.7;b.vz=p.vz*0.7;b.vy=6;b.spin=6;st.boards[b.i]=1;PROFILE.earn(400);const ups=PROFILE.addXP(120);this.g.sfx('coin');const got=Object.keys(st.boards).length;
    this.g.toast(`💥 Cartel GSKORP ${got}/12 · +$400`,'green');for(const u of ups)this.g.toast(`⭐ ¡Nivel ${u.level}! +$${u.bonus}`,'blue');}}
  for(const t of this.traps){if(t.cool>0){t.cool-=h;continue;}if(Math.hypot(p.px-t.x,p.pz-t.z)<11&&sp>8){t.cool=4;const kmh=Math.round(sp*3.6);const best=st.traps[t.i]||0;const th=[90,130,170];const starsNow=th.filter(v=>kmh>=v).length,starsOld=th.filter(v=>best>=v).length;
    if(kmh>best)st.traps[t.i]=kmh;let msg=`📸 RADAR ${kmh} km/h ${'⭐'.repeat(starsNow)}`;if(starsNow>starsOld){const pay=(starsNow-starsOld)*500;PROFILE.earn(pay);PROFILE.addXP(80*(starsNow-starsOld));msg+=` · +$${pay}`;this.g.sfx('coin');}else PROFILE.save();this.g.toast(msg,starsNow>starsOld?'green':'');}}}
 respawn(){const pl=this.player;this.g.copilot.event('respawn');if(this.route){const a=this.arcPos(pl);const N=this.track.samples.length,i=(a.idx+1)%N,s=this.track.samples[i],tg=this.track.tangents[i];const lo=this.track.laneFix?this.track.laneFix(i,a.lat||0):0,L=this.track.laterals[i];pl.phys.reset({x:s.x+L.x*lo,z:s.z+L.z*lo,yaw:Math.atan2(tg.x,tg.z)});pl.phys.trackHint=i;}else{const p=pl.phys;p.reset({x:p.px,z:p.pz,yaw:p.yaw});}}
 finish(ok){if(this.state==='done')return;$('subMsg').textContent='';
  if(ok&&this.ghostKey&&this.player.finishTime){try{const old=JSON.parse(localStorage.getItem(this.ghostKey)||'null');if(!old||this.player.finishTime<old.t){const id=currentVehicleId,st=this.g.testState||PROFILE.car;localStorage.setItem(this.ghostKey,JSON.stringify({t:this.player.finishTime,car:id,paint:st&&st.paint,dt:0.1,f:this.rec,splits:this.splits}));this.newGhost=true;}}catch(e){}}this.state='done';this.doneT=0;this.ok=ok;const pl=this.player;if(this.g.copilot.ready&&this.g.copilot.enabled){this.g.codriver.stop();this.g.copilot.event('finish',{ok,record:!!this.newGhost,pos:this.type==='race'?this.standings().findIndex(c=>c.isPlayer)+1:0});}else if(ok&&this.notes&&this.notes.length){this.g.codriver.stop();this.g.voice(['meta'],'meta, buen tramo');}
  if(this.cfg.mission){const r=this.missionResult(ok);this.mres=r;const good=r.stars>0;this.g.bigMsg(this.cfg.cinematic?'':good?'¡MISIÓN CUMPLIDA!':'MISIÓN FALLIDA',good?'go':'');if(this.director)this.holdResults=this.director.end(good);}
  else if(this.type==='story'){this.g.bigMsg(ok?'¡ESCAPASTE!':'¡TE ATRAPARON!',ok?'go':'');if(this.director)this.director.end(ok);}
  else if(this.type==='race'){const pos=this.standings().findIndex(c=>c.isPlayer)+1;this.g.bigMsg(pos===1?'¡GANASTE!':`${pos}°`,pos===1?'go':'');}
  else if(ok)this.g.bigMsg('¡LISTO!','go');else this.g.bigMsg(this.type==='rush'?'¡TIEMPO!':'¡PERDISTE!');
  this.g.sfx('finish');$('parkOk').classList.remove('show');}
 /* lo que mide el juego para las estrellas de la misión */
 missionResult(ok){const m=this.cfg.mission,pl=this.player,t=this.type;const hp=Math.max(0,Math.round(100-(pl.phys.damage||0)*100));
  const r={hp,time:pl.finishTime||this.time,pos:t==='race'?this.standings().indexOf(pl)+1:0,kmh:this.trapKmh||0,left:t==='rush'?Math.max(0,Math.round(this.cfg.time-this.time)):0,park:this.time+this.touches*3};
  r.ok=ok&&!(t==='timetrial'&&this.cfg.timeLimit&&r.time>this.cfg.timeLimit)&&!(t==='race'&&r.pos!==1)&&!(t==='trap'&&m.stars.kmh&&r.kmh<m.stars.kmh[0]);r.stars=missionStars(m,r);return r;}
 finishCinematic(){if(this.state!=='done'){this.player.finishTime=this.time;this.finish(true);}}
 standings(){return [...this.cars].sort((a,b)=>{if(a.finished&&b.finished)return a.finishTime-b.finishTime;if(a.finished)return -1;if(b.finished)return 1;return (b.prog||0)-(a.prog||0);});}
 buildResult(){const t=this.type,pl=this.player,cfg=this.cfg;let value=null,title='',line='',sub='',rows=null;
  if(t==='race'){const st=this.standings();const pos=st.indexOf(pl)+1;value=pos;title=pos===1?'¡Victoria!':`${pos}° puesto`;
   rows=st.map(c=>{let time=c.finishTime;if(!c.finished){const v=Math.max(8,Math.hypot(c.phys.vx,c.phys.vz));time=this.time+(this.raceLen-c.prog)/v;}return {name:c.name,time,me:c.isPlayer,dnf:false};});
   rows.sort((a,b)=>a.time-b.time);line=`Tiempo ${fmtTime(pl.finishTime)}`;}
  else if(t==='timetrial'){value=pl.finishTime;title=fmtTime(value);line='Tiempo final';}
  else if(t==='parking'){value=this.time+this.touches*3;title=this.ok?fmtTime(value):'Descalificado';line=this.ok?`${this.touches} toque${this.touches===1?'':'s'} (+${this.touches*3} s)`:'Tocaste un auto o la pared';if(!this.ok)value=999;}
  else if(t==='drift'){value=Math.round(this.drift.total);title=value.toLocaleString('es-AR')+' pts';line='Puntaje de drift';}
  else if(t==='rush'){value=this.ok?Math.max(0,Math.round(this.cfg.time-this.time)):0;title=this.ok?`${value} s de sobra`:'Se acabó el tiempo';line=`${this.flags.filter(f=>f.got).length}/${this.flags.length} banderas`;}
  else if(t==='trap'){value=this.trapKmh||0;title=value+' km/h';line='Velocidad en el radar';}
  else if(t==='story'){const hp=Math.max(0,Math.round(100-(pl.phys.damage||0)*100));value=this.ok?hp:0;title=this.ok?'¡Escapaste de la mina!':'Misión fallida';line=this.ok?`Llegaste a la salida con el auto al ${hp}%`:'El auto quedó destrozado: te atraparon';sub=this.ok?'':'Esquivá las embestidas: frená o abrite cuando se te pegan';}
  if(cfg.mission){const m=cfg.mission,r=this.mres||this.missionResult(this.ok);const st=starText(m);const f=x=>fmtTime(x);
   title=r.stars>0?m.title:'Misión fallida';line=cfg.cinematic?'Escena completa':t==='race'?`Terminaste ${r.pos}° · auto al ${r.hp}%`:t==='story'?(r.stars>0?`Llegaste con el auto al ${r.hp}%`:'Te atraparon'):t==='timetrial'?`Tiempo ${f(r.time)}`:t==='trap'?`${r.kmh} km/h en el radar`:t==='rush'?(r.stars>0?`${r.left} s de sobra`:'Se acabó el tiempo'):t==='parking'?(r.stars>0?`${f(r.park)}`:'Tocaste algo'):'';
   this.result={type:t,value:r.stars,title,line,sub:'',standings:rows,maxKmh:Math.round(pl.maxKmh),mission:m.id,stars:r.stars,starText:st,chapter:m.chapter};this.g.showResults(this.result);return;}
  this.result={type:t,value,title,line,sub,standings:rows,maxKmh:Math.round(pl.maxKmh),soon:false,next:t==='story'&&this.ok?'c2m1':null};this.g.showResults(this.result);}
}

/* ═══ JUEGO ═══ */
class Game{
 constructor(){
  this.canvas=$('game');this.renderer=new THREE.WebGLRenderer({canvas:this.canvas,antialias:false,powerPreference:'high-performance'});this.renderer.setSize(innerWidth,innerHeight);this.renderer.outputColorSpace=THREE.SRGBColorSpace;this.renderer.toneMapping=THREE.ACESFilmicToneMapping;this.renderer.toneMappingExposure=1.05;
  this.scene=new THREE.Scene();this.scene.background=new THREE.Color(0x9ec0d2);this.scene.fog=new THREE.Fog(0x9ec0d2,180,900);
  this.camera=new THREE.PerspectiveCamera(CAMERAS[CAM_INDEX].fov,innerWidth/innerHeight,.15,2500);this.addLights();
  this.showroom=new Showroom(this.renderer);this.post=new PostFX(this.renderer);
  this.track=null;this.session=null;this.car=null;this.physics=null;this.shadows=[];
  this.input=new Input();this.cameraRig=null;this.fx=new Effects(this.scene);this.audio=new AudioEngine();this.codriver=new CoDriver();
  this.acc=0;this.last=performance.now();this.state='menu';this.fixed=1/120;this.fpsFrames=0;this.fpsAccum=0;this.fps=0;this.odo=0;
  this.rpmFill=$('rpmFill');this.customLocked=false;
  const api={profile:PROFILE,sfx:n=>this.sfx(n),unlockAudio:()=>{this.audio.init();this.audio.resume();this.applySettings();this.musicCheck();},
   perf:(id,st)=>{const pf=perfOf(paramsFor(id,st));return pf;},params:(id,st)=>paramsFor(id,st),base:id=>VEHICLES[id],
   showCar:(id,st)=>{this.showroom.setCar(id,st);},carChanged:()=>{const id=PROFILE.d.current;this.showroom.setCar(id,PROFILE.car);},
   onScreen:n=>this.onScreen(n),startEvent:ev=>this.startEvent(ev),startQuick:q=>this.startQuick(q),testDrive:id=>this.testDrive(id),openWorld:()=>this.openWorld(),startStory:()=>this.startStory(),startMission:id=>this.startMission(id),
   mapName:id=>(MAPS[id]||{}).name||id,mapList:()=>Object.entries(MAPS).filter(([id,m])=>!m.hidden).map(([id,m])=>({id,...m})),applySettings:()=>this.applySettings(),postSupported:()=>this.post.supported,canExitToWorld:()=>!!(this.cfg&&this.cfg.fromWorld),toWorld:()=>this.exitTrench(),previewVisual:id=>{this.previewFx=id;if(this.post)this.post.setPreset(id||PROFILE.d.settings.visual||'none');this.fxStageOn=!!id&&!this.session;if(this.fxStageOn){if(!this.fxStage)this.fxStage=new FxStage();this.fxStage.setCar(PROFILE.d.current||'t1plus',PROFILE.car);}},autoLevel:()=>effQuality(PROFILE.d.settings),
   toggleGyro:async()=>{if(this.input.gyroEnabled){this.input.disableGyro();return {};}const r=await this.input.enableGyro();return r.ok?{}:{err:r.err};},gyroOn:()=>this.input.gyroEnabled,recalGyro:()=>this.input.recalibrateGyro(),gyroValue:()=>this.input.gyroSteer,gyroInvert:()=>!!PROFILE.d.settings.gyroInvert,setGyroInvert:v=>{PROFILE.d.settings.gyroInvert=!!v;PROFILE.save();this.input.gyroInvert=!!v;},
   resume:()=>this.resume(),editHud:()=>this.openHudEditor(),respawn:()=>{if(this.session){this.session.respawn();this.resume();}},canRespawn:()=>!!(this.session&&this.session.type!=='parking'),restart:()=>this.retry(),quit:()=>this.quit(),nextCam:()=>{this.nextCamera();},prevCam:()=>{this.nextCamera(-1);},camName:()=>CAMERAS[CAM_INDEX].name,afterResults:n=>this.afterResults(n),retry:()=>this.retry()};
  this.music=new Music(this.audio);
  this.ui=new UI(api);
  this.bind();this.applySettings();
  addEventListener('resize',()=>this.resize());this.resize();
  this.ui.show('splash');
  const tick=setInterval(()=>{this.ui.splashProgress(ASSET_PROGRESS/10,false);},120);
  ASSETS_READY.then(()=>{clearInterval(tick);this.ui.splashProgress(1,true);if(PROFILE.d.current)this.showroom.setCar(PROFILE.d.current,PROFILE.car);else this.showroom.setCar('t1plus',null);});
  requestAnimationFrame(t=>this.loop(t));}
 addLights(){this.hemi=new THREE.HemisphereLight(0xd9e9ff,0x4b4132,1.1);this.scene.add(this.hemi);this.sun=new THREE.DirectionalLight(0xfff0d2,1.6);this.sun.position.set(120,160,80);this.scene.add(this.sun);this.scene.add(this.sun.target);const sc=this.sun.shadow.camera;sc.left=-22;sc.right=22;sc.top=22;sc.bottom=-22;sc.near=1;sc.far=400;this.sun.shadow.bias=-0.0006;this.sun.shadow.normalBias=0.03;this.setSky('day');}
 setSky(id){const k=SKIES[id]||SKIES.day;if(this.skyId===id)return;this.skyId=id;this.scene.background=new THREE.Color(k.bg);this.scene.fog=new THREE.Fog(k.bg,k.fog[0],k.fog[1]);
  this.hemi.color.set(k.hemi[0]);this.hemi.groundColor.set(k.hemi[1]);this.hemi.intensity=k.hemi[2];this.sun.color.set(k.sun[0]);this.sun.intensity=k.sun[1];this.sun.position.set(...k.sunPos);this.renderer.toneMappingExposure=k.exp;this.skyDome(k);this.sunDir=new THREE.Vector3(...k.sunPos).normalize();this.sunPower=k.rain?0.15:k.zen==='#7b8792'?0.3:id==='dusk'?0.85:1;this.hazeCol=new THREE.Color().setHex(parseInt(k.bg.slice(1),16),THREE.LinearSRGBColorSpace);this.isRain=!!k.rain;if(!this.rain)this.buildRain();this.rain.visible=!!k.rain;this.audio&&this.audio.rainSet(!!k.rain);
  const env=canvasTex(256,128,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h);g.addColorStop(0,k.env[0]);g.addColorStop(0.48,k.env[1]);g.addColorStop(0.52,k.env[2]);g.addColorStop(1,k.env[3]);c.fillStyle=g;c.fillRect(0,0,w,h);c.fillStyle=k.disc;c.beginPath();c.arc(w*0.3,h*0.22,9,0,7);c.fill()});
  env.mapping=THREE.EquirectangularReflectionMapping;const pm=new THREE.PMREMGenerator(this.renderer);if(this.scene.environment)this.scene.environment.dispose();this.scene.environment=pm.fromEquirectangular(env).texture;pm.dispose();env.dispose();}
 buildRain(){const N=1400;const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.BufferAttribute(new Float32Array(N*6),3));this.rain=new THREE.LineSegments(g,new THREE.LineBasicMaterial({color:0xb8cadb,transparent:true,opacity:0.42,depthWrite:false}));this.rain.frustumCulled=false;this.rain.visible=false;this.scene.add(this.rain);this.rainP=[];for(let i=0;i<N;i++)this.rainP.push([(Math.random()-.5)*56,Math.random()*28,(Math.random()-.5)*56]);}
 updateRain(dt){if(!this.rain||!this.rain.visible)return;const c=this.camera.position,a=this.rain.geometry.attributes.position.array;for(let i=0;i<this.rainP.length;i++){const q=this.rainP[i];q[1]-=dt*24;if(q[1]<-5){q[1]+=28;q[0]=(Math.random()-.5)*56;q[2]=(Math.random()-.5)*56;}const x=c.x+q[0],y=c.y+q[1],z=c.z+q[2],j=i*6;a[j]=x;a[j+1]=y;a[j+2]=z;a[j+3]=x+0.04;a[j+4]=y+0.75;a[j+5]=z+0.02;}this.rain.geometry.attributes.position.needsUpdate=true;}
 skyDome(k){if(!this.dome){this.dome=new THREE.Mesh(new THREE.SphereGeometry(1500,32,16),new THREE.MeshBasicMaterial({side:THREE.BackSide,fog:false,depthWrite:false}));this.dome.renderOrder=-1;this.scene.add(this.dome);}
  const old=this.dome.material.map;const sd=new THREE.Vector3(...k.sunPos).normalize();const su=(Math.atan2(sd.x,sd.z)/(2*Math.PI)+0.5),sv=0.5-Math.asin(sd.y)/Math.PI;
  const tex=canvasTex(1024,512,(c,w,h)=>{const g=c.createLinearGradient(0,0,0,h/2);g.addColorStop(0,k.zen);g.addColorStop(1,k.bg);c.fillStyle=g;c.fillRect(0,0,w,h/2);c.fillStyle=k.bg;c.fillRect(0,h/2,w,h/2);
   const sx=su*w,sy=sv*h;const rg=c.createRadialGradient(sx,sy,2,sx,sy,k.rain?60:140);rg.addColorStop(0,k.disc);rg.addColorStop(0.12,k.disc.replace(/[\d.]+\)$/,'0.5)'));rg.addColorStop(1,'rgba(255,255,255,0)');c.fillStyle=rg;c.fillRect(0,0,w,h/2+20);
   let seed=7;const r=()=>{seed=(seed*16807)%2147483647;return seed/2147483647;};const nc=k.rain?70:k.zen==='#7b8792'?60:26;
   for(let i=0;i<nc;i++){const x=r()*w,y=h*0.12+r()*h*0.32,rw=40+r()*120,rh=8+r()*18;const a=k.rain?0.22:0.16+r()*0.2;c.fillStyle=k.rain||k.zen==='#7b8792'?`rgba(170,178,186,${a})`:`rgba(255,255,255,${a})`;for(let j=0;j<5;j++){c.beginPath();c.ellipse(x+(r()-.5)*rw,y+(r()-.5)*rh,rw*(0.3+r()*0.4),rh*(0.5+r()*0.5),0,0,7);c.fill();}}});
  tex.mapping=THREE.UVMapping;this.dome.material.map=tex;this.dome.material.needsUpdate=true;if(old)old.dispose();}
 makeShadow(){if(!this._shTex)this._shTex=canvasTex(64,64,(x)=>{const g=x.createRadialGradient(32,32,3,32,32,30);g.addColorStop(0,'rgba(0,0,0,.55)');g.addColorStop(1,'rgba(0,0,0,0)');x.fillStyle=g;x.fillRect(0,0,64,64)});
  const m=new THREE.Mesh(new THREE.PlaneGeometry(2.8,5.4),new THREE.MeshBasicMaterial({map:this._shTex,transparent:true,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-5}));m.rotation.order='YXZ';m.rotation.x=-Math.PI/2;this.scene.add(m);this.shadows.push(m);return m;}
 sfx(n){try{sfxPlay(this.audio,n)}catch(e){}}
 toast(m,c){this.ui.toast(m,c);}
 updateNotes(S,p){const set=PROFILE.d.settings,el=$('paceNote');if(!set.notes){el.innerHTML='';return;}
  const L=S.L,base=S.track.cum[S.s0],P=S.player.prog,sp=Math.hypot(p.vx,p.vz),D=45+sp*3.4;const up=[];const lap=Math.floor(Math.max(0,P)/L);
  for(const lp of [lap,lap+1])for(const o of S.notes){const np=((o.s-base)%L+L)%L+lp*L;const d=np-P;if(d>-8&&d<Math.max(D,160)&&np<=S.raceLen+5)up.push({o,d,key:lp+'_'+o.idx});}
  up.sort((a,b)=>a.d-b.d);const show=up.filter(u=>u.d<D).slice(0,2);
  const key=show.map(u=>u.key).join('|');if(key!==S.noteKey){S.noteKey=key;el.innerHTML=show.map((u,i)=>`<div class="pn ${i?'next':''}" style="border-color:${noteColor(u.o)}"><b style="color:${noteColor(u.o)}">${noteShort(u.o)}</b><span>${u.o.text}${u.o.into?' ›':''}</span></div>`).join('');
   if(this.cockpit)this.cockpit.drawNotes(up.slice(0,7).map(u=>u.o.text));}
  for(const u of show)if(!S.called.has(u.key)){S.called.add(u.key);this.callNote(u.o);}}
 callNote(o){this.voice(noteKeys(o),noteSpeech(o));}
 /* voz grabada (offline); si no cargó, sintetizador del sistema */
 voice(keys,text){const s=PROFILE.d.settings;if(!s.copilot)return;const cd=this.codriver;if(this.audio.ctx&&!cd.loading)cd.load(this.audio.ctx);
  if(cd.ready){this.copilot.hold(this.audio.ctx.currentTime+0.1);cd.say(keys,Math.min(1,s.volume/80));this.copilot.hold(cd.busyUntil);return;}if(cd.failed||!cd.loading)this.speak(text);}
 speak(t){const s=PROFILE.d.settings;if(!s.copilot||!('speechSynthesis' in window))return;try{const ss=window.speechSynthesis;if(ss.speaking&&ss.pending)ss.cancel();const u=new SpeechSynthesisUtterance(t);u.lang='es-AR';u.rate=1.3;u.pitch=0.95;u.volume=Math.min(1,s.volume/80);
  if(!this._voice){const vs=ss.getVoices();this._voice=vs.find(v=>/es-(AR|419|MX|US)/i.test(v.lang))||vs.find(v=>/^es/i.test(v.lang))||null;}if(this._voice)u.voice=this._voice;ss.speak(u);}catch(e){}}
 splitMsg(d){const e=$('subMsg');e.textContent=(d<0?'−':'+')+Math.abs(d).toFixed(2)+' s';e.style.color=d<0?'#3ddc84':'#ff4d5e';clearTimeout(this._sm);this._sm=setTimeout(()=>{e.textContent='';e.style.color='';},1800);}
 bigMsg(t,cls){const e=$('centerMsg');e.textContent=t;e.className='anim '+(cls||'');void e.offsetWidth;e.className='anim '+(cls||'');clearTimeout(this._bm);this._bm=setTimeout(()=>{e.textContent='';e.className='';},950);}
 hitFx(v){if(v>2.5&&PROFILE.d.settings.vibrate&&navigator.vibrate)try{navigator.vibrate(Math.min(80,v*10))}catch(e){}if(v>1.5)this.audio.thump&&this.audio.thump(Math.min(1,v/8));}
 /* ¿un punto está en cámara? (para no animar lo que no se ve) */
 inView(x,y,z,r){const f=this._frus||(this._frus=new THREE.Frustum());if(this._fmN!==this.frameN){this._fmN=this.frameN;const m=this._fm||(this._fm=new THREE.Matrix4());m.multiplyMatrices(this.camera.projectionMatrix,this.camera.matrixWorldInverse);f.setFromProjectionMatrix(m);}const sp=this._sph||(this._sph=new THREE.Sphere());sp.center.set(x,y,z);sp.radius=r;return f.intersectsSphere(sp);}
 /* mundo abierto ↔ Trinchera */
 enterTrench(){if(this._portalBusy)return;this._portalBusy=true;const sky=this.cfg&&this.cfg.sky;this.toast('⛏️ Entrando a La Trinchera…','blue');setTimeout(()=>{this._portalBusy=false;this.launch({type:'free',map:'trinchera',sky:sky||'day',fromWorld:true});},350);}
 exitTrench(){const w=this.worldPortal;this.launch({type:'world',map:'offroad',sky:(this.cfg&&this.cfg.sky)||PROFILE.d.stats.worldSky||'day',flags:0,spawn:w?w.exit:null});}
 checkPortal(){const tr=this.track;if(!tr||!tr.portal||this.state!=='race')return;this.worldPortal=tr.portal;const p=this.physics,P=tr.portal,d=Math.hypot(p.px-P.x,p.pz-P.z);
  if(d<40&&!this._portalHint){this._portalHint=true;this.toast('⛏️ Entrada a La Trinchera: metete en la mina','blue');}if(d>60)this._portalHint=false;
  if(d<6&&(p.vx*P.tx+p.vz*P.tz)>1)this.enterTrench();}
 /* modo Optimizar: mide los FPS en carrera y baja (o sube una vez) la calidad; lo aprende para la próxima */
 autoTune(){const s=PROFILE.d.settings;if(s.quality!=='auto'||this.state!=='race'||!this.fps)return;const a=this._at||(this._at={t:0,sum:0,n:0,ups:0});a.sum+=this.fps;a.n++;a.t+=0.5;if(a.t<8)return;
  const avg=a.sum/a.n;a.t=0;a.sum=0;a.n=0;const L=['baja','media','alta'],cur=effQuality(s),i=L.indexOf(cur);let ni=i;
  if(avg<44&&i>0)ni=i-1;else if(avg>58&&i<2&&a.ups<1){ni=i+1;a.ups++;}
  if(ni!==i){s.autoLevel=L[ni];PROFILE.save();this.applySettings();this.toast('⚡ Calidad ajustada: '+{baja:'Baja',media:'Media',alta:'Máxima'}[L[ni]],'blue');}}
 /* 'Cámara de acción cruda': bruma verdosa (lineal, mismo shader que el juego → sin recompilar) y vibración solo durante el dibujado; después se deja todo como estaba */
 rawBegin(S=this.scene,c=this.camera){const R=this._raw||(this._raw={pos:new THREE.Vector3(),q:new THREE.Quaternion(),fog:new THREE.Fog(0x8fa88f,8,210),bg:new THREE.Color(),tint:new THREE.Color(0x8fa88f)});
  R.cam=c;R.S=S;R.pos.copy(c.position);R.q.copy(c.quaternion);R.oldFog=S.fog;R.oldBg=S.background;R.dome=this.dome&&this.dome.visible;
  if(S.fog&&S.fog.color)R.fog.color.copy(S.fog.color).lerp(R.tint,0.6);S.fog=R.fog;R.bg.copy(R.fog.color);S.background=R.bg;if(this.dome&&S===this.scene)this.dome.visible=false;
  /* vibración de cámara en mano: ondas suaves + un poco de temblor, regulable en Opciones (100 = la de antes) */
  const k=(PROFILE.d.settings.rawShake??25)/100;if(k>0){const t=performance.now()/1000,r=Math.random,w=(a,b,c)=>Math.sin(t*a+c)*0.7+Math.sin(t*b+c*1.7)*0.3;
   c.position.x+=(w(5.3,13.1,0.2)*0.05+(r()-0.5)*0.05)*k;c.position.y+=(w(6.1,15.7,1.1)*0.05+(r()-0.5)*0.05)*k;c.position.z+=(r()-0.5)*0.06*k;
   c.rotation.z+=(w(4.7,11.3,2.3)*0.007+(r()-0.5)*0.008)*k;c.rotation.x+=(w(5.9,12.7,0.7)*0.004+(r()-0.5)*0.004)*k;c.rotation.y+=(r()-0.5)*0.004*k;}c.updateMatrixWorld();}
 rawEnd(){const R=this._raw,c=R.cam,S=R.S;c.position.copy(R.pos);c.quaternion.copy(R.q);c.updateMatrixWorld();S.fog=R.oldFog;S.background=R.oldBg;if(this.dome&&S===this.scene)this.dome.visible=R.dome;}
 /* dibujo con el efecto elegido (incluye el estilo 'cámara de acción cruda', que va por CSS + bruma + vibración) */
 renderPost(scene,cam,info){const raw=this.post.preset==='accion';if(raw!==!!this.rawOn){this.rawOn=raw;document.body.classList.toggle('rawcam',raw);this.applySettings();}
  if(raw)this.rawBegin(scene,cam);this.post.render(scene,cam,info);if(raw)this.rawEnd();}
 /* cámara "detrás del piloto": pantalla de cámara trasera arriba al centro (usa la misma imagen del espejo, sin costo extra) */
 rearCamOn(){return PROFILE.d.settings.rearCam===true&&!(this.session&&this.session.cine);}
 rearScreen(){const ck=this.cockpit;if(!ck||!this.rearCamOn()||!ck.mirrorRT)return;
  let M=this._rs;if(!M){const sc=new THREE.Scene(),cam=new THREE.OrthographicCamera(-1,1,1,-1,0,1);const fr=new THREE.Mesh(new THREE.PlaneGeometry(1,1),new THREE.MeshBasicMaterial({color:0x0b0e13,depthTest:false}));
   const q=new THREE.Mesh(new THREE.PlaneGeometry(1,1),new THREE.MeshBasicMaterial({map:ck.mirrorRT.texture,depthTest:false}));q.renderOrder=1;sc.add(fr,q);M=this._rs={sc,cam,fr,q};}
  if(M.q.material.map!==ck.mirrorRT.texture){M.q.material.map=ck.mirrorRT.texture;M.q.material.needsUpdate=true;}
  const W=innerWidth,H=innerHeight,w=Math.min(0.5,300/W*2),h=w*W/(256/96)/H;M.q.scale.set(w,h,1);const top=this.inside?0.05:Math.min(0.45,112/H*2);M.q.position.set(0,1-top-h/2,0);M.fr.scale.set(w+8/W*2,h+8/H*2,1);M.fr.position.copy(M.q.position);
  const r=this.renderer,ac=r.autoClear;r.autoClear=false;r.setRenderTarget(null);r.render(M.sc,M.cam);r.autoClear=ac;}
 musicCheck(){if(!this.music)return;const want=PROFILE.d.settings.music&&(this.state==='menu'||this.state==='results');if(want)this.music.start();else this.music.stop();}
 applySettings(){const s=PROFILE.d.settings;if(this.copilot)this.copilot.configure(s);this.musicCheck&&this.musicCheck();tune.steerMode=s.steerMode;tune.gameSpeed=s.gameSpeed;tune.gyroSensitivity=s.gyroSens;GYRO_TILT_FOR_FULL=55-s.gyroSens*0.40;this.input.gyroInvert=!!s.gyroInvert;
  document.body.classList.toggle('slider-mode',s.steerMode==='slider');document.body.classList.toggle('manual',s.gearbox==='manual');if(this.physics)this.physics.manual=s.gearbox==='manual';const Q=effQuality(s);QUALITY=Q;
  let pr={baja:0.7,media:Math.min(devicePixelRatio,1.25),alta:Math.min(devicePixelRatio,1.75)}[Q]||1;if(this.rawOn)pr=Math.min(pr,1)/1.2;this.renderer.setPixelRatio(pr);this.renderer.setSize(innerWidth,innerHeight);if(this.fx)this.fx.setScale(innerHeight,pr);
  if(this.audio.master)this.audio.master.gain.value=SND.master*(s.volume/80);this.audio.mix={eng:(s.volEngine??100)/100,surf:(s.volSurf??30)/100,wind:(s.volWind??30)/100};
  if(this.post&&!this.previewFx&&this.post.preset!==(s.visual||'none'))this.post.setPreset(s.visual||'none');
  if(this.cockpit&&this.cockpit.setMirrors)this.cockpit.setMirrors(s.mirrors!==false);applyHud(s.hudLayout);
  const shOn=Q!=='baja'&&s.shadows!==false;if(this.renderer.shadowMap.enabled!==shOn){this.renderer.shadowMap.enabled=shOn;this.renderer.shadowMap.type=THREE.PCFShadowMap;}this.sun.castShadow=shOn;const ms=Q==='alta'?2048:1024;if(this.sun.shadow.mapSize.x!==ms){this.sun.shadow.mapSize.set(ms,ms);if(this.sun.shadow.map){this.sun.shadow.map.dispose();this.sun.shadow.map=null;}}
  if(this.physics&&this.session){const id=currentVehicleId;const st=this.testState||PROFILE.d.owned[id];const V=paramsFor(id,st);Object.assign(VEH,V);this.physics.setup();}}
 onScreen(n){this.ui.inRace=this.state==='paused';this.musicCheck();this.showroom.off={home:0,starter:-1.3,garage:-1.3,dealer:-1.3,paint:-1.3,tuning:-1.5,workshop:-2.2}[n]??0;}
 bind(){
  /* la app pasa a segundo plano (botón inicio, llamada): pausa y silencio total */
  document.addEventListener('visibilitychange',()=>{try{if(document.hidden){if(this.state==='race'&&!this.loadingOn)this.pause();if(this.audio.ctx&&this.audio.ctx.state==='running')this.audio.ctx.suspend();}else if(this.state!=='paused')this.audio.resume();}catch(e){}});
  $('camBtn').onclick=()=>this.nextCamera();$('camLockBtn').onclick=()=>this.lockCamera();$('pauseBtn').onclick=()=>this.pause();
  const nb=$('nitroBtn');const non=e=>{e.preventDefault();this.input.nitroTouch=true;nb.classList.add('active');},noff=()=>{this.input.nitroTouch=false;nb.classList.remove('active');};
  nb.addEventListener('pointerdown',non,{passive:false});nb.addEventListener('pointerup',noff);nb.addEventListener('pointercancel',noff);nb.addEventListener('pointerleave',noff);
  this._setupCustomCamDrag();
  const cv=this.canvas;cv.addEventListener('pointerdown',e=>{if(this.state==='menu')this.showroom.pointer(e,'down');});addEventListener('pointermove',e=>{if(this.state==='menu')this.showroom.pointer(e,'move');});addEventListener('pointerup',e=>{if(this.state==='menu')this.showroom.pointer(e,'up');});
  $('ui').addEventListener('pointerdown',e=>{if(this.state==='menu'&&(e.target.classList.contains('scr')||e.target.classList.contains('homeC')||e.target.classList.contains('split')||e.target.parentElement&&e.target.parentElement.classList.contains('split')&&!e.target.classList.contains('panelBox')))this.showroom.pointer(e,'down');});
  addEventListener('keydown',e=>{if(this.state==='race'){if(e.code==='KeyR')this.retry();if(e.code==='KeyP'){STATE.debug=!STATE.debug;$('debug').style.display=STATE.debug?'block':'none'}if(e.code==='KeyC')this.nextCamera();if(e.code==='Escape')this.pause();if(e.code==='KeyN')this.input.nitroKey=true;}});
  addEventListener('keyup',e=>{if(e.code==='KeyN')this.input.nitroKey=false;});

  const wake=()=>{this.audio.init();this.audio.resume();if(this.audio.master)this.audio.master.gain.value=SND.master*(PROFILE.d.settings.volume/80);};addEventListener('pointerdown',wake);addEventListener('keydown',wake);}
 setHud(on){for(const id of ['hud','speedPanel','touch','menu'])$(id).classList.toggle('off',!on);if(!on){$('paceNote').innerHTML='';document.body.classList.remove('inside');}else this.camVis();if(!on){$('driftPanel').classList.remove('on');$('parkOk').classList.remove('show');$('centerMsg').textContent='';document.body.classList.remove('cam-edit');}}
 /* ─── arrancar sesiones ─── */
 startEvent(ev){const tier=TIERS.find(t=>t.id===ev.tier);const cfg={type:ev.type,map:ev.map,laps:ev.laps,seg:ev.seg,ai:ev.ai||0,time:ev.time,flags:ev.flags,sky:ev.sky,hard:ev.hard,maxPI:tier.maxPI,skill:tier.skill*(ev.final?1.03:1),aiCar:tier.car,event:ev,tier,seed:ev.id.charCodeAt(1)};this.launch(cfg);}
 startQuick(q){const cfg={type:q.mode==='free'?'free':q.mode,map:q.map,laps:q.laps,ai:q.mode==='race'?q.ai:0,sky:q.sky,time:q.mode==='drift'?90:undefined,maxPI:Math.max(560,perfOf(VEH).pi+20),skill:0.9*q.skill,quick:true,seed:7};if(q.seg)cfg.seg=q.seg;
  if(cfg.type==='timetrial'&&MAPS[q.map].kind!=='route')cfg.type='free';if(cfg.type==='drift'&&MAPS[q.map].kind==='route'){cfg.seg=null;}this.launch(cfg);}
 testDrive(id){this.testState=newCarState(id);this.launch({type:'test',map:'offroad',sky:'day',testCar:id});}
 startStory(){const id=PROFILE.d.current||'t1plus';let pi=999;try{pi=perfOf(paramsFor(id,PROFILE.car)).pi;}catch(e){}this.launch({type:'story',map:'escape',seg:[0.012,0.83],ai:3,skill:1,sky:'day',maxPI:pi,chapter1:true});}
 /* misiones del modo historia: cada tipo usa un modo del juego */
 startMission(id){if(id==='c1')return this.startStory();const m=MISSION_BY_ID[id];if(!m)return;const car=PROFILE.d.current||'t1plus';let pi=999;try{pi=perfOf(paramsFor(car,PROFILE.car)).pi;}catch(e){}
  const T={escape:'story',cinematica:'story',carrera:'race',contrarreloj:'timetrial',radar:'trap',banderas:'rush',estacionar:'parking'};
  const cfg={type:T[m.type],map:m.map,sky:m.sky||'day',mission:m,ai:m.ai||0,skill:m.skill||0.88,maxPI:pi+20,seed:m.chapter*3};
  if(m.seg)cfg.seg=m.seg;if(m.laps)cfg.laps=m.laps;if(m.boss)cfg.bossName=m.boss;if(m.bossSkill)cfg.bossSkill=m.bossSkill;if(m.hunterK)cfg.hunterK=m.hunterK;if(m.hunterCar)cfg.aiCar=m.hunterCar;
  if(m.type==='cinematica')cfg.cinematic=true;if(m.type==='banderas'){cfg.flags=m.flags;cfg.time=m.time;}if(m.type==='contrarreloj')cfg.timeLimit=m.stars.time[0];
  this.launch(cfg);}
 setCam(i){CAM_INDEX=i;if(this.cameraRig)this.cameraRig.setPreset(i);this.camVis();}
 getCam(){return CAM_INDEX;}
 settingsVolume(){return PROFILE.d.settings.volume??80;}
 gearboxManual(){return PROFILE.d.settings.gearbox==='manual';}
 openWorld(){this.launch({type:'world',map:'offroad',sky:PROFILE.d.stats.worldSky||'day',flags:0});}
 /* ─── pantalla de carga: se muestra ANTES de armar la pista (así se ve mientras carga), con consejos;
    después se dibujan unos cuadros ocultos para subir texturas y shaders y recién ahí arranca ─── */
 /* ¿sugerir ajuste? (carreras y misiones; no en paseo, mundo abierto, prueba, estacionar ni cinemáticas) */
 setupFor(cfg){if(PROFILE.d.settings.askSetup===false||cfg.testCar||!PROFILE.car||cfg.chapter1||cfg.cinematic)return null;const t=cfg.type;
  if(!(['race','timetrial','drift','trap','rush'].includes(t)||(cfg.mission&&t!=='parking')))return null;const m=MAPS[cfg.map]||{};
  const rec=t==='drift'||m.kind==='drift'?'drift':m.kind==='offroad'||m.mode==='dirt'?'tierra':'asfalto';
  return {rec,mapName:m.name||'',surfName:{drift:'la plaza de drift',tierra:m.kind==='offroad'?'campo abierto y tierra':'tierra',asfalto:'asfalto'}[rec]};}
 launch(cfg){if(!this.copilot)this.copilot=new CoPilot();
  if(!this.syncLaunch&&!cfg._setup&&!this.loadingOn){const inf=this.setupFor(cfg);if(inf){cfg._setup=true;this.ui.setupPicker(inf,id=>{if(id&&PROFILE.car){const car=PROFILE.car;car.tune={...(car.tune||{}),...PRESETS[id]};PROFILE.save();}this.launch(cfg);});return;}}
  if(this.syncLaunch){this._launchNow(cfg);return;}if(this.loadingOn)return;
  const L=this.load={cfg,t0:performance.now(),min:this._launchedOnce?2600:3400,frames:0,built:false,tipI:0,tips:tipsFor(cfg.story||cfg.type==='story'?'story':cfg.type)};this._launchedOnce=true;this.loadingOn=true;
  this.codriver.stop();if(this.storyVO)this.storyVO.stop();this.audioSilence();
  const TYPE={race:'CARRERA',timetrial:'CONTRARRELOJ',drift:'DRIFT',parking:'ESTACIONAMIENTO',rush:'BANDERAS',trap:'RADAR',free:'MANEJO LIBRE',world:'MUNDO ABIERTO',test:'PRUEBA DE MANEJO',story:'MODO HISTORIA · CAPÍTULO 1'};
  const ev=cfg.event,id=cfg.testCar||PROFILE.d.current||'t1plus';$('lsMode').textContent=TYPE[cfg.type]||'CARGANDO';$('lsTitle').textContent=cfg.type==='story'?'LA FUGA':ev?ev.name:(MAPS[cfg.map]||{}).name||'GSKORP RALLY';
  $('lsSub').textContent=(VEHICLES[id]||{}).name||'';$('lsDots').innerHTML=L.tips.slice(0,6).map(()=>'<i></i>').join('');this.showTip(0);
  const el=$('loadScr');el.classList.remove('out');el.classList.add('on');$('lsFill').style.width='8%';$('lsSt').textContent='Preparando el auto…';
  clearInterval(this._tipTimer);this._tipTimer=setInterval(()=>{if(!this.loadingOn)return;L.tipI=(L.tipI+1)%L.tips.length;this.showTip(L.tipI);},4200);
  requestAnimationFrame(()=>requestAnimationFrame(()=>{$('lsFill').style.width='22%';$('lsSt').textContent='Construyendo la pista…';setTimeout(()=>{
   this._launchNow(cfg);L.built=true;this.state='loading';$('lsFill').style.width='70%';$('lsSt').textContent='Cargando texturas y efectos…';},60);}));}
 showTip(i){const L=this.load,t=L.tips[i%L.tips.length],box=$('lsTip');box.classList.add('fade');setTimeout(()=>{$('lsIco').textContent=t[1];$('lsCat').textContent=t[0].toUpperCase();$('lsTT').textContent=t[2];$('lsTx').textContent=t[3];box.classList.remove('fade');
   const d=$('lsDots').children;for(let k=0;k<d.length;k++)d[k].classList.toggle('on',k===i%d.length);},i?300:0);}
 loadingStep(){const L=this.load;if(!L||!L.built)return;L.frames++;if(this.cameraRig&&this.physics)this.cameraRig.update(1/60,this.physics);
  const el=performance.now()-L.t0,k=Math.min(1,el/L.min);$('lsFill').style.width=Math.round(70+30*Math.min(k,L.frames/10))+'%';if(L.frames>6)$('lsSt').textContent='¡Listo! Calentando motores…';
  if(el>=L.min&&L.frames>=10){this.loadingOn=false;clearInterval(this._tipTimer);this.state='race';this.last=performance.now();this.acc=0;this.audio.resume();const ls=$('loadScr');ls.classList.add('out');setTimeout(()=>{if(!this.loadingOn)ls.classList.remove('on');},480);}}
 _launchNow(cfg){try{if(this.audio.ctx)this.codriver.load(this.audio.ctx);this.cfg=cfg;const id=cfg.testCar||PROFILE.d.current||'t1plus';if(!cfg.testCar)this.testState=null;const st=(cfg.testCar?this.testState:PROFILE.car)||newCarState(id);
  setPlayerCar(id,st);this.cleanupSession();this.setSky(cfg.sky||'day');
  if(this.car){this.car.dispose();this.scene.remove(this.car.group);}
  if(this.cockpit){this.cockpit.dispose();this.cockpit=null;}
  this.car=new VehicleVisual(VEHICLES[id].visualType,VEH,{paint:st.paint,lo:QUALITY==='baja'});this.scene.add(this.car.group);this.makeShadow();
  this.cockpit=new Cockpit(VEHICLES[id].visualType,VEH,st.paint);this.cockpit.units=PROFILE.d.settings.units;this.cockpit.setMirrors(PROFILE.d.settings.mirrors!==false);this.cockpit.root.position.y=-VEH.comHeight+(VEH.rideOffset||0);this.car.group.add(this.cockpit.root);this.cockpit.crew.position.copy(this.cockpit.root.position);this.car.group.add(this.cockpit.crew);
  this.session=new Session(this,cfg);this.track=this.session.track;this.physics=this.session.player.phys;this.physics.manual=PROFILE.d.settings.gearbox==='manual';this.timeScale=1;
  if(this.renderer.shadowMap.enabled){/* sombra real solo para tu auto (en Máxima, todos); los rivales usan la sombra difusa, mucho más barata */for(const c of this.session.cars)if(c.isPlayer||QUALITY==='alta')c.vis.group.traverse(o=>{if(o.isMesh)o.castShadow=true;});this.track.group.traverse(o=>{if(o.isMesh&&!o.isInstancedMesh)o.receiveShadow=true;});}
  this.cameraRig=new CameraRig(this.camera,this.track);this.cameraRig.cockpit=this.cockpit;this.cameraRig.mount=this.mountPoints();this.camVis();
  this.acc=0;this.odo=0;this.fx.reset();
  $('nitroBtn').classList.toggle('have',VEH.nitroCap>0);
  this.state='race';this.musicCheck();this.ui.root.innerHTML='';this.setHud(true);this.hudLayout();this.buildMinimap();
  if(!this.copilot)this.copilot=new CoPilot();if(this.audio.ctx)this.copilot.load(this.audio.ctx);this.copilot.stop();this.copilot.begin(this.session,PROFILE.d.settings);
  if(cfg.chapter1){if(!this.storyVO)this.storyVO=new CoDriver('story');const S=this.session;S.director=new Director(this,S);S.onHit=(v,o)=>S.director.onHit(v,o);}
  else if(cfg.mission){if(!this.storyVoice)this.storyVoice=new StoryVoice();if(this.audio.ctx)this.storyVoice.load(this.audio.ctx);const S=this.session;S.director=new MissionDirector(this,S,cfg.mission);}
  /* compilar todos los shaders ahora (tripulaciones, trajes, pista): sin tirones la primera vez que algo entra en cámara */
  try{const hid=[];this.scene.traverse(o=>{if(o.isObject3D&&!o.visible&&(o.name==='crew'||o.isGroup)){hid.push(o);o.visible=true;}});this.renderer.compile(this.scene,this.camera);for(const o of hid)o.visible=false;}catch(e){}
  if(cfg.fromWorld)setTimeout(()=>{if(this.cfg===cfg)this.toast('⛏️ La Trinchera · para volver al mundo: ⏸ → Salir al mundo abierto','blue');},2500);
  this.audio.init();this.audio.resume();
  if(!PROFILE.d.tutorial){PROFILE.d.tutorial=true;PROFILE.save();const T=['Volante a la izquierda · pedal a la derecha: arriba GAS, abajo FRENO','Frenando a fondo parado → marcha atrás · botón H = freno de mano','❚❚ pausa: volver a la pista, cámara y opciones'];T.forEach((m,i)=>setTimeout(()=>this.toast(m,'blue'),600+i*2800));}
  if(cfg.type==='world')this.toast('Mundo abierto: rompé los 12 carteles GSKORP, pasá por los radares 📸 y buscá a los rivales en sus bases ⚔ (rombos del mapa)','blue');
  if(cfg.type==='test')this.toast('Prueba de manejo · pausa ❚❚ para salir','blue');
  }catch(err){console.error(err);this.showError(err);}}
 cleanupSession(){this.codriver.stop();if(this.copilot)this.copilot.stop();if(this.storyVO)this.storyVO.stop();if(this.session&&this.session.director){this.session.director.dispose();this.session.director=null;}this.timeScale=1;if(this.cockpit){if(this.cockpit.root.parent)this.cockpit.root.parent.remove(this.cockpit.root);this.cockpit.dispose();this.cockpit=null;}if(this.session){for(const c of this.session.cars)if(!c.isPlayer){if(c.crew)c.crew.dispose();c.vis.dispose();this.scene.remove(c.vis.group);if(c.tag){this.scene.remove(c.tag);c.tag.material.map.dispose();c.tag.material.dispose();}}if(this.session.ghost){this.session.ghost.vis.dispose();this.scene.remove(this.session.ghost.vis.group);}}
  for(const s of this.shadows){this.scene.remove(s);s.geometry.dispose();s.material.dispose();}this.shadows=[];
  if(this.track){try{this.track.dispose();}catch(e){}}this.track=null;this.session=null;this.physics=null;}
 hudLayout(){const t=this.cfg.type;const route=this.session.route;
  $('riPos').classList.toggle('off',t!=='race');$('riLap').classList.toggle('off',!(route&&this.session.laps>1&&(t==='race'||t==='timetrial')));
  $('riBest').classList.toggle('off',!['timetrial','parking','drift','rush','trap'].includes(t));$('riProg').classList.toggle('off',!route||t==='drift');
  $('raceInfo').classList.toggle('off',t==='test');$('minimap').classList.toggle('off',['parking','drift'].includes(t)&&!route);$('driftPanel').classList.toggle('on',t==='drift');
  const ev=this.cfg.event;const tg=ev&&TARGETS[ev.id];$('bestLbl').textContent=t==='rush'?'Banderas':'Oro';
  $('best').textContent=t==='rush'?`0/${this.cfg.flags}`:tg?(t==='drift'?tg[0].toLocaleString('es-AR'):t==='trap'?tg[0]+' km/h':fmtTime(tg[0])):'—';
  $('timeLbl').textContent=t==='rush'||t==='drift'?'Restante':'Tiempo';$('paceNote').innerHTML='';}
 /* ─── minimapa ─── */
 buildMinimap(){const cv=$('minimap'),S=this.session,tr=this.track;const ctx=cv.getContext('2d');const W=cv.width;
  let pts=[];if(S.route)pts=tr.samples.map(p=>[p.x,p.z]);else if(tr.roads){for(const r of tr.roads)pts.push(...r.pts);}else pts=[[-60,-60],[60,60]];
  let x0=1e9,x1=-1e9,z0=1e9,z1=-1e9;for(const [x,z] of pts){x0=Math.min(x0,x);x1=Math.max(x1,x);z0=Math.min(z0,z);z1=Math.max(z1,z);}
  if(!S.route&&tr.roads){x0=-420;x1=420;z0=-420;z1=420;}
  const sc=(W-24)/Math.max(x1-x0,z1-z0),ox=(W-(x1-x0)*sc)/2,oz=(W-(z1-z0)*sc)/2;this.mm={sc,x0,z0,ox,oz,W,ctx};
  const base=document.createElement('canvas');base.width=base.height=W;const b=base.getContext('2d');b.lineCap='round';b.lineJoin='round';
  const P=(x,z)=>[ox+(x-x0)*sc,W-(oz+(z-z0)*sc)];
  if(S.route){b.strokeStyle='rgba(0,0,0,.5)';b.lineWidth=7;b.beginPath();pts.forEach(([x,z],i)=>{const [u,v]=P(x,z);i?b.lineTo(u,v):b.moveTo(u,v);});b.closePath();b.stroke();b.strokeStyle='rgba(235,240,248,.9)';b.lineWidth=3;b.stroke();
   const [su,sv]=P(tr.samples[S.s0].x,tr.samples[S.s0].z);b.fillStyle='#3ddc84';b.fillRect(su-4,sv-4,8,8);if(this.cfg.seg){const [fu,fv]=P(tr.samples[S.s1].x,tr.samples[S.s1].z);b.fillStyle='#ff4d5e';b.fillRect(fu-4,fv-4,8,8);}}
  else if(tr.roads){for(const r of tr.roads){b.strokeStyle=r.surf==='asphalt'?'rgba(230,235,240,.85)':'rgba(200,160,110,.85)';b.lineWidth=3;b.beginPath();r.pts.forEach(([x,z],i)=>{const [u,v]=P(x,z);i?b.lineTo(u,v):b.moveTo(u,v);});b.stroke();}}
  this.mmBase=base;this.mmP=P;}
 drawMinimap(){const m=this.mm;if(!m)return;const {ctx,W}=m,S=this.session,P=this.mmP;ctx.clearRect(0,0,W,W);ctx.drawImage(this.mmBase,0,0);
  if(S.flags)for(const f of S.flags){if(f.got)continue;const [u,v]=P(f.x,f.z);ctx.fillStyle='#ffb020';ctx.beginPath();ctx.arc(u,v,4,0,7);ctx.fill();}
  if(S.boards)for(const b of S.boards){if(b.hit)continue;const [u,v]=P(b.x,b.z);ctx.fillStyle='#ff6a08';ctx.fillRect(u-2.5,v-2.5,5,5);}
  if(S.traps)for(const t of S.traps){const [u,v]=P(t.x,t.z);ctx.fillStyle='#ffc83d';ctx.font='10px sans-serif';ctx.fillText('📸',u-6,v+4);}
  if(S.duels)S.duels.drawMini(ctx,P);
  for(const c of S.cars){if(c.sleep)continue;const p=c.phys,[u,v]=P(p.px,p.pz);if(c.isPlayer){ctx.save();ctx.translate(u,v);ctx.rotate(-p.yaw+Math.PI);ctx.fillStyle='#ff6a08';ctx.strokeStyle='#fff';ctx.lineWidth=1.5;ctx.beginPath();ctx.moveTo(0,-7);ctx.lineTo(5,5);ctx.lineTo(-5,5);ctx.closePath();ctx.fill();ctx.stroke();ctx.restore();}
   else{ctx.fillStyle=c.color;ctx.strokeStyle='#000';ctx.lineWidth=1;ctx.beginPath();ctx.arc(u,v,4,0,7);ctx.fill();ctx.stroke();}}}
 /* ─── pausa / salir / resultados ─── */
 pause(){if(this.state!=='race')return;this.codriver.stop();if(this.storyVO)this.storyVO.stop();this.audioSilence();if(this.copilot)this.copilot.stop();try{if(this.audio.ctx&&this.audio.ctx.state==='running')this.audio.ctx.suspend();}catch(e){}this.state='paused';this.setHud(false);this.ui.inRace=true;this.ui.show('pause');}
 /* editor de controles en pantalla (desde la pausa): el juego sigue pausado mientras se acomodan */
 openHudEditor(){if(this.state!=='paused')return;this.ui.root.innerHTML='';this.setHud(true);this.hudEd=new HudEditor(PROFILE,()=>{this.hudEd=null;this.setHud(false);this.ui.show('pause');});this.hudEd.open();}
 resume(){if(this.state!=='paused')return;this.audio.resume();this.ui.root.innerHTML='';this.state='race';this.setHud(true);this.hudLayout();this.last=performance.now();}
 quit(){this.saveOdo();this.audio.resume();this.cleanupSession();if(this.car){this.car.dispose();this.scene.remove(this.car.group);this.car=null;}this.state='menu';this.setHud(false);this.ui.inRace=false;this.audio.update&&this.audioSilence();
  const back=this.cfg&&this.cfg.event?'career':this.cfg&&this.cfg.testCar?'dealer':'home';this.ui.show(back);}
 retry(){const c=this.cfg;this.saveOdo();this.ui.inRace=false;this.launch(c);}
 audioSilence(){try{const a=this.audio;if(!a.on)return;const t=a.ctx.currentTime;for(const g of [a.eng,a.roll,a.sq,a.grav,a.wind,a.tb])g.gain.setTargetAtTime(0,t,0.05);}catch(e){}}
 saveOdo(){if(this.odo>1){const km=this.odo/1000;PROFILE.d.stats.km+=km;if(!this.testState&&PROFILE.car)PROFILE.car.km+=km;this.odo=0;PROFILE.save();}}
 showResults(r){const cfg=this.cfg,ev=cfg.event;this.state='results';document.body.classList.remove('story','cine');this.setHud(false);this.audioSilence();this.saveOdo();
  const st=PROFILE.d.stats;st.events++;if(r.maxKmh>st.topSpeed)st.topSpeed=r.maxKmh;
  let medal=0,cr=0,xp=0,record=false,next='home',levelUps=[];
  if(ev){medal=medalFor(ev,r.value);const rw=rewardFor(ev,medal,cfg.tier);cr=rw.cr;xp=rw.xp;const rec=PROFILE.recordEvent(ev.id,{value:r.value,medal,lowerIsBetter:lowerIsBetter(ev.type)});record=rec.improved&&PROFILE.eventResult(ev.id).plays>1;if(rec.firstMedal&&medal===3){cr+=Math.round(cfg.tier.base*0.25);}next='career';
   if(ev.type==='race'){st.races++;if(r.value===1)st.wins++;if(r.value<=3)st.podiums++;}if(ev.type==='drift'&&r.value>st.driftBest)st.driftBest=r.value;}
  else if(cfg.mission){const m=cfg.mission,d=storyProgress(PROFILE),old=d.m[m.id]||{stars:0},first=!(old.stars>0);
   if(r.stars>old.stars){d.m[m.id]={stars:r.stars};const gain=r.stars-old.stars;cr=Math.round(m.reward*(first?1:0.5)*gain/3/50)*50+(first?Math.round(m.reward*0.4/50)*50:0);xp=Math.round(m.reward/6)*gain;
    if(first&&m.gift&&PROFILE.car){const u=PROFILE.car.upg||(PROFILE.car.upg={});const lv=u[m.gift]||0;if(lv<1){u[m.gift]=1;r.gift=m.gift;try{const U=UPG_BY_ID[m.gift];r.giftName=U.name+' · '+U.levels[1].n;}catch(e){}}}}
   else{cr=r.stars>0?150:50;xp=r.stars>0?60:20;}next='story';}
  else if(cfg.type==='story'){if(r.value>0){const sd=PROFILE.d.story||(PROFILE.d.story={});const first=!sd.ch1;sd.ch1=Math.max(sd.ch1||0,r.value);cr=first?5000:800+r.value*10;xp=first?1200:300;}else{cr=150;xp=60;}next='story';}
  else if(cfg.quick){if(cfg.type==='race'){medal=r.value===1?3:r.value===2?2:r.value===3?1:0;cr=[150,500,800,1200][medal]*(cfg.laps||1)*(1+cfg.ai/3);xp=120*(cfg.laps||1)+medal*60;}else if(cfg.type==='drift'){cr=Math.min(2500,Math.round(r.value/20));xp=Math.round(r.value/60);}else{cr=300;xp=100;}next='quick';}
  let cupMsg=null;if(ev){const T=cfg.tier;const all=EVENTS.filter(e=>e.tier===T.id).every(e=>(PROFILE.eventResult(e.id)||{}).medal>0);const cups=PROFILE.d.cups||(PROFILE.d.cups={});
   if(all&&!cups[T.id]){cups[T.id]=1;const bonus=T.base*4;cr+=bonus;xp+=1500;cupMsg=`🏆 ¡${T.name} completada! +$ ${bonus.toLocaleString('es-AR')}`;}}
  cr=Math.round(cr/10)*10;PROFILE.earn(cr);levelUps=PROFILE.addXP(xp);
  this.ui.show('results',{...r,medal,cr,xp,record,next,levelUps,cupMsg,eventName:ev?ev.name:cfg.mission?`MODO HISTORIA · CAPÍTULO ${cfg.mission.chapter}`:cfg.type==='story'?'MODO HISTORIA · CAPÍTULO 1':(MAPS[cfg.map]||{}).name,nextMission:cfg.mission?((nextMission(cfg.mission.id)||{}).id||'soon'):(cfg.chapter1&&r.value>0?'c2m1':null),showMedal:!cfg.mission&&(!!ev||cfg.type==='race'),_sm:0});
  if(cfg.chapter1&&r.soon&&this.storyVO)setTimeout(()=>{if(this.state==='results')this.storyVO.say(['proximamente']);},1400);}
 afterResults(next){this.cleanupSession();if(this.car){this.car.dispose();this.scene.remove(this.car.group);this.car=null;}this.state='menu';this.ui.inRace=false;if(next==='nextEv')this.ui.openNext();else this.ui.show(next||'home');}
 showError(err){const box=$('errorBox');box.style.display='block';box.innerHTML='<b>ERROR</b><br>'+String(err&&err.stack||err).replace(/</g,'&lt;')+'<br><button onclick="location.reload()">Recargar</button>';}
 nextCamera(dir=1){
  CAM_INDEX=(CAM_INDEX+dir+CAMERAS.length)%CAMERAS.length;const isCustom=CAM_INDEX===CAM_CUSTOM_INDEX;
  if(this.cameraRig)this.cameraRig.setPreset(CAM_INDEX);this.camVis();
  /* cámara libre: se usa manejando (sin modo edición ni botón aplicar): deslizar = mirar alrededor, pellizcar = zoom */
  this.customLocked=false;document.body.classList.remove('cam-edit');
  if(this.state==='race')this.toast(isCustom?'🎥 Cámara libre · deslizá la pantalla para mirar, pellizcá para acercar/alejar':'🎥 '+CAMERAS[CAM_INDEX].name,'blue');}
 /* puntos de cámara de capó y paragolpes medidos sobre la carrocería real (raycast), en coordenadas del auto */
 mountPoints(){const g=this.car.group,body=this.car.body,C=this.cockpit&&this.cockpit.C;g.updateWorldMatrix(true,true);const inv=g.matrixWorld.clone().invert();
  const box=new THREE.Box3(),bb=new THREE.Box3();body.traverse(o=>{if(o.isMesh&&o.geometry){if(!o.geometry.boundingBox)o.geometry.computeBoundingBox();bb.copy(o.geometry.boundingBox).applyMatrix4(o.matrixWorld).applyMatrix4(inv);box.union(bb);}});
  const ground=this.cockpit?this.cockpit.root.position.y:-VEH.comHeight;const rc=new THREE.Raycaster();const wasVis=body.visible;body.visible=true;
  const surf=(x,z)=>{const o=g.localToWorld(new THREE.Vector3(x,box.max.y+1,z)),d=new THREE.Vector3(0,-1,0).transformDirection(g.matrixWorld);rc.set(o,d);const h=rc.intersectObject(body,true)[0];return h?g.worldToLocal(h.point.clone()).y:null;};
  const cowl=C?C.cowlZ:box.max.z*0.3;let hy=null;for(const dz of [0.3,0.5,0.7,0.15]){hy=surf(0,Math.min(cowl+dz,box.max.z-0.2));if(hy!=null)break;}
  body.visible=wasVis;if(hy==null)hy=ground+(C?C.eyeY-0.35:1.0);
  return {group:g,hood:{y:Math.max(hy+0.36,ground+(C?C.eyeY-0.25:0)),z:cowl+0.02,ly:-0.22},bumper:{y:ground+0.46,z:box.max.z+0.06,ly:-0.1}};}
 camVis(){if(!this.car)return;const m=CAMERAS[CAM_INDEX].mode,inside=m==='onboard'||m==='rearcabin';document.body.classList.toggle('inside',inside);this.mounted=m==='hood'||m==='bumper';this.car.body.visible=!inside;if(this.cockpit)this.cockpit.root.visible=inside;this.inside=inside;}
 lockCamera(){this.customLocked=true;document.body.classList.remove('cam-edit');}
 _setupCustomCamDrag(){
  const el=this.canvas;
  const pointers=new Map();
  let orbitPointerId=null;
  let lastMid=null,lastDist=0;
  const isActive=()=>CAM_INDEX===CAM_CUSTOM_INDEX&&this.cameraRig;
  el.addEventListener('pointerdown',e=>{
   if(!isActive())return;
   pointers.set(e.pointerId,{x:e.clientX,y:e.clientY});
   if(pointers.size===1){orbitPointerId=e.pointerId;}
   else if(pointers.size===2){
    orbitPointerId=null;
    const arr=[...pointers.values()];
    lastMid={x:(arr[0].x+arr[1].x)/2,y:(arr[0].y+arr[1].y)/2};
    lastDist=Math.hypot(arr[0].x-arr[1].x,arr[0].y-arr[1].y);
   }
   try{el.setPointerCapture(e.pointerId)}catch(_){}
  });
  el.addEventListener('pointermove',e=>{
   if(!pointers.has(e.pointerId))return;
   const p=pointers.get(e.pointerId);
   const dx=e.clientX-p.x,dy=e.clientY-p.y;
   p.x=e.clientX;p.y=e.clientY;
   if(!isActive())return;
   if(pointers.size===1&&e.pointerId===orbitPointerId){
    // Órbita
    this.cameraRig.customYawOff-=dx*0.008;
    this.cameraRig.customElev=clamp(this.cameraRig.customElev+dy*0.006,-1.4,1.4);
   }else if(pointers.size===2){
    const arr=[...pointers.values()];
    const midX=(arr[0].x+arr[1].x)/2;
    const midY=(arr[0].y+arr[1].y)/2;
    const dist=Math.hypot(arr[0].x-arr[1].x,arr[0].y-arr[1].y);
    if(lastMid){
     const dmx=midX-lastMid.x,dmy=midY-lastMid.y;
     // Zoom (pinch)
     if(lastDist>20&&dist>20){
      this.cameraRig.customDist=clamp(this.cameraRig.customDist*lastDist/dist,2,60);
     }
     // Pan: horizontal → forward, vertical → up
     const k=Math.max(0.01,this.cameraRig.customDist*0.0045);
     this.cameraRig.customPanF+=dmx*k;
     this.cameraRig.customPanU-=dmy*k;
    }
    lastMid={x:midX,y:midY};lastDist=dist;
   }
  });
  const end=e=>{
   pointers.delete(e.pointerId);
   if(e.pointerId===orbitPointerId)orbitPointerId=null;
   if(pointers.size<2){lastMid=null;lastDist=0;}
   if(pointers.size===1){orbitPointerId=[...pointers.keys()][0];}
  };
  el.addEventListener('pointerup',end);
  el.addEventListener('pointercancel',end);
  el.addEventListener('lostpointercapture',end);
 }
 loop(now){const realDt=Math.min(.05,(now-this.last)/1000);this.last=now;
  try{
  if(this.state==='menu'||!this.session){if(this.fxStageOn&&this.fxStage){this.post.autoQuality(this.fps||60,realDt);this.fxStage.render(realDt,this);}else{if(this.rawOn){this.rawOn=false;document.body.classList.remove('rawcam');this.applySettings();}this.showroom.render(realDt);}requestAnimationFrame(t=>this.loop(t));return;}
  if(this.state==='loading')this.loadingStep();
  /* en pausa la cámara sigue viva: al cambiarla se ve cómo queda */
  if(this.state==='paused'&&this.cameraRig&&this.physics&&!(this.session.director&&this.session.cine)){this.cameraRig.update(Math.min(realDt,1/30),this.physics);if(this.cockpit&&(this.inside||this.rearCamOn())&&(this.frameN%3)===0)this.cockpit.renderMirror(this.renderer,this.scene,[this.car.group,...this.shadows],this.rearCamOn());}
  const dt=realDt*(tune.gameSpeed/100)*(this.timeScale||1);
  if(this.state==='race'&&this.physics&&this.track){
   this.acc+=dt;let steps=0;while(this.acc>=this.fixed&&steps<8){this.fixedUpdate();this.acc-=this.fixed;steps++}if(steps>=8)this.acc=0;
   const S=this.session;
   for(let i=0;i<S.cars.length;i++){const c=S.cars[i],p=c.phys;if(c.sleep)continue;c.vis.update(p,dt);if(c.crew){const cp=this.camera.position,d=Math.hypot(p.px-cp.x,p.pz-cp.z);const vis=d<70&&this.inView(p.px,p.py,p.pz,3);/* tripulación fuera de cámara: se saca del árbol de la escena (sus 100+ huesos no se recalculan) */if(vis!==c.crew._on){c.crew._on=vis;c.crew.group.visible=true;if(vis)c.vis.group.add(c.crew.group);else c.crew.group.removeFromParent();}if(vis)c.crew.update(dt,p,((this.frameN+i)%(d<25?2:4))===0);}if(c.tag){const d=Math.hypot(p.px-this.physics.px,p.pz-this.physics.pz);c.tag.visible=d>6&&d<90&&!S.cine&&!S.introHold&&!(S.type==='story'&&S.state==='done');c.tag.position.set(p.px,p.py+1.9,p.pz);}const sh=c.isPlayer?this.shadows[0]:c.shadow;if(sh){this.track._hint=p.trackHint;const g=this.track.groundInfo(p.px,p.pz).y;sh.position.set(p.px,g+0.04,p.pz);sh.rotation.y=p.yaw;}}
   this.track._hint=this.physics.trackHint;
   {const p=this.physics;let cv=0,loose=0;for(const w of p.wheels){cv+=Math.abs(w.cv||0);if(w.contact&&w.surf!=='asphalt')loose++;}const sp=Math.hypot(p.vx,p.vz);
    /* túnel: la imagen se oscurece (la vista se adapta) */
    {const tr=this.track;let inT=0;if(tr&&tr.inTunnel){tr._hint=p.trackHint;inT=tr.inTunnel(p.px,p.pz)?1:0;}this.tunnelK=(this.tunnelK||0)+(inT-(this.tunnelK||0))*(1-Math.exp(-dt*(inT?2.5:1.6)));const base=(SKIES[this.skyId]||SKIES.day).exp;this.renderer.toneMappingExposure=base*(1-0.5*this.tunnelK);}
    this.checkPortal();if(this.track&&this.track.cones)this.track.cones.update(dt);
    this.frameInfo={time:now/1000,rough:Math.min(1,cv*0.12+loose*0.08*Math.min(1,sp/15)),rain:this.isRain?1:0,stage:S.time,delta:S.lastDelta??null};
    if(this.cameraRig)this.cameraRig.info=this.frameInfo;
    if(this.cockpit){this.cockpit.setLOD(!this.inside);if(!this.inside)this.cockpit.updateCrew(dt,p,this.frameInfo);}
    if(this.inside&&this.cockpit){this.cockpit.update(dt,p,this.input,this.frameInfo);}
    if(this.cockpit&&(this.inside||this.rearCamOn())&&(this.frameN%3)===0)this.cockpit.renderMirror(this.renderer,this.scene,[this.car.group,...this.shadows],this.rearCamOn());}
   if(this.car){this.car.group.updateMatrixWorld();CAR_CUT.uCutInv.value.copy(this.car.group.matrixWorld).invert();CAR_CUT.uCutHalf.value.set((VEH.trackF||1.8)/2+0.3,VEH.comHeight+0.6,(VEH.wheelBase||2.9)/2+0.95);CAR_CUT.uCutOn.value=1;}
   if(this.cameraRig)this.cameraRig.update(dt,this.physics);if(S.director)S.director.update(dt,realDt);if(this.copilot){if(!this.copilot.loading&&this.audio.ctx)this.copilot.load(this.audio.ctx);this.copilot.update(realDt,S,this.input);}if(this.dome)this.dome.position.copy(this.camera.position);
   if(this.track.updateTape)this.track.updateTape(this.physics.position);this.updateRain(dt);if(S.ghost)S.updateGhost(dt);
   {let best=null,bd=1e9;for(const c of S.cars)if(c.ai){const d=Math.hypot(c.phys.px-this.physics.px,c.phys.pz-this.physics.pz);if(d<bd){bd=d;best=c;}}this.audio.aiUpdate(best?bd:null,best?best.phys.rpm:0,best?best.phys.V.firingOrder:4);}
   const p=this.physics;if(p.nitroActive){const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),L=VEH.wheelBase/2+0.9;for(let k=0;k<3;k++){const rr=Math.random;this.fx.spawn(p.px-fx*L+(rr()-.5)*0.3,p.py-VEH.comHeight+0.55,p.pz-fz*L+(rr()-.5)*0.3,-fx*(8+rr()*6)+p.vx*0.9,0.3+rr(),-fz*(8+rr()*6)+p.vz*0.9,0.35+rr()*0.3,0.6+rr()*0.3,1,0.9,0.35+rr()*0.25,0.18+rr()*0.12,2.5,0);}}
   this.fx.emitFrom(p,dt);for(const c of S.cars)if(c.ai&&c.phys.px!==undefined){const d=Math.hypot(c.phys.px-p.px,c.phys.pz-p.pz);if(d<40&&this.inView(c.phys.px,c.phys.py,c.phys.pz,6))this.fx.emitFrom(c.phys,dt*0.4);}this.fx.update(dt);this.audio.update(p,dt);
   for(const c of S.cars)c.phys.events.length=0;
   this.updateHud(realDt);
  }
  {const p=this.physics;let info=null;if(p){const sp=Math.hypot(p.vx,p.vz);let cv=0,loose=0;for(const w of p.wheels){cv+=Math.abs(w.cv||0);if(w.contact&&w.surf!=='asphalt')loose++;}
    info={time:now/1000,speed:Math.min(1,sp/55),rough:Math.min(1,cv*0.12+loose*0.08*Math.min(1,sp/15)),rain:this.isRain?1:0,sunDir:this.sunDir,sunPower:this.sunPower,focus:this.inside||this.mounted?1e5:this.camera.position.distanceTo(this._fp||(this._fp=new THREE.Vector3()).set(p.px,p.py,p.pz)),hazeColor:this.hazeCol};
    if(this.renderer.shadowMap.enabled){this.sun.position.set(p.px+this.sunDir.x*120,p.py+this.sunDir.y*120,p.pz+this.sunDir.z*120);this.sun.target.position.set(p.px,p.py,p.pz);}}
   this.post.autoQuality(this.fps||60,realDt);
   this.renderPost(this.scene,this.camera,info||{time:now/1000,speed:0,rough:0,rain:0});this.rearScreen();}
  }catch(err){console.error(err);this.showError(err);this.state='menu';}
  requestAnimationFrame(t=>this.loop(t))}
 fixedUpdate(){this.input.update(this.fixed);this.input.nitro=!!(this.input.nitroTouch||this.input.nitroKey);this.session.fixed(this.fixed,this.input);}
 updateHud(dt){if(this.physics&&document.body.classList.contains('manual')){const g=this.physics.gear,t=g<0?'R':String(g);if(this._gi!==t){this._gi=t;$('gearInd').textContent=t;}}this.fpsFrames++;this.fpsAccum+=dt;if(this.fpsAccum>=.5){this.fps=Math.round(this.fpsFrames/this.fpsAccum);this.fpsAccum=0;this.fpsFrames=0;this.autoTune();}
  const p=this.physics,S=this.session,t=this.cfg.type,mph=PROFILE.d.settings.units==='mph';const kmh=Math.abs(p.vLong)*3.6;const g=p.gear<0?'R':p.gear===0?'N':(p.clutchLocked||kmh>3?String(p.gear):'N');
  $('speed').innerHTML=`${Math.round(mph?kmh*0.6214:kmh)}<span class="unit">${mph?'mph':'km/h'}</span>`;$('gear').textContent=g;this.rpmFill.style.width=(clamp(p.rpm/VEH.maxRpm,0,1)*100).toFixed(1)+'%';
  if(VEH.nitroCap>0){$('nitroFill').style.height=(p.nitro/VEH.nitroCap*100).toFixed(0)+'%';$('nitroBtn').classList.toggle('active',!!p.nitroActive);}
  if(t==='race'){const st=S.standings();$('pos').textContent=`${st.indexOf(S.player)+1}/${st.length}`;}
  const dm=t==='story'?0:p.damage||0;const de=$('dmg');if(dm>0.04){de.style.display='block';de.textContent='🔧 Daño '+Math.round(dm*100)+'%';de.style.color=dm>0.5?'#ff4d5e':'#ffc83d';}else de.style.display='none';
  if(S.route&&S.laps>1)$('lap').textContent=`${Math.min(S.laps,Math.floor(Math.max(0,S.player.prog)/S.L)+1)}/${S.laps}`;
  if(S.route)$('progFill').style.width=(clamp(S.player.prog/S.raceLen,0,1)*100).toFixed(1)+'%';
  if(t==='rush'){$('time').textContent=fmtTime(Math.max(0,this.cfg.time-S.time));$('best').textContent=`${S.flags.filter(f=>f.got).length}/${S.flags.length}`;}
  else if(t==='drift'){$('time').textContent=fmtTime(Math.max(0,this.cfg.time-S.time));const d=S.drift;$('driftScore').textContent=Math.round(d.cur).toLocaleString('es-AR');$('driftCombo').textContent=d.cur>0?'x'+d.mult+' COMBO':'';$('driftTotal').textContent='TOTAL '+Math.round(d.total).toLocaleString('es-AR');}
  else if(t==='parking')$('time').textContent=fmtTime(S.time+S.touches*3);
  else $('time').textContent=fmtTime(S.time);
  if((this.frameN=(this.frameN||0)+1)%3===0)this.drawMinimap();
  if(S.notes&&this.frameN%4===0&&!S.introHold)this.updateNotes(S,p);
  if(STATE.debug){const d=v=>v.toFixed(2);$('debug').textContent=`FPS ${this.fps}\nMapa ${this.cfg.map}\nCam ${CAM_INDEX+1}\nvLong ${d(p.vLong)} vLat ${d(p.vLat)}\nRPM ${p.rpm.toFixed(0)} marcha ${g}\nPI ${perfOf(VEH).pi}\nNitro ${d(p.nitro||0)}`}}
 resize(){this.camera.aspect=innerWidth/innerHeight;this.camera.updateProjectionMatrix();this.renderer.setSize(innerWidth,innerHeight);this.fx.setScale(innerHeight,this.renderer.getPixelRatio())}
}
try{
 const game=new Game();window.__HILL_CLIMB_GAME__=game;window.__PROFILE__=PROFILE;window.__THREE__=THREE;
}catch(err){console.error(err);const box=document.getElementById('errorBox');box.style.display='block';box.innerHTML='<b>ERROR DE INICIALIZACION</b><br>'+String(err&&err.stack||err).replace(/</g,'&lt;');}
