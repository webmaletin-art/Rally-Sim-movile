# Tránsito de Dream City

## Etapa 6 — carriles, sentidos y grafo (`godot/game/world/traffic_graph.gd`)
- El grafo se **deriva** de las calles de `CityLayout` (que salen de la semilla del mundo): igual en todos los teléfonos y en el servidor, no se guarda ni se sincroniza. Se arma en ~0,1 s (259 cruces, 1102 carriles, 198 km de carril en la ciudad actual).
- **Mano derecha** (Argentina). Cada calle tiene un carril por sentido (dos por sentido las avenidas de 7 m de semiancho y la costanera). Los **callejones del casco viejo son de un solo sentido** (alternados). No entran túneles ni bahías.
- **Nodo** = cruce (los cruces a menos de 14 m se funden) o extremo de calle sin salida. **Carril** = tramo entre dos nodos, en un sentido: `{road, s0, s1, dir, k, off, len, a, b, next}`; `k=0` es el carril del lado del eje (gira a la izquierda), el último el de la derecha (gira a la derecha).
- **Conexiones**: seguir derecho al carril equivalente; giro a la derecha desde el carril derecho, a la izquierda desde el del eje; sin vueltas en U salvo en calles sin salida (ahí vuelve por el carril opuesto). Todo carril tiene al menos una salida.
- `lane_at(carril, d)` da posición, rumbo y altura a `d` metros del inicio del carril: función pura, pensada para tránsito cinemático determinista (Etapa 9).
- `lanes_in_cell(cuadra)` / `nearest_lane(p)`: consultas por cuadra de 160 m (igual que el gestor de sectores de World Life).
- Prueba: `tests/traffic_graph_test.gd` (determinismo, mano derecha, salidas, empalmes ≤ 30 m, recorrido de 4000 tramos al azar sin trabarse). Corre en CI.

## Etapa 7 — semáforos funcionales (`world/traffic_signals.gd`, `fx/city_signal.gdshader`)
- El estado de cada semáforo es una **función pura de la hora del mundo** (`WorldClock.now()`): sin temporizadores ni estado que sincronizar; todos (y el servidor) ven el mismo color. Ciclo de 40 s: verde 16 s, amarillo 3 s, rojo el resto; las dos calles de un cruce alternan (con un segundo de «todo rojo» a cada lado). Cada cruce tiene su desfase (derivado de su posición y de la semilla).
- 35 cruces con semáforo y 77 postes en la ciudad actual (los cruces grandes, los mismos que ya tenían postes). Cada poste sabe qué calle regula (`CityLayout.prop_signal`).
- Visual: las tres lámparas de cada poste son una malla aparte por cuadra con un shader que calcula el color activo con la hora del mundo (un solo parámetro global, `CityWorld.set_signal_time`, que pone `CityClock` cada cuadro): costo cero por semáforo. Un poste caído queda con las lámparas apagadas.
- Para el tránsito (Etapa 9): `lane_state(carril, t)` → ROJO/AMARILLO/VERDE del cruce al final del carril y `time_to_change(carril, t)` para decidir si frenar o pasar.
- Prueba: `tests/traffic_graph_test.gd` (nunca verde en ambas calles, orden verde→amarillo→rojo, periodicidad).

## Etapa 8 — autos estacionados deterministas (`world/parked_cars.gd`)
- Sistema de World Life (se registra en `race.gd`). Lugares de 7 m en el cordón de las calles chicas y los anillos (no en avenidas, callejones, costanera ni rutas), a 15 m de los cruces y lejos de las gasolineras. Un lugar está ocupado con 36 % de probabilidad según `WORLD_SEED + calle + lugar + época` (la época cambia cada 2 días del mundo): mismos autos en los mismos lugares para todos, sin guardar nada.
- Sólo en los sectores **activos** (150 m), con el tope del perfil: 24 / 48 / 80 (LOW / MEDIUM / HIGH). Un `MultiMesh` por sector (una llamada de dibujo) con color por instancia (neutros y de color) y tres tamaños (sedán, hatch, furgón). Dos círculos de choque por auto, sólidos (no se rompen). Al alejarse todo se libera y al volver reaparece idéntico; con World Life en OFF no queda nada.
- Para dejarles lugar, el carril de las calles de un carril por sentido pasó a 0,40·semiancho del eje.
- Prueba: `tests/parked_cars_test.gd` (huella igual en dos «teléfonos», otra semilla → otros autos, tope por perfil, choques que se agregan/sacan, liberación al apagar).

## Etapa 9 — tránsito civil cinemático (`world/civil_traffic.gd`)
- Sistema de World Life. **Sin física**: cada auto va por los carriles del grafo con un modelo de velocidad (crucero según el tipo de calle × carácter del conductor, frena ante el semáforo en rojo y ante el auto de adelante; el tope de velocidad garantiza que siempre pueda frenar antes de la línea). En los cruces recorre un empalme suave (curva Hermite entre el final de un carril y el inicio del siguiente); la ruta se elige con un hash de `semilla + auto + tramo`.
- **Reconstrucción determinista**: al acercarse un sector (activo o simplificado, hasta 300 m) se llena con autos que salen de `WORLD_SEED + sector + número + bloque de 60 s`: se parte del estado del comienzo del bloque y se avanza a pasos fijos de 0,5 s hasta ahora. Misma semilla y hora = mismos autos en los mismos lugares. Después cada auto sigue de forma continua (nunca salta); los sectores con pocos autos reciben uno de repuesto, siempre a más de 95 m del jugador.
- **Topes por perfil** (`world_life.json`): LOW 12 · MEDIUM 24 · HIGH 36. Los autos del sector simplificado (150–300 m) se calculan a 4 Hz; los activos, a 20 Hz. Un solo `MultiMesh` (una llamada de dibujo). Más allá de 360 m se descartan.
- Choque: cada auto son dos círculos sólidos que se pasan a `CityTrack.set_dynamic_circles` (la reacción al golpe, con física temporal, es la Etapa 11). Con World Life OFF no queda ninguno.
- Prueba: `tests/civil_traffic_test.gd` (huella igual en dos «teléfonos», otra semilla/otra hora → otro tránsito, topes, 150 s simulados sin entrar al cruce con rojo, sin superposiciones relevantes, liberación al apagar).

## Etapa 10 — rutinas del tránsito (`world/traffic_routine.gd`)
Funciones puras de la hora del mundo y del día (los días 5 y 6 de cada 7 son fin de semana):
- **Densidad** de autos en marcha: madrugada ≈ 0,3×, hora pico de la mañana (≈ 8:20) y de la tarde (≈ 18:30) ≈ 1,5×, mediodía ≈ 0,8×; el fin de semana el pico es más suave y hay más movimiento a la tarde-noche. Mueve la cantidad de autos por sector y el tope efectivo (nunca más que el del perfil); los que sobran se retiran de a uno, lejos de la vista.
- **Sentido**: a la mañana las rutas se inclinan hacia el centro, a la tarde hacia afuera (peso en cada elección de carril; sigue siendo determinista).
- **Velocidad**: −18 % en hora pico, +12 % de madrugada.
- **Estacionados**: más autos en el cordón de noche (casas) que de día (trabajo).
- Prueba: `tests/traffic_routine_test.gd`. Además se mejoró la convivencia: los autos que entran a un cruce ven al que va primero hacia el mismo carril y los nuevos no nacen a menos de 9 m de otro (0 superposiciones en 150 s).
