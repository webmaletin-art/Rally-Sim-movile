## Graba (a un .wav) lo que suena el motor de audio del auto en escenas armadas a mano (acelerar, cruzar a fondo, soltar, frenar, lluvia…) para poder MEDIRLO (niveles, tonos que
## se quedan, repeticiones) con tools/audio/analyze_audio.py. No usa la carrera: arma el CarAudio y le va pasando estados del auto inventados.
## Uso: godot --headless --path godot --script res://tests/audio_render.gd -- --car=hatch --scene=accel --out=/tmp/audio/hatch_accel.wav [--solo=wind,roll] [--secs=30] [--wind=30] [--log]
##   escenas: accel (0→tope, crucero, soltar y frenar) · cruise (crucero a 140 km/h) · coast (soltar a fondo) · idle · slide (derrape en asfalto) · dirt (tierra a 90 km/h) · rain (crucero con lluvia)
##            fast (crucero a 220 km/h, pie a fondo) · stop (frena hasta parar y queda quieto: no tiene que sonar nada)
##   --solo: deja sonar SÓLO esas voces (engine, engnoise, roll, squeal, gravel, wind, turbo, rain, whine1, whine2, whistle, gwe, shots)
##   --wind/--surf/--turbo/--gear/--eng: porcentaje de «Viento», «Superficie», «Turbo», «Caja», «Motor» (los del perfil; por defecto 30 / 30 / 100 / 100 / 100)
##   --rival=d,rpm: hay un rival a d metros con ese régimen (como race.gd le avisa a CarAudio.rival)
##   --log: imprime cada segundo (sólo las voces que suenan) el nivel (lineal, ya con la «unidad» de la muestra) y la velocidad de reproducción de cada voz
extends SceneTree

const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

## CarAudio con un filtro: si hay voces «solo», las demás no suenan nunca (se pasan por una subclase para no tocar el original)
const SOLO_SRC := """extends "res://game/audio/car_audio.gd"
var solo: Array = []
func _set_voice(vname: String, vol: float, pitch: float) -> void:
	if not solo.is_empty() and not solo.has(vname):
		(voices[vname]["p"] as AudioStreamPlayer).stream_paused = true
		return
	super(vname, vol, pitch)
func _shoot(pname: String, amp: float, pitch := 1.0) -> void:
	if solo.is_empty() or solo.has("shots"):
		super(pname, amp, pitch)
"""

var audio: Node
var rec: AudioEffectRecord
var V: VehicleParams
var car := "hatch"
var scene_name := "accel"
var out_path := "/tmp/audio/out.wav"
var vmax := 60.0
var secs := 0.0
var solo: Array = []
var mixv := {"wind": 30.0, "surf": 30.0, "turbo": 100.0, "gear": 100.0, "eng": 100.0}
var do_log := false
var rival_d := -1.0
var rival_rpm := 0.0

func _initialize() -> void:
	Engine.max_fps = 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--car="):
			car = a.substr(6)
		elif a.begins_with("--scene="):
			scene_name = a.substr(8)
		elif a.begins_with("--out="):
			out_path = a.substr(6)
		elif a.begins_with("--secs="):
			secs = float(a.substr(7))
		elif a.begins_with("--vmax="):
			vmax = float(a.substr(7))
		elif a.begins_with("--solo="):
			solo = Array(a.substr(7).split(","))
		elif a == "--log":
			do_log = true
		elif a.begins_with("--rival="):
			var rv := a.substr(8).split(",")
			rival_d = float(rv[0])
			rival_rpm = float(rv[1])
		else:
			for k in mixv:
				if a.begins_with("--%s=" % k):
					mixv[k] = float(a.substr(k.length() + 3))
	_run()

