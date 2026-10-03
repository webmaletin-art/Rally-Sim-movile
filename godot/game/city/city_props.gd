extends RefCounted
## Objetos de la calle de Dream City en papel: farolas, árboles, semáforos y bolardos. Cada uno es un puñado de cajas y prismas de color liso (de 12 a 60 triángulos);
## todos los de una cuadra se juntan en una sola malla (una llamada de dibujo) y se rearma cuando uno se rompe: el objeto queda tirado en el piso.
## Espacio local del objeto: +y arriba y +z hacia la calle (hacia donde apunta el brazo de la farola o del semáforo).

enum { LAMP, TREE, LIGHT, BOLLARD, MONUMENT, PILLAR, PARKED, FLOWERS, BUSH, GRASS, RTREE, PUMP, BLOCK }
const RADIUS := [0.30, 0.45, 0.30, 0.20, 3.6, 1.0, 1.5, 0.0, 0.0, 0.0, 0.0, 0.9, 3.0] # 0 = decoración: no choca ni se rompe
const PieceBatch := preload("res://game/city/piece_batch.gd")
const STREET_TREES := ["tree_birch", "tree_tree", "tree_sassafras", "tree_quaking_aspen", "sc_acacia", "tree_weeping_willow", "abedul", "sc_cypress"]
const ROAD_TREES := ["alamo", "pino", "sc_pine", "tree_tree", "tree_birch", "tree_lombardy_poplar", "sc_cypress", "tree_sassafras", "arbol_hoja_ancha", "tree_quaking_aspen"]
const PALMS := ["palmera", "sc_palm_tree", "tree_palm_tree", "sc_coconut_tree"]
const FLOWER_PIECES := ["flor_roja", "flor_amarilla", "flor_violeta", "flor_blanca", "flor_naranja", "margarita"] # radio de choque de cada tipo (m)
const TYPE_NAMES := ["farola", "árbol", "semáforo", "bolardo", "monumento", "pilar", "auto estacionado"]
const SOLID_FROM := 4 # desde este tipo no se rompen (los de radio 0 son solo adorno)

static func _tri(v: PackedVector3Array, c: PackedColorArray, a: Vector3, b: Vector3, d: Vector3, center: Vector3, col: Color) -> void:
	# la cara mira hacia afuera del cuerpo (lejos de center)
	var nr := (b - a).cross(d - a)
	if nr.dot((a + b + d) / 3.0 - center) < 0.0:
		var t := b
		b = d
		d = t
	v.append(a)
	v.append(b)
	v.append(d)
	c.append(col)
	c.append(col)
	c.append(col)

## Caja alineada con los ejes locales, ya pasada por xf
static func box(v: PackedVector3Array, c: PackedColorArray, xf: Transform3D, cen: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		p.append(xf * (cen + Vector3(h.x if (i & 1) else -h.x, h.y if (i & 2) else -h.y, h.z if (i & 4) else -h.z)))
	var mid: Vector3 = xf * cen
	for f in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6]]:
		_tri(v, c, p[f[0]], p[f[1]], p[f[2]], mid, col)
		_tri(v, c, p[f[0]], p[f[2]], p[f[3]], mid, col)

## Charco de luz sobre el piso: un abanico de triángulos que se apaga hacia el borde (el alfa baja a 0)
static func halo(v: PackedVector3Array, c: PackedColorArray, xf: Transform3D, cen: Vector3, r: float, col: Color, n := 10) -> void:
	var mid: Vector3 = xf * cen
	var edge := Color(col.r, col.g, col.b, 0.0)
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		v.append(mid)
		v.append(xf * (cen + Vector3(cos(a0) * r, 0.0, sin(a0) * r)))
		v.append(xf * (cen + Vector3(cos(a1) * r, 0.0, sin(a1) * r)))
		c.append(col)
		c.append(edge)
		c.append(edge)

