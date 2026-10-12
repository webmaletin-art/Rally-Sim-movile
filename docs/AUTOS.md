# Autos (lista definitiva, 26)

Todos los autos tienen **modelo con textura propia, sin reducir** (de 300 mil a casi 1 millón de triángulos; `<id>.glb`) más una versión liviana de ~6 mil triángulos con la misma textura para los rivales (`<id>_lo.glb`), en `godot/game/models/cars/`.
Los modelos crudos (`Autos_texturas.part*.rar` + `MoustExtreme.glb`) NO están en el repo: `tools/cars/build_final.py` los lee de una carpeta (`CARS_SRC`, por defecto `/tmp/claude-0/autos`).

## Pipeline
- `tools/cars/final_cars.py`: qué modelo crudo es cada auto, giro, largo, ancho, alto real (`HEIGHT`), pasos de rueda, vidrio.
- `tools/cars/final_wheels.py`: llantas (`style`), tamaños, goma (`tread`), suspensión, color de llanta de fábrica (`RIM`) y canales de color de la textura (`TEX`, ver más abajo).
- `tools/cars/final_specs.py` + `make_final_vehicles.py`: física, precio y orden → `vehicles.json` y `catalog.json`. El inicial es el **R2 Turbo** (el más lento y barato: 9 000).
- `python3 tools/cars/build_final.py [ids]` arma `<id>.glb`, `<id>_lo.glb` y `<id>.json`; `--meta` refresca solo ruedas y canales de color. Después `godot --headless --import`.
- **Torito '67**: el modelo trae el motor a la vista (sin capó) y así se deja, es su diseño.
- **Bisonte XR**: el modelo va sin deformar (altura natural ~1,67 m, techo más alto que el viejo) y con las medidas físicas de siempre: entre ejes 2,95 m, rueda R 0,508, trocha 1,86 m, ancho ~2,2 m. Ruedas nuevas: negras, beadlock, goma de taco grande (como el Genesis X Skorpio). La física no cambió.
- `t1plus` quedó solo como ficha de física **oculta** (`"hidden": true`): la usan la IA y las pruebas contra la versión HTML; no está en el garaje ni en la tienda.
- Borrados: Safari, Volcán y Veltor Max Pro GTR Original (HD).

- **Nivelado:** si el modelo viene «cabeceado» (paso de rueda de adelante más bajo o alto que el de atrás), `build_final.py` lo gira sobre x hasta nivelarlos (Trilux −4,8°, Veltor −3,4°, Trilux Sport −2,2°, SUV, Buggy…): así ningún auto se ve inclinado hacia el frente sobre sus ruedas.
- **Cámaras de adentro:** con la cámara adentro se dibuja la carrocería liviana (`_lo`, ~6 mil triángulos: más rápida) y se recorta todo lo que está detrás de la base del parabrisas (techo, puertas, columnas, volante del modelo); el habitáculo (tablero, butacas, jaula, pilotos) lo arma `cockpit.gd` con las medidas de `cabin_cfg.gd`. Los pilotos y el tablero no quedan a más de 1,12 m del parabrisas.
- **Suspensión visible:** los brazos terminan sobre el piso de la carrocería (no asoman por abajo), el resorte lleva más vueltas en carrocerías altas (Bisonte) y los camiones sacan las ruedas un poco más afuera (`x_off` en `final_wheels.py`) para tapar los bulones del eje del modelo.

## Colores
- «De fábrica» (rotulado 11) muestra la textura original.
- La textura se recolorea con dos colores (carrocería y detalles); canales por auto en `TEX`. Un color sólido = detalles iguales a la carrocería.
- Estilos listos en Garaje → Pintura → Carrocería (`game/car/paint_presets.gd`): 15 sólidos con letras en las puertas (Dream Racing / SRGamestudios / Sport / nombre del auto, con su propio color en «Letras»), 8 de textura con dos colores y «De fábrica».

## Ruedas
`wheel_gen.gd`: 27 diseños de llanta (nuevos: `bead10`, `split8`, `rally7`, `dish5`, `mag5`, `steelcap`, `mono12`, `trophy`, `fan`, `twin5`, `windows`) y 9 dibujos de goma (`road`, `slick`, `offroad`, `mud`, `rally`, `sport`, `truck`, `dune`, `classic` con cinta blanca), todos con letras en el flanco. Cada auto trae las suyas; el jugador las cambia desde el taller (`parts.json`, `rim_*`). Vitrina de prueba: `godot/tests/_wheelview.gd`.

