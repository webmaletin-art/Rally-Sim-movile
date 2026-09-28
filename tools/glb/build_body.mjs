import {loadMesh,weld} from './lib.mjs';import {archProfile} from './arches.mjs';
import {MeshoptSimplifier} from 'meshoptimizer';
import {Document,NodeIO} from '@gltf-transform/core';
const CFG={k:1.25,s:1.7,wheelBase:2.9,weightFront:0.48,lift:+(process.env.LIFT||0.15),archScale:+(process.env.ARCH||1.19),targetTris:+(process.env.TRIS||28000)};
const {P:P0,I:I0}=await loadMesh(process.argv[2]);let {P,I}=weld(P0,I0);
const N=P.length/3;
// 1) restore arch roundness: global z stretch
for(let i=2;i<P.length;i+=3)P[i]*=CFG.k;
// 2) uniform scale to meters
for(let i=0;i<P.length;i++)P[i]*=CFG.s;
let A=archProfile(P,{xOuter:0.55*CFG.s});
let [rear,front]=A.spans.sort((a,b)=>a.center-b.center);
let Ra=(rear.width+front.width)/4;
// 3) mid-section stretch between arches to reach target wheelbase
const d=front.center-rear.center,delta=CFG.wheelBase-d;
const z0=rear.center+Ra*1.2,z1=front.center-Ra*1.2,m=1+delta/(z1-z0);
for(let i=2;i<P.length;i+=3){const z=P[i];if(z>=z1)P[i]=z+delta;else if(z>z0)P[i]=z0+(z-z0)*m;}
A=archProfile(P,{xOuter:0.55*CFG.s});[rear,front]=A.spans.sort((a,b)=>a.center-b.center);
// 4) place: front axle at +a, rear at -b, lift body
const a=CFG.wheelBase*(1-CFG.weightFront),b=CFG.wheelBase*CFG.weightFront;
const dz=a-front.center;for(let i=0;i<N;i++){P[i*3+2]+=dz;P[i*3+1]+=CFG.lift;}
const archTop=(rear.top+front.top)/2+CFG.lift,archC=archTop-Ra;
// 4b) open up the wheel arches (radial warp around each arch centre, fades out by Dout)
{const Ra2=Ra*CFG.archScale,Dout=Ra*1.8;const f=d=>d<=Ra?d*Ra2/Ra:d>=Dout?d:Ra2+(d-Ra)*(Dout-Ra2)/(Dout-Ra);
 for(let i=0;i<N;i++){const y=P[i*3+1];let z=P[i*3+2];
  for(const za of [a,-b]){const dz=z-za,dy=y-archC;
   if(dy>=0){const d=Math.hypot(dz,dy);if(d<Dout&&d>1e-6){const k=f(d)/d;P[i*3+2]=za+dz*k;P[i*3+1]=archC+dy*k;}}
   else{const d=Math.abs(dz);if(d<Dout&&d>1e-6){P[i*3+2]=za+dz*f(d)/d;}}}}
 console.log('arch warp',Ra.toFixed(3),'->',Ra2.toFixed(3));Ra=Ra2;}
let mn=[1e9,1e9,1e9],mx=[-1e9,-1e9,-1e9];for(let i=0;i<N;i++)for(let k=0;k<3;k++){mn[k]=Math.min(mn[k],P[i*3+k]);mx[k]=Math.max(mx[k],P[i*3+k]);}
console.log('arch radius(after warp)',Ra.toFixed(3),'arch center y',archC.toFixed(3),'arch top',archTop.toFixed(3),'wheelbase',(front.center-rear.center).toFixed(3),'mid stretch x',m.toFixed(3),'zone',z0.toFixed(2),z1.toFixed(2));
console.log('bbox min',mn.map(v=>v.toFixed(3)),'max',mx.map(v=>v.toFixed(3)),'size',mx.map((v,i)=>(v-mn[i]).toFixed(3)));
// 5) decimate
await MeshoptSimplifier.ready;
const P32=Float32Array.from(P);
const [Is]=MeshoptSimplifier.simplify(I,P32,3,CFG.targetTris*3,0.02,[]);
console.log('decimated tris',Is.length/3);
// compact
const used=new Int32Array(N).fill(-1);const Pc=[];let nv=0;const Ic=new Uint32Array(Is.length);
for(let t=0;t<Is.length;t++){const v=Is[t];if(used[v]<0){used[v]=nv++;Pc.push(P[v*3],P[v*3+1],P[v*3+2]);}Ic[t]=used[v];}
const V=Float32Array.from(Pc);
// smooth normals
const Nn=new Float32Array(V.length);const T=Ic.length/3;const FN=new Float32Array(T*3);const C=new Float32Array(T*3);
for(let t=0;t<T;t++){const [i0,i1,i2]=[Ic[t*3],Ic[t*3+1],Ic[t*3+2]];
 const ax=V[i1*3]-V[i0*3],ay=V[i1*3+1]-V[i0*3+1],az=V[i1*3+2]-V[i0*3+2],bx=V[i2*3]-V[i0*3],by=V[i2*3+1]-V[i0*3+1],bz=V[i2*3+2]-V[i0*3+2];
 const nx=ay*bz-az*by,ny=az*bx-ax*bz,nz=ax*by-ay*bx;for(const i of [i0,i1,i2]){Nn[i*3]+=nx;Nn[i*3+1]+=ny;Nn[i*3+2]+=nz;}
 const l=Math.hypot(nx,ny,nz)||1;FN[t*3]=nx/l;FN[t*3+1]=ny/l;FN[t*3+2]=nz/l;
 for(let k=0;k<3;k++)C[t*3+k]=(V[i0*3+k]+V[i1*3+k]+V[i2*3+k])/3;}
