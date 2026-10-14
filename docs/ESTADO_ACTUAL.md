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
- ✅📱 Sectores: abiertos Dream City y la Ruta a la Sierra (oeste); el resto en obra con barreras visibles y reversible (`game/data/sectors.json`, `docs/REGION.md`).
- 🚧 Reorganización del centro (autopistas elevadas, concesionarios): ver `docs/REGISTRO_TECNICO.md`.

## Carreras del mundo abierto
- ✅📱 79 eventos para descubrir (sprint, rally, montaña, velocidad, picada, circuito urbano, huida, persecución), en el mapa, con rivales adaptables y premios que valida el servidor (`docs/CARRERAS_MUNDO_ABIERTO.md`). Apagados en el online.

## Policía
- ✅📱 Controles policiales en las 176 rutas largas entre ciudades, persecución con barrera, interceptor de frente, arresto, multa y comisaría de Dream City (`docs/POLICIA.md`). Probado en la computadora; falta sentirlo en el teléfono.

## Vehículos
- ✅ 26 autos con textura propia (`docs/AUTOS.md`).
- ✅📱 DRP Interceptor y STRIX Vandal RS en el catálogo (28). Monoplaza DR-1 especial bloqueado (`Release.SPECIAL_OPEN`). ⛔ Moto: falta física de dos ruedas. 🚧 Interior de rally y volante.

## Online
- ✅ Cuenta obligatoria, economía en el servidor, Realtime preparado. Cerrado en la versión pública (`Release.ONLINE_OPEN := false`); con el modo desarrollador se abre y conecta dos jugadores (con lag, según el dueño, 14/10).

## Compilación
- ✅ Cada push a `main` arma el APK liviano + `content.pck` + `cars.pck` (release `godot-content-4.5`). `cars.pck` sólo se vuelve a bajar si cambian los autos.
