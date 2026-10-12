extends RefCounted
## Red de rutas (formato de godot/game/data/networks/<id>.json, lo arma tools/route_gen/import_network.py): calles con su superficie, ancho y entorno, rotondas y estaciones de servicio.
## Todas las consultas son puras (sirven desde los hilos de la física y de armado del mundo). Una grilla de 128 m guarda los segmentos de cada calle para buscar la más cercana a un punto.
## Ejes: x al este, z al sur (como el editor). Superficies: 0 asfalto · 1 tierra · 2 ripio · 3 barro · 4 arena. Entornos: 0 rural · 1 bosque · 2 desierto · 3 periurbano · 4 urbano.

const CELL := 128.0
const RING_STEP := 6.0 # largo de los segmentos de una rotonda (m)

var id := ""
var title := ""
var bbox := Rect2()
var km := 0.0
var nodes: Dictionary = {} # id -> Vector2
var e_id: PackedStringArray = PackedStringArray()
var e_a: PackedStringArray = PackedStringArray()
var e_b: PackedStringArray = PackedStringArray()
var e_surf: PackedByteArray = PackedByteArray()
var e_w: PackedFloat32Array = PackedFloat32Array() # ancho de la calzada (m)
var e_env: PackedByteArray = PackedByteArray()
var e_len: PackedFloat32Array = PackedFloat32Array()
var e_ring: PackedByteArray = PackedByteArray() # 1 = rotonda (anillo cerrado)
var e_pts: Array = [] # PackedVector2Array por calle
var e_cum: Array = [] # PackedFloat32Array (largo acumulado) por calle
var grid: Dictionary = {} # Vector2i -> PackedInt32Array [calle, segmento, calle, segmento, …]
var stations: Array = [] # {id, name, pos (centro del playón), yaw (rumbo del camino), road (punto del camino), services}
var rounds: Array = [] # {x, z, r, w, surf, island}
var adj: Dictionary = {} # id de nodo -> Array de [índice de calle, true si el nodo es el inicio (a)]
var ring_edge: Dictionary = {} # índice de rotonda -> índice de calle del anillo

static func load_net(net_id: String):
	var f := "res://game/data/networks/%s.json" % net_id
	if not FileAccess.file_exists(f):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(f))
	if not (d is Dictionary):
		return null
	var nd = (load("res://game/net/net_data.gd") as GDScript).new()
	nd._parse(d as Dictionary)
	return nd

func _parse(d: Dictionary) -> void:
	id = str(d["id"])
	title = str(d["name"])
	km = float(d.get("km", 0.0))
	var bb: Array = d["bbox"]
	bbox = Rect2(float(bb[0]), float(bb[1]), float(bb[2]) - float(bb[0]), float(bb[3]) - float(bb[1]))
	for n in d["nodes"]:
		nodes[str(n[0])] = Vector2(float(n[1]), float(n[2]))
	for e in d["edges"]:
		var flat: Array = e[6]
		var pts := PackedVector2Array()
		pts.resize(flat.size() / 2)
		for i in pts.size():
			pts[i] = Vector2(float(flat[i * 2]) * 0.1, float(flat[i * 2 + 1]) * 0.1)
		_add_edge(str(e[0]), str(e[1]), str(e[2]), int(e[3]), float(e[4]), int(e[5]), pts, false)
	for r in d.get("roundabouts", []):
		rounds.append(r)
		var ring := PackedVector2Array()
		var rr := float(r["r"])
		var n := maxi(24, int(round(TAU * rr / RING_STEP)))
		for i in n + 1:
			var a := TAU * float(i % n) / float(n)
			ring.append(Vector2(float(r["x"]) + cos(a) * rr, float(r["z"]) + sin(a) * rr))
		ring_edge[rounds.size() - 1] = e_id.size()
		_add_edge("ring_" + str(r["id"]), "", "", int(r["surf"]), float(r["w"]), int(r["env"]), ring, true)
	# grafo: la calle del anillo no tiene nodos; las puntas que caen sobre la rotonda se unen entre sí por arcos (ver _link_rounds)
	for ei in e_id.size():
		if e_ring[ei] == 1:
			continue
		for end in [e_a[ei], e_b[ei]]:
			if not adj.has(end):
				adj[end] = []
		(adj[e_a[ei]] as Array).append([ei, true])
		(adj[e_b[ei]] as Array).append([ei, false])
	_link_rounds()
	_make_stations(d.get("stations", []))

