## (herramienta del informe de autos, no es una prueba) Dibuja cada auto en 6 versiones con la misma cámara: alta y baja del juego (CarVisual) y las 4 livianas de tools/report/car_variants.py.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/_render_cars.gd -- <carpeta de los .pap> <carpeta de salida> [ids separados por coma]
extends SceneTree
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")

var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var in_dir := "/tmp/claude-0/cars"
var out_dir := "/tmp/claude-0/cars/img"

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		in_dir = a[0]
	if a.size() > 1:
		out_dir = a[1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	vp = SubViewport.new()
	vp.size = Vector2i(640, 400)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.52, 0.6, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.86)
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.2
	vp.add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.32, 0.35)
	fl.material_override = fm
	vp.add_child(fl)
	cam = Camera3D.new()
	cam.fov = 28.0
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	_run(a[2].split(",") if a.size() > 2 else PackedStringArray())

func _meshes(n: Node, acc: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).visible and (n as MeshInstance3D).mesh != null:
		acc.append(n)
	for c in n.get_children():
		_meshes(c, acc)

func _frame(n: Node3D) -> void:
	var acc: Array = []
	_meshes(n, acc)
	var box := AABB()
	var first := true
	for m in acc:
		var mi: MeshInstance3D = m
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	n.position -= Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
	var c := Vector3(0, box.size.y * 0.45, 0)
	var yaw := deg_to_rad(38.0)
	var pit := deg_to_rad(13.0)
	var dist := box.size.length() * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 0.9
	cam.position = c + Vector3(sin(yaw) * cos(pit), sin(pit), cos(yaw) * cos(pit)) * dist
	cam.look_at(c)

func _pap_mesh(path: String) -> ArrayMesh:
	var f := FileAccess.open(path, FileAccess.READ)
	f.get_buffer(4)
	var nv := int(f.get_32())
	var pos := f.get_buffer(nv * 12).to_float32_array()
	var rgba := f.get_buffer(nv * 4)
	f.close()
	var verts := PackedVector3Array()
	verts.resize(nv)
	var cols := PackedColorArray()
	cols.resize(nv)
	for i in nv:
		verts[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
		cols[i] = Color8(rgba[i * 4], rgba[i * 4 + 1], rgba[i * 4 + 2], 255)
	return PaperKit.mesh_from_triangles(verts, cols)

func _flat_mesh(path: String) -> ArrayMesh:
	var pm := _pap_mesh(path)
	var arr := pm.surface_get_arrays(0)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	return m

## El GLB propio del Genesis (models/genesis_body*.glb, hoy sin usar): carrocería roja, vidrio oscuro y cuatro ruedas simples
func _genesis_glb(lo: bool, d: Dictionary) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path("res://game/models/genesis_body%s.glb" % ("_lo" if lo else "")), st)
	var node: Node = doc.generate_scene(st)
	var acc: Array = []
	_meshes(node, acc)
	for m in acc:
		var mi: MeshInstance3D = m
		for sidx in mi.mesh.get_surface_count():
			var nm := StandardMaterial3D.new()
			var mn := str(mi.mesh.surface_get_material(sidx).resource_name) if mi.mesh.surface_get_material(sidx) != null else ""
			if mn == "glass":
				nm.albedo_color = Color(0.08, 0.1, 0.14)
				nm.roughness = 0.1
			else:
				nm.albedo_color = Color(0.75, 0.08, 0.1)
				nm.metallic = 0.45
				nm.roughness = 0.35
			mi.set_surface_override_material(sidx, nm)
	var root3 := Node3D.new()
	root3.add_child(node)
	var R: float = float(d["wheelRadius"])
	var wb: float = float(d["wheelBase"])
	var tw: float = float(d["trackF"])
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = R
			cm.bottom_radius = R
			cm.height = 0.3
			cm.radial_segments = 24
			w.mesh = cm
			w.rotation_degrees = Vector3(0, 0, 90)
			w.position = Vector3(sx * (tw * 0.5), R, sz * wb * 0.5)
			var wm := StandardMaterial3D.new()
			wm.albedo_color = Color(0.08, 0.08, 0.09)
			w.material_override = wm
			root3.add_child(w)
	return root3

