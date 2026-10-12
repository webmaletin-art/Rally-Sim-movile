# Dream Racing en Google Play — guía de publicación

Todo lo que ya está armado en el repositorio y lo que tiene que hacer el dueño (GitHub y Play Console).

## 0. Revisión del 12/10/2026: ¿está todo para vender?
**Todavía no se puede subir a producción.** Hay dos bloqueos técnicos que el juego tiene HOY y un trámite de Google que lleva 14 días. Lo demás está.

| | Tema | Estado | Qué hay que hacer |
|---|---|---|---|
| ❌ | **Páginas de 16 KB** (exigencia de Google desde el 1/11/2025 para apps con API objetivo 35+; nosotros apuntamos a la 36) | **Bloqueo.** Verificado en el AAB `v1002`: `libgodot_android.so` y `libc++_shared.so` (arm64) tienen los segmentos alineados a 4 KB (`p_align = 0x1000`), no a 16 KB. Godot **4.4.1** no lo soporta; viene desde Godot **4.5** (PR #106358). Play Console rechaza o marca como no apta una versión así. | Subir el motor a Godot 4.5 o más nuevo (hay 4.6.x y 4.7.x) y probar todo el juego otra vez (las ~50 pruebas de la CI + mirar el juego en el teléfono). Alternativa más chica: compilar las plantillas de exportación de 4.4 con la corrección. Ver 7.1. |
| ❌ | **Tamaño del AAB**: los 26 autos pesan 566 MB (`cars.pck`) + 54 MB (`content.pck`); el módulo base de un AAB no puede pasar los 200 MB | **Bloqueo.** El preset «Google Play (AAB)» mete todo adentro: con los autos nuevos ya no entra (el AAB `v1002` pesa 67 MB porque es de antes). | Armar el AAB con **Play Asset Delivery** (paquete de recursos «install-time» con `cars.pck`) o bajar los autos con un paquete a pedido. Ver 7.2. |
| ⏳ | **Prueba cerrada**: las cuentas personales nuevas necesitan 12 testers durante 14 días seguidos antes de publicar en producción | Trámite tuyo. Es el camino más largo: **empezalo ya** apenas haya un AAB que Play acepte. | Juntar 12 personas con Gmail, mandarles el link de la prueba cerrada, que no se desinstalen. Ver 3.1. |
| ⚠️ | **Compras dentro del juego** (plugin de Google Play Billing) | Armadas pero **nunca probadas en Play** (no se pueden probar con el APK de GitHub). | Prueba interna con tu correo como tester de licencia; revisar compra, restaurar y las monedas. |
| ⚠️ | **Música** (9 temas de MusicGPT, créditos ya puestos en el juego) | La licencia depende del plan de MusicGPT con el que se generaron. | Confirmar que tu plan permite **uso comercial** y guardar el comprobante (los términos cambian). Si no lo permite, apagar la música o reemplazarla antes de publicar. |
| ⚠️ | **Ficha** (textos, capturas, tráiler) | Textos nuevos listos en 6 idiomas (`store_listing/ficha.md`). Capturas y video: salen del tráiler (ver 4). | Pegar los textos en Play Console, subir 4–8 capturas y el link del video de YouTube. |
| ✅ | Política de privacidad y términos (con el online como «próximamente»), eliminación de la cuenta, créditos, clasificación y seguridad de los datos | Hechos y actualizados | Seguir `docs/PLAY_SEGURIDAD_DATOS.md`. Si algún día se abre el online: volver a revisar. |
| ✅ | Sin anuncios, 13+, sin cuenta obligatoria (se puede revisar el juego sin registrarse), sin chat ni mercado mientras el online esté cerrado | Hecho | — |
| ✅ | Íconos, gráfico de funciones 1024×500, correo de contacto, URL de privacidad | Hechos (ícono provisorio «DR») | Cambiar el ícono si tenés logo propio. |

### Precios: sí, conviene actualizarlos
Los precios de abajo (`USD 0,99` por auto premium, `USD 1,99` el juego completo) se pensaron cuando el juego tenía 3 etapas y pocos autos. Hoy el paquete completo incluye 12 etapas, 4 copas, Travesía X, Dream City y 3 autos que en la tienda valdrían **450.000 $** del juego (el Aerion solo vale 260.000: es el auto más caro). Y hay una incoherencia: con monedas, un auto de 30.000 $ cuesta USD 3,99, pero el hypercar de 260.000 $ cuesta USD 0,99.
Los precios los fija Play Console (el juego muestra lo que devuelve Google), así que no hace falta tocar el juego. Recomendación:

| ID | Antes | Recomendado | Comentario |
|---|---|---|---|
| `dr_full` (juego completo) | 1,99 | **9,99** | un solo pago, sin anuncios; es el que más conviene empujar en la publicidad |
| `dr_adventure` | 0,99 | **4,99** | aventura (12 etapas) + copas Continental y Leyenda |
| `dr_garage` (3 autos premium) | 1,99 | **6,99** | lo que cuestan los tres sueltos con ~20 % de descuento |
| `car_truck` Mamut 6x6 | 0,99 | **1,99** | |
| `car_gt3` GT3 RS | 0,99 | **2,99** | |
| `car_hyper` Aerion | 0,99 | **3,99** | el auto más caro del juego |
| `dr_coins_s/m/l/xl` | 0,99 / 1,99 / 3,99 / 7,99 | **igual** | 5.000 / 12.000 / 30.000 / 80.000 $: rinden 5.000 → 10.000 $ por dólar, bien escalonado |

Con eso: tres autos sueltos (8,97) > garaje (6,99); aventura + garaje (11,98) > juego completo (9,99). En Play Console conviene dejar que Google convierta a cada país y revisar a mano Argentina, Brasil y México (precios locales más bajos venden más). Los precios de los autos DENTRO del juego (9.000 a 260.000 $) no hace falta cambiarlos: el inicial es el R2 Turbo de 9.000 y una medalla de oro en la copa Debut paga 2.000 $ (la tabla está en `docs/AUTOS.md`).

## 1. Qué ya está listo en el código
| Cosa | Dónde |
|---|---|
| Preset de exportación **«Google Play (AAB)»**: juego completo adentro (sin descargas), Gradle + AAB, API objetivo **36**, arm64 + armeabi-v7a, íconos propios, característica `store` | `godot/export_presets.cfg` (preset.3) |
| Flujo de compilación **«Build Play Store AAB»** (manual): instala la plantilla de Gradle, el plugin de compras, firma, versión automática y publica el `.aab` en la release `play-aab` | `.github/workflows/build-aab.yml` |
| Compras dentro del juego (Google Play Billing): productos, pantalla COMPRAS, restaurar, créditos, juego completo | `godot/game/store/products.gd`, `store/billing.gd`, `ui/menu_store.gd` |
| Versión «store»: sin modo desarrollador, sin prueba de rendimiento, sin descargas, textos legales con compras | `Release.store()` (`data/release.gd`) |
| Íconos y gráfico de la ficha (generados) | `store_listing/` y `godot/store/icons/` (`python3 tools/play/make_graphics.py`) |
| Política de privacidad y términos en web (para la URL de Play Console) | `docs/privacidad.html`, `docs/terminos.html` (`python3 tools/play/make_legal_html.py`) |
| Textos de la ficha (título, descripciones, notas) | `store_listing/ficha.md` |

La versión de prueba (APK liviano / completo de GitHub) **no cambia**: todo lo de «store» solo se activa en el AAB.

## 2. Qué tenés que hacer en GitHub
1. **Settings → Pages → Build and deployment → Source: «GitHub Actions»**. Hoy el flujo «Deploy static content to Pages» falla porque Pages no está activado. Con eso quedan públicas las URL:
   - Privacidad: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html`
   - Términos: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/terminos.html`
2. **Completar el correo de contacto** en `docs/PRIVACIDAD.md` (dice «completar antes de publicar») y volver a generar la web (`python3 tools/play/make_legal_html.py`). Si me pasás el correo, lo hago yo.
3. **Firma** (Settings → Secrets and variables → Actions → *New repository secret*), tres secretos:
   - `ANDROID_KEYSTORE_BASE64`: el archivo `.keystore` de la clave de **subida** en base64.
   - `ANDROID_KEYSTORE_PASSWORD`: la contraseña (la del keystore y la de la clave tienen que ser **la misma**).
   - `ANDROID_KEY_ALIAS`: el alias de la clave.
   Si no tenés cómo generar el keystore, decime y lo genero acá y te paso los tres valores para pegar (y guardalos además en un lugar seguro: sin la clave de subida no podés actualizar la app; Google permite reiniciarla desde Play Console, pero es un trámite).
4. **Actions → «Build Play Store AAB» → Run workflow** (poné el nombre de versión, por ejemplo `1.0.0`). Cuando termina, el archivo queda en **Releases → «AAB para Google Play»**. Usá solo el que **no** diga `PRUEBA` ni `SIN-COMPRAS`.

## 3. Qué tenés que hacer en Play Console (https://play.google.com/console)
1. **Cuenta de desarrollador** (pago único de USD 25 y verificación de identidad). *Ojo:* las cuentas personales nuevas necesitan una **prueba cerrada con al menos 12 testers durante 14 días seguidos** antes de poder publicar en producción (verificalo en la pantalla de «Acceso a producción»). Es lo que más tarda: **conviene empezar la prueba cerrada apenas haya un AAB que Play acepte** (ver 0), con el juego tal cual y, mientras corren los 14 días, ir sumando mejoras en versiones nuevas de la misma prueba. Tip: los testers tienen que entrar con un Gmail, aceptar la invitación (link de la prueba cerrada) y no desinstalar; conviene juntar 15–20 por si alguno se baja.
2. **Crear la app**: nombre «Dream Racing», idioma predeterminado español, tipo **Juego**, **gratis** (con compras integradas).
3. **Nombre de paquete**: el AAB usa `com.srg.dreamracing`. **Es permanente** una vez publicada. Si querés otro, decímelo *antes* de la primera subida.
4. **Play App Signing**: aceptá que Google guarde la clave de firma (la tuya es solo la de *subida*).
5. **Contenido de la app** (todos son formularios cortos):
   - Política de privacidad: la URL de arriba.
   - Anuncios: **No contiene anuncios**.
   - Acceso a la app: todo accesible sin restricciones (la cuenta con correo es opcional).
   - Clasificación de contenido (IARC): categoría *Juego*; carreras, sin violencia, sin contenido sexual, sin apuestas, sin chat, **con compras dentro de la app**.
   - Público objetivo: **13 años o más** (así no entra en las reglas de «Diseñado para niños»).
   - Seguridad de los datos y eliminación de la cuenta: **seguí `docs/PLAY_SEGURIDAD_DATOS.md`** (paso a paso, con las respuestas exactas). Resumen: sin el modo online no se recopila nada; con el online encendido se declaran correo, apodo, ID de usuario y puntajes (todo opcional, no compartido), y la dirección web para pedir el borrado es `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html` (el borrado desde la app ya está: MODO ONLINE → Cuenta → Borrar mi cuenta y mis marcas).
   - Declaración de ID de publicidad: **No** usa.
6. **Ficha principal de Play Store**: título, descripción corta y larga (`store_listing/ficha.md`), ícono 512, gráfico de funciones 1024×500, capturas (ver sección 4).
7. **Productos integrados** (Monetizar → Productos → Productos integrados), con **estos IDs exactos** (los pide el código):
   | ID | Tipo | Qué es | Precio recomendado (ver 0; lo confirmás vos) |
   |---|---|---|---|
   | `dr_full` | no consumible | **Juego completo**: aventura (12 etapas), todas las copas y los 3 autos premium | USD 9,99 |
   | `dr_adventure` | no consumible | Aventura completa (12 etapas, tenés 3 gratis) y las copas Continental y Leyenda | USD 4,99 |
   | `dr_garage` | no consumible | Garaje premium: Mamut 6x6, GT3 RS y Aerion | USD 6,99 |
   | `car_truck` | no consumible | Colossus Mamut 6x6 (camión) | USD 1,99 |
   | `car_gt3` | no consumible | Altair GT3 RS | USD 2,99 |
   | `car_hyper` | no consumible | Vortex Aerion | USD 3,99 |
   | `dr_coins_s` | **consumible** | Puñado de monedas: $ 5.000 del juego | USD 0,99 |
   | `dr_coins_m` | **consumible** | Bolsa de monedas: $ 12.000 (+20 % por moneda) | USD 1,99 |
   | `dr_coins_l` | **consumible** | Cofre de monedas: $ 30.000 (+50 % por moneda) | USD 3,99 |
   | `dr_coins_xl` | **consumible** | Baúl de monedas: $ 80.000 (mejor precio por moneda) | USD 7,99 |
   Los desbloqueos son **no consumibles** (se compran una vez y se recuperan con «Restaurar compras»); las bolsas de monedas son **consumibles** (se pueden comprar las veces que se quiera: el juego acredita las monedas, guarda el recibo para no acreditar dos veces la misma compra y recién después las consume en Google). Las monedas **no compran** los autos premium ni el DR Bisonte XR (esos son aparte), así que no hay «pagar para ganar»: sólo acelera lo que igual se consigue corriendo (autos de la tienda de $ 9.000 a $ 225.000, piezas, pintura, nafta). Los precios los pone Play Console: el juego muestra el que devuelve Google; los de arriba son una recomendación que revisás vos antes de subir.
   También hace falta tener la cuenta de pagos de comerciante (Perfil de pagos) completa.
8. **Probar las compras**: subí el primer AAB a **Pruebas internas**, agregá tu correo como tester y como *tester de licencia* (Configuración → Pruebas de licencia), instalá desde el link de Play y comprá (las compras de testers no cobran). **Las compras no se pueden probar con el APK de GitHub.**
9. **Producción**: crear versión → subir AAB → notas de versión → enviar a revisión (tarda de horas a unos días).

## 4. Imágenes que hay que subir
| Imagen | Medida / formato | Estado |
|---|---|---|
| Ícono de la app | 512×512 PNG | ✅ `store_listing/icono_512.png` (diseño provisorio «DR»; si tenés logo propio, reemplazalo) |
| Gráfico de funciones | 1024×500 PNG o JPG | ✅ `store_listing/grafico_funciones_1024x500.png` |
| Capturas de teléfono | 2 a 8, horizontales (ej. 1920×1080), PNG/JPG, lado menor ≥ 320 px | ✅ salen de las imágenes del tráiler en Full HD: carpeta `store_listing/capturas/` (ver `docs/TRAILER.md`); también podés sacar las tuyas con el botón 📷 del juego |
| Capturas de tablet 7" y 10" | opcionales (mejoran el posicionamiento), mismas reglas | opcional |
| Video promocional | enlace de YouTube, opcional | ✅ el tráiler (`docs/TRAILER.md`): subilo a YouTube («No es para niños»; no listado o público) y pegá el link en Play Console |

**Capturas sugeridas (en este orden):** 1) carrera con cámara trasera y el HUD completo; 2) cámara interior con los pilotos; 3) la plaza de drift con humo; 4) el mapa de la Ruta de los Sueños; 5) la tienda con el DR Bisonte XR; 6) el taller con las barras de ajuste; 7) una carrera con lluvia o atardecer; 8) un efecto de lente (ojo de pez / cine).
Los íconos del lanzador (adaptativo + monocromo) ya están en `godot/store/icons/` y los usa el AAB.

