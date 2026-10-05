# Arquitectura del código (Etapa 23: modularización)

Mapa de dónde vive cada cosa, para no tener que leer 2700 líneas de `race.gd`.

## Capas
| Carpeta | Qué hay |
|---|---|
| `game/physics/` | física del auto (120 Hz) y pistas base |
| `game/car/` | dibujo del auto (`car_visual`), piezas modulares (`part_catalog`, `vehicle_customization`, `wheel_gen`), desgaste de gomas (`tire_wear`), animaciones Mixamo del menú |
| `game/world/` | **World Life** (vida del mundo): reloj, semilla, sectores y los sistemas: grafo de tránsito, semáforos, estacionados, tránsito civil, rutinas, peatones, superficies, clima, actividades y fama. Todo determinista (semilla + hora) |
| `game/city/` | Dream City: generador (`city_layout`), mundo en papel (`city_world`, `city_props`), HUD, reloj/clima visual, y los **módulos de servicio** (abajo) |
| `game/audio/` | sonido del auto, sonidos de interfaz y `world_ambient` (ambiente del mundo) |
| `game/online/` | conexión Supabase, social (chat, presencia, mercado), economía online (`online_economy`), autos de otros jugadores |
| `game/data/` | perfil offline (`profile`), perfil online espejo (`online_profile`), catálogo, tiendas, reglas |
| `game/ui/` | menús (`menu` + una clase por sección: garage, aventura, cuenta, tienda, **mundo/online**), HUD, opciones |
| `supabase/migrations/` | SQL aditivo (todo lo online que importa se valida en el servidor) |

## Lo que se separó en la Etapa 23
* `city/city_life.gd` — conecta la **vida del mundo** con Dream City: crea el núcleo, registra los sistemas (estacionados, tránsito, peatones), el audio ambiente, y cada cuadro le pasa lo del jugador. Antes estaba suelto dentro de `race.gd`.
* `city/city_services.gd` — agrupa los **servicios de la ciudad** que viven dentro de la carrera: locales, bocas de túnel, nafta, gomas, actividades, peajes y la Plaza de Drift (se crean y actualizan con una sola línea).
* `ui/menu_world.gd` — las pantallas de **entrada al mundo y al modo online** del menú (dónde aparecer, hub online con créditos y regalo diario, apodo, cuenta/rankings, «pronto»).
* `data/online_profile.gd` + `online/online_economy.gd` — el modo online con **el mismo interfaz** que el offline (los menús no saben si están online o no).
* `race.gd` quedó con lo que es de la carrera en sí (parrilla, cámaras, sesión, HUD, rendimiento). `race.life`, `race.services`, `race.fuel`, `race.tires`… siguen siendo accesibles igual que antes.

## Reglas para seguir ordenado
1. Un sistema nuevo de vida del mundo = un archivo en `game/world/` que hereda de `world_life_system.gd` y se registra en `city_life.gd` (una línea). Su tope de CPU y de cantidad se lee de `wl.scaled_cap()`.
2. Un servicio nuevo de la ciudad = un archivo en `game/city/` y una línea en `city_services.gd`.
3. Una pantalla nueva del menú = una clase `ui/menu_<sección>.gd` con `var m` (el menú) como `menu_account`, `menu_world`, `menu_garage`.
4. Nada del online confía en el teléfono: toda compra/venta pasa por una función SQL validada (ver `ECONOMIA_ONLINE.md`).
5. Cada sistema nuevo trae su prueba corta en `godot/tests/` y la agrega a `build-godot.yml`.

## Pendiente de modularizar (no urgente)
* `race.gd` (~2650 líneas): el modo de pruebas de rendimiento y los resultados (`bench`, `perf`) podrían ir a su propio módulo; la construcción de la parrilla también.
* `city/city_layout.gd` (~1800 líneas) y `city/city_world.gd` (~1500): separar el plan de calles de las construcciones y de los props.
* `ui/menu.gd` (~750 líneas): la pantalla de inicio y la de eventos/campeonatos.
