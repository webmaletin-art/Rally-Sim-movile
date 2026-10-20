## Prueba de la práctica de aventura (Carrera rápida) y del taller de prueba: el estado real no se toca y el auto se arma con todo liberado.
## Uso: godot --headless --path godot --script res://tests/practice_test.gd
extends SceneTree

const Adventure := preload("res://game/adventure/adventure.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

## Dobles de la carrera y del HUD: sólo lo que usa Adventure al guardar y al terminar
class FakeRace:
	extends RefCounted
	var profile: RefCounted
	func _init(p: RefCounted) -> void:
		profile = p

class FakeHud:
	extends Control
	var final_data: Dictionary = {}
	func show_final(d: Dictionary) -> void:
		final_data = d

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
	_practice_never_saves()
	quit(1 if fail else 0)

## Terminar etapas en la PRÁCTICA de Carrera rápida (la Ruta de los Sueños) no toca el avance real de la Aventura ni da su premio (20/10/2026, pedido del dueño: «revisá que si en
## carrera rápida juego las etapas de aventura no se desbloqueen en la aventura, que es de pago»). Antes _save() escribía el estado de la práctica en profile.d["adv"].
func _practice_never_saves() -> void:
	var saved := FileAccess.get_file_as_string(Profile.PATH) if FileAccess.file_exists(Profile.PATH) else "" # (Profile.save() escribe el archivo del perfil: se deja como estaba)
	var p2 := Profile.new()
	p2.d = Profile.default_profile()
	var real2 := AdvData.state(p2)
	real2["stage"] = 3
	real2["points"] = 9
	real2["started"] = true
	real2["intro"] = true
	(real2["skills"] as Dictionary)["curve"] = 2
	var before: Dictionary = (p2.d["adv"] as Dictionary).duplicate(true)
	var cr0: int = p2.credits
	var cfgp := {"type": "adventure", "stage": 1, "practice": true, "back": "quick"}
	Adventure.prepare_cfg(cfgp, p2)
	var adv := Adventure.new()
	adv.r = FakeRace.new(p2)
	adv.stage = 1
	adv.st = AdvData.state(p2) # (el estado descartable de la práctica)
	adv.result = {"time": 100.0}
	adv._save_station()
	check(int(adv.st["stage"]) == 2, "la práctica avanza SU estado (etapa 2)")
	check((p2.d["adv"] as Dictionary).hash() == before.hash(), "…y el avance real de la Aventura queda igual (etapa 3, 9 puntos y habilidades)")
	check(p2.credits == cr0, "…y no cobra el premio de la etapa")
	adv.st["stage"] = 11
	adv.stage = 11
	var fh := FakeHud.new()
	adv.hud = fh
	adv._finish_adventure()
	check(not p2.owns(AdvData.CAR) and p2.credits == cr0 and (p2.d["adv"] as Dictionary).hash() == before.hash(), "terminar la última etapa en práctica no da el DR Bisonte XR ni los $20.000 ni da por terminada la Aventura")
	check(bool(fh.final_data.get("practice", false)), "…y la pantalla final avisa que es práctica")
	# la Aventura de verdad sí guarda y paga
	var cfgr := {"type": "adventure", "stage": 3}
	Adventure.prepare_cfg(cfgr, p2)
	check(AdvData.practice.is_empty(), "una etapa normal sale de la práctica")
	var adv2 := Adventure.new()
	adv2.r = FakeRace.new(p2)
	adv2.stage = 3
	adv2.st = AdvData.state(p2)
	adv2.result = {"time": 120.0}
	adv2._save_station()
	check(int((p2.d["adv"] as Dictionary)["stage"]) == 4 and p2.credits == cr0 + AdvData.stage_reward(3), "la Aventura de verdad sí guarda el avance y cobra la etapa")
	adv.free()
	adv2.free()
	fh.free()
	if saved != "":
		var f := FileAccess.open(Profile.PATH, FileAccess.WRITE)
		f.store_string(saved)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.PATH))
