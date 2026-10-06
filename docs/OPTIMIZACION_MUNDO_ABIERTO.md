# Optimización del mundo abierto (Dream City)

Objetivo: ~60 FPS estables en el celular **sin vaciar el mapa** (ciudades, pueblos, árboles, vegetación, horizonte, edificios y tránsito siguen ahí): se optimiza reusando, instanciando, con niveles de detalle (LOD), impostores, menos llamadas de dibujo y materiales/texturas compartidos. Alcance: **árboles, vegetación lejana / horizonte, edificios y autos civiles**. No se tocó física, controles, autos del jugador ni de otros jugadores, cámaras, carreras, misiones, online, economía, garaje, tuning, sonido, interfaz ni jugabilidad.

> Aclaración honesta: los FPS del celular de la prueba de vegetación no llegaron como números, sólo la impresión del dueño («los dos impostores funcionan bien», «Drift se ve más lindo»). Por eso las elecciones de abajo se justifican con lo que **sí se puede medir sin el celular**: triángulos, materiales, llamadas de dibujo, memoria y tiempo de armado. Los FPS reales se miran en el APK (Opciones → Gráficos → Mostrar FPS).

## 1. Árboles — 8 VISTAS cerca + CRUZ lejos (una sola textura)
- **Qué hay:** 7 especies de árbol y 2 de palmera (`city/tree_sprites.gd`): pino, ciprés, álamo, hoja ancha, roble, abedul, sasafrás y palmera/coco (las palmeras sólo en la playa, z > 1040). Salen de los **mismos árboles de papel** que ya estaban en las plazas (misma paleta, el estilo no cambia): `tools/vegworld/render_world_trees.gd` dibuja las 8 vistas (cada 45°) y `process_world_trees.py` las limpia (promedio premultiplicado y color de borde, sin halos) → `godot/game/city/trees/<especie>_<ángulo>.png` + `trees.json`. Se descartaron las especies de la biblioteca con ramas finas (acacia, sauce, tupelo, abedul B, pino SC): como imagen quedan como bolas flotando sin tronco.
- **Cómo se dibuja:** las 72 imágenes (9 especies × 8 vistas, 192 px) viven en **una textura de capas** (≈ 14 MB con mipmaps) compartida por todo el mundo. Por cuadra hay **un MultiMesh por nivel** (2 llamadas de dibujo por cuadra con árboles):
  - **8 VISTAS** (`shaders/tree_bill.gdshader`): un cuadro de 2 triángulos que mira a la cámara y elige la vista según el ángulo; para las cuadras a menos de ~190 m.
  - **CRUZ** (`shaders/tree_cross.gdshader`): dos cuadros cruzados (4 triángulos) con las vistas de 0° y 90° **de la misma textura** (no cuesta memoria); desde ahí hasta donde se arma el mundo (~520 m).
- **Por qué esta mezcla:** las 8 vistas son mejores en calidad (la silueta nunca «gira» como los planos cruzados) pero la cruz es más barata de calcular y no necesita el cálculo de ángulo por vértice; como las dos usan **la misma textura**, tener las dos no cuesta nada de memoria. Cerca (donde se nota) 8 vistas; lejos (donde el costo cuenta) cruz.
- **Variedad natural:** el monte tiene «manchones» de 45 m con una especie preferida (como un monte real) y un tercio de los árboles salen distintos; cada árbol tiene escala 0,6–1,3, giro propio y un tinte (más claro/oscuro, hacia amarillo o azul). Sobre cada árbol de ruta se suman 0 a 3 más, **atrás y a distinta distancia del camino** (sólo donde no pisan calle, playón, peaje ni garaje): ya no quedan en fila.
- **Qué reemplaza:** los árboles de ruta eran recortes de papel de ~100 triángulos cada uno, mezclados en la malla de objetos (se veían a 190 m); los árboles de calle/plaza/gasolinera/peaje/boca de túnel eran árboles de papel con volumen de 160 a 430 triángulos. Ahora son imágenes de 2–4 triángulos. Los árboles de calle **se siguen rompiendo**: el sano es una imagen, el roto un recorte de papel tirado en la malla de objetos de la cuadra (`CityProps.emit` → `card_tree`).
- **De noche:** las imágenes traen la luz de día pintada; `set_night()` las oscurece con un tinte (igual que el reloj de la ciudad).

