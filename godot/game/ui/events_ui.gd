extends Control
## Pantalla de EVENTOS (pausa → 📅 EVENTOS). [B] 19/10/2026, pedido del dueño: «los eventos no van como letras en la pantalla de juego: un menú lindo, con una imagen de cada
## evento, donde entro, miro, y si quiero voy al evento (el GPS me guía) o no; si salgo para atrás no me queda nada en la pantalla; sólo un puntito de notificación».
## Tres solapas: EVENTOS (lista de tarjetas con imagen + detalle con premios, cómo vas y los botones «IR AL EVENTO» / «SALIR DEL EVENTO»), NOVEDADES (lo que pasó: quién ganó,
## premios, avisos) y AYUDA. Los datos los da city_modes.gd (event_cards / notes); acá sólo se dibuja. Se prueba con tests/events_ui_test.gd.

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const Tr := preload("res://game/i18n/tr.gd")

signal closed
signal go_pressed(id: int)
signal cancel_pressed(id: int)

const KIND_COL := {"bounty": Color(0.95, 0.35, 0.3), "escape": Color(0.35, 0.55, 1.0), "reach": Color(0.3, 0.85, 0.55), "record": Color(1.0, 0.72, 0.2), "drift": Color(0.55, 0.85, 1.0), "season": Color(0.9, 0.5, 1.0)}

var cards_fn: Callable # → Array de tarjetas (city_modes.event_cards)
var notes_fn: Callable # → Array de {t, text, new}
var seen_fn: Callable # se llama al abrir: marca todo como visto (se apaga el puntito)
var help_fn: Callable # → String
var tab := "eventos"
var sel := -1 # id del evento elegido
var _new_ids := {} # eventos que eran nuevos al abrir (llevan su puntito dentro de la pantalla)
var _cards: Array = []
var _notes_new := false
var _body: Control
var _msg := ""
static var _tex_cache := {}

func _init() -> void:
	visible = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

## La imagen de un tipo de evento (una captura del juego por tipo; si falta, la genérica)
static func image_for(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind]
	var p := "res://game/ui/events/%s.jpg" % kind
	if not ResourceLoader.exists(p):
		p = "res://game/ui/events/default.jpg"
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_tex_cache[kind] = t
	return t

static func car_thumb(id: String) -> Texture2D:
	if id == "":
		return null
	var p := "res://game/ui/thumbs/%s.png" % id
	return load(p) if ResourceLoader.exists(p) else null

func open(start_tab := "eventos") -> void:
	tab = start_tab
	_msg = ""
	_cards = _get_cards()
	_new_ids = {}
	for c in _cards:
		if bool(c.get("new", false)):
			_new_ids[int(c["id"])] = true
	_notes_new = false
	for n in _get_notes():
		if bool(n.get("new", false)):
			_notes_new = true
	if sel < 0 or not _has(sel):
		sel = int(_cards[0]["id"]) if not _cards.is_empty() else -1
	if seen_fn.is_valid():
		seen_fn.call()
	visible = true
	_rebuild()

func close() -> void:
	visible = false
	closed.emit()

func _has(id: int) -> bool:
	for c in _cards:
		if int(c["id"]) == id:
			return true
	return false

func _get_cards() -> Array:
	var r: Variant = cards_fn.call() if cards_fn.is_valid() else []
	return r if r is Array else []

func _get_notes() -> Array:
	var r: Variant = notes_fn.call() if notes_fn.is_valid() else []
	return r if r is Array else []

## Se llama cuando cambian los datos (una acción del jugador): vuelve a dibujar sin cerrar
func refresh(msg := "") -> void:
	_msg = msg
	_cards = _get_cards()
	if sel >= 0 and not _has(sel):
		sel = int(_cards[0]["id"]) if not _cards.is_empty() else -1
	if visible:
		_rebuild()

