// Genesis: carrocería del usuario → metros, estirada a la distancia entre ejes real, pasos de rueda abiertos, vidrios y partes oscuras separados
import {loadMesh,weld} from './lib.mjs';import {archProfile} from './arches.mjs';
import {MeshoptSimplifier} from 'meshoptimizer';import {Document,NodeIO} from '@gltf-transform/core';
const CFG={halfW:1.10,wheelBase:2.95,weightFront:0.48,R:0.42,archScale:+(process.env.ARCH||1.17),targetTris:+(process.env.TRIS||30000)};
const {P:P0,I:I0}=await loadMesh(process.argv[2]);let {P,I}=weld(P0,I0);const N=P.length/3;
let hx=0;for(let i=0;i<P.length;i+=3)hx=Math.max(hx,Math.abs(P[i]));const s=CFG.halfW/hx;for(let i=0;i<P.length;i++)P[i]*=s;
let A=archProfile(P,{xOuter:0.8*CFG.halfW});let [rear,front]=A.spans.sort((a,b)=>a.center-b.center);let Ra=(rear.width+front.width)/4;
const d=front.center-rear.center,delta=CFG.wheelBase-d,z0=rear.center+Ra*1.25,z1=front.center-Ra*1.25,m=1+delta/(z1-z0);
for(let i=2;i<P.length;i+=3){const z=P[i];if(z>=z1)P[i]=z+delta;else if(z>z0)P[i]=z0+(z-z0)*m;}
A=archProfile(P,{xOuter:0.8*CFG.halfW});[rear,front]=A.spans.sort((a,b)=>a.center-b.center);
const a=CFG.wheelBase*(1-CFG.weightFront),b=CFG.wheelBase*CFG.weightFront;const dz=a-front.center;
const archTop0=(rear.top+front.top)/2;let archC=archTop0-Ra;
// la rueda queda centrada en el paso: su centro a la altura R
const lift=(CFG.R+0.02)-archC;for(let i=0;i<N;i++){P[i*3+2]+=dz;P[i*3+1]+=lift;}archC+=lift;
{const Ra2=Ra*CFG.archScale,Dout=Ra*1.8;const f=d=>d<=Ra?d*Ra2/Ra:d>=Dout?d:Ra2+(d-Ra)*(Dout-Ra2)/(Dout-Ra);
 for(let i=0;i<N;i++){const y=P[i*3+1];for(const za of [a,-b]){const z=P[i*3+2],dz2=z-za,dy=y-archC;
   if(dy>=0){const dd=Math.hypot(dz2,dy);if(dd<Dout&&dd>1e-6){const k=f(dd)/dd;P[i*3+2]=za+dz2*k;P[i*3+1]=archC+dy*k;}}
   else{const dd=Math.abs(dz2);if(dd<Dout&&dd>1e-6)P[i*3+2]=za+dz2*f(dd)/dd;}}}
 console.log('paso de rueda',Ra.toFixed(3),'->',Ra2.toFixed(3));Ra=Ra2;}
let mn=[1e9,1e9,1e9],mx=[-1e9,-1e9,-1e9];for(let i=0;i<N;i++)for(let k=0;k<3;k++){mn[k]=Math.min(mn[k],P[i*3+k]);mx[k]=Math.max(mx[k],P[i*3+k]);}
console.log('estirado x',m.toFixed(3),'entre ejes',CFG.wheelBase,'medidas',mx.map((v,i)=>(v-mn[i]).toFixed(2)),'piso',mn[1].toFixed(2));
await MeshoptSimplifier.ready;const [Is]=MeshoptSimplifier.simplify(I,Float32Array.from(P),3,CFG.targetTris*3,0.02,[]);
const used=new Int32Array(N).fill(-1);const Pc=[];let nv=0;const Ic=new Uint32Array(Is.length);
for(let t=0;t<Is.length;t++){const v=Is[t];if(used[v]<0){used[v]=nv++;Pc.push(P[v*3],P[v*3+1],P[v*3+2]);}Ic[t]=used[v];}
const V=Float32Array.from(Pc),T=Ic.length/3,Nn=new Float32Array(V.length);
for(let t=0;t<T;t++){const [i0,i1,i2]=[Ic[t*3],Ic[t*3+1],Ic[t*3+2]];const ax=V[i1*3]-V[i0*3],ay=V[i1*3+1]-V[i0*3+1],az=V[i1*3+2]-V[i0*3+2],bx=V[i2*3]-V[i0*3],by=V[i2*3+1]-V[i0*3+1],bz=V[i2*3+2]-V[i0*3+2];
 const nx=ay*bz-az*by,ny=az*bx-ax*bz,nz=ax*by-ay*bx;for(const i of [i0,i1,i2]){Nn[i*3]+=nx;Nn[i*3+1]+=ny;Nn[i*3+2]+=nz;}}
