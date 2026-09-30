extends RefCounted
## Autos de los rivales (aiCarsFor de js/main.js): del mismo nivel que el evento (índice de rendimiento), con piezas al azar.

const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

const NAMES := ["M. Kovac", "L. Ferreyra", "S. Okafor", "T. Nakamura", "R. Álvarez", "J. Lindqvist", "C. Duarte", "A. Moreau", "P. Rossi", "K. Bauer", "D. Sosa", "E. Varga"]
const CATS := ["engine", "turbo", "weight", "brakes", "suspension", "gearbox", "diff", "aero"]
const ASSISTS := {"abs": true, "tc": 50.0, "stab": 40.0}

## Devuelve n elementos {id, state}. vehicles: vehicles.json; only: auto obligatorio ("" = cualquiera salvo el camión)
static func pick(vehicles: Dictionary, n: int, max_pi: int, only: String, surface: String, rng: RandomNumberGenerator) -> Array:
	var cat := CarBuild.catalog()
	var pool: Array = []
	if only != "":
		pool.append(only)
	else:
		for id in cat["order"]:
			if id == "truck" or not vehicles.has(id):
				continue
			var st := Profile.new_car_state(id)
			if int(CarBuild.perf_of(CarBuild.build_params(vehicles[id], st, ASSISTS))["pi"]) <= max_pi + 30:
				pool.append(id)
		if pool.is_empty():
			pool.append("pickup")
	var out: Array = []
	var paints: Array = cat["paints"]
	for i in n:
		var id: String = pool[i % pool.size()]
		var st := Profile.new_car_state(id)
		st["tires"] = "sport" if surface == "asphalt" else "gravel"
		var target := minf(max_pi, 999) - 30 - rng.randf() * 45.0
		var guard := 0
		while guard < 40:
			guard += 1
			if int(CarBuild.perf_of(CarBuild.build_params(vehicles[id], st, ASSISTS))["pi"]) >= target:
				break
			var c: String = CATS[rng.randi() % CATS.size()]
			var u := CarBuild.upgrade(c)
			if int(st["upg"].get(c, 0)) < (u["levels"] as Array).size() - 1:
				st["upg"][c] = int(st["upg"].get(c, 0)) + 1
		while int(CarBuild.perf_of(CarBuild.build_params(vehicles[id], st, ASSISTS))["pi"]) > max_pi:
			var found := ""
			for c in CATS:
				if int(st["upg"].get(c, 0)) > 0:
					found = c
					break
			if found == "":
				break
			st["upg"][found] = int(st["upg"][found]) - 1
		st["paint"] = {"body": paints[(i * 7 + 3) % paints.size()], "accent": paints[(i * 5 + 11) % paints.size()], "rim": "#2a2d33", "finish": ["gloss", "metal", "matte"][i % 3]}
		out.append({"id": id, "state": st})
	return out
