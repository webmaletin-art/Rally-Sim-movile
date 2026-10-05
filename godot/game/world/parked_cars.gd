extends "res://game/world/world_life_system.gd"
## Autos estacionados DETERMINISTAS (Etapa 8). No se guardan: cada lugar de estacionamiento (en el cordón de las calles chicas y los anillos) está ocupado o no según
## WORLD_SEED + calle + lugar + «época» (cada dos días del mundo cambian), así que todos los jugadores ven los mismos autos en los mismos lugares.
## Sólo existen en los sectores ACTIVOS (150 m, con el tope del perfil LOW/MEDIUM/HIGH): un MultiMesh por sector (una llamada de dibujo) y dos círculos de choque por auto
## (sólidos, no se rompen). Al alejarse el sector se libera todo; al volver se reconstruye idéntico.

const WorldSeed := preload("res://game/world/world_seed.gd")
const TrafficRoutine := preload("res://game/world/traffic_routine.gd")
const CityProps := preload("res://game/city/city_props.gd")

const SLOT := 7.0 # largo de un lugar (m)
const MARGIN := 15.0 # distancia al cruce
const EPOCH_DAYS := 2.0
const ID_BASE := 1000000000 # ids de choque (por encima de los de los objetos de la calle: no se rompen)
const KINDS := ["ring", "minor"]
const FILL := 0.36 # fracción de lugares ocupados

var layout: RefCounted
var graph: RefCounted
var track: RefCounted
var root: Node3D
var _built: Dictionary = {} # Vector2i → {node: MultiMeshInstance3D, ids: [[id, x, z]], sig: int}
var _mesh: ArrayMesh
var _mat: StandardMaterial3D
var _next_id := ID_BASE
var _slot_cache: Dictionary = {}
var _n_cars := 0

func _init() -> void:
	system_id = "parked"
	update_hz = 0.5

func attach(p_layout: RefCounted, p_track: RefCounted, p_root: Node3D) -> void:
	layout = p_layout
	graph = p_layout.traffic()
	track = p_track
	root = p_root

func enable() -> void:
	if root != null and not is_instance_valid(root):
		root = null

func disable() -> void:
	for k in _built.keys():
		_free_sector(k)
	_built.clear()
	_slot_cache.clear()
	_n_cars = 0

func rebuild() -> void:
	disable()
	on_sector_changed()

func epoch() -> int:
	var day := float(wl.clock.day_seconds)
	return int(floor(wl.clock.now() / (day * EPOCH_DAYS)))

func seed_v() -> int:
	return wl.state.system_seed("parked")

# ───────────────────────── lógica (pura) ─────────────────────────
## Todos los autos estacionados de un sector (los mismos siempre): [{x, y, z, yaw, hue, sat, val, variant, key}]
func cars_in_sector(cell: Vector2i, ep: int) -> Array:
	var out: Array = []
	var sd := seed_v()
	var hour := fposmod(float(wl.clock.now()) / float(wl.clock.day_seconds), 1.0) * 24.0
	var fill := FILL * TrafficRoutine.parked_factor(hour) # de día hay menos autos en el cordón, de noche más (más ocupación = superconjunto: los mismos más otros)
	var cs: float = graph.CELL
	for li in graph.lanes_in_cell(cell):
		var L: Dictionary = graph.lanes[li]
		if not KINDS.has(str(L["kind"])) or float(L["hw"]) > 5.0 or float(L["hw"]) < 3.5:
			continue
		var len_: float = float(L["len"])
		var i := 0
		var d := MARGIN
		while d <= len_ - MARGIN:
			var key := WorldSeed.hash_ints(sd, int(L["road"]), roundi(float(L["s0"]) * 2.0) * 2 + (0 if int(L["dir"]) == 1 else 1), i, ep)
			d += SLOT
			i += 1
			if float(key & 0xFFFF) / 65536.0 >= fill:
				continue
			var c: Dictionary = graph.lane_at(int(li), d - SLOT)
			var p: Vector3 = c["pos"]
			var tg: Vector2 = c["tan"]
			var right := Vector2(-tg.y, tg.x)
			var push := float(L["hw"]) - 0.8 - float(L["off"]) # del centro del carril al lugar junto al cordón
			var x := p.x + right.x * push
			var z := p.z + right.y * push
			if Vector2i(int(floor(x / cs)), int(floor(z / cs))) != cell:
				continue
			if _near_station(Vector2(x, z)):
				continue
			var k2 := WorldSeed.mix32(key)
			out.append({"x": x, "y": p.y, "z": z, "yaw": c["yaw"], "hue": float((k2 >> 4) & 0xFFF) / 4096.0, "var": (k2 >> 16) % 3, "col": (k2 >> 20) % 10, "key": key})
	return out

func _near_station(p: Vector2) -> bool:
	for st in layout.stations:
		if p.distance_to(st["center"]) < 42.0:
			return true
	return false

## Huella de los autos de los sectores activos (para comprobar que dos teléfonos reconstruyen lo mismo)
func logical_hash() -> int:
	var h := 17
	var ep := epoch()
	var secs: Array = []
	for s in wl.sectors.active:
		secs.append(s)
	secs.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for s in secs:
		for c in cars_in_sector(s, ep):
			h = WorldSeed.combine(h, int(c["key"]))
	return h

