extends RefCounted
## Perfil del jugador (js/profile.js): dinero, experiencia, autos con sus mejoras/pintura/ajuste, resultados de eventos y ajustes.
## Se guarda en user://profile.json.

signal changed

const CarBuild := preload("res://game/data/car_build.gd")
const TireWear := preload("res://game/car/tire_wear.gd")
const WorldProgress := preload("res://game/world/world_progress.gd")
const PartCatalog := preload("res://game/car/part_catalog.gd")
const VehicleCustomization := preload("res://game/car/vehicle_customization.gd")
const PATH := "user://profile.json"

const DEFAULT_SETTINGS := {
	"visual": "none", "shadows": true, "mirrors": true, "rearCam": false, "notes": true, "copilot": true, "chatter": "normal",
	"steerMode": "wheel", "gyro": false, "gyroSens": 50, "gameSpeed": 100, "quality": "auto", "gearbox": "auto", "volume": 80, "volEngine": 100,
	"volSurf": 30, "volAmb": 70, "volWind": 30, "volTurbo": 100, "volGear": 100, "rawShake": 25, "askSetup": true, "music": true, "simpleAudio": false, "musicMode": "menu", "volMusic": 25, "units": "kmh",
	"abs": true, "tc": 50, "stab": 30, "steerAngle": 0, "wheelReal": 0, "camera": 6, "camAdj": {}, "hud": "full", "dev": false, "lang": "auto", "haptics": 0, "gyroDead": 1.5, "gyroCurve": 1.0, "gyroSmooth": 15.0, "lens2": 0, "fx": [0, 0, 0], "fxAmt": [1.0, 1.0, 1.0], "fxOn": [true, true, true], "simLevel": "mid", "lineAssist": 0, "wheelSize": 100, "pedalSize": 100, "textures": "auto", "particles": "auto", "autoParticles": 10, "autoTex": "high", "autoRes": 0.8, "autoTrees": 3000, "autoShadows": false, "autoTier": 1, "autotuned": false, "gfxMode": "auto", "frameRes": "auto", "autoFrame": 0, "gfx": {}, "onlineScores": false, "trees": "auto", "shadowsQ": "auto", "res": 0, "showFps": false, "crewOut": false, "mapRefs": true, "diagBtn": true, "worldLife": true, "worldWeather": true, "ctrlLayout": {}, "weather": "dia", "capBtn": true, "capHud": "keep", "capQuality": "mid", "capFormat": "jpg",
}

var d: Dictionary
## La cuenta del servidor (online/account_econ.gd) cuando la economía no es local: cada premio, gasto y compra se anota ahí como un evento para que el servidor lo valide. null = todo local.
var acct: Node = null

func _init() -> void:
	d = load_data()

static func new_car_state(id: String) -> Dictionary:
	var m: Dictionary = CarBuild.catalog()["cars"].get(id, {}) # los autos ocultos (solo física: IA y pruebas) no están en el catálogo
	var t0 := str(m.get("tires", "street")) # (el monoplaza sale con slicks)
	return {"upg": {}, "tires": t0, "tiresOwned": ["street"] if t0 == "street" else ["street", t0], "tune": {}, "paint": (m.get("paint", {"body": "#1a4fe0", "accent": "#f5f5f2", "rim": "#16181c"}) as Dictionary).duplicate(), "km": 0.0, "bought": Time.get_unix_time_from_system()}

static func default_profile() -> Dictionary:
	return {"v": 1, "name": "Piloto", "credits": 5000, "fuel": 1.0, "toll_pass": 0, "migr": 1, "xp": 0, "level": 1, "owned": {}, "current": "", "events": {}, "cups": {},
		"stats": {"km": 0.0, "races": 0, "wins": 0, "podiums": 0, "events": 0, "driftBest": 0, "topSpeed": 0, "boards": {}, "traps": {}, "time": 0.0},
		"iap": {}, "settings": DEFAULT_SETTINGS.duplicate(true), "daily": {"day": "", "streak": 0}, "claimed": {}, "created": Time.get_unix_time_from_system(), "tutorial": false,
		"acct": {"uid": "", "synced": 0, "seq": 0, "pending": [], "n": 0, "seal": ""}}

