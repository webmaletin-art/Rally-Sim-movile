## Prueba de la ciudad de Puerto Aurelia: que se genere igual siempre, que las calles tengan pendientes manejables, que los edificios no pisen las calles y que
## los números de calle y las salidas existan.
## Uso: godot --headless --path godot --script res://tests/city_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const CityGps := preload("res://game/city/city_gps.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var c := CityLayout.new()
	c.build()
	print("     ciudad armada en %d ms" % (Time.get_ticks_msec() - t0))
	var km := 0.0
	var worst_up := 0.0
	var worst_dn := 0.0
	var rural_n := 0
	for rd in c.roads:
		var cum: PackedFloat32Array = rd["cum"]
		var pts: PackedVector3Array = rd["pts"]
		km += float(cum[cum.size() - 1]) / 1000.0
		for i in pts.size() - 1:
			var run := maxf(0.1, Vector2(pts[i + 1].x - pts[i].x, pts[i + 1].z - pts[i].z).length())
			var sl := (pts[i + 1].y - pts[i].y) / run
			if str(rd["kind"]) == "hill":
				worst_up = maxf(worst_up, sl)
				worst_dn = minf(worst_dn, sl)
				if absf(sl) > 0.18:
					print("     colina: punto ", i, " pendiente ", snappedf(sl, 0.01), " en ", pts[i])
			elif absf(sl) > 0.13:
				print("     pendiente fuerte en ", rd["name"], " ", snappedf(sl, 0.01))
				fail = true
		if str(rd["kind"]) == "rural":
			rural_n += 1
	check(c.roads.size() >= 47, "%d calles (%.1f km de calzada)" % [c.roads.size(), km])
	check(rural_n == 4 and c.exits.size() == 4, "4 rutas rurales con su Salida numerada (%s)" % str(c.exits.map(func(e): return e["num"])))
	check(c.junctions.size() > 140, "%d cruces" % c.junctions.size())
	check(c.building_count > 2500, "%d edificios" % c.building_count)
	check(worst_up > 0.03 and worst_up < 0.2, "el camino de la colina sube como máximo %.1f %%" % (worst_up * 100.0))
	check(worst_dn > -0.22, "y baja como máximo %.1f %%" % (worst_dn * 100.0))
	# los números de calle
	var names := {}
	for rd in c.roads:
		names[str(rd["name"])] = true
	for nm in ["Avenida 1", "Avenida 8", "Calle 10", "Calle 80", "Calle 101", "Calle 216", "Costanera 90", "Camino de la Colina 300", "Ruta 20", "Ruta 80", "Plaza Aurora", "Atajo 1", "Atajo 4", "Calle Vieja 1", "Calle Vieja 4"]:
		check(names.has(nm), "existe «%s»" % nm)
	check(names.size() == c.roads.size(), "no hay dos calles con el mismo nombre")
	# ningún edificio pisa el corredor de una calle
	var bad := 0
	var total := 0
	for key in c.buildings:
		for b in c.buildings[key]:
			total += 1
			var yw := float(b["yaw"])
			var tg := Vector2(sin(yw), cos(yw))
			var nm := Vector2(cos(yw), -sin(yw))
			var worst := 1e9
			for sx in [-0.5, 0.5]:
				for sz in [-0.5, 0.5]:
					var wp := Vector2(b["x"], b["z"]) + tg * (float(sx) * float(b["w"])) + nm * (float(sz) * float(b["d"]))
					var pr := c.probe(wp.x, wp.y)
					worst = minf(worst, -float(pr[0])) # holgura negativa = la esquina está adentro de un corredor
			if worst < 0.0:
				bad += 1
	check(bad < total / 40, "casi ningún edificio entra en una calle (%d de %d tocan el corredor)" % [bad, total])
	# atajos y callejones: pendiente máxima razonable y cruzan las calles que unen
	for nm in ["Atajo 1", "Atajo 2", "Atajo 3", "Atajo 4", "Calle Vieja 1", "Calle Vieja 2", "Calle Vieja 3", "Calle Vieja 4"]:
		var rd: Dictionary = c.roads[c.road_named(nm)]
		var pp: PackedVector3Array = rd["pts"]
		var mg := 0.0
		for i in range(1, pp.size()):
			mg = maxf(mg, absf(pp[i].y - pp[i - 1].y) / maxf(0.1, Vector2(pp[i].x - pp[i - 1].x, pp[i].z - pp[i - 1].z).length()))
		var nj := 0
		for j in c.junctions:
			if (j["roads"] as Array).has(int(rd["id"])):
				nj += 1
		check(mg < 0.12 and nj >= 2, "%s: pendiente máxima %.1f %%, %d cruces, %d m" % [nm, mg * 100.0, nj, int(rd["cum"][rd["cum"].size() - 1])])
	# consulta de calle
	var lc := c.locate(0.0, -150.0)
	check(str(lc["name"]) == "Avenida 7" and int(lc["cuadra"]) == 2, "locate: en (0, -150) estás en %s, cuadra %d" % [lc["name"], lc["cuadra"]])
	var pl := c.locate(0.0, 48.0)
	check(str(pl["name"]) != "", "locate en la plaza: %s" % pl["name"])
	# igual en cada corrida (semilla fija)
	var c2 := CityLayout.new()
	c2.build()
	check(c2.building_count == c.building_count and c2.junctions.size() == c.junctions.size() and c2.roads.size() == c.roads.size(), "la ciudad sale igual en cada corrida")
	# GPS: hay camino de la plaza a cada lugar y a cada salida, y no es absurdamente largo
	var tg0 := Time.get_ticks_usec()
	var gps := CityGps.new(c)
	print("     GPS armado en %.0f ms" % (float(Time.get_ticks_usec() - tg0) / 1000.0))
	var dests: Array = []
	for p in c.pois:
		dests.append([str(p["name"]), p["front"]])
	for ex in c.exits:
		dests.append([str(ex["name"]), ex["pos"]])
	for d in dests:
		var t2 := Time.get_ticks_usec()
		var r: Dictionary = gps.route(Vector2(0.0, 60.0), d[1])
		var straight := Vector2(0.0, 60.0).distance_to(d[1])
		var ln := float(r["len"])
		check(ln > 0.0 and ln < straight * 2.6 + 400.0, "GPS a %s: %.0f m por calles (en línea recta %.0f m, %.0f ms)" % [d[0], ln, straight, float(Time.get_ticks_usec() - t2) / 1000.0])
	# costo de las consultas de la física
	var t1 := Time.get_ticks_usec()
	var acc := 0.0
	for i in 20000:
		var pr := c.probe(-300.0 + float(i % 200) * 3.0, -400.0 + float(i / 200) * 4.0)
		acc += pr[0]
	var per := float(Time.get_ticks_usec() - t1) / 20000.0
	print("     probe: %.1f µs por consulta" % per)
	check(per < 120.0, "la consulta de la física es rápida (%.0f µs)" % per)
	quit(1 if fail else 0)