## Tronco de cono de n lados (r0 abajo, r1 arriba), con tapa de arriba
static func frustum(v: PackedVector3Array, c: PackedColorArray, xf: Transform3D, base: Vector3, r0: float, r1: float, hgt: float, n: int, col: Color, rot := 0.0) -> void:
	var mid: Vector3 = xf * (base + Vector3(0.0, hgt * 0.5, 0.0))
	var top := base + Vector3(0.0, hgt, 0.0)
	for i in n:
		var a0 := rot + TAU * float(i) / float(n)
		var a1 := rot + TAU * float(i + 1) / float(n)
		var b0: Vector3 = xf * (base + Vector3(cos(a0) * r0, 0.0, sin(a0) * r0))
		var b1: Vector3 = xf * (base + Vector3(cos(a1) * r0, 0.0, sin(a1) * r0))
		var t0: Vector3 = xf * (top + Vector3(cos(a0) * r1, 0.0, sin(a0) * r1))
		var t1: Vector3 = xf * (top + Vector3(cos(a1) * r1, 0.0, sin(a1) * r1))
		_tri(v, c, b0, b1, t1, mid, col)
		_tri(v, c, b0, t1, t0, mid, col)
		if r1 > 0.01:
			_tri(v, c, xf * top, t0, t1, mid, col.lightened(0.12))

