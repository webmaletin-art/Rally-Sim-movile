# Animaciones de Mixamo en el menú (Etapa 5)

**Qué hace:** los dos pilotos de la sala del menú (garaje, tienda, taller…) ahora usan clips de Mixamo cuando están parados haciendo algo (charlar, señalar, pensar, mirar el teléfono, tocar la pintura, esperar…). Al caminar alrededor del auto siguen con la marcha procedural de siempre; el paso de una cosa a la otra se mezcla (0,45 s).

**Cómo funciona**
- `tools/mixamo/bake.gd` convierte los FBX del ZIP (importados por Godot) en **un solo archivo**: `godot/game/anim/menu_clips.txt` (~3 MB, 71 clips, rotaciones por hueso a 15 cuadros/s en int16 + cadera). Los FBX NO van al repositorio (licencia de Mixamo: no se redistribuyen sueltos); el archivo horneado es el contenido del juego.
- `game/car/mixamo_clips.gd`: lee el archivo a demanda (sólo decodifica los clips que se usan) y `Player` los aplica al esqueleto del piloto (mismos huesos `mixamorig`), con mezcla suave entre clips.
- `game/ui/showroom.gd`: la tabla `CLIPS` dice qué clips usa cada pose del guion (`idle`, `chin`, `crossed`, `hip`, `pocket`, `point`, `paint`, `talk`, `read`). Cuando un clip termina antes que el paso del guion, se elige otro distinto del mismo grupo. Si el archivo no está, queda todo como antes.
- El archivo es `.txt` a propósito: los presets de exportación ya incluyen `*.txt` (como los `.pap`), así que viaja en el paquete de contenido sin tocar la configuración.

**Para agregar/cambiar clips:** importar el FBX en un proyecto Godot vacío con los demás, correr `godot --headless -s bake.gd` y copiar el `menu_clips.txt` resultante a `godot/game/anim/`. Después sumarlo a `CLIPS` en `showroom.gd`.

**Clips todavía sin usar (ya horneados):** saludos/festejo (`Waving`, `Standing_Fist_Pump`, `Clapping`…), apoyado en el auto, subir/bajar del auto (`Entering_Car`/`Exiting_Car`, pensados para «Jugar»), hablar por teléfono. Quedan para las etapas de mundo abierto y peatones.

**Pendiente de ver en el teléfono:** el celular del copiloto (se pega a la mano derecha con el clip de texteo): la orientación/posición exacta se ajusta mirando el APK.
