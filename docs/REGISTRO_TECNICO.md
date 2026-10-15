# Registro técnico de intervenciones

Una entrada por intervención, la más nueva arriba. Antes de tocar un sistema, buscar acá su nombre: si el problema ya se trabajó, seguir desde el último diagnóstico.
Resultado: RESUELTO · PARCIAL · FALLIDO · BLOQUEADO · PENDIENTE DE APK. Una hipótesis no es una causa confirmada.

---

## 15/10/2026 (14) · Online de EVENTOS DE CLASIFICACIÓN: el servidor como gestor de eventos y premios
- **Pedido del dueño:** «hasta Supabase Pro (1/11), el juego es de eventos de clasificación: cada uno en su mapa contra la IA, sus registros al servidor. No modos en
  la pausa: eventos del mundo que manda el servidor (cacería de las 22 con 3 autos; fuga de 10 min → auto de policía 3 días; llegar a una ciudad con 3 intentos →
  $20.000…), premios justos; eventos al azar no muy seguidos; la policía y los controles mezclados con los eventos; récord de cada carrera del mapa; dejar listo
  para subir y avisar que el tiempo real viene pronto».
- **Servidor** (`20261020000000_world_events.sql`): `wev_cfg`, `wev_templates` (6 de fábrica), `wev_events`, `wev_runs`, `wev_winners`; `_wev_ensure` (programa al azar
  según peso y descanso, hora fija en UTC, hasta 4 abiertos), `_wev_close` (paga a los 3 primeros de la carrera de la semana), `events_current`, `event_start`,
  `event_finish` (valida por tipo con la hora de inicio del intento, cupos, uno por auto en la cacería, cooldown de 7 días), `event_board`, `event_winners`,
  `event_admin_schedule`; `_wev_grant` (créditos, auto, alquiler); `_acct_row` borra los autos alquilados vencidos. Apaga la programación de la recompensa
  vieja (`bounty_cfg.auto`). Autoprueba al aplicar. Sintaxis revisada con `pglast`.
- **Cliente:** `city_modes.gd` reescrito como cliente de los eventos (sin modos en la pausa: un botón «📅 EVENTOS EN VIVO»); `city_police.gd` (`checkpoint_near`,
  control que se suma a la persecución), presa que pasa un control → te persigue la policía; cada escape paga; `city_events.gd` (récord mundial y tu mejor tiempo
  en el cartel de cada carrera, carrera de la semana); `account_econ.gd` (marca `until` de los alquilados); `menu_world.gd` (EVENTOS EN VIVO, ganadores en el
  ranking); `menu.gd` («eventos y ranking · tiempo real pronto»); `race_hud.gd` (un solo botón en la pausa).
- **Docs:** `docs/ONLINE_POR_EVENTOS.md` (texto para el dueño + checklist para subir), `docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md` (panel), `docs/MODOS_MUNDO_ABIERTO.md`.
- **Pruebas:** `city_modes_test` (reescrita, servidor falso en memoria), `scripts_parse_test`, `release_test`, `language_test`, `police_online_test`,
  `account_econ_test`. Sin pruebas con red. (`menu_ui_test` falla en esta máquina en «cámara libre: arrastrar» también con el commit verde 510ffa7: es del entorno
  local, en la compilación anda.)
- **Migración 20261019 FALLÓ al aplicarse** (flujo n.º 29, 16:56 UTC: `malformed array literal: "notice_min"`). Causa: Postgres crea solo el tipo `_bounty_cfg`
  (arreglo de la tabla `bounty_cfg`), y `public._bounty_cfg('notice_min')` se leía como conversión a ese tipo, no como la función. No se aplicó nada (la
  migración es repetible). Arreglo: la función pasa a llamarse `_bounty_conf`; lo mismo en 20261020 (`_wev_cfg` → `_wev_conf`). `pglast` sólo revisa la
  sintaxis, no estos choques de nombres: no nombrar funciones `_<tabla>`.
- **Migraciones 20261019 y 20261020 APLICADAS:** 15/10/2026 17:28 UTC, flujo n.º 32, sin errores (la autoprueba de 20261020 programó los primeros eventos;
  si hubiera fallado, se deshacía todo).
- **Resultado:** servidor listo; cliente PENDIENTE DE APK (probar en el teléfono).

## 15/10/2026 (13) · Online «por datos» (sin tiempo real), recompensa global con un solo ganador, ranking
- **Pedido del dueño:** «hasta pagar Supabase Pro, nada de tiempo real ni de encontrarse: el servidor para la cuenta, la plata, los autos, los eventos y el ranking;
  al entrar al mundo online, un aviso de «próximamente»; habilitarlo con un botón». «La recompensa: aparece un rato en el mapa, gana uno solo, el que se pega lo que
  dice el servidor (un minuto); la IA muy buena, se hace la boluda a mitad de barra». «Ranking: quién ganó la persecución, la recompensa, los récords de las carreras».
- **Servidor** (`supabase/migrations/20261019000000_bounty_event_ranking_flags.sql`): `app_flags` (`pvp` = false) + `app_flags()`; recompensa: `bounty_cfg`, `bounty_events`,
  `bounty_joins`, `bounty_claims`, `bounty_current` (programa sola la próxima), `bounty_join`, `bounty_claim` (el primero gana, le da el auto a la cuenta),
  `bounty_winners`, `bounty_admin_schedule` (sólo desde el panel); cierra `give_car` «bounty»; ranking: tableros `owev` y `fugitive` en `scores`, `submit_record`,
  `get_leaderboard` ordena la racha de mayor a menor. Sintaxis revisada con `pglast` (no se levantó la base).
- **Cliente:** `release.gd` (`PVP_FORCE`, `pvp_remote`, `pvp_open`), `online.gd` (`fetch_flags`, `submit_record`), `menu_world.gd` (`_data_hub`, `pvp_soon`, `ranking`, `bounty_screen`;
  `_start_city` no entra al mundo compartido sin `pvp_open`), `menu.gd` (rutas), `city_modes.gd` (recompensa del servidor en vez del «1 por día» local; récord del Fugitivo),
  `city_events.gd` (récord mundial al terminar una carrera del mundo abierto; guarda el nombre para el ranking).
