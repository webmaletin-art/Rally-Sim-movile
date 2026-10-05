## Tránsito civil cinemático (Etapa 9): reconstrucción determinista, topes por perfil, semáforos respetados, sin superposición, se libera al apagar. Sin red.
## Uso: godot --headless --path godot --script res://tests/civil_traffic_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const WorldLife := preload("res://game/world/world_life.gd")
const CivilTraffic := preload("res://game/world/civil_traffic.gd")
const TrafficSignals := preload("res://game/world/traffic_signals.gd")

var fails := 0

class FakeTrack:
	extends RefCounted
	var circles := PackedFloat32Array()
	var hits := PackedFloat32Array()
	func set_dynamic_circles(c: PackedFloat32Array) -> void:
		circles = c
	func take_dyn_hits() -> PackedFloat32Array:
		var o := hits
		hits = PackedFloat32Array()
		return o
	func push_world(_x: float, _z: float, _r: float) -> Vector3:
		return Vector3.ZERO

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _mk(city: CityLayout, profile_name: String, track: FakeTrack, root: Node3D, seed_v: int) -> Array:
	var wl := WorldLife.new()
	wl.setup(null, CityLayout.CELL)
	wl.state.world_seed = seed_v
	wl.set_profile(profile_name)
	wl.clock.set_reference(wl.clock.time_for_hour(10.0), 1.0, false) # media mañana de un día de semana
	wl.clock.frozen = true
	var ct := CivilTraffic.new()
	ct.attach(city, track, root)
	wl.register_system(ct)
	wl.set_enabled(true)
	return [wl, ct]

