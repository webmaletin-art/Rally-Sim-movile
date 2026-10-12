extends Node
## Posiciones del mundo online en tiempo real, sobre Realtime (realtime.gd). Sólo se usa con Release.REALTIME encendido (hoy apagado: el mundo online sigue con la consulta
## periódica de online_social.gd). Ahorra mensajes con DOS ideas, porque Realtime tiene tope de mensajes por segundo (Pro: 500) y no hay que mandarle todo a todos:
##
##  1) CELDAS: el mundo se parte en cuadrados de 2 km (CELL). Cada jugador manda su posición SÓLO al canal de su celda («world:cx:cz») y escucha su celda más las vecinas a las
##     que está a menos de 700 m del borde (MARGIN, lo que se ve de lejos): como mucho 4 canales. Dos jugadores a 30 km no se mandan nada.
##  2) RITMO ADAPTATIVO: con k jugadores en un canal cada mensaje se entrega a k−1 personas. Se reparte un presupuesto de BUDGET entregas por segundo y por canal:
##     solo (k=1) → 1 cada 10 s · k=2 o 3 → 5 Hz · k=5 → 3 Hz · k=8 → 1,1 Hz · k=11 o más → 0,5 Hz. Quieto manda 1 vez cada 5 s; en movimiento sólo si se movió.
##     (la cuenta de Supabase se paga por mensaje y tiene tope por segundo: docs/ONLINE_SUPABASE.md, «Tiempo real», explica los números)
##
## Los mensajes son de cliente a cliente: NO son autoritativos (cualquiera podría mandar cualquier cosa). Por eso acá se descarta lo imposible (fuera del mapa, NaN, velocidades
## absurdas) y nada de la economía depende de esto: sólo se dibujan autos. Los nombres y los modelos NO viajan por acá (se filtran en el servidor y llegan por presence_list_v).

const Realtime := preload("res://game/online/realtime.gd")

signal car_state(id: String, st: Dictionary) # {x, z, yaw, kmh, t}
signal car_left(id: String)

const CELL := 2000.0
const MARGIN := 700.0
const HYST := 150.0 # histéresis: un canal ya abierto se cierra recién cuando el borde queda a más de MARGIN + HYST
const BUDGET := 60.0
const MIN_HZ := 0.5
const MAX_HZ := 5.0
const IDLE_HZ := 0.2
const ALONE_HZ := 0.1 # nadie más en el canal: casi no hace falta mandar
const MOVE_EPS := 0.4 # metros que hay que moverse para que valga la pena avisar
const GONE_S := 5.0 # sin noticias de un auto en tanto tiempo: se fue
const MAX_COORD := 400000.0
const MAX_KMH := 700.0
const EVENT := "s"
const REFRESH_LEFT := 300.0 # se renueva la sesión cuando faltan menos de estos segundos

var rt: Node
var uid := ""
var my_cell := Vector2i.ZERO
var stats := {"sent": 0, "received": 0, "bad": 0, "own": 0}
var seen: Dictionary = {} # id → último momento (s) en que llegó algo
var _x := 0.0
var _z := 0.0
var _yaw := 0.0
var _kmh := 0.0
var _has_pos := false
var _send_t := 0.0
var _sent_pos := Vector2(1e9, 1e9)
var _manage_t := 0.0
var _seq := 0
var _online: Node

# ───────────────────────── reglas (puras, se prueban sin red) ─────────────────────────
static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor(x / CELL)), int(floor(z / CELL)))

static func channel_name(c: Vector2i) -> String:
	return "world:%d:%d" % [c.x, c.y]

## La celda propia y las vecinas que quedan a menos de `margin` metros (con `open`: canales ya abiertos, que se mantienen un poco más). Máximo 4, la propia primero.
static func cells_for(x: float, z: float, open: Array = [], margin := MARGIN) -> Array:
	var c := cell_of(x, z)
	var out: Array = [c]
	var fx := x - float(c.x) * CELL # metros desde el borde oeste/norte de mi celda
	var fz := z - float(c.y) * CELL
	var dx := 0
	var dz := 0
	var mx := margin + (HYST if open.has(Vector2i(c.x - 1, c.y)) else 0.0)
	var px := margin + (HYST if open.has(Vector2i(c.x + 1, c.y)) else 0.0)
	if fx < mx:
		dx = -1
	elif CELL - fx < px:
		dx = 1
	var mz := margin + (HYST if open.has(Vector2i(c.x, c.y - 1)) else 0.0)
	var pz := margin + (HYST if open.has(Vector2i(c.x, c.y + 1)) else 0.0)
	if fz < mz:
		dz = -1
	elif CELL - fz < pz:
		dz = 1
	if dx != 0:
		out.append(Vector2i(c.x + dx, c.y))
	if dz != 0:
		out.append(Vector2i(c.x, c.y + dz))
	if dx != 0 and dz != 0:
		out.append(Vector2i(c.x + dx, c.y + dz))
	return out

## Cuántas veces por segundo conviene mandar la posición cuando hay k jugadores en el canal (incluido uno mismo)
static func rate_for(k: int) -> float:
	if k <= 1:
		return ALONE_HZ
	return clampf(BUDGET / float(k * (k - 1)), MIN_HZ, MAX_HZ)

