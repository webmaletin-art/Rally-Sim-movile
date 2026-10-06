extends RefCounted
## WORLD LIFE: la capa de «vida» del mundo, separada del mapa (el cuerpo) y del jugador. Este es el NÚCLEO: reloj, semilla, versión, sectores, reglas, ON/OFF y la sincronización
## inicial online. Los sistemas de vida (tráfico, estacionados, semáforos, peatones…) se registran acá con register_system(); el núcleo no sabe nada de cada uno.
##
##   WorldLife → WorldState (id, versión, semilla) · WorldClock (tiempo) · WorldSectorManager (qué hay cerca) · WorldLifeConfig (reglas) · sistemas registrados
##
## Offline y online usan el MISMO núcleo; sólo cambia de dónde salen id, versión, semilla y tiempo (local, o del servidor al entrar: RPC world_join). El servidor no simula nada.
## Con World Life en OFF el mapa, el auto, el GPS y el online siguen igual: se apagan los sistemas de vida, se libera lo que instanciaron y no queda trabajo por cuadro
## (el reloj es un cálculo derivado, no un proceso).

const WorldState := preload("res://game/world/world_state.gd")
const WorldClock := preload("res://game/world/world_clock.gd")
const WorldSeed := preload("res://game/world/world_seed.gd")
const WorldLifeConfig := preload("res://game/world/world_life_config.gd")
const WorldSectorManager := preload("res://game/world/world_sector_manager.gd")

var state := WorldState.new()
var clock := WorldClock.new()
var sectors := WorldSectorManager.new()
var cfg: Dictionary = {}
var systems: Array = []
var _sys_acc: Array = [] # tiempo acumulado por sistema (para respetar su update_hz)
var _tick_acc := 0.0
var _resync_t := 0.0
var _syncing := false
var _online: Node
var rebuilds := 0 # cuántas veces se reconstruyó (para comprobar)
# presupuesto de CPU (Etapa 22): se mide cuánto cuesta la vida del mundo por cuadro y, si pasa el tope del perfil, se achican los topes y las frecuencias solos (y se recuperan al aliviarse)
const BUDGET_MS := {"LOW": 1.6, "MEDIUM": 2.6, "HIGH": 4.0}
const MAX_THROTTLE := 3
var life_ms := 0.0 # costo promedio por cuadro de todos los sistemas (ms)
var sys_ms: Dictionary = {} # id → costo promedio por cuadro (ms)
var _frame_acc: Dictionary = {}
var spike_ms := 0.0 # lo más caro que costó un cambio de sector (ms; baja de a poco)
var throttle := 0 # 0 = todo normal … 3 = al mínimo
var _over_t := 0.0
var _under_t := 0.0

## profile: perfil del jugador (para la semilla local, la hora guardada y el perfil de rendimiento). cell: lado del sector (el de la cuadrícula de la ciudad).
func setup(profile: RefCounted, cell := 0.0) -> void:
	cfg = WorldLifeConfig.get_config()
	state.config_version = WorldLifeConfig.version()
	state.world_id = str(cfg.get("local_world_id", "dream_city_local"))
	state.world_version = state.config_version
	state.mode = "offline"
	var w: Dictionary = (cfg.get("worlds", {}) as Dictionary).get("dream_city", {})
	clock.day_seconds = float(w.get("day_seconds", 960.0))
	var sy: Dictionary = cfg.get("sync", {})
	clock.max_slew = float(sy.get("max_slew", 0.08))
	clock.snap_seconds = float(sy.get("snap_seconds", 45.0))
	# semilla local ESTABLE: se crea una vez y queda en el perfil
	var sd := 0
	if profile != null:
		sd = int(profile.d.get("worldSeed", 0))
		if sd == 0:
			sd = (int(Time.get_unix_time_from_system()) * 2654435761 + 12345) & 0x1FFFFFFFFFFFFF
			profile.d["worldSeed"] = sd
			profile.save()
	state.world_seed = sd if sd != 0 else 20261004
	# hora local: la guardada (el ciclo de la ciudad la guardaba como «tod») o la de arranque
	var start_t := clock.time_for_hour(float(w.get("start_hour", 9.0)))
	if profile != null:
		if profile.d.has("worldTime"):
			start_t = float(profile.d["worldTime"])
		elif profile.d.has("tod"):
			start_t = clock.time_for_hour(float(profile.d["tod"]))
	clock.set_reference(start_t, float(w.get("time_scale", 1.0)), false)
	set_profile(WorldLifeConfig.profile_for(profile))
	sectors.cell = cell if cell > 0.0 else float((cfg.get("sector", {}) as Dictionary).get("size", 160.0))
	_configure_sectors()
	_resync_t = float(sy.get("resync_seconds", 120.0))

