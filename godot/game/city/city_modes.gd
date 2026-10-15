extends RefCounted
## Modos del mundo abierto contra la IA (15/10/2026, pedidos del dueño). Funcionan sin el mundo online compartido (cada uno juega en su mundo). Detalle en
## docs/MODOS_MUNDO_ABIERTO.md.
##
##  · FUGITIVO (desde la pausa): hacé lío por la ciudad y la policía te caza (city_police.gd → desmadre, el doble de sensible y la cacería llega igual).
##    Cada escape paga (más cuanto más dura y más alto el nivel) y la próxima viene más fuerte; si te agarran se corta la racha. La mejor racha va al ranking.
##  · RECOMPENSA (evento del SERVIDOR, un solo ganador): cada tanto el servidor suelta un auto (el mismo para todos, a la misma hora: bounty_current). Al
##    soltarse, durante map_s segundos se ve en el mapa dónde está; hay que ir, encontrarlo y pegarse atrás: la barra se llena en verde mientras estés a menos
##    de STICK_R m y baja despacio si te alejás. El PRIMERO que la completa (hold_s, lo pone el servidor: 60 s) se lo lleva (bounty_claim: el servidor le da
##    el auto a la cuenta); a los demás se les va. El que huye maneja muy bien (rápido, sin errores, rehace el camino para el otro lado si lo tenés encima)
##    y «se hace el boludo» un ratito a mitad de la barra. Necesita conexión y cuenta.
## Es un servicio de la ciudad (city_services.gd): setup(race) / update(dt).

