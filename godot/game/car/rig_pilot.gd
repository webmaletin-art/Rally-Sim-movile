extends RefCounted
## Piloto con esqueleto (GLB tipo Mixamo) sentado en la butaca: manos al volante / palanca / freno de mano y pies en los pedales
## por cinemática inversa, torso y cabeza que se mueven con las fuerzas G. Traducción de RigPilot (js/pilot.js).
## Todo se calcula en el espacio de la cabina ("frame"): +z adelante, +x izquierda, y arriba.

const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
const NEED := ["Hips", "Spine", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]

static var _lo_scene: PackedScene
static var _full_scene: PackedScene
static var _full_mat: Material

var ok := false
var root: Node3D # el piloto (escalado a su estatura)
var skel: Skeleton3D
var B := {} # nombre sin prefijo → índice de hueso
var s := 1.0
var meshes: Array = []
var _rest := {} # hueso → {lq: Quaternion, wq: Basis, p: Vector3}
var _ax := {} # hueso → {p: Vector3, s: Vector3}
var _side := {}
var _spine: Array = []
var _fing: Array = []
var head_hidden := false

## height: estatura en metros; lo: malla liviana (para verlo desde afuera)
func _init(parent: Node3D, height := 1.76, lo := true) -> void:
	if _full_scene == null:
		_full_scene = load("res://game/models/pilot.glb")
		_lo_scene = load("res://game/models/pilot_lo.glb")
		var full: Node = _full_scene.instantiate()
		for mi in _meshes(full):
			if mi.mesh.get_surface_count() > 0:
				_full_mat = mi.mesh.surface_get_material(0)
				break
		full.free()
	root = Node3D.new()
	parent.add_child(root)
	var scene: Node3D = (_lo_scene if lo else _full_scene).instantiate()
	root.add_child(scene)
	skel = _find_skeleton(scene)
	for mi in _meshes(scene):
		if lo:
			mi.set_surface_override_material(0, _full_mat)
		mi.extra_cull_margin = 3.0
		meshes.append(mi)
	if skel == null:
		return
	for i in skel.get_bone_count():
		var k := _norm(skel.get_bone_name(i))
		if not B.has(k):
			B[k] = i
	for k in NEED:
		if not B.has(k):
			push_warning("piloto: falta el hueso " + k)
			return
	# escala: la articulación de la cabeza ≈ 0,80·estatura por encima del tobillo
	var head_y := skel.get_bone_global_rest(B["Head"]).origin.y
	var foot_y := minf(skel.get_bone_global_rest(B["LeftFoot"]).origin.y, skel.get_bone_global_rest(B["RightFoot"]).origin.y)
	s = height * 0.80 / maxf(1e-6, head_y - foot_y)
	root.scale = Vector3.ONE * s
	# datos de reposo (espacio del personaje)
	for i in skel.get_bone_count():
		var gr := skel.get_bone_global_rest(i)
		_rest[i] = {"lq": skel.get_bone_rest(i).basis.get_rotation_quaternion(), "wq": gr.basis.orthonormalized(), "p": gr.origin}
	var up := Vector3.UP
	var fw := Vector3.BACK # +z
	_spine = []
	for k in ["Spine", "Spine1", "Spine2", "Neck"]:
		if B.has(k):
			_spine.append(B[k])
	for b in _spine:
		_def(b, -1, fw, up)
	_def(B["Hips"], -1, fw, up)
	_def(B["Head"], -1, fw, up)
	for pair in [["Left", 1.0], ["Right", -1.0]]:
		var S: String = pair[0]
		var sg: float = pair[1]
		var arm: int = B[S + "Arm"]
		var fore: int = B[S + "ForeArm"]
		var hand: int = B[S + "Hand"]
		var mid: int = B.get(S + "HandMiddle1", B.get(S + "HandIndex1", -1))
		var shb: int = B.get(S + "Shoulder", -1)
		if shb >= 0:
			_def(shb, arm, up)
		_def(arm, fore, fw)
		_def(fore, hand, up)
		_def(hand, mid, up, Vector3.ZERO if mid >= 0 else Vector3(sg, 0, 0))
		var ul: int = B[S + "UpLeg"]
		var lg: int = B[S + "Leg"]
		var ft: int = B[S + "Foot"]
		var toe: int = B.get(S + "ToeBase", -1)
		_def(ul, lg, fw)
		_def(lg, ft, fw)
		_def(ft, toe, up, Vector3.ZERO if toe >= 0 else Vector3(0, -0.5, 1).normalized())
		var rp: Vector3 = _rest[arm]["p"]
		var rf: Vector3 = _rest[fore]["p"]
		var rh: Vector3 = _rest[hand]["p"]
		var lu: Vector3 = _rest[ul]["p"]
		var ll: Vector3 = _rest[lg]["p"]
		var lf: Vector3 = _rest[ft]["p"]
		# dedos: eje de nudillos en reposo (T-pose: Z); se curvan hacia la palma
		var fing := []
		for F in FINGERS + ["Thumb"]:
			for n in [1, 2, 3]:
				var nm: String = S + "Hand" + str(F) + str(n)
				if B.has(nm):
					var bi: int = B[nm]
					var axv: Vector3 = (_rest[bi]["wq"] as Basis).inverse() * Vector3(0, 0, 1)
					fing.append({"b": bi, "ax": axv, "k": 0.35 if F == "Thumb" else 1.0, "sg": sg})
		_side[S] = {"sh": shb, "arm": arm, "fore": fore, "hand": hand, "ul": ul, "lg": lg, "ft": ft, "fing": fing, "sg": sg,
			"L1": rp.distance_to(rf) * s, "L2": rf.distance_to(rh) * s, "T1": lu.distance_to(ll) * s, "T2": ll.distance_to(lf) * s}
	ok = true

