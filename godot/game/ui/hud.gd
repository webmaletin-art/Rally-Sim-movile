extends Control
## HUD táctil de la prueba: volante deslizando el dedo a la izquierda, pedales a la derecha,
## contador de rendimiento arriba y botones para cambiar cuántos autos / árboles / pilotos hay.
## Multitáctil: cada dedo se sigue por su índice.

signal option_changed(key: String, value)
signal bench_pressed
signal copy_pressed

var steer := 0.0
var throttle := 0.0
var brake := 0.0
var handbrake := false
var stats_text := ""
var speed_kmh := 0.0
var gear_text := "1"
var rpm := 0.0
var result_text := ""
var toast_text := ""
var toast_t := 0.0

var _steer_finger := -1
var _steer_x0 := 0.0
var _fingers := {} # index → botón que sostiene
var _buttons: Array = [] # {id, rect, label}
var _opts := {
	"cars": [1, [1, 4, 8, 12]],
	"trees": [1, [0, 3000, 8000, 16000]],
	"pilots": [1, [0, 1]],
	"shadows": [0, [0, 1]],
	"hi": [1, [0, 1]],
	"threads": [1, [0, 1]],
	"res": [1, [0.35, 0.5, 0.7, 1.0]],
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Tamaño de la pantalla (el HUD vive en una CanvasLayer: no hereda tamaño de un padre Control)
func _vs() -> Vector2:
	return get_viewport_rect().size

func option_value(key: String):
	var o: Array = _opts[key]
	return o[1][o[0]]

func _layout() -> void:
	var s := _vs()
	_buttons.clear()
	var bw := 150.0
	var bh := 70.0
	_buttons.append({"id": "gas", "rect": Rect2(s.x - 190, s.y - 150, 170, 140), "label": "ACEL"})
	_buttons.append({"id": "brake", "rect": Rect2(s.x - 380, s.y - 130, 170, 120), "label": "FRENO"})
	_buttons.append({"id": "hb", "rect": Rect2(s.x - 330, s.y - 250, 110, 90), "label": "MANO"})
	_buttons.append({"id": "bench", "rect": Rect2(s.x - 2.0 * bw - 24, 10, bw, bh * 0.75), "label": "PRUEBA"})
	_buttons.append({"id": "copy", "rect": Rect2(s.x - 2.0 * bw - 24, 10 + (bh * 0.75 + 6), bw, bh * 0.75), "label": "INFORME"})
	var keys := ["cars", "trees", "pilots", "shadows", "hi", "threads", "res"]
	var names := {"cars": "Autos", "trees": "Árboles", "pilots": "Pilotos", "shadows": "Sombras", "hi": "Modelo alto", "threads": "Hilos", "res": "Resolución"}
	for i in keys.size():
		_buttons.append({"id": "opt:" + keys[i], "rect": Rect2(s.x - bw - 12, 10 + i * (bh * 0.75 + 6), bw, bh * 0.75), "label": names[keys[i]]})

func _hit(pos: Vector2) -> String:
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			return b["id"]
	return ""

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if ev.pressed:
			var h := _hit(ev.position)
			if h != "":
				_fingers[ev.index] = h
				if h.begins_with("opt:"):
					_cycle(h.substr(4))
				elif h == "bench":
					result_text = ""
					bench_pressed.emit()
				elif h == "copy":
					copy_pressed.emit()
			elif ev.position.x < _vs().x * 0.5 and _steer_finger == -1:
				_steer_finger = ev.index
				_steer_x0 = ev.position.x
		else:
			if _fingers.has(ev.index):
				_fingers.erase(ev.index)
			if ev.index == _steer_finger:
				_steer_finger = -1
				steer = 0.0
		_recompute()
	elif event is InputEventScreenDrag:
		var ev2 := event as InputEventScreenDrag
		if ev2.index == _steer_finger:
			steer = clampf((ev2.position.x - _steer_x0) / (_vs().x * 0.12), -1.0, 1.0)

func _cycle(key: String) -> void:
	var o: Array = _opts[key]
	o[0] = (o[0] + 1) % o[1].size()
	option_changed.emit(key, o[1][o[0]])

func _recompute() -> void:
	throttle = 0.0
	brake = 0.0
	handbrake = false
	for idx in _fingers:
		match _fingers[idx]:
			"gas": throttle = 1.0
			"brake": brake = 1.0
			"hb": handbrake = true

func show_toast(t: String) -> void:
	toast_text = t
	toast_t = 3.0

func _process(_dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= _dt
	# teclado (para probar en la compu)
	var kt := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var kb := Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	if kt:
		throttle = 1.0
	elif not _fingers.values().has("gas"):
		throttle = 0.0
	if kb:
		brake = 1.0
	elif not _fingers.values().has("brake"):
		brake = 0.0
	var ks := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		ks -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		ks += 1.0
	if ks != 0.0:
		steer = ks
	elif _steer_finger == -1:
		steer = 0.0
	if Input.is_key_pressed(KEY_SPACE):
		handbrake = true
	elif not _fingers.values().has("hb"):
		handbrake = false
	_layout()
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	# estadísticas
	draw_rect(Rect2(8, 8, 620, 96), Color(0, 0, 0, 0.55))
	var lines := stats_text.split("\n")
	for i in lines.size():
		draw_string(font, Vector2(16, 30 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))
	# velocímetro
	var vs := _vs()
	draw_string(font, Vector2(vs.x * 0.5 - 60, vs.y - 30), "%d km/h" % int(speed_kmh), HORIZONTAL_ALIGNMENT_CENTER, 200, 30, Color(1, 1, 1))
	draw_string(font, Vector2(vs.x * 0.5 + 110, vs.y - 30), "M %s" % gear_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.55, 0.15))
	# barra de dirección
	var cx := vs.x * 0.25
	var cy := vs.y - 60.0
	draw_rect(Rect2(cx - 150, cy - 6, 300, 12), Color(1, 1, 1, 0.18))
	draw_circle(Vector2(cx + steer * 150.0, cy), 20.0, Color(1.0, 0.5, 0.1, 0.9))
	# botones
	for b in _buttons:
		var r: Rect2 = b["rect"]
		var id: String = b["id"]
		var down := _fingers.values().has(id)
		var col := Color(1, 1, 1, 0.16)
		if id == "gas":
			col = Color(0.1, 0.8, 0.3, 0.30 if not down else 0.6)
		elif id == "brake":
			col = Color(0.9, 0.2, 0.2, 0.30 if not down else 0.6)
		elif id == "hb":
			col = Color(0.9, 0.6, 0.1, 0.30 if not down else 0.6)
		draw_rect(r, col, true)
		draw_rect(r, Color(1, 1, 1, 0.5), false, 2.0)
		var lab: String = b["label"]
		if id.begins_with("opt:"):
			var key := id.substr(4)
			var val = option_value(key)
			lab += ": " + (("sí" if int(val) == 1 else "no") if key in ["pilots", "shadows", "hi", "threads"] else (("%d%%" % int(float(val) * 100.0)) if key == "res" else str(val)))
		var fs := 18 if (id.begins_with("opt:") or id == "bench" or id == "copy") else 26
		draw_string(font, Vector2(r.position.x + 6, r.position.y + r.size.y * 0.62), lab, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, fs, Color(1, 1, 1))
	if result_text != "":
		var rl := result_text.split("\n")
		var h := 30.0 + rl.size() * 24.0
		draw_rect(Rect2(20, 20, vs.x - 40, h), Color(0, 0, 0, 0.82))
		for i in rl.size():
			draw_string(font, Vector2(34, 46 + i * 24), rl[i], HORIZONTAL_ALIGNMENT_LEFT, vs.x - 60, 19, Color(1, 1, 1))
	if toast_t > 0.0:
		draw_rect(Rect2(vs.x * 0.5 - 260, vs.y * 0.5 - 40, 520, 80), Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(vs.x * 0.5 - 250, vs.y * 0.5 + 8), toast_text, HORIZONTAL_ALIGNMENT_CENTER, 500, 26, Color(0.4, 1, 0.5))
