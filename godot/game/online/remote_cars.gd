extends Node3D
## Los autos de los otros jugadores en el mundo: se piden las posiciones cada ~2 s (presence_list) y cada auto se dibuja como un auto de papel liviano con el apodo arriba.
## Entre una lectura y la otra se estima dónde está (la última posición + rumbo × velocidad) y el auto se acerca suave a ese punto, así se ve fluido aunque lleguen pocos datos.
## Sólo se muestran los más cercanos (hasta MAX_SHOWN, a menos de SHOW_R metros). Sin física compartida: no se chocan.

const PaperKit := preload("res://game/fx/paper_kit.gd")
const CityProps := preload("res://game/city/city_props.gd")

const POLL := 2.0
const SHOW_R := 700.0
const MAX_SHOWN := 12
const LABEL_R := 140.0

var race
var social: Node
var city
var cars: Dictionary = {} # id → {node, label, pos, target, yaw, speed, t, has}
var _t := 0.0
var _busy := false
static var _meshes: Dictionary = {}

func setup(p_race, p_social: Node, p_city) -> void:
	race = p_race
	social = p_social
	city = p_city

static func mesh_for(hue_i: int) -> ArrayMesh:
	if _meshes.has(hue_i):
		return _meshes[hue_i]
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var body := Color.from_hsv(float(hue_i) / 12.0, 0.7, 0.92)
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
			(cars[id]["node"] as Node3D).queue_free()
			cars.erase(id)

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
