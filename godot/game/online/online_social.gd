extends Node
## Lo social del mundo online: presencia (dónde estoy), chat mundial y privado, jugadores conectados, amigos, reportes y mercado de autos.
## Todo pasa por funciones de la base (supabase/migrations/20261005000000_chat_social_market.sql); acá no hay ninguna regla de confianza: el servidor filtra los insultos,
## aplica los bloqueos del chat y guarda la evidencia de los reportes. Si no hay red, cada llamada devuelve {ok:false} y el juego sigue.

const BEAT_EVERY := 6.0 # segundos entre avisos de posición
const POLL_IDLE := 12.0 # el chat mundial se mira despacio con el panel cerrado (para el globito de mensajes nuevos)
const POLL_OPEN := 3.0 # y rápido con el panel abierto
const KEEP := 80 # mensajes que se guardan por canal

signal chat_changed(channel: String)

var online: Node
var profile: RefCounted
var active := false # hay sesión en el mundo online (si no, no se manda nada)
var x := 0.0
var z := 0.0
var kmh := 0.0
var events: Array = [] # lo que pasó cerca (golpes, etc.) para la evidencia de un reporte: [{t, what}]
var msgs: Dictionary = {} # canal → [mensajes]
var last_id: Dictionary = {} # canal → id del último mensaje recibido
var unread := 0 # mensajes mundiales nuevos desde que se abrió el panel
var panel_open := false
var watch := "world" # canal que se está mirando
var blocked_until := 0.0 # unix: hasta cuándo no puedo escribir
var sent_log: Array = [] # lo que intenté escribir (incluye lo que el filtro tapó), para la evidencia
var _beat_t := 0.0
var _poll_t := 0.0
var _busy := false
var _beating := false

func setup(p_online: Node, p_profile: RefCounted) -> void:
	online = p_online
	profile = p_profile
	active = online != null and online.configured() and online.is_account()
	set_process(active)
	if active:
		_beat_t = 1.0

func player_name() -> String:
	return str(profile.d.get("name", "Piloto")) if profile != null else "Piloto"

## race.gd la llama cada tanto con la posición y la velocidad del auto
func set_state(px: float, pz: float, speed_kmh: float) -> void:
	x = px
	z = pz
	kmh = speed_kmh

func note_event(what: String) -> void:
	events.append({"t": Time.get_unix_time_from_system(), "what": what, "x": roundf(x), "z": roundf(z), "kmh": roundf(kmh)})
	while events.size() > 20:
		events.pop_front()

func _process(dt: float) -> void:
	if not active:
		return
	_beat_t -= dt
	if _beat_t <= 0.0 and not _beating:
		_beat_t = BEAT_EVERY
		_beat()
	_poll_t -= dt
	if _poll_t <= 0.0 and not _busy:
		_poll_t = POLL_OPEN if panel_open else POLL_IDLE
		poll(watch)

func _beat() -> void:
	_beating = true
	await online.call_fn("presence_beat", {"p_x": x, "p_z": z, "p_speed": kmh, "p_car": str(profile.current_id()), "p_name": player_name()})
	_beating = false

## Al salir del mundo se avisa para no quedar como conectado
func leave() -> void:
	if active:
		active = false
		set_process(false)
		online.call_fn("presence_leave", {})

# ───────────────────────── chat ─────────────────────────
static func dm_channel(a: String, b: String) -> String:
	return "dm:%s:%s" % [a, b] if a < b else "dm:%s:%s" % [b, a]

func channel_with(other: String) -> String:
	return dm_channel(str(online.uid), other)

func blocked_left() -> int:
	return maxi(0, int(ceil(blocked_until - Time.get_unix_time_from_system())))

