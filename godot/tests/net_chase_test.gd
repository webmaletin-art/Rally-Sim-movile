## Red de rutas: el piloto (NetDriver) recorre la red sin salirse ni trabarse, y la persecución (NetSession) termina con un ganador.
## Uso: godot --headless --path godot --script res://tests/net_chase_test.gd
extends SceneTree

const NetTrack := preload("res://game/net/net_track.gd")
const NetSession := preload("res://game/net/net_session.gd")
const NetDriver := preload("res://game/net/net_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

class FakeCar:
	extends RefCounted
	var phys
	var driver
	func step(h: float) -> void:
		var c: Vector3 = driver.update(phys, h)
		phys.step(h, c.x, c.y, c.z, false, driver.get("nitro") == true)

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _make(track, car_id: String, slot: int, mode: String, skill: float, seed_: int) -> FakeCar:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var d: Dictionary = vehicles[car_id].duplicate()
	d["camberF"] = -1.0
	d["camberR"] = -0.5
	d["toeF"] = 0.0
	d["toeR"] = 0.1
	d["pressF"] = 30.0
	d["pressR"] = 30.0
	var c := FakeCar.new()
	c.phys = VehiclePhysics.new(track, VehicleParams.from_dict(d))
	var sp: Array = track.station_pose(0, slot)
	c.phys.reset(sp[0], sp[1], sp[2])
	c.driver = NetDriver.new(track.net, mode, skill, seed_)
	return c

func _init() -> void:
	var track = NetTrack.new("red_1")
	# 1) un auto solo recorre la red 6 minutos
	for car_id in ["hatch", "pickup", "gt"]:
		var c := _make(track, car_id, 0, "wander", 0.9, 3)
		var h := 1.0 / 120.0
		var t := 0.0
		var dist := 0.0
		var off := 0.0
		var vmax := 0.0
		var prev := Vector2(c.phys.px, c.phys.pz)
		var stuck := 0.0
		var worst_stuck := 0.0
		while t < 360.0:
			c.step(h)
			t += h
			var q := Vector2(c.phys.px, c.phys.pz)
			dist += q.distance_to(prev)
			prev = q
			var sp := sqrt(c.phys.vx * c.phys.vx + c.phys.vz * c.phys.vz)
			vmax = maxf(vmax, sp)
			stuck = stuck + h if sp < 1.0 else 0.0
			worst_stuck = maxf(worst_stuck, stuck)
			var gi: Vector2 = track.ground_info(q.x, q.y)
			if int(gi.y) >= 3:
				off += h
		_check(dist > 360.0 * 14.0, "%s: recorrió %.1f km en 6 min (prom. %.0f km/h, máx. %.0f km/h)" % [car_id, dist / 1000.0, dist / 360.0 * 3.6, vmax * 3.6])
		_check(off < 360.0 * 0.10, "%s: fuera del camino %.1f s de 360" % [car_id, off])
		_check(worst_stuck < 8.0, "%s: peor quedada parado %.1f s" % [car_id, worst_stuck])
	# 2) persecución: el jugador es otro piloto automático (huye); el rival lo persigue. Termina con un ganador y los roles pueden cambiar.
	for mode in ["flee", "chase"]:
		var cars: Array = []
		var player := _make(track, "hatch", 1 if mode == "chase" else 0, "pursue" if mode == "chase" else "wander", 0.85, 5)
		var rival := _make(track, "hatch", 0 if mode == "chase" else 1, "wander" if mode == "chase" else "pursue", 0.9, 11)
		cars.append(player)
		cars.append(rival)
		var ses := NetSession.new(track, {"netMode": mode, "chaseGap": 150.0, "skill": 0.9}, 2)
		var h2 := 1.0 / 60.0
		var t2 := 0.0
		var swaps_seen := 0
		while t2 < 900.0 and ses.state == "run":
			if mode == "chase":
				player.driver.target_pos = Vector2(rival.phys.px, rival.phys.pz)
			for c in cars:
				c.step(h2)
			ses.update(h2, cars)
			t2 += h2
			swaps_seen = ses.swaps
		_check(ses.state == "done", "%s: terminó en %.0f s (%s, %d cambios de rol, máx dist %d m)" % [mode, t2, ses.note, swaps_seen, int(ses.dist)])
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
