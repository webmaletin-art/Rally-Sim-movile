## «PRÓXIMO OBJETIVO» (game/city/next_goal.gd + city_goal.gd): elige algo posible y útil de lo que ya existe; nafta primero; nada imposible; ✕ lo saca un rato.
## Uso: godot --headless --path godot --script res://tests/next_goal_test.gd
extends SceneTree

const NextGoal := preload("res://game/city/next_goal.gd")
const CityGoal := preload("res://game/city/city_goal.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var evs := [
		{"id": "a", "name": "Sprint · Norte", "icon": "🏁", "pos": Vector2(3000, 0), "reward": 5600, "found": true, "wins": 0, "best": null, "type": "sprint"},
		{"id": "b", "name": "Montaña · Sur", "icon": "⛰", "pos": Vector2(500, 0), "reward": 4300, "found": true, "wins": 2, "best": 95.4, "type": "montana"},
		{"id": "c", "name": "?", "icon": "🏁", "pos": Vector2(0, 1200), "reward": 3000, "found": false, "wins": 0, "best": null, "type": "sprint"},
		{"id": "d", "name": "Lejísimos", "icon": "🏁", "pos": Vector2(90000, 0), "reward": 7000, "found": true, "wins": 0, "best": null, "type": "sprint"},
	]
	var ctx := {"pos": Vector2.ZERO, "fuel": 0.8, "credits": 5000, "events": evs, "live": [], "next_car": {"id": "torito", "name": "BRAVA Torito '67", "price": 18000},
		"fuel_pos": Vector2(100, 0), "dealer_pos": Vector2(50, 50), "dismissed": {}}
	var g := NextGoal.pick(ctx)
	_check(not g.is_empty() and str(g[0]["key"]) == "ow:a", "primero, la carrera descubierta y sin ganar más cercana (%s)" % (str(g[0]["key"]) if not g.is_empty() else "nada"))
	_check(str(g[0]["sub"]).contains("cualquier auto") and g[0]["pos"] is Vector2, "dice el premio, que sirve cualquier auto, y tiene IR (GPS)")
	var keys: Array = g.map(func(x: Dictionary) -> String: return str(x["key"]))
	_check(keys.has("unk:c") and keys.has("car:torito") and keys.has("rec:b"), "también: una por descubrir, el próximo auto y bajar un tiempo propio")
	_check(not keys.has("ow:d"), "lo que está a más de 60 km no se propone")
	ctx["fuel"] = 0.08
	g = NextGoal.pick(ctx)
	_check(str(g[0]["key"]) == "fuel" and g[0]["pos"] == Vector2(100, 0), "con el tanque casi vacío, primero cargar nafta")
	ctx["fuel"] = 0.8
	ctx["dismissed"] = {"ow:a": true}
	g = NextGoal.pick(ctx)
	_check(str(g[0]["key"]) != "ow:a", "✕ saca ese objetivo y aparece otro (%s)" % str(g[0]["key"]))
	ctx["dismissed"] = {}
	ctx["live"] = [{"id": "77", "title": "Fuga de 5 minutos", "icon": "🚨", "ends_in": 3000.0, "standing": ""}]
	g = NextGoal.pick(ctx)
	_check(str(g[0]["key"]) == "live:77", "un evento del servidor en vivo va antes que las carreras")
	ctx["live"] = []
	ctx["credits"] = 20000
	g = NextGoal.pick(ctx)
	var car: Array = g.filter(func(x: Dictionary) -> bool: return str(x["key"]) == "car:torito")
	_check(not car.is_empty() and str(car[0]["title"]).begins_with("Ya te alcanza") and car[0]["pos"] == Vector2(50, 50), "con la plata justa: «ya te alcanza» con IR al concesionario")
	# el próximo auto de verdad (catálogo): el más barato que no tenés, comprable con plata y más caro que el tuyo
	var p := Profile.new()
	p.d = Profile.default_profile()
	p.d["owned"] = {"hatch": Profile.new_car_state("hatch")}
	p.d["current"] = "hatch"
	var nc := CityGoal.next_car(p)
	_check(str(nc.get("id", "")) == "torito", "con el auto inicial, el próximo es el Torito ($18.000): %s" % str(nc))
	p.d["owned"]["torito"] = Profile.new_car_state("torito")
	p.d["owned"]["hatch2"] = Profile.new_car_state("hatch2")
	p.d["current"] = "hatch2"
	nc = CityGoal.next_car(p)
	_check(not nc.is_empty() and int(nc["price"]) > 24000 and not ["truck", "gt3", "hyper", "genesis"].has(str(nc["id"])), "nunca propone un auto pago o de premio: %s" % str(nc.get("id", "")))
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
