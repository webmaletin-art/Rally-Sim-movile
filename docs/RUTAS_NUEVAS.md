# Mapas nuevos: generador HTML + carpeta que el juego lee sola

**Flujo:** el dueño arma/dibuja/genera el mapa en `generador_mapas.html` (lo programa DeepSeek con `tools/route_gen/PROMPT_DEEPSEEK.md`) → exporta `<id>.json` (formato «dreamracing-route» v2, ver `tools/route_gen/FORMATO.md`) → lo sube a **`godot/game/data/custom_maps/`** → al compilar, la CI lo valida (`tools/route_gen/validate_all.py`), le hace dar una vuelta a la IA (`tests/custom_route_test.gd`) y el juego lo lee solo al arrancar.

## Qué soporta el juego (todo en el `.json`)
- **Camino** por puntos de control (lazo cerrado Catmull-Rom), ancho y banquina; circuito (vueltas) o punto a punto (`seg`).
- **Superficie por tramo**: asfalto, tierra, grava, barro y arena (cada una con su agarre real y el de la IA, y su textura en un atlas del camino: `RouteTrack._atlas_tex`). Arena usa el código 6 del motor (el de «nieve»: tierra × 0.78).
- **Árboles**: tipo (`none/pine/broadleaf/mixed`) y densidad por tramo, siempre dentro del presupuesto de árboles del teléfono (`race._rebuild_trees`).
- **Rivales y dificultad** (0–100 % → habilidad de la IA 0.62–1.04, `MapData.skill_of`), vueltas por defecto en Carrera rápida.
- **Evento de la carrera** que reemplaza (bloque `career`: copa, evento, cielo, inverso) y versión inversa (`reverse`).
- Carga: `data/map_data.gd` (`MapData.load_all()`) junta `routes.json` + la carpeta; lo usan RouteTrack, Race, App, Rewards y el menú. Los parches de eventos se aplican en `CarBuild.catalog()`.

## Herramientas (`tools/route_gen/`)
- `route_spec.py` (reglas y validador; acepta v1 y la convierte), `validate_all.py` (toda la carpeta; CI), `import_route.py` (valida y copia a la carpeta, con `--tier/--event/--reverse`), `make_example.py` (generador de ejemplo en Python), `build_assets_zip.py` → `dreamracing_route_assets.zip` (árboles de 8 vistas, horizonte, suelos, `referencias/mapas_del_juego.json` con 5 mapas reales medidos, ejemplos y rutas del juego).
- Pruebas: `tests/map_data_test.gd` (conversión + superficies/densidad en RouteTrack), `tests/custom_route_test.gd` (IA da la vuelta a cada mapa de la carpeta).

## Referencias medidas (por vuelta)
Bajada de los Badenes 5,13 km · Bosque 4,46 km · Montaña asfalto 3,40 km · Lago 2,60 km · Cantera 1,86 km. Índice de costo (100 = Badenes): Bosque 99, Montaña 81, Cantera 83, Lago 68.

## Pendiente
- **Picadas (drag)**: usan un óvalo fijo (`routes.json` → `picada`); el importador las rechaza con aviso. Cuando el dueño mande una, se adapta.
- Miniaturas de los mapas nuevos (`ui/tracks/<id>_0.jpg`, `_1.jpg`): se sacan con `tools/godot/run_shot.sh`; sin ellas el menú funciona igual.
- El «suelo» (`scenery.ground`) todavía se ignora en el juego; las especies de árbol del visor son sólo vista previa (el juego usa sus pinos y árboles de hojas procedurales).
- Si un mapa nuevo trae problemas de IA (se sale/traba), la CI frena: ajustar el mapa o la IA.


## Formato v3 (editor de trazados, sin visor 3D) — vigente
El generador v2 (con visor 3D) no le gustó al dueño: ahora el HTML es **sólo una grilla** para trazar (`tools/route_gen/PROMPT_EDITOR_V3.md`, formato en `FORMATO_V3.md`, reglas en `route_spec3.py`). El editor define el trazado (a mano alzada, curvas ilimitadas, **cruces a nivel**: ochos y cruces), alturas, superficie por tramo, clima, estilo de carrera, rivales y dificultad; **árboles, vegetación y borde del camino los pone el juego solo**.
- **Cruces a nivel**: `RouteTrack._find_crossings` (sólo mapas con `custom`): alturas iguales, sin guardarraíl/banquina/vegetación sobre el otro camino, el auto sigue al camino más cercano (`_pick_branch`), y `Session` mide el avance como distancia recorrida (los saltos de camino no cuentan).
- **A→B**: `MapData.close_open_path` cierra el lazo con un tramo de vuelta que no se corre; `defaults.seg = [0, B]`.
- **Estilos** (`race.style`): carrera, contrarreloj, aventura (una pasada), **persecución** y **eliminación** (`race_rules.gd`, `cfg["rule"]`). En Carrera rápida el selector «Modo» ofrece las cuatro en TODOS los mapas de ruta (los del juego también), no sólo en los personalizados.
- **Borde del camino**: `RouteTrack.build_guardrail(rail_off, wood, style)` con `guardrail` / `wood` / `fence`; `decor.edge = auto` lo elige al azar con el id del mapa (`Race._pick_edge`).
- Pruebas: `tests/map_v3_test.gd` (cruce, A→B, reglas, persecución simulada con física real); `--autotest=gt@rule:chase|elim|race@<mapa>` arranca esa carrera directo (con `--auto` maneja la IA).
- Mapas de prueba en `custom_maps/`: `prueba_04` (ocho, persecución) y `prueba_05` (A→B con barro, lluvia, aventura). Se pueden borrar cuando lleguen los del dueño.
