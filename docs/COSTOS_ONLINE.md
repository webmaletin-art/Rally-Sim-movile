# Costos y límites del modo online (Supabase)

Medido el 15/10/2026 con la prueba de 2 teléfonos del dueño (registros del proyecto, flujo «Supabase · uso y costos» → `tools/online/supabase_usage.py`, sólo lectura; en el plan gratis los registros duran 1 día). Precios y topes de supabase.com/pricing y supabase.com/docs/guides/realtime/limits (consultados el 15/10/2026).

## Cómo habla el juego con el servidor (por jugador en el mundo online)
| Qué | Cada cuánto | Para qué |
|---|---|---|
| `presence_beat` (HTTP) | 2 s | «estoy acá»: posición, velocidad, auto. Escribe en `presence` (una fila por jugador) y en `presence_trail` (últimos 10 min, para los reportes) |
| `presence_list_v` (HTTP) | 2 s | la lista de conectados con nombre y modelo. **Hoy trae a TODOS los conectados del mundo** (hasta 60), no sólo a los cercanos |
| `chat_fetch` (HTTP) | 12 s (3 s con el chat abierto) | mensajes nuevos |
| `world_join` (HTTP) | 2 min | la hora y el clima del mundo compartido |
| `account_apply` (HTTP) | ≥ 12 s, sólo si hubo premios/gastos | la economía de la cuenta |
| Realtime (WebSocket) | 1 conexión; latido cada 25 s | posiciones en vivo por celdas de 2 km (`world_sync.gd`) |
| Realtime: posición | solo en la celda: 1 cada 10 s · con 2–3 jugadores: 5 por s · 5: 3 por s · 10: 0,7 por s · 11 o más: 0,5 por s; quieto: 1 cada 5 s | cada mensaje llega a todos los de la celda |

**Medido:** 58–63 llamadas HTTP por minuto por jugador (≈ 1 por segundo); 2 jugadores = 123–128 por minuto. En 24 h: 2.084 llamadas, ~32 jugador-minutos. Reparto: `presence_beat` 37 %, `presence_list_v` 35 %, `online_state` 8 %, `online_set_paint` 6 % (era el error de la pintura en el concesionario: arreglado el 15/10), `chat_fetch` 6 %. Base de datos: 13 MB de 500 MB. Realtime: 7 conexiones. Costo de la prueba: **$0** (todo dentro del plan gratis). Los registros NO traen la cantidad de mensajes de Realtime: se ve en el panel de Supabase → Usage → Realtime Messages.

## Dos jugadores lejos
Cada uno manda su posición sólo a su celda de 2 km; si está solo manda 1 mensaje cada 10 s y no recibe nada del otro (no se cobran entregas). En el servidor los dos figuran en `presence` (una fila cada uno, «conectado» si avisó en los últimos 45 s). Hoy igual se bajan la lista completa cada 2 s por HTTP (aparecen en la lista de jugadores; los autos se dibujan sólo a menos de 700 m).

## Planes (oct/2026)
| | Gratis | Pro ($25/mes) | Pro sin tope de gasto |
|---|---|---|---|
| Conexiones Realtime a la vez | 200 | 500 (+$10 c/1000) | 10.000 |
| Mensajes Realtime por segundo | 100 | 500 | 2.500 |
| Mensajes Realtime por mes | 2 M | 5 M (+$2,50 c/millón) | ídem |
| Tráfico de salida (egress) | 5 GB | 250 GB (+$0,09/GB) | ídem |
| Base de datos | 500 MB | 8 GB | ídem |
| Usuarios activos por mes | 50.000 | 100.000 | ídem |
| Otros | se pausa tras 1 semana sin uso | no se pausa; crédito para una instancia Micro | |
Las llamadas HTTP no se cobran por cantidad: el tope es la máquina de la base (Micro alcanza para ~50 jugadores a la vez a 1 llamada/s cada uno; con ~200 conviene «Small»).
**Cómo se cobra Realtime:** cada mensaje cuenta 1 al mandarse + 1 por cada jugador que lo recibe.

## Cuentas (peor caso: siempre acompañado y moviéndose)
| Jugadores en la misma celda | Mensajes por s (celda) | Mensajes por jugador-hora |
|---|---|---|
| 1 (solo) | 0,1 | 360 |
| 2 | 20 | 36.000 |
| 5 | 75 | 54.000 |
| 10 | 67 | 24.000 |
| 20 | 200 | 36.000 |
Egress por jugador-hora (hoy, por la lista completa cada 2 s): 3,7 MB con 2 conectados, 40 MB con 50, 153 MB con 200 (crece con la cantidad de conectados).

