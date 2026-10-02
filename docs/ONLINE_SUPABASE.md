# Modo online con Supabase — paso a paso

Ya está todo **cableado** en el repositorio: base de datos (tablas, seguridad y funciones), cliente del juego, compilación con tus claves y prueba de conexión.
Lo único que falta son **tus claves**, que se cargan una vez en GitHub. Nada de esto se activa hasta que lo hagas, y aun con todo cargado los rankings
están **apagados de fábrica** y cada jugador elige si participa.

## Qué hay en el repositorio
| Qué | Dónde |
|---|---|
| Base: jugadores anónimos, pistas, mejores marcas, seguridad por filas (RLS) y funciones `submit_score`, `get_leaderboard`, `set_player_name` | `supabase/migrations/20261003000000_online_base.sql` (probada contra un Postgres real) |
| Configuración de Supabase (con «anonymous sign-ins» activado) | `supabase/config.toml` |
| Cliente del juego (entra sin cuenta, manda marcas, trae rankings) | `godot/game/online/online.gd` + `online_config.json` (vacío en el repo) |
| Envío automático de la marca al terminar una carrera (si el jugador participa) | `godot/game/app.gd` (`_submit_online`) |
| Pantalla Online: opción «Participar en los rankings online» y, en modo desarrollador, **«Probar conexión con Supabase»** | `ui/menu.gd` (`_online_options`) |
| Compilación del APK y del AAB: escriben la dirección y la clave pública dentro de la app desde los secretos | `.github/workflows/build-godot.yml` y `build-aab.yml` |
| Aplicar las migraciones desde GitHub (opcional) | `.github/workflows/supabase-deploy.yml` |
| Pruebas | `godot/tests/online_test.gd` (con un Supabase de mentira, `tools/online/mock_supabase.py`) |

## Paso a paso (unos 15 minutos)

### 1) En Supabase (supabase.com)
1. **Proyecto**: si todavía no lo creaste, *New project* → nombre `dream-racing`, región **South America (São Paulo)**, y una **contraseña de base de datos** (guardala).
2. **Autenticación anónima** (imprescindible: el juego entra sin cuenta): *Authentication → Sign In / Providers* (o *Settings → Authentication*) → activá **«Allow anonymous sign-ins»**.
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
3. Tiene que decir **«✔ Conectado a Supabase (usuario xxxxxx…)»**. Si falla, el mensaje dice por qué (falta la clave, la autenticación anónima está apagada, o no se aplicaron las migraciones).
4. El modo desarrollador **no manda marcas** (para que nadie ensucie los rankings). Apagalo (**Acerca de → APAGAR MODO DESARROLLADOR**), corré una carrera y mirá en Supabase → *Table Editor → scores*: aparece tu marca. (Con el modo desarrollador apagado ya no ves el botón de prueba, pero el juego sigue funcionando igual.)

## Cómo funciona (para no perderse)
- El juego usa solo la **clave pública**. Nadie puede escribir directo en las tablas: las marcas entran únicamente por `submit_score`, que valida que haya sesión, que la pista exista, que el tiempo sea posible (nadie recorre una pista a más de 120 m/s), y limita a 40 envíos por hora. Guarda **una mejor marca por jugador, pista y tabla** (carrera, contrarreloj, picada, drift).
- Las pistas y su largo están en la tabla `tracks`; **cuando agreguemos una pista nueva, va también una migración nueva** (`supabase/migrations/AAAAMMDDHHMMSS_nombre.sql`) con su fila.
- Quedan afuera de los rankings: modo desarrollador, pruebas de autos de la tienda, prácticas de la aventura y el duelo de drift contra el bot.
- La sesión anónima se guarda en el teléfono (`user://online.json`). Si desinstalan la app, el jugador nuevo es otro usuario.

## Antes de publicar con el online encendido
- La política de privacidad ya trae el apartado «Rankings online (opcional)» (en el juego solo se muestra si la versión trae el online configurado; también está en `docs/PRIVACIDAD.md` y `docs/privacidad.html`). **Volvé a publicar `privacidad.html`** si la tenés alojada (GitHub Pages lo hace solo al hacer push).
- **Play Console → Seguridad de los datos**: pasá a declarar que se recopilan *Identificadores de usuario* (ID anónimo) y *Datos del juego* (puntuaciones), opcionales, usados para la «Funcionalidad de la app», no compartidos.
- El AAB ahora lleva el permiso de Internet.

## Lo que sigue (cuando quieras)
Carreras uno contra uno en tiempo real (Supabase Realtime), eventos mensuales (tabla de eventos + función), nombres con filtro, y borrado de datos desde el juego. Todo se apoya en lo que ya quedó conectado.
