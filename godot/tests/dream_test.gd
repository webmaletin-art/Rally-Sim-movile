## Prueba del Vórtice de Ensueño: largo, pendientes, peralte, límite lateral y que la altura del suelo sea continua.
## Uso: godot --headless --path godot --script res://tests/dream_test.gd
extends SceneTree

const DreamTrack := preload("res://game/track/dream_track.gd")
const DreamWorld := preload("res://game/track/dream_world.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	var m: Dictionary = maps["dream"]
	var t := DreamTrack.new(str(m["route"]), str(m["mode"]), false, float(m.get("hills", 1.0)))
	check(t.n >= 2000, "la ruta tiene %d muestras" % t.n)
	check(t.length > 9000.0 and t.length < 10500.0, "la vuelta mide %.0f m (vuelta inmensa)" % t.length)
	var ymin := 1e9
	var ymax := -1e9
	var smax := -1e9
	var smin := 1e9
	var bmax := 0.0
	var bnonzero := 0
	for i in t.n:
		ymin = minf(ymin, t.cy[i])
		ymax = maxf(ymax, t.cy[i])
		var j := (i + 1) % t.n
		var run: float = t.cum[i + 1] - t.cum[i]
		var sl: float = (t.cy[j] - t.cy[i]) / maxf(0.1, run)
		smax = maxf(smax, sl)
		smin = minf(smin, sl)
		bmax = maxf(bmax, absf(t.bank[i]))
		if absf(t.bank[i]) > 0.03:
			bnonzero += 1
	check(ymax - ymin > 280.0, "desnivel de %.0f m: subida altísima" % (ymax - ymin))
	check(smax < 0.15 and smax > 0.08, "la subida más empinada es del %.1f %%" % (smax * 100.0))
	check(smin > -0.17 and smin < -0.10, "la bajada más brutal es del %.1f %%" % (smin * 100.0))
	check(bmax > 0.06 and bmax <= 0.111, "peralte máximo %.1f° (se inclina un poco)" % rad_to_deg(atan(bmax)))
	check(bnonzero > 40, "hay curvas con peralte (%d muestras)" % bnonzero)
	# continuidad: dos puntos a 1 m no difieren más de 25 cm en altura, ni de noche ni de día, sobre todo el recorrido
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
	# la banquina y el campo son planos a la altura del borde
	var p0: Vector3 = t.samples[300]
	var l0: Vector3 = t.laterals[300]
	var ya: float = t.ground_smooth(p0.x + l0.x * 14.0, p0.z + l0.z * 14.0)
	var yb: float = t.ground_smooth(p0.x + l0.x * 30.0, p0.z + l0.z * 30.0)
	check(absf(ya - yb) < 0.05, "el campo de flores es plano a los costados (%.3f m)" % absf(ya - yb))
	# la flora de ensueño: piezas hechas en papel, livianas, y todas las que usa el mapa existen
	var ids: Array = []
	var heavy := 0
	for c in PaperKit.catalog():
		if str(c["id"]).begins_with("d_"):
			ids.append(str(c["id"]))
			if int(c["tris"]) > 400:
				heavy += 1
	check(ids.size() >= 55, "%d piezas de flora de ensueño en el catálogo" % ids.size())
	check(heavy == 0, "ninguna pieza de ensueño pasa de 400 triángulos (%d pasan)" % heavy)
	var missing := 0
	for th in DreamWorld.THEMES:
		for k in ["trees", "tall", "low", "shrubs", "grass", "fill"]:
			for id in (th as Dictionary)[k]:
				if not ids.has(str(id)) or PaperKit.mesh(str(id)) == null:
					missing += 1
					print("     falta la pieza ", id)
	check(missing == 0, "todas las piezas que nombran los 6 temas de color existen")
	var dw := DreamWorld.new()
	dw.setup(t, 0.75, DreamWorld.SUN)
	check(dw.inst_total > 60000, "el mundo planta %d flores, arbustos y árboles" % dw.inst_total)
	# el rival se queda a la par: un auto «jugador» (IA a fondo) contra un rival con otro auto; la distancia entre los dos se mantiene corta
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	for pair in [["gt", "hatch"], ["hatch", "gt"]]:
		_duel(t, vehicles, str(pair[0]), str(pair[1]))
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
