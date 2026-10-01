extends RefCounted
## Objetos del modo aventura armados con código: árboles (pinos con copa en capas desparejas, árboles de hojas con varias
## copas, álamos, pinos nevados), casas y edificios con fachada de una textura atlas, estación de servicio, taller mecánico,
## carteles, molino, silo, vacas, autos estacionados, faroles, flechas de curva…
## Todo va a mallas de un solo material por tipo (vértices con color): pocos objetos para dibujar.

const MB := preload("res://game/adventure/adv_mesh.gd")

# ───────────────────────── atlas de fachadas (512 px, 4×4 baldosas de 128 px) ─────────────────────────
## Baldosas: (columna, fila)
const T_WIN := Vector2i(0, 0) # ventana con postigos
const T_BALC := Vector2i(1, 0) # ventana con balcón
const T_DOOR := Vector2i(2, 0) # puerta con ventanita
const T_SHOP := Vector2i(3, 0) # vidriera con toldo
const T_OFFICE := Vector2i(0, 1) # oficinas (vidrio)
const T_BRICK := Vector2i(1, 1) # ladrillo con ventana
const T_GARAGE := Vector2i(2, 1) # portón
const T_WALL := Vector2i(3, 1) # pared lisa
const T_TILES := Vector2i(0, 2) # tejas
const T_GRAVEL := Vector2i(1, 2) # techo plano
const T_TIN := Vector2i(2, 2) # chapa acanalada
const T_CONC := Vector2i(3, 2) # hormigón
const T_CHEVRON := Vector2i(0, 3) # flecha de curva (amarilla y negra)
const T_PLANK := Vector2i(1, 3) # tablas de madera
const T_ROCK := Vector2i(2, 3) # roca
const T_TOOLS := Vector2i(3, 3) # tablero de herramientas del taller

static var _atlas: ImageTexture

static func tile_rect(t: Vector2i) -> Rect2:
	var m := 1.0 / 512.0
	return Rect2(Vector2(float(t.x) * 0.25 + m, float(t.y) * 0.25 + m), Vector2(0.25 - 2.0 * m, 0.25 - 2.0 * m))