# ───────────────────────── instancias ─────────────────────────
func on_sector_changed() -> void:
	if root == null or not is_instance_valid(root) or wl == null or not wl.state.enabled:
		return
	var ep := epoch()
	var cap: int = wl.scaled_cap(int(wl.state.rules.get("max_parked", 48))) # (el estrangulamiento por CPU lo achica)
	var want: Dictionary = {}
	var all: Array = []
	for s in wl.sectors.active:
		var ck := [s, ep, int(fposmod(float(wl.clock.now()) / float(wl.clock.day_seconds), 1.0) * 24.0)] # (la ocupación depende de la hora)
		var cars: Array = _slot_cache.get(ck, [])
		if not _slot_cache.has(ck):
			cars = cars_in_sector(s, ep)
			_slot_cache[ck] = cars
		for c in cars:
			all.append([Vector2(c["x"], c["z"]).distance_squared_to(wl.sectors.player), s, c])
	all.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for e in all.slice(0, cap):
		var s: Vector2i = e[1]
		if not want.has(s):
			want[s] = []
		(want[s] as Array).append(e[2])
	# suelta lo que ya no va y arma lo nuevo o cambiado
	for k in _built.keys():
		if not want.has(k) or int(_built[k]["sig"]) != _sig(want[k]):
			_free_sector(k)
			_built.erase(k)
	for k in want:
		if not _built.has(k):
			_build_sector(k, want[k])
	if _slot_cache.size() > 200:
		_slot_cache.clear()

func _sig(cars: Array) -> int:
	var h := cars.size()
	for c in cars:
		h = WorldSeed.combine(h, int(c["key"]))
	return h

func _ensure_mesh() -> void:
	if _mesh != null:
		return
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var xf := Transform3D.IDENTITY
	var white := Color(1, 1, 1)
	CityProps.box(v, c, xf, Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.3), white)
	CityProps.box(v, c, xf, Vector3(0, 1.1, -0.2), Vector3(1.55, 0.5, 2.3), Color(0.18, 0.24, 0.32))
	CityProps.box(v, c, xf, Vector3(0, 1.38, -0.2), Vector3(1.5, 0.08, 2.1), Color(0.85, 0.85, 0.85))
	for wx in [-0.92, 0.92]:
		for wz in [-1.4, 1.4]:
			CityProps.box(v, c, xf, Vector3(float(wx), 0.32, float(wz)), Vector3(0.22, 0.64, 0.64), Color(0.10, 0.10, 0.12))
	_mesh = ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 0.55
	_mat.metallic = 0.2
	_mesh.surface_set_material(0, _mat)

const NEUTRAL := [Color(0.95, 0.95, 0.95), Color(0.12, 0.12, 0.13), Color(0.55, 0.57, 0.6)]

func _build_sector(cell: Vector2i, cars: Array) -> void:
	_ensure_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mesh
	mm.instance_count = cars.size()
	var ids: Array = []
	for i in cars.size():
		var c: Dictionary = cars[i]
		var sc := Vector3(1.0, 1.0, 1.0)
		match int(c["var"]):
			1: sc = Vector3(1.0, 1.0, 0.88)
			2: sc = Vector3(1.08, 1.22, 1.1)
		var yaw := float(c["yaw"])
		var b := Basis(Vector3.UP, yaw) * Basis.from_scale(sc)
		mm.set_instance_transform(i, Transform3D(b, Vector3(c["x"], c["y"], c["z"])))
		var col: Color
		if int(c["col"]) < 3:
			col = NEUTRAL[int(c["col"])]
		else:
			col = Color.from_hsv(float(c["hue"]), 0.55 + 0.25 * fmod(float(c["hue"]) * 7.0, 1.0), 0.6 + 0.3 * fmod(float(c["hue"]) * 13.0, 1.0))
		mm.set_instance_color(i, col)
		# dos círculos de choque a lo largo del auto (sólidos)
		var fwd := Vector2(sin(yaw), cos(yaw))
		for sgn in [-1.0, 1.0]:
			var q := Vector2(c["x"], c["z"]) + fwd * float(sgn) * 1.2 * sc.z
			var id := _next_id
			_next_id += 1
			track.add_prop(id, q.x, q.y, 1.05)
			ids.append([id, q.x, q.y])
	var mi := MultiMeshInstance3D.new()
	mi.name = "Parked_%d_%d" % [cell.x, cell.y]
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 200.0
	root.add_child(mi)
	_built[cell] = {"node": mi, "ids": ids, "sig": _sig(cars)}
	_n_cars += cars.size()

func _free_sector(cell: Vector2i) -> void:
	var e: Dictionary = _built.get(cell, {})
	if e.is_empty():
		return
	for it in (e["ids"] as Array):
		track.remove_prop(int(it[0]), float(it[1]), float(it[2]))
	var n: Node = e["node"]
	if is_instance_valid(n):
		n.queue_free()
	_n_cars = maxi(0, _n_cars - int((e["ids"] as Array).size() * 0.5))

func stats() -> Dictionary:
	return {"sectors": _built.size(), "cars": _n_cars}
