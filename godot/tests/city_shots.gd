## Capturas de Dream City desde varios puntos (xvfb + OpenGL): arma la pista de la ciudad, el mundo por cuadras y un cielo de día.
## Uso: xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 1280x720 --script res://tests/city_shots.gd -- /carpeta [vista 0.6..1]
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityWorld := preload("res://game/city/city_world.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/city_shots"
	var view := float(args[1]) if args.size() > 1 else 1.0
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_msec()
	var track := CityTrack.new()
	print("ciudad en %d ms" % (Time.get_ticks_msec() - t0))
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.40, 0.62, 0.90)
	psm.sky_horizon_color = Color(0.86, 0.90, 0.95)
	psm.ground_horizon_color = Color(0.80, 0.84, 0.86)
	sky.sky_material = psm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.82, 0.87, 0.92)
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 160.0 * view
	env.fog_depth_end = 560.0 * view
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.96, 0.88)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 66.0
	cam.near = 0.15
	cam.far = 3000.0
	vp.add_child(cam)
	cam.make_current()
	var world: CityWorld = track.build_world()
	world.view_k = view
	vp.add_child(world)
	# [nombre, x, z, yaw (grados: 0 = mirando al sur, +z), alto sobre el suelo, cabeceo]
	var shots: Array = [["00_plaza", 0.0, 30.0, 0.0, 3.0, -4.0], ["01_avenida3_sur", 0.0, 180.0, 0.0, 3.0, -4.0], ["02_avenida7_norte", 0.0, -220.0, 180.0, 3.0, -4.0],
		["03_avenida1_este", 330.0, 0.0, -90.0, 3.2, -4.0], ["04_centro_alto", 40.0, -80.0, 0.0, 60.0, -28.0], ["05_anillo", 400.0, 160.0, 140.0, 3.0, -4.0],
		["06_costanera", 0.0, 1100.0, 90.0, 3.0, -3.0], ["07_colina_sube", -860.0, -780.0, 200.0, 3.0, -4.0], ["08_colina_alto", -900.0, -900.0, 45.0, 30.0, -10.0],
		["09_ruta_este", 1500.0, 0.0, -90.0, 3.0, -3.0], ["10_barrio", -520.0, 380.0, 60.0, 3.0, -4.0], ["11_plaza_alto", 0.0, 120.0, 0.0, 120.0, -45.0],
		["12_casco_viejo", 305.0, 563.0, 64.0, 2.6, -3.0], ["13_casco_viejo_b", 198.0, 609.0, 23.0, 2.6, -3.0], ["14_casco_alto", 330.0, 600.0, 28.0, 45.0, -30.0], ["15_atajo", 1330.0, 100.0, 80.0, 3.0, -3.0], ["16_vacio_a", 109.0, -330.0, 180.0, 70.0, -55.0], ["17_vacio_b", -56.0, 290.0, 180.0, 70.0, -55.0], ["18_barrio_alto", -520.0, 380.0, 60.0, 60.0, -40.0], ["19_zenit", -520.0, 380.0, 0.0, 160.0, -89.0], ["20_grilla", -540.0, 200.0, 60.0, 3.0, -3.0], ["21_parque", 178.0, 128.0, 180.0, 3.0, -3.0], ["22_afueras", 0.0, 940.0, 180.0, 3.0, -3.0], ["23_parque_alto", 178.0, 150.0, 180.0, 70.0, -50.0], ["24_plaza_alto", 0.0, 100.0, 180.0, 60.0, -45.0], ["25_ruta_borde", 1600.0, 56.0, 87.0, 2.6, -2.0], ["26_salida", 2255.0, -37.0, 93.0, 2.6, -2.0], ["27_atajo_borde", 1330.0, 100.0, 80.0, 3.0, -2.0]]
	var pk := Vector2(cos(deg_to_rad(22.5)), sin(deg_to_rad(22.5))) * 195.0
	shots.append(["40_tunel_recto", 5550.0, 30.0, 90.0, 1.9, -2.0])
	shots.append(["41_tunel_cruce", 5930.0, 0.0, 90.0, 1.9, -2.0])
	shots.append(["42_tunel_alto", 5900.0, 0.0, 90.0, 5.2, -22.0])
	shots.append(["43_sala", 6000.0, 2985.0, 0.0, 1.9, -2.0])
	shots.append(["44_sala_alto", 6000.0, 2962.0, 0.0, 4.5, -30.0])
	shots.append(["45_boca_este", 1150.0, 22.0, 180.0, 2.6, -2.0])
	shots.append(["46_boca_parque", pk.x + 18.0, pk.y, -90.0, 2.6, -2.0])
	var ns := 0
	for pp in track.city.pois:
		if str(pp["shop"]) == "" or ns >= 4:
			continue
		ns += 1
		var fr: Vector2 = pp["front"]
		var ty := float(pp["road_yaw"])
		var cam_p := fr - Vector2(sin(ty), cos(ty)) * 13.0
		var dv: Vector2 = (pp["door"] as Vector2) - cam_p
		shots.append(["30_local_%s" % str(pp["id"]), cam_p.x, cam_p.y, rad_to_deg(atan2(dv.x, dv.y)), 2.8, -3.0])
	for sh in shots:
		var x := float(sh[1])
		var z := float(sh[2])
		var gy: float = track.ground_info(x, z).x
		cam.position = Vector3(x, gy + float(sh[4]), z)
		cam.rotation = Vector3(deg_to_rad(float(sh[5])), deg_to_rad(float(sh[3])) + PI, 0)
		world.warm(cam.position)
		for k in 6:
			await process_frame
		var info := world.stats()
		var img := vp.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, str(sh[0])])
		print("%s · cuadras %d · triángulos en memoria %dk · llamadas %d · triángulos dibujados %dk" % [str(sh[0]), info["chunks"], int(info["tris"]) / 1000,
			int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)) / 1000])
	quit()