- **Pruebas:** `city_modes_test` (reescrita: 23 comprobaciones, servidor falso en memoria), `scripts_parse_test`; capturas del aviso «PRÓXIMAMENTE». Sin pruebas con red.
- **Guía:** `docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md` (programar y configurar la recompensa, revisar ganadores, habilitar el tiempo real con `app_flags.pvp`).
- **Límite honesto:** el servidor no ve la persecución (cada uno en su mundo): protege con join + tiempo mínimo, un ganador por evento, uno cada 7 días por cuenta y el recorrido guardado.
- **Resultado:** PENDIENTE DE APK y de aplicar la migración.

## 15/10/2026 (12) · Volante «girado», desmadre con la policía, modos Fugitivo y Caza recompensas
- **Volante (reporte del dueño: «se giró sobre su eje vertical, la izquierda más adelante»):** el volante estaba derecho (mira al piloto); la cámara de casco miraba 4,3° (0,075 rad) hacia la ventanilla y con la lente ancha el aro se veía girado. **Cambio:** `cockpit.camera_local` mira derecho al frente (sigue girando con el volante y el derrape). Comparado en capturas antes/después.
- **Desmadre** (`city/city_police.gd`, `race.gd`): choques fuertes, objetos rotos y velocidad en la ciudad llenan un medidor; lleno → cacería policial donde estés. Detalle: `docs/MODOS_MUNDO_ABIERTO.md`.
- **Modos** (`city/city_modes.gd` nuevo, `city_services.gd`, `ui/race_hud.gd` pausa, `ui/city_hud.gd` `set_dest(…, quiet)`): FUGITIVO (cada escape paga, la racha sube el nivel) y CAZA RECOMPENSAS (pegado 30 s a un auto de la IA que huye → es tuyo). Sólo sin conexión.
- **Servidor:** migración `20261018000000_bounty_car.sql` (`give_car` motivo «bounty»: sin premium/aventura/especiales, ≤ $150.000, 1 cada 20 h). Sintaxis revisada con `pglast`; no se levantó el Postgres local (pedido del dueño).
- **Pruebas:** `city_modes_test` (nueva, en el CI: 22 comprobaciones), `police_test`, `police_online_test`, `scripts_parse_test`; capturas de la pausa con los botones y de la caza en el juego real.
- **Resultado:** PENDIENTE DE APK.

## 15/10/2026 (11) · Tanda de pendientes del dueño: peatones, lluvia bajo techo, faros, capó, policía online, fotos
- **Pedidos (anotados antes):** gente sólo en plazas (chicos jugando, paseando, cercadas) y algunos en el concesionario limpiando autos; que no llueva adentro (estacionamiento); faros que «alumbran poco y salen debajo/detrás del auto»; capó «arrugado» desde la cámara interior; policía online compartida e inteligente; fotos Full HD de cada mejora; rutas mal unidas / pasto en caminos / puentes. El dueño pidió NO correr más pruebas online ni levantar servidores: no se corrieron.
- **Peatones** (`world/ambient_peds.gd`, `city/city_layout.gd`, `city/city_props.gd`): las veredas quedan sin gente (`SIDEWALKS = false`, el código queda); en la Plaza Aurora 20 paseantes (r 25–33 m) y 14 chicos (más bajos, corren de un lado a otro, r 16–24 m) adentro de una **reja baja nueva** (`PFENCE`, 36 tramos de 6 m, 4 entradas frente a las avenidas de 45°); dos personas «lavando» frente a la vidriera de cada concesionario (8). Siguen siendo deterministas (todos ven a la misma gente) y dependen de la hora y la lluvia. Prueba: `ambient_peds_test` (reescrita: nadie en veredas ni asfalto, chicos, lavadores).
- **Lluvia bajo techo** (`fx/weather_drop.gdshader`, `fx/weather.gd`, `CityLayout.rain_covers()`, `race.gd`): lista de techos (3 salas del estacionamiento, rampas y túneles en rectángulos de ≤ 16 m, techo de cada gasolinera); el clima le pasa al shader los 16 más cercanos cada 0,3 s y cada gota/salpicadura que cae debajo se descarta en el vértice (4 vértices por gota: barato). Las salpicaduras usan el mismo shader. Prueba nueva `rain_cover_test` (en el CI); compilación del shader verificada con OpenGL.
- **Faros** (`city/city_clock.gd`, `race.gd`): **causa:** el haz nacía a 2,2 m del centro en TODOS los autos (en los largos debajo del capó; el charco desde 1,5 m, debajo del auto) y se acomodaba antes de mover el auto en el cuadro (a 100 km/h ~1 m atrás). **Cambio:** nace en la trompa de cada auto (eje delantero + 0,9 m), 42 m de largo, más ancho, intensidad 0,55 → 0,85, y `place_beam()` lo acomoda después de `update_visual`. Visto en capturas de noche antes/después.
- **Capó desde la cabina** (`car/car_visual.gd`): con los modelos sin reducir, las ondas finas de la malla brillaban como chapa arrugada a un metro. Sólo en el material de la vista interior: las caras de arriba toman la normal «vertical» del auto (85 %) y el brillo es más suave. Comparado en capturas antes/después (Génesis: desaparecen las vetas).
- **Policía online** (`city/city_police.gd`, `online/police_net.gd` nuevo, `online/remote_cars.gd`, `race.gd`; detalle en `docs/POLICIA.md` → «Online»): 2 patrulleros por jugador fuerte (1 los demás), implacable con 3+ jugadores juntos, para 1–2: aviso + pasar a < 60 km/h + abandonan a los ~2,5 km; los patrulleros de cada uno se ven en los otros teléfonos por Realtime (evento «p», 2 Hz, sólo en persecución y con otro jugador en la celda). Sin conexión, igual que antes (la prueba de siempre pasó entera). Pruebas: `police_online_test` (nueva, en el CI), `police_test`. **No se probó con red** (pedido del dueño).
- **Rutas / pasto:** medido con `region_terrain_test` (0 puntos tapados en 41.905, 3 niveles) y `region_junction_test` (530 cruces parejos, 0 escalones): en la región no aparece. Hace falta que el dueño diga DÓNDE lo ve (captura + 📍). Puentes / pasos a distinto nivel: no hechos (cambio grande del generador del mapa).
- **Herramienta de fotos** (`tests/trailer/director.gd`): `cam: {"game": true}` (cámara del juego), `tp: {x, z, yaw}` en ciudad/región, `police: nivel` (persecución) y `env.wx` (clima).
- **Resultado:** PENDIENTE DE APK.

