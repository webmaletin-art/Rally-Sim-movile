extends Control
## Hojas de la guía del Modo de prueba (20/10/2026, pedido del dueño: «en la pausa, a la derecha, una imagen con botones atrás y adelante con ayuda de reglaje, suspensión, cámaras, volante,
## tracciones»). Los dibujos están hechos con código (sin imágenes): se ven nítidos en cualquier pantalla y no pesan en el APK.
## index = la hoja que se ve; next() / prev() pasan de hoja; el que lo usa pone los botones y el contador.

const Tr := preload("res://game/i18n/tr.gd")

## id, título, texto (en español: se traduce con Tr.t)
const SLIDES := [
	{"id": "motor", "title": "MOTOR: POTENCIA, PESO Y AIRE", "text": "Más potencia acelera más, pero las ruedas patinan más (ideal para el drift). Con menos peso el auto acelera, frena y dobla mejor. La resistencia al aire frena el auto a alta velocidad: con menos llegás más rápido."},
	{"id": "agarre", "title": "AGARRE: GOMAS Y PRESIÓN", "text": "Las gomas blandas agarran más y las duras se deslizan: para el drift conviene poco agarre atrás. Con menos presión la goma apoya más superficie. La caída negativa (la rueda inclinada hacia adentro) da más agarre en la curva."},
	{"id": "susp", "title": "SUSPENSIÓN", "text": "Los resortes duros responden rápido y evitan que el auto se hamaque; los blandos absorben mejor los baches y los lomos de burro. Los amortiguadores frenan el rebote: si el auto rebota mucho, subí el amortiguador."},
	{"id": "frenos", "title": "FRENOS", "text": "El reparto de frenado decide qué ruedas frenan más. Más freno adelante: el auto entra recto y estable. Más freno atrás: la cola se suelta y ayuda a meter el auto de costado."},
	{"id": "trac", "title": "TRANSMISIÓN Y TRACCIÓN", "text": "Delantera: estable y fácil. Trasera: la reina del drift, porque las ruedas de atrás patinan y empujan el auto de costado. Integral: mucho agarre al salir de las curvas. El reparto se cambia en el reglaje de transmisión."},
	{"id": "aero", "title": "AERODINÁMICA", "text": "El aire empuja el auto contra el piso: con más carga aerodinámica agarra más en las curvas rápidas, pero también lo frena en las rectas. A baja velocidad casi no se nota."},
	{"id": "camaras", "title": "CÁMARAS", "text": "Onboard (casco): la más realista. Interior, capó y paragolpes: más sensación de velocidad. Persecución y aérea: ven todo el auto y el derrape. Se cambian con el botón de cámara de arriba."},
	{"id": "volante", "title": "VOLANTE Y NIVEL DE SIMULACIÓN", "text": "En Arcade el volante de la pantalla gira tres cuartos de vuelta de tope a tope. En el volante real hay que girar el dedo de verdad: hasta tres vueltas de tope a tope, y más con el ángulo de dirección en 130 %."},
	{"id": "drift", "title": "DRIFT", "text": "Se derrapa con el auto de costado, a más de 20 km/h. Los puntos suben con la velocidad y el ángulo, y el multiplicador sube cada 2 segundos seguidos. Chocar pierde el derrape; un cono baja el multiplicador."},
	{"id": "nafta", "title": "NAFTA Y LOMOS DE BURRO", "text": "El tanque baja con la velocidad. Frená adentro del cuadrado verde, en la esquina de la nafta, para cargar. En la esquina de pruebas hay lomos de burro: pasalos a distintas velocidades para probar la suspensión."},
]

var index := 0

