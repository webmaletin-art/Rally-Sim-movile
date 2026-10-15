# Guía: la RECOMPENSA, el ranking y cómo habilitar el tiempo real

Todo se maneja desde el panel de Supabase (supabase.com → tu proyecto). No hace falta un APK nuevo para nada de esto.
Migración que lo arma: `supabase/migrations/20261019000000_bounty_event_ranking_flags.sql` (se aplica con el flujo «Supabase · aplicar migraciones»).

## 1. El online hoy: «por datos» (sin tiempo real)
- Cada jugador juega en su mundo: **no se encuentran**, no hay chat ni «quién está conectado».
- El servidor se usa sólo para: iniciar sesión, los créditos, los autos y las compras, los récords (ranking) y la recompensa.
- En el menú, MODO ONLINE muestra: RANKING, RECOMPENSA, MIS RÉCORDS (si se mandan o no), CUENTA y «MUNDO ONLINE EN TIEMPO REAL» → pantalla «PRÓXIMAMENTE».
- Gasto: unas pocas llamadas por hora por jugador (la recompensa pregunta cada 2 min, cada 20 s cuando está por soltarse o suelta; un récord por carrera terminada).
  Cero mensajes de Realtime.

## 2. Habilitar el tiempo real (cuando pagues Supabase Pro) — UN BOTÓN
1. Supabase → **Table Editor** → tabla **`app_flags`** → fila **`pvp`** → columna **`val`** → marcar **true** → Save.
2. Listo: la próxima vez que un jugador abra MODO ONLINE, aparece el hub de siempre con «ENTRAR AL MUNDO ONLINE» (Realtime, chat, conectados, mercado).
3. Para volver a apagarlo: `val` = false.
(En el código: `Release.pvp_open()` = `REALTIME` y (`PVP_FORCE` o la bandera del servidor o modo desarrollador). Antes de habilitarlo: Realtime → Settings →
«Allow public access» = OFF y mirar los topes del plan; ver `docs/COSTOS_ONLINE.md`.)

## 3. La RECOMPENSA (un auto suelto, un solo ganador)
Cómo se juega: a la hora que dice el servidor se suelta el mismo auto para todos, en el mismo lugar de Dream City. Diez minutos antes avisa en el juego.
Al soltarse, durante `map_s` segundos se ve en el mapa dónde está; después hay que buscarlo. Pegado atrás (a menos de 20 m) la barra se llena en verde;
lejos baja despacio. **El primero que completa la barra (`hold_s`) se lo lleva** y el servidor le pone el auto en su cuenta (si ya lo tenía: la mitad de su
precio en créditos). A los demás se les va con el aviso «X se llevó el …». El que huye maneja muy bien: rápido, sin errores, dobla para el otro lado si lo
tenés encima y se hace el boludo un ratito al 45 % y al 78 % de la barra.

### Configurar (Table Editor → tabla `bounty_cfg`, columna `val`)
| clave | qué es | por defecto |
|---|---|---|
| `auto` | el servidor programa solo la próxima cuando no hay ninguna pendiente (`true`/`false`) | true |
| `every_h` | cada cuántas horas (aprox.) | 6 |
| `jitter_min` | demora al azar extra, en minutos (para que no sea siempre a la misma hora) | 90 |
| `hold_s` | segundos pegado para ganarla | 60 |
| `map_s` | segundos que se ve en el mapa al soltarse | 45 |
| `duration_min` | cuánto anda suelta si nadie la gana | 15 |
| `notice_min` | aviso previo en el juego, en minutos | 10 |
| `cars` | autos que pueden salir (ids separados por coma) | veltor_s,moust,veltor_gtr,strix,veltor,trilux_gt,kl5,pro_gt |
| `win_cooldown_d` | días que un ganador tiene que esperar para ganar otra | 7 |
Los cambios valen para la próxima que se programe.

### Publicar una a mano (por ejemplo, para un anuncio o un sábado a la noche)
SQL Editor → pegar y ejecutar (cambiar el auto, la hora y los segundos):
```sql
select public.bounty_admin_schedule('veltor_gtr', now() + interval '30 minutes', 60, 15);
-- auto, cuándo se suelta, segundos pegado, minutos que anda suelta
```
Para una hora fija (hora de Argentina): `'2026-10-18 21:00:00-03'::timestamptz` en vez de `now() + …`.
Ver las programadas y quién ganó: Table Editor → `bounty_events` (columnas `starts_at`, `car`, `winner_name`, `won_at`).
Cancelar una que todavía no salió: borrar su fila en `bounty_events`.

### Revisar un ganador sospechoso
`bounty_claims` guarda cada reclamo con el recorrido que mandó el juego (`trace`: cada segundo `[segundo, x jugador, z jugador, x auto, z auto, barra]`).
Un ganador «real» tiene la distancia jugador–auto chica durante la barra y posiciones que avanzan a velocidades de auto. Si alguien hizo trampa: en
`bounty_events` borrar `winner`/`winner_name` de esa fila (no le saca el auto: para eso, en `account_econ` quitarle el auto de `cars`).
**Límite honesto:** el servidor no ve la persecución (cada uno juega en su mundo); se protege con: tiene que haber «salido a buscarla» (`bounty_join`) y pasado
`hold_s` segundos desde entonces, uno por evento, uno cada `win_cooldown_d` días por cuenta, y el recorrido queda guardado para revisar.

## 4. El RANKING
- **Carreras del mundo abierto:** al terminar una, el juego manda el tiempo (`submit_record`, board `owev`) y avisa «🌍 Récord mundial: 1:23.4 de X · vos sos 5º»
  o «¡NUEVO RÉCORD MUNDIAL!». Menú → MODO ONLINE → RANKING → elegir la carrera.
- **Fugitivo:** la mejor racha de escapes (board `fugitive`).
- **Recompensa:** los últimos ganadores.
- Los tiempos se validan (entre 8 s y 1 h; rachas de 1 a 500) y hay tope de 40 envíos por hora por cuenta. Tabla `scores` (Table Editor) para mirar o borrar.
- Si un jugador no quiere aparecer: MODO ONLINE → MIS RÉCORDS (☐ no se mandan).
