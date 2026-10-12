## Una captura de cada auto SIN ruedas, en gris plata sobre fondo blanco, desde 3/4 delantero-lateral con poca altura (para dárselas a un generador de imágenes y volver a modelar el auto).
## Uso (pantalla virtual): [W=1920 H=1080 OUT=/ruta] xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://../tools/godot/body_shots.gd [-- id1 id2 …]
extends SceneTree

const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const CarBuild := preload("res://game/data/car_build.gd")

func _initialize() -> void:
	_run.call_deferred()

func _aabb(n: Node, acc: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as Node3D).visible:
		var mi := n as MeshInstance3D
		var bb := mi.global_transform * mi.mesh.get_aabb()
		acc[0] = bb if acc[0] == null else (acc[0] as AABB).merge(bb)
	for c in n.get_children():
		_aabb(c, acc)

func _measure(img: Image) -> Rect2i:
	var s := img.duplicate() as Image
	s.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	var x0 := 480
	var x1 := -1
	var y0 := 270
	var y1 := -1
	for y in 270:
		for x in 480:
			var c := s.get_pixel(x, y)
			if c.r < 0.94 or c.g < 0.94 or c.b < 0.94:
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)

func _run() -> void:
	OS.set_environment("CAR_NOWHEEL", "1") # sin ruedas ni suspensión: solo la carrocería
	OS.set_environment("CAR_NOSUSP", "1")
	var w := int(OS.get_environment("W")) if OS.has_environment("W") else 1920
	var h := int(OS.get_environment("H")) if OS.has_environment("H") else 1080
	var out := OS.get_environment("OUT") if OS.has_environment("OUT") else "/tmp/body_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var ids: Array = OS.get_cmdline_user_args() if not OS.get_cmdline_user_args().is_empty() else CarBuild.catalog()["order"]
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.94, 1.0)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.0
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 215, 0)
	fill.light_energy = 0.35
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 22.0
	cam.near = 0.5
	cam.far = 200.0
	vp.add_child(cam)
	cam.make_current()
	var n := 0
	for id in ids:
		n += 1
		var V: VehicleParams = VehicleParams.from_dict(vehicles[id].duplicate())
		var vis := CarVisual.new()
		vis.setup(V, false, Color(0.74, 0.76, 0.8), Color(0.8, 0.82, 0.86), "gloss")
		vp.add_child(vis)
		vis.set_livery(0, Color(0.74, 0.76, 0.8), Color(0.42, 0.43, 0.47), "gloss") # liso, los detalles (rojos de la textura, etc.) en gris oscuro
		vis.blob.visible = false
		for wd in vis.wheels:
			(wd["steer"] as Node3D).visible = false # ruedas, discos y pinzas
		for i in 3:
			await process_frame
		var acc: Array = [null]
		_aabb(vis, acc)
		var bb: AABB = acc[0]
		var ctr := bb.get_center()
		var yaw := deg_to_rad(72.0)
		var pit := deg_to_rad(7.0)
		var ext := maxf(bb.size.z * sin(yaw) + bb.size.x * cos(yaw), 0.5)
		var d := ext / (2.0 * 0.86 * tan(deg_to_rad(cam.fov) * 0.5) * float(w) / float(h)) + bb.size.length() * 0.5
		var path := "%s/%s.png" % [out, str(id)]
		for pass_i in 2:
			cam.position = ctr + Vector3(sin(yaw) * cos(pit), sin(pit), cos(yaw) * cos(pit)) * d
			cam.look_at(ctr)
			for i in 6:
				await process_frame
			var img := vp.get_texture().get_image()
			var r := _measure(img)
			var frac := float(r.size.x) / 480.0
			if pass_i == 0 and frac > 0.0:
				d *= frac / 0.88 # que ocupe ~88 % del ancho
				# y se centra el auto en el cuadro según lo medido
				var cx := (float(r.position.x) + float(r.size.x) * 0.5) / 480.0 - 0.5
				var cy := (float(r.position.y) + float(r.size.y) * 0.5) / 270.0 - 0.5
				var right := cam.global_transform.basis.x
				var up := cam.global_transform.basis.y
				var half_w := d * tan(deg_to_rad(cam.fov) * 0.5)
				ctr += right * (cx * 2.0 * half_w * float(w) / float(h)) - up * (cy * 2.0 * half_w)
			else:
				img.save_png(path)
		print("captura ", id, " ", n, "/", ids.size())
		vis.queue_free()
		await process_frame
	quit()
