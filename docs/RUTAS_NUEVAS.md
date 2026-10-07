# Rutas nuevas (generador HTML + importador)

**Flujo:** el dueño genera rutas con `generador_rutas.html` (lo programa DeepSeek con `tools/route_gen/PROMPT_DEEPSEEK.md`) → exporta un `.json` («dreamracing-route» v1, ver `tools/route_gen/FORMATO.md`) → Claude lo valida e importa a la copa que diga el dueño.

## Herramientas (`tools/route_gen/`)
- `route_spec.py`: reglas y validador (mismas que el prompt). `python3 tools/route_gen/route_spec.py ruta.json`.
- `import_route.py`: agrega la ruta y el mapa a `godot/game/data/routes.json` (marcados `custom`), con `--reverse` también la inversa y con `--event <id>` cambia el mapa/vueltas/tramo de un evento de la carrera en `catalog.json`.
- `make_example.py`: generador de ejemplo en Python (misma lógica que se le pide al HTML) → `ejemplo_*.json`.
- `dreamracing_route_assets.zip`: paquete que importa el HTML (árboles de 8 vistas, horizonte, texturas de suelo, ejemplos, rutas reales del juego y el formato).
- Prueba: `godot --headless --path godot --script res://tests/custom_route_test.gd [-- --id=<ruta>]` (la IA da una vuelta completa con la pickup y el t1plus sin salirse ni trabarse).

## Lo que ya se probó
Ejemplo de circuito asfalto + inversa importados en `c1`: la IA da la vuelta (los T1+ se salen un poco con caminos angostos → por eso asfalto exige `halfWidth` ≥ 4.2).

## Pendiente
- **Picadas (drag)**: hoy la picada usa un óvalo fijo (`routes.json` → `picada`); el importador las rechaza con un aviso. Cuando el dueño mande una, se adapta.
- Miniaturas de las pistas nuevas (`ui/tracks/<id>_0.jpg`, `_1.jpg`): se sacan con `tools/godot/run_shot.sh`; sin ellas el menú funciona igual.
- Que el juego dibuje árboles/suelo según `scenery` (hoy el mapa nuevo usa el entorno estándar de su superficie).

## Mapas hoy en la carrera
Circuitos distintos: Bosque (forest), Lago (lake), Cantera (quarry), Montaña Asfalto (asphaltLong) + sus inversas, y la Picada (400 m). Sin usar en la carrera: Bajada de los Badenes, La Trinchera, Paper Race, 4 mapas fantasía, Travesía X.
