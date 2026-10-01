extends RefCounted
## Ruedas, frenos de disco y resortes de los autos nuevos, generados por código (no hay modelos de ruedas en los GLB).
## Eje de la rueda = X, cara de afuera hacia +x (las ruedas de la izquierda se espejan con escala −1).
## Las mallas se calculan una vez por combinación de medidas y se comparten entre las cuatro ruedas y entre autos iguales.
## Convención de Godot: las caras de frente van en sentido horario; MB.tri() orienta cada triángulo con una normal de referencia.

class MB:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var idx := PackedInt32Array()

	func vert(p: Vector3, nn: Vector3) -> int:
		v.append(p)
		n.append(nn.normalized())
		return v.size() - 1

	func tri(i: int, j: int, k: int, hint: Vector3) -> void:
		var g := (v[j] - v[i]).cross(v[k] - v[i])
		if g.dot(hint) > 0.0:
			idx.append(i)
			idx.append(k)
			idx.append(j)
		else:
			idx.append(i)
			idx.append(j)
			idx.append(k)

	## cuadrilátero plano a-b-c-d (en orden alrededor), mirando hacia hint
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length() < 1e-12:
			nn = (c - b).cross(a - b)
		nn = nn.normalized()
		if nn.dot(hint) < 0.0:
			nn = -nn
		var i := vert(a, nn)
		var j := vert(b, nn)
		var k := vert(c, nn)
		var l := vert(d, nn)
		tri(i, j, k, nn)
		tri(i, k, l, nn)

	func polygon(pts: Array, hint: Vector3) -> void:
		var nn := Vector3.ZERO
		var c := Vector3.ZERO
		for p: Vector3 in pts:
			c += p
		c /= float(pts.size())
		for i in pts.size():
			nn += ((pts[i] as Vector3) - c).cross((pts[(i + 1) % pts.size()] as Vector3) - c)
		nn = nn.normalized()
		if nn.dot(hint) < 0.0:
			nn = -nn
		var ci := vert(c, nn)
		var first := v.size()
		for p: Vector3 in pts:
			vert(p, nn)
		for i in pts.size():
			tri(ci, first + i, first + (i + 1) % pts.size(), nn)

	## prisma entre dos cuadriláteros (frente y fondo), caras planas
	func prism(f: Array, b: Array) -> void:
		var c := Vector3.ZERO
		for p: Vector3 in f:
			c += p
		for p: Vector3 in b:
			c += p
		c /= float(f.size() + b.size())
		quad(f[0], f[1], f[2], f[3], (((f[0] as Vector3) + (f[2] as Vector3)) * 0.5) - c)
		for i in 4:
			var j := (i + 1) % 4
			quad(f[i], f[j], b[j], b[i], (((f[i] as Vector3) + (b[j] as Vector3)) * 0.5) - c)
		quad(b[0], b[1], b[2], b[3], (((b[0] as Vector3) + (b[2] as Vector3)) * 0.5) - c)

	func box(center: Vector3, bx: Basis, size: Vector3, skip_bottom := false) -> void:
		var h := size * 0.5
		var c: Array = []
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					c.append(center + bx * Vector3(sx * h.x, sy * h.y, sz * h.z))
		# índices: x,y,z → 4*ix + 2*iy + iz
		var faces := [[0, 1, 3, 2, Vector3(-1, 0, 0)], [4, 6, 7, 5, Vector3(1, 0, 0)], [2, 3, 7, 6, Vector3(0, 1, 0)], [0, 4, 5, 1, Vector3(0, -1, 0)], [1, 5, 7, 3, Vector3(0, 0, 1)], [0, 2, 6, 4, Vector3(0, 0, -1)]]
		for f in faces:
			if skip_bottom and (f[4] as Vector3) == Vector3(0, -1, 0):
				continue
			quad(c[f[0]], c[f[1]], c[f[2]], c[f[3]], bx * (f[4] as Vector3))

	## suma la geometría de otra malla (para juntar superficies y ahorrar llamadas de dibujo)
	func absorb(o: MB) -> void:
		var base := v.size()
		v.append_array(o.v)
		n.append_array(o.n)
		for i in o.idx:
			idx.append(i + base)

	func to_arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_INDEX] = idx
		return a

