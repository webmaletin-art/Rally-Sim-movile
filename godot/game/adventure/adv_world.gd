extends Node3D
## Mundo del modo aventura armado por tramos («chunks» de 120 m): solo existe lo que está cerca, sobre todo lo que viene
## adelante (~1,3 km). Cada cuadro se arma un pedacito (con un tope de milisegundos) y se borra lo que quedó atrás.
## Cada tramo tiene: camino (asfalto con líneas, tierra o nieve) y el playón de las estaciones, banquinas y terreno a los
## costados según el ambiente, guardarraíles/alambrados, árboles en dos niveles de detalle, casas y edificios, campos
## sembrados, vacas, postes de luz, carteles y las obras grandes (estaciones, talleres, túneles, puente, paso bajo nivel).

const MB := preload("res://game/adventure/adv_mesh.gd")
const Props := preload("res://game/adventure/adv_props.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const RouteTrack := preload("res://game/track/route_track.gd")

const CH := 48 # muestras por tramo (120 m)
const AHEAD := 1350.0
const BEHIND := 260.0
const ROWS := [0.25, 1.0, 2.5, 4.5, 7.0, 11.0, 17.0, 26.0, 40.0, 60.0, 90.0, 130.0] # filas del terreno pasando la banquina

var track # AdvTrack
var view # vista propia para ubicar cosas
var quality := 1.0 # 0,5 baja · 1 media · 1,4 alta
var nchunks := 0
var chunks := {} # índice → Node3D
var _jobs: Array = [] # [índice, paso]
var _building := -1
var _step := 0
var _cur: Node3D
var mats := {}
var meshes := {}
var plan_buildings: Array = [] # por tramo: lista de casas {xf, w, d, floors, style, color, roof}
var horizon: MeshInstance3D
var road_mat: StandardMaterial3D # el del asfalto (el clima lo moja)
var terrain_mat: StandardMaterial3D
var water_mat: StandardMaterial3D
var tunnel_lamps: Array = []
var branch := false # mundo del ramal de una bifurcación (solo arma ese tramo)
var cross # vista del otro camino de la bifurcación (para que las casas no lo pisen)
var lim := Vector2i(0, 1 << 30) # muestras que arma este mundo

func setup(p_track, p_quality := 1.0) -> void:
	track = p_track
	view = track.make_view()
	quality = p_quality
	nchunks = int(ceil(float(track.n - 1) / float(CH)))
	if branch:
		lim = Vector2i(int(track.split), int(track.join))
	_make_materials()
	_make_meshes()
	_plan_buildings()
	if not branch:
		_build_horizon()

# ───────────────────────── materiales y texturas ─────────────────────────
func _tex_road(kind: String) -> ImageTexture:
	var W := 128
	var H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var base := {"asphalt": Color(0.21, 0.215, 0.23), "dirt": Color(0.47, 0.37, 0.27), "snow": Color(0.86, 0.88, 0.92), "conc": Color(0.6, 0.6, 0.58), "mine": Color(0.4, 0.3, 0.24)}[kind] as Color
	for y in H:
		for x in W:
			var q := (rng.randf() - 0.5) * (0.06 if kind != "snow" else 0.04)
			img.set_pixel(x, y, Color(base.r + q, base.g + q, base.b + q))
	match kind:
		"asphalt":
			# bordes blancos y línea amarilla discontinua al medio
			img.fill_rect(Rect2i(5, 0, 4, H), Color(0.9, 0.9, 0.86))
			img.fill_rect(Rect2i(W - 9, 0, 4, H), Color(0.9, 0.9, 0.86))
			img.fill_rect(Rect2i(62, 0, 4, 120), Color(0.95, 0.76, 0.22))
			# parches y manchas
			for k in 30:
				var c := img.get_pixel(rng.randi() % W, rng.randi() % H)
				img.fill_rect(Rect2i(rng.randi() % (W - 12), rng.randi() % (H - 12), 4 + rng.randi() % 10, 4 + rng.randi() % 10), c.darkened(0.08))
		"dirt", "mine":
			# huellas de las ruedas: dos franjas más oscuras y piedritas
			for y in H:
				for xs: int in [36, 92]:
					var ox := int(sin(float(y) * 0.05) * 3.0)
					for x in range(xs - 10 + ox, xs + 10 + ox):
						var c := img.get_pixel(clampi(x, 0, W - 1), y)
						img.set_pixel(clampi(x, 0, W - 1), y, c.darkened(0.13))
			for k in 900:
				var g := 0.3 + rng.randf() * 0.4
				img.set_pixel(rng.randi() % W, rng.randi() % H, Color(g, g * 0.9, g * 0.8))
		"snow":
			for y in H:
				for xs: int in [36, 92]:
					var ox := int(sin(float(y) * 0.04) * 2.0)
					for x in range(xs - 8 + ox, xs + 8 + ox):
						var c := img.get_pixel(clampi(x, 0, W - 1), y)
						img.set_pixel(clampi(x, 0, W - 1), y, c.darkened(0.16))
		"conc":
			for y in range(0, H, 64):
				img.fill_rect(Rect2i(0, y, W, 1), base.darkened(0.2))
			img.fill_rect(Rect2i(0, 0, 1, H), base.darkened(0.2))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _mat_road(kind: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex_road(kind)
	m.roughness = 0.9 if kind != "snow" else 0.7
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _make_materials() -> void:
	mats["asphalt"] = _mat_road("asphalt")
	mats["dirt"] = _mat_road("dirt")
	mats["snow"] = _mat_road("snow")
	mats["conc"] = _mat_road("conc")
	road_mat = mats["asphalt"]
	var tm := StandardMaterial3D.new()
	tm.vertex_color_use_as_albedo = true
	tm.albedo_texture = RouteTrack.grass_texture()
	tm.uv1_scale = Vector3(1, 1, 1)
	tm.roughness = 1.0
	terrain_mat = tm
	mats["terrain"] = tm
	mats["vc"] = Props.material("vc")
	mats["metal"] = Props.material("metal")
	mats["emis"] = Props.material("emis")
	mats["atlas"] = Props.material("atlas")
	var tr := StandardMaterial3D.new()
	tr.vertex_color_use_as_albedo = true
	tr.roughness = 1.0
	mats["tree"] = tr
	var ru := StandardMaterial3D.new()
	ru.vertex_color_use_as_albedo = true
	ru.roughness = 0.4
	ru.metallic = 0.55
	ru.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["rail"] = ru
	var wi := StandardMaterial3D.new()
	wi.vertex_color_use_as_albedo = true
	wi.roughness = 0.6
	wi.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["wire"] = wi
	water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.18, 0.32, 0.38)
	water_mat.roughness = 0.08
	water_mat.metallic = 0.3
	mats["water"] = water_mat
	mats["corn"] = _card_mat(_tex_corn())
	mats["wheat"] = _card_mat(_tex_wheat())

func _card_mat(t: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.vertex_color_use_as_albedo = true
	return m

## Maizal: plantas altas con hojas largas (textura con transparencia, 4 m de largo por 2,3 m de alto)
func _tex_corn() -> ImageTexture:
	var W := 256
	var H := 128
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for p in 11:
		var x0 := 8.0 + float(p) * 22.0 + rng.randf() * 8.0
		var g := Color(0.28 + rng.randf() * 0.1, 0.48 + rng.randf() * 0.1, 0.18, 1.0)
		for y in range(H - 1, 6, -1):
			var w := 2 if y > 30 else 1
			for dx in range(-w, w + 1):
				img.set_pixel(clampi(int(x0) + dx, 0, W - 1), y, g.darkened(0.15))
		for l in 7:
			var ly := 20.0 + float(l) * 14.0 + rng.randf() * 6.0
			var dir := -1.0 if l % 2 == 0 else 1.0
			var ln := 14.0 + rng.randf() * 12.0
			for t in int(ln):
				var xx := x0 + dir * float(t)
				var yy := ly + float(t * t) * 0.03
				for k in 3:
					img.set_pixel(clampi(int(xx), 0, W - 1), clampi(int(yy) + k - 1, 0, H - 1), g.lightened(0.05 * float(k)))
		# espiga arriba
		for y in range(2, 14):
			img.set_pixel(clampi(int(x0), 0, W - 1), y, Color(0.8, 0.7, 0.35, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Trigo: matas doradas cortas
func _tex_wheat() -> ImageTexture:
	var W := 128
	var H := 64
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 70:
		var x0 := rng.randf() * float(W)
		var h := rng.randf_range(0.6, 0.95) * float(H)
		var lean := rng.randf_range(-0.2, 0.2)
		var c := Color(0.78 + rng.randf() * 0.1, 0.64 + rng.randf() * 0.1, 0.3, 1.0)
		for j in int(h):
			var xx := int(x0 + lean * float(j))
			img.set_pixel(clampi(xx, 0, W - 1), H - 1 - j, c.darkened(0.2 * (1.0 - float(j) / h)))
		for j in 6:
			var xx := int(x0 + lean * h)
			img.set_pixel(clampi(xx, 0, W - 1), clampi(H - int(h) + j, 0, H - 1), c.lightened(0.15))
			img.set_pixel(clampi(xx + 1, 0, W - 1), clampi(H - int(h) + j, 0, H - 1), c.lightened(0.1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Mallas compartidas: árboles (cerca y lejos), girasoles, matas, vacas
func _make_meshes() -> void:
	meshes["pine"] = Props.pine(17).commit(mats["tree"])
	meshes["pine_lo"] = Props.pine(17, false, true).commit(mats["tree"])
	meshes["spine"] = Props.pine(23, true).commit(mats["tree"])
	meshes["spine_lo"] = Props.pine(23, true, true).commit(mats["tree"])
	meshes["broad"] = Props.broadleaf(5).commit(mats["tree"])
	meshes["broad_lo"] = Props.broadleaf(5, true).commit(mats["tree"])
	meshes["poplar"] = Props.poplar(9).commit(mats["tree"])
	meshes["poplar_lo"] = Props.poplar(9, true).commit(mats["tree"])
	meshes["bush"] = Props.bush(4).commit(mats["tree"])
	meshes["rock"] = Props.rock(8).commit(mats["vc"])
	meshes["sunflower"] = _sunflower_row().commit(mats["vc"])
	var wq := QuadMesh.new()
	wq.size = Vector2(1.6, 0.8)
	wq.center_offset = Vector3(0, 0.4, 0)
	wq.material = mats["wheat"]
	meshes["wheat"] = wq

## Fila corta de 4 girasoles (tallo, hojas y la flor mirando al sol)
func _sunflower_row() -> RefCounted:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 4:
		var x := float(k) * 1.0 + rng.randf_range(-0.15, 0.15)
		var h := rng.randf_range(1.5, 1.9)
		var stem := Color(0.25, 0.42, 0.16)
		b.box(Transform3D(Basis(), Vector3(x, h * 0.5, 0)), Vector3(0.05, h, 0.05), stem)
		b.quad(Vector3(x - 0.3, h * 0.5, 0.0), Vector3(x, h * 0.5 + 0.08, 0.0), Vector3(x, h * 0.5 + 0.25, 0.1), Vector3(x - 0.3, h * 0.5 + 0.2, 0.15), stem.lightened(0.1))
		b.quad(Vector3(x + 0.3, h * 0.45, 0.0), Vector3(x + 0.3, h * 0.45 + 0.2, 0.15), Vector3(x, h * 0.45 + 0.25, 0.1), Vector3(x, h * 0.45 + 0.08, 0.0), stem.lightened(0.1))
		# flor: pétalos amarillos y el centro marrón, inclinada hacia adelante
		var c := Vector3(x, h, 0.08)
		var pts: Array = []
		for p in 10:
			var a := TAU * float(p) / 10.0
			var r := 0.30 if p % 2 == 0 else 0.22
			pts.append(c + Vector3(cos(a) * r, sin(a) * r * 0.95, -sin(a) * r * 0.25))
		for p in 10:
			b.tri(c + Vector3(0, 0, 0.02), pts[p], pts[(p + 1) % 10], Color(0.98, 0.78, 0.08))
			b.tri(c + Vector3(0, 0, -0.04), pts[(p + 1) % 10], pts[p], Color(0.5, 0.42, 0.1))
		for p in 6:
			var a0 := TAU * float(p) / 6.0
			var a1 := TAU * float(p + 1) / 6.0
			b.tri(c + Vector3(0, 0, 0.05), c + Vector3(cos(a0) * 0.13, sin(a0) * 0.13, 0.03), c + Vector3(cos(a1) * 0.13, sin(a1) * 0.13, 0.03), Color(0.32, 0.2, 0.08))
	return b

# ───────────────────────── manejo de tramos ─────────────────────────
## Arma ya (sin repartir en cuadros) lo que hay entre s0 y s1 metros: para la pantalla de carga
func build_now(s0: float, s1: float) -> void:
	var c0 := _chunk_at(s0)
	var c1 := _chunk_at(s1)
	for ci in range(c0, c1 + 1):
		if not chunks.has(ci):
			_build_chunk_sync(ci)

func _chunk_at(s: float) -> int:
	return clampi(int(track.idx_at(clampf(s, 0.0, track.length)) / CH), 0, nchunks - 1)

## Cada cuadro: con la posición del jugador (m sobre la ruta) arma lo que falta adelante y borra lo de atrás.
## Cada tramo se arma entero en otro hilo (mallas y nodos fuera del árbol de la escena) y acá solo se agrega: no hay tirones.
var _task := -1
var _task_ci := -1
var _task_node: Node3D

func update(s: float, _budget_ms := 3.5) -> void:
	var c0 := _chunk_at(s - BEHIND)
	var c1 := _chunk_at(s + AHEAD * quality_reach())
	if branch:
		c0 = maxi(c0, lim.x / CH)
		c1 = mini(c1, lim.y / CH)
	for ci in chunks.keys():
		var k: int = ci
		if k < c0 - 1 or k > c1 + 2:
			(chunks[k] as Node3D).queue_free()
			chunks.erase(k)
	if _task != -1:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _task_ci >= c0 - 1 and _task_ci <= c1 + 2 and not chunks.has(_task_ci):
			add_child(_task_node)
			chunks[_task_ci] = _task_node
		else:
			_task_node.queue_free()
		_task_node = null
	# el que falta más cerca (primero adelante)
	var best := -1
	for ci in range(c0, c1 + 1):
		if not chunks.has(ci):
			best = ci
			break
	if best < 0:
		return
	_task_ci = best
	_task = WorkerThreadPool.add_task(_chunk_job.bind(best), false, "tramo de la aventura")

func _chunk_job(ci: int) -> void:
	var node := Node3D.new()
	node.name = "tramo%d" % ci
	_cur = node
	for st in STEPS:
		_run_step(ci, st)
	_task_node = node

## Antes de borrar el mundo: que no quede un tramo armándose
func _exit_tree() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _task_node != null:
			_task_node.queue_free()

func quality_reach() -> float:
	return 0.8 if quality < 0.8 else 1.0

const STEPS := 6
func _build_chunk_sync(ci: int) -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _task_node != null:
			_task_node.queue_free()
			_task_node = null
	_cur = Node3D.new()
	_cur.name = "tramo%d" % ci
	for st in STEPS:
		_run_step(ci, st)
	add_child(_cur)
	chunks[ci] = _cur
	_building = -1

var _prof := OS.get_cmdline_user_args().has("--advprof")
var prof_ms := PackedFloat64Array([0, 0, 0, 0, 0, 0])
var prof_n := 0
func _run_step(ci: int, st: int) -> void:
	var t0 := Time.get_ticks_usec()
	_run_step2(ci, st)
	if _prof:
		prof_ms[st] += float(Time.get_ticks_usec() - t0) / 1000.0
		if st == STEPS - 1:
			prof_n += 1
			if prof_n % 10 == 0:
				print("TRAMOS %d · ms por paso (camino, terreno, rieles, árboles, pueblo/campo, obras): %s" % [prof_n, str(Array(prof_ms).map(func(x): return snappedf(x / float(prof_n), 0.01)))])

func _run_step2(ci: int, st: int) -> void:
	var a := ci * CH
	var b := mini(track.n - 1, (ci + 1) * CH)
	if branch:
		# el ramal: el camino desde que se separa; el terreno y lo demás un poco después (al principio se pisa con el principal)
		var m := 0 if st == 0 else 10
		a = maxi(a, lim.x + m)
		b = mini(b, lim.y - m)
		if b <= a:
			return
	match st:
		0: _build_road(a, b)
		1: _build_terrain(a, b)
		2: _build_rails(a, b)
		3: _build_trees(ci, a, b)
		4: _build_town_and_fields(ci, a, b)
		5: _build_structures(ci, a, b)

func _add_mesh(m: Mesh, shadow := false, vis_end := 0.0) -> MeshInstance3D:
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vis_end > 0.0:
		mi.visibility_range_end = vis_end
	_cur.add_child(mi)
	return mi

# ───────────────────────── camino ─────────────────────────
func _surf_kind(i: int) -> String:
	var f := int(track.flaga[i])
	if (f & AdvRoute.F_MINE) != 0:
		return "dirt"
	match int(track.surfa[i]):
		1: return "dirt"
		6: return "snow"
	return "asphalt"

func _build_road(a: int, b: int) -> void:
	# una superficie por tipo de piso dentro del tramo
	var runs := {}
	for i in range(a, b):
		var k := _surf_kind(i)
		if not runs.has(k):
			runs[k] = MB.new()
		var mb: RefCounted = runs[k]
		_road_quad(mb, i, i + 1, k)
	var mesh: ArrayMesh = null
	for k in runs:
		mesh = (runs[k] as RefCounted).commit(mats[k], mesh)
	_add_mesh(mesh)
	# playón de estaciones y talleres (hormigón) a la derecha
	var lb := MB.new()
	for i in range(a, b):
		var l0: float = track.laya[i]
		var l1: float = track.laya[i + 1]
		if l0 < 0.05 and l1 < 0.05:
			continue
		var p0: Vector3 = track.samples[i]
		var p1: Vector3 = track.samples[i + 1]
		var L0: Vector3 = track.laterals[i]
		var L1: Vector3 = track.laterals[i + 1]
		var h0: float = track.hwa[i]
		var h1: float = track.hwa[i + 1]
		var y0: float = track.cy[i] + 0.012
		var y1: float = track.cy[i + 1] + 0.012
		var v0 := float(track.cum[i]) / 8.0
		var v1 := float(track.cum[i + 1]) / 8.0
		lb.quad(Vector3(p0.x + L0.x * h0, y0, p0.z + L0.z * h0), Vector3(p0.x + L0.x * (h0 + l0), y0, p0.z + L0.z * (h0 + l0)),
			Vector3(p1.x + L1.x * (h1 + l1), y1, p1.z + L1.z * (h1 + l1)), Vector3(p1.x + L1.x * h1, y1, p1.z + L1.z * h1), Color(1, 1, 1),
			Vector2(0, v0), Vector2(maxf(l0, l1) / 4.0, v1))
	_add_mesh(lb.commit(mats["conc"]))

func _road_quad(mb: RefCounted, i: int, j: int, kind: String) -> void:
	var p0: Vector3 = track.samples[i]
	var p1: Vector3 = track.samples[j]
	var L0: Vector3 = track.laterals[i]
	var L1: Vector3 = track.laterals[j]
	var h0: float = track.hwa[i]
	var h1: float = track.hwa[j]
	var y0: float = track.cy[i] + 0.015
	var y1: float = track.cy[j] + 0.015
	var v0 := float(track.cum[i]) / 11.4
	var v1 := float(track.cum[j]) / 11.4
	# dentro del túnel el camino es más oscuro (la luz del sol no llega)
	var c0 := Color(1, 1, 1) if not track.in_tunnel(i) else Color(0.55, 0.55, 0.58)
	# derecha (lateral +) → izquierda; u: 0 izquierda, 1 derecha
	var lA := Vector3(p0.x - L0.x * h0, y0, p0.z - L0.z * h0)
	var rA := Vector3(p0.x + L0.x * h0, y0, p0.z + L0.z * h0)
	var lB := Vector3(p1.x - L1.x * h1, y1, p1.z - L1.z * h1)
	var rB := Vector3(p1.x + L1.x * h1, y1, p1.z + L1.z * h1)
	var o: int = mb.v.size()
	mb.v.append_array([lA, rA, rB, lB])
	mb.nm.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	mb.col.append_array([c0, c0, c0, c0])
	mb.uv.append_array([Vector2(0, v0), Vector2(1, v0), Vector2(1, v1), Vector2(0, v1)])
	# de frente hacia arriba (con el orden de índices de adv_mesh: horario visto desde el frente)
	mb.idx.append_array([o, o + 2, o + 1, o, o + 3, o + 2])

# ───────────────────────── terreno de los costados ─────────────────────────
const C_GRASS := Color(0.30, 0.43, 0.22)
const C_SHOULDER := Color(0.50, 0.45, 0.37)
const C_SIDEWALK := Color(0.63, 0.63, 0.61)
const C_ROCK := Color(0.47, 0.45, 0.42)
const C_SNOW := Color(0.90, 0.92, 0.96)
const C_QUARRY := Color(0.64, 0.40, 0.27)
const CROP_COL := [Color(0.30, 0.43, 0.22), Color(0.74, 0.63, 0.33), Color(0.32, 0.38, 0.18), Color(0.27, 0.37, 0.18), Color(0.34, 0.48, 0.24)]

func _ground_col(i: int, e: float, side: float, steep: float) -> Color:
	var c := Color(0, 0, 0)
	var ws := 0.0
	for bi in 7:
		var w: float = track.bw[bi][i]
		if w < 0.01:
			continue
		var cb := C_GRASS
		match bi:
			0: cb = C_SIDEWALK if e < 3.0 else Color(0.33, 0.45, 0.25)
			1:
				cb = C_GRASS
				var cr := int(track.cropa[i])
				if e > 5.0 and cr > 0:
					cb = CROP_COL[cr]
				elif e > 1.0 and e < 4.0:
					cb = Color(0.27, 0.38, 0.2) # la cuneta
			2: cb = Color(0.26, 0.36, 0.19) if e > 2.0 else Color(0.34, 0.38, 0.22)
			3: cb = Color(0.36, 0.42, 0.26)
			4: cb = C_QUARRY
			5: cb = C_SNOW
			6: cb = C_SNOW
		c += cb * w
		ws += w
	if ws > 0.0:
		c /= ws
	if steep > 0.9:
		var rk := C_ROCK if float(track.bw[4][i]) < 0.5 else C_QUARRY.darkened(0.1)
		if float(track.bw[5][i]) + float(track.bw[6][i]) > 0.5:
			rk = C_ROCK.lightened(0.15)
		c = c.lerp(rk, clampf((steep - 0.9) * 1.5, 0.0, 1.0))
	if float(track.w_lay[i]) > 0.3 and side > 0.0 and e < 26.0:
		c = c.lerp(C_SIDEWALK, float(track.w_lay[i]))
	return c

func _build_terrain(a: int, b: int) -> void:
	var mb := MB.new()
	for side: float in [-1.0, 1.0]:
		var nrow := ROWS.size() + 3 # borde del camino, fin de la banquina, filas y la pollera
		var base: int = mb.v.size()
		for i in range(a, b + 1):
			var p: Vector3 = track.samples[i]
			var L: Vector3 = track.laterals[i]
			var hw: float = track.hwa[i]
			var edge: float = hw + (float(track.laya[i]) if side > 0.0 else 0.0)
			var sh: float = track.shl[i]
			var clear: float = float(track.clear_r[i]) if side > 0.0 else float(track.clear_l[i])
			var ry: float = track.cy[i]
			var ys := PackedFloat32Array()
			var os := PackedFloat32Array()
			os.append(edge)
			ys.append(ry - 0.004)
			os.append(edge + sh)
			ys.append(ry - 0.05 if float(track.bw[0][i]) < 0.5 else ry + 0.16)
			var clamped := false
			for r in ROWS.size():
				var e: float = ROWS[r]
				var o := edge + sh + e
				if o > clear:
					o = maxf(clear, edge + sh + 0.2)
					if not clamped:
						clamped = true
						var x := p.x + L.x * side * o
						var z := p.z + L.z * side * o
						ys.append(track.side_height(i, 0.0, o - edge - sh, side, x, z))
					else:
						ys.append(ys[ys.size() - 1] - 3.0)
					os.append(o)
					continue
				var x2 := p.x + L.x * side * o
				var z2 := p.z + L.z * side * o
				os.append(o)
				ys.append(track.side_height(i, 0.0, e, side, x2, z2))
			# pollera: baja derecho para que no se vea el vacío debajo
			os.append(os[os.size() - 1])
			ys.append(ys[ys.size() - 1] - 30.0)
			for r in nrow:
				var o: float = os[r]
				var x3 := p.x + L.x * side * o
				var z3 := p.z + L.z * side * o
				mb.v.append(Vector3(x3, ys[r], z3))
				mb.uv.append(Vector2(x3, z3) * 0.22)
				var steep := 0.0
				if r > 1 and r < nrow - 1:
					steep = absf(ys[r] - ys[r - 1]) / maxf(0.2, os[r] - os[r - 1])
				var e2 := o - edge - sh
				var col := C_SHOULDER if r <= 1 else _ground_col(i, e2, side, steep)
				if r == 1 and float(track.bw[0][i]) > 0.5:
					col = C_SIDEWALK
				if r <= 1 and (float(track.bw[5][i]) + float(track.bw[6][i])) > 0.5:
					col = C_SNOW.darkened(0.08)
				if track.in_tunnel(i):
					col = col.darkened(0.6)
				mb.col.append(col)
				mb.nm.append(Vector3.UP)
		var rows_n: int = b - a + 1
		for k in rows_n - 1:
			for r in nrow - 1:
				var q0 := base + k * nrow + r
				var q1 := q0 + 1
				var q2 := q0 + nrow
				var q3 := q2 + 1
				# orientación hacia arriba según el lado
				if side > 0.0:
					mb.idx.append_array([q0, q2, q1, q1, q2, q3])
				else:
					mb.idx.append_array([q0, q1, q2, q1, q3, q2])
	_smooth_normals(mb)
	_add_mesh(mb.commit(terrain_mat))

## Normales suaves (promedio de las caras que tocan cada vértice)
func _smooth_normals(mb: RefCounted) -> void:
	var nn := PackedVector3Array()
	nn.resize(mb.v.size())
	nn.fill(Vector3.ZERO)
	var ix: PackedInt32Array = mb.idx
	var vv: PackedVector3Array = mb.v
	for t in range(0, ix.size(), 3):
		var a := ix[t]
		var b := ix[t + 1]
		var c := ix[t + 2]
		# con nuestro orden de índices el frente es (c−a)×(b−a)
		var fnv := (vv[c] - vv[a]).cross(vv[b] - vv[a])
		nn[a] += fnv
		nn[b] += fnv
		nn[c] += fnv
	for i in nn.size():
		var q := nn[i]
		nn[i] = q.normalized() if q.length_squared() > 1e-10 else Vector3.UP
	mb.nm = nn

# ───────────────────────── guardarraíles, alambrados y paredes ─────────────────────────
## Tipo de límite visible en cada muestra y lado: 0 nada · 1 guardarraíl · 2 alambrado · 3 baranda de madera · 4 parapeto de
## hormigón · 5 postes con reflectores (nieve)
func rail_type(i: int, side: float) -> int:
	if side > 0.0 and float(track.w_lay[i]) > 0.15:
		return 0
	if float(track.w_tunnel[i]) > 0.35 or float(track.w_under[i]) > 0.3:
		return 0
	if float(track.w_bridge[i]) > 0.3:
		return 4
	var best := 0
	var bwv := -1.0
	for bi in 7:
		if float(track.bw[bi][i]) > bwv:
			bwv = float(track.bw[bi][i])
			best = bi
	match best:
		0: return 0
		1: return 2
		2: return 3 if int(track.surfa[i]) == 1 else 1
		3, 6:
			return 1 if side * float(track.msidea[i]) < 0.0 else 0
		4: return 0
		5: return 5
	return 0

func _build_rails(a: int, b: int) -> void:
	var metal := MB.new()
	var wood := MB.new()
	var conc := MB.new()
	for side: float in [-1.0, 1.0]:
		var i := a
		while i < b:
			var t := rail_type(i, side)
			if t == 0:
				i += 1
				continue
			var j := i
			while j < b and rail_type(j + 1, side) == t:
				j += 1
			j = mini(j + 1, b)
			match t:
				1: _guardrail(metal, i, j, side)
				2: _fence(wood, i, j, side)
				3: _wood_rail(wood, i, j, side)
				4: _parapet(conc, i, j, side)
				5: _snow_poles(wood, i, j, side)
			i = j
	var m: ArrayMesh = metal.commit(mats["rail"])
	_add_mesh(m)
	_add_mesh(wood.commit(mats["wire"]))
	_add_mesh(conc.commit(mats["vc"]))

func _rail_pos(i: int, side: float, extra := 0.0) -> Vector3:
	var p: Vector3 = track.samples[i]
	var L: Vector3 = track.laterals[i]
	var w: float = (float(track.wall_r[i]) if side > 0.0 else float(track.wall_l[i])) + 1.0 + extra
	var x := p.x + L.x * side * w
	var z := p.z + L.z * side * w
	return Vector3(x, track.cy[i] - 0.05, z)

func _guardrail(mb: RefCounted, a: int, b: int, side: float) -> void:
	var prof := [[0.0, 0.40], [0.035, 0.46], [0.0, 0.53], [0.05, 0.62], [0.0, 0.71], [0.035, 0.78], [0.0, 0.84]]
	var col := Color(0.78, 0.8, 0.83)
	for i in range(a, b):
		var p0 := _rail_pos(i, side)
		var p1 := _rail_pos(i + 1, side)
		var L0: Vector3 = track.laterals[i] * side
		var L1: Vector3 = track.laterals[i + 1] * side
		for q in prof.size() - 1:
			var o0: float = prof[q][0]
			var o1: float = prof[q + 1][0]
			var h0: float = prof[q][1]
			var h1: float = prof[q + 1][1]
			mb.quad(p0 + L0 * o0 + Vector3(0, h0, 0), p1 + L1 * o0 + Vector3(0, h0, 0), p1 + L1 * o1 + Vector3(0, h1, 0), p0 + L0 * o1 + Vector3(0, h1, 0), col * (0.92 + 0.1 * float(q % 2)))
		if i % 2 == 0:
			mb.box(Transform3D(Basis(Vector3.UP, atan2(L0.x, L0.z)), p0 + L0 * 0.12 + Vector3(0, 0.42, 0)), Vector3(0.12, 0.95, 0.12), Color(0.5, 0.52, 0.55))

func _fence(mb: RefCounted, a: int, b: int, side: float) -> void:
	# alambrado: postes de madera cada 5 m y cuatro hilos de alambre
	for i in range(a, b):
		var p0 := _rail_pos(i, side, 0.4)
		var p1 := _rail_pos(i + 1, side, 0.4)
		for hh: float in [0.35, 0.65, 0.95, 1.2]:
			var d := Vector3(0, 0.012, 0)
			mb.quad(p0 + Vector3(0, hh, 0) - d, p1 + Vector3(0, hh, 0) - d, p1 + Vector3(0, hh, 0) + d, p0 + Vector3(0, hh, 0) + d, Color(0.55, 0.55, 0.55))
		if i % 2 == 0:
			mb.box(Transform3D(Basis(Vector3.UP, float(i)), p0 + Vector3(0, 0.62, 0)), Vector3(0.11, 1.35, 0.11), Color(0.42, 0.32, 0.22))

func _wood_rail(mb: RefCounted, a: int, b: int, side: float) -> void:
	for i in range(a, b):
		var p0 := _rail_pos(i, side)
		var p1 := _rail_pos(i + 1, side)
		for hh: float in [0.5, 0.82]:
			mb.quad(p0 + Vector3(0, hh - 0.09, 0), p1 + Vector3(0, hh - 0.09, 0), p1 + Vector3(0, hh + 0.09, 0), p0 + Vector3(0, hh + 0.09, 0), Color(0.45, 0.31, 0.19))
		if i % 2 == 0:
			mb.box(Transform3D(Basis(), p0 + Vector3(0, 0.5, 0)), Vector3(0.2, 1.05, 0.2), Color(0.36, 0.25, 0.15))

func _parapet(mb: RefCounted, a: int, b: int, side: float) -> void:
	for i in range(a, b):
		var p0 := _rail_pos(i, side, -0.2)
		var p1 := _rail_pos(i + 1, side, -0.2)
		var L0: Vector3 = track.laterals[i] * side
		var L1: Vector3 = track.laterals[i + 1] * side
		var c := Color(0.7, 0.7, 0.68)
		var up := Vector3(0, 0.95, 0)
		# cara hacia el camino, tapa y cara de afuera (cajón de hormigón)
		mb.quad(p0, p1, p1 + up, p0 + up, c)
		mb.quad(p1, p0, p0 + up, p1 + up, c)
		mb.quad(p0 + up, p1 + up, p1 + L1 * 0.4 + up, p0 + L0 * 0.4 + up, c.lightened(0.1))
		mb.quad(p1 + up, p0 + up, p0 + L0 * 0.4 + up, p1 + L1 * 0.4 + up, c.lightened(0.1))

func _snow_poles(mb: RefCounted, a: int, b: int, side: float) -> void:
	for i in range(a, b):
		if i % 6 != 0:
			continue
		var p0 := _rail_pos(i, side, 0.3)
		mb.box(Transform3D(Basis(), p0 + Vector3(0, 0.9, 0)), Vector3(0.08, 1.8, 0.08), Color(0.95, 0.95, 0.95))
		mb.box(Transform3D(Basis(), p0 + Vector3(0, 1.62, 0)), Vector3(0.09, 0.3, 0.09), Color(0.95, 0.35, 0.1))

# ───────────────────────── árboles ─────────────────────────
## Punto del costado: muestra i (fracción t), lado y distancia e pasando la banquina → [posición, ¿válido?]
func _side_point(i: int, t: float, side: float, e: float) -> Array:
	var j := mini(i + 1, track.n - 1)
	var p: Vector3 = (track.samples[i] as Vector3).lerp(track.samples[j], t)
	var L: Vector3 = (track.laterals[i] as Vector3).lerp(track.laterals[j], t).normalized()
	var edge: float = float(track.hwa[i]) + (float(track.laya[i]) if side > 0.0 else 0.0) + float(track.shl[i])
	var clear: float = float(track.clear_r[i]) if side > 0.0 else float(track.clear_l[i])
	var o := edge + e
	if o > clear - 2.5:
		return [Vector3.ZERO, false]
	var x := p.x + L.x * side * o
	var z := p.z + L.z * side * o
	return [Vector3(x, track.side_height(i, t, e, side, x, z), z), true]

func _biome_w(i: int, bi: int) -> float:
	return float(track.bw[bi][i])

func _build_trees(ci: int, a: int, b: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = track.stage * 100003 + ci * 7919 + 1
	var lists := {"pine": [], "spine": [], "broad": [], "poplar": [], "bush": [], "rock": []}
	var span := float(b - a)
	var q := quality
	for side: float in [-1.0, 1.0]:
		# bosque, montaña, nieve: árboles hasta el borde de lo dibujado (franja densa junto al camino)
		var tries := int(110.0 * q)
		for k in tries:
			var i := a + rng.randi() % maxi(1, b - a)
			var forest := _biome_w(i, 2)
			var mount := _biome_w(i, 3) + _biome_w(i, 6)
			var snow := _biome_w(i, 5) + _biome_w(i, 6)
			var quarry := _biome_w(i, 4)
			var dens := forest + mount * 0.45 + _biome_w(i, 5) * 0.8 + quarry * 0.12
			if track.in_tunnel(i) or float(track.w_bridge[i]) > 0.3:
				continue
			if rng.randf() > dens:
				continue
			var near := rng.randf() < 0.55
			var e := rng.randf_range(2.2, 14.0) if near else rng.randf_range(12.0, 120.0)
			if mount > 0.5 and side * float(track.msidea[i]) > 0.0:
				e = rng.randf_range(6.0, 60.0) # sobre la ladera
			if side > 0.0 and float(track.w_lay[i]) > 0.1:
				continue
			var sp: Array = _side_point(i, rng.randf(), side, e)
			if not sp[1]:
				continue
			var kind := "pine"
			if snow > 0.5:
				kind = "spine"
			elif forest > 0.5 and rng.randf() < 0.3:
				kind = "broad"
			lists[kind].append([sp[0], rng.randf_range(0.75, 1.35), rng.randf() * TAU])
		# campo: cortinas de álamos y eucaliptos sueltos, arbustos junto al alambrado
		for k in int(18.0 * q):
			var i := a + rng.randi() % maxi(1, b - a)
			var rural := _biome_w(i, 1)
			if rng.randf() > rural:
				continue
			var r := rng.randf()
			if r < 0.45:
				# una cortina de álamos (varios en fila paralela al camino)
				var e := rng.randf_range(35.0, 95.0)
				var t0 := rng.randf()
				for m in 6:
					var ii := mini(b - 1, i + m * 3)
					var sp: Array = _side_point(ii, t0, side, e + rng.randf_range(-0.6, 0.6))
					if sp[1]:
						lists["poplar"].append([sp[0], rng.randf_range(0.85, 1.15), rng.randf() * TAU])
			elif r < 0.75:
				var sp: Array = _side_point(i, rng.randf(), side, rng.randf_range(9.0, 70.0))
				if sp[1]:
					lists["broad"].append([sp[0], rng.randf_range(0.9, 1.5), rng.randf() * TAU])
			else:
				var sp: Array = _side_point(i, rng.randf(), side, rng.randf_range(4.0, 7.0))
				if sp[1]:
					lists["bush"].append([sp[0], rng.randf_range(0.7, 1.3), rng.randf() * TAU])
		# ciudad: árboles de vereda y en los fondos
		for k in int(10.0 * q):
			var i := a + rng.randi() % maxi(1, b - a)
			if _biome_w(i, 0) < 0.5 or (side > 0.0 and float(track.w_lay[i]) > 0.1):
				continue
			var e := 1.6 if rng.randf() < 0.7 else rng.randf_range(22.0, 60.0)
			var sp: Array = _side_point(i, rng.randf(), side, e)
			if sp[1]:
				lists["broad"].append([sp[0], rng.randf_range(0.6, 0.9), rng.randf() * TAU])
		# piedras en la montaña y la cantera
		for k in int(8.0 * q):
			var i := a + rng.randi() % maxi(1, b - a)
			if _biome_w(i, 3) + _biome_w(i, 4) + _biome_w(i, 6) < 0.5:
				continue
			var sp: Array = _side_point(i, rng.randf(), side, rng.randf_range(1.0, 25.0))
			if sp[1]:
				lists["rock"].append([sp[0], rng.randf_range(0.5, 1.6), rng.randf() * TAU])
	var mid: Vector3 = track.samples[(a + b) / 2]
	for kind in lists:
		var L: Array = lists[kind]
		if L.is_empty():
			continue
		var near_mesh: Mesh = meshes[kind]
		_add_mm(near_mesh, L, mid, 0.0, 250.0 if kind != "rock" else 160.0)
		if meshes.has(kind + "_lo"):
			_add_mm(meshes[kind + "_lo"], L, mid, 230.0, 950.0)

func _add_mm(mesh: Mesh, L: Array, center: Vector3, r0: float, r1: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = L.size()
	for j in L.size():
		var e: Array = L[j]
		var p: Vector3 = e[0]
		var sc: float = e[1]
		var yaw: float = e[2]
		var sx := sc * (0.9 + 0.2 * fposmod(p.x * 0.37, 1.0))
		mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(sx, sc, sx)), p - center - Vector3(0, 0.15, 0)))
		var tv := 0.85 + 0.3 * fposmod(p.x * 0.137 + p.z * 0.291, 1.0)
		mm.set_instance_color(j, Color(tv, tv * (0.95 + 0.1 * fposmod(p.z * 0.53, 1.0)), tv * 0.95))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.position = center
	inst.visibility_range_begin = r0
	inst.visibility_range_end = r1
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cur.add_child(inst)

# ───────────────────────── pueblos y ciudades ─────────────────────────
## Las casas de toda la etapa se planean de una vez (así no se pisan entre tramos); cada tramo arma las suyas.
func _plan_buildings() -> void:
	plan_buildings.clear()
	plan_buildings.resize(nchunks)
	for ci in nchunks:
		plan_buildings[ci] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321 + track.stage
	var pal := [Color(0.95, 0.93, 0.86), Color(0.93, 0.84, 0.70), Color(0.86, 0.90, 0.93), Color(0.95, 0.80, 0.78), Color(0.84, 0.90, 0.80),
		Color(0.97, 0.90, 0.66), Color(0.80, 0.80, 0.82), Color(0.90, 0.72, 0.58), Color(0.75, 0.85, 0.92)]
	for side: float in [-1.0, 1.0]:
		var s := 0.0
		var next_gap := rng.randf_range(70.0, 130.0)
		while s < track.length - 10.0:
			var i: int = track.idx_at(s)
			var town := int(track.towna[i])
			if town == 0 or float(track.bw[0][i]) < 0.6 or (side > 0.0 and float(track.w_lay[i]) > 0.05) or (int(track.flaga[i]) & AdvRoute.F_UNDER) != 0:
				s += 6.0
				continue
			if s > next_gap:
				# calle lateral (se deja el hueco; la calle se dibuja con su barrera)
				plan_buildings[i / CH].append({"street": true, "i": i, "side": side})
				s += 14.0
				next_gap = s + rng.randf_range(70.0, 140.0)
				continue
			var w := rng.randf_range(7.0, 13.0) if town == 1 else rng.randf_range(10.0, 18.0)
			var d := rng.randf_range(9.0, 14.0) if town == 1 else rng.randf_range(12.0, 18.0)
			var floors := (1 if rng.randf() < 0.55 else 2) if town == 1 else rng.randi_range(3, 8)
			var style := 0
			var r := rng.randf()
			if town == 1:
				style = 1 if r < 0.25 else 0
			else:
				style = 1 if r < 0.25 else (3 if r < 0.45 else 2)
			var roof := 1 if (town == 1 and rng.randf() < 0.65) else 0
			var ic: int = track.idx_at(s + w * 0.5)
			var p: Vector3 = track.samples[ic]
			var L: Vector3 = track.laterals[ic]
			var tg: Vector3 = track.tangents[ic]
			var hw: float = track.hwa[ic]
			var set_back := hw + float(track.shl[ic]) + 3.4 + (rng.randf() * 1.5 if town == 1 else 0.3)
			var clear: float = float(track.clear_r[ic]) if side > 0.0 else float(track.clear_l[ic])
			if set_back + d > clear - 1.0:
				s += 5.0
				continue
			# el frente mira a la calle: z local = hacia el camino
			var front := Vector3(p.x + L.x * side * set_back, track.cy[ic] + 0.14, p.z + L.z * side * set_back)
			var to_road := -L * side
			var xax := Vector3.UP.cross(to_road).normalized()
			var basis := Basis(xax, Vector3.UP, to_road)
			# que ninguna esquina caiga sobre el camino (en las esquinas a 90°)
			var ok := true
			var xf := Transform3D(basis, front)
			if branch and (ic < lim.x + 8 or ic > lim.y - 8):
				ok = false
			for corner: Vector3 in [Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, 0, -d), Vector3(w * 0.5, 0, -d), Vector3(0, 0, -d * 0.5)]:
				if not ok:
					break
				var cp := xf * (corner as Vector3)
				view.hint = ic
				view.nearest(cp.x, cp.z)
				var lm: float = float(view.hwa[view.r_idx]) + float(view.shl[view.r_idx]) + 2.8 + (float(view.laya[view.r_idx]) if view.r_lat > 0.0 else 0.0)
				if absf(view.r_lat) < lm:
					ok = false
				# tampoco sobre el otro camino de la bifurcación
				if cross != null and ic > int(cross.zone.x) - 40 and ic < int(cross.zone.y) + 40:
					cross.nearest(cp.x, cp.z)
					if absf(float(cross.r_lat)) < float(cross.hwa[cross.r_idx]) + 3.5:
						ok = false
			if ok:
				plan_buildings[ic / CH].append({"xf": xf, "w": w, "d": d, "floors": floors, "style": style, "color": pal[rng.randi() % pal.size()], "roof": roof, "seed": rng.randi()})
			s += w + rng.randf_range(0.3, 2.5)
			if tg == Vector3.ZERO:
				break

func _build_town_and_fields(ci: int, a: int, b: int) -> void:
	var atl := MB.new()
	var vc := MB.new()
	var wire := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = track.stage * 7777 + ci * 31 + 5
	# casas y calles laterales
	for bd in plan_buildings[ci]:
		var d: Dictionary = bd
		if d.has("street"):
			_side_street(vc, int(d["i"]), float(d["side"]), rng)
			continue
		var r2 := RandomNumberGenerator.new()
		r2.seed = int(d["seed"])
		Props.building(atl, d["xf"], float(d["w"]), float(d["d"]), int(d["floors"]), int(d["style"]), d["color"], int(d["roof"]), r2)
	# faroles y autos estacionados en la ciudad
	for i in range(a, b, 8):
		if _biome_w(i, 0) < 0.6 or int(track.towna[i]) == 0:
			continue
		for side: float in [-1.0, 1.0]:
			if side > 0.0 and float(track.w_lay[i]) > 0.05:
				continue
			var sp: Array = _side_point(i, 0.0, side, 0.7)
			if sp[1]:
				var tg: Vector3 = track.tangents[i]
				Props.street_lamp(vc, Transform3D(Basis(Vector3.UP, atan2(tg.x, tg.z) + (PI * 0.5 if side < 0.0 else -PI * 0.5)), sp[0]))
	# campo: postes de luz con cables, vacas, girasoles, maíz y trigo
	var poles: Array = []
	for i in range(a, b + 1):
		if _biome_w(i, 1) < 0.6:
			continue
		var gi: int = track.g0 + i
		if gi % 18 == 0:
			var sp: Array = _side_point(i, 0.0, -1.0, 5.5)
			if sp[1]:
				poles.append(sp[0])
	for k in poles.size():
		var pp: Vector3 = poles[k]
		Props.power_pole(vc, Transform3D(Basis(), pp))
		if k > 0:
			var p0: Vector3 = poles[k - 1]
			for off: float in [-0.9, 0.0, 0.9]:
				var dirv := (pp - p0)
				var side_v := Vector3(-dirv.z, 0, dirv.x).normalized() * float(off)
				_cable(wire, p0 + side_v + Vector3(0, 7.55, 0), pp + side_v + Vector3(0, 7.55, 0))
	var sun: Array = []
	var corn_mb := MB.new()
	var wheat: Array = []
	for side: float in [-1.0, 1.0]:
		for i in range(a, b, 2):
			if _biome_w(i, 1) < 0.7 or int(track.towna[i]) > 0:
				continue
			var cr := int(track.cropa[i])
			match cr:
				2:
					# girasoles: filas paralelas al camino, cada 1,7 m, hasta ~40 m
					var maxe := 40.0 if quality >= 1.0 else 24.0
					var e := 7.5
					while e < maxe:
						var sp: Array = _side_point(i, 0.0, side, e)
						if not sp[1]:
							break
						var tg: Vector3 = track.tangents[i]
						sun.append([sp[0], tg, side])
						e += 1.7
				3:
					# maizal: tres hileras altas
					for row in 3:
						var e2 := 7.0 + float(row) * 2.2
						var s0: Array = _side_point(i, 0.0, side, e2)
						var s1: Array = _side_point(mini(i + 2, track.n - 1), 0.0, side, e2)
						if s0[1] and s1[1]:
							var p0: Vector3 = s0[0]
							var p1: Vector3 = s1[0]
							var hgt := Vector3(0, 2.3, 0)
							corn_mb.quad(p0 - Vector3(0, 0.1, 0), p1 - Vector3(0, 0.1, 0), p1 + hgt, p0 + hgt, Color(1, 1, 1).darkened(0.08 * float(row)), Vector2(0, 1), Vector2(0.5, 0))
				1:
					for m in 3:
						var sp: Array = _side_point(i, rng.randf(), side, rng.randf_range(6.0, 16.0))
						if sp[1]:
							wheat.append(sp[0])
				4:
					if rng.randf() < 0.05:
						var sp: Array = _side_point(i, rng.randf(), side, rng.randf_range(10.0, 45.0))
						if sp[1]:
							Props.cow(vc, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), sp[0]), rng)
	_add_mesh(atl.commit(mats["atlas"]), false, 700.0)
	_add_mesh(vc.commit(mats["vc"]), false, 500.0)
	_add_mesh(wire.commit(mats["wire"]), false, 220.0)
	_add_mesh(corn_mb.commit(mats["corn"]), false, 260.0)
	var mid: Vector3 = track.samples[(a + b) / 2]
	if not sun.is_empty():
		var L: Array = []
		for s in sun:
			var tg: Vector3 = s[1]
			L.append([s[0], 1.0, atan2(tg.x, tg.z) + PI * 0.5 + (PI if float(s[2]) < 0.0 else 0.0)])
		_add_mm(meshes["sunflower"], L, mid, 0.0, 230.0)
	if not wheat.is_empty():
		var L2: Array = []
		for w in wheat:
			L2.append([w, rng.randf_range(0.8, 1.3), rng.randf() * PI])
		_add_mm(meshes["wheat"], L2, mid, 0.0, 120.0)

## Cable entre dos postes, con su panza
func _cable(mb: RefCounted, p0: Vector3, p1: Vector3) -> void:
	var n := 6
	var prev := p0
	for k in range(1, n + 1):
		var u := float(k) / float(n)
		var q := p0.lerp(p1, u) - Vector3(0, sin(u * PI) * 0.9, 0)
		var d := Vector3(0, 0.02, 0)
		mb.quad(prev - d, q - d, q + d, prev + d, Color(0.12, 0.12, 0.12))
		prev = q

## Calle lateral cerrada (vallas a rayas) en los pueblos
func _side_street(mb: RefCounted, i: int, side: float, rng: RandomNumberGenerator) -> void:
	var p: Vector3 = track.samples[i]
	var L: Vector3 = track.laterals[i]
	var tg: Vector3 = track.tangents[i]
	var edge: float = float(track.hwa[i]) + float(track.shl[i])
	var y: float = track.cy[i] + 0.02
	var o0 := edge
	var o1 := edge + 40.0
	var w := 4.5
	var a0 := p + L * side * o0 - tg * w
	var a1 := p + L * side * o0 + tg * w
	var b0 := p + L * side * o1 - tg * w
	var b1 := p + L * side * o1 + tg * w
	var c := Color(0.25, 0.25, 0.27)
	if side > 0.0:
		mb.quad(Vector3(a0.x, y, a0.z), Vector3(b0.x, y, b0.z), Vector3(b1.x, y, b1.z), Vector3(a1.x, y, a1.z), c)
	else:
		mb.quad(Vector3(a1.x, y, a1.z), Vector3(b1.x, y, b1.z), Vector3(b0.x, y, b0.z), Vector3(a0.x, y, a0.z), c)
	# valla a rayas blancas y rojas en la boca de la calle
	var bp := p + L * side * (edge + 2.6)
	var yaw := atan2(tg.x, tg.z)
	for k in 4:
		var t := (float(k) - 1.5) * 2.0
		var pos := bp + tg * t + Vector3(0, y + 0.55, 0) - Vector3(0, p.y, 0)
		mb.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, y + 0.55, pos.z)), Vector3(0.08, 1.1, 0.08), Color(0.3, 0.3, 0.3))
	for k in 3:
		var t2 := (float(k) - 1.0) * 2.0
		var pos2 := bp + tg * t2
		mb.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(pos2.x, y + 0.85, pos2.z)), Vector3(0.06, 0.28, 1.9), Color(0.95, 0.15, 0.12) if k % 2 == 0 else Color(0.97, 0.97, 0.95))