const PoliceDriver := preload("res://game/ai/police_driver.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CrashLog := preload("res://game/diag/crash_log.gd")

# fugitivo
const ESC_BASE := 1500
const ESC_LEVEL := 1000
const ESC_PER_S := 20
# recompensa
const STICK_R := 20.0 # «pegado»
const DECAY_K := 0.35 # lejos, la barra baja a esta fracción de lo que sube
const FLEE_R := 140.0 # más cerca que esto, huye para el otro lado
const POLL_IDLE := 120.0 # cada cuánto se pregunta por la recompensa (s)
const POLL_SOON := 20.0 # si falta poco o está suelta
const TRACE_MAX := 400
const SLACK_AT := [0.45, 0.78] # a qué fracción de la barra se hace el boludo (una vez cada una)
const SLACK_S := 3.5

var race
var mode := "" # "" · "fugitivo"
var stats := {"escapes": 0, "arrests": 0, "caught": 0, "lost": 0}
# fugitivo
var streak := 0
var best_streak := 0
var _esc0 := 0
var _arr0 := 0
var _chase_t := 0.0
# recompensa
var ev: Dictionary = {} # el evento del servidor: {id, car, starts, ends, hold_s, map_s, seed, won, winner, mine}
var target: Dictionary = {} # {car, drv, vid, name, ev}
var hold := 0.0
var _clock_off := 0.0 # hora del servidor − hora del teléfono
var _poll_t := 3.0
var _busy := false
var _warned := {} # id → avisos ya dados
var _map_t := 0.0
var _route_t := 0.0
var _gps_t := 0.0
var _end_t := 0.0
var _trace: Array = []
var _trace_t := 0.0
var _slack_i := 0
var _slack_t := 0.0
var _claiming := false
var _label: Label3D
var _hud: CanvasLayer
var _hud_l: Label
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat
var _banner: Label
var _banner_t := 0.0

func setup(p_race) -> void:
	race = p_race
	_build_hud()

## ¿Se pueden usar acá? (mundo abierto sin el mundo online compartido, con la policía de la región)
func available() -> bool:
	return race.get("police") != null and bool(race.police.enabled) and race.cfg.get("online", false) != true

## La recompensa necesita la cuenta conectada
func _online_ok() -> bool:
	var on = race.get("online")
	return on != null and on.has_method("is_account") and on.is_account() and race.cfg.get("testCar") == null

## Los botones de la pausa: [[texto, modo]]
func pause_buttons() -> Array:
	if not available():
		return []
	return [[Tr.t("🚨  TERMINAR FUGITIVO") if mode == "fugitivo" else Tr.t("🚨  MODO FUGITIVO"), "fugitivo"], [Tr.t("🎯  RECOMPENSA"), "caza"]]

func toggle(m: String) -> void:
	if m == "caza":
		_bounty_status()
		return
	if mode == "fugitivo":
		stop(true)
		return
	start(m)

func start(m: String) -> void:
	if not available() or race.cars.is_empty() or m != "fugitivo":
		return
	var evs = race.get("ow_events")
	if evs != null and evs.busy():
		_toast(Tr.t("Terminá la carrera antes de empezar un modo"))
		return
	var pol = race.police
	mode = "fugitivo"
	pol.fugitive = true
	pol.fugitive_level = 0
	streak = 0
	_esc0 = int(pol.stats["escapes"])
	_arr0 = int(pol.stats["arrests"])
	_chase_t = 0.0
	_big(Tr.t("🚨 MODO FUGITIVO\nHacé lío por la ciudad: la policía te va a cazar.\nCada escape paga y la próxima viene más fuerte."), 5.0)
	CrashLog.mark("modo", "empieza fugitivo")

## Termina el Fugitivo (desde la pausa)
func stop(by_player := false) -> void:
	if mode != "fugitivo":
		return
	var pol = race.get("police")
	if pol != null:
		pol.fugitive = false
		pol.fugitive_level = 0
	if by_player:
		_big(Tr.t("🚨 FIN DEL MODO FUGITIVO · racha de %d escapes") % streak, 3.5)
	CrashLog.mark("modo", "termina fugitivo")
	mode = ""

func update(dt: float) -> void:
	if _banner != null:
		_banner_t -= dt
		_banner.visible = _banner_t > 0.0
	if race.cars.is_empty():
		return
	var lines: Array = []
	if mode == "fugitivo":
		lines.append(_fugitive(dt, race.police))
	if available() and _online_ok():
		var l := _bounty(dt)
		if l != "":
			lines.append(l)
	_hud.visible = not lines.is_empty()
	_hud_l.text = "\n".join(lines)
	_bar.visible = not target.is_empty()

# ───────────────────────── fugitivo ─────────────────────────
func _fugitive(dt: float, pol) -> String:
	if str(pol.state) == "chase":
		_chase_t += dt
	if int(pol.stats["escapes"]) > _esc0:
		_esc0 = int(pol.stats["escapes"])
		streak += 1
		stats["escapes"] += 1
		var pay := escape_reward(int(pol.heat), _chase_t)
		race.profile.earn(float(pay), "fugitivo")
		race.profile.add_xp(float(pay) * 0.2)
		race.profile.save()
		pol.fugitive_level = mini(3, streak)
		_big(Tr.t("😎 ¡ESCAPASTE! + $%d\nRacha: %d · la próxima viene más fuerte") % [pay, streak], 4.0)
		_chase_t = 0.0
		if race.has_method("update_credits_hud"):
			race.update_credits_hud()
		if streak > best_streak:
			best_streak = streak
			_send_record("fugitive", "fugitivo", float(streak))
	if int(pol.stats["arrests"]) > _arr0:
		_arr0 = int(pol.stats["arrests"])
		stats["arrests"] += 1
		_big(Tr.t("🚔 TE AGARRARON · la racha quedó en %d") % streak, 4.0)
		streak = 0
		pol.fugitive_level = 0
		_chase_t = 0.0
	var st := Tr.t("en persecución · %d s") % int(_chase_t) if str(pol.state) == "chase" else Tr.t("la policía te busca: %d %%") % int(minf(pol.rage, 1.0) * 100.0)
	return Tr.t("🚨 FUGITIVO · racha %d · %s") % [streak, st]

static func escape_reward(level: int, chase_s: float) -> int:
	return int(round(float(ESC_BASE + ESC_LEVEL * clampi(level, 0, 3) + ESC_PER_S * int(clampf(chase_s, 0.0, 300.0))) / 50.0) * 50)

## Manda un récord al ranking (si el jugador participa); no traba el juego
func _send_record(board: String, id: String, value: float) -> void:
	var on = race.get("online")
	if on == null or not on.has_method("enabled") or not on.enabled() or not on.has_method("submit_record"):
		return
	var r: Dictionary = await on.submit_record(board, id, value, str(race.cfg.get("car", "")))
	if r.get("ok", false) and r.get("data") is Dictionary and bool((r["data"] as Dictionary).get("saved", false)) and int((r["data"] as Dictionary).get("rank", 0)) == 1:
		_toast(Tr.t("🌍 ¡NUEVO RÉCORD MUNDIAL!"))

# ───────────────────────── recompensa (evento del servidor) ─────────────────────────
func now_server() -> float:
	return Time.get_unix_time_from_system() + _clock_off

## Lo que pasa con el evento en este momento: «wait» (falta), «live» (suelto), «over» (se fue o ya lo ganaron), «none»
static func phase_of(e: Dictionary, now: float) -> String:
	if e.is_empty():
		return "none"
	if bool(e.get("won", false)) or now >= float(e.get("ends", 0)):
		return "over"
	return "live" if now >= float(e.get("starts", 0)) else "wait"

## La barra: sube 1 por segundo pegado, baja DECAY_K por segundo lejos (nunca de cero para abajo ni más que el máximo)
static func hold_step(h: float, dist: float, dt: float, hold_s: float) -> float:
	return minf(hold_s, h + dt) if dist < STICK_R else maxf(0.0, h - dt * DECAY_K)

## Dónde se suelta: el mismo lugar para todos (sale de la semilla del servidor): el frente de uno de los locales de Dream City
static func spawn_point(city, seed: int) -> Vector2:
	var pts: Array = []
	for p in city.pois:
		var d: Dictionary = p
		if d.has("front") and str(d.get("kind", "")) in ["fuel", "dealer", "garage"]:
			pts.append([str(d.get("id", "")), d["front"]])
	if pts.is_empty():
		return Vector2(0.0, 160.0)
	pts.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))
	return pts[absi(seed) % pts.size()][1]

