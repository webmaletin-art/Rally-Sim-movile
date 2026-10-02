extends CanvasLayer
## Pantalla de carga de la carrera: mientras se arma el mapa en etapas muestra la pista, los datos de la carrera, una barra de avance
## y consejos con dibujos sobre cómo se comporta el auto (peso, adherencia, subviraje, deriva, trazada) y sobre el nivel de simulación elegido.

const Kit := preload("res://game/ui/ui_kit.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")

var cfg: Dictionary
var track_name := ""
var bar: ProgressBar
var pct_l: Label
var status_l: Label
var tip_title: Label
var tip_text: Label
var art: TipArt
var tip_box: Control
var tip_i := 0
var tip_t := 0.0
var tips: Array = []
var target := 0.0
var shown := 0.0

func _init() -> void:
	layer = 90

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var base := str(cfg.get("track", "")).replace("Rev", "")
	var path := "res://game/ui/tracks/%s_%d.jpg" % [base, 0]
	var adv := str(cfg.get("type", "")) == "adventure"
	if adv:
		path = "res://game/ui/tracks/adv%d.jpg" % int(cfg.get("stage", 0))
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.modulate = Color(0.55, 0.6, 0.7)
		root.add_child(tr)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	# columna izquierda: datos de la carrera
	var left := Kit.vbox(8)
	left.position = Vector2(34, 30)
	left.custom_minimum_size = Vector2(430, 0)
	root.add_child(left)
	left.add_child(Kit.label("CARGANDO ETAPA" if adv else "CARGANDO MAPA", 42, Kit.ACCENT))
	left.add_child(Kit.label(track_name, 28, Kit.TEXT))
	var info := Kit.label(_info_text(), 18, Kit.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size.x = 420
	left.add_child(info)
	# consejos con dibujo (a la derecha)
	tips = _make_tips()
	tip_box = Control.new()
	tip_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	tip_box.custom_minimum_size = Vector2(470, 300)
	tip_box.position = Vector2(-500, -160)
	root.add_child(tip_box)
	var card := Kit.panel(16, Color(0.06, 0.08, 0.12, 0.88))
	card.custom_minimum_size = Vector2(470, 300)
	tip_box.add_child(card)
	var cv := Kit.vbox(8)
	card.add_child(cv)
	art = TipArt.new()
	art.custom_minimum_size = Vector2(430, 168)
	cv.add_child(art)
	tip_title = Kit.label("", 24, Kit.GOLD)
	cv.add_child(tip_title)
	tip_text = Kit.label("", 17, Kit.TEXT)
	tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_text.custom_minimum_size.x = 430
	cv.add_child(tip_text)
	_show_tip(0)
	# barra abajo
	var bot := Kit.vbox(6)
	bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 34
	bot.offset_right = -34
	bot.offset_top = -86
	bot.offset_bottom = -22
	root.add_child(bot)
	var row := Kit.hbox(10)
	bot.add_child(row)
	status_l = Kit.label("Preparando…", 18, Kit.MUTED)
	status_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_l)
	pct_l = Kit.label("0%", 20, Kit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	row.add_child(pct_l)
	bar = ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.add_theme_stylebox_override("background", Kit.box(Color(1, 1, 1, 0.10), 8))
	bar.add_theme_stylebox_override("fill", Kit.box(Kit.ACCENT, 8))
	bot.add_child(bar)

func set_progress(frac: float, text: String) -> void:
	target = clampf(frac, 0.0, 1.0)
	if status_l != null:
		status_l.text = text

var _shot := ""
var _fr := 0
func _process(dt: float) -> void:
	_fr += 1
	if _shot == "":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--loadshot="):
				_shot = a.substr(11)
	if _shot != "" and _fr == 12:
		get_viewport().get_texture().get_image().save_png(_shot) # prueba: captura de la pantalla de carga
	shown = lerpf(shown, target, clampf(dt * 6.0, 0.0, 1.0))
	if bar != null:
		bar.value = shown
		pct_l.text = "%d%%" % int(round(shown * 100.0))
	tip_t += dt
	if tip_t > 6.0:
		tip_t = 0.0
		tip_i = (tip_i + 1) % tips.size()
		_show_tip(tip_i)
	art.t += dt
	art.queue_redraw()
	# el cartel del consejo se desvanece un poco al cambiar
	tip_box.modulate.a = clampf(minf(tip_t / 0.4, (6.0 - tip_t) / 0.4), 0.0, 1.0)

func _show_tip(i: int) -> void:
	var t: Dictionary = tips[i]
	tip_title.text = str(t["title"])
	tip_text.text = str(t["text"])
	art.kind = str(t["art"])
	art.t = 0.0

func _info_text() -> String:
	var lines: Array = []
	if str(cfg.get("type", "")) == "adventure":
		var S: Dictionary = AdvRoute.STAGES[int(cfg.get("stage", 0))]
		lines.append(str(S["sub"]))
		lines.append("Rival: " + str(S["rival"]["name"]) + ((" y " + str(S["rival2"]["name"])) if S.has("rival2") else ""))
		lines.append("%.1f km hasta la próxima estación" % (AdvRoute.get_route().stage_length(int(cfg.get("stage", 0))) / 1000.0))
		lines.append("Modo aventura · simulación total con un poco de ayuda")
		return "\n".join(lines)
	var typ: String = {"race": "Carrera", "timetrial": "Contrarreloj", "trap": "Radar", "drift": "Drift", "bench": "Prueba de rendimiento", "free": "Prueba libre"}.get(str(cfg.get("type", "race")), "Carrera")
	var l := "%s" % typ
	if int(cfg.get("laps", 1)) > 1 and not (cfg.get("seg") is Array):
		l += " · %d vueltas" % int(cfg["laps"])
	if int(cfg.get("ai", 0)) > 0:
		l += " · %d rivales" % int(cfg["ai"])
	lines.append(l)
	var sky: String = {"day": "☀ Día", "overcast": "☁ Nublado", "sunset": "🌇 Atardecer", "dusk": "🌆 Anochecer", "rain": "🌧 Lluvia"}.get(str(cfg.get("sky", "day")), "")
	lines.append(sky)
	var lv: String = {"arcade": "Arcade", "mid": "Intermedio", "pro": "Simulador total", "custom": "Personalizado"}.get(str(cfg.get("sim", "mid")), "")
	lines.append("Nivel de simulación: " + lv)
	return "\n".join(lines)

func _make_tips() -> Array:
	var lv := str(cfg.get("sim", "mid"))
	var lv_text: String = {
		"arcade": "ARCADE: ABS, control de tracción y estabilidad altos, y el auto te ayuda a doblar. Ideal para aprender la pista.",
		"mid": "INTERMEDIO: ayudas medias y una ayuda de trazada suave: manejo equilibrado.",
		"pro": "SIMULADOR TOTAL: sin ayudas. Cada frenada y cada acelerada cuentan: manejá fino.",
		"custom": "PERSONALIZADO: usás las ayudas que elegiste. Podés cambiarlas desde Opciones en la pausa.",
	}.get(lv, "")
	var out: Array = [
		{"title": "Tu nivel de simulación", "text": lv_text, "art": "circle"},
		{"title": "El peso se mueve", "text": "Al frenar, el peso se va hacia adelante: las ruedas de adelante agarran más y las de atrás menos. Al acelerar pasa al revés. Frená recto y antes de la curva.", "art": "weight"},
		{"title": "Círculo de adherencia", "text": "Cada goma tiene una cantidad de agarre y se reparte: si frenás fuerte y doblás a la vez, no alcanza para las dos cosas. Soltá freno al girar.", "art": "circle"},
		{"title": "Subviraje y sobreviraje", "text": "Si entrás muy rápido, el auto se abre (subviraje): soltá el acelerador y enderezá un poco el volante. Si la cola se va (sobreviraje), contravolanteá suave.", "art": "steer"},
		{"title": "Tierra y lluvia", "text": "En tierra y con lluvia hay menos agarre: el auto desliza más y frena más largo. Anticipá las frenadas y dejá que el auto se acomode antes de acelerar.", "art": "slip"},
		{"title": "La línea de la curva", "text": "Entrá por afuera, tocá la parte de adentro de la curva y salí por afuera: la curva se hace más abierta y podés acelerar antes.", "art": "line"},
		{"title": "Guardarraíl", "text": "Si rozás la chapa del costado, el auto se frena; un golpe fuerte te hace perder tiempo. Y no se puede pasar: vas a volver a la pista.", "art": "weight"},
		{"title": "Cámaras", "text": "Con el botón CAM cambiás de cámara. Las interiores muestran a los pilotos: la lluvia moja el parabrisas y el limpiaparabrisas lo despeja.", "art": "line"},
	]
	return out

## Dibujos animados de los consejos (todos hechos con líneas y círculos)
class TipArt extends Control:
	var kind := "circle"
	var t := 0.0

	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.06, 0.09), true)
		var col := Color(1.0, 0.48, 0.1)
		var white := Color(0.92, 0.95, 0.98)
		var dim := Color(1, 1, 1, 0.18)
		match kind:
			"weight":
				# auto de costado: la trompa baja al frenar y sube al acelerar; flechas del peso
				var ph := sin(t * 1.6)
				var cx := s.x * 0.5
				var gy := s.y * 0.72
				draw_line(Vector2(10, gy + 22), Vector2(s.x - 10, gy + 22), dim, 3.0)
				var pitch := ph * 0.07
				var body := PackedVector2Array()
				for p in [Vector2(-95, 0), Vector2(-85, -28), Vector2(-40, -34), Vector2(-15, -58), Vector2(45, -58), Vector2(75, -32), Vector2(98, -22), Vector2(98, 0)]:
					var q: Vector2 = (p as Vector2).rotated(pitch)
					body.append(Vector2(cx, gy) + q)
				draw_colored_polygon(body, col)
				draw_polyline(body + PackedVector2Array([body[0]]), white, 2.0)
				for wx in [-60.0, 62.0]:
					var wp := Vector2(cx, gy) + Vector2(wx, 6).rotated(pitch)
					draw_circle(wp, 19.0, Color(0.1, 0.1, 0.12))
					draw_circle(wp, 8.0, Color(0.6, 0.62, 0.68))
				var braking := ph > 0.0
				var ax := Vector2(cx + (95.0 if braking else -95.0), gy - 62.0)
				draw_line(ax, ax + Vector2(40.0 if braking else -40.0, 0), white, 4.0)
				draw_string(ThemeDB.fallback_font, Vector2(12, 24), "FRENADA: el peso va adelante" if braking else "ACELERACIÓN: el peso va atrás", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, white)
			"circle":
				var c := Vector2(s.x * 0.5, s.y * 0.54)
				var r := minf(s.x, s.y) * 0.4
				draw_arc(c, r, 0, TAU, 64, white, 2.5, true)
				draw_arc(c, r * 0.5, 0, TAU, 48, dim, 1.5, true)
				draw_line(c - Vector2(r, 0), c + Vector2(r, 0), dim, 1.5)
				draw_line(c - Vector2(0, r), c + Vector2(0, r), dim, 1.5)
				var d := Vector2(sin(t * 1.3) * 0.85, cos(t * 0.9 + 0.5) * 0.7)
				if d.length() > 0.95:
					d = d.normalized() * 0.95
				draw_circle(c + d * r, 9.0, col)
				var f := ThemeDB.fallback_font
				draw_string(f, c + Vector2(-26, -r - 6), "FRENO", HORIZONTAL_ALIGNMENT_CENTER, 52, 14, white)
				draw_string(f, c + Vector2(-30, r + 16), "ACELERAR", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, white)
				draw_string(f, c + Vector2(-r - 44, 5), "GIRO", HORIZONTAL_ALIGNMENT_CENTER, 40, 14, white)
				draw_string(f, c + Vector2(r + 6, 5), "GIRO", HORIZONTAL_ALIGNMENT_LEFT, 40, 14, white)
			"steer":
				# curva a la derecha: trayectoria ideal, subviraje (se abre) y sobreviraje (cola afuera)
				var c2 := Vector2(s.x * 0.2, s.y * 0.95)
				var rr := s.y * 0.7
				draw_arc(c2, rr, -PI / 2.0, 0.0, 32, dim, 28.0, true)
				draw_arc(c2, rr, -PI / 2.0, 0.0, 32, white, 2.0, true)
				var k := fposmod(t * 0.35, 1.0)
				var a1 := -PI / 2.0 + k * PI / 2.0
				draw_circle(c2 + Vector2(cos(a1), sin(a1)) * rr, 8.0, white)
				var a2 := -PI / 2.0 + k * PI / 2.0 * 0.8
				draw_circle(c2 + Vector2(cos(a2), sin(a2)) * (rr + 18.0 * k), 8.0, Color(0.4, 0.7, 1.0))
				var a3 := -PI / 2.0 + k * PI / 2.0 * 1.12
				draw_circle(c2 + Vector2(cos(a3), sin(a3)) * (rr - 12.0 * k), 8.0, col)
				var f2 := ThemeDB.fallback_font
				draw_string(f2, Vector2(s.x * 0.52, 30), "● ideal", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, white)
				draw_string(f2, Vector2(s.x * 0.52, 52), "● subviraje (se abre)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.4, 0.7, 1.0))
				draw_string(f2, Vector2(s.x * 0.52, 74), "● sobreviraje (cola afuera)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
			"slip":
				# la goma apunta a un lado y el auto va a otro: ángulo de deriva
				var c3 := Vector2(s.x * 0.5, s.y * 0.55)
				var ang := sin(t * 1.2) * 0.45
				var dir := Vector2(0, -1)
				var head := dir.rotated(ang)
				draw_line(c3, c3 + dir * 70.0, col, 4.0)
				draw_line(c3, c3 - dir * 70.0, col, 4.0)
				draw_set_transform(c3, ang, Vector2.ONE)
				draw_rect(Rect2(-18, -34, 36, 68), Color(0.12, 0.12, 0.15), true)
				draw_rect(Rect2(-18, -34, 36, 68), white, false, 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_line(c3, c3 + head * 70.0, white, 2.0)
				draw_string(ThemeDB.fallback_font, Vector2(12, 24), "El agarre baja con la deriva y en tierra o lluvia", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, white)
			_: # line: curva de 90°, por afuera, adentro, afuera
				var p0 := Vector2(s.x * 0.12, s.y * 0.88)
				draw_polyline(PackedVector2Array([Vector2(s.x * 0.18, s.y * 1.0), Vector2(s.x * 0.18, s.y * 0.3), Vector2(s.x * 0.2, s.y * 0.16), Vector2(s.x * 0.34, s.y * 0.12), Vector2(s.x * 0.95, s.y * 0.12)]), dim, 30.0, true)
				var pts := PackedVector2Array()
				for i in 41:
					var u := float(i) / 40.0
					var q := Vector2(s.x * 0.10 + 0.0 * u, s.y) .lerp(Vector2(s.x * 0.98, s.y * 0.18), 0.0)
					# bezier cuadrática: afuera → vértice adentro → afuera
					var a := Vector2(s.x * 0.10, s.y * 1.0)
					var b := Vector2(s.x * 0.10, s.y * 0.06)
					var cc := Vector2(s.x * 0.98, s.y * 0.06)
					q = a.lerp(b, u).lerp(b.lerp(cc, u), u)
					pts.append(q)
				draw_polyline(pts, white, 2.0, true)
				var k2 := int(fposmod(t * 0.4, 1.0) * 40.0)
				draw_circle(pts[k2], 8.0, col)
				draw_string(ThemeDB.fallback_font, Vector2(s.x * 0.45, s.y * 0.7), "afuera → adentro → afuera", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, white)
