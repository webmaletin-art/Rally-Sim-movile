extends Node
## Sonido del auto del jugador. Traduce el estado de la física a volumen y velocidad de reproducción de unas pocas muestras
## (las genera tools/godot/make_audio.py con los mismos osciladores y filtros del Web Audio de la versión HTML) y las
## reproduce el motor de audio (C++), así que casi no gasta procesador y no se corta.
##  · motor: un ciclo con los 5 osciladores + modulación + saturación; velocidad = rpm; pasabajos según carga y vueltas
##  · ruidos en bucle: rodado, chillido de gomas, grava, viento, soplido del turbo, lluvia, ruido del motor. Son bucles LARGOS (12–24 s) y parejos: con los de 2 s del principio
##    el rodado se repetía idéntico cada 2 s y sonaba como un viento fuerte que vuelve (ver tools/godot/make_audio.py y docs/AUDIO.md)
##  · silbido del turbo y caja de engranajes: senos/triángulos de tabla corta a la frecuencia justa. Son tonos puros: por eso son bajitos, no pasan de ~3 kHz y NO se quedan
##    (el silbido sólo se oye mientras el turbo carga o se vacía; el zumbido de la caja se va apagando si la velocidad no cambia)
##  · flutter del turbo, petardeos, golpes: muestras de un disparo
## Niveles: los ruidos de fondo están grabados a RMS 0,10, así que un volumen de 1,0 es −20 dBFS y 0,1 es −40 dBFS.

const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const DIR := "res://game/audio/samples/"

## niveles generales. El motor, el flutter, los petardeos y los golpes son los de la versión web; los ruidos de fondo (gomas, tierra, viento, turbo, silbido, caja) se bajaron mucho
## (el rodado, la tierra y la lluvia sonaban tan fuertes como el motor, y el silbido del turbo era un seno de 8 kHz): ver docs/AUDIO.md
const SND := {"master": 0.55, "engine": 0.62, "tires": 0.13, "squeal": 0.17, "gravel": 0.092, "wind": 0.04, "turbo": 0.075, "whistle": 0.015, "flutter": 0.75, "whine": 0.012, "pops": 0.35, "impacts": 0.8,
	"rain": 0.06}
const SURF_DEFAULT := 0.30 # «Gomas y tierra» y «Viento y lluvia» en su valor normal (30): los niveles de arriba son para ese valor
const WHINE_MAX_HZ := 2400.0 # la caja de cambios nunca pasa de acá (antes llegaba a 4,2 kHz y se oía como un silbido fino)
const WHISTLE_MAX_HZ := 3300.0 # ídem el silbido del turbo (antes llegaba a 8 kHz)
const STEADY_RATE := 0.04 # cambio relativo de frecuencia por segundo por debajo del cual un tono se considera «parado»
const STEADY_FADE_S := 2.5 # un tono parado se va apagando en este tiempo
const STEADY_MIN := 0.30 # …hasta este nivel (y vuelve enseguida cuando la frecuencia se mueve)
const TURBO_SND := {
	"pickup": {"f": 1.0, "spool": 0.55, "w": 1.0, "fl": 1.0}, "t1plus": {"f": 1.12, "spool": 0.42, "w": 0.8, "fl": 0.9},
	"truck": {"f": 0.55, "spool": 0.9, "w": 0.9, "fl": 1.2}, "genesis": {"f": 1.3, "spool": 0.3, "w": 1.1, "fl": 1.0},
	"torito": {"f": 0.9, "spool": 0.8, "w": 0.3, "fl": 0.5}, "clasico60": {"f": 1.0, "spool": 0.8, "w": 0.3, "fl": 0.5},
	"kodiak": {"f": 0.9, "spool": 0.6, "w": 1.1, "fl": 1.1}, "titan": {"f": 0.5, "spool": 1.0, "w": 1.2, "fl": 1.3},
	"rally80": {"f": 1.1, "spool": 0.35, "w": 1.4, "fl": 1.5}, "kl5": {"f": 1.2, "spool": 0.5, "w": 0.4, "fl": 0.6},
	"trilux": {"f": 1.1, "spool": 0.45, "w": 0.9, "fl": 1.0}, "trilux_s": {"f": 1.15, "spool": 0.4, "w": 1.1, "fl": 1.1},
	"trilux_gt": {"f": 1.2, "spool": 0.35, "w": 1.3, "fl": 1.3},
	"veltor": {"f": 1.25, "spool": 0.4, "w": 0.8, "fl": 0.9}, "veltor_s": {"f": 1.3, "spool": 0.35, "w": 0.9, "fl": 1.0},
	"veltor_gtr": {"f": 1.4, "spool": 0.3, "w": 1.0, "fl": 1.2},
	"hatch": {"f": 1.15, "spool": 0.5, "w": 0.8, "fl": 0.8}, "hatch2": {"f": 1.2, "spool": 0.3, "w": 1.4, "fl": 1.6},
	"pro_gt": {"f": 1.3, "spool": 0.35, "w": 1.2, "fl": 1.2}, "moust": {"f": 1.2, "spool": 0.3, "w": 1.3, "fl": 1.4}}
