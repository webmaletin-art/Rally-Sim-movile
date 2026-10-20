extends "res://game/physics/track_base.gd"
## Pista de drift: un playón grande (240 × 240 m) con rotonda pintada, aros de conos y slalom, dentro de una ciudad chica.
## Por la boca del norte se sale a una avenida que llega a la rotonda de la ciudad (con isla, árboles y faroles) y calles
## con manzanas de edificios, veredas y cruces. Todo es plano; lo que choca (paredes, manzanas, isla, árboles) son
## rectángulos y círculos que consulta push(). Los conos tienen física propia (cone_field.gd).
## Ejes: x a la derecha, z hacia el sur (adelante del auto con yaw 0). El playón está en el origen; la ciudad, al norte (−z).

const MB := preload("res://game/adventure/adv_mesh.gd")
const Props := preload("res://game/adventure/adv_props.gd")
const ConeField := preload("res://game/track/cone_field.gd")
const Tr := preload("res://game/i18n/tr.gd")

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

## ───── Pista de pruebas (Modo de prueba, 20/10/2026) = la misma Drift Plaza mejorada (DriftTrack.new(true)):
##  · el playón se abre al este y al oeste (T_GATE_Z0 a T_GATE_Z1) en dos corredores de tierra que salen a un camino de tierra que da la vuelta por ATRÁS de la ciudad y vuelve al otro lado;
##  · una pista entre los edificios (por las calles) y la de tierra de afuera, como circuitos de una carrera contrarreloj con puertas;
##  · una esquina de pruebas de física con lomos de burro (suroeste) y el punto de nafta, un cuadrado verde (sureste).
const T_X0 := -360.0 # bordes del mundo de pruebas (la ciudad y el playón siguen adentro de X0…X1 y Z0…Z1)
const T_X1 := 360.0
const T_Z0 := -520.0
const T_Z1 := 170.0
const T_GATE_Z0 := 74.0 # abertura al sur de las paredes del playón: el corredor de tierra
const T_GATE_Z1 := 96.0
const T_ROAD_X := 330.0 # camino de tierra de afuera: x = ±T_ROAD_X por el oeste y el este
const T_ROAD_Z := -490.0 # y z = T_ROAD_Z por el norte (atrás de las manzanas)
const FUEL_ZONE := Rect2(322.0, 138.0, 16.0, 16.0) # cuadrado verde (suroeste del camino del este): se frena adentro y se carga nafta
## Lomos de burro: [x0, x1, z0, z1, alto]: cada uno cruza todo el ancho de la esquina de pruebas, con rampas de 1,3 m a cada lado
const BUMPS := [[-356.0, -304.0, 110.0, 113.4, 0.07], [-356.0, -304.0, 122.0, 125.4, 0.10], [-356.0, -304.0, 134.0, 137.4, 0.13], [-356.0, -304.0, 146.0, 149.4, 0.16], [-356.0, -304.0, 158.0, 161.4, 0.20]]

## Manzanas: columnas (x0, x1) y filas (z0, z1). Entre ellas quedan las calles (26 m; 30 m las avenidas).
const COLS := [[-300.0, -163.0], [-137.0, -15.0], [15.0, 137.0], [163.0, 300.0]]
const ROWS := [[-460.0, -443.0], [-417.0, -305.0], [-275.0, -163.0], [-137.0, -121.2]]
## Calles de este-oeste (centro z, ancho) y de norte-sur (centro x, ancho)
const STREETS_EW := [[-150.0, 26.0], [-290.0, 30.0], [-430.0, 26.0]]
const STREETS_NS := [[0.0, 30.0], [-150.0, 26.0], [150.0, 26.0]]

var mode := "asphalt" # (lo piden las funciones que eligen rivales según el piso)
var n := 0 # el minimapa y la sesión miran estos dos (hay una sola "vuelta" ficticia)
var samples: Array = []
var length := 1000.0
var map_lines: Array = [] # polilíneas para el minimapa (x, z)
var _map_base: Array = [] # (pista de pruebas) las calles; el circuito que se corre se suma aparte
var map_bounds := Rect2(-300.0, -460.0, 600.0, 580.0)

