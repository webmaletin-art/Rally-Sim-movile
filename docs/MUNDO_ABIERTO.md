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

## HUD
- **Minimapa que gira** con el auto (arriba = hacia donde mirás, la N roja gira), nombre de la calle y cuadra.
- Tocando el minimapa se abre el **mapa grande fijo** (norte arriba) con lugares y salidas: tocá un lugar (o cualquier punto) y el **GPS** traza el camino por las calles (Dijkstra sobre los puntos de las calles, unos pocos ms) con aviso de la próxima curva y la distancia; si te salís del camino recalcula.

## Pruebas
- `tests/city_test.gd` (también en el CI): calles, pendientes, edificios fuera de corredores, GPS a cada lugar y salida, costo de las consultas.
- `tests/city_shots.gd`: capturas desde varios puntos (xvfb).
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
