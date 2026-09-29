## Los autos de IA dan vueltas al circuito de prueba sin salirse. Uso: godot --headless --path godot --script res://tests/ai_test.gd
extends SceneTree

const CircuitTrack := preload("res://game/track/circuit_track.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const RingDriver := preload("res://game/ai/ring_driver.gd")

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var track := CircuitTrack.new()
	var fail := false
	for id in vehicles.keys():
		var d: Dictionary = vehicles[id].duplicate()
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var sp: Array = track.start_pose(0)
		var ph := VehiclePhysics.new(track, VehicleParams.from_dict(d))
		ph.reset(sp[0], sp[1], sp[2])
		var drv := RingDriver.new(track, 24.0, 0.0)
		var off := 0
		var max_off := 0.0
		var turns := 0.0
		var last_th := atan2(ph.pz, ph.px)
		var steps := 120 * 100
		for i in steps:
			var c: Vector3 = drv.update(ph, 1.0 / 120.0)
			ph.step(1.0 / 120.0, c.x, c.y, c.z, false)
			var th := atan2(ph.pz, ph.px)
			var dth := wrapf(th - last_th, -PI, PI)
			turns += dth
			last_th = th
			var dist := absf(sqrt(ph.px * ph.px + ph.pz * ph.pz) - track.radius(th))
			max_off = maxf(max_off, dist)
			if dist > CircuitTrack.HALF_W:
				off += 1
		var laps := absf(turns) / TAU
		var ok := max_off < CircuitTrack.HALF_W + CircuitTrack.SHOULDER and laps > 0.8
		if not ok:
			fail = true
		print("%s  %s  vueltas en 100 s: %.2f · máx. desvío del centro %.1f m · pasos fuera del asfalto %d · vel final %.0f km/h" % ["OK  " if ok else "FALLA", id, laps, max_off, off, ph.vLong * 3.6])
	quit(1 if fail else 0)
