extends RefCounted
## EVENTOS DEL MUNDO (15/10/2026, pedido del dueño: «mientras no haya tiempo real, el online es de eventos de clasificación: cada uno juega en su mapa contra la
## IA y sus registros se suben al servidor para competir; no son modos a elegir en la pausa: el servidor los manda»). Ver docs/MODOS_MUNDO_ABIERTO.md.
##
## El servidor (migración 20261020000000_world_events.sql) es el gestor: programa eventos al azar y a hora fija, cuenta intentos, valida tiempos, da los premios
## y publica los ganadores. Este módulo pregunta qué hay (events_current), los muestra (cartel, renglón arriba, mapa) y juega cada uno en el mundo de este celular:
##  · bounty  CAZARRECOMPENSAS: a la hora del evento aparecen N autos (el mismo lugar para todos, sale de la semilla); se ven map_s s en el mapa; pegado a menos
##            de STICK_R m la barra de ese auto se llena (verde); el primero que la completa se lo lleva (event_finish). Si la presa pasa un control policial y estás
##            cerca, la policía te persigue a vos también.
##  · escape  FUGA: cualquier persecución de la policía cuenta (por desmadre o por pasar un control): aguantá chase_s segundos y escapá.
##  · reach   CONTRARRELOJ: frená en el círculo de la salida de Dream City y llegá a la ciudad marcada antes del tiempo (intentos limitados).
##  · record  CARRERA DE LA SEMANA: una de las carreras del mundo abierto (sale de la semilla); cada vez que la terminás, tu tiempo va a la tabla; al cerrar,
##            premios a los 3 primeros.
## Además, siempre: cada escape de la policía paga (más cuanto más dura y más alto el nivel) y la mejor racha de escapes va al ranking.
## Sin conexión o sin cuenta no hay eventos (el resto del juego anda igual). Es un servicio de la ciudad (city_services.gd): setup(race) / update(dt).

const PoliceDriver := preload("res://game/ai/police_driver.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const ClassRecords := preload("res://game/online/class_records.gd")
const Profile := preload("res://game/data/profile.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CrashLog := preload("res://game/diag/crash_log.gd")
const Cosmetics := preload("res://game/data/cosmetics.gd")

# escapes de la policía (siempre)
const ESC_BASE := 1500
const ESC_LEVEL := 1000
const ESC_PER_S := 20
# cacería
const STICK_R := 20.0
const DECAY_K := 0.35
const FLEE_R := 140.0
const TRACE_MAX := 400
const SLACK_AT := [0.45, 0.78] # a qué fracción de la barra el que huye se hace el boludo (una vez cada una)
const SLACK_S := 3.5
const CP_TRIGGER_R := 60.0 # la presa pasa a menos de esto de un control…
const CP_ME_R := 450.0 # …y vos estás a menos de esto: la policía te persigue
# contrarreloj
const REACH_MIN := 10000.0 # la ciudad marcada está entre estas distancias de Dream City (la más cercana está a 14 km)
const REACH_MAX := 30000.0
const REACH_ARRIVE := 250.0
const START_R := 12.0
# servidor
const POLL_IDLE := 90.0
const POLL_SOON := 15.0

var race
var stats := {"escapes": 0, "arrests": 0, "caught": 0, "lost": 0, "won": 0}
var streak := 0
var best_streak := 0
var _esc0 := -1
var _arr0 := -1
var _chase_t := 0.0
var _was_chase := false

var events: Array = [] # lo último que dijo el servidor
var _clock_off := 0.0
var _poll_t := 2.0
var _busy := false
var _seen_win := {} # ganadores ya anunciados
var _announced := {} # id → 1 anunciado, 2 avisado al minuto, 3 suelto
var _first_poll := true
# cacería: un objetivo por auto suelto
var targets: Array = [] # [{ev, slot, car, drv, vid, name, hold, run, trace, slack_i, slack_t, label, route_t, done, cp_t}]
var _map_t := 0.0
var _gps_t := 0.0
# fuga
var _esc_runs := {} # evento de fuga → intento (pueden correr varias a la vez: una persecución cuenta para todas)
var _esc_start := 0.0
var _esc_wait := false
var _esc_end_pending := 0 # la persecución terminó mientras se pedían los intentos: 1 escapó, -1 lo agarraron

var _drift: Dictionary = {} # desafío de drift en curso: {ev, run, t, base}
var _drift_rearm := true # hay que salir de la plaza para empezar otro intento
var _drift_busy := false
# contrarreloj
var _reach: Dictionary = {} # {ev, town, pos, start, yaw, limit, run, t, marker}
var _reach_stop := 0.0
# carrera de la semana
var weekly: Dictionary = {} # {ev, ow_id, run}
var _hud: CanvasLayer
var _hud_l: Label
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat
var _banner: Label
var _banner_t := 0.0
var _towns: Array = []

func setup(p_race) -> void:
	race = p_race
	_build_hud()
	var rg = race.track.get("region") if race.track != null else null
	if rg != null:
		for n in rg.nodes:
			if int(n[3]) in [3, 4]:
				var q := Vector2(float(n[1]), float(n[2]))
				if q.length() >= REACH_MIN and q.length() <= REACH_MAX:
					_towns.append([str(n[0]), q, str(n[4]) if (n as Array).size() > 4 else ""])
	_towns.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))

## ¿Hay eventos acá? (mundo abierto sin el mundo compartido, con la policía de la región, con cuenta y conexión)
func available() -> bool:
	return race.get("police") != null and bool(race.police.enabled) and race.cfg.get("online", false) != true

func _online_ok() -> bool:
	var on = race.get("online")
	return on != null and on.has_method("is_account") and on.is_account() and race.cfg.get("testCar") == null

## La pausa: un solo botón con los eventos del momento
func pause_buttons() -> Array:
	return [[Tr.t("📅  EVENTOS EN VIVO"), "eventos"], [Tr.t("❓  AYUDA"), "ayuda"]] if available() else []

func toggle(m: String) -> void:
	if m == "ayuda":
		var g = race.get("goal")
		_big(g.help_text() if g != null else "", 9.0)
		return
	_show_board()

func now_server() -> float:
	return Time.get_unix_time_from_system() + _clock_off

