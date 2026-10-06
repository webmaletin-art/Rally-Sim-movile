extends RefCounted
## Arma la física final de un auto: fábrica + piezas del taller + ajuste fino + ayudas (js/carbuild.js).
## Devuelve un Dictionary con los mismos campos que VehicleParams (VehicleParams.from_dict lo convierte).
## godot/tests/build_test.gd lo compara con el resultado del código real de la versión HTML.

static var cat: Dictionary

static func catalog() -> Dictionary:
	if cat.is_empty():
		cat = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/catalog.json"))
	return cat

static func upgrade(id: String) -> Dictionary:
	for u in catalog()["upgrades"]:
		if u["id"] == id:
			return u
	return {}

static func tire(id: String) -> Dictionary:
	for t in catalog()["tires"]:
		if t["id"] == id:
			return t
	for t in catalog()["tires"]:
		if t["id"] == "street":
			return t
	return {}

static func default_tune(base: Dictionary) -> Dictionary:
	var t := {}
	for g in catalog()["tune"]:
		for i in g["items"]:
			t[i["k"]] = float(i["def"])
	t["bias"] = round(float(base["brakeBiasFront"]) * 100.0)
	t["split"] = round(float(base["frontDriveRatio"]) * 100.0)
	return t

static func unlocks_of(upg: Dictionary) -> Dictionary:
	var s := {}
	for u in catalog()["upgrades"]:
		var lvl := int(upg.get(u["id"], 0))
		for i in range(1, lvl + 1):
			for x in u["levels"][i].get("unlock", []):
				s[x] = true
	return s

static func effects_of(upg: Dictionary) -> Dictionary:
	var e := {}
	for k in ["power", "rpm", "inertia", "mass", "com", "yaw", "brake", "freq", "arb", "damp", "travel", "clutch", "shift", "lsd", "aeroF", "aeroR", "drag", "nitro", "nitroBoost", "steer", "vgov"]:
		e[k] = 0.0
	for u in catalog()["upgrades"]:
		var lvl := int(upg.get(u["id"], 0))
		if lvl == 0:
			continue
		var eff: Dictionary = u["levels"][lvl].get("eff", {})
		for k in eff:
			e[k] += float(eff[k])
	return e

