extends RefCounted
## Grafo de tránsito de Dream City (Etapa 6): carriles con sentido, cruces y conexiones. Se DERIVA de las calles de CityLayout (que ya salen de la semilla del mundo),
## así que es idéntico en todos los teléfonos y en el servidor: no se guarda ni se sincroniza nada. Mano derecha (Argentina).
## - nodo = un cruce (o el extremo de una calle sin salida)
## - carril = un tramo de calle entre dos nodos, en un sentido, a un costado del eje: {road, s0, s1, dir, k, off, len, a, b, next:[carriles]}
##   k=0 es el más cercano al eje (el de «adelantar»/girar a la izquierda), k=n-1 el de la derecha (el de girar a la derecha).
## - posición sobre un carril: lane_at(carril, d) con d = metros recorridos desde el inicio del carril; es una función pura (sirve para tránsito cinemático determinista).
## Calles de un solo sentido: los callejones (cada uno al revés del anterior). No entran ni los túneles ni las bahías de estacionamiento.

const CELL := 160.0 # igual que la cuadra de carga de CityLayout y de WorldSectorManager
const MERGE := 14.0 # los cruces a menos de esto (a lo largo de una calle o entre calles) son el mismo nodo
const MIN_EDGE := 6.0
const EXCLUDED := ["tunnel", "bay"]
const STRAIGHT := 0.5 # rad: una diferencia de rumbo menor a esto es «seguir derecho»
const MAX_TURN := 2.35 # rad: más que esto sería una vuelta en U (no se permite en cruces comunes)
const ONE_WAY := ["alley"]
const PARK_LANE := 0.40 # en calles de un carril por sentido, el carril va a 0,40·semiancho del eje (el resto es del estacionamiento)

var layout: RefCounted
var nodes: Array = [] # {id, pos: Vector2, y, roads: [ids], inl: [carriles que llegan], outl: [carriles que salen], dead: bool}
var lanes: Array = []
var _node_hash: Dictionary = {} # Vector2i → Array de ids de nodo
var _cells: Dictionary = {} # Vector2i (cuadra) → PackedInt32Array de carriles
var _road_ok: Dictionary = {}
var built := false

func build(p_layout: RefCounted) -> void:
	layout = p_layout
	nodes.clear()
	lanes.clear()
	_node_hash.clear()
	_cells.clear()
	_road_ok.clear()
	for r in layout.roads:
		_road_ok[int(r["id"])] = not EXCLUDED.has(str(r["kind"]))
	# 1) nodos en los cruces
	var jnode: Array = []
	for j in layout.junctions:
		var ok := false
		for rid in j["roads"]:
			if _road_ok.get(int(rid), false):
				ok = true
		if not ok:
			jnode.append(-1)
			continue
		var n := _node_at(j["pos"], float(j["y"]))
		for rid in j["roads"]:
			if _road_ok.get(int(rid), false) and not (nodes[n]["roads"] as Array).has(int(rid)):
				(nodes[n]["roads"] as Array).append(int(rid))
		jnode.append(n)
	# 2) por calle: nodos ordenados por posición y tramos entre ellos
	var per_road: Dictionary = {}
	for ji in layout.junctions.size():
		if int(jnode[ji]) < 0:
			continue
		for rid in layout.junctions[ji]["roads"]:
			if not _road_ok.get(int(rid), false):
				continue
			var s := _project(int(rid), layout.junctions[ji]["pos"])
			if not per_road.has(int(rid)):
				per_road[int(rid)] = []
			(per_road[int(rid)] as Array).append([s, int(jnode[ji])])
	for r in layout.roads:
		var rid := int(r["id"])
		if not _road_ok.get(rid, false):
			continue
		_build_road(r, per_road.get(rid, []))
	# 3) conexiones en los nodos y mapa por cuadras
	for n in nodes:
		_connect_node(n)
	for li in lanes.size():
		_register_cells(li)
	built = true

