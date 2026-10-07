# Formato «dreamracing-route» v3 (lo que exporta el editor de trazados `editor_trazados.html`)

Un `.json` por mapa → **`godot/game/data/custom_maps/<id>.json`**: el juego lo lee solo al arrancar (Carrera rápida; con `career`, reemplaza un evento). La CI lo valida con `route_spec3.py` y le hace dar una vuelta a la IA (`tests/custom_route_test.gd`). Prompt del editor: `PROMPT_EDITOR_V3.md`. La v2 (`FORMATO.md`) se sigue leyendo.
**El editor sólo define el TRAZADO y la configuración. Árboles, vegetación y borde del camino los pone el juego (al azar, según la potencia de cada celular).** Metros; **x z = plano, y = altura**.

```json
{ "format": "dreamracing-route", "version": 3, "id": "ocho_del_lago", "name": "Ocho del Lago", "icon": "♾️",
  "type": "circuit",
  "route": { "halfWidth": 4.6, "shoulder": 2.0, "points": [[x, y, z], …] },
  "sections": [ { "from": 0.0, "to": 0.5, "surface": "asphalt", "label": "Largada", "density": 0.6 }, … ],
  "weather": { "sky": "day" },
  "scenery": { "trees": "mixed", "density": 0.6 },
  "decor": { "edge": "auto", "vegetation": 1.0 },
  "slope": { "mode": "descent", "deg": 4.0 },
  "race": { "style": "chase", "laps": 2, "chase": { "maxGapM": 150 }, "elimination": { "everySec": 30 } },
  "rivals": { "count": 1, "difficulty": 0.6 },
  "career": { "tier": "continental", "event": "c1", "sky": "day", "reverse": false },
  "reverse": true, "meta": { } }
```

| Campo | Qué es |
|---|---|
| `type` | `circuit` (lazo cerrado, vueltas) o `point_to_point` (A→B). |
| `route.points` | Circuito: lazo CERRADO sin repetir el primero. A→B: camino ABIERTO, primero = A (largada), último = B (meta). **El camino puede cruzarse consigo mismo** (un 8, una cruz): es un cruce a nivel. |
| `sections` | Superficie por tramo (`asphalt dirt gravel mud sand`), fracciones 0–1 seguidas (del lazo, o de A→B), ≥ 60 m cada una, máx. 200. `density` = tendencia de árboles del tramo. |
| `weather.sky` | `day overcast sunset dusk rain` (el clima con el que arranca en Carrera rápida; el jugador lo puede cambiar). |
| `scenery` | `trees` `none pine broadleaf mixed` · `density` 0–1. |
| `decor` | `edge`: `auto` (el juego elige al azar: guardarraíl de chapa, tablón de madera o cerco; siempre el mismo para ese mapa), `guardrail`, `wood`, `fence` · `vegetation` 0–1 (matas junto al camino). |
| `slope` | (opcional) `mode`: `free` `descent` `ascent` + `deg` (grados promedio, 0–6.9). Lo escribe el editor con la «varilla» de descenso/ascenso: las alturas reales van en `route.points` y el juego usa ésas; `slope` sólo sirve para reabrir el mapa en el editor. Descenso/ascenso: sólo A→B y sin cruces. |
| `race.style` | `race` carrera · `timetrial` contrarreloj · `adventure` una sola pasada (sin vueltas) · `chase` persecución · `elimination` eliminación. Es el modo con el que arranca en Carrera rápida (el jugador lo puede cambiar). |
| `race.laps` | circuito, 1–5. En A→B se corre una sola pasada. |
| `race.chase.maxGapM` | persecución: distancia de escape, 60–1000 m. `race.elimination.everySec`: 15–120 s. |
| `rivals` | `count` 0–7 (persecución: 1) · `difficulty` 0–1 (1 %…100 %; habilidad de la IA = 0.62 + 0.42·dificultad). |
| `career`, `reverse` | como en v2. `reverse` sólo circuitos. |

## Qué hace el juego
- **Cruces a nivel** (`RouteTrack._find_crossings`): se marcan las muestras donde otra parte del camino (a más de 160 m de recorrido) pasa a menos de `2·(halfWidth+shoulder)+3` m. Ahí: las dos alturas se igualan (con suavizado de ~80 m), el camino «de arriba» se sube 3 cm (para que no parpadeen), **no se dibuja el guardarraíl, la banquina ni la vegetación que caerían sobre el otro camino**, y el auto **sigue al camino que tiene más cerca** (se puede doblar en el cruce sin chocar con un muro invisible). El avance de la carrera es lo que recorre el auto (`Session`): cambiar de camino en el cruce no regala ni quita vueltas.
- **A→B** (camino ABIERTO, sin tramo de vuelta): `MapData.open_ctrl` agrega 2 puntos «fantasma» antes de A y 2 después de B; `RouteTrack` sólo muestrea de A − 200 m a B + 200 m (`open_lo`/`open_hi`) y no dibuja ningún cierre. Se corre de A a B (`defaults.seg`). La altura es la de la curva por los puntos (`exact_y`): una bajada de 4° es de 4° en todo el recorrido.
- **Persecución** (`race_rules.gd`): un rival. Quien va atrás persigue; si el de adelante se escapa a `maxGapM`, gana. Los roles cambian al pasar (con 3 m de margen). El rival adelante sostiene su ritmo (de 0,90 a 1,04 del de la IA según la dificultad: si es más rápido que vos, se escapa); atrás se pega a ~12 m y de a ratos ataca para pasarte.
- **Eliminación**: cada `everySec` segundos sale el último (el de menos recorrido); si sos vos, perdés; gana el que queda. Sin límite de vueltas.
- **Borde del camino**: `guardrail` (chapa acanalada), `wood` (tablón) o `fence` (cerco con dos varas). Con `auto` el juego elige uno según el id del mapa y su superficie.
- **Mapas largos**: sin tope de forma ni de curvas; el juego sube la cantidad de muestras del camino con el largo (una cada ~4,5 m, hasta 6000).

## Reglas (la CI las exige; el editor las muestra en vivo)
1. Puntos: circuito 8–3000, A→B 4–3000; entre consecutivos **30–300 m**. |x|,|z| ≤ 20000; y 0–600; `halfWidth` 3.0–5.6; `shoulder` 1.6–2.6.
2. Largo: circuito ≥ 1000 m; A→B ≥ 800 m (de A a B). Más de 15 km = aviso.
3. Radio mínimo: 22 m (todo asfalto) · 18 m (si hay tierra, grava, barro o arena).
4. Pendiente máx. 12 % (promedio en 20 m). Primeros 150 m desde A casi rectos (radio ≥ 90 m).
5. Cruces (no valen con `slope` descent/ascent): ángulo ≥ 35° (si no, «se pisan en paralelo»); diferencia de altura ≤ 8 m (el editor las iguala); A fuera de un cruce (150 m) y B a más de 100 m de uno.
6. Tramos seguidos de 0 a 1, ≥ 60 m, máx. 200. `race.laps` 1–5, `maxGapM` 60–1000, `everySec` 15–120, `rivals.count` 0–7.

## Cómo se integra
`python3 tools/route_gen/route_spec.py mapa.json` (valida; manda a `route_spec3.py` si `version` es 3) · subir el archivo a `godot/game/data/custom_maps/` · `python3 tools/route_gen/validate_all.py` · `godot --headless --path godot --script res://tests/custom_route_test.gd` y `…/map_v3_test.gd`. Ejemplos: `python3 tools/route_gen/make_example_v3.py ocho|ab salida.json`.
