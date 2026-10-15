# Guía: eventos en vivo, ranking y cómo habilitar el tiempo real

Todo se maneja desde el panel de Supabase (supabase.com → tu proyecto). Para nada de esto hace falta un APK nuevo.
Migraciones:
- `20261019000000_bounty_event_ranking_flags.sql`: el interruptor `app_flags` y el ranking.
- `20261020000000_world_events.sql`: el gestor de eventos.

Las dos ya están aplicadas (15/10/2026 17:28 UTC, flujo «Supabase · aplicar migraciones» n.º 32). Qué es y cómo se juega: `docs/ONLINE_POR_EVENTOS.md`.

## 1. El online hoy: por eventos (sin tiempo real)
Cada jugador juega en su mundo: no se encuentran, no hay chat ni «quién está conectado». El servidor se usa sólo para:
- la cuenta, los créditos y los autos;
- los eventos y sus premios;
- el ranking.

Cero mensajes de Realtime.

## 2. Habilitar el tiempo real (cuando pagues Supabase Pro) — UN BOTÓN
1. Supabase → **Table Editor** → tabla **`app_flags`** → fila **`pvp`** → columna **`val`** → **true** → Save.
2. Listo: la próxima vez que un jugador abra MODO ONLINE aparece «ENTRAR AL MUNDO ONLINE» (Realtime, chat, conectados, mercado). Los eventos siguen.
3. Para volver a apagarlo: `val` = false.

Antes de habilitarlo: Realtime → Settings → «Allow public access» = OFF, y mirar los topes del plan (`docs/COSTOS_ONLINE.md`).

## 3. Los EVENTOS (el servidor es el gestor)
El servidor mantiene programados hasta `max_open` eventos (4) a partir de las **plantillas**. Los elige al azar según su peso, respeta el descanso de cada una
y pone a su hora las de hora fija. Los avisa con anticipación, cuenta los intentos, valida los tiempos, da los premios y publica los ganadores.

### Plantillas (Table Editor → `wev_templates`)
| columna | qué es |
|---|---|
| `kind` | `bounty` (cazarrecompensas) · `escape` (fuga) · `reach` (contrarreloj a una ciudad) · `record` (carrera de la semana) |
| `title` / `descr` | lo que lee el jugador |
| `weight` | más alto = sale más seguido |
| `params` | bounty: `{"n": autos a la vez, "pool": [autos posibles], "hold_s": 60, "map_s": 45}` · escape: `{"chase_s": 600}` · reach: `{"speed": 24, "time_max": 1800}` (tiempo = distancia × 1,25 / speed) · record: `{}` |
| `reward` | `{"credits": 20000}` · `{"car": true}` (el auto atrapado) · `{"rent": "police", "days": 3}` (alquilado) · `{"top": [25000, 12000, 6000]}` (3 primeros) |
| `duration_min` | cuánto dura abierto |
| `attempts` | intentos por jugador (0 = sin límite) |
| `max_winners` | cupo de ganadores (0 = todos los que cumplan; en la cacería, uno por auto) |
| `notice_min` | cuántos minutos antes se anuncia |
| `cooldown_h` | no se repite antes de tantas horas |
| `hours_utc` | horas fijas en UTC (Argentina = UTC − 3: las 22 h son `{1}`); vacío = a cualquier hora |
| `enabled` | apagarla sin borrarla |

Las de fábrica son `caza_22`, `caza_tarde`, `fuga_10` (Interceptor por 3 días), `fuga_5`, `llegada` y `carrera_semana`. Para agregar otra, copiá una fila y cambiá el `id`.
Ideas: «fuga de 15 min → STRIX por 2 días»; una cacería de un solo auto muy caro el sábado a las 21 (`hours_utc` = `{0}`).

### Configuración general (Table Editor → `wev_cfg`)
- `auto`: el servidor programa solo (true/false).
- `max_open`: eventos a la vez.
- `bounty_cooldown_d`: días entre dos autos de cacería del mismo jugador.

### Programar uno a mano (para un anuncio)
SQL Editor:
```sql
select public.event_admin_schedule('caza_22', now() + interval '30 minutes');
-- o a una hora fija de Argentina:
select public.event_admin_schedule('fuga_10', '2026-10-18 21:00:00-03'::timestamptz);
```
- Ver los programados y los que ya pasaron: `wev_events`.
- Cancelar uno que todavía no empezó: borrar su fila.
- Ganadores: `wev_winners`. Intentos: `wev_runs`.

### Autos alquilados
Un premio `rent` pone el auto en la cuenta con fecha de vencimiento (`until` dentro de `account_econ.cars`). El servidor lo borra solo al vencer y el juego lo saca del
garaje en la sincronización siguiente. Si el jugador ya tenía ese auto para siempre, no pasa nada.

### Revisar un ganador sospechoso
- `wev_runs` guarda cada intento: hora de inicio y de fin, el valor (segundos o barra) y, en la cacería, el recorrido (`trace`: cada segundo `[segundo, x jugador, z jugador, x auto, z auto, barra]`).
- Un ganador «real» tiene la distancia jugador–auto chica mientras sube la barra, y posiciones que avanzan a velocidades de auto.
- Si hubo trampa: borrar su fila en `wev_winners` y sacarle el premio en `account_econ` (créditos o el auto en `cars`).

**Límite honesto:** el servidor no ve la carrera (cada uno juega en su celular). Se protege con la hora de inicio de cada intento, los cupos y topes, y el recorrido guardado.

## 4. El RANKING
- **Carreras del mapa:** el cartel de cada carrera muestra el récord mundial y tu mejor tiempo. Al terminarla, el juego avisa tu puesto o «¡NUEVO RÉCORD MUNDIAL!».
  Tablero `owev` en la tabla `scores`.
- **Escapes:** la mejor racha de escapes de la policía, tablero `fugitive`.
- **Ganadores de los eventos:** `wev_winners`.
- Menú → MODO ONLINE → RANKING. El jugador puede dejar de mandar sus récords con MIS RÉCORDS.
