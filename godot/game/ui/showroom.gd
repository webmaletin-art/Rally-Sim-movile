extends Node3D
## Sala de exhibición 3D del menú: el auto de pie sobre una plataforma y el piloto y el copiloto parados a un costado, charlando,
## mirando el auto, con los brazos cruzados o analizando la pintura. Cada tanto cambian de pose (se mezclan suave) y al entrar
## al menú se elige un conjunto distinto. La cámara se mueve despacio alrededor.

const Car := preload("res://game/car/car.gd")
const FlatTrack := preload("res://game/physics/flat_track.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const RigPilot := preload("res://game/car/rig_pilot.gd")
const MixamoClips := preload("res://game/car/mixamo_clips.gd")
const ShowroomEnv := preload("res://game/ui/showroom_env.gd")

## Qué clips de Mixamo se usan para cada pose del guion del menú (si el archivo de clips no está, quedan las poses procedurales)
const CLIPS := {
	"idle": ["Standing_Idle", "Breathing_Idle", "Idle_2", "weight_shift", "Neck_Stretching", "Arm_Stretching", "Looking_Behind", "Happy_Idle"],
	"chin": ["Thinking", "Thoughtful_Head_Nod", "Looking_Down", "Looking_3", "Counting_2", "thoughtful_head_shake", "Looking"],
	"crossed": ["Bored", "weight_shift", "Looking_Around", "Happy_Idle_2", "being_cocky", "relieved_sigh", "Shrugging"],
	"hip": ["Male_Standing_Pose_11", "Male_Standing_Pose_2", "Male_Standing_Pose_4", "Male_Standing_Pose_5", "Male_Standing_Pose_7", "Happy_Idle", "Standing_Idle"],
	"pocket": ["Idle_2", "Looking_Around", "Breathing_Idle", "Looking", "acknowledging", "head_nod_yes", "look_away_gesture"],
	"point": ["Pointing_Forward", "Pointing_2", "Pointing_Gesture_2", "Reaching_Out", "Pointing"],
	"paint": ["Reaching_Out", "Pointing_2"], # (nada agachado ni sentado: sin silla no se sienta nadie)
	"lean": ["Leaning", "Leaning_2", "One_Shoulder_Lean"], # recostarse: sólo contra el auto (ver _lean_steps)
	"talk": ["Talking_7", "Talking_4", "Talking_6", "Talking_3", "Talking_5", "Arm_Gesture", "Hands_Forward_Gesture", "Agreeing_2", "happy_hand_gesture", "dismissing_gesture", "Telling_A_Secret", "Laughing", "Standing_Greeting", "Shaking_Hands_1"],
	"read": ["Texting_While_Standing", "Texting", "Talking_On_A_Cell_Phone"],
}
## Caminatas en el lugar (se elige una al azar en cada tramo): [clip, velocidad natural en m/s]. El tramo se camina a esa velocidad (entre 0.8 y 1.4) para que los pies no patinen
const WALKS := [["Standard_Walk_inplace", 1.50], ["unarmed_walk_forward_inplace", 0.98], ["walking_inplace", 1.60], ["Walking_7_inplace", 1.04], ["Walking_While_Texting_inplace", 0.83]]
## Dónde queda la espalda de cada clip de recostarse respecto del personaje (z local, en metros): para apoyarla justo en la chapa del auto
const LEAN_BACK := {"Leaning": -0.04, "Leaning_2": -0.16, "One_Shoulder_Lean": -0.21}
const CIRC_C := Vector2(1.205, -0.07) # centro del recorrido de Walk_In_Circle (cadera, en metros del Y Bot): el clip da una vuelta ovalada de 17 s y termina donde empezó
const CIRC_XZ := Vector2(1.5, 1.2) # cuánto se agranda ese óvalo para que rodee el auto


var car: Car
var crew: Array = [] # {rig, node, h}
var cam: Camera3D
var sun: DirectionalLight3D
var t := 0.0
var cam_ang := 0.0
var rng := RandomNumberGenerator.new()
var shown_id := "" # auto que está en la sala (para no rearmarlo si ya es ese)
var view_shift := 0.5 # cuánto se corre la escena hacia la derecha (el menú ocupa la izquierda)
var dist_scale := 1.0 # 1 = distancia de siempre; más que 1 aleja la cámara automática (con el marco del garaje el auto tiene menos lugar)
var view_shift_y := 0.0 # corrimiento vertical (fracción del alto; negativo = la escena sube): deja el auto en lo que no tapan la barra de arriba y el carrusel
var car_len := 4.6
var clip: MeshInstance3D
var ready_ok := false
# cámara libre: en TODAS las pantallas del menú se gira con un dedo, se acerca/aleja con pellizco (o rueda), se corre con dos dedos (o botón derecho) y con doble toque vuelve a la automática.
# En el taller, pintura y llantas queda libre todo el tiempo (forced_free); en las demás, si se deja de tocar unos segundos la cámara vuelve sola, con un movimiento suave
var free := false
var forced_free := false
var free_w := 0.0 # 0 = cámara automática · 1 = cámara libre (se mezclan para que no haya saltos)
var _last_input := -100.0
var _auto_cp := Vector3.ZERO
var _auto_target := Vector3.ZERO
var _shown_cp := Vector3.ZERO
var _shown_target := Vector3.ZERO
var _last_center := Vector2.ZERO
var _has_center := false
const IDLE_RETURN := 14.0
var f_yaw := 0.6
var f_pitch := 0.12
var f_dist := 6.0
var f_target := Vector3(0.0, 0.75, 0.0)
var _touches := {}
var _pinch_d := 0.0

func _ready() -> void:
	rng.randomize()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.024, 0.034)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.68)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.024, 0.034)
	env.fog_density = 0.014
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
	fm.albedo_color = Color(0.035, 0.04, 0.052)
	fm.roughness = 0.75
	fm.metallic = 0.0
	fm.metallic_specular = 0.12 # poco brillo: de costado el piso no se vuelve un espejo blanco
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
	if not OS.get_cmdline_user_args().has("--noroom"): # (prueba de rendimiento: sin la sala)
		ShowroomEnv.build(self)
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
	shown_id = id
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
		var mx: Variant = null
		if rig.ok and MixamoClips.available():
			mx = MixamoClips.Player.new(rig.skel, rig.B)
		crew.append({"rig": rig, "mx": mx, "node": node, "h": float(spec["h"]), "name": spec["name"], "ring": float(spec["ring"]), "queue": [], "step": {}, "t": 0.0,
			"mx_pose": "", "mx_step_id": -1, "yaw": 0.0, "phi": 0.0, "pose": "idle", "pose_prev": {}, "blend": 1.0, "speed": 0.0, "tl": Vector3.ZERO, "face": null, "ang": 0.0})
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

