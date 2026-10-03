extends RefCounted
## Entrar a los locales de Dream City: frente a cada uno hay un círculo verde. Si frenás encima, el auto queda derecho frente al portón, el portón se abre, el auto entra solo,
## la pantalla se funde a negro y se abre el menú de ese taller (o el concesionario). Al salir del menú volvés a la calle, en el mismo lugar.

const Tr := preload("res://game/i18n/tr.gd")
const Shops := preload("res://game/data/shops.gd")
const BayDriver := preload("res://game/ai/bay_driver.gd")

const R_IN := 3.4 # radio del círculo (m)
const R_OUT := 7.5 # hay que alejarse tanto para que el círculo vuelva a estar activo

var race
var world
var city
var st := {} # id del local -> {armed, hold, open}
var active := ""
var phase := ""
var t := 0.0
var fade := 0.0
var _driver
var _dist_in := 0.0

func setup(p_race, p_world, p_city) -> void:
	race = p_race
	world = p_world
	city = p_city
	for p in city.pois:
		if str(p["shop"]) != "":
			st[str(p["id"])] = {"armed": false, "hold": 0.0, "open": 0.0}
	if race.cfg.has("resume"):
		pass # al volver de un taller el auto ya está sobre el círculo: no se activa hasta que se aleje

func _node(p: Dictionary) -> Node3D:
	var k: Vector2i = city.chunk_of(float((p["pos"] as Vector2).x), float((p["pos"] as Vector2).y))
	if not world.chunks.has(k):
		return null
	return (world.chunks[k] as Node3D).get_node_or_null("shop_" + str(p["id"]))

func update(dt: float) -> void:
	if race.cars.is_empty():
		return
	var ph = race.cars[0].phys
	var pos := Vector2(ph.px, ph.pz)
	var spd := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	for p in city.pois:
		var id := str(p["id"])
		if not st.has(id):
			continue
		var s: Dictionary = st[id]
		var front: Vector2 = p["front"]
		var d := pos.distance_to(front)
		var nd := _node(p)
		if active != id:
			# el portón se cierra solo y el círculo respira
			s["open"] = move_toward(float(s["open"]), 0.0, dt * 1.5)
			if d > R_OUT:
				s["armed"] = true
		if nd != null:
			var door := nd.get_node_or_null("door")
			if door != null:
				(door as Node3D).scale.y = lerpf(1.0, 0.04, smoothstep(0.0, 1.0, float(s["open"])))
			var circle := nd.get_node_or_null("circle")
			if circle != null:
				var pulse := 1.0 + 0.05 * sin(float(Time.get_ticks_msec()) * 0.005)
				(circle as Node3D).scale = Vector3(pulse, 1.0, pulse)
		if active == "" and bool(s["armed"]) and d < R_IN and spd < 2.2:
			s["hold"] = float(s["hold"]) + dt
			if float(s["hold"]) > 0.45:
				_begin(id, p)
		elif active == "":
			s["hold"] = 0.0
	if active != "":
		_run(dt)

func _begin(id: String, p: Dictionary) -> void:
	active = id
	phase = "opening"
	t = 0.0
	var front: Vector2 = p["front"]
	var dir: Vector2 = p["dir"]
	race.cars[0].place(front.x, front.y, atan2(dir.x, dir.y)) # derecho frente al portón
	_driver = BayDriver.new()
	race.cars[0].driver = _driver
	_dist_in = (p["door"] as Vector2).distance_to(front) + 4.0
	race.race_hud.toast(Tr.t("Abriendo %s…") % Tr.t(str(p["name"])))

func _run(dt: float) -> void:
	t += dt
	var p: Dictionary = {}
	for q in city.pois:
		if str(q["id"]) == active:
			p = q
	var s: Dictionary = st[active]
	if phase == "opening":
		s["open"] = clampf(t / 0.9, 0.0, 1.0)
		if t >= 0.9:
			phase = "entering"
			_driver.go = true
			t = 0.0
	elif phase == "entering":
		var ph = race.cars[0].phys
		var gone := Vector2(ph.px, ph.pz).distance_to(p["front"])
		if gone > _dist_in or t > 2.6:
			phase = "fading"
			t = 0.0
	elif phase == "fading":
		fade = clampf(t / 0.45, 0.0, 1.0)
		if race.race_hud.city_hud != null:
			race.race_hud.city_hud.set_fade(fade)
		if fade >= 1.0:
			phase = "gone"
			var front: Vector2 = p["front"]
			race.enter_shop(str(p["shop"]), [front.x, front.y, float(p["road_yaw"])])
