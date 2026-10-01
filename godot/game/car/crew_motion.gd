extends RefCounted
## Movimiento del piloto y el copiloto (portado de js/cockpit.js):
##  · dos resortes encadenados con las fuerzas G REALES del auto (torso firme por el arnés, cabeza suelta): se pasan y vuelven;
##  · manos en el volante mano-sobre-mano (cada una agarra un punto del aro; al acabarse el brazo suelta y vuelve a agarrar);
##  · mano a la palanca en cada cambio, al freno de mano al tirarlo; pie derecho en el acelerador/freno;
##  · el copiloto se ataja con la mano en el tablero en una frenada fuerte y mira al frente con movimientos chicos.
## Coordenadas de la cabina: +z adelante, +x izquierda, y desde el piso.

const GRIP_R := 0.1706 # hypot(0.17, 0.015)
const GRIP_H := [0.0880, 3.0536] # atan2(0.015, 0.17), PI - atan2(0.015, 0.17)

# fuerzas G (resortes)
var kT := 40.0
var cT := 8.5
var kH := 95.0
var cH := 5.2
var gain := 1.0
var t := Vector3.ZERO
var tv := Vector3.ZERO
var r := Vector3.ZERO
var rv := Vector3.ZERO
var prev: Array = []
var body := Vector3.ZERO # desplazamiento del torso
var head := Vector3.ZERO # desplazamiento de la cabeza
var cam := Vector3.ZERO # lo que se mueve la cámara del casco (menos: no marea)
var kick := 0.0
var lim_t := 0.17 # cuánto se puede mover el torso (m) y la cabeza respecto del torso (m)
var lim_r := 0.11
var bump := 0.0 # sacudón reciente por baches y golpes (0..1): hace rebotar al cuerpo
var brace_door := 0.0 # copiloto: mano al marco de la puerta en una curva fuerte
var brace_mid := 0.0 # copiloto: mano a la jaula del centro

# miembros
var hbW := 0.0
var onBrake := 0.0
var press := 0.0
var aLs := 0.0
var braceT := 0.0
var side_sign := 1 # hacia qué lado empuja una curva con aLat > 0 (+1: hacia la puerta de este asiento)
var brace := 0.0

# volante
var grip: Array = [{"g": GRIP_H[0], "m": 0.0, "from": 0.0, "to": 0.0}, {"g": GRIP_H[1], "m": 0.0, "from": 0.0, "to": 0.0}]
var phi: Array = [0.0, 0.0]
var lift: Array = [0.0, 0.0]
var steer_vis := 0.0

# cambios
var shift_t := 9.0
var shift_up := true
var last_gear := -99
var t_look := 0.0

func _init(p_kT := 40.0, p_cT := 8.5, p_kH := 95.0, p_cH := 5.2, p_gain := 1.0) -> void:
	kT = p_kT
	cT = p_cT
	kH = p_kH
	cH = p_cH
	gain = p_gain

# ───────────────────────── utilidades ─────────────────────────
static func wrap_a(a: float) -> float:
	return atan2(sin(a), cos(a))

## peso de la mano en la palanca durante un cambio (0,5 s): va, empuja, vuelve
static func shift_w(tt: float) -> float:
	if tt > 0.55:
		return 0.0
	if tt < 0.16:
		var u := tt / 0.16
		return u * u * (3.0 - 2.0 * u)
	if tt < 0.3:
		return 1.0
	var u2 := (tt - 0.3) / 0.25
	return 1.0 - u2 * u2 * (3.0 - 2.0 * u2)

static func co_look(tt: float) -> float:
	return 0.10 * sin(tt * 0.41) + 0.05 * sin(tt * 1.07 + 1.3) + 0.03 * sin(tt * 2.3 + 0.4)

