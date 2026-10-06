extends CanvasLayer
## Menú de DIAGNÓSTICO / RENDIMIENTO (se abre con el botón 📊 mientras se conduce). Sólo REGISTRA: el jugador conduce, cambia las condiciones y pulsa CAPTURAR.
## Mide los FPS en tramos de 0,5 s (promedio y mínimo desde el último cambio o captura; los 2 s siguientes a un cambio no cuentan: el mundo se está rearmando),
## muestra la escena/ubicación/superficie/clima/hora, tiene los interruptores del mundo abierto (árboles, edificios, autos civiles, vegetación, decoración, peatones),
## el cambio manual de hora y clima, el respawn y el registro (VER REGISTRO / COPIAR TODO). El texto lo arma diag_log.gd. No hay pruebas ni recorridos automáticos.

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const DiagLog := preload("res://game/data/diag_log.gd")
const DiagSpots := preload("res://game/city/diag_spots.gd")
const CityTrack := preload("res://game/track/city_track.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")

const ZONES := ["Centro", "Barrio", "Campo", "Costa", "Colina", "Campo lejano"]
const SURFACES := ["asfalto", "tierra", "banquina", "pasto", "fuera de calzada", "barro", "nieve"]
const SETTLE := 2.5 # s sin medir después de un cambio (o de entrar a la escena)
const WEATHER_NAMES := {"dia": "Sol", "nublado": "Nublado", "lluvia": "Lluvia", "atardecer": "Atardecer", "ocaso": "Ocaso", "nieve": "Nieve"}

var race # race.gd
var is_city := false
var sw := {} # clave → bool (interruptores del mundo abierto)
var cond := {}
var where_label := "" # lo que se eligió en RESPAWN
var where_pos := Vector2.ZERO
var last_zone := ""

# medición
var fps_now := 0.0
var win_sum := 0.0
var win_n := 0
var win_min := 1e9
var win_ms := 0
var settle := SETTLE
var _frames := 0
var _t_mark := 0
var _was_paused := false
var _after_change := false
var _hist_sum := 0.0
var _hist_n := 0
var _hist_t := 0.0
var _ui_t := 0.0
var _start_fixed := false

# interfaz
var _root: Control
var _btn: Button
var _panel: PanelContainer
var _lbl_fps: Label
var _lbl_win: Label
var _lbl_info: Label
var _lbl_last: Label
var _main_box: VBoxContainer
var _log_box: VBoxContainer
var _log_lbl: Label
var _toggles := {}
var _scale_btns := {} # texto de la escala → botón
var _paper_btns := {} # «ORIGINAL» / «SIMPLE» → botón
var _spots_box: VBoxContainer
var _open := false

func setup(p_race) -> void:
	race = p_race
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_city = race.track is CityTrack
	PaperKit.set_simple(false) # el experimento PAPER SHADER arranca siempre en ORIGINAL
	for s in DiagLog.SWITCHES:
		sw[s[0]] = true
	cond = _cond()
	DiagLog.begin_session(_scene_name(), _circuit_name(), cond)
	last_zone = str(cond.get("zone", ""))
	_t_mark = Time.get_ticks_msec()
	_build()

func _scene_name() -> String:
	if is_city:
		return "MUNDO ABIERTO"
	match str(race.cfg.get("type", "")):
		"adventure":
			return "AVENTURA"
		"drift":
			return "DRIFT"
		"travesia":
			return "TRAVESÍA X"
	return "CARRERA"

func _circuit_name() -> String:
	if is_city:
		return ""
	var tm: Dictionary = race.get("track_maps") if race.get("track_maps") != null else {}
	var tid := str(race.get("track_id"))
	return str((tm.get(tid, {}) as Dictionary).get("name", tid))