func load_data() -> Dictionary:
	var def := default_profile()
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			var dd: Dictionary = parsed
			for k in def:
				if not dd.has(k):
					dd[k] = def[k]
			var st: Dictionary = def["settings"]
			for k in (dd["settings"] as Dictionary):
				st[k] = dd["settings"][k]
			dd["settings"] = st
			var stats: Dictionary = def["stats"]
			for k in (dd["stats"] as Dictionary):
				stats[k] = dd["stats"][k]
			dd["stats"] = stats
			var cars: Dictionary = CarBuild.catalog()["cars"]
			for id in (dd["owned"] as Dictionary).keys():
				if not cars.has(id):
					dd["owned"].erase(id)
				else:
					var ns := new_car_state(id)
					for k in dd["owned"][id]:
						ns[k] = dd["owned"][id][k]
					dd["owned"][id] = ns
			if int(dd.get("migr", 0)) < 1:
				# una sola vez: cámara interior con los dos pilotos como predeterminada y todos los gráficos en automático (si anda lento, el juego baja la calidad solo)
				var sets: Dictionary = dd["settings"]
				sets["camera"] = 6
				for k2 in ["quality", "textures", "particles", "trees", "shadowsQ"]:
					sets[k2] = "auto"
				sets["res"] = 0
				sets["autotuned"] = false
				dd["migr"] = 1
			if str(dd["current"]) != "" and not (dd["owned"] as Dictionary).has(dd["current"]):
				dd["current"] = (dd["owned"] as Dictionary).keys()[0] if (dd["owned"] as Dictionary).size() > 0 else ""
			return dd
	return def

func save() -> void:
	if acct != null:
		acct.stamp()
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()
	changed.emit()

var credits: int:
	get:
		return int(d["credits"])

func car() -> Dictionary:
	var c := str(d["current"])
	return d["owned"][c] if c != "" and (d["owned"] as Dictionary).has(c) else {}

func current_id() -> String:
	return str(d["current"])

func owns(id: String) -> bool:
	return (d["owned"] as Dictionary).has(id)

## Pone un auto en el garaje. `why` le dice a la cuenta del servidor de dónde salió: «starter» (el auto de partida), «iap» (lo compró en la tienda) o «adventure» (premio de la aventura)
func give(id: String, why := "") -> void:
	if not owns(id):
		d["owned"][id] = new_car_state(id)
		if acct != null and why != "":
			acct.log_event({"t": "give_car", "car": id, "why": why}, 0)
	if str(d["current"]) == "":
		d["current"] = id
	save()

func select(id: String) -> void:
	if owns(id):
		d["current"] = id
		save()

## Gasta créditos. `kind` (nafta, peaje, pintura…) es sólo para el registro de la cuenta del servidor
func spend(n: int, kind := "misc") -> bool:
	if kind in SHOP_KINDS:
		if not _take_shop(n, {"t": "spend", "amount": n, "kind": kind}):
			return false
		save()
		return true
	if not _take(n):
		return false
	if acct != null and n > 0:
		acct.log_event({"t": "spend", "amount": n, "kind": kind}, -n)
	save()
	return true

## Descuenta sin anotar nada en la cuenta (lo usan las compras, que anotan su propio evento)
func _take(n: int) -> bool:
	if credits < n:
		return false
	d["credits"] = credits - n
	return true

## Gastos sueltos que también se pagan con el vale de taller (reglajes; el servidor usa la misma lista)
const SHOP_KINDS := ["tune", "repair"]

## Vale de taller (premio de los eventos del servidor): un saldo aparte que sólo se gasta en el taller (mejoras, gomas, piezas, diseños y reglajes).
## Lo maneja el servidor (account_econ.voucher); acá se descuenta al instante y se corrige al sincronizar.
func voucher() -> int:
	return int(d.get("voucher", 0))

## ¿Alcanza para una compra del taller? (créditos + vale)
func can_shop(n: int) -> bool:
	return credits + voucher() >= n

## Como _take, pero primero usa el vale. Anota el evento `e` de la cuenta con lo que se pagó en créditos (y en «v» lo que puso el vale, para el perfil)
func _take_shop(n: int, e: Dictionary) -> bool:
	var v := mini(voucher(), maxi(0, n))
	if credits < n - v:
		return false
	d["voucher"] = voucher() - v
	d["credits"] = credits - (n - v)
	if acct != null and n > 0:
		if v > 0:
			e["v"] = v
		acct.log_event(e, -(n - v))
	return true