## 5. Qué queda oculto o apagado en la versión de Play (ya hecho, solo en el AAB)
- **Herramientas técnicas** (📊 diagnóstico de rendimiento, RENDIMIENTO, registro de FPS por capturas): ya no existen en el juego final; sólo en compilaciones de desarrollo (`Release.tools()`).
- **Modo online CERRADO** (`Release.ONLINE_OPEN := false`): la ficha dice «próximamente»; no se puede crear cuenta ni activar rankings, así que no se recopila ningún dato (las respuestas de «Seguridad de los datos» son las de «sin modo online»). Se abre en una actualización futura, cuando se cierre el tiempo real.
- **Modo desarrollador** (siete toques en la versión): no se puede activar y, aunque un perfil lo tuviera guardado, se ignora.
- **RENDIMIENTO** (prueba de rendimiento): sin botón en el menú ni arranque directo.
- **Descargas**: el juego tiene que funcionar sin conexión con todo adentro (los autos viajan en un paquete de recursos de Play, ver 7.2, no se bajan de internet); los permisos de red que figuran en el AAB los agrega la biblioteca de compras de Google.
- **Textos legales** (privacidad y términos): versión de Google Play, que cuenta las compras.
- Los argumentos de línea de comandos de prueba (`--perf`, `--autotest`…) no existen en Android.

