extends RefCounted
## Pantallas de entrada al MUNDO ABIERTO y al MODO ONLINE del menú (Etapa 23: antes estaban dentro de menu.gd): elegir dónde aparecer, hub online (apodo, conexión, créditos y regalo diario),
## apodo del jugador, cuenta/rankings y las pantallas «pronto». `m` es el menú (menu.gd): usa su cuerpo, sonidos, avisos y perfil.

const Kit := preload("res://game/ui/ui_kit.gd")
const Sectors := preload("res://game/region/sectors.gd")
const CityReach := preload("res://game/city/city_reach.gd")
const Release := preload("res://game/data/release.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const OnlineSocial := preload("res://game/online/online_social.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const RegionServices := preload("res://game/region/region_services.gd")
const SpawnMap := preload("res://game/ui/spawn_map.gd")

var m # menu.gd


func _start_city(spawn := 0) -> void:
	var online_world: bool = m.world_online and m.app.online != null and m.app.online.is_account()
	var prof: RefCounted = m.profile
	if online_world: # el mundo online usa los autos y los créditos del servidor (aparte del progreso offline)
		m.toast(tr("Conectando con tu garaje online…"))
		if not await m.app.enter_online():
			m.sfx.play("error")
			m.toast(tr("No se pudo cargar tu garaje online. Revisá la conexión."))
			return
		prof = m.app.oprofile
	var pid: String = prof.current_id()
	prof.select(pid)
	var cfg := {"type": "city", "track": "aurelia", "ai": 0, "sky": "day", "car": pid, "state": prof.car(), "seed": 7, "back": "home", "quick": true, "spawn": spawn, "online": online_world}
	if spawn < 0: # última ubicación
		var lp: Array = prof.d["lastPos"]
		cfg["resume"] = [float(lp[0]), float(lp[1]), float(lp[2])]
	m.launch(cfg)

## La última ubicación guardada (x, z, rumbo) si sirve en esta versión del mapa; si no, null
func _last_pos_value() -> Variant:
	var lp: Variant = (((m.profile.d.get("online", {}) as Dictionary).get("lastPos", null)) if m.world_online else m.profile.d.get("lastPos", null))
	if lp is Array and (lp as Array).size() >= 4 and int((lp as Array)[3]) == CityLayout.WORLD_VERSION:
		return lp
	return null

## ¿Hay una última ubicación guardada y sirve en esta versión del mapa?
func _has_last_pos() -> bool:
	return _last_pos_value() != null

const SPAWN_PLACES := [["Central · Nivel calle", "Estacionamiento Central, a nivel de la calle: salís directo a la ruta"], ["Central · Planta alta", "Estacionamiento Central, un piso arriba: bajás por la rampa"], ["Central · Subsuelo", "Estacionamiento Central, un piso abajo: subís por la rampa"]]

var locked: Array = [] # lugares de la región a los que todavía no se llegó manejando (city/city_reach.gd): en el mapa con candado

## Lugares para aparecer, en un solo selector: la última ubicación, los 3 estacionamientos de Dream City y las estaciones de servicio de las ciudades y pueblos de la región (los más cercanos primero).
## Cada uno: {key, name, sub, pos (mapa), kind, spawn (índice en city.spawns; -1 = última ubicación)}
func _spawn_options() -> Array:
	var out: Array = []
	locked = []
	var lp: Variant = _last_pos_value()
	if lp != null and Sectors.is_open(Vector2(float(lp[0]), float(lp[1]))): # (en un sector en obra no se aparece)
		out.append({"key": "last", "name": "📍 " + tr("ÚLTIMA UBICACIÓN"), "sub": tr("seguís desde donde dejaste el auto"), "pos": Vector2(float(lp[0]), float(lp[1])), "kind": "last", "spawn": -1})
	for i in SPAWN_PLACES.size():
		out.append({"key": "park%d" % i, "name": "🅿 " + tr(str(SPAWN_PLACES[i][0])), "sub": tr(str(SPAWN_PLACES[i][1])), "pos": Vector2.ZERO, "kind": "dream", "spawn": i})
	if RegionServices.available():
		var towns: Array = []
		var list := RegionServices.spawn_list()
		var reached := CityReach.reached_of(m.profile)
		for j in list.size():
			var sp: Dictionary = list[j]
			var pos := Vector2(float(sp["x"]), float(sp["z"]))
			if not Sectors.is_open(pos):
				continue # sector en obra: se ve en el mapa pero no se aparece ahí (game/data/sectors.json)
			var city_like := str(sp.get("kind", "")) == "ciudad"
			if not reached.has(str(sp["name"])) and not Release.dev(m.profile):
				# todavía no llegaste manejando (pasando los controles policiales): se ve en el mapa con candado, no se puede elegir
				locked.append({"key": "lock:%d" % j, "pos": pos, "label": "🔒 " + str(sp["name"]), "kind": "locked", "name": str(sp["name"])})
				continue
			towns.append({"key": "town:%d" % j, "name": ("🏙 " if city_like else "🏘 ") + str(sp["name"]), "sub": tr("estación de servicio") + " · %d km " % roundi(pos.length() / 1000.0) + tr("de Dream City"),
				"pos": pos, "kind": "ciudad" if city_like else "pueblo", "label": str(sp["name"]), "spawn": SPAWN_PLACES.size() + j})
		towns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["pos"] as Vector2).length() < (b["pos"] as Vector2).length())
		out.append_array(towns)
	return out

