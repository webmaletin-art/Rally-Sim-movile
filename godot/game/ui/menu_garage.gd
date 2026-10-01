extends RefCounted
## Garaje, concesionaria, taller (piezas y neumáticos), ajuste fino y pintura.

const Kit := preload("res://game/ui/ui_kit.gd")
const CarVisualS := preload("res://game/car/car_visual.gd")
const CarBuild := preload("res://game/data/car_build.gd")

var m # menu.gd

func build(name: String, arg) -> void:
	match name:
		"garage": _garage()
		"dealer": _dealer()
		"workshop": _workshop()
		"tune": _tune()
		"paint": _paint()

func _cat() -> Dictionary:
	return CarBuild.catalog()

func _perf(id: String, st: Dictionary) -> Dictionary:
	return CarBuild.perf_of(CarBuild.build_params(m.vehicles[id], st))

func _bar(label: String, v: float, color := Kit.ACCENT) -> Control:
	var row := Kit.hbox(8)
	var l := Kit.label(label, 16, Kit.MUTED)
	l.custom_minimum_size.x = 120
	row.add_child(l)
	var pb := ProgressBar.new()
	pb.max_value = 1.0
	pb.value = clampf(v, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 14)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.add_theme_stylebox_override("background", Kit.box(Color(1, 1, 1, 0.08), 7))
	pb.add_theme_stylebox_override("fill", Kit.box(color, 7))
	row.add_child(pb)
	return row

func _stats_block(id: String, st: Dictionary) -> Control:
	var pf := _perf(id, st)
	var cls: Dictionary = CarBuild.class_of(int(pf["pi"]))
	var p := Kit.panel(12, Kit.PANEL2)
	var v := Kit.vbox(4)
	p.add_child(v)
	var head := Kit.hbox(10)
	v.add_child(head)
	var badge := Kit.label(" %s " % cls["c"], 26, Color(0.05, 0.06, 0.08))
	badge.add_theme_stylebox_override("normal", Kit.box(Kit.hexc(cls["col"]), 8, Color(0, 0, 0, 0), 0, 6))
	head.add_child(badge)
	head.add_child(Kit.label("PI %d" % int(pf["pi"]), 24, Kit.TEXT))
	head.add_child(Kit.spacer())
	head.add_child(Kit.label("%d cv · %d kg · %d km/h" % [int(pf["hp"]), int(pf["kg"]), int(pf["vmax"])], 18, Kit.MUTED))
	var b: Dictionary = pf["bars"]
	v.add_child(_bar("Velocidad", float(b["speed"])))
	v.add_child(_bar("Aceleración", float(b["accel"])))
	v.add_child(_bar("Manejo", float(b["handling"])))
	v.add_child(_bar("Frenado", float(b["braking"])))
	v.add_child(_bar("Off-road", float(b["offroad"])))
	return p

func _no_car() -> bool:
	if m.profile.current_id() == "":
		m.body.add_child(Kit.label("Todavía no tenés auto. Comprá uno en la concesionaria.", 20, Kit.MUTED))
		return true
	return false

