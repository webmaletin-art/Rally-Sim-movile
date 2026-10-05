## (herramienta del informe de árboles, no es una prueba del juego) Dibuja cada árbol en 3D pesado (GLB original) y en papel (.pap) con la misma cámara.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/_render_trees.gd -- <carpeta salida>
extends SceneTree

const PaperKit := preload("res://game/fx/paper_kit.gd")
const AdvProps := preload("res://game/adventure/adv_props.gd")
const LIB := "/home/user/Rally-Sim-movile/biblioteca/vegetacion_y_suelo/"
const SZ := 320

# [id, ruta del glb pesado (o ""), id del papel, altura m]
var items: Array = []
var out_dir := "/tmp/claude-0/trees"
var vp: SubViewport
var holder: Node3D
var cam: Camera3D

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		out_dir = a
	DirAccess.make_dir_recursive_absolute(out_dir)
	for c in PaperKit.catalog():
		var src := str(c.get("source", ""))
		if src == "" or not (str(c["cat"]) in ["arbol", "palmera", "bambu"]):
			continue
		var glb := ""
		if src.begins_with("arboles/"):
			glb = LIB + src.split(" ")[0]
		elif src.begins_with("plantas_flores_arbustos/"):
			glb = LIB + src.split(" ")[0]
		elif src.begins_with("procedural"):
			glb = LIB + "procedural_arboles_y_plantas/" + str(c["id"]) + ".glb"
		items.append([str(c["id"]), glb, str(c["id"]), float(c["h"])])
	for id in ["arbusto", "cactus"]:
		var c2: Dictionary = PaperKit.info(id)
		items.append([id, LIB + "procedural_arboles_y_plantas/" + id + ".glb", id, float(c2["h"])])
	vp = SubViewport.new()
	vp.size = Vector2i(SZ, SZ)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 1.0)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 0.9
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	holder = Node3D.new()
	vp.add_child(holder)
	_run()

func _frame_node(n: Node3D, h: float) -> void:
	# centra y encuadra por la altura real (la misma para las dos versiones)
	var box := _aabb(n)
	var cx := box.position.x + box.size.x * 0.5
	var cz := box.position.z + box.size.z * 0.5
	n.position = Vector3(-cx, -box.position.y, -cz)
	var hh := maxf(box.size.y, 0.01)
	var w := maxf(box.size.x, box.size.z)
	var span := maxf(hh, w * 0.95) * 1.12
	cam.size = span
	cam.position = Vector3(0, span * 0.5 - 0.0 + 0.0, 40.0)
	cam.position.y = hh * 0.5 + 0.0
	cam.look_at(Vector3(0, hh * 0.5, 0))

func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in _meshes(n):
		var mi: MeshInstance3D = c
		var b: AABB = mi.global_transform * mi.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out

func _meshes(n: Node) -> Array:
	var r: Array = []
	if n is MeshInstance3D:
		r.append(n)
	for c in n.get_children():
		r.append_array(_meshes(c))
	return r

## El pack trae hojas como tarjetas sin material (color por defecto = blanco): se les da verde/marrón y se ven de los dos lados
func _fix_materials(n: Node) -> void:
	for c in _meshes(n):
		var mi: MeshInstance3D = c
		var m: Mesh = mi.mesh
		var sizes: Array = []
		for sidx in m.get_surface_count():
			sizes.append((m.surface_get_arrays(sidx)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		var big := 0
		for k in sizes.size():
			if sizes[k] > sizes[big]:
				big = k
		for sidx in m.get_surface_count():
			var cur: Material = mi.get_active_material(sidx)
			var nm: StandardMaterial3D
			if cur is StandardMaterial3D:
				nm = (cur as StandardMaterial3D).duplicate()
				if nm.albedo_color.is_equal_approx(Color(1, 1, 1)) and nm.albedo_texture == null:
					nm.albedo_color = Color(0.22, 0.42, 0.12) if sidx == big else Color(0.35, 0.26, 0.17)
			else:
				nm = StandardMaterial3D.new()
				nm.albedo_color = Color(0.22, 0.42, 0.12) if sidx == big else Color(0.35, 0.26, 0.17)
			nm.cull_mode = BaseMaterial3D.CULL_DISABLED
			nm.roughness = 0.95
			mi.set_surface_override_material(sidx, nm)

func _tris(n: Node) -> int:
	var t := 0
	for c in _meshes(n):
		var m: Mesh = (c as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			t += (idx as PackedInt32Array).size() / 3 if idx != null and (idx as PackedInt32Array).size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)

func _run() -> void:
	var report: Array = []
	for it in items:
		var id: String = it[0]
		var glb: String = it[1]
		var rec := {"id": id, "heavy_tris": 0, "paper_tris": 0}
		for c in holder.get_children():
			c.queue_free()
		await process_frame
		# papel
		var pm := PaperKit.mesh(str(it[2]))
		if pm != null:
			var mi := MeshInstance3D.new()
			mi.mesh = pm
			holder.add_child(mi)
			_frame_node(mi, float(it[3]))
			rec["paper_tris"] = _tris(mi)
			await _shot("%s/%s_pap.png" % [out_dir, id])
			mi.queue_free()
		await process_frame
		# 3D pesado (GLB)
		if glb != "" and FileAccess.file_exists(glb):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(glb, st) == OK:
				var node: Node = doc.generate_scene(st)
				holder.add_child(node)
				_fix_materials(node)
				_frame_node(node as Node3D, float(it[3]))
				rec["heavy_tris"] = _tris(node)
				await _shot("%s/%s_3d.png" % [out_dir, id])
				node.queue_free()
		report.append(rec)
		print("OK ", id, " ", rec["heavy_tris"], " ", rec["paper_tris"])
	var f := FileAccess.open(out_dir + "/report.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report))
	f.close()
	quit()
