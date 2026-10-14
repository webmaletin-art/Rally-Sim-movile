extends RefCounted
## Piloto de un patrullero (docs/POLICIA.md). Mismo molde que city_driver.gd / net_driver.gd: update(phys, dt) → Vector3(acelerador, freno, volante).
## Corre en el hilo de la física: sólo lee la física del jugador (`target`) y el camino que le deja el hilo principal (`path`, del GPS).
##  · lejos (> NEAR m): sigue el camino del GPS hasta el jugador, con la velocidad que permiten las curvas de adelante;
##  · cerca: deja el camino y va directo a un punto según su papel:
##      «ram»   apunta a la cola del jugador (de costado, como para hacerlo trompear) y llega más rápido que él;
##      «block» se adelanta, se le cruza adelante y frena para cortarle el paso;
##      «side»  se le pega al costado y lo encierra contra la banquina.
##  · parado («parked»): frenado en el control, esperando.
## Si se traba (contra un guardarraíl o un auto) da marcha atrás un rato.

const NEAR := 38.0 # m: más cerca que esto deja el GPS y va directo (más lejos el camino de la calle es más seguro que la línea recta)
const G := 9.81

var mode := "parked" # parked | chase | leave
var role := "ram" # ram | block | side
var target # VehiclePhysics del jugador
var path := PackedVector2Array() # camino del GPS (lo cambia el hilo principal entero: se lee una sola vez por paso)
var grip := 1.0 # agarre que usa para calcular las curvas (se sube con el nivel)
var hb := false
var nitro := false
var idx := 0
var stuck_t := 0.0
var rev_t := 0.0
var side := 1.0 # de qué lado se pega («side») o hacia dónde se cruza («block»)

func update(ph, dt: float) -> Vector3:
	hb = false
	if mode == "parked" or (target == null and mode != "path"):
		hb = true # (freno de mano: el freno sostenido con el auto parado es marcha atrás)
		return Vector3(0.0, 0.0, 0.0)
	var p := Vector2(ph.px, ph.pz)
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	if mode == "path": # (pruebas y autos de paseo) sólo sigue el camino y frena al final
		var rr := _follow(p, spd)
		return _drive(ph, p, spd, rr[0], minf(float(rr[1]), sqrt(2.0 * 0.7 * G * _remaining(p))), dt)
	var tp := Vector2(target.px, target.pz)
	var tv := Vector2(target.vx, target.vz)
	var tspd := tv.length()
	var tf := Vector2(sin(target.yaw), cos(target.yaw))
	var d := p.distance_to(tp)
	var aim := tp
	var want := 0.0
	if mode == "leave": # se va: sigue el camino que tenga, despacio, o frena
		if path.size() < 2:
			hb = true
			return Vector3(0.0, 0.0, 0.0)
	if mode == "chase" and d < 7.0 and (p - tp).dot(tf) > -1.0 and role != "block":
		# ya está encima (al costado o adelante): acompaña su velocidad y lo encierra, sin pasarse de largo ni dar vueltas
		aim = tp + tf * 6.0 + Vector2(tf.y, -tf.x) * side * 1.2
		want = tspd
	elif mode == "chase" and (d < NEAR or path.size() < 2):
		var lead := clampf(d / maxf(spd - tspd + 6.0, 6.0), 0.0, 1.1) # cuánto adelante mira (tiempo hasta alcanzarlo)
		var fut := tp + tv * lead
		var left := Vector2(tf.y, -tf.x) * side
		match role:
			"block":
				var ahead := (p - tp).dot(tf) # cuánto adelante del jugador está
				if ahead > 4.0:
					aim = tp + tf * 9.0 # ya está adelante: se le cruza adelante y frena
					want = maxf(0.0, tspd - 5.0)
				else:
					aim = fut + tf * 16.0 + left * 2.0 # lo pasa por un costado
					want = tspd + 14.0
			"side":
				aim = fut + left * 2.1 + tf * 1.0
				want = tspd + (6.0 if d > 6.0 else 1.5)
			_:
				aim = fut - tf * 1.6 + left * 0.7 # la cola, un poco de costado: lo hace trompear
				want = tspd + (10.0 if d > 8.0 else 4.0)
		want = maxf(want, 8.0 if d > 10.0 else 0.0)
	else:
		var r := _follow(p, spd)
		aim = r[0]
		want = r[1]
	return _drive(ph, p, spd, aim, want, dt)

