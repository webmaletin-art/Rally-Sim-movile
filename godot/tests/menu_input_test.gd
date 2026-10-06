extends SceneTree
## Cámara libre del menú con toques/mouse reales (Input.parse_input_event pasa por toda la cadena de entrada, como en el teléfono).
## uso: xvfb-run godot --path godot --script res://tests/menu_input_test.gd -- [--screen=garage]
func _init() -> void:
	var ps: PackedScene = load("res://game/main.tscn")
	var app: Node = ps.instantiate()
	get_root().add_child(app)
	print("cargado")
	for i in 60:
		await process_frame
	var menu: Node = app.get("menu")
	print("menu ", menu, " screen ", menu.get("screen"))
	var sr: Node = menu.get("showroom")
	var win := Vector2(get_root().size)
	print("ventana ", win)
	var pts := [Vector2(win.x * 0.8, win.y * 0.5), Vector2(win.x * 0.2, win.y * 0.5)]
	for p in pts:
		var y0: float = sr.f_yaw
		var d0: float = sr.f_dist
		# toque + arrastre (como en Android)
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = p
		t.pressed = true
		Input.parse_input_event(t)
		for k in 6:
			var dr := InputEventScreenDrag.new()
			dr.index = 0
			dr.position = p + Vector2(20 * (k + 1), 0)
			dr.relative = Vector2(20, 0)
			Input.parse_input_event(dr)
			await process_frame
		t = InputEventScreenTouch.new()
		t.index = 0
		t.position = p + Vector2(120, 0)
		t.pressed = false
		Input.parse_input_event(t)
		await process_frame
		print("toque en ", p, " yaw ", y0, " -> ", sr.f_yaw, " libre ", sr.free)
		# rueda
		var mb := InputEventMouseButton.new()
		mb.position = p
		mb.button_index = MOUSE_BUTTON_WHEEL_UP
		mb.pressed = true
		Input.parse_input_event(mb)
		await process_frame
		print("rueda en ", p, " dist ", d0, " -> ", sr.f_dist)
	quit()
