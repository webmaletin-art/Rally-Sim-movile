import { NodeIO } from '@gltf-transform/core';
export async function loadMesh(path){
  const io=new NodeIO();const doc=await io.read(path);
  const prim=doc.getRoot().listMeshes()[0].listPrimitives()[0];
  const P=prim.getAttribute('POSITION').getArray();const I=prim.getIndices().getArray();
  return {P:Float64Array.from(P),I:Uint32Array.from(I)};
}
// weld by position (quantized); returns {P,I} with shared verts
export function weld(P,I,eps=1e-5){
  const map=new Map();const out=[];const remap=new Uint32Array(P.length/3);
  for(let i=0;i<P.length/3;i++){const k=Math.round(P[i*3]/eps)+','+Math.round(P[i*3+1]/eps)+','+Math.round(P[i*3+2]/eps);
    let j=map.get(k);if(j===undefined){j=out.length/3;map.set(k,j);out.push(P[i*3],P[i*3+1],P[i*3+2]);}remap[i]=j;}
  const I2=[];for(let t=0;t<I.length;t+=3){const a=remap[I[t]],b=remap[I[t+1]],c=remap[I[t+2]];if(a!==b&&b!==c&&a!==c)I2.push(a,b,c);}
  return {P:Float64Array.from(out),I:Uint32Array.from(I2)};
}
export function boundaryLoops(P,I){
  const edges=new Map();
  for(let t=0;t<I.length;t+=3)for(let e=0;e<3;e++){const a=I[t+e],b=I[t+(e+1)%3];const k=a<b?a+'_'+b:b+'_'+a;const v=edges.get(k);if(v){v.n++;}else edges.set(k,{a,b,n:1});}
  const next=new Map();
  for(const {a,b,n} of edges.values())if(n===1){if(!next.has(a))next.set(a,[]);next.get(a).push(b);if(!next.has(b))next.set(b,[]);next.get(b).push(a);}
  const seen=new Set();const loops=[];
  for(const s of next.keys()){if(seen.has(s))continue;const loop=[s];seen.add(s);let prev=-1,cur=s;
    while(true){const nb=(next.get(cur)||[]).find(v=>v!==prev&&!seen.has(v));if(nb===undefined)break;loop.push(nb);seen.add(nb);prev=cur;cur=nb;}
    loops.push(loop);}
  return loops;
}
