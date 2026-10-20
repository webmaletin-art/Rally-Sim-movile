## MODO DE PRUEBA en el menú ([B] 20/10/2026, pedido del dueño): la baldosa del inicio (después de la configuración gráfica automática y hasta que se use), la guía antes de entrar
## (con la voz de Claudio y subtítulos), las hojas con dibujos, el armado (auto, nivel de simulación, drift o carrera, ayuda de reglaje) y la configuración que se larga.
## Uso: godot --headless --path godot --script res://tests/test_menu_test.gd -- --menu --noconsent
extends SceneTree

const Autotune := preload("res://game/autotune.gd")
const MenuTest := preload("res://game/ui/menu_test.gd")
const Tr := preload("res://game/i18n/tr.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _frames(n := 4) -> void:
	for i in n:
		await process_frame

func _all_text(node: Node, out: Array) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for c in node.get_children():
		_all_text(c, out)

func _buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)

func _text_of(b: Button) -> String:
	var parts: Array = [b.text]
	for c in b.get_children():
		_collect(c, parts)
	return " ".join(parts)

func _collect(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collect(c, out)

func _has_text(node: Node, needle: String) -> bool:
	var txt: Array = []
	_all_text(node, txt)
	for t in txt:
		if str(t).contains(needle):
			return true
	return false

## Busca un botón por parte de su texto (en toda la pantalla del menú)
func _btn(root_node: Node, needle: String) -> Button:
	var bs: Array = []
	_buttons(root_node, bs)
	for b in bs:
		if _text_of(b).contains(needle) and b.is_visible_in_tree():
			return b
	return null

## Busca un botón cuyo texto es exactamente éste
func _btn_exact(root_node: Node, text: String) -> Button:
	var bs: Array = []
	_buttons(root_node, bs)
	for b in bs:
		if (b as Button).text == text and b.is_visible_in_tree():
			return b
	return null

func _init() -> void:
	_run()

func _run() -> void:
	var ps: PackedScene = load("res://game/main.tscn")
	var app: Node = ps.instantiate()
	get_root().add_child(app)
	await _frames(40)
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	get_root().content_scale_size = Vector2i(1280, 576)
	await _frames(4)
	Tr.set_language("es") # (los textos se buscan en español: en la compilación de pruebas el idioma sale del sistema)
	var menu: Node = app.get("menu")
	var profile: RefCounted = menu.get("profile")
	var saved_state: Variant = (profile.d.get("testMode") as Dictionary).duplicate(true) if profile.d.get("testMode") is Dictionary else null
	var saved_gfx: Variant = profile.d["settings"].get("gfx")
	var saved_guide: Variant = profile.d["settings"].get("guideMode")
	profile.d.erase("testMode")
	profile.d["settings"]["gfx"] = {}
	# ── 1) sin la configuración gráfica automática no hay baldosa
	check(Autotune.pending(profile) and not MenuTest.available(profile), "sin configuración gráfica automática: la prueba todavía no está disponible")
	menu.call("go", "home", null, false)
	await _frames(6)
	check(not _has_text(menu.get("body"), "MODO DE PRUEBA"), "inicio: sin baldosa de prueba antes de la configuración gráfica")
	# ── 2) con la configuración hecha aparece al lado de Aventura y Modo online
	profile.d["settings"]["gfx"] = {"locked": true, "version": Autotune.VERSION, "sig": Autotune.device_sig(), "auto": {}}
	menu.set("calib_prompted", true)
	check(MenuTest.available(profile), "con la configuración gráfica hecha: la prueba está disponible")
	menu.call("go", "home", null, false)
	await _frames(6)
	var body: Node = menu.get("body")
	var tile: Button = _btn(body, "MODO DE PRUEBA")
	check(tile != null, "inicio: baldosa «MODO DE PRUEBA»")
	check(_btn(body, "AVENTURA") != null and _btn(body, "MODO ONLINE") != null, "…junto a AVENTURA y MODO ONLINE")
	var row: Node = tile.get_parent() if tile != null else null
	check(row != null and _btn(row, "AVENTURA") != null and _btn(row, "MODO ONLINE") != null, "las tres están en la misma fila")
	# ── 3) la guía antes de entrar
	tile.pressed.emit()
	await _frames(6)
	check(menu.get("screen") == "test_guide", "la baldosa abre la guía")
	body = menu.get("body")
	var g: Node = menu.call("guide_voice")
	check(g != null and g.heard.has("welcome"), "la guía da la bienvenida (voz y subtítulo)")
	check(_has_text(body, "UNA sola vez") or _has_text(body, "una sola vez"), "avisa que la prueba se usa una sola vez")
	check(_btn(body, "LEER LA GUÍA") != null and _btn(body, "IR A LA PRUEBA") != null, "botones: LEER LA GUÍA e IR A LA PRUEBA")
	var vb: Button = _btn(body, "GUÍA:")
	check(vb != null and g.mode == "full", "botón de la voz: «%s»" % (vb.text if vb != null else "—"))
	vb.pressed.emit() # voz y texto → sólo texto
	check(g.mode == "text" and profile.setting("guideMode") == "text", "un toque: sólo texto (se guarda en el perfil)")
	vb = _btn(menu.get("body"), "GUÍA:")
	vb.pressed.emit()
	check(g.mode == "off" and profile.setting("guideMode") == "off", "otro toque: guía apagada")
	vb = _btn(menu.get("body"), "GUÍA:")
	vb.pressed.emit()
	check(g.mode == "full", "y vuelve a voz y texto")
	# ── 4) las hojas
	_btn(menu.get("body"), "LEER LA GUÍA").pressed.emit()
	await _frames(6)
	check(menu.get("screen") == "test_pages", "LEER LA GUÍA abre las hojas")
	var slides: Node = null
	for c in _descendants(menu.get("body")):
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("guide_slides.gd"):
			slides = c
	check(slides != null and slides.count() == 10, "diez hojas de guía (%d)" % (slides.count() if slides != null else 0))
	var next_b: Button = _btn(menu.get("body"), "ADELANTE")
	var prev_b: Button = _btn(menu.get("body"), "ATRÁS")
	next_b.pressed.emit()
	check(slides.index == 1 and _has_text(menu.get("body"), "2 / 10"), "ADELANTE pasa a la hoja 2 de 10")
	prev_b.pressed.emit()
	prev_b.pressed.emit()
	check(slides.index == 9, "ATRÁS desde la primera da la vuelta a la última")
	# ── 5) el armado
	menu.call("go", "test_setup", null, true)
	await _frames(6)
	body = menu.get("body")
	check(menu.get("screen") == "test_setup" and g.heard.has("setup_welcome"), "ARMÁ TU PRUEBA: la guía explica qué elegir")
	for nm in ["CAMIONETA", "GT", "CLÁSICO", "SUPERDEPORTIVO"]:
		check(_btn(body, nm) != null, "auto de prueba: " + nm)
	for nm in ["ARCADE", "INTERMEDIO", "SIMULADOR TOTAL", "PERSONALIZADO"]:
		check(_btn(body, nm) != null, "nivel de simulación: " + nm)
	check(_btn(body, "DRIFT POR PUNTOS") != null and _btn(body, "DRIFT LIBRE") != null, "qué hacer: drift por puntos o libre")
	check(_btn(body, "CARRERA · CAMINO DE TIERRA") != null and _btn(body, "CARRERA · ENTRE EDIFICIOS") != null, "qué hacer: carrera por el camino de tierra o entre los edificios")
	check(_btn(body, "AYUDA DE REGLAJE") != null and _btn(body, "CALIDAD GRÁFICA") != null, "ayuda de reglaje y calidad gráfica")
	var pin: Node = menu.get("pinned")
	check(pin != null and pin.visible and _btn(pin, "EMPEZAR LA PRUEBA") != null, "EMPEZAR LA PRUEBA queda fijo arriba (se ve sin desplazar)")
	_btn(body, "CAMIONETA").pressed.emit()
	await _frames(4)
	var st := MenuTest.setup_of(profile)
	check(st["car"] == "pickup" and g.heard.has("car_pickup"), "elegir la camioneta: se guarda y la guía la presenta")
	_btn(menu.get("body"), "SIMULADOR TOTAL").pressed.emit()
	await _frames(4)
	check(profile.setting("simLevel") == "pro" and g.heard.has("sim_pro"), "elegir simulador total: queda como nivel y la guía lo explica")
	_btn(menu.get("body"), "DRIFT LIBRE").pressed.emit()
	await _frames(4)
	check(MenuTest.setup_of(profile)["score"] == "free" and g.heard.has("score_free"), "drift libre")
	_btn(menu.get("body"), "AYUDA DE REGLAJE").pressed.emit() # ayuda de reglaje: SÍ → NO
	await _frames(4)
	check(MenuTest.setup_of(profile)["lab"] == false and g.heard.has("lab_off"), "ayuda de reglaje: NO (se guarda como verdadero/falso)")
	_btn(menu.get("body"), "CARRERA · ENTRE EDIFICIOS").pressed.emit()
	await _frames(4)
	st = MenuTest.setup_of(profile)
	check(st["mode"] == "race" and st["loop"] == "urban" and g.heard.has("mode_race") and g.heard.has("loop_urban"), "carrera entre edificios elegida (y la guía la explica)")
	# ── 6) la configuración que se larga
	var cfg := MenuTest.build_cfg(st)
	var ts: Dictionary = cfg["testSetup"]
	check(cfg["type"] == "test" and cfg["track"] == "pruebas" and cfg["car"] == "pickup" and cfg["ai"] == 0, "configuración: tipo test, pista pruebas, camioneta, sin rivales")
	check(ts["mode"] == "race" and ts["loop"] == "urban" and ts["lab"] == false and float(ts["tank"]) == 1.0, "configuración de la prueba: carrera, entre edificios, sin ayuda de reglaje, tanque lleno")
	var cfg2 := MenuTest.build_cfg(MenuTest.default_setup())
	check(cfg2["ai"] == 4 and cfg2["car"] == "gt" and cfg2["testSetup"]["lab"] == true, "por defecto: drift con cuatro autos, GT y ayuda de reglaje")
	# ── 7) una sola vez
	MenuTest.mark_done(profile)
	check(not MenuTest.available(profile), "al salir de la prueba deja de estar disponible")
	menu.call("go", "test_guide", null, false)
	await _frames(4)
	check(menu.get("screen") == "test_guide" and not _has_text(menu.get("body"), "LEER LA GUÍA"), "no se puede volver a entrar (la pantalla cae al inicio)")
	menu.call("go", "home", null, false)
	await _frames(6)
	check(not _has_text(menu.get("body"), "MODO DE PRUEBA"), "inicio: la baldosa desapareció")
	check(g.heard.has("exit_done"), "el menú se despide con la guía una sola vez")
	# restaurar el perfil de la prueba
	if saved_state != null:
		profile.d["testMode"] = saved_state
	else:
		profile.d.erase("testMode")
	profile.d["settings"]["gfx"] = saved_gfx if saved_gfx != null else {}
	if saved_guide != null:
		profile.d["settings"]["guideMode"] = saved_guide
	else:
		profile.d["settings"].erase("guideMode")
	profile.save()
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)

func _descendants(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_descendants(c))
	return out
