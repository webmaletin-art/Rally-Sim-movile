# MEMORÁNDUM PRELIMINAR DE CLASIFICACIÓN DE EXPORTACIÓN

Proyecto: Dream Racing: Rally y Drift
Identificador: "com.srg.dreamracing"
Desarrollador: establecido en Argentina
Motor: Godot 4.7.2
Artefacto analizado: "DreamRacing-play-v1006.aab"
Fecha de elaboración: 23 de octubre de 2026
Estado: análisis preliminar; no constituye una determinación formal del BIS ni asesoramiento jurídico.

## 1. Propósito

Documentar los hallazgos técnicos y el análisis preliminar de las normas de exportación de Estados Unidos relativos al cifrado utilizado por Dream Racing, para respaldar la evaluación de la declaración solicitada por Google Play Console.

Este documento no certifica por sí solo que la aplicación esté autorizada para exportarse. La clasificación y el cumplimiento deben evaluarse conforme a la normativa vigente y a las circunstancias aplicables.

## 2. Función principal de la aplicación

Dream Racing es un videojuego de carreras y entretenimiento, distribuido gratuitamente con compras integradas previstas.

Según la auditoría técnica disponible, sus funciones online permiten autenticación, acceso a servicios del juego, comunicación con el servidor, descarga de contenido y compras integradas.

La función principal identificada es el entretenimiento, no la prestación de servicios de seguridad informática ni de criptografía.

## 3. Hallazgos técnicos disponibles

La auditoría preliminar del AAB v1006 y del código identificó:

- Conexiones HTTPS/TLS para servicios online y descarga de contenido.
- WebSocket seguro (WSS) para funciones online.
- SHA-256 para comprobar la integridad de contenido descargado.
- HMAC-SHA256 para comprobar la integridad de un perfil local.
- Godot 4.7.2 con componentes criptográficos de mbedTLS.
- Google Play Billing y bibliotecas estándar de Android.
- Ausencia identificada de cifrado propio de archivos, VPN, proxy, cifrado de extremo a extremo y cifrado del paquete de recursos.

La versión exacta de mbedTLS y la negociación efectiva de las suites criptográficas no están confirmadas. Los hallazgos corresponden al artefacto y al código examinados; deben revisarse si cambia la versión publicada.

## 4. Marco normativo por evaluar

Las fuentes de referencia identificadas son:

1. Google Play Help, “Cumplimiento de las leyes de exportación”:
   https://support.google.com/googleplay/android-developer/answer/113770?hl=en

2. BIS, “Cryptography for Data Confidentiality”:
   https://www.bis.gov/learn-support/encryption-controls/cryptography-for-data-confidentiality

3. Electronic Code of Federal Regulations, 15 CFR Part 740:
   https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-740

4. Electronic Code of Federal Regulations, 15 CFR Part 742:
   https://www.ecfr.gov/current/title-15/subtitle-B/chapter-VII/subchapter-C/part-742

5. Federal Register, regla del 25 de junio de 2010:
   https://www.federalregister.gov/documents/2010/06/25/2010-15072/

La normativa aplicable debe comprobarse en su versión vigente a la fecha de la determinación. La presencia de una referencia normativa en este documento no significa que todas sus disposiciones hayan sido verificadas íntegramente para este producto.

## 5. Evaluación preliminar

La orientación publicada por el BIS describe supuestos en los que la criptografía utilizada en apoyo del entretenimiento, incluidos los videojuegos, queda fuera de los controles específicos de cifrado de la Categoría 5, Parte 2.

Los hallazgos técnicos disponibles son compatibles con la hipótesis de que la criptografía de Dream Racing apoya su función principal de entretenimiento.

Esta hipótesis debe contrastarse con las condiciones exactas de la disposición vigente y con las características reales de la versión distribuida.

La exclusión de la Categoría 5, Parte 2 no determina automáticamente que el producto sea EAR99. Antes de concluir EAR99, corresponde evaluar si el artículo está descrito en otra categoría de la Commerce Control List (CCL).

No se ha obtenido una clasificación formal del BIS ni una opinión jurídica independiente.

## 6. Obligaciones de presentación

No se ha establecido que Dream Racing deba presentar una notificación, solicitar una clasificación formal o entregar un informe anual de autoclasificación.

Tampoco se ha establecido definitivamente que todas esas obligaciones sean inaplicables. La respuesta depende de la clasificación que corresponda y de las disposiciones vigentes.

Si se concluye que el producto está excluido de la Categoría 5, Parte 2, deben evaluarse las demás categorías de la CCL antes de determinar su clasificación final.

## 7. Estado de la declaración de Google Play

La declaración de Google Play exige que el desarrollador determine sus requisitos de cumplimiento y certifique que la aplicación está autorizada para exportarse conforme a las leyes aplicables.

Este memorándum documenta el análisis preliminar, pero no sustituye esa determinación ni una autorización cuando esta sea necesaria.

Estado actual: pendiente de decisión del desarrollador.

Antes de aceptar la declaración, se recomienda:

