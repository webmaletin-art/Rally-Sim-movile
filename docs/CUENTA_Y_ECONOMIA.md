# Cuenta obligatoria y economía en el servidor

**Pedido del dueño:** «para que no hackeen el juego y no tengan créditos gratis, que deban iniciar sesión incluso para jugar sin conexión: así el juego consulta a Supabase cuántos créditos tiene y qué autos tiene esa cuenta, y no hacen trampa».

**Estado:** hecho y probado con Postgres de verdad (`tools/online/account_test.sql`), con la función de borde de compras (`tools/online/verify_purchase_test.mjs`) y con el cliente (`godot/tests/account_econ_test.gd`, `login_wall_test.gd`). **Falta que el dueño aplique la migración y publique la función** (ver «Puesta en marcha»). Hasta entonces las compilaciones de prueba (APK) siguen jugando con el progreso local (el cliente se da cuenta de que el servidor no tiene las funciones y no bloquea el juego); la versión de Play **no entra** sin el servidor actualizado.

## Cómo funciona

```
 teléfono                                         servidor (Supabase)
 ─────────                                        ───────────────────
 Profile (profile.json)                           account_econ  (créditos, autos, compras, racha)
   · cada premio / gasto / compra  ──evento──►    account_apply(eventos)  → valida y devuelve el estado de verdad
   · el saldo en pantalla es inmediato            account_state()         → créditos, autos, compras
 AccountEcon (online/account_econ.gd)             account_iap_grant()     → sólo el servidor (compras de Google Play)
   · cola de eventos (se guarda con el perfil)    account_admin_grant()   → sólo el dueño (regalos)
   · el estado del servidor MANDA (reconcile)
```

1. **Iniciar sesión es obligatorio** (`Release.ACCOUNT_REQUIRED := true`): la primera pantalla pide el correo y la contraseña (crear cuenta / entrar). Sin Supabase configurado en la compilación, o con el modo desarrollador de las compilaciones de prueba (7 toques en la versión), el juego anda como antes, todo local (`Release.account_mode()`).
2. Después de entrar, el juego **le pregunta al servidor** (`account_state`) cuántos créditos tiene la cuenta, qué autos (con mejoras, gomas y piezas) y qué compras de la tienda hizo, y **pisa lo local con eso**. Una cuenta nueva empieza con **$5000** y pide el auto de partida (R2 Turbo).
3. Cada **premio** (carreras, aventura, actividades, logros, rangos, regalo diario, bonus de nivel), **gasto** (nafta, peajes, retoques) y **compra** (auto, mejora, gomas, cambio de gomas, pieza) se anota como un **evento** con un id único. Los eventos se mandan en tandas de hasta 40 (`account_apply`, máximo 60 por llamada y 600 llamadas por hora) cada ~6 s si hay algo nuevo, al volver al menú y al pasar la app a segundo plano.
4. El servidor **valida cada evento por separado** (un evento malo no arrastra a los demás) y devuelve el estado de verdad. `AccountEcon.reconcile()` lo vuelca sobre el perfil y le suma lo que todavía no se mandó, así el saldo en pantalla nunca espera la red. Lo que el servidor no reconoce **desaparece** (autos comprados con saldo inventado, mejoras puestas sin comprar, gomas o piezas ajenas, compras de la tienda que nunca se hicieron) y el juego avisa «Se ajustó tu cuenta con el servidor».
5. **Sin conexión se juega** hasta `Release.ACCOUNT_GRACE_DAYS` = **14 días** desde la última confirmación del servidor; los eventos esperan en `profile.d["acct"]["pending"]` (se guardan con el perfil, no se pierden si se cierra el juego) y se mandan al volver la conexión. Pasados los 14 días, en un teléfono nuevo, si cambia la cuenta o si se detecta que se tocó el archivo, la pantalla de entrada (**«Verificando tu cuenta…»**) pide conectarse.
6. **Idempotencia:** cada evento tiene un id; si el juego se cierra a mitad de camino y lo vuelve a mandar, el servidor responde «ya está» (`account_seen`) y no cobra ni acredita dos veces.

## Servidor (`supabase/migrations/20261014000000_account_economy.sql`)

Todas las tablas tienen RLS **sin políticas** y sin permisos para `anon` ni `authenticated`: el teléfono **no lee ni escribe tablas**, sólo llama a funciones (`security definer`).

| Pieza | Qué hace |
|---|---|
| `account_econ` | una fila por cuenta: créditos (nunca negativos), autos `{auto → {mejoras, gomas, piezas}}`, compras de la tienda, racha y día del regalo |
| `account_cfg` | los topes (se cambian con un `update`, sin tocar el juego) |
| `account_earns` | registro de premios (tipo, referencia, monto, hora) para los topes; se borra solo a los 3 días |
| `account_seen` | ids de eventos ya aplicados (14 días) |
| `account_iap_tokens` | recibos de Google Play ya acreditados (sólo el hash; al borrar la cuenta queda el código sin usuario para que no se pueda reusar) |
| `account_products` | los 4 packs de monedas y los 6 desbloqueos (mismos ids que `store/products.gd`) |
| `account_state()` | estado de la cuenta (la crea con $5000 la primera vez). Sólo cuentas con correo (no anónimas) |
| `account_apply(eventos)` | aplica en orden; devuelve el estado de verdad + el resultado de cada evento |
| `account_iap_grant(...)` | **sólo `service_role`** (la función de borde): acredita monedas o desbloquea un producto, **una sola vez por recibo** |
| `account_admin_grant(correo, créditos, autos)` | **sólo el dueño** (editor SQL o `service_role`): regala créditos y autos |

