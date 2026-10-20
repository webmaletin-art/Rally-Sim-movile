# Versión candidata (RC) — Dream Racing

Rama `ccr-e7ae3f10-45afj2` · **NO está en `main`** · Godot 4.7.2 · 16/10/2026.
Es la versión para probar en el teléfono antes de decidir si se publica. Nada de esto se publicó ni se aplicó al servidor real.

**Cómo leer los estados** (en este documento y en el registro):

| Estado | Qué significa |
|---|---|
| **listo para prueba manual** | El código está hecho y el APK RC se arma solo. Falta que alguien lo juegue. |
| **validado técnicamente** | Pasaron sus pruebas automáticas (Godot sin pantalla, SQL en un Postgres de prueba de GitHub). |
| **validado en dispositivo** | Alguien lo probó en un teléfono. **Hasta hoy: nada de esta tanda.** |
| **listo para publicar** | Validado en el teléfono, migraciones aplicadas, Play Console configurado. **Hasta hoy: no.** |

---

## 1. Qué trae (fases 1 a 6)

| Fase | Qué cambia | Detalle | Estado |
|---|---|---|---|
| 1 · Economía y seguridad | Reglajes bloqueados hasta comprar la pieza. Premios de una sola vez guardados en la cuenta (no se cobran dos veces al reinstalar). Fin de la granja de fugas. | `docs/AUDITORIA_CICLO_DE_JUEGO.md`, migración 20261022 | validado técnicamente |
| 2 · Descubrimiento | Próximo objetivo, «?» en el mapa, tutorial corto, cola de avisos. | registro 16/10 | validado técnicamente |
| 3 · Competencia justa | Récords por clase de PI, con ayudas y gomas; cola sin conexión; puesto al terminar. | migración 20261023 | validado técnicamente |
| 4 · Progresión y autos | Perder a propósito ya no paga más que ganar. GT3 e Hyper con un rol propio. Diferencial nivel 2 y stance con efecto real. Travesía X paga mejor. | `tools/econ/progression_sim.py`, registro (19) | validado técnicamente |
| 5 · Eventos y retención | Cacería para principiantes, horarios que rotan, desafíos del día, hitos de la temporada, metas de colección. | migración 20261024, registro (20) | validado técnicamente |
| 6 · Compras | Revisión (sección 5). Sin cambios de precios ni productos nuevos. | este documento | revisado (sin cambios de código) |

---

## 2. Cómo se arma

- **Compilación:** cada push a la rama corre `.github/workflows/build-godot.yml`. Corre la lista de pruebas (cada una con tope de tiempo) y después arma:
  - el contenido en la release `godot-content-4.7-rc` (los autos se reusan de `godot-content-4.7` si no cambiaron);
  - el APK en la release **`godot-apk-rc`** (`DreamRacing-RC.apk`).
- **Instalación:** el APK RC se llama «Dream Racing RC», paquete `com.gskorp.rallygodot.rc`. Se instala **al lado** de la app normal y no la pisa.
- **Concurrencia:** desde el 16/10, un push nuevo cancela la compilación anterior de la rama RC. En `main` no se cancela nada.
- **Al fusionar a `main`** (sólo con autorización del dueño) hay que deshacer 4 cosas:
  - la rama del disparador;
  - `CONTENT_TAG`;
  - la release y el `CHANNEL` de `bootstrap/boot.gd`;
  - el paquete `.rc`.

  Están anotadas al principio de `build-godot.yml`.
- **No hay que deshacer** el paso «Marcar la versión candidata» (desde el 20/10): escribe `game/build_channel.txt` («rc») sólo si la rama no es `main`, y con ese archivo `Release.internal()` habilita el modo desarrollador y «COPIAR REGISTRO».
  En `main` el paso no corre, así que la versión pública no los trae aunque nadie se acuerde de nada. `tools/export/check_pck.py` falla el armado si el marcador se escribió y no entró al paquete.
- **Play Store:** el AAB se arma a mano con el flujo «Build Play Store AAB» (`build-aab.yml`). Ese flujo sí lleva la característica `store`: sin modo desarrollador y sin herramientas.

## 3. Pruebas

