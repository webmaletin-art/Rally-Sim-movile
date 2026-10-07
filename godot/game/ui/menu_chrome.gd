extends RefCounted
## Marco del garaje premium (GARAJE · TALLER · TIENDA): barra superior con el logo, las secciones, el dinero, el nivel y los ajustes;
## riel de navegación a la izquierda; y, abajo, el carrusel de autos con la tira de especificaciones. Sólo es presentación:
## cada botón llama a lo mismo que antes (menu.go, menu.back, perfil, catálogo). No guarda ni inventa datos.

const Kit := preload("res://game/ui/ui_kit.gd")
const Icons := preload("res://game/ui/icons.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Tr := preload("res://game/i18n/tr.gd")

const SCREENS := ["garage", "dealer", "workshop", "tune", "paint", "shop"]
const TOP_H := 50.0
const MARGIN := 10.0
const CAROUSEL_H := 96.0
const SPECS_H := 44.0
const RAIL_W := 158.0
const RAIL_W_COMPACT := 66.0
## Pestañas del taller: [ícono, nombre, número de pestaña]
const WS_TABS := [["wrench", "PIEZAS", 0], ["tire", "GOMAS", 1], ["gear", "AJUSTE", 2], ["brush", "PINTURA", 3], ["wheel", "LLANTAS", 4], ["star", "ESTÉTICA", 5]]

var m # menu.gd
var top: Control
var rail: Control
var bottom: Control
var money_l: Label
var lvl_l: Label
var xp_bar: ProgressBar
var _scroll: ScrollContainer
var _last_scroll := 0
var _target_card: Control
var cards: Array = [] # botones de las tarjetas del carrusel (en orden; para las pruebas)

static func wanted(screen: String) -> bool:
	return SCREENS.has(screen)

func in_city() -> bool:
	return not m.app.city_return.is_empty()

func has_carousel(screen: String) -> bool:
	return screen == "garage" or screen == "dealer"

## Ancho del riel: con nombres en el garaje y la tienda; sólo íconos (con el nombre chico abajo) en el taller, que necesita el ancho para sus listas
func rail_width(screen: String) -> float:
	return RAIL_W if has_carousel(screen) else RAIL_W_COMPACT

func clear() -> void:
	for c in [top, rail, bottom]:
		if c != null and is_instance_valid(c):
			(c as Node).queue_free()
	top = null
	rail = null
	bottom = null
	money_l = null
	lvl_l = null
	xp_bar = null
	_scroll = null
	_target_card = null
	cards = []

## Cuánto mide hacia abajo lo que ocupa el carrusel y las especificaciones (el panel central y la cámara lo dejan libre)
func bottom_height(screen: String) -> float:
	return (CAROUSEL_H + SPECS_H + 6.0 + MARGIN) if has_carousel(screen) else MARGIN

## Dónde empieza lo central (debajo de la barra superior)
func main_top() -> float:
	return MARGIN + TOP_H + 8.0

# ───────────────────────── barra superior ─────────────────────────
func _tab(text: String, selected: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(112, TOP_H - 6.0)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE if selected else Color(0.7, 0.75, 0.83))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var sel := Kit.glow_box(Color(1, 1, 1, 0.06), 8, Color(0, 0, 0, 0), 0, Color(1.0, 0.48, 0.10, 0.22), 7, 6)
	sel.border_width_bottom = 3
	sel.border_color = Kit.ACCENT
	var idle := Kit.box(Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), 0, 6)
	var hov := Kit.box(Color(1, 1, 1, 0.05), 8, Color(0, 0, 0, 0), 0, 6)
	b.add_theme_stylebox_override("normal", sel if selected else idle)
	b.add_theme_stylebox_override("hover", sel if selected else hov)
	b.add_theme_stylebox_override("pressed", sel)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		if selected:
			return
		m.sfx.play("click")
		cb.call())
	return b

