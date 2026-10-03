# Mapas fantasía

Sección propia del juego (inicio → **FANTASÍA**): mapas sueltos de mundos imposibles, **todos hechos en papel** (papercraft). No pertenecen a ninguna copa ni suman
estrellas; se corren contra rivales que siguen tu ritmo (`race.gd::_pace_rivals`). Están también en los rankings online (una tabla por mapa).

| Mapa | Id | Vuelta | Qué tiene |
|---|---|---|---|
| Vórtice de Ensueño | `dream` | 9,7 km · +300 m | flores gigantes, Júpiter en el cielo y un agujero negro debajo (`docs/MAPA_ENSUENO.md`) |
| Marte · Monte Olimpo | `marte` | 9,4 km · +330 m | llanura de óxido, subida por la ladera del volcán, caldera, bajada y cañón; mesetas, picos y arcos de roca, cactus y cristales alienígenas, bases, antenas y rovers; dos lunas chicas y mar de polvo abajo |
| La Luna · Mar de la Tranquilidad | `luna` | 7,0 km · ±60 m | cráteres (el camino baja y sube por ellos), rocas grises, módulo lunar con astronauta y banderas, cúpulas, la Tierra en el cielo y estrellas por todos lados |
| Anillo de Júpiter | `anillo` | 7,8 km · +50 m | un camino sobre el anillo: hielo y cristales de colores, un puente de hielo, rocas, cometas, satélites y estaciones flotando, un Júpiter enorme con su tormenta y lunas |

## Cómo está armado
- **Rutas**: `tools/dream/planets.py` (planta, perfil de altura y chequeo de pendientes/radios) → `godot/game/data/routes.json`. Cada mapa es de tipo `"kind": "dream"`
  con un `"world"` (`dream`, `mars`, `moon`, `ring`), un `tagline`, los km y el desnivel (los usa la pantalla de la sección).
  Corre con `python3 tools/dream/planets.py --write`. Los 72 puntos de control van a igual distancia (si no, la Catmull-Rom se pasa de largo y la bajada sale más brusca).
- **Pista**: `track/dream_track.gd` (peralte, meseta plana a los costados, pared invisible a 7,5 m de la banquina), la misma para todos; su `theme` elige el mundo.
- **Mundo**: `track/fantasy_world.gd` extiende a `dream_world.gd`: mismos tramos de dibujo y plantas en MultiMesh, pero con la tabla `DEFS` de cada mundo (colores del suelo
  por zona, piezas por capa y distancia de visibilidad, faldón de capas, colores del camino, pórticos cada tanto, escenografía, objetos flotantes del anillo y cráteres pintados).
  La densidad sigue la calidad gráfica (0,5 · 0,75 · 1) como en el Vórtice.
- **Piezas de papel** (`tools/paper/spacepieces.py`, 62 piezas ≤ 420 triángulos, los pórticos ≤ 900): `m_*` Marte, `l_*` Luna, `r_*` anillo, `x_portico_*`.
  Caras de un solo color iluminadas según hacia dónde miran, sin texturas. Corre con `python3 tools/paper/spacepieces.py` (después de `paperize.py`).
- **Cielo y luz**: `fx/space_sky.gdshader` (degradé, estrellas redondas, planeta —gigante de gas o la Tierra—, lunas chicas, sol y nebulosa) y `fx/space_sea.gdshader`
  (mar de polvo de Marte); los parámetros de cada mundo están en `FantasyWorld.atmosphere_of`. Los destellos del sol son los de `fx/dream_flare.gd`.
- **Menú**: `ui/menu_career.gd` (`_fantasy()` la pantalla de tarjetas, `_quick()` con `quick["fantasy"]` los ajustes de la carrera) y el tile del inicio en `ui/menu.gd`.
  Las miniaturas son `ui/tracks/<mapa>_0.jpg` y `_1.jpg` (se sacan de las capturas).

## Pruebas y capturas
- `tests/fantasy_test.gd`: largo, desnivel, pendientes, peralte, suelo continuo, límite lateral, que existan las piezas, cantidad de piezas y que el rival se quede a la par.
- `tests/fantasy_shots.gd`: capturas desde varios puntos de la vuelta de cualquier mapa (también `dream`):
  `xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 --script res://tests/fantasy_shots.gd -- /carpeta marte`.
- Una carrera real: `tools/godot/run_shot.sh /tmp/x.png --track=luna --cars=2 --auto --cam=chase --viewat=0.3`.
- Piezas: `tests/paper_catalog.gd` (`-- /carpeta m_ 9` saca las de Marte).

## Online
Cada mapa tiene su fila en `public.tracks` (migración `20261004000000_fantasy_tracks.sql`; hay que aplicarla con el flujo «Supabase · aplicar migraciones»).

## Ideas
Gravedad lunar (hoy el auto se maneja igual en todos), más mundos (Venus con lluvia ácida, Saturno, una estación espacial), tormentas de polvo en Marte, y que cada
mapa tenga su propio tema musical.
