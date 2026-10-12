extends RefCounted
## Piloto de la Red de rutas: sigue una polilínea de la red (NetData.route) con «pure pursuit», baja la velocidad según la curvatura que ve adelante y frena a tiempo.
## Dos modos: "wander" (huye: elige un destino lejos del jugador y va hasta ahí; cuando llega elige otro) y "pursue" (persigue: recalcula el camino hasta el auto del jugador cada tanto).
## Mismo molde que city_driver.gd: update(phys, dt) → Vector3(acelerador, freno, volante).

const NetData := preload("res://game/net/net_data.gd")

var net # NetData
var mode := "wander"
var enabled := true
var hb := false
var nitro := false
var pace := 1.0 # multiplicador de la velocidad objetivo (la sesión lo ajusta para que el rival se quede a la par)
var top_speed := 48.0 # m/s: techo (la física del auto manda de todos modos)
var skill := 0.9
var target_pos := Vector2.ZERO # pursue: el auto a perseguir (lo actualiza la sesión)
var flee_from := Vector2.ZERO # wander: de quién se aleja
var route := PackedVector2Array()
var idx := 0
var _re_t := 0.0
var _stuck_t := 0.0
var _rev_t := 0.0
var _rng := RandomNumberGenerator.new()
var _dest := Vector2.ZERO
var _cum := PackedFloat32Array()
const SURF_CAP := [1.0, 0.62, 0.70, 0.42, 0.50] # fracción de la velocidad máxima según la calle: asfalto, tierra, ripio, barro, arena
var _kv := PackedFloat32Array() # velocidad máxima de cada punto del camino por su curvatura (m/s)

func _init(p_net, p_mode := "wander", p_skill := 0.9, seed_ := 1) -> void:
	net = p_net
	mode = p_mode
	skill = p_skill
	_rng.seed = seed_
	top_speed = lerpf(36.0, 52.0, clampf((skill - 0.6) / 0.45, 0.0, 1.0))

func set_route(r: PackedVector2Array) -> void:
	route = r
	idx = 0
	_cum.resize(r.size())
	_kv.resize(r.size())
	var acc := 0.0
	var ay := lerpf(5.2, 8.0, clampf((skill - 0.6) / 0.45, 0.0, 1.0)) # aceleración lateral que se anima a usar (m/s²)
	for i in r.size():
		if i > 0:
			acc += r[i].distance_to(r[i - 1])
		_cum[i] = acc
		var v := top_speed
		if i > 0 and i < r.size() - 1:
			var a := (r[i] - r[i - 1])
			var b := (r[i + 1] - r[i])
			var la := a.length()
			var lb := b.length()
			if la > 0.01 and lb > 0.01:
				var ang := absf(a.angle_to(b))
				var k := ang / (0.5 * (la + lb))
				if k > 1e-4:
					v = clampf(sqrt(ay / k), 7.0, top_speed)
		_kv[i] = v

func _pick_dest(from: Vector2) -> Vector2:
	# un nodo de la red lejos (1 a 12 km), de preferencia del lado contrario a quien lo persigue
	var best := Vector2.ZERO
	var best_sc := -1e18
	var ids: Array = net.nodes.keys()
	for k in 14:
		var q: Vector2 = net.nodes[ids[_rng.randi() % ids.size()]]
		var d := from.distance_to(q)
		if d < 1500.0 or d > 14000.0:
			continue
		var away := (q - from).normalized().dot((from - flee_from).normalized()) if flee_from != from else 0.0
		var sc := away * 2.0 + _rng.randf()
		if sc > best_sc:
			best_sc = sc
			best = q
	if best_sc < -1e17:
		best = net.nodes[ids[_rng.randi() % ids.size()]]
	return best

func _plan(from: Vector2, yaw := 0.0, standing := false) -> void:
	if mode == "pursue":
		var r: Array = net.route(from, target_pos)
		set_route(r[0])
	else:
		# parado (recién largado): de entre varios destinos se prefiere un camino que arranque hacia donde mira el auto (sin hacer un giro en U)
		var fwd := Vector2(sin(yaw), cos(yaw))
		var best: Array = []
		for k in (6 if standing else 1):
			_dest = _pick_dest(from)
			var r2: Array = net.route(from, _dest)
			var pts: PackedVector2Array = r2[0]
			var ok := not standing or (pts.size() > 6 and (pts[5] - pts[0]).normalized().dot(fwd) > 0.2)
			if best.is_empty() or ok:
				best = r2
			if ok:
				break
		set_route(best[0])