- **En cada compilación (GitHub):** 101 pruebas de Godot sin pantalla (`godot --headless --script res://tests/…`), cada una con `timeout`.
- **Pruebas SQL:** `.github/workflows/economy-test.yml` aplica TODAS las migraciones dos veces en un Postgres temporal. Después corre:
  - `tools/online/economy_test.sql`;
  - `tools/online/account_test.sql`;
  - la prueba de la función de compras (`verify_purchase_test.mjs`).

  No toca el proyecto real de Supabase.
- **A mano y cortas (pedido del dueño):** `tools/test/run_test.sh <prueba> [tope]` o `--lista a b c [tope]`.
  - Cada renglón queda escrito al instante en `test_logs/<prueba>.log`, con los segundos transcurridos.
  - El resultado va a `test_logs/RESUMEN.txt`.
  - Si una prueba se traba, se corta al llegar al tope y lo comprobado hasta ahí no se pierde.
- **La economía se calcula, no se juega:**
  - `godot/tests/econ_dump.gd` vuelca en unos 10 s las 79 carreras y los 28 autos;
  - `tools/econ/progression_sim.py` saca horas y $/h por perfil.
- **No se corre acá:** `online_test` necesita un servidor de prueba local, y el dueño pidió no levantarlo. La corre GitHub.

## 4. Variables y secretos (sólo los nombres; los valores están en GitHub → Settings → Secrets)

| Nombre | Para qué |
|---|---|
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` | Firma del AAB de Play (clave de SUBIDA) |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Cliente del juego. La clave anónima es pública por diseño: la seguridad está en RLS y en las funciones. |
| `SUPABASE_PROJECT_ID`, `SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD` | Flujos «Supabase · aplicar migraciones / publicar funciones / uso». Nunca van al APK. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT` | Secreto de la función `verify-purchase`. Nunca va al APK. |
| `SUPABASE_AUTODEPLOY` (variable) | Apagada: las migraciones se aplican a mano. |

La clave `service_role` **no** está en el repositorio ni en el APK. La usa sólo la función de borde, porque Supabase se la da.

### Auditoría del repositorio (16/10/2026)
- **Búsqueda de secretos** (claves JWT, `sb_secret_`, claves privadas, AWS, GitHub, Google API): **nada** en el repositorio.
- **`godot/game/online/online_config.json`:** está vacío (`url`/`anon_key` en blanco). Los pone la compilación desde los secretos.
- **`godot/keystore/debug.keystore`:** es la clave de DEPURACIÓN estándar de Android (`androiddebugkey` / `android`).
  - Firma los APK de GitHub (estable y RC) y está excluida de los paquetes del juego.
  - El AAB de Play se firma con la clave de SUBIDA (secretos). Si los secretos faltan, el flujo avisa que Play no lo acepta.
  - Límite: cualquiera podría firmar un APK con esa misma clave pública de depuración. No afecta a Play.
- **Constantes de la versión** (`game/data/release.gd`):
  - `PVP_FORCE = false`;
  - las herramientas (📊) sólo existen en compilaciones de depuración, y los APK salen con `--export-release`;
  - `ONLINE_OPEN` y `REALTIME` en `true` por autorización del dueño (15/10). El tiempo real sigue apagado por `app_flags.pvp`.
- **Recursos que falten:** los cubren `scripts_parse_test` (parsea todos los scripts) y `release_test` (en CI).

## 5. Contenido pago (fase 6: inventario y revisión)

| Producto | Tipo | Qué da | Dónde se valida |
|---|---|---|---|
| `dr_full` | no consumible | Aventura completa + copas + los 3 autos premium | `verify-purchase` → `account_iap_grant` → `account_econ.iap` |
| `dr_adventure` | no consumible | 12 etapas de la Aventura + copas Continental y Leyenda | ídem |
| `dr_garage` | no consumible | Mamut 6x6, GT3 RS y Aerion | ídem |
| `car_truck`, `car_gt3`, `car_hyper` | no consumible | Cada auto premium suelto | ídem; el servidor sólo da el auto con la compra (`give_car` «iap») |
| `dr_coins_s/m/l/xl` | consumible | $5.000 / 12.000 / 30.000 / 80.000 del juego | ídem; se acredita una vez por recibo y recién después se consume en Google |

