extends Node3D
## El mundo de la Red de rutas, armado POR TRAMOS: a medida que el auto avanza se arman (en hilos aparte) los cuadrados de 256 m que lo rodean —camino con su superficie, banquinas, árboles de borde, rotondas y
## estaciones— y se sueltan los que quedaron lejos. El suelo es un plano que acompaña al auto. Nada se arma entero: la red mide más de 1600 km.

const NetData := preload("res://game/net/net_data.gd")

const CHUNK := 256.0
const SHOULDER := 2.2
const SURF_NAMES := ["asphalt", "highway", "dirt", "gravel", "mud", "sand"]

var track
var net
var view_k := 1.0 # 0,6 teléfonos flojos … 1,0 (lo pone la carrera según la calidad)
var radius := 4 # cuadrados de cada lado que se mantienen armados
var road_mats: Array = [] # un material por superficie (SURF_NAMES)
var shoulder_mat: StandardMaterial3D
var tree_mat: StandardMaterial3D
var tree_mesh: ArrayMesh
var ground: MeshInstance3D
var _chunks: Dictionary = {} # Vector2i -> Node3D
var _jobs: Dictionary = {} # Vector2i -> id de tarea
var _done: Dictionary = {} # Vector2i -> arreglos armados por el hilo
var _mx := Mutex.new()
var _center := Vector2(1.0e9, 1.0e9)
var _t := 0.0
var _stations: Dictionary = {} # Vector2i -> [Node3D]
var _base_col := Color.WHITE
var built_n := 0 # cuadrados armados (para las pruebas)

func setup(p_track) -> void:
	track = p_track
	net = track.net
	_make_materials()
	track.road_mat = road_mats[0]
	track.ground_mat = ground.material_override as StandardMaterial3D if ground != null else null

func _make_materials() -> void:
	for i in SURF_NAMES.size():
		var m := StandardMaterial3D.new()
		m.albedo_texture = _road_tex(i)
		m.roughness = 0.92
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		road_mats.append(m)
	shoulder_mat = StandardMaterial3D.new()
	shoulder_mat.albedo_color = Color(0.46, 0.42, 0.34)
	shoulder_mat.roughness = 1.0
	shoulder_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	tree_mat = StandardMaterial3D.new()
	tree_mat.vertex_color_use_as_albedo = true
	tree_mat.roughness = 1.0
	tree_mesh = _make_tree_mesh()
	# suelo: plano grande de pasto que acompaña al auto (la textura se repite cada 8 m)
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = _grass_tex()
	gm.uv1_scale = Vector3(1000.0, 1000.0, 1.0)
	gm.roughness = 1.0
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8000.0, 8000.0)
	ground.mesh = pm
	ground.material_override = gm
	ground.position.y = -0.03
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)

func _grass_tex() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for y in 128:
		for x in 128:
			var q := (rng.randf() - 0.5) * 0.08
			img.set_pixel(x, y, Color(0.30 + q, 0.46 + q, 0.20 + q * 0.5))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Textura de cada superficie (128 × 256: el largo se repite cada 12 m)
