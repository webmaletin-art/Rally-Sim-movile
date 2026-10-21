# Estado actual por módulo

Una sección por sistema, con lo que anda, lo que falta y lo que espera prueba en el teléfono. El detalle técnico vive en el documento de cada sistema (ver `docs/INDICE_TECNICO.md`);
el historial de intervenciones, en `docs/REGISTRO_TECNICO.md`. Leyenda: ✅ hecho y probado en la computadora · 📱 falta probar en el APK · 🚧 en curso · ⛔ bloqueado.

## Sexta tanda («último retoque», 20/10/2026, [B]) — `docs/REGISTRO_TECNICO.md` → 20/10 [B] sexta tanda
- ✅📱 **Modo de prueba guiado** (baldosa en el inicio, una sola vez): guía antes de entrar, armado (camioneta, GT, clásico o superdeportivo · nivel de simulación · drift por puntos/libre o carrera por el camino de tierra o entre los edificios · ayuda de reglaje), pista con lomos de burro, punto de nafta y 4 autos haciendo drift; pausa con la guía en dibujos a la derecha y SALIR DE LA PRUEBA con doble toque. **La voz de Claudio es opcional:** sin audios se ve el subtítulo (`docs/GUION_VOZ_GUIA.md`).
- ✅📱 Pausa: cambiar el nivel de simulación en cualquier modo menos la Aventura; sin «taller de prueba» (queda el del garaje y los talleres del mundo). Volante real en simulación total y PERSONALIZADO.
- ✅📱 Calles de Dream City: bocas soldadas, cruces a la misma altura, paredes de relleno recortadas, terreno que no tapa el asfalto (`city_streets_test`). Policía con jurisdicción por ciudad y reconocimiento del auto. Taller con COMPRAR fijo arriba y lista que no salta. Cabinas del monoplaza y el buggy.
- ✅📱 Sin Nitro ni alerones; precios por escalones («cada dos autos, el mismo precio»); migración `20261025120000` con devolución probada en un Postgres local.
- ✅ Guías nuevas: `docs/GUIA_SQL_SUPABASE.md`, `docs/GUIA_PLAY_CONSOLE_PASO_A_PASO.md`, `docs/QUE_FALTA.md`.

## Versión candidata (rama ccr-e7ae3f10-45afj2; **fusionada a main el 21/10/2026**, commit `e953c9b`) — `docs/VERSION_CANDIDATA.md`
- ✅📱 Fases 1–5 validadas técnicamente (pruebas de Godot y SQL en GitHub); **ninguna probada en un teléfono**. APK «Dream Racing RC» en la release `godot-apk-rc` (se instala al lado).
- ✅📱 Fase 5: desafíos del día (LOGROS, 1.ª página), metas de colección X/N, hitos de temporada, horarios rotativos, cacería para principiantes (apagada hasta publicar).
- ✅ Fase 6: compras revisadas sin cambios (verificación con Google, recibo único, restaurar). Límites: reembolsos no se quitan solos; un desbloqueo queda en la 1.ª cuenta del juego.
- ✅ Migraciones 20261022, 20261023, 20261024 y 20261025120000 **aplicadas** el 21/10/2026 00:02 UTC (flujo «Supabase · aplicar migraciones» n.º 35, sin errores; autorización expresa del dueño). `caza_inicial` sigue apagada. Detalle: `docs/GUIA_SQL_SUPABASE.md` → «Historial».

## Estabilidad (cierres nativos)
- ✅📱 **Causa confirmada y corregida (15/10):** bucles de sonido que leían fuera de los datos (hilo de audio, `AudioStreamPlaybackWAV::decode_samples`) → `game/audio/wav_loop.gd`. Falta confirmar en el teléfono.
- ✅📱 Los autos ya no largan marcha atrás (caja automática con el freno de mano de la largada).
- 🚧📱 El juego se cierra de golpe con **ERROR NATIVO (SIGSEGV)** según Android, no por memoria: en el mundo abierto, en carrera rápida (Quarry) y en drift (registros r180 del 14/10). **Causa NO confirmada** (`docs/REGISTRO_TECNICO.md` → 15/10).
- ✅ Corregido (15/10): las capas del frame reducido (`ui/frame_res.gd`) ya no salen del árbol apuntando a la SubViewport: desaparece el error `child_order_changed` y un SIGSEGV que se reproducía en la PC (no está probado que sea el del teléfono). Antes: carrera entre hilos en la región (`RegionData._cum`, 14/10).
- ✅ El registro trae la **lápida** de Android del último cierre nativo (`game/diag/tombstone.gd`): hilo, biblioteca (motor o driver), dirección y logcat del instante. 📱 Falta el primer registro con `[lápida]`.
- ✅📱 **Calidad gráfica a mano** (15/10): BAJA / NORMAL / ALTA / ULTRA en vez de la calibración automática (se cerraba al armar el centro de Dream City).
- ✅📱 **Frame reducido apagado** (15/10 tarde): la calibración se cerraba al activarlo en dos teléfonos y con los dos motores. Ahora sólo baja la ESCALA 3D; la opción «Resolución de frame» no se muestra.
- ✅📱 Descarga del APK liviano (13/0 = tiempo agotado: había un tope de 30 s para TODA la descarga): sin tope, vigilante de trabas, sigue con Range, reintenta solo. **Hay que reinstalar el APK.**
- 🔎 Motor: evaluado Godot 4.7.2 (ver `docs/MIGRACION_GODOT.md` → «Evaluación 15/10/2026»); 4.5.1 sigue en `main`.
- ✅ «COPIAR REGISTRO» en Acerca de y en Opciones → Sonido, **sólo en la versión candidata** (la pública no lo trae: `Release.internal()`).

