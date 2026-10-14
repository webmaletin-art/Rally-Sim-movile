## Menú premium (garaje · taller · tienda): el marco (barra superior, riel, carrusel, especificaciones) arma lo que corresponde, cada botón hace lo mismo que antes
## y la cámara libre responde a toques en todas las pantallas con el auto.
## Uso: godot --headless --path godot --script res://tests/menu_ui_test.gd -- --menu --noconsent
extends SceneTree

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _frames(n := 4) -> void:
	for i in n:
		await process_frame

func _init() -> void:
	_run()

func _run() -> void:
	var ps: PackedScene = load("res://game/main.tscn")
	var app: Node = ps.instantiate()
	get_root().add_child(app)
	await _frames(40)
	var menu: Node = app.get("menu")
	check(menu != null, "el menú arrancó")
	var profile: RefCounted = menu.get("profile")
	var chrome: RefCounted = menu.get("chrome")
	var garage: RefCounted = menu.get("garage")
	var Kit: GDScript = load("res://game/ui/ui_kit.gd")
	# ── inicio: esquina con dinero y nivel, sin marco de garaje
	menu.call("go", "home")
	await _frames()
	check(not bool(menu.get("chrome_on")) and chrome.top != null, "inicio: sin marco de garaje, con el dinero y el nivel en la esquina")
	check(chrome.money_l.text == Kit.fmt_cr(float(profile.credits)), "inicio: el dinero de la esquina es el del perfil")
	# ── garaje
	menu.call("go", "garage")
	await _frames()
	check(bool(menu.get("chrome_on")) and chrome.top != null and chrome.rail != null and chrome.bottom != null, "garaje: barra superior, riel y carrusel")
	var owned := 0
	for id in profile.d["owned"]:
		owned += 1
	check(chrome.cards.size() == owned, "garaje: una tarjeta por auto propio (%d)" % chrome.cards.size())
	check(chrome.money_l.text == Kit.fmt_cr(float(profile.credits)), "garaje: el dinero de la barra es el del perfil")
	# elegir otro auto en el carrusel
	if chrome.cards.size() > 1:
		var before: int = int(garage.mine_i)
		var target: int = (before + 1) % chrome.cards.size()
		(chrome.cards[target] as Button).pressed.emit()
		await _frames()
		check(int(garage.mine_i) == target and menu.get("screen") == "garage", "garaje: tocar una tarjeta elige ese auto")
		check(String(menu.get("showroom").shown_id) != "", "garaje: la sala muestra el auto elegido")
	# riel: PIEZAS … ESTÉTICA abren la pestaña del taller de siempre (RIEL: atrás, separador, mis autos, compra autos, 6 pestañas)
	var rail_kids: Array = chrome.rail.get_children()
	check(rail_kids.size() == 10, "garaje: el riel tiene atrás, separador, 2 autos y 6 pestañas del taller (%d)" % rail_kids.size())
	for k in 6:
		menu.call("go", "garage")
		await _frames()
		var rk: Array = chrome.rail.get_children()
		(rk[4 + k] as Button).pressed.emit()
		await _frames()
		check(menu.get("screen") == "workshop" and int(garage.ws_tab) == k, "riel: la pestaña %d del taller abre el taller en esa pestaña" % k)
		check(chrome.bottom == null and chrome.rail != null, "taller %d: sin carrusel, con riel compacto" % k)
	# Carrera rápida: la pantalla que agrupa la práctica (pistas, mundo abierto, Travesía X, Rutas, fantasía)
	menu.call("go", "quickhub")
	await _frames()
	var qh_tiles := 0
	var st3: Array = [menu.get("body")]
	while not st3.is_empty():
		var n3: Node = st3.pop_back()
		if n3 is Label and str((n3 as Label).text) in ["PISTAS Y MAPAS", "MUNDO ABIERTO", "TRAVESÍA X", "RUTAS", "MAPAS FANTASÍA"]:
			qh_tiles += 1
		st3.append_array(n3.get_children())
	check(menu.get("screen") == "quickhub" and qh_tiles == 5, "Carrera rápida agrupa pistas, mundo abierto, Travesía X, Rutas y fantasía (%d)" % qh_tiles)
	# taller → Pintura: interior, volante y diseños exclusivos (cosméticos que se compran)
	for tgt in ["interior", "steer", "body"]:
		garage.ws_tab = 3
		garage.paint_target = tgt
		garage.cos_pick = {"interior": "cab_carbono", "steer": "vol_pro", "body": "st_llamas"}[tgt]
		menu.call("go", "workshop", null, false)
		await _frames()
		var buy_found := false
		var st2: Array = [menu.get("body")]
		while not st2.is_empty():
			var n2: Node = st2.pop_back()
			if n2 is Button and (n2 as Button).text.begins_with("🛒"):
				buy_found = true
			st2.append_array(n2.get_children())
		check(menu.get("screen") == "workshop" and buy_found, "taller → Pintura → %s: lista y barra de COMPRAR" % tgt)
	garage.cos_pick = ""
	garage.paint_target = "body"
	# tienda (compra de autos) desde el riel
	menu.call("go", "workshop", 0)
	await _frames()
	var rk2: Array = chrome.rail.get_children()
	(rk2[3] as Button).pressed.emit()
	await _frames()
	check(menu.get("screen") == "dealer" and chrome.cards.size() >= 12, "riel: COMPRA AUTOS abre la tienda con todos los autos (%d)" % chrome.cards.size())
	# ATRÁS vuelve
	menu.call("go", "home")
	await _frames()
	menu.call("go", "garage")
	await _frames()
	((chrome.rail.get_children())[0] as Button).pressed.emit()
	await _frames()
	check(menu.get("screen") == "home", "riel: ATRÁS vuelve al inicio")
	# ── Acerca de y Opciones → Sonido: el botón «COPIAR REGISTRO» está (sin modo desarrollador) y copia el informe
	for dest in [["about", null], ["options", "sonido"]]:
		menu.call("go", dest[0], dest[1])
		await _frames()
		var found: Button = null
		var stack: Array = [menu.get("body")]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			var txt := (n as Button).text if n is Button else ((n as Label).text if n is Label else "")
			if txt.contains("COPIAR REGISTRO") or txt.begins_with("🪲"): # (el botón de Opciones va traducido al idioma del teléfono)
				var up: Node = n
				while up != null and not (up is Button):
					up = up.get_parent()
				found = up
			stack.append_array(n.get_children())
		check(found != null, "«COPIAR REGISTRO» visible en %s" % str(dest))
		if found != null:
			DisplayServer.clipboard_set("")
			found.pressed.emit()
			await _frames(2)
			check(DisplayServer.clipboard_get().contains("DREAM RACING · registro") or DisplayServer.get_name() == "headless", "«COPIAR REGISTRO» copia el informe (%s)" % str(dest))
	# ── cámara libre: un arrastre sobre el auto la activa en todas las pantallas con el auto
	var sr: Node3D = menu.get("showroom")
	var win := Vector2(get_root().size)
	for sc in ["home", "garage", "dealer", "workshop"]:
		menu.call("go", sc)
		await _frames()
		var y0: float = sr.f_yaw
		var p := Vector2(win.x * 0.82, win.y * 0.5)
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = p
		t.pressed = true
		Input.parse_input_event(t)
		for k in 5:
			var dr := InputEventScreenDrag.new()
			dr.index = 0
			dr.position = p + Vector2(18.0 * float(k + 1), 0)
			dr.relative = Vector2(18, 0)
			Input.parse_input_event(dr)
			await process_frame
		t = InputEventScreenTouch.new()
		t.index = 0
		t.position = p + Vector2(100, 0)
		t.pressed = false
		Input.parse_input_event(t)
		await process_frame
		check(sr.free and not is_equal_approx(y0, sr.f_yaw), "cámara libre: arrastrar sobre el auto gira la cámara en «%s»" % sc)
	quit(1 if fail else 0)
