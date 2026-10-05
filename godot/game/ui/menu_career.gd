extends RefCounted
## Pantallas del modo carrera (copas, eventos, detalle) y de la carrera rápida.

const Kit := preload("res://game/ui/ui_kit.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Rewards := preload("res://game/data/rewards.gd")
const Release := preload("res://game/data/release.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")

const SKY_N := {"day": "☀ Día", "sunset": "🌇 Atardecer", "overcast": "☁ Nublado", "dusk": "🌆 Anochecer", "rain": "🌧 Lluvia"}
const MEDAL_N := ["Sin medalla", "Bronce", "Plata", "Oro"]

var m # menu.gd
var maps: Dictionary
var quick := {"dmode": "free", "map": "lake", "mode": "race", "laps": 2, "ai": 3, "sky": "day", "skill": 1.0, "car": "cur", "stage": 0, "fantasy": false}

func _maps() -> Dictionary:
	if maps.is_empty():
		maps = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/routes.json"))["maps"]
	return maps

## Vista previa de una pista: dos tomas del recorrido que se alternan con un fundido (como una cámara que pasa por la pista)
func preview(map_id: String, h := 172.0, label_size := 22) -> Control:
	var base := map_id.replace("Rev", "")
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, h)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texs: Array = []
	for k in 2:
		var path := "res://game/ui/tracks/%s_%d.jpg" % [base, k]
		if ResourceLoader.exists(path):
			texs.append(load(path))
	if texs.is_empty():
		return holder
	var rects: Array = []
	for t in texs:
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
		rects.append(tr)
	if rects.size() > 1:
		(rects[1] as Control).modulate.a = 0.0
		var tw := holder.create_tween().set_loops()
		tw.tween_interval(2.4)
		tw.tween_property(rects[1], "modulate:a", 1.0, 0.9)
		tw.tween_interval(2.4)
		tw.tween_property(rects[1], "modulate:a", 0.0, 0.9)
	# nombre sobre la imagen
	var lbl := Kit.label(map_name(map_id), label_size, Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 8 if label_size >= 20 else 5)
	lbl.position = Vector2(12, 8) if label_size >= 20 else Vector2(6, 4)
	holder.add_child(lbl)
	return holder

## Mapas fantasía (el Vórtice de Ensueño, Marte, la Luna y el anillo de Júpiter): sueltos, fuera de las copas, todos en papel
func fantasy_maps() -> Array:
	var out: Array = []
	for k in _maps():
		if str(_maps()[k].get("kind", "")) == "dream":
			out.append(k)
	return out

func is_fantasy(id: String) -> bool:
	return str(_maps().get(id, {}).get("kind", "")) == "dream"

func map_name(id: String) -> String:
	if id == "adventure":
		return tr("Ruta de los Sueños (aventura)")
	return tr(str(_maps().get(id, {}).get("name", id)))

## ¿Se puede jugar este evento en la versión Godot? (hoy: los que corren sobre una ruta)
func playable(ev: Dictionary) -> bool:
	return Rewards.playable(ev)

func build(name: String, arg) -> void:
	match name:
		"career": _tiers()
		"events": _events(str(arg))
		"event": _event(str(arg))
		"quick": _quick()
		"fantasy": _fantasy()

func _medals(n: int) -> String:
	return "●".repeat(n) + "○".repeat(3 - n)

func _medal_color(n: int) -> Color:
	return [Kit.MUTED, Color(0.85, 0.55, 0.3), Color(0.8, 0.85, 0.92), Kit.GOLD][n]

# ───────────────────────── copas ─────────────────────────
func _tiers() -> void:
	m.set_title("CARRERA")
	var stars_l := Kit.label("⭐ %d estrellas ganadas · cada medalla suma 1 a 3 estrellas y abre copas nuevas" % m.profile.stars(), 15, Kit.MUTED)
	m.body.add_child(stars_l)
	for t in CarBuild.catalog()["tiers"]:
		var tid := str(t["id"])
		var allowed := Release.tier_allowed(m.profile, tid)
		var open := Rewards.tier_open(m.profile, t)
		var evs := Rewards.events_of(tid)
		var done := 0
		for e in evs:
			if int(m.profile.event_result(str(e["id"])).get("medal", 0)) > 0:
				done += 1
		var right := "%d/%d" % [done, evs.size()]
		if not allowed:
			right = "🔒 Completo" if Release.IAP_FULL else "🔒 Próximamente"
		elif not open:
			if t.has("car") and not m.profile.owns(str(t["car"])):
				right = "🔒 %s" % CarBuild.catalog()["cars"][t["car"]]["model"]
			else:
				right = "🔒 %d ⭐" % Rewards.stars_needed(t)
		var tt: Dictionary = t
		var b := Kit.card_button(str(t["name"]), str(t["sub"]), right, func(): _open_tier(tt), false, true, 62, 21, str(t["icon"]))
		m.body.add_child(b)

