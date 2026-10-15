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
const NT := preload("res://game/online/net_tuning.gd") # (todos los ritmos y umbrales: net_tuning.gd)
const BUDGET := NT.SEND_BUDGET
const MIN_HZ := NT.SEND_MIN_HZ_CROWD
const MAX_HZ := NT.SEND_MAX_HZ
const IDLE_HZ := NT.SEND_IDLE_HZ
const ALONE_HZ := NT.SEND_ALONE_HZ
const MOVE_EPS := NT.MOVE_EPS
const GONE_S := NT.GONE_S
const MAX_COORD := 400000.0
const MAX_KMH := 700.0
const EVENT := "s"
const REFRESH_LEFT := 300.0 # se renueva la sesión cuando faltan menos de estos segundos

var rt: Node
var uid := ""
var my_cell := Vector2i.ZERO
var stats := {"sent": 0, "received": 0, "bad": 0, "own": 0, "stale": 0, "triggers": 0, "left_presence": 0, "left_timeout": 0}
var rates := {"sent_hz": 0.0, "recv_hz": 0.0, "want_hz": 0.0} # mensajes por segundo (último segundo) y el ritmo elegido ahora
var near_d := 1e9 # m al auto en vivo más cercano
var _others: Dictionary = {} # id → {pos, at}: dónde está cada uno según lo último que mandó (para elegir el ritmo)
var _last_n: Dictionary = {} # id → último número de mensaje (descartar repetidos y desordenados)
var _off: Dictionary = {} # id → desfase entre su reloj y el mío (s), para pasar la hora de sus muestras a mi reloj
var _sent_yaw := 0.0
var _sent_kmh := 0.0
var _rate_t := 0.0
var _rate_sent0 := 0
var _rate_recv0 := 0
var _joined_since := -1.0
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

## Cuántas veces por segundo conviene mandar la posición cuando hay k jugadores en el canal (incluido uno mismo) y el más cercano está a `near` metros.
## Solo en la celda: casi nada. Otros en la celda pero ninguno cerca (no ven mi auto): 1 por s. Con alguien cerca: se reparte el presupuesto de la celda
## (BUDGET entregas/s: cada mensaje llega a k−1), entre 1 y 4 por s; con muchísimos en la celda se acepta bajar a 0,5 (si no, la celda se come el tope de mensajes/s).
static func rate_for(k: int, near := 0.0) -> float:
	if k <= 1:
		return ALONE_HZ
	if near > NT.NEAR_D:
		return NT.SEND_FAR_HZ
	var floor_hz := NT.SEND_MIN_HZ_NEAR if k <= NT.SEND_CROWD else NT.SEND_MIN_HZ_CROWD
	return clampf(BUDGET / float(k * (k - 1)), floor_hz, MAX_HZ)

## «t»: la hora del que manda (ms de su reloj) — el que recibe la pasa a su reloj y así la demora irregular de la red no se ve como tirones (los clientes viejos la ignoran)
static func pack(id: String, x: float, z: float, yaw: float, kmh: float, seq: int, t_ms := -1) -> Dictionary:
	var d := {"i": id, "x": snappedf(x, 0.1), "z": snappedf(z, 0.1), "a": snappedf(yaw, 0.01), "v": int(round(kmh)), "n": seq}
	if t_ms >= 0:
		d["t"] = t_ms
	return d

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
	var out := {"id": str(p["i"]), "x": x, "z": z, "yaw": float(p["a"]), "kmh": maxf(v, 0.0), "n": int(p.get("n", 0))}
	var tt: Variant = p.get("t")
	if (tt is float or tt is int) and float(tt) >= 0.0 and float(tt) < 1e13 and not is_nan(float(tt)):
		out["ts"] = float(tt) / 1000.0
	return out

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
	_send_t = randf() * 0.25 # (que no manden todos en el mismo instante)
	rt.connect_socket()