func update(dt: float) -> void:
	if _banner != null:
		_banner_t -= dt
		_banner.visible = _banner_t > 0.0
	if race.cars.is_empty() or not available():
		_hud.visible = false
		return
	var lines: Array = []
	_escapes(dt)
	if _online_ok():
		_poll_t -= dt
		if _poll_t <= 0.0 and not _busy:
			_poll_t = POLL_SOON if _soon() else POLL_IDLE
			_poll()
		var now := now_server()
		for e in events:
			var l := _event_tick(e, dt, now)
			if l != "":
				lines.append(l)
	_hud.visible = not lines.is_empty()
	_hud_l.text = "\n".join(lines.slice(0, 3))
	_bar.visible = false
	for tg in targets:
		if not bool(tg["done"]):
			_bar.visible = true

# ───────────────────────── escapes (siempre) ─────────────────────────
func _escapes(dt: float) -> void:
	var pol = race.police
	if _esc0 < 0:
		_esc0 = int(pol.stats["escapes"])
		_arr0 = int(pol.stats["arrests"])
	var chasing := str(pol.state) == "chase"
	if chasing:
		_chase_t += dt
	if int(pol.stats["escapes"]) > _esc0:
		_esc0 = int(pol.stats["escapes"])
		streak += 1
		stats["escapes"] += 1
		var pay := escape_reward(int(pol.heat), _chase_t)
		race.profile.earn(float(pay), "fuga")
		race.profile.add_xp(float(pay) * 0.2)
		race.profile.save()
		_big(Tr.t("😎 ¡TE ESCAPASTE! + $%d · racha %d") % [pay, streak], 3.5)
		if race.has_method("update_credits_hud"):
			race.update_credits_hud()
		if streak > best_streak:
			best_streak = streak
			_send_record("fugitive", "fugitivo", float(streak))
		_escape_event_end(true)
		_chase_t = 0.0
	if int(pol.stats["arrests"]) > _arr0:
		_arr0 = int(pol.stats["arrests"])
		stats["arrests"] += 1
		streak = 0
		_escape_event_end(false)
		_chase_t = 0.0
	if chasing and not _was_chase:
		_escape_event_begin()
	_was_chase = chasing

static func escape_reward(level: int, chase_s: float) -> int:
	return int(round(float(ESC_BASE + ESC_LEVEL * clampi(level, 0, 3) + ESC_PER_S * int(clampf(chase_s, 0.0, 300.0))) / 50.0) * 50)

func _send_record(board: String, id: String, value: float) -> void:
	var on = race.get("online")
	if on == null or not on.has_method("enabled") or not on.enabled() or not on.has_method("submit_record"):
		return
	var r: Dictionary
	if on.has_method("submit_class"): # récords por clase (fase 3)
		var car := str(race.cfg.get("car", ""))
		var e := ClassRecords.meta(race.vehicles.get(car, {}), race.cfg.get("state", {}) if race.cfg.get("state") is Dictionary else {}, str(race.cfg.get("sim", "")))
		e.merge({"board": board, "track": id, "value": value, "car": car})
		r = await on.submit_class(e)
	else:
		r = await on.submit_record(board, id, value, str(race.cfg.get("car", "")))
	if r.get("ok", false) and r.get("data") is Dictionary and bool((r["data"] as Dictionary).get("saved", false)) and int((r["data"] as Dictionary).get("rank", 0)) == 1:
		_toast(Tr.t("🌍 ¡NUEVO RÉCORD MUNDIAL!"))

# ───────────────────────── servidor ─────────────────────────
func _soon() -> bool:
	var now := now_server()
	for e in events:
		if float(e.get("starts", 0)) - now < 300.0 and float(e.get("ends", 0)) > now:
			return true
	return false

func _poll() -> void:
	var on = race.get("online")
	if on == null:
		return
	_busy = true
	var r: Dictionary = await on.call_fn("events_current", {})
	_busy = false
	if r.get("ok", false) and r.get("data") is Dictionary:
		apply_state(r["data"])

## Lo que contestó el servidor: {now, events: [...], winners: [...]}
func apply_state(d: Dictionary) -> void:
	_clock_off = float(d.get("now", Time.get_unix_time_from_system())) - Time.get_unix_time_from_system()
	events = (d.get("events", []) as Array).duplicate() if d.get("events") is Array else []
	# ganadores nuevos: se anuncian (la primera vez sólo se recuerdan)
	for w in (d.get("winners", []) as Array):
		var k := "%s|%s|%s" % [str(w.get("event", "")), str(w.get("name", "")), str(w.get("at", ""))]
		if not _seen_win.has(k):
			_seen_win[k] = true
			if not _first_poll and float(w.get("at", 0)) > now_server() - 300.0:
				var car := str(w.get("car", ""))
				_toast(Tr.t("📢 %s ganó «%s»%s") % [str(w.get("name", "")), Tr.t(str(w.get("event", ""))), (" · " + _car_name(car)) if car != "" and car != "<null>" else ""])
	_first_poll = false
	# la carrera de la semana: cuál de las carreras del mundo abierto es
	weekly = {}
	for e in events:
		if str(e.get("kind", "")) == "record" and float(e.get("starts", 0)) <= now_server():
			var evs = race.get("ow_events")
			if evs != null and not (evs.events as Array).is_empty():
				var ids: Array = []
				for oe in evs.events:
					ids.append(str(oe["id"]))
				ids.sort()
				weekly = {"ev": int(e["id"]), "ow_id": str(ids[absi(int(e.get("seed", 0))) % ids.size()]), "run": -1, "best": e.get("best"), "title": str(e.get("title", ""))}

static func _find(evs: Array, id: int) -> Dictionary:
	for e in evs:
		if int(e.get("id", -1)) == id:
			return e
	return {}

