extends Node3D
## El mundo 3D de la región (todo lo que rodea a Dream City): terreno de montañas y llanuras, caminos, guardarraíles, árboles y los pueblos. Se arma por cuadrados de 256 m alrededor de la
## cámara: los hilos calculan los arreglos y el hilo principal sólo crea las mallas. El terreno tiene tres niveles de detalle (8, 16 y 32 m) y hay un terreno lejano muy simple (cada 400 m)
## que sigue a la cámara y hace de horizonte con las montañas de verdad.

const CityWorld := preload("res://game/city/city_world.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const PaperKit := preload("res://game/fx/paper_kit.gd")
const RegionData := preload("res://game/region/region_data.gd")
const CityProps := preload("res://game/city/city_props.gd")
const Tr := preload("res://game/i18n/tr.gd")
const TEX := "res://game/models/paper/tex/"

const CHUNK := 256.0
const FAR_CELL := 400.0
const FAR_HALF := 14000.0

const C_ASPH := Color(0.50, 0.51, 0.56)
const C_DIRT := Color(0.62, 0.50, 0.36)
const C_GRAVEL := Color(0.68, 0.64, 0.58)
const C_SIDE := Color(0.66, 0.62, 0.50)
const C_YEL := Color(1.0, 0.82, 0.30)
const C_WHT := Color(0.97, 0.96, 0.93)
const BIOME_COL := [Color(0.62, 0.72, 0.42), Color(0.78, 0.70, 0.48), Color(0.45, 0.62, 0.38), Color(0.58, 0.55, 0.52), Color(0.95, 0.96, 0.98), Color(0.28, 0.50, 0.30), Color(0.80, 0.46, 0.30), Color(0.90, 0.82, 0.60), Color(0.45, 0.66, 0.52)]
const TREE_SPACING := [58.0, 90.0, 20.0, 0.0, 0.0, 12.0, 0.0, 0.0, 38.0] # metros entre árboles por bioma (0 = ninguno)

var track # CityTrack
var rg: RegionData
var cw: CityWorld
var view_k := 1.0
var radius := 5 # cuadrados a la redonda
var built_n := 0
var _chunks: Dictionary = {} # Vector2i -> {node, tier}
var _jobs: Dictionary = {} # Vector2i -> {task, tier}
var _done: Dictionary = {}
var _mx := Mutex.new()
var _center := Vector2(1.0e9, 1.0e9)
var _t := 0.0
var _mat_terrain: Material
var _mat_road: Material
var _mat_mark: Material
var _mat_side: StandardMaterial3D
var _mat_rail: StandardMaterial3D
var _tree_mesh: ArrayMesh
var _far: MeshInstance3D
var _far_center := Vector2(1.0e9, 1.0e9)
var _far_job := -1
var _far_res: Dictionary = {}
var _far_center_job := Vector2.ZERO
var _sea: MeshInstance3D
var _places_by_chunk: Dictionary = {}
var _nodes_by_chunk: Dictionary = {}
var _towns: Array = []
var _svc_nodes: Dictionary = {} # "toll_<id>" / "shop_<id>" -> Node3D (los usa CityToll y CityShops para animar barreras y portones)
var _stations_by_chunk: Dictionary = {}
var _tolls_by_chunk: Dictionary = {}
var _shops_by_chunk: Dictionary = {}

func setup(p_track, p_cw) -> void:
	track = p_track
	cw = p_cw
	rg = track.region
	_make_materials()
	_index()
	_sea_plane()

func _make_materials() -> void:
	_mat_terrain = PaperKit.material(null, 0.0, 0.2, 0.25)
	_mat_road = PaperKit.material(load(TEX + "asphalt.png") as Texture2D, 0.28, 0.22, 0.07)
	_mat_mark = PaperKit.material(null, 0.0, 0.2, 0.0)
	_mat_side = StandardMaterial3D.new()
	_mat_side.vertex_color_use_as_albedo = true
	_mat_side.roughness = 1.0
	_mat_side.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_rail = StandardMaterial3D.new()
	_mat_rail.vertex_color_use_as_albedo = true
	_mat_rail.roughness = 0.6
	_mat_rail.metallic = 0.3
	_mat_rail.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.roughness = 1.0
	_mat_tree = tm
	_tree_mesh = _make_tree_mesh()

var _mat_tree: StandardMaterial3D

func _index() -> void:
	# pueblos y ciudades: por cuadrado (con margen: los edificios se salen unos 350 m del centro)
	for i in rg.nodes.size():
		var n: Array = rg.nodes[i]
		var kind := int(n[3])
		if kind < 3 or kind > 5:
			continue
		var ax: Array = n[6]
		if ax.size() < 2:
			continue
		var t := {"i": i, "kind": kind, "name": str(n[4]), "x": float(n[1]), "z": float(n[2]), "ax": Vector2(float(ax[0]), float(ax[1])), "idx": _towns.size()}
		_towns.append(t)
		var m := 380.0
		for cx in range(int(floor((t["x"] - m) / CHUNK)), int(floor((t["x"] + m) / CHUNK)) + 1):
			for cz in range(int(floor((t["z"] - m) / CHUNK)), int(floor((t["z"] + m) / CHUNK)) + 1):
				var k := Vector2i(cx, cz)
				if not _places_by_chunk.has(k):
					_places_by_chunk[k] = []
				(_places_by_chunk[k] as Array).append(t)
	var city = track.city
	for st in city.stations:
		if st.get("region", false):
			_add_to(_stations_by_chunk, st["center"], st)
	for tl in city.tolls:
		if tl.get("region", false):
			_add_to(_tolls_by_chunk, tl["pos"], tl)
	for p in city.pois:
		if p.get("region", false) and str(p["kind"]) == "garage":
			_add_to(_shops_by_chunk, p["pos"], p)
	for i in rg.nodes.size():
		var k2 := Vector2i(int(floor(float(rg.nodes[i][1]) / CHUNK)), int(floor(float(rg.nodes[i][2]) / CHUNK)))
		if not _nodes_by_chunk.has(k2):
			_nodes_by_chunk[k2] = []
		(_nodes_by_chunk[k2] as Array).append(i)

func _add_to(d: Dictionary, pos: Vector2, item) -> void:
	var k := Vector2i(int(floor(pos.x / CHUNK)), int(floor(pos.y / CHUNK)))
	if not d.has(k):
		d[k] = []
	(d[k] as Array).append(item)

func service_node(nm: String) -> Node3D:
	var n: Variant = _svc_nodes.get(nm)
	return n if (n != null and is_instance_valid(n)) else null

## el mar de toda la costa sur (más allá de la ciudad, que ya trae el suyo): un plano a nivel del mar
func _sea_plane() -> void:
	_sea = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(150000.0, 80000.0)
	_sea.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.20, 0.52, 0.70)
	sm.roughness = 0.6
	_sea.material_override = sm
	_sea.position = Vector3(0.0, 0.0, CityLayout.SEA_Z - 100.0 + 40000.0)
	_sea.extra_cull_margin = 100000.0
	_sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sea)