static func atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var img := Image.create(512, 512, false, Image.FORMAT_RGB8)
	img.fill(Color(0.92, 0.92, 0.9))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var glass := Color(0.16, 0.22, 0.30)
	var glass2 := Color(0.26, 0.34, 0.44)
	var frame := Color(0.97, 0.97, 0.95)
	var dark := Color(0.18, 0.16, 0.15)
	# ruido de revoque en toda la imagen (después se tiñe con el color de cada casa)
	for k in 9000:
		var px := rng.randi() % 512
		var py := rng.randi() % 512
		var g := 0.84 + rng.randf() * 0.12
		img.set_pixel(px, py, Color(g, g, g * 0.98))
	var o := func(t: Vector2i) -> Vector2i: return Vector2i(t.x * 128, t.y * 128)
	# ventana con postigos verdes
	var p: Vector2i = o.call(T_WIN)
	img.fill_rect(Rect2i(p.x + 34, p.y + 30, 60, 70), frame)
	img.fill_rect(Rect2i(p.x + 40, p.y + 36, 48, 58), glass)
	img.fill_rect(Rect2i(p.x + 63, p.y + 36, 2, 58), frame)
	img.fill_rect(Rect2i(p.x + 14, p.y + 30, 20, 70), Color(0.22, 0.42, 0.30))
	img.fill_rect(Rect2i(p.x + 94, p.y + 30, 20, 70), Color(0.22, 0.42, 0.30))
	for yy in range(32, 100, 6):
		img.fill_rect(Rect2i(p.x + 14, p.y + yy, 20, 1), Color(0.15, 0.3, 0.22))
		img.fill_rect(Rect2i(p.x + 94, p.y + yy, 20, 1), Color(0.15, 0.3, 0.22))
	img.fill_rect(Rect2i(p.x + 30, p.y + 100, 68, 6), Color(0.8, 0.8, 0.78))
	# ventana con balcón
	p = o.call(T_BALC)
	img.fill_rect(Rect2i(p.x + 30, p.y + 18, 68, 92), frame)
	img.fill_rect(Rect2i(p.x + 36, p.y + 24, 56, 86), glass2)
	img.fill_rect(Rect2i(p.x + 63, p.y + 24, 2, 86), frame)
	img.fill_rect(Rect2i(p.x + 18, p.y + 84, 92, 4), dark)
	img.fill_rect(Rect2i(p.x + 18, p.y + 108, 92, 6), Color(0.6, 0.6, 0.58))
	for xx in range(20, 110, 7):
		img.fill_rect(Rect2i(p.x + xx, p.y + 86, 2, 22), dark)
	# puerta
	p = o.call(T_DOOR)
	img.fill_rect(Rect2i(p.x + 38, p.y + 34, 52, 94), frame)
	img.fill_rect(Rect2i(p.x + 43, p.y + 39, 42, 89), Color(0.42, 0.26, 0.15))
	img.fill_rect(Rect2i(p.x + 50, p.y + 46, 28, 30), glass)
	img.fill_rect(Rect2i(p.x + 78, p.y + 86, 4, 4), Color(0.85, 0.7, 0.3))
	# vidriera con toldo a rayas
	p = o.call(T_SHOP)
	img.fill_rect(Rect2i(p.x + 6, p.y + 40, 116, 88), Color(0.25, 0.25, 0.27))
	img.fill_rect(Rect2i(p.x + 10, p.y + 44, 108, 84), Color(0.32, 0.40, 0.48))
	img.fill_rect(Rect2i(p.x + 60, p.y + 44, 3, 84), Color(0.25, 0.25, 0.27))
	for i in 8:
		img.fill_rect(Rect2i(p.x + i * 16, p.y + 14, 16, 22), Color(0.85, 0.2, 0.18) if i % 2 == 0 else Color(0.97, 0.97, 0.95))
	img.fill_rect(Rect2i(p.x, p.y + 36, 128, 3), Color(0.5, 0.12, 0.1))
	# oficinas: grilla de vidrio
	p = o.call(T_OFFICE)
	img.fill_rect(Rect2i(p.x, p.y, 128, 128), Color(0.55, 0.58, 0.6))
	for gy in 2:
		for gx in 3:
			img.fill_rect(Rect2i(p.x + 4 + gx * 41, p.y + 6 + gy * 62, 38, 52), glass2 if (gx + gy) % 2 == 0 else glass)
	# ladrillo con ventana
	p = o.call(T_BRICK)
	for by in 16:
		for bx in 8:
			var sh := 0.85 + rng.randf() * 0.2
			img.fill_rect(Rect2i(p.x + bx * 16 + (8 if by % 2 == 1 else 0), p.y + by * 8, 15, 7), Color(0.62 * sh, 0.32 * sh, 0.22 * sh))
	img.fill_rect(Rect2i(p.x + 36, p.y + 32, 56, 60), frame)
	img.fill_rect(Rect2i(p.x + 41, p.y + 37, 46, 50), glass)
	# portón de chapa
	p = o.call(T_GARAGE)
	img.fill_rect(Rect2i(p.x + 10, p.y + 26, 108, 102), Color(0.55, 0.57, 0.6))
	for yy in range(28, 128, 8):
		img.fill_rect(Rect2i(p.x + 10, p.y + yy, 108, 2), Color(0.4, 0.42, 0.45))
	# tejas
	p = o.call(T_TILES)
	for ty in 16:
		for tx in 8:
			var sh := 0.85 + rng.randf() * 0.25
			img.fill_rect(Rect2i(p.x + tx * 16 + (8 if ty % 2 == 1 else 0) - 8, p.y + ty * 8, 15, 7), Color(0.66 * sh, 0.28 * sh, 0.18 * sh))
			img.fill_rect(Rect2i(p.x + tx * 16 + (8 if ty % 2 == 1 else 0) - 8, p.y + ty * 8 + 6, 15, 1), Color(0.35, 0.14, 0.1))
	# techo plano (membrana gris con pedregullo)
	p = o.call(T_GRAVEL)
	img.fill_rect(Rect2i(p.x, p.y, 128, 128), Color(0.5, 0.5, 0.5))
	for k in 700:
		var g := 0.4 + rng.randf() * 0.25
		img.set_pixel(p.x + rng.randi() % 128, p.y + rng.randi() % 128, Color(g, g, g))
	# chapa acanalada
	p = o.call(T_TIN)
	for xx in 128:
		var g := 0.62 + 0.12 * sin(float(xx) * 0.75)
		img.fill_rect(Rect2i(p.x + xx, p.y, 1, 128), Color(g, g * 1.01, g * 1.03))
	# hormigón
	p = o.call(T_CONC)
	img.fill_rect(Rect2i(p.x, p.y, 128, 128), Color(0.66, 0.66, 0.64))
	for k in 1500:
		var g := 0.58 + rng.randf() * 0.15
		img.set_pixel(p.x + rng.randi() % 128, p.y + rng.randi() % 128, Color(g, g, g * 0.98))
	img.fill_rect(Rect2i(p.x, p.y + 63, 128, 1), Color(0.5, 0.5, 0.48))
	# flecha de curva: fondo amarillo con flecha negra hacia la derecha (se espeja para la izquierda)
	p = o.call(T_CHEVRON)
	img.fill_rect(Rect2i(p.x, p.y, 128, 128), Color(0.98, 0.78, 0.08))
	for yy in 128:
		var d := absi(yy - 64)
		var x0 := 30 + d
		img.fill_rect(Rect2i(p.x + clampi(x0, 0, 127), p.y + yy, 26, 1), Color(0.05, 0.05, 0.05))
		img.fill_rect(Rect2i(p.x + clampi(x0 + 40, 0, 127), p.y + yy, mini(26, 128 - clampi(x0 + 40, 0, 127)), 1), Color(0.05, 0.05, 0.05))
	# tablas de madera
	p = o.call(T_PLANK)
	for yy in range(0, 128, 16):
		var sh := 0.85 + rng.randf() * 0.2
		img.fill_rect(Rect2i(p.x, p.y + yy, 128, 15), Color(0.52 * sh, 0.36 * sh, 0.22 * sh))
		img.fill_rect(Rect2i(p.x, p.y + yy + 15, 128, 1), Color(0.25, 0.16, 0.1))
	# roca
	p = o.call(T_ROCK)
	for yy in 128:
		for xx in 128:
			var fx := float(xx) / 128.0 * TAU
			var fy := float(yy) / 128.0 * TAU
			var g := 0.5 + 0.12 * sin(fx * 3.0 + sin(fy * 2.0) * 2.0) + 0.08 * sin(fy * 7.0 + fx * 2.0) + rng.randf() * 0.06
			img.set_pixel(p.x + xx, p.y + yy, Color(g, g * 0.97, g * 0.93))
	# tablero de herramientas
	p = o.call(T_TOOLS)
	img.fill_rect(Rect2i(p.x, p.y, 128, 128), Color(0.32, 0.36, 0.4))
	for k in 22:
		var tx := 6 + rng.randi() % 110
		var ty := 6 + rng.randi() % 110
		var tc: Color = [Color(0.85, 0.15, 0.1), Color(0.8, 0.8, 0.82), Color(0.2, 0.2, 0.22), Color(0.95, 0.7, 0.1)][rng.randi() % 4]
		if rng.randf() < 0.5:
			img.fill_rect(Rect2i(p.x + tx, p.y + ty, 3, 14 + rng.randi() % 10), tc)
		else:
			img.fill_rect(Rect2i(p.x + tx, p.y + ty, 10 + rng.randi() % 8, 3), tc)
	img.generate_mipmaps()
	_atlas = ImageTexture.create_from_image(img)
	return _atlas