## 15/10/2026 (10) · Concesionarios: cada uno con su rubro y 4 versiones de cada auto
- **Pedido del dueño:** «si voy a un concesionario no debe mostrar todos los autos, es según el concesionario»; «3 o 4 del mismo modelo con distintos ajustes y pinturas: con llamas más caro, con más caballos más caro, pintura premium más cara».
- **Cambio:** `shops.gd`: el Concesionario Dream City ahora vende sólo autos de calle (12); Rally & 4x4, Clásicos y Motorsport ya tenían su lista (la TIENDA del menú sigue con todos). `game/data/dealer_variants.gd` (nuevo): cada auto en 4 versiones — DE FÁBRICA · SPORT (motor 1, susp./frenos 1, gomas, dos tonos) · PREPARADO (motor 2, turbo 1, caja 1, susp./frenos 2, pintura de competición) · LLAMAS (motor 3, turbo 2, caja 2, aligerado, susp./frenos 3, llamas); el diseño y las gomas cambian según el rubro (tierra: ripio y diseños de rally; Motorsport: slicks y carbono). Precio = auto + lo que cuestan esas piezas en el taller (p. ej. GT: $72.000 / 516 cv → LLAMAS $151.500 / 748 cv). Al comprar se hace cada compra de siempre, así la cuenta del servidor la valida igual. `menu_garage.gd`: fila de versiones en la tienda (la sala y los números muestran la versión). En el online, sólo la de fábrica (las mejoras se hacen en cada taller).
- **Pruebas:** `dealer_variants_test` (nueva, en el CI), capturas de la tienda a 2400×1080.
- **Resultado:** PENDIENTE DE APK.

---

## 15/10/2026 (9) · Optimización automática más potente: opción 60 FPS y recomendada ≥ 40 FPS
- **Pedido del dueño:** «primero la recomendada, que corra a más de 40 FPS; también una opción de 60 FPS que reduzca todo hasta correr a 60 aunque se vea pixelado; después las demás con sus FPS (normal 30, alta 20…). Entre 40 y 60 vamos a estar».
- **Cambio:** `autotune.gd` (5 calidades, búsqueda nueva, `presets_for`, `preset_info`, `preset_order`, `VERSION` 3 → todos miden una vez), `calibration.gd` (aplica la escala calculada y la vida del mundo de la 60 FPS), `calib_ui.gd` (orden), `menu.gd`. Detalle en `docs/CONFIGURACION_GRAFICA_AUTOMATICA.md` → «Versión actual».
- **Pruebas:** `autotune_test` (62 comprobaciones), calibración real en la PC (`_calib_run.gd`: 6 mediciones, terminó en la 60 FPS sin tránsito; la PC del contenedor está topeada a 20 FPS, así que sus números no sirven para el teléfono).
- **Resultado:** PENDIENTE DE APK (¿qué recomienda en el Z2356?, ¿la 60 FPS llega a 60?, ¿cuánto tarda?).
- **Además:** policía con modelo de patrullero por nivel (`city_police.gd` → `BY_LEVEL`, hoy todos «police»), listo para sumar los autos nuevos del dueño.

---

## 15/10/2026 (8) · Online: compras que «volvían», concesionarios nuevos y garaje online
- **Reporte del dueño:** «compré autos y una camioneta y el modo online no me deja elegirlos, tengo que volver a comprarlos»; «compraba, se descontaba y al rato volvía y me decía que ese no era el lugar para realizar eso, pero me dio una camioneta».
- **Causa (confirmada en el código y con la prueba):** (1) la compra SÍ se cobraba en el servidor; justo después el cliente veía una diferencia de pintura entre su espejo y el auto recién comprado y mandaba `online_set_paint` desde el concesionario → el servidor contestaba «este trabajo no se hace en ese local» → el cliente volvía a pedir el saldo real (de ahí el «volvía»). (2) Los 3 concesionarios nuevos (Rally & 4x4, Clásicos, Motorsport) no estaban en `online_cat_shops` y `online_buy_vehicle` sólo aceptaba `'dealer'`. (3) No había garaje online en el menú y los autos de la cuenta (juego sin conexión) no pasaban al online. (4) Al entrar al online se elegía el auto del juego sin conexión si el online también lo tenía.
- **Cambio:** migración `20261017000000_online_garage_dealers.sql` (concesionarios nuevos; compra en cualquier `dealer*` estando en ese local; garaje de 40; tabla `online_imports` + `_online_import_account`: los autos de `account_econ.cars` aparecen UNA vez en el garaje online, y si se venden en el mercado no vuelven gratis). Cliente: `online_profile.gd` manda el concesionario donde está el jugador, adopta la pintura del servidor después de comprar y compara lo que el servidor no guarda con el color de fábrica; recuerda el auto elegido online. `menu_world.gd`: pantalla «MI GARAJE ONLINE» (`ogarage`) desde el hub online, y la tarjeta del piloto muestra el auto online.
- **Pruebas:** `tools/online/run_economy_test.sh` (todas las migraciones en Postgres 16, repetidas dos veces; 7 casos nuevos), `online_profile_test` (4 casos nuevos: reproducía la pintura rechazada antes del arreglo).
- **Resultado:** PENDIENTE DE APK.

---

