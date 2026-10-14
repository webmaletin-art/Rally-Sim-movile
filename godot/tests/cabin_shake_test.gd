## Cámara de adentro que «tiembla» (reporte del dueño, 14/10/2026): mide cuánto salta la cámara de la cabina de un cuadro al siguiente con la física a 120 Hz
## y la pantalla a 30–37 cuadros desparejos (como en el teléfono), manejando la IA por tierra. Salto = segunda diferencia de la posición (mm).
## Uso: godot --headless --path godot --script res://tests/cabin_shake_test.gd
extends SceneTree

const RouteTrack := preload("res://game/track/route_track.gd")
const AIDriver := preload("res://game/ai/ai_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CrewMotion := preload("res://game/car/crew_motion.gd")
const Cockpit := preload("res://game/car/cockpit.gd")

var fail := false
func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var track = RouteTrack.new("forest", "dirt")
	var ph := VehiclePhysics.new(track.make_view(), VehicleParams.from_dict(vehicles["hatch2"]))
	var sp: Array = track.start_pose(0)
	ph.reset(sp[0], sp[1], sp[2])
	var drv := AIDriver.new(track.make_view(), ph, {"skill": 0.95})
	var mo := CrewMotion.new(32.0, 7.0, 82.0, 4.4, 1.85)
	var h := 1.0 / 120.0
	var t := 0.0
	var next_frame := 0.5
	var frames: Array = [] # posición de la cámara (relativa al auto) en cada cuadro
	var fj: Array = [] # sólo la vibración
	var fc: Array = [] # sólo el movimiento de la cabeza (fuerzas G)
	var fi := 0
	var last_t := 0.0
	while t < 60.0:
		var c: Vector3 = drv.update(ph, h)
		ph.step(h, c.x, c.y, c.z, false, drv.nitro)
		t += h
		if t >= next_frame:
			var dt := t - last_t
			last_t = t
			mo.step_forces(dt, ph)
			var rough := 1.0
			var jv: Vector3 = Cockpit.cam_jitter(t, ph, rough)
			frames.append(jv + mo.cam_s)
			fj.append(jv)
			fc.append(mo.cam_s)
			fi += 1
			next_frame += 0.030 if fi % 3 != 0 else 0.037 # cuadros desparejos
	var r := _jump(frames)
	var rms: float = r[0]
	var worst: float = r[1] / 1000.0
	print("     vibración sola %.2f mm · cabeza (fuerzas G) sola %.2f mm (peor %.1f)" % [_jump(fj)[0], _jump(fc)[0], _jump(fc)[1]])
	print("     %d cuadros · salto medio %.2f mm · peor %.1f mm · %.0f km/h al final" % [frames.size(), rms, worst * 1000.0, absf(ph.vLong) * 3.6])
	_check(rms < 1.5, "la cámara de adentro no tiembla: salto medio entre cuadros %.2f mm (< 1,5 mm)" % rms)
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)

## salto entre cuadros: [media cuadrática, peor] de la segunda diferencia (mm)
func _jump(fr: Array) -> Array:
	var sum := 0.0
	var worst := 0.0
	for i in range(2, fr.size()):
		var d2: Vector3 = fr[i] - 2.0 * fr[i - 1] + fr[i - 2]
		sum += d2.length_squared()
		worst = maxf(worst, d2.length())
	return [sqrt(sum / float(fr.size() - 2)) * 1000.0, worst * 1000.0]