func build_top(screen: String) -> void:
	top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", Kit.box(Kit.GRAPHITE, 14, Kit.LINE, 1, 10))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = MARGIN
	top.offset_right = -MARGIN
	top.offset_top = MARGIN
	top.offset_bottom = MARGIN + TOP_H
	m.root.add_child(top)
	var row := Kit.hbox(14)
	top.add_child(row)
	# logo
	var logo := Kit.hbox(6)
	row.add_child(logo)
	for pr in [["DREAM", Color.WHITE], ["RACING", Kit.ACCENT]]:
		var l := Kit.label(str(pr[0]), 23, pr[1] as Color)
		l.add_theme_color_override("font_outline_color", pr[1] as Color)
		l.add_theme_constant_override("outline_size", 1)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		logo.add_child(l)
	# secciones
	var mid := Kit.hbox(6)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	if in_city():
		var tl := Kit.label(m.garage.city_title() if m.garage != null else "", 20, Kit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tl.clip_text = true
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(tl)
	else:
		var group := 0 if screen == "garage" else (2 if screen == "dealer" else 1)
		mid.add_child(_tab("GARAJE", group == 0, func() -> void: m.go("garage", null, false)))
		mid.add_child(_tab("TALLER", group == 1, func() -> void: m.go("workshop", null, false)))
		mid.add_child(_tab("TIENDA", group == 2, func() -> void: m.go("dealer", null, false)))
	_stats_cluster(row, true)
	refresh_stats()

## Dinero (con «+» a las compras), nivel con su barra y, opcional, el engranaje de ajustes. `row` es la fila donde se agregan
func _stats_cluster(row: HBoxContainer, with_gear: bool) -> void:
	var money := PanelContainer.new()
	money.add_theme_stylebox_override("panel", Kit.box(Color(0, 0, 0, 0.28), 10, Kit.LINE, 1, 8))
	row.add_child(money)
	var mrow := Kit.hbox(8)
	money.add_child(mrow)
	money_l = Kit.label("", 21, Kit.GOLD)
	money_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mrow.add_child(money_l)
	if not in_city():
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(30, 30)
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.add_theme_font_size_override("font_size", 22)
		plus.add_theme_color_override("font_color", Kit.ACCENT)
		plus.add_theme_color_override("font_hover_color", Color.WHITE)
		plus.add_theme_stylebox_override("normal", Kit.box(Color(0.13, 0.1, 0.07, 0.9), 8, Kit.ACCENT, 1, 0))
		plus.add_theme_stylebox_override("hover", Kit.box(Color(0.22, 0.14, 0.07, 0.95), 8, Kit.ACCENT, 2, 0))
		plus.add_theme_stylebox_override("pressed", Kit.box(Color(0.3, 0.17, 0.07, 1), 8, Kit.ACCENT, 2, 0))
		plus.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		plus.pressed.connect(func() -> void:
			m.sfx.play("click")
			m.go("iap"))
		mrow.add_child(plus)
	var lv := Kit.vbox(2)
	lv.custom_minimum_size.x = 88
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(lv)
	lvl_l = Kit.label("", 14, Kit.TEXT)
	lv.add_child(lvl_l)
	xp_bar = ProgressBar.new()
	xp_bar.max_value = 1.0
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(80, 7)
	xp_bar.add_theme_stylebox_override("background", Kit.box(Color(1, 1, 1, 0.1), 4))
	xp_bar.add_theme_stylebox_override("fill", Kit.box(Kit.ACCENT, 4))
	lv.add_child(xp_bar)
	if with_gear and not in_city():
		var sb := Button.new()
		sb.custom_minimum_size = Vector2(38, 38)
		sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sb.add_theme_stylebox_override("normal", Kit.box(Color(0, 0, 0, 0), 10, Color(0, 0, 0, 0), 0, 0))
		sb.add_theme_stylebox_override("hover", Kit.box(Color(1, 1, 1, 0.07), 10, Kit.ACCENT_SOFT, 1, 0))
		sb.add_theme_stylebox_override("pressed", Kit.box(Color(1, 1, 1, 0.12), 10, Kit.ACCENT, 1, 0))
		sb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		sb.pressed.connect(func() -> void:
			m.sfx.play("click")
			m.go("options"))
		var gi := Icons.make("gear", Color(0.85, 0.89, 0.95), 24.0)
		gi.position = Vector2(7, 7)
		sb.add_child(gi)
		row.add_child(sb)

## Esquina superior derecha del inicio: el mismo dinero y nivel que en el garaje (el inicio no lleva barra completa)
func build_corner() -> void:
	top = PanelContainer.new()
	top.add_theme_stylebox_override("panel", Kit.box(Kit.GRAPHITE, 14, Kit.LINE, 1, 8))
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.offset_right = -MARGIN
	top.offset_top = MARGIN
	m.root.add_child(top)
	var row := Kit.hbox(12)
	top.add_child(row)
	_stats_cluster(row, false)
	refresh_stats()
	Kit.pop_in(top, 0.0, 0.18)

## Dinero, nivel y barra de progreso al nivel siguiente (mismos números que el perfil)
func refresh_stats() -> void:
	if money_l == null or not is_instance_valid(money_l):
		return
	var p: RefCounted = m.profile
	money_l.text = Kit.fmt_cr(float(p.credits))
	var lvl := int(p.d["level"])
	lvl_l.text = "Nv %d" % lvl
	var need: int = int(p.xp_for_level(lvl))
	xp_bar.value = clampf(float(p.d["xp"]) / maxf(1.0, float(need)), 0.0, 1.0)

# ───────────────────────── riel de navegación ─────────────────────────
func _rail_item(icon: String, text: String, selected: bool, compact: bool, cb: Callable) -> Control:
	if not compact:
		return Kit.nav_item(icon, Tr.t(text), selected, cb, 31.0, 13)
	# compacto: ícono arriba y el nombre chico abajo
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel_bg := Color(0.17, 0.14, 0.12, 0.96)
	var n := Kit.glow_box(sel_bg if selected else Color(0.075, 0.09, 0.12, 0.78), 10, Kit.ACCENT if selected else Kit.LINE, 2 if selected else 1, Color(1.0, 0.48, 0.10, 0.30) if selected else Color(0, 0, 0, 0), 8, 4)
	var h := Kit.box(sel_bg if selected else Color(0.11, 0.125, 0.16, 0.9), 10, Kit.ACCENT if selected else Kit.ACCENT_SOFT, 2 if selected else 1, 4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", Kit.box(Color(0.2, 0.15, 0.1, 0.98), 10, Kit.ACCENT, 2, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var v := Kit.vbox(1)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := Icons.make(icon, Kit.ACCENT if selected else Color(0.72, 0.77, 0.85), 20.0)
	v.add_child(ic)
	var short := {"COMPRA AUTOS": "COMPRAR"}
	var l := Kit.label(Tr.t(str(short.get(text, text))), 10, Color.WHITE if selected else Color(0.78, 0.82, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	l.clip_text = true
	l.custom_minimum_size.x = 20
	v.add_child(l)
	b.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		cb.call())
	return b

## Riel de la izquierda: ATRÁS (o SALIR si se entró desde la calle) y los destinos. Cada uno abre lo que ya abría
func build_rail(screen: String, ws_tab: int, allowed_tabs: Array) -> void:
	var compact := not has_carousel(screen)
	rail = Kit.vbox(4)
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = MARGIN
	rail.offset_right = MARGIN + rail_width(screen)
	rail.offset_top = main_top()
	rail.offset_bottom = -bottom_height(screen)
	m.root.add_child(rail)
	var leaving: bool = m.stack.is_empty() and in_city()
	rail.add_child(_rail_item("back", "SALIR" if leaving else "ATRÁS", false, compact, m.back))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rail.add_child(sep)
	if not in_city():
		rail.add_child(_rail_item("car", "MIS AUTOS", screen == "garage", compact, func() -> void:
			m.sfx.play("click")
			m.go("garage", null, false)))
		rail.add_child(_rail_item("cart", "COMPRA AUTOS", screen == "dealer", compact, func() -> void:
			m.sfx.play("click")
			m.go("dealer", null, false)))
	var in_ws: bool = screen != "garage" and screen != "dealer"
	var shown: Array = WS_TABS
	for t in shown:
		var tab_i: int = t[2]
		if not allowed_tabs.has(tab_i):
			continue
		if in_city() and (not in_ws or allowed_tabs.size() <= 1):
			continue # en la calle: el concesionario no tiene taller, y un local de una sola cosa no necesita riel de pestañas
		rail.add_child(_rail_item(str(t[0]), str(t[1]), in_ws and ws_tab == tab_i, compact, func() -> void:
			m.sfx.play("click")
			m.go("workshop", tab_i, false)))
	Kit.pop_in(rail, -10.0, 0.14)

# ───────────────────────── carrusel de autos + especificaciones ─────────────────────────
## ids: autos de la lista · idx: el elegido · info(id) → {name, letter, col, pi} · pick(índice) → elige ese auto
func build_bottom(ids: Array, idx: int, info: Callable, pick: Callable, spec: Dictionary) -> void:
	bottom = Control.new()
	bottom.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.root.add_child(bottom)
	# carrusel
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", Kit.box(Kit.GRAPHITE, 14, Kit.LINE, 1, 6))
	cp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cp.offset_left = MARGIN
	cp.offset_right = -MARGIN
	cp.offset_bottom = -(MARGIN + SPECS_H + 6.0)
	cp.offset_top = -(MARGIN + SPECS_H + 6.0 + CAROUSEL_H)
	bottom.add_child(cp)
	var row := Kit.hbox(6)
	cp.add_child(row)
	var la := _arrow("◀", func() -> void: pick.call(posmod(idx - 1, ids.size())))
	row.add_child(la)
	var sc := TouchScroll.new()
	sc.horizontal = true
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(sc)
	_scroll = sc
	var cards_box := Kit.hbox(8)
	cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cards_box)
	cards = []
	for i in ids.size():
		var inf: Dictionary = info.call(str(ids[i]))
		var card := _car_card(str(ids[i]), inf, i == idx, func() -> void:
			if i != idx:
				pick.call(i))
		cards_box.add_child(card)
		cards.append(card)
		if i == idx:
			_target_card = card
	var ra := _arrow("▶", func() -> void: pick.call(posmod(idx + 1, ids.size())))
	row.add_child(ra)
	# especificaciones
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", Kit.box(Kit.GRAPHITE, 12, Kit.LINE, 1, 6))
	sp.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sp.offset_left = MARGIN
	sp.offset_right = -MARGIN
	sp.offset_bottom = -MARGIN
	sp.offset_top = -(MARGIN + SPECS_H)
	bottom.add_child(sp)
	var srow := Kit.hbox(0)
	sp.add_child(srow)
	var cells: Array = [["engine", "Motor", str(spec["engine"])], ["shift", "Transmisión", str(spec["gears"])], ["drive", "Tracción", str(spec["drive"])],
		["weight", "Peso", str(spec["kg"])], ["gauge", "Vel. máx.", str(spec["vmax"])], ["power", "Potencia", str(spec["hp"])]]
	for i in cells.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = Color(1, 1, 1, 0.09)
			line.custom_minimum_size = Vector2(1, 0)
			line.size_flags_vertical = Control.SIZE_EXPAND_FILL
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			srow.add_child(line)
		var cell := Kit.hbox(8)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 8)
		srow.add_child(cell)
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(8, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pad)
		cell.add_child(Icons.make(str(cells[i][0]), Color(0.8, 0.84, 0.9), 22.0))
		var tv := Kit.vbox(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(tv)
		var vl := Kit.label(str(cells[i][2]), 14, Kit.TEXT)
		vl.clip_text = true
		vl.custom_minimum_size.x = 20
		tv.add_child(vl)
		var tl2 := Kit.label(Tr.t(str(cells[i][1])), 11, Kit.MUTED)
		tl2.clip_text = true
		tl2.custom_minimum_size.x = 20
		tv.add_child(tl2)
	Kit.pop_in(cp, 0.0, 0.18)
	_center_target.call_deferred()

func _arrow(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(34, 0)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.85, 0.89, 0.95))
	b.add_theme_stylebox_override("normal", Kit.box(Color(1, 1, 1, 0.04), 10, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("hover", Kit.box(Color(1, 1, 1, 0.09), 10, Kit.ACCENT_SOFT, 1, 4))
	b.add_theme_stylebox_override("pressed", Kit.box(Color(1, 1, 1, 0.14), 10, Kit.ACCENT, 1, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func() -> void:
		m.sfx.play("click")
		cb.call())
	return b

func _thumb(id: String) -> Texture2D:
	var path := "res://game/ui/thumbs/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

## Tarjeta de un auto: miniatura, nombre, categoría y PI. El elegido: borde naranja, resplandor suave y un poco más alto; el resto, más oscuro
func _car_card(id: String, inf: Dictionary, selected: bool, cb: Callable) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(156, 76)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var nbg := Color(0.09, 0.11, 0.15, 0.96) if selected else Color(0.05, 0.06, 0.085, 0.92)
	var nb := Kit.glow_box(nbg, 10, Kit.ACCENT if selected else Kit.LINE, 2 if selected else 1, Color(1.0, 0.48, 0.10, 0.32) if selected else Color(0, 0, 0, 0), 7, 0)
	b.add_theme_stylebox_override("normal", nb)
	b.add_theme_stylebox_override("hover", Kit.box(Color(0.11, 0.13, 0.17, 0.98), 10, Kit.ACCENT if selected else Kit.ACCENT_SOFT, 2 if selected else 1, 0))
	b.add_theme_stylebox_override("pressed", nb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var tex := _thumb(id)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 3
		tr.offset_right = -3
		tr.offset_top = 3
		tr.offset_bottom = -3
		tr.modulate = Color.WHITE if selected else Color(0.62, 0.64, 0.7)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)
	else:
		var ic := Icons.make("car", Color(1, 1, 1, 0.18), 46.0)
		ic.set_anchors_preset(Control.PRESET_CENTER)
		ic.position = Vector2(52, 8)
		b.add_child(ic)
	# franja de texto abajo (oscurece la miniatura para que se lea)
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", Kit.box(Color(0.02, 0.025, 0.04, 0.78), 8, Color(0, 0, 0, 0), 0, 5))
	strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_left = 3
	strip.offset_right = -3
	strip.offset_bottom = -3
	strip.offset_top = -38
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(strip)
	var v := Kit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(v)
	var nl := Kit.label(str(inf["name"]), 13, Color.WHITE if selected else Color(0.8, 0.84, 0.9))
	nl.clip_text = true
	nl.custom_minimum_size.x = 20
	v.add_child(nl)
	var r2 := Kit.hbox(5)
	r2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(r2)
	var bd := Kit.class_badge(str(inf["letter"]), inf["col"] as Color, 11)
	bd.custom_minimum_size = Vector2(16, 16)
	r2.add_child(bd)
	r2.add_child(Kit.label(str(inf["sub"]), 11, Kit.GOLD if selected else Kit.MUTED))
	b.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		m.sfx.play("click")
		cb.call())
	return b

## Deja la tarjeta elegida en el medio del carrusel: arranca donde estaba el desplazamiento anterior y se mueve suave
func _center_target() -> void:
	if _scroll == null or not is_instance_valid(_scroll) or _target_card == null or not is_instance_valid(_target_card):
		return
	await _scroll.get_tree().process_frame
	if _scroll == null or not is_instance_valid(_scroll) or _target_card == null or not is_instance_valid(_target_card):
		return
	var want := int(_target_card.position.x + _target_card.size.x * 0.5 - _scroll.size.x * 0.5)
	want = maxi(0, want)
	_scroll.scroll_horizontal = _last_scroll
	var tw := _scroll.create_tween()
	tw.tween_property(_scroll, "scroll_horizontal", want, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_last_scroll = want
