extends "res://game/track/drift_track.gd"
## La pista de Dream City (mundo abierto): las calles son un laberinto. Todo lo que no es calle o vereda son edificios: ahí hay una pared invisible. El suelo de cada
## calle sale de la capa de la ciudad (city_layout.gd). Hereda de la pista de drift (comparten cómo chocan los autos: track.push) pero no tiene playón ni conos de slalom.
## Las consultas son puras, así que los hilos de la física pueden llamarlas a la vez.

const CityLayout := preload("res://game/city/city_layout.gd")
const CityWorld := preload("res://game/city/city_world.gd")

var city: CityLayout
var world_node: Node3D
var props := {} # Vector2i (16 m) -> PackedFloat32Array [x, z, r, id, …] de cosas que se pueden golpear (postes, árboles, semáforos)
var _prop_alive := {} # id -> true
var broken := {} # id -> Vector2 (hacia dónde cayó): lo roto queda tirado y ya no choca
var _fresh := PackedInt32Array() # rotos desde la última vez que el mundo los miró
var _dyn := PackedFloat32Array() # círculos de choque que se mueven (autos del tránsito): x, z, r, …
var _mx := Mutex.new() # la física corre en hilos aparte: los objetos se tocan de a uno

func _init() -> void:
	city = CityLayout.new()
	city.build()
	cones = ConeField.new()
	cones.setup(PackedVector2Array())
	samples = [Vector3(0, 0, 0)]
	n = 1
	map_bounds = Rect2(-RURAL_END_X, -RURAL_END_X, RURAL_END_X * 2.0, RURAL_END_X * 2.0)

const RURAL_END_X := 2300.0

func _layout() -> void:
	pass # la plaza de drift no se arma: la ciudad viene de CityLayout

# ───────────────────────── interfaz de pista ─────────────────────────
func ground_info(x: float, z: float) -> Vector2:
	var pr := city.probe(x, z)
	if pr[0] > -0.05:
		return Vector2(float(pr[4]), 0.0 if float(pr[1]) <= float(pr[5]) else 2.0)
	return Vector2(city.height(x, z), 4.0)

## Cámara: de a hacia b (en el plano), ¿qué parte del camino está libre? 1 = toda; menos: ahí empiezan los edificios (fuera del corredor de la calle, que no sea ruta ni campo)
func camera_clear(a: Vector2, b: Vector2) -> float:
	var d := a.distance_to(b)
	if d < 0.5:
		return 1.0
	var n := int(ceil(d / 1.5))
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / float(n))
		var pr := city.probe(q.x, q.y)
		if float(pr[0]) < -0.2 and int(pr[6]) >= 0:
			if str((city.roads[int(pr[6])] as Dictionary)["kind"]) in ["rural", "shortcut"]:
				continue
			return maxf(0.0, (float(i) - 1.0) / float(n))
	return 1.0

func ground_smooth(x: float, z: float) -> float:
	return ground_info(x, z).x

var spawn_i := 0 # cuál de los estacionamientos (city.spawns) toca esta vez: el jugador siempre aparece dentro de uno
## Pose de largada: dentro de un estacionamiento (subterráneo o de planta baja). Los lugares siguientes se abren en fila hacia el costado.
func start_pose(slot: int) -> Array:
	var sp: Array = city.spawns[spawn_i % city.spawns.size()]
	var side := -1.0 if slot % 2 == 0 else 1.0
	var yaw := float(sp[2])
	var lat := Vector2(cos(yaw), -sin(yaw)) # a la derecha del rumbo
	var q := Vector2(float(sp[0]), float(sp[1])) + lat * side * 3.0 * float(1 + slot / 2) - Vector2(sin(yaw), cos(yaw)) * float(slot / 2) * 4.0
	return [q.x, q.y, yaw]

## Empuja un círculo (x, z, r) hacia adentro del corredor de la calle y lo saca de los postes: (nx, nz, profundidad)
func push(x: float, z: float, r: float) -> Vector3:
	_mx.lock()
	var res := _push_locked(x, z, r)
	_mx.unlock()
	return res

