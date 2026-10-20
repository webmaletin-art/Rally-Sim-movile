## Las calles de la ciudad sólo chocan contra los edificios ([B] 19/10/2026).
## Reporte del dueño: «hay una colisión invisible en la esquina, no me deja pasar a la otra calle ni hacer un finito de drift al edificio; lo único que debe chocar son los edificios,
## las vallas, los guardarraíles y las banquinas». Antes la pared era el borde del corredor de la calle: en los cruces quedaba 1–5 m antes de la fachada y donde no había edificio
## (esquinas, huecos) también. Esta prueba arma Dream City y comprueba: que se cruza cada cruce de las avenidas por el medio y por las esquinas, que un auto pegado a una fachada
## (a un radio de distancia) pasa y adentro de ella no, que ninguna pared de la ciudad queda sin un edificio, un objeto o una valla detrás, y que las rutas de campo siguen con su pared.
## Uso: tools/test/run_test.sh city_walls_test 60
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var track = CityTrack.new()
	var city = track.city
	var R := 1.2
	# ── 1. los cruces de las calles de la ciudad se cruzan sin chocar con nada (por el eje de cada calle, 14 m antes y 14 m después del cruce)
	var n_j := 0
	var blocked := 0
	var first_bad := ""
	for j in city.junctions:
		var jp: Vector2 = j["pos"]
		var ok_kind := true
		for rid in j["roads"]:
			if not city.is_dense_road(int(rid)):
				ok_kind = false
		if not ok_kind or jp.length() > 1100.0:
			continue
		n_j += 1
		for rid in j["roads"]:
			var pts: PackedVector3Array = city.roads[int(rid)]["pts"]
			for i in pts.size():
				var q := Vector2(pts[i].x, pts[i].z)
				if q.distance_to(jp) > 14.0:
					continue
				var prq: PackedFloat64Array = city.probe(q.x, q.y)
				if prq[6] < 0.0 or not city.is_dense_road(int(prq[6])):
					continue # (el punto cae sobre una ruta de campo o una bahía: ahí manda la pared del corredor)
				var h: Vector3 = track.push_world(q.x, q.y, R)
				if h.z > 0.05:
					blocked += 1
					if first_bad == "":
						first_bad = "%s en (%.0f, %.0f) pen %.2f" % [city.roads[int(rid)]["name"], q.x, q.y, h.z]
					break
	_check(n_j > 40, "cruces de calles de la ciudad mirados: %d" % n_j)
	_check(blocked == 0, "se cruzan por el eje sin chocar con nada (%d cruces trabados%s)" % [blocked, (": " + first_bad) if first_bad != "" else ""])
	# ── 2. pegado a una fachada: pasa a un radio de distancia y no pasa adentro (finito de drift contra el edificio)
	var n_f := 0
	var bad_out := 0
	var bad_in := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var keys: Array = city.slabs.keys()
	for tries in 600:
		var key: Vector2i = keys[rng.randi() % keys.size()]
		var lst: Array = city.slabs[key]
		var sl: Dictionary = lst[rng.randi() % lst.size()]
		var pts: PackedVector3Array = sl["pts"]
		if pts.size() < 3:
			continue
		var i := 1 + rng.randi() % (pts.size() - 2)
		var p := Vector2(pts[i].x, pts[i].z)
		var away: Vector2 = (sl["away"] as PackedVector2Array)[i]
		var out := -away
		var q_free := p + out * (R + 0.15)
		var q_in := p + out * (R - 0.6)
		# el punto de afuera tiene que estar libre de CUALQUIER otro edificio (sino la prueba no dice nada)
		if city.wall_push(q_free.x, q_free.y, R).z > 0.0:
			continue
		n_f += 1
		var h_in: Vector3 = city.wall_push(q_in.x, q_in.y, R)
		if h_in.z < 0.5:
			bad_in += 1
	_check(n_f > 200, "fachadas mirados: %d" % n_f)
	_check(bad_in == 0, "a menos de un radio de la fachada el edificio frena (%d sin pared)" % bad_in)
	# ── 3. ninguna pared de la ciudad queda sin edificio, objeto o valla detrás: se muestrea el barrio y toda pared tiene que ser un edificio
	var walls_free := 0
	var n_w := 0
	for k in 6000:
		var x := rng.randf_range(-1050.0, 1050.0)
		var z := rng.randf_range(-1050.0, 1050.0)
		var pr: PackedFloat64Array = city.probe(x, z)
		if pr[6] < 0.0 or not city.is_dense_road(int(pr[6])):
			continue
		var v: Vector3 = track.push_world(x, z, R)
		if v.z <= 0.0:
			continue
		n_w += 1
		# la pared tiene que ser un edificio (wall_push) o un objeto de la calle (poste, semáforo, banco…)
		if city.wall_push(x, z, R).z <= 0.0:
			var near_prop := false
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var kk := Vector2i(int(floor(x / 16.0)) + dx, int(floor(z / 16.0)) + dz)
					if track.props.has(kk):
						near_prop = true
			if not near_prop:
				walls_free += 1
	_check(n_w > 300, "puntos con pared mirados: %d" % n_w)
	_check(walls_free == 0, "toda pared de las calles de la ciudad es un edificio o un objeto (%d paredes de la nada)" % walls_free)
	# ── 4. las rutas de campo siguen con su pared (la Panorámica: a 3 m de la banquina todavía hay pared del corredor)
	var scn: int = city.road_named("Ruta Panorámica 70")
	var rural_ok := 0
	var rural_n := 0
	if scn >= 0:
		var rp: PackedVector3Array = city.roads[scn]["pts"]
		for i in range(20, rp.size() - 20, 25):
			var a2 := Vector2(rp[i].x, rp[i].z)
			var b2 := Vector2(rp[i + 1].x, rp[i + 1].z)
			var dir2 := (b2 - a2).normalized()
			var nrm := Vector2(-dir2.y, dir2.x)
			var half: float = float(city.roads[scn]["hw"]) + float(city.roads[scn]["sw"])
			var q2 := a2 + nrm * (half + 6.0)
			var pr2: PackedFloat64Array = city.probe(q2.x, q2.y)
			if int(pr2[6]) != scn:
				continue
			rural_n += 1
			if track.push_world(q2.x, q2.y, R).z > 0.0:
				rural_ok += 1
	_check(rural_n > 5 and rural_ok >= rural_n - 1, "la ruta de campo sigue con su pared del corredor (%d de %d puntos)" % [rural_ok, rural_n])
	# ── 5. costo: 20 000 consultas
	var t0 := Time.get_ticks_usec()
	for k in 20000:
		var x2 := rng.randf_range(-600.0, 600.0)
		var z2 := rng.randf_range(-600.0, 600.0)
		track.push_world(x2, z2, R)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	_check(ms < 4000.0, "20 000 consultas de choque: %.0f ms (%.1f µs cada una)" % [ms, ms * 1000.0 / 20000.0])
	quit(1 if fail else 0)