func _init() -> void:
	custom_minimum_size = Vector2(460, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func count() -> int:
	return SLIDES.size()

## Número de hoja de un id («susp», «camaras»…); −1 si no existe
static func index_of(id: String) -> int:
	for i in SLIDES.size():
		if str(SLIDES[i]["id"]) == id:
			return i
	return -1

func show_id(id: String) -> void:
	var i := index_of(id)
	if i >= 0:
		set_index(i)

func set_index(i: int) -> void:
	index = posmod(i, SLIDES.size())
	queue_redraw()

func next() -> void:
	set_index(index + 1)

func prev() -> void:
	set_index(index - 1)

func title_of(i: int) -> String:
	return Tr.t(str(SLIDES[posmod(i, SLIDES.size())]["title"]))

func _draw() -> void:
	var sz := size
	if sz.x < 40.0 or sz.y < 40.0:
		return
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.05, 0.07, 0.11, 0.94), true)
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.4, 0.75, 1.0, 0.45), false, 2.0)
	var s: Dictionary = SLIDES[index]
	var font := get_theme_default_font()
	var area := Rect2(10.0, 44.0, sz.x - 20.0, sz.y * 0.5)
	draw_string(font, Vector2(14.0, 30.0), Tr.t(str(s["title"])), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 28.0, 22, Color(1.0, 0.62, 0.2))
	draw_rect(area, Color(0.09, 0.12, 0.18, 1.0), true)
	match str(s["id"]):
		"motor": _motor(area)
		"agarre": _agarre(area)
		"aero": _aero(area)
		"susp": _susp(area)
		"trac": _trac(area)
		"frenos": _frenos(area)
		"camaras": _camaras(area)
		"volante": _volante(area)
		"drift": _drift(area)
		"nafta": _nafta(area)
	var ty := area.end.y + 18.0
	draw_multiline_string(font, Vector2(14.0, ty), Tr.t(str(s["text"])), HORIZONTAL_ALIGNMENT_LEFT, sz.x - 28.0, 15, 6, Color(0.88, 0.92, 1.0))

# ───────────────────────── dibujos ─────────────────────────
func _arrow(a: Vector2, b: Vector2, col: Color, w := 3.0) -> void:
	draw_line(a, b, col, w, true)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([b, b - d * 11.0 + n * 6.0, b - d * 11.0 - n * 6.0]), col)

## Auto visto desde arriba (c = centro, k = escala, rot = giro en radianes, el frente mira hacia arriba con rot = 0)
func _car_top(c: Vector2, k: float, rot: float, body := Color(0.85, 0.2, 0.18), wheels := Color(0.12, 0.12, 0.14)) -> void:
	var xf := Transform2D(rot, c)
	var pts := PackedVector2Array([Vector2(-18, -44), Vector2(18, -44), Vector2(22, -30), Vector2(22, 38), Vector2(16, 46), Vector2(-16, 46), Vector2(-22, 38), Vector2(-22, -30)])
	for i in pts.size():
		pts[i] = xf * (pts[i] * k)
	draw_colored_polygon(pts, body)
	var win := PackedVector2Array([Vector2(-13, -14), Vector2(13, -14), Vector2(15, 8), Vector2(-15, 8)])
	for i in win.size():
		win[i] = xf * (win[i] * k)
	draw_colored_polygon(win, Color(0.12, 0.18, 0.25))
	for wp in [Vector2(-25, -30), Vector2(25, -30), Vector2(-25, 30), Vector2(25, 30)]:
		var q := PackedVector2Array([Vector2(-5, -11), Vector2(5, -11), Vector2(5, 11), Vector2(-5, 11)])
		for i in q.size():
			q[i] = xf * ((q[i] + wp) * k)
		draw_colored_polygon(q, wheels)

