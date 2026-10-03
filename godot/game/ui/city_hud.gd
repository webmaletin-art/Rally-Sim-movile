extends Control
## HUD de Puerto Aurelia: minimapa que gira con el auto (arriba siempre es hacia donde mirás), mapa grande fijo (norte arriba) que se abre tocando el minimapa,
## nombre de la calle y cuadra, y el GPS hasta un lugar (se elige tocando el mapa grande). Todo se dibuja con líneas a partir de las calles de CityLayout (nada de imágenes).

const Kit := preload("res://game/ui/ui_kit.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CityGps := preload("res://game/city/city_gps.gd")

const MINI := 176.0 # lado del minimapa (px)
const MINI_R := 230.0 # metros que muestra de radio
const KIND_COL := {"dealer": Color(0.35, 0.65, 1.0), "garage": Color(1.0, 0.6, 0.15), "view": Color(1.0, 0.88, 0.3)}
const KIND_ICON := {"dealer": "🚗", "garage": "🔧", "view": "⛰"}

var city
var track
var gps
var segs: Array = [] # cada tramo: {box: Rect2, pts: PackedVector2Array, hw: float, kind: String}
var car_pos := Vector2.ZERO
var heading := 0.0 # yaw del auto (adelante = (sin, cos) en x, z)
var route := PackedVector2Array()
var route_len := 0.0
var route_name := ""
var dest := Vector2.ZERO
var has_dest := false
var big := false
var street_l: Label
var gps_l: Label
var _t := 0.0
var _off_t := 0.0
var _mini: Control
var _big: Control
var _toast_cb: Callable

func setup(p_track, toast_cb: Callable) -> void:
	track = p_track
	city = track.city
	_toast_cb = toast_cb
	gps = CityGps.new(city)
	for rd in city.roads:
		var pts: PackedVector3Array = rd["pts"]
		var step := 3
		var i := 0
		while i < pts.size():
			var seg := PackedVector2Array()
			var j := i
			while j < mini(i + 20 * step + 1, pts.size()):
				seg.append(Vector2(pts[j].x, pts[j].z))
				j += step
			if seg.size() < 2 and j < pts.size() + step:
				seg.append(Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z))
			var lo := seg[0]
			var hi := seg[0]
			for q in seg:
				lo = lo.min(q)
				hi = hi.max(q)
			segs.append({"box": Rect2(lo, hi - lo).grow(12.0), "pts": seg, "hw": float(rd["hw"]), "kind": str(rd["kind"])})
			i += 20 * step
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini = MapView.new()
	(_mini as MapView).hud = self
	(_mini as MapView).big = false
	_mini.position = Vector2(14.0, 100.0)
	_mini.custom_minimum_size = Vector2(MINI, MINI)
	_mini.size = Vector2(MINI, MINI)
	_mini.clip_contents = true
	_mini.mouse_filter = Control.MOUSE_FILTER_STOP
	_mini.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
			_set_big(true))
	add_child(_mini)
	street_l = Kit.label("", 20, Color.WHITE)
	street_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	street_l.add_theme_constant_override("outline_size", 7)
	street_l.position = Vector2(14.0 + MINI + 8.0, 104.0)
	street_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(street_l)
	gps_l = Kit.label("", 18, Color(1.0, 0.8, 0.3))
	gps_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	gps_l.add_theme_constant_override("outline_size", 7)
	gps_l.position = Vector2(14.0 + MINI + 8.0, 134.0)
	gps_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gps_l)
	_build_big()

func _build_big() -> void:
	_big = Control.new()
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_big.mouse_filter = Control.MOUSE_FILTER_STOP
	_big.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.9)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(bg)
	var mv := MapView.new()
	mv.hud = self
	mv.big = true
	mv.name = "map"
	mv.clip_contents = true
	mv.mouse_filter = Control.MOUSE_FILTER_STOP
	mv.gui_input.connect(_big_input)
	_big.add_child(mv)
	var close := Kit.button(Tr.t("✕ CERRAR"), func() -> void: _set_big(false), true, 22, Vector2(170, 56))
	close.position = Vector2(16, 12)
	_big.add_child(close)
	var clear := Kit.button(Tr.t("QUITAR GPS"), func() -> void: _clear_dest(), false, 20, Vector2(190, 56))
	clear.position = Vector2(200, 12)
	_big.add_child(clear)
	var hint := Kit.label(Tr.t("Tocá un lugar del mapa para ir con el GPS"), 18, Kit.MUTED)
	hint.position = Vector2(16, 76)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big.add_child(hint)
	add_child(_big)
	_layout_big()

func _layout_big() -> void:
	var vs := get_viewport_rect().size
	var mv: Control = _big.get_node("map")
	var side := minf(vs.x * 0.62, vs.y - 24.0)
	mv.size = Vector2(side, side)
	mv.position = Vector2(vs.x - side - 14.0, (vs.y - side) * 0.5)