## Un evento, cada cuadro: avisos, lo que corresponde según el tipo y el renglón del HUD
func _event_tick(e: Dictionary, dt: float, now: float) -> String:
	var id := int(e["id"])
	var st := float(e.get("starts", 0))
	var en := float(e.get("ends", 0))
	var kind := str(e.get("kind", ""))
	var a: int = int(_announced.get(id, 0))
	if now < st:
		if a == 0 and st - now < 1800.0:
			_announced[id] = 1
			_big(Tr.t("📅 %s\nEmpieza en %d min · %s") % [Tr.t(str(e["title"])), maxi(1, int((st - now) / 60.0)), reward_text(e)], 5.0)
		elif a == 1 and st - now < 60.0:
			_announced[id] = 2
			_toast(Tr.t("📅 «%s» empieza en 1 minuto") % Tr.t(str(e["title"])))
		return (Tr.t("📅 %s en %d:%02d") % [Tr.t(str(e["title"])), int(st - now) / 60, int(st - now) % 60]) if st - now < 1200.0 else ""
	if now >= en:
		if kind == "bounty":
			_bounty_end(id, Tr.t("💨 Se fueron los autos de la cacería"))
		elif kind == "drift" and not _drift.is_empty() and int(_drift["ev"]) == id:
			_drift_finish(e) # se termina la sesión que estaba en juego (el servidor da 2 min de gracia)
		return ""
	if a < 3 and kind != "bounty":
		_announced[id] = 3
		_big(Tr.t("📅 EN VIVO: %s\n%s\n%s") % [Tr.t(str(e["title"])), Tr.t(str(e.get("descr", ""))), reward_text(e)], 6.0)
	match kind:
		"bounty":
			return _bounty_tick(e, dt, now)
		"escape":
			return _escape_line(e, now)
		"reach":
			return _reach_tick(e, dt, now)
		"record":
			return _record_line(e, now)
		"drift":
			return _drift_tick(e, dt, now)
	return ""

static func reward_text(e: Dictionary) -> String:
	var r: Dictionary = e.get("reward", {})
	if r.has("top"):
		var tp: Array = r["top"]
		var parts: Array = []
		for k in mini(3, tp.size()):
			parts.append("%dº %s" % [k + 1, prize_text(tp[k])])
		return Tr.t("premios: %s") % " · ".join(parts)
	if r.has("car") and not (r["car"] is String):
		return Tr.t("premio: el auto que atrapes")
	var t := prize_text(r)
	return (Tr.t("premio: %s") % t) if t != "" else ""

## Un premio: un número (créditos) o {credits, voucher, car, rent+days, skin, tires}
static func prize_text(p: Variant) -> String:
	if p is int or p is float:
		return "$%d" % int(p)
	if not (p is Dictionary):
		return ""
	var r: Dictionary = p
	var out: Array = []
	if r.get("car") is String:
		out.append(_car_name(str(r["car"])))
	if r.has("rent"):
		out.append(Tr.t("el %s por %d días") % [_car_name(str(r["rent"])), int(r.get("days", 1))])
	if r.has("credits"):
		out.append("$%d" % int(r["credits"]))
	if r.has("voucher"):
		out.append(Tr.t("$%d de vale de taller") % int(r["voucher"]))
	if r.has("skin"):
		out.append(Tr.t("el diseño %s") % _skin_name(str(r["skin"])))
	if r.has("tires"):
		out.append(Tr.t("gomas %s para todos tus autos") % str(CarBuild.tire(str(r["tires"])).get("n", r["tires"])))
	return " + ".join(out)

static func _skin_name(id: String) -> String:
	var it: Dictionary = Cosmetics.item(id)
	return str(it.get("n", id)) if not it.is_empty() else id

# ───────────────────────── cacería ─────────────────────────
## Dónde se suelta cada auto: el mismo lugar para todos (semilla del servidor + número de auto): el frente de uno de los locales de Dream City
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

static func hold_step(h: float, dist: float, dt: float, hold_s: float) -> float:
	return minf(hold_s, h + dt) if dist < STICK_R else maxf(0.0, h - dt * DECAY_K)

static func phase_of(e: Dictionary, now: float) -> String:
	if e.is_empty():
		return "none"
	if now >= float(e.get("ends", 0)):
		return "over"
	return "live" if now >= float(e.get("starts", 0)) else "wait"

func _bounty_tick(e: Dictionary, dt: float, now: float) -> String:
	var id := int(e["id"])
	var cars: Array = (e.get("params", {}) as Dictionary).get("cars", [])
	var won_slots := {}
	for w in (e.get("winners", []) as Array):
		won_slots[int(w.get("slot", 0))] = str(w.get("name", ""))
	# los autos que ya atrapó alguien se van
	for tg in targets.duplicate():
		if int(tg["ev"]) == id and won_slots.has(int(tg["slot"])) and not bool(tg["done"]):
			if not bool(tg.get("mine", false)):
				_big(Tr.t("😞 %s atrapó el %s") % [str(won_slots[int(tg["slot"])]), str(tg["name"])], 4.0)
			_drop(tg)
	var mine := bool(e.get("done", false))
	if int(_announced.get(id, 0)) < 3:
		_announced[id] = 3
		if not mine and _free_to_play():
			var n := 0
			for s in cars.size():
				if not won_slots.has(s) and _release(e, s):
					n += 1
			if n > 0:
				_map_t = float((e.get("params", {}) as Dictionary).get("map_s", 45))
				_gps_t = 0.0
				_big(Tr.t("🎯 ¡CAZARRECOMPENSAS!\n%d autos sueltos: mirá el mapa (%d s).\nEl primero que se pegue %d s a uno se lo lleva.") % [n, int(_map_t), int((e.get("params", {}) as Dictionary).get("hold_s", 60))], 6.0)
		else:
			_announced[id] = 2 # (estaba en una carrera: aparecen cuando termine)
	var line := ""
	var best_d := 1e9
	var best: Dictionary = {}
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	for tg in targets:
		if int(tg["ev"]) != id or bool(tg["done"]):
			continue
		var c = tg["car"]
		if c == null or not race.cars.has(c):
			continue
		var q := Vector2(c.phys.px, c.phys.pz)
		var d := q.distance_to(p)
		_hunt_one(e, tg, dt, now, p, q, d)
		if d < best_d:
			best_d = d
			best = tg
	# el mapa: los primeros map_s segundos se ve dónde está el más cercano
	var ch = _ch()
	if _map_t > 0.0 and not best.is_empty():
		_map_t -= dt
		_gps_t -= dt
		var bq := Vector2(best["car"].phys.px, best["car"].phys.pz)
		if ch != null and _gps_t <= 0.0:
			_gps_t = 2.0
			if not bool(ch.get("has_dest")) or (ch.get("dest") as Vector2).distance_to(bq) > 40.0:
				ch.set_dest(bq, "🎯 " + str(best["name"]), bool(ch.get("has_dest")))
		if _map_t <= 0.0:
			if ch != null and ch.has_method("clear_dest"):
				ch.clear_dest()
			_toast(Tr.t("🎯 Ya no se ven en el mapa: buscalos"))
	if not best.is_empty():
		var hs := float((e.get("params", {}) as Dictionary).get("hold_s", 60))
		var green := best_d < STICK_R
		_bar.max_value = hs
		_bar.value = float(best["hold"])
		_bar_fill.bg_color = Color(0.2, 0.9, 0.35) if green else Color(0.95, 0.7, 0.15)
		var where := (Tr.t("en el mapa %d s") % int(_map_t)) if _map_t > 0.0 else ((Tr.t("%d m") % int(best_d)) if best_d < 500.0 else Tr.t("buscalos"))
		var left := maxf(0.0, float(e.get("ends", now)) - now)
		line = Tr.t("🎯 %s · %s · %d/%d s · %d:%02d") % [str(best["name"]), where, int(best["hold"]), int(hs), int(left) / 60, int(left) % 60]
	elif int(_announced.get(id, 0)) == 2 and _free_to_play() and not mine:
		_announced[id] = 0 # terminó la carrera: ahora sí se sueltan
	return line

