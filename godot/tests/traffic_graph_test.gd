## Comprobación corta del grafo de tránsito (Etapa 6): se arma igual siempre, los carriles van por la derecha, todo carril tiene salida, las conexiones son continuas
## y se puede recorrer al azar sin quedar trabado. Sin red.
## Uso: godot --headless --path godot --script res://tests/traffic_graph_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const TrafficGraph := preload("res://game/world/traffic_graph.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	var city := CityLayout.new()
	city.build()
	var t0 := Time.get_ticks_msec()
	var g := TrafficGraph.new()
	g.build(city)
	var ms := Time.get_ticks_msec() - t0
	var st := g.stats()
	print("     grafo: ", st, " en ", ms, " ms")
	check(int(st["lanes"]) > 500 and int(st["nodes"]) > 100, "el grafo tiene carriles y cruces")
	check(ms < 4000, "se arma rápido (%d ms)" % ms)
	var g2 := TrafficGraph.new()
	g2.build(city)
	check(g.signature() == g2.signature(), "el grafo sale igual las dos veces (huella %d)" % g.signature())
	# no entran ni túneles ni bahías
	var bad_kind := false
	for L in g.lanes:
		if TrafficGraph.EXCLUDED.has(str(L["kind"])):
			bad_kind = true
	check(not bad_kind, "no hay carriles en túneles ni bahías")
	# mano derecha: el carril del sentido +1 queda a la derecha del eje (mirando en el sentido de la marcha)
	var right_ok := true
	var sampled := 0
	for L in g.lanes:
		if str(L["kind"]) == "alley" or float(L["len"]) < 20.0:
			continue
		var mid := float(L["len"]) * 0.5
		var c: Dictionary = g.lane_at(int(L["id"]), mid)
		# el eje de esa calle en el mismo s
		var r: Dictionary = city.roads[int(L["road"])]
		var s := float(L["s0"]) + mid if int(L["dir"]) == 1 else float(L["s1"]) - mid
		var axis := _axis(r, s)
		var tg: Vector2 = c["tan"]
		var rel := Vector2((c["pos"] as Vector3).x - axis.x, (c["pos"] as Vector3).z - axis.y)
		var side := tg.x * rel.y - tg.y * rel.x # + = a la derecha según (x,z) con y arriba
		sampled += 1
		if side > 0.0 == false and rel.length() > 0.5:
			right_ok = false
		if sampled > 400:
			break
	check(right_ok, "los carriles van por la derecha (%d muestreados)" % sampled)
	# cada carril tiene salida (salvo contados) y las conexiones son continuas
	var no_next := int(st["no_next"])
	check(no_next <= int(float(st["lanes"]) * 0.01), "casi todos los carriles tienen salida (%d sin salida)" % no_next)
	var worst_gap := 0.0
	var gap_n := 0
	var big_gap := 0
	for L in g.lanes:
		var end: Vector3 = g.lane_at(int(L["id"]), float(L["len"]))["pos"]
		for nx in (L["next"] as Array):
			var st2: Vector3 = g.lane_at(int(nx), 0.0)["pos"]
			var gap := Vector2(end.x - st2.x, end.z - st2.z).length()
			worst_gap = maxf(worst_gap, gap)
			gap_n += 1
			if gap > 30.0:
				big_gap += 1
	check(big_gap <= int(float(gap_n) * 0.02), "las conexiones empalman (peor salto %.1f m, %d de %d pasan 30 m)" % [worst_gap, big_gap, gap_n])
	# recorrido al azar: 4000 tramos sin quedar trabado
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var li := rng.randi() % g.lanes.size()
	var stuck := false
	var turns := 0
	for i in 4000:
		var nx: Array = g.lanes[li]["next"]
		if nx.is_empty():
			stuck = true
			break
		if nx.size() > 1:
			turns += 1
		li = int(nx[rng.randi() % nx.size()])
	check(not stuck, "se puede andar 4000 tramos al azar sin trabarse (%d decisiones)" % turns)
	# consultas espaciales
	var p := Vector2(130.0, 0.0)
	var near := g.nearest_lane(p, 60.0)
	check(not near.is_empty(), "hay un carril cerca de la calle 10 (a %.1f m)" % float(near.get("dist", -1.0)))
	var cell := Vector2i(int(floor(p.x / TrafficGraph.CELL)), int(floor(p.y / TrafficGraph.CELL)))
	check(g.lanes_in_cell(cell).size() > 0, "la cuadra del centro tiene carriles")
	# semáforos (Etapa 7)
	var sg: RefCounted = city.traffic_signals()
	check(sg.count() > 15, "hay cruces con semáforos (%d) y %d postes" % [sg.count(), sg.head_info.size()])
	check(sg.head_info.size() >= sg.count() * 2, "cada cruce con semáforo tiene sus postes")
	var clash := false
	var seen_green := 0
	var seen_amber := 0
	var seen_red := 0
	var order_ok := true
	for off in [0.0, 7.3, 21.9]:
		var prev := -1
		for k in 800:
			var t := float(k) * 0.1
			var a: int = sg.state_at(off, 0, t)
			var b: int = sg.state_at(off, 1, t)
			if a == sg.GO and b != sg.RED:
				clash = true
			if b == sg.GO and a != sg.RED:
				clash = true
			if a == sg.GO: seen_green += 1
			elif a == sg.AMBER: seen_amber += 1
			else: seen_red += 1
			if prev == sg.GO and a == sg.RED:
				order_ok = false # del verde se pasa al amarillo, nunca directo al rojo
			prev = a
	check(not clash, "nunca hay verde en las dos calles a la vez")
	check(order_ok and seen_green > 0 and seen_amber > 0 and seen_red > seen_green, "el ciclo hace verde → amarillo → rojo (%d/%d/%d)" % [seen_green, seen_amber, seen_red])
	check(is_equal_approx(sg.state_at(5.0, 0, 3.0), sg.state_at(5.0, 0, 3.0 + sg.CYCLE)), "el estado se repite cada ciclo (puro por la hora del mundo)")
	var any_lane := -1
	for L in g.lanes:
		if sg.is_signalized(int(L["b"])):
			any_lane = int(L["id"])
			break
	check(any_lane >= 0 and sg.time_to_change(any_lane, 0.0) > 0.0, "un carril que llega a un cruce con semáforo sabe cuánto falta para el cambio")
	print("TRAFFIC_GRAPH_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)

func _axis(r: Dictionary, s: float) -> Vector2:
	var cum: PackedFloat32Array = r["cum"]
	var pts: PackedVector3Array = r["pts"]
	for i in cum.size() - 1:
		if s <= float(cum[i + 1]) or i == cum.size() - 2:
			var t := clampf((s - float(cum[i])) / maxf(float(cum[i + 1]) - float(cum[i]), 1e-4), 0.0, 1.0)
			var p := pts[i].lerp(pts[i + 1], t)
			return Vector2(p.x, p.z)
	return Vector2.ZERO
