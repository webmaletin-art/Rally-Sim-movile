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
const MenuAdventure := preload("res://game/ui/menu_adventure.gd")
const MenuAbout := preload("res://game/ui/menu_about.gd")
const MenuAccount := preload("res://game/ui/menu_account.gd")
const MenuWorld := preload("res://game/ui/menu_world.gd")
const MenuPerf := preload("res://game/ui/menu_perf.gd")
const MenuStore := preload("res://game/ui/menu_store.gd")
const Release := preload("res://game/data/release.gd")
const Autotune := preload("res://game/autotune.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const OnlineSocial := preload("res://game/online/online_social.gd")
const CityLayout := preload("res://game/city/city_layout.gd")

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
var adventure: RefCounted
var about: RefCounted
var account: RefCounted
var world_ui: RefCounted # menu_world.gd: mundo abierto y modo online
var world_online := false # el mundo se abre desde Modo online (con cuenta): se activan el chat, los jugadores y el mercado
var perf: RefCounted
var store: RefCounted
var frames := 0
var showcar := "" # prueba: muestra este auto en la sala
var perf_arg := ""
var autotest := "" # prueba: arranca directo una prueba libre de este auto
var sky_arg := "" # prueba: fuerza el clima de la carrera (day, overcast, sunset, dusk, rain)
var no_consent := false # prueba: salta la pantalla de aceptación del primer inicio
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
		elif a.begins_with("--autotest="):
			autotest = a.substr(11)
		elif a.begins_with("--perf="): # prueba: arranca directo la prueba de rendimiento (quick | full)
			perf_arg = a.substr(7)
		elif a.begins_with("--sky="):
			sky_arg = a.substr(6)
		elif a.begins_with("--autorace="):
			autorace = a.substr(11)
		elif a == "--noconsent":
			no_consent = true
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
		elif key == "retune":
			start_autotune()
		elif key == "recal":
			toast("El acelerómetro se calibra solo al empezar la carrera; para recalibrar usá Opciones desde la pausa"))
	career = Career.new()
	career.m = self
	garage = Garage.new()
	garage.m = self
	adventure = MenuAdventure.new()
	adventure.m = self
	about = MenuAbout.new()
	about.m = self
	account = MenuAccount.new()
	account.m = self
	world_ui = MenuWorld.new()
	world_ui.m = self
	perf = MenuPerf.new()
	perf.m = self
	store = MenuStore.new()
	store.m = self
	_build_world()
	_build_ui()
	start_autotune()
	if showcar != "":
		refresh_car(showcar, profile.new_car_state(showcar))
	# el premio del día, una sola vez por día
	var daily: Dictionary = profile.daily_check()
	if autotest != "" and not app.autorace_used:
		app.autorace_used = true
		var at := autotest.split("@") # prueba: --autotest=gt (lago) o --autotest=gt@drift (plaza de drift)
		var tc := {"type": "free", "track": "lake", "ai": 0, "sky": "day", "car": at[0], "state": profile.new_car_state(at[0]), "testCar": true, "back": "dealer", "seed": 7}
		if at.size() > 1 and at[1] == "aurelia": # mundo abierto (prueba)
			tc["type"] = "city"
			tc["track"] = "aurelia"
			tc["testCar"] = false
			tc["resume"] = [0.0, 40.0, 0.0] # las pruebas arrancan en la plaza (no en un estacionamiento) salvo que pidan otra pose
			for ai in range(2, at.size()):
				if at[ai].begins_with("pose:"): # prueba: arranca en este punto (x,z,rumbo en grados)
					var pp := at[ai].substr(5).split(",")
					tc["resume"] = [float(pp[0]), float(pp[1]), deg_to_rad(float(pp[2]))]
				elif at[ai] == "spawn":
					tc.erase("resume") # prueba: se aparece dentro de un estacionamiento, como en el juego
				elif at[ai].begins_with("tod:"):
					tc["tod"] = float(at[ai].substr(4)) # prueba: hora del día fija
					tc["tod_frozen"] = true
				elif at[ai].begins_with("fuel:"):
					tc["fuel"] = float(at[ai].substr(5)) # prueba: nafta con la que arranca (0..1)
				elif at[ai] == "map":
					tc["bigmap"] = true # prueba: abre el mapa grande con el GPS puesto al concesionario
				elif at[ai] != "-":
					tc["gpsdrive"] = at[ai] # --autotest=gt@aurelia@concesionario: el auto va solo hasta ahí
		if at.size() > 1 and at[1] == "paper":
			tc["type"] = "timetrial"
			tc["track"] = "paperRace"
		if at.size() > 1 and career.is_fantasy(at[1]): # mapa fantasía (dream, marte, luna, anillo) contra un rival a la par (prueba)
			tc["type"] = "race"
			tc["track"] = at[1]
			tc["ai"] = 1
			tc["skill"] = 0.9
			tc["testCar"] = false
			tc["quick"] = true
		if at.size() > 1 and at[1] == "picada": # picada contra un rival (prueba)
			tc["type"] = "race"
			tc["track"] = "picada"
			tc["drag"] = true
			tc["ai"] = 1
			tc["skill"] = 0.9
		if at.size() > 1 and (at[1] == "drift" or at[1] == "duel"):
			tc["type"] = "drift"
			tc["track"] = "drift"
			tc["time"] = 1800
			if at[1] == "duel": # duelo contra el bot (prueba)
				tc["time"] = 20
				tc["duel"] = true
				tc["ai"] = 1
				tc["duelSkill"] = 1.0
		launch(tc, false)
		return
	if perf_arg != "" and not app.autorace_used and not Release.store():
		app.autorace_used = true
		perf._start(perf_arg)
		return
	if autorace != "" and not app.autorace_used:
		app.autorace_used = true
		var ev: Dictionary = Rewards.event_by_id(autorace)
		var tier: Dictionary = Rewards.tier_by_id(str(ev["tier"]))
		if sky_arg != "":
			ev = ev.duplicate()
			ev["sky"] = sky_arg
		career._start_event(ev, tier, false)
		return
	var parts := start_screen.split(":")
	var arg0 = parts[1] if parts.size() > 1 else null
	if parts[0] == "level":
		arg0 = {"type": "race", "track": "lake", "ai": 3, "car": profile.current_id(), "state": profile.car()} # solo para probar la pantalla
	if start_screen == "home" and not no_consent and MenuAbout.needs_consent(profile):
		go("consent")
	elif start_screen == "home" and not no_consent and MenuAccount.should_offer(profile, app.online):
		go("account", "welcome") # una sola vez: crear cuenta con correo (opcional)
	else:
		go(parts[0], arg0)
		if start_screen == "home":
			store.offer_popup() # cartel de ofertas (una vez por sesión)
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
	var sc := 0.8
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

