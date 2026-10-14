# Registro técnico de intervenciones

Una entrada por intervención, la más nueva arriba. Antes de tocar un sistema, buscar acá su nombre: si el problema ya se trabajó, seguir desde el último diagnóstico.
Resultado: RESUELTO · PARCIAL · FALLIDO · BLOQUEADO · PENDIENTE DE APK. Una hipótesis no es una causa confirmada.

---

## 14/10/2026 (noche) · Cámaras de adentro que tiemblan
- **Reporte del dueño:** «los autos con cámara interior se ve que tiemblan, vibran mucho».
- **Causa confirmada (medida):** `cockpit.camera_local` sumaba una vibración de hasta 8,5 mm a ~6 Hz; con la pantalla a 30–40 cuadros desparejos eso es un salto de **8,3 mm de cuadro a cuadro en promedio (peor 19 mm)** con el tablero a medio metro de los ojos. El movimiento de la cabeza por fuerzas G aportaba 0,9 mm. Las cámaras de capó/paragolpes (hasta 12 mm a 6–7 Hz) y la de atrás (hasta 26 mm en tierra) tenían lo mismo.
- **Cambio:** `cockpit.cam_jitter` (estática): ~2,5 Hz y < 2 mm; `crew_motion.cam_s` (cabeza suavizada para la cámara); `camera_rig._mounted` y `_chase` con vibración lenta y chica.
- **Prueba nueva:** `tests/cabin_shake_test.gd` (IA en tierra, física 120 Hz, pantalla 30/37 cuadros): salto medio 8,25 → **0,99 mm**, peor 19,2 → 5,1 mm (un bache de verdad).
- **Resultado:** PENDIENTE DE APK.

---

## 14/10/2026 (noche) · Cierre de golpe: Android confirma ERROR NATIVO (SIGSEGV) · carrera entre hilos en la región · entrada del estacionamiento
- **Registro del dueño (contenido r174, APK con CrashGuard), 2 de 2 se cierran:** `[android] cierre 1: ERROR NATIVO (motor o driver) (código 5, estado 11) · RAM 566 MB (pss 429 MB)`; otro igual con 570 MB y uno anterior con 880 MB.
  **Confirmado:** es un cierre nativo por señal 11 (SIGSEGV: acceso a memoria inválido dentro del motor o del driver), **no es falta de memoria** (430–740 MB de PSS, Android no lo mató por RAM). Sólo en el mundo abierto (drift varios minutos sin problema), 10–30 s después de cargar, también quieto.
  (`RAM juego ?`: en ese teléfono no se puede leer `/proc/self/status` ni `OS.get_memory_info()`; la RAM sale de Android en la línea `[android]`.)
- **Defecto encontrado (confirmado en el código):** `region_world._build` corre en hasta 4 hilos (`WorkerThreadPool`) y llama `_road_caps → _fillets → RegionData.edge_cum`, que **llenaba a demanda** el Dictionary compartido `_cum`; a la vez el hilo principal (GPS, policía, carreras) usaba la misma tabla. Dos hilos escribiendo un Dictionary de Godot pueden romper la memoria → SIGSEGV. Es exclusivo del mundo abierto y ocurre cuando más terreno se arma (los primeros segundos).
  **Que ésta sea LA causa no está confirmado:** en la computadora la versión vieja no llegó a cerrarse en 3 corridas de la prueba de estrés (sí se comprobó que los hilos escribían la tabla: 0 → 3.686 entradas). Los otros hilos del mundo abierto se revisaron: no escriben datos compartidos (los objetos sólidos de `city_track` ya tenían Mutex; `probe`, `height_w`, `_ground_color`, `verge_clearance` sólo leen).
