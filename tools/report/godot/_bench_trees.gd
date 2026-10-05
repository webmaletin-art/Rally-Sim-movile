## (herramienta del informe de árboles, no es una prueba del juego) Mide el costo relativo de dibujar 1500 árboles en cada estilo (pantalla virtual, GL por software:
## sirve para comparar entre estilos, no son FPS de un teléfono). Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tests/_bench_trees.gd -- <carpeta de las imágenes de árboles>
extends SceneTree

const PaperKit := preload("res://game/fx/paper_kit.gd")
const LIB := "/home/user/Rally-Sim-movile/biblioteca/vegetacion_y_suelo/"
const N := 1500
const SPECIES := [["sc_pine", "arboles/sc_pine.glb", 10.0], ["tree_birch", "arboles/tree_birch.glb", 8.0], ["tree_tree", "arboles/tree_tree.glb", 10.0],
	["tree_black_tupelo", "arboles/tree_black_tupelo.glb", 12.0], ["sc_acacia", "arboles/sc_acacia.glb", 7.5], ["tree_sassafras", "arboles/tree_sassafras.glb", 11.0]]
var dir := "/tmp/claude-0/trees"
var vp: SubViewport
var scene: Node3D
var results: Dictionary = {}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		dir = a
	vp = SubViewport.new()
	vp.size = Vector2i(960, 432)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.75, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.85, 0.9)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 4, 0)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 70.0
	cam.far = 600.0
	vp.add_child(cam)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	ground.mesh = pm
	vp.add_child(ground)
	_run()

func _load_glb(path: String) -> Node:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(path, st)
	return doc.generate_scene(st)

func _merge_mesh(n: Node) -> ArrayMesh:
	# junta todas las superficies del GLB en una malla (con un material verde/marrón liso) como la usaría el juego en un MultiMesh
	var out := ArrayMesh.new()
	var mis: Array = []
	_collect(n, mis)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.22, 0.42, 0.12)
	green.cull_mode = BaseMaterial3D.CULL_DISABLED
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.35, 0.26, 0.17)
	for mi in mis:
		var m: Mesh = (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(s))
			out.surface_set_material(out.get_surface_count() - 1, green if s == 0 else brown)
	return out

func _collect(n: Node, acc: Array) -> void:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_collect(c, acc)

func _multimesh(mesh: Mesh, count: int, seed_v: int, scale_h: float, h_ref: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in count:
		var p := Vector3(rng.randf_range(-130.0, 130.0), 0, -rng.randf_range(35.0, 260.0))
		var s := rng.randf_range(0.8, 1.25) * scale_h / h_ref
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi

func _run() -> void:
	var styles := ["3D pesado (GLB original)", "Papercraft (.pap, el actual)", "Billboard foto (2 triángulos, con recorte)", "Cruz de 2 cartas (4 triángulos, con recorte)", "Billboard difuminado (mezcla alfa)", "Referencia: escena sin árboles"]
	var tex_cache: Dictionary = {}
	for sp in SPECIES:
		var im := Image.load_from_file("%s/%s_3d.png" % [dir, sp[0]])
		im.generate_mipmaps()
		tex_cache[sp[0]] = ImageTexture.create_from_image(im)
		var imb := Image.load_from_file("%s/%s_blur.png" % [dir, sp[0]])
		imb.generate_mipmaps()
		tex_cache[str(sp[0]) + "_blur"] = ImageTexture.create_from_image(imb)
	for si in styles.size():
		if scene != null:
			scene.queue_free()
		scene = Node3D.new()
		vp.add_child(scene)
		var tris_total := 0
		var calls := 0
		for k in (SPECIES.size() if si < 5 else 0):
			var sp: Array = SPECIES[k]
			var per: int = N / SPECIES.size()
			var h: float = sp[2]
			var mesh: Mesh = null
			var h_ref := h
			match si:
				0:
					var n := _load_glb(LIB + str(sp[1]))
					mesh = _merge_mesh(n)
				1:
					mesh = PaperKit.mesh(str(sp[0]))
					scene_mat(mesh)
				2, 4:
					mesh = _quad(tex_cache[sp[0] if si == 2 else str(sp[0]) + "_blur"], h, h * 0.9, false, si == 4, true)
				3:
					mesh = _quad(tex_cache[sp[0]], h, h * 0.9, true, false, false)
			var mmi := _multimesh(mesh, per, 100 + k, h, h_ref)
			scene.add_child(mmi)
			calls += mesh.get_surface_count()
			var tpi := 0
			for s in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(s)
				var idx: Variant = arr[Mesh.ARRAY_INDEX]
				tpi += (idx as PackedInt32Array).size() / 3 if idx != null and (idx as PackedInt32Array).size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			tris_total += tpi * per
		for f in 12:
			await process_frame
		var ts: Array = []
		for f in 40:
			var t0 := Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			ts.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		ts.sort()
		var med: float = ts[ts.size() / 2]
		results[styles[si]] = {"ms": snappedf(med, 0.1), "tris": tris_total, "calls": calls}
		print("%s · %.1f ms · %d triángulos totales · %d llamadas de dibujo" % [styles[si], med, tris_total, calls])
	var f := FileAccess.open(dir + "/bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results))
	f.close()
	quit()

func scene_mat(mesh: Mesh) -> void:
	pass

func _quad(tex: Texture2D, h: float, w: float, cross: bool, blend: bool, billboard: bool) -> ArrayMesh:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if blend:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.billboard_keep_scale = true
	var am := ArrayMesh.new()
	var planes := 2 if cross else 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for p in planes:
		var ang := PI * 0.5 * float(p)
		var dx := Vector3(cos(ang), 0, sin(ang)) * w * 0.5
		var base := verts.size()
		verts.append_array([-dx, dx, dx + Vector3(0, h, 0), -dx + Vector3(0, h, 0)])
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	am.surface_set_material(0, mat)
	return am
