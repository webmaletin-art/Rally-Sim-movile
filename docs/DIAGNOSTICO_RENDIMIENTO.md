# Diagnóstico / rendimiento (registro manual)

**Para qué sirve:** descubrir CON DATOS qué sistema del mundo abierto baja los FPS. El juego **sólo registra**: no hay benchmark, recorridos, bots ni pruebas automáticas. Vos manejás, apagás sistemas, cambiás hora/clima/lugar y apretás **📸 CAPTURAR**.

**Dónde está:** botón **📊** (con los FPS en vivo) al costado izquierdo de la pantalla, en el mundo abierto y en las carreras; también `MUNDO ABIERTO → DIAGNÓSTICO / RENDIMIENTO` en el menú (ver registro, copiar, borrar, y prender/apagar el botón: ajuste `diagBtn`, viene en SÍ).

## Qué muestra y qué hace el panel
- FPS actual, **promedio** y **mínimo** (tramos de 0,5 s) desde el último cambio o captura. Los 2 s siguientes a un cambio no cuentan (el mundo se rearma).
- Escena, ubicación, zona, superficie, clima y hora.
- **Interruptores** (sólo mundo abierto): árboles, edificios, autos civiles, vegetación, decoración, peatones.
  - Árboles: imágenes de árbol de calles y rutas (y su choque). Edificios: fachadas (la pared invisible sigue). Autos civiles: sistemas `traffic` y `parked` de WorldLife, apagados de verdad (`WorldLife.set_muted`). Vegetación: flores, arbustos, pasto de calle y bosque lejano del horizonte. Decoración: farolas, semáforos, bolardos, vallas, carteles (y sus luces). Peatones: sistema `peds`.
  - Apagar uno **no cambia cómo funciona nada más**: `CityWorld.diag_set` sólo deja de dibujar (y de registrar el choque de) esos objetos y rearma las cuadras de a 3 por cuadro.
- **Interruptores de GPU** (sólo mundo abierto; todos arrancan en ON y sólo cambian qué se dibuja, no se borra ni se cambia ningún recurso):
  - 🛣️ **Asfalto**: la calzada. La malla base de cada cuadra (`MeshInstance3D` «base» de `city_world._build_chunk`) tiene una superficie por categoría (terreno, calles, marcas, túnel; guardadas en la meta `diag_roles`) y la de calles mezcla calzada + veredas + cordones + banquina rural en una sola malla/material: se separan por el color de cada cuadrilátero de `_road_segment` (`C_ASPH` calzada, `C_RURAL_SIDE` banquina rural, el resto veredas/cordones). Apagar = copia de la malla con un índice que saltea esos triángulos (`_diag_base`, de a 2 cuadras por cuadro). Las marcas viales, veredas, cordones y el disco de la plaza de drift NO se apagan.
  - 🛤️ **Caminos de tierra**: en la ciudad NO hay caminos de tierra como malla propia (todas las calles son asfalto con la misma textura); lo único «de tierra» transitable es la banquina beige de las rutas rurales (`rural`/`shortcut`/`scenic`). Es lo que apaga este interruptor.
  - 🌱 **Terreno / césped**: la superficie «terreno» de la malla base de cada cuadra (grilla de 16 m). Queda el plano de suelo de 30 km (color de la lejanía) y el mar. La vegetación es otro interruptor.
  - 🌫️ **Niebla**: `race.env.fog_enabled` (la niebla de siempre; no se tocan color ni distancias). Sin niebla el cielo se ve más azul porque la niebla también lo tiñe (el cielo no se toca). Compatibility: sin niebla volumétrica.
  - ⛰️ **Horizonte / montañas**: `city_world._hz` (las lomas, 72 triángulos) y los anillos del bosque lejano (`_hz_trees`, que además siguen apagándose con Vegetación). El cielo, el plano de suelo, el mar, la cámara y el far clip no se tocan.
  - ☁️ **Cielo**: sin interruptor en esta ronda; en el registro figura «Cielo: ON».
- **Hora y clima** a mano: DÍA / ATARDECER / NOCHE (el reloj queda quieto) y SOL / LLUVIA; ↺ AUTO vuelve a los del mundo. En las carreras: SOL, NUBLADO, LLUVIA, ATARDECER, OCASO. Ganchos: `CityClock.set_manual_hour / set_manual_weather / release_manual`.
- **ESCALA DE RENDERIZADO 3D** (mundo abierto y carreras): 0.80 / 0.70 / 0.60 / 0.50 / AUTO. Usa el mecanismo de siempre: `race.res_scale` → `race._on_resize()` → `world.size = ventana × escala` (el SubViewport del mundo 3D; el HUD, la ventana y la resolución física no se tocan). Fijar una escala pone `race.res_auto = false` (si no, el ajuste automático la movería solo en plena prueba); AUTO lo vuelve a prender. No se guarda en el perfil: al reabrir el juego vuelve a la configuración de Opciones. Queda anotada en cada captura («ESCALA 3D: 0.80 (mundo 3D 1920x1080)»), en los cambios («ESCALA 3D: 0.80 → 0.50») y en el resumen de impactos.
- **Respawn** (`game/city/diag_spots.gd`): asfalto, centro del pueblo, zona rural, «camino de tierra» (no hay: es la banquina de tierra de la Ruta 20), cuadra con más árboles, cuadra con más fachadas. Sin reiniciar nada.
- **VER REGISTRO / COPIAR TODO**: texto limpio para pegar (`DiagLog.export_text`), también guardado en `user://informe_diagnostico.txt`.

## El registro (`game/data/diag_log.gd`)
- **Sesiones**: una por escena (mundo abierto, cada carrera). No se borran (quedan en `user://diag_log.json`, sobreviven al cierre de la app; se borran sólo a mano desde el menú, con doble toque).
- **Historial** cronológico compacto: inicio, cada cambio manual (`[CAMBIO] Árboles → OFF`, hora, clima, ubicación), cambios de zona al conducir, capturas y un renglón de FPS justo después de cada cambio y cada ~10 s.
- **Pruebas** (CAPTURAR): condiciones + FPS promedio/mínimo + diferencia con la prueba anterior y qué cambió. Al final de cada sesión sale un **resumen de impactos** con las pruebas seguidas en las que cambió una sola cosa («ÁRBOLES: +8 FPS promedio al desactivarlos»), y la diferencia respecto de la prueba 1 (base) cuando la escena es la misma.
- Datos técnicos (secundarios): dispositivo, GPU, versión de motor, pantalla y núcleos.

## Cómo medir bien
1. Fijá hora y clima (los botones congelan el reloj) y quedate en el mismo lugar o recorrido.
2. Capturá el estado base con todo ON. Apagá UN sistema, manejá unos 10–15 s por el mismo recorrido y capturá. Repetí con cada sistema (prendiendo el anterior).
3. Pegá el resultado de **📋 COPIAR TODO**.
El panel abierto cuesta un poco de FPS: conviene cerrarlo mientras se mide (la medición sigue andando con el panel cerrado; el botón 📊 muestra los FPS).
