extends RefCounted
## Reparto de los árboles de la prueba: SIEMPRE el mismo (semilla fija) y por tandas: los primeros 1000 son un subconjunto de los primeros 5000, y así hasta 20 000,
## así 1000 vs 5000 vs 10000 se comparan sobre el mismo bosque. Mezcla: bordes del camino (cerca), bosques en manchones (medio) y bosques lejanos (hasta ~700 m), con claros abiertos.
## Cada árbol: [x, y, z, escala, yaw, especie 0..n-1]. La altura sale de la misma función que usa la física (ground_smooth).

const SEED := 20240611
const MAX_TREES := 20000

var track
var items: Array = [] # una entrada por árbol ya repartido
var _rng := RandomNumberGenerator.new()
var _view
var _clusters: Array = [] # centros de bosque: [x, z, radio, especie principal]
var species_n := 5

func setup(p_track, p_species: int) -> void:
	track = p_track
	species_n = p_species
	_rng.seed = SEED
	_view = track.make_view(false)
	_view.trust = true
	# manchones de bosque repartidos alrededor de todo el recorrido (a distintas distancias del camino)
	for k in 90:
		var si := _rng.randi() % int(track.n)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var off := _rng.randf_range(25.0, 520.0) * side
		var p: Vector3 = track.samples[si]
		var l: Vector3 = track.laterals[si]
		_clusters.append([p.x + l.x * off, p.z + l.z * off, _rng.randf_range(35.0, 120.0), _rng.randi() % species_n])

## Reparte hasta `count` árboles más (devuelve true cuando ya están todos)
func generate(upto: int, budget: int) -> bool:
	var made := 0
	while items.size() < mini(upto, MAX_TREES) and made < budget:
		items.append(_one(items.size()))
		made += 1
	return items.size() >= mini(upto, MAX_TREES)

func _one(i: int) -> Array:
	var near_min: float = track.half_width + track.shoulder + 3.0
	var px := 0.0
	var pz := 0.0
	var sp := 0
	var kind := _rng.randf()
	for tries in 12:
		var si := _rng.randi() % int(track.n)
		var p: Vector3 = track.samples[si]
		var l: Vector3 = track.laterals[si]
		if kind < 0.22:
			# a los lados del camino: cerca, en hileras irregulares
			var off := near_min + _rng.randf_range(0.0, 22.0)
			off *= -1.0 if _rng.randf() < 0.5 else 1.0
			px = p.x + l.x * off
			pz = p.z + l.z * off
			sp = _rng.randi() % species_n
		elif kind < 0.78:
			# manchones de bosque (medio y lejos)
			var c: Array = _clusters[_rng.randi() % _clusters.size()]
			var ang := _rng.randf() * TAU
			var rr := float(c[2]) * sqrt(_rng.randf())
			px = float(c[0]) + cos(ang) * rr
			pz = float(c[1]) + sin(ang) * rr
			sp = int(c[3]) if _rng.randf() < 0.65 else _rng.randi() % species_n
		else:
			# sueltos y lejanos, hasta ~700 m del camino (profundidad para ver árboles a larga distancia)
			var off2 := _rng.randf_range(40.0, 700.0) * (-1.0 if _rng.randf() < 0.5 else 1.0)
			px = p.x + l.x * off2
			pz = p.z + l.z * off2
			sp = _rng.randi() % species_n
		# no sobre el camino ni sobre otro tramo (curvas cerradas): se comprueba con la distancia al tramo más cercano
		_view.hint = _nearest_idx(px, pz)
		var y: float = _view.ground_smooth(px, pz)
		if float(_view.r_dist) > near_min:
			return [px, y, pz, _rng.randf_range(0.8, 1.25), _rng.randf() * TAU, sp]
	# si no hubo lugar (muy raro) el árbol queda lejos y se ve igual: no se pierde la cuenta
	var q: Vector3 = track.samples[0]
	return [q.x + 150.0, q.y, q.z + 150.0, 1.0, 0.0, sp]

func _nearest_idx(x: float, z: float) -> int:
	# búsqueda gruesa (cada 6 muestras) para arrancar la local
	var best := 1e18
	var bi := 0
	var i := 0
	while i < int(track.n):
		var p: Vector3 = track.samples[i]
		var d := (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
		if d < best:
			best = d
			bi = i
		i += 7
	return bi
