extends Node
## Lo social del mundo online: presencia (dónde estoy), chat mundial y privado, jugadores conectados, amigos, reportes y mercado de autos.
## Todo pasa por funciones de la base (supabase/migrations/20261005000000_chat_social_market.sql); acá no hay ninguna regla de confianza: el servidor filtra los insultos,
## aplica los bloqueos del chat y guarda la evidencia de los reportes. Si no hay red, cada llamada devuelve {ok:false} y el juego sigue.

const BEAT_EVERY := 2.0 # segundos entre avisos de posición (los otros jugadores te ven moverte con esa frecuencia)
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

const BAD_NICK := ["puta", "puto", "mierda", "carajo", "concha", "verga", "pelotud", "forro", "boludo", "culiad", "idiota", "imbecil", "maricon", "trolo", "sorete", "cabron", "fuck", "shit", "bitch", "bastard", "asshole", "dick", "cunt", "whore", "slut", "nigg", "fagg", "retard", "pussy", "cock", "admin", "moderador"]

## Valida un apodo: devuelve "" si está bien o el texto del problema. Entre 3 y 16 letras, números, espacios, guiones o puntos, y sin palabras ofensivas
static func nick_error(n: String) -> String:
	var t := n.strip_edges()
	if t.length() < 3:
		return "El nombre tiene que tener al menos 3 letras."
	if t.length() > 16:
		return "El nombre puede tener hasta 16 letras."
	var rx := RegEx.new()
	rx.compile("^[A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ _.\\-]+$")
	if rx.search(t) == null:
		return "Usá sólo letras, números, espacios, guiones y puntos."
	var low := t.to_lower().replace("á", "a").replace("é", "e").replace("í", "i").replace("ó", "o").replace("ú", "u").replace("ñ", "n").replace("0", "o").replace("1", "i").replace("3", "e").replace("4", "a").replace(" ", "").replace("_", "").replace(".", "").replace("-", "")
	for w in BAD_NICK:
		if low.contains(w):
			return "Ese nombre no está permitido. Elegí otro."
	return ""

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
	var inst := str(profile.instance_of(str(profile.current_id()))) if profile.has_method("instance_of") else ""
	await online.call_fn("presence_beat", {"p_x": x, "p_z": z, "p_speed": kmh, "p_car": str(profile.current_id()), "p_name": player_name(), "p_instance": inst if inst != "" else null})
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
	var r: Dictionary = await online.call_fn("presence_list_v", {"p_limit": 60})
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
## Cada auto en venta es una instancia verificada por el servidor (market_list_instance): el servidor hace el traspaso y paga al vendedor en el momento. El estado del auto no lo manda el teléfono.
func _eco() -> RefCounted:
	return profile.get("eco") as RefCounted

func _resync() -> void:
	var e := _eco()
	if e != null and await e.sync(player_name()):
		profile.rebuild()

func market_browse() -> Array:
	var r: Dictionary = await online.call_fn("market_browse", {"p_limit": 40})
	return r["data"] if r["ok"] and r["data"] is Array else []

## Pone a la venta un auto del garaje online (con sus mejoras y pintura). Sale del garaje al publicarse y vuelve si se retira.
func market_sell(car_id: String, price: int) -> Dictionary:
	var e := _eco()
	var inst: String = str(profile.instance_of(car_id)) if e != null else ""
	if inst == "":
		return {"ok": false, "text": "Ese auto no es tuyo."}
	if (profile.d["owned"] as Dictionary).size() <= 1:
		return {"ok": false, "text": "No podés vender tu único auto."}
	var r: Dictionary = await e.act("market_list_instance", {"p_instance": inst, "p_price": price, "p_name": player_name()}, false)
	if not bool(r["ok"]):
		var m := str(r["text"])
		if m.contains("máximo"):
			return {"ok": false, "text": "Ya tenés 5 autos en venta."}
		if m.contains("garage") or m.contains("venta"):
			return {"ok": false, "text": "Ese auto ya está en venta."}
		return {"ok": false, "text": "No se pudo publicar la venta."}
	await _resync()
	return {"ok": true, "text": "Auto publicado en el mercado."}

func market_cancel(row: Dictionary) -> Dictionary:
	var e := _eco()
	if e == null:
		return {"ok": false, "text": "No se pudo retirar."}
	var r: Dictionary = await e.act("market_cancel", {"p_id": int(row["id"])}, false)
	if not bool(r["ok"]):
		return {"ok": false, "text": "No se pudo retirar."}
	await _resync()
	return {"ok": true, "text": "Retiraste el auto de la venta."}

func market_buy(row: Dictionary) -> Dictionary:
	var e := _eco()
	var cid := str(row.get("car", ""))
	var price := int(row.get("price", 0))
	if e == null:
		return {"ok": false, "text": "Sin conexión."}
	if profile.owns(cid):
		return {"ok": false, "text": "Ya tenés ese auto."}
	if profile.credits < price:
		return {"ok": false, "text": "No te alcanzan los créditos."}
	var r: Dictionary = await e.act("market_buy_instance", {"p_id": int(row["id"])}, false)
	if not bool(r["ok"]):
		var m := str(r["text"])
		if m.contains("alcanza"):
			return {"ok": false, "text": "No te alcanzan los créditos."}
		if m.contains("lleno"):
			return {"ok": false, "text": "Tu garaje está lleno (máximo 12 autos)."}
		return {"ok": false, "text": "Ya no está disponible."}
	await _resync()
	return {"ok": true, "text": "¡Compraste el auto! Ya está en tu garaje."}

## Al abrir el mercado se vuelve a pedir el saldo al servidor: lo que se vendió ya está acreditado (devuelve cuánto entró desde la última vez)
func market_collect() -> int:
	var e := _eco()
	if not active or e == null:
		return 0
	var before: int = int(e.credits)
	await _resync()
	return maxi(0, int(e.credits) - before)