# ───────────────────────── árboles ─────────────────────────
## Pino: tronco y copa de 6 "polleras" desparejas (estrella de puntas caídas), más oscuras abajo y con puntas claras.
## snowy: con nieve arriba de cada pollera
static func pine(seed_v: int, snowy := false, lo := false) -> RefCounted:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h := rng.randf_range(7.5, 10.0)
	b.cyl(Transform3D.IDENTITY, 0.24, 0.07, h * 0.75, 6 if not lo else 4, Color(0.36, 0.25, 0.17), false)
	var layers := 6 if not lo else 3
	var base_r := rng.randf_range(2.1, 2.7)
	var green := Color(0.10 + rng.randf() * 0.04, 0.27 + rng.randf() * 0.06, 0.13 + rng.randf() * 0.03)
	for L in layers:
		var u := float(L) / float(layers)
		var y_top := lerpf(h * 0.30, h * 0.98, u) + (0.6 if L == layers - 1 else 0.0)
		var r := base_r * (1.0 - u * 0.82) * rng.randf_range(0.9, 1.1)
		var drop := r * rng.randf_range(0.75, 0.95)
		var pts := 10 if not lo else 6
		var ring: Array = []
		var a0 := rng.randf() * TAU
		for k in pts:
			var a := a0 + TAU * float(k) / float(pts)
			var rr := r * (1.0 if k % 2 == 0 else 0.62) * rng.randf_range(0.85, 1.15)
			var dy := drop * (1.0 if k % 2 == 0 else 0.7) * rng.randf_range(0.85, 1.1)
			ring.append(Vector3(cos(a) * rr, y_top - dy, sin(a) * rr))
		var top := Vector3(rng.randf_range(-0.08, 0.08), y_top, rng.randf_range(-0.08, 0.08))
		var under := Vector3(0, y_top - drop * 0.55, 0)
		for k in pts:
			var p0: Vector3 = ring[k]
			var p1: Vector3 = ring[(k + 1) % pts]
			var tip := k % 2 == 0
			var c_top := green.lightened(0.10 if tip else 0.0)
			if snowy:
				c_top = Color(0.86, 0.9, 0.95) if rng.randf() < 0.8 else green.lightened(0.15)
			b.tri(top, p1, p0, c_top)
			b.tri(under, p0, p1, green.darkened(0.45))
	return b

## Árbol de hojas (eucalipto, sauce, paraíso…): tronco con dos ramas y 4-6 copas abolladas
static func broadleaf(seed_v: int, lo := false, autumn := false) -> RefCounted:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h := rng.randf_range(5.5, 8.5)
	var bark := Color(0.40, 0.32, 0.24)
	b.cyl(Transform3D.IDENTITY, 0.26, 0.16, h * 0.55, 6 if not lo else 4, bark, false)
	var leaf := Color(0.20 + rng.randf() * 0.08, 0.38 + rng.randf() * 0.1, 0.14 + rng.randf() * 0.05)
	if autumn:
		leaf = Color(0.62, 0.42, 0.14)
	if lo:
		b.blob(Vector3(0, h * 0.72, 0), Vector3(2.6, 2.2, 2.6), leaf, rng, 0.18, 0.35, 1)
		return b
	for k in 2:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a) * 0.55, 1.0, sin(a) * 0.55).normalized()
		var bb := Basis()
		bb = Basis(dir.cross(Vector3.FORWARD).normalized(), dir, dir.cross(Vector3.FORWARD).normalized().cross(dir)).orthonormalized()
		b.cyl(Transform3D(bb, Vector3(0, h * 0.42, 0)), 0.12, 0.05, h * 0.45, 5, bark, false)
	var nb := rng.randi_range(4, 6)
	for k in nb:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.6, 1.6) if k > 0 else 0.0
		var c := Vector3(cos(a) * rr, h * rng.randf_range(0.62, 0.86) + (0.6 if k == 0 else 0.0), sin(a) * rr)
		var s := rng.randf_range(1.5, 2.2)
		b.blob(c, Vector3(s, s * 0.82, s), leaf.lightened(rng.randf_range(-0.06, 0.1)), rng, 0.22, 0.4, 1)
	return b

## Álamo: alto y angosto (las cortinas de álamos de las chacras)
static func poplar(seed_v: int, lo := false) -> RefCounted:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h := rng.randf_range(11.0, 15.0)
	b.cyl(Transform3D.IDENTITY, 0.22, 0.08, h * 0.5, 5 if not lo else 4, Color(0.48, 0.44, 0.38), false)
	var leaf := Color(0.24 + rng.randf() * 0.06, 0.42 + rng.randf() * 0.08, 0.17)
	var n := 3 if not lo else 1
	for k in n:
		var u := float(k) / float(maxi(1, n - 1)) if n > 1 else 0.5
		var c := Vector3(0, lerpf(h * 0.38, h * 0.82, u), 0)
		var r := lerpf(1.7, 1.0, u)
		b.blob(c, Vector3(r, h * (0.22 if n > 1 else 0.42), r), leaf, rng, 0.15, 0.35, 1)
	return b

## Arbusto bajo
static func bush(seed_v: int) -> RefCounted:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var leaf := Color(0.22, 0.36, 0.15)
	for k in 3:
		var c := Vector3(rng.randf_range(-0.6, 0.6), 0.5, rng.randf_range(-0.6, 0.6))
		b.blob(c, Vector3(0.9, 0.6, 0.9), leaf.lightened(rng.randf() * 0.1), rng, 0.25, 0.4, 1)
	return b

## Roca
static func rock(seed_v: int, col := Color(0.5, 0.48, 0.45)) -> RefCounted:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	b.blob(Vector3(0, 0.3, 0), Vector3(1.2, 0.8, 1.0), col, rng, 0.3, 0.3, 1)
	return b

