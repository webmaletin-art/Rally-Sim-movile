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
var solid := false # la pista tiene obstáculos (paredes, edificios, islas): track.push() los consulta
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
	elif solid:
		_keep_out()

## Pista solo de camino: pasado el límite lateral el auto choca contra el guardarraíl (se lo devuelve, rebota un poco y raspa: lo frena)
var wall_hit := 0.0 # velocidad del último choque contra el guardarraíl (m/s); la lee el sonido
func _keep_in_wall() -> void:
	var tr = phys.track
	tr.nearest(phys.px, phys.pz)
	var lat: float = tr.r_lat
	var lim_l := wall
	var lim_r := wall
	if tr.wall_r.size() > 0:
		# modo aventura: el límite cambia por tramo y de cada lado (veredas, estaciones, túneles…)
		var i: int = tr.r_idx
		var j: int = mini(i + 1, tr.n - 1)
		lim_l = lerpf(tr.wall_l[i], tr.wall_l[j], tr.r_t)
		lim_r = lerpf(tr.wall_r[i], tr.wall_r[j], tr.r_t)
	if lat <= lim_r and lat >= -lim_l:
		return
	var l: Vector3 = tr.laterals[tr.r_idx]
	var sg := 1.0 if lat > 0.0 else -1.0
	var over := (lat - lim_r) if lat > 0.0 else (-lat - lim_l)
	phys.px -= l.x * sg * over
	phys.pz -= l.z * sg * over
	var vn := (phys.vx * l.x + phys.vz * l.z) * sg # velocidad hacia afuera
	if vn > 0.0:
		wall_hit = maxf(wall_hit, vn)
		phys.vx -= l.x * sg * vn * 1.25 # rebota
		phys.vz -= l.z * sg * vn * 1.25
		# raspa contra la chapa: pierde velocidad a lo largo
		var drag := 1.0 - clampf(0.012 + vn * 0.004, 0.0, 0.08)
		phys.vx *= drag
		phys.vz *= drag
		phys.yawRate *= 0.92
	else:
		# apoyado contra el riel (sin acercarse): roce suave
		phys.vx *= 0.9975
		phys.vz *= 0.9975

## Pistas con obstáculos (plaza de drift): tres círculos por auto contra paredes, manzanas, isla y árboles. Rebota y raspa.
func _keep_out() -> void:
	var ph := phys
	var tr = ph.track
	var L: float = ph.V.wheelBase + 1.5
	var r: float = maxf(0.95, ph.V.trackF * 0.5 + 0.05)
	var s := sin(ph.yaw)
	var c := cos(ph.yaw)
	for k in 3:
		var kk := float(k - 1)
		var h: Vector3 = tr.push(ph.px + s * kk * L * 0.34, ph.pz + c * kk * L * 0.34, r)
		if h.z <= 0.0:
			continue
		ph.px += h.x * h.z
		ph.pz += h.y * h.z
		var vn: float = ph.vx * h.x + ph.vz * h.y # velocidad contra la normal (negativa = se mete en el obstáculo)
		if vn < 0.0:
			wall_hit = maxf(wall_hit, -vn)
			ph.vx -= 1.3 * vn * h.x
			ph.vz -= 1.3 * vn * h.y
			var drag := 1.0 - clampf(0.02 + (-vn) * 0.006, 0.0, 0.12)
			ph.vx *= drag
			ph.vz *= drag
			ph.yawRate *= 0.9

## Reinicia el historial del dibujado en la hora t (al colocar el auto)
func restart_history(t: float) -> void:
	snap.reset_to(t, phys)

## Un paso de física; deja el estado en el historial con su hora
func step_and_record(dt: float, t: float) -> void:
	step(dt)
	snap.push(t, phys)

func update_visual(dt: float) -> void:
	visual.sync_from(snap, dt)
