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
const SOLID_ID0 := 40000000 # los objetos sólidos de la región tienen ids por encima de los de la ciudad (índices chicos): el auto los choca pero no los rompe
const ROAD_EPS := 0.12 # la malla del terreno queda al menos tanto por debajo de la calzada (las banquinas van 5 cm más abajo)
const CAP_STEP := 1.5 # cada cuántos metros se mira la calzada para que el terreno no la tape (ver _road_caps)
const JUNCTION_CLEAR := 4.0 # metros más allá del medio ancho de la calle más ancha de un cruce donde no se dibujan rayas (la plazoleta queda lisa, sin rayas cruzadas)
const GORE_MIN_DEG := 9.0 # dos calles que salen del nodo con un ángulo entre este y FILLET_MIN_DEG (una bifurcación): el pasto entre las dos se rellena de pavimento hasta que se separan GORE_GAP m
const GORE_GAP := 6.5
const FILLET_MIN_DEG := 28.0 # esquinas redondeadas en los cruces: entre dos calles vecinas que forman un ángulo entre estos dos
const FILLET_MAX_DEG := 152.0
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
var _jclear: Dictionary = {} # nodo (cruce de 3 o más calles) -> radio dentro del cual no se dibujan rayas
var _svc_nodes: Dictionary = {} # "toll_<id>" / "shop_<id>" -> Node3D (los usa CityToll y CityShops para animar barreras y portones)
var _stations_by_chunk: Dictionary = {}
var _tolls_by_chunk: Dictionary = {}
var _shops_by_chunk: Dictionary = {}
var _solids: Dictionary = {} # Vector2i (cuadrado) -> Array de [id, x, z]: los objetos sólidos de gasolineras, gomerías y peajes de ese cuadrado (para sacarlos al borrarlo)
var _solid_next := SOLID_ID0

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
	_mat_mark = PaperKit.mark_material()
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
		var eds_i: PackedInt32Array = rg.node_edges[i]
		if eds_i.size() >= 3:
			var hm := 0.0
			for ei in eds_i:
				hm = maxf(hm, rg.e_hw[ei])
			_jclear[i] = maxf(hm + JUNCTION_CLEAR, _hub_overlap(i))
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
			_drop_solids(k)
			(ent["node"] as Node3D).queue_free()
			_chunks.erase(k)

func _job(k: Vector2i, tier: int) -> void:
	var res := _build(k, tier)
	_mx.lock()
	_done[k] = res
	_mx.unlock()

## Cuadrados que terminaron en los hilos: se arman en la escena UNO por cuadro, y un segundo sólo si el primero fue barato (< COLLECT_BUDGET_MS). Antes eran 2 por cuadro siempre:
## en el teléfono, al llegar a un pueblo el subir la malla, los edificios y los carteles de dos cuadrados de golpe era un tironcito de fotogramas (reporte del dueño, 19/10/2026).
const COLLECT_BUDGET_MS := 2.5
func _collect() -> void:
	var t0 := Time.get_ticks_usec()
	for _n in 2:
		_mx.lock()
		var keys := _done.keys()
		var k: Variant = null
		var res: Dictionary = {}
		if not keys.is_empty():
			k = keys[0]
			res = _done[k]
			_done.erase(k)
		_mx.unlock()
		if k == null:
			return
		var jb: Dictionary = _jobs[k]
		WorkerThreadPool.wait_for_task_completion(int(jb["task"]))
		_jobs.erase(k)
		_finish(k, int(jb["tier"]), res)
		if float(Time.get_ticks_usec() - t0) / 1000.0 > COLLECT_BUDGET_MS:
			return # (el resto, en el próximo cuadro)

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
	var w := n + 3 # un anillo de vértices de más alrededor del cuadrado: los vértices de los bordes salen iguales en el cuadrado de al lado (sin escalones)
	var drop: float = [0.0, 0.5, 2.2][tier]
	var y0 := PackedFloat32Array()
	y0.resize(w * w)
	for iz in w:
		for ix in w:
			var hw := rg.height_w(x0 + float(ix - 1) * step, z0 + float(iz - 1) * step)
			y0[iz * w + ix] = hw.x - 0.1 - drop * hw.y
	# el terreno nunca tapa la calzada: donde la malla (de 8, 16 o 32 m) quedaría por encima de un camino, los vértices más altos del triángulo se bajan
	var cap := PackedFloat32Array()
	cap.resize(w * w)
	cap.fill(1.0e9)
	_road_caps(x0 - step, z0 - step, step, w, y0, cap)
	var hs := PackedFloat32Array()
	hs.resize((n + 1) * (n + 1))
	for iz in n + 1:
		for ix in n + 1:
			var j := (iz + 1) * w + ix + 1
			hs[iz * (n + 1) + ix] = minf(y0[j], cap[j])
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