## 15/10/2026 (7) · Optimización automática nueva: mide las calidades y recomienda
- **Pedido del dueño:** «volver a la optimización automática para correr mejor según el dispositivo; aplicá la forma mejor que dijiste».
- **Cómo funciona:** la primera vez (o con otro teléfono, o tras subir `Autotune.VERSION` a 2 → todos miden una vez) aparece el aviso y una carrera corta en el centro de Dream City (`calibration.gd`) mide como mucho 3 calidades: ALTA → si es fluida ULTRA, si no NORMAL → si no BAJA (`Autotune.PresetSearch`). «Fluida» = promedio ≥ 75 % del objetivo (45 FPS en 60 Hz) y el 95 % de los cuadros ≥ 50 % (30 FPS). Al terminar se abre la pantalla de elección con la ★ **recomendada** (la más alta fluida; si ninguna, BAJA) y los FPS medidos; el jugador elige (`save_preset` guarda la elegida y lo medido en `gfx.auto`). En Opciones → Gráficos → «ELEGIR CALIDAD GRÁFICA» se ve lo último medido y está «📏 MEDIR AUTOMÁTICAMENTE». El frame reducido sigue apagado; la escalera vieja de 8 escalones queda en el código sin uso.
- **Pruebas:** `autotune_test` (+ 5 casos de la búsqueda y que se guarde lo medido), `scripts_parse_test`, `language_test`; la medición real en la PC de punta a punta (`tests/_calib_run.gd`: midió ALTA, NORMAL, BAJA, recomendó BAJA con ~20 FPS de la PC, al tocar la ★ quedó guardada y no vuelve a preguntar).
- **Resultado:** PENDIENTE DE APK (¿cuánto tarda en el Z2356?, ¿qué recomienda?).

---

## 15/10/2026 (6) · Interior: sólo el tablero clásico
- **Pedido del dueño:** «vamos a usar sólo el interior clásico, el PNG se ve feo y el 3D también; luego mejoramos ese interior aparte, es liviano y optimizado».
- **Cambio:** `cockpit.gd` arma siempre el tablero clásico (se borraron `_b_dash_model`, `_b_dash_image`, la opción «Tablero de la cabina», `cabDash` del perfil, `models/cabin/tablero_rally.glb` + su textura, `tablero_imagen.png` y `cabin_dash_test`). Las herramientas `tools/cars/build_cabin_dash.py` y `build_dash_image.py` quedan por si se retoma. Se mantienen el Volante Pro 3D y la pantallita digital.
- **Pruebas:** `scripts_parse_test`, `cabin_shake_test`, `cosmetics_test` OK.
- **Resultado:** PENDIENTE DE APK.

---

## 15/10/2026 (5) · Migración de `main` a Godot 4.7.2
- **Decisión del dueño** tras probar la rama experimental en el Z2356: pasar ahora y no con el juego ya publicado. Ventajas verificadas: rama mantenida, API 36 de fábrica (la exige Play desde el 31/08/2026), NDK r29/build-tools 36, parches de PCK por diferencias (4.6+, para usar después). Sin ventajas de rendimiento anunciadas para Compatibility.
- **Cambio:** `build-godot.yml`, `build-aab.yml`, `project.godot` (ver `docs/MIGRACION_GODOT.md`). Local: el proyecto importa con 4.7.2 sin errores; las 74 pruebas ya habían pasado con 4.7.2 (15/10).
- **Resultado:** PENDIENTE DE APK (reinstalar una vez). Retorno: `704a513`.

---

## 15/10/2026 (4) · CAUSA CONFIRMADA de los cierres: bucles de sonido que leían fuera de los datos · y autos que largaban marcha atrás
- **Evidencia (lápida del Z2356, contenido r188 / Godot 4.5.1, igual en r189 / 4.7.2, «en cualquier modo de juego»):** `SIGSEGV (11) · SEGV_ACCERR · dirección 0x6ff0ca8000 · hilo «AudioTrack»`; cuadros `libgodot_android.so +2ad01cc / +3227528 / +303dbd4 / +303b9d8 / +1114894` ← `libwilhelm.so audioTrack_handleMoreData_lockPlay` ← `libaudioclient.so AudioTrack::processAudioBuffer`. Con los símbolos oficiales de Godot 4.5.1 (`Godot_native_debug_symbols.4.5.1.stable.template_release.android.zip`, mismo build-id `51ca91226c11fafc`, `llvm-symbolizer`): `AudioStreamPlaybackWAV::decode_samples<short,false,false,false>` (audio_stream_wav.cpp:193 `final = p_src[pos]`) ← `_mix_internal` ← `AudioStreamPlaybackResampled::mix` ← `AudioServer::_mix_step` ← `AudioDriverOpenSL::_buffer_callback`.
- **Causa (confirmada en el código del juego y del motor):** Godot reproduce un bucle hasta la muestra `loop_end` INCLUSIVE y no limita `loop_end` al largo de los datos (su importador lo deja en «muestras − 1»). `car_audio._load_wav`, `world_ambient` (2 lugares) y `city_police._siren_on` ponían `loop_end = muestras` → en cada vuelta de cada bucle (motor, rodado, viento, lluvia, ambiente, sirena) se leía UNA muestra después del final. Casi siempre esa memoria existe; si los datos terminaban justo en el borde de una página (dirección terminada en `000`), SIGSEGV. Por eso: al azar, en cualquier modo, con los dos motores, también quieto y con «audio simple», y no se veía en la PC. (Con eso se descartan como causa el frame reducido, la calibración y la memoria; esos cambios quedan porque igual corrigen defectos reales.)
- **Cambio:** `game/audio/wav_loop.gd` (nuevo): `WavLoop.make(w, muestras)` agrega al final una copia de la primera muestra y pone `loop_end = muestras` → Godot toca esa copia y sigue desde la 1: bucle exacto, sin salto, sin leer afuera. Lo usan los 4 lugares; la sirena ahora trabaja sobre una copia (antes modificaba el recurso compartido).
- **Marcha atrás al largar (reporte del dueño, «en ningún tipo de carrera ni con ningún auto»):** en la cuenta regresiva `race.gd` tiene al jugador con freno a fondo + freno de mano; la caja automática (`vehicle_physics._sub`) pasaba a reversa a los 0,35 s de estar frenado y parado y en reversa el freno es el acelerador → el auto se iba para atrás (registro: `-1ª · 6992 rpm · gas 0.0`, 2→11 km/h). **Cambio:** no pasa a reversa con el freno de mano puesto; frenar parado sin freno de mano sigue poniendo reversa.
- **Pruebas:** `wav_loop_test` nueva (41 sonidos: el bucle termina dentro de los datos y es exacto; el bucle viejo se detecta inseguro; ningún script pone `loop_end` a mano), `start_hold_test` nueva (los 30 autos: 4 s de largada + 2 s sin tocar nada → ni reversa ni movimiento; con el código viejo fallaban todos; la reversa a propósito sigue andando), `physics_test`, `cars_test`, `ai_test`, `ai_route_test`, `drift_test`, `wall_test`, `practice_test`, `audio_levels_test`, `controls_test`, `scripts_parse_test` OK. Las dos nuevas, en GitHub.
- **Resultado:** RESUELTO en el código / PENDIENTE DE APK (confirmar en el teléfono que no se cierra más).

