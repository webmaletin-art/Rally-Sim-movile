# Guía del SQL y de Supabase — qué se aplica, cómo se aplica y cómo se comprueba

Para el dueño. **Estado al 21/10/2026: las 4 migraciones nuevas ya están aplicadas** (detalle al final, en «Historial»). Lo que sólo se puede hacer en el panel de Supabase está marcado con 🖱.

## 1. Qué es esto, en una frase
El servidor del juego (Supabase) guarda las cuentas, los créditos, los autos, las compras, los récords y los eventos. Su estructura está escrita en **migraciones SQL** (carpeta `supabase/migrations/`): cada archivo es un paso, se aplican **en orden** y cada una se aplica **una sola vez** (las ya aplicadas se saltean). Todas son **aditivas y repetibles** (`if not exists`, `on conflict`) y cada una **se prueba sola** con un bloque `do $$ … $$` al final: si la prueba falla, la migración entera se deshace y no queda nada a medias.

## 2. Qué hay aplicado y qué falta

| Migración | Qué hace | Estado |
|---|---|---|
| `20261003000000` a `20261021000000` (17 archivos: base online, borrado de cuenta, chat, economía, catálogo, cuenta obligatoria, Realtime privado, economía en el servidor, cosméticos, concesionarios, cacería, eventos, temporadas y vales) | La base del online y de la cuenta | **Aplicadas** (la última, `20261021000000`, el 15/10/2026 17:45 UTC) |
| `20261022000000_claims_progress` | Los premios de una sola vez (logros, medallas, primeras victorias) quedan guardados en la cuenta: al reinstalar no se cobran dos veces y no se pierde el progreso | ✅ **Aplicada** el 21/10/2026 00:02 UTC |
| `20261023000000_class_records` | Récords por **clase** (según el índice de rendimiento del auto): se compite contra autos parecidos, no contra cualquiera | ✅ **Aplicada** el 21/10/2026 00:02 UTC |
| `20261024000000_events_rotation_daily_milestones` | Horarios de eventos que rotan, cacería para principiantes (queda **apagada**), desafíos del día configurables e hitos de la temporada | ✅ **Aplicada** el 21/10/2026 00:02 UTC |
| `20261025120000_no_nitro_spoilers_price_tiers` | **Sin Nitro ni alerones:** devuelve lo pagado a quien los tuviera (a cuentas y a garajes online), los saca de los autos y borra esas filas del catálogo del servidor; siembra los **precios por escalones** (cada precio lo comparten 2 a 5 autos) y los locales nuevos | ✅ **Aplicada** el 21/10/2026 00:02 UTC |

**Ojo con la última (ya aplicada):** devuelve plata y borra filas del catálogo; no es reversible con un botón (la plata devuelta queda en la cuenta). Se probó con datos de verdad en un Postgres local (`tools/online/refund_nitro_test.sh`: una cuenta con Nitro 1 y 2 y los tres alerones recupera exactamente lo que pagó, se le sacan de los autos, y repetir la migración no devuelve dos veces).

## 3. Cómo se aplican (con GitHub, sin escribir SQL)
1. Entrá a https://github.com/webmaletin-art/Rally-Sim-movile → pestaña **Actions**.
2. En la lista de la izquierda elegí **«Supabase · aplicar migraciones»**.
3. Botón **Run workflow** (a la derecha). En **«Use workflow from»** elegí la rama que tiene las migraciones (`main`; desde el 21/10/2026 la rama de la versión candidata tiene las mismas) y apretá **Run workflow**.
4. Esperá 1 o 2 minutos y abrí la corrida. Tiene que quedar con ✅ verde. Los pasos que importan:
   - **«Migraciones pendientes»**: lista lo que falta aplicar (columna *Remote* vacía).
   - **«Aplicar las migraciones»**: aplica cada una en orden y escribe `Applying migration …` por cada una.
   - **«Migraciones aplicadas»**: la lista final; **todas** tienen que tener la misma versión en *Local* y en *Remote*.
5. Si algo sale rojo, **no pasa nada grave** (cada migración es una transacción): copiá el mensaje de error del paso que falló y pasámelo.

Secretos que usa el flujo (ya están cargados; sólo cambian si cambiás la contraseña de la base): `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_ID`. La variable `SUPABASE_AUTODEPLOY` está apagada a propósito: **nada se aplica solo**, siempre a mano.

## 4. Cómo comprobar que quedó bien (🖱 Supabase → SQL Editor)
Pegá cada consulta y tocá **Run**:

```sql
-- 1) la última migración aplicada tiene que ser 20261025120000
select version from supabase_migrations.schema_migrations order by version desc limit 6;

-- 2) ya no hay Nitro ni alerones en el catálogo del servidor (los dos números tienen que ser 0)
select (select count(*) from public.online_cat_upgrades where category = 'nitro') as nitro,
       (select count(*) from public.online_cat_parts where category = 'spoiler') as alerones;

-- 3) los precios por escalones: cuántos autos hay en cada precio (de 2 a 5 por precio; el R2 Turbo inicial no se vende)
select price, count(*) as autos, string_agg(id, ', ' order by id) as cuales
  from public.online_cat_vehicles where price > 0 group by price order by price;

-- 4) las tablas nuevas existen (récords por clase, hitos, configuración de desafíos)
select to_regclass('public.class_scores') as class_scores, to_regclass('public.wev_milestones') as hitos, to_regclass('public.game_cfg') as game_cfg;

-- 5) la cacería para principiantes queda APAGADA hasta publicar (enabled = false)
select id, enabled from public.wev_templates where id = 'caza_inicial';
```

