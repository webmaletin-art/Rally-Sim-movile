# Registro técnico de intervenciones

Una entrada por intervención, la más nueva arriba. Antes de tocar un sistema, buscar acá su nombre: si el problema ya se trabajó, seguir desde el último diagnóstico.
Resultado: RESUELTO · PARCIAL · FALLIDO · BLOQUEADO · PENDIENTE DE APK. Una hipótesis no es una causa confirmada.

---

## 20/10/2026 01:00 UTC · [B] Tercera tanda: la ciudad sólo choca con edificios, esquinas y veredas bien terminadas, terreno que no tapa la ruta, banquina con nieve, GPS, menús y luces (rama ccr-e7ae3f10-45afj2) — PENDIENTE DE APK
- **Pedido del dueño (mensaje con 15 capturas, 19/10):** «hay una traba invisible, una colisión: en un mundo abierto lo único que no deja pasar son los edificios y las vallas o cercos de la ruta; el resto no
  es colisión» (Avenida 3 cuadras 3 y 6; Avenida 2 cuadra 6 «justo me topo con otra calle y no puedo cruzar»; no puedo hacer un finito de drift contra un edificio; «en los vértices sólo colisionan los edificios,
  no puede haber una colisión invisible en la esquina de un edificio»). Al modificar la suspensión en el taller de prueba el auto hace respawn y el GPS queda por arriba del menú. «La rueda sigue hundiéndose
  en el borde del asfalto y de la tierra.» Asfalto y veredas mal terminados, rayas que se intercruzan: «poné una regla de que esas líneas terminen bien, hacelo de una vez». GPS que marca mal, tarda en
  actualizarse y no da ruta nueva si te pasaste. Botón para apagar las luces (de día estaban prendidas). Nieve: «si hay nieve no debe haber camino de tierra limpio»; en la X de la Ruta Panorámica el camino
  de tierra pasaba por arriba del asfalto en diagonal: «las rutas deben cortarse, una unión limpia»; «pasto y tierra sobre la ruta no existe, la ruta debe ser limpia». Eventos: sólo en el modo online
  con cuenta (y en tiempo real cuando se habilite), nunca en una partida común del mundo abierto (ahí sólo persecuciones y carreras). Placa de policía tapada por los botones de pausa y cámara.
- **Cambios (cada uno con su causa):**
  - **Colisiones (`city/city_layout.gd` → `prepare_walls`, `wall_push`, `DENSE_KINDS`; `track/city_track.gd` → `_push_locked`; commit 03c612b):** la pared de la ciudad era el borde del corredor de la calle (a
    1–5 m de las fachadas en los cruces, y también donde no había edificio: esquinas y huecos). Ahora, en las calles de la ciudad (`DENSE_KINDS`), sólo chocan las fachadas (los cuadriláteros de `slabs`, con
    una grilla de 4 m) y los 11 edificios especiales, más los objetos (postes, semáforos) y las vallas; las rutas de campo, la costa, la bahía y los túneles conservan la pared del corredor. Un auto pegado
    a una fachada (a un radio) pasa; adentro, no. `city_walls_test` (8 OK) cruza cada cruce por el eje y las esquinas, comprueba que toda pared es un edificio o un objeto y que la Panorámica sigue con su pared.
  - **Taller de prueba y menús (`race.gd` → `_lab_apply`, `ui/race_hud.gd` → `external_menu`, `ui/city_hud.gd` → `menu_open`; commit 81ffd53):** al aplicar un ajuste en el mundo abierto se reconstruía el
    auto como en una largada (respawn). Ahora `_rebuild_cars(only_player)` conserva posición, velocidad y giro. El minimapa/GPS (`city_hud`) se agregaba después del menú de pausa y se dibujaba arriba: ahora
    se esconde mientras haya cualquier menú (pausa, taller, eventos, pantalla de pruebas).
  - **Placa de policía (`city/city_police.gd` → `PoliceBadge`):** pasó arriba a la izquierda, junto al cronómetro (los botones de pausa y cámara la tapaban).
  - **Luces (`city/city_clock.gd` → `lights_mode`, `cycle_lights`; botón en la pausa de `ui/race_hud.gd`):** AUTO (de noche y bajo techo) · ENCENDIDAS · APAGADAS; de día en AUTO los faros quedan apagados.
  - **GPS (`ui/city_hud.gd` → `_trim_route`, `_route_dev`, `_off_t`; commit aa81f03):** la línea se recorta proyectando el auto sobre la poligonal (arranca sobre la calle) y se pide ruta nueva a los 0,5 s
    de estar a más de 14 m del recorrido (antes recién a más de 40 m). Primera versión: medía el desvío salteando el primer tramo y recalculaba de más; corregido y probado en `lab_city_test`.
  - **Esquinas redondeadas, veredas y rayas con una regla única (`city/city_layout.gd` → `ribbon_poly`, `prepare_fillets`, `clip_obstacles`, `CURB`; `city/city_world.gd` → `_road_segment`, `_clip_all`,
    `_sidewalk_part`, `_mark_part`, `_flat`):** causa: cada tramo de vereda y de raya se dibujaba entero y sólo se salteaba si su punto medio caía en otra calle; en los cruces quedaban escalones, cuñas dentro
    de la otra calle y rayas que cruzaban otra calzada. La regla ahora: (1) la calzada de cada tramo es un polígono (`ribbon_poly`, la misma que se dibuja); (2) en cada cruce se unen las calzadas y se «cierra» la
    unión con un radio de 4,5 m: lo que se agrega es la esquina redondeada del pavimento (`fillets`, 717 en la ciudad; los 187 cruces probados tienen sus esquinas); (3) las veredas y las rayas de cada tramo
    se recortan contra las calzadas de las otras calles y contra esas esquinas (`clip_obstacles`): la vereda termina en el cordón del cruce con su cara vertical, la raya no pasa por arriba de otra calzada.
    Dos errores propios encontrados con la prueba: la costura de la circunvalación repetía el primer punto y `miter` normalizaba un vector casi nulo (dirección al azar, escala 1,8: vereda metida en la calzada
    en (910, ±10)); y `_flat` dejaba triángulos de área cero (ahora se descartan).
  - **Ruedas en el borde (`track/city_track.gd` → `ground_info`):** el piso de la física sobre la vereda sube a `CURB` (16 cm) con una rampita de 25 cm desde el asfalto (antes quedaba a la altura del asfalto y la
    rueda se hundía 16 cm dentro del cordón dibujado); la esquina redondeada se consulta antes que el corredor (parte de ella cae afuera) y es asfalto a la altura de la calle más cercana.
  - **Terreno que no tapa el asfalto (`world/terrain_cap.gd` nuevo, `city/city_world.gd` → `_city_caps`, `_has_cap_roads`, `_terrain`; `region/region_world.gd` ahora delega en `TerrainCap.point`):** causa
    medida con la prueba nueva `city_terrain_test`: en el camino de la colina (`Camino de la Colina 300`, en (−1058, −728)) la malla de 16 m quedaba hasta 73 cm POR ENCIMA del asfalto (un vértice de la
    ladera de arriba, interpolado hasta el de abajo) y 1,4 cm en un atajo: era el «pasto y tierra sobre la ruta». Se usa el mismo recorte que ya tenía la región: para cada punto de la calzada y la banquina
    de las rutas de campo y la colina se bajan los vértices que la taparían. Ahora 0 puntos de 25 026 medidos. **Efecto lateral a mirar:** la malla queda hasta unos decímetros más baja junto a esa ruta, y la
    física fuera del corredor sigue el terreno natural (ya pasaba antes con el hundimiento de 0,5 m de la colina).
  - **Banquina con nieve (`world/world_surfaces.gd` → `snow_k`, `side_color`, `snow_side`; `city/city_world.gd`, `region/region_world.gd`, `track/city_track.gd`, `region/region_data.gd`):** a partir de 54 m la banquina
    de las rutas de campo se tiñe hacia la nieve (casi blanca desde 64 m) y desde unos 59 m se pisa como nieve (superficie 6) en vez de banquina. El asfalto sigue limpio.
  - **La X de la Ruta Panorámica (2054, 1213, a 63,9 m):** se renderizó con el director del tráiler (pantalla virtual, no es el del teléfono): el asfalto de los dos tramos se cruza limpio y las banquinas se cortan
    contra el borde del asfalto del otro; lo que se veía «tierra sobre el asfalto» era la banquina dibujada entera. Hay 9 cruces de rutas de campo en el mapa (Ruta 20/60/80 con sus atajos y la X de la Panorámica).
  - **Eventos:** ya estaba (tanda anterior) que sólo corren con `cfg.events` (mundo abierto entrado desde el MODO ONLINE) y que una partida común no los tiene. Queda pendiente de definir el mundo compartido en
    tiempo real (pregunta abierta).