Precios sugeridos (los pone Play Console, no el juego): `docs/PLAY_STORE.md`. **No se cambió ningún precio ni producto.**
No hay suscripciones, publicidad, cajas de botín ni moneda premium nueva. Los cosméticos (diseños, interiores, volantes) se compran con créditos del juego, validados por el servidor.

**Cómo es una compra:**
1. Google confirma la compra.
2. El juego manda el recibo a `verify-purchase`.
3. La función le pregunta a la API de Google Play si la compra es real (`purchaseState = 0`).
4. `account_iap_grant` guarda el hash SHA-256 del recibo, que es clave única: el mismo recibo nunca acredita dos veces, ni en otra cuenta.
5. Recién con el OK del servidor el juego consume (monedas) o reconoce (desbloqueos) la compra en Google.
6. Si algo falla, la compra queda pendiente en Google y se reintenta sola al abrir el juego. Google devuelve el dinero si no se reconoce en 3 días.

**Restaurar compras:**
- El botón de la tienda (`billing.restore()` → `query_purchases`) vuelve a mandar los recibos.
- Si el recibo ya era de esta cuenta, el servidor contesta `dup` con la cuenta como está: no se pierde nada ni se duplica nada.

**Pruebas que lo cubren:**
- `tools/online/account_test.sql`: recibo repetido, recibo en otra cuenta, cuenta borrada, auto premium sin compra.
- `tools/online/verify_purchase_test.mjs`: recibo falso, pendiente, cancelado, sin sesión.
- **No hay validación simulada en el juego:** sin servidor, la compra no se acredita.

**Límites conocidos de las compras** (hay que saberlos antes de publicar; ninguno se arregló en esta tanda):
- **Reembolsos:** un reembolso de Google NO quita lo comprado. No se usa la API de compras anuladas («voided purchases»). Se puede quitar a mano con `account_admin_grant` o desde el panel.
- **Un recibo, una cuenta del juego:** un desbloqueo comprado con un Google queda en la PRIMERA cuenta del juego que lo verificó. Si el jugador crea otra cuenta, «Restaurar» no se lo pasa: hay que hacerlo a mano.
- **El APK liviano de GitHub** (y el RC) no lleva la característica `store`: ahí se puede activar el modo desarrollador (7 toques en la versión), que juega todo local y no toca la cuenta del servidor. **Al público sólo se le da el AAB de Play.**
- **Sin cuenta o sin Supabase en la compilación**, la compra se acredita sólo en el teléfono (modo viejo). Con la cuenta obligatoria (`Release.ACCOUNT_REQUIRED`) eso no pasa en la versión de Play.

## 6. Migraciones del servidor PENDIENTES (no aplicadas: el servidor es el mismo que usa el APK estable)

Se aplican **en este orden** con el flujo «Supabase · aplicar migraciones», **sólo con autorización del dueño**. Todas son aditivas y se pueden repetir. Cada una tiene una autoprueba: si falla, se deshace sola.

| Migración | Qué agrega | Efecto en el APK estable | Después de aplicarla |
|---|---|---|---|
| `20261022000000_claims_progress.sql` | `account_econ.claims`: premios de una sola vez y progreso en la cuenta | Ninguno visible (los premios únicos dejan de pagarse dos veces) | Nada |
| `20261023000000_class_records.sql` | `class_scores`, `submit_class_record`, `get_class_leaderboard` | Ninguno (sigue con su tabla `scores`) | Nada |
| `20261024000000_events_rotation_daily_milestones.sql` | Horarios rotativos, `caza_inicial` (apagada), `game_cfg.daily`, hitos de temporada | Las cacerías cambian de hora y de título (las ve igual) | Cuando se publique la versión nueva: `wev_templates` → `caza_inicial` → `enabled = true` |

**Si se publica el APK nuevo SIN 20261022:**
- los desafíos del día y las metas nuevas se pagan igual, pero el servidor no los marca como únicos;
- un jugador que reinstala podría cobrarlos otra vez, dentro de los topes por hora y por día.

**Conclusión: aplicar 20261022 antes de publicar.**

## 7. Economía y eventos (resumen)

