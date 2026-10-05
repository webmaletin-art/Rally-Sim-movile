## Travesía X: la ruta (largo, tramos, superficies, agua) y el convoy (un jugador a buen ritmo llega con el grupo; uno muy lento los pierde).
## El «jugador» lo maneja la IA con un tope de velocidad distinto en cada caso. Uso: godot --headless --path godot --script res://tests/travesia_test.gd [-- --km=9]
## (--km=9 corre solo los primeros 9 km —incluye barro, pedregal y vado—: es lo que corre la integración continua; sin eso da la vuelta entera, ~7 minutos)
extends SceneTree

const RouteTrack := preload("res://game/track/route_track.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const Convoy := preload("res://game/ai/convoy.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

class FakeCar:
	var phys
	var driver
class FakeSession:
	var state := "run"
	var prog := PackedFloat64Array()
	var last: PackedFloat64Array = PackedFloat64Array()
	var views: Array = []
	var track
	var time := 0.0

const IDS := ["pickup", "suv", "truck", "camo", "buggy", "pickup"] # el 0 es el «jugador»
const RANKS := [2, 0, 1, 3, 4, 5]

var goal_m := 0.0

func _init() -> void:
	var fail := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--km="):
			goal_m = float(a.substr(5)) * 1000.0
	var track = RouteTrack.new("travesia", "dirt", false, 0.0)
	var okl: bool = track.length > 15000.0 and track.length < 24000.0
	var muds := 0
	for i in track.n:
		if int(track.road_surf[i]) == 5:
			muds += 1
	var ok2: bool = track.sections.size() == 12 and muds > track.n / 12 and track.water.size() == 1 and track.half_width <= 3.2
	print("%s ruta: %.1f km, %d muestras, %d con barro, %d tramos, %d lago(s), ancho %.1f m" % ["OK  " if (okl and ok2) else "FALLA", track.length / 1000.0, track.n, muds, track.sections.size(), track.water.size(), track.half_width * 2.0])
	if not (okl and ok2):
		fail = true
	# alturas: sin saltos, pendiente máxima razonable
	var maxg := 0.0
	for i in track.n:
		var j: int = (i + 1) % int(track.n)
		var g := absf(track.cy[j] - track.cy[i]) / maxf(0.5, track.samples[i].distance_to(track.samples[j]))
		maxg = maxf(maxg, g)
	print("%s pendiente máxima %.0f %%" % ["OK  " if maxg < 0.2 else "FALLA", maxg * 100.0])
	if maxg >= 0.2:
		fail = true
	var scenarios: Array = [["jugador a buen ritmo (tope 11 m/s)", 11.0, false], ["jugador muy lento (tope 3 m/s)", 3.0, true]]
	for sc in scenarios:
		var r := _run(track, float(sc[1]))
		var good: bool = (r["lost"] == bool(sc[2])) and (bool(sc[2]) or r["finished"])
		if not good:
			fail = true
		print("%s %s → %s · %.0f s (%.1f min) · unión %.0f %% · máx. alejado %.0f m" % ["OK  " if good else "FALLA", sc[0], "PERDIÓ EL CONVOY" if r["lost"] else ("llegó" if r["finished"] else "no llegó"), r["t"], r["t"] / 60.0, r["coh"] * 100.0, r["maxout"]])
	quit(1 if fail else 0)

func _run(track, player_cap: float) -> Dictionary:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var cars: Array = []
	var ses := FakeSession.new()
	ses.track = track
	var phs: Array = []
	for i in IDS.size():
		var d: Dictionary = vehicles[IDS[i]].duplicate()
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var ph := VehiclePhysics.new(track.make_view(), VehicleParams.from_dict(d))
		var back := 6.0 + float(RANKS[i]) * 11.0
		var k := 0
		var acc := 0.0
		while acc < back:
			var j := posmod(k - 1, track.n)
			acc += track.samples[k].distance_to(track.samples[j])
			k = j
		var s: Vector3 = track.samples[k]
		var l: Vector3 = track.laterals[k]
		var t: Vector3 = track.tangents[k]
		var side := 0.9 if int(RANKS[i]) % 2 == 0 else -0.9
		ph.reset(s.x + l.x * side, s.z + l.z * side, atan2(t.x, t.z))
		var c := FakeCar.new()
		c.phys = ph
		c.driver = AIDriver.new(track.make_view(), ph, {"skill": 0.95 if i == 0 else 0.9, "lane": 0.0, "aggr": 0.25})
		cars.append(c)
		phs.append(ph)
		ses.views.append(track.make_view())
		ses.prog.append(-back)
		ses.last.append(0.0)
	for c in cars:
		c.driver.others = phs
	# arco inicial
	for i in cars.size():
		var v = ses.views[i]
		v.nearest(cars[i].phys.px, cars[i].phys.pz)
		var a: float = v.cum[v.r_idx] + v.r_t * (v.cum[v.r_idx + 1] - v.cum[v.r_idx])
		if a > track.length * 0.5:
			a -= track.length
		ses.prog[i] = a
		ses.last[i] = a
	var cv := Convoy.new()
	cv.setup(cars, ses)
	var h := 1.0 / 90.0
	var t := 0.0
	var maxout := 0.0
	var finished := false
	while t < 3600.0 and not cv.lost:
		for i in cars.size():
			var c: Vector3 = cars[i].driver.update(cars[i].phys, h)
			if i == 0 and player_cap > 0.0:
				cars[i].driver.max_v = player_cap
			cars[i].phys.step(h, c.x, c.y, c.z, false, false)
			var v = ses.views[i]
			v.nearest(cars[i].phys.px, cars[i].phys.pz)
			var a: float = v.cum[v.r_idx] + v.r_t * (v.cum[v.r_idx + 1] - v.cum[v.r_idx])
			var da: float = a - ses.last[i]
			if da < -track.length * 0.5:
				da += track.length
			elif da > track.length * 0.5:
				da -= track.length
			ses.prog[i] += da
			ses.last[i] = a
		t += h
		ses.time = t
		cv.update(h)
		maxout = maxf(maxout, cv.out_gap)
		if ses.prog[0] >= (goal_m if goal_m > 0.0 else track.length):
			finished = true
			break
	return {"lost": cv.lost, "finished": finished, "t": t, "coh": cv.cohesion(), "maxout": maxout}
