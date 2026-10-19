# Dream Racing: cómo queda listo para subir y cómo funciona el online hasta Supabase Pro

*15/10/2026. Tiempo real (jugador contra jugador) previsto para el 1/11/2026, al pagar Supabase Pro.*

## En una frase
Hasta el 1 de noviembre el online es de **EVENTOS DE CLASIFICACIÓN**. Cada uno juega en su celular, en su mapa, contra la IA. El servidor (Supabase) es el
**gestor de eventos y premios**: manda los eventos, cuenta los intentos, valida los tiempos, entrega los premios y publica quién ganó. No hay tiempo real,
así que no se gasta nada de Realtime: el plan gratis alcanza para la base de datos y los eventos.

## Qué ve el jugador
- **Menú → MODO ONLINE** («eventos y ranking · tiempo real pronto»):
  - **EVENTOS EN VIVO:** lo que hay ahora y lo que viene, con premios, intentos y ganadores.
  - **RANKING:** ganadores de los eventos, mejor racha de escapes y récords mundiales de cada carrera del mapa.
  - **MIS RÉCORDS:** si se mandan al ranking o no.
  - **CUENTA.**
  - **MUNDO ONLINE EN TIEMPO REAL:** pantalla «PRÓXIMAMENTE — La partida en tiempo real, jugador contra jugador, estará disponible próximamente. Se está trabajando en eso.»
- **Portada del MODO ONLINE:** «📅 EVENTOS DE HOY», los 3 primeros (en vivo y próximos) con la miniatura del auto que se gana y «VER TODOS LOS EVENTOS».
- **En Dream City, SÓLO si se entró desde el MODO ONLINE** (cfg `events`; [B] 19/10/2026, pedido del dueño: «el online y el offline son distintos juegos, como el GTA;
  si en el offline aparecen los eventos, juego el offline y hago trampa»). Desde Menú → MUNDO ABIERTO (offline) no hay eventos, ni marca, ni récords al ranking.
  - **nada de carteles en la pantalla de juego:** el botón de pausa lleva un numerito naranja con los eventos en vivo;
  - **pausa → 📅 EVENTOS:** una tarjeta por evento (miniatura del auto o ícono, cuándo, premio, cómo vas) y «📍 IR» para marcar en el GPS la largada del
    contrarreloj, la Plaza de Drift o la carrera de la semana;
  - en la pantalla de juego sólo queda UN renglón chico del evento que estás jugando (cerca de la cacería, en una fuga, en la largada del contrarreloj, en la
    plaza de drift o corriendo la carrera de la semana) y avisos cortos (empieza en 1 minuto, ganó Fulano, resultado).
  - (antes: cartel grande al anunciar y al empezar cada evento, hasta 3 renglones fijos debajo del velocímetro y el resumen de la pausa como cartel gigante)

## Los eventos (los programa el servidor, al azar y sin amontonarse)
| Evento | Cuándo | Qué hay que hacer | Premio |
|---|---|---|---|
| 🎯 **Cazarrecompensas de las 22** | todos los días a las 22 h (Argentina) | Se sueltan **3 autos** en Dream City, en el mismo lugar para todos. Se ven 45 s en el mapa; después hay que buscarlos. Pegado atrás a menos de 20 m la barra se llena en verde (60 s). La IA es muy buena: rápida, sin errores, dobla para el otro lado si la tenés encima y afloja un ratito a mitad de la barra. | **El auto.** Uno por auto: el primero que completa la barra se lo lleva. Si ya lo tenía, la mitad de su precio. Cada jugador puede ganar un auto de cacería cada 7 días. |
| 🎯 Cazarrecompensas de la tarde | 16 h | Igual, con 1 auto de gama media | el auto |
| 🚨 **Fuga de 10 minutos** | cada 2 días aprox., dura 24 h | Cualquier persecución cuenta: aguantar 10 minutos sin que te agarren y escaparte. 5 intentos. | **DRP Interceptor por 3 días** (auto alquilado: después vuelve a la policía) |
| 🚨 Fuga de 5 minutos | cada 12 h aprox., dura 6 h | Aguantar 5 minutos y escaparse | $12.000 |
| 🏁 **Contrarreloj entre ciudades** | una vez por día, todo el día | Frenar en el círculo de la salida de Dream City y llegar a la ciudad marcada antes del tiempo. 3 intentos. | $20.000 |
| 🏆 **Carrera de la semana** | 7 días | Una de las carreras del mapa, marcada con 🏆: tu mejor tiempo de la semana va a la tabla | $25.000 · $12.000 · $6.000 a los 3 primeros |
| 🏅 **Temporada de la semana** | 7 días, una atrás de otra | Cada evento cumplido en la semana suma puntos (ganarlo, el doble) | 1.º el **Veltor Max Pro GTR** · 2.º diseño Oro para todos tus autos + $50.000 de vale de taller · 3.º a 5.º $25.000 de vale |
| 🌀 **Desafío de drift** | 3 días | En la Plaza de Drift: 90 s para hacer la mayor cantidad de puntos (vale el mejor intento) | 1.º el **KAIRÓS KL5** · 2.º y 3.º gomas de drift para todos tus autos + vale de taller |
| 🚨 Fuga por el vale | 24 h | Aguantar 8 minutos y escaparse (una persecución cuenta para todas las fugas a la vez) | $50.000 de **vale de taller** |

