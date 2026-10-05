# Dream City · mundo abierto (en papel)

Una ciudad enorme para recorrer libre, estilo Mónaco, toda en papel y pensada para gastar poca CPU. Se entra desde el menú principal → **MUNDO ABIERTO** (antes se elige el nivel de simulación).

## Cómo está armada
- **Generador determinista** (`godot/game/city/city_layout.gd`): sale igual en todos los teléfonos a partir de una semilla (`seed_v`). Eso es lo que hace posible el online: todos ven las mismas calles, edificios y salidas en las mismas coordenadas.
- **Ejes:** x al este, z al sur (el norte es −z), todo en metros. La plaza Aurora está en (0, 0).
- **Calles numeradas:** Avenida 1–8 (cada una con su propio carácter: unas casi rectas, otras con curvas largas o cortas), anillos Calle 10–80, secundarias, Costanera 90, Camino de la Colina 300 y las rutas rurales 20/40/60/80 que terminan en una **Salida** numerada.
- **Barrios distintos:** un sector de manzanas cuadradas (calles 301 en adelante, al oeste-sudoeste), el **casco viejo** al sudeste (Calle Vieja 1–4: callejones angostos y sinuosos, fachadas de colores y veredas de ladrillo), la colina con casas bajas, la costanera y las afueras con casas chicas de techo a dos aguas.
- **Atajos 1–4:** caminos con curvas que unen una ruta rural con la de al lado (vas por una principal y, si doblás, salís por otra).
- **Zonas abiertas** (se maneja por adentro): la **Plaza Aurora** (parque con monumento y árboles) y el **Parque del Drift** (plaza redonda pavimentada con calle alrededor).
- **Las calles son un laberinto cerrado:** no hay banquina; al borde de cada calle hay **frentes de edificios pegados** (losas de pared sobre la línea de edificación, con su altura, color, ventanas y techo). Donde cruza otra calle la pared termina justo sobre la línea de esa calle, así las esquinas quedan cerradas. Detrás de la pared no hay nada: el jugador nunca ve qué hay atrás. Las rutas rurales llevan **dos filas de árboles de papel recortados** a cada lado y, al final, un **portón cerrado** con el cartel «SALIDA N · PRÓXIMAMENTE» (la ciudad vecina abre en la próxima actualización).
- **Cuadras de carga** (160 m, `city_world.gd`): solo existen las que están cerca de la cámara; las lejanas se borran (a lo sumo una cuadra nueva por cuadro). Cada cuadra son pocas mallas: terreno, calles con veredas y rayas, frentes y objetos.
- **Fachadas** (`fx/city_facade.gdshader`): ventanas, postigos, balcones, vidrieras y toldos los dibuja el shader a partir de las medidas de la pared (UV en metros). Cero imágenes grandes.
- **Física** (`track/city_track.gd`): corredores de calle (`probe`/`push`), fuera de la calle hay una pared invisible. Consultas puras (~17 µs), seguras para los hilos de la física. Misma interfaz que la pista de drift.
- **Objetos de papel que se rompen:** farolas, árboles, semáforos y bolardos (el monumento y los portones no se rompen); una malla por cuadra.
- **Presupuesto** (vista completa, capturas de prueba): 70–130 llamadas de dibujo y 25–50 mil triángulos por cuadro; la niebla y el radio de cuadras bajan solos en teléfonos flojos (`view_k`).

> Nota técnica: Godot toma como frente de una cara el sentido horario. El generador de mallas (`Soup.tri`) emite los vértices en ese orden; si se invierte, las paredes se ven «abiertas» desde la calle (se ve el interior de la caja).

## Locales (concesionario y talleres)
Ocho locales con puerta de garage, cada uno en una avenida, con cartel de su color. Frente a cada uno hay un **círculo verde** sobre el asfalto: si frenás encima, el auto se alinea derecho frente al portón, el portón de papel sube, el auto entra solo y la pantalla se funde a negro. Se abre el menú de ese local y al tocar **🚪 SALIR** volvés a la calle, en el mismo lugar y con el auto como lo dejaste.

| Local | Qué hace |
|---|---|
| Concesionario Dream City | autos nuevos y garaje |
| Taller de Pintura | colores, acabados, llantas, pinzas y discos |
| Taller de Motor | motor, turbo, aligerado y nitro |
| Taller de Transmisión | caja de cambios, diferencial y reparto de tracción |
| Suspensión y Frenos | suspensión, amortiguadores, barras, frenos y estilo |
| Taller de Ruedas | gomas, presiones y alineación |
| Reglaje Central (pista) | aerodinámica, alineación y presiones |
| Reglaje del Puerto (tierra y drift) | suspensión, frenos, transmisión y extras |

