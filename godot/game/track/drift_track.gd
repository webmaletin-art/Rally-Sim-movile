extends "res://game/physics/track_base.gd"
## Pista de drift: un playón grande (240 × 240 m) con rotonda pintada, aros de conos y slalom, dentro de una ciudad chica.
## Por la boca del norte se sale a una avenida que llega a la rotonda de la ciudad (con isla, árboles y faroles) y calles
## con manzanas de edificios, veredas y cruces. Todo es plano; lo que choca (paredes, manzanas, isla, árboles) son
## rectángulos y círculos que consulta push(). Los conos tienen física propia (cone_field.gd).
## Ejes: x a la derecha, z hacia el sur (adelante del auto con yaw 0). El playón está en el origen; la ciudad, al norte (−z).

const MB := preload("res://game/adventure/adv_mesh.gd")
const Props := preload("res://game/adventure/adv_props.gd")
const ConeField := preload("res://game/track/cone_field.gd")

const HALF := 120.0 # medio lado del playón (centro de las paredes)
const WALL := 1.2 # medio espesor de las paredes
const GATE := 15.0 # media boca de la salida norte
const SW := 3.0 # ancho de las veredas
const RB := Vector2(0.0, -290.0) # centro de la rotonda de la ciudad
const RB_R := 15.0 # radio de afuera de la rotonda
const ISLAND_R := 6.0 # radio de la isla del medio
const X0 := -300.0
const X1 := 300.0
const Z0 := -460.0
const Z1 := 122.0

## Manzanas: columnas (x0, x1) y filas (z0, z1). Entre ellas quedan las calles (26 m; 30 m las avenidas).
const COLS := [[-300.0, -163.0], [-137.0, -15.0], [15.0, 137.0], [163.0, 300.0]]
const ROWS := [[-460.0, -443.0], [-417.0, -305.0], [-275.0, -163.0], [-137.0, -121.2]]
## Calles de este-oeste (centro z, ancho) y de norte-sur (centro x, ancho)
const STREETS_EW := [[-150.0, 26.0], [-290.0, 30.0], [-430.0, 26.0]]
const STREETS_NS := [[0.0, 30.0], [-150.0, 26.0], [150.0, 26.0]]

var n := 0 # el minimapa y la sesión miran estos dos (hay una sola "vuelta" ficticia)
var samples: Array = []
var length := 1000.0
var map_lines: Array = [] # polilíneas para el minimapa (x, z)
var map_bounds := Rect2(-300.0, -460.0, 600.0, 580.0)

var road_mat: StandardMaterial3D
var ground_mat: StandardMaterial3D
var cones: ConeField
var _bx := PackedFloat32Array() # rectángulos: x0, z0, x1, z1
var _cc := PackedFloat32Array() # círculos: x, z, r
var _rng := RandomNumberGenerator.new()
var cone_count := 0

func _init() -> void:
	_rng.seed = 2024
	samples = [Vector3(0, 0, 0)]
	n = 1
	_layout()

# ───────────────────────── interfaz de pista ─────────────────────────
func ground_info(x: float, z: float) -> Vector2:
	if x < X0 - 2.0 or x > X1 + 2.0 or z < Z0 - 2.0 or z > Z1 + 2.0:
		return Vector2(0.0, 4.0)
	return Vector2(0.0, 0.0)

func nearest(_x: float, _z: float) -> void:
	pass

## Pose de largada: en el playón, de cara al centro (al norte, yaw π). Los lugares se abren en filas de dos.
func start_pose(slot: int) -> Array:
	var side := -1.0 if slot % 2 == 0 else 1.0
	return [side * 3.0 + (0.0 if slot < 2 else side * 2.0), 78.0 + float(slot / 2) * 9.0, PI]

func _box(x0: float, z0: float, x1: float, z1: float) -> void:
	_bx.append_array([x0, z0, x1, z1])

func _circle(x: float, z: float, r: float) -> void:
	_cc.append_array([x, z, r])

