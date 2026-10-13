extends RefCounted
## Movimiento suave de un auto remoto (otro jugador) a partir de muestras sueltas {posición, rumbo, velocidad} que llegan entre 0,5 y 5 veces por segundo (Realtime) o cada ~2 s (consulta periódica).
## Estima hacia dónde va (un arco con la velocidad y la curvatura que salen de las dos últimas muestras; si dejan de llegar sigue un rato y después frena solo) y el auto que se dibuja sigue esa
## estimación con la velocidad de la estimación (sin retraso) y corrige de a poco lo que se desvió cuando llega una muestra nueva: no salta, dobla en las curvas (no corta camino en línea recta)
## y acelera y frena de forma creíble. También entrega lo que necesita el modelo real (CarVisual.sync_from) para verse como un auto de la IA: ángulo de las ruedas delanteras, cabeceo y balanceo
## de la carrocería y la velocidad de giro de las ruedas.
## La curvatura sale de la geometría (cuánto giró el rumbo en cuántos metros), no de los tiempos: la demora de la red no la ensucia.
## Funciones puras de estado: se prueba sin red ni escena (tests/remote_motion_test.gd).

const HOLD_MIN := 0.7 # s: aunque lleguen muy seguido, se sigue la trayectoria al menos esto antes de empezar a frenar
const HOLD_MAX := 3.4 # s: con consulta lenta (cada ~2 s) se sigue de largo hasta acá
const STOP_TIME := 2.4 # s: pasada la espera, el auto frena hasta quedarse (si se corta la señal no se va al infinito)
const ACC_TIME := 1.2 # s: la aceleración o frenada que traía se mantiene este tiempo
const CURV_DECAY := 0.22 # 1/s: la curva que traía se va abriendo de a poco (un auto no gira en círculos para siempre)
const MAX_CURV := 0.25 # 1/m (radio mínimo de 4 m)
const POS_RATE := 5.0 # 1/s: qué tan rápido se corrige lo que se desvió de la estimación
const YAW_RATE := 8.0
const SPEED_RATE := 5.0
const WHEELBASE := 2.7
const TELEPORT := 60.0 # una diferencia mayor que esto es un salto (otro lado del mapa): se corta en seco

# lo que se dibuja
var pos := Vector2.ZERO
var yaw := 0.0
var speed := 0.0 # m/s
var steer := 0.0 # ángulo de las ruedas delanteras (rad; positivo = hacia donde aumenta el rumbo)
var roll := 0.0
var pitch := 0.0
var has := false

# última muestra y lo que se dedujo de las anteriores
var _s_pos := Vector2.ZERO
var _s_yaw := 0.0
var _s_speed := 0.0
var _s_t := 0.0
var _kappa := 0.0 # curvatura (1/m; positiva = el rumbo aumenta)
var _acc := 0.0 # aceleración longitudinal estimada (m/s²)
var _interval := 0.5 # tiempo típico entre muestras (s)
var _chord := 0.0 # rumbo de la cuerda entre las dos últimas muestras sin rumbo (push_track)
var _chord_known := false
var _om_disp := 0.0
var _acc_disp := 0.0
var _prev_speed_disp := 0.0

## Llega una muestra: posición en el mapa del juego, rumbo (rad), velocidad (m/s) y la hora (segundos) en que se tomó/llegó
func push_sample(p: Vector2, yaw_s: float, speed_s: float, t: float) -> void:
	if not has or p.distance_to(pos) > TELEPORT:
		pos = p
		yaw = yaw_s
		speed = maxf(speed_s, 0.0)
		_s_pos = p
		_s_yaw = yaw_s
		_s_speed = speed
		_s_t = t
		_kappa = 0.0
		_acc = 0.0
		_interval = 0.5
		_chord_known = false
		_om_disp = 0.0
		_acc_disp = 0.0
		_prev_speed_disp = speed
		has = true
		return
	var dt := t - _s_t
	if dt < 0.03:
		return # la misma muestra otra vez (o desordenada): no aporta nada
	if dt < 5.0:
		var dyaw := wrapf(yaw_s - _s_yaw, -PI, PI)
		var ds := p.distance_to(_s_pos)
		if ds > 0.4:
			# largo del arco a partir de la cuerda: cuerda = 2·R·sin(dyaw/2), arco = R·dyaw
			var half := absf(dyaw) * 0.5
			var arc := ds * (half / sin(half) if half > 1e-4 else 1.0)
			_kappa = lerpf(_kappa, clampf(dyaw / arc, -MAX_CURV, MAX_CURV), 0.75)
		_acc = lerpf(_acc, clampf((speed_s - _s_speed) / dt, -14.0, 9.0), 0.6)
		_interval = lerpf(_interval, clampf(dt, 0.1, 4.0), 0.3)
	else:
		_kappa = 0.0
		_acc = 0.0
	_s_pos = p
	_s_yaw = yaw_s
	_s_speed = maxf(speed_s, 0.0)
	_s_t = t

