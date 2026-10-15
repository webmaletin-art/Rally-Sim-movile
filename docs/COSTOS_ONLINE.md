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
