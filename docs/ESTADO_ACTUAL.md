# Estado actual por módulo

Una sección por sistema, con lo que anda, lo que falta y lo que espera prueba en el teléfono. El detalle técnico vive en el documento de cada sistema (ver `docs/INDICE_TECNICO.md`);
el historial de intervenciones, en `docs/REGISTRO_TECNICO.md`. Leyenda: ✅ hecho y probado en la computadora · 📱 falta probar en el APK · 🚧 en curso · ⛔ bloqueado.

## Estabilidad (cierre al acelerar)
- 🚧📱 El juego se cierra de golpe **sólo en el mundo abierto** (Dream City), a veces 8–25 s después de cargar, **también quieto y con audio simple** (registros del 14/10): no es el acelerador ni el audio. Causa **sin confirmar** (¿falta de RAM o error nativo del motor 4.5.1?).
- ✅ Registro de diagnóstico que anda con cualquier APK (`game/diag/crash_log.gd`): migas cada segundo al manejar (velocidad, marcha, RAM del juego y libre, video, FPS), al acelerar a fondo, al cargar y salir; errores del motor; escritura inmediata; tras un cierre, el motivo que da Android.
- ✅ «COPIAR REGISTRO» en Acerca de y en Opciones → Sonido (antes la pantalla Acerca de no cargaba con un APK viejo).
- 📱 Siguiente paso: otro «COPIAR REGISTRO» tras un cierre: la línea `[android] cierre 1: …` dice el motivo.

## Mundo abierto y región
- ✅ Dream City + región de ~2.700 km (rutas, pueblos, estaciones, peajes, GPS, mapa). 📱 retoques del 13/10.
- ✅📱 Todo abierto otra vez (pedido del dueño: la policía es el obstáculo entre ciudades). El sistema de sectores sigue listo (`game/data/sectors.json`, `open_all`; `docs/REGION.md`).
- ✅📱 Fachadas: cajas cerradas (costados enteros) y ninguna sobre una calle (antes 49).
- ✅📱 Ciudades alcanzadas: para aparecer en otra ciudad o pueblo hay que haber llegado manejando (`city/city_reach.gd`).
- ✅📱 4 concesionarios con vidriera y 3 autos reales cada uno (general, Rally & 4x4, Clásicos, Motorsport); los de especialidad venden sólo su rubro (`docs/MUNDO_ABIERTO.md`).
- 🚧 Reorganización del centro (autopistas elevadas, túneles nuevos): ver `docs/REGISTRO_TECNICO.md`.

## Carreras del mundo abierto
- ✅📱 79 eventos para descubrir (sprint, rally, montaña, velocidad, picada, circuito urbano, huida, persecución), en el mapa, con rivales adaptables y premios que valida el servidor (`docs/CARRERAS_MUNDO_ABIERTO.md`). Apagados en el online.

## Policía
- ✅📱 Controles policiales en las 176 rutas largas entre ciudades (patrulleros en la banquina), persecución, interceptor de frente, arresto, multa y comisaría de Dream City (`docs/POLICIA.md`). Probado en la computadora; falta sentirlo en el teléfono.

## Vehículos
- ✅ 26 autos con textura propia (`docs/AUTOS.md`).
- ✅📱 DRP Interceptor y STRIX Vandal RS en el catálogo (28). Monoplaza DR-1 especial bloqueado (`Release.SPECIAL_OPEN`). ⛔ Moto: falta física de dos ruedas.
- ✅📱 18 diseños de pintura, 8 interiores y 6 volantes comprables (Volante Pro 3D del dueño) en el taller → Pintura (`docs/PERSONALIZACION.md`). ✅ Migración `20261015000000_catalog_28_cosmetics.sql` aplicada (14/10/2026 20:26 UTC). 📱 Falta probar una compra con la cuenta.

## Online
- ✅ Cuenta obligatoria, economía en el servidor, Realtime preparado. Cerrado en la versión pública (`Release.ONLINE_OPEN := false`); con el modo desarrollador se abre y conecta dos jugadores (con lag, según el dueño, 14/10).

## Compilación
- ✅ Cada push a `main` arma el APK liviano + `content.pck` + `cars.pck` (release `godot-content-4.5`). `cars.pck` sólo se vuelve a bajar si cambian los autos.
