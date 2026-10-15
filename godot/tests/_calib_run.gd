## (herramienta) Corre la calibración real (Dream City) como en el teléfono y anota cada paso. Uso: xvfb-run godot --rendering-driver opengl3 -s tests/_calib_run.gd -- --menu --noconsent
extends SceneTree

func _init() -> void:
	_run()

func _run() -> void:
	var app: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	get_root().add_child(app)
	for i in 30:
		await process_frame
	print("[calib] arranca")
	app.start_calibration("home")
	for i in 20:
		await process_frame
	var t0 := Time.get_ticks_msec()
	var last := ""
	while Time.get_ticks_msec() - t0 < 240000:
		await process_frame
		var r: Node = app.get("race")
		if r == null or not is_instance_valid(r):
			print("[calib] la carrera terminó")
			break
		var c: Node = r.get("calib")
		if c != null:
			var st := "%s rung=%d probe=%d frame=%d" % [str(c.get("state")), int(c.get("_rung")), int(c.get("_n_probe")), int(r.frame_rig.level) if r.frame_rig != null else -1]
			if st != last:
				print("[calib] %.1f s %s" % [(Time.get_ticks_msec() - t0) / 1000.0, st])
				last = st
			if str(c.get("state")) == "done":
				print("[calib] terminó: ", c.get("result"))
				c._play()
	for i in 60:
		await process_frame
	print("[calib] FIN")
	quit(0)
