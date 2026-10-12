extends SceneTree
## Vitrina de ruedas: cada fila es un diseño (llanta + goma) visto de 3/4. uso: -- salida.png "estilo:dibujo,estilo:dibujo,…" [R] [rr] [ancho] [yaw]
const WheelGen := preload("res://game/car/wheel_gen.gd")

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var items: Array = str(a[1]).split(",")
	var R := float(a[2]) if a.size() > 2 else 0.40
	var rr := float(a[3]) if a.size() > 3 else 0.24
	var tw := float(a[4]) if a.size() > 4 else 0.30
	var yaw := deg_to_rad(float(a[5])) if a.size() > 5 else deg_to_rad(55.0)
	var cols := 4
	var rows := ceili(float(items.size()) / cols)
	var vp := SubViewport.new()
	vp.size = Vector2i(1400, 360 * rows)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.56, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.88)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var tire := StandardMaterial3D.new()
	tire.albedo_color = Color(0.08, 0.085, 0.09)
	tire.roughness = 0.93
	var rimc := OS.get_environment("RIM") if OS.has_environment("RIM") else "#b9bdc4"
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(rimc)
	rim.metallic = 0.85
	rim.roughness = 0.28
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.035)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.7, 0.72, 0.75)
	steel.metallic = 1.0
	steel.roughness = 0.25
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.5, 0.5, 0.52)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	for i in items.size():
		var parts := str(items[i]).split(":")
		var root := Node3D.new()
		root.position = Vector3((i % cols) * 1.1 - (cols - 1) * 0.55, -(i / cols) * 1.0, 0)
		root.rotation.y = yaw
		vp.add_child(root)
		var wr := tw * 0.78
		var t := MeshInstance3D.new()
		t.mesh = WheelGen.tire_mesh(R, rr, tw, parts[1], false)
		for k in (t.mesh as ArrayMesh).get_surface_count():
			var nm := str((t.mesh as ArrayMesh).get_meta("names")[k])
			t.set_surface_override_material(k, tire if nm == "tire" else (white if parts[1] == "classic" else wall))
		root.add_child(t)
		var r := MeshInstance3D.new()
		r.mesh = WheelGen.rim_mesh(parts[0], rr, wr, false)
		for k in (r.mesh as ArrayMesh).get_surface_count():
			var nm := str((r.mesh as ArrayMesh).get_meta("names")[k])
			r.set_surface_override_material(k, rim if nm == "rim" else (steel if nm == "steel" else dark))
		root.add_child(r)
		var lbl := Label3D.new()
		lbl.text = str(items[i])
		lbl.position = Vector3(0, -R - 0.05, 0.4)
		lbl.pixel_size = 0.0035
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		root.add_child(lbl)
	var cam := Camera3D.new()
	cam.fov = 32.0
	vp.add_child(cam)
	cam.make_current()
	await process_frame
	var cy := -(rows - 1) * 0.5
	cam.position = Vector3(0, cy + 0.25, 6.0 + rows * 0.35)
	cam.look_at(Vector3(0, cy, 0))
	for i in 10:
		await process_frame
	vp.get_texture().get_image().save_png(a[0])
	quit()
