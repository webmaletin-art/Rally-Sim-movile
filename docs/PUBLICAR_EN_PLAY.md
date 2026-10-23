# Publicar en Google Play con un solo mensaje — procedimiento (21/10/2026)

Este documento es para el dueño. Explica cómo funciona la publicación automática de Dream Racing en Google Play **con la API oficial** (no sólo «bajar un archivo»).
Las herramientas están en `tools/play/` y el flujo en `.github/workflows/play-release.yml` («Play · Publicar»). Sirven tal cual para otros juegos del estudio (ver el final).

## 1. La frase mágica

Cuando probaste el juego en tu teléfono y está bien, le decís a Claude:

> **«Dream Racing está listo para publicar»**

Claude entonces, en este orden, y **se detiene y te explica qué falta si algo no se puede cumplir**:

1. **Auditoría previa** (`tools/play/audit.py`): paquete, API de destino, firma configurada, productos (juego ↔ servidor ↔ lista), ficha, imágenes, textos legales y flujos.
2. **Pruebas** (107 obligatorias, las mismas de «Build Godot APK»). Si ya pasaron en verde con exactamente el mismo código del juego se aceptan; si no, se corren todas. **Si una falla, no se publica.**
3. **AAB firmado** con la clave de subida (sin los secretos de firma el flujo se corta: ya no existe el «AAB de depuración» en este camino).
4. **Verificación del AAB** (`tools/play/verify_aab.py`): firma íntegra y que **no** sea la clave de depuración, huella igual a la registrada en Play, paquete `com.srg.dreamracing`, `versionCode`/`versionName` esperados, API 36, permiso de compras (plugin adentro) y páginas de 16 KB.
5. **Subida a Google Play** (`tools/play/publish.py`): se abre una edición, se sube el bundle, se arma la versión con las notas en 6 idiomas, **Google valida** y recién ahí se confirma.
6. **Informe**: el resultado de cada paso y dónde comprobarlo en Play Console.

Claude **no dice «publicado»** si sólo se compiló o se subió a GitHub. Sólo lo dice cuando Google confirmó la edición, y te da el lugar para verlo (Play Console exige tu sesión).

### Qué autoriza cada cosa
| Pista | Qué es | Cómo se autoriza |
|---|---|---|
| `internal` | Pruebas internas (hasta 100 testers, sin revisión) | La frase «listo para publicar» |
| `alpha` | **Prueba cerrada** (la de los 12 testers × 14 días) | La frase «listo para publicar» (decir «en prueba cerrada») |
| `beta` | Prueba abierta | La frase y decir «en prueba abierta» |
| `production` | **Producción (público)** | Frase aparte, por versión: **«AUTORIZO PRODUCCION 1.0.0»** (el número de esa versión). Sin ella el sistema se niega, aunque se lo pidan |

Además, en modo `publish` el flujo exige escribir `PUBLICAR`, y sólo publica desde la rama `main`.

## 2. Los dos modos del flujo «Play · Publicar»

GitHub → **Actions → «Play · Publicar» → Run workflow** (rama `main`). (Claude lo lanza por vos cuando se lo pedís.)

| Modo | Qué hace |
|---|---|
| `validate` (por defecto) | **No publica nada.** Hace todo, sube el AAB a una edición temporal de Google, la valida y la **borra**. Es el «ensayo general». |
| `publish` | Igual, y **confirma**: la versión queda en la pista elegida. Exige `confirm = PUBLICAR`. |

Otros datos del formulario: `track` (pista), `version_name` (ej. `1.0.0`), `release_status` (`completed` = disponible; `draft` = borrador que enviás a mano), `rollout_percent` (sólo producción: % de usuarios), `update_listing` (sube también la ficha), `tests` (`reuse` o `all`).

El número de versión (`versionCode`) **no se repite**: el flujo le pregunta a Google cuál es el mayor ya usado y toma el siguiente.
El AAB queda como **artefacto de la corrida** (30 días) y **no** se sube a GitHub Releases por este camino (el flujo viejo «Build Play Store AAB» sigue existiendo para bajar un archivo a mano).

## 3. Conectar Google Play (UNA sola vez) — lo que sólo podés hacer vos

El flujo necesita la **cuenta de servicio** de Google. Ya existe el nombre del secreto en GitHub (`GOOGLE_PLAY_SERVICE_ACCOUNT`); **desde acá no puedo ver si está cargado ni si funciona**: el primer «validate» lo dice. Si falta o falla, los pasos son:

