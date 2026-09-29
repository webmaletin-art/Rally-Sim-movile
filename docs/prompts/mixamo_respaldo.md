Tarea: armar en ESTE repositorio (privado) un respaldo completo de TODAS las animaciones de Mixamo, clasificadas y documentadas. Es solo un archivo de respaldo; no hay que integrarlo a ningún juego.

## Acceso
- La cuenta de Mixamo está en las variables de entorno MIXAMO_EMAIL y MIXAMO_PASSWORD (o te la paso en el chat).
- NUNCA escribas la contraseña ni el token en ningún archivo, commit, log o README.
- Si Adobe pide captcha o código de verificación, frená y avisame.

## Cómo descargar
1. Iniciá sesión en https://www.mixamo.com con Playwright (Chromium ya viene instalado) y sacá el token de acceso de la sesión (localStorage "access_token").
2. Usá la API interna de Mixamo con ese token. Encabezados: `Authorization: Bearer <token>` y `X-Api-Key: mixamo2`. Así lo hacen los scripts conocidos; verificá que funcione antes de lanzar todo.
   - Listar: `GET /api/v1/products?page=N&limit=96&type=Motion,MotionPack` (recorré todas las páginas).
   - Detalle: `GET /api/v1/products/{id}?similar=0&character_id={YBOT_ID}` (trae `gms_hash`).
   - Exportar: `POST /api/v1/animations/export` con el personaje **Y Bot**. Preferencias:
     - `format: "fbx7_2019"` (FBX Binary)
     - `skin: "false"` (sin piel)
     - `fps: "30"`
     - `reducekf: "0"`
   - Esperar: `GET /api/v1/characters/{YBOT_ID}/monitor` hasta `completed` y bajar el archivo de `job_result`.
3. Las de caminar/correr/trotar, si tienen la opción **In Place**, bajalas en esa versión y además la normal (sufijo `_inplace`).
4. Bajá UNA vez el personaje **Y Bot** en T-pose con piel: `personajes/ybot_tpose.fbx`. Es el esqueleto que comparten todas las animaciones.
5. Sé prolijo con Adobe:
   - de a una exportación por vez, con 1 a 2 segundos de pausa;
   - reintentos con espera si falla;
   - si Adobe empieza a frenar (errores 429 o 403 seguidos), pará y avisame.
6. **Reanudable:** si un archivo ya existe, salteálo, así se puede cortar y seguir otro día.

## Cómo guardar y clasificar
- **Nombres:** respetá el **nombre original** de Mixamo en el archivo (espacios → guiones bajos). Ejemplo: `Soccer_Penalty_Kick.fbx`.
- **Packs:** los packs de Mixamo (MotionPack) van en `packs/<Nombre_del_pack>/` con todas sus animaciones adentro.
- **Animaciones sueltas:** van en `animaciones/<categoria>/`, clasificadas por el nombre, la descripción y las etiquetas de Mixamo. Categorías:
  - `idle_parado` · `caminar_correr` · `saltos_parkour` · `combate_pelea` · `armas_shooter` · `deportes_futbol` · `deportes_otros`
  - `baile` · `gestos` · `hablar_conversacion` · `emociones` (festejo, derrota, miedo, risa) · `interaccion` (dar, agarrar, saludar, empujar)
  - `sentado_manejar` · `trabajo_acciones` (levantar, cargar, reparar) · `caidas_muertes` · `magia_fantasia` · `zombie_criaturas` · `otras`
  - Si dudás, elegí la más probable y anotalo en el índice.
- **Límites de GitHub:**
  - ningún archivo de más de 100 MB;
  - hacé commit y push por tandas (por ejemplo cada ~300 archivos o ~500 MB), cada push por debajo de 1,5 GB, directo a la rama `main`.

## README (muy importante)
Armá un `README.md` detallado que se actualice en cada tanda, con:
1. Resumen: total de animaciones y de packs, peso total y fecha.
2. Cómo está organizado el repo, qué hay en cada carpeta y la configuración de descarga (FBX Binary, sin piel, 30 fps, Y Bot).
3. Por cada categoría y cada pack, una tabla con:
   - `Archivo` (ruta completa)
   - `Nombre en Mixamo`
   - `Descripción` (la de Mixamo, traducida en una línea)
   - `Duración / frames` (si la API la da)
   - `In Place` (sí/no)
4. Al final, la lista de las que fallaron, si hubo.

Además guardá `indice.json` con lo mismo (una entrada por animación: ruta, nombre, descripción, categoría, pack, duración, inplace, id de Mixamo), para poder buscar rápido.

## Para después
Cuando te pida "armá un zip con estas animaciones", juntá esos archivos (con la misma estructura de carpetas) en un ZIP y dejalo en `exportes/<nombre>.zip`, o pasame el link.

Al terminar cada tanda, decime cuántas llevás, cuántas faltan y cuánto pesa el repo.