func _push_locked(x: float, z: float, r: float) -> Vector3:
	var pr := city.probe(x, z)
	var best := Vector3.ZERO
	if pr[6] >= 0.0:
		var pen := r - float(pr[0])
		if pen > 0.0:
			best = Vector3(float(pr[2]), float(pr[3]), minf(pen, 6.0))
	if not city.drift.is_empty(): # la pared invisible de la plaza de drift (el cerco), con una abertura donde entra la ruta
		var dc: Vector2 = city.drift["c"]
		var dd := Vector2(x, z) - dc
		var dl := dd.length()
		var rr: float = city.drift["r"]
		if dl > rr - 3.0 - r and dl < rr + 3.0 + r and dl > 0.001:
			var u := dd / dl
			if u.dot(-(city.drift["dir"] as Vector2)) < CityLayout.DRIFT_GATE:
				var pen := dl + r - (rr - 1.0) if dl < rr else (rr + 1.0) - (dl - r)
				if pen > best.z:
					best = Vector3(-u.x if dl < rr else u.x, -u.y if dl < rr else u.y, pen)
	var di := 0
	while di < _dyn.size(): # autos del tránsito: sólidos (no se rompen)
		var ox2 := x - _dyn[di]
		var oz2 := z - _dyn[di + 1]
		var rs2 := r + _dyn[di + 2]
		di += 3
		var e22 := ox2 * ox2 + oz2 * oz2
		if e22 < rs2 * rs2:
			var e2 := sqrt(e22)
			if rs2 - e2 > best.z:
				best = Vector3(ox2 / e2 if e2 > 0.001 else 1.0, oz2 / e2 if e2 > 0.001 else 0.0, rs2 - e2)
	var kx := int(floor(x / 16.0))
	var kz := int(floor(z / 16.0))
	var hit_id := -1
	var hit_pos := Vector2.ZERO
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var k := Vector2i(kx + dx, kz + dz)
			if not props.has(k):
				continue
			var arr: PackedFloat32Array = props[k]
			var i := 0
			while i < arr.size():
				var ox := x - arr[i]
				var oz := z - arr[i + 1]
				var rs := r + arr[i + 2]
				var pid := int(arr[i + 3])
				var px := arr[i]
				var pz := arr[i + 1]
				i += 4
				var e2 := ox * ox + oz * oz
				if e2 >= rs * rs:
					continue
				var e := sqrt(e2)
				if rs - e > best.z:
					best = Vector3(ox / e if e > 0.001 else 1.0, oz / e if e > 0.001 else 0.0, rs - e)
					hit_id = pid
					hit_pos = Vector2(px, pz)
	if hit_id >= 0 and best.z > 0.0 and hit_id < city.prop_type.size() and int(city.prop_type[hit_id]) < 4: # el monumento, los pilares, los autos estacionados y los portones de las salidas no se rompen
		# el primer golpe lo tira (el auto lo siente una vez) y deja de ser obstáculo
		_break_locked(hit_id, hit_pos, Vector2(-best.x, -best.y))
	return best

func _break_locked(id: int, pos: Vector2, dir: Vector2) -> void:
	var k := Vector2i(int(floor(pos.x / 16.0)), int(floor(pos.y / 16.0)))
	if props.has(k):
		var arr: PackedFloat32Array = props[k]
		var out := PackedFloat32Array()
		var i := 0
		while i < arr.size():
			if int(arr[i + 3]) != id:
				out.append_array(arr.slice(i, i + 4))
			i += 4
		props[k] = out
	_prop_alive.erase(id)
	broken[id] = dir.normalized() if dir.length() > 0.001 else Vector2(1.0, 0.0)
	_fresh.append(id)

## Los objetos rotos desde la última consulta (el mundo los redibuja tirados)
func take_broken() -> PackedInt32Array:
	_mx.lock()
	var out := _fresh
	_fresh = PackedInt32Array()
	_mx.unlock()
	return out

## Los círculos de choque de los autos del tránsito (se reemplazan enteros cada vez: x, z, r por auto)
func set_dynamic_circles(c: PackedFloat32Array) -> void:
	_mx.lock()
	_dyn = c
	_mx.unlock()

func add_prop(id: int, x: float, z: float, r: float) -> void:
	_mx.lock()
	_add_prop_locked(id, x, z, r)
	_mx.unlock()

func _add_prop_locked(id: int, x: float, z: float, r: float) -> void:
	var k := Vector2i(int(floor(x / 16.0)), int(floor(z / 16.0)))
	var arr: PackedFloat32Array = props.get(k, PackedFloat32Array())
	arr.append_array(PackedFloat32Array([x, z, r, float(id)]))
	props[k] = arr
	_prop_alive[id] = true

func remove_prop(id: int, x: float, z: float) -> void:
	_mx.lock()
	_remove_prop_locked(id, x, z)
	_mx.unlock()

func _remove_prop_locked(id: int, x: float, z: float) -> void:
	var k := Vector2i(int(floor(x / 16.0)), int(floor(z / 16.0)))
	if not props.has(k):
		return
	var arr: PackedFloat32Array = props[k]
	var out := PackedFloat32Array()
	var i := 0
	while i < arr.size():
		if int(arr[i + 3]) != id:
			out.append_array(arr.slice(i, i + 4))
		i += 4
	props[k] = out
	_prop_alive.erase(id)

func build_world() -> Node3D:
	world_node = CityWorld.new()
	(world_node as CityWorld).setup(self)
	road_mat = StandardMaterial3D.new() # el clima no toca estos materiales
	ground_mat = StandardMaterial3D.new()
	return world_node
