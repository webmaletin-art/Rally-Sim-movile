extends RefCounted
## Foto del estado de un auto para dibujarlo. La física corre un cuadro adelantada en otros hilos; el dibujado y la cámara
## leen esta copia (nunca el estado vivo), así no hay carreras de datos entre hilos.

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

func capture(p) -> void:
	px = p.px
	py = p.py
	pz = p.pz
	pitch = p.pitch
	roll = p.roll
	yaw = p.yaw
	steerAngle = p.steerAngle
	vLong = p.vLong
	gear = p.gear
	rpm = p.rpm
	for i in 4:
		wheel_s[i] = p.wheels[i].s
		wheel_omega[i] = p.wheels[i].omega