1. **Google Cloud** (console.cloud.google.com): elegí/creá un proyecto → *APIs y servicios* → habilitá **«Google Play Android Developer API»**.
2. *IAM y administración → Cuentas de servicio → Crear cuenta de servicio* (nombre p. ej. `dreamracing-play`) → *Claves → Agregar clave → JSON* → se descarga un `.json`.
3. **Play Console → Usuarios y permisos → Invitar usuarios nuevos** → el correo de la cuenta de servicio (`…@…iam.gserviceaccount.com`) → permisos de **la app** Dream Racing: *Ver información de la app*, *Publicar en pruebas* / *Administrar versiones de las pistas de prueba*, *Administrar la presencia en la tienda* (ficha) y, para producción, *Publicar en producción*. (Esa misma cuenta usa la función de compras de Supabase: sumale *Ver datos financieros* y *Administrar pedidos*.) Puede tardar **hasta ~24 h** en activarse.
4. **GitHub → Settings → Secrets and variables → Actions → New repository secret**: nombre `GOOGLE_PLAY_SERVICE_ACCOUNT`, valor = **todo el contenido** del `.json`. Después borrá el archivo de tu compu.
5. *(Recomendado)* **Variable** (pestaña *Variables*, no es secreta) `UPLOAD_CERT_SHA256` = la huella SHA-256 de **Play Console → Prueba y publicación → Integridad de la aplicación → Firma de la app → «Certificado de clave de carga»**. Con eso el flujo comprueba solo que el AAB está firmado con **esa** clave. La huella del AAB que se armó el 21/10 (v1006) es `50:59:FD:2C:9B:DB:2C:D3:1C:2D:54:45:19:26:8B:26:5F:BD:1E:35:D3:FA:F0:DC:69:46:D9:57:C8:5B:6C:86` (certificado «SRGamestudios», vence en 2054; no es la clave de depuración): **comparala con la de Play** antes de cargar la variable.
6. *(Recomendado)* **GitHub → Settings → Environments → `google-play-produccion` → Required reviewers**: te ponés a vos. Así producción pide además un clic tuyo.

Después: Actions → «Play · Publicar» → modo **validate**. Si termina en verde, Google ya aceptó el AAB y la cuenta de servicio funciona.

## 4. Secretos y variables que usa el sistema (nunca se imprimen)