static func pack(id: String, x: float, z: float, yaw: float, kmh: float, seq: int) -> Dictionary:
	return {"i": id, "x": snappedf(x, 0.1), "z": snappedf(z, 0.1), "a": snappedf(yaw, 0.01), "v": int(round(kmh)), "n": seq}

## Valida un mensaje que llegó. Devuelve {} si no sirve
static func unpack(p: Dictionary) -> Dictionary:
	for k in ["i", "x", "z", "a", "v"]:
		if not p.has(k):
			return {}
	if not (p["i"] is String) or str(p["i"]).length() < 8 or str(p["i"]).length() > 64:
		return {}
	for k in ["x", "z", "a", "v"]:
		if not (p[k] is float or p[k] is int):
			return {}
		if is_nan(float(p[k])) or is_inf(float(p[k])):
			return {}
	var x := float(p["x"])
	var z := float(p["z"])
	var v := float(p["v"])
	if absf(x) > MAX_COORD or absf(z) > MAX_COORD or v < -20.0 or v > MAX_KMH or absf(float(p["a"])) > 20.0:
		return {}
	return {"id": str(p["i"]), "x": x, "z": z, "yaw": float(p["a"]), "kmh": maxf(v, 0.0), "n": int(p.get("n", 0))}

# ───────────────────────── uso ─────────────────────────
## online: online.gd (dirección, clave y sesión). Crea el cliente de Realtime y se conecta.
func setup(p_online: Node) -> void:
	_online = p_online
	uid = str(p_online.uid)
	rt = Realtime.new()
	add_child(rt)
	rt.configure(str(p_online.url), str(p_online.anon_key))
	rt.set_token(str(p_online.token))
	rt.broadcast_received.connect(_on_broadcast)
	rt.channel_joined.connect(_on_joined)
	rt.connect_socket()

## Para las pruebas: usar un cliente de Realtime ya armado
func setup_with(p_rt: Node, p_uid: String) -> void:
	rt = p_rt
	uid = p_uid
	rt.broadcast_received.connect(_on_broadcast)
	rt.channel_joined.connect(_on_joined)

func stop() -> void:
	if rt != null:
		rt.close_socket()

## race.gd la llama en cada cuadro con la posición del auto del jugador
func update_me(dt: float, x: float, z: float, yaw: float, kmh: float) -> void:
	_x = x
	_z = z
	_yaw = yaw
	_kmh = kmh
	_has_pos = true
	if rt == null:
		return
	_manage_t -= dt
	if _manage_t <= 0.0:
		_manage_t = 0.5
		_manage_cells()
		_refresh_token()
	_expire()
	var ch := channel_name(cell_of(x, z))
	if not rt.is_joined(ch):
		return
	var k := maxi(rt.presence_count(ch), _recent_count() + 1)
	var moved := Vector2(x, z).distance_to(_sent_pos) > MOVE_EPS
	var hz := rate_for(k) if moved else IDLE_HZ
	_send_t += dt
	if _send_t >= 1.0 / hz:
		_send_t = 0.0
		_seq += 1
		if rt.send_broadcast(ch, EVENT, pack(uid, x, z, yaw, kmh, _seq)):
			stats["sent"] += 1
			_sent_pos = Vector2(x, z)

func _recent_count() -> int:
	var now := Time.get_ticks_msec() / 1000.0
	var n := 0
	for id in seen:
		if now - float(seen[id]) < 3.0:
			n += 1
	return n

func _open_cells() -> Array:
	var out: Array = []
	for name in rt.channels():
		var s := str(name)
		if s.begins_with("world:"):
			var p := s.split(":")
			if p.size() == 3:
				out.append(Vector2i(int(p[1]), int(p[2])))
	return out

func _manage_cells() -> void:
	var open := _open_cells()
	var want := cells_for(_x, _z, open)
	my_cell = want[0]
	for c in want:
		if not open.has(c):
			rt.join(channel_name(c), {"private": true, "key": uid})
	for c in open:
		if not want.has(c):
			rt.leave(channel_name(c))

## Si falta poco para que venza la sesión, se renueva y se le avisa a Realtime (sin token válido el servidor corta los canales)
func _refresh_token() -> void:
	if _online == null or not _online.has_method("sign_in"):
		return
	if int(_online.expires_at) - int(Time.get_unix_time_from_system()) > int(REFRESH_LEFT):
		return
	var old := str(_online.token)
	await _online.sign_in()
	if str(_online.token) != "" and str(_online.token) != old and rt != null:
		rt.set_token(str(_online.token))

## Al entrar a un canal se avisa la presencia (sólo «estoy acá»: así todos saben cuántos son y el ritmo se ajusta enseguida); los nombres y modelos NO viajan por acá
func _on_joined(channel: String) -> void:
	if channel.begins_with("world:"):
		rt.track(channel, {"t": int(Time.get_unix_time_from_system())})

func _on_broadcast(channel: String, event: String, payload: Dictionary) -> void:
	if event != EVENT or not channel.begins_with("world:"):
		return
	var st := unpack(payload)
	if st.is_empty():
		stats["bad"] += 1
		return
	if str(st["id"]) == uid:
		stats["own"] += 1
		return
	stats["received"] += 1
	var now := Time.get_ticks_msec() / 1000.0
	seen[str(st["id"])] = now
	st["t"] = now
	car_state.emit(str(st["id"]), st)

func _expire() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for id in seen.keys():
		if now - float(seen[id]) > GONE_S:
			seen.erase(id)
			car_left.emit(str(id))