const GEAR_SND := {
	"pickup": {"k": 0.55, "tooth": 40.0}, "t1plus": {"k": 1.0, "tooth": 48.0},
	"truck": {"k": 0.8, "tooth": 34.0}, "genesis": {"k": 0.8, "tooth": 44.0},
	"torito": {"k": 0.3, "tooth": 30.0}, "clasico60": {"k": 0.45, "tooth": 36.0}, "kodiak": {"k": 0.6, "tooth": 34.0}, "titan": {"k": 0.8, "tooth": 28.0},
	"rally80": {"k": 0.9, "tooth": 46.0}, "kl5": {"k": 0.6, "tooth": 44.0}, "trilux": {"k": 0.6, "tooth": 42.0}, "trilux_s": {"k": 0.7, "tooth": 44.0},
	"trilux_gt": {"k": 0.9, "tooth": 46.0}, "veltor": {"k": 0.5, "tooth": 52.0}, "veltor_s": {"k": 0.6, "tooth": 54.0},
	"veltor_gtr": {"k": 1.2, "tooth": 40.0},
	"hatch": {"k": 0.35, "tooth": 38.0}, "hatch2": {"k": 0.9, "tooth": 44.0}, "pro_gt": {"k": 0.9, "tooth": 46.0}, "moust": {"k": 1.0, "tooth": 48.0}}
## Carácter del motor de los autos nuevos (los de siempre conservan su voz): tono (f), brillo del filtro (cut), volumen (eng), ruido mecánico (noise) y petardeos (pops)
const VOICE := {
	"torito": {"f": 0.92, "cut": 0.85, "eng": 1.10, "noise": 1.3, "pops": 1.2},
	"clasico60": {"f": 1.08, "cut": 0.90, "eng": 0.95, "noise": 1.2, "pops": 1.0},
	"kodiak": {"f": 0.85, "cut": 0.80, "eng": 1.10, "noise": 1.5, "pops": 0.8},
	"titan": {"f": 0.72, "cut": 0.65, "eng": 1.25, "noise": 1.8, "pops": 0.4},
	"rally80": {"f": 1.00, "cut": 1.15, "eng": 1.00, "noise": 1.1, "pops": 1.6},
	"kl5": {"f": 1.10, "cut": 1.30, "eng": 0.95, "noise": 0.9, "pops": 1.0},
	"trilux": {"f": 1.00, "cut": 1.00, "eng": 1.00, "noise": 1.0, "pops": 1.0},
	"trilux_s": {"f": 1.00, "cut": 1.10, "eng": 1.00, "noise": 1.0, "pops": 1.1},
	"trilux_gt": {"f": 1.02, "cut": 1.20, "eng": 1.05, "noise": 1.1, "pops": 1.3},
	"veltor": {"f": 1.00, "cut": 1.25, "eng": 0.95, "noise": 0.9, "pops": 1.0},
	"veltor_s": {"f": 1.00, "cut": 1.30, "eng": 0.95, "noise": 0.9, "pops": 1.1},
	"veltor_gtr": {"f": 1.00, "cut": 1.40, "eng": 1.10, "noise": 1.2, "pops": 1.4},
	"hatch": {"f": 1.12, "cut": 0.95, "eng": 0.90, "noise": 1.0, "pops": 0.9},
	"hatch2": {"f": 1.06, "cut": 1.15, "eng": 1.00, "noise": 1.1, "pops": 1.6},
	"pro_gt": {"f": 1.04, "cut": 1.25, "eng": 1.05, "noise": 1.0, "pops": 1.3},
	"moust": {"f": 0.96, "cut": 1.20, "eng": 1.10, "noise": 1.2, "pops": 1.5}}
