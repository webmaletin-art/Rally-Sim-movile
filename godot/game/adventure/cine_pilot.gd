extends RefCounted
## Piloto automático de las cinemáticas: maneja el auto del jugador (o del rival) por el camino hasta un punto exacto y frena
## ahí (entrar a la estación y quedar junto al surtidor, entrar al taller) o lo saca a la ruta a una velocidad dada.
## Sigue una trayectoria con desplazamiento lateral que se mueve de a poco (de un carril al playón y al revés).

var track # vista de AdvTrack
var p # VehiclePhysics
var s0 := 0.0 # dónde empieza el cambio de carril (m)
var s1 := 0.0 # dónde termina
var lat0 := 0.0 # lateral al empezar (+ = derecha)
var lat1 := 0.0 # lateral al terminar
var s_stop := -1.0 # dónde frenar (−1 = no frena: sigue a v_max)
var v_max := 14.0
var decel := 3.2
var done := false
var hb := false
var nitro := false
var throttle := 0.0
var brake := 0.0
var steer := 0.0

func _init(p_track, p_phys) -> void:
	track = p_track
	p = p_phys

func lat_at(s: float) -> float:
	if s <= s0:
		return lat0
	if s >= s1:
		return lat1
	var u := (s - s0) / maxf(1.0, s1 - s0)
	u = u * u * (3.0 - 2.0 * u)
	return lerpf(lat0, lat1, u)

func _s_of(i: int, t: float) -> float:
	return float(track.cum[i]) + t * (float(track.cum[mini(i + 1, track.n - 1)]) - float(track.cum[i]))

func update(_ph, h: float) -> Vector3:
	track.nearest(p.px, p.pz)
	var s := _s_of(track.r_idx, track.r_t)
	var spd: float = sqrt(p.vx * p.vx + p.vz * p.vz)
	hb = false
	# punto a seguir (más adelante cuanto más rápido)
	var Ld := clampf(4.0 + spd * 0.55, 5.0, 24.0)
	var sa := s + Ld
	var ia: int = track.idx_at(sa)
	var pt: Vector3 = track.samples[ia]
	var L: Vector3 = track.laterals[ia]
	var la := lat_at(sa)
	var tx := pt.x + L.x * la
	var tz := pt.z + L.z * la
	var yaw: float = p.yaw
	var fx := sin(yaw)
	var fz := cos(yaw)
	var lx := cos(yaw)
	var lz := -sin(yaw)
	var dx: float = tx - float(p.px)
	var dz: float = tz - float(p.pz)
	var alpha := atan2(dx * lx + dz * lz, maxf(0.5, dx * fx + dz * fz))
	var delta: float = atan(2.0 * float(p.V.wheelBase) * sin(alpha) / Ld)
	steer = clampf(-delta / (p.V.maxSteer * p.steer_scale(maxf(spd, 1.0))), -1.0, 1.0)
	# velocidad buscada
	var vt := v_max
	if s_stop >= 0.0:
		var left := s_stop - s
		vt = minf(v_max, sqrt(maxf(0.0, 2.0 * decel * maxf(0.0, left - 0.8))))
		if left < 1.2 and spd < 1.2:
			done = true
	if done:
		throttle = 0.0
		brake = 1.0
		hb = true
		return Vector3(0.0, 1.0, steer * 0.3)
	var err := vt - spd
	if err > 0.0:
		throttle = clampf(0.25 + err * 0.18, 0.0, 0.75)
		brake = 0.0
	else:
		throttle = 0.0
		brake = clampf(-err * 0.25, 0.0, 1.0)
	return Vector3(throttle, brake, steer)

## Quieto y frenado (dentro del taller, esperando en la estación)
class Hold extends RefCounted:
	var hb := true
	var nitro := false
	func update(_ph, _h: float) -> Vector3:
		return Vector3(0.0, 1.0, 0.0)
