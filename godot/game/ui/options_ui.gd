extends RefCounted
## Opciones del juego (calidad, texturas, física y ayudas, sonido, manejo, cámara, efectos). Las usan el menú principal y la
## pausa de la carrera: las mismas pantallas, y cada cambio avisa con la señal «changed» para aplicarlo en el momento.

const Kit := preload("res://game/ui/ui_kit.gd")
const Lens := preload("res://game/fx/lens.gd")

signal changed(key: String)

var profile: RefCounted
var sfx: Node
var nav: Callable # (pantalla: String, arg) → abre una pantalla de opciones (ver menu.go y RaceOptions)
var set_title: Callable # (texto: String)
var reset_cb: Callable # botón de borrar progreso (solo en el menú)
var fx_slot := 0
var fx_rows: Array = []
var fx_slot_btns: Array = []
var fx_toggle: Button
var fx_slider: HSlider
var fx_val: Label

func _title(t: String) -> void:
	if set_title.is_valid():
		set_title.call(t)

func _cat_button(text: String, sub: String, cb: Callable) -> Button:
	var b := Kit.button("", Callable(), false, 22, Vector2(0, 66))
	var v := Kit.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(Kit.label(text, 24, Kit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.label(sub, 15, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	b.add_child(v)
	b.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		sfx.play("click")
		cb.call())
	return b

## [categoría, ícono y nombre, ayuda]
const OPTION_CATS := [["graficos", "🖥", "Gráficos", "calidad, resolución, árboles, texturas"], ["fisica", "⚙", "Física y ayudas", "ABS, tracción, estabilidad"],
	["sonido", "🔊", "Sonido", "volúmenes y voz del copiloto"], ["manejo", "🎮", "Manejo", "caja, dirección, vibración"],
	["inclinacion", "📱", "Inclinación", "volante con el acelerómetro"], ["controles", "🕹", "Controles", "volante y pedal en pantalla"],
	["camara", "🎥", "Cámara", "cámara al empezar"], ["efectos", "✨", "Efectos", "Lente Rally y efectos 2.0"],
	["idioma", "🌐", "Idioma", "español, English, português, français, italiano, Deutsch"], ["captura", "📷", "Captura", "botón, calidad y grabaciones"]]
## [categoría, clave, título, valores, etiquetas]
const OPTION_LIST := [
	["graficos", "quality", "Calidad general", ["auto", "low", "mid", "high"], ["Automática", "Baja", "Media", "Alta"]],
	["graficos", "res", "Resolución del 3D", [0, 0.35, 0.5, 0.7, 1.0], ["Automática", "35%", "50%", "70%", "100%"]],
	["graficos", "showFps", "Mostrar FPS (cuadros por segundo)", [false, true], ["No", "Sí"]],
	["graficos", "worldLife", "Vida del mundo (tráfico y ambiente; apagala si el teléfono anda lento)", [true, false], ["Sí", "No"]],
	["graficos", "worldWeather", "Clima del mundo (nubes, niebla y lluvia según la hora; en Dream City)", [true, false], ["Sí", "No"]],
	["graficos", "trees", "Árboles", ["auto", 0, 1500, 3000, 6000], ["Según la calidad", "Ninguno", "Pocos", "Normales", "Muchos"]],
	["graficos", "shadowsQ", "Sombras", ["auto", false, true], ["Según la calidad", "No", "Sí"]],
	["graficos", "textures", "Calidad de texturas", ["auto", "low", "mid", "high"], ["Automática", "Baja", "Media", "Alta"]],
	["fisica", "abs", "ABS", [false, true], ["No", "Sí"]],
	["fisica", "tc", "Control de tracción", [0, 25, 50, 75, 100], ["Apagado", "25%", "50%", "75%", "100%"]],
	["fisica", "stab", "Estabilidad", [0, 30, 60, 100], ["Apagada", "Baja", "Media", "Alta"]],
	["fisica", "lineAssist", "Ayuda de trazada (el auto te ayuda a doblar)", [0, 25, 50, 75, 100], ["Sin ayuda", "Suave", "Media", "Fuerte", "Máxima"]],
	["sonido", "volume", "Volumen general", [0, 30, 60, 80, 100], ["Silencio", "Bajo", "Medio", "Alto", "Máximo"]],
	["sonido", "volEngine", "Motor", [0, 50, 75, 100, 130], ["Silencio", "Bajo", "Medio", "Normal", "Fuerte"]],
	["sonido", "volSurf", "Gomas y tierra", [0, 15, 30, 50, 80], ["Silencio", "Muy bajo", "Normal", "Fuerte", "Muy fuerte"]],
	["sonido", "volWind", "Viento", [0, 15, 30, 50, 80], ["Silencio", "Muy bajo", "Normal", "Fuerte", "Muy fuerte"]],
	["sonido", "volTurbo", "Turbo", [0, 50, 100, 140], ["Silencio", "Bajo", "Normal", "Fuerte"]],
	["sonido", "volGear", "Caja de cambios", [0, 50, 100, 140], ["Silencio", "Bajo", "Normal", "Fuerte"]],
	["sonido", "copilot", "Voz del copiloto (campeonato)", [false, true], ["No", "Sí"]],
	["manejo", "gearbox", "Caja de cambios", ["auto", "manual"], ["Automática", "Manual"]],
	["manejo", "steerMode", "Dirección", ["wheel", "slider"], ["Volante", "Barra"]],
	["manejo", "units", "Unidades", ["kmh", "mph"], ["km/h", "mph"]],
	["manejo", "haptics", "Vibración tipo volante (peso y baches)", [0, 1, 2, 3], ["Apagada", "Suave", "Media", "Fuerte"]],
	["inclinacion", "gyro", "Volante con inclinación", [false, true], ["No", "Sí"]],
	["inclinacion", "gyroSens", "Sensibilidad de la inclinación", [25, 40, 55, 70, 85, 100, 115, 130], ["Muy baja", "Baja", "Media baja", "Media", "Media alta", "Alta", "Muy alta", "Extrema"]],
	["inclinacion", "gyroDead", "Zona muerta (ir recto sin temblar)", [0, 1.5, 3, 5], ["Ninguna", "Chica", "Media", "Grande"]],
	["inclinacion", "gyroCurve", "Respuesta de la inclinación", [1.0, 1.35, 1.7], ["Lineal", "Progresiva", "Muy progresiva"]],
	["inclinacion", "gyroSmooth", "Suavizado de la inclinación", [30.0, 15.0, 8.0, 5.0], ["Directo", "Normal", "Suave", "Muy suave"]],
	["controles", "wheelSize", "Tamaño del volante", [70, 85, 100, 120, 140, 160], ["70%", "85%", "100%", "120%", "140%", "160%"]],
	["controles", "pedalSize", "Tamaño del pedal", [70, 85, 100, 120, 140, 160], ["70%", "85%", "100%", "120%", "140%", "160%"]],
	["camara", "camera", "Cámara al empezar", [0, 1, 2, 3, 4, 6, 7, 8], ["Casco", "Seguimiento", "Cerca", "Lejos", "Aérea", "Trasera (dos pilotos)", "Capó", "Paragolpes"]],
]

func options_page(body: VBoxContainer, cat = null) -> void:
	if cat == null:
		_title("OPCIONES")
		var g := Kit.grid(2, 8, 8)
		body.add_child(g)
		for c in OPTION_CATS:
			var key: String = c[0]
			g.add_child(Kit.card_button(str(c[2]), str(c[3]), "", func() -> void:
				sfx.play("click")
				nav.call("fx", null) if key == "efectos" else nav.call("options", key), false, true, 62.0, 18, str(c[1])))
		if reset_cb.is_valid():
			body.add_child(Kit.button("🗑 BORRAR TODO EL PROGRESO", reset_cb, false, 16, Vector2(0, 40)))
		return
	for c in OPTION_CATS:
		if c[0] == cat:
			_title(str(c[2]).to_upper())
	if cat == "idioma":
		_language_page(body)
		return
	if cat == "captura":
		_capture_page(body)
		return
	if cat == "galeria":
		_title("GALERÍA")
		preload("res://game/ui/capture_ui.gd").gallery(body, nav, sfx)
		return
	var g2 := Kit.grid(2, 8, 8)
	body.add_child(g2)
	for o in OPTION_LIST:
		if o[0] != cat:
			continue
		var key2: String = o[1]
		var vals: Array = o[3]
		var labels: Array = o[4]
		var cur = profile.setting(key2)
		if vals.find(cur) < 0:
			cur = vals[0]
		var sel := Kit.selector(tr(str(o[2])), vals, cur, func(v) -> String: return tr(str(labels[vals.find(v)])), func(v) -> void:
			profile.set_setting(key2, v)
			if key2 == "volume":
				sfx.volume = float(v) / 100.0
			changed.emit(key2), sfx, 62.0)
		g2.add_child(sel)
	if cat == "graficos":
		_particles_row(body)
		body.add_child(Kit.wrap("Al abrir el juego por primera vez se eligen solos según tu teléfono y se corrigen en el menú. Si cambiaste cosas y querés volver a eso:", 12, Kit.MUTED, 300))
		body.add_child(Kit.button("🔄 AJUSTE AUTOMÁTICO PARA MI TELÉFONO", func() -> void:
			for k in ["quality", "trees", "shadowsQ", "textures", "particles"]:
				profile.set_setting(k, "auto")
			profile.set_setting("res", 0)
			profile.set_setting("autotuned", false)
			sfx.play("click")
			changed.emit("retune"), false, 15, Vector2(0, 50)))
	if cat == "inclinacion":
		_accel_block(body)

## Idioma de los textos del juego (la voz del copiloto sigue el idioma del teléfono)
func _language_page(body: VBoxContainer) -> void:
	var Tr := preload("res://game/i18n/tr.gd")
	var cur := str(profile.setting("lang"))
	var g := Kit.grid(2, 8, 8)
	body.add_child(g)
	for l in Tr.available_languages():
		var code: String = l[0]
		var b := Kit.button(("✔ " if cur == code else "") + str(l[1]), func() -> void:
			profile.set_setting("lang", code)
			Tr.set_language(code)
			sfx.play("click")
			changed.emit("lang")
			nav.call("options", "idioma"), cur == code, 18, Vector2(0, 54))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)
	var hint := Kit.wrap("Los textos del juego cambian al instante. La voz del copiloto usa el idioma de tu teléfono.", 13, Kit.MUTED, 300)
	body.add_child(hint)

## Botón de captura, calidad y grabaciones (la pantalla se arma en capture_ui.gd)
func _capture_page(body: VBoxContainer) -> void:
	var CaptureUi := preload("res://game/ui/capture_ui.gd")
	CaptureUi.options_block(body, profile, sfx, nav, func(k: String) -> void: changed.emit(k))

## Lectura en vivo del acelerómetro (barras de los tres ejes + cuánto gira el volante) y botón de calibrar, sin salir de la pantalla
class AccelMeter extends Control:
	var ref_angle := INF
	var sens_cb: Callable
	var zero_t := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 124)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func calibrate() -> void:
		var g := Input.get_accelerometer()
		ref_angle = rad_to_deg(atan2(g.y, g.x))

	func _process(dt: float) -> void:
		var g := Input.get_accelerometer()
		zero_t = zero_t + dt if g.length() < 0.01 else 0.0
		queue_redraw()

	func _draw() -> void:
		var g := Input.get_accelerometer()
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.1, 0.9), true)
		var names := ["X", "Y", "Z"]
		var vals := [g.x, g.y, g.z]
		var colors := [Color(1, 0.4, 0.4), Color(0.4, 1, 0.5), Color(0.45, 0.7, 1)]
		var bw := size.x - 70.0
		for i in 3:
			var y := 8.0 + float(i) * 25.0
			draw_string(font, Vector2(8, y + 12), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.85, 0.9))
			var cx := 34.0 + bw * 0.5
			draw_rect(Rect2(34, y, bw, 16), Color(1, 1, 1, 0.07), true)
			var f := clampf(float(vals[i]) / 12.0, -1.0, 1.0)
			draw_rect(Rect2(cx if f >= 0.0 else cx + f * bw * 0.5, y, absf(f) * bw * 0.5, 16), colors[i], true)
			draw_line(Vector2(cx, y), Vector2(cx, y + 16), Color(1, 1, 1, 0.5), 1.5)
			draw_string(font, Vector2(size.x - 30, y + 13), "%.1f" % float(vals[i]), HORIZONTAL_ALIGNMENT_RIGHT, 28, 13, Color(0.8, 0.85, 0.9))
		# volante: el ángulo de la gravedad en el plano de la pantalla respecto de la calibración
		var y2 := 84.0
		draw_string(font, Vector2(8, y2 + 14), "Giro", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.82, 0.25))
		var sens := float(sens_cb.call()) if sens_cb.is_valid() else 50.0
		var full := 55.0 - sens * 0.40
		var steer := 0.0
		if Vector2(g.x, g.y).length() >= 3.0:
			if ref_angle == INF:
				calibrate()
			var d := rad_to_deg(atan2(g.y, g.x)) - ref_angle
			d = wrapf(d, -180.0, 180.0)
			steer = clampf(d / full, -1.0, 1.0)
		var cx2 := 34.0 + bw * 0.5
		draw_rect(Rect2(34, y2, bw, 22), Color(1, 1, 1, 0.07), true)
		draw_rect(Rect2(cx2 if steer >= 0.0 else cx2 + steer * bw * 0.5, y2, absf(steer) * bw * 0.5, 22), Color(1.0, 0.48, 0.1), true)
		draw_line(Vector2(cx2, y2), Vector2(cx2, y2 + 22), Color(1, 1, 1, 0.6), 2.0)
		draw_string(font, Vector2(size.x - 40, y2 + 17), "%d%%" % int(round(steer * 100.0)), HORIZONTAL_ALIGNMENT_RIGHT, 38, 15, Color(1.0, 0.82, 0.25))
		if zero_t > 1.0:
			draw_string(font, Vector2(8, size.y - 8), "Sin lectura del acelerómetro (necesita la versión nueva instalada)", HORIZONTAL_ALIGNMENT_LEFT, size.x - 16, 13, Color(1, 0.4, 0.4))