## Antes de entrar al mundo abierto se elige dónde aparecer. Un solo selector con las flechas ◀ ▶ y el mapa de la región, que también se toca: un toque elige el lugar más cercano
## (tocar Dream City pasa de un estacionamiento al siguiente). Todos los lugares tienen estación o estacionamiento: se arranca y se sale manejando.
func spawn_screen() -> void:
	m.set_title(tr("¿DÓNDE APARECER?"))
	var opts := _spawn_options()
	var saved := str(m.profile.setting("spawnPick")) if m.profile.setting("spawnPick") != null else ""
	var sel := 0
	var found := false
	for i in opts.size():
		if str(opts[i]["key"]) == saved:
			sel = i
			found = true
			break
	if not found:
		sel = 0 # la última ubicación si hay; si no, el Estacionamiento Central
	# pantalla completa: el mapa a la izquierda (lo más grande posible) y los controles a la derecha
	m.panel.anchor_right = 1.0
	m.view_frac = 1.0
	m._apply_view_shift()
	m.body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := Kit.hbox(12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.body.add_child(row)
	# el mapa: una marca por lugar (los 3 estacionamientos son una sola, Dream City)
	var map := SpawnMap.new()
	map.marks.append({"key": "dream", "pos": Vector2.ZERO, "label": "Dream City", "kind": "dream"})
	for lk in locked:
		map.marks.append(lk)
	for o in opts:
		if str(o["kind"]) in ["ciudad", "pueblo", "last"]:
			map.marks.append({"key": str(o["key"]), "pos": o["pos"], "label": str(o.get("label", tr("Última ubicación"))), "kind": str(o["kind"])})
	row.add_child(map)
	var side := Kit.vbox(10)
	side.custom_minimum_size.x = 350
	side.size_flags_horizontal = Control.SIZE_FILL
	side.size_flags_stretch_ratio = 0.0
	row.add_child(side)
	side.add_child(Kit.wrap(tr("Tocá un lugar en el mapa o usá las flechas. Todos tienen estación de servicio o estacionamiento: se sale manejando."), 15, Kit.MUTED, 300))
	if not locked.is_empty():
		side.add_child(Kit.wrap("🔒 " + tr("Las otras ciudades y pueblos se habilitan cuando llegás manejando (la policía controla las rutas largas)."), 14, Kit.GOLD, 300))
	var info := Kit.wrap("", 16, Kit.TEXT, 300)
	var holder := {"sel": sel}
	var selector: PanelContainer = null
	var show_pick := func(i: int, from_selector: bool) -> void:
		holder["sel"] = i
		var o: Dictionary = opts[i]
		map.select("dream" if str(o["kind"]) == "dream" else str(o["key"]))
		info.text = str(o["sub"])
		m.profile.set_setting("spawnPick", str(o["key"]))
		if not from_selector and selector != null:
			selector.call("set_value", i)
	selector = Kit.selector(tr("LUGAR"), range(opts.size()), sel, func(v) -> String: return str(opts[int(v)]["name"]), func(v) -> void: show_pick.call(int(v), true), m.sfx, 76.0)
	side.add_child(selector)
	side.add_child(info)
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(grow)
	map.tapped.connect(func(key: String) -> void:
		var target := -1
		if key == "dream":
			# Dream City: si ya se estaba en un estacionamiento se pasa al siguiente; si no, al primero
			var parks: Array = []
			for i in opts.size():
				if str(opts[i]["kind"]) == "dream":
					parks.append(i)
			if not parks.is_empty():
				var at := parks.find(int(holder["sel"]))
				target = int(parks[(at + 1) % parks.size()]) if at >= 0 else int(parks[0])
		elif key.begins_with("lock:"):
			for lk in locked:
				if str(lk["key"]) == key:
					m.sfx.play("click")
					info.text = "🔒 %s: %s" % [str(lk["name"]), tr("todavía no llegaste manejando. Salí de Dream City por la ruta, pasá los controles policiales y, al llegar, vas a poder aparecer acá.")]
			return
		else:
			for i in opts.size():
				if str(opts[i]["key"]) == key:
					target = i
		if target >= 0:
			m.sfx.play("click")
			show_pick.call(target, false))
	show_pick.call(sel, false)
	side.add_child(Kit.button("▶ " + tr("APARECER AQUÍ"), func() -> void:
		m.sfx.play("click")
		var o: Dictionary = opts[int(holder["sel"])]
		_start_city(int(o["spawn"])), true, 26, Vector2(0, 66)))
	if Release.tools():
		side.add_child(m.menu_button("📊 " + tr("DIAGNÓSTICO"), "", func() -> void:
			m.sfx.play("click")
			m.go("diag"), false))

## Modo online: sin cuenta se pide una (ver _online_options); con cuenta pide el apodo la primera vez y muestra el hub del mundo online
func online_home() -> void:
	m.set_title(tr("MODO ONLINE"))
	if not Release.online_open(m.profile):
		m.body.add_child(Kit.label("🔒 " + tr("CERRADO POR AHORA"), 28, Kit.ACCENT))
		m.body.add_child(Kit.wrap(tr("El modo online está cerrado hasta la próxima actualización: estamos afinando el tiempo real para que los autos de los demás jugadores se vean y se muevan perfecto. Mientras tanto podés recorrer Dream City sin conexión."), 15, Kit.TEXT, 300))
		m.body.add_child(m.menu_button("🏙 " + tr("DREAM CITY"), tr("recorrer sin conexión"), func() -> void:
			m.sfx.play("click")
			m.world_online = false
			m.go("spawn"), true))
		return
	if m.app.online == null or not m.app.online.configured():
		m.body.add_child(Kit.wrap(tr("El modo online todavía no está disponible en esta versión. Mientras tanto podés recorrer Dream City sin conexión."), 15, Kit.TEXT, 300))
		m.body.add_child(m.menu_button("🏙 " + tr("DREAM CITY"), tr("recorrer sin conexión"), func() -> void:
			m.sfx.play("click")
			m.world_online = false
			m.go("spawn"), true))
		return
	if not m.app.online.is_account():
		_online_options()
		return
	if m.profile.d.get("nickSet", false) != true:
		m.go("nick", null, false)
		return
	_online_hub()

## El hub del mundo online (rediseño 14/10/2026): tarjeta del piloto con el estado de la conexión, el botón grande para entrar al mundo, accesos a lo que se maneja
## desde el menú (regalo diario, rankings, cuenta, dónde aparecer) y un resumen de lo que hay adentro del mundo (en la pausa: chat, jugadores y amigos, mercado, reportes).
## Sólo se muestra lo que anda: nada de botones de adorno. La conexión se consulta sin trabar la pantalla; si no hay, se puede entrar igual o reintentar.
func _online_hub() -> void:
	var nick := str(m.profile.d.get("name", "Piloto"))
	# ── tarjeta del piloto
	var card := Kit.panel(14, Kit.PANEL2)
	m.body.add_child(card)
	var cv := Kit.vbox(6)
	card.add_child(cv)
	var head := Kit.hbox(10)
	cv.add_child(head)
	var av := Kit.label(nick.substr(0, 1).to_upper(), 30, Color(0.05, 0.06, 0.08), HORIZONTAL_ALIGNMENT_CENTER)
	av.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	av.custom_minimum_size = Vector2(54, 54)
	av.add_theme_stylebox_override("normal", Kit.box(Kit.ACCENT, 27, Color(1, 1, 1, 0.6), 2, 0))
	head.add_child(av)
	var nv := Kit.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nv)
	var nl := Kit.label(nick, 24, Kit.TEXT)
	nl.clip_text = true
	nl.custom_minimum_size.x = 40
	nv.add_child(nl)
	var cid: String = m.profile.current_id()
	var cm: Dictionary = CarBuild.catalog()["cars"].get(cid, {})
	var car_l := Kit.label("%s %s" % [str(cm.get("brand", "")), str(cm.get("model", ""))], 14, Kit.MUTED)
	car_l.clip_text = true
	car_l.custom_minimum_size.x = 40
	nv.add_child(car_l)
	head.add_child(Kit.button(tr("NOMBRE"), func() -> void:
		m.sfx.play("click")
		m.go("nick"), false, 13, Vector2(90, 36)))
	var pills := Kit.hbox(8)
	cv.add_child(pills)
	var st_l := Kit.label("● " + tr("Conectando…"), 14, Kit.MUTED)
	st_l.add_theme_stylebox_override("normal", Kit.box(Color(0, 0, 0, 0.25), 12, Color(1, 1, 1, 0.15), 1, 6))
	pills.add_child(st_l)
	var pl_l := Kit.label("", 14, Kit.MUTED)
	pl_l.clip_text = true
	pl_l.custom_minimum_size.x = 40
	pl_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pills.add_child(pl_l)
	var wal_l := Kit.label("💰 " + tr("Créditos online") + ": …", 16, Kit.GOLD)
	cv.add_child(wal_l)
	# ── entrar
	m.body.add_child(m.menu_button(tr("ENTRAR AL MUNDO ONLINE"), tr("Dream City y la región · elegí dónde aparecer"), func() -> void:
		m.sfx.play("click")
		m.world_online = true
		m.go("spawn"), true, true, 22))
	# ── accesos (sólo lo que anda desde el menú)
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	var gift: Button = m.tile("bag", tr("REGALO DIARIO"), tr("cargando…"), func() -> void: pass, false, 64.0)
	gift.disabled = true
	g.add_child(gift)
	var on_r: bool = m.profile.setting("onlineScores") == true
	g.add_child(m.tile("trophy", tr("RANKINGS"), ("☑ " + tr("participás")) if on_r else ("☐ " + tr("no participás")), func() -> void:
		m.profile.set_setting("onlineScores", not on_r)
		m.go("online", null, false), false, 64.0))
	var mail := str(m.app.online.email)
	g.add_child(m.tile("gear", tr("CUENTA"), mail if mail != "" else tr("tu correo"), func() -> void: m.go("account"), false, 64.0))
	g.add_child(m.tile("world", tr("DÓNDE APARECER"), tr("estacionamientos y pueblos"), func() -> void:
		m.world_online = true
		m.go("spawn"), false, 64.0))
	var gar: Button = m.tile("car", tr("MI GARAJE ONLINE"), tr("cargando…"), func() -> void:
		m.sfx.play("click")
		m.go("ogarage"), false, 64.0)
	gar.disabled = true
	g.add_child(gar)
	# ── lo que hay adentro del mundo
	var inside := Kit.panel(10, Kit.PANEL2)
	m.body.add_child(inside)
	var iv := Kit.vbox(3)
	inside.add_child(iv)
	iv.add_child(Kit.label(tr("ADENTRO DEL MUNDO · en la pausa"), 14, Kit.ACCENT))
	for t in ["💬 " + tr("Chat mundial y mensajes privados"), "👥 " + tr("Jugadores conectados y amigos"), "🚗 " + tr("Mercado de autos entre jugadores"), "🛡 " + tr("Reportes y bloqueos (protegen el chat)"), "🚨 " + tr("Controles policiales en las rutas")]:
		iv.add_child(Kit.label(t, 14, Kit.TEXT))
	if Release.dev(m.profile):
		var res := Kit.wrap("", 13, Kit.GREEN, 300)
		m.body.add_child(Kit.button("🛠 Probar conexión con Supabase", func() -> void:
			res.text = tr("Probando…")
			var r0: Dictionary = await m.app.online.ping()
			res.text = str(r0["text"]), false, 15, Vector2(0, 44)))
		m.body.add_child(res)
	# billetera online (la guarda el servidor, aparte de los créditos sin conexión) y regalo diario
	if await m.app.enter_online() and is_instance_valid(wal_l):
		wal_l.text = "💰 %s: %s" % [tr("Créditos online"), Kit.fmt_cr(float(m.app.eco.credits))]
		var op: RefCounted = m.app.oprofile
		var ocm: Dictionary = CarBuild.catalog()["cars"].get(op.current_id(), {})
		car_l.text = "%s %s" % [str(ocm.get("brand", "")), str(ocm.get("model", ""))] # (el auto del garaje online, no el del juego sin conexión)
		gar.disabled = false
		_tile_sub(gar, tr("%d autos · elegí cuál usar") % (op.d["owned"] as Dictionary).size())
		gift.disabled = false
		_tile_sub(gift, tr("cobrar el de hoy"))
		gift.pressed.connect(func() -> void:
			m.sfx.play("click")
			var gr: Dictionary = await m.app.eco.daily()
			if not is_instance_valid(wal_l):
				return
			if bool(gr["ok"]):
				m.sfx.play("buy")
				m.toast(tr("¡Regalo del día! +%s créditos online") % Kit.fmt_cr(float(gr["gift"])))
				wal_l.text = "💰 %s: %s" % [tr("Créditos online"), Kit.fmt_cr(float(m.app.eco.credits))]
			else:
				m.toast(tr(str(gr["text"]))))
	elif is_instance_valid(gift):
		_tile_sub(gift, tr("sin conexión"))
		_tile_sub(gar, tr("sin conexión"))
		wal_l.text = "💰 %s: %s" % [tr("Créditos online"), tr("sin conexión")]
	# estado de la conexión y jugadores (sin trabar la pantalla)
	var on: Node = m.app.online
	var r: Dictionary = await on.call_fn("presence_list", {"p_limit": 60})
	if not is_instance_valid(st_l):
		return
	if r["ok"] and r["data"] is Array:
		st_l.text = "● " + tr("Conectado")
		st_l.add_theme_color_override("font_color", Kit.GREEN)
		var n := 0
		var fr := 0
		for p in (r["data"] as Array):
			if bool(p.get("is_me", false)):
				continue
			n += 1
			if bool(p.get("is_friend", false)):
				fr += 1
		pl_l.text = "👥 %s · ⭐ %s" % [tr("%d jugadores online") % n, tr("%d amigos") % fr]
	else:
		st_l.text = "● " + tr("Sin conexión")
		st_l.add_theme_color_override("font_color", Kit.RED)
		pl_l.text = tr("se puede entrar igual, sin chat ni jugadores")
		cv.add_child(Kit.button("↻ " + tr("REINTENTAR"), func() -> void:
			m.sfx.play("click")
			m.go("online", null, false), false, 14, Vector2(0, 40)))

