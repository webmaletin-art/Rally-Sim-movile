extends RefCounted
## Las bocas de los túneles y del estacionamiento: cuando el auto llega a una, la pantalla se funde a negro y el auto aparece en el otro extremo (el túnel y la sala están en otra
## parte del mundo, un «bolsillo»). La velocidad se conserva. Lo que no se ve en el mapa son justamente estas bocas: hay que descubrirlas.

var race
var world
var city
var cooldown := 1.0
var phase := ""
var t := 0.0
var cur: Dictionary = {}

func setup(p_race, p_world, p_city) -> void:
	race = p_race
	world = p_world
	city = p_city

func _hud():
	return race.race_hud.city_hud

func update(dt: float) -> void:
	if race.cars.is_empty():
		return
	if phase == "out":
		t += dt
		if _hud() != null:
			_hud().set_fade(clampf(t / 0.3, 0.0, 1.0))
		if t >= 0.3:
			_teleport()
			phase = "in"
			t = 0.0
	elif phase == "in":
		t += dt
		if _hud() != null:
			_hud().set_fade(clampf(1.0 - t / 0.4, 0.0, 1.0))
		if t >= 0.4:
			phase = ""
			if _hud() != null:
				_hud().set_fade(0.0)
	else:
		cooldown -= dt
		if cooldown > 0.0 or (race.shops != null and race.shops.active != ""):
			return
		var ph = race.cars[0].phys
		var pos := Vector2(ph.px, ph.pz)
		for l in city.links:
			if pos.distance_to(l["pos"]) < float(l["r"]):
				cur = l
				phase = "out"
				t = 0.0
				return

func _teleport() -> void:
	var to: Array = cur["to"]
	var ph = race.cars[0].phys
	var v := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
	world.warm(Vector3(float(to[0]), 0.0, float(to[1]))) # las cuadras de allá, armadas mientras la pantalla está negra
	race.cars[0].place(float(to[0]), float(to[1]), float(to[2]))
	ph.vx = sin(float(to[2])) * v
	ph.vz = cos(float(to[2])) * v
	ph.vLong = v
	cooldown = 1.5
	race.on_teleport()