## Desfase en altura de cada calle sobre su perfil (m): evita que dos calles que se pisan (cruces) titilen y deja el asfalto por encima de los caminos de tierra y ripio (la tierra no «pinta» sobre el asfalto)
func _road_off(ei: int, surf: int) -> float:
	return 0.004 * float(ei % 5) + (0.02 if surf == 0 else 0.0)

## El terreno nunca tapa un camino. La malla es una grilla de triángulos (con la diagonal de (ix, iz) a (ix+1, iz+1)) y un camino de 7 m que cruza una ladera no cabe en una grilla de 8, 16 o 32 m:
## entre un vértice sobre la calzada y otro más alto afuera, la malla se levantaba por encima del asfalto (tierra y pasto sobre la ruta). Para cada punto de la calzada y de la banquina se calcula la altura
## de la malla ahí (combinación de los 3 vértices del triángulo) y, si queda por encima de la calzada, se baja el «nivel de corte» de esos vértices (los más altos primero; los que ya están abajo no se tocan)
## hasta que la malla pase por debajo. Los puntos salen sólo de la geometría de los caminos y las alturas son las de antes de bajar, así que el cuadrado vecino llega a los mismos valores en los vértices que comparten.
## (ox, oz) es la posición del vértice (0, 0) de la grilla de w×w vértices (con un anillo de más alrededor del cuadrado).
func _road_caps(ox: float, oz: float, step: float, w: int, y0: PackedFloat32Array, cap: PackedFloat32Array) -> void:
	var span := float(w - 1) * step
	var seen := {}
	for cx in range(int(floor((ox - 24.0) / 128.0)), int(floor((ox + span + 24.0) / 128.0)) + 1):
		for cz in range(int(floor((oz - 24.0) / 128.0)), int(floor((oz + span + 24.0) / 128.0)) + 1):
			var k2 := Vector2i(cx, cz)
			var lst: Variant = rg.cells.get(k2)
			if lst != null:
				for k in (lst as PackedInt32Array):
					if seen.has(k):
						continue
					seen[k] = true
					_cap_segment(k, ox, oz, step, w, y0, cap)
			# playones de las gasolineras y gomerías (discos planos a su altura + 6 cm)
			var pl: Variant = rg.pad_cells.get(k2)
			if pl != null:
				for pi in (pl as PackedInt32Array):
					if seen.has(-2 - pi):
						continue
					seen[-2 - pi] = true
					var pd: Dictionary = rg.pads[pi]
					_cap_disc(float(pd["x"]), float(pd["z"]), float(pd["r"]), float(pd["h"]) + 0.06, ox, oz, step, w, y0, cap)
	# plazoletas de los cruces (el disco de asfalto de _junction)
	for kx in range(int(floor((ox - 40.0) / CHUNK)), int(floor((ox + span + 40.0) / CHUNK)) + 1):
		for kz in range(int(floor((oz - 40.0) / CHUNK)), int(floor((oz + span + 40.0) / CHUNK)) + 1):
			for ni in (_nodes_by_chunk.get(Vector2i(kx, kz), []) as Array):
				var eds: PackedInt32Array = rg.node_edges[ni]
				if eds.size() < 3:
					continue
				var hmax := 0.0
				for ei in eds:
					hmax = maxf(hmax, rg.e_hw[ei])
				var np := rg.node_pos(ni)
				_cap_disc(np.x, np.y, hmax + 0.6, float((rg.nodes[ni] as Array)[5]) + 0.05, ox, oz, step, w, y0, cap)
				# las esquinas redondeadas: el terreno queda por debajo del pavimento también ahí
				for fl in _fillets(ni):
					var fc: Vector3 = fl["c"]
					var arc: PackedVector3Array = fl["arc"]
					var fo: Vector2 = fl["o"]
					_cap_point(fc.x, fc.z, fc.y - ROAD_EPS, 0.0, 0.0, ox, oz, step, w, y0, cap)
					for q in arc.size():
						var ap := arc[q]
						_cap_point(ap.x, ap.z, ap.y - ROAD_EPS, 0.0, 0.0, ox, oz, step, w, y0, cap)
						_cap_point((ap.x + fc.x) * 0.5, (ap.z + fc.z) * 0.5, (ap.y + fc.y) * 0.5 - ROAD_EPS, 0.0, 0.0, ox, oz, step, w, y0, cap)
						_cap_point(ap.x + (fo.x - ap.x) * 0.3, ap.z + (fo.y - ap.z) * 0.3, ap.y - 0.05 - ROAD_EPS, 0.0, 0.0, ox, oz, step, w, y0, cap)