## Cambia la línea chica de un mosaico del menú (m.tile: ícono, nombre, línea chica)
## Mi garaje online (15/10/2026, pedido del dueño: «me compré autos y una camioneta y el modo online no me deja elegirlos»): los autos que guarda el
## servidor (los comprados en los concesionarios del mundo online, más los de la cuenta, que pasan una vez al garaje online) y cuál se usa al entrar.
## Mejorar, pintar y vender se hace en los talleres y el mercado del mundo; acá sólo se elige.
func online_garage() -> void:
	m.set_title(tr("MI GARAJE ONLINE"))
	var op: RefCounted = m.app.oprofile
	if op == null:
		m.body.add_child(Kit.label(tr("Conectando con tu garaje online…"), 16, Kit.MUTED))
		if not await m.app.enter_online():
			m.toast(tr("No se pudo cargar tu garaje online. Revisá la conexión."))
			return
		m.go("ogarage", null, false)
		return
	var owned: Dictionary = op.d["owned"]
	var cars: Dictionary = CarBuild.catalog()["cars"]
	m.body.add_child(Kit.label("💰 %s: %s" % [tr("Créditos online"), Kit.fmt_cr(float(m.app.eco.credits))], 16, Kit.GOLD))
	m.body.add_child(Kit.wrap(tr("Los autos que compraste en los concesionarios del mundo online y los de tu cuenta. Tocá uno para usarlo al entrar. Las mejoras y la pintura se hacen en los talleres de Dream City."), 13, Kit.MUTED, 300))
	if owned.is_empty():
		m.body.add_child(Kit.label(tr("Todavía no tenés autos online."), 16, Kit.MUTED))
		return
	var cur: String = op.current_id()
	if cur != "":
		m.refresh_car(cur, owned[cur])
	for key in owned:
		var id := str(key)
		var st: Dictionary = owned[id]
		var cm: Dictionary = cars.get(id, {})
		var pf: Dictionary = CarBuild.perf_of(CarBuild.build_params(m.vehicles[id], st)) if m.vehicles.has(id) else {}
		var sub := "%d cv · %d km/h · %s km" % [int(pf.get("hp", 0)), int(pf.get("vmax", 0)), Kit.fmt_cr(float(st.get("km", 0.0)))]
		var on := id == cur
		m.body.add_child(m.menu_button(("✓ " if on else "") + "%s %s" % [str(cm.get("brand", "")), str(cm.get("model", id))], (tr("EN USO") + " · " if on else "") + sub, func() -> void:
			m.sfx.play("click")
			op.select(id)
			m.refresh_car(id, owned[id])
			m.go("ogarage", null, false), on, true, 18))

