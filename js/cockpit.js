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
 genesis:{eyeY:1.34,eyeZ:-0.05,cowlZ:0.92,halfW:0.78,roofY:1.66},
};
function tex(w,h,draw){const c=document.createElement('canvas');c.width=w;c.height=h;draw(c.getContext('2d'),w,h);const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;t.anisotropy=4;return t;}
const V3=(x,y,z)=>new THREE.Vector3(x,y,z);

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
  const disp=add(new THREE.PlaneGeometry(0.24,0.105),new THREE.MeshBasicMaterial({map:this.dispTex,toneMapped:false}),xD,eY-0.325,eZ+0.495);disp.lookAt(root.localToWorld(eye.clone()));
  /* cronómetro central (como los de rally) */
  this.timCan=document.createElement('canvas');this.timCan.width=256;this.timCan.height=96;this.timTex=new THREE.CanvasTexture(this.timCan);this.timTex.colorSpace=THREE.SRGBColorSpace;
  add(new THREE.BoxGeometry(0.19,0.085,0.05),M.trim,-0.02,eY-0.265,eZ+0.64);const tim=add(new THREE.PlaneGeometry(0.17,0.064),new THREE.MeshBasicMaterial({map:this.timTex,toneMapped:false}),-0.02,eY-0.265,eZ+0.612);tim.lookAt(root.localToWorld(eye.clone()));
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
  const mpos=V3(0,rY-0.11,eZ+0.40);add(new THREE.BoxGeometry(0.27,0.085,0.03),M.trim,mpos.x,mpos.y,mpos.z+0.015);const mir=add(new THREE.PlaneGeometry(0.25,0.07),mm,mpos.x,mpos.y,mpos.z);mir.lookAt(root.localToWorld(eye.clone()));
  add(new THREE.CylinderGeometry(0.008,0.008,0.07,6),M.trim,0,rY-0.05,eZ+0.42);
  for(const sd of [1,-1]){const sp=V3(sd*(hw+0.17),cowlY+0.07,cz-0.08);add(new THREE.BoxGeometry(0.2,0.12,0.07),M.paint,sp.x,sp.y,sp.z+0.04);const sm=add(new THREE.PlaneGeometry(0.18,0.1),mm,sp.x,sp.y,sp.z);sm.lookAt(root.localToWorld(eye.clone()));add(new THREE.BoxGeometry(0.12,0.03,0.05),M.paint,sd*(hw+0.07),cowlY+0.04,cz-0.05);}
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
 useRig(){for(const P of [this.driver,this.codriver]){for(const c of P.g.children)if(c!==P.book)c.visible=false;if(P.book)P.book.children.forEach((c,i)=>{if(i>0)c.visible=false;});}
  for(const a of this.arms){a.fore.visible=a.upper.visible=a.stripe.visible=false;}this.hands.visible=false;
  this.rig.forEach((r,i)=>{if(r.hasHelmet)return;const P=i?this.codriver:this.driver,hb=r.B.Head;const w=new THREE.Group();const ws=hb.getWorldScale(V3(0,0,0));w.scale.setScalar(1/ws.x);w.quaternion.copy(r.rest.get(hb).wq).invert();
   const hc=P.helmet.clone();hc.visible=true;hc.position.set(0,0.095,0.02);hc.rotation.set(0,0,0);w.add(hc);hb.add(w);r.helmet=hc;});}
 /* pose del rig cada cuadro */
 poseRig(){const C=this.C,xD=this.xD,b=this.body,h=this.head,fy=this.floorY;const wg=this.wheelGroup;
  const n=V3(0,0,1).applyQuaternion(wg.quaternion);const hands=[];
  for(let i=0;i<2;i++){const gl=this.gloves[i];const gp=gl.position.clone().applyMatrix4(this.hands.matrix).applyMatrix4(wg.matrix);const r=gp.clone().sub(this.wheelC).normalize();
   hands.push({side:this.arms[i].side>0?'Left':'Right',wrist:gp.clone().addScaledVector(n,0.07).addScaledVector(r,0.045),fdir:r.clone().multiplyScalar(-0.15).addScaledVector(n,-0.85).normalize(),back:r.clone().multiplyScalar(0.9).addScaledVector(n,0.25).normalize()});}
  this.rig[0].pose({hips:V3(xD+b.x*0.3,C.eyeY-0.70+b.y*0.3,C.eyeZ-0.11+b.z*0.2),head:V3(xD+h.x,C.eyeY-0.07+h.y,C.eyeZ-0.09+h.z),roll:h.x*1.2,look:this.look||0,hands,grip:1.2,
   feet:[{side:'Left',pos:V3(xD+0.13,fy+0.13,C.eyeZ+0.60)},{side:'Right',pos:V3(xD-0.11,fy+0.13,C.eyeZ+0.62)}]});
  const x=-xD+b.x*0.9,by=C.eyeY-0.47+b.y,bz=C.eyeZ+0.27+b.z;
  this.rig[1].pose({hips:V3(-xD+b.x*0.3,C.eyeY-0.70+b.y*0.3,C.eyeZ-0.13+b.z*0.2),head:V3(-xD+h.x*0.9,C.eyeY-0.09+h.y,C.eyeZ-0.07+h.z),roll:h.x*1.1,look:-0.05,grip:0.8,
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
  /* cabeza con resorte-amortiguador: fuerzas G reales */
  const tgt=this._v.set(clamp(-p.aLat*0.011,-0.085,0.085),clamp((p.vy||0)*-0.01,-0.04,0.04)+clamp(-Math.abs(p.aLat)*0.002,-0.02,0),clamp(-p.aLong*0.0095,-0.07,0.07));
  const k=70,c=11;const hs=Math.max(1,Math.ceil(dt/0.01)),hd=dt/hs;for(let q=0;q<hs;q++)for(const ax of ['x','y','z']){const a=k*(tgt[ax]-this.head[ax])-c*this.headV[ax];this.headV[ax]+=a*hd;this.head[ax]=clamp(this.head[ax]+this.headV[ax]*hd,-0.11,0.11);}
  this.body.lerp(this._w.copy(this.head).multiplyScalar(0.55),1-Math.exp(-dt*9));
  /* volante (≈ 8:1 de relación visual), manos con límite */
  this.steerVis+=((p.steerAngle*7.5)-this.steerVis)*(1-Math.exp(-dt*25));this.rim.rotation.z=this.steerVis;this.hands.rotation.z=clamp(this.steerVis,-1.1,1.1);
  /* brazos: hombro → codo → muñeca */
  this.wheelGroup.updateMatrix();this.hands.updateMatrix();
  for(let i=0;i<2;i++){const a=this.arms[i],gl=this.gloves[i];gl.updateMatrix();const wrist=this._w.set(a.sd*0.03,-0.06,0.06).applyMatrix4(gl.matrix).applyMatrix4(this.hands.matrix).applyMatrix4(this.wheelGroup.matrix);const side=a.side;
   const sh=V3(this.xD+side*0.21+this.body.x,C.eyeY-0.34+this.body.y,C.eyeZ-0.05+this.body.z);const mid=sh.clone().lerp(wrist,0.45);mid.y-=0.17;mid.x+=side*0.11;
   this.link(a.upper,sh,mid);this.link(a.fore,mid,wrist);a.stripe.position.copy(mid);a.stripe.quaternion.copy(a.fore.quaternion);}
  /* cuerpos */
  for(const P of [this.driver,this.codriver]){P.g.position.set((P.isDriver?this.xD:-this.xD)+this.body.x*(P.isDriver?1:0.9),C.eyeY+this.body.y,C.eyeZ+this.body.z);P.helmet.position.set(this.head.x-this.body.x,0.02+this.head.y-this.body.y,-0.02+this.head.z-this.body.z);P.helmet.rotation.z=-this.head.x*1.2;}
  if(this.codriver.book){this.codriver.book.rotation.x=-0.95+Math.sin(info.time*9)*0.02*info.rough+this.head.z*0.8;}
  this.look=clamp(p.steerAngle*0.45+p.yawRate*0.06,-0.35,0.35);if(this.rig)this.poseRig();}
 updateCabin(dt,p,inp,info){const C=this.C;
  /* palancas */
  this.hbLever.rotation.x=inp&&inp.handbrake?-0.45:0;this.gearKick=Math.max(0,this.gearKick-dt*6);if(p.events)for(const e of p.events)if(e.type==='shift')this.gearKick=1;this.gearLever.rotation.x=-this.gearKick*0.25;
  /* limpias y lluvia */
  const rainOn=info.rain>0;this.rainMat.uniforms.uTime.value=info.time;this.rainMat.uniforms.uRain.value+=((rainOn?1:0)-this.rainMat.uniforms.uRain.value)*Math.min(1,dt);this.rainMat.uniforms.uSpeed.value=Math.min(1,Math.hypot(p.vx,p.vz)/40);
  if(rainOn)this.wipeT+=dt;const ph=rainOn?(this.wipeT%1.4)/1.4:0;const th=(0.5-0.5*Math.cos(ph*Math.PI*2))*1.65;this.rainMat.uniforms.uWipe.value=rainOn?ph:1;
  for(const w of this.wipers){const dir=this._v.copy(this.wu).multiplyScalar(Math.cos(th)).addScaledVector(this.wv,Math.sin(th));const end=w.piv.clone().addScaledVector(dir,w.len);this.link(w.blade,w.piv,end,true);}
  /* displays */
  this.dispT-=dt;if(this.dispT<=0){this.dispT=0.1;this.drawDisplay(p,info);}}
 link(m,A,B,box){const d=B.clone().sub(A),L=d.length()||1e-4;m.position.copy(A).addScaledVector(d,0.5);m.quaternion.setFromUnitVectors(V3(0,1,0),d.multiplyScalar(1/L));if(!box)m.scale.set(1,L,1);}
 drawDisplay(p,info){const V=p.V,c=this.dispCan.getContext('2d'),w=512,h=224;c.fillStyle='#050608';c.fillRect(0,0,w,h);
  const rn=Math.max(0,Math.min(1,p.rpm/V.maxRpm));const leds=15;for(let i=0;i<leds;i++){const on=rn>0.55+i*0.03;c.fillStyle=on?(i<5?'#23e05a':i<10?'#ffcc18':'#ff2f3d'):'#1a1c20';if(rn>0.97&&Math.floor(info.time*12)%2)c.fillStyle='#3aa0ff';c.beginPath();c.arc(40+i*31,20,11,0,7);c.fill();}
  const g=p.gear<0?'R':p.clutchLocked||Math.abs(p.vLong)>1?String(p.gear):'N';c.fillStyle='#fff';c.font='bold 120px monospace';c.textAlign='center';c.fillText(g,w/2,160);
  c.font='bold 44px monospace';c.textAlign='left';c.fillStyle='#cfe8ff';c.fillText(String(Math.round(Math.abs(p.vLong)*3.6)).padStart(3,' '),20,110);c.font='18px monospace';c.fillStyle='#7f93a8';c.fillText('KM/H',24,134);
  c.textAlign='right';c.font='bold 38px monospace';c.fillStyle='#ffd166';c.fillText(Math.round(p.rpm),w-20,110);c.font='18px monospace';c.fillStyle='#7f93a8';c.fillText('RPM',w-24,134);
  c.fillStyle='#1d2127';c.fillRect(20,176,w-40,30);c.fillStyle=rn>0.9?'#ff2f3d':'#3aa0ff';c.fillRect(20,176,(w-40)*rn,30);
  if(V.nitroCap>0){c.fillStyle='#39c6ff';c.fillRect(20,212,(w-40)*(p.nitro/V.nitroCap),8);}
  this.dispTex.needsUpdate=true;
  const t=this.timCan.getContext('2d');t.fillStyle='#08090a';t.fillRect(0,0,256,96);t.fillStyle='#23e05a';t.fillRect(8,8,112,80);t.fillStyle='#ff4a2f';t.fillRect(136,8,112,80);
  t.fillStyle='#051';t.font='bold 34px monospace';t.textAlign='center';t.fillStyle='#022';t.fillText((info.stage||0).toFixed(1),64,62);t.fillStyle='#200';t.fillText(info.delta!=null?(info.delta>0?'+':'')+info.delta.toFixed(1):'--',192,62);this.timTex.needsUpdate=true;}
 /* cámaras: 'onboard' = casco del piloto · 'rearcabin' = atrás de las butacas */
 applyCamera(cam,mode,p,info){const C=this.C,root=this.root;root.updateWorldMatrix(true,true);
  const rough=info.rough||0,t=info.time;const vib=(0.0025+0.006*rough)*(0.3+Math.min(1,Math.abs(p.vLong)/30));
  const nx=Math.sin(t*37.1)*0.6+Math.sin(t*23.7)*0.4,ny=Math.sin(t*41.3)*0.5+Math.sin(t*29.9)*0.5;
  let pos,look;
  if(mode==='onboard'){pos=V3(this.xD+this.head.x+nx*vib,C.eyeY+0.03+this.head.y+ny*vib,C.eyeZ+0.04+this.head.z);
   const yawLook=clamp(p.steerAngle*0.45+p.yawRate*0.06,-0.35,0.35);look=pos.clone().add(V3(Math.sin(yawLook),-0.2,Math.cos(yawLook)));}
  else{pos=V3(0.02+nx*vib*0.5,C.eyeY+Math.min(0.13,(C.roofY-C.eyeY)*0.55)+ny*vib*0.5,C.eyeZ-0.72);look=V3(0.08,C.eyeY-0.32,C.eyeZ+2.4);}
  const wp=root.localToWorld(pos.clone()),wl=root.localToWorld(look.clone());const up=V3(0,1,0).applyQuaternion(root.getWorldQuaternion(this._q));
  if(mode==='onboard')up.applyAxisAngle(wl.clone().sub(wp).normalize(),-this.head.x*0.9);
  cam.position.copy(wp);cam.up.copy(up);cam.lookAt(wl);cam.up.set(0,1,0);
  cam.fov=mode==='onboard'?74:72;cam.near=0.04;cam.updateProjectionMatrix();
  /* el piloto propio no se dibuja en la vista de casco */
  if(this.rig)this.rig[0].hideHead(mode==='onboard');else{this.driver.helmet.visible=mode!=='onboard';this.driver.torso.visible=mode!=='onboard';}}
 renderMirror(renderer,scene,hide){const C=this.C,root=this.root;root.updateWorldMatrix(true,false);const pos=root.localToWorld(V3(0,C.roofY+0.05,C.eyeZ-1.6)),look=root.localToWorld(V3(0,C.roofY-0.35,C.eyeZ-30));
  this.mirrorCam.position.copy(pos);this.mirrorCam.lookAt(look);for(const h of hide)h.visible=false;const old=renderer.getRenderTarget();renderer.setRenderTarget(this.mirrorRT);renderer.render(scene,this.mirrorCam);renderer.setRenderTarget(old);for(const h of hide)h.visible=true;}
 dispose(){const rigObjs=new Set((this.rig||[]).map(r=>r.obj));const free=o=>{if(o.geometry)o.geometry.dispose();};this.crew.removeFromParent();this.crew.traverse(o=>{let q=o;while(q){if(rigObjs.has(q))return;q=q.parent;}free(o);});this.root.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){const ms=Array.isArray(o.material)?o.material:[o.material];for(const m of ms){if(m.map)m.map.dispose();m.dispose();}}});this.mirrorRT.dispose();}
}
function clamp(v,a,b){return Math.max(a,Math.min(b,v));}