## Para las pruebas: usar un cliente de Realtime ya armado
func setup_with(p_rt: Node, p_uid: String) -> void:
	rt = p_rt
	uid = p_uid
	rt.broadcast_received.connect(_on_broadcast)
	rt.channel_joined.connect(_on_joined)
	_send_t = randf() * 0.25

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
	_rates(dt)
	var ch := channel_name(cell_of(x, z))
	if not rt.is_joined(ch):
		_joined_since = -1.0
		return
	if _joined_since < 0.0:
		_joined_since = Time.get_ticks_msec() / 1000.0
	var k := maxi(rt.presence_count(ch), _recent_count() + 1)
	near_d = _nearest(Vector2(x, z))
	var moved := Vector2(x, z).distance_to(_sent_pos) > MOVE_EPS
	var hz := rate_for(k, near_d) if moved else IDLE_HZ
	rates["want_hz"] = hz
	_send_t += dt
	var due := _send_t >= 1.0 / hz
	# curvas cerradas y frenadas fuertes: se avisa enseguida (con alguien cerca), así el otro no ve al auto seguir derecho
	if not due and moved and hz >= 1.0 and _send_t >= NT.TRIGGER_MIN_GAP:
		if absf(wrapf(yaw - _sent_yaw, -PI, PI)) > NT.TURN_TRIGGER or absf(kmh - _sent_kmh) > NT.SPEED_TRIGGER:
			due = true
			stats["triggers"] += 1
	if due:
		_send_t = 0.0
		_seq += 1
		if rt.send_broadcast(ch, EVENT, pack(uid, x, z, yaw, kmh, _seq, Time.get_ticks_msec())):
			stats["sent"] += 1
			_sent_pos = Vector2(x, z)
			_sent_yaw = yaw
			_sent_kmh = kmh

## ¿Realtime está andando? (socket abierto y la celda propia unida hace un rato): con esto la lista y la presencia por HTTP se piden más despacio
func healthy() -> bool:
	return rt != null and rt.is_open() and _joined_since >= 0.0 and Time.get_ticks_msec() / 1000.0 - _joined_since > NT.RT_HEALTHY_S

func _nearest(me: Vector2) -> float:
	var now := Time.get_ticks_msec() / 1000.0
	var best := 1e9
	for id in _others:
		var o: Dictionary = _others[id]
		if now - float(o["at"]) < GONE_S:
			best = minf(best, (o["pos"] as Vector2).distance_to(me))
	return best

func _rates(dt: float) -> void:
	_rate_t += dt
	if _rate_t >= 1.0:
		rates["sent_hz"] = float(int(stats["sent"]) - _rate_sent0) / _rate_t
		rates["recv_hz"] = float(int(stats["received"]) - _rate_recv0) / _rate_t
		_rate_sent0 = int(stats["sent"])
		_rate_recv0 = int(stats["received"])
		_rate_t = 0.0

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
	var id := str(st["id"])
	var now := Time.get_ticks_msec() / 1000.0
	# repetido o desordenado (el número de mensaje no avanzó): no sirve. Si el otro reinició el juego el número vuelve a empezar: se acepta tras un silencio o un salto grande hacia atrás
	var n := int(st.get("n", 0))
	if _last_n.has(id) and n <= int(_last_n[id]) and n > int(_last_n[id]) - 1000 and now - float(seen.get(id, -100.0)) < 10.0:
		stats["stale"] += 1
		return
	_last_n[id] = n
	stats["received"] += 1
	# la hora de la muestra en MI reloj: su hora + el desfase más chico visto (el mensaje que menos tardó); el desfase puede crecer despacio (relojes que se corren)
	var t_sample := now
	if st.has("ts"):
		var raw := now - float(st["ts"])
		if not _off.has(id) or now - float(seen.get(id, -100.0)) > 30.0:
			_off[id] = raw
		else:
			_off[id] = minf(float(_off[id]) + 0.01 * (now - float(seen.get(id, now))), raw)
		t_sample = minf(float(st["ts"]) + float(_off[id]), now)
	seen[id] = now
	_others[id] = {"pos": Vector2(float(st["x"]), float(st["z"])), "at": now}
	st["t"] = t_sample
	st["arr"] = now
	car_state.emit(id, st)

## Se fue: no avisó en GONE_S, o la presencia de los canales que escucho ya no lo tiene (cerró el juego, se cortó) y no llegó nada en un rato
func _expire() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var present := {}
	var have_presence := false
	if rt != null:
		for name in rt.channels():
			if str(name).begins_with("world:") and rt.joined_for(str(name)) > 3.0: # (recién unido todavía no llegó la lista de presentes)
				have_presence = true
				for key in rt.presence(str(name)):
					present[str(key)] = true
	for id in seen.keys():
		var age := now - float(seen[id])
		var gone := age > GONE_S
		if not gone and have_presence and not present.has(str(id)) and age > NT.PRESENCE_LEAVE_GRACE:
			gone = true
			stats["left_presence"] += 1
		elif gone:
			stats["left_timeout"] += 1
		if gone:
			seen.erase(id)
			_others.erase(id)
			car_left.emit(str(id))
