extends RefCounted
## Piloto de IA de la versión HTML (js/ai.js): maneja con la MISMA física que el jugador, solo decide volante, acelerador y freno.
##  · perfil de velocidad de la pista según la curvatura, las lomas y la pendiente, con frenada anticipada
##  · seguimiento de trayectoria "pure pursuit" en su propio carril, con corrección lateral y contravolanteo
##  · círculo de fricción: dosifica el gas si las gomas ya trabajan doblando; levanta con subviraje/sobreviraje
##  · esquiva autos lentos de adelante, se pone prudente después de un susto, se destraba o reaparece
## Pensado para las pistas por curva (route_track.gd).

const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const G := 9.81

var track # RouteTrack (vista propia de este auto)
var p: VehiclePhysics
var skill := 0.9
var lane := 0.0
var lane_t := 0.0
var aggr := 0.5
var mu := 1.0
var prof: Dictionary
var throttle := 0.0
var brake := 0.0
var steer := 0.0
var hb := false
var nitro := false
var stuck_t := 0.0
var off_t := 0.0
var boost := 1.0
var idx := 0
var lat := 0.0
var t_frac := 0.0
var enabled := true
var max_v := 0.0
var caution := 0.0
var unstick_t := 0.0
var unstick_s := 0.0
var tried_unstick := false
var unstick_n := 0
var ok_t := 0.0
var time := 0.0
var others: Array = []
var respawns := 0

## opts: {skill, lane, aggr}
func _init(p_track, p_phys: VehiclePhysics, opts := {}) -> void:
	track = p_track
	p = p_phys
	skill = float(opts.get("skill", 0.9))
	lane = float(opts.get("lane", 0.0))
	lane_t = lane
	aggr = float(opts.get("aggr", 0.5))
	var V = p.V
	var surf := 0 if track.mode == "asphalt" else 1
	mu = V.mu * float(V.surfGrip[surf]) * minf(V.gripFront, V.gripRear) * (0.92 if surf == 0 else 0.84) * (0.8 + 0.15 * skill)
	prof = speed_profile(track, snappedf(mu, 0.02))

static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))