# ───────────────────────── dibujo ─────────────────────────
func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.035, 0.06, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# un velo naranja muy suave arriba a la izquierda: que no sea un negro liso
	var glow := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.48, 0.1, 0.20), Color(1.0, 0.48, 0.1, 0.0)])
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.9, 0.9)
	glow.texture = gt
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + s, 22)
	mc.add_theme_constant_override("margin_top", 14)
	mc.add_theme_constant_override("margin_bottom", 14)
	add_child(mc)
	var root := Kit.vbox(10)
	mc.add_child(root)
	root.add_child(_top_bar())
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	match tab:
		"novedades":
			_notes_tab()
		"ayuda":
			_help_tab()
		_:
			_events_tab()

func _top_bar() -> Control:
	var row := Kit.hbox(10)
	row.add_child(Kit.button("←  " + Tr.t("ATRÁS"), func() -> void: close(), false, 18, Vector2(120, 46)))
	var title := Kit.label("EVENTOS" if tab != "novedades" and tab != "ayuda" else Tr.t("EVENTOS"), 32, Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.48, 0.1, 0.5))
	title.add_theme_constant_override("outline_size", 3)
	title.text = Tr.t("EVENTOS")
	row.add_child(title)
	var live := 0
	for c in _cards:
		if bool(c["live"]) and not bool(c["done"]):
			live += 1
	if live > 0:
		var chip := Kit.label("● " + Tr.t("%d en vivo") % live, 15, Color(0.3, 1.0, 0.55))
		chip.add_theme_stylebox_override("normal", Kit.box(Color(0.1, 0.3, 0.18, 0.8), 12, Color(0.3, 1.0, 0.55, 0.5), 1, 8))
		row.add_child(chip)
	row.add_child(Kit.spacer())
	for t in [["eventos", "📅 " + Tr.t("EVENTOS"), false], ["novedades", "🔔 " + Tr.t("NOVEDADES"), _notes_new], ["ayuda", "❓ " + Tr.t("AYUDA"), false]]:
		var tb := Kit.button(str(t[1]), func() -> void:
			tab = str(t[0])
			_rebuild(), tab == str(t[0]), 16, Vector2(0, 46))
		if bool(t[2]):
			tb.add_child(_dot(Vector2(-4, 4), true))
		row.add_child(tb)
	return row

## Puntito rojo de «nuevo» (esquina de un botón o de una tarjeta)
func _dot(off := Vector2(-6, 6), top_right := true) -> Control:
	var d := Control.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_anchors_preset(Control.PRESET_TOP_RIGHT if top_right else Control.PRESET_TOP_LEFT)
	d.custom_minimum_size = Vector2(14, 14)
	d.position = Vector2(-14, 0) + off
	d.draw.connect(func() -> void:
		d.draw_circle(Vector2(7, 7), 7.0, Color(1, 1, 1, 0.95))
		d.draw_circle(Vector2(7, 7), 5.2, Color(0.95, 0.18, 0.2)))
	d.queue_redraw()
	return d

