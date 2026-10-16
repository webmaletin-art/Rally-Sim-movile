## Volcado corto (fase 4): las 79 carreras del mapa con su tipo, largo, premio y distancia a Dream City, para que tools/econ/progression_sim.py
## calcule la economía sin simular partidas. Imprime un renglón «EV {json}» por carrera. Tarda pocos segundos.
## Uso: tools/test/run_test.sh econ_dump 60   (el registro queda en test_logs/econ_dump.log)
extends SceneTree

const OW := preload("res://game/world/ow_events.gd")
const CityGps := preload("res://game/city/city_gps.gd")
const CityTrack := preload("res://game/track/city_track.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var SecS: GDScript = load("res://game/region/sectors.gd")
	SecS.set("_loaded", true)
	SecS.set("_open_all", true)
	var tr := CityTrack.new()
	var evs: Array = OW.build(tr.region, CityGps.new(tr.city))
	for e in evs:
		var p: Vector2 = e["start"]
		print("EV " + JSON.stringify({"id": e["id"], "type": e["type"], "len": snappedf(float(e["len"]), 1.0), "reward": int(e["reward"]),
			"tier": snappedf(float(e["tier"]), 0.01), "dist": snappedf(p.length(), 1.0), "x": snappedf(p.x, 1.0), "y": snappedf(p.y, 1.0), "rivals": int(e["rivals"])}))
	print("EVENTOS %d" % evs.size())
	# los 28 autos: prestaciones de serie y con todas las mejoras al máximo (CarBuild.perf_of, lo mismo que muestra el garaje)
	var veh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var cat: Dictionary = CarBuild.catalog()
	var maxu := {}
	for u in cat["upgrades"]:
		maxu[str(u["id"])] = (u["levels"] as Array).size() - 1
	for id in cat["cars"]:
		if not veh.has(id):
			continue
		var st := Profile.new_car_state(id)
		var p0: Dictionary = CarBuild.perf_of(CarBuild.build_params(veh[id], st))
		var st2 := st.duplicate(true)
		st2["upg"] = maxu.duplicate()
		var p1: Dictionary = CarBuild.perf_of(CarBuild.build_params(veh[id], st2))
		var sg: Dictionary = veh[id].get("surfGrip", {})
		print("CAR " + JSON.stringify({"id": id, "price": int(cat["cars"][id].get("price", 0)), "pi": p0["pi"], "hp": p0["hp"], "kg": p0["kg"], "vmax": p0["vmax"], "t100": p0["t100"],
			"bars": p0["bars"], "pi_max": p1["pi"], "hp_max": p1["hp"], "vmax_max": p1["vmax"], "t100_max": p1["t100"], "asphalt": sg.get("asphalt", 0), "dirt": sg.get("dirt", 0)}))
	print("RESULTADO: TODO OK")
	quit(0)