## Perfil de velocidad de la pista para un nivel de agarre (se guarda en la pista)
static func speed_profile(track, mu_v: float) -> Dictionary:
	var key := "%.2f" % mu_v
	if track.prof_cache.has(key):
		return track.prof_cache[key]
	var S: PackedVector3Array = track.samples
	var N: int = track.n
	var v := PackedFloat32Array()
	v.resize(N)
	var kap := PackedFloat32Array()
	kap.resize(N)
	var W := 5
	for i in N:
		var a := S[posmod(i - W, N)]
		var b := S[i]
		var c := S[(i + W) % N]
		var h1 := atan2(b.x - a.x, b.z - a.z)
		var h2 := atan2(c.x - b.x, c.z - b.z)
		var d := _wrap(h2 - h1)
		var ds := Vector2(c.x - a.x, c.z - a.z).length() / 2.0 + 1e-3
		kap[i] = absf(d) / ds
	var k2 := PackedFloat32Array()
	k2.resize(N)
	for i in N:
		var s := 0.0
		for j in range(-3, 4):
			s += kap[posmod(i + j, N)]
		k2[i] = s / 7.0
	# sin perder el pico: curvatura medida en ±2 muestras
	var kc := PackedFloat32Array()
	kc.resize(N)
	for i in N:
		var a := S[posmod(i - 2, N)]
		var b := S[i]
		var c := S[(i + 2) % N]
		var h1 := atan2(b.x - a.x, b.z - a.z)
		var h2 := atan2(c.x - b.x, c.z - b.z)
		kc[i] = absf(_wrap(h2 - h1)) / (Vector2(c.x - a.x, c.z - a.z).length() / 2.0 + 1e-3)
	for i in N:
		var m := (kc[posmod(i - 1, N)] + kc[i] + kc[(i + 1) % N]) / 3.0
		if m > k2[i]:
			k2[i] = m
	# lomas: sobre una cresta el auto pesa menos y agarra menos → v² = mu·g/(k + mu·kv)
	var kv_a := PackedFloat32Array()
	kv_a.resize(N)
	for i in N:
		var a := S[posmod(i - 3, N)]
		var b := S[i]
		var c := S[(i + 3) % N]
		var d1 := maxf(Vector2(b.x - a.x, b.z - a.z).length(), 1e-6)
		var d2 := maxf(Vector2(c.x - b.x, c.z - b.z).length(), 1e-6)
		kv_a[i] = maxf(0.0, ((b.y - a.y) / d1 - (c.y - b.y) / d2) / ((d1 + d2) / 2.0))
	for i in N:
		var kv := 0.0
		for j in range(-2, 3):
			kv = maxf(kv, kv_a[posmod(i + j, N)])
		var k := maxf(k2[i], 1e-4)
		var j2 := (i + 4) % N
		var gd := maxf(0.0, (S[i].y - S[j2].y) / maxf(1.0, Vector2(S[j2].x - S[i].x, S[j2].z - S[i].z).length()))
		v[i] = minf(95.0, sqrt(mu_v * (1.0 - 1.6 * minf(0.2, gd)) * G / (k + mu_v * kv)))
	# crestas: con curvatura vertical convexa el auto se aliviana
	for i in N:
		var a := S[posmod(i - 3, N)]
		var b := S[i]
		var c := S[(i + 3) % N]
		var d1 := maxf(Vector2(b.x - a.x, b.z - a.z).length(), 1e-6)
		var d2 := maxf(Vector2(c.x - b.x, c.z - b.z).length(), 1e-6)
		var kv := ((b.y - a.y) / d1 - (c.y - b.y) / d2) / ((d1 + d2) / 2.0)
		if kv > 1e-4:
			v[i] = minf(v[i], sqrt(0.5 * G / kv))
	# frenada: v_i ≤ √(v_{i+1}² + 2·a·ds), dos vueltas hacia atrás para cerrar el circuito (en bajada la gravedad resta frenada)
	var a_b := mu_v * G * 0.72
	for pass_i in 2:
		for i in range(N - 1, -1, -1):
			var j := (i + 1) % N
			var ds := S[i].distance_to(S[j])
			var gr := (S[i].y - S[j].y) / maxf(0.5, ds)
			var a := maxf(1.5, a_b - G * gr)
			v[i] = minf(v[i], sqrt(v[j] * v[j] + 2.0 * a * ds))
	var out := {"v": v, "kap": kap}
	track.prof_cache[key] = out
	return out

func _locate() -> void:
	track.nearest(p.px, p.pz)
	idx = track.r_idx
	lat = track.r_lat
	t_frac = track.r_t

## punto de la trayectoria a "dist" metros por delante, con el carril dado
func _point_ahead(dist: float, ln: float) -> Vector3:
	var S: PackedVector3Array = track.samples
	var N: int = track.n
	var i := idx
	var acc := -t_frac * S[i].distance_to(S[(i + 1) % N])
	while acc < dist:
		var j := (i + 1) % N
		acc += S[i].distance_to(S[j])
		i = j
	var pt := S[i]
	var l: Vector3 = track.laterals[i]
	return Vector3(pt.x + l.x * ln, float(i), pt.z + l.z * ln)