## base: preset de fábrica (vehicles.json) · car: estado guardado {upg, tires, tune, paint…} · assists: {abs, tc, stab}
static func build_params(base: Dictionary, car: Dictionary, assists := {"abs": true, "tc": 50.0, "stab": 30.0}) -> Dictionary:
	var V: Dictionary = base.duplicate(true)
	var upg: Dictionary = car.get("upg", {})
	var e := effects_of(upg)
	var un := unlocks_of(upg)
	var lab: Dictionary = car.get("lab", {}) # taller de prueba (pausa): todo desbloqueado y ajustes extra; nunca se guarda
	if lab.get("all", false) == true:
		for k in ["springs", "damp", "arb", "height", "camber", "toe", "final", "lsd", "split", "aero", "stance", "drift"]:
			un[k] = true
		e["aeroF"] = maxf(e["aeroF"], 0.7)
		e["aeroR"] = maxf(e["aeroR"], 1.1)
		e["drag"] = maxf(e["drag"], 0.06)
	V["turboLvl"] = int(upg.get("turbo", 0))
	var tu := default_tune(base)
	var ct: Dictionary = car.get("tune", {})
	for k in ct:
		tu[k] = float(ct[k])
	var has := func(k: String) -> bool: return un.has(k)
	var pct := func(k: String) -> float: return float(tu[k]) / 100.0
	# motor
	V["powerScale"] = 1.0 + e["power"]
	var vg := float(base.get("vGov", 0.0))
	if vg != 0.0:
		V["vGov"] = 0.0 if e["vgov"] >= 500.0 else vg + e["vgov"]
	else:
		V["vGov"] = 0.0
	V["maxRpm"] = float(base["maxRpm"]) * (1.0 + e["rpm"])
	V["shiftUpRpm"] = float(base["shiftUpRpm"]) * (1.0 + e["rpm"])
	V["engineInertia"] = float(base["engineInertia"]) * (1.0 + e["inertia"])
	# peso
	var mm: float = 1.0 + e["mass"]
	V["mass"] = float(base["mass"]) * mm
	V["Ixx"] = float(base["Ixx"]) * mm
	V["Iyy"] = float(base["Iyy"]) * mm
	V["Izz"] = float(base["Izz"]) * (mm + e["yaw"])
	V["comHeight"] = float(base["comHeight"]) * (1.0 + e["com"])
	# frenos
	V["brakeTorque"] = float(base["brakeTorque"]) * (1.0 + e["brake"]) * pct.call("bpress")
	V["brakeBiasFront"] = float(tu["bias"]) / 100.0
	# suspensión
	V["freqF"] = float(base["freqF"]) * (1.0 + e["freq"]) * (pct.call("springF") if has.call("springs") else 1.0)
	V["freqR"] = float(base["freqR"]) * (1.0 + e["freq"]) * (pct.call("springR") if has.call("springs") else 1.0)
	V["zetaBump"] = float(base["zetaBump"]) * (1.0 + e["damp"]) * (pct.call("bump") if has.call("damp") else 1.0)
	V["zetaRebound"] = float(base["zetaRebound"]) * (1.0 + e["damp"]) * (pct.call("rebound") if has.call("damp") else 1.0)
	V["arbF"] = float(base["arbF"]) * (1.0 + e["arb"]) * (pct.call("arbF") if has.call("arb") else 1.0)
	V["arbR"] = float(base["arbR"]) * (1.0 + e["arb"]) * (pct.call("arbR") if has.call("arb") else 1.0)
	V["travel"] = float(base["travel"]) * (1.0 + e["travel"])
	if has.call("height"):
		V["comHeight"] = float(V["comHeight"]) + float(tu["height"]) / 1000.0
	V["rideOffset"] = float(base.get("rideOffset", 0.0)) + (float(tu["height"]) / 1000.0 if has.call("height") else 0.0)
	# alineación
	V["camberF"] = float(tu["camberF"]) if has.call("camber") else -1.0
	V["camberR"] = float(tu["camberR"]) if has.call("camber") else -0.5
	if has.call("stance"):
		V["camberF"] = float(V["camberF"]) - float(tu["stanceCamber"])
		V["camberR"] = float(V["camberR"]) - float(tu["stanceCamber"])
	V["toeF"] = float(tu["toeF"]) if has.call("toe") else 0.0
	V["toeR"] = float(tu["toeR"]) if has.call("toe") else 0.1
	V["maxSteer"] = float(base["maxSteer"]) * (1.0 + e["steer"]) * pct.call("steer")
	# transmisión
	V["clutchTime"] = float(base["clutchTime"]) * (1.0 + e["clutch"])
	V["shiftTime"] = float(base["shiftTime"]) * (1.0 + e["shift"])
	V["lsd"] = float(base["lsd"]) * (1.0 + e["lsd"]) * (pct.call("lsd") if has.call("lsd") else 1.0)
	var sp := clampf(float(tu["split"]), 0.0, 100.0)
	V["frontDriveRatio"] = sp / 100.0
	V["rearDriveRatio"] = 1.0 - sp / 100.0
	V["driveType"] = "RWD" if sp <= 0.0 else ("FWD" if sp >= 100.0 else "AWD")
	V["finalDrive"] = float(base["finalDrive"]) * (pct.call("final") if has.call("final") else 1.0)
	# aerodinámica: ClA (m²) por eje
	V["aeroF"] = e["aeroF"] * (float(tu["aeroF"]) / 50.0 if has.call("aero") else 0.0)
	V["aeroR"] = e["aeroR"] * (float(tu["aeroR"]) / 60.0 if has.call("aero") else 0.0)
	V["dragCoef"] = float(base["dragCoef"]) * (1.0 + e["drag"] * (0.5 + float(tu["aeroR"]) / 120.0 if has.call("aero") else 0.0))
	# nitro
	V["nitroCap"] = e["nitro"]
	V["nitroBoost"] = e["nitroBoost"]
	# neumáticos
	var tr := tire(str(car.get("tires", "street")))
	V["tireId"] = tr["id"]
	var sg := {}
	var base_sg: Dictionary = base["surfGrip"]
	for k in base_sg:
		sg[k] = float(base_sg[k]) * float(tr["s"].get(k, 1.0))
	V["surfGrip"] = sg
	if tr.has("falloff"):
		V["tireFalloff"] = float(base["tireFalloff"]) * float(tr["falloff"])
	V["pressF"] = float(tu["pressF"])
	V["pressR"] = float(tu["pressR"])
	# diversión
	V["gripFront"] = pct.call("gripF")
	V["gripRear"] = pct.call("gripR")
	# ayudas globales
	V["abs"] = assists.get("abs", true) == true
	V["tractionControl"] = float(assists.get("tc", 50.0)) > 0.0
	V["tcSlip"] = float(base["tcSlip"]) * (1.6 - float(assists.get("tc", 50.0)) / 100.0)
	V["stabilityAssist"] = float(assists.get("stab", 30.0)) / 100.0
	if lab.get("all", false) == true:
		V["powerScale"] = float(V["powerScale"]) * float(lab.get("power", 100.0)) / 100.0
		var mk := float(lab.get("mass", 100.0)) / 100.0
		V["mass"] = float(V["mass"]) * mk
		V["Ixx"] = float(V["Ixx"]) * mk
		V["Iyy"] = float(V["Iyy"]) * mk
		V["Izz"] = float(V["Izz"]) * mk
		V["travel"] = float(V["travel"]) * float(lab.get("travel", 100.0)) / 100.0
		var gk := float(lab.get("grip", 100.0)) / 100.0
		for k in V["surfGrip"]:
			V["surfGrip"][k] = float(V["surfGrip"][k]) * gk
		V["dragCoef"] = float(V["dragCoef"]) * float(lab.get("drag", 100.0)) / 100.0
	return V