var road_mat: StandardMaterial3D
var ground_mat: StandardMaterial3D
var cones: ConeField
var _bx := PackedFloat32Array() # rectángulos: x0, z0, x1, z1
var _cc := PackedFloat32Array() # círculos: x, z, r
var _rng := RandomNumberGenerator.new()
var cone_count := 0
var test_mode := false # pista de pruebas (ver más arriba)
var loop := "" # circuito de la carrera contrarreloj que se corre: "dirt" (el camino de tierra de atrás de la ciudad) o "urban" (entre los edificios); "" = el playón
var loops: Dictionary = {} # nombre → PackedVector2Array: la línea del circuito (cerrada)
var gates: Dictionary = {} # nombre → Array de Vector3(x, z, radio): las puertas por donde hay que pasar, en orden
var _loop_nodes: Dictionary = {}
var _beam: MeshInstance3D # el faro que marca la próxima puerta

func _init(p_test := false) -> void:
	test_mode = p_test
	_rng.seed = 2024
	samples = [Vector3(0, 0, 0)]
	n = 1
	_layout()

# ───────────────────────── interfaz de pista ─────────────────────────
func ground_info(x: float, z: float) -> Vector2:
	if test_mode:
		if x < T_X0 - 2.0 or x > T_X1 + 2.0 or z < T_Z0 - 2.0 or z > T_Z1 + 2.0:
			return Vector2(0.0, 4.0)
		if x >= X0 and x <= X1 and z >= Z0 and z <= Z1:
			if absf(x) > HALF and z >= T_GATE_Z0 and z <= T_GATE_Z1:
				return Vector2(0.0, 1.0) # los corredores de tierra que salen del playón
			return Vector2(0.0, 0.0)
		return Vector2(bump_height(x, z), 1.0) # afuera de la ciudad: tierra (con los lomos de burro de la esquina de pruebas)
	if x < X0 - 2.0 or x > X1 + 2.0 or z < Z0 - 2.0 or z > Z1 + 2.0:
		return Vector2(0.0, 4.0)
	return Vector2(0.0, 0.0)

## Altura del piso por los lomos de burro (perfil trapezoidal: rampas de 1,3 m a los costados y la parte de arriba plana)
func bump_height(x: float, z: float) -> float:
	var h := 0.0
	for b in BUMPS:
		if x < float(b[0]) or x > float(b[1]) or z < float(b[2]) or z > float(b[3]):
			continue
		var ramp := 1.3
		var e := minf(z - float(b[2]), float(b[3]) - z)
		h = maxf(h, float(b[4]) * clampf(e / ramp, 0.0, 1.0))
	return h

func nearest(_x: float, _z: float) -> void:
	pass

## Pose de largada: en el playón, de cara al centro (al norte, yaw π). Los lugares se abren en filas de dos.
func start_pose(slot: int) -> Array:
	if test_mode and loop == "dirt":
		return [70.0 + float(slot) * 7.0, 85.0 + (3.0 if slot % 2 == 0 else -3.0), -PI * 0.5] # sobre la línea de largada del camino de tierra, mirando al oeste
	if test_mode and loop == "urban":
		return [(-3.0 if slot % 2 == 0 else 3.0), -92.0 + float(slot / 2) * 9.0, PI] # en la boca norte del playón, mirando a la avenida
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
	if test_mode:
		# el oeste y el este con una abertura al sur: los corredores de tierra (con paredes bajas a los dos lados hasta el borde de la ciudad)
		_box(-HALF - w, -HALF - w, -HALF + w, T_GATE_Z0)
		_box(-HALF - w, T_GATE_Z1, -HALF + w, HALF + w)
		_box(HALF - w, -HALF - w, HALF + w, T_GATE_Z0)
		_box(HALF - w, T_GATE_Z1, HALF + w, HALF + w)
		for sx in [-1.0, 1.0]:
			var xa := minf(float(sx) * HALF, float(sx) * (X1 + 2.0))
			var xb := maxf(float(sx) * HALF, float(sx) * (X1 + 2.0))
			_box(xa, T_GATE_Z0 - 2.0 * WALL, xb, T_GATE_Z0)
			_box(xa, T_GATE_Z1, xb, T_GATE_Z1 + 2.0 * WALL)
	else:
		_box(-HALF - w, -HALF - w, -HALF + w, HALF + w)
		_box(HALF - w, -HALF - w, HALF + w, HALF + w)
	# borde del mundo
	_box(X0 - 2.0, Z0 - 4.0, X1 + 2.0, Z0)
	if test_mode:
		_box(X0 - 2.0, Z0 - 4.0, X0, T_GATE_Z0)
		_box(X0 - 2.0, T_GATE_Z1, X0, Z1 + 2.0)
		_box(X1, Z0 - 4.0, X1 + 2.0, T_GATE_Z0)
		_box(X1, T_GATE_Z1, X1 + 2.0, Z1 + 2.0)
	else:
		_box(X0 - 2.0, Z0 - 4.0, X0, Z1 + 2.0)
		_box(X1, Z0 - 4.0, X1 + 2.0, Z1 + 2.0)
	_box(X0 - 2.0, Z1, X1 + 2.0, Z1 + 2.0)
	if test_mode:
		# el borde del mundo de pruebas (afuera del camino de tierra)
		_box(T_X0 - 2.0, T_Z0 - 4.0, T_X1 + 2.0, T_Z0)
		_box(T_X0 - 2.0, T_Z0 - 4.0, T_X0, T_Z1 + 2.0)
		_box(T_X1, T_Z0 - 4.0, T_X1 + 2.0, T_Z1 + 2.0)
		_box(T_X0 - 2.0, T_Z1, T_X1 + 2.0, T_Z1 + 2.0)
		_layout_test()
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
	if test_mode:
		map_bounds = Rect2(T_X0, T_Z0, T_X1 - T_X0, T_Z1 - T_Z0)
		map_lines.append(PackedVector2Array([Vector2(-HALF, T_GATE_Z0), Vector2(X0, T_GATE_Z0), Vector2(X0, Z0), Vector2(X1, Z0), Vector2(X1, T_GATE_Z0), Vector2(HALF, T_GATE_Z0)]))
		_map_base = map_lines.duplicate()
		_refresh_map_lines()

