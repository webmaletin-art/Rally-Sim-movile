extends RefCounted
## Garaje y tienda (un auto por pantalla, con flechas para pasar al siguiente) y taller con pestañas: piezas, gomas, ajuste fino y pintura.
## Todo entra en la pantalla sin desplazar: la sala 3D con el auto y los pilotos queda siempre a la vista.

const Kit := preload("res://game/ui/ui_kit.gd")
const CarVisualS := preload("res://game/car/car_visual.gd")
const CarParts := preload("res://game/car/car_parts.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Release := preload("res://game/data/release.gd")
const Shops := preload("res://game/data/shops.gd")
const PartCatalog := preload("res://game/car/part_catalog.gd")
const TireWear := preload("res://game/car/tire_wear.gd")
const VehicleCustomization := preload("res://game/car/vehicle_customization.gd")

const DARK := Color(0.05, 0.06, 0.08)
const GROUP_SHORT := {"Neumáticos": "Gomas", "Alineación": "Alineac.", "Suspensión": "Susp.", "Frenos": "Frenos", "Transmisión": "Transm.", "Aerodinámica": "Aero", "Diversión (gustos raros)": "Extras"}
const PAINT_TARGETS := [["body", "Carrocería"], ["accent", "Detalles"], ["rim", "Llantas"], ["tire", "Gomas"], ["spring", "Resortes"], ["caliper", "Pinzas"], ["disc", "Discos"]]
const DISC_NAMES := {"steel": "Acero", "dark": "Oscuro", "gold": "Dorado", "carbon": "Carbono"}

var m # menu.gd
var shop_i := 0
var mine_i := -1
var ws_tab := 0
var body_cat := 0
const BODY_CATS := ["spoiler", "front_bumper", "rear_bumper", "side_skirt", "hood"]
var shop := "" # taller de Dream City en el que se está (vacío: el taller completo del menú)
var up_cat := 0
var pv := {} # vista previa SIN comprar (mejoras, gomas y piezas): {id, kind: upg|tire|part, key, lvl, cat}. Se ve en el auto y en los números; la plata se pide recién al tocar COMPRAR
var tune_stats_box: VBoxContainer
var tune_grp := 0
var paint_target := "body"
var tune_info := ""
# Reglaje y pintura en borrador: se prueban gratis y cobran al aplicar (trabajo del mecánico)
var draft_id := ""
var draft_tune: Dictionary = {}
var draft_paint: Dictionary = {}
var draft_lbl: Label
var draft_apply: Button
const TUNE_FEE := 300
const TUNE_FEE_EACH := 60
const TUNE_FEE_MAX := 1500
const PAINT_FEE := 300

func build(name: String, arg) -> void:
	match name:
		"shop":
			shop = str(arg)
			var sd := Shops.get_shop(shop)
			if sd.is_empty():
				shop = ""
				m.go("home")
			elif str(sd["kind"]) == "dealer":
				shop = ""
				m.go("dealer", null, false)
			else:
				ws_tab = int((sd["tabs"] as Array)[0])
				up_cat = 0
				tune_grp = 0
				_workshop()
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
		if m.app.city_return.is_empty(): # en el concesionario de Dream City no hay taller: cada trabajo se hace en su local
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
		elif Release.PREMIUM_CARS.has(id) and not Release.dev(m.profile):
			var pb := Kit.button("💎 DESBLOQUEAR EN COMPRAS", func() -> void:
				m.sfx.play("click")
				m.go("iap"), true, 18, Vector2(0, 52))
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			brow.add_child(pb)
		elif not Release.can_buy(m.profile, id):
			var lk := Kit.button("🔒 SE GANA TERMINANDO LA AVENTURA", Callable(), false, 17, Vector2(0, 52))
			lk.disabled = true
			lk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			brow.add_child(lk)
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
	if not Release.can_buy(m.profile, id):
		m.sfx.play("error")
		return
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
func _shop_data() -> Dictionary:
	return Shops.get_shop(shop) if shop != "" else {}

func _workshop() -> void:
	var sd := _shop_data()
	m.set_title(("%s %s" % [sd["icon"], tr(str(sd.get("title", sd["name"])))]) if not sd.is_empty() else "TALLER")
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
	var tab_names := ["⚙ PIEZAS", "⚪ GOMAS", "🎚 AJUSTE", "🎨 PINTURA", "🛞 LLANTAS", "🔩 ESTÉTICA"]
	var allowed: Array = sd["tabs"] if not sd.is_empty() else [0, 1, 2, 3, 4, 5]
	if not allowed.has(ws_tab):
		ws_tab = int(allowed[0])
	if allowed.size() > 1:
		var shown: Array = []
		for ti in allowed:
			shown.append(tab_names[int(ti)])
		m.body.add_child(Kit.tabs(shown, allowed.find(ws_tab), func(i: int) -> void:
			ws_tab = int(allowed[i])
			m.sfx.play("click")
			m.go("workshop", null, false), 16, 40.0))
	elif not sd.is_empty():
		m.body.add_child(Kit.wrap(tr(str(sd["info"])), 14, Kit.MUTED, 300))
	if not pv.is_empty():
		var kind_of_tab := {0: "upg", 1: "tire", 4: "part", 5: "part"}
		if str(pv["id"]) != id or str(kind_of_tab.get(ws_tab, "")) != str(pv["kind"]):
			_pv_clear(false)
			m.refresh_car()
	match ws_tab:
		0: _ws_parts(id)
		1: _ws_tires(id, st)
		2: _ws_tune(id, st)
		3: _ws_paint(id, st)
		4: _ws_rims(id, st)
		5: _ws_body(id, st)

## Cómo cambia el auto con la vista previa o el reglaje: potencia, peso, velocidad, 0-100 y las barras (lo que sube en verde y lo que baja en rojo)
func _fill_stats(box: VBoxContainer, id: String, sa: Dictionary, sb: Dictionary) -> void:
	for c in box.get_children():
		c.queue_free()
	var pa := CarBuild.perf_of(CarBuild.build_params(m.vehicles[id], sa))
	var pb := CarBuild.perf_of(CarBuild.build_params(m.vehicles[id], sb))
	box.add_child(Kit.label(tr("Cómo cambia el auto"), 15, Kit.GOLD))
	var ba: Dictionary = pa["bars"]
	var bb: Dictionary = pb["bars"]
	var rows: Array = [
		["Potencia", float(pa["hp"]), float(pb["hp"]), " cv", true, 0],
		["Peso", float(pa["kg"]), float(pb["kg"]), " kg", false, 0],
		["Velocidad máxima", float(pa["vmax"]), float(pb["vmax"]), " km/h", true, 0],
		["0 a 100 km/h (aprox.)", float(pa["t100"]), float(pb["t100"]), " s", false, 1],
		["Aceleración", float(ba["accel"]) * 100.0, float(bb["accel"]) * 100.0, " %", true, 0],
		["Manejo", float(ba["handling"]) * 100.0, float(bb["handling"]) * 100.0, " %", true, 0],
		["Frenado", float(ba["braking"]) * 100.0, float(bb["braking"]) * 100.0, " %", true, 0],
		["Off-road", float(ba["offroad"]) * 100.0, float(bb["offroad"]) * 100.0, " %", true, 0],
		["Nivel (PI)", float(pa["pi"]), float(pb["pi"]), "", true, 0]]
	for r in rows:
		var a: float = r[1]
		var b: float = r[2]
		var better: bool = r[4]
		var dec: int = r[5]
		var diff := b - a
		var changed := absf(diff) > (0.04 if dec > 0 else 0.5)
		var good := (diff > 0.0) == better
		var col := Kit.MUTED if not changed else (Color(0.45, 0.9, 0.5) if good else Color(1.0, 0.45, 0.4))
		var row := Kit.hbox(6)
		var nl := Kit.label(tr(str(r[0])), 13, Kit.TEXT if changed else Kit.MUTED)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		nl.custom_minimum_size.x = 40
		row.add_child(nl)
		var fa := "%.1f" % a if dec > 0 else str(roundi(a))
		var fb := "%.1f" % b if dec > 0 else str(roundi(b))
		var arrow := "" if not changed else (" ▲" if diff > 0.0 else " ▼")
		var vl := Kit.label("%s → %s%s%s" % [fa, fb, str(r[3]), arrow] if changed else "%s%s" % [fa, str(r[3])], 13, col, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(vl)
		box.add_child(row)

func _pv_clear(refresh := true) -> void:
	pv = {}
	if refresh:
		m.refresh_car()

## El auto con la vista previa puesta
func _pv_state(id: String, st: Dictionary) -> Dictionary:
	var d := st.duplicate(true)
	match str(pv["kind"]):
		"upg":
			(d["upg"] as Dictionary)[str(pv["key"])] = int(pv["lvl"])
		"tire":
			d["tires"] = str(pv["key"])
		"part":
			var ctx := VehicleCustomization.context(id, m.vehicles, d)
			VehicleCustomization.install(d, id, str(pv["key"]), ctx["V"], ctx["meta"])
	return d

## Barra de la vista previa: precio, números (si el cambio es mecánico), COMPRAR (acá recién se pide la plata) y VOLVER
func _pv_bar(id: String, st: Dictionary, price: int, with_stats: bool, buy: Callable) -> Control:
	var box := Kit.panel(8, Kit.PANEL2)
	var col := Kit.vbox(5)
	box.add_child(col)
	col.add_child(Kit.label(tr("👁 VISTA PREVIA · todavía no es tuyo"), 14, Kit.GOLD))
	var row := Kit.hbox(6)
	col.add_child(row)
	var b := Kit.button("🛒 %s %s" % [tr("COMPRAR"), Kit.fmt_cr(float(price))], buy, true, 16, Vector2(0, 44))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	var c := Kit.button("✖ " + tr("VOLVER"), func() -> void:
		m.sfx.play("click")
		_pv_clear()
		m.go("workshop", null, false), false, 15, Vector2(0, 44))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c)
	if with_stats:
		var sb := Kit.vbox(2)
		col.add_child(sb)
		_fill_stats(sb, id, st, _pv_state(id, st))
	return box

func _after_change() -> void:
	pv = {}
	m.refresh_car()
	m.update_credits()
	m.go("workshop", null, false)

func _ws_parts(id: String) -> void:
	var ups: Array = _cat()["upgrades"]
	var sdp := _shop_data()
	if sdp.has("parts"):
		var fil: Array = []
		for u in ups:
			if (sdp["parts"] as Array).has(str(u["id"])):
				fil.append(u)
		ups = fil
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
		var previewed: bool = not pv.is_empty() and str(pv["kind"]) == "upg" and str(pv["key"]) == uid and int(pv["lvl"]) == li
		var b := Kit.card_button(("✔ " if equipped else ("👁 " if previewed else "")) + str(lv["n"]), "", rt, func() -> void:
			if owned_p or cost <= 0:
				_buy_upgrade(id, uid, lvl_i) # ya es tuyo: se pone gratis
			else:
				m.sfx.play("click") # no es tuyo: primero se ve cómo queda (y los números); la plata se pide al comprar
				pv = {"id": id, "kind": "upg", "key": uid, "lvl": lvl_i}
				m.refresh_car(id, _pv_state(id, m.profile.d["owned"][id]))
				m.go("workshop", null, false), equipped or previewed, true, 40.0, 14)
		right.add_child(b)
	if not pv.is_empty() and str(pv["kind"]) == "upg" and str(pv["key"]) == uid:
		var pl := int(pv["lvl"])
		right.add_child(_pv_bar(id, m.profile.d["owned"][id], int(levels[pl].get("cost", 0)), true, func() -> void: _buy_upgrade(id, uid, pl)))

func _buy_upgrade(id: String, uid: String, lvl: int) -> void:
	if m.profile.buy_upgrade(id, uid, lvl):
		m.sfx.play("buy")
		_after_change()
	else:
		m.sfx.play("error")
		m.toast(tr("No te alcanza el dinero"))

func _ws_tires(id: String, st: Dictionary) -> void:
	# desgaste del juego de gomas puesto y cambio (Etapa 13)
	var cur_t := str(st["tires"])
	var wear: float = m.profile.tire_wear(id)
	var rcost := TireWear.replace_cost(float(CarBuild.tire(cur_t).get("cost", 0)))
	var fam := TireWear.family(cur_t)
	var wb := Kit.card_button("🛞 %s · %s %d%%" % [tr(TireWear.state_name(wear)), tr("desgaste"), roundi(wear * 100.0)], tr("Tipo %s · el agarre baja a %d%% cuando están lisas") % [tr(str(TireWear.NAMES[fam])), roundi(float(TireWear.GRIP_MIN[fam]) * 100.0)], tr("CAMBIAR") + " " + Kit.fmt_cr(float(rcost)), func() -> void:
		var paid: int = m.profile.replace_tires(id)
		if paid >= 0:
			m.sfx.play("buy")
			_after_change()
		else:
			m.sfx.play("error")
			m.toast(tr("No te alcanza el dinero")), false, wear >= 0.03, 66.0, 16)
	m.body.add_child(wb)
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	for t in _cat()["tires"]:
		var tid := str(t["id"])
		var have: bool = (st["tiresOwned"] as Array).has(tid)
		var eq: bool = str(st["tires"]) == tid
		var rt := tr("EQUIPADO") if eq else (tr("PONER") if have else Kit.fmt_cr(float(t["cost"])))
		var wset: float = m.profile.tire_wear(id, tid)
		var sub_t := str(t["info"]) if not (have and wset > 0.01) else "%s · %s %d%%" % [tr(TireWear.state_name(wset)), tr("desgaste"), roundi(wset * 100.0)]
		var tprev: bool = not pv.is_empty() and str(pv["kind"]) == "tire" and str(pv["key"]) == tid
		var b := Kit.card_button("%s %s%s" % [t["icon"], "👁 " if tprev else "", t["n"]], sub_t, rt, func() -> void:
			if have or int(t["cost"]) <= 0:
				if m.profile.buy_tires(id, tid):
					m.sfx.play("buy")
					_after_change()
				return
			m.sfx.play("click") # no son tuyas: se ven los números primero, la plata se pide al comprar
			pv = {"id": id, "kind": "tire", "key": tid}
			m.refresh_car(id, _pv_state(id, st))
			m.go("workshop", null, false), eq or tprev, true, 62.0, 16)
		g.add_child(b)
	if not pv.is_empty() and str(pv["kind"]) == "tire":
		var ptid := str(pv["key"])
		var pcost := int(CarBuild.tire(ptid).get("cost", 0))
		m.body.add_child(_pv_bar(id, st, pcost, true, func() -> void:
			if m.profile.buy_tires(id, ptid):
				m.sfx.play("buy")
				_after_change()
			else:
				m.sfx.play("error")
				m.toast(tr("No te alcanza el dinero"))))

## Llantas modulares: se ven puestas en el auto de la sala al instante. Comprar = pagar una vez por auto; cambiar entre las compradas es gratis.
func _ws_rims(id: String, st: Dictionary) -> void:
	_ws_part_grid(id, st, "wheel")

## Estética modular (alerones, paragolpes, faldones…): una categoría por chip
func _ws_body(id: String, st: Dictionary) -> void:
	var cats: Array = []
	for c in BODY_CATS:
		if not PartCatalog.parts_in(str(c)).is_empty():
			cats.append(str(c))
	if cats.is_empty():
		m.body.add_child(Kit.wrap(tr("Todavía no hay piezas de estética para este taller."), 14, Kit.MUTED, 300))
		return
	body_cat = clampi(body_cat, 0, cats.size() - 1)
	var names: Array = []
	for c in cats:
		names.append(tr(str(PartCatalog.category(str(c)).get("name", c))))
	m.body.add_child(Kit.tabs(names, body_cat, func(i: int) -> void:
		body_cat = i
		m.sfx.play("click")
		m.go("workshop", null, false), 15, 36.0))
	_ws_part_grid(id, st, str(cats[body_cat]))

func _ws_part_grid(id: String, st: Dictionary, cat: String) -> void:
	if not pv.is_empty() and str(pv["kind"]) == "part" and str(pv.get("cat", "")) != cat:
		_pv_clear() # cambió de categoría: se saca la pieza que se estaba viendo
	var ctx := VehicleCustomization.context(id, m.vehicles, st)
	var cur := str((VehicleCustomization.installed(st).get(cat, {}) as Dictionary).get("id", ""))
	if not VehicleCustomization.supports(id):
		m.body.add_child(Kit.wrap(tr("Este auto todavía no admite piezas modulares."), 14, Kit.MUTED, 300))
		return
	var own: Array = st.get("partsOwned", [])
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	var stock := Kit.card_button(tr("ORIGINAL"), tr("Como viene de fábrica"), tr("EQUIPADO") if cur == "" else tr("PONER"), func() -> void:
		m.profile.remove_part(id, cat)
		m.sfx.play("click")
		_after_change(), cur == "", true, 64.0, 16)
	g.add_child(stock)
	for pid in PartCatalog.parts_in(cat, bool(m.profile.d["settings"].get("dev", false))):
		var p := PartCatalog.part(str(pid))
		var ok: bool = bool(VehicleCustomization.can_install(str(pid), id, ctx["V"], ctx["meta"])["ok"])
		var eq: bool = cur == str(pid)
		var have: bool = own.has(str(pid))
		var rt := tr("EQUIPADO") if eq else (tr("PONER") if have else Kit.fmt_cr(float(p.get("price", 0))))
		var pprev: bool = not pv.is_empty() and str(pv["kind"]) == "part" and str(pv["key"]) == str(pid)
		var b := Kit.card_button(("👁 " if pprev else "") + tr(str(p["name"])), "" if ok else tr("No entra en este auto"), rt, func() -> void:
			if have or int(p.get("price", 0)) <= 0:
				var r0: Dictionary = m.profile.buy_part(id, str(pid), m.vehicles)
				if bool(r0["ok"]):
					m.sfx.play("buy")
					_after_change()
				else:
					m.sfx.play("error")
					m.toast(tr(str(r0["reason"])))
				return
			m.sfx.play("click") # no es tuya: se ve puesta en el auto; la plata se pide al tocar COMPRAR
			pv = {"id": id, "kind": "part", "key": str(pid), "cat": cat}
			m.refresh_car(id, _pv_state(id, st))
			m.go("workshop", null, false), eq or pprev, ok, 64.0, 16)
		g.add_child(b)
	if not pv.is_empty() and str(pv["kind"]) == "part" and str(pv["cat"]) == cat:
		var ppid := str(pv["key"])
		m.body.add_child(_pv_bar(id, st, int(PartCatalog.part(ppid).get("price", 0)), false, func() -> void:
			var r: Dictionary = m.profile.buy_part(id, ppid, m.vehicles)
			if bool(r["ok"]):
				m.sfx.play("buy")
				_after_change()
			else:
				m.sfx.play("error")
				m.toast(tr(str(r["reason"])))))

func _draft_sync(id: String, st: Dictionary) -> void:
	if draft_id != id:
		draft_id = id
		draft_tune = (st["tune"] as Dictionary).duplicate(true)
		draft_paint = (st["paint"] as Dictionary).duplicate(true)

func _tune_changes(id: String, st: Dictionary) -> int:
	var defs := CarBuild.default_tune(m.vehicles[id])
	var n := 0
	var keys := {}
	for k in draft_tune:
		keys[k] = true
	for k in (st["tune"] as Dictionary):
		keys[k] = true
	for k in keys:
		var a := float(draft_tune.get(k, defs.get(k, 0.0)))
		var b := float((st["tune"] as Dictionary).get(k, defs.get(k, 0.0)))
		if absf(a - b) > 0.0001:
			n += 1
	return n

func _paint_changed(st: Dictionary) -> bool:
	return draft_paint.hash() != (st["paint"] as Dictionary).hash()

func _fee(id: String, st: Dictionary) -> int:
	var n := _tune_changes(id, st)
	var fee := 0
	if n > 0:
		fee += mini(TUNE_FEE_MAX, TUNE_FEE + TUNE_FEE_EACH * n)
	if _paint_changed(st):
		fee += PAINT_FEE
	return fee

## El auto con el borrador puesto (para verlo en la sala y para probarlo)
func _draft_state(st: Dictionary) -> Dictionary:
	var d := st.duplicate(true)
	d["tune"] = draft_tune.duplicate(true)
	d["paint"] = draft_paint.duplicate(true)
	return d

func _draft_refresh(id: String, st: Dictionary) -> void:
	m.refresh_car(id, _draft_state(st))
	_draft_update_bar(id, st)

## Los números del reglaje que se está armando contra el auto como está hoy (se actualiza al mover cada control)
func _tune_stats(id: String, st: Dictionary) -> void:
	if tune_stats_box == null or not is_instance_valid(tune_stats_box) or ws_tab != 2:
		return
	if _tune_changes(id, st) == 0:
		for c in tune_stats_box.get_children():
			c.queue_free()
		tune_stats_box.add_child(Kit.label(tr("Cómo cambia el auto"), 15, Kit.GOLD))
		tune_stats_box.add_child(Kit.wrap(tr("Movés un control y acá ves qué sube (verde ▲) y qué baja (rojo ▼): potencia, aceleración, velocidad, manejo, frenado…"), 12, Kit.MUTED, 300))
		return
	_fill_stats(tune_stats_box, id, st, _draft_state(st))

func _draft_update_bar(id: String, st: Dictionary) -> void:
	_tune_stats(id, st)
	if draft_lbl == null or not is_instance_valid(draft_lbl):
		return
	var fee := _fee(id, st)
	draft_lbl.text = (Tr.t("Sin cambios") if fee == 0 else Tr.t("Cambios sin aplicar · el mecánico cobra %s") % Kit.fmt_cr(float(fee)))
	if draft_apply != null and is_instance_valid(draft_apply):
		draft_apply.disabled = fee == 0 or m.profile.credits < fee
		draft_apply.text = (Tr.t("✔ APLICAR") + " " + Kit.fmt_cr(float(fee))) if fee > 0 else Tr.t("✔ APLICAR")

## Barra del borrador: cuánto cuesta y APLICAR / DESCARTAR; y a probarlo gratis en una pista
func _draft_bar(id: String, st: Dictionary, with_test: bool) -> void:
	_draft_sync(id, st)
	var box := Kit.panel(8, Kit.PANEL2)
	m.body.add_child(box)
	var col := Kit.vbox(6)
	box.add_child(col)
	draft_lbl = Kit.label("", 15, Kit.GOLD)
	col.add_child(draft_lbl)
	var row := Kit.hbox(6)
	col.add_child(row)
	draft_apply = Kit.button("✔ APLICAR", func() -> void:
		var fee := _fee(id, st)
		if fee <= 0:
			return
		if not m.profile.spend(fee):
			m.sfx.play("error")
			m.toast(tr("No te alcanza el dinero"))
			return
		st["tune"] = draft_tune.duplicate(true)
		st["paint"] = draft_paint.duplicate(true)
		m.profile.save()
		m.sfx.play("buy")
		m.refresh_car()
		m.update_credits()
		m.toast(tr("🔧 Listo: el mecánico terminó el trabajo"))
		m.go("workshop", null, false), true, 17, Vector2(0, 44))
	draft_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(draft_apply)
	var disc := Kit.button("↺ DESCARTAR", func() -> void:
		draft_id = ""
		_draft_sync(id, st)
		m.sfx.play("click")
		m.refresh_car()
		m.go("workshop", null, false), false, 15, Vector2(0, 44))
	disc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(disc)
	if with_test:
		var trow := Kit.hbox(6)
		col.add_child(trow)
		for tt in [["🏁 PROBAR EN ASFALTO", "lake"], ["🏜 EN TIERRA", "forest"], ["🌀 EN DRIFT", "drift"]]:
			var tmap: String = tt[1]
			var tb := Kit.button(tt[0], func() -> void:
				m.sfx.play("click")
				var tcfg := {"type": "free", "track": tmap, "ai": 0, "sky": "day", "car": id, "state": _draft_state(st), "testCar": true, "back": "workshop", "seed": 7}
				if tmap == "drift":
					tcfg["type"] = "drift"
					tcfg["time"] = 1800
				m.launch(tcfg, false), false, 14, Vector2(0, 40))
			tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			trow.add_child(tb)
		col.add_child(Kit.wrap("Probar es gratis: ajustá a gusto y volvé cuando esté listo. Solo se cobra al aplicar.", 12, Kit.MUTED, 300))
	_draft_update_bar(id, st)

# ── ajuste fino ──
func _ws_tune(id: String, st: Dictionary) -> void:
	var base: Dictionary = m.vehicles[id]
	var defs := CarBuild.default_tune(base)
	_draft_sync(id, st)
	var tune: Dictionary = draft_tune
	var groups: Array = _cat()["tune"]
	var sdt := _shop_data()
	if sdt.has("tune"):
		var fg: Array = []
		for g in groups:
			if (sdt["tune"] as Array).has(str(g["g"])):
				fg.append(g)
		groups = fg
	tune_grp = clampi(tune_grp, 0, groups.size() - 1)
	var names: Array = []
	for g in groups:
		names.append(str(GROUP_SHORT.get(str(g["g"]), str(g["g"]))))
	m.body.add_child(Kit.tabs(names, tune_grp, func(i: int) -> void:
		tune_grp = i
		tune_info = ""
		m.sfx.play("click")
		m.go("workshop", null, false), 14, 36.0))
	_draft_bar(id, st, true)
	var tsp := Kit.panel(8, Kit.PANEL2)
	tune_stats_box = Kit.vbox(2)
	tsp.add_child(tune_stats_box)
	m.body.add_child(tsp)
	_tune_stats(id, st)
	m.body.add_child(Kit.wrap("Debajo de cada ajuste ves qué pasa si lo bajás (▼) y si lo subís (▲).", 12, Kit.GOLD, 300))
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
		if it.has("lo"):
			m.body.add_child(Kit.wrap("▼ %s\n▲ %s" % [Tr.t(str(it["lo"])), Tr.t(str(it["hi"]))], 12, Kit.MUTED, 300)) # guía fácil: qué pasa si lo bajás y si lo subís
		var txt := str(it.get("info", ""))
		sl.value_changed.connect(func(nv: float) -> void:
			tune[k] = nv
			vl.text = "%s %s" % [_num(nv), unit]
			tune_info = txt
			info.text = txt
			_draft_update_bar(id, st))
		sl.drag_ended.connect(func(_c: bool) -> void:
			_draft_refresh(id, st))
	m.body.add_child(info)
	var prow := Kit.hbox(6)
	m.body.add_child(prow)
	for pk in ["asfalto", "tierra", "drift", "salto"]:
		var key: String = pk
		var pb := Kit.button(str(_cat()["preset_n"][pk]), func() -> void:
			m.sfx.play("click")
			draft_tune = {}
			for k2 in _cat()["presets"][key]:
				draft_tune[k2] = float(_cat()["presets"][key][k2])
			_draft_refresh(id, st)
			m.go("workshop", null, false), false, 15, Vector2(0, 40))
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(pb)
	var rb := Kit.button("↺ FÁBRICA", func() -> void:
		draft_tune = {}
		_draft_refresh(id, st)
		m.go("workshop", null, false), false, 15, Vector2(0, 40))
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prow.add_child(rb)

func _num(v: float) -> String:
	return str(snappedf(v, 0.01)) if absf(v - roundf(v)) > 0.001 else str(int(roundf(v)))

# ── pintura ──
func _ws_paint(id: String, st: Dictionary) -> void:
	_draft_bar(id, st, false)
	var paint: Dictionary = draft_paint
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
				m.sfx.play("click")
				_draft_refresh(id, st)
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
				m.sfx.play("click")
				_draft_refresh(id, st)
				m.go("workshop", null, false))
			grid.add_child(sw)
	var sg := Kit.grid(2, 8, 8)
	m.body.add_child(sg)
	var lids: Array = []
	for li in CarVisualS.LIVERIES.size():
		lids.append(li)
	sg.add_child(Kit.selector("Rotulado (usa el color de Detalles)", lids, int(paint.get("livery", 0)), func(v) -> String: return str(CarVisualS.LIVERIES[int(v)]), func(v) -> void:
		paint["livery"] = int(v)
		_draft_refresh(id, st), m.sfx, 62.0))
	var fids: Array = []
	var fnames := {}
	for f in _cat()["finishes"]:
		fids.append(str(f["id"]))
		fnames[str(f["id"])] = str(f["n"])
	sg.add_child(Kit.selector("Acabado", fids, str(paint.get("finish", "gloss")), func(v) -> String: return str(fnames[v]), func(v) -> void:
		paint["finish"] = str(v)
		_draft_refresh(id, st), m.sfx, 62.0))