func poll(channel: String) -> void:
	if not active or _busy:
		return
	_busy = true
	var r: Dictionary = await online.call_fn("chat_fetch", {"p_channel": channel, "p_after": int(last_id.get(channel, 0)), "p_limit": 40})
	_busy = false
	if not r["ok"] or not (r["data"] is Array):
		return
	var rows: Array = r["data"]
	if rows.is_empty():
		return
	var first := not last_id.has(channel) # lo que ya estaba escrito al conectarse no cuenta como «nuevo»
	var list: Array = msgs.get(channel, [])
	for row in rows:
		if row is Dictionary:
			list.append(row)
			last_id[channel] = maxi(int(last_id.get(channel, 0)), int(row.get("id", 0)))
			if channel == "world" and not first and not panel_open and not bool(row.get("mine", false)):
				unread += 1
	while list.size() > KEEP:
		list.pop_front()
	msgs[channel] = list
	chat_changed.emit(channel)

## Devuelve {ok, text} con el aviso para mostrar. El servidor tapa los insultos con asteriscos, cuenta las faltas y bloquea el chat cuando se repiten.
func send(channel: String, body: String) -> Dictionary:
	if not active:
		return {"ok": false, "text": "Sin conexión."}
	if blocked_left() > 0:
		return {"ok": false, "text": "Tenés el chat bloqueado un rato más."}
	var clean := body.strip_edges()
	if clean == "":
		return {"ok": false, "text": ""}
	var r: Dictionary = await online.call_fn("chat_send", {"p_channel": channel, "p_body": clean, "p_name": player_name()})
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	sent_log.append({"t": Time.get_unix_time_from_system(), "channel": "world" if channel == "world" else "dm", "body": clean, "ok": bool(d.get("ok", false)), "masked": bool(d.get("masked", false)), "reason": str(d.get("reason", ""))})
	while sent_log.size() > 20:
		sent_log.pop_front()
	if not r["ok"]:
		return {"ok": false, "text": "No se pudo mandar. Probá de nuevo."}
	if int(d.get("seconds", 0)) > 0 and (str(d.get("reason", "")) == "bloqueado" or bool(d.get("masked", false))):
		blocked_until = Time.get_unix_time_from_system() + float(d["seconds"])
	if bool(d.get("ok", false)):
		_poll_t = 0.5
		if bool(d.get("masked", false)):
			return {"ok": true, "text": "Se taparon palabras no permitidas."}
		return {"ok": true, "text": ""}
	match str(d.get("reason", "")):
		"bloqueado": return {"ok": false, "text": "Tenés el chat bloqueado un rato más."}
		"muy rápido": return {"ok": false, "text": "Más despacio: un mensaje por segundo."}
	return {"ok": false, "text": ""}

func threads() -> Array:
	var r: Dictionary = await online.call_fn("chat_threads", {})
	return r["data"] if r["ok"] and r["data"] is Array else []

# ───────────────────────── jugadores y amigos ─────────────────────────
func players() -> Array:
	var r: Dictionary = await online.call_fn("presence_list", {"p_limit": 60})
	return r["data"] if r["ok"] and r["data"] is Array else []

func friends() -> Array:
	var r: Dictionary = await online.call_fn("follow_list", {})
	return r["data"] if r["ok"] and r["data"] is Array else []

func follow(id: String, on: bool) -> bool:
	var r: Dictionary = await online.call_fn("follow_set", {"p_target": id, "p_on": on})
	return bool(r["ok"])

# ───────────────────────── reportes ─────────────────────────
## Manda el reporte con lo que vio este teléfono (chat reciente con ese jugador, mi posición y velocidad, lo que pasó cerca). El servidor suma lo suyo (rastro, faltas del chat).
## No castiga a nadie: queda guardado para revisarlo con tools/online/report_view.py
func report(id: String, note: String) -> Dictionary:
	var recent: Array = []
	for ch in msgs:
		for m in msgs[ch]:
			if m is Dictionary and str(m.get("sender", "")) == id:
				recent.append({"channel": "world" if str(ch) == "world" else "dm", "id": m.get("id"), "at": m.get("created_at"), "body": m.get("body")})
	var build := ""
	if FileAccess.file_exists("res://game/build_id.txt"):
		build = FileAccess.get_file_as_string("res://game/build_id.txt").strip_edges()
	var client := {"version": 1, "build": build, "at": Time.get_unix_time_from_system(), "my_pos": [x, z], "my_kmh": kmh, "their_chat_seen": recent.slice(-20),
		"my_chat_tries": sent_log, "events": events}
	var r: Dictionary = await online.call_fn("report_submit", {"p_reported": id, "p_note": note.substr(0, 300), "p_client": client})
	if r["ok"]:
		return {"ok": true, "text": "Reporte enviado. Lo vamos a revisar."}
	var e := str(r["error"])
	if e.contains("demasiados"):
		return {"ok": false, "text": "Ya mandaste varios reportes: esperá un rato."}
	return {"ok": false, "text": "No se pudo mandar el reporte."}

