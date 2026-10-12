# Seguridad — revisión del 12/10/2026

Qué se revisó, qué se arregló, qué queda y qué tenés que configurar vos en Supabase y en Play. Complementa `docs/ONLINE_SUPABASE.md` (cómo se conecta), `docs/ECONOMIA_ONLINE.md` (la economía del online) y `docs/PRIVACIDAD.md`/`docs/TERMINOS.md` (lo que se le dice al jugador).

## Resumen corto
- **El juego sin conexión no tiene nada que atacar del lado del servidor**: no hay servidor. Lo único "vulnerable" es que alguien con el teléfono rooteado edite su propio archivo de guardado (créditos, autos), y eso sólo le arruina el juego a él. No se arregla con login.
- **El modo online SÍ exige una cuenta con correo** (ya lo hacía el cliente; ahora lo exige también la base de datos). Antes un usuario anónimo —Supabase permite crear miles— podía usar la economía, el mercado, el chat y la presencia: con muchas cuentas anónimas se podía cobrar el regalo diario de cada una y pasarle los autos a una cuenta principal por el mercado. Está cerrado con la migración `20261009010000_require_account.sql`.
- **Login obligatorio para jugar: no hace falta y no conviene encenderlo hoy** (el online está cerrado, Google Play pide poder revisar la app sin registrarse y se pierden jugadores). Dejé el interruptor listo: `Release.LOGIN_REQUIRED` (apagado). Con el online abierto y configurado, ponerlo en `true` hace que la primera pantalla pida crear la cuenta o iniciar sesión, sin el botón «Jugar sin cuenta»; una vez adentro el juego sigue andando sin conexión. Prueba: `tests/login_wall_test.gd`.

## Lo que se revisó
| Zona | Resultado |
|---|---|
| Clave de Supabase en la app | Sólo va la clave pública (`anon`). La `service_role` no está en el repositorio ni en la app; no la pongas nunca ahí. |
| Tablas | Todas con RLS. Los jugadores sólo leen/escriben lo suyo; los rankings, el mercado y el chat se leen por funciones. |
| Funciones (RPC) | `security definer` con `set search_path`, validan todo del lado del servidor (precios, rangos, dueño del auto). El cliente nunca manda "cuánta plata tengo": la billetera y los autos viven en el servidor. |
| Usuarios anónimos | Pueden mandar marcas a los rankings (no mueven plata). **Ya no** pueden usar economía, mercado, chat ni presencia (`_online_uid()` y `_ensure_player()` exigen cuenta con correo). Siguen abiertas a anónimos —con límites de frecuencia y sin efecto económico— `follow_set`, `report_submit` y `world_join`. |
| Catálogo online | Los 26 autos (migración `20261009000000_online_catalog_26.sql`). Los autos premium y el Bisonte también se pueden comprar con los créditos del online (aparte de la plata sin conexión, que no se vende) porque el dueño pidió "todos los autos". |
| Ganchos de prueba | `DR_SPAWN`, `DR_POS` y los argumentos de línea de comandos quedan apagados en la versión de tienda (`Release.store()`). |
| Compras (Google Play Billing) | Se validan en el teléfono. Alcanza para un juego sin conexión; **antes de vender cualquier cosa que entre al online hay que verificar el recibo en un servidor** (función de borde de Supabase que llame a la API de Google Play Developer con la cuenta de servicio). Hoy las monedas compradas son sólo del juego sin conexión. |
| Eliminación de cuenta | Desde la app y por la web (`docs/eliminar-cuenta.html`): borra la cuenta y las marcas (Play lo exige). |
| Pruebas de la base | `tools/online/run_economy_test.sh` levanta un Postgres 16 local, aplica todas las migraciones y corre `economy_test.sql` (incluye anónimos bloqueados, 26 autos, mercado, regalo diario). La CI lo corre en «Economía online · prueba SQL». |

## Lo que tenés que configurar vos en Supabase (panel del proyecto)
1. **Aplicar las migraciones** nuevas con el flujo «Supabase · aplicar migraciones» (a mano): `20261009000000_online_catalog_26.sql` y `20261009010000_require_account.sql`. Sin la segunda, el servidor sigue aceptando anónimos en la economía.
2. **Authentication → Providers → Email**: dejar «Confirm email» ENCENDIDO; contraseña de 8+ (lo ideal 10+, con «leaked password protection» en el plan Pro).
3. **Authentication → Attack protection → CAPTCHA** (hCaptcha o Cloudflare Turnstile) para registrarse: evita que un programa cree miles de cuentas. Cuando lo actives hay que sumar el token del captcha al registro en `online.gd` (`create_account`): avisame y lo cableo.
4. **Authentication → SMTP**: poner un servicio de correo propio (Resend, Brevo, SES…). El correo que viene con Supabase tiene un tope bajísimo de envíos por hora y no sirve para lanzar.
5. **Authentication → Rate limits**: dejar los límites por defecto o más bajos (registros e inicios de sesión por hora y por IP).
6. **Allow anonymous sign-ins**: puede quedar encendido (los rankings lo usan); la economía ya no los acepta.
7. **Backups**: en el plan gratis no hay copias diarias descargables. Antes de abrir el online conviene el plan Pro (copias diarias, más conexiones y los 500 mensajes/seg de Realtime: ver `docs/ONLINE_SUPABASE.md`).
8. **Realtime**: usar canales *privados* con políticas sobre `realtime.messages` (el plan está en `docs/ONLINE_SUPABASE.md`, "Tiempo real").

## Límites que hay que conocer (honestamente)
- Un teléfono rooteado puede editar `profile.json` (créditos, autos, compras desbloqueadas). Es un juego sin conexión: sólo se estafa a sí mismo. Si más adelante se quiere impedir, hay que mover el perfil al servidor (la economía online ya lo está) o firmar los guardados; no es un problema de seguridad del servidor.
- Los ganadores de las compras (`iap`) se guardan en el perfil local; «Restaurar compras» las vuelve a pedir a Google.
- Las marcas de los rankings las manda el cliente; la base valida rangos y tiempos mínimos por mapa, pero un tramposo decidido con un programa puede mandar una marca "posible". Para un ranking competitivo habría que mandar también el replay o validar la carrera en el servidor; hoy no se hace.
- Las traducciones de los textos nuevos de políticas están en 5 idiomas, pero la versión legal que manda es la española.
