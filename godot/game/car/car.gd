extends RefCounted
## Un auto de la carrera: física + dibujo + quién lo maneja (jugador o IA).

const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const TrackBase := preload("res://game/physics/track_base.gd")

var phys: VehiclePhysics
var visual: Node3D
var is_player := false
var driver: RefCounted = null # IA (RingDriver) o null si es el jugador
# entradas del jugador (las carga el HUD / teclado)
var in_throttle := 0.0
var in_brake := 0.0
var in_steer := 0.0
var in_handbrake := false

func _init(track: TrackBase, params: VehicleParams, player: bool, lo: bool, paint: Color, rim: Color) -> void:
	phys = VehiclePhysics.new(track, params)
	is_player = player
	visual = CarVisual.new()
	visual.setup(params, lo, paint, rim)

func place(x: float, z: float, yaw: float) -> void:
	phys.reset(x, z, yaw)

func step(dt: float) -> void:
	if driver != null:
		var c: Vector3 = driver.update(phys, dt)
		phys.step(dt, c.x, c.y, c.z, false)
	else:
		phys.step(dt, in_throttle, in_brake, in_steer, in_handbrake)

func update_visual(dt: float) -> void:
	visual.sync_from(phys, dt)
