## Prueba de la ciudad de Dream City: que se genere igual siempre, que las calles tengan pendientes manejables, que los frentes cierren las calles sin huecos y que
## los números de calle y las salidas existan.
## Uso: godot --headless --path godot --script res://tests/city_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const CityTrack := preload("res://game/track/city_track.gd")
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
	check(c.slab_count > 3000 and c.building_count == 8, "%d frentes de edificios y %d lugares especiales (el concesionario y siete talleres)" % [c.slab_count, c.building_count])
	# gasolineras: cuatro, con 3 a 6 puntos de carga; ningún punto de carga sobre una calle y ningún punto del playón sobre el asfalto
	check(c.stations.size() == 6, "hay %d gasolineras (4 de la ciudad y 2 en la Ruta Panorámica)" % c.stations.size())
	var fast_n := 0
	for st in c.stations:
		var fp0: Vector2 = st["fuel_points"][0]
		print("     %s (%s%s) en (%d, %d): %d puntos de carga (el primero en (%d, %d), carriles hacia %d°), %d círculos de playón" % [st["id"], st["kind"], ", carga rápida" if st["fast"] else "", int(st["center"].x), int(st["center"].y), st["fuel_points"].size(), int(fp0.x), int(fp0.y), int(rad_to_deg(atan2(st["lx"].x, st["lx"].y))), st["circles"].size()])
		fast_n += 1 if st["fast"] else 0
		check(st["fuel_points"].size() >= 3, "%s tiene 3 o más puntos de carga" % st["id"])
		var bad := 0
		for fp in st["fuel_points"]:
			if int(c.probe(fp.x, fp.y)[6]) >= -1:
				bad += 1
		for cc in st["circles"]:
			for k in 24:
				var ang := TAU * float(k) / 24.0
				for rr in [0.0, 0.5, 0.9]:
					var q: Vector2 = (cc as Vector2) + Vector2(cos(ang), sin(ang)) * float(st["r"]) * float(rr)
					var pq := c.probe(q.x, q.y)
					if int(pq[6]) >= 0 and float(pq[1]) < float(pq[5]):
						bad += 1
		check(bad == 0, "el playón de %s no pisa ninguna calle (%d puntos mal)" % [st["id"], bad])
	check(fast_n == 1, "hay una sola gasolinera de carga rápida")
	# Estacionamiento Central: está sobre una ruta, unido a la calle por su camino de entrada; tres niveles a 0 y ±4,4 m
	check(not c.garage.is_empty(), "el Estacionamiento Central tiene lugar en una ruta")
	if not c.garage.is_empty():
		var gy: Array = c.garage["y"]
		var gc: Array = c.garage["c"]
		check(absf(float(gy[1]) - float(gy[0]) - 4.4) < 0.01 and absf(float(gy[2]) - float(gy[0]) + 4.4) < 0.01, "planta alta a 4,4 m, subsuelo a −4,4 m y planta baja al nivel de la ruta")
		for gi in 3:
			var pg0 := c.probe((gc[gi] as Vector2).x, (gc[gi] as Vector2).y)
			check(float(pg0[0]) > 10.0 and absf(float(pg0[4]) - float(gy[gi])) < 0.01, "el centro de la sala %d es suelo a su altura" % gi)
		# de la ruta al centro de la planta baja se llega sin cortes (camino de entrada)
		var ok_path := true
		var p_a: Vector2 = c.garage["p"]
		var p_b: Vector2 = gc[0]
		for k in 41:
			var q: Vector2 = p_a.lerp(p_b, float(k) / 40.0)
			if float(c.probe(q.x, q.y)[0]) < 1.0:
				ok_path = false
		check(ok_path, "se entra al estacionamiento manejando desde la ruta, sin cortes")
	check(c.spawns.size() == 3, "hay %d lugares donde aparecer (todos dentro de un estacionamiento)" % c.spawns.size())
	for spw in c.spawns:
		check(float(c.probe(spw[0], spw[1])[0]) > 3.0, "se puede aparecer en (%d, %d)" % [int(spw[0]), int(spw[1])])
	# peajes: uno por ruta rural, sobre la calzada
	check(c.tolls.size() == 4, "hay %d peajes (uno por ruta)" % c.tolls.size())
	for tl in c.tolls:
		print("     %s en (%d, %d), hacia afuera %d°" % [tl["id"], int(tl["pos"].x), int(tl["pos"].y), int(rad_to_deg(atan2(tl["tn"].x, tl["tn"].y)))])
		var pt := c.probe(tl["pos"].x, tl["pos"].y)
		check(int(pt[6]) == int(tl["road"]) and float(pt[1]) < 0.5, "el %s está sobre el eje de su ruta" % tl["id"])
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
			if worst < -0.5: # una esquina de un lugar especial puede asomar unos centímetros en una curva
				bad += 1
				print("     mal: %s en (%d, %d), esquina adentro de un corredor por %.1f m" % [str(b.get("poi", "?")), int(b["x"]), int(b["z"]), -worst])
	check(bad == 0, "ningún lugar especial se mete en una calle (%d de %d)" % [bad, total])
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
	# Ruta Panorámica: larga, con subida de montaña y bajada a la costa, unida a la costanera
	var scr := c.road_named("Ruta Panorámica 70")
	check(scr >= 0, "existe la Ruta Panorámica 70")
	if scr >= 0:
		var sp: PackedVector3Array = c.roads[scr]["pts"]
		var scum: PackedFloat32Array = c.roads[scr]["cum"]
		var ymin := 1e9
		var ymax := -1e9
		for q in sp:
			ymin = minf(ymin, q.y)
			ymax = maxf(ymax, q.y)
		var joined := false
		for j in c.junctions:
			if (j["roads"] as Array).has(scr) and (j["roads"] as Array).has(c.road_named("Costanera 90")):
				joined = true
		check(float(scum[scum.size() - 1]) > 4000.0, "la Ruta Panorámica mide %d m" % int(scum[scum.size() - 1]))
		check(ymax - ymin > 55.0, "sube y baja la sierra (%.0f m de desnivel)" % (ymax - ymin))
		check(joined, "arranca en la costanera")
		check(sp[sp.size() - 1].x < 2990.0, "termina antes del bolsillo plano de x = 3000")
	# frentes continuos: a lo largo de la línea de edificación de cada calle no hay huecos (o hay otra calle, un lugar especial o una zona abierta)
	var gaps := 0
	var tested := 0
	for ri in c.roads.size():
		var rd: Dictionary = c.roads[ri]
		if str(rd["kind"]) in ["rural", "shortcut", "scenic", "plaza", "bay", "tunnel"]:
			continue
		var pp: PackedVector3Array = rd["pts"]
		for i in range(2, pp.size() - 2, 2):
			var tg := Vector2(pp[i + 1].x - pp[i - 1].x, pp[i + 1].z - pp[i - 1].z).normalized()
			var nrm := Vector2(-tg.y, tg.x)
			for sd in [-1.0, 1.0]:
				if str(rd["kind"]) == "coast" and sd > 0.0:
					continue
				var lp: Vector2 = Vector2(pp[i].x, pp[i].z) + nrm * (float(sd) * (float(rd["hw"]) + float(rd["sw"]) + CityLayout.LINE_GAP))
				if c._blocked_line(lp.x, lp.y, ri):
					continue
				tested += 1
				if not c.slab_covers(lp):
					gaps += 1
	print("     frentes: %d losas, %d puntos de línea de edificación, %d sin pared" % [c.slab_count, tested, gaps])
	check(gaps < tested / 12, "los frentes de las calles casi no tienen huecos (los angostos son farola y flores) (%d de %d)" % [gaps, tested])
	# objetos de la calle: hay de cada tipo y ninguno sobre el asfalto
	var cnt := []
	cnt.resize(24)
	cnt.fill(0)
	var on_road := 0
	for i in c.prop_type.size():
		cnt[c.prop_type[i]] += 1
		var pr2 := c.probe(c.prop_x[i], c.prop_z[i])
		if pr2[6] >= 0.0 and float(pr2[1]) < float(pr2[5]) - 0.01:
			on_road += 1
	print("     objetos: %d farolas, %d árboles, %d semáforos, %d bolardos" % [cnt[0], cnt[1], cnt[2], cnt[3]])
	check(cnt[0] > 300 and cnt[1] > 10 and cnt[2] > 60 and cnt[3] > 100 and on_road == 0, "farolas, árboles (pocos: la ciudad es limpia), semáforos y bolardos, ninguno sobre el asfalto (%d)" % on_road)
	# golpear un objeto lo rompe una sola vez y el auto SIGUE (no lo empuja ni lo hace rebotar)
	var tr := CityTrack.new()
	var pid := 40
	tr.add_prop(pid, tr.city.prop_x[pid], tr.city.prop_z[pid], 0.3)
	var hit1 := tr.push(tr.city.prop_x[pid] + 0.5, tr.city.prop_z[pid], 1.0)
	var hit2 := tr.push(tr.city.prop_x[pid] + 0.5, tr.city.prop_z[pid], 1.0)
	var brk := tr.take_broken()
	check(hit1.z <= 0.0 and hit2.z <= 0.0 and tr.take_breaks() == 1 and brk.size() == 1 and brk[0] == pid and tr.broken.has(pid), "un golpe rompe el objeto (y avisa una vez)")
	check(tr.push(tr.city.prop_x[pid], tr.city.prop_z[pid], 0.3).z <= 0.0 or tr.city.probe(tr.city.prop_x[pid], tr.city.prop_z[pid])[6] >= 0.0, "lo roto ya no choca")
	hit2 = hit2
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
