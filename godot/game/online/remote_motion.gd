extends RefCounted
## Movimiento suave de un auto remoto (otro jugador) a partir de muestras sueltas {posición, rumbo, velocidad} que llegan entre 0,5 y 5 veces por segundo (Realtime) o cada ~2 s (consulta periódica).
## Estima hacia dónde va (un arco con la velocidad y la curvatura que salen de las dos últimas muestras; si dejan de llegar sigue un rato y después frena solo) y el auto que se dibuja sigue esa
## estimación con la velocidad de la estimación (sin retraso) y corrige de a poco lo que se desvió cuando llega una muestra nueva: no salta, dobla en las curvas (no corta camino en línea recta)
## y acelera y frena de forma creíble. También entrega lo que necesita el modelo real (CarVisual.sync_from) para verse como un auto de la IA: ángulo de las ruedas delanteras, cabeceo y balanceo
## de la carrocería y la velocidad de giro de las ruedas.
## La curvatura sale de la geometría (cuánto giró el rumbo en cuántos metros), no de los tiempos: la demora de la red no la ensucia.
## Desde el 15/10/2026 («online fluido») hay DOS modos, según qué tan seguido llegan las muestras:
##  · INTERPOLACIÓN CON BÚFER (Realtime, ≥ ~1 por s): se guardan las últimas muestras con su hora (la del que las mandó, pasada al reloj propio por world_sync.gd) y el auto se
##    dibuja un poco en el pasado (`delay`, ~0,1–0,9 s según cada cuánto llegan y cuánto varían), siempre ENTRE dos muestras reales: curva de Hermite con la velocidad de cada
##    muestra (dobla redondo, no en línea recta) y rumbo tangente a la curva. Si se acaban las muestras (pérdida, corte) sigue con la estimación de abajo un rato y frena solo.
##    Cuando llega una muestra que contradice lo extrapolado, la diferencia se absorbe de a poco (ERR_RATE); si es enorme, se reubica (y se cuenta como resincronización).
##  · ESTIMACIÓN HACIA ADELANTE (consulta HTTP cada ~2 s, o pocas muestras): la de siempre (abajo).
## Las muestras repetidas o desordenadas se descartan (se cuentan). Funciones puras de estado: se prueba sin red ni escena (tests/remote_motion_test.gd).

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
const NT := preload("res://game/online/net_tuning.gd")

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

# búfer de la interpolación: [t, posición, rumbo, velocidad]
var buf: Array = []
var delay := 0.25 # s: el auto se dibuja así de atrasado respecto de la muestra más nueva
var _delay_want := 0.25
var _late := 0.0 # cuánto después de su hora llega una muestra (promedio) y cuánto varía
var _late_var := 0.0
var _last_arrival := -1.0
var _tgt := Vector2.ZERO # punto de la trayectoria (sin la corrección) del cuadro anterior
var _tgt_yaw := 0.0
var _tgt_ok := false
var _err := Vector2.ZERO # corrección pendiente (se absorbe de a poco)
var _err_yaw := 0.0
var mode := "" # "interp" | "estim" (para el diagnóstico)
var resyncs := 0 # veces que se reubicó en seco (salto grande, reaparición)
var dropped := 0 # muestras repetidas o desordenadas descartadas
var extrap_s := 0.0 # cuánto lleva extrapolando (sin muestras nuevas) en el modo interpolación

