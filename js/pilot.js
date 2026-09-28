/* ═══ Piloto con esqueleto (GLB tipo Mixamo): sentado en la butaca, manos al volante por IK,
   torso/cabeza que se mueven con las fuerzas G. Funciona con cualquier rig de nombres Mixamo
   (mixamorig:Hips, Spine, Head, LeftArm, LeftForeArm, LeftHand, LeftUpLeg, …). ═══ */
import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {clone as skClone} from 'three/addons/utils/SkeletonUtils.js';

let SRC=null,PROM=null;
/* opts.helmet: el modelo ya trae casco puesto */
export function loadPilot(url='models/pilot.glb',opts={}){if(!PROM)PROM=new Promise(res=>{try{new GLTFLoader().load(url,g=>{g.opts=opts;SRC=g;res(g);},undefined,e=>{console.warn('piloto',e);res(null);});}catch(e){res(null);}});return PROM;}
export function pilotSource(){return SRC;}

const V=(x=0,y=0,z=0)=>new THREE.Vector3(x,y,z);
/* traje de otro color: rota el tono de las zonas saturadas (el traje), deja casco/visera/gris como están */
function hueMat(m,hue){const c=m.clone();c.onBeforeCompile=sh=>{sh.uniforms.uHue={value:hue};sh.fragmentShader='uniform float uHue;\n'+sh.fragmentShader.replace('#include <map_fragment>',`#include <map_fragment>
 {vec3 c=diffuseColor.rgb;float mx=max(c.r,max(c.g,c.b)),mn=min(c.r,min(c.g,c.b));float m=smoothstep(0.25,0.5,(mx-mn)/(mx+1e-4));
  vec3 yiq=mat3(0.299,0.596,0.211,0.587,-0.274,-0.523,0.114,-0.322,0.312)*c;float cs=cos(uHue),sn=sin(uHue);yiq.yz=mat2(cs,sn,-sn,cs)*yiq.yz;
  vec3 rc=mat3(1.0,1.0,1.0,0.956,-0.272,-1.106,0.621,-0.647,1.703)*yiq;diffuseColor.rgb=mix(c,max(rc,0.0),m);}`);};c.customProgramCacheKey=()=>'hue'+hue.toFixed(2);return c;}
const norm=n=>n.replace(/^mixamorig\d*[:_]?/i,'').replace(/^.*[:|]/,'');
const FINGERS=['Index','Middle','Ring','Pinky'];
const _m1=new THREE.Matrix4(),_m2=new THREE.Matrix4(),_q=new THREE.Quaternion(),_q2=new THREE.Quaternion(),_q3=new THREE.Quaternion(),_a=V(),_b=V(),_c=V(),_d=V(),_e=V();

