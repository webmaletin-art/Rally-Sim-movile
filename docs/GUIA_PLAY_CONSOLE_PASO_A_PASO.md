# Guía de Google Play Console, paso a paso (de cero a «Dream Racing» publicado)

Para el dueño, 20/10/2026. Está pensada para ir **tocando y tildando**: cada paso dice **dónde entrar**, **qué poner** y **qué tiene que pasar**. Lo técnico (el juego, el AAB, las políticas, los textos y el servidor) ya está hecho en el repositorio; acá van sólo los trámites que se hacen en tu cuenta.

> Los nombres del menú de Play Console cambian de vez en cuando. Si no encontrás algo con el nombre que figura acá, usá el **buscador de la consola** (arriba, «Buscar en la consola») y escribí la palabra clave que va entre «comillas».
> Documentos que complementan esta guía: `docs/PLAY_STORE.md` (lo técnico y los precios), `docs/PLAY_SEGURIDAD_DATOS.md` (las respuestas exactas de «Seguridad de los datos»), `docs/GUIA_SQL_SUPABASE.md` (el servidor), `docs/QUE_FALTA.md` (la lista de pendientes), `store_listing/ficha.md` (los textos de la ficha en 6 idiomas).

## Resumen del camino (cuánto tarda)
| # | Qué | Quién | Tiempo |
|---|---|---|---|
| 1 | Cuenta de desarrollador de Google Play | vos | 1 día (verifican tu identidad) |
| 2 | Crear la app y completar «Contenido de la app» y la ficha | vos | 2–3 horas |
| 3 | Armar el AAB y la cuenta de servicio para las compras | yo + vos | 1 hora |
| 4 | Prueba **interna** (compras) | vos + tu teléfono | 1 día |
| 5 | Prueba **cerrada**: 12 testers durante **14 días seguidos** | vos + 12 personas | **14 días** (lo que más tarda) |
| 6 | Producción (revisión de Google) | Google | horas a unos días |

**Empezá por el paso 1 hoy mismo:** la prueba cerrada (paso 5) es lo que define cuándo se puede publicar.

---

## Paso 1 · La cuenta de desarrollador
1. Entrá a https://play.google.com/console con el Gmail con el que vas a publicar (conviene uno que sea tuyo para siempre, no uno de trabajo).
2. **Crear cuenta de desarrollador** → tipo **«Personal»** (o «Organización» si tenés una empresa con número D-U-N-S).
3. Pagá **USD 25** (una sola vez, con tarjeta).
4. **Verificá tu identidad**: documento y, a veces, un video corto; también un teléfono Android donde Google te manda un código desde la app «Play Console». Tarda de horas a 2 días.
5. Completá el **Perfil de pagos** (Configuración → «Perfil de pagos»): nombre legal, dirección y datos fiscales/bancarios. Sin esto **no se puede vender nada** (ni las monedas ni los desbloqueos).
6. Anotá en un lugar seguro (no en el repositorio): el correo de la cuenta y la contraseña.

⚠ **Importante para cuentas personales nuevas:** Google exige una **prueba cerrada con al menos 12 testers durante 14 días seguidos** antes de dejarte publicar en producción (paso 5).

## Paso 2 · Crear la app
1. Panel → **Crear app**.
2. **Nombre de la app:** `Dream Racing: Rally y Drift` (máximo 30 caracteres; es el título de la ficha en español).
3. **Idioma predeterminado:** Español (Latinoamérica) — `es-419`.
4. **App o juego:** **Juego**.
5. **Gratis o de pago:** **Gratis** (tiene compras dentro de la app; esto **no se puede cambiar después**).
6. Tildá las dos declaraciones (políticas del programa para desarrolladores y leyes de exportación de EE. UU.) → **Crear app**.
7. El **nombre de paquete** (`com.srg.dreamracing`) lo toma de la primera versión que subas; **es permanente**. Si querés otro, avisame **antes** del paso 6.
8. En el menú de la izquierda vas a ver el **Panel** con una lista de tareas («Configurar la app»): es tu tablero de avance; cada paso de abajo tilda una.

## Paso 3 · «Contenido de la app» (Política y programas → Contenido de la app)
Son formularios cortos. Hacelos todos; si falta uno, Google no deja enviar a revisión.

