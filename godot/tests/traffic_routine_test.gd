## Rutinas del tránsito (Etapa 10): densidad, sentido y velocidad según la hora; los autos estacionados cambian entre el día y la noche. Sin red.
## Uso: godot --headless --path godot --script res://tests/traffic_routine_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const WorldLife := preload("res://game/world/world_life.gd")
const CivilTraffic := preload("res://game/world/civil_traffic.gd")
const ParkedCars := preload("res://game/world/parked_cars.gd")
const TR := preload("res://game/world/traffic_routine.gd")

var fails := 0

class FakeTrack:
	extends RefCounted
	func set_dynamic_circles(_c: PackedFloat32Array) -> void:
		pass
	func add_prop(_id: int, _x: float, _z: float, _r: float) -> void:
		pass
	func remove_prop(_id: int, _x: float, _z: float) -> void:
		pass

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	check(TR.density(8.3) > TR.density(12.5) and TR.density(18.5) > TR.density(12.5), "hay hora pico a la mañana y a la tarde (%.2f / %.2f vs mediodía %.2f)" % [TR.density(8.3), TR.density(18.5), TR.density(12.5)])
	check(TR.density(3.0) < 0.4 and TR.density(3.0) < TR.density(12.5), "de madrugada hay poco tránsito (%.2f)" % TR.density(3.0))
	check(TR.density(8.3, true) < TR.density(8.3, false), "el fin de semana el pico de la mañana es más suave")
	check(TR.inward_bias(8.3) > 0.5 and TR.inward_bias(18.5) < -0.5 and absf(TR.inward_bias(13.0)) < 0.2, "a la mañana van al centro, a la tarde salen (%.2f / %.2f)" % [TR.inward_bias(8.3), TR.inward_bias(18.5)])
	check(TR.speed_factor(8.3) < 1.0 and TR.speed_factor(2.0) > 1.0, "hora pico más despacio, de noche más rápido")
	check(TR.parked_factor(23.0) > TR.parked_factor(13.0), "de noche hay más autos estacionados que de día")
	check(TR.is_weekend(5) and TR.is_weekend(6) and not TR.is_weekend(2) and TR.is_weekend(12), "los días 5 y 6 de cada 7 son fin de semana")
	# en el mundo: más autos en la hora pico que de madrugada
	var city := CityLayout.new()
	city.build()
	var root := Node3D.new()
	get_root().add_child(root)
	var wl := WorldLife.new()
	wl.setup(null, CityLayout.CELL)
	wl.state.world_seed = 31337
	wl.set_profile("MEDIUM")
	var ct := CivilTraffic.new()
	ct.attach(city, FakeTrack.new(), root)
	var pk := ParkedCars.new()
	pk.attach(city, FakeTrack.new(), root)
	wl.register_system(ct)
	wl.register_system(pk)
	wl.set_enabled(true)
	var spot := Vector2(300.0, 40.0)
	wl.clock.frozen = true
	wl.clock.set_reference(wl.clock.time_for_hour(8.3, 0), 1.0, false)
	wl.update(0.05, spot)
	var rush: int = int(ct.stats()["cars"])
	var park_day: int = int(pk.stats()["cars"])
	wl.clock.set_reference(wl.clock.time_for_hour(3.0, 0), 1.0, false)
	wl.rebuild()
	wl.update(0.05, spot)
	for i in 60: # el sistema retira de a uno los autos que sobran
		ct.update(1.0)
	var night: int = int(ct.stats()["cars"])
	var park_night: int = int(pk.stats()["cars"])
	print("     hora pico %d autos · madrugada %d autos · estacionados 8 h: %d / 3 h: %d" % [rush, night, park_day, park_night])
	check(rush > night, "hay más autos andando a la hora pico que de madrugada")
	check(park_night >= park_day, "de madrugada hay al menos tantos autos estacionados como de día")
	print("TRAFFIC_ROUTINE_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
