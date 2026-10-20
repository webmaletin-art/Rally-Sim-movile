## Capturas de las pantallas del menú (para revisar a ojo cómo se ven textos, tarjetas y botones sin un teléfono): arranca el juego en una pantalla virtual y guarda un PNG por pantalla.
## Uso: xvfb-run -a -s "-screen 0 1290x580x24" godot --rendering-driver opengl3 --resolution 1290x580 --script res://tests/_menu_shots.gd -- --menu --noconsent --out=/ruta/carpeta
extends SceneTree

var out_dir := "user://shots"

func _frames(n := 6) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(8)
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
	var ps: PackedScene = load("res://game/main.tscn")
	var app: Node = ps.instantiate()
	get_root().add_child(app)
	await _frames(40)
	var menu: Node = app.get("menu")
	var profile: RefCounted = menu.get("profile")
	var list := [
		["home", null], ["options", null], ["options", "graficos"], ["options", "sonido"], ["options", "controles"], ["options", "camara"], ["options", "efectos"], ["options", "idioma"],
		["about", null], ["iap", null], ["career", null], ["quickhub", null], ["quick", null], ["online", null], ["adventure", null], ["goals", null],
	]
	for it in list:
		var nm: String = it[0] if it[1] == null else "%s_%s" % [it[0], it[1]]
		menu.call("go", it[0], it[1])
		await _shot(nm)
	quit(0)