## p: CarSnapshot con el estado del auto
func step_forces(dt: float, p) -> void:
	dt = minf(dt, 0.05)
	if dt <= 0.0:
		return
	var fx := sin(p.yaw)
	var fz := cos(p.yaw)
	var lx := cos(p.yaw)
	var lz := -sin(p.yaw)
	var vL: float = p.vx * fx + p.vz * fz
	var vT: float = p.vx * lx + p.vz * lz
	var vY: float = p.vy
	var mL: float = p.aLong
	var mT: float = p.aLat
	var mY := 0.0
	if not prev.is_empty():
		var aL: float = (vL - float(prev[0])) / dt
		var aT: float = (vT - float(prev[1])) / dt + float(p.yawRate) * vL
		var aY: float = (vY - float(prev[2])) / dt
		# lo que no explican las gomas = golpe (choque, cordón, aterrizaje) → sacudón
		var dL: float = (aL - mL) * dt
		var dT: float = (aT - mT) * dt
		var dv := sqrt(dL * dL + dT * dT)
		if dv > 0.25:
			var f := minf(dv, 25.0) / dv
			tv.x += -dT * f * 0.02
			tv.z += -dL * f * 0.02
			rv.x += -dT * f * 0.045
			rv.z += -dL * f * 0.045
			kick = minf(1.0, kick + dv / 10.0)
		if absf(aY) > 7.0:
			var dy := clampf(aY * dt, -8.0, 8.0)
			tv.y += -dy * 0.028
			rv.y += -dy * 0.05
			bump = minf(1.0, bump + absf(dy) * 0.12)
		mY = clampf(aY, -15.0, 15.0)
	prev = [vL, vT, vY]
	# al acelerar los cuerpos van para atrás, al frenar bastante para adelante (el arnés los frena), en curva se van al costado
	var tgt := Vector3(
		clampf(-mT * 0.015 * gain, -lim_t * 0.85, lim_t * 0.85),
		clampf(-mY * 0.0032, -0.05, 0.05) + clampf(-absf(mT) * 0.0028, -0.04, 0.0),
		clampf(-mL * (0.018 if mL < 0.0 else 0.013) * gain, -lim_t * 0.8, lim_t * 0.9))
	var n := maxi(1, int(ceil(dt / 0.005)))
	var h := dt / float(n)
	for i in n:
		for ax in 3:
			var at := kT * (tgt[ax] - t[ax]) - cT * tv[ax]
			tv[ax] += at * h
			t[ax] = clampf(t[ax] + tv[ax] * h, -lim_t, lim_t)
			var ar := -kH * r[ax] - cH * rv[ax] - at * 1.3
			rv[ax] += ar * h
			r[ax] = clampf(r[ax] + rv[ax] * h, -lim_r, lim_r)
	kick = maxf(0.0, kick - dt * 2.0)
	bump = maxf(0.0, bump - dt * 2.5)
	body = t * 0.8
	head = t + r
	cam = t * 0.6 + r * 0.25

## mano al freno de mano, pie derecho en acelerador/freno, ataje del copiloto
func step_limbs(dt: float, p) -> void:
	var k := 1.0 - exp(-dt * 14.0)
	hbW += ((1.0 if p.hbIn else 0.0) - hbW) * k
	var br: float = p.brake
	var th: float = p.throttle
	onBrake += ((1.0 if br > 0.05 else 0.0) - onBrake) * (1.0 - exp(-dt * 18.0))
	press += ((br if br > 0.05 else th) - press) * (1.0 - exp(-dt * 16.0))
	var vl: float = p.vLong
	var aL: float = p.aLong
	aLs += (clampf(aL, -30.0, 30.0) - aLs) * (1.0 - exp(-dt * 10.0))
	# frenada fuerte (más de ~0,85 g): el copiloto se ataja con la mano en el tablero, y la saca al rato
	if vl > 6.0 and (aLs < -7.2 or (br > 0.85 and aLs < -5.5 and vl > 15.0)):
		braceT = 0.7
	else:
		braceT = maxf(0.0, braceT - dt)
	var bt := 1.0 if braceT > 0.0 else 0.0
	brace += (bt - brace) * (1.0 - exp(-dt * (10.0 if bt > 0.0 else 3.5)))
	# curva fuerte (más de ~0,8 g): el copiloto se agarra del marco de la puerta si lo empuja hacia afuera, o de la jaula si lo empuja hacia adentro
	var lat: float = p.aLat
	var door_t := 1.0 if (absf(lat) > 7.5 and vl > 8.0 and lat * float(side_sign) > 0.0) else 0.0
	var mid_t := 1.0 if (absf(lat) > 7.5 and vl > 8.0 and lat * float(side_sign) < 0.0) else 0.0
	brace_door += (door_t - brace_door) * (1.0 - exp(-dt * (9.0 if door_t > 0.0 else 2.2)))
	brace_mid += (mid_t - brace_mid) * (1.0 - exp(-dt * (9.0 if mid_t > 0.0 else 2.2)))

## cambios de marcha: arranca el gesto de la mano
func step_gear(dt: float, gear: int) -> void:
	if last_gear != -99 and gear != last_gear and gear > 0 and last_gear > 0:
		shift_t = 0.0
		shift_up = gear > last_gear
	last_gear = gear
	shift_t += dt