func _road_tex(si: int) -> ImageTexture:
	var img := Image.create(128, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5 + si
	var base := [Color(0.20, 0.205, 0.22), Color(0.19, 0.195, 0.21), Color(0.40, 0.31, 0.22), Color(0.52, 0.48, 0.42), Color(0.23, 0.17, 0.12), Color(0.80, 0.70, 0.46)][si] as Color
	var noise := 0.14 if si == 3 else 0.07
	for y in 256:
		for x in 128:
			var q := (rng.randf() - 0.5) * noise
			img.set_pixel(x, y, Color(base.r + q, base.g + q, base.b + q))
	var white := Color(0.92, 0.92, 0.88)
	var yellow := Color(0.96, 0.80, 0.27)
	if si <= 1:
		for y in 256:
			for x in range(5, 10):
				img.set_pixel(x, y, white)
			for x in range(118, 123):
				img.set_pixel(x, y, white)
		if si == 0:
			for y in range(0, 128): # eje amarillo cortado
				for x in range(62, 67):
					img.set_pixel(x, y, yellow)
		else:
			for y in 256: # autopista: doble línea amarilla en el medio y líneas blancas cortadas entre los carriles
				for x in range(58, 62):
					img.set_pixel(x, y, yellow)
				for x in range(66, 70):
					img.set_pixel(x, y, yellow)
			for y in range(0, 128):
				for x in range(30, 34):
					img.set_pixel(x, y, white)
				for x in range(94, 98):
					img.set_pixel(x, y, white)
	else:
		for y in 256: # huellas de las ruedas
			for xs in [38, 90]:
				var ox := int(sin(float(y) * 0.05) * 3.0)
				for x in range(xs - 9 + ox, xs + 9 + ox):
					var px := clampi(x, 0, 127)
					img.set_pixel(px, y, img.get_pixel(px, y).darkened(0.16 if si != 4 else 0.28))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Árbol de poca geometría (tronco + tres conos) con colores de vértice: una sola malla para miles de copias
func _make_tree_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, Vector3(0, 0, 0), 0.28, 0.28, 2.2, 6, Color(0.36, 0.25, 0.15))
	_cone(st, Vector3(0, 1.6, 0), 2.1, 0.5, 2.4, 7, Color(0.15, 0.36, 0.17))
	_cone(st, Vector3(0, 3.1, 0), 1.6, 0.35, 2.1, 7, Color(0.18, 0.42, 0.20))
	_cone(st, Vector3(0, 4.4, 0), 1.0, 0.0, 2.0, 7, Color(0.21, 0.47, 0.22))
	st.generate_normals()
	return st.commit()

func _cone(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, seg: int, col: Color) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10 := base + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var p11 := base + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		for v in [p00, p10, p01, p01, p10, p11]:
			st.set_color(col)
			st.add_vertex(v)
		# base de abajo (se ve desde adelante en las ramas bajas)
		if r0 > r1:
			for v in [base, p01, p00]:
				st.set_color(col.darkened(0.25))
				st.add_vertex(v)

# ───────────────────────── armado por tramos ─────────────────────────
func _process(dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and track != null:
		update(cam.global_position, dt)

func warm(p: Vector3) -> void:
	_stream(Vector2(p.x, p.z), 2, true)

func update(p: Vector3, dt: float) -> void:
	_t += dt
	ground.position.x = snappedf(p.x, 8.0)
	ground.position.z = snappedf(p.z, 8.0)
	_apply_weather_tint()
	_collect()
	var c := Vector2(p.x, p.z)
	if c.distance_to(_center) > 24.0 or _t > 1.0:
		_t = 0.0
		_center = c
		_stream(c, maxi(2, int(round(float(radius) * view_k))), false)

## colores de clima: el clima mueve el color del material del asfalto; las demás superficies lo siguen
func _apply_weather_tint() -> void:
	var m0: StandardMaterial3D = road_mats[0]
	if m0.albedo_color != _base_col:
		_base_col = m0.albedo_color
		for i in range(1, road_mats.size()):
			(road_mats[i] as StandardMaterial3D).albedo_color = _base_col
		shoulder_mat.albedo_color = Color(0.46, 0.42, 0.34) * _base_col

func _stream(c: Vector2, r: int, sync: bool) -> void:
	var ck := Vector2i(int(floor(c.x / CHUNK)), int(floor(c.y / CHUNK)))
	var want: Array = []
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := Vector2i(ck.x + dx, ck.y + dz)
			if dx * dx + dz * dz > r * r + 1:
				continue
			if _chunks.has(k) or _jobs.has(k):
				continue
			if not _has_roads(k):
				_chunks[k] = null # cuadrado sin caminos: no hay nada que armar
				continue
			want.append(k)
	want.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - ck).length_squared() < (b - ck).length_squared())
	for k in want:
		if sync:
			_finish(k, _build(k))
		elif _jobs.size() < 3:
			_jobs[k] = WorkerThreadPool.add_task(_job.bind(k))
	# soltar los lejanos
	for k in _chunks.keys():
		if (k - ck).length() > float(r) + 2.0:
			var n: Variant = _chunks[k]
			if n != null:
				(n as Node3D).queue_free()
			_chunks.erase(k)
			_stations.erase(k)

func _has_roads(k: Vector2i) -> bool:
	var cx0 := int(floor(float(k.x) * CHUNK / NetData.CELL))
	var cz0 := int(floor(float(k.y) * CHUNK / NetData.CELL))
	var per := int(CHUNK / NetData.CELL)
	for dx in per:
		for dz in per:
			if net.grid.has(Vector2i(cx0 + dx, cz0 + dz)):
				return true
	for st in net.stations:
		var p: Vector2 = st["pos"]
		if Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK))) == k:
			return true
	for r in net.rounds:
		if Vector2i(int(floor(float(r["x"]) / CHUNK)), int(floor(float(r["z"]) / CHUNK))) == k:
			return true
	return false

