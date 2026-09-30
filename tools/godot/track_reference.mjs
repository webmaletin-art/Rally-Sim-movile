/* Referencia de las pistas por curva: corre el código REAL de la clase Track de js/main.js (solo la geometría, sin dibujar)
   y guarda muestras y alturas en godot/tests/expected_tracks.json. godot/tests/track_test.gd compara la versión Godot.
   Uso: node tools/godot/track_reference.mjs */
import fs from 'node:fs';
import * as THREE from '../../vendor/three.module.min.js';
const root = new URL('../../', import.meta.url).pathname;
const src = fs.readFileSync(root + 'js/main.js', 'utf8');
const lines = src.split('\n');
const start = lines.findIndex(l => l.startsWith('class Track{'));
// métodos que hacen falta (líneas completas de la clase hasta que empieza otro método al mismo nivel)
const want = ['control()', 'applyDips()', 'getYAt(t)', 'roadOffset(i)', 'terrainBase(x,z,roadY)', '_scan(x,z,i0,cnt)', '_segD(x,z,i)', 'nearest(x,z)', 'ditchDip(d,se)', 'groundInfo(x,z)', 'ground(x,z)'];
const chunks = {};
let cur = null;
for (let i = start + 1; i < lines.length; i++) {
  const l = lines[i];
  if (l.startsWith('}')) break;
  const m = l.match(/^ ([A-Za-z_]+\([^)]*\)) ?\{/);
  if (m && !l.startsWith('  ')) { cur = m[1]; chunks[cur] = [l]; } else if (cur) chunks[cur].push(l);
}
let body = '';
for (const w of want) { if (!chunks[w]) throw new Error('falta ' + w); body += chunks[w].join('\n') + '\n'; }
const buildStart = lines.findIndex((l, i) => i > start && l.startsWith(' build(){'));
// build(): solo hasta this.length=...
let bl = lines[buildStart].replace('this.buildRoad();this.buildTerrain();this.buildTape();this.buildStart();this.buildScenery();}', '}');
const bAll = [bl];
for (let i = buildStart + 1; i < buildStart + 14; i++) { if (lines[i].includes('this.buildRoad()')) { bAll.push('}'); break; } bAll.push(lines[i]); }
const bump = src.match(/const BUMP_AMP=\{[^}]*\};/)[0];
const mb = src.match(/function microBump[^\n]*\n/)[0];
const routes = JSON.parse(fs.readFileSync(root + 'godot/game/data/routes.json', 'utf8')).routes;
const code = `const clamp=(v,a,b)=>Math.max(a,Math.min(b,v)),lerp=(a,b,t)=>a+(b-a)*t;${bump}${mb}
return class T{constructor(mode,routeId,opts){opts=opts||{};this.mode=mode;const route=ROUTES[routeId];this.routeDef=route;this.halfWidth=route.halfWidth;this.shoulder=route.shoulder;this._control=opts.reverse?[route.points[0],...route.points.slice(1).reverse()]:route.points;this.samples=[];this.tangents=[];this.laterals=[];this.length=0;this.build();}
${body}${bAll.join('\n')}
}`;
const T = new Function('THREE', 'ROUTES', 'window', code)(THREE, routes, {});
const out = {};
const modes = { forest: 'dirt', lake: 'asphalt', quarry: 'dirt', descent: 'asphalt', asphaltLong: 'asphalt' };
for (const [id, mode] of Object.entries(modes)) for (const rev of [false, true]) {
  if (rev && id !== 'forest' && id !== 'asphaltLong') continue;
  const t = new T(mode, id, { reverse: rev });
  const key = id + (rev ? 'Rev' : '');
  const S = t.samples, N = S.length;
  const pick = []; for (let i = 0; i < N; i += 50) pick.push([i, S[i].x, S[i].y, S[i].z]);
  // puntos de prueba: sobre el camino, banquina, pasto y afuera
  const probes = [];
  for (let i = 0; i < N; i += 97) for (const off of [0, 1.5, t.halfWidth + 0.5, t.halfWidth + t.shoulder + 1, t.halfWidth + t.shoulder + 9, -t.halfWidth - 3, -30]) {
    const p = S[i], l = t.laterals[i]; const x = p.x + l.x * off, z = p.z + l.z * off;
    t._hint = null; const g = t.groundInfo(x, z);
    probes.push([x, z, g.y, g.surf]);
  }
  out[key] = { length: t.length, N, mode, halfWidth: t.halfWidth, shoulder: t.shoulder, samples: pick, probes };
}
fs.writeFileSync(root + 'godot/tests/expected_tracks.json', JSON.stringify(out));
console.log(Object.entries(out).map(([k, v]) => k + ' largo ' + v.length.toFixed(1) + ' m · ' + v.probes.length + ' pruebas').join('\n'));
