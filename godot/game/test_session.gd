extends "res://game/drift_session.gd"
## Sesión del MODO DE PRUEBA (20/10/2026, pedido del dueño): la Drift Plaza mejorada (DriftTrack.new(true)) para probar el auto, el reglaje y las ayudas antes de salir al mundo abierto.
##  · DRIFT: por puntos (como la Drift Plaza) o libre (sólo se ve el ángulo); sin tiempo límite y sin cuenta regresiva larga.
##  · CARRERA: contrarreloj por un circuito (el camino de tierra de atrás de la ciudad o la vuelta entre los edificios): puertas en orden, tiempo de cada vuelta y la mejor.
##  · NAFTA: el tanque baja con la velocidad; se carga frenando adentro del cuadrado verde. Sin nafta el auto no acelera (para probar el consumo).
## No suma nada a la carrera ni al garaje: es una prueba (cfg testCar).

signal guide_event(id: String) # el guía por voz (game/audio/guide_voice.gd) reacciona a lo que hace el jugador

const PER_M := 1.0 / 7000.0 # fracción del tanque por metro: a 100 km/h dura unos 4 minutos (se nota el consumo en una prueba corta)
const REFUEL_PER_S := 0.25 # cargar el tanque entero lleva 4 s
const REFUEL_SPEED := 2.5 # m/s: hay que estar casi parado adentro del cuadrado verde
const LOW_TANK := 0.2
const HINT_DRIFT_S := 25.0 # segundos de manejo sin ningún derrape para que la guía sugiera probar uno

var mode := "drift" # drift | race
var score_on := true # drift por puntos (false = libre)
var loop_name := "dirt"
var gates: Array = [] # Vector3(x, z, radio)
var gate_i := 1
var lap := 1
var lap_t := 0.0
var best_lap := 0.0
var laps_done: Array = []
var tank := 1.0
var refueling := false
var seen := {} # lo que ya se avisó (no se repite)
var guided := false # la guía (subtítulos y voz) está prendida: ella cuenta lo de la nafta, la pantalla no repite los carteles

func _init(p_track, cfg: Dictionary, n_cars: int) -> void:
	super._init(p_track, cfg, n_cars)
	var ts: Dictionary = cfg.get("testSetup", {})
	mode = str(ts.get("mode", "drift"))
	score_on = str(ts.get("score", "points")) == "points" and mode == "drift"
	loop_name = str(ts.get("loop", "dirt"))
	limit = 1.0e9
	cd = 3.6 if mode == "race" else 0.5
	last_beep = 4
	tank = clampf(float(ts.get("tank", 1.0)), 0.0, 1.0)
	if p_track != null and p_track.get("gates") is Dictionary:
		gates = ((p_track.gates as Dictionary).get(loop_name, []) as Array).duplicate()
	if mode == "race" and p_track != null:
		p_track.set_loop(loop_name)
		p_track.set_next_gate(gates[gate_i % gates.size()] if not gates.is_empty() else null)
	elif p_track != null and p_track.has_method("set_loop"):
		p_track.set_loop("")

func remaining() -> float:
	return limit # (no hay tiempo límite)

## El acelerador no responde sin nafta ni mientras se carga
func blocks_throttle() -> bool:
	return tank <= 0.0005 or refueling

func update(dt: float, cars: Array) -> void:
	if not seen.has("start"): # (la primera vez que corre: la carga ya terminó)
		seen["start"] = true
		guide_event.emit("race_start" if mode == "race" else "test_welcome")
	super.update(dt, cars)
	if state != "run" or cars.is_empty():
		return
	var ph = cars[0].phys
	if not score_on:
		cur = 0.0
		total = 0.0
		mult = 1
		combo = 0.0
	_fuel(dt, ph)
	if mode == "race":
		_race(dt, ph)
	else:
		_notice(ph)
		if time > HINT_DRIFT_S and not seen.has("test_drift_first"): # pasaron unos segundos sin derrapar: la guía propone probarlo
			_say("test_try_drift")

func _say(id: String) -> void:
	if not seen.has(id):
		seen[id] = true
		guide_event.emit(id)

## Avisos de lo que hay en el mapa (una sola vez cada uno)
func _notice(ph) -> void:
	if drifting and mode == "drift":
		_say("test_drift_first")
	if track != null and ph.px < -300.0 and ph.pz > 100.0:
		_say("test_bumps")
	if track != null and ph.px > 300.0 and ph.pz > 100.0:
		_say("test_fuel_corner")