- **Pruebas (Godot 4.7.2 en la computadora, nada probado en un teléfono):** nuevas `junction_render_test` (8 OK: esquinas, vereda y rayas sin pisar otra calzada, piso de la vereda a ±0 mm, esquina como asfalto
  108 de 108), `city_terrain_test` (6 OK: terreno bajo el asfalto en 25 026 puntos, banquina con nieve), `city_walls_test` (8), `lab_city_test` (24); y las existentes `road_height_test` (12), `city_test` (101),
  `surfaces_test` (9), `region_terrain_test` (8), etc. (ver abajo la lista final de la corrida). Las dos nuevas están en el flujo de GitHub.
- **Qué falta / pedirle al dueño (APK RC):** (1) recorrer Avenida 2 y 3 (cuadras 3 y 6) y las esquinas: ¿ya nada invisible?, ¿el finito de drift contra un edificio?; (2) taller de prueba en el mundo abierto: ¿sin
  respawn y sin el mapa arriba del menú?; (3) ruedas en el cordón y el borde del asfalto; (4) esquinas redondas, veredas y rayas en los cruces (de día y de noche); (5) GPS: pasarse una calle, ¿da ruta nueva rápido?;
  (6) luces: AUTO/ENCENDIDAS/APAGADAS en la pausa; (7) Ruta Panorámica en la X y por encima de 59 m: ¿la banquina nevada se ve bien?; (8) caminos de la colina: ¿se ve limpia la ruta?; (9) placa de policía.
  **Preguntas abiertas:** ¿en los túneles el GPS «sin ruta» te molesta?; ¿a alta velocidad el volante de la pantalla llega al tope igual (hoy la dirección se reduce con la velocidad)?; ¿eventos también en el mundo
  compartido en tiempo real cuando se abra?; ¿querés suavizar más las esquinas redondeadas (hoy radio 4,5 m)?

---

## 19/10/2026 22:10 UTC · [B] Segunda tanda sobre la pantalla de juego: eventos sin letras, policía, talleres, faros, carreras del mapa, volante, altura del asfalto y terraplén (rama ccr-e7ae3f10-45afj2) — PENDIENTE DE APK
- **Pedido del dueño (dos mensajes con capturas, 19/10):** «sigue estando mal: no quiero más letras en la pantalla de partida; sólo un puntito rojo en la pausa y en EVENTOS; un menú de eventos lindo, con fotos
  y autos, nada genérico: lista → elegir uno → explicación con imagen → IR AL EVENTO (el GPS me lleva, incluso a otra ciudad) → pausa → SALIR DEL EVENTO». Cartel de la policía más lindo, arriba a un costado.
  Talleres: «que no me aparezcan más; si cruzo por el taller, que se registre en el mapa». Faros que no alumbran los bordes de la calle y GPS que no anda bien. Foto en la Ruta Panorámica 70 (cuadra 37):
  piso blanco más bajo que la ruta, «salgo volando»; tironcitos de fotogramas al cargar pueblos por la ruta. Rayas por arriba del asfalto, bordes que tapan las ruedas, ruedas enterradas. Carreras: el
  Circuito del Puerto largaba pegado a un taller, hay que cerrar las calles dejando sólo la pista (en A→B varios caminos), mostrarla en el mapa y en el GPS. Volante: «se le pueden dar 3 vueltas y la
  rueda se traba antes; tiene que trabarse donde se traba la rueda y girar lo que gira el volante, como un auto real». Orden permanente: trabajar a conciencia, arreglar lo obvio y avisar, preguntar lo dudoso.
