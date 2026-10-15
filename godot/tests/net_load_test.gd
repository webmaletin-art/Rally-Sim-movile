## Carga y fluidez del mundo online (15/10/2026, «online fluido»): 2, 5, 10 y 20 jugadores SIMULADOS con el protocolo real (cada uno su WebSocket, realtime.gd +
## world_sync.gd, contra tools/online/mock_realtime.py: Phoenix, canales privados, presencia y broadcast), manejando en círculos en la misma celda.
## Cada uno dibuja a los demás con remote_motion.gd y se compara con dónde están de verdad. Mide: mensajes mandados y recibidos por segundo, mensajes que
## cobraría Supabase (1 por envío + 1 por entrega), el hueco más largo entre muestras, el error del auto dibujado contra el real y el salto más grande por cuadro.
## Además: cruzar el borde de una celda, cerrar el juego de golpe y volver a entrar al mundo.
## NO es un teléfono: todo corre en una PC, con la red local (sin la demora ni las pérdidas de un 4G). Sirve para comparar ritmos y encontrar errores de lógica.
## Uso: godot --headless --path godot --script res://tests/net_load_test.gd   (≈ 1,5 min)
extends SceneTree

const Realtime := preload("res://game/online/realtime.gd")
const WorldSync := preload("res://game/online/world_sync.gd")
const RemoteMotion := preload("res://game/online/remote_motion.gd")
const NT := preload("res://game/online/net_tuning.gd")

var fail := false
var pid := -1
var url := ""
var results: Array = []

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	_run()

func _start_mock(lag_ms := 0, jitter_ms := 0) -> int:
	var script := ProjectSettings.globalize_path("res://").path_join("../tools/online/mock_realtime.py").simplify_path()
	var r: Dictionary = OS.execute_with_pipe("python3", [script, "--port", "0", "--apikey", "testkey", "--lag", str(lag_ms), "--jitter", str(jitter_ms)])
	if r.is_empty():
		return -1
	pid = int(r["pid"])
	var line := (r["stdio"] as FileAccess).get_line()
	return int(line.substr(5)) if line.begins_with("PORT ") else -1

func _client(uid: String) -> Array:
	var rt: Node = Realtime.new()
	root.add_child(rt)
	rt.configure(url, "testkey")
	rt.set_token("user:" + uid)
	rt.connect_socket()
	var ws: Node = WorldSync.new()
	root.add_child(ws)
	ws.setup_with(rt, uid)
	return [rt, ws]

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Dónde está de verdad el jugador i a la hora t: un círculo propio (todos a menos de ~400 m entre sí, en el medio de la celda 0:0)
func _truth(i: int, t: float) -> Array:
	var c := Vector2(1000.0 + 90.0 * float(i % 5), 1000.0 + 90.0 * float(i / 5))
	var r := 45.0 + 6.0 * float(i % 4)
	var v := 16.0 + 1.5 * float(i % 6)
	var w := v / r
	var th := w * t + float(i)
	var p := c + Vector2(cos(th), sin(th)) * r
	var vel := Vector2(-sin(th), cos(th)) * v
	return [p, atan2(vel.x, vel.y), v]

func _uid(prefix: String, i: int) -> String:
	return "%s-%04d-xxxxxxxx" % [prefix, i]

