/* ═══════════════════════════════════════════════════════════════════
   GSKORP RALLY — Habitáculo "falso" para cámaras interiores
   Onboard (casco del piloto) y cámara trasera (detrás de las butacas).
   Todo procedural: tablero, jaula, parantes, parabrisas con lluvia y limpias,
   espejos que reflejan de verdad, display digital, volante con guantes,
   piloto y copiloto (con hoja de notas) que se mueven con las fuerzas G.
   Coordenadas: marco de la carrocería (+z adelante, +x izquierda, y desde el piso).
   ═══════════════════════════════════════════════════════════════════ */
import * as THREE from 'three';
import {mergeGeometries} from 'three/addons/utils/BufferGeometryUtils.js';
import {RigPilot,pilotSource} from './pilot.js';

const CABIN={
 pickup:{eyeY:1.40,eyeZ:0.30,cowlZ:1.22,halfW:0.80,roofY:1.70},
 t1plus:{eyeY:1.19,eyeZ:-0.20,cowlZ:0.78,halfW:0.82,roofY:1.44},
 truck:{eyeY:1.55,eyeZ:1.72,cowlZ:2.55,halfW:0.98,roofY:1.98},
 genesis:{eyeY:1.08,eyeZ:-0.12,cowlZ:0.98,halfW:0.74,roofY:1.33},
};
function tex(w,h,draw){const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;t.anisotropy=4;return t;}
const V3=(x,y,z)=>new THREE.Vector3(x,y,z);
/* ═══ Cuerpo del piloto frente a las fuerzas G: dos resortes encadenados.
   Torso (sujetado por el arnés, firme) → cabeza (cuello, poco amortiguado: se pasa y vuelve).
   Se alimenta con la aceleración REAL medida del auto (incluye choques y aterrizajes): los golpes
   entran como sacudón de velocidad, las frenadas bruscas y volantazos por el "jerk". ═══ */
/* peso de la mano en la palanca durante un cambio (0.5 s): va, empuja, vuelve */
function shiftW(t){if(t===undefined||t>0.55)return 0;if(t<0.16)return (t/0.16)*(t/0.16)*(3-2*t/0.16);if(t<0.3)return 1;const u=(t-0.3)/0.25;return 1-u*u*(3-2*u);}
/* piloto que "hace" lo que hace el auto: mano al freno de mano, pie derecho en acelerador/freno (sin atravesar el piso) */
function limbState(o,dt,p){const k=1-Math.exp(-dt*14);o.hbW=(o.hbW||0)+((p.hbIn?1:0)-(o.hbW||0))*k;const br=p.brake||0,th=p.throttle||0;
 o.onBrake=(o.onBrake||0)+((br>0.05?1:0)-(o.onBrake||0))*(1-Math.exp(-dt*18));o.press=(o.press||0)+((br>0.05?br:th)-(o.press||0))*(1-Math.exp(-dt*16));}
function rightFoot(o,xD,fy,eZ){const x=xD-0.11+(o.onBrake||0)*0.10,pr=o.press||0;return V3(x,Math.max(fy+0.09,fy+0.13-pr*0.05),eZ+0.62+pr*0.09);}
/* copiloto: mira al frente con movimientos chicos de cabeza (nunca por encima del hombro) */
function coLook(t){return 0.10*Math.sin(t*0.41)+0.05*Math.sin(t*1.07+1.3)+0.03*Math.sin(t*2.3+0.4);}
/* manos en el volante: cada una agarra un punto del aro y gira con él; cuando se le acaba el brazo suelta y vuelve a agarrar
   más atrás (mano sobre mano, de a una). Si la derecha está en la palanca o el freno de mano, la izquierda dobla sola. */
const GRIP_R=Math.hypot(0.17,0.015),GRIP_H=[Math.atan2(0.015,0.17),Math.PI-Math.atan2(0.015,0.17)];
const wrapA=a=>Math.atan2(Math.sin(a),Math.cos(a));
function gripStep(o,dt,wheel,busy){const st=o.grip||(o.grip=[{g:GRIP_H[0],m:0},{g:GRIP_H[1],m:0}]);o.phi=o.phi||[0,0];o.lift=o.lift||[0,0];
 for(let i=0;i<2;i++){const s=st[i],j=1-i,H=GRIP_H[i];
  if(busy[i]){s.m=-1;o.phi[i]=H;o.lift[i]=0;continue;}
  if(s.m===-1){s.m=0;s.g=H-wheel;}
  if(s.m>0){s.m=Math.max(0,s.m-dt/0.18);const u=1-s.m,e=u*u*(3-2*u);o.phi[i]=s.from+wrapA(s.to-s.from)*e;o.lift[i]=Math.sin(u*Math.PI)*0.06;if(s.m===0)s.g=s.to-wheel;continue;}
  const phi=s.g+wheel,dev=wrapA(phi-H),alone=busy[j]||st[j].m!==0,lim=alone?1.9:1.15;
  if(Math.abs(dev)>lim&&(st[j].m===0||busy[j])){s.from=phi;s.to=H-Math.sign(dev)*0.5;s.m=1;}
  o.phi[i]=phi;o.lift[i]=0;}}
function makeG(o={}){return {kT:o.kT??40,cT:o.cT??8.5,kH:o.kH??95,cH:o.cH??5.2,gain:o.gain??1,t:V3(0,0,0),tv:V3(0,0,0),r:V3(0,0,0),rv:V3(0,0,0),a:V3(0,0,0),prev:null,body:V3(0,0,0),head:V3(0,0,0),cam:V3(0,0,0),kick:0};}
function stepG(G,dt,p){dt=Math.min(dt,0.05);if(dt<=0)return;
 const fx=Math.sin(p.yaw),fz=Math.cos(p.yaw),lx=Math.cos(p.yaw),lz=-Math.sin(p.yaw);const vL=p.vx*fx+p.vz*fz,vT=p.vx*lx+p.vz*lz,vY=p.vy||0;
 let mL=p.aLong||0,mT=p.aLat||0,mY=0;
 if(G.prev){const aL=(vL-G.prev[0])/dt,aT=(vT-G.prev[1])/dt+(p.yawRate||0)*vL,aY=(vY-G.prev[2])/dt;
  /* lo que no explican las gomas = golpe (choque, cordón, aterrizaje) → sacudón */
  /* Δv que no explican las gomas (m/s): el cuerpo sigue con la velocidad que traía → sacudón proporcional */
  const dL=(aL-mL)*dt,dT=(aT-mT)*dt,dv=Math.hypot(dL,dT);if(dv>0.25){const f=Math.min(dv,25)/dv;G.tv.x+=-dT*f*0.02;G.tv.z+=-dL*f*0.02;G.rv.x+=-dT*f*0.045;G.rv.z+=-dL*f*0.045;G.kick=Math.min(1,G.kick+dv/10);}
  if(Math.abs(aY)>14){const dy=clamp(aY*dt,-8,8);G.tv.y+=-dy*0.02;G.rv.y+=-dy*0.035;}
  mY=clamp(aY,-15,15);}
 G.prev=[vL,vT,vY];
 /* cuerpos más sueltos: al acelerar van para atrás, al frenar bastante para adelante (el arnés los frena), en curva se van al costado */
 const g=G.gain,tgt=G.a.set(clamp(-mT*0.015*g,-0.14,0.14),clamp(-mY*0.0025,-0.035,0.035)+clamp(-Math.abs(mT)*0.0025,-0.03,0),clamp(-mL*(mL<0?0.018:0.013)*g,-0.13,0.15));
 const n=Math.max(1,Math.ceil(dt/0.005)),h=dt/n;
 for(let i=0;i<n;i++)for(const ax of ['x','y','z']){const at=G.kT*(tgt[ax]-G.t[ax])-G.cT*G.tv[ax];G.tv[ax]+=at*h;G.t[ax]=clamp(G.t[ax]+G.tv[ax]*h,-0.17,0.17);
  const ar=-G.kH*G.r[ax]-G.cH*G.rv[ax]-at*1.3;G.rv[ax]+=ar*h;G.r[ax]=clamp(G.r[ax]+G.rv[ax]*h,-0.11,0.11);}
 G.kick=Math.max(0,G.kick-dt*2);
 /* la cámara de adentro se mueve como antes (no marea): solo los cuerpos exageran */
 G.body.copy(G.t).multiplyScalar(0.8);G.head.copy(G.t).add(G.r);G.cam.copy(G.t).multiplyScalar(0.6).addScaledVector(G.r,0.25);}

