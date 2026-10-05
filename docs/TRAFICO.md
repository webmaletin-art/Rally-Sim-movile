# Tránsito de Dream City

## Etapa 6 — carriles, sentidos y grafo (`godot/game/world/traffic_graph.gd`)
- El grafo se **deriva** de las calles de `CityLayout` (que salen de la semilla del mundo): igual en todos los teléfonos y en el servidor, no se guarda ni se sincroniza. Se arma en ~0,1 s (259 cruces, 1102 carriles, 198 km de carril en la ciudad actual).
- **Mano derecha** (Argentina). Cada calle tiene un carril por sentido (dos por sentido las avenidas de 7 m de semiancho y la costanera). Los **callejones del casco viejo son de un solo sentido** (alternados). No entran túneles ni bahías.
- **Nodo** = cruce (los cruces a menos de 14 m se funden) o extremo de calle sin salida. **Carril** = tramo entre dos nodos, en un sentido: `{road, s0, s1, dir, k, off, len, a, b, next}`; `k=0` es el carril del lado del eje (gira a la izquierda), el último el de la derecha (gira a la derecha).
- **Conexiones**: seguir derecho al carril equivalente; giro a la derecha desde el carril derecho, a la izquierda desde el del eje; sin vueltas en U salvo en calles sin salida (ahí vuelve por el carril opuesto). Todo carril tiene al menos una salida.
- `lane_at(carril, d)` da posición, rumbo y altura a `d` metros del inicio del carril: función pura, pensada para tránsito cinemático determinista (Etapa 9).
- `lanes_in_cell(cuadra)` / `nearest_lane(p)`: consultas por cuadra de 160 m (igual que el gestor de sectores de World Life).
- Prueba: `tests/traffic_graph_test.gd` (determinismo, mano derecha, salidas, empalmes ≤ 30 m, recorrido de 4000 tramos al azar sin trabarse). Corre en CI.
