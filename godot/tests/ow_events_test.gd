## Carreras del mundo abierto (world/ow_events.gd + city/city_events.gd): hay eventos variados sobre calles de verdad, se descubren y quedan guardados,
## un sprint con rivales se corre hasta la meta con premio (y menos premio si se repite), una contrarreloj de montaña da medalla, la Huida usa a la policía.
## Uso: godot --headless --path godot --script res://tests/ow_events_test.gd
extends "res://tests/police_test.gd"

const OW := preload("res://game/world/ow_events.gd")
const CityEvents := preload("res://game/city/city_events.gd")
const CityGps := preload("res://game/city/city_gps.gd")

class EvProfile:
	extends RefCounted
	var d := {}
	var credits := 50000
	var earned: Array = []
	func spend(n: int, _k := "") -> bool:
		credits -= n
		return true
	var prog: Array = []
	func earn(n: float, kind := "", ref := "", extra := {}) -> void:
		credits += int(n)
		earned.append([int(n), kind, ref, extra])
	func progress(key: String, data := {}) -> void:
		prog.append([key, data])
	func add_xp(_x: float) -> void:
		pass
	func save() -> void:
		pass

func _ev_race(tr, vehicles, ev: Dictionary, car_id: String) -> Array:
	var s: Vector2 = ev["start"]
	var a: Array = _make(tr, vehicles, car_id, s.x, s.y, float(ev["yaw"]))
	var race = a[0]
	race.profile = EvProfile.new()
	race.cfg = {"car": car_id, "state": Profile.new_car_state(car_id)}
	race.set("police", a[1])
	var evs := CityEvents.new()
	evs.setup(race)
	return [race, a[1], a[2], evs]

var _rev_min := 0.0 # la menor velocidad hacia adelante de los rivales en los primeros 5 s (negativa = marcha atrás)

## corre la física con el jugador manejado por un piloto automático que sigue el recorrido del evento
func _drive(race, pol, evs, me, pts: PackedVector2Array, pace: float, secs: float) -> void:
	var drv := PoliceDriver.new()
	drv.mode = "path"
	drv.path = pts
	drv.grip = 1.05
	drv.pace = pace
	me.driver = drv
	var steps := int(secs * 30.0)
	for i in steps:
		for k in 4:
			_collide(race.cars)
			for c in race.cars:
				c.step(1.0 / 120.0)
			race.sim_t += 1.0 / 120.0
		pol.update(1.0 / 30.0)
		evs.update(1.0 / 30.0)
		if evs.state == "run" and evs.t < 5.0: # al largar ningún rival va marcha atrás (reporte del dueño, 14/10/2026)
			for r in evs.rivals:
				var cp = r["car"].phys
				_rev_min = minf(_rev_min, cp.vx * sin(cp.yaw) + cp.vz * cos(cp.yaw))
		if OS.has_environment("EV_DBG") and i % 150 == 0 and evs.state == "run":
			var pr: Array = evs._project(Vector2(me.phys.px, me.phys.pz), evs._pi)
			print("   t=%.0f arc=%.0f off=%.1f v=%.0f km/h pi=%d" % [evs.t, evs.arc, float(pr[2]), sqrt(me.phys.vx * me.phys.vx + me.phys.vz * me.phys.vz) * 3.6, evs._pi])
		if evs.state == "free" and i > 30:
			return