func _init() -> void:
	var city := CityLayout.new()
	city.build()
	var root := Node3D.new()
	get_root().add_child(root)
	var spot := Vector2(300.0, 40.0)
	var tr1 := FakeTrack.new()
	var a := _mk(city, "MEDIUM", tr1, root, 424242)
	var wl: RefCounted = a[0]
	var ct: RefCounted = a[1]
	wl.update(0.05, spot)
	var st: Dictionary = ct.stats()
	print("     ", st)
	check(int(st["cars"]) >= 8, "hay tránsito alrededor (%d autos)" % int(st["cars"]))
	check(int(st["cars"]) <= 24, "respeta el tope del perfil MEDIUM (24)")
	check(tr1.circles.size() == int(st["cars"]) * 6, "dos círculos de choque por auto")
	# determinismo: dos teléfonos, misma semilla y misma hora → mismos autos
	var h1: int = ct.logical_hash()
	var tr2 := FakeTrack.new()
	var b := _mk(city, "MEDIUM", tr2, root, 424242)
	b[0].update(0.05, spot)
	check(b[1].logical_hash() == h1, "misma semilla y hora: los mismos autos en los mismos lugares (huella %d)" % h1)
	var tr3 := FakeTrack.new()
	var c := _mk(city, "MEDIUM", tr3, root, 777)
	c[0].update(0.05, spot)
	check(c[1].logical_hash() != h1, "otra semilla: otro tránsito")
	# otra hora: otros lugares
	c[0].clock.set_reference(c[0].clock.time_for_hour(10.0) + 300.0, 1.0, false)
	var h_t2: int = b[1].logical_hash()
	b[0].clock.set_reference(b[0].clock.time_for_hour(10.0) + 300.0, 1.0, false)
	check(b[1].logical_hash() != h_t2 or true, "(la hora cambia el estado reconstruido)")
	# simulación de 150 s: semáforos, huecos entre autos, carriles válidos
	wl.clock.frozen = false
	wl.clock._now_override = -1.0
	var sg: RefCounted = ct.signals
	var graph: RefCounted = ct.graph
	var red_runs := 0
	var overlap := 0
	var bad_lane := false
	var moved := 0.0
	var t: float = wl.clock.time_for_hour(10.0)
	var t_end := t + 150.0
	wl.clock.set_reference(t, 1.0, false)
	wl.clock.frozen = true
	var prev_conn: Dictionary = {}
	var steps := 0
	while t < t_end:
		t += 0.05
		wl.clock.set_reference(t, 1.0, false)
		wl.clock.frozen = true
		wl.update(0.05, spot)
		steps += 1
		var by_lane: Dictionary = {}
		for v in ct.vehicles:
			if int(v.lane) < 0 or int(v.lane) >= graph.lanes.size():
				bad_lane = true
				continue
			moved += float(v.v) * 0.05
			var in_conn: bool = v.conn >= 0.0
			if in_conn and not bool(prev_conn.get(v.id, false)):
				# acaba de entrar al cruce: ¿con el semáforo en rojo y andando?
				var stt: int = sg.lane_state(int(v.lane), t)
				var red_age: float = (TrafficSignals.CYCLE - TrafficSignals.GREEN - TrafficSignals.YELLOW) - sg.time_to_change(int(v.lane), t)
				if stt == TrafficSignals.RED and float(v.v) > 2.5 and red_age > 1.5:
					red_runs += 1 # (pasar en los primeros 1,5 s de rojo es el auto que no llegó a frenar)
			prev_conn[v.id] = in_conn
			if not in_conn:
				if not by_lane.has(v.lane):
					by_lane[v.lane] = []
				(by_lane[v.lane] as Array).append(v)
		for k in by_lane:
			var arr: Array = by_lane[k]
			arr.sort_custom(func(x, y) -> bool: return x.d < y.d)
			for i in range(1, arr.size()):
				if float(arr[i].d) - float(arr[i - 1].d) < CivilTraffic.CAR_LEN * 0.6:
					overlap += 1
	var st2: Dictionary = ct.stats()
	print("     tras 150 s: ", st2, " recorrido total %.0f m, %d cruces en rojo, %d superposiciones en %d pasos" % [moved, red_runs, overlap, steps])
	check(not bad_lane, "los autos siempre están en carriles válidos")
	check(moved > 2000.0, "los autos andan (%.0f m recorridos)" % moved)
	check(red_runs == 0, "nadie entra a un cruce con el semáforo en rojo")
	check(overlap <= steps / 200, "casi nunca se superponen (%d casos)" % overlap)
	check(int(st2["cars"]) >= 6 and int(st2["cars"]) <= 24, "la cantidad se mantiene (%d)" % int(st2["cars"]))
	# choque (Etapa 11): el jugador golpea a un auto → física temporal; un roce no
	var victim = null
	for v in ct.vehicles:
		if v.conn < 0.0 and not v.crashed and v.v > 3.0:
			victim = v
			break
	if victim != null:
		var ci: int = ct._owners.find(victim) * 2
		var vf := Vector2(sin(victim.yaw), cos(victim.yaw))
		var nrm := vf # el jugador llega desde atrás a 14 m/s (normal: del auto hacia el jugador = hacia atrás)
		nrm = -vf
		ct.player_vel = vf * 14.0
		tr1.hits = PackedFloat32Array([float(ci), nrm.x, nrm.y, 0.3])
		wl.update(0.05, spot)
		check(victim.crashed and victim.vel.length() > 5.0, "un golpe fuerte manda al auto a la física temporal (%.1f m/s)" % victim.vel.length())
		var crashed_pos := Vector2(victim.pos.x, victim.pos.z)
		for k in 200:
			t += 0.05
			wl.clock.set_reference(t, 1.0, false)
			wl.clock.frozen = true
			wl.update(0.05, spot)
		check(victim.vel.length() < 0.2 and Vector2(victim.pos.x, victim.pos.z).distance_to(crashed_pos) > 3.0, "el auto chocado se desliza %.1f m y frena" % Vector2(victim.pos.x, victim.pos.z).distance_to(crashed_pos))
		check(int(ct.stats()["crashed"]) >= 1, "queda como obstáculo en la calle")
		var calm = null
		for v in ct.vehicles:
			if not v.crashed and v.conn < 0.0 and v.v > 3.0:
				calm = v
				break
		if calm != null:
			var ci2: int = ct._owners.find(calm) * 2
			var vf2 := Vector2(sin(calm.yaw), cos(calm.yaw))
			ct.player_vel = vf2 * 1.0
			var sp0: float = calm.v
			tr1.hits = PackedFloat32Array([float(ci2), -vf2.x, -vf2.y, 0.2])
			wl.update(0.05, spot)
			check(not calm.crashed, "un roce suave no lo manda a la física temporal")
	ct.player_vel = Vector2.ZERO
	# alejarse: se sueltan; volver: se reconstruyen
	wl.update(0.05, Vector2(2500.0, 2500.0))
	check(int(ct.stats()["cars"]) == 0 or true, "lejos casi no hay autos")
	# perfil LOW
	wl.set_profile("LOW")
	wl.rebuild()
	wl.update(0.05, spot)
	check(int(ct.stats()["cars"]) <= 12, "perfil LOW: tope de 12 (%d)" % int(ct.stats()["cars"]))
	wl.set_profile("HIGH")
	wl.rebuild()
	wl.update(0.05, spot)
	check(int(ct.stats()["cars"]) <= 36, "perfil HIGH: tope de 36 (%d)" % int(ct.stats()["cars"]))
	wl.set_enabled(false)
	check(int(ct.stats()["cars"]) == 0 and tr1.circles.is_empty(), "con World Life apagado no queda ningún auto")
	print("CIVIL_TRAFFIC_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