## Ajuste automático de gráficos según el teléfono: nivel inicial por el hardware y corrección midiendo los cuadros del menú (ver autotune.gd)
func start_autotune() -> void:
	if autotest != "" or perf_arg != "" or autorace != "" or shot_path != "" or not Autotune.pending(profile):
		return
	Autotune.apply_tier(profile, Autotune.device_tier())
	var pr := Autotune.Probe.new()
	pr.apply = func(t: int) -> void: Autotune.apply_tier(profile, t)
	pr.done.connect(func(tier: int, _changed: bool) -> void:
		toast(tr("⚙ Gráficos ajustados a tu teléfono: %s") % tr(Autotune.tier_name(tier))))
	add_child(pr)
	pr.begin(profile)

func toast(t: String) -> void:
	toast_l.text = t
	toast_t = 3.2
	toast_l.modulate.a = 1.0

## Pasa al filtro del menú lo elegido en Opciones → Efectos (se ve en la sala mientras se prueba)
func apply_fx() -> void:
	lens.apply_settings(profile)

func _process(dt: float) -> void:
	lens.update(dt, 0.0)
	if toast_t > 0.0:
		toast_t -= dt
		toast_l.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_l.text = ""
	frames += 1
	if frames == 25 and OS.get_cmdline_user_args().has("--shopback") and not app.city_return.is_empty():
		return_to_city() # prueba: sale del taller y vuelve a la calle
	if shot_frames > 0 and frames >= shot_frames:
		if shot_path != "":
			get_viewport().get_texture().get_image().save_png(shot_path)
		get_tree().quit()

