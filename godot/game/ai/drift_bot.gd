extends RefCounted
## Piloto automático de la plaza de drift (para la prueba de rendimiento y los rivales de adorno): da vueltas en círculo alrededor
## del centro con el acelerador a fondo y tirones de freno de mano, así hay derrape, humo y conos volando como en una partida real.

var hb := false
var nitro := false
var enabled := true
var radius := 28.0
var speed := 16.0
var t := 0.0
var phase := 0.0

func _init(p_radius := 28.0, p_phase := 0.0) -> void:
	radius = p_radius
	phase = p_phase
	t = p_phase

## Devuelve Vector3(acelerador, freno, volante)
func update(ph, dt: float) -> Vector3:
	t += dt
	var r := sqrt(ph.px * ph.px + ph.pz * ph.pz)
	var a := atan2(ph.pz, ph.px)
	# rumbo deseado: tangente al círculo (antihorario) corregida hacia el radio pedido
	var corr := clampf((r - radius) * 0.06, -0.7, 0.7)
	var ta := a + PI * 0.5 + corr
	var dx := cos(ta)
	var dz := sin(ta)
	var fx := sin(ph.yaw)
	var fz := cos(ph.yaw)
	var lx := cos(ph.yaw)
	var lz := -sin(ph.yaw)
	var alpha := atan2(dx * lx + dz * lz, maxf(0.05, dx * fx + dz * fz))
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	hb = spd > 9.0 and fmod(t, 3.2) < 0.45
	var thr := 1.0 if spd < speed else 0.45
	return Vector3(thr, 0.0, clampf(-alpha * 1.8, -1.0, 1.0))