func _open_tier(t: Dictionary) -> void:
	if not Release.tier_allowed(m.profile, str(t["id"])):
		m.sfx.play("error")
		m.toast(Release.lock_text())
		return
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

# ───────────────────────── eventos de una copa (grilla con páginas) ─────────────────────────
var ev_page := 0
const EV_PER_PAGE := 8

func _events(tier_id: String) -> void:
	var tier := Rewards.tier_by_id(tier_id)
	m.set_title(str(tier["name"]).to_upper())
	var lst := Rewards.events_of(tier_id)
	var pages := maxi(1, int(ceil(float(lst.size()) / float(EV_PER_PAGE))))
	ev_page = clampi(ev_page, 0, pages - 1)
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	for i in range(ev_page * EV_PER_PAGE, mini(lst.size(), (ev_page + 1) * EV_PER_PAGE)):
		var e: Dictionary = lst[i]
		var lk := Rewards.event_locked(m.profile, e)
		var res: Dictionary = m.profile.event_result(str(e["id"]))
		var medal := int(res.get("medal", 0))
		var can := playable(e)
		var ti: Dictionary = CarBuild.catalog()["types"][e["type"]]
		var rw := Rewards.reward_for(e, 3, tier)
		var sub := "%s · %s" % [map_name(str(e["map"])), tr(SKY_N.get(str(e.get("sky", "day")), ""))]
		var right := "%s\n%s" % [_medals(medal), Kit.fmt_cr(float(rw["cr"]))]
		if not can:
			right = "🚧 pronto"
		elif lk != "":
			right = "🔒"
		var ev: Dictionary = e
		var b := Kit.card_button("%s %s%s" % [ti["icon"], e["name"], " · FINAL" if e.get("final", false) else ""], sub, right, func(): _open_event(ev, lk), false, true, 66, 18, "%d" % (i + 1))
		g.add_child(b)
	if pages > 1:
		m.body.add_child(Kit.pager(ev_page, pages, func(pg: int) -> void:
			ev_page = pg
			m.go("events", tier_id, false)))

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
	var top := Kit.hbox(10)
	m.body.add_child(top)
	var pv := preview(str(ev["map"]), 128.0)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pv)
	var side := Kit.vbox(2)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(side)
	var res: Dictionary = m.profile.event_result(id)
	var len_s := tr("%d vuelta(s)") % int(ev.get("laps", 1)) if not ev.has("seg") else tr("Tramo de ruta")
	if str(ev["type"]) == "drift":
		len_s = tr("%d segundos") % int(ev.get("time", 60))
	var rows := [["Tipo", "%s %s" % [ti["icon"], ti["n"]]], ["Formato", len_s], ["Rivales", str(ev.get("ai", "—"))],
		["Clima", tr(SKY_N.get(str(ev.get("sky", "day")), "-"))], ["Récord", _fmt_target(ev, float(res["best"])) if res.has("best") and res["best"] != null else "—"],
		["Medalla", tr(MEDAL_N[int(res.get("medal", 0))])]]
	for r in rows:
		var rr := Kit.hbox(6)
		var kl := Kit.label(r[0], 15, Kit.MUTED)
		kl.custom_minimum_size.x = 78
		rr.add_child(kl)
		rr.add_child(Kit.label(r[1], 15, Kit.TEXT))
		side.add_child(rr)
	m.body.add_child(Kit.wrap(str(ev["desc"]), 15, Kit.MUTED, 380))
	var targets: Dictionary = CarBuild.catalog()["targets"]
	if ev["type"] == "race":
		m.body.add_child(Kit.label("🥇 1° puesto · 🥈 2° · 🥉 3°", 17, Kit.TEXT))
	elif targets.has(id):
		var t: Array = targets[id]
		m.body.add_child(Kit.label("🥇 %s   🥈 %s   🥉 %s" % [_fmt_target(ev, t[0]), _fmt_target(ev, t[1]), _fmt_target(ev, t[2])], 17, Kit.TEXT))
	var rws: Array = []
	for md in [3, 2, 1]:
		rws.append(Kit.fmt_cr(float(Rewards.reward_for(ev, md, tier)["cr"])))
	m.body.add_child(Kit.label(tr("Premios: oro %s · plata %s · bronce %s") % rws, 15, Kit.GOLD))
	var block := ""
	var pid: String = m.profile.current_id()
	if not playable(ev):
		block = tr("🚧 Este tipo de evento (%s) llega en una próxima versión del juego nuevo.") % ti["n"]
	elif tier.has("car") and pid != str(tier["car"]):
		block = tr("Esta copa se corre solo con el %s. Elegilo en el garaje.") % CarBuild.catalog()["cars"][tier["car"]]["model"]
	else:
		var pi := _player_pi()
		if not tier.has("car") and pi > int(tier["maxPI"]):
			block = tr("Tu auto es clase %s (PI %d). Esta copa admite hasta clase %s (PI %d). Bajá piezas en el taller o usá otro auto.") % [
				CarBuild.class_of(pi)["c"], pi, CarBuild.class_of(int(tier["maxPI"]))["c"], int(tier["maxPI"])]
	if block != "":
		m.body.add_child(Kit.wrap(block, 15, Kit.RED, 380))
	var go_b := Kit.button("¡CORRER!", func(): _start_event(ev, tier), true, 26, Vector2(0, 58))
	go_b.disabled = block != ""
	m.body.add_child(go_b)

