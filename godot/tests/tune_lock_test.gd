## Reglajes bloqueados (auditoría 15/10/2026, P0): un reglaje que pide una mejora no se cobra ni se guarda si la mejora no está; con la mejora se cobra y llega a la física.
## Uso: godot --headless --path godot --script res://tests/tune_lock_test.gd
extends SceneTree

const CarBuild := preload("res://game/data/car_build.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var base: Dictionary = vehicles["hatch"]
	var defs := CarBuild.default_tune(base)
	var st := Profile.new_car_state("hatch")
	var none := {}
	var susp := {"suspension": 1}
	# qué está bloqueado
	_check(not CarBuild.tune_unlocked("springF", none) and CarBuild.tune_unlocked("pressF", none), "sin mejoras: los resortes están bloqueados y la presión de gomas no")
	_check(CarBuild.tune_unlocked("springF", susp) and not CarBuild.tune_unlocked("camberF", susp), "suspensión 1 habilita resortes; la caída sigue bloqueada (pide suspensión 3)")
	var src := CarBuild.unlock_source("springs")
	_check(str(src.get("cat", "")) == "suspension" and int(src.get("level", 0)) == 1 and int(src.get("cost", 0)) > 0, "el candado dice qué mejora lo habilita: %s nivel %d, $%d" % [str(src.get("name", "")), int(src.get("level", 0)), int(src.get("cost", 0))])
	for k in ["camber", "toe", "height", "final", "lsd", "aero", "stance"]:
		_check(not CarBuild.unlock_source(k).is_empty(), "«%s» tiene una mejora que lo habilita" % k)
	# cobro: lo bloqueado no cuenta
	var draft := {"springF": 140.0, "camberF": -3.0, "pressF": 33.0}
	_check(CarBuild.tune_change_count(draft, {}, defs, none) == 1, "sin mejoras: de 3 cambios sólo se cobra 1 (la presión)")
	_check(CarBuild.tune_change_count({"springF": 140.0}, {}, defs, none) == 0, "mover sólo un reglaje bloqueado no cobra nada")
	_check(CarBuild.tune_change_count(draft, {}, defs, susp) == 2, "con suspensión 1: se cobran presión y resortes (la caída sigue bloqueada)")
	# guardado: lo bloqueado no se guarda (queda como estaba)
	var clean := CarBuild.tune_sanitize(draft, {}, none)
	_check(not clean.has("springF") and not clean.has("camberF") and float(clean.get("pressF", 0)) == 33.0, "al aplicar sin mejoras se guarda sólo la presión")
	var clean2 := CarBuild.tune_sanitize({"springF": 150.0}, {"springF": 120.0}, none)
	_check(float(clean2.get("springF", 0)) == 120.0, "un valor viejo guardado se respeta (no se pisa ni se borra)")
	# física: bloqueado no cambia nada; desbloqueado sí
	var p0 := CarBuild.build_params(base, st)
	var st_l := st.duplicate(true)
	st_l["tune"] = {"springF": 150.0}
	var p1 := CarBuild.build_params(base, st_l)
	_check(is_equal_approx(float(p0["freqF"]), float(p1["freqF"])), "resortes al 150 %% sin la mejora: la física no cambia (%.3f = %.3f)" % [float(p0["freqF"]), float(p1["freqF"])])
	var st_u := st_l.duplicate(true)
	st_u["upg"] = {"suspension": 1}
	var st_u0 := st.duplicate(true)
	st_u0["upg"] = {"suspension": 1}
	var p2 := CarBuild.build_params(base, st_u)
	var p3 := CarBuild.build_params(base, st_u0)
	_check(float(p2["freqF"]) > float(p3["freqF"]) * 1.4, "con la mejora: resortes al 150 %% endurecen de verdad (%.3f → %.3f)" % [float(p3["freqF"]), float(p2["freqF"])])
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
