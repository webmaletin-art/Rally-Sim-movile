# Eventos del mundo y la policía (15/10/2026)

**Pedidos del dueño:**
- «El online, hasta pagar Supabase Pro, es de eventos de clasificación: cada uno juega en su mapa contra la IA y sus registros se suben para competir.
  No son modos a elegir en la pausa: el servidor manda los eventos.»
- «Los eventos no son ajenos entre sí: si me escapo y paso por un control, el control también me sigue; si mi presa pasa un control, la policía me sigue a mí.»

Texto para el dueño: `docs/ONLINE_POR_EVENTOS.md`. Guía del panel: `docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md`.

## La policía (siempre) — `game/city/city_police.gd`
- **Desmadre:** un medidor `rage` (0–1) que se llena así:
  - choque fuerte contra una pared: +0,04 a +0,3;
  - choque contra otro auto: +0,03 a +0,2;
  - cada objeto roto: +0,12;
  - más de 110 km/h dentro de la ciudad.

  Avisa al 50 % y al 80 %. Lleno, arranca una persecución donde estés. Manejando tranquilo se vacía en 75 s.
- **Controles en las rutas:** como siempre. Además, **durante una persecución, si pasás por otro control, sus patrulleros se suman** (2, tope 7 en total;
  `checkpoint_near`, `_join_checkpoint`).
- **Cada escape paga:** 1.500 + 1.000 × nivel + $20 por segundo de persecución (tope 300 s). La mejor racha de escapes va al ranking (tablero `fugitive`).

## Eventos del mundo — `game/city/city_modes.gd` (servicio `race.modes`)
Pregunta al servidor `events_current` cada 90 s (cada 15 s si hay uno en vivo o por empezar). Los muestra con un cartel grande cuando faltan menos de 30 min
y al empezar, y con un renglón arriba (debajo del velocímetro y del cartel de la policía). Anuncia a los ganadores nuevos («📢 X ganó …»).
La pausa tiene un solo botón: «📅 EVENTOS EN VIVO», un resumen. Ya no hay modos Fugitivo ni Recompensa para elegir.
Sin conexión o sin cuenta no hay eventos; el resto del juego anda igual.

| tipo | qué hace el juego | qué valida el servidor (`event_start` / `event_finish`) |
|---|---|---|
| `bounty` cazarrecompensas | a la hora suelta los N autos (lugar = semilla + n.º, el mismo para todos), 45 s en el mapa, barra por auto (pegado < 20 m sube 1/s, lejos baja 0,35/s), la IA rápida y sin errores que se hace la boluda al 45 % y 78 %; si la presa pasa un control y estás a < 450 m, la policía te persigue; el intento se anota al acercarte a < 300 m | ≥ hold_s + 5 s desde el inicio del intento; uno por auto (el primero); uno por jugador y evento; un auto de cacería cada 7 días |
| `escape` fuga | cualquier persecución anota un intento; al terminar, si escapaste y duró ≥ chase_s, reclama | el aguante declarado ≤ el tiempo real desde el inicio + 10 s y ≥ chase_s; intentos |
| `reach` contrarreloj | la ciudad (10–30 km de Dream City) y la salida más cercana salen de la semilla; frenar en el círculo (largada), llegar a < 250 m antes de `distancia × 1,25 / speed` | 60 s ≤ tiempo ≤ time_max y ≤ tiempo real; intentos (3) |
| `record` carrera de la semana | una carrera del mundo abierto (semilla), su cartel dice 🏆; al largarla se anota el intento y al terminar se manda el tiempo | 8 s ≤ tiempo ≤ 1 h y ≤ tiempo real; al cerrar, premios a los 3 primeros |
| `drift` desafío de drift | al entrar a la Plaza de Drift con el desafío en vivo arranca una sesión de `run_s` s (puntos = lo cobrado + el derrape en curso, `city_drift.gd`); al terminar se manda; para otro intento hay que salir y volver a entrar | la sesión dura `run_s` (− 5 s) y ≤ `cap_rate` puntos/s; al cerrar, premios por puesto (más puntos gana) |
| `season` temporada | no se juega sola: cada evento cumplido avisa «🏅 ¡Suma para la temporada!»; el tablero muestra tus puntos y tu puesto | `_wev_season_rows`: cada evento cumplido en la semana suma `pts[tipo]`, ganarlo suma otra vez; al cerrar, premios por puesto |

- **Premios:** `_wev_grant` en el servidor: créditos (tope 200.000 por premio), **vale de taller** (`account_econ.voucher`, mismo tope), el auto atrapado o un auto
  puntual (si ya lo tenía, la mitad del precio), un auto alquilado (`until` en `account_econ.cars`, se borra solo al vencer; el juego lo marca en `owned[id].until`),
  un **diseño** para todos los autos (`skin`) o un juego de **gomas** para todos los autos (`tires`). Por puesto (`top`): número = créditos, objeto = cualquiera de esos.
- **Vale de taller:** `profile.gd` (`voucher`, `can_shop`, `_take_shop`: mejoras, gomas, cambio de gomas, piezas, diseños y el gasto «tune») lo usa antes que los
  créditos y lo anota como «v» en el evento de la cuenta; el servidor hace lo mismo con un envoltorio de `_acct_one` (la de siempre quedó como `_acct_one_base`).
  `account_econ.gd` (reconcile) trae el vale del servidor. Se ve en la barra de arriba del menú («🔧 $…»). En el modo online no hay vale.
- **Varias fugas a la vez:** una persecución abre un intento en cada fuga en vivo y al terminar cierra todos.
- **Cada carrera del mapa:** su cartel muestra el récord mundial y tu mejor tiempo (`city_events._fetch_record`); al terminarla, el puesto o «¡NUEVO RÉCORD MUNDIAL!».

## Pruebas
`tests/city_modes_test.gd` (en la compilación), con un servidor falso en memoria:
- el desmadre;
- el control que se suma a la persecución;
- el pago por escape;
- la cacería con 2 autos (se sueltan donde dice la semilla, huyen, pegado → reclamo con recorrido; otro gana uno → se va);
- la fuga (intento al empezar la persecución, reclamo al escapar);
- el contrarreloj (largada en el círculo, llegada);
- dos fugas a la vez (una se cumple, la otra no);
- el desafío de drift (empieza al entrar, manda los puntos con el derrape en curso, otro intento sólo saliendo y volviendo);
- los textos de los premios por puesto, el vale, el diseño y la temporada.

`tests/account_econ_test.gd`: el vale (reconcile, compras del taller primero con el vale, la nafta no, el reglaje sí).

La sintaxis de las migraciones se revisó con `pglast`. La migración trae una autoprueba que programa los eventos al aplicarse.

## Pendiente
- Probar en el teléfono:
  - ¿la cacería es difícil pero posible?
  - ¿60 s de barra está bien?
  - ¿se ven bien los avisos?
  - ¿los eventos están bien espaciados?
- Textos sólo en español.
- Cuando haya tiempo real (`app_flags.pvp`), la cacería podría ser compartida (todos ven el mismo auto).