- **Cambios (cada uno con su causa):**
  - **Eventos (`ui/events_ui.gd` nuevo, `ui/race_hud.gd`, `ui/controls.gd`, `city/city_modes.gd`, `ui/menu_world.gd`):** pantalla propia a pantalla completa con pestañas EVENTOS · NOVEDADES · AYUDA, tarjetas con imagen
    (`ui/events/<tipo>.jpg`, 7 imágenes) y detalle con banner, descripción, CÓMO SE JUEGA, PREMIOS (con miniaturas de los autos), TU PROGRESO, «📍 IR…» y «✕ SALIR DEL EVENTO» (`event_go` / `event_cancel`). En la
    partida no hay texto de eventos: sólo un punto rojo (`controls.badge_dot`) sobre el botón de pausa y sobre «📅 EVENTOS» cuando hay algo sin ver (`profile` ajuste `evSeen`). Sólo quedan cuadritos de lo que
    estás corriendo (cuenta regresiva de una fuga, la barra de la cacería de cerca, etc., arriba al centro, 17 px, finos). Reemplaza la página `_events_page` y el numerito del primer paso.
  - **Policía (`city/city_police.gd` → `PoliceBadge`):** placa de 196×46 arriba a la derecha (sirena, CONTROL POLICIAL / TE ESTÁN MIRANDO / PERSECUCIÓN, barra de tiempo; titila rojo y azul en la persecución). Antes: dos renglones de texto debajo del velocímetro.
  - **Talleres, concesionarios y gomerías (`ui/city_hud.gd`):** ya no se muestra en el mapa lo que no pasaste; al cruzar a menos de 70 m se registra en silencio (`seen_pois`, ajuste `poiSeen`, `DISCOVER_R`). Ojo: del «pantalla verde en
    el centro» del mensaje no está claro a qué se refiere: pregunta abierta abajo.
  - **Faros (`city/city_clock.gd`):** el haz era un cono angosto; ahora es una malla con shader que reparte la luz hasta ±12 m (núcleo + falda) y se apaga con la distancia (3 pasadas de ajuste con capturas nocturnas).
  - **Carreras del mundo abierto (`world/ow_events.gd`, `city/city_events.gd`, nuevo `city/street_closure.gd`, `ui/city_hud.gd`):** (1) ninguna largada a menos de 100 m de un taller, concesionario, estación, gomería o peaje (`_clear_start`:
    el circuito rota la largada por el lazo, el A→B se acorta por adelante hasta un tercio); (2) al largar se cierran con vallas rojas y blancas con colisión las calles que salen del recorrido (ciudad: cruces con
    `CityGps`; región: nodos de 3+ calles), se sacan al terminar o cancelar; (3) la pista se dibuja verde y gruesa en el minimapa y el mapa grande y el GPS la sigue (`set_course` / `course_at`, en un circuito dando la vuelta);
    al tocar una carrera descubierta en el mapa se ve su recorrido antes de largar (`preview_route`).
  - **Volante de la pantalla (`ui/controls.gd`):** el dibujo giraba hasta ±540° y la dirección ya estaba al máximo a ±180° (`wheel_rotation` ±3π contra `wheel_target = rot / π`). Ahora `WHEEL_LOCK = 0,75 π` (±135°, lo
    mismo que ya usaban el acelerómetro y el teclado): el volante sigue al dedo 1:1, se traba donde la dirección llega al tope y vuelve al centro al mismo ritmo que la dirección. Con el dedo se necesita casi el mismo
    recorrido que antes para el tope (133° antes, 135° ahora): el manejo no cambia, sólo desaparecen las 2,5 vueltas de más. La rueda de la cabina 3D ya seguía el ángulo real (`steerAngle × 7,5`). **No se tocó** la reducción
    de la dirección con la velocidad (`steer_scale`): a 150 km/h el tope de la rueda es menor que a baja velocidad. Pregunta abierta abajo.
  - **Asfalto, rayas y ruedas (`track/city_track.gd`, `region/region_data.gd`, `city/city_world.gd`, `region/region_world.gd`, `fx/paper_kit.gd`, `paper.gdshader`, `paper_simple.gdshader`, `city/city_layout.gd`):** causa confirmada
    leyendo el código y con capturas: el asfalto se dibujaba 4 cm (ciudad) o 5–7 cm (región) arriba del piso de la física y las rayas 7 cm más arriba todavía (11–14 cm), así que las gomas quedaban metidas en el
    asfalto y las rayas laterales las tapaban. Ahora el piso de la física sube lo mismo que el asfalto (`CityLayout.ROAD_UP`, `RegionData.road_lift`; túneles y playones sin cambio) y las rayas van a 1,2 cm del
    asfalto con un shader que las levanta 5 cm por cada 100 m de distancia a la cámara (`lift_k`; antes los 7 cm fijos eran el parche contra el parpadeo a la distancia).
  - **Ruta Panorámica 70 (cuadra 37) (`city/city_layout.gd`, `city_world.gd`, `city_track.gd`):** lo que se midió (`road_height_test`): la calle es una terraza a media ladera; del lado de abajo el piso natural quedaba 0,9–1,9 m más
    abajo pegado a la banquina (escalón) y del de arriba subía como pared mientras la malla visible se hundía junto a la calle (la física seguía el terreno natural, no la malla). Ahora el terreno junto a las rutas
    de campo (`rural`, `shortcut`, `scenic`, `hill`) sale de UNA función (`CityLayout.verge_height`) que usan la malla y la física: terraplén que baja de a poco del lado de abajo, cuneta que sube suave del de arriba,
    mezcla por cercanía entre dos tramos a distinto nivel (horquilla). Escalón máximo en el borde 0,29 m; pendiente máxima 0,61 m por metro (antes 1,9 m de golpe); en las horquillas más cerradas (la ruta se cruza
    con su propio tramo, 25 m entre ejes y 3 m de diferencia) queda 1,55 m por metro: hay guardarraíles. La espiral de subida y la de bajada se cruzan a ras en (2054, 1213) a 63,9 m: ahí ya no se pintan las dos
    líneas amarillas cruzadas. **El blanco es nieve de diseño:** `WorldSurfaces.SNOW_H = 64 m`, la ruta pasa justo por esa altura ahí. Pregunta abierta abajo.
  - **Tironcitos al cargar pueblos (`region/region_world.gd` → `_collect`):** antes se armaban 2 cuadrados por cuadro siempre; ahora 1 y un segundo sólo si el primero costó menos de 2,5 ms. **No se pudo medir en un teléfono**
    (en la computadora `_finish` cuesta 0,3–3,6 ms): es una mejora razonable, no una causa confirmada.
  - **GPS:** revisado con 396 rutas al azar entre ciudad, región, estaciones y pueblos: 6 sin ruta, todas con un extremo dentro de los túneles del «bolsillo» (x ≥ 75 000), que no están unidos al resto por diseño
    (se entra por un portal con fundido); 1 rodeo. Dentro de un túnel el GPS sigue diciendo «sin ruta». Lo demás (las carreras, el ir a un evento) está arreglado arriba; el dueño no dijo qué hace mal: pregunta abierta.
  - Textos nuevos en 5 idiomas (`tools/i18n/batches/b68_eventos_policia.py`, 45 textos).