# ───────────────────────── armado ─────────────────────────
func _node_at(pos: Vector2, y: float) -> int:
	var k := Vector2i(int(floor(pos.x / MERGE)), int(floor(pos.y / MERGE)))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var kk := Vector2i(k.x + dx, k.y + dz)
			if not _node_hash.has(kk):
				continue
			for ni in (_node_hash[kk] as Array):
				if (nodes[int(ni)]["pos"] as Vector2).distance_to(pos) < MERGE:
					return int(ni)
	var id := nodes.size()
	nodes.append({"id": id, "pos": pos, "y": y, "roads": [], "inl": [], "outl": [], "dead": false})
	if not _node_hash.has(k):
		_node_hash[k] = []
	(_node_hash[k] as Array).append(id)
	return id

## Posición (metros desde el inicio de la calle) del punto de la calle más cercano a p
func _project(rid: int, p: Vector2) -> float:
	var r: Dictionary = layout.roads[rid]
	var pts: PackedVector3Array = r["pts"]
	var cum: PackedFloat32Array = r["cum"]
	var best := 1e18
	var bs := 0.0
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var e := Vector2(pts[i + 1].x, pts[i + 1].z) - a
		var l2 := e.length_squared()
		var t := 0.0 if l2 < 1e-6 else clampf((p - a).dot(e) / l2, 0.0, 1.0)
		var d := (a + e * t).distance_squared_to(p)
		if d < best:
			best = d
			bs = float(cum[i]) + t * sqrt(l2)
	return bs

func _build_road(r: Dictionary, found: Array) -> void:
	var rid := int(r["id"])
	var cum: PackedFloat32Array = r["cum"]
	var pts: PackedVector3Array = r["pts"]
	var total := float(cum[cum.size() - 1])
	if total < MIN_EDGE * 2.0:
		return
	var closed: bool = Vector2(pts[0].x, pts[0].z).distance_to(Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z)) < 2.0 * float(layout.STEP)
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	# quita repetidos (mismo nodo o a menos de MERGE metros)
	var stops: Array = []
	for f in found:
		if not stops.is_empty() and (int(stops[-1][1]) == int(f[1]) or float(f[0]) - float(stops[-1][0]) < MERGE * 0.5):
			continue
		stops.append([float(f[0]), int(f[1])])
	# extremos
	if stops.is_empty() or float(stops[0][0]) > MERGE:
		var first_n := _node_at(Vector2(pts[0].x, pts[0].z), pts[0].y)
		if not (nodes[first_n]["roads"] as Array).has(rid):
			(nodes[first_n]["roads"] as Array).append(rid)
		stops.push_front([0.0, first_n])
	if closed:
		stops.append([total, int(stops[0][1])])
	elif float(stops[-1][0]) < total - MERGE:
		var last_n := _node_at(Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z), pts[pts.size() - 1].y)
		if not (nodes[last_n]["roads"] as Array).has(rid):
			(nodes[last_n]["roads"] as Array).append(rid)
		stops.append([total, last_n])
	var per_dir := 2 if float(r["hw"]) >= 6.0 else 1
	var one_way := ONE_WAY.has(str(r["kind"]))
	for i in stops.size() - 1:
		var s0: float = stops[i][0]
		var s1: float = stops[i + 1][0]
		if s1 - s0 < MIN_EDGE:
			continue
		var na: int = stops[i][1]
		var nb: int = stops[i + 1][1]
		for dir in [1, -1]:
			if one_way and (dir == 1) != (rid % 2 == 0):
				continue
			var cnt := 1 if one_way else per_dir
			for k in cnt:
				var off := (float(k) + 0.5) * float(r["hw"]) / float(cnt)
				if cnt == 1:
					off = float(r["hw"]) * PARK_LANE # un poco hacia el eje: deja lugar a los autos estacionados del cordón
				if one_way:
					off = 0.0
				var id := lanes.size()
				var a := na if dir == 1 else nb
				var b := nb if dir == 1 else na
				lanes.append({"id": id, "road": rid, "s0": s0, "s1": s1, "dir": dir, "k": k, "n": cnt, "off": off, "len": s1 - s0, "a": a, "b": b, "next": [], "kind": str(r["kind"]), "hw": float(r["hw"])})
				(nodes[a]["outl"] as Array).append(id)
				(nodes[b]["inl"] as Array).append(id)