## Empuja un círculo (x, z, r) fuera de los obstáculos. Devuelve (nx, nz, profundidad): la normal que sale del obstáculo más
## hundido y cuánto hay que correrse; profundidad 0 = no choca.
func push(x: float, z: float, r: float) -> Vector3:
	var best := 0.0
	var bx := 0.0
	var bz := 0.0
	var i := 0
	var r2 := r * r
	while i < _bx.size():
		var a := _bx[i]
		var b := _bx[i + 1]
		var c := _bx[i + 2]
		var d := _bx[i + 3]
		i += 4
		if x < a - r or x > c + r or z < b - r or z > d + r:
			continue
		var cx := clampf(x, a, c)
		var cz := clampf(z, b, d)
		var dx := x - cx
		var dz := z - cz
		var d2 := dx * dx + dz * dz
		if d2 >= r2:
			continue
		if d2 > 1e-8:
			var dd := sqrt(d2)
			if r - dd > best:
				best = r - dd
				bx = dx / dd
				bz = dz / dd
		else:
			# el centro quedó adentro del rectángulo: sale por el lado más cercano
			var l := x - a
			var rr := c - x
			var t := z - b
			var bt := d - z
			var m := minf(minf(l, rr), minf(t, bt))
			if m + r > best:
				best = m + r
				if m == l:
					bx = -1.0
					bz = 0.0
				elif m == rr:
					bx = 1.0
					bz = 0.0
				elif m == t:
					bx = 0.0
					bz = -1.0
				else:
					bx = 0.0
					bz = 1.0
	i = 0
	while i < _cc.size():
		var ox := x - _cc[i]
		var oz := z - _cc[i + 1]
		var rs := r + _cc[i + 2]
		i += 3
		var e2 := ox * ox + oz * oz
		if e2 >= rs * rs:
			continue
		var e := sqrt(e2)
		if rs - e > best:
			best = rs - e
			bx = ox / e if e > 0.001 else 1.0
			bz = oz / e if e > 0.001 else 0.0
	return Vector3(bx, bz, best)

# ───────────────────────── trazado ─────────────────────────
func _layout() -> void:
	# paredes del playón (con la boca al norte)
	var w := WALL
	_box(-HALF - w, -HALF - w, -GATE, -HALF + w)
	_box(GATE, -HALF - w, HALF + w, -HALF + w)
	_box(-HALF - w, HALF - w, HALF + w, HALF + w)
	_box(-HALF - w, -HALF - w, -HALF + w, HALF + w)
	_box(HALF - w, -HALF - w, HALF + w, HALF + w)
	# borde del mundo
	_box(X0 - 2.0, Z0 - 4.0, X1 + 2.0, Z0)
	_box(X0 - 2.0, Z0 - 4.0, X0, Z1 + 2.0)
	_box(X1, Z0 - 4.0, X1 + 2.0, Z1 + 2.0)
	_box(X0 - 2.0, Z1, X1 + 2.0, Z1 + 2.0)
	# manzanas de la ciudad
	for r in ROWS:
		for c in COLS:
			_box(float(c[0]), float(r[0]), float(c[1]), float(r[1]))
	# isla de la rotonda
	_circle(RB.x, RB.y, ISLAND_R)
	# árboles de las veredas: círculos chicos (se calculan junto con el dibujo)
	# minimapa: contorno del playón, la avenida, la rotonda y las calles principales
	var ringp := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		ringp.append(RB + Vector2(cos(a), sin(a)) * RB_R)
	map_lines = [
		PackedVector2Array([Vector2(-HALF, HALF), Vector2(-HALF, -HALF), Vector2(-GATE, -HALF), Vector2(-GATE, -150.0)]),
		PackedVector2Array([Vector2(HALF, HALF), Vector2(HALF, -HALF), Vector2(GATE, -HALF), Vector2(GATE, -150.0)]),
		PackedVector2Array([Vector2(-HALF, HALF), Vector2(HALF, HALF)]),
		PackedVector2Array([Vector2(0.0, -HALF), Vector2(0.0, -440.0)]),
		PackedVector2Array([Vector2(-290.0, -150.0), Vector2(290.0, -150.0)]),
		PackedVector2Array([Vector2(-290.0, -290.0), Vector2(290.0, -290.0)]),
		PackedVector2Array([Vector2(-290.0, -430.0), Vector2(290.0, -430.0)]),
		PackedVector2Array([Vector2(-150.0, -150.0), Vector2(-150.0, -430.0)]),
		PackedVector2Array([Vector2(150.0, -150.0), Vector2(150.0, -430.0)]),
		ringp,
	]

# ───────────────────────── dibujo ─────────────────────────
static var _noise: ImageTexture