- **Pruebas (Godot 4.7.2 en la computadora, nada probado en un teléfono):** nuevas `street_closure_test` (13 OK: largadas, vallas, no se escapa por las calles), `road_height_test` (12 OK: asfalto = física ±0,4 mm de promedio,
  rayas a 1,2 cm, terraplén), `events_ui_test` (19 OK), `controls_test` (20 OK, 5 nuevas del volante), `events_rules_test` (43 OK), `ow_events_test` (13 OK, 133 s), `city_modes_test` (34 OK), `city_test` (101 OK),
  `region_junction_test`, `region_connectors_test`, `region_terrain_test`, `region_polish_test`, `region_test`, `region_threads_test`, `region_drive_test`, `open_world_access_test`, `spawn_menu_test`, `track_test`, `city_reach_test`.
  Capturas con pantalla virtual (renderizador por software, no es el del teléfono): ruedas apoyadas en el asfalto y rayas pegadas, la Ruta Panorámica en el cruce de la cuadra 37. `street_closure_test` y `road_height_test` ya
  están en el flujo de GitHub.
- **Qué falta / pedirle al dueño (APK RC):** (1) pantalla de juego limpia, punto rojo, pausa → EVENTOS (tarjeta → IR AL EVENTO → GPS → SALIR); (2) placa de policía; (3) pasar cerca de un taller y mirar el mapa;
  (4) de noche: ¿los faros alcanzan los bordes?; (5) una carrera del mapa (Circuito del Puerto): ¿larga lejos del taller?, ¿se ven las vallas?, ¿la pista verde en el mapa?, ¿el GPS la sigue?; (6) el volante: ¿se traba
  cuando se traba la rueda?, ¿se siente igual el manejo?; (7) ruedas sobre el asfalto y rayas pegadas, de cerca y de lejos; (8) Ruta Panorámica 70 cuadra 37 y bajando por el lado del abismo; (9) tironcitos al llegar a un pueblo.
  **Preguntas abiertas:** ¿querés la nieve sobre los 64 m (es de diseño y hoy toca la Panorámica)?; ¿a qué se refería con la «pantalla verde en el centro» de los talleres?; ¿qué hace mal el GPS (no marca, marca
  mal, no recalcula)?; ¿querés que a alta velocidad el volante de la pantalla llegue al tope igual (hoy la dirección se reduce con la velocidad)?; ¿eventos también en el mundo compartido en tiempo real cuando se abra?

---

## 19/10/2026 18:54 UTC · [B] Eventos online: sólo en el modo online y fuera de la pantalla de juego (rama ccr-e7ae3f10-45afj2) — PENDIENTE DE APK
- **Pedido del dueño (19/10):** «la pantalla de juego está llena de letras: eventos que aparecen y no salen más, letras gigantes, hace más lento el juego y molesta.
  Los eventos van en la pausa, como en cualquier juego de carreras: pauso, miro los eventos y si quiero participo; como mucho un botoncito chiquito. Y son sólo
  del online: en el mundo abierto offline no tienen que aparecer (el online y el offline son distintos juegos, como el GTA); si no, juego el offline y hago trampa.
  En el menú online, eventos del día, disponibles y próximos, con imágenes».
- **Síntoma / causa (código):** `city_modes.gd` corría en TODO mundo abierto sin el mundo compartido (`available()`: policía prendida y `cfg.online != true`), o sea
  también desde Menú → MUNDO ABIERTO offline (y el hub online sin tiempo real entraba con `world_online = false`: no había forma de distinguirlos). En pantalla:
  `_event_tick` tiraba `_big` (Label de 28 px en el medio, 5–6 s) al anunciar cada evento y al empezar («📅 EN VIVO…»), y `update` dejaba hasta 3 renglones fijos
  debajo del velocímetro con TODOS los eventos (fugas con «quedan 3h», contrarreloj «largada a 12 km», carrera de la semana…) mientras duraran (horas). La pausa
  («📅 EVENTOS EN VIVO») mostraba el resumen como otro cartel gigante de 7 s. Además la racha del Fugitivo y los récords de las carreras del mapa se mandaban al
  ranking online desde el mundo offline.