## 5. Lo que sólo se hace en el panel (🖱, una vez)
| Dónde | Qué | Valor |
|---|---|---|
| Authentication → Sign In / Providers | «Allow anonymous sign-ins» | **Apagado** |
| Authentication → Sign In / Providers → Email | «Confirm email» | **Apagado** (o un SMTP propio; sin esto el correo de confirmación puede no llegar) |
| Realtime → Settings | «Allow public access» | **Apagado** (el tiempo real es privado: ver `docs/ONLINE_SUPABASE.md`) |
| Table Editor → `app_flags` | fila `pvp` | `false` hasta que quieras el mundo compartido en tiempo real (un solo botón: ponerla en `true`; no hace falta APK nuevo) |
| Table Editor → `wev_templates` | fila `caza_inicial`, columna `enabled` | `false` hasta publicar la versión nueva; después `true` |
| Authentication → Users | cuenta de revisión de Google Play | crearla desde el juego (correo + contraseña) y regalarle saldo con `account_admin_grant` (SQL Editor: ver `docs/CUENTA_Y_ECONOMIA.md`, «Operación») |

## 6. Funciones de borde (compras de Google Play)
La compra de un producto de Play la verifica la función `verify-purchase` (carpeta `supabase/functions/`). Se publica con el flujo **«Supabase · publicar funciones»** (Actions → Run workflow). Necesita el secreto de GitHub `GOOGLE_PLAY_SERVICE_ACCOUNT` (el JSON de la cuenta de servicio de Google Cloud; ver `docs/GUIA_PLAY_CONSOLE_PASO_A_PASO.md`, paso 9). **Sin eso las compras de Play no se acreditan.** Esta tanda no cambió esa función.

## 7. Cómo se prueba el SQL sin tocar el servidor real
- `.github/workflows/economy-test.yml` («Economía online · prueba SQL») levanta un Postgres temporal, aplica **todas** las migraciones dos veces (así se comprueba que son repetibles) y corre `tools/online/economy_test.sql`, `tools/online/account_test.sql`, la prueba de la función de compras y la de devolución del Nitro. **No toca el proyecto real.** Corre sola en cada cambio de `supabase/**` o `tools/online/**`.
- En una computadora: `pg_ctlcluster 16 main start` y `runuser -u postgres -- env PGUSER=postgres bash tools/online/refund_nitro_test.sh`.

## 8. Si algo sale mal
- **Una migración falla al aplicarse:** se deshace sola. Mandame el error del flujo y la arreglo (no la apliques a mano).
- **Un jugador dice que perdió plata o autos:** abrí 🖱 SQL Editor y mirá `select * from public.account_econ where user_id = '…';` y los últimos premios y gastos `select * from public.account_earns where user_id = '…' order by at desc limit 50;` (se borran solos a los 3 días) y pasámelo.
- **Copia de seguridad antes de un cambio grande:** el plan gratuito no trae copias automáticas; en el plan **Pro** (Database → Backups) hay copias diarias. Si pasás a Pro, conviene hacerlo **antes de abrir el tiempo real** (ver `docs/COSTOS_ONLINE.md`).

## Historial (lo que se aplicó de verdad)
- **21/10/2026 00:02 UTC · flujo «Supabase · aplicar migraciones», corrida n.º 35** (desde la rama `ccr-e7ae3f10-45afj2`, commit `edaaaf6`; autorización expresa del dueño el 20/10: «ejecutes todo lo que es SQL»). **Aplicó sin errores y en orden** `20261022000000_claims_progress`, `20261023000000_class_records`, `20261024000000_events_rotation_daily_milestones` y `20261025120000_no_nitro_spoilers_price_tiers`. «Migraciones pendientes» listaba exactamente esas cuatro; «Migraciones aplicadas» muestra las 22 versiones (`20261003000000` … `20261025120000`) con la misma fecha en *Local* y en *Remote*.
  - **Antes de aplicar** estaba verde: el flujo «Economía online · prueba SQL» (corrida a mano n.º 32 sobre el mismo commit: aplica todas las migraciones dos veces, `ECONOMIA_ONLINE_TEST OK`, `CUENTA_TEST OK`, la función de compras y la devolución del Nitro con datos de verdad) y las 106 pruebas de Godot de `build-godot.yml` (corrida n.º 234, job «tests»).
  - **Lo que no pude comprobar desde acá:** no tengo acceso a la base del proyecto real, así que las consultas de la sección 4 las corrés vos en el SQL Editor (30 segundos). Lo que sí se sabe es que cada migración corrió su autoprueba `do $$ … $$` (si una fallaba, el flujo quedaba en rojo y se deshacía todo) y que la lista final coincide.
  - **Lo que cambia para quien juega:** el Nitro y los alerones desaparecen del catálogo y de los autos (a quien los hubiera pagado se le devolvió la plata de catálogo en su cuenta o su garaje online); los autos quedan con los precios por escalones; los premios de una sola vez, los récords por clase, los eventos rotativos y los hitos de la temporada ya existen en el servidor. La cacería para principiantes (`caza_inicial`) quedó **apagada** a propósito hasta publicar.
  - **Pendiente (sólo vos, 🖱):** las 5 consultas de la sección 4, y lo de la sección 5 (correo sin confirmación, Realtime sin acceso público, cuenta de revisión de Google).
- Antes (15/10/2026): `20261003000000` a `20261021000000` aplicadas con el mismo flujo; la última (`20261021000000_seasons_drift_vouchers`) el 15/10/2026 17:45 UTC, sin errores y con su autoprueba.
