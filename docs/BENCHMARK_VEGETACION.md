# Benchmark de vegetación (ImpostorForestTest)

Prueba **aislada** para medir cuántos árboles aguanta un teléfono con tres técnicas. No toca pistas, física, vehículos, menús del juego ni progresión. Se entra desde **Rendimiento → 🌲 BENCHMARK — VEGETACIÓN** (la pantalla de Rendimiento no está en la versión de Google Play). En PC: `godot --path godot res://game/main.tscn -- --vegbench`.

## Qué hay
| Archivo | Para qué |
|---|---|
| `godot/game/vegbench/ImpostorForestTest.tscn` + `forest_test.gd` | La escena: pista, auto, interfaz, estadísticas y benchmark automático |
| `veg_track.gd` | Pista corta de rally (~2,8 km, curvas, subidas, tramos abiertos) con la clase de pistas por curva del juego; sin tocar `routes.json` |
| `veg_scatter.gd` | Reparto de los árboles con semilla fija: los primeros 1000 son un subconjunto de los 5000, etc. (hasta 20 000) |
| `tree_models.gd` | Los 5 árboles pesados y la carga de su GLB original (3D ORIGINAL) |
| `tree_impostor_8view.gd` + `shaders/impostor8.gdshader` | **TreeImpostor8View**: 1 cuadro (2 triángulos) + 1 textura de 8 capas compartida; elige la vista según el ángulo de la cámara |
| `tree_cross.gd` + `shaders/cross2.gdshader` | **Cross 2 planos**: 2 cuadros cruzados (4 triángulos) + 2 PNG |
| `tex/<árbol>/8views/*.png`, `tex/<árbol>/cross/*.png`, `meta.json` | Imágenes generadas (fondo transparente, sin líneas, sin papel, sin grano) |
| `tools/vegbench/render_views.gd` + `process_views.py` | Cómo se generan las imágenes (ver abajo) |

## Árboles elegidos (los pesados del pack, no los .pap)
| Id | Modelo original | Triángulos | Imágenes |
|---|---|---|---|
| A | Pino SC (`sc_pine.glb`) | 11 554 | 512 px |
| B | Bambú SC (`sc_bamboo.glb`) | 5 913 | 512 px |
| C | Árbol de hoja ancha (`tree_tree.glb`) | 2 992 | 256 px |
| D | Abedul (`tree_birch.glb`) | 2 826 | 256 px |
| E | Sauce llorón (`tree_weeping_willow.glb`) | 2 784 | 256 px |

Los árboles de Dream/Dream City sólo existen como papel (.pap, 160–330 triángulos): no hay un modelo pesado para convertir. Los GLB están copiados en `vegbench/models/`; el pack original sigue en `biblioteca/`.

## Cómo se generan las imágenes
1. `xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/render_views.gd -- /tmp/vegraw` (copiar antes `tools/vegbench/render_views.gd` a `godot/tests/`): dibuja cada árbol a 0°, 45°… 315° con cámara ortogonal, fondo transparente, la misma luz y el mismo encuadre (al doble de resolución).
2. `python3 tools/vegbench/process_views.py /tmp/vegraw`: reduce a la mitad con promedio premultiplicado (bordes suaves, sin halos negros), rellena el color de los píxeles transparentes con el del borde y deja los PNG y el `meta.json` (lado del cuadro `S`, altura, radio).
3. Cross: `front` es la vista 0° y `side` la de 90°.
Para agregar un árbol: sumarlo a `TREES` en `tree_models.gd` (con su GLB en `vegbench/models/`) y repetir 1 y 2.

## Los tres sistemas
* **3D ORIGINAL**: la malla pesada del GLB en un MultiMesh por bloque (referencia de calidad y costo).
* **8 VISTAS PNG**: un cuadro que gira sólo alrededor de Y para mirar a la cámara; el shader calcula el ángulo cámara–árbol y elige una de las 8 capas. Sin luz (la luz va pintada). Los árboles no giran (la luz está en la imagen). Recorte alfa a 0,4.
* **CROSS 2 PLANOS**: dos cuadros fijos a 90° (frente/costado), con la orientación de cada instancia.
Las tres comparten: mismo reparto, bloques de 250 m (un MultiMesh por bloque y especie: el motor oculta los que están fuera de cuadro), sin sombras.

## Opciones (panel; el botón de pausa del juego lo abre y lo cierra)
* **Sistema de vegetación**: 3D ORIGINAL · 8 VISTAS PNG · CROSS 2 PLANOS.
* **Cantidad de árboles**: 1000 (arranque), 2000, 3000, 5000, 7500, 10000, 15000, 20000. Siempre el mismo bosque (los primeros 1000 son un subconjunto de los 5000, etc.).
* **Edificios** (una calle de ciudad a lo largo de toda la pista, mismo reparto para los tres): SIN EDIFICIOS · **DRIFT / AVENTURA** (fachadas modulares de geometría con atlas de texturas) · **DREAM CITY** (cajas de pocas caras con las ventanas dibujadas por el shader) · **PAPEL** (cajas lisas con el material de papel). Cantidad: 100, 200, 400, 800, 1000.
* **Maneja la IA** SÍ/NO (por defecto manejás vos con los controles táctiles del juego, o WASD en PC) y **Reiniciar auto**.
* **FPS** arriba a la izquierda (con el mínimo desde el último cambio), más qué sistema y cuántos hay.
Los árboles se arman en bloques de 250 m (un MultiMesh por bloque y especie: el motor oculta los que están fuera de cuadro). No hay benchmark automático.

## Límites a tener en cuenta
* El 3D ORIGINAL con 10 000 árboles o más son decenas de millones de triángulos: puede congelar el teléfono.
* Las 8 vistas de los árboles A y B (512 px) ocupan ~11 MB de textura cada una sin comprimir; las demás ~2,7 MB.
