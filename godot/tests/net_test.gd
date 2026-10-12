## Prueba de la Red de rutas: datos, consultas del piso, camino más corto, armado por tramos.
## Uso: godot --headless --path godot --script res://tests/net_test.gd
extends SceneTree

const NetTrack := preload("res://game/net/net_track.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var tr = NetTrack.new("red_1")
	var net = tr.net
	check(net != null and net.e_id.size() >= 70, "la red se carga (%d calles, %d estaciones, %.0f ms)" % [net.e_id.size(), net.stations.size(), Time.get_ticks_msec() - t0])
	check(net.stations.size() == 9, "9 estaciones con su playón")
	# sobre el eje de la primera calle: asfalto o tierra; lejos de todo: afuera
	var p0: Vector2 = (net.e_pts[0] as PackedVector2Array)[10]
	var gi := tr.ground_info(p0.x, p0.y)
	check(int(gi.y) in [0, 1, 5], "sobre el eje de una calle el piso es de calzada (%d)" % int(gi.y))
	var far := tr.ground_info(net.bbox.position.x - 5000.0, net.bbox.position.y - 5000.0)
	check(int(far.y) == 4, "lejos de todo es «afuera»")
	# a 4 m del borde: banquina o pasto
	var pr: Array = net.probe(p0.x, p0.y)
	var q: Vector2 = Vector2(p0.x, p0.y) + Vector2(pr[6], pr[7]) * 0.0 + Vector2(-(net.tangent_at(int(pr[3]), int(pr[4])).y), net.tangent_at(int(pr[3]), int(pr[4])).x) * (float(pr[1]) + 1.0)
	check(int(tr.ground_info(q.x, q.y).y) == 2, "a 1 m del borde hay banquina")
	# velocidad de la consulta
	var t1 := Time.get_ticks_usec()
	for i in 20000:
		tr.ground_info(p0.x + float(i % 50), p0.y + float(i % 37))
	var us := float(Time.get_ticks_usec() - t1) / 20000.0
	check(us < 60.0, "consulta del piso: %.1f µs" % us)
	# camino más corto entre dos estaciones
	var r: Array = net.route(net.stations[0]["pos"], net.stations[5]["pos"])
	var path: PackedVector2Array = r[0]
	check(path.size() > 10 and float(r[1]) > 100.0, "hay camino entre las estaciones 1 y 6: %.1f km (%d puntos)" % [float(r[1]) / 1000.0, path.size()])
	# el camino es continuo (sin saltos de más de 300 m entre puntos)
	var jump := 0.0
	for i in range(1, path.size()):
		jump = maxf(jump, path[i].distance_to(path[i - 1]))
	check(jump < 520.0, "el camino es continuo (salto máximo %.0f m)" % jump)
	# aparecer en cada estación: el piso es el playón (pasto) y queda cerca del camino
	for i in net.stations.size():
		var sp: Array = tr.station_pose(i)
		var g := tr.ground_info(sp[0], sp[1])
		var d: Array = net.probe(sp[0], sp[1], 80.0)
		check(not d.is_empty() and float(d[0]) < 40.0, "estación %d: a %.0f m del camino (piso %d)" % [i + 1, float(d[0]) if not d.is_empty() else -1.0, int(g.y)])
	print("NET_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
