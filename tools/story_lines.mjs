// Junta todas las frases de la historia (js/story_data.js) con su id → docs/dialogos/historia_lineas.json (para gen_dialogos.py)
import {CHAPTERS} from '../js/story_data.js';
import fs from 'fs';
const out={},who={};const id=(m,p,k)=>`${m}_${p}_${k}`;
const add=(k,l)=>{out[k]=[{t:l[1],i:2}];who[k]=l[0];};
for(const c of CHAPTERS){c.hook.forEach((l,k)=>add(id('ch'+c.n,'hook',k),l));
 for(const m of c.missions){m.intro.forEach((l,k)=>add(id(m.id,'intro',k),l));m.win.forEach((l,k)=>add(id(m.id,'win',k),l));m.lose.forEach((l,k)=>add(id(m.id,'lose',k),l));
  for(const [tr,L] of Object.entries(m.during||{}))L.forEach((l,k)=>add(id(m.id,'d_'+tr,k),l));}}
fs.writeFileSync('docs/dialogos/historia_lineas.json',JSON.stringify(out,null,1));
console.log(Object.keys(out).length,'frases');
