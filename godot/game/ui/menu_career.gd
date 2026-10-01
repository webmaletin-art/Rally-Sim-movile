extends RefCounted
## Pantallas del modo carrera (copas, eventos, detalle) y de la carrera rápida.

const Kit := preload("res://game/ui/ui_kit.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Rewards := preload("res://game/data/rewards.gd")

const SKY_N := {"day": "☀ Día", "sunset": "🌇 Atardecer", "overcast": "☁ Nublado", "dusk": "🌆 Anochecer", "rain": "🌧 Lluvia"}
const MEDAL_N := ["Sin medalla", "Bronce", "Plata", "Oro"]

var m # menu.gd
var maps: Dictionary
var quick := {"map": "lake", "mode": "race", "laps": 2, "ai": 3, "sky": "day", "skill": 1.0}

func _maps() -> Dictionary:
	if maps.is_empty():
		maps = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	return maps

func map_name(id: String) -> String:
	return str(_maps().get(id, {}).get("name", id))

## ¿Se puede jugar este evento en la versión Godot? (hoy: los que corren sobre una ruta)
func playable(ev: Dictionary) -> bool:
	return Rewards.playable(ev)

func build(name: String, arg) -> void:
	match name:
		"career": _tiers()
		"events": _events(str(arg))
		"event": _event(str(arg))
		"quick": _quick()

func _medals(n: int) -> String:
	return "●".repeat(n) + "○".repeat(3 - n)

func _medal_color(n: int) -> Color:
	return [Kit.MUTED, Color(0.85, 0.55, 0.3), Color(0.8, 0.85, 0.92), Kit.GOLD][n]

func _row_button(head: String, title: String, sub: String, right: String, cb: Callable, col: Color, enabled := true, accent := false) -> Button:
	var b := Kit.button("", Callable(), accent, 20, Vector2(0, 76))
	b.disabled = not enabled
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := Kit.hbox(12)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var hl := Kit.label(head, 34, col if enabled else Kit.MUTED)
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hl)
	var v := Kit.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	v.add_child(Kit.label(title, 22, Kit.TEXT if enabled else Kit.MUTED))
	var sl := Kit.label(sub, 15, Kit.MUTED)
	sl.clip_text = true
	sl.custom_minimum_size.x = 100
	v.add_child(sl)
	var rl := Kit.label(right, 18, Kit.GOLD if enabled else Kit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(rl)
	b.pressed.connect(func() -> void:
		if Kit.scroll_moved:
			Kit.scroll_moved = false
			return
		m.sfx.play("click")
		cb.call())
	return b

# ───────────────────────── copas ─────────────────────────
func _tiers() -> void:
	m.set_title("CARRERA")
	var cur_pi := _player_pi()
	for t in CarBuild.catalog()["tiers"]:
		var open := Rewards.tier_open(m.profile, t)
		var evs := Rewards.events_of(str(t["id"]))
		var done := 0
		for e in evs:
			if int(m.profile.event_result(str(e["id"])).get("medal", 0)) > 0:
				done += 1
		var sub := str(t["sub"])
		var right := "%d/%d" % [done, evs.size()]
		if not open:
			if t.has("car") and not m.profile.owns(str(t["car"])):
				right = "🔒 necesitás el %s" % CarBuild.catalog()["cars"][t["car"]]["model"]
			else:
				right = "🔒 %d ⭐" % Rewards.stars_needed(t)
		var tt: Dictionary = t
		m.body.add_child(_row_button(str(t["icon"]), str(t["name"]), sub, right, func(): _open_tier(tt), Kit.hexc(t["color"]), true))

func _open_tier(t: Dictionary) -> void:
	if not Rewards.tier_open(m.profile, t):
		m.sfx.play("error")
		if t.has("car") and not m.profile.owns(str(t["car"])):
			m.toast("Necesitás el %s %s" % [CarBuild.catalog()["cars"][t["car"]]["brand"], CarBuild.catalog()["cars"][t["car"]]["model"]])
		else:
			m.toast("Necesitás %d ⭐ para abrir esta copa (tenés %d)" % [Rewards.stars_needed(t), m.profile.stars()])
		return
	m.go("events", t["id"])

func _player_pi() -> int:
	var id: String = m.profile.current_id()
	return int(CarBuild.perf_of(CarBuild.build_params(m.vehicles[id], m.profile.car()))["pi"])

# ───────────────────────── eventos de una copa ─────────────────────────
func _events(tier_id: String) -> void:
	var tier := Rewards.tier_by_id(tier_id)
	m.set_title(str(tier["name"]).to_upper())
	var lst := Rewards.events_of(tier_id)
	var i := 0
	for e in lst:
		i += 1
		var lk := Rewards.event_locked(m.profile, e)
		var res: Dictionary = m.profile.event_result(str(e["id"]))
		var medal := int(res.get("medal", 0))
		var can := playable(e)
		var ti: Dictionary = CarBuild.catalog()["types"][e["type"]]
		var rw := Rewards.reward_for(e, 3, tier)
		var sub := "%s · %s" % [map_name(str(e["map"])), SKY_N.get(str(e.get("sky", "day")), "")]
		var right := "%s\n%s" % [_medals(medal), Kit.fmt_cr(float(rw["cr"]))]
		if not can:
			right = "🚧 pronto"
		elif lk != "":
			right = "🔒"
		var head := "%d" % i
		var ev: Dictionary = e
		var b := _row_button(head, "%s %s%s" % [ti["icon"], e["name"], "  · FINAL" if e.get("final", false) else ""], sub, right, func(): _open_event(ev, lk), Kit.hexc(tier["color"]), lk == "" or true)
		m.body.add_child(b)

func _open_event(ev: Dictionary, lk: String) -> void:
	if lk != "":
		m.sfx.play("error")
		m.toast(lk)
		return
	m.go("event", ev["id"])

# ───────────────────────── detalle del evento ─────────────────────────
func _fmt_target(ev: Dictionary, v: float) -> String:
	match str(ev["type"]):
		"timetrial", "parking": return Kit.fmt_time(v)
		"trap": return "%d km/h" % int(v)
		"drift": return "%d pts" % int(v)
	return str(v)

func _event(id: String) -> void:
	var ev := Rewards.event_by_id(id)
	var tier := Rewards.tier_by_id(str(ev["tier"]))
	var ti: Dictionary = CarBuild.catalog()["types"][ev["type"]]
	m.set_title(str(ev["name"]))
	var dl := Kit.label(str(ev["desc"]), 18, Kit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = 380
	m.body.add_child(dl)
	var res: Dictionary = m.profile.event_result(id)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 26)
	m.body.add_child(g)
	var len_s := "%d vuelta%s" % [int(ev.get("laps", 1)), "s" if int(ev.get("laps", 1)) > 1 else ""] if not ev.has("seg") else "Tramo de ruta"
	var rows := [["Tipo", "%s %s" % [ti["icon"], ti["n"]]], ["Pista", map_name(str(ev["map"]))], ["Formato", len_s], ["Rivales", str(ev.get("ai", "—"))],
		["Clima", SKY_N.get(str(ev.get("sky", "day")), "-")], ["Récord", _fmt_target(ev, float(res["best"])) if res.has("best") and res["best"] != null else "—"],
		["Medalla", MEDAL_N[int(res.get("medal", 0))]]]
	for r in rows:
		g.add_child(Kit.label(r[0], 18, Kit.MUTED))
		g.add_child(Kit.label(r[1], 18, Kit.TEXT))
	# objetivos de medalla
	var targets: Dictionary = CarBuild.catalog()["targets"]
	if ev["type"] == "race":
		m.body.add_child(Kit.label("🥇 1° puesto · 🥈 2° · 🥉 3°", 18, Kit.TEXT))
	elif targets.has(id):
		var t: Array = targets[id]
		m.body.add_child(Kit.label("🥇 %s   🥈 %s   🥉 %s" % [_fmt_target(ev, t[0]), _fmt_target(ev, t[1]), _fmt_target(ev, t[2])], 18, Kit.TEXT))
	var rws: Array = []
	for md in [3, 2, 1]:
		rws.append(Kit.fmt_cr(float(Rewards.reward_for(ev, md, tier)["cr"])))
	m.body.add_child(Kit.label("Premios: oro %s · plata %s · bronce %s" % rws, 16, Kit.GOLD))
	# bloqueos
	var block := ""
	var pid: String = m.profile.current_id()
	if not playable(ev):
		block = "🚧 Este tipo de evento (%s) llega en una próxima versión del juego nuevo." % ti["n"]
	elif tier.has("car") and pid != str(tier["car"]):
		block = "Esta copa se corre solo con el %s. Elegilo en el garaje." % CarBuild.catalog()["cars"][tier["car"]]["model"]
	else:
		var pi := _player_pi()
		if not tier.has("car") and pi > int(tier["maxPI"]):
			block = "Tu auto es clase %s (PI %d). Esta copa admite hasta clase %s (PI %d). Bajá piezas en el taller o usá otro auto." % [
				CarBuild.class_of(pi)["c"], pi, CarBuild.class_of(int(tier["maxPI"]))["c"], int(tier["maxPI"])]
	if block != "":
		var bl := Kit.label(block, 18, Kit.RED)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size.x = 380
		m.body.add_child(bl)
	var go_b := Kit.button("¡CORRER!", func(): _start_event(ev, tier), true, 28, Vector2(0, 66))
	go_b.disabled = block != ""
	m.body.add_child(go_b)

func _start_event(ev: Dictionary, tier: Dictionary, ask := true) -> void:
	var pid: String = m.profile.current_id()
	var cfg := {"type": ev["type"], "track": ev["map"], "laps": int(ev.get("laps", 1)), "ai": int(ev.get("ai", 0)), "time": ev.get("time", 0), "sky": ev.get("sky", "day"),
		"maxPI": int(tier["maxPI"]), "skill": float(tier["skill"]) * (1.03 if ev.get("final", false) else 1.0), "aiCar": str(tier.get("car", "")), "event": ev, "tier": tier,
		"seed": int(str(ev["id"]).unicode_at(1)), "car": pid, "state": m.profile.car(), "back": "events:" + str(tier["id"])}
	if ev.has("seg"):
		cfg["seg"] = ev["seg"]
	m.launch(cfg, ask)

# ───────────────────────── carrera rápida ─────────────────────────
func _quick() -> void:
	m.set_title("CARRERA RÁPIDA")
	var route_maps: Array = []
	for k in _maps():
		if str(_maps()[k].get("kind", "")) == "route" and not _maps()[k].get("hidden", false) and not _maps()[k].get("trench", false):
			route_maps.append(k)
	var opts := [
		["Pista", "map", route_maps, func(v): return map_name(str(v))],
		["Modo", "mode", ["race", "timetrial"], func(v): return "Carrera" if v == "race" else "Contrarreloj"],
		["Vueltas", "laps", [1, 2, 3, 5], func(v): return str(v)],
		["Rivales", "ai", [0, 1, 3, 5, 7], func(v): return str(v)],
		["Clima", "sky", ["day", "overcast", "sunset", "dusk", "rain"], func(v): return SKY_N[v]],
		["Nivel de los rivales", "skill", [0.85, 1.0, 1.08], func(v): return {0.85: "Fácil", 1.0: "Normal", 1.08: "Difícil"}[v]],
	]
	for o in opts:
		var key: String = o[1]
		var vals: Array = o[2]
		var fmt: Callable = o[3]
		var b := Kit.button("%s:  %s" % [o[0], fmt.call(quick[key])], Callable(), false, 20, Vector2(0, 52))
		b.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			var i := vals.find(quick[key])
			quick[key] = vals[(i + 1) % vals.size()]
			m.sfx.play("click")
			b.text = "%s:  %s" % [o[0], fmt.call(quick[key])])
		m.body.add_child(b)
	m.body.add_child(Kit.button("¡CORRER!", func(): _start_quick(), true, 28, Vector2(0, 66)))

func _start_quick() -> void:
	var pid: String = m.profile.current_id()
	var pi := _player_pi()
	var q := quick
	var cfg := {"type": q["mode"], "track": q["map"], "laps": int(q["laps"]), "ai": int(q["ai"]) if q["mode"] == "race" else 0, "sky": q["sky"], "maxPI": maxi(560, pi + 20),
		"skill": 0.9 * float(q["skill"]), "quick": true, "seed": 7, "car": pid, "state": m.profile.car(), "back": "quick"}
	m.launch(cfg)
