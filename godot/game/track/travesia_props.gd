extends Node3D
## Lo que le da carácter a la Travesía X además del camino: el agua de los vados (los lagos que se cruzan), piedras, la CUEVA (un túnel de roca sobre el camino, sólo visual), el BOSQUE de imágenes
## a los costados (los mismos árboles de 8 vistas / cruz del mundo abierto, según el tramo: denso en el bosque y en el arroyo, ralo en el valle y en la cresta) y el bosque lejano del horizonte.
## Todo es visual y liviano (mallas de agua y cueva, un MultiMesh de piedras y dos MultiMesh por cada ~260 m de árboles). El arrastre del agua lo aplica race.gd con water_depth().

const TreeSprites := preload("res://game/city/tree_sprites.gd")
const HorizonTrees := preload("res://game/city/horizon_trees.gd")
const BLOCK := 60 # muestras por bloque de árboles (~260 m)
## Árboles por tramo: [por cada 100 m y por lado en la primera fila, bioma]. La segunda fila (más atrás) tiene un 20 % más.
const FOREST := {"largada": [1.0, "mixed"], "bosque": [6.0, "mixed"], "barro1": [3.0, "mixed"], "pedregal": [0.8, "conifer"], "valle": [0.6, "round"], "vado": [1.5, "round"],
	"orilla": [2.0, "round"], "ascenso": [3.5, "conifer"], "cresta": [0.4, "conifer"], "bajada_cueva": [3.0, "conifer"], "cueva": [2.0, "conifer"], "arroyo": [3.0, "round"],
	"escalones": [1.0, "conifer"], "bosque2": [7.0, "conifer"], "llanura": [0.5, "round"], "medanos": [0.3, "round"], "muro": [2.0, "conifer"], "cornisa": [1.5, "conifer"],
	"pico": [1.2, "conifer"], "techo": [0.2, "conifer"], "gran_bajada": [3.0, "conifer"], "barranca": [2.5, "mixed"], "vado2": [2.0, "round"], "barro2": [3.5, "mixed"],
	"pedregal2": [0.8, "conifer"], "pista": [0.8, "round"], "final": [1.5, "mixed"]}
const ROCKY := ["pedregal", "pedregal2", "arroyo", "barranca", "escalones"]

var track # RouteTrack de la Travesía (con water y sections)
var vk := 1.0 # alcance de la vista (0,6 … 1): achica las distancias de los árboles
var density := 1.0 # 1 = completo; los teléfonos flojos piden menos árboles
var sun: DirectionalLight3D # para oscurecer los árboles de imagen cuando baja el sol
var trees_count := 0
var _rings: Array[MeshInstance3D] = []
var _view
var _coarse := PackedInt32Array()
var _acc := 0.0
var _ring_y := 0.0

func setup(p_track) -> void:
	track = p_track
	for z in track.water:
		add_child(_water_strip(z as Dictionary))
	var rocks := _rocks()
	if rocks != null:
		add_child(rocks)
	for cv in track.caves:
		add_child(_cave(cv as Dictionary))
	_view = track.make_view(false)
	_view.trust = true
	for i in range(0, track.n, 12):
		_coarse.append(i)
	_forest()
	for ring in HorizonTrees.build():
		add_child(ring)
		_rings.append(ring)
	HorizonTrees.set_sea(1e9, 2e9) # el bosque del horizonte da toda la vuelta (no hay mar)
	_update_rings()

func _process(dt: float) -> void:
	if _ring_y == 0.0:
		_update_rings()
	var cam := get_viewport().get_camera_3d()
	if cam == null or _rings.is_empty():
		return
	for ring in _rings:
		ring.global_position = Vector3(cam.global_position.x, _ring_y, cam.global_position.z)
	_acc += dt
	if _acc >= 0.4:
		_acc = 0.0
		_update_rings()
		if sun != null:
			TreeSprites.set_night(clampf(1.0 - sun.light_energy / 1.25, 0.0, 0.9))
			HorizonTrees.set_night(clampf(1.0 - sun.light_energy / 1.25, 0.0, 0.9))

