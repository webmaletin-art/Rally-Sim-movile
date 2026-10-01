extends Node3D
## Dibujo del auto: carrocería y ruedas del GLB del Volt (los mismos modelos de la versión HTML), siguiendo a la física.
## Estructura igual a VehicleVisual de js/main.js: el grupo está en el centro de masa; la carrocería baja hasta el piso;
## cada rueda cuelga de su punto de suspensión y gira con la velocidad angular real de la física.

const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const VOLT_WHEEL_R := 0.40 # radio de la rueda con la que se modeló el GLB

var V: VehicleParams
var body: Node3D
var wheels: Array = [] # {steer, spin, front, angle}
var lo := false
var shell: Node3D
var blob: MeshInstance3D # sombrita suave en el piso (no hace falta una sombra de verdad)
static var _blob_mat: StandardMaterial3D

const FINISH := {"gloss": [0.45, 0.35], "metal": [0.9, 0.24], "matte": [0.08, 0.88], "chrome": [1.0, 0.07]} # metálico, rugosidad

func setup(p_params: VehicleParams, p_lo: bool, paint: Color, rim: Color, finish := "gloss") -> void:
	V = p_params
	lo = p_lo
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	body.position.y = -V.comHeight + V.rideOffset
	var suffix := "_lo" if lo else ""
	var body_scene: PackedScene = load("res://game/models/volt_body%s.glb" % suffix)
	shell = body_scene.instantiate()
	body.add_child(shell)
	# la carrocería del Volt se ajusta a la distancia entre ejes y a la trocha de cada auto (si no, las ruedas quedan corridas del chasis)
	var wb_ref := 2.9
	var wf_ref := 0.48
	var sz := V.wheelBase / wb_ref
	var sx := V.trackF / 2.02
	var c_ref := wb_ref * (1.0 - 2.0 * wf_ref) * 0.5 # centro entre ejes del Volt (adelante − atrás)/2
	var c_car := V.wheelBase * (1.0 - 2.0 * V.weightFront) * 0.5
	shell.scale = Vector3(sx, sqrt(sx * sz), sz)
	shell.position.z = c_car - c_ref * sz
	for mi in _mesh_instances(shell):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var nm := mat.resource_name if mat else ""
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			if nm == "glass":
				# vidrio polarizado: desde afuera no se ve la tripulación (ni se dibuja); además no hace falta transparencia
				m.albedo_color = Color(0.035, 0.045, 0.06)
				m.metallic = 0.6
				m.roughness = 0.1
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			else:
				m.albedo_color = paint
				var fin: Array = FINISH.get(finish, FINISH["gloss"])
				m.metallic = fin[0]
				m.roughness = fin[1]
			mi.set_surface_override_material(s, m)
	_make_blob()
	# ruedas
	var wheel_scene: PackedScene = load("res://game/models/volt_wheel%s.glb" % suffix)
	var R := V.wheelRadius
	var a := V.wheelBase * (1.0 - V.weightFront)
	var b := V.wheelBase * V.weightFront
	var defs := [[V.trackF / 2.0, a, true], [-V.trackF / 2.0, a, true], [V.trackR / 2.0, -b, false], [-V.trackR / 2.0, -b, false]]
	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.08, 0.085, 0.09)
	tire_mat.roughness = 0.93
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.18, 0.2, 0.22)
	rim_mat.metallic = 0.85
	rim_mat.roughness = 0.28
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = rim
	ring_mat.metallic = 0.35
	ring_mat.roughness = 0.3
	for d in defs:
		var steer := Node3D.new()
		steer.position = Vector3(d[0], R, d[1])
		body.add_child(steer)
		var spin := Node3D.new()
		steer.add_child(spin)
		var w: Node3D = wheel_scene.instantiate()
		var k := R / VOLT_WHEEL_R
		w.scale = Vector3(-k if d[0] < 0.0 else k, k, k)
		spin.add_child(w)
		for mi in _mesh_instances(w):
			var mesh2: Mesh = mi.mesh
			for s in mesh2.get_surface_count():
				var mt := mesh2.surface_get_material(s)
				var n2 := mt.resource_name if mt else ""
				mi.set_surface_override_material(s, tire_mat if n2 == "tire" else (ring_mat if n2 == "ring" else rim_mat))
		wheels.append({"steer": steer, "spin": spin, "front": d[2], "angle": 0.0})

func _make_blob() -> void:
	if _blob_mat == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.28), Color(0, 0, 0, 0.0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_SQUARE
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_blob_mat = StandardMaterial3D.new()
		_blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob_mat.albedo_texture = gt
		_blob_mat.disable_receive_shadows = true
	blob = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(V.trackF + 1.3, V.wheelBase + 2.4)
	q.material = _blob_mat
	blob.mesh = q
	blob.top_level = true
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)

## Puntos de las cámaras de capó y paragolpes, medidos sobre la carrocería real (rayos sobre sus triángulos), en el marco del auto
func compute_mounts(cowl_z: float, eye_y: float) -> Dictionary:
	var ground := -V.comHeight + V.rideOffset
	var tris := PackedVector3Array()
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for mi in _mesh_instances(shell):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != self:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for v in (mi.mesh as Mesh).get_faces():
			var w := xf * v
			tris.append(w)
			mn = mn.min(w)
			mx = mx.max(w)
	var hy := NAN
	for dz in [0.3, 0.5, 0.7, 0.15]:
		var z := minf(cowl_z + dz, mx.z - 0.2)
		var best := -1e9
		for k in range(0, tris.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(0, mx.y + 1.0, z), Vector3.DOWN, tris[k], tris[k + 1], tris[k + 2])
			if hit != null:
				best = maxf(best, (hit as Vector3).y)
		if best > -1e8:
			hy = best
			break
	if is_nan(hy):
		hy = ground + eye_y - 0.35
	return {"hood": {"y": maxf(hy + 0.36, ground + eye_y - 0.25), "z": cowl_z + 0.02, "ly": -0.22}, "bumper": {"y": ground + 0.46, "z": mx.z + 0.06, "ly": -0.1}}

func _mesh_instances(root: Node) -> Array:
	var out := []
	var stack := [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out

## Sincroniza con el estado de la física
func sync_from(p: CarSnapshot, dt: float) -> void:
	position = Vector3(p.px, p.py, p.pz)
	basis = Basis.from_euler(Vector3(p.pitch, p.yaw, p.roll), EULER_ORDER_YXZ)
	blob.global_position = Vector3(p.px, p.py - V.comHeight + 0.05, p.pz)
	blob.global_rotation = Vector3(0.0, p.yaw, 0.0)
	var base := V.comHeight + V.hardpointY - V.rideOffset
	for i in 4:
		var w: Dictionary = wheels[i]
		var steer: Node3D = w["steer"]
		steer.position.y = base - p.wheel_s[i]
		if w["front"]:
			steer.rotation.y = p.steerAngle
		w["angle"] += p.wheel_omega[i] * dt
		(w["spin"] as Node3D).rotation.x = w["angle"]