## N jugadores manejando juntos durante `secs` s (los primeros `warm` no cuentan)
func _scenario(n: int, secs: float, warm: float) -> Dictionary:
	var cl: Array = []
	var ids: Array = []
	for i in n:
		ids.append(_uid("p%d" % n, i))
		cl.append(_client(ids[i]))
	var motions: Dictionary = {} # "receptor|emisor" → RemoteMotion
	var last_rx: Dictionary = {} # "receptor|emisor" → hora de la última muestra
	var gaps: Array = []
	var left := [0]
	var t0 := [_now()]
	for r in n:
		var rr: int = r
		var ws: Node = cl[r][1]
		ws.car_state.connect(func(id: String, st: Dictionary) -> void:
			var key := "%d|%s" % [rr, id]
			if not motions.has(key):
				motions[key] = RemoteMotion.new()
			(motions[key] as RefCounted).push_sample(Vector2(float(st["x"]), float(st["z"])), float(st["yaw"]), float(st["kmh"]) / 3.6, float(st["t"]), float(st["arr"]))
			var now := _now()
			if last_rx.has(key) and now - t0[0] > warm:
				gaps.append(now - float(last_rx[key]))
			last_rx[key] = now)
		ws.car_left.connect(func(_id: String) -> void: left[0] += 1)
	t0[0] = _now()
	var sent0 := 0
	var recv0 := 0
	var errs: PackedFloat32Array = PackedFloat32Array()
	var jump := 0.0
	var prev: Dictionary = {}
	var frames := 0
	var measuring := false
	var tm := 0.0
	var last := _now()
	while _now() - t0[0] < secs:
		var now := _now()
		var dt := maxf(now - last, 0.001)
		last = now
		var t: float = now - float(t0[0])
		if not measuring and t > warm:
			measuring = true
			tm = now
			sent0 = 0
			recv0 = 0
			for c in cl:
				sent0 += int((c[1] as Node).stats["sent"])
				recv0 += int((c[1] as Node).stats["received"])
			left[0] = 0
		for i in n:
			var tr := _truth(i, t)
			(cl[i][1] as Node).update_me(dt, (tr[0] as Vector2).x, (tr[0] as Vector2).y, float(tr[1]), float(tr[2]) * 3.6)
		for key in motions:
			var m: RefCounted = motions[key]
			m.step(now, dt)
			if measuring and m.has:
				var sender := ids.find(str(key).get_slice("|", 1))
				var tr2 := _truth(sender, now + dt - t0[0])
				errs.append(m.pos.distance_to(tr2[0]))
				if prev.has(key):
					jump = maxf(jump, absf(m.pos.distance_to(prev[key]) - float(tr2[2]) * dt))
				prev[key] = m.pos
		frames += 1
		await process_frame
	var dur := _now() - tm
	var sent := 0
	var recv := 0
	for c in cl:
		sent += int((c[1] as Node).stats["sent"])
		recv += int((c[1] as Node).stats["received"])
	sent -= sent0
	recv -= recv0
	errs.sort()
	var mean := 0.0
	for e in errs:
		mean += e
	mean /= float(maxi(errs.size(), 1))
	var p95 := errs[int(errs.size() * 0.95)] if errs.size() > 0 else 0.0
	gaps.sort()
	var gmax := float(gaps[gaps.size() - 1]) if not gaps.is_empty() else 99.0
	var g95 := float(gaps[int(gaps.size() * 0.95)]) if not gaps.is_empty() else 99.0
	var old_hz := clampf(60.0 / float(n * (n - 1)), 0.5, 5.0) # (los ritmos de antes del 15/10/2026, para comparar)
	var res := {"n": n, "sent_s": float(sent) / dur, "sent_per_player": float(sent) / dur / float(n), "recv_per_player": float(recv) / dur / float(n),
		"billed_s": float(sent + recv) / dur, "billed_old_s": old_hz * float(n) * float(n), "err_mean": mean, "err_p95": p95, "jump_max": jump,
		"gap_p95": g95, "gap_max": gmax, "left": left[0], "fps": float(frames) / secs}
	for c in cl:
		(c[0] as Node).close_socket()
		(c[1] as Node).queue_free()
		(c[0] as Node).queue_free()
	await process_frame
	return res

