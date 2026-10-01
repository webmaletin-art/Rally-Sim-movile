## Prueba de la pista de drift: choques contra paredes/manzanas/isla, conos con física y puntaje de una sesión manejada por un guion.
## Uso: godot --headless --path godot --script res://tests/drift_test.gd
extends SceneTree

const DriftTrack := preload("res://game/track/drift_track.gd")
const DriftSession := preload("res://game/drift_session.gd")
const Car := preload("res://game/car/car.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const ConeField := preload("res://game/track/cone_field.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var tr := DriftTrack.new()
	# 1) obstáculos
	check(tr.push(0.0, 50.0, 1.0).z == 0.0, "el centro del playón está libre")
	var h := tr.push(0.0, -HALF() + 0.5, 1.0) # contra la pared del norte (fuera de la boca)
	check(h.z == 0.0, "la boca de la salida norte está libre")
	h = tr.push(60.0, -HALF() + 0.5, 1.0)
	check(h.z > 0.5 and h.y > 0.9, "la pared del norte empuja hacia el playón (normal +z): %s" % str(h))
	h = tr.push(-HALF() + 0.5, 10.0, 1.0)
	check(h.z > 0.5 and h.x > 0.9, "la pared del oeste empuja hacia adentro (normal +x): %s" % str(h))
	h = tr.push(0.0, tr.RB.y, 1.0)
	check(h.z > 5.0, "la isla de la rotonda está maciza")
	h = tr.push(10.0, tr.RB.y, 1.0)
	check(h.z == 0.0, "la calzada de la rotonda está libre")
	h = tr.push(60.0, -200.0, 1.0)
	check(h.z > 1.0, "una manzana de la ciudad choca")
	h = tr.push(0.0, -200.0, 1.0)
	check(h.z == 0.0, "la avenida está libre")
	# 2) un auto manejado: no atraviesa nada y suma puntos
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	for id in ["gt", "muscle", "hatch"]:
		var d: Dictionary = CarBuild.build_params(vehicles[id], Profile.new_car_state(id))
		var car := Car.new(tr, VehicleParams.from_dict(d), true, true, Color.RED, Color.WHITE)
		car.solid = true
		var sp := tr.start_pose(0)
		car.place(sp[0], sp[1], sp[2])
		var ses := DriftSession.new(tr, {"time": 40}, 1)
		ses.state = "run"
		var hits := 0
		var worst := 0.0
		for i in 120 * 40:
			var t := float(i) / 120.0
			# guion: acelerar recto, después trazar un círculo a 25 m del centro con ráfagas de freno de mano
			car.in_throttle = 1.0 if t < 4.0 else 0.75
			car.in_brake = 0.0
			var to_c := Vector2(-car.phys.px, -car.phys.pz)
			var r := to_c.length()
			var fwd := Vector2(sin(car.phys.yaw), cos(car.phys.yaw))
			var side := fwd.x * to_c.y - fwd.y * to_c.x # signo: de qué lado queda el centro
			car.in_steer = clampf(0.9 * (1.0 if side > 0.0 else -1.0), -1.0, 1.0) if t > 3.0 else 0.0
			car.in_handbrake = t > 5.0 and fmod(t, 3.0) < 0.35
			car.step_and_record(1.0 / 120.0, t)
			if car.wall_hit > 0.0:
				hits += 1
				worst = maxf(worst, car.wall_hit)
				ses.on_wall(car.wall_hit)
				car.wall_hit = 0.0
			if i % 2 == 0:
				ses.update(1.0 / 60.0, [car])
			if is_nan(car.phys.px) or absf(car.phys.px) > 400.0 or car.phys.pz > 140.0 or car.phys.pz < -470.0:
				check(false, "%s se fue del mapa (%.0f, %.0f)" % [id, car.phys.px, car.phys.pz])
				break
		var h2 := tr.push(car.phys.px, car.phys.pz, 0.9)
		check(h2.z < 0.15, "%s no quedó metido en un obstáculo (pen %.2f)" % [id, h2.z])
		print("     %s: total %d pts · pico x%d · mejor derrape %d · choques %d (peor %.1f m/s) · tope %.0f km/h" % [id, int(ses.total + ses.cur), ses.mult, int(ses.best_run), hits, worst, ses.max_kmh])
		check(ses.total + ses.cur > 100.0, "%s suma puntos de drift" % id)
	# 3) conos: un auto a 20 m/s pasa por encima de un cono y lo tira
	var cf := ConeField.new()
	cf.setup(PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]))
	var d2: Dictionary = CarBuild.build_params(vehicles["gt"], Profile.new_car_state("gt"))
	var car2 := Car.new(tr, VehicleParams.from_dict(d2), true, true, Color.RED, Color.WHITE)
	car2.place(0.0, 8.0, PI)
	car2.phys.vx = 0.0
	car2.phys.vz = -20.0
	for i in 60:
		car2.phys.vz = -20.0
		car2.phys.pz += -20.0 / 60.0
		car2.snap.px = car2.phys.px
		car2.snap.pz = car2.phys.pz
		car2.snap.vx = 0.0
		car2.snap.vz = -20.0
		car2.snap.yaw = PI
		cf.update(1.0 / 60.0, [car2])
	for i in 120:
		cf.update(1.0 / 60.0, [])
	check(cf.hits == 1, "el cono del camino se golpeó una sola vez (%d)" % cf.hits)
	check(cf.state[0] == 2 and cf.state[1] == 0, "el golpeado quedó tirado y el otro sigue parado (%d, %d)" % [cf.state[0], cf.state[1]])
	check(cf.pos[0].y < -3.0, "salió despedido hacia donde iba el auto (z = %.1f)" % cf.pos[0].y)
	quit(1 if fail else 0)

func HALF() -> float:
	return DriftTrack.HALF