## El corte del terreno para una grilla de w×w vértices (el (0, 0) en (ox, oz), separados `step` metros) con las alturas y0: el terreno de la ciudad, más allá de REGION_R, lo usa también
## (su malla de 16 m tapaba los caminos de la región). Devuelve el nivel de corte de cada vértice (1e9 = ninguno).
func road_caps(ox: float, oz: float, step: float, w: int, y0: PackedFloat32Array) -> PackedFloat32Array:
	var cap := PackedFloat32Array()
	cap.resize(w * w)
	cap.fill(1.0e9)
	_road_caps(ox, oz, step, w, y0, cap)
	return cap

func _cap_segment(k: int, ox: float, oz: float, step: float, w: int, y0: PackedFloat32Array, cap: PackedFloat32Array) -> void:
	var ei: int = rg.pe[k]
	var e: Array = rg.edges[ei]
	var i := k - int(e[6])
	if i + 1 >= int(e[7]):
		return
	var a := Vector2(float(rg.pts[k * 2]) * 0.1, float(rg.pts[k * 2 + 1]) * 0.1)
	var b := Vector2(float(rg.pts[k * 2 + 2]) * 0.1, float(rg.pts[k * 2 + 3]) * 0.1)
	var seg_len := a.distance_to(b)
	if seg_len < 0.05:
		return
	var hw: float = rg.e_hw[ei]
	var reach := hw + RegionData.SHOULDER + 3.0
	var span := float(w - 1) * step
	if maxf(a.x, b.x) < ox - reach or minf(a.x, b.x) > ox + span + reach or maxf(a.y, b.y) < oz - reach or minf(a.y, b.y) > oz + span + reach:
		return
	var dir := (b - a) / seg_len
	var nrm := Vector2(-dir.y, dir.x)
	var off := _road_off(ei, int(e[5]))
	var ya: float = rg.hs[k] + 0.03 + off
	var yb: float = rg.hs[k + 1] + 0.03 + off
	var m := maxi(1, int(ceil(seg_len / CAP_STEP)))
	var sw := RegionData.SHOULDER
	var grade := (yb - ya) / seg_len # pendiente del camino (m por m): el tope sigue el plano de la calzada, no un nivel horizontal
	var gx := dir.x * grade
	var gz := dir.y * grade
	for si in m + 1:
		var t := float(si) / float(m)
		var c := a.lerp(b, t)
		var yr := lerpf(ya, yb, t) - ROAD_EPS
		for lat in [-hw - sw, -hw, hw, hw + sw]:
			var l: float = lat
			var target := yr if absf(l) <= hw + 0.01 else yr - 0.05
			_cap_point(c.x + nrm.x * l, c.y + nrm.y * l, target, gx, gz, ox, oz, step, w, y0, cap)

## Un disco plano (playón, plazoleta) a la altura yr: su borde en 16 puntos y los vértices de la grilla que caen adentro
func _cap_disc(cx: float, cz: float, r: float, yr: float, ox: float, oz: float, step: float, w: int, y0: PackedFloat32Array, cap: PackedFloat32Array) -> void:
	var span := float(w - 1) * step
	if cx + r < ox or cx - r > ox + span or cz + r < oz or cz - r > oz + span:
		return
	var target := yr - ROAD_EPS
	for q in 16:
		var an := TAU * float(q) / 16.0
		_cap_point(cx + cos(an) * r, cz + sin(an) * r, target, 0.0, 0.0, ox, oz, step, w, y0, cap)
		_cap_point(cx + cos(an) * r * 0.5, cz + sin(an) * r * 0.5, target, 0.0, 0.0, ox, oz, step, w, y0, cap)
	_cap_point(cx, cz, target, 0.0, 0.0, ox, oz, step, w, y0, cap)
	for iz in range(maxi(0, int(floor((cz - r - oz) / step))), mini(w, int(ceil((cz + r - oz) / step)) + 1)):
		for ix in range(maxi(0, int(floor((cx - r - ox) / step))), mini(w, int(ceil((cx + r - ox) / step)) + 1)):
			var dx := ox + float(ix) * step - cx
			var dz := oz + float(iz) * step - cz
			if dx * dx + dz * dz <= r * r:
				var j := iz * w + ix
				cap[j] = minf(cap[j], target)

