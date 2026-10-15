# Dream Racing: cómo funciona el juego (resumen para el dueño)

*15/10/2026. El online por eventos está en `docs/ONLINE_POR_EVENTOS.md`; el panel de Supabase, en `docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md`.*

## La idea en una frase
Un juego de manejo de **mundo abierto** (Dream City y una región de ~2.700 km de rutas, montaña, pueblos y ciudades) donde **ganás plata manejando**,
**la gastás en tu garaje** (autos, mejoras, gomas, diseños) y **compitís contra todos** en eventos que manda el servidor y en tablas de récords.
Mientras no haya tiempo real, cada uno juega en su celular contra la IA y lo que hace se compara con los demás.

## El círculo del juego (por qué se vuelve a abrir)
1. **Manejás** en Dream City o en la región: carreras para descubrir, policía, eventos en vivo.
2. **Ganás**: créditos por carreras, escapes y eventos; autos de cacería; premios de temporada; el regalo diario.
3. **Gastás**: autos nuevos, mejoras, gomas (se gastan con los km), nafta, peajes, multas, diseños, interiores y volantes.
4. **Volvés** porque siempre hay un evento por empezar, una temporada en curso, un récord para bajar o un auto para cazar.

## Modos
| Modo | Qué es |
|---|---|
| **Dream City / región** | El mundo abierto. Acá pasa casi todo: carreras para descubrir, concesionarios, talleres, estaciones, peajes, policía y eventos en vivo. |
| **Aventura** | Copas por etapas contra la IA. Debut y Nacional libres; Continental y Leyenda con la compra «Aventura». |
| **Travesía X** | Convoy off-road de 30–40 min: seguirle el ritmo a los demás. |
| **Carrera rápida / Rutas / Drift / Picada** | Partidas sueltas: circuitos, la red de rutas con persecuciones, la plaza de drift y los 400 m. |
| **Modo online** | Hoy, eventos y ranking (sin encontrarse). El 1/11, con Supabase Pro, se prende el mundo compartido con un botón. |

## Cómo se gana plata
- **Carreras del mundo abierto** (79, se descubren manejando): premio por puesto, rivales que se adaptan a tu auto.
- **Escaparse de la policía**: $1.500 + $1.000 por nivel + $20 por segundo de persecución. La racha va al ranking.
- **Eventos en vivo** (los manda el servidor, ver abajo): autos, créditos, vale de taller, diseños, gomas y autos alquilados.
- **Aventura, Travesía X y carreras sueltas**: premios por puesto.
- **Regalo diario** (sube con la racha de días) y **subida de nivel**.
- Todo lo que suma plata lo **valida el servidor** (topes por hora y por día). No se puede inventar plata en el celular.

## En qué se gasta
- **Autos**: 28 en el catálogo, de $9.000 (R2 Turbo, el inicial) a $260.000. Cuatro concesionarios, cada uno con su rubro, y cada auto en 4 versiones (De fábrica, Sport, Preparado, Llamas).
- **Taller**: mejoras por nivel (motor, turbo, frenos…), gomas por tipo (calle, deportiva, slick, tierra, barro, drift), llantas y piezas, reglajes.
- **Diseños, interiores y volantes** (cosméticos por auto).
- **En la calle**: nafta (~80 km por tanque), peajes, multas de la policía, gomas gastadas (1.200 km las de calle).
- **Vale de taller** (NUEVO): saldo que se gana en eventos y **sólo se gasta en el taller** (mejoras, gomas, piezas, diseños y reglajes). Se usa solo,
  antes que los créditos. Se ve arriba, al lado de la plata: «🔧 $50.000».

## La policía (lo que le da tensión al mundo)
- **Controles** en las rutas largas entre ciudades.
- **Desmadre** en la ciudad: chocar paredes y autos, romper farolas o correr llena un medidor; avisa a la mitad y al 80 %, y lleno te persiguen.
- **Persecución**: patrulleros, interceptor de frente, arresto, multa y aparecés en la comisaría. Si escapás, cobrás.
- **Se mezcla con todo**: si te escapás y pasás por otro control, ese control se suma; si tu presa de la cacería pasa un control, te persiguen a vos.

## El online hasta el 1/11: EVENTOS (cada uno en su celular, el servidor decide)
El servidor (Supabase) es el **gestor de eventos y premios**. Programa eventos al azar (no muy seguidos, máximo 5 a la vez), los avisa en el juego, cuenta los
intentos, valida tiempos y puntajes, da los premios y publica quién ganó. No hay que elegir nada en la pausa: **los eventos aparecen en el mundo**.

