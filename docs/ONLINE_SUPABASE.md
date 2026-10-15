# Modo online con Supabase — paso a paso

Ya está todo **cableado** en el repositorio: base de datos (tablas, seguridad y funciones), cliente del juego, compilación con tus claves y prueba de conexión.
Lo único que falta son **tus claves**, que se cargan una vez en GitHub. Nada de esto se activa hasta que lo hagas.
**Desde octubre de 2026 la cuenta con correo es obligatoria para jugar** y los créditos, los autos y las compras viven en el servidor: ver `docs/CUENTA_Y_ECONOMIA.md` (migración `20261014000000_account_economy.sql` y función de borde `verify-purchase`). **El modo online multijugador (mundo, chat, mercado, tiempo real) está ABIERTO desde el 15/10/2026** por autorización expresa del dueño (`Release.ONLINE_OPEN := true`, `Release.REALTIME := true`; contenido r184+). Pendiente del dueño: «Allow public access» = OFF en Realtime, Seguridad de los datos en Play y la prueba con 2 teléfonos (ver «Cómo encenderlo»).

## Qué hay en el repositorio
| Qué | Dónde |
|---|---|
| Base: jugadores anónimos, pistas, mejores marcas, seguridad por filas (RLS) y funciones `submit_score`, `get_leaderboard`, `set_player_name` | `supabase/migrations/20261003000000_online_base.sql` (probada contra un Postgres real) |
| Configuración de Supabase | `supabase/config.toml` |
| Cliente del juego (cuenta con correo, marcas, rankings, economía de la cuenta) | `godot/game/online/online.gd`, `account_econ.gd` + `online_config.json` (vacío en el repo) |
| Envío automático de la marca al terminar una carrera (si el jugador participa) | `godot/game/app.gd` (`_submit_online`) |
| Pantalla Online: opción «Participar en los rankings online» y, en modo desarrollador, **«Probar conexión con Supabase»** | `ui/menu.gd` (`_online_options`) |
| Compilación del APK y del AAB: escriben la dirección y la clave pública dentro de la app desde los secretos | `.github/workflows/build-godot.yml` y `build-aab.yml` |
| Aplicar las migraciones desde GitHub (opcional) | `.github/workflows/supabase-deploy.yml` |
| Pruebas | `godot/tests/online_test.gd` (con un Supabase de mentira, `tools/online/mock_supabase.py`) |

## Paso a paso (unos 15 minutos)

### 1) En Supabase (supabase.com)
1. **Proyecto**: si todavía no lo creaste, *New project* → nombre `dream-racing`, región **South America (São Paulo)**, y una **contraseña de base de datos** (guardala).
2. **Autenticación**: *Authentication → Sign In / Providers* → **Email** encendido y «Allow new users to sign up» encendido. **«Allow anonymous sign-ins»: APAGADO** (el juego ya no crea usuarios anónimos: la cuenta con correo es obligatoria; ver «Cuentas con correo» más abajo).
3. **Copiá tres datos** de *Project Settings*:
   - *Data API / API*: **Project URL** (`https://xxxx.supabase.co`) y la clave **`anon` `public`**. (La `service_role` **NO**: esa es secreta y nunca va en el juego ni en GitHub.)
   - *General*: **Project ID** (la parte `xxxx` de la URL, también llamada *Reference ID*).
4. **Token de acceso**: *Account (tu avatar) → Access Tokens → Generate new token* (por ejemplo `github-dream-racing`). Es una sola vez: copialo.

### 2) En GitHub (repositorio → *Settings → Secrets and variables → Actions → New repository secret*)
Cargá estos **5 secretos** (nombre exacto):

| Secreto | Qué es |
|---|---|
| `SUPABASE_URL` | el Project URL |
| `SUPABASE_ANON_KEY` | la clave `anon` pública (va dentro de la app; la seguridad la dan las políticas de la base) |
| `SUPABASE_PROJECT_ID` | el Project ID |
| `SUPABASE_DB_PASSWORD` | la contraseña de la base que elegiste |
| `SUPABASE_ACCESS_TOKEN` | el token del paso 1.4 |

