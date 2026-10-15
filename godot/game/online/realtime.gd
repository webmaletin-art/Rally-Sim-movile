extends Node
## Cliente de Supabase Realtime (WebSocket, protocolo Phoenix «vsn 1.0.0», el mismo que usa supabase-js): canales de «broadcast» (mensajes entre jugadores, sin pasar por la base)
## y «presence» (quién está en el canal). Es lo que va a reemplazar la consulta periódica de posiciones (online_social.gd) cuando se encienda Release.REALTIME.
## Sólo habla el protocolo: no sabe nada del juego (eso lo hace world_sync.gd). Se prueba contra tools/online/mock_realtime.py (tests/realtime_test.gd).
##
## Cosas que cuida (porque Realtime tiene tope de mensajes por segundo y de canales por conexión):
##  · latidos cada 25 s y reconexión con espera creciente (1, 2, 4, 8, 15, 30 s) · al reconectar se vuelve a entrar a todos los canales pedidos
##  · tope de mensajes por canal (cubo de fichas) y cola chica mientras no hay socket (lo viejo se descarta: una posición vieja no sirve)
##  · canales privados (autorizados por las políticas de realtime.messages, ver supabase/migrations/20261012000000_realtime_private.sql); si el servidor dice que no hay permiso, no insiste
##  · al renovar la sesión (set_token) se avisa a todos los canales abiertos

signal socket_open
signal socket_closed(code: int, reason: String)
signal channel_joined(channel: String)
signal channel_error(channel: String, reason: String)
signal broadcast_received(channel: String, event: String, payload: Dictionary)
signal presence_changed(channel: String)

const VSN := "1.0.0"
const HEARTBEAT_S := 25.0
const REPLY_TIMEOUT_S := 10.0
const BACKOFF := [1.0, 2.0, 4.0, 8.0, 15.0, 30.0]
const MAX_QUEUE := 40
const MAX_JOIN_TRIES := 4 # canales que el servidor rechaza (sin permiso): se dejan de intentar
const DEFAULT_RATE := 12.0 # mensajes por segundo y por canal (tope de cortesía)
const DEFAULT_BURST := 4.0

var url := "" # «https://proyecto.supabase.co» (o «http://127.0.0.1:puerto» en las pruebas)
var anon_key := ""
var token := "" # JWT de la sesión (cuenta con correo)
var state := "idle" # idle | connecting | open | waiting (espera para reconectar)
var wanted := false # quien lo usa lo quiere conectado
var rtt_ms := -1.0 # ida y vuelta del último latido
var rtt_min_ms := -1.0 # la mejor ida y vuelta medida (la demora base de la red, sin los picos)
var stats := {"sent": 0, "received": 0, "dropped": 0, "reconnects": 0}
var last_close := ""

var _ws: WebSocketPeer
var _ref := 0
var _ch: Dictionary = {} # nombre → {want, state, ref, join_ref, tries, since, key, private, presence, rate, burst, tokens, t_refill, retry_t}
var _hb_t := HEARTBEAT_S
var _hb_ref := ""
var _hb_sent := 0.0
var _wait := 0.0
var _attempt := 0
var _queue: Array = []

# ───────────────────────── armado de mensajes (puro, se prueba sin red) ─────────────────────────
static func socket_url(base: String, key: String) -> String:
	var u := base.strip_edges().rstrip("/")
	if u.begins_with("https://"):
		u = "wss://" + u.substr(8)
	elif u.begins_with("http://"):
		u = "ws://" + u.substr(7)
	return u + "/realtime/v1/websocket?apikey=" + key.uri_encode() + "&vsn=" + VSN

static func topic_of(channel: String) -> String:
	return "realtime:" + channel

static func channel_of(topic: String) -> String:
	return topic.trim_prefix("realtime:")

static func encode(topic: String, event: String, payload: Dictionary, ref: String, join_ref := "") -> String:
	var m := {"topic": topic, "event": event, "payload": payload, "ref": ref}
	if join_ref != "":
		m["join_ref"] = join_ref
	return JSON.stringify(m)

static func join_payload(access_token: String, key: String, is_private: bool) -> Dictionary:
	return {"config": {"broadcast": {"ack": false, "self": false}, "presence": {"key": key}, "postgres_changes": [], "private": is_private}, "access_token": access_token}

