# Estado actual por módulo

Una sección por sistema, con lo que anda, lo que falta y lo que espera prueba en el teléfono. El detalle técnico vive en el documento de cada sistema (ver `docs/INDICE_TECNICO.md`);
el historial de intervenciones, en `docs/REGISTRO_TECNICO.md`. Leyenda: ✅ hecho y probado en la computadora · 📱 falta probar en el APK · 🚧 en curso · ⛔ bloqueado.

## Estabilidad (cierres nativos)
- ✅📱 **Causa confirmada y corregida (15/10):** bucles de sonido que leían fuera de los datos (hilo de audio, `AudioStreamPlaybackWAV::decode_samples`) → `game/audio/wav_loop.gd`. Falta confirmar en el teléfono.
- ✅📱 Los autos ya no largan marcha atrás (caja automática con el freno de mano de la largada).
- 🚧📱 El juego se cierra de golpe con **ERROR NATIVO (SIGSEGV)** según Android, no por memoria: en el mundo abierto, en carrera rápida (Quarry) y en drift (registros r180 del 14/10). **Causa NO confirmada** (`docs/REGISTRO_TECNICO.md` → 15/10).
- ✅ Corregido (15/10): las capas del frame reducido (`ui/frame_res.gd`) ya no salen del árbol apuntando a la SubViewport: desaparece el error `child_order_changed` y un SIGSEGV que se reproducía en la PC (no está probado que sea el del teléfono). Antes: carrera entre hilos en la región (`RegionData._cum`, 14/10).
- ✅ El registro trae la **lápida** de Android del último cierre nativo (`game/diag/tombstone.gd`): hilo, biblioteca (motor o driver), dirección y logcat del instante. 📱 Falta el primer registro con `[lápida]`.
- ✅📱 **Calidad gráfica a mano** (15/10): BAJA / NORMAL / ALTA / ULTRA en vez de la calibración automática (se cerraba al armar el centro de Dream City).
- ✅📱 **Frame reducido apagado** (15/10 tarde): la calibración se cerraba al activarlo en dos teléfonos y con los dos motores. Ahora sólo baja la ESCALA 3D; la opción «Resolución de frame» no se muestra.
- ✅📱 Descarga del APK liviano (13/0 = tiempo agotado: había un tope de 30 s para TODA la descarga): sin tope, vigilante de trabas, sigue con Range, reintenta solo. **Hay que reinstalar el APK.**
- 🔎 Motor: evaluado Godot 4.7.2 (ver `docs/MIGRACION_GODOT.md` → «Evaluación 15/10/2026»); 4.5.1 sigue en `main`.
- ✅ «COPIAR REGISTRO» en Acerca de y en Opciones → Sonido.

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
- ✅📱 18 diseños de pintura, 8 interiores y 6 volantes comprables (Volante Pro 3D del dueño) en el taller → Pintura (`docs/PERSONALIZACION.md`). ✅ Migraciones `20261015000000_catalog_28_cosmetics.sql` (14/10 20:26 UTC) y `20261016000000_cosmetics_volantes_pro.sql` (15/10 01:38 UTC) aplicadas. 📱 Falta probar una compra con la cuenta.

## Online
- ✅📱 **Abierto desde el 15/10/2026** (autorización del dueño): `Release.ONLINE_OPEN` y `Release.REALTIME` en true. Cuenta obligatoria y economía en el servidor. Garaje online en el hub («MI GARAJE ONLINE») y compras en los 4 concesionarios (migración `20261017000000_online_garage_dealers.sql`, ver `docs/REGISTRO_TECNICO.md` → 15/10 (8)). 📱 Falta la prueba con 2 teléfonos y, en el panel de Supabase, «Allow public access» = OFF en Realtime.

## Compilación
- ✅ Cada push a `main` arma el APK liviano + `content.pck` + `cars.pck` con **Godot 4.7.2** (release `godot-content-4.7`; desde el 15/10/2026, antes 4.5.1). `cars.pck` sólo se vuelve a bajar si cambian los autos.