func _add_edge(eid: String, a: String, b: String, surf: int, w: float, env: int, pts: PackedVector2Array, ring: bool) -> void:
	var ei := e_id.size()
	e_id.append(eid)
	e_a.append(a)
	e_b.append(b)
	e_surf.append(surf)
	e_w.append(w)
	e_env.append(env)
	e_ring.append(1 if ring else 0)
	var cum := PackedFloat32Array()
	cum.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		cum[i] = acc
	e_len.append(acc)
	e_pts.append(pts)
	e_cum.append(cum)
	for si in pts.size() - 1:
		var m := (pts[si] + pts[si + 1]) * 0.5
		var k := Vector2i(int(floor(m.x / CELL)), int(floor(m.y / CELL)))
		var arr: PackedInt32Array = grid.get(k, PackedInt32Array())
		arr.append(ei)
		arr.append(si)
		grid[k] = arr

## Las calles que terminan sobre una rotonda quedan unidas por arcos del anillo (para buscar caminos)
func _link_rounds() -> void:
	for ri in rounds.size():
		var r: Dictionary = rounds[ri]
		var c := Vector2(float(r["x"]), float(r["z"]))
		var rr := float(r["r"])
		var ports: Array = [] # [nodo, ángulo]
		for ei in e_id.size():
			if e_ring[ei] == 1:
				continue
			for isa in [true, false]:
				var nid: String = e_a[ei] if isa else e_b[ei]
				var p: Vector2 = nodes[nid]
				if absf(p.distance_to(c) - rr) < 3.0:
					ports.append([nid, atan2(p.y - c.y, p.x - c.x)])
		for i in ports.size():
			for j in range(i + 1, ports.size()):
				var a: float = ports[i][1]
				var b: float = ports[j][1]
				var da := fposmod(b - a, TAU)
				var arc := PackedVector2Array()
				var n := maxi(2, int(ceil(minf(da, TAU - da) * rr / RING_STEP)))
				var dir := 1.0 if da <= PI else -1.0
				var span := da if da <= PI else TAU - da
				for k in n + 1:
					var ang := a + dir * span * float(k) / float(n)
					arc.append(c + Vector2(cos(ang), sin(ang)) * rr)
				var ni := e_id.size()
				_add_virtual(ports[i][0], ports[j][0], arc)
				(adj[ports[i][0]] as Array).append([ni, true])
				(adj[ports[j][0]] as Array).append([ni, false])

## Un arco de rotonda para buscar caminos: está en las listas de calles pero NO en la grilla (la calle que se dibuja y se pisa es el anillo)
func _add_virtual(a: String, b: String, pts: PackedVector2Array) -> void:
	e_id.append("arc_%s_%s" % [a, b])
	e_a.append(a)
	e_b.append(b)
	e_surf.append(0)
	e_w.append(9.0)
	e_env.append(0)
	e_ring.append(2)
	var cum := PackedFloat32Array()
	cum.resize(pts.size())
	var acc := 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		cum[i] = acc
	e_len.append(acc)
	e_pts.append(pts)
	e_cum.append(cum)

func _make_stations(list: Array) -> void:
	for s in list:
		var q := Vector2(float(s["x"]), float(s["z"]))
		var pr := probe(q.x, q.y, 200.0)
		if pr.is_empty():
			continue
		var road: Vector2 = pr[8]
		var tg := tangent_at(int(pr[3]), int(pr[4]))
		var nrm := Vector2(-tg.y, tg.x)
		var side := signf((q - road).dot(nrm))
		if absf((q - road).dot(nrm)) < 3.0:
			side = 1.0
		var hw := e_w[int(pr[3])] * 0.5
		var pad := road + nrm * side * (hw + 24.0)
		stations.append({"id": str(s["id"]), "name": str(s["name"]), "pos": pad, "road": road, "yaw": atan2(tg.x, tg.y), "side": side, "services": s.get("services", [])})

