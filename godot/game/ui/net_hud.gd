extends Control
## HUD de la Red de rutas: minimapa que gira con el auto (arriba = hacia donde mirás) con las calles del entorno, las estaciones, el rival y una flecha cuando se sale del mapa;
## nombre de la estación más cercana y botón «↺ ESTACIÓN» (el auto vuelve a aparecer en la estación más cercana). Todo se dibuja con líneas a partir de NetData.

signal respawn_pressed

const Kit := preload("res://game/ui/ui_kit.gd")

const MINI := 176.0 # lado del minimapa (px)
const MINI_R := 420.0 # metros que muestra de radio (la red es de rutas largas)
const SURF_COL := [Color(0.80, 0.82, 0.86), Color(0.78, 0.60, 0.38), Color(0.66, 0.62, 0.56), Color(0.55, 0.40, 0.28), Color(0.90, 0.80, 0.55)]

var track
var net
var session
var car_pos := Vector2.ZERO
var heading := 0.0
var rival := Vector2(INF, INF)
var st_l: Label
var _mini: Control
var _btn: Button
var _t := 0.0

class MapView extends Control:
	var hud
	func _draw() -> void:
		hud._draw_mini(self)

func setup(p_track, p_session) -> void:
	track = p_track
	net = track.net
	session = p_session
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini = MapView.new()
	(_mini as MapView).hud = self
	_mini.position = Vector2(14.0, 100.0)
	_mini.size = Vector2(MINI, MINI)
	_mini.clip_contents = true
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mini)
	st_l = Kit.label("", 17, Color(1.0, 0.85, 0.35))
	st_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	st_l.add_theme_constant_override("outline_size", 6)
	st_l.position = Vector2(14.0 + MINI + 8.0, 104.0)
	st_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(st_l)
	_btn = Kit.button(tr("↺ ESTACIÓN"), func() -> void: respawn_pressed.emit(), false, 18, Vector2(150, 44))
	_btn.position = Vector2(14.0 + MINI + 8.0, 134.0)
	add_child(_btn)

func update_hud(dt: float, car) -> void:
	car_pos = Vector2(car.snap.px, car.snap.pz)
	heading = car.phys.yaw
	_t += dt
	if _t < 0.1:
		return
	_t = 0.0
	if session != null and session.near_station >= 0:
		var st: Dictionary = net.stations[session.near_station]
		var d: float = session.near_station_d
		st_l.text = "⛽ %s · %s" % [tr(str(st["name"])), ("%d m" % int(d)) if d < 1000.0 else ("%.1f km" % (d / 1000.0))]
	_mini.queue_redraw()

## rival en el mapa (la carrera lo pone cada cuadro)
func set_rival(p: Vector2) -> void:
	rival = p

func _to_map(w: Vector2) -> Vector2:
	# mundo → pixel: el auto en el centro, adelante = arriba
	var d := w - car_pos
	var fx := sin(heading)
	var fz := cos(heading)
	var fwd := d.x * fx + d.y * fz
	var rgt := d.x * fz - d.y * fx # derecha del auto
	var k := (MINI * 0.5) / MINI_R
	return Vector2(MINI * 0.5 + rgt * k, MINI * 0.5 - fwd * k)

func _draw_mini(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI, MINI)), Color(0.05, 0.07, 0.10, 0.78))
	if net == null:
		return
	var cx0 := int(floor((car_pos.x - MINI_R) / net.CELL))
	var cx1 := int(floor((car_pos.x + MINI_R) / net.CELL))
	var cz0 := int(floor((car_pos.y - MINI_R) / net.CELL))
	var cz1 := int(floor((car_pos.y + MINI_R) / net.CELL))
	var seen := {}
	for cx in range(cx0, cx1 + 1):
		for cz in range(cz0, cz1 + 1):
			var cell: PackedInt32Array = net.grid.get(Vector2i(cx, cz), PackedInt32Array())
			var j := 0
			while j < cell.size():
				var ei := cell[j]
				var si := cell[j + 1]
				j += 2
				var key := ei * 100000 + si
				if seen.has(key):
					continue
				seen[key] = true
				var pts: PackedVector2Array = net.e_pts[ei]
				if si + 1 >= pts.size():
					continue
				var a := _to_map(pts[si])
				var b := _to_map(pts[si + 1])
				var col: Color = SURF_COL[clampi(int(net.e_surf[ei]), 0, 4)]
				c.draw_line(a, b, Color(0, 0, 0, 0.7), 5.0 if net.e_w[ei] > 12.0 else 4.0)
				c.draw_line(a, b, col, 3.0 if net.e_w[ei] > 12.0 else 2.0)
	for st in net.stations:
		var q := _to_map(st["road"])
		if q.x > -8 and q.y > -8 and q.x < MINI + 8 and q.y < MINI + 8:
			c.draw_circle(q, 5.0, Color(1.0, 0.8, 0.2))
			c.draw_circle(q, 3.0, Color(0.15, 0.12, 0.02))
	if rival.x < 1e8:
		var rq := _to_map(rival)
		var cen := Vector2(MINI * 0.5, MINI * 0.5)
		var inside := rq.x > 6 and rq.y > 6 and rq.x < MINI - 6 and rq.y < MINI - 6
		if inside:
			c.draw_circle(rq, 5.5, Color(1.0, 0.25, 0.2))
			c.draw_arc(rq, 5.5, 0, TAU, 12, Color.WHITE, 1.5)
		else:
			var dir := (rq - cen).normalized()
			var edge := cen + dir * (MINI * 0.5 - 10.0)
			var n := Vector2(-dir.y, dir.x)
			c.draw_colored_polygon(PackedVector2Array([edge + dir * 8.0, edge - dir * 4.0 + n * 6.0, edge - dir * 4.0 - n * 6.0]), Color(1.0, 0.25, 0.2))
	# el auto: triángulo al centro
	var cc := Vector2(MINI * 0.5, MINI * 0.5)
	c.draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -9), cc + Vector2(-6, 7), cc + Vector2(6, 7)]), Color(0.3, 0.8, 1.0))
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(MINI, MINI)), Color(1, 1, 1, 0.35), false, 1.5)

func set_paused(on: bool) -> void:
	visible = not on
