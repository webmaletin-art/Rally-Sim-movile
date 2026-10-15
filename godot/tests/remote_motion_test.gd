## Movimiento de los autos de otros jugadores (online/remote_motion.gd): con muestras sueltas (de 0,5 a 5 por segundo, con demora irregular de la red) el auto dibujado se mueve parejo, dobla las curvas,
## no salta, se frena si se corta la señal y entrega el giro de las ruedas, el balanceo y el cabeceo que necesita el modelo real. Sin red ni escena.
## Uso: godot --headless --path godot --script res://tests/remote_motion_test.gd
extends SceneTree

const RemoteMotion := preload("res://game/online/remote_motion.gd")

const FPS := 60.0
const WARM := 6.0 # s: los primeros segundos el modelo todavía está aprendiendo la curva (no cuentan en el error)
const RUN := 24.0

var fails := 0
var _tab_pos := {} # nombre de la trayectoria → PackedVector2Array (una cada 1/240 s)
var _tab_yaw := {}
var _tab_spd := {}

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

## Trayectoria «circle»: un auto que da vueltas en un círculo (r 70 m a 22 m/s). Trayectoria «slalom»: zigzaguea (±0,6 rad de rumbo cada 6 s) con la velocidad variando entre 14 y 22 m/s
func _build(name: String) -> void:
	var n := int((RUN + 6.0) * 240.0)
	var pos := PackedVector2Array()
	var yaw_a := PackedFloat32Array()
	var spd_a := PackedFloat32Array()
	var p := Vector2.ZERO
	var dt := 1.0 / 240.0
	for i in n:
		var t := float(i) * dt
		var yw: float
		var v: float
		if name == "circle":
			v = 22.0
			yw = 0.3 + (v / 70.0) * t
		else:
			v = 18.0 + 4.0 * sin(t * 0.7)
			yw = 0.6 * sin(t * TAU / 6.0)
		pos.append(p)
		yaw_a.append(yw)
		spd_a.append(v)
		p += Vector2(sin(yw), cos(yw)) * v * dt
	_tab_pos[name] = pos
	_tab_yaw[name] = yaw_a
	_tab_spd[name] = spd_a

func _truth(name: String, t: float) -> Array:
	var i := clampi(int(t * 240.0), 0, (_tab_pos[name] as PackedVector2Array).size() - 1)
	return [(_tab_pos[name] as PackedVector2Array)[i], float((_tab_yaw[name] as PackedFloat32Array)[i]), float((_tab_spd[name] as PackedFloat32Array)[i])]