func set_profile(name: String) -> void:
	state.profile_name = name
	state.rules = WorldLifeConfig.profile_rules(name)
	_configure_sectors()

func _configure_sectors() -> void:
	sectors.configure(sectors.cell, cfg.get("activation", {}), float(state.rules.get("dist_scale", 1.0)))

# ───────────────────────── ON / OFF ─────────────────────────
## Sistemas apagados a mano desde el menú de diagnóstico (id → true). Mientras esté vacío nada cambia: ni se enteran del resto del código.
var muted: Dictionary = {}

func set_muted(id: String, on: bool) -> void:
	var s = get_system(id)
	if s == null or on == muted.has(id):
		return
	if on:
		muted[id] = true
		s.disable() # libera todo lo que instanció
	else:
		muted.erase(id)
		if state.enabled:
			s.enable()
			s.rebuild()

func is_enabled() -> bool:
	return state.enabled

func set_enabled(on: bool) -> void:
	if on == state.enabled:
		return
	state.enabled = on
	if on:
		for s in systems:
			if not muted.has(s.system_id):
				s.enable()
		rebuild()
	else:
		for s in systems:
			s.disable() # cada sistema libera lo que instanció
		sectors.clear()
		_tick_acc = 0.0
		for i in _sys_acc.size():
			_sys_acc[i] = 0.0

func register_system(sys) -> void:
	systems.append(sys)
	_sys_acc.append(0.0)
	sys.setup(self)
	if state.enabled:
		sys.enable()
		sys.rebuild()

func get_system(id: String):
	for s in systems:
		if s.system_id == id:
			return s
	return null

## Reconstruye el estado lógico de todos los sistemas desde id + versión + semilla + tiempo (no se guarda nada por objeto)
func rebuild() -> void:
	rebuilds += 1
	for s in systems:
		if not muted.has(s.system_id):
			s.rebuild()
	if sectors.sector.x > -99999:
		for s in systems:
			if not muted.has(s.system_id):
				s.on_sector_changed()

# ───────────────────────── por cuadro ─────────────────────────
## Se llama una vez por cuadro con la posición del auto (x, z). Con World Life en OFF casi no hace nada.
func update(dt: float, player_xz: Vector2) -> void:
	clock.tick(dt)
	if not state.enabled:
		return
	state.player_pos = player_xz
	var t_frame := Time.get_ticks_usec()
	if sectors.update(player_xz):
		state.player_sector = sectors.sector
		var t_sec := Time.get_ticks_usec()
		for s in systems:
			if muted.has(s.system_id):
				continue
			var t_s := Time.get_ticks_usec()
			s.on_sector_changed()
			_note(str(s.system_id), float(Time.get_ticks_usec() - t_s) / 1000.0)
		spike_ms = maxf(spike_ms, float(Time.get_ticks_usec() - t_sec) / 1000.0)
	var hz_k := hz_scale()
	for i in systems.size():
		var sys = systems[i]
		if muted.has(sys.system_id):
			continue
		_sys_acc[i] += dt
		var period := 1.0 / maxf(float(sys.update_hz) * hz_k, 0.1)
		if _sys_acc[i] >= period:
			var acc: float = _sys_acc[i]
			_sys_acc[i] = 0.0
			var t_s := Time.get_ticks_usec()
			sys.update(acc)
			_note(str(sys.system_id), float(Time.get_ticks_usec() - t_s) / 1000.0)
	spike_ms = maxf(0.0, spike_ms - dt * 2.0)
	govern(float(Time.get_ticks_usec() - t_frame) / 1000.0, dt)
	if _online != null and not _syncing:
		_resync_t -= dt
		if _resync_t <= 0.0:
			_resync_t = float((cfg.get("sync", {}) as Dictionary).get("resync_seconds", 120.0))
			_sync_online(false)

func _note(id: String, ms: float) -> void:
	_frame_acc[id] = float(_frame_acc.get(id, 0.0)) + ms

## Tope de CPU de la vida del mundo (ms por cuadro) para el perfil actual
func budget_ms() -> float:
	return float(BUDGET_MS.get(state.profile_name, 2.6))

## Cuánto se achican los topes (autos, estacionados, peatones) con el estrangulamiento actual
func cap_scale() -> float:
	return pow(0.8, float(throttle))

