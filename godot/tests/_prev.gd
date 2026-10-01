extends SceneTree
# uso: -- res://modelo.glb salida.png [yaw_deg] [pitch_deg] [dist]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 560)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var ps: PackedScene = load(a[0])
	var m: Node3D = ps.instantiate()
	vp.add_child(m)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	vp.add_child(sun)
	var yaw := deg_to_rad(float(a[2]) if a.size() > 2 else 35.0)
	var pit := deg_to_rad(float(a[3]) if a.size() > 3 else 15.0)
	var dist := float(a[4]) if a.size() > 4 else 3.4
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 38
	cam.make_current()
	await process_frame
	cam.position = Vector3(sin(yaw) * cos(pit), sin(pit), cos(yaw) * cos(pit)) * dist + Vector3(0, 0.3, 0)
	cam.look_at(Vector3(0, 0.3, 0))
	for i in 10:
		await process_frame
	vp.get_texture().get_image().save_png(a[1])
	quit()