## Premio en créditos. `kind` y `ref` (qué carrera, qué logro) le sirven al servidor para no pagar dos veces lo mismo y para poner topes
## `extra` (opcional) viaja con el evento a la cuenta del servidor: {first: true, rep: monto de repetición} para las primeras victorias y {m, b, h, w, p}
## (medalla, mejor tiempo, mejor puntaje, victorias, jugadas) para que el progreso quede en la cuenta y vuelva al reinstalar (migración 20261022).
func earn(n: float, kind := "misc", ref := "", extra := {}) -> void:
	d["credits"] = credits + roundi(n)
	if acct != null and roundi(n) > 0:
		var e := {"t": "earn", "amount": roundi(n), "kind": kind, "ref": ref}
		e.merge(extra)
		acct.log_event(e, roundi(n))
	save()

## Progreso sin plata (medalla, mejor tiempo, carrera descubierta) para la cuenta del servidor: key «owev:<id>» o «race:<id>»
func progress(key: String, data := {}) -> void:
	if acct != null:
		var e := {"t": "prog", "key": key}
		e.merge(data)
		acct.log_event(e, 0)

func buy_car(id: String) -> bool:
	var m: Dictionary = CarBuild.catalog()["cars"][id]
	if owns(id) or not _take(int(m["price"])):
		return false
	give(id)
	if acct != null:
		acct.log_event({"t": "buy_car", "car": id}, -int(m["price"]))
	d["current"] = id
	save()
	return true

func sell_value(id: String) -> int:
	return roundi(float(CarBuild.catalog()["cars"][id]["price"]) * 0.5)

# piezas
func upgrade_level(id: String, cat: String) -> int:
	return int((d["owned"][id]["upg"] as Dictionary).get(cat, 0))

func buy_upgrade(id: String, cat: String, level: int) -> bool:
	var u := CarBuild.upgrade(cat)
	if u.is_empty() or not owns(id):
		return false
	var car_d: Dictionary = d["owned"][id]
	if level < 0 or level >= (u["levels"] as Array).size():
		return false
	var cur := int((car_d["upg"] as Dictionary).get(cat, 0))
	if level == cur:
		return false
	if level < cur:
		car_d["upg"][cat] = level # bajar de nivel: gratis (las piezas quedan guardadas)
		save()
		return true
	if not car_d.has("owned"):
		car_d["owned"] = {}
	var key := "%s:%d" % [cat, level]
	if not car_d["owned"].has(key):
		var cost := int(u["levels"][level].get("cost", 0))
		if not _take_shop(cost, {"t": "buy_upgrade", "car": id, "cat": cat, "level": level}):
			return false
		car_d["owned"][key] = 1
	car_d["upg"][cat] = level
	save()
	return true

func part_owned(id: String, cat: String, level: int) -> bool:
	if not owns(id):
		return false
	var car_d: Dictionary = d["owned"][id]
	return level == 0 or (car_d.has("owned") and car_d["owned"].has("%s:%d" % [cat, level])) or int((car_d["upg"] as Dictionary).get(cat, 0)) == level

func buy_tires(id: String, tid: String) -> bool:
	if not owns(id):
		return false
	var car_d: Dictionary = d["owned"][id]
	var t := CarBuild.tire(tid)
	if not (car_d["tiresOwned"] as Array).has(tid):
		if not _take_shop(int(t["cost"]), {"t": "buy_tires", "car": id, "tire": tid}):
			return false
		car_d["tiresOwned"].append(tid)
	car_d["tires"] = tid
	save()
	return true

## Desgaste de un juego de gomas del auto id (0 = nuevas … 1 = lisas); cada juego comprado guarda el suyo
func tire_wear(id: String, tid := "") -> float:
	if not owns(id):
		return 0.0
	var car_d: Dictionary = d["owned"][id]
	var t := tid if tid != "" else str(car_d.get("tires", "street"))
	return float((car_d.get("tireWear", {}) as Dictionary).get(t, 0.0))