### Propuestas que necesitan tu OK (todavía NO las hice)
1. **Idiomas**: español, inglés, portugués, francés, italiano y alemán ya tienen traducción de los textos del juego (la voz grabada del copiloto todavía solo existe en español, ver `docs/PLAN_V1.md`).
2. **Taller de prueba de la pausa** (ajusta todo gratis en pruebas de autos de la tienda y Carrera rápida): ¿lo dejamos para todos o solo en la prueba de autos de la tienda? Como se venden créditos, quizá convenga dejarlo solo en la tienda.
3. **Reparto gratis / pago**: hoy son gratis las 3 primeras etapas de la aventura, las copas Debut y Nacional y todos los mapas; el resto con `dr_adventure` / `dr_garage` / `dr_full`.
4. **Créditos**: SÍ se venden (bolsas de monedas consumibles, ver tabla de productos). Precios y cantidades a revisar por el dueño antes de subir.
5. **DR Bisonte XR** en la tienda ($190.000): se ve y se prueba, pero se compra recién al terminar la aventura. ¿Lo mantenemos así en la versión de Play?
6. **Ícono provisorio**: ¿querés un logo propio?

## 6. Antes de cada actualización
- Cada vez que corras el flujo, el *versionCode* sube solo (1000 + número de ejecución). Play exige que siempre sea mayor.
- Subí el nuevo `.aab` en la pista que corresponda y completá las notas de versión.
- Si cambia algo que cuenta datos o compras, actualizá `docs/PRIVACIDAD.md` y volvé a correr `python3 tools/play/make_legal_html.py`.