# ───────────────────────── mercado de autos ─────────────────────────
func market_browse() -> Array:
	var r: Dictionary = await online.call_fn("market_browse", {"p_limit": 40})
	return r["data"] if r["ok"] and r["data"] is Array else []

## Pone a la venta el auto con sus mejoras y pintura. El auto sale del garaje al publicarse (si se cancela vuelve igual que estaba).
func market_sell(car_id: String, price: int) -> Dictionary:
	var owned: Dictionary = profile.d["owned"]
	if not owned.has(car_id):
		return {"ok": false, "text": "Ese auto no es tuyo."}
	if owned.size() <= 1:
		return {"ok": false, "text": "No podés vender tu único auto."}
	var state: Dictionary = (owned[car_id] as Dictionary).duplicate(true)
	owned.erase(car_id)
	var was_current: bool = str(profile.d["current"]) == car_id
	if was_current:
		profile.d["current"] = str(owned.keys()[0])
	profile.save()
	var r: Dictionary = await online.call_fn("market_list", {"p_car": car_id, "p_state": state, "p_price": price, "p_name": player_name()})
	if not r["ok"]:
		owned[car_id] = state # no se pudo publicar: el auto vuelve
		if was_current:
			profile.d["current"] = car_id
		profile.save()
		var e := str(r["error"])
		if e.contains("máximo"):
			return {"ok": false, "text": "Ya tenés 5 autos en venta."}
		return {"ok": false, "text": "No se pudo publicar la venta."}
	return {"ok": true, "text": "Auto publicado en el mercado."}

func market_cancel(row: Dictionary) -> Dictionary:
	var r: Dictionary = await online.call_fn("market_cancel", {"p_id": int(row["id"])})
	if not r["ok"]:
		return {"ok": false, "text": "No se pudo retirar."}
	var cid := str(row.get("car", ""))
	if cid != "" and not profile.owns(cid) and row.get("state") is Dictionary:
		profile.d["owned"][cid] = (row["state"] as Dictionary).duplicate(true)
		profile.save()
	return {"ok": true, "text": "Retiraste el auto de la venta."}

func market_buy(row: Dictionary) -> Dictionary:
	var cid := str(row.get("car", ""))
	var price := int(row.get("price", 0))
	if profile.owns(cid):
		return {"ok": false, "text": "Ya tenés ese auto."}
	if profile.credits < price:
		return {"ok": false, "text": "No te alcanzan los créditos."}
	var r: Dictionary = await online.call_fn("market_buy", {"p_id": int(row["id"])})
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	if not r["ok"] or not bool(d.get("ok", false)):
		return {"ok": false, "text": "Ya no está disponible."}
	if not profile.spend(int(d.get("price", price))):
		return {"ok": false, "text": "No te alcanzan los créditos."}
	if d.get("state") is Dictionary:
		profile.d["owned"][str(d.get("car", cid))] = (d["state"] as Dictionary).duplicate(true)
	else:
		profile.give(cid)
	profile.save()
	return {"ok": true, "text": "¡Compraste el auto! Ya está en tu garaje."}

## Cobra lo que se vendió desde la última vez (los créditos viven en cada teléfono)
func market_collect() -> int:
	if not active:
		return 0
	var r: Dictionary = await online.call_fn("market_collect", {})
	var d: Dictionary = r["data"] if r["data"] is Dictionary else {}
	var cr := int(d.get("credits", 0))
	if r["ok"] and cr > 0:
		profile.earn(cr)
	return cr if r["ok"] else 0