## Un punto (px, pz) que tiene que quedar por encima de la malla: si la malla pasa por arriba de `target` se baja el nivel de corte de los vértices del triángulo.
## El camino tiene pendiente (gx, gz son los metros que sube por metro hacia cada eje): se trabaja con las alturas de los vértices «sin la pendiente» (como si el camino fuera horizontal) y el nivel
## de corte se vuelve a inclinar con el camino. Antes todos los vértices se bajaban al mismo nivel, el del punto más bajo del camino dentro del triángulo: en una subida del 7 % y una grilla de 8 m
## el terreno quedaba hasta medio metro por debajo de la calzada (el asfalto parecía flotar y «doblado»).
func _cap_point(px: float, pz: float, target: float, gx: float, gz: float, ox: float, oz: float, step: float, w: int, y0: PackedFloat32Array, cap: PackedFloat32Array) -> void:
	var fx := (px - ox) / step
	var fz := (pz - oz) / step
	var ix := int(floor(fx))
	var iz := int(floor(fz))
	if ix < 0 or iz < 0 or ix >= w - 1 or iz >= w - 1:
		return
	var u := fx - float(ix)
	var v := fz - float(iz)
	var j1 := iz * w + ix
	var j2: int
	var l1: float
	var l2: float
	var l3: float
	var x1 := ox + float(ix) * step
	var z1 := oz + float(iz) * step
	var x3 := x1 + step
	var z3 := z1 + step
	var x2: float
	var z2: float
	if u >= v:
		j2 = j1 + 1
		l1 = 1.0 - u
		l2 = u - v
		l3 = v
		x2 = x3
		z2 = z1
	else:
		j2 = j1 + w
		l1 = 1.0 - v
		l2 = v - u
		l3 = u
		x2 = x1
		z2 = z3
	var j3 := j1 + w + 1
	if l1 * y0[j1] + l2 * y0[j2] + l3 * y0[j3] <= target:
		return
	# alturas sin la pendiente del camino (distancia al punto medida sobre el camino × pendiente)
	var s1 := gx * (x1 - px) + gz * (z1 - pz)
	var s2 := gx * (x2 - px) + gz * (z2 - pz)
	var s3 := gx * (x3 - px) + gz * (z3 - pz)
	var y1 := y0[j1] - s1
	var y2 := y0[j2] - s2
	var y3 := y0[j3] - s3
	# se ordenan los tres vértices de menor a mayor altura
	var t_j: int
	var t_y: float
	var t_l: float
	var t_s: float
	if y1 > y2:
		t_j = j1; t_y = y1; t_l = l1; t_s = s1
		j1 = j2; y1 = y2; l1 = l2; s1 = s2
		j2 = t_j; y2 = t_y; l2 = t_l; s2 = t_s
	if y2 > y3:
		t_j = j2; t_y = y2; t_l = l2; t_s = s2
		j2 = j3; y2 = y3; l2 = l3; s2 = s3
		j3 = t_j; y3 = t_y; l3 = t_l; s3 = t_s
		if y1 > y2:
			t_j = j1; t_y = y1; t_l = l1; t_s = s1
			j1 = j2; y1 = y2; l1 = l2; s1 = s2
			j2 = t_j; y2 = t_y; l2 = t_l; s2 = t_s
	# nivel de corte L: l1·min(y1, L) + l2·min(y2, L) + l3·min(y3, L) = target
	var lvl := target
	if lvl > y1:
		var s_low := l1 * y1
		lvl = (target - s_low) / maxf(l2 + l3, 1.0e-6)
		if lvl > y2:
			s_low += l2 * y2
			lvl = (target - s_low) / maxf(l3, 1.0e-6)
	if l1 > 1.0e-4:
		cap[j1] = minf(cap[j1], lvl + s1)
	if l2 > 1.0e-4:
		cap[j2] = minf(cap[j2], lvl + s2)
	if l3 > 1.0e-4:
		cap[j3] = minf(cap[j3], lvl + s3)

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
			_junction(rd, sd, int(ni))

func _junction(rd, sd, ni: int) -> void:
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
	# esquinas redondeadas entre cada par de calles vecinas
	for f in _fillets(ni):
		var fc: Vector3 = f["c"]
		var arc: PackedVector3Array = f["arc"]
		var col: Color = f["col"]
		for k in arc.size() - 1:
			rd.tri(fc, arc[k], arc[k + 1], col)
		if f.has("gore"):
			continue
		# banquina siguiendo el arco (hacia afuera, donde está el centro del círculo)
		var oc: Vector2 = f["o"]
		var dn := Vector3(0, -0.05, 0)
		for k in arc.size() - 1:
			var ua := (oc - Vector2(arc[k].x, arc[k].z)).normalized() * RegionData.SHOULDER
			var ub := (oc - Vector2(arc[k + 1].x, arc[k + 1].z)).normalized() * RegionData.SHOULDER
			var qa := Vector3(arc[k].x + ua.x, arc[k].y, arc[k].z + ua.y) + dn
			var qb := Vector3(arc[k + 1].x + ub.x, arc[k + 1].y, arc[k + 1].z + ub.y) + dn
			sd.quad_up(arc[k] + dn, arc[k + 1] + dn, qb, qa, C_SIDE if col == C_ASPH else col.darkened(0.1))

