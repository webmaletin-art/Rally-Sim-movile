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
var _hud: CanvasLayer # el cuadrito del intento que estás jugando (sólo mientras corre uno: ver _build_hud)
var _hud_l: Label
var _bar: ProgressBar
var _bar_fill: StyleBoxFlat
var notes: Array = [] # novedades de los eventos (quién ganó, avisos, resultados): se ven en la pantalla EVENTOS → NOVEDADES, nunca como letras en el juego
var _seen := {} # id del evento → 1 vista de «próximo», 2 vista «en vivo» (el puntito de notificación se apaga al abrir la pantalla de eventos)
var _dismissed := {} # eventos que el jugador dejó («SALIR DEL EVENTO»): no se sueltan autos, no se anota intento
var _go_ev := -1 # evento al que se mandó el GPS con «IR AL EVENTO»
var _dot_cache := false
var _towns: Array = []

func setup(p_race) -> void:
	race = p_race
	_load_seen()
	_build_hud()
	var rg = race.track.get("region") if race.track != null else null
	if rg != null:
		for n in rg.nodes:
			if int(n[3]) in [3, 4]:
				var q := Vector2(float(n[1]), float(n[2]))
				if q.length() >= REACH_MIN and q.length() <= REACH_MAX:
					_towns.append([str(n[0]), q, str(n[4]) if (n as Array).size() > 4 else ""])
	_towns.sort_custom(func(a: Array, b: Array) -> bool: return str(a[0]) < str(b[0]))

## ¿Hay escapes que pagan y AYUDA acá? (mundo abierto sin el mundo compartido, con la policía de la región)
func available() -> bool:
	return race.get("police") != null and bool(race.police.enabled) and race.cfg.get("online", false) != true

## ¿Hay EVENTOS acá? Sólo si el mundo se abrió desde el MODO ONLINE (cfg «events», menu_world._start_city). Pedido del dueño (19/10/2026): «el online y el offline son
## distintos juegos, como el GTA: en el mundo abierto offline no tienen que aparecer los eventos online; si no, juego el offline y hago trampa».
func events_on() -> bool:
	return available() and race.cfg.get("events", false) == true

func _online_ok() -> bool:
	var on = race.get("online")
	return on != null and on.has_method("is_account") and on.is_account() and race.cfg.get("testCar") == null

## La pausa ya no tiene botones de modos: los eventos tienen su pantalla (event_cards → race_hud → events_ui.gd) y la ayuda va adentro de ella
func pause_buttons() -> Array:
	return []

func toggle(_m: String) -> void:
	pass

## El texto de la ayuda (solapa AYUDA de la pantalla de eventos y botón AYUDA de la pausa)
func help_text() -> String:
	var g = race.get("goal")
	return g.help_text() if g != null else ""

func now_server() -> float:
	return Time.get_unix_time_from_system() + _clock_off

func update(dt: float) -> void:
	if race.cars.is_empty() or not available():
		_hud.visible = false
		return
	var lines: Array = []
	_bar.visible = false
	_escapes(dt)
	if events_on() and _online_ok():
		_poll_t -= dt
		if _poll_t <= 0.0 and not _busy:
			_poll_t = POLL_SOON if _soon() else POLL_IDLE
			_poll()
		var now := now_server()
		for e in events:
			var l := _event_tick(e, dt, now)
			if l != "":
				lines.append(l)
	# En la pantalla de juego NO hay letras de eventos: todo está en la pausa → EVENTOS. Sólo mientras corre un intento (fuga, contrarreloj, drift, carrera de la
	# semana, pegado a un auto de la cacería) se ve un cuadrito chico con el reloj o los puntos, como el cronómetro de cualquier carrera.
	_hud.visible = not lines.is_empty()
	_hud_l.text = str(lines[0]) if not lines.is_empty() else ""
	_badge()

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
		_toast(Tr.t("😎 ¡TE ESCAPASTE! + $%d · racha %d") % [pay, streak])
		if race.has_method("update_credits_hud"):
			race.update_credits_hud()
		if streak > best_streak:
			best_streak = streak
			if events_on(): # (el ranking es del online: la racha del mundo offline no cuenta)
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
				_note(Tr.t("📢 %s ganó «%s»%s") % [str(w.get("name", "")), Tr.t(str(w.get("event", ""))), (" · " + _car_name(car)) if car != "" and car != "<null>" else ""])
	_first_poll = false
	# hitos de la temporada (fase 5): si llegaste a uno que no cobraste, se pide una vez (el servidor lo paga una sola vez)
	for e in events:
		var hi := season_due(e)
		if hi >= 0 and int(_hito_asked.get(int(e["id"]), -1)) < hi:
			_hito_asked[int(e["id"])] = hi
			_claim_hitos(int(e["id"]))
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

