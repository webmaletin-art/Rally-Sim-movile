## Prueba de todos los autos del catálogo: aceleración, frenada y viraje sobre el plano. Sin comparación contra la versión HTML:
## comprueba que cada auto tenga números razonables (que no se trabe, no se vaya de cola solo, frene, doble).
## Uso: godot --headless --path godot --script res://tests/cars_test.gd
extends SceneTree

const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const FlatTrack := preload("res://game/physics/flat_track.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

func _fresh(id: String, vehicles: Dictionary) -> VehiclePhysics:
	var st := Profile.new_car_state(id)
	var d: Dictionary = CarBuild.build_params(vehicles[id], st)
	var ph := VehiclePhysics.new(FlatTrack.new(), VehicleParams.from_dict(d))
	return ph

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var fail := false
	print("%-8s %6s %6s %7s %7s %6s  %s" % ["auto", "0-100", "100-0m", "tope", "lateral", "PI", "notas"])
	for id in vehicles.keys():
		var notes: Array = []
		# aceleración recta: 0 → 100 km/h y velocidad a los 45 s
		var ph := _fresh(id, vehicles)
		ph.reset(0.35, 0.0, 0.0)
		var t100 := -1.0
		var vmax := 0.0
		var ok := true
		for i in 120 * 45:
			ph.step(1.0 / 120.0, 1.0, 0.0, 0.0, false)
			if t100 < 0.0 and ph.vLong * 3.6 >= 100.0:
				t100 = float(i) / 120.0
			vmax = maxf(vmax, ph.vLong * 3.6)
			if is_nan(ph.px) or is_nan(ph.vLong) or absf(ph.px) > 60.0:
				ok = false
				notes.append("se fue de costado/NaN")
				break
		# frenada desde 100 km/h
		var ph2 := _fresh(id, vehicles)
		ph2.reset(0.35, 0.0, 0.0)
		for i in 120 * 60:
			ph2.step(1.0 / 120.0, 1.0, 0.0, 0.0, false)
			if ph2.vLong * 3.6 >= 100.0:
				break
		var z0 := ph2.pz
		for i in 120 * 20:
			ph2.step(1.0 / 120.0, 0.0, 1.0, 0.0, false)
			if ph2.vLong < 0.5:
				break
		var brake_d := ph2.pz - z0
		# viraje: 60 km/h con el volante a fondo → aceleración lateral sostenida
		var ph3 := _fresh(id, vehicles)
		ph3.reset(0.35, 0.0, 0.0)
		for i in 120 * 60:
			var thr := 1.0 if ph3.vLong * 3.6 < 80.0 else 0.35
			ph3.step(1.0 / 120.0, thr, 0.0, 0.0, false)
			if ph3.vLong * 3.6 >= 80.0:
				break
		var lat := 0.0
		for i in 120 * 6:
			ph3.step(1.0 / 120.0, 0.3, 0.0, 0.5, false)
			if i > 120 * 3:
				lat = maxf(lat, absf(ph3.vLong * ph3.yawRate))
		var pi_n := int(CarBuild.perf_of(CarBuild.build_params(vehicles[id], Profile.new_car_state(id)))["pi"])
		if t100 < 0.0 or t100 > 14.0:
			notes.append("0-100 raro")
		if brake_d > 80.0 or brake_d < 20.0:
			notes.append("frenada rara")
		if lat < 5.0 or lat > 16.0:
			notes.append("lateral raro")
		if vmax < 130.0:
			notes.append("tope bajo")
		if not ok or notes.size() > 0:
			fail = fail or not ok
		print("%-8s %6.1f %6.0f %7.0f %6.2fg %6d  %s" % [id, t100, brake_d, vmax, lat / 9.81, pi_n, ", ".join(notes)])
	quit(1 if fail else 0)
