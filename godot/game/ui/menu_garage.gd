extends RefCounted
## Garaje y tienda (un auto por pantalla, con flechas para pasar al siguiente) y taller con pestañas: piezas, gomas, ajuste fino y pintura.
## Todo entra en la pantalla sin desplazar: la sala 3D con el auto y los pilotos queda siempre a la vista.

const Kit := preload("res://game/ui/ui_kit.gd")
const CarVisualS := preload("res://game/car/car_visual.gd")
const CarParts := preload("res://game/car/car_parts.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Release := preload("res://game/data/release.gd")

const DARK := Color(0.05, 0.06, 0.08)
const GROUP_SHORT := {"Neumáticos": "Gomas", "Alineación": "Alineac.", "Suspensión": "Susp.", "Frenos": "Frenos", "Transmisión": "Transm.", "Aerodinámica": "Aero", "Diversión (gustos raros)": "Extras"}
const PAINT_TARGETS := [["body", "Carrocería"], ["accent", "Detalles"], ["rim", "Llantas"], ["tire", "Gomas"], ["spring", "Resortes"], ["caliper", "Pinzas"], ["disc", "Discos"]]
const DISC_NAMES := {"steel": "Acero", "dark": "Oscuro", "gold": "Dorado", "carbon": "Carbono"}

var m # menu.gd
var shop_i := 0
var mine_i := -1
var ws_tab := 0
var up_cat := 0
var tune_grp := 0
var paint_target := "body"
var tune_info := ""

func build(name: String, arg) -> void:
	match name:
		"garage": _cars(true)
		"dealer": _cars(false)
		"workshop":
			if arg != null:
				ws_tab = int(arg)
			_workshop()
		"tune":
			ws_tab = 2
			_workshop()
		"paint":
			ws_tab = 3
			_workshop()

func _cat() -> Dictionary:
	return CarBuild.catalog()

func _perf(id: String, st: Dictionary) -> Dictionary:
	return CarBuild.perf_of(CarBuild.build_params(m.vehicles[id], st))

func _no_car() -> bool:
	if m.profile.current_id() == "":
		m.body.add_child(Kit.label("Todavía no tenés auto. Comprá uno en la tienda.", 20, Kit.MUTED))
		return true
	return false

func _bar(label: String, v: float, color := Kit.ACCENT) -> Control:
	var row := Kit.hbox(6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Kit.label(label, 13, Kit.MUTED)
	l.custom_minimum_size.x = 74
	row.add_child(l)
	var pb := ProgressBar.new()
	pb.max_value = 1.0
	pb.value = clampf(v, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(40, 10)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("background", Kit.box(Color(1, 1, 1, 0.08), 5))
	pb.add_theme_stylebox_override("fill", Kit.box(color, 5))
	row.add_child(pb)
	return row

func _class_badge(cls: Dictionary, size := 24) -> Label:
	var badge := Kit.label(" %s " % cls["c"], size, DARK)
	badge.add_theme_stylebox_override("normal", Kit.box(Kit.hexc(cls["col"]), 8, Color(0, 0, 0, 0), 0, 5))
	return badge

# ───────────────────────── garaje / tienda ─────────────────────────
func _ids(mine: bool) -> Array:
	var out: Array = []
	for id in _cat()["order"]:
		if mine:
			if m.profile.owns(str(id)):
				out.append(str(id))
		elif Release.car_for_sale(m.profile, str(id)):
			out.append(str(id))
	return out

func _cars(mine: bool) -> void:
	m.set_title("GARAJE" if mine else "TIENDA")
	m.body.add_child(Kit.tabs(["🚗 MIS AUTOS", "🏬 TIENDA"], 0 if mine else 1, func(i: int) -> void:
		m.sfx.play("click")
		m.go("garage" if i == 0 else "dealer", null, false), 17, 40.0))
	var ids := _ids(mine)
	if ids.is_empty():
		m.body.add_child(Kit.label("No hay autos para mostrar.", 20, Kit.MUTED))
		return
	var idx: int
	if mine:
		if mine_i < 0 or mine_i >= ids.size() or str(ids[mine_i]) != m.profile.current_id() and not m.profile.owns(str(ids[mine_i])):
			mine_i = maxi(0, ids.find(m.profile.current_id()))
		idx = clampi(mine_i, 0, ids.size() - 1)
	else:
		idx = clampi(shop_i, 0, ids.size() - 1)
	var id: String = ids[idx]
	var owned: bool = m.profile.owns(id)
	var st: Dictionary = m.profile.d["owned"][id] if owned else m.profile.new_car_state(id)
	var cm: Dictionary = _cat()["cars"][id]
	var pf := _perf(id, st)
	var cls: Dictionary = CarBuild.class_of(int(pf["pi"]))
	var cur: bool = owned and id == m.profile.current_id()
	var step := func(d: int) -> void:
		m.sfx.play("click")
		var n := posmod(idx + d, ids.size())
		if mine:
			mine_i = n
		else:
			shop_i = n
		var nid: String = ids[n]
		var nst: Dictionary = m.profile.d["owned"][nid] if m.profile.owns(nid) else m.profile.new_car_state(nid)
		m.refresh_car(nid, nst)
		m.go("garage" if mine else "dealer", null, false)
	var row := Kit.hbox(6)
	m.body.add_child(row)
	var la := Kit.button("◀", func() -> void: step.call(-1), false, 26, Vector2(46, 0))
	la.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(la)
	var p := Kit.panel(10, Kit.PANEL2)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(p)
	var ra := Kit.button("▶", func() -> void: step.call(1), false, 26, Vector2(46, 0))
	ra.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(ra)
	var v := Kit.vbox(3)
	p.add_child(v)
	var top := Kit.hbox(8)
	v.add_child(top)
	var left := Kit.vbox(0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	var bl := Kit.label(str(cm["brand"]), 13, Kit.MUTED)
	bl.clip_text = true
	bl.custom_minimum_size.x = 40
	left.add_child(bl)
	var nl := Kit.label(str(cm["model"]), 27, Kit.TEXT)
	nl.clip_text = true
	nl.custom_minimum_size.x = 40
	left.add_child(nl)
	top.add_child(_class_badge(cls))
	top.add_child(Kit.label("PI %d" % int(pf["pi"]), 21, Kit.GOLD))
	var ln := Kit.label("%s · %s · %s · %d" % [cm["kind"], cm["engine"], cm["drive"], int(cm["year"])], 13, Kit.MUTED)
	ln.clip_text = true
	ln.custom_minimum_size.x = 40
	v.add_child(ln)
	v.add_child(Kit.label("%d cv · %d kg · %d km/h   (%d/%d)" % [int(pf["hp"]), int(pf["kg"]), int(pf["vmax"]), idx + 1, ids.size()], 15, Kit.TEXT))
	var b: Dictionary = pf["bars"]
	var g := Kit.grid(2, 14, 2)
	v.add_child(g)
	g.add_child(_bar("Velocidad", float(b["speed"])))
	g.add_child(_bar("Aceleración", float(b["accel"])))
	g.add_child(_bar("Manejo", float(b["handling"])))
	g.add_child(_bar("Frenado", float(b["braking"])))
	g.add_child(_bar("Off-road", float(b["offroad"])))
	var dl := Kit.wrap(str(cm["desc"]), 13, Kit.MUTED, 200)
	dl.max_lines_visible = 3
	dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(dl)
	var brow := Kit.hbox(8)
	m.body.add_child(brow)
	if mine:
		var use := Kit.button("✔ EN USO" if cur else "USAR ESTE AUTO", func() -> void:
			m.profile.select(id)
			m.sfx.play("click")
			m.refresh_car()
			m.go("garage", null, false), not cur, 20, Vector2(0, 52))
		use.disabled = cur
		use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(use)
		var wb := Kit.button("🔧 TALLER", func() -> void:
			m.profile.select(id)
			m.sfx.play("click")
			m.refresh_car()
			m.go("workshop", 0), false, 20, Vector2(0, 52))
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(wb)
	else:
		if owned:
			var ob := Kit.button("✔ EN TU GARAJE", Callable(), false, 20, Vector2(0, 52))
			ob.disabled = true
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			brow.add_child(ob)
		else:
			var price := int(cm["price"])
			var bb := Kit.button("COMPRAR  " + Kit.fmt_cr(float(price)), func() -> void: _buy_car(id), m.profile.credits >= price, 20, Vector2(0, 52))
			bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			brow.add_child(bb)
		# probar el auto antes de comprarlo (también los que ya tenés): sin premios y con el taller de prueba en la pausa
		var trow := Kit.hbox(6)
		m.body.add_child(trow)
		for tt in [["🏁 ASFALTO", "lake"], ["🏜 TIERRA", "forest"], ["🌀 DRIFT", "drift"]]:
			var tmap: String = tt[1]
			var tb := Kit.button(tt[0], func() -> void:
				m.sfx.play("click")
				var tcfg := {"type": "free", "track": tmap, "ai": 0, "sky": "day", "car": id, "state": st.duplicate(true), "testCar": true, "back": "dealer", "seed": 7}
				if tmap == "drift":
					tcfg["type"] = "drift"
					tcfg["time"] = 1800 # práctica larga: se corta desde la pausa
				m.launch(tcfg, false), false, 17, Vector2(0, 48))
			tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trow.add_child(tb)

func _buy_car(id: String) -> void:
	if m.profile.buy_car(id):
		m.sfx.play("buy")
		m.toast(tr("¡Es tuyo! %s %s") % [_cat()["cars"][id]["brand"], _cat()["cars"][id]["model"]])
		m.refresh_car()
		m.update_credits()
		m.go("dealer", null, false)
	else:
		m.sfx.play("error")
		m.toast(tr("No te alcanza el dinero"))

# ───────────────────────── taller ─────────────────────────
func _workshop() -> void:
	m.set_title("TALLER")
	if _no_car():
		return
	var id: String = m.profile.current_id()
	var st: Dictionary = m.profile.car()
	var cm: Dictionary = _cat()["cars"][id]
	var pf := _perf(id, st)
	var cls: Dictionary = CarBuild.class_of(int(pf["pi"]))
	var head := Kit.hbox(8)
	m.body.add_child(head)
	head.add_child(_class_badge(cls, 18))
	var hl := Kit.label("%s %s · PI %d · %d cv · %d km/h" % [cm["brand"], cm["model"], int(pf["pi"]), int(pf["hp"]), int(pf["vmax"])], 15, Kit.MUTED)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.clip_text = true
	hl.custom_minimum_size.x = 40
	head.add_child(hl)
	m.body.add_child(Kit.tabs(["⚙ PIEZAS", "⚪ GOMAS", "🎚 AJUSTE", "🎨 PINTURA"], ws_tab, func(i: int) -> void:
		ws_tab = i
		m.sfx.play("click")
		m.go("workshop", null, false), 16, 40.0))
	match ws_tab:
		0: _ws_parts(id)
		1: _ws_tires(id, st)
		2: _ws_tune(id, st)
		3: _ws_paint(id, st)

func _after_change() -> void:
	m.refresh_car()
	m.update_credits()
	m.go("workshop", null, false)

func _ws_parts(id: String) -> void:
	var ups: Array = _cat()["upgrades"]
	up_cat = clampi(up_cat, 0, ups.size() - 1)
	var row := Kit.hbox(8)
	m.body.add_child(row)
	var left := Kit.vbox(3)
	left.custom_minimum_size.x = 196
	row.add_child(left)
	for i in ups.size():
		var u: Dictionary = ups[i]
		var lvl := int(m.profile.upgrade_level(id, str(u["id"])))
		var n := (u["levels"] as Array).size() - 1
		var ci := i
		var cb := Kit.card_button(str(u["name"]), "", "●".repeat(lvl) + "○".repeat(n - lvl), func() -> void:
			up_cat = ci
			m.sfx.play("click")
			m.go("workshop", null, false), i == up_cat, true, 33.0, 14, str(u["icon"]))
		left.add_child(cb)
	var right := Kit.vbox(5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var u2: Dictionary = ups[up_cat]
	var uid := str(u2["id"])
	right.add_child(Kit.label("%s %s" % [u2["icon"], u2["name"]], 20, Kit.ACCENT))
	var il := Kit.wrap(str(u2["info"]), 13, Kit.MUTED, 150)
	il.max_lines_visible = 5
	il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	right.add_child(il)
	var cur_lvl := int(m.profile.upgrade_level(id, uid))
	var levels: Array = u2["levels"]
	for li in levels.size():
		var lv: Dictionary = levels[li]
		var owned_p: bool = m.profile.part_owned(id, uid, li)
		var equipped := li == cur_lvl
		var cost := int(lv.get("cost", 0))
		var rt := tr("EQUIPADO") if equipped else (tr("PONER") if owned_p else Kit.fmt_cr(float(cost)))
		var lvl_i := li
		var b := Kit.card_button(("✔ " if equipped else "") + str(lv["n"]), "", rt, func() -> void: _buy_upgrade(id, uid, lvl_i), equipped, true, 40.0, 14)
		right.add_child(b)

func _buy_upgrade(id: String, uid: String, lvl: int) -> void:
	if m.profile.buy_upgrade(id, uid, lvl):
		m.sfx.play("buy")
		_after_change()
	else:
		m.sfx.play("error")
		m.toast(tr("No te alcanza el dinero"))

func _ws_tires(id: String, st: Dictionary) -> void:
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	for t in _cat()["tires"]:
		var tid := str(t["id"])
		var have: bool = (st["tiresOwned"] as Array).has(tid)
		var eq: bool = str(st["tires"]) == tid
		var rt := tr("EQUIPADO") if eq else (tr("PONER") if have else Kit.fmt_cr(float(t["cost"])))
		var b := Kit.card_button("%s %s" % [t["icon"], t["n"]], str(t["info"]), rt, func() -> void:
			if m.profile.buy_tires(id, tid):
				m.sfx.play("buy")
				_after_change()
			else:
				m.sfx.play("error")
				m.toast(tr("No te alcanza el dinero")), eq, true, 74.0, 16)
		g.add_child(b)

# ── ajuste fino ──
func _ws_tune(id: String, st: Dictionary) -> void:
	var base: Dictionary = m.vehicles[id]
	var defs := CarBuild.default_tune(base)
	var tune: Dictionary = st["tune"]
	var groups: Array = _cat()["tune"]
	tune_grp = clampi(tune_grp, 0, groups.size() - 1)
	var names: Array = []
	for g in groups:
		names.append(str(GROUP_SHORT.get(str(g["g"]), str(g["g"]))))
	m.body.add_child(Kit.tabs(names, tune_grp, func(i: int) -> void:
		tune_grp = i
		tune_info = ""
		m.sfx.play("click")
		m.go("workshop", null, false), 14, 36.0))
	var info := Kit.wrap("", 13, Kit.MUTED, 200)
	info.max_lines_visible = 3
	info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var grp: Dictionary = groups[tune_grp]
	var items: Array = grp["items"]
	if tune_info == "" and items.size() > 0:
		tune_info = str(items[0].get("info", ""))
	info.text = tune_info
	for it in items:
		var k := str(it["k"])
		var v0 := float(tune.get(k, defs.get(k, it["def"])))
		var row := Kit.hbox(8)
		m.body.add_child(row)
		var nl := Kit.label(str(it["n"]), 15, Kit.TEXT)
		nl.custom_minimum_size.x = 168
		nl.clip_text = true
		row.add_child(nl)
		var sl := HSlider.new()
		sl.min_value = float(it["min"])
		sl.max_value = float(it["max"])
		sl.step = float(it["step"]) if it.has("step") else 1.0
		sl.value = v0
		sl.custom_minimum_size = Vector2(0, 34)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sl)
		var unit := str(it.get("u", ""))
		var vl := Kit.label("%s %s" % [_num(v0), unit], 15, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size.x = 74
		row.add_child(vl)
		var txt := str(it.get("info", ""))
		sl.value_changed.connect(func(nv: float) -> void:
			tune[k] = nv
			vl.text = "%s %s" % [_num(nv), unit]
			tune_info = txt
			info.text = txt)
		sl.drag_ended.connect(func(_c: bool) -> void:
			m.profile.save()
			m.refresh_car())
	m.body.add_child(info)
	var prow := Kit.hbox(6)
	m.body.add_child(prow)
	for pk in ["asfalto", "tierra", "drift", "salto"]:
		var key: String = pk
		var pb := Kit.button(str(_cat()["preset_n"][pk]), func() -> void:
			m.sfx.play("click")
			st["tune"] = {}
			for k2 in _cat()["presets"][key]:
				st["tune"][k2] = float(_cat()["presets"][key][k2])
			m.profile.save()
			m.refresh_car()
			m.go("workshop", null, false), false, 15, Vector2(0, 40))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(pb)
	var rb := Kit.button("↺ FÁBRICA", func() -> void:
		st["tune"] = {}
		m.profile.save()
		m.refresh_car()
		m.go("workshop", null, false), false, 15, Vector2(0, 40))
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(rb)

func _num(v: float) -> String:
	return str(snappedf(v, 0.01)) if absf(v - roundf(v)) > 0.001 else str(int(roundf(v)))

# ── pintura ──
func _ws_paint(id: String, st: Dictionary) -> void:
	var paint: Dictionary = st["paint"]
	var own := CarVisualS.has_own_model(str(m.vehicles[id].get("visualType", id)))
	var targets: Array = []
	for t in PAINT_TARGETS:
		if own or not ["spring", "caliper", "disc"].has(str(t[0])):
			targets.append(t)
	if not targets.any(func(t: Array) -> bool: return str(t[0]) == paint_target):
		paint_target = "body"
	var tg := Kit.grid(4, 6, 6)
	m.body.add_child(tg)
	for t in targets:
		var key: String = t[0]
		var b := Kit.button(str(t[1]), func() -> void:
			paint_target = key
			m.sfx.play("click")
			m.go("workshop", null, false), paint_target == key, 15, Vector2(0, 38))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		tg.add_child(b)
	if paint_target == "disc":
		var dg := Kit.grid(4, 6, 6)
		m.body.add_child(dg)
		for k in DISC_NAMES:
			var dk: String = k
			var db := Kit.button(str(DISC_NAMES[k]), func() -> void:
				paint["disc"] = dk
				m.profile.save()
				m.sfx.play("click")
				m.refresh_car()
				m.go("workshop", null, false), str(paint.get("disc", "steel")) == dk, 16, Vector2(0, 54))
			db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			dg.add_child(db)
		m.body.add_child(Kit.wrap("El disco de freno se ve por entre los rayos de la llanta. Las pinzas llevan el color de «Pinzas».", 13, Kit.MUTED, 300))
	else:
		var swatches: Array = _cat()["paints"]
		if paint_target == "tire":
			swatches = ["#141516", "#2b2d31", "#55585e", "#5a3f2a", "#e8e6e1", "#c1121f", "#ffc300", "#1a4fe0", "#12a454", "#ff6a08"]
		var grid := Kit.grid(10, 5, 5)
		m.body.add_child(grid)
		var meta := CarVisualS.load_meta(str(m.vehicles[id].get("visualType", id)))
		var wdef: Dictionary = meta.get("wheel", {})
		var cur_hex := str(paint.get(paint_target, "")).to_lower()
		if cur_hex == "" and paint_target == "spring":
			cur_hex = str(wdef.get("spring_col", "")).to_lower()
		if cur_hex == "" and paint_target == "caliper":
			cur_hex = str(wdef.get("caliper_col", "")).to_lower()
		for hx in swatches:
			var h: String = hx
			var sw := Button.new()
			sw.custom_minimum_size = Vector2(0, 46)
			sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var selected := cur_hex == h.to_lower()
			sw.add_theme_stylebox_override("normal", Kit.box(Color(h), 10, Color.WHITE if selected else Kit.LINE, 4 if selected else 1))
			sw.add_theme_stylebox_override("hover", Kit.box(Color(h).lightened(0.1), 10, Color.WHITE, 2))
			sw.add_theme_stylebox_override("pressed", Kit.box(Color(h).darkened(0.1), 10, Kit.ACCENT, 3))
			sw.pressed.connect(func() -> void:
				paint[paint_target] = h
				m.profile.save()
				m.sfx.play("click")
				m.refresh_car()
				m.go("workshop", null, false))
			grid.add_child(sw)
	var sg := Kit.grid(2, 8, 8)
	m.body.add_child(sg)
	var lids: Array = []
	for li in CarVisualS.LIVERIES.size():
		lids.append(li)
	sg.add_child(Kit.selector("Rotulado (usa el color de Detalles)", lids, int(paint.get("livery", 0)), func(v) -> String: return str(CarVisualS.LIVERIES[int(v)]), func(v) -> void:
		paint["livery"] = int(v)
		m.profile.save()
		m.refresh_car(), m.sfx, 62.0))
	var fids: Array = []
	var fnames := {}
	for f in _cat()["finishes"]:
		fids.append(str(f["id"]))
		fnames[str(f["id"])] = str(f["n"])
	sg.add_child(Kit.selector("Acabado", fids, str(paint.get("finish", "gloss")), func(v) -> String: return str(fnames[v]), func(v) -> void:
		paint["finish"] = str(v)
		m.profile.save()
		m.refresh_car(), m.sfx, 62.0))
