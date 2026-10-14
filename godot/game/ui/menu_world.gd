extends RefCounted
## Pantallas de entrada al MUNDO ABIERTO y al MODO ONLINE del menú (Etapa 23: antes estaban dentro de menu.gd): elegir dónde aparecer, hub online (apodo, conexión, créditos y regalo diario),
## apodo del jugador, cuenta/rankings y las pantallas «pronto». `m` es el menú (menu.gd): usa su cuerpo, sonidos, avisos y perfil.

const Kit := preload("res://game/ui/ui_kit.gd")
const Sectors := preload("res://game/region/sectors.gd")
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

## Lugares para aparecer, en un solo selector: la última ubicación, los 3 estacionamientos de Dream City y las estaciones de servicio de las ciudades y pueblos de la región (los más cercanos primero).
## Cada uno: {key, name, sub, pos (mapa), kind, spawn (índice en city.spawns; -1 = última ubicación)}
func _spawn_options() -> Array:
	var out: Array = []
	var lp: Variant = _last_pos_value()
	if lp != null and Sectors.is_open(Vector2(float(lp[0]), float(lp[1]))): # (en un sector en obra no se aparece)
		out.append({"key": "last", "name": "📍 " + tr("ÚLTIMA UBICACIÓN"), "sub": tr("seguís desde donde dejaste el auto"), "pos": Vector2(float(lp[0]), float(lp[1])), "kind": "last", "spawn": -1})
	for i in SPAWN_PLACES.size():
		out.append({"key": "park%d" % i, "name": "🅿 " + tr(str(SPAWN_PLACES[i][0])), "sub": tr(str(SPAWN_PLACES[i][1])), "pos": Vector2.ZERO, "kind": "dream", "spawn": i})
	if RegionServices.available():
		var towns: Array = []
		var list := RegionServices.spawn_list()
		for j in list.size():
			var sp: Dictionary = list[j]
			var pos := Vector2(float(sp["x"]), float(sp["z"]))
			if not Sectors.is_open(pos):
				continue # sector en obra: se ve en el mapa pero no se aparece ahí (game/data/sectors.json)
			var city_like := str(sp.get("kind", "")) == "ciudad"
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

## El hub del mundo online: quién sos, cómo está la conexión, cuánta gente hay y el botón de entrar
func _online_hub() -> void:
	var nick := str(m.profile.d.get("name", "Piloto"))
	var card := Kit.panel(12, Kit.PANEL2)
	m.body.add_child(card)
	var cv := Kit.vbox(4)
	card.add_child(cv)
	var head := Kit.hbox(8)
	cv.add_child(head)
	var nl := Kit.label("👤 " + nick, 26, Kit.GOLD)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nl)
	head.add_child(Kit.button(tr("CAMBIAR"), func() -> void:
		m.sfx.play("click")
		m.go("nick"), false, 14, Vector2(100, 38)))
	var cid: String = m.profile.current_id()
	var cm: Dictionary = CarBuild.catalog()["cars"].get(cid, {})
	cv.add_child(Kit.label("🚗 %s %s" % [str(cm.get("brand", "")), str(cm.get("model", ""))], 15, Kit.TEXT))
	cv.add_child(Kit.label("🏙 " + tr("MUNDO ABIERTO") + " · Dream City", 15, Kit.MUTED))
	var st_l := Kit.label("● " + tr("Conectando…"), 15, Kit.MUTED)
	cv.add_child(st_l)
	var pl_l := Kit.label("", 15, Kit.MUTED)
	cv.add_child(pl_l)
	var wal_l := Kit.label("💰 " + tr("Créditos online") + ": …", 15, Kit.GOLD)
	cv.add_child(wal_l)
	m.body.add_child(m.menu_button("🌍 " + tr("ENTRAR AL MUNDO"), tr("elegí dónde aparecer"), func() -> void:
		m.sfx.play("click")
		m.world_online = true
		m.go("spawn"), true))
	var gift_b := Kit.button("🎁 " + tr("REGALO DIARIO ONLINE"), func() -> void:
		m.sfx.play("click")
		var gr: Dictionary = await m.app.eco.daily()
		if not is_instance_valid(wal_l):
			return
		if bool(gr["ok"]):
			m.sfx.play("buy")
			m.toast(tr("¡Regalo del día! +%s créditos online") % Kit.fmt_cr(float(gr["gift"])))
			wal_l.text = "💰 %s: %s" % [tr("Créditos online"), Kit.fmt_cr(float(m.app.eco.credits))]
		else:
			m.toast(tr(str(gr["text"]))), false, 16, Vector2(0, 46))
	gift_b.visible = false
	m.body.add_child(gift_b)
	_online_options()
	# billetera online (la guarda el servidor, aparte de los créditos offline)
	if await m.app.enter_online() and is_instance_valid(wal_l):
		wal_l.text = "💰 %s: %s" % [tr("Créditos online"), Kit.fmt_cr(float(m.app.eco.credits))]
		gift_b.visible = true
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
		st_l.text = "● " + tr("Sin conexión con el servidor: se puede entrar igual, sin chat ni jugadores.")
		st_l.add_theme_color_override("font_color", Kit.RED)

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

