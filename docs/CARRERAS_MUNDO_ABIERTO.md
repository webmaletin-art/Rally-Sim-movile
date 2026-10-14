# Carreras del mundo abierto (para descubrir)

Pedido del dueño (14/10/2026): que las calles y rutas del mundo abierto sean una red de carreras que se descubren recorriendo, sin duplicar la ciudad para cada carrera.

## Qué hay
`game/world/ow_events.gd` arma los eventos (puro y determinista: igual en todos los teléfonos) a partir de los tramos que **ya existen**:
- **Región**: para cada ciudad y pueblo, hasta dos tramos de ruta que salen de sus afueras (cruces a menos de 1,5 km del pueblo, de más de 1,6 km): sobre tierra o ripio → **Rally** (contrarreloj),
  de montaña → **Contrarreloj de montaña**, autopista → **Desafío de velocidad** (promedio), ruta o provincial → **Sprint** A→B con 3 rivales (el segundo tramo de un pueblo, **Persecución**).
  Cerca de cada ciudad grande: una **Picada** (450 m rectos, menos de 2,5 m de desvío) y una **Huida** (90 s con la policía encima).
- **Dream City**: tres **Circuitos urbanos** de dos vueltas (puntos fijos alrededor de la plaza, el recorrido lo arma el GPS de la ciudad).
- Hoy salen 79 eventos (20 sprints, 20 de montaña, 19 persecuciones, 8 huidas, 6 picadas, 3 circuitos, 2 rallies, 1 de velocidad). Ninguno sobre una calle cortada: el recorrido es un tramo
  continuo de la red (`RegionData._slice`) o una ruta del GPS que existe.
- Premio: base + por km según el tipo, ×1 a ×1,6 cuanto más lejos de Dream City (`tier`). Ganarlo de nuevo paga el 35 %; 2º 45 %, 3º 25 %; medallas oro 100 %, plata 60 %, bronce 35 %.
  Todo pasa por `profile.earn(…, "owev", id)`: la cuenta del servidor lo valida (tope por premio, por hora y por día, y el mismo evento no se cobra dos veces en 15 s). Entre corrida y corrida del mismo evento, 90 s.

## Cómo se juega (`game/city/city_events.gd`, servicio de la ciudad)
1. **Descubrir**: pasar a menos de 90 m de la largada (anillo en el piso + cartel flotante con nombre y premio, sólo los que están a menos de 450 m). La primera vez sale un cartel
   «¡CARRERA DESCUBIERTA!» con el largo, el premio y cómo largar; queda guardado en `profile.d["owEvents"]` y aparece en el **mapa** (cuadradito amarillo; verde si ya la ganaste) y se puede tocar para ir con el GPS.
2. **Largar**: frenar adentro del círculo (12 m). No se puede con la policía persiguiéndote. Cuenta regresiva de 3 s; los rivales salen adelante (en la picada, al lado).
3. **Correr**: GPS a la meta y una columna naranja en el próximo punto (250 m adelante). Salirse más de 70 m del recorrido durante 6 s, o pasarse mucho del tiempo, lo anula.
   Durante el evento no se arman controles policiales (`CityPolice.suspended`), salvo en la Huida, que usa a la policía (`CityPolice.event_chase`).
4. **Rivales**: autos del catálogo parecidos al tuyo (`AiCars.pick` por índice de rendimiento), con piloto `police_driver.gd` en modo «path» (frenan antes de las curvas según el radio, cometen errores chicos cada 7–16 s).
   **Adaptables**: si les ganás, la próxima vez van un 3 % más rápido; si perdés, un 3 % más lento (entre 0,85 y 1,08 del ritmo que permite el camino). No hay goma elástica ni teletransporte: tu auto y sus mejoras importan.
5. Las carreras rápidas, la Carrera y la Aventura no cambian (siguen pagando igual).

## Pruebas
`tests/ow_events_test.gd`: eventos variados, largadas sobre la calle, recorridos continuos, descubrir, largar un sprint con 3 rivales y terminarlo con premio, contrarreloj de montaña con medalla,
repetir un evento ganado paga menos, Huida con la policía (parado te agarran y no hay premio). Usa el mismo auto de prueba que `police_test` (física real, choques simplificados).

## Pendiente
- Online: los eventos están apagados en el mundo online hasta que el servidor dé los premios (como las demás actividades). La estructura de eventos online (carreras entre jugadores) está en `docs/ONLINE_SUPABASE.md` → pendiente.
- Eliminación y drift como eventos del mundo (el drift ya está en la Plaza de Drift), campeonatos que sumen eventos del mundo, eventos nocturnos o con lluvia.
- Probar en el APK: ¿se encuentran fácil?, ¿se entiende cómo largar?, ¿los rivales dan pelea?, ¿premios razonables?