## Pone un objeto en la malla. fallen: dirección (x, z) hacia donde cayó (Vector2.ZERO = parado)
static func emit(kind: int, x: float, y: float, z: float, yaw: float, seed_v: float, fallen: Vector2, v: PackedVector3Array, c: PackedColorArray, gv := PackedVector3Array(), gc := PackedColorArray()) -> void:
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))
	if fallen != Vector2.ZERO:
		var d := Vector3(fallen.x, 0.0, fallen.y).normalized()
		var axis := Vector3.UP.cross(d).normalized()
		xf = Transform3D(Basis(axis, deg_to_rad(84.0)) * Basis(Vector3.UP, yaw), Vector3(x, y + 0.12, z))
	match kind:
		LAMP:
			var steel := Color(0.24, 0.29, 0.31)
			box(v, c, xf, Vector3(0, 0.25, 0), Vector3(0.34, 0.5, 0.34), steel.darkened(0.15))
			box(v, c, xf, Vector3(0, 2.8, 0), Vector3(0.14, 5.1, 0.14), steel)
			box(v, c, xf, Vector3(0, 5.25, 0.6), Vector3(0.1, 0.1, 1.3), steel)
			box(v, c, xf, Vector3(0, 5.17, 1.25), Vector3(0.46, 0.16, 0.72), Color(1.0, 0.93, 0.68))
			if fallen == Vector2.ZERO:
				# de noche: la lámpara brilla y tira un charco de luz en el piso (superficie aparte, aditiva: ver CityWorld._glow_instance)
				box(gv, gc, xf, Vector3(0, 5.1, 1.25), Vector3(0.5, 0.2, 0.76), Color(1.0, 0.88, 0.5, 1.0))
				halo(gv, gc, xf, Vector3(0, 0.06, 1.2), 6.5, Color(1.0, 0.82, 0.45, 0.5))
		TREE:
			# árboles del pack de papel (con volumen: copas de ocho caras o más), de varias especies; cerca del mar, palmeras
			var sp: Array = PALMS if seed_v > 0.93 else STREET_TREES
			var id: String = sp[int(seed_v * 977.0) % sp.size()]
			PieceBatch.add(id, Vector3.ZERO, seed_v * TAU, 5.5 + 2.5 * fmod(seed_v * 13.7, 1.0), v, c, xf, 1.18)
		RTREE:
			var id2: String = ROAD_TREES[int(seed_v * 977.0) % ROAD_TREES.size()]
			PieceBatch.add(id2, Vector3.ZERO, seed_v * TAU, 7.5 + 3.5 * fmod(seed_v * 13.7, 1.0), v, c, xf, 1.18)
		FLOWERS:
			for k in 5:
				var a := TAU * (float(k) + fmod(seed_v * 5.1, 1.0)) / 5.0
				var rr := 0.25 + 0.55 * fmod(seed_v * 7.3 + float(k) * 0.37, 1.0)
				PieceBatch.add(FLOWER_PIECES[(int(seed_v * 977.0) + k) % FLOWER_PIECES.size()], Vector3(cos(a) * rr, 0, sin(a) * rr), seed_v * 6.0 + float(k), 0.9 + 0.5 * fmod(seed_v * 3.3 + float(k) * 0.2, 1.0), v, c, xf)
			PieceBatch.add("pasto_alto", Vector3(0.1, 0, 0.1), seed_v * 4.0, 0.0, v, c, xf)
		GRASS:
			PieceBatch.add("pasto_alto", Vector3.ZERO, seed_v * TAU, 0.0, v, c, xf)
			PieceBatch.add("pasto_alto", Vector3(0.7, 0, 0.3), seed_v * 5.0, 0.0, v, c, xf)
			PieceBatch.add("pasto", Vector3(-0.5, 0, 0.5), seed_v * 7.0, 0.0, v, c, xf)
		BUSH:
			PieceBatch.add("arbusto" if seed_v < 0.6 else "arbusto_flores", Vector3.ZERO, seed_v * TAU, 1.1 + 0.5 * fmod(seed_v * 9.1, 1.0), v, c, xf)
		BLOCK:
			pass # solo choca (el kiosco de la gasolinera): se dibuja aparte
		PUMP:
			var body := Color(0.92, 0.92, 0.94)
			box(v, c, xf, Vector3(0, 0.45, 0), Vector3(1.1, 0.9, 0.9), Color(0.2, 0.2, 0.24)) # base
			box(v, c, xf, Vector3(0, 1.25, 0), Vector3(0.9, 1.3, 0.7), body)
			box(v, c, xf, Vector3(0, 1.55, 0.38), Vector3(0.6, 0.35, 0.06), Color(0.15, 0.6, 0.85)) # pantalla
			box(v, c, xf, Vector3(0.55, 1.05, 0), Vector3(0.12, 0.7, 0.3), Color(0.12, 0.12, 0.14)) # manguera
			box(v, c, xf, Vector3(0, 2.0, 0), Vector3(1.0, 0.18, 0.8), Color(0.88, 0.2, 0.15))
		LIGHT:
			var dark := Color(0.16, 0.17, 0.19)
			box(v, c, xf, Vector3(0, 2.2, 0), Vector3(0.18, 4.4, 0.18), Color(0.30, 0.32, 0.33))
			box(v, c, xf, Vector3(0, 4.25, 1.3), Vector3(0.12, 0.12, 2.6), Color(0.30, 0.32, 0.33))
			box(v, c, xf, Vector3(0, 3.8, 2.4), Vector3(0.3, 1.0, 0.3), dark)
			var lights := [[4.15, Color(0.92, 0.16, 0.12)], [3.8, Color(0.97, 0.74, 0.12)], [3.45, Color(0.22, 0.82, 0.32)]]
			for l in lights:
				box(v, c, xf, Vector3(0, float(l[0]), 2.4), Vector3(0.42, 0.22, 0.2), l[1])
		MONUMENT:
			var stone := Color(0.80, 0.77, 0.70)
			box(v, c, xf, Vector3(0, 0.3, 0), Vector3(8.0, 0.6, 8.0), stone.darkened(0.12))
			box(v, c, xf, Vector3(0, 0.9, 0), Vector3(5.6, 0.6, 5.6), stone)
			frustum(v, c, xf, Vector3(0, 1.2, 0), 1.5, 0.7, 11.0, 4, stone.lightened(0.05), PI * 0.25)
			frustum(v, c, xf, Vector3(0, 12.2, 0), 0.7, 0.0, 1.6, 4, Color(0.95, 0.78, 0.25), PI * 0.25)
		PILLAR:
			box(v, c, xf, Vector3(0, 2.4, 0), Vector3(1.2, 4.8, 1.2), Color(0.66, 0.66, 0.69))
			box(v, c, xf, Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 1.6), Color(0.52, 0.52, 0.56))
			box(v, c, xf, Vector3(0, 1.4, 0), Vector3(1.24, 0.35, 1.24), Color(0.96, 0.78, 0.15)) # franja amarilla
		PARKED:
			var hue := fmod(seed_v * 5.37, 1.0)
			var body := Color.from_hsv(hue, 0.55, 0.88)
			box(v, c, xf, Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.3), body)
			box(v, c, xf, Vector3(0, 1.1, -0.2), Vector3(1.55, 0.5, 2.3), Color(0.18, 0.24, 0.32))
			box(v, c, xf, Vector3(0, 1.38, -0.2), Vector3(1.5, 0.08, 2.1), body.darkened(0.1))
			for wx in [-0.92, 0.92]:
				for wz in [-1.4, 1.4]:
					box(v, c, xf, Vector3(float(wx), 0.32, float(wz)), Vector3(0.22, 0.64, 0.64), Color(0.10, 0.10, 0.12))
		BOLLARD:
			box(v, c, xf, Vector3(0, 0.4, 0), Vector3(0.18, 0.8, 0.18), Color(0.16, 0.18, 0.22))
			box(v, c, xf, Vector3(0, 0.86, 0), Vector3(0.25, 0.12, 0.25), Color(0.30, 0.33, 0.38))
