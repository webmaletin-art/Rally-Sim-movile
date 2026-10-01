## Física del auto — traducción fiel de la clase Physics de la versión HTML (js/main.js).
## Mismo modelo: 4 ruedas con suspensión independiente, neumático tipo Pacejka simplificado, motor + embrague + caja,
## diferenciales, ABS / control de tracción / estabilidad, aerodinámica, salto y aterrizaje.
## Se corre a 120 Hz con 2 sub-pasos. Nada de esto usa el motor de física de Godot: el auto es 100% nuestro.
## godot/tests/physics_test.gd compara paso a paso con la versión HTML (godot/tests/expected.json).
extends RefCounted

const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const TrackBase := preload("res://game/physics/track_base.gd")

const G := 9.81

class Wheel:
	var Fz0 := 0.0
	var x := 0.0
	var z := 0.0
	var front := false
	var left := false
	var k := 0.0
	var cB := 0.0
	var cR := 0.0
	var sMax := 0.0
	var sMin := 0.0
	var sStatic := 0.0
	var comp := 0.0
	var s := 0.0
	var contact := true
	var Fz := 0.0
	var jack := 0.0
	var omega := 0.0
	var drive := 0.0
	var brake := 0.0
	var kappa := 0.0
	var alpha := 0.0
	var gy := 0.0
	var surf := 0
	var wx := 0.0
	var wz := 0.0
	var fl := 0.0
	var slip := 0.0
	var impact := 0.0
	var vl := 0.0
	var cv := 0.0
	var camber := 0.0
	var latMul := 1.0
	var longMul := 1.0
	var toeRad := 0.0
	var press := 30.0
	var pkLat := 1.0
	var inertiaExtra := 0.0
	var jackTau := 0.0
	var jackLat := 0.0
	var absF := 1.0

var V: VehicleParams
var track: TrackBase
var wheels: Array[Wheel] = []
var a := 0.0
var b := 0.0
var manual := false
var reqShift := 0

# estado del cuerpo
var px := 0.0
var py := 0.0
var pz := 0.0
var yaw := 0.0
var pitch := 0.0
var roll := 0.0
var vx := 0.0
var vy := 0.0
var vz := 0.0
var yawRate := 0.0
var pitchRate := 0.0
var rollRate := 0.0
var vLong := 0.0
var vLat := 0.0
var aLong := 0.0
var aLat := 0.0
var steerAngle := 0.0
var rpm := 0.0
var gear := 1
var shiftT := 0.0
var clutchLocked := false
var tc := 1.0
var load := 0.0
var limiter := false
var wasLimiter := false
var events: Array = []
var revT := 0.0
var airTime := 0.0
var slip := 0.0
var contacts := 4
var nitro := 0.0
var nitroActive := false
var nitroOn := false
var engage := 0.0
var cutT := 0.0
var inGearT := 0.0
var brake := 0.0
var hbIn := false
var throttle := 0.0
var damage := 0.0
var powerMul := 1.0
var _good := Vector3.ZERO
var _goodYaw := 0.0
var _gt := 0
var tire_B := 1.0 # tan(PI / (2·tireFalloff)): constante del neumático (se calcula una vez)

func _init(p_track: TrackBase, p_params: VehicleParams) -> void:
	V = p_params
	track = p_track
	setup()
	reset()

