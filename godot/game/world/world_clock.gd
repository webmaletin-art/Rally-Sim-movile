extends RefCounted
## Reloj del mundo (WORLD_TIME). Es un instante LÓGICO en segundos de mundo: no se lee de la red a cada rato. Se fija una referencia (al entrar online, la da el servidor) y de ahí en
## más el tiempo se calcula con el reloj local del teléfono: no hay trabajo por cuadro. Si el teléfono se desvía del servidor, `correct()` lo corrige de a poco (sin saltos),
## salvo que la diferencia sea enorme (ahí se corta en seco, una sola vez).

var day_seconds := 960.0 # un día del mundo (16 minutos)
var time_scale := 1.0 # segundos de mundo por segundo real
var max_slew := 0.08 # cuánto se puede acelerar o frenar el reloj para alcanzar al servidor (8 %)
var snap_seconds := 45.0 # una diferencia mayor que esto se corrige de golpe
var frozen := false # tiempo detenido (pruebas con la hora fija)
var synced := false # la referencia vino del servidor

var _ref_time := 0.0 # tiempo del mundo en el instante _ref_ticks
var _ref_ticks := 0 # Time.get_ticks_msec() del instante de referencia
var _offset := 0.0 # corrección ya aplicada (s)
var _target := 0.0 # corrección que falta alcanzar (s)
var _now_override := -1.0 # sólo para pruebas: tiempo fijo (>= 0) en lugar del reloj local

## Fija la referencia: world_time es el tiempo del mundo AHORA
func set_reference(world_time: float, scale := 1.0, from_server := false) -> void:
	_ref_time = world_time
	_ref_ticks = Time.get_ticks_msec()
	time_scale = scale
	_offset = 0.0
	_target = 0.0
	synced = from_server

func now() -> float:
	if _now_override >= 0.0:
		return _now_override
	if frozen:
		return _ref_time + _offset
	return _ref_time + float(Time.get_ticks_msec() - _ref_ticks) / 1000.0 * time_scale + _offset

## Corrección de deriva: server_time es el tiempo del mundo que dice el servidor ahora. Devuelve la diferencia que había.
func correct(server_time: float) -> float:
	var d := server_time - now()
	if absf(d) > snap_seconds:
		set_reference(server_time, time_scale, true)
	else:
		_target += d
		synced = true
	return d

## Avanza la corrección pendiente de a poco (se llama con el dt de cada cuadro, es casi gratis)
func tick(dt: float) -> void:
	if is_equal_approx(_offset, _target):
		return
	var step := maxf(0.0, max_slew) * dt
	_offset = move_toward(_offset, _target, step)

func pending_correction() -> float:
	return _target - _offset

func day_index() -> int:
	return int(floor(now() / day_seconds))

## Fracción del día (0 = medianoche, 0,5 = mediodía)
func day_fraction() -> float:
	return fposmod(now() / day_seconds, 1.0)

func hour() -> float:
	return day_fraction() * 24.0

## Tiempo del mundo para una hora del día dada (para empezar a las 9:00, por ejemplo)
func time_for_hour(h: float, day := 0) -> float:
	return float(day) * day_seconds + fposmod(h, 24.0) / 24.0 * day_seconds

func set_test_time(t: float) -> void:
	_now_override = t
