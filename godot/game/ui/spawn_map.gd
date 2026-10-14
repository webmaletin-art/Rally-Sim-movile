extends Control
## Mapa de «¿dónde aparecer?»: la región entera con los lugares donde se puede largar. Un toque elige el lugar más cercano al dedo; arrastrar con un dedo mueve el mapa;
## con dos dedos (pellizco) o la rueda se acerca y se aleja. Mismo manejo que el mapa grande del mundo abierto (city_hud.gd).

const Kit := preload("res://game/ui/ui_kit.gd")
const RegionServices := preload("res://game/region/region_services.gd")

signal tapped(key: String) # el toque eligió esta marca

## [{key, pos (Vector2, metros), label, kind: "dream" | "ciudad" | "pueblo" | "last" | "locked"}]
var marks: Array = []
var selected := ""
var zoom := 1.0
var center := Vector2.ZERO # punto del mundo que está en el medio del mapa (metros)
var tex: Texture2D
var _tp := {} # dedos apoyados: índice -> posición
var _pinch_d := 0.0
var _pressing := false
var _moved := 0.0

const MIN_ZOOM := 1.0
const MAX_ZOOM := 14.0

func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 240)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tex = load("res://game/data/region/region_map.png") as Texture2D
	center = RegionServices.MAP_RECT.get_center()

func _process(_dt: float) -> void:
	if is_visible_in_tree():
		queue_redraw() # el aro del lugar elegido late

# ───────────────────────── mundo ⇄ pantalla ─────────────────────────
func base_scale() -> float:
	var r := RegionServices.MAP_RECT
	return minf(size.x / r.size.x, size.y / r.size.y)

func scale_px() -> float:
	return base_scale() * zoom # píxeles por metro

func to_screen(w: Vector2) -> Vector2:
	return (w - center) * scale_px() + size * 0.5

func to_world(p: Vector2) -> Vector2:
	return (p - size * 0.5) / scale_px() + center

func _clamp_center() -> void:
	var r := RegionServices.MAP_RECT
	var half := size * 0.5 / maxf(scale_px(), 1e-9)
	center.x = clampf(center.x, r.position.x + minf(half.x, r.size.x * 0.5), r.end.x - minf(half.x, r.size.x * 0.5))
	center.y = clampf(center.y, r.position.y + minf(half.y, r.size.y * 0.5), r.end.y - minf(half.y, r.size.y * 0.5))

func zoom_by(f: float, at: Vector2) -> void:
	var before := to_world(at)
	zoom = clampf(zoom * f, MIN_ZOOM, MAX_ZOOM)
	var after := to_world(at)
	center += before - after
	_clamp_center()
	queue_redraw()

func pan_by(d: Vector2) -> void:
	center -= d / scale_px()
	_clamp_center()
	queue_redraw()

## Elegir una marca desde afuera (el selector): si el mapa está acercado, la marca queda a la vista
func select(key: String) -> void:
	selected = key
	for m in marks:
		if str(m["key"]) == key:
			var sp := to_screen(m["pos"])
			if zoom > 1.01 and not Rect2(Vector2.ZERO, size).grow(-30.0).has_point(sp):
				center = m["pos"]
				_clamp_center()
	queue_redraw()