## Los anillos de bosque lejano quedan a la altura del terreno más bajo que los rodea a ~350 m (nunca flotan sobre el suelo; donde el terreno sube, lo tapa)
func _update_rings() -> void:
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cx := cam.global_position.x
	var cz := cam.global_position.z
	var lo := 1e9
	for k in 8:
		var a := TAU * float(k) / 8.0
		var x := cx + cos(a) * 350.0
		var z := cz + sin(a) * 350.0
		var bi := 0
		var bd := 1e18
		for i in _coarse:
			var dx: float = track.samples[i].x - x
			var dz: float = track.samples[i].z - z
			var dd := dx * dx + dz * dz
			if dd < bd:
				bd = dd
				bi = i
		_view.hint = bi
		lo = minf(lo, float(_view.ground_smooth(x, z)))
	_ring_y = lerpf(_ring_y, lo + 3.5, 0.5) if _ring_y != 0.0 else lo + 3.5

# ───────────────────────── bosque ─────────────────────────
## Árboles de imagen a los dos lados: dos filas por tramo (la de adelante y una más atrás), en manchones de una especie, nunca sobre el camino ni sobre otro tramo que pase cerca.
func _forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var grid := {} # celdas de 40 m con las muestras del camino (para no plantar un árbol sobre otro tramo)
	for i in range(0, track.n, 2):
		var key := Vector2i(floori(track.samples[i].x / 40.0), floori(track.samples[i].z / 40.0))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		(grid[key] as PackedInt32Array).append(i)
	var edge: float = float(track.half_width + track.shoulder)
	var blocks := {}
	var sec_of := PackedInt32Array()
	sec_of.resize(track.n)
	sec_of.fill(-1)
	for si in track.sections.size():
		var sc: Dictionary = track.sections[si]
		for i in range(int(sc["i0"]), mini(int(sc["i1"]), track.n - 1) + 1):
			sec_of[i] = si
	var step := 3
	for i in range(0, track.n, step):
		if sec_of[i] < 0:
			continue
		var sec: Dictionary = track.sections[sec_of[i]]
		var def: Array = FOREST.get(str(sec["name"]), [1.0, "mixed"])
		var dens: float = float(def[0]) * density
		var per := dens * float(step) * 4.4 / 100.0 # árboles esperados por muestra, por lado y por fila
		var p: Vector3 = track.samples[i]
		var l: Vector3 = track.laterals[i]
		var tg: Vector3 = track.tangents[i]
		for sd in [-1.0, 1.0]:
			for row in 2:
				var want := per * (1.0 if row == 0 else 1.2)
				var cnt := int(want)
				if rng.randf() < want - float(cnt):
					cnt += 1
				for t in cnt:
					var off := edge + (rng.randf_range(3.0, 14.0) if row == 0 else rng.randf_range(14.0, 62.0))
					var along := rng.randf_range(-6.0, 6.0)
					var x: float = p.x + l.x * float(sd) * off + tg.x * along
					var z: float = p.z + l.z * float(sd) * off + tg.z * along
					if _near_road(grid, x, z, edge + 3.5):
						continue
					_view.hint = i
					var y: float = _view.ground_smooth(x, z)
					var r := rng.randf()
					var sp := TreeSprites.pick_biome(x, z, r, str(def[1]))
					var k := rng.randf_range(0.7, 1.35) * (0.8 if y > 250.0 else 1.0) # arriba en la sierra los árboles son más chicos
					var key := i / BLOCK
					if not blocks.has(key):
						blocks[key] = []
					(blocks[key] as Array).append(TreeSprites.item(x, y, z, sp, k, rng.randf() * TAU, r))
					trees_count += 1
	for key in blocks:
		var node := TreeSprites.build(blocks[key], vk)
		if node != null:
			add_child(node)

func _near_road(grid: Dictionary, x: float, z: float, r: float) -> bool:
	var cx := floori(x / 40.0)
	var cz := floori(z / 40.0)
	var r2 := r * r
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var lst: Variant = grid.get(Vector2i(cx + dx, cz + dz))
			if lst == null:
				continue
			for i in (lst as PackedInt32Array):
				var ex: float = track.samples[i].x - x
				var ez: float = track.samples[i].z - z
				if ex * ex + ez * ez < r2:
					return true
	return false

