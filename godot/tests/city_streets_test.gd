## Calles de Dream City sin «pedazos de tierra», sin colisión invisible en la calle y sin rampas en los cruces (20/10/2026, sexta tanda; reporte del dueño con capturas):
##  · las avenidas y calles que desembocan en otra no quedan SUELTAS a unos metros de su calzada (la boca de las avenidas en la Plaza Aurora: la vereda de la otra calle cruzaba la entrada
##    como una franja de «tierra»);
##  · la colisión de la ciudad (edificios, losas y paredes de relleno) no se mete adentro del corredor de ninguna calle: en 924 puntos de la calzada y la vereda el auto frenaba contra una pared
##    que no se ve; ahora ninguno (las paredes de relleno se recortan contra todos los corredores y las esquinas redondeadas);
##  · en ningún cruce hay un escalón de más de 15 cm en 1 m en el piso de la física (había hasta 83 cm: la «rampa invisible» de la Ruta 80, cuadra 4, y de los cruces de los atajos);
##  · las pendientes de las calles no pasan de las de siempre (los cruces se nivelan sin crear subidas nuevas de más del 15 %);
##  · el terreno de la región (que se dibuja desde los 2 km) no tapa la calzada ni la banquina de las rutas de campo de la ciudad (Ruta 40, cuadra 11; Ruta 80, cuadra 13): era el «pasto sobre el asfalto».
## Uso: godot --headless --path godot --script res://tests/city_streets_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityLayout := preload("res://game/city/city_layout.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## Altura de la malla de un cuadrado de terreno (triángulos de `soup`) en (x, z), o −1e9 si ese punto no está en la malla
func _mesh_h(soup, p: Vector2) -> float:
	for ti in soup.v.size() / 3:
		var a: Vector3 = soup.v[ti * 3]
		var b: Vector3 = soup.v[ti * 3 + 1]
		var c: Vector3 = soup.v[ti * 3 + 2]
		var den := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(den) < 1.0e-9:
			continue
		var w0 := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.y - c.z)) / den
		var w1 := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.y - c.z)) / den
		var w2 := 1.0 - w0 - w1
		if w0 >= -1.0e-6 and w1 >= -1.0e-6 and w2 >= -1.0e-6:
			return w0 * a.y + w1 * b.y + w2 * c.y
	return -1.0e9