## Hitos de la temporada: el más alto alcanzado y sin cobrar (−1 si no hay)
static func season_due(e: Dictionary) -> int:
	if str(e.get("kind", "")) != "season" or not (e.get("hitos") is Array):
		return -1
	var pts := int(e["pts"]) if e.get("pts") != null else 0
	var got: Array = e.get("hitos_got", []) if e.get("hitos_got") is Array else []
	var best := -1
	for i in (e["hitos"] as Array).size():
		if pts >= int((e["hitos"][i] as Dictionary).get("pts", 1 << 30)) and not got.has(i) and not got.has(float(i)):
			best = i
	return best

## El próximo hito de la temporada: «próximo hito: 60 pts → $6.000» (vacío si ya los tiene todos)
static func next_hito_text(e: Dictionary) -> String:
	if not (e.get("hitos") is Array):
		return ""
	var pts := int(e["pts"]) if e.get("pts") != null else 0
	for h in (e["hitos"] as Array):
		if pts < int((h as Dictionary).get("pts", 0)):
			return " · " + Tr.t("próximo hito: %d pts → %s") % [int(h["pts"]), got_text(h.get("reward", {}))]
	return ""

var _hito_asked := {}
func _claim_hitos(ev_id: int) -> void:
	var on = race.get("online")
	if on == null or not _online_ok():
		return
	var r: Dictionary = await on.call_fn("season_claim", {"p_id": ev_id})
	var d: Dictionary = r.get("data") if r.get("data") is Dictionary else {}
	for g in (d.get("granted", []) as Array):
		_toast(Tr.t("🏅 ¡Hito de la temporada! %s") % got_text((g as Dictionary).get("reward", {})))
	if not (d.get("granted", []) as Array).is_empty():
		var acct = race.profile.get("acct")
		if acct != null and acct.has_method("sync"):
			acct.sync() # el servidor ya dio el premio a la cuenta: se trae

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
	if _dismissed.has(id):
		return ""
	if now < st:
		# (sin carteles: el próximo evento se ve en la pausa → EVENTOS y con el puntito rojo del botón de pausa; al minuto de empezar queda en NOVEDADES)
		if a == 0 and st - now < 1800.0:
			_announced[id] = 1
		elif a == 1 and st - now < 60.0:
			_announced[id] = 2
			_note(Tr.t("📅 «%s» empieza en 1 minuto") % Tr.t(str(e["title"])))
		return ""
	if now >= en:
		if kind == "bounty":
			_bounty_end(id, Tr.t("💨 Se fueron los autos de la cacería"))
		elif kind == "drift" and not _drift.is_empty() and int(_drift["ev"]) == id:
			_drift_finish(e) # se termina la sesión que estaba en juego (el servidor da 2 min de gracia)
		return ""
	if a < 3 and kind != "bounty":
		_announced[id] = 3 # (antes: cartel gigante «EN VIVO» en el medio de la pantalla; ahora está en la pausa → EVENTOS)
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

