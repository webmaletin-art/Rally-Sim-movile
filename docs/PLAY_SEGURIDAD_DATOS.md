# Google Play · «Seguridad de los datos» y eliminación de la cuenta — paso a paso

Para el dueño. Todo lo que se puede hacer desde el repositorio ya está hecho (política de privacidad, página de eliminación de cuenta, borrado desde el juego y en la base). Acá van **los pasos que solo se pueden hacer en tu cuenta de Play Console / Supabase / GitHub**, en orden, con **las respuestas exactas** para cada pregunta.

## Qué datos maneja Dream Racing (la base de todas las respuestas)
| Dato | Cuándo se envía a nuestro servidor (Supabase) | Para qué |
|---|---|---|
| **Correo electrónico** (y contraseña cifrada) | solo si el jugador **crea una cuenta** (opcional) | recuperar las marcas en otro teléfono; mensajes de confirmación y de «olvidé mi contraseña» |
| **ID de usuario** (un número anónimo que crea Supabase) | solo si el jugador **participa en los rankings** o crea una cuenta | identificar sus marcas; frenar abusos |
| **Nombre de piloto** (apodo que elige) | solo si participa en los rankings | se muestra en el ranking |
| **Marcas** (tiempo/puntos, pista, auto) | solo si participa en los rankings | armar el ranking |
| **Mensajes de chat** (mundial y privados) | solo en el **mundo online** (con cuenta), al escribirlos | chat entre jugadores; se guardan para revisar abusos |
| **Posición en el mapa del juego, velocidad y auto** | solo en el **mundo online**, cada pocos segundos | mostrar quién está conectado; el rastro dura minutos; **no es la ubicación real del teléfono** |
| **Amigos, reportes y autos en venta** | solo en el mundo online, cuando el jugador los usa | lista de amigos, revisión de abusos (evidencia guardada), mercado entre jugadores |
| Registro de envíos (`score_log`: ID + hora) | cada vez que manda una marca | limitar a 40 envíos por hora (antiabuso) |

**Todo lo demás se queda en el teléfono** (autos, mejoras, créditos, nafta, opciones, capturas) y nunca se envía. No hay anuncios, ni analytics, ni ID de publicidad, ni ubicación **real** del teléfono, ni contactos. (Las coordenadas del mundo online son del mapa del juego.) Las **compras** las procesa Google Play (el juego no ve datos de pago). Los rankings vienen **apagados de fábrica**.