func _accel_block(body: VBoxContainer) -> void:
	var meter := AccelMeter.new()
	meter.sens_cb = func() -> float: return float(profile.setting("gyroSens"))
	body.add_child(meter)
	var row := Kit.hbox(8)
	body.add_child(row)
	var cb := Kit.button("📐 CALIBRAR", func() -> void:
		sfx.play("buy")
		meter.calibrate()
		changed.emit("recal"), true, 18, Vector2(0, 46))
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cb)
	var tip := Kit.label("Sostené el teléfono como para jugar y tocá Calibrar.", 12, Kit.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 150
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tip)

## Partículas (polvo, humo de las gomas, rocío, piedritas): barra de 0 a 10 (0 = sin partículas) o AUTO
func _particles_row(body: VBoxContainer) -> void:
	var p := Kit.panel(8, Kit.PANEL2)
	body.add_child(p)
	var col := Kit.vbox(4)
	p.add_child(col)
	var head := Kit.hbox(8)
	col.add_child(head)
	var lbl := Kit.label("", 19)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)
	var sl := HSlider.new()
	sl.min_value = 0
	sl.max_value = 10
	sl.step = 1
	sl.custom_minimum_size = Vector2(0, 30)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var refresh := func() -> void:
		var v = profile.setting("particles")
		var auto := str(v) == "auto"
		var lvl := int(profile.setting("autoParticles")) if auto else int(v)
		lbl.text = "Partículas: %s" % (("Automática (%d/10)" % lvl) if auto else ("%d/10%s" % [lvl, " (sin)" if lvl == 0 else ""]))
		sl.set_value_no_signal(lvl)
	var auto_b := Kit.button("AUTO", func() -> void:
		sfx.play("click")
		var v = profile.setting("particles")
		profile.set_setting("particles", int(profile.setting("autoParticles")) if str(v) == "auto" else "auto")
		changed.emit("particles")
		refresh.call(), false, 16, Vector2(90, 44))
	head.add_child(auto_b)
	sl.value_changed.connect(func(v: float) -> void:
		profile.set_setting("particles", int(v))
		changed.emit("particles")
		refresh.call())
	col.add_child(sl)
	var hl := Kit.label("Polvo y humo: 1 poco, 10 máximo, 0 sin partículas. AUTO las baja solo si el teléfono no llega.", 12, Kit.MUTED)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.custom_minimum_size.x = 300
	col.add_child(hl)
	refresh.call()

