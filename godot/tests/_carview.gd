extends SceneTree
## Vista previa de un auto (carrocería + ruedas + suspensión) sin carrera.
## uso: -- id salida.png yaw pitch dist [alto_mm] [target_y] [fov]
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 560)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var d: Dictionary = vehicles[a[0]].duplicate()
	var lift := float(a[5]) / 1000.0 if a.size() > 5 else 0.0
	d["rideOffset"] = float(d.get("rideOffset", 0.0)) + lift
	d["comHeight"] = float(d["comHeight"]) + lift
	var V: VehicleParams = VehicleParams.from_dict(d)
	var vis := CarVisual.new()
	vis.setup(V, false, Color(0.75, 0.08, 0.1), Color(0.8, 0.82, 0.86), "gloss")
	vp.add_child(vis)
	if OS.has_environment("LIV"): # prueba: rotulado (LIV=1..5) con color de franja naranja
		vis.set_livery(int(OS.get_environment("LIV")), Color(0.1, 0.3, 0.9), Color(1.0, 0.5, 0.1), "gloss")
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.52, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 40, 0)
	sun.light_energy = 1.3
	vp.add_child(sun)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.25, 0.27, 0.3)
	fl.material_override = fm
	fl.position.y = -V.comHeight + 0.0
	vp.add_child(fl)
	var cam := Camera3D.new()
	cam.fov = float(a[7]) if a.size() > 7 else 38.0
	vp.add_child(cam)
	cam.make_current()
	await process_frame
	var snap := CarSnapshot.new()
	vis.blob.visible = false
	var rest := V.comHeight - V.wheelRadius + V.hardpointY
	for i in 4:
		snap.wheel_s[i] = rest
	snap.px = 0.0
	snap.py = 0.0
	snap.pz = 0.0
	vis.sync_from(snap, 0.0)
	var yaw := deg_to_rad(float(a[2]))
	var pit := deg_to_rad(float(a[3]))
	var dist := float(a[4])
	var ty := float(a[6]) if a.size() > 6 else 0.5
	var tgt := Vector3(0, -V.comHeight + ty, 0)
	cam.position = tgt + Vector3(sin(yaw) * cos(pit), sin(pit), cos(yaw) * cos(pit)) * dist
	cam.look_at(tgt)
	for i in 8:
		await process_frame
	vp.get_texture().get_image().save_png(a[1])
	quit()
