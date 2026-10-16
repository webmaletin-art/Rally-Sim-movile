## Granja de escapes (auditoría 15/10/2026, P0): ¿se puede ganar plata encadenando «desmadre → persecución → escape» más rápido que con cualquier otra cosa?
## Mide, con física real y la IA manejando a fondo por una autopista (el caso más fácil para escapar), cuánto dura cada ciclo, cuántos terminan en escape
## y cuánto se gana por hora (escapes − multas), con el auto inicial y con un superdeportivo. Imprime los números para docs/AUDITORIA_CICLO_DE_JUEGO.md.
## Uso: godot --headless --path godot --script res://tests/escape_farm_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityPolice := preload("res://game/city/city_police.gd")
const PoliceDriver := preload("res://game/ai/police_driver.gd")
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
	var cfg := {}
	var vehicles: Dictionary
	var race_hud = null
	var audio = null
	var sim_t := 0.0
	var profile = null
	var teleports := 0
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
		teleports += 1

class FakeProfile:
	extends RefCounted
	var credits := 50000
	var spent := 0
	func spend(n: int, _k := "") -> bool:
		credits -= n
		spent += n
		return true

const CityModes := preload("res://game/city/city_modes.gd")

const FILL_S := 10.0 # llenar el desmadre: 10 s a 170 km/h por la ciudad (city_police.gd: RAGE_KMH 110, +dt·(v−110)/600) — lo más rápido posible
const CYCLE_MAX := 80.0

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _make(tr, vehicles, player_id: String, x: float, z: float, yaw: float) -> Array:
	var race := FakeRace.new()
	race.track = tr
	race.vehicles = vehicles
	race.profile = FakeProfile.new()
	root.add_child(race)
	var su: Dictionary = CarBuild.build_params(vehicles[player_id], Profile.new_car_state(player_id))
	var me := Car.new(tr, VehicleParams.from_dict(su), true, true, Color.BLUE, Color.GRAY)
	me.solid = true
	me.place(x, z, yaw)
	race.add_child(me.visual)
	race.cars.append(me)
	var pol := CityPolice.new()
	pol.setup(race)
	return [race, pol, me]

## Choque entre autos simplificado (círculos de 1,1 m en la trompa, el centro y la cola), como race._resolve_collisions
func _collide(cars: Array) -> void:
	for a in cars.size():
		for b in range(a + 1, cars.size()):
			var pa = cars[a].phys
			var pb = cars[b].phys
			if Vector2(pa.px - pb.px, pa.pz - pb.pz).length_squared() > 40.0:
				continue
			for ka in [-1.0, 0.0, 1.0]:
				for kb in [-1.0, 0.0, 1.0]:
					var ca := Vector2(pa.px + sin(pa.yaw) * ka * 1.4, pa.pz + cos(pa.yaw) * ka * 1.4)
					var cb := Vector2(pb.px + sin(pb.yaw) * kb * 1.4, pb.pz + cos(pb.yaw) * kb * 1.4)
					var dv := cb - ca
					var d := dv.length()
					if d >= 2.2 or d < 0.001:
						continue
					var nrm := dv / d
					var over := 2.2 - d
					var wa: float = pb.V.mass / (pa.V.mass + pb.V.mass)
					pa.px -= nrm.x * over * wa
					pa.pz -= nrm.y * over * wa
					pb.px += nrm.x * over * (1.0 - wa)
					pb.pz += nrm.y * over * (1.0 - wa)
					var rv: float = Vector2(pb.vx - pa.vx, pb.vz - pa.vz).dot(nrm)
					if rv < 0.0:
						var j: float = -1.3 * rv / (1.0 / pa.V.mass + 1.0 / pb.V.mass)
						pa.vx -= j * nrm.x / pa.V.mass
						pa.vz -= j * nrm.y / pa.V.mass
						pb.vx += j * nrm.x / pb.V.mass
						pb.vz += j * nrm.y / pb.V.mass

## n segundos de física a 120 Hz (todos los autos con su piloto) + la policía a 30 Hz
func _sim(race, pol, secs: float, on_step := Callable()) -> void:
	var steps := int(secs * 120.0)
	for i in steps:
		_collide(race.cars)
		for c in race.cars:
			c.step(1.0 / 120.0)
		race.sim_t += 1.0 / 120.0
		if i % 4 == 0:
			pol.update(4.0 / 120.0)
			if on_step.is_valid():
				on_step.call()

