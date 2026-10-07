extends Control
## HUD de la carrera: puesto, vuelta, tiempo, cuenta regresiva, avisos y menú de pausa.

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const OptionsUi := preload("res://game/ui/options_ui.gd")
const Tr := preload("res://game/i18n/tr.gd")
const LabPanel := preload("res://game/ui/lab_panel.gd")
const CityHud := preload("res://game/ui/city_hud.gd")
const OnlinePanel := preload("res://game/ui/online_panel.gd")

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal tests_pressed
signal camera_pressed
signal cine_pressed
signal edit_controls_pressed # «Modificar controles» de la pausa
signal options_changed(key: String)
signal cam_step(d: int) # cambiar de cámara desde el panel de ajuste (−1 anterior, 1 siguiente)
signal camadj_changed # se movió una barra del ajuste de cámara (race.gd lo guarda)
signal lab_changed # se movió una barra del taller de prueba (race.gd rearma el auto)
signal lab_reset

var session: RefCounted
var cfg: Dictionary
var rivals: Array
var top: PanelContainer
var pos_l: Label
var lap_l: Label
var time_l: Label
var sub_l: Label
var drift_l: Label # puntos del derrape en curso (grande, arriba al centro)
var big_l: Label
var toast_l: Label
var tick := 0.0
var big_t := 0.0
var toast_t := 0.0
var pause_box: Control
var cine_btn: Button
var bar: ColorRect
var bar_fill: ColorRect
var minimap: Control
var city_hud: Control # mundo abierto: minimapa que gira, mapa grande y GPS
var opts: RefCounted
var opts_box: Control
var opts_body: VBoxContainer
var opts_col: VBoxContainer
var opts_title: Label
var opts_stack: Array = []
var opts_page := ""
var opts_arg = null
var opts_panel: PanelContainer
var opts_scroll: ScrollContainer
var online_panel # online_panel.gd: chat, jugadores, amigos, reportes y mercado (sólo en el mundo online)
var convoy: RefCounted # ai/convoy.gd (Travesía X) o null
var rig: RefCounted # CameraRig del jugador (null en la aventura, que tiene sus propias cámaras)
var lab_on := false # ¿hay taller de prueba? (prueba de autos, Carrera rápida y drift)
var lab: Dictionary = {} # estado del auto de la prueba
var lab_defs: Dictionary = {}
var lab_tab: Array = [0]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	# bloque de arriba al centro (con las cámaras interiores queda poco tapado)
	top = Kit.panel(10, Color(0.04, 0.05, 0.08, 0.72))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(14, 10)
	add_child(top)
	var row := Kit.hbox(18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	pos_l = Kit.label("", 40, Kit.GOLD)
	row.add_child(pos_l)
	var col := Kit.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	time_l = Kit.label("0:00.00", 30)
	col.add_child(time_l)
	lap_l = Kit.label("", 18, Kit.MUTED)
	col.add_child(lap_l)
	sub_l = Kit.label("", 18, Kit.MUTED)
	big_l = Kit.label("", 120, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	big_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	big_l.add_theme_constant_override("outline_size", 14)
	big_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_l.position.y = -40
	add_child(big_l)
	drift_l = Kit.label("", 54, Color(0.55, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	drift_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	drift_l.add_theme_constant_override("outline_size", 10)
	drift_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	drift_l.offset_top = 56
	drift_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drift_l)
	toast_l = Kit.label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	toast_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_l.add_theme_constant_override("outline_size", 8)
	toast_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_l.offset_top = 150
	add_child(toast_l)
	minimap = MiniMap.new()
	add_child(minimap)
	_build_pause()

## Minimapa: el recorrido (se dibuja una vez) y los autos (se mueven)
class MiniMap extends Control:
	var pts := PackedVector2Array()
	var seg_a := -1
	var seg_b := -1
	var cars: Array = []
	var colors: Array = []
	var minv := Vector2.ZERO
	var scale_k := 1.0
	var box := Vector2(210, 120)
	var tick := 0.0

	func setup_track(track, seg, colors_in: Array) -> void:
		colors = colors_in
		var n: int = track.n
		var raw := PackedVector2Array()
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		var step := maxi(1, n / 160)
		for i in range(0, n, step):
			var p: Vector3 = track.samples[i]
			var q := Vector2(p.x, -p.z) # el norte (−z) queda arriba
			raw.append(q)
			lo = lo.min(q)
			hi = hi.max(q)
		var sz := hi - lo
		var m := 8.0
		scale_k = minf((box.x - 2 * m) / maxf(sz.x, 1.0), (box.y - 2 * m) / maxf(sz.y, 1.0))
		minv = lo - (box - sz * scale_k) * 0.5 / scale_k
		pts.clear()
		for q in raw:
			pts.append((q - minv) * scale_k)
		if seg is Array:
			seg_a = int(floor(float(seg[0]) * float(raw.size())))
			seg_b = int(floor(float(seg[1]) * float(raw.size())))
		custom_minimum_size = box
		size = box
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	## Pistas sin recorrido (plaza de drift): se dibujan las calles como polilíneas y un recuadro
	var lines: Array = []
	func setup_lines(polys: Array, bounds: Rect2, colors_in: Array) -> void:
		colors = colors_in
		lines.clear()
		var sz := bounds.size
		var m := 8.0
		scale_k = minf((box.x - 2 * m) / maxf(sz.x, 1.0), (box.y - 2 * m) / maxf(sz.y, 1.0))
		minv = Vector2(bounds.position.x, -bounds.end.y) - (box - sz * scale_k) * 0.5 / scale_k
		for pl in polys:
			var q := PackedVector2Array()
			for p in (pl as PackedVector2Array):
				q.append((Vector2(p.x, -p.y) - minv) * scale_k)
			lines.append(q)
		pts = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		custom_minimum_size = box
		size = box
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func set_cars(list: Array) -> void:
		cars = list
		queue_redraw()

	func _to_map(x: float, z: float) -> Vector2:
		return (Vector2(x, -z) - minv) * scale_k

	func _draw() -> void:
		if pts.size() < 3:
			return
		draw_rect(Rect2(Vector2.ZERO, box), Color(0.03, 0.05, 0.08, 0.62), true)
		draw_rect(Rect2(Vector2.ZERO, box), Color(1, 1, 1, 0.18), false, 1.5)
		var loop := pts.duplicate()
		loop.append(pts[0])
		if not lines.is_empty():
			for q in lines:
				draw_polyline(q, Color(1, 1, 1, 0.28), 5.0, true)
				draw_polyline(q, Color(0.55, 0.6, 0.68, 0.9), 2.5, true)
		else:
			draw_polyline(loop, Color(1, 1, 1, 0.28), 5.0, true)
			draw_polyline(loop, Color(0.55, 0.6, 0.68, 0.9), 2.5, true)
		if seg_a >= 0 and seg_b > seg_a:
			draw_polyline(pts.slice(seg_a, mini(seg_b + 1, pts.size())), Color(1.0, 0.55, 0.15), 3.5, true)
		if lines.is_empty():
			draw_circle(pts[maxi(seg_a, 0)], 4.0, Color(0.3, 0.9, 0.5))
		for i in range(cars.size() - 1, -1, -1):
			var c: Array = cars[i]
			if absf(float(c[0])) > 5.0e4:
				continue # auto eliminado (fuera de la pista)
			var pos := _to_map(float(c[0]), float(c[1]))
			if i == 0:
				draw_circle(pos, 6.0, Color.WHITE)
				draw_circle(pos, 4.2, Color(1.0, 0.48, 0.1))
			else:
				draw_circle(pos, 3.8, colors[i] if i < colors.size() else Color.WHITE)

func setup(s: RefCounted, c: Dictionary, r: Array) -> void:
	session = s
	cfg = c
	rivals = r
	var t := str(c.get("type", "race"))
	pos_l.visible = t == "race"
	lap_l.visible = true
	var cols: Array = []
	for x in r:
		cols.append(x["color"])
	if city_hud != null:
		city_hud.queue_free()
		city_hud = null
	if t == "city":
		minimap.visible = false
		city_hud = CityHud.new()
		add_child(city_hud)
		city_hud.setup(s.track, func(m: String) -> void: toast(m))
		pos_l.visible = false
	elif t == "drift":
		var polys: Array = (s.track.map_lines as Array)
		minimap.setup_lines(polys, s.track.map_bounds, cols)
	else:
		minimap.setup_track(s.track, c.get("seg"), cols)

func big(t: String, color := Color.WHITE) -> void:
	big_l.text = t
	big_l.add_theme_color_override("font_color", color)
	big_t = 1.1

func toast(t: String, kind := "") -> void:
	toast_l.text = t
	toast_l.add_theme_color_override("font_color", Kit.GREEN if kind == "up" else (Kit.RED if kind == "down" else Color.WHITE))
	toast_t = 2.2

func update_hud(dt: float, n_cars: int, car_list: Array = []) -> void:
	# el minimapa va arriba a la izquierda, debajo del cronómetro (no tapa el espejo ni los botones)
	minimap.position = Vector2(14.0, 100.0)
	tick += dt
	if city_hud != null and not car_list.is_empty():
		city_hud.update_hud(dt, car_list[0])
	if tick > 0.05:
		tick = 0.0
		var L: Array = []
		for c in car_list:
			L.append([c.snap.px, c.snap.pz])
		minimap.set_cars(L)
	if session == null:
		top.visible = false
		return
	top.visible = true
	var s = session
	if s.state == "countdown":
		time_l.text = "0:00.00"
	else:
		time_l.text = Kit.fmt_time(s.time)
	var t := str(cfg.get("type", "race"))
	if t == "race" and convoy != null:
		pos_l.visible = false
	elif t == "race":
		pos_l.text = "%d/%d" % [s.position_of(0, n_cars), n_cars]
	var rule_t: Variant = s.get("rule_text") # sólo las sesiones de ruta lo tienen
	if rule_t is String and rule_t != "": # persecución / eliminación: el texto y el aviso los arma race_rules.gd
		lap_l.text = rule_t
		drift_l.text = str(s.get("rule_sub"))
		drift_l.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if s.get("rule_warn") == true else Color(0.6, 1.0, 0.7))
		drift_l.add_theme_font_size_override("font_size", 24)
	elif t == "drift":
		time_l.text = Kit.fmt_time(s.remaining()) if s.state != "countdown" else Kit.fmt_time(s.limit)
		pos_l.visible = true
		pos_l.text = "x%d" % s.mult
		lap_l.text = tr("TOTAL %s") % _pts(s.total)
		if s.duel:
			var bn := str(rivals[1]["name"]) if rivals.size() > 1 else "BOT"
			lap_l.text += "  ·  🤖 %s %s" % [bn, _pts(s.bot_score)]
		drift_l.text = ("%s  ·  %d°" % [_pts(s.cur), int(s.angle_deg)]) if (s.cur > 0.0 and s.state == "run") else ""
		drift_l.add_theme_color_override("font_color", [Color(0.55, 0.85, 1.0), Color(0.55, 0.85, 1.0), Color(1.0, 0.9, 0.4), Color(1.0, 0.7, 0.25), Color(1.0, 0.5, 0.2), Color(1.0, 0.35, 0.3)][clampi(s.mult, 0, 5)])
	elif t == "city":
		lap_l.text = "%s · %.1f km" % [Tr.t("DREAM CITY"), s.odo / 1000.0]
	elif t == "free":
		lap_l.text = "PRUEBA LIBRE · salí desde la pausa"
	elif t == "drift":
		pass
	elif convoy != null:
		var left_c := maxf(s.race_len - maxf(s.prog[0], 0.0), 0.0)
		lap_l.text = "🚙 CONVOY · %.1f km a la meta · unión %d %%" % [left_c / 1000.0, int(round(convoy.cohesion() * 100.0))]
		drift_l.text = str(convoy.text)
		drift_l.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if (convoy.lost or convoy.out_gap > 220.0) else Color(1.0, 0.85, 0.3))
		drift_l.add_theme_font_size_override("font_size", 34)
		if str(convoy.section_new) != "":
			toast(str(convoy.section_new))
			convoy.section_new = ""
	elif s.laps > 1:
		lap_l.text = "VUELTA %d/%d" % [s.lap_of_player(), s.laps]
	else:
		var left := maxf(s.race_len - maxf(s.prog[0], 0.0), 0.0)
		lap_l.text = ("%d m a la meta" % int(left)) if left < 1000.0 else ("%.1f km a la meta" % (left / 1000.0))
	# mensajes del juego
	for m in s.messages:
		if m[1] == "big":
			big(str(m[0]), Kit.GOLD)
		else:
			toast(str(m[0]), str(m[1]))
	if big_t > 0.0:
		big_t -= dt
		big_l.modulate.a = clampf(big_t / 0.5, 0.0, 1.0)
		if big_t <= 0.0:
			big_l.text = ""

## Los avisos se apagan solos aunque no haya sesión que actualice el HUD (aventura, pausa)
func _process(dt: float) -> void:
	if toast_t > 0.0:
		toast_t -= dt
		toast_l.modulate.a = clampf(toast_t / 0.5, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_l.text = ""

static func _pts(v: float) -> String:
	var n := int(roundf(v))
	var txt := str(n)
	var out := ""
	var cnt := 0
	for i in range(txt.length() - 1, -1, -1):
		out = txt[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "." + out
	return out + " pts"

func _build_pause() -> void:
	pause_box = Control.new()
	pause_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_box.visible = false
	add_child(pause_box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.18)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_box.add_child(dim)
	var cc := Control.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_box.add_child(cc)
	# panel a la izquierda (a la derecha se ve el auto y la cámara) con botones grandes de dos en dos; si no entra, se desliza
	var p := Kit.panel(14)
	p.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p.anchor_right = 0.46
	p.offset_left = 12
	p.offset_top = 12
	p.offset_bottom = -12
	p.offset_right = 0
	cc.add_child(p)
	var sc := TouchScroll.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(sc)
	pause_col = Kit.vbox(8)
	pause_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(pause_col)
	_fill_pause()

var pause_col: VBoxContainer

## Los botones se rearman al abrir la pausa (el taller y el ajuste de cámara solo aparecen si corresponden)
func _fill_pause() -> void:
	for c in pause_col.get_children():
		c.queue_free()
	pause_col.add_child(Kit.label("PAUSA", 34, Kit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var go := Kit.button("▶  SEGUIR", func(): resume_pressed.emit(), true, 26, Vector2(0, 66))
	pause_col.add_child(go)
	var pair := func(a: Button, b: Button) -> void:
		var row := Kit.hbox(8)
		pause_col.add_child(row)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		if b != null:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
	var sz := Vector2(0, 62)
	var cam_b := Kit.button("🎥  CÁMARA", func(): camera_pressed.emit(), false, 19, sz)
	var adj_b: Button = null
	if rig != null:
		adj_b = Kit.button("📐  AJUSTAR CÁMARA", func(): open_page("camadj"), false, 19, sz)
	pair.call(cam_b, adj_b)
	cine_btn = Kit.button("🎬  MODO CINE", func(): cine_pressed.emit(), false, 19, sz)
	pair.call(cine_btn, Kit.button("⚙  OPCIONES", func(): open_options(), false, 19, sz))
	if online_panel != null:
		var on_b := Kit.button("🌐  ONLINE  ·  CHAT, JUGADORES, MERCADO", func(): open_page("on_home"), true, 19, sz)
		on_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pause_col.add_child(on_b)
		if city_hud != null:
			var map_b := Kit.button("🗺  MAPA / GPS", func() -> void:
				resume_pressed.emit()
				city_hud.call_deferred("_set_big", true), false, 19, sz)
			map_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pause_col.add_child(map_b)
	var ed_b := Kit.button("🕹  MODIFICAR CONTROLES", func(): edit_controls_pressed.emit(), false, 19, sz)
	ed_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_col.add_child(ed_b)
	if lab_on:
		var lb := Kit.button("🔧  TALLER DE PRUEBA  (grip, suspensión, potencia…)", func(): open_page("lab"), false, 19, sz)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pause_col.add_child(lb)
	pair.call(Kit.button("↺  REINICIAR", func(): restart_pressed.emit(), false, 19, sz), Kit.button("✕  SALIR", func(): quit_pressed.emit(), false, 19, sz))
	cine_btn.text = "🎬  SALIR DEL MODO CINE" if cine_on else "🎬  MODO CINE"

var cine_on := false

## Modo cine: se esconden los paneles del HUD (la pausa y las opciones siguen funcionando)
func set_cine(on: bool) -> void:
	for c in get_children():
		if c != pause_box and c != opts_box and c is CanvasItem:
			(c as CanvasItem).visible = not on
	cine_on = on
	if cine_btn != null:
		cine_btn.text = "🎬  SALIR DEL MODO CINE" if on else "🎬  MODO CINE"

func set_paused(on: bool) -> void:
	if on:
		_fill_pause()
		big_t = 0.0
		big_l.text = ""
		toast_t = 0.0 if toast_l.text == "" else toast_t
	pause_box.visible = on
	pause_box.mouse_filter = Control.MOUSE_FILTER_STOP
	if city_hud != null:
		city_hud.set_paused(on)

# ───────────────────────── opciones dentro de la carrera ─────────────────────────
## Las mismas pantallas de opciones del menú; cada cambio se aplica en el momento (options_changed) y se ve detrás
func setup_options(profile: RefCounted, sfx: Node) -> void:
	opts = OptionsUi.new()
	opts.profile = profile
	opts.sfx = sfx
	opts.nav = func(n: String, a) -> void: _opts_go(n, a)
	opts.set_title = func(t: String) -> void: opts_title.text = t
	opts.changed.connect(func(key: String) -> void: options_changed.emit(key))
	opts_box = Control.new()
	opts_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	opts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	opts_box.visible = false
	add_child(opts_box)

## Activa las páginas online de la pausa (sólo si el mundo se abrió desde Modo online con cuenta)
func setup_online(social: Node, profile: RefCounted) -> void:
	online_panel = OnlinePanel.new()
	online_panel.setup(social, profile, self)

func open_options() -> void:
	pause_box.visible = false
	opts_box.visible = true
	opts_stack.clear()
	opts_page = ""
	_opts_go("options", null, false)

## Páginas propias de la pausa (ajuste de cámara, taller de prueba): el mismo panel de la izquierda que las opciones
func open_page(name: String) -> void:
	pause_box.visible = false
	opts_box.visible = true
	opts_stack.clear()
	opts_page = ""
	_opts_go(name, null, false)

func _opts_close() -> void:
	if online_panel != null:
		online_panel.closed()
	opts_box.visible = false
	pause_box.visible = true

func _opts_back() -> void:
	if opts_stack.is_empty():
		_opts_close()
		return
	var prev: Array = opts_stack.pop_back()
	_opts_go(prev[0], prev[1], false)

func _opts_go(name: String, arg, push := true) -> void:
	if opts_page != "" and push and (name != opts_page or arg != opts_arg):
		opts_stack.append([opts_page, opts_arg])
	opts_page = name
	opts_arg = arg
	if opts_panel != null:
		opts_panel.queue_free()
	opts_panel = Kit.panel(12)
	opts_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	opts_panel.anchor_right = 0.475
	opts_panel.offset_left = 12
	opts_panel.offset_top = 12
	opts_panel.offset_bottom = -12
	opts_panel.offset_right = 0
	opts_box.add_child(opts_panel)
	opts_col = Kit.vbox(8)
	opts_panel.add_child(opts_col)
	var head := Kit.hbox(8)
	opts_col.add_child(head)
	head.add_child(Kit.button("← ATRÁS", func(): opts.sfx.play("click"); _opts_back(), false, 16, Vector2(104, 40)))
	opts_title = Kit.label("", 26, Kit.ACCENT)
	opts_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(opts_title)
	opts_scroll = TouchScroll.new()
	opts_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opts_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_col.add_child(opts_scroll)
	opts_body = Kit.vbox(8)
	opts_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_scroll.add_child(opts_body)
	if online_panel != null and not name.begins_with("on_"):
		online_panel.closed()
	if name.begins_with("on_") and online_panel != null:
		online_panel.build(name, arg, opts_body)
	elif name == "fx":
		opts.fx_page(opts_body, opts_col)
	elif name == "camadj":
		_cam_page()
	elif name == "lab":
		_lab_page()
	else:
		opts.options_page(opts_body, arg)


# ───────────────────────── ajuste de cámara ─────────────────────────
## Por cada cámara: distancia (más atrás o más adelante), altura, lado y campo de visión. Se guarda en el perfil.
func _cam_page() -> void:
	opts_title.text = Tr.t("AJUSTE DE CÁMARA")
	if rig == null:
		return
	var mode: String = rig.mode()
	var inside := mode == "onboard" or mode == "rearcabin" or mode == "hood" or mode == "bumper"
	var head := Kit.hbox(6)
	opts_body.add_child(head)
	head.add_child(Kit.button("◀", func() -> void:
		cam_step.emit(-1)
		_opts_go("camadj", null, false), false, 22, Vector2(60, 52)))
	var nl := Kit.label(Tr.t(str(rig.cam_name())), 21, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nl)
	head.add_child(Kit.button("▶", func() -> void:
		cam_step.emit(1)
		_opts_go("camadj", null, false), false, 22, Vector2(60, 52)))
	if mode == "custom":
		opts_body.add_child(Kit.wrap("Con el juego en marcha: arrastrá un dedo por la pantalla para girar la cámara y pellizcá con dos dedos para acercarla o alejarla.", 14, Kit.MUTED, 200))
	var rows := [
		["dist", "Distancia (largo)", -0.6 if inside else -4.0, 0.6 if inside else 10.0, 0.05 if inside else 0.1, "m", "Más atrás (+) o más adelante (−) de donde está."],
		["height", "Altura", -0.3 if inside else -1.5, 0.3 if inside else 4.0, 0.05 if inside else 0.1, "m", "Más arriba (+) o más abajo (−)."],
		["side", "Posición lateral", -0.3 if inside else -3.0, 0.3 if inside else 3.0, 0.05 if inside else 0.1, "m", "Corre la cámara a la izquierda (−) o a la derecha (+)."],
		["fov", "Ángulo de visión", -15.0, 25.0, 1.0, "°", "Más ángulo ve más cosas y da más sensación de velocidad; menos ángulo acerca."],
	]
	var info := Kit.wrap("", 13, Kit.MUTED, 200)
	for r in rows:
		var key: String = r[0]
		var v0: float = rig.adj_of(key)
		var row := Kit.hbox(8)
		opts_body.add_child(row)
		var lbl := Kit.label(str(r[1]), 16, Kit.TEXT)
		lbl.custom_minimum_size.x = 168
		lbl.clip_text = true
		row.add_child(lbl)
		var sl := HSlider.new()
		sl.min_value = float(r[2])
		sl.max_value = float(r[3])
		sl.step = float(r[4])
		sl.value = v0
		sl.custom_minimum_size = Vector2(0, 40)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sl)
		var unit: String = r[5]
		var vl := Kit.label("%+.2f %s" % [v0, unit] if inside and key != "fov" else "%+.1f %s" % [v0, unit], 15, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size.x = 84
		row.add_child(vl)
		var txt := Tr.t(str(r[6]))
		sl.value_changed.connect(func(nv: float) -> void:
			rig.set_adj(key, nv)
			vl.text = "%+.2f %s" % [nv, unit] if inside and key != "fov" else "%+.1f %s" % [nv, unit]
			info.text = txt)
		sl.drag_ended.connect(func(_c: bool) -> void: camadj_changed.emit())
	opts_body.add_child(info)
	opts_body.add_child(Kit.button("↺  RESTABLECER ESTA CÁMARA", func() -> void:
		rig.adj.erase(str(rig.index))
		camadj_changed.emit()
		_opts_go("camadj", null, false), false, 18, Vector2(0, 52)))

# ───────────────────────── taller de prueba ─────────────────────────
func _lab_page() -> void:
	opts_title.text = Tr.t("TALLER DE PRUEBA")
	if lab.is_empty():
		return
	LabPanel.build(opts_body, lab, lab_defs, lab_tab, func() -> void: lab_changed.emit(), func() -> void: _opts_go("lab", null, false), func() -> void:
		lab_reset.emit()
		_opts_go("lab", null, false), opts.sfx if opts != null else null)