## Caminar hasta puntos sueltos del mundo (no del círculo)
func _walk_pts(pts: Array) -> Dictionary:
	return {"t": "walk", "path": pts, "to": 0.0, "pts": true}

func _ang_of(p: Vector3) -> float:
	return rad_to_deg(atan2(p.x, p.z - car_len * 0.12))

## Dónde queda parado el personaje al empezar la vuelta al auto (el óvalo gira media vuelta para empezar del lado de la cámara, rodeando el auto)
func _circle_node(hk: float) -> Vector3:
	var off := Basis(Vector3.UP, PI) * Vector3(CIRC_C.x * CIRC_XZ.x * hk, 0.0, CIRC_C.y * CIRC_XZ.y * hk)
	return Vector3.ZERO - off

func _can_circle() -> bool:
	return crew[0]["mx"] != null and crew[1]["mx"] != null and MixamoClips.has_clip("Walk_In_Circle")

## Recostarse: se acerca al costado del auto, se da vuelta, retrocede hasta tocarlo con la espalda y recién ahí se apoya (nunca recostado en el aire)
func _lean_steps(i: int, dur: float) -> Array:
	var opts: Array = []
	for n in LEAN_BACK:
		if MixamoClips.has_clip(str(n)):
			opts.append(str(n))
	if opts.is_empty() or crew[i]["mx"] == null:
		return [_stand("crossed", dur, "car")]
	var nm: String = opts[rng.randi() % opts.size()]
	var k: float = float(crew[i]["h"]) / 1.76
	var hw := (car.phys.V.trackF * 0.5 + 0.12) if car != null else 1.0
	var contact := Vector3(hw - 0.05 - float(LEAN_BACK[nm]) * k, 0.0, _rf(-0.6, 0.9)) # siempre del lado de la cámara (+x): los recorridos del resto de la escena quedan de ese lado
	var out_pt := contact + Vector3(6.0, 0.9, 0.0)
	return [
		_walk_pts([contact + Vector3(0.8, 0.0, 0.0)]),
		{"t": "stand", "pose": "idle", "dur": 8.0, "face": "pt", "pt": out_pt, "tl": Vector3.ZERO, "lean_to": contact},
		{"t": "stand", "pose": "lean", "dur": dur, "face": "pt", "pt": out_pt, "tl": Vector3.ZERO, "clip": nm}]

