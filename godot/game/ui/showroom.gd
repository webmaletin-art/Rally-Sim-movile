extends Node3D
## Sala de exhibición 3D del menú: el auto de pie sobre una plataforma y el piloto y el copiloto parados a un costado, charlando,
## mirando el auto, con los brazos cruzados o analizando la pintura. Cada tanto cambian de pose (se mezclan suave) y al entrar
## al menú se elige un conjunto distinto. La cámara se mueve despacio alrededor.

const Car := preload("res://game/car/car.gd")
const FlatTrack := preload("res://game/physics/flat_track.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const RigPilot := preload("res://game/car/rig_pilot.gd")

const POSE_TIME := 11.0 # segundos que dura cada pose
const BLEND := 1.4

var car: Car
var crew: Array = [] # {rig, node, h}
var cam: Camera3D
var sun: DirectionalLight3D
var t := 0.0
var cam_ang := 0.0
var sets: Array = []
var cur_set := 0
var next_set := -1
var blend_t := 0.0
var pose_t := 0.0
var rng := RandomNumberGenerator.new()
var view_shift := 0.22 # cuánto se corre la escena hacia la derecha (el menú ocupa la izquierda)
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
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.045, 0.06, 0.085)
	env.fog_density = 0.022
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 22.0
	add_child(sun)
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
	_build_sets()
	cur_set = rng.randi() % sets.size()
	ready_ok = true

## Pone el auto: id del catálogo, estado guardado (mejoras, pintura) y vehicles.json
func set_car(id: String, state: Dictionary, vehicles: Dictionary) -> void:
	if car != null:
		car.visual.queue_free()
		car = null
	var d: Dictionary = CarBuild.build_params(vehicles[id], state)
	var pp: Dictionary = state.get("paint", {"body": "#1a4fe0", "rim": "#ff6a08"})
	car = Car.new(FlatTrack.new(), VehicleParams.from_dict(d), false, false, Color(str(pp["body"])), Color(str(pp.get("rim", "#2a2d33"))), str(pp.get("finish", "gloss")))
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
	_build_sets()
	if crew.is_empty():
		_make_crew()

func _make_crew() -> void:
	for spec in [{"h": 1.78, "name": "piloto"}, {"h": 1.68, "name": "copiloto"}]:
		var node := Node3D.new()
		add_child(node)
		var rig := RigPilot.new(node, float(spec["h"]), false)
		crew.append({"rig": rig, "node": node, "h": float(spec["h"]), "name": spec["name"]})
	clip = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.30, 0.012)
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.92, 0.9, 0.84)
	bm.material = cm
	clip.mesh = bm
	add_child(clip)

# ───────────────────────── poses ─────────────────────────
## Cada conjunto: dos personas con posición (mundo), hacia dónde miran, y la pose de cada una
func _build_sets() -> void:
	var fr := car_len * 0.5
	sets = [
		# 0 · charlan entre ellos (gesticulan) al costado del frente
		{"p": [Vector3(2.7, 0, fr + 0.2), Vector3(3.9, 0, fr + 1.1)], "face": ["c", "p"], "pose": ["talk", "read"], "clip": 1},
		# 1 · el piloto analiza la pintura de la trompa, la copiloto con la mano en la cintura mirando el auto
		{"p": [Vector3(2.0, 0, fr + 1.5), Vector3(3.6, 0, fr - 0.5)], "face": [Vector3(0.6, 0.6, fr - 0.2), Vector3(0.4, 0.8, fr - 1.0)], "pose": ["paint", "hip"], "clip": -1},
		# 2 · brazos cruzados, mirando el auto
		{"p": [Vector3(2.9, 0, fr - 0.6), Vector3(3.9, 0, fr + 0.6)], "face": [Vector3(0.4, 0.9, fr - 0.6), Vector3(0.4, 0.9, fr - 0.6)], "pose": ["crossed", "chin"], "clip": -1},
		# 3 · se miran, él con las manos en los bolsillos y ella apunta algo del auto
		{"p": [Vector3(3.0, 0, fr + 0.6), Vector3(4.0, 0, fr - 0.3)], "face": ["c", "p"], "pose": ["pocket", "point"], "clip": -1},
	]

func _face_yaw(i: int, s: Dictionary) -> float:
	var pos: Vector3 = (s["p"] as Array)[i]
	var f = (s["face"] as Array)[i]
	var tgt: Vector3
	if f is String:
		tgt = (s["p"] as Array)[1 if f == "c" else 0]
	else:
		tgt = f
	return atan2(tgt.x - pos.x, tgt.z - pos.z)

