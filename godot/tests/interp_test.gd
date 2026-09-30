## Suavidad del auto en pantalla: con cuadros de duración irregular (como en un celular) el avance por cuadro tiene que
## ser proporcional al tiempo del cuadro. Compara "último estado" (antes) con el historial interpolado (ahora).
extends SceneTree

const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const FlatTrack := preload("res://game/physics/flat_track.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")

const PATTERNS := [
	[0.0166, 0.0167, 0.0333, 0.0166, 0.025, 0.0167, 0.0333, 0.0166, 0.0167, 0.041],
	[0.0345, 0.0322, 0.0338, 0.0351, 0.0319, 0.0333, 0.0341, 0.0326], # ~30 FPS con temblor (justo en 4 pasos de física)
	[0.0169, 0.0164, 0.0171, 0.0163, 0.0168, 0.0166]] # ~60 FPS con temblor (justo en 2 pasos)

func _init() -> void:
	var ok := true
	for pt in PATTERNS.size():
		ok = _run(pt) and ok
	quit(0 if ok else 1)

func _run(pattern: int) -> bool:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var d: Dictionary = vehicles["t1plus"]
	d["camberF"] = -1.0
	d["camberR"] = -0.5
	d["toeF"] = 0.0
	d["toeR"] = 0.1
	d["pressF"] = 30.0
	d["pressR"] = 30.0
	var ph := VehiclePhysics.new(FlatTrack.new(), VehicleParams.from_dict(d))
	var snap := CarSnapshot.new()
	snap.reset_to(0.0, ph)
	var h := 1.0 / 120.0
	var acc := 0.0
	var sim_t := 0.0
	var smooth_dt := 0.016
	var dts: Array = PATTERNS[pattern]
	var ratios_new: Array = []
	var ratios_old: Array = []
	var last_new := 0.0
	var last_old := 0.0
	var real_t := 0.0
	var f := 0
	while real_t < 12.0:
		var dt: float = dts[f % dts.size()]
		f += 1
		real_t += dt
		smooth_dt = lerpf(smooth_dt, dt, 0.02)
		acc = minf(acc + dt, 0.05)
		var n := int(acc / h)
		acc -= n * h
		var t0 := sim_t
		sim_t += n * h
		for k in n:
			ph.step(h, 1.0, 0.0, 0.0, false)
			snap.push(t0 + (k + 1) * h, ph)
		var render_t := sim_t + acc - (smooth_dt * 1.3 + h)
		snap.sample(render_t)
		var new_pos := snap.pz
		var old_pos := ph.pz
		if real_t > 6.0 and ph.vLong > 5.0:
			ratios_new.append((new_pos - last_new) / (ph.vLong * dt))
			ratios_old.append((old_pos - last_old) / (ph.vLong * dt))
		last_new = new_pos
		last_old = old_pos
	print("patrón %d · antes (último estado): desvío del avance por cuadro %.3f · ahora (interpolado): %.3f" % [pattern, _sd(ratios_old), _sd(ratios_new)])
	return _sd(ratios_new) < _sd(ratios_old) * 0.6

func _sd(a: Array) -> float:
	var m := 0.0
	for x in a:
		m += x
	m /= a.size()
	var v := 0.0
	for x in a:
		v += (x - m) * (x - m)
	return sqrt(v / a.size())
