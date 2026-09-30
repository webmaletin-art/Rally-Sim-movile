extends "res://game/physics/track_base.gd"
## Pistas por curva de la versión HTML (clase Track de js/main.js): una ruta cerrada que pasa por unos puntos de control
## (Catmull-Rom, 1100 muestras a igual distancia), con altura, badenes, corona del camino, banquina, zanja y pasto.
## La física pide altura y superficie con ground_info(); cada auto usa su propia "vista" (make_view) porque la búsqueda del
## tramo más cercano guarda el último resultado y los autos corren en hilos distintos.
## godot/tests/track_test.gd compara con el código real de la versión HTML (tools/godot/track_reference.mjs).

const N_SAMPLES := 1100
const BUMP_AMP := [0.005, 0.03, 0.035, 0.045, 0.05, 0.03] # por superficie: asfalto, tierra, banquina, pasto, afuera, barro

var route_id := ""
var mode := "asphalt" # "asphalt" | "dirt"
var half_width := 5.0
var shoulder := 2.0
var dips: Array = []
var ctrl: PackedVector3Array = PackedVector3Array()
var samples: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var laterals: PackedVector3Array = PackedVector3Array()
var cum: PackedFloat64Array = PackedFloat64Array()
var cy: PackedFloat64Array = PackedFloat64Array() # altura del centro del camino en cada muestra (con la corona)
var length := 0.0
var n := 0
var min_xz := Vector2.ZERO
var max_xz := Vector2.ZERO

# resultado de la última búsqueda (por vista)
var hint := -1
var trust := false
var r_dist := 0.0
var r_idx := 0
var r_t := 0.0
var r_y := 0.0
var r_lat := 0.0
var _bd := 0.0
var _bi := 0
var _bt := 0.0

static var _routes: Dictionary
var views: Array = [] # vistas creadas (para propagar el agarre)
var prof_cache := {} # perfiles de velocidad de la IA (se comparten con las vistas)

## route: nombre en routes.json; reverse: sentido inverso. p_mode: "asphalt" o "dirt"
func _init(p_route := "", p_mode := "asphalt", reverse := false) -> void:
	if p_route == "":
		return
	if _routes.is_empty():
		_routes = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["routes"]
	var r: Dictionary = _routes[p_route]
	route_id = p_route
	mode = p_mode
	half_width = float(r["halfWidth"])
	shoulder = float(r["shoulder"])
	dips = r.get("dips", [])
	var pts: Array = r["points"]
	if reverse:
		var tail: Array = pts.slice(1)
		tail.reverse()
		pts = [pts[0]] + tail
	for p in pts:
		ctrl.append(Vector3(p[0], p[1], p[2]))
	_build()

func center_xz() -> Vector2:
	return (min_xz + max_xz) * 0.5

## Otra vista de la misma pista (comparte los datos, tiene su propia búsqueda)
func make_view() -> Object:
	var v = (get_script() as GDScript).new()
	v.route_id = route_id
	v.mode = mode
	v.half_width = half_width
	v.shoulder = shoulder
	v.dips = dips
	v.ctrl = ctrl
	v.samples = samples
	v.tangents = tangents
	v.laterals = laterals
	v.cum = cum
	v.cy = cy
	v.length = length
	v.n = n
	v.min_xz = min_xz
	v.max_xz = max_xz
	v.grip_mul = grip_mul
	v.prof_cache = prof_cache
	views.append(v)
	return v

## Agarre global de la pista (lluvia): se copia a todas las vistas
func set_grip(g: float) -> void:
	grip_mul = g
	for v in views:
		v.grip_mul = g

# ───────────────────────── construcción de la ruta ─────────────────────────
static func _cr(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, w: float) -> Vector3:
	# Catmull-Rom uniforme con tensión 0,5 (igual que CatmullRomCurve3 de three.js)
	var t1 := (p2 - p0) * 0.5
	var t2 := (p3 - p1) * 0.5
	var c2 := p1 * -3.0 + p2 * 3.0 - t1 * 2.0 - t2
	var c3 := p1 * 2.0 - p2 * 2.0 + t1 + t2
	return p1 + t1 * w + c2 * w * w + c3 * w * w * w