| Formulario | Qué poner |
|---|---|
| **Política de privacidad** | `https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html` (abrila antes en el teléfono y comprobá que se lee) |
| **Acceso a la app** | **«Toda o parte de la funcionalidad de mi app está restringida»** (hace falta iniciar sesión). Agregá un acceso: **usuario** (el correo de la cuenta de revisión) y **contraseña**; en «Instrucciones»: *Abrir el juego → Iniciar sesión → escribir el correo y la contraseña → ENTRAR*. Cómo crear esa cuenta y regalarle saldo: `docs/CUENTA_Y_ECONOMIA.md` («Operación», `account_admin_grant`). **Sin esto Google rechaza la revisión («no pudimos acceder a la app»).** |
| **Anuncios** | **No** contiene anuncios |
| **Clasificación del contenido** | Correo de contacto → categoría **«Juego»** → cuestionario (abajo) → **Guardar** → **Calcular clasificación** → **Aplicar** |
| **Público objetivo y contenido** | Rangos de edad: **13–15, 16–17, 18 o más** (no tildes menores de 13). «¿La app atrae a niños?»: **No** |
| **Apps de noticias / COVID-19 / apps financieras / salud / gobierno** | **No** en todas |
| **Seguridad de los datos** | Seguí `docs/PLAY_SEGURIDAD_DATOS.md` (las respuestas exactas por tipo de dato). La app **siempre** recopila: correo, ID de usuario, historial de compras (y apodo y marcas si juega los rankings; chat y posición del mapa del juego sólo en el mundo online). Datos cifrados en tránsito: **Sí**. Solicitar borrado: **Sí**, URL `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html` |
| **ID de publicidad** | **No** lo usa |
| **Aplicaciones de VPN / permisos sensibles / cámara-fotos** | No aplica (el juego sólo guarda capturas propias en su carpeta) |

**Cuestionario de clasificación (IARC), respuestas honestas:**
- Violencia: **No** (hay choques de autos y policías en persecución, pero no se muestra violencia contra personas ni sangre). Si el cuestionario pregunta por «violencia fantástica» o «contenido delictivo», contestá la verdad: *persecuciones policiales de carreras, sin daño a personas*.
- Contenido sexual, lenguaje, drogas, alcohol y tabaco: **No**.
- Apuestas simuladas / apuestas reales: **No** (las monedas no son azar: no hay cajas sorpresa).
- Compras dentro de la app: **Sí**. Ubicación compartida con otros usuarios: **No** (las coordenadas son del mapa del juego, no del teléfono).
- **Interacción entre usuarios:** el **chat del mundo online** existe (con filtro de insultos, bloqueos y reportes). Si en tu versión el online sigue «sólo por datos», contestá que los usuarios **no** se comunican; **si activás el tiempo real (chat), contestá que sí.** Tiene que coincidir con lo que hace el juego.
- Resultado esperado: «Para todos» / PEGI 3–7 (puede subir a 12 por las persecuciones). Está bien.

## Paso 4 · La ficha de la tienda (Presencia en Play Store → Ficha principal de Play Store)
Todo el texto está listo en `store_listing/ficha.md` (6 idiomas). Pegalo tal cual.

1. **Nombre de la app** (máx. 30): `Dream Racing: Rally y Drift`.
2. **Descripción corta** (máx. 80) y **descripción completa** (máx. 4000): copiá de `ficha.md`, sección «Español».
   - ⚠ **Antes de pegarlas, revisá la última frase:** el texto actual termina con «Próximamente: modo online». Hoy el modo online ya está abierto «por datos» (eventos, temporadas y ranking; el tiempo real todavía no). Cambiala por: *«Modo online con eventos semanales, temporadas y ranking.»* y que no prometa chat ni «jugar contra otros en tiempo real» si todavía no lo prendiste. La cantidad de autos de la ficha ya está corregida a **28** (los de la tienda; `docs/AUTOS.md`).