| Nombre | Para qué | Cómo sé que está |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` | Firma de subida | La auditoría dice «configurado»; además el AAB del 21/10 salió firmado con la clave real (CN=SRGamestudios) |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Cuenta, créditos y compras del juego | El armado del 21/10 pasó el paso que los exige |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Hablar con Google Play (publicar, estado, productos) | **No verificable desde acá**: lo dice el primer «validate» |
| variable `UPLOAD_CERT_SHA256` | Comparar la firma con la registrada en Play | Opcional; sin ella el flujo avisa y muestra la huella para comparar a mano |
| `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_ID`, `SUPABASE_DB_PASSWORD` | Migraciones y funciones de Supabase (otros flujos) | — |

Reglas: **nunca** pegues claves, contraseñas ni el JSON en el chat, en archivos del repositorio ni en capturas. Sólo en *Secrets* de GitHub.

## 4 bis. Primer «validate» real contra Google (23/10/2026) — resultado

Corrida n.º 1 de «Play · Publicar» sobre `main` (`660552c`), modo validar, pista interna:
- ✅ Los 5 secretos de firma y de Supabase **existen** (la auditoría con los valores a mano los vio presentes). *(El paso en línea los marcó «faltantes» por un defecto mío —no recibía esas variables—; ya está corregido con `--no-secret-check`.)*
- ✅ El secreto **`GOOGLE_PLAY_SERVICE_ACCOUNT` existe, es un JSON de cuenta de servicio válido y Google lo aceptó** (la autenticación funcionó; la cuenta es `dre…@srg-play-publisher.iam.gserviceaccount.com`).
- ⛔ **Google contestó 404 «Package not found: com.srg.dreamracing».** Es decir: la API llega, pero **para esa cuenta de servicio la app todavía no existe**. Lo más probable —es el comportamiento conocido de Play Console— es que **el paquete queda asociado a la app recién cuando se sube el primer AAB a mano**. Otras causas posibles: la cuenta no tiene permisos sobre esa app, o la invitación tiene menos de ~24 h. Desde acá no se puede distinguir.
- ➖ El resto del flujo (pruebas, build, subida) no corrió porque la auditoría en línea frenó antes, a propósito.

**Lo que hay que hacer una sola vez (sólo vos):** subir **a mano** el AAB `DreamRacing-play-v1006.aab` a *Play Console → Prueba y publicación → Pruebas internas → Crear versión* (aceptar Play App Signing). Eso crea el vínculo del paquete. Después, en *Usuarios y permisos*, comprobar que la cuenta `srg-play-publisher` tiene permisos sobre la app. Y avisarme: corro de nuevo «validate» y, si da verde, sigo con las publicaciones por API (la versión 1006 ya subida a mano no estorba: el flujo usa un código mayor).

## 4 ter. «Play · Estado»: consulta de SÓLO LECTURA (23/10/2026)

Actions → **«Play · Estado»** → Run workflow. Ejecuta únicamente `python3 tools/play/publish.py status`, que **sólo envía pedidos GET** (`applications.tracks.releases.list`) y muestra pistas, versiones y artefactos activos. No abre ediciones, no sube AAB, no toca `versionCode`, pistas ni ficha. Candados: revisión estática (`tools/play/check_status_readonly.py`), filtro en el cliente que rechaza todo lo que no sea GET, y permisos de GitHub de sólo lectura. (Antes `status` abría y borraba una edición temporal; ya no.)

## 5. Primera publicación de prueba (paso a paso)

1. Probás el juego en tu teléfono. Si está bien: **«Dream Racing está listo para publicar»**.
2. Claude fusiona la rama de trabajo a `main` (con tu OK), lanza **validate** en `internal` y te cuenta el resultado.
3. Si da verde, Claude lanza **publish** en `internal` (con `PUBLICAR`). Vos abrís Play Console → *Prueba y publicación → Pruebas internas* y mirás la versión; instalás desde el enlace de testers y probás las compras con tu cuenta de licencia.
4. **Prueba cerrada**: vos conseguís los testers (la regla de Google: si la cuenta es personal y se creó después del 13/11/2023, **12 testers inscriptos durante 14 días seguidos**). Cuando estén, Claude publica la misma versión en `alpha` y anota la fecha en `tools/play/game.json → closed_test.started_on` para que `status` cuente los días.
5. A los 14 días: **vos** pedís el acceso a producción en Play Console (*Panel → Solicitar acceso a producción*: la API de Google no lo ofrece y es una declaración tuya). Cuando Google lo aprueba, decís **«AUTORIZO PRODUCCION 1.0.0»** y Claude publica con `rollout_percent` (se recomienda 20 % primero).
6. Para versiones siguientes: Claude prepara los cambios, sube número de versión solo, y se repite el ciclo (validate → internal → alpha → producción).

## 6. Qué comprueba el sistema y qué no

**Se verifica solo (con evidencia en el informe):** paquete y API 36; plugin de compras fijo (3.3.0) y permiso de Billing en el AAB; firma íntegra y no-depuración (probado sobre el AAB real v1006 de GitHub); `versionCode` único; 16 KB; 107 pruebas; textos (límites 30/80/4000/500) en 6 idiomas; íconos y capturas (tamaños y formatos); productos juego ↔ servidor ↔ lista; con la cuenta de servicio: acceso real a la app, versiones y productos existentes en Play.

**No se puede verificar solo (depende de vos o de Google):**
- Que el secreto `GOOGLE_PLAY_SERVICE_ACCOUNT` exista y tenga permisos (se descubre al correr `validate`).
- Que la huella de firma sea la **registrada** en Play (hasta cargar `UPLOAD_CERT_SHA256`; la API de Google no la entrega).
- Las **declaraciones** de Play Console (Seguridad de los datos, clasificación de contenido, anuncios, público objetivo, acceso a la app con la cuenta de revisión): no hay API; ver `docs/PLAY_SEGURIDAD_DATOS.md` y la guía de Play Console.
- Que los **12 testers** estén inscriptos y hayan pasado los **14 días**, y la **aprobación de producción**: lo decide Google (la API no lo informa).
- Las **compras reales** (plugin 3.3.0 con el motor 4.7.2): sólo con tu cuenta de licencia en la prueba interna.
- Que la app esté **en borrador** o ya tenga una primera versión: si está en borrador Google sólo acepta versiones en estado «borrador» por la API (el flujo reintenta así y avisa); y es posible que la **primera subida** haya que hacerla a mano en Play Console. No lo puedo confirmar desde acá.

## 7. Ficha, fotos y vídeo

| Elemento | Estado (21/10/2026) |
|---|---|
| Textos corto/largo en es-419, en-US, pt-BR, fr-FR, it-IT, de-DE | ✅ listos y dentro de límites (`store_listing/ficha.md`) |
| Novedades de la versión (6 idiomas, ≤ 500) | ✅ `store_listing/novedades.md` (se suben solas con la versión) |
| Ícono 512×512 | ✅ pero es el **«DR» provisorio** (reemplazable cuando haya logo) |
| Gráfico de funciones 1024×500 | ✅ |
| 8 capturas reales de teléfono (1920×1080) | ✅ `store_listing/capturas/` (tomadas con el motor del juego) |
| Capturas de tablet 7"/10" | ➖ opcionales; no hay |
| Política de privacidad / eliminación de cuenta / contacto | ✅ en el repositorio y enlazadas (que las páginas respondan se ve en la auditoría en línea; vos revisalas) |
| **Vídeo promocional** | ⚠️ **Hay un tráiler real** (hecho con el juego) pero **Play sólo acepta un enlace de YouTube** y todavía no está subido. Falta: subirlo a YouTube («no listado» alcanza) y pegar la URL en `tools/play/game.json → listing.video_youtube_url`. No se inventa ni se sube nada ficticio |

Subir la ficha por API: modo `validate`/`publish` con `update_listing = true` (o `python3 tools/play/listing.py sync --mode validate`). **La ficha no se da por completa** mientras la auditoría muestre BLOQUEO en el punto que sea; las **declaraciones** de Play Console (sección 6) son aparte y siguen siendo manuales.

## 8. Productos integrados (compras)

El juego tiene **10 productos**; los IDs son **exactos** y no se pueden cambiar después de crearlos. Hay que crearlos en *Play Console → Monetizar → Productos → Productos integrados* y **activarlos**:

| ID | Tipo | Precio USD recomendado |
|---|---|---|
| `dr_full` | No consumible (producto único) | 9,99 |
| `dr_adventure` | No consumible | 4,99 |
| `dr_garage` | No consumible | 6,99 |
| `car_truck` | No consumible | 1,99 |
| `car_gt3` | No consumible | 2,99 |
| `car_hyper` | No consumible | 3,99 |
| `dr_coins_s` | **Consumible** | 0,99 |
| `dr_coins_m` | Consumible | 1,99 |
| `dr_coins_l` | Consumible | 3,99 |
| `dr_coins_xl` | Consumible | 7,99 |

El sistema compara esto con Play (`python3 tools/play/publish.py products`, necesita la cuenta de servicio) y **no crea ni cambia precios**. En el juego están implementados: restaurar compras, reconocer las únicas, consumir las monedas **después** de acreditarlas el servidor, cancelación por el jugador y error de compra.

## 9. Si algo falla

| Mensaje | Qué hacer |
|---|---|
| «Falta el secreto GOOGLE_PLAY_SERVICE_ACCOUNT» | Sección 3 |
| «La cuenta de servicio no tiene permiso» (403) | Sección 3, paso 3; esperar hasta 24 h |
| «Ese código de versión ya existe» | Correr de nuevo: el flujo toma el siguiente |
| «La app todavía está en borrador» | Se reintenta como borrador; terminá el primer envío en Play Console |
| «Firma no coincide / no es la de subida» | **No cambies la clave.** Revisá los secretos de firma o pedí a Claude que compare con la huella de Play |
| «Producción NO autorizada» | Es lo esperado: escribí `AUTORIZO PRODUCCION <versión>` |
| Una prueba falla | No se publica. Se arregla en la rama de trabajo y se vuelve a correr |

## 10. Reutilizar para otro juego del estudio

1. Copiar `tools/play/` y `.github/workflows/play-release.yml`.
2. Editar `tools/play/game.json` (paquete, nombre, idiomas, productos, rutas de la ficha) y los pasos de compilación de Godot del flujo (preset, plugin de compras).
3. Crear la cuenta de servicio y los secretos (sección 3). Las herramientas (`audit`, `verify_aab`, `publish`, `listing`) no tienen nada propio de Dream Racing fuera de `game.json`.
4. Correr `python3 tools/play/tests/publish_test.py` (prueba contra un Google Play falso, sin credenciales).
