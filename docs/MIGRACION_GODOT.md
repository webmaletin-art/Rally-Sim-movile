# Migración a Godot — plan y estado

Objetivo: pasar GSkorp Rally de HTML (Three.js) a **Godot 4**, sin perder lo que ya tiene, para tener más rendimiento
(más autos, árboles, ciudades) y una app liviana que se actualiza sola. Todo en **este mismo repositorio**, carpeta `godot/`.
La versión HTML sigue funcionando y sacando su APK hasta que la de Godot la iguale; **recién ahí se borra**.

## Cómo se instala y se actualiza
1. Se instala **una vez** el APK liviano (~25 MB: motor + pantalla de arranque).
2. Al abrirlo, la app consulta `manifest.json` de la release **godot-content-4.5** (el nombre lleva la versión del motor) en GitHub y descarga `content.pck` (el juego) y `cars.pck` (los autos).
3. Cada vez que se sube un cambio a `main`, GitHub Actions compila un `content.pck` nuevo y actualiza esa release.
   La próxima vez que se abre la app, baja lo nuevo. **No hay que reinstalar el APK.**
4. Si no hay internet, usa el último juego guardado. Si es la primera vez, pide conexión.
5. Solo se reinstala el APK si cambia el motor (versión de Godot) o `godot/bootstrap/`. Al subir de Godot 4.4 a **4.5.1** (12/10/2026, por las páginas de 16 KB que exige Google Play) hay que reinstalar el APK una vez: los paquetes de 4.5 no los lee un motor 4.4, así que cada versión del motor baja de su propia release.
6. El workflow también deja un **APK completo** (todo adentro) para probar sin descarga.
Cuando esté en la Play Store, los modelos de autos nuevos pueden ir en `content.pck` sin actualizar la tienda.

## Qué pasa con cada parte de la versión HTML
| Parte HTML | En Godot | Estado |
|---|---|---|
| Física (`js/main.js` → Physics) | `godot/game/physics/vehicle_physics.gd`, traducción línea por línea | ✅ verificada (1e-13) |
| Datos de autos (`VEHICLES`) | `godot/game/data/vehicles.json` (se genera de `main.js`) | ✅ |
| Mejoras y ajustes (`js/carbuild.js`, `js/data.js`) | `godot/game/data/` (`catalog.json`, `car_build.gd` idéntico al JS a 1e-16, `profile.gd`, `rewards.gd`, `ai_cars.gd`) | ✅ |
| Modelos GLB (autos, ruedas, piloto) | Godot los abre directo | ✅ Volt · ⏳ Genesis, pick-up, camión (hay que rehacerlos: eran procedurales) |
| Pistas (`Track`, `OffroadTrack`, `TrenchTrack`) | `godot/game/track/` | ✅ rutas (bosque, lago, cantera, montaña, bajada) · ⏳ drift, estacionamiento, valle abierto, trinchera |
| IA (`js/ai.js`) | `godot/game/ai/ai_driver.gd` | ✅ idéntica a la del HTML (vuelta por vuelta) · ⏳ mejorar en la montaña larga |
| Pilotos (`js/pilot.js`, `js/cockpit.js`) | `godot/game/car/rig_pilot.gd` (IK), `crew_motion.gd` (fuerzas G, manos, pies), `cockpit.gd` | ✅ Solo se dibujan con las cámaras interiores (los vidrios son polarizados). Falta: espejos con reflejo, lluvia en el parabrisas, hoja de notas con texto |
| Cámaras (4 de seguimiento, libre, capó, paragolpes, casco, atrás de los pilotos) | `godot/game/car/camera_rig.gd` | ✅ (la cámara libre con el dedo falta) |
| Sonido (Web Audio: motor, turbo, flutter, caja, gomas, viento, lluvia) | `godot/game/audio/car_synth.gd` (mismos filtros y osciladores, verificado contra las fórmulas de Web Audio) + `car_audio.gd` | ✅ Sin música ni efectos de menú todavía |
| Voces del copiloto e historia (`audio/`) | Directo (.ogg / .wav) | ⏳ |
| Menús, garaje, HUD (`js/ui.js`…) | `godot/game/ui/menu*.gd` (inicio, carrera, rápida, garaje, concesionaria, taller, ajuste, pintura, logros, opciones, resultados) + `race_hud.gd` + sala 3D `showroom.gd` con piloto y copiloto posando | ✅ primera versión · ⏳ editor de controles |
| Modos: carrera, drift, rush, estacionamiento, mundo, duelos, historia | `godot/game/session.gd` | ✅ carrera y contrarreloj y radar sobre rutas · ⏳ drift, rush, estacionamiento, mundo, duelos · historia bloqueada (decisión del dueño) |
| Guardado (`localStorage`) | `user://profile.json` (`profile.gd`) | ✅ · ⏳ importar el progreso de la versión HTML |