for(let i=0;i<Nn.length;i+=3){const l=Math.hypot(Nn[i],Nn[i+1],Nn[i+2])||1;Nn[i]/=l;Nn[i+1]/=l;Nn[i+2]/=l;}
// 6) envelopes for cavity detection
const G=0.04;const key=(u,v)=>Math.round(u/G)+','+Math.round(v/G);
const envX=new Map(),envY=new Map(),envZf=new Map(),envZr=new Map();
const up=(M,k,v,f)=>{const o=M.get(k);if(o===undefined||f(v,o))M.set(k,v);};
for(let i=0;i<V.length;i+=3){const x=V[i],y=V[i+1],z=V[i+2];up(envX,key(y,z),Math.abs(x),(a,b)=>a>b);up(envY,key(x,z),y,(a,b)=>a>b);up(envZf,key(x,y),z,(a,b)=>a>b);up(envZr,key(x,y),z,(a,b)=>a<b);}
const tol=0.05,hw=mx[0],H=mx[1],beltY=CFG.lift+0.52*CFG.s,yb=mn[1],zF=mx[2],zR=mn[2];
// roofline per z slice -> cabin z range (contiguous around the highest point)
const RB=80,roof=new Array(RB).fill(-1e9),zb=z=>Math.max(0,Math.min(RB-1,Math.floor((z-zR)/(zF-zR)*RB)));
for(let i=0;i<V.length;i+=3)if(Math.abs(V[i])<0.5*hw){const b=zb(V[i+2]);roof[b]=Math.max(roof[b],V[i+1]);}
let top=0;for(let i=0;i<RB;i++)if(roof[i]>roof[top])top=i;
let c0=top,c1=top;while(c0>0&&roof[c0-1]>beltY+0.12)c0--;while(c1<RB-1&&roof[c1+1]>beltY+0.12)c1++;
const cab0=zR+(c0)/RB*(zF-zR),cab1=zR+(c1+1)/RB*(zF-zR);
console.log('cabin z',cab0.toFixed(2),cab1.toFixed(2),'roof max',roof[top].toFixed(2));
const sst=(e0,e1,x)=>{const t=Math.max(0,Math.min(1,(x-e0)/(e1-e0)));return t*t*(3-2*t);};
// per-vertex livery (smooth): base blue, orange accents, black trim, tinted glass
const blue=[0.02,0.10,0.55],orange=[1.0,0.38,0.02],black=[0.018,0.018,0.022],glassC=[0.012,0.02,0.03];
const mix=(c0,c1,t)=>c0.map((v,k)=>v*(1-t)+c1[k]*t);
const arches=[a,-b];
const COL=new Float32Array(V.length);const vcls=new Uint8Array(V.length/3);// 1 glass 2 trim
for(let i=0;i<V.length;i+=3){const x=V[i],y=V[i+1],z=V[i+2],ax=Math.abs(x),nx=Nn[i],ny=Nn[i+1],nz=Nn[i+2];
 const outX=ax>=(envX.get(key(y,z))??0)-tol&&nx*Math.sign(x)>0.1;
 const outY=y>=(envY.get(key(x,z))??0)-tol&&ny>0.1;
 const outF=z>=(envZf.get(key(x,y))??0)-tol&&nz>0.1;
 const outR=z<=(envZr.get(key(x,y))??0)+tol&&nz<-0.1;
 const outer=outX||outY||outF||outR;
 // orange accents
 let o=0;
 for(const za of arches){const dd=Math.hypot(z-za,y-archC);if(ax>0.62*hw&&y>archC-0.10)o=Math.max(o,sst(Ra*1.02,Ra*1.08,dd)*(1-sst(Ra*1.24,Ra*1.30,dd)));}
 if(ax>0.8*hw&&z>-b+Ra*1.3&&z<a-Ra*1.3)o=Math.max(o,sst(yb+0.25,yb+0.30,y)*(1-sst(yb+0.38,yb+0.43,y)));
 const st=1-sst(0.055,0.08,Math.abs(ax-0.17*hw));
 if((z>cab1-0.05&&y>beltY-0.28)||(y>H-0.2&&z>cab0&&z<cab1))o=Math.max(o,st);
 let c=blue.slice();// orange accents are drawn per-pixel in the game shader
 // black trim
 let k=0;
 if(!outer&&ny<0.45)k=1;
 if(ny<-0.35)k=1;
 k=Math.max(k,1-sst(yb+0.20,yb+0.24,y));
 if(outF&&ax<0.36*hw&&y<0.74)k=1;
 if(outR&&ax<0.40*hw&&y<0.62)k=1;
 for(const za of arches)if(Math.hypot(z-za,y-archC)<Ra*1.0&&ax<0.93*hw)k=1;
 if(k>0)c=mix(c,black,k);
 // tinted glass
 const roofTop=ny>0.72&&y>H-0.24;
 if(y>beltY+0.03&&z>cab0&&z<cab1&&!roofTop){c=glassC.slice();vcls[i/3]=1;}
 else if(k>0.5)vcls[i/3]=2;
 COL.set(c,i);}
