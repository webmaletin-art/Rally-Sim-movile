/* ═══ Pilotos de la IA ═══
   Manejan con la MISMA física que el jugador: sólo deciden volante, acelerador y freno.
   - Perfil de velocidad por curvatura de la pista (con frenada anticipada)
   - Seguimiento de trayectoria "pure pursuit" con carril propio
   - Evitan autos de adelante, se recuperan si se salen o se quedan */
const G=9.81;

/* Perfil de velocidad de la pista para un nivel de agarre dado (se cachea por pista) */
export function speedProfile(track,mu){
 const key='_vp_'+mu.toFixed(2);if(track[key])return track[key];
 const S=track.samples,N=S.length,v=new Float32Array(N),kap=new Float32Array(N);
 const W=5;
 for(let i=0;i<N;i++){const a=S[(i-W+N)%N],b=S[i],c=S[(i+W)%N];
  const h1=Math.atan2(b.x-a.x,b.z-a.z),h2=Math.atan2(c.x-b.x,c.z-b.z);let d=h2-h1;d=Math.atan2(Math.sin(d),Math.cos(d));
  const ds=Math.hypot(c.x-a.x,c.z-a.z)/2+1e-3;kap[i]=Math.abs(d)/ds;}
 /* suavizado */
 const k2=new Float32Array(N);for(let i=0;i<N;i++){let s=0;for(let j=-3;j<=3;j++)s+=kap[(i+j+N)%N];k2[i]=s/7;}
 /* en bajada se deja margen: cualquier error cuesta más metros para corregir */
 for(let i=0;i<N;i++){const k=Math.max(k2[i],1e-4),j=(i+4)%N,gd=Math.max(0,(S[i].y-S[j].y)/Math.max(1,Math.hypot(S[j].x-S[i].x,S[j].z-S[i].z)));v[i]=Math.min(95,Math.sqrt(mu*(1-1.6*Math.min(0.2,gd))*G/k));}
 /* crestas: con curvatura vertical convexa el auto se aliviana; no pasar tan rápido que despegue */
 for(let i=0;i<N;i++){const a=S[(i-3+N)%N],b=S[i],c=S[(i+3)%N];const d1=Math.hypot(b.x-a.x,b.z-a.z)||1,d2=Math.hypot(c.x-b.x,c.z-b.z)||1;const kv=((b.y-a.y)/d1-(c.y-b.y)/d2)/((d1+d2)/2);if(kv>1e-4)v[i]=Math.min(v[i],Math.sqrt(0.5*G/kv));}
 /* frenada: v_i <= sqrt(v_{i+1}^2 + 2 a ds) — dos vueltas hacia atrás para cerrar el circuito */
 const aB=mu*G*0.72;
 /* en bajada la gravedad resta frenada (y en subida suma) */
 for(let pass=0;pass<2;pass++)for(let i=N-1;i>=0;i--){const j=(i+1)%N,ds=S[i].distanceTo(S[j]),gr=(S[i].y-S[j].y)/Math.max(0.5,ds);const a=Math.max(1.5,aB-G*gr);v[i]=Math.min(v[i],Math.sqrt(v[j]*v[j]+2*a*ds));}
 track[key]={v,kap};return track[key];}