## Cambiar el juego de gomas puesto por uno nuevo (del mismo tipo): cuesta la mitad de lo que valen. Devuelve el precio pagado, o -1 si no alcanzó el dinero.
func replace_tires(id: String) -> int:
	if not owns(id):
		return -1
	var car_d: Dictionary = d["owned"][id]
	var t := str(car_d.get("tires", "street"))
	var rep: Variant = d.get("worldRep")
	var rk := WorldProgress.rank_for(float((rep as Dictionary).get("pts", 0.0))) if rep is Dictionary else 0
	var cost := int(round(float(TireWear.replace_cost(float(CarBuild.tire(t).get("cost", 0)))) * WorldProgress.tire_price_k(rk)))
	if not _take_shop(cost, {"t": "replace_tires", "car": id, "tire": t, "cost": cost}):
		return -1
	var tw: Dictionary = car_d.get("tireWear", {})
	tw[t] = 0.0
	car_d["tireWear"] = tw
	save()
	return cost

## Piezas modulares (llantas, etc.): se compran una vez por auto y se pueden cambiar gratis. Offline = estado local; el online usa su propia instancia validada por el servidor.
func buy_part(id: String, part_id: String, vehicles: Dictionary) -> Dictionary:
	if not owns(id):
		return {"ok": false, "reason": "no tenés ese auto"}
	var car_d: Dictionary = d["owned"][id]
	var ctx := VehicleCustomization.context(id, vehicles, car_d)
	var c := VehicleCustomization.can_install(part_id, id, ctx["V"], ctx["meta"])
	if not bool(c["ok"]):
		return c
	var own: Array = car_d.get("partsOwned", [])
	if not own.has(part_id):
		var price := int(PartCatalog.part(part_id).get("price", 0))
		if not _take_shop(price, {"t": "buy_part", "car": id, "part": part_id}):
			return {"ok": false, "reason": "no alcanza el dinero"}
		own.append(part_id)
		car_d["partsOwned"] = own
	var r := VehicleCustomization.install(car_d, id, part_id, ctx["V"], ctx["meta"])
	save()
	return r

func remove_part(id: String, category: String) -> void:
	if owns(id):
		VehicleCustomization.remove(d["owned"][id], category)
		save()

# experiencia
static func xp_for_level(l: int) -> int:
	return roundi(1100.0 * pow(float(l), 1.5))

func add_xp(n: float) -> Array:
	d["xp"] = int(d["xp"]) + roundi(n)
	var ups := []
	while int(d["xp"]) >= xp_for_level(int(d["level"])):
		d["xp"] = int(d["xp"]) - xp_for_level(int(d["level"]))
		d["level"] = int(d["level"]) + 1
		var bonus := 300 + int(d["level"]) * 100
		d["credits"] = credits + bonus
		if acct != null:
			acct.log_event({"t": "earn", "amount": bonus, "kind": "level", "ref": "lv%d" % int(d["level"])}, bonus)
		ups.append({"level": d["level"], "bonus": bonus})
	save()
	return ups

# resultados de eventos
func event_result(eid: String) -> Dictionary:
	return d["events"].get(eid, {})

func stars() -> int:
	var n := 0
	for k in (d["events"] as Dictionary):
		n += int(d["events"][k].get("medal", 0))
	return n

func record_event(eid: String, value: float, medal: int, lower_is_better: bool) -> Dictionary:
	var cur: Dictionary = d["events"].get(eid, {"medal": 0, "best": null})
	var best = cur.get("best")
	var better: bool = best == null or (value < float(best) if lower_is_better else value > float(best))
	if better:
		cur["best"] = value
	var first_medal := medal > int(cur["medal"])
	cur["medal"] = maxi(int(cur["medal"]), medal)
	cur["done"] = true
	cur["plays"] = int(cur.get("plays", 0)) + 1
	d["events"][eid] = cur
	save()
	return {"improved": better, "firstMedal": first_medal}

func daily_check() -> Dictionary:
	var today := Time.get_date_string_from_system(acct != null) # con la cuenta del servidor el día cambia a la medianoche UTC (como en el servidor)
	var dl: Dictionary = d["daily"]
	if dl["day"] == today:
		return {}
	var y := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	dl["streak"] = mini(7, int(dl["streak"]) + 1) if dl["day"] == y else 1
	dl["day"] = today
	var amount := 300 + int(dl["streak"]) * 150
	d["credits"] = credits + amount
	if acct != null:
		acct.log_event({"t": "daily"}, amount)
	save()
	return {"amount": amount, "streak": dl["streak"]}

func reset() -> void:
	d = default_profile()
	save()

func setting(k: String):
	return d["settings"].get(k, DEFAULT_SETTINGS.get(k))

func set_setting(k: String, v) -> void:
	d["settings"][k] = v
	save()
