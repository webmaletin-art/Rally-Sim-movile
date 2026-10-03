## Mide cuánto le pide cada mapa fantasía al dibujo (llamadas de dibujo, triángulos y objetos por cuadro) desde varios puntos de la vuelta.
## Sirve de presupuesto para teléfonos: ver docs/MAPAS_FANTASIA.md. No mide cuadros por segundo (el xvfb dibuja por software), solo la carga.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 --script res://tests/fantasy_perf.gd -- <mapa> [densidad]
extends SceneTree

const DreamTrack := preload("res://game/track/dream_track.gd")
const DreamWorld := preload("res://game/track/dream_world.gd")
const FantasyWorld := preload("res://game/track/fantasy_world.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id := args[0] if args.size() > 0 else "anillo"
	var dens := float(args[1]) if args.size() > 1 else 0.75
	var view := lerpf(0.6, 1.0, (dens - 0.5) / 0.5) # el mismo alcance de vista que usa el juego según la calidad
	var maps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	var m: Dictionary = maps[map_id]
	var theme := str(m.get("world", "dream"))
	var track := DreamTrack.new(str(m["route"]), str(m["mode"]), false, 0.0)
	track.theme = theme
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 576)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.15
	vp.add_child(sun)
	vp.add_child(cam)
	cam.make_current()
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var world: Node3D
	if theme == "dream":
		DreamWorld.atmosphere(env, sun, cam, vp)
		world = DreamWorld.new()
		world.setup(track, dens, DreamWorld.SUN)
	else:
		FantasyWorld.atmosphere_of(theme, env, sun, cam, vp, view)
		world = FantasyWorld.new()
		world.setup_world(track, dens, theme, view)
	vp.add_child(world)
	var tot_dc := 0
	var tot_pr := 0
	var tot_ob := 0
	var worst_dc := 0
	var worst_pr := 0
	var n := 0
	for k in 24:
		var frac := (float(k) + 0.5) / 24.0
		var i := int(frac * float(track.n))
		var p: Vector3 = track.samples[i]
		var tg: Vector3 = track.tangents[i]
		cam.position = Vector3(p.x, track.cy[i] + 2.6, p.z) - Vector3(tg.x, 0, tg.z) * 7.0
		cam.rotation = Vector3(deg_to_rad(-6.0), atan2(tg.x, tg.z) + PI, 0)
		for f in 5:
			await process_frame
		var dc := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var pr := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		var ob := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		tot_dc += dc
		tot_pr += pr
		tot_ob += ob
		worst_dc = maxi(worst_dc, dc)
		worst_pr = maxi(worst_pr, pr)
		n += 1
	print("PERF %s dens=%.2f vista=%.2f · llamadas de dibujo: media %d, máx %d · triángulos: media %dk, máx %dk · objetos: media %d" % [map_id, dens, view, tot_dc / n, worst_dc, tot_pr / n / 1000, worst_pr / 1000, tot_ob / n])
	quit()
