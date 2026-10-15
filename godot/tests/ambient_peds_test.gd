## Peatones ambientales (Etapa 21): deterministas (misma semilla → misma gente), más gente de día que de noche y menos con lluvia; desde el 15/10/2026 sólo en la
## Plaza Aurora (adentro de la reja: paseantes y chicos) y frente a los concesionarios (lavando autos), ninguno en las veredas,
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
	var spot := Vector2(20.0, 0.0) # la Plaza Aurora
	wl.clock.set_reference(960.0 * 0.5, 1.0, false) # mediodía del mundo
	wl.clock.frozen = true
	wl.update(0.1, spot)
	pd.update(0.1)
	var st: Dictionary = pd.stats()
	print("     ", st)
	check(int(st["pool"]) > 10, "hay gente en la plaza (%d)" % int(st["pool"]))
	check(int(st["shown"]) > 0 and int(st["shown"]) <= 32, "se dibujan algunos y respeta el tope MEDIUM (32): %d" % int(st["shown"]))
	# sólo en la plaza (adentro de la reja, sin autos) o frente a un concesionario: ninguno en las veredas
	var dealers: Array = []
	for poi in city.pois:
		if str(poi.get("kind", "")) == "dealer" and poi.has("door"):
			dealers.append(poi["door"])
	var in_plaza := 0
	var at_dealer := 0
	var elsewhere := 0
	var kids := 0
	for cell in wl.sectors.active:
		for p in pd.slots_in_sector(cell):
			for q in [p["a"], p["b"]]:
				var q2 := Vector2((q as Vector3).x, (q as Vector3).z)
				if q2.length() < 37.5:
					in_plaza += 1
				else:
					var near_d := false
					for d in dealers:
						if q2.distance_to(d) < 12.0:
							near_d = true
					if near_d:
						at_dealer += 1
					else:
						elsewhere += 1
			if float(p.get("scale", 1.0)) < 0.9:
				kids += 1
	check(elsewhere == 0 and in_plaza > 20, "la gente está adentro de la plaza (%d puntas) y no en las veredas (%d afuera)" % [in_plaza, elsewhere])
	check(kids >= 6, "hay chicos jugando en la plaza (%d)" % kids)
	var sp: Array = pd.special_slots()
	var wash := 0
	for p in sp:
		var a3: Vector3 = p["a"]
		for d in dealers:
			if Vector2(a3.x, a3.z).distance_to(d) < 12.0:
				wash += 1
				break
	check(dealers.size() > 0 and wash == dealers.size() * 2, "dos personas lavando autos en cada concesionario (%d en %d)" % [wash, dealers.size()])
	var crosses := 0
	for p in sp:
		for q in [p["a"], p["b"], (p["a"] as Vector3).lerp(p["b"], 0.5)]:
			var pr: PackedFloat64Array = city.probe((q as Vector3).x, (q as Vector3).z)
			if float(pr[6]) >= 0.0 and float(pr[1]) <= float(pr[5]):
				crosses += 1
	check(crosses == 0, "nadie camina sobre el asfalto (%d puntos)" % crosses)
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