for(let i=0;i<Nn.length;i+=3){const l=Math.hypot(Nn[i],Nn[i+1],Nn[i+2])||1;Nn[i]/=l;Nn[i+1]/=l;Nn[i+2]/=l;}
// envolventes para saber qué está "afuera"
const G=0.04,key=(u,v)=>Math.round(u/G)+','+Math.round(v/G),envX=new Map(),envY=new Map(),up=(M,k,v,f)=>{const o=M.get(k);if(o===undefined||f(v,o))M.set(k,v);};
for(let i=0;i<V.length;i+=3){up(envX,key(V[i+1],V[i+2]),Math.abs(V[i]),(p,q)=>p>q);up(envY,key(V[i],V[i+2]),V[i+1],(p,q)=>p>q);}
const hw=mx[0],H=mx[1],yb=mn[1],zF=mx[2],zR=mn[2];
// techo por franja → zona de la cabina (vidrios)
const RB=90,roof=new Array(RB).fill(-1e9),zb=z=>Math.max(0,Math.min(RB-1,Math.floor((z-zR)/(zF-zR)*RB)));
for(let i=0;i<V.length;i+=3)if(Math.abs(V[i])<0.35*hw){const k=zb(V[i+2]);roof[k]=Math.max(roof[k],V[i+1]);}
let top=0;for(let i=0;i<RB;i++)if(roof[i]>roof[top])top=i;const beltY=yb+(H-yb)*(+(process.env.BELT||0.62));
let c0=top,c1=top;while(c0>0&&roof[c0-1]>beltY+0.1)c0--;while(c1<RB-1&&roof[c1+1]>beltY+0.1)c1++;
const zTop=zR+(top+0.5)/RB*(zF-zR);const cab0=Math.max(zR+c0/RB*(zF-zR),zTop-1.15),cab1=Math.min(zR+(c1+1)/RB*(zF-zR),zTop+1.05);console.log('cabina z',cab0.toFixed(2),cab1.toFixed(2),'cintura',beltY.toFixed(2),'techo',roof[top].toFixed(2));
const sst=(e0,e1,x)=>{const t=Math.max(0,Math.min(1,(x-e0)/(e1-e0)));return t*t*(3-2*t);};
const COL=new Float32Array(V.length),vcls=new Uint8Array(V.length/3);const tol=0.05;
for(let i=0;i<V.length;i+=3){const x=V[i],y=V[i+1],z=V[i+2],ax=Math.abs(x),ny=Nn[i+1];
 const outX=ax>=(envX.get(key(y,z))??0)-tol,outY=y>=(envY.get(key(x,z))??0)-tol;
 let k=0;/* partes oscuras: abajo, adentro de los pasos, caras hacia abajo, zonas internas */
 k=Math.max(k,1-sst(yb+0.16,yb+0.22,y));if(ny<-0.4)k=1;if(!outX&&!outY&&ny<0.3)k=Math.max(k,0.8);
 for(const za of [a,-b])if(Math.hypot(z-za,y-archC)<Ra*1.02&&ax<0.95*hw)k=1;
 let c=[1,1,1];if(k>0)c=c.map(v=>v*(1-k)+0.06*k);
 /* vidrios: la burbuja de la cabina arriba de la cintura, sin el lomo del techo */
 const crest=ny>0.8&&ax<0.28*hw&&y>roof[zb(z)]-0.06;
 if(y>beltY&&z>cab0+0.05&&z<cab1-0.02&&!crest&&(outX||outY)){vcls[i/3]=1;c=[0.05,0.07,0.09];}
 COL.set(c,i);}
const cls=new Uint8Array(T);for(let t=0;t<T;t++){let g=0;for(let q=0;q<3;q++)if(vcls[Ic[t*3+q]]===1)g++;cls[t]=g>=2?1:0;}
console.log('vidrio tris',cls.filter(v=>v).length,'de',T);
const doc=new Document();const buf=doc.createBuffer();const mesh=doc.createMesh('body');const names=['body','glass'];
for(const c of [0,1]){const idx=[];for(let t=0;t<T;t++)if(cls[t]===c)idx.push(Ic[t*3],Ic[t*3+1],Ic[t*3+2]);if(!idx.length)continue;
 const map=new Map(),pos=[],nor=[],col=[],ii=[];for(const v of idx){let j=map.get(v);if(j===undefined){j=pos.length/3;map.set(v,j);pos.push(V[v*3],V[v*3+1],V[v*3+2]);nor.push(Nn[v*3],Nn[v*3+1],Nn[v*3+2]);col.push(COL[v*3],COL[v*3+1],COL[v*3+2]);}ii.push(j);}
 const mat=doc.createMaterial(names[c]).setBaseColorFactor([1,1,1,1]).setDoubleSided(true);
 mesh.addPrimitive(doc.createPrimitive().setMaterial(mat).setAttribute('POSITION',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(pos)).setBuffer(buf))
  .setAttribute('NORMAL',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(nor)).setBuffer(buf)).setAttribute('COLOR_0',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(col)).setBuffer(buf))
  .setIndices(doc.createAccessor().setType('SCALAR').setArray(Uint32Array.from(ii)).setBuffer(buf)));}
doc.createScene().addChild(doc.createNode('body').setMesh(mesh));await new NodeIO().write(process.argv[3],doc);
console.log('META',JSON.stringify({archR:+Ra.toFixed(3),archY:+archC.toFixed(3),hw:+hw.toFixed(3),zf:+zF.toFixed(3),zr:+zR.toFixed(3),H:+H.toFixed(3),yb:+yb.toFixed(3),belt:+beltY.toFixed(3),cab0:+cab0.toFixed(3),cab1:+cab1.toFixed(3),front:a,rear:-b}));