- **Economía:**
  - números y método en `docs/REGISTRO_TECNICO.md` (19) y `docs/AUDITORIA_CICLO_DE_JUEGO.md`;
  - primer superdeportivo (Veltor GTR) en 12–16 h sólo con lo repetible;
  - las 79 carreras del mapa pagan la 1.ª victoria entera, 35 % repetida y 55 % de su puesto si no ganás (desde el 2.º intento).
- **Eventos del servidor:**
  - `docs/ONLINE_POR_EVENTOS.md` y `docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md`;
  - nuevos en la fase 5: horarios rotativos (noche 20–23 h, tarde 15–18 h, principiantes 11–14 h, hora argentina, distinta cada día);
  - hitos de temporada: 25 / 60 / 150 / 300 pts.
- **Desafíos del día:**
  - `godot/game/data/daily.gd`, tres por día, cambian a la medianoche argentina;
  - se configuran en `game_cfg` → `daily` (prendidos, premios, cuántas carreras).

## 8. Límites conocidos de la versión

- **Nada de esta tanda se probó en un teléfono.**
- El tope de PI de la cacería de principiantes lo controla el juego: el servidor no conoce el PI del auto.
- El día de los desafíos usa el reloj del teléfono. Adelantar el reloj da los desafíos de otro día, pero los topes de premios del servidor siguen valiendo.
- `account_econ.claims` guarda hasta 3.000 claves por cuenta. Los desafíos del día suman 3 por día jugado, así que alcanza para unos 2 años y medio.
- Pendientes de antes que siguen igual:
  - puentes y pasos a distinto nivel;
  - rutas mal unidas que el dueño reporte con captura;
  - textos nuevos sólo en español.

## 9. Prueba en el teléfono (corta, para el dueño)

1. **Instalar:** bajá `DreamRacing-RC.apk` de la release `godot-apk-rc` e instalalo. Queda al lado de la app normal.
2. **Abrir:** iniciá sesión y dejá que baje el contenido. ¿Abre sin cerrarse?
3. **LOGROS:**
   - la primera página tiene que mostrar «DESAFÍOS DEL DÍA» y «COLECCIÓN»;
   - terminá 2 carreras del mapa y cobrá el primer desafío;
   - cerrá y abrí la app: tiene que seguir «COBRADO».
4. **Carreras del mapa:** salí 2.º dos veces en la misma. La segunda vez tiene que pagar menos que la primera.
5. **Taller:**
   - con el diferencial en nivel 1, el reparto de tracción tiene que tener candado;
   - comprá el nivel 2: el candado se va.
6. **Stance:** ponele 10° o más a un auto con stance. ¿Se ven las ruedas inclinadas?
7. **Garaje:** mirá el GT3 RS y el Aerion (barra de manejo).
8. **Travesía X:** ¿cuánto pagó al llegar? Tiene que ser $3.000–6.000.
9. **Si algo se cierra:** «COPIAR REGISTRO» (Acerca de) y pegarlo.

Con el servidor tal cual, sin las migraciones nuevas:
- los récords por clase van a la tabla vieja;
- no hay hitos de temporada;
- la cacería es la de siempre.

Todo eso es lo esperado.

## 9 bis. Lo que se sumó el 20/10/2026 (cuarta tanda de [B], pedido del dueño de «dejar el juego listo para publicar»)

Está en la misma rama y en el mismo APK RC. Detalle y causas: `docs/REGISTRO_TECNICO.md` → 20/10 05:30. **Nada de esto se probó en un teléfono.**

| Qué | Para mirar en el teléfono |
|---|---|
| Las cuadras de la ciudad se arman en un hilo | Ir fuerte (150–250 km/h) por las rutas a otros pueblos y por la ciudad: ¿hay tirones? ¿se ve que aparezcan las cuadras de golpe? Con «Mostrar FPS»: ¿baja el FPS al cruzar de una cuadra a otra? |
| Huecos entre edificios cerrados | Intentar entrar entre dos edificios, a un parque o a la Plaza Aurora (no debe poder); la Plaza y el Parque del Drift siguen abiertos; entrar a talleres, concesionarios y estaciones. |
| Veredas planas | ¿Las ruedas ya no «suben» el cordón? ¿Se ve bien la vereda? |
| Policía | Pasar un control a más de 70 km/h (no te arresta); frenar pegado a un patrullero (te arresta); quedarte quieto con patrulleros cerca (sube la barra). |
| Nivel de simulación | Empezar una carrera: pregunta el nivel (menos en la Aventura). En PERSONALIZADO: «Ángulo de dirección» (más/menos giro de las ruedas). La pausa de una copa o evento no trae OPCIONES ni taller; la de Carrera rápida sí. |
| Carreras del mapa | Circuito Centro / Puerto / Norte: lazos limpios, minimapa con sólo el circuito, mapa grande con la ciudad apagada. |
| Calidad automática | Primer arranque: ¿la recomendada es más alta que antes? Todos los teléfonos recalibran una vez (`Autotune.VERSION` 4). |
| Aventura | 5 etapas libres; daño de ruedas bajo; el daño vuelve a cero en cada etapa. |
| Menús | Textos que no se cortan; «Acerca de» con los 3 enlaces web (hay que verificar que abran: la página de GitHub Pages tiene que estar publicada). |