/* lluvia sobre el parabrisas: gotas quietas, gotas que corren y barrido de limpias */
const RAIN_VS=`varying vec2 vUv;void main(){vUv=uv;gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);}`;
const RAIN_FS=`precision highp float;varying vec2 vUv;uniform float uTime,uRain,uWipe,uSpeed,uDirt;uniform vec2 uAspect;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float wiperAge(vec2 uv,float piv){vec2 d=uv-vec2(piv,-0.05);float ang=atan(d.x,d.y);/* ángulo barrido: 0 derecha… */float a=clamp((ang+1.35)/2.3,0.0,1.0);return a;}
void main(){vec2 uv=vUv;vec2 g=uv*uAspect;float alpha=0.0;vec3 col=vec3(0.0);
 /* suciedad/polvo fino del vidrio */
 float dust=h(floor(g*60.0))*0.5+h(floor(g*23.0))*0.5;alpha+=uDirt*0.10*smoothstep(0.55,1.0,dust)*(0.4+0.6*(1.0-uv.y));col+=vec3(0.75,0.7,0.6)*uDirt*0.08*smoothstep(0.6,1.0,dust);
 if(uRain>0.01){
  /* limpias: la zona recién barrida queda limpia y se vuelve a mojar */
  float clean=1.0-smoothstep(0.0,1.0,uWipe);
  for(int L=0;L<2;L++){float sc=L==0?11.0:23.0;vec2 q=g*sc;vec2 id=floor(q);vec2 f=fract(q)-0.5;float r=h(id+float(L)*7.3);
   vec2 o=vec2(h(id+1.7)-0.5,h(id+3.1)-0.5)*0.55;float life=fract(uTime*(0.05+r*0.06)+r*10.0);float size=(L==0?0.26:0.2)*smoothstep(0.0,0.2,life)*step(0.35,r);
   /* el viento empuja las gotas hacia arriba con velocidad */
   o.y+=uSpeed*life*0.9;float d=length((f-o)*vec2(1.0,1.2));float m=smoothstep(size,size*0.6,d);
   float rim=smoothstep(size*0.9,size*0.5,d)-smoothstep(size*0.5,size*0.2,d);
   alpha+=m*0.35*uRain;col+=vec3(0.85,0.9,0.95)*(rim*0.6+m*0.15)*uRain;}
  /* chorritos que corren */
  vec2 q=g*vec2(17.0,3.0);vec2 id=floor(q);float r=h(id);float t=fract(uTime*(0.2+r*0.3)+r);vec2 f=fract(q);float streak=smoothstep(0.08,0.0,abs(f.x-0.5-(h(id+2.0)-0.5)*0.4))*smoothstep(t,t-0.35,1.0-f.y)*step(0.8,r);
  alpha+=streak*0.3*uRain;col+=vec3(0.8,0.85,0.9)*streak*0.25*uRain;
  alpha*=mix(1.0,0.15,clean*step(uv.y,0.95));}
 gl_FragColor=vec4(col,clamp(alpha,0.0,0.75));}`;