- **Cambio:** `RegionData.load_file` calcula las distancias de las 3.686 calles al cargar (≈0,1 s en la computadora): durante el juego sólo se leen. Prueba nueva `tests/region_threads_test.gd` (tabla completa al cargar; 24 cuadrados en 4 hilos con ~900.000 consultas del hilo principal a la vez; nadie escribe la tabla).
- **Entrada del Estacionamiento Central (reporte del dueño: «tiene una valla enfrente»):** el alambrado de la Ruta 40 corría por delante de toda la explanada (salvo el carril de entrada) y había otro tramo enfrente de la salida; también árboles y flores. **Cambio:** `city_layout.lot_blocked` deja sin objetos 30 m alrededor de los playones del estacionamiento y 32 m alrededor del empalme con la ruta; `_add_prop` ya no pone un tramo de alambrado cuyos alambres crucen el asfalto de una calle. Capturas `tests/city_shots.gd … 78` (desde arriba) antes y después.
- **Pruebas:** `region_threads_test` TODO OK, `city_test`, `open_world_access_test` TODO OK, `region_terrain_test`, `police_test`, `scripts_parse_test`.
- **Resultado:** PENDIENTE DE APK. **Siguiente paso:** si con r177+ se sigue cerrando, el próximo registro dirá si sigue siendo `ERROR NATIVO`; entonces sospechar del driver Mali con el motor 4.5.1 (probar el mismo punto con el 📊 apagando terreno de la región / árboles / edificios, o volver a 4.4.1 para comparar).

---

## 14/10/2026 (tarde) · Fachadas abiertas y sobre las calles, IA marcha atrás al largar, policía en la banquina, ciudades alcanzadas, registro del mundo abierto
- **Reporte del dueño:** (1) dos registros más: **se cierra sólo en el mundo abierto** (en drift jugó varios minutos sin problema); (2) al cortar las fachadas para los concesionarios quedaron fachadas abiertas (se ve el hueco), y en el centro hay muchas; hay fachadas encima de las calles; (3) autos que apenas empieza la carrera van marcha atrás; (4) la policía debe controlar desde la orilla, no en el medio; (5) si un jugador logra pasar, que esa ciudad figure en su mapa y pueda aparecer ahí; (6) ¿qué pasa con 3 jugadores online yendo a otra ciudad?
- **(1) Registro:** el contenido del dueño era r173 (sin la RAM ni el motivo de Android, que entraron en r174). Se agrega una línea `[mundo]` cada 5 s en el mundo abierto (posición, cuadras armadas, triángulos, autos, llamadas de dibujo, primitivas). Causa **sin confirmar**; el próximo registro (r175+) trae `[android] cierre 1: …`.
- **(2) Fachadas — causa confirmada:** `city_world._slabs` sólo dibujaba el costado de una losa cuando el vecino era más bajo; en los extremos de cada tira (cruce, concesionario, hueco) no había costado → «caja abierta». Además 49 losas pisaban una calle (otra calle que pasa por detrás en curva, o las entradas de las estaciones de servicio). **Cambio:** costado completo (desde abajo) cuando no hay vecino o el vecino es menos hondo; `city_layout._free_depth` achica el fondo de cada losa hasta la calle de atrás (si queda < 4 m no se hace; las paredes de las estaciones < 2 m); los tramos del arco de las estaciones se marcan como vecinos. Resultado: 0 losas sobre calles (antes 49), 30 de 5.291 losas menos.
- **(3) IA marcha atrás — causa confirmada:** en `ai/ai_driver.gd` el reloj `time` corría durante la cuenta regresiva (`enabled = false`); al largar ya pasaban los 2 s de gracia y un auto que patinaba o estaba encajonado en la grilla a menos de 1,5 m/s durante 1,5 s se creía trabado y tiraba marcha atrás. **Cambio:** con la IA apagada el reloj y el contador de trabado vuelven a 0; gracia de 4 s. Los rivales de las carreras del mundo abierto (`police_driver`) no tenían el problema (prueba nueva).
- **(4) Policía:** `city_police._arm`: todos en las dos banquinas, escalonados, apuntando a la ruta (sin barrera en la calzada).
- **(5) Ciudades alcanzadas:** `game/city/city_reach.gd` (servicio nuevo en `city_services.gd`), `ui/menu_world.gd` (lugares no alcanzados con 🔒 en el mapa, no se eligen), `ui/spawn_map.gd` (marca gris). Textos `b62_ciudades_alcanzadas.py`.
- **(6) Online:** respuesta en `docs/POLICIA.md` (cada teléfono tiene su policía).
- **Pruebas:** `city_test`, `police_test` (nueva: ninguno en la calzada; parado te arrestan en 8,3 s; superdeportivo a fondo 18 s con los patrulleros encima), `ow_events_test` (nueva: ningún rival marcha atrás al largar), `ai_route_test` (nueva: cuenta regresiva de 3 s y nadie va marcha atrás en los primeros 6 s), `city_reach_test` (nueva), `scripts_parse_test`; capturas del centro, de los concesionarios y de una estación revisadas.
- **Resultado:** PENDIENTE DE APK.

