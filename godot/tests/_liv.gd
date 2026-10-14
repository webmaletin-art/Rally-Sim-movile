extends SceneTree
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
func _initialize():
	_go.call_deferred()
func _go():
	var a := OS.get_cmdline_user_args()
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var vp := SubViewport.new()
	vp.size = Vector2i(560, 300)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.58, 0.68)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.86, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.position = Vector3(3.6, 1.2, 1.7)
	cam.fov = 38.0
	cam.look_at(Vector3(0, 0.4, 0))
	var V: VehicleParams = VehicleParams.from_dict(vehicles[a[0]].duplicate())
	var vis := CarVisual.new()
	vis.setup(V, false, Color(0.8, 0.1, 0.1), Color(0.8, 0.82, 0.86), "gloss")
	vp.add_child(vis)
	var cols := {12: ["#d3162b", "#ff6a08"], 13: ["#f2f3f5", "#1a4fe0"], 14: ["#d3162b", "#15161a"], 15: ["#15161a", "#00e5ff"], 16: ["#f2f3f5", "#d3162b"], 17: ["#ff6a08", "#6a1fd1"], 18: ["#ffc300", "#15161a"], 19: ["#15161a", "#ff6a08"]}
	var imgs: Array = []
	for pat in [12, 13, 14, 15, 16, 17, 18, 19]:
		vis.set_livery(pat, Color(cols[pat][0]), Color(cols[pat][1]), "gloss", Color(1, 0.85, 0.1) if pat == 19 else Color(0.96, 0.96, 0.95))
		for k in 6:
			await process_frame
		imgs.append(vp.get_texture().get_image())
	var out := Image.create(560 * 4, 300 * 2, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		out.blit_rect(im, Rect2i(0, 0, 560, 300), Vector2i((i % 4) * 560, (i / 4) * 300))
	out.save_png(a[1])
	quit()
