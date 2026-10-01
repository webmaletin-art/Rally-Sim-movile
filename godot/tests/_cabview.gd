extends SceneTree
## Vista previa del habitáculo de un auto.
## uso: -- id salida.png modo [yaw pitch dist]   modo: onboard | rear | out (afuera, sin carrocería) | outbody (afuera, con carrocería y capó de adentro)
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const Cockpit := preload("res://game/car/cockpit.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var vp := SubViewport.new()
	vp.size = Vector2i(1000, 560)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var V: VehicleParams = VehicleParams.from_dict(vehicles[a[0]].duplicate())
	var vis := CarVisual.new()
	vis.setup(V, false, Color(0.75, 0.08, 0.1), Color(0.8, 0.82, 0.86), "gloss")
	vp.add_child(vis)
	var ck := Cockpit.new(str(V.visualType), Color(0.75, 0.08, 0.1), Color(1.0, 0.5, 0.1))
	ck.position = Vector3(0, -V.comHeight + V.rideOffset, 0)
	vis.add_child(ck)
	ck.set_engine(V.maxRpm, V.shiftUpRpm, 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.88)
	env.ambient_light_energy = 0.9
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
	fm.albedo_color = Color(0.3, 0.33, 0.3)
	fl.material_override = fm
	fl.position.y = -V.comHeight
	vp.add_child(fl)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.make_current()
	await process_frame
	var snap := CarSnapshot.new()
	vis.blob.visible = false
	var rest := V.comHeight - V.wheelRadius + V.hardpointY
	for i in 4:
		snap.wheel_s[i] = rest
	vis.sync_from(snap, 0.0)
	var mode := str(a[2])
	var inside := mode == "onboard" or mode == "rear" or mode == "out" or mode == "outbody" or mode == "ghost"
	vis.set_inside(mode == "onboard" or mode == "rear" or mode == "outbody")
	if mode == "out":
		vis.body.visible = false
	if mode == "ghost":
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.9, 0.2, 0.2, 0.28)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var st: Array = [vis.shell]
		while st.size() > 0:
			var n: Node = st.pop_back()
			if n is MeshInstance3D:
				for k in (n as MeshInstance3D).mesh.get_surface_count():
					(n as MeshInstance3D).set_surface_override_material(k, gm)
			st.append_array(n.get_children())
	ck.set_inside(inside, mode != "onboard")
	for i in 30:
		ck.update_crew(1.0 / 60.0, snap, false, float(i) / 60.0, 0.0)
		ck.update_cabin(1.0 / 60.0, snap, false, float(i) / 60.0)
		await process_frame
	if mode == "onboard" or mode == "rear":
		var cl: Dictionary = ck.camera_local("onboard" if mode == "onboard" else "rearcabin", snap, 0.5, 0.0)
		cam.fov = float(cl["hfov"]) * 0.58 # (aprox. vertical)
		cam.global_position = ck.global_transform * (cl["pos"] as Vector3)
		cam.look_at(ck.global_transform * (cl["look"] as Vector3))
	else:
		var yaw := deg_to_rad(float(a[3]) if a.size() > 3 else 60.0)
		var pit := deg_to_rad(float(a[4]) if a.size() > 4 else 15.0)
		var dist := float(a[5]) if a.size() > 5 else 6.0
		cam.fov = 35.0
		var tgt := Vector3(0, -V.comHeight + 0.9, 0)
		cam.position = tgt + Vector3(sin(yaw) * cos(pit), sin(pit), cos(yaw) * cos(pit)) * dist
		cam.look_at(tgt)
	for i in 6:
		await process_frame
	vp.get_texture().get_image().save_png(a[1])
	quit()
