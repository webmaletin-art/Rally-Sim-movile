## Policía: jurisdicción y reconocimiento (20/10/2026, pedido del dueño). «La policía debe dejar de seguirme si llegué a otra ciudad porque ya no tiene jurisdicción; si vuelvo me esperan;
## si cambio de auto no me reconocen y puedo volver tranquilo, esa ruta ya queda libre; si ando tranquilo no me arrestan.»
## Uso: godot --headless --path godot --script res://tests/police_jurisdiction_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityPolice := preload("res://game/city/city_police.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const AiCars := preload("res://game/data/ai_cars.gd")

## Lo mínimo de race.gd que usa la policía
class FakeRace:
	extends Node
	var track
	var cars: Array = []
	var cfg := {"car": "hatch"}
	var vehicles: Dictionary
	var race_hud = null
	var audio = null
	var sim_t := 0.0
	var profile = null
	var police = null
	var ow_events = null
	func add_ai_car(vid: String, x: float, z: float, yaw: float, driver: RefCounted, paint := Color.WHITE, mods := {}):
		var su: Dictionary = CarBuild.build_params(vehicles[vid], Profile.new_car_state(vid), AiCars.ASSISTS)
		for k in mods:
			su[k] = mods[k]
		var c := Car.new(track, VehicleParams.from_dict(su), false, true, paint, Color.GRAY)
		c.driver = driver
		c.solid = true
		c.place(x, z, yaw)
		add_child(c.visual)
		cars.append(c)
		return c
	func remove_car(c) -> void:
		var i := cars.find(c)
		if i > 0:
			cars.remove_at(i)
			c.visual.queue_free()
	func on_teleport() -> void:
		pass

class FakeProfile:
	extends RefCounted
	var d := {}
	var saves := 0
	func save() -> void:
		saves += 1
	func spend(_n: int, _k := "") -> bool:
		return true

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _make(tr, vehicles, car_id: String, x: float, z: float, yaw: float, prof = null) -> Array:
	var race := FakeRace.new()
	race.track = tr
	race.vehicles = vehicles
	race.profile = prof if prof != null else FakeProfile.new()
	race.cfg["car"] = car_id
	root.add_child(race)
	var su: Dictionary = CarBuild.build_params(vehicles[car_id], Profile.new_car_state(car_id))
	var me := Car.new(tr, VehicleParams.from_dict(su), true, true, Color.BLUE, Color.GRAY)
	me.solid = true
	me.place(x, z, yaw)
	race.add_child(me.visual)
	race.cars.append(me)
	var pol := CityPolice.new()
	pol.setup(race)
	return [race, pol, me]