Se definen en `godot/game/data/shops.gd` (qué pestañas, mejoras y grupos de ajuste muestra cada uno) y en `POI_SPECS` de `city_layout.gd` (dónde están). Cada local tiene una calle de entrada (`kind = "bay"`) que cruza la vereda hasta adentro del edificio. El flujo está en `city_shops.gd` (círculo, portón, entrada y fundido) y en `app.gd`/`menu.gd` (`city_return`: vuelta a la calle).

## Subsuelo (oculto: no figura en el mapa ni en el GPS)
- **Túnel en cruz**: dos calles cubiertas de 1,8 km que se cruzan en el centro (con curvas). Es un tubo cerrado (piso con rayas, paredes con franja, techo con lámparas); en el cruce las paredes se abren hacia la otra calle. Cuatro **bocas** escondidas fuera del centro: este y oeste (en las rutas 20 y 40), norte (ruta 60) y sur (costanera). Se entra por una y se sale por la boca del brazo por el que se llegue al final, con la velocidad conservada.
- **Estacionamiento subterráneo**: boca en el Parque del Drift (cartel «P ESTACIONAMIENTO»); adentro una sala redonda con pilares, **sin autos** (los únicos autos serán los 3D de los jugadores que entren al mundo abierto), se maneja libre y se sale por el círculo verde del sur.
- Cómo se hace: el túnel y la sala están en un «bolsillo» del mundo (x > 3000, plano) y las bocas son enlaces (`links` de `city_layout.gd`, `city_links.gd`) que mueven el auto con un fundido a negro. Abajo la luz del sol casi se apaga y la niebla es oscura y corta (`race.gd`, `_underground_light`).
- Las puntas de los brazos todavía salen a la ciudad; en la próxima actualización pueden conectar con otras ciudades.

## Estacionamiento Central y aparición
- **Un solo estacionamiento, unido a la calle:** el **Estacionamiento Central** está junto a una ruta rural (Ruta 40/60/20/80, entre 140 y 300 m de la ciudad), con un gran cartel «P» azul. Se entra **manejando** por un carril de entrada («Entrada Estacionamiento Central»): no hay círculo verde ni teletransporte (los círculos verdes quedan sólo para los talleres y el concesionario).
- Son **tres salas redondas planas a distinta altura** (planta baja a nivel de la calle, subsuelo −4,4 m y planta alta +4,4 m) unidas por dos rampas («Rampa …», calles tipo túnel) de 10 %; no se superponen en planta, así el suelo de cada una es una altura simple (`open_areas` con `y`; `city_layout.gd`: `_place_garage`/`_build_garage`; `city_world.gd`: `_hall` y `_garage_sign`).
- **Al entrar al mundo se elige dónde aparecer** (`menu.gd`, pantalla «¿DÓNDE APARECER?»): a nivel de la calle, un piso arriba o un piso abajo. Se pasa `spawn` en el cfg y `race.gd` lo usa como `track.spawn_i`.
- Los túneles ocultos (bolsillo) siguen existiendo en los 4 brazos con las bocas de `city_links.gd`.

## Salidas de la ciudad
- **Ruta 60 → Plaza de Drift (física, en el mismo mundo):** la ruta termina en un playón redondo de 90 m de radio, plano (`height()` mezcla el terreno con la altura de la plaza), con disco de asfalto y anillos pintados (`city_world.gd: _drift_disc`), cerco de postes con una sola abertura donde entra la ruta (pared invisible analítica en `city_track.gd: _push_locked`) y **conos con física** (`city_drift.gd`, reutiliza `cone_field.gd`). Adentro suma puntos de derrape como la sesión de drift (combo hasta ×5, chocar pierde el derrape, un cono baja el multiplicador) y guarda el mejor en las estadísticas. Figura en el mapa y se puede ir con el GPS.
- **Ruta 20 → Modo aventura:** portón abierto (sin barrera, cartel AVENTURA). Al cruzarlo (a menos de 12 m, `race.gd: _check_gates`) la pantalla se funde a negro y se abre la pantalla de la aventura (`app.gd: _on_race_exit` con `gate:`). *La aventura sigue siendo otra escena (12 etapas con su propia pista): la fusión física completa queda pendiente.* Ruta 40 (estacionamiento) y 80 siguen sin otra ciudad.
- **Carteles de orientación** a ~70 m de la salida de cada ruta: «RUTA 60 · PLAZA DE DRIFT · 1,3 km» de un lado y «DREAM CITY · centro» del otro (`city_world.gd: _route_signs`).