func _tile_sub(t: Button, txt: String) -> void:
	var labels: Array = []
	var stack: Array = [t]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		if n is Label:
			labels.append(n)
		stack.append_array(n.get_children())
	if labels.size() >= 2:
		(labels[labels.size() - 1] as Label).text = txt

## Apodo del jugador (se muestra en la lista de jugadores, el chat, los amigos, los reportes y el mercado)
func nick_screen() -> void:
	m.set_title(tr("NOMBRE DEL JUGADOR"))
	var first: bool = m.profile.d.get("nickSet", false) != true
	m.body.add_child(Kit.wrap(tr("Elegí el nombre con el que te van a ver los demás jugadores. Entre 3 y 16 letras, sin insultos."), 15, Kit.TEXT, 300))
	var le := LineEdit.new()
	le.text = "" if first else str(m.profile.d.get("name", ""))
	le.placeholder_text = tr("Tu nombre de piloto")
	le.max_length = 16
	le.custom_minimum_size = Vector2(0, 58)
	le.add_theme_font_size_override("font_size", 24)
	m.body.add_child(le)
	var msg := Kit.wrap("", 14, Kit.RED, 300)
	var ok := func() -> void:
		var t := le.text.strip_edges()
		var e: String = OnlineSocial.nick_error(t)
		if e != "":
			msg.text = tr(e)
			return
		m.sfx.play("click")
		m.profile.d["name"] = t
		m.profile.d["nickSet"] = true
		m.profile.save()
		m.go("online", null, false)
	m.body.add_child(Kit.button("✔ " + tr("CONFIRMAR"), ok, true, 22, Vector2(0, 60)))
	m.body.add_child(msg)
	le.text_submitted.connect(func(_s: String) -> void: ok.call())
	if not first:
		m.body.add_child(Kit.button(tr("← Volver"), func() -> void:
			m.sfx.play("click")
			m.go("online", null, false), false, 16, Vector2(0, 46)))

