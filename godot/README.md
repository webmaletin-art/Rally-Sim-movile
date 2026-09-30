# GSkorp Rally — versión Godot

Segunda versión del juego, hecha con **Godot 4.4** (renderizador Compatibility, el más liviano y compatible con celulares).
Convive con la versión HTML (raíz del repositorio) hasta que esta la iguale; después la HTML se retira.

## Cómo está armado (cliente liviano)
| Carpeta | Qué es | Dónde viaja |
|---|---|---|
| `bootstrap/` | Pantalla de arranque: consulta la versión, baja el juego, lo guarda y lo abre | **dentro del APK** (~25 MB con el motor) |
| `game/` | El juego: física, autos, pistas, IA, HUD, modelos, datos | **`content.pck`**, se descarga al abrir la app |
| `tests/` | Pruebas (física contra la versión HTML, IA) | solo desarrollo |

Actualizar el juego = subir cambios a `main`. GitHub Actions (`.github/workflows/build-godot.yml`) compila y publica el
`content.pck` en la release **godot-content**; la app lo baja sola la próxima vez que se abre. **El APK liviano no hay que reinstalarlo.**
Solo se reinstala si cambia el motor o `bootstrap/`.

El workflow también deja el **APK completo** (todo adentro) por si no hay internet o para comparar.

## Reglas para no romper las actualizaciones
- En `game/` **no usar `class_name`**: las clases de un paquete descargado no se registran solas. Usar `const X := preload("res://game/…")`.
- El paquete se descarga desde `https://github.com/webmaletin-art/Rally-Sim-movile/releases/download/godot-content/` (el repositorio tiene que ser público).
- La firma del APK usa `keystore/debug.keystore` (fija), así cada APK se instala encima del anterior sin desinstalar.

## Pruebas locales (sin celular)
```bash
# física: compara con la versión HTML (referencia generada por node tools/godot/js_reference.mjs)
godot --headless --path godot --script res://tests/physics_test.gd
godot --headless --path godot --script res://tests/ai_test.gd
# ver el juego con pantalla virtual y sacar una captura
tools/godot/run_shot.sh /tmp/captura.png --cars=4 --cam=side
```

## Estado
- ✅ Física completa portada y verificada (diferencias de 1e-13 con la versión HTML).
- ✅ Circuito de prueba, Volt con su modelo real, pilotos en pose fija, bosque, contador de rendimiento (botón PRUEBAS).
- ✅ Controles reales portados de la versión HTML: volante, barra, pedal único, tira de cambios, freno de mano, nitro, acelerómetro, tablero.
- ✅ Rendimiento: dibujado a resolución ajustable, árboles por zonas, física en hilos un cuadro adelantada con interpolación.
- ⏳ Fase 2: IA completa, cámaras (incluidas las dos interiores), pilotos animados con IK, humo y efectos, minimapa, editor de controles.
- ⏳ Fase 3: sonido (motor, turbo, flutter, caja), menús, garaje, mejoras, guardado.
- ⏳ Fase 4: modos de juego, duelos, historia y voces.
- ⏳ Fase 5: ciudades y pistas nuevas con los mapas del dueño.