## Muestra sin rumbo (la consulta periódica sólo trae posición y velocidad): el rumbo sale de hacia dónde se movió desde la muestra anterior. Esa dirección es el promedio del tramo, o sea el rumbo de la
## mitad del tramo: se le suma la mitad de lo que giró respecto del tramo anterior para tener el rumbo de ahora.
func push_track(p: Vector2, speed_s: float, t: float) -> void:
	if not has or p.distance_to(pos) > TELEPORT:
		push_sample(p, yaw if has else 0.0, speed_s, t)
		return
	var d := p - _s_pos
	if d.length() < 0.6 or t - _s_t < 0.03:
		push_sample(p, _s_yaw, speed_s, t) # (casi sin moverse: queda el mismo rumbo)
		return
	var chord := atan2(d.x, d.y)
	var yaw_s := chord
	if _chord_known:
		yaw_s = chord + wrapf(chord - _chord, -PI, PI) * 0.5
	push_sample(p, yaw_s, speed_s, t)
	_chord = chord
	if not _chord_known:
		_chord_known = true
		yaw = yaw_s # hasta ahora no se sabía hacia dónde miraba: se pone de una (no gira desde cualquier lado)

## Cuánto sigue de largo el auto sin muestras nuevas antes de frenar: depende de qué tan seguido llegan
func hold_time() -> float:
	return clampf(_interval * 1.4 + 0.25, HOLD_MIN, HOLD_MAX)

## Hacia dónde estaría el auto a la hora `now` según la última muestra (arco con la velocidad y la curvatura, apagándose con el tiempo): [posición, rumbo, velocidad]
func estimate(now: float) -> Array:
	var hold := hold_time()
	var age := clampf(now - _s_t, 0.0, hold + STOP_TIME)
	if age <= 0.0:
		return [_s_pos, _s_yaw, _s_speed]
	var steps := clampi(ceili(age / 0.15), 1, 32)
	var st := age / float(steps)
	var h := _s_yaw
	var p := _s_pos
	var v_end := _s_speed
	for i in steps:
		var tt := (float(i) + 0.5) * st
		var vv := maxf(0.0, _s_speed + _acc * minf(tt, ACC_TIME))
		if tt > hold:
			vv *= 1.0 - smoothstep(0.0, 1.0, (tt - hold) / STOP_TIME)
		var dh := _kappa * exp(-CURV_DECAY * tt) * vv * st
		p += Vector2(sin(h + dh * 0.5), cos(h + dh * 0.5)) * vv * st
		h += dh
		v_end = vv
	return [p, h, v_end]

## Un cuadro: el auto avanza como avanza la estimación y lo que se había desviado se va corrigiendo
func step(now: float, dt: float) -> void:
	if not has or dt <= 0.0:
		return
	var e0 := estimate(now)
	var e1 := estimate(now + dt)
	var prev_yaw := yaw
	pos = (e1[0] as Vector2) + (pos - (e0[0] as Vector2)) * exp(-POS_RATE * dt)
	yaw = float(e1[1]) + wrapf(yaw - float(e0[1]), -PI, PI) * exp(-YAW_RATE * dt)
	speed = maxf(0.0, float(e1[2]) + (speed - float(e0[2])) * exp(-SPEED_RATE * dt))
	# lo que mira el modelo: giro y aceleración del auto dibujado (suavizados), de ahí salen las ruedas, el balanceo y el cabeceo
	var om := wrapf(yaw - prev_yaw, -PI, PI) / dt
	_om_disp = lerpf(_om_disp, om, 1.0 - exp(-8.0 * dt))
	var ac := (speed - _prev_speed_disp) / dt
	_prev_speed_disp = speed
	_acc_disp = lerpf(_acc_disp, clampf(ac, -14.0, 9.0), 1.0 - exp(-6.0 * dt))
	steer = clampf(atan(WHEELBASE * _om_disp / maxf(speed, 2.5)), -0.55, 0.55)
	roll = clampf(speed * _om_disp * 0.0035, -0.07, 0.07)
	pitch = clampf(-_acc_disp * 0.0028, -0.05, 0.05)

## Velocidad de giro de las ruedas (rad/s) para un radio dado
func wheel_omega(radius: float) -> float:
	return speed / maxf(0.2, radius)
