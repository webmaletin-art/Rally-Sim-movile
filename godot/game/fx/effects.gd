extends Node3D
## Humo de neumáticos, polvo y piedritas, y marcas de frenada. Portado de la clase Effects de la versión HTML
## (js/main.js): mismas reglas de emisión por rueda (patinaje, superficie suelta), mismos colores y tiempos de vida.
## Las partículas son un solo MultiMesh de cuadritos que miran a la cámara (una llamada de dibujo); la simulación de
## cada partícula es sencilla y con tope de cantidad según la calidad, para que no pese en teléfonos de gama baja.

const CarSnapshot := preload("res://game/car/car_snapshot.gd")

const N := 220
const MARKS := 500

var cap := 110 # tope de partículas vivas (70 baja · 110 media · 150 alta)
var qk := 0.45 # factor de emisión por calidad
var track: RefCounted

var _pos := PackedFloat32Array()
var _vel := PackedFloat32Array()
var _col := PackedFloat32Array()
var _alpha := PackedFloat32Array()
var _a0 := PackedFloat32Array()
var _size := PackedFloat32Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _grow := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _next := 0
var _buf := PackedFloat32Array()
var _mm: MultiMesh
var _marks: MultiMesh
var _mk := 0
# por auto (índice) y por rueda: acumulador de emisión y última posición de la marca
var _acc := {}
var _last := {}

func setup(p_track: RefCounted) -> void:
	track = p_track
	for a in [_pos, _vel, _col]:
		a.resize(N * 3)
	for a in [_alpha, _a0, _size, _life, _max, _grow, _grav]:
		a.resize(N)
	_buf.resize(N * 16)
	# nubes de humo/polvo: cuadritos suaves que miran a la cámara
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var tex := GradientTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	tex.gradient = g
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.disable_receive_shadows = true
	quad.material = m
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = quad
	_mm.instance_count = N
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = _mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 4000.0 # las partículas están en todo el mundo: no se recortan por cuadro
	add_child(inst)
	# marcas de frenada: tiras negras pegadas al piso
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var mm2 := StandardMaterial3D.new()
	mm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm2.albedo_color = Color(0.04, 0.04, 0.04, 0.42)
	mm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm2.no_depth_test = false
	plane.material = mm2
	_marks = MultiMesh.new()
	_marks.transform_format = MultiMesh.TRANSFORM_3D
	_marks.mesh = plane
	_marks.instance_count = MARKS
	var hide := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -999, 0))
	for i in MARKS:
		_marks.set_instance_transform(i, hide)
	var inst2 := MultiMeshInstance3D.new()
	inst2.multimesh = _marks
	inst2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst2.extra_cull_margin = 4000.0
	add_child(inst2)

func set_quality(level: String) -> void:
	cap = 70 if level == "baja" else (150 if level == "alta" else 110)
	qk = 0.3 if level == "baja" else (0.6 if level == "alta" else 0.45)

func reset() -> void:
	_life.fill(0.0)
	_alpha.fill(0.0)
	_acc.clear()
	_last.clear()
	var hide := Transform3D(Basis().scaled(Vector3.ZERO), Vector3(0, -999, 0))
	for i in MARKS:
		_marks.set_instance_transform(i, hide)
	_mk = 0

func _spawn(x: float, y: float, z: float, vx: float, vy: float, vz: float, r: float, g: float, b: float, a: float, size: float, life: float, grow: float, grav: float) -> void:
	var i := _next % cap
	_next = (i + 1) % cap
	_pos[i * 3] = x
	_pos[i * 3 + 1] = y
	_pos[i * 3 + 2] = z
	_vel[i * 3] = vx
	_vel[i * 3 + 1] = vy
	_vel[i * 3 + 2] = vz
	_col[i * 3] = r
	_col[i * 3 + 1] = g
	_col[i * 3 + 2] = b
	_a0[i] = a
	_alpha[i] = a
	_size[i] = size
	_life[i] = life
	_max[i] = life
	_grow[i] = grow
	_grav[i] = grav