1. Conservar el informe técnico del AAB y este memorándum.
2. Verificar la normativa vigente y completar el análisis de las demás categorías de la CCL.
3. Si persiste una duda relevante, obtener una opinión escrita de un especialista en controles de exportación o consultar al BIS sobre el procedimiento apropiado.

## 8. Control de cambios

Este documento corresponde únicamente a la versión técnica identificada como "DreamRacing-play-v1006.aab".

Cualquier cambio relevante en el motor, bibliotecas criptográficas, funcionalidades online, cifrado o arquitectura debe motivar una revisión antes de reutilizar estas conclusiones para una versión posterior.

Conclusión: existe una base técnica preliminar para evaluar la exclusión de la Categoría 5, Parte 2 por función principal de entretenimiento. La clasificación final y la autorización de exportación no se consideran formalmente determinadas por este documento.

---

## Anexo (agregado al guardar el documento, 23/10/2026): verificación de los datos técnicos contra el AAB v1006

Este anexo NO forma parte del memorándum recibido; registra la comprobación pedida al guardarlo. No cambia sus conclusiones, que siguen siendo preliminares.

**Artefacto:** `DreamRacing-play-v1006.aab`, release `play-aab` de GitHub, 763 337 049 bytes, SHA-256 `d3e3dc89e8c12ddccd72a602175a9a26b390fecdec906e8677e9b18a87c29119` (coincide con el digest que publica GitHub). Compilado desde el commit `a19d51a` de `main`; `godot/` no cambió desde entonces. Firma: `CN=SRGamestudios`; paquete `com.srg.dreamracing`, versionCode 1006, versionName 1.0.0.

| Afirmación del memorándum | Resultado | Evidencia / comando |
|---|---|---|
| Godot 4.7.2 | Coincide | `strings -a base/lib/arm64-v8a/libgodot_android.so \| grep "Godot Engine v"` → `v4.7.2.stable.official` |
| Componentes mbedTLS | Coincide | símbolos `mbedtls_ssl_*` con TLS 1.3 y suites AES/ARIA/Camellia/ChaCha20-Poly1305 en `libgodot_android.so` (arm64 y armeabi-v7a). Que estén incluidos no prueba que se usen |
| Versión exacta de mbedTLS no confirmada | Coincide | La cadena de versión no está en el binario. La tabla `thirdparty/README.md` de Godot 4.7.2-stable indica mbedTLS 3.6.7: fuente de procedencia, no verificada en el binario |
| HTTPS/TLS para servicios y descarga | Coincide | `godot/game/online/online.gd` (HTTPRequest a Supabase), `godot/bootstrap/boot.gd` (descarga desde GitHub) |
| WSS | Coincide | `godot/game/online/realtime.gd` (WebSocketPeer, `https://` → `wss://`) |
| SHA-256 de integridad de contenido | Coincide | `godot/bootstrap/boot.gd:271` (`FileAccess.get_sha256`) |
| HMAC-SHA256 de integridad del perfil local | Coincide | `godot/game/online/account_econ.gd:133-134` (`Crypto.hmac_digest`, clave escrita en el código: integridad, no confidencialidad) |
| Google Play Billing y bibliotecas estándar de Android | Coincide | plugin GodotGooglePlayBilling 3.3.0 en el AAB; `classes.dex` con `com.android.billingclient`, AndroidX y Play Services; llamadas a `MessageDigest`, `SecureRandom` y `KeyStore "AndroidCAStore"` (almacén de certificados del sistema) halladas con androguard |
| Sin cifrado propio de archivos | Coincide | `encrypt_pck=false` en `godot/export_presets.cfg`; sin `open_encrypted`/`AESContext` en `godot/**/*.gd` |
| Sin VPN, proxy, cifrado de extremo a extremo | Coincide | sin permisos ni código de ese tipo; permisos del manifiesto: INTERNET, ACCESS_NETWORK_STATE, VIBRATE, BILLING; sin GDExtensions ni addons propios |
| Negociación efectiva de suites no confirmada | Coincide | no se midió |

**Observaciones que el memorándum no recoge (para completar el análisis, sin alterarlo):**
- El chat y las cuentas del modo online pasan por HTTPS al servidor (Supabase); si cuentan como apoyo al entretenimiento es una de las cuestiones por resolver con un especialista.
- Del lado del servidor (fuera del AAB) hay firma JWT RS256 para verificar compras con Google y autenticación de Supabase.
- El motor incluye AES para cifrar paquetes y otras funciones que el juego no activa.

**Referencias NO verificadas:** ninguna de las cinco fuentes de la sección 4 pudo abrirse desde el entorno de trabajo (bloqueadas); no se leyó su texto vigente. Sobre ellas sólo se vieron resúmenes de búsqueda. En particular, la URL del BIS «Cryptography for Data Confidentiality» (referencia 2), el texto vigente de la Nota 4 de la Categoría 5, Parte 2 y el contenido actual de 15 CFR Partes 740 y 742 siguen sin comprobar, y la afirmación de la sección 5 sobre la orientación del BIS no pudo contrastarse con el original. Tampoco se verificó el texto exacto de la declaración en Play Console.
