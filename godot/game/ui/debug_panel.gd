extends Control
## Panel de pruebas (botón «PRUEBAS» arriba a la izquierda): contador de rendimiento, cambios de carga
## (autos / árboles / pilotos / sombras / resolución), prueba automática e informe.
## Los controles de manejo reales están en controls.gd.

signal option_changed(key: String, value)
signal bench_pressed
signal copy_pressed

var open := false
var stats_text := ""
var speed_kmh := 0.0
var gear_text := "1"
var rpm := 0.0
var result_text := ""
var toast_text := ""
var banner := ""
var toast_t := 0.0

var _steer_finger := -1
var _last_sig := ""
var _last_size := Vector2.ZERO
var _steer_x0 := 0.0
## barras deslizables (clave → {label, min, max, val}); se ven con el panel abierto
var sliders := {
	"cam_rear": {"label": "Trasera: distancia (m)", "min": 0.60, "max": 1.70, "val": 1.08},
	"cam_rear_fov": {"label": "Trasera: ángulo (° menos = zoom)", "min": 60.0, "max": 120.0, "val": 92.0},
	"cam_ob": {"label": "Casco: distancia (m)", "min": -0.10, "max": 0.50, "val": 0.17},
	"cam_ob_fov": {"label": "Casco: ángulo (°)", "min": 60.0, "max": 120.0, "val": 96.0},
	"disp_x": {"label": "Pantalla: corrida al costado (m)", "min": 0.0, "max": 0.40, "val": 0.13},
}
var _slider_finger := {} # dedo → clave
var _fingers := {} # index → botón que sostiene
var _buttons: Array = [] # {id, rect, label}
var _opts := {
	"cars": [1, [1, 4, 8, 12]],
	"trees": [1, [0, 3000, 8000, 16000]],
	"pilots": [1, [0, 1]],
	"shadows": [0, [0, 1]],
	"hi": [1, [0, 1]],
	"threads": [1, [0, 1]],
	"res": [0, [0.0, 0.35, 0.5, 0.7, 1.0]],
	"lens": [1, ["apagado", "suave", "fuerte"]],
	"steer": [0, ["volante", "barra"]],
	"gearbox": [0, ["auto", "manual"]],
	"gyro": [0, [0, 1]],
	"nitro": [0, [0, 1]],
	"weather": [0, ["dia", "nublado", "lluvia", "atardecer", "ocaso"]],
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
	if s == _last_size and not _buttons.is_empty():
		return
	_last_size = s
	_buttons.clear()
	var bw := 150.0
	var bh := 70.0
	_buttons.append({"id": "toggle", "rect": Rect2(10, 8, 120, 40), "label": "PRUEBAS" if not open else "CERRAR"})
	if not open:
		return
	_buttons.append({"id": "bench", "rect": Rect2(10, 56, 150, 44), "label": "PRUEBA"})
	_buttons.append({"id": "copy", "rect": Rect2(10, 106, 150, 44), "label": "INFORME"})
	_buttons.append({"id": "recal", "rect": Rect2(10, 156, 150, 44), "label": "CALIBRAR"})
	var keys := ["cars", "trees", "pilots", "shadows", "hi", "threads", "res", "steer", "gearbox", "gyro", "nitro", "weather", "lens"]
	var names := {"cars": "Autos", "trees": "Árboles", "pilots": "Pilotos", "shadows": "Sombras", "hi": "Modelo alto", "threads": "Hilos", "res": "Resolución", "steer": "Dirección", "gearbox": "Caja", "gyro": "Acelerómetro", "nitro": "Nitro", "weather": "Clima", "lens": "Lente"}
	for i in keys.size():
		var col := i / 5
		var row := i % 5
		_buttons.append({"id": "opt:" + keys[i], "rect": Rect2(s.x - 170.0 - 175.0 * (2 - col), 56 + row * 52, 165, 46), "label": names[keys[i]]})

func slider_rect(i: int) -> Rect2:
	var s := _vs()
	var col := i / 3
	return Rect2(s.x * 0.5 - 400.0 + float(col) * 410.0, s.y - 62.0 - float(i % 3) * 58.0, 390.0, 46.0)

func _slider_key_at(pos: Vector2) -> String:
	var i := 0
	for k in sliders:
		if slider_rect(i).grow(10.0).has_point(pos):
			return k
		i += 1
	return ""

func _slider_set(k: String, x: float) -> void:
	var i := sliders.keys().find(k)
	var r := slider_rect(i)
	var d: Dictionary = sliders[k]
	var t := clampf((x - r.position.x - 10.0) / (r.size.x - 20.0), 0.0, 1.0)
	d["val"] = snappedf(lerpf(d["min"], d["max"], t), 0.01)
	option_changed.emit(k, d["val"])
	_last_sig = ""

func _hit(pos: Vector2) -> String:
	for b in _buttons:
		if (b["rect"] as Rect2).has_point(pos):
			return b["id"]
	return ""

func _input(event: InputEvent) -> void:
	if open and event is InputEventScreenDrag and _slider_finger.has((event as InputEventScreenDrag).index):
		get_viewport().set_input_as_handled()
		_slider_set(_slider_finger[(event as InputEventScreenDrag).index], (event as InputEventScreenDrag).position.x)
		return
	if event is InputEventScreenTouch:
		var ev := event as InputEventScreenTouch
		if not ev.pressed:
			_slider_finger.erase(ev.index)
		elif open:
			var sk := _slider_key_at(ev.position)
			if sk != "":
				get_viewport().set_input_as_handled()
				_slider_finger[ev.index] = sk
				_slider_set(sk, ev.position.x)
				return
		if ev.pressed:
			var h := _hit(ev.position)
			if h != "":
				get_viewport().set_input_as_handled() # el panel se queda con este toque: el manejo no lo ve
				_fingers[ev.index] = h
				if h == "toggle":
					open = not open
					_last_size = Vector2.ZERO
					result_text = ""
				elif h.begins_with("opt:"):
					_cycle(h.substr(4))
				elif h == "bench":
					result_text = ""
					bench_pressed.emit()
				elif h == "copy":
					copy_pressed.emit()
				elif h == "recal":
					option_changed.emit("recal", 1)
		else:
			_fingers.erase(ev.index)

func _cycle(key: String) -> void:
	var o: Array = _opts[key]
	o[0] = (o[0] + 1) % o[1].size()
	option_changed.emit(key, o[1][o[0]])

func show_toast(t: String) -> void:
	toast_text = t
	toast_t = 3.0

func _process(_dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= _dt
	_layout()
	# solo se vuelve a dibujar si cambió algo de lo que se ve (ahorra tiempo de CPU/GPU en cada cuadro)
	var sig := "%s|%s|%s|%s|%s|%s|%s|%s" % [str(sliders), str(open), str(_fingers.values()), stats_text if open else "", result_text, str(toast_t > 0.0), banner, str(option_value("res"))]
	if sig != _last_sig:
		_last_sig = sig
		queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vs := _vs()
	if open and stats_text != "":
		draw_rect(Rect2(140, 8, 620, 96), Color(0, 0, 0, 0.55))
		var lines := stats_text.split("\n")
		for i in lines.size():
			draw_string(font, Vector2(148, 30 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1))
	for b in _buttons:
		var r: Rect2 = b["rect"]
		var id: String = b["id"]
		draw_rect(r, Color(1, 1, 1, 0.10 if id != "toggle" else 0.06), true)
		draw_rect(r, Color(1, 1, 1, 0.5 if id != "toggle" else 0.22), false, 2.0)
		var lab: String = b["label"]
		if id.begins_with("opt:"):
			var key := id.substr(4)
			var val = option_value(key)
			lab += ": " + (("sí" if int(val) == 1 else "no") if key in ["pilots", "shadows", "hi", "threads", "gyro", "nitro"] else ((("auto" if float(val) == 0.0 else "%d%%" % int(float(val) * 100.0))) if key == "res" else str(val)))
		var fs := 18 if (id.begins_with("opt:") or id == "bench" or id == "copy") else 18
		draw_string(font, Vector2(r.position.x + 6, r.position.y + r.size.y * 0.62), lab, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, fs, Color(1, 1, 1, 0.9 if id != "toggle" else 0.55))
	if open:
		var si := 0
		for k in sliders:
			var d: Dictionary = sliders[k]
			var r := slider_rect(si)
			draw_rect(r, Color(0, 0, 0, 0.62))
			draw_rect(r, Color(1, 1, 1, 0.45), false, 2.0)
			var t := inverse_lerp(d["min"], d["max"], d["val"])
			draw_rect(Rect2(r.position.x + 10.0, r.position.y + 30.0, (r.size.x - 20.0) * t, 6.0), Color(1.0, 0.6, 0.2))
			draw_rect(Rect2(r.position.x + 10.0 + (r.size.x - 20.0) * t - 6.0, r.position.y + 24.0, 12.0, 18.0), Color(1, 1, 1))
			draw_string(font, Vector2(r.position.x + 10.0, r.position.y + 20.0), "%s:  %.2f" % [d["label"], d["val"]], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0, 17, Color(1, 1, 1))
			si += 1
	if result_text != "":
		var rl := result_text.split("\n")
		var h := 30.0 + rl.size() * 24.0
		draw_rect(Rect2(20, 60, vs.x - 40, h), Color(0, 0, 0, 0.82))
		for i in rl.size():
			draw_string(font, Vector2(34, 86 + i * 24), rl[i], HORIZONTAL_ALIGNMENT_LEFT, vs.x - 60, 19, Color(1, 1, 1))
	if toast_t > 0.0:
		draw_rect(Rect2(vs.x * 0.5 - 260, vs.y * 0.5 - 40, 520, 80), Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(vs.x * 0.5 - 250, vs.y * 0.5 + 8), toast_text, HORIZONTAL_ALIGNMENT_CENTER, 500, 26, Color(0.4, 1, 0.5))
	if banner != "":
		draw_rect(Rect2(vs.x * 0.5 - 330, 8, 660, 44), Color(0.75, 0.1, 0.1, 0.9))
		draw_string(font, Vector2(vs.x * 0.5 - 320, 39), banner, HORIZONTAL_ALIGNMENT_CENTER, 640, 24, Color(1, 1, 1))