## Altura de la calzada de la calle ei a s metros del nodo ni (sin el desfase de la calle)
func _edge_h(ei: int, ni: int, s: float) -> float:
	var e: Array = rg.edges[ei]
	var cum := rg.edge_cum(ei)
	var total := cum[cum.size() - 1]
	var sa := s if int(e[0]) == ni else total - s
	sa = clampf(sa, 0.0, total)
	var lo := 0
	var hi := cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if cum[mid] <= sa:
			lo = mid
		else:
			hi = mid
	var p0 := int(e[6])
	var seg := maxf(cum[hi] - cum[lo], 1.0e-4)
	return lerpf(rg.hs[p0 + lo], rg.hs[p0 + hi], clampf((sa - cum[lo]) / seg, 0.0, 1.0))

## Las esquinas de un cruce: entre cada par de calles vecinas (ordenadas por el ángulo con que salen del nodo) el pavimento cierra la esquina con un arco de círculo tangente a los bordes de
## las dos calles (antes la esquina era un ángulo recto: «cuadrados»). Cada una: {c: la esquina (el punto donde se cortan los dos bordes, con su altura), arc: los puntos del arco (con altura),
## o: centro del círculo, col}. Se arma igual para dibujar (_junction) y para que el terreno no tape el pavimento (_road_caps).
func _fillets(ni: int) -> Array:
	var out: Array = []
	var eds: PackedInt32Array = rg.node_edges[ni]
	if eds.size() < 3:
		return out
	var np := rg.node_pos(ni)
	var rays: Array = []
	for ei in eds:
		var e: Array = rg.edges[ei]
		var cum := rg.edge_cum(ei)
		var total := cum[cum.size() - 1]
		var at_start := int(e[0]) == ni
		var sa := minf(16.0, total * 0.5) if at_start else maxf(total - 16.0, total * 0.5)
		var q: Vector2 = (rg.point_at(ei, sa) as Array)[0]
		var d := q - np
		if d.length() < 4.0:
			continue
		d = d.normalized()
		rays.append({"a": atan2(d.y, d.x), "d": d, "hw": float(rg.e_hw[ei]), "ei": ei, "surf": int(e[5])})
	var n := rays.size()
	if n < 3:
		return out
	rays.sort_custom(func(a, b): return float(a["a"]) < float(b["a"]))
	for k in n:
		var ri: Dictionary = rays[k]
		var rj: Dictionary = rays[(k + 1) % n]
		var phi: float = float(rj["a"]) - float(ri["a"])
		if phi <= 0.0:
			phi += TAU
		var deg := rad_to_deg(phi)
		if deg < GORE_MIN_DEG or deg > FILLET_MAX_DEG:
			continue
		var is_gore := deg < FILLET_MIN_DEG
		var di: Vector2 = ri["d"]
		var dj: Vector2 = rj["d"]
		var hwi: float = ri["hw"]
		var hwj: float = rj["hw"]
		var ni_ := Vector2(-di.y, di.x) # a la izquierda de i: del lado de j
		var mj := Vector2(dj.y, -dj.x) # a la derecha de j: del lado de i
		var rhs := mj * hwj - ni_ * hwi
		var bx := -dj.x
		var by := -dj.y
		var det := di.x * by - di.y * bx
		if absf(det) < 1.0e-4:
			continue
		var t := (rhs.x * by - rhs.y * bx) / det
		var u := (di.x * rhs.y - di.y * rhs.x) / det
		if t < 0.5 or u < 0.5:
			continue
		var cpt := np + di * t + ni_ * hwi # la esquina
		if is_gore:
			# bifurcación: un triángulo de pavimento entre las dos calles, desde la esquina hasta donde sus bordes quedan a GORE_GAP m
			var gl := minf(GORE_GAP / (2.0 * sin(phi * 0.5)), 30.0)
			var ei_a: int = ri["ei"]
			var ei_b: int = rj["ei"]
			var offg := (_road_off(ei_a, int(ri["surf"])) + _road_off(ei_b, int(rj["surf"]))) * 0.5 + 0.03
			var hcg := (_edge_h(ei_a, ni, t) + _edge_h(ei_b, ni, u)) * 0.5 + offg
			var ea := cpt + di * gl
			var eb := cpt + dj * gl
			var garc := PackedVector3Array()
			garc.append(Vector3(ea.x, _edge_h(ei_a, ni, t + gl) + offg, ea.y))
			garc.append(Vector3(eb.x, _edge_h(ei_b, ni, u + gl) + offg, eb.y))
			var gwide: Dictionary = ri if hwi >= hwj else rj
			out.append({"c": Vector3(cpt.x, hcg, cpt.y), "arc": garc, "o": cpt, "col": [C_ASPH, C_DIRT, C_GRAVEL][clampi(int(gwide["surf"]), 0, 2)], "gore": true})
			continue
		var rho := clampf(0.8 * minf(hwi, hwj) + 2.0, 3.5, 9.0)
		var tau := rho / tan(phi * 0.5)
		if tau > 24.0:
			continue
		var bis := (di + dj).normalized()
		var oc := cpt + bis * (rho / sin(phi * 0.5))
		var ti := cpt + di * tau
		var tj := cpt + dj * tau
		var a0 := atan2(ti.y - oc.y, ti.x - oc.x)
		var a1 := atan2(tj.y - oc.y, tj.x - oc.x)
		var da := wrapf(a1 - a0, -PI, PI)
		var m := maxi(3, int(ceil(absf(da) * rho / 1.3)))
		var ei_i: int = ri["ei"]
		var ei_j: int = rj["ei"]
		var off := (_road_off(ei_i, int(ri["surf"])) + _road_off(ei_j, int(rj["surf"]))) * 0.5 + 0.03
		var hc := (_edge_h(ei_i, ni, t) + _edge_h(ei_j, ni, u)) * 0.5 + off
		var hti := _edge_h(ei_i, ni, t + tau) + off
		var htj := _edge_h(ei_j, ni, u + tau) + off
		var arc := PackedVector3Array()
		for q in m + 1:
			var f := float(q) / float(m)
			var an := a0 + da * f
			arc.append(Vector3(oc.x + cos(an) * rho, lerpf(hti, htj, f), oc.y + sin(an) * rho))
		var wide: Dictionary = ri if hwi >= hwj else rj
		var col: Color = [C_ASPH, C_DIRT, C_GRAVEL][clampi(int(wide["surf"]), 0, 2)]
		out.append({"c": Vector3(cpt.x, hc, cpt.y), "arc": arc, "o": oc, "col": col})
	return out

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
	var off := _road_off(ei, surf)
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
	var dn := Vector3(0, -0.05, 0) # la banquina queda por debajo del asfalto de cualquier calle que la cruce
	for sg in [-1.0, 1.0]:
		var s: float = sg
		sd.quad_up(a + na * (s * hw) + dn, b + nb * (s * hw) + dn, b + nb * (s * (hw + sw)) + dn, a + na * (s * (hw + sw)) + dn, C_SIDE if surf == 0 else col.darkened(0.1))
	# rayas (no en la boca de una calle que termina contra otra: las rayas de la calle chica no cruzan la ruta que atraviesa)
	var mouth: bool = (i == 0 and not _is_through(int(e[0]), ei)) or (i == n - 2 and not _is_through(int(e[1]), ei))
	var mid2 := (a2 + b2) * 0.5
	if not mouth and (i < 5 or i > n - 7):
		mouth = _near_junction(int(e[0]), mid2) or _near_junction(int(e[1]), mid2)
	if surf == 0 and cls != "tierra" and not mouth:
		var mu := Vector3(0, PaperKit.MARK_UP, 0) # (el shader de las rayas las sube con la distancia: paper_kit.gd)
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
			if drop > 2.4 and _rail_clear(a, b, na, nb, s3, hw + sw * 0.85, ei):
				_rail(rl, a, b, na, nb, s3, hw + sw * 0.85, i)

