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

func setup(p_params: VehicleParams, p_lo: bool, paint: Color, rim: Color) -> void:
	V = p_params
	lo = p_lo
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	body.position.y = -V.comHeight + V.rideOffset
	var suffix := "_lo" if lo else ""
	var body_scene: PackedScene = load("res://game/models/volt_body%s.glb" % suffix)
	var shell: Node3D = body_scene.instantiate()
	body.add_child(shell)
	for mi in _mesh_instances(shell):
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var nm := mat.resource_name if mat else ""
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			if nm == "glass":
				m.albedo_color = Color(0.45, 0.55, 0.68, 0.72)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				m.metallic = 0.4
				m.roughness = 0.12
				m.cull_mode = BaseMaterial3D.CULL_DISABLED
			else:
				m.albedo_color = paint
				m.metallic = 0.45
				m.roughness = 0.35
			mi.set_surface_override_material(s, m)
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
	var base := V.comHeight + V.hardpointY - V.rideOffset
	for i in 4:
		var w: Dictionary = wheels[i]
		var steer: Node3D = w["steer"]
		steer.position.y = base - p.wheel_s[i]
		if w["front"]:
			steer.rotation.y = p.steerAngle
		w["angle"] += p.wheel_omega[i] * dt
		(w["spin"] as Node3D).rotation.x = w["angle"]
