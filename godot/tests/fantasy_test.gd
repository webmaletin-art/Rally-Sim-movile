## Prueba de los mapas fantasía planetarios (Marte, la Luna y el anillo de Júpiter): largo, pendientes, peralte, límite lateral, suelo continuo,
## piezas de papel y que el rival se quede a la par.
## Uso: godot --headless --path godot --script res://tests/fantasy_test.gd
extends SceneTree

const DreamTrack := preload("res://game/track/dream_track.gd")
const FantasyWorld := preload("res://game/track/fantasy_world.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

# por mapa: [largo mín, largo máx, desnivel mín, pendiente máx (+), bajada máx (-), prefijo de las piezas]
const SPEC := {
	"marte": [8800.0, 10000.0, 300.0, 0.15, 0.16, "m_"],
	"luna": [6500.0, 7600.0, 40.0, 0.12, 0.12, "l_"],
	"anillo": [7200.0, 8400.0, 40.0, 0.12, 0.12, "r_"],
}

func _init() -> void:
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var cat := {}
	for c in PaperKit.catalog():
		cat[str(c["id"])] = c
	for id in SPEC:
		var sp: Array = SPEC[id]
		var m: Dictionary = maps[id]
		print("── ", id)
		check(str(m.get("kind", "")) == "dream" and str(m.get("world", "")) != "", "%s es un mapa fantasía con su mundo (%s)" % [id, str(m.get("world", ""))])
		var t := DreamTrack.new(str(m["route"]), str(m["mode"]), false, float(m.get("hills", 1.0)))
		t.theme = str(m["world"])
		check(t.n >= 2000, "la ruta tiene %d muestras" % t.n)
		check(t.length > float(sp[0]) and t.length < float(sp[1]), "la vuelta mide %.0f m" % t.length)
		var ymin := 1e9
		var ymax := -1e9
		var smax := -1e9
		var smin := 1e9
		var bmax := 0.0
		for i in t.n:
			ymin = minf(ymin, t.cy[i])
			ymax = maxf(ymax, t.cy[i])
			var j := (i + 1) % t.n
			var run: float = t.cum[i + 1] - t.cum[i]
			var sl: float = (t.cy[j] - t.cy[i]) / maxf(0.1, run)
			smax = maxf(smax, sl)
			smin = minf(smin, sl)
			bmax = maxf(bmax, absf(t.bank[i]))
		check(ymax - ymin > float(sp[2]), "desnivel de %.0f m" % (ymax - ymin))
		check(smax < float(sp[3]), "la subida más empinada es del %.1f %%" % (smax * 100.0))
		check(smin > -float(sp[4]), "la bajada más brutal es del %.1f %%" % (smin * 100.0))
		check(bmax <= 0.111, "peralte máximo %.1f°" % rad_to_deg(atan(bmax)))
		var worst := 0.0
		for i in range(0, t.n, 7):
			var p: Vector3 = t.samples[i]
			var l: Vector3 = t.laterals[i]
			for off in [-14.0, -8.0, -3.0, 0.0, 3.0, 8.0, 14.0]:
				var y0: float = t.ground_info(p.x + l.x * off, p.z + l.z * off).x
				var y1: float = t.ground_info(p.x + l.x * (off + 1.0), p.z + l.z * (off + 1.0)).x
				worst = maxf(worst, absf(y1 - y0))
		check(worst < 0.25, "el suelo es continuo (salto máximo a 1 m: %.2f m)" % worst)
		check(t.wall_r.size() == t.n and t.wall_r[0] > 14.0 and t.wall_r[0] < 22.0, "límite lateral por muestra: %.1f m del centro" % t.wall_r[0])
		# piezas de papel: las del mundo existen, son livianas y las tres versiones del pórtico también
		var def: Dictionary = FantasyWorld.DEFS[str(m["world"])]
		var missing := 0
		var heavy := 0
		var used := {}
		for th in def["themes"]:
			for k in ["low", "mid", "tall", "huge", "fill"]:
				for pid in (th as Dictionary)[k]:
					used[str(pid)] = true
		for pr in def["props"]:
			used[str(pr["id"])] = true
		for pc in def["porticos"]:
			used[str(pc[1])] = true
		for F in def.get("floaters", []):
			for pid in F[5]:
				used[str(pid)] = true
		for pid in used:
			if not cat.has(pid) or PaperKit.mesh(pid) == null:
				missing += 1
				print("     falta la pieza ", pid)
			elif int(cat[pid]["tris"]) > (900 if pid.begins_with("x_") else 420):
				heavy += 1
		check(missing == 0, "las %d piezas que usa el mundo existen" % used.size())
		check(heavy == 0, "ninguna pieza es pesada")
		var w := FantasyWorld.new()
		w.setup_world(t, 0.75, str(m["world"]))
		check(w.inst_total > 15000, "el mundo coloca %d piezas" % w.inst_total)
		_duel(t, vehicles, "gt", "hatch")
	quit(1 if fail else 0)

func _car(t, vehicles: Dictionary, id: String, slot: int, skill: float) -> Array:
	var d: Dictionary = vehicles[id].duplicate()
	d["camberF"] = -1.0
	d["camberR"] = -0.5
	d["toeF"] = 0.0
	d["toeR"] = 0.1
	d["pressF"] = 30.0
	d["pressR"] = 30.0
	var ph := VehiclePhysics.new(t.make_view(), VehicleParams.from_dict(d))
	var sp: Array = t.start_pose(slot)
	ph.reset(sp[0], sp[1], sp[2])
	var drv := AIDriver.new(t.make_view(), ph, {"skill": skill})
	return [ph, drv, t.make_view()]

func _duel(t, vehicles: Dictionary, me: String, rival: String) -> void:
	var a: Array = _car(t, vehicles, me, 0, 1.0)
	var b: Array = _car(t, vehicles, rival, 1, 0.9)
	a[1].others = [b[0]]
	b[1].others = [a[0]]
	var prog := [0.0, 0.0]
	var last := [a[2].arc_pos(a[0].px, a[0].pz), b[2].arc_pos(b[0].px, b[0].pz)]
	var h := 1.0 / 120.0
	var tm := 0.0
	var worst := 0.0
	var sum_abs := 0.0
	var n := 0
	var max_lat := 0.0
	while tm < 330.0 and prog[0] < t.length and prog[1] < t.length:
		for k in 2:
			var c: Array = a if k == 0 else b
			var drv = c[1]
			var ph = c[0]
			var ctl: Vector3 = drv.update(ph, h)
			ph.step(h, ctl.x, ctl.y, ctl.z, false, drv.nitro)
			var ar: float = c[2].arc_pos(ph.px, ph.pz)
			var da: float = ar - last[k]
			if da < -t.length * 0.5:
				da += t.length
			elif da > t.length * 0.5:
				da -= t.length
			prog[k] += da
			last[k] = ar
			max_lat = maxf(max_lat, absf(c[2].r_lat))
		var gap: float = prog[1] - prog[0]
		b[1].pace = lerpf(b[1].pace, AIDriver.pace_target(gap, 8.0), clampf(h * 1.5, 0.0, 1.0))
		b[0].powerMul = lerpf(b[0].powerMul, AIDriver.power_target(gap, 8.0), clampf(h * 1.0, 0.0, 1.0))
		tm += h
		if tm > 30.0:
			worst = maxf(worst, absf(gap))
			sum_abs += absf(gap)
			n += 1
	var mean := sum_abs / maxf(1.0, float(n))
	print("     %s (jugador) contra %s: vuelta de %.0f m en %.0f s · distancia media %.0f m · máxima %.0f m · desvío máx. %.1f m" % [me, rival, t.length, tm, mean, worst, max_lat])
	check(mean < 45.0 and worst < 140.0, "%s vs %s: el rival se queda a la par (media %.0f m, máx %.0f m)" % [me, rival, mean, worst])
	check(max_lat < t.wall_r[0], "%s vs %s: ninguno se sale del límite lateral" % [me, rival])