## constante de tiempo de cada parámetro (como setTargetAtTime de Web Audio)
const TIME_K := {"f0": 0.012, "cut": 0.03, "eng": 0.03, "engn": 0.05, "roll": 0.08, "sq": 0.05, "sqf": 0.03, "grav": 0.03, "wind": 0.1, "windf": 0.1,
	"gw": 0.05, "wf": 0.03, "gwe": 0.04, "gwef": 0.02, "tw": 0.05, "twf": 0.06, "tb": 0.08, "tbf": 0.05, "rain": 0.4, "ai": 0.08, "aif": 0.05}

var consts: Dictionary
var voices := {} # nombre → {p: AudioStreamPlayer, unit: float}
var pools := {} # muestras de un disparo: nombre → {players: [], unit: float}
var cur := {}
var tgt := {}
var engine_bus := -1
var ai_bus := -1
var lp_engine: AudioEffectLowPassFilter
var active := true
var vehicle_id := "t1plus"
var voice := {} # carácter del motor (VOICE) del auto actual; vacío = la voz de siempre
var pop_t := -10.0 # última vez que sonó un petardeo (pausa mínima entre ráfagas)
var thump_t := -10.0 # último golpe grave (pausa mínima entre golpes)
var pops_ok := false # lo calcula update(): hay petardeo/flutter solo en 1ª–2ª o bajando de marcha
var mix := {"eng": 1.0, "surf": 0.3, "wind": 0.3, "turbo": 1.0, "gear": 1.0}
var volume := 80.0
var boost := 0.0
var arm_b := 0.0
var fl_t := -9.0
var prev_thr := 0.0
var time := 0.0
var rng := RandomNumberGenerator.new()
var gw_tau := 0.05
var spool := 0.0 # cuánto se está moviendo la carga del turbo (0 quieto … 1 cargando o vaciándose): sólo entonces se oye el silbido
var _boost_prev := 0.0
var _steady := {} # tono → {f, rate, k}: seguimiento de los tonos puros que se quedan quietos (ver _steady_gain)
var _rain_k := 1.0 # «Viento y lluvia»

func _ready() -> void:
	rng.randomize()
	consts = JSON.parse_string(FileAccess.get_file_as_string(DIR + "consts.json"))
	for k in TIME_K:
		cur[k] = 0.0
		tgt[k] = 0.0
	cur["cut"] = 400.0
	tgt["cut"] = 400.0
	cur["f0"] = 50.0
	tgt["f0"] = 50.0
	for k in ["sqf", "windf", "wf", "gwef", "twf", "aif"]:
		cur[k] = 1000.0
		tgt[k] = 1000.0
	# buses: el motor pasa por un pasabajos que sube con la carga; el rival por otro fijo; el master comprime como el del HTML
	engine_bus = _make_bus("GSMotor")
	lp_engine = AudioEffectLowPassFilter.new()
	lp_engine.cutoff_hz = 400.0
	lp_engine.resonance = 0.55
	lp_engine.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(engine_bus, lp_engine)
	# viento: ruido grave y filtrado (se siente el aire, sin silbido); la muestra ya es grave, el pasabajos sólo asegura que nada agudo se cuele
	var wind_bus := _make_bus("GSViento")
	var lp_w := AudioEffectLowPassFilter.new()
	lp_w.cutoff_hz = 1800.0
	lp_w.resonance = 0.4
	lp_w.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(wind_bus, lp_w)
	ai_bus = _make_bus("GSRival")
	var lp_ai := AudioEffectLowPassFilter.new()
	lp_ai.cutoff_hz = 900.0
	lp_ai.resonance = 0.55
	lp_ai.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(ai_bus, lp_ai)
	if AudioServer.get_bus_effect_count(0) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 4.0
		comp.attack_us = 3000.0
		comp.release_ms = 250.0
		AudioServer.add_bus_effect(0, comp)
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	# voces en bucle
	_voice("engine", "GSMotor", false)
	_voice("engnoise", "Master")
	_voice("roll", "Master")
	_voice("squeal", "Master")
	_voice("gravel", "Master")
	_voice("wind", "GSViento")
	_voice("turbo", "Master")
	_voice("rain", "Master")
	_voice("engine_ai", "GSRival", false)
	_voice("whine1", "Master", false, "sine")
	_voice("whine2", "Master", false, "sine")
	_voice("whistle", "Master", false, "sine")
	_voice("gwe", "Master", false, "tri")
	# disparos
	for n in ["flutter_lo", "flutter_mid", "flutter_hi", "pop", "thump"]:
		_pool(n, 6 if n == "pop" else 3)
	apply_settings()