## Pantallas «pronto» del modo online y del mundo abierto (todavía cerrados)
func soon_screen(kind: String) -> void:
	var online := kind == "online"
	m.set_title("MODO ONLINE" if online else "MUNDO ABIERTO")
	m.body.add_child(Kit.label("🚧 PRONTO", 34, Kit.ACCENT))
	if online:
		m.body.add_child(Kit.wrap("Se viene el modo online: carreras de jugador contra jugador, un ranking mundial y eventos mensuales con premios.", 18, Kit.TEXT, 300))
		for t in ["🏁 Carreras JcJ contra otros pilotos", "🏆 Ranking de tiempos y puntos", "📅 Eventos mensuales", "🌍 Mundo abierto compartido"]:
			m.body.add_child(Kit.label(t, 18, Kit.GOLD))
	else:
		m.body.add_child(Kit.wrap("Llega el mundo abierto: ciudades amplias, diversos biomas, rutas espectaculares y libre recorrido, con misiones por todo el mapa.", 18, Kit.TEXT, 300))
		for t in ["🏙 Ciudades amplias para recorrer", "🌲 Biomas distintos: selva, montaña, nieve, desierto", "🛣 Rutas espectaculares y libre recorrido", "🎯 Misiones en el mundo abierto"]:
			m.body.add_child(Kit.label(t, 18, Kit.GOLD))
	m.body.add_child(Kit.wrap("Llegará en una actualización gratuita del juego. ¡Gracias por jugar!", 14, Kit.MUTED, 300))
	if online and m.app.online != null and m.app.online.configured():
		_online_options()