## Unidad de rumbo (x,z) de un carril en la distancia d, en el sentido de la marcha
func heading_at(li: int, d: float) -> Vector2:
	return lane_at(li, d)["tan"]

## Punto del carril a d metros del inicio: {pos: Vector3 (con altura), tan: Vector2 (sentido de la marcha), yaw}
func lane_at(li: int, d: float) -> Dictionary:
	var L: Dictionary = lanes[li]
	var r: Dictionary = layout.roads[int(L["road"])]
	var dd := clampf(d, 0.0, float(L["len"]))
	var s := float(L["s0"]) + dd if int(L["dir"]) == 1 else float(L["s1"]) - dd
	var cum: PackedFloat32Array = r["cum"]
	var pts: PackedVector3Array = r["pts"]
	# búsqueda binaria del segmento
	var lo := 0
	var hi := cum.size() - 2
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if float(cum[mid]) <= s:
			lo = mid
		else:
			hi = mid - 1
	var seg := maxf(float(cum[lo + 1]) - float(cum[lo]), 1e-4)
	var t := clampf((s - float(cum[lo])) / seg, 0.0, 1.0)
	var a := pts[lo]
	var b := pts[lo + 1]
	var tg := Vector2(b.x - a.x, b.z - a.z).normalized() * float(L["dir"])
	var right := Vector2(-tg.y, tg.x)
	var p := a.lerp(b, t)
	return {"pos": Vector3(p.x + right.x * float(L["off"]), p.y, p.z + right.y * float(L["off"])), "tan": tg, "yaw": atan2(tg.x, tg.y)}

func lane_length(li: int) -> float:
	return float(lanes[li]["len"])

# ───────────────────────── conexiones ─────────────────────────
func _connect_node(n: Dictionary) -> void:
	var ins: Array = n["inl"]
	var outs: Array = n["outl"]
	if ins.is_empty() or outs.is_empty():
		return
	for li in ins:
		var L: Dictionary = lanes[int(li)]
		var hl: Vector2 = lane_at(int(li), float(L["len"]))["tan"]
		var right_l := Vector2(-hl.y, hl.x)
		var cand: Array = [] # [carril de salida, tipo, |ángulo|]
		for oi in outs:
			var O: Dictionary = lanes[int(oi)]
			var reverse: bool = int(O["road"]) == int(L["road"]) and float(O["s0"]) == float(L["s0"]) and float(O["s1"]) == float(L["s1"]) and int(O["dir"]) != int(L["dir"])
			if reverse:
				continue
			var ho: Vector2 = lane_at(int(oi), 0.0)["tan"]
			var ang := absf(hl.angle_to(ho))
			if ang > MAX_TURN:
				continue
			var kind := "straight"
			if ang >= STRAIGHT:
				kind = "right" if ho.dot(right_l) > 0.0 else "left"
			cand.append([int(oi), kind, ang])
		var conns: Array = []
		for c in cand:
			var kind: String = c[1]
			var O2: Dictionary = lanes[int(c[0])]
			match kind:
				"straight":
					if int(O2["road"]) == int(L["road"]) or absf(float(O2["hw"]) - float(L["hw"])) < 3.0:
						# carril equivalente: el mismo k (o el último que exista)
						if int(O2["k"]) == mini(int(L["k"]), int(O2["n"]) - 1) or int(L["n"]) == 1:
							conns.append(int(c[0]))
				"right":
					if int(L["k"]) == int(L["n"]) - 1 and int(O2["k"]) == int(O2["n"]) - 1:
						conns.append(int(c[0]))
				"left":
					if int(L["k"]) == 0 and int(O2["k"]) == 0:
						conns.append(int(c[0]))
		if conns.is_empty() and not cand.is_empty():
			# sin giro permitido por carril: el de rumbo más parecido (que no quede una calle cortada)
			cand.sort_custom(func(a: Array, b: Array) -> bool: return float(a[2]) < float(b[2]))
			conns.append(int(cand[0][0]))
		if conns.is_empty():
			# calle sin salida: vuelta en U al carril opuesto
			for oi in outs:
				var O3: Dictionary = lanes[int(oi)]
				if int(O3["road"]) == int(L["road"]) and float(O3["s0"]) == float(L["s0"]) and int(O3["dir"]) != int(L["dir"]):
					conns.append(int(oi))
					n["dead"] = true
		L["next"] = conns