# ───────────────────────── utilidades ─────────────────────────
static func _norm(n: String) -> String:
	var r := RegEx.new()
	r.compile("^mixamorig\\d*[:_]?")
	var out := r.sub(n, "")
	var idx := maxi(out.rfind(":"), out.rfind("|"))
	return out.substr(idx + 1) if idx >= 0 else out

static func _meshes(n: Node) -> Array:
	var out := []
	var stack := [n]
	while stack.size() > 0:
		var c: Node = stack.pop_back()
		if c is MeshInstance3D:
			out.append(c)
		stack.append_array(c.get_children())
	return out

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null

## eje primario (hacia el hijo, o el dado en prim) y secundario (dado en el espacio del personaje) en coordenadas del hueso
func _def(b: int, child: int, sec: Vector3, prim := Vector3.ZERO) -> void:
	var r: Dictionary = _rest[b]
	var p: Vector3 = prim if prim != Vector3.ZERO else ((_rest[child]["p"] as Vector3) - (r["p"] as Vector3)).normalized()
	var iq: Basis = (r["wq"] as Basis).inverse()
	_ax[b] = {"p": (iq * p).normalized(), "s": (iq * sec).normalized()}

## posición del hueso en el espacio de la cabina
func _fpos(b: int) -> Vector3:
	return skel.get_bone_global_pose(b).origin * s

## orienta el hueso para que su eje primario apunte a P y el secundario hacia S (vectores de la cabina)
func _orient(b: int, P: Vector3, S: Vector3) -> void:
	if not _ax.has(b):
		return
	var a: Dictionary = _ax[b]
	var p1 := P.normalized()
	var s1 := S - p1 * S.dot(p1)
	if s1.length_squared() < 1e-9:
		return
	s1 = s1.normalized()
	var t1 := p1.cross(s1)
	var m1 := Basis(p1, s1, t1)
	var ap: Vector3 = a["p"]
	var s0: Vector3 = (a["s"] as Vector3)
	s0 = (s0 - ap * s0.dot(ap)).normalized()
	var t0 := ap.cross(s0)
	var m2 := Basis(ap, s0, t0).transposed()
	var Q := m1 * m2
	var par := skel.get_bone_parent(b)
	var pq := skel.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis.IDENTITY
	skel.set_bone_pose_rotation(b, (pq.inverse() * Q).get_rotation_quaternion())

