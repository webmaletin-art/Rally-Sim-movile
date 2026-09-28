// returns arch info from outer lower-edge profile: [{z0,z1,top,center}]
export function archProfile(P,{xOuter,bins=120}){
  let zmin=1e9,zmax=-1e9;for(let i=2;i<P.length;i+=3){zmin=Math.min(zmin,P[i]);zmax=Math.max(zmax,P[i]);}
  const low=new Array(bins).fill(Infinity);
  for(let i=0;i<P.length/3;i++){if(Math.abs(P[i*3])<xOuter)continue;const b=Math.min(bins-1,Math.floor((P[i*3+2]-zmin)/(zmax-zmin)*bins));low[b]=Math.min(low[b],P[i*3+1]);}
  const zc=i=>zmin+(i+0.5)*(zmax-zmin)/bins;
  const thr=0.5*Math.max(...low.filter(isFinite));
  const spans=[];let s=-1;
  for(let i=0;i<bins;i++){const inA=isFinite(low[i])&&low[i]>thr;if(inA&&s<0)s=i;if((!inA||i===bins-1)&&s>=0){const e=inA?i:i-1;spans.push({z0:zc(s),z1:zc(e),top:Math.max(...low.slice(s,e+1))});s=-1;}}
  return {spans:spans.filter(a=>a.z1-a.z0>0.05*(zmax-zmin)).map(a=>({...a,center:(a.z0+a.z1)/2,width:a.z1-a.z0})),zmin,zmax};
}
