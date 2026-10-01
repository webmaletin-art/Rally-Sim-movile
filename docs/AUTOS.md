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