## Hasta dónde se pisan las calzadas de un cruce con muchas calles: los bordes de dos calles vecinas que salen con poco ángulo entre sí se cortan a (w1 + w2) / 2 / tan(ángulo / 2) del nodo, y ahí las rayas
## de una calle quedarían encima del asfalto de la otra (un abanico de líneas finas cruzadas en el centro de los pueblos, donde llegan 8 o 9 calles). Hasta ahí no se dibujan rayas.
func _hub_overlap(ni: int) -> float:
	var eds: PackedInt32Array = rg.node_edges[ni]
	var np := rg.node_pos(ni)
	var rays: Array = []
	for ei in eds:
		var e: Array = rg.edges[ei]
		var cum := rg.edge_cum(ei)
		var total := cum[cum.size() - 1]
		var sa := minf(16.0, total * 0.5) if int(e[0]) == ni else maxf(total - 16.0, total * 0.5)
		var q: Vector2 = (rg.point_at(ei, sa) as Array)[0]
		var d := q - np
		if d.length() < 4.0:
			continue
		rays.append([atan2(d.y, d.x), float(rg.e_hw[ei])])
	rays.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	var worst := 0.0
	var n := rays.size()
	for k in n:
		var a: Array = rays[k]
		var b: Array = rays[(k + 1) % n]
		var gap := wrapf(float(b[0]) - float(a[0]), 0.0, TAU)
		if gap < 0.02 or gap > 2.6:
			continue
		worst = maxf(worst, (float(a[1]) + float(b[1])) * 0.5 / tan(gap * 0.5))
	return minf(worst + 3.0, 45.0)

