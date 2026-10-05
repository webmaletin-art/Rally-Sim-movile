# Travesía X — convoy off-road

Modo nuevo debajo de **Aventura** en el menú principal. El mismo mapa está en **Carrera rápida** (con tu auto, clima a elegir). Es una sola vuelta de ~20 km (unos 30–40 minutos) con un convoy de 5 autos y camiones que va en fila: hay que llegar a la meta **con el grupo**.

## La ruta (`tools/travesia/gen_route.py` → `routes.json`, ruta y mapa `travesia`)
Circuito cerrado, camino de 6 m (dos autos muy justos), 12 tramos con cartel al entrar:

| Tramo | Qué es |
|---|---|
| Largada · Bosque rápido | tierra, curvas rápidas, algunos badenes tipo «lavadero» |
| Barrial | barro (agarre 0,35 de la física + color oscuro) |
| Pedregal | tierra con corrugado (`dips` de 18 m y 30 cm) y piedras al costado (MultiMesh) |
| Valle abierto | rápido, con «whoops» (60 m, 50 cm) |
| El vado del lago | hondonada de 1,6 m, 400 m bajo el agua (0,8 m) y el terreno de los costados baja: se cruza un lago de verdad. El agua frena (`water_drag` en `race.gd`) |
| Orilla | barro más suelto |
| Ascenso en zigzag | subida de ~110 m en horquillas de ~16 m de radio |
| La cresta · Bajada suelta | rápido arriba, pendiente de hasta 14 % abajo, tierra suelta |
| Barro final · Recta final | barro de nuevo y llegada |

El generador no se ejecuta en el juego (el resultado va en `routes.json`). `python3 tools/travesia/gen_route.py --check` imprime largo, radio mínimo, cercanía entre tramos y caja. La altura está calculada por la fracción **recorrida** (no por la curva base) para que lagos, barro y subidas coincidan con los tramos; hace 5 pasadas para eso.

`RouteTrack` ahora entiende en `routes.json`: `surf` (zonas `{from,to,s,mu}` → `road_surf` y agarre de la IA `surf_mu`), `water` (lagos: `{from,to,above,half}`) y `sections` (tramos con nombre). El barro se pinta con color de vértice en el camino.

## El convoy (`ai/convoy.gd`)
* Cada auto de la fila **sigue al de adelante** (el jugador cuenta como uno más): copia su velocidad y corrige con la distancia (26 m de separación).
* El primero va al tope del tramo (rápido en bosque/valle/cresta, lento en barro, pedregal y vado) si el grupo está junto. Si el último de la fila se queda, **baja el ritmo** (hasta 18 km/h) y espera. Si el jugador acelera, el tope no lo frena: los de atrás lo persiguen.
* **Se pierde el convoy** si el jugador queda a más de 280 m del primero del convoy (atrás, o adelante de todos) por más de 9 s. Aviso en pantalla desde los 140 m: «¡ALCANZALOS!» / «¡ESPERÁ AL CONVOY!» con cuenta regresiva.
* Llegar a la meta sin haberlos perdido = victoria; la **unión** (tiempo a menos de 100 m del grupo) define medalla y premio. Perderlos corta la carrera con «¡LOS PERDISTE!».
* Premios: 600–1200 de crédito y 250–450 XP si llegás (más cuanto más unido), 40 XP si los perdés. La práctica con auto de prueba no paga.
* Los 5 del convoy: pickup, camión, SUV, Cóndor T6 Multicam y buggy, de serie con gomas todo terreno (`CONVOY_CARS` en `race.gd`).

## Probarlo
* `tools/godot/run_shot.sh /tmp/x.png --convoy=0.44 --cam=chase --auto` arranca la Travesía en esa fracción del recorrido (el vado).
* `godot --headless --path godot --script res://tests/travesia_test.gd` (vuelta entera, ~7 min; `-- --km=9` para lo que corre la CI): comprueba largo, tramos, pendiente máxima y que un jugador a ritmo normal llega con el grupo y uno muy lento los pierde.

## Pendiente / ideas
* Salpicaduras de agua y barro (hoy sólo frena y se ve el agua).
* Más piedras grandes con colisión en el pedregal; troncos caídos.
* Versión inversa del recorrido y modo nocturno.