func _set_big(on: bool) -> void:
	big = on
	_big.visible = on
	if on:
		_layout_big()
		(_big.get_node("map") as Control).queue_redraw()

func _big_input(e: InputEvent) -> void:
	var p := Vector2.ZERO
	if e is InputEventMouseButton and e.pressed:
		p = e.position
	elif e is InputEventScreenTouch and e.pressed:
		p = e.position
	else:
		return
	var mv: MapView = _big.get_node("map")
	var w := mv.to_world(p)
	# un lugar de la lista si el toque cae cerca
	var best := -1
	var bd := 34.0 / mv.scale_px()
	for i in city.pois.size():
		var d: float = (city.pois[i]["pos"] as Vector2).distance_to(w)
		if d < bd:
			bd = d
			best = i
	if best >= 0:
		set_dest(city.pois[best]["front"], str(city.pois[best]["name"]))
	else:
		set_dest(w, Tr.t("el punto elegido"))
	_set_big(false)

func set_dest(p: Vector2, nm: String) -> void:
	dest = p
	has_dest = true
	route_name = nm
	_reroute()
	if _toast_cb.is_valid():
		_toast_cb.call(Tr.t("📍 GPS: %s") % nm)

func _clear_dest() -> void:
	has_dest = false
	route = PackedVector2Array()
	gps_l.text = ""
	_mini.queue_redraw()
	(_big.get_node("map") as Control).queue_redraw()

func _reroute() -> void:
	var r: Dictionary = gps.route(car_pos, dest)
	route = r["pts"]
	route_len = float(r["len"])
	if route.is_empty():
		has_dest = false
		gps_l.text = Tr.t("GPS: no hay camino")

func update_hud(dt: float, car) -> void:
	car_pos = Vector2(car.phys.px, car.phys.pz)
	heading = car.phys.yaw
	_t += dt
	if _t < 0.06:
		return
	var step := _t
	_t = 0.0
	_mini.queue_redraw()
	if big:
		(_big.get_node("map") as Control).queue_redraw()
	var loc: Dictionary = city.locate(car_pos.x, car_pos.y)
	if int(loc["road"]) >= 0:
		street_l.text = "%s · %s %d" % [str(loc["name"]), Tr.t("cuadra"), int(loc["cuadra"])]
	else:
		street_l.text = Tr.t("Fuera de calle")
	if has_dest:
		_off_t += step
		_gps_text()
		var to_dest := car_pos.distance_to(dest)
		if to_dest < 28.0:
			if _toast_cb.is_valid():
				_toast_cb.call(Tr.t("🏁 ¡Llegaste a %s!") % route_name)
			_clear_dest()
			return
		if _off_t > 1.5 and _route_dist() > 45.0:
			_off_t = 0.0
			_reroute()

## distancia del auto al punto más cercano de la ruta
func _route_dist() -> float:
	var bd := 1e9
	for q in route:
		bd = minf(bd, q.distance_to(car_pos))
	return bd

func _gps_text() -> void:
	if route.size() < 2:
		return
	var bi := 0
	var bd := 1e9
	for i in route.size():
		var d := route[i].distance_to(car_pos)
		if d < bd:
			bd = d
			bi = i
	var left := 0.0
	for i in range(bi, route.size() - 1):
		left += route[i].distance_to(route[i + 1])
	# próxima curva: el primer cambio de rumbo grande más adelante
	var turn := ""
	var turn_d := 0.0
	var acc := 0.0
	var i := bi
	while i + 3 < route.size() and acc < 600.0:
		var a := (route[i + 1] - route[i]).normalized()
		var b := (route[i + 3] - route[i + 2]).normalized()
		var ang := rad_to_deg(a.angle_to(b))
		acc += route[i].distance_to(route[i + 1])
		if absf(ang) > 38.0:
			turn = Tr.t("↱ Doblá a la derecha") if ang > 0.0 else Tr.t("↰ Doblá a la izquierda")
			turn_d = acc
			break
		i += 1
	var dist_txt := ("%d m" % int(round(left / 10.0) * 10.0)) if left < 1000.0 else ("%.1f km" % (left / 1000.0))
	if turn != "":
		gps_l.text = "%s · %d m\n%s %s" % [turn, int(round(turn_d / 10.0) * 10.0), route_name, dist_txt]
	else:
		gps_l.text = "%s\n%s %s" % [Tr.t("Seguí derecho"), route_name, dist_txt]