func setup() -> void:
	a = V.wheelBase * (1.0 - V.weightFront)
	b = V.wheelBase * V.weightFront
	var def := [[V.trackF / 2.0, a, true, true], [-V.trackF / 2.0, a, true, false], [V.trackR / 2.0, -b, false, true], [-V.trackR / 2.0, -b, false, false]]
	var old := wheels
	wheels = []
	for i in 4:
		var d: Array = def[i]
		var front: bool = d[2]
		var left: bool = d[3]
		var w := Wheel.new()
		var load_w := V.mass * G * (V.weightFront if front else 1.0 - V.weightFront) / 2.0
		var mc := load_w / G
		var f := V.freqF if front else V.freqR
		var k := mc * pow(2.0 * PI * f, 2.0)
		var cc := 2.0 * sqrt(k * mc)
		var xs := load_w / k
		var ss := V.comHeight - V.wheelRadius + V.hardpointY
		var s_max := ss + xs
		var s_min := maxf(0.03, s_max - V.travel)
		w.Fz0 = load_w
		w.x = d[0]
		w.z = d[1]
		w.front = front
		w.left = left
		w.k = k
		w.cB = V.zetaBump * cc
		w.cR = V.zetaRebound * cc
		w.sMax = s_max
		w.sMin = s_min
		w.sStatic = ss
		w.comp = xs
		w.s = ss
		w.Fz = load_w
		var cam := V.camberF if front else V.camberR
		var gc := -cam
		w.camber = cam
		if cam > 0.0:
			w.latMul = 1.0 - 0.04 * cam
		elif gc <= 5.0:
			w.latMul = 1.0 + 0.07 * (1.0 - pow((gc - 2.5) / 2.5, 2.0))
		else:
			w.latMul = maxf(0.6, 1.0 - 0.035 * (gc - 5.0))
		w.longMul = 1.0 - 0.012 * absf(cam)
		w.toeRad = (V.toeF if front else V.toeR) * PI / 180.0 * (-1.0 if left else 1.0)
		w.press = V.pressF if front else V.pressR
		if w.press == 0.0:
			w.press = 30.0
		w.pkLat = clampf(1.0 - 0.006 * (w.press - 30.0), 0.85, 1.15)
		if old.size() == 4:
			w.omega = old[i].omega
			w.comp = old[i].comp
			w.s = old[i].s
		wheels.append(w)
	nitro = V.nitroCap
	tire_B = tan(PI / (2.0 * V.tireFalloff))

func reset(p_x := 0.35, p_z := 0.0, p_yaw := 0.0) -> void:
	px = p_x
	pz = p_z
	yaw = p_yaw
	var fx := sin(yaw)
	var fz := cos(yaw)
	var lx := cos(yaw)
	var lz := -sin(yaw)
	var gy := track.ground_y(px, pz)
	for w in wheels:
		gy = maxf(gy, track.ground_y(px + fx * w.z + lx * w.x, pz + fz * w.z + lz * w.x))
	py = gy + V.comHeight + 0.01
	pitch = 0.0
	roll = 0.0
	vx = 0.0
	vy = 0.0
	vz = 0.0
	yawRate = 0.0
	pitchRate = 0.0
	rollRate = 0.0
	vLong = 0.0
	vLat = 0.0
	aLong = 0.0
	aLat = 0.0
	steerAngle = 0.0
	rpm = V.idleRpm
	gear = 1
	shiftT = 0.0
	clutchLocked = false
	tc = 1.0
	load = 0.0
	limiter = false
	events = []
	revT = 0.0
	airTime = 0.0
	slip = 0.0
	contacts = 4
	nitro = V.nitroCap
	nitroActive = false
	for w in wheels:
		w.comp = w.sMax - w.sStatic
		w.s = w.sStatic
		w.omega = 0.0
		w.contact = true
		w.jack = 0.0

func torque_at(r: float) -> float:
	var c := V.torqueCurve
	if r <= c[0][0]:
		return c[0][1]
	for i in range(1, c.size()):
		if r <= c[i][0]:
			var u: float = (r - c[i - 1][0]) / (c[i][0] - c[i - 1][0])
			return c[i - 1][1] + (c[i][1] - c[i - 1][1]) * u
	return c[c.size() - 1][1]

func tire_curve(s: float) -> float:
	return sin(V.tireFalloff * atan(tire_B * s))

## Un paso de física (dt = 1/120). input: {throttle, brake, steer, handbrake, nitro, shift}
func step(dt: float, throttle_in: float, brake_in: float, steer_in: float, handbrake_in: bool, nitro_in := false, shift_in := 0) -> void:
	if shift_in != 0:
		reqShift = shift_in
	var n := 2
	var h := dt / n
	for i in n:
		_sub(h, throttle_in, brake_in, steer_in, handbrake_in, nitro_in)
	if not is_finite(px + py + pz + vx + vy + vz + yaw + pitch + roll + yawRate):
		push_warning("physics NaN → recover")
		reset(_good.x, _good.z, _goodYaw)
	else:
		_gt = (_gt + 1) % 60
		if _gt == 0 or _good == Vector3.ZERO:
			_good = Vector3(px, 0.0, pz)
			_goodYaw = yaw