---

## 15/10/2026 (3) · La calibración se sigue cerrando (antes de bajar nada) → elección MANUAL de la calidad (BAJA / NORMAL / ALTA / ULTRA)
- **Reporte del dueño (captura):** con r186/r187 las dos versiones se cierran igual en «OPTIMIZANDO RENDIMIENTO…»; la captura muestra «Resolución: detectando…» y el reloj en 0:01.50. **Corrección del diagnóstico anterior:** el cierre es ANTES del primer escalón, en `calibration._setup()` (a los 1,5 s de cargar: arma de golpe el centro de Dream City con `world_node.warm()`, ubica el auto, fija clima y hora) → el frame reducido NO era el disparador de la calibración (sigue apagado: no hace falta para jugar). La causa exacta la tiene que dar la lápida.
- **Pedido del dueño:** «solucioná esto o si no hay forma, que el ajuste sea manual: una pantalla que me deje elegir baja, normal, alta y ultra».
- **Cambio:** `autotune.gd` → `PRESETS` (BAJA 50 % / NORMAL 67 % / ALTA 80 % con sombras / ULTRA 100 %), `save_preset()`, `suggested_preset()` (según la GPU); `calib_ui.pick()` (pantalla nueva con las 4 y la sugerida marcada); `menu.request_calibration()` ya no corre la carrera de calibración: muestra la elección (la primera vez y desde Opciones → Gráficos → «ELEGIR CALIDAD GRÁFICA»). Queda en «Automática» con esos ajustes y cada opción se sigue pudiendo cambiar a mano. La calibración automática queda en el código, sin uso. Textos en 5 idiomas (b65).
- **Pruebas:** `autotune_test` (+ las 4 calidades: se guardan, quedan en Automática, frame 100 %, no se vuelve a preguntar), `scripts_parse_test`, `language_test`; la pantalla se abrió en la PC con el menú real (`tests/_pick_shot.gd`): elegir NORMAL guarda el perfil y no vuelve a preguntar.
- **Defecto encontrado en el mismo paso (confirmado en el código):** la física de los autos corre en hilos (`race._step_physics` lanza `_step_car` en el WorkerThreadPool) **en paralelo con el resto del cuadro**, y `calibration._setup()` llama `cars[0].place()` (reescribe toda la física del auto y su «foto») mientras un hilo puede estar calculando ese mismo auto. Lo mismo hacen la policía (arresto), los portones de talleres (`city_shops`, `city_links`), los eventos del mundo abierto, la aventura y la eliminación. Dos hilos escribiendo el mismo objeto de GDScript (con arreglos adentro) es una causa clásica de SIGSEGV. Agregar o sacar autos ya esperaba a la física (`add_ai_car`/`remove`), mover no. **Cambio:** `Car.place()` primero espera los hilos de la física de ese cuadro (`Car.set_sync_hook(race.sync_physics)`, sólo desde el hilo principal). Sin confirmar que sea LA causa (falta la lápida), pero es un defecto real en el instante exacto del cierre de la calibración.
- **Pruebas del cambio:** `police_test`, `ow_events_test`, `city_test`, `drift_test`, `region_threads_test`, `adv_route_test`, `travesia_test --km=10.5`, `open_world_access_test`, `ai_route_test`, `scripts_parse_test` salida 0; calibración real en la PC de punta a punta.
- **Resultado:** PENDIENTE DE APK. Si el juego se cierra al entrar a Dream City (el mismo armado del centro): «COPIAR REGISTRO» → líneas `[lápida]`.

---

## 15/10/2026 (2) · La calibración se cierra en las dos versiones (4.5.1 y 4.7.2) al bajar la resolución → frame reducido APAGADO
- **Reporte del dueño (captura de «OPTIMIZANDO RENDIMIENTO…»):** «las 2 versiones se cierran acá: baja las resoluciones y se cierran las 2 APK». Es lo mismo que en el otro teléfono.
- **Evidencia junta:** (1) los 3 cierres en carrera del 14/10 tenían el frame reducido activo (el error `child_order_changed` sólo aparece con él); (2) la calibración se cierra justo al activar/cambiar ese frame, en dos teléfonos y **con los dos motores** (no es la versión de Godot); (3) en la PC (Mesa) la calibración completa pasa por 4 niveles de frame sin cerrarse (`tests/_calib_run.gd`, herramienta nueva que corre la calibración real). Conclusión: el disparador es el frame reducido (una SubViewport 2D que redibuja todo, con la SubViewport 3D adentro) en el driver del teléfono. La línea exacta del motor/driver la dará la lápida.
- **Cambio:** `ui/frame_res.gd` → `FrameRes.set_enabled(false)` por defecto: `set_level()` siempre deja NATIVA y no se redirige ninguna capa; `race._frame_level()` devuelve 0; Opciones → Gráficos ya no muestra «Resolución de frame»; el 📊 de desarrollo la puede volver a encender para medir. La calibración y el perfil siguen igual pero lo que baja es la **ESCALA 3D** (el mundo 3D a 80/67/50/40 %; el HUD queda nítido). La calibración muestra esa resolución y anota cada escalón en el registro (`[calib] escalón … · frame · escala 3D · sombras · texturas · partículas · árboles`).
- **Pruebas:** `frame_res_test` (+ caso «apagado»), `autotune_test`, `scripts_parse_test` OK; calibración real en la PC de punta a punta con el frame en 0 en todos los escalones.
- **Resultado:** PENDIENTE DE APK. **Siguiente paso:** abrir el juego (baja el contenido nuevo solo), dejar terminar la calibración y jugar Aurelia / Quarry / drift. Si se cierra igual: «COPIAR REGISTRO» → las líneas `[lápida]` y la última `[calib]` dicen dónde.

