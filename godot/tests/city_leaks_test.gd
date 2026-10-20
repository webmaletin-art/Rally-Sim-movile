## Un auto no puede entrar entre los edificios de Dream City ([B] 20/10/2026).
## Pedido del dueño: «los huecos entre edificios no se pueden abrir: el jugador no puede entrar entre los edificios; parques y plazas cerrados (menos el Drift); con colisión invisible alcanza».
## Con la pared hecha sólo de edificios, cada lugar de la línea de edificación sin losa dejaba pasar: el auto se metía en las manzanas (289 bolsillos, 100 000 m²). Esta prueba recorre la
## ciudad con la colisión real (BFS sobre una grilla de 2 m, círculo del auto de 1,2 m de radio) empezando por el eje de cada calle y comprueba que:
##  · no se puede llegar a ningún lugar fuera del corredor de las calles, salvo las zonas abiertas permitidas (Plaza y Parque del Drift y los playones de las estaciones) y unas pocas celdas
##    de borde pegadas al Parque del Drift;
##  · la Plaza Aurora (el parque del centro) queda cerrada;
##  · se llega a todos los surtidores de las estaciones, a la plaza y al parque del Drift y al frente de cada taller y concesionario (las paredes de relleno no cierran ninguna entrada);
##  · los cruces y las esquinas siguen libres (las paredes de relleno no tocan el eje de ninguna calle salvo en la punta de una calle sin salida).
## Uso: tools/test/run_test.sh city_leaks_test 90
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityLayout := preload("res://game/city/city_layout.gd")

