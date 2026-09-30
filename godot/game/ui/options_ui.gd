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

## [categoría, clave, título, valores, etiquetas]
const OPTION_CATS := [["graficos", "🖥 Gráficos", "calidad general, resolución, árboles, sombras"], ["texturas", "🧱 Texturas", "filtrado de las texturas"],
	["fisica", "⚙ Física y ayudas", "ABS, tracción, estabilidad"], ["sonido", "🔊 Sonido", "volúmenes y voz del copiloto"],
	["manejo", "🎮 Manejo", "caja, dirección, inclinación"], ["camara", "🎥 Cámara", "cámara al empezar"], ["efectos", "✨ Efectos", "Lente Rally y efectos 2.0 (hasta 3 a la vez)"]]
const OPTION_LIST := [
	["graficos", "quality", "Calidad general", ["auto", "low", "mid", "high"], ["Automática", "Baja", "Media", "Alta"]],
	["graficos", "res", "Resolución del 3D", [0, 0.35, 0.5, 0.7, 1.0], ["Automática", "35%", "50%", "70%", "100%"]],
	["graficos", "trees", "Árboles", ["auto", 0, 1500, 3000, 6000], ["Según la calidad", "Ninguno", "Pocos", "Normales", "Muchos"]],
	["graficos", "shadowsQ", "Sombras", ["auto", false, true], ["Según la calidad", "No", "Sí"]],
	["texturas", "textures", "Calidad de texturas", ["low", "mid", "high"], ["Baja", "Media", "Alta"]],
	["fisica", "abs", "ABS", [false, true], ["No", "Sí"]],
	["fisica", "tc", "Control de tracción", [0, 25, 50, 75, 100], ["Apagado", "25%", "50%", "75%", "100%"]],
	["fisica", "stab", "Estabilidad", [0, 30, 60, 100], ["Apagada", "Baja", "Media", "Alta"]],
	["sonido", "volume", "Volumen general", [0, 30, 60, 80, 100], ["Silencio", "Bajo", "Medio", "Alto", "Máximo"]],
	["sonido", "volEngine", "Motor", [0, 50, 75, 100, 130], ["Silencio", "Bajo", "Medio", "Normal", "Fuerte"]],
	["sonido", "volSurf", "Gomas y tierra", [0, 15, 30, 50, 80], ["Silencio", "Muy bajo", "Normal", "Fuerte", "Muy fuerte"]],
	["sonido", "volWind", "Viento", [0, 15, 30, 50, 80], ["Silencio", "Muy bajo", "Normal", "Fuerte", "Muy fuerte"]],
	["sonido", "volTurbo", "Turbo", [0, 50, 100, 140], ["Silencio", "Bajo", "Normal", "Fuerte"]],
	["sonido", "volGear", "Caja de cambios", [0, 50, 100, 140], ["Silencio", "Bajo", "Normal", "Fuerte"]],
	["sonido", "copilot", "Voz del copiloto (campeonato)", [false, true], ["No", "Sí"]],
	["manejo", "gearbox", "Caja de cambios", ["auto", "manual"], ["Automática", "Manual"]],
	["manejo", "steerMode", "Dirección", ["wheel", "slider"], ["Volante", "Barra"]],
	["manejo", "gyro", "Volante con inclinación", [false, true], ["No", "Sí"]],
	["manejo", "gyroSens", "Sensibilidad de la inclinación", [25, 50, 75, 100], ["Baja", "Media", "Alta", "Muy alta"]],
	["manejo", "units", "Unidades", ["kmh", "mph"], ["km/h", "mph"]],
	["manejo", "vibrate", "Vibración", [false, true], ["No", "Sí"]],
	["camara", "camera", "Cámara al empezar", [0, 1, 2, 3, 4, 6, 7, 8], ["Casco", "Seguimiento", "Cerca", "Lejos", "Aérea", "Trasera (dos pilotos)", "Capó", "Paragolpes"]],
]