## Estado del auto en el segundo t de la escena
func _state(t: float, p: CarSnapshot) -> void:
	var v := 0.0 # m/s
	var thr := 0.0
	var surf := 0
	var slide := 0.0
	var brake := 0.0
	match scene_name:
		"accel":
			if t < 18.0:
				v = vmax * (1.0 - exp(-t / 7.0)) / (1.0 - exp(-18.0 / 7.0)) * 0.97
				thr = 1.0
			elif t < 28.0:
				v = vmax * 0.97
				thr = 0.55
			elif t < 38.0:
				v = vmax * 0.97 * (1.0 - (t - 28.0) / 10.0 * 0.4)
				thr = 0.0 # soltar el acelerador: el auto va rodando (la caja y el viento siguen)
			else:
				v = maxf(0.0, vmax * 0.97 * 0.6 * (1.0 - (t - 38.0) / 6.0))
				brake = 1.0
		"cruise":
			v = 38.9
			thr = 0.4
		"fast":
			v = 61.0
			thr = 1.0
		"coast":
			v = 45.0 - t * 1.2
			thr = 0.0
		"idle":
			v = 0.0
			thr = 0.0
		"slide":
			v = 22.0
			thr = 0.8
			slide = 0.35
		"dirt":
			v = 25.0
			thr = 0.6
			surf = 1
		"rain":
			v = 38.9
			thr = 0.4
		"blips": # pisar y soltar seguido (estampidos del escape)
			v = 22.0
			thr = 1.0 if fmod(t, 1.1) < 0.45 else 0.0
		"stop":
			v = maxf(0.0, 38.9 * (1.0 - t / 5.0))
			thr = 0.0 if t > 1.0 else 0.4
			brake = 1.0 if t > 1.0 else 0.0
	var rpm_range := V.maxRpm - V.idleRpm
	var gear := clampi(int(v / (vmax / 6.0)) + 1, 1, 6)
	var in_gear := v / maxf(vmax / 6.0, 1.0) - float(gear - 1)
	var rpm := V.idleRpm + rpm_range * 0.1 * thr
	if v > 0.5:
		rpm = V.idleRpm + rpm_range * clampf(0.35 + 0.6 * in_gear, 0.0, 1.0) * (0.4 + 0.6 * clampf(v / 8.0, 0.0, 1.0))
	p.rpm = rpm
	p.load = thr
	p.throttle = thr
	p.brake = brake
	p.vx = 0.0
	p.vz = v
	p.vLong = v
	p.gear = gear if v > 0.5 else 0
	p.clutchLocked = v > 0.5
	p.shiftT = 0.0
	for i in 4:
		var o := i * 8
		p.wheel_fx[o] = 1.0 # contacto
		p.wheel_fx[o + 1] = float(surf)
		p.wheel_fx[o + 3] = slide * 0.6
		p.wheel_fx[o + 4] = slide * 0.5

func _log(t: float) -> void:
	var s := "LOG %5.1f" % t
	for k in audio.voices.keys():
		var v: Dictionary = audio.voices[k]
		var pl: AudioStreamPlayer = v["p"]
		if not pl.stream_paused:
			s += " | %s %.4f x%.2f" % [k, db_to_linear(pl.volume_db), pl.pitch_scale]
	print(s)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var st: Dictionary = Profile.new_car_state(car)
	V = VehicleParams.from_dict(CarBuild.build_params(vehicles[car], st))
	rec = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, rec)
	var gs := GDScript.new()
	gs.source_code = SOLO_SRC
	gs.reload()
	audio = gs.new()
	audio.solo = solo
	audio.set_vehicle(car)
	root.add_child(audio)
	await process_frame
	audio.mix["wind"] = mixv["wind"] / 100.0
	audio.mix["surf"] = mixv["surf"] / 100.0
	audio.mix["turbo"] = mixv["turbo"] / 100.0
	audio.mix["gear"] = mixv["gear"] / 100.0
	audio.mix["eng"] = mixv["eng"] / 100.0
	audio.rain(scene_name == "rain")
	rec.set_recording_active(true)
	var p := CarSnapshot.new()
	var dur := secs if secs > 0.0 else (44.0 if scene_name == "accel" else 24.0)
	var t := 0.0
	var next_log := 0.0
	var last := Time.get_ticks_msec()
	while t < dur:
		await process_frame
		var now := Time.get_ticks_msec()
		var dt := float(now - last) / 1000.0
		last = now
		t += dt
		_state(t, p)
		audio.update(p, V, dt, [], 0.0)
		if rival_d >= 0.0:
			audio.rival(rival_d, rival_rpm, float(V.firingOrder))
		if do_log and t >= next_log:
			next_log += 1.0
			_log(t)
	rec.set_recording_active(false)
	var w: AudioStreamWAV = rec.get_recording()
	w.save_to_wav(out_path)
	print("AUDIO %s %s → %s (%.1f s)" % [car, scene_name, out_path, t])
	quit(0)