# ───────────────────────── condiciones ─────────────────────────
func _cond() -> Dictionary:
	var c := {}
	for s in DiagLog.SWITCHES:
		if is_city:
			c[s[0]] = bool(sw[s[0]])
	if is_city:
		c["paper"] = "SIMPLE" if PaperKit.simple else "ORIGINAL"
	c["res"] = _res_text()
	c["res_px"] = _res_px_text()
	var px := 0.0
	var pz := 0.0
	if not race.cars.is_empty():
		px = float(race.cars[0].phys.px)
		pz = float(race.cars[0].phys.pz)
	var ground: Vector2 = race.track.ground_info(px, pz)
	c["surface"] = SURFACES[clampi(int(ground.y), 0, SURFACES.size() - 1)]
	if is_city:
		var city = race.track.city
		if px > 3000.0:
			c["zone"] = "Subsuelo (túnel / estacionamiento)"
		else:
			c["zone"] = ZONES[clampi(city.zone_of(px, pz), 0, ZONES.size() - 1)]
		c["where"] = _where_text(px, pz, str(c["zone"]))
		var clock = race.clock
		if clock != null:
			var wx: Dictionary = clock.wx if clock.weather_on else {"cloud": 0.0, "rain": 0.0, "fog": 0.0}
			c["weather"] = "Lluvia" if float(wx["rain"]) > 0.35 else ("Niebla" if float(wx["fog"]) > 0.5 else ("Nublado" if float(wx["cloud"]) > 0.5 else "Sol"))
			c["time"] = clock.band()
		else:
			c["weather"] = "?"
			c["time"] = "?"
	else:
		c["zone"] = "Pista"
		c["where"] = _circuit_name()
		c["weather"] = str(WEATHER_NAMES.get(race.weather.current if race.weather != null else "dia", "?"))
		c["time"] = "(según el clima elegido)"
	return c

## ESCALA 3D (sólo se lee). «res» es lo que se compara entre pruebas («0.80», «AUTO»); «res_px» sólo se muestra
func _res_text() -> String:
	return "AUTO" if bool(race.res_auto) else "%.2f" % float(race.res_scale)

func _res_px_text() -> String:
	var wsz: Vector2i = race.world.size
	if bool(race.res_auto):
		return "ahora %.2f · mundo 3D %dx%d" % [float(race.res_scale), wsz.x, wsz.y]
	return "mundo 3D %dx%d" % [wsz.x, wsz.y]

func _where_text(px: float, pz: float, zone: String) -> String:
	if where_label != "" and Vector2(px, pz).distance_to(where_pos) < 220.0:
		return where_label
	var loc: Dictionary = race.track.city.locate(px, pz)
	var nm := str(loc.get("name", ""))
	if nm == "":
		return zone
	return "%s, cuadra %d (%s)" % [nm, int(loc.get("cuadra", 0)), zone]