const cls=new Uint8Array(T);// 0 body 4 headlight 5 taillight
for(let t=0;t<T;t++){let h=true,r=true;
 for(let q=0;q<3;q++){const v=Ic[t*3+q],x=V[v*3],y=V[v*3+1],z=V[v*3+2],ax=Math.abs(x),nz=Nn[v*3+2];
  if(!(z>zF-0.6&&nz>0.2&&ax>0.38*hw&&ax<0.72*hw&&y>0.68&&y<0.88&&z>=(envZf.get(key(x,y))??0)-tol))h=false;
  if(!(z<zR+0.6&&nz<-0.2&&ax>0.45*hw&&y>0.80&&y<1.0&&z<=(envZr.get(key(x,y))??0)+tol))r=false;}
 let g=0;for(let q=0;q<3;q++)if(vcls[Ic[t*3+q]]===1)g++;
 cls[t]=g>=2?3:0;}// lights are placed as separate meshes in the game
const names=['body','','','glass','headlight','taillight'];
const counts={};for(const c of cls)counts[names[c]]=(counts[names[c]]||0)+1;console.log('class tris',JSON.stringify(counts),'glass verts',vcls.filter(v=>v===1).length);
// 7) export
const doc=new Document();const buf=doc.createBuffer();const mesh=doc.createMesh('body');
const props={body:[[1,1,1],0.3,0.3],trim:[[0.025,0.025,0.03],0.2,0.75],glass:[[0.03,0.045,0.06],0.7,0.06],headlight:[[0.95,0.97,1],0,0.2],taillight:[[0.9,0.05,0.07],0,0.3]};
for(const c of [0,3,4,5]){const idx=[];for(let t=0;t<T;t++)if(cls[t]===c)idx.push(Ic[t*3],Ic[t*3+1],Ic[t*3+2]);if(!idx.length)continue;
 const map=new Map();const pos=[],nor=[],col=[],ii=[];for(const v of idx){let j=map.get(v);if(j===undefined){j=pos.length/3;map.set(v,j);pos.push(V[v*3],V[v*3+1],V[v*3+2]);nor.push(Nn[v*3],Nn[v*3+1],Nn[v*3+2]);col.push(COL[v*3],COL[v*3+1],COL[v*3+2]);}ii.push(j);}
 const [bc,met,rou]=props[names[c]];
 const mat=doc.createMaterial(names[c]).setBaseColorFactor([...bc,1]).setMetallicFactor(met).setRoughnessFactor(rou).setDoubleSided(true);
 const prim=doc.createPrimitive().setMaterial(mat)
  .setAttribute('POSITION',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(pos)).setBuffer(buf))
  .setAttribute('NORMAL',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(nor)).setBuffer(buf))
  .setIndices(doc.createAccessor().setType('SCALAR').setArray(Uint32Array.from(ii)).setBuffer(buf));
 if(c===0||c===3)prim.setAttribute('COLOR_0',doc.createAccessor().setType('VEC3').setArray(Float32Array.from(col)).setBuffer(buf));
 mesh.addPrimitive(prim);}
const node=doc.createNode('body').setMesh(mesh);doc.createScene().addChild(node);
await new NodeIO().write(process.argv[3],doc);
console.log('META',JSON.stringify({archRadius:+Ra.toFixed(3),archCenterY:+archC.toFixed(3),halfWidth:+hw.toFixed(3),front:a,rear:-b,zFront:+mx[2].toFixed(3),zRear:+mn[2].toFixed(3),height:+H.toFixed(3),beltY:+beltY.toFixed(3),yb:+yb.toFixed(3),cab0:+cab0.toFixed(3),cab1:+cab1.toFixed(3)}));