func _stand(pose: String, dur: float, face = null, tl = Vector3.ZERO) -> Dictionary:
	return {"t": "stand", "pose": pose, "dur": dur, "face": face, "tl": tl}

func _rf(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func _new_scene() -> void:
	var kind := rng.randi() % 5
	if kind == 4 and not _can_circle():
		kind = 0
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
			qb = [_stand("read", _rf(3.5, 5), "car"), _walk(1, ang + 24.0), _stand("chin", _rf(4, 6), "tl", part)] + _lean_steps(1, _rf(5, 7))
		2: # charlan entre ellos, gesticulando
			var ang2 := _rf(30, 55)
			qa = [_walk(0, ang2), _stand("talk", _rf(6, 8), 1), _stand("point", _rf(3, 4), "tl", part), _stand("talk", _rf(3, 5), 1)]
			qb = [_walk(1, ang2 + 26.0), _stand("crossed", _rf(4, 6), 0), _stand("chin", _rf(3, 4), "tl", part), _stand("read", _rf(3, 4), 0)]
		4: # uno da la vuelta entera al auto mirándolo (Walk_In_Circle) y el otro lo mira desde su lugar
			var pf := rng.randi() % 2
			var hk: float = (crew[pf]["mx"] as MixamoClips.Player).hips_k
			var qp := [_walk_pts([_circle_node(hk)]), {"t": "circle"}, _stand("chin", _rf(3, 4.5), "car"), _stand("hip", _rf(2.5, 4), "car")]
			var qo := [_walk(1 - pf, _rf(60, 85)), _stand("crossed", _rf(6, 8), pf), _stand("chin", _rf(6, 8), pf), _stand("talk", _rf(4, 6), pf), _stand("hip", _rf(3, 4), "car")]
			qa = qp if pf == 0 else qo
			qb = qo if pf == 0 else qp
		_: # inspección: uno al frente tocando la pintura, el otro da la vuelta
			qa = [_walk(0, _rf(2, 14)), _stand("paint", _rf(5, 7), "tl", Vector3(0.3, 0.9, car_len * 0.5 - 0.3)), _walk(0, _rf(40, 55)), _stand("hip", _rf(3, 5), "car")]
			qb = [_walk(1, _rf(95, 112)), _stand("hip", _rf(3, 5), "car"), _walk(1, _rf(60, 75)), _stand("chin", _rf(4, 6), "tl", part)] + _lean_steps(1, _rf(5, 7))
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
	var o := _base_pose(k, 0.915)
	var A := 0.21 * clampf(spd / 1.1, 0.4, 1.1) # paso más corto: con 0,30 las piernas se estiraban de más y se deformaba la cadera
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
	o["hips"] = Vector3(0.006 * sin(TAU * phi), 0.915 * k - 0.008 * absf(sin(TAU * phi)), 0.0)
	o["head"] = Vector3(0.0, 1.46 * k, 0.03)
	o["lean1"] = 0.08
	o["roll"] = 0.01 * sin(TAU * phi)
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
		if f == "pt":
			return step["pt"]
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
			c["ang"] = _ang_of(node.position) if step.has("pts") else float(step["to"])
			return
		var mp: Variant = c["mx"]
		if mp != null and not step.has("sid"):
			_setup_walk(c, step, path.size())
		var tgt: Vector3 = path[0] if path[0] is Vector3 else _ring(i, float(path[0]))
		var d := Vector3(tgt.x - node.position.x, 0.0, tgt.z - node.position.z)
		var dist := d.length()
		var spd := float(step.get("spd", 1.15 if i == 0 else 1.05))
		if bool(step.get("start", false)) and not bool(step.get("start_done", false)):
			# arranque con el clip de Mixamo: el avance de la cadera mueve al personaje hacia el primer punto
			var sp: MixamoClips.Player = mp
			desired_yaw = atan2(d.x, d.z)
			var r0 := sp.root_at(sp.t)
			var r1 := sp.root_at(sp.t + dt)
			node.position += Basis(Vector3.UP, float(c["yaw"])) * Vector3(r1.x - r0.x, 0.0, r1.y - r0.y)
			c["speed"] = 0.6
			step["rate"] = 1.0
			if sp.t + dt >= float(sp.cur["len"]) - 0.02:
				step["start_done"] = true
				sp.play(MixamoClips.clip(str(step["wclip"])), true)
				c["mx_pose"] = str(step["wclip"])
				while path.size() > 1 and node.position.distance_to(_pt(i, path[1])) < _pt(i, path[0]).distance_to(_pt(i, path[1])):
					path.pop_front() # el arranque ya pasó los primeros puntos
		else:
			c["speed"] = lerpf(float(c["speed"]), spd, clampf(dt * 3.0, 0.0, 1.0))
			if dist < 0.12:
				c["ang"] = _ang_of(tgt) if not (path[0] is float or path[0] is int) else float(path[0])
				path.pop_front()
				return
			desired_yaw = atan2(d.x, d.z)
			var yaw_err := wrapf(desired_yaw - float(c["yaw"]), -PI, PI)
			# primero gira (la velocidad cae si hay que girar mucho), después camina
			var turn_k := clampf(1.0 - absf(yaw_err) / 1.2, 0.0, 1.0)
			var move := float(c["speed"]) * turn_k * dt
			node.position += d / dist * minf(move, dist)
			c["phi"] = float(c["phi"]) + float(c["speed"]) * turn_k * dt / 1.4
			step["rate"] = (spd / float(step.get("nat", spd))) * lerpf(0.35, 1.0, turn_k)
	elif step["t"] == "circle":
		_circle(c, step)
		return
	else:
		c["speed"] = lerpf(float(c["speed"]), 0.0, clampf(dt * 5.0, 0.0, 1.0))
		var tp = _target_point(c, step)
		if tp != null:
			var dv: Vector3 = (tp as Vector3) - node.position
			desired_yaw = atan2(dv.x, dv.z)
		var done_t := float(c["t"]) >= float(step["dur"])
		if step.has("lean_to"): # camina hacia atrás hasta tocar el auto con la espalda (ya de espaldas a él)
			var dv2: Vector3 = (step["lean_to"] as Vector3) - node.position
			dv2.y = 0.0
			var yerr := absf(wrapf(desired_yaw - float(c["yaw"]), -PI, PI))
			if yerr < 0.25 and dv2.length() > 0.02:
				node.position += dv2.normalized() * minf(0.5 * dt, dv2.length())
			done_t = done_t or (yerr < 0.25 and dv2.length() <= 0.02)
		if done_t:
			c["step"] = {}
			var other: Dictionary = crew[1 - i]
			c["ang"] = rad_to_deg(atan2(node.position.x, node.position.z - car_len * 0.12))
	var rate := 5.5
	c["yaw"] = float(c["yaw"]) + wrapf(desired_yaw - float(c["yaw"]), -PI, PI) * clampf(dt * rate, 0.0, 1.0)
	node.rotation.y = c["yaw"]

func _pt(i: int, p: Variant) -> Vector3:
	return p if p is Vector3 else _ring(i, float(p))

## Al empezar un tramo a pie: elige al azar una caminata de Mixamo (y a veces arranca con Start_Walking); si no hay clips, queda la caminata procedural
func _setup_walk(c: Dictionary, step: Dictionary, n_pts: int) -> void:
	_step_seq += 1
	step["sid"] = _step_seq
	var pl: MixamoClips.Player = c["mx"]
	var opts: Array = []
	for w in WALKS:
		if MixamoClips.has_clip(str(w[0])) and (str(c["name"]) == "copiloto" or not str(w[0]).contains("Texting")):
			opts.append(w)
	if opts.is_empty():
		return
	var pick: Array = opts[rng.randi() % opts.size()]
	step["wclip"] = str(pick[0])
	step["nat"] = float(pick[1])
	step["spd"] = clampf(float(pick[1]), 0.8, 1.4)
	step["rate"] = 1.0
	step["mx"] = true
	c["mx_step_id"] = int(step["sid"])
	if n_pts >= 3 and MixamoClips.has_clip("Start_Walking") and rng.randf() < 0.4:
		step["start"] = true
		pl.play(MixamoClips.clip("Start_Walking"), false, true)
		c["mx_pose"] = "Start_Walking"
	else:
		pl.play(MixamoClips.clip(str(pick[0])), true)
		c["mx_pose"] = str(pick[0])

## Vuelta entera al auto con Walk_In_Circle: el personaje queda fijo y el recorrido de la cadera (agrandado) lo lleva alrededor
func _circle(c: Dictionary, step: Dictionary) -> void:
	var mp: MixamoClips.Player = c["mx"]
	var node: Node3D = c["node"]
	if not step.has("sid"):
		_step_seq += 1
		step["sid"] = _step_seq
		node.position = _circle_node(mp.hips_k)
		c["yaw"] = PI
		node.rotation.y = PI
		mp.play(MixamoClips.clip("Walk_In_Circle"), false, false, CIRC_XZ)
		c["mx_pose"] = "Walk_In_Circle"
		c["mx_step_id"] = int(step["sid"])
		step["mx"] = true
		step["rate"] = 1.0
	c["speed"] = 0.9
	if mp.t >= float(mp.cur["len"]) - 0.06:
		c["step"] = {}
		c["speed"] = 0.0
		c["ang"] = _ang_of(node.position)

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
		target = _pose_def("crossed" if str(step["pose"]) == "lean" else str(step["pose"]), k, ph, tl_local)
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
var _step_seq := 0

## Un clip de Mixamo para la pose del guion (distinto del que está sonando); "" si no hay
func _pick_clip(pose: String, avoid: String) -> String:
	var pool: Array = CLIPS.get(pose, CLIPS["idle"])
	var opts: Array = []
	for n in pool:
		if MixamoClips.has_clip(str(n)) and str(n) != avoid:
			opts.append(str(n))
	if opts.is_empty():
		return ""
	return str(opts[rng.randi() % opts.size()])

## Un cuadro del personaje: clips de Mixamo cuando está parado haciendo algo; pose procedural al caminar (y como respaldo si faltan los clips)
func _animate(i: int) -> void:
	var c: Dictionary = crew[i]
	var rig: RigPilot = c["rig"]
	var mx: Variant = c["mx"]
	var st: Dictionary = c["step"]
	if mx == null:
		rig.pose(_pose_for(i))
		return
	var pl: MixamoClips.Player = mx
	var dt := get_process_delta_time()
	if not st.is_empty() and bool(st.get("mx", false)): # caminando (o dando la vuelta) con un clip de Mixamo
		pl.step(dt * float(st.get("rate", 1.0)))
		pl.apply_clip()
		pl.post(dt)
		return
	var standing: bool = (not st.is_empty()) and str(st["t"]) == "stand"
	if standing:
		if not st.has("sid"):
			_step_seq += 1
			st["sid"] = _step_seq
		var pose := str(st["pose"])
		var need := int(c["mx_step_id"]) != int(st["sid"]) or (pl.ended() and not st.has("clip")) # los recostados se quedan en la última pose
		if need:
			var n: String = str(st["clip"]) if st.has("clip") else _pick_clip(pose, str((pl.cur as Dictionary).get("name", "")) if int(c["mx_step_id"]) == int(st["sid"]) else "")
			if n != "":
				pl.play(MixamoClips.clip(n))
				c["mx_step_id"] = int(st["sid"])
				c["mx_pose"] = n
			elif int(c["mx_step_id"]) != int(st["sid"]):
				standing = false
		if standing:
			pl.step(dt)
			pl.apply_clip()
	if not standing:
		if str(c["mx_pose"]) != "":
			pl.mark_transition()
			rig.skel.reset_bone_poses()
			c["mx_pose"] = ""
			c["mx_step_id"] = -1
			pl.cur = {}
		rig.pose(_pose_for(i))
	pl.post(dt)

func set_free(on: bool) -> void:
	forced_free = on
	if on == free:
		return
	_touches.clear()
	if on:
		_enter_free(true)
	else:
		free = false # al salir del taller la cámara vuelve a la automática (con el fundido de free_w)

## Pasa a la cámara libre. defaults: arranca desde la vista de siempre del taller; si no, desde donde está la cámara automática en este momento (no hay salto)
func _enter_free(defaults: bool) -> void:
	free = true
	_last_input = t
	if defaults:
		f_yaw = cam_ang
		f_pitch = 0.12
		f_dist = (car_len * 1.5 + 1.1) * dist_scale
		f_target = Vector3(0.0, 0.75, 0.0)
	else:
		var off := _shown_cp - _shown_target # donde está la cámara en este momento (automática o a medio volver): sin saltos
		f_dist = clampf(off.length(), 1.8, car_len * 4.2)
		f_yaw = atan2(off.x, off.z)
		f_pitch = clampf(asin(clampf(off.y / maxf(off.length(), 0.01), -1.0, 1.0)), -0.05, 1.45)
		f_target = _shown_target
		free_w = 1.0

func _touch_input() -> void:
	_last_input = t
	if not free:
		_enter_free(false)

func _orbit(rel: Vector2) -> void:
	f_yaw -= rel.x * 0.009
	f_pitch = clampf(f_pitch + rel.y * 0.006, -0.05, 1.45)

func _pan(rel: Vector2) -> void:
	var k := f_dist * 0.0016
	var b := cam.global_transform.basis
	f_target += (-b.x * rel.x + b.y * rel.y) * k
	f_target.x = clampf(f_target.x, -6.0, 6.0)
	f_target.y = clampf(f_target.y, 0.1, 3.0)
	f_target.z = clampf(f_target.z, -6.0, 6.0)

func _unhandled_input(ev: InputEvent) -> void:
	if not ready_ok:
		return
	if (ev is InputEventMouseMotion or ev is InputEventMouseButton) and ev.device == InputEvent.DEVICE_ID_EMULATION:
		return # el mouse que Godot inventa a partir de los toques: ya llegan como toques (si no, todo se movería doble)
	if ev is InputEventScreenTouch:
		var te := ev as InputEventScreenTouch
		if te.pressed:
			_touches[te.index] = te.position
			if te.double_tap and free and not forced_free:
				free = false # doble toque: vuelve a la cámara automática
				_touches.clear()
				return
			if te.double_tap and forced_free:
				_enter_free(true)
		else:
			_touches.erase(te.index)
		_pinch_d = 0.0
		_has_center = false
	elif ev is InputEventScreenDrag:
		var de := ev as InputEventScreenDrag
		_touch_input()
		_touches[de.index] = de.position
		if _touches.size() >= 2:
			var ks: Array = _touches.keys()
			var p0: Vector2 = _touches[ks[0]]
			var p1: Vector2 = _touches[ks[1]]
			var d := p0.distance_to(p1)
			if _pinch_d > 0.0:
				f_dist = clampf(f_dist * _pinch_d / maxf(d, 1.0), 1.8, car_len * 4.2)
			_pinch_d = d
			var ctr := (p0 + p1) * 0.5
			if _has_center:
				_pan(ctr - _last_center)
			_last_center = ctr
			_has_center = true
		else:
			_orbit(de.relative)
	elif ev is InputEventMouseMotion:
		var me := ev as InputEventMouseMotion
		if me.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			_touch_input()
			_orbit(me.relative)
		elif me.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE) != 0:
			_touch_input()
			_pan(me.relative)
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_touch_input()
			f_dist = clampf(f_dist * 0.92, 1.8, car_len * 4.2)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_touch_input()
			f_dist = clampf(f_dist * 1.08, 1.8, car_len * 4.2)
		elif mb.double_click and free and not forced_free:
			free = false