func _job(k: Vector2i) -> void:
	var res := _build(k)
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
		WorkerThreadPool.wait_for_task_completion(_jobs[k])
		_jobs.erase(k)
		_finish(k, got[k])

## Arma (en un hilo) los arreglos del cuadrado k: camino por superficie, banquinas y árboles
func _build(k: Vector2i) -> Dictionary:
	var x0 := float(k.x) * CHUNK
	var z0 := float(k.y) * CHUNK
	var cx0 := int(floor(x0 / NetData.CELL))
	var cz0 := int(floor(z0 / NetData.CELL))
	var per := int(CHUNK / NetData.CELL)
	var road := {} # índice de material -> {v, uv, idx}
	var shv := PackedVector3Array()
	var shi := PackedInt32Array()
	var trees := PackedFloat32Array()
	for dx in per:
		for dz in per:
			var arr: PackedInt32Array = net.grid.get(Vector2i(cx0 + dx, cz0 + dz), PackedInt32Array())
			var q := 0
			while q < arr.size():
				_segment(arr[q], arr[q + 1], road, shv, shi, trees)
				q += 2
	return {"road": road, "shv": shv, "shi": shi, "trees": trees}

func _lat(pts: PackedVector2Array, i: int) -> Vector2:
	var t := Vector2.ZERO
	if i > 0:
		t += (pts[i] - pts[i - 1]).normalized()
	if i < pts.size() - 1:
		t += (pts[i + 1] - pts[i]).normalized()
	t = t.normalized() if t.length() > 0.01 else Vector2(1, 0)
	return Vector2(-t.y, t.x)

func _segment(ei: int, si: int, road: Dictionary, shv: PackedVector3Array, shi: PackedInt32Array, trees: PackedFloat32Array) -> void:
	var pts: PackedVector2Array = net.e_pts[ei]
	var w: float = net.e_w[ei]
	var hw := w * 0.5
	var surf: int = net.e_surf[ei]
	var mi := 1 if (surf == 0 and w > 12.0) else (0 if surf == 0 else surf + 1)
	var cum: PackedFloat32Array = net.e_cum[ei]
	var a := pts[si]
	var b := pts[si + 1]
	var la := _lat(pts, si)
	var lb := _lat(pts, si + 1)
	var y := 0.010 + float(ei % 4) * 0.0035 + (0.006 if mi <= 1 else 0.0)
	if not road.has(mi):
		road[mi] = {"v": PackedVector3Array(), "uv": PackedVector2Array(), "idx": PackedInt32Array()}
	var r: Dictionary = road[mi]
	var v: PackedVector3Array = r["v"]
	var uv: PackedVector2Array = r["uv"]
	var idx: PackedInt32Array = r["idx"]
	var o := v.size()
	v.append(Vector3(a.x - la.x * hw, y, a.y - la.y * hw))
	v.append(Vector3(a.x + la.x * hw, y, a.y + la.y * hw))
	v.append(Vector3(b.x - lb.x * hw, y, b.y - lb.y * hw))
	v.append(Vector3(b.x + lb.x * hw, y, b.y + lb.y * hw))
	var va := cum[si] / 12.0
	var vb := cum[si + 1] / 12.0
	uv.append(Vector2(0, va))
	uv.append(Vector2(1, va))
	uv.append(Vector2(0, vb))
	uv.append(Vector2(1, vb))
	idx.append_array(PackedInt32Array([o, o + 1, o + 2, o + 1, o + 3, o + 2]))
	r["v"] = v
	r["uv"] = uv
	r["idx"] = idx
	# banquinas (una tira a cada lado)
	for side: float in [-1.0, 1.0]:
		var o2 := shv.size()
		var ya := y - 0.006
		shv.append(Vector3(a.x + la.x * side * hw, ya, a.y + la.y * side * hw))
		shv.append(Vector3(a.x + la.x * side * (hw + SHOULDER), ya, a.y + la.y * side * (hw + SHOULDER)))
		shv.append(Vector3(b.x + lb.x * side * hw, ya, b.y + lb.y * side * hw))
		shv.append(Vector3(b.x + lb.x * side * (hw + SHOULDER), ya, b.y + lb.y * side * (hw + SHOULDER)))
		shi.append_array(PackedInt32Array([o2, o2 + 1, o2 + 2, o2 + 1, o2 + 3, o2 + 2]))
	# árboles de borde (la cantidad depende del entorno de la calle)
	var env: int = net.e_env[ei]
	var chance: float = [0.30, 1.1, 0.0, 0.32, 0.22][env]
	if net.e_ring[ei] == 1:
		chance = 0.5
	var h := _hash(ei * 73856093 ^ si * 19349663)
	for side: float in [-1.0, 1.0]:
		var hs := _hash(h + int(side) * 7)
		var rr := float(hs % 1000) / 1000.0
		var cnt := int(chance) + (1 if rr < fposmod(chance, 1.0) else 0)
		for q in cnt:
			var hq := _hash(hs + q * 131)
			var t := float(hq % 1000) / 1000.0
			var off := hw + SHOULDER + 4.0 + float((hq / 1000) % 1000) / 1000.0 * (56.0 if env == 1 else 36.0)
			var p := a.lerp(b, t)
			var l := la.lerp(lb, t).normalized()
			var tx := p.x + l.x * side * off
			var tz := p.y + l.y * side * off
			var pr: Array = net.probe(tx, tz, 22.0)
			if not pr.is_empty() and float(pr[0]) - float(pr[1]) < 9.0:
				continue # no cae sobre otra calle
			trees.append_array(PackedFloat32Array([tx, tz, 0.75 + float((hq / 1000000) % 100) / 100.0 * 0.9, float(hq % 628) / 100.0, float((hq / 7) % 100) / 100.0]))

