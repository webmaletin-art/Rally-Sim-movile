extends Node3D
## Los autos de los otros jugadores en el mundo: se piden las posiciones cada ~2 s (presence_list) y cada auto se dibuja como un auto de papel liviano con el apodo arriba.
## Entre una lectura y la otra se estima dónde está (la última posición + rumbo × velocidad) y el auto se acerca suave a ese punto, así se ve fluido aunque lleguen pocos datos.
## Sólo se muestran los más cercanos (hasta MAX_SHOWN, a menos de SHOW_R metros). Sin física compartida: no se chocan.

const PaperKit := preload("res://game/fx/paper_kit.gd")
const CityProps := preload("res://game/city/city_props.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const CarSnapshot := preload("res://game/car/car_snapshot.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const Profile := preload("res://game/data/profile.gd")

const POLL := 2.0
const SHOW_R := 700.0
const MAX_SHOWN := 12
const LABEL_R := 140.0
const REAL_R := 80.0 # los más cercanos se dibujan con su modelo real (pintura, llantas y piezas que el SERVIDOR sabe que tiene); el resto, de papel con su color
const REAL_MAX := 3

var race
var social: Node
var city
var cars: Dictionary = {} # id → {node, label, pos, target, yaw, speed, t, has}
var _t := 0.0
var _busy := false
static var _meshes: Dictionary = {}
var _snap := CarSnapshot.new()

func setup(p_race, p_social: Node, p_city) -> void:
	race = p_race
	social = p_social
	city = p_city

static func mesh_for(hue_i: int) -> ArrayMesh:
	return mesh_color(Color.from_hsv(float(hue_i) / 12.0, 0.7, 0.92))

## Auto de papel del color de la pintura (se guardan unos pocos distintos)
static func mesh_color(body: Color) -> ArrayMesh:
	var hue_i := body.to_html(false)
	if _meshes.has(hue_i):
		return _meshes[hue_i]
	if _meshes.size() > 40:
		_meshes.clear()
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var xf := Transform3D.IDENTITY
	CityProps.box(v, c, xf, Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.3), body)
	CityProps.box(v, c, xf, Vector3(0, 1.1, -0.2), Vector3(1.55, 0.5, 2.3), Color(0.18, 0.24, 0.32))
	CityProps.box(v, c, xf, Vector3(0, 1.38, -0.2), Vector3(1.5, 0.08, 2.1), body.darkened(0.1))
	CityProps.box(v, c, xf, Vector3(0, 0.6, 2.16), Vector3(1.5, 0.2, 0.06), Color(1.0, 0.95, 0.7)) # faros
	for wx in [-0.92, 0.92]:
		for wz in [-1.4, 1.4]:
			CityProps.box(v, c, xf, Vector3(float(wx), 0.32, float(wz)), Vector3(0.22, 0.64, 0.64), Color(0.10, 0.10, 0.12))
	var m := ArrayMesh.new()
	PaperKit.add_surface(m, v, c, PaperKit.material(null, 0.0, 0.2, 0.3))
	_meshes[hue_i] = m
	return m

func _process(dt: float) -> void:
	if social == null or not social.active or race.cars.is_empty():
		return
	_t -= dt
	if _t <= 0.0 and not _busy:
		_t = POLL
		_poll()
	var ph = race.cars[0].phys
	var me := Vector2(ph.px, ph.pz)
	var now := Time.get_ticks_msec() / 1000.0
	for id in cars:
		var c: Dictionary = cars[id]
		if not bool(c["has"]):
			continue
		var dir := Vector2(sin(float(c["yaw"])), cos(float(c["yaw"])))
		var age := minf(now - float(c["t"]), 3.0)
		var want: Vector2 = (c["target"] as Vector2) + dir * float(c["speed"]) * age
		var p: Vector2 = (c["pos"] as Vector2).lerp(want, 1.0 - exp(-6.0 * dt))
		c["pos"] = p
		var n: Node3D = c["node"]
		var pr: Array = city.probe(p.x, p.y)
		var y: float = float(pr[4]) if float(pr[0]) >= -1.0 else city.height(p.x, p.y)
		n.position = Vector3(p.x, y, p.y)
		n.rotation.y = lerp_angle(n.rotation.y, float(c["yaw"]), 1.0 - exp(-8.0 * dt))
		(c["label"] as Label3D).visible = p.distance_to(me) < LABEL_R
		var real: Variant = c.get("real")
		if real != null and is_instance_valid(real):
			var vis: Node3D = real
			_snap.px = p.x
			_snap.py = y + float(vis.V.comHeight)
			_snap.pz = p.y
			_snap.yaw = n.rotation.y
			var w: float = float(c["speed"]) / maxf(0.2, float(vis.V.wheelRadius))
			_snap.wheel_omega = PackedFloat64Array([w, w, w, w])
			vis.sync_from(_snap, dt)

func _poll() -> void:
	_busy = true
	var list: Array = await social.players()
	_busy = false
	if not is_inside_tree():
		return
	var ph = race.cars[0].phys
	var me := Vector2(ph.px, ph.pz)
	var near: Array = []
	for p in list:
		if bool(p.get("is_me", false)):
			continue
		var pos := Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0)))
		if (pos.x > 3000.0) != (me.x > 3000.0):
			continue # uno está en el estacionamiento/túnel (el bolsillo) y el otro no: no se ven
		var d := pos.distance_to(me)
		if d < SHOW_R:
			near.append([d, p, pos])
	near.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	var keep := {}
	for k in mini(near.size(), MAX_SHOWN):
		var p: Dictionary = near[k][1]
		var pos: Vector2 = near[k][2]
		var id := str(p.get("player_id", ""))
		keep[id] = true
		_update_car(id, p, pos)
	for id in cars.keys():
		if not keep.has(id):
			_drop_real(cars[id])
			(cars[id]["node"] as Node3D).queue_free()
			cars.erase(id)
	_update_real(me)

