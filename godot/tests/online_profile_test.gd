## Perfil online (espejo del servidor): cada compra en un taller se manda al servidor y se confirma; lo que el servidor rechaza vuelve atrás; no se crea dinero ni se toca el perfil offline. Servidor simulado, sin red.
## Uso: godot --headless --path godot --script res://tests/online_profile_test.gd
extends SceneTree

const Profile := preload("res://game/data/profile.gd")
const OnlineProfile := preload("res://game/data/online_profile.gd")
const OnlineEconomy := preload("res://game/online/online_economy.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

## Un «servidor» mínimo con las mismas reglas que el SQL para las acciones que se prueban
class FakeOnline extends Node:
	var credits := 100000
	var veh: Dictionary = {"instance": "i-1", "vehicle": "pickup", "upg": {}, "tires": "street", "tiresOwned": ["street"], "tireWear": {}, "paint": {"body": "#b31f24", "accent": "#1b1d22", "rim": "#23262b", "livery": 11}, "partsOwned": [], "mods": {}, "km": 0, "status": "garage"}
	var at_shop := false
	var calls: Array = []
	var bought: Array = [] # autos comprados en el concesionario
	var buy_shop := ""
	func call_fn(fn: String, args: Dictionary, _need := true) -> Dictionary:
		calls.append(fn)
		match fn:
			"presence_beat":
				at_shop = true
				return {"ok": true, "data": null, "error": ""}
			"online_state":
				return {"ok": true, "data": {"credits": credits, "vehicles": [veh.duplicate(true)] + bought.duplicate(true)}, "error": ""}
			"online_buy_vehicle": # (como el SQL de 20261017000000: cualquier concesionario, con el color de fábrica del catálogo online; sin las demás claves)
				buy_shop = str(args["p_shop"])
				if not at_shop or not buy_shop.begins_with("dealer"):
					return {"ok": false, "data": null, "error": "este trabajo no se hace en ese local"}
				credits -= 1000
				var nv := {"instance": "i-%d" % (bought.size() + 2), "vehicle": str(args["p_vehicle"]), "upg": {}, "tires": "street", "tiresOwned": ["street"], "tireWear": {}, "paint": {"body": "#b31f24"}, "partsOwned": [], "mods": {}, "km": 0, "status": "garage"}
				bought.append(nv)
				return {"ok": true, "data": {"ok": true, "vehicle": nv.duplicate(true), "credits": credits}, "error": ""}
			"online_buy_upgrade":
				if not at_shop or str(args["p_shop"]) != "engine":
					return {"ok": false, "data": null, "error": "no estás en el local"}
				if int(args["p_level"]) != int((veh["upg"] as Dictionary).get(args["p_category"], 0)) + 1:
					return {"ok": false, "data": null, "error": "primero comprá el nivel anterior"}
				if credits < 400:
					return {"ok": false, "data": null, "error": "no te alcanza el dinero"}
				credits -= 400
				veh["upg"][args["p_category"]] = int(args["p_level"])
				return {"ok": true, "data": {"ok": true, "vehicle": veh.duplicate(true), "credits": credits}, "error": ""}
			"online_set_paint":
				if credits < 300:
					return {"ok": false, "data": null, "error": "no te alcanza el dinero"}
				credits -= 300
				for k in (args["p_paint"] as Dictionary):
					veh["paint"][k] = str(args["p_paint"][k]).to_lower()
				return {"ok": true, "data": {"ok": true, "vehicle": veh.duplicate(true), "credits": credits}, "error": ""}
		return {"ok": false, "data": null, "error": "obsoleto"}

func _initialize() -> void:
	var base := Profile.new()
	base.d["credits"] = 777
	base.d["owned"] = {"hatch": Profile.new_car_state("hatch")}
	base.d["current"] = "hatch"
	var offline_before: String = JSON.stringify(base.d["owned"]) + str(base.d["credits"])
	var fo := FakeOnline.new()
	root.add_child(fo)
	var eco := OnlineEconomy.new(fo)
	check(await eco.sync("Test"), "se trae el estado del servidor")
	var op := OnlineProfile.new(base, eco)
	check(op.credits == 100000 and op.owns("pickup") and not op.owns("hatch"), "el perfil online muestra los autos y créditos del servidor, no los offline")
	check(op.instance_of("pickup") == "i-1", "cada auto online tiene su instancia")
	# comprar el motor nivel 1 en el taller de motor
	eco.anchor = Vector2(10, 10)
	eco.has_anchor = true
	op.shop = "engine"
	var ok: bool = op.buy_upgrade("pickup", "engine", 1)
	check(ok and op.upgrade_level("pickup", "engine") == 1 and op.credits < 100000, "la compra se ve enseguida (espejo): motor 1 y menos créditos")
	await process_frame
	await process_frame
	await process_frame
	check(int(fo.veh["upg"].get("engine", 0)) == 1 and fo.credits == 99600, "el servidor registró la compra y cobró 400")
	check(fo.calls.has("presence_beat"), "antes del trabajo se avisó la posición en el local")
	check(op.credits == fo.credits, "el espejo coincide con la billetera del servidor")
	# saltarse un nivel: la interfaz ni lo intenta
	check(not op.buy_upgrade("pickup", "engine", 3), "no se puede saltar un nivel")
	check(not op.buy_upgrade("pickup", "engine", 0), "no se puede bajar de nivel")
	# repintar: se manda sólo lo que cambió
	var st: Dictionary = op.d["owned"]["pickup"]
	op.spend(300)
	st["paint"]["body"] = "#1A4FE0"
	op.save()
	for i in 4:
		await process_frame
	check(str(fo.veh["paint"]["body"]) == "#1a4fe0" and fo.credits == 99300, "la pintura se aplicó en el servidor y cobró 300")
	# el servidor rechaza (sin plata): el espejo vuelve a lo que dice el servidor
	var failed := []
	op.sync_failed.connect(func(t: String) -> void: failed.append(t))
	fo.credits = 100 # el servidor ya no tiene plata para esto, aunque el espejo diga otra cosa
	op.d["credits"] = 99999 # intento de trampa en el espejo
	op.shop = "engine"
	var bought: bool = op.buy_upgrade("pickup", "engine", 2)
	for i in 4:
		await process_frame
	check(bought and failed.size() == 1 and op.upgrade_level("pickup", "engine") == 1 and op.credits == fo.credits, "si el servidor rechaza, el espejo vuelve atrás y los créditos son los del servidor")
	# ajuste fino: sólo local, no cobra
	fo.calls.clear()
	var c0 := op.credits
	op.spend(100)
	op.d["owned"]["pickup"]["tune"] = {"x": 1}
	op.save()
	for i in 3:
		await process_frame
	check(not fo.calls.has("online_set_paint") and op.credits == c0, "el ajuste fino es local y no cobra online")
	# en la calle (nafta, peajes) no se cobra ni se crea dinero
	op.shop = ""
	var cc := op.credits
	check(op.spend(50) and op.credits == cc, "en la calle no se descuenta (todavía sin cobro online)")
	op.earn(5000.0)
	check(op.credits == cc, "los premios offline no crean créditos online")
	# comprar en un concesionario de especialidad (15/10/2026: «compraba y al rato me decía que ese no era el lugar»): se manda ESE local y después
	# no se intenta repintar en el concesionario (lo que el servidor no guarda de la pintura se compara con el color de fábrica)
	fo.credits = 200000
	op.d["credits"] = 200000
	op.shop = "dealer_rally"
	fo.calls.clear()
	var failed0 := failed.size()
	var got: bool = op.buy_car("gt")
	for i in 5:
		await process_frame
	check(got and fo.buy_shop == "dealer_rally" and fo.bought.size() == 1 and op.instance_of("gt") == "i-2", "el auto se compra en el concesionario donde está el jugador (%s)" % fo.buy_shop)
	check(not fo.calls.has("online_set_paint") and failed.size() == failed0, "después de comprar no se manda una pintura que el concesionario rechaza")
	check(op.credits == fo.credits and fo.credits == 199000, "se descontó una sola vez y el espejo coincide con el servidor")
	# el garaje online recuerda su auto elegido, aunque en el juego sin conexión se use otro
	op.shop = ""
	op.select("gt")
	op.flush()
	base.d["current"] = "pickup"
	var op2 := OnlineProfile.new(base, eco)
	check(op2.current_id() == "gt", "al volver a entrar al online sigue el auto elegido en el garaje online (%s)" % op2.current_id())
	base.d["current"] = "hatch"
	# el perfil offline no se tocó
	op.flush()
	var off_after: String = JSON.stringify(base.d["owned"]) + str(base.d["credits"])
	check(off_after == offline_before, "el progreso offline quedó intacto")
	print("ONLINE_PROFILE_TEST ", "OK" if fails == 0 else "FALLÓ")
	quit(1 if fails > 0 else 0)