---

## 15/10/2026 · Migración de los volantes aplicada y modo online ABIERTO (autorización del dueño)
- **Pedido del dueño:** «aplicá la migración y abrí el online, te autorizo todo hasta que ande bien el juego».
- **Migración:** flujo «Supabase · aplicar migraciones» n.º 23 (a mano, 15/10/2026 01:38 UTC): aplicó `20261016000000_cosmetics_volantes_pro.sql` sin errores; la lista final muestra las 13 migraciones en el servidor (local = remoto).
- **Online:** `game/data/release.gd` → `ONLINE_OPEN := true`, `REALTIME := true` (las dos únicas líneas que había que cambiar según `docs/ONLINE_SUPABASE.md`). `release_test` ahora comprueba que esté abierto.
- **Pruebas (acá):** `release_test`, `realtime_test`, `remote_cars_test`, `remote_motion_test`, `online_profile_test`, `login_wall_test`, `account_econ_test`, `net_test`, `spawn_menu_test`, `scripts_parse_test` salida 0 sin fallas. (`menu_ui_test` «cámara libre» falla sólo en este entorno desde antes; en GitHub pasa.)
- **Falta (no se puede desde acá):** Supabase → Realtime → Settings → «Allow public access» = OFF y revisar los topes del plan; Play Console → Seguridad de los datos; prueba con 2 teléfonos.
- **Resultado:** PENDIENTE DE APK (contenido r184+; no hace falta reinstalar el APK para esto).

---

