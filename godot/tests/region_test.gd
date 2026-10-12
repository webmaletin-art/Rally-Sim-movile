## La región del mundo abierto: carga del archivo, terreno, caminos, paredes y rutas (GPS).
## Uso: godot --headless --path godot --script res://tests/region_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const RegionData := preload("res://game/region/region_data.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var city := CityLayout.new()
	city.build()
	var t1 := Time.get_ticks_msec()
	var rg := RegionData.new()
	_check(rg.load_file(city), "carga region_1.bin")
	print("  ciudad %d ms · región %d ms" % [t1 - t0, Time.get_ticks_msec() - t1])
	_check(rg.edges.size() > 1000, "calles: %d, nodos: %d" % [rg.edges.size(), rg.nodes.size()])
	# el terreno cerca de la ciudad es el de la ciudad
	var dd := 0.0
	for p in [Vector2(0, 0), Vector2(1500, -800), Vector2(-2000, 500), Vector2(900, 900)]:
		dd = maxf(dd, absf(rg.base_height(p.x, p.y) - city.height(p.x, p.y)))
	_check(dd < 0.01, "terreno base = CityLayout.height cerca de la ciudad (dif. %.3f)" % dd)
	# el anillo: sobre su eje el piso es el camino
	var ring := rg.node_by_id("ring0")
	var found := false
	for i in rg.nodes.size():
		if str(rg.nodes[i][0]).begins_with("ring"):
			ring = i
			found = true
			break
	_check(found, "nodos del anillo")
	var rp := rg.node_pos(ring)
	var g := rg.ground(rp.x, rp.y)
	_check(g.y == 0.0, "sobre el nodo del anillo hay asfalto (sup. %d, altura %.2f)" % [int(g.y), g.x])
	# a 60 m del camino el terreno vuelve a la normalidad
	var far := rg.height(rp.x, rp.y + 400.0)
	print("  altura a 400 m del nodo: %.2f (base %.2f)" % [far, rg.base_height(rp.x, rp.y + 400.0)])
	# consultas por segundo
	var tq := Time.get_ticks_usec()
	var acc := 0.0
	for i in 20000:
		var q := Vector2(-3000.0 + float(i % 200) * 30.0, -5000.0 - float(i / 200) * 40.0)
		acc += rg.ground(q.x, q.y).x
	var us := float(Time.get_ticks_usec() - tq) / 20000.0
	print("  ground(): %.1f µs por consulta (%.0f)" % [us, acc])
	_check(us < 80.0, "ground() rápido (< 80 µs)")
	# rutas entre dos ciudades
	var names := {}
	for i in rg.nodes.size():
		names[str(rg.nodes[i][4])] = i
	for pair in [["Puerto Alba", "Bahía Ámbar"], ["Santa Aurora", "Quebrada Roja"], ["Villa Cóndor", "Puerto Alba"], ["Paso del Cóndor", "Río Hondo"]]:
		var a := rg.node_pos(names[pair[0]])
		var b := rg.node_pos(names[pair[1]])
		var tr := Time.get_ticks_usec()
		var r: Dictionary = rg.route(a, b)
		_check(bool(r["ok"]) and float(r["len"]) > a.distance_to(b) * 0.95, "ruta %s → %s: %.1f km (recta %.1f) en %.1f ms, %d puntos" % [pair[0], pair[1], float(r["len"]) / 1000.0, a.distance_to(b) / 1000.0, float(Time.get_ticks_usec() - tr) / 1000.0, (r["pts"] as PackedVector2Array).size()])
	# desde la salida de la ruta 20 de la ciudad hasta Puerto Alba
	var ex20 := rg.node_pos(rg.node_by_id("exit20"))
	var r2: Dictionary = rg.route(ex20, rg.node_pos(names["Puerto Alba"]))
	_check(bool(r2["ok"]), "Salida 20 → Puerto Alba: %.1f km" % (float(r2["len"]) / 1000.0))
	# conectividad: desde la salida 20 se llega a todos los lugares con nombre
	var unreachable := 0
	for nm in names:
		var ni: int = names[nm]
		if int((rg.nodes[ni] as Array)[3]) in [3, 4, 5]:
			var rr: Dictionary = rg.route(ex20, rg.node_pos(ni))
			if not bool(rr["ok"]):
				unreachable += 1
				print("  sin camino a ", nm)
	_check(unreachable == 0, "todas las ciudades, pueblos y villas son alcanzables desde Dream City")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