3. **Ícono:** `store_listing/icono_512.png` (512×512; es provisorio, cambialo si tenés logo).
4. **Gráfico de funciones:** `store_listing/grafico_funciones_1024x500.png`.
5. **Capturas de teléfono:** entre 2 y 8, **horizontales** (carpeta `store_listing/capturas/`, 1920×1080). Orden sugerido: carrera con el HUD, cámara interior con pilotos, drift en la plaza, el mapa de la Ruta de los Sueños, la tienda, el taller, lluvia/atardecer, un efecto de lente. (Opcional: tablets de 7 y 10 pulgadas.)
6. **Video** (opcional): subí el tráiler a YouTube («No es para niños»; público o no listado) y pegá el link.
7. **Categoría:** Juegos → **Carreras**. **Etiquetas:** carreras, rally, drift, mundo abierto, simulación.
8. **Datos de contacto:** el correo que figura en la política de privacidad (obligatorio); sitio web y teléfono (opcionales).
9. **Traducciones** (Presencia en Play Store → «Agregar traducciones» o «Administrar traducciones»): inglés, portugués (Brasil), francés, italiano y alemán; copiá de `ficha.md`.
10. **Guardar.** (Se puede dejar como borrador: se publica con la versión.)

## Paso 5 · Países y dispositivos
1. **Países:** se eligen en cada pista (Pruebas y lanzamiento → Producción → pestaña **«Países o regiones»**; lo mismo en las pruebas). Elegí todos, o empezá por Argentina, Brasil, México, España, Chile, Colombia y EE. UU. y sumá más después.
2. **Dispositivos:** dejá lo que detecta Google (Alcance y dispositivos → «Catálogo de dispositivos»): teléfonos y tablets Android de 64 bits. Si algún modelo queda fuera por RAM o por la API, no hace falta tocar nada.
3. **Precio de la app:** Gratis (con compras dentro de la app). No hay que cargar ningún precio acá: los de los productos se cargan en el paso 7.

## Paso 6 · La firma de la app y el AAB
1. **Play App Signing** (Configuración → «Integridad de la app» o «Firma de la app»): aceptá que Google guarde la clave de la app. Vos subís con la clave de **subida** (la que ya usa el flujo de GitHub).
2. **Armar el AAB** (esto lo hago yo o lo hacés vos con dos clics): GitHub → **Actions → «Build Play Store AAB» → Run workflow** → rama `main`, versión `1.0.0` → esperá unos 40 minutos. Cuando termina: **Releases → `play-aab`** → bajá el `.aab` que **no** diga `PRUEBA` ni `SIN-COMPRAS` (pesa ~675 MB).
   - El número de versión (*versionCode*) sube solo en cada corrida; Play exige que siempre sea mayor que el anterior.
   - El flujo verifica las **páginas de 16 KB** (exigencia de Google) y falla si no cumple.
3. **Claves que tienen que estar cargadas en GitHub** (Settings → Secrets and variables → Actions): `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`. Si falta alguna, el flujo del AAB se detiene y lo dice. (Tabla completa en `docs/GUIA_SUBIR_A_PLAY.md`.)

