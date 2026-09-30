extends Control
## Controles en pantalla de GSkorp Rally, portados de la versión HTML (Input en js/main.js + estilos del HUD):
##  · VOLANTE: se gira con el dedo (el ángulo del dedo alrededor del centro, ×1,35; hasta 3 vueltas medias) y vuelve solo al soltar.
##  · BARRA de dirección (modo alternativo): se desliza el dedo a izquierda/derecha.
##  · PEDAL único: arriba de la mitad acelera, abajo de la mitad frena.
##  · TIRA DE CAMBIOS (caja manual): deslizar 30 px = un cambio, o tocar ▲ / ▼.
##  · FRENO DE MANO y NITRO (mantener apretado).
##  · ACELERÓMETRO: inclinar el teléfono como un volante (con calibración).
## Todo se dimensiona en "unidades HTML" (u = alto de pantalla / 393): así el tamaño relativo es el mismo que en la versión web.
## Multitáctil: cada dedo queda asignado al control que tocó primero.

signal camera_pressed
signal pause_pressed

# ── opciones (las carga el juego) ──
var steer_mode := "wheel" # "wheel" | "slider"
var manual := false
var has_nitro := false
var gyro_on := false
var gyro_invert := false
var gyro_sens := 50.0 # 0..100 → cuánto hay que inclinar
var use_mph := false
var show_speed := true # el panel de velocidad de arriba se oculta con las cámaras interiores (ya está en el tablero)
var layout := {} # id → {x, y, s}: posición (fracción de pantalla) y tamaño relativo, para el editor de controles

# ── salidas ──
var steer := 0.0 # -1 izquierda … +1 derecha (igual que en la versión HTML)
var gas := 0.0
var brake := 0.0
var handbrake := false
var nitro := false
var shift := 0 # -1 / 0 / +1: cambio pedido este cuadro (ya consumido de la cola)

# ── datos para el tablero ──
var speed_kmh := 0.0
var gear_text := "N"
var rpm_frac := 0.0
var nitro_frac := 1.0
var limited := false # limitador de vueltas (para la luz del tablero)

# ── estado interno ──
var wheel_rotation := 0.0
var wheel_visual := 0.0
var wheel_target := 0.0
var wheel_touch_angle := 0.0
var slider_target := 0.0
var pedal_v := 0.0
var shift_queue := 0
var _touch := {} # índice de dedo → {kind, …}
var _flash_up := 0.0
var _flash_dn := 0.0
var _gyro_calib := INF
var _gyro_raw := 0.0
var _gyro_steer := 0.0

const ITEMS := ["wheel", "slider", "pedal", "gears", "handbrake", "nitro"]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

# ───────────────────────── geometría ─────────────────────────
func _vs() -> Vector2:
	return get_viewport_rect().size

func _u() -> float:
	return _vs().y / 393.0

## Rectángulo de un control en pantalla (posición base del HTML + lo que movió el jugador en el editor)
func rect_of(id: String) -> Rect2:
	var vs := _vs()
	var u := _u()
	var r := Rect2()
	match id:
		"wheel":
			r = Rect2(16.0 * u, vs.y - 30.0 * u - 158.0 * u, 158.0 * u, 158.0 * u)
		"slider":
			var w := minf(0.58 * vs.x, 400.0 * u)
			r = Rect2(16.0 * u, vs.y - 30.0 * u - 64.0 * u, w, 64.0 * u)
		"pedal":
			var h := 0.58 * vs.y
			r = Rect2(vs.x - 18.0 * u - 70.0 * u, (vs.y - h) * 0.5, 70.0 * u, h)
		"gears":
			r = Rect2(190.0 * u, vs.y - 30.0 * u - 158.0 * u, 64.0 * u, 158.0 * u)
		"handbrake":
			r = Rect2(vs.x - 100.0 * u - 64.0 * u, vs.y - 22.0 * u - 64.0 * u, 64.0 * u, 64.0 * u)
		"nitro":
			r = Rect2(vs.x - 100.0 * u - 64.0 * u, vs.y - 100.0 * u - 64.0 * u, 64.0 * u, 64.0 * u)
		"cam":
			r = Rect2(vs.x - 10.0 * u - 40.0 * u, 10.0 * u, 40.0 * u, 40.0 * u)
		"pause":
			r = Rect2(vs.x - 18.0 * u - 80.0 * u, 10.0 * u, 40.0 * u, 40.0 * u)
	var L: Dictionary = layout.get(id, {})
	if not L.is_empty():
		var s: float = float(L.get("s", 1.0))
		var c := r.get_center() + Vector2(float(L.get("x", 0.0)) * vs.x, float(L.get("y", 0.0)) * vs.y)
		r = Rect2(c - r.size * s * 0.5, r.size * s)
	return r

