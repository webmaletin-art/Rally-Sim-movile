## Versiones de cada auto en los concesionarios (game/data/dealer_variants.gd, pedido del dueño 15/10/2026): 4 por auto, cada una más preparada,
## con más potencia y más cara; comprar una cobra exactamente su precio y deja el auto con esas piezas y esa pintura. En el online, sólo la de fábrica.
## Uso: godot --headless --path godot --script res://tests/dealer_variants_test.gd
extends SceneTree

const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Shops := preload("res://game/data/shops.gd")
const DealerVariants := preload("res://game/data/dealer_variants.gd")
const Cosmetics := preload("res://game/data/cosmetics.gd")
var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

class Stub extends Profile:
	func save() -> void:
		pass

func _initialize() -> void:
	var veh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var cars: Dictionary = CarBuild.catalog()["cars"]
	for dealer in ["dealer", "dealer_rally", "dealer_classic", "dealer_sport"]:
		var list: Array = Shops.get_shop(dealer).get("cars", [])
		if list.is_empty():
			list = ["hatch", "gt", "pickup"]
		var all_ok := true
		var why := ""
		for id in list:
			var vs: Array = DealerVariants.for_car(dealer, str(id))
			var last_p := -1
			var last_hp := -1.0
			for v in vs:
				var hp := float(CarBuild.perf_of(CarBuild.build_params(veh[str(id)], DealerVariants.state(str(id), v)))["hp"])
				if int(v["price"]) <= last_p or hp < last_hp:
					all_ok = false
					why = "%s %s: %d / %.0f cv" % [id, v["n"], int(v["price"]), hp]
				last_p = int(v["price"])
				last_hp = hp
			if vs.size() != 4 or int(vs[0]["price"]) != int(cars[str(id)]["price"]):
				all_ok = false
				why = "%s: %d versiones" % [id, vs.size()]
		_check(all_ok, "%s: 4 versiones por auto, cada una más cara y con igual o más potencia %s" % [dealer, why])
	var v3: Dictionary = DealerVariants.for_car("dealer_classic", "gt")[3]
	var hp0 := float(CarBuild.perf_of(CarBuild.build_params(veh["gt"], Profile.new_car_state("gt")))["hp"])
	var hp3 := float(CarBuild.perf_of(CarBuild.build_params(veh["gt"], DealerVariants.state("gt", v3)))["hp"])
	print("     gt: de fábrica %.0f cv $%d · %s %.0f cv $%d" % [hp0, int(cars["gt"]["price"]), v3["n"], hp3, int(v3["price"])])
	_check(hp3 > hp0 * 1.1, "la versión LLAMAS tiene bastante más potencia")
	# comprar
	var p := Stub.new()
	p.d["owned"] = {}
	p.d["credits"] = int(v3["price"]) + 1000
	var r: Dictionary = DealerVariants.buy(p, "gt", v3)
	var st: Dictionary = p.d["owned"].get("gt", {})
	_check(bool(r["ok"]) and p.credits == 1000, "comprar la versión cobra exactamente su precio (queda %d)" % p.credits)
	_check(not st.is_empty() and int(st["upg"].get("engine", 0)) == 3 and int(st["upg"].get("turbo", 0)) == 2 and str(st["tires"]) == "sport", "el auto queda con las mejoras y las gomas de la versión (%s · %s)" % [str(st.get("upg")), str(st.get("tires"))])
	_check(Cosmetics.owns(st, str(v3["style"])) and int(Cosmetics.paint_ok("gt", st).get("livery", 0)) == 19, "y con el diseño de llamas comprado y puesto")
	var p2 := Stub.new()
	p2.d["owned"] = {}
	p2.d["credits"] = int(v3["price"]) - 1
	_check(not bool(DealerVariants.buy(p2, "gt", v3)["ok"]) and p2.credits == int(v3["price"]) - 1 and not p2.owns("gt"), "sin la plata justa no se compra nada a medias")
	_check(DealerVariants.for_car("dealer_rally", "pickup", true).size() == 1, "en el online sólo se vende la de fábrica")
	print("RESULTADO: " + ("HAY FALLAS" if fail else "TODO OK"))
	quit(1 if fail else 0)
