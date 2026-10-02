## Capturas del Vórtice de Ensueño desde varios puntos de la vuelta (con xvfb y OpenGL): arma la pista, el mundo, el cielo y los reflejos.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 --script res://tests/dream_shots.gd -- /carpeta/salida [fracción:alto:giro ...]
extends SceneTree

const DreamTrack := preload("res://game/track/dream_track.gd")
const DreamWorld := preload("res://game/track/dream_world.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/dream_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	var m: Dictionary = maps["dream"]
	var t0 := Time.get_ticks_msec()
	var track := DreamTrack.new(str(m["route"]), str(m["mode"]), false, 0.0)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = false
	var cam := Camera3D.new()
	cam.fov = 66.0
	cam.near = 0.15
	vp.add_child(sun)
	vp.add_child(cam)
	cam.make_current()
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	DreamWorld.atmosphere(env, sun, cam, vp)
	var dw := DreamWorld.new()
	dw.setup(track, 0.75, DreamWorld.SUN)
	vp.add_child(dw)
	print("mundo armado en %d ms · %d plantas" % [Time.get_ticks_msec() - t0, dw.inst_total])
	# puntos de vista: [fracción de la vuelta, alto sobre el camino, giro (grados) respecto de la marcha, atrás (m)]
	var shots: Array = [[0.003, 3.2, 0.0, 9.0, "00_largada"], [0.06, 3.0, 0.0, 9.0, "01_inicio_subida"], [0.20, 3.0, 0.0, 9.0, "02_subida"], [0.30, 3.0, 0.0, 9.0, "03_cerca_cresta"],
		[0.40, 3.2, 0.0, 9.0, "04_cresta_peralte"], [0.52, 3.0, 0.0, 9.0, "05_bajada"], [0.65, 3.0, 0.0, 9.0, "06_bajada_baja"], [0.80, 3.0, 0.0, 9.0, "07_retorno"],
		[0.32, 70.0, 999.0, 0.0, "08_agujero_negro"], [0.22, 14.0, 0.0, 30.0, "09_vista_alta"], [0.45, 4.0, -25.0, 6.0, "10_planeta"], [0.92, 3.0, 0.0, 9.0, "11_final"], [0.236, 4.0, 0.0, 28.0, "12_arco"], [0.002, 5.0, 0.0, 14.0, "13_largada_arco"]]
	for sh in shots:
		var i := int(float(sh[0]) * float(track.n))
		var p: Vector3 = track.samples[i]
		var tg: Vector3 = track.tangents[i]
		var yaw := atan2(tg.x, tg.z) + deg_to_rad(float(sh[2]))
		if float(sh[2]) > 900.0: # mirar al centro (el agujero negro)
			yaw = atan2(-p.x, -p.z)
		var back := Vector3(-tg.x, 0, -tg.z).normalized() * float(sh[3])
		cam.position = Vector3(p.x, track.cy[i] + float(sh[1]), p.z) + back
		var pitch := -8.0 if float(sh[1]) < 6.0 else -18.0 - (float(sh[1]) - 6.0) * 0.1
		if float(sh[2]) > 900.0:
			pitch = -22.0
		cam.rotation = Vector3(deg_to_rad(pitch), yaw + PI, 0)
		for k in 6:
			await process_frame
		var img := vp.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, str(sh[4])])
	quit()