## Paisaje y calles (papel)
- **Dentro de la ciudad:** sólo farolas, carteles y canteros de flores en el centro lujoso; **sin árboles** (los árboles quedan para plazas, colinas y rutas). Fachadas con caras de papel, huecos angostos tapados por farola + flores en lugar de edificios apretados.
- **Árboles de ruta de papel cruzado (estilo PepeCraft):** tres planos verticales cruzados a 60° con degradé (conífera, álamo o copa redonda) y tronco de dos tiras, dibujados por los dos lados: ~50 triángulos por árbol en vez de cientos (`city_props.gd: card_tree`). Sin física ni animación.
- **Rutas rurales:** franja delgada de árboles, segunda hilera más atrás, pasto, **cerco de postes** a cada 6 m, carteles de curva, límite de velocidad y **PARE** en los cruces de calles menores; **horizonte falso** de colinas de papel que sigue a la cámara (`city_world.gd: _horizon`).
- **Cámara que no entra en los edificios** (`camera_rig.gd: _clearance`, `city_track.gd: camera_clear`): muestrea cada 1,5 m entre el auto y la cámara y la acerca (rápido) o la aleja (lento) y la sube un poco.
- **Faros** más realistas (`city_clock.gd: _build_beam`: dos conos anidados con bordes suaves y charco de luz en el piso, una sola malla aditiva) y **sin parpadeo** en las rayas amarillas (marcas 0,11 m arriba) y en los edificios claro/oscuro (normal de la fachada tomada de la malla, no de derivadas de pantalla).

## Mapa grande y GPS
- Zoom (＋ − y pellizco), arrastrar para mover, 🎯 MI AUTO, tocar un lugar o cualquier punto para marcar el destino. El GPS se actualiza solo: recorta la ruta a medida que avanzás y recalcula si te salís (>24 m).

## Controles y FPS
- Pausa → **MODIFICAR CONTROLES**: cada control se arrastra con un dedo y se agranda/achica con dos; GUARDAR / RESTABLECER / CANCELAR; se guarda en el perfil (`ctrlLayout`).
- Opciones → Gráficos → **Mostrar FPS** (apagado de fábrica), arriba a la derecha.

## Hub online, apodo y última ubicación
- **Modo online → (cuenta) → apodo → hub**: la primera vez se pide el nombre del jugador (3–16 letras, sin insultos; es el `name` del perfil, el mismo que usan rankings, chat, amigos, reportes y mercado; se cambia desde el hub con CAMBIAR). El hub muestra apodo, auto elegido, estado de conexión, jugadores y amigos conectados y el botón **ENTRAR AL MUNDO** → dónde aparecer: **ÚLTIMA UBICACIÓN** (se guarda al salir del mundo; se descarta si cambió la versión del mapa: `CityLayout.WORLD_VERSION`) o uno de los tres niveles del Estacionamiento Central.
- **Se ven los otros jugadores** (`online/remote_cars.gd`): cada auto es un auto de papel liviano con el apodo arriba (dorado si es amigo), sólo los 12 más cercanos y a menos de 700 m. Se piden las posiciones cada ~2 s (`presence_list`) y se avisa la propia cada 2 s (`presence_beat`); entre una lectura y otra el auto se estima (última posición + rumbo × velocidad) y se acerca suave. Sin física compartida: no chocan. Por ahora va por RPC cada 2 s; **Supabase Realtime** (broadcast) queda para una segunda vuelta si hace falta más fluidez.

## Online del mundo (con cuenta)
Desde **Modo online → INGRESAR A LA CIUDAD** el mundo se abre con `cfg.online`. En la **pausa** aparece **ONLINE · CHAT, JUGADORES, MERCADO** (sin salir del mundo) y **MAPA / GPS**:
- **Chat mundial** y **privados** (tocar el nombre de alguien), con filtro de insultos, bloqueo creciente y aviso de tiempo restante.
- **Jugadores conectados** y **Amigos** (seguir / dejar de seguir, «IR HASTA ÉL (GPS)»).
- **Reportar**: guarda la evidencia para revisar a mano (sin castigos automáticos).
- **Mercado de autos**: vender un auto con sus mejoras al precio que quieras, comprar, retirar de la venta y cobrar.
Código: `game/online/online_social.gd` (cliente), `game/ui/online_panel.gd` (pantallas), SQL y reglas en `docs/ONLINE_SUPABASE.md`.