## El auto que se puede ganar en un evento (para la miniatura de su tarjeta): el del premio, el alquilado, el del 1.º puesto o el primero de la cacería; "" si no hay
static func prize_car(e: Dictionary) -> String:
	var r: Dictionary = e.get("reward", {}) if e.get("reward") is Dictionary else {}
	if r.has("top") and r["top"] is Array and not (r["top"] as Array).is_empty() and (r["top"] as Array)[0] is Dictionary:
		r = (r["top"] as Array)[0]
	if r.get("car") is String and str(r["car"]) != "":
		return str(r["car"])
	if r.get("rent") is String and str(r["rent"]) != "":
		return str(r["rent"])
	var cars: Variant = (e.get("params", {}) as Dictionary).get("cars", []) if e.get("params") is Dictionary else []
	if cars is Array and not (cars as Array).is_empty():
		var c0: Variant = (cars as Array)[0]
		if c0 is String:
			return c0
		if c0 is Dictionary:
			return str((c0 as Dictionary).get("id", (c0 as Dictionary).get("car", "")))
	return ""

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
				_toast(Tr.t("😞 %s atrapó el %s") % [str(won_slots[int(tg["slot"])]), str(tg["name"])])
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
				_toast(Tr.t("🎯 Cacería: %d autos sueltos, mirá el mapa") % n)
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
			_note(Tr.t("🎯 Ya no se ven en el mapa: buscalos"))
	if not best.is_empty() and (best_d < 90.0 or float(best["hold"]) > 0.0): # (el cuadrito sólo aparece pegado a un auto de la cacería)
		var hs := float((e.get("params", {}) as Dictionary).get("hold_s", 60))
		var green := best_d < STICK_R
		_bar.visible = true
		_bar.max_value = hs
		_bar.value = float(best["hold"])
		_bar_fill.bg_color = Color(0.2, 0.9, 0.35) if green else Color(0.95, 0.7, 0.15)
		line = "🎯 %d / %d s" % [int(best["hold"]), int(hs)]
	elif int(_announced.get(id, 0)) == 2 and _free_to_play() and not mine:
		_announced[id] = 0 # terminó la carrera: ahora sí se sueltan
	return line

func _free_to_play() -> bool:
	var evs = race.get("ow_events")
	return (evs == null or not evs.busy()) and _reach.get("run", -1) == -1

## Cómo maneja el auto perseguido de una cacería. Por defecto, como siempre (+15 % de potencia, +12 % de agarre, ritmo 112 %, sin errores: la cacería
## difícil). Fase 5 (16/10/2026): el servidor puede mandar params.boost / pace / errors para una cacería accesible (autos C/B, sin empujón, con errores).
## Cacería con tope de PI (params.max_pi, la accesible): ¿el auto con el que vas puede entrar? Sin tope, cualquiera.
static func pi_ok(prm: Dictionary, my_pi: int) -> bool:
	return int(prm.get("max_pi", 0)) <= 0 or my_pi <= int(prm.get("max_pi", 0))

static func prey_ai(prm: Dictionary) -> Dictionary:
	var boost := float(prm.get("boost", 1.0 if prm.has("pace") else 1.15))
	return {"power": boost, "mu": 1.0 + (boost - 1.0) * 0.8, "grip": float(prm.get("grip", 1.15 if boost > 1.0 else 1.0)),
		"pace": clampf(float(prm.get("pace", 1.12)), 0.8, 1.2), "errors": bool(prm.get("errors", false))}

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
	var prm: Dictionary = e.get("params", {})
	var ai := prey_ai(prm)
	drv.mode = "parked"
	drv.grip = float(ai["grip"])
	drv.pace = float(ai["pace"])
	drv.errors = bool(ai["errors"])
	var base: Dictionary = race.vehicles[vid]
	var car = race.add_ai_car(vid, float(pose[0]), float(pose[1]), float(pose[2]), drv, Color(str(Profile.new_car_state(vid)["paint"]["body"])),
		{"powerScale": float(base.get("powerScale", 1.0)) * float(ai["power"]), "mu": float(base.get("mu", 1.0)) * float(ai["mu"])})
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
		"slack_i": 0, "slack_t": 0.0, "label": lb, "route_t": 0.0, "done": false, "claiming": false, "cp_t": 0.0, "starting": false, "pace": float(ai["pace"])})
	CrashLog.mark("evento", "cacería: suelto %s (slot %d)" % [vid, slot])
	return true

func _hunt_one(e: Dictionary, tg: Dictionary, dt: float, now: float, p: Vector2, q: Vector2, d: float) -> void:
	var hs := float((e.get("params", {}) as Dictionary).get("hold_s", 60))
	# el intento se anota en el servidor cuando te acercás (gasta un intento sólo si de verdad vas por él)
	if int(tg["run"]) < 0 and d < 300.0 and not bool(tg["starting"]):
		if not pi_ok(e.get("params", {}), _my_pi()):
			if not bool(tg.get("pi_told", false)):
				tg["pi_told"] = true
				_toast(Tr.t("🎯 Esta cacería es para autos de hasta PI %d: el tuyo tiene %d") % [int((e.get("params", {}) as Dictionary).get("max_pi", 0)), _my_pi()])
		else:
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
			drv.pace = float(tg.get("pace", 1.12))
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