Premios justos: nada de millones. Los autos se ganan sólo en la cacería (uno por auto) y los alquileres duran unos días.
Hay como mucho 5 eventos abiertos a la vez (en curso más los que vienen; la temporada ocupa uno). El **vale de taller** es un saldo que sólo se gasta en el taller (mejoras, gomas, piezas, diseños y reglajes) y se usa solo, antes que los créditos. Todo se configura sin APK nuevo (ver la guía).

## Lo que pasa siempre (con o sin eventos)
- **La policía y el desmadre:** chocar paredes y autos, romper farolas y correr por la ciudad llena un medidor. La policía avisa a la mitad y al 80 %; lleno, te persigue.
- **Los controles** de las rutas siguen como antes. Y ahora se mezclan:
  - si te estás escapando y pasás por otro control, **ese control también sale detrás tuyo**;
  - si la presa de la cacería pasa por un control y vos venís atrás, **la policía te persigue a vos también**.
- **Cada escape paga** (más cuanto más dura y más alto el nivel), y la **mejor racha de escapes** va al ranking.
- **Cada carrera del mapa:** al acercarte, su cartel muestra el récord mundial (tiempo y piloto) y tu mejor tiempo. Al terminar te dice en qué puesto quedaste o si
  hiciste el nuevo récord mundial.
- Se juega y se gana plata como siempre; los créditos, los autos y las compras viven en el servidor, sin trampas.

## Cómo se evitan las trampas
- **Todo lo que vale lo da el servidor:** créditos, autos de la cacería y alquileres. El juego no puede regalarse nada.
- **Intentos:** el servidor anota cuándo empezó cada intento y valida contra esa hora. Por ejemplo, la fuga de 10 minutos tiene que haber empezado hace al menos
  10 minutos; la barra de la cacería necesita sus 60 s reales.
- **Topes:**
  - cupos por evento y un ganador por auto;
  - un auto de cacería cada 7 días por jugador;
  - tiempos posibles, entre 8 s y 1 h por carrera;
  - 40 envíos de récords por hora.
- **Recorrido guardado:** en la cacería se guarda el recorrido del ganador (jugador y auto, cada segundo) para revisarlo si algo parece raro.
- **Límite honesto:** el servidor no ve la carrera, porque cada uno juega en su celular. Con estas reglas, hacer trampa cuesta y deja rastro.

## Cuánto cuesta
- Por jugador, unas 40–60 llamadas por hora a la base: se pregunta por los eventos cada 90 s (cada 15 s cuando está por empezar uno), más un récord por carrera.
- **Cero mensajes de Realtime.**
- El plan gratis de Supabase alcanza mientras tanto. Ojo: un proyecto gratis se pausa si pasa una semana sin uso.

## El 1 de noviembre: habilitar el tiempo real (un botón)
1. Pagar Supabase Pro y, en Realtime → Settings, poner «Allow public access» en OFF.
2. Supabase → Table Editor → `app_flags` → `pvp` → **true**.
3. Listo, sin APK nuevo. Los jugadores se encuentran en el mundo online: autos en vivo, chat, conectados y mercado. Los eventos y el ranking siguen.

## Para subir a Play (checklist)
1. Instalar el APK de la última compilación verde y probar: cuenta, una carrera del mapa (récord), una persecución, la pantalla «PRÓXIMAMENTE» y EVENTOS EN VIVO.
2. Programar un evento de prueba desde el SQL Editor, por ejemplo `select public.event_admin_schedule('caza_tarde', now() + interval '10 minutes');`,
   jugarlo y mirar `wev_winners`.
3. Lo de `docs/PLAY_STORE.md`:
   - AAB con el flujo «Build Play Store AAB»;
   - ficha y capturas (`store_listing/`);
   - Seguridad de los datos (`docs/PLAY_SEGURIDAD_DATOS.md`);
   - cuenta de revisión con saldo (`account_admin_grant`);
   - textos legales publicados en GitHub Pages.
4. Subir primero a **prueba interna**, probar las compras, y después a producción.

Guía de los eventos (configurar, programar, revisar ganadores): `docs/PUBLICAR_RECOMPENSA_Y_TIEMPO_REAL.md`.