## 7. Cosas técnicas a vigilar
### 7.1 Páginas de 16 KB (bloqueo)
Google exige desde el 1/11/2025 que las apps con API objetivo 35 o más (nosotros: 36) soporten dispositivos con páginas de memoria de 16 KB. Eso se cumple si las bibliotecas nativas (`libgodot_android.so`, `libc++_shared.so`) tienen los segmentos `LOAD` alineados a 16 KB (`p_align = 0x4000`) y van sin comprimir en el APK.
- **Estado:** el AAB `v1002` (Godot 4.4.1) tiene `p_align = 0x1000` en las dos (comprobado leyendo el ELF). Godot 4.4.1 no lo soporta; la compatibilidad entró en Godot 4.5 (PR #106358; hay una copia para la rama 4.4 en el PR #110926, pero no hay certeza de en qué versión 4.4.x salió).
- **Camino recomendado:** subir el motor a **Godot 4.5.x o más nuevo** en `.github/workflows/*.yml` (`GODOT_VERSION`) y en la computadora de pruebas, correr toda la batería (`godot --headless --script res://tests/...`) y mirar el juego en el teléfono (sombras, el sombreador de papel, la pintura de los autos, la física de los camiones, el audio y el mundo abierto son lo más sensible a un cambio de motor). Después volver a armar el AAB y revisar con `tools/export/check_aab_alignment.py` (a escribir junto con el cambio) que ningún `.so` de 64 bits quede en 4 KB.
- **Hasta que se haga esto no se puede subir ningún AAB nuevo.** Las versiones de prueba por APK (GitHub) no se ven afectadas: sólo es una exigencia de la Play Store.

### 7.2 Los autos (566 MB) no entran en el AAB (bloqueo)
El módulo base de un AAB está limitado a 200 MB. Los 26 autos (`cars.pck`, 566 MB) hay que sacarlos del módulo base:
- **Play Asset Delivery** (recomendado): un paquete de recursos *install-time* (o *fast-follow*) con `cars.pck`; Google lo baja junto con la app sin que el jugador haga nada y sin servidor propio. Las plantillas de Gradle de Godot ya traen el módulo `assetPackInstallTime`; el flujo «Build Play Store AAB» tiene que (1) exportar `content.pck` como paquete principal, (2) exportar `cars.pck` con el preset «Cars» y copiarlo al módulo del paquete de recursos, y (3) hacer que el arranque cargue `cars.pck` desde los recursos de la app. Los paquetes de recursos pueden pesar hasta 1,5 GB cada uno (verificalo en la consola de Play, los límites cambian).
- **Alternativa**: bajar `cars.pck` de un servidor propio la primera vez (como hace hoy el APK liviano con GitHub). Para la Play Store no conviene: depende de un hosting propio (hoy es el de GitHub, no pensado para esto) y hay que declararlo en la política de privacidad.
- **Alternativa 3**: reducir los modelos (el dueño pidió no reducirlos hasta probar; está anotado).

### 7.3 Otras
- **API 36 exigida por Google** (la fecha límite de 2026 ya pasó): el flujo compila contra la plataforma 36 aunque Godot 4.4 trae la plantilla de la 35. Con Godot 4.5+ se simplifica.
- **Plugin de compras**: el flujo lo baja de `godotengine/godot-google-play-billing`; si no lo encuentra el AAB sale marcado `SIN-COMPRAS`. La API del plugin se ajustará en la primera prueba interna (no se puede probar fuera de Google Play).
- **Verificado en la compilación de prueba (r1):** el AAB se arma de punta a punta, apunta a la API 36, trae el plugin y la biblioteca de compras, el nombre de paquete `com.srg.dreamracing` y vibración. El `v1002` salió con la clave de subida real.
