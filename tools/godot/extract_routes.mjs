// Extrae TRACK_ROUTES y MAPS de js/main.js a godot/game/data/routes.json (las pistas por curva de la versión HTML)
import fs from 'fs';
const src = fs.readFileSync(new URL('../../js/main.js', import.meta.url), 'utf8');
function grab(name) {
  const i = src.indexOf('const ' + name + '={');
  let j = src.indexOf('{', i), d = 0, k = j;
  for (; k < src.length; k++) { if (src[k] === '{') d++; else if (src[k] === '}') { d--; if (d === 0) break; } }
  return new Function('return ' + src.slice(j, k + 1))();
}
const routes = grab('TRACK_ROUTES');
const maps = grab('MAPS');
const out = { routes: {}, maps };
for (const k of ['forest', 'lake', 'quarry', 'descent', 'asphaltLong']) out.routes[k] = routes[k];
fs.writeFileSync(new URL('../../godot/game/data/routes.json', import.meta.url), JSON.stringify(out));
console.log(Object.keys(out.routes), Object.keys(maps));