func _bounty(dt: float) -> String:
	_poll_t -= dt
	var now := now_server()
	var ph := phase_of(ev, now)
	if _poll_t <= 0.0 and not _busy:
		_poll_t = POLL_SOON if (ph == "live" or (ph == "wait" and float(ev.get("starts", 0)) - now < 900.0)) else POLL_IDLE
		_poll()
	if ph == "wait":
		var left := float(ev["starts"]) - now
		var id := str(ev["id"])
		var w: int = int(_warned.get(id, 0))
		if left < float(ev.get("notice_s", 600)) and w == 0:
			_warned[id] = 1
			_big(Tr.t("🎯 RECOMPENSA en %d min\nSe suelta un %s: el primero que lo atrape se lo lleva") % [maxi(1, int(left / 60.0)), _car_name(str(ev["car"]))], 5.0)
		elif left < 60.0 and w == 1:
			_warned[id] = 2
			_toast(Tr.t("🎯 ¡La recompensa se suelta en 1 minuto!"))
		return (Tr.t("🎯 Recompensa: %s en %d:%02d") % [_car_name(str(ev["car"])), int(left) / 60, int(left) % 60]) if left < 900.0 else ""
	if ph == "live":
		if target.is_empty() and _end_t <= 0.0 and not _claiming:
			var evs = race.get("ow_events")
			if evs == null or not evs.busy():
				_release()
		if not target.is_empty():
			return _hunt(dt, now)
		return ""
	# terminado: el auto se va
	if not target.is_empty() and _end_t <= 0.0 and not _claiming:
		if bool(ev.get("won", false)) and not bool(ev.get("mine", false)):
			_big(Tr.t("😞 %s se llevó el %s") % [str(ev.get("winner", "otro piloto")), _car_name(str(ev["car"]))], 4.5)
			stats["lost"] += 1
		elif not bool(ev.get("won", false)):
			_big(Tr.t("💨 La recompensa se fue: nadie la atrapó"), 4.0)
			stats["lost"] += 1
		_end_t = 0.01
	if _end_t > 0.0:
		_end_t -= dt
		if _end_t <= 0.0:
			_drop_target()
	return ""