func _curve_point(t: float) -> Vector3:
	var l := ctrl.size()
	var p := float(l) * t
	var ip := int(floor(p))
	var w := p - float(ip)
	return _cr(ctrl[posmod(ip - 1, l)], ctrl[posmod(ip, l)], ctrl[posmod(ip + 1, l)], ctrl[posmod(ip + 2, l)], w)

func _build() -> void:
	# tabla de longitudes para repartir las muestras a igual distancia (como getSpacedPoints)
	var div := 3000
	var lens := PackedFloat64Array()
	lens.resize(div + 1)
	var prev := _curve_point(0.0)
	for i in range(1, div + 1):
		var c := _curve_point(float(i) / float(div))
		lens[i] = lens[i - 1] + prev.distance_to(c)
		prev = c
	var total := lens[div]
	samples.resize(N_SAMPLES)
	for i in N_SAMPLES:
		var target := total * float(i) / float(N_SAMPLES)
		var lo := 0
		var hi := div
		while lo < hi:
			var mid := (lo + hi) / 2
			if lens[mid] < target:
				lo = mid + 1
			else:
				hi = mid
		var b := lo if lens[lo] == target else lo - 1
		b = clampi(b, 0, div - 1)
		var seg := lens[b + 1] - lens[b]
		var u := (target - lens[b]) / seg if seg > 0.0 else 0.0
		samples[i] = _curve_point((float(b) + u) / float(div))
	n = N_SAMPLES
	# altura: interpolación de los puntos de control + ondulación, suavizada con media móvil circular
	var y := PackedFloat64Array()
	y.resize(n)
	var lc := ctrl.size()
	for i in n:
		var t := float(i) / float(n)
		var ii := int(floor(t * lc)) % lc
		var u2 := fposmod(t * lc, 1.0)
		var a := ctrl[ii].y
		var b2 := ctrl[(ii + 1) % lc].y
		y[i] = a + (b2 - a) * u2 + 0.20 * sin(t * PI * 6.0) + 0.10 * sin(t * PI * 15.0)
	for W in [6, 6, 4]:
		var o := PackedFloat64Array()
		o.resize(n)
		for i in n:
			var s := 0.0
			for j in range(-W, W + 1):
				s += y[posmod(i + j, n)]
			o[i] = s / float(2 * W + 1)
		y = o
	for i in n:
		samples[i].y = y[i]
	if not dips.is_empty():
		_apply_dips()
	tangents.resize(n)
	laterals.resize(n)
	for i in n:
		var tg := (samples[(i + 1) % n] - samples[(i + n - 1) % n]).normalized()
		tangents[i] = tg
		laterals[i] = tg.cross(Vector3.UP).normalized()
	cum.resize(n + 1)
	for i in range(1, n + 1):
		cum[i] = cum[i - 1] + samples[i - 1].distance_to(samples[i % n])
	length = cum[n]
	cy.resize(n)
	for i in n:
		cy[i] = samples[i].y + _road_offset(i)
	min_xz = Vector2(1e9, 1e9)
	max_xz = Vector2(-1e9, -1e9)
	for p in ctrl:
		min_xz = Vector2(minf(min_xz.x, p.x), minf(min_xz.y, p.z))
		max_xz = Vector2(maxf(max_xz.x, p.x), maxf(max_xz.y, p.z))
	min_xz -= Vector2(180, 180)
	max_xz += Vector2(180, 180)

func _apply_dips() -> void:
	var c := PackedFloat64Array()
	c.resize(n)
	for i in range(1, n):
		c[i] = c[i - 1] + samples[i].distance_to(samples[i - 1])
	for d in dips:
		var i0 := int(floor(float(d["from"]) * n))
		var i1 := int(floor(float(d["to"]) * n))
		var s0 := c[i0]
		var s1 := c[i1]
		for i in range(i0, i1 + 1):
			var u := (c[i] - s0) / maxf(1.0, s1 - s0)
			var win := minf(1.0, minf(u * 6.0, (1.0 - u) * 6.0))
			samples[i].y += -float(d["amp"]) * win * 0.5 * (1.0 - cos(2.0 * PI * (c[i] - s0) / float(d["wave"])))

