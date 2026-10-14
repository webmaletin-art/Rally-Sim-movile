# Estado actual por módulo

Una sección por sistema, con lo que anda, lo que falta y lo que espera prueba en el teléfono. El detalle técnico vive en el documento de cada sistema (ver `docs/INDICE_TECNICO.md`);
el historial de intervenciones, en `docs/REGISTRO_TECNICO.md`. Leyenda: ✅ hecho y probado en la computadora · 📱 falta probar en el APK · 🚧 en curso · ⛔ bloqueado.

## Estabilidad (cierre al acelerar)
- 🚧📱 El juego se cierra al acelerar (el audio se corta antes). Causa **sin confirmar**: no hay registro del teléfono todavía.
- ✅ Registro de diagnóstico que anda con cualquier APK (`game/diag/crash_log.gd`): migas cada 2 s al manejar (velocidad, marcha, memoria, FPS), al acelerar a fondo, al cargar y salir; errores del motor; escritura inmediata.
- ✅ «COPIAR REGISTRO» en Acerca de y en Opciones → Sonido (antes la pantalla Acerca de no cargaba con un APK viejo).
- 📱 Siguiente paso: que el dueño juegue hasta que se cierre, abra el juego, toque «COPIAR REGISTRO» y lo pegue.

## Mundo abierto y región
- ✅ Dream City + región de ~2.700 km (rutas, pueblos, estaciones, peajes, GPS, mapa). 📱 retoques del 13/10.
- 🚧 Reorganización del centro (autopistas elevadas, concesionarios, sectores bloqueados): ver `docs/REGISTRO_TECNICO.md`.

## Policía
- 🚧 Controles policiales en las rutas entre ciudades, persecución, arresto, multa y aparición frente a la comisaría (`docs/POLICIA.md`).

## Vehículos
- ✅ 26 autos con textura propia (`docs/AUTOS.md`).
- 🚧 Modelos nuevos entregados el 14/10: 2 autos (deportivo y patrullero), monoplaza, superbike (entera y por piezas), interior de rally y volante.

## Online
- ✅ Cuenta obligatoria, economía en el servidor, Realtime preparado. Cerrado en la versión pública (`Release.ONLINE_OPEN := false`); con el modo desarrollador se abre y conecta dos jugadores (con lag, según el dueño, 14/10).

## Compilación
- ✅ Cada push a `main` arma el APK liviano + `content.pck` + `cars.pck` (release `godot-content-4.5`). `cars.pck` sólo se vuelve a bajar si cambian los autos.