## manos en el volante: cada una agarra un punto del aro y gira con él; cuando se le acaba el brazo suelta y vuelve a agarrar
## más atrás (mano sobre mano, de a una). busy[i] = esa mano está ocupada (palanca / freno de mano).
func step_grip(dt: float, wheel: float, busy: Array) -> void:
	for i in 2:
		var s: Dictionary = grip[i]
		var j := 1 - i
		var H: float = GRIP_H[i]
		if busy[i]:
			s["m"] = -1.0
			phi[i] = H
			lift[i] = 0.0
			continue
		if s["m"] == -1.0:
			s["m"] = 0.0
			s["g"] = H - wheel
		if s["m"] > 0.0:
			s["m"] = maxf(0.0, s["m"] - dt / 0.18)
			var u: float = 1.0 - s["m"]
			var e := u * u * (3.0 - 2.0 * u)
			phi[i] = s["from"] + wrap_a(s["to"] - s["from"]) * e
			lift[i] = sin(u * PI) * 0.06
			if s["m"] == 0.0:
				s["g"] = s["to"] - wheel
			continue
		var ph: float = s["g"] + wheel
		var dev := wrap_a(ph - H)
		var oth: Dictionary = grip[j]
		var alone: bool = busy[j] or oth["m"] != 0.0
		var lim := 1.9 if alone else 1.15
		if absf(dev) > lim and (oth["m"] == 0.0 or busy[j]):
			s["from"] = ph
			s["to"] = H - signf(dev) * 0.5
			s["m"] = 1.0
		phi[i] = ph
		lift[i] = 0.0

## manos del copiloto sobre la hoja de notas (o en el tablero al atajarse)
func co_hands(x: float, by: float, bz: float, xD: float, C: Dictionary) -> Array:
	var hs := [
		{"side": "Left", "wrist": Vector3(x + 0.14, by, bz - 0.05), "fdir": Vector3(-0.5, -0.2, 0.8).normalized(), "back": Vector3(0.4, 1, 0.1).normalized()},
		{"side": "Right", "wrist": Vector3(x - 0.14, by, bz - 0.05), "fdir": Vector3(0.5, -0.2, 0.8).normalized(), "back": Vector3(-0.4, 1, 0.1).normalized()}]
	var w := brace
	if w > 0.01:
		var rr: Dictionary = hs[1]
		rr["wrist"] = (rr["wrist"] as Vector3).lerp(Vector3(-xD - 0.08, C["eyeY"] - 0.35, C["eyeZ"] + 0.46), w)
		rr["fdir"] = (rr["fdir"] as Vector3).lerp(Vector3(0.05, -0.45, 1).normalized(), w).normalized()
		rr["back"] = (rr["back"] as Vector3).lerp(Vector3(-0.15, 1, -0.3).normalized(), w).normalized()
	# curva fuerte: derecha al marco de la puerta, izquierda a la jaula del centro (se agarra para no irse de costado)
	var wd := brace_door
	if wd > 0.01:
		var rd: Dictionary = hs[1]
		rd["wrist"] = (rd["wrist"] as Vector3).lerp(Vector3(-xD - 0.28, C["eyeY"] - 0.30, C["eyeZ"] + 0.10), wd)
		rd["fdir"] = (rd["fdir"] as Vector3).lerp(Vector3(-0.3, -0.35, 0.9).normalized(), wd).normalized()
		rd["back"] = (rd["back"] as Vector3).lerp(Vector3(0.2, 1, -0.2).normalized(), wd).normalized()
	var wm := brace_mid
	if wm > 0.01:
		var lm: Dictionary = hs[0]
		lm["wrist"] = (lm["wrist"] as Vector3).lerp(Vector3(-xD + 0.30, C["eyeY"] - 0.36, C["eyeZ"] + 0.12), wm)
		lm["fdir"] = (lm["fdir"] as Vector3).lerp(Vector3(0.3, -0.3, 0.9).normalized(), wm).normalized()
		lm["back"] = (lm["back"] as Vector3).lerp(Vector3(-0.2, 1, -0.2).normalized(), wm).normalized()
	return hs

func right_foot(xD: float, fy: float, eZ: float) -> Vector3:
	var x := xD - 0.11 + onBrake * 0.10
	return Vector3(x, maxf(fy + 0.09, fy + 0.13 - press * 0.05), eZ + 0.62 + press * 0.09)
