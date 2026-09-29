## Compara la física de Godot con la de la versión HTML, paso a paso.
## Uso:  godot --headless --path godot --script res://tests/physics_test.gd
## (los archivos de referencia se generan con:  node tools/godot/js_reference.mjs)
extends SceneTree

const NAMES := ["px", "py", "pz", "yaw", "pitch", "roll", "vLong", "vLat", "rpm", "gear", "steer", "w0", "w1", "w2", "w3", "aLong"]

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/vehicles.json"))
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/expected.json"))
	var scen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/scenario.json"))
	var fail := false
	var t_total := 0
	var steps_total := 0
	for id in vehicles.keys():
		var d: Dictionary = vehicles[id]
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var ph := VehiclePhysics.new(FlatTrack.new(), VehicleParams.from_dict(d))
		ph.yawRate = float(scen.get("init_yaw_rate", 0.0))
		var exp: Array = expected[id]
		var n := 0
		var idx := 0
		var worst := 0.0
		var worst_name := ""
		var worst_at := 0
		var first_at := -1
		var first_name := ""
		var t0 := Time.get_ticks_usec()
		for seg in scen["segments"]:
			var steps := int(round(float(seg[0]) * 120.0))
			for i in steps:
				ph.step(1.0 / 120.0, float(seg[1]), float(seg[2]), float(seg[3]), int(seg[4]) != 0)
				n += 1
				if n % int(scen["every"]) == 0:
					var got := [ph.px, ph.py, ph.pz, ph.yaw, ph.pitch, ph.roll, ph.vLong, ph.vLat, ph.rpm, ph.gear, ph.steerAngle, ph.wheels[0].omega, ph.wheels[1].omega, ph.wheels[2].omega, ph.wheels[3].omega, ph.aLong]
					var e: Array = exp[idx]
					for j in got.size():
						var err := absf(float(got[j]) - float(e[j])) / maxf(1.0, absf(float(e[j])))
						if err > 1e-9 and first_at < 0:
							first_at = idx
							first_name = NAMES[j]
						if err > worst:
							worst = err
							worst_name = NAMES[j]
							worst_at = idx
					idx += 1
		t_total += Time.get_ticks_usec() - t0
		steps_total += n
		var ok := worst < 1e-4
		if not ok:
			fail = true
		print("%s  %s  peor diferencia relativa %s (%s, muestra %d) · primera >1e-9: %s en muestra %d" % ["OK  " if ok else "FALLA", id, String.num_scientific(worst), worst_name, worst_at, first_name, first_at])
	print("Godot: %d pasos por auto, %.0f ms por auto" % [steps_total / vehicles.size(), t_total / 1000.0 / vehicles.size()])
	quit(1 if fail else 0)
