extends Node
## Audio del mundo abierto (Etapa 20): ambiente de ciudad según el tránsito y la hora, viento y lluvia según el clima, truenos que suenan a la vez para todos (salen de la hora del mundo),
## motores del tránsito civil en 3D (suenan de donde vienen, con efecto Doppler) y eco bajo tierra (túneles y estacionamientos).
## Todo reusa las muestras que ya están (rodado, viento, lluvia, motor de rival, golpe grave): no suma archivos ni peso. Los motores en 3D son pocos (2–4 según la calidad).
## La lógica de decisión está en funciones estáticas (se prueba sin audio): pick_nearest, doppler, engine_pitch, bed_level, thunder_events.

const DIR := "res://game/audio/samples/"
const SPEED_OF_SOUND := 343.0
const ENGINE_R := 60.0 # a esta distancia el motor de un auto del tránsito ya no suena
const KEEP_R := 75.0 # un auto que ya suena se conserva hasta esta distancia (así no cambian de lugar de golpe)
const THUNDER_SLOT := 9.0 # segundos de mundo por casilla de truenos
const BED_FULL := 8.0 # autos cerca para el ruido de ciudad completo

var race
var consts: Dictionary
var rng := RandomNumberGenerator.new()
var level := 0.7 # volumen del ambiente (0..1; opción «Ambiente del mundo»)
var engines: Array = [] # {p: AudioStreamPlayer3D, veh: Veh | null, vlin: float}
var voices: Dictionary = {} # nombre → {p, unit}
var thunders: Array = [] # AudioStreamPlayer
var reverb: AudioEffectReverb
var amb_bus := -1
var _pick_t := 0.0
var _slot_done := -1
var _density := 0.0
var _bed := 0.0
var _gust := 0.0
var _verb := 0.0
var _prev_pl := Vector2.ZERO
var _pl_vel := Vector2.ZERO
var enabled := true

func setup(p_race, n_engines: int) -> void:
	race = p_race
	rng.randomize()
	consts = JSON.parse_string(FileAccess.get_file_as_string(DIR + "consts.json"))
	amb_bus = _make_bus("GSAmbiente", 900.0)
	_make_bus("GSAmbViento", 520.0)
	if AudioServer.get_bus_index("GSRival") < 0:
		_make_bus("GSRival", 900.0)
	_voice("bed", "roll", "GSAmbiente")
	_voice("gust", "wind", "GSAmbViento")
	var thump: AudioStreamWAV = load(DIR + "thump.wav") as AudioStreamWAV
	for i in 2:
		var tp := AudioStreamPlayer.new()
		tp.stream = thump
		tp.bus = "GSAmbiente"
		add_child(tp)
		thunders.append(tp)
	var eng: AudioStreamWAV = (load(DIR + "engine_ai.wav") as AudioStreamWAV).duplicate()
	eng.loop_mode = AudioStreamWAV.LOOP_FORWARD
	eng.loop_begin = 0
	eng.loop_end = int(consts["engine_ai"]["n"])
	for i in n_engines:
		var p := AudioStreamPlayer3D.new()
		p.stream = eng
		p.bus = "GSRival"
		p.unit_size = 7.0
		p.max_distance = ENGINE_R + 20.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		p.volume_db = -80.0
		add_child(p)
		engines.append({"p": p, "veh": null, "vlin": 0.0})
	# eco bajo tierra: un reverb en el Master que sólo se enciende dentro de túneles y estacionamientos
	reverb = AudioEffectReverb.new()
	reverb.room_size = 0.55
	reverb.damping = 0.6
	reverb.wet = 0.0
	reverb.dry = 1.0
	AudioServer.add_bus_effect(0, reverb, 0)
	AudioServer.set_bus_effect_enabled(0, 0, false)

func _exit_tree() -> void:
	if reverb != null:
		for i in AudioServer.get_bus_effect_count(0):
			if AudioServer.get_bus_effect(0, i) == reverb:
				AudioServer.remove_bus_effect(0, i)
				break

func _make_bus(bus_name: String, cutoff: float) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i >= 0:
		return i
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = cutoff
	lp.resonance = 0.45
	lp.db = AudioEffectFilter.FILTER_24DB
	AudioServer.add_bus_effect(i, lp)
	return i

func _voice(vname: String, sample: String, bus: String) -> void:
	var w: AudioStreamWAV = (load(DIR + sample + ".wav") as AudioStreamWAV).duplicate()
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = int(consts[sample]["n"])
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play(rng.randf() * 1.5)
	p.stream_paused = true
	voices[vname] = {"p": p, "unit": float(consts[sample]["unit"])}

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
	p.pitch_scale = clampf(pitch, 0.1, 4.0)