func _process(dt: float) -> void:
	if not ready_ok:
		return
	t += dt
	# cámara: va y viene despacio alrededor del frente-izquierdo del auto
	cam_ang = 0.62 + 0.30 * sin(t * 0.12)
	var dist := (car_len * 1.5 + 1.1) * dist_scale
	var target := Vector3(1.35, 0.85, car_len * 0.18)
	var cp := target + Vector3(sin(cam_ang) * dist, 0.65 + 0.12 * sin(t * 0.17), cos(cam_ang) * dist)
	_auto_cp = cp
	_auto_target = target
	if free and not forced_free and t - _last_input > IDLE_RETURN:
		free = false # un rato sin tocar: la cámara vuelve sola a la automática
	free_w = move_toward(free_w, 1.0 if free else 0.0, dt * 2.5)
	var hd := dist
	if free_w > 0.0:
		var fcp := f_target + Vector3(sin(f_yaw) * cos(f_pitch), sin(f_pitch), cos(f_yaw) * cos(f_pitch)) * f_dist
		var w := smoothstep(0.0, 1.0, free_w)
		cp = cp.lerp(fcp, w)
		target = target.lerp(f_target, w)
		hd = lerpf(dist, f_dist, w)
	cam.position = cp
	cam.look_at(target)
	_shown_cp = cp
	_shown_target = target
	cam.h_offset = -view_shift * hd * 0.5
	cam.v_offset = view_shift_y * hd * 0.69
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
		_animate(i)
		var st: Dictionary = c["step"]
		if i == 1 and not st.is_empty() and st["t"] == "stand" and st["pose"] == "read":
			show_clip = true
		elif i == 1 and not st.is_empty() and st["t"] == "walk" and str(c["mx_pose"]).begins_with("Walking_While_Texting"):
			show_clip = true
	clip.visible = show_clip
	if show_clip:
		var cn: Node3D = crew[1]["node"]
		var k2: float = float(crew[1]["h"]) / 1.76
		var rg: RigPilot = crew[1]["rig"]
		if str(crew[1]["mx_pose"]) != "" and rg.B.has("RightHand"):
			# con el clip de Mixamo (texteando) el celular va en la mano derecha
			(clip.mesh as BoxMesh).size = Vector3(0.07, 0.15, 0.01)
			var hand: Transform3D = rg.skel.global_transform * rg.skel.get_bone_global_pose(int(rg.B["RightHand"]))
			clip.global_transform = Transform3D(hand.basis.orthonormalized(), hand * Vector3(0.0, 0.07, 0.025))
		else:
			(clip.mesh as BoxMesh).size = Vector3(0.22, 0.30, 0.012)
			clip.global_transform = Transform3D(cn.global_transform.basis * Basis.from_euler(Vector3(-0.9, 0, 0)), cn.global_transform * Vector3(0, 1.10 * k2, 0.30))