const STEP := 2.0
const RMAX := 1100.0

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var track = CityTrack.new()
	var city = track.city
	var t0 := Time.get_ticks_msec()
	_check(city.gap_wall_len > 1000.0 and city._gap_quads.size() > 400, "paredes de relleno armadas: %d tramos, %.0f m" % [city._gap_quads.size() / 8, city.gap_wall_len])
	# ── 1. los ejes de las calles se recorren enteros sin chocar (salvo la punta de una calle sin salida)
	var n_ax := 0
	var blocked_ax := 0
	var first_ax := ""
	for ri in city.roads.size():
		var rd: Dictionary = city.roads[ri]
		if not city.is_dense_road(ri) or str(rd["name"]).contains("Drift"):
			continue
		var pts: PackedVector3Array = rd["pts"]
		for i in pts.size():
			var p := Vector2(pts[i].x, pts[i].z)
			if p.length() > RMAX:
				continue
			# la punta de una calle sin salida tiene una pared a 15 cm: no se cuenta lo que queda a menos de 2,5 m de un extremo
			if i < 2 or i > pts.size() - 3:
				continue
			n_ax += 1
			if track.push_world(p.x, p.y, 1.2).z > 0.05:
				blocked_ax += 1
				if first_ax == "":
					first_ax = "%s en (%.0f, %.0f)" % [rd["name"], p.x, p.y]
	_check(n_ax > 5000 and blocked_ax == 0, "el eje de las calles está libre en %d puntos (%d trabados%s)" % [n_ax, blocked_ax, (": " + first_ax) if first_ax != "" else ""])
	# ── 2. BFS desde las calles con la colisión real
	var seen := {}
	var queue: Array = []
	for si in city.s_x.size():
		var rid: int = city.s_road[si]
		if not city.is_dense_road(rid):
			continue
		var p := Vector2(city.s_x[si], city.s_z[si])
		if p.length() > RMAX:
			continue
		var c := Vector2i(int(round(p.x / STEP)), int(round(p.y / STEP)))
		if not seen.has(c):
			seen[c] = true
			queue.append(c)
	var head := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in dirs:
			var nc: Vector2i = c + d
			if seen.has(nc):
				continue
			var q := Vector2(float(nc.x) * STEP, float(nc.y) * STEP)
			if q.length() > RMAX:
				continue
			seen[nc] = true
			if track.push_world(q.x, q.y, 1.2).z > 0.05:
				continue
			queue.append(nc)
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	# fugas: alcanzables fuera de todo corredor de calle y fuera de las zonas abiertas permitidas
	var park_c := Vector2.ZERO
	for oa in city.open_areas:
		if str(oa["name"]) == "Parque del Drift":
			park_c = oa["pos"]
	var leaks := 0
	var leaks_far := 0
	var plaza_in := 0
	var first_leak := ""
	for c in queue:
		var q := Vector2(float(c.x) * STEP, float(c.y) * STEP)
		if q.length() < float(CityLayout.PLAZA_R) - 14.0:
			plaza_in += 1
		var pr: PackedFloat64Array = city.probe(q.x, q.y)
		if float(pr[6]) >= 0.0 and float(pr[0]) > -3.0:
			continue # adentro del corredor de una calle
		if float(pr[6]) < 0.0 and float(pr[6]) > -1e8:
			continue # adentro de una zona abierta permitida (las cerradas no se alcanzan: ver abajo)
		leaks += 1
		if q.distance_to(park_c) > 95.0: # (un puñado de celdas del borde del Parque del Drift, que se maneja por adentro)
			leaks_far += 1
			if first_leak == "":
				first_leak = "(%.0f, %.0f)" % [q.x, q.y]
	_check(queue.size() > 100000, "celdas alcanzables manejando: %d (%.1f s)" % [queue.size(), secs])
	_check(leaks_far == 0, "no se puede entrar entre los edificios: %d celdas alcanzables fuera de las calles (%d de ellas junto al Parque del Drift)%s" % [leaks, leaks - leaks_far, (" · primera en " + first_leak) if first_leak != "" else ""])
	_check(plaza_in == 0, "la Plaza Aurora está cerrada: %d celdas alcanzables adentro de su círculo" % plaza_in)
	# ── 3. las entradas de todos los lugares siguen abiertas
	var miss: Array = []
	var n_fuel := 0
	for st in city.stations:
		for fp in (st["fuel_points"] as Array):
			var f: Vector2 = fp
			if f.length() > RMAX - 20.0:
				continue # (las estaciones de las rutas largas quedan fuera de la zona que recorre esta prueba)
			n_fuel += 1
			if not _near_seen(seen, f, queue):
				miss.append("surtidor de " + str(st["name"]) + " (%.0f, %.0f)" % [f.x, f.y])
	for p in city.pois:
		var f2: Vector2 = p["front"]
		if f2.length() > RMAX - 20.0:
			continue
		n_fuel += 1
		if not _near_seen(seen, f2, queue):
			miss.append(str(p.get("name", p.get("id", "?"))) + " (%.0f, %.0f)" % [f2.x, f2.y])
	var dr: Vector2 = city.drift["c"] if not city.drift.is_empty() else Vector2.ZERO
	_check(miss.is_empty(), "se llega a los %d surtidores y frentes de lugares de la zona (%d sin llegar: %s)" % [n_fuel, miss.size(), str(miss.slice(0, 6))])
	var park_ok := false
	for c in queue:
		if Vector2(float(c.x) * STEP, float(c.y) * STEP).distance_to(park_c) < 12.0:
			park_ok = true
			break
	_check(park_c != Vector2.ZERO and park_ok, "el Parque del Drift sigue abierto (se maneja por adentro)")
	_check(dr != Vector2.ZERO, "la Plaza de Drift existe (su cerco propio la deja abierta por la ruta)")
	quit(1 if fail else 0)

## ¿Hay una celda alcanzada a menos de 4 m de p?
func _near_seen(seen: Dictionary, p: Vector2, queue: Array) -> bool:
	var c0 := Vector2i(int(round(p.x / STEP)), int(round(p.y / STEP)))
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var c := Vector2i(c0.x + dx, c0.y + dz)
			if seen.has(c) and _is_free(c, queue):
				return true
	return false

var _free_cache := {}
func _is_free(c: Vector2i, queue: Array) -> bool:
	if _free_cache.is_empty():
		for q in queue:
			_free_cache[q] = true
	return _free_cache.has(c)