## Simula RUN s a 60 cuadros por segundo con una muestra cada `period` s; cada muestra llega con su propia demora de la red (entre 0 y 2·`jitter` s, siempre en orden).
## Devuelve {mean, max, step (cuánto se aparta, a lo sumo, el paso de un cuadro de lo que el auto avanza de verdad), hold (error medio de dejar el auto en la última muestra)}
## `stamped`: las muestras traen la hora en que se tomaron (protocolo nuevo de world_sync.gd, 15/10/2026); si no, sólo se sabe cuándo llegaron (clientes viejos y consulta HTTP).
func _drive(name: String, period: float, jitter: float, no_yaw := false, stamped := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var m := RemoteMotion.new()
	var dt := 1.0 / FPS
	var t := 0.0
	var next_sample := 0.0
	var pending: Array = [] # [llegada, muestra]
	var last_arrive := 0.0
	var sum := 0.0
	var sum_hold := 0.0
	var n := 0
	var worst := 0.0
	var step_max := 0.0
	var last := Vector2.ZERO
	var have_last := false
	var last_arrived := Vector2.ZERO
	while t < RUN:
		if t >= next_sample - 1e-9:
			# la muestra se toma ahora (t) pero llega más tarde, y trae la posición de cuando se tomó
			last_arrive = maxf(t + rng.randf_range(0.0, 2.0 * jitter), last_arrive + 0.001)
			pending.append([last_arrive, _truth(name, t), t])
			next_sample += period
		var rest: Array = []
		for q in pending:
			if float(q[0]) <= t + 1e-9:
				var s: Array = q[1]
				if no_yaw:
					m.push_track(s[0], s[2], t)
				elif stamped:
					m.push_sample(s[0], s[1], s[2], float(q[2]), t) # (hora de la muestra + hora de llegada)
				else:
					m.push_sample(s[0], s[1], s[2], t)
				last_arrived = s[0]
			else:
				rest.append(q)
		pending = rest
		m.step(t, dt)
		if t > WARM and m.has:
			var truth := _truth(name, t + dt - (0.0 if stamped else jitter)) # (el auto ya está al final del cuadro; sin la hora de la muestra la red lo muestra jitter s atrasado en promedio: eso no es error del modelo)
			var e := m.pos.distance_to(truth[0])
			sum += e
			sum_hold += last_arrived.distance_to(truth[0])
			n += 1
			worst = maxf(worst, e)
			if have_last:
				var real_step := float(truth[2]) * dt
				step_max = maxf(step_max, m.pos.distance_to(last) - real_step)
		last = m.pos
		have_last = true
		t += dt
	return {"mean": sum / float(maxi(n, 1)), "max": worst, "step": step_max, "hold": sum_hold / float(maxi(n, 1))}

func _init() -> void:
	_build("circle")
	_build("slalom")
	var c20 := _drive("circle", 2.0, 0.0)
	var c05 := _drive("circle", 0.5, 0.0)
	var c02 := _drive("circle", 0.2, 0.0)
	print("círculo   2,0 s: ", c20, "\ncírculo   0,5 s: ", c05, "\ncírculo   0,2 s: ", c02)
	check(c20["mean"] < 1.0 and c20["max"] < 2.8, "círculo a 22 m/s con una muestra cada 2 s (consulta periódica): error medio %.2f m, máximo %.2f m" % [c20["mean"], c20["max"]])
	check(c05["mean"] < 0.1 and c05["max"] < 0.3, "círculo, una muestra cada 0,5 s: error medio %.3f m, máximo %.2f m" % [c05["mean"], c05["max"]])
	check(c02["mean"] < 0.1 and c02["max"] < 0.3, "círculo, 5 muestras por segundo (Realtime): error medio %.3f m, máximo %.2f m" % [c02["mean"], c02["max"]])
	check(c02["mean"] <= c05["mean"] and c05["mean"] <= c20["mean"], "más muestras, menos error")
	# zigzag: la curva cambia de sentido todo el tiempo, el modelo no la puede adivinar del todo (con una muestra cada 2 s hay apenas 3 por zigzag)
	var s20 := _drive("slalom", 2.0, 0.0)
	var s05 := _drive("slalom", 0.5, 0.0)
	var s02 := _drive("slalom", 0.2, 0.0)
	print("zigzag    2,0 s: ", s20, "\nzigzag    0,5 s: ", s05, "\nzigzag    0,2 s: ", s02)
	check(s02["mean"] < 0.15 and s02["max"] < 0.4, "zigzag, 5 muestras por segundo: error medio %.3f m, máximo %.2f m" % [s02["mean"], s02["max"]])
	check(s05["mean"] < 0.8 and s05["max"] < 1.8, "zigzag, una muestra cada 0,5 s: error medio %.2f m, máximo %.2f m" % [s05["mean"], s05["max"]])
	check(s20["mean"] < 8.5 and s20["max"] < 35.0, "zigzag, una muestra cada 2 s (el peor caso): error medio %.2f m, máximo %.2f m" % [s20["mean"], s20["max"]])
	# mejor que dejar el auto en la última muestra (lo que haría un auto que se «teletransporta» de muestra en muestra)
	check(s02["mean"] < s02["hold"] * 0.1 and s05["mean"] < s05["hold"] * 0.2 and s20["mean"] < s20["hold"] * 0.6, "mucho mejor que dejar el auto en la última muestra (zigzag: %.2f contra %.2f m a 0,2 s; %.2f contra %.2f m a 0,5 s; %.2f contra %.2f m a 2 s)" % [s02["mean"], s02["hold"], s05["mean"], s05["hold"], s20["mean"], s20["hold"]])
	# demora irregular de la red (cada muestra llega con entre 0 y 240 ms de demora): se corrige de a poco, no se ve a los saltos
	var j02 := _drive("circle", 0.2, 0.12)
	var j05 := _drive("slalom", 0.5, 0.12)
	print("con demora irregular: ", j02, " ", j05)
	check(j02["mean"] < 1.3 and j02["max"] < 3.5, "círculo con demora irregular de la red: error medio %.2f m, máximo %.2f m" % [j02["mean"], j02["max"]])
	check(j05["mean"] < 1.4 and j05["max"] < 3.2, "zigzag con demora irregular de la red: error medio %.2f m, máximo %.2f m" % [j05["mean"], j05["max"]])
	# protocolo nuevo (15/10/2026): cada muestra trae la hora en que se tomó → la demora irregular de la red casi no se nota (se dibuja proyectado al presente)
	var st02 := _drive("circle", 0.25, 0.12, false, true)
	var st05 := _drive("slalom", 0.25, 0.12, false, true)
	var sl10 := _drive("slalom", 1.0, 0.12, false, true)
	print("con hora de la muestra: ", st02, " ", st05, " ", sl10)
	check(st02["mean"] < 0.15 and st02["max"] < 0.6 and st05["mean"] < 0.5 and st05["max"] < 1.0, "con la hora de cada muestra (4 por s) y demora irregular: círculo %.2f m (máx %.2f), zigzag %.2f m (máx %.2f) de error contra el auto real AHORA" % [st02["mean"], st02["max"], st05["mean"], st05["max"]])
	check(st02["step"] < 0.1 and st05["step"] < 0.15, "y sin saltos: a lo sumo %.2f m por cuadro de diferencia" % maxf(st02["step"], st05["step"]))
	check(sl10["mean"] < 3.0 and sl10["step"] < 0.6, "una muestra por segundo (muchos jugadores en la celda; el peor caso: zigzag continuo): %.2f m de error medio, %.2f m por cuadro" % [sl10["mean"], sl10["step"]])
	# no salta: el paso de un cuadro a otro no se aparta mucho de lo que avanza el auto de verdad
	check(c02["step"] < 0.05 and s02["step"] < 0.05 and c05["step"] < 0.05 and s05["step"] < 0.1 and c20["step"] < 0.2, "no salta: el paso de un cuadro se aparta de lo real a lo sumo %.2f m con Realtime y %.2f m con una muestra cada 2 s (círculo)" % [maxf(c02["step"], s02["step"]), c20["step"]])
	check(j02["step"] < 0.5 and j05["step"] < 0.5, "con demora irregular de la red tampoco: a lo sumo %.2f m por cuadro de diferencia" % maxf(j02["step"], j05["step"]))
	# la consulta periódica no trae el rumbo: sale de hacia dónde se movió el auto entre dos consultas
	var t20 := _drive("circle", 2.0, 0.0, true)
	var t05 := _drive("circle", 0.5, 0.0, true)
	var tz05 := _drive("slalom", 0.5, 0.0, true)
	print("sin rumbo: ", t20, " ", t05, " ", tz05)
	check(t20["mean"] < 2.2 and t20["max"] < 6.0, "consulta periódica sin rumbo, círculo, una muestra cada 2 s: error medio %.2f m, máximo %.2f m" % [t20["mean"], t20["max"]])
	check(t05["mean"] < 0.3 and tz05["mean"] < 1.5, "sin rumbo, una muestra cada 0,5 s: círculo %.2f m, zigzag %.2f m de error medio" % [t05["mean"], tz05["mean"]])
	# el rumbo cruza ±π sin dar la vuelta entera
	var m := RemoteMotion.new()
	var t := 0.0
	var worst_dyaw := 0.0
	var prev_yaw := 2.9
	for i in 300:
		var yw := 2.9 + (20.0 / 90.0) * t
		var pp := Vector2(90.0 * cos(2.9), -90.0 * sin(2.9)) + Vector2(-90.0 * cos(yw), 90.0 * sin(yw))
		if i % 6 == 0:
			m.push_sample(pp, yw, 20.0, t)
		m.step(t, 1.0 / FPS)
		worst_dyaw = maxf(worst_dyaw, absf(wrapf(m.yaw - prev_yaw, -PI, PI)))
		prev_yaw = m.yaw
		t += 1.0 / FPS
	check(worst_dyaw < 0.02, "el rumbo cruza ±π sin saltar (mayor cambio por cuadro %.3f rad; el auto gira %.3f rad por cuadro)" % [worst_dyaw, 20.0 / 90.0 / FPS])
	# un salto grande (otro lado del mapa) se corta en seco
	m = RemoteMotion.new()
	m.push_sample(Vector2(0, 0), 0.0, 10.0, 0.0)
	m.step(0.1, 0.016)
	m.push_sample(Vector2(5000, -3000), 1.0, 10.0, 0.5)
	check(m.pos.distance_to(Vector2(5000, -3000)) < 1.0, "un salto de miles de metros se corta en seco (no se desliza por todo el mapa)")
	# la misma muestra otra vez no hace nada raro
	m = RemoteMotion.new()
	m.push_sample(Vector2(0, 0), 0.0, 20.0, 0.0)
	m.push_sample(Vector2(0, 10), 0.0, 20.0, 0.5)
	var before := m.estimate(0.7)
	m.push_sample(Vector2(0, 10), 0.0, 20.0, 0.5)
	m.push_sample(Vector2(0, 10), 0.0, 20.0, 0.51)
	var after := m.estimate(0.7)
	check((before[0] as Vector2).distance_to(after[0] as Vector2) < 0.001, "una muestra repetida no cambia la estimación")
	# se corta la señal: sigue un rato, frena solo y no se va al infinito
	m = RemoteMotion.new()
	m.push_sample(Vector2(0, 0), 0.0, 25.0, 0.0)
	m.push_sample(Vector2(0, 5), 0.0, 25.0, 0.2)
	t = 0.2
	var at_1s := 0.0
	for i in 60 * 14:
		m.step(t, 1.0 / FPS)
		t += 1.0 / FPS
		if absf(t - 1.2) < 0.009:
			at_1s = m.pos.distance_to(Vector2(0, 5))
	var dist := m.pos.distance_to(Vector2(0, 5))
	check(at_1s > 12.0 and dist < 25.0 * 4.0 and m.speed < 0.5, "si se corta la señal sigue un rato (%.0f m en el primer segundo), se queda a %.0f m de la última muestra (no sigue de largo) y para (%.1f m/s)" % [at_1s, dist, m.speed])
	# con consulta lenta (2 s) espera más antes de frenar que con Realtime
	var slow := RemoteMotion.new()
	var fast := RemoteMotion.new()
	t = 0.0
	for i in int(14.0 * FPS):
		if i % int(2.0 * FPS) == 0:
			slow.push_sample(Vector2(0, t * 20.0), 0.0, 20.0, t)
		if i % int(0.2 * FPS) == 0:
			fast.push_sample(Vector2(0, t * 20.0), 0.0, 20.0, t)
		slow.step(t, 1.0 / FPS)
		fast.step(t, 1.0 / FPS)
		t += 1.0 / FPS
	check(slow.hold_time() > fast.hold_time() + 1.0 and fast.hold_time() < 1.2 and slow.hold_time() > 2.5, "con consulta lenta espera más antes de frenar (%.1f s) que con Realtime (%.1f s)" % [slow.hold_time(), fast.hold_time()])
	# parado: no se mueve solo
	m = RemoteMotion.new()
	m.push_sample(Vector2(100, 100), 1.0, 0.0, 0.0)
	for i in 300:
		m.step(float(i) / FPS, 1.0 / FPS)
	check(m.pos.distance_to(Vector2(100, 100)) < 0.01 and m.speed < 0.01, "parado se queda parado")
	# ruedas, balanceo y cabeceo
	m = RemoteMotion.new()
	t = 0.0
	for i in 240: # giro hacia donde aumenta el rumbo (r 60 m) a 20 m/s
		var yw := (20.0 / 60.0) * t
		var pp := Vector2(60.0 * (1.0 - cos(yw)), 60.0 * sin(yw))
		if i % 12 == 0:
			m.push_sample(pp, yw, 20.0, t)
		m.step(t, 1.0 / FPS)
		t += 1.0 / FPS
	check(m.steer > 0.03 and m.steer < 0.5, "al doblar las ruedas delanteras se orientan hacia donde gira el rumbo (%.3f rad)" % m.steer)
	check(m.roll > 0.01 and m.roll <= 0.07, "la carrocería se balancea (%.3f rad)" % m.roll)
	check(absf(m.wheel_omega(0.33) - m.speed / 0.33) < 1e-6, "las ruedas giran a la velocidad del auto (%.1f rad/s)" % m.wheel_omega(0.33))
	m = RemoteMotion.new()
	t = 0.0
	var p := Vector2.ZERO
	var vv := 30.0
	for i in 180: # frenada fuerte (de 30 a 0 m/s en 3 s), muestras cada 0,2 s
		if i % 12 == 0:
			m.push_sample(p, 0.0, vv, t)
		m.step(t, 1.0 / FPS)
		vv = maxf(0.0, vv - 10.0 / FPS)
		p.y += vv / FPS
		t += 1.0 / FPS
	check(m.pitch > 0.0, "al frenar la trompa baja (cabeceo %.3f rad)" % m.pitch)
	print("REMOTE_MOTION_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