func _make_bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i >= 0:
		while AudioServer.get_bus_effect_count(i) > 0:
			AudioServer.remove_bus_effect(i, 0)
		return i
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	return i

func _load_wav(sample: String, looped: bool) -> AudioStreamWAV:
	var w: AudioStreamWAV = (load(DIR + sample + ".wav") as AudioStreamWAV).duplicate()
	if looped:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(consts[sample]["n"])
	return w

func _voice(vname: String, bus: String, random_start := true, sample := "") -> void:
	var smp := sample if sample != "" else vname
	var p := AudioStreamPlayer.new()
	p.stream = _load_wav(smp, true)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	var length := float(consts[smp]["n"]) / float(consts[smp].get("rate", 44100))
	p.play(rng.randf() * length if random_start else 0.0) # los bucles de ruido son largos: cada partida arranca en otro lugar
	p.stream_paused = true
	voices[vname] = {"p": p, "unit": float(consts[smp]["unit"])}

func _pool(pname: String, n: int) -> void:
	var arr := []
	var st := _load_wav(pname, false)
	for i in n:
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = "Master"
		add_child(p)
		arr.append(p)
	pools[pname] = {"players": arr, "unit": float(consts[pname]["unit"])}

func _shoot(pname: String, amp: float, pitch := 1.0) -> void:
	var pl: Dictionary = pools[pname]
	for p in pl["players"]:
		if not p.playing:
			p.volume_db = linear_to_db(maxf(amp * pl["unit"], 1e-4))
			p.pitch_scale = clampf(pitch, 0.25, 4.0)
			p.play()
			return

## fija el volumen (lineal) y la velocidad de una voz; si es inaudible la pausa (no gasta nada)
func _set_voice(vname: String, vol: float, pitch: float) -> void:
	var v: Dictionary = voices[vname]
	var p: AudioStreamPlayer = v["p"]
	var lin: float = vol * float(v["unit"])
	if lin < 3e-4:
		if not p.stream_paused:
			p.stream_paused = true
		return
	p.stream_paused = false
	p.volume_db = linear_to_db(lin)
	p.pitch_scale = clampf(pitch, 0.02, 30.0)

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(SND["master"] * volume / 80.0, 1e-3)))

func set_active(v: bool) -> void:
	active = v
	if not v:
		for k in voices:
			(voices[k]["p"] as AudioStreamPlayer).stream_paused = true

func rain(on: bool) -> void:
	tgt["rain"] = float(SND["rain"]) if on else 0.0

## elige la voz del auto: los autos nuevos tienen la suya (VOICE, TURBO_SND, GEAR_SND); los demás siguen como estaban
func set_vehicle(id: String) -> void:
	if VOICE.has(id):
		vehicle_id = id
		voice = VOICE[id]

func _r() -> float:
	return rng.randf()

## Petardeos suaves del escape: solo en marchas bajas (1ª y 2ª) o al reducir de marcha, nunca a velocidad de ruta
func pops(_n: int) -> void:
	if not pops_ok or time - pop_t < 2.5:
		return # una ráfaga cada tanto: antes, con cambios seguidos, sonaba «pa pa pa» todo el tiempo como un tractor
	pop_t = time
	for i in _n:
		var d := 0.03 + _r() * 0.35
		var f := 700.0 + _r() * 700.0
		var a: float = SND["pops"] * float(voice.get("pops", 1.0)) * (0.35 + _r() * 0.35)
		get_tree().create_timer(d).timeout.connect(_shoot.bind("pop", a, f / 1000.0))

## el pedal que se usa para decidir los petardeos (el valor del cuadro)
func thr_now(p) -> float:
	return p.throttle

