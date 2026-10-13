# Seguridad — revisión del 12/10/2026 (actualizada el 13/10/2026: cuenta obligatoria y economía en el servidor)

Qué se revisó, qué se arregló, qué queda y qué tenés que configurar vos en Supabase y en Play. Complementa `docs/ONLINE_SUPABASE.md` (cómo se conecta), `docs/ECONOMIA_ONLINE.md` (la economía del online) y `docs/PRIVACIDAD.md`/`docs/TERMINOS.md` (lo que se le dice al jugador).

## Resumen corto
- **Actualización (13/10/2026) — cuenta obligatoria:** a pedido del dueño ya **hace falta iniciar sesión para jugar** (también «sin conexión») y **los créditos, los autos y las compras viven en el servidor** (`docs/CUENTA_Y_ECONOMIA.md`): el juego le pregunta a Supabase cuánto tiene la cuenta y qué autos tiene, y le manda cada premio y cada compra para que los valide (precio del catálogo del servidor, saldo, topes de premios por hora y por día, autos premium sólo con la compra verificada con Google). Editar `profile.json` ya no da créditos ni autos: el servidor pisa lo que no reconoce. Lo que sigue sin poder impedirse es que un cliente tramposo pida premios hasta los topes ($1.200.000 por día y por cuenta): ver «Límites». Las compras de Google Play las verifica la función de borde `verify-purchase` con la API de Google (antes se validaban sólo en el teléfono).
- *(Lo que sigue es la revisión original, de antes de ese cambio.)* **El juego sin conexión no tenía nada que atacar del lado del servidor**: no había servidor. Lo único "vulnerable" era que alguien con el teléfono rooteado editara su propio archivo de guardado (créditos, autos).
- **El modo online SÍ exige una cuenta con correo** (ya lo hacía el cliente; ahora lo exige también la base de datos). Antes un usuario anónimo —Supabase permite crear miles— podía usar la economía, el mercado, el chat y la presencia: con muchas cuentas anónimas se podía cobrar el regalo diario de cada una y pasarle los autos a una cuenta principal por el mercado. Está cerrado con la migración `20261009010000_require_account.sql`.
- **Login obligatorio para jugar: ENCENDIDO** (`Release.ACCOUNT_REQUIRED := true`, antes era `LOGIN_REQUIRED` apagado). La primera pantalla pide crear la cuenta o iniciar sesión, sin «Jugar sin cuenta»; una vez adentro el juego anda sin conexión hasta 14 días entre verificaciones. Para la revisión de Google Play hay que darle una cuenta de prueba (Acceso a la app: ver `docs/CUENTA_Y_ECONOMIA.md`). Pruebas: `tests/login_wall_test.gd`, `tests/account_econ_test.gd`, `tools/online/account_test.sql`.

## Lo que se revisó
| Zona | Resultado |
|---|---|
| Clave de Supabase en la app | Sólo va la clave pública (`anon`). La `service_role` no está en el repositorio ni en la app; no la pongas nunca ahí. |
| Tablas | Todas con RLS. Los jugadores sólo leen/escriben lo suyo; los rankings, el mercado y el chat se leen por funciones. |
| Funciones (RPC) | `security definer` con `set search_path`, validan todo del lado del servidor (precios, rangos, dueño del auto). El cliente nunca manda "cuánta plata tengo": la billetera y los autos viven en el servidor. |
| Usuarios anónimos | Pueden mandar marcas a los rankings (no mueven plata). **Ya no** pueden usar economía, mercado, chat ni presencia (`_online_uid()` y `_ensure_player()` exigen cuenta con correo). Siguen abiertas a anónimos —con límites de frecuencia y sin efecto económico— `follow_set`, `report_submit` y `world_join`. |
| Catálogo online | Los 26 autos (migración `20261009000000_online_catalog_26.sql`). Los autos premium y el Bisonte también se pueden comprar con los créditos del online (aparte de la plata sin conexión, que no se vende) porque el dueño pidió "todos los autos". |
| Ganchos de prueba | `DR_SPAWN`, `DR_POS` y los argumentos de línea de comandos quedan apagados en la versión de tienda (`Release.store()`). |
| Compras (Google Play Billing) | **Verificadas en el servidor**: la función de borde `verify-purchase` (`supabase/functions/verify-purchase`) comprueba la sesión, le pregunta a la API de Google Play Developer si el recibo existe y está pagado y llama a `account_iap_grant` (sólo `service_role`; acredita una vez por recibo). Probada con una clave de prueba y respuestas de Google simuladas (`tools/online/verify_purchase_test.mjs`); **no se puede probar contra Google fuera de Play**. |
| Economía de la cuenta | `account_state` / `account_apply` (migración `20261014000000_account_economy.sql`): tablas sin permisos para el teléfono, eventos idempotentes, topes por premio/hora/día, precios del catálogo del servidor, `account_admin_grant` sólo para el dueño. Prueba: `tools/online/account_test.sql` (CI: «Economía online · prueba SQL»). |
| Eliminación de cuenta | Desde la app y por la web (`docs/eliminar-cuenta.html`): borra la cuenta y las marcas (Play lo exige). |
| Pruebas de la base | `tools/online/run_economy_test.sh` levanta un Postgres 16 local, aplica todas las migraciones y corre `economy_test.sql` (incluye anónimos bloqueados, 26 autos, mercado, regalo diario). La CI lo corre en «Economía online · prueba SQL». |

