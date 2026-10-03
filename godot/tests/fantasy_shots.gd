## Capturas de un mapa fantasía (dream, marte, luna, anillo) desde varios puntos de la vuelta, con xvfb y OpenGL: arma la pista, el mundo y el cielo.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 --script res://tests/fantasy_shots.gd -- /carpeta/salida <mapa> [densidad]
extends SceneTree

const DreamTrack := preload("res://game/track/dream_track.gd")
const DreamWorld := preload("res://game/track/dream_world.gd")
const FantasyWorld := preload("res://game/track/fantasy_world.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/fantasy_shots"
	var map_id := args[1] if args.size() > 1 else "marte"
	var dens := float(args[2]) if args.size() > 2 else 0.75
	DirAccess.make_dir_recursive_absolute(out)
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	var m: Dictionary = maps[map_id]
	var theme := str(m.get("world", "dream"))
	var t0 := Time.get_ticks_msec()
	var track := DreamTrack.new(str(m["route"]), str(m["mode"]), false, 0.0)
	track.theme = theme
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
	var world: Node3D
	var sun_dir: Vector3
	var planet_dir := Vector3(-0.88, 0.36, 0.10)
	if theme == "dream":
		DreamWorld.atmosphere(env, sun, cam, vp)
		world = DreamWorld.new()
		world.setup(track, dens, DreamWorld.SUN)
		sun_dir = DreamWorld.SUN
	else:
		FantasyWorld.atmosphere_of(theme, env, sun, cam, vp)
		world = FantasyWorld.new()
		world.setup_world(track, dens, theme)
		sun_dir = FantasyWorld.SUNS[theme]
		planet_dir = FantasyWorld.PLANETS.get(theme, planet_dir)
	vp.add_child(world)
	print("mundo armado en %d ms · %d piezas" % [Time.get_ticks_msec() - t0, world.inst_total])
	# puntos de vista: [fracción de la vuelta, alto sobre el camino, giro (grados) respecto de la marcha (999 = al planeta, 888 = al sol), atrás (m), nombre]
	var shots: Array = [[0.003, 3.2, 0.0, 9.0, "00_largada"], [0.06, 3.0, 0.0, 9.0, "01_inicio"], [0.20, 3.0, 0.0, 9.0, "02_tramo"], [0.30, 3.0, 0.0, 9.0, "03_tramo"],
		[0.40, 3.2, 0.0, 9.0, "04_tramo"], [0.50, 3.0, 0.0, 9.0, "05_mitad"], [0.65, 3.0, 0.0, 9.0, "06_tramo"], [0.80, 3.0, 0.0, 9.0, "07_retorno"],
		[0.10, 4.0, 999.0, 0.0, "08_planeta"], [0.22, 14.0, 0.0, 30.0, "09_vista_alta"], [0.45, 4.0, 888.0, 6.0, "10_sol"], [0.92, 3.0, 0.0, 9.0, "11_final"],
		[0.195, 3.5, 0.0, 6.0, "12_portico_marte"], [0.165, 3.5, 0.0, 6.0, "13_portico_luna"], [0.115, 3.5, 0.0, 6.0, "13b_portico_anillo"], [0.30, 60.0, 0.0, 0.0, "14_desde_arriba"]]
	for sh in shots:
		var i := int(float(sh[0]) * float(track.n))
		var p: Vector3 = track.samples[i]
		var tg: Vector3 = track.tangents[i]
		var yaw := atan2(tg.x, tg.z) + deg_to_rad(float(sh[2]))
		var pitch := -8.0 if float(sh[1]) < 6.0 else -18.0 - (float(sh[1]) - 6.0) * 0.1
		if float(sh[2]) == 999.0:
			yaw = atan2(planet_dir.x, planet_dir.z)
			pitch = rad_to_deg(asin(clampf(planet_dir.y, -1.0, 1.0)))
		elif float(sh[2]) == 888.0:
			yaw = atan2(sun_dir.x, sun_dir.z)
			pitch = rad_to_deg(asin(clampf(sun_dir.normalized().y, -1.0, 1.0))) * 0.7
		var back := Vector3(-tg.x, 0, -tg.z).normalized() * float(sh[3])
		cam.position = Vector3(p.x, track.cy[i] + float(sh[1]), p.z) + back
		cam.rotation = Vector3(deg_to_rad(pitch), yaw + PI, 0)
		for k in 6:
			await process_frame
		var img := vp.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, str(sh[4])])
	quit()