## Llega una muestra: posición en el mapa del juego, rumbo (rad), velocidad (m/s) y la hora (segundos) en que se tomó (en el reloj propio).
## `arrival` (opcional): cuándo llegó de verdad (para medir cuánto se atrasan y elegir el atraso del dibujo); si falta, se usa `t`.
func push_sample(p: Vector2, yaw_s: float, speed_s: float, t: float, arrival := -1.0) -> void:
	var arr := arrival if arrival >= 0.0 else t
	if has and not buf.is_empty() and t <= float((buf[buf.size() - 1] as Array)[0]) + 0.005:
		dropped += 1 # repetida o desordenada: la trayectoria ya pasó por ahí
		return
	var jump := has and p.distance_to(pos) > TELEPORT
	if jump:
		resyncs += 1
		buf.clear()
		_err = Vector2.ZERO
		_err_yaw = 0.0
		_tgt_ok = false
	buf.append([t, p, yaw_s, maxf(speed_s, 0.0)])
	if buf.size() == 2:
		_interval = clampf(t - float((buf[0] as Array)[0]), 0.1, 4.0) # (con dos muestras ya se sabe cada cuánto llegan: no se arranca con un valor inventado)
	while buf.size() > NT.BUF_MAX or (buf.size() > 2 and t - float((buf[0] as Array)[0]) > NT.BUF_KEEP_S):
		buf.pop_front()
	# cuánto se atrasan las muestras al llegar (la red no es pareja): el atraso del dibujo tiene que cubrir eso para tener siempre una muestra adelante
	var late := maxf(0.0, arr - t)
	if _last_arrival < 0.0:
		_late = late
	else:
		_late_var = lerpf(_late_var, absf(late - _late), 0.2)
		_late = lerpf(_late, late, 0.2)
	_last_arrival = arr
	extrap_s = 0.0
	_dr_push(p, yaw_s, speed_s, t)
	_delay_want = clampf(_interval * 1.15 + _late + 2.5 * _late_var + 0.03, NT.DELAY_MIN, NT.DELAY_MAX)
	if buf.size() <= 2:
		delay = _delay_want # (al aparecer se arranca con el atraso justo; después cambia de a poco)

## (la estimación hacia adelante de siempre)
func _dr_push(p: Vector2, yaw_s: float, speed_s: float, t: float) -> void:
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

## ¿Se interpola con el búfer? (muestras seguidas; con la consulta lenta se estima hacia adelante)
func interpolating() -> bool:
	return buf.size() >= 2 and _interval <= NT.INTERP_MAX_INTERVAL

## Punto de la trayectoria a la hora `rt` (en el pasado): entre dos muestras, una curva de Hermite con la velocidad de cada una; antes de la primera, la primera;
## después de la última, la estimación hacia adelante (que frena sola si no llega nada). [posición, rumbo, velocidad, extrapolando]
func sample_at(rt: float) -> Array:
	var a: Array = buf[0]
	if rt <= float(a[0]):
		return [a[1], a[2], a[3], false]
	var last: Array = buf[buf.size() - 1]
	if rt >= float(last[0]):
		var e := estimate(rt)
		return [e[0], e[1], e[2], true]
	for i in range(buf.size() - 1):
		var b: Array = buf[i + 1]
		if rt <= float(b[0]):
			a = buf[i]
			var t0 := float(a[0])
			var span := maxf(float(b[0]) - t0, 1e-3)
			var u := clampf((rt - t0) / span, 0.0, 1.0)
			var p0: Vector2 = a[1]
			var p1: Vector2 = b[1]
			var chord := p1.distance_to(p0)
			# tangentes = velocidad × tramo, sin pasarse (una velocidad que no cuadra con la distancia haría un rulo)
			var m0 := Vector2(sin(float(a[2])), cos(float(a[2]))) * float(a[3]) * span
			var m1 := Vector2(sin(float(b[2])), cos(float(b[2]))) * float(b[3]) * span
			var cap := chord * 1.6 + 0.5
			if m0.length() > cap:
				m0 = m0.normalized() * cap
			if m1.length() > cap:
				m1 = m1.normalized() * cap
			var u2 := u * u
			var u3 := u2 * u
			var pp := p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * (u3 - 2.0 * u2 + u) + p1 * (-2.0 * u3 + 3.0 * u2) + m1 * (u3 - u2)
			var vv := lerpf(float(a[3]), float(b[3]), u)
			var hh := float(a[2]) + wrapf(float(b[2]) - float(a[2]), -PI, PI) * u # (por el lado corto: de 359° a 0° no da la vuelta)
			if chord > 0.3 and vv > 1.5:
				var d := (p0 * (6.0 * u2 - 6.0 * u) + m0 * (3.0 * u2 - 4.0 * u + 1.0) + p1 * (-6.0 * u2 + 6.0 * u) + m1 * (3.0 * u2 - 2.0 * u))
				if d.length() > 1e-3:
					var tang := atan2(d.x, d.y)
					if absf(wrapf(tang - hh, -PI, PI)) < 1.2: # (marcha atrás o datos raros: queda el rumbo de las muestras)
						hh = tang
			return [pp, hh, vv, false]
	return [last[1], last[2], last[3], false]