**Auto «Ren…»:** pendiente de que el dueño diga cuál es (no hay ninguno con ese nombre).

### 9 ter. Lo que se sumó después (20/10/2026, 2.º mensaje del dueño) — detalle en `docs/REGISTRO_TECNICO.md` → 20/10 11:00

| Qué | Para mirar en el teléfono |
|---|---|
| El modo desarrollador y «COPIAR REGISTRO» existen sólo en la RC | En la RC (el APK ya instalado recibe el cambio solo, sin reinstalar): Acerca de → la versión es un botón (siete toques = modo desarrollador) y «COPIAR REGISTRO» está en Acerca de y en Opciones → Sonido. **En la versión pública (main / Play) no hay nada de eso.** |
| Práctica de la Ruta de los Sueños desde Carrera rápida | Terminá una etapa en práctica y mirá en AVENTURA que el avance (etapa, puntos, habilidades) quede como estaba; en la estación dice «práctica: no se guarda». |
| El nombre del jugador viaja con la cuenta | Con la misma cuenta en otro celular: MODO ONLINE ya no pide el nombre (si el nombre de la cuenta nunca llegó al servidor, la primera vez lo pide). |
| Las monedas en otro celular | Contame qué número ves en cada celular y si en el primero estaba el modo desarrollador: con el modo desarrollador los créditos son del teléfono (en «Tu cuenta» ahora lo dice). |

## 10. Antes de publicar (pasos manuales, en orden)

1. Probar el RC en el teléfono (sección 9) y en uno más, si hay.
2. Autorizar y aplicar las migraciones 20261022 → 20261023 → 20261024 (sección 6) y mirar que el flujo salga en verde.
3. Fusionar la rama a `main` (con autorización) y deshacer los 4 cambios del RC (sección 2).
4. Armar el AAB con «Build Play Store AAB» y subirlo a una **prueba interna** de Play.
5. En Play Console:
   - crear los 10 productos con los ID de la sección 5 y sus precios;
   - crear el secreto `GOOGLE_PLAY_SERVICE_ACCOUNT` y correr «Supabase · publicar funciones»;
   - en Supabase: «Allow anonymous sign-ins» apagado, y SMTP propio o «Confirm email» apagado;
   - en Supabase → Realtime → «Allow public access» = OFF;
   - completar Seguridad de los datos (`docs/PLAY_SEGURIDAD_DATOS.md`);
   - crear la cuenta de revisión (Acceso a la app) con saldo (`account_admin_grant`).
6. Probar una compra real de cada tipo en la prueba interna, y «Restaurar compras» después de reinstalar.
7. Prender `caza_inicial` (sección 6) recién cuando la versión nueva sea la que está en Play.

## 11. Después de publicar (primera semana)

- Mirar el flujo «Supabase · uso y costos»: llamadas por jugador y tamaño de la base.
- Revisar `account_earns` por cuentas que choquen los topes de premios todos los días: puede ser trampa.
- Mirar los cierres que manden los jugadores (lápidas en «COPIAR REGISTRO»).
- Ajustar desde el panel, sin APK nuevo:
  - los premios de los desafíos (`game_cfg` → `daily`);
  - los hitos (`wev_templates` → `temporada` → `params.hitos`);
  - el peso y las horas de las cacerías.
- Reembolsos: revisar a mano los pedidos devueltos en Play Console y sacar lo comprado si hace falta.