func _active_items() -> Array:
	var a := ["pedal", "handbrake"]
	a.append("wheel" if steer_mode == "wheel" else "slider")
	if manual:
		a.append("gears")
	if has_nitro:
		a.append("nitro")
	if gyro_on:
		a.erase("wheel")
		a.erase("slider")
	return a

# ───────────────────────── entrada táctil ─────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if ev.pressed:
			_touch_down(ev.index, ev.position)
		else:
			_touch_up(ev.index)
	elif event is InputEventScreenDrag:
		var ev2 := event as InputEventScreenDrag
		_touch_move(ev2.index, ev2.position)

func _hit(pos: Vector2) -> String:
	for id in ["cam", "pause"]:
		if rect_of(id).grow(4.0 * _u()).has_point(pos):
			return id
	for id in ["pedal", "handbrake", "nitro", "gears"]:
		if id in _active_items() and rect_of(id).grow(6.0 * _u()).has_point(pos):
			return id
	if "wheel" in _active_items():
		var r := rect_of("wheel")
		if pos.distance_to(r.get_center()) <= r.size.x * 0.56:
			return "wheel"
	if "slider" in _active_items() and rect_of("slider").grow(8.0 * _u()).has_point(pos):
		return "slider"
	return ""

func _taken(kind: String) -> bool:
	for k in _touch:
		if _touch[k]["kind"] == kind:
			return true
	return false

func _touch_down(idx: int, pos: Vector2) -> void:
	var id := _hit(pos)
	if id == "" or _taken(id):
		return
	_touch[idx] = {"kind": id, "y0": pos.y, "moved": false}
	match id:
		"cam":
			camera_pressed.emit()
		"pause":
			pause_pressed.emit()
		"wheel":
			var c := rect_of("wheel").get_center()
			wheel_touch_angle = atan2(pos.y - c.y, pos.x - c.x)
		"slider":
			_slider_from_x(pos.x)
		"pedal":
			_pedal_from_y(pos.y)
		"handbrake":
			handbrake = true
		"nitro":
			nitro = true

func _touch_move(idx: int, pos: Vector2) -> void:
	if not _touch.has(idx):
		return
	var t: Dictionary = _touch[idx]
	match t["kind"]:
		"wheel":
			var c := rect_of("wheel").get_center()
			var a := atan2(pos.y - c.y, pos.x - c.x)
			var d := wrapf(a - wheel_touch_angle, -PI, PI)
			wheel_touch_angle = a
			wheel_rotation = clampf(wheel_rotation + d * 1.35, -PI * 3.0, PI * 3.0)
			wheel_target = clampf(wheel_rotation / PI, -1.0, 1.0)
		"slider":
			_slider_from_x(pos.x)
		"pedal":
			_pedal_from_y(pos.y)
		"gears":
			var dy: float = pos.y - float(t["y0"])
			if absf(dy) > 30.0 * _u():
				_request_shift(1 if dy < 0.0 else -1)
				t["y0"] = pos.y
				t["moved"] = true