func _poll() -> void:
	var on = race.get("online")
	if on == null:
		return
	_busy = true
	var r: Dictionary = await on.call_fn("bounty_current", {})
	_busy = false
	if not r.get("ok", false) or not (r.get("data") is Dictionary):
		return
	apply_state(r["data"])

## Lo que contestó el servidor (bounty_current): {next, last}
func apply_state(d: Dictionary) -> void:
	var n: Variant = d.get("next")
	var last: Variant = d.get("last")
	var cur_id := int(target.get("ev", ev.get("id", -1)))
	# el que estaba persiguiendo ya lo ganó alguien (o yo): manda lo que dice «last»
	if last is Dictionary and int((last as Dictionary).get("id", -2)) == cur_id:
		ev = last
		_clock_off = float((last as Dictionary).get("now", 0)) - Time.get_unix_time_from_system()
		return
	if n is Dictionary:
		_clock_off = float((n as Dictionary).get("now", 0)) - Time.get_unix_time_from_system()
		if not target.is_empty() and int((n as Dictionary)["id"]) != cur_id:
			ev["won"] = true # el que se estaba persiguiendo terminó (y ya hay otro programado)
			return
		if ev.is_empty() or int(ev["id"]) != int((n as Dictionary)["id"]):
			hold = 0.0
			_slack_i = 0
			_trace.clear()
		ev = n
	elif not target.is_empty():
		ev["won"] = true

## Se suelta el auto: aparece en el mismo lugar para todos y se ve en el mapa durante map_s segundos
func _release() -> void:
	var vid := str(ev["car"])
	if not race.vehicles.has(vid):
		return
	var p0 := spawn_point(race.track.city, int(ev.get("seed", 0)))
	var pose: Array = race.track.nearest_road_pose(p0, 0.0)
	if pose.is_empty():
		return
	var drv := PoliceDriver.new()
	drv.mode = "parked"
	drv.grip = 1.15
	drv.pace = 1.12
	drv.errors = false
	var base: Dictionary = race.vehicles[vid]
	var car = race.add_ai_car(vid, float(pose[0]), float(pose[1]), float(pose[2]), drv, Color(str(Profile.new_car_state(vid)["paint"]["body"])),
		{"powerScale": float(base.get("powerScale", 1.0)) * 1.15, "mu": float(base.get("mu", 1.0)) * 1.12})
	if car == null:
		return
	target = {"car": car, "drv": drv, "vid": vid, "name": _car_name(vid), "ev": int(ev["id"])}
	_label = Label3D.new()
	_label.text = "🎯"
	_label.font_size = 110
	_label.pixel_size = 0.014
	_label.outline_size = 18
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 2.8, 0)
	car.visual.add_child(_label)
	hold = 0.0
	_slack_i = 0
	_trace.clear()
	_map_t = float(ev.get("map_s", 45))
	_route_t = 0.0
	_gps_t = 0.0
	_big(Tr.t("🎯 ¡SE SOLTÓ LA RECOMPENSA!\n%s · mirá el mapa: se ve %d s dónde está.\nPegate %d s y es tuyo… si llegás primero.") % [str(target["name"]), int(_map_t), int(ev.get("hold_s", 60))], 6.0)
	CrashLog.mark("recompensa", "suelta %s · ev %d" % [vid, int(ev["id"])])
	var on = race.get("online")
	if on != null and on.has_method("call_fn"):
		var r: Dictionary = await on.call_fn("bounty_join", {"p_id": int(ev["id"])})
		if r.get("ok", false) and r.get("data") is Dictionary and not bool((r["data"] as Dictionary).get("ok", true)):
			_toast(str((r["data"] as Dictionary).get("reason", "")))