# ───────────────────────── consultas ─────────────────────────
func tangent_at(ei: int, si: int) -> Vector2:
	var pts: PackedVector2Array = e_pts[ei]
	return (pts[si + 1] - pts[si]).normalized()

## La calle más cercana a (x, z) (por el borde de la calzada, no por el eje): [distancia al eje, 0, superficie, calle, segmento, t, nx, nz, punto del eje (Vector2)] o [] si no hay ninguna a menos de `rmax`
func probe(x: float, z: float, rmax := 70.0) -> Array:
	var cx := int(floor(x / CELL))
	var cz := int(floor(z / CELL))
	var lx := x - float(cx) * CELL
	var lz := z - float(cz) * CELL
	var x0 := -1 if lx < rmax else 0
	var x1 := 1 if lx > CELL - rmax else 0
	var z0 := -1 if lz < rmax else 0
	var z1 := 1 if lz > CELL - rmax else 0
	var best_m := 1.0e9
	var best: Array = []
	for dx in range(x0, x1 + 1):
		for dz in range(z0, z1 + 1):
			var arr: PackedInt32Array = grid.get(Vector2i(cx + dx, cz + dz), PackedInt32Array())
			var k := 0
			while k < arr.size():
				var ei := arr[k]
				var si := arr[k + 1]
				k += 2
				var pts: PackedVector2Array = e_pts[ei]
				var a := pts[si]
				var ab := pts[si + 1] - a
				var l2 := ab.length_squared()
				var t := 0.0 if l2 < 1e-6 else clampf(((x - a.x) * ab.x + (z - a.y) * ab.y) / l2, 0.0, 1.0)
				var qx := a.x + ab.x * t
				var qz := a.y + ab.y * t
				var ddx := x - qx
				var ddz := z - qz
				var d2 := ddx * ddx + ddz * ddz
				var hw := e_w[ei] * 0.5
				if d2 > (hw + rmax) * (hw + rmax):
					continue
				var d := sqrt(d2)
				var m := d - hw
				if m < best_m:
					best_m = m
					best = [d, 0.0, int(e_surf[ei]), ei, si, t, ddx / maxf(d, 0.001), ddz / maxf(d, 0.001), Vector2(qx, qz), hw]
	if best.is_empty():
		return best
	best[1] = best[9]
	return best

## Punto del camino a `s` metros del inicio de la calle ei: [posición, rumbo (Vector2 unitario)]
func point_at(ei: int, s: float) -> Array:
	var cum: PackedFloat32Array = e_cum[ei]
	var pts: PackedVector2Array = e_pts[ei]
	s = clampf(s, 0.0, cum[cum.size() - 1])
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg := maxf(cum[hi] - cum[lo], 1e-4)
	var t := (s - cum[lo]) / seg
	return [pts[lo].lerp(pts[hi], t), (pts[hi] - pts[lo]).normalized()]

## Largo recorrido sobre la calle ei hasta el segmento si (con la fracción t)
func s_of(ei: int, si: int, t: float) -> float:
	var cum: PackedFloat32Array = e_cum[ei]
	return cum[si] + (cum[si + 1] - cum[si]) * t

func nearest_station(p: Vector2) -> int:
	var bi := -1
	var bd := 1.0e18
	for i in stations.size():
		var d := p.distance_squared_to(stations[i]["pos"])
		if d < bd:
			bd = d
			bi = i
	return bi