func _susp(a: Rect2) -> void:
	var c := a.get_center()
	var base_y := a.end.y - 34.0
	# piso con un lomo de burro
	draw_line(Vector2(a.position.x + 6.0, base_y), Vector2(a.end.x - 6.0, base_y), Color(0.55, 0.55, 0.6), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x + 70.0, base_y), Vector2(c.x + 88.0, base_y - 12.0), Vector2(c.x + 112.0, base_y - 12.0), Vector2(c.x + 130.0, base_y)]), Color(0.95, 0.78, 0.15))
	# carrocería de costado
	var body := Rect2(c.x - 120.0, base_y - 92.0, 240.0, 40.0)
	draw_rect(body, Color(0.85, 0.2, 0.18), true)
	draw_rect(Rect2(c.x - 50.0, base_y - 118.0, 100.0, 28.0), Color(0.75, 0.16, 0.14), true)
	for wx in [-78.0, 78.0]:
		var wc := Vector2(c.x + float(wx), base_y - 20.0)
		draw_circle(wc, 22.0, Color(0.1, 0.1, 0.12))
		draw_circle(wc, 11.0, Color(0.6, 0.62, 0.68))
		# resorte (zigzag) y amortiguador entre la rueda y la carrocería
		var top := Vector2(wc.x - 9.0, body.end.y)
		var pts := PackedVector2Array()
		for i in 9:
			pts.append(Vector2(top.x + (7.0 if i % 2 == 0 else -7.0), top.y + float(i) * (wc.y - 18.0 - top.y) / 8.0))
		draw_polyline(pts, Color(1.0, 0.8, 0.2), 3.0, true)
		draw_rect(Rect2(wc.x + 6.0, body.end.y, 7.0, wc.y - 16.0 - body.end.y), Color(0.7, 0.75, 0.85), true)
	_arrow(Vector2(c.x - 40.0, a.position.y + 26.0), Vector2(c.x - 40.0, a.position.y + 52.0), Color(0.5, 0.9, 0.55))
	draw_string(get_theme_default_font(), Vector2(a.position.x + 14.0, a.position.y + 22.0), Tr.t("DURO ▲ rápido"), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 13, Color(0.5, 0.9, 0.55))
	draw_string(get_theme_default_font(), Vector2(a.end.x - 160.0, a.position.y + 22.0), Tr.t("BLANDO ▼ cómodo"), HORIZONTAL_ALIGNMENT_RIGHT, 150.0, 13, Color(0.55, 0.8, 1.0))

func _trac(a: Rect2) -> void:
	var font := get_theme_default_font()
	var names := ["DELANTERA", "TRASERA", "INTEGRAL"]
	var w := a.size.x / 3.0
	for i in 3:
		var c := Vector2(a.position.x + w * (float(i) + 0.5), a.get_center().y + 2.0)
		_car_top(c, 0.95, 0.0)
		var col := Color(1.0, 0.62, 0.2)
		var front := i == 0 or i == 2
		var rear := i == 1 or i == 2
		for sx in [-1.0, 1.0]:
			if front:
				_arrow(c + Vector2(float(sx) * 24.0, -18.0), c + Vector2(float(sx) * 24.0, -52.0), col, 4.0)
			if rear:
				_arrow(c + Vector2(float(sx) * 24.0, 38.0), c + Vector2(float(sx) * 24.0, 4.0), col, 4.0)
		draw_string(font, Vector2(c.x - w * 0.5, a.end.y - 8.0), Tr.t(str(names[i])), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.9, 0.93, 1.0))

func _frenos(a: Rect2) -> void:
	var c := a.get_center()
	_car_top(Vector2(c.x - 90.0, c.y), 1.2, 0.0)
	var font := get_theme_default_font()
	var bar := Rect2(c.x + 10.0, c.y - 62.0, 150.0, 124.0)
	draw_rect(bar, Color(0.16, 0.19, 0.26), true)
	var front_h := bar.size.y * 0.6
	draw_rect(Rect2(bar.position.x, bar.position.y, bar.size.x, front_h), Color(0.95, 0.45, 0.2), true)
	draw_rect(Rect2(bar.position.x, bar.position.y + front_h, bar.size.x, bar.size.y - front_h), Color(0.3, 0.6, 0.95), true)
	draw_string(font, Vector2(bar.position.x, bar.position.y + 22.0), Tr.t("ADELANTE 60 %"), HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 14, Color.WHITE)
	draw_string(font, Vector2(bar.position.x, bar.end.y - 12.0), Tr.t("ATRÁS 40 %"), HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 14, Color.WHITE)
	_arrow(Vector2(c.x - 90.0, c.y - 80.0), Vector2(c.x - 90.0, c.y - 56.0), Color(1.0, 0.85, 0.3))

