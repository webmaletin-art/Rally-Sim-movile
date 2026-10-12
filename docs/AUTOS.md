# Autos del juego: cómo se arman

Los 9 autos «nuevos» salen de modelos GLB de una sola malla (carrocería sin ruedas). Todo lo demás —ruedas, frenos de disco, resortes,
amortiguadores, brazos, vidrios, habitáculo— se genera por código a partir de las medidas del modelo.

```
tools/cars/src/car0..8.glb      modelos originales (no se publican en el juego)
tools/cars/build_car.py         escala, mide los pasos de rueda, simplifica y escribe godot/game/models/cars/<id>.glb (+ _lo) y <id>.json
tools/cars/make_vehicles.py     agrega los autos a data/vehicles.json y data/catalog.json
godot/game/car/wheel_gen.gd     mallas de goma, llanta, disco, pinza, resorte
godot/game/car/car_parts.gd     arma las 4 ruedas + suspensión sobre la carrocería y las mueve con la física
godot/game/car/car_visual.gd    carga la carrocería, el sombreador de pintura (rotulados, acabados, vidrios)
godot/game/car/cabin_cfg.gd     medidas del habitáculo de cada auto (a partir del JSON) + ajustes por auto (OVR)
godot/game/car/cockpit.gd       habitáculo, butacas, tablero, volante, tripulación
```

## Tanda 2: 14 autos más (tienda de menor a mayor precio)
Salen de `tools/cars/src/car10..23.glb` (originales de muy alta resolución, no se publican). `tools/cars/prep_sources.py` los ordena/rota/reduce a 120 k triángulos y
`tools/cars/batch2.py` define por auto: medidas (`MODEL`), llanta (`WHEEL`) y física + ficha del catálogo (`SPEC`, `ORDER`). `build_car.py` y `make_vehicles.py` lo leen solos.
Como los modelos traen capas internas y huecos, `remesh_skin` (voxelizar + marching cubes) les hace una piel nueva y cerrada (`close`/`voxel` por auto) y después se
reduce a ~24 k (alta) y ~5 k (baja) triángulos, igual que los anteriores. Los vidrios se miden solos (`glass='auto'`) o se fijan a mano con el polígono (Kodiak, Titán).

| Auto | Precio | Motor / tracción | Carácter |
|---|---|---|---|
| Torito '67 | 20 000 | V8 7.0 · RWD | clásico de demolición, patina y suena a V8 |
| Clásico 60 | 28 000 | 6 cil. 2.8 · RWD | coupé liviano, poca potencia, mucho placer |
| Colossus Titán T4 | 32 000 | diésel 12 L · RWD | camión tractor: tope bajo (105 km/h), torque de sobra |
| Cóndor Kodiak Raid | 36 000 | V6 biturbo · AWD | pick-up de raid, suspensión larga |
| Rally 80 | 58 000 | 4 cil. turbo · AWD | Grupo B moderno, vuela en la tierra |
| KL5 | 68 000 | V6 biturbo · RWD | GT de pista, alerón gigante |
| Trilux | 72 000 | 6 cil. turbo · RWD | coupé equilibrado |
| Trilux S | 88 000 | 6 cil. biturbo · RWD | capó ventilado y alerón |
| Safari | 95 000 | V8 biturbo · AWD | hypercar todo terreno, techo abierto |
| Trilux GT | 112 000 | 6 cil. biturbo · RWD | versión de pista, semi-slick |
| Veltor | 140 000 | V12 híbrido · AWD | superdeportivo, motor central |
| Veltor S | 175 000 | V12 híbrido · AWD | más potencia, menos peso |
| Volcán | 195 000 | V12 aspirado · AWD | hypercar, grita hasta 8700 rpm |
| Veltor GTR | 215 000 | V12 híbrido · AWD | el más rápido de la tanda (slick, +1000 cv) |

Los 14 se compran con créditos del juego (ninguno es premium de Play). Pruebas: `cars_test.gd` (aceleración/frenada/viraje de todos), capturas con
`tools/godot/run_shot.sh out.png --menu --autotest=<id> --auto --cam=chase|cabin`.

### Sonido por auto
`car_audio.gd` tiene `VOICE` (tono, brillo, volumen, ruido y petardeos), `TURBO_SND` (silbido, flutter) y `GEAR_SND` (aullido de la caja) por id para los autos nuevos
(`set_vehicle(id)` en `race.gd`). Los 12 autos anteriores conservan su voz.

### Rotulados con letras
`LIVERIES` suma 7 = **Dream Racing**, 8 = **SRGamestudios**, 9 = **Sport** y 10 = **Nombre del auto**. Las letras salen del atlas `models/cars/decals.png`
(`python3 tools/cars/gen_decals.py`: una fila por texto, se regenera al agregar un auto) y el sombreador de la carrocería las proyecta en las dos puertas
(posición medida con los pasos de rueda y la cintura del GLB, `_set_decal` en `car_visual.gd`). Usan el color «Detalles» del taller; llevan franjas en el capó y el techo.

## Rehacer un auto
```
pip install trimesh fast-simplification numpy scipy shapely rtree networkx
python3 tools/cars/build_car.py gt          # o sin argumentos: todos
python3 tools/cars/make_vehicles.py
godot --headless --path godot --import
```
`CARS` (en `build_car.py`) tiene por auto: largo real `L`, `ground` (luz al piso), `gap` (luz entre la goma y el paso), reparto de peso `wf`
y el polígono de las ventanillas laterales `glass` (z, y). El parabrisas y la luneta se miden solos sobre el eje central del modelo.
`WHEELS` define el diseño de la llanta (`style`), el ancho de la goma delantera y trasera (`tw`, `tw_r`), el dibujo (`tread`) y el tipo de suspensión.

## Diseños de llanta
`multi5`, `star5`, `multi10`, `turbine`, `centerlock`, `dish6`, `dish8`, `steel10`, `beadlock` (ver `wheel_gen.gd`, `rim_mesh`).
Para agregar uno: una rama más en el `match` de `rim_mesh` y un nombre en `WHEELS`.

## Piezas editables en el taller (perfil → `paint`)
`body`, `accent`, `livery`, `finish` (brillante, metalizado, mate, cromado), `rim`, `tire`, `spring` (resortes), `caliper` (pinzas), `disc`
(acero, oscuro, dorado, carbono).

## Vidrios
Los vidrios no son otra malla: los pinta el sombreador de la carrocería con esquinas redondeadas (parabrisas y luneta: trapecio medido sobre
el modelo; ventanillas laterales: el polígono `glass`). Si un vidrio queda mal, se puede forzar con `glass_override` en `CARS`.

## Con la cámara interior
La carrocería se dibuja solo por fuera (se ve el capó y los guardabarros reales y no el techo), las ruedas y la suspensión se esconden y el
habitáculo procedural se mide con `cabin_cfg.gd`. Para mover los ojos, el ancho o el fondo del habitáculo de un auto: `OVR` en ese archivo.

## Pruebas
```
godot --headless --path godot --script res://tests/cars_test.gd     # aceleración, frenada y viraje de todos los autos
tests/_carview.gd, tests/_cabview.gd                                 # vistas previas (ver cabecera de cada archivo)
```
