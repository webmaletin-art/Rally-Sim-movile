# Paper Race — mundo de papel (papercraft)

Pista nueva «Paper Race (selva de papel)»: circuito cerrado de **1,9 km**, angosto (camino de 5,6 m), con **cinco tramos que alternan ruta y tierra**
(asfalto → tierra → asfalto → tierra → asfalto) y una selva muy tupida a los costados. Está en **Carrera rápida** (carrera con rivales o contrarreloj).

## Cómo se hizo
- `tools/paper/paperize.py <carpeta del pack>`: convierte los GLB del pack de vegetación (`biblioteca/vegetacion_y_suelo/`) a piezas de papel
  (`godot/game/models/paper/*.pap`, 54 piezas, ~8.000 triángulos en total): cada cara es un papel de un solo color. Los árboles con hojas sueltas
  se rehacen como copas facetadas (icosferas de papel), las plantas y flores como hojas grandes recortadas, las palmeras con tiras de papel, y
  las 11 especies «procedurales» del juego se hicieron a mano (conos de pino, esferas, tiras). Las piezas «sc_» del pack venían sin colores: se pintaron por parte.
- `game/fx/paper.gdshader`: sombreado plano, dobleces como borde claro, grano de papel y textura impresa (asfalto, tierra, pasto del pack).
- `game/fx/paper_kit.gd`: carga las piezas y arma los materiales. `game/track/paper_track.gd` (física: superficie por tramo) y
  `game/track/paper_world.gd` (camino con marcas, banquina, campo y selva con MultiMesh por tramos de 200 m; todo fijo, nada se mueve con el viento).
- Piezas de calle usadas como decoración: sendas peatonales sobre el asfalto, postes en la recta de largada, cordón de piedra en el pueblo, arenero y estacionamiento.

## Grilla de todo el pack
`godot/tests/paper_catalog.gd` saca las capturas de todas las piezas (árboles, plantas/flores/rocas, calle):
`xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1920x1080 --script res://tests/paper_catalog.gd -- /carpeta/salida`.
