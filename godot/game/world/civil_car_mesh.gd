extends RefCounted
## Malla de los autos civiles del mundo abierto (estacionados y tránsito): «cajas con rampas». Una carrocería armada con cortes a lo largo del auto (baúl, parabrisas inclinado, techo, luneta, capó) en vez de siete cajas
## apiladas, ruedas de seis lados, faros y luces traseras. Son ~190 triángulos con normales planas (la caja apilada tenía 84 y sin normales): la silueta se lee como auto desde lejos y el costo es el mismo de siempre:
## una sola malla y un MultiMesh por sector (una llamada de dibujo). NO es la de los autos del jugador ni la de los otros jugadores (online/remote_cars.gd).
## Espacio local: +z = frente, +y arriba, el auto mide 4,3 x 1,8 m y la carrocería es blanca (el color de cada auto lo da el MultiMesh).

static var _mesh: ArrayMesh
static var _tris := 0

const GLASS := Color(0.16, 0.22, 0.30)
const ROOF := Color(0.92, 0.92, 0.92)
const DARK := Color(0.10, 0.10, 0.12)
const HEAD := Color(1.0, 0.95, 0.75)
const TAIL := Color(0.85, 0.10, 0.08)

## Cortes de la carrocería, de atrás para adelante: [z, y de la base, y de la cintura, y del techo, medio ancho de la cintura, medio ancho del techo]
const STATIONS := [
	[-2.15, 0.34, 0.90, 0.90, 0.88, 0.88],
	[-1.55, 0.26, 1.00, 1.00, 0.90, 0.90],  # fin del baúl
	[-0.95, 0.26, 1.00, 1.42, 0.90, 0.70],  # sube la luneta
	[0.35, 0.26, 1.00, 1.42, 0.90, 0.70],   # techo
	[1.05, 0.26, 0.98, 0.98, 0.90, 0.90],   # baja el parabrisas
	[2.15, 0.34, 0.80, 0.80, 0.86, 0.86],   # capó hasta el paragolpes
]

static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var centre := Vector3(0, 0.8, 0)
	var white := Color(1, 1, 1)
	# carrocería: seis cortes unidos (cada tramo: costado, parante de vidrio, techo, parante, costado)
	var rings: Array = []
	for st in STATIONS:
		var z: float = st[0]
		var y0: float = st[1]
		var yb: float = st[2]
		var yt: float = st[3]
		var hb: float = st[4]
		var ht: float = st[5]
		rings.append([Vector3(-hb, y0, z), Vector3(-hb, yb, z), Vector3(-ht, yt, z), Vector3(ht, yt, z), Vector3(hb, yb, z), Vector3(hb, y0, z)])
	for s in rings.size() - 1:
		var a: Array = rings[s]
		var b: Array = rings[s + 1]
		var cabin: bool = (float(STATIONS[s][3]) > float(STATIONS[s][2]) + 0.01) or (float(STATIONS[s + 1][3]) > float(STATIONS[s + 1][2]) + 0.01)
		var rising: bool = not is_equal_approx(float(STATIONS[s][3]), float(STATIONS[s + 1][3])) # rampa: luneta o parabrisas (vidrio) · plana: techo
		_quad(v, n, c, a[0], a[1], b[1], b[0], white, centre) # costado izquierdo
		_quad(v, n, c, a[4], a[5], b[5], b[4], white, centre) # costado derecho
		var side_col := GLASS if cabin else white
		_quad(v, n, c, a[1], a[2], b[2], b[1], side_col, centre) # parante izquierdo (vidrio)
		_quad(v, n, c, a[3], a[4], b[4], b[3], side_col, centre) # parante derecho
		var top_col := ROOF
		if cabin and rising:
			top_col = GLASS
		elif not cabin:
			top_col = white
		_quad(v, n, c, a[2], a[3], b[3], b[2], top_col, centre) # techo / capó / baúl
	for end in [0, rings.size() - 1]: # tapas: paragolpes de adelante y de atrás
		var r: Array = rings[end]
		_quad(v, n, c, r[0], r[1], r[4], r[5], white, centre)
		_quad(v, n, c, r[1], r[2], r[3], r[4], white, centre)
	# luces: faros adelante y traseras atrás (cajitas)
	for sx in [-0.62, 0.62]:
		_box(v, n, c, Vector3(float(sx), 0.62, 2.14), Vector3(0.40, 0.14, 0.06), HEAD)
		_box(v, n, c, Vector3(float(sx), 0.70, -2.14), Vector3(0.42, 0.14, 0.06), TAIL)
	# ruedas: prismas de seis lados con el eje en x
	for wx in [-0.92, 0.92]:
		for wz in [-1.40, 1.40]:
			_wheel(v, n, c, Vector3(float(wx), 0.33, float(wz)), 0.33, 0.24, DARK)
	_tris = v.size() / 3
	_mesh = ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_COLOR] = c
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.55
	mat.metallic = 0.2
	_mesh.surface_set_material(0, mat)
	return _mesh

static func triangle_count() -> int:
	mesh()
	return _tris

static func _tri(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, d: Vector3, col: Color, centre: Vector3) -> void:
	var nr := (b - a).cross(d - a)
	if nr.length() < 1e-8:
		return
	nr = nr.normalized()
	# Godot toma como frente de una cara el sentido horario: el producto vectorial apunta hacia ADENTRO del cuerpo y la normal (hacia afuera) es su opuesta
	if nr.dot((a + b + d) / 3.0 - centre) > 0.0:
		var t := b
		b = d
		d = t
		nr = -nr
	v.append(a)
	v.append(b)
	v.append(d)
	for i in 3:
		n.append(-nr)
		c.append(col)

static func _quad(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, centre: Vector3) -> void:
	_tri(v, n, c, a, b, d, col, centre)
	_tri(v, n, c, a, d, e, col, centre)

static func _box(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, cen: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		p.append(cen + Vector3(h.x if (i & 1) else -h.x, h.y if (i & 2) else -h.y, h.z if (i & 4) else -h.z))
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6]]:
		_quad(v, n, c, p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, cen)

static func _wheel(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, cen: Vector3, r: float, w: float, col: Color) -> void:
	var sides := 6
	for i in sides:
		var a0 := TAU * float(i) / float(sides) + PI / 6.0
		var a1 := TAU * float(i + 1) / float(sides) + PI / 6.0
		var p0 := Vector3(0, sin(a0) * r, cos(a0) * r)
		var p1 := Vector3(0, sin(a1) * r, cos(a1) * r)
		var hx := Vector3(w * 0.5, 0, 0)
		_quad(v, n, c, cen + p0 - hx, cen + p1 - hx, cen + p1 + hx, cen + p0 + hx, col, cen) # banda
		_tri(v, n, c, cen - hx, cen + p1 - hx, cen + p0 - hx, col, cen) # tapa de afuera
		_tri(v, n, c, cen + hx, cen + p0 + hx, cen + p1 + hx, col, cen) # tapa de adentro