func update(ph, dt: float) -> Vector3:
	var p := Vector2(ph.px, ph.pz)
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	_re_t -= dt
	var need := route.size() < 2
	if mode == "pursue" and _re_t <= 0.0:
		need = true
	if mode == "wander" and route.size() >= 2 and idx >= route.size() - 3:
		need = true
	if need:
		_re_t = 2.0 if mode == "pursue" else 1.0
		_plan(p, ph.yaw, spd < 5.0)
	if route.size() < 2:
		return Vector3(0.0, 0.6, 0.0)
	# punto más cercano (cerca del anterior) y punto de mira
	var bd := 1e18
	var lo := maxi(0, idx - 6)
	var hi := mini(route.size() - 1, idx + 30)
	if p.distance_to(route[mini(idx, route.size() - 1)]) > 90.0:
		lo = 0
		hi = route.size() - 1
	for i in range(lo, hi + 1):
		var d := route[i].distance_squared_to(p)
		if d < bd:
			bd = d
			idx = i
	var look := clampf(5.0 + spd * 0.55, 6.0, 32.0)
	var ti := idx
	while ti < route.size() - 1 and _cum[ti] - _cum[idx] < look:
		ti += 1
	var tgt := route[ti]
	var dx := tgt.x - p.x
	var dz := tgt.y - p.y
	var fx := sin(ph.yaw)
	var fz := cos(ph.yaw)
	var fwd := dx * fx + dz * fz
	var lft := dx * cos(ph.yaw) - dz * sin(ph.yaw)
	var alpha := atan2(lft, maxf(0.5, fwd))
	# atascado: marcha atrás un rato
	if spd < 0.8 and _rev_t <= 0.0 and enabled:
		_stuck_t += dt
	else:
		_stuck_t = 0.0
	if _stuck_t > 2.5:
		_rev_t = 1.6
		_stuck_t = 0.0
	if _rev_t > 0.0:
		_rev_t -= dt
		return Vector3(0.0, 1.0, clampf(alpha * 1.5, -1.0, 1.0))
	if not enabled:
		return Vector3(0.0, 0.5, 0.0)
	# velocidad objetivo: la más restrictiva de las curvas de adelante, con frenada anticipada (a_freno ≈ 9 m/s²)
	var want := top_speed
	var j := idx
	var s0 := _cum[idx]
	while j < route.size() and _cum[j] - s0 < 170.0:
		var dd := maxf(_cum[j] - s0 - 4.0, 0.0)
		want = minf(want, sqrt(_kv[j] * _kv[j] + 2.0 * 8.5 * dd))
		j += 1
	# calle de tierra, ripio o barro más adelante: baja el ritmo con anticipación
	var jj := idx
	for dd2 in [0.0, 25.0, 60.0, 110.0, 170.0]:
		while jj < route.size() - 1 and _cum[jj] - s0 < dd2:
			jj += 1
		var pr: Array = net.probe(route[jj].x, route[jj].y, 12.0)
		if not pr.is_empty():
			var cap: float = top_speed * float(SURF_CAP[clampi(int(pr[2]), 0, 4)])
			want = minf(want, sqrt(cap * cap + 2.0 * 8.5 * maxf(dd2 - 4.0, 0.0)))
	want = minf(want, 1.0 + (_cum[route.size() - 1] - s0) * 0.5) if mode == "pursue" and route.size() - idx < 6 else want
	want *= pace * (1.0 - 0.55 * minf(1.0, absf(alpha) * 1.2))
	var V = ph.V
	# dirección: pure pursuit con modelo de bicicleta + amortiguación de giro y contravolante (como la IA de carrera)
	var Ld := maxf(1.0, p.distance_to(tgt))
	var delta: float = atan(2.0 * V.wheelBase * sin(alpha) / Ld)
	var slip_ang: float = atan2(ph.vLat, maxf(1.0, absf(ph.vLong))) if spd > 4.0 else 0.0
	delta += slip_ang * 0.55
	if spd > 12.0:
		var r_des: float = 2.0 * spd * sin(alpha) / Ld
		delta += 0.8 * V.wheelBase * (r_des - ph.yawRate) / spd
	var steer: float = clampf(-delta / (V.maxSteer * ph.steer_scale(spd)), -1.0, 1.0)
	var thr := clampf((want - spd) * 0.6, 0.0, 1.0)
	var brk := clampf((spd - want - 1.5) * 0.18, 0.0, 1.0)
	if absf(steer) > 0.95 and spd > 12.0:
		thr *= 0.6
	# si la cola se va o las gomas ya trabajan al límite, levanta
	var lat_use: float = absf((ph.vLong if ph.vLong != 0.0 else spd) * ph.yawRate) / (V.mu * 9.81)
	thr = minf(thr, maxf(0.15, 1.0 - maxf(0.0, lat_use - 0.35) * 2.2))
	if spd > 6.0:
		var b: float = absf(slip_ang)
		if b > 0.13:
			thr = minf(thr, 0.0 if b > 0.3 else (0.2 if b > 0.2 else 0.4))
	return Vector3(thr, brk, steer)