# ───────────────────────── consultas ─────────────────────────
func _register_cells(li: int) -> void:
	var len_ := lane_length(li)
	var d := 0.0
	while true:
		var p: Vector3 = lane_at(li, d)["pos"]
		var k := Vector2i(int(floor(p.x / CELL)), int(floor(p.z / CELL)))
		if not _cells.has(k):
			_cells[k] = PackedInt32Array()
		var arr: PackedInt32Array = _cells[k]
		if not arr.has(li):
			arr.append(li)
			_cells[k] = arr
		if d >= len_:
			break
		d = minf(d + 24.0, len_)

## Carriles que pasan por una cuadra de carga (Vector2i como en CityLayout.CELL)
func lanes_in_cell(cell: Vector2i) -> PackedInt32Array:
	return _cells.get(cell, PackedInt32Array())

## El nodo (cruce) más cercano a p dentro de max_dist; -1 si no hay
func node_near(p: Vector2, max_dist := 30.0) -> int:
	var best := -1
	var bd := max_dist
	var k := Vector2i(int(floor(p.x / MERGE)), int(floor(p.y / MERGE)))
	var rr := int(ceil(max_dist / MERGE))
	for dx in range(-rr, rr + 1):
		for dz in range(-rr, rr + 1):
			var kk := Vector2i(k.x + dx, k.y + dz)
			if not _node_hash.has(kk):
				continue
			for ni in (_node_hash[kk] as Array):
				var d := (nodes[int(ni)]["pos"] as Vector2).distance_to(p)
				if d < bd:
					bd = d
					best = int(ni)
	return best

## El carril más cercano a un punto (para saber dónde está el jugador o ubicar algo): {lane, d, dist}; vacío si no hay uno a menos de max_dist
func nearest_lane(p: Vector2, max_dist := 40.0) -> Dictionary:
	var best := {}
	var bd := max_dist
	var cx := int(floor(p.x / CELL))
	var cz := int(floor(p.y / CELL))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for li in lanes_in_cell(Vector2i(cx + dx, cz + dz)):
				var len_ := lane_length(li)
				var d := 0.0
				while true:
					var q: Vector3 = lane_at(li, d)["pos"]
					var dist := Vector2(q.x, q.z).distance_to(p)
					if dist < bd:
						bd = dist
						best = {"lane": li, "d": d, "dist": dist}
					if d >= len_:
						break
					d = minf(d + 12.0, len_)
	return best

## Huella del grafo (para comprobar que sale igual en todos lados)
func signature() -> int:
	var h := hash(nodes.size() * 100003 + lanes.size())
	for L in lanes:
		h = hash([h, int(L["road"]), roundi(float(L["s0"])), roundi(float(L["s1"])), int(L["dir"]), int(L["k"]), (L["next"] as Array).size()])
	return h

func stats() -> Dictionary:
	var km := 0.0
	var no_next := 0
	for L in lanes:
		km += float(L["len"]) / 1000.0
		if (L["next"] as Array).is_empty():
			no_next += 1
	return {"nodes": nodes.size(), "lanes": lanes.size(), "lane_km": km, "no_next": no_next, "cells": _cells.size()}