# ───────────── decisiones (puras, sin audio) ─────────────
## Los n autos más cercanos a pos (dentro de r), ya asignados primero si siguen dentro de keep_r. veh_list: [{pos: Vector3, crashed: bool}] (o Veh de civil_traffic).
static func pick_nearest(veh_list: Array, pos: Vector3, r: float, n: int, current: Array = [], keep_r := KEEP_R) -> Array:
	var cand: Array = []
	for v in veh_list:
		if v.crashed:
			continue
		var d: float = (v.pos as Vector3).distance_to(pos)
		var lim := keep_r if current.has(v) else r
		if d <= lim:
			cand.append([d - (6.0 if current.has(v) else 0.0), v]) # el que ya suena gana un poco de ventaja (histéresis)
	cand.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for i in mini(n, cand.size()):
		out.append(cand[i][1])
	return out

## Efecto Doppler: closing = velocidad con la que se acercan (m/s, negativa si se alejan)
static func doppler(closing: float) -> float:
	return clampf(SPEED_OF_SOUND / (SPEED_OF_SOUND - clampf(closing, -60.0, 60.0)), 0.8, 1.25)

## Velocidad de reproducción del motor de un auto del tránsito según su velocidad (m/s): ralentí ≈ 0,32 y a 20 m/s ≈ 0,7 (misma escala que el motor de rival)
static func engine_pitch(speed: float) -> float:
	var rpm := 850.0 + clampf(speed, 0.0, 40.0) * 58.0
	return (rpm / 60.0 * 4.0 * 0.5) * 0.5 / 42.0

## Ruido de ciudad (0..1): crece con los autos cerca, baja de noche y a alta velocidad del jugador el viento lo tapa
static func bed_level(cars_near: float, night: float, player_speed: float) -> float:
	var base := clampf(cars_near / BED_FULL, 0.0, 1.0)
	return base * lerpf(1.0, 0.45, clampf(night, 0.0, 1.0)) * lerpf(1.0, 0.55, clampf(player_speed / 40.0, 0.0, 1.0))

## Truenos entre dos horas del mundo (t0, t1): iguales para todos los jugadores (salen de la semilla y la hora). Cada casilla de THUNDER_SLOT s tiene 55 % de probabilidad.
static func thunder_events(world_seed: int, t0: float, t1: float) -> Array:
	var out: Array = []
	var s0 := int(floor(t0 / THUNDER_SLOT))
	var s1 := int(floor(t1 / THUNDER_SLOT))
	for s in range(s0, s1 + 1):
		var h := absi(hash(Vector3i(world_seed, s, 7331)))
		if h % 100 >= 55:
			continue
		var t := (float(s) + float((h / 100) % 1000) / 1000.0) * THUNDER_SLOT
		if t >= t0 and t < t1:
			out.append({"t": t, "strength": 0.5 + float((h / 100000) % 100) / 200.0})
	return out

# ───────────── cuadro a cuadro ─────────────
func set_level(v: float) -> void:
	level = clampf(v, 0.0, 1.0)

func update(dt: float, pl: Vector2, pl_speed: float) -> void:
	if not enabled or level <= 0.001:
		_silence()
		return
	var clk = race.clock
	var night: float = float(clk.night) if clk != null else 0.0
	var wx: Dictionary = clk.wx if clk != null else {}
	var tsys = race.world_life.get_system("traffic") if race.world_life != null else null
	var vehs: Array = tsys.vehicles if tsys != null else []
	_pl_vel = _pl_vel.lerp((pl - _prev_pl) / maxf(dt, 0.001), 1.0 - exp(-6.0 * dt))
	_prev_pl = pl
	var pos3 := Vector3(pl.x, float(race.cars[0].phys.py), pl.y)
	# autos del tránsito cerca (ruido de ciudad) y motores 3D
	_pick_t -= dt
	if _pick_t <= 0.0:
		_pick_t = 0.3
		var near_n := 0
		for v in vehs:
			if (v.pos as Vector3).distance_squared_to(pos3) < 150.0 * 150.0:
				near_n += 1
		_density = float(near_n)
		_assign(vehs, pos3)
	var k := 1.0 - exp(-1.5 * dt)
	_bed = lerpf(_bed, bed_level(_density, night, pl_speed), k)
	_set_voice("bed", _bed * 0.16 * level, 0.9)
	# viento ambiente: un poco siempre, más con tormenta, nubes y con la altura (la ruta panorámica sube)
	var storm := 1.0 if str(wx.get("kind", "clear")) == "storm" else 0.0
	var alt := clampf((pos3.y - 40.0) / 160.0, 0.0, 1.0)
	var gust_t := 0.03 + 0.10 * float(wx.get("cloud", 0.0)) + 0.18 * storm + 0.08 * alt
	_gust = lerpf(_gust, gust_t, k)
	_set_voice("gust", _gust * level, 0.8 + 0.4 * alt)
	# truenos
	if str(wx.get("kind", "clear")) == "storm" and race.world_life != null:
		_thunder(float(race.world_life.clock.now()))
	else:
		_slot_done = -1
	# motores 3D
	for e in engines:
		_move_engine(e, pos3, dt)
	# eco bajo tierra
	var ug: float = float(race._ug)
	_verb = lerpf(_verb, ug, 1.0 - exp(-3.0 * dt))
	var on := _verb > 0.03
	AudioServer.set_bus_effect_enabled(0, 0, on)
	if on:
		reverb.wet = 0.28 * _verb * level

