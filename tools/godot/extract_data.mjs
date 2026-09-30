/* Pasa el contenido del juego (catálogo de autos, mejoras, neumáticos, ajustes, eventos de la carrera) a JSON para Godot:
   godot/game/data/catalog.json  y  godot/tests/expected_build.json (resultados de buildParams/perfOf del HTML para comparar).
   Uso: node tools/godot/extract_data.mjs */
import fs from 'node:fs';
const root = new URL('../../', import.meta.url).pathname;
const D = await import(root + 'js/data.js');
const E = await import(root + 'js/events.js');
const B = await import(root + 'js/carbuild.js');
const strip = o => JSON.parse(JSON.stringify(o, (k, v) => typeof v === 'function' ? undefined : v));
const cat = {
  cars: D.CAR_META, order: D.CAR_ORDER, coming: D.COMING_SOON, upgrades: strip(D.UPGRADES), tires: strip(D.TIRES), tune: strip(D.TUNE_GROUPS),
  paints: D.PAINTS, finishes: D.FINISHES, achievements: D.ACHIEVEMENTS.map(a => ({id: a.id, icon: a.icon, n: a.n, d: a.d, cr: a.cr})),
  presets: D.PRESETS, preset_n: D.PRESET_N, preset_info: D.PRESET_INFO_T,
  tiers: E.TIERS, events: E.EVENTS, types: E.TYPE_INFO, targets: E.TARGETS, classes: B.CLASSES,
};
fs.writeFileSync(root + 'godot/game/data/catalog.json', JSON.stringify(cat));
// referencia de buildParams / perfOf
const src = fs.readFileSync(root + 'js/main.js', 'utf8');
const a = src.indexOf('const VEHICLES={'), b = src.indexOf('\nconst VEHICLE_ORDER');
const VEHICLES = new Function('return ' + src.slice(a + 'const VEHICLES='.length, b).trim().replace(/;$/, ''))();
const states = [
  {upg: {}, tires: 'street', tune: {}},
  {upg: {engine: 2, turbo: 1, weight: 1, brakes: 2}, tires: 'street', tune: {}},
  {upg: {engine: 3, turbo: 2, weight: 3, brakes: 3, suspension: 3, gearbox: 2, diff: 2, aero: 2, nitro: 2, stance: 1}, tires: 'gravel', tune: {pressF: 27, pressR: 26, camberF: -2.5, toeR: 0.3, height: 20, springF: 120, bias: 60, lsd: 150, final: 110, aeroF: 70, aeroR: 40, steer: 110, gripR: 90, stanceCamber: 2}},
];
const out = {cases: []};
const ups = D.UPGRADES.map(u => u.id);
out.upgrade_ids = ups; out.tire_ids = D.TIRES.map(t => t.id);
for (const id of Object.keys(VEHICLES)) for (let si = 0; si < states.length; si++) {
  const st = structuredClone(states[si]);
  // completa las mejoras con el máximo nivel válido
  for (const k of Object.keys(st.upg)) { const u = D.UPG_BY_ID[k]; if (u) st.upg[k] = Math.min(st.upg[k], u.levels.length - 1); }
  if (!D.TIRE_BY_ID[st.tires]) st.tires = 'street';
  const V = B.buildParams(VEHICLES[id], st, {abs: true, tc: 50, stab: 30});
  const P = B.perfOf(V);
  out.cases.push({id, state: st, V: strip(V), perf: P});
}
fs.writeFileSync(root + 'godot/tests/expected_build.json', JSON.stringify(out));
console.log('catálogo: autos', Object.keys(D.CAR_META).length, 'mejoras', D.UPGRADES.length, 'eventos', E.EVENTS.length, '· casos de prueba', out.cases.length, '· ids mejoras', ups.join(','), '· neumáticos', out.tire_ids.join(','));
