import {loadMesh,weld} from './lib.mjs';
import {MeshoptSimplifier} from 'meshoptimizer';
import {Document,NodeIO} from '@gltf-transform/core';
const R=+(process.env.R||0.33),TT=+(process.env.TT||7000);
const {P:P0,I:I0}=await loadMesh(process.argv[2]);let {P,I}=weld(P0,I0);const N=P.length/3;
let ymin=1e9,ymax=-1e9;for(let i=0;i<N;i++){ymin=Math.min(ymin,P[i*3+1]);ymax=Math.max(ymax,P[i*3+1]);}
const cy=(ymin+ymax)/2;let rx=0;for(let i=0;i<N;i++)rx=Math.max(rx,Math.abs(P[i*3]));const round=((ymax-ymin)/2)/rx;for(let i=0;i<N;i++)P[i*3]*=round;console.log('roundness fix x',round.toFixed(3));let rmax=0;for(let i=0;i<N;i++)rmax=Math.max(rmax,Math.hypot(P[i*3],P[i*3+1]-cy));
const s=R/rmax;const RIM=0.555/0.95*rmax*s,RING=0.43/0.95*rmax*s;
// axis z -> x (face toward +x), center, scale
const Q=new Float64Array(P.length);for(let i=0;i<N;i++){const x=P[i*3],y=P[i*3+1]-cy,z=P[i*3+2];Q[i*3]=z*s;Q[i*3+1]=y*s;Q[i*3+2]=-x*s;}
await MeshoptSimplifier.ready;
const Q32=Float32Array.from(Q);const RIM0=0.555/0.95*rmax*s,RING0=0.43/0.95*rmax*s;
const parts={tire:[],ring:[],rim:[]};
for(let t=0;t<I.length;t+=3){let r=0;for(let q=0;q<3;q++){const v=I[t+q];r+=Math.hypot(Q[v*3+1],Q[v*3+2])/3;}parts[r>RIM0?'tire':r>RING0?'ring':'rim'].push(I[t],I[t+1],I[t+2]);}
const budget={tire:TT*0.62,ring:TT*0.12,rim:TT*0.26};
const Is=[];const tag=[];
for(const [n,arr] of Object.entries(parts)){const [o]=MeshoptSimplifier.simplify(Uint32Array.from(arr),Q32,3,Math.floor(budget[n])*3,+(process.env.ERR||0.01),process.env.LOCK==='0'?[]:['LockBorder']);for(const v of o)Is.push(v);for(let i=0;i<o.length/3;i++)tag.push(n);console.log('part',n,arr.length/3,'->',o.length/3);}
const used=new Int32Array(N).fill(-1);const Pc=[];let nv=0;const Ic=new Uint32Array(Is.length);
for(let t=0;t<Is.length;t++){const v=Is[t];if(used[v]<0){used[v]=nv++;Pc.push(Q[v*3],Q[v*3+1],Q[v*3+2]);}Ic[t]=used[v];}
const V=Float32Array.from(Pc);const T=Ic.length/3;
const doc=new Document();const buf=doc.createBuffer();const mesh=doc.createMesh('wheel');
let w0=1e9,w1=-1e9;for(let i=0;i<V.length;i+=3){w0=Math.min(w0,V[i]);w1=Math.max(w1,V[i]);}
const groups={tire:[],rim:[],ring:[]};
for(let t=0;t<T;t++)groups[tag[t]].push(Ic[t*3],Ic[t*3+1],Ic[t*3+2]);
// flat-ish shading for tread: compute smooth normals per group (split at group borders)
for(const [name,idx] of Object.entries(groups)){if(!idx.length)continue;
 const map=new Map();const pos=[],ii=[];for(const v of idx){let j=map.get(v);if(j===undefined){j=pos.length/3;map.set(v,j);pos.push(V[v*3],V[v*3+1],V[v*3+2]);}ii.push(j);}
 const nor=new Float32Array(pos.length);
 for(let t=0;t<ii.length;t+=3){const [a,b,c]=[ii[t],ii[t+1],ii[t+2]];const ax=pos[b*3]-pos[a*3],ay=pos[b*3+1]-pos[a*3+1],az=pos[b*3+2]-pos[a*3+2],bx=pos[c*3]-pos[a*3],by=pos[c*3+1]-pos[a*3+1],bz=pos[c*3+2]-pos[a*3+2];
  const nx=ay*bz-az*by,ny=az*bx-ax*bz,nz=ax*by-ay*bx;for(const v of [a,b,c]){nor[v*3]+=nx;nor[v*3+1]+=ny;nor[v*3+2]+=nz;}}
 for(let i=0;i<nor.length;i+=3){const l=Math.hypot(nor[i],nor[i+1],nor[i+2])||1;nor[i]/=l;nor[i+1]/=l;nor[i+2]/=l;}
 const props={tire:[[0.035,0.035,0.038],0,0.92],rim:[[0.16,0.17,0.19],0.85,0.32],ring:[[1.0,0.38,0.02],0.4,0.35]}[name];
 const mat=doc.createMaterial(name).setBaseColorFactor([...props[0],1]).setMetallicFactor(props[1]).setRoughnessFactor(props[2]).setDoubleSided(true);
 mesh.addPrimitive(doc.createPrimitive().setMaterial(mat)
  .setAttribute('POSITION',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(pos)).setBuffer(buf))
  .setAttribute('NORMAL',doc.createAccessor().setType('VEC3').setArray(nor).setBuffer(buf))
  .setIndices(doc.createAccessor().setType('SCALAR').setArray(Uint16Array.from(ii)).setBuffer(buf)));
 console.log(name,ii.length/3,'tris',pos.length/3,'verts');}
doc.createScene().addChild(doc.createNode('wheel').setMesh(mesh));
await new NodeIO().write(process.argv[3],doc);
console.log('R',R,'width',(w1-w0).toFixed(3),'x',w0.toFixed(3),w1.toFixed(3),'rimR',RIM.toFixed(3),'tris',T);