# ───────────────────────── cueva ─────────────────────────
## Un túnel de roca sobre el camino (sólo visual, no choca): arco por dentro, cerro de roca con pasto por fuera y un frente en cada boca. El camino baja y dobla adentro.
func _cave(z: Dictionary) -> MeshInstance3D:
	var i0 := int(z["i0"])
	var i1 := int(z["i1"])
	var wd: float = float(track.half_width + track.shoulder) + 1.4 # semiancho del hueco
	var hh := 6.6 # alto del hueco
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var arch := 12
	var rings: Array = [] # por anillo: [puntos del arco, puntos del cerro]
	var i := i0
	while i <= i1:
		var p: Vector3 = track.samples[i]
		var l: Vector3 = track.laterals[i]
		var y0: float = track.cy[i]
		var jit := 0.25 * sin(float(i) * 0.9)
		var inner: Array = []
		for k in arch + 1:
			var th := PI * float(k) / float(arch)
			var w := wd * cos(th)
			var h := (hh + jit) * sin(th)
			inner.append(Vector3(p.x - l.x * w, y0 + h, p.z - l.z * w))
		# el cerro de afuera: base enterrada, hombro y cumbre (lados espejados)
		var outer: Array = []
		var prof := [[-1.0, -(wd + 26.0)], [4.5, -(wd + 12.0)], [hh + 3.0, -(wd + 3.0)], [hh + 6.5 + jit * 2.0, 0.0], [hh + 3.0, wd + 3.0], [4.5, wd + 12.0], [-1.0, wd + 26.0]]
		for q in prof:
			var wn := float(q[1])
			outer.append(Vector3(p.x + l.x * wn, y0 + float(q[0]) + 0.6 * sin(float(i) * 0.37 + wn * 0.1), p.z + l.z * wn))
		rings.append([inner, outer])
		i += 2
	var rock_in := Color(0.20, 0.17, 0.15)
	var rock_out := Color(0.46, 0.42, 0.37)
	var grass := Color(0.30, 0.42, 0.25)
	for r in rings.size() - 1:
		var a: Array = (rings[r] as Array)[0]
		var b: Array = (rings[r + 1] as Array)[0]
		var shade := 0.85 + 0.3 * rng.randf()
		for k in arch:
			var depth := 1.0 - 0.45 * absf(float(k) / float(arch) - 0.5) * 2.0 # el techo un poco más claro que las paredes
			var col := rock_in * (shade * (0.8 + 0.4 * depth)) * (0.9 + 0.2 * rng.randf())
			_quad(v, c, a[k], a[k + 1], b[k + 1], b[k], Color(col.r, col.g, col.b))
		var ao: Array = (rings[r] as Array)[1]
		var bo: Array = (rings[r + 1] as Array)[1]
		for k in ao.size() - 1:
			var top := float(k) / float(ao.size() - 2)
			var tt := 1.0 - absf(top - 0.5) * 2.0 # 0 abajo · 1 arriba
			var col2 := rock_out.lerp(grass, smoothstep(0.55, 0.95, tt)) * (0.9 + 0.2 * rng.randf())
			_quad(v, c, ao[k], ao[k + 1], bo[k + 1], bo[k], Color(col2.r, col2.g, col2.b))
	# frentes de las dos bocas: una tira entre el arco del hueco y el contorno del cerro (de la base de un lado a la del otro, por la cumbre)
	var lip := Color(0.55, 0.50, 0.44)
	for end in [0, rings.size() - 1]:
		var ring: Array = rings[end]
		var inn: Array = ring[0]
		var out: Array = ring[1]
		var poly: Array = [out[0], out[1], out[2], out[3], out[4], out[5], out[6]]
		for k in arch:
			_quad(v, c, inn[k], inn[k + 1], _along(poly, float(k + 1) / float(arch)), _along(poly, float(k) / float(arch)), lip * (0.9 + 0.2 * rng.randf()))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.generate_normals()
	var out_m := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	out_m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "cueva"
	mi.mesh = out_m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 1100.0
	return mi