| Jugador-horas por mes | Mensajes | Costo Realtime en Pro (además de los $25) |
|---|---|---|
| 100 | 3 M | $0 |
| 1.000 (≈ 33 por día) | 30 M | ≈ $62 |
| 5.000 (≈ 170 por día) | 150 M | ≈ $362 |
| 20.000 | 600 M | ≈ $1.490 |
Con el plan gratis el juego se corta en cuanto haya 2 celdas con grupos (100 mensajes/s) o 200 conectados, y el proyecto se pausa si nadie juega una semana: **para publicar hace falta Pro**.

## Recomendación
1. **Quedarse con Supabase y pasar a Pro** antes de publicar, con el tope de gasto prendido.
2. **Bajar el gasto antes de crecer** (cambios chicos, ninguno toca la economía):
   - `presence_list_v` sólo con los cercanos y cada 10 s con Realtime prendido → egress 1–2 MB por jugador-hora fijo (hoy crece con los conectados).
   - Realtime: presupuesto 60 → 20 entregas/s por celda y máximo 5 → 3 por s (el movimiento se interpola igual) → ~60 % menos mensajes (≈ $17 en vez de $62 a 1.000 jugador-horas).
   - `presence_beat` cada 5 s con Realtime prendido (la posición ya viaja por Realtime).
3. **Servidor propio** (Nakama o Colyseus en un VPS de $10–40/mes, mensajes sin cargo) recién si pasa de ~5.000 jugador-horas por mes; las cuentas y la economía siguen en Supabase.

---

# Online fluido (rama experimental `exp/online-fluido`, 15/10/2026)

Pedido del dueño (prompt maestro «optimización del online, fluidez multijugador y costos»): que los autos de los demás se muevan fluido, sin saltos ni fantasmas, y con el costo medido. **Rama aparte, NO fusionada a `main`.** APK aparte: release `godot-apk-online-prueba` → `DreamRacing-ONLINE-PRUEBA.apk` («Dream Racing ONLINE PRUEBA», `com.gskorp.rallygodot.online`, se instala al lado del normal); contenido en `godot-content-4.7-online` (los autos se reusan de `godot-content-4.7`).

## Diagnóstico inicial (código de `main` al 15/10/2026)
| Mecanismo | Cómo | Frecuencia | Destinatarios | Tamaño aprox. |
|---|---|---|---|---|
| Posición en vivo | Realtime **Broadcast** a la celda de 2 km (`world_sync.gd`) | 5/s con 2–3 en la celda, 3/s con 5, 0,67/s con 10, 0,5/s con 20+; quieto 0,2/s; solo 0,1/s | todos los de la celda | ~110 B |
| Presencia del canal | Realtime **Presence** (track al entrar) | al entrar | todos los de la celda | ~80 B |
| Latido del socket | Phoenix heartbeat | 25 s | servidor | ~60 B |
| `presence_beat` | HTTP RPC (escribe `presence` + `presence_trail`) | 2 s | servidor | ~250 B |
| `presence_list_v` | HTTP RPC | 2 s | — | ~420 B **por cada conectado del mundo** (hasta 60) |
| `chat_fetch` | HTTP RPC | 12 s (3 s con el chat abierto) | — | chico |
| `world_join` (hora y clima) | HTTP RPC | 2 min | — | chico |
| Economía (garaje, compras) | HTTP RPC | al usar un local | — | — |
No se usa Postgres Changes. Lo que cobra Supabase por mensaje es SÓLO Realtime (Broadcast/Presence: 1 al mandarse + 1 por cada receptor); las llamadas HTTP no se cobran por cantidad (pesan en la máquina de la base y en el tráfico de salida).

**Problemas encontrados en el código:**
1. El auto remoto se estimaba con la HORA DE LLEGADA de cada mensaje: la demora irregular de la red se veía como tirones (hasta 0,5–0,9 m por cuadro en la prueba) y el auto quedaba ~2 m atrás en una red tipo 4G.
2. Un auto recién llegado no se dibujaba hasta que la lista HTTP lo traía (hasta 2 s), aunque ya llegaran sus posiciones en vivo.
3. Si la lista HTTP fallaba (sin respuesta), **desaparecían todos los autos** hasta la siguiente.
4. El que cerraba el juego quedaba como **fantasma** hasta 45 s (la presencia del servidor dura 45 s y la lista lo volvía a poner, quieto).
5. Un jugador quieto avisa cada 5 s y se daba de baja a los 5 s: titilaba.
6. Un canal que el servidor cerraba (`phx_close`) quedaba muerto hasta salir de la celda.
7. Al volver a entrar al mundo el número de mensaje volvía a 1 (con el código nuevo de descarte de repetidos eso habría silenciado al jugador ~10 s: se evitó de entrada).
8. La lista HTTP trae a todos los conectados del mundo cada 2 s (crece con la cantidad de jugadores) aunque las posiciones ya lleguen en vivo.