## Pose (en el marco de la persona: +z al frente, +x a su izquierda) → Dictionary para RigPilot.pose
func _pose_def(name: String, k: float, ph: float) -> Dictionary:
	var hips := Vector3(0, 0.93 * k, 0)
	var head := Vector3(0, 1.49 * k, 0.0)
	var feet := [{"side": "Left", "pos": Vector3(0.11, 0.085, 0.02)}, {"side": "Right", "pos": Vector3(-0.11, 0.085, 0.02)}]
	var o := {"hips": hips, "head": head, "roll": 0.0, "look": 0.0, "look_y": -0.05, "lean0": -0.02, "lean1": 0.02, "hip_tilt": -0.02, "foot_up": 0.0, "grip": 0.7}
	var hands: Array = []
	var sway := sin(ph * 1.3) * 0.012
	match name:
		"crossed":
			hands = [_hand("Left", Vector3(-0.17, 1.20 * k, 0.22), Vector3(-0.9, 0.3, 0.6), Vector3(0, 0.6, 0.8), Vector3(0.35, -1, 0.25)),
				_hand("Right", Vector3(0.17, 1.15 * k, 0.26), Vector3(0.9, 0.3, 0.6), Vector3(0, 0.5, 0.85), Vector3(0.3, -1, 0.3))]
			o["look"] = 0.12 * sin(ph * 0.4)
			o["hips"] = hips + Vector3(sway, 0, 0)
		"hip":
			hands = [_hand("Right", Vector3(-0.30 * k, 0.97 * k, -0.01), Vector3(-0.4, -0.5, 0.75), Vector3(0, 0.3, 0.9), Vector3(1.4, -0.1, -0.7)),
				_hand("Left", Vector3(0.24, 0.80 * k, 0.04), Vector3(0, -1, 0.15), Vector3(1, 0, 0), Vector3(0.6, -1, -0.1))]
			o["hips"] = hips + Vector3(0.03, 0, 0)
			o["roll"] = 0.05
			o["feet"] = [{"side": "Left", "pos": Vector3(0.20, 0.085, 0.0)}, {"side": "Right", "pos": Vector3(-0.08, 0.085, 0.06)}]
		"chin":
			hands = [_hand("Right", Vector3(-0.07, 1.36 * k, 0.24), Vector3(0.0, 0.85, 0.5), Vector3(-1, 0, 0.2), Vector3(0.9, -1, 0.0)),
				_hand("Left", Vector3(-0.05, 1.12 * k, 0.26), Vector3(-0.9, 0.1, 0.4), Vector3(0, 0.6, 0.8), Vector3(0.3, -1, 0.4))]
			o["look_y"] = -0.12
			o["roll"] = -0.06
			o["lean0"] = 0.02
			o["lean1"] = 0.10
		"paint":
			# inclinado hacia adelante, una mano recorre la carrocería
			hands = [_hand("Right", Vector3(-0.22, 1.02 * k + 0.03 * sin(ph * 0.8), 0.62 + 0.04 * sin(ph * 0.8)), Vector3(-0.2, -0.4, 1), Vector3(0, 1, 0.1), Vector3(0.7, -1, 0.2)),
				_hand("Left", Vector3(0.26, 0.92 * k, 0.03), Vector3(0, -1, 0.2), Vector3(1, 0, 0), Vector3(0.6, -1, -0.1))]
			o["head"] = Vector3(0, 1.45 * k, 0.15)
			o["hips"] = hips + Vector3(0, -0.01, 0.04)
			o["look_y"] = -0.45
			o["lean0"] = 0.12
			o["lean1"] = 0.42
			o["feet"] = [{"side": "Left", "pos": Vector3(0.12, 0.085, -0.10)}, {"side": "Right", "pos": Vector3(-0.12, 0.085, 0.14)}]
		"talk":
			var g := 0.5 + 0.5 * sin(ph * 2.3)
			hands = [_hand("Right", Vector3(-0.34, 1.12 * k + 0.16 * g, 0.36 + 0.06 * g), Vector3(0.2, 0.6, 0.9), Vector3(0, 0.3, 0.9), Vector3(1.0, -0.9, -0.2)),
				_hand("Left", Vector3(0.22, 0.88 * k, 0.05), Vector3(0, -1, 0.2), Vector3(1, 0, 0), Vector3(0.6, -1, -0.1))]
			o["roll"] = 0.03 * sin(ph * 1.1)
			o["look"] = 0.1 * sin(ph * 0.7)
		"read":
			hands = [_hand("Left", Vector3(0.12, 1.12 * k, 0.26), Vector3(-0.6, 0.4, 0.7), Vector3(0, 0.7, 0.7), Vector3(0.5, -1, 0.2)),
				_hand("Right", Vector3(-0.12, 1.06 * k, 0.26), Vector3(0.6, 0.4, 0.7), Vector3(0, 0.6, 0.8), Vector3(0.5, -1, 0.2))]
			o["look_y"] = -0.05 + 0.1 * sin(ph * 0.5)
			o["look"] = -0.1 + 0.05 * sin(ph * 0.3)
		"pocket":
			hands = [_hand("Left", Vector3(0.24, 0.88 * k, 0.02), Vector3(0, -1, 0.3), Vector3(1, 0, 0), Vector3(1.0, -0.5, -0.4)),
				_hand("Right", Vector3(-0.24, 0.88 * k, 0.02), Vector3(0, -1, 0.3), Vector3(-1, 0, 0), Vector3(1.0, -0.5, -0.4))]
			o["roll"] = 0.04 * sin(ph * 0.6)
		"point":
			var g2 := 0.5 + 0.5 * sin(ph * 0.9)
			hands = [_hand("Right", Vector3(-0.30, 1.30 * k, 0.58 + 0.04 * g2), Vector3(-0.3, 0.1, 1), Vector3(0, 1, 0.0), Vector3(0.9, -0.5, -0.1)),
				_hand("Left", Vector3(0.12, 1.00 * k, 0.30), Vector3(0, 0.2, 1), Vector3(0, 1, 0.3), Vector3(0.4, -1, 0.3))]
			o["look"] = -0.15
			o["roll"] = -0.04
	o["hands"] = hands
	if not o.has("feet"):
		o["feet"] = feet
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
		feet.append({"side": fa["side"], "pos": (fa["pos"] as Vector3).lerp(fb["pos"], w)})
	o["feet"] = feet
	return o