- **Cambios:**
  - `city_modes.gd`: `events_on()` = `available()` + `cfg.events`; el sondeo, los eventos, la marca y el récord del Fugitivo sólo con `events_on()`. Los escapes de la
    policía siguen pagando en el offline (es de la policía, no del online). Sin carteles al anunciar/empezar (queda el aviso corto «empieza en 1 minuto»); la cacería,
    el «X atrapó…», los hitos y el escape pasan a avisos cortos (`_toast`). Renglón: uno solo y sólo del evento en juego (`_bounty_tick` cerca o con mapa,
    `_escape_line` en persecución, `_reach_tick` a < 300 m de la largada o corriendo, `_record_line` corriendo la de la semana, drift en la plaza). `_big` queda para
    los resultados de lo que estás jugando, más chico (21 px), arriba y ≤ 4 s. Nuevas: `event_cards`, `live_count`, `_badge`, `_go_point`, `event_go`, `prize_car`.
    Se sacó `_show_board` (el cartel de la pausa).
  - `ui/race_hud.gd`: `events_fn` / `event_go_fn` y la página «eventos» de la pausa (`_events_page`: tarjetas con miniatura `ui/thumbs/<auto>.png`, cuándo, premio,
    cómo vas, «📍 IR»); botón «📅 EVENTOS · N en vivo» en la pausa sólo si hay eventos acá. `ui/controls.gd`: `badge_n`, numerito naranja sobre el botón de pausa.
    `race.gd`: el cableado (2 renglones).
  - `ui/menu_world.gd`: `events_entry` (true desde las pantallas del modo online, false desde la de online cerrado) → `cfg.events`; «📅 EVENTOS DE HOY» en la portada
    del online por datos (`_today_events`, 3 tarjetas + «VER TODOS»), tarjetas con imagen y secciones EN VIVO / PRÓXIMOS en la lista (`_event_card`).
    `ui/menu.gd`: MUNDO ABIERTO offline pone `events_entry = false`. `city/city_events.gd → _send_record`: sólo con `cfg.events`.
  - Textos nuevos en 5 idiomas (`tools/i18n/batches/b67_eventos_pausa.py`).
- **Pruebas (Godot 4.7.2 en la computadora):** `tools/test/run_test.sh events_rules_test 60` → OK, 35 OK (11 nuevas: offline sin eventos, online con eventos,
  compartido igual que antes, sin renglones ni cartel por eventos que no jugás, tarjetas en vivo primero, miniatura, marca). `city_modes_test` (con `cfg.events` en
  las partes de eventos) → OK 34/34; una corrida dio FALLA en «y huyen por las calles» (la IA de la presa en 6 s) y la siguiente OK, igual que con el código de
  antes → inestable, no es de este cambio. `escape_farm_test`, `ow_events_test`, `scripts_parse_test`, `language_test` → OK. `menu_ui_test`: las 4 FALLA de
  «cámara libre: arrastrar…» salen igual sin este cambio (no las toqué).
- **Qué falta / pedirle al dueño:** probar desde el APK RC: (1) Menú → MUNDO ABIERTO: ningún evento, ni numerito en la pausa; (2) MODO ONLINE → «EVENTOS DE HOY»
  con imágenes → JUGAR EN DREAM CITY: numerito naranja en el botón de pausa, pausa → 📅 EVENTOS con las tarjetas y «📍 IR»; (3) que la pantalla de juego quede
  limpia. Pendiente de decidir: en el mundo compartido en tiempo real (cuando se abra) siguen sin eventos de clasificación, como antes.

---

## 16/10/2026 (20) · Versión candidata, fase 5: eventos y retención (rama ccr-e7ae3f10-45afj2, NO en main) — PENDIENTE DE APK Y DE MIGRACIÓN
- **Cacería accesible:** la presa tenía SIEMPRE +15 % de motor, +12 % de agarre, ritmo 112 % y cero errores, con autos S/A (Veltor GTR, Moust…): un R2 Turbo de serie
  (PI 487, 209 km/h) no tenía chance. Ahora (`city_modes.gd → prey_ai / pi_ok`) el servidor puede mandar `boost`, `pace`, `errors` y `max_pi` en la plantilla; sin esos
  datos todo sigue igual que antes (comprobado). Plantilla nueva `caza_inicial`: 2 autos de clase C (pickup, SUV, Camo, Torito, Clásico 60; PI 454–536), sin empujón,
  ritmo 95 % con errores, 45 s pegado (no 60), 60 s en el mapa y sólo para autos de hasta PI 599 (lo controla el juego: el servidor no conoce el PI; límite documentado).
  Arreglo de paso: después de «hacerse el boludo» la presa volvía siempre a ritmo 112 %; ahora vuelve al suyo.
  **`caza_inicial` queda APAGADA al aplicar** (`enabled = false`): el APK estable usa el mismo servidor y no entiende esos parámetros (soltaría la presa reforzada y
  sin tope de PI). Se prende cuando la versión nueva sea la publicada (Table Editor → `wev_templates` → `caza_inicial` → `enabled`).
- **Horarios rotativos:** `_wev_next_slot` (función pura, probada sola) + `params.rotate`: cada «día de evento» (empieza a las 12 UTC = 9 de Argentina, así la noche
  argentina no se parte en dos) la plantilla arranca a UNA hora de su lista. Cacería de la noche: 20–23 h AR; de la tarde: 15–18 h; principiantes: 11–14 h. Entre dos
  seguidas de la misma plantilla hay ≥ 21 h (descanso 18 h), así no se duplican ni se pisan. Las de fábrica se cambian sólo si el dueño no las tocó en el panel.
- **Desafíos del día** (`game/data/daily.gd`): 3 por día (terminar 2 carreras del mapa; ganar la carrera del mapa marcada —una ya descubierta, fija desde que empieza el
  día— o cualquiera si no descubrió ninguna; terminar 2 eventos del menú). Día de Argentina (UTC−3) igual para todos. Premios $2.500 / $5.000 / $4.000 (≈ $11.500/día,
  menos que una hora de juego). Sin compras, sin conexión. Se cobran con `earn` «daily» `once` (20261022 ya los rechaza repetidos: reinstalar o reconectar no paga dos
  veces) y la cuenta devuelve lo cobrado hoy. Configurables desde el servidor (`game_cfg.daily`, viaja con el estado de la cuenta: **ninguna consulta nueva**).
- **Hitos de la temporada:** 25 / 60 / 150 / 300 pts → $3.000 / $6.000 / $15.000 de vale / $20.000 (una fuga de 5 min ya da 40 pts: el jugador casual cobra algo).
  `season_claim(id)` paga cada hito una sola vez (`wev_milestones`, clave primaria) y el juego lo pide sólo cuando la consulta de eventos que ya existía dice que hay uno
  nuevo; el tablero muestra «próximo hito: 60 pts → + $6000».