# ───────────────────────── solapa EVENTOS ─────────────────────────
func _events_tab() -> void:
	if _cards.is_empty():
		var box := Kit.vbox(8)
		box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_body.add_child(box)
		var ic := Kit.label("📅", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		box.add_child(ic)
		box.add_child(Kit.label(Tr.t("Ahora no hay eventos"), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(Kit.label(Tr.t("Los eventos llegan solos: volvé a mirar en un rato."), 16, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		box.position = Vector2(-300, -80)
		box.custom_minimum_size = Vector2(600, 0)
		return
	var row := Kit.hbox(14)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(row)
	var sc := TouchScroll.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 0.9
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	var list := Kit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var shown_head := {}
	for c in _cards:
		var live := bool(c["live"])
		if not shown_head.has(live):
			shown_head[live] = true
			list.add_child(Kit.label(("🔴 " + Tr.t("EN VIVO")) if live else ("🕒 " + Tr.t("PRÓXIMOS")), 15, Color(0.3, 1.0, 0.55) if live else Kit.GOLD))
		list.add_child(_card(c))
	var det := _detail(_find(sel))
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.size_flags_vertical = Control.SIZE_EXPAND_FILL
	det.size_flags_stretch_ratio = 1.25
	row.add_child(det)

func _find(id: int) -> Dictionary:
	for c in _cards:
		if int(c["id"]) == id:
			return c
	return {}

func _kind_col(kind: String) -> Color:
	return KIND_COL.get(kind, Kit.ACCENT)

## Una tarjeta de la lista: imagen, nombre, cuándo y premio. Tocarla muestra su detalle a la derecha.
func _card(c: Dictionary) -> Control:
	var id := int(c["id"])
	var selected := id == sel
	var col := _kind_col(str(c["kind"]))
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 98)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", Kit.box(Color(0.10, 0.125, 0.17, 0.97), 14, col if selected else Kit.LINE, 3 if selected else 1))
	b.add_theme_stylebox_override("hover", Kit.box(Color(0.13, 0.16, 0.21, 0.98), 14, col, 2))
	b.add_theme_stylebox_override("pressed", Kit.box(Color(0.08, 0.1, 0.14, 0.98), 14, col, 3))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		sel = id
		_msg = ""
		_rebuild())
	var h := Kit.hbox(10)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_top = 7
	h.offset_right = -8
	h.offset_bottom = -7
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var img := TextureRect.new()
	img.texture = image_for(str(c["kind"]))
	img.custom_minimum_size = Vector2(150, 84)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.clip_contents = true
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(img)
	var v := Kit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	var t := Kit.label(str(c["title"]), 19, Color.WHITE)
	t.clip_text = true
	v.add_child(t)
	var live := bool(c["live"])
	var st := Kit.label(("● " if live else "○ ") + str(c["when_short"]), 13, Color(0.3, 1.0, 0.55) if live else Kit.GOLD)
	st.clip_text = true
	v.add_child(st)
	if bool(c["done"]):
		v.add_child(Kit.label("✔ " + Tr.t("ya lo hiciste"), 12, Kit.MUTED))
	elif str(c["reward_short"]) != "":
		var rw := Kit.label("🎁 " + str(c["reward_short"]), 12, Kit.MUTED)
		rw.clip_text = true
		v.add_child(rw)
	if bool(c.get("active", false)):
		var tag := Kit.label("➤ " + Tr.t("EN CURSO"), 12, col)
		v.add_child(tag)
	if _new_ids.has(id):
		b.add_child(_dot(Vector2(-8, 8), true))
	return b

## El detalle del evento elegido: imagen grande con el nombre encima, cómo se juega, premios, cómo vas y los botones
func _detail(c: Dictionary) -> Control:
	var pnl := Kit.panel(0, Color(0.07, 0.09, 0.13, 0.97))
	pnl.clip_contents = true
	var v := Kit.vbox(0)
	pnl.add_child(v)
	if c.is_empty():
		return pnl
	var col := _kind_col(str(c["kind"]))
	var ban := Control.new()
	ban.custom_minimum_size = Vector2(0, 118)
	ban.clip_contents = true
	v.add_child(ban)
	var img := TextureRect.new()
	img.texture = image_for(str(c["kind"]))
	img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ban.add_child(img)
	var fade := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.03, 0.05, 0.0), Color(0.02, 0.03, 0.05, 0.92)])
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.25)
	gt.fill_to = Vector2(0, 1.0)
	fade.texture = gt
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ban.add_child(fade)
	var live := bool(c["live"])
	var chip := Kit.label(("● " + Tr.t("EN VIVO")) if live else ("🕒 " + str(c["when_short"]).to_upper()), 14, Color(0.04, 0.06, 0.08))
	chip.add_theme_stylebox_override("normal", Kit.box(Color(0.3, 1.0, 0.55) if live else Kit.GOLD, 10, Color(0, 0, 0, 0), 0, 9))
	chip.position = Vector2(12, 10)
	ban.add_child(chip)
	var ti := Kit.label(str(c["icon"]) + "  " + str(c["title"]), 29, Color.WHITE)
	ti.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ti.add_theme_constant_override("outline_size", 8)
	ti.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ti.offset_left = 14
	ti.offset_top = -46
	ti.offset_bottom = -8
	ban.add_child(ti)
	var bar := ColorRect.new()
	bar.color = col
	bar.custom_minimum_size = Vector2(0, 3)
	v.add_child(bar)
	var sc := TouchScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var mg := MarginContainer.new()
	mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right"]:
		mg.add_theme_constant_override("margin_" + s, 14)
	mg.add_theme_constant_override("margin_top", 8)
	mg.add_theme_constant_override("margin_bottom", 8)
	sc.add_child(mg)
	var info := Kit.vbox(7)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.add_child(info)
	info.add_child(Kit.wrap(str(c["when"]), 14, Color(0.3, 1.0, 0.55) if live else Kit.GOLD, 200))
	if str(c["descr"]) != "":
		info.add_child(Kit.wrap(str(c["descr"]), 15, Kit.TEXT, 200))
	info.add_child(Kit.label("🧭 " + Tr.t("CÓMO SE JUEGA"), 13, col))
	info.add_child(Kit.wrap(str(c["how"]), 14, Kit.MUTED, 200))
	if not (c["prizes"] as Array).is_empty():
		info.add_child(Kit.label("🎁 " + Tr.t("PREMIOS"), 13, col))
		for p in (c["prizes"] as Array):
			info.add_child(_prize_row(p as Dictionary))
	if str(c["progress"]) != "":
		info.add_child(Kit.label("📊 " + Tr.t("TU PROGRESO"), 13, col))
		info.add_child(Kit.wrap(str(c["progress"]), 14, Kit.TEXT, 200))
	if _msg != "":
		info.add_child(Kit.wrap("✔ " + _msg, 14, Color(0.3, 1.0, 0.55), 200))
	# botones
	var bb := Kit.hbox(8)
	var bm := MarginContainer.new()
	for s in ["left", "right"]:
		bm.add_theme_constant_override("margin_" + s, 12)
	bm.add_theme_constant_override("margin_top", 6)
	bm.add_theme_constant_override("margin_bottom", 10)
	bm.add_child(bb)
	v.add_child(bm)
	var id := int(c["id"])
	var go := Kit.button("📍  " + str(c["go_label"]), func() -> void: go_pressed.emit(id), true, 17, Vector2(0, 52))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.disabled = not bool(c["go"])
	bb.add_child(go)
	if bool(c.get("active", false)):
		var cn := Kit.button("✕  " + Tr.t("SALIR DEL EVENTO"), func() -> void: cancel_pressed.emit(id), false, 16, Vector2(0, 52))
		cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bb.add_child(cn)
	return pnl