func _camaras(a: Rect2) -> void:
	var c := a.get_center()
	var font := get_theme_default_font()
	# auto de costado, mirando a la derecha
	var base_y := c.y + 26.0
	draw_rect(Rect2(c.x - 110.0, base_y - 38.0, 220.0, 34.0), Color(0.85, 0.2, 0.18), true)
	draw_rect(Rect2(c.x - 40.0, base_y - 64.0, 90.0, 28.0), Color(0.7, 0.15, 0.13), true)
	for wx in [-70.0, 70.0]:
		draw_circle(Vector2(c.x + float(wx), base_y - 2.0), 17.0, Color(0.1, 0.1, 0.12))
	var cams := [["CASCO", Vector2(c.x + 10.0, base_y - 54.0), Vector2(1, 0)], ["CAPÓ", Vector2(c.x + 70.0, base_y - 40.0), Vector2(1, 0)], ["PARAGOLPES", Vector2(c.x + 112.0, base_y - 18.0), Vector2(1, 0)],
		["PERSECUCIÓN", Vector2(c.x - 170.0, base_y - 70.0), Vector2(1, 0.12)], ["AÉREA", Vector2(c.x - 40.0, a.position.y + 20.0), Vector2(0.3, 1)]]
	for cm in cams:
		var p: Vector2 = cm[1]
		var d: Vector2 = (cm[2] as Vector2).normalized()
		var n := Vector2(-d.y, d.x)
		draw_colored_polygon(PackedVector2Array([p, p + d * 46.0 + n * 14.0, p + d * 46.0 - n * 14.0]), Color(1.0, 0.82, 0.2, 0.28))
		draw_circle(p, 5.0, Color(1.0, 0.82, 0.2))
		var off := Vector2(-4.0, -10.0)
		if str(cm[0]) == "PARAGOLPES":
			off = Vector2(-20.0, 22.0)
		draw_string(font, p + off, Tr.t(str(cm[0])), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 11, Color(0.95, 0.95, 0.85))

func _volante(a: Rect2) -> void:
	var c := Vector2(a.position.x + a.size.x * 0.3, a.get_center().y)
	var r := minf(a.size.y * 0.38, 70.0)
	var font := get_theme_default_font()
	draw_arc(c, r, 0.0, TAU, 48, Color(0.75, 0.78, 0.85), 8.0, true)
	for k in 3:
		var ang := float(k) * TAU / 3.0 - PI / 2.0
		draw_line(c, c + Vector2(cos(ang), sin(ang)) * r, Color(0.75, 0.78, 0.85), 6.0, true)
	draw_circle(c, 14.0, Color(0.55, 0.58, 0.66))
	draw_arc(c, r + 16.0, -PI * 0.5, PI * 0.5, 24, Color(1.0, 0.62, 0.2), 4.0, true)
	_arrow(c + Vector2(0.0, -r - 16.0) + Vector2(-2.0, 0.0), c + Vector2(r + 16.0, 0.0) + Vector2(0.0, -2.0), Color(1.0, 0.62, 0.2))
	var tx := a.position.x + a.size.x * 0.55
	draw_string(font, Vector2(tx, a.position.y + 40.0), Tr.t("ARCADE: ¾ de vuelta"), HORIZONTAL_ALIGNMENT_LEFT, a.size.x * 0.43, 15, Color(0.55, 0.9, 0.6))
	draw_string(font, Vector2(tx, a.position.y + 66.0), Tr.t("REAL 50 %: 1 vuelta y media"), HORIZONTAL_ALIGNMENT_LEFT, a.size.x * 0.43, 15, Color(1.0, 0.85, 0.35))
	draw_string(font, Vector2(tx, a.position.y + 92.0), Tr.t("REAL 100 %: 3 vueltas"), HORIZONTAL_ALIGNMENT_LEFT, a.size.x * 0.43, 15, Color(1.0, 0.5, 0.35))

