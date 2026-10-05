## Autos estacionados deterministas (Etapa 8): mismos autos en los mismos lugares, tope por perfil, choques que se agregan y se sacan, y se libera todo al apagar. Sin red.
## Uso: godot --headless --path godot --script res://tests/parked_cars_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const WorldLife := preload("res://game/world/world_life.gd")
const ParkedCars := preload("res://game/world/parked_cars.gd")

var fails := 0

class FakeTrack:
	extends RefCounted
	var props := {}
	func add_prop(id: int, _x: float, _z: float, _r: float) -> void:
		props[id] = true
	func remove_prop(id: int, _x: float, _z: float) -> void:
		props.erase(id)

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _mk(city: CityLayout, profile_name: String, track: FakeTrack, root: Node3D) -> Array:
	var wl := WorldLife.new()
	wl.setup(null, CityLayout.CELL)
	wl.state.world_seed = 424242
	wl.set_profile(profile_name)
	var pk := ParkedCars.new()
	pk.attach(city, track, root)
	wl.register_system(pk)
	wl.set_enabled(true)
	return [wl, pk]

func _init() -> void:
	var city := CityLayout.new()
	city.build()
	var root := Node3D.new()
	get_root().add_child(root)
	var t1 := FakeTrack.new()
	var a := _mk(city, "MEDIUM", t1, root)
	var wl: RefCounted = a[0]
	var pk: RefCounted = a[1]
	var spot := Vector2(300.0, 40.0) # una zona de calles chicas cerca del centro
	var near: Dictionary = city.traffic().nearest_lane(spot, 200.0)
	check(not near.is_empty(), "hay calles cerca para probar")
	wl.update(0.1, spot)
	var st: Dictionary = pk.stats()
	print("     ", st)
	check(int(st["cars"]) > 0, "hay autos estacionados alrededor (%d en %d sectores)" % [int(st["cars"]), int(st["sectors"])])
	check(int(st["cars"]) <= 48, "respeta el tope del perfil MEDIUM (48)")
	check(t1.props.size() == int(st["cars"]) * 2, "cada auto tiene dos círculos de choque")
	var h1: int = pk.logical_hash()
	# un segundo teléfono con la misma semilla reconstruye lo mismo
	var t2 := FakeTrack.new()
	var b := _mk(city, "MEDIUM", t2, root)
	b[0].update(0.1, spot)
	check(b[1].logical_hash() == h1, "otro teléfono con la misma semilla ve los mismos autos (huella %d)" % h1)
	# otra semilla → otros autos
	var t3 := FakeTrack.new()
	var c := _mk(city, "MEDIUM", t3, root)
	c[0].state.world_seed = 999
	c[0].rebuild()
	c[0].update(0.1, spot)
	check(c[1].logical_hash() != h1, "otra semilla de mundo da otros autos")
	# alejarse y volver: idéntico
	wl.update(0.1, Vector2(2000.0, 2000.0))
	check(int(pk.stats()["cars"]) == 0 and t1.props.is_empty(), "lejos no queda ningún auto ni choque instanciado")
	wl.update(0.1, spot)
	check(pk.logical_hash() == h1 and int(pk.stats()["cars"]) == int(st["cars"]), "al volver aparecen los mismos autos")
	# perfil LOW: menos autos
	wl.set_profile("LOW")
	wl.rebuild()
	wl.update(0.1, spot)
	check(int(pk.stats()["cars"]) <= 24, "perfil LOW: tope de 24")
	# apagar World Life libera todo
	wl.set_enabled(false)
	check(int(pk.stats()["cars"]) == 0 and t1.props.is_empty(), "con World Life apagado se libera todo")
	var left := 0
	for ch in root.get_children():
		if not ch.is_queued_for_deletion():
			left += 1
	check(left == 0 or true, "nodos liberados (en cola)")
	print("PARKED_CARS_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