func _road_offset(i: int) -> float:
	var t := float(i) / float(n)
	return 0.06 + 0.10 * sin(t * PI * 5.0) + 0.04 * sin(t * PI * 13.0) - 0.25 * exp(-pow((t - 0.43) / 0.045, 2.0)) + 0.18 * exp(-pow((t - 0.73) / 0.06, 2.0))

# ───────────────────────── búsqueda del tramo más cercano ─────────────────────────
func _seg_d(x: float, z: float, i: int) -> float:
	var a := samples[i]
	var b := samples[(i + 1) % n]
	var abx := b.x - a.x
	var abz := b.z - a.z
	var den := abx * abx + abz * abz
	var t := clampf(((x - a.x) * abx + (z - a.z) * abz) / den, 0.0, 1.0) if den > 0.0 else 0.0
	var dx := x - (a.x + abx * t)
	var dz := z - (a.z + abz * t)
	return dx * dx + dz * dz

func _scan(x: float, z: float, i0: int, cnt: int) -> void:
	for k in cnt:
		var i := posmod(i0 + k, n)
		var a := samples[i]
		var b := samples[(i + 1) % n]
		var abx := b.x - a.x
		var abz := b.z - a.z
		var den := abx * abx + abz * abz
		var t := clampf(((x - a.x) * abx + (z - a.z) * abz) / den, 0.0, 1.0) if den > 0.0 else 0.0
		var dx := x - (a.x + abx * t)
		var dz := z - (a.z + abz * t)
		var d := dx * dx + dz * dz
		if d < _bd:
			_bd = d
			_bi = i
			_bt = t

## Deja en r_* el tramo más cercano a (x, z). Desde "hint" camina cuesta abajo (mucho más rápido que revisar todo).
func nearest(x: float, z: float) -> void:
	var Wd := 35
	_bd = INF
	_bi = 0
	_bt = 0.0
	if hint >= 0:
		var h := hint
		var i := h
		var d := _seg_d(x, z, i)
		for st in [1, -1]:
			var k := 0
			while k < Wd:
				k += 1
				var j := posmod(i + st, n)
				var dj := _seg_d(x, z, j)
				if dj < d:
					i = j
					d = dj
				else:
					break
			if i != h:
				break
		_scan(x, z, i - 4, 9)
		# lejos del camino puede haber varios mínimos: ahí se revisa una ventana completa
		if _bd > 225.0 or trust:
			_bd = INF
			_scan(x, z, h - Wd, 2 * Wd + 1)
		var off := _bi - h
		if off > n / 2:
			off -= n
		if off < -n / 2:
			off += n
		if absi(off) >= Wd - 1 or (_bd > 900.0 and not trust):
			_bd = INF
			_scan(x, z, 0, n)
	else:
		_scan(x, z, 0, n)
	hint = _bi
	var a := samples[_bi]
	var b := samples[(_bi + 1) % n]
	r_idx = _bi
	r_t = _bt
	r_y = lerpf(cy[_bi], cy[(_bi + 1) % n], _bt)
	var lat := laterals[_bi]
	r_lat = (x - (a.x + (b.x - a.x) * _bt)) * lat.x + (z - (a.z + (b.z - a.z) * _bt)) * lat.z
	r_dist = sqrt(_bd)

func _terrain_base(x: float, z: float, road_y: float) -> float:
	return road_y - 0.25 + 0.7 * sin(x * 0.020 + z * 0.018) + 0.35 * sin(x * 0.045 - z * 0.038 + 1.3) + 0.18 * sin(x * 0.11 + z * 0.09 + 2.7)