func _free_to_play() -> bool:
	var evs = race.get("ow_events")
	return (evs == null or not evs.busy()) and _reach.get("run", -1) == -1

func _release(e: Dictionary, slot: int) -> bool:
	var cars: Array = (e.get("params", {}) as Dictionary).get("cars", [])
	var vid := str(cars[slot])
	if not race.vehicles.has(vid):
		return false
	var p0 := spawn_point(race.track.city, int(e.get("seed", 0)) + slot * 7)
	var pose: Array = race.track.nearest_road_pose(p0, 0.0)
	if pose.is_empty():
		return false
	var drv := PoliceDriver.new()
	drv.mode = "parked"
	drv.grip = 1.15
	drv.pace = 1.12
	drv.errors = false
	var base: Dictionary = race.vehicles[vid]
	var car = race.add_ai_car(vid, float(pose[0]), float(pose[1]), float(pose[2]), drv, Color(str(Profile.new_car_state(vid)["paint"]["body"])),
		{"powerScale": float(base.get("powerScale", 1.0)) * 1.15, "mu": float(base.get("mu", 1.0)) * 1.12})
	if car == null:
		return false
	var lb := Label3D.new()
	lb.text = "🎯"
	lb.font_size = 110
	lb.pixel_size = 0.014
	lb.outline_size = 18
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = Vector3(0, 2.8, 0)
	car.visual.add_child(lb)
	targets.append({"ev": int(e["id"]), "slot": slot, "car": car, "drv": drv, "vid": vid, "name": _car_name(vid), "hold": 0.0, "run": -1, "trace": [], "trace_t": 0.0,
		"slack_i": 0, "slack_t": 0.0, "label": lb, "route_t": 0.0, "done": false, "claiming": false, "cp_t": 0.0, "starting": false})
	CrashLog.mark("evento", "cacería: suelto %s (slot %d)" % [vid, slot])
	return true

func _hunt_one(e: Dictionary, tg: Dictionary, dt: float, now: float, p: Vector2, q: Vector2, d: float) -> void:
	var hs := float((e.get("params", {}) as Dictionary).get("hold_s", 60))
	# el intento se anota en el servidor cuando te acercás (gasta un intento sólo si de verdad vas por él)
	if int(tg["run"]) < 0 and d < 300.0 and not bool(tg["starting"]):
		_start_run(tg, int(e["id"]), int(tg["slot"]))
	if not bool(tg["claiming"]):
		tg["hold"] = hold_step(float(tg["hold"]), d, dt, hs) if int(tg["run"]) >= 0 else 0.0
	tg["trace_t"] = float(tg["trace_t"]) - dt
	if float(tg["trace_t"]) <= 0.0 and (tg["trace"] as Array).size() < TRACE_MAX and int(tg["run"]) >= 0:
		tg["trace_t"] = 1.0
		(tg["trace"] as Array).append([int(now) % 100000, int(p.x), int(p.y), int(q.x), int(q.y), int(float(tg["hold"]))])
	if float(tg["hold"]) >= hs and not bool(tg["claiming"]):
		_claim(tg)
	var drv = tg["drv"]
	if float(tg["slack_t"]) > 0.0:
		tg["slack_t"] = float(tg["slack_t"]) - dt
		drv.pace = 0.72
		if float(tg["slack_t"]) <= 0.0:
			drv.pace = 1.12
	elif int(tg["slack_i"]) < SLACK_AT.size() and float(tg["hold"]) / hs >= float(SLACK_AT[int(tg["slack_i"])]):
		tg["slack_i"] = int(tg["slack_i"]) + 1
		tg["slack_t"] = SLACK_S
	tg["route_t"] = float(tg["route_t"]) - dt
	if not bool(tg["claiming"]) and (float(tg["route_t"]) <= 0.0 or (drv.mode == "path" and drv.idx >= (drv.path as PackedVector2Array).size() - 2)):
		tg["route_t"] = 3.0 if d < FLEE_R else 9.0
		_flee(drv, q, p, tg["car"].phys.yaw)
	var green := d < STICK_R
	var lb: Variant = tg["label"]
	if lb != null and is_instance_valid(lb):
		(lb as Label3D).modulate = Color(0.3, 1.0, 0.4) if green else Color(1.0, 0.85, 0.2)
	# si la presa pasa un control policial y vos venís atrás, la policía te persigue a vos
	tg["cp_t"] = float(tg["cp_t"]) - dt
	if float(tg["cp_t"]) <= 0.0 and d < CP_ME_R:
		tg["cp_t"] = 0.5
		var pol = race.police
		if str(pol.state) != "chase" and pol.has_method("checkpoint_near") and pol.checkpoint_near(q, CP_TRIGGER_R) >= 0:
			pol.event_chase(race.cars[0].phys, clampi(int(pol.heat) + 1, 0, 3))
			_toast(Tr.t("🚨 Tu presa pasó un control: ¡la policía te persigue a vos también!"))

