extends RefCounted
## Actividades de Dream City en marcha (Etapa 15): radares, contrarreloj de la Ruta Panorámica y encargos. Las reglas (dónde, cuánto paga, medallas) son puras y viven en
## world/world_activities.gd; acá se detecta lo que hace el auto cada cuadro, se dibujan las marcas y se guarda lo logrado en el perfil (offline: profile.d["act"]).
## Online todavía no: los créditos online los dará el servidor (ver docs/ECONOMIA_ONLINE.md), así que con cfg.online no hace nada.

const WA := preload("res://game/world/world_activities.gd")
const WP := preload("res://game/world/world_progress.gd")
const CityProps := preload("res://game/city/city_props.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CityNames := preload("res://game/city/city_names.gd")

const NEAR := 320.0 # los radares y marcas se arman a esta distancia

var race
var city
var world: Node
var active := false
var traps: Array = []
var trial := {}
var sites: Array = []
var label: Label
var _prev := Vector2.ZERO
var _have_prev := false
var _trap_nodes := {}
var _t_acc := 0.0
var _trial_t := -1.0 # >= 0: la contrarreloj está en marcha
var _trial_nodes: Array = []
# encargo
var offer := {}
var del_state := "idle" # idle · pickup · carrying · cooldown
var _del_t := 0.0
var _del_marker: MeshInstance3D
var _cool := 0.0

func setup(p_race, p_city, p_world: Node) -> void:
	race = p_race
	city = p_city
	world = p_world
	if race.profile == null or race.cfg.get("online", false) == true or race.cfg.get("testCar") != null:
		return
	active = true
	traps = WA.traps(city)
	trial = WA.trial(city)
	sites = WA.delivery_sites(city)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 128
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race.race_hud.add_child(label)

func _act() -> Dictionary:
	var d: Dictionary = race.profile.d
	if not d.has("act") or not (d["act"] is Dictionary):
		d["act"] = {}
	var a: Dictionary = d["act"]
	for k in ["traps", "trial"]:
		if not a.has(k):
			a[k] = {}
	return a

## Fama del mundo (profile.d["worldRep"] = {pts, visited: {id: true}}) y su rango
func _rep() -> Dictionary:
	var d: Dictionary = race.profile.d
	if not d.has("worldRep") or not (d["worldRep"] is Dictionary):
		d["worldRep"] = {"pts": 0.0, "visited": {}}
	return d["worldRep"]

func rank() -> int:
	return WP.rank_for(float(_rep()["pts"]))

func add_fame(p: float) -> void:
	var r := _rep()
	var before := WP.rank_for(float(r["pts"]))
	r["pts"] = float(r["pts"]) + p
	var after := WP.rank_for(float(r["pts"]))
	if after > before:
		var bonus := int(WP.RANK_BONUS[after])
		race.profile.earn(float(bonus))
		_toast(Tr.t("🏅 ¡Nuevo rango: %s! +$%d") % [Tr.t(WP.rank_name(after)), bonus], "up")
	race.profile.save()

func _day() -> int:
	return race.world_life.clock.day_index() if race.world_life != null else 0

func _seed() -> int:
	return int(race.world_life.state.world_seed) if race.world_life != null else 20261004

func _toast(s: String, kind := "") -> void:
	race.race_hud.toast(s, kind)

func _pay(n: int) -> void:
	if n <= 0:
		return
	race.profile.earn(float(n))
	race.profile.add_xp(float(n) * 0.2)
	var a := _act()
	a["earned"] = int(a.get("earned", 0)) + n
	race.profile.save()

func update(dt: float) -> void:
	if not active or race.cars.is_empty():
		return
	var ph = race.cars[0].phys
	if ph.px > 3000.0:
		return # bajo tierra
	var pos := Vector2(ph.px, ph.pz)
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	if _have_prev and pos.distance_to(_prev) < 40.0:
		_check_traps(pos, spd)
		_check_trial(pos, dt)
	_prev = pos
	_have_prev = true
	_delivery(pos, spd, dt)
	_fame_tick(pos, dt)
	if _hello > 0.0:
		_hello -= dt
		if _hello <= 0.0:
			var pts := float(_rep()["pts"])
			var nx := WP.to_next(pts)
			_toast(Tr.t("🏅 Rango: %s · %d de fama") % [Tr.t(WP.rank_name(rank())), int(pts)] + ((" · " + Tr.t("faltan %d") % int(nx)) if nx > 0.0 else ""))
	_t_acc += dt
	if _t_acc > 0.5:
		_t_acc = 0.0
		_manage_nodes(pos)
	_label()

# ───────────────────────── fama ─────────────────────────
var _km_acc := 0.0
var _disc_t := 0.0

func _fame_tick(pos: Vector2, dt: float) -> void:
	if _fame_ok and pos.distance_to(_prev_fame) < 60.0:
		_km_acc += pos.distance_to(_prev_fame)
		if _km_acc >= 1000.0:
			_km_acc -= 1000.0
			add_fame(float(WP.PTS["km"]))
	_prev_fame = pos
	_fame_ok = true
	_disc_t += dt
	if _disc_t < 1.0:
		return
	_disc_t = 0.0
	var vis: Dictionary = _rep()["visited"]
	for p in city.pois:
		var id := str(p["id"])
		if vis.has(id):
			continue
		if (p["pos"] as Vector2).distance_to(pos) < 28.0:
			vis[id] = true
			_toast(Tr.t("📍 Descubriste %s · +%d de fama") % [CityNames.t(str(p["name"])), int(WP.PTS["discover"])], "up")
			add_fame(float(WP.PTS["discover"]))
			return

var _prev_fame := Vector2.ZERO
var _fame_ok := false
var _hello := 3.0 # al entrar al mundo se muestra el rango una vez

# ───────────────────────── radares ─────────────────────────
func _check_traps(pos: Vector2, spd: float) -> void:
	for tp in traps:
		if (tp["pos"] as Vector2).distance_squared_to(pos) > 90.0 * 90.0:
			continue
		if WA.crossed(tp, _prev, pos) == 0 or spd < 8.0:
			continue
		var kmh := spd * 3.6
		var rec: Dictionary = (_act()["traps"] as Dictionary).get(str(tp["id"]), {})
		var best := maxf(float(rec.get("best", 0.0)), kmh)
		var pay := WA.trap_reward(kmh)
		var paid_today: bool = int(rec.get("day", -1)) == _day()
		if pay > 0 and not paid_today:
			rec["day"] = _day()
			_pay(pay)
			add_fame(WP.trap_pts(pay))
			_toast("📸 %s: %d km/h · +$%d" % [CityNames.t(str(tp["name"])), roundi(kmh), pay], "up")
		else:
			_toast("📸 %s: %d km/h" % [CityNames.t(str(tp["name"])), roundi(kmh)])
		rec["best"] = best
		(_act()["traps"] as Dictionary)[str(tp["id"])] = rec

# ───────────────────────── contrarreloj ─────────────────────────
func _check_trial(pos: Vector2, dt: float) -> void:
	if trial.is_empty():
		return
	var ls := {"pos": trial["start"], "dir": trial["start_dir"], "half": trial["half"]}
	var lf := {"pos": trial["finish"], "dir": trial["finish_dir"], "half": trial["half"]}
	if _trial_t >= 0.0:
		_trial_t += dt
		if WA.crossed(lf, _prev, pos) > 0:
			_finish_trial()
		elif _trial_t > 900.0:
			_trial_t = -1.0
			_toast(Tr.t("⏱ Contrarreloj cancelada"), "down")
	elif WA.crossed(ls, _prev, pos) > 0:
		_trial_t = 0.0
		_toast(Tr.t("⏱ ¡Contrarreloj Panorámica en marcha!"), "up")

func _finish_trial() -> void:
	var t := _trial_t
	_trial_t = -1.0
	var m := WA.medal(t)
	var rec: Dictionary = (_act()["trial"] as Dictionary)
	var old_m := int(rec.get("medal", 0))
	var pay := WA.trial_reward(m, old_m)
	var best := t if float(rec.get("best", 1e9)) > t else float(rec["best"])
	rec["best"] = best
	rec["medal"] = maxi(m, old_m)
	var names := ["", Tr.t("🥉 bronce"), Tr.t("🥈 plata"), Tr.t("🥇 oro")]
	_pay(pay)
	if m > old_m:
		add_fame(float(WP.PTS["medal"]) * float(m - old_m))
	_toast("⏱ %s · %s%s%s" % [_fmt(t), Tr.t("medalla") + " " + names[m] if m > 0 else Tr.t("sin medalla"), (" · +$%d" % pay) if pay > 0 else "", (" · " + Tr.t("récord") + " " + _fmt(best)) if best >= t - 0.001 and t <= best + 0.001 else ""], "up" if m > 0 else "")

static func _fmt(t: float) -> String:
	return "%d:%04.1f" % [int(t / 60.0), fmod(t, 60.0)]

# ───────────────────────── encargos ─────────────────────────
func _delivery(pos: Vector2, spd: float, dt: float) -> void:
	if sites.size() < 2:
		return
	match del_state:
		"idle":
			var a := _act()
			var seq := int(a.get("seq", 0))
			var best := {}
			var bd := 1e18
			for k in 4: # entre los próximos encargos del mundo, el que arranca más cerca del jugador
				var o := WA.delivery_offer(_seed(), _day(), seq + k, sites)
				if o.is_empty():
					continue
				var d := (sites[int(o["from"])]["pos"] as Vector2).distance_squared_to(pos)
				if d < bd:
					bd = d
					best = o
					best["seq"] = seq + k
			if best.is_empty():
				return
			offer = best
			del_state = "pickup"
			_toast(Tr.t("📦 Encargo: pasá a buscarlo por %s") % CityNames.t(str(sites[int(offer["from"])]["name"])))
			_set_marker(sites[int(offer["from"])]["pos"], Color(0.95, 0.75, 0.15))
			var hud = race.race_hud.city_hud
			if hud != null and not hud.has_dest:
				hud.set_dest(sites[int(offer["from"])]["pos"], CityNames.t(str(sites[int(offer["from"])]["name"])))
		"pickup":
			var sp: Vector2 = sites[int(offer["from"])]["pos"]
			if pos.distance_to(sp) < WA.DELIVERY_RADIUS and spd < 3.5:
				del_state = "carrying"
				_del_t = 0.0
				var tp: Vector2 = sites[int(offer["to"])]["pos"]
				_set_marker(tp, Color(0.2, 0.85, 0.35))
				var hud2 = race.race_hud.city_hud
				if hud2 != null:
					hud2.set_dest(tp, CityNames.t(str(sites[int(offer["to"])]["name"])))
				_toast(Tr.t("📦 Recogido: entregalo en %s (%d s)") % [CityNames.t(str(sites[int(offer["to"])]["name"])), int(offer["deadline"])], "up")
		"carrying":
			_del_t += dt
			var tp2: Vector2 = sites[int(offer["to"])]["pos"]
			if pos.distance_to(tp2) < WA.DELIVERY_RADIUS and spd < 4.0:
				var pay := int(round(float(WA.delivery_pay(offer, _del_t)) * WP.delivery_pay_k(rank())))
				_pay(pay)
				if pay > 0:
					add_fame(float(WP.PTS["delivery"]))
				var a2 := _act()
				a2["seq"] = int(offer["seq"]) + 1
				a2["deliveries"] = int(a2.get("deliveries", 0)) + 1
				_toast((Tr.t("📦 ¡Entregado! +$%d") % pay) if pay > 0 else Tr.t("📦 Llegaste tarde: sin paga"), "up" if pay > 0 else "down")
				_end_delivery()
			elif _del_t > float(offer["deadline"]) * 2.0:
				var a3 := _act()
				a3["seq"] = int(offer["seq"]) + 1
				_toast(Tr.t("📦 Encargo vencido"), "down")
				_end_delivery()
		"cooldown":
			_cool -= dt
			if _cool <= 0.0:
				del_state = "idle"

func _end_delivery() -> void:
	del_state = "cooldown"
	_cool = 20.0
	offer = {}
	if is_instance_valid(_del_marker):
		_del_marker.queue_free()
	_del_marker = null
	var hud = race.race_hud.city_hud
	if hud != null:
		hud.clear_dest()

func _set_marker(p: Vector2, col: Color) -> void:
	if is_instance_valid(_del_marker):
		_del_marker.queue_free()
	_del_marker = world._circle_mesh(WA.DELIVERY_RADIUS - 1.2, WA.DELIVERY_RADIUS, col, Color(0.97, 0.97, 0.97))
	var y: float = float(city.probe(p.x, p.y)[4]) + 0.18
	_del_marker.position = Vector3(p.x, y, p.y)
	world.add_child(_del_marker)

# ───────────────────────── marcas en el mundo ─────────────────────────
func _manage_nodes(pos: Vector2) -> void:
	for tp in traps:
		var id := str(tp["id"])
		var near := (tp["pos"] as Vector2).distance_to(pos) < NEAR
		if near and not _trap_nodes.has(id):
			var n := _trap_node(tp)
			world.add_child(n)
			_trap_nodes[id] = n
		elif not near and _trap_nodes.has(id):
			(_trap_nodes[id] as Node).queue_free()
			_trap_nodes.erase(id)
	if not trial.is_empty():
		var near_t := (trial["start"] as Vector2).distance_to(pos) < NEAR or (trial["finish"] as Vector2).distance_to(pos) < NEAR
		if near_t and _trial_nodes.is_empty():
			_trial_nodes = [_line_node(trial["start"], trial["start_dir"], float(trial["half"]), Color(0.2, 0.9, 0.4)), _line_node(trial["finish"], trial["finish_dir"], float(trial["half"]), Color(0.95, 0.95, 0.95))]
			for n2 in _trial_nodes:
				world.add_child(n2)
		elif not near_t and not _trial_nodes.is_empty():
			for n3 in _trial_nodes:
				(n3 as Node).queue_free()
			_trial_nodes.clear()

func _line_node(p: Vector2, d: Vector2, half: float, col: Color) -> Node3D:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var y := float(city.probe(p.x, p.y)[4])
	var xf := Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), Vector3(p.x, y + 0.13, p.y))
	CityProps.box(v, c, xf, Vector3.ZERO, Vector3(half * 2.0, 0.03, 1.0), col)
	return _mesh_node(v, c)

