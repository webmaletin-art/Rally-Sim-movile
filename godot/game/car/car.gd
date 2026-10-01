extends RefCounted
## Un auto de la carrera: física + dibujo + quién lo maneja (jugador o IA).

const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const TrackBase := preload("res://game/physics/track_base.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")

var phys: VehiclePhysics
var visual: Node3D
var snap: CarSnapshot = CarSnapshot.new()
var is_player := false
var driver: RefCounted = null # IA (RingDriver) o null si es el jugador
# entradas del jugador (las carga el HUD / teclado)
var in_throttle := 0.0
var in_brake := 0.0
var in_steer := 0.0
var in_handbrake := false
var in_nitro := false
var in_shift := 0 # cambio pedido (se consume en el primer paso)
var wall := 0.0 # límite lateral (m desde el centro del camino): más allá hay un "muro de árboles" que lo devuelve; 0 = sin límite

func _init(track: TrackBase, params: VehicleParams, player: bool, lo: bool, paint: Color, rim: Color, finish := "gloss") -> void:
	phys = VehiclePhysics.new(track, params)
	is_player = player
	visual = CarVisual.new()
	visual.setup(params, lo, paint, rim, finish)
	snap.reset_to(0.0, phys)

func place(x: float, z: float, yaw: float) -> void:
	phys.reset(x, z, yaw)
	snap.reset_to(0.0, phys)

func step(dt: float) -> void:
	if driver != null:
		var c: Vector3 = driver.update(phys, dt)
		phys.step(dt, c.x, c.y, c.z, driver.get("hb") == true, driver.get("nitro") == true)
	else:
		var sh := in_shift
		in_shift = 0
		phys.step(dt, in_throttle, in_brake, in_steer, in_handbrake, in_nitro, sh)
	if wall > 0.0:
		_keep_in_wall()

## Pista solo de camino: pasado el límite lateral el auto choca contra la línea de árboles (se lo devuelve y rebota)
func _keep_in_wall() -> void:
	var tr = phys.track
	tr.nearest(phys.px, phys.pz)
	var lat: float = tr.r_lat
	if absf(lat) <= wall:
		return
	var l: Vector3 = tr.laterals[tr.r_idx]
	var sg := 1.0 if lat > 0.0 else -1.0
	var over := absf(lat) - wall
	phys.px -= l.x * sg * over
	phys.pz -= l.z * sg * over
	var vn := (phys.vx * l.x + phys.vz * l.z) * sg # velocidad hacia afuera
	if vn > 0.0:
		phys.vx -= l.x * sg * vn * 1.3 # rebota un poco
		phys.vz -= l.z * sg * vn * 1.3
		phys.vx *= 0.985
		phys.vz *= 0.985
		phys.yawRate *= 0.9

## Reinicia el historial del dibujado en la hora t (al colocar el auto)
func restart_history(t: float) -> void:
	snap.reset_to(t, phys)

## Un paso de física; deja el estado en el historial con su hora
func step_and_record(dt: float, t: float) -> void:
	step(dt)
	snap.push(t, phys)

func update_visual(dt: float) -> void:
	visual.sync_from(snap, dt)