# ───────────────────────── obras: estaciones, talleres, túneles, puentes, carteles ─────────────────────────
func _yaw_at(i: int) -> float:
	var tg: Vector3 = track.tangents[clampi(i, 0, track.n - 1)]
	return atan2(tg.x, tg.z)

func _lay_max(i: int) -> float:
	var m := 0.0
	for j in range(maxi(0, i - 30), mini(track.n, i + 31)):
		m = maxf(m, float(track.laya[j]))
	return m

func _build_structures(ci: int, a: int, b: int) -> void:
	var vc := MB.new()
	var metal := MB.new()
	var emis := MB.new()
	var atl := MB.new()
	for ev in track.events:
		var e: Dictionary = ev
		var i: int = e["i"]
		var t := str(e["t"])
		var i1: int = int(e.get("i1", i))
		if t in ["tunnel", "mine", "bridge"]:
			if i1 < a or i > b:
				continue
		elif i < a or i >= b:
			continue
		match t:
			"station":
				var lat0: float = float(track.hwa[i]) + _lay_max(i)
				var st := Props.gas_station(str(e["name"]), lat0)
				st.position = Vector3(track.samples[i].x, track.cy[i], track.samples[i].z)
				st.rotation.y = _yaw_at(i)
				_cur.add_child(st)
			"workshop":
				var lat0: float = float(track.hwa[i]) + _lay_max(i)
				var ws := Props.workshop(str(e["name"]), lat0)
				ws.position = Vector3(track.samples[i].x, track.cy[i], track.samples[i].z)
				ws.rotation.y = _yaw_at(i)
				_cur.add_child(ws)
			"tunnel", "mine":
				_tunnel(vc, emis, metal, maxi(a, i), mini(b, i1), i, i1, t == "mine", str(e.get("name", "")))
			"bridge":
				_bridge(vc, maxi(a, i), mini(b, i1), i, i1)
			"overpass":
				_overpass(vc, metal, emis, i, str(e.get("kind", "rail")))
			"sign":
				_road_sign(vc, i, str(e["text"]), Color(0.06, 0.36, 0.2), 1.0)
			"town":
				_road_sign(vc, i, "BIENVENIDOS A\n" + str(e["name"]), Color(0.95, 0.95, 0.93), 1.0, Color(0.08, 0.08, 0.1))
			"farm":
				_farm(vc, atl, i, float(e.get("side", 1)))
	_chevrons(atl, a, b)
	_km_posts(vc, a, b)
	if ci == 0:
		_road_block(vc, 2, -1.0)
	if b >= track.n - 1:
		_road_block(vc, track.n - 6, 1.0)
	_add_mesh(vc.commit(mats["vc"]))
	_add_mesh(metal.commit(mats["metal"]))
	_add_mesh(emis.commit(mats["emis"]))
	_add_mesh(atl.commit(mats["atlas"]), false, 400.0)

