# Guía simple: subir Dream Racing a Google Play

Pasos en orden, para hacer vos (la parte técnica ya está hecha en el repositorio). Detalle fino en `docs/PLAY_STORE.md`.
Tiempo total: unas horas de trámites + **14 días de prueba cerrada** (obligatorio en cuentas personales nuevas).

## 0. Antes de nada (no te saltees esto)
1. Instalá el APK de GitHub en tu teléfono (Releases → `godot-apk`), **apagá el modo desarrollador** (Acerca de → «APAGAR MODO DEV») y confirmá que **ya no se cierra al acelerar** (si se cierra: Acerca de → «COPIAR REGISTRO» y pegámelo). No subas a Play algo que se cierra.
2. Jugá una carrera completa, comprá un auto con créditos y cerrá/abrí el juego sin conexión.

## 1. Servidor (Supabase y GitHub) — una vez
1. GitHub → Settings → Secrets and variables → Actions → creá el secreto `GOOGLE_PLAY_SERVICE_ACCOUNT` (el JSON de una cuenta de servicio de Google Cloud con permiso en Play Console → Usuarios y permisos → «Ver información financiera»). Después corré el flujo **«Supabase · publicar funciones»** (así el servidor verifica las compras con Google).
2. Supabase → Authentication: **«Confirm email» apagado** (o un SMTP propio) y **«Allow anonymous sign-ins» apagado**.
3. Abrí `https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html`, `terminos.html` y `eliminar-cuenta.html` y comprobá que se ven (cuenta con correo, créditos en el servidor).

## 2. Cuenta de Play Console
1. https://play.google.com/console → pagá los USD 25 y verificá tu identidad.
2. Completá el **Perfil de pagos** (para vender).
3. Crear app: nombre «Dream Racing», español, **Juego**, **Gratis**. Paquete: `com.srg.dreamracing` (no se puede cambiar después).
4. Aceptá **Play App Signing**.

## 3. Armar el AAB
1. GitHub → Actions → **«Build Play Store AAB»** → Run workflow (versión `1.0.0`).
2. Cuando termina: Releases → `play-aab` → bajá el `.aab` que **no** diga `PRUEBA` ni `SIN-COMPRAS` (pesa ~675 MB).

## 4. Formularios de «Contenido de la app»
- Política de privacidad: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html`
- Anuncios: **No**. Público: **13 años o más**. Clasificación IARC: carreras, sin violencia, con compras.
- **Acceso a la app**: «restringida». Creá una cuenta de revisión (correo + contraseña) en el juego, regalale saldo con `account_admin_grant` (ver `docs/CUENTA_Y_ECONOMIA.md`) y pegá las instrucciones («Abrir → Iniciar sesión → ENTRAR») y los datos.
- **Seguridad de los datos** y borrado de cuenta: seguí `docs/PLAY_SEGURIDAD_DATOS.md` (respuestas exactas). Dirección de borrado: `https://webmaletin-art.github.io/Rally-Sim-movile/docs/eliminar-cuenta.html`.
- ID de publicidad: **No**.

## 5. Ficha
- Textos en 6 idiomas: `store_listing/ficha.md`. Ícono 512 y gráfico 1024×500: carpeta `store_listing/`. Capturas: `store_listing/capturas/` (mínimo 2, mejor 8).
- Video: subí el tráiler a YouTube y pegá el link.

## 6. Productos integrados (Monetizar → Productos)
IDs **exactos** (el juego y el servidor los esperan): `dr_full`, `dr_adventure`, `dr_garage`, `car_truck`, `car_gt3`, `car_hyper` (no consumibles) y `dr_coins_s`, `dr_coins_m`, `dr_coins_l`, `dr_coins_xl` (**consumibles**). Precios recomendados en `docs/PLAY_STORE.md` (sección 0); confirmalos vos.

## 7. Prueba interna (compras) → prueba cerrada → producción
1. **Pruebas internas** → subí el `.aab` → agregá tu correo como tester y en Configuración → *Pruebas de licencia*. Instalá desde el link de Play, iniciá sesión y probá una compra (no cobra a testers). Verificá que los créditos llegan.
2. **Prueba cerrada**: subí el mismo AAB, juntá **12 testers con Gmail** y que sigan inscriptos **14 días seguidos**.
3. Cuando Play te habilite «Acceso a producción»: Producción → crear versión → subir AAB → notas → **enviar a revisión** (horas a días).

## 8. Cada actualización
Volvé a correr «Build Play Store AAB» (el número de versión sube solo) y subí el nuevo `.aab` a la pista que corresponda.

## Cosas que dependen de vos
- Confirmar que tu plan de **MusicGPT permite uso comercial** (si no, apagá la música o reemplazala).
- El modo online queda **cerrado** hasta que me digas «abrilo» (después hay que revisar la declaración de datos de Play).
- Tu progreso anterior del teléfono no se importa a la cuenta: si lo querés, `account_admin_grant`.