func _fuel(dt: float, ph) -> void:
	var sp := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	var in_zone: bool = track != null and track.has_method("in_fuel_zone") and track.in_fuel_zone(ph.px, ph.pz)
	if in_zone and sp < REFUEL_SPEED and tank < 0.999:
		if not refueling:
			refueling = true
			messages.append([tr("⛽ Cargando nafta…"), "up"])
			guide_event.emit("test_refuel")
		tank = minf(1.0, tank + dt * REFUEL_PER_S)
		if tank >= 0.999:
			refueling = false
			messages.append([tr("⛽ Tanque lleno"), "up"])
			guide_event.emit("test_fuel_full")
		return
	if refueling and (not in_zone or sp > REFUEL_SPEED * 2.0):
		refueling = false
	tank = maxf(0.0, tank - sp * dt * PER_M)
	if tank < LOW_TANK and tank > 0.0005 and not seen.has("low"):
		seen["low"] = true
		if not guided:
			messages.append([tr("⛽ Poca nafta: frená en el cuadrado verde para cargar"), "down"])
		guide_event.emit("test_fuel_low")
	elif tank <= 0.0005 and not seen.has("empty"):
		seen["empty"] = true
		if not guided:
			messages.append([tr("⛽ Sin nafta: el auto no acelera. Empujalo al cuadrado verde o reiniciá"), "down"])
		guide_event.emit("test_fuel_empty")
	if tank > LOW_TANK + 0.05:
		seen.erase("low")
		seen.erase("empty")

func _race(dt: float, ph) -> void:
	lap_t += dt
	if gates.is_empty():
		return
	var g: Vector3 = gates[gate_i % gates.size()]
	if Vector2(ph.px - g.x, ph.pz - g.y).length() > g.z + 1.5:
		return
	if gate_i % gates.size() == 0:
		# la puerta 0 es la meta: vuelta completa
		var secs := lap_t
		laps_done.append(secs)
		var is_best := best_lap <= 0.0 or secs < best_lap
		if is_best:
			best_lap = secs
		messages.append([tr("🏁 Vuelta %d · %s%s") % [lap, fmt(secs), tr("  ¡mejor!") if is_best and laps_done.size() > 1 else ""], "up"])
		guide_event.emit("test_lap_done" if laps_done.size() > 1 else "test_lap_first")
		lap += 1
		lap_t = 0.0
		gate_i = 1
	else:
		gate_i += 1
	var nxt: Variant = gates[gate_i % gates.size()]
	if track != null:
		track.set_next_gate(nxt)

## Textos de la pantalla: [cronómetro, línea de arriba, línea grande del medio]
func hud_lines() -> Array:
	var fuel_txt := "⛽ %d %%" % roundi(tank * 100.0)
	if mode == "race":
		var g := gate_i % maxi(gates.size(), 1)
		var left := (gates.size() - g) % maxi(gates.size(), 1) if gates.size() > 0 else 0
		var best := ("  ·  " + tr("MEJOR %s") % fmt(best_lap)) if best_lap > 0.0 else ""
		return [fmt(lap_t), "%s %d  ·  %s%s" % [tr("VUELTA"), lap, fuel_txt, best], ("%s %d/%d" % [tr("PUERTA"), g if g > 0 else gates.size(), gates.size()]) if state == "run" else ""]
	if score_on:
		return [fmt(time), "%s  ·  %s %s" % [fuel_txt, tr("TOTAL"), _pts_txt(total)], ("%s  ·  %d°" % [_pts_txt(cur), int(angle_deg)]) if (cur > 0.0 and state == "run") else ""]
	return [fmt(time), "%s  ·  %s" % [fuel_txt, tr("DRIFT LIBRE")], ("%d°" % int(angle_deg)) if (drifting and state == "run") else ""]

func show_mult() -> bool:
	return mode == "drift" and score_on

func fmt(secs: float) -> String:
	var m := int(secs / 60.0)
	var s := secs - float(m) * 60.0
	return "%d:%05.2f" % [m, s]

func _pts_txt(v: float) -> String:
	var t := str(int(roundf(v)))
	var out := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 3 == 0:
			out += "."
		out += t[i]
	return out