## 15/10/2026 · Cierres nativos (prompt maestro del dueño): lápida de Android, capas del frame reducido, descarga 13/0 y evaluación de Godot
- **Evidencia del dueño (contenido r180, Z2356, Mali-G57, Android 13 (el registro dice «33.20241128…»: Godot informa el nivel de API, 33), APK con CrashGuard):** 12 cierres de golpe seguidos; Android los clasifica `ERROR NATIVO (código 5, estado 11)` = `ApplicationExitInfo.REASON_CRASH_NATIVE` con señal 11 (SIGSEGV); RSS 567–664 MB, PSS 432–528 MB **en el momento de morir** (`getRss`/`getPss`). Ya no es «sólo el mundo abierto»: también en carrera rápida (Quarry, 4 autos) y en drift. En las tres cargas aparece, ~0,3 s después de «carrera cargada», `Attempt to disconnect a nonexistent connection from 'App' … Signal: 'child_order_changed'`. En otro teléfono: la descarga falla con «Falló la descarga (13/0)» con buen wifi, y la calibración se cierra al pasar a una resolución de frame más baja.
- **Qué mide el registro (`game/diag/crash_log.gd`):** «RAM juego» = VmRSS de `/proc/self/status` (en el Z2356 sale «?»: Android no deja leerlo así); «libre … de …» = `OS.get_memory_info()` (también «?» en ese teléfono); «video»/«tex» = estimación del motor de la memoria de video/texturas (`RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED`), no memoria del proceso; la línea `[android]` viene de Android (`getHistoricalProcessExitReasons`: motivo, estado = número de señal, RSS/PSS en kB). **Memoria descartada como causa directa:** Android no lo cerró por memoria (el motivo sería 3 = LOW_MEMORY) y el PSS al morir (430–530 MB) no muestra un crecimiento hasta el cierre.
- **Historial (git):** antes de 4.5.1 el motor era 4.4.1; la migración es `8ec1ef6` (13/10/2026 08:50). Los primeros cierres registrados son del 14/10 (r171), pero el registro de cierres recién existe desde el 14/10: **no se puede afirmar que empezaron con la migración**. En el medio entraron muchos cambios (cabina 3D, audio por capas, región, policía…). `frame_res.gd` (RESOLUCIÓN DE FRAME) es anterior a la migración (b849178, 12/10).
- **A. Señal `child_order_changed` — causa CONFIRMADA (código del motor 4.5.1 leído):** `CanvasLayer` conecta `child_order_changed` del padre con el viewport en el que ENTRA al árbol y al salir desconecta con el viewport que tenga EN ESE MOMENTO (`scene/main/canvas_layer.cpp`, ENTER/EXIT_TREE y `set_custom_viewport`). `ui/frame_res.gd` redirige todas las capas a su SubViewport (`custom_viewport`), incluida la pantalla de carga (`ui/loading.gd`, hija de `App`): al terminar de cargar, `app.gd` la borra todavía redirigida → el error. **Ese error en sí no rompe memoria** (la desconexión no hace nada y el viewport guarda los padres por ObjectID). **Pero el mismo mecanismo SÍ puede romperla:** una capa que sigue viva apuntando a la SubViewport cuando ésta se borra guarda un puntero colgado (`CanvasLayer::vp`) y al salir llama `vp->_canvas_layer_remove(this)` sobre memoria liberada. **Reproducido en la PC:** `tests/frame_res_test.gd` con el código viejo cae con `signal 11` en 3 de 6 corridas (y da 4 fallas en todas). En el juego normal `app.gd` llama `release_frame()` antes de borrar la carrera, así que **no está probado que el teléfono pase por ese camino**: es un defecto real corregido, no la causa confirmada de los cierres. El mismo código está igual en Godot 4.7.2 (actualizar el motor no lo arregla).
- **Cambio A:** `ui/frame_res.gd`: cada capa redirigida se devuelve a la ventana en su `tree_exiting` (antes de que el motor desconecte); al irse la carrera, las capas de afuera vuelven a la ventana; un `_redirect` diferido que llega con el frame ya apagado no hace nada.
- **B. Driver / motor:** sin traza no se puede decidir entre `libGLES_mali.so` y `libgodot_android.so`. No hay reportes oficiales de Godot que coincidan (4.5.2 arregla un cuelgue de Adreno 5xx en Vulkan; nosotros usamos Compatibility/OpenGL). Indicio a favor del frame reducido (SubViewport 2D anidada con la 3D): los tres cierres del Z2356 tienen el frame activo (el error de la señal sólo aparece con el frame activo) y el otro teléfono se cierra justo cuando la calibración cambia el tamaño del frame. **No se cambió el renderer.** Experimento sin código: Opciones → Gráficos → «Resolución de frame» = **100 %** (apaga el frame reducido) y jugar las mismas 3 cargas.
- **C. Memoria:** ver arriba (no es falta de memoria).
- **D. Traza del cierre — cambio:** `game/diag/tombstone.gd` (nuevo) + `crash_log._tombstone()`: Android 12+ guarda la «lápida» (tombstone) de cada cierre nativo y la entrega con `ApplicationExitInfo.getTraceInputStream()`; se lee con `readAllBytes()` (Android 13+), se decodifica el protobuf (`tombstone.proto` de AOSP) y se escriben líneas `[lápida]`: señal, código (`SEGV_MAPERR`/`SEGV_ACCERR`), dirección, **nombre del hilo que se rompió**, sus primeros 16 cuadros (**biblioteca** + dirección relativa + función si la hay + build-id de libgodot) y las últimas 14 líneas de **logcat** del proceso. Se guarda también el archivo crudo (`user://diag/lapida_<hora>.pb`). La primera vez con este contenido se lee la del último cierre aunque esa sesión haya salido bien. No hace falta PC ni adb. Si la lectura llegara a cerrar el juego, la marca `exitinfo.try` impide repetirla.
- **Descarga 13/0 — causa CONFIRMADA (código):** 13 = `HTTPRequest.RESULT_TIMEOUT`; `bootstrap/boot.gd` ponía `timeout = 30` y en Godot ese tiempo es el TOTAL del pedido (un temporizador que arranca con `request()`), también para bajar `cars.pck` (~566 MB): sólo terminaba a más de ~20 MB/s. Además con `use_threads = true` el cliente HTTP lee en modo bloqueante: una conexión trabada colgaba la descarga para siempre (ni `cancel_request()` volvía; visto en la prueba). **Cambio (va en el APK, hay que reinstalarlo):** 30 s sólo para el manifiesto; paquetes sin tope total, sin hilo (bloques de 1 MB por cuadro), **por tramos de 32 MB con `Range`** (cada tramo terminado se pega al archivo: un corte pierde como mucho un tramo; se eligió así porque Godot 4.7 borra el archivo a medio bajar al fallar, visto con la prueba), vigilante que corta si no llega nada en 45 s, 4 intentos automáticos (se reinician con cada tramo que llega) antes de mostrar «Reintentar», restos limpios al terminar.
- **Pruebas (acá, Godot 4.5.1):** `frame_res_test` nueva (vieja: SIGSEGV 3/6 y 4 fallas; nueva: 6/6 TODO OK), `tombstone_test` nueva (lápida armada con el formato de AOSP: señal, hilo, cuadros, logcat, causa; datos cortados o basura no rompen), `boot_download_test` nueva (servidor local que corta un tramo de `content.pck` y deja trabado uno de `cars.pck`: termina solo en ~10 s, repite sólo el tramo perdido, sha256 correcto, sin tocar «Reintentar»; **pasa igual con Godot 4.5.1 y 4.7.2**), `crash_log_test`, `autotune_test`, `scripts_parse_test` OK. Las tres nuevas se sumaron a GitHub Actions.
- **Evaluación de motor (fases 4 y 5):** ver `docs/MIGRACION_GODOT.md` → «Evaluación 15/10/2026». Recomendado 4.7.2 como experimento (rama `exp/godot-4.7.2`, sin fusionar): importa sin errores, las 74 pruebas pasan, r183 armó el APK `DreamRacing-4.7-PRUEBA.apk` (se instala aparte) y el contenido `godot-content-4.7`. Compilar no prueba estabilidad: falta el teléfono. APK normal con estas correcciones: r182 (`godot-apk/DreamRacing-liviano.apk`, contenido r182-15c3ae2).
- **Resultado:** PARCIAL / PENDIENTE DE APK. Causa del cierre nativo **NO confirmada**; corregidos un defecto que sí produce SIGSEGV (probado en PC) y la descarga. **Siguiente paso mínimo:** (1) instalar el APK nuevo (por la descarga), abrir el juego y tocar «COPIAR REGISTRO»: deberían aparecer las líneas `[lápida]` del último cierre aunque no se cierre de nuevo; pegarlas. (2) Jugar las mismas 3 cargas (Aurelia, Quarry, drift) con el contenido nuevo; si se cierra, pegar el registro. (3) Si se sigue cerrando, repetir con «Resolución de frame» = 100 % para aislar el frame reducido.

---

## 15/10/2026 · Tablero de la cabina: 3 opciones para comparar (3D, imagen, clásico) y sin el velocímetro redondo
- **Pedido del dueño:** sacar el velocímetro circular de debajo de la pantallita (quedan el de atrás del volante y el digital del centro); probar un tablero PNG «para que el interior 3D no ocupe muchos recursos» y comparar los 3: el que había, el 3D y el de imagen; elegir cuál de sus 3 PNG queda mejor.
- **Elección del PNG:** el de fondo gris (1870 × 841): tablero + consola limpios. Los otros dos traen la jaula, las puertas, los espejos y el techo (no encajan en cada auto) y uno tiene el «transparente» dibujado como cuadriculado (no es transparencia real; ninguno de los 3 tenía canal alfa).
- **Cambio:** `tools/cars/build_dash_image.py` (nuevo: fondo quitado con GrabCut, restos de parantes borrados, 1024 × 461) → `models/cabin/tablero_imagen.png`; `cockpit.gd`: `dash_style` (`modelo` / `imagen` / `clasico`), `_b_dash_image()` (un plano con transparencia recortada, inclinado ~20°, tapa oscura hasta el parabrisas), velocímetro redondo quitado (`_b_speedo`, `SpeedFace`, `set_speedo_max`); Opciones → Gráficos → «Tablero de la cabina» (por defecto el 3D, como estaba; se aplica en la próxima carrera); textos en 5 idiomas (b64). También: sin la opción de pilotos desde afuera, capó entero desde adentro (`car_visual.set_inside`), Volante Pro rehecho sin roturas (91 mil triángulos).
- **Pruebas:** `cabin_dash_test` nueva (los 3 en hatch, genesis y gt3; la imagen no pasa el ancho del habitáculo ni el parabrisas; el buggy usa el clásico), `cosmetics_test`, `cabin_shake_test`, `language_test`, `scripts_parse_test`; capturas de la cabina con cada tablero.
- **Resultado:** PENDIENTE DE APK (¿cuál se ve mejor?, ¿FPS con cada uno en el Z2356?).