## flutter (surge del compresor): al soltar el acelerador con el turbo cargado, el aire rebota → "tu-tu-tu-tu" que se apaga
func flutter(b: float, T: Dictionary, L: float, mt: float) -> void:
	if mt <= 0.0 or time - fl_t < 2.0:
		return
	var amp: float = SND["flutter"] * b * (1.0 + 0.25 * L) * float(T["fl"]) * mt
	var smp := "flutter_hi" if b > 0.8 else ("flutter_mid" if b > 0.5 else "flutter_lo")
	_shoot(smp, amp, float(T["f"]))

func thump(strength: float) -> void:
	if time - thump_t < 0.15:
		return # rozando una pared los golpes llegaban en cada cuadro y se juntaban en un retumbo continuo
	thump_t = time
	_shoot("thump", minf(1.0, strength) * SND["impacts"])

## Un tono puro que no cambia de altura enseguida se vuelve un silbido que molesta. Si la frecuencia `f` casi no se mueve (menos de STEADY_RATE por segundo, mirando la tendencia y no
## el temblor de cuadro a cuadro) el volumen se va apagando de a poco hasta STEADY_MIN; en cuanto se mueve (acelerando, frenando) vuelve a sonar entero. Devuelve el factor (STEADY_MIN..1).
func _steady_gain(key: String, f: float, dt: float) -> float:
	var st: Dictionary = _steady.get(key, {"f": f, "rate": 0.0, "k": 1.0})
	var f_old := float(st["f"])
	var f_new := f_old + (f - f_old) * (1.0 - exp(-dt / 0.4)) # frecuencia alisada
	var rel := absf(f_new - f_old) / maxf(dt, 0.001) / maxf(f, 50.0)
	st["f"] = f_new
	st["rate"] = float(st["rate"]) + (rel - float(st["rate"])) * (1.0 - exp(-dt / 0.3))
	if float(st["rate"]) > STEADY_RATE:
		st["k"] = minf(1.0, float(st["k"]) + dt / 0.4)
	else:
		st["k"] = maxf(STEADY_MIN, float(st["k"]) - dt * (1.0 - STEADY_MIN) / STEADY_FADE_S)
	_steady[key] = st
	return float(st["k"])

## acerca cada parámetro a su objetivo (como setTargetAtTime)
func _smooth(dt: float) -> void:
	for k in TIME_K:
		var tau: float = gw_tau if k == "gw" else TIME_K[k]
		cur[k] += (tgt[k] - cur[k]) * (1.0 - exp(-dt / tau))

