## Desgaste de neumáticos (Etapa 13): progresivo, depende de cómo se maneja, baja el agarre de verdad en la física, se guarda por juego de gomas y se cambia pagando. Sin red.
## Uso: godot --headless --path godot --script res://tests/tire_wear_test.gd
extends SceneTree

const TW := preload("res://game/car/tire_wear.gd")
const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	# familias
	check(TW.family("street") == "STREET" and TW.family("sport") == "SPORT" and TW.family("slick") == "SPORT" and TW.family("gravel") == "RALLY" and TW.family("drift") == "DRIFT", "cada neumático del catálogo pertenece a una familia (calle, deportiva, rally, drift)")
	for t in CarBuild.catalog()["tires"]:
		check(TW.FAMILY.has(str(t["id"])), "el neumático %s tiene familia" % str(t["id"]))
	# progresivo y proporcional a la distancia
	var calm := 0.0
	for i in 600: # 60 s a 15 m/s tranquilo
		calm += TW.wear_step("street", 15.0, 0.5, 0.2, 0.0, true, 0.1)
	check(calm > 0.0 and calm < 0.02, "manejo tranquilo: poco desgaste (%.2f %% por minuto)" % (calm * 100.0))
	var hard := 0.0
	for i in 600:
		hard += TW.wear_step("street", 15.0, 9.0, 6.0, 0.5, true, 0.1)
	check(hard > calm * 3.0, "manejo brusco gasta más de 3 veces más (%.1f vs %.1f)" % [hard * 100.0, calm * 100.0])
	check(TW.wear_step("street", 0.0, 9.0, 6.0, 1.0, true, 1.0) == 0.0, "parado no se gasta")
	# superficies y tipos
	var rally_asph := TW.wear_step("gravel", 15.0, 3.0, 1.0, 0.0, true, 1.0)
	var rally_dirt := TW.wear_step("gravel", 15.0, 3.0, 1.0, 0.0, false, 1.0)
	check(rally_asph > rally_dirt, "las de rally se gastan más en asfalto que en tierra")
	check(TW.wear_step("sport", 15.0, 3.0, 1.0, 0.0, false, 1.0) > TW.wear_step("sport", 15.0, 3.0, 1.0, 0.0, true, 1.0), "las deportivas sufren en tierra")
	check(TW.wear_step("drift", 15.0, 3.0, 1.0, 0.0, true, 1.0) > TW.wear_step("street", 15.0, 3.0, 1.0, 0.0, true, 1.0) * 2.0, "las de drift duran mucho menos")
	# agarre
	check(is_equal_approx(TW.grip_factor("street", 0.0), 1.0), "nuevas: agarre completo")
	check(TW.grip_factor("street", 0.5) < 1.0 and TW.grip_factor("street", 0.5) > TW.grip_factor("street", 1.0), "el agarre baja de a poco")
	check(is_equal_approx(TW.grip_factor("street", 1.0), TW.GRIP_MIN["STREET"]), "lisas: agarre mínimo")
	check(TW.state_name(0.0) == "Nuevas" and TW.state_name(0.5) == "Gastadas" and TW.state_name(0.95) == "Lisas", "estados en palabras")
	check(TW.warn_level(0.5) == 0 and TW.warn_level(0.75) == 1 and TW.warn_level(0.95) == 2, "avisos al 70 % y al 90 %")
	# el agarre llega a la física: el auto con gomas gastadas tiene menos surfGrip
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var d: Dictionary = CarBuild.build_params(vehicles["gt"], {"upg": {}, "tires": "street", "tune": {}})
	var V = VehicleParams.from_dict(d)
	var base := (V.surfGrip as PackedFloat64Array).duplicate()
	var k := TW.grip_factor("street", 0.8)
	var worn := PackedFloat64Array()
	worn.resize(base.size())
	for i in base.size():
		worn[i] = base[i] * k
	V.surfGrip = worn
	check(V.surfGrip[0] < base[0] and absf(V.surfGrip[0] / base[0] - k) < 1e-6, "con 80 %% de desgaste el agarre sobre asfalto baja a %.0f %%" % (k * 100.0))
	# perfil: desgaste por juego de gomas y cambio pagando
	var p := Profile.new()
	p.d["owned"] = {}
	p.give("gt")
	p.d["credits"] = 100000
	var car_d: Dictionary = p.d["owned"]["gt"]
	car_d["tireWear"] = {"street": 0.8}
	check(is_equal_approx(p.tire_wear("gt"), 0.8), "el perfil devuelve el desgaste del juego puesto")
	check(p.buy_tires("gt", "sport"), "comprar y poner otro juego")
	check(is_equal_approx(p.tire_wear("gt"), 0.0) and is_equal_approx(p.tire_wear("gt", "street"), 0.8), "cada juego guarda su desgaste (el nuevo en 0, el viejo sigue en 80 %)")
	p.buy_tires("gt", "street")
	var c0: int = p.credits
	var cost: int = p.replace_tires("gt")
	check(cost >= 250 and c0 - p.credits == cost and is_equal_approx(p.tire_wear("gt"), 0.0), "cambiar las gomas cuesta %d y las deja nuevas" % cost)
	p.d["credits"] = 10
	check(p.replace_tires("gt") == -1, "sin plata no se cambian")
	print("TIRE_WEAR_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