func _civil_actual(id: String) -> Node3D:
	var root3 := Node3D.new()
	var sc := {"hatch": Vector3(1.0, 1.0, 0.88), "muscle": Vector3(1.0, 1.0, 1.0), "suv": Vector3(1.08, 1.22, 1.1)}.get(id, Vector3.ONE) as Vector3
	var parts := [[Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.3), Color(0.95, 0.95, 0.95)], [Vector3(0, 1.1, -0.2), Vector3(1.55, 0.5, 2.3), Color(0.18, 0.24, 0.32)], [Vector3(0, 1.38, -0.2), Vector3(1.5, 0.08, 2.1), Color(0.85, 0.85, 0.85)]]
	for wx in [-0.92, 0.92]:
		for wz in [-1.4, 1.4]:
			parts.append([Vector3(wx, 0.32, wz), Vector3(0.22, 0.64, 0.64), Color(0.1, 0.1, 0.12)])
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = (p[1] as Vector3) * sc
		mi.mesh = bm
		mi.position = (p[0] as Vector3) * sc
		var m := StandardMaterial3D.new()
		m.albedo_color = p[2]
		m.roughness = 0.55
		m.metallic = 0.2
		mi.material_override = m
		root3.add_child(mi)
	return root3

func _shot(path: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)

func _run(only: PackedStringArray) -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var ids: Array = vehicles.keys()
	ids.append("genesis_glb")
	for id in ids:
		if not only.is_empty() and not (id in only):
			continue
		var d: Dictionary = (vehicles["genesis" if id == "genesis_glb" else id] as Dictionary).duplicate()
		if OS.has_environment("CIVIL"):
			# autos civiles: el mismo cubo de 7 cajas que usa el juego (world/parked_cars.gd y civil_traffic.gd), con los tres tamaños, y las variantes
			for c in holder.get_children():
				c.queue_free()
			await process_frame
			holder.add_child(_civil_actual(id))
			await process_frame
			_frame(holder.get_child(0))
			await _shot("%s/%s_actual.png" % [out_dir, id])
			for k in ["cajas", "rampas", "lowpoly", "papel"]:
				for c in holder.get_children():
					c.queue_free()
				await process_frame
				var mi2 := MeshInstance3D.new()
				mi2.mesh = _pap_mesh("%s/%s_%s.pap" % [in_dir, id, k]) if k == "papel" else _flat_mesh("%s/%s_%s.pap" % [in_dir, id, k])
				holder.add_child(mi2)
				await process_frame
				_frame(mi2)
				await _shot("%s/%s_%s.png" % [out_dir, id, k])
			print("OK ", id)
			continue
		for lo in [false, true]:
			if id == "genesis_glb":
				for c in holder.get_children():
					c.queue_free()
				await process_frame
				var node := _genesis_glb(lo, d)
				holder.add_child(node)
				await process_frame
				_frame(node)
				await _shot("%s/%s_%s.png" % [out_dir, id, "lo" if lo else "hi"])
				continue
			for c in holder.get_children():
				c.queue_free()
			await process_frame
			var V: VehicleParams = VehicleParams.from_dict(d)
			var vis := CarVisual.new()
			vis.setup(V, lo, Color(0.75, 0.08, 0.1), Color(0.8, 0.82, 0.86), "gloss")
			holder.add_child(vis)
			await process_frame
			vis.blob.visible = false
			var snap := CarSnapshot.new()
			var rest := V.comHeight - V.wheelRadius + V.hardpointY
			for i in 4:
				snap.wheel_s[i] = rest
			vis.sync_from(snap, 0.0)
			await process_frame
			_frame(vis)
			await _shot("%s/%s_%s.png" % [out_dir, id, "lo" if lo else "hi"])
		for k in ["cajas", "rampas", "lowpoly", "papel"]:
			for c in holder.get_children():
				c.queue_free()
			await process_frame
			var p := "%s/%s_%s.pap" % [in_dir, id, k]
			var mi := MeshInstance3D.new()
			mi.mesh = _pap_mesh(p) if k == "papel" else _flat_mesh(p)
			if k == "papel":
				mi.mesh = _pap_mesh(p)
			holder.add_child(mi)
			await process_frame
			_frame(mi)
			await _shot("%s/%s_%s.png" % [out_dir, id, k])
		print("OK ", id)
	quit()