# ───────────────────────── edificios ─────────────────────────
## Casa o edificio: xf = posición del centro del frente a nivel del piso (z local hacia la calle), w ancho, d fondo,
## floors pisos (3 m), style 0 casa · 1 local con vidriera · 2 edificio de departamentos · 3 oficinas, wall color,
## roof 0 plano · 1 a dos aguas (tejas). Las fachadas se arman por módulos de 3 m con baldosas del atlas.
static func building(b: RefCounted, xf: Transform3D, w: float, d: float, floors: int, style: int, wall: Color, roof: int, rng: RandomNumberGenerator) -> void:
	var fh := 3.0
	var H := float(floors) * fh + 0.4
	var bays := maxi(1, int(round(w / 3.0)))
	var bw := w / float(bays)
	# frente (z = 0 mirando a +z), costados y fondo
	for fl in floors:
		for k in bays:
			var x0 := -w * 0.5 + float(k) * bw
			var y0 := float(fl) * fh
			var t := T_WIN
			if fl == 0:
				if style == 1:
					t = T_SHOP
				elif style == 3:
					t = T_OFFICE
				elif k == bays / 2:
					t = T_DOOR
				elif rng.randf() < 0.18:
					t = T_GARAGE
				else:
					t = T_WIN if rng.randf() < 0.7 else T_BRICK
			else:
				if style == 3:
					t = T_OFFICE
				elif style == 2:
					t = T_BALC if rng.randf() < 0.6 else T_WIN
				else:
					t = T_WIN if rng.randf() < 0.75 else T_BALC
			var r := tile_rect(t)
			b.quad(xf * Vector3(x0, y0, 0), xf * Vector3(x0 + bw, y0, 0), xf * Vector3(x0 + bw, y0 + fh, 0), xf * Vector3(x0, y0 + fh, 0), wall,
				Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y))
	# franja de arriba del frente
	var rw := tile_rect(T_WALL)
	b.quad(xf * Vector3(-w * 0.5, H - 0.4, 0), xf * Vector3(w * 0.5, H - 0.4, 0), xf * Vector3(w * 0.5, H, 0), xf * Vector3(-w * 0.5, H, 0), wall.darkened(0.05),
		Vector2(rw.position.x, rw.end.y), Vector2(rw.end.x, rw.position.y))
	# costados y fondo con pocas ventanas
	var sides := [[Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, 0, -d)], [Vector3(-w * 0.5, 0, -d), Vector3(-w * 0.5, 0, 0)], [Vector3(w * 0.5, 0, -d), Vector3(-w * 0.5, 0, -d)]]
	for sd in sides:
		var a: Vector3 = sd[0]
		var c: Vector3 = sd[1]
		var L := a.distance_to(c)
		var nb := maxi(1, int(round(L / 3.0)))
		for fl in floors:
			for k in nb:
				var p0 := a.lerp(c, float(k) / float(nb)) + Vector3(0, float(fl) * fh, 0)
				var p1 := a.lerp(c, float(k + 1) / float(nb)) + Vector3(0, float(fl) * fh, 0)
				var t := T_WALL if (rng.randf() < 0.6 or style == 3) else T_WIN
				if style == 3:
					t = T_OFFICE
				var r := tile_rect(t)
				b.quad(xf * p0, xf * p1, xf * (p1 + Vector3(0, fh, 0)), xf * (p0 + Vector3(0, fh, 0)), wall.darkened(0.08),
					Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y))
		b.quad(xf * (a + Vector3(0, H - 0.4, 0)), xf * (c + Vector3(0, H - 0.4, 0)), xf * (c + Vector3(0, H, 0)), xf * (a + Vector3(0, H, 0)), wall.darkened(0.1),
			Vector2(rw.position.x, rw.end.y), Vector2(rw.end.x, rw.position.y))
	# techo
	if roof == 1:
		var rt := tile_rect(T_TILES)
		var ov := 0.45
		var ridge := H + minf(w, d) * 0.32
		var tcol := Color(1, 1, 1)
		# dos aguas con la cumbrera a lo largo del frente
		b.quad(xf * Vector3(-w * 0.5 - ov, H - 0.1, ov), xf * Vector3(w * 0.5 + ov, H - 0.1, ov), xf * Vector3(w * 0.5 + ov, ridge, -d * 0.5), xf * Vector3(-w * 0.5 - ov, ridge, -d * 0.5), tcol,
			Vector2(rt.position.x, rt.end.y), Vector2(rt.end.x, rt.position.y))
		b.quad(xf * Vector3(w * 0.5 + ov, H - 0.1, -d - ov), xf * Vector3(-w * 0.5 - ov, H - 0.1, -d - ov), xf * Vector3(-w * 0.5 - ov, ridge, -d * 0.5), xf * Vector3(w * 0.5 + ov, ridge, -d * 0.5), tcol,
			Vector2(rt.position.x, rt.end.y), Vector2(rt.end.x, rt.position.y))
		# hastiales
		b.tri(xf * Vector3(w * 0.5, H, 0), xf * Vector3(w * 0.5, H, -d), xf * Vector3(w * 0.5, ridge, -d * 0.5), wall.darkened(0.08), Vector2(rw.position.x, rw.end.y), Vector2(rw.end.x, rw.end.y), Vector2(rw.position.x, rw.position.y))
		b.tri(xf * Vector3(-w * 0.5, H, -d), xf * Vector3(-w * 0.5, H, 0), xf * Vector3(-w * 0.5, ridge, -d * 0.5), wall.darkened(0.08), Vector2(rw.position.x, rw.end.y), Vector2(rw.end.x, rw.end.y), Vector2(rw.position.x, rw.position.y))
	else:
		var rg := tile_rect(T_GRAVEL)
		b.quad(xf * Vector3(-w * 0.5, H, 0), xf * Vector3(w * 0.5, H, 0), xf * Vector3(w * 0.5, H, -d), xf * Vector3(-w * 0.5, H, -d), Color(1, 1, 1),
			Vector2(rg.position.x, rg.end.y), Vector2(rg.end.x, rg.position.y))
		# parapeto
		var pc := wall.darkened(0.15)
		for e in [[Vector3(-w * 0.5, H, 0), Vector3(w * 0.5, H, 0)], [Vector3(w * 0.5, H, -d), Vector3(-w * 0.5, H, -d)]]:
			var p0: Vector3 = e[0]
			var p1: Vector3 = e[1]
			b.quad(xf * p0, xf * p1, xf * (p1 + Vector3(0, 0.6, 0)), xf * (p0 + Vector3(0, 0.6, 0)), pc, Vector2(rw.position.x, rw.end.y), Vector2(rw.end.x, rw.position.y))
		if floors >= 3 and rng.randf() < 0.6:
			# tanque de agua en la terraza
			b.box(xf * Transform3D(Basis(), Vector3(rng.randf_range(-w * 0.3, w * 0.3), H + 1.0, -d * 0.5)), Vector3(1.6, 1.6, 1.6), Color(0.75, 0.75, 0.72))
	# vereda / zócalo
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.1, -d * 0.5)), Vector3(w + 0.1, 0.24, d + 0.1), wall.darkened(0.35))