# ───────────────────────── garaje ─────────────────────────
func _garage() -> void:
	m.set_title("GARAJE")
	var owned: Dictionary = m.profile.d["owned"]
	for id in _cat()["order"]:
		if not owned.has(id):
			continue
		var cm: Dictionary = _cat()["cars"][id]
		var st: Dictionary = owned[id]
		var pf := _perf(id, st)
		var cur: bool = id == m.profile.current_id()
		var b := Kit.button("", Callable(), cur, 20, Vector2(0, 68))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := Kit.hbox(10)
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 14
		row.offset_right = -14
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)
		var dark := Color(0.05, 0.06, 0.08)
		var v := Kit.vbox(0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(v)
		v.add_child(Kit.label("%s %s" % [cm["brand"], cm["model"]], 22, dark if cur else Kit.TEXT))
		v.add_child(Kit.label("%s · %.0f km" % [cm["kind"], float(st.get("km", 0.0))], 15, dark if cur else Kit.MUTED))
		var cls: Dictionary = CarBuild.class_of(int(pf["pi"]))
		var rl := Kit.label("%s · PI %d%s" % [cls["c"], int(pf["pi"]), "  ✔" if cur else ""], 20, dark if cur else Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(rl)
		var cid: String = id
		b.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			m.profile.select(cid)
			m.sfx.play("click")
			m.refresh_car()
			m.go("garage", null, false))
		m.body.add_child(b)
	if _no_car():
		return
	var id2: String = m.profile.current_id()
	m.body.add_child(_stats_block(id2, m.profile.car()))
	var row2 := Kit.hbox(8)
	m.body.add_child(row2)
	for bt in [["🔧 TALLER", "workshop"], ["🎚 AJUSTE", "tune"], ["🎨 PINTURA", "paint"]]:
		var dest: String = bt[1]
		var bb := Kit.button(bt[0], func(): m.sfx.play("click"); m.go(dest), false, 18, Vector2(0, 52))
		bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(bb)
	var cm2: Dictionary = _cat()["cars"][id2]
	var dl := Kit.label(str(cm2["desc"]), 16, Kit.MUTED)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = 380
	m.body.add_child(dl)

# ───────────────────────── concesionaria ─────────────────────────
func _dealer() -> void:
	m.set_title("CONCESIONARIA")
	for id in _cat()["order"]:
		var cm: Dictionary = _cat()["cars"][id]
		var owned: bool = m.profile.owns(id)
		var st: Dictionary = m.profile.d["owned"][id] if owned else m.profile.new_car_state(id)
		var pf := _perf(id, st)
		var cls: Dictionary = CarBuild.class_of(int(pf["pi"]))
		var p := Kit.panel(12, Kit.PANEL2)
		m.body.add_child(p)
		var v := Kit.vbox(4)
		p.add_child(v)
		var head := Kit.hbox(10)
		v.add_child(head)
		head.add_child(Kit.label("%s %s" % [cm["brand"], cm["model"]], 24, Kit.TEXT))
		head.add_child(Kit.spacer())
		head.add_child(Kit.label("%s · PI %d" % [cls["c"], int(pf["pi"])], 20, Kit.GOLD))
		v.add_child(Kit.label("%s · %s · %s · %d" % [cm["kind"], cm["engine"], cm["drive"], int(cm["year"])], 16, Kit.MUTED))
		var dl := Kit.label(str(cm["desc"]), 16, Kit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 360
		v.add_child(dl)
		v.add_child(Kit.label("%d cv · %d kg · %d km/h" % [int(pf["hp"]), int(pf["kg"]), int(pf["vmax"])], 16, Kit.TEXT))
		var brow := Kit.hbox(8)
		v.add_child(brow)
		var cid: String = id
		var see := Kit.button("👁 VER", func():
			m.sfx.play("click")
			m.refresh_car(cid, st), false, 18, Vector2(110, 50))
		brow.add_child(see)
		var trow := Kit.hbox(8)
		v.add_child(trow)
		for tt in [["🏁 PROBAR EN ASFALTO", "lake"], ["🏜 PROBAR EN TIERRA", "forest"]]:
			var tmap: String = tt[1]
			var tb := Kit.button(tt[0], func() -> void:
				m.sfx.play("click")
				var tcfg := {"type": "free", "track": tmap, "ai": 0, "sky": "day", "car": cid, "state": st.duplicate(true), "testCar": true, "back": "dealer", "seed": 7}
				m.launch(tcfg, false), false, 16, Vector2(0, 46))
			tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trow.add_child(tb)
		if owned:
			var ob := Kit.button("✔ EN TU GARAJE", Callable(), false, 18, Vector2(0, 50))
			ob.disabled = true
			ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			brow.add_child(ob)
		else:
			var price := int(cm["price"])
			var bb := Kit.button("COMPRAR  " + Kit.fmt_cr(float(price)), func(): _buy_car(cid), m.profile.credits >= price, 18, Vector2(0, 50))
			bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			brow.add_child(bb)
	m.body.add_child(Kit.label("PRÓXIMAMENTE", 16, Kit.MUTED))
	for c in _cat()["coming"]:
		m.body.add_child(Kit.label("%s  %s — %s" % [c["icon"], c["name"], c["kind"]], 18, Kit.MUTED))

func _buy_car(id: String) -> void:
	if m.profile.buy_car(id):
		m.sfx.play("buy")
		m.toast("¡Es tuyo! %s %s" % [_cat()["cars"][id]["brand"], _cat()["cars"][id]["model"]])
		m.refresh_car()
		m.update_credits()
		m.go("dealer", null, false)
	else:
		m.sfx.play("error")
		m.toast("No te alcanza el dinero")

# ───────────────────────── taller ─────────────────────────
func _workshop() -> void:
	m.set_title("TALLER")
	if _no_car():
		return
	var id: String = m.profile.current_id()
	m.body.add_child(_stats_block(id, m.profile.car()))
	var st: Dictionary = m.profile.car()
	for u in _cat()["upgrades"]:
		var uid := str(u["id"])
		var p := Kit.panel(10, Kit.PANEL2)
		m.body.add_child(p)
		var v := Kit.vbox(6)
		p.add_child(v)
		v.add_child(Kit.label("%s %s" % [u["icon"], u["name"]], 22, Kit.ACCENT))
		var il := Kit.label(str(u["info"]), 15, Kit.MUTED)
		il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		il.custom_minimum_size.x = 360
		v.add_child(il)
		var cur_lvl := int(m.profile.upgrade_level(id, uid))
		var levels: Array = u["levels"]
		for li in levels.size():
			var lv: Dictionary = levels[li]
			var owned_p: bool = m.profile.part_owned(id, uid, li)
			var equipped := li == cur_lvl
			var cost := int(lv.get("cost", 0))
			var txt := "%s%s" % ["✔ " if equipped else "", lv["n"]]
			var right := "EQUIPADO" if equipped else ("PONER" if owned_p else Kit.fmt_cr(float(cost)))
			var b := Kit.button("", Callable(), equipped, 17, Vector2(0, 46))
			var row := Kit.hbox(8)
			row.set_anchors_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 12
			row.offset_right = -12
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(row)
			var dark := Color(0.05, 0.06, 0.08)
			var tl := Kit.label(txt, 17, dark if equipped else Kit.TEXT)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tl.clip_text = true
			tl.custom_minimum_size.x = 80
			tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(tl)
			var rl := Kit.label(right, 17, dark if equipped else (Kit.GOLD if not owned_p else Kit.GREEN), HORIZONTAL_ALIGNMENT_RIGHT)
			rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(rl)
			var lvl := li
			b.pressed.connect(func() -> void:
				if Kit.scroll_moved:
					Kit.scroll_moved = false
					return
				_buy_upgrade(id, uid, lvl))
			v.add_child(b)
	# neumáticos
	var tp := Kit.panel(10, Kit.PANEL2)
	m.body.add_child(tp)
	var tv := Kit.vbox(6)
	tp.add_child(tv)
	tv.add_child(Kit.label("⚪ NEUMÁTICOS", 22, Kit.ACCENT))
	for t in _cat()["tires"]:
		var tid := str(t["id"])
		var have: bool = (st["tiresOwned"] as Array).has(tid)
		var eq: bool = str(st["tires"]) == tid
		var b2 := Kit.button("", Callable(), eq, 17, Vector2(0, 54))
		var row2 := Kit.hbox(8)
		row2.set_anchors_preset(Control.PRESET_FULL_RECT)
		row2.offset_left = 12
		row2.offset_right = -12
		row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b2.add_child(row2)
		var dark2 := Color(0.05, 0.06, 0.08)
		var v2 := Kit.vbox(0)
		v2.alignment = BoxContainer.ALIGNMENT_CENTER
		v2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row2.add_child(v2)
		v2.add_child(Kit.label("%s %s%s" % [t["icon"], t["n"], "  ✔" if eq else ""], 18, dark2 if eq else Kit.TEXT))
		var il2 := Kit.label(str(t["info"]), 13, dark2 if eq else Kit.MUTED)
		il2.clip_text = true
		il2.custom_minimum_size.x = 60
		v2.add_child(il2)
		var rl2 := Kit.label("EQUIPADO" if eq else ("PONER" if have else Kit.fmt_cr(float(t["cost"]))), 17, dark2 if eq else (Kit.GREEN if have else Kit.GOLD), HORIZONTAL_ALIGNMENT_RIGHT)
		rl2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row2.add_child(rl2)
		b2.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			if m.profile.buy_tires(id, tid):
				m.sfx.play("buy")
				_after_change()
			else:
				m.sfx.play("error")
				m.toast("No te alcanza el dinero"))
		tv.add_child(b2)

func _buy_upgrade(id: String, uid: String, lvl: int) -> void:
	if m.profile.buy_upgrade(id, uid, lvl):
		m.sfx.play("buy")
		_after_change()
	else:
		m.sfx.play("error")
		m.toast("No te alcanza el dinero")

func _after_change() -> void:
	m.refresh_car()
	m.update_credits()
	m.go("workshop", null, false)

# ───────────────────────── ajuste fino ─────────────────────────
func _tune() -> void:
	m.set_title("AJUSTE")
	if _no_car():
		return
	var id: String = m.profile.current_id()
	var st: Dictionary = m.profile.car()
	var base: Dictionary = m.vehicles[id]
	var defs := CarBuild.default_tune(base)
	var tune: Dictionary = st["tune"]
	# preajustes
	var prow := Kit.hbox(6)
	m.body.add_child(prow)
	for pk in ["asfalto", "tierra", "drift", "salto"]:
		var key: String = pk
		var pb := Kit.button(_cat()["preset_n"][pk], func() -> void:
			m.sfx.play("click")
			st["tune"] = {}
			for k in _cat()["presets"][key]:
				st["tune"][k] = float(_cat()["presets"][key][k])
			m.profile.save()
			m.refresh_car()
			m.go("tune", null, false), false, 17, Vector2(0, 48))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(pb)
	m.body.add_child(Kit.button("↺ VOLVER A LO DE FÁBRICA", func() -> void:
		st["tune"] = {}
		m.profile.save()
		m.refresh_car()
		m.go("tune", null, false), false, 17, Vector2(0, 46)))
	for g in _cat()["tune"]:
		m.body.add_child(Kit.label(str(g["g"]).to_upper(), 16, Kit.MUTED))
		for it in g["items"]:
			var k := str(it["k"])
			var v0 := float(tune.get(k, defs.get(k, it["def"])))
			var p := Kit.panel(8, Kit.PANEL2)
			m.body.add_child(p)
			var col := Kit.vbox(2)
			p.add_child(col)
			var head := Kit.hbox(8)
			col.add_child(head)
			head.add_child(Kit.label(str(it["n"]), 18, Kit.TEXT))
			head.add_child(Kit.spacer())
			var vl := Kit.label("", 18, Kit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			head.add_child(vl)
			var sl := HSlider.new()
			sl.min_value = float(it["min"])
			sl.max_value = float(it["max"])
			sl.step = float(it["step"]) if it.has("step") else 1.0
			sl.value = v0
			sl.custom_minimum_size = Vector2(0, 30)
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var unit := str(it.get("u", ""))
			vl.text = "%s %s" % [_num(v0), unit]
			sl.value_changed.connect(func(v: float) -> void:
				tune[k] = v
				vl.text = "%s %s" % [_num(v), unit])
			sl.drag_ended.connect(func(_c: bool) -> void:
				m.profile.save()
				m.refresh_car())
			col.add_child(sl)
			var il := Kit.label(str(it["info"]) if it.has("info") else "", 13, Kit.MUTED)
			il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			il.custom_minimum_size.x = 340
			if il.text != "":
				col.add_child(il)

func _num(v: float) -> String:
	return str(snappedf(v, 0.01)) if absf(v - roundf(v)) > 0.001 else str(int(roundf(v)))

# ───────────────────────── pintura ─────────────────────────
var paint_target := "body"

func _paint() -> void:
	m.set_title("PINTURA")
	if _no_car():
		return
	var st: Dictionary = m.profile.car()
	var paint: Dictionary = st["paint"]
	var row := Kit.hbox(6)
	m.body.add_child(row)
	for t in [["body", "Carrocería"], ["accent", "Detalles"], ["rim", "Llantas"], ["tire", "Gomas"]]:
		var key: String = t[0]
		var b := Kit.button(t[1], func() -> void:
			paint_target = key
			m.sfx.play("click")
			m.go("paint", null, false), paint_target == key, 18, Vector2(0, 50))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	m.body.add_child(grid)
	var swatches: Array = _cat()["paints"]
	if paint_target == "tire":
		# gomas: negro de fábrica, grafito, gris, marrón de tierra, blanco, o de color
		swatches = ["#141516", "#2b2d31", "#55585e", "#5a3f2a", "#e8e6e1", "#c1121f", "#ffc300", "#1a4fe0", "#12a454", "#ff6a08"]
	for hx in swatches:
		var h: String = hx
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(62, 62)
		var selected := str(paint.get(paint_target, "")).to_lower() == h.to_lower()
		sw.add_theme_stylebox_override("normal", Kit.box(Color(h), 12, Color.WHITE if selected else Kit.LINE, 4 if selected else 1))
		sw.add_theme_stylebox_override("hover", Kit.box(Color(h).lightened(0.1), 12, Color.WHITE, 2))
		sw.add_theme_stylebox_override("pressed", Kit.box(Color(h).darkened(0.1), 12, Kit.ACCENT, 3))
		sw.pressed.connect(func() -> void:
			if Kit.scroll_moved:
				Kit.scroll_moved = false
				return
			paint[paint_target] = h
			m.profile.save()
			m.sfx.play("click")
			m.refresh_car()
			m.go("paint", null, false))
		grid.add_child(sw)
	m.body.add_child(Kit.label("ROTULADO (usa el color de Detalles)", 16, Kit.MUTED))
	var lg := GridContainer.new()
	lg.columns = 3
	lg.add_theme_constant_override("h_separation", 6)
	lg.add_theme_constant_override("v_separation", 6)
	m.body.add_child(lg)
	for li in CarVisualS.LIVERIES.size():
		var lid := li
		var lb := Kit.button(str(CarVisualS.LIVERIES[li]), func() -> void:
			paint["livery"] = lid
			m.profile.save()
			m.sfx.play("click")
			m.refresh_car()
			m.go("paint", null, false), int(paint.get("livery", 0)) == li, 16, Vector2(0, 46))
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lg.add_child(lb)
	m.body.add_child(Kit.label("ACABADO", 16, Kit.MUTED))
	var frow := Kit.hbox(6)
	m.body.add_child(frow)
	for f in _cat()["finishes"]:
		var fid := str(f["id"])
		var fb := Kit.button(str(f["n"]), func() -> void:
			paint["finish"] = fid
			m.profile.save()
			m.sfx.play("click")
			m.refresh_car()
			m.go("paint", null, false), str(paint.get("finish", "gloss")) == fid, 16, Vector2(0, 48))
		fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		frow.add_child(fb)