func _run() -> void:
	var SecS: GDScript = load("res://game/region/sectors.gd") # (toda la región abierta: los sectores tienen su prueba)
	SecS.set("_loaded", true)
	SecS.set("_open_all", true)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var tr := CityTrack.new()
	var rg = tr.region
	_check(rg != null and vehicles.has("police"), "hay región y patrullero")
	var prof := FakeProfile.new()
	var a: Array = _make(tr, vehicles, "hatch", 0.0, 0.0, 0.0, prof)
	var race = a[0]
	var pol = a[1]
	var me = a[2]
	_check(pol._settle.size() > 20 and pol._settle_names.size() == pol._settle.size(), "la policía conoce las ciudades y pueblos (%d)" % pol._settle.size())
	# un control lejos de todo pueblo
	var ci := -1
	for i in pol.checkpoints.size():
		var q: Vector2 = pol.checkpoints[i]["p"]
		if pol._settlement_at(q) < 0 and q.length() > 6000.0:
			ci = i
			break
	_check(ci >= 0, "hay un control de ruta fuera de todo pueblo")
	var ck: Dictionary = pol.checkpoints[ci]
	var cpos: Vector2 = ck["p"]
	var dir: Vector2 = ck["dir"]
	# ── 1) el jugador pasa el control con el hatch: persecución de ruta y el control lo recuerda
	me.place(cpos.x - dir.x * 120.0, cpos.y - dir.y * 120.0, atan2(dir.x, dir.y))
	pol.update(0.1)
	_check(pol.state == "armed" and pol.cp == ci, "al acercarse con el hatch el control se arma (%s)" % pol.state)
	me.place(cpos.x + dir.x * 10.0, cpos.y + dir.y * 10.0, atan2(dir.x, dir.y))
	me.phys.vx = dir.x * 20.0
	me.phys.vz = dir.y * 20.0
	pol.update(0.1)
	_check(pol.state == "chase" and pol.route_chase, "al pasar el control empieza una persecución de ruta")
	_check(pol.memory.has(pol._cp_key(ci)) and str(pol.memory[pol._cp_key(ci)]) == pol.car_sig(), "el control recuerda con qué auto persiguió (%s)" % pol.car_sig())
	_check(int(prof.d.get("police_mem", {}).size()) == 1 and prof.saves >= 1, "la memoria se guarda en el perfil (%d)" % prof.saves)
	# ── 2) llega a una ciudad: ya no tiene jurisdicción
	var town: Vector2 = pol._settle[0]
	var town_name: String = pol._settle_names[0]
	me.place(town.x, town.y, 0.0)
	me.phys.vx = 0.0
	me.phys.vz = 15.0
	pol.chase_t = 10.0
	var esc0: int = pol.stats["escapes"]
	pol._chase(1.0 / 30.0, town, me.phys)
	_check(pol.state == "idle" and pol.units.is_empty(), "al llegar a %s la persecución termina (los patrulleros se quedan afuera)" % town_name)
	_check(pol.stats["escapes"] == esc0 + 1, "cuenta como escape")
	_check(not pol.cool.has(-1), "no queda ningún control con clave inválida")
	_check(pol.cool.has(ci) and float(pol.cool[ci]) < 60.0, "el control queda en espera corta: si volvés, te esperan (%s s)" % str(snappedf(float(pol.cool.get(ci, 0.0)), 0.1)))
	# vuelve al control con el mismo auto: se arma de nuevo (después de la espera corta)
	pol.cool.clear()
	me.place(cpos.x - dir.x * 120.0, cpos.y - dir.y * 120.0, atan2(dir.x, dir.y))
	pol.update(0.1)
	_check(pol.state == "armed" and pol.cp == ci, "si vuelve con el mismo auto, el control lo espera armado")
	pol._clear()
	# ── 3) con otro auto no lo reconocen: el control no se arma y la ruta queda libre
	race.cfg["car"] = "gt"
	pol.cool.clear()
	me.place(cpos.x - dir.x * 120.0, cpos.y - dir.y * 120.0, atan2(dir.x, dir.y))
	pol.update(0.1)
	_check(pol.state == "idle", "con otro auto (gt) el control no lo reconoce y no se arma (%s)" % pol.state)
	me.place(cpos.x + dir.x * 10.0, cpos.y + dir.y * 10.0, atan2(dir.x, dir.y))
	pol.update(0.1)
	_check(pol.state == "idle" and pol.units.is_empty(), "pasa por el control sin que nadie lo persiga")
	# otra pintura del mismo auto también despista
	race.cfg["car"] = "hatch"
	race.cfg["state"] = {"paint": {"body": "#12ab34"}}
	me.place(cpos.x - dir.x * 120.0, cpos.y - dir.y * 120.0, atan2(dir.x, dir.y))
	pol.cool.clear()
	pol.update(0.1)
	_check(pol.state == "idle", "el mismo auto repintado tampoco es reconocido (%s)" % pol.state)
	# ── 4) las persecuciones de eventos o del modo Fugitivo no se cortan al llegar a una ciudad
	pol._clear()
	pol.event_chase(me.phys, 1)
	_check(pol.state == "chase" and not pol.route_chase, "una persecución de evento no es de ruta")
	pol.chase_t = 10.0
	me.place(town.x, town.y, 0.0)
	pol._chase(1.0 / 30.0, town, me.phys)
	_check(pol.state == "chase", "la persecución de un evento sigue aunque el jugador llegue a una ciudad")
	race.queue_free()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
