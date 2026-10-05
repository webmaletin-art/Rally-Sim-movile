extends Node3D
## Sala de exhibición 3D del menú: el auto de pie sobre una plataforma y el piloto y el copiloto parados a un costado, charlando,
## mirando el auto, con los brazos cruzados o analizando la pintura. Cada tanto cambian de pose (se mezclan suave) y al entrar
## al menú se elige un conjunto distinto. La cámara se mueve despacio alrededor.

const Car := preload("res://game/car/car.gd")
const FlatTrack := preload("res://game/physics/flat_track.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const RigPilot := preload("res://game/car/rig_pilot.gd")


var car: Car
var crew: Array = [] # {rig, node, h}
var cam: Camera3D
var sun: DirectionalLight3D
var t := 0.0
var cam_ang := 0.0
var rng := RandomNumberGenerator.new()
var view_shift := 0.5 # cuánto se corre la escena hacia la derecha (el menú ocupa la izquierda)
var car_len := 4.6
var clip: MeshInstance3D
var ready_ok := false

func _ready() -> void:
	rng.randomize()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.045, 0.06, 0.085)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.72)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.045, 0.06, 0.085)
	env.fog_density = 0.022
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 22.0
	add_child(sun)
	var rim_l := DirectionalLight3D.new() # luz de contorno desde atrás: los autos negros no se pierden en el fondo
	rim_l.rotation_degrees = Vector3(-25, 200, 0)
	rim_l.light_energy = 0.55
	rim_l.light_color = Color(0.85, 0.9, 1.0)
	add_child(rim_l)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 150, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.6, 0.72, 1.0)
	add_child(fill)
	# plataforma
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.11, 0.125, 0.15)
	fm.roughness = 0.55
	fm.metallic = 0.25
	var floor_m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 8.5
	cyl.bottom_radius = 8.5
	cyl.height = 0.1
	cyl.radial_segments = 48
	cyl.rings = 1
	cyl.material = fm
	floor_m.mesh = cyl
	floor_m.position.y = -0.05
	add_child(floor_m)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.48, 0.1)
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.55
	tm.outer_radius = 4.62
	tm.rings = 48
	tm.ring_segments = 4
	tm.material = rm
	ring.mesh = tm
	ring.scale.y = 0.05
	ring.position.y = 0.015
	add_child(ring)
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.3
	cam.far = 120.0
	add_child(cam)
	cam.make_current()
	ready_ok = true

## Pone el auto: id del catálogo, estado guardado (mejoras, pintura) y vehicles.json
func set_car(id: String, state: Dictionary, vehicles: Dictionary) -> void:
	if car != null:
		car.visual.queue_free()
		car = null
	var d: Dictionary = CarBuild.build_params(vehicles[id], state)
	var pp: Dictionary = state.get("paint", {"body": "#1a4fe0", "rim": "#ff6a08"})
	car = Car.new(FlatTrack.new(), VehicleParams.from_dict(d), false, false, Color(str(pp["body"])), Color(str(pp.get("rim", "#2a2d33"))), str(pp.get("finish", "gloss")), state.get("mods", {}))
	car.visual.set_livery(int(pp.get("livery", 0)), Color(str(pp["body"])), Color(str(pp.get("accent", "#ff6a08"))), str(pp.get("finish", "gloss")))
	if pp.has("tire"):
		car.visual.set_tire_color(Color(str(pp["tire"])))
	car.visual.set_parts(pp)
	car.place(0, 0, 0)
	for i in 160:
		car.step_and_record(1.0 / 120.0, float(i + 1) / 120.0) # deja que la suspensión se asiente
	car.snap.sample(2.0)
	add_child(car.visual)
	car.update_visual(0.0)
	car.visual.blob.visible = false
	var V: VehicleParams = car.phys.V
	# tamaño de la carrocería: para acomodar la cámara y a la gente
	car_len = maxf(4.2, V.wheelBase + 1.9)
	if crew.is_empty():
		_make_crew()