---

## 14/10/2026 · Cierre de golpe: primer registro del teléfono (2 cierres) + motivo del cierre según Android
- **Síntoma (dueño, con «COPIAR REGISTRO»):** dos cierres seguidos en Dream City con el R2 Turbo, contenido r171, Z2356 (Mali-G57), APK viejo (sin CrashGuard).
  Sesión 1: carga a los 83 s, **nunca aceleró** (0 km/h todo el tiempo), se cerró entre los 96 y 98 s. Sesión 2: carga a los 77 s, acelera a los 79 s, suelta a 37 km/h, se cerró entre los 85,6 y 87,6 s.
  En las dos el audio estaba en **SIMPLE** (sólo motor y golpes). FPS 32–36 estables, memoria de video 256 MB estable (no crece). El único error del motor es inofensivo (desconectar una señal que no existe).
- **Descartado con estos datos:** el acelerador (la sesión 1 se cerró quieta) y las voces/filtros de `car_audio.gd` (las dos con audio simple). La memoria de video no crece.
- **Hipótesis que quedan (sin confirmar):** (1) Android lo cierra por **falta de RAM** (el registro no medía la RAM del proceso: `MEMORY_STATIC` da 0 en Android); (2) **error nativo** del motor o del driver (los cierres empezaron el 14/10, al día siguiente de pasar a Godot 4.5.1); (3) algo que se arma 8–15 s después de cargar la ciudad (cuadras que se siguen armando: los nodos suben de 454 a 478 antes del cierre).
- **Cambio:** `game/diag/crash_log.gd`: `ram_line()` (RAM real del juego desde `/proc/self/status` y RAM libre del teléfono con `OS.get_memory_info()`) en cada línea; `_exit_reasons()`: tras un cierre de golpe le pregunta a Android (`ActivityManager.getHistoricalProcessExitReasons`, vía `AndroidRuntime`) el motivo de los últimos 3 cierres (falta de memoria / error nativo / ANR…, con la RAM que usaba). Si esa consulta llegara a cerrar el juego, la marca `exitinfo.try` impide repetirla. `race.gd`: una línea por segundo (antes cada 2 s).
- **Pruebas:** `crash_log_test`, `scripts_parse_test`. La consulta a Android sólo se puede probar en el teléfono.
- **Resultado:** PENDIENTE DE APK. **Siguiente paso:** el dueño juega hasta que se cierre, abre y pega «COPIAR REGISTRO»: la línea `[android] cierre 1: …` dice la causa. Si dice FALTA DE MEMORIA → bajar lo que ocupa RAM (modelo del auto, cuadras, texturas); si dice ERROR NATIVO → probar con el motor 4.4.1 (revertir la migración) o aislar el sistema con el 📊.
- **Leer la próxima vez:** esta entrada, `game/diag/crash_log.gd`.

---

## 14/10/2026 · Ciudades abiertas otra vez (pedido del dueño) + concesionarios con vidriera
- **Pedido:** «No vayas a cerrar las otras ciudades, total la policía ya es un obstáculo»; que los jugadores intenten ir, los atrape la policía en el tramo y vuelvan a Dream City; sólo un buen conductor con un auto muy rápido pasa. Además (prompt maestro): concesionarios con 3–4 autos reales del catálogo en vidrieras.
- **Cambios:** `game/data/sectors.json` → `open_all: true` (todo abierto: 79 carreras y 176 controles policiales; el sistema de sectores queda para usarlo cuando haga falta). `tests/sectors_test.gd` prueba el modo con sectores en obra forzándolo con `Sectors.force_open_all(false)` (nuevo: asignar `Sectors._open_all` desde otro script después de `reload()` no se aplicaba en Godot 4.5.1 y la prueba quedaba colgada tras un error).
  Concesionarios: `data/shops.gd` (`dealer_rally`, `dealer_classic`, `dealer_sport` con `cars` = lo que venden y `display` = los 3 autos de la vidriera; el general muestra 3 también), `city/city_layout.gd` (`DEALER_SPECS` + `_place_dealers()` después del estacionamiento, para no correr los números de las calles; `_place_poi` sale de `_place_pois`; la huella de un local con vidriera deja 3 m libres para que las fachadas no la tapen — antes el concesionario quedaba detrás de las fachadas genéricas), `city/city_world.gd` (`_box_building` abre la planta baja del frente; `_showroom`: salones con piso, techo, luces, vidrio y parantes, y 3 autos de verdad con el modelo liviano y la pintura de fábrica; `_display_car`), `ui/menu_garage.gd` (`dealer`: la tienda de un concesionario de especialidad sólo muestra su rubro), `ui/menu.gd` (se limpia al volver al inicio o a la calle).
