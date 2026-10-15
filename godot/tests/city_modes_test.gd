## Modos del mundo abierto contra la IA (city/city_modes.gd) y el «desmadre» de la policía (city/city_police.gd): reglas puras, la cacería que arranca por
## chocar y romper cosas, el modo Fugitivo (paga cada escape) y la RECOMPENSA del servidor (un solo ganador: se suelta a la hora del servidor, pegado hold_s
## segundos → bounty_claim; si la gana otro, se va). Sin red: el servidor es un objeto falso en memoria. Uso: godot --headless --path godot --script res://tests/city_modes_test.gd
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

## El servidor de la recompensa, en memoria (las mismas respuestas que bounty_current / bounty_join / bounty_claim)
class FakeOnline:
	extends Node
	var state := {}
	var claims: Array = []
	var joins: Array = []
	var winner := ""
	func is_account() -> bool:
		return true
	func enabled() -> bool:
		return false
	func call_fn(fn: String, args: Dictionary, _need := true) -> Dictionary:
		match fn:
			"bounty_current":
				return {"ok": true, "data": state}
			"bounty_join":
				joins.append(int(args["p_id"]))
				return {"ok": true, "data": {"ok": true}}
			"bounty_claim":
				claims.append(args)
				if winner != "":
					return {"ok": true, "data": {"ok": false, "reason": "ya la ganó " + winner, "winner": winner}}
				winner = "yo"
				return {"ok": true, "data": {"ok": true, "car": "veltor", "dup": false}}
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
	var e0 := {"id": 7, "starts": 1000, "ends": 1900, "won": false}
	_check(CityModes.phase_of(e0, 900.0) == "wait" and CityModes.phase_of(e0, 1100.0) == "live" and CityModes.phase_of(e0, 2000.0) == "over", "la recompensa: espera, suelta y se va a la hora del servidor")
	_check(CityModes.phase_of({"id": 7, "starts": 1000, "ends": 1900, "won": true}, 1100.0) == "over", "si ya la ganó alguien, se terminó para todos")
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
	# recompensa: el servidor la suelta; aparece en el mismo lugar para todos, huye; pegado hold_s s → bounty_claim (gana el primero)
	race = _make(tr, vehicles, start.x, start.y, 0.0)
	var srv := FakeOnline.new()
	race.add_child(srv)
	race.online = srv
	var md = race.modes
	var now := int(Time.get_unix_time_from_system())
	srv.state = {"next": {"id": 41, "car": "veltor", "starts": now + 300, "ends": now + 1200, "hold_s": 20, "map_s": 30, "seed": 1234, "won": false, "winner": "", "mine": false, "now": now, "notice_s": 600}, "last": null}
	_sim(race, 0.3)
	md._poll_t = 0.0
	_sim(race, 0.3)
	_check(CityModes.phase_of(md.ev, md.now_server()) == "wait" and md.target.is_empty(), "programada: avisa y espera (todavía no hay auto)")
	srv.state["next"]["starts"] = now - 2
	srv.state["next"]["now"] = now
	md._poll_t = 0.0
	_sim(race, 1.0)
	_check(not md.target.is_empty() and md.target["vid"] == "veltor" and srv.joins == [41], "se soltó: aparece el auto y el jugador queda anotado en la caza")
	var sp := CityModes.spawn_point(tr.city, 1234)
	var tq := Vector2(md.target["car"].phys.px, md.target["car"].phys.pz)
	_check(tq.distance_to(sp) < 90.0, "aparece donde dice la semilla, el mismo lugar para todos (a %.0f m: ya arrancó a huir)" % tq.distance_to(sp))
	_sim(race, 6.0)
	_check(Vector2(md.target["car"].phys.px, md.target["car"].phys.pz).distance_to(tq) > 30.0, "y huye por las calles")
	_sim(race, 22.0, func() -> void:
		if not md.target.is_empty():
			var c = md.target["car"]
			race.cars[0].place(c.phys.px - sin(c.phys.yaw) * 9.0, c.phys.pz - cos(c.phys.yaw) * 9.0, c.phys.yaw))
	_check(srv.claims.size() == 1 and int(srv.claims[0]["p_id"]) == 41 and (srv.claims[0]["p_trace"] as Array).size() >= 20, "pegado 20 s: se reclama (con el recorrido para revisar: %d puntos)" % (srv.claims[0]["p_trace"] as Array).size() if not srv.claims.is_empty() else "pegado 20 s: se reclama")
	_check(md.stats["caught"] == 1 and bool(md.ev.get("mine", false)), "el servidor dice que llegó primero: la gana")
	_sim(race, 5.0)
	_check(md.target.is_empty() and race.cars.size() == 1, "el auto se va (el premio lo da el servidor a la cuenta)")
	race.queue_free()
	# otro jugador la gana antes: se va con el aviso
	race = _make(tr, vehicles, start.x, start.y, 0.0)
	srv = FakeOnline.new()
	race.add_child(srv)
	race.online = srv
	md = race.modes
	now = int(Time.get_unix_time_from_system())
	var live := {"id": 42, "car": "moust", "starts": now - 5, "ends": now + 900, "hold_s": 60, "map_s": 30, "seed": 99, "won": false, "winner": "", "mine": false, "now": now, "notice_s": 600}
	srv.state = {"next": live, "last": null}
	_sim(race, 0.3)
	md._poll_t = 0.0
	_sim(race, 1.0)
	_check(not md.target.is_empty(), "suelta otra")
	var won := live.duplicate()
	won["won"] = true
	won["winner"] = "ElRápido"
	srv.state = {"next": null, "last": won}
	md._poll_t = 0.0
	_sim(race, 1.0)
	_check(md.target.is_empty() and md.stats["lost"] == 1, "la ganó otro (ElRápido): el auto se va")
	race.queue_free()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
