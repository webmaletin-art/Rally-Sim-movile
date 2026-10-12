# Red de rutas (modo RUTAS)

Mapa de caminos largos (`red_1`, 1664 km, formato `dreamracing-network` v1 del «Editor de RED», `tools/route_gen/PROMPT_EDITOR_RED.md`) para **circular libre** o jugar a la **persecución**.
Se entra desde el menú → **RUTAS**: modo (Solo andar / Me persiguen / Yo persigo), ventaja para ganar (50–600 m, por defecto 150), nivel del rival y estación de salida.

## Piezas
| Archivo | Qué hace |
|---|---|
| `tools/route_gen/import_network.py` | `red_N.json` del editor → `godot/game/data/networks/red_N.json` (calles suavizadas y remuestreadas cada 12 m, en decímetros enteros; rotondas con su anillo; estaciones). |
| `godot/game/net/net_data.gd` | Datos y consultas puras: `probe(x,z)` (calle más cercana por grilla de 128 m), `route(a,b)` (Dijkstra sobre ~65 nodos → polilínea), estaciones (playón a 24 m del borde del camino, rumbo del camino). |
| `godot/game/net/net_track.gd` | Pista para la física (`ground_info`): calzada según la calle (asfalto / tierra / barro), banquina 2,2 m, pasto 30 m y «afuera». Sin paredes: se puede salir al campo. `start_pose`, `station_pose`. |
| `godot/game/net/net_world.gd` | Mundo 3D por tramos de 256 m: los hilos arman los arreglos y el hilo principal crea las mallas; se arman `radius × view_k` cuadrados alrededor de la cámara y se sueltan los lejanos. Árboles (MultiMesh), estaciones y rotondas con isleta. |
| `godot/game/net/net_driver.gd` | Piloto de IA: pure pursuit sobre `route()` con modelo de bicicleta (igual que la IA de carrera), velocidad por curvatura con frenada anticipada y tope por tipo de calle. Modos `wander` (huye hacia un destino lejano) y `pursue` (persigue al jugador). |
| `godot/game/net/net_session.gd` | Reglas: la ventaja es la distancia en línea recta; quien va adelante es quien tiene al otro a la espalda (cambia de rol si se mantiene 1,5 s a más de 12 m). Quien abre `limit` metros gana. |
| `godot/game/ui/net_hud.gd` | Minimapa que gira (radio 420 m) con calles, estaciones y rival (flecha en el borde si está lejos), estación más cercana y botón «↺ ESTACIÓN». |
| `godot/game/ui/menu_net.gd` | Pantalla del menú. Las opciones quedan en `profile.d["netOpts"]`. |

## Cómo se prueba
- `godot --headless --script res://tests/net_test.gd` (datos, consultas, estaciones, rutas) y `tests/net_chase_test.gd` (IA recorre la red sin salirse ni trabarse con 3 autos; persecución termina con ganador).
- Captura: `tools/godot/run_shot.sh out.png --net[=flee|chase|free[:estación]] [--auto] [--cam=chase]` (`--auto` = el jugador maneja solo con `NetDriver`).

## Límites actuales
- El mundo es plano (sin relieve) y sin tránsito civil ni peatones; sólo árboles al costado.
- Las estaciones sólo son punto de salida y de regreso (todavía no cargan nafta ni tienen servicios).
- La persecución usa una IA simple: no cierra atajos por el campo, sigue las calles.
- Textos del HUD de la persecución sólo en español.
- No hay ranking online ni premios por distancia; la persecución paga como una carrera corta de Carrera rápida (`cfg["rule"] = "chase"`).
- Se esperan ajustes del dueño: largo de vista (`view_k`), velocidad del rival, densidad de árboles.