- **Pruebas:** `scripts_parse_test` OK; `city_test` (11 locales: 4 concesionarios y 7 talleres); capturas `tests/city_shots.gd … 3` de los cuatro frentes revisadas a ojo (vidrio, autos adentro, portón en el medio).
- **Resultado:** PENDIENTE DE APK (¿se ven bien los autos en la vidriera?, ¿FPS al pasar por delante?).

---

## 14/10/2026 · Menú principal, Carrera rápida y menú online
- **Pedido:** AVENTURA y MODO ONLINE como accesos principales; Carrera rápida como zona de práctica (pistas, mapas, mundo abierto, Travesía X, Rutas); sacar los mapas «Prueba»; menú online más moderno y claro, sin botones de adorno.
- **Cambios:** `ui/menu.gd` (`_home`, `_quick_hub`, `menu_button` con tamaño de letra), `ui/menu_career.gd` (mapas `prueba_*` sólo en modo desarrollador), `ui/menu_world.gd` (`_online_hub` nuevo, `_tile_sub`), textos `b60_menus.py`. Detalle: `docs/MENU_PREMIUM.md`.
- **Pruebas:** `menu_ui_test` (pantalla Carrera rápida con sus 5 accesos) OK; `scripts_parse_test`, `release_test` OK; capturas del inicio y del menú online (sin conexión) revisadas.
- **No hecho (necesita permiso del dueño):** abrir el online (`Release.ONLINE_OPEN`) y prender `Release.REALTIME` (el lag que vio el dueño es la consulta de posiciones cada 2 s; con Realtime pasan a 3–5 por segundo y la consulta queda de respaldo). Las pruebas `realtime_test` y `remote_motion_test` pasan.
- **Resultado:** PENDIENTE DE APK.

---

## 14/10/2026 · Diseños de pintura, interiores y volantes comprables
- **Pedido:** nuevas pinturas comprables (competición, rojo y negro, carbono, dos colores, rally, nocturnos, metálicos, exclusivas de los autos nuevos, números) y texturas de interior y volante según el auto, cambiables en un taller; integrar el volante 3D del dueño.
- **Cambios:** `car_visual.gd` (patrones 12–19, emisión del neón, números en `models/paint/numbers.png`), `data/cosmetics.json` + `data/cosmetics.gd`, `cockpit.gd` (`_apply_interior`, colores del aro, Volante Pro 3D), `race.gd` (pasa interior/volante y limpia diseños no comprados), `menu_garage.gd` (solapas Interior y Volante, diseños exclusivos, barra de COMPRAR), `tools/cars/build_cabin_parts.py`, migración `20261015000000_catalog_28_cosmetics.sql` (+ autos police y strix en `online_cat_vehicles`). Detalle: `docs/PERSONALIZACION.md`.
- **El interior 3D de rally** (`biblioteca/modelos/cabina/interior_rally.glb`) **no se usó**: es un tablero con parantes de una sola medida; encajarlo en los 30 habitáculos distintos sin que atraviese pilotos y volante necesita un ajuste por auto que no se puede validar sin ver cada cabina. Queda guardado.
- **Pruebas:** `cosmetics_test` TODO OK; `menu_ui_test` (tres pantallas nuevas) OK; vistas de los 8 patrones y de 6 cabinas revisadas a ojo.
- **Resultado:** PENDIENTE DE APK. Migración aplicada por el dueño el 14/10/2026 20:26 UTC (flujo n.º 21: «Applying migration 20261015000000_catalog_28_cosmetics.sql… Finished», Local = Remote).