---

## 14/10/2026 (noche) · Pruebas de GitHub en rojo desde r175 (arreglado)
- **Síntoma:** el trabajo «tests» de «Build Godot APK» falló en r175–r178 (el APK y el contenido se publicaron igual: ese trabajo no bloquea).
- **Causa confirmada:** `spawn_menu_test` buscaba en el mapa de «¿dónde aparecer?» una marca de tipo «pueblo»; desde r175 los pueblos a los que no se llegó manejando salen como «locked» (`city_reach.gd`). Como el paso se corta en el primer error, desde r175 no corrían las pruebas que vienen después.
- **Cambio:** la prueba marca un pueblo como alcanzado, comprueba que se pueda elegir y que los otros 32 salgan con candado.
- **Pruebas (acá):** `spawn_menu_test` TODO OK; las que se salteaban en GitHub — `language_test`, `music_test`, `login_wall_test`, `account_econ_test`, `world_ambient_test`, `ambient_peds_test`, `world_budget_test`, `vegbench_test`, `travesia_test` (×2) — salida 0; `audio_levels_test` OK.
- **Resultado:** RESUELTO (falta ver la corrida de GitHub en verde).

---

## 14/10/2026 (noche) · Tablero 3D del dueño, velocímetro de aguja y variantes del Volante Pro
- **Pedido del dueño:** meter el interior 3D (InteriorRally.glb) con textura, que encaje con cada habitáculo y sin bordes afuera («es muy fino y ancho, vas a tener que ajustar»); varias texturas y colores del volante; un velocímetro lindo en el tablero sin sacar el digital del centro.
- **Tablero:** `tools/cars/build_cabin_dash.py` (nuevo) → `godot/game/models/cabin/tablero_rally.glb` (46.815 triángulos, textura 1024, 3 MB). Se recortó a tablero + consola (afuera el marco del parabrisas, los parantes, las puertas y los espejos: asomaban fuera de la carrocería), se giró 180° y se normalizó. La reducción usa **PyMeshLab con textura** (con el simplificador común la textura salía corrida o con manchas blancas: se probó y se descartó). `cockpit.gd` → `_b_dash_model()`: ancho del habitáculo, del volante al parabrisas, alto en la misma proporción (estirado hasta el piso ovalaba los relojes) y tapa a la altura del parabrisas; faldón oscuro abajo; material sin brillo de metal. En cabinas abiertas (monoplaza) y si falta el archivo queda el tablero de siempre (`CAB_OLD_DASH=1` para comparar).
- **Velocímetro:** `cockpit._b_speedo()` + `SpeedFace` (esfera dibujada una vez, aro de metal, aguja naranja), máxima según la velocidad al corte en la última marcha (`set_speedo_max`, desde `race.gd`). La pantallita digital del centro queda.
- **Volantes:** `tools/cars/make_wheel_variants.py` (nuevo) recolorea la textura del Volante Pro por partes (cuero, costuras, marcas): 5 variantes (azul, rojo, blanco, negro y oro, verde) en `cosmetics.json` (`kind: pro`, `tex`), migración **`20261016000000_cosmetics_volantes_pro.sql`** (hay que aplicarla), textos `b63`.
- **Pruebas:** `cosmetics_test` (precios iguales en el juego y en las migraciones), `menu_ui_test`, `cabin_shake_test`, `scripts_parse_test`; capturas de la cabina (hatch, gt3 con el volante azul) adentro y desde atrás.
- **Resultado:** PENDIENTE DE APK (¿se ve lindo?, ¿encaja en cada auto?, ¿FPS con 47 mil triángulos más en la cabina? — si pesa, bajar FACES en el script) + **aplicar la migración**.

---

## 14/10/2026 (noche) · Sonido: motor por capas, caja, freno motor, turbo y estampidos
- **Pedido del dueño:** sonido de motor real (no robótico), silbido de la caja al acelerar y en inercia, freno motor al soltar, turbo, explosiones al pisar intermitente.
- **Causa del sonido «robótico» (confirmada en el código):** el motor era un único ciclo de 1050 muestras repetido idéntico.
- **Cambio:** `tools/godot/make_engine_audio.py` (nuevo) + 18 muestras nuevas (~3 MB); `car_audio.gd` (capas con/sin carga mezcladas por frecuencia de explosiones y pedal, `gearwhine`, `overrun`, `backfire`, soplido del turbo en cualquier marcha, compensación de sonoridad por frecuencia); `race.gd` (el audio simple ya no se prende solo tras un cierre); `tests/audio_render.gd` (escena `blips`, `--log` con todas las voces que suenan). Detalle y mediciones: `docs/AUDIO.md` → «Motor por capas».
- **Pruebas:** `audio_levels_test` AUDIO_LEVELS_TEST OK (con los controles nuevos de la caja); mediciones con `analyze_audio.py`. **No se escuchó:** se midió (bandas, sonoridad, tonos); falta el oído del dueño.
- **Resultado:** PENDIENTE DE APK (¿suena a motor de verdad?, ¿la caja, el freno motor, los estampidos?, ¿volumen?). Para ajustar: `SND["layers"/"gwhine"/"overrun"/"backfire"]` en `car_audio.gd`.

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