func _silence() -> void:
	for n in voices:
		(voices[n]["p"] as AudioStreamPlayer).stream_paused = true
	for e in engines:
		(e["p"] as AudioStreamPlayer3D).volume_db = -80.0
	AudioServer.set_bus_effect_enabled(0, 0, false)

func _assign(vehs: Array, pos3: Vector3) -> void:
	var current: Array = []
	for e in engines:
		if e["veh"] != null:
			current.append(e["veh"])
	var want: Array = pick_nearest(vehs, pos3, ENGINE_R, engines.size(), current)
	for e in engines:
		if e["veh"] != null and not want.has(e["veh"]):
			e["veh"] = null
			e["vlin"] = 0.0
	for v in want:
		var has := false
		for e in engines:
			if e["veh"] == v:
				has = true
				break
		if has:
			continue
		for e in engines:
			if e["veh"] == null:
				e["veh"] = v
				e["vlin"] = 0.0
				(e["p"] as AudioStreamPlayer3D).volume_db = -80.0
				break

func _move_engine(e: Dictionary, pos3: Vector3, dt: float) -> void:
	var p: AudioStreamPlayer3D = e["p"]
	var v = e["veh"]
	if v == null:
		if p.playing:
			p.volume_db = -80.0
			p.stop()
		return
	if not p.playing:
		p.play(rng.randf())
	var vp: Vector3 = v.pos
	p.global_position = vp + Vector3(0.0, 0.6, 0.0)
	var spd: float = float(v.v)
	var to_pl := Vector2(pos3.x - vp.x, pos3.z - vp.z)
	var dist := maxf(to_pl.length(), 0.5)
	var dirv := to_pl / dist
	var vel_v := Vector2(sin(float(v.yaw)), cos(float(v.yaw))) * spd # el auto avanza hacia (sin yaw, cos yaw)
	var closing := vel_v.dot(dirv) - _pl_vel.dot(dirv)
	p.pitch_scale = clampf(engine_pitch(spd) * doppler(closing), 0.1, 2.5)
	e["vlin"] = lerpf(float(e["vlin"]), 0.20 * level * (0.55 + 0.45 * clampf(spd / 14.0, 0.0, 1.0)), 1.0 - exp(-6.0 * dt))
	p.volume_db = linear_to_db(maxf(float(e["vlin"]) * float(consts["engine_ai"]["unit"]), 1e-4))

func _thunder(t_now: float) -> void:
	var slot := int(floor(t_now / THUNDER_SLOT))
	if slot == _slot_done:
		return
	var from := maxf(t_now - 0.5, float(slot) * THUNDER_SLOT)
	if _slot_done < 0:
		from = t_now # al entrar al mundo no suena un trueno atrasado
	_slot_done = slot
	for ev in thunder_events(int(race.world_life.state.world_seed), from, float(slot + 1) * THUNDER_SLOT):
		var delay: float = maxf(0.0, float(ev["t"]) - t_now)
		get_tree().create_timer(delay).timeout.connect(_boom.bind(float(ev["strength"])))

func _boom(strength: float) -> void:
	for tp in thunders:
		var p: AudioStreamPlayer = tp
		if not p.playing:
			p.volume_db = linear_to_db(maxf(0.9 * strength * level * float(consts["thump"]["unit"]), 1e-4))
			p.pitch_scale = 0.22 + 0.12 * strength
			p.play()
			return