export class RigPilot{
 /* height: estatura objetivo (m). frame: objeto cuyo espacio local es el de la cabina (targets vienen en ese espacio) */
 constructor(src,frame,{height=1.76,hue=0}={}){
  this.frame=frame;const o=this.obj=skClone(src.scene);this.B={};this.hasHelmet=!!(src.opts&&src.opts.helmet);
  if(hue)o.traverse(n=>{if(n.isMesh&&n.material){n.material=hueMat(n.material,hue);this.ownMats=(this.ownMats||[]);this.ownMats.push(n.material);}});
  o.traverse(n=>{if(n.isBone){const k=norm(n.name);if(!this.B[k])this.B[k]=n;}if(n.isMesh&&/helmet|casco/i.test(n.name+' '+(n.material&&n.material.name||'')))this.hasHelmet=true;if(n.isMesh){n.frustumCulled=false;n.castShadow=false;n.receiveShadow=false;}});
  const B=this.B,need=['Hips','Spine','Head','LeftArm','LeftForeArm','LeftHand','RightArm','RightForeArm','RightHand','LeftUpLeg','LeftLeg','LeftFoot','RightUpLeg','RightLeg','RightFoot'];
  this.ok=need.every(k=>B[k]);if(!this.ok){console.warn('piloto: faltan huesos',need.filter(k=>!B[k]));return;}
  /* escala: articulación de la cabeza ≈ 0.80·altura por encima del tobillo */
  o.updateMatrixWorld(true);const wp=b=>b.getWorldPosition(V());
  const s=height*0.80/Math.max(1e-6,wp(B.Head).y-Math.min(wp(B.LeftFoot).y,wp(B.RightFoot).y));o.scale.multiplyScalar(s);o.updateMatrixWorld(true);
  this.scale=s;const oi=_m1.copy(o.matrixWorld).invert();
  /* datos de reposo (espacio del personaje): cuaternión local, cuaternión mundial, posiciones */
  const rest=this.rest=new Map();const pos=b=>b.getWorldPosition(V()).applyMatrix4(oi);
  o.traverse(n=>{if(n.isBone){const wq=n.getWorldQuaternion(new THREE.Quaternion());rest.set(n,{lq:n.quaternion.clone(),wq,p:pos(n)});}});
  const inv=b=>rest.get(b).wq.clone().invert();
  /* eje primario (hacia el hijo) y secundario (dado en espacio personaje) en coordenadas locales del hueso */
  this.ax=new Map();const def=(b,child,sec,prim)=>{if(!b)return;const r=rest.get(b);const p=prim?prim.clone():rest.get(child).p.clone().sub(r.p).normalize();const iq=inv(b);this.ax.set(b,{p:p.applyQuaternion(iq).normalize(),s:sec.clone().applyQuaternion(iq).normalize()});};
  const up=V(0,1,0),fw=V(0,0,1);
  const spine=['Spine','Spine1','Spine2','Neck'].map(k=>B[k]).filter(Boolean);this.spine=spine;
  for(const b of spine)def(b,null,fw,up);def(B.Hips,null,fw,up);def(B.Head,null,fw,up);
  this.side={};for(const [S,sg] of [['Left',1],['Right',-1]]){
   const arm=B[S+'Arm'],fore=B[S+'ForeArm'],hand=B[S+'Hand'],mid=B[S+'HandMiddle1']||B[S+'HandIndex1'];
   const shb=B[S+'Shoulder'];if(shb)def(shb,arm,up);def(arm,fore,fw);def(fore,hand,up);def(hand,mid,up,mid?null:V(sg,0,0));
   const ul=B[S+'UpLeg'],lg=B[S+'Leg'],ft=B[S+'Foot'],toe=B[S+'ToeBase'];def(ul,lg,fw);def(lg,ft,fw);def(ft,toe,up,toe?null:V(0,-0.5,1).normalize());
   const r=rest.get(arm).p,rf=rest.get(fore).p,rh=rest.get(hand).p;
   const lu=rest.get(ul).p,ll=rest.get(lg).p,lf=rest.get(ft).p;
   /* dedos: eje de nudillos en reposo (T-pose: Z); se curvan hacia la palma */
   const fing=[];for(const F of [...FINGERS,'Thumb'])for(let i=1;i<=3;i++){const b=B[S+'Hand'+F+i];if(b){const ax=V(0,0,1).applyQuaternion(inv(b));fing.push({b,ax,k:F==='Thumb'?0.35:1,sg});}}
   this.side[S]={sh:shb,arm,fore,hand,ul,lg,ft,fing,sg,L1:r.distanceTo(rf)*s,L2:rf.distanceTo(rh)*s,T1:lu.distanceTo(ll)*s,T2:ll.distanceTo(lf)*s};}
  this.hip2head=rest.get(B.Hips).p.distanceTo(rest.get(B.Head).p)*s;
  this.headHidden=false;}
 /* orienta el hueso para que su eje primario apunte a P y el secundario hacia S (vectores en espacio de "frame") */
 orient(b,P,S){const ax=this.ax.get(b);if(!ax)return;const fq=this.frame.getWorldQuaternion(_q2);
  const p1=_a.copy(P).applyQuaternion(fq).normalize(),s1=_b.copy(S).applyQuaternion(fq);s1.addScaledVector(p1,-s1.dot(p1)).normalize();if(!isFinite(s1.x)||s1.lengthSq()<1e-6)return;
  const t1=_c.crossVectors(p1,s1);_m1.makeBasis(p1,s1,t1);const s0=_d.copy(ax.s).addScaledVector(ax.p,-ax.s.dot(ax.p)).normalize();const t0=_e.crossVectors(ax.p,s0);_m2.makeBasis(ax.p,s0,t0).transpose();
  _m1.multiply(_m2);const Q=_q.setFromRotationMatrix(_m1);const pq=b.parent.getWorldQuaternion(_q3).invert();b.quaternion.copy(pq.multiply(Q));b.updateMatrixWorld(true);}
 /* posición del hueso en espacio "frame" */
 fpos(b,out){b.getWorldPosition(out);return this.frame.worldToLocal(out);}
 /* IK de dos huesos: A (raíz) → codo/rodilla → objetivo T, con vector polo */
 twoBone(A,B2,L1,L2,T,pole,secA,secB){const S=this.fpos(A,V());const d=T.clone().sub(S);let len=d.length();const mx=(L1+L2)*0.999;if(len>mx){d.multiplyScalar(mx/len);len=mx;}len=Math.max(len,Math.abs(L1-L2)+1e-3);
  const dir=d.clone().normalize();const a=(L1*L1-L2*L2+len*len)/(2*len),h=Math.sqrt(Math.max(0,L1*L1-a*a));const pd=pole.clone().addScaledVector(dir,-pole.dot(dir)).normalize();
  const E=S.clone().addScaledVector(dir,a).addScaledVector(pd,h);const tgt=S.clone().add(d);if(secA==='fold')secA=tgt.clone().sub(E).addScaledVector(pd,-0.3);
  this.orient(A,E.clone().sub(S),secA||pd);this.orient(B2,tgt.clone().sub(this.fpos(B2,V())),secB||pd);return E;}
 /* pose completa. o={hips,head(pos cabeza objetivo),roll,hands:[{side,wrist,fdir,back}], feet:[{side,pos,knee}], grip} */
 pose(o){if(!this.ok)return;const B=this.B;this.frame.updateWorldMatrix(true,false);this.obj.updateWorldMatrix(true,false);
  /* cadera en la butaca */
  const hw=this.frame.localToWorld(o.hips.clone());B.Hips.parent.updateWorldMatrix(true,false);B.Hips.position.copy(B.Hips.parent.worldToLocal(hw));
  const fwd=V(0,0,1),up=V(0,1,0);this.orient(B.Hips,V(0,1,-0.18).normalize(),fwd);
  /* columna hacia la cabeza (reclinada, cuello adelante) */
  const hp=this.fpos(B.Hips,V());const dir=o.head.clone().sub(hp).normalize();const n=this.spine.length;
  this.spine.forEach((b,i)=>{const t=n>1?i/(n-1):1;const d=dir.clone().add(V(0,0,-0.10+0.28*t)).normalize();this.orient(b,d,fwd.clone().add(V(0,0,0)));});
  /* cabeza: inclinación lateral por G y mirada hacia adelante */
  const hd=V(Math.sin(o.roll||0),Math.cos(o.roll||0),0.05).normalize();this.orient(B.Head,hd,V(o.look||0,-0.1,1));
  /* brazos */
  for(const h of o.hands){const S=this.side[h.side];if(!S)continue;const pole=V(S.sg*0.6,-1,-0.25);
   /* clavícula: acompaña un poco al brazo (sin esto el hombro se estira y deforma) */
   if(S.sh){const sp=this.fpos(S.sh,V());const tw=h.wrist.clone().sub(sp).normalize();this.orient(S.sh,V(S.sg,0,0).multiplyScalar(0.72).addScaledVector(tw,0.28).add(V(0,-0.04,0)),V(0,1,0));}
   this.twoBone(S.arm,S.fore,S.L1,S.L2,h.wrist,pole,'fold',h.back);
   this.orient(S.hand,h.fdir,h.back);
   for(const f of S.fing){const r=this.rest.get(f.b).lq;f.b.quaternion.copy(r).multiply(_q.setFromAxisAngle(f.ax,-f.sg*(o.grip??1.1)*0.55*f.k));}
   S.hand.updateMatrixWorld(true);}
  /* piernas */
  for(const f of o.feet){const S=this.side[f.side];if(!S)continue;this.twoBone(S.ul,S.lg,S.T1,S.T2,f.pos,V(0,1,0.3),V(0,1,0),V(0,0.3,1));this.orient(S.ft,V(0,0.25,1),V(0,1,-0.2));}
  }
 hideHead(v){if(!this.ok||this.headHidden===v)return;this.headHidden=v;this.B.Head.scale.setScalar(v?0.001:1);this.B.Head.updateMatrixWorld(true);}
 /* geometrías y materiales se comparten con el modelo fuente: no se liberan */
 dispose(){this.obj.removeFromParent();for(const m of this.ownMats||[])m.dispose();}
}