func _drift(a: Rect2) -> void:
	var c := a.get_center()
	var font := get_theme_default_font()
	# trayectoria curva y el auto de costado
	var path := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		path.append(Vector2(a.position.x + 20.0 + t * (a.size.x - 60.0), a.end.y - 28.0 - sin(t * PI) * (a.size.y - 70.0) * 0.8))
	draw_polyline(path, Color(0.5, 0.55, 0.65, 0.6), 3.0, true)
	var p := path[12]
	var dir := (path[13] - path[11]).normalized()
	var heading := atan2(dir.x, -dir.y) # (el frente del dibujo mira hacia arriba)
	_car_top(p, 0.55, heading - 0.65)
	_arrow(p, p + dir * 52.0, Color(0.4, 0.9, 1.0), 3.0)
	var nose := Vector2(sin(heading - 0.65), -cos(heading - 0.65))
	_arrow(p, p + nose * 52.0, Color(1.0, 0.62, 0.2), 3.0)
	draw_string(font, p + Vector2(40.0, -34.0), Tr.t("ÁNGULO"), HORIZONTAL_ALIGNMENT_LEFT, 90.0, 13, Color(1.0, 0.85, 0.35))
	draw_string(font, Vector2(a.position.x + 12.0, a.position.y + 22.0), Tr.t("PUNTOS = velocidad × ángulo × multiplicador"), HORIZONTAL_ALIGNMENT_LEFT, a.size.x - 24.0, 13, Color(0.7, 0.95, 1.0))

func _nafta(a: Rect2) -> void:
	var c := Vector2(a.position.x + a.size.x * 0.28, a.end.y - 40.0)
	var r := minf(a.size.y * 0.7, 80.0)
	var font := get_theme_default_font()
	draw_arc(c, r, PI, TAU, 40, Color(0.35, 0.4, 0.5), 10.0, true)
	draw_arc(c, r, PI, PI + PI * 0.2, 12, Color(0.95, 0.3, 0.25), 10.0, true)
	draw_arc(c, r, PI + PI * 0.2, TAU, 32, Color(0.3, 0.85, 0.45), 10.0, true)
	var ang := PI + PI * 0.7
	draw_line(c, c + Vector2(cos(ang), sin(ang)) * (r - 8.0), Color.WHITE, 4.0, true)
	draw_circle(c, 7.0, Color.WHITE)
	draw_string(font, c + Vector2(-r, 22.0), "⛽", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 20, Color.WHITE)
	# cuadrado verde y lomo de burro
	var gx := a.position.x + a.size.x * 0.58
	draw_rect(Rect2(gx, a.position.y + 26.0, 70.0, 56.0), Color(0.15, 0.65, 0.3), true)
	draw_rect(Rect2(gx, a.position.y + 26.0, 70.0, 56.0), Color(0.9, 0.95, 0.9), false, 2.0)
	_car_top(Vector2(gx + 35.0, a.position.y + 54.0), 0.4, 0.0)
	var by := a.end.y - 24.0
	draw_line(Vector2(gx - 6.0, by), Vector2(a.end.x - 10.0, by), Color(0.55, 0.55, 0.6), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(gx + 28.0, by), Vector2(gx + 44.0, by - 14.0), Vector2(gx + 76.0, by - 14.0), Vector2(gx + 92.0, by)]), Color(0.95, 0.78, 0.15))
	draw_string(font, Vector2(gx - 6.0, by + 16.0), Tr.t("LOMO DE BURRO"), HORIZONTAL_ALIGNMENT_LEFT, 150.0, 12, Color(0.95, 0.85, 0.4))

