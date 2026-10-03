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

## Nafta y gasolineras
- **4 gasolineras de papel** (Norte, Este, Sur y Oeste, sobre las avenidas 7, 1, 3 y 6): lote redondo abierto con techo de color, surtidores, kiosco, poste de precios y un **círculo verde** por cada punto de carga (`_place_stations` en `city_layout.gd`, `_station` en `city_world.gd`).
- **El tanque dura unos 80 km** (`city_fuel.gd`): consume más con el acelerador a fondo y casi nada al soltarlo. Se guarda en el perfil (`fuel`) y no gasta bajo tierra.
- **Sin estar pendiente:** al bajar del 15 % aparece un aviso y el **GPS marca solo la gasolinera más cercana**; con el tanque vacío el auto no acelera (hay que llegar a una gasolinera, o usar el último trecho en bajada). Barra de nafta bajo el minimapa.
- **Cargar:** frenás sobre un círculo verde, tarda 1,5 s + 3 s por tanque entero que falte, y se **paga con créditos** (120 por tanque lleno). Si no alcanzan se carga lo que se pueda pagar; con tanque vacío y 0 créditos regalan un 8 % para seguir. En modo desarrollador es gratis.
- Es una buena razón para vender créditos (Coins) en la tienda: la nafta es el gasto fijo del mundo abierto.

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
5. Conexión con la plaza de drift, carteles y publicidad de empresas.
6. Online: ver abajo.

## Diseño online
- **Mapa único y compartido** por servidor de 10–20 jugadores; la semilla y la versión del generador viajan en la sala para que todos tengan la misma ciudad.
- **Coordenadas:** cada jugador publica (x, z, rumbo, velocidad, auto/pintura) ~10 veces por segundo por Supabase Realtime (canal por sala); los demás lo dibujan como un auto de papel interpolado. Solo se pide la presencia de quienes están a menos de ~400 m (las mismas cuadras que se cargan).
- **Objetos rotos** (semáforos, árboles): estado por cuadra, mínimo (lista de ids rotos con hora de reaparición), sin física compartida.
- **Autoridad:** cada cliente maneja su auto; no hay choques autoritativos entre jugadores (solo empujón visual) para que ande bien con mala señal.
