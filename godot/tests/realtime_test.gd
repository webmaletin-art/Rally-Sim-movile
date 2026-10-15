## Realtime listo para conectar: reglas de celdas y de ritmo, validación de mensajes, y el cliente (realtime.gd + world_sync.gd) contra un servidor de mentira
## (tools/online/mock_realtime.py: protocolo Phoenix, canales privados sólo para cuentas, presencia, broadcast). Sin red ni cuenta.
## Uso: godot --headless --path godot --script res://tests/realtime_test.gd
extends SceneTree

const Realtime := preload("res://game/online/realtime.gd")
const WorldSync := preload("res://game/online/world_sync.gd")

var fail := false
var pid := -1

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	_run()

func _wait(cond: Callable, seconds := 5.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		if cond.call():
			return true
		await process_frame
	return cond.call()

func _pause(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await process_frame

func _start_mock() -> int:
	var script := ProjectSettings.globalize_path("res://").path_join("../tools/online/mock_realtime.py").simplify_path()
	var r: Dictionary = OS.execute_with_pipe("python3", [script, "--port", "0", "--apikey", "testkey"])
	if r.is_empty():
		return -1
	pid = int(r["pid"])
	var io: FileAccess = r["stdio"]
	var line := io.get_line()
	if not line.begins_with("PORT "):
		return -1
	return int(line.substr(5))

func _client(url: String, tok: String) -> Node:
	var rt: Node = Realtime.new()
	root.add_child(rt)
	rt.configure(url, "testkey")
	rt.set_token(tok)
	return rt

func _run() -> void:
	# ───── reglas puras ─────
	check(Realtime.socket_url("https://abc.supabase.co/", "k k") == "wss://abc.supabase.co/realtime/v1/websocket?apikey=k%20k&vsn=1.0.0", "la dirección del socket sale de la dirección del proyecto")
	check(Realtime.socket_url("http://127.0.0.1:99", "k").begins_with("ws://127.0.0.1:99/"), "http de prueba → ws")
	var j: Dictionary = JSON.parse_string(Realtime.encode("realtime:x", "phx_join", Realtime.join_payload("tok", "me", true), "3", "3"))
	check(str(j["event"]) == "phx_join" and bool(j["payload"]["config"]["private"]) and str(j["payload"]["access_token"]) == "tok" and str(j["join_ref"]) == "3", "el pedido de entrada lleva canal privado, clave y sesión")
	check(WorldSync.cell_of(0.0, 0.0) == Vector2i(0, 0) and WorldSync.cell_of(-0.1, 1999.9) == Vector2i(-1, 0) and WorldSync.cell_of(2000.0, -2000.0) == Vector2i(1, -1), "celdas de 2 km")
	check(WorldSync.cells_for(1000.0, 1000.0).size() == 1, "en el medio de la celda sólo se escucha esa")
	check(WorldSync.cells_for(100.0, 1000.0).size() == 2 and WorldSync.cells_for(100.0, 1000.0)[1] == Vector2i(-1, 0), "cerca del borde oeste se suma la vecina")
	check(WorldSync.cells_for(1950.0, 1950.0).size() == 4, "en una esquina se escuchan 4 canales (el tope)")
	check(WorldSync.cells_for(800.0, 1000.0).size() == 1 and WorldSync.cells_for(800.0, 1000.0, [Vector2i(-1, 0)]).size() == 2, "histéresis: un canal abierto se mantiene un poco más")
	# ritmos del 15/10/2026 («online fluido», net_tuning.gd): del otro lado se interpola con búfer y se proyecta al presente, así que 4 por s alcanza para verse fluido
	check(is_equal_approx(WorldSync.rate_for(2), 4.0) and WorldSync.rate_for(3) == 4.0 and WorldSync.rate_for(5) == 2.0 and WorldSync.rate_for(8) == 1.0 and WorldSync.rate_for(30) == 0.5 and WorldSync.rate_for(1) == 0.2, "ritmo adaptativo con alguien cerca: solo 0,2 Hz · 2 a 3 → 4 Hz · 5 → 2 Hz · 8 → 1 Hz · 30 → 0,5 Hz")
	check(WorldSync.rate_for(3, 1500.0) == 1.0 and WorldSync.rate_for(3, 300.0) == 4.0, "con otros en la celda pero lejos (no se ven): 1 por s")
	var tp := WorldSync.unpack(WorldSync.pack("aaaaaaaa-1111", 1.0, 2.0, 0.5, 50.0, 3, 123456))
	check(absf(float(tp.get("ts", -1.0)) - 123.456) < 1e-6 and not WorldSync.unpack(WorldSync.pack("aaaaaaaa-1111", 1.0, 2.0, 0.5, 50.0, 3)).has("ts"), "el mensaje lleva la hora del que lo manda (y un cliente viejo, sin hora, se sigue leyendo)")
	var okp := WorldSync.pack("aaaaaaaa-1111", 123.456, -7.0, 1.2345, 99.6, 5)
	var up := WorldSync.unpack(okp)
	check(not up.is_empty() and absf(float(up["x"]) - 123.5) < 0.01 and int(up["kmh"]) == 100, "un mensaje bueno se lee")
	var bad_all := true
	for bp in [{}, {"i": "x", "x": 1, "z": 1, "a": 0, "v": 1}, {"i": "aaaaaaaa-1", "x": NAN, "z": 1, "a": 0, "v": 1}, {"i": "aaaaaaaa-1", "x": 9e9, "z": 1, "a": 0, "v": 1}, {"i": "aaaaaaaa-1", "x": 1, "z": 1, "a": 0, "v": 5000}, {"i": "aaaaaaaa-1", "x": "1", "z": 1, "a": 0, "v": 1}, {"i": 5, "x": 1, "z": 1, "a": 0, "v": 1}]:
		if not WorldSync.unpack(bp).is_empty():
			bad_all = false
	check(bad_all, "se descartan los mensajes imposibles (faltan datos, NaN, fuera del mapa, velocidad absurda, tipos raros)")
	# ───── cliente contra el servidor de mentira ─────
	var port := _start_mock()
	check(port > 0, "arrancó el servidor de mentira (puerto %d)" % port)
	if port <= 0:
		_finish()
		return
	await _pause(0.3)
	var url := "http://127.0.0.1:%d" % port
	var a := _client(url, "user:alice")
	var b := _client(url, "user:bob")
	var got_b: Array = []
	b.broadcast_received.connect(func(ch: String, ev: String, pl: Dictionary) -> void: got_b.append([ch, ev, pl]))
	var got_a: Array = []
	a.broadcast_received.connect(func(ch: String, ev: String, pl: Dictionary) -> void: got_a.append([ch, ev, pl]))
	a.connect_socket()
	b.connect_socket()
	a.join("world:0:0", {"private": true, "key": "alice"})
	b.join("world:0:0", {"private": true, "key": "bob"})
	check(await _wait(func() -> bool: return a.is_joined("world:0:0") and b.is_joined("world:0:0")), "dos cuentas entran al canal privado")
	# presencia
	a.track("world:0:0", {"who": "alice"})
	b.track("world:0:0", {"who": "bob"})
	check(await _wait(func() -> bool: return a.presence_count("world:0:0") == 2 and b.presence_count("world:0:0") == 2), "la presencia muestra a los dos")
	# broadcast: llega al otro y no a uno mismo
	check(a.send_broadcast("world:0:0", "s", {"x": 1.5}), "se manda un mensaje")
	check(await _wait(func() -> bool: return got_b.size() == 1), "el otro lo recibe")
	await _pause(0.3)
	check(got_a.is_empty() and got_b[0][1] == "s" and float(got_b[0][2]["x"]) == 1.5, "uno no recibe sus propios mensajes y el contenido llega entero")
	# tope de mensajes: una ráfaga larga se corta (no se manda de más)
	var sent_ok := 0
	for i in 40:
		if a.send_broadcast("world:0:0", "s", {"n": i}):
			sent_ok += 1
	check(sent_ok <= 6 and int(a.stats["dropped"]) >= 30, "el tope por canal frena las ráfagas (%d de 40 salieron)" % sent_ok)
	# sin permiso: una cuenta anónima y un tema que no es del mundo
	var c := _client(url, "anon")
	var errs: Array = []
	c.channel_error.connect(func(ch: String, why: String) -> void: errs.append([ch, why]))
	c.connect_socket()
	c.join("world:0:0", {"private": true, "key": "anon"})
	check(await _wait(func() -> bool: return errs.size() >= 1), "una cuenta anónima no entra al canal privado")
	check(str(errs[0][1]).to_lower().contains("permission") and not c.is_joined("world:0:0"), "el motivo es «sin permiso»")
	await _pause(0.5)
	check(errs.size() == 1, "y no insiste")
	b.join("chat:otro", {"private": true})
	check(await _wait(func() -> bool: return int(b.channels().size()) == 2) and not await _wait(func() -> bool: return b.is_joined("chat:otro"), 1.0), "un tema que no es de «world:» tampoco")
	b.leave("chat:otro")
	# latido
	a._hb_t = 0.05
	check(await _wait(func() -> bool: return a.rtt_ms >= 0.0, 3.0), "el latido vuelve (ida y vuelta %.1f ms)" % a.rtt_ms)
	# renovar la sesión
	a.set_token("user:alice")
	await _pause(0.3)
	check(a.is_joined("world:0:0") and a.state == "open", "renovar la sesión no corta el canal")
	# caída de red: se reconecta solo y vuelve a entrar al canal
	var closed := [false]
	a.socket_closed.connect(func(_c: int, _r: String) -> void: closed[0] = true)
	a._send_raw("realtime:mock", "__test_drop", {}, "99", "")
	check(await _wait(func() -> bool: return closed[0]), "se nota la caída")
	check(await _wait(func() -> bool: return a.state == "open" and a.is_joined("world:0:0"), 8.0), "se reconecta y vuelve a entrar a sus canales")
	check(int(a.stats["reconnects"]) >= 1, "cuenta la reconexión")
	# el que se va avisa
	a.leave("world:0:0")
	check(await _wait(func() -> bool: return b.presence_count("world:0:0") == 1), "al salir de un canal el otro deja de verlo en la presencia")
	a.join("world:0:0", {"private": true, "key": "alice"})
	await _wait(func() -> bool: return a.is_joined("world:0:0"))
	# ───── world_sync: dos jugadores en la misma celda y uno lejos ─────
	var wa: Node = WorldSync.new()
	var wb: Node = WorldSync.new()
	var wc: Node = WorldSync.new()
	root.add_child(wa)
	root.add_child(wb)
	root.add_child(wc)
	var ra := _client(url, "user:ana-0001-xxxxxxxx")
	var rb := _client(url, "user:beto-0002-xxxxxxx")
	var rc := _client(url, "user:caro-0003-xxxxxxx")
	ra.connect_socket()
	rb.connect_socket()
	rc.connect_socket()
	wa.setup_with(ra, "ana-0001-xxxxxxxx")
	wb.setup_with(rb, "beto-0002-xxxxxxx")
	wc.setup_with(rc, "caro-0003-xxxxxxx")
	var seen_b: Array = []
	var seen_c: Array = []
	wb.car_state.connect(func(id: String, st: Dictionary) -> void: seen_b.append([id, st]))
	wc.car_state.connect(func(id: String, st: Dictionary) -> void: seen_c.append([id, st]))
	var left_b: Array = []
	wb.car_left.connect(func(id: String) -> void: left_b.append(id))
	# ana y beto en la plaza (celda 0:0, medio); caro a 30 km. El tiempo que se le pasa a update_me es el real (los cuadros de la prueba corren mucho más rápido que 30 por segundo)
	var last := Time.get_ticks_msec()
	var t_end := last + 4000
	var x := 1000.0
	while Time.get_ticks_msec() < t_end:
		var now := Time.get_ticks_msec()
		var dt := float(now - last) / 1000.0
		last = now
		x += 8.0 * dt
		wa.update_me(dt, x, 1000.0, 1.0, 80.0)
		wb.update_me(dt, 1010.0, 1000.0, 0.0, 0.0)
		wc.update_me(dt, 30000.0, 30000.0, 0.0, 50.0)
		await process_frame
	check(my_cells_ok(wa, wb, wc), "cada uno escucha su celda: ana y beto la misma, caro otra")
	check(seen_b.size() >= 12 and seen_b.size() <= 40, "beto ve a ana moverse a un ritmo razonable (%d mensajes en 4 s)" % seen_b.size())
	check(seen_c.is_empty(), "caro, lejos, no recibe nada (las celdas ahorran mensajes)")
	if not seen_b.is_empty():
		var st: Dictionary = seen_b[seen_b.size() - 1][1]
		check(str(seen_b[0][0]) == "ana-0001-xxxxxxxx" and float(st["x"]) > 1000.0 and int(st["kmh"]) == 80, "el estado trae quién es, dónde está y a qué velocidad")
	# un jugador que se queda quieto casi no manda; el que se va se da de baja
	var before := int(wb.stats["sent"])
	last = Time.get_ticks_msec()
	var t2 := last + 2500
	while Time.get_ticks_msec() < t2:
		var now2 := Time.get_ticks_msec()
		wb.update_me(float(now2 - last) / 1000.0, 1010.0, 1000.0, 0.0, 0.0)
		last = now2
		await process_frame
	check(int(wb.stats["sent"]) - before <= 1, "quieto manda muy poco (%d en 2,5 s)" % [int(wb.stats["sent"]) - before])
	last = Time.get_ticks_msec()
	var t3 := last + 7500
	while Time.get_ticks_msec() < t3 and left_b.is_empty():
		var now3 := Time.get_ticks_msec()
		wb.update_me(float(now3 - last) / 1000.0, 1010.0, 1000.0, 0.0, 0.0)
		last = now3
		await process_frame
	check(left_b.has("ana-0001-xxxxxxxx"), "si ana deja de avisar, beto la da de baja")
	# cruzar de celda: se abre el canal nuevo
	check(await _wait(func() -> bool:
		wa.update_me(0.05, 1900.0, 1000.0, 1.0, 80.0)
		return ra.is_joined("world:1:0") and ra.is_joined("world:0:0")), "cerca del borde se suma el canal de la celda vecina")
	_finish()

func my_cells_ok(wa: Node, wb: Node, wc: Node) -> bool:
	return wa.my_cell == Vector2i(0, 0) and wb.my_cell == Vector2i(0, 0) and wc.my_cell == Vector2i(15, 15)

func _finish() -> void:
	if pid > 0:
		OS.kill(pid)
	print("REALTIME_TEST ", "FALLÓ" if fail else "OK")
	quit(1 if fail else 0)
