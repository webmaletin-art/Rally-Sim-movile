## Policía del mundo abierto (city/city_police.gd, ai/police_driver.gd): controles en las rutas largas, persecución con física real sobre la región,
## arresto (multa y comisaría), escape y nivel según los pueblos cruzados.
## Uso: godot --headless --path godot --script res://tests/police_test.gd
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

func _run() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var tr := CityTrack.new()
	var rg = tr.region
	_check(rg != null and vehicles.has("police"), "hay región y patrullero")
	# 1) controles
	var probe: Array = _make(tr, vehicles, "hatch", 0.0, 0.0, 0.0)
	var pol0 = probe[1]
	var n: int = pol0.checkpoints.size()
	_check(n > 100, "controles en las rutas largas: %d" % n)
	var bad := 0
	for c in pol0.checkpoints:
		var q: Vector2 = c["p"]
		if q.length() < CityPolice.CITY_R or rg.in_town(q.x, q.y):
			bad += 1
	_check(bad == 0, "ningún control dentro de Dream City ni de un pueblo (%d mal)" % bad)
	_check(not pol0.station_pose.is_empty(), "la comisaría está sobre una calle de Dream City")
	# el control más lejano de la ciudad sobre una autopista o ruta
	var ck: Dictionary = pol0.checkpoints[0]
	for c in pol0.checkpoints:
		if int(rg.edges[c["ei"]][2]) == 2 and (c["p"] as Vector2).length() > 8000.0:
			ck = c
			break
	probe[0].queue_free()
	var dir: Vector2 = ck["dir"]
	# 2) arresto: el jugador llega al control y se queda parado → lo agarran, paga la multa y aparece en la comisaría
	var start: Vector2 = ck["p"] - dir * 300.0
	var a: Array = _make(tr, vehicles, "hatch", start.x, start.y, atan2(dir.x, dir.y))
	var race = a[0]
	var pol = a[1]
	var me = a[2]
	var drv := PoliceDriver.new() # el jugador lo maneja un piloto automático hasta pasar el control y frena
	drv.mode = "path"
	drv.path = PackedVector2Array([start, ck["p"] + dir * 40.0])
	me.driver = drv
	_sim(race, pol, 1.0)
	_check(pol.state == "armed" and pol.units.size() >= 2, "al acercarse se arma el control (%s, %d patrulleros)" % [pol.state, pol.units.size()])
	var st := {"chased": false, "arrested": false, "t": 0.0}
	_sim(race, pol, 40.0, func() -> void:
		if pol.state == "chase":
			st["chased"] = true
		if st["chased"] and not st["arrested"]:
			st["t"] += 4.0 / 120.0
		if pol.stats["arrests"] > 0 and not st["arrested"]:
			st["arrested"] = true
			me.driver = null) # (ya está en la comisaría: que no siga manejando)
	var chased: bool = st["chased"]
	var arrested: bool = st["arrested"]
	var t_chase: float = st["t"]
	_check(chased, "al pasar el control empieza la persecución")
	_check(arrested, "parado, lo arrestan (en %.1f s de persecución)" % t_chase)
	_sim(race, pol, 2.0)
	_check(race.profile.spent == CityPolice.FINE_BASE, "pagó la multa ($%d)" % race.profile.spent)
	_check(Vector2(me.phys.px, me.phys.pz).distance_to(Vector2(pol.station_pose[0], pol.station_pose[1])) < 3.0, "apareció frente a la comisaría")
	_check(pol.units.is_empty() and race.cars.size() == 1, "los patrulleros se van (%d autos)" % race.cars.size())
	race.queue_free()
	# 3) persecución: el jugador sigue de largo a fondo con un superdeportivo: los patrulleros lo siguen de cerca (no lo pierden en 30 s)
	var b: Array = _make(tr, vehicles, "veltor_gtr", start.x, start.y, atan2(dir.x, dir.y))
	race = b[0]
	pol = b[1]
	me = b[2]
	var far: Dictionary = rg.route(start, ck["p"] + dir * 6000.0)
	var d2 := PoliceDriver.new()
	d2.mode = "path"
	d2.grip = 1.0
	d2.path = far.get("pts", PackedVector2Array())
	me.driver = d2
	var st2 := {"close": 0.0, "worst": 0.0}
	_sim(race, pol, 45.0, func() -> void:
		if pol.state == "chase":
			var p := Vector2(me.phys.px, me.phys.pz)
			var dm := 1e9
			for u in pol.units:
				dm = minf(dm, Vector2(u["car"].phys.px, u["car"].phys.pz).distance_to(p))
			if dm < 60.0:
				st2["close"] += 4.0 / 120.0
			st2["worst"] = maxf(st2["worst"], dm)
		st2["k"] = int(st2.get("k", 0)) + 1
		if OS.has_environment("POL_DBG") and int(st2["k"]) % 60 == 0:
			var line := "  %s me %.0f km/h cp %.0f m |" % [pol.state, sqrt(me.phys.vx * me.phys.vx + me.phys.vz * me.phys.vz) * 3.6, Vector2(me.phys.px, me.phys.pz).distance_to(pol.checkpoints[maxi(pol.cp, 0)]["p"])]
			for u in pol.units:
				var c = u["car"]
				line += " %s %.0f km/h d=%.0f path=%d pm=%.2f |" % [u["drv"].role, sqrt(c.phys.vx * c.phys.vx + c.phys.vz * c.phys.vz) * 3.6, Vector2(c.phys.px, c.phys.pz).distance_to(Vector2(me.phys.px, me.phys.pz)), u["drv"].path.size(), c.phys.powerMul]
			print(line))
	var close_t: float = st2["close"]
	var dmin_max: float = st2["worst"]
	var sp: float = sqrt(me.phys.vx * me.phys.vx + me.phys.vz * me.phys.vz) * 3.6
	print("     persecución a fondo: %.0f s a menos de 60 m del patrullero más cercano, peor distancia %.0f m, arrestos %d, escapes %d, %.0f km/h al final" % [close_t, dmin_max, pol.stats["arrests"], pol.stats["escapes"], sp])
	_check(pol.stats["chases"] > 0 and (close_t > 8.0 or pol.stats["arrests"] > 0), "los patrulleros alcanzan a un superdeportivo a fondo")
	race.queue_free()
	# 4) escape y nivel
	var c4: Array = _make(tr, vehicles, "hatch", start.x, start.y, atan2(dir.x, dir.y))
	race = c4[0]
	pol = c4[1]
	_check(pol.wanted() == 2, "nivel 0: 2 patrulleros")
	pol.visited = {0: true, 1: true}
	pol.heat = 2
	_check(pol.wanted() == 4, "con dos pueblos cruzados: 4 patrulleros")
	pol.visited.clear()
	pol.heat = 0
	_sim(race, pol, 0.5)
	pol._start_chase(race.cars[0].phys)
	for u in pol.units: # todos lejos: el jugador se escapó
		u["car"].place(u["car"].phys.px + 5000.0, u["car"].phys.pz, 0.0)
		u["drv"].mode = "parked"
	pol.state = "chase"
	var esc := false
	for i in 30 * 12:
		pol.lose_t += 0.0
		pol._chase(1.0 / 30.0, Vector2(race.cars[0].phys.px, race.cars[0].phys.pz), race.cars[0].phys)
		if pol.state == "idle":
			esc = true
			break
	_check(esc and pol.stats["escapes"] == 1, "a más de %d m durante %d s se escapa" % [CityPolice.ESCAPE_R, CityPolice.ESCAPE_T])
	race.queue_free()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
