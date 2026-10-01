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
	b.add_theme_stylebox_override("normal", box(base, 12, LINE, 1, 14))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.08), 12, LINE, 1, 14))
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