# ───────────────────────── toques ─────────────────────────
func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.pressed:
			_tp[st.index] = st.position
		else:
			_tp.erase(st.index)
		_pinch_d = 0.0
		if _tp.size() >= 2:
			_moved = 999.0 # con dos dedos nunca es un toque
		accept_event()
		return
	if e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		_tp[sd.index] = sd.position
		if _tp.size() >= 2:
			var ks := _tp.keys()
			var pa: Vector2 = _tp[ks[0]]
			var pb: Vector2 = _tp[ks[1]]
			var d := pa.distance_to(pb)
			if _pinch_d > 8.0 and d > 8.0:
				zoom_by(d / _pinch_d, (pa + pb) * 0.5)
			_pinch_d = d
		accept_event()
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom_by(1.25, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom_by(0.8, mb.position)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_moved = 0.0
			else:
				if _pressing and _moved < 14.0 and _tp.size() < 2:
					_pick(mb.position)
				_pressing = false
		accept_event()
		return
	if e is InputEventMouseMotion and _pressing and _tp.size() < 2:
		var mm := e as InputEventMouseMotion
		_moved += mm.relative.length()
		if _moved >= 14.0:
			pan_by(mm.relative)
		accept_event()

## Un toque: la marca más cercana al dedo (a menos de ~70 px); si no hay ninguna cerca no cambia nada
func _pick(p: Vector2) -> void:
	var best := ""
	var bd := 70.0
	for m in marks:
		var d := to_screen(m["pos"]).distance_to(p)
		# las ciudades tienen un poco más de área que los pueblos
		d -= 8.0 if str(m["kind"]) in ["dream", "ciudad"] else 0.0
		if d < bd:
			bd = d
			best = str(m["key"])
	if best != "":
		tapped.emit(best)

# ───────────────────────── dibujo ─────────────────────────
func _draw() -> void:
	var r := RegionServices.MAP_RECT
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.12))
	var a := to_screen(r.position)
	var b := to_screen(r.end)
	if tex != null:
		draw_texture_rect(tex, Rect2(a, b - a), false)
	else:
		draw_rect(Rect2(a, b - a), Color(0.12, 0.16, 0.14))
	var f: Font = ThemeDB.fallback_font
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
	# primero los lugares y, encima de todo, el elegido (con su nombre grande): así ningún nombre lo tapa
	for pass_i in 2:
		for m in marks:
			var is_sel := str(m["key"]) == selected
			if is_sel != (pass_i == 1):
				continue
			var sp := to_screen(m["pos"])
			if not Rect2(Vector2.ZERO, size).grow(20.0).has_point(sp):
				continue
			var kind := str(m["kind"])
			var rad := 4.5
			var col := Color(1.0, 0.92, 0.65)
			match kind:
				"dream":
					rad = 7.5
					col = Color.WHITE
				"ciudad":
					rad = 6.0
					col = Color(1.0, 0.78, 0.2)
				"last":
					rad = 6.0
					col = Color(1.0, 0.3, 0.25)
				"locked": # (todavía no se llegó manejando: gris)
					rad = 4.0
					col = Color(0.55, 0.57, 0.6)
			draw_circle(sp, rad + 2.0, Color(0, 0, 0, 0.75))
			draw_circle(sp, rad, col)
			if is_sel:
				draw_circle(sp, 13.0 + 5.0 * pulse, Color(1.0, 0.2, 0.1, 0.30))
				draw_arc(sp, 12.0, 0.0, TAU, 28, Color.WHITE, 2.5)
				draw_circle(sp, rad, Color(1.0, 0.25, 0.1))
			# nombres: las ciudades siempre, los pueblos cuando se acerca el mapa, el elegido siempre
			if is_sel or (kind in ["dream", "ciudad"]) or zoom >= 2.4:
				var txt := str(m["label"])
				var fs := 18 if is_sel else 13
				var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var tp := sp + Vector2(12.0, 5.0)
				if tp.x + tw > size.x - 4.0:
					tp.x = sp.x - 12.0 - tw
				var bg := Rect2(tp + Vector2(-4.0, -fs), Vector2(tw + 8.0, fs + 7.0))
				draw_rect(bg, Color(0, 0, 0, 0.72 if is_sel else 0.38), true)
				draw_string(f, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.55) if is_sel else Color(1, 1, 1, 0.92))
	# marco
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.14), false, 1.0)
	# ayuda
	var hint := tr("toca un lugar · arrastrá para mover · dos dedos para el zoom")
	draw_string(f, Vector2(8.0, size.y - 8.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