# ───────────────────────── pista de pruebas ─────────────────────────
## Los circuitos de la carrera contrarreloj y sus puertas (se arma en _layout, antes de dibujar)
func _layout_test() -> void:
	# camino de tierra de afuera: el rectángulo que da la vuelta por atrás de la ciudad, pasa por los dos corredores y cruza el playón
	var dirt := PackedVector2Array([Vector2(70.0, 85.0), Vector2(-T_ROAD_X, 85.0), Vector2(-T_ROAD_X, T_ROAD_Z), Vector2(T_ROAD_X, T_ROAD_Z), Vector2(T_ROAD_X, 85.0), Vector2(70.0, 85.0)])
	loops["dirt"] = dirt
	gates["dirt"] = _gates_along(dirt, 150.0, 16.0)
	# entre los edificios: una vuelta por las calles alrededor de las manzanas del medio (pasa por la rotonda de la ciudad)
	loops["urban"] = PackedVector2Array([Vector2(0.0, -150.0), Vector2(-150.0, -150.0), Vector2(-150.0, -290.0), Vector2(150.0, -290.0), Vector2(150.0, -150.0), Vector2(0.0, -150.0)])
	gates["urban"] = [Vector3(0.0, -150.0, 12.0), Vector3(-75.0, -150.0, 12.0), Vector3(-150.0, -150.0, 12.0), Vector3(-150.0, -220.0, 12.0), Vector3(-150.0, -290.0, 12.0),
		Vector3(-75.0, -290.0, 12.0), Vector3(0.0, -301.0, 12.0), Vector3(75.0, -290.0, 12.0), Vector3(150.0, -290.0, 12.0), Vector3(150.0, -220.0, 12.0), Vector3(150.0, -150.0, 12.0), Vector3(75.0, -150.0, 12.0)]

## Puertas cada `spacing` metros a lo largo de una línea cerrada (la primera, en el punto de largada)
func _gates_along(path: PackedVector2Array, spacing: float, r: float) -> Array:
	var out: Array = []
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var count := maxi(3, int(round(total / spacing)))
	var step := total / float(count)
	for k in count:
		var want := float(k) * step
		var acc := 0.0
		for i in path.size() - 1:
			var seg := path[i].distance_to(path[i + 1])
			if want <= acc + seg + 0.001:
				var p := path[i].lerp(path[i + 1], (want - acc) / maxf(seg, 0.001))
				out.append(Vector3(p.x, p.y, r))
				break
			acc += seg
	return out

## Largo del circuito (m)
func loop_length(name: String) -> float:
	var path: PackedVector2Array = loops.get(name, PackedVector2Array())
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total

## ¿El punto (x, z) está en el cuadrado verde de la nafta?
func in_fuel_zone(x: float, z: float) -> bool:
	return FUEL_ZONE.has_point(Vector2(x, z))