### 3) Crear las tablas
Elegí **una** de las dos formas (no las dos):
- **A. Integración de Supabase con GitHub** (la que ya conectaste): en Supabase → *Project Settings → Integrations → GitHub*, elegí el repositorio, **Supabase directory = `supabase`** y la rama de producción `main`; activá el despliegue automático de migraciones. (Algunas funciones de ramas de la integración son del plan Pro; si tu plan no despliega migraciones, usá la B.)
- **B. Con GitHub Actions** (funciona en el plan gratis): *Actions → «Supabase · aplicar migraciones» → Run workflow*. Si todo está bien, el paso final lista la migración `20261003000000_online_base` como aplicada. Para que corra sola en cada cambio de `supabase/**`, creá la variable de repositorio `SUPABASE_AUTODEPLOY = true`.

Comprobación: en Supabase → *Table Editor* tienen que aparecer `players`, `tracks`, `scores` y `score_log` (las tres primeras con el candadito de RLS).

### 4) Compilar el juego con las claves
Corré la compilación (cada push a `main` ya lo hace). En el registro, el paso **«Configurar el modo online (Supabase)»** dice *«Modo online configurado»*. Instalá el APK nuevo.

### 5) Probar en el celular
1. Abrí **Acerca de → tocá la «Versión» 7 veces seguidas** (modo desarrollador; solo existe en el APK de GitHub, no en el de Play).
2. Menú principal → **Modo online**: aparece la opción **«Participar en los rankings online»** (activala) y el botón **«🛠 Probar conexión con Supabase»**.
3. Tiene que decir **«✔ Conectado a Supabase (usuario xxxxxx…)»**. Si falla, el mensaje dice por qué (falta la clave, no hay sesión o no se aplicaron las migraciones).
4. El modo desarrollador **no manda marcas** (para que nadie ensucie los rankings). Apagalo (**Acerca de → APAGAR MODO DESARROLLADOR**), corré una carrera y mirá en Supabase → *Table Editor → scores*: aparece tu marca. (Con el modo desarrollador apagado ya no ves el botón de prueba, pero el juego sigue funcionando igual.)

## Cuentas con correo (obligatorias para jugar)
**Para jugar hay que iniciar sesión** con un correo (`Release.ACCOUNT_REQUIRED := true`): se crea desde la primera pantalla («Crear cuenta con correo» o «Ya tengo cuenta · Iniciar sesión»; hay «Olvidé mi contraseña», «Cerrar sesión» y «Borrar mi cuenta»). Una vez adentro el juego también anda sin conexión (hasta 14 días entre una verificación y otra). Ya no se crean usuarios anónimos desde el juego, y la base **rechaza a los anónimos** en la economía, el mercado, el chat, la presencia y la cuenta (migraciones `20261009010000_require_account.sql` y `20261014000000_account_economy.sql`), así que nadie puede juntar plata con miles de cuentas anónimas. **Los créditos, los autos y las compras viven en el servidor** (`docs/CUENTA_Y_ECONOMIA.md`); el mundo online tiene además su propia billetera y sus propios autos (`docs/ECONOMIA_ONLINE.md`).
Sin Supabase configurado en la compilación (o con el modo desarrollador de las compilaciones de prueba) el juego anda todo local, como antes: así se pueden seguir probando cosas sin cuenta. La versión de Play **exige** los secretos de Supabase (el flujo del AAB falla si faltan).

**Qué configurar en Supabase** (*Authentication*):
1. *Sign In / Providers → Email*: **Enable Email provider** encendido (y «Allow new users to sign up» encendido).
2. *Confirm email*: recomendado **apagado al principio**. El correo de Supabase que viene por defecto manda muy pocos mensajes por hora (unos 2–4), así que con «Confirm email» encendido los registros se traban apenas haya movimiento. Para encenderlo bien, primero configurá un **SMTP propio** (*Authentication → SMTP Settings*, por ejemplo Resend o Brevo, tienen plan gratis) y recién ahí activá la confirmación. El juego ya maneja las dos formas (si pide confirmar, avisa «revisá tu correo»).
3. *URL Configuration → Site URL*: la dirección de la política de privacidad (`https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html`) sirve por ahora; es adonde lleva el enlace de los correos de confirmación y de «olvidé mi contraseña». Más adelante conviene una página propia que diga «listo, volvé al juego».
4. *Email Templates* (opcional): podés traducir/editar los mensajes de confirmación y de recuperación.
5. *Rate Limits*: dejá los valores por defecto.

**Google Play como forma de entrar:** todavía no. Hacerlo bien pide el plugin nativo de *Google Play Games Services* para Godot, un cliente OAuth en Google Cloud y activar el proveedor Google en Supabase (entrar con el *ID token*). Se puede sumar encima de lo que hay sin tocar el resto (misma tabla de jugadores). Queda en la hoja de ruta.