## Dirección sensible a la velocidad
func steer_scale(spd: float) -> float:
	var bb := absf(atan2(vLat, maxf(1.0, absf(vLong))))
	var lim := V.wheelBase * V.mu * 9.81 / (spd * spd + 4.0) * 1.1 + V.slipPeakLat * 0.35 + minf(0.35, bb * 1.0)
	return clampf(lim / V.maxSteer, 0.12, 1.0)

func _sub(h: float, thr_in: float, brk_in: float, steer_in: float, handbrake: bool, nitro_in: bool) -> void:
	var g := G
	var R := V.wheelRadius
	var m := V.mass
	var W := wheels
	var thr := thr_in
	var brk := brk_in
	var spd := sqrt(vx * vx + vz * vz)
	# caja automática: frenando parado pasa a reversa
	if not manual:
		if gear == 0:
			gear = 1
		if gear > 0 and brk > 0.5 and thr < 0.05 and spd < 0.6 and vLong < 0.4:
			revT += h
			if revT > 0.35:
				gear = -1
				revT = 0.0
		elif gear > 0:
			revT = 0.0
		if gear == -1:
			if thr > 0.1 and vLong > -0.6:
				gear = 1
			else:
				var t := thr
				thr = brk
				brk = t
	var sf := steer_scale(spd)
	var tgt := -steer_in * V.maxSteer * sf
	steerAngle += (tgt - steerAngle) * (1.0 - exp(-h * V.steerResponse))
	var sy := sin(yaw)
	var cy := cos(yaw)
	var fx := sy
	var fz := cy
	var lx := cy
	var lz := -sy
	var v_long := vx * fx + vz * fz
	var v_lat := vx * lx + vz * lz
	var sp := sin(pitch)
	var sr := sin(roll)
	var cnt := 0
	for w in W:
		w.wx = px + fx * w.z + lx * w.x
		w.wz = pz + fz * w.z + lz * w.x
		var gi := track.ground_info(w.wx, w.wz)
		w.gy = gi.x
		w.surf = int(gi.y)
		var ay := py + V.hardpointY + w.x * sr - w.z * sp
		var d := ay - (gi.x + R)
		var prev_contact := w.contact
		var prev_comp := w.comp
		if d >= w.sMax:
			w.contact = false
			w.comp = 0.0
			w.s = w.sMax
			w.Fz = 0.0
			w.cv = 0.0
		else:
			w.contact = true
			cnt += 1
			var comp := w.sMax - d
			var cv := (comp - prev_comp) / h if prev_contact else minf(6.0, -vy + 0.0)
			w.comp = comp
			w.cv = cv
			w.s = maxf(d, w.sMin)
			var F := w.k * comp + (w.cB if cv > 0.0 else w.cR) * cv
			if d < w.sMin:
				F += V.bumpStopK * (w.sMin - d) + (V.bumpStopC * cv if cv > 0.0 else 0.0)
			w.Fz = maxf(0.0, F)
			if not prev_contact or cv > 1.0:
				w.impact = maxf(w.impact, absf(cv) * (1.6 if d < w.sMin else 1.0))
	# barras estabilizadoras (delantera y trasera)
	if W[0].contact and W[1].contact:
		var dfF := V.arbF * (W[0].comp - W[1].comp)
		W[0].Fz = maxf(0.0, W[0].Fz + dfF)
		W[1].Fz = maxf(0.0, W[1].Fz - dfF)
	if W[2].contact and W[3].contact:
		var dfR := V.arbR * (W[2].comp - W[3].comp)
		W[2].Fz = maxf(0.0, W[2].Fz + dfR)
		W[3].Fz = maxf(0.0, W[3].Fz - dfR)
	contacts = cnt
	brake = brk
	hbIn = handbrake
	nitroOn = nitro_in
	_engine(h, thr, brk, v_long, handbrake)
	var FL := 0.0
	var FT := 0.0
	var Mz := 0.0
	var tauP := 0.0
	var tauR := 0.0
	var FzSum := 0.0
	var maxSlip := 0.0
	var hgt := maxf(0.3, py - (W[0].gy + W[1].gy + W[2].gy + W[3].gy) / 4.0)
	var grip_mul := track.grip_mul
	for w in W:
		var I := V.wheelInertia + w.inertiaExtra
		var fl := 0.0
		var k := 0.0
		if w.contact:
			var Ft0 := maxf(0.0, w.Fz + w.jack)
			var vpl := v_lat + yawRate * w.z
			var vpg := v_long - yawRate * w.x
			var dl := (steerAngle if w.front else 0.0) + w.toeRad
			var cs := cos(dl)
			var sn := sin(dl)
			var vl := vpl * sn + vpg * cs
			var vt := vpl * cs - vpg * sn
			w.vl = vl
			var den := maxf(absf(vl), 2.5)
			var kap := (w.omega * R - vl) / den
			var alp := atan2(vt, den)
			w.kappa = kap
			w.alpha = alp
			var po := 32.0 if w.surf == 0 else 26.0
			var sg := V.surfGrip[w.surf] if w.surf >= 0 and w.surf < 7 else 0.4
			var mu := grip_mul * V.mu * sg * (V.gripFront if w.front else V.gripRear) * (1.0 - 0.0009 * (w.press - po) * (w.press - po))
			var sx := kap / V.slipPeakLong
			var sy2 := alp / (V.slipPeakLat * w.pkLat)
			var s := sqrt(sx * sx + sy2 * sy2)
			var F := 0.0
			var Ft := 0.0
			var lsens := clampf(1.0 - 0.12 * (Ft0 / w.Fz0 - 1.0), 0.74, 1.12)
			if s > 1e-6:
				var tcs := tire_curve(s)
				F = mu * lsens * Ft0 * tcs
				fl = F * sx / s * w.longMul
				Ft = -F * sy2 / s * w.latMul
				var d1 := (tire_curve(s + 0.02) - tcs) / 0.02
				k = mu * Ft0 * maxf(0.08, d1 * absf(sx) / s + (0.3 if s < 1.0 else 0.0)) / V.slipPeakLong * R / den
			else:
				k = mu * Ft0 * 2.0 / V.slipPeakLong * R / den
			var rr := V.rolling * Ft0 * clampf(vl / 0.5, -1.0, 1.0)
			var flT := fl - rr
			var fbLat := flT * sn + Ft * cs
			var fbLong := flT * cs - Ft * sn
			FL += fbLong
			FT += fbLat
			Mz += w.z * fbLat - w.x * fbLong
			var anti: float
			if w.front:
				anti = V.antiDive if fbLong < 0.0 else 0.15
			else:
				anti = V.antiSquat if fbLong > 0.0 else 0.2
			tauP += -fbLong * hgt * (1.0 - anti)
			tauR += fbLat * (hgt - V.rollCenter)
			w.jackTau = -fbLong * hgt * anti
			w.jackLat = fbLat * V.rollCenter
			w.slip = s
			maxSlip = maxf(maxSlip, s)
			w.fl = fl
		else:
			w.slip = 0.0
			w.kappa = 0.0
			w.alpha = 0.0
			w.jackTau = 0.0
			w.jackLat = 0.0
			w.fl = 0.0
		FzSum += w.Fz
		tauP += -w.Fz * w.z
		tauR += w.Fz * w.x
		var T := w.drive
		var om := (w.omega + h / I * (T - R * fl + R * k * w.omega)) / (1.0 + h / I * R * k)
		var bd := w.brake * h / I
		if absf(om) <= bd:
			om = 0.0
		else:
			om -= signf(om) * bd
		if not w.contact:
			om *= exp(-h * 0.3)
		w.omega = om
	var jF := 0.0
	var jR := 0.0
	var jLF := 0.0
	var jLR := 0.0
	for w in W:
		if w.front:
			jF += w.jackTau
			jLF += w.jackLat
		else:
			jR += w.jackTau
			jLR += w.jackLat
	var jt := (jF + jR) / V.wheelBase / 2.0
	for w in W:
		var lat := (jLF / V.trackF if w.front else jLR / V.trackR) / 2.0
		w.jack = (jt if w.front else -jt) + (-lat if w.left else lat)
	slip = maxf(0.0, maxSlip - 1.0)
	var slL := ((W[0].gy + W[1].gy) - (W[2].gy + W[3].gy)) / 2.0 / V.wheelBase
	var slT := ((W[0].gy + W[2].gy) - (W[1].gy + W[3].gy)) / 2.0 / ((V.trackF + V.trackR) / 2.0)
	var drag := V.dragCoef * spd
	var Fx := fx * FL + lx * FT - drag * vx - FzSum * (fx * slL + lx * slT)
	var Fzw := fz * FL + lz * FT - drag * vz - FzSum * (fz * slL + lz * slT)
	var DF := 0.0
	var DR := 0.0
	if V.aeroF != 0.0 or V.aeroR != 0.0:
		var q := 0.6 * spd * spd
		DF = q * V.aeroF
		DR = q * V.aeroR
		tauP += DF * a - DR * b
	vx += Fx / m * h
	vz += Fzw / m * h
	vy += ((FzSum - DF - DR) / m - g) * h
	var kinYaw := v_long * tan(steerAngle) / V.wheelBase
	var yMax := V.mu * 9.81 * 0.95 / maxf(spd, 3.0)
	var yT := clampf(kinYaw, -yMax, yMax)
	if cnt > 0 and (absf(yawRate) > absf(yT) or yawRate * yT < 0.0):
		Mz += -V.stabilityAssist * V.Izz * 3.0 * (yawRate - yT) * clampf(spd / 8.0, 0.0, 1.0)
	if cnt > 0 and spd < 3.0:
		Mz += -V.Izz * 2.0 * (yawRate - kinYaw) * (1.0 - spd / 3.0)
	yawRate += Mz / V.Izz * h
	pitchRate += tauP / V.Iyy * h
	rollRate += tauR / V.Ixx * h
	if cnt == 0:
		pitchRate *= exp(-h * 0.4)
		rollRate *= exp(-h * 0.4)
		yawRate *= exp(-h * 0.2)
		airTime += h
	else:
		if airTime > 0.25:
			var mi := 0.0
			for w in W:
				mi = maxf(mi, w.impact)
			events.append({"type": "land", "v": mi})
		airTime = 0.0
	px += vx * h
	py += vy * h
	pz += vz * h
	yaw += yawRate * h
	pitch += pitchRate * h
	roll += rollRate * h
	if absf(pitch) > 0.6:
		pitch = signf(pitch) * 0.6
		pitchRate = 0.0
	if absf(roll) > 0.6:
		roll = signf(roll) * 0.6
		rollRate = 0.0
	var gc := track.ground_y(px, pz)
	if py < gc + 0.3:
		py = gc + 0.3
		if vy < 0.0:
			vy = 0.0
	if spd < 0.25 and thr < 0.05 and cnt == 4:
		vx *= 0.8
		vz *= 0.8
		yawRate *= 0.8
		for w in W:
			w.omega *= 0.8
	var nL := vx * fx + vz * fz
	var nT := vx * lx + vz * lz
	aLong += (((nL - v_long) / h) - aLong) * (1.0 - exp(-h * 12.0))
	aLat += ((FT / m) - aLat) * (1.0 - exp(-h * 12.0))
	vLong = nL
	vLat = nT

