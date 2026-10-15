extends RefCounted
## Todos los ritmos y umbrales del multijugador en un solo lugar (15/10/2026, «online fluido»: docs/COSTOS_ONLINE.md → «Ritmos actuales»).
## Lo usan world_sync.gd (posiciones en vivo por Realtime), remote_motion.gd (cómo se dibuja cada auto remoto), remote_cars.gd (qué autos se muestran)
## y online_social.gd (presencia y lista por HTTP). Cambiar un número acá cambia el comportamiento de todos: no repetirlos en otros scripts.

# ── Envío de la posición propia por Realtime (world_sync.gd). Cada mensaje se cobra 1 al mandarse + 1 por cada jugador de la celda que lo recibe.
const SEND_MAX_HZ := 4.0 # con alguien cerca y en movimiento (con la interpolación del otro lado se ve fluido)
const SEND_BUDGET := 40.0 # entregas por segundo y por celda que se reparten entre los k jugadores: hz = BUDGET / (k·(k−1))
const SEND_MIN_HZ_NEAR := 1.0 # con alguien cerca, nunca menos que esto (hasta SEND_CROWD jugadores en la celda)
const SEND_CROWD := 12 # con más jugadores que esto en la celda se acepta bajar hasta SEND_MIN_HZ_CROWD (si no, la celda se come el tope de mensajes/s)
const SEND_MIN_HZ_CROWD := 0.5
const SEND_FAR_HZ := 1.0 # hay otros en la celda pero ninguno a menos de NEAR_D: no ven mi auto, sólo hace falta que sepan dónde estoy
const SEND_ALONE_HZ := 0.2 # nadie más en la celda (para el que llega)
const SEND_IDLE_HZ := 0.25 # quieto (para que sepan que sigo ahí)
const NEAR_D := 900.0 # m: a partir de acá el otro ya no se dibuja (SHOW_R + margen)
const MOVE_EPS := 0.4 # m que hay que moverse para que valga mandar
const TURN_TRIGGER := 0.26 # rad (15°): si el rumbo cambió esto desde el último envío, se manda ya (curvas cerradas)
const SPEED_TRIGGER := 20.0 # km/h: ídem con la velocidad (frenadas y aceleraciones fuertes)
const TRIGGER_MIN_GAP := 0.12 # s entre un envío y uno extra
const GONE_S := 9.0 # s sin noticias de un auto: se fue (más del doble de lo que tarda uno quieto en avisar)
const PRESENCE_LEAVE_GRACE := 2.0 # s: si la presencia del canal dice que se fue y no llegó nada en este tiempo, se da de baja ya (sin esperar GONE_S)

# ── Cómo se dibuja un auto remoto (remote_motion.gd)
const INTERP_MAX_INTERVAL := 0.6 # s: si las muestras llegan más seguido que esto se interpola con búfer; si no (consulta HTTP cada ~2 s), se estima hacia adelante
const BUF_MAX := 16 # muestras guardadas por auto
const BUF_KEEP_S := 3.0 # s de historia
const DELAY_MIN := 0.10 # s de atraso del dibujo respecto de la última muestra (lo justo para tener siempre dos muestras entre las que interpolar)
const DELAY_MAX := 0.9
const LEAD_MAX := 0.9 # s: lo interpolado (suave, en el pasado) se proyecta hacia el presente a lo sumo esto (con su velocidad y su giro): sin esto el otro se vería ~6 m atrás a 80 km/h
const DELAY_SLEW := 0.08 # s de cambio del atraso por segundo (cambiarlo de golpe se vería como un tirón)
const SNAP_ERR := 12.0 # m: una corrección más grande que esto no se suaviza (se reubica)
const ERR_RATE := 5.0 # 1/s: qué tan rápido se absorbe una corrección chica
const TELEPORT := 60.0 # m: un salto así es otro lugar (reapareció, VOLVER A LA CALLE, otra punta del mapa): se reubica en seco
const STALE_S := 9.0 # s sin muestras: el auto se considera perdido (= GONE_S)

# ── Lista de jugadores y presencia por HTTP (online_social.gd, remote_cars.gd)
const POLL_S := 2.0 # lista de conectados (nombre, modelo, pintura) sin Realtime
const POLL_RT_S := 8.0 # con Realtime andando la posición llega en vivo: la lista sólo trae nombres, modelos y jugadores nuevos
const POLL_SOON_S := 0.4 # apareció en vivo un auto que la lista no conocía: se pide la lista enseguida (para su nombre y modelo)
const POLL_SOON_GAP := 3.0 # s mínimos entre dos pedidos «enseguida»
const BEAT_S := 2.0 # aviso de posición al servidor sin Realtime
const BEAT_RT_S := 5.0 # con Realtime (la posición ya viaja en vivo; el servidor la usa para la lista, los reportes y los locales)
const SHOW_R := 700.0 # m: a menos de esto se dibuja el auto del otro
const HIDE_R := 820.0 # m: se deja de dibujar recién acá (histéresis: no titila en el borde)
const MAX_SHOWN := 12
const GHOST_HOLD_S := 60.0 # s: un auto dado de baja (se fue) no vuelve por la lista (la presencia del servidor dura 45 s) salvo que se mueva o mande en vivo
const RT_HEALTHY_S := 4.0 # s: Realtime «andando» = socket abierto y la celda propia unida hace al menos esto