## Cómo funciona (para no perderse)
- El juego usa solo la **clave pública**. Nadie puede escribir directo en las tablas: las marcas entran únicamente por `submit_score`, que valida que haya sesión, que la pista exista, que el tiempo sea posible (nadie recorre una pista a más de 120 m/s), y limita a 40 envíos por hora. Guarda **una mejor marca por jugador, pista y tabla** (carrera, contrarreloj, picada, drift).
- Las pistas y su largo están en la tabla `tracks`; **cuando agreguemos una pista nueva, va también una migración nueva** (`supabase/migrations/AAAAMMDDHHMMSS_nombre.sql`) con su fila.
- Quedan afuera de los rankings: modo desarrollador, pruebas de autos de la tienda, prácticas de la aventura y el duelo de drift contra el bot.
- La sesión se guarda en el teléfono (`user://online.json`). Con cuenta, al reinstalar vuelve con «Iniciar sesión».

## Antes de publicar con el online encendido
- La política de privacidad ya trae el apartado «Rankings online (opcional)» (en el juego solo se muestra si la versión trae el online configurado; también está en `docs/PRIVACIDAD.md` y `docs/privacidad.html`). **Volvé a publicar `privacidad.html`** si la tenés alojada (GitHub Pages lo hace solo al hacer push).
- **Play Console → Seguridad de los datos**: pasá a declarar que se recopilan *Dirección de correo electrónico* (solo si el jugador crea una cuenta), *Identificadores de usuario* (ID) y *Datos del juego* (puntuaciones), opcionales, usados para la «Funcionalidad de la app», no compartidos.
- El AAB ahora lleva el permiso de Internet.

## Lista para abrir el online (resumen)
Todo el código está hecho y probado contra servidores de mentira y Postgres de verdad; lo que falta es **encenderlo y probarlo con dos teléfonos**. Orden:
1. **Cuenta y compras** (obligatorio, ya sin el online): aplicar `20261014000000_account_economy.sql` y publicar la función de compras (`docs/CUENTA_Y_ECONOMIA.md`, «Puesta en marcha»).
2. **Tiempo real:** aplicar `20261012000000_realtime_private.sql`, en Supabase → *Realtime → Settings* apagar «Allow public access» y mirar los topes de tu plan (ver «Tiempo real» más abajo).
3. En `godot/game/data/release.gd`: `ONLINE_OPEN := true` y `REALTIME := true` (son las **dos únicas** líneas del juego que hay que cambiar), compilar y probar con dos teléfonos en el mundo online.
4. Play Console → *Seguridad de los datos*: ver `docs/PLAY_SEGURIDAD_DATOS.md` (la cuenta, las compras y, con el online, mensajes y ubicación aproximada del mapa del juego).

## Lo que sigue (cuando quieras)
Carreras uno contra uno en tiempo real (Supabase Realtime), eventos mensuales (tabla de eventos + función), nombres con filtro, y borrado de datos desde el juego. Todo se apoya en lo que ya quedó conectado.


## Mundo online: chat, jugadores, amigos, reportes y mercado
Migración `supabase/migrations/20261005000000_chat_social_market.sql` (se aplica con el mismo flujo de migraciones). Todo vive en tablas con RLS y **sin acceso directo**: el juego sólo usa funciones (RPC) con sesión de cuenta.
- **Presencia** (`presence_beat/leave/list`): posición (x, z del mapa del juego), velocidad y auto cada 6 s; quien lleva más de 45 s sin avisar deja de figurar. `presence_trail` guarda el rastro de los últimos 10 minutos (sirve de evidencia).
- **Chat** (`chat_send/fetch/threads`): canal `world` y privados `dm:<uuid>:<uuid>`. Un mensaje por segundo, 200 caracteres. `mask_bad_words` tapa con asteriscos los insultos (diccionario ES/EN, sin tildes ni mayúsculas, palabras de 4+ letras; se edita en la propia función). Cada **mensaje con insultos** suma una falta; **a las 10 faltas** se bloquea el chat 10 minutos, la próxima vez 20, 30… (nivel creciente). El insulto nunca se publica.
- **Amigos** (`follow_set/list`): seguir y dejar de seguir; en el juego «IR HASTA ÉL (GPS)» traza la ruta hasta donde está.
- **Reportes** (`report_submit`): guarda en `reports.evidence` (JSON) los últimos mensajes del reportado, su rastro y el de quien reporta, sus faltas de chat y lo que vio el teléfono (chat visto, posición, velocidad, golpes). **No castiga a nadie**: se revisa a mano. Máximo 5 reportes por hora y por jugador. Para leerlos: exportá la tabla `reports` a JSON y corré `python3 tools/online/report_view.py reportes.json` (explica quién reportó a quién, mensajes tapados, velocidades máximas, saltos raros de posición y si estuvieron cerca).
- **Mercado** (`market_list/browse/cancel/buy/collect`): el auto sale del garaje del vendedor al publicarse (con mejoras y pintura), el precio lo pone el dueño, se reserva para quien compra primero y el comprador paga con créditos. Desde la migración de la economía online (`20261007010000_online_economy.sql`) la billetera y los autos viven en el servidor (el teléfono no manda «cuánta plata tengo»); sin dinero real.
- Borrar la cuenta (`delete_my_account`) borra todo lo anterior.
- Los demás autos se ven en el mapa (`remote_cars.gd`, posiciones cada ~2 s por `presence_list_v`). **Falta**: moderación en la web (marcar reportes como revisados desde un panel) y el tiempo real (sección siguiente).

