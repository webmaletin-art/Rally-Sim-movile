## El asfalto que se dibuja y el piso de la física están a la misma altura, y las rayas pegadas al asfalto ([B] 19/10/2026).
## Reporte del dueño: «las rayas se ven por arriba del asfalto, los bordes tapan las ruedas y la rueda está un poquito enterrada en el asfalto».
## Causa: el asfalto se dibujaba 4 cm (ciudad) o 5–7 cm (región) arriba de la altura donde apoyan las ruedas, y las rayas 7 cm más arriba todavía (11–14 cm sobre el piso de la física).
## Esta prueba arma tramos de calle con el mismo código que dibuja el mundo y compara con track.ground_info: tienen que coincidir (±6 mm) y las rayas quedar a MARK_UP del asfalto.
## Uso: tools/test/run_test.sh road_height_test 60
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## Centro y altura promedio de las caras que miran hacia arriba de una sopa de triángulos: [x, y, z] o []
func _center_up(soup, first_only := false) -> Array:
	var sx := 0.0
	var sy := 0.0
	var sz := 0.0
	var n := 0
	for i in range(0, mini(soup.v.size(), 6 if first_only else soup.v.size()), 3):
		if soup.n[i].y < 0.5:
			continue
		for k in 3:
			var p: Vector3 = soup.v[i + k]
			sx += p.x
			sy += p.y
			sz += p.z
			n += 1
	if n == 0:
		return []
	return [sx / n, sy / n, sz / n]

