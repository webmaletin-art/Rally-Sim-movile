## Capturas del minimapa y del mapa grande de Dream City: libre y en una carrera del mundo abierto (sólo el circuito). Ver _menu_shots.gd para el comando.
## Uso: xvfb-run -a -s "-screen 0 1290x580x24" godot --rendering-driver opengl3 --resolution 1290x580 --script res://tests/_hud_shots.gd -- --out=/ruta/carpeta
extends SceneTree
const CityTrack := preload("res://game/track/city_track.gd")
const CityHud := preload("res://game/ui/city_hud.gd")
const OwEvents := preload("res://game/world/ow_events.gd")
const CityGps := preload("res://game/city/city_gps.gd")

var out_dir := "user://shots"

func _frames(n := 6) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(6)
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("captura ", name, " ", img.get_size())

func _init() -> void:
	_run()

func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var track = CityTrack.new()
	var hud = CityHud.new()
	hud.setup(track, func(m): pass)
	root.add_child(hud)
	var evs: Array = OwEvents.build(track.region, CityGps.new(track.city))
	var ev: Dictionary = {}
	for e in evs:
		if str(e["id"]) == "circuito_1":
			ev = e
	var pts: PackedVector2Array = ev["pts"]
	hud.car_pos = pts[3]
	hud.heading = atan2(pts[4].x - pts[3].x, pts[4].y - pts[3].y)
	await _frames(4)
	await _shot("hud_free")
	hud.set_course(pts, "Circuito del Puerto")
	hud.course_at(3, true)
	await _frames(4)
	await _shot("hud_course_mini")
	hud._set_big(true)
	await _frames(4)
	await _shot("hud_course_big")
	quit(0)