func _touch_up(idx: int) -> void:
	if not _touch.has(idx):
		return
	var t: Dictionary = _touch[idx]
	_touch.erase(idx)
	match t["kind"]:
		"wheel":
			wheel_target = 0.0
		"slider":
			slider_target = 0.0
		"pedal":
			pedal_v = 0.0
			gas = 0.0
			brake = 0.0
		"handbrake":
			handbrake = false
		"nitro":
			nitro = false
		"gears":
			if not t["moved"]:
				var r := rect_of("gears")
				_request_shift(1 if float(t["y0"]) < r.position.y + r.size.y * 0.5 else -1)

func _slider_from_x(x: float) -> void:
	var r := rect_of("slider")
	var rel := clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	slider_target = clampf((rel - 0.5) * 2.0, -1.0, 1.0)

func _pedal_from_y(y: float) -> void:
	var r := rect_of("pedal")
	var rel := clampf((r.end.y - y) / r.size.y, 0.0, 1.0)
	var v := clampf((rel - 0.5) * 2.0, -1.0, 1.0)
	pedal_v = v
	gas = v if v >= 0.0 else 0.0
	brake = -v if v < 0.0 else 0.0

func _request_shift(d: int) -> void:
	shift_queue = clampi(shift_queue + d, -3, 3)
	if d > 0:
		_flash_up = 0.14
	else:
		_flash_dn = 0.14

# ───────────────────────── acelerómetro ─────────────────────────
func gyro_tilt_for_full() -> float:
	return 55.0 - gyro_sens * 0.40 # grados de giro para el máximo (igual que la versión HTML)

func recalibrate_gyro() -> void:
	_gyro_calib = INF
	_gyro_raw = 0.0
	_gyro_steer = 0.0

func gyro_value() -> float:
	return _gyro_steer

## Gravedad en el plano de la pantalla: girar el teléfono como un volante (cualquier apaisado)
func _feed_gyro() -> void:
	var g := Input.get_accelerometer()
	if Vector2(g.x, g.y).length() < 3.0:
		return
	var cur := rad_to_deg(atan2(g.y, g.x))
	if _gyro_calib == INF:
		_gyro_calib = cur
		return
	var delta := cur - _gyro_calib
	if delta > 180.0:
		delta -= 360.0
	if delta < -180.0:
		delta += 360.0
	_gyro_raw += (delta - _gyro_raw) * 0.22
	_gyro_steer = clampf((-1.0 if gyro_invert else 1.0) * _gyro_raw / gyro_tilt_for_full(), -1.0, 1.0)

# ───────────────────────── actualización por cuadro ─────────────────────────
func update_inputs(dt: float) -> void:
	var kb_steer := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		kb_steer -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		kb_steer += 1.0
	if gyro_on:
		_feed_gyro()
	var wheel_contact := _taken("wheel")
	var slider_contact := _taken("slider")
	var desired: float
	if gyro_on:
		desired = _gyro_steer
	elif steer_mode == "slider":
		desired = slider_target if slider_contact else kb_steer
	else:
		desired = wheel_target if wheel_contact else kb_steer
	var rate := 13.0 if desired == 0.0 else 9.5
	steer += (desired - steer) * (1.0 - exp(-dt * rate))
	if steer_mode == "wheel":
		if gyro_on:
			wheel_rotation += (_gyro_steer * PI * 0.75 - wheel_rotation) * (1.0 - exp(-dt * 15.0))
		elif not wheel_contact:
			var target_rot := kb_steer * PI * 0.75 if kb_steer != 0.0 else 0.0
			wheel_rotation += (target_rot - wheel_rotation) * (1.0 - exp(-dt * 5.5))
		wheel_visual += (wheel_rotation - wheel_visual) * (1.0 - exp(-dt * 10.0))
	# pedales: el dedo manda; sin dedo, el teclado
	if not _taken("pedal"):
		var kg := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
		var kbk := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		gas = 1.0 if kg else 0.0
		brake = 1.0 if (kbk and not kg) else 0.0
		pedal_v = gas - brake
	if not _taken("handbrake"):
		handbrake = Input.is_key_pressed(KEY_SPACE)
	if Input.is_key_pressed(KEY_E) and not _key_e:
		_request_shift(1)
	if Input.is_key_pressed(KEY_Q) and not _key_q:
		_request_shift(-1)
	_key_e = Input.is_key_pressed(KEY_E)
	_key_q = Input.is_key_pressed(KEY_Q)
	shift = 1 if shift_queue > 0 else (-1 if shift_queue < 0 else 0)
	shift_queue -= shift
	_flash_up = maxf(0.0, _flash_up - dt)
	_flash_dn = maxf(0.0, _flash_dn - dt)
	queue_redraw()

