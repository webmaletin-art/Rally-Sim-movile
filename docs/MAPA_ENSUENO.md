# Vórtice de Ensueño — mapa fantasía

> Es un **mapa suelto** de la sección «Mapas fantasía» (inicio → FANTASÍA; `docs/MAPAS_FANTASIA.md`, junto con Marte, la Luna y el anillo de Júpiter): no está en ninguna copa ni en la aventura, y no suma estrellas. Se corre contra rivales a la par.

Circuito de **9,7 km** (una vuelta inmensa) hecho todo en papel (papercraft) alrededor de un **agujero negro** que se ve muy abajo, en un mar de gas con
las bandas de color de Júpiter. Se corre desde **Mapas fantasía** (carrera con rivales o contrarreloj, 1 a 5 vueltas).

## La ruta (`tools/dream/route.py` → `data/routes.json`, ruta «ensueno»)
- Sale de un valle plano, **sube 300 m** en una subida larguísima (hasta el 13,9 %), cruza una **cresta con una curva peraltada** de ~160 m de radio,
  baja por una **bajada brutal** (hasta −13,5 %) y vuelve por una vuelta inmensa de curvas larguísimas (radios de 400 m a 1,5 km). Camino ancho (14 m).
- **Peralte** (`track/dream_track.gd`): en las curvas el camino se inclina hacia adentro hasta 6°. La física lo siente porque cada rueda lee su altura.
- **Suelo plano** a los costados (meseta de flores a la altura del borde, sin zanja) y **límite lateral** a 7,5 m del borde de la banquina: podés salir al
  campo y pisar las flores, pero una pared invisible te devuelve a la pista (los arbustos altos y los bambúes la tapan a la vista).

## El mundo (`track/dream_world.gd`)
- Camino con el asfalto del pack, cordones rosa y blanco, rayas y línea de largada en cuadros. Nueve **arcos de globos** a lo largo de la vuelta.
- **Seis zonas de color** (aurora rosa, jardín violeta, oro del cielo, selva turquesa, coral y fuego, arcoíris) que se mezclan: cada una cambia el piso
  (bandas de color paralelas al camino) y las piezas que se plantan. ~100.000 piezas por vuelta en MultiMesh por tramos, con distancia de visibilidad por tipo
  (flores 160 m, arbustos y bambúes 280 m, árboles 560 m). La calidad baja/media/alta cambia la cantidad (×0,5 / ×0,75 / ×1).
- **Flora de ensueño** (`tools/paper/dreamflora.py`, 61 piezas `d_*.pap`): sakura (3), jacarandá, arce dorado, árbol coral y turquesa, árboles de burbujas,
  rosas, tulipanes, lotos, hibiscos, lirios, orquídeas, girasoles, tropicales, margaritas, flores simples, arbustos floridos, bambúes de colores, algas,
  helechos, nenúfares, hongos gigantes y pastos con penachos. El zip `papercraft_batch_110modelos` traía solo imágenes (no los GLB), así que cada familia se
  rehízo en papel con la forma y la paleta de los renders.
- **Cielo** (`fx/dream_sky.gdshader`): degradé durazno → lila → índigo, estrellas, un **Júpiter gigante** con bandas, tormenta y terminador, y el sol.
- **Mar de gas y agujero negro** (`fx/dream_clouds.gdshader`): plano enorme 130 m bajo el valle con espirales de color que giran hacia un agujero negro con
  su anillo brillante (se ve desde la subida y desde los bordes de la meseta; los costados de la meseta caen en capas de colores).
- **Reflejos de sol**: destellos en las caras de papel que reflejan el sol hacia la cámara (`fx/paper.gdshader`, uniform `glint`), y halo, destello alargado y
  fantasmas del lente cuando mirás hacia el sol (`fx/dream_flare.gd`). Pétalos y motitas de luz flotando alrededor de la cámara.

## El rival a la par
`race.gd::_pace_rivals` ajusta en cada cuadro el ritmo del rival según la distancia que lo separa del jugador (`AIDriver.pace_target` y `power_target`): si se
escapa afloja, si se queda aprieta (hasta +90 % de potencia) y apunta a ir apenas adelante, con una ondita lenta para que la pelea se sienta viva.
En la prueba (`tests/dream_test.gd`) la distancia media entre un jugador y un rival bastante distinto queda en 27–40 m, con un máximo de 51–72 m.

## Pruebas y capturas
- `tests/dream_test.gd`: largo, desnivel, pendientes, peralte, continuidad del suelo, límite lateral, flora y rival a la par.
- Capturas de toda la vuelta: `xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 --script res://tests/dream_shots.gd -- /carpeta`.
- Una carrera real con captura: `tools/godot/run_shot.sh /tmp/x.png --track=dream --cars=2 --auto --cam=chase --viewat=0.385`.

## Nota importante sobre el contenido descargable
Las piezas `.pap` no son recursos de Godot: el export no las incluía (la selva de Paper Race salía sin plantas en el APK). Ahora `export_presets.cfg` las
agrega con `include_filter="*.pap, *.txt"`.
