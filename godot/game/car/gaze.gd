extends RefCounted
## Mirada con vida para el piloto y el copiloto: casi siempre al frente, con corrimientos mínimos de uno a tres grados a cada lado,
## y de vez en cuando miradas largas (espejos, tablero, hoja de notas, ventanilla, el otro). Los destinos y el tiempo que se
## sostiene cada uno son al azar con probabilidades, y la cabeza va con un resorte suave: nada se repite como un robot.
## Valores en la misma unidad que "look"/"look_y" de RigPilot (≈ tangente): yaw + = hacia la derecha, pitch − = hacia abajo.

var rng := RandomNumberGenerator.new()
var yaw := 0.0
var pitch := 0.0
var name_now := "front"
var _ty := 0.0
var _tp := 0.0
var _vy := 0.0
var _vp := 0.0
var _hold := 1.0
var _t := 0.0
var _ph := 0.0
var _targets: Array = [] # [peso, yaw, pitch, mínimo, máximo, nombre, dispersión]

func _init(kind: String, seed_v: int) -> void:
	rng.seed = seed_v
	_ph = rng.randf() * 10.0
	if kind == "pilot":
		_targets = [
			[48.0, 0.0, 0.0, 1.2, 3.8, "front", 0.025],
			[24.0, 0.0, 0.0, 0.5, 1.5, "micro", 0.07], # corrimiento de 1–4°: la dispersión se aplica con signo al azar
			[7.0, 0.38, 0.12, 0.35, 0.7, "mirror", 0.04],
			[8.0, 0.04, -0.27, 0.35, 0.9, "dash", 0.03],
			[4.0, -0.52, 0.02, 0.3, 0.6, "left_mirror", 0.05],
			[5.0, 0.55, -0.12, 0.5, 1.1, "copilot", 0.06],
			[6.0, 0.0, 0.06, 1.0, 2.2, "far", 0.03],
		]
	else:
		_targets = [
			[38.0, 0.0, -0.95, 1.4, 4.2, "read", 0.0],
			[20.0, -0.05, -0.04, 0.8, 2.6, "front", 0.03],
			[10.0, 0.7, 0.0, 0.8, 2.0, "window", 0.08],
			[8.0, -0.9, -0.02, 0.5, 1.4, "driver", 0.05],
			[18.0, 0.0, -0.1, 0.6, 1.5, "micro", 0.08],
			[6.0, 0.0, 0.1, 0.8, 1.6, "far", 0.04],
		]
	_pick()

func _pick() -> void:
	var tot := 0.0
	for t in _targets:
		tot += float(t[0])
	var r := rng.randf() * tot
	var sel: Array = _targets[0]
	for t in _targets:
		r -= float(t[0])
		if r <= 0.0:
			sel = t
			break
	name_now = str(sel[5])
	var sp := float(sel[6])
	var sg := 1.0 if rng.randf() < 0.5 else -1.0
	_ty = float(sel[1]) + (sg * (0.4 + 0.6 * rng.randf()) * sp if name_now == "micro" else rng.randfn(0.0, sp * 0.6))
	_tp = float(sel[2]) + rng.randfn(0.0, sp * 0.35)
	_hold = lerpf(float(sel[3]), float(sel[4]), rng.randf())
	_t = 0.0

func is_reading() -> bool:
	return name_now == "read"

func update(dt: float) -> void:
	dt = minf(dt, 0.05)
	_t += dt
	_ph += dt
	if _t >= _hold:
		_pick()
	# resorte amortiguado hacia el destino (las miradas largas van un poco más rápido que los corrimientos chicos)
	var k := 55.0 if (name_now == "mirror" or name_now == "left_mirror" or name_now == "dash") else 28.0
	var c := 2.0 * sqrt(k) * 0.95
	_vy += (k * (_ty - yaw) - c * _vy) * dt
	_vp += (k * (_tp - pitch) - c * _vp) * dt
	yaw += _vy * dt
	pitch += _vp * dt

## mirada final: destino + un temblor fino constante (la cabeza nunca está clavada)
func yaw_out() -> float:
	return yaw + 0.008 * sin(_ph * 0.83) + 0.005 * sin(_ph * 2.1 + 1.0)

func pitch_out() -> float:
	return pitch + 0.006 * sin(_ph * 0.67 + 0.6)
