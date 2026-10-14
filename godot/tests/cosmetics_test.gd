## Cosméticos que se compran por auto (data/cosmetics.gd + cosmetics.json): compra con plata, se registran como pieza para el servidor, lo no comprado no se dibuja,
## la cabina arma todos los interiores y volantes, y los precios del juego son los mismos que los de la migración del servidor.
## Uso: godot --headless --path godot --script res://tests/cosmetics_test.gd
extends SceneTree

const Cosmetics := preload("res://game/data/cosmetics.gd")
const Cockpit := preload("res://game/car/cockpit.gd")
const Profile := preload("res://game/data/profile.gd")
var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

class Acct:
	extends Node
	var events: Array = []
	func log_event(e: Dictionary, _d: int) -> void:
		events.append(e)

class P:
	extends RefCounted
	var d := {"owned": {}}
	var credits := 20000
	var acct = null
	func owns(id: String) -> bool:
		return d["owned"].has(id)
	func _take(n: int) -> bool:
		if credits < n:
			return false
		credits -= n
		return true
	func save() -> void:
		pass

func _initialize() -> void:
	var cat := Cosmetics.catalog()
	_check(cat.get("styles", []).size() >= 15 and cat.get("interiors", []).size() >= 6 and cat.get("wheels", []).size() >= 5, "catálogo: %d diseños, %d interiores, %d volantes" % [cat["styles"].size(), cat["interiors"].size(), cat["wheels"].size()])
	var p := P.new()
	var ac := Acct.new()
	p.acct = ac
	p.d["owned"]["hatch"] = {"paint": {"body": "#ffffff", "livery": 19}, "partsOwned": []}
	var st: Dictionary = p.d["owned"]["hatch"]
	_check(int(Cosmetics.paint_ok("hatch", st)["livery"]) == 0, "un diseño pago sin comprar se dibuja liso")
	var r := Cosmetics.buy(p, "hatch", "st_llamas")
	_check(bool(r["ok"]) and p.credits == 20000 - 8500 and (st["partsOwned"] as Array).has("st_llamas"), "comprar «Llamas» descuenta $8.500 y queda en el auto")
	_check(ac.events.size() == 1 and str(ac.events[0]["t"]) == "buy_part" and str(ac.events[0]["part"]) == "st_llamas", "la compra va al servidor como buy_part")
	_check(int(Cosmetics.paint_ok("hatch", st)["livery"]) == 19, "comprado, se dibuja")
	p.credits = 500
	var r2 := Cosmetics.buy(p, "hatch", "cab_neon")
	_check(not bool(r2["ok"]) and p.credits == 500 and not (st["partsOwned"] as Array).has("cab_neon"), "sin plata suficiente no se compra")
	_check(Cosmetics.interior_of("hatch", st) == "cab_dream" and Cosmetics.interior_of("police", {}) == "cab_patrulla" and Cosmetics.wheel_of("f1", {}) == "vol_pro", "interiores y volantes de fábrica según el auto")
	st["paint"]["interior"] = "cab_carbono"
	_check(Cosmetics.interior_of("hatch", st) == "cab_dream", "un interior elegido pero no comprado no se pone")
	_check(Cosmetics.styles_for("hatch").all(func(x) -> bool: return not (x.get("cars", []) as Array).has("strix")) and Cosmetics.styles_for("strix").any(func(x) -> bool: return str(x["id"]) == "st_strix_vandal"), "los diseños exclusivos sólo salen en su auto")
	# la cabina arma todos
	var bad: Array = []
	for it in cat["interiors"]:
		for w in cat["wheels"]:
			var ck := Cockpit.new("hatch", Color.RED, Color.ORANGE, {"interior": str(it["id"]), "steer": str(w["id"])})
			if ck.rim == null or ck.rim.get_child_count() == 0:
				bad.append("%s+%s" % [it["id"], w["id"]])
			ck.free()
	_check(bad.is_empty(), "la cabina arma los %d interiores × %d volantes (%s)" % [cat["interiors"].size(), cat["wheels"].size(), str(bad)])
	# mismos precios que la migración del servidor
	var sql := FileAccess.get_file_as_string("res://../supabase/migrations/20261015000000_catalog_28_cosmetics.sql") + FileAccess.get_file_as_string("res://../supabase/migrations/20261016000000_cosmetics_volantes_pro.sql")
	var miss: Array = []
	for k in ["styles", "interiors", "wheels"]:
		for it in cat[k]:
			if int(it.get("price", 0)) > 0 and not sql.contains("('%s', 'cosmetic', %d," % [it["id"], int(it["price"])]):
				miss.append(str(it["id"]))
	_check(sql != "" and miss.is_empty(), "precios iguales en el juego y en la migración del servidor (%s)" % str(miss))
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