## Abre una pantalla. Cada una arma su contenido dentro del panel de la izquierda.
var adv_car_shown := false
func go(name: String, arg = null, push := true) -> void:
	if name == "home":
		garage.shop = ""
	if adv_car_shown and not name.begins_with("adv"):
		adv_car_shown = false
		refresh_car()
	if screen != "" and push and (name != screen or arg != screen_arg):
		stack.append([screen, screen_arg])
	screen = name
	screen_arg = arg
	if panel != null:
		panel.queue_free()
	panel = Kit.panel(12)
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	var frac := 0.385 if name == "home" else 0.475
	panel.anchor_right = frac
	showroom.view_shift = 1.9 * frac - 0.26 # el auto queda en el medio de lo que no tapa el panel
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_bottom = -12
	panel.offset_right = 0
	root.add_child(panel)
	var col := Kit.vbox(8)
	col_box = col
	panel.add_child(col)
	var head := Kit.hbox(8)
	col.add_child(head)
	if name != "home" and name != "consent" and not (name == "account" and arg == "welcome"):
		var leaving: bool = stack.is_empty() and not app.city_return.is_empty()
		head.add_child(Kit.button("🚪 SALIR" if leaving else "← ATRÁS", back, false, 16, Vector2(104, 40)))
	title_l = Kit.label("", 26, Kit.ACCENT)
	title_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l.clip_text = true
	title_l.custom_minimum_size.x = 40
	head.add_child(title_l)
	credits_l = Kit.label("", 18, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(credits_l)
	update_credits()
	var sc := TouchScroll.new() # red de seguridad: las pantallas están armadas para entrar sin desplazar
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	body = Kit.vbox(8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	match name:
		"home": _home()
		"options": opts.options_page(body, arg)
		"fx": opts.fx_page(body, col_box)
		"level": _level_screen(arg)
		"goals": _goals()
		"results": _results()
		"quick_drift":
			career.quick["fantasy"] = false
			career.quick["map"] = "drift"
			career.build("quick", arg)
		"career", "events", "event", "quick", "fantasy": career.build(name, arg)
		"garage", "dealer", "workshop", "tune", "paint", "shop": garage.build(name, arg)
		"about", "privacy", "terms", "credits": about.build(name, arg)
		"consent": about.consent_screen()
		"account": account.build(arg)
		"perf":
			if not Release.store():
				perf.build(name, arg)
		"iap": store.build()
		"soon": world_ui.soon_screen(str(arg))
		"online": world_ui.online_home()
		"spawn": world_ui.spawn_screen()
		"nick": world_ui.nick_screen()
		"adventure", "adv_skills", "adv_help", "adv_stages", "adv_start": adventure.build(name, arg)
		_: _home()

## Antes de largar una carrera se elige el nivel de simulación (arcade / intermedio / simulador total / personalizado)
## Mundo abierto: Dream City, a recorrer libre con el auto elegido (antes se elige el nivel de simulación)
func launch(cfg: Dictionary, ask := true) -> void:
	if ask:
		go("level", cfg)
	else:
		cfg["sim"] = str(profile.setting("simLevel"))
		app.start_race(cfg)

const SIM_LEVELS := [["arcade", "ARCADE", "ABS, tracción y estabilidad altas y ayuda de trazada fuerte: el auto perdona casi todo."],
	["mid", "INTERMEDIO", "Ayudas medias y ayuda de trazada suave: un manejo equilibrado."],
	["pro", "SIMULADOR TOTAL", "Sin ayudas: sin ABS, sin control de tracción, sin estabilidad ni ayuda de trazada. Manejás vos."],
	["custom", "PERSONALIZADO", "Elegís cada ayuda a gusto."]]

func _level_screen(cfg) -> void:
	title_l.text = "NIVEL DE SIMULACIÓN"
	var cur := str(profile.setting("simLevel"))
	var play := Kit.button("▶ JUGAR", func() -> void:
		sfx.play("click")
		var c: Dictionary = cfg
		c["sim"] = str(profile.setting("simLevel"))
		app.start_race(c), true, 26, Vector2(0, 58))
	body.add_child(play)
	var g := Kit.grid(2, 8, 8)
	body.add_child(g)
	for lv in SIM_LEVELS:
		var id: String = lv[0]
		var b := Kit.button("", Callable(), cur == id, 20, Vector2(0, 112))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Kit.vbox(2)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 12
		v.offset_right = -12
		v.offset_top = 8
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dark := Color(0.05, 0.06, 0.08)
		v.add_child(Kit.label(tr(str(lv[1])) + ("  ✔" if cur == id else ""), 19, dark if cur == id else Kit.TEXT))
		var dl := Kit.label(tr(str(lv[2])), 12, dark if cur == id else Kit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 150
		dl.max_lines_visible = 5
		v.add_child(dl)
		b.add_child(v)
		b.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			profile.set_setting("simLevel", id)
			sfx.play("click")
			go("level", cfg, false))
		g.add_child(b)
	if cur == "custom":
		opts.options_page(body, "fisica")
		title_l.text = "NIVEL DE SIMULACIÓN"

func back() -> void:
	sfx.play("click")
	if stack.is_empty():
		if not app.city_return.is_empty():
			return_to_city() # se entró desde Dream City: se sale del local y se vuelve a la calle
			return
		go("home", null, false)
		return
	var prev: Array = stack.pop_back()
	go(prev[0], prev[1], false)

## Sale del taller o del concesionario de Dream City y vuelve a la calle, con el auto como quedó
func return_to_city() -> void:
	var c: Dictionary = app.city_return.duplicate(true)
	app.city_return = {}
	garage.shop = ""
	var pid: String = profile.current_id()
	c["car"] = pid
	c["state"] = profile.car()
	c["sim"] = str(profile.setting("simLevel"))
	app.start_race(c)

## El servidor rechazó una acción del taller online: se avisa y se vuelve a mostrar lo que el servidor dice
func on_online_failed(text: String) -> void:
	sfx.play("error")
	toast(tr(text))
	refresh_car()
	go(screen, screen_arg, false)

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
## Mosaico del inicio: ícono, nombre y una línea chica
func tile(icon: String, text: String, sub: String, cb: Callable, accent := false, h := 70.0) -> Button:
	var b := Kit.button("", Callable(), accent, 20, Vector2(0, h))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Kit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var col := Color(0.05, 0.06, 0.08) if accent else Kit.TEXT
	v.add_child(Kit.label(icon, 22, col, HORIZONTAL_ALIGNMENT_CENTER))
	var tl := Kit.label(text, 16, col, HORIZONTAL_ALIGNMENT_CENTER)
	tl.clip_text = true
	tl.custom_minimum_size.x = 40
	v.add_child(tl)
	if sub != "":
		var sl := Kit.label(sub, 11, col.darkened(0.15) if accent else Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		sl.clip_text = true
		sl.custom_minimum_size.x = 40
		v.add_child(sl)
	b.add_child(v)
	b.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		sfx.play("click")
		cb.call())
	return b

func _home() -> void:
	title_l.text = ""
	var t := Kit.label("DREAM RACING", 38, Kit.ACCENT)
	body.add_child(t)
	var car_id: String = profile.current_id()
	var cm: Dictionary = CarBuild.catalog()["cars"][car_id]
	var st: Dictionary = profile.car()
	var V: Dictionary = CarBuild.build_params(vehicles[car_id], st)
	var pf: Dictionary = CarBuild.perf_of(V)
	var cls: Dictionary = CarBuild.class_of(int(pf["pi"]))
	var chip := Kit.label("%s %s · %s %s · PI %d" % [cm["brand"], cm["model"], tr("Clase"), cls["c"], int(pf["pi"])], 14, Kit.MUTED)
	chip.clip_text = true
	chip.custom_minimum_size.x = 40
	body.add_child(chip)
	var next_ev := _next_event()
	if not next_ev.is_empty():
		body.add_child(menu_button("▶ SEGUIR CARRERA", str(next_ev["name"]), func(): go("event", next_ev["id"]), true))
	var ast := AdvData.state(profile)
	var adv_sub := "¡nuevo! · %d etapas" % AdvRoute.STAGES.size()
	if ast["done"] == true:
		adv_sub = "🏆 completada"
	elif ast["started"] == true:
		adv_sub = "etapa %d/%d" % [mini(int(ast["stage"]) + 1, AdvRoute.STAGES.size()), AdvRoute.STAGES.size()]
	body.add_child(menu_button("🌄 AVENTURA", "La Ruta de los Sueños · " + adv_sub, func(): go("adventure"), next_ev.is_empty()))
	# lo que viene: cerrado, con carteles de qué va a traer
	var soon := Kit.grid(3, 8, 8)
	body.add_child(soon)
	soon.add_child(tile("🌌", "FANTASÍA", "mapas de ensueño", func(): go("fantasy"), false, 70.0))
	soon.add_child(tile("🌐", "MODO ONLINE", "mundo abierto", func(): go("online"), false, 70.0))
	soon.add_child(tile("🗺", "MUNDO ABIERTO", "Dream City", func() -> void:
		world_online = false
		go("spawn"), false, 70.0))
	var g := Kit.grid(3, 8, 8)
	body.add_child(g)
	var tiles := [
		["🏆", "CARRERA", "%d ⭐" % profile.stars(), func(): go("career"), false],
		["⚡", "RÁPIDA", "pista y rivales", func():
			career.quick["fantasy"] = false
			go("quick"), false],
		["🚗", "GARAJE", "tus autos", func(): go("garage"), false],
		["🏬", "TIENDA", "comprá autos", func(): go("dealer"), false],
		["🔧", "TALLER", "piezas · pintura", func(): go("workshop", 0), false],
		["⭐", "LOGROS", ("%d para cobrar" % Rewards.ach_ready(profile)) if Rewards.ach_ready(profile) > 0 else "objetivos", func(): go("goals"), false],
		["⚙", "OPCIONES", "manejo · sonido", func(): go("options"), false],
		["ℹ", "ACERCA DE", "créditos · legales", func(): go("about"), false],
		["💎", "COMPRAS", "juego completo · créditos", func(): go("iap"), false],
	]
	if not Release.store():
		tiles.append(["📊", "RENDIMIENTO", "probá tu teléfono", func(): go("perf"), false]) # no va en la versión de Google Play
	for tl in tiles:
		g.add_child(tile(str(tl[0]), str(tl[1]), str(tl[2]), tl[3], bool(tl[4])))

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
var goals_page := 0
const GOALS_PER_PAGE := 6

func _goals() -> void:
	title_l.text = "LOGROS"
	var claimed: Dictionary = profile.d["claimed"]
	var all: Array = CarBuild.catalog()["achievements"]
	var pages := maxi(1, int(ceil(float(all.size()) / float(GOALS_PER_PAGE))))
	goals_page = clampi(goals_page, 0, pages - 1)
	var g := Kit.grid(2, 8, 8)
	body.add_child(g)
	for i in range(goals_page * GOALS_PER_PAGE, mini(all.size(), (goals_page + 1) * GOALS_PER_PAGE)):
		var a: Dictionary = all[i]
		var id := str(a["id"])
		var got := claimed.has(id)
		var ok := Rewards.ach_done(profile, id)
		var p := Kit.panel(8, Kit.PANEL2 if not got else Color(0.1, 0.2, 0.14, 0.95))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(p)
		var v := Kit.vbox(2)
		p.add_child(v)
		var head := Kit.hbox(6)
		v.add_child(head)
		head.add_child(Kit.label(str(a["icon"]), 26))
		var nl := Kit.label(str(a["n"]), 16, Kit.GOLD if ok and not got else (Kit.GREEN if got else Kit.TEXT))
		nl.clip_text = true
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.custom_minimum_size.x = 40
		head.add_child(nl)
		var dl := Kit.label(str(a["d"]), 12, Kit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 150
		dl.max_lines_visible = 2
		v.add_child(dl)
		if got:
			v.add_child(Kit.label("COBRADO ✔", 14, Kit.GREEN))
		elif ok:
			v.add_child(Kit.button("COBRAR " + Kit.fmt_cr(float(a["cr"])), func(): _claim(a), true, 14, Vector2(0, 32)))
		else:
			v.add_child(Kit.label(Kit.fmt_cr(float(a["cr"])), 14, Kit.MUTED))
	if pages > 1:
		body.add_child(Kit.pager(goals_page, pages, func(pg: int) -> void:
			goals_page = pg
			go("goals", null, false)))

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
	var top := Kit.hbox(10)
	body.add_child(top)
	var l0 := Kit.vbox(0)
	l0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l0)
	var en := Kit.label(str(r.get("event_name", "")), 18, Kit.MUTED)
	en.clip_text = true
	en.custom_minimum_size.x = 40
	l0.add_child(en)
	var t := str(r.get("type", "race"))
	var big := ""
	var sub := "" # línea de abajo (duelo de drift, cambios de la picada)
	match t:
		"race": big = "%d° %s" % [int(r["pos"]), tr("puesto")]
		"trap": big = "%d km/h" % int(r["value"])
		"drift":
			big = "%d pts" % int(r["value"])
			if r.get("duel", false) == true:
				sub = (tr("🏆 ¡Le ganaste al bot! (%d pts)") if r.get("win", false) == true else tr("😅 Ganó el bot (%d pts)")) % int(r["bot"])
		_: big = Kit.fmt_time(float(r["time"]))
	if r.get("drag", false) == true and int(r.get("shifts", 0)) > 0:
		sub = tr("⚡ Cambios perfectos: %d de %d") % [int(r["perfect"]), int(r["shifts"])]
	l0.add_child(Kit.label(big, 44, Kit.GOLD))
	if sub != "":
		l0.add_child(Kit.label(sub, 18, Kit.GREEN))
	if bool(r.get("show_medal", false)):
		var med := int(r["medal"])
		var names := ["Sin medalla", "🥉 Bronce", "🥈 Plata", "🥇 ORO"]
		top.add_child(Kit.label(tr(names[med]), 28, [Kit.MUTED, Color(0.85, 0.55, 0.3), Color(0.8, 0.85, 0.92), Kit.GOLD][med]))
	if bool(r.get("record", false)):
		body.add_child(Kit.label("🏅 ¡NUEVO RÉCORD!", 20, Kit.GREEN))
	var row := Kit.hbox(8)
	body.add_child(row)
	var again := Kit.button("↺ REPETIR", func(): app.start_race(cfg), true, 20, Vector2(0, 50))
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	var to := "career" if not cfg.get("event", {}).is_empty() else "home"
	var cont := Kit.button("CONTINUAR", func(): stack.clear(); go(to, null, false), false, 20, Vector2(0, 50))
	cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cont)
	var grid := Kit.grid(4, 12, 2)
	body.add_child(grid)
	var kv := [["Recompensa", Kit.fmt_cr(float(r["cr"]))], ["Experiencia", "+%d XP" % int(r["xp"])], ["Velocidad máxima", "%d km/h" % int(r["max_kmh"])], ["Distancia", "%.2f km" % (float(r["odo"]) / 1000.0)]]
	for p in kv:
		var kl := Kit.label(tr(str(p[0])), 13, Kit.MUTED)
		kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(kl)
		var vl := Kit.label(str(p[1]), 14, Kit.TEXT)
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(vl)
	if str(r.get("cup_msg", "")) != "":
		body.add_child(Kit.wrap(str(r["cup_msg"]), 15, Kit.GOLD, 300))
	for u in r.get("level_ups", []):
		body.add_child(Kit.label("⬆ ¡NIVEL %d! +%s" % [int(u["level"]), Kit.fmt_cr(float(u["bonus"]))], 18, Kit.GREEN))
	if t == "race" and not (r["standings"] as Array).is_empty():
		var sg := Kit.grid(2, 14, 2)
		body.add_child(sg)
		var i := 0
		for s in r["standings"]:
			i += 1
			var line := "%d. %s  %s" % [i, s["name"], Kit.fmt_time(float(s["time"])) if float(s["time"]) >= 0.0 else "—"]
			var sl := Kit.label(line, 14, Kit.ACCENT if s["player"] else Kit.TEXT)
			sl.clip_text = true
			sl.custom_minimum_size.x = 40
			sg.add_child(sl)
	sfx.play("finish")
