# Dream Racing en Google Play — guía de publicación

Todo lo que ya está armado en el repositorio y lo que tiene que hacer el dueño (GitHub y Play Console).

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
1. **Cuenta de desarrollador** (pago único de USD 25 y verificación de identidad). *Ojo:* las cuentas personales nuevas suelen necesitar una **prueba cerrada con al menos 12 testers durante 14 días** antes de poder publicar en producción; verificalo en la pantalla de «Acceso a producción».
2. **Crear la app**: nombre «Dream Racing», idioma predeterminado español, tipo **Juego**, **gratis** (con compras integradas).
3. **Nombre de paquete**: el AAB usa `com.srg.dreamracing`. **Es permanente** una vez publicada. Si querés otro, decímelo *antes* de la primera subida.
4. **Play App Signing**: aceptá que Google guarde la clave de firma (la tuya es solo la de *subida*).
5. **Contenido de la app** (todos son formularios cortos):
   - Política de privacidad: la URL de arriba.
   - Anuncios: **No contiene anuncios**.
   - Acceso a la app: todo accesible, sin cuentas.
   - Clasificación de contenido (IARC): categoría *Juego*; carreras, sin violencia, sin contenido sexual, sin apuestas, sin chat, **con compras dentro de la app**.
   - Público objetivo: **13 años o más** (así no entra en las reglas de «Diseñado para niños»).
   - Seguridad de los datos: **sin el modo online**, no se recopilan ni comparten datos (los pagos los procesa Google Play). **Con los rankings online encendidos** (ver `docs/ONLINE_SUPABASE.md`) hay que declarar ID de usuario, puntuaciones y, si el jugador crea una cuenta, correo electrónico: todo opcional y no compartido. Como el juego deja **crear cuentas**, Play pide además **poder borrarla desde la app** (ya está: Modo online → Cuenta → Borrar mi cuenta) y **una dirección web para pedir el borrado** (declarala en *Contenido de la app → Eliminación de la cuenta*; por ahora el contacto de la política de privacidad).
   - Declaración de ID de publicidad: **No** usa.
6. **Ficha principal de Play Store**: título, descripción corta y larga (`store_listing/ficha.md`), ícono 512, gráfico de funciones 1024×500, capturas (ver sección 4).
7. **Productos integrados** (Monetizar → Productos → Productos integrados), con **estos IDs exactos** (los pide el código):
   | ID | Tipo | Qué es | Precio sugerido (a confirmar por vos) |
   |---|---|---|---|
   | `dr_full` | no consumible | **Juego completo**: aventura (12 etapas), todas las copas y los 3 autos premium | USD 1,99 |
   | `dr_adventure` | no consumible | Aventura completa (12 etapas, tenés 3 gratis) y las copas Nacional, Continental y Leyenda | USD 0,99 |
   | `dr_garage` | no consumible | Garaje premium: Mamut 6x6, GT3 RS y Aerion | USD 1,99 |
   | `car_truck` | no consumible | Colossus Mamut 6x6 (camión) | USD 0,99 |
   | `car_gt3` | no consumible | Altair GT3 RS | USD 0,99 |
   | `car_hyper` | no consumible | Vortex Aerion | USD 0,99 |
   Todos son **no consumibles** (se compran una vez y se recuperan con «Restaurar compras»). **No se venden créditos.** Los precios los pone Play Console: el juego muestra el que devuelve Google.
   También hace falta tener la cuenta de pagos de comerciante (Perfil de pagos) completa.
8. **Probar las compras**: subí el primer AAB a **Pruebas internas**, agregá tu correo como tester y como *tester de licencia* (Configuración → Pruebas de licencia), instalá desde el link de Play y comprá (las compras de testers no cobran). **Las compras no se pueden probar con el APK de GitHub.**
9. **Producción**: crear versión → subir AAB → notas de versión → enviar a revisión (tarda de horas a unos días).