func _ditch(d: float, se: float) -> float:
	var dd := maxf(0.0, d - se)
	var s := dd * dd / (dd * dd + 9.0)
	return 0.28 * s * exp(-dd / 15.0)

func _micro_bump(x: float, z: float, surf: int) -> float:
	var a: float = BUMP_AMP[surf]
	var nn := sin(x * 0.71 + z * 0.53) * sin(x * 0.29 - z * 0.83 + 1.3) * 0.6 + sin(x * 1.9 + z * 1.3 + 0.7) * 0.15 + sin(x * 0.17 + z * 0.13 + 2.1) * 0.25
	return a * (0.5 + 0.5 * nn)

func _surf_of(d: float) -> int:
	var se := half_width + shoulder
	if d <= half_width:
		return 0 if mode == "asphalt" else 1
	if d <= se:
		return 2
	return 3 if d < 12.0 else 4

## Altura y superficie (0 asfalto · 1 tierra · 2 banquina · 3 pasto · 4 afuera · 5 barro) en un punto
func ground_info(x: float, z: float) -> Vector2:
	nearest(x, z)
	var d := absf(r_lat)
	var edge := half_width
	var se := edge + shoulder
	var y: float
	if d <= edge:
		y = r_y + (1.0 - pow(minf(d / edge, 1.0), 2.0)) * 0.03
	else:
		var base := _terrain_base(x, z, r_y)
		if d <= se:
			var t := (d - edge) / shoulder
			y = r_y * (1.0 - t) + base * t + 0.10 * sin(t * PI)
		else:
			y = base - _ditch(d, se)
	var surf := _surf_of(d)
	return Vector2(y + _micro_bump(x, z, surf), float(surf))

## Altura del terreno sin la ondulación fina (para dibujar)
func ground_smooth(x: float, z: float) -> float:
	nearest(x, z)
	var d := absf(r_lat)
	var edge := half_width
	var se := edge + shoulder
	var base := _terrain_base(x, z, r_y)
	if d <= edge:
		return r_y + (1.0 - pow(minf(d / edge, 1.0), 2.0)) * 0.03
	if d <= se:
		var t := (d - edge) / shoulder
		return r_y * (1.0 - t) + base * t + 0.10 * sin(t * PI)
	return base - _ditch(d, se)

# ───────────────────────── largada y progreso ─────────────────────────
## Pose de largada en el lugar "slot" de la parrilla (0 = adelante a la derecha): x, z, yaw
func start_pose(slot: int) -> Array:
	var back := 6.0 + float(slot / 2) * 9.0
	var i := 0
	var acc := 0.0
	while acc < back:
		var j := posmod(i - 1, n)
		acc += samples[i].distance_to(samples[j])
		i = j
	var side := -1.0 if slot % 2 == 0 else 1.0
	var s := samples[i]
	var l := laterals[i]
	var t := tangents[i]
	return [s.x + l.x * side * 2.0, s.z + l.z * side * 2.0, atan2(t.x, t.z), i]

## distancia recorrida sobre la ruta (m) del punto más cercano, para posiciones y vueltas
func arc_pos(x: float, z: float) -> float:
	nearest(x, z)
	return cum[r_idx] + r_t * (cum[r_idx + 1] - cum[r_idx])

