# Prompt para que DeepSeek (o cualquier IA) arme el GENERADOR DE RUTAS en un solo HTML

Copiá desde la línea «=== PROMPT ===» hasta el final y pegalo. Después subile el ZIP `dreamracing_route_assets.zip` si la IA deja adjuntar archivos (si no, no hace falta: el HTML mismo lo carga). Pedile que te entregue **un único archivo `generador_rutas.html`** completo.
Cuando el HTML ande, exportá una ruta (`.json`), pasámela y yo la meto en la copa que digas.

=== PROMPT ===

Quiero que programes **UN SOLO ARCHIVO `generador_rutas.html`** (HTML + CSS + JavaScript puro, sin servidor ni instalación: se abre con doble clic y anda también en el navegador del celular). Es una herramienta para crear **rutas de carreras** de mi juego de autos «Dream Racing» (motor Godot). Las rutas se exportan como JSON con un formato FIJO que el juego importa y valida. Todo el texto de la interfaz en **español rioplatense**. Diseño oscuro (fondo grafito, acento naranja #ff7a1a, dorado #ffd24a), prolijo, con botones grandes (táctil).

## 1. Cómo carga los recursos
- Un botón «Importar ZIP de recursos» (y también arrastrar y soltar) que lee `dreamracing_route_assets.zip` en el navegador (usá **JSZip** desde cdnjs; no hace falta otra librería para el 2D; para la vista 3D usá **three.js** desde cdnjs o jsdelivr).
- El ZIP trae: `arboles/<especie>_<ángulo>.png` (9 especies × 8 vistas cada 45°, PNG 192×192 transparentes, se dibujan como carteles que giran hacia la cámara), `arboles/trees.json` (alto real `h` en metros de cada especie), `horizonte/horizon_a.png` y `horizon_b.png` (franjas de bosque lejano), `suelo/asphalt.png`, `dirt.png`, `grass.png` (128×128, se repiten), `ejemplos/*.json` y `rutas_del_juego/*.json` (rutas ya en el formato de exportación) y `FORMATO.md`.
- No hay modelos 3D de banquina (cordón) ni de cartel de salida: dibujalos vos con geometría simple (cordón rojo y blanco a los costados del camino; cartel/arco de salida con la palabra SALIDA, y arco de META).
- Si todavía no se cargó el ZIP, el HTML igual funciona (colores lisos y árboles como círculos verdes).
- Botón «Cargar ruta del juego…» que importa un `.json` del mismo formato para seguir editándolo. Autoguardado del trabajo en localStorage.

## 2. Los tres tipos de ruta
1. **Circuito** (da vueltas): lazo cerrado, 1 a 5 vueltas.
2. **Punto a punto (A → B)**: el camino es igual un lazo cerrado (así lo entiende el juego) pero se corre sólo un tramo: de la fracción `desde` (siempre 0 = punto A) a la fracción `hasta` (= punto B). Mostrá marcadores **A** y **B** en el mapa, y la parte que no se corre en gris.
3. **Picada / aceleración**: una recta de largada con **cambios manuales** (nada de curvas), **cinta de llegada** y **reloj**. Largo elegible: 201, 402 u 804 m. Superficie asfalto o tierra. En la vista previa mostrá la línea de largada, la cinta de meta que se rompe y un cronómetro que corre en una animación de prueba. Sólo exporta `drag.lengthM`, `surface` y `scenery` (sin `route`).

## 3. El FORMATO de exportación (exacto, versión 1)
```json
{
  "format": "dreamracing-route", "version": 1,
  "id": "cantera_sur",            // minúsculas, números y _ (3 a 24 caracteres), único
  "name": "Cantera del Sur", "icon": "⛏️",
  "type": "circuit",              // "circuit" | "point_to_point" | "drag"
  "surface": "dirt",              // "asphalt" | "dirt"
  "route": { "halfWidth": 3.6, "shoulder": 2.0, "points": [[x, y, z], ...] },
  "race": { "laps": 2 },          // circuit: laps 1..5  ·  point_to_point: { "seg": [0, 0.55] }
  "drag": { "lengthM": 402 },     // sólo si type = "drag" (y entonces NO hay "route" ni "race")
  "scenery": { "trees": ["pino","roble"], "density": 0.6, "ground": "grass" },
  "meta": { "generator": "generador-rutas-html", "seed": 12345, "lengthM": 4321 }
}
```
- **x, z = plano del mapa en metros; y = ALTURA en metros** (¡no es el plano!). `points` son los **puntos de control** de un lazo cerrado; el punto 0 es **A** (la largada) y el camino sale hacia el punto 1.
- Especies de árbol permitidas: `pino cipres alamo hoja_ancha roble abedul sasafras palmera coco`. `ground`: `grass`, `dirt` o `sand`.
- Exportá con indentación de 1 espacio, números con 1 decimal, y nombre de archivo `<id>.json`.

## 4. LA CURVA (tiene que ser idéntica a la del juego)
El camino es la **curva Catmull-Rom uniforme CERRADA** que pasa por todos los puntos, aplicada a x, y y z por separado:
`P(t) = 0.5 * ( 2·P1 + (−P0+P2)·t + (2·P0−5·P1+4·P2−P3)·t² + (−P0+3·P1−3·P2+P3)·t³ )`, t∈[0,1], con `P0=pts[i−1], P1=pts[i], P2=pts[i+1], P3=pts[i+2]` (índices circulares). Muestreá cada tramo en 24 pasos. Dibujá el camino con ese muestreo y con el ancho real `2·halfWidth`, más la banquina `shoulder` a cada lado.

## 5. REGLAS DE VALIDACIÓN (el panel «Validación» las evalúa en vivo con ✔ / ✖; **el botón Exportar queda deshabilitado mientras haya un ✖**)
1. 12 a 48 puntos de control; distancia entre puntos consecutivos (incluido el último→primero) de **40 a 260 m**.
2. |x| ≤ 1500, |z| ≤ 1500; altura y entre 0 y 250 m.
3. Largo del lazo (de la curva muestreada): circuito **1800–7000 m**; punto a punto **4000–12000 m**, y la parte que se corre (`seg`) **1800–6000 m**.
4. **Radio de curva mínimo** en planta (circunradio de tres muestras separadas ~10 m): asfalto ≥ 22 m, tierra ≥ 18 m.
5. **Pendiente máxima 12 %** (|Δy/Δs| promediado en ventanas de 20 m).
6. **El camino no se toca ni se cruza**: dos muestras separadas por más de 60 m de recorrido tienen que estar a ≥ `2·(halfWidth+shoulder)+12` m en planta. Marcá en rojo en el mapa el punto donde falla.
7. Los **primeros 150 m desde A son casi rectos** (radio ≥ 90 m) para armar la parrilla de largada.
8. `halfWidth`: asfalto 4.2–5.6, tierra 3.0–4.4. `shoulder`: 1.6–2.6. `laps`: 1–5. `id` válido y `name` no vacío.
Mostrá también estadísticas: largo total, largo de la parte que se corre, radio mínimo, pendiente máxima, desnivel total, cantidad de curvas «cerradas» (radio < 40 m).

## 6. Pantallas / funciones
- **Mapa 2D cenital** (canvas, zoom con rueda/pellizco, pan arrastrando): el camino coloreado por altura, flecha de sentido, marcadores A/B, árboles según `scenery`, y el punto de falla de cada regla en rojo.
- **Perfil de altura** debajo del mapa (altura vs. distancia, con la pendiente en color).
- **Vista 3D** (three.js) simple: el camino con textura de suelo, banquinas con cordón rojo/blanco, árboles como carteles de 8 vistas (elegí la vista según el ángulo de la cámara), cartel de SALIDA en A, y una cámara que recorre la ruta («Recorrer») o se mueve libre.
- **Editor manual**: tocar el mapa agrega un punto; arrastrar mueve; doble toque borra; un slider de altura por punto (o arrastrar en el perfil); herramientas «suavizar», «alargar», «invertir sentido», «rotar largada» (elige cuál punto es A).
- **Generador automático (con lógica, no puro azar)**: panel con semilla (con botón 🎲), tipo, superficie, largo objetivo, «curvilínea» (0–1), desnivel (0–1) y ancho. Botones «Generar» y «Variar». El algoritmo recomendado: lazo base con radio polar ondulado (armónicos k = 2..5 con amplitudes decrecientes) y ligero estiramiento; mezclar rectas largas, horquillas abiertas, eses (chicanas) y curvas largas; alturas con 1–3 armónicos suaves que cierran el lazo (y(0)=y(1)); **elegir como punto A la zona más recta**; **reintentar hasta que pase TODAS las reglas** (hasta 3000 intentos con la misma semilla derivando sub-semillas); si no logra, avisar. Para punto a punto: elegir B de modo que `seg` cumpla el largo y el tramo A→B tenga variedad (no sólo una recta).
- **Picada**: panel propio con largo (201/402/804), superficie, entorno, y botones «Probar reloj» y «Exportar».
- **Autotest**: un botón «Probar con las rutas de ejemplo» que carga cada JSON de `ejemplos/` y `rutas_del_juego/` del ZIP y comprueba que tu validador las da por válidas (si alguna falla, es un bug tuyo).
- **Exportar JSON** (descarga) + «Copiar JSON» + «Exportar imagen del mapa (PNG)».

## 7. Entrega
- Un solo `generador_rutas.html`, comentado en español, organizado en secciones (zip, geometría, validación, generador, editor 2D, vista 3D, picada, exportación).
- No inventes campos nuevos en el JSON. No cambies los nombres de las especies ni los límites.
- Antes de entregar, repasá mentalmente que: (a) el generador nunca exporta una ruta inválida, (b) la curva es la Catmull-Rom cerrada de arriba, (c) y es la altura.

=== FIN DEL PROMPT ===
