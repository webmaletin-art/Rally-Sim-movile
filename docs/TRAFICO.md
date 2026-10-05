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
