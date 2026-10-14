# Registro técnico de intervenciones

Una entrada por intervención, la más nueva arriba. Antes de tocar un sistema, buscar acá su nombre: si el problema ya se trabajó, seguir desde el último diagnóstico.
Resultado: RESUELTO · PARCIAL · FALLIDO · BLOQUEADO · PENDIENTE DE APK. Una hipótesis no es una causa confirmada.

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
- **Resultado:** PENDIENTE DE APK + **aplicar la migración** (sin ella el servidor devuelve las compras de cosméticos y de los dos autos nuevos).

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
