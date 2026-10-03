extends RefCounted
## Sesión del mundo abierto: sin cuenta regresiva, sin meta y sin tiempo límite. Cuenta el recorrido y la velocidad máxima; el resto (calle, GPS, mapa) lo muestra el
## HUD de la ciudad. Mismo molde que Session y DriftSession para que race.gd y el HUD la traten igual.

signal beep(k: int)
signal go
signal player_finished(value: float)

var state := "run" # siempre en marcha: se sale desde la pausa
var cd := 0.0
var time := 0.0
var type := "city"
var laps := 1
var L := 1.0
var race_len := 1.0e9
var track
var views: Array = []
var prog: PackedFloat64Array = PackedFloat64Array([0.0])
var last_s: PackedFloat64Array = PackedFloat64Array([0.0])
var finished: Array = [false]
var finish_time: PackedFloat64Array = PackedFloat64Array([0.0])
var names: Array = [""]
var max_kmh := 0.0
var odo := 0.0
var trap_kmh := 0.0
var last_pos := 1
var messages: Array = []
var hits := 0 # golpes contra paredes y objetos

func _init(p_track, _cfg: Dictionary, _n_cars: int) -> void:
	track = p_track

func init_cars(_cars: Array) -> void:
	pass

func standings(_n: int) -> Array:
	return [0]

func position_of(_i: int, _n: int) -> int:
	return 1

func lap_of_player() -> int:
	return 1

func on_wall(speed: float) -> void:
	if speed > 3.0:
		hits += 1

func update(dt: float, cars: Array) -> void:
	messages.clear()
	time += dt
	var ph = cars[0].phys
	var sp := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	max_kmh = maxf(max_kmh, sp * 3.6)
	odo += sp * dt
