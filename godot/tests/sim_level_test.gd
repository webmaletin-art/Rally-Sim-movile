## El nivel de simulación que se elige al largar es lo único que manda ([B] 20/10/2026, pedido del dueño):
##  · el nivel PERSONALIZADO trae «Ángulo de dirección» (de 70 a 130 %, 0 = el del auto): reemplaza al del reglaje y nunca pasa de 130;
##  · los niveles ARCADE / INTERMEDIO / SIMULADOR TOTAL no cambian la dirección;
##  · Opciones ya no tiene la página de física (ayudas): se eligen al empezar cada carrera, así nada las pisa;
##  · la elección vale para cada carrera: las copas, la carrera rápida y el mundo abierto preguntan siempre, la Aventura trae su propia configuración.
## Uso: tools/test/run_test.sh sim_level_test 30
extends SceneTree

const RaceS := preload("res://game/race.gd")
const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const OptionsUi := preload("res://game/ui/options_ui.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var st: Dictionary = Profile.new_car_state("hatch")
	var assists := {"abs": true, "tc": 50.0, "stab": 30.0}
	var base: Dictionary = CarBuild.build_params(vehicles["hatch"], st, assists)
	var m0 := float(base["maxSteer"])
	# 0 = el del auto: no se toca
	var p0 := base.duplicate()
	RaceS.with_steer_angle(p0, st, 0.0)
	_check(is_equal_approx(float(p0["maxSteer"]), m0), "ángulo «según el auto» (0): la dirección queda como el auto la trae (%.3f)" % m0)
	# 130 % = 1,3 veces el ángulo del auto con el reglaje al 100 %
	var p1 := base.duplicate()
	RaceS.with_steer_angle(p1, st, 130.0)
	_check(absf(float(p1["maxSteer"]) / m0 - 1.3) < 1e-4, "130 %%: el ángulo máximo sube a 1,3 veces (%.3f → %.3f)" % [m0, float(p1["maxSteer"])])
	var p2 := base.duplicate()
	RaceS.with_steer_angle(p2, st, 80.0)
	_check(absf(float(p2["maxSteer"]) / m0 - 0.8) < 1e-4, "80 %%: baja a 0,8 veces (%.3f)" % float(p2["maxSteer"]))
	var p3 := base.duplicate()
	RaceS.with_steer_angle(p3, st, 999.0)
	_check(absf(float(p3["maxSteer"]) / m0 - 1.3) < 1e-4, "nunca pasa de 130 % (aunque el valor guardado fuera mayor)")
	# con el reglaje de dirección del taller al 120 %: el nivel personalizado lo REEMPLAZA (no se suman)
	var st2: Dictionary = st.duplicate(true)
	st2["tune"] = {"steer": 120.0}
	var base2: Dictionary = CarBuild.build_params(vehicles["hatch"], st2, assists)
	_check(float(base2["maxSteer"]) > m0 * 1.05, "con el reglaje al 120 %% el auto dobla más (%.3f)" % float(base2["maxSteer"]))
	var p4 := base2.duplicate()
	RaceS.with_steer_angle(p4, st2, 100.0)
	_check(absf(float(p4["maxSteer"]) - m0) < 1e-4, "100 %% en PERSONALIZADO reemplaza al reglaje (vuelve a %.3f)" % m0)
	# los tres niveles fijos no traen ángulo de dirección
	for lv in ["arcade", "mid", "pro", "adv"]:
		_check(not (RaceS.SIM_PRESETS[lv] as Dictionary).has("steer"), "el nivel «%s» no toca la dirección" % lv)
	# el ajuste existe, arranca en «según el auto» y está en la página de física de Opciones (que sólo se ve dentro de PERSONALIZADO)
	_check(int(Profile.DEFAULT_SETTINGS["steerAngle"]) == 0, "el ajuste «steerAngle» arranca en 0 (según el auto)")
	var row: Array = []
	for o in OptionsUi.OPTION_LIST:
		if o[1] == "steerAngle":
			row = o
	_check(not row.is_empty() and str(row[0]) == "fisica" and (row[3] as Array).has(0) and (row[3] as Array).has(100) and (row[3] as Array).has(130) and not (row[3] as Array).has(131), "Opciones → física: «Ángulo de dirección» de 70 a 130 %, o según el auto")
	var physics_in_menu := false
	for c in OptionsUi.OPTION_CATS:
		if c[0] == "fisica":
			physics_in_menu = true
	_check(physics_in_menu, "la página de física existe (la usa el nivel PERSONALIZADO); el menú de Opciones no la muestra (se prueba en pantalla)")
	quit(1 if fail else 0)