## Camino más corto entre dos puntos de la red (Dijkstra sobre los 65 nodos): la polilínea completa (Vector2) y su largo. Parte de la calle más cercana a cada punto.
func route(from: Vector2, to: Vector2) -> Array:
	var pa := probe(from.x, from.y, 400.0)
	var pb := probe(to.x, to.y, 400.0)
	if pa.is_empty() or pb.is_empty():
		return [PackedVector2Array(), 0.0]
	var ea := int(pa[3])
	var eb := int(pb[3])
	if e_ring[ea] == 1:
		return [PackedVector2Array([from, to]), from.distance_to(to)] # (sobre la rotonda: directo al otro punto)
	var sa := s_of(ea, int(pa[4]), float(pa[5]))
	var sb := s_of(eb, int(pb[4]), float(pb[5]))
	if ea == eb:
		return [_slice(ea, sa, sb), absf(sb - sa)]
	# Dijkstra
	var dist := {}
	var prev := {} # nodo -> [nodo anterior, calle, ¿se recorre de a a b?]
	var open := {}
	for end in [[e_a[ea], sa], [e_b[ea], e_len[ea] - sa]]:
		if not nodes.has(end[0]):
			continue
		if float(end[1]) < float(dist.get(end[0], 1e18)):
			dist[end[0]] = float(end[1])
			prev[end[0]] = ["", ea, end[0] == e_b[ea]] # se entra por esta punta (al nodo b se llega yendo hacia atrás… ver abajo)
			open[end[0]] = true
	var goal := {}
	for end in [[e_a[eb], sb], [e_b[eb], e_len[eb] - sb]]:
		goal[end[0]] = float(end[1])
	var best_total := 1.0e18
	var best_goal := ""
	while not open.is_empty():
		var cur := ""
		var cd := 1.0e18
		for k in open:
			if float(dist[k]) < cd:
				cd = float(dist[k])
				cur = k
		open.erase(cur)
		if cd >= best_total:
			break
		if goal.has(cur) and cd + float(goal[cur]) < best_total:
			best_total = cd + float(goal[cur])
			best_goal = cur
		for item in adj.get(cur, []):
			var ei: int = item[0]
			var far: String = e_b[ei] if bool(item[1]) else e_a[ei]
			var nd := cd + float(e_len[ei])
			if nd < float(dist.get(far, 1e18)):
				dist[far] = nd
				prev[far] = [cur, ei, bool(item[1])]
				open[far] = true
	if best_goal == "":
		return [PackedVector2Array([from, to]), from.distance_to(to)]
	# armar la polilínea de atrás para adelante
	var chain: Array = []
	var cur2 := best_goal
	while cur2 != "" and prev.has(cur2) and str((prev[cur2] as Array)[0]) != "":
		var pv: Array = prev[cur2]
		chain.push_front(pv)
		cur2 = str(pv[0])
	var first_node := cur2 # nodo por el que se sale de la calle de origen
	var out := PackedVector2Array()
	var start_s := e_len[ea] if first_node == e_b[ea] else 0.0
	if first_node == e_a[ea] and e_a[ea] != "":
		start_s = 0.0
	out.append_array(_slice(ea, sa, start_s))
	for pv in chain:
		var ei2: int = pv[1]
		var pts: PackedVector2Array = e_pts[ei2]
		if bool(pv[2]):
			out.append_array(pts)
		else:
			var rev := pts.duplicate()
			rev.reverse()
			out.append_array(rev)
	var end_s := 0.0 if best_goal == e_a[eb] else e_len[eb]
	out.append_array(_slice(eb, end_s, sb))
	return [out, best_total]

## Parte de la calle ei entre las distancias s0 y s1 (en ese sentido)
func _slice(ei: int, s0: float, s1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cum: PackedFloat32Array = e_cum[ei]
	var pts: PackedVector2Array = e_pts[ei]
	out.append(point_at(ei, s0)[0])
	if s1 >= s0:
		for i in pts.size():
			if cum[i] > s0 and cum[i] < s1:
				out.append(pts[i])
	else:
		for i in range(pts.size() - 1, -1, -1):
			if cum[i] < s0 and cum[i] > s1:
				out.append(pts[i])
	out.append(point_at(ei, s1)[0])
	return out
