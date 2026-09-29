# Migración a Godot — plan y estado

Objetivo: pasar GSkorp Rally de HTML (Three.js) a **Godot 4**, sin perder lo que ya tiene, para tener más rendimiento
(más autos, árboles, ciudades) y una app liviana que se actualiza sola. Todo en **este mismo repositorio**, carpeta `godot/`.
La versión HTML sigue funcionando y sacando su APK hasta que la de Godot la iguale; **recién ahí se borra**.

## Cómo se instala y se actualiza
1. Se instala **una vez** el APK liviano (~25 MB: motor + pantalla de arranque).
2. Al abrirlo, la app consulta `manifest.json` de la release **godot-content** en GitHub y descarga `content.pck` (el juego).
3. Cada vez que se sube un cambio a `main`, GitHub Actions compila un `content.pck` nuevo y actualiza esa release.
   La próxima vez que se abre la app, baja lo nuevo. **No hay que reinstalar el APK.**
4. Si no hay internet, usa el último juego guardado. Si es la primera vez, pide conexión.
5. Solo se reinstala el APK si cambia el motor (versión de Godot) o `godot/bootstrap/`.
6. El workflow también deja un **APK completo** (todo adentro) para probar sin descarga.
Cuando esté en la Play Store, los modelos de autos nuevos pueden ir en `content.pck` sin actualizar la tienda.

## Qué pasa con cada parte de la versión HTML
| Parte HTML | En Godot | Estado |
|---|---|---|
| Física (`js/main.js` → Physics) | `godot/game/physics/vehicle_physics.gd`, traducción línea por línea | ✅ verificada (1e-13) |
| Datos de autos (`VEHICLES`) | `godot/game/data/vehicles.json` (se genera de `main.js`) | ✅ |
| Mejoras y ajustes (`js/carbuild.js`, `js/data.js`) | `godot/game/data/` + `car_build.gd` | ⏳ |
| Modelos GLB (autos, ruedas, piloto) | Godot los abre directo | ✅ Volt · ⏳ Genesis, pick-up, camión (hay que rehacerlos: eran procedurales) |
| Pistas (`Track`, `OffroadTrack`, `TrenchTrack`) | `godot/game/track/` | ⏳ (hoy solo un circuito de prueba) |
| IA (`js/ai.js`) | `godot/game/ai/` | ⏳ (hoy una IA simple; falta el perfil de velocidad) |
| Pilotos (`js/pilot.js`, `js/cockpit.js`) | `godot/game/car/pilot.gd` | ⏳ (hoy pose fija; falta IK y fuerzas G) |
| Cámaras (chase, capó, casco, atrás de los pilotos) | `godot/game/camera/` | ⏳ |
| Sonido (Web Audio: motor, turbo, flutter, caja) | `AudioStreamGenerator` o loops grabados del sintetizador | ⏳ |
| Voces del copiloto e historia (`audio/`) | Directo (.ogg / .wav) | ⏳ |
| Menús, garaje, HUD, editor de controles (`js/ui.js`…) | Escenas de Godot (Control) | ⏳ (es lo más largo) |
| Modos: carrera, drift, rush, estacionamiento, mundo, duelos, historia | `godot/game/modes/` | ⏳ |
| Guardado (`localStorage`) | `user://save.json` (con botón para importar el progreso de la versión HTML) | ⏳ |

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