static func broadcast_payload(event: String, payload: Dictionary) -> Dictionary:
	return {"type": "broadcast", "event": event, "payload": payload}

## Las claves de presencia de un «presence_state» ({clave: {metas: [...]}}) → {clave: [metas]}
static func parse_presence_state(p: Dictionary) -> Dictionary:
	var out := {}
	for k in p:
		var v: Variant = p[k]
		if v is Dictionary and (v as Dictionary).get("metas") is Array:
			out[str(k)] = (v as Dictionary)["metas"]
	return out

# ───────────────────────── uso ─────────────────────────
func configure(p_url: String, p_anon_key: String) -> void:
	url = p_url
	anon_key = p_anon_key

func set_token(t: String) -> void:
	token = t
	if state == "open":
		for name in _ch:
			var c: Dictionary = _ch[name]
			if c["state"] == "joined":
				_send_raw(topic_of(name), "access_token", {"access_token": token}, _next_ref(), "")

func connect_socket() -> void:
	wanted = true
	if state == "idle" or state == "waiting":
		_open()

func close_socket() -> void:
	wanted = false
	if _ws != null:
		_ws.close(1000, "bye")
	state = "idle"
	_hb_ref = ""
	for name in _ch:
		_ch[name]["state"] = "closed"

func is_open() -> bool:
	return state == "open"

## Pide entrar a un canal (se entra cuando haya socket). opts: {private (true), key (clave de presencia), rate (msg/s), burst}
func join(channel: String, opts := {}) -> void:
	if _ch.has(channel) and bool((_ch[channel] as Dictionary)["want"]):
		return
	var c := {"want": true, "state": "closed", "ref": "", "join_ref": "", "tries": 0, "since": 0.0, "retry_t": 0.0, "key": str(opts.get("key", "")), "private": bool(opts.get("private", true)),
		"presence": {}, "rate": float(opts.get("rate", DEFAULT_RATE)), "burst": float(opts.get("burst", DEFAULT_BURST)), "tokens": float(opts.get("burst", DEFAULT_BURST)), "t_refill": Time.get_ticks_msec() / 1000.0}
	_ch[channel] = c
	if state == "open":
		_do_join(channel)
	elif wanted and state == "idle":
		_open()

func leave(channel: String) -> void:
	if not _ch.has(channel):
		return
	var c: Dictionary = _ch[channel]
	c["want"] = false
	if state == "open" and c["state"] != "closed":
		_send_raw(topic_of(channel), "phx_leave", {}, _next_ref(), "")
	c["state"] = "closed"
	_ch.erase(channel)

func channels() -> Array:
	return _ch.keys()

func is_joined(channel: String) -> bool:
	return _ch.has(channel) and (_ch[channel] as Dictionary)["state"] == "joined"

## Segundos desde que se entró al canal (0 si no está adentro)
func joined_for(channel: String) -> float:
	if not is_joined(channel):
		return 0.0
	return Time.get_ticks_msec() / 1000.0 - float((_ch[channel] as Dictionary).get("joined_at", Time.get_ticks_msec() / 1000.0))

func joined_count() -> int:
	var n := 0
	for name in _ch:
		if (_ch[name] as Dictionary)["state"] == "joined":
			n += 1
	return n

## Manda un mensaje a los demás del canal. Devuelve false si no se mandó (sin canal, sin conexión o por pasarse del tope)
func send_broadcast(channel: String, event: String, payload: Dictionary) -> bool:
	if not _ch.has(channel):
		stats["dropped"] += 1
		return false
	var c: Dictionary = _ch[channel]
	var now := Time.get_ticks_msec() / 1000.0
	c["tokens"] = minf(float(c["burst"]), float(c["tokens"]) + (now - float(c["t_refill"])) * float(c["rate"]))
	c["t_refill"] = now
	if float(c["tokens"]) < 1.0:
		stats["dropped"] += 1
		return false
	if c["state"] != "joined" or state != "open":
		stats["dropped"] += 1 # una posición vieja no sirve: no se guarda para después
		return false
	c["tokens"] = float(c["tokens"]) - 1.0
	_send_raw(topic_of(channel), "broadcast", broadcast_payload(event, payload), _next_ref(), "")
	return true