## Nafta y gasolineras
- **4 gasolineras de papel**, cada una un **playón** que ocupa el lugar de una manzana (varios círculos que se pisan, con una pared de edificios por detrás), con techo sobre islas de surtidores, carriles con **3 a 6 puntos de carga** (círculo verde), kiosco con vidriera, poste de precios y carteles (`_place_stations`/`STATION_KINDS` en `city_layout.gd`, `_station` en `city_world.gd`). El generador busca un lugar libre cerca del pedido (sin pisar calles, locales ni zonas abiertas):
  - **Carga Rápida Central** (grande, 6 puntos) en la Avenida 3, cerca del centro, donde pasa la mayoría. Carga en ~2 s y cuesta un 30 % más, pero regala un **pase de peaje** (los dos próximos peajes a mitad de precio).
  - **Gasolinera Norte** y **Oeste** (medianas, 4 puntos) en los barrios.
  - **Gasolinera Ruta 20** (chica, 3 puntos) saliendo de la ciudad por la Avenida 1, antes del peaje.
- **El tanque dura unos 80 km** (`city_fuel.gd`): consume más con el acelerador a fondo y casi nada al soltarlo. Se guarda en el perfil (`fuel`) y no gasta bajo tierra.
- **Sin estar pendiente:** al bajar del 15 % aparece un aviso y el **GPS marca solo la gasolinera más cercana**; con el tanque vacío el auto no acelera (hay que llegar a una gasolinera, o usar el último trecho en bajada). Barra de nafta bajo el minimapa.
- **Cargar:** frenás sobre un círculo verde, tarda 1,5 s + 3 s por tanque entero que falte, y se **paga con créditos** (120 por tanque lleno). Si no alcanzan se carga lo que se pueda pagar; con tanque vacío y 0 créditos regalan un 8 % para seguir. En modo desarrollador es gratis.
- Es una buena razón para vender créditos (Coins) en la tienda: la nafta es el gasto fijo del mundo abierto.

- **Todo en papel:** techos plegados en dos aguas, banderines de papel colgando de los aleros, canteros con flores y árboles del pack (los de la gasolinera se pueden romper), conos de papel plegado; el material es el de papel (grano, sombreado plano y dobleces marcados).

## Peajes
- **Un peaje por cada ruta rural** (Ruta 20, 40, 60 y 80), a ~95 m de donde empieza la ruta (antes de la ruta de alta velocidad). Pórtico, isla central con cabina y **una barrera por carril** (`_toll` en `city_world.gd`, lógica en `city_toll.gd`).
- La barrera cerrada es **sólida** (círculos de choque): hay que frenar (menos de ~30 km/h) en un carril, se **cobra 30 créditos** (15 con pase), la barrera se levanta y se pasa. Sin créditos no abre. Para volver a la ciudad las barreras se abren solas y no se cobra. En modo desarrollador pasa gratis.

## Cámara y calidad
- La cámara predeterminada es siempre la **interior con los dos pilotos** (la de atrás del piloto). Al actualizar, una sola vez, se pone en esa cámara y **todos los gráficos pasan a «Automático»** (`migr` en el perfil).
- Si el teléfono anda lento, el juego baja solo, en este orden: partículas, resolución del mundo 3D, **alcance de la vista de Dream City** (menos cuadras armadas y niebla más corta, hasta 0,6), texturas y el filtro de cámara. Las cuadras de alrededor se arman antes de largar (`warm`) y lo lejano se oculta por distancia (`visibility_range`).

## Día y noche
- **Un día entero dura 16 minutos** (`city_clock.gd`): amanecer, mañana, mediodía, tarde, atardecer y noche. El reloj se ve bajo la barra de nafta y la hora se guarda en el perfil.
- **Liviano:** son unos pocos valores (cielo, luz del sol o la luna, ambiente y niebla) que se recalculan 8 veces por segundo; no hay luces dinámicas ni sombras nuevas. El ambiente sale de un color (no del cielo), así el cielo no regenera reflejos.
- **De noche:** las **ventanas y vidrieras** se prenden en el shader de las fachadas (`night`), las **lámparas** brillan y tiran charcos de luz sobre el piso (malla aditiva por cuadra, `city_glow`), la gasolinera enciende su techo y el auto tiene un **haz de faros** plano sobre el piso. Bajo tierra la luz sigue siendo la de siempre.

