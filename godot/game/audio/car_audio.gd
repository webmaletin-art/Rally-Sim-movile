extends Node
## Sonido del auto del jugador: traduce el estado de la física a parámetros del sintetizador (AudioEngine.update de la versión
## HTML) y lo hace sonar con un AudioStreamGenerator alimentado desde un hilo aparte (así un cuadro lento no corta el audio).

const CarSynth := preload("res://game/audio/car_synth.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

## niveles generales (los mismos de la versión web)
const SND := {"master": 0.55, "engine": 0.62, "tires": 0.35, "squeal": 0.28, "gravel": 0.45, "wind": 0.25, "turbo": 0.10, "whistle": 0.06, "flutter": 0.75, "whine": 0.06, "pops": 0.35, "impacts": 0.8, "firingOrder": 4}
const TURBO_SND := {
	"pickup": {"f": 1.0, "spool": 0.55, "w": 1.0, "fl": 1.0}, "t1plus": {"f": 1.12, "spool": 0.42, "w": 0.8, "fl": 0.9},
	"truck": {"f": 0.55, "spool": 0.9, "w": 0.9, "fl": 1.2}, "genesis": {"f": 1.3, "spool": 0.3, "w": 1.1, "fl": 1.0}}
const GEAR_SND := {
	"pickup": {"k": 0.55, "tooth": 40.0}, "t1plus": {"k": 1.0, "tooth": 48.0},
	"truck": {"k": 0.8, "tooth": 34.0}, "genesis": {"k": 0.8, "tooth": 44.0}}

var synth: RefCounted
var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var thread: Thread
var running := false
var active := true
var vehicle_id := "t1plus"
var mix := {"eng": 1.0, "surf": 0.3, "wind": 0.3, "turbo": 1.0, "gear": 1.0}
var volume := 80.0
var boost := 0.0
var arm_b := 0.0
var fl_t := -9.0
var prev_thr := 0.0
var time := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	synth = CarSynth.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = CarSynth.FS
	gen.buffer_length = 0.16
	player = AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = 0.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	apply_settings()
	running = true
	thread = Thread.new()
	thread.start(_loop, Thread.PRIORITY_HIGH)

func _exit_tree() -> void:
	running = false
	if thread != null and thread.is_started():
		thread.wait_to_finish()

func _loop() -> void:
	var cap := int(0.16 * CarSynth.FS)
	var want := int(0.06 * CarSynth.FS) # cuánto audio se mantiene en cola (≈ 60 ms de retardo)
	while running:
		var queued := cap - playback.get_frames_available()
		if active and queued < want:
			var blk: PackedFloat32Array = synth.render(256)
			var fr := PackedVector2Array()
			fr.resize(blk.size())
			for i in blk.size():
				fr[i] = Vector2(blk[i], blk[i])
			playback.push_buffer(fr)
		else:
			OS.delay_msec(4)

func apply_settings() -> void:
	synth.set_target(CarSynth.P_MASTER, SND["master"] * volume / 80.0)

func set_active(v: bool) -> void:
	active = v
	if not v:
		for i in CarSynth.NP:
			if i not in [CarSynth.P_F0, CarSynth.P_CUT, CarSynth.P_SQF, CarSynth.P_WINDF, CarSynth.P_WF, CarSynth.P_GWEF, CarSynth.P_TWF, CarSynth.P_TBF, CarSynth.P_AIF, CarSynth.P_MASTER]:
				synth.target[i] = 0.0
				synth.cur[i] = 0.0

func rain(on: bool) -> void:
	synth.set_target(CarSynth.P_RAIN, 0.10 if on else 0.0)

func _r() -> float:
	return rng.randf()

func pops(n: int) -> void:
	for i in n:
		synth.burst(0.03 + _r() * 0.35, 0.03 + _r() * 0.03, 700.0 + _r() * 700.0, 1.2, SND["pops"] * (0.5 + _r() * 0.5))

## flutter (surge del compresor): al soltar el acelerador con el turbo cargado, el aire rebota → "tu-tu-tu-tu" que se apaga
func flutter(b: float, T: Dictionary, L: float, mt: float) -> void:
	if mt <= 0.0:
		return
	var amp: float = SND["flutter"] * b * (1.0 + 0.25 * L) * float(T["fl"]) * mt
	var n := int(round(5.0 + b * 9.0))
	var f: float = (850.0 + 350.0 * b) * float(T["f"])
	var tt := 0.015
	var step := 0.027 / sqrt(float(T["f"]))
	for i in n:
		var k := 1.0 - float(i) / float(n)
		synth.burst(tt, 0.016 + 0.012 * k, f * (1.0 - 0.018 * float(i)), 2.6, amp * pow(k, 1.2) * (0.75 + 0.5 * _r()))
		tt += step * (1.0 + 0.07 * float(i))
	synth.burst(0.015, 0.16 + 0.2 * b, 2300.0 * float(T["f"]), 0.8, amp * 0.22)

## p: estado del auto (interpolado); V: parámetros; events: eventos acumulados desde el último cuadro; impact: golpe de ruedas
func update(p: CarSnapshot, V: VehicleParams, dt: float, events: Array, impact: float) -> void:
	if not active:
		return
	time += dt
	var S := synth
	var rpm := p.rpm
	var rn := clampf((rpm - V.idleRpm) / (V.maxRpm - V.idleRpm), 0.0, 1.0)
	var load := clampf(p.load, 0.0, 1.0)
	var fo: float = V.firingOrder
	var f0 := rpm / 60.0 * fo
	S.set_target(CarSynth.P_F0, f0)
	S.set_target(CarSynth.P_CUT, 260.0 + load * 1500.0 + rn * 1600.0)
	var eg: float = SND["engine"] * mix["eng"] * (0.35 + 0.25 * rn) * (0.62 + 0.38 * load) * (0.7 if p.limiter else 1.0)
	S.set_target(CarSynth.P_ENG, eg)
	S.set_target(CarSynth.P_ENGN, 0.25 * load)
	var sp := sqrt(p.vx * p.vx + p.vz * p.vz)
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
	S.set_target(CarSynth.P_ROLL, SND["tires"] * asf * minf(1.0, sp / 30.0))
	S.set_target(CarSynth.P_SQ, SND["squeal"] * clampf((sl - 0.08) * 3.0, 0.0, 1.0))
	S.set_target(CarSynth.P_SQF, 1000.0 + sl * 400.0 + _r() * 120.0)
	# pasto/tierra: nada parado, sube con la velocidad; el pasto suena más suave que la tierra/ripio
	var mv := clampf((sp - 0.8) / 12.0, 0.0, 1.0)
	S.set_target(CarSynth.P_GRAV, SND["gravel"] * mix["surf"] * minf(1.0, loose) * (0.35 + 0.65 * dirt_k) * mv * mv * (0.8 + _r() * 0.4))
	S.set_target(CarSynth.P_WIND, SND["wind"] * mix["wind"] * pow(clampf((sp - 6.0) / 42.0, 0.0, 1.0), 2.0))
	S.set_target(CarSynth.P_WINDF, 500.0 + sp * 18.0)
	# caja: el tono sigue a la velocidad (eje de salida × dientes); suena acelerando y más aún levantando el pie; se corta en cada cambio
	var G: Dictionary = GEAR_SND.get(vehicle_id, GEAR_SND["pickup"])
	var shaft := absf(p.vLong) / (TAU * V.wheelRadius) * V.finalDrive
	var wf := minf(4200.0, shaft * float(G["tooth"]))
	var drive := p.gear != 0 and p.clutchLocked and not (p.shiftT > 0.0)
	var coast := maxf(0.0, 0.5 - p.throttle) * 2.0
	var sk := clampf((absf(p.vLong) - 2.0) / 20.0, 0.0, 1.0)
	var gg: float = SND["whine"] * float(G["k"]) * mix["gear"] * sk * (0.55 + 0.3 * load + 0.45 * coast) if drive else 0.0
	S.gw_tau = 0.05 if drive else 0.015
	S.set_target(CarSynth.P_GW, gg)
	S.set_target(CarSynth.P_WF, wf)
	S.set_target(CarSynth.P_GWE, gg * 0.25 * (0.4 + 0.6 * rn) if drive else 0.0)
	S.set_target(CarSynth.P_GWEF, rpm / 60.0 * float(G["tooth"]) * 0.36)
	# turbo: carga con retardo al acelerar y se vacía al soltar; silbido + soplido siguen la carga
	var T: Dictionary = TURBO_SND.get(vehicle_id, TURBO_SND["pickup"])
	var L := float(V.turboLvl)
	var mt: float = mix["turbo"]
	var thr := p.throttle
	var bt := 0.0
	if thr > 0.35:
		bt = clampf((rpm - V.idleRpm * 1.5) / ((V.maxRpm - V.idleRpm) * 0.45), 0.0, 1.0) * minf(1.0, thr * 1.3) * (0.6 + 0.4 * load)
	var tc := (float(T["spool"]) * (1.0 - 0.12 * L)) if bt > boost else 0.12
	boost += (bt - boost) * (1.0 - exp(-dt / tc))
	var b := boost
	var twf := float(T["f"]) * (1800.0 + b * b * 5200.0)
	S.set_target(CarSynth.P_TW, SND["whistle"] * float(T["w"]) * (1.0 + 0.3 * L) * mt * pow(b, 1.5) * (0.5 + 0.5 * load))
	S.set_target(CarSynth.P_TWF, twf)
	S.set_target(CarSynth.P_TB, SND["turbo"] * mt * b * (0.4 + 0.6 * load))
	S.set_target(CarSynth.P_TBF, twf * 0.9)
	# se recuerda cuánto turbo había con el pie a fondo: al soltar (en rampa) la carga ya cayó, pero el flutter suena igual
	if thr > 0.5:
		arm_b = maxf(b, arm_b * 0.98)
	if thr < 0.25 and arm_b > 0.25 and time - fl_t > 0.35:
		flutter(arm_b, T, L, mt)
		fl_t = time
		boost *= 0.3
		arm_b = 0.0
	elif thr < 0.25:
		arm_b = 0.0
	for e in events:
		if e is String and e == "shift_up" and b > 0.45 and time - fl_t > 0.35:
			flutter(b * 0.55, T, L, mt)
			fl_t = time
			boost *= 0.6
	if prev_thr > 0.6 and thr < 0.15 and rpm > 4200.0:
		pops(2 + int(_r() * 4.0))
	prev_thr = thr
	for e in events:
		if e is String:
			if e == "shift_up":
				pops(1)
			elif e == "limiter":
				pops(2)
		elif e is Array and e[0] == "land":
			S.thump(float(e[1]) / 4.0, SND["impacts"])
	if impact > 1.4:
		S.thump((impact - 1.2) / 5.0, SND["impacts"])

## motor de un rival cercano: d = distancia (o -1 si no hay), rpm del rival
func rival(d: float, rpm: float, fo: float) -> void:
	var g := 0.0 if d < 0.0 else 0.16 * pow(maxf(0.0, 1.0 - d / 55.0), 1.5)
	synth.set_target(CarSynth.P_AI, g)
	synth.set_target(CarSynth.P_AIF, (rpm if rpm > 0.0 else 1000.0) / 60.0 * (fo if fo > 0.0 else 4.0) * 0.5)