## Avisa mi presencia en el canal (quién soy; lo de siempre, no la posición)
func track(channel: String, meta: Dictionary) -> void:
	if is_joined(channel):
		_send_raw(topic_of(channel), "presence", {"type": "presence", "event": "track", "payload": meta}, _next_ref(), "")

## Quiénes están en el canal según la presencia: {clave: [metas]}
func presence(channel: String) -> Dictionary:
	return (_ch[channel] as Dictionary)["presence"] if _ch.has(channel) else {}

func presence_count(channel: String) -> int:
	return presence(channel).size()

# ───────────────────────── socket ─────────────────────────
func _open() -> void:
	if url == "" or anon_key == "":
		return
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url(socket_url(url, anon_key))
	if err != OK:
		_schedule_reconnect("no se pudo abrir (%d)" % err)
		return
	state = "connecting"
	set_process(true)

func _schedule_reconnect(why: String) -> void:
	last_close = why
	state = "waiting"
	_wait = float(BACKOFF[mini(_attempt, BACKOFF.size() - 1)]) * randf_range(0.75, 1.25) # (con algo de azar: si se cae el servidor, no vuelven todos en el mismo instante)
	_attempt += 1
	_hb_ref = ""
	for name in _ch:
		if (_ch[name] as Dictionary)["state"] == "joined" or (_ch[name] as Dictionary)["state"] == "joining":
			(_ch[name] as Dictionary)["state"] = "closed"

func _on_open() -> void:
	state = "open"
	_attempt = 0
	_hb_t = 3.0 # (el primer latido sale enseguida: así se sabe cuánto tarda la red sin esperar 25 s)
	_hb_ref = ""
	socket_open.emit()
	for name in _ch.keys():
		var c: Dictionary = _ch[name]
		if bool(c["want"]):
			c["tries"] = 0
			_do_join(name)
	var q := _queue.duplicate()
	_queue.clear()
	for m in q:
		_ws.send_text(str(m))

func _process(dt: float) -> void:
	if state == "idle":
		return
	if state == "waiting":
		_wait -= dt
		if wanted and _wait <= 0.0:
			stats["reconnects"] += 1
			_open()
		return
	if _ws == null:
		return
	_ws.poll()
	var rs := _ws.get_ready_state()
	if rs == WebSocketPeer.STATE_OPEN:
		if state == "connecting":
			_on_open()
		while _ws.get_available_packet_count() > 0:
			var pkt := _ws.get_packet()
			if _ws.was_string_packet():
				_handle(pkt.get_string_from_utf8())
	elif rs == WebSocketPeer.STATE_CLOSED:
		var code := _ws.get_close_code()
		var why := _ws.get_close_reason()
		var was_open := state == "open"
		_schedule_reconnect("cerrado (%d) %s" % [code, why])
		if not wanted:
			state = "idle"
		if was_open:
			socket_closed.emit(code, why)
		return
	if state != "open":
		return
	var now := Time.get_ticks_msec() / 1000.0
	# latidos
	_hb_t -= dt
	if _hb_t <= 0.0:
		_hb_t = HEARTBEAT_S
		if _hb_ref != "":
			_ws.close(4000, "sin respuesta al latido") # el anterior no volvió: el socket está muerto
			return
		_hb_ref = _next_ref()
		_hb_sent = now
		_send_raw("phoenix", "heartbeat", {}, _hb_ref, "")
	# canales: respuestas que no llegan y reintentos
	for name in _ch.keys():
		var c: Dictionary = _ch[name]
		if not bool(c["want"]):
			continue
		match str(c["state"]):
			"joining":
				if now - float(c["since"]) > REPLY_TIMEOUT_S:
					_chan_failed(name, "sin respuesta")
			"errored":
				if int(c["tries"]) < MAX_JOIN_TRIES and now >= float(c["retry_t"]):
					_do_join(name)

func _next_ref() -> String:
	_ref += 1
	return str(_ref)

