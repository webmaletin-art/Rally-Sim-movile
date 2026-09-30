extends RefCounted
## Historial de estados de un auto para dibujarlo suave.
## La física corre a 120 Hz un cuadro adelantada y en otros hilos; cada paso deja acá su estado con su hora. El dibujado
## pide el estado a una hora un poquito atrasada (sample) y lo interpola entre los dos pasos que la rodean: así el auto no
## "salta" cuando un cuadro avanza 2 pasos y el siguiente 3. Los hilos solo escriben (push) y el principal solo lee, nunca a la vez.

const RING := 24
const STRIDE := 51 # 19 del estado + 32 de datos por rueda para humo/marcas

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
	count += 1

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
	for i in 4:
		wheel_s[i] = lerpf(data[o0 + 11 + i], data[o1 + 11 + i], a)
		wheel_omega[i] = lerpf(data[o0 + 15 + i], data[o1 + 15 + i], a)