**Reglas de cada evento** (los precios salen del catálogo del **servidor**, `online_cat_*`, que se genera de `godot/game/data/*.json`; el juego nunca dice cuánto cuesta algo):

| Evento | Regla |
|---|---|
| `earn` (premio) | tope por premio **$60.000**, por hora **$300.000**, por día **$1.200.000**; el mismo premio (mismo tipo y referencia) no se cobra dos veces en menos de **15 s**; monto ≤ 0 se rechaza |
| `spend` (nafta, peajes, retoques) | descuenta sin pasar de cero; tope **$250.000** por gasto |
| `daily` | una vez por día **UTC**; $300 + $150 × racha (máx. 7 días) |
| `buy_car` | precio del catálogo, hace falta saldo; **no** compra los premium (Mamut, GT3, Aerion: sólo con la compra de la tienda) ni el de premio de la aventura (DR Bisonte XR) |
| `give_car` | `starter` (sólo el R2 Turbo y sólo con la cuenta vacía), `iap` (sólo si el servidor tiene la compra) o `adventure` (el auto de premio) |
| `buy_upgrade` / `buy_tires` / `buy_part` | precio del catálogo, hace falta saldo y ser dueño del auto; las piezas tienen que ser compatibles; repetir una compra no cobra de nuevo |
| `replace_tires` | la mitad del precio de las gomas (mínimo $250), con hasta 20 % de descuento por el rango del jugador |

## Cliente

- `godot/game/online/account_econ.gd` — la cola, la sincronización (tandas, reintentos 5 s → 15 s → 60 s → 5 min, espera a la que está en curso), `reconcile()`, el sello y la puerta de entrada (`gate_state()`).
- `godot/game/data/profile.gd` — ganchos: `earn(n, tipo, ref)`, `spend(n, tipo)`, `give(id, motivo)` y todas las compras anotan su evento **sin cambiar el comportamiento** (el saldo en pantalla sigue siendo inmediato). Las ayudas `_take()` (descuento interno) las reutiliza `online_profile.gd`.
- `godot/game/data/release.gd` — `ACCOUNT_REQUIRED`, `ACCOUNT_GRACE_DAYS`, `account_mode()`, `login_wall()`.
- `godot/game/ui/menu_account.gd` — pared de «iniciá sesión», pantalla «Verificando tu cuenta…» (`gate`), estado de la sincronización y botón «☁ SINCRONIZAR AHORA».
- `godot/game/store/billing.gd` — con la cuenta activa, **las compras las verifica y las acredita el servidor** (no se consume ni se reconoce la compra en Google hasta que el servidor confirma; si falla, se reintenta sola al abrir).
- `godot/game/online/online.gd` — `call_edge()` (funciones de borde) y la sesión vencida (se pide iniciar sesión de nuevo).

**Sello de integridad:** cada vez que se guarda el perfil se firma (HMAC-SHA256) un resumen de lo que importa (créditos, autos con sus compras, compras de la tienda, cola). Si se edita `profile.json` a mano el sello no coincide y el juego exige conectarse: el servidor pisa lo editado. **Es un freno, no una pared**: la clave está dentro de la app. La defensa de verdad es que el servidor es el dueño de los créditos y los autos.

**Compilaciones de prueba:** con el modo desarrollador encendido (7 toques en la versión) el juego anda todo local, con todo desbloqueado. Al apagarlo, hay que iniciar sesión y **el servidor pisa lo local** (los 5.000.000 de créditos y los autos de prueba desaparecen). Si el servidor todavía no tiene la migración (404), la compilación de prueba sigue con lo local y avisa; la de Play no entra.

## Compras de Google Play (`supabase/functions/verify-purchase`)

Flujo: Google Play cobra → el juego recibe el recibo (`purchase_token`) → se lo manda a la función `verify-purchase` con la sesión de la cuenta → la función comprueba la sesión (cuenta con correo), le pregunta a **Google Play Developer API** si el recibo existe y está pagado y llama a `account_iap_grant` (que acredita **una sola vez por recibo**) → el juego consume (monedas) o reconoce (desbloqueos) la compra en Google. Si la función falla (sin conexión, sin publicar, Google no contesta), la compra queda pendiente y se reintenta sola al abrir el juego; **Google devuelve el dinero si una compra no se reconoce en 3 días**, así que hay que publicar la función antes de vender.