# ───────────────────────── efectos ─────────────────────────
func fx_page(body: VBoxContainer, col_box: VBoxContainer) -> void:
	_title("EFECTOS")
	fx_rows.clear()
	fx_slot_btns.clear()
	# fijo arriba (no se desplaza con la lista): los tres lugares y, del lugar elegido, el interruptor y la intensidad (se ve en vivo)
	var fixed := Kit.vbox(6)
	col_box.add_child(fixed)
	col_box.move_child(fixed, 1)
	var srow := Kit.hbox(6)
	fixed.add_child(srow)
	for i in 3:
		var slot := i
		var sb := Kit.button("", func() -> void:
			fx_slot = slot
			sfx.play("click")
			_fx_refresh(), false, 15, Vector2(0, 44))
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.clip_text = true
		srow.add_child(sb)
		fx_slot_btns.append(sb)
	var strip := Kit.panel(8, Kit.PANEL2)
	fixed.add_child(strip)
	var srow2 := Kit.hbox(10)
	strip.add_child(srow2)
	fx_toggle = Kit.button("", func() -> void:
		var on := _arr("fxOn", true)
		on[fx_slot] = not (on[fx_slot] == true)
		profile.set_setting("fxOn", on)
		sfx.play("click")
		changed.emit("fx")
		_fx_refresh(), false, 17, Vector2(128, 46))
	srow2.add_child(fx_toggle)
	fx_slider = HSlider.new()
	fx_slider.min_value = 0
	fx_slider.max_value = 150
	fx_slider.step = 5
	fx_slider.custom_minimum_size = Vector2(0, 34)
	fx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fx_slider.value_changed.connect(func(v: float) -> void:
		var am := _arr("fxAmt", 1.0)
		am[fx_slot] = v / 100.0
		profile.set_setting("fxAmt", am)
		changed.emit("fx")
		_fx_refresh_strip())
	srow2.add_child(fx_slider)
	fx_val = Kit.label("", 18, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	fx_val.custom_minimum_size.x = 62
	srow2.add_child(fx_val)
	# acciones: lente, combo realista y quitar todo
	var lens_names := ["Apagado", "Suave", "Fuerte"]
	var arow := Kit.hbox(6)
	body.add_child(arow)
	var lb := Kit.button("Lente: %s" % tr(lens_names[int(profile.setting("lens2"))]), Callable(), false, 15, Vector2(0, 42))
	lb.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		var i := (int(profile.setting("lens2")) + 1) % 3
		profile.set_setting("lens2", i)
		lb.text = "%s: %s" % [tr("Lente"), tr(lens_names[i])]
		sfx.play("click")
		changed.emit("fx"))
	lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(lb)
	var combo := Kit.button("🎬 Realista", func() -> void:
		profile.set_setting("fx", [23, 24, 14])
		profile.set_setting("fxOn", [true, true, true])
		profile.set_setting("fxAmt", [1.0, 1.0, 1.0])
		sfx.play("buy")
		changed.emit("fx")
		_fx_refresh(), true, 15, Vector2(0, 42))
	combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(combo)
	var clr := Kit.button("✕ Quitar", func() -> void:
		profile.set_setting("fx", [0, 0, 0])
		sfx.play("click")
		changed.emit("fx")
		_fx_refresh(), false, 15, Vector2(0, 42))
	clr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(clr)
	var hold := VBoxContainer.new()
	hold.add_theme_constant_override("separation", 6)
	body.add_child(hold)
	_fx_list(hold)
	_fx_refresh()

