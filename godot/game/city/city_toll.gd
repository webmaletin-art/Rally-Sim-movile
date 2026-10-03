extends RefCounted
## Peajes de las rutas rurales de Dream City. Cada peaje tiene dos carriles con barrera. Una barrera cerrada es sólida (círculos que se suman a los de los objetos de la calle);
## si frenás en un carril (menos de ~30 km/h) se cobra el peaje, la barrera se levanta y pasás. Para volver a la ciudad las barreras se abren solas y no se cobra.
## Con un «pase de carga rápida» (se gana cargando en la Carga Rápida Central) el peaje cuesta la mitad.

const Tr := preload("res://game/i18n/tr.gd")
const Release := preload("res://game/data/release.gd")

const ID_BASE := 900000 # ids de los círculos sólidos (fuera del rango de los objetos de la calle: no se rompen)
const LANE_X := 2.85 # centro de cada carril respecto del eje de la ruta
const SLOW := 8.5 # m/s (≈ 30 km/h): hay que ir despacio para que cobre
const ZONE_BEFORE := 22.0 # el cobro empieza a esta distancia antes de la barrera
const PASS_DISCOUNT := 0.5

var race
var city
var track
var world
var st := {} # id del peaje -> {open: [0..1, 0..1], want: [bool, bool], solid: [bool, bool], paid: bool}
var _warn_t := 0.0

func setup(p_race, p_world, p_city) -> void:
	race = p_race
	world = p_world
	city = p_city
	track = p_world.track
	for i in city.tolls.size():
		var t: Dictionary = city.tolls[i]
		st[str(t["id"])] = {"open": [0.0, 0.0], "want": [false, false], "solid": [false, false], "paid": false}
		# isla central: siempre sólida (tres círculos a lo largo de la cabina)
		for k in 3:
			var q := _wp(t, 0.0, -3.4 + 3.4 * float(k))
			track.add_prop(_id(i, k), q.x, q.y, 1.15)
		for lane in 2:
			_set_solid(i, lane, true)

func _id(i: int, k: int) -> int:
	return ID_BASE + i * 20 + k

## punto del marco del peaje (x: a la derecha de la marcha hacia afuera, z: hacia afuera) en el mundo
func _wp(t: Dictionary, x: float, z: float) -> Vector2:
	var tn: Vector2 = t["tn"]
	var rt := Vector2(tn.y, -tn.x) # el eje x local (ver CityWorld._toll)
	return (t["pos"] as Vector2) + rt * x + tn * z

func _set_solid(i: int, lane: int, on: bool) -> void:
	var t: Dictionary = city.tolls[i]
	var s: Dictionary = st[str(t["id"])]
	if bool((s["solid"] as Array)[lane]) == on:
		return
	(s["solid"] as Array)[lane] = on
	var sg := 1.0 if lane == 0 else -1.0
	for k in 3:
		var q := _wp(t, sg * (LANE_X + (float(k) - 1.0) * 1.15), 3.2)
		var id := _id(i, 3 + lane * 3 + k)
		if on:
			track.add_prop(id, q.x, q.y, 0.95)
		else:
			track.remove_prop(id, q.x, q.y)

func _node(t: Dictionary) -> Node3D:
	var pos: Vector2 = t["pos"]
	var k: Vector2i = city.chunk_of(pos.x, pos.y)
	if not world.chunks.has(k):
		return null
	return (world.chunks[k] as Node3D).get_node_or_null("toll_" + str(t["id"]))

func _price(t: Dictionary) -> int:
	var p := int(t["price"])
	if int(race.profile.d.get("toll_pass", 0)) > 0:
		p = int(round(float(p) * PASS_DISCOUNT))
	return p

func update(dt: float) -> void:
	if race.cars.is_empty():
		return
	_warn_t = maxf(0.0, _warn_t - dt)
	var ph = race.cars[0].phys
	var pos := Vector2(ph.px, ph.pz)
	var vel := Vector2(ph.vx, ph.vz)
	var spd := vel.length()
	for i in city.tolls.size():
		var t: Dictionary = city.tolls[i]
		var s: Dictionary = st[str(t["id"])]
		var tp: Vector2 = t["pos"]
		var d := pos - tp
		if d.length_squared() > 90.0 * 90.0:
			# lejos: todo cerrado y listo para cobrar de nuevo
			s["paid"] = false
			(s["want"] as Array)[0] = false
			(s["want"] as Array)[1] = false
		else:
			var tn: Vector2 = t["tn"]
			var along := d.dot(tn) # + = ya pasó el peaje (hacia afuera)
			var lat := d.dot(Vector2(tn.y, -tn.x)) # + = carril derecho
			var inward := vel.dot(tn) < -1.0 and along > -2.0 # volviendo a la ciudad: pasa libre
			var lane := 0 if lat >= 0.0 else 1
			if inward and along < 30.0:
				(s["want"] as Array)[0] = true
				(s["want"] as Array)[1] = true
			elif along > -ZONE_BEFORE and along < 1.5 and absf(lat) < float(t["hw"]) + 1.0:
				if not bool(s["paid"]) and spd < SLOW:
					_try_pay(t, s, lane)
			if along > 28.0 or along < -45.0:
				s["paid"] = false
				(s["want"] as Array)[0] = false
				(s["want"] as Array)[1] = false
		for lane2 in 2:
			var want: bool = bool((s["want"] as Array)[lane2])
			_set_solid(i, lane2, not (float((s["open"] as Array)[lane2]) > 0.5 or want))
			(s["open"] as Array)[lane2] = move_toward(float((s["open"] as Array)[lane2]), 1.0 if want else 0.0, dt * 2.5)
		var nd := _node(t)
		if nd != null:
			var fr := nd.get_node_or_null("frame")
			if fr != null:
				for lane3 in 2:
					var arm := fr.get_node_or_null("arm%d" % lane3)
					if arm != null:
						var sg := 1.0 if lane3 == 0 else -1.0
						(arm as Node3D).rotation.z = sg * 1.45 * smoothstep(0.0, 1.0, float((s["open"] as Array)[lane3]))

func _try_pay(t: Dictionary, s: Dictionary, lane: int) -> void:
	var free := Release.dev(race.profile)
	var price := 0 if free else _price(t)
	if price > 0 and race.profile.credits < price:
		if _warn_t <= 0.0:
			_warn_t = 3.0
			race.race_hud.toast(Tr.t("🛣 No te alcanzan los créditos para el peaje"), "down")
		return
	if price > 0:
		race.profile.spend(price)
		var left := int(race.profile.d.get("toll_pass", 0))
		if left > 0:
			race.profile.d["toll_pass"] = left - 1
			race.profile.save()
			race.race_hud.toast(Tr.t("🛣 Peaje con pase de carga rápida: %d créditos (te quedan %d)") % [price, left - 1], "up")
		else:
			race.race_hud.toast(Tr.t("🛣 Peaje: %d créditos") % price)
	else:
		race.race_hud.toast(Tr.t("🛣 Peaje: pasás gratis"))
	s["paid"] = true
	(s["want"] as Array)[lane] = true