var _key_e := false
var _key_q := false

# ───────────────────────── dibujo ─────────────────────────
func _draw() -> void:
	var u := _u()
	var vs := _vs()
	var font := ThemeDB.fallback_font
	if show_speed:
		_draw_speed_panel(font, u, vs)
	if steer_mode == "wheel" and not gyro_on:
		_draw_wheel(rect_of("wheel"))
	elif steer_mode == "slider" and not gyro_on:
		_draw_slider(rect_of("slider"), font, u)
	if gyro_on:
		draw_string(font, Vector2(vs.x * 0.5 - 150.0 * u, vs.y - 12.0 * u), "ACELERÓMETRO ACTIVADO", HORIZONTAL_ALIGNMENT_CENTER, 300.0 * u, int(12.0 * u), Color(0.6, 1.0, 0.6, 0.9))
	_draw_pedal(rect_of("pedal"), font, u)
	if manual:
		_draw_gears(rect_of("gears"), font, u)
	_draw_round_button(rect_of("cam"), "CAM", false, Color(1.0, 0.8, 0.4), Color(0.2, 0.16, 0.08), Color(1.0, 0.82, 0.54), font, u * 0.5)
	_draw_round_button(rect_of("pause"), "II", false, Color(0.7, 0.75, 0.85), Color(0.12, 0.14, 0.18), Color(0.8, 0.85, 0.95), font, u * 0.6)
	_draw_round_button(rect_of("handbrake"), "H", handbrake, Color(1.0, 0.24, 0.19), Color(0.35, 0.12, 0.12), Color(1.0, 0.47, 0.43), font, u)
	if has_nitro:
		_draw_round_button(rect_of("nitro"), "N₂O", nitro, Color(0.3, 0.65, 1.0), Color(0.07, 0.19, 0.35), Color(0.31, 0.7, 1.0), font, u, nitro_frac)

func _draw_speed_panel(font: Font, u: float, vs: Vector2) -> void:
	var w := 150.0 * u
	var x0 := vs.x * 0.5 - w * 0.5
	var y0 := 12.0 * u
	draw_rect(Rect2(x0, y0, w, 74.0 * u), Color(0.04, 0.06, 0.09, 0.55), true)
	draw_rect(Rect2(x0, y0, w, 74.0 * u), Color(1, 1, 1, 0.10), false, 1.0)
	var sp := speed_kmh * (0.6214 if use_mph else 1.0)
	var txt := "%d" % int(round(sp))
	draw_string(font, Vector2(x0, y0 + 36.0 * u), txt, HORIZONTAL_ALIGNMENT_CENTER, w - 34.0 * u, int(34.0 * u), Color(1, 1, 1))
	draw_string(font, Vector2(x0 + w - 44.0 * u, y0 + 36.0 * u), "mph" if use_mph else "km/h", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.0 * u), Color(0.56, 0.64, 0.74))
	var gr := Rect2(vs.x * 0.5 - 15.0 * u, y0 + 42.0 * u, 30.0 * u, 16.0 * u)
	draw_rect(gr, Color(0.35, 0.63, 1.0, 0.2), true)
	draw_rect(gr, Color(0.35, 0.63, 1.0, 0.4), false, 1.0)
	draw_string(font, Vector2(gr.position.x, gr.position.y + 12.5 * u), gear_text, HORIZONTAL_ALIGNMENT_CENTER, gr.size.x, int(11.0 * u), Color(1, 1, 1))
	# barra de vueltas
	var bar := Rect2(x0 + 10.0 * u, y0 + 64.0 * u, w - 20.0 * u, 4.0 * u)
	draw_rect(bar, Color(1, 1, 1, 0.12), true)
	var f := clampf(rpm_frac, 0.0, 1.0)
	var col := Color(0.4, 0.71, 1.0).lerp(Color(1.0, 0.82, 0.4), clampf(f / 0.75, 0.0, 1.0))
	if f > 0.75:
		col = Color(1.0, 0.82, 0.4).lerp(Color(1.0, 0.3, 0.37), (f - 0.75) / 0.25)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)), col, true)

