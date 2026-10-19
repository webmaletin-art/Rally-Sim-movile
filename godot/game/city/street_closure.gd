extends RefCounted
## Calles cerradas durante una carrera del mundo abierto. [B] 19/10/2026, pedido del dueño: «en una carrera tiene que cerrar las calles y dejar únicamente la pista; no puede
## ser que esté todo abierto y me vaya para cualquier lado. Si es de A a B se pueden dejar varios caminos, pero se cierra el resto».
## Cómo: a lo largo del recorrido se buscan las calles que salen de él (cruces de la ciudad con CityGps; nodos de la región con RegionData) y, un poco más adelante de cada
## boca, se pone una valla roja y blanca con colisión (círculos sólidos en la grilla de objetos del mundo, que no se rompen). Al terminar la carrera se sacan todas.
## El cálculo es puro (sin escena): se prueba en tests/street_closure_test.gd.

const ID0 := 3000000 # los ids de las vallas empiezan acá (los de la calle terminan mucho antes, y por encima de prop_type.size() no se rompen)
const ON_ROUTE_D := 5.5 # un punto de calle a menos de esto del recorrido es «parte del recorrido»
const FAR_D := 15.0 # la valla va donde la calle se aleja tanto del recorrido
const REGION_MOUTH := 14.0 # en la región: a esta distancia del cruce se mira si la calle sigue el recorrido
const REGION_FAR := 34.0 # …y la valla va a esta
const MAX_FENCES := 90
const SEG := 2.1 # largo de cada tramo de valla (y de cada círculo de colisión)

var track
var _props: Array = [] # [id, x, z]
var _mm: Array = [] # nodos del dibujo
var count := 0

# ───────────────────────── cálculo (puro) ─────────────────────────
## Grilla de 32 m con los tramos del recorrido, para preguntar «¿a cuánto está este punto del recorrido?» sin recorrerlo entero
static func grid_of(pts: PackedVector2Array) -> Dictionary:
	var g := {}
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := maxi(1, int(ceil(a.distance_to(b) / 12.0)))
		for k in n + 1:
			var q := a.lerp(b, float(k) / float(n))
			var c := Vector2i(floori(q.x / 32.0), floori(q.y / 32.0))
			if not g.has(c):
				g[c] = PackedInt32Array()
			var arr: PackedInt32Array = g[c]
			if arr.is_empty() or arr[arr.size() - 1] != i:
				arr.append(i)
				g[c] = arr
	return g

