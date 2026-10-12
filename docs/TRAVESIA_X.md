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
* **Todos van a fondo.** Cada auto del convoy corre como un rival de la aventura: a lo fuerte que le deja el tramo donde está (`cap` de routes.json × un ritmo por lugar de la fila, 100 % el primero y 95 % el último). Ya no copian la velocidad del de adelante (antes sólo el primero iba rápido y el resto lo seguía): sólo se acomodan para que la fila no se amontone (30 m) ni se choquen (15 m). Si uno se queda atrás de su lugar aprieta hasta un 8 % por encima del tope.
* **Más rápido y más difícil:** los topes de los tramos duros (barro, pedregal, vado, zigzag, escalones, cornisa, pico…) subieron un 40 % (barro ~60 km/h, pedregal ~56, escalones ~49); donde el camino es bueno siguen en ~100–125 km/h. Las pruebas comprueban que ningún auto del convoy anda a menos del 80 % del más rápido.
* El primero **espera un poco al jugador** si se le queda atrás: desde 120 m afloja y a 300 m va al 70 % del tope del tramo (nunca menos de 32 km/h). Los demás no esperan a nadie.
* **Se pierde el convoy** si el jugador queda a más de 330 m del primero del convoy (atrás, o adelante de todos) por más de 10 s. Aviso en pantalla desde los 170 m: «¡ALCANZALOS!» / «¡ESPERÁ AL CONVOY!» con cuenta regresiva.
* Llegar a la meta sin haberlos perdido = victoria; la **unión** (tiempo a menos de 100 m del grupo) define medalla y premio. Perderlos corta la carrera con «¡LOS PERDISTE!».
* Premios: 600–1200 de crédito y 250–450 XP si llegás (más cuanto más unido), 40 XP si los perdés. La práctica con auto de prueba no paga.
* Los 5 del convoy: pickup, camión, SUV, Cóndor T6 Multicam y buggy, de serie con gomas todo terreno (`CONVOY_CARS` en `race.gd`).
* Para ajustar la dificultad: `PACE`, `CATCHUP_K`, `WAIT_*` y `LOSE_*` en `convoy.gd`, y la columna `cap` de `SECTIONS` en `tools/travesia/gen_route.py` (después hay que copiarla a `routes.json`).

## Probarlo
* `tools/godot/run_shot.sh /tmp/x.png --convoy=0.44 --cam=chase --auto` arranca la Travesía en esa fracción del recorrido (el vado).
* `godot --headless --path godot --script res://tests/travesia_test.gd` (vuelta entera, más de 20 min; la CI corre `-- --km=10.5` y `-- --from=18.5 --km=4`, los escalones): comprueba largo, tramos, pendiente máxima, que un jugador a buen ritmo (tope 100 km/h) llega con el grupo, que uno tranquilo (65 km/h) y uno muy lento los pierden, y que todos los autos del convoy van rápido. `--from=km` arranca el convoy en ese punto de la ruta.

## Pendiente / ideas
* Salpicaduras de agua y barro (hoy sólo frena y se ve el agua).
* Más piedras grandes con colisión en el pedregal; troncos caídos.
* Versión inversa del recorrido y modo nocturno.
