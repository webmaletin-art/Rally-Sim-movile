// Rueda Genesis: solo la LLANTA del modelo (la cubierta original tiene tacos deformes; el juego arma una cubierta limpia)
import {loadMesh,weld} from './lib.mjs';import {MeshoptSimplifier} from 'meshoptimizer';import {Document,NodeIO} from '@gltf-transform/core';
const RIMF=+(process.env.RIMF||0.565),TT=+(process.env.TT||6000);
const {P:P0,I:I0}=await loadMesh(process.argv[2]);const {P,I}=weld(P0,I0);const N=P.length/3;
let ymin=1e9,ymax=-1e9,zmin=1e9,zmax=-1e9;for(let i=0;i<N;i++){ymin=Math.min(ymin,P[i*3+1]);ymax=Math.max(ymax,P[i*3+1]);zmin=Math.min(zmin,P[i*3+2]);zmax=Math.max(zmax,P[i*3+2]);}
const cy=(ymin+ymax)/2,cz=(zmin+zmax)/2;let rmax=0;for(let i=0;i<N;i++)rmax=Math.max(rmax,Math.hypot(P[i*3],P[i*3+1]-cy));
// eje z → x (cara hacia +x), centrado, radio exterior de la cubierta = 1
const Q=new Float64Array(P.length);for(let i=0;i<N;i++){Q[i*3]=(P[i*3+2]-cz)/rmax;Q[i*3+1]=(P[i*3+1]-cy)/rmax;Q[i*3+2]=-P[i*3]/rmax;}
const keep=[];for(let t=0;t<I.length;t+=3){let r=0;for(let q=0;q<3;q++){const v=I[t+q];r+=Math.hypot(Q[v*3+1],Q[v*3+2])/3;}if(r<RIMF)keep.push(I[t],I[t+1],I[t+2]);}
await MeshoptSimplifier.ready;const [o]=MeshoptSimplifier.simplify(Uint32Array.from(keep),Float32Array.from(Q),3,TT*3,0.01,[]);
const map=new Map(),pos=[],ii=[];for(const v of o){let j=map.get(v);if(j===undefined){j=pos.length/3;map.set(v,j);pos.push(Q[v*3],Q[v*3+1],Q[v*3+2]);}ii.push(j);}
let w0=1e9,w1=-1e9,rr=0;for(let i=0;i<pos.length;i+=3){w0=Math.min(w0,pos[i]);w1=Math.max(w1,pos[i]);rr=Math.max(rr,Math.hypot(pos[i+1],pos[i+2]));}
const Nn=new Float32Array(pos.length);for(let t=0;t<ii.length;t+=3){const [a,b,c]=[ii[t],ii[t+1],ii[t+2]];const ax=pos[b*3]-pos[a*3],ay=pos[b*3+1]-pos[a*3+1],az=pos[b*3+2]-pos[a*3+2],bx=pos[c*3]-pos[a*3],by=pos[c*3+1]-pos[a*3+1],bz=pos[c*3+2]-pos[a*3+2];const nx=ay*bz-az*by,ny=az*bx-ax*bz,nz=ax*by-ay*bx;for(const v of [a,b,c]){Nn[v*3]+=nx;Nn[v*3+1]+=ny;Nn[v*3+2]+=nz;}}
for(let i=0;i<Nn.length;i+=3){const l=Math.hypot(Nn[i],Nn[i+1],Nn[i+2])||1;Nn[i]/=l;Nn[i+1]/=l;Nn[i+2]/=l;}
const doc=new Document();const buf=doc.createBuffer();const mesh=doc.createMesh('wheel');
mesh.addPrimitive(doc.createPrimitive().setMaterial(doc.createMaterial('rim')).setAttribute('POSITION',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(pos)).setBuffer(buf))
 .setAttribute('NORMAL',doc.createAccessor().setType('VEC3').setArray(Nn).setBuffer(buf)).setIndices(doc.createAccessor().setType('SCALAR').setArray(Uint32Array.from(ii)).setBuffer(buf)));
doc.createScene().addChild(doc.createNode('wheel').setMesh(mesh));await new NodeIO().write(process.argv[3],doc);
console.log('llanta tris',ii.length/3,'ancho',(w1-w0).toFixed(3),'x',w0.toFixed(3),w1.toFixed(3),'radio llanta',rr.toFixed(3));
