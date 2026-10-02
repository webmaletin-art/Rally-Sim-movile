extends RefCounted
## Perfil del jugador (js/profile.js): dinero, experiencia, autos con sus mejoras/pintura/ajuste, resultados de eventos y ajustes.
## Se guarda en user://profile.json.

signal changed

const CarBuild := preload("res://game/data/car_build.gd")
const PATH := "user://profile.json"

const DEFAULT_SETTINGS := {
	"visual": "none", "shadows": true, "mirrors": true, "rearCam": false, "notes": true, "copilot": true, "chatter": "normal",
	"steerMode": "wheel", "gyro": false, "gyroSens": 50, "gameSpeed": 100, "quality": "auto", "gearbox": "auto", "volume": 80, "volEngine": 100,
	"volSurf": 30, "volWind": 30, "volTurbo": 100, "volGear": 100, "rawShake": 25, "askSetup": true, "music": true, "units": "kmh",
	"abs": true, "tc": 50, "stab": 30, "camera": 6, "camAdj": {}, "hud": "full", "dev": false, "lang": "auto", "haptics": 0, "gyroDead": 1.5, "gyroCurve": 1.0, "gyroSmooth": 15.0, "lens2": 0, "fx": [0, 0, 0], "fxAmt": [1.0, 1.0, 1.0], "fxOn": [true, true, true], "simLevel": "mid", "lineAssist": 0, "wheelSize": 100, "pedalSize": 100, "textures": "auto", "particles": "auto", "autoParticles": 10, "autoTex": "high", "autoRes": 0.8, "autoTrees": 3000, "autoShadows": false, "autoTier": 1, "autotuned": false, "onlineScores": false, "trees": "auto", "shadowsQ": "auto", "res": 0, "weather": "dia", "capBtn": true, "capHud": "keep", "capQuality": "mid", "capFormat": "jpg",
}

var d: Dictionary

func _init() -> void:
	d = load_data()

static func new_car_state(id: String) -> Dictionary:
	var m: Dictionary = CarBuild.catalog()["cars"][id]
	return {"upg": {}, "tires": "street", "tiresOwned": ["street"], "tune": {}, "paint": (m["paint"] as Dictionary).duplicate(), "km": 0.0, "bought": Time.get_unix_time_from_system()}

static func default_profile() -> Dictionary:
	return {"v": 1, "name": "Piloto", "credits": 5000, "xp": 0, "level": 1, "owned": {}, "current": "", "events": {}, "cups": {},
		"stats": {"km": 0.0, "races": 0, "wins": 0, "podiums": 0, "events": 0, "driftBest": 0, "topSpeed": 0, "boards": {}, "traps": {}, "time": 0.0},
		"iap": {}, "settings": DEFAULT_SETTINGS.duplicate(true), "daily": {"day": "", "streak": 0}, "claimed": {}, "created": Time.get_unix_time_from_system(), "tutorial": false}

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
			if str(dd["current"]) != "" and not (dd["owned"] as Dictionary).has(dd["current"]):
				dd["current"] = (dd["owned"] as Dictionary).keys()[0] if (dd["owned"] as Dictionary).size() > 0 else ""
			return dd
	return def

func save() -> void:
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

func give(id: String) -> void:
	if not owns(id):
		d["owned"][id] = new_car_state(id)
	if str(d["current"]) == "":
		d["current"] = id
	save()

func select(id: String) -> void:
	if owns(id):
		d["current"] = id
		save()

func spend(n: int) -> bool:
	if credits < n:
		return false
	d["credits"] = credits - n
	save()
	return true

func earn(n: float) -> void:
	d["credits"] = credits + roundi(n)
	save()

func buy_car(id: String) -> bool:
	var m: Dictionary = CarBuild.catalog()["cars"][id]
	if owns(id) or not spend(int(m["price"])):
		return false
	give(id)
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
		if not spend(int(u["levels"][level].get("cost", 0))):
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
		if not spend(int(t["cost"])):
			return false
		car_d["tiresOwned"].append(tid)
	car_d["tires"] = tid
	save()
	return true

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
	var today := Time.get_date_string_from_system()
	var dl: Dictionary = d["daily"]
	if dl["day"] == today:
		return {}
	var y := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
	dl["streak"] = mini(7, int(dl["streak"]) + 1) if dl["day"] == y else 1
	dl["day"] = today
	var amount := 300 + int(dl["streak"]) * 150
	d["credits"] = credits + amount
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
