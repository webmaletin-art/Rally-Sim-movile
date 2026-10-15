extends RefCounted
## Cosméticos que se compran por auto: diseños de pintura, interiores y volantes (game/data/cosmetics.json, docs/PERSONALIZACION.md).
## Se compran una vez por auto y quedan en car["partsOwned"], igual que las piezas: la cuenta del servidor los valida como «buy_part» (mismo id y precio en
## online_cat_parts) y al sincronizar sólo quedan los que dice el servidor. Lo puesto vive en la pintura del auto: paint["interior"], paint["steer"] y paint["style"].

const FILE := "res://game/data/cosmetics.json"
static var _cat: Dictionary = {}

static func catalog() -> Dictionary:
	if _cat.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE)) if FileAccess.file_exists(FILE) else {}
		_cat = d if d is Dictionary else {}
	return _cat

static func item(id: String) -> Dictionary:
	for k in ["styles", "interiors", "wheels"]:
		for it in catalog().get(k, []):
			if str(it["id"]) == id:
				return it
	return {}

static func price(id: String) -> int:
	return int(item(id).get("price", 0))

## ¿Se puede usar en este auto? (gratis, o comprado en ese auto)
static func owns(st: Dictionary, id: String) -> bool:
	if id == "" or price(id) <= 0:
		return true
	return (st.get("partsOwned", []) as Array).has(id)

## Estilos que se ofrecen para un auto (los exclusivos, sólo en el suyo)
static func styles_for(car_id: String) -> Array:
	var out: Array = []
	for it in catalog().get("styles", []):
		var cars: Array = it.get("cars", [])
		if cars.is_empty() or cars.has(car_id):
			out.append(it)
	return out

static func default_interior(car_id: String) -> String:
	return str((catalog().get("defaults", {}).get("interior", {}) as Dictionary).get(car_id, "cab_dream"))

static func default_wheel(car_id: String) -> String:
	return str((catalog().get("defaults", {}).get("wheel", {}) as Dictionary).get(car_id, "vol_dream"))

## Lo que de verdad se pone (si lo elegido no es tuyo, el de fábrica)
static func interior_of(car_id: String, st: Dictionary) -> String:
	var pick := str((st.get("paint", {}) as Dictionary).get("interior", ""))
	return pick if pick != "" and not item(pick).is_empty() and owns(st, pick) else default_interior(car_id)

static func wheel_of(car_id: String, st: Dictionary) -> String:
	var pick := str((st.get("paint", {}) as Dictionary).get("steer", ""))
	return pick if pick != "" and not item(pick).is_empty() and owns(st, pick) else default_wheel(car_id)

## La pintura que se dibuja: un diseño pago (patrón 12 en adelante) sin comprar vuelve a liso
static func paint_ok(car_id: String, st: Dictionary) -> Dictionary:
	var p: Dictionary = (st.get("paint", {}) as Dictionary).duplicate()
	var lv := int(p.get("livery", 0))
	if lv >= 12:
		var ok := false
		for it in styles_for(car_id):
			if int(it["preset"]["livery"]) == lv and owns(st, str(it["id"])):
				ok = true
				break
		if not ok:
			p["livery"] = 0
	return p

## Compra (una vez por auto). Devuelve {ok, reason}
static func buy(profile, car_id: String, id: String) -> Dictionary:
	if not profile.owns(car_id):
		return {"ok": false, "reason": "no tenés ese auto"}
	var it := item(id)
	if it.is_empty():
		return {"ok": false, "reason": "no existe"}
	var st: Dictionary = profile.d["owned"][car_id]
	if owns(st, id):
		return {"ok": true, "dup": true}
	var cost := int(it.get("price", 0))
	if not profile._take_shop(cost, {"t": "buy_part", "car": car_id, "part": id}):
		return {"ok": false, "reason": "no alcanza el dinero"}
	var own: Array = st.get("partsOwned", [])
	own.append(id)
	st["partsOwned"] = own
	profile.save()
	return {"ok": true}
