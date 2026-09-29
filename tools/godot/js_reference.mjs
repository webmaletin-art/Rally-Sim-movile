/* Extrae de js/main.js (la versión HTML) los autos y la física, y genera:
     godot/data/vehicles.json      → datos de los 4 autos (para Godot)
     godot/tests/expected.json     → trayectorias de referencia de la física JS en una pista plana
   La versión Godot (godot/scripts/physics/vehicle_physics.gd) tiene que dar lo mismo: godot/tests/physics_test.gd los compara.
   Uso: node tools/godot/js_reference.mjs [--time] */
import fs from 'node:fs';
const root=new URL('../../',import.meta.url).pathname;
const src=fs.readFileSync(root+'js/main.js','utf8');
const a=src.indexOf('const VEHICLES={'),b=src.indexOf('\nconst VEHICLE_ORDER');
const VEHICLES=new Function('return '+src.slice(a+'const VEHICLES='.length,b).trim().replace(/;$/,''))();
fs.writeFileSync(root+'godot/data/vehicles.json',JSON.stringify(VEHICLES,null,1));
const p0=src.indexOf('function tireCurve'),p1=src.indexOf('const CFG=VEH;');
const {Physics}=new Function('const clampP=(v,a,b)=>Math.max(a,Math.min(b,v));const VEH={};'+src.slice(p0,p1)+';return {Physics};')();
const flat={samples:[{x:0,z:0}],tangents:[{x:0,z:1}],laterals:[{x:1,z:0}],_hint:null,groundInfo:()=>({y:0,surf:'asphalt'})};
/* escenario: [segundos, throttle, brake, steer, handbrake] */
const scen=JSON.parse(fs.readFileSync(root+'godot/tests/scenario.json','utf8'));if(process.env.EVERY)scen.every=+process.env.EVERY;
const out={};let tms=0;
for(const [id,V0] of Object.entries(VEHICLES)){
 const V=structuredClone(V0);V.camberF=-1;V.camberR=-0.5;V.toeF=0;V.toeR=0.1;V.pressF=30;V.pressR=30;
 const ph=new Physics(flat,V);ph.yawRate=scen.init_yaw_rate||0;const trace=[];let n=0;const t0=performance.now();
 for(const [dur,thr,brk,st,hb] of scen.segments){const steps=Math.round(dur*120);for(let i=0;i<steps;i++){ph.step(1/120,{throttle:thr,brake:brk,steer:st,handbrake:!!hb});n++;
  if(n%scen.every===0)trace.push([ph.px,ph.py,ph.pz,ph.yaw,ph.pitch,ph.roll,ph.vLong,ph.vLat,ph.rpm,ph.gear,ph.steerAngle,...ph.wheels.map(w=>w.omega),ph.aLong,...ph.wheels.map(w=>w.slip),ph.tc,ph.shiftT,ph.load]);}}
 tms+=performance.now()-t0;out[id]=trace;}
fs.writeFileSync(process.env.OUT||(root+'godot/tests/expected.json'),JSON.stringify(out));
if(process.argv.includes('--time'))console.log('JS: '+n_total(scen)+' pasos por auto, '+(tms/4).toFixed(0)+' ms por auto');
function n_total(s){return s.segments.reduce((t,x)=>t+Math.round(x[0]*120),0);}
console.log('OK',Object.keys(out).map(k=>k+':'+out[k].length).join(' '));
