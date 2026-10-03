extends RefCounted
## Piloto automático de Dream City: sigue un camino de puntos (el del GPS) mirando un poco adelante y baja la velocidad en las curvas. Sirve de prueba (¿se puede
## llegar por las calles sin trabarse?) y después para el tránsito de papel.

var hb := false
var nitro := false
var enabled := true
var hud # CityHud: de ahí sale el camino
var top_speed := 17.0 # m/s
var stuck_t := 0.0
var rev_t := 0.0
var idx := 0

func update(ph, dt: float) -> Vector3:
	var route: PackedVector2Array = hud.route if hud != null else PackedVector2Array()
	if route.size() < 2:
		return Vector3(0.0, 0.6, 0.0)
	var p := Vector2(ph.px, ph.pz)
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	# punto más cercano (sólo mirando cerca del anterior) y el de mira, adelante
	var bd := 1e18
	var lo := maxi(0, idx - 8)
	var hi := mini(route.size() - 1, idx + 40)
	if idx >= route.size() - 1 or p.distance_to(route[mini(idx, route.size() - 1)]) > 120.0:
		lo = 0
		hi = route.size() - 1
	for i in range(lo, hi + 1):
		var d := route[i].distance_squared_to(p)
		if d < bd:
			bd = d
			idx = i
	var look := 12.0 + spd * 0.7
	var ti := idx
	var acc := 0.0
	while ti < route.size() - 1 and acc < look:
		acc += route[ti].distance_to(route[ti + 1])
		ti += 1
	var tgt := route[ti]
	var dx := tgt.x - p.x
	var dz := tgt.y - p.y
	var fx := sin(ph.yaw)
	var fz := cos(ph.yaw)
	var lx := cos(ph.yaw)
	var lz := -sin(ph.yaw)
	var alpha := atan2(dx * lx + dz * lz, maxf(0.05, dx * fx + dz * fz))
	# atascado: va marcha atrás un rato girando
	if spd < 0.8 and rev_t <= 0.0:
		stuck_t += dt
	else:
		stuck_t = 0.0
	if stuck_t > 2.5:
		rev_t = 1.6
		stuck_t = 0.0
	if rev_t > 0.0:
		rev_t -= dt
		return Vector3(0.0, 1.0, clampf(alpha * 1.5, -1.0, 1.0)) # freno en reversa: el auto retrocede con el freno sostenido
	var want := clampf(top_speed * (1.0 - 0.75 * minf(1.0, absf(alpha) * 1.4)), 5.0, top_speed)
	var thr := 1.0 if spd < want else 0.0
	var brk := 0.0 if spd < want + 2.0 else 0.5
	return Vector3(thr, brk, clampf(-alpha * 1.8, -1.0, 1.0))
