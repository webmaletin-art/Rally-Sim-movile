## Prueba de la picada: la recta de salida es recta y plana, el tramo mide ~402 m (un cuarto de milla) y los dos extremos quedan sobre la recta.
## Uso: godot --headless --path godot --script res://tests/drag_test.gd
extends SceneTree

const RouteTrack := preload("res://game/track/route_track.gd")
const Drag := preload("res://game/data/drag.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const FlatTrack := preload("res://game/physics/flat_track.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	var m: Dictionary = maps["picada"]
	var t := RouteTrack.new(str(m["route"]), str(m["mode"]), false, float(m.get("hills", 1.0)))
	var seg: Array = t.seg_between_x(float(m["strip"][0]), float(m["strip"][1]))
	var a := int(round(float(seg[0]) * float(t.n)))
	var b := int(round(float(seg[1]) * float(t.n)))
	var d: float = t.cum[b] - t.cum[a]
	check(absf(d - 402.3) < 6.0, "el tramo mide %.1f m (cuarto de milla)" % d)
	var zmax := 0.0
	var ymin := 1e9
	var ymax := -1e9
	for i in range(a - 20, b + 40):
		zmax = maxf(zmax, absf(t.samples[i].z))
		ymin = minf(ymin, t.samples[i].y)
		ymax = maxf(ymax, t.samples[i].y)
	check(zmax < 0.5, "la recta no se desvía a los costados (%.2f m)" % zmax)
	check(ymax - ymin < 0.2, "la recta es plana (%.2f m de desnivel)" % (ymax - ymin))
	check(float(seg[0]) < float(seg[1]), "el tramo va de menor a mayor")
	check(t.length - d > 1500.0, "queda lugar de sobra para frenar después de la meta (%.0f m)" % (t.length - d))
	# cuarto de milla con caja manual: cambiar en la ventana verde gana a cambiar temprano y a pegarse al limitador
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	for id in ["gt", "muscle", "hatch"]:
		var ets := {}
		for ratio in [0.70, 0.98, 1.10]:
			ets[ratio] = _quarter(id, vehicles, ratio)
		print("     %s: temprano %.2f s · perfecto %.2f s · tarde %.2f s" % [id, ets[0.70], ets[0.98], ets[1.10]])
		check(ets[0.98] > 5.0 and ets[0.98] < 16.0, "%s hace el cuarto de milla en un tiempo razonable (%.2f s)" % [id, ets[0.98]])
		check(ets[0.98] < ets[0.70] and ets[0.98] < ets[1.10], "%s: el cambio perfecto gana al temprano y al tarde" % id)
	check(Drag.quality(5000.0, 6500.0) == Drag.Q.EARLY and Drag.quality(6400.0, 6500.0) == Drag.Q.PERFECT and Drag.quality(6900.0, 6500.0) == Drag.Q.LATE, "la calidad del cambio se clasifica bien")
	quit(1 if fail else 0)

## Tiempo (s) en cubrir 402 m subiendo de marcha a ratio × vueltas de cambio, con el mismo efecto de la picada sobre la duración del cambio
func _quarter(id: String, vehicles: Dictionary, ratio: float) -> float:
	var d: Dictionary = CarBuild.build_params(vehicles[id], Profile.new_car_state(id))
	var ph := VehiclePhysics.new(FlatTrack.new(), VehicleParams.from_dict(d))
	ph.reset(0.35, 0.0, 0.0)
	ph.manual = true
	var prev_gear := 0
	var rpm_before := 0.0
	var dist := 0.0
	ph.reqShift = 1 # neutro → primera
	for i in 120 * 40:
		var want := 0
		if ph.gear >= 1 and ph.gear < ph.V.gears.size() and ph.shiftT <= 0.0 and ph.rpm >= ratio * ph.V.shiftUpRpm:
			want = 1
		rpm_before = ph.rpm
		ph.step(1.0 / 120.0, 1.0, 0.0, 0.0, false, false, want)
		if ph.gear > prev_gear and prev_gear >= 1:
			ph.shiftT *= Drag.shift_scale(Drag.quality(rpm_before, ph.V.shiftUpRpm))
		prev_gear = ph.gear
		dist += ph.vLong / 120.0
		if dist >= 402.3:
			return float(i) / 120.0
	return 99.0