## 2. Vegetación lejana / horizonte
- `city/horizon_trees.gd` + `shaders/horizon_trees.gdshader`: **dos anillos** de bosque (radios 395 y 335 m, 72 segmentos, 144 triángulos en total, 2 llamadas de dibujo) que acompañan a la cámara delante de las lomas pintadas de siempre. Cada anillo es una **tira de 2048 × 64 px** hecha con las siluetas de las mismas imágenes de árboles (`tools/vegworld/make_horizon.py`): tres filas (atrás más clara y chica, adelante más oscura), manchones densos y claros, hileras de álamos, copas de distinta altura y una faja de arbustos abajo. **El borde de arriba es irregular: no es un muro rectangular.**
- Se repiten 4 y 3 veces por vuelta con **tiras distintas** y a distinto radio, así que no se nota la repetición. La niebla del juego las funde con la distancia. Sobre el mar se «hunden» en el piso (no hay árboles sobre el agua) y en el bolsillo de los túneles se apagan.
- Reemplazan a «miles de árboles individuales» a esa distancia: costo fijo de 144 triángulos y 2 texturas de 128 KB.
- **LOD resultante:** cerca = 8 vistas · medio = cruz · lejos = anillos del horizonte (más las lomas pintadas).

## 3. Edificios — se queda DREAM CITY
Medido con la misma calle y la misma cantidad de edificios (`veg_buildings.gd`, 1000 edificios):

| | DRIFT / AVENTURA (atlas modular) | DREAM CITY (cajas + shader) |
|---|---|---|
| triángulos por edificio | **213** | **10** |
| triángulos totales (1000) | 213 360 | 10 000 |
| memoria de malla (1000) | ~22,5 MB | ~1,6 MB |
| tiempo de armado (1000, PC) | ~390 ms | ~27 ms |
| llamadas de dibujo | 51 | 51 |
| materiales / texturas | 1 / atlas de 512² | 1 / ninguna (ventanas por shader) |

Regla del dueño: si Drift cuesta prácticamente lo mismo → Drift (más lindo); si suma costo apreciable → Dream City. Drift tiene **21 veces más geometría y 14 veces más memoria y tiempo de armado** (cada cuadra nueva que se arma al avanzar sería un tirón) → **Dream City**. Además el mundo abierto ya estaba hecho con Dream City, así que no cambia el estilo.

**Edificios lejanos con la versión más barata** (`fx/city_facade.gdshader`): entre 200 y 270 m (× alcance de vista, `lod_from`/`lod_to`) las ventanas, postigos, balcones, vidrieras y dobleces se funden en una pared lisa del mismo color y, pasado `lod_to`, el shader ni los calcula. Es el costo de píxel más alto de la ciudad y la mayoría de lo que se ve está lejos. Sin recarga de malla, sin saltos (es un fundido) y el mismo material.

## 4. Autos civiles — «cajas con rampas»
- `world/civil_car_mesh.gd`: una carrocería armada con cortes a lo largo del auto (baúl, luneta inclinada, techo, parabrisas inclinado, capó), ruedas de seis lados, faros y luces traseras: **186 triángulos con normales planas**, contra 84 de las siete cajas apiladas (que además no tenían normales y se veían «de adentro»). Lo usan **estacionados** (`parked_cars.gd`), **tránsito** (`civil_traffic.gd`) y por lo tanto los lejanos: una sola malla y un MultiMesh por sector (una llamada de dibujo), el color y las tres variantes (hatchback / sedán / SUV) siguen saliendo de la escala y el color de cada instancia.
- **No se tocó** el auto del jugador, los autos de otros jugadores (`online/remote_cars.gd`) ni los modelos de competencia.

## Verificación
Ver `tests/` (city_test, civil_traffic_test, parked_cars_test, world_life_test, world_budget_test, + la prueba de manejo larga del mundo abierto con `--autotest=gt@aurelia@salida_20`). Cómo sacar capturas: `tests/city_shots.gd`.

## Cómo regenerar las imágenes
```
cp tools/vegworld/render_world_trees.gd godot/tests/    # (y borrarlo después)
cd godot && xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tests/render_world_trees.gd -- /tmp/vegworld_raw
python3 tools/vegworld/process_world_trees.py /tmp/vegworld_raw
python3 tools/vegworld/make_horizon.py
```