## Devuelve Vector3(acelerador, freno, volante); también deja hb y nitro
func update(ph: VehiclePhysics, h: float) -> Vector3:
	time += h
	var V = p.V
	var N: int = track.n
	var hw: float = track.half_width
	hb = false
	nitro = false
	if not enabled:
		throttle = 0.0
		brake = 0.0
		hb = true
		steer = 0.0
		return Vector3(0, 0, 0)
	_locate()
	var spd := sqrt(p.vx * p.vx + p.vz * p.vz)
	# velocidad objetivo: mirar un poco adelante según la velocidad
	var look := mini(N - 1, int(round(2.0 + spd * 0.10)))
	var vt := 1e9
	var pv: PackedFloat32Array = prof["v"]
	for k in range(0, look + 1):
		vt = minf(vt, pv[(idx + k) % N])
	vt *= (1.0 + (boost - 1.0) * 0.35 if boost > 1.0 else boost) * (0.82 + 0.18 * skill)
	if max_v > 0.0:
		vt = minf(vt, max_v)
	# prudencia: después de un susto baja un poco el ritmo y lo recupera de a poco
	var slip_ang := atan2(p.vLat, maxf(1.0, absf(p.vLong))) if spd > 4.0 else 0.0
	caution = maxf(0.0, caution - h * 0.07)
	if spd > 14.0 and (absf(slip_ang) > 0.12 or absf(lat) > hw + 0.4):
		caution = minf(1.0, caution + h * 1.6)
	vt *= 1.0 - 0.2 * caution
	# carril: se cierra al centro antes de una curva (mira ~25 muestras adelante)
	var kp: PackedFloat32Array = prof["kap"]
	var kap := 0.0
	for k in range(2, 26, 3):
		kap = maxf(kap, kp[(idx + k) % N])
	var lane_max := maxf(0.0, hw - 1.8)
	var ln := clampf(lane_t, -lane_max, lane_max) * (1.0 - minf(1.0, kap * 40.0))
	# tráfico: auto adelante en el mismo carril → cambiar de carril o levantar
	var fx := sin(p.yaw)
	var fz := cos(p.yaw)
	var lx := cos(p.yaw)
	var lz := -sin(p.yaw)
	var block_v := INF
	for o in others:
		if o == p:
			continue
		var dx: float = o.px - p.px
		var dz: float = o.pz - p.pz
		var f := dx * fx + dz * fz
		var l := dx * lx + dz * lz
		if f > 0.0 and f < 16.0 and absf(l) < 2.4:
			var ov: float = o.vx * fx + o.vz * fz
			if ov < spd + 0.5:
				block_v = minf(block_v, ov)
				if kap < 1.0 / 250.0: # pasar solo en recta: en curva se espera atrás
					var side := -1.0 if l > 0.0 else 1.0
					lane_t = clampf(lat + side * 2.6, -lane_max, lane_max)
	if block_v < INF:
		vt = minf(vt, block_v + 1.5 + aggr * 2.5)
	# dirección: pure pursuit
	var Ld := maxf(6.0, minf(32.0, 5.0 + spd * 0.55))
	var tgt := _point_ahead(Ld, ln)
	var dx2 := tgt.x - p.px
	var dz2 := tgt.z - p.pz
	var fwd := dx2 * fx + dz2 * fz
	var lft := dx2 * lx + dz2 * lz
	var alpha := atan2(lft, maxf(0.5, fwd))
	var delta := atan(2.0 * V.wheelBase * sin(alpha) / Ld)
	# corrección por error lateral (tipo Stanley)
	delta += atan(0.4 * (lat - ln) / maxf(6.0, spd))
	# contravolanteo suave si la cola se va
	delta += slip_ang * 0.55
	# amortiguación de giro: si ya gira más de lo que pide la trazada, afloja
	if spd > 12.0:
		var r_des := 2.0 * spd * sin(alpha) / Ld
		delta += 0.8 * V.wheelBase * (r_des - p.yawRate) / spd
	var sf := p.steer_scale(spd)
	steer = clampf(-delta / (V.maxSteer * sf), -1.0, 1.0)
	# acelerador / freno
	var err := vt - spd
	if err > 0.0:
		throttle = minf(1.0, 0.35 + err * 0.25)
		brake = 0.0
	else:
		throttle = 0.25 if err > -1.2 else 0.0
		brake = minf(1.0, -err * 0.22) if err < -1.2 else 0.0
	if absf(steer) > 0.95 and spd > 12.0:
		throttle *= 0.6
	# círculo de fricción: si las gomas ya trabajan doblando, dosificar el acelerador
	var lat_use := absf((p.vLong if p.vLong != 0.0 else spd) * p.yawRate) / (mu * G)
	var edge := maxf(0.0, (absf(lat) - (hw - 1.2)) / 2.0) * (0.0 if signf(lat) == signf(-steer) else 1.0)
	var lim := maxf(0.15, 1.0 - maxf(0.0, lat_use - 0.3) * 2.2 - edge * 0.5)
	if throttle > lim:
		throttle = lim
	# subviraje: si las ruedas de adelante patinan de costado, abrir un poco el volante y levantar
	var pk: float = V.slipPeakLat
	var fa := maxf(absf(p.wheels[0].alpha), absf(p.wheels[1].alpha))
	if spd > 8.0 and fa > pk * 1.2:
		var k := clampf(pk * 1.15 / fa, 0.0, 1.0)
		steer *= maxf(0.6, k)
		throttle = minf(throttle, 0.25)
		if fa > pk * 1.7:
			brake = maxf(brake, 0.3)
	# sobreviraje o patinada: levantar como un piloto
	if spd > 6.0:
		var ra := maxf(absf(p.wheels[2].alpha), absf(p.wheels[3].alpha))
		var b := absf(slip_ang)
		if ra > pk * 1.4 or b > 0.13:
			throttle = minf(throttle, 0.0 if b > 0.3 else (0.2 if b > 0.2 else 0.4))
		var ks := 0.0
		for w in p.wheels:
			ks = maxf(ks, absf(w.kappa))
		if ks > V.slipPeakLong * 1.6:
			throttle *= 0.6
	nitro = V.nitroCap > 0.0 and err > 6.0 and absf(steer) < 0.2 and p.nitro > V.nitroCap * 0.3
	# recuperación
	if time > 2.0 and spd < 1.5 and throttle > 0.3:
		stuck_t += h
	else:
		stuck_t = maxf(0.0, stuck_t - h * 2.0)
	if absf(lat) > hw + 7.0:
		off_t += h
	else:
		off_t = 0.0
	# trabado contra algo: primero marcha atrás girando al revés; si no alcanza, reaparece
	if unstick_t > 0.0:
		unstick_t -= h
		throttle = 0.0
		brake = 1.0
		steer = -unstick_s
		if unstick_t <= 0.0:
			stuck_t = minf(stuck_t, 1.4)
		return Vector3(throttle, brake, steer)
	if spd > 8.0:
		ok_t += h
		if ok_t > 6.0:
			unstick_n = 0
	else:
		ok_t = 0.0
	if stuck_t > 1.5 and stuck_t < 3.0 and not tried_unstick:
		unstick_n += 1
		if unstick_n > 2:
			unstick_n = 0
			respawn()
			tried_unstick = false
			return Vector3(throttle, brake, steer)
		tried_unstick = true
		unstick_t = 1.3
		unstick_s = steer if steer != 0.0 else (-1.0 if randf() < 0.5 else 1.0)
	if stuck_t < 0.2:
		tried_unstick = false
	if stuck_t > 4.0 or off_t > 3.0:
		respawn()
		tried_unstick = false
	return Vector3(throttle, brake, steer)

## reaparece más adelante en la pista, lejos de los demás autos (y de los que vienen lanzados)
func respawn() -> void:
	var S: PackedVector3Array = track.samples
	var N: int = track.n
	var i := (idx + 2) % N
	var x := 0.0
	var z := 0.0
	for k in range(2, 60, 3):
		i = (idx + k) % N
		x = S[i].x
		z = S[i].z
		var clear := true
		for o in others:
			if o == p:
				continue
			var d := Vector2(o.px - x, o.pz - z).length()
			if d < 7.0 or (d < 90.0 and Vector2(o.vx, o.vz).length() > 15.0):
				clear = false
				break
		if clear:
			break
	var tg: Vector3 = track.tangents[i]
	respawns += 1
	p.reset(x, z, atan2(tg.x, tg.z))
	stuck_t = 0.0
	off_t = 0.0
	track.hint = i