export class Cockpit{
 constructor(type,V,paint){
  this.type=type;this.V=V;const C=this.C={...(CABIN[type]||CABIN.t1plus)};
  const root=this.root=new THREE.Group();root.name='cockpit';this.parts={};
  this.head=V3(0,0,0);this.headV=V3(0,0,0);this.body=V3(0,0,0);this.steerVis=0;this.wipe=0;this.wipeT=0;this.dispT=0;this.gearKick=0;
  const hw=C.halfW,eY=C.eyeY,eZ=C.eyeZ,cz=C.cowlZ,rY=C.roofY,floorY=eY-1.05,xD=0.37;this.xD=xD;this.floorY=floorY;
  const acc=new THREE.Color(paint&&paint.accent||'#ff6a08'),bodyCol=new THREE.Color(paint&&paint.body||'#1a4fe0');
  /* materiales */
  const suede=tex(128,128,(c,w,h)=>{c.fillStyle='#1b1c1f';c.fillRect(0,0,w,h);for(let i=0;i<5000;i++){const v=22+Math.random()*16;c.fillStyle=`rgb(${v},${v},${v+2})`;c.fillRect(Math.random()*w,Math.random()*h,1,1);}});suede.wrapS=suede.wrapT=THREE.RepeatWrapping;suede.repeat.set(4,2);
  const M=this.M={dash:new THREE.MeshStandardMaterial({map:suede,roughness:0.95,metalness:0}),trim:new THREE.MeshStandardMaterial({color:0x26282c,roughness:0.75}),
   carbon:new THREE.MeshStandardMaterial({map:tex(64,64,(c,w,h)=>{for(let y=0;y<h;y+=8)for(let x=0;x<w;x+=8){c.fillStyle=((x+y)/8)%2?'#1c1d20':'#2a2b2f';c.fillRect(x,y,8,8);}}),roughness:0.4,metalness:0.3}),
   head:new THREE.MeshStandardMaterial({color:0x8d9095,roughness:1}),cage:new THREE.MeshStandardMaterial({color:0xd6d8db,roughness:0.45,metalness:0.35}),
   glass:new THREE.MeshStandardMaterial({color:0xaec2d4,transparent:true,opacity:0.1,roughness:0.04,metalness:0.9,depthWrite:false,side:THREE.DoubleSide}),
   paint:new THREE.MeshStandardMaterial({color:bodyCol,metalness:0.45,roughness:0.3}),
   suit:new THREE.MeshStandardMaterial({color:0x2a2e36,roughness:0.85}),suitAcc:new THREE.MeshStandardMaterial({color:acc,roughness:0.7}),
   glove:new THREE.MeshStandardMaterial({color:0xecedee,roughness:0.8}),gloveDk:new THREE.MeshStandardMaterial({color:0x1d1e21,roughness:0.8}),
   helmet:new THREE.MeshStandardMaterial({map:tex(512,256,(c,w,h)=>{c.fillStyle='#'+bodyCol.getHexString();c.fillRect(0,0,w,h);c.fillStyle='#f4f4f4';c.fillRect(0,h*0.55,w,h*0.45);c.fillStyle='#'+acc.getHexString();c.fillRect(0,h*0.47,w,h*0.08);for(let i=0;i<6;i++){c.fillRect(i*w/6,0,w/60,h*0.47);}c.fillStyle='#111';c.font='italic 900 34px system-ui';c.fillText('GSKORP',w*0.08,h*0.75);c.fillText('GSKORP',w*0.58,h*0.75);}),roughness:0.25,metalness:0.15}),visor:new THREE.MeshStandardMaterial({color:0x0b0d10,roughness:0.08,metalness:0.8}),
   seat:new THREE.MeshStandardMaterial({color:0x17181b,roughness:0.9}),metal:new THREE.MeshStandardMaterial({color:0x9aa0a8,roughness:0.35,metalness:0.8}),red:new THREE.MeshStandardMaterial({color:0xc41e24,roughness:0.5})};
  const add=(geo,mat,x,y,z,parent)=>{const m=new THREE.Mesh(geo,mat);m.position.set(x,y,z);(parent||root).add(m);return m;};
  const bar=(a,b,r,mat,parent)=>{const d=b.clone().sub(a),L=d.length();const m=new THREE.Mesh(new THREE.CylinderGeometry(r,r,L,8),mat);m.position.copy(a).addScaledVector(d,0.5);m.quaternion.setFromUnitVectors(V3(0,1,0),d.normalize());(parent||root).add(m);return m;};
  const boxBetween=(a,b,w,t,mat)=>{const d=b.clone().sub(a),L=d.length();const m=new THREE.Mesh(new THREE.BoxGeometry(w,L,t),mat);m.position.copy(a).addScaledVector(d,0.5);m.quaternion.setFromUnitVectors(V3(0,1,0),d.normalize());root.add(m);return m;};
  const eye=V3(xD,eY,eZ);this.eye=eye;
  /* ─── parabrisas ─── */
  const cowlY=eY-0.30,wBL=V3(hw*0.97,cowlY,cz-0.02),wBR=V3(-hw*0.97,cowlY,cz-0.02),wTL=V3(hw*0.9,rY-0.03,eZ+0.46),wTR=V3(-hw*0.9,rY-0.03,eZ+0.46);
  this.wind={wBL,wBR,wTL,wTR};
  const quad=(a,b,c,d,v0=0,v1=1)=>{const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.Float32BufferAttribute([...a.toArray(),...b.toArray(),...c.toArray(),...d.toArray()],3));g.setAttribute('uv',new THREE.Float32BufferAttribute([0,v0,1,v0,0,v1,1,v1],2));g.setIndex([0,2,1,1,2,3]);g.computeVertexNormals();return g;};
  const lerp=(p,q,t)=>p.clone().lerp(q,t);
  const glassG=quad(wBL,wBR,wTL,wTR);const glass=new THREE.Mesh(glassG,M.glass);glass.renderOrder=2;root.add(glass);
  this.rainMat=new THREE.ShaderMaterial({vertexShader:RAIN_VS,fragmentShader:RAIN_FS,transparent:true,depthWrite:false,side:THREE.DoubleSide,uniforms:{uTime:{value:0},uRain:{value:0},uWipe:{value:1},uSpeed:{value:0},uDirt:{value:0.5},uAspect:{value:new THREE.Vector2(2*hw,wTL.distanceTo(wBL))}}});
  const rain=new THREE.Mesh(glassG,this.rainMat);rain.renderOrder=3;root.add(rain);
  /* banda superior (parasol) con texto espejado como en los autos reales */
  const strip=tex(1024,96,(c,w,h)=>{c.fillStyle='rgba(18,20,26,0.82)';c.fillRect(0,0,w,h);c.save();c.translate(w,0);c.scale(-1,1);c.fillStyle='#ffffff';c.font='italic 900 40px system-ui,sans-serif';c.textAlign='center';c.textBaseline='middle';c.fillText('GSKORP   RALLY   TEAM',w/2,h/2);c.fillStyle='#'+acc.getHexString();c.fillRect(0,h-10,w,10);c.restore();});
  const sM=new THREE.MeshBasicMaterial({map:strip,transparent:true,depthWrite:false,side:THREE.DoubleSide});const st=new THREE.Mesh(quad(lerp(wBL,wTL,0.88),lerp(wBR,wTR,0.88),wTL,wTR),sM);st.renderOrder=4;root.add(st);
  /* marco: parantes A, travesaño superior, cowl */
  boxBetween(wBL.clone().add(V3(0.03,0,0)),wTL.clone().add(V3(0.03,0,0)),0.09,0.13,M.trim);boxBetween(wBR.clone().add(V3(-0.03,0,0)),wTR.clone().add(V3(-0.03,0,0)),0.09,0.13,M.trim);
  add(new THREE.BoxGeometry(2*hw,0.09,0.16),M.trim,0,rY-0.02,eZ+0.44);
  /* techo */
  const roof=add(new THREE.PlaneGeometry(2*hw,Math.max(0.6,eZ+0.5-(eZ-1.05))),M.head,0,rY+0.01,(eZ+0.5+eZ-1.05)/2);roof.rotation.x=Math.PI/2;
  /* capot visto desde adentro */
  const hoodTex=tex(256,256,(c,w,h)=>{c.fillStyle='#'+bodyCol.getHexString();c.fillRect(0,0,w,h);c.fillStyle='#'+acc.getHexString();c.fillRect(w*0.36,0,w*0.07,h);c.fillRect(w*0.57,0,w*0.07,h);c.fillStyle='rgba(0,0,0,.35)';c.fillRect(w*0.47,h*0.1,w*0.06,h*0.35);});
  const hoodG=new THREE.PlaneGeometry(2*hw*1.12,1.4,6,4);hoodG.rotateX(-Math.PI/2);{const P=hoodG.attributes.position;for(let i=0;i<P.count;i++){const x=P.getX(i),z=P.getZ(i);P.setY(i,-0.06*(x*x)/(hw*hw)-0.12*(z+0.7)/1.4);}hoodG.computeVertexNormals();}
  const hood=new THREE.Mesh(hoodG,new THREE.MeshStandardMaterial({map:hoodTex,metalness:0.45,roughness:0.3}));hood.position.set(0,cowlY-0.07,cz+0.72);root.add(hood);
  /* limpiaparabrisas */
  this.wipers=[];for(const px of [0.28,-0.32]){const piv=V3(px,cowlY+0.01,cz+0.03);const blade=new THREE.Mesh(new THREE.BoxGeometry(0.018,0.55,0.012),M.trim);root.add(blade);this.wipers.push({piv,blade,len:0.55});}
  const wu=wBR.clone().sub(wBL).normalize().negate(),wv=lerp(wBL,wBR,0.5).sub(lerp(wTL,wTR,0.5)).negate().normalize();this.wu=wu;this.wv=wv;
  /* ─── tablero ─── */
  const sh=new THREE.Shape();const dz0=eZ+0.40;sh.moveTo(dz0,eY-0.78);sh.lineTo(dz0,eY-0.44);sh.quadraticCurveTo(dz0+0.02,eY-0.33,dz0+0.14,eY-0.32);sh.lineTo(cz-0.02,cowlY-0.005);sh.lineTo(cz-0.02,eY-0.78);sh.closePath();
  const dg=new THREE.ExtrudeGeometry(sh,{depth:2*hw,bevelEnabled:false,curveSegments:6});dg.rotateY(-Math.PI/2);dg.translate(hw,0,0);add(dg,M.dash,0,0,0);
  /* capuchón del instrumental + display digital */
  add(new THREE.BoxGeometry(0.34,0.07,0.16),M.dash,xD,eY-0.27,eZ+0.56);
  this.dispCan=document.createElement('canvas');this.dispCan.width=512;this.dispCan.height=224;this.dispTex=new THREE.CanvasTexture(this.dispCan);this.dispTex.colorSpace=THREE.SRGBColorSpace;
  /* display grande arriba del volante: se lee por el hueco superior del aro */
  /* display grande en el centro del tablero (al costado del volante, como en los autos de rally): se ve entero */
  const dx=xD-0.31,dy=eY-0.18;add(new THREE.BoxGeometry(0.31,0.145,0.04),M.dash,dx,dy,eZ+0.575).lookAt(root.localToWorld(eye.clone()));
  const disp=add(new THREE.PlaneGeometry(0.28,0.123),new THREE.MeshBasicMaterial({map:this.dispTex,toneMapped:false,depthTest:false}),dx,dy,eZ+0.55);disp.renderOrder=3;disp.lookAt(root.localToWorld(eye.clone()));
  /* cronómetro central (como los de rally) */
  this.timCan=document.createElement('canvas');this.timCan.width=256;this.timCan.height=96;this.timTex=new THREE.CanvasTexture(this.timCan);this.timTex.colorSpace=THREE.SRGBColorSpace;
  add(new THREE.BoxGeometry(0.19,0.085,0.05),M.trim,xD-0.36,eY-0.36,eZ+0.60);const tim=add(new THREE.PlaneGeometry(0.17,0.064),new THREE.MeshBasicMaterial({map:this.timTex,toneMapped:false}),xD-0.36,eY-0.36,eZ+0.572);tim.lookAt(root.localToWorld(eye.clone()));
  /* panel de interruptores */
  const sw=tex(256,128,(c,w,h)=>{c.fillStyle='#16171a';c.fillRect(0,0,w,h);const lab=['IGN','FAN','PUMP','WIPE','LGT','HORN','MAP','ALS'];for(let i=0;i<8;i++){const x=16+(i%4)*60,y=14+Math.floor(i/4)*58;c.fillStyle='#2b2d31';c.fillRect(x,y,44,42);c.fillStyle=i===0?'#d12a2a':i<3?'#e0a21a':'#9aa0a8';c.fillRect(x+15,y+6,14,22);c.fillStyle='#cfd3d8';c.font='bold 10px sans-serif';c.fillText(lab[i],x+6,y+40);}});
  const swp=add(new THREE.PlaneGeometry(0.27,0.135),new THREE.MeshStandardMaterial({map:sw,roughness:0.6}),-0.04,eY-0.56,eZ+0.44);swp.lookAt(root.localToWorld(eye.clone().add(V3(0,-0.25,0))));
  /* palanca secuencial y freno de mano hidráulico */
  this.gearLever=new THREE.Group();this.gearLever.position.set(xD-0.30,eY-0.78,eZ+0.20);root.add(this.gearLever);
  add(new THREE.CylinderGeometry(0.012,0.016,0.42,8),M.metal,0,0.21,0,this.gearLever);add(new THREE.SphereGeometry(0.035,10,8),M.dash,0,0.43,0,this.gearLever);
  this.hbLever=new THREE.Group();this.hbLever.position.set(xD-0.24,eY-0.80,eZ+0.02);root.add(this.hbLever);
  add(new THREE.CylinderGeometry(0.014,0.018,0.5,8),M.red,0,0.25,0,this.hbLever);add(new THREE.CylinderGeometry(0.024,0.024,0.09,10),M.dash,0,0.48,0,this.hbLever);
  /* espejo interior y retrovisores exteriores (textura viva) */
  this.mirrorRT=new THREE.WebGLRenderTarget(256,96,{depthBuffer:true});
  const mm=new THREE.MeshBasicMaterial({map:this.mirrorRT.texture});this.mirrorRT.texture.wrapS=THREE.RepeatWrapping;this.mirrorRT.texture.repeat.x=-1;this.mirrorRT.texture.offset.x=1;
  /* el central, bajo el borde superior del parabrisas y dentro del campo visual del casco */
  const my=Math.min(rY-0.14,eY+0.1),mpos=V3(0.02,my,eZ+0.42);this.mirrors=[];/* orientado entre el casco del piloto y la cámara de atrás de las butacas: se ve la imagen en las dos cámaras interiores */const aim=V3(xD*0.5,eY+0.06,eZ-0.36);const nrm=aim.clone().sub(mpos).normalize(),fp=mpos.clone().addScaledVector(nrm,-0.02);/* el marco va DETRÁS del vidrio (sobre su normal), no delante */const frame=add(new THREE.BoxGeometry(0.29,0.095,0.03),M.trim,fp.x,fp.y,fp.z);frame.lookAt(root.localToWorld(aim.clone()));const mir=add(new THREE.PlaneGeometry(0.27,0.08),mm,mpos.x,mpos.y,mpos.z);mir.lookAt(root.localToWorld(aim.clone()));this.mirrors.push(mir);
  add(new THREE.CylinderGeometry(0.008,0.008,Math.max(0.04,rY-my-0.02),6),M.trim,0.02,(rY+my)/2,eZ+0.44);
  /* laterales: afuera, a la altura de la vista, visibles por la ventanilla (no tapados por el parante) */
  for(const sd of [1,-1]){const sp=V3(sd*(hw+0.21),eY-0.1,cz-0.02),hn=eye.clone().sub(sp).normalize(),hp=sp.clone().addScaledVector(hn,-0.04);const hous=add(new THREE.BoxGeometry(0.25,0.16,0.07),M.paint,hp.x,hp.y,hp.z);hous.lookAt(root.localToWorld(eye.clone()));const sm=add(new THREE.PlaneGeometry(0.22,0.13),mm,sp.x,sp.y,sp.z);sm.lookAt(root.localToWorld(eye.clone()));this.mirrors.push(sm);add(new THREE.BoxGeometry(0.16,0.03,0.05),M.paint,sd*(hw+0.09),eY-0.17,cz-0.03);}
  /* puertas */
  for(const sd of [1,-1]){const d=add(new THREE.BoxGeometry(0.04,eY-0.22-floorY,cz-0.1-(eZ-1.0)),M.carbon,sd*hw,(eY-0.22+floorY)/2,(cz-0.1+eZ-1.0)/2);
   add(new THREE.BoxGeometry(0.1,0.05,cz-0.1-(eZ-1.0)),M.dash,sd*(hw-0.03),eY-0.21,(cz-0.1+eZ-1.0)/2);}
  add(new THREE.PlaneGeometry(2*hw,2.4),M.trim,0,floorY,eZ).rotation.x=-Math.PI/2;
  /* jaula antivuelco */
  const r=0.021,ih=hw-0.08;const aL0=V3(ih,eY-0.62,cz-0.25),aL1=V3(ih*0.95,rY-0.07,eZ+0.40),aR0=V3(-ih,eY-0.62,cz-0.25),aR1=V3(-ih*0.95,rY-0.07,eZ+0.40);
  const mL0=V3(ih,floorY,eZ-0.85),mL1=V3(ih,rY-0.07,eZ-0.85),mR0=V3(-ih,floorY,eZ-0.85),mR1=V3(-ih,rY-0.07,eZ-0.85);
  for(const [a,b] of [[aL0,aL1],[aR0,aR1],[aL1,aR1],[mL0,mL1],[mR0,mR1],[mL1,mR1],[aL1,mL1],[aR1,mR1],[mL1,mR0.clone().setY(eY-0.5)],[aL1,mR1],[aR1,mL1],
   [V3(ih,eY-0.55,cz-0.3),V3(ih,eY-0.40,eZ-0.85)],[V3(ih,eY-0.88,cz-0.3),V3(ih,eY-0.55,eZ-0.85)],[V3(-ih,eY-0.55,cz-0.3),V3(-ih,eY-0.40,eZ-0.85)],[V3(-ih,eY-0.88,cz-0.3),V3(-ih,eY-0.55,eZ-0.85)]])bar(a,b,r,M.cage);
  /* butacas */
  const seatTex=tex(256,256,(c,w,h)=>{c.translate(w,0);c.scale(-1,1);c.fillStyle='#141518';c.fillRect(0,0,w,h);c.fillStyle='#ffffff';c.font='italic 900 44px system-ui';c.textAlign='center';c.fillText('GSKORP',w/2,h*0.42);c.fillStyle='#'+acc.getHexString();c.font='800 22px system-ui';c.fillText('racing',w/2,h*0.54);});seatTex.repeat.set(1.92,-1.25);seatTex.offset.set(0.5,1);seatTex.wrapS=seatTex.wrapT=THREE.ClampToEdgeWrapping;
  for(const sd of [1,-1]){const s=new THREE.Shape();s.moveTo(-0.26,0);s.lineTo(0.26,0);s.lineTo(0.25,0.62);s.quadraticCurveTo(0.24,0.78,0.12,0.8);s.lineTo(-0.12,0.8);s.quadraticCurveTo(-0.24,0.78,-0.25,0.62);s.closePath();
   const g=new THREE.ExtrudeGeometry(s,{depth:0.09,bevelEnabled:true,bevelThickness:0.03,bevelSize:0.03,bevelSegments:2,curveSegments:6});
   const seat=new THREE.Mesh(g,[new THREE.MeshStandardMaterial({map:seatTex,roughness:0.9}),M.seat]);seat.position.set(sd*xD,eY-0.95,eZ-0.36);seat.rotation.x=-0.18;seat.rotation.y=Math.PI;root.add(seat);
   for(const side of [-1,1])add(new THREE.BoxGeometry(0.07,0.38,0.2),M.seat,sd*xD+side*0.25,eY-0.72,eZ-0.26);}
  /* ─── piloto y copiloto ─── */
  this.driver=this.person(xD,acc,true);this.codriver=this.person(-xD,acc,false);
  /* volante */
  const wc=V3(xD,eY-0.31,eZ+0.37);this.wheelC=wc;const wg=this.wheelGroup=new THREE.Group();wg.position.copy(wc);root.add(wg);wg.lookAt(root.localToWorld(eye.clone().add(V3(0,-0.12,0))));
  add(new THREE.CylinderGeometry(0.03,0.03,0.08,10),M.trim,0,0,-0.05,wg).rotation.x=Math.PI/2;
  const rim=this.rim=new THREE.Group();wg.add(rim);
  add(new THREE.TorusGeometry(0.17,0.021,10,44),M.dash,0,0,0,rim);const mark=add(new THREE.TorusGeometry(0.17,0.0225,8,8,0.28),M.suitAcc,0,0,0,rim);mark.rotation.z=Math.PI/2-0.14;
  for(const a of [0,Math.PI,-Math.PI/2]){const sp=add(new THREE.BoxGeometry(0.16,0.028,0.012),M.carbon,Math.cos(a)*0.085,Math.sin(a)*0.085,0.006,rim);sp.rotation.z=a;}
  add(new THREE.CylinderGeometry(0.05,0.055,0.03,16),M.carbon,0,0,0.012,rim).rotation.x=Math.PI/2;
  for(let i=0;i<4;i++){const b=add(new THREE.CylinderGeometry(0.008,0.008,0.01,8),i%2?M.red:M.suitAcc,-0.03+i*0.02,0.03,-0.004,rim);b.rotation.x=Math.PI/2;}
  /* manos: siguen al volante hasta ±100° */
  this.hands=new THREE.Group();wg.add(this.hands);this.gloves=[];
  for(const sd of [1,-1]){const hg=new THREE.Group();hg.position.set(sd*0.17,0.015,0);this.hands.add(hg);
   const palm=add(new THREE.CapsuleGeometry(0.032,0.055,4,8),M.glove,sd*0.012,0,-0.012,hg);palm.rotation.z=sd*0.25;
   const k=add(new THREE.BoxGeometry(0.05,0.07,0.035),M.glove,sd*-0.008,0.002,0.02,hg);k.rotation.z=sd*0.2;
   add(new THREE.CapsuleGeometry(0.012,0.03,3,6),M.glove,sd*-0.03,0.03,0.022,hg).rotation.z=sd*1.1;
   add(new THREE.CylinderGeometry(0.036,0.04,0.05,10),M.gloveDk,sd*0.03,-0.05,-0.03,hg).rotation.x=0.5;
   this.gloves.push(hg);}
  this.arms=this.gloves.map((g,i)=>({fore:new THREE.Mesh(new THREE.CylinderGeometry(0.031,0.04,1,10),M.suit),upper:new THREE.Mesh(new THREE.CylinderGeometry(0.042,0.047,1,10),M.suit),stripe:new THREE.Mesh(new THREE.CylinderGeometry(0.041,0.041,0.05,10),M.suitAcc),sd:i?-1:1}));
  for(const a of this.arms){root.add(a.fore,a.upper,a.stripe);}
  root.updateMatrixWorld(true);this.gloves.forEach((g,i)=>{const w=g.getWorldPosition(V3(0,0,0));this.arms[i].side=Math.sign(w.x-xD)||(i?-1:1);});
  this._v=V3(0,0,0);this._w=V3(0,0,0);this._q=new THREE.Quaternion();this._m=new THREE.Matrix4();this.mirrorCam=new THREE.PerspectiveCamera(46,256/96,0.3,700);
  this.mergeStatic();
  /* tripulación: fuera del habitáculo para que también se vea desde afuera (mismo marco que root) */
  this.crew=new THREE.Group();this.crew.name='crew';
  for(const o of [this.driver.g,this.codriver.g,...this.arms.flatMap(a=>[a.fore,a.upper,a.stripe])])this.crew.add(o);
  this.rig=null;const src=pilotSource();
  if(src){try{const r=[new RigPilot(src,this.crew),new RigPilot(src,this.crew)];if(r[0].ok&&r[1].ok){this.rig=r;for(const x of r)this.crew.add(x.obj);this.useRig();}}catch(e){console.warn('piloto',e);this.rig=null;}}}
 /* piloto con esqueleto: oculta el procedural y le pone el casco del equipo si el modelo no trae */
 /* desde afuera los pilotos usan la malla liviana; adentro, la completa */
 setLOD(lo){if(this.rig)for(const r of this.rig)r.setLOD(lo);}
 useRig(){for(const P of [this.driver,this.codriver]){for(const c of P.g.children)if(c!==P.book)c.visible=false;if(P.book)P.book.children.forEach((c,i)=>{if(i>0)c.visible=false;});}
  for(const a of this.arms){a.fore.visible=a.upper.visible=a.stripe.visible=false;}this.hands.visible=false;
  this.rig.forEach((r,i)=>{if(r.hasHelmet)return;const P=i?this.codriver:this.driver,hb=r.B.Head;const w=new THREE.Group();const ws=hb.getWorldScale(V3(0,0,0));w.scale.setScalar(1/ws.x);w.quaternion.copy(r.rest.get(hb).wq).invert();
   const hc=P.helmet.clone();hc.visible=true;hc.position.set(0,0.095,0.02);hc.rotation.set(0,0,0);w.add(hc);hb.add(w);r.helmet=hc;});}
 /* pose del rig cada cuadro */
 poseRig(){const C=this.C,xD=this.xD,b=this.body,h=this.head,fy=this.floorY;const wg=this.wheelGroup;
  const n=V3(0,0,1).applyQuaternion(wg.quaternion);const hands=[];
  for(let i=0;i<2;i++){const gl=this.gloves[i];const gp=gl.position.clone().applyMatrix4(this.hands.matrix).applyMatrix4(wg.matrix);const r=gp.clone().sub(this.wheelC).normalize();
   hands.push({side:this.arms[i].side>0?'Left':'Right',wrist:gp.clone().addScaledVector(n,0.07).addScaledVector(r,0.045),fdir:r.clone().multiplyScalar(-0.15).addScaledVector(n,-0.85).normalize(),back:r.clone().multiplyScalar(0.9).addScaledVector(n,0.25).normalize()});}
  /* cambio de marcha: la mano derecha va a la palanca, tira (sube) o empuja (baja) y vuelve */
  const sw=shiftW(this.shiftT);if(sw>0){const hr=hands.find(x=>x.side==='Right');if(hr){this.gearLever.updateMatrix();const knob=V3(0,0.43,0).applyMatrix4(this.gearLever.matrix);knob.z+=this.shiftUp?-0.05:0.05;knob.y+=0.035;
   hr.wrist.lerp(knob.add(V3(0.035,0.02,-0.05)),sw);hr.fdir.lerp(V3(-0.2,-0.75,0.6).normalize(),sw).normalize();hr.back.lerp(V3(-0.5,0.8,-0.2).normalize(),sw).normalize();}}
  /* freno de mano: la derecha agarra la palanca y tira */
  const hw=(this.hbW||0)*(1-sw);if(hw>0.01){const hr=hands.find(x=>x.side==='Right');if(hr){this.hbLever.updateMatrix();const grip=V3(0,0.47,0).applyMatrix4(this.hbLever.matrix);grip.x+=0.03;hr.wrist.lerp(grip,hw);hr.fdir.lerp(V3(-0.1,-0.6,0.8).normalize(),hw).normalize();hr.back.lerp(V3(-0.9,0.3,0).normalize(),hw).normalize();}}
  this.rig[0].pose({hips:V3(xD+b.x*0.4,C.eyeY-0.70+b.y*0.3,C.eyeZ-0.11+b.z*0.3),head:V3(xD+h.x,C.eyeY-0.07+h.y,C.eyeZ-0.09+h.z),roll:h.x*1.2,look:(this.look||0)*(1-Math.max(shiftW(this.shiftT),hw)*0.3),hands,grip:1.2,
   feet:[{side:'Left',pos:V3(xD+0.13,fy+0.13,C.eyeZ+0.60)},{side:'Right',pos:rightFoot(this,xD,fy,C.eyeZ)}]});
  const x=-xD+b.x*0.9,by=C.eyeY-0.47+b.y,bz=C.eyeZ+0.27+b.z;
  this.rig[1].pose({hips:V3(-xD+b.x*0.4,C.eyeY-0.70+b.y*0.3,C.eyeZ-0.13+b.z*0.3),head:V3(-xD+h.x*0.9,C.eyeY-0.09+h.y,C.eyeZ-0.07+h.z),roll:h.x*1.1,look:-0.05+coLook(this.tLook||0),grip:0.8,
   hands:[{side:'Left',wrist:V3(x+0.14,by,bz-0.05),fdir:V3(-0.5,-0.2,0.8).normalize(),back:V3(0.4,1,0.1).normalize()},{side:'Right',wrist:V3(x-0.14,by,bz-0.05),fdir:V3(0.5,-0.2,0.8).normalize(),back:V3(-0.4,1,0.1).normalize()}],
   feet:[{side:'Left',pos:V3(-xD+0.13,fy+0.12,C.eyeZ+0.55)},{side:'Right',pos:V3(-xD-0.13,fy+0.12,C.eyeZ+0.55)}]});}
 /* persona sentada: casco, torso, hombros, HANS; los brazos del copiloto sostienen la hoja */
 person(x,acc,isDriver){const C=this.C,M=this.M,g=new THREE.Group();g.position.set(x,C.eyeY,C.eyeZ);this.root.add(g);
  const helmet=new THREE.Group();helmet.position.set(0,0.02,-0.02);g.add(helmet);
  const hm=new THREE.Mesh(new THREE.SphereGeometry(0.135,20,16),M.helmet);hm.scale.set(0.93,1.0,1.06);helmet.add(hm);
  const vis=new THREE.Mesh(new THREE.SphereGeometry(0.137,20,10,Math.PI/2-0.95,1.9,1.15,0.62),M.visor);vis.scale.set(0.94,1.0,1.07);vis.rotation.y=Math.PI*0;helmet.add(vis);
  const strp=new THREE.Mesh(new THREE.TorusGeometry(0.136,0.012,6,24,Math.PI),M.suitAcc);strp.rotation.y=Math.PI/2;strp.scale.set(0.93,1.0,1.06);strp.visible=false;helmet.add(strp);
  const torso=new THREE.Mesh(new THREE.CapsuleGeometry(0.17,0.32,4,10),M.suit);torso.scale.set(1.25,1,0.75);torso.position.set(0,-0.42,-0.1);g.add(torso);
  const hans=new THREE.Mesh(new THREE.TorusGeometry(0.1,0.03,8,16,Math.PI),M.gloveDk);hans.rotation.x=Math.PI/2;hans.rotation.z=Math.PI;hans.position.set(0,-0.16,-0.05);g.add(hans);
  for(const sd of [1,-1]){const belt=new THREE.Mesh(new THREE.BoxGeometry(0.05,0.5,0.012),M.red);belt.position.set(sd*0.09,-0.4,0.06);belt.rotation.x=0.18;g.add(belt);}
  const P={g,helmet,torso,isDriver};
  if(!isDriver){/* hoja de notas */
   this.noteCan=document.createElement('canvas');this.noteCan.width=256;this.noteCan.height=320;this.noteTex=new THREE.CanvasTexture(this.noteCan);this.noteTex.colorSpace=THREE.SRGBColorSpace;
   const nb=new THREE.Group();nb.position.set(0.02,-0.45,0.30);nb.rotation.x=-0.95;g.add(nb);
   nb.add(new THREE.Mesh(new THREE.PlaneGeometry(0.2,0.25),new THREE.MeshStandardMaterial({map:this.noteTex,roughness:0.9,side:THREE.DoubleSide})));
   for(const sd of [1,-1]){const hand=new THREE.Mesh(new THREE.CapsuleGeometry(0.03,0.05,4,8),M.glove);hand.position.set(sd*0.1,-0.1,0.02);hand.rotation.z=Math.PI/2;nb.add(hand);
    const fa=new THREE.Mesh(new THREE.CylinderGeometry(0.036,0.045,0.34,10),M.suit);fa.position.set(sd*0.14,-0.2,-0.12);fa.rotation.x=0.9;fa.rotation.z=-sd*0.3;nb.add(fa);}
   P.book=nb;this.drawNotes(['Largada','4 der. larga','100','6 izq > 3 der','cresta']);}
  return P;}
 drawNotes(lines){const c=this.noteCan.getContext('2d'),w=256,h=320;c.fillStyle='#f4f1e8';c.fillRect(0,0,w,h);c.strokeStyle='#b9c7d6';c.lineWidth=1;for(let y=40;y<h;y+=32){c.beginPath();c.moveTo(10,y);c.lineTo(w-10,y);c.stroke();}
  c.fillStyle='#1b2a8c';c.font='bold 26px "Comic Sans MS",cursive,sans-serif';lines.slice(0,8).forEach((l,i)=>c.fillText(l,16,34+i*32));c.fillStyle='#c41e24';c.fillRect(0,0,6,h);this.noteTex.needsUpdate=true;}
 mergeStatic(){/* une piezas fijas por material (menos llamadas de dibujo) */
  const keep=new Set([this.wheelGroup,this.gearLever,this.hbLever,this.driver.g,this.codriver.g,...this.wipers.map(w=>w.blade),...this.arms.flatMap(a=>[a.fore,a.upper,a.stripe])]);
  const by=new Map();for(const o of [...this.root.children]){if(!o.isMesh||keep.has(o)||Array.isArray(o.material)||o.renderOrder)continue;const k=o.material.uuid;if(!by.has(k))by.set(k,[]);by.get(k).push(o);}
  for(const [,list] of by){if(list.length<2)continue;try{const geos=list.map(o=>{o.updateMatrix();const g=(o.geometry.index?o.geometry.toNonIndexed():o.geometry.clone());g.applyMatrix4(o.matrix);for(const n of Object.keys(g.attributes))if(!['position','normal','uv'].includes(n))g.deleteAttribute(n);if(!g.attributes.uv)g.setAttribute('uv',new THREE.Float32BufferAttribute(new Float32Array(g.attributes.position.count*2),2));return g;});
   const m=mergeGeometries(geos,false);if(!m)continue;this.root.add(new THREE.Mesh(m,list[0].material));for(const o of list){this.root.remove(o);o.geometry.dispose();}}catch(e){}}}
 /* cuadro por cuadro */
 update(dt,p,inp,info){this.updateCrew(dt,p,info);this.updateCabin(dt,p,inp,info);}
 /* tripulación (también se usa con cámaras exteriores) */
 updateCrew(dt,p,info){const C=this.C;
  /* torso + cabeza con fuerzas G reales (ver stepG) */
  const G=this.G||(this.G=makeG());stepG(G,dt,p);this.head.copy(G.head);this.body.copy(G.body);this.camHead=G.cam;
  if(this.lastGear!==undefined&&p.gear!==this.lastGear&&p.gear>0&&this.lastGear>0){this.shiftT=0;this.shiftUp=p.gear>this.lastGear;}this.lastGear=p.gear;if(this.shiftT!==undefined)this.shiftT+=dt;
  /* volante (≈ 8:1 de relación visual), manos con límite */
  this.steerVis+=((p.steerAngle*7.5)-this.steerVis)*(1-Math.exp(-dt*25));this.rim.rotation.z=this.steerVis;this.hands.rotation.z=0;
  {const busyR=Math.max(shiftW(this.shiftT),this.hbW||0)>0.45;gripStep(this,dt,this.steerVis,[this.arms[0].side<0&&busyR,this.arms[1].side<0&&busyR]);
   for(let i=0;i<2;i++){const g=this.gloves[i],ph=this.phi[i];g.position.set(Math.cos(ph)*GRIP_R,Math.sin(ph)*GRIP_R,this.lift[i]);g.rotation.z=ph-GRIP_H[i];}}
  /* brazos: hombro → codo → muñeca */
  this.wheelGroup.updateMatrix();this.hands.updateMatrix();
  for(let i=0;i<2;i++){const a=this.arms[i],gl=this.gloves[i];gl.updateMatrix();const wrist=this._w.set(a.sd*0.03,-0.06,0.06).applyMatrix4(gl.matrix).applyMatrix4(this.hands.matrix).applyMatrix4(this.wheelGroup.matrix);const side=a.side;
   const sh=V3(this.xD+side*0.21+this.body.x,C.eyeY-0.34+this.body.y,C.eyeZ-0.05+this.body.z);const mid=sh.clone().lerp(wrist,0.45);mid.y-=0.17;mid.x+=side*0.11;
   this.link(a.upper,sh,mid);this.link(a.fore,mid,wrist);a.stripe.position.copy(mid);a.stripe.quaternion.copy(a.fore.quaternion);}
  /* cuerpos */
  for(const P of [this.driver,this.codriver]){P.g.position.set((P.isDriver?this.xD:-this.xD)+this.body.x*(P.isDriver?1:0.9),C.eyeY+this.body.y,C.eyeZ+this.body.z);P.helmet.position.set(this.head.x-this.body.x,0.02+this.head.y-this.body.y,-0.02+this.head.z-this.body.z);P.helmet.rotation.z=-this.head.x*1.2;}
  if(this.codriver.book){this.codriver.book.rotation.x=-0.95+Math.sin(info.time*9)*0.02*info.rough+this.head.z*0.8;}
  this.look=clamp(p.steerAngle*0.45+p.yawRate*0.06,-0.35,0.35);limbState(this,dt,p);this.tLook=(this.tLook||0)+dt;if(this.rig)this.poseRig();}
 updateCabin(dt,p,inp,info){const C=this.C;
  /* palancas */
  this.hbLever.rotation.x=inp&&inp.handbrake?-0.45:0;this.gearKick=Math.max(0,this.gearKick-dt*6);if(this.shiftT!==undefined&&this.shiftT>0.14&&this.shiftT<0.2)this.gearKick=1;this.gearLever.rotation.x=(this.shiftUp?-1:1)*this.gearKick*0.25;
  /* limpias y lluvia */
  const rainOn=info.rain>0;this.rainMat.uniforms.uTime.value=info.time;this.rainMat.uniforms.uRain.value+=((rainOn?1:0)-this.rainMat.uniforms.uRain.value)*Math.min(1,dt);this.rainMat.uniforms.uSpeed.value=Math.min(1,Math.hypot(p.vx,p.vz)/40);
  if(rainOn)this.wipeT+=dt;const ph=rainOn?(this.wipeT%1.4)/1.4:0;const th=(0.5-0.5*Math.cos(ph*Math.PI*2))*1.65;this.rainMat.uniforms.uWipe.value=rainOn?ph:1;
  for(const w of this.wipers){const dir=this._v.copy(this.wu).multiplyScalar(Math.cos(th)).addScaledVector(this.wv,Math.sin(th));const end=w.piv.clone().addScaledVector(dir,w.len);this.link(w.blade,w.piv,end,true);}
  /* displays */
  this.dispT-=dt;if(this.dispT<=0){this.dispT=0.1;this.drawDisplay(p,info);}}
 link(m,A,B,box){const d=B.clone().sub(A),L=d.length()||1e-4;m.position.copy(A).addScaledVector(d,0.5);m.quaternion.setFromUnitVectors(V3(0,1,0),d.multiplyScalar(1/L));if(!box)m.scale.set(1,L,1);}
 drawDisplay(p,info){const V=p.V,c=this.dispCan.getContext('2d'),w=512,h=224;c.fillStyle='#040506';c.fillRect(0,0,w,h);
  const rn=Math.max(0,Math.min(1,p.rpm/V.maxRpm)),up=V.shiftUpRpm/V.maxRpm;const leds=15;for(let i=0;i<leds;i++){const th=up*0.6+i*(up*0.42/leds);const on=rn>th;c.fillStyle=on?(i<5?'#23e05a':i<10?'#ffcc18':'#ff2f3d'):'#15171b';if(rn>up&&Math.floor(info.time*12)%2)c.fillStyle='#3aa0ff';c.beginPath();c.arc(34+i*31.5,18,12,0,7);c.fill();}
  /* velocidad grande */
  const kmh=Math.round(Math.abs(p.vLong)*3.6),mph=this.units==='mph';c.fillStyle='#ffffff';c.font='900 118px system-ui,sans-serif';c.textAlign='right';c.textBaseline='alphabetic';c.fillText(String(mph?Math.round(kmh*0.621):kmh),318,150);
  c.font='800 24px system-ui,sans-serif';c.fillStyle='#8fb3d6';c.textAlign='left';c.fillText(mph?'MPH':'KM/H',326,150);
  /* marcha en recuadro */
  const g=p.gear<0?'R':p.gear===0?'N':p.clutchLocked||Math.abs(p.vLong)>1?String(p.gear):'N';c.fillStyle=rn>up?'#ff2f3d':'#12304a';c.fillRect(398,40,100,120);c.strokeStyle='#3aa0ff';c.lineWidth=4;c.strokeRect(398,40,100,120);
  c.fillStyle='#fff';c.font='900 100px system-ui,sans-serif';c.textAlign='center';c.fillText(g,448,142);
  /* vueltas del motor */
  c.fillStyle='#1d2127';c.fillRect(14,176,w-28,26);c.fillStyle=rn>up?'#ff2f3d':rn>up*0.85?'#ffcc18':'#3aa0ff';c.fillRect(14,176,(w-28)*rn,26);
  c.fillStyle='#e8f1ff';c.font='800 20px system-ui,sans-serif';c.textAlign='left';c.fillText(Math.round(p.rpm)+' rpm',20,196);
  if(V.nitroCap>0){c.fillStyle='#39c6ff';c.fillRect(14,208,(w-28)*(p.nitro/V.nitroCap),10);}
  this.dispTex.needsUpdate=true;
  const t=this.timCan.getContext('2d');t.fillStyle='#08090a';t.fillRect(0,0,256,96);t.fillStyle='#23e05a';t.fillRect(8,8,112,80);t.fillStyle='#ff4a2f';t.fillRect(136,8,112,80);
  t.fillStyle='#051';t.font='bold 34px monospace';t.textAlign='center';t.fillStyle='#022';t.fillText((info.stage||0).toFixed(1),64,62);t.fillStyle='#200';t.fillText(info.delta!=null?(info.delta>0?'+':'')+info.delta.toFixed(1):'--',192,62);this.timTex.needsUpdate=true;}
 /* cámaras: 'onboard' = casco del piloto · 'rearcabin' = atrás de las butacas */
 applyCamera(cam,mode,p,info){const C=this.C,root=this.root;root.updateWorldMatrix(true,false);
  const rough=info.rough||0,t=info.time;const vib=(0.0025+0.006*rough)*(0.3+Math.min(1,Math.abs(p.vLong)/30));
  const nx=Math.sin(t*37.1)*0.6+Math.sin(t*23.7)*0.4,ny=Math.sin(t*41.3)*0.5+Math.sin(t*29.9)*0.5;
  let pos,look;
  const H=this.camHead||this.head;if(mode==='onboard'){pos=V3(this.xD+H.x+nx*vib,C.eyeY+0.03+H.y+ny*vib,C.eyeZ+0.04+H.z);
   const yawLook=clamp(p.steerAngle*0.45+p.yawRate*0.06,-0.35,0.35);look=pos.clone().add(V3(Math.sin(yawLook),-0.2,Math.cos(yawLook)));}
  else{pos=V3(0.02+nx*vib*0.5,C.eyeY+Math.min(0.13,(C.roofY-C.eyeY)*0.55)+ny*vib*0.5,C.eyeZ-0.72);look=V3(0.08,C.eyeY-0.32,C.eyeZ+2.4);}
  const wp=root.localToWorld(pos.clone()),wl=root.localToWorld(look.clone());const up=V3(0,1,0).applyQuaternion(root.getWorldQuaternion(this._q));
  if(mode==='onboard')up.applyAxisAngle(wl.clone().sub(wp).normalize(),-H.x*0.9);
  cam.position.copy(wp);cam.up.copy(up);cam.lookAt(wl);cam.up.set(0,1,0);
  cam.fov=mode==='onboard'?74:72;cam.near=0.04;cam.updateProjectionMatrix();
  /* el piloto propio no se dibuja en la vista de casco */
  if(this.rig)this.rig[0].hideHead(mode==='onboard');else{this.driver.helmet.visible=mode!=='onboard';this.driver.torso.visible=mode!=='onboard';}}
 /* espejos con imagen (se pueden apagar en Opciones para ganar rendimiento: quedan como vidrio oscuro) */
 setMirrors(on){this.mirrorsOn=on;const dark=this._dark||(this._dark=new THREE.MeshBasicMaterial({color:0x1d242e}));for(const m of this.mirrors||[]){if(!m.userData.live)m.userData.live=m.material;m.material=on?m.userData.live:dark;}}
 renderMirror(renderer,scene,hide,force){if(this.mirrorsOn===false&&!force)return;const C=this.C,root=this.root;root.updateWorldMatrix(true,false);const pos=root.localToWorld(V3(0,C.roofY+0.05,C.eyeZ-1.6)),look=root.localToWorld(V3(0,C.roofY-0.35,C.eyeZ-30));
  this.mirrorCam.position.copy(pos);this.mirrorCam.lookAt(look);for(const h of hide)h.visible=false;const old=renderer.getRenderTarget();renderer.setRenderTarget(this.mirrorRT);renderer.render(scene,this.mirrorCam);renderer.setRenderTarget(old);for(const h of hide)h.visible=true;}
 dispose(){const rigObjs=new Set((this.rig||[]).map(r=>r.obj));const free=o=>{if(o.geometry)o.geometry.dispose();};this.crew.removeFromParent();this.crew.traverse(o=>{let q=o;while(q){if(rigObjs.has(q))return;q=q.parent;}free(o);});this.root.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){const ms=Array.isArray(o.material)?o.material:[o.material];for(const m of ms){if(m.map)m.map.dispose();m.dispose();}}});this.mirrorRT.dispose();}
}
function clamp(v,a,b){return Math.max(a,Math.min(b,v));}