func _start_run(tg: Dictionary, ev_id: int, slot: int) -> void:
	tg["starting"] = true
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_start", {"p_id": ev_id, "p_slot": slot})
	tg["starting"] = false
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if r.get("ok", false) and bool(d.get("ok", false)):
		tg["run"] = int(d["run"])
	elif d.has("reason"):
		_toast("🎯 " + str(d["reason"]))
		if str(d["reason"]).begins_with("ese auto ya") or str(d["reason"]).begins_with("ya ganaste"):
			_drop(tg)

func _flee(drv, q: Vector2, p: Vector2, yaw: float) -> void:
	var pol = race.police
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

func _claim(tg: Dictionary) -> void:
	tg["claiming"] = true
	tg["drv"].mode = "parked"
	_big(Tr.t("🎯 ¡BARRA COMPLETA!\nAvisándole al servidor…"), 3.0)
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_finish", {"p_run": int(tg["run"]), "p_ok": true, "p_value": float(tg["hold"]), "p_trace": tg["trace"], "p_name": str(race.profile.d.get("name", "Piloto"))})
	tg["claiming"] = false
	if bool(tg["done"]):
		return
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if r.get("ok", false) and bool(d.get("won", false)):
		stats["caught"] += 1
		stats["won"] += 1
		tg["mine"] = true
		_after_ok("bounty")
		var rw: Dictionary = d.get("reward", {})
		if bool(rw.get("dup", false)):
			_big(Tr.t("🏆 ¡LO ATRAPASTE!\nYa tenías el %s: + $%d") % [str(tg["name"]), int(rw.get("credits", 0))], 6.0)
		else:
			_big(Tr.t("🏆 ¡LO ATRAPASTE!\nEl %s es tuyo: ya está en tu garaje") % str(tg["name"]), 6.0)
		_sync_account()
		CrashLog.mark("evento", "cacería: ganada %s" % str(tg["vid"]))
		for o in targets.duplicate(): # (uno por evento: los otros se van)
			if int(o["ev"]) == int(tg["ev"]):
				_drop(o)
		return
	var why := str(d.get("reason", r.get("error", Tr.t("sin conexión"))))
	_big("😞 " + why, 4.5)
	if r.get("ok", false):
		_drop(tg) # el servidor dijo que no (lo ganó otro, ya ganaste hace poco…)
	else:
		tg["hold"] = maxf(0.0, float(tg["hold"]) - 5.0) # sin conexión: se reintenta
		tg["drv"].mode = "path"

func _drop(tg: Dictionary) -> void:
	tg["done"] = true
	var car = tg["car"]
	if car != null and race.cars.has(car):
		race.remove_car(car)
	targets.erase(tg)
	if targets.is_empty():
		var ch = _ch()
		if ch != null and ch.has_method("clear_dest") and _map_t > 0.0:
			ch.clear_dest()
		_map_t = 0.0

func _bounty_end(ev_id: int, msg: String) -> void:
	var any := false
	for tg in targets.duplicate():
		if int(tg["ev"]) == ev_id:
			_drop(tg)
			any = true
	if any:
		_big(msg, 4.0)

# ───────────────────────── fuga ─────────────────────────
func _escape_evs() -> Array:
	var now := now_server()
	var out: Array = []
	for e in events:
		if str(e.get("kind", "")) == "escape" and phase_of(e, now) == "live" and not bool(e.get("done", false)):
			var att := int(e.get("attempts", 0))
			if att <= 0 or int(e.get("used", 0)) < att:
				out.append(e)
	return out

## Empieza una persecución: un intento en cada fuga en vivo (la misma persecución cuenta para todas)
func _escape_event_begin() -> void:
	if not _online_ok() or _esc_wait or not _esc_runs.is_empty():
		return
	var evs := _escape_evs()
	if evs.is_empty():
		return
	_esc_wait = true
	_esc_end_pending = 0
	_esc_start = Time.get_ticks_msec() / 1000.0
	var on = race.get("online")
	var need := 0.0
	for e in evs:
		var r: Dictionary = await on.call_fn("event_start", {"p_id": int(e["id"]), "p_slot": 0})
		var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
		if r.get("ok", false) and bool(d.get("ok", false)):
			_esc_runs[int(e["id"])] = int(d["run"])
			e["used"] = int(e.get("used", 0)) + 1
			var n := float((e.get("params", {}) as Dictionary).get("chase_s", 600))
			need = n if need <= 0.0 else minf(need, n)
	_esc_wait = false
	if not _esc_runs.is_empty():
		_toast(Tr.t("⏱ Fuga en juego: ¡aguantá %d min y escapá!") % int(need / 60.0))
	if _esc_end_pending != 0:
		_escape_event_end(_esc_end_pending > 0)

func _escape_event_end(escaped: bool) -> void:
	if _esc_wait:
		_esc_end_pending = 1 if escaped else -1
		return
	if _esc_runs.is_empty():
		return
	var runs := _esc_runs
	_esc_runs = {}
	var held := Time.get_ticks_msec() / 1000.0 - _esc_start
	var on = race.get("online")
	var short := 0.0
	var won_any := false
	for ev_id in runs:
		var e := _find(events, int(ev_id))
		var need := float((e.get("params", {}) as Dictionary).get("chase_s", 600)) if not e.is_empty() else 600.0
		var ok := escaped and held >= need
		var r: Dictionary = await on.call_fn("event_finish", {"p_run": int(runs[ev_id]), "p_ok": ok, "p_value": snappedf(held, 0.1), "p_trace": null, "p_name": str(race.profile.d.get("name", "Piloto"))})
		var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
		if ok and r.get("ok", false) and bool(d.get("won", false)):
			stats["won"] += 1
			won_any = true
			_big(Tr.t("🏆 ¡FUGA CUMPLIDA!\n%s") % got_text(d.get("reward", {})), 6.0)
			if not e.is_empty():
				e["done"] = true
			_after_ok("escape")
		elif ok:
			_big("😞 " + str(d.get("reason", r.get("error", Tr.t("sin conexión")))), 4.0)
		elif escaped:
			short = need if short <= 0.0 else minf(short, need)
	if won_any:
		_sync_account()
	elif short > 0.0:
		_toast(Tr.t("⏱ Aguantaste %d:%02d · hacían falta %d:%02d") % [int(held) / 60, int(held) % 60, int(short) / 60, int(short) % 60])

