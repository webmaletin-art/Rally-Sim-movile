extends RefCounted
## Arma mallas a mano (vértices, normales, colores, UV e índices) para juntar muchas piezas en un solo objeto:
## una cuadra de casas, el alambrado de un tramo o toda una estación de servicio se dibujan con una sola llamada.

var v := PackedVector3Array()
var nm := PackedVector3Array()
var col := PackedColorArray()
var uv := PackedVector2Array()
var idx := PackedInt32Array()

func size() -> int:
	return v.size()

func clear() -> void:
	v.clear()
	nm.clear()
	col.clear()
	uv.clear()
	idx.clear()

## Triángulo (el frente es el lado desde el que a→b→c se ve en sentido antihorario)
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var n := (b - a).cross(c - a).normalized()
	var o := v.size()
	v.append_array([a, b, c])
	nm.append_array([n, n, n])
	col.append_array([color, color, color])
	uv.append_array([ua, ub, uc])
	idx.append_array([o, o + 2, o + 1])

## Cuadrilátero a-b-c-d (antihorario visto desde el frente); u0/u1 = esquinas de la textura
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, u0 := Vector2(0, 1), u1 := Vector2(1, 0)) -> void:
	var n := (b - a).cross(d - a).normalized()
	if n == Vector3.ZERO:
		n = (c - b).cross(d - b).normalized()
	var o := v.size()
	v.append_array([a, b, c, d])
	nm.append_array([n, n, n, n])
	col.append_array([color, color, color, color])
	uv.append_array([u0, Vector2(u1.x, u0.y), u1, Vector2(u0.x, u1.y)])
	idx.append_array([o, o + 2, o + 1, o, o + 3, o + 2])

## Caja transformada (centro en el origen de xf, tamaño s). top: color de la tapa de arriba (opcional)
func box(xf: Transform3D, s: Vector3, color: Color, top := Color(0, 0, 0, 0), uvr := Rect2(0, 0, 0, 0)) -> void:
	var h := s * 0.5
	var p := [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z), xf * Vector3(h.x, h.y, -h.z), xf * Vector3(-h.x, h.y, -h.z),
		xf * Vector3(-h.x, -h.y, h.z), xf * Vector3(h.x, -h.y, h.z), xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z)]
	var tc := color if top.a == 0.0 else top
	var u0 := uvr.position
	var u1 := uvr.position + uvr.size
	# caras: −z, +z, −x, +x, +y, −y
	quad(p[1], p[0], p[3], p[2], color, Vector2(u0.x, u1.y), Vector2(u1.x, u0.y))
	quad(p[4], p[5], p[6], p[7], color, Vector2(u0.x, u1.y), Vector2(u1.x, u0.y))
	quad(p[0], p[4], p[7], p[3], color, Vector2(u0.x, u1.y), Vector2(u1.x, u0.y))
	quad(p[5], p[1], p[2], p[6], color, Vector2(u0.x, u1.y), Vector2(u1.x, u0.y))
	quad(p[7], p[6], p[2], p[3], tc, Vector2(u0.x, u1.y), Vector2(u1.x, u0.y))
	quad(p[0], p[1], p[5], p[4], color.darkened(0.3), Vector2(u0.x, u1.y), Vector2(u1.x, u0.y))

## Cilindro/cono a lo largo del eje Y local de xf (base en el origen)
func cyl(xf: Transform3D, r0: float, r1: float, h: float, seg: int, color: Color, cap := true, top_color := Color(0, 0, 0, 0)) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		var b0 := xf * Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
		var b1 := xf * Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
		var t0 := xf * Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var t1 := xf * Vector3(cos(a1) * r1, h, sin(a1) * r1)
		quad(b1, b0, t0, t1, color, Vector2(float(i) / float(seg), 1), Vector2(float(i + 1) / float(seg), 0))
		if cap and r1 > 0.001:
			tri(xf * Vector3(0, h, 0), t1, t0, top_color if top_color.a > 0.0 else color)

## Malla cerrada de "esfera abollada" (copas de árboles, arbustos, rocas): octaedro subdividido con ruido
func blob(center: Vector3, r: Vector3, color: Color, rng: RandomNumberGenerator, rough := 0.25, shade := 0.35, subdiv := 1) -> void:
	var base := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var faces := [[0, 2, 4], [4, 2, 1], [1, 2, 5], [5, 2, 0], [4, 3, 0], [1, 3, 4], [5, 3, 1], [0, 3, 5]]
	var tris: Array = []
	for f in faces:
		tris.append([base[f[0]], base[f[1]], base[f[2]]])
	for s in subdiv:
		var nt: Array = []
		for t in tris:
			var a: Vector3 = t[0]
			var b: Vector3 = t[1]
			var c: Vector3 = t[2]
			var ab := ((a + b) * 0.5).normalized()
			var bc := ((b + c) * 0.5).normalized()
			var ca := ((c + a) * 0.5).normalized()
			nt.append_array([[a, ab, ca], [ab, b, bc], [ca, bc, c], [ab, bc, ca]])
		tris = nt
	var disp := {}
	for t in tris:
		var pts: Array = []
		for q in t:
			var key := Vector3i(roundi(q.x * 1000.0), roundi(q.y * 1000.0), roundi(q.z * 1000.0))
			if not disp.has(key):
				disp[key] = 1.0 + rng.randf_range(-rough, rough)
			var d: float = disp[key]
			pts.append(center + Vector3(q.x * r.x, q.y * r.y, q.z * r.z) * d)
		# normales suaves (desde el centro): la copa se ve redonda y frondosa, no facetada
		var o := v.size()
		for q2 in 3:
			var pp: Vector3 = pts[q2]
			var rel := pp - center
			var my := rel.y / maxf(r.y, 0.01)
			var k := 1.0 - shade * (0.5 - 0.5 * my) # más oscuro abajo
			var jit := 0.92 + 0.16 * fposmod(pp.x * 3.7 + pp.z * 5.3 + pp.y * 2.1, 1.0) # hojas más claras y más oscuras
			v.append(pp)
			nm.append(Vector3(rel.x / maxf(r.x, 0.01), rel.y / maxf(r.y, 0.01), rel.z / maxf(r.z, 0.01)).normalized())
			col.append(Color(color.r * k * jit, color.g * k * jit, color.b * k * jit, color.a))
			uv.append(Vector2.ZERO)
		idx.append_array([o, o + 2, o + 1])

## Agrega otra malla armada (opcionalmente transformada y teñida)
func add(o: RefCounted, xf := Transform3D.IDENTITY, tint := Color(1, 1, 1)) -> void:
	var off := v.size()
	var b := xf.basis
	for i in o.v.size():
		v.append(xf * o.v[i])
		nm.append((b * o.nm[i]).normalized())
		var c: Color = o.col[i]
		col.append(Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
		uv.append(o.uv[i])
	for q in o.idx:
		idx.append(q + off)

func arrays() -> Array:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nm
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = idx
	return arr

## Malla lista (null si está vacía)
func commit(mat: Material, into: ArrayMesh = null) -> ArrayMesh:
	if v.is_empty():
		return into
	var m := into if into != null else ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays())
	m.surface_set_material(m.get_surface_count() - 1, mat)
	return m