func _hash(n: int) -> int:
	var x := (n ^ (n >> 15)) * 2246822519 & 0x7fffffff
	x = (x ^ (x >> 13)) * 3266489917 & 0x7fffffff
	return x ^ (x >> 16)

## En el hilo principal: arma los nodos del cuadrado con lo que calculó el hilo
func _finish(k: Vector2i, d: Dictionary) -> void:
	if _chunks.has(k):
		return
	var root := Node3D.new()
	root.name = "N%d_%d" % [k.x, k.y]
	add_child(root)
	_chunks[k] = root
	built_n += 1
	var road: Dictionary = d["road"]
	if not road.is_empty():
		var mesh := ArrayMesh.new()
		var mats: Array = []
		for mi in road:
			var r: Dictionary = road[mi]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = r["v"]
			arr[Mesh.ARRAY_TEX_UV] = r["uv"]
			arr[Mesh.ARRAY_INDEX] = r["idx"]
			var nm := PackedVector3Array()
			nm.resize((r["v"] as PackedVector3Array).size())
			nm.fill(Vector3.UP)
			arr[Mesh.ARRAY_NORMAL] = nm
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			mats.append(road_mats[int(mi)])
		var mi_node := MeshInstance3D.new()
		mi_node.mesh = mesh
		for i in mats.size():
			mi_node.set_surface_override_material(i, mats[i])
		mi_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi_node)
	var shv: PackedVector3Array = d["shv"]
	if not shv.is_empty():
		var sh := ArrayMesh.new()
		var arr2 := []
		arr2.resize(Mesh.ARRAY_MAX)
		arr2[Mesh.ARRAY_VERTEX] = shv
		arr2[Mesh.ARRAY_INDEX] = d["shi"]
		var nm2 := PackedVector3Array()
		nm2.resize(shv.size())
		nm2.fill(Vector3.UP)
		arr2[Mesh.ARRAY_NORMAL] = nm2
		sh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
		var sn := MeshInstance3D.new()
		sn.mesh = sh
		sn.material_override = shoulder_mat
		sn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sn)
	var tr: PackedFloat32Array = d["trees"]
	var nt := tr.size() / 5
	if nt > 0:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tree_mesh
		mm.instance_count = nt
		for i in nt:
			var sc := tr[i * 5 + 2]
			var b := Basis(Vector3.UP, tr[i * 5 + 3]).scaled(Vector3(sc, sc * (0.85 + tr[i * 5 + 4] * 0.5), sc))
			mm.set_instance_transform(i, Transform3D(b, Vector3(tr[i * 5], 0.0, tr[i * 5 + 1])))
			var g := 0.8 + tr[i * 5 + 4] * 0.35
			mm.set_instance_color(i, Color(g, g, g))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = tree_mat
		mmi.visibility_range_end = 650.0 * view_k + 200.0
		root.add_child(mmi)
	# estaciones y rotondas de este cuadrado
	for st in net.stations:
		var p: Vector2 = st["pos"]
		if Vector2i(int(floor(p.x / CHUNK)), int(floor(p.y / CHUNK))) == k:
			root.add_child(_build_station(st))
	for r in net.rounds:
		if Vector2i(int(floor(float(r["x"]) / CHUNK)), int(floor(float(r["z"]) / CHUNK))) == k and bool(r.get("island", true)):
			root.add_child(_build_island(r))

