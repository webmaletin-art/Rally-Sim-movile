# Animaciones de Mixamo en el menú (Etapa 5)

**Qué hace:** los dos pilotos de la sala del menú (garaje, tienda, taller…) ahora usan clips de Mixamo cuando están parados haciendo algo (charlar, señalar, pensar, mirar el teléfono, tocar la pintura, esperar…). Al caminar alrededor del auto también usan clips: en cada tramo se elige **al azar** una caminata en el lugar (`WALKS` en `showroom.gd`: normal, lenta, con el celular…) y se camina a su velocidad natural para que los pies no patinen; a veces (40 %, tramos largos) arrancan con `Start_Walking` (el avance de la cadera mueve al personaje). En 1 de cada 5 escenas uno hace **`Walk_In_Circle`**: una vuelta entera al auto mirándolo (17 s, el óvalo de la cadera se agranda `CIRC_XZ` para rodear el auto) mientras el otro lo mira. Si faltan los clips queda la marcha procedural de siempre; el paso de una cosa a la otra se mezcla (0,45 s). `tests/showroom_walk_test.gd` corre el showroom y cuenta clips/choques con el auto.

**Cómo funciona**
- `tools/mixamo/bake.gd` convierte los FBX del ZIP (importados por Godot) en **un solo archivo**: `godot/game/anim/menu_clips.txt` (~3 MB, 83 clips, rotaciones por hueso a 15 cuadros/s en int16 + cadera). Los FBX NO van al repositorio (licencia de Mixamo: no se redistribuyen sueltos); el archivo horneado es el contenido del juego.
- `game/car/mixamo_clips.gd`: lee el archivo a demanda (sólo decodifica los clips que se usan) y `Player` los aplica al esqueleto del piloto (mismos huesos `mixamorig`), con mezcla suave entre clips.
- `game/ui/showroom.gd`: la tabla `CLIPS` dice qué clips usa cada pose del guion (`idle`, `chin`, `crossed`, `hip`, `pocket`, `point`, `paint`, `talk`, `read`). Cuando un clip termina antes que el paso del guion, se elige otro distinto del mismo grupo. Si el archivo no está, queda todo como antes.
- El archivo es `.txt` a propósito: los presets de exportación ya incluyen `*.txt` (como los `.pap`), así que viaja en el paquete de contenido sin tocar la configuración.

**Para agregar/cambiar clips:** importar el FBX en un proyecto Godot vacío con los demás, correr `godot --headless -s bake.gd` y copiar el `menu_clips.txt` resultante a `godot/game/anim/`. Después sumarlo a `CLIPS` en `showroom.gd`.

**Clips todavía sin usar (ya horneados):** saludos/festejo (`Waving`, `Standing_Fist_Pump`, `Clapping`…), apoyado en el auto, subir/bajar del auto (`Entering_Car`/`Exiting_Car`, pensados para «Jugar»), hablar por teléfono. Quedan para las etapas de mundo abierto y peatones.

**Pendiente de ver en el teléfono:** el celular del copiloto (se pega a la mano derecha con el clip de texteo): la orientación/posición exacta se ajusta mirando el APK.
