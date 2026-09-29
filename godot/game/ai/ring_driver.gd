extends RefCounted
## Piloto de IA sencillo para el circuito de prueba: apunta a un punto adelante en el camino y regula la velocidad.
## (La IA completa de la versión HTML, con perfil de velocidad por curva, se porta en la fase 2.)

const CircuitTrack := preload("res://game/track/circuit_track.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")

var track: CircuitTrack
var base_speed := 28.0
var look := 18.0
var lane := 0.0 # desplazamiento lateral dentro del camino

func _init(p_track: CircuitTrack, speed: float, p_lane: float) -> void:
	track = p_track
	base_speed = speed
	lane = p_lane

## devuelve Vector3(throttle, brake, steer)
func update(p: VehiclePhysics, _dt: float) -> Vector3:
	var th := atan2(p.pz, p.px)
	var spd := sqrt(p.vx * p.vx + p.vz * p.vz)
	var ahead := (look + spd * 0.45) / track.radius(th)
	var c: Vector2 = track.center(th + ahead)
	var t: Vector2 = track.tangent(th + ahead)
	c += Vector2(-t.y, t.x) * lane
	# objetivo en el sistema del auto: x izquierda, z adelante
	var dx := c.x - p.px
	var dz := c.y - p.pz
	var lx := dx * cos(p.yaw) - dz * sin(p.yaw)
	var lz := dx * sin(p.yaw) + dz * cos(p.yaw)
	var ang := atan2(lx, maxf(lz, 0.1))
	var steer := clampf(-ang * 2.2, -1.0, 1.0)
	var v_t := base_speed * (1.0 - 0.45 * minf(1.0, absf(ang) * 2.5))
	var throttle := clampf((v_t - spd) * 0.5, 0.0, 1.0)
	var brake := clampf((spd - v_t - 1.0) * 0.25, 0.0, 1.0)
	return Vector3(throttle, brake, steer)
