# World Life · la vida del mundo

**Idea:** el mapa es el cuerpo del mundo; World Life es su vida. Es una capa lógica aparte (no duplica el mapa) que va a manejar, de a poco, tráfico, autos estacionados, semáforos, peatones, eventos y ambiente. Un solo núcleo para offline y online (`godot/game/world/`).

## Piezas (etapa 1: núcleo)
| Archivo | Qué hace |
|---|---|
| `world_life.gd` | El núcleo: reúne todo, ON/OFF, reconstrucción, sincronización online, registro de sistemas |
| `world_state.gd` | `world_id`, `world_version` (versión de las REGLAS), `world_seed`, modo, perfil, huella (`fingerprint`) y semilla por sistema |
| `world_clock.gd` | `WORLD_TIME`: tiempo lógico en segundos. Se calcula con el reloj local a partir de una referencia (no lee la red). Corrige la deriva de a poco (≤ 8 %) sin saltos; sólo corta en seco si la diferencia pasa de 45 s |
| `world_seed.gd` | «Azar» determinista de 32 bits (mismas claves → mismo resultado en cualquier teléfono) |
| `world_sector_manager.gd` | Sectores de 160 m (la misma cuadrícula que el streaming de la ciudad) y niveles ACTIVO · SIMPLIFICADO · LÓGICO · NINGUNO (150/300/600 m × el perfil) |
| `world_life_config.gd` + `data/world_life.json` | REGLAS (distancias, perfiles LOW/MEDIUM/HIGH con presupuestos, sincronización). Se carga una vez. Nunca guarda entidades |
| `world_life_system.gd` | Molde de los sistemas de vida: `enable/disable/rebuild/on_sector_changed/update(dt)/logical_hash` |

## Reglas de oro
- **El estado se calcula, no se guarda:** reglas + `WORLD_ID` + `WORLD_VERSION` + `WORLD_SEED` + `WORLD_TIME` → mismo estado lógico en todos los teléfonos. Versión y tiempo son independientes.
- **El costo depende de la zona alrededor del jugador**, no del tamaño del mapa (sólo se siguen ~60 sectores).
- **OFF de verdad:** `WorldLife.set_enabled(false)` apaga los sistemas, les hace liberar lo que instanciaron, vacía los sectores y deja de actualizar. El mapa, el auto, el GPS y el online no se enteran. El reloj es un cálculo derivado, no un proceso. Opción en **Opciones → Gráficos → «Vida del mundo»**; con «Mostrar FPS» se ve `· VIDA ON/OFF` para comparar.
- **Offline:** `dream_city_local`, semilla local estable (`worldSeed` del perfil), hora guardada (`worldTime`, que reemplaza a `tod`).
- **Online:** al entrar, RPC `world_join` (migración `20261006000000_world_life.sql`, tabla `worlds`) devuelve `world_id`, `version`, `seed` y `time`; cada 120 s se vuelve a pedir sólo para corregir la deriva. **El servidor no simula nada.** Si no hay servidor, sigue con lo local. La hora del día de la ciudad (`city_clock.gd`) ya sale de `WorldClock`: en el online es la misma para todos.
- **Versión incompatible** (`state.compatible()` es false): los sistemas de vida deberían quedarse quietos para no mostrar un mundo distinto del de los demás.

## Presupuestos (perfil por calidad: auto → autoTier)
LOW 12 vehículos activos · MEDIUM 24 · HIGH 36 (y estacionados/peatones/frecuencias en el JSON). Son valores para ajustar con pruebas reales.

## Cómo se enchufa un sistema
```gdscript
extends "res://game/world/world_life_system.gd"
func _init(): system_id = "traffic"; update_hz = 20.0
func rebuild(): # derivar desde wl.state.system_seed("traffic") + wl.clock.now()
func on_sector_changed(): # mirar wl.sectors.active / simplified / logical
func disable(): # liberar todo
# y en race.gd:  world_life.register_system(TrafficManager.new())
```

## Prueba corta
`godot --headless --script res://tests/world_life_test.gd` (35 comprobaciones: semilla, reloj sin saltos, determinismo entre «teléfonos», ON→OFF→ON reconstruye lo mismo, sectores, perfiles). Corre en CI.