## Mundo abierto y región
- ✅ Dream City + región de ~2.700 km (rutas, pueblos, estaciones, peajes, GPS, mapa). 📱 retoques del 13/10.
- ✅📱 Todo abierto otra vez (pedido del dueño: la policía es el obstáculo entre ciudades). El sistema de sectores sigue listo (`game/data/sectors.json`, `open_all`; `docs/REGION.md`).
- ✅📱 Fachadas: cajas cerradas (costados enteros) y ninguna sobre una calle (antes 49).
- ✅📱 Ciudades alcanzadas: para aparecer en otra ciudad o pueblo hay que haber llegado manejando (`city/city_reach.gd`).
- ✅📱 4 concesionarios con vidriera y 3 autos reales cada uno (general, Rally & 4x4, Clásicos, Motorsport); los de especialidad venden sólo su rubro (`docs/MUNDO_ABIERTO.md`).
- 🚧 Reorganización del centro (autopistas elevadas, túneles nuevos): ver `docs/REGISTRO_TECNICO.md`.
- ✅📱 (15/10) Peatones sólo en la Plaza Aurora (con reja baja, chicos y paseantes) y lavando autos en los concesionarios; no llueve bajo techo (estacionamiento, rampas, túneles, gasolineras); faros desde la trompa, más largos y fuertes; capó sin brillos «arrugados» desde la cabina (`docs/REGISTRO_TECNICO.md` → 15/10 (11)).
- 🔎 Rutas mal unidas / pasto en caminos: las pruebas de la región dan 0; falta que el dueño marque dónde lo ve. Puentes y pasos a distinto nivel: sin hacer.

## Pantalla de juego y menús (19/10, [B])
- ✅📱 Sin texto de eventos en la partida: punto rojo en la pausa y en EVENTOS; pantalla de eventos propia con tarjetas e imágenes, IR AL EVENTO (el GPS guía) y SALIR DEL EVENTO (`ui/events_ui.gd`). Placa de policía arriba a la derecha. Talleres, concesionarios y gomerías se registran en el mapa al pasar a menos de 70 m.
- ✅📱 Faros con luz hasta los bordes de la calle (`city/city_clock.gd`). Volante de la pantalla trabado en ±135° donde la dirección llega al tope (`ui/controls.gd`).
- ✅📱 Asfalto y piso de la física a la misma altura, rayas a 1,2 cm (ruedas ya no «enterradas»); terraplén y cuneta junto a las rutas de campo (Ruta Panorámica 70 cuadra 37). La nieve sobre 64 m es de diseño: 🔎 pregunta al dueño.
- ✅📱 Región: 1 cuadrado por cuadro al cargar (antes 2): menos tironcitos, **sin medir en teléfono**.
- ✅📱 (20/10) Dream City sólo choca con edificios (fachadas y edificios especiales), objetos y vallas: esquinas, cruces y huecos libres; las rutas de campo conservan su pared (`city/city_layout.gd` → `wall_push`).
- ✅📱 (20/10) Esquinas redondeadas en los cruces, veredas y rayas recortadas contra las otras calzadas (una sola regla: `ribbon_poly`, `prepare_fillets`, `clip_obstacles`), piso de la vereda a la altura del cordón (ruedas ya no hundidas en el borde).
- ✅📱 (20/10) El terreno de la ciudad no tapa el asfalto de las rutas de campo ni de la colina (`world/terrain_cap.gd`); la banquina de las rutas de campo se cubre de nieve desde 54–64 m (`WorldSurfaces.snow_k`).
- ✅📱 (20/10) Taller de prueba del mundo abierto sin respawn; mapa/GPS escondido con cualquier menú; botón de luces (Auto/Encendidas/Apagadas); GPS que recalcula a los 0,5 s de salirte; placa de policía arriba a la izquierda.