func _start_event(ev: Dictionary, tier: Dictionary, ask := true) -> void:
	var pid: String = m.profile.current_id()
	var cfg := {"type": ev["type"], "track": ev["map"], "laps": int(ev.get("laps", 1)), "ai": int(ev.get("ai", 0)), "time": ev.get("time", 0), "sky": ev.get("sky", "day"),
		"maxPI": int(tier["maxPI"]), "skill": float(tier["skill"]) * (1.03 if ev.get("final", false) else 1.0), "aiCar": str(tier.get("car", "")), "event": ev, "tier": tier,
		"seed": int(str(ev["id"]).unicode_at(1)), "car": pid, "state": m.profile.car(), "back": "events:" + str(tier["id"])}
	if ev.has("seg"):
		cfg["seg"] = ev["seg"]
	if ev.get("drag", false) == true:
		cfg["drag"] = true # picada: caja manual obligatoria
	m.launch(cfg, ask)

# ───────────────────────── carrera rápida ─────────────────────────
func _cars_cat() -> Dictionary:
	return CarBuild.catalog()

func _quick_car_name(v) -> String:
	var cm: Dictionary = _cars_cat()["cars"][str(v)]
	return "%s %s" % [cm["brand"], cm["model"]]

## Pantalla «Mapas fantasía»: una tarjeta por mapa; al tocarla se abren los ajustes de la carrera con ese mapa
func _fantasy() -> void:
	m.set_title("MAPAS FANTASÍA")
	m.body.add_child(Kit.wrap("Mapas sueltos de mundos imposibles, todos hechos en papel. Sin copas ni estrellas: correlos cuando quieras.", 13, Kit.MUTED, 300))
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	for id in fantasy_maps():
		var mp: Dictionary = _maps()[id]
		var b := Kit.button("", Callable(), false, 18, Vector2(0, 214))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Kit.vbox(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.offset_left = 6
		v.offset_right = -6
		v.offset_top = 6
		v.offset_bottom = -4
		var pv := preview(str(id), 92.0, 13)
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pv)
		var tag := Kit.wrap(tr(str(mp.get("tagline", ""))), 12, Kit.TEXT, 120)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tag)
		var st := Kit.label("%s km · ↕ %d m" % [str(mp.get("km", 0)).replace(".", ","), int(mp.get("dz", 0))], 12, Kit.GOLD)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(st)
		b.add_child(v)
		var mid: String = str(id)
		b.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			m.sfx.play("click")
			quick["map"] = mid
			quick["fantasy"] = true
			m.go("quick"))
		g.add_child(b)