func _hunt(dt: float, now: float) -> String:
	var tc = target["car"]
	if tc == null or not race.cars.has(tc):
		target = {}
		return ""
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	var q := Vector2(tc.phys.px, tc.phys.pz)
	var d := q.distance_to(p)
	var hs := float(ev.get("hold_s", 60))
	if not _claiming:
		hold = hold_step(hold, d, dt, hs)
	# recorrido para el servidor (por si hay que revisar un ganador): cada segundo, jugador, auto y barra
	_trace_t -= dt
	if _trace_t <= 0.0 and _trace.size() < TRACE_MAX:
		_trace_t = 1.0
		_trace.append([int(now) % 100000, int(p.x), int(p.y), int(q.x), int(q.y), int(hold)])
	if hold >= hs and not _claiming:
		_claim()
	# el que huye: rápido y sin errores; a mitad de la barra se hace el boludo un ratito
	var drv = target["drv"]
	if _slack_t > 0.0:
		_slack_t -= dt
		drv.pace = 0.72
		if _slack_t <= 0.0:
			drv.pace = 1.12
	elif _slack_i < SLACK_AT.size() and hold / hs >= float(SLACK_AT[_slack_i]):
		_slack_i += 1
		_slack_t = SLACK_S
	_route_t -= dt
	if not _claiming and (_route_t <= 0.0 or (drv.mode == "path" and drv.idx >= (drv.path as PackedVector2Array).size() - 2)):
		_route_t = 3.0 if d < FLEE_R else 9.0
		_flee(q, p, tc.phys.yaw)
	# el mapa: los primeros map_s segundos se ve dónde está
	var ch = _ch()
	if _map_t > 0.0:
		_map_t -= dt
		_gps_t -= dt
		if ch != null and _gps_t <= 0.0:
			_gps_t = 2.0
			if not bool(ch.get("has_dest")) or (ch.get("dest") as Vector2).distance_to(q) > 40.0:
				ch.set_dest(q, "🎯 " + str(target["name"]), bool(ch.get("has_dest")))
		if _map_t <= 0.0:
			if ch != null and ch.has_method("clear_dest"):
				ch.clear_dest()
			_toast(Tr.t("🎯 Ya no se ve en el mapa: buscalo"))
	var green := d < STICK_R
	if _label != null and is_instance_valid(_label):
		_label.modulate = Color(0.3, 1.0, 0.4) if green else Color(1.0, 0.85, 0.2)
	_bar.max_value = hs
	_bar.value = hold
	_bar_fill.bg_color = Color(0.2, 0.9, 0.35) if green else Color(0.95, 0.7, 0.15)
	var left := maxf(0.0, float(ev.get("ends", now)) - now)
	var where := (Tr.t("se ve en el mapa %d s") % int(_map_t)) if _map_t > 0.0 else ((Tr.t("%d m") % int(d)) if d < 400.0 else Tr.t("buscalo"))
	return Tr.t("🎯 RECOMPENSA · %s · %s · %d/%d s · %d:%02d") % [str(target["name"]), where, int(hold), int(hs), int(left) / 60, int(left) % 60]

func _flee(q: Vector2, p: Vector2, yaw: float) -> void:
	var pol = race.police
	var drv = target["drv"]
	var away := (q - p).normalized() if q.distance_to(p) > 1.0 else Vector2(sin(yaw), cos(yaw))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for tries in 5: # (un destino al azar puede caer en el mar o sin camino: se prueban varios, cada uno sobre la calle más cercana)
		var spread := 0.9 + 0.5 * float(tries)
		var dest := q + away.rotated(rng.randf_range(-spread, spread)) * rng.randf_range(1200.0, 3000.0)
		var pose: Array = race.track.nearest_road_pose(dest, 0.0)
		if not pose.is_empty():
			dest = Vector2(float(pose[0]), float(pose[1]))
		var r: Dictionary = pol.gps.route(q, dest) if pol.gps != null else {}
		var pts: PackedVector2Array = r.get("pts", PackedVector2Array())
		if pts.size() > 1:
			drv.path = pts
			drv.idx = 0
			drv.mode = "path"
			return