## Un cuadro. Con muestras seguidas se interpola en el pasado; si no, la estimación hacia adelante de siempre.
func step(now: float, dt: float) -> void:
	if not has or dt <= 0.0:
		return
	var prev_yaw := yaw
	if interpolating():
		mode = "interp"
		# el atraso cambia de a poco (si cambiara de golpe el auto se adelantaría o se frenaría de un tirón)
		delay = move_toward(delay, _delay_want, NT.DELAY_SLEW * dt)
		var rt := now + dt - delay # (el auto se dibuja como queda al final del cuadro, igual que la estimación)
		var smp := sample_at(rt)
		var tp: Vector2 = smp[0]
		var ty := float(smp[1])
		var tv := float(smp[2])
		if bool(smp[3]):
			# se acabaron las muestras: la estimación hacia adelante desde la última (sigue un rato y frena sola; no se va al infinito)
			extrap_s += dt
			var e := estimate(now + dt)
			tp = e[0]
			ty = float(e[1])
			tv = float(e[2])
		else:
			extrap_s = 0.0
			# lo interpolado está `delay` s en el pasado: se proyecta al presente con su velocidad y su giro (un arco), así el otro no se ve atrasado
			var lead := minf(delay, NT.LEAD_MAX)
			var s2 := sample_at(rt - 0.06)
			var om := clampf(wrapf(ty - float(s2[1]), -PI, PI) / 0.06, -1.5, 1.5)
			var acc := clampf((tv - float(s2[2])) / 0.06, -12.0, 8.0)
			var v_end := maxf(0.0, tv + acc * lead * 0.5)
			var vm := (tv + v_end) * 0.5
			var hm := ty + om * lead * 0.5
			tp += Vector2(sin(hm), cos(hm)) * vm * lead
			ty += om * lead
			tv = v_end
		smp = [tp, ty, tv, smp[3]]
		if _tgt_ok:
			# si la trayectoria cambió de golpe (llegó una muestra que corrige lo extrapolado), la diferencia se absorbe de a poco
			var expect := _tgt + Vector2(sin(_tgt_yaw), cos(_tgt_yaw)) * float(smp[2]) * dt
			var jump := expect - tp
			if jump.length() > 0.08 + 0.01 * float(smp[2]):
				_err += jump
				_err_yaw += wrapf(_tgt_yaw - ty, -PI, PI) if absf(wrapf(_tgt_yaw - ty, -PI, PI)) > 0.15 else 0.0
		if _err.length() > NT.SNAP_ERR:
			_err = Vector2.ZERO
			_err_yaw = 0.0
			resyncs += 1
		_tgt = tp
		_tgt_yaw = ty
		_tgt_ok = true
		var k := exp(-NT.ERR_RATE * dt)
		_err *= k
		_err_yaw *= k
		pos = tp + _err
		yaw = ty + _err_yaw
		speed = maxf(0.0, float(smp[2]))
	else:
		mode = "estim"
		_tgt_ok = false
		_err = Vector2.ZERO
		_err_yaw = 0.0
		var e0 := estimate(now)
		var e1 := estimate(now + dt)
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

## Segundos desde la última muestra (para dar de baja autos perdidos)
func age(now: float) -> float:
	return now - _last_arrival if _last_arrival >= 0.0 else 1e9

func stale(now: float) -> bool:
	return has and age(now) > NT.STALE_S
