extends Node3D
## Conos de tránsito con física simple: los autos los golpean, salen volando, rebotan y quedan tirados donde caen.
## Un solo MultiMesh dibuja todos (una llamada de dibujo); solo se mueven los que están "despiertos".

const MB := preload("res://game/adventure/adv_mesh.gd")

const CONE_H := 0.75
const BASE := 0.23 # medio lado de la base cuadrada
const HIT_R := 0.30 # radio de choque del cono (auto: círculos de ~1 m)

var n := 0
var home: PackedVector2Array
var pos: PackedVector2Array
var vel: PackedVector2Array
var yv := PackedFloat32Array() # altura y velocidad vertical
var y := PackedFloat32Array()
var ang := PackedFloat32Array() # inclinación (0 parado, π/2 acostado)
var wv := PackedFloat32Array() # velocidad de giro
var dir := PackedVector2Array() # hacia dónde cae
var state := PackedByteArray() # 0 parado · 1 en movimiento · 2 tirado
var hits := 0 # conos golpeados en total
var new_hits := 0 # golpeados desde la última lectura (los lee la sesión)
var mm: MultiMesh
var mmi: MultiMeshInstance3D
var _awake: Array = []

static var _mesh: ArrayMesh

static func cone_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var b := MB.new()
	var orange := Color(1.0, 0.36, 0.06)
	b.box(Transform3D(Basis(), Vector3(0, 0.025, 0)), Vector3(BASE * 2.0, 0.05, BASE * 2.0), Color(0.07, 0.07, 0.08))
	b.cyl(Transform3D(Basis(), Vector3(0, 0.05, 0)), 0.165, 0.11, 0.34, 10, orange, false)
	b.cyl(Transform3D(Basis(), Vector3(0, 0.39, 0)), 0.11, 0.075, 0.12, 10, Color(0.96, 0.96, 0.94), false)
	b.cyl(Transform3D(Basis(), Vector3(0, 0.51, 0)), 0.075, 0.03, 0.24, 10, orange, true)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.7
	_mesh = b.commit(m)
	return _mesh

func setup(list: PackedVector2Array) -> void:
	n = list.size()
	home = list.duplicate()
	pos = list.duplicate()
	vel.resize(n)
	yv.resize(n)
	y.resize(n)
	ang.resize(n)
	wv.resize(n)
	dir.resize(n)
	state.resize(n)
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone_mesh()
	mm.instance_count = n
	mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	reset()

func reset() -> void:
	_awake.clear()
	hits = 0
	new_hits = 0
	for i in n:
		pos[i] = home[i]
		vel[i] = Vector2.ZERO
		yv[i] = 0.0
		y[i] = 0.0
		ang[i] = 0.0
		wv[i] = 0.0
		state[i] = 0
		_write(i)

func _write(i: int) -> void:
	var d := dir[i]
	if d.length_squared() < 1e-6:
		d = Vector2(0, 1)
	# eje horizontal perpendicular a la dirección de caída
	var axis := Vector3(d.y, 0.0, -d.x).normalized()
	var th := ang[i]
	var bs := Basis(axis, th)
	var ground := 0.0 if th < 0.01 else BASE * absf(sin(th)) * 1.1
	mm.set_instance_transform(i, Transform3D(bs, Vector3(pos[i].x, y[i] + ground, pos[i].y)))

## cars: lista de Car (con snap). dt: tiempo del cuadro.
func update(dt: float, cars: Array) -> void:
	if n == 0:
		return
	# choques con los autos (tres círculos por auto, como los choques entre autos)
	for c in cars:
		var sn = c.snap
		var sp := sqrt(sn.vx * sn.vx + sn.vz * sn.vz)
		var Lw: float = c.phys.V.wheelBase + 1.5
		var r: float = maxf(0.95, c.phys.V.trackF * 0.5 + 0.05)
		var ya: float = sn.yaw
		var s := sin(ya)
		var co := cos(ya)
		for k in 3:
			var kk := float(k - 1)
			var cx: float = sn.px + s * kk * Lw * 0.34
			var cz: float = sn.pz + co * kk * Lw * 0.34
			for i in n:
				if state[i] == 2 and pos[i].distance_squared_to(Vector2(cx, cz)) > 9.0:
					continue
				var dx := pos[i].x - cx
				var dz := pos[i].y - cz
				var rr := r + HIT_R
				var d2 := dx * dx + dz * dz
				if d2 >= rr * rr:
					continue
				var d := sqrt(d2)
				var nx := dx / d if d > 0.001 else 0.0
				var nz := dz / d if d > 0.001 else 1.0
				if state[i] == 0 and sp > 0.8:
					hits += 1
					new_hits += 1
				# el cono sale despedido: velocidad del auto en ese punto más un empujón hacia afuera
				var kick := maxf(sp, 3.0)
				vel[i] = Vector2(sn.vx * 1.05 + nx * kick * 0.45, sn.vz * 1.05 + nz * kick * 0.45)
				yv[i] = clampf(sp * 0.22, 1.2, 6.5)
				if y[i] < 0.01:
					y[i] = 0.02
				dir[i] = vel[i].normalized() if vel[i].length_squared() > 0.01 else Vector2(nx, nz)
				wv[i] = clampf(sp * 0.9, 4.0, 22.0)
				pos[i] += Vector2(nx, nz) * maxf(0.0, rr - d) # sale del auto
				if state[i] != 1:
					state[i] = 1
					_awake.append(i)
	# física de los que están en movimiento
	var keep: Array = []
	for i in _awake:
		var done := _step(i, dt)
		_write(i)
		if not done:
			keep.append(i)
	_awake = keep

func _step(i: int, dt: float) -> bool:
	pos[i] += vel[i] * dt
	var onground: bool = y[i] <= 0.0
	if not onground:
		yv[i] -= 9.81 * dt
		y[i] += yv[i] * dt
		ang[i] += wv[i] * dt
		if y[i] <= 0.0:
			y[i] = 0.0
			if yv[i] < -1.5:
				yv[i] = -yv[i] * 0.32 # rebota
				wv[i] *= 0.6
				vel[i] *= 0.82
				y[i] = 0.001
			else:
				yv[i] = 0.0
	else:
		var spd := vel[i].length()
		if spd > 0.001:
			vel[i] = vel[i] / spd * maxf(0.0, spd * (1.0 - 1.2 * dt) - 7.0 * dt) # roce con el asfalto
		# rueda un poco hasta quedar acostado
		ang[i] += wv[i] * dt * 0.4
		wv[i] *= maxf(0.0, 1.0 - 2.6 * dt)
		if vel[i].length() < 0.25 and wv[i] < 0.5:
			# queda en una de las posiciones de reposo: de pie, de costado o al revés
			var q := roundf(ang[i] / (PI * 0.5))
			var rest := q * (PI * 0.5)
			rest = fposmod(rest, TAU)
			if rest > PI * 1.2:
				rest = TAU - rest
			ang[i] = clampf(rest, 0.0, PI)
			vel[i] = Vector2.ZERO
			state[i] = 2
			return true
	return false