# ───────────────────────── árboles ─────────────────────────
func _make_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, Vector3(0, 0, 0), 0.26, 0.26, 2.0, 5, Color(0.36, 0.25, 0.15))
	_cone(st, Vector3(0, 1.5, 0), 1.9, 0.4, 2.3, 6, Color(0.9, 0.9, 0.9))
	_cone(st, Vector3(0, 3.0, 0), 1.45, 0.3, 2.0, 6, Color(1.0, 1.0, 1.0))
	_cone(st, Vector3(0, 4.2, 0), 0.9, 0.0, 1.9, 6, Color(1.0, 1.0, 1.0))
	st.generate_normals()
	return st.commit()

func _cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, seg: int, col: Color) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p00 := base + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var p01 := base + Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
		var p10 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for tri in [[p00, p10, p01], [p01, p10, p11]]:
			for p in tri:
				st.set_color(col)
				st.add_vertex(p)

# ───────────────────────── carga por cuadrados ─────────────────────────
func warm(p: Vector3) -> void:
	_stream(Vector2(p.x, p.z), 2, true)
	_update_far(Vector2(p.x, p.z), true)

func _process(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and track != null:
		update(cam.global_position, dt)

func region_k(x: float, z: float) -> float:
	return smoothstep(2000.0, 3400.0, sqrt(x * x + z * z))

func update(p: Vector3, dt: float) -> void:
	_t += dt
	_collect()
	var c := Vector2(p.x, p.z)
	var on := region_k(p.x, p.z) > 0.001 and not CityLayout.in_pocket(p.x)
	visible = on
	if not on:
		return
	if c.distance_to(_center) > 40.0 or _t > 1.0:
		_t = 0.0
		_center = c
		_stream(c, maxi(2, int(round(float(radius) * view_k))), false)
	_update_far(c, false)

func _tier_for(k: Vector2i, ck: Vector2i) -> int:
	var d := maxf(absf(float(k.x - ck.x)), absf(float(k.y - ck.y)))
	if d <= 1.0:
		return 0
	if d <= 2.5:
		return 1
	return 2

func _stream(c: Vector2, r: int, sync: bool) -> void:
	var ck := Vector2i(int(floor(c.x / CHUNK)), int(floor(c.y / CHUNK)))
	var want: Array = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if dx * dx + dz * dz > r * r + 1:
				continue
			var k := Vector2i(ck.x + dx, ck.y + dz)
			if _jobs.has(k):
				continue
			var tier := _tier_for(k, ck)
			if _chunks.has(k) and int((_chunks[k] as Dictionary)["tier"]) <= tier and (tier != 2 or int((_chunks[k] as Dictionary)["tier"]) == 2):
				continue
			if _chunks.has(k) and int((_chunks[k] as Dictionary)["tier"]) == tier:
				continue
			if not rg.in_bounds(float(k.x) * CHUNK, float(k.y) * CHUNK) and not rg.in_bounds(float(k.x) * CHUNK + CHUNK, float(k.y) * CHUNK + CHUNK):
				continue
			want.append([k, tier])
	want.sort_custom(func(a: Array, b: Array) -> bool: return ((a[0] as Vector2i) - ck).length_squared() < ((b[0] as Vector2i) - ck).length_squared())
	var started := 0
	for w in want:
		var k: Vector2i = w[0]
		var tier: int = w[1]
		if sync:
			_finish(k, tier, _build(k, tier))
		elif _jobs.size() < 4 and started < 2:
			_jobs[k] = {"task": WorkerThreadPool.add_task(_job.bind(k, tier)), "tier": tier}
			started += 1
	for k in _chunks.keys():
		if (k - ck).length() > float(r) + 2.0:
			var ent: Dictionary = _chunks[k]
			_forget_services(ent["node"] as Node3D)
			(ent["node"] as Node3D).queue_free()
			_chunks.erase(k)

func _job(k: Vector2i, tier: int) -> void:
	var res := _build(k, tier)
	_mx.lock()
	_done[k] = res
	_mx.unlock()

func _collect() -> void:
	_mx.lock()
	var keys := _done.keys()
	var got := {}
	for k in keys.slice(0, 2):
		got[k] = _done[k]
		_done.erase(k)
	_mx.unlock()
	for k in got:
		var jb: Dictionary = _jobs[k]
		WorkerThreadPool.wait_for_task_completion(int(jb["task"]))
		_jobs.erase(k)
		_finish(k, int(jb["tier"]), got[k])

# ───────────────────────── armado de un cuadrado (en un hilo) ─────────────────────────
func _build(k: Vector2i, tier: int) -> Dictionary:
	var x0 := float(k.x) * CHUNK
	var z0 := float(k.y) * CHUNK
	var res := {}
	var terr := CityWorld.Soup.new()
	_terrain(terr, x0, z0, [8.0, 16.0, 32.0][tier], tier)
	res["terrain"] = terr
	var rd := CityWorld.Soup.new()
	var mk := CityWorld.Soup.new()
	var sd := CityWorld.Soup.new()
	var rl := CityWorld.Soup.new()
	_roads(rd, mk, sd, rl, x0, z0, tier)
	res["roads"] = rd
	res["marks"] = mk
	res["sides"] = sd
	res["rails"] = rl
	var bl := CityWorld.Soup.new()
	if tier <= 1:
		_towns_in(bl, k)
	res["buildings"] = bl
	if tier <= 1:
		res["trees"] = _trees(x0, z0)
	return res

func _terrain(s, x0: float, z0: float, step: float, tier: int) -> void:
	var n := int(CHUNK / step)
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	var drop: float = [0.0, 0.5, 2.2][tier]
	for iz in n + 1:
		for ix in n + 1:
			var wx := x0 + float(ix) * step
			var wz := z0 + float(iz) * step
			var hw := rg.height_w(wx, wz)
			hs[iz * (n + 1) + ix] = hw.x - 0.1 - drop * hw.y
	var rr := 0.0
	for iz in n:
		for ix in n:
			var wx := x0 + float(ix) * step
			var wz := z0 + float(iz) * step
			var a := Vector3(wx, hs[iz * (n + 1) + ix], wz)
			var b := Vector3(wx + step, hs[iz * (n + 1) + ix + 1], wz)
			var c := Vector3(wx + step, hs[(iz + 1) * (n + 1) + ix + 1], wz + step)
			var d := Vector3(wx, hs[(iz + 1) * (n + 1) + ix], wz + step)
			var slope := maxf(maxf(absf(a.y - c.y), absf(b.y - d.y)), maxf(absf(a.y - b.y), absf(a.y - d.y))) / step
			s.quad_up(a, d, c, b, _color(wx + step * 0.5, wz + step * 0.5, (a.y + c.y) * 0.5, slope))
	# faldones en los cuatro bordes (los vecinos pueden tener otro nivel de detalle: sin grietas)
	var sk := 7.0
	for i in n:
		var t0 := float(i) * step
		var e0 := Vector3(x0 + t0, hs[i], z0)
		var e1 := Vector3(x0 + t0 + step, hs[i + 1], z0)
		s.quad_out(e0, e1, e1 - Vector3(0, sk, 0), e0 - Vector3(0, sk, 0), Color(0.45, 0.42, 0.36), Vector2(0, -1), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		var f0 := Vector3(x0 + t0, hs[n * (n + 1) + i], z0 + CHUNK)
		var f1 := Vector3(x0 + t0 + step, hs[n * (n + 1) + i + 1], z0 + CHUNK)
		s.quad_out(f0, f1, f1 - Vector3(0, sk, 0), f0 - Vector3(0, sk, 0), Color(0.45, 0.42, 0.36), Vector2(0, 1), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		var g0 := Vector3(x0, hs[i * (n + 1)], z0 + t0)
		var g1 := Vector3(x0, hs[(i + 1) * (n + 1)], z0 + t0 + step)
		s.quad_out(g0, g1, g1 - Vector3(0, sk, 0), g0 - Vector3(0, sk, 0), Color(0.45, 0.42, 0.36), Vector2(-1, 0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		var h0 := Vector3(x0 + CHUNK, hs[i * (n + 1) + n], z0 + t0)
		var h1 := Vector3(x0 + CHUNK, hs[(i + 1) * (n + 1) + n], z0 + t0 + step)
		s.quad_out(h0, h1, h1 - Vector3(0, sk, 0), h0 - Vector3(0, sk, 0), Color(0.45, 0.42, 0.36), Vector2(1, 0), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	rr = rr

## Color del terreno: el de la ciudad cerca de ella, el del bioma lejos; la pendiente fuerte se vuelve roca
func _color(x: float, z: float, y: float, slope: float) -> Color:
	var b := rg.biome_at(x, z)
	var col: Color = BIOME_COL[clampi(b, 0, BIOME_COL.size() - 1)]
	var jit := 0.02 * sin(x * 0.013) * cos(z * 0.011) + 0.015 * sin(x * 0.07 + z * 0.05)
	col = Color(col.r + jit, col.g + jit, col.b + jit)
	if b != 4 and b != 3:
		var rock := smoothstep(0.38, 0.85, slope)
		if rock > 0.0:
			col = col.lerp(Color(0.56 + jit, 0.52 + jit, 0.48 + jit), rock)
	if y > 900.0 and b != 4:
		col = col.lerp(Color(0.95, 0.96, 0.98), smoothstep(900.0, 1000.0, y))
	var r := sqrt(x * x + z * z)
	if r < 4600.0:
		var cc: Color = cw._ground_color(x, z, y)
		col = cc.lerp(col, smoothstep(3300.0, 4600.0, r))
	return col

# ───────────────────────── caminos ─────────────────────────
func _norm_at(k: int, ei: int, p0: int, n: int) -> Vector2:
	var i := k - p0
	var a := rg.edge_point(ei, maxi(i - 1, 0))
	var b := rg.edge_point(ei, mini(i + 1, n - 1))
	var t := (b - a)
	if t.length_squared() < 1e-6:
		return Vector2(0, 1)
	t = t.normalized()
	return Vector2(-t.y, t.x)

func _roads(rd, mk, sd, rl, x0: float, z0: float, tier: int) -> void:
	var seen := {}
	for cx in range(int(floor(x0 / 128.0)), int(floor((x0 + CHUNK) / 128.0)) + 1):
		for cz in range(int(floor(z0 / 128.0)), int(floor((z0 + CHUNK) / 128.0)) + 1):
			var lst: Variant = rg.cells.get(Vector2i(cx, cz))
			if lst == null:
				continue
			for k in (lst as PackedInt32Array):
				if seen.has(k):
					continue
				seen[k] = true
				var ax := float(rg.pts[k * 2]) * 0.1
				var az := float(rg.pts[k * 2 + 1]) * 0.1
				if ax < x0 or ax >= x0 + CHUNK or az < z0 or az >= z0 + CHUNK:
					continue # cada tramo lo arma el cuadrado donde empieza
				_road_segment(rd, mk, sd, rl, k)
	# playones de las gasolineras y gomerías (un disco de pavimento plano; cada uno lo arma el cuadrado donde está su centro)
	var done := {}
	for cx in range(int(floor(x0 / 128.0)), int(floor((x0 + CHUNK) / 128.0)) + 1):
		for cz in range(int(floor(z0 / 128.0)), int(floor((z0 + CHUNK) / 128.0)) + 1):
			var pl: Variant = rg.pad_cells.get(Vector2i(cx, cz))
			if pl == null:
				continue
			for pi in (pl as PackedInt32Array):
				if done.has(pi):
					continue
				done[pi] = true
				var pd: Dictionary = rg.pads[pi]
				var px: float = pd["x"]
				var pz: float = pd["z"]
				if px >= x0 and px < x0 + CHUNK and pz >= z0 and pz < z0 + CHUNK:
					var pr: float = pd["r"]
					var ph: float = float(pd["h"]) + 0.06
					var c0 := Vector3(px, ph, pz)
					for q in 24:
						var a0 := TAU * float(q) / 24.0
						var a1 := TAU * float(q + 1) / 24.0
						rd.tri(c0, Vector3(px + cos(a0) * pr, ph, pz + sin(a0) * pr), Vector3(px + cos(a1) * pr, ph, pz + sin(a1) * pr), Color(0.58, 0.60, 0.65))
	# plazoletas en los cruces
	var kk := Vector2i(int(floor(x0 / CHUNK)), int(floor(z0 / CHUNK)))
	for ni in (_nodes_by_chunk.get(kk, []) as Array):
		if (rg.node_edges[ni] as PackedInt32Array).size() >= 3:
			_junction(rd, int(ni))

func _junction(rd, ni: int) -> void:
	var p := rg.node_pos(ni)
	var hmax := 0.0
	var hh := float((rg.nodes[ni] as Array)[5])
	for ei in (rg.node_edges[ni] as PackedInt32Array):
		hmax = maxf(hmax, rg.e_hw[ei])
	var r := hmax + 0.6
	var c := Vector3(p.x, hh + 0.05, p.y)
	for i in 10:
		var a0 := TAU * float(i) / 10.0
		var a1 := TAU * float(i + 1) / 10.0
		rd.tri(c, Vector3(p.x + cos(a0) * r, hh + 0.05, p.y + sin(a0) * r), Vector3(p.x + cos(a1) * r, hh + 0.05, p.y + sin(a1) * r), C_ASPH)

func _road_segment(rd, mk, sd, rl, k: int) -> void:
	var ei: int = rg.pe[k]
	var e: Array = rg.edges[ei]
	var p0: int = int(e[6])
	var n: int = int(e[7])
	var i := k - p0
	if i + 1 >= n:
		return
	var hw: float = rg.e_hw[ei]
	var surf := int(e[5])
	var cls: String = rg.CLS_NAMES[int(e[2])]
	var a2 := rg.edge_point(ei, i)
	var b2 := rg.edge_point(ei, i + 1)
	var na2 := _norm_at(k, ei, p0, n)
	var nb2 := _norm_at(k + 1, ei, p0, n)
	var off := 0.004 * float(ei % 5)
	var ya: float = rg.hs[k] + 0.03 + off
	var yb: float = rg.hs[k + 1] + 0.03 + off
	var a := Vector3(a2.x, ya, a2.y)
	var b := Vector3(b2.x, yb, b2.y)
	var na := Vector3(na2.x, 0.0, na2.y)
	var nb := Vector3(nb2.x, 0.0, nb2.y)
	var col: Color = [C_ASPH, C_DIRT, C_GRAVEL][clampi(surf, 0, 2)]
	rd.quad_up(a - na * hw, b - nb * hw, b + nb * hw, a + na * hw, col)
	# banquina (tierra clara)
	var sw := 1.9
	var dn := Vector3(0, -0.015, 0)
	for sg in [-1.0, 1.0]:
		var s: float = sg
		sd.quad_up(a + na * (s * hw) + dn, b + nb * (s * hw) + dn, b + nb * (s * (hw + sw)) + dn, a + na * (s * (hw + sw)) + dn, C_SIDE if surf == 0 else col.darkened(0.1))
	# rayas
	if surf == 0 and cls != "tierra":
		var mu := Vector3(0, 0.07, 0)
		var lw := 0.11
		var wide := hw >= 7.0
		if cls == "calle":
			if i % 3 == 0:
				mk.quad_up(a - na * 0.08 + mu, b - nb * 0.08 + mu, b + nb * 0.08 + mu, a + na * 0.08 + mu, C_WHT)
		elif cls == "camino":
			if i % 3 != 2:
				mk.quad_up(a - na * 0.08 + mu, b - nb * 0.08 + mu, b + nb * 0.08 + mu, a + na * 0.08 + mu, C_WHT)
		else:
			if i % 3 != 2 or wide:
				var cc := C_YEL if not wide else C_WHT
				mk.quad_up(a - na * lw + mu, b - nb * lw + mu, b + nb * lw + mu, a + na * lw + mu, cc)
			if wide: # autopista: dos carriles por mano (rayas blancas cortadas a los cuartos)
				for sg in [-0.5, 0.5]:
					var o: float = hw * float(sg)
					if i % 3 != 2:
						mk.quad_up(a + na * (o - 0.08) + mu, b + nb * (o - 0.08) + mu, b + nb * (o + 0.08) + mu, a + na * (o + 0.08) + mu, C_WHT)
			for sg in [-1.0, 1.0]:
				var s2: float = sg
				var o2 := (hw - 0.4) * s2
				mk.quad_up(a + na * (o2 - 0.07) + mu, b + nb * (o2 - 0.07) + mu, b + nb * (o2 + 0.07) + mu, a + na * (o2 + 0.07) + mu, C_WHT)
	# guardarraíl donde el costado cae a un abismo
	if cls in ["montana", "ruta", "provincial", "autopista", "anillo", "conector"] and i % 2 == 0:
		for sg in [-1.0, 1.0]:
			var s3: float = sg
			var q := a2 + na2 * (s3 * (hw + 7.0))
			var drop: float = rg.hs[k] - rg.base_height(q.x, q.y)
			if drop > 2.4:
				_rail(rl, a, b, na, nb, s3, hw + sw * 0.85, i)

func _rail(rl, a: Vector3, b: Vector3, na: Vector3, nb: Vector3, s: float, off: float, i: int) -> void:
	var gcol := Color(0.80, 0.82, 0.84)
	var pa := a + na * (s * off)
	var pb := b + nb * (s * off)
	# la baranda (dos cintas) y los postes
	for hy in [0.45, 0.85]:
		var up := Vector3(0, hy, 0)
		var dn := Vector3(0, hy + 0.28, 0)
		rl.quad(pa + up, pb + up, pb + dn, pa + dn, gcol)
	var pc := Color(0.55, 0.55, 0.58)
	for q in [pa, pb]:
		rl.quad(q + Vector3(-0.07, 0, 0), q + Vector3(0.07, 0, 0), q + Vector3(0.07, 1.0, 0), q + Vector3(-0.07, 1.0, 0), pc)
		rl.quad(q + Vector3(0, 0, -0.07), q + Vector3(0, 0, 0.07), q + Vector3(0, 1.0, 0.07), q + Vector3(0, 1.0, -0.07), pc)

# ───────────────────────── árboles ─────────────────────────
func _hash(n: int) -> int:
	var x := n * 374761393 + 668265263
	x = (x ^ (x >> 13)) * 1274126177
	return (x ^ (x >> 16)) & 0x7fffffff

func _rnd(n: int) -> float:
	return float(_hash(n) % 10000) / 10000.0

func _trees(x0: float, z0: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ck := int(x0 / CHUNK) * 73856093 ^ int(z0 / CHUNK) * 19349663
	for gz in 8:
		for gx in 8:
			var cell := 32.0
			var cxm := x0 + float(gx) * cell
			var czm := z0 + float(gz) * cell
			var mid_b := rg.biome_at(cxm + 16.0, czm + 16.0)
			var sp: float = TREE_SPACING[clampi(mid_b, 0, TREE_SPACING.size() - 1)]
			if sp <= 0.0:
				continue
			var per := (cell / sp) * (cell / sp)
			var cnt := int(per) + (1 if _rnd(ck + gx * 31 + gz * 17 + 1) < fposmod(per, 1.0) else 0)
			for q in cnt:
				var hh := ck + gx * 131 + gz * 977 + q * 7919
				var px := cxm + _rnd(hh + 1) * cell
				var pz := czm + _rnd(hh + 2) * cell
				var pr: PackedFloat64Array = rg.probe(px, pz, 30.0)
				if pr[0] > -1e8 and pr[4] < pr[5] + RegionData.WALL + 4.0:
					continue
				var y: float = rg.height(px, pz)
				if y > 760.0 or y < 0.5:
					continue
				var sc := 0.8 + 0.9 * _rnd(hh + 3)
				if mid_b == 5:
					sc *= 1.5
				out.append_array(PackedFloat32Array([px, y, pz, sc, _rnd(hh + 4) * TAU, float(mid_b)]))
	return out

# ───────────────────────── pueblos ─────────────────────────
func _street_lines(kind: int) -> Array:
	var half: float = [0.0, 0.0, 0.0, 330.0, 270.0, 135.0][kind]
	var lines: Array = []
	if kind == 5:
		for u in [-135.0, -45.0, 45.0, 135.0]:
			lines.append([Vector2(u, -80.0), Vector2(u, 80.0), 3.5])
		lines.append([Vector2(-half, 0.0), Vector2(half, 0.0), 4.7])
	elif kind == 4:
		for u in [-270.0, -180.0, -90.0, 0.0, 90.0, 180.0, 270.0]:
			lines.append([Vector2(u, -150.0), Vector2(u, 150.0), 3.5])
		for v in [-100.0, 100.0]:
			lines.append([Vector2(-270.0, v), Vector2(270.0, v), 3.5])
		lines.append([Vector2(-half, 0.0), Vector2(half, 0.0), 4.7])
	else:
		for u in range(-330, 331, 110):
			lines.append([Vector2(float(u), -260.0), Vector2(float(u), 260.0), 3.5])
		for v in [-220.0, -110.0, 110.0, 220.0]:
			lines.append([Vector2(-330.0, v), Vector2(330.0, v), 3.5])
		lines.append([Vector2(-half, 0.0), Vector2(half, 0.0), 4.7])
	return lines

func _towns_in(s, k: Vector2i) -> void:
	var lst: Variant = _places_by_chunk.get(k)
	if lst == null:
		return
	var x0 := float(k.x) * CHUNK
	var z0 := float(k.y) * CHUNK
	for t in (lst as Array):
		var kind: int = t["kind"]
		var ax: Vector2 = t["ax"]
		var nrm := Vector2(-ax.y, ax.x)
		var c := Vector2(t["x"], t["z"])
		var li := 0
		for ln in _street_lines(kind):
			var a: Vector2 = ln[0]
			var b: Vector2 = ln[1]
			var shw: float = ln[2]
			var L := a.distance_to(b)
			var dir := (b - a) / L
			var lot: float = [18.0, 15.0, 13.0][kind - 3]
			var nlots := int(L / lot)
			var wdir := c + ax * dir.x + nrm * dir.y # el sentido de la calle en el mundo (dir = (du, dv))
			wdir = (ax * dir.x + nrm * dir.y).normalized()
			var side_n := Vector2(-wdir.y, wdir.x)
			for i in nlots:
				for sd in [-1.0, 1.0]:
					var hh := int(t["idx"]) * 100003 + li * 7919 + i * 131 + (0 if sd < 0.0 else 7)
					if _rnd(hh) < 0.18:
						continue
					var u: Vector2 = a + dir * (lot * (float(i) + 0.5) + (_rnd(hh + 1) - 0.5) * 3.0)
					var wc: Vector2 = c + ax * u.x + nrm * u.y
					var dep := 6.5 + 2.5 * _rnd(hh + 2)
					var w: float = lot * (0.55 + 0.3 * _rnd(hh + 3))
					var center_d := Vector2(u.x, u.y).length()
					var hgt := 3.2 + 1.2 * _rnd(hh + 4)
					var hip := true
					if kind == 4:
						hgt = 3.4 + 4.0 * _rnd(hh + 4) * (1.0 if center_d > 120.0 else 1.6)
						hip = _rnd(hh + 5) < 0.6
					elif kind == 3:
						if center_d < 190.0:
							hgt = 9.0 + 20.0 * _rnd(hh + 4)
							w = lot * (0.7 + 0.25 * _rnd(hh + 3))
							dep = 10.0 + 4.0 * _rnd(hh + 2)
							hip = false
						else:
							hgt = 4.0 + 5.0 * _rnd(hh + 4)
							hip = _rnd(hh + 5) < 0.5
					var shw_e := _hw_at(wc, shw)
					var pos: Vector2 = wc + side_n * float(sd) * (shw_e + RegionData.TOWN_WALL + 1.8 + dep * 0.5)
					if pos.x < x0 or pos.x >= x0 + CHUNK or pos.y < z0 or pos.y >= z0 + CHUNK:
						continue
					# que no pise ningún camino
					var pr: PackedFloat64Array = rg.probe(pos.x, pos.y, 20.0)
					if pr[0] > -1e8 and pr[4] < pr[5] + RegionData.TOWN_WALL + 1.8 + dep * 0.5 - 0.5:
						continue
					var y: float = rg.height(pos.x, pos.y)
					var yaw := atan2(wdir.x, wdir.y)
					var wall: Color = CityLayout.WALLS[_hash(hh + 9) % CityLayout.WALLS.size()]
					var roof: Color = CityLayout.ROOFS[_hash(hh + 10) % CityLayout.ROOFS.size()]
					cw._box_building(s, {"x": pos.x, "z": pos.y, "y": y, "yaw": yaw, "w": w, "d": dep, "h": hgt, "wall": wall, "roof": roof, "seed": _rnd(hh + 11), "hip": hip})
			_fence_line(s, k, c, ax, nrm, a, b, shw)
			li += 1

## Medio ancho real de la calle en el punto del eje p (la ruta que atraviesa el pueblo es más ancha que una calle común)
func _hw_at(p: Vector2, shw: float) -> float:
	var pr: PackedFloat64Array = rg.probe(p.x, p.y, 20.0)
	if pr[0] > -1e8 and pr[4] < 2.5:
		return maxf(shw, pr[5])
	return shw

## Cerco bajo (muro con postes) a cada lado de una calle del pueblo, justo donde está la pared invisible: se ve el límite. Se corta en las bocacalles.
func _fence_line(s, k: Vector2i, c: Vector2, ax: Vector2, nrm: Vector2, a: Vector2, b: Vector2, shw: float) -> void:
	const STEP := 6.0
	var x0 := float(k.x) * CHUNK
	var z0 := float(k.y) * CHUNK
	var L := a.distance_to(b)
	var dir := (b - a) / L
	var wdir := (ax * dir.x + nrm * dir.y).normalized()
	var side_n := Vector2(-wdir.y, wdir.x)
	var n := int(L / STEP)
	for i in n:
		var u: Vector2 = a + dir * (STEP * (float(i) + 0.5))
		var axp: Vector2 = c + ax * u.x + nrm * u.y
		if axp.x < x0 - 12.0 or axp.x >= x0 + CHUNK + 12.0 or axp.y < z0 - 12.0 or axp.y >= z0 + CHUNK + 12.0:
			continue
		var shw_e := _hw_at(axp, shw)
		for sd in [-1.0, 1.0]:
			var mid: Vector2 = axp + side_n * float(sd) * (shw_e + RegionData.TOWN_WALL - 0.25)
			if mid.x < x0 or mid.x >= x0 + CHUNK or mid.y < z0 or mid.y >= z0 + CHUNK:
				continue
			var pr: PackedFloat64Array = rg.probe(mid.x, mid.y, 20.0)
			if pr[0] <= -1e8 or absf(pr[4] - (pr[5] + RegionData.TOWN_WALL - 0.25)) > 1.4:
				continue # una bocacalle, otra ruta cerca o un cerco que no sigue a ninguna calle
			var y: float = rg.height(mid.x, mid.y)
			var hh := int(mid.x * 7.0 + mid.y * 13.0)
			var col := Color(0.84, 0.82, 0.77) if (_hash(hh) % 3) != 0 else Color(0.62, 0.38, 0.30)
			_fence_box(s, mid, wdir, STEP * 0.5, y - 0.2, 0.9, 0.11, col)
			if i % 2 == 0: # pilar
				_fence_box(s, mid - wdir * (STEP * 0.5), wdir, 0.22, y - 0.2, 1.35, 0.22, col.darkened(0.12))

## Caja de largo 2·hl (a lo largo de dir), alto h y medio espesor ht, centrada en c; sale del suelo y
func _fence_box(s, c: Vector2, dir: Vector2, hl: float, y: float, h: float, ht: float, col: Color) -> void:
	var nm := Vector2(-dir.y, dir.x)
	var p00 := c - dir * hl - nm * ht
	var p10 := c + dir * hl - nm * ht
	var p11 := c + dir * hl + nm * ht
	var p01 := c - dir * hl + nm * ht
	var t := y + h
	s.quad_up(Vector3(p00.x, t, p00.y), Vector3(p10.x, t, p10.y), Vector3(p11.x, t, p11.y), Vector3(p01.x, t, p01.y), col.lightened(0.08))
	var pts := [p00, p10, p11, p01]
	for i in 4:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % 4]
		var out := ((p + q) * 0.5 - c).normalized()
		s.quad_out(Vector3(p.x, y, p.y), Vector3(p.x, t, p.y), Vector3(q.x, t, q.y), Vector3(q.x, y, q.y), col, out, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

# ───────────────────────── de los hilos a la escena ─────────────────────────
func _finish(k: Vector2i, tier: int, d: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "r%d_%d" % [k.x, k.y]
	var m := ArrayMesh.new()
	_surface(m, d["terrain"], _mat_terrain)
	_surface(m, d["roads"], _mat_road)
	_surface(m, d["sides"], _mat_side)
	_surface(m, d["marks"], _mat_mark)
	_surface(m, d["rails"], _mat_rail)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var bl = d["buildings"]
	if bl.v.size() > 0:
		var bm := ArrayMesh.new()
		_surface(bm, bl, cw._facade_mat)
		var bi := MeshInstance3D.new()
		bi.mesh = bm
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bi)
	if d.has("trees"):
		var tr: PackedFloat32Array = d["trees"]
		var cnt := tr.size() / 6
		if cnt > 0:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = _tree_mesh
			mm.instance_count = cnt
			for i in cnt:
				var sc := tr[i * 6 + 3]
				var b := Basis(Vector3.UP, tr[i * 6 + 4]).scaled(Vector3(sc, sc, sc))
				mm.set_instance_transform(i, Transform3D(b, Vector3(tr[i * 6], tr[i * 6 + 1], tr[i * 6 + 2])))
				var bio := int(tr[i * 6 + 5])
				var col := Color(0.20, 0.42, 0.20)
				match bio:
					0: col = Color(0.30, 0.52, 0.24)
					1: col = Color(0.50, 0.50, 0.30)
					2: col = Color(0.22, 0.46, 0.26)
					5: col = Color(0.12, 0.34, 0.18)
					8: col = Color(0.26, 0.50, 0.36)
				mm.set_instance_color(i, col.lerp(Color.WHITE, 0.0))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = _mat_tree
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 700.0 * maxf(view_k, 0.6)
			root.add_child(mmi)
	# gasolineras, peajes, gomerías y carteles (se arman con las funciones de Dream City: se ven igual)
	for st in (_stations_by_chunk.get(k, []) as Array):
		root.add_child(cw._station(st))
	for tl in (_tolls_by_chunk.get(k, []) as Array):
		var tn: Node3D = cw._toll(tl)
		root.add_child(tn)
		_svc_nodes[tn.name] = tn
	for sp in (_shops_by_chunk.get(k, []) as Array):
		var sn := _shop(sp)
		root.add_child(sn)
		_svc_nodes[sn.name] = sn
	if tier <= 1:
		_signs_in(root, k)
	if _chunks.has(k):
		_forget_services((_chunks[k] as Dictionary)["node"] as Node3D)
		((_chunks[k] as Dictionary)["node"] as Node3D).queue_free()
	_chunks[k] = {"node": root, "tier": tier}
	add_child(root)
	built_n += 1

func _surface(m: ArrayMesh, s, mat: Material) -> void:
	if s.v.size() == 0:
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = s.v
	arr[Mesh.ARRAY_NORMAL] = s.n
	arr[Mesh.ARRAY_COLOR] = s.c
	arr[Mesh.ARRAY_TEX_UV] = s.uv
	arr[Mesh.ARRAY_TEX_UV2] = s.uv2
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(m.get_surface_count() - 1, mat)

# ───────────────────────── terreno lejano ─────────────────────────
func _update_far(c: Vector2, sync: bool) -> void:
	# llegó el resultado del hilo
	_mx.lock()
	var got: Dictionary = _far_res
	_far_res = {}
	_mx.unlock()
	if not got.is_empty():
		if _far_job >= 0:
			WorkerThreadPool.wait_for_task_completion(_far_job)
		_far_job = -1
		var m := ArrayMesh.new()
		_surface(m, got["soup"], _mat_terrain)
		if _far == null:
			_far = MeshInstance3D.new()
			_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_far.extra_cull_margin = 20000.0
			add_child(_far)
		_far.mesh = m
		_far_center = got["center"]
	if _far_job >= 0:
		return
	var snap := Vector2(snappedf(c.x, 1600.0), snappedf(c.y, 1600.0))
	if snap.distance_to(_far_center) < 1.0:
		return
	_far_center_job = snap
	if sync:
		var soup = _far_build(snap)
		_far_res = {"soup": soup, "center": snap}
		_update_far(c, false)
	else:
		_far_job = WorkerThreadPool.add_task(_far_job_run.bind(snap))

func _far_job_run(snap: Vector2) -> void:
	var soup = _far_build(snap)
	_mx.lock()
	_far_res = {"soup": soup, "center": snap}
	_mx.unlock()

func _far_build(c: Vector2):
	var s := CityWorld.Soup.new()
	var n := int(FAR_HALF * 2.0 / FAR_CELL)
	var x0 := c.x - FAR_HALF
	var z0 := c.y - FAR_HALF
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			var wx := x0 + float(ix) * FAR_CELL
			var wz := z0 + float(iz) * FAR_CELL
			# el mínimo de tres muestras y 14 m más abajo: queda siempre por debajo del terreno de cerca
			var h := minf(rg.base_height(wx, wz), minf(rg.base_height(wx + 90.0, wz + 90.0), rg.base_height(wx - 90.0, wz - 90.0)))
			hs[iz * (n + 1) + ix] = h - 14.0
	for iz in n:
		for ix in n:
			var wx := x0 + float(ix) * FAR_CELL
			var wz := z0 + float(iz) * FAR_CELL
			var a := Vector3(wx, hs[iz * (n + 1) + ix], wz)
			var b := Vector3(wx + FAR_CELL, hs[iz * (n + 1) + ix + 1], wz)
			var cc := Vector3(wx + FAR_CELL, hs[(iz + 1) * (n + 1) + ix + 1], wz + FAR_CELL)
			var d := Vector3(wx, hs[(iz + 1) * (n + 1) + ix], wz + FAR_CELL)
			var slope := maxf(absf(a.y - cc.y), absf(b.y - d.y)) / FAR_CELL
			var col := _color(wx + FAR_CELL * 0.5, wz + FAR_CELL * 0.5, (a.y + cc.y) * 0.5 + 14.0, slope * 2.0)
			s.quad_up(a, d, cc, b, col)
	return s


func _forget_services(root: Node3D) -> void:
	for c in root.get_children():
		var nm := str(c.name)
		if nm.begins_with("toll_") or nm.begins_with("shop_"):
			_svc_nodes.erase(nm)

## Gomería: un galpón con el portón (que se abre cuando se frena en el círculo verde), el cartel y el círculo
func _shop(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "shop_" + str(p["id"])
	var pos: Vector2 = p["pos"]
	var nrm: Vector2 = p["dir"]
	var y: float = rg.height(pos.x, pos.y)
	var xf := Transform3D(Basis(Vector3.UP, atan2(nrm.x, nrm.y)), Vector3(pos.x, y, pos.y)) # +z local = hacia el fondo del lote
	var v := PackedVector3Array()
	var cl := PackedColorArray()
	var col: Color = p["color"]
	CityProps.box(v, cl, xf, Vector3(0, 2.75, 6.0), Vector3(14.0, 5.5, 8.0), Color(0.93, 0.92, 0.88))
	CityProps.box(v, cl, xf, Vector3(0, 5.65, 6.0), Vector3(15.0, 0.4, 9.0), col)
	CityProps.box(v, cl, xf, Vector3(-5.2, 1.5, 1.95), Vector3(2.4, 3.0, 0.12), Color(0.16, 0.30, 0.45))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, cl, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# el portón: una hoja que baja hasta el piso (escala en y desde la base)
	var dv := PackedVector3Array()
	var dc := PackedColorArray()
	CityProps.box(dv, dc, Transform3D(), Vector3(0, 2.0, 0), Vector3(5.2, 4.0, 0.16), col.darkened(0.1))
	var dm := ArrayMesh.new()
	PaperKit.add_surface(dm, dv, dc, PaperKit.material(null, 0.0, 0.2, 0.3))
	var door := MeshInstance3D.new()
	door.name = "door"
	door.mesh = dm
	door.transform = Transform3D(Basis(Vector3.UP, atan2(nrm.x, nrm.y)), Vector3(pos.x, y, pos.y)) * Transform3D(Basis(), Vector3(1.0, 0.0, 1.9))
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(door)
	var front: Vector2 = p["front"]
	var ring: MeshInstance3D = cw._circle_mesh(2.7, 3.2, Color(0.20, 0.85, 0.35), Color(0.97, 0.97, 0.97))
	ring.name = "circle"
	ring.position = Vector3(front.x, rg.height(front.x, front.y) + 0.12, front.y)
	root.add_child(ring)
	var face := atan2(-nrm.x, -nrm.y)
	var sp := pos + nrm * 1.8
	root.add_child(cw._label3d(Tr.t(str(p["name"])), Vector3(sp.x, y + 4.6, sp.y), face, 0.012, Color(0.1, 0.1, 0.12), 80))
	return root

## Carteles: el nombre de cada pueblo a la entrada y los destinos con los kilómetros antes de cada cruce
func _signs_in(root: Node3D, k: Vector2i) -> void:
	for t in (_places_by_chunk.get(k, []) as Array):
		var ax: Vector2 = t["ax"]
		var half: float = [0.0, 0.0, 0.0, 330.0, 270.0, 135.0][int(t["kind"])]
		var tipo: String = ["", "", "", "CIUDAD", "PUEBLO", "VILLA"][int(t["kind"])]
		for sgn in [1.0, -1.0]:
			var pos := Vector2(t["x"], t["z"]) + ax * (half + 90.0) * float(sgn)
			var tv := -ax * float(sgn) # sentido de quien llega
			var right := Vector2(-tv.y, tv.x)
			pos += right * 8.5
			if pos.x < float(k.x) * CHUNK or pos.x >= float(k.x + 1) * CHUNK or pos.y < float(k.y) * CHUNK or pos.y >= float(k.y + 1) * CHUNK:
				continue
			root.add_child(_board(pos, tv, "%s\n%s" % [Tr.t(str(t["name"])).to_upper(), Tr.t(tipo)], Color(0.10, 0.42, 0.30), 0.0, 0.016))
	for ni in (_nodes_by_chunk.get(k, []) as Array):
		var nid := str((rg.nodes[ni] as Array)[0])
		if not rg.signs.has(nid):
			continue
		var kind := int((rg.nodes[ni] as Array)[3])
		if kind == 4 or kind == 5 or kind == 3:
			continue # los pueblos ya tienen su cartel; los destinos se ven en los cruces
		var rows: Array = rg.signs[nid]
		var npos := rg.node_pos(ni)
		for ei in (rg.node_edges[ni] as PackedInt32Array):
			var cls := rg.edge_cls(ei)
			if cls == "calle":
				continue
			var e: Array = rg.edges[ei]
			var at_start: bool = int(e[0]) == ni
			var i_near := 5 if at_start else maxi(0, rg.edge_n(ei) - 1 - 5)
			var far_i := 0
			var acc := 0.0
			# punto a ~60 m del cruce sobre esta calle
			var j := 0 if at_start else rg.edge_n(ei) - 1
			var step := 1 if at_start else -1
			while acc < 60.0 and j + step >= 0 and j + step < rg.edge_n(ei):
				acc += rg.edge_point(ei, j).distance_to(rg.edge_point(ei, j + step))
				j += step
			var bp := rg.edge_point(ei, j)
			var tv2 := (npos - bp).normalized()
			var lines: Array = []
			for r in rows:
				if int(r["e"]) == ei:
					continue
				var d := Vector2(cos(deg_to_rad(float(r["ang"]))), sin(deg_to_rad(float(r["ang"]))))
				var turn := rad_to_deg(atan2(tv2.x * d.y - tv2.y * d.x, tv2.dot(d)))
				var arrow := "↑" if absf(turn) < 35.0 else ("→" if turn > 0.0 else "←")
				var km := float(r["km"])
				lines.append("%s %s · %s" % [arrow, Tr.t(str(r["to"])), ("%.0f km" % km) if km >= 10.0 else ("%.1f km" % km)])
			if lines.is_empty():
				continue
			var hw: float = rg.e_hw[ei]
			var rp := bp + Vector2(-tv2.y, tv2.x) * (hw + 6.0)
			if rp.x < float(k.x) * CHUNK or rp.x >= float(k.x + 1) * CHUNK or rp.y < float(k.y) * CHUNK or rp.y >= float(k.y + 1) * CHUNK:
				continue
			lines.sort()
			root.add_child(_board(rp, tv2, "\n".join(lines.slice(0, 4)), Color(0.10, 0.30, 0.62), float(lines.size()), 0.011))

## Un cartel: poste y tablero con texto, de cara a quien viene con rumbo tv (vector unitario)
func _board(pos: Vector2, tv: Vector2, text: String, col: Color, rows: float, px: float) -> Node3D:
	var root := Node3D.new()
	var y: float = rg.height(pos.x, pos.y)
	var yaw := atan2(-tv.x, -tv.y)
	var lines := text.split("\n").size()
	var w := 5.6
	var h := 0.95 * float(lines) + 0.6
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, y, pos.y))
	var v := PackedVector3Array()
	var cl := PackedColorArray()
	CityProps.box(v, cl, xf, Vector3(-w * 0.35, 1.6, 0), Vector3(0.16, 3.2, 0.16), Color(0.45, 0.46, 0.5))
	CityProps.box(v, cl, xf, Vector3(w * 0.35, 1.6, 0), Vector3(0.16, 3.2, 0.16), Color(0.45, 0.46, 0.5))
	CityProps.box(v, cl, xf, Vector3(0, 3.2 + h * 0.5, 0), Vector3(w, h, 0.14), col)
	CityProps.box(v, cl, xf, Vector3(0, 3.2 + h * 0.5, 0.075), Vector3(w - 0.3, h - 0.3, 0.02), col.lightened(0.08))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, cl, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var lab := Label3D.new()
	lab.text = text
	lab.font_size = 56
	lab.pixel_size = px if px > 0.0 else 0.012
	lab.modulate = Color(1, 1, 1)
	lab.outline_size = 0
	lab.line_spacing = 4.0
	lab.double_sided = false
	lab.position = Vector3(pos.x, y + 3.2 + h * 0.5, pos.y) + Vector3(-tv.x, 0.0, -tv.y) * 0.1
	lab.rotation = Vector3(0, yaw, 0)
	root.add_child(lab)
	return root
