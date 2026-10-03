extends RefCounted
## GPS de Dream City: el camino más corto por las calles hasta un punto. Las calles son listas de puntos (cada 8 m); acá cada punto es un nodo unido al anterior
## y al siguiente de su calle, y los cruces unen un punto de cada calle. Dijkstra con una pila de prioridad hecha a mano (una vez por destino: unos pocos ms).

const CityLayout := preload("res://game/city/city_layout.gd")

var city: CityLayout
var adj: Array = [] # índice de punto -> PackedInt32Array de vecinos

func _init(p_city: CityLayout) -> void:
	city = p_city
	adj.resize(city.s_x.size())
	for i in adj.size():
		adj[i] = PackedInt32Array()
	for si in adj.size():
		if city.s_next[si] >= 0:
			_link(si, city.s_next[si])
	# cruces: el punto más cercano de cada una de las dos calles
	for j in city.junctions:
		var jp: Vector2 = j["pos"]
		var best := {}
		for si in _near(jp, 14.0):
			var rid := int(city.s_road[si])
			var d := Vector2(city.s_x[si], city.s_z[si]).distance_squared_to(jp)
			if not best.has(rid) or d < float(best[rid][1]):
				best[rid] = [si, d]
		var keys := best.keys()
		for a in keys.size():
			for b in range(a + 1, keys.size()):
				_link(int(best[keys[a]][0]), int(best[keys[b]][0]))
	# los extremos de las calles que no son anillos (la colina nace de una avenida sin cruzarla)
	for ri in city.roads.size():
		var rd: Dictionary = city.roads[ri]
		if str(rd["kind"]) in ["ring", "plaza"]:
			continue
		var pts: PackedVector3Array = rd["pts"]
		for end_i in [0, pts.size() - 1]:
			var ep := Vector2(pts[end_i].x, pts[end_i].z)
			var bi := -1
			var bd := 26.0 * 26.0
			for si in _near(ep, 26.0):
				if int(city.s_road[si]) == ri:
					continue
				var d := Vector2(city.s_x[si], city.s_z[si]).distance_squared_to(ep)
				if d < bd:
					bd = d
					bi = si
			if bi >= 0:
				var base := _first_of(ri)
				_link(base + int(end_i), bi)

func _first_of(ri: int) -> int:
	var si := 0
	for k in ri:
		si += (city.roads[k]["pts"] as PackedVector3Array).size()
	return si

func _link(a: int, b: int) -> void:
	if a == b:
		return
	var la: PackedInt32Array = adj[a]
	if not la.has(b):
		la.append(b)
		adj[a] = la
	var lb: PackedInt32Array = adj[b]
	if not lb.has(a):
		lb.append(a)
		adj[b] = lb

func _near(p: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := int(ceil(r / CityLayout.HC))
	var kx := int(floor(p.x / CityLayout.HC))
	var kz := int(floor(p.y / CityLayout.HC))
	for dx in range(-c, c + 1):
		for dz in range(-c, c + 1):
			var k := Vector2i(kx + dx, kz + dz)
			if city._hash.has(k):
				out.append_array(city._hash[k])
	return out

## Punto de calle más cercano a (x, z); −1 si no hay ninguno a menos de 400 m
func nearest(p: Vector2) -> int:
	var rad := 40.0
	while rad <= 400.0:
		var bi := -1
		var bd := rad * rad
		for si in _near(p, rad):
			var d := Vector2(city.s_x[si], city.s_z[si]).distance_squared_to(p)
			if d < bd:
				bd = d
				bi = si
		if bi >= 0:
			return bi
		rad *= 2.0
	return -1

## Camino de a hasta b por las calles: {pts: PackedVector2Array (cada ~16 m), len: metros}; vacío si no hay camino
func route(a: Vector2, b: Vector2) -> Dictionary:
	var s := nearest(a)
	var t := nearest(b)
	if s < 0 or t < 0:
		return {"pts": PackedVector2Array(), "len": 0.0}
	var n := adj.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(1e30)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var hk := PackedFloat32Array() # pila binaria de (distancia, nodo)
	var hv := PackedInt32Array()
	dist[s] = 0.0
	hk.append(0.0)
	hv.append(s)
	while hk.size() > 0:
		var u := hv[0]
		var du := hk[0]
		var lk: float = hk[hk.size() - 1]
		var lv: int = hv[hv.size() - 1]
		hk.resize(hk.size() - 1)
		hv.resize(hv.size() - 1)
		if hk.size() > 0:
			var i := 0
			var m := hk.size()
			while true:
				var l := i * 2 + 1
				if l >= m:
					break
				var r := l + 1
				var c := r if (r < m and hk[r] < hk[l]) else l
				if hk[c] >= lk:
					break
				hk[i] = hk[c]
				hv[i] = hv[c]
				i = c
			hk[i] = lk
			hv[i] = lv
		if du > dist[u]:
			continue
		if u == t:
			break
		var pu := Vector2(city.s_x[u], city.s_z[u])
		for v in (adj[u] as PackedInt32Array):
			var nd := du + pu.distance_to(Vector2(city.s_x[v], city.s_z[v])) + 0.01
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
				hk.append(nd)
				hv.append(v)
				var i := hk.size() - 1
				while i > 0:
					var p := (i - 1) >> 1
					if hk[p] <= hk[i]:
						break
					var tk := hk[p]
					hk[p] = hk[i]
					hk[i] = tk
					var tv := hv[p]
					hv[p] = hv[i]
					hv[i] = tv
					i = p
	if prev[t] < 0 and s != t:
		return {"pts": PackedVector2Array(), "len": 0.0}
	var rev := PackedVector2Array()
	var cur := t
	var k := 0
	while cur >= 0:
		if k % 2 == 0 or cur == s:
			rev.append(Vector2(city.s_x[cur], city.s_z[cur]))
		k += 1
		cur = prev[cur]
	var out := PackedVector2Array()
	for i in range(rev.size() - 1, -1, -1):
		out.append(rev[i])
	return {"pts": out, "len": float(dist[t])}