# ───────────────────────── objetos chicos ─────────────────────────
## Auto estacionado simple (carrocería, cabina, ruedas)
static func parked_car(b: RefCounted, xf: Transform3D, paint: Color) -> void:
	b.box(xf * Transform3D(Basis(), Vector3(0, 0.62, 0)), Vector3(1.75, 0.62, 4.2), paint)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.17, -0.2)), Vector3(1.55, 0.5, 2.1), Color(0.16, 0.2, 0.26), paint)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var wb := Basis(Vector3(0, 0, 1), PI * 0.5)
			b.cyl(xf * Transform3D(wb, Vector3(sx * 0.95, 0.33, sz * 1.35)), 0.33, 0.33, 0.24 * sx, 8, Color(0.08, 0.08, 0.08), true, Color(0.5, 0.5, 0.52))

## Farol de calle
static func street_lamp(b: RefCounted, xf: Transform3D) -> void:
	b.cyl(xf, 0.09, 0.06, 6.5, 6, Color(0.3, 0.32, 0.35), false)
	b.box(xf * Transform3D(Basis(), Vector3(0, 6.45, 0.9)), Vector3(0.12, 0.12, 1.9), Color(0.3, 0.32, 0.35))
	b.box(xf * Transform3D(Basis(), Vector3(0, 6.35, 1.75)), Vector3(0.35, 0.16, 0.6), Color(0.95, 0.92, 0.75))

## Poste de luz rural con travesaño
static func power_pole(b: RefCounted, xf: Transform3D) -> void:
	b.cyl(xf, 0.16, 0.12, 8.0, 6, Color(0.42, 0.33, 0.24), false)
	b.box(xf * Transform3D(Basis(), Vector3(0, 7.5, 0)), Vector3(2.2, 0.14, 0.14), Color(0.4, 0.31, 0.22))

## Vaca (blanca y negra o colorada)
static func cow(b: RefCounted, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var c := Color(0.95, 0.94, 0.92) if rng.randf() < 0.5 else Color(0.5, 0.28, 0.16)
	var c2 := Color(0.08, 0.08, 0.08) if c.r > 0.8 else Color(0.95, 0.94, 0.92)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.05, 0)), Vector3(0.75, 0.75, 1.7), c, c2)
	b.box(xf * Transform3D(Basis(), Vector3(0, 1.25, 1.0)), Vector3(0.42, 0.42, 0.55), c2)
	for sx: float in [-0.25, 0.25]:
		for sz: float in [-0.6, 0.6]:
			b.box(xf * Transform3D(Basis(), Vector3(sx, 0.36, sz)), Vector3(0.14, 0.72, 0.14), c)

## Cartel verde de ruta o blanco de pueblo (panel con dos postes); el texto va aparte (Label3D)
static func sign_panel(b: RefCounted, xf: Transform3D, w: float, h: float, col: Color, height := 2.2) -> void:
	for sx: float in [-w * 0.38, w * 0.38]:
		b.box(xf * Transform3D(Basis(), Vector3(sx, (height + h) * 0.5, -0.06)), Vector3(0.1, height + h, 0.1), Color(0.55, 0.57, 0.6))
	b.box(xf * Transform3D(Basis(), Vector3(0, height + h * 0.5, 0)), Vector3(w, h, 0.08), col.darkened(0.2), col)
	b.quad(xf * Vector3(-w * 0.5, height, 0.045), xf * Vector3(w * 0.5, height, 0.045), xf * Vector3(w * 0.5, height + h, 0.045), xf * Vector3(-w * 0.5, height + h, 0.045), col)
	b.quad(xf * Vector3(-w * 0.5 + 0.06, height + 0.06, 0.05), xf * Vector3(w * 0.5 - 0.06, height + 0.06, 0.05), xf * Vector3(w * 0.5 - 0.06, height + h - 0.06, 0.05), xf * Vector3(-w * 0.5 + 0.06, height + h - 0.06, 0.05), col.lightened(0.6))
	b.quad(xf * Vector3(-w * 0.5 + 0.1, height + 0.1, 0.055), xf * Vector3(w * 0.5 - 0.1, height + 0.1, 0.055), xf * Vector3(w * 0.5 - 0.1, height + h - 0.1, 0.055), xf * Vector3(-w * 0.5 + 0.1, height + h - 0.1, 0.055), col)