static var _cache := {}

## Revolución alrededor del eje X. prof: Array de Vector3(r, x, liso) recorrida de modo que la cara de afuera quede a la derecha del
## sentido de avance (normal = (dx, −dr)); liso = 1 une suave con el tramo anterior.
static func lathe(mb: MB, prof: Array, seg: int) -> void:
	var np := prof.size()
	var sn: Array = []
	for i in np - 1:
		var a: Vector3 = prof[i]
		var b: Vector3 = prof[i + 1]
		var dr := b.x - a.x
		var dx := b.y - a.y
		var l := maxf(sqrt(dr * dr + dx * dx), 1e-9)
		sn.append(Vector2(dx / l, -dr / l))
	for i in np - 1:
		var a: Vector3 = prof[i]
		var b: Vector3 = prof[i + 1]
		if absf(a.x - b.x) < 1e-7 and absf(a.y - b.y) < 1e-7:
			continue
		var na: Vector2 = sn[i]
		if a.z > 0.5 and i > 0:
			na = (na + (sn[i - 1] as Vector2)).normalized()
		var nb: Vector2 = sn[i]
		if b.z > 0.5 and i + 1 < np - 1:
			nb = (nb + (sn[i + 1] as Vector2)).normalized()
		var base := mb.v.size()
		for j in seg + 1:
			var ang := TAU * float(j) / float(seg)
			var s := sin(ang)
			var c := cos(ang)
			mb.vert(Vector3(a.y, a.x * s, a.x * c), Vector3(na.y, na.x * s, na.x * c))
			mb.vert(Vector3(b.y, b.x * s, b.x * c), Vector3(nb.y, nb.x * s, nb.x * c))
		for j in seg:
			var i0 := base + 2 * j
			var h1 := mb.n[i0] + mb.n[i0 + 1] + mb.n[i0 + 2] + mb.n[i0 + 3]
			mb.tri(i0, i0 + 1, i0 + 2, h1)
			mb.tri(i0 + 1, i0 + 3, i0 + 2, h1)

static func _surf(mesh: ArrayMesh, mb: MB, name: String, names: Array) -> void:
	if mb.idx.size() == 0:
		return
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.to_arrays())
	names.append(name)

