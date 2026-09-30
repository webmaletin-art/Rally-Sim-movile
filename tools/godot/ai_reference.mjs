/* Corre la IA REAL de la versión HTML (js/ai.js) con la física y la pista reales, y dice si da la vuelta.
   Sirve para comparar con godot/tests/ai_route_test.gd (la versión Godot).  Uso: node tools/godot/ai_reference.mjs [ruta] [auto] */
import fs from 'node:fs';
import * as THREE from '../../vendor/three.module.min.js';
const root = new URL('../../', import.meta.url).pathname;
const src = fs.readFileSync(root + 'js/main.js', 'utf8');
const lines = src.split('\n');
// Physics
const p0 = src.indexOf('function tireCurve'), p1 = src.indexOf('const CFG=VEH;');
const {Physics} = new Function('const clampP=(v,a,b)=>Math.max(a,Math.min(b,v));const VEH={};' + src.slice(p0, p1) + ';return {Physics};')();
// Track (solo geometría)
const start = lines.findIndex(l => l.startsWith('class Track{'));
const want = ['control()', 'applyDips()', 'getYAt(t)', 'roadOffset(i)', 'terrainBase(x,z,roadY)', '_scan(x,z,i0,cnt)', '_segD(x,z,i)', 'nearest(x,z)', 'ditchDip(d,se)', 'groundInfo(x,z)', 'ground(x,z)'];
const chunks = {}; let cur = null;
for (let i = start + 1; i < lines.length; i++) { const l = lines[i]; if (l.startsWith('}')) break; const m = l.match(/^ ([A-Za-z_]+\([^)]*\)) ?\{/); if (m && !l.startsWith('  ')) { cur = m[1]; chunks[cur] = [l]; } else if (cur) chunks[cur].push(l); }
let body = ''; for (const w of want) body += chunks[w].join('\n') + '\n';
const bs = lines.findIndex((l, i) => i > start && l.startsWith(' build(){'));
const bAll = [lines[bs].replace('this.buildRoad();this.buildTerrain();this.buildTape();this.buildStart();this.buildScenery();}', '}')];
for (let i = bs + 1; i < bs + 14; i++) { if (lines[i].includes('this.buildRoad()')) { bAll.push('}'); break; } bAll.push(lines[i]); }
const bump = src.match(/const BUMP_AMP=\{[^}]*\};/)[0], mb = src.match(/function microBump[^\n]*\n/)[0];
const routes = JSON.parse(fs.readFileSync(root + 'godot/game/data/routes.json', 'utf8')).routes;
const T = new Function('THREE', 'ROUTES', 'window', `const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t;${bump}${mb}
return class T{constructor(mode,routeId,opts){opts=opts||{};this.mode=mode;const route=ROUTES[routeId];this.routeDef=route;this.halfWidth=route.halfWidth;this.shoulder=route.shoulder;this._control=route.points;this.samples=[];this.tangents=[];this.laterals=[];this.length=0;this.gripMul=1;this.build();}
${body}${bAll.join('\n')}}`)(THREE, routes, {});
const {AIDriver} = await import(root + 'js/ai.js');
const VEHICLES = JSON.parse(fs.readFileSync(root + 'godot/game/data/vehicles.json', 'utf8'));
const cases = process.argv[2] ? [[process.argv[2], process.argv[3] || 'asphalt', process.argv[4] || 't1plus']] : [['forest', 'dirt', 't1plus'], ['quarry', 'dirt', 'pickup'], ['lake', 'asphalt', 't1plus'], ['asphaltLong', 'asphalt', 't1plus'], ['asphaltLong', 'asphalt', 'genesis'], ['descent', 'asphalt', 't1plus']];
for (const [rid, mode, car] of cases) {
  const tr = new T(mode, rid);
  const V = structuredClone(VEHICLES[car]); V.camberF = -1; V.camberR = -0.5; V.toeF = 0; V.toeR = 0.1; V.pressF = 30; V.pressR = 30;
  const ph = new Physics(tr, V);
  // largada igual que la de Godot (slot 0)
  const S = tr.samples, N = S.length; let i = 0, acc = 0; while (acc < 6) { const j = (i - 1 + N) % N; acc += S[i].distanceTo(S[j]); i = j; }
  const l = tr.laterals[i], tg = tr.tangents[i]; ph.reset({x: S[i].x - l.x * 2, z: S[i].z - l.z * 2, yaw: Math.atan2(tg.x, tg.z)});
  const ai = new AIDriver(tr, ph, {skill: 0.95}); ai.enabled = true;
  let t = 0, dist = 0, maxLat = 0, off = 0, prev = null, lap = -1, resp = 0;
  const origRespawn = ai.respawn.bind(ai); ai.respawn = () => { resp++; origRespawn(); };
  const arc = (x, z) => { const h = tr._hint; tr._hint = null; const n = tr.nearest(x, z); tr._hint = h; return [tr.cum[n.idx] + n.t * (tr.cum[n.idx + 1] - tr.cum[n.idx]), n.lateral]; };
  while (t < 420) {
    const inp = ai.update(1 / 120, [], t); ph.step(1 / 120, inp); t += 1 / 120;
    const [a, lat] = arc(ph.px, ph.pz);
    if (prev !== null) { let da = a - prev; if (da < -tr.length / 2) da += tr.length; else if (da > tr.length / 2) da -= tr.length; dist += da; }
    prev = a; maxLat = Math.max(maxLat, Math.abs(lat)); if (Math.abs(lat) > tr.halfWidth) off++;
    if (lap < 0 && dist >= tr.length) { lap = t; break; }
  }
  console.log(`${rid.padEnd(12)} ${car.padEnd(8)} vuelta de ${tr.length.toFixed(0)} m en ${lap > 0 ? lap.toFixed(0) + ' s' : 'NO TERMINÓ'} · máx. desvío ${maxLat.toFixed(1)} m (camino ±${tr.halfWidth}) · pasos fuera ${off} · reapariciones ${resp}`);
}
