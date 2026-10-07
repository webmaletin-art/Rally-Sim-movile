extends RefCounted
## Medallas, créditos y experiencia de un resultado (medalFor / rewardFor de js/events.js + showResults de js/main.js).

const CarBuild := preload("res://game/data/car_build.gd")
const MapData := preload("res://game/data/map_data.gd")

static func event_by_id(id: String) -> Dictionary:
	for e in CarBuild.catalog()["events"]:
		if e["id"] == id:
			return e
	return {}

static func tier_by_id(id: String) -> Dictionary:
	for t in CarBuild.catalog()["tiers"]:
		if t["id"] == id:
			return t
	return {}

static func events_of(tier_id: String) -> Array:
	var out: Array = []
	for e in CarBuild.catalog()["events"]:
		if e["tier"] == tier_id:
			out.append(e)
	return out

static var _maps: Dictionary

## ¿Se puede jugar este evento con lo que ya está portado? (carrera, contrarreloj y radar sobre una ruta, y drift en la plaza)
static func playable(ev: Dictionary) -> bool:
	if _maps.is_empty():
		_maps = MapData.maps()
	var mp: Dictionary = _maps.get(str(ev["map"]), {})
	if str(mp.get("kind", "")) == "drift":
		return str(ev["type"]) == "drift"
	return str(mp.get("kind", "")) in ["route", "dream"] and str(ev["type"]) in ["race", "timetrial", "trap"]

## Estrellas que pide una copa: mientras falten tipos de evento por portar, se pide como mucho el 70% de lo que se puede ganar antes
static func stars_needed(tier: Dictionary) -> int:
	var avail := 0
	for t in CarBuild.catalog()["tiers"]:
		if t["id"] == tier["id"]:
			break
		for e in events_of(str(t["id"])):
			if playable(e):
				avail += 3
	return mini(int(tier["stars"]), int(floor(float(avail) * 0.7)))

static func lower_is_better(type: String) -> bool:
	return type == "timetrial" or type == "parking"

static func medal_for(ev: Dictionary, value: float) -> int:
	if ev["type"] == "race":
		return 3 if value == 1.0 else (2 if value == 2.0 else (1 if value == 3.0 else 0))
	var targets: Dictionary = CarBuild.catalog()["targets"]
	if not targets.has(ev["id"]):
		return 0
	var t: Array = targets[ev["id"]]
	if lower_is_better(str(ev["type"])):
		if value <= float(t[0]):
			return 3
		if value <= float(t[1]):
			return 2
		if value <= float(t[2]):
			return 1
		return 0
	if value >= float(t[0]):
		return 3
	if value >= float(t[1]):
		return 2
	if value >= float(t[2]):
		return 1
	return 0

static func reward_for(ev: Dictionary, medal: int, tier: Dictionary) -> Dictionary:
	var base := float(tier["base"]) * (1.6 if ev.get("final", false) else 1.0)
	# premio justo: 1° 100 %, 2° 60 %, 3° 40 %, 4° o peor 20 % (carreras); en pruebas por medalla: oro 100 %, plata 60 %, bronce 40 %, sin medalla 10 %
	var mult: float = ([0.2, 0.4, 0.6, 1.0] if str(ev.get("type", "")) == "race" else [0.1, 0.4, 0.6, 1.0])[medal]
	return {"cr": int(round(base * mult / 10.0)) * 10, "xp": int(round((250.0 + float(tier["base"]) * 0.12) * (0.4 + float(medal) * 0.3) * (1.5 if ev.get("final", false) else 1.0)))}

## ¿Está abierto el evento? Devuelve "" si sí, o el motivo. Los eventos que todavía no se pueden jugar no traban a los siguientes.
static func event_locked(profile: RefCounted, ev: Dictionary) -> String:
	if preload("res://game/data/release.gd").dev(profile):
		return ""
	var lst: Array = []
	for e in events_of(str(ev["tier"])):
		if playable(e):
			lst.append(e)
	var i := lst.find(ev)
	if i <= 0:
		return ""
	var m := func(id: String) -> int: return int(profile.event_result(id).get("medal", 0))
	if ev.get("final", false):
		var miss := 0
		for k in i:
			if m.call(lst[k]["id"]) < 1:
				miss += 1
		return "Conseguí medalla en todas las anteriores (faltan %d)" % miss if miss > 0 else ""
	return "" if m.call(lst[i - 1]["id"]) >= 1 else "Conseguí medalla en «%s»" % lst[i - 1]["name"]

