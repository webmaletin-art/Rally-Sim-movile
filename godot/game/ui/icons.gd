extends Control
## Íconos de línea dibujados en código (sin imágenes): se tiñen con `color`, escalan con el tamaño y no pesan nada.
## Uso: Icons.make("car", Kit.ACCENT, 24). Se dibujan sobre una grilla de 24 × 24.

const KINDS := ["car", "cart", "brush", "wrench", "wheel", "star", "gear", "plus", "back", "engine", "shift", "drive", "weight", "gauge", "power",
	"check", "swap", "tire", "bolt", "trophy", "road", "flag", "lock", "mountain", "world", "bag", "info"]

var kind := "car"
var color := Color.WHITE
var line_w := 1.8

static func make(k: String, col: Color = Color.WHITE, px := 24.0) -> Control:
	var ic: Control = (load("res://game/ui/icons.gd") as GDScript).new()
	ic.kind = k
	ic.color = col
	ic.custom_minimum_size = Vector2(px, px)
	ic.size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return ic

func set_color(c: Color) -> void:
	color = c
	queue_redraw()

func _p(x: float, y: float) -> Vector2:
	var s := minf(size.x, size.y) / 24.0
	return Vector2(x, y) * s + (size - Vector2.ONE * minf(size.x, size.y)) * 0.5

func _pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size(), 2):
		out.append(_p(float(a[i]), float(a[i + 1])))
	return out

func _w() -> float:
	return maxf(1.4, minf(size.x, size.y) / 24.0 * line_w)

func _ln(a: Array, closed := false) -> void:
	var p := _pts(a)
	if closed:
		p.append(p[0])
	draw_polyline(p, color, _w(), true)

func _circ(x: float, y: float, r: float, fill := false) -> void:
	var s := minf(size.x, size.y) / 24.0
	if fill:
		draw_circle(_p(x, y), r * s, color)
	else:
		draw_arc(_p(x, y), r * s, 0.0, TAU, 28, color, _w(), true)

func _arc(x: float, y: float, r: float, a0: float, a1: float) -> void:
	var s := minf(size.x, size.y) / 24.0
	draw_arc(_p(x, y), r * s, a0, a1, 24, color, _w(), true)