func _run() -> void:
	var SecS: GDScript = load("res://game/region/sectors.gd") # (la lógica se prueba con toda la región abierta; los sectores tienen su prueba: sectors_test)
	SecS.set("_loaded", true)
	SecS.set("_open_all", true)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var tr := CityTrack.new()
	var rg = tr.region
	var evs0 := OW.build(rg, CityGps.new(tr.city))
	var by := {}
	for e in evs0:
		by[e["type"]] = int(by.get(e["type"], 0)) + 1
	print("     eventos: %d %s" % [evs0.size(), str(by)])
	_check(evs0.size() >= 60 and by.size() >= 7, "eventos variados en el mundo abierto (%d de %d tipos)" % [evs0.size(), by.size()])
	var bad := 0
	var gaps := 0
	for e in evs0:
		var s: Vector2 = e["start"]
		var gi: Vector2 = tr.ground_info(s.x, s.y)
		if int(gi.y) >= 3:
			bad += 1
		var pts: PackedVector2Array = e["pts"]
		for i in range(1, pts.size()):
			if pts[i].distance_to(pts[i - 1]) > 60.0 and str(e["type"]) not in ["picada", "huida"]:
				gaps += 1
				break
	_check(bad == 0, "todas las largadas están sobre la calle (%d afuera)" % bad)
	_check(gaps == 0, "los recorridos son continuos (%d con saltos)" % gaps)
	# 1) descubrir
	var sprint: Dictionary = {}
	var mont: Dictionary = {}
	var huida: Dictionary = {}
	for e in evs0:
		if e["type"] == "sprint" and sprint.is_empty() and float(e["len"]) > 2400.0:
			sprint = e
		if e["type"] == "montana" and mont.is_empty():
			mont = e
		if e["type"] == "huida" and huida.is_empty():
			huida = e
	var r1: Array = _ev_race(tr, vehicles, sprint, "veltor_gtr")
	var race = r1[0]
	var pol = r1[1]
	var me = r1[2]
	var evs = r1[3]
	var back: Vector2 = sprint["start"] - (sprint["pts"][1] - sprint["pts"][0]).normalized() * 60.0
	me.place(back.x, back.y, float(sprint["yaw"]))
	evs.update(0.25)
	evs.update(0.25)
	_check(evs.found(str(sprint["id"])), "al pasar cerca se descubre «%s»" % sprint["name"])
	# 2) largar el sprint (frenado en el círculo) y correrlo a fondo
	me.place(sprint["start"].x, sprint["start"].y, float(sprint["yaw"]))
	for i in 14:
		evs.update(0.2)
	_check(evs.state == "countdown" and evs.rivals.size() == 3, "frenado en el círculo larga con 3 rivales (%s, %d)" % [evs.state, evs.rivals.size()])
	_check(evs._closure != null, "al largar se arma el cierre de calles (%d vallas: una ruta de la región casi no tiene calles que salgan; los circuitos de la ciudad sí, en street_closure_test)" % (evs._closure.count if evs._closure != null else -1))
	_drive(race, pol, evs, me, sprint["pts"], 1.05, 260.0)
	_check(evs._closure == null, "al terminar se abren las calles otra vez")
	var got: Array = race.profile.earned
	print("     sprint %s: %d m, premio %s · %s" % [sprint["id"], int(sprint["len"]), str(got), evs._banner.text.replace("\n", " | ")])
	_check(not got.is_empty() and str(got[0][1]) == "owev", "terminó el sprint con premio (%s)" % str(got))
	_check(_rev_min > -0.5, "al largar ningún rival va marcha atrás (menor velocidad hacia adelante %.1f m/s)" % _rev_min)
	var won1: bool = int(evs._rec(str(sprint["id"])).get("wins", 0)) > 0
	print("     ganó: %s · ritmo de los rivales ahora %.2f" % [str(won1), float(evs._rec(str(sprint["id"])).get("pace", 0.0))])
	race.queue_free()
	# 3) contrarreloj de montaña: medalla
	var r2: Array = _ev_race(tr, vehicles, mont, "rally80")
	race = r2[0]
	me = r2[2]
	evs = r2[3]
	evs._begin(evs.events.find(evs.events.filter(func(x): return x["id"] == mont["id"])[0]))
	_drive(race, r2[1], evs, me, mont["pts"], 1.0, 300.0)
	var got2: Array = race.profile.earned
	print("     montaña %s: %d m, oro %.0f s, premio %s" % [mont["id"], int(mont["len"]), float(mont["gold"]), str(got2)])
	_check(evs.state == "free" and evs._rec(str(mont["id"])).get("runs", 0) == 1, "la contrarreloj termina (medalla o sin medalla)")
	race.queue_free()
	# 4) repetir un evento ganado paga menos
	var r3: Array = _ev_race(tr, vehicles, sprint, "veltor_gtr")
	race = r3[0]
	evs = r3[3]
	evs._saved()[str(sprint["id"])] = {"found": true, "wins": 1, "pace": 0.85}
	evs._begin(evs.events.find(evs.events.filter(func(x): return x["id"] == sprint["id"])[0]))
	_drive(race, r3[1], evs, r3[2], sprint["pts"], 1.05, 260.0)
	var got3: Array = race.profile.earned
	if not got3.is_empty() and not got.is_empty():
		_check(int(got3[0][0]) < int(got[0][0]) or int(got[0][0]) < int(sprint["reward"]), "repetir un evento ganado paga menos ($%d vs $%d)" % [int(got3[0][0]), int(got[0][0])])
	race.queue_free()
	# 5) Huida: la policía sale ya; quedarse quieto = te agarran y se pierde el evento
	var r4: Array = _ev_race(tr, vehicles, huida, "hatch")
	race = r4[0]
	pol = r4[1]
	evs = r4[3]
	evs._begin(evs.events.find(evs.events.filter(func(x): return x["id"] == huida["id"])[0]))
	for i in 30 * 40:
		for k in 4:
			_collide(race.cars)
			for c in race.cars:
				c.step(1.0 / 120.0)
		pol.update(1.0 / 30.0)
		evs.update(1.0 / 30.0)
		if evs.state == "free":
			break
	print("     huida: %s · persecuciones %d arrestos %d · %s" % [evs.state, pol.stats["chases"], pol.stats["arrests"], evs._banner.text.replace("\n", " | ")])
	_check(pol.stats["chases"] >= 1 and pol.stats["arrests"] >= 1 and race.profile.earned.is_empty(), "Huida: sale la policía, parado te agarran y no hay premio")
	race.queue_free()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