## Punto a la fracción t (0…1) del largo de la poligonal
static func _along(poly: Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * float(poly.size() - 1)
	var k := mini(int(floor(f)), poly.size() - 2)
	return (poly[k] as Vector3).lerp(poly[k + 1], f - float(k))

static func _quad(v: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color) -> void:
	for p in [a, b, d, a, d, e]:
		v.append(p)
		c.append(col)

func _water_strip(z: Dictionary) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var half := float(z["half"])
	var wy := float(z["y"])
	var k := 0
	var i := int(z["i0"])
	var i1 := int(z["i1"])
	while i <= i1:
		var p: Vector3 = track.samples[i]
		var l: Vector3 = track.laterals[i]
		verts.append(Vector3(p.x - l.x * half, wy, p.z - l.z * half))
		verts.append(Vector3(p.x + l.x * half, wy, p.z + l.z * half))
		uvs.append(Vector2(0.0, float(i) * 0.05))
		uvs.append(Vector2(1.0, float(i) * 0.05))
		if k > 0:
			var a := (k - 1) * 2
			idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
		k += 1
		i += 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	nrm.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = nrm
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.36, 0.40, 0.74)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.07
	mat.metallic_specular = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Piedras a los lados: muchas en el pedregal, algunas sueltas en el resto
func _rocks() -> MultiMeshInstance3D:
	var view = track.make_view(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2718
	var rock_zones: Array = []
	for sc in track.sections:
		if ROCKY.has(str(sc["name"])):
			rock_zones.append([int(sc["i0"]), int(sc["i1"])])
	var xf: Array = []
	var edge: float = float(track.half_width + track.shoulder)
	var i := 0
	while i < track.n:
		var dense := false
		for rz in rock_zones:
			if i >= int(rz[0]) and i <= int(rz[1]):
				dense = true
		var step := 3 if dense else 16
		var p: Vector3 = track.samples[i]
		var l: Vector3 = track.laterals[i]
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var off := edge * (0.78 if dense else 0.95) + rng.randf_range(0.0, 5.0 if dense else 3.0)
		var x := p.x + l.x * side * off
		var z := p.z + l.z * side * off
		var sc := rng.randf_range(0.5, 1.7 if dense else 1.2)
		var y: float = view.ground_smooth(x, z)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc * rng.randf_range(0.8, 1.4), sc * rng.randf_range(0.55, 0.9), sc * rng.randf_range(0.8, 1.3)))
		xf.append(Transform3D(b, Vector3(x, y + sc * 0.18, z)))
		i += step
	if xf.is_empty():
		return null
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.2
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.43, 0.39)
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	sm.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xf.size()
	for k in xf.size():
		mm.set_instance_transform(k, xf[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = 420.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

## Arrastre del agua: 0 = fuera del agua, hasta 1 = bien metido (el agua frena y salpica). Se pregunta con la posición del auto.
func water_depth(x: float, z: float) -> float:
	for w in track.water:
		var i0 := int(w["i0"])
		var i1 := int(w["i1"])
		var a: Vector3 = track.samples[i0]
		var b: Vector3 = track.samples[i1]
		var half := float(w["half"]) + 60.0
		var cx := (a.x + b.x) * 0.5
		var cz := (a.z + b.z) * 0.5
		var span := a.distance_to(b) * 0.5 + half
		if absf(x - cx) > span or absf(z - cz) > span:
			continue
		var best := 1e18
		var bi := i0
		var i := i0
		while i <= i1:
			var dx: float = track.samples[i].x - x
			var dz: float = track.samples[i].z - z
			var d := dx * dx + dz * dz
			if d < best:
				best = d
				bi = i
			i += 2
		var cyv: float = track.cy[bi]
		return clampf((float(w["y"]) - cyv) / 0.5, 0.0, 1.0) if best < 36.0 else 0.0
	return 0.0