static func tier_open(profile: RefCounted, tier: Dictionary) -> bool:
	if not preload("res://game/data/release.gd").tier_allowed(profile, str(tier["id"])):
		return false
	if preload("res://game/data/release.gd").dev(profile):
		return true # modo desarrollador: todas las copas abiertas
	if tier.has("car") and not profile.owns(str(tier["car"])):
		return false
	return profile.stars() >= stars_needed(tier)

## Aplica un resultado al perfil y devuelve lo que muestra la pantalla de resultados
static func apply(profile: RefCounted, cfg: Dictionary, r: Dictionary) -> Dictionary:
	var out := r.duplicate()
	var d: Dictionary = profile.d
	var st: Dictionary = d["stats"]
	var km: float = float(r.get("odo", 0.0)) / 1000.0
	if km > 0.0:
		st["km"] = float(st["km"]) + km
		if profile.car().has("km") and cfg.get("testCar") == null:
			profile.car()["km"] = float(profile.car()["km"]) + km
	st["events"] = int(st["events"]) + 1
	st["topSpeed"] = maxf(float(st["topSpeed"]), roundf(float(r.get("max_kmh", 0.0))))
	var medal := 0
	var cr := 0
	var xp := 0
	var record := false
	var ev: Dictionary = cfg.get("event", {})
	var t := str(r["type"])
	var show_medal := false
	if not ev.is_empty():
		var tier: Dictionary = cfg["tier"]
		medal = medal_for(ev, float(r["value"]))
		var rw := reward_for(ev, medal, tier)
		# repetir lo mismo paga cada vez menos (la 1ª vez 100 %, la 2ª 60 %, la 3ª 35 %, después 20 %)
		var plays := int(profile.event_result(str(ev["id"])).get("plays", 0))
		var decay: float = [1.0, 0.6, 0.35][plays] if plays < 3 else 0.2
		cr = int(round(float(rw["cr"]) * decay / 10.0)) * 10
		xp = int(round(float(rw["xp"]) * decay))
		var rec: Dictionary = profile.record_event(str(ev["id"]), float(r["value"]), medal, lower_is_better(str(ev["type"])))
		record = bool(rec["improved"]) and int(profile.event_result(str(ev["id"])).get("plays", 0)) > 1
		if bool(rec["firstMedal"]) and medal == 3:
			cr += int(round(float(tier["base"]) * 0.25))
		show_medal = true
	elif cfg.get("quick", false):
		if t == "race":
			var n := int(r["value"])
			medal = 3 if n == 1 else (2 if n == 2 else (1 if n == 3 else 0))
			# Carrera rápida paga poquito (es práctica): por vuelta y rivales, con tope, y por puesto como en la Copa
			var laps := maxi(1, int(cfg.get("laps", 1)))
			if str(cfg.get("rule", "")) != "":
				laps = 3 # persecución / eliminación no tienen vueltas: paga como una carrera corta
			var pos := int(r["value"])
			var by_pos: float = [1.0, 0.6, 0.4, 0.2][pos - 1] if pos >= 1 and pos <= 4 else 0.08
			cr = mini(400, int(round(50.0 * float(laps) * (1.0 + float(cfg.get("ai", 0)) / 6.0) * by_pos / 10.0)) * 10)
			xp = int(round((40.0 * laps + medal * 30.0)))
			show_medal = true
		elif t == "drift":
			cr = mini(700, int(round(float(r["value"]) / 90.0 / 10.0)) * 10)
			xp = int(round(float(r["value"]) / 120.0))
			if r.get("duel", false) == true:
				cr = int(round(float(cr) * (1.5 if r.get("win", false) == true else 0.7) / 10.0)) * 10 # ganarle al bot paga más
			show_medal = false
		elif t == "convoy":
			# Travesía X: se cobra por llegar con el grupo, más cuanto más unido hayas ido
			var coh := clampf(float(r.get("cohesion", 0.0)), 0.0, 1.0)
			if r.get("win", false) == true:
				medal = 3 if coh > 0.8 else (2 if coh > 0.55 else 1)
				cr = 600 + int(round(coh * 60.0)) * 10
				xp = 250 + int(round(coh * 200.0))
			else:
				xp = 40
			show_medal = true
		else:
			cr = 120
			xp = 50
	var practice: bool = cfg.get("testCar", false) == true or cfg.get("labbed", false) == true # prueba de un auto o con el taller de la pausa: no paga ni cuenta
	if practice:
		cr = 0
		xp = 0
	if t == "drift" and not practice:
		st["driftBest"] = maxf(float(st["driftBest"]), float(r["value"]))
	if t == "race" and not practice:
		st["races"] = int(st["races"]) + 1
		if int(r["value"]) == 1:
			st["wins"] = int(st["wins"]) + 1
		if int(r["value"]) <= 3:
			st["podiums"] = int(st["podiums"]) + 1
	var cup_msg := ""
	if not ev.is_empty():
		var tier2: Dictionary = cfg["tier"]
		var all_done := true
		for e in events_of(str(tier2["id"])):
			if int(profile.event_result(str(e["id"])).get("medal", 0)) < 1:
				all_done = false
		if all_done and not (d["cups"] as Dictionary).has(tier2["id"]):
			d["cups"][tier2["id"]] = 1
			var bonus := int(round(float(tier2["base"]) * 2.0))
			cr += bonus
			xp += 1500
			cup_msg = "🏆 ¡%s completada! +%s" % [tier2["name"], "$ " + str(bonus)]
	cr = int(round(float(cr) / 10.0)) * 10
	profile.earn(cr)
	var ups: Array = profile.add_xp(xp)
	out["cup_msg"] = cup_msg
	out["medal"] = medal
	out["cr"] = cr
	out["xp"] = xp
	out["record"] = record
	out["level_ups"] = ups
	out["show_medal"] = show_medal
	out["event_name"] = str(ev.get("name", "Carrera rápida"))
	out["cfg"] = cfg
	profile.save()
	return out