func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, rough := 0.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

## Estación de servicio: playón, techo con columnas y surtidores, el local y un cartel alto que se ve de lejos
func _build_station(st: Dictionary) -> Node3D:
	var n := Node3D.new()
	var p: Vector2 = st["pos"]
	n.position = Vector3(p.x, 0.0, p.y)
	n.rotation.y = float(st["yaw"])
	_box(n, Vector3(46.0, 0.06, 34.0), Vector3(0, 0.03, 0), Color(0.22, 0.225, 0.24), 0.95)
	# techo y columnas (el frente del auto es +z)
	_box(n, Vector3(16.0, 0.5, 9.0), Vector3(0, 5.2, -2.0), Color(0.92, 0.18, 0.15))
	_box(n, Vector3(16.2, 0.12, 9.2), Vector3(0, 4.9, -2.0), Color(0.95, 0.95, 0.95))
	for sx in [-6.5, 6.5]:
		for sz in [-5.5, 1.5]:
			_box(n, Vector3(0.5, 5.0, 0.5), Vector3(sx, 2.5, sz), Color(0.9, 0.9, 0.9))
	for sx in [-4.0, 4.0]:
		_box(n, Vector3(0.7, 1.5, 0.7), Vector3(sx, 0.78, -2.0), Color(0.85, 0.12, 0.12))
		_box(n, Vector3(0.5, 0.5, 0.72), Vector3(sx, 1.2, -2.0), Color(0.1, 0.1, 0.12))
	# local
	_box(n, Vector3(14.0, 4.2, 7.0), Vector3(0, 2.1, -13.0), Color(0.88, 0.86, 0.80))
	_box(n, Vector3(14.6, 0.4, 7.6), Vector3(0, 4.4, -13.0), Color(0.75, 0.15, 0.12))
	_box(n, Vector3(10.0, 2.0, 0.1), Vector3(0, 1.6, -9.46), Color(0.25, 0.4, 0.55), 0.2)
	# cartel alto
	_box(n, Vector3(0.6, 14.0, 0.6), Vector3(-17.0, 7.0, 3.0), Color(0.8, 0.8, 0.82))
	var sign_b := _box(n, Vector3(4.2, 3.2, 0.5), Vector3(-17.0, 15.0, 3.0), Color(0.95, 0.75, 0.1))
	sign_b.visibility_range_end = 4000.0
	var lb := Label3D.new()
	lb.text = "SERVICIO"
	lb.font_size = 72
	lb.pixel_size = 0.012
	lb.modulate = Color(0.1, 0.1, 0.12)
	lb.position = Vector3(0, 0.0, 0.3)
	lb.double_sided = true
	sign_b.add_child(lb)
	return n

## Isla de una rotonda: un montículo de pasto con unos árboles
func _build_island(r: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(float(r["x"]), 0.0, float(r["z"]))
	var rad := float(r["r"]) - float(r["w"]) * 0.5 - SHOULDER - 1.0
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rad
	cm.bottom_radius = rad
	cm.height = 0.5
	cm.radial_segments = 24
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.30, 0.50, 0.22)
	m.roughness = 1.0
	mi.material_override = m
	mi.position.y = 0.2
	n.add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tree_mesh
	mm.instance_count = 22
	for i in 22:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * (rad - 4.0)
		var sc := 0.9 + rng.randf() * 0.8
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(cos(a) * d, 0.45, sin(a) * d)))
		mm.set_instance_color(i, Color(0.9, 0.9, 0.9))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = tree_mat
	n.add_child(mmi)
	return n