## Distancia de p al recorrido (1e9 si está a más de ~64 m)
static func dist_to(grid: Dictionary, pts: PackedVector2Array, p: Vector2) -> float:
	var best := 1e18
	var c0 := Vector2i(floori(p.x / 32.0), floori(p.y / 32.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var arr: Variant = grid.get(c0 + Vector2i(dx, dz))
			if arr == null:
				continue
			for i in (arr as PackedInt32Array):
				var a := pts[i]
				var ab := pts[i + 1] - a
				var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
				best = minf(best, p.distance_squared_to(a + ab * t))
	return sqrt(best) if best < 1e17 else 1e9

## Bocas de las calles de Dream City que salen del recorrido: [{p, dir, hw}] (dir = hacia dónde se aleja la calle)
static func city_exits(cgps, pts: PackedVector2Array, grid: Dictionary) -> Array:
	var city = cgps.city
	var seen := {}
	var near_nodes := {}
	for q in pts:
		for si in cgps._near(q, 22.0):
			near_nodes[si] = true
	var on_route := {}
	for si in near_nodes:
		var d := dist_to(grid, pts, Vector2(city.s_x[si], city.s_z[si]))
		if d <= ON_ROUTE_D:
			on_route[si] = true
	var out: Array = []
	var done := {}
	for n in on_route:
		for m in (cgps.adj[n] as PackedInt32Array):
			if on_route.has(m) or done.has(m):
				continue
			done[m] = true
			var prev: int = n
			var cur: int = m
			var visited := {n: true}
			for _step in 20:
				var pc := Vector2(city.s_x[cur], city.s_z[cur])
				var d := dist_to(grid, pts, pc)
				if d >= FAR_D:
					var pp := Vector2(city.s_x[prev], city.s_z[prev])
					var key := Vector2i(roundi(pc.x / 7.0), roundi(pc.y / 7.0))
					if not seen.has(key):
						seen[key] = true
						var rd: Dictionary = city.roads[int(city.s_road[cur])]
						out.append({"p": pc, "dir": (pc - pp).normalized(), "hw": float(rd.get("hw", 6.0))})
					break
				visited[cur] = true
				var best := -1
				var bd := -1.0
				for k in (cgps.adj[cur] as PackedInt32Array):
					if visited.has(k) or on_route.has(k):
						continue
					var dk := dist_to(grid, pts, Vector2(city.s_x[k], city.s_z[k]))
					if dk > bd:
						bd = dk
						best = k
				if best < 0:
					break # (calle sin salida a menos de FAR_D del recorrido: no hay nada que cerrar)
				prev = cur
				cur = best
	return out

## Bocas de las calles de la región que salen del recorrido: en cada cruce (nodo con 3 o más calles) pegado al recorrido, las calles que no lo siguen
static func region_exits(rg, pts: PackedVector2Array, grid: Dictionary) -> Array:
	var out: Array = []
	for ni in rg.nodes.size():
		var eds: PackedInt32Array = rg.node_edges[ni]
		if eds.size() < 3:
			continue
		var np: Vector2 = rg.node_pos(ni)
		if dist_to(grid, pts, np) > 9.0:
			continue
		for ei in eds:
			var e: Array = rg.edges[ei]
			var cum: PackedFloat32Array = rg.edge_cum(ei)
			var total: float = cum[cum.size() - 1]
			if total < REGION_FAR + 10.0:
				continue
			var from_a: bool = int(e[0]) == ni
			var s_near := REGION_MOUTH if from_a else total - REGION_MOUTH
			var s_far := REGION_FAR if from_a else total - REGION_FAR
			var q: Vector2 = (rg.point_at(ei, s_near) as Array)[0]
			if dist_to(grid, pts, q) <= 4.0:
				continue # esta calle es el recorrido
			var f: Array = rg.point_at(ei, s_far)
			var dir: Vector2 = (f[1] as Vector2) if from_a else -(f[1] as Vector2)
			out.append({"p": f[0], "dir": dir, "hw": float(rg.e_hw[ei])})
	return out

## Todas las bocas (ciudad y región), las más cercanas al recorrido primero y no más de MAX_FENCES
static func exits_for(cgps, rg, pts: PackedVector2Array) -> Array:
	var grid := grid_of(pts)
	var out: Array = []
	if cgps != null:
		out.append_array(city_exits(cgps, pts, grid))
	if rg != null:
		out.append_array(region_exits(rg, pts, grid))
	if out.size() > MAX_FENCES:
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return dist_to(grid, pts, a["p"]) < dist_to(grid, pts, b["p"]))
		out.resize(MAX_FENCES)
	return out

# ───────────────────────── en la partida ─────────────────────────
## Cierra las calles que salen del recorrido pts; devuelve cuántas vallas puso
func close(p_track, pts: PackedVector2Array, cgps, rg) -> int:
	open()
	track = p_track
	if track == null or pts.size() < 2:
		return 0
	var fences := exits_for(cgps, rg, pts)
	var inst_r: Array = []
	var inst_w: Array = []
	var id := ID0
	for f in fences:
		var d: Vector2 = f["dir"]
		var side := Vector2(-d.y, d.x)
		var half := float(f["hw"]) + 2.5 # calzada + vereda
		var n := maxi(2, int(ceil(half * 2.0 / SEG)))
		for k in n:
			var off := (float(k) - float(n - 1) * 0.5) * SEG
			var c: Vector2 = (f["p"] as Vector2) + side * off
			var y := float(track.ground_y(c.x, c.y))
			# el largo del tramo (eje x local) sigue la dirección lateral: girar θ lleva x a (cos θ, 0, −sin θ)
			var xf := Transform3D(Basis(Vector3.UP, atan2(-side.y, side.x)), Vector3(c.x, y + 0.5, c.y))
			(inst_r if k % 2 == 0 else inst_w).append(xf)
			track.add_prop(id, c.x, c.y, SEG * 0.62)
			_props.append([id, c.x, c.y])
			id += 1
	count = fences.size()
	_mm = [_mmi(inst_r, Color(0.86, 0.12, 0.1)), _mmi(inst_w, Color(0.95, 0.95, 0.93))]
	for m in _mm:
		if track.world_node != null:
			track.world_node.add_child(m)
	return count

func _mmi(xfs: Array, col: Color) -> MultiMeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(SEG * 0.96, 1.0, 0.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	mat.emission_enabled = true # un poco de brillo propio: se ven de noche
	mat.emission = col
	mat.emission_energy_multiplier = 0.25
	bm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Saca las vallas (dibujo y colisión)
func open() -> void:
	if track != null:
		for p in _props:
			track.remove_prop(int(p[0]), float(p[1]), float(p[2]))
	_props.clear()
	for m in _mm:
		if is_instance_valid(m):
			(m as Node).queue_free()
	_mm.clear()
	count = 0
