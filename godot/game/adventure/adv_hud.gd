extends Control
## Pantalla del modo aventura: etapa y reloj, distancia al rival (barra), daño del auto, minimapa de la etapa, aviso del
## taller (entrar / seguir), mensajes grandes, franjas de cine, fundido a negro y las pantallas completas (explicación,
## estación de servicio con guía/ajuste/habilidades, taller, derrota y final).

const Kit := preload("res://game/ui/ui_kit.gd")
const TouchScroll := preload("res://game/ui/touch_scroll.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const CarBuild := preload("res://game/data/car_build.gd")

signal choice(id: String) # botones de las pantallas

var info: PanelContainer
var stage_l: Label
var time_l: Label
var dist_l: Label
var gap_box: Control
var gap_l: Label
var dmg: Control
var prompt: PanelContainer
var prompt_l: Label
var big_l: Label
var sub_l: Label
var toast_l: Label
var bars: Array = []
var fade: ColorRect
var overlay: Control
var minimap: Control
var big_t := 0.0
var toast_t := 0.0
var fade_target := 0.0
var bars_on := false
var bars_k := 0.0
var sfx: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	# franjas negras de cine (arriba y abajo)
	for k in 2:
		var b := ColorRect.new()
		b.color = Color(0, 0, 0)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_anchors_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
		add_child(b)
		bars.append(b)
	# panel de la etapa
	info = Kit.panel(10, Color(0.04, 0.05, 0.08, 0.72))
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.position = Vector2(14, 10)
	add_child(info)
	var col := Kit.vbox(0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(col)
	stage_l = Kit.label("", 17, Kit.ACCENT)
	col.add_child(stage_l)
	var row := Kit.hbox(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	time_l = Kit.label("0:00.00", 28)
	row.add_child(time_l)
	dist_l = Kit.label("", 17, Kit.MUTED)
	dist_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dist_l)
	# distancia con el rival (dentro del mismo panel, debajo del reloj)
	gap_box = GapBar.new()
	col.add_child(gap_box)
	gap_l = Kit.label("", 16, Color.WHITE)
	col.add_child(gap_l)
	# daño
	dmg = DamageIcon.new()
	add_child(dmg)
	# aviso del taller
	prompt = Kit.panel(14, Color(0.06, 0.07, 0.1, 0.9))
	prompt.visible = false
	prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	prompt.offset_top = 150
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(prompt)
	var pv := Kit.vbox(8)
	prompt.add_child(pv)
	prompt_l = Kit.label("", 20, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	pv.add_child(prompt_l)
	var ph := Kit.hbox(10)
	pv.add_child(ph)
	var b1 := Kit.button("🔧 INGRESAR AL TALLER", func(): _pick("ws_in"), true, 20, Vector2(250, 54))
	ph.add_child(b1)
	var b2 := Kit.button("SEGUIR ▶", func(): _pick("ws_skip"), false, 20, Vector2(150, 54))
	ph.add_child(b2)
	# mensajes
	big_l = Kit.label("", 84, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	big_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	big_l.add_theme_constant_override("outline_size", 14)
	big_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	big_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_l.offset_top = -80
	add_child(big_l)
	sub_l = Kit.label("", 30, Kit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	sub_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	sub_l.add_theme_constant_override("outline_size", 8)
	sub_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sub_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sub_l.offset_top = 40
	add_child(sub_l)
	toast_l = Kit.label("", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	toast_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	toast_l.add_theme_constant_override("outline_size", 8)
	toast_l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_l.offset_top = 160
	add_child(toast_l)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

func _pick(id: String) -> void:
	if sfx != null:
		sfx.play("click")
	choice.emit(id)

## Barra de distancia: el jugador (naranja) y el rival (su color) sobre una escala de ±200 m
class GapBar extends Control:
	var gap := 0.0
	var col := Color.RED
	var col2 := Color(0, 0, 0, 0)
	var gap2 := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(230, 22)
	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		draw_rect(Rect2(0, y - 4, w, 8), Color(0, 0, 0, 0.5), true)
		draw_rect(Rect2(w * 0.5 - 1, y - 9, 2, 18), Color(1, 1, 1, 0.35), true)
		var px := w * 0.5
		var rx := clampf(w * 0.5 + gap / 200.0 * w * 0.5, 8.0, w - 8.0)
		draw_line(Vector2(px, y), Vector2(rx, y), Color(col.r, col.g, col.b, 0.6), 4.0)
		draw_circle(Vector2(rx, y), 8.0, Color.WHITE)
		draw_circle(Vector2(rx, y), 6.0, col)
		if col2.a > 0.0:
			var r2 := clampf(w * 0.5 + gap2 / 200.0 * w * 0.5, 6.0, w - 6.0)
			draw_circle(Vector2(r2, y), 8.0, Color.WHITE)
			draw_circle(Vector2(r2, y), 6.0, col2)
		draw_circle(Vector2(px, y), 9.0, Color.WHITE)
		draw_circle(Vector2(px, y), 7.0, Kit.ACCENT)

## Auto visto de arriba con las tres partes coloreadas según el daño (verde → amarillo → rojo)
class DamageIcon extends Control:
	var d := {"motor": 0.0, "dir": 0.0, "susp": 0.0}
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -250
		offset_right = -200
		offset_top = 14
		size = Vector2(50, 84)
	func _c(v: float) -> Color:
		if v < 0.05:
			return Color(0.3, 0.85, 0.5, 0.9)
		return Color(1.0, 0.85, 0.2, 0.95).lerp(Color(1.0, 0.25, 0.2, 0.95), clampf((v - 0.2) / 0.5, 0.0, 1.0))
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 50, 84), Color(0, 0, 0, 0.45), true)
		draw_rect(Rect2(12, 6, 26, 24), _c(float(d["motor"])), true) # motor (adelante)
		draw_rect(Rect2(6, 10, 5, 12), _c(float(d["dir"])), true)
		draw_rect(Rect2(39, 10, 5, 12), _c(float(d["dir"])), true)
		draw_rect(Rect2(14, 34, 22, 34), Color(0.75, 0.78, 0.82, 0.8), true)
		draw_rect(Rect2(6, 58, 5, 14), _c(float(d["susp"])), true)
		draw_rect(Rect2(39, 58, 5, 14), _c(float(d["susp"])), true)

## Minimapa de la etapa entera: la ruta, la estación de llegada, el taller y los autos
class StageMap extends Control:
	var pts := PackedVector2Array()
	var marks: Array = [] # [punto, color, radio]
	var cars: Array = []
	var colors: Array = []
	var minv := Vector2.ZERO
	var k := 1.0
	var box := Vector2(200, 130)
	var alt_pts := PackedVector2Array()
	func setup_track(track, colors_in: Array, alt = null) -> void:
		colors = colors_in
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		var raw := PackedVector2Array()
		for i in range(track.i_start, mini(track.n, track.i_end + 1), 4):
			var p: Vector3 = track.samples[i]
			var q := Vector2(p.x, -p.z)
			raw.append(q)
			lo = lo.min(q)
			hi = hi.max(q)
		var sz := hi - lo
		k = minf((box.x - 16.0) / maxf(sz.x, 1.0), (box.y - 16.0) / maxf(sz.y, 1.0))
		minv = lo - (box - sz * k) * 0.5 / k
		pts.clear()
		for q in raw:
			pts.append((q - minv) * k)
		alt_pts.clear()
		if alt != null:
			for i in range(int(alt.split), mini(int(alt.n), int(alt.join) + 1), 3):
				var pa: Vector3 = alt.samples[i]
				alt_pts.append(to_map(pa.x, pa.z))
		marks.clear()
		for e in track.events:
			var t := str(e["t"])
			var i: int = e["i"]
			if i < track.i_start or i > track.i_end + 2:
				continue
			var p: Vector3 = track.samples[i]
			if t == "workshop":
				marks.append([to_map(p.x, p.z), Color(1.0, 0.8, 0.2), 4.0])
			elif t == "station" and i > track.i_start + 10:
				marks.append([to_map(p.x, p.z), Color(0.3, 0.9, 0.5), 5.5])
			elif t == "tunnel" or t == "mine":
				marks.append([to_map(p.x, p.z), Color(0.6, 0.6, 0.65), 3.0])
		custom_minimum_size = box
		size = box
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()
	func to_map(x: float, z: float) -> Vector2:
		return (Vector2(x, -z) - minv) * k
	func set_cars(list: Array) -> void:
		cars = list
		queue_redraw()
	func _draw() -> void:
		if pts.size() < 2:
			return
		draw_rect(Rect2(Vector2.ZERO, box), Color(0.03, 0.05, 0.08, 0.62), true)
		draw_rect(Rect2(Vector2.ZERO, box), Color(1, 1, 1, 0.18), false, 1.5)
		draw_polyline(pts, Color(1, 1, 1, 0.28), 5.0, true)
		draw_polyline(pts, Color(0.62, 0.66, 0.74, 0.95), 2.5, true)
		if alt_pts.size() > 1:
			# el ramal de la bifurcación (punteado)
			for q in range(0, alt_pts.size() - 1, 2):
				draw_line(alt_pts[q], alt_pts[q + 1], Color(1.0, 0.85, 0.35, 0.95), 2.0, true)
		for m in marks:
			draw_circle(m[0], float(m[2]) + 1.5, Color(0, 0, 0, 0.7))
			draw_circle(m[0], float(m[2]), m[1])
		for i in range(cars.size() - 1, -1, -1):
			var c: Array = cars[i]
			var pos := to_map(float(c[0]), float(c[1]))
			if i == 0:
				draw_circle(pos, 6.0, Color.WHITE)
				draw_circle(pos, 4.2, Kit.ACCENT)
			else:
				draw_circle(pos, 5.0, Color.WHITE)
				draw_circle(pos, 3.8, colors[i] if i < colors.size() else Color.RED)

func setup_map(track, colors_in: Array, alt = null) -> void:
	minimap = StageMap.new()
	add_child(minimap)
	move_child(minimap, 3)
	minimap.position = Vector2(14, 150)
	minimap.setup_track(track, colors_in, alt)

# ───────────────────────── durante la etapa ─────────────────────────
func set_info(stage_txt: String, t: float, left_m: float) -> void:
	stage_l.text = stage_txt
	time_l.text = Kit.fmt_time(t)
	if left_m < 1000.0:
		dist_l.text = "⛽ %d m" % int(maxf(left_m, 0.0))
	else:
		dist_l.text = "⛽ %.1f km" % (left_m / 1000.0)

func set_gap(gap: float, rival_col: Color, name: String, gap2 := 0.0, col2 := Color(0, 0, 0, 0)) -> void:
	var gb: GapBar = gap_box
	gb.gap = gap
	gb.col = rival_col
	gb.gap2 = gap2
	gb.col2 = col2
	gb.queue_redraw()
	if gap > 1.0:
		gap_l.text = "%s · %d m adelante" % [name, int(gap)]
		gap_l.add_theme_color_override("font_color", Color(1.0, 0.75, 0.6))
	elif gap < -1.0:
		gap_l.text = "¡Vas primero! · %d m de ventaja" % int(-gap)
		gap_l.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	else:
		gap_l.text = "¡Lado a lado con %s!" % name
		gap_l.add_theme_color_override("font_color", Kit.GOLD)

func set_damage(d: Dictionary) -> void:
	var di: DamageIcon = dmg
	di.d = d
	di.queue_redraw()

func set_cars(list: Array) -> void:
	if minimap != null:
		minimap.set_cars(list)

func show_race_hud(on: bool) -> void:
	info.visible = on
	gap_box.visible = on
	gap_l.visible = on
	dmg.visible = on
	if minimap != null:
		minimap.visible = on
	if not on:
		prompt.visible = false

func show_prompt(text: String) -> void:
	prompt_l.text = text
	prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func big(t: String, sub := "", dur := 2.4, color := Color.WHITE) -> void:
	big_l.text = t
	big_l.add_theme_color_override("font_color", color)
	sub_l.text = sub
	big_t = dur

func toast(t: String) -> void:
	toast_l.text = t
	toast_t = 2.6

func cine(on: bool) -> void:
	bars_on = on

func fade_to(a: float) -> void:
	fade_target = a

func _process(dt: float) -> void:
	bars_k = move_toward(bars_k, 1.0 if bars_on else 0.0, dt * 2.5)
	var h := get_viewport_rect().size.y * 0.11 * bars_k
	(bars[0] as ColorRect).offset_bottom = h
	(bars[1] as ColorRect).offset_top = -h
	fade.color.a = move_toward(fade.color.a, fade_target, dt * 1.8)
	if big_t > 0.0:
		big_t -= dt
		var a := clampf(big_t / 0.5, 0.0, 1.0)
		big_l.modulate.a = a
		sub_l.modulate.a = a
		if big_t <= 0.0:
			big_l.text = ""
			sub_l.text = ""
	if toast_t > 0.0:
		toast_t -= dt
		toast_l.modulate.a = clampf(toast_t / 0.5, 0.0, 1.0)
		if toast_t <= 0.0:
			toast_l.text = ""

# ───────────────────────── pantallas completas ─────────────────────────
func clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Panel grande a la izquierda (se ve la escena a la derecha). Devuelve el contenedor del cuerpo.
func _panel(title: String, wide := 0.56) -> VBoxContainer:
	clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var p := Kit.panel(16)
	p.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p.anchor_right = wide
	p.offset_left = 16
	p.offset_top = 16
	p.offset_bottom = -16
	p.offset_right = 0
	overlay.add_child(p)
	var col := Kit.vbox(10)
	p.add_child(col)
	if title != "":
		col.add_child(Kit.label(title, 30, Kit.ACCENT))
	var sc := TouchScroll.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(sc)
	var body := Kit.vbox(10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(body)
	return body

func _text(body: VBoxContainer, t: String, size := 19, col := Kit.TEXT) -> Label:
	var l := Kit.label(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 380
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(l)
	return l

func _row_buttons(body: VBoxContainer, items: Array) -> void:
	var h := Kit.hbox(10)
	body.add_child(h)
	for it in items:
		var b := Kit.button(str(it[0]), func(): _pick(str(it[1])), it.size() > 2 and it[2] == true, 21, Vector2(0, 58))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)

## Páginas de la explicación inicial (page 0..4)
func show_intro_page(page: int, n_pages: int) -> void:
	var body := _panel("", 0.62)
	match page:
		0:
			body.add_child(Kit.label("DREAM RACING", 46, Kit.ACCENT))
			body.add_child(Kit.label("La Ruta de los Sueños", 28, Kit.GOLD))
			_text(body, "La carrera de los sueños: una sola ruta larguísima, de punta a punta, del pueblo de Villa Aurora hasta la Cumbre de los Sueños. Asfalto, campos de girasol, un río, la sierra, túneles, una ciudad, tierra, una cantera con su mina y al final la nieve.")
			_text(body, "%d etapas · unos %d km de ruta · más de una hora de manejo de punta a punta (con reintentos, entre 2 y 3 horas)." % [AdvRoute.STAGES.size(), int(_route_km())], 19, Kit.MUTED)
		1:
			body.add_child(Kit.label("CÓMO SE JUEGA", 32, Kit.ACCENT))
			_text(body, "• En cada etapa hay un rival adelante tuyo. Tenés que pasarlo y llegar primero a la próxima estación de servicio.")
			_text(body, "• El rival maneja a tu ritmo: si vas con cuidado, él también; si apretás al límite, él aprieta. Si te pasa, va a pelear por recuperar el puesto, pero nunca te choca a propósito.")
			_text(body, "• Si él llega primero, repetís la etapa desde la estación anterior.")
			_text(body, "• Al final te esperan dos jefes súper rápidos.")
		2:
			body.add_child(Kit.label("ESTACIONES Y TALLERES", 32, Kit.ACCENT))
			_text(body, "⛽ Las estaciones de servicio son los puntos de guardado: el auto entra solo, carga combustible y antes de salir podés leer la guía de la próxima etapa, ajustar el auto y gastar tus puntos de habilidad.")
			_text(body, "🔧 En el camino hay talleres. Un cartel te avisa antes: podés INGRESAR o SEGUIR. Entrar y salir no cuesta nada, pero cada reparación lleva tiempo… y el rival no te espera.")
			_text(body, "💥 Los golpes contra el guardarraíl o el rival dañan el auto: menos potencia (motor), tira hacia un lado (dirección) o menos agarre (suspensión).")
		3:
			body.add_child(Kit.label("TU AUTO Y TUS HABILIDADES", 32, Kit.ACCENT))
			_text(body, "Manejás el DR Bisonte XR, el auto del equipo Dream Racing, con su pintura negra de campaña. Al terminar la aventura queda en tu garaje.")
			_text(body, "Cada etapa ganada te da %d puntos para el árbol de habilidades: Curvas, Aceleración, Frenada, Control y Resistencia (hasta nivel 5 cada una)." % AdvData.POINTS_PER_STAGE)
			_text(body, "La aventura es SIMULACIÓN TOTAL, con un poco de ayuda: ABS y algo de control de tracción y estabilidad. Las ayudas se pueden cambiar en Opciones.", 19, Kit.GOLD)
			_text(body, "Cámaras: tercera persona, piloto (adentro) y capó. Cambialas con el botón de la cámara.", 18, Kit.MUTED)
		4:
			body.add_child(Kit.label("EL MAPA", 32, Kit.ACCENT))
			var mp := RouteMap.new()
			mp.custom_minimum_size = Vector2(520, 250)
			body.add_child(mp)
			_text(body, "Cada punto es una estación de servicio. Las etapas ganadas quedan en verde.", 17, Kit.MUTED)
	var nav := []
	if page > 0:
		nav.append(["← ATRÁS", "intro_prev"])
	nav.append(["SIGUIENTE ▶" if page < n_pages - 1 else "▶ COMENZAR", "intro_next", true])
	_row_buttons(body, nav)

func _route_km() -> float:
	var R = AdvRoute.get_route()
	return float(int(R.stations[R.stations.size() - 1]) - int(R.stations[0])) * AdvRoute.DS / 1000.0

## Mapa de toda la ruta con las estaciones (la etapa actual en naranja). Se gira para que la ruta quede acostada y
## aproveche el ancho; cada etapa con el color de su paisaje.
class RouteMap extends Control:
	var cur := 0
	var done := 0
	const BIOME_COL := [Color(0.85, 0.85, 0.8), Color(0.85, 0.78, 0.35), Color(0.35, 0.7, 0.4), Color(0.65, 0.6, 0.55), Color(0.85, 0.45, 0.3), Color(0.92, 0.95, 1.0), Color(0.8, 0.88, 0.98)]
	func _draw() -> void:
		var R = AdvRoute.get_route()
		var i0: int = R.stations[0]
		var i1: int = R.stations[R.stations.size() - 1]
		var ang := atan2(-(R.z[i1] - R.z[i0]), R.x[i1] - R.x[i0])
		var ca := cos(-ang)
		var sa := sin(-ang)
		var rot := func(i: int) -> Vector2:
			var q := Vector2(R.x[i] - R.x[i0], -(R.z[i] - R.z[i0]))
			return Vector2(q.x * ca - q.y * sa, q.x * sa + q.y * ca)
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for i in range(i0, i1, 20):
			var q: Vector2 = rot.call(i)
			lo = lo.min(q)
			hi = hi.max(q)
		var sz := hi - lo
		var k := minf((size.x - 40.0) / maxf(sz.x, 1.0), (size.y - 40.0) / maxf(sz.y, 1.0))
		var off := (size - sz * k) * 0.5
		var to_map := func(i: int) -> Vector2: return ((rot.call(i) as Vector2) - lo) * k + off
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.12, 0.85), true)
		for si in R.stations.size() - 1:
			var a: int = R.stations[si]
			var b: int = R.stations[si + 1]
			var pts := PackedVector2Array()
			for i in range(a, b + 1, 12):
				pts.append(to_map.call(i))
			pts.append(to_map.call(b))
			draw_polyline(pts, Color(0, 0, 0, 0.55), 9.0, true)
			var bc: Color = BIOME_COL[int(R.biome[(a + b) / 2])]
			draw_polyline(pts, bc.darkened(0.35) if si > done else bc, 5.0, true)
			if si == cur:
				draw_polyline(pts, Kit.ACCENT, 2.5, true)
			elif si < done:
				draw_polyline(pts, Color(0.25, 0.85, 0.5), 2.0, true)
		for si in R.stations.size():
			var p: Vector2 = to_map.call(int(R.stations[si]))
			draw_circle(p, 7.5, Color(0, 0, 0, 0.75))
			draw_circle(p, 5.5, Color(0.25, 0.85, 0.5) if si <= done else Color.WHITE)
			draw_string(ThemeDB.fallback_font, p + Vector2(-4, -11 if si % 2 == 0 else 22), "⛽" if si == 0 else str(si), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))

## Antes de salir de la estación: la etapa que viene y el rival
func show_brief(stage: int, rival: Dictionary, retry: bool) -> void:
	var S: Dictionary = AdvRoute.STAGES[stage]
	var body := _panel("ETAPA %d DE %d" % [stage + 1, AdvRoute.STAGES.size()], 0.56)
	body.add_child(Kit.label(str(S["name"]), 34, Kit.TEXT))
	body.add_child(Kit.label(str(S["sub"]), 20, Kit.MUTED))
	var R = AdvRoute.get_route()
	_text(body, "%.1f km hasta la próxima estación." % (R.stage_length(stage) / 1000.0), 18, Kit.MUTED)
	var rp := Kit.panel(10, Kit.PANEL2)
	body.add_child(rp)
	var rv := Kit.vbox(4)
	rp.add_child(rv)
	rv.add_child(Kit.label("RIVAL: " + str(rival["name"]) + ("   👑 JEFE" if rival.get("boss", false) else ""), 22, Kit.GOLD))
	var bio := Kit.label(str(rival.get("bio", "")), 17, Kit.MUTED)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.custom_minimum_size.x = 360
	rv.add_child(bio)
	if S.has("rival2"):
		rv.add_child(Kit.label("y también: " + str(S["rival2"]["name"]) + "  👑", 20, Kit.GOLD))
	_text(body, "💡 " + str(S["tip"]), 18)
	if retry:
		_text(body, "Intento %d. ¡Esta vez se lo ganás!" % 2, 18, Kit.ACCENT)
	_row_buttons(body, [["▶ SALIR DE LA ESTACIÓN", "go", true], ["⚙ AJUSTE", "tune"], ["✕ SALIR", "quit"]])

## Estación de servicio al llegar: resumen, guía, ajuste, habilidades
func show_station(tab: String, data: Dictionary, st: Dictionary) -> void:
	var stage: int = data["stage"]
	var last := stage >= AdvRoute.STAGES.size() - 1
	var body := _panel("⛽ " + str(data.get("station", "ESTACIÓN")), 0.6)
	var tabs := Kit.hbox(6)
	body.add_child(tabs)
	for t in [["sum", "ETAPA"], ["guide", "GUÍA"], ["tune", "AJUSTE"], ["skills", "HABILIDADES (%d)" % int(st["points"])]]:
		var tb := Kit.button(str(t[1]), func(): _pick("tab_" + str(t[0])), tab == t[0], 17, Vector2(0, 46))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tb)
	match tab:
		"sum":
			body.add_child(Kit.label("¡ETAPA %d SUPERADA!" % (stage + 1), 30, Kit.GREEN))
			body.add_child(Kit.label(str(AdvRoute.STAGES[stage]["name"]), 22, Kit.TEXT))
			var g := GridContainer.new()
			g.columns = 2
			g.add_theme_constant_override("h_separation", 24)
			body.add_child(g)
			for kv in [["Tiempo", Kit.fmt_time(float(data["time"]))], ["Ventaja sobre el rival", "%d m" % int(data["margin"])], ["Velocidad máxima", "%d km/h" % int(data["vmax"])], ["Puntos de habilidad", "+%d" % AdvData.POINTS_PER_STAGE], ["Avance guardado", "✔"]]:
				g.add_child(Kit.label(str(kv[0]), 19, Kit.MUTED))
				g.add_child(Kit.label(str(kv[1]), 19, Kit.TEXT))
			var d: Dictionary = st["damage"]
			var dm := maxf(float(d["motor"]), maxf(float(d["dir"]), float(d["susp"])))
			if dm > 0.05:
				_text(body, "🔧 El auto tiene daño (motor %d %% · dirección %d %% · suspensión %d %%). Se arregla en los talleres del camino." % [int(float(d["motor"]) * 100.0), int(float(d["dir"]) * 100.0), int(float(d["susp"]) * 100.0)], 17, Kit.GOLD)
		"guide":
			if last:
				_text(body, "¡Esta fue la última estación!", 20)
			else:
				var G: Dictionary = AdvData.GUIDES[mini(stage + 1, AdvData.GUIDES.size() - 1)]
				body.add_child(Kit.label(str(G["title"]), 26, Kit.GOLD))
				_text(body, str(G["text"]), 19)
				var nx: Dictionary = AdvRoute.STAGES[stage + 1]
				_text(body, "Próxima etapa: %s — %s" % [nx["name"], nx["sub"]], 17, Kit.MUTED)
				_text(body, "Ajuste sugerido: " + str(nx["setup"]), 17, Kit.MUTED)
				body.add_child(Kit.button("✔ APLICAR EL AJUSTE RECOMENDADO", func(): _pick("apply_guide"), true, 19, Vector2(0, 54)))
		"tune":
			tune_page(body, st)
		"skills":
			skills_page(body, st)
	var capped := (stage + 1) >= int(data.get("limit", 99)) and not last
	if capped:
		_text(body, "🚧 Hasta acá llega la primera parte de la aventura. Las próximas etapas llegan con una actualización; tu avance queda guardado.", 18, Kit.GOLD)
		_row_buttons(body, [["💾 GUARDAR Y SALIR", "save_quit", true]])
	elif last:
		_row_buttons(body, [["🏆 TERMINAR LA AVENTURA", "finish", true]])
	else:
		_row_buttons(body, [["▶ CONTINUAR A LA ETAPA %d" % (stage + 2), "next", true], ["💾 GUARDAR Y SALIR", "save_quit"]])

const TUNE_KEYS := ["split", "pressF", "pressR", "height", "springF", "springR", "bump", "rebound", "arbF", "arbR", "bias", "lsd", "final"]
const TIRES := ["street", "sport", "slick", "gravel", "mud"]

func tune_page(body: VBoxContainer, st: Dictionary) -> void:
	body.add_child(Kit.label("NEUMÁTICOS", 16, Kit.MUTED))
	var th := Kit.hbox(6)
	body.add_child(th)
	for tid in TIRES:
		var T: Dictionary = CarBuild.tire(tid)
		var tb := Kit.button(str(T["icon"]) + " " + str(T["n"]), func(): _pick("tire_" + tid), str(st["tires"]) == tid, 15, Vector2(0, 44))
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		th.add_child(tb)
	var Tn: Dictionary = CarBuild.tire(str(st["tires"]))
	_text(body, str(Tn["info"]), 15, Kit.MUTED)
	var items := {}
	for g in CarBuild.catalog()["tune"]:
		for it in g["items"]:
			items[str(it["k"])] = it
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))[AdvData.CAR]
	var defs: Dictionary = CarBuild.default_tune(base)
	var tune: Dictionary = st["tune"]
	for k in TUNE_KEYS:
		if not items.has(k):
			continue
		var it: Dictionary = items[k]
		var v := float(tune.get(k, defs.get(k, it["def"])))
		var row := Kit.vbox(2)
		body.add_child(row)
		var top := Kit.hbox(8)
		row.add_child(top)
		var nl := Kit.label(str(it["n"]), 18, Kit.TEXT)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(nl)
		var vl := Kit.label("%s %s" % [_fmt(v, float(it["step"])), str(it["u"])], 18, Kit.GOLD)
		top.add_child(vl)
		var sl := HSlider.new()
		sl.min_value = float(it["min"])
		sl.max_value = float(it["max"])
		sl.step = float(it["step"])
		sl.value = v
		sl.custom_minimum_size = Vector2(0, 34)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = k
		var unit := str(it["u"])
		var stp := float(it["step"])
		sl.value_changed.connect(func(x: float) -> void:
			tune[key] = x
			vl.text = "%s %s" % [_fmt(x, stp), unit])
		row.add_child(sl)
		var il := Kit.label(str(it["info"]), 14, Kit.MUTED)
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		il.custom_minimum_size.x = 360
		row.add_child(il)
	body.add_child(Kit.button("↺ VOLVER AL AJUSTE DE FÁBRICA", func(): _pick("tune_reset"), false, 17, Vector2(0, 48)))

