extends Control
## Radar de cinco puntas con las barras del auto (velocidad, aceleración, frenado, off-road, manejo): los mismos números de las barras, sólo dibujados distinto.
## values: 0..1 en el orden de `labels` (de arriba, en sentido horario).

const ACCENT := Color(1.0, 0.48, 0.10)

var values: Array = [0.5, 0.5, 0.5, 0.5, 0.5]
var labels: Array = ["Vel", "Acc", "Fre", "Off", "Man"]

static func make(vals: Array, px := 120.0) -> Control:
	var r: Control = (load("res://game/ui/radar.gd") as GDScript).new()
	r.values = vals
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _vertex(i: int, k: float) -> Vector2:
	var c := size * 0.5
	var rad := minf(size.x, size.y) * 0.5 - 22.0
	var a := -PI / 2.0 + TAU * float(i) / 5.0
	return c + Vector2(cos(a), sin(a)) * rad * k

func _draw() -> void:
	var line := Color(1, 1, 1, 0.12)
	for k in [0.34, 0.67, 1.0]:
		var ring := PackedVector2Array()
		for i in 5:
			ring.append(_vertex(i, k))
		ring.append(_vertex(0, k))
		draw_polyline(ring, line, 1.0, true)
	for i in 5:
		draw_line(_vertex(i, 0.0), _vertex(i, 1.0), line, 1.0)
	var poly := PackedVector2Array()
	for i in 5:
		poly.append(_vertex(i, clampf(float(values[i]), 0.06, 1.0)))
	draw_colored_polygon(poly, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.30))
	var outl := poly.duplicate()
	outl.append(poly[0])
	draw_polyline(outl, ACCENT, 1.6, true)
	var font := ThemeDB.fallback_font
	for i in 5:
		var p := _vertex(i, 1.0)
		var dir := (p - size * 0.5).normalized()
		var txt: String = TranslationServer.translate(str(labels[i]))
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var tp := p + dir * 9.0 + Vector2(-w * 0.5, 4.0)
		draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.62, 0.68, 0.76))