## Versión para publicar (20/10, [B] 4.ª tanda) — `docs/REGISTRO_TECNICO.md` → 20/10 05:30
- ✅📱 **Fluidez:** las cuadras de la ciudad se calculan en un hilo y el cuadro sólo las sube en pasos cortos (`CityWorld`, válvula `threaded = false`). En la computadora, a 180 km/h por la ruta de 42 km: 0 cuadros de más de 40 ms (antes p99 68 ms, máximo 120 ms), `update_around` ≤ 3 ms. **Sin medir en un teléfono.** `city_stream_test`.
- ✅📱 **Huecos entre edificios** cerrados con paredes invisibles (7,3 km), Plaza Aurora cerrada, Plaza y Parque del Drift abiertos (`city_leaks_test`: ninguna celda alcanzable adentro de las manzanas salvo 13 junto al Parque del Drift).
- ✅📱 **Veredas planas** (un plano a 1 cm del asfalto, sin cordón); piso de la física igual.
- ✅📱 **Policía:** a 70 km/h o más no arresta; la barra sube si te frenan (pegado y despacio) o si te quedás quieto con patrulleros cerca (`police_bust_test`).
- ✅📱 **Nivel de simulación:** lo elegido al largar es lo único que manda; la pausa sin OPCIONES/reglajes/taller salvo en Carrera rápida y pruebas; se pregunta en cada carrera menos en la Aventura; PERSONALIZADO con «Ángulo de dirección» 70–130 % (`sim_level_test`).
- ✅📱 **Circuitos de Dream City** como lazos limpios (antes con «púas»), minimapa con sólo el circuito y mapa grande con la ciudad apagada durante la carrera (`street_closure_test`, `lab_city_test`). 🔎 «GPS amarillo» interpretado como el texto/línea amarilla: confirmar con el dueño.
- ✅📱 **Calidad automática** más flexible (mediana sin tirones, 36 FPS, perdón del 10 %, Mali-G57/G68 en gama media); todos recalibran una vez (`VERSION` 4).
- ✅📱 **Aventura:** menos daño de ruedas y se reinicia en cada etapa; 5 etapas libres (`adv_rules_test`).
- ✅📱 **Menús:** texto que baja la letra en vez de cortarse con «…»; «Acerca de» con enlaces web a privacidad, términos y borrado de cuenta.
- 🔎 **Auto «Ren…»:** no existe un auto con ese nombre; sus cabinas más rotas son Strix Vandal RS y Chakal Dune R. Falta que el dueño diga cuál.
- ✅ **SQL:** 21 migraciones aplicadas en orden y repetidas en un Postgres 16 local (`ECONOMIA_ONLINE_TEST OK`, `CUENTA_TEST OK`). ✅ 20261022 → 20261025120000 aplicadas al servidor real el 21/10/2026 00:02 UTC (ver `docs/GUIA_SQL_SUPABASE.md` → «Historial»).

## Versión pública vs versión candidata, práctica de la Aventura y nombre online (20/10, [B] 5.ª tanda) — `docs/REGISTRO_TECNICO.md` → 20/10 11:00
- ✅📱 **La versión pública (main y Google Play) no trae modo desarrollador ni «COPIAR REGISTRO»:** `Release.internal()` = editor o versión candidata marcada (`game/build_channel.txt`, que escribe el flujo sólo fuera de main); `Release.dev()` lo exige. En la RC todo sigue igual (`public_build_test`).
- ✅📱 **Carrera rápida → Ruta de los Sueños (práctica) ya no pisa el avance real de la Aventura ni da el DR Bisonte XR/$20.000 de la última etapa** (`Adventure._save()` y `_finish_adventure()`); las etapas de pago nunca se pudieron elegir ahí (`practice_test`, demostrado que fallaba antes).
- ✅📱 **El apodo viaja con la cuenta:** en otro celular se trae el nombre que ya tiene la cuenta (`Online.fetch_name`, `OnlineSocial.adopt_nick`) en vez de pedir uno nuevo, y sin apodo elegido no se manda «Piloto» (pisaba el de la cuenta). `nick_account_test`. 🔎 **Las monedas «borradas»:** no hay ningún camino que borre créditos de la cuenta; falta el relato exacto del dueño (¿modo desarrollador en el primer celular? ¿cuál número veía?).