## Tabla
| # | id | Auto | Tipo | Tracción | Precio | 0-100 | PI | |
|---|----|------|------|----------|--------|-------|----|---|
| 1 | `hatch` | PAMPA R2 Turbo | Hatch urbano | FWD | 9.000 | 8.5 s | 487 | ★ inicial |
| 2 | `torito` | BRAVA Torito '67 | Clásico de demolición | RWD | 18.000 | 7.4 s | 530 |  |
| 3 | `hatch2` | PAMPA R2 Rally | Hatch de rally | AWD | 24.000 | 4.5 s | 599 |  |
| 4 | `clasico60` | ÑANDÚ Legend GT | Deportivo clásico | RWD | 30.000 | 6.4 s | 536 |  |
| 5 | `titan` | COLOSSUS Titán T4 | Camión tractor | RWD | 32.000 | 14.0 s | 250 |  |
| 6 | `pickup` | PAMPERO Yaguareté 4x4 | Pick-up 4x4 | 4x4 | 34.000 | 6.1 s | 454 |  |
| 7 | `suv` | TEHUELCHE G4 4x4 | SUV todo terreno | 4x4 | 38.000 | 6.0 s | 511 |  |
| 8 | `kodiak` | CÓNDOR Kodiak Raid | Pick-up de raid | 4x4 | 44.000 | 5.2 s | 557 |  |
| 9 | `camo` | CÓNDOR T6 Multicam | Camioneta todo terreno | 4x4 | 46.000 | 5.7 s | 525 |  |
| 10 | `buggy` | CHAKAL Dune R | Buggy Dakar | RWD | 50.000 | 6.7 s | 641 |  |
| 11 | `muscle` | BRAVA Furia V8 | Muscle car | RWD | 56.000 | 6.8 s | 629 |  |
| 12 | `truck` | COLOSSUS Mamut 6x6 | Camión Dakar | AWD | 60.000 | 13.4 s | 278 |  |
| 13 | `rally80` | SEND Rally 80 | Rally Grupo B | AWD | 64.000 | 3.9 s | 653 |  |
| 14 | `gt` | KAZE Zero GT | Coupé GT | RWD | 72.000 | 6.0 s | 645 |  |
| 15 | `trilux` | TRILUX Base | Coupé deportivo | RWD | 78.000 | 6.5 s | 590 |  |
| 16 | `pro_gt` | ALTAIR Pro GT | GT de pista | RWD | 92.000 | 5.2 s | 684 |  |
| 17 | `kl5` | KAIRÓS KL5 Sport | GT de pista | RWD | 98.000 | 5.5 s | 706 |  |
| 18 | `trilux_s` | TRILUX Sport | Coupé deportivo | RWD | 104.000 | 6.1 s | 642 |  |
| 19 | `trilux_gt` | TRILUX Pro GT | Coupé de pista | RWD | 118.000 | 5.9 s | 707 |  |
| 20 | `gt3` | ALTAIR GT3 RS | GT3 de pista | RWD | 130.000 | 5.1 s | 705 |  |
| 21 | `veltor` | VELTOR Max | Superdeportivo híbrido | AWD | 150.000 | 3.1 s | 737 |  |
| 22 | `veltor_s` | VELTOR Max Sport | Superdeportivo híbrido | AWD | 185.000 | 2.9 s | 772 |  |
| 23 | `genesis` | DR Bisonte XR | Hiperdeportivo AWD | AWD | 190.000 | 4.0 s | 710 |  |
| 24 | `moust` | MOUST Extreme | Superdeportivo extremo | AWD | 205.000 | 2.9 s | 781 |  |
| 25 | `veltor_gtr` | VELTOR Max Pro GTR | Hypercar de pista | AWD | 225.000 | 2.9 s | 805 |  |
| 26 | `hyper` | VORTEX Aerion | Hypercar híbrido | AWD | 260.000 | 3.0 s | 766 |  |

## Paquetes de contenido
Los autos pesan ~500 MB: el contenido se parte en `content.pck` (todo menos `game/models/cars/`) y `cars.pck` (los autos). `tools/export/split_presets.py` arma el preset «Cars»; el APK liviano baja los dos (ver `bootstrap/boot.gd`), `cars.pck` solo si cambió (su versión es su hash). Ya no se arma el APK «completo». El AAB de Play (preset.3) lleva todo adentro y supera el límite: hay que usar Play Asset Delivery antes de subirlo.

## Pendiente para abrir el modo online
- ~~Sumar los 26 autos al catálogo online~~ **Hecho**: `tools/online/online_catalog.json` + migración `supabase/migrations/20261009000000_online_catalog_26.sql` (pintura de fábrica `livery: 11`; hay que aplicarla con el flujo «Supabase · aplicar migraciones»). Ojo: con `ONLINE_ALL_CARS` en `tools/online/export_catalog.gd` los autos premium (Mamut 6x6, GT3 RS, Aerion) y el Bisonte XR también se pueden comprar con los créditos DEL ONLINE (la plata del online es aparte de la del juego sin conexión y no se vende); si no se quiere, ponerlo en `false` y regenerar.
- El color de las letras (`paint.text`) todavía no viaja al servidor (`SERVER_PAINT_KEYS` en `online_profile.gd`): hay que agregarlo junto con la migración.

- **Pilotos vistos desde afuera:** los pilotos siempre están en las cámaras de adentro. Opción Opciones → Gráficos → «Ver los pilotos desde las cámaras de afuera (vidrios transparentes)» (`crewOut`, apagada por defecto): el auto del jugador usa una variante del sombreador de pintura con el vidrio translúcido (`LIVERY_SHADER` con `blend_mix`, `CarVisual.set_clear_glass`) y `Cockpit.crew_out` deja a los dos pilotos visibles con las cámaras exteriores. Los rivales no llevan pilotos (pendiente si se quiere).