export class AIDriver{
 constructor(track,phys,o){
  this.track=track;this.p=phys;this.skill=o.skill??0.9;this.lane=o.lane??0;this.laneT=this.lane;this.aggr=o.aggr??0.5;
  const V=phys.V,surf=track.mode==='asphalt'?'asphalt':'dirt';
  this.mu=V.mu*(V.surfGrip[surf]||0.8)*Math.min(V.gripFront,V.gripRear)*(0.78+0.2*this.skill);
  this.prof=speedProfile(track,Math.round(this.mu*50)/50);
  this.inp={throttle:0,brake:0,steer:0,handbrake:false,nitro:false};
  this.stuckT=0;this.offT=0;this.boost=1;this.idx=0;this.hint=null;this.enabled=false;this.wobble=Math.random()*10;}
 /* índice de la pista más cercano usando la pista hint propia del auto */
 locate(){const tr=this.track;tr._hint=this.hint;const n=tr.nearest(this.p.px,this.p.pz);this.hint=tr._hint;this.idx=n.idx;this.lat=n.lateral;this.t=n.t;return n;}
 pointAhead(dist,lane){const tr=this.track,S=tr.samples,N=S.length;let i=this.idx,acc=-this.t*S[i].distanceTo(S[(i+1)%N]);
  while(acc<dist){const j=(i+1)%N;acc+=S[i].distanceTo(S[j]);i=j;}
  const p=S[i],l=tr.laterals[i];return {x:p.x+l.x*lane,z:p.z+l.z*lane,i};}
 update(h,others,time){
  const p=this.p,V=p.V,tr=this.track,N=tr.samples.length,inp=this.inp;
  if(!this.enabled){inp.throttle=0;inp.brake=0;inp.handbrake=true;inp.steer=0;return inp;}inp.handbrake=false;
  this.locate();
  const spd=Math.hypot(p.vx,p.vz),hw=tr.halfWidth;
  /* velocidad objetivo: mirar un poco adelante según la velocidad */
  const look=Math.min(N-1,Math.round(2+spd*0.10));let vt=1e9;
  for(let k=0;k<=look;k+=1){vt=Math.min(vt,this.prof.v[(this.idx+k)%N]);}
  vt*=this.boost*(0.9+0.1*this.skill);
  /* carril: se cierra al centro en curvas cerradas */
  const kap=this.prof.kap[(this.idx+6)%N];const laneMax=Math.max(0,hw-1.3);
  let lane=Math.max(-laneMax,Math.min(laneMax,this.laneT))*(1-Math.min(1,kap*25));
  /* tráfico: auto adelante en el mismo carril → cambiar de carril o levantar */
  const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw);
  let blockV=null;
  for(const o of others){if(o===p)continue;const dx=o.px-p.px,dz=o.pz-p.pz;const f=dx*fx+dz*fz,l=dx*lx+dz*lz;
   if(f>0&&f<14&&Math.abs(l)<2.4){const ov=o.vx*fx+o.vz*fz;if(ov<spd+0.5){blockV=Math.min(blockV??1e9,ov);
     const side=(l>0?-1:1);this.laneT=Math.max(-laneMax,Math.min(laneMax,(this.lat||0)+side*2.6));}}}
  if(blockV!=null&&this.aggr<0.8)vt=Math.min(vt,blockV+2+this.aggr*4);
  /* dirección: pure pursuit */
  const Ld=Math.max(6,Math.min(32,5+spd*0.55));const tgt=this.pointAhead(Ld,lane);
  const dx=tgt.x-p.px,dz=tgt.z-p.pz;const fwd=dx*fx+dz*fz,lft=dx*lx+dz*lz;const alpha=Math.atan2(lft,Math.max(0.5,fwd));
  let delta=Math.atan(2*V.wheelBase*Math.sin(alpha)/Ld);
  /* corrección por error lateral (tipo Stanley): no dejar que el auto se abra de a poco */
  delta+=Math.atan(0.4*((this.lat||0)-lane)/Math.max(6,spd));
  /* contravolanteo suave si la cola se va (ángulo de deriva grande) */
  const slipAng=spd>4?Math.atan2(p.vLat||0,Math.max(1,Math.abs(p.vLong||0))):0;delta+=slipAng*0.55;
  const sf=p.steerScale?p.steerScale(spd):1-0.45*Math.min(1,spd/40);const st=-delta/(V.maxSteer*sf);
  inp.steer=Math.max(-1,Math.min(1,st));
  /* acelerador / freno */
  const err=vt-spd;
  if(err>0){inp.throttle=Math.min(1,0.35+err*0.25);inp.brake=0;}
  else{inp.throttle=err>-1.2?0.25:0;inp.brake=err<-1.2?Math.min(1,-err*0.22):0;}
  if(Math.abs(inp.steer)>0.95&&spd>12)inp.throttle*=0.6;
  /* círculo de fricción: si las gomas ya trabajan doblando, dosificar el acelerador (y más si el auto se abre hacia el borde) */
  {const latUse=Math.abs((p.vLong||spd)*p.yawRate)/(this.mu*G);const edge=Math.max(0,(Math.abs(this.lat||0)-(hw-1.2))/2)*(Math.sign(this.lat||0)===Math.sign(-(inp.steer||0))?0:1);
   const lim=Math.max(0.15,1-Math.max(0,latUse-0.3)*2.2-edge*0.5);if(inp.throttle>lim)inp.throttle=lim;}
  inp.nitro=V.nitroCap>0&&err>6&&Math.abs(inp.steer)<0.2&&p.nitro>V.nitroCap*0.3;
  /* recuperación */
  if(time>2&&spd<1.5&&inp.throttle>0.3)this.stuckT+=h;else this.stuckT=Math.max(0,this.stuckT-h*2);
  if(Math.abs(this.lat)>hw+7)this.offT+=h;else this.offT=0;
  if(this.stuckT>2.5||this.offT>3){this.respawn();}
  return inp;}
 respawn(){const tr=this.track,N=tr.samples.length,i=(this.idx+2)%N,s=tr.samples[i],tg=tr.tangents[i];
  this.p.reset({x:s.x,z:s.z,yaw:Math.atan2(tg.x,tg.z)});this.stuckT=0;this.offT=0;this.hint=i;}
}
