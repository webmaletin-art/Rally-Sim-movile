## El terreno de la ciudad no tapa el asfalto de ninguna calle ni ruta de campo ([B] 19/10/2026).
## Reporte del dueño: «se ve pasto y tierra sobre la ruta; la ruta debe ser limpia». La malla del terreno (grilla de 16 m) se arma con la altura natural más el terraplén/cuneta de las rutas de
## campo (CityLayout.verge_height) y el hundimiento junto a las calles (dense_ground). Esta prueba arma las cuadras por donde pasan las calles y las rutas, mide la altura de la malla en
## puntos de la calzada (de borde a borde) y comprueba que nunca queda por encima del asfalto que se dibuja.
## Uso: tools/test/run_test.sh city_terrain_test 90
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const WorldSurfaces := preload("res://game/world/world_surfaces.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## Altura de la malla (caras que miran hacia arriba) en (x, z) dentro de la lista de triángulos; NAN si no cae en ninguno
func _tri_y(tris: Array, x: float, z: float) -> float:
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 1e-9:
			continue
		var l1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
		var l2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
		var l3 := 1.0 - l1 - l2
		if l1 >= -1e-6 and l2 >= -1e-6 and l3 >= -1e-6:
			return l1 * a.y + l2 * b.y + l3 * c.y
	return NAN

func _init() -> void:
	var track = CityTrack.new()
	var city = track.city
	var cw = track.build_world()
	var t0 := Time.get_ticks_msec()
	var chunks := {} # clave de cuadra -> triángulos del terreno
	var worst := {} # tipo de calle -> [peor exceso, x, z, puntos mirados]
	var n_pts := 0
	var n_over := 0
	var first := ""
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for si in city.s_x.size():
		var ni: int = city.s_next[si]
		if ni < 0:
			continue
		var road: Dictionary = city.roads[city.s_road[si]]
		var kind := str(road["kind"])
		if kind == "tunnel" or kind == "bay":
			continue
		# las calles del centro son miles: se mira una de cada tres; las rutas de campo, todas
		var rural: bool = kind in ["rural", "scenic", "shortcut"]
		if not rural and si % 3 != 0:
			continue
		var pm := Vector2(city.s_x[si], city.s_z[si])
		if pm.length() > 2300.0:
			continue
		var key: Vector2i = city.chunk_of(pm.x, pm.y)
		if not chunks.has(key):
			var s = cw.Soup.new()
			var x0 := float(key.x) * CityLayout.CELL
			var z0 := float(key.y) * CityLayout.CELL
			cw._terrain(s, x0, z0)
			var lst: Array = []
			for i in range(0, s.v.size(), 3):
				if s.n[i].y < 0.5:
					continue
				lst.append([s.v[i], s.v[i + 1], s.v[i + 2]])
			chunks[key] = lst
		var tris: Array = chunks[key]
		var a := pm
		var b := Vector2(city.s_x[ni], city.s_z[ni])
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var hw := float(road["hw"])
		var m := 0.0
		while m <= hw - 0.2:
			for sg in [-1.0, 1.0]:
				var q: Vector2 = a + (b - a) * 0.5 + nrm * (m * float(sg))
				# la altura del asfalto ahí: la del piso de la física (sólo si el punto es de la calzada de esta calle)
				var pr: PackedFloat64Array = city.probe(q.x, q.y)
				if int(pr[6]) != int(city.s_road[si]) or float(pr[1]) > float(pr[5]) - 0.1:
					continue
				var gi: Vector2 = track.ground_info(q.x, q.y)
				if int(gi.y) != 0:
					continue
				# los puntos de la calzada que otra calle o una esquina redondeada cubren no cuentan
				var ty := _tri_y(tris, q.x, q.y)
				if is_nan(ty):
					continue
				n_pts += 1
				var exc := ty - gi.x
				if exc > 0.005:
					n_over += 1
					var w: Array = worst.get(kind, [0.0, 0.0, 0.0, 0])
					w[3] = int(w[3]) + 1
					if exc > float(w[0]):
						w[0] = exc
						w[1] = q.x
						w[2] = q.y
					worst[kind] = w
					if first == "":
						first = "%s «%s» en (%.0f, %.0f): la malla queda %.0f cm sobre el asfalto" % [kind, road["name"], q.x, q.y, exc * 100.0]
			m += 1.5
	_check(chunks.size() > 20 and n_pts > 5000, "cuadras armadas %d · puntos de calzada medidos %d (%.1f s)" % [chunks.size(), n_pts, float(Time.get_ticks_msec() - t0) / 1000.0])
	for k in worst.keys():
		var w: Array = worst[k]
		print("  ", k, ": ", w[3], " puntos por encima (peor ", snappedf(float(w[0]) * 100.0, 0.1), " cm en (", snappedf(float(w[1]), 0.1), ", ", snappedf(float(w[2]), 0.1), "))")
	_check(n_over == 0, "el terreno nunca tapa el asfalto (%d puntos; %s)" % [n_over, first])
	# ── la banquina de una ruta de campo con nieve no es tierra limpia: se tiñe (WorldSurfaces.side_color) y se pisa como nieve; abajo sigue siendo banquina
	_check(WorldSurfaces.snow_k(40.0) == 0.0 and WorldSurfaces.snow_k(64.0) == 1.0 and WorldSurfaces.snow_k(59.0) > 0.4, "snow_k: 0 abajo de 54 m, 1 desde 64 m")
	var tan := Color(0.66, 0.62, 0.50)
	_check(WorldSurfaces.side_color(tan, 30.0).is_equal_approx(tan) and WorldSurfaces.side_color(tan, 70.0).v > tan.v + 0.2, "la banquina a 70 m es casi blanca y a 30 m queda como antes")
	var n_snow := 0
	var n_snow_ok := 0
	var n_low := 0
	var n_low_ok := 0
	var first_low := ""
	for si in city.s_x.size():
		var ni2: int = city.s_next[si]
		if ni2 < 0:
			continue
		var rd3: Dictionary = city.roads[city.s_road[si]]
		if not (str(rd3["kind"]) in ["rural", "scenic", "shortcut"]) or float(rd3["sw"]) < 1.0:
			continue
		var a3 := Vector2(city.s_x[si], city.s_z[si])
		var b3 := Vector2(city.s_x[ni2], city.s_z[ni2])
		if (b3 - a3).length() < 0.5 or si % 2 != 0:
			continue
		var d3 := (b3 - a3).normalized()
		var q3 := (a3 + b3) * 0.5 + Vector2(-d3.y, d3.x) * (float(rd3["hw"]) + float(rd3["sw"]) * 0.6)
		var pr3: PackedFloat64Array = city.probe(q3.x, q3.y)
		if int(pr3[6]) != int(city.s_road[si]) or float(pr3[1]) <= float(pr3[5]) or float(pr3[0]) < 0.0:
			continue
		var gi3: Vector2 = track.ground_info(q3.x, q3.y)
		if float(pr3[4]) >= WorldSurfaces.SNOW_H:
			n_snow += 1
			if int(gi3.y) == WorldSurfaces.SNOW:
				n_snow_ok += 1
		elif float(pr3[4]) < WorldSurfaces.SNOW_H - 12.0:
			n_low += 1
			if int(gi3.y) != WorldSurfaces.SNOW: # (2 = banquina; 0 donde otra calle de la región la cruza con su asfalto)
				n_low_ok += 1
			elif first_low == "":
				first_low = "«%s» en (%.0f, %.0f) altura %.1f superficie %d" % [rd3["name"], q3.x, q3.y, float(pr3[4]), int(gi3.y)]
	_check(n_snow > 20 and n_snow_ok == n_snow, "la banquina de las rutas de campo por encima de 64 m es nieve (%d de %d puntos)" % [n_snow_ok, n_snow])
	_check(n_low > 100 and n_low_ok == n_low, "la banquina de las rutas de campo por debajo de 52 m no es nieve (%d de %d puntos; %s)" % [n_low_ok, n_low, first_low])
	quit(1 if fail else 0)