## Una fila de premio: miniatura del auto (si el premio es un auto) y el texto
func _prize_row(p: Dictionary) -> Control:
	var r := Kit.hbox(8)
	var th := car_thumb(str(p.get("car", "")))
	if th != null:
		var tr_ := TextureRect.new()
		tr_.texture = th
		tr_.custom_minimum_size = Vector2(112, 56)
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr_.clip_contents = true
		r.add_child(tr_)
	else:
		r.add_child(Kit.label(str(p.get("icon", "🎁")), 26, Kit.GOLD))
	var t := Kit.wrap(str(p.get("text", "")), 14, Kit.TEXT, 150)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(t)
	return r

# ───────────────────────── novedades y ayuda ─────────────────────────
func _notes_tab() -> void:
	var sc := TouchScroll.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var list := Kit.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var notes := _get_notes()
	if notes.is_empty():
		list.add_child(Kit.wrap(Tr.t("Todavía no hay novedades: acá vas a ver quién ganó, tus premios y los avisos de los eventos."), 17, Kit.MUTED, 400))
		return
	for n in notes:
		var p := Kit.panel(10, Color(0.10, 0.125, 0.17, 0.97))
		list.add_child(p)
		var l := Kit.wrap(str(n["text"]).replace("\n", "  ·  "), 16, Kit.TEXT, 400)
		p.add_child(l)
		if bool(n.get("new", false)):
			p.add_child(_dot(Vector2(-8, 8), true))

func _help_tab() -> void:
	var sc := TouchScroll.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var p := Kit.panel(14, Color(0.10, 0.125, 0.17, 0.97))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(p)
	var t: String = str(help_fn.call()) if help_fn.is_valid() else ""
	p.add_child(Kit.wrap(t.replace("❓ AYUDA\n", ""), 17, Kit.TEXT, 500))
