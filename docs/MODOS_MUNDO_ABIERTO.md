# Modos del mundo abierto contra la IA (15/10/2026)

Pedido del dueño: «un modo persecución: la policía le sigue a un jugador que anda muy loco por el centro (choca paredes, rompe farolas) y tiene que huir»;
«caza recompensas: una IA anda por el mapa, hay que pegarse a ella 30 s o un minuto y ese auto es tuyo; y la policía te puede perseguir si andás como loco».
Sirven aunque el online no ande: son partidas contra la IA en Dream City y la región.

## Desmadre (siempre, en todo el mundo abierto) — `game/city/city_police.gd`
- Medidor `rage` (0–1): choque fuerte contra una pared (+0,04 a +0,3 según el golpe), contra otro auto (+0,03 a +0,2), cada objeto roto (farola, cartel, semáforo: +0,12)
  y andar a más de 110 km/h dentro de la ciudad (a 170 km/h se llena en ~10 s). Manejando tranquilo 4 s empieza a vaciarse (75 s de lleno a cero).
- Avisa al 50 % («👮 La policía te está mirando») y al 80 % («¡Último aviso!»); desde el 30 % se ve la barra arriba al centro.
- Lleno: arranca una cacería donde estés (la misma persecución de los controles: patrulleros que llegan de atrás, interceptor, arresto, multa y comisaría).
  Nivel = pueblos cruzados + 1 si estás en la ciudad (+ la racha del modo Fugitivo), tope 3.
- Los choques los avisa `race.gd` (`police.on_wall`, `police.on_car_hit`); los objetos rotos se cuentan con `track.broken`.

## Modo FUGITIVO — `game/city/city_modes.gd`
- Pausa → «🚨 MODO FUGITIVO» (otra vez para terminarlo). No está en el mundo online.
- El desmadre cuenta el doble, se vacía más lento y además sube solo (la cacería llega igual en ~90 s aunque manejes bien).
- Cada escape paga `1.500 + 1.000 × nivel + 20 por segundo de persecución` (tope 300 s) y sube el nivel de la próxima (racha). Si te agarran, se corta la racha.

## RECOMPENSA (evento del servidor, un solo ganador) — `game/city/city_modes.gd` · actualizado 15/10/2026 noche
Pedido del dueño: «como un eclipse: todos lo esperan; aparece un rato en el mapa, hay que ir y pegarse; es muy difícil, la IA es súper inteligente y
rápida; a la mitad de la barra se hace la boluda; casi nunca choca; gana UNO solo, el que se mantiene pegado lo que da el servidor (un minuto)».
- El servidor programa la recompensa (`bounty_current`): el auto, la hora, `hold_s` (60 s), `map_s` (45 s) y una semilla. Es la misma para todos.
- Diez minutos antes avisa; a la hora, el auto aparece en el frente de uno de los locales de Dream City (sale de la semilla: el mismo para todos) y se ve en
  el mapa/GPS `map_s` segundos. El jugador queda anotado (`bounty_join`).
- Pegado a menos de 20 m la barra se llena en verde (1 por segundo); lejos baja 0,35 por segundo. Completa → `bounty_claim` con el recorrido.
- El que huye: potencia ×1,15, agarre ×1,12, ritmo 1,12, sin errores; rehace el camino para el otro lado cada 3 s si lo tenés a menos de 140 m; al 45 % y al
  78 % de la barra afloja 3,5 s («se hace el boludo»).
- Gana el PRIMERO: el servidor le pone el auto en la cuenta (o la mitad del precio si ya lo tenía). A los demás: «X se llevó el …» y el auto se va.
- Pausa → «🎯 RECOMPENSA»: cuándo es la próxima y qué auto. Necesita conexión y cuenta.
- El camino viejo (un auto por día con `give_car` «bounty») quedó cerrado en el servidor.
- Cómo programarla, configurarla y revisar ganadores: `docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md`.

## Pruebas
`tests/city_modes_test.gd` (en la compilación): reglas, el desmadre que arranca la cacería, Fugitivo (paga y sube el nivel) y la recompensa con un servidor falso
en memoria (espera, se suelta donde dice la semilla, huye, pegado → reclamo con recorrido, gana; si la gana otro, se va). La sintaxis de las migraciones se
revisó con `pglast` (sin levantar la base, pedido del dueño).

## Pendiente
- Probar en el teléfono: ¿el desmadre es justo?, ¿el que huye es difícil pero no imposible?, ¿60 s está bien?, ¿se ve bien en el mapa los 45 s?
- Textos sólo en español.