## HUD
- **Minimapa que gira** con el auto (arriba = hacia donde mirás, la N roja gira), nombre de la calle y cuadra.
- Tocando el minimapa se abre el **mapa grande fijo** (norte arriba) con lugares y salidas: tocá un lugar (o cualquier punto) y el **GPS** traza el camino por las calles (Dijkstra sobre los puntos de las calles, unos pocos ms) con aviso de la próxima curva y la distancia; si te salís del camino recalcula.

## Pruebas
- `tests/city_test.gd` (también en el CI): calles, pendientes, edificios fuera de corredores, GPS a cada lugar y salida, costo de las consultas.
- `tests/city_shots.gd`: capturas desde varios puntos (xvfb).
- Pruebas con banderas: `--autotest=gt@aurelia@-@pose:x,z,grados@tod:21@fuel:0.3` (`tod` fija la hora, `fuel` la nafta con la que arranca; `-` = sin GPS).
- Manejo automático por el GPS: `--menu --autotest=gt@aurelia@concesionario` (el auto va solo hasta ahí y avisa si llegó o se trabó).

## Qué falta (por etapas)
(Ver el plan completo en `docs/PROXIMA_ACTUALIZACION.md`.)
1. Semáforos, farolas, bolardos, árboles y conos de papel, rompibles (`add_prop`/`remove_prop` ya existen en la pista).
2. Rutas rurales con bordes de fotos de árboles y paredes invisibles; plaza con monumento.
3. Autovía elevada + tren de alta velocidad y de carga (imágenes), túnel por la montaña, puentes, campos de girasoles, estacionamiento subterráneo.
4. Concesionarios y talleres con puerta de garage que se abre y menú del taller visto de costado (suspensión y pintura; las piezas de carrocería las trae el dueño).
5. Fusión física con la plaza de drift y la aventura (hoy las salidas abren sus pantallas), carteles y publicidad de empresas.
6. Online: ver abajo.

## Diseño online
- **Mapa único y compartido** por servidor de 10–20 jugadores; la semilla y la versión del generador viajan en la sala para que todos tengan la misma ciudad.
- **Coordenadas:** cada jugador publica (x, z, rumbo, velocidad, auto/pintura) ~10 veces por segundo por Supabase Realtime (canal por sala); los demás lo dibujan como un auto de papel interpolado. Solo se pide la presencia de quienes están a menos de ~400 m (las mismas cuadras que se cargan).
- **Objetos rotos** (semáforos, árboles): estado por cuadra, mínimo (lista de ids rotos con hora de reaparición), sin física compartida.
- **Autoridad:** cada cliente maneja su auto; no hay choques autoritativos entre jugadores (solo empujón visual) para que ande bien con mala señal.

## Etapa 12 — bordes y guardarrailes
- **Banquinas con escalones (visto en las capturas del teléfono)**: el terreno se hunde bajo las calles para que el asfalto quede por encima de la ladera, pero lo hacía todo-o-nada por cada vértice de 16 m, así que en las banquinas el borde subía y bajaba como una escalera. Ahora el hundimiento se desvanece con la distancia al borde de la vereda (`CityWorld._terrain`, `smoothstep`), sin escalones.
- **Guardarrailes en barrancos** (`CityLayout._place_guardrails`, tipo de objeto `GUARD`): donde el terreno cae más de 1,3 m a 6 m del borde de la banquina (hoy: el camino de la colina, 135 tramos) se pone un guardarrail de 4 m, sólido (círculo de choque de 1,25 m), que no se rompe, a la altura de la calle y fuera del asfalto y de los cruces. Si se agrega otra ruta con barrancos, los pone solo.
- Prueba: `tests/guardrail_test.gd`.
- **Pendiente de ver en el APK** (no se pudo reproducir sin el teléfono): esquinas de edificios donde el auto se «engancha», y postes en lugares raros. Cuando pase, mandar la calle/cuadra que muestra el HUD y el momento.

