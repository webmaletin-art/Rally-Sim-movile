/* ═══ Notas del copiloto (pace notes) generadas desde la geometría de la pista ═══
   Escala 1-6 como en el rally real: 1 = muy cerrada … 6 = casi recta. "Horquilla" si es cerradísima.
   "larga", "cierra", "abre", "cresta", "y" (encadenadas). */
export function buildPaceNotes(track){
 const S=track.samples,N=S.length,cum=track.cum;if(!S||N<50)return [];
 const W=4,k=new Float32Array(N);
 for(let i=0;i<N;i++){const a=S[(i-W+N)%N],b=S[i],c=S[(i+W)%N];const h1=Math.atan2(b.x-a.x,b.z-a.z),h2=Math.atan2(c.x-b.x,c.z-b.z);let d=h2-h1;d=Math.atan2(Math.sin(d),Math.cos(d));const ds=(Math.hypot(b.x-a.x,b.z-a.z)+Math.hypot(c.x-b.x,c.z-b.z))/2||1;k[i]=d/ds;}
 const ks=new Float32Array(N);for(let i=0;i<N;i++){let s=0;for(let j=-3;j<=3;j++)s+=k[(i+j+N)%N];ks[i]=s/7;}
 const KMIN=1/240;const notes=[];let i=0;
 /* empezar en un tramo recto para no partir una curva */
 let start=0;for(let j=0;j<N;j++)if(Math.abs(ks[j])<KMIN*0.5){start=j;break;}
 const seen=new Uint8Array(N);
 for(let n=0;n<N;n++){i=(start+n)%N;if(seen[i]||Math.abs(ks[i])<KMIN)continue;const sg=Math.sign(ks[i]);let j=i,maxK=0,maxAt=i,len=0;
  while(Math.abs(ks[j])>=KMIN*0.7&&Math.sign(ks[j])===sg&&len<400){seen[j]=1;if(Math.abs(ks[j])>maxK){maxK=Math.abs(ks[j]);maxAt=j;}const jn=(j+1)%N;len+=S[j].distanceTo(S[jn]);j=jn;}
  const R=1/Math.max(maxK,1e-4);if(R>235||len<10)continue;
  const sev=R<18?0:R<30?1:R<45?2:R<70?3:R<100?4:R<145?5:6;
  const posFrac=((maxAt-i+N)%N)/Math.max(1,(j-i+N)%N);
  notes.push({idx:i,end:j,s:cum[i],dir:sg>0?'izq':'der',sev,long:len>95,tight:posFrac>0.62&&len>50,open:posFrac<0.3&&len>50});}
 /* crestas: cambio brusco de pendiente hacia abajo */
 for(let n=0;n<N;n+=3){const a=S[(n-12+N)%N],b=S[n],c=S[(n+12)%N];const d1=(b.y-a.y)/Math.max(1,Math.hypot(b.x-a.x,b.z-a.z)),d2=(c.y-b.y)/Math.max(1,Math.hypot(c.x-b.x,c.z-b.z));
  if(d1-d2>0.07&&!notes.some(o=>Math.abs(o.s-cum[n])<35))notes.push({idx:n,s:cum[n],crest:true,sev:7});}
 notes.sort((a,b)=>a.s-b.s);
 /* encadenar notas cercanas con "y" */
 for(let q=0;q<notes.length-1;q++){const gap=notes[q+1].s-notes[q].s;if(gap<45)notes[q].into=true;}
 for(const o of notes)o.text=noteText(o);
 return notes;}
const NUM=['Horquilla','1','2','3','4','5','6'];
export function noteText(o){if(o.crest)return 'Cresta';let t=(o.sev===0?'Horquilla ':NUM[o.sev]+' ')+(o.dir==='izq'?'izquierda':'derecha');if(o.long)t+=' larga';if(o.tight)t+=' cierra';else if(o.open)t+=' abre';return t;}
export function noteSpeech(o){const w=['horquilla','uno','dos','tres','cuatro','cinco','seis'];if(o.crest)return 'cresta';let t=(o.sev===0?'horquilla':w[o.sev])+' '+(o.dir==='izq'?'izquierda':'derecha');if(o.long)t+=' larga';if(o.tight)t+=' cierra';else if(o.open)t+=' abre';if(o.into)t+=', y';return t;}
export function noteShort(o){if(o.crest)return '⌒';return (o.sev===0?'H':o.sev)+(o.dir==='izq'?'↰':'↱');}
export function noteColor(o){if(o.crest)return '#8fd8ff';return o.sev<=2?'#ff4d5e':o.sev<=4?'#ffc83d':'#3ddc84';}