## Perfil del túnel (lateral, altura): paredes rectas y bóveda
func _tunnel_profile(i: int) -> Array:
	var W: float = float(track.hwa[i]) + float(track.shl[i]) + 0.6
	var pts: Array = [Vector2(-W, -0.1), Vector2(-W, 4.3)]
	for k in range(1, 8):
		var ang := PI - PI * float(k) / 8.0
		pts.append(Vector2(cos(ang) * W, 4.3 + sin(ang) * 2.8))
	pts.append(Vector2(W, 4.3))
	pts.append(Vector2(W, -0.1))
	return pts

func _tpt(i: int, q: Vector2) -> Vector3:
	var p: Vector3 = track.samples[i]
	var L: Vector3 = track.laterals[i]
	return Vector3(p.x + L.x * q.x, track.cy[i] + q.y, p.z + L.z * q.x)

func _tunnel(vc: RefCounted, emis: RefCounted, metal: RefCounted, a: int, b: int, i0: int, i1: int, mine: bool, name: String) -> void:
	var col := Color(0.42, 0.42, 0.4) if not mine else Color(0.36, 0.27, 0.2)
	for i in range(a, b):
		var P0 := _tunnel_profile(i)
		var P1 := _tunnel_profile(i + 1)
		for k in P0.size() - 1:
			var c := col if k != 0 and k != P0.size() - 2 else col.darkened(0.15)
			if mine:
				c = col.lightened(0.08 * sin(float(i) * 1.7 + float(k) * 2.3))
			# hacia adentro: visto desde el camino
			vc.quad(_tpt(i, P0[k]), _tpt(i + 1, P1[k]), _tpt(i + 1, P1[k + 1]), _tpt(i, P0[k + 1]), c)
		# luces
		if i % 6 == 0:
			if not mine:
				var lp := _tpt(i, Vector2((-1.0 if (i / 6) % 2 == 0 else 1.0) * 2.2, 6.75))
				emis.box(Transform3D(Basis(Vector3.UP, _yaw_at(i)), lp), Vector3(0.35, 0.12, 1.4), Color(1.0, 0.85, 0.55))
			else:
				emis.box(Transform3D(Basis(), _tpt(i, Vector2(0, 5.6))), Vector3(0.18, 0.18, 0.18), Color(1.0, 0.75, 0.4))
		if mine and i % 4 == 0:
			# marcos de madera de la mina
			var yaw := _yaw_at(i)
			var W: float = float(track.hwa[i]) + float(track.shl[i])
			for sx: float in [-1.0, 1.0]:
				vc.box(Transform3D(Basis(Vector3.UP, yaw), _tpt(i, Vector2(sx * W, 2.4))), Vector3(0.3, 4.8, 0.3), Color(0.38, 0.26, 0.15))
			vc.box(Transform3D(Basis(Vector3.UP, yaw), _tpt(i, Vector2(0, 4.9))), Vector3(2.0 * W + 0.4, 0.3, 0.3), Color(0.38, 0.26, 0.15))
		# la montaña de arriba (tapa el túnel desde afuera)
		_cap_strip(vc, i, i + 1, mine)
	# portales
	if i0 >= a and i0 < b + 1:
		_portal(vc, emis, i0, 1.0, name, mine)
	if i1 >= a and i1 <= b:
		_portal(vc, emis, i1, -1.0, name, mine)