func scaled_cap(n: int) -> int:
	return 0 if n <= 0 else maxi(1, int(round(float(n) * cap_scale())))

func hz_scale() -> float:
	return 1.0 - 0.15 * float(throttle)

## Decide el estrangulamiento con el costo del cuadro (ms). Más de 2 s pasado del tope → un escalón más; más de 6 s holgado → un escalón menos.
func govern(frame_ms: float, dt: float) -> void:
	life_ms = lerpf(life_ms, frame_ms, clampf(dt * 3.0, 0.0, 1.0))
	for k in _frame_acc.keys():
		sys_ms[k] = lerpf(float(sys_ms.get(k, 0.0)), float(_frame_acc[k]), clampf(dt * 1.5, 0.0, 1.0)) # costo por cuadro de cada sistema (promedio móvil)
		_frame_acc[k] = 0.0
	var b := budget_ms()
	if life_ms > b:
		_over_t += dt
		_under_t = 0.0
		if _over_t > 2.0 and throttle < MAX_THROTTLE:
			throttle += 1
			_over_t = 0.0
			_budget_changed()
	elif life_ms < b * 0.5 and throttle > 0:
		_under_t += dt
		_over_t = 0.0
		if _under_t > 6.0 and throttle > 0:
			throttle -= 1
			_under_t = 0.0
			_budget_changed()
	else:
		_over_t = 0.0
		_under_t = 0.0

func _budget_changed() -> void:
	for s in systems:
		s.on_sector_changed() # cada sistema vuelve a leer su tope

## Un número que resume el estado lógico del mundo (huella + lo que digan los sistemas)
func logical_hash(world_time := -1.0) -> int:
	var t := clock.now() if world_time < 0.0 else world_time
	var h := state.fingerprint(t)
	for s in systems:
		h = WorldSeed.combine(h, s.logical_hash())
	return h

func save(profile: RefCounted) -> void:
	if profile != null and state.mode == "offline":
		profile.d["worldTime"] = clock.now()

# ───────────────────────── online ─────────────────────────
## Al entrar al mundo online: pide id, versión, semilla y tiempo al servidor (una vez) y se queda pidiendo sólo el tiempo, cada tanto, para corregir la deriva.
## Si no hay servidor, sigue con lo local (el mundo funciona igual, sólo que no coincide con el de los demás).
func join_online(online: Node) -> void:
	_online = online
	await _sync_online(true)

func _sync_online(first: bool) -> void:
	if _online == null or _syncing:
		return
	_syncing = true
	var t0 := Time.get_ticks_msec()
	var r: Dictionary = await _online.call_fn("world_join", {"p_world": "dream_city"})
	var rtt := float(Time.get_ticks_msec() - t0) / 1000.0
	_syncing = false
	if bool(r.get("ok", false)) and r.get("data") is Dictionary:
		apply_server(r["data"] as Dictionary, rtt, first)

## data: {world_id, version, seed, time, time_scale}. El tiempo llega medio RTT viejo: se le suma.
func apply_server(data: Dictionary, rtt := 0.0, first := true) -> void:
	var id := str(data.get("world_id", state.world_id))
	var ver := int(data.get("version", state.world_version))
	var sd := int(data.get("seed", state.world_seed))
	var scale := float(data.get("time_scale", 1.0))
	var t := float(data.get("time", 0.0)) + rtt * 0.5 * scale
	var changed := id != state.world_id or ver != state.world_version or sd != state.world_seed or state.mode != "online"
	state.world_id = id
	state.world_version = ver
	state.world_seed = sd
	state.mode = "online"
	state.server_synced = true
	if first or changed:
		clock.set_reference(t, scale, true) # la primera vez se alinea con el servidor
	else:
		clock.correct(t) # después, sólo correcciones suaves
	if changed and state.enabled:
		rebuild()

func stats() -> Dictionary:
	var out := {"enabled": state.enabled, "mode": state.mode, "id": state.world_id, "version": state.world_version, "seed": state.world_seed, "time": snappedf(clock.now(), 0.1),
		"profile": state.profile_name, "sector": state.player_sector, "active_sectors": sectors.active.size(), "synced": state.server_synced, "rebuilds": rebuilds,
		"life_ms": snappedf(life_ms, 0.01), "throttle": throttle, "spike_ms": snappedf(spike_ms, 0.1)}
	var sys := {}
	for s in systems:
		sys[s.system_id] = s.stats()
	out["systems"] = sys
	return out
