extends RefCounted
## Piezas de interfaz en código (sin archivos de tema): colores, botones, paneles, etiquetas. Estilo oscuro con acento naranja
## como la versión HTML.

const BG := Color(0.035, 0.05, 0.075)
const PANEL := Color(0.075, 0.095, 0.13, 0.94)
const PANEL2 := Color(0.11, 0.135, 0.18, 0.96)
const LINE := Color(1, 1, 1, 0.10)
const ACCENT := Color(1.0, 0.48, 0.10)
const GOLD := Color(1.0, 0.82, 0.25)
const GREEN := Color(0.25, 0.85, 0.5)
const RED := Color(1.0, 0.3, 0.35)
static var scroll_moved := false
const TEXT := Color(0.93, 0.95, 0.98)
const MUTED := Color(0.62, 0.68, 0.76)
const GRAPHITE := Color(0.05, 0.058, 0.082, 0.9) # barras y paneles del garaje premium (translúcidos, el auto se ve detrás)
const ACCENT_SOFT := Color(1.0, 0.48, 0.10, 0.55)
const Icons := preload("res://game/ui/icons.gd")
const Radar := preload("res://game/ui/radar.gd")

static func box(bg: Color, radius := 10, border := Color(0, 0, 0, 0), bw := 0, pad := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	if pad > 0:
		sb.content_margin_left = pad
		sb.content_margin_right = pad
		sb.content_margin_top = pad * 0.7
		sb.content_margin_bottom = pad * 0.7
	return sb

static func label(text: String, size := 22, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, cb: Callable = Callable(), accent := false, size := 22, min_size := Vector2(0, 56)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.05, 0.06, 0.08) if accent else TEXT)
	b.add_theme_color_override("font_hover_color", Color(0.05, 0.06, 0.08) if accent else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.06, 0.08) if accent else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.56))
	var base := ACCENT if accent else PANEL2
	var nb := box(base, 12, LINE, 1, 14)
	var hb := box(base.lightened(0.08), 12, Color(1, 1, 1, 0.5) if accent else ACCENT_SOFT, 1, 14)
	if accent: # el botón principal tiene un resplandor naranja muy suave
		for sbx in [nb, hb]:
			(sbx as StyleBoxFlat).shadow_color = Color(1.0, 0.48, 0.10, 0.32)
			(sbx as StyleBoxFlat).shadow_size = 7
	b.add_theme_stylebox_override("normal", nb)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.12), 12, ACCENT, 2, 14))
	b.add_theme_stylebox_override("disabled", box(Color(0.09, 0.11, 0.14, 0.9), 12, LINE, 1, 14))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if cb.is_valid():
		b.pressed.connect(func() -> void:
			if scroll_moved:
				scroll_moved = false # el toque fue un arrastre para desplazar la lista: no cuenta como pulsación
				return
			cb.call())
	return b

static func panel(pad := 16, bg := PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, 14, LINE, 1, pad))
	return p

static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func fmt_cr(n: float) -> String:
	var s := str(int(round(n)))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += "."
		out += s[i]
	return "$ " + out

static func fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var s := t - float(m) * 60.0
	return "%d:%05.2f" % [m, s]

static func hexc(h) -> Color:
	return Color(str(h))

# ───────────────────────── piezas compactas (menús sin scroll) ─────────────────────────
const DARK := Color(0.05, 0.06, 0.08)

## Selector de tarjeta: título chico arriba y, abajo, ◀ valor ▶ (toca la mitad izquierda para ir atrás, la derecha para adelante).
## values: lista de valores · fmt: Callable(valor) → texto · cb: Callable(valor) cuando cambia. Devuelve un PanelContainer con set_value().
static func selector(title: String, values: Array, cur, fmt: Callable, cb: Callable, sfx: Node = null, h := 64.0) -> PanelContainer:
	var S: GDScript = load("res://game/ui/ui_selector.gd")
	var s: PanelContainer = S.new(title, values, cur, fmt, cb, h)
	s.set("sfx", sfx)
	return s