func _cap_strip(vc: RefCounted, i: int, j: int, mine: bool) -> void:
	var c := Color(0.4, 0.38, 0.33) if not mine else Color(0.55, 0.36, 0.25)
	var pts_i := _cap_row(i)
	var pts_j := _cap_row(j)
	for k in pts_i.size() - 1:
		vc.quad(pts_i[k], pts_i[k + 1], pts_j[k + 1], pts_j[k], c)

func _cap_row(i: int) -> Array:
	var p: Vector3 = track.samples[i]
	var L: Vector3 = track.laterals[i]
	var edge: float = float(track.hwa[i]) + float(track.shl[i])
	var out: Array = []
	var top: float = track.cy[i] + 9.0
	for o: float in [-(edge + 4.5), -(edge + 0.6), 0.0, edge + 0.6, edge + 4.5]:
		var oo: float = o
		var x := p.x + L.x * oo
		var z := p.z + L.z * oo
		var y := top + 1.2 * cos(oo * 0.25)
		if absf(oo) > edge + 1.0:
			y = maxf(top, track.side_height(i, 0.0, 4.5, signf(oo), x, z))
		out.append(Vector3(x, y, z))
	return out

## Boca del túnel: pared de hormigón alrededor del arco y el nombre arriba. dir: +1 entrada (mira hacia atrás), −1 salida
func _portal(vc: RefCounted, emis: RefCounted, i: int, dir: float, name: String, mine: bool) -> void:
	var P := _tunnel_profile(i)
	var edge: float = float(track.hwa[i]) + float(track.shl[i])
	var X := edge + 5.5
	var Y := 12.0
	var cen := Vector2(0, 3.0)
	var col := Color(0.62, 0.62, 0.6) if not mine else Color(0.42, 0.3, 0.2)
	var outer: Array = []
	for q in P:
		var v: Vector2 = q - cen
		var k := minf(X / maxf(absf(v.x), 0.001), (Y - cen.y) / maxf(v.y, 0.001)) if v.y > 0.0 else X / maxf(absf(v.x), 0.001)
		var o := cen + v * k
		o.y = maxf(o.y, -0.1)
		outer.append(o)
	var tg: Vector3 = track.tangents[i]
	var push := tg * (-0.05 * dir)
	for k in P.size() - 1:
		var a0 := _tpt(i, P[k]) + push
		var a1 := _tpt(i, P[k + 1]) + push
		var b0 := _tpt(i, outer[k]) + push
		var b1 := _tpt(i, outer[k + 1]) + push
		if dir < 0.0:
			vc.quad(a0, b0, b1, a1, col)
		else:
			vc.quad(a1, b1, b0, a0, col)
	# marco más oscuro y el nombre
	if name != "":
		var lp := _tpt(i, Vector2(0, 8.6)) - tg * (0.12 * dir)
		var lb := Props.label(name, lp, _yaw_at(i) + (PI if dir > 0.0 else 0.0), 0.016, Color(1, 1, 1), Color(0.1, 0.1, 0.1))
		lb.visibility_range_end = 400.0
		_cur.add_child(lb)