- **Colección:** LOGROS tiene una primera página «DESAFÍOS DEL DÍA + COLECCIÓN» (autos X/28, carreras del mapa descubiertas X/79 y ganadas X/79) y 4 metas nuevas de una
  sola vez (Explorador 20 descubiertas $6.000, Cartógrafo 79 $25.000, Dueño del mapa 25 ganadas $20.000, Colección completa 24 autos comprables $100.000), con avance X/N.
- **Servidor (migración ADITIVA `20261024000000_events_rotation_daily_milestones.sql`, NO aplicada):** `_wev_next_slot`, `_wev_ensure` con rotación, `caza_inicial`,
  `game_cfg`, `_acct_json` + «dcfg», `wev_milestones`, `season_claim`, `_wev_json` + hitos. Autoprueba al aplicar + casos nuevos en `tools/online/account_test.sql`
  (rotación 8 días, hito una sola vez, desafío del día una sola vez, configuración en el estado). Un servidor sin la migración: el juego usa la configuración de fábrica,
  no pide hitos y la cacería es la de siempre.
- **CI:** `build-godot.yml` con `concurrency` por rama (un push nuevo cancela la compilación anterior de la rama RC; en main no se cancela nada): había 6 corriendo a la
  vez y la más vieja podía pisar el APK RC.
- **Pruebas:** `events_rules_test` (24 OK, 1 s, en CI), `progression_rules_test` 22 OK, `account_econ_test` 81 OK, `rewards_test` 17 OK, `city_modes_test` 34 OK (40 s),
  `next_goal_test` 11 OK, `scripts_parse_test` OK. Pruebas SQL: las corre GitHub («Economía online · prueba SQL»). **Sin probar en el teléfono.**
- **GitHub Actions (16/10, 21:40 UTC):** «Build Godot APK» #212 a #218 en verde (las 85 pruebas de Godot + APK). **RC = corrida #218, commit `2ae3c00`**: `DreamRacing-RC.apk` (26,5 MB, sha256 `6f52b0e7…98fe8`) en la release `godot-apk-rc`, subido 21:09:56 UTC y sin cambios después. «Economía online · prueba SQL» #29 y #30 en verde (la #28 falló por la prueba misma: el rol de jugador no lee `wev_events`; arreglado con un ayudante). Los commits posteriores (`58ddead`, `36f23f3`, `7d4577a`, `06a0377`) sólo tocan SQL de prueba, la migración (no aplicada) y documentos: el APK RC no cambia.

## 16/10/2026 (19) · Versión candidata, fase 4: progresión, autos pagos, stance/diferencial (rama ccr-e7ae3f10-45afj2, NO en main) — PENDIENTE DE APK
- **Método (pedido del dueño: pruebas cortas, nada de tests de horas):** la economía se CALCULA con `tools/econ/progression_sim.py` sobre datos reales volcados en 10 s por
  `godot/tests/econ_dump.gd` (79 carreras con `OW.build`, 28 autos con `CarBuild.perf_of`) → `tools/econ/game_data_snapshot.txt`. Las pruebas de Godot corren con
  `tools/test/run_test.sh <prueba> <tope>`: registro renglón por renglón en `test_logs/` y corte al llegar al tope (si se traba, lo comprobado queda escrito).
- **Agujero encontrado (P0, demostrado en el código):** en las carreras del mapa, un resultado que no es victoria pagaba ENTERO siempre: salir 2.º (45 %) o sacar plata
  (60 %) a propósito rendía más que ganar repetido (35 %). Granja de plata: **$45.000/h**, la actividad más rentable del juego. Arreglo (`city_events.gd → pay_mult`,
  `LOSE_K = 0,55`): la no-victoria paga entera en el 1.er intento y × 0,55 después (2.º 25 %, plata 33 %). Ahora: $24.800/h, debajo del mejor par ganado ($27.600/h).
- **Progresión (meta 10–15 h al primer superdeportivo sólo con lo repetible):** Veltor (clase S, $150.000): 8–11 h; Veltor GTR ($225.000): 12–16 h según el perfil
  (nuevo 15,9 · intermedio 13,2 · avanzado 12,0). Con los premios de 1.ª vez (~$650.000–750.000 en 12–18 h) se llega antes; no se tocaron precios de autos.
- **Travesía X:** pagaba $600–1.200 por 30–40 min (≈ $1.500/h, diez veces menos que repetir carreras). Ahora $3.000–6.000 (`rewards.gd → convoy_pay`, ≈ $7.700/h).
- **GT3 e Hyper (pagos, US$):** medidos, eran peores en todo que un auto gratis más barato (GT3 PI 705 < Trilux GT 707; Hyper 766 < Veltor S 772). Cambios SÓLO en
  esos dos (`vehicles.json`): GT3 = auto de pista con carga aerodinámica de fábrica (PI 745, manejo 0,43→0,52, el mejor en curvas de su grupo; el Trilux GT sigue con
  más motor y vmax); Hyper = híbrido con carga + par 1000→1120 (PI 821, clase X, manejo 0,50; el Veltor GTR gratis sigue más veloz, potente y con mejor PI máximo).
  Los otros 26 autos y las 79 carreras quedaron idénticos (comparación del volcado antes/después). Precios reales sin tocar.
- **Diferencial nivel 2 ($10.000):** decía desbloquear el reparto de tracción, pero ese reglaje era libre para todos. Ahora pide «split» (candado de la fase 1); sin el
  nivel 2 la tracción queda de fábrica. La Aventura trae diff 2: sus lecciones de reparto siguen.
- **Stance nivel 1 ($2.500):** la caída extrema ya actuaba en la física pero no se veía y el texto era engañoso. Ahora las ruedas se inclinan (sólo lo que pasa de 2°) y
  el texto dice la verdad (hasta ~3° dobla igual o mejor; después pierde agarre, 12° ≈ −30 % en curva).
- **Pruebas:** `progression_rules_test` (22 OK, 1 s, en CI), `tune_lock_test` 18 OK, `rewards_test` 17 OK, `ow_events_test` 11 OK (105 s), `scripts_parse_test` OK,
  `account_econ_test` OK. `online_test` NO se corre acá (necesita el servidor de prueba local, pedido del dueño de no levantarlo): la corre GitHub en cada compilación.
  **Sin probar en el teléfono.**

