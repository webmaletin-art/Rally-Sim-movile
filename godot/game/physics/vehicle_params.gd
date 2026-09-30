## Parámetros de un auto (los mismos nombres que en la versión HTML: js/main.js → VEHICLES y js/carbuild.js → buildParams).
## Se cargan de un Dictionary (vehicles.json + mejoras + ajuste) a campos tipados: es mucho más rápido que leer el diccionario en cada paso.
extends RefCounted

var mass := 2000.0
var weightFront := 0.5
var comHeight := 0.8
var Ixx := 900.0
var Iyy := 3500.0
var Izz := 4000.0
var wheelBase := 2.9
var trackF := 1.8
var trackR := 1.8
var wheelRadius := 0.4
var rimRadius := 0.23
var tireWidth := 0.3
var wheelInertia := 8.0
var rideOffset := 0.0
var hardpointY := 0.0
var travel := 0.3
var freqF := 1.3
var freqR := 1.3
var zetaBump := 0.3
var zetaRebound := 0.55
var arbF := 4000.0
var arbR := 2000.0
var bumpStopK := 300000.0
var bumpStopC := 9000.0
var antiSquat := 0.5
var antiDive := 0.4
var rollCenter := 0.2
var mu := 1.0
var gripFront := 1.0
var gripRear := 1.0
var slipPeakLong := 0.12
var slipPeakLat := 0.16
var tireFalloff := 1.4
var rolling := 0.02
## Agarre por superficie: 0 asfalto · 1 tierra · 2 banquina · 3 pasto · 4 afuera · 5 barro (los que faltan valen 0,4)
var surfGrip := PackedFloat64Array([1.0, 0.6, 0.7, 0.45, 0.4, 0.35])
var peakTorque := 1000.0
var idleRpm := 800.0
var launchRpm := 2500.0
var maxRpm := 7000.0
var vGov := 0.0
var torqueCurve: Array = []
var engineInertia := 0.3
var engineBrake := 150.0
var gears := PackedFloat64Array()
var reverseRatio := 3.0
var finalDrive := 4.0
var efficiency := 0.88
var clutchTime := 1.0
var shiftUpRpm := 6500.0
var shiftDownRpm := 3000.0
var shiftTime := 0.15
var driveType := "AWD"
var frontDriveRatio := 0.5
var rearDriveRatio := 0.5
var centerDiffBias := 0.4
var lsd := 1000.0
var tractionControl := true
var tcSlip := 0.2
var brakeTorque := 13000.0
var brakeBiasFront := 0.6
var abs := true
var absSlip := 0.14
var maxSteer := 0.5
var steerResponse := 9.0
var dragCoef := 1.0
var stabilityAssist := 0.3
var powerScale := 1.0
var aeroF := 0.0
var aeroR := 0.0
var nitroCap := 0.0
var nitroBoost := 0.0
var camberF := -1.0
var camberR := -0.5
var toeF := 0.0
var toeR := 0.1
var pressF := 30.0
var pressR := 30.0
var turboLvl := 0
var firingOrder := 4.0

const SURF_NAMES := ["asphalt", "dirt", "shoulder", "grass", "outside", "mud"]

static func from_dict(d: Dictionary) -> RefCounted:
	var p := new()
	for k in d.keys():
		if k == "surfGrip":
			var sg: Dictionary = d[k]
			for i in SURF_NAMES.size():
				if sg.has(SURF_NAMES[i]):
					p.surfGrip[i] = float(sg[SURF_NAMES[i]])
		elif k == "gears":
			p.gears = PackedFloat64Array(d[k])
		elif k == "torqueCurve":
			p.torqueCurve = d[k]
		elif k in p:
			var cur: Variant = p.get(k)
			if typeof(cur) == TYPE_FLOAT:
				p.set(k, float(d[k]))
			elif typeof(cur) == TYPE_INT:
				p.set(k, int(d[k]))
			else:
				p.set(k, d[k])
	return p