## Decisiones del dueño (Godot)
- **Modo historia**: queda **bloqueado** ("próximamente"), sin portar la historia actual: se va a rehacer. Sí se usan sus mapas/carreras.
- **Voces del copiloto**: solo en las carreras oficiales de la campaña (no en mundo abierto, drift, pruebas ni mapa de test).
- **Tripulación**: no se dibuja desde afuera (vidrios polarizados); solo con las cámaras interiores, con física realista (frenada, aceleración, cambios, freno de mano, pies).
- **Menú/garaje**: el auto en 3D con el piloto y el copiloto parados a su lado (brazos cruzados, mano en la cintura, charlando, mirando el auto), cambiando de pose; al elegir auto o pintura lo analizan.
- **Filtro de cámara propio** ("Lente Rally": viñeta, color de cine, desenfoque radial con la velocidad, grano) para que los modelos simples se vean mejor; sin copiar los estilos de la versión web.
- **Calidad intermedia**: árboles simples, sombras suaves y claras, el resto lo hacen los efectos. La física es lo principal.
- **Mapas propios**: el motor tiene que poder cargar mapas hechos por el dueño (JSON + modelos 3D con edificios y paredes).

## Fases
0. ✅ **Base + prueba de fuego**: proyecto, APK liviano con descarga, CI, física verificada, escena con muchos autos/árboles/pilotos y contador de rendimiento.
1. ⏳ **Jugar bien**: IA completa, cámaras interiores, pilotos con IK, humo, marcas de frenada, sonido.
2. ⏳ **Menús y garaje**: HUD, editor de controles, garaje, mejoras, ajuste, guardado.
3. ⏳ **Modos y contenido**: eventos, mundo abierto, duelos, historia y voces.
4. ⏳ **Lo nuevo**: ciudades y pistas con los mapas del dueño, más árboles y autos.
5. ⏳ **Retiro de HTML**: cuando la versión Godot iguale a la HTML se borra `js/`, `css/`, el HTML y `build-apk.yml`,
   y `godot/` pasa a ser la raíz del juego.

## Reglas
- En `godot/game/` **no usar `class_name`** (las clases de un paquete descargado no se registran solas): usar `preload`.
- Toda pieza portada lleva su prueba: física contra la referencia JS (`tools/godot/js_reference.mjs`), IA en pista, etc.
- El paso de física va a 120 Hz con paso fijo y **un auto por hilo** (`WorkerThreadPool`).
- Renderizador **Compatibility** (OpenGL ES 3): el más compatible con teléfonos de gama baja.

## Riesgos conocidos
- **GDScript es ~3 veces más lento que el JavaScript del navegador** en la física (medido). Se compensa repartiendo autos
  en hilos; si no alcanza, la física se puede pasar a C++ (GDExtension) sin cambiar nada más.
- El paquete se baja de GitHub Releases: el repositorio tiene que ser **público** (o usar otro hosting).
- Play Store: la app descarga contenido del juego (recursos y scripts). Está permitido mientras no se salte las políticas de la tienda.


## Estado tras la r24 (Dream Racing)
- Pistas «solo camino»: guardarraíl (chapa en asfalto, valla de madera en tierra) con colisión, franja de árboles detrás, pasto con textura y matas, subidas y bajadas suaves, sin línea amarilla (solo el modo aventura la usará).
- Carrera: choques entre autos, ayuda de trazada, minimapa, niveles de simulación (arcade / intermedio / simulador total / personalizado).
- Menús: vistas previas de las pistas (`godot/game/ui/tracks/*.jpg`, se generan con `--viewat=… --hidecars --nohud --fx=0,0,0`), pruebas de autos en la concesionaria, opciones por categorías también en la pausa.
- Interior: tacómetro con luces de cambio detrás del volante, miradas con vida (`car/gaze.gd`), capó con toma de aire y pasadores, espejos con reflejo, red en el triángulo de la ventana.
- Sala 3D: la tripulación camina alrededor del auto (pasos con cinemática inversa) y hace gestos.
- El acelerómetro necesita la APK nueva: los sensores vienen desactivados por defecto en Godot 4.4 y se activan en `project.godot` (`input_devices/sensors`).

## Evaluación 15/10/2026: ¿actualizar el motor por los cierres nativos? (prompt maestro del dueño)
Fuentes oficiales consultadas el 15/10/2026: `godotengine.org/blog/release` (lista de versiones), notas de 4.5.2 y 4.7.2, `developer.android.com/google/play/requirements/target-sdk`, y el código fuente de cada versión (`platform/android/java/app/config.gradle`, `scene/main/canvas_layer.cpp`, `scene/main/http_request.cpp`).