func _escape_line(e: Dictionary, now: float) -> String:
	if bool(e.get("done", false)):
		return ""
	var need := float((e.get("params", {}) as Dictionary).get("chase_s", 600))
	var att := int(e.get("attempts", 0))
	var left := (Tr.t(" · %d intentos") % maxi(0, att - int(e.get("used", 0)))) if att > 0 else ""
	if _esc_runs.has(int(e["id"])):
		var held := Time.get_ticks_msec() / 1000.0 - _esc_start
		return Tr.t("⏱ FUGA %d:%02d / %d:%02d — ¡no te dejes agarrar!") % [int(held) / 60, int(held) % 60, int(need) / 60, int(need) % 60]
	var rem := maxf(0.0, float(e.get("ends", now)) - now)
	return Tr.t("🚨 %s%s · quedan %dh%02d") % [Tr.t(str(e["title"])), left, int(rem) / 3600, (int(rem) % 3600) / 60]

# ───────────────────────── contrarreloj ─────────────────────────
## La ciudad marcada (la misma para todos: semilla del servidor) y la salida de Dream City más cercana a ella
func reach_plan(seed: int) -> Dictionary:
	if _towns.is_empty():
		return {}
	var t: Array = _towns[absi(seed) % _towns.size()]
	var tp: Vector2 = t[1]
	var best: Dictionary = {}
	var bd := 1e18
	for ex in race.track.city.exits:
		var d := (ex["pos"] as Vector2).distance_to(tp)
		if d < bd:
			bd = d
			best = ex
	if best.is_empty():
		return {}
	var ep: Vector2 = best["pos"]
	var start := ep + (Vector2.ZERO - ep).normalized() * 60.0 # (el círculo va un poco adentro de la ciudad, sobre la misma calle)
	var pose: Array = race.track.nearest_road_pose(start, 0.0)
	if not pose.is_empty():
		start = Vector2(float(pose[0]), float(pose[1]))
	return {"town": str(t[2]) if str(t[2]) != "" else str(t[0]), "pos": tp, "start": start, "dist": start.distance_to(tp)}

func _reach_tick(e: Dictionary, dt: float, now: float) -> String:
	if bool(e.get("done", false)):
		_reach_clear()
		return ""
	var att := int(e.get("attempts", 0))
	var used := int(e.get("used", 0))
	if _reach.is_empty() or int(_reach.get("ev", -1)) != int(e["id"]):
		_reach_clear()
		var plan := reach_plan(int(e.get("seed", 0)))
		if plan.is_empty():
			return ""
		var speed := float((e.get("params", {}) as Dictionary).get("speed", 24.0))
		plan["limit"] = clampf(roundf(float(plan["dist"]) * 1.25 / speed / 10.0) * 10.0, 120.0, float((e.get("params", {}) as Dictionary).get("time_max", 1500)))
		plan["ev"] = int(e["id"])
		plan["run"] = -1
		plan["t"] = 0.0
		plan["marker"] = _reach_marker(plan["start"], "%s → %s" % [Tr.t("CONTRARRELOJ"), str(plan["town"])])
		_reach = plan
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	var limit := float(_reach["limit"])
	if int(_reach["run"]) >= 0:
		_reach["t"] = float(_reach["t"]) + dt
		var t := float(_reach["t"])
		if p.distance_to(_reach["pos"]) < REACH_ARRIVE:
			_reach_finish(t <= limit, t)
		elif t > limit + 1.0:
			_reach_finish(false, t)
		return Tr.t("🏁 %s · %d:%02d / %d:%02d") % [str(_reach["town"]), int(t) / 60, int(t) % 60, int(limit) / 60, int(limit) % 60]
	if att > 0 and used >= att:
		return ""
	# largada: frená en el círculo
	if not bool(_reach.get("starting", false)) and p.distance_to(_reach["start"]) < START_R and sqrt(me.vx * me.vx + me.vz * me.vz) < 2.0 and _free_to_play():
		_reach_stop += dt
		if _reach_stop > 0.8:
			_reach_stop = 0.0
			_reach_begin(e)
	else:
		_reach_stop = 0.0
	var dd := p.distance_to(_reach["start"])
	return Tr.t("🏁 %s: llegá a %s en %d:%02d · %d intentos · largada a %.1f km") % [Tr.t(str(e["title"])), str(_reach["town"]), int(limit) / 60, int(limit) % 60, maxi(0, att - used), dd / 1000.0]

func _reach_begin(e: Dictionary) -> void:
	_reach["starting"] = true
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_start", {"p_id": int(e["id"]), "p_slot": 0})
	_reach["starting"] = false
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if r.get("ok", false) and bool(d.get("ok", false)):
		_reach["run"] = int(d["run"])
		_reach["t"] = 0.0
		e["used"] = int(e.get("used", 0)) + 1
		var ch = _ch()
		if ch != null:
			ch.set_dest(_reach["pos"], "🏁 " + str(_reach["town"]))
		_big(Tr.t("🏁 ¡YA! Llegá a %s en %d:%02d") % [str(_reach["town"]), int(float(_reach["limit"])) / 60, int(float(_reach["limit"])) % 60], 3.0)
	else:
		_toast("🏁 " + str(d.get("reason", r.get("error", Tr.t("sin conexión")))))

func _reach_finish(ok: bool, t: float) -> void:
	var run := int(_reach["run"])
	_reach["run"] = -1
	var ch = _ch()
	if ch != null and ch.has_method("clear_dest"):
		ch.clear_dest()
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_finish", {"p_run": run, "p_ok": ok, "p_value": snappedf(t, 0.1), "p_trace": null, "p_name": str(race.profile.d.get("name", "Piloto"))})
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if ok and r.get("ok", false) and bool(d.get("won", false)):
		stats["won"] += 1
		_after_ok("reach")
		_big(Tr.t("🏆 ¡LLEGASTE A TIEMPO! %d:%02d\n%s") % [int(t) / 60, int(t) % 60, got_text(d.get("reward", {}))], 6.0)
		_sync_account()
		var e := _find(events, int(_reach.get("ev", -1)))
		if not e.is_empty():
			e["done"] = true
	elif ok:
		_big("😞 " + str(d.get("reason", r.get("error", Tr.t("sin conexión")))), 4.0)
	else:
		_big(Tr.t("⌛ Se terminó el tiempo"), 3.0)

