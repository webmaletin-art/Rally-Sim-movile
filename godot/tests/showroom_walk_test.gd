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
	var seen := {}
	var kinds := {}
	var inside := 0
	var shots := 0
	var frames := 0
	var tmax := 150.0
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