# ───────────────────────── interfaz ─────────────────────────
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_btn = Kit.button("📊", func() -> void: _set_open(not _open), false, 20, Vector2(86, 54))
	_btn.modulate = Color(1, 1, 1, 0.82)
	_btn.anchor_top = 0.5
	_btn.anchor_bottom = 0.5
	_btn.offset_left = 8
	_btn.offset_right = 94
	_btn.offset_top = -27
	_btn.offset_bottom = 27
	_root.add_child(_btn)
	_panel = Kit.panel(8, Color(0.06, 0.08, 0.11, 0.86))
	_panel.visible = false
	_panel.anchor_left = 0.5
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.92
	_panel.offset_left = 0
	_panel.offset_right = -8
	_panel.offset_top = 8
	_panel.offset_bottom = 0
	_root.add_child(_panel)
	var outer := Kit.vbox(5)
	_panel.add_child(outer)
	_main_box = outer
	var head := Kit.hbox(6)
	outer.add_child(head)
	var title := Kit.label("📊 DIAGNÓSTICO", 18, Kit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(Kit.button("✕", func() -> void: _set_open(false), false, 18, Vector2(54, 38)))
	_lbl_fps = Kit.label("FPS –", 24, Kit.TEXT)
	outer.add_child(_lbl_fps)
	_lbl_win = Kit.label("", 12, Kit.MUTED)
	outer.add_child(_lbl_win)
	var cap := Kit.button("📸 CAPTURAR", func() -> void: _capture(), true, 20, Vector2(0, 48))
	outer.add_child(cap)
	_lbl_last = Kit.wrap("", 13, Kit.GREEN, 100)
	outer.add_child(_lbl_last)
	var sc: ScrollContainer = TouchScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(sc)
	var body := Kit.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	_lbl_info = Kit.wrap("", 13, Kit.TEXT, 100)
	body.add_child(_lbl_info)
	body.add_child(Kit.label("ESCALA DE RENDERIZADO 3D", 13, Kit.MUTED))
	var rs := Kit.hbox(6)
	body.add_child(rs)
	for v in [0.8, 0.7, 0.6, 0.5, 0.4, 0.35]:
		var sv: float = v
		var sb0 := _pick("%.2f" % sv, func() -> void: _set_scale(sv))
		rs.add_child(sb0)
		_scale_btns["%.2f" % sv] = sb0
	var sba := _pick("AUTO", func() -> void: _set_scale(0.0))
	rs.add_child(sba)
	_scale_btns["AUTO"] = sba
	body.add_child(Kit.wrap("Sólo cambia a qué resolución se dibuja el mundo 3D (pantalla × escala). El HUD, la ventana y todo lo demás no cambian. AUTO es lo que hace el juego solo.", 12, Kit.MUTED, 100))
	if is_city:
		body.add_child(Kit.label("PAPER SHADER (sólo mundo abierto)", 13, Kit.MUTED))
		var pr := Kit.hbox(6)
		body.add_child(pr)
		for pn in ["ORIGINAL", "SIMPLE"]:
			var pname: String = pn
			var pb := _pick(pname, func() -> void: _set_paper(pname == "SIMPLE"))
			pr.add_child(pb)
			_paper_btns[pname] = pb
		body.add_child(Kit.wrap("Experimento: SIMPLE reemplaza paper.gdshader (terreno, calles, marcas y objetos de calle) por una variante sin normal por derivadas, sin líneas de borde ni variación de tono. Fachadas, árboles, horizonte, señales y peatones no cambian. Tocá una vez ORIGINAL ⇄ SIMPLE antes de medir (la primera vez compila el shader).", 12, Kit.MUTED, 100))
	if is_city:
		body.add_child(Kit.wrap("Tip: el reloj y el clima del mundo andan solos. Antes de comparar, fijá la hora y el clima con los botones de abajo (si no, la luz y la lluvia cambian en medio de la prueba).", 12, Kit.MUTED, 100))
	if is_city:
		body.add_child(Kit.label("INTERRUPTORES", 13, Kit.MUTED))
		var g := Kit.grid(3, 6, 6)
		body.add_child(g)
		var icons := {"trees": "🌳", "buildings": "🏢", "cars": "🚗", "veg": "🌿", "decor": "💡", "peds": "🚶", "asphalt": "🛣️", "dirt": "🛤️", "terrain": "🌱", "fog": "🌫️", "horizon": "⛰️"}
		for s in DiagLog.SWITCHES:
			var key: String = s[0]
			var b := Kit.button("", func() -> void: _toggle(key), false, 13, Vector2(0, 46))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.set_meta("name", "%s %s" % [icons.get(key, ""), s[1]])
			g.add_child(b)
			_toggles[key] = b
			_style_toggle(key)
		body.add_child(Kit.wrap("☁️ CIELO: siempre ON (no tiene interruptor en esta ronda). Asfalto = sólo la calzada; veredas, cordones y marcas siguen. Caminos de tierra = banquina beige de las rutas rurales.", 12, Kit.MUTED, 100))
		body.add_child(Kit.label("HORA Y CLIMA", 13, Kit.MUTED))
		var r1 := Kit.hbox(6)
		body.add_child(r1)
		r1.add_child(_pick("☀️ DÍA", func() -> void: _set_time(12.5, "Día")))
		r1.add_child(_pick("🌅 ATARDECER", func() -> void: _set_time(19.0, "Atardecer")))
		r1.add_child(_pick("🌙 NOCHE", func() -> void: _set_time(23.0, "Noche")))
		var r2 := Kit.hbox(6)
		body.add_child(r2)
		r2.add_child(_pick("☀ SOL", func() -> void: _set_weather("clear", "Sol")))
		r2.add_child(_pick("🌧️ LLUVIA", func() -> void: _set_weather("rain", "Lluvia")))
		r2.add_child(_pick("↺ AUTO", func() -> void: _auto_clock()))
		var rb := Kit.button("📍 RESPAWN / CAMBIAR UBICACIÓN", func() -> void: _spots_box.visible = not _spots_box.visible, false, 15, Vector2(0, 46))
		body.add_child(rb)
		_spots_box = Kit.vbox(4)
		_spots_box.visible = false
		body.add_child(_spots_box)
		for sp in DiagSpots.spots(race.track.city):
			var spd: Dictionary = sp
			var sb := Kit.card_button(str(spd["label"]), str(spd["sub"]), "", func() -> void: _respawn(spd), false, true, 50.0, 15)
			_spots_box.add_child(sb)
	else:
		body.add_child(Kit.label("CLIMA", 13, Kit.MUTED))
		var rw := Kit.hbox(6)
		body.add_child(rw)
		for w in [["☀ SOL", "dia"], ["☁ NUBLADO", "nublado"], ["🌧️ LLUVIA", "lluvia"]]:
			var wn: String = w[1]
			rw.add_child(_pick(str(w[0]), func() -> void: _set_race_weather(wn)))
		var rw2 := Kit.hbox(6)
		body.add_child(rw2)
		for w2 in [["🌅 ATARDECER", "atardecer"], ["🌙 OCASO", "ocaso"]]:
			var wn2: String = w2[1]
			rw2.add_child(_pick(str(w2[0]), func() -> void: _set_race_weather(wn2)))
		body.add_child(Kit.wrap("Los interruptores del mundo (árboles, edificios, autos…) sólo existen en el MUNDO ABIERTO.", 12, Kit.MUTED, 100))
	body.add_child(Kit.label("REGISTRO", 13, Kit.MUTED))
	var rr := Kit.hbox(6)
	body.add_child(rr)
	var vb := Kit.button("📄 VER REGISTRO", func() -> void: _show_log(true), false, 15, Vector2(0, 46))
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.add_child(vb)
	var cb := Kit.button("📋 COPIAR TODO", func() -> void: copy_all(), false, 15, Vector2(0, 46))
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.add_child(cb)
	# vista del registro
	_log_box = Kit.vbox(5)
	_log_box.visible = false
	_panel.add_child(_log_box)
	var lh := Kit.hbox(6)
	_log_box.add_child(lh)
	var back := Kit.button("← VOLVER", func() -> void: _show_log(false), false, 16, Vector2(0, 44))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(back)
	var lc := Kit.button("📋 COPIAR TODO", func() -> void: copy_all(), true, 16, Vector2(0, 44))
	lc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(lc)
	var lsc: ScrollContainer = TouchScroll.new()
	lsc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_box.add_child(lsc)
	_log_lbl = Kit.wrap("", 12, Kit.TEXT, 100)
	lsc.add_child(_log_lbl)
	_refresh_labels()

func _pick(text: String, cb: Callable) -> Button:
	var b := Kit.button(text, cb, false, 14, Vector2(0, 44))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	return b

func _style_toggle(key: String) -> void:
	var b: Button = _toggles[key]
	var on := bool(sw[key])
	b.text = "%s: %s" % [b.get_meta("name"), "ON" if on else "OFF"]
	var base := Color(0.10, 0.34, 0.20, 0.96) if on else Color(0.42, 0.11, 0.14, 0.96)
	b.add_theme_stylebox_override("normal", Kit.box(base, 12, Kit.LINE, 1, 10))
	b.add_theme_stylebox_override("hover", Kit.box(base.lightened(0.08), 12, Kit.LINE, 1, 10))
	b.add_theme_stylebox_override("pressed", Kit.box(base.darkened(0.12), 12, Kit.ACCENT, 2, 10))

func _set_open(on: bool) -> void:
	_open = on
	_panel.visible = on
	if on:
		_show_log(false)
		_refresh_labels()

func _show_log(on: bool) -> void:
	_main_box.visible = not on
	_log_box.visible = on
	if on:
		_log_lbl.text = DiagLog.export_text()

func copy_all() -> void:
	var txt := DiagLog.export_text()
	DisplayServer.clipboard_set(txt)
	var f := FileAccess.open("user://informe_diagnostico.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()
	_note("📋 Registro copiado (%d líneas). Pegalo en el chat." % txt.count("\n"))

func _note(t: String) -> void:
	if race.race_hud != null:
		race.race_hud.toast(t)
	_lbl_last.text = t

# ───────────────────────── cambios manuales ─────────────────────────
## Anota un cambio del jugador y arranca de nuevo la medición (los FPS de antes ya no cuentan para la condición nueva)
func _changed(label: String) -> void:
	cond = _cond()
	DiagLog.change(label, cond, int(round(fps_now)))
	_reset_window()
	settle = SETTLE
	_after_change = true
	_refresh_labels()

func _reset_window() -> void:
	win_sum = 0.0
	win_n = 0
	win_min = 1e9
	win_ms = 0

func _toggle(key: String) -> void:
	var on := not bool(sw[key])
	sw[key] = on
	_style_toggle(key)
	_apply_switch(key, on)
	var nm := ""
	for s in DiagLog.SWITCHES:
		if s[0] == key:
			nm = s[1]
	_changed("%s → %s" % [nm, DiagLog.onoff(on)])

## Cambia SÓLO la resolución interna del mundo 3D (el mismo mecanismo de siempre: race.res_scale → world.size). Fija una escala = apaga el ajuste automático mientras dure la prueba
func _set_scale(v: float) -> void:
	var before := _scale_label()
	if v <= 0.0:
		race.res_auto = true
	else:
		race.res_auto = false
		race.res_scale = v
		race._on_resize()
	var after := _scale_label()
	if after == before:
		return
	_changed("ESCALA 3D: %s → %s" % [before, after])

## PAPER SHADER: sólo cambia el shader de los materiales de papel (ver PaperKit.set_simple); nada más
func _set_paper(simple: bool) -> void:
	if PaperKit.simple == simple:
		return
	var before := "SIMPLE" if PaperKit.simple else "ORIGINAL"
	PaperKit.set_simple(simple)
	_changed("PAPER SHADER: %s → %s" % [before, "SIMPLE" if simple else "ORIGINAL"])

func _style_paper() -> void:
	var cur := "SIMPLE" if PaperKit.simple else "ORIGINAL"
	for k in _paper_btns:
		var b: Button = _paper_btns[k]
		var on: bool = str(k) == cur
		var base := Color(0.10, 0.34, 0.20, 0.96) if on else Color(0.16, 0.19, 0.24, 0.96)
		b.add_theme_stylebox_override("normal", Kit.box(base, 12, Kit.LINE, 1, 10))
		b.add_theme_stylebox_override("hover", Kit.box(base.lightened(0.08), 12, Kit.LINE, 1, 10))
		b.add_theme_stylebox_override("pressed", Kit.box(base.darkened(0.12), 12, Kit.ACCENT, 2, 10))

func _exit_tree() -> void:
	if PaperKit.simple:
		PaperKit.set_simple(false) # al salir del mundo abierto todo vuelve a paper.gdshader

func _scale_label() -> String:
	if bool(race.res_auto):
		return "AUTO (ahora %.2f)" % float(race.res_scale)
	return "%.2f" % float(race.res_scale)

func _style_scale() -> void:
	var cur := _res_text()
	for k in _scale_btns:
		var b: Button = _scale_btns[k]
		var on: bool = str(k) == cur
		var base := Color(0.10, 0.34, 0.20, 0.96) if on else Color(0.16, 0.19, 0.24, 0.96)
		b.add_theme_stylebox_override("normal", Kit.box(base, 12, Kit.LINE, 1, 10))
		b.add_theme_stylebox_override("hover", Kit.box(base.lightened(0.08), 12, Kit.LINE, 1, 10))
		b.add_theme_stylebox_override("pressed", Kit.box(base.darkened(0.12), 12, Kit.ACCENT, 2, 10))

func _apply_switch(key: String, on: bool) -> void:
	match key:
		"trees", "buildings", "veg", "decor", "asphalt", "dirt", "terrain", "horizon":
			race.track.world_node.diag_set(key, on)
		"fog":
			race.env.fog_enabled = on # sólo se prende o apaga: la distancia y el color de la niebla no se tocan
		"cars":
			if race.world_life != null:
				race.world_life.set_muted("traffic", not on)
				race.world_life.set_muted("parked", not on)
		"peds":
			if race.world_life != null:
				race.world_life.set_muted("peds", not on)

func _set_time(h: float, nm: String) -> void:
	if race.clock == null:
		return
	race.clock.set_manual_hour(h)
	_changed("Hora → %s" % nm)

func _set_weather(kind: String, nm: String) -> void:
	if race.clock == null:
		return
	race.clock.set_manual_weather(kind)
	_changed("Clima → %s" % nm)

func _auto_clock() -> void:
	if race.clock == null:
		return
	race.clock.release_manual()
	_changed("Hora y clima → automáticos (los del mundo)")

func _set_race_weather(name: String) -> void:
	race.weather.apply(name)
	race.weather_name = name
	_changed("Clima → %s" % str(WEATHER_NAMES.get(name, name)))

func _respawn(sp: Dictionary) -> void:
	var cw = race.track.world_node
	cw.warm(Vector3(float(sp["x"]), 0.0, float(sp["z"]))) # las cuadras de ahí, armadas antes de aparecer
	race.cars[0].place(float(sp["x"]), float(sp["z"]), float(sp["yaw"]))
	race.on_teleport()
	var lbl := str(sp["label"])
	where_label = lbl.substr(0, 1) + lbl.substr(1).to_lower()
	where_pos = Vector2(float(sp["x"]), float(sp["z"]))
	last_zone = ""
	_changed("Ubicación → %s" % where_label)
	settle = SETTLE + 1.5 # además se están armando las cuadras nuevas

func _capture() -> void:
	if win_n < 1:
		_note("Esperá un momento: se está midiendo (%.0f s)." % maxf(settle, 0.5))
		return
	cond = _cond()
	var avg := win_sum / float(win_n)
	var t := DiagLog.add_test(cond, avg, win_min, win_n, float(win_ms) / 1000.0)
	var txt := "PRUEBA %d · prom %d · mín %d" % [int(t["n"]), int(round(avg)), int(round(win_min))]
	if t.has("d_avg"):
		txt += " · %s prom, %s mín vs. la anterior" % [DiagLog._sgn(float(t["d_avg"])), DiagLog._sgn(float(t["d_min"]))]
		var dk: Array = t["diff"]
		if dk.is_empty():
			txt += " (mismas condiciones)"
		else:
			var names: Array = []
			for k in dk:
				names.append(str(DiagLog.KEY_NAMES.get(k, k)))
			txt += " (cambió: %s)" % ", ".join(names)
	_note("📸 " + txt)
	_reset_window()

# ───────────────────────── cada cuadro ─────────────────────────
func _process(dt: float) -> void:
	if race == null or race.cars.is_empty():
		return
	var now := Time.get_ticks_msec()
	if bool(race.get("paused")):
		_was_paused = true
		_frames = 0
		_t_mark = now
		return
	if _was_paused:
		_was_paused = false
		settle = maxf(settle, 1.5)
	_frames += 1
	var el := now - _t_mark
	if el >= 500:
		var f := float(_frames) * 1000.0 / float(el)
		_frames = 0
		_t_mark = now
		fps_now = f
		_sample(f, el)
	_ui_t += dt
	if _ui_t >= 0.25:
		_ui_t = 0.0
		_refresh_labels()

func _sample(f: float, el_ms: int) -> void:
	if settle > 0.0:
		settle -= float(el_ms) / 1000.0
		return
	if not _start_fixed: # recién ahora el reloj y el clima del mundo están puestos: se corrige el INICIO
		_start_fixed = true
		cond = _cond()
		DiagLog.refresh_start(cond)
	win_sum += f
	win_n += 1
	win_min = minf(win_min, f)
	win_ms += el_ms
	if _after_change: # el renglón de FPS justo después de un cambio
		_after_change = false
		DiagLog.event("fps", "", int(round(f)))
		_hist_t = DiagLog.now_s()
	_hist_sum += f
	_hist_n += 1
	if DiagLog.now_s() - _hist_t >= 10.0 and _hist_n > 0: # un renglón de FPS cada ~10 s (promedio de ese tramo)
		DiagLog.event("fps", "", int(round(_hist_sum / float(_hist_n))))
		_hist_t = DiagLog.now_s()
		_hist_sum = 0.0
		_hist_n = 0
	# cambio de zona al conducir: queda anotado sin reiniciar la medición
	var c := _cond()
	if str(c["zone"]) != last_zone:
		if last_zone != "":
			DiagLog.event("zona", "%s → %s" % [last_zone, str(c["zone"])], int(round(f)))
		last_zone = str(c["zone"])

func _refresh_labels() -> void:
	if not _open and _btn != null:
		_btn.text = "📊 %d" % int(round(fps_now))
		return
	if _btn != null:
		_btn.text = "📊 %d" % int(round(fps_now))
	var c := _cond()
	var avg := (win_sum / float(win_n)) if win_n > 0 else 0.0
	_lbl_fps.text = "FPS %d   PROM %s   MÍN %s" % [int(round(fps_now)), str(int(round(avg))) if win_n > 0 else "–", str(int(round(win_min))) if win_n > 0 else "–"]
	_lbl_win.text = ("midiendo… (no cuenta hasta que se estabilice: %.1f s)" % maxf(settle, 0.0)) if settle > 0.0 else ("promedio de %d mediciones · %d s (desde el último cambio o captura)" % [win_n, int(round(float(win_ms) / 1000.0))])
	var l: Array = []
	l.append("ESCENA: %s%s" % [_scene_name(), (" · " + _circuit_name()) if not is_city and _circuit_name() != "" else ""])
	l.append("UBICACIÓN: %s" % str(c["where"]))
	l.append("ZONA: %s · SUPERFICIE: %s" % [str(c["zone"]), str(c["surface"])])
	l.append("ESCALA 3D: %s (%s)" % [str(c["res"]), str(c["res_px"])])
	l.append("CLIMA: %s · HORA: %s%s" % [str(c["weather"]), str(c["time"]), (" (%s)" % race.clock.clock_text()) if is_city and race.clock != null else ""])
	_lbl_info.text = "\n".join(l)
	_style_scale()
	_style_paper()
