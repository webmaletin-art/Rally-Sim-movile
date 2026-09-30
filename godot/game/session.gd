extends RefCounted
## Sesión de una carrera o evento sobre una ruta: cuenta regresiva, avance por vuelta, posiciones, meta y resultado
## (la lógica de la clase Session de js/main.js). No dibuja nada: race.gd le pasa los autos y muestra lo que devuelve.

signal beep(k: int)
signal go
signal player_finished(value: float)

var state := "countdown" # countdown | run | done
var cd := 3.6
var last_beep := 4
var time := 0.0
var type := "race" # race | timetrial | trap | free
var laps := 1
var L := 0.0 # largo de una vuelta (m)
var s0 := 0 # índice de la línea de largada
var s1 := 0 # índice de la meta (si es un tramo)
var race_len := 0.0
var track # RouteTrack base (para largo y distancias acumuladas)
var views: Array = []
var prog: PackedFloat64Array = PackedFloat64Array()
var last_s: PackedFloat64Array = PackedFloat64Array()
var finished: Array = []
var finish_time: PackedFloat64Array = PackedFloat64Array()
var names: Array = []
var max_kmh := 0.0
var odo := 0.0 # metros recorridos por el jugador
var trap_kmh := 0.0
var last_pos := 0
var last_lap_shown := false
var messages: Array = [] # avisos para mostrar (texto, tipo)
var _tick := 0.0

func _init(p_track, cfg: Dictionary, n_cars: int) -> void:
	track = p_track
	type = str(cfg.get("type", "race"))
	L = track.length
	s0 = 0
	var seg = cfg.get("seg", null)
	if seg is Array:
		s0 = int(floor(float(seg[0]) * float(track.n)))
		s1 = int(floor(float(seg[1]) * float(track.n)))
		var d: float = track.cum[s1] - track.cum[s0]
		if d <= 0.0:
			d += L
		race_len = d
		laps = 1
	else:
		laps = maxi(1, int(cfg.get("laps", 1)))
		race_len = float(laps) * L
		s1 = s0
	prog.resize(n_cars)
	last_s.resize(n_cars)
	finish_time.resize(n_cars)
	for i in n_cars:
		finished.append(false)
		names.append("")
		views.append(track.make_view())

## Coloca el progreso inicial de cada auto (negativo: están detrás de la línea)
func init_cars(cars: Array) -> void:
	for i in cars.size():
		var s := _arc(i, cars[i].snap)
		var d := s - float(track.cum[s0])
		if d > L / 2.0:
			d -= L
		if d < -L / 2.0:
			d += L
		prog[i] = d
		last_s[i] = s

func _arc(i: int, sn) -> float:
	var v = views[i]
	v.nearest(sn.px, sn.pz)
	return float(v.cum[v.r_idx]) + float(v.r_t) * (float(v.cum[v.r_idx + 1]) - float(v.cum[v.r_idx]))

func standings(n_cars: int) -> Array:
	var ids: Array = []
	for i in n_cars:
		ids.append(i)
	ids.sort_custom(func(a: int, b: int) -> bool:
		if finished[a] and finished[b]:
			return finish_time[a] < finish_time[b]
		if finished[a]:
			return true
		if finished[b]:
			return false
		return prog[a] > prog[b])
	return ids

func position_of(i: int, n_cars: int) -> int:
	return standings(n_cars).find(i) + 1

func lap_of_player() -> int:
	return clampi(int(floor(maxf(prog[0], 0.0) / L)) + 1, 1, laps)

## Un cuadro de simulación. cars: Array de Car (con snap). Devuelve true mientras siga la sesión.
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
	time += dt
	_tick += dt
	# el avance se mide a ~30 Hz: alcanza para vueltas y posiciones
	if _tick < 1.0 / 30.0:
		return
	var h := _tick
	_tick = 0.0
	var n := cars.size()
	for i in n:
		if finished[i]:
			continue
		var sn = cars[i].snap
		var s := _arc(i, sn)
		var ds := s - last_s[i]
		if ds < -L / 2.0:
			ds += L
		if ds > L / 2.0:
			ds -= L
		var sp := sqrt(sn.vx * sn.vx + sn.vz * sn.vz)
		ds = minf(ds, sp * h * 1.3 + 0.6)
		prog[i] += ds
		last_s[i] = s
		if i == 0:
			max_kmh = maxf(max_kmh, sp * 3.6)
			odo += sp * h
		if type != "free" and prog[i] >= race_len:
			finished[i] = true
			finish_time[i] = time
			if i == 0:
				trap_kmh = sp * 3.6
				state = "done"
				player_finished.emit(_value(n))
	if state == "run" and type == "race":
		var pos := position_of(0, n)
		if last_pos != 0 and pos != last_pos and time > 3.0:
			messages.append(["⬆ ¡Pasaste! Vas %d°" % pos if pos < last_pos else "⬇ Te pasaron · %d°" % pos, "up" if pos < last_pos else "down"])
		last_pos = pos
		if laps > 1 and not last_lap_shown and prog[0] >= L * float(laps - 1):
			last_lap_shown = true
			messages.append(["ÚLTIMA VUELTA", "big"])

## Valor del resultado del jugador: tiempo (contrarreloj), puesto (carrera) o km/h (radar)
func _value(n: int) -> float:
	match type:
		"race":
			return float(position_of(0, n))
		"trap":
			return roundf(trap_kmh)
	return finish_time[0]
