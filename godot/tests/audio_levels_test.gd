## Sonido del auto: que no vuelva el «viento fuerte que se repite» ni el «silbido que se queda» (docs/AUDIO.md).
##  1) Los ruidos de fondo (rodado, tierra, viento, lluvia, turbo, chillido, ruido del motor) son bucles LARGOS (≥ 10 s), a RMS 0,10, sin costura y sin repetirse adentro
##     (antes eran de 2 s EXACTOS: el rodado a velocidad de ruta volvía idéntico cada 2 s).
##  2) Con el auto andando (crucero, a fondo, acelerando, soltando) cada capa queda por debajo de su tope, el silbido del turbo y el zumbido de la caja no pasan de 3,3 / 2,4 kHz,
##     el tono que no cambia se apaga solo y parado no suena nada.
##  3) «Gomas y tierra» y «Viento y lluvia» mandan sobre lo que dicen (en 0 → silencio).
##  4) El viento y la lluvia del mundo abierto (world_ambient.gd) quedan bajos.
## No necesita audio real: mira lo que el motor le manda a cada voz (volumen y velocidad de reproducción).
## Uso: godot --headless --path godot --script res://tests/audio_levels_test.gd
extends SceneTree

const CarAudio := preload("res://game/audio/car_audio.gd")
const WorldAmbient := preload("res://game/audio/world_ambient.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const DIR := "res://game/audio/samples/"
const NOISES := ["roll", "squeal", "gravel", "wind", "turbo", "rain", "engnoise"]
const DT := 1.0 / 60.0

var fails := 0
var consts: Dictionary
var vehicles: Dictionary

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _initialize() -> void:
	consts = JSON.parse_string(FileAccess.get_file_as_string(DIR + "consts.json"))
	vehicles = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	_main()

func _main() -> void:
	_test_samples()
	await _test_driving()
	await _test_sliders()
	await _test_world()
	print("AUDIO_LEVELS_TEST ", "OK" if fails == 0 else "FALLÓ")
	quit(1 if fails > 0 else 0)

# ───────────────────────── 1) muestras ─────────────────────────
func _pcm(name: String) -> PackedFloat32Array:
	var w := load(DIR + name + ".wav") as AudioStreamWAV
	var out := PackedFloat32Array()
	if w == null or w.format != AudioStreamWAV.FORMAT_16_BITS:
		return out # (si el formato no es PCM 16 bits no se puede mirar: lo avisa el chequeo de abajo)
	var d := w.data
	var n := d.size() / 2
	out.resize(n)
	for i in n:
		var v := d.decode_s16(i * 2)
		out[i] = float(v) / 32768.0
	return out

func _test_samples() -> void:
	for name in NOISES:
		var c: Dictionary = consts[name]
		var rate := float(c.get("rate", 44100))
		var secs := float(c["n"]) / rate
		check(secs >= 10.0, "%s: bucle de %.0f s (≥ 10 s: no se oye que se repite)" % [name, secs])
		var x := _pcm(name)
		check(x.size() == int(c["n"]), "%s: se importa como PCM de 16 bits sin recortes (%d muestras)" % [name, x.size()])
		if x.size() != int(c["n"]):
			continue
		var unit := float(c["unit"])
		var ss := 0.0
		for v in x:
			ss += v * v
		var rms := sqrt(ss / float(x.size())) * unit
		check(absf(rms - 0.10) < 0.004, "%s: RMS %.4f (el de todos los ruidos de fondo: 0,10 = −20 dBFS)" % [name, rms])
		# costura: el salto entre la última y la primera muestra es como cualquier salto entre vecinas
		var sd := 0.0
		for i in range(1, mini(x.size(), 20000)):
			sd += (x[i] - x[i - 1]) * (x[i] - x[i - 1])
		sd = sqrt(sd / 19999.0)
		check(absf(x[0] - x[x.size() - 1]) < 6.0 * sd + 1e-4, "%s: el bucle no tiene costura (salto %.5f, típico %.5f)" % [name, absf(x[0] - x[x.size() - 1]), sd])
		# repeticiones: un tramo de 0,25 s contra el mismo tramo corrido k × 0,1 s (incluidos los 2,0 s de antes)
		var blk := int(0.25 * rate)
		var worst := 0.0
		var worst_at := 0.0
		var step := int(0.1 * rate)
		var off := step * 2
		while off + blk < x.size() - blk and off < x.size() - blk:
			var sab := 0.0
			var saa := 0.0
			var sbb := 0.0
			for i in range(0, blk, 3):
				var a := x[i]
				var b := x[off + i]
				sab += a * b
				saa += a * a
				sbb += b * b
			var r := absf(sab) / sqrt(maxf(saa * sbb, 1e-12))
			if r > worst:
				worst = r
				worst_at = float(off) / rate
			off += step
		# (un tramo igual repetido da 1,0; el ruido de banda angosta se parece a sí mismo por casualidad hasta ~0,3)
		check(worst < 0.5, "%s: sin repeticiones adentro (mayor parecido %.2f a %.1f s del principio)" % [name, worst, worst_at])

# ───────────────────────── 2) andando ─────────────────────────
func _params(car: String) -> VehicleParams:
	var st: Dictionary = Profile.new_car_state(car)
	return VehicleParams.from_dict(CarBuild.build_params(vehicles[car], st))

func _db(lin: float) -> float:
	return 20.0 * log(maxf(lin, 1e-9)) / log(10.0)

## nivel de una voz en dBFS: ruido = vol × RMS 0,10; seno = amplitud (el RMS es 3 dB menos)
func _level(a: Node, vname: String) -> float:
	var v: Dictionary = a.voices[vname]
	var p: AudioStreamPlayer = v["p"]
	if p.stream_paused:
		return -140.0
	var vol := db_to_linear(p.volume_db) / float(v["unit"])
	if vname in ["whine1", "whine2", "whistle", "gwe"]:
		return _db(vol) - 3.0
	return _db(vol * 0.10) if vname != "engine" and vname != "engine_ai" else _db(vol)

func _freq(a: Node, vname: String) -> float:
	var p: AudioStreamPlayer = a.voices[vname]["p"]
	if vname == "gearwhine":
		return p.pitch_scale * float(consts["gearwhine_hz"]) # (la fundamental de la caja con armónicos)
	return p.pitch_scale * float(consts["tone_base_hz"])

func _snap(V: VehicleParams, v: float, thr: float, gear: int, surf := 0, slide := 0.0) -> CarSnapshot:
	var p := CarSnapshot.new()
	var in_gear := fmod(v / 10.0, 1.0)
	p.rpm = V.idleRpm + (V.maxRpm - V.idleRpm) * clampf(0.35 + 0.6 * in_gear, 0.0, 1.0) if v > 0.5 else V.idleRpm
	p.load = thr
	p.throttle = thr
	p.vz = v
	p.vLong = v
	p.gear = gear if v > 0.5 else 0
	p.clutchLocked = v > 0.5
	p.shiftT = 0.0
	for i in 4:
		p.wheel_fx[i * 8] = 1.0
		p.wheel_fx[i * 8 + 1] = float(surf)
		p.wheel_fx[i * 8 + 3] = slide * 0.6
		p.wheel_fx[i * 8 + 4] = slide * 0.5
	return p

func _new_audio(car: String) -> Node:
	var a: Node = CarAudio.new()
	a.set_vehicle(car)
	root.add_child(a)
	await process_frame # (el _ready del nodo corre recién en el primer cuadro)
	return a

## corre `secs` segundos de la escena (v(t) = f(t)) y devuelve el máximo de cada capa en la última parte (desde `from`)
func _run(a: Node, V: VehicleParams, secs: float, from: float, fn: Callable) -> Dictionary:
	var peak := {}
	var t := 0.0
	while t < secs:
		t += DT
		var p: CarSnapshot = fn.call(t)
		a.update(p, V, DT, [], 0.0)
		if t >= from:
			for vn in ["roll", "squeal", "gravel", "wind", "turbo", "rain", "whine1", "whine2", "whistle", "gwe", "engnoise", "gearwhine", "overrun"]:
				if not a.voices.has(vn):
					peak[vn] = -140.0
					peak["f_" + vn] = 0.0
					continue
				peak[vn] = maxf(float(peak.get(vn, -140.0)), _level(a, vn))
				peak["f_" + vn] = maxf(float(peak.get("f_" + vn, 0.0)), _freq(a, vn))
	return peak

func _test_driving() -> void:
	for car in ["hatch", "rally80", "veltor_gtr", "truck"]:
		var V := _params(car)
		# a fondo en ruta a 220 km/h, mucho rato (el caso del «silbido que se queda»)
		var a := await _new_audio(car)
		var pk := _run(a, V, 30.0, 20.0, func(_t): return _snap(V, 61.0, 1.0, 6))
		check(pk["whistle"] < -50.0, "%s a fondo a 220 km/h: el silbido del turbo parado queda en %.0f dBFS (< −50)" % [car, pk["whistle"]])
		check(pk["whine1"] < -55.0, "%s a 220 km/h parejo: el zumbido de la caja queda en %.0f dBFS (< −55)" % [car, pk["whine1"]])
		check(pk["roll"] < -36.0 and pk["wind"] < -44.0 and pk["turbo"] < -52.0, "%s a 220 km/h: rodado %.0f · viento %.0f · soplido %.0f dBFS (< −36 / −44 / −52)" % [car, pk["roll"], pk["wind"], pk["turbo"]])
		check(pk["f_whistle"] <= 3300.0 * 1.01 and pk["f_whine1"] <= 2400.0 * 1.02 * 1.007, "%s: el silbido no pasa de 3,3 kHz (%.0f) ni la caja de 2,4 kHz (%.0f)" % [car, pk["f_whistle"], pk["f_whine1"]])
		check(pk["gearwhine"] < -38.0 and pk["f_gearwhine"] <= 1500.0 * 1.01, "%s a 220 km/h: la caja con armónicos queda en %.0f dBFS (< −38) y no pasa de 1,5 kHz (%.0f)" % [car, pk["gearwhine"], pk["f_gearwhine"]])
		a.queue_free()
		# acelerando: el silbido y la caja se oyen, pero siguen siendo bajos
		a = await _new_audio(car)
		pk = _run(a, V, 24.0, 0.0, func(t): return _snap(V, minf(61.0, 3.0 * t), 1.0, clampi(int(t / 4.0) + 1, 1, 6)))
		check(pk["whistle"] < -36.0 and pk["whine1"] < -40.0 and pk["turbo"] < -40.0, "%s acelerando: silbido %.0f · caja %.0f · soplido %.0f dBFS (tope −36 / −40 / −40)" % [car, pk["whistle"], pk["whine1"], pk["turbo"]])
		a.queue_free()
		# soltando el acelerador en ruta (rueda libre): suena la caja, bajito
		a = await _new_audio(car)
		pk = _run(a, V, 20.0, 0.0, func(t): return _snap(V, 55.0 - 1.4 * t, 0.0, 6))
		check(pk["whine1"] < -38.0, "%s soltando el pie: la caja queda en %.0f dBFS (< −38)" % [car, pk["whine1"]])
		# (pedido del dueño, 14/10/2026: «al soltar se siente la caja y el freno motor»): la caja con armónicos se oye, sin tapar al motor
		check(pk["gearwhine"] > -62.0 and pk["gearwhine"] < -30.0, "%s soltando el pie: la caja se oye (%.0f dBFS, entre −62 y −30)" % [car, pk["gearwhine"]])
		a.queue_free()
		# tono que no cambia: se apaga solo (a los 10 s suena mucho menos que al principio)
		a = await _new_audio(car)
		var early := _run(a, V, 1.5, 0.5, func(_t): return _snap(V, 40.0, 0.0, 5))
		var late := _run(a, V, 12.0, 10.0, func(_t): return _snap(V, 40.0, 0.0, 5))
		if early["whine1"] > -80.0:
			check(late["whine1"] <= early["whine1"] - 6.0, "%s: el zumbido de la caja que no cambia baja de %.0f a %.0f dBFS (al menos −6 dB)" % [car, early["whine1"], late["whine1"]])
		if early["gearwhine"] > -80.0:
			check(late["gearwhine"] <= early["gearwhine"] - 3.0, "%s: la caja con armónicos que no cambia baja de %.0f a %.0f dBFS (al menos −3 dB)" % [car, early["gearwhine"], late["gearwhine"]])
		a.queue_free()
		# parado: no suena nada de fondo
		a = await _new_audio(car)
		pk = _run(a, V, 4.0, 3.0, func(_t): return _snap(V, 0.0, 0.0, 0))
		var quiet := true
		for vn in ["roll", "squeal", "gravel", "wind", "turbo", "rain", "whine1", "whistle", "gwe", "gearwhine", "overrun"]:
			if pk[vn] > -100.0:
				quiet = false
		check(quiet, "%s parado: ninguna capa de fondo suena" % car)
		a.queue_free()
	# tierra a 90 km/h y derrape: tope de la tierra y del chillido
	var V2 := _params("hatch")
	var a2 := await _new_audio("hatch")
	var pk2 := _run(a2, V2, 10.0, 6.0, func(_t): return _snap(V2, 25.0, 0.6, 3, 1))
	check(pk2["gravel"] < -38.0 and pk2["roll"] < -100.0, "tierra a 90 km/h: tierra %.0f dBFS (< −38) y sin rodado de asfalto (%.0f)" % [pk2["gravel"], pk2["roll"]])
	a2.queue_free()
	a2 = await _new_audio("hatch")
	pk2 = _run(a2, V2, 10.0, 6.0, func(_t): return _snap(V2, 22.0, 0.8, 3, 0, 0.5))
	check(pk2["squeal"] < -34.0 and pk2["squeal"] > -60.0, "derrape: el chillido se oye pero bajo (%.0f dBFS, entre −60 y −34)" % pk2["squeal"])
	a2.queue_free()
	# lluvia en carrera
	a2 = await _new_audio("hatch")
	a2.rain(true)
	pk2 = _run(a2, V2, 12.0, 8.0, func(_t): return _snap(V2, 0.0, 0.0, 0))
	check(pk2["rain"] < -38.0 and pk2["rain"] > -55.0, "lluvia: %.0f dBFS (entre −55 y −38; antes −25, un siseo tan fuerte como el motor)" % pk2["rain"])
	a2.queue_free()

# ───────────────────────── 3) controles ─────────────────────────
func _test_sliders() -> void:
	var V := _params("hatch")
	var a := await _new_audio("hatch")
	a.mix["surf"] = 0.0
	a.mix["wind"] = 0.0
	a.rain(true)
	var pk := _run(a, V, 6.0, 4.0, func(_t): return _snap(V, 40.0, 0.5, 5))
	check(pk["roll"] < -100.0 and pk["wind"] < -100.0 and pk["rain"] < -100.0, "«Gomas y tierra» y «Viento y lluvia» en 0 → silencio (rodado %.0f · viento %.0f · lluvia %.0f)" % [pk["roll"], pk["wind"], pk["rain"]])
	a.queue_free()
	a = await _new_audio("hatch")
	a.mix["surf"] = 0.8
	a.mix["wind"] = 0.8
	a.rain(true)
	var hi := _run(a, V, 6.0, 4.0, func(_t): return _snap(V, 40.0, 0.5, 5))
	a.queue_free()
	a = await _new_audio("hatch")
	a.rain(true)
	var lo := _run(a, V, 6.0, 4.0, func(_t): return _snap(V, 40.0, 0.5, 5))
	a.queue_free()
	check(hi["roll"] > lo["roll"] + 6.0 and hi["wind"] > lo["wind"] + 6.0 and hi["rain"] > lo["rain"] + 6.0, "en «Muy fuerte» suenan al menos 6 dB más que en «Normal» (rodado +%.0f · viento +%.0f · lluvia +%.0f dB)" % [hi["roll"] - lo["roll"], hi["wind"] - lo["wind"], hi["rain"] - lo["rain"]])

# ───────────────────────── 4) mundo abierto ─────────────────────────
class FakeClock:
	extends RefCounted
	var night := 0.0
	var wx: Dictionary = {}

class FakeCarPhys:
	extends RefCounted
	var py := 0.0

class FakeCar:
	extends RefCounted
	var phys := FakeCarPhys.new()

class FakeRace:
	extends RefCounted
	var clock := FakeClock.new()
	var world_life = null
	var cars: Array = [FakeCar.new()]
	var _ug := 0.0

func _test_world() -> void:
	var race := FakeRace.new()
	race.clock.wx = {"kind": "storm", "cloud": 1.0, "rain": 1.0}
	var wa := WorldAmbient.new()
	root.add_child(wa)
	await process_frame
	wa.setup(race, 0)
	var t := 0.0
	while t < 12.0:
		t += DT
		wa.update(DT, Vector2(t, 0.0), 30.0)
	var g: Dictionary = wa.voices["gust"]
	var gp: AudioStreamPlayer = g["p"]
	var lvl := _db(db_to_linear(gp.volume_db) / float(g["unit"]) * 0.10)
	check(not gp.stream_paused and lvl < -36.0, "tormenta en el mundo abierto: el viento queda en %.0f dBFS (< −36; antes −28, un soplido fuerte)" % lvl)
	race.clock.wx = {"kind": "clear", "cloud": 0.0, "rain": 0.0}
	t = 0.0
	while t < 20.0:
		t += DT
		wa.update(DT, Vector2(t, 0.0), 30.0)
	lvl = _db(db_to_linear(gp.volume_db) / float(g["unit"]) * 0.10) if not gp.stream_paused else -140.0
	check(lvl < -55.0, "cielo despejado: el viento del mundo casi no se oye (%.0f dBFS, < −55)" % lvl)
	wa.queue_free()
