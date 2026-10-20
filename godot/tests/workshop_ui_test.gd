## Taller (20/10/2026, pedido del dueño): el COMPRAR de una pieza (llanta, goma, mejora) está en una franja fija ARRIBA —igual que el APLICAR de la pintura—, no abajo de la lista donde hacía
## falta desplazar; al elegir una pieza la lista se rearma pero queda donde estaba (antes saltaba arriba); y la tarjeta de lo que da cada mejora se lee completa.
## Uso: godot --headless --path godot --script res://tests/workshop_ui_test.gd -- --menu --noconsent
extends SceneTree

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _frames(n := 4) -> void:
	for i in n:
		await process_frame

## Primer descendiente de tipo T
func _first(node: Node, cls: String) -> Node:
	if node.is_class(cls):
		return node
	for c in node.get_children():
		var r := _first(c, cls)
		if r != null:
			return r
	return null

func _buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)

func _text_of(b: Button) -> String:
	var t := b.text
	for c in b.get_children():
		if c is Label:
			t += " " + (c as Label).text
	return t

func _init() -> void:
	_run()

func _run() -> void:
	var ps: PackedScene = load("res://game/main.tscn")
	var app: Node = ps.instantiate()
	get_root().add_child(app)
	await _frames(40)
	# (en headless la ventana mide 64 × 64 y con el aspecto «expand» del proyecto la pantalla virtual sale cuadrada, de 1280 × 1280: las listas no se recortan y no hay nada que desplazar)
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_root().content_scale_size = Vector2i(1280, 576)
	await _frames(4)
	var menu: Node = app.get("menu")
	var profile: RefCounted = menu.get("profile")
	var garage: RefCounted = menu.get("garage")
	profile.credits = 900000
	# ── llantas: elegir una que no es tuya
	garage.ws_tab = 4
	menu.call("go", "workshop", null, false)
	await _frames(6)
	var pinned: Control = menu.get("pinned")
	check(pinned != null and not pinned.visible, "llantas: sin vista previa, la franja de arriba no se ve (no suma espacio)")
	var grid: Node = _first(menu.get("body"), "GridContainer")
	check(grid != null and grid.get_child_count() > 12, "llantas: la lista tiene muchas (%d)" % (grid.get_child_count() if grid != null else 0))
	var sc: ScrollContainer = menu.get("_last_scroll")
	sc.scroll_vertical = 260
	await _frames(2)
	var sv0 := sc.scroll_vertical
	check(sv0 > 50, "llantas: la lista se desplazó (%d)" % sv0)
	var pick: Button = grid.get_child(11) as Button
	pick.pressed.emit()
	await _frames(8)
	pinned = menu.get("pinned")
	var bs: Array = []
	_buttons(pinned, bs)
	var has_buy := false
	for b in bs:
		if _text_of(b as Button).contains("🛒"):
			has_buy = true
	check(pinned.visible and has_buy, "llantas: al elegir una pieza, el COMPRAR queda en la franja fija de arriba (%d botones)" % bs.size())
	sc = menu.get("_last_scroll")
	check(absi(sc.scroll_vertical - sv0) <= 4, "llantas: la lista se rearmó pero quedó donde estaba (%d → %d)" % [sv0, sc.scroll_vertical])
	# ── mejoras: la tarjeta de lo que da la mejora se lee entera (sin recortar a 5 líneas)
	garage.ws_tab = 0
	garage.pv = {}
	menu.call("go", "workshop", null, false)
	await _frames(6)
	var labels: Array = []
	var st: Array = [menu.get("body")]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is Label and (n as Label).autowrap_mode != TextServer.AUTOWRAP_OFF and (n as Label).text.length() > 40:
			labels.append(n)
		st.append_array(n.get_children())
	var cut := 0
	for l in labels:
		if (l as Label).max_lines_visible > 0 or (l as Label).text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS:
			cut += 1
	check(labels.size() >= 1 and cut == 0, "mejoras: el texto de lo que da la mejora no se recorta (%d textos largos, %d cortados)" % [labels.size(), cut])
	# elegir un nivel sin comprar: el COMPRAR y los números van arriba, fijos
	var bs2: Array = []
	_buttons(menu.get("body"), bs2)
	var lvl_btn: Button = null
	for b in bs2:
		var tx := _text_of(b as Button)
		if tx.contains("$") or tx.contains("Kit") or tx.contains("Stage"):
			lvl_btn = b
	if lvl_btn != null:
		lvl_btn.pressed.emit()
		await _frames(6)
		var bs3: Array = []
		_buttons(menu.get("pinned"), bs3)
		var has_buy2 := false
		for b in bs3:
			if _text_of(b as Button).contains("🛒"):
				has_buy2 = true
		check(menu.get("pinned").visible and has_buy2, "mejoras: la vista previa trae el COMPRAR arriba, sin desplazar")
	quit(1 if fail else 0)