## ¿El punto p está dentro de la plazoleta lisa (sin rayas) de un cruce de 3 o más calles?
func _near_junction(ni: int, p: Vector2) -> bool:
	var r: float = _jclear.get(ni, -1.0)
	return r > 0.0 and p.distance_to(rg.node_pos(ni)) < r

## ¿La calle ei es de las dos más anchas que llegan al nodo ni (la que sigue derecho en un cruce)? Las demás terminan contra ellas.
func _is_through(ni: int, ei: int) -> bool:
	var eds: PackedInt32Array = rg.node_edges[ni]
	if eds.size() < 3:
		return true
	var mine: float = rg.e_hw[ei]
	var rank := 0
	for other in eds:
		if other == ei:
			continue
		var ow: float = rg.e_hw[other]
		if ow > mine or (ow == mine and other < ei):
			rank += 1
	return rank < 2

## El guardarraíl de un costado no se arma donde otra calle pasa por encima de ese costado (la boca de un cruce, un empalme): taparía la entrada
func _rail_clear(a: Vector3, b: Vector3, na: Vector3, nb: Vector3, s: float, off: float, ei: int) -> bool:
	var pa := a + na * (s * off)
	var pb := b + nb * (s * off)
	for t in [0.0, 0.5, 1.0]:
		var p: Vector3 = pa.lerp(pb, t)
		var pr: PackedFloat64Array = rg.probe(p.x, p.z, 12.0, false)
		if pr[0] > -1e8 and int(pr[1]) != ei and pr[4] - pr[5] < 0.6:
			return false
	return true

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
				if rg.corridor(px, pz, 4.0)[0] < 0.0:
					continue # tampoco donde el auto puede llegar (círculos de los cruces, playones)
				# las rutas de la ciudad que atraviesan la región (rurales, atajos, panorámica): tampoco hay árboles de la región encima ni pegados (el bosque de la ruta lo pone la ciudad)
				if track.city.verge_clearance(px, pz) > -14.0:
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
	for sc in rg.secret_sites:
		var sp: Vector2 = sc["pos"]
		if sp.x >= x0 and sp.x < x0 + CHUNK and sp.y >= z0 and sp.y < z0 + CHUNK:
			_monument(s, sp, sc["ax"], rg.height(sp.x, sp.y), str(sc["kind"]) == "auto")
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
					# ni las esquinas de la casa pisan una calle que cruza (la casa mide `w` a lo largo de la calle)
					var on_road := false
					for cs in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
						var cp: Vector2 = pos + wdir * (w * 0.5 * (cs as Vector2).x) + side_n * (dep * 0.5 * (cs as Vector2).y)
						var pc: PackedFloat64Array = rg.probe(cp.x, cp.y, 20.0, false)
						if pc[0] > -1e8 and pc[4] - pc[5] < 1.5:
							on_road = true
							break
					if on_road:
						continue
					var y: float = rg.height(pos.x, pos.y)
					var yaw := atan2(wdir.x, wdir.y)
					var wall: Color = CityLayout.WALLS[_hash(hh + 9) % CityLayout.WALLS.size()]
					var roof: Color = CityLayout.ROOFS[_hash(hh + 10) % CityLayout.ROOFS.size()]
					cw._box_building(s, {"x": pos.x, "z": pos.y, "y": y, "yaw": yaw, "w": w, "d": dep, "h": hgt, "wall": wall, "roof": roof, "seed": _rnd(hh + 11), "hip": hip})
			_fence_line(s, k, c, ax, nrm, a, b, shw)
			li += 1

## Un monumento de piedra con una placa dorada en la manzana del secreto (los de «auto» tienen además un cubo bajo una lona)
func _monument(s, c: Vector2, ax: Vector2, y: float, car: bool) -> void:
	var stone := Color(0.62, 0.60, 0.56)
	var gold := Color(0.95, 0.78, 0.25)
	_fence_box(s, c, ax, 2.2, y - 0.2, 0.7, 2.2, stone.darkened(0.1))
	_fence_box(s, c, ax, 1.0, y, 3.6, 1.0, stone)
	_fence_box(s, c + Vector2(-ax.y, ax.x) * 1.05, ax, 0.6, y + 1.2, 0.9, 0.05, gold)
	if car:
		_fence_box(s, c + ax * 5.5, ax, 2.4, y - 0.2, 1.5, 1.1, Color(0.30, 0.42, 0.55))

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
			# el tramo mide 6 m: sus dos puntas también tienen que seguir a la misma calle (si no, una punta se mete en la calle que cruza)
			var ends_ok := true
			for q in [mid - wdir * (STEP * 0.5), mid + wdir * (STEP * 0.5)]:
				var qq: Vector2 = q
				var pq: PackedFloat64Array = rg.probe(qq.x, qq.y, 20.0)
				if pq[0] <= -1e8 or int(pq[1]) != int(pr[1]) or absf(pq[4] - (pq[5] + RegionData.TOWN_WALL - 0.25)) > 1.4:
					ends_ok = false
					break
			if not ends_ok:
				continue
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
	_drop_solids(k)
	for st in (_stations_by_chunk.get(k, []) as Array):
		root.add_child(cw._station(st))
		root.add_child(_station_props(st, k))
	for tl in (_tolls_by_chunk.get(k, []) as Array):
		var tn: Node3D = cw._toll(tl)
		root.add_child(tn)
		_svc_nodes[tn.name] = tn
		_toll_solids(tl, k)
	for sp in (_shops_by_chunk.get(k, []) as Array):
		var sn := _shop(sp)
		root.add_child(sn)
		_svc_nodes[sn.name] = sn
		_shop_solids(sp, k)
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


