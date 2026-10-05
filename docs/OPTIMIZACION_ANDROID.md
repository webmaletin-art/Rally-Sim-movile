# Optimización Android (Etapa 22)

Qué se hizo, sin tocar lo que ya anda bien (calidad automática, resolución dinámica, sombras sólo del auto del jugador):

1. **Presupuesto de CPU de la vida del mundo** (`world/world_life.gd`): cada cuadro se mide cuánto cuestan en total los sistemas (tránsito, estacionados, peatones…) y por separado. Si pasan el tope del perfil (LOW 1,6 ms · MEDIA 2,6 ms · ALTA 4,0 ms) durante 2 s, se **estrangula un escalón** (hasta 3): los topes de autos / estacionados / peatones bajan 20 % por escalón y las frecuencias de actualización 15 %. Con holgura sostenida (mitad del tope durante 6 s) se recupera un escalón. Sin vaivén (hay una franja intermedia donde no cambia). Todo automático.
   * En **Opciones → Gráficos → Mostrar FPS** aparece `VIDA 0.4ms ▼1` (costo de la vida del mundo y escalón de estrangulamiento).
   * Medido en una PC con pantalla virtual: la vida del mundo cuesta ~0,4 ms/cuadro (tránsito 0,2 · peatones 0,15 · estacionados sólo al cambiar de sector). En un teléfono rinde varias veces más lento: ahí actúa el estrangulamiento.
2. **Costo de un cambio de sector** (`spike_ms` en `world_life.stats()`): lo más caro que costó reconstruir lo cercano (para detectar tirones al cruzar una cuadra).
3. **Menú**: el archivo de animaciones de Mixamo (3 MB) ya no se carga entero en memoria al abrir el menú: se lee sólo el índice (4 ms) y cada animación a demanda.
4. **Vidrio polarizado** (camión y demás): antes se veía como un agujero negro; ahora es vidrio oscuro con un reflejo de cielo falso (más claro de costado y hacia arriba), sin transparencia ni costo extra.
5. Ya estaba (etapas anteriores): MultiMesh por sistema (tránsito, estacionados, peatones, semáforos), tope por perfil, sectores activos/simplificados/lógicos, sin luces dinámicas, sin sombras por auto civil.

Prueba: `godot/tests/world_budget_test.gd`.

Pendiente de medir en el teléfono (necesita el APK): FPS reales en Dream City con Vida ON/OFF; si sigue en 30–40 FPS con Vida OFF el cuello de botella es el dibujo del mapa (edificios), no la vida del mundo. La pared blanca lisa que viste en una captura no se pudo reproducir: si vuelve a aparecer, mandá la captura con la posición (el GPS muestra la calle).
