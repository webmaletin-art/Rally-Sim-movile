## Eventos del mundo (city/city_modes.gd) y el «desmadre» de la policía (city/city_police.gd): cada escape paga, la cacería que arranca por chocar y romper,
## el control que se suma a la persecución, y los eventos que manda el servidor: cazarrecompensas (varios autos, gana el primero), fuga (aguantar N min),
## contrarreloj a una ciudad y la carrera de la semana. Sin red: el servidor es un objeto falso en memoria.
## Uso: godot --headless --path godot --script res://tests/city_modes_test.gd
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
	var online = null
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

## El servidor de eventos, en memoria (las mismas respuestas que events_current / event_start / event_finish)
class FakeOnline:
	extends Node
	var state := {"now": 0, "events": [], "winners": []}
	var starts: Array = []
	var finishes: Array = []
	var won_slots := {}
	var next_run := 100
	func is_account() -> bool:
		return true
	func enabled() -> bool:
		return false
	func call_fn(fn: String, args: Dictionary, _need := true) -> Dictionary:
		match fn:
			"events_current":
				state["now"] = int(Time.get_unix_time_from_system())
				return {"ok": true, "data": state}
			"event_start":
				starts.append(args)
				next_run += 1
				return {"ok": true, "data": {"ok": true, "run": next_run}}
			"event_finish":
				finishes.append(args)
				if not bool(args["p_ok"]):
					return {"ok": true, "data": {"ok": true, "won": false}}
				return {"ok": true, "data": {"ok": true, "won": true, "reward": {"credits": 20000}}}
		return {"ok": false, "data": null, "error": "?"}

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
	var e0 := {"id": 7, "starts": 1000, "ends": 1900}
	_check(CityModes.phase_of(e0, 900.0) == "wait" and CityModes.phase_of(e0, 1100.0) == "live" and CityModes.phase_of(e0, 2000.0) == "over", "los eventos: esperan, están en vivo y terminan a la hora del servidor")
	var h := 0.0
	for i in 30:
		h = CityModes.hold_step(h, 10.0, 1.0, 60.0)
	var h2 := CityModes.hold_step(h, 50.0, 10.0, 60.0)
	_check(is_equal_approx(h, 30.0) and h2 < h and h2 > h - 10.0, "la barra sube pegado (%.0f s) y baja más despacio lejos (%.1f)" % [h, h2])
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
	# cada escape paga (siempre) y la racha sube
	race = _make(tr, vehicles, start.x, start.y, 0.0)
	pol = race.police
	_sim(race, 0.3)
	pol.rage = 1.0
	_sim(race, 0.2)
	_check(str(pol.state) == "chase", "la cacería arranca")
	var n_units := (pol.units as Array).size()
	# pasa por un control en plena persecución: sus patrulleros se suman
	var ck: Dictionary = pol.checkpoints[(pol.cp + 7) % pol.checkpoints.size()] # (otro control, no el de esta persecución)
	race.cars[0].place((ck["p"] as Vector2).x, (ck["p"] as Vector2).y, 0.0)
	_sim(race, 0.6)
	_check(pol._joined.size() == 1 and (pol.units as Array).size() >= 2, "pasa por un control escapando: sus patrulleros se suman (%d en la persecución)" % (pol.units as Array).size())
	for u in pol.units:
		u["car"].place(u["car"].phys.px + 5000.0, u["car"].phys.pz, 0.0)
		u["drv"].mode = "parked"
	pol.lose_t = CityPolice.ESCAPE_T
	_sim(race, 0.3)
	var prof: FakeProfile = race.profile
	_check(race.modes.streak == 1 and prof.earned >= CityModes.ESC_BASE, "escapó: cobra $%d y la racha es %d" % [int(prof.earned), race.modes.streak])
	race.queue_free()
	# eventos del servidor
	race = _make(tr, vehicles, start.x, start.y, 0.0)
	var srv := FakeOnline.new()
	race.add_child(srv)
	race.online = srv
	var md = race.modes
	var now := int(Time.get_unix_time_from_system())
	# cazarrecompensas con 2 autos, programada
	var bounty := {"id": 51, "kind": "bounty", "title": "Cazarrecompensas", "descr": "", "params": {"cars": ["veltor", "moust"], "hold_s": 20, "map_s": 30}, "reward": {"car": true},
		"starts": now + 600, "ends": now + 1800, "attempts": 0, "seed": 1234, "used": 0, "done": false, "winners": []}
	srv.state["events"] = [bounty]
	_sim(race, 0.3)
	md._poll_t = 0.0
	_sim(race, 0.5)
	_check(md.targets.is_empty() and md.events.size() == 1, "programada: avisa y espera (todavía no hay autos)")
	bounty["starts"] = now - 2
	md._poll_t = 0.0
	_sim(race, 0.5)
	_check(md.targets.size() == 2, "a la hora: se sueltan los 2 autos (%d)" % md.targets.size())
	var sp := CityModes.spawn_point(tr.city, 1234)
	var tq := Vector2(md.targets[0]["car"].phys.px, md.targets[0]["car"].phys.pz)
	_check(tq.distance_to(sp) < 90.0, "el primero aparece donde dice la semilla, el mismo lugar para todos (a %.0f m)" % tq.distance_to(sp))
	_sim(race, 6.0)
	_check(Vector2(md.targets[0]["car"].phys.px, md.targets[0]["car"].phys.pz).distance_to(tq) > 30.0, "y huyen por las calles")
	var tg0: Dictionary = md.targets[0]
	_sim(race, 24.0, func() -> void:
		if not tg0.get("done", true):
			var c = tg0["car"]
			race.cars[0].place(c.phys.px - sin(c.phys.yaw) * 9.0, c.phys.pz - cos(c.phys.yaw) * 9.0, c.phys.yaw))
	_check(srv.starts.size() >= 1 and int(srv.starts[0]["p_id"]) == 51, "al acercarse se anota el intento en el servidor")
	var fin_ok := false
	for f in srv.finishes:
		if bool(f["p_ok"]) and (f["p_trace"] as Array).size() >= 15:
			fin_ok = true
	_check(fin_ok and md.stats["caught"] == 1, "pegado 20 s: lo reclama con el recorrido y el servidor dice que ganó")
	_check(md.targets.is_empty() and race.cars.size() == 1, "ganó uno: los autos de esa cacería se van")
	# otro jugador atrapó un auto: se va con el aviso
	var b2 := bounty.duplicate(true)
	b2["id"] = 52
	b2["starts"] = now - 2
	srv.state["events"] = [b2]
	md._poll_t = 0.0
	_sim(race, 0.5)
	_check(md.targets.size() == 2, "otra cacería: 2 autos")
	b2["winners"] = [{"name": "ElRápido", "slot": 1}]
	md._poll_t = 0.0
	_sim(race, 0.5)
	_check(md.targets.size() == 1 and int(md.targets[0]["slot"]) == 0, "ElRápido atrapó uno: ese se va, el otro sigue suelto")
	race.queue_free()
	# fuga: cualquier persecución cuenta; aguantar chase_s y escapar (en una partida nueva)
	race = _make(tr, vehicles, start.x, start.y, 0.0)
	srv = FakeOnline.new()
	race.add_child(srv)
	race.online = srv
	md = race.modes
	var esc := {"id": 61, "kind": "escape", "title": "Fuga", "descr": "", "params": {"chase_s": 2}, "reward": {"rent": "police", "days": 3}, "starts": now - 10, "ends": now + 3600, "attempts": 5, "seed": 1, "used": 0, "done": false, "winners": []}
	srv.state["events"] = [esc]
	md._poll_t = 0.0
	pol = race.police
	_sim(race, 0.3)
	pol.rage = 1.0
	_sim(race, 0.5)
	_check(str(pol.state) == "chase" and srv.starts.size() == 1 and int(srv.starts[0]["p_id"]) == 61, "empieza la persecución: se anota un intento de la fuga")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2300:
		OS.delay_msec(50)
	for u in pol.units:
		u["car"].place(u["car"].phys.px + 5000.0, u["car"].phys.pz, 0.0)
		u["drv"].mode = "parked"
	pol.lose_t = CityPolice.ESCAPE_T
	_sim(race, 0.5)
	var last: Dictionary = srv.finishes[srv.finishes.size() - 1]
	_check(int(last["p_run"]) == srv.next_run and bool(last["p_ok"]) and float(last["p_value"]) >= 2.0, "aguantó %.1f s y escapó: fuga cumplida" % float(last["p_value"]))
	# contrarreloj a una ciudad
	var rc := {"id": 71, "kind": "reach", "title": "Contrarreloj", "descr": "", "params": {"speed": 24, "time_max": 1500}, "reward": {"credits": 20000}, "starts": now - 10, "ends": now + 3600, "attempts": 3, "seed": 5, "used": 0, "done": false, "winners": []}
	srv.state["events"] = [rc]
	md._poll_t = 0.0
	_sim(race, 0.5)
	var plan: Dictionary = md._reach
	_check(not plan.is_empty() and (plan["pos"] as Vector2).length() > CityModes.REACH_MIN and float(plan["limit"]) >= 120.0, "contrarreloj a %s: %.1f km, %d s" % [str(plan.get("town", "")), float(plan.get("dist", 0)) / 1000.0, int(plan.get("limit", 0))])
	var st0: Vector2 = plan["start"]
	race.cars[0].place(st0.x, st0.y, 0.0)
	race.cars[0].phys.vx = 0.0
	race.cars[0].phys.vz = 0.0
	_sim(race, 1.5, func() -> void:
		race.cars[0].phys.vx = 0.0
		race.cars[0].phys.vz = 0.0)
	_check(int(md._reach.get("run", -1)) >= 0, "frenó en el círculo de largada: empieza el intento")
	_sim(race, 2.0)
	if md._reach.is_empty():
		_check(false, "el contrarreloj sigue armado")
		race.queue_free()
		print("RESULTADO: FALLA")
		quit(1)
		return
	var tp: Vector2 = md._reach["pos"]
	race.cars[0].place(tp.x, tp.y, 0.0)
	_sim(race, 0.5)
	last = srv.finishes[srv.finishes.size() - 1]
	_check(bool(last["p_ok"]) and float(last["p_value"]) > 1.0, "llegó a tiempo (%.1f s): lo reclama" % float(last["p_value"]))
	race.queue_free()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