## Tiempo real (Supabase Realtime) — listo para conectar
**Estado (12/10/2026):** el código del juego, las reglas del servidor y las pruebas están hechos. Está **apagado**: `Release.REALTIME := false` (y el modo online sigue cerrado, `ONLINE_OPEN := false`). No se pudo probar contra un Supabase de verdad desde acá (sin cuenta ni red hacia el proyecto): todo se probó contra un servidor de mentira que habla el mismo protocolo. **La primera conexión real va a necesitar una prueba con 2 teléfonos** (ver «Cómo encenderlo»).

### Qué hay
| Pieza | Dónde |
|---|---|
| Cliente de Realtime (WebSocket, protocolo Phoenix `vsn 1.0.0` como supabase-js): canales, broadcast, presencia, latidos, reconexión con espera creciente, tope de mensajes por canal, renovación de la sesión | `godot/game/online/realtime.gd` |
| Posiciones del mundo: **celdas de 2 km** + **ritmo adaptativo** (ahorran mensajes) | `godot/game/online/world_sync.gd` |
| Reglas del servidor: canales **privados** `world:*` sólo para cuentas con correo y no suspendidas (tabla `realtime_bans`) | `supabase/migrations/20261012000000_realtime_private.sql` |
| Servidor de mentira (biblioteca estándar de Python) para probar sin red | `tools/online/mock_realtime.py` |
| Pruebas: reglas de celdas y de ritmo, mensajes imposibles, entrar/salir, presencia, broadcast, anónimos sin permiso, reconexión, ahorro entre celdas lejanas (CI) | `godot/tests/realtime_test.gd`, `tools/online/economy_test.sql` (políticas) |
| Integración (dormida con la bandera apagada) | `race.gd` (`rtsync`), `remote_cars.gd` (`apply_live`) |

### Cómo funciona
- **Celdas:** el mundo se parte en cuadrados de 2 km. Cada jugador manda su posición **sólo al canal de su celda** (`world:<cx>:<cz>`) y escucha su celda más las vecinas a menos de 700 m del borde (como mucho 4 canales; se mantienen 150 m más para no abrir y cerrar en el borde). Dos jugadores a 30 km no se mandan nada.
- **Ritmo adaptativo:** cada mensaje se entrega a los demás del canal, así que con k jugadores hay k·(k−1) entregas por tick. Se reparte un presupuesto de **60 entregas por segundo por canal**: solo → 1 mensaje cada 10 s · 2 o 3 jugadores → 5 Hz · 5 → 3 Hz · 8 → 1,1 Hz · 11 o más → 0,5 Hz. Quieto manda 1 cada 5 s; en movimiento sólo si se movió más de 40 cm. Cuántos son lo dice la presencia del canal (todos hacen `track` al entrar).
- **Qué viaja:** `{i: id, x, z, a: rumbo, v: km/h, n: secuencia}` (~100 bytes). **Nombres y modelos NO viajan por Realtime**: siguen saliendo de `presence_list_v` (que filtra el servidor); así un tramposo no puede mandar un apodo ofensivo salteándose el filtro.
- **Los mensajes son de cliente a cliente: no son autoritativos.** Se descarta lo imposible (sin datos, NaN, fuera del mapa, velocidad absurda) y nada de la economía depende de esto: sólo se dibujan autos. Un tramposo puede mandar posiciones falsas de *su propio* id (o de otro: Realtime no firma al que manda); a lo sumo mueve un auto de papel en la pantalla de los demás.
- **Seguridad del canal:** canales privados (`private: true` al entrar) autorizados por las políticas `dr_world_read` / `dr_world_write` de `realtime.messages`: cuenta con correo (no anónima), tema que empieza con `world:`, sólo `broadcast` y `presence`, y no suspendida. Para suspender a alguien: `insert into public.realtime_bans (player_id, until, reason) values ('<uuid>', null, 'motivo');` (la política se evalúa al entrar a un canal: se corta cuando se reconecta o renueva la sesión).

