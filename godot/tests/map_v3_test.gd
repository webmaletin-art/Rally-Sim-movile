## Mapas v3 (editor en grilla): un OCHO que se cruza a nivel (alturas iguales, sin guardarraíl sobre el otro camino, el auto sigue al camino que tiene más cerca, la IA da la vuelta sin
## saltar de camino), un recorrido A→B cerrado por el juego, y las reglas de PERSECUCIÓN y ELIMINACIÓN (lógica y una persecución simulada con física real).
## Uso: godot --headless --path godot --script res://tests/map_v3_test.gd
extends SceneTree

const MapData := preload("res://game/data/map_data.gd")
const RouteTrack := preload("res://game/track/route_track.gd")
const Session := preload("res://game/session.gd")
const RaceRules := preload("res://game/race_rules.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

class Snap:
	var px := 0.0
	var pz := 0.0
	var vx := 0.0
	var vz := 0.0

class FakeCar:
	var driver = null
	var phys: RefCounted
	var snap := Snap.new()
	var out := false
	var visual := Node3D.new()
	func place(_x: float, _z: float, _yaw: float) -> void:
		pass

class FakePhys:
	extends RefCounted
	var powerMul := 1.0

func _load(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _init() -> void:
	var ocho: Dictionary = MapData.convert_doc(_load("res://tests/data_v3/ocho.json"))
	var ab: Dictionary = MapData.convert_doc(_load("res://tests/data_v3/ab.json"))
	check(not ocho.is_empty() and not ab.is_empty(), "convierte los dos mapas v3")
	var routes: Dictionary = MapData.load_all()["routes"]
	routes["ej_ocho"] = ocho["route"]
	routes["ej_ab"] = ab["route"]
	RouteTrack._routes = routes

	# ───── A→B ─────
	var abm: Dictionary = ab["map"]
	var seg: Array = abm["defaults"]["seg"]
	var tab = RouteTrack.new("ej_ab", "dirt")
	var race_m: float = float(seg[1]) * tab.length
	check(seg.size() == 2 and float(seg[0]) == 0.0 and float(seg[1]) > 0.2 and float(seg[1]) < 0.7, "A→B: la meta cae en la fracción %.3f del lazo" % float(seg[1]))
	check(absf(race_m - 2444.0) < 90.0, "A→B: se corren %.0f m (el validador dice 2444)" % race_m)
	check(abm["defaults"]["style"] == "adventure" and abm["defaults"]["sky"] == "rain", "A→B: estilo aventura y clima lluvia")
	var dens_end: float = tab.scen_w[int(tab.n * (float(seg[1]) + 0.05))]
	check(dens_end == 0.0, "A→B: el tramo de vuelta no lleva árboles")

	# ───── ocho (cruce a nivel) ─────
	var tr = RouteTrack.new("ej_ocho", "dirt")
	check(tr.has_cross and tr.cross_any.size() == tr.n, "el ocho tiene un cruce a nivel")
	var marked := 0
	var worst_dy := 0.0
	for i in tr.n:
		if tr.cross_any[i] == 1:
			marked += 1
			worst_dy = maxf(worst_dy, absf(tr.cy[i] - tr.cy[tr.cross_pt[i]]))
	check(marked > 10 and marked < tr.n / 4, "muestras del cruce: %d de %d" % [marked, tr.n])
	check(worst_dy < 0.15, "las dos pasadas por el cruce quedan a la misma altura (diferencia máxima %.3f m)" % worst_dy)
	# el auto sigue al camino que tiene más cerca
	var ci := -1
	for i in tr.n:
		if tr.cross_any[i] == 1:
			ci = i
			break
	var centre := Vector3.ZERO
	var pairs := 0
	for i in tr.n:
		if tr.cross_any[i] == 1:
			centre += tr.samples[i]
			pairs += 1
	centre /= float(maxi(pairs, 1))
	var a_i := ci
	var b_i: int = tr.cross_pt[ci]
	var v = tr.make_view()
	v.hint = a_i
	var tb: Vector3 = tr.tangents[b_i]
	var probe: Vector3 = centre + tb * 12.0 # 12 m por el otro camino
	v.nearest(probe.x, probe.z)
	var d_to_b := minf(absi(v.r_idx - b_i), tr.n - absi(v.r_idx - b_i))
	check(d_to_b < 70 and absf(v.r_lat) < 1.5, "parado sobre el otro camino, el auto lo reconoce (muestra %d, a %.2f m del eje)" % [v.r_idx, absf(v.r_lat)])
	v.hint = a_i
	var along: Vector3 = centre + tr.tangents[a_i] * 12.0
	v.nearest(along.x, along.z)
	var d_to_a := minf(absi(v.r_idx - a_i), tr.n - absi(v.r_idx - a_i))
	check(d_to_a < 70 and absf(v.r_lat) < 1.5, "yendo derecho por su camino, sigue en el suyo")
	# guardarraíl cortado en el cruce
	var rail_flags := 0
	for v2 in tr.cross_rail:
		rail_flags += int(v2)
	check(rail_flags > 4 and rail_flags < tr.n / 2, "el borde se corta donde caería sobre el otro camino (%d tramos marcados)" % rail_flags)
	for style in ["guardrail", "wood", "fence"]:
		var g2: Node3D = tr.build_guardrail(6.3, false, style)
		check(g2.get_child_count() == 2, "borde «%s» se arma" % style)
	var strip: ArrayMesh = tr.build_shoulder_mesh()
	check(strip != null and strip.get_surface_count() == 1, "la banquina se arma salteando el cruce")

	# ───── la IA da la vuelta al ocho sin saltar de camino ─────
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var d: Dictionary = (vehicles["pickup"] as Dictionary).duplicate()
	d["camberF"] = -1.0
	d["camberR"] = -0.5
	d["toeF"] = 0.0
	d["toeR"] = 0.1
	d["pressF"] = 30.0
	d["pressR"] = 30.0
	var sp: Array = tr.start_pose(0)
	var ph := VehiclePhysics.new(tr.make_view(), VehicleParams.from_dict(d))
	ph.reset(sp[0], sp[1], sp[2])
	var drv := AIDriver.new(tr.make_view(), ph, {"skill": 0.95})
	var sv = tr.make_view()
	var sess := Session.new(tr, {"type": "race", "laps": 1}, 1)
	var t := 0.0
	var h := 1.0 / 120.0
	var jumps := 0
	var prev_idx := -1
	var max_lat := 0.0
	var snap := Snap.new()
	var fc := FakeCar.new()
	fc.phys = ph
	fc.snap = snap
	sess.init_cars([fc])
	while t < 700.0 and sess.state != "done":
		var c: Vector3 = drv.update(ph, h)
		ph.step(h, c.x, c.y, c.z, false, drv.nitro)
		t += h
		snap.px = ph.px
		snap.pz = ph.pz
		snap.vx = ph.vx
		snap.vz = ph.vz
		sess.update(h, [fc])
		sv.nearest(ph.px, ph.pz)
		if prev_idx >= 0:
			var dj := absi(sv.r_idx - prev_idx)
			if mini(dj, tr.n - dj) > 40:
				jumps += 1
		prev_idx = sv.r_idx
		max_lat = maxf(max_lat, absf(sv.r_lat))
	check(sess.state == "done", "la IA completa la vuelta del ocho en %.0f s (progreso %.0f de %.0f m)" % [t, sess.prog[0], sess.race_len])
	check(jumps == 0 and drv.respawns <= 1, "sin saltos de camino en el cruce (%d) ni reapariciones (%d)" % [jumps, drv.respawns])
	check(max_lat < tr.half_width + tr.shoulder + 2.0, "no se sale del camino (desvío máx. %.1f m)" % max_lat)

	# ───── reglas: lógica ─────
	var fs := Session.new(tr, {"type": "race", "laps": 99}, 3)
	var cars3: Array = []
	for i in 3:
		var fk := FakeCar.new()
		fk.phys = FakePhys.new()
		cars3.append(fk)
	fs.state = "run"
	var rr := RaceRules.new()
	rr.setup("elim", fs, cars3, null, {"every": 30.0, "names": ["Vos", "A", "B"]})
	fs.prog[0] = 500.0
	fs.prog[1] = 300.0
	fs.prog[2] = 900.0
	fs.time = 31.0
	rr.update(0.1)
	check(fs.out_t[1] >= 0.0 and fs.out_t[0] < 0.0 and fs.out_t[2] < 0.0 and cars3[1].out, "eliminación: a los 30 s sale el último (el de menos progreso)")
	check(fs.standings(3)[2] == 1 and fs.standings(3)[0] == 2, "eliminación: el eliminado queda último en la tabla")
	fs.prog[0] = 400.0
	fs.time = 61.0
	rr.update(0.1)
	check(rr.done and not rr.win and fs.out_t[0] >= 0.0, "eliminación: si el último sos vos, perdés")
	var fs2 := Session.new(tr, {"type": "race", "laps": 99}, 3)
	fs2.state = "run"
	var cars3b: Array = []
	for i in 3:
		var fk2 := FakeCar.new()
		fk2.phys = FakePhys.new()
		cars3b.append(fk2)
	var rr2 := RaceRules.new()
	rr2.setup("elim", fs2, cars3b, null, {"every": 30.0, "names": ["Vos", "A", "B"]})
	fs2.prog[0] = 900.0
	fs2.prog[1] = 100.0
	fs2.prog[2] = 400.0
	fs2.time = 31.0
	rr2.update(0.1)
	fs2.prog[0] = 1300.0
	fs2.time = 61.0
	rr2.update(0.1)
	check(rr2.done and rr2.win and fs2.standings(3)[0] == 0, "eliminación: si queda uno en pie y sos vos, ganás")
	var fc2 := Session.new(tr, {"type": "race", "laps": 99}, 2)
	fc2.state = "run"
	var cars2: Array = []
	for i in 2:
		var fk3 := FakeCar.new()
		fk3.phys = FakePhys.new()
		cars2.append(fk3)
	var rc := RaceRules.new()
	rc.setup("chase", fc2, cars2, null, {"max_gap": 150.0, "names": ["Vos", "Rival"]})
	fc2.prog[0] = 0.0
	fc2.prog[1] = 40.0
	rc.update(0.1)
	check(not rc.lead_player and not rc.done, "persecución: el rival va adelante, lo perseguís")
	fc2.prog[0] = 60.0
	rc.update(0.1)
	check(rc.lead_player and rc.swaps == 1, "persecución: al pasarlo, los roles se cambian")
	fc2.prog[0] = 40.0
	fc2.prog[1] = 200.0
	rc.update(0.1)
	check(rc.done and not rc.win and rc.result_pos() == 2, "persecución: si se escapa a 150 m, perdés")
	var fc3 := Session.new(tr, {"type": "race", "laps": 99}, 2)
	fc3.state = "run"
	var rc3 := RaceRules.new()
	rc3.setup("chase", fc3, cars2, null, {"max_gap": 150.0, "names": ["Vos", "Rival"]})
	fc3.prog[0] = 400.0
	fc3.prog[1] = 100.0
	rc3.update(0.1)
	check(rc3.done and rc3.win and rc3.result_pos() == 1, "persecución: si te escapás a 150 m, ganás")

	# ───── persecución simulada con física real (el jugador es una IA) ─────
	var vehicles_ref := d
	for case in [["rival fuerte: se escapa", 0.85, 1.04, false], ["rival flojo: lo pasás y ganás", 0.97, 0.62, true]]:
		var track_c = RouteTrack.new("ej_ocho", "dirt")
		var cars_s: Array = []
		var drvs: Array = []
		for i in 2:
			var spc: Array = track_c.start_pose(i)
			var pp := VehiclePhysics.new(track_c.make_view(), VehicleParams.from_dict(vehicles_ref))
			pp.reset(spc[0], spc[1], spc[2])
			var dr := AIDriver.new(track_c.make_view(), pp, {"skill": 0.9, "lane": 0.0 if i == 0 else 1.6})
			var fk4 := FakeCar.new()
			fk4.phys = pp
			fk4.driver = dr
			cars_s.append(fk4)
			drvs.append(dr)
		var all_phys: Array = [cars_s[0].phys, cars_s[1].phys]
		for dr2 in drvs:
			dr2.others = all_phys
		var ss := Session.new(track_c, {"type": "race", "laps": 99}, 2)
		ss.init_cars(cars_s)
		var rs := RaceRules.new()
		rs.setup("chase", ss, cars_s, null, {"max_gap": 150.0, "skill": float(case[2]), "names": ["Vos", "Rival"]})
		var tt := 0.0
		var h2 := 1.0 / 60.0
		while tt < 900.0 and not rs.done:
			for i in 2:
				var cc: Vector3 = drvs[i].update(cars_s[i].phys, h2)
				cars_s[i].phys.step(h2, cc.x, cc.y, cc.z, false, drvs[i].nitro)
				cars_s[i].snap.px = cars_s[i].phys.px
				cars_s[i].snap.pz = cars_s[i].phys.pz
				cars_s[i].snap.vx = cars_s[i].phys.vx
				cars_s[i].snap.vz = cars_s[i].phys.vz
			tt += h2
			ss.update(h2, cars_s)
			rs.update(h2)
		print("     persecución simulada (%s): terminó=%s a los %.0f s · cambios de roles %d · gana el jugador=%s · brecha %.0f m" % [str(case[0]), str(rs.done), tt, rs.swaps, str(rs.win), rs.gap])
		check(rs.done and rs.win == bool(case[3]), "persecución simulada, %s (%.0f s)" % [str(case[0]), tt])
	quit(1 if fail else 0)