func _draw() -> void:
	match kind:
		"car":
			_ln([2.5, 16, 3.5, 11.5, 7, 8, 16.5, 8, 20, 11.5, 21.5, 12.5, 21.5, 16, 2.5, 16], true)
			_ln([8, 11.2, 15.5, 11.2])
			_circ(7, 16.4, 2.3, true)
			_circ(17, 16.4, 2.3, true)
		"cart":
			_ln([2, 4, 5, 4, 7.5, 15, 18.5, 15, 20.5, 7, 6, 7])
			_circ(9.5, 19.2, 1.6, true)
			_circ(17, 19.2, 1.6, true)
		"brush":
			_ln([5, 19, 16.5, 7.5])
			_ln([14, 5.5, 18.5, 10], false)
			_ln([18.5, 3.5, 20.5, 5.5, 17.5, 8.5, 15.5, 6.5], true)
			_circ(5.8, 18.2, 2.6)
		"wrench":
			_arc(16, 8, 4.6, 2.4, 2.4 + 4.3)
			_ln([13, 11, 4.5, 19.5])
			_circ(5.2, 18.8, 1.2, true)
		"wheel", "tire":
			_circ(12, 12, 9.2)
			_circ(12, 12, 2.6)
			for i in 5:
				var a := TAU * float(i) / 5.0 - PI / 2.0
				_ln([12.0 + cos(a) * 2.8, 12.0 + sin(a) * 2.8, 12.0 + cos(a) * 8.6, 12.0 + sin(a) * 8.6])
		"star":
			var pts: Array = []
			for i in 10:
				var a := TAU * float(i) / 10.0 - PI / 2.0
				var r := 10.0 if i % 2 == 0 else 4.4
				pts.append(12.0 + cos(a) * r)
				pts.append(12.5 + sin(a) * r)
			var pv := _pts(pts)
			draw_colored_polygon(pv, color)
		"gear":
			_circ(12, 12, 3.4)
			_circ(12, 12, 7.0)
			for i in 8:
				var a := TAU * float(i) / 8.0
				_ln([12.0 + cos(a) * 7.0, 12.0 + sin(a) * 7.0, 12.0 + cos(a) * 10.0, 12.0 + sin(a) * 10.0])
		"plus":
			_ln([12, 5, 12, 19])
			_ln([5, 12, 19, 12])
		"back":
			_ln([20, 12, 5, 12])
			_ln([11, 5.5, 4.5, 12, 11, 18.5])
		"engine":
			_ln([6, 9, 17, 9, 19, 11, 19, 17, 6, 17], true)
			_ln([3, 12, 6, 12])
			_ln([9, 9, 9, 6, 14, 6])
			_ln([19, 13, 21.5, 13])
		"shift":
			_ln([6, 5, 6, 19])
			_ln([18, 5, 18, 19])
			_ln([6, 12, 18, 12])
			_circ(6, 5, 1.6, true)
			_circ(18, 5, 1.6, true)
			_circ(6, 19, 1.6, true)
			_circ(18, 19, 1.6, true)
			_circ(12, 12, 1.6, true)
		"drive":
			_ln([4.5, 3.5, 8, 3.5, 8, 9.5, 4.5, 9.5], true)
			_ln([16, 3.5, 19.5, 3.5, 19.5, 9.5, 16, 9.5], true)
			_ln([4.5, 14.5, 8, 14.5, 8, 20.5, 4.5, 20.5], true)
			_ln([16, 14.5, 19.5, 14.5, 19.5, 20.5, 16, 20.5], true)
			_ln([8, 6.5, 16, 6.5])
			_ln([8, 17.5, 16, 17.5])
			_ln([12, 6.5, 12, 17.5])
		"weight":
			_ln([7.5, 9, 16.5, 9, 20, 20, 4, 20], true)
			_circ(12, 5.8, 2.4)
		"gauge":
			_arc(12, 14, 9, PI * 0.85, PI * 2.15)
			_ln([12, 14, 17, 8.5])
			_circ(12, 14, 1.4, true)
		"power":
			_circ(12, 12, 9.2)
			_circ(12, 12, 5.4)
			_circ(12, 12, 1.8, true)
		"check":
			_ln([4.5, 12.5, 10, 18, 19.5, 6.5])
		"swap":
			_ln([4, 8, 19, 8])
			_ln([15, 4, 19.5, 8, 15, 12])
			_ln([20, 16, 5, 16])
			_ln([9, 12, 4.5, 16, 9, 20])
		"bolt":
			draw_colored_polygon(_pts([13.5, 2.5, 5.5, 13.5, 11, 13.5, 10, 21.5, 18.5, 10, 12.8, 10]), color)
		"trophy":
			_ln([7, 4, 17, 4, 16.5, 10, 14, 13, 10, 13, 7.5, 10], true)
			_ln([12, 13, 12, 17])
			_ln([8, 20, 16, 20])
			_arc(5.5, 7.5, 2.5, PI * 0.5, PI * 1.5)
			_arc(18.5, 7.5, 2.5, -PI * 0.5, PI * 0.5)
		"road":
			_ln([8, 3, 3.5, 21])
			_ln([16, 3, 20.5, 21])
			_ln([12, 4, 12, 8])
			_ln([12, 11, 12, 15])
			_ln([12, 18, 12, 21])
		"flag":
			_ln([6, 21, 6, 3])
			_ln([6, 4, 19, 4, 16, 8.5, 19, 13, 6, 13], true)
		"lock":
			_ln([6, 11, 18, 11, 18, 20, 6, 20], true)
			_arc(12, 11, 4.5, PI, TAU)
		"mountain":
			_ln([2, 20, 9, 7, 13, 14, 16, 10, 22, 20], false)
			_ln([2, 20, 22, 20])
		"world":
			_circ(12, 12, 9.2)
			_ln([2.8, 12, 21.2, 12])
			_arc(12, 12, 9.2, PI * 0.5 - 0.9, PI * 0.5 + 0.9)
			_ln([12, 2.8, 12, 21.2])
		"bag":
			_ln([5, 8, 19, 8, 20, 20, 4, 20], true)
			_arc(12, 8, 4, PI, TAU)
		"info":
			_circ(12, 12, 9.2)
			_ln([12, 11, 12, 17])
			_circ(12, 7.6, 1.2, true)
