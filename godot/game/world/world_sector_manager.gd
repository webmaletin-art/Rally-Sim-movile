extends RefCounted
## Sectores de World Life. Usa la MISMA cuadrícula que el streaming de la ciudad (cuadras de 160 m, CityLayout.CELL) para no tener un segundo sistema de carga.
## Dado dónde está el jugador, dice qué sectores están en cada nivel de actividad. El costo de la vida del mundo depende de ESTA zona alrededor del jugador y no del tamaño del mapa.
##   ACTIVO       (0 – activo m):      modelo + comportamiento completo
##   SIMPLIFICADO (activo – simp. m):  simulación reducida, poca frecuencia
##   LÓGICO       (simp. – lógico m):  sólo la información necesaria, sin dibujar
##   NINGUNO      (más lejos):         no existe; se reconstruye con reglas + semilla + tiempo cuando el jugador se acerca
## Las distancias salen de world_life.json y se escalan según el perfil (LOW/MEDIUM/HIGH).

enum Level { ACTIVE, SIMPLIFIED, LOGICAL, NONE }

var cell := 160.0
var r_active := 150.0
var r_simplified := 300.0
var r_logical := 600.0
var sector := Vector2i(-99999, -99999)
var player := Vector2.ZERO
var active: Array[Vector2i] = []
var simplified: Array[Vector2i] = []
var logical: Array[Vector2i] = []

func configure(cell_size: float, radii: Dictionary, dist_scale: float) -> void:
	cell = cell_size
	r_active = float(radii.get("active", 150.0)) * dist_scale
	r_simplified = float(radii.get("simplified", 300.0)) * dist_scale
	r_logical = float(radii.get("logical", 600.0)) * dist_scale
	sector = Vector2i(-99999, -99999)

func sector_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))

func sector_center(s: Vector2i) -> Vector2:
	return (Vector2(s) + Vector2(0.5, 0.5)) * cell

func level_for_distance(d: float) -> int:
	if d <= r_active:
		return Level.ACTIVE
	if d <= r_simplified:
		return Level.SIMPLIFIED
	if d <= r_logical:
		return Level.LOGICAL
	return Level.NONE

## Nivel de un punto del mundo respecto del jugador
func level_at(p: Vector2) -> int:
	return level_for_distance(p.distance_to(player))

## Nivel de un sector entero (por la distancia de su borde más cercano al jugador)
func level_of_sector(s: Vector2i) -> int:
	var c := sector_center(s)
	var dx := maxf(0.0, absf(player.x - c.x) - cell * 0.5)
	var dz := maxf(0.0, absf(player.y - c.y) - cell * 0.5)
	return level_for_distance(sqrt(dx * dx + dz * dz))

## Actualiza la posición del jugador. Devuelve true si cambió de sector (ahí se recalculan las listas; el resto de los cuadros no cuesta nada).
func update(p: Vector2) -> bool:
	player = p
	var s := sector_of(p)
	if s == sector:
		return false
	sector = s
	_rebuild_lists()
	return true

func _rebuild_lists() -> void:
	active.clear()
	simplified.clear()
	logical.clear()
	var n := int(ceil(r_logical / cell)) + 1
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var s := Vector2i(sector.x + dx, sector.y + dz)
			match level_of_sector(s):
				Level.ACTIVE: active.append(s)
				Level.SIMPLIFIED: simplified.append(s)
				Level.LOGICAL: logical.append(s)

func clear() -> void:
	sector = Vector2i(-99999, -99999)
	active.clear()
	simplified.clear()
	logical.clear()
