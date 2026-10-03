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

func ground_smooth(x: float, z: float) -> float:
	return ground_info(x, z).x

## Pose de largada: en la plaza, sobre el anillo, mirando hacia la Avenida 3 (al sur). Los lugares se abren en filas.
func start_pose(slot: int) -> Array:
	var side := -1.0 if slot % 2 == 0 else 1.0
	return [side * 3.0, 48.0 + float(slot / 2) * 9.0 - 8.0, 0.0]

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
	if hit_id >= 0 and best.z > 0.0 and hit_id < city.prop_type.size() and int(city.prop_type[hit_id]) != 4: # el monumento y los portones de las salidas no se rompen
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
