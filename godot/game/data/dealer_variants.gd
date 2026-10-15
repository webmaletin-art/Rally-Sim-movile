extends RefCounted
## Versiones de cada auto en los concesionarios (15/10/2026, pedido del dueño: «3 o 4 del mismo modelo con distintos ajustes y pinturas: con llamas
## más caro, con más caballos más caro, pintura premium más cara, mejor preparado más caro»). Cada versión es el mismo auto con piezas reales ya puestas
## (mejoras del catálogo, gomas y un diseño de pintura de cosmetics.json): el precio es el del auto más lo que cuestan esas piezas, y al comprarla se
## compra todo junto con las compras de siempre (la cuenta del servidor valida cada una: buy_car, buy_upgrade, buy_tires, buy_part).
## En el modo online sólo se vende la de fábrica (las mejoras online se hacen en cada taller de Dream City).

const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Cosmetics := preload("res://game/data/cosmetics.gd")
const PaintPresets := preload("res://game/car/paint_presets.gd")

## n: nombre · d: qué trae · upg: {mejora: nivel} · tires: gomas puestas ("" = las de fábrica) · style: diseño de pintura (cosmetics.json → styles)
const TIERS := [
	{"n": "DE FÁBRICA", "d": "Como sale de la fábrica", "upg": {}, "tires": "", "style": ""},
	{"n": "SPORT", "d": "Motor 1, suspensión y frenos 1, gomas deportivas y pintura de dos tonos", "upg": {"engine": 1, "suspension": 1, "brakes": 1}, "tires": "sport", "style": "two"},
	{"n": "PREPARADO", "d": "Motor 2, turbo 1, caja 1, suspensión y frenos 2 y pintura premium de competición", "upg": {"engine": 2, "turbo": 1, "gearbox": 1, "suspension": 2, "brakes": 2}, "tires": "sport", "style": "comp"},
	{"n": "LLAMAS", "d": "Lo mejor: motor 3, turbo 2, caja 2, aligerado, suspensión y frenos 3 y pintura con llamas", "upg": {"engine": 3, "turbo": 2, "gearbox": 2, "weight": 1, "suspension": 3, "brakes": 3}, "tires": "sport", "style": "flames"},
]
## El diseño de cada versión según el rubro del concesionario (y las gomas: en el de tierra, de ripio)
const STYLES := {
	"dealer_rally": {"two": "st_rally_dakar", "comp": "st_rally_clasico", "flames": "st_llamas", "tires": "gravel"},
	"dealer_classic": {"two": "st_dos_tonos_azul", "comp": "st_damero", "flames": "st_llamas"},
	"dealer_sport": {"two": "st_carbono_negro", "comp": "st_competicion_roja", "flames": "st_llamas_azul", "tires": "slick"},
	"": {"two": "st_rojo_negro", "comp": "st_competicion", "flames": "st_llamas"},
}

static func _cfg(dealer: String) -> Dictionary:
	return STYLES.get(dealer, STYLES[""])

## Las versiones de un auto en ese concesionario: [{i, n, d, upg, tires, style, price, extra}] (la 0 es la de fábrica)
static func for_car(dealer: String, id: String, online := false) -> Array:
	var cm: Dictionary = CarBuild.catalog()["cars"].get(id, {})
	var base := int(cm.get("price", 0))
	var cfg := _cfg(dealer)
	var out: Array = []
	for i in TIERS.size():
		if online and i > 0:
			break
		var T: Dictionary = TIERS[i]
		var extra := 0
		var upg: Dictionary = {}
		for cat in (T["upg"] as Dictionary):
			var u := CarBuild.upgrade(str(cat))
			if u.is_empty():
				continue
			var lvl := mini(int(T["upg"][cat]), (u["levels"] as Array).size() - 1)
			if lvl <= 0:
				continue
			upg[str(cat)] = lvl
			extra += int(u["levels"][lvl].get("cost", 0)) # (en el taller también se paga sólo el nivel que se pone)
		var tires := ""
		if str(T["tires"]) != "":
			tires = str(cfg.get("tires", T["tires"]))
			if tires == str(Profile.new_car_state(id)["tires"]):
				tires = ""
			else:
				extra += int(CarBuild.tire(tires).get("cost", 0))
		var style := ""
		if str(T["style"]) != "":
			style = str(cfg.get(str(T["style"]), ""))
			if Cosmetics.item(style).is_empty():
				style = ""
			else:
				extra += Cosmetics.price(style)
		out.append({"i": i, "n": str(T["n"]), "d": str(T["d"]), "upg": upg, "tires": tires, "style": style, "price": base + extra, "extra": extra})
	return out

## Cómo queda el auto de esa versión (para la sala y los números de la tienda)
static func state(id: String, v: Dictionary) -> Dictionary:
	var st: Dictionary = Profile.new_car_state(id)
	st["upg"] = (v.get("upg", {}) as Dictionary).duplicate()
	var t := str(v.get("tires", ""))
	if t != "":
		st["tires"] = t
		(st["tiresOwned"] as Array).append(t)
	var sid := str(v.get("style", ""))
	if sid != "":
		var it := Cosmetics.item(sid)
		PaintPresets.apply(st["paint"], it["preset"])
		st["paint"]["number"] = str((it["preset"] as Dictionary).get("number", "77"))
		st["partsOwned"] = [sid]
	return st

## Compra la versión: el auto y después cada pieza con las compras de siempre. {ok, reason}
static func buy(profile: RefCounted, id: String, v: Dictionary) -> Dictionary:
	if profile.owns(id):
		return {"ok": false, "reason": "ya tenés ese auto"}
	if profile.credits < int(v["price"]):
		return {"ok": false, "reason": "No te alcanza el dinero"}
	if not profile.buy_car(id):
		return {"ok": false, "reason": "No te alcanza el dinero"}
	var upg: Dictionary = v.get("upg", {})
	for cat in upg:
		profile.buy_upgrade(id, str(cat), int(upg[cat]))
	var t := str(v.get("tires", ""))
	if t != "":
		profile.buy_tires(id, t)
	var sid := str(v.get("style", ""))
	if sid != "" and bool(Cosmetics.buy(profile, id, sid).get("ok", false)):
		var it := Cosmetics.item(sid)
		var st: Dictionary = profile.d["owned"][id]
		PaintPresets.apply(st["paint"], it["preset"])
		st["paint"]["number"] = str((it["preset"] as Dictionary).get("number", "77"))
		profile.save()
	return {"ok": true}