## Cambios (archivos y funciones)
- `game/online/net_tuning.gd` (nuevo): TODOS los ritmos y umbrales en un lugar.
- `game/online/remote_motion.gd`: **búfer de muestras con hora** (`push_sample(p, yaw, v, t, arrival)`), interpolación de Hermite entre muestras reales con rumbo tangente y giro por el lado corto (±180°), dibujo `delay` s en el pasado (se adapta a cada cuánto llegan y cuánto varía la red, cambia de a poco) **y proyectado al presente** con la velocidad y el giro filtrados (`LEAD_MAX` 0,9 s), extrapolación acotada si se cortan las muestras (sigue un rato y frena sola), correcciones absorbidas de a poco (`ERR_RATE`) y reubicación sólo si el error pasa `SNAP_ERR` 12 m o hay un salto de 60 m (`resyncs`); descarta repetidas/desordenadas (`dropped`). Con pocas muestras (< 1,7/s, o la lista HTTP) sigue la estimación de antes.
- `game/online/world_sync.gd`: cada mensaje lleva la **hora del que manda** (`t`, compatible con clientes viejos); el que recibe la pasa a su reloj (desfase mínimo − la ida y vuelta mínima del latido = demora de la red); descarta repetidos/desordenados por número de mensaje (que ahora arranca de la hora: siempre crece); **ritmo por distancia**: solo 0,2/s, otros en la celda pero a más de 900 m 1/s, con alguien cerca `40/(k·(k−1))` entre 1 y 4 por s (0,5 con más de 12 en la celda), quieto 0,25/s, y un envío extra al doblar fuerte (15°) o frenar/acelerar fuerte (20 km/h); baja por silencio a los 9 s o **por la presencia del canal** a los 2 s (cerró el juego); fase al azar para no mandar todos juntos; `healthy()`, `rates`, `near_d`, más estadísticas.
- `game/online/realtime.gd`: un canal cerrado por el servidor se vuelve a pedir; reconexión con azar (no vuelven todos juntos); primer latido a los 3 s y `rtt_min_ms`; `joined_for()`.
- `game/online/remote_cars.gd`: aparece con el primer dato en vivo (y pide la lista enseguida para el nombre/modelo); una lista fallida no borra a nadie; el que manda en vivo sigue aunque la lista no lo traiga; se muestra a < 700 m y se saca a > 820 m (histéresis); el que se va se saca ya y la lista no lo vuelve a poner por 60 s salvo que se mueva (sin fantasmas); con Realtime andando la lista se pide cada 8 s (cada 2 s si algún auto cercano no manda en vivo: cliente viejo); `net_info()` y `stats`.
- `game/online/online_social.gd`: `players_safe()` ({ok, list}); aviso al servidor cada 5 s con Realtime andando (2 s sin él).
- `game/race.gd`: pasa el estado de Realtime a la lista y al aviso; línea de **datos de red** debajo de los FPS (Opciones → Gráficos → «Mostrar datos de red», con «Mostrar FPS»): estado, latido, mandados/recibidos por s, ritmo, descartados, reconexiones, bajas, distancia al más cercano, autos (en vivo), búfer, atraso, edad de la última muestra, resincronizaciones, cada cuánto se pide la lista y el aviso, fallas de la lista. No pide nada al servidor.
- `tools/online/mock_realtime.py`: `--lag` y `--jitter` (red «de teléfono» para las pruebas).
- Sin migraciones de Supabase, sin cambios de permisos, RLS, claves, economía, chat, garaje ni física local.

## Mediciones (PC, `tests/net_load_test.gd`: N clientes reales del protocolo contra el servidor de mentira, manejando en círculos en la misma celda)
Antes = el mismo test contra el código de `main`. Error = distancia entre el auto dibujado y el real AHORA. Salto = cuánto se aparta, en un cuadro, el paso dibujado del real.
| Escenario | Antes: msj/s cobrables | Ahora | Antes: error medio / salto máx | Ahora |
|---|---|---|---|---|
| 2 juntos, red local | 19 | **15** | 0,10 m / 0,01 m | 0,10 m / 0,07 m |
| 5 juntos, red local | 75 | **50** | 0,14 m / 0,01 m | 0,15 m / 0,11 m |
| 10 juntos, red local | 71 | 137 | 0,68 m / 0,30 m | **0,15 m / 0,12 m** |
| 20 juntos, red local | 229 | 203 | 1,59 m / 1,41 m | **1,11 m / 0,73 m** |
| 2 juntos, **red tipo 4G** (60 ms + hasta 120 ms al azar) | — | — | 2,13 m / 0,06 m | **0,35 m / 0,11 m** |
| 5 juntos, red tipo 4G | — | — | 2,81 m / 0,06 m | **0,88 m / 0,09 m** |
Otros resultados (ahora): nadie desaparece mientras maneja (0 bajas); al cruzar el borde de celda el otro lo sigue viendo (hueco máx 0,26 s); si uno cierra el juego de golpe el otro lo saca en ~1 s (antes: fantasma hasta 45 s por la lista); al volver a entrar al mundo se lo recibe enseguida; lista HTTP 4× menos seguida y aviso 2,5× menos seguido con Realtime andando (~0,35 en vez de ~1,06 llamadas HTTP/s por jugador, calculado).
**Lectura honesta:** en red perfecta el método viejo se ve igual de bien con 2–5 jugadores (el salto por cuadro nuevo, 0,07–0,11 m, es invisible a 60 FPS); la diferencia está en la red real (4–6 veces menos error) y con 10+ jugadores. Con 10 en una celda se cobran MÁS mensajes que antes (137 contra 71 por s) porque antes se mandaba 0,67 por s y se veía a saltos: se eligió fluidez. Las variaciones entre corridas son de ±20 %.

