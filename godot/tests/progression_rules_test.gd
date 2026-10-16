## Reglas de premio de las carreras del mapa (fase 4, game/city/city_events.gd → pay_mult): perder a propósito ya no paga más que ganar.
## Corta (≈ 1 s). Uso: tools/test/run_test.sh progression_rules_test 30
extends SceneTree

const CityEvents := preload("res://game/city/city_events.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")
const CarVisual := preload("res://game/car/car_visual.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var E = CityEvents
	_check(is_equal_approx(E.pay_mult(true, true, 1), 1.0) and is_equal_approx(E.pay_mult(true, true, 4), 1.0), "la primera victoria paga entera (aunque haya perdido antes)")
	_check(is_equal_approx(E.pay_mult(true, false, 5), E.REPEAT_K), "una victoria repetida paga el 35 %")
	_check(is_equal_approx(E.pay_mult(false, true, 1), 1.0), "el primer intento perdido paga su puesto entero (2.º 45 %, plata 60 %): no castiga al que aprende")
	_check(is_equal_approx(E.pay_mult(false, true, 2), E.LOSE_K), "desde el segundo intento, perder paga × %.2f" % E.LOSE_K)
	var second: float = E.PLACE_K[1] * E.LOSE_K
	var silver: float = E.MEDAL_K[1] * E.LOSE_K
	_check(second < E.REPEAT_K and silver < E.REPEAT_K, "salir 2.º (%.0f %%) o sacar plata (%.0f %%) repetido paga MENOS que ganar repetido (%.0f %%)" % [second * 100.0, silver * 100.0, E.REPEAT_K * 100.0])
	_check(E.PLACE_K[1] > E.PLACE_K[2] and E.MEDAL_K[1] > E.MEDAL_K[2], "el orden de los puestos y medallas se mantiene (2.º > 3.º, plata > bronce)")
	# autos pagos (fase 4): cada uno con un rol propio, ninguno obligatorio ni peor que un gratis más barato en todo
	var veh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var pf := func(id: String) -> Dictionary: return CarBuild.perf_of(CarBuild.build_params(veh[id], Profile.new_car_state(id)))
	var gt3: Dictionary = pf.call("gt3")
	var tgt: Dictionary = pf.call("trilux_gt")
	var hy: Dictionary = pf.call("hyper")
	var gtr: Dictionary = pf.call("veltor_gtr")
	_check(float(gt3["bars"]["handling"]) > float(tgt["bars"]["handling"]) + 0.05, "GT3: el mejor en curvas de su grupo (carga aerodinámica de fábrica): %.2f vs Trilux GT %.2f" % [gt3["bars"]["handling"], tgt["bars"]["handling"]])
	_check(int(tgt["hp"]) > int(gt3["hp"]) and int(tgt["vmax"]) >= int(gt3["vmax"]), "…pero el Trilux GT (gratis) sigue teniendo más motor y velocidad: el GT3 no es obligatorio")
	_check(float(hy["bars"]["handling"]) > float(gtr["bars"]["handling"]), "Hyper: dobla mejor que el Veltor GTR (%.2f vs %.2f)" % [hy["bars"]["handling"], gtr["bars"]["handling"]])
	_check(int(gtr["vmax"]) > int(hy["vmax"]) and int(gtr["hp"]) > int(hy["hp"]), "…y el Veltor GTR (gratis) sigue siendo el más veloz y potente (%d vs %d km/h)" % [gtr["vmax"], hy["vmax"]])
	_check(int(pf.call("veltor_s")["pi"]) == 772 and int(tgt["pi"]) == 707 and int(gtr["pi"]) == 805, "los autos gratis no cambiaron (Veltor S 772, Trilux GT 707, Veltor GTR 805)")
	# diferencial nivel 2 → reparto de tracción (fase 4: antes el reglaje era libre para todos y el nivel 2 no agregaba nada)
	var st := Profile.new_car_state("hatch")
	var base_fdr := float(veh["hatch"]["frontDriveRatio"])
	st["tune"] = {"split": 0}
	_check(CarBuild.tune_req("split") == "split" and not CarBuild.tune_unlocked("split", st["upg"]), "el reparto de tracción pide el diferencial nivel 2 (candado en el taller)")
	_check(is_equal_approx(float(CarBuild.build_params(veh["hatch"], st)["frontDriveRatio"]), base_fdr), "sin diferencial nivel 2 un reparto guardado no cambia la física (sigue de fábrica: %.0f %% adelante)" % (base_fdr * 100.0))
	st["upg"] = {"diff": 2}
	_check(is_equal_approx(float(CarBuild.build_params(veh["hatch"], st)["frontDriveRatio"]), 0.0), "con diferencial nivel 2 el reparto sí cambia la física (0 % = tracción trasera)")
	st["upg"] = {"diff": 1}
	_check(not CarBuild.tune_unlocked("split", st["upg"]) and CarBuild.tune_unlocked("lsd", st["upg"]), "el nivel 1 desbloquea el autoblocante, no el reparto")
	# stance nivel 1: la caída extrema existe en la física y se ve en las ruedas; con el control en 0 no cambia nada
	var ss := Profile.new_car_state("hatch")
	ss["upg"] = {"stance": 1}
	ss["tune"] = {"stanceCamber": 0}
	_check(is_equal_approx(float(CarBuild.build_params(veh["hatch"], ss)["camberF"]), -1.0), "stance comprado con el control en 0: la caída queda de fábrica (−1°)")
	ss["tune"] = {"stanceCamber": 12}
	var cam12 := float(CarBuild.build_params(veh["hatch"], ss)["camberF"])
	_check(is_equal_approx(cam12, -13.0), "con 12° de stance la rueda queda en −13° (física)")
	_check(is_zero_approx(CarVisual.camber_tilt(-1.0)) and is_zero_approx(CarVisual.camber_tilt(-2.0)) and CarVisual.camber_tilt(cam12) > deg_to_rad(10.0), "se dibuja sólo lo extremo: −1° y −2° no inclinan la rueda; −13° la inclina %.0f°" % rad_to_deg(CarVisual.camber_tilt(cam12)))
	ss["upg"] = {}
	_check(is_equal_approx(float(CarBuild.build_params(veh["hatch"], ss)["camberF"]), -1.0), "sin el kit stance el valor guardado no hace nada")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