var fx_pg := 0
const FX_PER_PAGE := 8

func _fx_list(hold: VBoxContainer) -> void:
	for c in hold.get_children():
		c.queue_free()
	fx_rows.clear()
	var n := Lens.FX_NAMES.size()
	var pages := maxi(1, int(ceil(float(n) / float(FX_PER_PAGE))))
	fx_pg = clampi(fx_pg, 0, pages - 1)
	var g := Kit.grid(2, 6, 6)
	hold.add_child(g)
	for k in range(fx_pg * FX_PER_PAGE, mini(n, (fx_pg + 1) * FX_PER_PAGE)):
		var id := k
		var cost := "●".repeat(int(Lens.FX_COST[k])) if k > 0 else ""
		var b := Kit.button("", Callable(), false, 15, Vector2(0, 44))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := Kit.hbox(4)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -10
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var nl := Kit.label("%d. %s" % [k, Lens.FX_NAMES[k]] if k > 0 else tr("Ninguno"), 14)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.custom_minimum_size.x = 30
		row.add_child(nl)
		var ml := Kit.label("", 14, Kit.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(ml)
		var cl := Kit.label(cost, 9, Kit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cl)
		b.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			var a: Array = _fx_get()
			a[fx_slot] = id
			var on2 := _arr("fxOn", true)
			on2[fx_slot] = true # al elegir un efecto el lugar queda activo
			profile.set_setting("fxOn", on2)
			profile.set_setting("fx", a)
			sfx.play("click")
			changed.emit("fx")
			_fx_refresh())
		g.add_child(b)
		fx_rows.append({"id": id, "btn": b, "mark": ml})
	hold.add_child(Kit.pager(fx_pg, pages, func(pg: int) -> void:
		fx_pg = pg
		_fx_list(hold)
		_fx_refresh()))