func _reach_marker(pos: Vector2, text: String) -> Node3D:
	if race.track == null or race.track.world_node == null:
		return null
	var root := Node3D.new()
	var y := float(race.track.ground_y(pos.x, pos.y))
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = START_R
	cm.bottom_radius = START_R
	cm.height = 0.06
	cm.radial_segments = 32
	cm.rings = 1
	ring.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 1.0, 0.5, 0.35)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(pos.x, y + 0.12, pos.y)
	root.add_child(ring)
	var lb := Label3D.new()
	lb.text = "🏁 " + text
	lb.font_size = 56
	lb.pixel_size = 0.011
	lb.outline_size = 12
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.visibility_range_begin = 16.0
	lb.modulate = Color(0.6, 1.0, 0.7)
	lb.position = Vector3(pos.x, y + 5.0, pos.y)
	root.add_child(lb)
	race.track.world_node.add_child(root)
	return root

func _reach_clear() -> void:
	var mk: Variant = _reach.get("marker")
	if mk != null and is_instance_valid(mk):
		(mk as Node).queue_free()
	_reach = {}

# ───────────────────────── desafío de drift ─────────────────────────
## En la Plaza de Drift (city_drift.gd hace la cuenta de siempre): al entrar con el desafío en vivo arranca una sesión de run_s segundos;
## lo que sumás en ese tiempo va al servidor (vale tu mejor intento). Para otro intento hay que salir y volver a entrar.
func _drift_tick(e: Dictionary, dt: float, _now: float) -> String:
	var cd = race.get("city_drift")
	if cd == null or not bool(cd.active):
		return ""
	var run_s := float((e.get("params", {}) as Dictionary).get("run_s", 90))
	if not _drift.is_empty() and int(_drift["ev"]) == int(e["id"]):
		_drift["t"] = float(_drift["t"]) + dt
		var pts := drift_points(cd)
		if float(_drift["t"]) >= run_s:
			_drift_finish(e)
		return Tr.t("🌀 DESAFÍO DE DRIFT %d s · %d pts") % [int(ceil(maxf(0.0, run_s - float(_drift.get("t", run_s))))), int(pts)]
	if not bool(cd.inside):
		_drift_rearm = true
	elif _drift_rearm and not _drift_busy and _drift.is_empty():
		var att := int(e.get("attempts", 0))
		if att <= 0 or int(e.get("used", 0)) < att:
			_drift_rearm = false
			_drift_begin(e, cd)
	var b: Variant = e.get("best")
	var rk := ("  ·  " + Tr.t("vas %dº") % int(e["rank"])) if e.get("rank") != null else ""
	return Tr.t("🌀 %s · tu mejor: %s%s · Plaza de Drift (Ruta 60)") % [Tr.t(str(e["title"])), str(int(float(b))) if b != null else "—", rk]

## Puntos de la sesión: lo que se cobró desde que empezó más el derrape que está en curso
func drift_points(cd) -> float:
	if _drift.is_empty():
		return 0.0
	return maxf(0.0, float(cd.total) + float(cd.cur) - float(_drift["base"]))

func _drift_begin(e: Dictionary, cd) -> void:
	_drift_busy = true
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_start", {"p_id": int(e["id"]), "p_slot": 0})
	_drift_busy = false
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if r.get("ok", false) and bool(d.get("ok", false)):
		e["used"] = int(e.get("used", 0)) + 1
		_drift = {"ev": int(e["id"]), "run": int(d["run"]), "t": 0.0, "base": float(cd.total) + float(cd.cur)}
		_big(Tr.t("🌀 DESAFÍO DE DRIFT\n%d segundos: ¡sumá todo lo que puedas!") % int(float((e.get("params", {}) as Dictionary).get("run_s", 90))), 3.0)
	elif r.get("ok", false):
		_toast("🌀 " + str(d.get("reason", "")))

func _drift_finish(e: Dictionary) -> void:
	if _drift.is_empty():
		return
	var cd = race.get("city_drift")
	if cd != null and float(cd.cur) > 0.0:
		cd._bank() # el derrape que estaba en curso cuenta
	var pts := floorf(drift_points(cd)) if cd != null else 0.0
	var run := int(_drift["run"])
	_drift = {}
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_finish", {"p_run": run, "p_ok": pts > 0.0, "p_value": pts, "p_trace": null, "p_name": str(race.profile.d.get("name", "Piloto"))})
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if pts > 0.0 and bool(d.get("saved", false)):
		if e.get("best") == null or pts > float(e["best"]):
			e["best"] = pts
		e["rank"] = int(d.get("rank", 0))
		_big(Tr.t("🌀 %d puntos · vas %dº en «%s»") % [int(pts), int(d.get("rank", 0)), Tr.t(str(e.get("title", "")))], 4.5)
		_after_ok("drift")
	elif pts > 0.0:
		_big("😞 " + str(d.get("reason", r.get("error", Tr.t("sin conexión")))), 4.0)
	else:
		_toast(Tr.t("🌀 Sin puntos esta vez: salí y volvé a entrar para otro intento"))

# ───────────────────────── temporada ─────────────────────────
## Algo que se cumplió en un evento: si hay temporada en vivo, suma (el servidor lleva la cuenta)
func _after_ok(_kind: String) -> void:
	var now := now_server()
	for e in events:
		if str(e.get("kind", "")) == "season" and phase_of(e, now) == "live":
			_toast(Tr.t("🏅 ¡Suma para la %s!") % Tr.t(str(e["title"])))
			_poll_t = minf(_poll_t, 3.0)
			return