## Carreras del mundo abierto
- ✅📱 (19/10) Las carreras largan a 100 m o más de cualquier taller, se cierran las calles que salen del recorrido (vallas) y la pista se ve en el mapa y en el GPS (`city/street_closure.gd`).
- ✅📱 79 eventos para descubrir (sprint, rally, montaña, velocidad, picada, circuito urbano, huida, persecución), en el mapa, con rivales adaptables y premios que valida el servidor (`docs/CARRERAS_MUNDO_ABIERTO.md`). Apagados en el online.

## Policía
- ✅📱 Controles policiales en las 176 rutas largas entre ciudades (patrulleros en la banquina), persecución, interceptor de frente, arresto, multa y comisaría de Dream City (`docs/POLICIA.md`). Probado en la computadora; falta sentirlo en el teléfono.
- ✅📱 (15/10) Desmadre (choques, objetos rotos y velocidad en la ciudad llaman a la policía) y modos FUGITIVO y CAZA RECOMPENSAS desde la pausa (`docs/MODOS_MUNDO_ABIERTO.md`).
- ✅📱 (15/10) Online: 2 patrulleros por jugador fuerte, implacable con grupos de 3+, aviso y paso despacio para 1–2 jugadores, y los patrulleros de cada uno a la vista de todos (`online/police_net.gd`). Falta probar con 2 teléfonos.

## Vehículos
- ✅ 26 autos con textura propia (`docs/AUTOS.md`).
- ✅📱 DRP Interceptor y STRIX Vandal RS en el catálogo (28). Monoplaza DR-1 especial bloqueado (`Release.SPECIAL_OPEN`). ⛔ Moto: falta física de dos ruedas.
- ✅📱 18 diseños de pintura, 8 interiores y 6 volantes comprables (Volante Pro 3D del dueño) en el taller → Pintura (`docs/PERSONALIZACION.md`). ✅ Migraciones `20261015000000_catalog_28_cosmetics.sql` (14/10 20:26 UTC) y `20261016000000_cosmetics_volantes_pro.sql` (15/10 01:38 UTC) aplicadas. 📱 Falta probar una compra con la cuenta.

## Online
- 🚧📱 **[B] (19/10) Eventos sólo en el modo online y fuera de la pantalla de juego:** pausa → 📅 EVENTOS con tarjetas, numerito en el botón de pausa, «EVENTOS DE HOY» con imágenes en el menú online; el mundo abierto offline ya no tiene eventos ni manda récords (`docs/ONLINE_POR_EVENTOS.md`). Rama RC, falta probar en el APK.
- ✅📱 **(15/10 noche) Temporada semanal, desafío de drift y vale de taller:** la temporada suma puntos de todos los eventos (1.º el Veltor GTR), el desafío de drift (90 s en la Plaza de Drift, 1.º el KL5), premios nuevos (vale de taller, diseño y gomas para todos los autos) y varias fugas con una misma persecución (`docs/COMO_FUNCIONA_EL_JUEGO.md`). Migración `20261021000000` aplicada (15/10 17:45 UTC).
- ✅📱 **(15/10 noche) Online de EVENTOS DE CLASIFICACIÓN:** el servidor programa y valida eventos del mundo (cacería de las 22 con 3 autos, fugas, contrarreloj entre ciudades, carrera de la semana) con premios justos y autos alquilados; cada uno juega en su mapa (`docs/ONLINE_POR_EVENTOS.md`).
- ✅📱 **(15/10 noche) Online «por datos»:** sin tiempo real ni encontrarse (pantalla «PRÓXIMAMENTE»); cuenta, plata, autos, ranking (récords de las carreras del mundo abierto, racha del Fugitivo, ganadores) y la RECOMPENSA global. El tiempo real se habilita con `app_flags.pvp` = true en Supabase (`docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md`).
- ✅📱 **Abierto desde el 15/10/2026** (autorización del dueño): `Release.ONLINE_OPEN` y `Release.REALTIME` en true. Cuenta obligatoria y economía en el servidor. Garaje online en el hub («MI GARAJE ONLINE») y compras en los 4 concesionarios (migración `20261017000000_online_garage_dealers.sql`, ver `docs/REGISTRO_TECNICO.md` → 15/10 (8)). 📱 Falta la prueba con 2 teléfonos y, en el panel de Supabase, «Allow public access» = OFF en Realtime.

## Compilación
- ✅ Cada push a `main` arma el APK liviano + `content.pck` + `cars.pck` con **Godot 4.7.2** (release `godot-content-4.7`; desde el 15/10/2026, antes 4.5.1). `cars.pck` sólo se vuelve a bajar si cambian los autos.