func _fmt(v: float, step: float) -> String:
	return ("%.1f" % v) if step < 1.0 else str(int(round(v)))

func skills_page(body: VBoxContainer, st: Dictionary) -> void:
	body.add_child(Kit.label("PUNTOS DISPONIBLES: %d" % int(st["points"]), 24, Kit.GOLD))
	_text(body, "Cada nivel cuesta tantos puntos como su número (nivel 1 = 1 punto … nivel 5 = 5 puntos). Ganás %d puntos por etapa." % AdvData.POINTS_PER_STAGE, 16, Kit.MUTED)
	var sk: Dictionary = st["skills"]
	for S in AdvData.SKILLS:
		var id := str(S["id"])
		var lvl := int(sk.get(id, 0))
		var p := Kit.panel(10, Kit.PANEL2)
		body.add_child(p)
		var row := Kit.hbox(12)
		p.add_child(row)
		row.add_child(Kit.label(str(S["icon"]), 34))
		var col := Kit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Kit.label("%s  %s" % [S["name"], "●".repeat(lvl) + "○".repeat(AdvData.MAX_LEVEL - lvl)], 21, Kit.TEXT))
		var dl := Kit.label(str(S["desc"]) + "\n" + str(S["per"]), 15, Kit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 260
		col.add_child(dl)
		if lvl < AdvData.MAX_LEVEL:
			var c := AdvData.cost(lvl + 1)
			var b := Kit.button("+1 (%d pt)" % c, func(): _pick("skill_" + id), int(st["points"]) >= c, 17, Vector2(130, 50))
			b.disabled = int(st["points"]) < c
			row.add_child(b)
		else:
			row.add_child(Kit.label("MÁX", 18, Kit.GREEN))

## Taller: daño por parte y reparaciones (cada una lleva segundos reales: el rival sigue corriendo)
func show_workshop(name: String, st: Dictionary, busy: String, prog: float, gap: float) -> void:
	var body := _panel("🔧 " + name.to_upper(), 0.56)
	_text(body, "Cada reparación lleva tiempo y el rival sigue corriendo. Entrar y salir no cuesta nada.", 17, Kit.MUTED)
	if gap > 0.0:
		_text(body, "El rival te lleva %d m." % int(gap), 18, Color(1.0, 0.75, 0.6))
	else:
		_text(body, "Le llevás %d m al rival." % int(-gap), 18, Kit.GREEN)
	var d: Dictionary = st["damage"]
	var parts := [["motor", "⚙ Motor", "Menos potencia", 9.0], ["dir", "🎯 Dirección", "El auto tira hacia un costado", 6.0], ["susp", "🔩 Suspensión", "Menos agarre en las curvas", 7.0]]
	for P in parts:
		var id := str(P[0])
		var v := float(d[id])
		var p := Kit.panel(10, Kit.PANEL2)
		body.add_child(p)
		var row := Kit.hbox(10)
		p.add_child(row)
		var col := Kit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Kit.label("%s  ·  %d %%" % [P[1], int(v * 100.0)], 21, Kit.GREEN if v < 0.05 else (Kit.GOLD if v < 0.4 else Kit.RED)))
		col.add_child(Kit.label(str(P[2]), 15, Kit.MUTED))
		if busy == id:
			var bar := ProgressBar.new()
			bar.value = prog * 100.0
			bar.custom_minimum_size = Vector2(170, 26)
			bar.show_percentage = false
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.add_theme_stylebox_override("background", Kit.box(Color(1, 1, 1, 0.10), 8))
			bar.add_theme_stylebox_override("fill", Kit.box(Kit.ACCENT, 8))
			row.add_child(bar)
		elif v >= 0.05:
			var secs := ceilf(float(P[3]) * v / 0.5 + 2.0)
			var b := Kit.button("REPARAR (%d s)" % int(secs), func(): _pick("fix_" + id), true, 17, Vector2(170, 50))
			b.disabled = busy != ""
			row.add_child(b)
		else:
			row.add_child(Kit.label("OK ✔", 18, Kit.GREEN))
	var ex := Kit.button("▶ SALIR DEL TALLER", func(): _pick("ws_out"), busy == "", 21, Vector2(0, 58))
	ex.disabled = busy != ""
	body.add_child(ex)

func show_lost(rival_name: String) -> void:
	var body := _panel("", 0.5)
	body.add_child(Kit.label("LLEGÓ PRIMERO", 40, Kit.RED))
	body.add_child(Kit.label(rival_name, 28, Kit.TEXT))
	_text(body, "Para seguir con la aventura tenés que llegar a la estación antes que tu rival. Probá otra trazada, revisá el ajuste del auto o usá tus puntos de habilidad.", 19)
	_row_buttons(body, [["↺ REINTENTAR LA ETAPA", "retry", true], ["✕ SALIR", "quit"]])

func show_final(data: Dictionary) -> void:
	var body := _panel("", 0.62)
	body.add_child(Kit.label("🏆 ¡LO LOGRASTE!", 44, Kit.GOLD))
	body.add_child(Kit.label("Completaste la Ruta de los Sueños", 28, Kit.TEXT))
	_text(body, "Le ganaste a La Sombra y al Lobo Blanco en la cumbre. El DR Bisonte XR, con su pintura negra de campaña, ya está en tu garaje.", 20)
	_text(body, "Premio: %s" % Kit.fmt_cr(float(data.get("reward", 50000))), 22, Kit.GREEN)
	_row_buttons(body, [["VOLVER AL MENÚ", "quit", true]])