func _bridge(vc: RefCounted, a: int, b: int, i0: int, i1: int) -> void:
	var col := Color(0.6, 0.6, 0.58)
	for i in range(a, b):
		var W0: float = float(track.hwa[i]) + float(track.shl[i]) + 0.6
		var W1: float = float(track.hwa[i + 1]) + float(track.shl[i + 1]) + 0.6
		# losa: cara de abajo y costados
		var l0 := _tpt(i, Vector2(-W0, -1.3))
		var r0 := _tpt(i, Vector2(W0, -1.3))
		var l1 := _tpt(i + 1, Vector2(-W1, -1.3))
		var r1 := _tpt(i + 1, Vector2(W1, -1.3))
		vc.quad(r0, l0, l1, r1, col.darkened(0.3))
		vc.quad(_tpt(i, Vector2(-W0, -0.05)), _tpt(i + 1, Vector2(-W1, -0.05)), l1, l0, col)
		vc.quad(r0, r1, _tpt(i + 1, Vector2(W1, -0.05)), _tpt(i, Vector2(W0, -0.05)), col)
		# pilas cada 40 m
		if (i - i0) % 16 == 8:
			for sx: float in [-0.55, 0.55]:
				var pp := _tpt(i, Vector2(sx * W0, -1.3))
				vc.box(Transform3D(Basis(Vector3.UP, _yaw_at(i)), pp - Vector3(0, 7.5, 0)), Vector3(1.4, 15.0, 2.2), col.darkened(0.1))
	# el río (un plano de agua grande debajo del puente)
	if a <= (i0 + i1) / 2 and (i0 + i1) / 2 < b:
		var im := (i0 + i1) / 2
		var p: Vector3 = track.samples[im]
		var water := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(240.0, float(i1 - i0) * 2.5 + 140.0)
		water.mesh = pm
		water.material_override = water_mat
		water.position = Vector3(p.x, track.cy[im] - 11.8, p.z)
		water.rotation.y = _yaw_at(im)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cur.add_child(water)