func _trap_node(tp: Dictionary) -> Node3D:
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var p: Vector2 = tp["pos"]
	var d: Vector2 = tp["dir"]
	var y: float = float(tp["y"])
	var yaw := atan2(d.x, d.y)
	var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y + 0.13, p.y))
	var half := float(tp["half"])
	CityProps.box(v, c, xf, Vector3.ZERO, Vector3(half * 2.0, 0.03, 0.6), Color(1.0, 0.6, 0.1)) # la línea
	# poste con la cámara junto al cordón derecho
	var side := Vector3(half + 0.6, 0, 0)
	CityProps.box(v, c, xf, side + Vector3(0, 1.6, 0), Vector3(0.16, 3.2, 0.16), Color(0.35, 0.37, 0.4))
	CityProps.box(v, c, xf, side + Vector3(0, 3.3, 0), Vector3(0.7, 0.5, 0.6), Color(0.2, 0.22, 0.25))
	CityProps.box(v, c, xf, side + Vector3(-0.25, 3.3, -0.31), Vector3(0.25, 0.25, 0.04), Color(0.95, 0.15, 0.1))
	return _mesh_node(v, c)

func _mesh_node(v: PackedVector3Array, c: PackedColorArray) -> Node3D:
	var m := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.7
	m.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _label() -> void:
	var t := ""
	if _trial_t >= 0.0:
		t = "⏱ %s" % _fmt(_trial_t)
	elif del_state == "carrying":
		var left := float(offer["deadline"]) - _del_t
		t = "📦 %s %d s" % [CityNames.t(str(sites[int(offer["to"])]["name"])), maxi(int(left), 0)]
	if label.text != t:
		label.text = t

func save() -> void:
	pass # (lo logrado se guarda en el momento, con profile.save())