func _send_raw(topic: String, event: String, payload: Dictionary, ref: String, join_ref: String) -> void:
	var txt := encode(topic, event, payload, ref, join_ref)
	if state == "open" and _ws != null:
		_ws.send_text(txt)
		stats["sent"] += 1
	elif _queue.size() < MAX_QUEUE and event != "broadcast":
		_queue.append(txt)

func _do_join(name: String) -> void:
	var c: Dictionary = _ch[name]
	var ref := _next_ref()
	c["state"] = "joining"
	c["ref"] = ref
	c["join_ref"] = ref
	c["since"] = Time.get_ticks_msec() / 1000.0
	c["tries"] = int(c["tries"]) + 1
	_send_raw(topic_of(name), "phx_join", join_payload(token, str(c["key"]), bool(c["private"])), ref, ref)

func _chan_failed(name: String, reason: String) -> void:
	if not _ch.has(name):
		return
	var c: Dictionary = _ch[name]
	c["state"] = "errored"
	c["retry_t"] = Time.get_ticks_msec() / 1000.0 + minf(2.0 * float(c["tries"]), 10.0)
	channel_error.emit(name, reason)

func _handle(txt: String) -> void:
	var m: Variant = JSON.parse_string(txt)
	if not (m is Dictionary):
		return
	stats["received"] += 1
	var d: Dictionary = m
	var topic := str(d.get("topic", ""))
	var ev := str(d.get("event", ""))
	var payload: Variant = d.get("payload", {})
	var ref := str(d.get("ref", "")) if d.get("ref") != null else ""
	if topic == "phoenix":
		if ev == "phx_reply" and ref == _hb_ref:
			rtt_ms = (Time.get_ticks_msec() / 1000.0 - _hb_sent) * 1000.0
			rtt_min_ms = rtt_ms if rtt_min_ms < 0.0 else minf(rtt_min_ms, rtt_ms)
			_hb_ref = ""
		return
	var name := channel_of(topic)
	if not _ch.has(name):
		return
	var c: Dictionary = _ch[name]
	match ev:
		"phx_reply":
			if ref == str(c["ref"]) and c["state"] == "joining":
				var st := str((payload as Dictionary).get("status", "")) if payload is Dictionary else ""
				if st == "ok":
					c["state"] = "joined"
					c["tries"] = 0
					c["joined_at"] = Time.get_ticks_msec() / 1000.0
					channel_joined.emit(name)
				else:
					var resp: Variant = (payload as Dictionary).get("response", {}) if payload is Dictionary else {}
					var why := str((resp as Dictionary).get("reason", "error")) if resp is Dictionary else "error"
					if "permission" in why.to_lower() or "unauthor" in why.to_lower():
						c["tries"] = MAX_JOIN_TRIES # sin permiso: no se reintenta
					_chan_failed(name, why)
		"phx_error":
			_chan_failed(name, "error del canal")
		"phx_close":
			# lo cerró el servidor (sesión renovada, reinicio): se olvida, y quien lo pidió (world_sync._manage_cells) lo vuelve a pedir si todavía lo quiere.
			# Antes quedaba en la lista sin querer reabrirse: esa celda quedaba muda hasta salir de ella.
			var jr := str(d.get("join_ref", "")) if d.get("join_ref") != null else ref
			if jr == "" or jr == str(c["join_ref"]): # (el cierre de una entrada vieja no borra la nueva)
				_ch.erase(name)
		"broadcast":
			if payload is Dictionary and str((payload as Dictionary).get("type", "")) == "broadcast":
				var inner: Variant = (payload as Dictionary).get("payload", {})
				broadcast_received.emit(name, str((payload as Dictionary).get("event", "")), inner if inner is Dictionary else {})
		"presence_state":
			if payload is Dictionary:
				c["presence"] = parse_presence_state(payload)
				presence_changed.emit(name)
		"presence_diff":
			if payload is Dictionary:
				var pr: Dictionary = c["presence"]
				var joins: Variant = (payload as Dictionary).get("joins", {})
				var leaves: Variant = (payload as Dictionary).get("leaves", {})
				if leaves is Dictionary:
					for k in leaves:
						pr.erase(str(k))
				if joins is Dictionary:
					for k in parse_presence_state(joins):
						pr[k] = parse_presence_state(joins)[k]
				presence_changed.emit(name)