func _fx_get() -> Array:
	var a = profile.setting("fx")
	return [int(a[0]), int(a[1]), int(a[2])] if a is Array and a.size() >= 3 else [0, 0, 0]

func _arr(key: String, def) -> Array:
	var a = profile.setting(key)
	var out: Array = []
	for i in 3:
		out.append(a[i] if a is Array and a.size() > i else def)
	return out

func _fx_refresh_strip() -> void:
	var ids := _fx_get()
	var has: bool = int(ids[fx_slot]) > 0
	var on: bool = _arr("fxOn", true)[fx_slot] == true
	var amt := float(_arr("fxAmt", 1.0)[fx_slot])
	fx_toggle.text = "● ACTIVO" if on else "○ APAGADO"
	fx_toggle.disabled = not has
	fx_toggle.add_theme_stylebox_override("normal", Kit.box(Kit.GREEN.darkened(0.45) if (on and has) else Kit.PANEL2, 12, Kit.LINE, 1, 14))
	fx_slider.editable = has
	fx_slider.set_value_no_signal(amt * 100.0)
	fx_val.text = "%d%%" % int(round(amt * 100.0)) if has else "—"

func _fx_refresh() -> void:
	var a := _fx_get()
	for i in fx_slot_btns.size():
		var b: Button = fx_slot_btns[i]
		b.text = "%d · %s" % [i + 1, Lens.FX_NAMES[a[i]] if a[i] > 0 else "—"]
		b.add_theme_stylebox_override("normal", Kit.box(Kit.ACCENT if i == fx_slot else Kit.PANEL2, 12, Kit.LINE, 1, 14))
		b.add_theme_color_override("font_color", Color(0.05, 0.06, 0.08) if i == fx_slot else Kit.TEXT)
	_fx_refresh_strip()
	for r in fx_rows:
		var marks: Array = []
		for i in 3:
			if a[i] == r["id"] and r["id"] > 0:
				marks.append(str(i + 1))
		(r["mark"] as Label).text = "✔ " + "+".join(marks) if not marks.is_empty() else ""