func _update_car(id: String, p: Dictionary, pos: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not cars.has(id):
		var n := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_for(absi(hash(id)) % 12)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
		var lab := Label3D.new()
		lab.text = str(p.get("name", "?"))
		lab.font_size = 56
		lab.pixel_size = 0.012
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.outline_size = 12
		lab.outline_modulate = Color(0.05, 0.1, 0.2)
		lab.modulate = Color(1.0, 0.9, 0.5) if bool(p.get("is_friend", false)) else Color.WHITE
		lab.position = Vector3(0, 2.6, 0)
		n.add_child(lab)
		add_child(n)
		n.position = Vector3(pos.x, 0.0, pos.y)
		cars[id] = {"node": n, "label": lab, "pos": pos, "target": pos, "yaw": 0.0, "speed": 0.0, "t": now, "has": true}
	var c: Dictionary = cars[id]
	var old: Vector2 = c["target"]
	if pos.distance_to(old) > 0.6:
		c["yaw"] = atan2(pos.x - old.x, pos.y - old.y)
	if pos.distance_to(c["pos"]) > 60.0:
		c["pos"] = pos # salto grande: se corta en seco en vez de deslizarse por todo el mapa
	c["target"] = pos
	c["speed"] = float(p.get("speed", 0.0)) / 3.6
	c["t"] = now
	(c["label"] as Label3D).text = str(p.get("name", "?"))
	var veh: Variant = p.get("vehicle")
	c["veh"] = veh if veh is Dictionary else {}
	var body_col := Color.from_hsv(float(absi(hash(id)) % 12) / 12.0, 0.7, 0.92)
	if veh is Dictionary and ((veh as Dictionary).get("paint") is Dictionary) and str(((veh as Dictionary)["paint"] as Dictionary).get("body", "")) != "":
		body_col = Color(str(((veh as Dictionary)["paint"] as Dictionary)["body"]))
	if c.get("col") != body_col:
		c["col"] = body_col
		((c["node"] as Node3D).get_child(0) as MeshInstance3D).mesh = mesh_color(body_col)


## Los REAL_MAX autos más cercanos (a menos de REAL_R) con datos del servidor se dibujan con su modelo; se arma uno por vez para no trabar
func _update_real(me: Vector2) -> void:
	var cand: Array = []
	for id in cars:
		var c: Dictionary = cars[id]
		var d: float = (c["pos"] as Vector2).distance_to(me)
		if d < REAL_R and not (c["veh"] as Dictionary).is_empty():
			cand.append([d, id])
	cand.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	var want := {}
	for k in mini(cand.size(), REAL_MAX):
		want[cand[k][1]] = true
	var built := false
	for id in cars:
		var c: Dictionary = cars[id]
		var has: bool = c.get("real") != null and is_instance_valid(c.get("real"))
		if want.has(id) and not has and not built:
			var vis: Node3D = _build_real(c["veh"] as Dictionary)
			if vis != null:
				add_child(vis)
				c["real"] = vis
				((c["node"] as Node3D).get_child(0) as MeshInstance3D).visible = false
				built = true
		elif not want.has(id) and has:
			_drop_real(c)

func _drop_real(c: Dictionary) -> void:
	var r: Variant = c.get("real")
	if r != null and is_instance_valid(r):
		(r as Node).queue_free()
	c["real"] = null
	if c.has("node") and is_instance_valid(c["node"]):
		((c["node"] as Node3D).get_child(0) as MeshInstance3D).visible = true

## El auto tal como lo conoce el servidor: modelo, pintura, gomas y piezas puestas (llantas, alerones…). Si el modelo no existe en esta versión, queda el de papel.
func _build_real(veh: Dictionary) -> Node3D:
	var vid := str(veh.get("vehicle", ""))
	if not race.vehicles.has(vid) or not (CarBuild.catalog()["cars"] as Dictionary).has(vid):
		return null
	var st: Dictionary = Profile.new_car_state(vid)
	var pp: Dictionary = st["paint"]
	for k in (veh.get("paint", {}) as Dictionary):
		pp[k] = (veh["paint"] as Dictionary)[k]
	st["tires"] = str(veh.get("tires", "street"))
	st["mods"] = (veh.get("mods", {}) as Dictionary).duplicate(true)
	var d: Dictionary = CarBuild.build_params(race.vehicles[vid], st)
	var vis := CarVisual.new()
	vis.mods = st["mods"]
	vis.setup(VehicleParams.from_dict(d), true, Color(str(pp.get("body", "#1a4fe0"))), Color(str(pp.get("rim", "#2a2d33"))), str(pp.get("finish", "gloss")))
	if int(pp.get("livery", 0)) > 0:
		vis.set_livery(int(pp["livery"]), Color(str(pp["body"])), Color(str(pp.get("accent", "#ff6a08"))), str(pp.get("finish", "gloss")))
	if pp.has("tire"):
		vis.set_tire_color(Color(str(pp["tire"])))
	vis.set_parts(pp)
	return vis
