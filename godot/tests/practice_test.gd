## Prueba de la práctica de aventura (Carrera rápida) y del taller de prueba: el estado real no se toca y el auto se arma con todo liberado.
## Uso: godot --headless --path godot --script res://tests/practice_test.gd
extends SceneTree

const Adventure := preload("res://game/adventure/adventure.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var prof := Profile.new()
	var real := AdvData.state(prof)
	real["stage"] = 3
	var cfg := {"type": "adventure", "stage": 1, "practice": true, "back": "quick"}
	Adventure.prepare_cfg(cfg, prof)
	check(int(AdvData.state(prof)["stage"]) == 1, "la práctica usa su propio estado (etapa 1)")
	check(int(prof.d["adv"]["stage"]) == 3, "el avance real no se tocó")
	var cfg2 := {"type": "adventure", "stage": 3}
	Adventure.prepare_cfg(cfg2, prof)
	check(int(AdvData.state(prof)["stage"]) == 3, "una etapa normal vuelve al estado real")
	# taller de prueba: todo liberado y ajustes extra
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var st := Profile.new_car_state("gt")
	var stock: Dictionary = CarBuild.build_params(vehicles["gt"], st)
	var lab := st.duplicate(true)
	lab["lab"] = {"all": true, "power": 150.0, "mass": 90.0}
	lab["tune"] = {"springF": 130.0, "height": 40.0, "aeroF": 0.0, "aeroR": 0.0}
	var P: Dictionary = CarBuild.build_params(vehicles["gt"], lab)
	check(absf(float(P["powerScale"]) - 1.5) < 0.001, "potencia ×1,5 (%.2f)" % float(P["powerScale"]))
	check(float(P["mass"]) < float(stock["mass"]) * 0.91, "peso −10 %")
	check(float(P["freqF"]) > float(stock["freqF"]) * 1.25, "resortes duros aunque no tenga el kit de suspensión")
	check(float(P["rideOffset"]) > float(stock["rideOffset"]) + 0.03, "altura liberada")
	check(float(P["aeroR"]) == 0.0, "sin aerodinámica si no se pide")
	var lab0 := st.duplicate(true)
	lab0["lab"] = {"all": true}
	var P0: Dictionary = CarBuild.build_params(vehicles["gt"], lab0)
	check(absf(float(P0["mass"]) - float(stock["mass"])) < 0.01 and absf(float(P0["freqF"]) - float(stock["freqF"])) < 0.001, "taller sin cambios = auto de fábrica")
	quit(1 if fail else 0)