## Completó la barra: el servidor dice si llegó primero
func _claim() -> void:
	_claiming = true
	target["drv"].mode = "parked"
	_big(Tr.t("🎯 ¡BARRA COMPLETA!\nAvisándole al servidor…"), 3.0)
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("bounty_claim", {"p_id": int(ev["id"]), "p_trace": _trace, "p_name": str(race.profile.d.get("name", "Piloto"))})
	_claiming = false
	if target.is_empty():
		return
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if r.get("ok", false) and bool(d.get("ok", false)):
		stats["caught"] += 1
		ev["won"] = true
		ev["mine"] = true
		if bool(d.get("dup", false)):
			_big(Tr.t("🏆 ¡GANASTE LA RECOMPENSA!\nYa tenías el %s: + $%d") % [str(target["name"]), int(d.get("credits", 0))], 6.0)
		else:
			_big(Tr.t("🏆 ¡GANASTE LA RECOMPENSA!\nEl %s es tuyo: ya está en tu garaje") % str(target["name"]), 6.0)
		var acct = race.profile.get("acct")
		if acct != null and acct.has_method("sync"):
			acct.sync() # el servidor ya le dio el auto a la cuenta: se trae
		CrashLog.mark("recompensa", "ganada %s" % str(target["vid"]))
		_end_t = 4.0
		return
	var why := str(d.get("reason", r.get("error", Tr.t("sin conexión"))))
	_big("😞 " + why, 4.5)
	if why.begins_with("ya la ganó") or why.begins_with("la recompensa ya se fue") or why.begins_with("ya ganaste"):
		ev["won"] = true
		ev["winner"] = str(d.get("winner", ""))
		_end_t = 4.0
	else:
		hold = maxf(0.0, float(ev.get("hold_s", 60)) - 5.0) # (sin conexión o muy temprano: se reintenta en unos segundos)
		target["drv"].mode = "path"

func _drop_target() -> void:
	if target.is_empty():
		return
	var car = target["car"]
	if car != null and race.cars.has(car):
		race.remove_car(car)
	target = {}
	_label = null
	var ch = _ch()
	if ch != null and ch.has_method("clear_dest") and _map_t > 0.0:
		ch.clear_dest()
	_map_t = 0.0

## Desde la pausa: cómo está la recompensa
func _bounty_status() -> void:
	if not _online_ok():
		_toast(Tr.t("La recompensa necesita conexión y tu cuenta"))
		return
	var now := now_server()
	match phase_of(ev, now):
		"wait":
			var left := float(ev["starts"]) - now
			_big(Tr.t("🎯 Próxima recompensa: %s\nse suelta en %d h %02d min · pegado %d s") % [_car_name(str(ev["car"])), int(left) / 3600, (int(left) % 3600) / 60, int(ev.get("hold_s", 60))], 4.0)
		"live":
			_toast(Tr.t("🎯 Está suelta: ¡buscala!") if not target.is_empty() else Tr.t("🎯 Está suelta: terminá lo que estás haciendo y aparece"))
		_:
			_toast(Tr.t("🎯 No hay recompensa programada por ahora"))
			_poll_t = 0.0

## Los autos se rehicieron (taller de prueba, cambio de auto): el que andaba suelto ya no está en la lista
func forget() -> void:
	target = {}
	_label = null

static func _car_name(vid: String) -> String:
	var c: Dictionary = CarBuild.catalog()["cars"].get(vid, {})
	return ("%s %s" % [str(c.get("brand", "")), str(c.get("model", vid))]).strip_edges() if not c.is_empty() else vid

# ───────────────────────── HUD ─────────────────────────
func _ch():
	return race.race_hud.city_hud if race.race_hud != null else null

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 3
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -330.0
	box.offset_right = 330.0
	box.offset_top = 176.0 # (debajo del velocímetro y del cartel de la policía)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_hud_l = Label.new()
	_hud_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_l.add_theme_font_size_override("font_size", 20)
	_hud_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_hud_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hud_l.add_theme_constant_override("outline_size", 6)
	_hud_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hud_l)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 14)
	_bar.show_percentage = false
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = Color(0.95, 0.7, 0.15)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	_bar.visible = false
	box.add_child(_bar)
	_hud.visible = false
	race.add_child(_hud)
	var lay := CanvasLayer.new() # el cartel grande va aparte
	lay.layer = 3
	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -420.0
	_banner.offset_right = 420.0
	_banner.offset_top = -150.0
	_banner.offset_bottom = 10.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	lay.add_child(_banner)
	race.add_child(lay)

func _big(s: String, secs: float) -> void:
	_banner.text = s
	_banner_t = secs
	_banner.visible = true

func _toast(s: String) -> void:
	if race.race_hud != null:
		race.race_hud.toast(s)