## Un ciclo: el jugador va a fondo por la ruta, la policía arranca la cacería por desmadre (nivel 1, el de la ciudad) y se mide hasta el escape o el arresto
func _cycle(tr, vehicles, car_id: String, start: Vector2, route: PackedVector2Array, yaw: float, modes_pay: bool) -> Dictionary:
	var a: Array = _make(tr, vehicles, car_id, start.x, start.y, yaw)
	var race = a[0]
	var pol = a[1]
	var me = a[2]
	var drv := PoliceDriver.new()
	drv.mode = "path"
	drv.grip = 1.0
	drv.path = route
	me.driver = drv
	_sim(race, pol, 6.0) # toma velocidad
	pol.event_chase(me.phys, 1)
	var st := {"t": 0.0, "end": ""}
	_sim(race, pol, CYCLE_MAX, func() -> void:
		if st["end"] != "":
			return
		st["t"] = float(st["t"]) + 4.0 / 120.0
		if pol.stats["escapes"] > 0:
			st["end"] = "escape"
		elif pol.stats["arrests"] > 0:
			st["end"] = "arresto"
			me.driver = null)
	var t: float = st["t"]
	var end: String = st["end"]
	var pay := CityModes.escape_reward(1, t) if end == "escape" else 0
	var fine := int(race.profile.spent)
	race.queue_free()
	return {"t": t, "end": end if end != "" else "sigue", "pay": pay, "fine": fine}

func _run() -> void:
	var SecS: GDScript = load("res://game/region/sectors.gd")
	SecS.set("_loaded", true)
	SecS.set("_open_all", true)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var tr := CityTrack.new()
	var rg = tr.region
	var probe: Array = _make(tr, vehicles, "hatch", 0.0, 0.0, 0.0)
	var pol0 = probe[1]
	var cks: Array = []
	for c in pol0.checkpoints:
		if int(rg.edges[c["ei"]][2]) == 2 and (c["p"] as Vector2).length() > 8000.0:
			cks.append(c)
	probe[0].queue_free()
	_check(cks.size() >= 3, "hay autopistas para probar (%d controles)" % cks.size())
	var res := {}
	for car_id in ["veltor_gtr", "hatch"]:
		var n := 3 if car_id == "veltor_gtr" else 2
		var tot_t := 0.0
		var tot := 0
		var esc := 0
		var lines: Array = []
		for k in n:
			var ck: Dictionary = cks[(k * 7) % cks.size()]
			var dir: Vector2 = ck["dir"]
			var start: Vector2 = ck["p"] + dir * 400.0 # pasado el control (que no se arme el control: la cacería es la del desmadre)
			var far: Dictionary = rg.route(start, start + dir * 9000.0)
			var r := _cycle(tr, vehicles, car_id, start, far.get("pts", PackedVector2Array()), atan2(dir.x, dir.y), true)
			tot_t += FILL_S + float(r["t"])
			tot += int(r["pay"]) - int(r["fine"])
			if r["end"] == "escape":
				esc += 1
			lines.append("%s %.0f s %s" % [r["end"], float(r["t"]), ("+$%d" % int(r["pay"])) if int(r["pay"]) > 0 else ("−$%d" % int(r["fine"]))])
		var per_h := float(tot) / maxf(tot_t, 1.0) * 3600.0
		res[car_id] = per_h
		print("     %s: %s → $%d en %.0f s = $%.0f por hora (%d escapes de %d)" % [car_id, " · ".join(lines), tot, tot_t, per_h, esc, n])
	# referencia: una carrera del mapa ganada por primera vez paga la mediana $5.000 y lleva ≈ 4–6 min con el viaje (≈ $50–75.000/h);
	# repetida paga el 35 % (≈ $17–26.000/h). El techo del servidor es $300.000/h.
	var top: float = maxf(float(res["veltor_gtr"]), float(res["hatch"]))
	_check(top <= 75000.0, "encadenar escapes no paga más que ganar carreras del mapa por primera vez (≤ $75.000/h): $%.0f/h" % top)
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