## Un objeto sólido (un círculo de choque que no se rompe) de los servicios del cuadrado k
func _add_solid(k: Vector2i, x: float, z: float, r: float) -> void:
	var id := _solid_next
	_solid_next += 1
	track.add_prop(id, x, z, r)
	if not _solids.has(k):
		_solids[k] = []
	(_solids[k] as Array).append([id, x, z])

func _drop_solids(k: Vector2i) -> void:
	var lst: Variant = _solids.get(k)
	if lst == null:
		return
	for it in (lst as Array):
		track.remove_prop(int(it[0]), float(it[1]), float(it[2]))
	_solids.erase(k)

## Los surtidores y los bloques del kiosco de una gasolinera de la región chocan (como los de las gasolineras de la ciudad: nada de esto se rompe) y los surtidores y las columnas se dibujan
func _station_props(st: Dictionary, k: Vector2i) -> MeshInstance3D:
	var nr: Vector2 = st["dir"]
	var yaw := atan2(nr.x, nr.y)
	var v := PackedVector3Array()
	var cl := PackedColorArray()
	for pp in st["pumps"]:
		var q: Vector2 = pp
		CityProps.emit(CityProps.PUMP, q.x, rg.height(q.x, q.y), q.y, yaw + PI, 0.5, Vector2.ZERO, v, cl)
		_add_solid(k, q.x, q.y, CityProps.RADIUS[CityProps.PUMP])
	for pc in st["pillars"]:
		var q2: Vector2 = pc
		CityProps.emit(CityProps.PILLAR, q2.x, rg.height(q2.x, q2.y), q2.y, yaw, 0.5, Vector2.ZERO, v, cl)
		_add_solid(k, q2.x, q2.y, CityProps.RADIUS[CityProps.PILLAR])
	for bc in st["blocks"]:
		var q3: Vector2 = bc
		_add_solid(k, q3.x, q3.y, CityProps.RADIUS[CityProps.BLOCK])
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, cl, PaperKit.material(null, 0.0, 0.2, 0.3))
	var mi := MeshInstance3D.new()
	mi.name = "props_" + str(st["id"])
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## La gomería es un galpón de 14 × 8 m (ver _shop): chocan las paredes (círculos pegados que se pisan, un poco hacia adentro)
func _shop_solids(p: Dictionary, k: Vector2i) -> void:
	var pos: Vector2 = p["pos"]
	var nrm: Vector2 = p["dir"]
	var lx := Vector2(nrm.y, -nrm.x)
	var pts: Array = []
	var x_a := -6.0
	var x_b := 6.0
	var z_a := 3.0
	var z_b := 9.0
	var n_x := int(ceil((x_b - x_a) / 1.8))
	for i in n_x + 1:
		var u := x_a + (x_b - x_a) * float(i) / float(n_x)
		pts.append(Vector2(u, z_a))
		pts.append(Vector2(u, z_b))
	var n_z := int(ceil((z_b - z_a) / 1.8))
	for i in range(1, n_z):
		var w := z_a + (z_b - z_a) * float(i) / float(n_z)
		pts.append(Vector2(x_a, w))
		pts.append(Vector2(x_b, w))
	for q in pts:
		var lp: Vector2 = q
		var wp := pos + lx * lp.x + nrm * lp.y
		_add_solid(k, wp.x, wp.y, 1.7)

## El peaje: la cabina de la isla central y los dos postes del pórtico chocan (la isla baja y los conos se pisan)
func _toll_solids(t: Dictionary, k: Vector2i) -> void:
	var pos: Vector2 = t["pos"]
	var tn: Vector2 = t["tn"]
	var hw: float = t["hw"]
	var lx := Vector2(tn.y, -tn.x)
	for dz in [-1.2, 0.0, 1.2]:
		var c := pos + tn * float(dz)
		_add_solid(k, c.x, c.y, 1.1)
	for sx in [-1.0, 1.0]:
		var c2 := pos + lx * (float(sx) * (hw + 1.0))
		_add_solid(k, c2.x, c2.y, 0.8)

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