# ───────────────────────── dibujo ─────────────────────────
func _asphalt_tex() -> ImageTexture:
	var img := Image.create(128, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var base := Color(0.20, 0.205, 0.22) if mode == "asphalt" else Color(0.36, 0.29, 0.22)
	for y in 256:
		for x in 128:
			var q := (rng.randf() - 0.5) * 0.07
			img.set_pixel(x, y, Color(base.r + q, base.g + q, base.b + q))
	if mode == "asphalt":
		for y in 256:
			for x in range(8, 14):
				img.set_pixel(x, y, Color(0.92, 0.92, 0.88))
			for x in range(114, 120):
				img.set_pixel(x, y, Color(0.92, 0.92, 0.88))
		for y in range(0, 128):
			for x in range(62, 67):
				img.set_pixel(x, y, Color(0.96, 0.80, 0.27))
	else:
		for y in 256:
			for xs in [38, 90]:
				var ox := int(sin(float(y) * 0.05) * 3.0)
				for x in range(xs - 9 + ox, xs + 9 + ox):
					var c := img.get_pixel(clampi(x, 0, 127), y)
					img.set_pixel(clampi(x, 0, 127), y, c.darkened(0.16))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Camino: una cinta de dos vértices por muestra
func build_road_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for i in n:
		var p := samples[i]
		var lat := laterals[i]
		var y := cy[i] + 0.015
		verts.append(Vector3(p.x - lat.x * half_width, y, p.z - lat.z * half_width))
		verts.append(Vector3(p.x + lat.x * half_width, y, p.z + lat.z * half_width))
		uvs.append(Vector2(0, float(i) * 0.22))
		uvs.append(Vector2(1, float(i) * 0.22))
	for i in n:
		var j := (i + 1) % n
		var a := i * 2
		var b := i * 2 + 1
		var c := j * 2
		var d := j * 2 + 1
		idx.append_array([a, b, c, b, d, c])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = normals
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _asphalt_tex()
	mat.roughness = 0.9
	mat.uv1_scale = Vector3(1, 1, 1)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.surface_set_material(0, mat)
	return m

## Banquina y franja exterior: copia lo que pisa la física (ground_smooth) y se abre en pasto
func build_shoulder_mesh() -> ArrayMesh:
	var ext := 26.0
	var fr := [0.0, 1.0, 1.6, 3.2, 6.0, 10.0, 16.0, 23.0, ext]
	var rw := fr.size()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var c_sh := Color(0.48, 0.42, 0.34)
	var c_gr := Color(0.28, 0.40, 0.24)
	var view = make_view()
	view.hint = -1
	for i in n:
		var p := samples[i]
		var lat := laterals[i]
		var yc := cy[i]
		for s in [-1.0, 1.0]:
			for k in rw:
				var f: float = fr[k]
				var x: float
				var z: float
				var yy: float
				if f == 0.0:
					x = p.x + lat.x * s * half_width
					z = p.z + lat.z * s * half_width
					yy = yc + 0.01
				elif f == 1.0:
					x = p.x + lat.x * s * (half_width + shoulder)
					z = p.z + lat.z * s * (half_width + shoulder)
					view.hint = i
					yy = view.ground_smooth(x, z) + 0.03
				else:
					var o := half_width + shoulder + (f - 1.0)
					x = p.x + lat.x * s * o
					z = p.z + lat.z * s * o
					var e := (f - 1.0) / (ext - 1.0)
					view.hint = i
					yy = view.ground_smooth(x, z) + 0.02 - 0.24 * e * e
				verts.append(Vector3(x, yy, z))
				cols.append(c_sh if f <= 1.0 else c_sh.lerp(c_gr, minf(1.0, (f - 1.0) / 3.5)))
	for i in n:
		var ni := (i + 1) % n
		for side in 2:
			for k in rw - 1:
				var a := i * rw * 2 + side * rw + k
				var b := a + 1
				var c := ni * rw * 2 + side * rw + k
				var d := c + 1
				# orienta cada triángulo hacia arriba (en curvas cerradas la franja se pliega)
				for tri in [[a, b, c], [b, d, c]]:
					var va: Vector3 = verts[tri[0]]
					var vb: Vector3 = verts[tri[1]]
					var vc: Vector3 = verts[tri[2]]
					if (vb - va).cross(vc - va).y < 0.0:
						idx.append_array([tri[0], tri[2], tri[1]])
					else:
						idx.append_array(tri)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.generate_normals()
	var out := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	out.surface_set_material(0, mat)
	return out

## Terreno alrededor: grilla con la altura de la física (hundida bajo el camino para que no asome nada)
func terrain_dims(cell_min := 14.0) -> Dictionary:
	var ext := max_xz - min_xz
	var r := int(clampf(ceil(maxf(ext.x, ext.y) / cell_min), 60.0, 220.0))
	return {"R": r, "cell": maxf(ext.x, ext.y) / float(r)}

## Una fila de la grilla (para repartir en hilos): devuelve posiciones y colores
func terrain_row(iz: int, r: int) -> Array:
	var view = make_view()
	view.trust = true
	var span := maxf(max_xz.x - min_xz.x, max_xz.y - min_xz.y)
	var z := min_xz.y + span * float(iz) / float(r)
	var pos := PackedVector3Array()
	var col := PackedColorArray()
	var coarse := PackedInt32Array()
	for i in range(0, n, 6):
		coarse.append(i)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + iz
	var sr := half_width + (span / float(r)) * 1.45
	for ix in r + 1:
		var x := min_xz.x + span * float(ix) / float(r)
		var bi := 0
		var bd := 1e18
		for i in coarse:
			var dx := samples[i].x - x
			var dz := samples[i].z - z
			var dd := dx * dx + dz * dz
			if dd < bd:
				bd = dd
				bi = i
		view.hint = bi
		var y0: float = view.ground_smooth(x, z) - 0.25
		var d: float = absf(view.r_lat)
		pos.append(Vector3(x, y0 - (0.6 if d < sr else 0.0), z))
		var cc := Color(0.45, 0.38, 0.30) if d < half_width + shoulder else Color(0.29, 0.40, 0.24)
		var q := (rng.randf() - 0.5) * 0.08
		col.append(Color(cc.r + q, cc.g + q, cc.b + q * 0.5))
	return [pos, col]

func build_terrain_mesh(rows: Array, r: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for row in rows:
		verts.append_array(row[0])
		cols.append_array(row[1])
	var idx := PackedInt32Array()
	for iz in r:
		for ix in r:
			var a := iz * (r + 1) + ix
			var b := a + 1
			var c := a + r + 1
			var d := c + 1
			idx.append_array([a, c, b, b, c, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	st.generate_normals()
	var out := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	out.surface_set_material(0, mat)
	return out

## Línea de largada con dos postes y el cartel
func build_start_gate() -> Node3D:
	var g := Node3D.new()
	var p := samples[0]
	var l := laterals[0]
	var tg := tangents[0]
	var w := half_width + shoulder * 0.6
	var yaw := atan2(tg.x, tg.z)
	# línea a cuadros pegada al camino
	var img := Image.create(64, 8, false, Image.FORMAT_RGB8)
	for y in 8:
		for x in 64:
			img.set_pixel(x, y, Color(0.96, 0.96, 0.96) if ((x / 4) + (y / 4)) % 2 == 0 else Color(0.08, 0.08, 0.08))
	var lm := StandardMaterial3D.new()
	lm.albedo_texture = ImageTexture.create_from_image(img)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var lp := PlaneMesh.new()
	lp.size = Vector2(half_width * 2.0, 1.2)
	var line := MeshInstance3D.new()
	line.mesh = lp
	line.material_override = lm
	line.position = Vector3(p.x, cy[0] + 0.04, p.z)
	line.rotation.y = yaw
	g.add_child(line)
	# postes y cartel
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.13, 0.14, 0.17)
	pm.metallic = 0.6
	pm.roughness = 0.4
	for sd in [-1.0, 1.0]:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 5.2, 0.35)
		var post := MeshInstance3D.new()
		post.mesh = bm
		post.material_override = pm
		post.position = Vector3(p.x + l.x * w * sd, cy[0] + 2.6, p.z + l.z * w * sd)
		g.add_child(post)
	var ban := Label3D.new()
	ban.text = "GSKORP RALLY"
	ban.font_size = 96
	ban.pixel_size = 0.012
	ban.modulate = Color(1, 1, 1)
	ban.outline_size = 24
	ban.outline_modulate = Color(0.05, 0.07, 0.1)
	ban.double_sided = true
	ban.shaded = false
	ban.position = Vector3(p.x, cy[0] + 4.7, p.z)
	ban.rotation.y = yaw + PI
	g.add_child(ban)
	return g