## Paso 0 · Tres comprobaciones antes de tocar Play Console
1. **Que las dos páginas web abran** (GitHub → Settings → Pages → Source: «GitHub Actions», y que el flujo «Deploy static content to Pages» salga verde):
   - Privacidad: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html`
   - **Eliminar cuenta** (la nueva): `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html`
   Abrilas desde el teléfono y fijate que se lean bien.
2. **Que el borrado de cuenta funcione en la base real** (Supabase → tu proyecto → *Database → Functions*): tiene que existir **`delete_my_account`**. Si no aparece, en GitHub: *Actions → «Supabase · aplicar migraciones» → Run workflow* (aplica `supabase/migrations/20261003010000_delete_account.sql`).
3. **¿La versión de Play lleva el modo online?** Solo lo lleva si cargaste los secretos `SUPABASE_URL` y `SUPABASE_ANON_KEY` en GitHub (*Settings → Secrets and variables → Actions*) antes de compilar el AAB. Mirá en el registro de «Build Play Store AAB» el paso *«Configurar el modo online (Supabase)»*: si dice *«Modo online configurado»* → seguí con **la Opción A**; si dice *«Sin secretos de Supabase»* → **Opción B**.

## Paso 1 · Probar el borrado desde el juego (5 minutos, con el APK de prueba)
1. Abrí el juego → **MODO ONLINE** → **Cuenta con correo (opcional)** → creá una cuenta de prueba.
2. Volvé a esa pantalla → **Borrar mi cuenta y mis marcas** → confirmá. Tiene que decir *«Listo: se borraron tu cuenta y tus marcas»*.
3. En Supabase → *Authentication → Users*: el usuario de prueba ya no tiene que estar.
(Google puede pedirte esto como prueba. Sacale una captura a la pantalla de borrado: sirve si Play la pide en la revisión.)

## Paso 2 · Play Console → «Seguridad de los datos»
Ruta: *Play Console → tu app → **Política y programas → Contenido de la app → Seguridad de los datos** → Empezar / Administrar*.

### Opción A (la versión de Play lleva el modo online) — respuestas
**Pantalla «Recopilación y seguridad de los datos»**
| Pregunta | Respuesta |
|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos de usuario obligatorios? | **Sí** |
| ¿Todos los datos de usuario que recopila tu app se cifran en tránsito? | **Sí** (todo va por HTTPS) |
| ¿Ofreces a los usuarios una forma de solicitar que se borren sus datos? | **Sí** |
| URL para solicitar el borrado | `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html` |

**Pantalla «Tipos de datos»** — tildá **solo** estos (dejá todo lo demás sin tildar). Con el chat y la posición del mundo online hay que sumar los de abajo:
| Categoría | Tipo | 
|---|---|
| Información personal | **Dirección de correo electrónico** |
| Información personal | **Nombre** (el apodo de piloto) |
| Información personal | **ID de usuario** («Identificadores de usuario») |
| Actividad en la app | **Otras acciones** (las marcas/puntajes de juego) |
| Mensajes | **Otros mensajes dentro de la app** (el chat del mundo online) |
| Ubicación | **Ubicación aproximada** (coordenadas del mapa del juego; Play pide declararla igual porque se manda al servidor y se ve en el mundo online) — marcala como **Opcional**, finalidad «Funciones de la app», **no compartida**, y aclaralo en la descripción |

*No* tildes: ubicación **precisa**, contactos, fotos/videos, audio, archivos, información financiera (las compras las maneja Google), identificadores de dispositivo o de publicidad, historial de navegación, diagnósticos de fallas.

**Pantalla de cada tipo de dato** (te la hace para cada uno de los cuatro):
| Tipo | ¿Se recopila? | ¿Se comparte? | ¿Efímero? | ¿Obligatorio u opcional? | Finalidades |
|---|---|---|---|---|---|
| Correo electrónico | Se recopila | **No** | No | **Los usuarios pueden elegir** si se recopila | Administración de la cuenta |
| Nombre (apodo) | Se recopila | **No** | No | **Opcional** | Funciones de la app |
| ID de usuario | Se recopila | **No** | No | **Opcional** | Funciones de la app · Administración de la cuenta · Prevención del fraude, seguridad y cumplimiento |
| Otras acciones (marcas) | Se recopila | **No** | No | **Opcional** | Funciones de la app |

Por qué «No se comparte»: los datos los procesa Supabase **por nuestra cuenta** (proveedor de servicios), y Google no cuenta eso como «compartir». Que el apodo y las marcas se vean en el ranking tampoco es compartir con terceros.

**Prácticas de seguridad (última pantalla):** cifrado en tránsito **Sí** · borrado **Sí** (misma URL) · «Cumple la política de Familias» **No** (público 13+) · revisión de seguridad independiente **No**.

### Opción B (la versión de Play NO lleva el modo online todavía)
Contestá **«No»** a «¿Tu app recopila o comparte alguno de los tipos de datos de usuario obligatorios?» y listo (las compras las maneja Google; el progreso queda en el teléfono). Cuando actives el online, **repetí este paso con la Opción A**.

Al final: **Guardar → Vista previa** (revisá que diga lo mismo que la política de privacidad) → **Enviar**.

## Paso 3 · Eliminación de la cuenta
En la misma zona (*Contenido de la app → Seguridad de los datos*, y/o la tarjeta **«Eliminación de la cuenta»** / **«Borrado de datos»** si te aparece aparte) pegá **la misma URL**: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html`.
Play pide dos cosas y las dos ya están: **borrar desde la app** (MODO ONLINE → Cuenta → *Borrar mi cuenta y mis marcas*) y **una página web** que explique cómo pedirlo y qué datos se borran.

## Paso 4 · Otras declaraciones que tienen que coincidir
- **Política de privacidad (URL):** la de arriba (ya habla del modo online, la cuenta, el borrado y los derechos).
- **Acceso a la app:** *«Toda la funcionalidad está disponible sin restricciones de acceso especiales»* (la cuenta es opcional).
- **Anuncios:** No. **ID de publicidad:** No.
- **Público objetivo:** 13 años o más (la cuenta con correo es para mayores de 13).
- **Clasificación de contenido (IARC):** carreras, sin violencia ni apuestas; con el mundo online hay **chat entre usuarios** (con filtro de insultos, bloqueos automáticos y botón de reportar): en «interacción de usuarios» marcá que **los usuarios pueden interactuar / intercambiar contenido** y que se **comparte información de usuario** (el apodo se ve en rankings y en el mundo online). Si la versión de Play sale sin el mundo online, mantené «sin chat».

## Paso 5 · Cuando alguien pide borrar su cuenta por correo (a roldanhr98@gmail.com)
Prometimos hacerlo en **30 días como máximo**. Pasos (Supabase → tu proyecto):
1. *Authentication → Users* → buscá el correo → **⋮ → Delete user**. Eso borra también su fila de `players` y sus `scores` (cascada).
2. *SQL Editor* → corré (cambiando el ID por el del usuario que borraste; el ID se ve en la lista antes de borrarlo):
   ```sql
   delete from public.score_log where player_id = 'ID-DEL-USUARIO';
   ```
3. Si **no tenía correo** (usuario anónimo): *SQL Editor* → `select id, name from public.players where name ilike '%nombre%';` → con ese `id`, repetí `delete from public.score_log …`, `delete from public.scores …`, `delete from public.players …` y por último `delete from auth.users where id = '…';`.
4. Contestale al jugador que ya está hecho.

## Qué me tenés que pasar o decidir
1. **El resultado del Paso 0.3** (¿Opción A o B?).
2. Confirmar que **querés comprometerte a 30 días** para los pedidos por correo (si preferís otro plazo, lo cambio en la página y en este documento).
3. Si cambia el correo de contacto, decime y regenero las páginas (`python3 tools/play/make_legal_html.py`).