### Capacidad para ~50 jugadores (cuentas y costos)
Los topes por plan (a revisar en tu panel: *Settings → Realtime* y la página de precios, cambian) son aproximadamente: **Free** 200 conexiones y 100 mensajes/s · **Pro** 500 conexiones y 500 mensajes/s (ampliables a pedido); los mensajes incluidos y el precio por millón extra también están en la página de precios.
- **50 conexiones** entran en cualquier plan. Lo que manda es **mensajes por segundo** (y, en Pro, el costo por millón).
- **Entregas por segundo** = suma sobre los canales de k·(k−1)·ritmo(k): un canal con k=2 consume 10/s; k=5 → 60/s; k=11 → 55/s; k=25 → 300/s; k=50 → 1.225/s.
- **50 jugadores repartidos** (la mayoría solos o de a dos): ≈ 100–300 mensajes/s → **entra en Pro (500/s)**; en Free (100/s) sólo con 10–15 jugadores.
- **50 jugadores juntos en la misma plaza** ≈ 1.225 entregas/s → **no entra en Pro sin pedir más cupo** a Supabase (o hay que bajar el ritmo mínimo o limitar cuántos autos se muestran por celda). Es el caso límite a tener presente para eventos.
- **Costo:** se paga por mensaje. Con 300 mensajes/s durante 2 horas = 2,2 millones; con 10 jugadores promedio y pocos encuentros el consumo es una fracción de eso. Conviene mirar el gráfico de uso de Realtime los primeros días y ajustar `BUDGET`, `MIN_HZ`, `MAX_HZ` en `world_sync.gd` (están a propósito en constantes).
- Los latidos (cada 25 s por conexión) y la presencia (alta/baja) son poquísimos mensajes.

### Cómo encenderlo (cuando llegue el momento)
1. **Aplicar la migración** `20261012000000_realtime_private.sql` con el flujo «Supabase · aplicar migraciones» (y las dos del 9/10 si todavía no estaban).
2. Supabase → **Realtime → Settings**: **Allow public access: OFF** (si no, cualquiera entra a canales públicos sin autorización); revisar *Max concurrent clients / events per second / joins per second* para tu plan; si hace falta, pasar a Pro.
3. En `godot/game/data/release.gd`: `ONLINE_OPEN := true` y `REALTIME := true`. Compilar con los secretos de Supabase (como hoy).
4. **Prueba con 2 teléfonos** en el mundo online: ¿se ven moviéndose fluido (no a saltos de 2 s)?, ¿se ven al cruzar el borde de una celda (a 2 km del punto de aparición)?, ¿se van al salir? Si un teléfono no ve al otro: mirar *Realtime → Inspector* en el panel de Supabase (canales `world:*`) para ver si llegan los mensajes.
5. Prueba de carga: sumar de a poco testers y mirar el gráfico de mensajes por segundo.
6. Antes de abrir: revisar `docs/PRIVACIDAD.md` (ya dice que la posición viaja en tiempo real a los jugadores cercanos) y la ficha de *Seguridad de los datos* de Play (ubicación aproximada: sí, opcional, no compartida con terceros; sólo la ven otros jugadores cerca).

### Lo que NO está hecho (queda para la actualización de tiempo real)
- Que los autos de los otros jugadores se vean y se muevan igual de bien que los de la IA (hoy se ven más simples y con retraso; con posiciones a 5 Hz queda la interpolación, el suavizado y el modelo real a distancias medias): es el trabajo de esa actualización.
- Chat por Realtime (hoy sigue por `chat_fetch` cada 3–12 s) y carreras uno contra uno. El cliente ya sirve para ambas (broadcast + presencia); falta la lógica de juego.
- Probar con un proyecto Supabase real (ver arriba): el protocolo está implementado según supabase-js 2.x (`vsn 1.0.0`, `phx_join` con `config.private`, `broadcast`, `presence`, `access_token`), pero sin una prueba real puede aparecer algún detalle (por ejemplo, un cambio de versión de protocolo).