static func label(text: String, pos: Vector3, yaw: float, size_px: float, col := Color.WHITE, outline := Color(0, 0, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = size_px
	l.modulate = col
	l.outline_size = 0 if outline.a == 0.0 else 10
	l.outline_modulate = outline
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation.y = yaw
	l.visibility_range_end = 260.0
	return l

# ───────────────────────── estación de servicio ─────────────────────────
## Estación «DREAM»: marquesina con luces, dos islas de surtidores, minimercado vidriado, tótem de precios, faroles y
## detalles. Marco local: z hacia adelante (por el camino), x hacia la IZQUIERDA (la estación queda en x negativo),
## origen en el centro del camino a la altura de los surtidores. lat0: distancia del centro al borde del playón.
static func gas_station(name: String, lat0: float) -> Node3D:
	var root := Node3D.new()
	var b := MB.new() # pintura y hormigón
	var m := MB.new() # metal
	var e := MB.new() # luces
	var a := MB.new() # atlas
	var blue := Color(0.10, 0.17, 0.45)
	var orange := Color(1.0, 0.48, 0.1)
	var white := Color(0.95, 0.95, 0.93)
	var px := -(lat0 * 0.5 + 2.6) # centro de la marquesina
	# marquesina: losa con frente pintado y franja naranja, luces abajo
	var cw := 12.0
	var cl := 20.0
	var ch := 5.4
	b.box(Transform3D(Basis(), Vector3(px, ch + 0.45, 0)), Vector3(cw, 0.9, cl), white, white)
	b.box(Transform3D(Basis(), Vector3(px, ch + 0.62, 0)), Vector3(cw + 0.06, 0.34, cl + 0.06), blue)
	b.box(Transform3D(Basis(), Vector3(px, ch + 0.2, 0)), Vector3(cw + 0.05, 0.12, cl + 0.05), orange)
	for k in 6:
		for j in 2:
			e.box(Transform3D(Basis(), Vector3(px - 2.6 + 5.2 * float(j), ch - 0.02, -7.5 + float(k) * 3.0)), Vector3(1.4, 0.05, 0.7), Color(1.0, 0.98, 0.9))
	# columnas
	for sx: float in [-3.5, 3.5]:
		for sz: float in [-6.0, 6.0]:
			b.box(Transform3D(Basis(), Vector3(px + sx, ch * 0.5, sz)), Vector3(0.5, ch, 0.5), white)
			b.box(Transform3D(Basis(), Vector3(px + sx, 0.6, sz)), Vector3(0.56, 1.2, 0.56), blue)
	# islas y surtidores
	for sx: float in [-3.5, 3.5]:
		b.box(Transform3D(Basis(), Vector3(px + sx, 0.1, 0)), Vector3(1.4, 0.2, 9.0), Color(0.75, 0.75, 0.72), Color(0.95, 0.8, 0.1))
		for sz: float in [-2.3, 2.3]:
			var xf := Transform3D(Basis(), Vector3(px + sx, 0.2, sz))
			b.box(xf * Transform3D(Basis(), Vector3(0, 0.95, 0)), Vector3(0.75, 1.9, 1.15), white)
			b.box(xf * Transform3D(Basis(), Vector3(0, 1.75, 0)), Vector3(0.8, 0.3, 1.2), blue)
			e.box(xf * Transform3D(Basis(), Vector3(0.39, 1.25, 0)), Vector3(0.02, 0.45, 0.6), Color(0.4, 0.95, 0.6))
			e.box(xf * Transform3D(Basis(), Vector3(-0.39, 1.25, 0)), Vector3(0.02, 0.45, 0.6), Color(0.4, 0.95, 0.6))
			m.box(xf * Transform3D(Basis(), Vector3(0.42, 0.9, 0.35)), Vector3(0.08, 0.5, 0.12), Color(0.15, 0.15, 0.16))
			m.box(xf * Transform3D(Basis(), Vector3(-0.42, 0.9, -0.35)), Vector3(0.08, 0.5, 0.12), Color(0.15, 0.15, 0.16))
	# minimercado vidriado
	var sx0 := -(lat0 + 9.5)
	var sw := 9.0
	var sl := 16.0
	var shh := 4.2
	b.box(Transform3D(Basis(), Vector3(sx0 - 1.0, shh * 0.5, 0)), Vector3(sw - 2.0, shh, sl), white)
	e.box(Transform3D(Basis(), Vector3(sx0 + sw * 0.5 - 1.2, 1.7, 0)), Vector3(0.2, 2.8, sl - 1.2), Color(1.0, 0.86, 0.6)) # interior iluminado
	m.box(Transform3D(Basis(), Vector3(sx0 + sw * 0.5 - 1.05, 1.7, 0)), Vector3(0.06, 2.9, sl - 1.0), Color(0.12, 0.16, 0.22)) # vidrio (marco)
	b.box(Transform3D(Basis(), Vector3(sx0, shh + 0.35, 0)), Vector3(sw + 0.4, 0.7, sl + 0.4), blue)
	b.box(Transform3D(Basis(), Vector3(sx0, shh + 0.06, 0)), Vector3(sw + 0.42, 0.12, sl + 0.42), orange)
	b.box(Transform3D(Basis(), Vector3(sx0 + sw * 0.5 + 0.6, 0.06, 0)), Vector3(1.4, 0.12, sl), Color(0.7, 0.7, 0.68))
	# tótem de precios junto al camino
	var tz := -16.0
	var tx := -(lat0 + 1.2)
	b.box(Transform3D(Basis(), Vector3(tx, 4.0, tz)), Vector3(0.7, 8.0, 2.4), white)
	b.box(Transform3D(Basis(), Vector3(tx, 6.6, tz)), Vector3(0.78, 2.4, 2.5), blue)
	e.box(Transform3D(Basis(), Vector3(tx, 3.9, tz)), Vector3(0.74, 2.2, 2.1), Color(0.08, 0.09, 0.12))
	# faroles, aire y agua, cestos, macetas
	for k in 3:
		var lz := -14.0 + float(k) * 14.0
		var lxf := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-(lat0 + 0.6), 0, lz))
		m.cyl(lxf, 0.1, 0.07, 7.0, 6, Color(0.3, 0.32, 0.35), false)
		m.box(lxf * Transform3D(Basis(), Vector3(0, 6.95, 0.8)), Vector3(0.12, 0.12, 1.7), Color(0.3, 0.32, 0.35))
		e.box(lxf * Transform3D(Basis(), Vector3(0, 6.85, 1.55)), Vector3(0.38, 0.12, 0.62), Color(1.0, 0.96, 0.82))
	b.box(Transform3D(Basis(), Vector3(px - 7.6, 0.6, 9.0)), Vector3(0.5, 1.2, 0.5), Color(0.85, 0.15, 0.12))
	for k in 4:
		b.box(Transform3D(Basis(), Vector3(sx0 + sw * 0.5 + 0.6, 0.4, -6.0 + float(k) * 4.0)), Vector3(0.8, 0.5, 0.8), Color(0.55, 0.4, 0.3), Color(0.25, 0.42, 0.2))
	# autos estacionados al costado del minimercado
	parked_car(b, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx0 + sw * 0.5 + 2.6, 0, sl * 0.5 + 3.5)), Color(0.75, 0.1, 0.1))
	parked_car(b, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx0 + sw * 0.5 + 2.6, 0, sl * 0.5 + 6.5)), Color(0.85, 0.85, 0.82))
	_finish(root, b, m, e, a)
	# letreros
	var yaw_f := 0.0 # mirando hacia adelante (+z)
	for sgn: float in [1.0, -1.0]:
		var lb := label("DREAM", Vector3(px, ch + 0.62, sgn * (cl * 0.5 + 0.07)), 0.0 if sgn > 0 else PI, 0.024, Color(1, 1, 1))
		lb.font_size = 72
		root.add_child(lb)
		var lb2 := label("★", Vector3(px - 4.2, ch + 0.62, sgn * (cl * 0.5 + 0.07)), 0.0 if sgn > 0 else PI, 0.03, Color(1.0, 0.55, 0.15))
		root.add_child(lb2)
	var road_side := label("DREAM", Vector3(px + cw * 0.5 + 0.07, ch + 0.62, 0), PI * 0.5, 0.03, Color(1, 1, 1))
	root.add_child(road_side)
	var shop := label("DREAM SHOP · 24 h", Vector3(sx0 + sw * 0.5 + 0.23, shh + 0.36, 0), PI * 0.5, 0.012, Color(1, 1, 1))
	root.add_child(shop)
	var tt := label("DREAM", Vector3(tx + 0.41, 6.7, tz), PI * 0.5, 0.012, Color(1, 1, 1))
	root.add_child(tt)
	var pr := label("SÚPER      1.459\nPREMIUM  1.689\nDIÉSEL      1.399", Vector3(tx + 0.4, 3.9, tz), PI * 0.5, 0.0055, Color(1.0, 0.75, 0.25))
	pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	root.add_child(pr)
	var nm := label(name.to_upper(), Vector3(tx + 0.4, 1.6, tz), PI * 0.5, 0.0045, Color(0.1, 0.17, 0.45))
	root.add_child(nm)
	var nm2 := label(name.to_upper(), Vector3(tx - 0.4, 1.6, tz), -PI * 0.5, 0.0045, Color(0.1, 0.17, 0.45))
	root.add_child(nm2)
	return root