func _quick() -> void:
	if str(m.screen_arg) == "fantasy": # para abrirla directo (pruebas y capturas)
		quick["fantasy"] = true
	var fantasy: bool = quick.get("fantasy", false) == true
	var tv: bool = quick.get("travesia", false) == true and not fantasy
	m.set_title("MAPAS FANTASÍA" if fantasy else ("TRAVESÍA X" if tv else "CARRERA RÁPIDA"))
	var route_maps: Array = []
	if tv:
		route_maps = ["travesia"] # el modo Travesía X: un solo mapa
		quick["map"] = "travesia"
	elif fantasy:
		route_maps = fantasy_maps()
		if not route_maps.has(str(quick["map"])):
			quick["map"] = route_maps[0]
	else:
		for k in _maps():
			if str(_maps()[k].get("kind", "")) == "route" and not _maps()[k].get("hidden", false) and not _maps()[k].get("trench", false):
				route_maps.append(k)
		route_maps.append("paperRace") # selva de papel: ruta y tierra, angosta y tupida
		route_maps.append("drift") # la plaza de drift
		route_maps.append("adventure") # la Ruta de los Sueños del modo aventura, para recorrerla completa
		if is_fantasy(str(quick["map"])):
			quick["map"] = "lake" # los mapas fantasía tienen su propia sección
	var adv: bool = str(quick["map"]) == "adventure"
	var pv_box := VBoxContainer.new()
	m.body.add_child(pv_box)
	pv_box.add_child(preview(str(quick["map"]), 128.0))
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	var refresh_pv := func() -> void:
		for c in pv_box.get_children():
			c.queue_free()
		pv_box.add_child(preview(str(quick["map"]), 128.0))
	var car_ids: Array = []
	for id in _cars_cat()["order"]:
		if m.profile.owns(str(id)):
			car_ids.append(str(id)) # Carrera rápida: solo con tus autos (los de la tienda se prueban desde la tienda)
	if str(quick.get("car", "cur")) == "cur" or not car_ids.has(str(quick.get("car", "cur"))):
		quick["car"] = str(m.profile.current_id())
	if m.profile.owns(str(quick["car"])):
		m.refresh_car(str(quick["car"]), m.profile.d["owned"][str(quick["car"])]) # tu auto en la escena, junto a los pilotos
	var stages: Array = []
	for i in mini(AdvRoute.STAGES.size(), Release.adventure_limit(m.profile)):
		stages.append(i)
	if int(quick.get("stage", 0)) >= stages.size():
		quick["stage"] = 0
	var convoy: bool = bool(_maps().get(str(quick["map"]), {}).get("convoy", false))
	var defs := [["Pista", "map", route_maps, func(v): return map_name(str(v))]]
	if tv:
		defs.clear()
	if adv:
		defs.append(["Etapa", "stage", stages, func(v): return "%d · %s" % [int(v) + 1, str(AdvRoute.STAGES[int(v)]["name"])]])
	elif not convoy:
		defs.append(["Modo", "mode", ["race", "timetrial"], func(v): return tr("Carrera") if v == "race" else tr("Contrarreloj")])
	if car_ids.size() > 0:
		defs.append(["Auto", "car", car_ids, func(v): return _quick_car_name(v)])
	if not adv:
		if not is_fantasy(str(quick["map"])): # los mapas fantasía tienen su propio cielo
			defs.append(["Clima", "sky", ["day", "overcast", "sunset", "dusk", "rain"], func(v): return tr(SKY_N[v])])
		if str(quick["map"]) == "drift":
			defs.append(["Drift", "dmode", ["free", "duel"], func(v): return tr("Libre (por puntos)") if v == "free" else tr("Duelo contra un bot")])
			if str(quick["dmode"]) == "duel":
				defs.append(["Nivel del bot", "skill", [0.85, 1.0, 1.08], func(v): return {0.85: tr("Fácil"), 1.0: tr("Normal"), 1.08: tr("Difícil")}[v]])
		if convoy:
			pass # el convoy son 5 autos y camiones fijos, una sola vuelta
		elif str(quick["map"]) == "picada":
			defs.append(["Nivel del rival", "skill", [0.85, 1.0, 1.08], func(v): return {0.85: tr("Fácil"), 1.0: tr("Normal"), 1.08: tr("Difícil")}[v]]) # un solo rival, a la par
		elif str(quick["map"]) != "drift":
			defs.append(["Vueltas", "laps", [1, 2, 3, 5], func(v): return str(v)])
			defs.append(["Rivales", "ai", [0, 1, 3, 5, 7], func(v): return str(v)])
			defs.append(["Nivel de los rivales", "skill", [0.85, 1.0, 1.08], func(v): return {0.85: tr("Fácil"), 1.0: tr("Normal"), 1.08: tr("Difícil")}[v]])
	for o in defs:
		var key: String = o[1]
		var sel := Kit.selector(tr(str(o[0])), o[2], quick[key], o[3], func(v) -> void:
			var prev = quick[key]
			quick[key] = v
			if key == "car":
				m.refresh_car(str(v), m.profile.d["owned"][str(v)]) # el auto elegido aparece en la escena, junto a los pilotos
			if key == "dmode":
				m.go("quick", null, false)
			if key == "map":
				if _map_kind(str(v)) != _map_kind(str(prev)):
					m.go("quick", null, false) # cambian los ajustes que se muestran
				else:
					refresh_pv.call(), m.sfx, 60.0)
		g.add_child(sel)
	if fantasy:
		m.body.add_child(Kit.wrap(tr(str(_maps()[str(quick["map"])].get("tagline", ""))) + " " + tr("Los rivales te siguen el ritmo. No pertenece a ninguna copa."), 13, Kit.MUTED, 300))
	if convoy:
		m.body.add_child(Kit.wrap(tr(str(_maps()[str(quick["map"])].get("tagline", ""))) + " " + tr("Un convoy de 5 autos y camiones va en fila: si acelerás, aceleran; si te quedás, te esperan un poco, pero si te perdés muy lejos los perdés. Hay que llegar a la meta con el grupo."), 13, Kit.MUTED, 300))
	if adv:
		m.body.add_child(Kit.wrap(tr("Práctica: corrés la etapa con el auto que elijas; no cuenta para tu avance ni da premios. La aventura de verdad sigue con el DR Bisonte."), 13, Kit.MUTED, 300))
	m.body.add_child(Kit.button("¡CORRER!", func(): _start_quick(), true, 26, Vector2(0, 58)))