func _remaining(p: Vector2) -> float:
	var rem := 0.0
	for i in range(idx, path.size() - 1):
		rem += path[i].distance_to(path[i + 1])
	return rem

func _drive(ph, p: Vector2, spd: float, aim: Vector2, want: float, dt: float) -> Vector3:
	# volante: punto adelantado
	var dx := aim.x - p.x
	var dz := aim.y - p.y
	var fx := sin(ph.yaw)
	var fz := cos(ph.yaw)
	var lx := cos(ph.yaw)
	var lz := -sin(ph.yaw)
	var alpha := atan2(dx * lx + dz * lz, maxf(0.05, dx * fx + dz * fz))
	var ld := maxf(sqrt(dx * dx + dz * dz), 8.0)
	if dx * fx + dz * fz < 0.0: # el punto quedó atrás: volantazo hacia ese lado (o, si está cerca, frena en vez de dar la vuelta)
		alpha = signf(dx * lx + dz * lz) * 1.2
		if ld < 12.0:
			want = minf(want, 2.0)
	# trabado: marcha atrás girando al revés
	if spd < 1.0 and want > 3.0 and rev_t <= 0.0:
		stuck_t += dt
	else:
		stuck_t = maxf(0.0, stuck_t - dt)
	if stuck_t > 1.6:
		rev_t = 1.3
		stuck_t = 0.0
	if rev_t > 0.0:
		rev_t -= dt
		return Vector3(0.0, 1.0, clampf(alpha * 1.6, -1.0, 1.0))
	# en curva cerrada baja la velocidad (no más de lo que da el agarre con ese volante)
	# radio de giro de la persecución pura: r = Ld / (2·sen α) → velocidad que da el agarre en ese radio
	want = minf(want, maxf(9.0, sqrt(grip * G * 0.95 * ld / (2.0 * maxf(sin(absf(alpha)), 0.004)))))
	var thr := 1.0 if spd < want - 0.5 else (0.35 if spd < want + 1.0 else 0.0)
	var brk := 0.0 if spd < want + 2.5 else clampf((spd - want) / 8.0, 0.3, 1.0)
	if absf(alpha) > 0.9 and spd > 12.0:
		hb = true # media vuelta: freno de mano
	return Vector3(thr, brk, clampf(-alpha * 2.0, -1.0, 1.0))

## Sigue el camino del GPS: punto de mira adelante y velocidad según las curvas que vienen (frena a tiempo)
func _follow(p: Vector2, spd: float) -> Array:
	var route := path
	if route.size() < 2:
		return [p, 0.0]
	var bd := 1e18
	var lo := maxi(0, idx - 6)
	var hi := mini(route.size() - 1, idx + 40)
	if idx >= route.size() - 1 or p.distance_to(route[mini(idx, route.size() - 1)]) > 90.0:
		lo = 0
		hi = route.size() - 1
	for i in range(lo, hi + 1):
		var dd := route[i].distance_squared_to(p)
		if dd < bd:
			bd = dd
			idx = i
	var look := 10.0 + spd * 0.55
	var ti := idx
	var acc := 0.0
	while ti < route.size() - 1 and acc < look:
		acc += route[ti].distance_to(route[ti + 1])
		ti += 1
	# velocidad: la menor que exige cada curva de los próximos ~250 m, con lugar para frenar (≈ 0,8 g)
	var want := 95.0
	var dist := 0.0
	var j := idx
	while j < route.size() - 2 and dist < 260.0:
		var a := route[j]
		var b := route[j + 1]
		var c := route[j + 2]
		var seg := a.distance_to(b)
		dist += seg
		var ang := absf((b - a).angle_to(c - b))
		if ang > 0.02:
			var r := maxf(seg, b.distance_to(c)) / ang
			var vc := sqrt(grip * G * 0.95 * r)
			want = minf(want, sqrt(vc * vc + 2.0 * 0.8 * G * maxf(0.0, dist - seg)))
		j += 1
	return [route[ti], want]