## PI del auto con el que vas (lo mismo que se manda con los récords por clase)
var _pi_of := ["", 0]
func _my_pi() -> int:
	var car := str(race.cfg.get("car", ""))
	if str(_pi_of[0]) != car:
		_pi_of = [car, int(ClassRecords.meta(race.vehicles.get(car, {}), race.cfg.get("state", {}) if race.cfg.get("state") is Dictionary else {}, "").get("pi", 0))]
	return int(_pi_of[1])

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
	if any and msg != "":
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
		return "🚨 %d:%02d / %d:%02d" % [int(held) / 60, int(held) % 60, int(need) / 60, int(need) % 60]
	return "" # (sin persecución en juego no hay renglón: la fuga está en la pausa → EVENTOS)

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
		return "🏁 %d:%02d / %d:%02d" % [int(t) / 60, int(t) % 60, int(limit) / 60, int(limit) % 60]
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
	return "" # (antes de largar no hay letras: el evento está en la pausa → EVENTOS, con «IR AL EVENTO» que marca la largada en el GPS)

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

func _reach_finish(ok: bool, t: float, quiet := false) -> void:
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
	elif not quiet:
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
		return "🌀 %d s · %d pts" % [int(ceil(maxf(0.0, run_s - float(_drift.get("t", run_s))))), int(pts)]
	if not bool(cd.inside):
		_drift_rearm = true
	elif _drift_rearm and not _drift_busy and _drift.is_empty():
		var att := int(e.get("attempts", 0))
		if att <= 0 or int(e.get("used", 0)) < att:
			_drift_rearm = false
			_drift_begin(e, cd)
	return "" # (el desafío espera en la pausa → EVENTOS)

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

func _drift_finish(e: Dictionary, quiet := false) -> void:
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
	elif not quiet:
		_toast(Tr.t("🌀 Sin puntos esta vez: salí y volvé a entrar para otro intento"))

# ───────────────────────── temporada ─────────────────────────
## Algo que se cumplió en un evento: si hay temporada en vivo, suma (el servidor lleva la cuenta)
func _after_ok(_kind: String) -> void:
	var now := now_server()
	for e in events:
		if str(e.get("kind", "")) == "season" and phase_of(e, now) == "live":
			_note(Tr.t("🏅 ¡Suma para la %s!") % Tr.t(str(e["title"])))
			_poll_t = minf(_poll_t, 3.0)
			return

## Tu lugar en un evento de tabla: temporada (puntos), drift (mejor puntaje), carrera de la semana (mejor tiempo)
static func standing_text(e: Dictionary) -> String:
	var k := str(e.get("kind", ""))
	var rk := (" · " + Tr.t("vas %dº de %d") % [int(e["rank"]), int(e.get("players", 0))]) if e.get("rank") != null else ""
	if k == "season":
		return " · " + Tr.t("tus puntos: %d") % (int(e["pts"]) if e.get("pts") != null else 0) + rk + next_hito_text(e)
	if k == "drift" and e.get("best") != null:
		return " · " + Tr.t("tu mejor: %d pts") % int(float(e["best"])) + rk
	if k == "record" and e.get("best") != null:
		return " · " + Tr.t("tu mejor: %s") % _fmt(float(e["best"])) + rk
	return ""

# ───────────────────────── carrera de la semana ─────────────────────────
func _record_line(e: Dictionary, _now: float) -> String:
	if weekly.is_empty() or int(weekly["ev"]) != int(e["id"]) or int(weekly.get("run", -1)) < 0:
		return "" # (sólo mientras corrés la carrera de la semana)
	return "" # (mientras corrés la carrera, su propio cuadrito ya muestra el tiempo: city_events.gd)

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