## IK de dos huesos: A (raíz) → codo/rodilla → objetivo T, con vector polo
func _two_bone(A: int, B2: int, L1: float, L2: float, T: Vector3, pole: Vector3, secA: Variant, secB: Variant) -> void:
	var S := _fpos(A)
	var d := T - S
	var ln := d.length()
	var mx := (L1 + L2) * 0.999
	if ln > mx:
		d *= mx / ln
		ln = mx
	ln = maxf(ln, absf(L1 - L2) + 1e-3)
	var dir := d.normalized()
	var a := (L1 * L1 - L2 * L2 + ln * ln) / (2.0 * ln)
	var h := sqrt(maxf(0.0, L1 * L1 - a * a))
	var pd := (pole - dir * pole.dot(dir)).normalized()
	var E := S + dir * a + pd * h
	var tgt := S + d
	var sa: Vector3
	if secA is String:
		sa = tgt - E + pd * -0.3
	elif secA == null:
		sa = pd
	else:
		sa = secA
	_orient(A, E - S, sa)
	_orient(B2, tgt - _fpos(B2), pd if secB == null else (secB as Vector3))

## Pose completa. o = {hips, head, roll, look, hands:[{side, wrist, fdir, back, pole?}], feet:[{side, pos}], grip}
func pose(o: Dictionary) -> void:
	if not ok:
		return
	var hips: int = B["Hips"]
	skel.set_bone_pose_position(hips, (o["hips"] as Vector3) / s)
	var fwd := Vector3(0, 0, 1)
	_orient(hips, Vector3(0, 1, -0.18).normalized(), fwd)
	# columna hacia la cabeza (reclinada, cuello adelante)
	var hp := _fpos(hips)
	var dir: Vector3 = ((o["head"] as Vector3) - hp).normalized()
	var n := _spine.size()
	for i in n:
		var tt := float(i) / float(n - 1) if n > 1 else 1.0
		var d := (dir + Vector3(0, 0, -0.10 + 0.28 * tt)).normalized()
		_orient(_spine[i], d, fwd)
	# cabeza: inclinación lateral por G y mirada hacia adelante
	var roll: float = o.get("roll", 0.0)
	var hd := Vector3(sin(roll), cos(roll), 0.05).normalized()
	_orient(B["Head"], hd, Vector3(o.get("look", 0.0), o.get("look_y", -0.1), 1))
	# brazos
	var grip: float = o.get("grip", 1.1)
	for h in o["hands"]:
		var S: Dictionary = _side.get(h["side"], {})
		if S.is_empty():
			continue
		var sg: float = S["sg"]
		var pole := Vector3(sg * 0.6, -1, -0.25)
		if h.has("pole"):
			var hp2: Vector3 = h["pole"]
			pole = Vector3(sg * hp2.x, hp2.y, hp2.z)
		var wrist: Vector3 = h["wrist"]
		# clavícula: acompaña un poco al brazo (sin esto el hombro se estira y deforma)
		if S["sh"] >= 0:
			var sp := _fpos(S["sh"])
			var tw := (wrist - sp).normalized()
			_orient(S["sh"], Vector3(sg, 0, 0) * 0.72 + tw * 0.28 + Vector3(0, -0.04, 0), Vector3.UP)
		_two_bone(S["arm"], S["fore"], S["L1"], S["L2"], wrist, pole, "fold", h["back"])
		_orient(S["hand"], h["fdir"], h["back"])
		for f in S["fing"]:
			var r: Quaternion = _rest[f["b"]]["lq"]
			skel.set_bone_pose_rotation(f["b"], r * Quaternion(f["ax"], -f["sg"] * grip * 0.55 * f["k"]))
	# piernas
	for f in o["feet"]:
		var S2: Dictionary = _side.get(f["side"], {})
		if S2.is_empty():
			continue
		_two_bone(S2["ul"], S2["lg"], S2["T1"], S2["T2"], f["pos"], Vector3(0, 1, 0.3), Vector3(0, 1, 0), Vector3(0, 0.3, 1))
		_orient(S2["ft"], Vector3(0, 0.25, 1), Vector3(0, 1, -0.2))

func hide_head(v: bool) -> void:
	if not ok or head_hidden == v:
		return
	head_hidden = v
	skel.set_bone_pose_scale(B["Head"], Vector3.ONE * (0.001 if v else 1.0))

func set_visible(v: bool) -> void:
	root.visible = v

func dispose() -> void:
	root.queue_free()
