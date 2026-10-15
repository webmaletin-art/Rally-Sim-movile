## (herramienta) Captura de la pantalla «CALIDAD GRÁFICA» y elección de una calidad. Uso: xvfb-run godot --rendering-driver opengl3 -s tests/_pick_shot.gd -- --menu --noconsent salida.png
extends SceneTree

func _find_btn(n: Node, needle: String) -> Button:
	if n is Button and (n as Button).text.begins_with(needle):
		return n as Button
	for c in n.get_children():
		var r := _find_btn(c, needle)
		if r != null:
			return r
	return null

func _init() -> void:
	_run()

func _run() -> void:
	var app: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	get_root().add_child(app)
	for i in 40:
		await process_frame
	app.menu.request_calibration("home")
	for i in 10:
		await process_frame
	var out := str(OS.get_cmdline_user_args()[-1])
	get_root().get_texture().get_image().save_png(out)
	var b := _find_btn(app.menu, "NORMAL")
	print("[pick] botón NORMAL: ", b != null)
	if b != null:
		b.pressed.emit()
	for i in 5:
		await process_frame
	print("[pick] perfil: ", app.profile.setting("gfx").get("profile"), " · escala 3D ", app.profile.setting("autoRes"), " · pendiente: ", preload("res://game/autotune.gd").pending(app.profile))
	quit(0)