## Taller mecánico: galpón de ladrillo con techo de chapa, portón abierto con el interior iluminado (elevador, tablero de
## herramientas, banco), pila de cubiertas, tambores, cartel pintado. Mismo marco que la estación.
static func workshop(name: String, lat0: float) -> Node3D:
	var root := Node3D.new()
	var b := MB.new()
	var m := MB.new()
	var e := MB.new()
	var a := MB.new()
	var cx := -(lat0 + 8.0) # centro del galpón
	var W := 12.0 # frente (a lo largo del camino)
	var D := 13.0
	var H := 5.5
	var brick := Color(1, 1, 1)
	var rb := tile_rect(T_BRICK)
	var rt := tile_rect(T_TIN)
	# paredes: fondo y los dos costados (el frente da al camino con el portón)
	var x_front := cx + D * 0.5
	var x_back := cx - D * 0.5
	var walls := [
		[Vector3(x_back, 0, W * 0.5), Vector3(x_back, 0, -W * 0.5)],
		[Vector3(x_front, 0, W * 0.5), Vector3(x_back, 0, W * 0.5)],
		[Vector3(x_back, 0, -W * 0.5), Vector3(x_front, 0, -W * 0.5)],
	]
	for wv in walls:
		var p0: Vector3 = wv[0]
		var p1: Vector3 = wv[1]
		var nb := int(round(p0.distance_to(p1) / 3.0))
		for k in nb:
			for fl in 2:
				var q0 := p0.lerp(p1, float(k) / float(nb)) + Vector3(0, float(fl) * H * 0.5, 0)
				var q1 := p0.lerp(p1, float(k + 1) / float(nb)) + Vector3(0, float(fl) * H * 0.5, 0)
				# por fuera y por dentro (la cámara entra al taller)
				a.quad(q1, q0, q0 + Vector3(0, H * 0.5, 0), q1 + Vector3(0, H * 0.5, 0), brick, Vector2(rb.position.x, rb.end.y), Vector2(rb.end.x, rb.position.y))
				var tools: bool = wv == walls[0] and fl == 0
				var rr := tile_rect(T_TOOLS if tools else T_WALL)
				a.quad(q0, q1, q1 + Vector3(0, H * 0.5, 0), q0 + Vector3(0, H * 0.5, 0), Color(1, 1, 1) if tools else Color(0.85, 0.85, 0.82), Vector2(rr.position.x, rr.end.y), Vector2(rr.end.x, rr.position.y))
	# frente: pared a los lados y arriba del portón (portón de 7 m × 4,2 m)
	var gw := 7.0
	var gh := 4.2
	for sd: float in [-1.0, 1.0]:
		var z0 := sd * gw * 0.5
		var z1 := sd * W * 0.5
		var za := z0 if sd < 0.0 else z1
		var zb := z1 if sd < 0.0 else z0
		var rw2 := tile_rect(T_WALL)
		a.quad(Vector3(x_front, 0, za), Vector3(x_front, 0, zb), Vector3(x_front, H, zb), Vector3(x_front, H, za), brick, Vector2(rb.position.x, rb.end.y), Vector2(rb.end.x, rb.position.y))
		a.quad(Vector3(x_front, 0, zb), Vector3(x_front, 0, za), Vector3(x_front, H, za), Vector3(x_front, H, zb), Color(0.85, 0.85, 0.82), Vector2(rw2.position.x, rw2.end.y), Vector2(rw2.end.x, rw2.position.y))
	a.quad(Vector3(x_front, gh, gw * 0.5), Vector3(x_front, gh, -gw * 0.5), Vector3(x_front, H, -gw * 0.5), Vector3(x_front, H, gw * 0.5), brick, Vector2(rb.position.x, rb.end.y), Vector2(rb.end.x, rb.position.y))
	a.quad(Vector3(x_front, gh, -gw * 0.5), Vector3(x_front, gh, gw * 0.5), Vector3(x_front, H, gw * 0.5), Vector3(x_front, H, -gw * 0.5), Color(0.85, 0.85, 0.82), Vector2(rb.position.x, rb.end.y), Vector2(rb.end.x, rb.position.y))
	# techo de chapa a un agua (y su cara de abajo)
	a.quad(Vector3(x_front + 0.6, H + 0.3, -W * 0.5 - 0.4), Vector3(x_front + 0.6, H + 0.3, W * 0.5 + 0.4), Vector3(x_back - 0.4, H + 1.4, W * 0.5 + 0.4), Vector3(x_back - 0.4, H + 1.4, -W * 0.5 - 0.4), Color(0.45, 0.45, 0.47), Vector2(rt.position.x, rt.end.y), Vector2(rt.end.x, rt.position.y))
	a.quad(Vector3(x_back - 0.4, H + 1.38, -W * 0.5 - 0.4), Vector3(x_back - 0.4, H + 1.38, W * 0.5 + 0.4), Vector3(x_front + 0.6, H + 0.28, W * 0.5 + 0.4), Vector3(x_front + 0.6, H + 0.28, -W * 0.5 - 0.4), Color(0.85, 0.87, 0.9), Vector2(rt.position.x, rt.end.y), Vector2(rt.end.x, rt.position.y))
	for wv in [[W * 0.5, 1.0], [-W * 0.5, -1.0]]:
		var zz: float = wv[0]
		if float(wv[1]) < 0.0:
			b.quad(Vector3(x_front, H, zz), Vector3(x_back, H, zz), Vector3(x_back, H + 1.4, zz), Vector3(x_front, H + 0.3, zz), Color(0.62, 0.34, 0.24))
		else:
			b.quad(Vector3(x_back, H, zz), Vector3(x_front, H, zz), Vector3(x_front, H + 0.3, zz), Vector3(x_back, H + 1.4, zz), Color(0.62, 0.34, 0.24))
	# piso de hormigón adentro
	var rc := tile_rect(T_CONC)
	a.quad(Vector3(x_back, 0.03, -W * 0.5), Vector3(x_back, 0.03, W * 0.5), Vector3(x_front, 0.03, W * 0.5), Vector3(x_front, 0.03, -W * 0.5), Color(0.8, 0.8, 0.78), Vector2(rc.position.x, rc.end.y), Vector2(rc.end.x, rc.position.y))
	# luces del techo y del interior
	for k in 3:
		e.box(Transform3D(Basis(), Vector3(cx - 3.0 + float(k) * 3.0, H - 0.1, 0)), Vector3(0.3, 0.08, 2.6), Color(1.0, 0.97, 0.88))
	# elevador (columnas y brazos), banco de trabajo, estantes, compresor
	for sz: float in [-3.0, 3.0]:
		m.box(Transform3D(Basis(), Vector3(cx - 5.2, 1.6, sz)), Vector3(0.35, 3.2, 0.35), Color(0.85, 0.2, 0.12))
		m.box(Transform3D(Basis(), Vector3(cx - 4.4, 0.25, sz * 0.8)), Vector3(1.4, 0.12, 0.25), Color(0.3, 0.3, 0.32))
	b.box(Transform3D(Basis(), Vector3(x_back + 0.6, 0.45, -3.0)), Vector3(0.9, 0.9, 3.5), Color(0.45, 0.32, 0.2), Color(0.55, 0.42, 0.28))
	b.box(Transform3D(Basis(), Vector3(x_back + 0.5, 1.6, 3.5)), Vector3(0.6, 3.2, 2.5), Color(0.25, 0.3, 0.38))
	b.box(Transform3D(Basis(), Vector3(x_back + 0.9, 0.5, 0.8)), Vector3(0.8, 1.0, 0.7), Color(0.9, 0.4, 0.1))
	# afuera: cubiertas apiladas, tambores, un auto viejo sobre tacos
	for k in 6:
		var tz := W * 0.5 + 1.2
		var txf := Transform3D(Basis(), Vector3(x_front - 1.0 - float(k / 3) * 1.0, float(k % 3) * 0.28, tz + float(k / 3) * 0.2))
		b.cyl(txf, 0.42, 0.42, 0.26, 10, Color(0.08, 0.08, 0.08), true, Color(0.18, 0.18, 0.18))
	for k in 3:
		m.cyl(Transform3D(Basis(), Vector3(x_front - 0.6 - float(k) * 0.7, 0, -W * 0.5 - 0.8)), 0.3, 0.3, 0.9, 10, [Color(0.15, 0.35, 0.6), Color(0.75, 0.15, 0.1), Color(0.2, 0.5, 0.25)][k], true)
	parked_car(b, Transform3D(Basis(Vector3.UP, 0.3), Vector3(x_front + 5.0, 0.25, -W * 0.5 - 4.5)), Color(0.35, 0.45, 0.55))
	_finish(root, b, m, e, a)
	# cartel pintado sobre el portón y uno de pie junto al camino
	var lbl := label("TALLER MECÁNICO\n" + name.to_upper(), Vector3(x_front + 0.05, gh + 0.68, 0), PI * 0.5, 0.0085, Color(1, 0.95, 0.85), Color(0.15, 0.1, 0.08))
	root.add_child(lbl)
	var sgn := MB.new()
	sign_panel(sgn, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-(lat0 + 0.8), 0, -18.0)), 3.2, 1.6, Color(0.95, 0.75, 0.15), 1.8)
	var mi := MeshInstance3D.new()
	mi.mesh = sgn.commit(_mat("vc"))
	root.add_child(mi)
	var l2 := label("🔧 TALLER", Vector3(-(lat0 + 0.8) + 0.1, 2.6, -18.0), PI * 0.5, 0.012, Color(0.1, 0.08, 0.05))
	root.add_child(l2)
	return root

static var _mats := {}
static func _mat(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	match kind:
		"metal":
			m.metallic = 0.6
			m.roughness = 0.35
		"emis":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"atlas":
			m.albedo_texture = atlas()
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.roughness = 0.9
		"tree":
			m.roughness = 1.0
	_mats[kind] = m
	return m

static func material(kind: String) -> Material:
	return _mat(kind)

static func _finish(root: Node3D, b: RefCounted, m: RefCounted, e: RefCounted, a: RefCounted) -> void:
	for pair in [[b, "vc"], [m, "metal"], [e, "emis"], [a, "atlas"]]:
		var mb: RefCounted = pair[0]
		if mb.size() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = mb.commit(_mat(str(pair[1])))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