| Evento | Cuánto dura | Qué hay que hacer | Premio |
|---|---|---|---|
| 🏅 **Temporada de la semana** (NUEVO) | 7 días, una atrás de otra | Todo suma: cada evento cumplido da puntos (cacería 100, fuga 40, contrarreloj 30, carrera y drift 25) y ganarlo suma el doble | **1.º el Veltor Max Pro GTR (súper deportivo)** · 2.º el diseño Oro para todos tus autos + $50.000 de vale de taller · 3.º a 5.º $25.000 de vale |
| 🌀 **Desafío de drift** (NUEVO) | 3 días | En la Plaza de Drift (Ruta 60): 90 s para hacer la mayor cantidad de puntos; vale tu mejor intento | **1.º el KAIRÓS KL5** · 2.º y 3.º gomas de drift para todos tus autos + vale de taller |
| 🎯 Cazarrecompensas de las 22 | 20 min | 3 autos sueltos en Dream City; pegarte 60 s a uno | el auto (uno por auto, uno cada 7 días por jugador) |
| 🎯 Cazarrecompensas de la tarde | 15 min | 1 auto de gama media | el auto |
| 🚨 Fuga de 10 min | 24 h | aguantar 10 min una persecución y escapar | DRP Interceptor por 3 días |
| 🚨 **Fuga por el vale** (NUEVO) | 24 h | aguantar 8 min y escapar | $50.000 de vale de taller |
| 🚨 Fuga de 5 min | 6 h | aguantar 5 min y escapar | $12.000 |
| 🏁 Contrarreloj entre ciudades | 24 h, 3 intentos | salir de Dream City y llegar a tiempo a la ciudad marcada | $20.000 |
| 🏆 Carrera de la semana | 7 días | el mejor tiempo en la carrera marcada del mapa | $25.000 · $12.000 · $6.000 |

- **Una persecución cuenta para todas las fugas a la vez**: si aguantás 10 min, cumplís la de 5, la del vale y la de 10.
- **Cada carrera del mapa** muestra el récord mundial y tu mejor tiempo; al terminar te dice tu puesto.
- **Premios justos**: nada de millones. Los autos grandes salen sólo de la temporada (uno por semana) y de la cacería (uno por auto).
- **Se configura sin APK nuevo**: en Supabase (tabla `wev_templates`) se cambian premios, tiempos, frecuencia y textos, o se agregan eventos copiando una fila.
  Por ejemplo: «drift del sábado con un súper deportivo», «temporada de diseños», «fuga de 15 min → STRIX por 2 días».

### Por qué es justo y difícil de trampear
- **Todo lo que vale lo da el servidor**: créditos, autos, alquileres, vale de taller, diseños y gomas. El celular no puede regalarse nada.
- **Cada intento tiene hora de inicio en el servidor**: una fuga de 10 min tiene que haber empezado hace 10 min de verdad; la sesión de drift tiene que durar
  sus 90 s y no puede pasar de 1.500 puntos por segundo; los tiempos de carrera tienen que ser posibles.
- **Topes**: intentos por evento, un ganador por auto de cacería, un auto de cacería cada 7 días, premios máximos por evento.
- **Recorrido guardado** del ganador de la cacería para revisarlo.
- **Límite honesto**: el servidor no ve la partida. Con estas reglas, hacer trampa cuesta y deja rastro.

## Por qué jugarían (lo que engancha)
- **Siempre hay algo en juego**: un evento por empezar (aviso con cuenta regresiva), una temporada con un súper deportivo y una tabla donde ves tu puesto.
- **Objetivos de distinto largo**: 90 s (drift), 10 min (fuga), media hora (contrarreloj), una semana (temporada y carrera de la semana).
- **Cosas que no se compran**: autos de la cacería, el súper deportivo de la temporada, el Interceptor alquilado. Se ganan jugando.
- **Progreso visible**: garaje que crece, mejoras, diseños, nivel, récords con tu nombre, «📢 Fulano ganó…» que ven todos.
- **Emoción del mundo**: la policía puede arruinarte una cacería o regalarte una fuga; las cosas se cruzan.
- **Escasez**: un ganador por auto, eventos con fecha, alquileres que vencen. Volver mañana tiene premio.

## Cuando llegue el tiempo real (1/11, Supabase Pro)
Supabase → `app_flags` → `pvp` = true y listo, sin APK nuevo. Los jugadores se ven en el mundo online (autos en vivo, chat, mercado, policía compartida)
y los eventos y la temporada siguen igual.

## Qué falta para estar seguro
Todo lo de esta tanda se probó en la computadora (pruebas automáticas con un servidor falso), **no en el teléfono**. Falta jugarlo en el APK y,
en Supabase, programar un evento de prueba (`select public.event_admin_schedule('drift_finde', now() + interval '5 minutes');`) y jugarlo.