## Un mapa: el chico gira con el auto y el grande es fijo con el norte arriba
class MapView extends Control:
	var hud
	var big := false

	func scale_px() -> float:
		if big:
			return minf(size.x, size.y) / 2600.0
		return size.x * 0.5 / MINI_R

	func _center_world() -> Vector2:
		return Vector2.ZERO if big else hud.car_pos

	## mundo → pantalla del control
	func _xf() -> Transform2D:
		var s := scale_px()
		var ctr := size * 0.5
		if big:
			return Transform2D(Vector2(s, 0.0), Vector2(0.0, s), ctr)
		var f := Vector2(sin(hud.heading), cos(hud.heading))
		var xa := Vector2(-f.y, -f.x) * s
		var ya := Vector2(f.x, -f.y) * s
		var cp: Vector2 = hud.car_pos
		return Transform2D(xa, ya, ctr - (xa * cp.x + ya * cp.y))

	func to_world(p: Vector2) -> Vector2:
		return _xf().affine_inverse() * p

	func _draw() -> void:
		if hud == null or hud.city == null:
			return
		var s := scale_px()
		var sz := size
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.10, 0.13, 0.17, 0.80) if not big else Color(0.12, 0.16, 0.20, 1.0), true)
		var xf := _xf()
		# el mar (al sur de la costa) en el mapa grande y en el chico
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var view_w := Rect2(to_world(Vector2.ZERO), Vector2.ZERO)
		for q in [Vector2(0, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(0, sz.y)]:
			view_w = view_w.expand(to_world(q))
		view_w = view_w.grow(6.0)
		draw_set_transform_matrix(xf)
		var sea := PackedVector2Array([Vector2(-5000.0, 1260.0), Vector2(5000.0, 1260.0), Vector2(5000.0, 5000.0), Vector2(-5000.0, 5000.0)])
		draw_colored_polygon(sea, Color(0.16, 0.34, 0.50, 0.9))
		# calles: primero un borde claro y encima el asfalto
		for pass_i in 2:
			for sg in hud.segs:
				if not view_w.intersects(sg["box"]):
					continue
				var hw: float = sg["hw"]
				var wpx := maxf(hw * 2.0 + (3.0 if pass_i == 0 else 0.0), (4.5 if big else 3.0) / s)
				if not big:
					wpx = maxf(wpx, 3.2 / s)
				var col := Color(0.92, 0.94, 0.97, 0.9) if pass_i == 0 else (Color(0.42, 0.46, 0.54) if str(sg["kind"]) in ["rural", "hill"] else Color(0.30, 0.34, 0.42))
				draw_polyline(sg["pts"], col, wpx if big else minf(wpx, 11.0 / s), false)
		if hud.has_dest and hud.route.size() > 1:
			draw_polyline(hud.route, Color(0.05, 0.12, 0.2, 0.9), 12.0 / s, false)
			draw_polyline(hud.route, Color(1.0, 0.72, 0.1), 7.0 / s, false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# lugares
		var f := ThemeDB.fallback_font
		for p in hud.city.pois:
			var sp: Vector2 = xf * (p["pos"] as Vector2)
			if not Rect2(Vector2.ZERO, sz).grow(12.0).has_point(sp):
				continue
			var col: Color = KIND_COL.get(str(p["kind"]), Color.WHITE)
			draw_circle(sp, 9.0 if big else 6.5, Color(0, 0, 0, 0.7))
			draw_circle(sp, 7.0 if big else 5.0, col)
			if big:
				draw_string(f, sp + Vector2(12.0, 6.0), str(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		for ex in hud.city.exits:
			var sp: Vector2 = xf * (ex["pos"] as Vector2)
			if Rect2(Vector2.ZERO, sz).grow(12.0).has_point(sp):
				draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(0.3, 0.9, 0.5))
				if big:
					draw_string(f, sp + Vector2(10.0, 5.0), str(ex["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 1.0, 0.7))
		if hud.has_dest:
			var dp: Vector2 = xf * (hud.dest as Vector2)
			if Rect2(Vector2.ZERO, sz).grow(12.0).has_point(dp):
				draw_circle(dp, 9.0, Color(1, 0.25, 0.2))
				draw_circle(dp, 4.0, Color.WHITE)
		# el auto: en el chico siempre en el centro mirando hacia arriba; en el grande en su lugar y rotado
		var me: Vector2 = xf * (hud.car_pos as Vector2)
		var fwd := Vector2(0.0, -1.0) # en el mapa grande: x al este, z al sur (en pantalla y crece hacia el sur)
		if big:
			fwd = Vector2(sin(hud.heading), cos(hud.heading))
		var rgt := Vector2(-fwd.y, fwd.x)
		var tri := PackedVector2Array([me + fwd * 11.0, me - fwd * 7.0 + rgt * 7.0, me - fwd * 3.0, me - fwd * 7.0 - rgt * 7.0])
		draw_colored_polygon(tri, Color(1.0, 0.5, 0.1))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color.WHITE, 1.6, true)
		draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, 0.35), false, 2.0)
		if not big:
			# la N del norte, girando con el mapa
			var nrm: Vector2 = xf * (hud.car_pos + Vector2(0.0, -MINI_R * 0.8))
			draw_string(f, nrm - Vector2(5.0, -6.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.45, 0.4))