## Familia del mapa de la Carrera rápida: cambia qué ajustes se muestran
func _map_kind(id: String) -> String:
	if is_fantasy(id):
		return "dream"
	if bool(_maps().get(id, {}).get("convoy", false)):
		return "convoy"
	return id if id in ["adventure", "drift", "picada"] else "route"

func _start_quick() -> void:
	var q := quick
	var pid: String = str(q.get("car", m.profile.current_id()))
	if not m.profile.owns(pid):
		pid = m.profile.current_id()
	m.profile.select(pid)
	var st: Dictionary = m.profile.car()
	var test_car := false
	var pi := _player_pi()
	if str(q["map"]) == "adventure":
		var ac := {"type": "adventure", "stage": int(q.get("stage", 0)), "back": "quick", "practice": true, "intro": false, "pcar": pid}
		m.app.start_race(ac)
		return
	var is_drift := str(q["map"]) == "drift"
	var is_drag := str(q["map"]) == "picada"
	var is_convoy: bool = bool(_maps().get(str(q["map"]), {}).get("convoy", false))
	if is_convoy:
		q["mode"] = "race"
		q["laps"] = 1
		q["ai"] = 5
	var cfg := {"type": "drift" if is_drift else q["mode"], "track": q["map"], "laps": 1 if is_drag else int(q["laps"]), "ai": (1 if is_drag else int(q["ai"])) if (q["mode"] == "race" and not is_drift) else 0, "sky": q["sky"], "maxPI": maxi(560, pi + 20),
		"skill": 0.9 * float(q["skill"]), "quick": true, "seed": 7, "car": pid, "state": st, "back": "quick"}
	if test_car:
		cfg["testCar"] = true
	if is_convoy:
		cfg["convoy"] = true
	if is_drag:
		cfg["drag"] = true # caja manual obligatoria y ventana de cambio perfecto
	if is_drift:
		cfg["time"] = 90
		if str(q.get("dmode", "free")) == "duel":
			cfg["duel"] = true
			cfg["ai"] = 1
			cfg["duelSkill"] = float(q["skill"])
	m.launch(cfg)