func _motor(a: Rect2) -> void:
	var font := get_theme_default_font()
	var w := a.size.x / 3.0
	# 1) curva de potencia
	var x0 := a.position.x + 14.0
	var y0 := a.end.y - 36.0
	var cw := w - 30.0
	var ch := a.size.y - 78.0
	draw_line(Vector2(x0, y0), Vector2(x0 + cw, y0), Color(0.55, 0.58, 0.66), 2.0)
	draw_line(Vector2(x0, y0), Vector2(x0, y0 - ch), Color(0.55, 0.58, 0.66), 2.0)
	var low := PackedVector2Array()
	var high := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		var base := sin(t * PI * 0.92 + 0.12) * (1.0 - 0.25 * t)
		low.append(Vector2(x0 + t * cw, y0 - base * ch * 0.5))
		high.append(Vector2(x0 + t * cw, y0 - base * ch * 0.95))
	draw_polyline(low, Color(0.55, 0.8, 1.0, 0.8), 3.0, true)
	draw_polyline(high, Color(1.0, 0.62, 0.2), 3.5, true)
	_arrow(Vector2(x0 + cw * 0.5, y0 - ch * 0.42), Vector2(x0 + cw * 0.5, y0 - ch * 0.82), Color(1.0, 0.85, 0.3))
	draw_string(font, Vector2(x0 - 6.0, a.end.y - 8.0), Tr.t("POTENCIA"), HORIZONTAL_ALIGNMENT_CENTER, cw + 12.0, 13, Color(0.9, 0.93, 1.0))
	# 2) peso: una pesa y una pluma
	var c2 := Vector2(a.position.x + w * 1.5, a.get_center().y - 4.0)
	draw_colored_polygon(PackedVector2Array([c2 + Vector2(-34.0, 26.0), c2 + Vector2(34.0, 26.0), c2 + Vector2(24.0, -18.0), c2 + Vector2(-24.0, -18.0)]), Color(0.45, 0.48, 0.56))
	draw_arc(c2 + Vector2(0.0, -18.0), 12.0, PI, TAU, 14, Color(0.45, 0.48, 0.56), 5.0, true)
	draw_string(font, c2 + Vector2(-30.0, 17.0), "kg", HORIZONTAL_ALIGNMENT_CENTER, 60.0, 17, Color.WHITE)
	draw_string(font, Vector2(a.position.x + w, a.end.y - 8.0), Tr.t("PESO"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.9, 0.93, 1.0))
	# 3) aire: el auto de costado y las flechas del viento en contra
	var c3 := Vector2(a.position.x + w * 2.55, a.get_center().y)
	draw_rect(Rect2(c3.x - 46.0, c3.y - 8.0, 92.0, 22.0), Color(0.85, 0.2, 0.18), true)
	draw_rect(Rect2(c3.x - 20.0, c3.y - 26.0, 44.0, 20.0), Color(0.7, 0.15, 0.13), true)
	for wx in [-26.0, 26.0]:
		draw_circle(Vector2(c3.x + float(wx), c3.y + 14.0), 10.0, Color(0.1, 0.1, 0.12))
	for k in 3:
		var yy := c3.y - 22.0 + float(k) * 18.0
		_arrow(Vector2(c3.x + 94.0, yy), Vector2(c3.x + 54.0, yy), Color(0.55, 0.85, 1.0), 3.0)
	draw_string(font, Vector2(a.position.x + w * 2.0, a.end.y - 8.0), Tr.t("AIRE"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.9, 0.93, 1.0))