static func asphalt_texture() -> ImageTexture:
	if _noise != null:
		return _noise
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	img.fill(Color(0.93, 0.93, 0.93))
	for k in 9000:
		var g := 0.80 + rng.randf() * 0.26
		img.set_pixel(rng.randi() % 128, rng.randi() % 128, Color(g, g, g * 1.02))
	_noise = ImageTexture.create_from_image(img)
	return _noise

## Rectángulo en el piso (y fijo) visto desde arriba
static func floor_quad(b: RefCounted, x0: float, z0: float, x1: float, z1: float, y: float, col: Color, tile := 6.0) -> void:
	b.quad(Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), Vector3(x0, y, z0), col, Vector2(x0 / tile, z1 / tile), Vector2(x1 / tile, z0 / tile))

## Anillo pintado (centro c, radio r, ancho w)
static func ring(b: RefCounted, c: Vector2, r: float, w: float, y: float, col: Color, seg := 96, arc0 := 0.0, arc1 := TAU) -> void:
	for i in seg:
		var a0 := arc0 + (arc1 - arc0) * float(i) / float(seg)
		var a1 := arc0 + (arc1 - arc0) * float(i + 1) / float(seg)
		var i0 := Vector3(c.x + cos(a0) * (r - w * 0.5), y, c.y + sin(a0) * (r - w * 0.5))
		var o0 := Vector3(c.x + cos(a0) * (r + w * 0.5), y, c.y + sin(a0) * (r + w * 0.5))
		var i1 := Vector3(c.x + cos(a1) * (r - w * 0.5), y, c.y + sin(a1) * (r - w * 0.5))
		var o1 := Vector3(c.x + cos(a1) * (r + w * 0.5), y, c.y + sin(a1) * (r + w * 0.5))
		# visto desde arriba el sentido es antihorario: i0 → i1 → o1 → o0 mira hacia abajo, así que se invierte
		b.quad(i0, o0, o1, i1, col, Vector2.ZERO, Vector2.ZERO)

## Raya entre dos puntos del piso
static func line(b: RefCounted, a: Vector2, c: Vector2, w: float, y: float, col: Color) -> void:
	var d := (c - a).normalized()
	var nn := Vector2(-d.y, d.x) * w * 0.5
	b.quad(Vector3(a.x - nn.x, y, a.y - nn.y), Vector3(c.x - nn.x, y, c.y - nn.y), Vector3(c.x + nn.x, y, c.y + nn.y), Vector3(a.x + nn.x, y, a.y + nn.y), col, Vector2.ZERO, Vector2.ZERO)