---

## 14/10/2026 · Sectores habilitados (bloqueo reversible del resto de la región)
- **Pedido:** dejar manejables Dream City y las salidas hacia la izquierda (montañas); el resto, visible en el mapa pero bloqueado para manejar y aparecer, de forma reversible.
- **Cambios:** `game/data/sectors.json`, `game/region/sectors.gd`, `game/city/city_sectors.gd` (barreras), filtros en `city_police.gd`, `world/ow_events.gd`, `ui/menu_world.gd` (aparecer) y `ui/city_hud.gd` (rayado en el mapa).
- **Pruebas:** `sectors_test` TODO OK (14 barreras, 7 lugares para aparecer abiertos, 20 carreras y 20 controles en el oeste, nadie pasa una barrera a fondo); `police_test` y `ow_events_test` prueban su lógica con todo abierto.
- **Resultado:** PENDIENTE DE APK. **Ojo:** con el bloqueo quedan 20 de las 79 carreras y 20 de los 176 controles (los del oeste); al abrir sectores vuelven solos.

---

## 14/10/2026 · Carreras para descubrir en el mundo abierto
- **Pedido:** convertir las calles y rutas del mundo abierto en carreras que se descubren recorriendo, que quedan en el mapa, con rivales que se adaptan y premios equilibrados; sin tocar Carrera rápida.
- **Sistema:** `game/world/ow_events.gd` (generador puro), `game/city/city_events.gd` (servicio), `ai/police_driver.gd` (modo «path» con `pace` y errores), `ui/city_hud.gd` (`marks` en el mapa y tocar para ir), `city_police.gd` (`suspended`, `event_chase`). Detalle: `docs/CARRERAS_MUNDO_ABIERTO.md`.
- **Problemas al probar:** los nodos de los pueblos sólo tocan sus calles (no salía ninguna carrera de ruta) → se buscan tramos cuyo cruce de afuera está a menos de 1,5 km; tipos sin declarar en GDScript (`var x := valor_sin_tipo`) rompían la compilación del script; el auto de prueba no tenía `police` (la Huida fallaba al instante).
- **Pruebas:** `ow_events_test` TODO OK (79 eventos de 8 tipos, largadas sobre la calle, recorridos continuos, descubrir, sprint de 4 km ganado con premio, medalla de montaña, repetir paga 35 %, Huida con arresto); `police_test` y `scripts_parse_test` TODO OK.
- **Resultado:** PENDIENTE DE APK (encontrarlas, largar, rivales, premios).

---

## 14/10/2026 · Policía en las rutas de la región (pedido del dueño)
- **Pedido:** controles policiales lejos de las ciudades; 2–3 patrulleros que cortan, chocan y se cruzan; casi imposible pasar; más difícil por cada ciudad cruzada; arresto → multa → comisaría de Dream City.
- **Sistema:** mundo abierto → servicio nuevo `game/city/city_police.gd` (registrado en `city_services.gd`), piloto `game/ai/police_driver.gd`, `race.gd` (`add_ai_car`, `remove_car`, `police.forget()` en `_rebuild_cars`), sirena `game/audio/samples/siren.wav`, textos `tools/i18n/batches/b57_policia.py`. Detalle: `docs/POLICIA.md`.
- **Problemas encontrados y corregidos al probar:** (1) los patrulleros «estacionados» con el freno apretado andaban marcha atrás (en esta física el freno sostenido con el auto parado es reversa) → freno de mano; (2) la velocidad por ángulo de volante topeaba a 140 km/h → radio de persecución pura `r = Ld / (2·sen α)`; (3) a 75 m dejaban el GPS y se metían contra la pared → 38 m; (4) al llegar a la cola daban vueltas → a menos de 7 m acompañan la velocidad; (5) un hiperdeportivo perfecto se escapaba siempre → barrera de dos patrulleros atravesados, interceptor de frente, más agarre y más empuje de lejos.
- **Pruebas:** `police_test` TODO OK (arresto en 6,5 s, multa, comisaría; el Veltor Max Pro GTR a fondo choca la barrera y lo arrestan; escape; nivel). `scripts_parse_test` y `open_world_access_test` TODO OK. Captura del juego real (pantalla virtual): arranca la persecución y se ve la barrera.
- **Resultado:** PENDIENTE DE APK (sensación de dificultad, FPS con 5 patrulleros, sonido de la sirena).
- **Leer la próxima vez:** `docs/POLICIA.md`, `city_police.gd`, `police_driver.gd`.

