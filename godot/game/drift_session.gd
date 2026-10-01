extends RefCounted
## Sesión de drift (la lógica de driftStep de js/main.js): cuenta regresiva, tiempo límite y puntaje por derrape.
## Mismo molde que Session (race.gd le pasa los autos y muestra lo que devuelve), sin vueltas ni rivales.
##
## Puntos: mientras el auto va de costado (ángulo entre 10° y 100° respecto de su marcha), a más de 6 m/s y con al menos dos
## ruedas apoyadas, suma velocidad × ángulo × multiplicador. El multiplicador sube (hasta ×5) cada 2,2 s de derrape seguido.
## Si se corta el derrape más de 0,8 s, lo hecho se "cobra" (pasa al total). Chocar contra una pared o un edificio lo pierde;
## un cono golpeado baja el multiplicador.

signal beep(k: int)
signal go
signal player_finished(value: float)

var state := "countdown" # countdown | run | done
var cd := 3.6
var last_beep := 4
var time := 0.0
var type := "drift"
var limit := 60.0 # segundos de la prueba
var laps := 1
var L := 1000.0
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

var total := 0.0 # puntos ya cobrados
var cur := 0.0 # puntos del derrape en curso
var mult := 1
var combo := 0.0 # segundos seguidos de derrape
var idle := 0.0
var best_run := 0.0 # el derrape más largo cobrado
var angle_deg := 0.0 # ángulo actual (para mostrarlo)
var drifting := false

func _init(p_track, cfg: Dictionary, _n_cars: int) -> void:
	track = p_track
	limit = maxf(20.0, float(cfg.get("time", 60)))
	if float(cfg.get("time", 0)) <= 0.0:
		limit = 90.0

func init_cars(_cars: Array) -> void:
	pass

func standings(_n: int) -> Array:
	return [0]

func position_of(_i: int, _n: int) -> int:
	return 1

func lap_of_player() -> int:
	return 1

func remaining() -> float:
	return maxf(0.0, limit - time)

## Un golpe contra pared o edificio: se pierde el derrape en curso
func on_wall(speed: float) -> void:
	if state != "run" or speed < 2.0:
		return
	if cur > 0.0:
		messages.append([tr("💥 Chocaste: perdiste el derrape"), "down"])
	cur = 0.0
	mult = 1
	combo = 0.0
	idle = 0.0

## Conos golpeados con el auto: bajan el multiplicador
func on_cones(k: int) -> void:
	if state != "run" or k <= 0:
		return
	if mult > 1:
		mult -= 1
		combo = float(mult - 1) * 2.2
		messages.append([tr("Cono: multiplicador x%d") % mult, "down"])

func _bank() -> void:
	if cur <= 0.0:
		return
	var pts := roundf(cur)
	total += pts
	best_run = maxf(best_run, pts)
	if pts > 600.0:
		messages.append([tr("🌀 +%d pts") % int(pts), "up"])
	cur = 0.0
	mult = 1
	combo = 0.0

func update(dt: float, cars: Array) -> void:
	messages.clear()
	if state == "countdown":
		cd -= dt
		var k := int(ceil(cd))
		if k < last_beep and k > 0:
			last_beep = k
			beep.emit(k)
		if cd <= 0.0:
			state = "run"
			time = 0.0
			go.emit()
		return
	if state != "run":
		return
	time += dt
	var ph = cars[0].phys
	var sp := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	max_kmh = maxf(max_kmh, sp * 3.6)
	odo += sp * dt
	var beta := absf(atan2(ph.vLat, maxf(0.5, absf(ph.vLong))))
	angle_deg = rad_to_deg(beta)
	drifting = sp > 6.0 and beta > 0.17 and beta < 1.7 and ph.contacts >= 2
	if drifting:
		cur += dt * sp * beta * 57.3 * 0.11 * float(mult)
		combo += dt
		idle = 0.0
		var nm := mini(5, 1 + int(floor(combo / 2.2)))
		if nm > mult:
			mult = nm
			messages.append([tr("x%d COMBO") % mult, "up"])
	else:
		idle += dt
		if idle > 0.8 and cur > 0.0:
			_bank()
	if time >= limit:
		_bank()
		state = "done"
		finished[0] = true
		finish_time[0] = time
		player_finished.emit(total)