func _agarre(a: Rect2) -> void:
	var font := get_theme_default_font()
	var w := a.size.x / 3.0
	var base_y := a.end.y - 50.0
	# 1) rueda de frente con la huella marcada
	var c1 := Vector2(a.position.x + w * 0.5, base_y - 34.0)
	draw_rect(Rect2(c1.x - 22.0, c1.y - 34.0, 44.0, 68.0), Color(0.1, 0.1, 0.12), true)
	draw_rect(Rect2(c1.x - 22.0, base_y - 5.0, 44.0, 5.0), Color(1.0, 0.62, 0.2), true)
	draw_line(Vector2(a.position.x + 8.0, base_y), Vector2(a.position.x + w - 8.0, base_y), Color(0.55, 0.55, 0.6), 3.0)
	draw_string(font, Vector2(a.position.x, a.end.y - 8.0), Tr.t("HUELLA"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.9, 0.93, 1.0))
	# 2) caída negativa: la rueda inclinada hacia adentro
	var c2 := Vector2(a.position.x + w * 1.5, base_y - 34.0)
	var xf := Transform2D(0.2, Vector2(c2.x, base_y - 2.0))
	var q := PackedVector2Array([Vector2(-22.0, -66.0), Vector2(22.0, -66.0), Vector2(22.0, 0.0), Vector2(-22.0, 0.0)])
	for i in q.size():
		q[i] = xf * q[i]
	draw_colored_polygon(q, Color(0.1, 0.1, 0.12))
	draw_line(Vector2(c2.x - 40.0, base_y), Vector2(c2.x + 40.0, base_y), Color(0.55, 0.55, 0.6), 3.0)
	draw_dashed_line(Vector2(c2.x, base_y - 80.0), Vector2(c2.x, base_y), Color(1.0, 1.0, 1.0, 0.5), 1.5, 5.0)
	draw_string(font, Vector2(a.position.x + w, a.end.y - 8.0), Tr.t("CAÍDA"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.9, 0.93, 1.0))
	# 3) presión: un manómetro
	var c3 := Vector2(a.position.x + w * 2.5, base_y - 8.0)
	var r := minf(w * 0.34, 46.0)
	draw_arc(c3, r, PI, TAU, 32, Color(0.35, 0.4, 0.5), 8.0, true)
	draw_arc(c3, r, PI, PI * 1.35, 10, Color(0.3, 0.6, 0.95), 8.0, true)
	draw_arc(c3, r, PI * 1.35, PI * 1.7, 10, Color(0.3, 0.85, 0.45), 8.0, true)
	draw_arc(c3, r, PI * 1.7, TAU, 10, Color(0.95, 0.3, 0.25), 8.0, true)
	var ang := PI * 1.52
	draw_line(c3, c3 + Vector2(cos(ang), sin(ang)) * (r - 6.0), Color.WHITE, 3.0, true)
	draw_circle(c3, 5.0, Color.WHITE)
	draw_string(font, Vector2(a.position.x + w * 2.0, a.end.y - 8.0), Tr.t("PRESIÓN"), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(0.9, 0.93, 1.0))
	draw_string(font, Vector2(a.position.x + 12.0, a.position.y + 22.0), Tr.t("Blandas = más agarre · Duras = se deslizan"), HORIZONTAL_ALIGNMENT_LEFT, a.size.x - 24.0, 13, Color(0.7, 0.95, 1.0))

func _aero(a: Rect2) -> void:
	var c := a.get_center()
	var font := get_theme_default_font()
	var base_y := c.y + 34.0
	draw_line(Vector2(a.position.x + 8.0, base_y), Vector2(a.end.x - 8.0, base_y), Color(0.55, 0.55, 0.6), 3.0)
	# auto de costado con alerón atrás y labio adelante
	draw_rect(Rect2(c.x - 100.0, base_y - 36.0, 200.0, 26.0), Color(0.85, 0.2, 0.18), true)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 40.0, base_y - 36.0), Vector2(c.x + 50.0, base_y - 36.0), Vector2(c.x + 28.0, base_y - 58.0), Vector2(c.x - 22.0, base_y - 58.0)]), Color(0.7, 0.15, 0.13))
	draw_rect(Rect2(c.x - 100.0, base_y - 60.0, 44.0, 5.0), Color(0.15, 0.15, 0.17), true)
	draw_rect(Rect2(c.x - 92.0, base_y - 56.0, 5.0, 20.0), Color(0.15, 0.15, 0.17), true)
	draw_rect(Rect2(c.x + 90.0, base_y - 14.0, 24.0, 4.0), Color(0.15, 0.15, 0.17), true)
	for wx in [-62.0, 62.0]:
		draw_circle(Vector2(c.x + float(wx), base_y - 10.0), 16.0, Color(0.1, 0.1, 0.12))
	# la carga aerodinámica empuja hacia abajo, el aire va hacia atrás
	_arrow(Vector2(c.x - 78.0, base_y - 100.0), Vector2(c.x - 78.0, base_y - 66.0), Color(0.5, 0.9, 0.55), 4.0)
	_arrow(Vector2(c.x + 100.0, base_y - 70.0), Vector2(c.x + 100.0, base_y - 22.0), Color(0.5, 0.9, 0.55), 4.0)
	for k in 3:
		var yy := base_y - 90.0 + float(k) * 20.0
		_arrow(Vector2(c.x + 150.0, yy), Vector2(c.x + 120.0, yy), Color(0.55, 0.85, 1.0), 2.5)
	draw_string(font, Vector2(a.position.x + 12.0, a.position.y + 22.0), Tr.t("CARGA ▼ agarre · RESISTENCIA ◀ frena"), HORIZONTAL_ALIGNMENT_LEFT, a.size.x - 24.0, 13, Color(0.7, 0.95, 1.0))