func _run() -> void:
	var port := _start_mock()
	check(port > 0, "arrancó el servidor de Realtime de mentira")
	if port <= 0:
		_finish()
		return
	url = "http://127.0.0.1:%d" % port
	for n in [2, 5, 10, 20]:
		var r := await _scenario(n, 11.0, 4.0)
		results.append(r)
		print("  N=%2d · manda %.1f/s c/u · recibe %.1f/s c/u · Supabase cobraría %.0f msj/s (antes %.0f) · error medio %.2f m (95%% %.2f m) · salto máx %.2f m/cuadro · hueco entre muestras 95%% %.2f s, máx %.2f s · bajas %d · %.0f cuadros/s"
			% [r["n"], r["sent_per_player"], r["recv_per_player"], r["billed_s"], r["billed_old_s"], r["err_mean"], r["err_p95"], r["jump_max"], r["gap_p95"], r["gap_max"], r["left"], r["fps"]])
	var r2: Dictionary = results[0]
	var r5: Dictionary = results[1]
	var r10: Dictionary = results[2]
	var r20: Dictionary = results[3]
	check(float(r2["err_mean"]) < 0.5 and float(r2["err_p95"]) < 1.2 and float(r5["err_mean"]) < 1.0, "2 y 5 jugadores juntos: el auto del otro se dibuja a %.2f / %.2f m de donde está de verdad (en promedio)" % [r2["err_mean"], r5["err_mean"]])
	check(float(r2["jump_max"]) < 0.6 and float(r5["jump_max"]) < 0.8 and float(r10["jump_max"]) < 1.5, "sin teletransportes: el salto más grande entre cuadros es %.2f m (2), %.2f m (5), %.2f m (10)" % [r2["jump_max"], r5["jump_max"], r10["jump_max"]])
	check(int(r2["left"]) == 0 and int(r5["left"]) == 0 and int(r10["left"]) == 0 and int(r20["left"]) == 0, "nadie desaparece mientras maneja (bajas: %d / %d / %d / %d)" % [r2["left"], r5["left"], r10["left"], r20["left"]])
	check(float(r2["billed_s"]) <= float(r2["billed_old_s"]) * 1.05 and float(r5["billed_s"]) < float(r5["billed_old_s"]), "con 2 y 5 jugadores juntos se cobran menos mensajes que antes (%.0f contra %.0f; %.0f contra %.0f por s)" % [r2["billed_s"], r2["billed_old_s"], r5["billed_s"], r5["billed_old_s"]])
	check(float(r20["billed_s"]) < 500.0, "20 juntos en una celda: %.0f mensajes/s (el tope del plan Pro es 500/s)" % r20["billed_s"])
	await _border_and_disconnect()
	# la misma prueba con una red «de teléfono»: 60 ms de demora + hasta 120 ms más al azar en cada mensaje (en orden), como un 4G regular
	OS.kill(pid)
	port = _start_mock(60, 120)
	url = "http://127.0.0.1:%d" % port
	var j2 := await _scenario(2, 11.0, 4.0)
	var j5 := await _scenario(5, 11.0, 4.0)
	for r in [j2, j5]:
		print("  4G N=%2d · error medio %.2f m (95%% %.2f m) · salto máx %.2f m/cuadro · hueco 95%% %.2f s" % [r["n"], r["err_mean"], r["err_p95"], r["jump_max"], r["gap_p95"]])
	check(float(j2["err_mean"]) < 1.0 and float(j2["jump_max"]) < 0.6 and float(j5["jump_max"]) < 0.8, "con demora irregular de 4G: error medio %.2f m y salto máximo %.2f m por cuadro (2 jugadores)" % [j2["err_mean"], j2["jump_max"]])
	_finish()

