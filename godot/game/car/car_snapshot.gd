extends RefCounted
## Historial de estados de un auto para dibujarlo suave.
## La física corre a 120 Hz un cuadro adelantada y en otros hilos; cada paso deja acá su estado con su hora. El dibujado
## pide el estado a una hora un poquito atrasada (sample) y lo interpola entre los dos pasos que la rodean: así el auto no
## "salta" cuando un cuadro avanza 2 pasos y el siguiente 3. Los hilos solo escriben (push) y el principal solo lee, nunca a la vez.

const RING := 24
const STRIDE := 67 # 19 del estado + 32 de datos por rueda (humo/marcas) + 16 datos para cabina y sonido

var data := PackedFloat64Array()
var count := 0

# estado interpolado (lo lee el dibujado, la cámara y el HUD)
var px := 0.0
var py := 0.0
var pz := 0.0
var pitch := 0.0
var roll := 0.0
var yaw := 0.0
var steerAngle := 0.0
var vLong := 0.0
var gear := 1
var rpm := 0.0
var wheel_s := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
var wheel_omega := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
## por rueda (8 valores): contacto, superficie, velocidad longitudinal, kappa, alfa, x, z del contacto, altura del piso (último paso)
var wheel_fx := PackedFloat64Array()
# datos para la cabina, la cámara y el sonido (interpolados los continuos; los demás, del último paso)
var vx := 0.0
var vy := 0.0
var vz := 0.0
var yawRate := 0.0
var aLong := 0.0
var aLat := 0.0
var load := 0.0
var throttle := 0.0
var brake := 0.0
var hbIn := false
var clutchLocked := false
var shiftT := 1.0
var limiter := false
var nitro := 0.0
var nitroOn := false
var trackHint := 0.0
## eventos que ocurrieron desde la última vez que se pidieron: ["shift_up", "shift_down", "limiter", ["land", v]…]
var pending_events: Array = []
var pending_impact := 0.0

func _init() -> void:
	data.resize(RING * STRIDE)
	wheel_fx.resize(32)

## Borra el historial y deja un solo estado a la hora t
func reset_to(t: float, p) -> void:
	count = 0
	push(t, p)
	push(t + 0.0001, p)
	sample(t)

func push(t: float, p) -> void:
	var o := (count % RING) * STRIDE
	data[o] = t
	data[o + 1] = p.px
	data[o + 2] = p.py
	data[o + 3] = p.pz
	data[o + 4] = p.pitch
	data[o + 5] = p.yaw
	data[o + 6] = p.roll
	data[o + 7] = p.steerAngle
	data[o + 8] = p.vLong
	data[o + 9] = p.rpm
	data[o + 10] = float(p.gear)
	for i in 4:
		data[o + 11 + i] = p.wheels[i].s
		data[o + 15 + i] = p.wheels[i].omega
		var w = p.wheels[i]
		var q := o + 19 + i * 8
		data[q] = 1.0 if w.contact else 0.0
		data[q + 1] = float(w.surf)
		data[q + 2] = w.vl
		data[q + 3] = w.kappa
		data[q + 4] = w.alpha
		data[q + 5] = w.wx
		data[q + 6] = w.wz
		data[q + 7] = w.gy
	var e := o + 51
	data[e] = p.vx
	data[e + 1] = p.vy
	data[e + 2] = p.vz
	data[e + 3] = p.yawRate
	data[e + 4] = p.aLong
	data[e + 5] = p.aLat
	data[e + 6] = p.load
	data[e + 7] = p.throttle
	data[e + 8] = p.brake
	data[e + 9] = 1.0 if p.hbIn else 0.0
	data[e + 10] = 1.0 if p.clutchLocked else 0.0
	data[e + 11] = p.shiftT
	data[e + 12] = 1.0 if p.limiter else 0.0
	data[e + 13] = p.nitro
	data[e + 14] = 1.0 if p.nitroOn else 0.0
	# eventos del paso (la física los borra en cada paso) y golpes de las ruedas
	for ev in p.events:
		match ev["type"]:
			"shift":
				pending_events.append("shift_up" if ev["up"] else "shift_down")
			"limiter":
				pending_events.append("limiter")
			"land":
				pending_events.append(["land", ev["v"]])
	for i in 4:
		pending_impact = maxf(pending_impact, p.wheels[i].impact)
		p.wheels[i].impact = 0.0
	count += 1

## Entrega (y borra) los eventos acumulados. Solo se llama con la física detenida (entre tareas).
func take_events() -> Array:
	var out := pending_events
	pending_events = []
	return out

func take_impact() -> float:
	var v := pending_impact
	pending_impact = 0.0
	return v

func sample(t: float) -> void:
	var n := mini(count, RING)
	if n == 0:
		return
	var newest := (count - 1) % RING
	var i0 := newest
	var i1 := newest
	var found := false
	for k in n:
		var idx := (count - 1 - k) % RING
		if data[idx * STRIDE] <= t:
			i0 = idx
			i1 = (idx + 1) % RING if k > 0 else idx
			found = true
			break
	if not found:
		i0 = (count - n) % RING
		i1 = i0
	var o0 := i0 * STRIDE
	var o1 := i1 * STRIDE
	var t0 := data[o0]
	var t1 := data[o1]
	var a := 0.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	px = lerpf(data[o0 + 1], data[o1 + 1], a)
	py = lerpf(data[o0 + 2], data[o1 + 2], a)
	pz = lerpf(data[o0 + 3], data[o1 + 3], a)
	pitch = lerpf(data[o0 + 4], data[o1 + 4], a)
	yaw = lerp_angle(data[o0 + 5], data[o1 + 5], a)
	roll = lerpf(data[o0 + 6], data[o1 + 6], a)
	steerAngle = lerpf(data[o0 + 7], data[o1 + 7], a)
	vLong = lerpf(data[o0 + 8], data[o1 + 8], a)
	rpm = lerpf(data[o0 + 9], data[o1 + 9], a)
	gear = int(data[o1 + 10])
	var on := newest * STRIDE
	for j in 32:
		wheel_fx[j] = data[on + 19 + j] # datos de las ruedas: los del último paso
	vx = lerpf(data[o0 + 51], data[o1 + 51], a)
	vy = lerpf(data[o0 + 52], data[o1 + 52], a)
	vz = lerpf(data[o0 + 53], data[o1 + 53], a)
	yawRate = lerpf(data[o0 + 54], data[o1 + 54], a)
	aLong = lerpf(data[o0 + 55], data[o1 + 55], a)
	aLat = lerpf(data[o0 + 56], data[o1 + 56], a)
	load = lerpf(data[o0 + 57], data[o1 + 57], a)
	throttle = lerpf(data[o0 + 58], data[o1 + 58], a)
	brake = lerpf(data[o0 + 59], data[o1 + 59], a)
	hbIn = data[o1 + 60] > 0.5
	clutchLocked = data[o1 + 61] > 0.5
	shiftT = data[o1 + 62]
	limiter = data[o1 + 63] > 0.5
	nitro = data[o1 + 64]
	nitroOn = data[o1 + 65] > 0.5
	for i in 4:
		wheel_s[i] = lerpf(data[o0 + 11 + i], data[o1 + 11 + i], a)
		wheel_omega[i] = lerpf(data[o0 + 15 + i], data[o1 + 15 + i], a)
