## Peatones ambientales (Etapa 21): deterministas (misma semilla → misma gente), más gente de día que de noche y menos con lluvia, caminan por la vereda (no por la calzada),
## su posición es función pura de la hora, respetan el tope del perfil y se libera todo al apagar. Sin red.
## Uso: godot --headless --path godot --script res://tests/ambient_peds_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const WorldLife := preload("res://game/world/world_life.gd")
const AmbientPeds := preload("res://game/world/ambient_peds.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _mk(city: CityLayout, profile_name: String, root: Node3D, sd: int) -> Array:
	var wl := WorldLife.new()
	wl.setup(null, CityLayout.CELL)
	wl.state.world_seed = sd
	wl.set_profile(profile_name)
	var pd := AmbientPeds.new()
	pd.attach(city, null, root)
	wl.register_system(pd)
	wl.set_enabled(true)
	return [wl, pd]

func _initialize() -> void:
	var AP := AmbientPeds
	# reglas puras
	check(AP.density(13.0, false, 0.0) > AP.density(3.0, false, 0.0) * 2.0, "de día hay mucha más gente que de madrugada")
	check(AP.density(13.0, false, 0.9) < AP.density(13.0, false, 0.0) * 0.4, "con lluvia fuerte casi no hay gente")
	check(AP.present(1234, 0.2) == false or AP.present(1234, 1.0) == true, "con más gente, los que estaban siguen estando (subconjunto)")
	var ok_sub := true
	for k in 2000:
		var key := k * 7919
		if AP.present(key, 0.3) and not AP.present(key, 0.9):
			ok_sub = false
	check(ok_sub, "los peatones de poca gente son un subconjunto de los de mucha")
	var u0 := AP.along(0.3, 1.2, 20.0, 0.0)
	var u1 := AP.along(0.3, 1.2, 20.0, 5.0)
	check(is_equal_approx(u0, 0.3) and u1 > u0 and u1 <= 1.0, "camina a lo largo del tramo")
	check(AP.along(0.3, 1.2, 20.0, 1000.0) == AP.along(0.3, 1.2, 20.0, 1000.0), "la posición es función pura de la hora")
	var ok_range := true
	for k in 400:
		var u := AP.along(0.7, 1.4, 22.0, float(k) * 1.7)
		if u < 0.0 or u > 1.0:
			ok_range = false
	check(ok_range, "va y viene dentro del tramo (nunca se sale)")
	check(AP.heading(0.3, 1.2, 20.0, 0.0) == 1.0, "al principio va hacia adelante")
	# en la ciudad
	var city := CityLayout.new()
	city.build()
	var root := Node3D.new()
	get_root().add_child(root)
	var a := _mk(city, "MEDIUM", root, 424242)
	var wl: RefCounted = a[0]
	var pd: RefCounted = a[1]
	var spot := Vector2(300.0, 40.0)
	wl.clock.set_reference(960.0 * 0.5, 1.0, false) # mediodía del mundo
	wl.clock.frozen = true
	wl.update(0.1, spot)
	pd.update(0.1)
	var st: Dictionary = pd.stats()
	print("     ", st)
	check(int(st["pool"]) > 10, "hay tramos de vereda con peatones alrededor (%d)" % int(st["pool"]))
	check(int(st["shown"]) > 0 and int(st["shown"]) <= 32, "se dibujan algunos y respeta el tope MEDIUM (32): %d" % int(st["shown"]))
	# están sobre la vereda: entre el borde de la calzada y el de la vereda
	var on_walk := 0
	var total := 0
	var g: RefCounted = city.traffic()
	for cell in wl.sectors.active:
		for p in pd.slots_in_sector(cell):
			var pos: Vector3 = (p["a"] as Vector3).lerp(p["b"] as Vector3, 0.5)
			var nl: Dictionary = g.nearest_lane(Vector2(pos.x, pos.z), 20.0)
			if nl.is_empty():
				continue
			var rd: Dictionary = city.roads[int(g.lanes[int(nl["lane"])]["road"])]
			var pts: PackedVector3Array = rd["pts"]
			var best := 1e9
			for i in pts.size() - 1:
				var a2 := Vector2(pts[i].x, pts[i].z)
				var b2 := Vector2(pts[i + 1].x, pts[i + 1].z)
				var cp2 := Geometry2D.get_closest_point_to_segment(Vector2(pos.x, pos.z), a2, b2)
				best = minf(best, cp2.distance_to(Vector2(pos.x, pos.z)))
			total += 1
			if best >= float(rd["hw"]) - 0.2 and best <= float(rd["hw"]) + float(rd["sw"]) + 0.2:
				on_walk += 1
	check(total > 0 and float(on_walk) / float(total) > 0.9, "los peatones están en la vereda, no en el medio de la calle (%d de %d)" % [on_walk, total])
	var h1: int = pd.logical_hash()
	var b := _mk(city, "MEDIUM", root, 424242)
	b[0].clock.set_reference(960.0 * 0.5, 1.0, false)
	b[0].clock.frozen = true
	b[0].update(0.1, spot)
	check(b[1].logical_hash() == h1, "otro teléfono con la misma semilla ve a la misma gente (huella %d)" % h1)
	var c := _mk(city, "MEDIUM", root, 999)
	c[0].clock.set_reference(960.0 * 0.5, 1.0, false)
	c[0].clock.frozen = true
	c[0].update(0.1, spot)
	check(c[1].logical_hash() != h1, "otra semilla de mundo, otra gente")
	# noche: menos
	wl.clock.set_reference(960.0 * 3.0 / 24.0, 1.0, false)
	wl.update(0.1, spot)
	pd.update(0.1)
	check(int(pd.stats()["shown"]) < int(st["shown"]), "de madrugada hay menos gente (%d < %d)" % [int(pd.stats()["shown"]), int(st["shown"])])
	# perfil LOW y apagado
	wl.set_profile("LOW")
	wl.rebuild()
	wl.clock.set_reference(960.0 * 0.5, 1.0, false)
	wl.update(0.1, spot)
	pd.update(0.1)
	check(int(pd.stats()["shown"]) <= 16, "perfil LOW: tope de 16")
	wl.set_enabled(false)
	check(int(pd.stats()["pool"]) == 0 and int(pd.stats()["shown"]) == 0, "con World Life apagado se libera todo")
	print("AMBIENT_PEDS_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