## El minimapa muestra las calles y sólo el circuito que se corre
func _refresh_map_lines() -> void:
	map_lines = _map_base.duplicate()
	if loops.has(loop):
		map_lines.append(loops[loop])

## Se muestra sólo el circuito que se corre
func set_loop(name: String) -> void:
	loop = name
	for k in _loop_nodes:
		(_loop_nodes[k] as Node3D).visible = str(k) == name
	if _beam != null:
		_beam.visible = false
	if test_mode and not _map_base.is_empty():
		_refresh_map_lines()

## El faro verde marca la próxima puerta (null = ninguna)
func set_next_gate(g) -> void:
	if _beam == null:
		return
	if g == null:
		_beam.visible = false
		return
	var gv: Vector3 = g
	_beam.position = Vector3(gv.x, 14.0, gv.y)
	_beam.visible = true

## Todo lo que se agrega al mundo de pruebas: tierra, lomos de burro, el punto de nafta, las puertas de los circuitos y el borde
func _build_test() -> Node3D:
	var root := Node3D.new()
	root.name = "pruebas"
	var b := MB.new()
	var dirt := Color(0.56, 0.44, 0.31)
	var dirt_dk := Color(0.44, 0.34, 0.24)
	# piso de tierra: cuatro franjas alrededor de la ciudad (el camino de atrás) y los dos corredores del playón
	floor_quad(b, T_X0, T_Z0, X0, T_Z1, 0.0, dirt, 8.0)
	floor_quad(b, X1, T_Z0, T_X1, T_Z1, 0.0, dirt, 8.0)
	floor_quad(b, X0, T_Z0, X1, Z0, 0.0, dirt, 8.0)
	floor_quad(b, X0, Z1, X1, T_Z1, 0.0, dirt_dk, 8.0)
	floor_quad(b, X0, T_GATE_Z0, -HALF, T_GATE_Z1, 0.013, dirt, 8.0)
	floor_quad(b, HALF, T_GATE_Z0, X1, T_GATE_Z1, 0.013, dirt, 8.0)
	# huellas de las ruedas a lo largo del camino de tierra (afuera del playón)
	var pieces: Array = [PackedVector2Array([Vector2(-HALF - 3.0, 85.0), Vector2(-T_ROAD_X, 85.0), Vector2(-T_ROAD_X, T_ROAD_Z), Vector2(T_ROAD_X, T_ROAD_Z), Vector2(T_ROAD_X, 85.0), Vector2(HALF + 3.0, 85.0)])]
	for pc in pieces:
		var pp: PackedVector2Array = pc
		for off in [-2.8, 2.8]:
			for i in pp.size() - 1:
				var d := (pp[i + 1] - pp[i]).normalized()
				var nn := Vector2(-d.y, d.x) * float(off)
				line(b, pp[i] + nn, pp[i + 1] + nn, 1.3, 0.025, dirt_dk)
	# esquina de pruebas de física (suroeste): una franja pintada y los lomos de burro
	var amber := Color(0.96, 0.78, 0.12)
	var dark := Color(0.16, 0.16, 0.17)
	for bp in BUMPS:
		var x0: float = bp[0]
		var x1: float = bp[1]
		var z0: float = bp[2]
		var z1: float = bp[3]
		var h: float = bp[4]
		var rp := 1.3
		var base := Color(0.34, 0.34, 0.36)
		b.quad(Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), Vector3(x1, h, z0 + rp), Vector3(x0, h, z0 + rp), base)
		b.quad(Vector3(x0, h, z1 - rp), Vector3(x1, h, z1 - rp), Vector3(x1, 0.0, z1), Vector3(x0, 0.0, z1), base)
		var sx := x0
		var flip := false
		while sx < x1 - 0.01:
			var ex := minf(sx + 3.0, x1)
			var col := amber if flip else dark
			b.quad(Vector3(sx, h + 0.012, z0 + rp), Vector3(ex, h + 0.012, z0 + rp), Vector3(ex, h + 0.012, z1 - rp), Vector3(sx, h + 0.012, z1 - rp), col)
			b.quad(Vector3(sx, 0.012, z0), Vector3(ex, 0.012, z0), Vector3(ex, h + 0.012, z0 + rp), Vector3(sx, h + 0.012, z0 + rp), col)
			b.quad(Vector3(sx, h + 0.012, z1 - rp), Vector3(ex, h + 0.012, z1 - rp), Vector3(ex, 0.012, z1), Vector3(sx, 0.012, z1), col)
			sx = ex
			flip = not flip
	# punto de nafta (sureste): el cuadrado verde para frenar adentro
	var green := Color(0.12, 0.62, 0.28)
	var fz := FUEL_ZONE
	floor_quad(b, fz.position.x - 2.0, fz.position.y - 2.0, fz.end.x + 2.0, fz.end.y + 2.0, 0.026, Color(0.9, 0.9, 0.88), 8.0)
	floor_quad(b, fz.position.x, fz.position.y, fz.end.x, fz.end.y, 0.032, green, 8.0)
	for k in 4:
		var yy := fz.position.y + 2.0 + float(k) * 4.0
		line(b, Vector2(fz.position.x + 1.5, yy), Vector2(fz.end.x - 1.5, yy), 0.18, 0.036, Color(0.85, 0.95, 0.85))
	var mi := MeshInstance3D.new()
	mi.mesh = b.commit(road_mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# el surtidor y el techito (con colisión: no se atraviesa) y su cartel
	var pb := MB.new()
	var px := fz.position.x + fz.size.x * 0.5
	var pz := fz.position.y - 1.2
	pb.box(Transform3D(Basis(), Vector3(px, 0.9, pz)), Vector3(1.0, 1.8, 0.7), Color(0.88, 0.2, 0.16), Color(0.95, 0.95, 0.93))
	pb.box(Transform3D(Basis(), Vector3(px, 1.35, pz - 0.38)), Vector3(0.7, 0.4, 0.06), Color(0.1, 0.1, 0.12))
	for sx2 in [-2.4, 2.4]:
		pb.box(Transform3D(Basis(), Vector3(px + float(sx2), 2.0, pz)), Vector3(0.22, 4.0, 0.22), Color(0.78, 0.78, 0.8))
	pb.box(Transform3D(Basis(), Vector3(px, 4.1, pz)), Vector3(6.2, 0.3, 3.2), Color(0.9, 0.9, 0.9), Color(0.2, 0.62, 0.3))
	_box(px - 0.5, pz - 0.35, px + 0.5, pz + 0.35)
	# bordes del mundo de pruebas y pilones
	var conc := Color(0.62, 0.62, 0.6)
	var stripe := Color(0.86, 0.18, 0.14)
	_wall(pb, Vector2(T_X0, T_Z0), Vector2(T_X1, T_Z0), conc, stripe)
	_wall(pb, Vector2(T_X1, T_Z0), Vector2(T_X1, T_Z1), conc, stripe)
	_wall(pb, Vector2(T_X1, T_Z1), Vector2(T_X0, T_Z1), conc, stripe)
	_wall(pb, Vector2(T_X0, T_Z1), Vector2(T_X0, T_Z0), conc, stripe)
	for sx3 in [-1.0, 1.0]:
		var xa := float(sx3) * HALF
		var xb := float(sx3) * X1
		_wall(pb, Vector2(xa, T_GATE_Z0 - WALL), Vector2(xb, T_GATE_Z0 - WALL), conc, stripe)
		_wall(pb, Vector2(xa, T_GATE_Z1 + WALL), Vector2(xb, T_GATE_Z1 + WALL), conc, stripe)
	var pmi := MeshInstance3D.new()
	pmi.mesh = pb.commit(Props.material("vc"))
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pmi)
	var lb := Label3D.new()
	lb.text = Tr.t("⛽ NAFTA")
	lb.font_size = 72
	lb.pixel_size = 0.03
	lb.shaded = false
	lb.double_sided = true
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED # (se lee desde cualquier lado: el cuadrado se encuentra viniendo por cualquiera de los caminos)
	lb.modulate = Color(1, 1, 1, 0.95)
	lb.position = Vector3(px, 5.3, pz)
	root.add_child(lb)
	# puertas de cada circuito (anillos pintados con banderas en los costados); se muestra sólo el que se corre
	for nm in ["dirt", "urban"]:
		var gb := MB.new()
		var lroot := Node3D.new()
		lroot.name = "circuito_" + nm
		var gl: Array = gates[nm]
		for gi in gl.size():
			var g: Vector3 = gl[gi]
			var col := Color(1.0, 0.55, 0.1) if gi > 0 else Color(0.95, 0.95, 0.95)
			ring(gb, Vector2(g.x, g.y), g.z, 0.5, 0.04, col, 36)
			# banderas: dos postes a los costados del anillo (sobre la línea que va a la puerta siguiente)
			var nxt: Vector3 = gl[(gi + 1) % gl.size()]
			var dir := Vector2(nxt.x - g.x, nxt.y - g.y).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			for sd in [-1.0, 1.0]:
				var fp := Vector2(g.x, g.y) + nrm * g.z * float(sd)
				gb.cyl(Transform3D(Basis(), Vector3(fp.x, 0, fp.y)), 0.08, 0.08, 3.2, 6, col, true, col)
				gb.box(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(fp.x, 2.9, fp.y)), Vector3(0.05, 0.5, 0.9), col)
		var gmi := MeshInstance3D.new()
		gmi.mesh = gb.commit(road_mat)
		gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lroot.add_child(gmi)
		lroot.visible = nm == loop # (se elige antes de armar el mundo: race.gd lo deja en track.loop)
		root.add_child(lroot)
		_loop_nodes[nm] = lroot
	# el faro que marca la próxima puerta
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.4
	cm.height = 28.0
	cm.radial_segments = 12
	_beam.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.2, 1.0, 0.45, 0.35)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam.material_override = bm
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	root.add_child(_beam)
	return root

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
	if test_mode:
		_wall(pb, Vector2(HALF, -HALF), Vector2(HALF, T_GATE_Z0), conc, stripe)
		_wall(pb, Vector2(HALF, T_GATE_Z1), Vector2(HALF, HALF), conc, stripe)
		_wall(pb, Vector2(HALF, HALF), Vector2(-HALF, HALF), conc, stripe)
		_wall(pb, Vector2(-HALF, HALF), Vector2(-HALF, T_GATE_Z1), conc, stripe)
		_wall(pb, Vector2(-HALF, T_GATE_Z0), Vector2(-HALF, -HALF), conc, stripe)
	else:
		_wall(pb, Vector2(HALF, -HALF), Vector2(HALF, HALF), conc, stripe)
		_wall(pb, Vector2(HALF, HALF), Vector2(-HALF, HALF), conc, stripe)
		_wall(pb, Vector2(-HALF, HALF), Vector2(-HALF, -HALF), conc, stripe)
	# pilones de la boca
	for sx in [-GATE, GATE]:
		pb.cyl(Transform3D(Basis(), Vector3(sx, 0, -HALF)), 0.9, 0.9, 1.6, 8, Color(0.9, 0.9, 0.88), true, Color(0.9, 0.2, 0.15))
	if test_mode:
		for px in [-HALF, HALF]:
			for pz in [T_GATE_Z0, T_GATE_Z1]:
				pb.cyl(Transform3D(Basis(), Vector3(px, 0, pz)), 0.9, 0.9, 1.6, 8, Color(0.9, 0.9, 0.88), true, Color(0.9, 0.2, 0.15))
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
	var fills := [Rect2(HALF + 4.0, -HALF + 6.0, 170.0, 2.0 * HALF - 12.0), Rect2(-HALF - 174.0, -HALF + 6.0, 170.0, 2.0 * HALF - 12.0), Rect2(-HALF, HALF + 4.0, 2.0 * HALF, 60.0)]
	if test_mode: # (hasta antes del corredor de tierra: no tapan el camino)
		fills = [Rect2(HALF + 4.0, -HALF + 6.0, 170.0, T_GATE_Z0 - 2.0 + HALF - 6.0), Rect2(-HALF - 174.0, -HALF + 6.0, 170.0, T_GATE_Z0 - 2.0 + HALF - 6.0), Rect2(-HALF, HALF + 4.0, 2.0 * HALF, 60.0)]
	for rb in fills:
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
	if test_mode:
		root.add_child(_build_test())
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
	# (pista de pruebas) los rellenos que bordean los corredores de tierra muestran fachada del lado del corredor (antes era una caja lisa)
	var corridor_face := test_mode and ci < 0 and rect.position.y < 0.0 and absf(rect.end.y - (T_GATE_Z0 - 2.0)) < 0.5
	# sur y norte: hilera completa; este y oeste: entre las dos
	if south or corridor_face:
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
		if test_mode and float(zz2) > T_GATE_Z0 - 6.0 and float(zz2) < T_GATE_Z1 + 6.0:
			continue # (en la abertura del corredor de tierra)
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