## Paso 7 · Prueba INTERNA (acá se prueban las compras)
1. Menú **Pruebas y lanzamiento → Pruebas → Pruebas internas → Crear nueva versión**.
2. **Subí el `.aab`** (arrastrarlo). Tarda unos minutos en procesar el archivo de ~675 MB; Google lo divide en el módulo base (~50 MB) y el paquete con los autos (install-time).
3. Poné el **nombre de la versión** (`1.0.0`) y las **notas** (por ejemplo «Primera versión de prueba») → **Siguiente** → revisá las advertencias (Google puede avisar de permisos o de la API; si hay un **error** rojo, copialo y pasámelo) → **Guardar y publicar** («Iniciar lanzamiento en pruebas internas»).
4. Pestaña **Testers → Crear lista de correos**: poné tu Gmail (y el de quien te ayude) → Guardar → tildá la lista.
5. Copiá el **enlace de participación** («Copiar enlace»), abrilo **desde el teléfono con ese Gmail**, aceptá ser tester e **instalá desde Play**. (Si ya tenías instalado el APK de GitHub, desinstalalo antes: la firma es distinta.)
6. **Pruebas de licencia** (Configuración → «Pruebas de licencia»): agregá tu Gmail → «Respuesta de licencia»: *RESPOND_NORMALLY*. Con esto **las compras de prueba no te cobran**.
7. **Productos integrados** (Monetizar con Play → **Productos → Productos integrados**; **para crear productos hace falta haber subido ya un AAB** con la facturación, o sea el del paso 2): creá **estos 10 con los IDs exactos** (no se pueden cambiar después) y **activá** cada uno:

   | ID (exacto) | Tipo | Nombre sugerido | Precio recomendado* |
   |---|---|---|---|
   | `dr_full` | Producto **no consumible** («Producto único») | Juego completo | USD 9,99 |
   | `dr_adventure` | no consumible | Aventura completa | USD 4,99 |
   | `dr_garage` | no consumible | Garaje premium (3 autos) | USD 6,99 |
   | `car_truck` | no consumible | Colossus Mamut 6x6 | USD 1,99 |
   | `car_gt3` | no consumible | Altair GT3 RS | USD 2,99 |
   | `car_hyper` | no consumible | Vortex Aerion | USD 3,99 |
   | `dr_coins_s` | **consumible** | Puñado de monedas ($ 5.000) | USD 0,99 |
   | `dr_coins_m` | consumible | Bolsa de monedas ($ 12.000) | USD 1,99 |
   | `dr_coins_l` | consumible | Cofre de monedas ($ 30.000) | USD 3,99 |
   | `dr_coins_xl` | consumible | Baúl de monedas ($ 80.000) | USD 7,99 |

   *Los precios los ponés vos; los de la tabla son una recomendación (`docs/PLAY_STORE.md`, sección 0). Dejá que Google convierta a cada país y revisá a mano Argentina, Brasil y México (precios locales más bajos venden más). La **descripción** de cada producto: una línea clara de qué da.
8. **Probá en el teléfono** (instalado desde Play): crear cuenta o iniciar sesión → COMPRAS → comprá **una** monedas (consumible) y **un** desbloqueo; verificá que los créditos suben y que el desbloqueo queda; cerrá y abrí el juego; **desinstalá, reinstalá, iniciá sesión y tocá «Restaurar compras»**. Mirá también que **Acerca de** no tiene modo desarrollador ni «COPIAR REGISTRO».
9. **La cuenta de servicio para verificar las compras** (se hace una vez; sin esto **las compras no se acreditan**):
   1. https://console.cloud.google.com → creá un proyecto (o usá uno) → **API y servicios → Biblioteca** → buscá **«Google Play Android Developer API»** → **Habilitar**.
   2. **IAM y administración → Cuentas de servicio → Crear cuenta de servicio** (nombre `dreamracing-billing`) → listo. Entrá a la cuenta → pestaña **Claves → Agregar clave → Crear clave nueva → JSON**: se baja un archivo. **No lo compartas con nadie ni lo pegues en un chat.**
   3. Play Console → **Usuarios y permisos → Invitar usuarios nuevos** → pegá el **correo de la cuenta de servicio** (termina en `iam.gserviceaccount.com`) → en **Permisos de la app** elegí Dream Racing con **«Ver información financiera, pedidos y respuestas de encuestas de cancelación»** y **«Gestionar pedidos y suscripciones»** → Invitar.
   4. GitHub → Settings → Secrets and variables → Actions → **New repository secret** → nombre `GOOGLE_PLAY_SERVICE_ACCOUNT` → pegá **todo el contenido** del JSON.
   5. GitHub → Actions → **«Supabase · publicar funciones»** → Run workflow. (La verificación de Google puede tardar hasta ~24 h en activarse la primera vez.)

## Paso 8 · Prueba CERRADA (los 14 días)
1. **Pruebas y lanzamiento → Pruebas → Pruebas cerradas → Crear pista** (o usá «Prueba cerrada» que ya existe) → **Crear versión** → subí el **mismo AAB** (o **«Promover versión»** desde la interna) → notas → guardar y publicar.
2. **Testers:** creá una lista con **15 a 20 Gmail** (hacen falta 12, pero siempre alguno se baja). Pueden ser amigos y familia. Mandales el **enlace de participación** de la prueba cerrada.
3. Cada tester tiene que: abrir el enlace con su Gmail → «Ser tester» → instalar desde Play → **abrir la app de vez en cuando** y **no desinstalarla** durante **14 días seguidos** (la consola muestra cuántos están inscriptos).
4. Mientras pasan los 14 días podés mandar versiones nuevas a la misma prueba (el juego sigue mejorando); el contador no se reinicia por eso.
5. Al cumplirse, en el **Panel** aparece **«Solicitar acceso a producción»**: te hace un formulario corto sobre cómo fue la prueba (cuántos testers, qué feedback recibiste, qué cambiaste). Contestalo con la verdad. Google responde en unos días.

