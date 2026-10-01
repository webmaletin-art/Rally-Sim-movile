extends RefCounted
## Opciones de captura y galería de capturas (se muestran dentro de las pantallas de opciones, en el menú y en la pausa).

const Kit := preload("res://game/ui/ui_kit.gd")
const Capture := preload("res://game/capture.gd")

static var page := 0
const PER_PAGE := 6

static func options_block(body: VBoxContainer, profile: RefCounted, sfx: Node, nav: Callable, changed: Callable) -> void:
	var g := Kit.grid(2, 8, 8)
	body.add_child(g)
	var defs := [
		["Botón de captura en la carrera", "capBtn", [true, false], ["Sí", "No"]],
		["Captura con o sin HUD", "capHud", ["keep", "hide"], ["Con HUD", "Sin HUD"]],
		["Calidad de la captura", "capQuality", ["low", "mid", "high"], ["Baja", "Media", "Alta"]],
		["Formato", "capFormat", ["jpg", "png"], ["JPG (liviano)", "PNG (sin pérdida)"]],
	]
	for o in defs:
		var key: String = o[1]
		var vals: Array = o[2]
		var labels: Array = o[3]
		var cur = profile.setting(key)
		if vals.find(cur) < 0:
			cur = vals[0]
		g.add_child(Kit.selector(g.tr(str(o[0])), vals, cur, func(v) -> String: return g.tr(str(labels[vals.find(v)])), func(v) -> void:
			profile.set_setting(key, v)
			changed.call(key), sfx, 62.0))
	var n := Capture.list().size()
	var gb := Kit.button("🖼 GALERÍA  (%d)" % n, func() -> void:
		page = 0
		nav.call("options", "galeria"), true, 20, Vector2(0, 52))
	body.add_child(gb)
	body.add_child(Kit.wrap("Para grabar video: en la pausa tocá «MODO CINE» (se esconde casi todo el HUD) y usá la grabadora de pantalla de tu teléfono.", 12, Kit.MUTED, 300))

static func gallery(body: VBoxContainer, nav: Callable, sfx: Node) -> void:
	var files := Capture.list()
	if files.is_empty():
		body.add_child(Kit.label("Todavía no hay capturas.", 18, Kit.MUTED))
		body.add_child(Kit.wrap("Sacalas con el botón de cámara que aparece arriba a la derecha durante la carrera.", 13, Kit.MUTED, 300))
		return
	var pages := maxi(1, int(ceil(float(files.size()) / float(PER_PAGE))))
	page = clampi(page, 0, pages - 1)
	var g := Kit.grid(3, 8, 8)
	body.add_child(g)
	for i in range(page * PER_PAGE, mini(files.size(), (page + 1) * PER_PAGE)):
		var path: String = files[i]
		var box := Kit.vbox(2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(box)
		var tr_ := TextureRect.new()
		tr_.texture = Capture.thumb(path)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr_.custom_minimum_size = Vector2(0, 92)
		tr_.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(tr_)
		var del := Kit.button("🗑 Borrar", func() -> void:
			sfx.play("click")
			Capture.delete(path)
			nav.call("options", "galeria"), false, 13, Vector2(0, 30))
		box.add_child(del)
	if pages > 1:
		body.add_child(Kit.pager(page, pages, func(pg: int) -> void:
			page = pg
			nav.call("options", "galeria")))
	var pd := Capture.pictures_dir()
	body.add_child(Kit.wrap("Carpeta: %s" % (pd if pd != "" else ProjectSettings.globalize_path(Capture.DIR)), 11, Kit.MUTED, 300))