## Cruzar el borde de una celda, cerrar el juego de golpe y volver a entrar
func _border_and_disconnect() -> void:
	var a := _client(_uid("cruza", 1))
	var b := _client(_uid("mira", 2))
	var c := _client(_uid("cierra", 3))
	var rx: Dictionary = {}
	var gap_a := [0.0, -1.0]
	var left_b: Array = []
	(b[1] as Node).car_state.connect(func(id: String, _st: Dictionary) -> void:
		var now := _now()
		if id == _uid("cruza", 1) and float(gap_a[1]) > 0.0:
			gap_a[0] = maxf(float(gap_a[0]), now - float(gap_a[1]))
		if id == _uid("cruza", 1):
			gap_a[1] = now
		rx[id] = int(rx.get(id, 0)) + 1)
	(b[1] as Node).car_left.connect(func(id: String) -> void: left_b.append([id, _now()]))
	# a cruza de la celda 0:0 a la 1:0 (x = 2000) a 25 m/s; b está quieto al lado del borde; c quieto cerca
	var t0 := _now()
	var last := t0
	var x := 1880.0
	while _now() - t0 < 9.0:
		var now := _now()
		var dt := maxf(now - last, 0.001)
		last = now
		x += 25.0 * dt
		(a[1] as Node).update_me(dt, x, 1000.0, PI * 0.5, 90.0)
		(b[1] as Node).update_me(dt, 1985.0, 1010.0, 0.0, 0.0)
		(c[1] as Node).update_me(dt, 1960.0, 990.0, 0.0, 0.0)
		await process_frame
	check(x > 2050.0 and (a[1] as Node).my_cell == Vector2i(1, 0), "el que cruza ya está en la celda vecina (x = %.0f)" % x)
	check(float(gap_a[0]) < 1.0 and left_b.filter(func(l) -> bool: return str(l[0]) == _uid("cruza", 1)).is_empty(), "al cruzar el borde el otro lo sigue viendo sin cortes (hueco máximo %.2f s) y no lo da de baja" % gap_a[0])
	# c cierra el juego de golpe (sin despedirse): b lo da de baja por la presencia, sin esperar los %d s
	(c[0] as Node).wanted = false
	(c[0] as Node)._send_raw("realtime:mock", "__test_drop", {}, "99", "")
	var t_drop := _now()
	while _now() - t_drop < 8.0 and left_b.filter(func(l) -> bool: return str(l[0]) == _uid("cierra", 3)).is_empty():
		var now2 := _now()
		var dt2 := maxf(now2 - last, 0.001)
		last = now2
		(a[1] as Node).update_me(dt2, x, 1000.0, PI * 0.5, 0.0)
		(b[1] as Node).update_me(dt2, 1985.0, 1010.0, 0.0, 0.0)
		await process_frame
	var gone := left_b.filter(func(l) -> bool: return str(l[0]) == _uid("cierra", 3))
	check(not gone.is_empty() and float(gone[0][1]) - t_drop < NT.GONE_S, "si uno cierra el juego de golpe, el otro lo saca en %.1f s (por la presencia; sin eso tardaría %d s)" % [(float(gone[0][1]) - t_drop) if not gone.is_empty() else 99.0, int(NT.GONE_S)])
	# a sale del mundo y vuelve a entrar (escena nueva, cliente nuevo, mismo jugador): b vuelve a recibirlo enseguida
	(a[0] as Node).close_socket()
	(a[1] as Node).queue_free()
	(a[0] as Node).queue_free()
	await process_frame
	var n_before := int(rx.get(_uid("cruza", 1), 0))
	var a2 := _client(_uid("cruza", 1))
	var t_back := _now()
	var got_back := -1.0
	while _now() - t_back < 8.0 and got_back < 0.0:
		var now3 := _now()
		var dt3 := maxf(now3 - last, 0.001)
		last = now3
		x += 20.0 * dt3
		(a2[1] as Node).update_me(dt3, x, 1000.0, PI * 0.5, 72.0)
		(b[1] as Node).update_me(dt3, 1985.0, 1010.0, 0.0, 0.0)
		if int(rx.get(_uid("cruza", 1), 0)) > n_before:
			got_back = _now() - t_back
		await process_frame
	check(got_back >= 0.0 and got_back < 3.0, "al volver a entrar al mundo el otro lo recibe en %.1f s (sin descartar sus mensajes como viejos)" % got_back)
	check(int((b[0] as Node).channels().filter(func(ch) -> bool: return str(ch).begins_with("world:")).size()) <= 4, "sin canales de más")
	for cc in [a2, b, c]:
		(cc[0] as Node).close_socket()

func _finish() -> void:
	if pid > 0:
		OS.kill(pid)
	print("NET_LOAD_TEST ", "FALLÓ" if fail else "OK")
	quit(1 if fail else 0)