func _overpass(vc: RefCounted, metal: RefCounted, emis: RefCounted, i: int, kind: String) -> void:
	var p: Vector3 = track.samples[i]
	var L: Vector3 = track.laterals[i]
	var tg: Vector3 = track.tangents[i]
	var yaw := _yaw_at(i)
	var edge: float = float(track.hwa[i]) + float(track.shl[i]) + 1.2
	var deck_y: float = track.cy[i] + 6.0
	var width := 9.0
	if kind == "avenue":
		deck_y = float(track.under_top[i]) + 0.0
		width = 16.0
	var span := edge + 26.0
	var b := Basis(Vector3.UP, yaw)
	# tablero (de lado a lado del camino)
	vc.box(Transform3D(b, Vector3(p.x, deck_y - 0.6, p.z)), Vector3(span * 2.0, 1.2, width), Color(0.6, 0.6, 0.58))
	# estribos
	for sd: float in [-1.0, 1.0]:
		var c := p + L * sd * (edge + 1.2)
		var h: float = deck_y - float(track.cy[i])
		vc.box(Transform3D(b, Vector3(c.x, track.cy[i] + h * 0.5 - 0.6, c.z)), Vector3(2.4, h, width + 1.0), Color(0.55, 0.55, 0.53))
	# barandas
	for sz: float in [-1.0, 1.0]:
		var c2 := p + tg * sz * (width * 0.5 - 0.15)
		metal.box(Transform3D(b, Vector3(c2.x, deck_y + 0.5, c2.z)), Vector3(span * 2.0, 0.08, 0.08), Color(0.3, 0.32, 0.35))
		metal.box(Transform3D(b, Vector3(c2.x, deck_y + 0.25, c2.z)), Vector3(span * 2.0, 0.5, 0.04), Color(0.4, 0.42, 0.45))
	if kind == "rail":
		for sz: float in [-0.75, 0.75]:
			var c3 := p + tg * sz
			metal.box(Transform3D(b, Vector3(c3.x, deck_y + 0.1, c3.z)), Vector3(span * 2.0, 0.15, 0.1), Color(0.35, 0.3, 0.25))
		var lb := Props.label("FERROCARRIL GENERAL BELGRANO", Vector3(p.x, deck_y - 0.6, p.z) - tg * (width * 0.5 + 0.02), yaw + PI, 0.012, Color(1, 1, 1))
		_cur.add_child(lb)
	else:
		var lb2 := Props.label("AV. DE LOS SUEÑOS", Vector3(p.x, deck_y - 0.6, p.z) - tg * (width * 0.5 + 0.02), yaw + PI, 0.014, Color(1, 1, 1))
		_cur.add_child(lb2)
		for k in 3:
			var cp := p + L * (float(k) * 6.0 - 6.0) + tg * 3.0
			Props.parked_car(vc, Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), Vector3(cp.x, deck_y, cp.z)), [Color(0.7, 0.1, 0.1), Color(0.9, 0.9, 0.9), Color(0.1, 0.3, 0.6)][k])