**Puesta en marcha de las compras (una sola vez, la hacés vos):**
1. En **Google Cloud** (el proyecto vinculado a Play Console): activar la API «Google Play Android Developer», crear una **cuenta de servicio** y bajar su clave en JSON.
2. En **Play Console → Usuarios y permisos → Invitar usuarios**: invitar el correo de esa cuenta de servicio con los permisos «Ver información de la app y descargar informes en masa» y «Gestionar pedidos y suscripciones».
3. En GitHub → *Settings → Secrets and variables → Actions*: crear el secreto **`GOOGLE_PLAY_SERVICE_ACCOUNT`** pegando el JSON entero (los otros secretos, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_ID`, `SUPABASE_URL` y `SUPABASE_ANON_KEY`, ya están por el modo online).
4. *Actions → «Supabase · publicar funciones» → Run workflow*: prueba la función, carga los secretos y la publica.
5. Probar con la pista de **prueba interna** de Play Console y una cuenta de probador con licencia (las compras no se pueden probar fuera de Google Play).

## Operación

- **Aplicar la migración:** *Actions → «Supabase · aplicar migraciones» → Run workflow* (`20261014000000_account_economy.sql`; es aditiva y repetible). Revisar que el flujo salga verde.
- **Regalar créditos o autos** (probadores, compensaciones, el progreso que alguien tenía antes de que la economía pasara al servidor): en Supabase → *SQL Editor*:
  `select public.account_admin_grant('alguien@correo.com', 50000, array['gt','hatch2']);` (créditos negativos descuentan; la cuenta tiene que existir).
- **Cuenta de revisión para Google Play** (Play Console → *Contenido de la app → Acceso a la app* pide un usuario y una contraseña porque el juego requiere cuenta): crear una cuenta desde el juego con un correo exclusivo (por ejemplo `revision.dreamracing@gmail.com`), darle saldo con `account_admin_grant` y pegar el correo y la contraseña en Play Console con las instrucciones («Abrir el juego → Iniciar sesión → ENTRAR»).
- **Correo de confirmación:** el archivo `supabase/config.toml` deja «Confirm email» apagado. Si lo encendés en el panel de Supabase hace falta un **SMTP propio** (el de Supabase por defecto manda muy pocos correos por hora y frenaría las altas y los «olvidé mi contraseña»).
- **Cambiar los topes:** `update public.account_cfg set val = 90000 where key = 'earn_max_one';` (claves: `start_credits`, `earn_max_one`, `earn_hour`, `earn_day`, `earn_ref_gap_s`, `spend_max_one`, `apply_hour`).
- **Ver qué rechaza el servidor:** `AccountEcon.last_rejects` (de la última tanda) y el registro `account_earns`.

## Límites (honestos)

- Las carreras se corren **en el teléfono**: el servidor no ve la carrera, sólo el premio que el cliente dice haber ganado. Un cliente tramposo puede pedir premios hasta los topes (**$1.200.000 por día y por cuenta**, $60.000 por premio). Es una cota, no una garantía; las cuentas son gratis, así que los topes frenan pero no impiden del todo. Si se ve abuso: bajar `earn_day`, o validar más del lado del servidor (por ejemplo premios sólo por carreras con un tiempo plausible).
- Los autos premium y el juego completo **sólo** se desbloquean con una compra verificada con Google; los créditos y los autos comunes salen del servidor.
- El progreso que **no** vale plata (estrellas, medallas, tiempos, pintura, ajuste fino, kilómetros, desgaste) sigue guardado en el teléfono y se puede editar: no da créditos ni autos.
- Con un teléfono rooteado y sin conexión se puede «romper» el sello y jugar hasta 14 días con valores tocados; al conectarse el servidor lo pisa. No se mueve nada que quede en el servidor.
- Los rankings online tienen sus propias comprobaciones (`submit_score`) y no dependen de esto.
- La verificación de compras con Google **no se puede probar fuera de Google Play**: está probada con una clave RSA de prueba y respuestas de Google simuladas, no contra el servicio real.

## Pruebas

| Qué | Cómo |
|---|---|
| Servidor (reglas, topes, permisos, idempotencia, borrado) | `bash tools/online/run_economy_test.sh` (Postgres local; corre también en CI: «Economía online · prueba SQL») |
| Función de borde de compras | `node tools/online/verify_purchase_test.mjs` (Node 22) |
| Cliente (cola, reconcile, sin conexión, trampas, compras, sesión vencida) | `godot --headless --path godot --script res://tests/account_econ_test.gd` |
| Pared de login | `godot --headless --path godot --script res://tests/login_wall_test.gd` |

## Puesta en marcha (orden)

1. Aplicar la migración (flujo «Supabase · aplicar migraciones»).
2. Crear el secreto `GOOGLE_PLAY_SERVICE_ACCOUNT` y publicar la función (flujo «Supabase · publicar funciones»).
3. Decidir «Confirm email» (apagado, o SMTP propio).
4. Instalar el APK nuevo, **apagar el modo desarrollador** (Acerca de → «APAGAR MODO DEV»), crear una cuenta y probar: créditos, compra de un auto, mejora, cerrar y abrir sin conexión, y una carrera.
5. Crear la cuenta de revisión y cargar sus datos en Play Console.
6. Armar el AAB (flujo «Build Play Store AAB»: falla si faltan `SUPABASE_URL` y `SUPABASE_ANON_KEY`).