## Tu lugar en un evento de tabla: temporada (puntos), drift (mejor puntaje), carrera de la semana (mejor tiempo)
static func standing_text(e: Dictionary) -> String:
	var k := str(e.get("kind", ""))
	var rk := (" · " + Tr.t("vas %dº de %d") % [int(e["rank"]), int(e.get("players", 0))]) if e.get("rank") != null else ""
	if k == "season":
		return " · " + Tr.t("tus puntos: %d") % (int(e["pts"]) if e.get("pts") != null else 0) + rk
	if k == "drift" and e.get("best") != null:
		return " · " + Tr.t("tu mejor: %d pts") % int(float(e["best"])) + rk
	if k == "record" and e.get("best") != null:
		return " · " + Tr.t("tu mejor: %s") % _fmt(float(e["best"])) + rk
	return ""

# ───────────────────────── carrera de la semana ─────────────────────────
func _record_line(e: Dictionary, _now: float) -> String:
	if weekly.is_empty() or int(weekly["ev"]) != int(e["id"]):
		return ""
	var b: Variant = e.get("best")
	return Tr.t("🏆 %s · tu mejor: %s") % [Tr.t(str(e["title"])), _fmt(float(b)) if b != null else "—"]

## city_events.gd avisa cuando empieza y termina una carrera del mundo abierto
func on_ow_start(id: String) -> void:
	if weekly.is_empty() or str(weekly["ow_id"]) != id or not _online_ok():
		return
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_start", {"p_id": int(weekly["ev"]), "p_slot": 0})
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if r.get("ok", false) and bool(d.get("ok", false)) and not weekly.is_empty():
		weekly["run"] = int(d["run"])

func on_ow_finish(id: String, ok: bool, secs: float) -> void:
	if weekly.is_empty() or str(weekly["ow_id"]) != id or int(weekly.get("run", -1)) < 0:
		return
	var run := int(weekly["run"])
	weekly["run"] = -1
	var on = race.get("online")
	var r: Dictionary = await on.call_fn("event_finish", {"p_run": run, "p_ok": ok, "p_value": snappedf(secs, 0.01), "p_trace": null, "p_name": str(race.profile.d.get("name", "Piloto"))})
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	if ok and bool(d.get("saved", false)):
		_toast(Tr.t("🏆 Carrera de la semana: vas %dº") % int(d.get("rank", 0)))
		_after_ok("record")
		_poll_t = 1.0

func is_weekly(id: String) -> bool:
	return not weekly.is_empty() and str(weekly["ow_id"]) == id

# ───────────────────────── tablero (pausa) ─────────────────────────
func _show_board() -> void:
	if not _online_ok():
		_big(Tr.t("📅 Los eventos en vivo necesitan conexión y tu cuenta"), 3.5)
		return
	var now := now_server()
	var lines: Array = [Tr.t("📅 EVENTOS EN VIVO")]
	for e in events:
		var st := float(e.get("starts", 0))
		var en := float(e.get("ends", 0))
		if en < now:
			continue
		var when := Tr.t("en vivo · termina en %s") % _dur(en - now) if st <= now else Tr.t("empieza en %s") % _dur(st - now)
		lines.append("%s %s — %s · %s%s" % [kind_icon(str(e.get("kind", ""))), Tr.t(str(e["title"])), when, reward_text(e), standing_text(e)])
	if lines.size() == 1:
		lines.append(Tr.t("Ahora no hay eventos: vuelve a mirar en un rato"))
		_poll_t = 0.0
	lines.append(Tr.t("⏳ Tiempo real (jugador contra jugador): próximamente"))
	_big("\n".join(lines.slice(0, 7)), 7.0)

static func kind_icon(k: String) -> String:
	return {"bounty": "🎯", "escape": "🚨", "reach": "🏁", "record": "🏆", "drift": "🌀", "season": "🏅"}.get(k, "📅")

static func _dur(s: float) -> String:
	var n := int(s)
	return ("%dh%02d" % [n / 3600, (n % 3600) / 60]) if n >= 3600 else ("%d:%02d" % [n / 60, n % 60])

static func _fmt(secs: float) -> String:
	return "%d:%04.1f" % [int(secs / 60.0), fmod(secs, 60.0)]

## Lo que el servidor dice que diste: {credits, voucher, car, dup, rent, until, had, skin, skin_cars, tires, tires_cars}
static func got_text(rw: Variant) -> String:
	if not (rw is Dictionary):
		return ""
	var r: Dictionary = rw
	var out: Array = []
	if r.has("car") and not bool(r.get("dup", false)):
		out.append(Tr.t("el %s es tuyo") % _car_name(str(r["car"])))
	if r.has("credits") and int(r["credits"]) > 0:
		out.append("+ $%d" % int(r["credits"]))
	if r.has("voucher") and int(r["voucher"]) > 0:
		out.append(Tr.t("🔧 + $%d de vale de taller") % int(r["voucher"]))
	if r.has("rent") and not bool(r.get("had", false)):
		out.append(Tr.t("el %s es tuyo hasta el %s") % [_car_name(str(r["rent"])), Time.get_date_string_from_unix_time(int(r.get("until", 0)))])
	if r.has("skin"):
		out.append(Tr.t("el diseño %s en %d autos") % [_skin_name(str(r["skin"])), int(r.get("skin_cars", 0))])
	if r.has("tires"):
		out.append(Tr.t("gomas %s en %d autos") % [str(CarBuild.tire(str(r["tires"])).get("n", r["tires"])), int(r.get("tires_cars", 0))])
	return " · ".join(out)

func _sync_account() -> void:
	var acct = race.profile.get("acct")
	if acct != null and acct.has_method("sync"):
		acct.sync() # el servidor ya dio el premio a la cuenta: se trae
	if race.has_method("update_credits_hud"):
		race.update_credits_hud()

## Los autos se rehicieron (taller de prueba, cambio de auto): los de la cacería ya no están en la lista
func forget() -> void:
	targets.clear()

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
	box.offset_left = -340.0
	box.offset_right = 340.0
	box.offset_top = 176.0 # (debajo del velocímetro y del cartel de la policía)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(box)
	_hud_l = Label.new()
	_hud_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_l.add_theme_font_size_override("font_size", 18)
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
	var lay := CanvasLayer.new()
	lay.layer = 3
	_banner = Label.new()
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -440.0
	_banner.offset_right = 440.0
	_banner.offset_top = -170.0
	_banner.offset_bottom = 20.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_theme_font_size_override("font_size", 28)
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
