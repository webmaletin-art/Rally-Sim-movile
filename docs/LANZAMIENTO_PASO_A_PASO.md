# Lanzamiento de Dream Racing — instructivo en orden cronológico (preparado el 21/10/2026 para subir el 22/10)

Todo lo que se podía dejar hecho desde GitHub **está hecho**. Esto es lo que hacés vos, en el orden en que conviene hacerlo, con los links y los datos exactos.
Los detalles de cada formulario de Play Console están en `docs/GUIA_PLAY_CONSOLE_PASO_A_PASO.md` (cada paso de acá dice cuál leer). Las respuestas de «Seguridad de los datos» están en `docs/PLAY_SEGURIDAD_DATOS.md`.

## 0. Lo que tenés que saber antes de empezar

| Dato | Valor |
|---|---|
| **Rama que se publica** | **`main`** (https://github.com/webmaletin-art/Rally-Sim-movile/tree/main). La rama `ccr-e7ae3f10-45afj2` es la de pruebas («Dream Racing RC»): no se sube a Play. |
| **De dónde sale el AAB** | Lo arma el flujo **«Build Play Store AAB»** sobre `main` (ya corrido el 21/10: versión **1.0.0**, código de versión **1004**). Se baja de **GitHub → Releases → `play-aab`**: https://github.com/webmaletin-art/Rally-Sim-movile/releases/tag/play-aab → archivo **`DreamRacing-play-v1004.aab`** (763 MB; armado en verde el 21/10, con el plugin de compras y la revisión de 16 KB aprobada). **No uses** el `v1003` (es del 13/10, motor viejo) ni ninguno que diga `PRUEBA` o `SIN-COMPRAS`. |
| Paquete (ID de la app) | `com.srg.dreamracing` (no se puede cambiar después) |
| Nombre en la tienda | Dream Racing: Rally y Drift |
| Precio de la app | **Gratis**, con 10 compras dentro de la app (ver paso 5) |
| Países | Todos los que ofrece Play (decidido así: más alcance, sin costo extra) |
| Correo de contacto | roldanhr98@gmail.com |
| Servidor | Supabase: las 22 migraciones están aplicadas (verificado hoy: *Local = Remote*, nada pendiente) |

**⚠ La condición que decide cuándo sale al público:** si tu cuenta de desarrollador de Google es **personal y se creó después del 13/11/2023**, Google exige antes de publicar en Producción una **prueba cerrada con al menos 12 testers inscriptos durante 14 días seguidos**. Con ese tipo de cuenta, mañana **subís y empezás las pruebas**, y la publicación al público es **unos 15–20 días después** (14 de prueba + la revisión de Google: de horas a unos días). Si tu cuenta es de **organización** (con número D-U-N-S) o es anterior a esa fecha, no hace falta la prueba cerrada y podés pasar a Producción apenas funcionen las compras en la prueba interna.
Te lo puede decir la propia consola: en el Panel aparece (o no) la tarea «Realizar una prueba cerrada». La semana de pruebas que querés encaja dentro de esos 14 días.

## 1. Hoy a la noche / mañana a primera hora (20 minutos, desde la compu)

1. **Bajá el AAB**: https://github.com/webmaletin-art/Rally-Sim-movile/releases/tag/play-aab → `DreamRacing-play-v1004.aab`. Guardalo en una carpeta fácil.
2. **Bajá la ficha** (los textos y las imágenes están en `store_listing/` de `main`):
   - Textos en 6 idiomas: https://github.com/webmaletin-art/Rally-Sim-movile/blob/main/store_listing/ficha.md (abrilo en el navegador y copiá/pegá desde ahí).
   - Ícono 512×512: https://raw.githubusercontent.com/webmaletin-art/Rally-Sim-movile/main/store_listing/icono_512.png (clic derecho → guardar imagen como…). *Es el «DR» provisorio: sirve para lanzar; si tenés logo propio, cambiás sólo esta imagen cuando quieras, sin tocar el juego.*
   - Gráfico de funciones 1024×500: https://raw.githubusercontent.com/webmaletin-art/Rally-Sim-movile/main/store_listing/grafico_funciones_1024x500.png
   - **8 capturas** (1920×1080): `store_listing/capturas/` → https://github.com/webmaletin-art/Rally-Sim-movile/tree/main/store_listing/capturas (abrí cada una y guardala). Cuando tengas el juego instalado desde Play, podés sacar capturas propias con el botón 📷 y reemplazarlas.
3. **Supabase (panel de tu proyecto, 3 interruptores)** — sin esto el login o los correos pueden fallar y Google rechaza la app por «no puedo entrar»:
   - Authentication → **Sign In / Providers**: **«Allow anonymous sign-ins» = apagado**.
   - Authentication → Sign In / Providers → **Email**: **«Confirm email» = apagado**.
   - Realtime → **Settings**: **«Allow public access» = apagado**.
   - Recomendado (decisión de dinero, tuya): **pasar el proyecto a Pro** (Settings → Billing) **antes de enviar a revisión**: en el plan gratis Supabase **pausa el proyecto tras una semana sin uso** y, si pasa justo cuando Google lo revisa, nadie puede entrar. Ver `docs/COSTOS_ONLINE.md`.
4. **Creá la cuenta de revisión** (la que le vas a dar a Google): instalá el APK normal de `main` (https://github.com/webmaletin-art/Rally-Sim-movile/releases/download/godot-apk/DreamRacing-liviano.apk), creá una cuenta con un correo **exclusivo** (por ejemplo `revision.dreamracing@gmail.com`) y una contraseña que no uses en otro lado, entrá al juego y cerrá. Después, en Supabase → **SQL Editor**, regalale saldo y un par de autos para que el revisor pueda probar todo:
   ```sql
   select public.account_admin_grant('revision.dreamracing@gmail.com', 100000, array['gt','hatch2']);
   ```
   (Si da error de que el correo no existe, entrá al juego con esa cuenta una vez más y repetí.) Anotá correo y contraseña: se piden en el paso 4.

## 2. Play Console, parte 1: cuenta, app y declaraciones (≈1 hora) → `GUIA_PLAY_CONSOLE_PASO_A_PASO.md` pasos 1–5

1. https://play.console.google.com → **si todavía no tenés cuenta de desarrollador**: crearla (pago único de USD 25, verificación de identidad: puede tardar 1–3 días, por eso conviene empezar hoy) y el **perfil de pagos** (necesario para vender las compras). *Elegí «Organización» si tenés D-U-N-S; si no, «Personal».*
2. **Crear app**: nombre «Dream Racing: Rally y Drift» · idioma predeterminado **Español (Latinoamérica)** · **Juego** · **Gratis** · aceptá las declaraciones.
3. **Contenido de la app** (Política → Contenido de la app). Todo está contestado en la guía, paso 3:
   - Política de privacidad: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html`
   - **Acceso a la app**: restringido → usuario y contraseña de la cuenta de revisión del paso 1.4; instrucciones: «Abrir el juego → Iniciar sesión → ENTRAR».
   - Anuncios: **No**. Clasificación (IARC): categoría Juego, respuestas de la guía (esperado: Para todos / PEGI 3–7, puede subir a 12). Público objetivo: 13 años o más (**no** marques menores de 13; «¿atrae a niños?»: No).
   - **Seguridad de los datos**: seguí `docs/PLAY_SEGURIDAD_DATOS.md`. URL para borrar la cuenta: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html` (en el juego también: pantalla de la cuenta → «Borrar mi cuenta y mis marcas»).
   - Noticias / COVID / finanzas / salud / gobierno: **No**.
4. **Ficha principal**: pegá título, descripción corta y completa de `ficha.md` (español), subí ícono, gráfico de funciones y las capturas (mínimo 2, sirven las 8). Después **Agregar traducciones** (en, pt, fr, it, de): pegá cada bloque de `ficha.md`. Categoría **Juegos → Carreras**.
5. **Países y precios**: todos los países; app gratuita.

## 3. Play Console, parte 2: subir el AAB y probar las compras (≈1–2 horas, el día 1) → guía pasos 6–7

1. **Prueba interna** → Crear versión → **subí `DreamRacing-play-v1004.aab`** (tarda varios minutos en procesar). Aceptá Play App Signing. Nombre de versión `1.0.0`, notas «Primera versión de prueba».
   - Si Google muestra un **error rojo**, copiámelo tal cual. Las advertencias amarillas (por ejemplo, de símbolos de depuración) no impiden nada.
2. **Testers**: creá una lista con tu Gmail (y los de quien te ayude) → copiá el **enlace de participación** → abrilo en el teléfono con ese Gmail → instalá **desde Play** (desinstalá antes el APK de GitHub: la firma es distinta).
3. **Pruebas de licencia** (Configuración → Pruebas de licencia): agregá tu Gmail, respuesta `RESPOND_NORMALLY` (las compras de prueba no cobran).
4. **Productos integrados** (Monetizar → Productos → Productos integrados; *recién se pueden crear después de subir el AAB*): creá estos **10 con el ID exacto** (no se puede cambiar después) y **activá** cada uno. Los precios son recomendados (`docs/PLAY_STORE.md`, sección 0):

   | ID | Tipo | Precio USD |
   |---|---|---|
   | `dr_full` | no consumible («producto único») | 9,99 |
   | `dr_adventure` | no consumible | 4,99 |
   | `dr_garage` | no consumible | 6,99 |
   | `car_truck` | no consumible | 1,99 |
   | `car_gt3` | no consumible | 2,99 |
   | `car_hyper` | no consumible | 3,99 |
   | `dr_coins_s` | **consumible** | 0,99 |
   | `dr_coins_m` | consumible | 1,99 |
   | `dr_coins_l` | consumible | 3,99 |
   | `dr_coins_xl` | consumible | 7,99 |

5. **La cuenta de servicio que verifica las compras** (sin esto **las compras no se acreditan**; ≈20 min) → guía, paso 7.9: Google Cloud (habilitar *Google Play Android Developer API* → crear cuenta de servicio `dreamracing-billing` → clave JSON) → Play Console → Usuarios y permisos → invitar ese correo con permisos «Ver información financiera…» y «Gestionar pedidos…» → GitHub → Settings → Secrets → **`GOOGLE_PLAY_SERVICE_ACCOUNT`** = el contenido del JSON → GitHub → Actions → **«Supabase · publicar funciones»** → Run workflow (rama `main`).
   - Google puede tardar **hasta ~24 h** en activar el permiso la primera vez: si la primera compra queda «pendiente», esperá y reintentá; **Google devuelve la plata sola a los 3 días** si una compra no se reconoce.
6. **Probá en el teléfono** (instalado desde Play): iniciar sesión → COMPRAS → comprá **una bolsa de monedas** y **un desbloqueo**; los créditos tienen que subir y el desbloqueo quedar; cerrá y abrí; **desinstalá, reinstalá, iniciá sesión y tocá «Restaurar compras»**. Mirá además que **Acerca de** sea sólo un texto (sin modo desarrollador ni «COPIAR REGISTRO»), que el **Modo de prueba** aparezca en el inicio y que no haya nada de herramientas técnicas.

## 4. Play Console, parte 3: pasar a producción → guía pasos 8–9

- **Cuenta personal nueva (la condición del paso 0):** el mismo día 1, **Prueba cerrada → Crear versión → «Promover»** el mismo AAB, lista de **15 a 20 testers** (hacen falta 12; siempre alguno se baja) y mandales el enlace. Tienen que instalar desde Play, **abrir la app de vez en cuando y no desinstalarla durante 14 días seguidos**. Mientras pasan los días podés subir versiones nuevas a esa misma prueba sin reiniciar el contador. Al día 14: **«Solicitar acceso a producción»** (formulario corto: contestá con la verdad cuántos testers tuviste y qué arreglaste). Google responde en unos días.
- **Cuenta de organización / anterior a noviembre de 2023:** cuando las compras anden en la interna → **Producción → Crear versión → promover el AAB → notas de versión → Enviar a revisión** (horas a unos días).
- **Notas de la versión 1.0.0** (ya están en `ficha.md`): «Primera versión en Google Play: 28 autos, Dream City y su región, aventura de 12 etapas, Travesía X, copas, red de rutas, drift, modo de prueba guiado, tienda con prueba de autos y taller con guías fáciles.»
- Antes de «Enviar a revisión»: en el **Panel** de Play Console todas las tareas tienen que estar tildadas (la que falte te dice qué hacer).

## 5. La semana de pruebas y después (lo que acordamos)

1. **Primera semana (con los testers):** que jueguen en todos los modos (Aventura, Dream City, drift, Travesía X, Modo de prueba, compras) y que reporten cierres. Mirá **Calidad → Android vitals** (cierres y ANR) y el **informe previo al lanzamiento** que Google corre solo con cada AAB.
2. **Cuando haya algo para arreglar:** me pasás el texto del cierre o la captura; arreglo en `main`, corro de nuevo «Build Play Store AAB» (el número de versión sube solo) y subís el `.aab` nuevo a la misma prueba.
3. **Ya publicado:** prender la cacería de principiantes (Supabase → Table Editor → `wev_templates` → `caza_inicial` → `enabled = true`); mirar reseñas; y recién ahí **optimizar** lo que haga falta (rendimiento, tamaño de descarga, ajustes de equilibrio) con datos reales.
4. **Más adelante:** el mundo compartido en tiempo real (`app_flags` → `pvp = true`) se prende sin subir nada nuevo, pero conviene hacerlo con el plan Pro de Supabase (`docs/COSTOS_ONLINE.md`).

## 6. Si algo falla

| Síntoma | Qué hacer |
|---|---|
| Google rechaza el AAB | Copiame el mensaje exacto (casi siempre es un dato de la ficha o una declaración que falta). |
| «No pudimos acceder a la app» en la revisión | Probá la cuenta de revisión en el juego; revisá «Confirm email» apagado y que Supabase no esté pausado. |
| Las compras no suman monedas | Falta la cuenta de servicio o el flujo «Supabase · publicar funciones» (paso 3.5); esperá hasta 24 h; probá con un tester de licencia. |
| Quiero un AAB nuevo | GitHub → Actions → **Build Play Store AAB** → Run workflow → rama `main`, versión `1.0.1` (por ejemplo) → ~40 min → Releases → `play-aab`. |
| Necesito volver atrás una actualización | Play Console → Producción → «Detener lanzamiento» o publicar el AAB anterior como una versión nueva (el código de versión sólo sube). |

## 7. Qué revisé yo para que Play lo acepte (21/10/2026)

- **Nivel de API:** el AAB apunta a la **API 36 (Android 16)**, el mínimo que Google exige hoy para apps nuevas y actualizaciones (plazo del 31/08/2026); mínimo Android 7 (API 24).
- **Biblioteca de Google Play Billing:** el flujo instala el plugin **3.3.0 (Billing Library 9.1)**; Google exige la versión 8 o más nueva. Quedó **fijo en esa versión** para que el AAB no cambie solo.
- **Páginas de 16 KB:** el flujo falla si alguna biblioteca nativa no está alineada (Godot 4.7.2: lo cumple).
- **Tamaño:** el AAB pesa 763 MB (el módulo base ~50 MB y los autos en un paquete de recursos *install-time* de ~620 MB comprimidos; dentro de los topes de Google: 2 GB por AAB, 4 GB en total). La subida tarda unos minutos.
- **Compras:** los 10 productos del cliente (`godot/game/store/products.gd`) coinciden uno a uno con la lista que acepta el servidor (`supabase/functions/verify-purchase`); el cliente reconoce las compras únicas y consume las monedas **sólo después de que el servidor las acredita** (sin doble cobro ni pérdida); hay «Restaurar compras».
- **Cuenta y datos:** política de privacidad, términos y borrado de cuenta publicados (GitHub Pages en verde) y borrado también dentro del juego.
- **Versión pública limpia:** sin modo desarrollador, sin «COPIAR REGISTRO», sin diagnóstico; probado con `public_build_test` (las 106 pruebas del flujo en verde).
- **Lo que NO se puede comprobar desde acá y se verifica en tu prueba interna:** que el plugin de compras 3.3.0 funcione con el motor 4.7.2 en tu teléfono, que Google acepte el AAB y las compras reales (paso 3.6). Si la compra fallara por el plugin, avisame: lo cambio de versión en minutos.