# ───────────────────────── tablero (pausa → EVENTOS) ─────────────────────────
## Las tarjetas de la pantalla EVENTOS (ui/events_ui.gd): una por evento que no terminó, primero los que están en vivo.
## Cada una: {id, kind, icon, title, descr, how, live, done, when, when_short, reward, reward_short, prizes[{car,text,icon}], progress, car, go, go_label, active, new}.
## Vacía si no hay eventos acá (mundo offline) o todavía no contestó el servidor.
func event_cards() -> Array:
	var out: Array = []
	if not events_on():
		return out
	var now := now_server()
	for e in events:
		var st := float(e.get("starts", 0))
		var en := float(e.get("ends", 0))
		if en < now:
			continue
		var live := st <= now
		var id := int(e["id"])
		var kind := str(e.get("kind", ""))
		var stand := standing_text(e).strip_edges().trim_prefix("· ")
		var prog: Array = []
		if stand != "":
			prog.append(stand)
		if int(e.get("attempts", 0)) > 0:
			prog.append(Tr.t("intentos: %d de %d") % [int(e.get("used", 0)), int(e.get("attempts", 0))])
		if bool(e.get("done", false)):
			prog.append("✔ " + Tr.t("ya lo hiciste"))
		var gp: Variant = _go_point(e)
		out.append({"id": id, "kind": kind, "icon": kind_icon(kind), "title": Tr.t(str(e["title"])), "descr": Tr.t(str(e.get("descr", ""))), "how": how_text(kind),
			"live": live, "done": bool(e.get("done", false)),
			"when": (Tr.t("En vivo · termina en %s") % _dur(en - now)) if live else (Tr.t("Empieza en %s") % _dur(st - now)),
			"when_short": (Tr.t("termina en %s") % _dur(en - now)) if live else (Tr.t("empieza en %s") % _dur(st - now)),
			"reward": reward_text(e), "reward_short": reward_text(e).trim_prefix(Tr.t("premio: ")).trim_prefix(Tr.t("premios: ")), "prizes": prize_list(e),
			"progress": "\n".join(prog), "car": prize_car(e), "go": gp != null, "go_label": go_label(kind), "active": _is_active(e), "new": int(_seen.get(str(id), 0)) < (2 if live else 1)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return bool(a["live"]) and not bool(b["live"]))
	return out

## Cómo se juega cada tipo de evento (una frase)
static func how_text(kind: String) -> String:
	return {
		"bounty": Tr.t("Hay autos sueltos por la ciudad: mirá el mapa los primeros segundos y pegate al auto hasta llenar la barra. El primero que lo logra se lo lleva."),
		"escape": Tr.t("Hacé que la policía te persiga (pasá un control o chocá) y aguantá el tiempo indicado sin que te agarren."),
		"reach": Tr.t("Frená en el círculo de la salida de Dream City y llegá a la ciudad marcada antes de que se acabe el tiempo."),
		"record": Tr.t("Corré la carrera marcada del mapa. Tu tiempo va a la tabla y los tres mejores se llevan premios."),
		"drift": Tr.t("Entrá a la Plaza de Drift y sumá todos los puntos que puedas derrapando mientras dura el desafío."),
		"season": Tr.t("Cada evento que cumplís suma puntos a la temporada. Al cerrar, premios para los primeros y por cada hito."),
	}.get(kind, "")

static func go_label(kind: String) -> String:
	return {"bounty": Tr.t("IR A LA ZONA"), "escape": Tr.t("IR A UN CONTROL POLICIAL"), "reach": Tr.t("IR A LA LARGADA"), "record": Tr.t("IR A LA CARRERA"), "drift": Tr.t("IR A LA PLAZA DE DRIFT")}.get(kind, Tr.t("IR AL EVENTO"))

## Los premios de un evento, uno por renglón: [{car, icon, text}]
static func prize_list(e: Dictionary) -> Array:
	var out: Array = []
	var r: Variant = e.get("reward", {})
	if r is Dictionary and (r as Dictionary).has("top") and (r["top"] is Array):
		var tp: Array = r["top"]
		for k in mini(5, tp.size()):
			var pr: Variant = tp[k]
			out.append({"car": str(pr.get("car", pr.get("rent", ""))) if pr is Dictionary else "", "icon": ["🥇", "🥈", "🥉", "🏅", "🏅"][k], "text": "%dº · %s" % [k + 1, prize_text(pr)]})
		return out
	if r is Dictionary and (r as Dictionary).has("car") and not (r["car"] is String):
		var cars: Variant = (e.get("params", {}) as Dictionary).get("cars", []) if e.get("params") is Dictionary else []
		out.append({"car": prize_car(e), "icon": "🎁", "text": Tr.t("el auto que atrapes")})
		return out
	var t := prize_text(r)
	if t != "":
		out.append({"car": prize_car(e), "icon": "🎁", "text": t})
	return out

## Hitos de la temporada y otras tarjetas pueden no tener lugar: «go» sólo si hay adónde ir
func _is_active(e: Dictionary) -> bool:
	var id := int(e["id"])
	if _go_ev == id:
		var ch = _ch()
		if ch != null and bool(ch.get("has_dest")):
			return true
	if _esc_runs.has(id) or (not _reach.is_empty() and int(_reach.get("ev", -1)) == id and int(_reach.get("run", -1)) >= 0) or (not _drift.is_empty() and int(_drift["ev"]) == id):
		return true
	if not weekly.is_empty() and int(weekly["ev"]) == id and int(weekly.get("run", -1)) >= 0:
		return true
	for tg in targets:
		if int(tg["ev"]) == id and not bool(tg["done"]):
			return true
	return false

## ¿Hay algo nuevo para mirar? (un evento que todavía no viste, uno que recién empezó o una novedad): enciende el puntito rojo del botón de pausa y del menú de pausa
func has_unseen() -> bool:
	if not events_on() or not _online_ok():
		return false
	for n in notes:
		if bool(n.get("new", false)):
			return true
	var now := now_server()
	for e in events:
		if float(e.get("ends", 0)) < now:
			continue
		var live := float(e.get("starts", 0)) <= now
		if int(_seen.get(str(int(e["id"])), 0)) < (2 if live else 1):
			return true
	return false

## Se abrió la pantalla de eventos: todo lo que había quedó visto (se apaga el puntito)
func mark_seen() -> void:
	var now := now_server()
	for e in events:
		_seen[str(int(e["id"]))] = 2 if float(e.get("starts", 0)) <= now else 1
	for n in notes:
		n["new"] = false
	if race.profile != null and race.profile.has_method("set_setting"):
		var keep := {}
		for e in events:
			keep[str(int(e["id"]))] = _seen[str(int(e["id"]))]
		race.profile.set_setting("evSeen", keep) # (sólo los eventos de ahora: no crece)
	_badge()

func _load_seen() -> void:
	if race.profile != null and race.profile.has_method("setting"):
		var d: Variant = race.profile.setting("evSeen")
		if d is Dictionary:
			for k in (d as Dictionary):
				_seen[str(k)] = int((d as Dictionary)[k])

## El puntito de notificación sobre el botón de pausa (ui/controls.gd): sólo en el modo online y sólo si hay algo nuevo; ninguna letra
func _badge() -> void:
	var on := has_unseen()
	if on == _dot_cache:
		return
	_dot_cache = on
	var ctl = race.get("controls")
	if ctl != null and "badge_dot" in ctl:
		ctl.badge_dot = on
		ctl.queue_redraw()

## Dónde se juega un evento (para «IR AL EVENTO»): la largada del contrarreloj, la Plaza de Drift, la carrera de la semana, la zona de la cacería o un control policial; null si no tiene lugar fijo
func _go_point(e: Dictionary) -> Variant:
	match str(e.get("kind", "")):
		"reach":
			if not _reach.is_empty() and int(_reach.get("ev", -1)) == int(e["id"]):
				return _reach["start"]
			var plan := reach_plan(int(e.get("seed", 0)))
			if not plan.is_empty():
				return plan["start"]
		"drift":
			var cd = race.get("city_drift")
			if cd != null:
				return cd.c
		"record":
			if not weekly.is_empty() and int(weekly["ev"]) == int(e["id"]):
				var evs = race.get("ow_events")
				if evs != null:
					for oe in evs.events:
						if str(oe["id"]) == str(weekly["ow_id"]):
							return oe["start"]
		"bounty":
			if race.track != null and race.track.get("city") != null:
				return spawn_point(race.track.city, int(e.get("seed", 0)))
		"escape":
			return _nearest_control()
	return null

## El control policial más cercano (para empezar una fuga)
func _nearest_control() -> Variant:
	var pol = race.get("police")
	if pol == null or race.cars.is_empty():
		return null
	var cps: Variant = pol.get("checkpoints")
	if not (cps is Array) or (cps as Array).is_empty():
		return null
	var me = race.cars[0].phys
	var p := Vector2(me.px, me.pz)
	var best: Variant = null
	var bd := 1e18
	for c in (cps as Array):
		var q: Vector2 = c["p"]
		var d := q.distance_to(p)
		if d < bd:
			bd = d
			best = q
	return best

## «IR AL EVENTO»: marca el lugar en el GPS (el auto sigue el camino). Devuelve el aviso para mostrar en la pantalla de eventos.
func event_go(id: int) -> String:
	var e := _find(events, id)
	var q: Variant = _go_point(e) if not e.is_empty() else null
	var ch = _ch()
	if q == null or ch == null:
		return ""
	_dismissed.erase(id)
	_go_ev = id
	ch.set_dest(q, kind_icon(str(e.get("kind", ""))) + " " + Tr.t(str(e["title"])), true)
	return Tr.t("GPS listo: seguí la ruta hasta el evento")

## «SALIR DEL EVENTO»: se saca el GPS, se corta el intento en curso (cuenta como no cumplido) y el evento queda quieto hasta que vuelvas a tocar IR AL EVENTO
func event_cancel(id: int) -> String:
	var e := _find(events, id)
	if e.is_empty():
		return ""
	var ch = _ch()
	if _go_ev == id:
		_go_ev = -1
		if ch != null and ch.has_method("clear_dest"):
			ch.clear_dest()
	_dismissed[id] = true
	if not _reach.is_empty() and int(_reach.get("ev", -1)) == id:
		if int(_reach.get("run", -1)) >= 0:
			_reach_finish(false, float(_reach.get("t", 0.0)), true)
		_reach_clear()
	if not _drift.is_empty() and int(_drift["ev"]) == id:
		_drift_finish(e, true)
	if not weekly.is_empty() and int(weekly["ev"]) == id:
		weekly["run"] = -1
	if str(e.get("kind", "")) == "bounty":
		_bounty_end(id, "")
	return Tr.t("Saliste del evento: el juego sigue normal")

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
	# El cuadrito del intento en curso: arriba al centro, justo debajo del velocímetro, chico. Sólo se ve mientras corre un intento (como el cronómetro de una carrera).
	_hud = CanvasLayer.new()
	_hud.layer = 3
	var pnl := PanelContainer.new()
	pnl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pnl.offset_left = -105.0
	pnl.offset_right = 105.0
	pnl.offset_top = 124.0
	pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.78)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1.0, 0.72, 0.2, 0.7)
	sb.set_border_width_all(1)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0
	pnl.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pnl.add_child(box)
	_hud.add_child(pnl)
	_hud_l = Label.new()
	_hud_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_l.add_theme_font_size_override("font_size", 17)
	_hud_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	_hud_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hud_l)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.show_percentage = false
	_bar_fill = StyleBoxFlat.new()
	_bar_fill.bg_color = Color(0.95, 0.7, 0.15)
	_bar.add_theme_stylebox_override("fill", _bar_fill)
	_bar.visible = false
	box.add_child(_bar)
	_hud.visible = false
	_hud.set_meta("panel", pnl)
	race.add_child(_hud)

## Un resultado de lo que estás jugando: queda en NOVEDADES y sale un aviso chico de un par de segundos (la primera línea). Nada de carteles grandes.
func _big(s: String, _secs := 3.0) -> void:
	_toast(s)

## Aviso corto + novedad
func _toast(s: String) -> void:
	_note(s)
	if race.race_hud != null:
		race.race_hud.toast(s.split("\n")[0])

## Sólo una novedad (sin aviso en pantalla): enciende el puntito de notificación
func _note(s: String) -> void:
	notes.push_front({"t": int(now_server()), "text": s, "new": true})
	if notes.size() > 40:
		notes.resize(40)