func _make_crew() -> void:
	for spec in [{"h": 1.78, "name": "piloto", "ring": 3.3}, {"h": 1.68, "name": "copiloto", "ring": 3.9}]:
		var node := Node3D.new()
		add_child(node)
		var rig := RigPilot.new(node, float(spec["h"]), false)
		crew.append({"rig": rig, "node": node, "h": float(spec["h"]), "name": spec["name"], "ring": float(spec["ring"]), "queue": [], "step": {}, "t": 0.0,
			"yaw": 0.0, "phi": 0.0, "pose": "idle", "pose_prev": {}, "blend": 1.0, "speed": 0.0, "tl": Vector3.ZERO, "face": null, "ang": 0.0})
	clip = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.30, 0.012)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.92, 0.9, 0.84)
	bm.material = cm
	clip.mesh = bm
	add_child(clip)
	# posiciones iniciales sobre el círculo, adelante a la izquierda del auto
	_place(0, 28.0)
	_place(1, 62.0)
	_new_scene()

func _ring(i: int, ang_deg: float) -> Vector3:
	var r: float = crew[i]["ring"]
	var a := deg_to_rad(ang_deg)
	return Vector3(sin(a) * r, 0.0, cos(a) * r + car_len * 0.12)

func _place(i: int, ang_deg: float) -> void:
	var c: Dictionary = crew[i]
	c["ang"] = ang_deg
	var node: Node3D = c["node"]
	node.position = _ring(i, ang_deg)
	var yaw := atan2(-node.position.x, -node.position.z + car_len * 0.12)
	node.rotation.y = yaw
	c["yaw"] = yaw

## camino por el círculo (por el lado corto) desde el ángulo actual hasta ang_deg: puntos cada ~18°
func _arc_path(i: int, to_deg: float) -> Array:
	var from_deg: float = crew[i]["ang"]
	var d := to_deg - from_deg
	var n := maxi(1, int(ceil(absf(d) / 18.0)))
	var pts: Array = []
	for k in range(1, n + 1):
		pts.append(from_deg + d * float(k) / float(n))
	return pts

## Partes del auto que se señalan o se miran (mundo, el auto está en el origen mirando a +z)
func _car_part() -> Vector3:
	var h := car_len * 0.5
	var parts := [Vector3(0.0, 0.55, h), Vector3(0.0, 0.95, h - 0.7), Vector3(1.0, 0.85, 0.4), Vector3(1.0, 0.45, h - 0.6), Vector3(0.0, 1.3, -0.2), Vector3(0.6, 0.9, h - 0.1)]
	return parts[rng.randi() % parts.size()]

# ───────────────────────── escenas (guion al azar de lo que hacen) ─────────────────────────
func _walk(i: int, to_deg: float) -> Dictionary:
	return {"t": "walk", "path": _arc_path(i, to_deg), "to": to_deg}

func _stand(pose: String, dur: float, face = null, tl = Vector3.ZERO) -> Dictionary:
	return {"t": "stand", "pose": pose, "dur": dur, "face": face, "tl": tl}