## Cartel al costado derecho, mirando a los que vienen
func _road_sign(vc: RefCounted, i: int, text: String, col: Color, size_k: float, text_col := Color.WHITE) -> void:
	var p: Vector3 = track.samples[i]
	var L: Vector3 = track.laterals[i]
	var edge: float = float(track.hwa[i]) + float(track.shl[i]) + 1.3
	var pos := p + L * edge
	pos.y = track.cy[i]
	var yaw := _yaw_at(i) + PI # mira hacia atrás (a los autos que llegan)
	var w := clampf(float(text.length()) * 0.26, 2.6, 7.0) * size_k
	var lines := text.split("\n").size()
	var h := (0.9 + 0.5 * float(lines - 1)) * size_k
	Props.sign_panel(vc, Transform3D(Basis(Vector3.UP, yaw), pos), w, h, col, 1.9)
	var longest := 1
	for ln in text.split("\n"):
		longest = maxi(longest, ln.length())
	var px := minf(0.0068, (w - 0.35) / (float(longest) * 64.0 * 0.58)) * size_k
	var lb := Props.label(text, pos + Vector3(0, 1.9 + h * 0.5, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.08, yaw, px, text_col)
	lb.visibility_range_end = 300.0
	_cur.add_child(lb)

## Chacra: casa blanca con techo de tejas, galpón, silo y molino
func _farm(vc: RefCounted, atl: RefCounted, i: int, side: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = i * 13 + track.stage
	var sp: Array = _side_point(i, 0.0, side, 42.0)
	if not sp[1]:
		return
	var c: Vector3 = sp[0]
	var L: Vector3 = track.laterals[i]
	var to_road := -L * side
	var basis := Basis(Vector3.UP.cross(to_road).normalized(), Vector3.UP, to_road)
	Props.building(atl, Transform3D(basis, c), 11.0, 8.0, 1, 0, Color(0.96, 0.95, 0.92), 1, rng)
	var sh := c + basis.x * 16.0 - to_road * 4.0
	Props.building(atl, Transform3D(basis, sh), 10.0, 12.0, 2, 0, Color(0.75, 0.3, 0.22), 0, rng)
	# silo
	var so := c - basis.x * 13.0 - to_road * 6.0
	vc.cyl(Transform3D(Basis(), so), 2.6, 2.6, 11.0, 12, Color(0.78, 0.8, 0.82), false)
	vc.cyl(Transform3D(Basis(), so + Vector3(0, 11.0, 0)), 2.7, 0.2, 2.2, 12, Color(0.7, 0.72, 0.75), false)
	# molino: torre de hierro y la rueda de aspas
	var mo := c - basis.x * 22.0 + to_road * 6.0
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		var foot := mo + Vector3(cos(a) * 1.6, 0, sin(a) * 1.6)
		var top := mo + Vector3(cos(a) * 0.35, 10.0, sin(a) * 0.35)
		var dirv := (top - foot).normalized()
		var bb := Basis(dirv.cross(Vector3.FORWARD).normalized(), dirv, dirv.cross(Vector3.FORWARD).normalized().cross(dirv)).orthonormalized()
		vc.cyl(Transform3D(bb, foot), 0.06, 0.06, foot.distance_to(top), 4, Color(0.45, 0.45, 0.47), false)
	var hub := mo + Vector3(0, 10.4, 0)
	var face := to_road
	for k in 16:
		var a := TAU * float(k) / 16.0
		var rdir := basis.x * cos(a) + Vector3.UP * sin(a)
		var p0 := hub + rdir * 0.5
		var p1 := hub + rdir * 2.2
		var tw := (basis.x * cos(a + 0.18) + Vector3.UP * sin(a + 0.18))
		vc.quad(p0, p1, p1 + tw * 0.35 + face * 0.1, p0 + tw * 0.12 + face * 0.05, Color(0.85, 0.86, 0.88))
		vc.quad(p0 + tw * 0.12 + face * 0.05, p1 + tw * 0.35 + face * 0.1, p1, p0, Color(0.7, 0.7, 0.72))
	vc.box(Transform3D(basis, hub - face * 1.4), Vector3(0.1, 1.2, 2.2), Color(0.8, 0.8, 0.82))

## Flechas amarillas y negras por fuera de las curvas cerradas
func _chevrons(atl: RefCounted, a: int, b: int) -> void:
	var r := Props.tile_rect(Props.T_CHEVRON)
	for i in range(a, b):
		var k: float = track.curv[i]
		if absf(k) < 1.0 / 95.0 or i % 5 != 0 or float(track.bw[0][i]) > 0.5:
			continue
		if track.in_tunnel(i):
			continue
		var side := -1.0 if k > 0.0 else 1.0 # por fuera de la curva
		if side > 0.0 and float(track.w_lay[i]) > 0.1:
			continue
		var pos := _rail_pos(i, side, 0.35)
		var yaw := _yaw_at(i) + PI
		var bs := Basis(Vector3.UP, yaw)
		var c := pos + Vector3(0, 0.75, 0)
		var w := 0.45
		var h := 0.6
		var x := bs.x * w
		var y := Vector3(0, h, 0)
		var u0 := Vector2(r.position.x, r.end.y)
		var u1 := Vector2(r.end.x, r.position.y)
		if k < 0.0:
			# curva a la derecha: la flecha apunta a la derecha del que viene (−x del cartel)
			u0 = Vector2(r.end.x, r.end.y)
			u1 = Vector2(r.position.x, r.position.y)
		atl.quad(c - x, c + x, c + x + y, c - x + y, Color(1, 1, 1), u0, u1)
		atl.box(Transform3D(bs, c - Vector3(0, 0.38, 0) - bs.z * 0.03), Vector3(0.07, 0.8, 0.05), Color(0.4, 0.4, 0.42))

## Mojones de kilómetro (desde la estación de largada)
func _km_posts(vc: RefCounted, a: int, b: int) -> void:
	for i in range(a, b):
		var s := float(track.cum[i]) - float(track.cum[track.i_start])
		var s1 := float(track.cum[i + 1]) - float(track.cum[track.i_start])
		if s <= 0.0 or floor(s / 1000.0) == floor(s1 / 1000.0):
			continue
		var km := int(floor(s1 / 1000.0))
		var pos := _rail_pos(i, -1.0, 0.2)
		vc.box(Transform3D(Basis(Vector3.UP, _yaw_at(i)), pos + Vector3(0, 0.45, 0)), Vector3(0.28, 0.9, 0.12), Color(0.95, 0.95, 0.93))
		var lb := Props.label("KM %d" % km, pos + Vector3(0, 0.62, 0) - (track.tangents[i] as Vector3) * 0.07, _yaw_at(i) + PI, 0.0042, Color(0.1, 0.1, 0.1))
		_cur.add_child(lb)

## Fin del camino: valla «RUTA CORTADA»
func _road_block(vc: RefCounted, i: int, dir: float) -> void:
	var p: Vector3 = track.samples[i]
	var L: Vector3 = track.laterals[i]
	var yaw := _yaw_at(i)
	var hw: float = float(track.hwa[i]) + float(track.shl[i]) + 1.5
	for k in 7:
		var o := -hw + float(k) * hw * 2.0 / 6.0
		var c := p + L * o
		vc.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, track.cy[i] + 0.6, c.z)), Vector3(hw * 2.0 / 6.0, 0.35, 0.12), Color(0.95, 0.15, 0.12) if k % 2 == 0 else Color(0.97, 0.97, 0.95))
		vc.box(Transform3D(Basis(Vector3.UP, yaw), Vector3(c.x, track.cy[i] + 0.35, c.z)), Vector3(0.08, 0.7, 0.08), Color(0.3, 0.3, 0.3))

