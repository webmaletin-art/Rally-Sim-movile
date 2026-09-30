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
