## Esquinas, veredas y rayas de las calles de la ciudad ([B] 19/10/2026): ninguna vereda se mete en la calzada de otra calle, ninguna raya pasa por arriba de otra calzada,
## cada cruce tiene sus esquinas redondeadas, el piso de la física sigue la vereda (a la altura del cordón) y las esquinas (asfalto).
## Reporte del dueño: «las terminaciones de la vereda están mal hechas, las rayas se intercruzan, el camino de tierra pasa por arriba del asfalto de otra ruta».
## Uso: tools/test/run_test.sh junction_render_test 90
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const CityWorld := preload("res://game/city/city_world.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## Distancia del punto a la poligonal cerrada (para no contar los puntos que sólo rozan el borde de una calzada)
func _edge_dist(p: Vector2, poly: PackedVector2Array) -> float:
	var best := 1.0e9
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1.0e-9 else 0.0
		best = minf(best, p.distance_to(a + ab * t))
	return best

## ¿El punto (x, z) cae adentro de la calzada de alguna calle que NO sea la dada (own, −1 = cualquiera)? Devuelve la cantidad de calles distintas. Un punto a menos de 4 cm del borde de
## una calzada no cuenta (la vereda y las rayas terminan justo ahí).
func _roads_over(city, p: Vector2, own: int) -> int:
	var seen := {}
	var kx := int(floor(p.x / CityLayout.HC))
	var kz := int(floor(p.y / CityLayout.HC))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k2 := Vector2i(kx + dx, kz + dz)
			if not city._hash.has(k2):
				continue
			for si in (city._hash[k2] as PackedInt32Array):
				var rj: int = city.s_road[si]
				if rj == own or seen.has(rj):
					continue
				var poly: PackedVector2Array = city.ribbon_poly(si)
				if poly.is_empty():
					continue
				if Geometry2D.is_point_in_polygon(p, poly) and _edge_dist(p, poly) > 0.04:
					seen[rj] = true
	return seen.size()

func _init() -> void:
	var track = CityTrack.new()
	var city = track.city
	var cw = track.build_world()
	var t0 := Time.get_ticks_msec()
	# ── 1. esquinas redondeadas
	var n_x := 0
	var n_with := 0
	for j in city.junctions:
		var jp: Vector2 = j["pos"]
		if jp.length() > 1100.0:
			continue
		var ok_kind := true
		for rid in j["roads"]:
			if str(city.roads[int(rid)]["kind"]) in ["tunnel", "bay"]:
				ok_kind = false
		if not ok_kind:
			continue
		n_x += 1
		if city.fillets_in(Rect2(jp - Vector2(20, 20), Vector2(40, 40))).size() > 0:
			n_with += 1
	_check(city.fillets.size() > 300, "esquinas redondeadas armadas: %d" % city.fillets.size())
	_check(n_x > 100 and float(n_with) / float(n_x) > 0.9, "%d de %d cruces tienen sus esquinas redondeadas" % [n_with, n_x])
	# ── 2. veredas y rayas de las cuadras con cruces
	var keys := {}
	for j in city.junctions:
		var jp2: Vector2 = j["pos"]
		if jp2.length() < 1100.0:
			keys[city.chunk_of(jp2.x, jp2.y)] = true
	var klist: Array = keys.keys()
	klist.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var n_side := 0
	var bad_side := 0
	var n_mark := 0
	var bad_mark := 0
	var n_curb := 0
	var n_nan := 0
	var first_bad := ""
	var built := 0
	for ki in range(0, klist.size(), maxi(1, klist.size() / 18)):
		var key: Vector2i = klist[ki]
		var rd = cw.Soup.new()
		var mk = cw.Soup.new()
		var tn = cw.Soup.new()
		cw._roads(rd, mk, key, tn)
		built += 1
		for i in range(0, rd.v.size(), 3):
			var a: Vector3 = rd.v[i]
			var b: Vector3 = rd.v[i + 1]
			var c: Vector3 = rd.v[i + 2]
			if not (is_finite(a.y) and is_finite(b.y) and is_finite(c.y) and is_finite(a.x) and is_finite(c.z)):
				n_nan += 1
				continue
			var col: Color = rd.c[i]
			if col.is_equal_approx(cw.C_CURB):
				n_curb += 1
				continue
			if col.is_equal_approx(cw.C_ASPH):
				continue
			var cen := Vector2((a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
			n_side += 1
			if _roads_over(city, cen, -1) > 0 and bad_side < 3:
				# una vereda cuyo centro cae adentro de una calzada: la de su propia calle no cuenta (la vereda está AFUERA de su calzada)
				bad_side += 1
				if first_bad == "":
					first_bad = "vereda en (%.0f, %.0f)" % [cen.x, cen.y]
			elif _roads_over(city, cen, -1) > 0:
				bad_side += 1
		for i in range(0, mk.v.size(), 3):
			var a2: Vector3 = mk.v[i]
			var b2: Vector3 = mk.v[i + 1]
			var c2: Vector3 = mk.v[i + 2]
			var cen2 := Vector2((a2.x + b2.x + c2.x) / 3.0, (a2.z + b2.z + c2.z) / 3.0)
			n_mark += 1
			if _roads_over(city, cen2, -1) > 1:
				bad_mark += 1
				if first_bad == "":
					first_bad = "raya en (%.0f, %.0f)" % [cen2.x, cen2.y]
	_check(built >= 10 and n_side > 500, "cuadras armadas: %d · triángulos de vereda %d · de rayas %d (%.1f s)" % [built, n_side, n_mark, float(Time.get_ticks_msec() - t0) / 1000.0])
	_check(n_curb == 0, "las veredas son un plano: ninguna cara de cordón (%d)" % n_curb)
	_check(n_nan == 0, "ningún vértice con altura o posición inválida (%d)" % n_nan)
	_check(bad_side == 0, "ninguna vereda cae adentro de una calzada (%d, %s)" % [bad_side, first_bad])
	_check(bad_mark == 0, "ninguna raya pasa por arriba de dos calzadas a la vez (%d, %s)" % [bad_mark, first_bad])
	# ── 3. el piso de la física: vereda a la altura del cordón, esquina como asfalto
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n_sw := 0
	var worst_sw := 0.0
	for tries in 600:
		var si: int = rng.randi() % city.s_x.size()
		var rd2: Dictionary = city.roads[city.s_road[si]]
		var ni: int = city.s_next[si]
		if ni < 0 or float(rd2["sw"]) < 1.0 or not city.is_dense_road(int(city.s_road[si])):
			continue
		var a3 := Vector2(city.s_x[si], city.s_z[si])
		var b3 := Vector2(city.s_x[ni], city.s_z[ni])
		var dir := (b3 - a3).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var q := (a3 + b3) * 0.5 + nrm * (float(rd2["hw"]) + float(rd2["sw"]) * 0.5)
		if _roads_over(city, q, int(city.s_road[si])) > 0 or city.on_fillet(q.x, q.y):
			continue
		var prq: PackedFloat64Array = city.probe(q.x, q.y)
		if int(prq[6]) != int(city.s_road[si]) or float(prq[0]) < 0.0:
			continue
		n_sw += 1
		var g: float = track.ground_info(q.x, q.y).x
		var want: float = (city.s_y[si] + city.s_y[ni]) * 0.5 + CityLayout.CURB
		worst_sw = maxf(worst_sw, absf(g - want))
	_check(n_sw > 100 and worst_sw < 0.02, "el piso de la física sobre la vereda está a la altura del plano de la vereda (%d puntos, peor diferencia %.1f mm)" % [n_sw, worst_sw * 1000.0])
	# sin escalón al pasar del asfalto a la vereda (y de la vereda al asfalto): el piso cambia menos de 2 cm en 20 cm de ancho (a 200 km/h un cordón de 16 cm era un salto)
	var n_edge := 0
	var worst_step := 0.0
	for tries in 600:
		var si3: int = rng.randi() % city.s_x.size()
		var rd3: Dictionary = city.roads[city.s_road[si3]]
		var ni3: int = city.s_next[si3]
		if ni3 < 0 or float(rd3["sw"]) < 1.0 or not city.is_dense_road(int(city.s_road[si3])):
			continue
		var a4 := Vector2(city.s_x[si3], city.s_z[si3])
		var b4 := Vector2(city.s_x[ni3], city.s_z[ni3])
		if (b4 - a4).length() < 1.0:
			continue
		var d4 := (b4 - a4).normalized()
		var n4 := Vector2(-d4.y, d4.x)
		var m4 := (a4 + b4) * 0.5
		var hw4 := float(rd3["hw"])
		var inside := m4 + n4 * (hw4 - 0.1)
		var outside := m4 + n4 * (hw4 + 0.1)
		if _roads_over(city, outside, int(city.s_road[si3])) > 0 or city.on_fillet(outside.x, outside.y):
			continue
		var p_in: PackedFloat64Array = city.probe(inside.x, inside.y)
		var p_out: PackedFloat64Array = city.probe(outside.x, outside.y)
		if int(p_in[6]) != int(city.s_road[si3]) or int(p_out[6]) != int(city.s_road[si3]) or float(p_out[0]) < 0.0:
			continue
		n_edge += 1
		worst_step = maxf(worst_step, absf(track.ground_info(inside.x, inside.y).x - track.ground_info(outside.x, outside.y).x))
	_check(n_edge > 100 and worst_step < 0.02, "el borde del asfalto no tiene escalón: peor salto %.1f mm en %d puntos" % [worst_step * 1000.0, n_edge])
	var fl_ok := 0
	var fl_n := 0
	for f in city.fillets:
		if city.poly_area(f) < 4.0:
			continue
		var c3 := Vector2.ZERO
		for q2 in f:
			c3 += q2
		c3 /= float(f.size())
		if not Geometry2D.is_point_in_polygon(c3, f):
			continue
		fl_n += 1
		var gf: Vector2 = track.ground_info(c3.x, c3.y)
		if int(gf.y) == 0 and absf(gf.x - (city.road_y_near(c3) + CityLayout.ROAD_UP)) < 0.15:
			fl_ok += 1
	_check(fl_n > 50 and fl_ok >= fl_n - 3, "adentro de una esquina redondeada el piso es asfalto (%d de %d)" % [fl_ok, fl_n])
	quit(1 if fail else 0)
