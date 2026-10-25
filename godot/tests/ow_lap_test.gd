## Vueltas de un circuito del mundo abierto (city/city_events.gd): el avance del jugador sobre un recorrido en lazo pasa de la última vuelta a la siguiente.
## Antes la búsqueda se quedaba pegada al último tramo y la vuelta nunca se contaba (reporte del dueño, 25/10/2026).
## Uso: godot --headless --path godot --script res://tests/ow_lap_test.gd
extends SceneTree

const CityEvents := preload("res://game/city/city_events.gd")

var _fails := 0

func _ok(c: bool, m: String) -> void:
	print(("OK    " if c else "FALLA ") + m)
	if not c:
		_fails += 1

func _init() -> void:
	# lazo cuadrado de 200 m de lado, 10 m por tramo, cerrado (el último punto es el primero)
	var pts := PackedVector2Array()
	var corners := [Vector2(0, 0), Vector2(200, 0), Vector2(200, 200), Vector2(0, 200), Vector2(0, 0)]
	for c in 4:
		for k in 20:
			pts.append((corners[c] as Vector2).lerp(corners[c + 1], float(k) / 20.0))
	pts.append(Vector2(0, 0))
	var ce := CityEvents.new()
	var lap_len := 800.0
	ce.cur = {"pts": pts, "type": "circuito", "laps": 3, "lap_len": lap_len}
	ce._cum = PackedFloat32Array([0.0])
	for k in range(1, pts.size()):
		ce._cum.append(ce._cum[k - 1] + pts[k - 1].distance_to(pts[k]))
	var arc := 0.0
	var pi := 0
	var laps_seen := 0
	var s := 0.0
	var step := 5.0
	var prev_lap := 0
	while s < lap_len * 3.0 - 4.0:
		s += step
		var q := _at(pts, ce._cum, fmod(s, lap_len))
		var proj: Array = ce._project(q + Vector2(1.5, 0), pi, true)
		pi = int(proj[0])
		var lap_base := floorf(arc / lap_len) * lap_len
		var a := lap_base + float(proj[1])
		if a < arc - lap_len * 0.5:
			a += lap_len
		if a > arc and a - arc < 120.0:
			arc = a
		var lap := int(arc / lap_len)
		if lap > prev_lap:
			laps_seen += 1
			prev_lap = lap
	_ok(laps_seen == 3, "pasó la línea 3 veces (2 vueltas completas y la meta) en 3 vueltas (vio %d)" % laps_seen)
	_ok(arc >= lap_len * 3.0 - 12.0, "el avance llega al final de la 3.ª vuelta (arc %.0f de %.0f)" % [arc, lap_len * 3.0])
	print("TODO OK" if _fails == 0 else "HAY FALLAS: %d" % _fails)
	quit(_fails)

func _at(pts: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	for i in range(1, cum.size()):
		if cum[i] >= d:
			return pts[i - 1].lerp(pts[i], (d - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.01))
	return pts[pts.size() - 1]
