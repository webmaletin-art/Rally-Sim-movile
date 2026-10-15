extends Node3D
## Policía compartida del mundo online (15/10/2026, pedido del dueño: «que la policía sea la misma para todos»). Cada teléfono maneja a SUS patrulleros (city_police.gd:
## los que lo persiguen a él) y, mientras hay otros jugadores en su celda de 2 km, manda dónde están por el mismo canal de Realtime de las posiciones (world_sync.gd),
## evento «p», 2 veces por segundo y SÓLO durante una persecución (solo, o sin persecución, no manda nada: no carga el servidor). Los demás los dibujan como
## patrulleros con balizas que se mueven suave (remote_motion.gd). Así un grupo ve a todos los patrulleros que lo persiguen (2 por jugador fuerte, 1 por los demás).
## Igual que las posiciones, NO es autoritativo: sólo se dibujan autos (sin choques compartidos) y se descarta lo imposible.

const CarVisual := preload("res://game/car/car_visual.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const Profile := preload("res://game/data/profile.gd")
const RemoteMotion := preload("res://game/online/remote_motion.gd")

const EVENT := "p"
const HZ := 2.0
const MAX_U := 6
const GONE_S := 3.0 # sin noticias de un patrullero en tanto tiempo: se borra
const SHOW_R := 700.0
const MAX_COORD := 400000.0
const VID := "police"

var race
var sync: Node # world_sync.gd
var ghosts: Dictionary = {} # "uid:k" → {vis, motion, t, lights}
var stats := {"sent": 0, "received": 0, "bad": 0}
var _t := 0.0
var _seq := 0
var _was := false
var _flash := 0.0
var _snap := CarSnapshot.new()

func setup(p_race, p_sync: Node) -> void:
	race = p_race
	sync = p_sync
	if sync != null and sync.rt != null:
		sync.rt.broadcast_received.connect(_on_broadcast)

# ───────────────────────── reglas (puras, se prueban sin red) ─────────────────────────
## units: [[x, z, yaw, km/h], …]
static func pack(id: String, units: Array, seq: int) -> Dictionary:
	var u: Array = []
	for k in mini(units.size(), MAX_U):
		var q: Array = units[k]
		u.append([snappedf(float(q[0]), 0.1), snappedf(float(q[1]), 0.1), snappedf(float(q[2]), 0.01), int(round(float(q[3])))])
	return {"i": id, "u": u, "n": seq}

## Devuelve {id, units} o {} si el mensaje no sirve
static func unpack(p: Dictionary) -> Dictionary:
	if not (p.get("i") is String) or str(p["i"]).length() < 8 or str(p["i"]).length() > 64 or not (p.get("u") is Array):
		return {}
	var arr: Array = p["u"]
	if arr.size() > MAX_U:
		return {}
	var out: Array = []
	for q in arr:
		if not (q is Array) or (q as Array).size() != 4:
			return {}
		for v in q:
			if not (v is float or v is int) or is_nan(float(v)) or is_inf(float(v)):
				return {}
		if absf(float(q[0])) > MAX_COORD or absf(float(q[1])) > MAX_COORD or absf(float(q[2])) > 20.0 or float(q[3]) < -20.0 or float(q[3]) > 500.0:
			return {}
		out.append([float(q[0]), float(q[1]), float(q[2]), maxf(float(q[3]), 0.0)])
	return {"id": str(p["i"]), "units": out}

# ───────────────────────── uso ─────────────────────────
func _process(dt: float) -> void:
	_send(dt)
	_step(dt)

func _send(dt: float) -> void:
	var pol = race.get("police")
	if pol == null or sync == null or sync.rt == null or race.cars.is_empty():
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0 / HZ
	var me = race.cars[0].phys
	var ch: String = sync.channel_name(sync.cell_of(me.px, me.pz))
	if not sync.rt.is_joined(ch):
		return
	var others: bool = sync.rt.presence_count(ch) > 1 or sync._recent_count() > 0
	var chasing: bool = str(pol.state) == "chase" and not (pol.units as Array).is_empty()
	if chasing and others:
		var u: Array = []
		for un in pol.units:
			var ph = un["car"].phys
			u.append([ph.px, ph.pz, ph.yaw, sqrt(ph.vx * ph.vx + ph.vz * ph.vz) * 3.6])
		_seq += 1
		if sync.rt.send_broadcast(ch, EVENT, pack(sync.uid, u, _seq)):
			stats["sent"] += 1
			_was = true
	elif _was:
		_was = false # terminó la persecución: un último mensaje vacío para que los demás los borren enseguida
		_seq += 1
		if sync.rt.send_broadcast(ch, EVENT, pack(sync.uid, [], _seq)):
			stats["sent"] += 1

func _on_broadcast(channel: String, event: String, payload: Dictionary) -> void:
	if event != EVENT or not channel.begins_with("world:"):
		return
	var st := unpack(payload)
	if st.is_empty():
		stats["bad"] += 1
		return
	if str(st["id"]) == str(sync.uid):
		return
	stats["received"] += 1
	apply(str(st["id"]), st["units"])

## Los patrulleros que persiguen al jugador `id` (lista vacía: terminó la persecución)
func apply(id: String, units: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for k in MAX_U:
		var key := "%s:%d" % [id, k]
		if k >= units.size():
			if ghosts.has(key):
				_drop(key)
			continue
		var q: Array = units[k]
		if not ghosts.has(key):
			ghosts[key] = {"vis": null, "motion": RemoteMotion.new(), "t": now, "lights": []}
		var g: Dictionary = ghosts[key]
		g["t"] = now
		(g["motion"] as RefCounted).push_sample(Vector2(float(q[0]), float(q[1])), float(q[2]), float(q[3]) / 3.6, now)

func _drop(key: String) -> void:
	var g: Dictionary = ghosts[key]
	if g["vis"] != null and is_instance_valid(g["vis"]):
		(g["vis"] as Node).queue_free()
	ghosts.erase(key)

func _step(dt: float) -> void:
	if ghosts.is_empty() or race.cars.is_empty():
		return
	_flash += dt
	var now := Time.get_ticks_msec() / 1000.0
	var me := Vector2(race.cars[0].phys.px, race.cars[0].phys.pz)
	var city = race.track.city if race.track != null and race.track.get("city") != null else null
	var built := false
	for key in ghosts.keys():
		var g: Dictionary = ghosts[key]
		if now - float(g["t"]) > GONE_S:
			_drop(key)
			continue
		var m = g["motion"]
		m.step(now, dt)
		var p: Vector2 = m.pos
		var near := p.distance_to(me) < SHOW_R
		if g["vis"] == null and near and not built:
			g["vis"] = _build()
			built = true # (uno por cuadro: armar un auto cuesta)
			if g["vis"] != null:
				add_child(g["vis"])
				g["lights"] = _lights_for(g["vis"])
		var vis: Variant = g["vis"]
		if vis == null or not is_instance_valid(vis):
			continue
		(vis as Node3D).visible = near
		if not near:
			continue
		var y := 0.0
		if city != null:
			var pr: Array = city.probe(p.x, p.y)
			y = float(pr[4]) if float(pr[0]) >= -1.0 else city.height(p.x, p.y)
		_snap.px = p.x
		_snap.py = y + float(vis.V.comHeight)
		_snap.pz = p.y
		_snap.yaw = m.yaw
		_snap.pitch = m.pitch
		_snap.roll = m.roll
		_snap.steerAngle = m.steer
		var w: float = m.wheel_omega(float(vis.V.wheelRadius))
		_snap.wheel_omega = PackedFloat64Array([w, w, w, w])
		vis.sync_from(_snap, dt)
		var on := int(_flash / 0.18) % 2 == 0
		var l: Array = g["lights"]
		for k in l.size():
			if is_instance_valid(l[k]):
				(l[k] as Node3D).visible = on == (k == 0)

func _build() -> Node3D:
	if not race.vehicles.has(VID):
		return null
	var st: Dictionary = Profile.new_car_state(VID)
	var d: Dictionary = CarBuild.build_params(race.vehicles[VID], st)
	var vis := CarVisual.new()
	vis.setup(VehicleParams.from_dict(d), true, Color(0.95, 0.95, 0.95), Color(0.16, 0.17, 0.19), "gloss")
	return vis

## Balizas (roja y azul) sobre el techo, como los patrulleros propios (city_police.gd)
func _lights_for(vis: Node3D) -> Array:
	var out: Array = []
	var body: Node3D = vis.get("body")
	if body == null:
		return out
	var h := 1.42
	var meta: Variant = vis.get("meta")
	if meta is Dictionary and (meta as Dictionary).has("H"):
		h = float(meta["H"]) + 0.02
	for k in 2:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.11
		sm.height = 0.16
		sm.radial_segments = 8
		sm.rings = 4
		mi.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.12, 0.1) if k == 0 else Color(0.15, 0.35, 1.0)
		mi.material_override = mat
		mi.position = Vector3(-0.32 if k == 0 else 0.32, h, -0.15)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mi)
		out.append(mi)
	return out
