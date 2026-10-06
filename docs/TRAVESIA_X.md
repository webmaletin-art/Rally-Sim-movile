# Travesía X — convoy off-road

Modo nuevo debajo de **Aventura** en el menú principal. El mismo mapa está en **Carrera rápida** (con tu auto, clima a elegir). Es una sola vuelta de 44 km (más de una hora si se maneja con cuidado) con un convoy de 5 autos y camiones que va en fila: hay que llegar a la meta **con el grupo**.

## La ruta (`tools/travesia/gen_route.py` → `routes.json`, ruta y mapa `travesia`)
Circuito cerrado de **44 km** (para pasar de 20 a 44 el generador ahora arma la ruta por tramos con largo real en km), camino de 6 m (dos autos muy justos), **27 tramos** con cartel al entrar, alturas de 33 a 355 m y pendientes de hasta **21 %** (el muro). Pensada para ir con precaución: freno, acelerador y suspensión.

| Tramo | Qué es |
|---|---|
| Largada · Bosque rápido | tierra buena, curvas rápidas: **acá el convoy va a ~100 km/h** |
| Barrial · Pedregal | barro (agarre 0,35) y tierra con corrugado y piedras al costado |
| Valle abierto | rápido, con ondulaciones |
| El vado del lago + Orilla | hondonada de 1,6 m con 0,8 m de agua; la orilla baja de a poco (ya no hay un escalón al borde) |
| Ascenso en zigzag → La cresta | subida de ~150 m en horquillas y cresta rápida con ondulaciones |
| **Bajada a la cueva · La cueva** | bajada de ~10 % y un **túnel de roca** de ~900 m (sólo visual) que sigue bajando y doblando |
| El arroyo seco | cauce con piedras y bachecitos de 14 m |
| **Los escalones** | peldaños de roca de 45 cm cada 42 m: suben y bajan (hay que levantarlos con la suspensión) |
| Bosque cerrado · Llanura rápida | curvas muy cerradas entre árboles y una recta ancha a fondo |
| Los médanos | rompe-ejes: ondulaciones de 1 m cada 46 m |
| **El muro · La cornisa · El pico · El techo** | subida corta de 20 %, cornisa, zigzag hasta los 350 m y el techo |
| **La gran bajada · La barranca** | 200 m de bajada suelta y una barranca erosionada |
| El lago grande · Barro profundo · Pedregal de la sierra | segundo vado, barro y piedras |
| Pista de tierra · Recta final | tierra rápida y llegada |

El generador no se ejecuta en el juego (el resultado va en `routes.json`). `python3 tools/travesia/gen_route.py --check --plot` imprime largo, radio mínimo, cercanía y pendiente por tramo y dibuja el recorrido (`/tmp/claude-0/travesia_plot.png`). La altura está calculada por la fracción **recorrida** para que lagos, barro y subidas coincidan con los tramos.

`RouteTrack` entiende en `routes.json`: `surf` (zonas de superficie y agarre de la IA), `water` (lagos), `sections` (tramos con `label` y `cap`: el tope de velocidad del convoy), `dips` (ondulaciones), `ledges` (escalones) y `caves` (túnel visual). Para una ruta de 44 km la grilla de terreno de fondo es gruesa (~48 m): cerca del camino hay una **franja con la altura exacta** hasta 90 m (`build_far_strip`).

**Paisaje:** bosque de imágenes (los mismos árboles de 8 vistas / cruz del mundo abierto, `docs/OPTIMIZACION_MUNDO_ABIERTO.md`) según el tramo (denso en el bosque, ralo en el valle y la cresta; pinos arriba, hojas anchas en valles y arroyos) y dos anillos de bosque lejano en el horizonte (`travesia_props.gd`).

## El convoy (`ai/convoy.gd`)
* Cada auto de la fila **sigue al de adelante** (el jugador cuenta como uno más): copia su velocidad y corrige con la distancia (34 m de separación).
* **Corre como los rivales de la aventura**: el primero va a todo lo que da el tramo (`cap` en routes.json: ~115–120 km/h en camino bueno, 35–55 km/h en barro, escalones y vado: frena un poco en lo peligroso y sale acelerando a fondo). Sólo **espera un poquito al jugador** si se le queda atrás: desde 110 m empieza a aflojar y a 280 m va al 60 % del tope del tramo (nunca menos de 32 km/h). Los de la fila no lo frenan: lo persiguen solos. Si el jugador acelera, el tope no lo frena.
* **Se pierde el convoy** si el jugador queda a más de 330 m del primero del convoy (atrás, o adelante de todos) por más de 10 s. Aviso en pantalla desde los 170 m: «¡ALCANZALOS!» / «¡ESPERÁ AL CONVOY!» con cuenta regresiva.
* Llegar a la meta sin haberlos perdido = victoria; la **unión** (tiempo a menos de 100 m del grupo) define medalla y premio. Perderlos corta la carrera con «¡LOS PERDISTE!».
* Premios: 600–1200 de crédito y 250–450 XP si llegás (más cuanto más unido), 40 XP si los perdés. La práctica con auto de prueba no paga.
* Los 5 del convoy: pickup, camión, SUV, Cóndor T6 Multicam y buggy, de serie con gomas todo terreno (`CONVOY_CARS` en `race.gd`).

## Probarlo
* `tools/godot/run_shot.sh /tmp/x.png --convoy=0.44 --cam=chase --auto` arranca la Travesía en esa fracción del recorrido (el vado).
* `godot --headless --path godot --script res://tests/travesia_test.gd` (vuelta entera, más de 20 min; `-- --km=12` para lo que corre la CI): comprueba largo, tramos, pendiente máxima y que un jugador a ritmo normal llega con el grupo y uno muy lento los pierde.

## Pendiente / ideas
* Salpicaduras de agua y barro (hoy sólo frena y se ve el agua).
* Más piedras grandes con colisión en el pedregal; troncos caídos.
* Versión inversa del recorrido y modo nocturno.