## Modo online: hace falta una cuenta con correo (el resto del juego anda sin conexión y sin cuenta). Con cuenta, el jugador elige si participa en los rankings (se activa al crearla)
## y, en modo desarrollador, se prueba la conexión
func _online_options() -> void:
	if not m.app.online.is_account():
		m.body.add_child(Kit.wrap("Para jugar online necesitás una cuenta con tu correo. El resto del juego funciona sin conexión y sin cuenta.", 15, Kit.TEXT, 300))
		m.body.add_child(Kit.button("✉ " + tr("CREAR CUENTA CON CORREO"), func() -> void:
			m.sfx.play("click")
			m.go("account", "signup"), true, 18, Vector2(0, 54)))
		m.body.add_child(Kit.button(tr("Ya tengo cuenta · Iniciar sesión"), func() -> void:
			m.sfx.play("click")
			m.go("account", "login"), false, 16, Vector2(0, 46)))
		return
	m.body.add_child(Kit.wrap("Rankings online: se envían tu nombre de piloto y tus mejores marcas (tiempo y puntos). No se envía nada más.", 13, Kit.MUTED, 300))
	var on: bool = m.profile.setting("onlineScores") == true
	m.body.add_child(Kit.button(("☑ " if on else "☐ ") + tr("Participar en los rankings online"), func() -> void:
		m.sfx.play("click")
		m.profile.set_setting("onlineScores", not on)
		m.go("online", null, false), on, 16, Vector2(0, 46)))
	m.body.add_child(Kit.button("👤 " + m.app.online.email, func() -> void:
		m.sfx.play("click")
		m.go("account"), false, 16, Vector2(0, 46)))
	if Release.dev(m.profile):
		var res := Kit.wrap("", 13, Kit.GREEN, 300)
		m.body.add_child(Kit.button("🛠 Probar conexión con Supabase", func() -> void:
			res.text = tr("Probando…")
			var r: Dictionary = await m.app.online.ping()
			res.text = str(r["text"]), false, 15, Vector2(0, 44)))
		m.body.add_child(res)