# ───────────────────────── horizonte ─────────────────────────
## Anillo de montañas lejanas alrededor de la cámara (no le afecta la niebla: ya viene con colores de lejanía)
func _build_horizon() -> void:
	var img := Image.create(1024, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + track.stage
	var snowy: bool = int(track.stage) >= 7
	for layer in 2:
		var base := 70.0 if layer == 0 else 95.0
		var amp := 40.0 if layer == 0 else 22.0
		var c := Color(0.55, 0.62, 0.72, 1.0) if layer == 0 else Color(0.45, 0.53, 0.6, 1.0)
		for x in 1024:
			var fx := float(x) / 1024.0 * TAU
			var h := base - amp * (0.5 + 0.3 * sin(fx * 3.0 + float(layer) * 2.0) + 0.15 * sin(fx * 11.0 + 1.3) + 0.08 * sin(fx * 29.0))
			if layer == 0:
				h -= amp * 0.4 * pow(maxf(0.0, sin(fx * 5.0 + 0.4)), 3.0)
			for y in range(int(h), 128):
				var cc := c
				if snowy and layer == 0 and float(y) < h + 6.0 and h < 50.0:
					cc = Color(0.92, 0.94, 0.97, 1.0)
				img.set_pixel(x, y, cc)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	m.albedo_color = Color(1, 1, 1)
	var cm := CylinderMesh.new()
	cm.top_radius = 2400.0
	cm.bottom_radius = 2400.0
	cm.height = 600.0
	cm.radial_segments = 48
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	cm.material = m
	horizon = MeshInstance3D.new()
	horizon.mesh = cm
	horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	horizon.extra_cull_margin = 10000.0
	add_child(horizon)

## La niebla y el horizonte siguen a la cámara; el color del horizonte se mezcla con el del cielo
func follow(cam_pos: Vector3, fog_col: Color) -> void:
	if horizon != null:
		horizon.position = Vector3(cam_pos.x, cam_pos.y + 30.0, cam_pos.z)
		var m := (horizon.mesh as CylinderMesh).material as StandardMaterial3D
		m.albedo_color = Color(1, 1, 1).lerp(fog_col, 0.35)