## 4. Imágenes que hay que subir
| Imagen | Medida / formato | Estado |
|---|---|---|
| Ícono de la app | 512×512 PNG | ✅ `store_listing/icono_512.png` (diseño provisorio «DR»; si tenés logo propio, reemplazalo) |
| Gráfico de funciones | 1024×500 PNG o JPG | ✅ `store_listing/grafico_funciones_1024x500.png` |
| Capturas de teléfono | 2 a 8, horizontales (ej. 1920×1080), PNG/JPG, lado menor ≥ 320 px | ⏳ Sacalas en tu teléfono con el botón 📷 del juego (salen sin esfuerzo y en tu idioma) |
| Capturas de tablet 7" y 10" | opcionales (mejoran el posicionamiento), mismas reglas | opcional |
| Video promocional | enlace de YouTube, opcional | opcional |

**Capturas sugeridas (en este orden):** 1) carrera con cámara trasera y el HUD completo; 2) cámara interior con los pilotos; 3) la plaza de drift con humo; 4) el mapa de la Ruta de los Sueños; 5) la tienda con el DR Bisonte XR; 6) el taller con las barras de ajuste; 7) una carrera con lluvia o atardecer; 8) un efecto de lente (ojo de pez / cine).
Los íconos del lanzador (adaptativo + monocromo) ya están en `godot/store/icons/` y los usa el AAB.

## 5. Qué queda oculto o apagado en la versión de Play (ya hecho, solo en el AAB)
- **Modo desarrollador** (siete toques en la versión): no se puede activar y, aunque un perfil lo tuviera guardado, se ignora.
- **RENDIMIENTO** (prueba de rendimiento): sin botón en el menú ni arranque directo.
- **Descargas**: el juego va completo adentro y funciona sin conexión (los permisos de red que figuran en el AAB los agrega la biblioteca de compras de Google).
- **Textos legales** (privacidad y términos): versión de Google Play, que cuenta las compras.
- Los argumentos de línea de comandos de prueba (`--perf`, `--autotest`…) no existen en Android.

### Propuestas que necesitan tu OK (todavía NO las hice)
1. **Idiomas**: español, inglés, portugués, francés, italiano y alemán ya tienen traducción de los textos del juego (la voz grabada del copiloto todavía solo existe en español, ver `docs/PLAN_V1.md`).
2. **Taller de prueba de la pausa** (ajusta todo gratis en pruebas de autos de la tienda y Carrera rápida): ¿lo dejamos para todos o solo en la prueba de autos de la tienda? Como se venden créditos, quizá convenga dejarlo solo en la tienda.
3. **Reparto gratis / pago**: hoy son gratis las 3 primeras etapas de la aventura, la copa Debut y todos los mapas; el resto con `dr_adventure` / `dr_garage` / `dr_full`.
4. **Créditos**: no se venden (decidido).
5. **DR Bisonte XR** en la tienda ($250.000): se ve y se prueba, pero se compra recién al terminar la aventura. ¿Lo mantenemos así en la versión de Play?
6. **Ícono provisorio**: ¿querés un logo propio?

## 6. Antes de cada actualización
- Cada vez que corras el flujo, el *versionCode* sube solo (1000 + número de ejecución). Play exige que siempre sea mayor.
- Subí el nuevo `.aab` en la pista que corresponda y completá las notas de versión.
- Si cambia algo que cuenta datos o compras, actualizá `docs/PRIVACIDAD.md` y volvé a correr `python3 tools/play/make_legal_html.py`.

## 7. Cosas técnicas a vigilar
- **API 36 exigida por Google** desde el 31/08/2026 (hay prórroga hasta el 1/11/2026 si se pide). El flujo compila contra la plataforma 36 aunque Godot 4.4 trae la plantilla de la 35: si Gradle se queja, hay que subir a Godot 4.5 (hay que probar el juego en esa versión).
- **Plugin de compras**: el flujo lo baja de `godotengine/godot-google-play-billing`; si no lo encuentra el AAB sale marcado `SIN-COMPRAS`. La API del plugin se ajustará en la primera prueba interna (no se puede probar fuera de Google Play).
- Tamaño: el AAB debe pesar menos de 200 MB (la prueba de armado dio **70 MB**).
- **Verificado en la compilación de prueba (r1):** el AAB se arma de punta a punta, apunta a la API 36, trae el plugin y la biblioteca de compras, el nombre de paquete `com.srg.dreamracing` y vibración; salió con la clave de depuración (por eso se llama `PRUEBA`).