## 16/10/2026 (18) · Versión candidata, fase 3: competencia justa (rama ccr-e7ae3f10-45afj2, NO en main) — PENDIENTE DE APK
- **Pedido:** fase 3 del prompt maestro: récords por clase, registro del modo arcade/simulación, puesto al terminar, récords sin conexión.
- **Antes:** una tabla por pista (`scores`) mezclaba un R2 de serie con un Bisonte de 1000 cv; sólo guardaba el id del auto; sin conexión la marca se perdía.
- **Servidor (migración ADITIVA `20261023000000_class_records.sql`, NO aplicada):** tabla nueva `class_scores` (una marca por jugador, pista, tabla y CLASE) con
  auto, PI, clase, nivel de ayudas (arcade/mid/pro/custom/adv), gomas, resumen de mejoras («E3 T2 S1»), vueltas y «enviada después». `submit_class_record` valida igual
  que antes (tiempos posibles, 40 envíos por hora, sólo cuentas con correo) y **la clase la calcula el servidor con el PI** (mismos cortes que el catálogo: D<400, C, B,
  A, S, X≥800). `get_class_leaderboard(pista, tabla, clase)`. La tabla vieja `scores` NO se toca: el APK estable la sigue usando y el nuevo la muestra como «HISTÓRICO».
- **Cliente:** `game/online/class_records.gd` (reglas puras), `online.gd` → `submit_class` / `flush_records` / `class_board`. Si el servidor todavía no tiene la migración,
  la marca va a la tabla vieja como siempre (sin romper nada). **Sin conexión** queda en `profile.d.recQueue` (la mejor por pista/tabla/clase, tope 30) y sale sola
  después de cada sincronización de la cuenta, marcada «enviada después». Las marcas no tocan plata: la cola no puede duplicar premios.
- **Pantallas:** al terminar una carrera, «🌍 Ranking Clase B (PI 523): 3.º de 41» (o «sin conexión: se manda sola»; si no hay puesto fiable no se inventa).
  RANKING: selector TODAS / D…X / HISTÓRICO (arranca en la clase del auto actual), sección nueva de circuitos (Lago, Bosque, Cantera, Montaña, Vórtice, Picada, Drift),
  y cada renglón dice auto, PI, clase y nivel de ayudas. Carreras del mapa y Fugitivo también por clase.
- **Arcade/simulación:** se REGISTRA el nivel en cada marca; las tablas NO se separan por modo (la regla pide separarlas sólo si las mediciones lo demuestran; queda
  la columna para medirlo con datos reales).
- **Pruebas:** `class_records_test` (24 OK: PI/clase/resumen, cola, mejor por clase, tope, reintento vs. descarte, vuelta a la tabla vieja, «enviada después», textos),
  `account_test.sql` +10 casos (corre en GitHub con su Postgres), `scripts_parse_test` OK. **Sin probar en el teléfono ni contra el servidor real.**

## 16/10/2026 (17) · Versión candidata, fase 2: descubrimiento (rama ccr-e7ae3f10-45afj2, NO en main) — PENDIENTE DE APK
- **Pedido:** fase 2 del prompt maestro: «PRÓXIMO OBJETIVO», marcas «?» en el mapa, tutorial breve con ayuda, cola de avisos.
- **Cola de avisos (P1):** antes cada aviso del HUD pisaba al anterior al instante (policía + premio + GPS en el mismo segundo y no se leía ninguno). `game/ui/toast_queue.gd`
  (pura): prioridad policía > premio > información, uno nuevo de más prioridad corta sólo si el actual ya se vio 0,7 s, iguales no se repiten, tope de 4 en espera.
  `race_hud.gd` la usa en `toast()`. Prueba `toast_queue_test` (9 OK).
- **PRÓXIMO OBJETIVO (P1):** tarjeta chica debajo del minimapa (no tapa el volante táctil; no recibe toques salvo IR y ✕). Reglas puras en `game/city/next_goal.gd`: nafta < 15 %
  → estación; evento del servidor en vivo; carrera del mapa descubierta sin ganar más cercana (premio, «cualquier auto», IR = GPS); carrera por descubrir; próximo auto
  («ya te alcanza» → concesionario, o «te faltan $»); bajar un tiempo propio. Nada imposible (nunca un auto pago o de premio, nada a más de 60 km). ✕ lo saca 10 min. Se
  esconde en carrera/persecución/modos y a más de 75 km/h sostenidos. Servicio `game/city/city_goal.gd` (sólo sin conexión). Prueba `next_goal_test` (10 OK).
- **Tutorial breve:** 6 consejos de una vez cada uno (inicio, GPS, círculo de largada, carreras del mapa, garaje, policía), 3 líneas, se van solos a los 15 s; quedan
  en `profile.d.tutorial`. Botón nuevo «❓ AYUDA» en la pausa del mundo abierto (resumen de cómo se gana).
- **Marcas «?»:** las carreras sin descubrir se ven en el mapa grande como «?» (tocarla pone el GPS: «❓ Carrera por descubrir»); las descubiertas muestran tipo, km, premio,
  tu mejor tiempo y «cualquier auto» al tocarlas.
- **Pruebas:** `scripts_parse_test`, `city_modes_test`, `ow_events_test`, `activities_test` OK; capturas reales con el director (la tarjeta no pisa el volante).
  **Sin probar en el teléfono.**

## 16/10/2026 (16) · Versión candidata, fase 1: economía y seguridad (rama ccr-e7ae3f10-45afj2, NO en main)
- **Pedido del dueño:** «prompt maestro definitivo»: implementar la auditoría (docs/AUDITORIA_CICLO_DE_JUEGO.md) por fases en una rama aparte, con APK experimental que no pise el estable.
- **APK aparte:** la rama arma «Dream Racing RC» (`com.gskorp.rallygodot.rc`, release `godot-apk-rc`, contenido `godot-content-4.7-rc`; los autos se reusan de main). Al fusionar hay que deshacer
  esos 4 cambios (`build-godot.yml`, `bootstrap/boot.gd` CHANNEL, `export_presets.cfg`).
