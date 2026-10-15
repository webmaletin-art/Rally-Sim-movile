## Modos del mundo abierto contra la IA (city/city_modes.gd) y el «desmadre» de la policía (city/city_police.gd): reglas puras, la cacería que arranca por
## chocar y romper cosas, el modo Fugitivo (paga cada escape) y la Caza recompensas (pegado HOLD_S segundos → el auto es tuyo, con los topes del servidor).
## Sin red. Uso: godot --headless --path godot --script res://tests/city_modes_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityPolice := preload("res://game/city/city_police.gd")
const CityModes := preload("res://game/city/city_modes.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const AiCars := preload("res://game/data/ai_cars.gd")

## Lo mínimo de race.gd que usan la policía y los modos
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
	var teleports := 0
	var police = null
	var ow_events = null
	var modes = null
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
		teleports += 1

class FakeProfile:
	extends RefCounted
	var credits := 50000
	var earned := 0.0
	var given: Array = []
	var d := {"owned": {"hatch": {}}}
	func spend(n: int, _k := "") -> bool:
		credits -= n
		return true
	func earn(n: float, _k := "", _r := "") -> void:
		earned += n
	func add_xp(_n: float) -> void:
		pass
	func owns(id: String) -> bool:
		return (d["owned"] as Dictionary).has(id)
	func give(id: String, why := "") -> void:
		d["owned"][id] = {}
		given.append([id, why])
	func save() -> void:
		pass

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _make(tr, vehicles, x: float, z: float, yaw: float) -> FakeRace:
	var race := FakeRace.new()
	race.track = tr
	race.vehicles = vehicles
	race.profile = FakeProfile.new()
	root.add_child(race)
	var su: Dictionary = CarBuild.build_params(vehicles["hatch"], Profile.new_car_state("hatch"))
	var me := Car.new(tr, VehicleParams.from_dict(su), true, true, Color.BLUE, Color.GRAY)
	me.solid = true
	me.place(x, z, yaw)
	race.add_child(me.visual)
	race.cars.append(me)
	race.police = CityPolice.new()
	race.police.setup(race)
	race.modes = CityModes.new()
	race.modes.setup(race)
	return race

## n segundos: física a 120 Hz, policía y modos a 30 Hz; `each` corre cada paso de 30 Hz
func _sim(race, secs: float, each := Callable()) -> void:
	for i in int(secs * 120.0):
		for c in race.cars:
			c.step(1.0 / 120.0)
		race.sim_t += 1.0 / 120.0
		if i % 4 == 0:
			if each.is_valid():
				each.call()
			race.police.update(4.0 / 120.0)
			race.modes.update(4.0 / 120.0)

func _run() -> void:
	var SecS: GDScript = load("res://game/region/sectors.gd")
	SecS.set("_loaded", true)
	SecS.set("_open_all", true)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	# reglas puras
	_check(CityModes.escape_reward(0, 0.0) == CityModes.ESC_BASE and CityModes.escape_reward(3, 60.0) > CityModes.escape_reward(1, 60.0), "cada escape paga más con nivel y tiempo (%d · %d)" % [CityModes.escape_reward(1, 60.0), CityModes.escape_reward(3, 60.0)])
	var pool := CityModes.bounty_pool(vehicles)
	var bad := 0
	for id in pool:
		if CityModes.NO_BOUNTY.has(id) or int(CarBuild.catalog()["cars"][id]["price"]) > CityModes.PRICE_MAX:
			bad += 1
	_check(pool.size() >= 10 and bad == 0, "autos para cazar: %d, ninguno premium, especial ni de más de $%d" % [pool.size(), CityModes.PRICE_MAX])
	var now := 2000000000
	_check(CityModes.bounty_prize("gt", 72000, false, 0, now).get("car", "") == "gt", "atrapado y no lo tenías: el auto es tuyo")
	_check(int(CityModes.bounty_prize("gt", 72000, true, 0, now).get("credits", 0)) == 18000, "si ya lo tenés: el 25 por ciento de su precio")
	_check(CityModes.bounty_prize("gt", 72000, false, now - 3600, now).has("credits"), "un solo auto por día (como el servidor)")
	var tr := CityTrack.new()
	var start: Vector2 = Vector2(0.0, 160.0) # Avenida 3
	# desmadre: chocar paredes y romper cosas llena el medidor; lleno, arranca la cacería
	var race := _make(tr, vehicles, start.x, start.y, 0.0)
	var pol = race.police
	_sim(race, 0.3)
	pol.on_wall(3.0)
	_check(pol.rage == 0.0, "un roce no cuenta")
	pol.on_wall(18.0)
	var one := float(pol.rage)
	_check(one >= 0.25 and one < 0.7, "un choque fuerte contra una pared llena una parte (%.2f)" % one)
	pol._rage_quiet = 10.0
	pol._rage(10.0, start, race.cars[0].phys)
	_check(pol.rage < one, "manejando tranquilo se vacía (%.2f → %.2f)" % [one, pol.rage])
	pol.on_wall(25.0)
	pol.on_wall(25.0)
	pol.on_car_hit(12.0)
	pol.on_wall(25.0)
	_sim(race, 0.5)
	_check(str(pol.state) == "chase" and not (pol.units as Array).is_empty(), "lleno: la policía arranca la cacería (%s, %d patrulleros)" % [pol.state, (pol.units as Array).size()])
	_check(pol.rage == 0.0, "y el medidor vuelve a cero")
	race.queue_free()
	# fugitivo: más sensible, y cada escape paga
	race = _make(tr, vehicles, start.x, start.y, 0.0)
	pol = race.police
	_sim(race, 0.3)
	race.modes.start("fugitivo")
	_check(race.modes.mode == "fugitivo" and pol.fugitive, "modo Fugitivo prendido")
	pol.on_wall(18.0)
	_check(pol.rage > one * 1.8, "en el modo Fugitivo el mismo choque cuenta el doble (%.2f)" % pol.rage)
	pol.rage = 1.0
	_sim(race, 0.2)
	_check(str(pol.state) == "chase", "la cacería arranca")
	for u in pol.units:
		u["car"].place(u["car"].phys.px + 5000.0, u["car"].phys.pz, 0.0)
		u["drv"].mode = "parked"
	pol.lose_t = CityPolice.ESCAPE_T
	_sim(race, 0.3)
	var prof: FakeProfile = race.profile
	_check(race.modes.streak == 1 and prof.earned >= CityModes.ESC_BASE and pol.fugitive_level == 1, "escapó: cobra $%d, racha %d y la próxima viene más fuerte (nivel extra %d)" % [int(prof.earned), race.modes.streak, pol.fugitive_level])
	race.modes.toggle("fugitivo")
	_check(race.modes.mode == "" and not pol.fugitive, "desde la pausa se apaga")
	race.queue_free()
	# caza recompensas: aparece lejos, huye; pegado HOLD_S s → el auto es tuyo
	race = _make(tr, vehicles, start.x, start.y, 0.0)
	pol = race.police
	_sim(race, 0.3)
	race.modes.start("caza")
	var md = race.modes
	_check(md.mode == "caza" and not md.target.is_empty(), "aparece un auto para cazar: %s ($%d)" % [str(md.target.get("name", "")), int(md.target.get("price", 0))])
	var tc = md.target["car"]
	var d0 := Vector2(tc.phys.px, tc.phys.pz).distance_to(start)
	_check(d0 > 250.0 and d0 < 900.0, "lejos pero no tanto (%.0f m)" % d0)
	var p0 := Vector2(tc.phys.px, tc.phys.pz)
	_sim(race, 8.0)
	var moved := Vector2(tc.phys.px, tc.phys.pz).distance_to(p0)
	_check(moved > 40.0, "anda suelto por las calles (%.0f m en 8 s)" % moved)
	var vid := str(md.target["vid"])
	var owned_before: bool = prof.owns(vid) if false else race.profile.owns(vid)
	# el jugador se le pega (se lo pone justo detrás todo el tiempo)
	_sim(race, CityModes.HOLD_S + 1.5, func() -> void:
		if not md.target.is_empty():
			var c = md.target["car"]
			race.cars[0].place(c.phys.px - sin(c.phys.yaw) * 9.0, c.phys.pz - cos(c.phys.yaw) * 9.0, c.phys.yaw))
	var given: Array = race.profile.given
	_check(md.stats["caught"] == 1, "pegado %d s: lo atrapó" % int(CityModes.HOLD_S))
	_check(not owned_before and given.size() == 1 and given[0][0] == vid and given[0][1] == "bounty", "el auto es suyo y la cuenta lo valida como «bounty» (%s)" % [str(given)])
	_sim(race, 3.5)
	_check(md.mode == "" and md.target.is_empty() and race.cars.size() == 1, "termina y el auto de la IA se va")
	# perder de vista: se escapa
	race.modes.start("caza")
	md.target["car"].place(start.x + 9000.0, start.y, 0.0)
	md.target["drv"].mode = "parked"
	race.cars[0].place(start.x, start.y, 0.0)
	_sim(race, CityModes.LOST_T + 1.0)
	_check(md.mode == "" and md.stats["lost"] == 1, "muy lejos %d s: se escapó" % int(CityModes.LOST_T))
	race.queue_free()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