## Lo que tenés que configurar vos en Supabase (panel del proyecto)
1. **Aplicar las migraciones** nuevas con el flujo «Supabase · aplicar migraciones» (a mano): `20261009000000_online_catalog_26.sql` y `20261009010000_require_account.sql`. Sin la segunda, el servidor sigue aceptando anónimos en la economía.
2. **Authentication → Providers → Email**: contraseña de 8+ (lo ideal 10+, con «leaked password protection» en el plan Pro). «Confirm email»: **apagado hasta tener un SMTP propio** (punto 4); con SMTP propio, encendido.
3. **Authentication → Attack protection → CAPTCHA** (hCaptcha o Cloudflare Turnstile) para registrarse: evita que un programa cree miles de cuentas. Cuando lo actives hay que sumar el token del captcha al registro en `online.gd` (`create_account`): avisame y lo cableo.
4. **Authentication → SMTP**: poner un servicio de correo propio (Resend, Brevo, SES…). El correo que viene con Supabase tiene un tope bajísimo de envíos por hora y no sirve para lanzar.
5. **Authentication → Rate limits**: dejar los límites por defecto o más bajos (registros e inicios de sesión por hora y por IP).
6. **Allow anonymous sign-ins**: **APAGADO** (el juego ya no crea usuarios anónimos: la cuenta con correo es obligatoria).
7. **Backups**: en el plan gratis no hay copias diarias descargables. Antes de abrir el online conviene el plan Pro (copias diarias, más conexiones y los 500 mensajes/seg de Realtime: ver `docs/ONLINE_SUPABASE.md`).
8. **Realtime**: usar canales *privados* con políticas sobre `realtime.messages` (el plan está en `docs/ONLINE_SUPABASE.md`, "Tiempo real").

## Límites que hay que conocer (honestamente)
- **(Cuenta obligatoria)** Las carreras se corren en el teléfono: el servidor no ve la carrera, sólo el premio que el cliente dice haber ganado. Un cliente tramposo puede pedir premios hasta los topes (`account_cfg`: $60.000 por premio, $300.000 por hora, $1.200.000 por día). Es una cota, no una garantía, y las cuentas son gratis. Si se ve abuso: bajar los topes o validar premios del lado del servidor.
- Editar `profile.json` (créditos, autos, compras) ya no sirve: el servidor pisa lo que no reconoce. Un teléfono rooteado sin conexión puede romper el sello de integridad y jugar hasta 14 días con valores tocados; al conectarse el servidor lo pisa. Lo que no vale plata (estrellas, medallas, tiempos, pintura, ajuste fino) sigue siendo local.
- Las compras (`iap`) ahora las dice el servidor; «Restaurar compras» vuelve a pedirle a Google los recibos y el servidor los acredita una sola vez por recibo.
- Las marcas de los rankings las manda el cliente; la base valida rangos y tiempos mínimos por mapa, pero un tramposo decidido con un programa puede mandar una marca "posible". Para un ranking competitivo habría que mandar también el replay o validar la carrera en el servidor; hoy no se hace.
- Las traducciones de los textos nuevos de políticas están en 5 idiomas, pero la versión legal que manda es la española.
