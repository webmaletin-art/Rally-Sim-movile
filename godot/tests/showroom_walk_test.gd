extends SceneTree
## Caminatas de Mixamo en el menú: corre el showroom un rato, cuenta qué clips sonaron, que nadie atraviese el auto y saca capturas de la vuelta al auto.
## uso: xvfb-run godot --path godot --script res://tests/showroom_walk_test.gd -- [carpeta_capturas]
const Showroom := preload("res://game/ui/showroom.gd")
const MixamoClips := preload("res://game/car/mixamo_clips.gd")

func _init() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 560)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var sr: Node3D = Showroom.new()
	vp.add_child(sr)
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	sr.set_car(str(vehicles.keys()[0]), {}, vehicles)
	print("clips disponibles: ", MixamoClips.available(), " circle ", MixamoClips.has_clip("Walk_In_Circle"))
	if OS.get_cmdline_user_args().has("--lean"):
		await _lean_check(sr, vp, out)
		quit()
		return
	var seen := {}
	var kinds := {}
	var inside := 0
	var shots := 0
	var frames := 0
	var tmax := 240.0
	var sim := 0.0
	var last := Time.get_ticks_msec()
	while sim < tmax:
		await process_frame
		var nowm := Time.get_ticks_msec()
		var dt := float(nowm - last) / 1000.0
		last = nowm
		frames += 1
		sim += dt
		for i in 2:
			var c: Dictionary = sr.crew[i]
			var st: Dictionary = c["step"]
			if not st.is_empty():
				kinds[str(st["t"])] = int(kinds.get(str(st["t"]), 0)) + 1
			var mp: String = str(c["mx_pose"])
			if mp != "":
				seen[mp] = true
			var p: Vector3 = (c["node"] as Node3D).position
			if absf(p.x) < 0.95 and absf(p.z) < sr.car_len * 0.5 - 0.1:
				inside += 1
			if not st.is_empty() and str(st["t"]) == "circle" and out != "" and shots < 3 and sim > 0.0 and frames % 90 == 0:
				vp.get_texture().get_image().save_png(out + "/circle_%d.png" % shots)
				shots += 1
	print("frames ", frames, " sim ", snappedf(sim, 0.1))
	print("pasos ", kinds)
	print("clips vistos ", seen.keys())
	print("frames dentro del auto ", inside)
	quit()

## Recostarse sólo contra el auto: fuerza la secuencia, y verifica que la espalda quede en la chapa (a unos 5 cm adentro) y que ahí se vea apoyado
func _lean_check(sr: Node3D, vp: SubViewport, out: String) -> void:
	for round in 3:
		sr.crew[0]["queue"] = []
		sr.crew[0]["step"] = {}
		sr.crew[1]["step"] = {}
		sr.crew[1]["queue"] = sr._lean_steps(1, 6.0)
		var n := 0
		var shot := false
		var t0 := Time.get_ticks_msec()
		while (not sr.crew[1]["queue"].is_empty() or not sr.crew[1]["step"].is_empty()) and Time.get_ticks_msec() - t0 < 60000:
			await process_frame
			var st: Dictionary = sr.crew[1]["step"]
			if not st.is_empty() and str(st.get("pose", "")) == "lean" and float(sr.crew[1]["t"]) > 3.0 and not shot:
				var nd: Node3D = sr.crew[1]["node"]
				var hw: float = sr.car.phys.V.trackF * 0.5 + 0.12
				print("recostado con ", st["clip"], ": x del personaje ", snappedf(nd.position.x, 0.01), " z ", snappedf(nd.position.z, 0.01), " yaw ", snappedf(rad_to_deg(nd.rotation.y), 1.0), " semiancho auto ", snappedf(hw, 0.01))
				if out != "":
					vp.get_texture().get_image().save_png(out + "/lean_%d.png" % round)
				shot = true
			n += 1
		print("secuencia ", round, " terminada en ", n, " cuadros, apoyó: ", shot)