## Todo lo que se ve: devuelve un nodo con el piso, las manzanas con sus edificios, las paredes, los faroles, la isla y los conos
func build_world() -> Node3D:
	var root := Node3D.new()
	root.name = "ciudad_drift"
	road_mat = StandardMaterial3D.new()
	road_mat.vertex_color_use_as_albedo = true
	road_mat.albedo_texture = asphalt_texture()
	road_mat.roughness = 0.9
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.17, 0.22, 0.14)
	ground_mat.roughness = 1.0
	# fuera de la ciudad: un piso grande y oscuro
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000.0, 4000.0)
	far.mesh = pm
	far.material_override = ground_mat
	far.position = Vector3(0.0, -0.08, -170.0)
	root.add_child(far)
	# piso: asfalto de la ciudad + playón + rayas
	var b := MB.new()
	var asphalt := Color(0.30, 0.31, 0.33)
	var plaza := Color(0.60, 0.66, 0.68)
	floor_quad(b, X0, Z0, X1, Z1, 0.0, asphalt, 8.0)
	floor_quad(b, -HALF, -HALF, HALF, HALF, 0.012, plaza, 8.0)
	floor_quad(b, -GATE, -HALF - 1.0, GATE, -HALF + 1.0, 0.012, plaza, 8.0)
	var white := Color(0.94, 0.94, 0.92)
	var yellow := Color(0.95, 0.78, 0.15)
	var ly := 0.03
	# ── playón: rotonda de drift con aros, marcas y cruz
	var C := Vector2.ZERO
	ring(b, C, 12.0, 0.20, ly, Color(0.91, 0.91, 0.9), 64)
	ring(b, C, 25.0, 0.30, ly, white, 96)
	ring(b, C, 25.7, 0.12, ly, white, 96)
	ring(b, C, 45.0, 0.20, ly, Color(0.88, 0.88, 0.86), 120)
	ring(b, C, 95.0, 0.22, ly, Color(0.82, 0.82, 0.8), 160)
	for i in 12:
		var a := float(i) * PI / 6.0
		line(b, Vector2(cos(a) * 30.0, sin(a) * 30.0), Vector2(cos(a) * 43.0, sin(a) * 43.0), 0.22, ly, white)
	line(b, Vector2(-3, 0), Vector2(3, 0), 0.25, ly, white)
	line(b, Vector2(0, -3), Vector2(0, 3), 0.25, ly, white)
	# casilla de largada (abajo)
	for sx in [-5.5, 5.5]:
		line(b, Vector2(sx, 70.0), Vector2(sx, 92.0), 0.2, ly, yellow)
	line(b, Vector2(-5.5, 70.0), Vector2(5.5, 70.0), 0.25, ly, yellow)
	# flechas hacia la salida del norte
	for k in 4:
		var zz := -HALF + 14.0 + float(k) * 7.0
		b.tri(Vector3(0, ly, zz - 3.0), Vector3(2.6, ly, zz + 1.5), Vector3(-2.6, ly, zz + 1.5), yellow)
	# ── calles: líneas del medio, cruces peatonales y bordes de vereda
	for st in STREETS_EW:
		var zc: float = st[0]
		for xi in range(int(X0) + 10, int(X1) - 10, 12):
			var xx := float(xi)
			if absf(xx) < 18.0 and absf(zc - RB.y) < 1.0:
				continue
			if absf(xx) < 17.0 or absf(absf(xx) - 150.0) < 18.0:
				continue
			line(b, Vector2(xx, zc), Vector2(xx + 6.0, zc), 0.18, ly, white)
	for st in STREETS_NS:
		var xc: float = st[0]
		var wd: float = st[1]
		var z_from := -440.0
		var z_to := -121.0
		if absf(xc) < 1.0:
			line(b, Vector2(xc - 0.25, z_from), Vector2(xc - 0.25, z_to), 0.14, ly, yellow)
			line(b, Vector2(xc + 0.25, z_from), Vector2(xc + 0.25, z_to), 0.14, ly, yellow)
		else:
			for zi in range(int(z_from) + 10, int(z_to) - 10, 12):
				var zz := float(zi)
				if absf(zz + 150.0) < 18.0 or absf(zz + 290.0) < 18.0 or absf(zz + 430.0) < 18.0:
					continue
				line(b, Vector2(xc, zz), Vector2(xc, zz + 6.0), 0.18, ly, white)
		_zebra_ew(b, xc, wd, white)
	# rotonda de la ciudad: calzada, aro pintado, isla con cordón
	ring(b, RB, RB_R - 1.0, 0.25, ly, white, 72)
	_disc(b, RB, ISLAND_R + 0.9, 0.16, Color(0.72, 0.72, 0.7), 28)
	_disc(b, RB, ISLAND_R, 0.18, Color(0.24, 0.42, 0.18), 28)
	for i in 8:
		var a := float(i) * TAU / 8.0
		var p := RB + Vector2(cos(a), sin(a)) * (RB_R - 2.0)
		b.tri(Vector3(p.x + cos(a) * 1.2, ly, p.y + sin(a) * 1.2), Vector3(p.x - sin(a) * 0.9, ly, p.y + cos(a) * 0.9), Vector3(p.x + sin(a) * 0.9, ly, p.y - cos(a) * 0.9), white)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(road_mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# "DRIFT" pintado en el piso
	for lb in [["DRIFT", Vector3(0, 0.05, -62.0), 0.36], ["DREAM RACING", Vector3(0, 0.05, 62.0), 0.22]]:
		var l := Label3D.new()
		l.text = str(lb[0])
		l.font_size = 64
		l.pixel_size = float(lb[2])
		l.modulate = Color(0.95, 0.95, 0.93, 0.5)
		l.shaded = false
		l.double_sided = true
		l.position = lb[1]
		l.rotation_degrees = Vector3(-90, 0, 0)
		root.add_child(l)
	# ── paredes del playón
	var pb := MB.new()
	var conc := Color(0.62, 0.62, 0.6)
	var stripe := Color(0.86, 0.18, 0.14)
	_wall(pb, Vector2(-HALF, -HALF), Vector2(-GATE, -HALF), conc, stripe)
	_wall(pb, Vector2(GATE, -HALF), Vector2(HALF, -HALF), conc, stripe)
	_wall(pb, Vector2(HALF, -HALF), Vector2(HALF, HALF), conc, stripe)
	_wall(pb, Vector2(HALF, HALF), Vector2(-HALF, HALF), conc, stripe)
	_wall(pb, Vector2(-HALF, HALF), Vector2(-HALF, -HALF), conc, stripe)
	# pilones de la boca
	for sx in [-GATE, GATE]:
		pb.cyl(Transform3D(Basis(), Vector3(sx, 0, -HALF)), 0.9, 0.9, 1.6, 8, Color(0.9, 0.9, 0.88), true, Color(0.9, 0.2, 0.15))
	var pmi := MeshInstance3D.new()
	pmi.mesh = pb.commit(Props.material("vc"))
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pmi)
	# ── manzanas con sus edificios (una malla por manzana: se descartan las que no se ven)
	var k := 0
	for r in range(ROWS.size()):
		for c in range(COLS.size()):
			var rect := Rect2(float(COLS[c][0]), float(ROWS[r][0]), float(COLS[c][1]) - float(COLS[c][0]), float(ROWS[r][1]) - float(ROWS[r][0]))
			root.add_child(_block(rect, c, r, k))
			k += 1
	# manzanas de relleno detrás de las paredes del playón (solo se ven desde adentro)
	for rb in [Rect2(HALF + 4.0, -HALF + 6.0, 170.0, 2.0 * HALF - 12.0), Rect2(-HALF - 174.0, -HALF + 6.0, 170.0, 2.0 * HALF - 12.0), Rect2(-HALF, HALF + 4.0, 2.0 * HALF, 60.0)]:
		root.add_child(_block(rb, -1, -1, k))
		k += 1
	# ── rotonda: isla con árbol, faroles y árboles de las veredas
	root.add_child(_island_and_props())
	root.add_child(_fence_ends())
	# ── conos con física
	cones = ConeField.new()
	cones.setup(_cone_positions())
	root.add_child(cones)
	cone_count = cones.n
	return root