- **Reglajes bloqueados (P0):** CONFIRMADO: la pantalla dejaba mover, guardar y cobrar reglajes que la física ignora sin la mejora. Arreglo: reglas puras en `CarBuild`
  (`tune_req`, `tune_unlocked`, `unlock_source`, `tune_sanitize`, `tune_change_count`); el taller muestra 🔒 + «Se habilita con <mejora> nivel N · $», no deja mover, no cobra
  y los presets/«fábrica» no tocan lo bloqueado. Prueba nueva `tune_lock_test` (17 OK: también que con la mejora sí cobra y sí cambia la física).
- **Granja de escapes (P0):** MEDIDA con `escape_farm_test` (física real, IA a fondo por autopista, cacería por desmadre nivel 1): Veltor GTR 3/3 arrestos (21–50 s), R2 2/2
  arrestos (22–30 s) → **−$145.000/h y −$199.000/h** (multas). No hay granja demostrable: NO se tocaron los premios. La prueba queda de guardia (falla si encadenar escapes pasa
  $75.000/h).
- **Premios irrepetibles y progreso (P0):** migración ADITIVA `20261022000000_claims_progress.sql` (**NO aplicada**: el servidor es el mismo que usa el APK estable; aplicarla
  desde la rama dejaría a main sin esa versión en su carpeta de migraciones). Columna `account_econ.claims` (lo cobrado/logrado por «tipo:ref»), `_claim_merge`, el envoltorio
  `_acct_one` (mantiene el vale de 20261021) bloquea para siempre «goal», «cup», «rank», «level», «adv» repetidos (también con el APK viejo) y paga como repetición una
  «primera vez» que la cuenta ya tenía; evento nuevo «prog» (progreso sin plata). Cliente: `profile.earn(…, extra)` + `progress()`, `city_events` (descubierta, victorias,
  mejor tiempo, 1.ª vez + monto de repetición), `rewards.gd` (medalla, marca, jugadas; el bono de copa completa ahora se cobra aparte como «cup»), `account_econ.restore_progress`
  (al sincronizar vuelven logros, copas, medallas, carreras del mapa, Aventura, rango y nivel; nunca empeora). Pruebas: `account_test.sql` (+9 casos, corre en GitHub con su
  Postgres), `account_econ_test` (+6), `ow_events_test` y `rewards_test` siguen OK. Sin la migración el juego anda igual que antes (el servidor ignora los datos nuevos).
- **Compras:** revisado el código (verificación en el servidor, consumo después de confirmar, recibo repetido no acredita, restauración al abrir): no se tocó.

## 15/10/2026 (15) · Temporada semanal, desafío de drift, vale de taller; resumen del juego
- **Pedido del dueño:** «un resumen de cómo quedó el juego, su lógica, cómo funciona el online, cómo se gana y por qué jugarían»; «eventos de una semana tipo
  temporada para ganarse un súper deportivo, una skin, 50.000 pesos en reparaciones/mejoras; eventos de drift: el mayor puntaje en un tiempo limitado se lleva
  una mejora de drifting o un vehículo».
- **Servidor** (`20261021000000_seasons_drift_vouchers.sql`): tipos `drift` y `season`; `_wev_grant` con `voucher`, `skin` (diseño en todos los autos), `tires`
  (gomas en todos los autos) y `car` puntual; premios por puesto con objetos (`top`); `_wev_season_rows` (cada evento cumplido en la semana suma `pts[tipo]`,
  ganarlo suma otra vez), `_wev_rank`, `_wev_close` (paga por puesto carrera, drift y temporada), `_wev_json` (`pts`, `rank`, `players`, mejor de drift),
  `event_start` (la temporada no se juega sola), `event_finish` (drift: sesión de `run_s` y ≤ `cap_rate` pts/s), `event_board` (los tres tipos).
  Vale de taller: columna `account_econ.voucher`, `_acct_json` lo devuelve y `_acct_one` pasa a ser un envoltorio de la de siempre (renombrada `_acct_one_base`)
  que pone el vale delante de los créditos en las compras del taller y en el gasto «tune/repair». Plantillas `temporada`, `drift_finde`, `fuga_vale`;
  `max_open` 4 → 5. Autoprueba al aplicar. Sintaxis con `pglast`, sin choques de nombres `_<tabla>`.
- **Cliente:** `city_modes.gd` (desafío de drift con `race.city_drift`, temporada `_after_ok`, varias fugas con una persecución, textos públicos
  `reward_text`/`prize_text`/`got_text`/`standing_text`/`kind_icon`), `profile.gd` (`voucher`, `can_shop`, `_take_shop` en mejoras, gomas, cambio de gomas,
  piezas y «tune»), `cosmetics.gd` (diseños con vale), `online_profile.gd` (sin vale en el online), `account_econ.gd` (reconcile del vale),
  `menu_chrome.gd` (vale en la barra), `menu_garage.gd` (el reglaje mira créditos + vale), `menu_world.gd` (EVENTOS EN VIVO con premios por puesto y tu lugar).
- **Docs:** `docs/COMO_FUNCIONA_EL_JUEGO.md` (nuevo: resumen para el dueño), `ONLINE_POR_EVENTOS.md`, `PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md`, `MODOS_MUNDO_ABIERTO.md`.
- **Pruebas:** `city_modes_test` (33 OK: dos fugas a la vez, drift, textos), `account_econ_test` (vale), `scripts_parse_test`, `release_test`, `language_test`,
  `ow_events_test`, `police_test`, `spawn_menu_test`. Sin red.
- **Compilación r205 FALLÓ** (`cosmetics_test`: su perfil falso no tiene `_take_shop`): `Cosmetics.buy` ahora usa el vale sólo si el perfil lo tiene (si no, cobra como
  antes). Además la prueba del vale de `account_econ_test` guardaba el perfil con vale en `user://profile.json` y otra prueba lo gastaba: ahora devuelve el archivo
  como estaba. Pasan `cosmetics_test`, `dealer_variants_test`, `online_profile_test`, `tire_wear_test`, `account_econ_test`, `scripts_parse_test`.
- **Migración 20261021 APLICADA:** 15/10/2026 17:45 UTC, flujo «Supabase · aplicar migraciones» n.º 34, sin errores (con la autoprueba).
- **Resultado:** servidor listo; cliente PENDIENTE DE APK.

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