func options_page(body: VBoxContainer, cat = null) -> void:
	if cat == null:
		_title("OPCIONES")
		for c in OPTION_CATS:
			var key: String = c[0]
			body.add_child(_cat_button(c[1], c[2], func(): nav.call("fx", null) if key == "efectos" else nav.call("options", key)))
		if reset_cb.is_valid():
			body.add_child(Kit.label("PROGRESO", 16, Kit.MUTED))
			body.add_child(Kit.button("🗑 BORRAR TODO EL PROGRESO", reset_cb, false, 20))
		return
	for c in OPTION_CATS:
		if c[0] == cat:
			_title(str(c[1]).to_upper())
	for o in OPTION_LIST:
		if o[0] != cat:
			continue
		var key: String = o[1]
		var vals: Array = o[3]
		var cur = profile.setting(key)
		var idx := vals.find(cur)
		if idx < 0:
			idx = 0
		var b := Kit.button("%s:  %s" % [o[2], o[4][idx]], Callable(), false, 20, Vector2(0, 52))
		b.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			var cur2 = profile.setting(key)
			var i2 := vals.find(cur2)
			i2 = (i2 + 1) % vals.size()
			profile.set_setting(key, vals[i2])
			if key == "volume":
				sfx.volume = float(vals[i2]) / 100.0
			sfx.play("click")
			changed.emit(key)
			b.text = "%s:  %s" % [o[2], o[4][i2]])
		body.add_child(b)
	if cat == "graficos":
		var hint := Kit.label("La calidad automática ajusta la resolución sola según lo que aguante el teléfono.", 15, Kit.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = 380
		body.add_child(hint)

# ───────────────────────── efectos ─────────────────────────
func fx_page(body: VBoxContainer, col_box: VBoxContainer) -> void:
	_title("EFECTOS")
	fx_rows.clear()
	fx_slot_btns.clear()
	# fijo arriba (no se desplaza con la lista): el lente y los tres lugares para efectos
	var fixed := Kit.vbox(8)
	col_box.add_child(fixed)
	col_box.move_child(fixed, 1)
	var lens_vals := [0, 1, 2]
	var lens_names := ["Apagado", "Suave", "Fuerte"]
	var lb := Kit.button("Lente Rally:  %s" % lens_names[int(profile.setting("lens2"))], Callable(), false, 20, Vector2(0, 50))
	lb.pressed.connect(func() -> void:
		var i := (int(profile.setting("lens2")) + 1) % 3
		profile.set_setting("lens2", i)
		lb.text = "Lente Rally:  %s" % lens_names[i]
		sfx.play("click")
		changed.emit("fx"))
	fixed.add_child(lb)
	var h2 := Kit.label("EFECTOS 2.0 — tocá un lugar y elegí el efecto (hasta 3 a la vez)", 15, Kit.MUTED)
	h2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h2.custom_minimum_size.x = 300
	fixed.add_child(h2)
	var srow := Kit.hbox(6)
	fixed.add_child(srow)
	for i in 3:
		var slot := i
		var sb := Kit.button("", func() -> void:
			fx_slot = slot
			sfx.play("click")
			_fx_refresh(), false, 17, Vector2(0, 54))
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.clip_text = true
		srow.add_child(sb)
		fx_slot_btns.append(sb)
	for k in Lens.FX_NAMES.size():
		var id := k
		var cost := "●".repeat(int(Lens.FX_COST[k])) if k > 0 else ""
		var b := Kit.button("", Callable(), false, 19, Vector2(0, 50))
		var row := Kit.hbox(8)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 12
		row.offset_right = -12
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var nl := Kit.label("%d. %s" % [k, Lens.FX_NAMES[k]] if k > 0 else "Ninguno", 19)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nl)
		var cl := Kit.label(cost, 14, Kit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(cl)
		var ml := Kit.label("", 17, Kit.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT)
		ml.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(ml)
		b.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			var a: Array = _fx_get()
			a[fx_slot] = id
			profile.set_setting("fx", a)
			sfx.play("click")
			changed.emit("fx")
			_fx_refresh())
		body.add_child(b)
		fx_rows.append({"id": id, "btn": b, "mark": ml})
	var foot := Kit.label("● liviano … ●●●●● pesado para el teléfono. Los de contorno (boceto, pizarra, graphic black, 1-bit, sin city, borderlands, tiza, XIII) y el infrarrojo son los que más cuestan: si ves tirones, bajá la resolución.", 14, Kit.MUTED)
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size.x = 300
	body.add_child(foot)
	_fx_refresh()

func _fx_get() -> Array:
	var a = profile.setting("fx")
	return [int(a[0]), int(a[1]), int(a[2])] if a is Array and a.size() >= 3 else [0, 0, 0]

func _fx_refresh() -> void:
	var a := _fx_get()
	for i in fx_slot_btns.size():
		var b: Button = fx_slot_btns[i]
		b.text = "%d · %s" % [i + 1, Lens.FX_NAMES[a[i]] if a[i] > 0 else "—"]
		b.add_theme_stylebox_override("normal", Kit.box(Kit.ACCENT if i == fx_slot else Kit.PANEL2, 12, Kit.LINE, 1, 14))
		b.add_theme_color_override("font_color", Color(0.05, 0.06, 0.08) if i == fx_slot else Kit.TEXT)
	for r in fx_rows:
		var marks: Array = []
		for i in 3:
			if a[i] == r["id"] and r["id"] > 0:
				marks.append(str(i + 1))
		(r["mark"] as Label).text = "✔ " + "+".join(marks) if not marks.is_empty() else ""

