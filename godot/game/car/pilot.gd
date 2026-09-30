extends RefCounted
## Piloto sentado (fase de prueba): el mismo modelo con esqueleto tipo Mixamo que usa la versión HTML.
## Por ahora va con una pose fija de sentado con las manos al frente; la cinemática inversa (volante, palanca,
## freno de mano, fuerzas G) se porta en la fase 2.

static var _lo_scene: PackedScene
static var _full_mat: Material

static func create(parent: Node3D, x: float, hip_y: float, hip_z: float, lo: bool, max_dist := 0.0) -> Node3D:
	if _lo_scene == null:
		_lo_scene = load("res://game/models/pilot_lo.glb")
		var full: Node = (load("res://game/models/pilot.glb") as PackedScene).instantiate()
		for mi in _meshes(full):
			if mi.mesh.get_surface_count() > 0:
				_full_mat = mi.mesh.surface_get_material(0)
				break
		full.free()
	var root := Node3D.new()
	parent.add_child(root)
	var scene: Node3D = (_lo_scene if lo else load("res://game/models/pilot.glb")).instantiate()
	root.add_child(scene)
	var skel := _find_skeleton(scene)
	for mi in _meshes(scene):
		mi.set_surface_override_material(0, _full_mat)
		mi.extra_cull_margin = 2.0
		if max_dist > 0.0:
			mi.visibility_range_end = max_dist # los pilotos de los rivales lejanos no se dibujan
	if skel == null:
		return root
	var head := _bone(skel, "Head")
	var foot := _bone(skel, "LeftFoot")
	var hips := _bone(skel, "Hips")
	var h_head := skel.get_bone_global_rest(head).origin.y
	var h_foot := skel.get_bone_global_rest(foot).origin.y
	var s := 1.76 * 0.80 / maxf(0.0001, (h_head - h_foot) * skel.global_transform.basis.get_scale().y)
	root.scale = Vector3.ONE * s
	# pose de sentado
	_rot(skel, "LeftUpLeg", Vector3.RIGHT, -PI / 2.0)
	_rot(skel, "RightUpLeg", Vector3.RIGHT, -PI / 2.0)
	_rot(skel, "LeftLeg", Vector3.RIGHT, deg_to_rad(80.0))
	_rot(skel, "RightLeg", Vector3.RIGHT, deg_to_rad(80.0))
	_rot(skel, "LeftArm", Vector3.BACK, -PI / 2.0)
	_rot(skel, "LeftArm", Vector3.RIGHT, deg_to_rad(-70.0))
	_rot(skel, "RightArm", Vector3.BACK, PI / 2.0)
	_rot(skel, "RightArm", Vector3.RIGHT, deg_to_rad(-70.0))
	_rot(skel, "LeftForeArm", Vector3.RIGHT, deg_to_rad(30.0))
	_rot(skel, "RightForeArm", Vector3.RIGHT, deg_to_rad(30.0))
	# la cadera en la butaca
	var hip_local := root.to_local(skel.to_global(skel.get_bone_global_pose(hips).origin))
	root.position = Vector3(x, hip_y, hip_z) - root.basis * hip_local
	return root

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

static func _bone(skel: Skeleton3D, suffix: String) -> int:
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i)
		if nm == suffix or nm.ends_with("_" + suffix) or nm.ends_with(":" + suffix):
			return i
	return -1

## Gira un hueso alrededor de un eje del esqueleto (ejes en espacio del esqueleto)
static func _rot(skel: Skeleton3D, suffix: String, axis: Vector3, angle: float) -> void:
	var i := _bone(skel, suffix)
	if i < 0:
		return
	var par := skel.get_bone_parent(i)
	var cur := skel.get_bone_global_pose(i).basis
	var target := Basis(axis, angle) * cur
	var pb := skel.get_bone_global_pose(par).basis if par >= 0 else Basis.IDENTITY
	skel.set_bone_pose_rotation(i, (pb.inverse() * target).get_rotation_quaternion())