## Grilla de n columnas
static func grid(cols := 2, hsep := 8, vsep := 8) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", hsep)
	g.add_theme_constant_override("v_separation", vsep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return g

## Pestañas: botones en fila; el actual resaltado. cb(índice)
static func tabs(labels: Array, cur: int, cb: Callable, size := 17, h := 44.0) -> HBoxContainer:
	var row := hbox(6)
	for i in labels.size():
		var idx := i
		var b := button(str(labels[i]), func() -> void: cb.call(idx), cur == i, size, Vector2(0, h))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		row.add_child(b)
	return row

## Paginador: ◀ página 2/3 ▶ (cb recibe la página nueva)
static func pager(page: int, pages: int, cb: Callable) -> HBoxContainer:
	var row := hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var b0 := button("◀", func() -> void: cb.call(posmod(page - 1, pages)), false, 20, Vector2(64, 40))
	var b1 := button("▶", func() -> void: cb.call(posmod(page + 1, pages)), false, 20, Vector2(64, 40))
	b0.disabled = pages <= 1
	b1.disabled = pages <= 1
	row.add_child(b0)
	var l := label("%d / %d" % [page + 1, maxi(1, pages)], 18, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size.x = 80
	row.add_child(l)
	row.add_child(b1)
	return row

## Tarjeta de dos líneas dentro de un botón: título, subtítulo y texto a la derecha. Devuelve el botón.
static func card_button(title: String, sub: String, right: String, cb: Callable, accent := false, enabled := true, h := 64.0, tsize := 20, left := "") -> Button:
	var b := button("", Callable(), accent, 20, Vector2(0, h))
	b.disabled = not enabled
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := hbox(8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -12
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var dark := accent
	if left != "":
		var ll := label(left, 28, DARK if dark else (ACCENT if enabled else MUTED))
		ll.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ll)
	var v := vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var tl := label(title, tsize, DARK if dark else (TEXT if enabled else MUTED))
	tl.clip_text = true
	tl.custom_minimum_size.x = 40
	v.add_child(tl)
	if sub != "":
		var sl := label(sub, 13, DARK.lightened(0.15) if dark else MUTED)
		sl.clip_text = true
		sl.custom_minimum_size.x = 40
		v.add_child(sl)
	if right != "":
		var rl := label(right, 17, DARK if dark else (GOLD if enabled else MUTED), HORIZONTAL_ALIGNMENT_RIGHT)
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rl)
	b.pressed.connect(func() -> void:
		if scroll_moved:
			scroll_moved = false
			return
		cb.call())
	return b

## Texto con ajuste de línea
static func wrap(text: String, size := 16, col := MUTED, min_w := 300.0) -> Label:
	var l := label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = min_w
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

# ───────────────────────── garaje premium: navegación, barras y estadísticas ─────────────────────────
## Caja con resplandor (shadow) del color dado
static func glow_box(bg: Color, radius: int, border: Color, bw: int, glow: Color, glow_size: int, pad := 0) -> StyleBoxFlat:
	var sb := box(bg, radius, border, bw, pad)
	if glow.a > 0.0:
		sb.shadow_color = glow
		sb.shadow_size = glow_size
	return sb

## Ítem de navegación lateral: ícono + texto. El seleccionado: fondo más claro, borde naranja, resplandor suave, ícono naranja
static func nav_item(icon: String, text: String, selected: bool, cb: Callable, h := 42.0, size := 15, enabled := true) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not enabled
	var n_bg := Color(0.075, 0.09, 0.12, 0.78)
	var sel_bg := Color(0.17, 0.14, 0.12, 0.96)
	var sb_n := box(sel_bg if selected else n_bg, 10, ACCENT if selected else LINE, 2 if selected else 1, 10)
	if selected:
		sb_n.shadow_color = Color(1.0, 0.48, 0.10, 0.30)
		sb_n.shadow_size = 8
	var sb_h := box(sel_bg if selected else Color(0.11, 0.125, 0.16, 0.9), 10, ACCENT if selected else ACCENT_SOFT, 2 if selected else 1, 10)
	b.add_theme_stylebox_override("normal", sb_n)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", box(Color(0.2, 0.15, 0.1, 0.98), 10, ACCENT, 2, 10))
	b.add_theme_stylebox_override("disabled", sb_n)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := hbox(8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -6
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var ic := Icons.make(icon, ACCENT if selected else Color(0.72, 0.77, 0.85), 20.0)
	row.add_child(ic)
	var l := label(text, size, Color.WHITE if selected else Color(0.82, 0.86, 0.92) if enabled else MUTED)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size.x = 30
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	b.pressed.connect(func() -> void:
		if scroll_moved:
			scroll_moved = false
			return
		cb.call())
	return b

## Barra de estadística moderna: nombre, barra con punta clara y número (opcional)
static func stat_bar(name: String, v: float, value_text := "", color := ACCENT, name_w := 92.0, size := 14) -> Control:
	var row := hbox(8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := label(name, size, MUTED)
	l.custom_minimum_size.x = name_w
	l.clip_text = true
	row.add_child(l)
	var pb := ProgressBar.new()
	pb.max_value = 1.0
	pb.value = clampf(v, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(40, 9)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("background", box(Color(1, 1, 1, 0.07), 5))
	pb.add_theme_stylebox_override("fill", box(color, 5))
	row.add_child(pb)
	if value_text != "":
		var vl := label(value_text, size, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size.x = 30
		row.add_child(vl)
	return row

## Insignia de categoría (C, B, A, S…): cuadrado de color con la letra
static func class_badge(letter: String, col: Color, size := 24) -> Label:
	var badge := label(letter, size, DARK, HORIZONTAL_ALIGNMENT_CENTER)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(size * 1.45, size * 1.45)
	badge.add_theme_stylebox_override("normal", box(col, 8, Color(0, 0, 0, 0), 0, 0))
	return badge

## Entrada suave de un panel (alpha + un corrimiento corto): microinteracción liviana, sin partículas
static func pop_in(c: Control, from_x := -14.0, t := 0.16) -> void:
	if c == null or not c.is_inside_tree():
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, t)
	c.position.x += from_x
	tw.tween_property(c, "position:x", c.position.x - from_x, t).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Botón con ícono de línea + texto, centrados (como los botones de acción del garaje)
static func icon_button(icon: String, text: String, cb: Callable, accent := false, size := 18, min_size := Vector2(0, 50)) -> Button:
	var b := button("", cb, accent, size, min_size)
	var row := hbox(8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var ic := Icons.make(icon, DARK if accent else Color(0.9, 0.93, 0.97), float(size) + 3.0)
	row.add_child(ic)
	var l := label(text, size, DARK if accent else TEXT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	b.set_meta("lbl", l)
	b.set_meta("ico", ic)
	return b