## p: estado del auto (interpolado); V: parámetros; events: eventos acumulados desde el último cuadro; impact: golpe de ruedas
func update(p: CarSnapshot, V: VehicleParams, dt: float, events: Array, impact: float) -> void:
	if not active:
		return
	time += dt
	var rpm := p.rpm
	var rn := clampf((rpm - V.idleRpm) / (V.maxRpm - V.idleRpm), 0.0, 1.0)
	var load := clampf(p.load, 0.0, 1.0)
	var f0 := rpm / 60.0 * V.firingOrder * float(voice.get("f", 1.0))
	tgt["f0"] = f0
	tgt["cut"] = (260.0 + load * 1500.0 + rn * 1600.0) * float(voice.get("cut", 1.0))
	var sp := sqrt(p.vx * p.vx + p.vz * p.vz)
	# parado y sin acelerar el motor no suena (el ralentí sonaba a motor de turismo carretera con petardeos): el sonido entra con el pedal o al andar
	var alive := clampf(maxf(p.throttle * 2.5, (sp - 0.6) / 3.0), 0.0, 1.0)
	tgt["eng"] = SND["engine"] * float(voice.get("eng", 1.0)) * mix["eng"] * (0.35 + 0.25 * rn) * (0.62 + 0.38 * load) * alive
	tgt["engn"] = 0.145 * load * float(voice.get("noise", 1.0)) # (el ruido mecánico está grabado más fuerte que antes: 0,145 deja el mismo nivel de siempre)
	var asf := 0.0
	var loose := 0.0
	var sl := 0.0
	var dirt := 0
	var nl := 0
	for i in 4:
		var o := i * 8
		if p.wheel_fx[o] < 0.5:
			continue
		var surf := int(p.wheel_fx[o + 1])
		if surf != 0:
			nl += 1
			if surf == 1 or surf == 5:
				dirt += 1
		var s2 := maxf(0.0, absf(p.wheel_fx[o + 3]) - 0.08) + maxf(0.0, absf(p.wheel_fx[o + 4]) - 0.1)
		if surf == 0:
			asf += 0.25
			sl = maxf(sl, s2)
		else:
			loose += 0.25 + s2
	var dirt_k := float(dirt) / float(nl) if nl > 0 else 0.0
	# «Gomas y tierra» manda sobre el rodado, el chillido y la tierra; «Viento y lluvia» sobre el viento y la lluvia (antes el rodado y la lluvia no tenían control)
	var surf_k := float(mix["surf"]) / SURF_DEFAULT
	var wind_k := float(mix["wind"]) / SURF_DEFAULT
	_rain_k = wind_k
	tgt["roll"] = SND["tires"] * surf_k * asf * minf(1.0, sp / 30.0)
	tgt["sq"] = SND["squeal"] * surf_k * clampf((sl - 0.08) * 3.0, 0.0, 1.0)
	tgt["sqf"] = 1000.0 + sl * 400.0 + _r() * 120.0
	# pasto/tierra: nada parado, sube con la velocidad; el pasto suena más suave que la tierra/ripio
	var mv := clampf((sp - 0.8) / 12.0, 0.0, 1.0)
	tgt["grav"] = SND["gravel"] * surf_k * minf(1.0, loose) * (0.35 + 0.65 * dirt_k) * mv * mv
	# viento: aire grave que sube con la velocidad (casi nada hasta ~20 km/h) y sopla con ráfagas lentas (dos ondas que no se alinean: nunca se repite igual)
	var gust := 1.0 + 0.18 * sin(time * 0.69) + 0.12 * sin(time * 1.09 + 1.3)
	tgt["wind"] = SND["wind"] * wind_k * pow(clampf((sp - 6.0) / 54.0, 0.0, 1.0), 1.7) * gust
	tgt["windf"] = 630.0 + sp * 3.5 # la muestra es grave y se corre un poco hacia arriba con la velocidad (pitch 0,9 … 1,2)
	# caja: el tono sigue a la velocidad (eje de salida × dientes); suena acelerando y más aún levantando el pie; se corta en cada cambio
	var G: Dictionary = GEAR_SND.get(vehicle_id, GEAR_SND["pickup"])
	var shaft := absf(p.vLong) / (TAU * V.wheelRadius) * V.finalDrive
	var wf := minf(WHINE_MAX_HZ, shaft * float(G["tooth"]) * 0.5)
	var drive := p.gear != 0 and p.clutchLocked and not (p.shiftT > 0.0)
	var coast := maxf(0.0, 0.5 - p.throttle) * 2.0
	var sk := clampf((absf(p.vLong) - 2.0) / 20.0, 0.0, 1.0)
	var gg: float = SND["whine"] * float(G["k"]) * mix["gear"] * sk * (0.55 + 0.3 * load + 0.45 * coast) * _steady_gain("whine", wf, dt) if drive else 0.0
	gw_tau = 0.05 if drive else 0.015
	tgt["gw"] = gg
	tgt["wf"] = wf
	tgt["gwe"] = gg * 0.25 * (0.4 + 0.6 * rn) if drive else 0.0
	tgt["gwef"] = minf(WHINE_MAX_HZ, rpm / 60.0 * float(G["tooth"]) * 0.36)
	# turbo: carga con retardo al acelerar y se vacía al soltar; silbido + soplido siguen la carga
	var T: Dictionary = TURBO_SND.get(vehicle_id, TURBO_SND["pickup"])
	var L := float(V.turboLvl)
	var mt: float = mix["turbo"]
	var thr := p.throttle
	# el flutter y los petardeos del escape solo suenan en 1ª y 2ª (arranque) o en los cambios hacia abajo; a 4ª/5ª ni se oyen
	var low_gear := p.gear >= 1 and p.gear <= 2 and sp < 22.0 and thr_now(p) < 0.5
	pops_ok = low_gear
	var bt := 0.0
	if thr > 0.35:
		bt = clampf((rpm - V.idleRpm * 1.5) / ((V.maxRpm - V.idleRpm) * 0.45), 0.0, 1.0) * minf(1.0, thr * 1.3) * (0.6 + 0.4 * load)
	var tc := (float(T["spool"]) * (1.0 - 0.12 * L)) if bt > boost else 0.12
	boost += (bt - boost) * (1.0 - exp(-dt / tc))
	var b := boost
	# el silbido sólo se oye mientras la carga se mueve (cargando o vaciándose); con el turbo estable queda un resto muy bajo. Antes, a fondo en una ruta, era un seno fijo de
	# 8 kHz que se quedaba sonando todo el tiempo
	var act := clampf(absf(b - _boost_prev) / maxf(dt, 0.001) * 1.6, 0.0, 1.0)
	_boost_prev = b
	spool += (act - spool) * (1.0 - exp(-dt / (0.12 if act > spool else 1.1)))
	var twf := minf(WHISTLE_MAX_HZ, float(T["f"]) * (1500.0 + b * b * 1900.0))
	tgt["tw"] = SND["whistle"] * float(T["w"]) * (1.0 + 0.3 * L) * mt * pow(b, 1.5) * (0.5 + 0.5 * load) * (0.2 + 0.8 * spool)
	tgt["twf"] = twf
	tgt["tb"] = SND["turbo"] * mt * b * (0.4 + 0.6 * load) * (0.35 + 0.65 * spool)
	tgt["tbf"] = twf * 0.9
	# se recuerda cuánto turbo había con el pie a fondo: al soltar (en rampa) la carga ya cayó, pero el flutter suena igual
	if thr > 0.5:
		arm_b = maxf(b, arm_b * 0.98)
	if thr < 0.25 and arm_b > 0.25 and time - fl_t > 0.9 and low_gear:
		flutter(arm_b, T, L, mt)
		fl_t = time
		boost *= 0.3
		arm_b = 0.0
	elif thr < 0.25:
		arm_b = 0.0
	for e in events:
		if e is String and e == "shift_up" and b > 0.45 and time - fl_t > 0.9 and low_gear:
			flutter(b * 0.55, T, L, mt)
			fl_t = time
			boost *= 0.6
	if prev_thr > 0.6 and thr < 0.15 and rpm > 4200.0 and sp > 3.0 and low_gear:
		pops(2 + int(_r() * 2.0))
	prev_thr = thr
	for e in events:
		if e is String:
			if e == "shift_down" and sp > 3.0 and sp < 25.0 and p.gear <= 3 and thr < 0.3:
				pops_ok = true # al bajar de marcha levantando el pie el escape crepita (suave y corto)
				pops(2)
				pops_ok = low_gear
		elif e is Array and e[0] == "land":
			thump(float(e[1]) / 4.0)
	if impact > 1.4:
		thump((impact - 1.2) / 5.0)
	_smooth(dt)
	_apply()