func _engine(h: float, thr: float, brk: float, v_long: float, handbrake: bool) -> void:
	var W := wheels
	var fr := V.frontDriveRatio
	var rr := V.rearDriveRatio
	if V.driveType == "RWD":
		fr = 0.0
		rr = 1.0
	elif V.driveType == "FWD":
		fr = 1.0
		rr = 0.0
	var tot := fr + rr
	if tot == 0.0:
		tot = 1.0
	fr /= tot
	rr /= tot
	var wF := (W[0].omega + W[1].omega) / 2.0
	var wR := (W[2].omega + W[3].omega) / 2.0
	var wAvg := wF * fr + wR * rr
	var ratio := 0.0
	if gear > 0:
		ratio = V.gears[gear - 1] * V.finalDrive
	elif gear < 0:
		ratio = -V.reverseRatio * V.finalDrive
	var rpmW := absf(wAvg * ratio) * 60.0 / (2.0 * PI)
	if shiftT > 0.0:
		shiftT -= h
	# neutro: el motor gira libre
	if gear == 0:
		clutchLocked = false
		engage = 0.0
		cutT = maxf(0.0, cutT - h)
		var tg := V.idleRpm if cutT > 0.0 else V.idleRpm + thr * (V.maxRpm * 1.02 - V.idleRpm)
		rpm += (tg - rpm) * (1.0 - exp(-h * (7.0 if tg > rpm else 2.5)))
		if rpm >= V.maxRpm:
			rpm = V.maxRpm
			cutT = 0.07
	elif not clutchLocked:
		if thr > 0.05:
			engage = minf(1.0, engage + h / V.clutchTime)
		else:
			engage = 0.0
		var free := V.idleRpm + thr * (V.launchRpm - V.idleRpm)
		var target := maxf(rpmW, free + (maxf(rpmW, V.idleRpm) - free) * engage)
		rpm += (target - rpm) * (1.0 - exp(-h * (10.0 if thr > 0.05 else 4.0)))
		if thr > 0.05 and (rpmW >= rpm * 0.97 or engage >= 1.0):
			clutchLocked = true
		if thr < 0.05 and rpmW > V.idleRpm * 1.2:
			clutchLocked = true
	else:
		rpm += (maxf(V.idleRpm * 0.85, rpmW) - rpm) * (1.0 - exp(-h * 30.0))
		if rpmW < V.idleRpm * 0.8 and (thr < 0.05 or brk > 0.3):
			clutchLocked = false
			engage = 0.0
	limiter = rpm >= V.maxRpm
	var Te: float
	var Tmax := V.peakTorque * V.powerScale * torque_at(rpm)
	if shiftT > 0.0:
		Te = 0.0
	elif clutchLocked:
		Te = thr * Tmax - (1.0 - thr) * V.engineBrake * (rpm / V.maxRpm)
		if limiter:
			Te = minf(Te, -V.engineBrake * 0.5)
	else:
		Te = thr * Tmax
	# limitador de velocidad de fábrica
	if V.vGov > 0.0 and gear > 0 and Te > 0.0:
		var kmh := absf(v_long) * 3.6
		if kmh > V.vGov - 4.0:
			Te *= maxf(0.0, minf(1.0, (V.vGov - kmh) / 4.0))
	if limiter and not wasLimiter:
		events.append({"type": "limiter"})
	wasLimiter = limiter
	var mk := 0.0
	var sgn_ratio := signf(ratio) if ratio != 0.0 else 1.0
	for w in W:
		if w.contact and ((w.front and fr > 0.0) or (not w.front and rr > 0.0)):
			mk = maxf(mk, w.kappa * sgn_ratio)
	if V.tractionControl and thr > 0.05:
		if mk > V.tcSlip:
			tc = maxf(0.2, tc - h * 6.0)
		else:
			tc = minf(1.0, tc + h * 2.5)
	else:
		tc = minf(1.0, tc + h * 4.0)
	nitroActive = false
	if V.nitroCap > 0.0:
		if nitroOn and nitro > 0.02 and thr > 0.3 and gear > 0:
			nitro = maxf(0.0, nitro - h)
			nitroActive = true
		elif not nitroOn:
			nitro = minf(V.nitroCap, nitro + h * V.nitroCap / 35.0)
	if Te > 0.0:
		Te *= tc * (1.0 + V.nitroBoost if nitroActive else 1.0) * (1.0 - 0.35 * damage) * powerMul
	var Tw := Te * ratio * V.efficiency
	var couple := V.centerDiffBias * 600.0 * (wF - wR)
	var both := fr > 0.0 and rr > 0.0
	var Tf := Tw * fr - (couple if both else 0.0)
	var Tr := Tw * rr + (couple if both else 0.0)
	var ie := V.engineInertia * ratio * ratio if clutchLocked else 0.0
	var cap := 0.45 * V.wheelInertia / h
	var dF := W[0].omega - W[1].omega
	var dR := W[2].omega - W[3].omega
	var lF := signf(dF) * minf(V.lsd * absf(dF), cap * absf(dF))
	var lR := signf(dR) * minf(V.lsd * absf(dR), cap * absf(dR))
	for w in W:
		var lsd_t := lF if w.front else lR
		w.drive = (Tf if w.front else Tr) / 2.0 - lsd_t * (1.0 if w.left else -1.0) * (1.0 if (clutchLocked or thr > 0.05) else 0.3)
		w.inertiaExtra = ie * (fr if w.front else rr) / 2.0
		if V.abs and brk > 0.05:
			var vs := signf(w.vl) if w.vl != 0.0 else 1.0
			if w.kappa * vs < -V.absSlip:
				w.absF = maxf(0.25, w.absF - h * 9.0)
			else:
				w.absF = minf(1.0, w.absF + h * 4.0)
		else:
			w.absF = 1.0
		w.brake = brk * w.absF * V.brakeTorque * (V.brakeBiasFront if w.front else 1.0 - V.brakeBiasFront) / 2.0
		if handbrake and not w.front:
			w.brake = maxf(w.brake, V.brakeTorque * 0.55)
	# caja manual: el piloto pide el cambio
	if manual and reqShift != 0:
		var dd := reqShift
		reqShift = 0
		var wr := absf(vLong) / V.wheelRadius * V.finalDrive * 9.549
		if dd > 0:
			if gear == -1:
				gear = 0
			elif gear == 0:
				gear = 1
			elif gear < V.gears.size() and shiftT <= 0.0:
				gear += 1
				shiftT = V.shiftTime
				inGearT = 0.0
				events.append({"type": "shift", "up": true})
		else:
			if gear > 1 and shiftT <= 0.0:
				if wr * V.gears[gear - 2] < V.maxRpm * 1.03:
					gear -= 1
					shiftT = V.shiftTime * 0.6
					inGearT = 0.0
					events.append({"type": "shift", "up": false})
				else:
					events.append({"type": "shiftDenied"})
			elif gear == 1:
				gear = 0
			elif gear == 0 and absf(vLong) < 1.2:
				gear = -1
	# caja automática secuencial
	if not manual and gear > 0 and clutchLocked and shiftT <= 0.0:
		inGearT += h
		var wr2 := absf(vLong) / V.wheelRadius * V.finalDrive * 9.549
		var g0: float = wr2 * V.gears[gear - 1]
		var gm: float = wr2 * V.gears[gear - 2] if gear > 1 else 0.0
		var up: bool = gear < V.gears.size() and thr > 0.1 and contacts >= 2 and inGearT > 0.45 and ((rpm > V.shiftUpRpm and g0 > V.shiftUpRpm * 0.8) or g0 > V.maxRpm * 0.99)
		var brk_down: bool = brk > 0.25 and gear > 1 and inGearT > 0.28 and g0 < V.shiftDownRpm * 1.7 and gm < V.shiftUpRpm * 0.92
		var lug_down: bool = gear > 1 and rpm < V.shiftDownRpm * (1.0 if thr > 0.6 else 0.6) and inGearT > 0.2 and gm < V.shiftUpRpm * 0.95
		if up:
			gear += 1
			shiftT = V.shiftTime
			inGearT = 0.0
			events.append({"type": "shift", "up": true})
		elif brk_down or lug_down:
			gear -= 1
			shiftT = V.shiftTime * 0.6
			inGearT = 0.0
			events.append({"type": "shift", "up": false})
	var l := (Te / maxf(1.0, Tmax) if Te > 0.0 else 0.0) if clutchLocked else thr * 0.7
	load += (l - load) * (1.0 - exp(-h * 10.0))
	throttle = thr