## Etapa 13 — Ruta Panorámica 70 (montaña + costa) y gasolineras
- **Sierra**: dos lomas de borde suave sumadas a `CityLayout.height()` (`MT_A` 72 m de alto y 1050 m de radio, al este; `MT_B` 40 m junto al mar). Desnivel total del camino ≈ 85 m.
- **Ruta Panorámica 70** (`kind: "scenic"`, calzada de 4,6 m de semiancho y banquina de 3,6 m, **4,6 km**): sale del extremo este de la costanera (cruce agregado a mano), toma una espiral de casi una vuelta alrededor de la sierra subiendo con pendiente suave, baja por el lado sur y termina en un tramo costero con guardarrailes, antes de x = 3000 (el bolsillo plano de los túneles). Pendiente máxima 12 %. El final es un callejón sin salida con tres bloques de hormigón. Tiene alambrado y árboles como las rutas rurales y guardarrailes sólidos en los tramos con barranco (245 tramos).
- **Gasolineras en la ruta**: *Pie de Sierra* (a 900 m, cerca de la subida) y *Mirador* (a 4400 m, en la costa); las dos de tamaño chico con 3 puntos de carga. El `ov` del playón exige banquina ≥ 3,3 m para que entre una gasolinera: por eso la banquina de 3,6 m.
- **«La otra ciudad»**: todavía no existe (las Salidas 40 y 80 siguen cerradas), así que por ahora no hay gasolineras ahí; cuando se genere esa ciudad se pueden poner con el mismo mecanismo (`STATION_SPECS`).
- `WORLD_VERSION` pasó a 5 (el mapa cambió: una «última ubicación» vieja ya no sirve).
- ⚠ Aprendido: no iterar una constante `Array` dentro de `height()` (se llama desde los hilos de física y daba errores de acceso); por eso las lomas son dos constantes `Vector4`.

## Etapa 14 — superficies del mundo (`world/world_surfaces.gd`)
Antes todo lo que no era calle era «afuera» (código 4). Ahora `CityTrack.ground_info` devuelve según dónde se esté (función pura, igual en cliente y servidor):
| Dónde | Código | Efecto (agarre = `surfGrip` × neumático; polvo y sonido ya distinguen cada código) |
|---|---|---|
| Calzada | 0 asfalto | |
| Vereda / banquina de la calle | 2 | |
| Playa (z > 1090 y altura < 3,4 m) y **banquina de tierra** a menos de 6 m de una ruta de campo (rural, atajo, panorámica, colina) | 1 tierra/arena | polvo y ruido de tierra suelta |
| Plaza Aurora, barrios, colina y campo | 3 pasto | |
| Sierra desde 44 m | 4 roca | poco agarre |
| Cumbre desde 64 m | 6 nieve pisada | |
| Entre edificios | 4 | |
El color del suelo del mapa usa las mismas alturas (`WorldSurfaces.color`): arena clara, roca gris y nieve blanca. `CityLayout.verge_clearance()` mide a cuántos metros de la banquina se está (probe() sólo es confiable adentro del corredor). Costo de `ground_info`: ≈ 17 µs. Prueba: `tests/surfaces_test.gd`. Barro (5) queda libre para la lluvia (Etapa 17).

## Etapa 15 — actividades del mundo abierto (`world/world_activities.gd` + `city/city_activities.gd`)
Reglas puras (dónde, cuánto paga, medallas) en `world_activities.gd`; el estado (récords y cobros) en el perfil (`profile.d["act"]`, offline). **Online todavía no** (los créditos online los dará el servidor; ver `docs/ECONOMIA_ONLINE.md`): con `cfg.online` no hace nada.
- **Radares** (8: avenidas 1·3·5·7, Rutas 20 y 60 y dos en la Ruta Panorámica): una línea naranja y una cámara junto al cordón. Pasar a ≥120 km/h paga $150, ≥160 $300, ≥200 $600, ≥240 $1000, **una vez por radar por día del mundo** (16 min); se guarda el récord de velocidad de cada radar.
- **Contrarreloj Panorámica**: línea verde de largada al principio de la Ruta Panorámica y línea blanca de llegada al final (4,5 km); cronómetro en pantalla. Oro ≤ 3:55, plata ≤ 4:35, bronce ≤ 5:30; el premio ($400 / $900 / $1800) se cobra sólo al mejorar la medalla.
- **Encargos**: el mundo ofrece (según semilla + día + número de encargo, igual para todos) llevar algo de un lugar a otro (gasolineras, locales, estacionamiento, peajes, plaza de drift) entre 350 y 1800 m. Se recoge frenando en el círculo amarillo, se entrega frenando en el verde (el GPS marca el destino). Paga $150 + 0,35 $/m; +30 % si llegás en menos del 70 % del tiempo límite, la mitad si llegás tarde (hasta 1,5×) y nada después. Se ofrece el más cercano de los próximos cuatro.
- Prueba: `tests/activities_test.gd` (reglas, determinismo y un auto simulado cruzando un radar, la contrarreloj y un encargo completo).