## pasa los valores suavizados a las voces
func _apply() -> void:
	var base_f: float = float(consts["engine_base_hz"])
	var tone: float = float(consts["tone_base_hz"])
	var f0: float = cur["f0"]
	var eg: float = cur["eng"]
	_set_voice("engine", eg, f0 / 8.0 / base_f)
	lp_engine.cutoff_hz = clampf(cur["cut"], 100.0, 20000.0)
	_set_voice("engnoise", cur["engn"] * eg, f0 / 200.0)
	_set_voice("roll", cur["roll"], 1.0)
	_set_voice("squeal", cur["sq"], cur["sqf"] / 1150.0)
	_set_voice("gravel", cur["grav"], 1.0)
	_set_voice("wind", cur["wind"], cur["windf"] / 700.0)
	_set_voice("turbo", cur["tb"], cur["tbf"] / 2600.0)
	_set_voice("rain", cur["rain"] * _rain_k, 1.0)
	var w: float = maxf(40.0, cur["wf"])
	_set_voice("whine1", cur["gw"] * 0.418, w / tone)
	_set_voice("whine2", cur["gw"] * 0.328, w * 1.007 / tone)
	_set_voice("gwe", cur["gwe"], cur["gwef"] / tone)
	_set_voice("whistle", cur["tw"], cur["twf"] / tone)
	_set_voice("engine_ai", cur["ai"], cur["aif"] * 0.5 / base_f)

## motor de un rival cercano: d = distancia (o -1 si no hay), rpm del rival
func rival(d: float, rpm: float, fo: float) -> void:
	tgt["ai"] = 0.0 if d < 0.0 else 0.16 * pow(maxf(0.0, 1.0 - d / 55.0), 1.5)
	tgt["aif"] = (rpm if rpm > 0.0 else 1000.0) / 60.0 * (fo if fo > 0.0 else 4.0) * 0.5