---

## 14/10/2026 · Cierre al acelerar: registro que no aparecía y diagnóstico que anda con cualquier APK
- **Síntoma (dueño):** el juego se sigue cerrando al acelerar; el audio se corta antes. En el teléfono **no aparece el botón «COPIAR REGISTRO»** de Acerca de.
- **Sistema:** diagnóstico / exportación. `game/ui/menu_about.gd`, `bootstrap/crash_guard.gd`, `game/race.gd`, `project.godot`, preset «Content» de `export_presets.cfg`.
- **Causa confirmada (botón que no aparece):** `menu_about.gd` hacía `preload("res://bootstrap/crash_guard.gd")`. El contenido descargado (`content.pck`) excluye `bootstrap/*` (preset «Content») y ese archivo sólo existe en el APK compilado desde el 14/10 (r165).
  Con un APK liviano anterior (el dueño no reinstala: el liviano baja el contenido solo) el script de Acerca de no compila → la pantalla no muestra el botón. Por la misma razón, con un APK viejo **no existían** el autoload `CrashGuard` (audio simple automático) ni el registro de archivo del motor (`[debug] file_logging` es de `project.godot`, que el contenido no cambia).
- **Cambio:**
  - `game/diag/crash_log.gd` (nuevo, va en el contenido): marca de sesión abierta (`user://diag/open.flag`) → detecta el cierre de golpe anterior; archivo por sesión `user://diag/s_<ms>.log` (se guardan 6) con `flush` en cada línea y tope de 40 líneas/s; captura mensajes y errores del motor con `OS.add_logger` (Godot 4.5); `report()` arma teléfono + memoria + sesión anterior + actual (+ `godot.log` si el APK nuevo lo escribe).
  - `app.gd`: crea el registro primero. `race.gd`: migas al cargar (tipo, pista, autos, memoria), al elegir el audio (simple/completo), al acelerar a fondo (velocidad + memoria), cada 2 s manejando (km/h, rpm, marcha, gas, memoria, video, FPS) y al salir (`_diag_tick`). El audio simple se activa con el registro del contenido también (antes sólo con el `CrashGuard` del APK).
  - `menu_about.gd`: el botón usa el registro del contenido (sin `res://bootstrap`). Segundo botón en **Opciones → Sonido**.
  - `tests/crash_log_test.gd` (nuevo, en la compilación): nada del contenido carga `res://bootstrap/`, detección del cierre de golpe, flush, errores del motor, informe, rotación. `menu_ui_test`: el botón está en Acerca de y en Opciones → Sonido y copia.
- **Pruebas ejecutadas (computadora, Godot 4.5.1):** `crash_log_test` TODO OK; `scripts_parse_test` TODO OK (180 scripts); `menu_ui_test`: los 4 controles nuevos OK. `menu_ui_test` tiene 4 fallas de «cámara libre» que **ya fallaban antes** de este cambio (comprobado con `git stash`; el arrastre táctil simulado no llega en modo sin pantalla).
- **Causa del cierre: NO confirmada.** Hipótesis abiertas (sin evidencia): memoria (autos de 300 mil a 1 millón de triángulos sin reducir, `cars.pck` ~600 MB), partículas GPU del humo al patinar (`fx/effects.gd`, GPUParticles3D en GL Compatibility) o una voz/filtro de `car_audio.gd`.
- **Resultado:** RESUELTO el botón y el registro; PENDIENTE DE APK el diagnóstico del cierre.
- **Siguiente paso con evidencia:** el dueño juega hasta que se cierre, vuelve a abrir, toca «COPIAR REGISTRO» y lo pega. Mirar la última línea `[auto]`/`[gas]`: si la memoria (`mem`/`video`) sube hasta el cierre → memoria; si hay `ERROR` del motor justo antes → seguir ese error; si se corta en `[gas] a fondo` con la memoria estable → probar partículas en CPU.
- **Leer la próxima vez:** esta entrada, `game/diag/crash_log.gd`, `race.gd` (`_diag_tick`), `docs/AUDIO.md` (audio simple).