static func ach_done(profile: RefCounted, id: String) -> bool:
	var d: Dictionary = profile.d
	var st: Dictionary = d["stats"]
	match id:
		"win1": return int(st["wins"]) >= 1
		"win5": return int(st["wins"]) >= 5
		"win15": return int(st["wins"]) >= 15
		"pod10": return int(st["podiums"]) >= 10
		"km50": return float(st["km"]) >= 50.0
		"km250": return float(st["km"]) >= 250.0
		"spd200": return float(st["topSpeed"]) >= 200.0
		"spd250": return float(st["topSpeed"]) >= 250.0
		"drift5k": return float(st["driftBest"]) >= 5000.0
		"drift15k": return float(st["driftBest"]) >= 15000.0
		"board6": return (st["boards"] as Dictionary).size() >= 6
		"board12": return (st["boards"] as Dictionary).size() >= 12
		"trap150":
			for v in (st["traps"] as Dictionary).values():
				if float(v) >= 150.0:
					return true
			return false
		"cars2": return (d["owned"] as Dictionary).size() >= 2
		"cars4": return (d["owned"] as Dictionary).size() >= 4
		"gold10":
			var n := 0
			for k in d["events"]:
				if int(d["events"][k].get("medal", 0)) == 3:
					n += 1
			return n >= 10
		"cup1": return (d["cups"] as Dictionary).size() >= 1
		"lvl10": return int(d["level"]) >= 10
	return false

static func ach_ready(profile: RefCounted) -> int:
	var n := 0
	for a in CarBuild.catalog()["achievements"]:
		if not (profile.d["claimed"] as Dictionary).has(a["id"]) and ach_done(profile, str(a["id"])):
			n += 1
	return n