func _rf(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func _new_scene() -> void:
	var kind := rng.randi() % 4
	var qa: Array = []
	var qb: Array = []
	var part := _car_part()
	match kind:
		0: # recorrido: caminan alrededor mirando el auto y se detienen a pensar
			qa = [_walk(0, _rf(10, 30)), _stand("chin", _rf(3, 5), "car"), _walk(0, _rf(60, 85)), _stand("crossed", _rf(3, 5), "car"), _walk(0, _rf(35, 55)), _stand("paint", _rf(3, 4.5), "tl", part)]
			qb = [_walk(1, _rf(55, 75)), _stand("hip", _rf(3, 5), "car"), _walk(1, _rf(90, 108)), _stand("chin", _rf(3, 5), "car"), _walk(1, _rf(70, 85)), _stand("pocket", _rf(2.5, 4), "car")]
		1: # uno señala algo del auto, el otro viene y mira
			var ang := _rf(20, 50)
			qa = [_walk(0, ang), _stand("point", _rf(4, 5.5), "tl", part), _stand("talk", _rf(3, 5), 1), _stand("hip", _rf(2, 3.5), "car")]
			qb = [_stand("read", _rf(3.5, 5), "car"), _walk(1, ang + 24.0), _stand("chin", _rf(4, 6), "tl", part), _stand("crossed", _rf(2.5, 4), "car")]
		2: # charlan entre ellos, gesticulando
			var ang2 := _rf(30, 55)
			qa = [_walk(0, ang2), _stand("talk", _rf(6, 8), 1), _stand("point", _rf(3, 4), "tl", part), _stand("talk", _rf(3, 5), 1)]
			qb = [_walk(1, ang2 + 26.0), _stand("crossed", _rf(4, 6), 0), _stand("chin", _rf(3, 4), "tl", part), _stand("read", _rf(3, 4), 0)]
		_: # inspección: uno al frente tocando la pintura, el otro da la vuelta
			qa = [_walk(0, _rf(2, 14)), _stand("paint", _rf(5, 7), "tl", Vector3(0.3, 0.9, car_len * 0.5 - 0.3)), _walk(0, _rf(40, 55)), _stand("hip", _rf(3, 5), "car")]
			qb = [_walk(1, _rf(95, 112)), _stand("hip", _rf(3, 5), "car"), _walk(1, _rf(60, 75)), _stand("chin", _rf(4, 6), "tl", part), _stand("crossed", _rf(2.5, 4), "car")]
	crew[0]["queue"] = qa
	crew[1]["queue"] = qb
	crew[0]["step"] = {}
	crew[1]["step"] = {}

# ───────────────────────── poses (marco de la persona: +z al frente, +x a su izquierda) ─────────────────────────
func _base_pose(k: float, hips_y := 0.93) -> Dictionary:
	return {"hips": Vector3(0, hips_y * k, 0), "head": Vector3(0, (hips_y + 0.56) * k, 0.0), "roll": 0.0, "look": 0.0, "look_y": -0.05, "lean0": -0.02, "lean1": 0.02,
		"hip_tilt": -0.02, "foot_up": -0.35, "grip": 0.7, "hands": [], "feet": [{"side": "Left", "pos": Vector3(0.11, 0.085, 0.02)}, {"side": "Right", "pos": Vector3(-0.11, 0.085, 0.02)}]}

## tl: destino local (en el marco de la persona) para señalar/tocar
func _pose_def(name: String, k: float, ph: float, tl := Vector3.ZERO) -> Dictionary:
	var o := _base_pose(k)
	var hands: Array = []
	var sway := sin(ph * 1.3) * 0.012
	match name:
		"crossed":
			hands = [_hand("Left", Vector3(-0.17, 1.20 * k, 0.22), Vector3(-0.9, 0.3, 0.6), Vector3(0, 0.6, 0.8), Vector3(0.35, -1, 0.25)),
				_hand("Right", Vector3(0.17, 1.15 * k, 0.26), Vector3(0.9, 0.3, 0.6), Vector3(0, 0.5, 0.85), Vector3(0.3, -1, 0.3))]
			o["hips"] = (o["hips"] as Vector3) + Vector3(sway, 0, 0)
		"hip":
			hands = [_hand("Right", Vector3(-0.30 * k, 0.97 * k, -0.01), Vector3(-0.4, -0.5, 0.75), Vector3(0, 0.3, 0.9), Vector3(1.4, -0.1, -0.7)),
				_hand("Left", Vector3(0.24, 0.80 * k, 0.04), Vector3(0, -1, 0.15), Vector3(1, 0, 0), Vector3(0.6, -1, -0.1))]
			o["hips"] = (o["hips"] as Vector3) + Vector3(0.03, 0, 0)
			o["roll"] = 0.05
			o["feet"] = [{"side": "Left", "pos": Vector3(0.20, 0.085, 0.0)}, {"side": "Right", "pos": Vector3(-0.08, 0.085, 0.06)}]
		"chin":
			hands = [_hand("Right", Vector3(-0.07, 1.36 * k, 0.24), Vector3(0.0, 0.85, 0.5), Vector3(-1, 0, 0.2), Vector3(0.9, -1, 0.0)),
				_hand("Left", Vector3(-0.05, 1.12 * k, 0.26), Vector3(-0.9, 0.1, 0.4), Vector3(0, 0.6, 0.8), Vector3(0.3, -1, 0.4))]
			o["look_y"] = -0.12 + 0.05 * sin(ph * 0.7)
			o["roll"] = -0.06
			o["lean0"] = 0.02
			o["lean1"] = 0.10
		"paint":
			var w := tl if tl != Vector3.ZERO else Vector3(-0.22, 1.0 * k, 0.62)
			w = w.limit_length(0.72)
			if w.y < 0.6 * k:
				w.y = 0.6 * k
			w += Vector3(0.0, 0.025 * sin(ph * 0.8), 0.03 * sin(ph * 0.8)) # la mano recorre la chapa
			hands = [_hand("Right", w, (w - Vector3(0, 1.3 * k, 0)).normalized(), Vector3(0, 1, 0.1), Vector3(0.7, -1, 0.2)),
				_hand("Left", Vector3(0.26, 0.92 * k, 0.03), Vector3(0, -1, 0.2), Vector3(1, 0, 0), Vector3(0.6, -1, -0.1))]
			o["head"] = Vector3(0, 1.45 * k, 0.15)
			o["hips"] = (o["hips"] as Vector3) + Vector3(0, -0.01, 0.04)
			o["look_y"] = -0.45
			o["lean0"] = 0.12
			o["lean1"] = 0.42
			o["feet"] = [{"side": "Left", "pos": Vector3(0.12, 0.085, -0.10)}, {"side": "Right", "pos": Vector3(-0.12, 0.085, 0.14)}]
		"talk":
			var g := 0.5 + 0.5 * sin(ph * 2.3)
			var g2 := 0.5 + 0.5 * sin(ph * 1.7 + 1.2)
			hands = [_hand("Right", Vector3(-0.34, 1.12 * k + 0.16 * g, 0.36 + 0.06 * g), Vector3(0.2, 0.6, 0.9), Vector3(0, 0.3, 0.9), Vector3(1.0, -0.9, -0.2)),
				_hand("Left", Vector3(0.30, 1.02 * k + 0.10 * g2, 0.30 + 0.05 * g2), Vector3(0.1, 0.4, 0.9), Vector3(0, 0.4, 0.9), Vector3(0.8, -0.8, -0.2))]
			o["roll"] = 0.03 * sin(ph * 1.1)
			o["look"] = 0.1 * sin(ph * 0.7)
		"read":
			hands = [_hand("Left", Vector3(0.12, 1.12 * k, 0.26), Vector3(-0.6, 0.4, 0.7), Vector3(0, 0.7, 0.7), Vector3(0.5, -1, 0.2)),
				_hand("Right", Vector3(-0.12, 1.06 * k, 0.26), Vector3(0.6, 0.4, 0.7), Vector3(0, 0.6, 0.8), Vector3(0.5, -1, 0.2))]
			o["look_y"] = -0.45 + 0.1 * sin(ph * 0.5)
		"pocket":
			hands = [_hand("Left", Vector3(0.24, 0.88 * k, 0.02), Vector3(0, -1, 0.3), Vector3(1, 0, 0), Vector3(1.0, -0.5, -0.4)),
				_hand("Right", Vector3(-0.24, 0.88 * k, 0.02), Vector3(0, -1, 0.3), Vector3(-1, 0, 0), Vector3(1.0, -0.5, -0.4))]
			o["roll"] = 0.04 * sin(ph * 0.6)
		"point":
			var w2 := tl.limit_length(0.66) if tl != Vector3.ZERO else Vector3(-0.30, 1.30 * k, 0.58)
			if w2.y < 1.0 * k:
				w2.y = 1.0 * k + (w2.y - 1.0 * k) * 0.3
			hands = [_hand("Right", w2 + Vector3(0, 0.02 * sin(ph * 1.4), 0), (tl.normalized() if tl != Vector3.ZERO else Vector3(-0.3, 0.1, 1.0)), Vector3(0, 1, 0.0), Vector3(0.9, -0.5, -0.1)),
				_hand("Left", Vector3(0.12, 1.00 * k, 0.30), Vector3(0, 0.2, 1), Vector3(0, 1, 0.3), Vector3(0.4, -1, 0.3))]
			o["lean1"] = 0.14
			o["roll"] = -0.04
		_: # idle: brazos sueltos
			hands = [_hand("Left", Vector3(0.24, 0.84 * k, 0.04), Vector3(0, -1, 0.1), Vector3(1, 0, 0), Vector3(0.6, -1, -0.1)),
				_hand("Right", Vector3(-0.24, 0.84 * k, 0.04), Vector3(0, -1, 0.1), Vector3(-1, 0, 0), Vector3(0.6, -1, -0.1))]
	o["hands"] = hands
	return o

## caminando: pasos con apoyo y vuelo de cada pie, cadera que sube y baja, brazos que se balancean al revés de las piernas
func _walk_pose(k: float, phi: float, spd: float) -> Dictionary:
	var o := _base_pose(k, 0.905)
	var A := 0.30 * clampf(spd / 1.1, 0.4, 1.2)
	var feet: Array = []
	for si in 2:
		var ph := fposmod(phi + 0.5 * float(si), 1.0)
		var z: float
		var y := 0.085
		if ph < 0.6:
			z = A * (1.0 - 2.0 * ph / 0.6)
		else:
			var t := (ph - 0.6) / 0.4
			var e := t * t * (3.0 - 2.0 * t)
			z = -A + 2.0 * A * e
			y += 0.11 * sin(PI * t)
		feet.append({"side": "Left" if si == 0 else "Right", "pos": Vector3(0.10 if si == 0 else -0.10, y, z), "pole": Vector3(0.0, 1.0, 0.45)})
	o["feet"] = feet
	var swing := cos(TAU * phi) * 0.13 * clampf(spd / 1.1, 0.4, 1.2)
	o["hips"] = Vector3(0.012 * sin(TAU * phi), 0.905 * k - 0.014 * absf(sin(TAU * phi)), 0.0)
	o["head"] = Vector3(0.0, 1.46 * k, 0.03)
	o["lean1"] = 0.08
	o["roll"] = 0.02 * sin(TAU * phi)
	o["hands"] = [_hand("Left", Vector3(0.22, 0.86 * k, 0.04 + swing), Vector3(0, -1, 0.1), Vector3(1, 0, 0), Vector3(0.6, -1, -0.1)),
		_hand("Right", Vector3(-0.22, 0.86 * k, 0.04 - swing), Vector3(0, -1, 0.1), Vector3(-1, 0, 0), Vector3(0.6, -1, -0.1))]
	return o

func _hand(side: String, wrist: Vector3, fdir: Vector3, back: Vector3, pole: Vector3) -> Dictionary:
	return {"side": side, "wrist": wrist, "fdir": fdir.normalized(), "back": back.normalized(), "pole": pole}

func _lerp_pose(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var o := {}
	for key in ["hips", "head"]:
		o[key] = (a[key] as Vector3).lerp(b[key], w)
	for key in ["roll", "look", "look_y", "lean0", "lean1", "hip_tilt", "foot_up", "grip"]:
		o[key] = lerpf(float(a[key]), float(b[key]), w)
	var hands: Array = []
	for side in ["Left", "Right"]:
		var ha := {}
		var hb := {}
		for h in a["hands"]:
			if h["side"] == side:
				ha = h
		for h in b["hands"]:
			if h["side"] == side:
				hb = h
		if ha.is_empty() and hb.is_empty():
			continue
		if ha.is_empty():
			ha = hb
		if hb.is_empty():
			hb = ha
		hands.append({"side": side, "wrist": (ha["wrist"] as Vector3).lerp(hb["wrist"], w), "fdir": (ha["fdir"] as Vector3).lerp(hb["fdir"], w).normalized(),
			"back": (ha["back"] as Vector3).lerp(hb["back"], w).normalized(), "pole": (ha["pole"] as Vector3).lerp(hb["pole"], w)})
	o["hands"] = hands
	var feet: Array = []
	for i in 2:
		var fa: Dictionary = a["feet"][i]
		var fb: Dictionary = b["feet"][i]
		var pa: Vector3 = fa.get("pole", Vector3(0, 1, 0.3))
		var pb: Vector3 = fb.get("pole", Vector3(0, 1, 0.3))
		feet.append({"side": fa["side"], "pos": (fa["pos"] as Vector3).lerp(fb["pos"], w), "pole": pa.lerp(pb, w)})
	o["feet"] = feet
	return o

# ───────────────────────── cuadro a cuadro ─────────────────────────
func _target_point(c: Dictionary, step: Dictionary) -> Variant:
	var f = step.get("face")
	if f is String:
		if f == "car":
			return Vector3(0.0, 0.9, car_len * 0.12)
		if f == "tl":
			return step["tl"]
	elif f is int:
		return (crew[int(f)]["node"] as Node3D).position + Vector3(0, 1.5, 0)
	return null

func _advance(i: int, dt: float) -> void:
	var c: Dictionary = crew[i]
	var node: Node3D = c["node"]
	var step: Dictionary = c["step"]
	if step.is_empty():
		var q: Array = c["queue"]
		if q.is_empty():
			return
		step = q.pop_front()
		c["step"] = step
		c["t"] = 0.0
		if step["t"] == "stand":
			c["pose_prev"] = c.get("last_pose", {})
			c["blend"] = 0.0
			c["pose"] = step["pose"]
		else:
			c["pose_prev"] = c.get("last_pose", {})
			c["blend"] = 0.0
	c["t"] = float(c["t"]) + dt
	var desired_yaw: float = c["yaw"]
	if step["t"] == "walk":
		var path: Array = step["path"]
		if path.is_empty():
			c["step"] = {}
			c["speed"] = 0.0
			c["ang"] = float(step["to"])
			return
		var tgt := _ring(i, float(path[0]))
		var d := Vector3(tgt.x - node.position.x, 0.0, tgt.z - node.position.z)
		var dist := d.length()
		var spd := 1.15 if i == 0 else 1.05
		c["speed"] = lerpf(float(c["speed"]), spd, clampf(dt * 3.0, 0.0, 1.0))
		if dist < 0.12:
			c["ang"] = float(path[0])
			path.pop_front()
			return
		desired_yaw = atan2(d.x, d.z)
		var yaw_err := wrapf(desired_yaw - float(c["yaw"]), -PI, PI)
		# primero gira (la velocidad cae si hay que girar mucho), después camina
		var turn_k := clampf(1.0 - absf(yaw_err) / 1.2, 0.0, 1.0)
		var move := float(c["speed"]) * turn_k * dt
		node.position += d / dist * minf(move, dist)
		c["phi"] = float(c["phi"]) + float(c["speed"]) * turn_k * dt / 1.4
	else:
		c["speed"] = lerpf(float(c["speed"]), 0.0, clampf(dt * 5.0, 0.0, 1.0))
		var tp = _target_point(c, step)
		if tp != null:
			var dv: Vector3 = (tp as Vector3) - node.position
			desired_yaw = atan2(dv.x, dv.z)
		if float(c["t"]) >= float(step["dur"]):
			c["step"] = {}
			var other: Dictionary = crew[1 - i]
			c["ang"] = rad_to_deg(atan2(node.position.x, node.position.z - car_len * 0.12))
	var rate := 5.5
	c["yaw"] = float(c["yaw"]) + wrapf(desired_yaw - float(c["yaw"]), -PI, PI) * clampf(dt * rate, 0.0, 1.0)
	node.rotation.y = c["yaw"]

func _pose_for(i: int) -> Dictionary:
	var c: Dictionary = crew[i]
	var k: float = float(c["h"]) / 1.76
	var step: Dictionary = c["step"]
	var ph := t + float(i) * 1.7
	var target: Dictionary
	var node: Node3D = c["node"]
	if not step.is_empty() and step["t"] == "stand":
		var tl_local := Vector3.ZERO
		if step.get("tl", Vector3.ZERO) != Vector3.ZERO and (step["pose"] == "point" or step["pose"] == "paint"):
			tl_local = node.global_transform.affine_inverse() * (step["tl"] as Vector3)
		target = _pose_def(str(step["pose"]), k, ph, tl_local)
	else:
		target = _walk_pose(k, float(c["phi"]), float(c["speed"])) if float(c["speed"]) > 0.15 else _pose_def("idle", k, ph)
		if float(c["speed"]) <= 0.15 and float(c["speed"]) > 0.0:
			target = _lerp_pose(_pose_def("idle", k, ph), _walk_pose(k, float(c["phi"]), float(c["speed"])), clampf(float(c["speed"]) / 0.15, 0.0, 1.0))
	# mirada: al auto o al lugar de interés, relativa al cuerpo
	var tp = _target_point(c, step) if not step.is_empty() else Vector3(0.0, 0.9, car_len * 0.12)
	if tp == null:
		tp = Vector3(0.0, 0.9, car_len * 0.12)
	var loc: Vector3 = node.global_transform.affine_inverse() * (tp as Vector3)
	var yaw_look := clampf(atan2(loc.x, maxf(loc.z, 0.3)), -0.9, 0.9)
	if step.is_empty() or step["t"] == "walk":
		target["look"] = clampf(yaw_look * 0.7, -0.6, 0.6)
		target["look_y"] = -0.08
	elif step["pose"] != "read" and step["pose"] != "paint":
		target["look"] = float(target["look"]) + clampf(yaw_look * 0.5, -0.5, 0.5)
	var blend: float = float(c["blend"])
	var res := target
	if blend < 1.0 and not (c["pose_prev"] as Dictionary).is_empty():
		var e := smoothstep(0.0, 1.0, blend)
		res = _lerp_pose(c["pose_prev"], target, e)
	c["last_pose"] = res
	return res

var _cur_pos := [Vector3.ZERO, Vector3.ZERO]

func _process(dt: float) -> void:
	if not ready_ok:
		return
	t += dt
	# cámara: va y viene despacio alrededor del frente-izquierdo del auto
	cam_ang = 0.62 + 0.30 * sin(t * 0.12)
	var dist := car_len * 1.5 + 1.1
	var target := Vector3(1.35, 0.85, car_len * 0.18)
	var cp := target + Vector3(sin(cam_ang) * dist, 0.65 + 0.12 * sin(t * 0.17), cos(cam_ang) * dist)
	cam.position = cp
	cam.look_at(target)
	cam.h_offset = -view_shift * dist * 0.5
	if car != null:
		car.visual.blob.visible = false
	if crew.is_empty():
		return
	for i in 2:
		_advance(i, dt)
		var c: Dictionary = crew[i]
		c["blend"] = minf(1.0, float(c["blend"]) + dt / 0.55)
	if crew[0]["step"].is_empty() and crew[0]["queue"].is_empty() and crew[1]["step"].is_empty() and crew[1]["queue"].is_empty():
		_new_scene()
	var show_clip := false
	for i in 2:
		var c: Dictionary = crew[i]
		(c["rig"] as RigPilot).pose(_pose_for(i))
		var st: Dictionary = c["step"]
		if i == 1 and not st.is_empty() and st["t"] == "stand" and st["pose"] == "read":
			show_clip = true
	clip.visible = show_clip
	if show_clip:
		var cn: Node3D = crew[1]["node"]
		var k2: float = float(crew[1]["h"]) / 1.76
		clip.global_transform = Transform3D(cn.global_transform.basis * Basis.from_euler(Vector3(-0.9, 0, 0)), cn.global_transform * Vector3(0, 1.10 * k2, 0.30))