| | **4.5.1** (actual, 15/10/2025) | **4.5.2** (19/3/2026) | **4.6.3** (20/5/2026) | **4.7.2** (18/8/2026, la estable más nueva) |
|---|---|---|---|---|
| Rama mantenida | no (4.7 es la actual) | no | no (terminó con 4.7.1) | **sí** |
| `targetSdk` / `compileSdk` por defecto | 35 / 35 | 35 / 35 | **36 / 36** | **36 / 36** |
| build-tools · NDK | 35.0.0 · r28 | 35.0.1 · r28 | 36.1.0 · r29 | 36.1.0 · r29 |
| Java | 17 | 17 | 17 | 17 |
| Arreglos que nos tocan | — | ANR al cerrar (hilo de render), cuelgue de Adreno 5xx en Vulkan (no usamos Vulkan); nada de Mali ni de viewports | — (no revisado uno por uno) | ninguno nombrado de Android/Mali/OpenGL en las notas de 4.7.2 |
| Fallo de `CanvasLayer.custom_viewport` (ver REGISTRO 15/10) | sí | sí | sí | **sí (mismo código)**: lo arregla el juego, no el motor |
| HTTPRequest | deja el archivo a medio bajar | igual | — | **borra el archivo a medio bajar** al fallar (la descarga por tramos anda con las dos) |

**Google Play:** desde el 31/08/2026 las apps nuevas y las actualizaciones tienen que apuntar a **Android 16 (API 36)** (prórroga posible hasta el 1/11/2026). Nuestro AAB **ya apunta a 36 con 4.5.1** (`build-aab.yml` sube `compileSdk` a 36 y el preset «Google Play (AAB)» tiene `target_sdk=36`), así que Play **no obliga** a cambiar de motor hoy; pero 4.5 no está pensado para la 36 (Godot recién la adopta en 4.6) y los cambios de comportamiento de Android 16 (pantalla de borde a borde obligatoria, gesto de volver) sólo los cubre oficialmente 4.6+. El APK liviano (fuera de Play) usa 35 y no le afecta. Formato: AAB con páginas de 16 KB y paquete install-time (sin cambios), sólo arm64 (+ armeabi-v7a en el AAB).

**Probado acá con Godot 4.7.2 (el mismo commit que `main`):** importa el proyecto entero sin errores (sólo 8 avisos «load-time scene» de glTF, iguales a 4.5.1); la batería de GitHub completa (74 pruebas, ~45 min) **pasa entera** con 4.7.2: la única falla fue `boot_download_test`, que destapó que 4.7 borra el archivo a medio bajar (corregido con la descarga por tramos: ahora pasa con los dos motores); en GitHub la rama experimental (r183) **compiló el APK con las plantillas 4.7.2 y publicó el contenido** (`godot-content-4.7`, versión r183-374ecfa); una captura de la cabina sale igual con los dos motores. **No probado:** el teléfono (Mali-G57), el audio real, el tacto, la exportación Android con las plantillas 4.7.2 (la arma GitHub en la rama experimental).

**Recomendación:** **4.7.2**, como experimento controlado y SIN fusionar todavía: es la única rama mantenida, trae la API 36 de fábrica y el proyecto pasa las pruebas sin cambios de código. 4.5.2 sería el paso más corto pero no arregla nada nuestro (ni Mali ni OpenGL ni viewports) y sigue en API 35. 4.6.3 ya no recibe arreglos. **Actualizar el motor no es la solución probada de los cierres**: primero hace falta la lápida (ver REGISTRO 15/10); si la lápida apunta al driver o al motor, la versión 4.7.2 se compara en el mismo teléfono.

**Rama experimental `exp/godot-4.7.2`** (no tocar `main` hasta tener resultados): igual a `main` + `GODOT_VERSION: 4.7.2`, `config/features` «4.7», SDK 36.1.0, y se publica APARTE: contenido en la release `godot-content-4.7`, APK en `godot-apk-4.7-prueba` (`DreamRacing-4.7-PRUEBA.apk`), y la app se instala AL LADO de la normal («Dream Racing 4.7 PRUEBA», `com.gskorp.rallygodot.prueba47`; su perfil, su cuenta iniciada y su descarga son aparte). **Punto de retorno:** `main` no cambió de motor; el último commit de `main` antes de la rama es `15c3ae2`.
**Comparar en el mismo teléfono** (con «Mostrar FPS» y «COPIAR REGISTRO» después de cada cierre): inicio y menú, drift, carrera rápida en Quarry, Aurelia/Dream City, transiciones (entrar y salir 5 veces seguidas), audio, controles, física; anotar FPS, cierres y la lápida. **Para fusionar:** que en varias sesiones no se cierre (o se cierre menos con evidencia), que no haya regresiones visibles, y revertir en la rama los nombres «PRUEBA» (paquete, nombre, release del APK y disparador del flujo) antes de pasarla a `main`.
