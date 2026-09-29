/* Cabina del dueño → models/cabin.glb (para las cámaras "Chasis 3D")
   - saca los tres espejos sueltos (se usan los del juego, con imagen)
   - la gira 180° (el frente queda en +z como los autos del juego)
   - la achica a ~24k triángulos
   - separa la piel exterior (se pinta del color del auto) del interior (grises con color por vértice) */
import {Document,NodeIO} from '@gltf-transform/core';
import {MeshoptSimplifier} from 'meshoptimizer';
const [,,inp,out,ratio='0.2']=process.argv;await MeshoptSimplifier.ready;
const src=await new NodeIO().read(inp);const sp=src.getRoot().listMeshes()[0].listPrimitives()[0];
const P0=sp.getAttribute('POSITION').getArray(),I0=sp.getIndices()?sp.getIndices().getArray():Uint32Array.from({length:P0.length/3},(_,i)=>i);
/* soldar por posición */
const map=new Map(),rep=[],P=[];for(let i=0;i<P0.length/3;i++){const k=Math.round(P0[i*3]*4000)+','+Math.round(P0[i*3+1]*4000)+','+Math.round(P0[i*3+2]*4000);let r=map.get(k);if(r===undefined){r=P.length/3;map.set(k,r);P.push(-P0[i*3],P0[i*3+1],-P0[i*3+2]);}rep.push(r);}
let I=[];for(let t=0;t<I0.length;t+=3){const a=rep[I0[t]],b=rep[I0[t+1]],c=rep[I0[t+2]];if(a!==b&&b!==c&&a!==c)I.push(a,b,c);}
/* componentes: quedarse con la grande */
const par=Int32Array.from({length:P.length/3},(_,i)=>i),f=x=>{while(par[x]!==x){par[x]=par[par[x]];x=par[x];}return x;};
for(let t=0;t<I.length;t+=3){const a=f(I[t]),b=f(I[t+1]),c=f(I[t+2]);par[a]=b;par[f(b)]=f(c);}
const cnt=new Map();for(let t=0;t<I.length;t+=3){const r=f(I[t]);cnt.set(r,(cnt.get(r)||0)+1);}const big=[...cnt.entries()].sort((a,b)=>b[1]-a[1])[0][0];
I=I.filter((_,k)=>k%3===0).map((_,j)=>j*3).filter(t=>f(I[t])===big).flatMap(t=>[I[t],I[t+1],I[t+2]]);
const Pf=Float32Array.from(P);
const [Is,err]=MeshoptSimplifier.simplify(Uint32Array.from(I),Pf,3,Math.floor(I.length*(+ratio)/3)*3,0.004,[]);
/* normales por vértice */
const N=new Float32Array(Pf.length);for(let t=0;t<Is.length;t+=3){const a=Is[t]*3,b=Is[t+1]*3,c=Is[t+2]*3;const ux=Pf[b]-Pf[a],uy=Pf[b+1]-Pf[a+1],uz=Pf[b+2]-Pf[a+2],vx=Pf[c]-Pf[a],vy=Pf[c+1]-Pf[a+1],vz=Pf[c+2]-Pf[a+2];const nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;for(const i of [a,b,c]){N[i]+=nx;N[i+1]+=ny;N[i+2]+=nz;}}
for(let i=0;i<N.length;i+=3){const l=Math.hypot(N[i],N[i+1],N[i+2])||1;N[i]/=l;N[i+1]/=l;N[i+2]/=l;}
/* clasificar: piel exterior de los costados y el techo = pintura; el resto interior */
let maxX=0,maxY=0;for(let i=0;i<Pf.length;i+=3){maxX=Math.max(maxX,Math.abs(Pf[i]));maxY=Math.max(maxY,Pf[i+1]);}
const paint=[],inner=[];for(let t=0;t<Is.length;t+=3){const a=Is[t]*3,b=Is[t+1]*3,c=Is[t+2]*3;const cx=(Pf[a]+Pf[b]+Pf[c])/3,cy=(Pf[a+1]+Pf[b+1]+Pf[c+1])/3;
 const ux=Pf[b]-Pf[a],uy=Pf[b+1]-Pf[a+1],uz=Pf[b+2]-Pf[a+2],vx=Pf[c]-Pf[a],vy=Pf[c+1]-Pf[a+1],vz=Pf[c+2]-Pf[a+2];let nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx;const l=Math.hypot(nx,ny,nz)||1;nx/=l;ny/=l;
 const outerSide=Math.abs(cx)>maxX*0.9&&nx*Math.sign(cx)>0.55&&cy<maxY*0.75,roofTop=cy>maxY*0.95&&ny>0.6;(outerSide||roofTop?paint:inner).push(Is[t],Is[t+1],Is[t+2]);}
/* color interior por vértice: piso y tablero oscuros, jaula clara arriba */
const C=new Float32Array(Pf.length);for(let i=0;i<Pf.length;i+=3){const y=Pf[i+1]/maxY;const v=y>0.86?0.3:y>0.5?0.028:0.018;/* colores lineales (glTF): 0.03 ≈ gris muy oscuro en pantalla */C[i]=C[i+1]=C[i+2]=v;}
const doc=new Document();const buf=doc.createBuffer();const scene=doc.createScene();
const mk=(name,idx,withCol)=>{const used=new Map(),pos=[],nor=[],col=[],ind=[];for(const v of idx){let j=used.get(v);if(j===undefined){j=pos.length/3;used.set(v,j);pos.push(Pf[v*3],Pf[v*3+1],Pf[v*3+2]);nor.push(N[v*3],N[v*3+1],N[v*3+2]);if(withCol)col.push(C[v*3],C[v*3+1],C[v*3+2]);}ind.push(j);}
 const prim=doc.createPrimitive().setAttribute('POSITION',doc.createAccessor().setType('VEC3').setArray(new Float32Array(pos)).setBuffer(buf)).setAttribute('NORMAL',doc.createAccessor().setType('VEC3').setArray(new Float32Array(nor)).setBuffer(buf)).setIndices(doc.createAccessor().setType('SCALAR').setArray(new Uint32Array(ind)).setBuffer(buf)).setMaterial(doc.createMaterial(name));
 if(withCol)prim.setAttribute('COLOR_0',doc.createAccessor().setType('VEC3').setArray(new Float32Array(col)).setBuffer(buf));
 scene.addChild(doc.createNode(name).setMesh(doc.createMesh(name).addPrimitive(prim)));return ind.length/3;};
const np=mk('paint',paint,false),ni=mk('interior',inner,true);
await new NodeIO().write(out,doc);console.log('tris',Is.length/3,'paint',np,'interior',ni,'err',err.toFixed(4),'box',maxX.toFixed(2),maxY.toFixed(2));