# ─── Índice de rendimiento (PI) y clase ───
static func torque_at(V: Dictionary, rpm: float) -> float:
	var c: Array = V["torqueCurve"]
	if rpm <= float(c[0][0]):
		return float(c[0][1])
	for i in range(1, c.size()):
		if rpm <= float(c[i][0]):
			var u := (rpm - float(c[i - 1][0])) / (float(c[i][0]) - float(c[i - 1][0]))
			return float(c[i - 1][1]) + (float(c[i][1]) - float(c[i - 1][1])) * u
	return float(c[c.size() - 1][1])

static func _cl(x: float) -> float:
	return clampf(x, 0.0, 1.0)

static func perf_of(V: Dictionary) -> Dictionary:
	var kw := 0.0
	var r := float(V["idleRpm"])
	while r <= float(V["maxRpm"]):
		kw = maxf(kw, float(V["peakTorque"]) * float(V["powerScale"]) * torque_at(V, r) * r / 9549.0)
		r += 100.0
	var hp := kw * 1.341
	var pw := hp / (float(V["mass"]) / 1000.0)
	var gears: Array = V["gears"]
	var g := float(gears[gears.size() - 1]) * float(V["finalDrive"])
	var v_gear := float(V["maxRpm"]) * 2.0 * PI / 60.0 * float(V["wheelRadius"]) / g
	var v_drag := pow(kw * 1000.0 * float(V["efficiency"]) / maxf(0.3, float(V["dragCoef"])), 1.0 / 3.0)
	var gov := float(V.get("vGov", 0.0))
	var vmax := minf(minf(v_gear * 3.6, v_drag * 3.6), gov if gov != 0.0 else 1e9)
	var sg: Dictionary = V["surfGrip"]
	var tire_k := (float(sg["asphalt"]) + float(sg["dirt"])) / 2.0
	var grip := float(V["mu"]) * tire_k * ((float(V["gripFront"]) + float(V["gripRear"])) / 2.0)
	var decel := minf(float(V["brakeTorque"]) / (float(V["wheelRadius"]) * float(V["mass"])), grip * 9.81 * 1.1)
	var aero := float(V.get("aeroF", 0.0)) + float(V.get("aeroR", 0.0))
	var s_acc := _cl(log(pw / 60.0) / log(700.0 / 60.0))
	var s_spd := _cl((vmax - 90.0) / (300.0 - 90.0))
	var s_grip := _cl((grip - 0.55) / (1.25 - 0.55))
	var s_brk := _cl((decel - 4.0) / (12.0 - 4.0))
	var s_aero := _cl(aero / 2.0)
	var s_off := _cl(((float(V["travel"]) - 0.2) / 0.25) * 0.35 + ((float(sg["dirt"]) * float(V["mu"])) - 0.5) / 0.7 * 0.4 + (float(V["wheelRadius"]) - 0.3) / 0.3 * 0.25)
	var pi := roundi(100.0 + 320.0 * s_acc + 190.0 * s_spd + 200.0 * s_grip + 100.0 * s_brk + 90.0 * s_aero)
	# 0-100 km/h estimado (para comparar mejoras y reglajes): sale de los kg por cv y no baja de lo que deja el agarre (75 % del peso en las ruedas que traccionan)
	var t100 := maxf(1.25 * pow(float(V["mass"]) / maxf(hp, 1.0), 0.9), 27.8 / (maxf(grip, 0.4) * 9.81 * 0.75))
	return {"pi": mini(999, pi), "hp": roundi(hp), "kg": roundi(float(V["mass"])), "vmax": roundi(vmax), "pw": roundi(pw), "t100": snappedf(t100, 0.1),
		"bars": {"speed": s_spd, "accel": s_acc, "handling": _cl(s_grip * 0.8 + s_aero * 0.2), "braking": s_brk, "offroad": s_off}}

static func class_of(pi: int) -> Dictionary:
	var r: Dictionary = catalog()["classes"][0]
	for k in catalog()["classes"]:
		if pi >= int(k["min"]):
			r = k
	return r
