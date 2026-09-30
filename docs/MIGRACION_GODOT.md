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
| Pilotos (`js/pilot.js`, `js/cockpit.js`) | `godot/game/car/rig_pilot.gd` (IK), `crew_motion.gd` (fuerzas G, manos, pies), `cockpit.gd` | ✅ Solo se dibujan con las cámaras interiores (los vidrios son polarizados). Falta: espejos con reflejo, lluvia en el parabrisas, hoja de notas con texto |
| Cámaras (4 de seguimiento, libre, capó, paragolpes, casco, atrás de los pilotos) | `godot/game/car/camera_rig.gd` | ✅ (la cámara libre con el dedo falta) |
| Sonido (Web Audio: motor, turbo, flutter, caja, gomas, viento, lluvia) | `godot/game/audio/car_synth.gd` (mismos filtros y osciladores, verificado contra las fórmulas de Web Audio) + `car_audio.gd` | ✅ Sin música ni efectos de menú todavía |
| Voces del copiloto e historia (`audio/`) | Directo (.ogg / .wav) | ⏳ |
| Menús, garaje, HUD, editor de controles (`js/ui.js`…) | Escenas de Godot (Control) | ⏳ (es lo más largo) |
| Modos: carrera, drift, rush, estacionamiento, mundo, duelos, historia | `godot/game/modes/` | ⏳ |
| Guardado (`localStorage`) | `user://save.json` (con botón para importar el progreso de la versión HTML) | ⏳ |

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