func _init() -> void:
	var track := CityTrack.new()
	var city = track.city
	# ── 1. bocas: ninguna calle queda suelta a pocos metros de la calzada de la otra
	var loose := 0
	var first_loose := ""
	for ri in city.roads.size():
		var rd: Dictionary = city.roads[ri]
		if not (str(rd["kind"]) in CityLayout.WELD_KINDS):
			continue
		var pts: PackedVector3Array = rd["pts"]
		for e in 2:
			var n := pts.size()
			var pe := Vector2(pts[0].x, pts[0].z) if e == 0 else Vector2(pts[n - 1].x, pts[n - 1].z)
			var pn := Vector2(pts[1].x, pts[1].z) if e == 0 else Vector2(pts[n - 2].x, pts[n - 2].z)
			var hit: Array = city._ray_hit_axis(pe, (pe - pn).normalized(), ri, CityLayout.WELD_MAX + 12.0)
			if hit.is_empty():
				continue
			var other_hw := float((city.roads[int(hit[2])] as Dictionary)["hw"])
			var reach: float = float(hit[1])
			if reach <= other_hw + CityLayout.WELD_MAX and absf((pe - pn).normalized().dot(hit[3] as Vector2)) <= CityLayout.WELD_PARALLEL:
				loose += 1
				if first_loose == "":
					first_loose = "%s (%.0f, %.0f) a %.1f m del eje de %s" % [rd["name"], pe.x, pe.y, reach, (city.roads[int(hit[2])] as Dictionary)["name"]]
	check(loose == 0, "ninguna calle queda suelta a unos metros de la calzada de otra (%d; %s)" % [loose, first_loose])
	for nm in ["Avenida 2", "Avenida 4", "Avenida 8"]:
		var ri2: int = city.road_named(nm)
		var p0: Vector3 = (city.roads[ri2]["pts"] as PackedVector3Array)[0]
		var rr := Vector2(p0.x, p0.z).length()
		check(absf(rr - CityLayout.PLAZA_R) < 6.0, "%s arranca adentro de la calzada de la Plaza Aurora (a %.1f m del centro; la calzada va de 42 a 54)" % [nm, rr])
	# ── 2. ninguna pared adentro de un corredor
	var n_pts := 0
	var walled := 0
	var first_wall := ""
	for ri3 in city.roads.size():
		if not city.is_dense_road(ri3) or str(city.roads[ri3]["name"]).contains("Drift"):
			continue
		var rd3: Dictionary = city.roads[ri3]
		var p3: PackedVector3Array = rd3["pts"]
		var half := float(rd3["hw"]) + float(rd3["sw"]) - 1.3 # (el auto mide 1 m de radio: si toca antes de 30 cm del borde ya es pared del edificio)
		for i in p3.size() - 1:
			var a := Vector2(p3[i].x, p3[i].z)
			var b := Vector2(p3[i + 1].x, p3[i + 1].z)
			var l := a.distance_to(b)
			if l < 0.5:
				continue
			var dir := (b - a) / l
			var nrm := Vector2(-dir.y, dir.x)
			var m := maxi(1, int(ceil(l / 3.0)))
			for k in m:
				var c := a.lerp(b, (float(k) + 0.5) / float(m))
				var lat := -half
				while lat <= half + 0.01:
					var q: Vector2 = c + nrm * lat
					n_pts += 1
					var wp: Vector3 = city.wall_push(q.x, q.y, 1.0)
					if wp.z > 0.2:
						walled += 1
						if first_wall == "":
							first_wall = "%s (%.0f, %.0f) %.2f m" % [rd3["name"], q.x, q.y, wp.z]
					lat += 2.0
	check(walled == 0, "ninguna pared se mete adentro de las calles: %d de %d puntos de calzada y vereda (%s)" % [walled, n_pts, first_wall])
	# ── 3. cruces sin escalones y pendientes que no suben
	var worst_step := 0.0
	var worst_at := ""
	for j in city.junctions:
		var roads_j: Array = j["roads"]
		var skip := false
		for rid in roads_j:
			if str((city.roads[int(rid)] as Dictionary)["kind"]) == "tunnel":
				skip = true
		if skip:
			continue
		var jp: Vector2 = j["pos"]
		var zz := -13.0
		while zz <= 13.0:
			var xx := -13.0
			while xx <= 13.0:
				var p := jp + Vector2(xx, zz)
				var pr = city.probe(p.x, p.y)
				if float(pr[0]) > 0.5:
					var h0: float = track.ground_info(p.x, p.y).x
					for d in [Vector2(1, 0), Vector2(0, 1)]:
						var q2: Vector2 = p + d
						var pq = city.probe(q2.x, q2.y)
						if float(pq[0]) > 0.5:
							var dh := absf(float(track.ground_info(q2.x, q2.y).x) - h0)
							if dh > worst_step:
								worst_step = dh
								worst_at = "%s × %s en (%.0f, %.0f)" % [city.roads[int(roads_j[0])]["name"], city.roads[int(roads_j[1])]["name"], p.x, p.y]
				xx += 2.0 # (puntos base cada 2 m; cada uno se compara con sus vecinos a 1 m)
			zz += 2.0
	check(worst_step <= 0.15, "el piso de los cruces no tiene escalones de más de 15 cm en 1 m (peor: %.2f m, %s)" % [worst_step, worst_at])
	var worst_grade := 0.0
	var worst_road := ""
	for rd4 in city.roads:
		if str(rd4["kind"]) in ["tunnel", "hill"]:
			continue # (los túneles tienen su piso y el camino de la colina ya era así)
		var p4: PackedVector3Array = rd4["pts"]
		for i in p4.size() - 1:
			var d4 := Vector2(p4[i + 1].x - p4[i].x, p4[i + 1].z - p4[i].z).length()
			if d4 < 0.5:
				continue
			var g := absf(p4[i + 1].y - p4[i].y) / d4
			if g > worst_grade:
				worst_grade = g
				worst_road = "%s en (%.0f, %.0f)" % [rd4["name"], p4[i].x, p4[i].z]
	check(worst_grade <= 0.13, "ninguna calle sube más del 13 %% (peor: %.1f %%, %s)" % [worst_grade * 100.0, worst_road])
	# ── 4. el terreno de la región no tapa las rutas de campo de la ciudad
	var world = track.build_world()
	var rw = world.region_world
	check(rw != null, "la región está cargada")
	if rw != null:
		for spot in [["Ruta 40", 1000.0, 1100.0], ["Ruta 80", 1200.0, 1300.0], ["Ruta 80", 300.0, 400.0]]:
			var rdx: Dictionary = city.roads[city.road_named(str(spot[0]))]
			var cum: PackedFloat32Array = rdx["cum"]
			var px: PackedVector3Array = rdx["pts"]
			var mid := 0
			for i in cum.size():
				if cum[i] >= (float(spot[1]) + float(spot[2])) * 0.5:
					mid = i
					break
			var chunk := 256.0
			var x0 := floorf(px[mid].x / chunk) * chunk
			var z0 := floorf(px[mid].z / chunk) * chunk
			var soup = preload("res://game/city/city_world.gd").Soup.new()
			rw._terrain(soup, x0, z0, 8.0, 0)
			var hw: float = rdx["hw"]
			var sw: float = rdx["sw"]
			var total := 0
			var poke := 0
			var worst := 0.0
			for i in range(maxi(mid - 14, 0), mini(mid + 14, px.size() - 1)):
				var a2 := Vector2(px[i].x, px[i].z)
				var b2 := Vector2(px[i + 1].x, px[i + 1].z)
				var l2 := a2.distance_to(b2)
				if l2 < 0.5:
					continue
				var dir2 := (b2 - a2) / l2
				var nrm2 := Vector2(-dir2.y, dir2.x)
				for t in [0.0, 0.5]:
					var c2 := a2.lerp(b2, float(t))
					var yr := lerpf(px[i].y, px[i + 1].y, float(t))
					var lat2 := -(hw + sw) + 0.4
					while lat2 <= hw + sw - 0.4 + 0.01:
						var p2: Vector2 = c2 + nrm2 * lat2
						if p2.x >= x0 + 1.0 and p2.x <= x0 + chunk - 1.0 and p2.y >= z0 + 1.0 and p2.y <= z0 + chunk - 1.0:
							var th := _mesh_h(soup, p2)
							if th > -1.0e8:
								total += 1
								var surf := yr + (CityLayout.ROAD_UP if absf(lat2) <= hw else CityLayout.CURB)
								if th > surf + 0.004:
									poke += 1
									worst = maxf(worst, th - surf)
						lat2 += 1.0
			check(total > 40 and poke == 0, "%s (cuadra ~%d): el terreno de la región no tapa la calzada ni la banquina (%d de %d puntos; peor +%.2f m)" % [spot[0], int((float(spot[1]) + float(spot[2])) * 0.005) + 1, poke, total, worst])
	quit(1 if fail else 0)