static func _finish(parts: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var names := []
	for p in parts:
		_surf(mesh, p[1], str(p[0]), names)
	mesh.set_meta("names", names)
	return mesh

## punto (x, r en el ángulo ang) del plano de la rueda
static func _pt(x: float, r: float, ang: float) -> Vector3:
	return Vector3(x, r * sin(ang), r * cos(ang))

# ───────────────────────── goma ─────────────────────────
## tread: road | slick | offroad
static func tire_mesh(R: float, rr: float, w: float, tread: String, lo: bool) -> ArrayMesh:
	var key := "tire|%.3f|%.3f|%.3f|%s|%d" % [R, rr, w, tread, int(lo)]
	if _cache.has(key):
		return _cache[key]
	var h := w * 0.5
	var sh := R - rr
	var lug := 0.0 if (tread != "offroad" or lo) else clampf(sh * 0.22, 0.02, 0.045)
	var rt := R - lug
	var prof: Array = [Vector3(rr, -h * 0.58, 0), Vector3(rr + sh * 0.10, -h * 0.80, 1), Vector3(rr + sh * 0.35, -h * 0.97, 1), Vector3(rr + sh * 0.62, -h * 0.99, 1),
		Vector3(rr + sh * 0.84, -h * 0.90, 1), Vector3(rt - sh * 0.06, -h * 0.74, 1), Vector3(rt - sh * 0.015, -h * 0.55, 1), Vector3(rt, -h * 0.38, 1)]
	if tread == "road" and not lo:
		prof.append_array([Vector3(rt, -h * 0.26, 0), Vector3(rt - 0.004, -h * 0.22, 0), Vector3(rt - 0.004, -h * 0.12, 0), Vector3(rt, -h * 0.08, 0),
			Vector3(rt, h * 0.08, 0), Vector3(rt - 0.004, h * 0.12, 0), Vector3(rt - 0.004, h * 0.22, 0), Vector3(rt, h * 0.26, 0)])
	prof.append_array([Vector3(rt, h * 0.38, 0), Vector3(rt - sh * 0.015, h * 0.55, 1), Vector3(rt - sh * 0.06, h * 0.74, 1), Vector3(rr + sh * 0.84, h * 0.90, 1),
		Vector3(rr + sh * 0.62, h * 0.99, 1), Vector3(rr + sh * 0.35, h * 0.97, 1), Vector3(rr + sh * 0.10, h * 0.80, 1), Vector3(rr, h * 0.58, 1)])
	var mb := MB.new()
	lathe(mb, prof, 28 if lo else 56)
	var parts := [["tire", mb]]
	if lug > 0.0:
		var lb := MB.new()
		var n := 30
		for i in n:
			for side: float in [-1.0, 1.0]:
				var a := TAU * (float(i) + (0.5 if side > 0.0 else 0.0)) / float(n)
				var bx := Basis(Vector3.RIGHT, -a)  # y,z del bloque → radial y tangente
				var c := Vector3(side * h * 0.34, 0.0, 0.0)
				var p := bx * Vector3(0.0, rt + lug * 0.5 - 0.002, 0.0)
				lb.box(p + c, bx, Vector3(w * 0.30, lug + 0.004, TAU * R / float(n) * 0.52), true)
			# bloque del hombro, inclinado
			var a2 := TAU * (float(i) + 0.25) / float(n)
			var bx2 := Basis(Vector3.RIGHT, -a2)
			for side2: float in [-1.0, 1.0]:
				var p2 := bx2 * Vector3(0.0, rt - sh * 0.05, 0.0) + Vector3(side2 * h * 0.76, 0.0, 0.0)
				lb.box(p2, bx2 * Basis(Vector3.UP, side2 * 0.5), Vector3(w * 0.16, lug * 0.9, TAU * R / float(n) * 0.40), true)
		parts.append(["tire", lb])
	var mesh := _finish(parts)
	_cache[key] = mesh
	return mesh

# ───────────────────────── llanta ─────────────────────────
## Devuelve una malla con superficies "rim" (color de la llanta), "dark" (fondo, agujeros) y "steel" (tuercas y tapas).
static func rim_mesh(style: String, rr: float, wr: float, lo: bool) -> ArrayMesh:
	var key := "rim|%s|%.3f|%.3f|%d" % [style, rr, wr, int(lo)]
	if _cache.has(key):
		return _cache[key]
	var rim := MB.new()
	var dark := MB.new()
	var steel := MB.new()
	var seg := 28 if lo else 48
	var xl := wr * 0.5 # borde de afuera
	var rb := rr - 0.012 # radio interior del barril
	var dish := clampf(wr * 0.26, 0.03, 0.075)
	# labio y barril
	lathe(rim, [Vector3(rr + 0.016, xl - 0.012, 0), Vector3(rr + 0.016, xl, 1), Vector3(rr + 0.002, xl + 0.003, 1), Vector3(rb + 0.004, xl - 0.006, 1)], seg)
	lathe(dark, [Vector3(rb + 0.004, xl - 0.006, 0), Vector3(rb, xl - 0.02, 0), Vector3(rb, -xl + 0.02, 0), Vector3(rb - 0.02, -xl + 0.04, 0)], seg)
	var xf := xl - dish # plano de la cara en el centro
	var r0 := rr * 0.22
	match style:
		"multi5":
			_spokes(rim, 5, rr * 0.40, rr * 0.22, r0, rb, xl - 0.012, xf, 0.016, 0.0)
			_hub(rim, steel, r0 * 1.05, xf, 5, rr * 0.14, rr * 0.075, lo)
		"star5":
			_spokes(rim, 5, rr * 0.34, rr * 0.52, r0, rb, xl - 0.012, xf, 0.018, 0.0)
			_hub(rim, steel, r0 * 1.1, xf, 5, rr * 0.16, rr * 0.07, lo)
		"multi10":
			_spokes(rim, 10, rr * 0.17, rr * 0.11, r0, rb, xl - 0.012, xf, 0.014, 0.0)
			_hub(rim, steel, r0 * 1.0, xf, 5, rr * 0.13, rr * 0.06, lo)
		"turbine":
			_plate(rim, rb * 0.99, r0, xl - 0.018, xf, seg)
			_vanes(rim, 18, r0 * 1.2, rb * 0.97, xl - 0.012, xf, 0.012, 0.55)
			_hub(rim, steel, r0 * 1.0, xf, 0, 0.0, 0.0, lo)
			steel_nut(steel, xf, r0 * 0.7, 0.012)
		"centerlock":
			_plate(rim, rb * 0.99, r0, xl - 0.014, xf, seg)
			for i in 12:
				_slot(dark, TAU * float(i) / 12.0, rb * 0.62, rb * 0.93, rr * 0.07, xl - 0.0125)
			_hub(rim, steel, r0 * 1.2, xf, 0, 0.0, 0.0, lo)
			steel_nut(steel, xf, r0 * 0.9, 0.022)
		"dish6":
			_plate(rim, rb * 0.99, r0, xl - 0.014, xf, seg)
			_holes(dark, 6, rb * 0.58, rr * 0.17, xl - 0.0125, xf, rb, 10)
			_hub(rim, steel, r0 * 1.3, xf, 6, rr * 0.18, rr * 0.06, lo)
		"dish8":
			_plate(rim, rb * 0.99, r0, xl - 0.014, xf, seg)
			_holes(dark, 8, rb * 0.62, rr * 0.12, xl - 0.0125, xf, rb, 10)
			_hub(rim, steel, r0 * 1.3, xf, 8, rr * 0.20, rr * 0.055, lo)
		"steel10":
			_plate(rim, rb * 0.99, r0, xl - 0.014, xf, seg)
			_holes(dark, 10, rb * 0.68, rr * 0.13, xl - 0.0125, xf, rb, 10)
			_hub(rim, steel, r0 * 1.7, xf, 10, rr * 0.28, rr * 0.05, lo)
		"beadlock":
			_plate(rim, rb * 0.99, r0, xl - 0.014, xf, seg)
			_holes(dark, 6, rb * 0.55, rr * 0.22, xl - 0.0125, xf, rb, 10)
			_hub(rim, steel, r0 * 1.2, xf, 6, rr * 0.2, rr * 0.06, lo)
			for i in (0 if lo else 18):
				var a := TAU * float(i) / 18.0
				_bolt(steel, a, rr * 0.985, xl + 0.003, 0.0075)
		_:
			_spokes(rim, 5, rr * 0.4, rr * 0.22, r0, rb, xl - 0.012, xf, 0.016, 0.0)
	if lo: # de lejos no se distinguen las tuercas: una superficie menos
		dark.absorb(steel)
		steel = MB.new()
	var mesh := _finish([["rim", rim], ["dark", dark], ["steel", steel]])
	_cache[key] = mesh
	return mesh

## radios: de r0 a r1; ancho w0 en el cubo y w1 en el borde; el centro está en el plano xf y el borde en xe (llanta cóncava)
static func _spokes(mb: MB, n: int, w0: float, w1: float, r0: float, r1: float, xe: float, xf: float, th: float, twist: float) -> void:
	for i in n:
		var a := TAU * float(i) / float(n)
		var er := Vector3(0, sin(a), cos(a))
		var et := Vector3(0, cos(a), -sin(a))
		var steps := 3
		var prev_f: Array = []
		var prev_b: Array = []
		for s in steps + 1:
			var u := float(s) / float(steps)
			var r := lerpf(r0, r1, u)
			var x := lerpf(xf, xe, u * u)
			var w := lerpf(w0, w1, u) * 0.5
			var f: Array = [er * r + et * w + Vector3(x, 0, 0), er * r - et * w + Vector3(x, 0, 0)]
			var b: Array = [er * r + et * w + Vector3(x - th, 0, 0), er * r - et * w + Vector3(x - th, 0, 0)]
			if s > 0:
				mb.quad(prev_f[0], f[0], f[1], prev_f[1], Vector3.RIGHT)
				mb.quad(prev_f[0], prev_b[0], b[0], f[0], et)
				mb.quad(prev_f[1], f[1], b[1], prev_b[1], -et)
			prev_f = f
			prev_b = b
		# punta del borde
		mb.quad(prev_f[0], prev_f[1], prev_b[1], prev_b[0], er)

## paletas de turbina: cada una es una cinta curva (sweep = cuánto se desplaza en ángulo hacia afuera)
static func _vanes(mb: MB, n: int, r0: float, r1: float, xe: float, xf: float, th: float, sweep: float) -> void:
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var steps := 4
		var pf: Array = []
		var pb: Array = []
		for s in steps + 1:
			var u := float(s) / float(steps)
			var r := lerpf(r0, r1, u)
			var x := lerpf(xf, xe, u * u) + 0.012
			var a := a0 + sweep * u
			var wdt := lerpf(0.016, 0.028, u)
			var er := Vector3(0, sin(a), cos(a))
			var et := Vector3(0, cos(a), -sin(a))
			var f: Array = [er * r + et * wdt + Vector3(x, 0, 0), er * r - et * wdt + Vector3(x, 0, 0)]
			var b: Array = [er * r + et * wdt + Vector3(x - th, 0, 0), er * r - et * wdt + Vector3(x - th, 0, 0)]
			if s > 0:
				mb.quad(pf[0], f[0], f[1], pf[1], Vector3.RIGHT)
				mb.quad(pf[0], pb[0], b[0], f[0], et)
				mb.quad(pf[1], f[1], b[1], pb[1], -et)
			pf = f
			pb = b

## cara de disco cóncava (tapa llena) entre r0 y r1
static func _plate(mb: MB, r1: float, r0: float, xe: float, xf: float, seg: int) -> void:
	lathe(mb, [Vector3(r1, xe, 0), Vector3(r1 * 0.9, xe - (xe - xf) * 0.18, 1), Vector3(r1 * 0.62, xe - (xe - xf) * 0.55, 1), Vector3(r0 * 1.6, xf + 0.004, 1), Vector3(r0, xf, 1), Vector3(0.0, xf, 0)], seg)

## agujeros (polígonos oscuros apenas por encima de la cara): n círculos a distancia rho del centro
static func _holes(mb: MB, n: int, rho: float, size: float, xe: float, xf: float, r1: float, sides: int) -> void:
	for i in n:
		var a := TAU * float(i) / float(n)
		var er := Vector3(0, sin(a), cos(a))
		var et := Vector3(0, cos(a), -sin(a))
		var x := lerpf(xf, xe, clampf((rho - 0.02) / r1, 0.0, 1.0) * 0.55) + 0.004
		var pts: Array = []
		for k in sides:
			var b := TAU * float(k) / float(sides)
			pts.append(er * (rho + cos(b) * size * 1.15) + et * (sin(b) * size * 0.8) + Vector3(x, 0, 0))
		mb.polygon(pts, Vector3.RIGHT)

## ranura radial (rectángulo) de ancho w entre los radios ra y rb
static func _slot(mb: MB, a: float, ra: float, rb: float, w: float, x: float) -> void:
	var er := Vector3(0, sin(a), cos(a))
	var et := Vector3(0, cos(a), -sin(a))
	var xx := Vector3(x - 0.004, 0, 0)
	mb.quad(er * ra - et * w + xx, er * ra + et * w + xx, er * rb + et * w + xx, er * rb - et * w + xx, Vector3.RIGHT)

## cubo: tapa central y tuercas
static func _hub(rim: MB, steel: MB, r: float, xf: float, nuts: int, ring_r: float, nut_r: float, lo: bool) -> void:
	lathe(rim, [Vector3(r, xf - 0.004, 0), Vector3(r, xf + 0.012, 1), Vector3(r * 0.9, xf + 0.020, 1), Vector3(r * 0.5, xf + 0.026, 1), Vector3(0.0, xf + 0.028, 1)], 14 if lo else 24)
	if lo:
		return
	for i in nuts:
		var a := TAU * float(i) / float(nuts)
		var p := _pt(xf + 0.026, ring_r, a)
		lathe_at(steel, p, nut_r, 0.012)

static func steel_nut(steel: MB, xf: float, r: float, h: float) -> void:
	lathe_at(steel, Vector3(xf + 0.03, 0, 0), r, h, 6)

## cilindrito sobre el eje X con centro en p
static func lathe_at(mb: MB, p: Vector3, r: float, h: float, seg := 6) -> void:
	var tmp := MB.new()
	lathe(tmp, [Vector3(0, 0, 0), Vector3(r, 0, 0), Vector3(r, h, 0), Vector3(r * 0.8, h * 1.1, 0), Vector3(0, h * 1.1, 0)], seg)
	var o := mb.v.size()
	for i in tmp.v.size():
		mb.v.append(tmp.v[i] + p)
		mb.n.append(tmp.n[i])
	for k in tmp.idx:
		mb.idx.append(k + o)

static func _bolt(mb: MB, a: float, r: float, x: float, br: float) -> void:
	lathe_at(mb, _pt(x, r, a), br, 0.008, 6)

# ───────────────────────── freno de disco ─────────────────────────
## Disco ventilado: superficies "disc" y "dark" (ranuras). Posición x = 0 en el centro del disco.
static func disc_mesh(r_out: float, r_in: float, t: float) -> ArrayMesh:
	var key := "disc|%.3f|%.3f|%.3f" % [r_out, r_in, t]
	if _cache.has(key):
		return _cache[key]
	var d := MB.new()
	var s := MB.new()
	lathe(d, [Vector3(r_in, -t * 0.5, 0), Vector3(r_out, -t * 0.5, 0), Vector3(r_out, t * 0.5, 0), Vector3(r_in, t * 0.5, 0)], 40)
	# cubo del disco (campana): cilindro hacia afuera
	lathe(d, [Vector3(r_in, t * 0.5, 0), Vector3(r_in, t * 0.5 + 0.045, 0), Vector3(r_in * 0.55, t * 0.5 + 0.045, 0)], 24)
	for i in 28:
		var a := TAU * float(i) / 28.0
		var er := Vector3(0, sin(a), cos(a))
		var et := Vector3(0, cos(a), -sin(a))
		var xx := Vector3(t * 0.5 + 0.0008, 0, 0)
		s.quad(er * (r_in + (r_out - r_in) * 0.30) - et * 0.0045 + xx, er * (r_in + (r_out - r_in) * 0.30) + et * 0.0045 + xx, er * (r_out - 0.012) + et * 0.0045 + xx, er * (r_out - 0.012) - et * 0.0045 + xx, Vector3.RIGHT)
	var mesh := _finish([["disc", d], ["dark", s]])
	_cache[key] = mesh
	return mesh

## Pinza de freno: barrido de una sección rectangular que abraza el disco, entre los ángulos a0..a1 (0 = arriba)
static func caliper_mesh(r_out: float, r_in: float, t: float, a0: float, a1: float) -> ArrayMesh:
	var key := "cal|%.3f|%.3f|%.3f|%.2f|%.2f" % [r_out, r_in, t, a0, a1]
	if _cache.has(key):
		return _cache[key]
	var mb := MB.new()
	var x0 := -t * 0.5 - 0.018
	var x1 := t * 0.5 + 0.018
	var ri := r_in
	var ro := r_out + 0.022
	var steps := 7
	var prev: Array = []
	for s in steps + 1:
		var a := lerpf(a0, a1, float(s) / float(steps))
		var cur: Array = [_pt(x0, ri, a), _pt(x0, ro, a), _pt(x1, ro, a), _pt(x1, ri, a)]
		if s == 0:
			mb.quad(cur[0], cur[1], cur[2], cur[3], _pt(0, (ri + ro) * 0.5, a0) - _pt(0, (ri + ro) * 0.5, a0 + 0.3))
		else:
			var cen := _pt((x0 + x1) * 0.5, (ri + ro) * 0.5, a)
			for k in 4:
				var j := (k + 1) % 4
				var fc := ((cur[k] as Vector3) + (cur[j] as Vector3) + (prev[k] as Vector3) + (prev[j] as Vector3)) * 0.25
				mb.quad(prev[k], prev[j], cur[j], cur[k], fc - cen)
		prev = cur
	mb.quad(prev[0], prev[1], prev[2], prev[3], _pt(0, (ri + ro) * 0.5, a1) - _pt(0, (ri + ro) * 0.5, a1 - 0.3))
	var mesh := _finish([["caliper", mb]])
	_cache[key] = mesh
	return mesh

# ───────────────────────── resorte y amortiguador ─────────────────────────
## Resorte helicoidal de altura 1 a lo largo de +Y (origen abajo); se estira con la escala Y.
static func spring_mesh(r: float, wire: float, coils: float, lo: bool) -> ArrayMesh:
	var key := "spr|%.3f|%.4f|%.1f|%d" % [r, wire, coils, int(lo)]
	if _cache.has(key):
		return _cache[key]
	var mb := MB.new()
	var per := 9
	var steps := int(coils * float(per))
	var sides := 5
	var rings: Array = []
	for i in steps + 1:
		var u := float(i) / float(steps)
		var ph := TAU * coils * u
		var c := Vector3(r * cos(ph), 0.05 + 0.9 * u, r * sin(ph))
		var tg := Vector3(-r * sin(ph) * TAU * coils, 0.9, r * cos(ph) * TAU * coils).normalized()
		var nn := Vector3(cos(ph), 0, sin(ph))
		var bn := tg.cross(nn).normalized()
		var ring: Array = []
		for k in sides:
			var b := TAU * float(k) / float(sides)
			var dir := nn * cos(b) + bn * sin(b)
			ring.append([c + dir * wire, dir])
		rings.append(ring)
	for i in steps:
		var base := mb.v.size()
		var ra: Array = rings[i]
		var rb: Array = rings[i + 1]
		for k in sides:
			mb.vert(ra[k][0], ra[k][1])
		for k in sides:
			mb.vert(rb[k][0], rb[k][1])
		for k in sides:
			var k2 := (k + 1) % sides
			var hint: Vector3 = (ra[k][1] as Vector3) + (ra[k2][1] as Vector3)
			mb.tri(base + k, base + k2, base + sides + k, hint)
			mb.tri(base + k2, base + sides + k2, base + sides + k, hint)
	var mesh := _finish([["spring", mb]])
	_cache[key] = mesh
	return mesh

## Cilindro de altura 1 sobre +Y con el origen abajo (para el amortiguador y la varilla)
static func _tube_mb(r: float, y0: float, y1: float, seg: int) -> MB:
	var mb := MB.new()
	# lathe sobre el eje X: se hace sobre X y se gira a Y
	var m2 := MB.new()
	lathe(m2, [Vector3(0, y0, 0), Vector3(r, y0, 0), Vector3(r, y1, 0), Vector3(0, y1, 0)], seg)
	for i in m2.v.size():
		var p := m2.v[i]
		var q := m2.n[i]
		mb.v.append(Vector3(p.y, p.x, p.z))
		mb.n.append(Vector3(q.y, q.x, q.z))
	for k in range(0, m2.idx.size(), 3): # el cambio de ejes invierte el giro de las caras
		mb.idx.append(m2.idx[k])
		mb.idx.append(m2.idx[k + 2])
		mb.idx.append(m2.idx[k + 1])
	return mb

static func tube_mesh(r: float, y0: float, y1: float, seg := 8) -> ArrayMesh:
	var key := "tube|%.4f|%.3f|%.3f|%d" % [r, y0, y1, seg]
	if _cache.has(key):
		return _cache[key]
	var mesh := _finish([["tube", _tube_mb(r, y0, y1, seg)]])
	_cache[key] = mesh
	return mesh

## Amortiguador: cuerpo y vástago en una sola superficie (una llamada de dibujo en vez de dos)
static func damper_mesh(rs: float) -> ArrayMesh:
	var key := "damper|%.4f" % rs
	if _cache.has(key):
		return _cache[key]
	var mb := _tube_mb(rs * 0.46, 0.04, 0.56, 8)
	mb.absorb(_tube_mb(rs * 0.20, 0.5, 0.97, 6))
	var mesh := _finish([["tube", mb]])
	_cache[key] = mesh
	return mesh