func _init() -> void:
	var track = CityTrack.new()
	track.build_world()
	var cw = track.world_node
	var rw = cw.get_node("region")
	var rg = track.region
	# ── ciudad: tramos de calles comunes (no túneles) repartidos por el mapa
	var n_city := 0
	var worst_c := 0.0
	var sum_c := 0.0
	var skipped_c := 0
	var worst_m := 0.0
	var marks_seen := 0
	var city = track.city
	var step := maxi(1, city.s_x.size() / 400)
	var si := 0
	while si < city.s_x.size():
		var ni: int = city.s_next[si]
		var road: Dictionary = city.roads[city.s_road[si]]
		if ni >= 0 and str(road["kind"]) != "tunnel":
			var rd = cw.Soup.new()
			var mk = cw.Soup.new()
			var tn = cw.Soup.new()
			cw._road_segment(rd, mk, si, ni, tn)
			var c: Array = _center_up(rd, true) # (la cinta del asfalto es lo primero que dibuja _road_segment; después vienen las veredas con cordón)
			if not c.is_empty() and Vector2(city.s_x[ni] - city.s_x[si], city.s_z[ni] - city.s_z[si]).length() > 1.0:
				# el centro de la cinta de asfalto está sobre el eje de la calle, a media altura entre los dos puntos
				var g: float = track.ground_info(c[0], c[2]).x
				var prc: PackedFloat64Array = city.probe(c[0], c[2])
				if int(prc[6]) != int(city.s_road[si]): # (adentro de una plaza o sobre otra calle que cruza manda otro piso: se mira en otro punto)
					skipped_c += 1
					si += step
					continue
				var d := absf(g - float(c[1]))
				if d > worst_c:
					worst_c = d
					if OS.has_environment("RH_DBG"):
						print("   peor ciudad: si=%d kind=%s g=%.4f vis=%.4f seg=%.1f m dy=%.2f" % [si, road["kind"], g, float(c[1]), Vector2(city.s_x[ni] - city.s_x[si], city.s_z[ni] - city.s_z[si]).length(), city.s_y[ni] - city.s_y[si]])
				n_city += 1
				sum_c += d
				var cm: Array = _center_up(mk)
				if not cm.is_empty():
					marks_seen += 1
					var dm := absf((float(cm[1]) - float(c[1])) - PaperKit.MARK_UP)
					# (las rayas del costado están a los lados: la altura es la del tramo, así que sólo cambia por la pendiente)
					worst_m = maxf(worst_m, dm)
		si += step
	_check(n_city > 150, "ciudad: %d tramos de calle mirados (%d salteados por plazas o cruces)" % [n_city, skipped_c])
	_check(worst_c < 0.015 and sum_c / maxf(1.0, float(n_city)) < 0.002, "ciudad: el piso de la física coincide con el asfalto dibujado (peor diferencia %.1f mm, promedio %.1f mm)" % [worst_c * 1000.0, sum_c / maxf(1.0, float(n_city)) * 1000.0])
	_check(marks_seen > 40 and worst_m < 0.02, "ciudad: las rayas quedan a %.1f cm del asfalto (%d tramos con rayas, peor diferencia %.1f mm)" % [PaperKit.MARK_UP * 100.0, marks_seen, worst_m * 1000.0])
	# ── región: tramos de ruta de todas las clases
	var n_reg := 0
	var worst_r := 0.0
	var sum_r := 0.0
	var marks_r := 0
	var worst_rm := 0.0
	var total: int = rg.pe.size()
	var stp := maxi(1, total / 500)
	var k := 0
	while k < total:
		var ei: int = rg.pe[k]
		var e: Array = rg.edges[ei]
		var i := k - int(e[6])
		if i + 1 < int(e[7]):
			var a2: Vector2 = rg.edge_point(ei, i)
			var b2: Vector2 = rg.edge_point(ei, i + 1)
			if a2.distance_to(b2) > 1.0:
				var rd2 = cw.Soup.new()
				var mk2 = cw.Soup.new()
				var sd2 = cw.Soup.new()
				var rl2 = cw.Soup.new()
				rw._road_segment(rd2, mk2, sd2, rl2, k)
				var c2: Array = _center_up(rd2, true)
				if not c2.is_empty():
					var pr: PackedFloat64Array = rg.probe(c2[0], c2[2], 10.0, false)
					if int(pr[1]) == ei and pr[4] <= pr[5]: # (el punto cae sobre la calzada de ESTA calle, no de otra que la cruza)
						var g2: float = rg.ground(c2[0], c2[2]).x
						var d2 := absf(g2 - float(c2[1]))
						if d2 > worst_r and OS.has_environment("RH_DBG"):
							print("   peor: ei=%d surf=%d pr9=%d cls=%s g=%.4f vis=%.4f" % [ei, int(e[5]), int(pr[9]), rg.CLS_NAMES[int(e[2])], g2, float(c2[1])])
						worst_r = maxf(worst_r, d2)
						sum_r += d2
						n_reg += 1
						var cm2: Array = _center_up(mk2)
						if not cm2.is_empty():
							marks_r += 1
							worst_rm = maxf(worst_rm, absf((float(cm2[1]) - float(c2[1])) - PaperKit.MARK_UP))
		k += stp
	_check(n_reg > 150, "región: %d tramos de ruta mirados" % n_reg)
	_check(worst_r < 0.025 and sum_r / maxf(1.0, float(n_reg)) < 0.002, "región: el piso de la física coincide con el asfalto dibujado (peor diferencia %.1f mm, promedio %.1f mm; antes del arreglo: 50–66 mm)" % [worst_r * 1000.0, sum_r / maxf(1.0, float(n_reg)) * 1000.0])
	_check(marks_r > 40 and worst_rm < 0.02, "región: las rayas quedan a %.1f cm del asfalto (%d tramos con rayas, peor diferencia %.1f mm)" % [PaperKit.MARK_UP * 100.0, marks_r, worst_rm * 1000.0])
	# ── fuera de la calzada el piso no sube (la banquina y el campo siguen donde estaban)
	var bad_off := 0
	var n_off := 0
	k = 0
	while k < total:
		var ei3: int = rg.pe[k]
		var e3: Array = rg.edges[ei3]
		var i3 := k - int(e3[6])
		if i3 + 1 < int(e3[7]) and str(rg.CLS_NAMES[int(e3[2])]) != "calle":
			var a3: Vector2 = rg.edge_point(ei3, i3)
			var b3: Vector2 = rg.edge_point(ei3, i3 + 1)
			if a3.distance_to(b3) > 1.0:
				var dir := (b3 - a3).normalized()
				var nrm := Vector2(-dir.y, dir.x)
				var mid := (a3 + b3) * 0.5
				var hw: float = rg.e_hw[ei3]
				var p_on := mid
				var p_out := mid + nrm * (hw + 14.0)
				var pr_on: PackedFloat64Array = rg.probe(p_on.x, p_on.y, 10.0, false)
				var pr_out: PackedFloat64Array = rg.probe(p_out.x, p_out.y, 10.0, false)
				if int(pr_on[1]) == ei3 and pr_out[0] <= -0.05:
					n_off += 1
					var gout: float = rg.ground(p_out.x, p_out.y).x
					if absf(gout - rg.base_height(p_out.x, p_out.y)) > 0.5 * float(absf(rg.hs[k] - rg.base_height(p_out.x, p_out.y)) + 1.0):
						bad_off += 1
		k += stp * 3
	_check(n_off > 40 and bad_off == 0, "región: fuera de la calzada el piso no se levanta (%d puntos mirados, %d raros)" % [n_off, bad_off])
	# ── terraplén junto a las rutas de campo (Ruta Panorámica 70, cuadra 37: «el piso está más abajo que la ruta y salgo volando»)
	var rid := -1
	for i in city.roads.size():
		if str((city.roads[i] as Dictionary)["name"]) == "Ruta Panorámica 70":
			rid = i
	var first := -1
	var cnt := 0
	for sj in city.s_x.size():
		if int(city.s_road[sj]) == rid:
			if first < 0:
				first = sj
			cnt += 1
	_check(rid >= 0 and cnt > 400, "la Ruta Panorámica 70 tiene %d puntos" % cnt)
	var worst_drop := 0.0 # mayor escalón entre el borde de la banquina y el piso 1 m más afuera
	var worst_slope := 0.0 # mayor pendiente entre dos puntos del piso separados 1 m, hasta 20 m del borde
	var n_prof := 0
	var worst_k := 0
	var worst_hairpin := 0.0 # lo mismo donde dos tramos de la ruta (una horquilla) pasan a menos de ~20 m a distinto nivel
	for kk in range(2, cnt - 2, 3):
		var sk: int = first + kk
		var nk: int = city.s_next[sk]
		var dx: float = city.s_x[nk] - city.s_x[sk]
		var dz: float = city.s_z[nk] - city.s_z[sk]
		var ln := sqrt(dx * dx + dz * dz)
		if ln < 1.0:
			continue
		var nx := -dz / ln
		var nz := dx / ln
		var rdk: Dictionary = city.roads[rid]
		var half: float = float(rdk["hw"]) + float(rdk["sw"])
		for side in [-1.0, 1.0]:
			var prev_y := 0.0
			var have := false
			for off in range(0, 21):
				var d: float = half + float(off) + 0.2
				var px: float = city.s_x[sk] + nx * d * side
				var pz: float = city.s_z[sk] + nz * d * side
				var vv: PackedFloat64Array = city.verge_roads(px, pz)
				if vv.is_empty() or CityLayout.verge_min_e(vv) <= 0.0:
					have = false
					continue # (adentro de la calzada de otro tramo de la ruta, en una horquilla: se mira en otro punto)
				if float(city.probe(px, pz)[0]) > -0.05:
					have = false
					continue # (adentro de otra calle que cruza: manda esa calle)
				var gy: float = track.ground_info(px, pz).x
				if have:
					var sl := absf(gy - prev_y)
					if vv.size() == 2 and sl > worst_slope:
						worst_slope = sl
						worst_k = kk
					if vv.size() > 2 and sl > worst_hairpin:
						worst_hairpin = sl
						if OS.has_environment("RH_DBG"):
							print("   slope k=%d side=%+d off=%d: %.2f -> %.2f vv=%s" % [kk, int(side), off, prev_y, gy, str(vv)])
				elif off == 0 and vv.size() == 2:
					var road_y: float = float(vv[1]) + CityLayout.ROAD_UP
					if road_y - gy > worst_drop and OS.has_environment("RH_DBG"):
						print("   drop k=%d side=%+d: road_y=%.2f g=%.2f nat=%.2f e=%.2f" % [kk, int(side), road_y, gy, city.height(px, pz), vv[0]])
					worst_drop = maxf(worst_drop, road_y - gy)
				prev_y = gy
				have = true
			n_prof += 1
	_check(n_prof > 100, "perfiles laterales mirados: %d" % n_prof)
	_check(worst_drop < 0.45, "al borde de la banquina el piso baja como mucho %.2f m (antes: hasta 1,9 m de golpe)" % worst_drop)
	_check(worst_slope < 0.75, "afuera de la banquina el piso nunca sube ni baja más de %.2f m por cada metro (cuadra %.1f)" % [worst_slope, float(worst_k) * 8.0 / 100.0])
	_check(worst_hairpin < 1.7, "en las horquillas (dos tramos a 3 m de diferencia a ~20 m) el piso entre los dos no tiene paredes: %.2f m por metro" % worst_hairpin)
	quit(1 if fail else 0)
