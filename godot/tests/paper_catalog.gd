## Saca capturas de TODAS las piezas del pack en papel, en grillas (con nombre debajo): arboles, plantas, otros.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1920x1080 --script res://tests/paper_catalog.gd -- <carpeta de salida>
extends SceneTree

const PaperKit := preload("res://game/fx/paper_kit.gd")

func _init() -> void:
	var out := "/tmp/paper_catalog"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var prefix := args[1] if args.size() > 1 else "" # solo las piezas cuyo id empieza así (por ejemplo «d_» = flora de ensueño)
	DirAccess.make_dir_recursive_absolute(out)
	var groups := {"1_arboles": ["arbol", "palmera"], "2_plantas_flores_rocas": ["arbusto", "planta", "flor", "bambu", "roca", "pasto"], "3_calle_y_suelo": ["calle"]}
	var cat := PaperKit.catalog()
	await process_frame
	for gname in groups:
		var items: Array = []
		for c in cat:
			if (groups[gname] as Array).has(str(c["cat"])) and str(c["id"]).begins_with(prefix):
				items.append(c)
		var per := 10
		for part in int(ceil(float(items.size()) / float(per))):
			await _shot("%s_%d" % [gname, part + 1], items.slice(part * per, (part + 1) * per), out, gname)
	quit()

func _shot(gname: String, items: Array, out: String, kind: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.90, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.86, 0.92)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.8
	vp.add_child(sun)
	var cols := 5
	var rows := int(ceil(float(items.size()) / float(cols)))
	var cell := 13.0 if kind == "1_arboles" else (3.4 if kind == "2_plantas_flores_rocas" else 7.0)
	var args2 := OS.get_cmdline_user_args()
	if args2.size() > 2 and kind == "2_plantas_flores_rocas":
		cell = float(args2[2]) # tamaño de la celda (más chico = más zoom)
	var vscale := 1.0
	for i in items.size():
		var c: Dictionary = items[i]
		var mi := MeshInstance3D.new()
		mi.mesh = PaperKit.mesh(str(c["id"]))
		var cx := (i % cols) - (cols - 1) * 0.5
		var rz := int(i / cols) - (rows - 1) * 0.5
		mi.position = Vector3(cx * cell, 0, rz * cell)
		vp.add_child(mi)
		var lb := Label3D.new()
		lb.text = "%s\n%d tri" % [str(c["id"]), int(c["tris"])]
		lb.font_size = 40
		lb.pixel_size = cell / 1100.0
		lb.rotation_degrees = Vector3(-35, 0, 0)
		lb.position = Vector3(cx * cell, 0.02, rz * cell + cell * 0.42)
		lb.modulate = Color(0.15, 0.17, 0.22)
		lb.outline_size = 0
		vp.add_child(lb)
	var floor_m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(cols * cell + 20, rows * cell + 20)
	floor_m.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.60, 0.54)
	floor_m.material_override = fm
	floor_m.position.y = -0.02
	vp.add_child(floor_m)
	var cam := Camera3D.new()
	cam.fov = 38.0
	var span_x := cols * cell
	var dist := span_x * 0.85 + rows * cell * 0.4
	cam.position = Vector3(0, dist * 0.50, dist * 0.82)
	vp.add_child(cam)
	cam.look_at(Vector3(0, cell * 0.18, 0))
	cam.make_current()
	await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, gname])
	print("guardado ", gname, " ", items.size())
	vp.queue_free()