## Pruebas
- Ejecutadas y en verde: `remote_motion_test` (+ casos con hora de la muestra y 1 por s), `realtime_test` (ritmos nuevos, hora en el mensaje), `remote_cars_test` (+ 11 casos: aparece en vivo, lista fallida, histéresis, fantasmas, sin duplicados), `net_load_test` (nueva), `online_profile_test`, `scripts_parse_test`, `language_test`, `boot_download_test`.
- **No ejecutadas (necesitan teléfonos o la cuenta real):** dos teléfonos reales con Supabase, pérdida real de paquetes, cambio de wifi a 4G, app en segundo plano, consumo de datos del teléfono, FPS del teléfono con la línea de red, mensajes reales en el panel de Supabase. Los 2/5/10/20 son clientes simulados en una PC (protocolo real, red simulada).

## Probar con dos teléfonos
1. Instalar en los dos `DreamRacing-ONLINE-PRUEBA.apk` (release `godot-apk-online-prueba`). Se instala aparte; la primera vez baja el juego y los autos; hay que iniciar sesión (cuentas distintas) y calibrar.
2. Opciones → Gráficos → «Mostrar FPS» = Sí y «Mostrar datos de red» = Sí.
3. Entrar los dos al mundo online cerca (mismo estacionamiento). Mirar la línea RED: «● en vivo», «autos 1 (1 en vivo)», «env ~4/s», «edad» < 0,5 s, «resinc» que casi no suba.
4. Manejar juntos: aceleraciones, frenadas, curvas, adelantamientos; uno quieto y el otro dando vueltas; alejarse a más de 1 km y volver; cruzar un borde de celda (cada 2 km); uno cierra la app de golpe (el otro tiene que dejar de verlo en ~2 s); volver a entrar; apagar y prender los datos.
5. Chat, garaje online, concesionario y talleres: que sigan andando.
6. Mandar captura de la línea RED en los dos teléfonos y, en Supabase → Usage, «Realtime Messages» antes y después de la prueba (anotar minutos jugados).

## Riesgos pendientes
- La demora se estima con la ida y vuelta del latido (supone que los dos tienen una red parecida); si uno está en wifi y el otro en 4G, el auto puede verse unos decímetros adelantado/atrasado.
- Con 10–12 jugadores juntos en una celda se cobran ~2× mensajes que antes (fluidez); con más de 12 baja a 0,5 por s (se ve menos fluido, como antes).
- La lista HTTP todavía trae a todos los conectados (con Realtime andando, cada 8 s en vez de 2): con cientos de jugadores conviene una función `presence_near` en el servidor (migración; NO hecha, para no tocar producción desde una rama).
- `presence_trail` sigue guardando cada aviso (ahora cada 5 s con Realtime).

## Cuándo pasar a Pro / alertas
Seguir con el plan gratis mientras sea una prueba (2–5 jugadores: 15–50 msj/s, muy por debajo de 100/s y de 2 M/mes en pocas horas). Pasar a Pro **antes de publicar** (el gratis se pausa a la semana sin uso y corta con 2 celdas llenas). En Pro conviene tope de gasto prendido y alertas de uso al 70 % y 85 % (Supabase → Organization → Billing/Usage; no se puede configurar desde acá). Servidor de juego propio sólo si las mediciones con jugadores reales pasan ~5.000 jugador-horas por mes.

## Volver atrás
Es una rama aparte: con no fusionarla, `main` y el APK normal quedan como estaban. Para sacar sólo una parte: `git revert` del commit correspondiente en la rama. La app de prueba se desinstala sola («Dream Racing ONLINE PRUEBA»).
