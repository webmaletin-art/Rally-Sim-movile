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

## Modo CAZA RECOMPENSAS — `game/city/city_modes.gd`
- Pausa → «🎯 CAZA RECOMPENSAS». Aparece un auto de la IA a 400–700 m (prefiere uno que no tengas), con 🎯 arriba y en el GPS/minimapa.
- Huye por las calles: va lejos (1,2–3 km) y, si lo tenés a menos de 140 m, rehace el camino para el otro lado cada 3 s.
- Hay que estar a menos de 22 m durante **30 s en total** (alejarse lo descuenta despacio). Se escapa si queda a más de 2,5 km 25 s seguidos o pasan 12 minutos.
  Si te arresta la policía (desmadre), también se termina.
- Premio: **el auto** (va al garaje) si no lo tenías y no ganaste otro en las últimas 24 h; si no, el 25 % de su precio en créditos.
- Autos que pueden andar sueltos: los del catálogo hasta $150.000, nunca los premium (truck, gt3, hyper), el premio de la aventura (genesis) ni los especiales (police, f1, t1plus).
- **Servidor:** el auto ganado se anota con `give_car` motivo `bounty`; la cuenta lo valida con las mismas reglas y además UNO cada 20 h por cuenta
  (migración `supabase/migrations/20261018000000_bounty_car.sql`). Sin esa migración aplicada el servidor lo rechaza y el auto desaparece al sincronizar.

## Pruebas
`tests/city_modes_test.gd` (en la compilación): reglas, el desmadre que arranca la cacería, Fugitivo (paga y sube el nivel), Caza (aparece, anda, pegado 30 s →
el auto con motivo «bounty», se va; lejos 25 s → se escapa). La sintaxis de la migración se revisó con `pglast` (sin levantar la base, pedido del dueño).

## Pendiente
- Probar en el teléfono: ¿el desmadre es justo (ni muy fácil ni imposible)?, ¿el que huye maneja bien y se escapa a veces?, ¿30 s está bien o mejor 60?
- Textos sólo en español.
