// Junta todas las frases de la historia (js/story_data.js) y de los duelos (js/duel_data.js) con su id → docs/dialogos/historia_lineas.json (para gen_dialogos.py)
import {CHAPTERS} from '../js/story_data.js';
import {DUEL_RIVALS,TANO_DUEL,duelLineId} from '../js/duel_data.js';
import fs from 'fs';
const out={},who={};const id=(m,p,k)=>`${m}_${p}_${k}`;
const add=(k,l)=>{out[k]=[{t:l[1],i:2}];who[k]=l[0];};
for(const c of CHAPTERS){c.hook.forEach((l,k)=>add(id('ch'+c.n,'hook',k),l));
 for(const m of c.missions){m.intro.forEach((l,k)=>add(id(m.id,'intro',k),l));m.win.forEach((l,k)=>add(id(m.id,'win',k),l));m.lose.forEach((l,k)=>add(id(m.id,'lose',k),l));
  for(const [tr,L] of Object.entries(m.during||{}))L.forEach((l,k)=>add(id(m.id,'d_'+tr,k),l));}}
/* duelos del mundo abierto: presentación, revancha, final (las cargadas en carrera van solo en texto) */
for(const r of DUEL_RIVALS)for(const part of ['intro','again','win','lose'])r[part].forEach((l,k)=>add(duelLineId(r.id,part,k),l));
for(const [part,L] of Object.entries(TANO_DUEL))L.forEach((t,k)=>add(duelLineId('tano',part,k),['tano',t]));
fs.writeFileSync('docs/dialogos/historia_lineas.json',JSON.stringify(out,null,1));
console.log(Object.keys(out).length,'frases');