func _disc(b: RefCounted, c: Vector2, r: float, y: float, col: Color, seg: int) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		b.tri(Vector3(c.x, y, c.y), Vector3(c.x + cos(a1) * r, y, c.y + sin(a1) * r), Vector3(c.x + cos(a0) * r, y, c.y + sin(a0) * r), col)

func _zebra_ew(b: RefCounted, xc: float, wd: float, col: Color) -> void:
	# cruces peatonales de la calle norte-sur al llegar a cada calle este-oeste
	for st in STREETS_EW:
		var zc: float = st[0]
		var sw: float = (st[1] as float) * 0.5
		if absf(xc) < 1.0 and absf(zc - RB.y) < 1.0:
			continue # la rotonda no lleva cruces
		var half := wd * 0.5 - SW
		for sgn in [-1.0, 1.0]:
			var zz: float = zc + float(sgn) * (sw + 1.8)
			if zz < -440.0 or zz > -121.0:
				continue
			var x := -half + 0.6
			while x < half - 0.5:
				floor_quad(b, xc + x, zz - 1.4, xc + x + 0.9, zz + 1.4, 0.03, col)
				x += 1.8

## Pared de hormigón con franjas rojas y blancas (un tramo entre dos puntos)
func _wall(b: RefCounted, a: Vector2, c: Vector2, conc: Color, stripe: Color) -> void:
	var d := c - a
	var L := d.length()
	var ang := atan2(d.x, d.y)
	var mid := (a + c) * 0.5
	var xf := Transform3D(Basis(Vector3.UP, ang), Vector3(mid.x, 0.55, mid.y))
	b.box(xf, Vector3(WALL * 2.0, 1.1, L), conc, conc.lightened(0.15))
	var seg := int(L / 4.0)
	for i in seg:
		if i % 2 == 0:
			var t := (float(i) + 0.5) / float(seg) - 0.5
			var p := xf * Vector3(0, 0.0, t * L)
			b.box(Transform3D(Basis(Vector3.UP, ang), Vector3(p.x, 0.62, p.z)), Vector3(WALL * 2.0 + 0.04, 0.5, L / float(seg) * 0.9), stripe)