## Emite humo/polvo/marcas de un auto a partir de la foto de su física. key = índice del auto; tire_w = ancho de la cubierta.
func emit_from(key: int, s: CarSnapshot, dt: float, tire_w: float) -> void:
	var fx := sin(s.yaw)
	var fz := cos(s.yaw)
	var lx := cos(s.yaw)
	var lz := -sin(s.yaw)
	if not _acc.has(key):
		_acc[key] = [0.0, 0.0, 0.0, 0.0]
		_last[key] = [null, null, null, null]
	var acc: Array = _acc[key]
	var last: Array = _last[key]
	for i in 4:
		var o := i * 8
		var f := s.wheel_fx
		if f[o] < 0.5: # sin contacto
			last[i] = null
			continue
		var surf := int(f[o + 1])
		var vl := f[o + 2]
		var kappa := f[o + 3]
		var alp := f[o + 4]
		var x := f[o + 5]
		var z := f[o + 6]
		var y := f[o + 7] + 0.08
		var left := (i % 2) == 0
		var loose := surf != 0
		var sp := absf(vl)
		var sl := maxf(0.0, absf(kappa) - 0.06) + maxf(0.0, absf(alp) - 0.09)
		var side := 1.0 if left else -1.0
		var rate := 0.0
		var kind := 0
		if loose:
			rate = sp * 0.9 + sl * 90.0
			kind = 1
		elif sl > 0.14:
			rate = (sl - 0.14) * 120.0 * minf(1.0, sp / 3.0 + 0.3)
			kind = 2
		acc[i] = minf(acc[i] + rate * qk * dt, 2.0)
		var n_s := 0
		while acc[i] >= 1.0 and n_s < 2:
			n_s += 1
			acc[i] -= 1.0
			var back := -(1.5 + sp * 0.25 + absf(kappa) * 6.0)
			var up := 0.6 + randf() * 1.2
			if kind == 1:
				var c := 0.55 + randf() * 0.1
				_spawn(x + (randf() - 0.5) * 0.3, y, z + (randf() - 0.5) * 0.3,
					fx * back + lx * side * (randf() * 1.5) + (randf() - 0.5), up, fz * back + lz * side * (randf() * 1.5) + (randf() - 0.5),
					c * 0.86, c * 0.72, c * 0.55, 0.42, 0.7 + randf() * 0.5, 0.9 + randf() * 0.7, 1.6, -0.4)
				if randf() < 0.18:
					_spawn(x, y, z, fx * back * 0.8 + (randf() - 0.5) * 2.0, 1.5 + randf() * 2.0, fz * back * 0.8 + (randf() - 0.5) * 2.0,
						0.18, 0.15, 0.12, 1.0, 0.07, 0.6, 0.0, -9.8)
			else:
				var c2 := 0.78 + randf() * 0.1
				_spawn(x + (randf() - 0.5) * 0.3, y + 0.1, z + (randf() - 0.5) * 0.3,
					fx * back * 0.3 + (randf() - 0.5) * 0.8, 0.5 + randf() * 0.5, fz * back * 0.3 + (randf() - 0.5) * 0.8,
					c2, c2, c2 * 1.02, 0.36, 0.8 + randf() * 0.6, 1.4 + randf(), 2.2, 0.25)
		# marcas de frenada: solo en asfalto y patinando fuerte
		var mark := (not loose) and sl > 0.22
		if mark and last[i] != null:
			var L: Vector3 = last[i]
			var dx := x - L.x
			var dz := z - L.z
			var dd := sqrt(dx * dx + dz * dz)
			if dd > 0.35 and dd < 3.0:
				var y1 := _ground(x, z)
				var b := Basis.from_euler(Vector3(-atan2(y1 - L.y, dd), atan2(dx, dz), 0.0), EULER_ORDER_YXZ)
				b = b * Basis.from_scale(Vector3(tire_w * 0.9, 1.0, sqrt(dd * dd + (y1 - L.y) * (y1 - L.y))))
				_marks.set_instance_transform(_mk, Transform3D(b, Vector3((x + L.x) * 0.5, (y1 + L.y) * 0.5 + 0.06, (z + L.z) * 0.5)))
				_mk = (_mk + 1) % MARKS
				last[i] = Vector3(x, y1, z)
			elif dd >= 3.0:
				last[i] = Vector3(x, _ground(x, z), z)
		elif mark:
			last[i] = Vector3(x, _ground(x, z), z)
		else:
			last[i] = null

func _ground(x: float, z: float) -> float:
	return track.ground_y(x, z) if track != null else 0.0

## Avanza las partículas y las sube al MultiMesh. cam_pos: posición de la cámara (las que quedan pegadas a la lente se desvanecen)
func update(dt: float, cam_pos: Vector3) -> void:
	var drag := exp(-dt * 1.6)
	for i in N:
		var a := 0.0
		if _life[i] > 0.0:
			_life[i] -= dt
			var k := _life[i] / _max[i]
			_vel[i * 3 + 1] += _grav[i] * dt
			_vel[i * 3] *= drag
			_vel[i * 3 + 2] *= drag
			_pos[i * 3] += _vel[i * 3] * dt
			_pos[i * 3 + 1] += _vel[i * 3 + 1] * dt
			_pos[i * 3 + 2] += _vel[i * 3 + 2] * dt
			_size[i] = minf(4.5, _size[i] + _grow[i] * dt * 0.9)
			a = maxf(0.0, _a0[i] * k)
			# se desvanece pegada a la cámara (no tapa la pantalla)
			var dx := _pos[i * 3] - cam_pos.x
			var dy := _pos[i * 3 + 1] - cam_pos.y
			var dz := _pos[i * 3 + 2] - cam_pos.z
			a *= smoothstep(1.2, 4.5, sqrt(dx * dx + dy * dy + dz * dz))
		var o := i * 16
		var s := _size[i] if a > 0.003 else 0.0
		_buf[o] = s
		_buf[o + 1] = 0.0
		_buf[o + 2] = 0.0
		_buf[o + 3] = _pos[i * 3]
		_buf[o + 4] = 0.0
		_buf[o + 5] = s
		_buf[o + 6] = 0.0
		_buf[o + 7] = _pos[i * 3 + 1]
		_buf[o + 8] = 0.0
		_buf[o + 9] = 0.0
		_buf[o + 10] = s
		_buf[o + 11] = _pos[i * 3 + 2]
		_buf[o + 12] = _col[i * 3]
		_buf[o + 13] = _col[i * 3 + 1]
		_buf[o + 14] = _col[i * 3 + 2]
		_buf[o + 15] = a
	_mm.buffer = _buf