func _draw_wheel(r: Rect2) -> void:
	var k := r.size.x / 200.0
	draw_set_transform(r.get_center(), wheel_visual, Vector2(k, k))
	draw_circle(Vector2.ZERO, 94.0, Color("1a1d22"))
	draw_arc(Vector2.ZERO, 82.0, 0.0, TAU, 72, Color("2a2f38"), 20.0, true)
	draw_rect(Rect2(-6, -86, 12, 76), Color("2a2f38"))
	draw_rect(Rect2(-86, -6, 172, 12), Color("2a2f38"))
	draw_circle(Vector2.ZERO, 26.0, Color("14181e"))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color("5a6472"), 3.0, true)
	draw_circle(Vector2.ZERO, 7.0, Color("ff6a08"))
	draw_rect(Rect2(-6, -94, 12, 18), Color("ff6a08"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_slider(r: Rect2, font: Font, u: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("101318")
	sb.set_corner_radius_all(int(32.0 * u))
	sb.border_color = Color("4a4f57")
	sb.set_border_width_all(2)
	draw_style_box(sb, r)
	var c := r.get_center()
	draw_line(Vector2(c.x, r.position.y + 6.0 * u), Vector2(c.x, r.end.y - 6.0 * u), Color(1, 1, 1, 0.5), 2.0)
	var v := slider_target if _taken("slider") else steer
	var kx := c.x + v * 0.38 * r.size.x
	draw_circle(Vector2(kx, c.y), 23.0 * u, Color("0a0d12"))
	draw_arc(Vector2(kx, c.y), 23.0 * u, 0.0, TAU, 32, Color("6db9ff"), 2.0, true)
	draw_string(font, Vector2(r.position.x + 14.0 * u, c.y + 6.0 * u), "←", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * u), Color("a8d0ff"))
	draw_string(font, Vector2(r.end.x - 30.0 * u, c.y + 6.0 * u), "→", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16.0 * u), Color("a8d0ff"))

func _draw_pedal(r: Rect2, font: Font, u: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0d1015")
	sb.set_corner_radius_all(int(35.0 * u))
	sb.border_color = Color("4a4f57")
	sb.set_border_width_all(2)
	draw_style_box(sb, r)
	var mid := r.position.y + r.size.y * 0.5
	var inner := r.grow(-3.0)
	if pedal_v > 0.0:
		var h := r.size.y * 0.5 * pedal_v
		_grad_rect(Rect2(inner.position.x, mid - h, inner.size.x, h), Color("a6ffab"), Color("0b4b10"))
	elif pedal_v < 0.0:
		var h2 := r.size.y * 0.5 * -pedal_v
		_grad_rect(Rect2(inner.position.x, mid, inner.size.x, h2), Color("3c0000"), Color("ff9a9a"))
	draw_line(Vector2(r.position.x + r.size.x * 0.1, mid), Vector2(r.end.x - r.size.x * 0.1, mid), Color(1, 1, 1, 0.65), 2.0)
	var ky := r.end.y - (0.5 + pedal_v * 0.38) * r.size.y
	var kr := 20.0 * u
	draw_circle(Vector2(r.get_center().x, ky), kr, Color("0a0d12"))
	draw_arc(Vector2(r.get_center().x, ky), kr, 0.0, TAU, 32, Color("6db9ff"), 2.0, true)
	draw_string(font, Vector2(r.position.x, r.position.y + 16.0 * u), "GAS", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(9.0 * u), Color("a6ffab"))
	draw_string(font, Vector2(r.position.x, r.end.y - 8.0 * u), "FRENO", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(9.0 * u), Color("ff9a9a"))

## Rectángulo con degradé vertical: "top" arriba y "bot" abajo
func _grad_rect(r: Rect2, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([top, top, bot, bot]))

func _draw_gears(r: Rect2, font: Font, u: float) -> void:
	var bh := (r.size.y - 12.0 * u) / 3.0
	var up := Rect2(r.position, Vector2(r.size.x, bh))
	var mid := Rect2(r.position + Vector2(0, bh + 6.0 * u), Vector2(r.size.x, bh))
	var dn := Rect2(r.position + Vector2(0, 2.0 * (bh + 6.0 * u)), Vector2(r.size.x, bh))
	for pair in [[up, "▲", "SUBIR", _flash_up > 0.0], [dn, "▼", "BAJAR", _flash_dn > 0.0]]:
		var b: Rect2 = pair[0]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.23, 0.63, 1.0, 0.55) if pair[3] else Color(0.08, 0.1, 0.13, 0.62)
		sb.set_corner_radius_all(int(14.0 * u))
		sb.border_color = Color(0.56, 0.82, 1.0) if pair[3] else Color(1, 1, 1, 0.25)
		sb.set_border_width_all(1)
		draw_style_box(sb, b)
		draw_string(font, Vector2(b.position.x, b.position.y + b.size.y * 0.5 + 2.0 * u), pair[1], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(24.0 * u), Color("e8f1ff"))
		draw_string(font, Vector2(b.position.x, b.position.y + b.size.y * 0.5 + 16.0 * u), pair[2], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(9.0 * u), Color(0.9, 0.95, 1.0, 0.7))
	draw_rect(mid, Color(0.04, 0.055, 0.08, 0.55), true)
	draw_string(font, Vector2(mid.position.x, mid.position.y + mid.size.y * 0.5 + 9.0 * u), gear_text, HORIZONTAL_ALIGNMENT_CENTER, mid.size.x, int(26.0 * u), Color(1, 1, 1))

func _draw_round_button(r: Rect2, label: String, active: bool, glow: Color, dark: Color, ring: Color, font: Font, u: float, fill := -1.0) -> void:
	var c := r.get_center()
	var rad := r.size.x * 0.5
	if active:
		draw_circle(c, rad + 6.0 * u, Color(glow.r, glow.g, glow.b, 0.25))
	draw_circle(c, rad, glow.darkened(0.45) if active else dark.darkened(0.55))
	if fill >= 0.0:
		var h := 2.0 * rad * clampf(fill, 0.0, 1.0)
		var cl := Rect2(c.x - rad + 2.0, c.y + rad - h, 2.0 * rad - 4.0, h)
		draw_rect(cl, Color(0.16, 0.6, 1.0, 0.35), true)
	draw_arc(c, rad - 1.0, 0.0, TAU, 40, Color(ring.r, ring.g, ring.b, 1.0 if active else 0.6), 2.0, true)
	draw_string(font, Vector2(r.position.x, c.y + 7.0 * u), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(20.0 * u), Color(1, 1, 1) if active else ring.lightened(0.3))