## Una manzana: relleno bajo, vereda alrededor y una hilera de edificios con la fachada hacia las calles
func _block(rect: Rect2, ci: int, ri: int, seed_k: int) -> MeshInstance3D:
	var b := MB.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + seed_k * 31
	var x0 := rect.position.x
	var z0 := rect.position.y
	var x1 := rect.end.x
	var z1 := rect.end.y
	var pal := [Color(0.92, 0.86, 0.74), Color(0.80, 0.82, 0.86), Color(0.86, 0.72, 0.6), Color(0.74, 0.8, 0.74), Color(0.9, 0.88, 0.84), Color(0.7, 0.68, 0.72), Color(0.88, 0.8, 0.62)]
	# relleno: un cuerpo bajo para que no se vea hueco entre los edificios
	b.box(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 2.5, (z0 + z1) * 0.5)), Vector3(x1 - x0 - 0.4, 5.0, z1 - z0 - 0.4), Color(0.45, 0.43, 0.42), Color(0.38, 0.38, 0.38))
	# qué lados dan a una calle
	var west := ci != 0 and ci >= 0
	var east := ci != COLS.size() - 1 and ci >= 0
	var north := ri != 0 and ri >= 0
	var south := ri != ROWS.size() - 1 and ri >= 0
	if ci < 0: # relleno detrás de las paredes: la fachada mira al playón
		west = rect.position.x > 0.0
		east = rect.end.x < 0.0
		north = false
		south = false
		if rect.position.y > 100.0:
			north = true
	if ri == ROWS.size() - 1 and ci >= 0:
		south = false
	var depth := minf(16.0, minf(x1 - x0, z1 - z0) * 0.5)
	var tall := 0.0 if ci < 0 else 1.0 # las manzanas del centro son más altas
	# sur y norte: hilera completa; este y oeste: entre las dos
	if south:
		_row(b, rng, pal, Vector2(x0, z1), Vector2(x1, z1), 0.0, depth, tall)
	if north:
		_row(b, rng, pal, Vector2(x1, z0), Vector2(x0, z0), PI, depth, tall)
	var ez0 := z0 + (depth if north else 0.0)
	var ez1 := z1 - (depth if south else 0.0)
	if west:
		_row(b, rng, pal, Vector2(x0, ez0), Vector2(x0, ez1), -PI * 0.5, depth, tall)
	if east:
		_row(b, rng, pal, Vector2(x1, ez1), Vector2(x1, ez0), PI * 0.5, depth, tall)
	# veredas (claras y apenas más altas que el asfalto)
	var sc := Color(0.62, 0.62, 0.6)
	var sy := 0.035
	if south:
		floor_quad(b, x0 - SW, z1, x1 + SW, z1 + SW, sy, sc)
	if north:
		floor_quad(b, x0 - SW, z0 - SW, x1 + SW, z0, sy, sc)
	if west:
		floor_quad(b, x0 - SW, z0, x0, z1, sy, sc)
	if east:
		floor_quad(b, x1, z0, x1 + SW, z1, sy, sc)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Props.material("atlas"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 520.0
	return mi

## Hilera de edificios sobre el borde a → c (la fachada mira hacia donde apunta yaw)
func _row(b: RefCounted, rng: RandomNumberGenerator, pal: Array, a: Vector2, c: Vector2, yaw: float, depth: float, tall: float) -> void:
	var L := a.distance_to(c)
	if L < 8.0:
		return
	var cnt := maxi(1, int(round(L / 26.0)))
	var w := L / float(cnt)
	for i in cnt:
		var t := (float(i) + 0.5) / float(cnt)
		var p := a.lerp(c, t)
		var floors := rng.randi_range(3, 6) + int(tall * float(rng.randi_range(0, 4)))
		var style: int = [1, 2, 2, 3, 3, 0][rng.randi() % 6]
		var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y))
		Props.building(b, xf, w - 0.5, depth - 0.5, floors, style, pal[rng.randi() % pal.size()], 0, rng)

