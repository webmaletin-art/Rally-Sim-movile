extends Node
## Menú principal de GSkorp Rally: sala 3D con el auto y la tripulación detrás, y a la izquierda los paneles (inicio, carrera,
## carrera rápida, garaje, concesionaria, taller, ajuste, pintura, logros, opciones y resultados).
## Las pantallas más largas están en menu_career.gd y menu_garage.gd.

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const Showroom := preload("res://game/ui/showroom.gd")
const UiSfx := preload("res://game/audio/ui_sfx.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Rewards := preload("res://game/data/rewards.gd")
const Career := preload("res://game/ui/menu_career.gd")
const Garage := preload("res://game/ui/menu_garage.gd")
const Lens := preload("res://game/fx/lens.gd")
const OptionsUi := preload("res://game/ui/options_ui.gd")

var app: Node
var profile: RefCounted
var start_screen := "home"
var vehicles: Dictionary

var world: SubViewport
var view_rect: TextureRect
var showroom: Node3D
var layer: CanvasLayer
var root: Control
var panel: PanelContainer
var body: VBoxContainer
var title_l: Label
var credits_l: Label
var toast_l: Label
var toast_t := 0.0
var sfx: Node
var screen := ""
var screen_arg = null
var career: RefCounted
var garage: RefCounted
var frames := 0
var showcar := "" # prueba: muestra este auto en la sala
var autorace := "" # prueba: arranca directo este evento (p. ej. d2)
var shot_path := ""
var shot_frames := 0
var lens: Node
var opts: RefCounted
var col_box: VBoxContainer
var fx_slot := 0
var fx_rows: Array = []
var fx_slot_btns: Array = []
var stack: Array = [] # pantallas anteriores (para "atrás")

func _ready() -> void:
	vehicles = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--frames="):
			shot_frames = int(a.substr(9))
		elif a.begins_with("--mshot="):
			shot_path = a.substr(8)
		elif a.begins_with("--mframes="):
			shot_frames = int(a.substr(10))
		elif a.begins_with("--screen="):
			start_screen = a.substr(9)
		elif a.begins_with("--showcar="):
			showcar = a.substr(10)
		elif a.begins_with("--autorace="):
			autorace = a.substr(11)
	if (profile.d["owned"] as Dictionary).is_empty():
		_first_time()
	sfx = UiSfx.new()
	add_child(sfx)
	sfx.volume = float(profile.setting("volume")) / 100.0
	opts = OptionsUi.new()
	opts.profile = profile
	opts.sfx = sfx
	opts.nav = func(n: String, a) -> void: go(n, a)
	opts.set_title = func(t: String) -> void: title_l.text = t
	opts.reset_cb = _confirm_reset
	opts.changed.connect(func(key: String) -> void:
		if key == "fx":
			apply_fx()
		elif key == "recal":
			toast("El acelerómetro se calibra solo al empezar la carrera; para recalibrar usá Opciones desde la pausa"))
	career = Career.new()
	career.m = self
	garage = Garage.new()
	garage.m = self
	_build_world()
	_build_ui()
	if showcar != "":
		refresh_car(showcar, profile.new_car_state(showcar))
	# el premio del día, una sola vez por día
	var daily: Dictionary = profile.daily_check()
	if autorace != "" and not app.autorace_used:
		app.autorace_used = true
		var ev: Dictionary = Rewards.event_by_id(autorace)
		var tier: Dictionary = Rewards.tier_by_id(str(ev["tier"]))
		career._start_event(ev, tier)
		return
	var parts := start_screen.split(":")
	go(parts[0], parts[1] if parts.size() > 1 else null)
	if not daily.is_empty():
		toast("🎁 Premio diario: +%s (racha %d)" % [Kit.fmt_cr(float(daily["amount"])), int(daily["streak"])])
		sfx.play("coin")

## Primera vez: se entregan los autos iniciales (como en la versión web)
func _first_time() -> void:
	for id in CarBuild.catalog()["order"]:
		var c: Dictionary = CarBuild.catalog()["cars"][id]
		if c.get("starter", false):
			profile.give(id)
	profile.select("t1plus" if profile.owns("t1plus") else str(profile.d["owned"].keys()[0]))

# ───────────────────────── mundo 3D ─────────────────────────
func _build_world() -> void:
	var l0 := CanvasLayer.new()
	l0.layer = 0
	add_child(l0)
	world = SubViewport.new()
	world.msaa_3d = Viewport.MSAA_DISABLED
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(world)
	view_rect = TextureRect.new()
	view_rect.texture = world.get_texture()
	view_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view_rect.stretch_mode = TextureRect.STRETCH_SCALE
	view_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l0.add_child(view_rect)
	lens = Lens.new()
	add_child(lens)
	lens.attach(view_rect)
	apply_fx()
	showroom = Showroom.new()
	world.add_child(showroom)
	get_tree().root.size_changed.connect(_on_resize)
	_on_resize()
	refresh_car()

func _on_resize() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var sc := 0.62
	world.size = Vector2i(maxi(480, int(win.x * sc)), maxi(270, int(win.y * sc)))
	view_rect.position = Vector2.ZERO
	view_rect.size = get_viewport().get_visible_rect().size
	if showroom != null and showroom.cam != null:
		showroom.cam.keep_aspect = Camera3D.KEEP_HEIGHT

## Muestra en la sala el auto elegido (con sus piezas y su pintura)
func refresh_car(override_id := "", override_state := {}) -> void:
	var id: String = override_id if override_id != "" else profile.current_id()
	if id == "":
		return
	var st: Dictionary = override_state if not override_state.is_empty() else (profile.d["owned"][id] if profile.owns(id) else profile.new_car_state(id))
	showroom.set_car(id, st, vehicles)

# ───────────────────────── interfaz ─────────────────────────
func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	toast_l = Kit.label("", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	toast_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast_l.add_theme_constant_override("outline_size", 8)
	toast_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_l.position = Vector2(0, -24)
	layer.add_child(toast_l)

func toast(t: String) -> void:
	toast_l.text = t
	toast_t = 3.2
	toast_l.modulate.a = 1.0

## Pasa al filtro del menú lo elegido en Opciones → Efectos (se ve en la sala mientras se prueba)
func apply_fx() -> void:
	var a = profile.setting("fx")
	lens.level = int(profile.setting("lens2"))
	lens.fx = [int(a[0]), int(a[1]), int(a[2])] if a is Array and a.size() >= 3 else [0, 0, 0]

func _process(dt: float) -> void:
	lens.update(dt, 0.0)
	if toast_t > 0.0:
		toast_t -= dt
		toast_l.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_l.text = ""
	frames += 1
	if shot_frames > 0 and frames >= shot_frames:
		if shot_path != "":
			get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()

## Abre una pantalla. Cada una arma su contenido dentro del panel de la izquierda.
func go(name: String, arg = null, push := true) -> void:
	if screen != "" and push and (name != screen or arg != screen_arg):
		stack.append([screen, screen_arg])
	screen = name
	screen_arg = arg
	if panel != null:
		panel.queue_free()
	panel = Kit.panel(14)
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	var wide := name in ["career", "events", "event", "workshop", "tune", "garage", "dealer", "results", "goals", "options", "quick", "paint", "fx"]
	panel.anchor_right = 0.52 if wide else 0.40
	showroom.view_shift = 0.75 if wide else 0.5
	panel.offset_left = 14
	panel.offset_top = 14
	panel.offset_bottom = -14
	panel.offset_right = 0
	root.add_child(panel)
	var col := Kit.vbox(10)
	col_box = col
	panel.add_child(col)
	var head := Kit.hbox(10)
	col.add_child(head)
	if name != "home":
		head.add_child(Kit.button("← ATRÁS", back, false, 18, Vector2(120, 46)))
	title_l = Kit.label("", 30, Kit.ACCENT)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_l)
	credits_l = Kit.label("", 20, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(credits_l)
	update_credits()
	var sc := TouchScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	body = Kit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	match name:
		"home": _home()
		"options": opts.options_page(body, arg)
		"fx": opts.fx_page(body, col_box)
		"goals": _goals()
		"results": _results()
		"career", "events", "event", "quick": career.build(name, arg)
		"garage", "dealer", "workshop", "tune", "paint": garage.build(name, arg)
		_: _home()

func back() -> void:
	sfx.play("click")
	if stack.is_empty():
		go("home", null, false)
		return
	var prev: Array = stack.pop_back()
	go(prev[0], prev[1], false)

func update_credits() -> void:
	if credits_l != null:
		credits_l.text = "%s · Nv %d" % [Kit.fmt_cr(float(profile.credits)), int(profile.d["level"])]

func set_title(t: String) -> void:
	title_l.text = t

## Botón grande de menú
func menu_button(text: String, sub: String, cb: Callable, accent := false, enabled := true) -> Button:
	var b := Kit.button("", Callable(), accent, 22, Vector2(0, 66))
	b.disabled = not enabled
	var v := Kit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var col := Color(0.05, 0.06, 0.08) if accent else (Kit.TEXT if enabled else Kit.MUTED)
	v.add_child(Kit.label(text, 24, col, HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		v.add_child(Kit.label(sub, 15, col.darkened(0.15) if accent else Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	b.add_child(v)
	b.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		sfx.play("click")
		cb.call())
	return b

# ───────────────────────── inicio ─────────────────────────
func _home() -> void:
	title_l.text = ""
	var t := Kit.label("DREAM RACING", 44, Kit.ACCENT)
	body.add_child(t)
	var car_id: String = profile.current_id()
	var cm: Dictionary = CarBuild.catalog()["cars"][car_id]
	var st: Dictionary = profile.car()
	var V: Dictionary = CarBuild.build_params(vehicles[car_id], st)
	var pf: Dictionary = CarBuild.perf_of(V)
	var cls: Dictionary = CarBuild.class_of(int(pf["pi"]))
	var chip := Kit.label("%s %s  ·  Clase %s · PI %d" % [cm["brand"], cm["model"], cls["c"], int(pf["pi"])], 18, Kit.MUTED)
	body.add_child(chip)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(g)
	var next_ev := _next_event()
	var btns := [
		["🏆 CARRERA", "%d ⭐ · %d/%d eventos" % [profile.stars(), _done_events(), CarBuild.catalog()["events"].size()], func(): go("career"), true],
		["⚡ RÁPIDA", "elegí pista y rivales", func(): go("quick"), false],
		["🚗 GARAJE", "tus autos", func(): go("garage"), false],
		["🏬 CONCESIONARIA", "comprá autos", func(): go("dealer"), false],
		["🔧 TALLER", "piezas y neumáticos", func(): go("workshop"), false],
		["🎚 AJUSTE", "suspensión y más", func(): go("tune"), false],
		["🎨 PINTURA", "color y acabado", func(): go("paint"), false],
		["⭐ LOGROS", ("%d para cobrar" % Rewards.ach_ready(profile)) if Rewards.ach_ready(profile) > 0 else "objetivos", func(): go("goals"), false],
		["⚙ OPCIONES", "manejo, sonido, cámara", func(): go("options"), false],
		["📖 HISTORIA", "🔒 próximamente", func(): toast("El modo historia llega más adelante"), false],
	]
	for b in btns:
		var mb := menu_button(b[0], b[1], b[2], b[3], b[0] != "📖 HISTORIA")
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(mb)
	var test := menu_button("🔬 PRUEBAS", "rendimiento e informe", func(): app.start_race({}))
	test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(test)
	if not next_ev.is_empty():
		var cont := menu_button("▶ SEGUIR CARRERA", str(next_ev["name"]), func(): go("event", next_ev["id"]), true)
		body.add_child(cont)
		body.move_child(cont, 2)

func _done_events() -> int:
	var n := 0
	for k in profile.d["events"]:
		if int(profile.d["events"][k].get("medal", 0)) > 0:
			n += 1
	return n

## El primer evento abierto sin medalla
func _next_event() -> Dictionary:
	for t in CarBuild.catalog()["tiers"]:
		if not Rewards.tier_open(profile, t):
			continue
		for e in Rewards.events_of(str(t["id"])):
			if Rewards.event_locked(profile, e) == "" and int(profile.event_result(str(e["id"])).get("medal", 0)) == 0 and career.playable(e):
				return e
	return {}

# ───────────────────────── logros ─────────────────────────
func _goals() -> void:
	title_l.text = "LOGROS"
	var claimed: Dictionary = profile.d["claimed"]
	for a in CarBuild.catalog()["achievements"]:
		var id := str(a["id"])
		var got := claimed.has(id)
		var ok := Rewards.ach_done(profile, id)
		var p := Kit.panel(10, Kit.PANEL2 if not got else Color(0.1, 0.2, 0.14, 0.95))
		body.add_child(p)
		var row := Kit.hbox(12)
		p.add_child(row)
		row.add_child(Kit.label(str(a["icon"]), 34))
		var col := Kit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Kit.label(str(a["n"]), 22, Kit.GOLD if ok and not got else (Kit.GREEN if got else Kit.TEXT)))
		var dl := Kit.label(str(a["d"]), 16, Kit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 200
		col.add_child(dl)
		if got:
			row.add_child(Kit.label("COBRADO ✔", 18, Kit.GREEN))
		elif ok:
			row.add_child(Kit.button("COBRAR " + Kit.fmt_cr(float(a["cr"])), func(): _claim(a), true, 18, Vector2(170, 48)))
		else:
			row.add_child(Kit.label(Kit.fmt_cr(float(a["cr"])), 18, Kit.MUTED))

func _claim(a: Dictionary) -> void:
	profile.d["claimed"][a["id"]] = 1
	profile.earn(float(a["cr"]))
	sfx.play("buy")
	toast("%s %s · +%s" % [a["icon"], a["n"], Kit.fmt_cr(float(a["cr"]))])
	go("goals", null, false)

# ───────────────────────── opciones ─────────────────────────
func _confirm_reset() -> void:
	for c in body.get_children():
		c.queue_free()
	body.add_child(Kit.label("¿Borrar todo el progreso?", 28, Kit.RED))
	body.add_child(Kit.label("Se pierden autos, dinero y medallas. No se puede deshacer.", 18, Kit.MUTED))
	body.add_child(Kit.button("Sí, borrar todo", func():
		profile.reset()
		_first_time()
		refresh_car()
		stack.clear()
		go("home", null, false), false, 22))
	body.add_child(Kit.button("Cancelar", func(): go("options", null, false), true, 22))

# ───────────────────────── resultados ─────────────────────────
func _results() -> void:
	var r: Dictionary = app.pending_result
	title_l.text = "RESULTADO"
	var cfg: Dictionary = r.get("cfg", {})
	body.add_child(Kit.label(str(r.get("event_name", "")), 26, Kit.TEXT))
	var t := str(r.get("type", "race"))
	var big := ""
	match t:
		"race": big = "%d° puesto" % int(r["pos"])
		"trap": big = "%d km/h" % int(r["value"])
		_: big = Kit.fmt_time(float(r["time"]))
	var bl := Kit.label(big, 54, Kit.GOLD)
	body.add_child(bl)
	if bool(r.get("show_medal", false)):
		var med := int(r["medal"])
		var names := ["Sin medalla", "🥉 Bronce", "🥈 Plata", "🥇 ORO"]
		body.add_child(Kit.label(names[med], 34, [Kit.MUTED, Color(0.85, 0.55, 0.3), Color(0.8, 0.85, 0.92), Kit.GOLD][med]))
	if bool(r.get("record", false)):
		body.add_child(Kit.label("🏅 ¡NUEVO RÉCORD!", 24, Kit.GREEN))
	var row := Kit.hbox(10)
	body.add_child(row)
	var again := Kit.button("↺ REPETIR", func(): app.start_race(cfg), true, 22)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	var to := "career" if not cfg.get("event", {}).is_empty() else "home"
	var cont := Kit.button("CONTINUAR", func(): stack.clear(); go(to, null, false), false, 22)
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cont)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	body.add_child(grid)
	var kv := [["Recompensa", Kit.fmt_cr(float(r["cr"]))], ["Experiencia", "+%d XP" % int(r["xp"])], ["Velocidad máxima", "%d km/h" % int(r["max_kmh"])], ["Distancia", "%.2f km" % (float(r["odo"]) / 1000.0)]]
	for p in kv:
		grid.add_child(Kit.label(p[0], 20, Kit.MUTED))
		grid.add_child(Kit.label(p[1], 20, Kit.TEXT))
	if str(r.get("cup_msg", "")) != "":
		body.add_child(Kit.label(str(r["cup_msg"]), 22, Kit.GOLD))
	for u in r.get("level_ups", []):
		body.add_child(Kit.label("⬆ ¡NIVEL %d! +%s" % [int(u["level"]), Kit.fmt_cr(float(u["bonus"]))], 24, Kit.GREEN))
	if t == "race" and not (r["standings"] as Array).is_empty():
		body.add_child(Kit.label("CLASIFICACIÓN", 16, Kit.MUTED))
		var i := 0
		for s in r["standings"]:
			i += 1
			var line := "%d.  %s   %s" % [i, s["name"], Kit.fmt_time(float(s["time"])) if float(s["time"]) >= 0.0 else "—"]
			body.add_child(Kit.label(line, 20, Kit.ACCENT if s["player"] else Kit.TEXT))
	sfx.play("finish")
