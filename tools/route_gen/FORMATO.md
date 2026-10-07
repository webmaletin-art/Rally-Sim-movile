# Formato «dreamracing-route» v2 (lo que exporta el generador HTML y lo que lee el juego)

Un `.json` por mapa. Se sube a **`godot/game/data/custom_maps/<id>.json`** y el juego lo lee solo al arrancar (aparece en Carrera rápida; si trae `career`, reemplaza ese evento de la carrera). La CI valida cada archivo de esa carpeta.
Todo en metros. **x y z = plano; `y` = ALTURA.**

```json
{
  "format": "dreamracing-route",
  "version": 2,
  "id": "cantera_sur",
  "name": "Cantera del Sur",
  "icon": "⛏️",
  "type": "circuit",
  "surface": "dirt",
  "route": { "halfWidth": 3.6, "shoulder": 2.0, "points": [[727, 67, 0], [558, 64, 81]] },
  "sections": [
    { "from": 0.00, "to": 0.15, "surface": "asphalt", "label": "Largada", "density": 0.3 },
    { "from": 0.15, "to": 0.60, "surface": "dirt",    "label": "Bosque",  "density": 1.0 },
    { "from": 0.60, "to": 0.80, "surface": "mud",     "label": "Barrial", "density": 0.5 },
    { "from": 0.80, "to": 1.00, "surface": "sand",    "label": "Playa",   "density": 0.1 }
  ],
  "scenery": { "trees": "mixed", "density": 0.6, "ground": "grass" },
  "race": { "laps": 2 },
  "rivals": { "count": 5, "difficulty": 0.62 },
  "career": { "tier": "continental", "event": "c1", "sky": "day", "reverse": false },
  "reverse": true,
  "meta": { "generator": "generador-rutas-html", "seed": 12345, "lengthM": 4321, "stats": { } }
}
```

| Campo | Qué es |
|---|---|
| `id` | minúsculas, números y `_` (3–24). **El archivo se llama `<id>.json`.** No puede repetirse. |
| `name`, `icon` | lo que ve el jugador (ícono = emoji). |
| `type` | `circuit` (da vueltas) o `point_to_point` (de A a B). *(La picada `drag` todavía no la lee el juego.)* |
| `surface` | superficie base: `asphalt` o `dirt`. |
| `route.points` | puntos de control `[x, y, z]` de un **lazo CERRADO**; el punto 0 es **A** (largada) y el camino sale hacia el punto 1. |
| `route.halfWidth` | medio ancho (asfalto 4.2–5.6 · tierra 3.0–4.4). `route.shoulder`: 1.6–2.6. |
| `sections` | **superficie por tramo.** Fracciones 0–1 del lazo, seguidas (cada `from` = el `to` anterior), de 0 a 1, hasta 24 tramos, cada uno ≥ 80 m. `surface`: `asphalt` `dirt` `gravel` `mud` `sand`. `label` opcional. `density`: árboles del tramo 0–1. |
| `scenery` | `trees`: `none` `pine` `broadleaf` `mixed` · `density`: densidad por defecto 0–1 (para tramos sin `density`) · `ground`: `grass` `dirt` `sand`. |
| `race.laps` | (circuit) 1–5. `race.seg` | (point_to_point) `[0, hasta]`, fracciones del lazo; A = punto 0, B = fracción `hasta`. |
| `rivals` | `count` 0–7 · `difficulty` 0–1 (= 1 %…100 % de la barra del generador). |
| `career` | (opcional) la copa y el evento que reemplaza: `tier` (`debut` `nacional` `continental` `leyenda` `camiones`), `event` (id, ver `referencias_mapas.json`), `sky` (`day` `overcast` `sunset` `dusk` `rain`), `reverse` (correrla en sentido inverso). Sin este bloque el mapa sólo está en Carrera rápida. |
| `reverse` | `true` agrega también la versión inversa («(inversa)») en Carrera rápida. |
| `meta` | lo que quiera el generador (semilla, estadísticas estimadas…). El juego lo ignora. |

## Qué hace el juego con cada superficie
asfalto (líneas blancas) · tierra (huellas) · grava (granulado, agarre un poco mejor que la tierra) · barro (oscuro, agarre muy bajo) · arena (clara, agarre medio-bajo). Cada tramo cambia el agarre real del auto **y** el que usa la IA para frenar antes de entrar; el camino se dibuja con la textura de cada superficie.
Árboles: el juego nunca dibuja más que el presupuesto del teléfono (1500 / 3000 / 6000). `density` reparte ese presupuesto: 1.0 = todo, 0.5 = la mitad, 0 = nada; los tramos con menos densidad quedan más ralos. `pine` = pinos, `broadleaf` = mayoría de hojas anchas, `mixed` = mezcla.
Dificultad: habilidad de la IA = `0.62 + 0.42·difficulty` (Debut ≈ 33 %, Nacional ≈ 52 %, Continental ≈ 67 %, Leyenda ≈ 81 %).

## La curva
**Catmull-Rom uniforme CERRADA** que pasa por los puntos, aplicada a x, y, z por separado:
`P(t) = 0.5 · ( 2·P1 + (−P0+P2)·t + (2·P0−5·P1+4·P2−P3)·t² + (−P0+3·P1−3·P2+P3)·t³ )`, `P0=pts[i−1] P1=pts[i] P2=pts[i+1] P3=pts[i+2]` (índices circulares), 24 pasos por tramo.

## Reglas (la importación y la CI las exigen)
1. **12–48 puntos**; entre consecutivos (incluido último→primero) **40–260 m**.
2. |x|,|z| ≤ 1500; altura 0–250.
3. Largo del lazo: circuito **1800–7000 m**; punto a punto **4000–12000 m** y la parte que se corre **1800–6000 m**.
4. Radio de curva mínimo (en planta): asfalto ≥ 22 m, tierra ≥ 18 m (si hay tramos de tierra/barro/arena/grava vale el de tierra).
5. Pendiente máxima 12 % (promedio en 20 m).
6. El camino no se toca ni se cruza: dos partes separadas por más de 60 m de recorrido a ≥ `2·(halfWidth+shoulder)+12` m.
7. Los primeros 150 m desde A casi rectos (radio ≥ 90 m).
8. Tramos: seguidos de 0 a 1, ≥ 80 m cada uno, superficie válida, máx. 24. `rivals`, `race`, `scenery`, `career` con los rangos de la tabla.

## Cómo se integra
`python3 tools/route_gen/route_spec.py ruta.json` (valida) · `python3 tools/route_gen/import_route.py ruta.json [--tier T --event E] [--reverse]` (la copia a la carpeta; o simplemente subí el archivo a `godot/game/data/custom_maps/`) · `python3 tools/route_gen/validate_all.py` (todos los mapas de la carpeta; lo corre la CI) · `godot --headless --path godot --script res://tests/custom_route_test.gd` (la IA da una vuelta a cada mapa).