## Paso 9 · Producción
1. **Pruebas y lanzamiento → Producción → Crear nueva versión** → subí el AAB (o promovelo desde la prueba cerrada).
2. **Notas de la versión** en cada idioma, entre etiquetas, por ejemplo:
   ```
   <es-419>
   Primera versión pública: 26 autos, Dream City y su región, Aventura, copas, Travesía X y modo de prueba guiado.
   </es-419>
   <en-US>
   First public release: 26 cars, Dream City and its region, Adventure, cups, Travesía X and a guided test mode.
   </en-US>
   ```
3. **Siguiente → Guardar → «Ir a la descripción general de la publicación» → Enviar a revisión.** Google revisa de horas a unos días. Cuando aprueban, el juego aparece en la tienda (podés elegir publicar «a mano» para controlar el momento).
4. Mirá en el Panel que **todas** las tareas estén tildadas; la que falte te dice qué hacer.

## Paso 10 · Después de publicar
- **Cada actualización:** volvé a correr «Build Play Store AAB» (el número de versión sube solo) y subí el nuevo `.aab` a Producción (o a la prueba que corresponda). Completá las notas.
- **Servidor:** prender la cacería para principiantes (`wev_templates` → `caza_inicial` → `enabled = true`) y, cuando quieras el mundo compartido en tiempo real, `app_flags` → `pvp = true` (`docs/GUIA_SQL_SUPABASE.md`, sección 5).
- **Salud de la app:** Calidad → «Android vitals» (cierres y ANR). Si ves cierres, abrí el detalle y pasame el texto.
- **Reseñas:** Calidad → «Calificaciones y reseñas»: contestá las primeras.
- **Cambios en datos o compras:** actualizá `docs/PRIVACIDAD.md`, corré `python3 tools/play/make_legal_html.py` y revisá «Seguridad de los datos».

## Problemas comunes y qué hacer
| Mensaje de Google | Causa probable | Qué hacer |
|---|---|---|
| «No pudimos acceder a la app» / «Acceso restringido» | La cuenta de revisión no entra, no tiene saldo o Supabase pide confirmar el correo | Probá esa cuenta en el juego; «Confirm email» apagado en Supabase (`docs/GUIA_SQL_SUPABASE.md`, sección 5) |
| «La política de privacidad no está disponible» | La web de GitHub Pages no se publicó | Actions → «Deploy static content to Pages» en verde; abrí la URL (si quedó una corrida vieja en «Waiting», cancelala) |
| «Los datos de seguridad no coinciden con la app» | Declaración incompleta | Releé `docs/PLAY_SEGURIDAD_DATOS.md` y marcá todos los datos que figuran |
| «El módulo base supera los 200 MB» | AAB armado sin el paquete install-time | No subas el `.aab` que diga PRUEBA o SIN-COMPRAS; usá el de la corrida «Build Play Store AAB» de `main` |
| «Tu app no es compatible con páginas de 16 KB» | Motor viejo | El flujo ya lo verifica (Godot 4.7.2); si aparece, pasame la corrida |
| La compra queda «pendiente» y no llegan las monedas | Falta la cuenta de servicio o la función `verify-purchase` | Paso 7.9; Google devuelve la plata a los 3 días si no se acredita |
| «Falta una declaración de permisos» | Algún permiso sensible | Contame cuál y lo vemos (el juego sólo usa internet, vibración y facturación) |

## Lo que tenés que decidir o pasarme
1. ¿Los precios de la tabla del paso 7 te sirven? (los pone Play Console; yo no los toco).
2. ¿Querés mencionar los eventos y el ranking online en la ficha (paso 4) o dejarlos afuera?
3. La **licencia comercial de la música** (MusicGPT): confirmá que tu plan permite uso comercial; si no, apagamos la música antes de publicar.
4. El **correo de la cuenta de revisión** (paso 3) y que la cuenta tenga saldo.
5. ¿Hay logo propio para el ícono (el actual «DR» es provisorio)?
