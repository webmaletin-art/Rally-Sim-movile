extends Control
## HUD de la carrera: puesto, vuelta, tiempo, cuenta regresiva, avisos y menú de pausa.

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const OptionsUi := preload("res://game/ui/options_ui.gd")

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal tests_pressed
signal camera_pressed
signal options_changed(key: String)

var session: RefCounted
var cfg: Dictionary
var rivals: Array
var top: PanelContainer
var pos_l: Label
var lap_l: Label
var time_l: Label
var sub_l: Label
var big_l: Label
var toast_l: Label
var big_t := 0.0
var toast_t := 0.0
var pause_box: Control
var bar: ColorRect
var bar_fill: ColorRect
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
	toast_l = Kit.label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	toast_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_l.add_theme_constant_override("outline_size", 8)
	toast_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_l.offset_top = 150
	add_child(toast_l)
	_build_pause()

func setup(s: RefCounted, c: Dictionary, r: Array) -> void:
	session = s
	cfg = c
	rivals = r
	var t := str(c.get("type", "race"))
	pos_l.visible = t == "race"
	lap_l.visible = true

func big(t: String, color := Color.WHITE) -> void:
	big_l.text = t
	big_l.add_theme_color_override("font_color", color)
	big_t = 1.1

func toast(t: String, kind := "") -> void:
	toast_l.text = t
	toast_l.add_theme_color_override("font_color", Kit.GREEN if kind == "up" else (Kit.RED if kind == "down" else Color.WHITE))
	toast_t = 2.2

func update_hud(dt: float, n_cars: int) -> void:
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
	if t == "race":
		pos_l.text = "%d/%d" % [s.position_of(0, n_cars), n_cars]
	if s.laps > 1:
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
	if toast_t > 0.0:
		toast_t -= dt
		toast_l.modulate.a = clampf(toast_t / 0.5, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_l.text = ""

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
	var p := Kit.panel(18)
	p.position = Vector2(20, 80) # a un costado: se ve la cámara detrás mientras se elige
	cc.add_child(p)
	var v := Kit.vbox(12)
	v.custom_minimum_size = Vector2(340, 0)
	p.add_child(v)
	v.add_child(Kit.label("PAUSA", 38, Kit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.button("▶  SEGUIR", func(): resume_pressed.emit(), true))
	v.add_child(Kit.button("🎥  CÁMARA", func(): camera_pressed.emit()))
	v.add_child(Kit.button("↺  REINICIAR", func(): restart_pressed.emit()))
	v.add_child(Kit.button("⚙  OPCIONES (gráficos, sonido, efectos…)", func(): open_options()))
	v.add_child(Kit.button("🔧  PRUEBAS Y AJUSTES", func(): tests_pressed.emit()))
	v.add_child(Kit.button("✕  SALIR", func(): quit_pressed.emit()))

func set_paused(on: bool) -> void:
	if on:
		big_t = 0.0
		big_l.text = ""
		toast_t = 0.0 if toast_l.text == "" else toast_t
	pause_box.visible = on
	pause_box.mouse_filter = Control.MOUSE_FILTER_STOP

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

func open_options() -> void:
	pause_box.visible = false
	opts_box.visible = true
	opts_stack.clear()
	opts_page = ""
	_opts_go("options", null, false)

func _opts_close() -> void:
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
	opts_panel = Kit.panel(14)
	opts_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	opts_panel.anchor_right = 0.50
	opts_panel.offset_left = 14
	opts_panel.offset_top = 14
	opts_panel.offset_bottom = -14
	opts_panel.offset_right = 0
	opts_box.add_child(opts_panel)
	opts_col = Kit.vbox(10)
	opts_panel.add_child(opts_col)
	var head := Kit.hbox(10)
	opts_col.add_child(head)
	head.add_child(Kit.button("← ATRÁS", func(): opts.sfx.play("click"); _opts_back(), false, 18, Vector2(120, 46)))
	opts_title = Kit.label("", 28, Kit.ACCENT)
	opts_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(opts_title)
	opts_scroll = TouchScroll.new()
	opts_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	opts_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_col.add_child(opts_scroll)
	opts_body = Kit.vbox(10)
	opts_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opts_scroll.add_child(opts_body)
	if name == "fx":
		opts.fx_page(opts_body, opts_col)
	else:
		opts.options_page(opts_body, arg)
