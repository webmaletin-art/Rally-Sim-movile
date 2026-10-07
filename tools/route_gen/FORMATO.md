# Formato «dreamracing-route» v1 (lo que exporta el generador HTML y lo que importa el juego)

Un archivo `.json` por ruta. Todo en metros. Ejes: **x y z son los del juego; `y` es la ALTURA** (arriba), `x`/`z` el plano del mapa.

```json
{
  "format": "dreamracing-route",
  "version": 1,
  "id": "cantera_sur",
  "name": "Cantera del Sur",
  "icon": "⛏️",
  "type": "circuit",
  "surface": "dirt",
  "route": {
    "halfWidth": 3.6,
    "shoulder": 2.0,
    "points": [[727, 67, 0], [558, 64, 81], [498, 58, 149]]
  },
  "race": { "laps": 2 },
  "scenery": { "trees": ["pino", "roble"], "density": 0.6, "ground": "grass" },
  "meta": { "generator": "generador-rutas-html", "seed": 12345, "lengthM": 4321 }
}
```

| Campo | Qué es |
|---|---|
| `id` | minúsculas, números y `_` (3–24). Es el nombre interno; no se repite. |
| `name`, `icon` | lo que ve el jugador (el ícono es un emoji). |
| `type` | `circuit` (da vueltas), `point_to_point` (de A a B) o `drag` (aceleración recta). |
| `surface` | `asphalt` o `dirt`. |
| `route.points` | puntos de control `[x, y, z]` de un **lazo CERRADO** (el último se une con el primero). El punto 0 es **A** (la largada), mirando hacia el punto 1. |
| `route.halfWidth` | medio ancho del camino (asfalto 4.2–5.6, tierra 3.0–4.4). |
| `route.shoulder` | banquina a cada lado: 1.6–2.6. |
| `race.laps` | (circuit) 1–5 vueltas. |
| `race.seg` | (point_to_point) `[desde, hasta]`: fracciones 0–1 del lazo que se corren. Largar en `0`. **A = punto 0 · B = punto en la fracción `hasta`**. |
| `drag` | (drag) `{ "lengthM": 201 \| 402 \| 804 }` y nada de `route`. Recta de largada con cambios manuales, cinta de llegada y reloj. |
| `scenery` | `trees`: especies de `pino cipres alamo hoja_ancha roble abedul sasafras palmera coco` · `density` 0–1 · `ground`: `grass dirt sand`. |

## La curva
El camino es la curva **Catmull-Rom uniforme CERRADA** que pasa por los puntos (la misma que usa el juego), con la altura interpolada igual:

```
P(t) = 0.5 * ( 2·P1 + (−P0+P2)·t + (2·P0−5·P1+4·P2−P3)·t² + (−P0+3·P1−3·P2+P3)·t³ ),   t en [0,1]
```
(cada componente x, y, z por separado; los índices dan la vuelta: `P0 = pts[i−1]`, `P1 = pts[i]`, `P2 = pts[i+1]`, `P3 = pts[i+2]`).

## Reglas (el juego se niega a importar lo que no las cumple)
1. **12 a 48 puntos**; entre puntos consecutivos (incluido el último → el primero) **40 a 260 m**.
2. |x| y |z| ≤ 1500 m; altura `y` entre 0 y 250 m.
3. Largo del lazo: circuito **1800–7000 m**; punto a punto **4000–12000 m** (y la parte que se corre, `seg`, **1800–6000 m**).
4. **Radio de curva mínimo** (en planta, sobre la curva): asfalto ≥ 22 m, tierra ≥ 18 m.
5. **Pendiente máxima** 12 % (promedio en 20 m).
6. **El camino no puede tocarse ni cruzarse**: dos partes del camino separadas por más de 60 m de recorrido tienen que estar a ≥ `2·(halfWidth+shoulder)+12` m de distancia en planta.
7. Los **primeros 150 m desde A** son casi rectos (radio ≥ 90 m) para armar la parrilla.
8. `id` único; `type` y `surface` válidos; especies de árboles de la lista.

## Cómo se integra
`python3 tools/route_gen/route_spec.py ruta.json` (valida) → `python3 tools/route_gen/import_route.py ruta.json --event c1 --reverse` (la mete en el juego y en el evento de la copa) → `godot --headless --script res://tests/custom_route_test.gd` (la IA da una vuelta sin salirse).