/* ═══ Tripulación liviana para los autos rivales: piloto y copiloto con esqueleto, sin habitáculo.
   Cada tripulación tiene su propio "cuello" (rigidez/amortiguación), cuánto se inclina el cuerpo
   y cuánto rola la cabeza: se mueven distinto con las mismas fuerzas G. Traje de otro color. ═══ */
const SUIT_HUES=[2.3,4.1,1.2,3.3,5.2,0.55];
let NOTE_TEX=null;
function noteTex(){if(NOTE_TEX)return NOTE_TEX;NOTE_TEX=tex(64,80,(c,w,h)=>{c.fillStyle='#f2efe6';c.fillRect(0,0,w,h);c.strokeStyle='#9fb2c8';for(let y=12;y<h;y+=9){c.beginPath();c.moveTo(4,y);c.lineTo(w-4,y);c.stroke();}c.fillStyle='#c41e24';c.fillRect(0,0,3,h);});return NOTE_TEX;}
export class Crew{
 constructor(type,seed=0){const C=this.C={...(CABIN[type]||CABIN.t1plus)};this.group=new THREE.Group();this.group.name='crew';this.ok=false;const src=pilotSource();if(!src)return;
  let q=(Math.imul(seed+1,2654435761)>>>0)||1;const rnd=()=>{q^=q<<13;q>>>=0;q^=q>>>17;q^=q<<5;q>>>=0;return q/4294967296;};rnd();rnd();
  this.k=52+rnd()*42;this.c=7+rnd()*6;this.lean=0.35+rnd()*0.4;this.rollK=0.8+rnd()*0.8;this.gain=0.8+rnd()*0.45;
  const hue=SUIT_HUES[seed%SUIT_HUES.length];
  try{this.rigs=[new RigPilot(src,this.group,{hue}),new RigPilot(src,this.group,{hue})];for(const r of this.rigs)r.setLOD(true);}catch(e){console.warn('tripulación',e);return;}
  if(!this.rigs.every(r=>r.ok))return;for(const r of this.rigs)this.group.add(r.obj);
  const xD=this.xD=0.37;this.wc=V3(xD,C.eyeY-0.31,C.eyeZ+0.37);this.n=V3(xD,C.eyeY-0.12,C.eyeZ).sub(this.wc).normalize();
  this.wX=V3(0,1,0).cross(this.n).normalize();this.wY=this.n.clone().cross(this.wX);
  this.book=new THREE.Mesh(new THREE.PlaneGeometry(0.2,0.25),new THREE.MeshLambertMaterial({map:noteTex(),side:THREE.DoubleSide}));this.book.rotation.x=-0.95;this.group.add(this.book);
  this.head=V3(0,0,0);this.headV=V3(0,0,0);this.body=V3(0,0,0);this.steerVis=0;this._v=V3(0,0,0);this.ok=true;}
 update(dt,p,pose){if(!this.ok)return;const C=this.C;dt=Math.min(dt,0.05);
  const G=this.G||(this.G=makeG({kT:this.k*0.6,cT:this.c*0.8,kH:90+this.k*0.6,cH:4.5+this.c*0.25,gain:this.gain}));stepG(G,dt,p);
  this.head.copy(G.head);this.body.copy(G.t).multiplyScalar(this.lean*1.3);
  if(this.lastGear!==undefined&&p.gear!==this.lastGear&&p.gear>0&&this.lastGear>0){this.shiftT=0;this.shiftUp=p.gear>this.lastGear;}this.lastGear=p.gear;if(this.shiftT!==undefined)this.shiftT+=dt;
  this.steerVis+=((p.steerAngle*7.5)-this.steerVis)*(1-Math.exp(-dt*25));limbState(this,dt,p);this.tLook=(this.tLook||0)+dt;
  gripStep(this,dt,this.steerVis,[Math.max(shiftW(this.shiftT),this.hbW||0)>0.45,false]);
  if(!pose)return;
  const xD=this.xD,b=this.body,h=this.head,fy=C.eyeY-1.05,th=clamp(this.steerVis,-1.1,1.1),cs=Math.cos(th),sn=Math.sin(th),n=this.n;const hands=[];
  for(const sd of [1,-1]){const i=sd>0?0:1,ph=this.phi[i];const gp=this.wc.clone().addScaledVector(this.wX,Math.cos(ph)*GRIP_R).addScaledVector(this.wY,Math.sin(ph)*GRIP_R).addScaledVector(this.n,this.lift[i]);const r=gp.clone().sub(this.wc).normalize();
   hands.push({side:sd>0?'Right':'Left',wrist:gp.clone().addScaledVector(n,0.07).addScaledVector(r,0.045),fdir:r.clone().multiplyScalar(-0.15).addScaledVector(n,-0.85).normalize(),back:r.clone().multiplyScalar(0.9).addScaledVector(n,0.25).normalize()});}
  const sw=shiftW(this.shiftT);if(sw>0){const hr=hands.find(x=>x.side==='Right');if(hr){const knob=V3(xD-0.30+0.035,C.eyeY-0.33,C.eyeZ+0.15+(this.shiftUp?-0.05:0.05));hr.wrist.lerp(knob,sw);hr.fdir.lerp(V3(-0.2,-0.75,0.6).normalize(),sw).normalize();hr.back.lerp(V3(-0.5,0.8,-0.2).normalize(),sw).normalize();}}
  const hw=(this.hbW||0)*(1-sw);if(hw>0.01){const hr=hands.find(x=>x.side==='Right');if(hr){const grip=V3(xD-0.24+0.03,C.eyeY-0.33+hw*0.05,C.eyeZ+0.02-hw*0.07);hr.wrist.lerp(grip,hw);hr.fdir.lerp(V3(-0.1,-0.6,0.8).normalize(),hw).normalize();hr.back.lerp(V3(-0.9,0.3,0).normalize(),hw).normalize();}}
  this.rigs[0].pose({hips:V3(xD+b.x*0.4,C.eyeY-0.70+b.y*0.3,C.eyeZ-0.11+b.z*0.3),head:V3(xD+h.x,C.eyeY-0.07+h.y,C.eyeZ-0.09+h.z),roll:h.x*1.2*this.rollK,look:clamp(p.steerAngle*0.45,-0.35,0.35),hands,grip:1.2,
   feet:[{side:'Left',pos:V3(xD+0.13,fy+0.13,C.eyeZ+0.60)},{side:'Right',pos:rightFoot(this,xD,fy,C.eyeZ)}]});
  const x=-xD+b.x*0.9,by=C.eyeY-0.47+b.y,bz=C.eyeZ+0.27+b.z;this.book.position.set(x+0.02,by+0.03,bz+0.03);
  this.rigs[1].pose({hips:V3(-xD+b.x*0.4,C.eyeY-0.70+b.y*0.3,C.eyeZ-0.13+b.z*0.3),head:V3(-xD+h.x*0.9,C.eyeY-0.09+h.y,C.eyeZ-0.07+h.z),roll:h.x*1.1*this.rollK,look:-0.05+coLook((this.tLook||0)+this.k),grip:0.8,
   hands:[{side:'Left',wrist:V3(x+0.14,by,bz-0.05),fdir:V3(-0.5,-0.2,0.8).normalize(),back:V3(0.4,1,0.1).normalize()},{side:'Right',wrist:V3(x-0.14,by,bz-0.05),fdir:V3(0.5,-0.2,0.8).normalize(),back:V3(-0.4,1,0.1).normalize()}],
   feet:[{side:'Left',pos:V3(-xD+0.13,fy+0.12,C.eyeZ+0.55)},{side:'Right',pos:V3(-xD-0.13,fy+0.12,C.eyeZ+0.55)}]});}
 dispose(){this.group.removeFromParent();if(this.rigs)for(const r of this.rigs)r.dispose();if(this.book){this.book.geometry.dispose();this.book.material.dispose();}}
}