var _cur_pos := [Vector3.ZERO, Vector3.ZERO]
var _cur_yaw := [0.0, 0.0]

func _process(dt: float) -> void:
	if not ready_ok:
		return
	t += dt
	# cámara: va y viene despacio alrededor del frente-izquierdo del auto
	cam_ang = 0.62 + 0.30 * sin(t * 0.12)
	var dist := car_len * 1.62 + 1.0
	var target := Vector3(1.55, 0.95, car_len * 0.2)
	var cp := target + Vector3(sin(cam_ang) * dist, 0.65 + 0.12 * sin(t * 0.17), cos(cam_ang) * dist)
	cam.position = cp
	cam.look_at(target)
	cam.h_offset = -view_shift * dist * 0.5
	if car != null:
		car.visual.blob.visible = false
	if crew.is_empty():
		return
	pose_t += dt
	if next_set < 0 and pose_t > POSE_TIME:
		next_set = (cur_set + 1 + rng.randi() % (sets.size() - 1)) % sets.size()
		blend_t = 0.0
	var w := 0.0
	if next_set >= 0:
		blend_t += dt
		w = smoothstep(0.0, 1.0, blend_t / BLEND)
		if blend_t >= BLEND:
			cur_set = next_set
			next_set = -1
			pose_t = 0.0
			w = 0.0
	var sa: Dictionary = sets[cur_set]
	var sb: Dictionary = sets[next_set] if next_set >= 0 else sa
	for i in 2:
		var c: Dictionary = crew[i]
		var k: float = float(c["h"]) / 1.76
		var ph := t + float(i) * 1.7
		var pa := _pose_def(str((sa["pose"] as Array)[i]), k, ph)
		var pb := _pose_def(str((sb["pose"] as Array)[i]), k, ph)
		var pos_a: Vector3 = (sa["p"] as Array)[i]
		var pos_b: Vector3 = (sb["p"] as Array)[i]
		var pos := pos_a.lerp(pos_b, w)
		var ya := _face_yaw(i, sa)
		var yb := _face_yaw(i, sb)
		var yaw := ya + wrapf(yb - ya, -PI, PI) * w
		var node: Node3D = c["node"]
		node.position = pos
		node.rotation.y = yaw
		(c["rig"] as RigPilot).pose(_lerp_pose(pa, pb, w) if next_set >= 0 else pa)
	# la hoja de notas (solo cuando el conjunto la trae): en las manos de la copiloto
	var cn: Node3D = crew[1]["node"]
	var want_clip := int(sa["clip"]) >= 0 and next_set < 0
	clip.visible = want_clip
	if want_clip:
		var k2: float = float(crew[1]["h"]) / 1.76
		clip.global_transform = Transform3D(cn.global_transform.basis * Basis.from_euler(Vector3(-0.9, 0, 0)), cn.global_transform * Vector3(0, 1.10 * k2, 0.30))