## Isla de la rotonda con árbol, faroles a lo largo de las calles y árboles en las veredas
func _island_and_props() -> Node3D:
	var root := Node3D.new()
	var b := MB.new()
	# árbol de la isla (copa redonda)
	var tree := Props.broadleaf(11)
	var tm: ArrayMesh = tree.commit(Props.material("tree"))
	var ti := MeshInstance3D.new()
	ti.mesh = tm
	ti.position = Vector3(RB.x, 0.18, RB.y)
	ti.scale = Vector3(0.9, 0.9, 0.9)
	root.add_child(ti)
	# faroles: dos filas a lo largo de la avenida y de las calles principales
	var lamps: Array = []
	for zz in range(-440 + 20, -121, 40):
		if absf(float(zz) - RB.y) < 24.0:
			continue
		lamps.append([Vector2(-14.0, float(zz)), PI * 0.5])
		lamps.append([Vector2(14.0, float(zz)), -PI * 0.5])
	for st in STREETS_EW:
		var zc: float = st[0]
		for xx in range(-280, 281, 40):
			if absf(float(xx)) < 30.0 or absf(absf(float(xx)) - 150.0) < 20.0:
				continue
			lamps.append([Vector2(float(xx), zc - (st[1] as float) * 0.5 + 1.0), 0.0])
	# faroles del playón: sobre la pared, mirando hacia adentro
	for xx in range(-100, 101, 50):
		if absf(float(xx)) < GATE + 8.0:
			continue
		lamps.append([Vector2(float(xx), -HALF + 1.4), 0.0])
		lamps.append([Vector2(float(xx), HALF - 1.4), PI])
	for zz2 in range(-80, 81, 40):
		lamps.append([Vector2(-HALF + 1.4, float(zz2)), PI * 0.5])
		lamps.append([Vector2(HALF - 1.4, float(zz2)), -PI * 0.5])
	for l in lamps:
		var p: Vector2 = l[0]
		Props.street_lamp(b, Transform3D(Basis(Vector3.UP, float(l[1])), Vector3(p.x, 0.0, p.y)))
		_circle(p.x, p.y, 0.25)
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Props.material("vc"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# árboles de las veredas de la avenida
	var trees: Array = []
	for zz in range(-440 + 40, -121, 40):
		if absf(float(zz) - RB.y) < 30.0:
			continue
		trees.append(Vector2(-13.3, float(zz) + 20.0))
		trees.append(Vector2(13.3, float(zz) + 20.0))
	for p in trees:
		_circle(p.x, p.y, 0.45)
	if not trees.is_empty():
		var tmesh: ArrayMesh = Props.broadleaf(23, true).commit(Props.material("tree"))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tmesh
		mm.instance_count = trees.size()
		for i in trees.size():
			var p: Vector2 = trees[i]
			var s := 0.75 + _rng.randf() * 0.25
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, 0.0, p.y)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	return root

## Barreras a rayas en los finales de las calles (donde termina el mapa)
func _fence_ends() -> Node3D:
	var b := MB.new()
	var red := Color(0.85, 0.16, 0.12)
	var wh := Color(0.95, 0.95, 0.93)
	for st in STREETS_EW:
		var zc: float = st[0]
		var hw: float = (st[1] as float) * 0.5
		for sx in [X0 + 1.0, X1 - 1.0]:
			for k in 6:
				var zz: float = zc - hw + (float(k) + 0.5) * (hw * 2.0 / 6.0)
				b.box(Transform3D(Basis(), Vector3(sx, 0.55, zz)), Vector3(0.5, 1.1, hw * 2.0 / 6.0 * 0.92), red if k % 2 == 0 else wh)
	for st in STREETS_NS:
		var xc: float = st[0]
		var hw: float = (st[1] as float) * 0.5
		for k in 6:
			var xx: float = xc - hw + (float(k) + 0.5) * (hw * 2.0 / 6.0)
			b.box(Transform3D(Basis(), Vector3(xx, 0.55, Z0 + 1.0)), Vector3(hw * 2.0 / 6.0 * 0.92, 1.1, 0.5), red if k % 2 == 0 else wh)
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(Props.material("vc"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root

## Posiciones de los conos: aro de la rotonda, dos slaloms y aro chico del medio
func _cone_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 46:
		var a := TAU * float(i) / 46.0
		out.append(Vector2(cos(a) * 26.0, sin(a) * 26.0))
	for i in 12:
		out.append(Vector2((-3.5 if i % 2 == 0 else 3.5), -100.0 + float(i) * 5.0))
	for i in 12:
		out.append(Vector2((3.5 if i % 2 == 0 else -3.5), 45.0 + float(i) * 5.0))
	for i in 16:
		var a := TAU * float(i) / 16.0
		out.append(Vector2(cos(a) * 8.0, sin(a) * 8.0))
	# puertas dobles a los costados del playón (entrada a una curva larga)
	for i in 10:
		out.append(Vector2(-70.0 + float(i) * 4.0, -70.0))
		out.append(Vector2(-70.0 + float(i) * 4.0, -77.0))
	return out
