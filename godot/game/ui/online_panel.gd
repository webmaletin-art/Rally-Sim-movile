extends RefCounted
## Las páginas online de la pausa del mundo abierto: chat mundial, mensajes privados, jugadores conectados, amigos, reportar y mercado de autos.
## Se dibujan en el mismo panel de la izquierda que las opciones (race_hud._opts_go) sin salir del mundo.

const Kit := preload("res://game/ui/ui_kit.gd")
const Tr := preload("res://game/i18n/tr.gd")
const CarBuild := preload("res://game/data/car_build.gd")

var social: Node # online_social.gd
var profile: RefCounted
var hud: Control # race_hud.gd
var body: VBoxContainer
var _live: VBoxContainer # lista de mensajes que se refresca sola
var _status: Label
var _players: Array = [] # último listado de conectados (posiciones para «ir»)
var _friend_ids: Dictionary = {}

func setup(p_social: Node, p_profile: RefCounted, p_hud: Control) -> void:
	social = p_social
	profile = p_profile
	hud = p_hud
	social.chat_changed.connect(_on_chat)

func _t(s: String) -> String:
	return Tr.t(s)

func _go(page: String, arg = null) -> void:
	hud._opts_go(page, arg)

func _alive(n: Object) -> bool:
	return n != null and is_instance_valid(n)

## Cada página se arma acá; el título y el botón ATRÁS los pone race_hud
func build(page: String, arg, p_body: VBoxContainer) -> void:
	body = p_body
	_live = null
	social.panel_open = true
	match page:
		"on_home": _home()
		"on_chat": _chat(arg if arg is Dictionary else {"channel": "world", "name": ""})
		"on_dms": _dms()
		"on_players": _players_page()
		"on_friends": _friends_page()
		"on_player": _player_page(arg if arg is Dictionary else {})
		"on_report": _report_page(arg if arg is Dictionary else {})
		"on_market": _market_page()
		"on_sell": _sell_page()
		"on_sell_car": _sell_car_page(str(arg))
		"on_buy": _buy_page(arg if arg is Dictionary else {})

func closed() -> void:
	if social != null:
		social.panel_open = false
		social.watch = "world"

func _title(s: String) -> void:
	hud.opts_title.text = _t(s)

func _status_label() -> Label:
	_status = Kit.label("", 15, Kit.GOLD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 200
	return _status

func _say(s: String, translate := true) -> void:
	if _alive(_status):
		_status.text = _t(s) if translate else s

func _btn(text: String, cb: Callable, accent := false) -> Button:
	var b := Kit.button(text, cb, accent, 19, Vector2(0, 58))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

# ───────────────────────── inicio ─────────────────────────
func _home() -> void:
	_title("MODO ONLINE")
	social.unread = 0
	body.add_child(Kit.label("👤 " + social.player_name(), 20, Kit.GOLD))
	body.add_child(_btn("💬  " + _t("CHAT MUNDIAL"), func() -> void: _go("on_chat", {"channel": "world", "name": ""}), true))
	body.add_child(_btn("✉  " + _t("MENSAJES PRIVADOS"), func() -> void: _go("on_dms")))
	body.add_child(_btn("🌐  " + _t("JUGADORES CONECTADOS"), func() -> void: _go("on_players")))
	body.add_child(_btn("⭐  " + _t("AMIGOS"), func() -> void: _go("on_friends")))
	body.add_child(_btn("🚗  " + _t("MERCADO DE AUTOS"), func() -> void: _go("on_market")))
	body.add_child(Kit.wrap(_t("Para reportar a alguien, abrí su perfil desde Jugadores, Amigos o tocando su nombre en el chat."), 13, Kit.MUTED, 200))

# ───────────────────────── chat ─────────────────────────
func _chat(arg: Dictionary) -> void:
	var ch := str(arg.get("channel", "world"))
	var who := str(arg.get("name", ""))
	_title("CHAT MUNDIAL" if ch == "world" else "PRIVADO")
	social.watch = ch
	if who != "":
		body.add_child(Kit.label("✉ " + who, 18, Kit.GOLD))
	body.add_child(Kit.wrap(_t("Los insultos se tapan con asteriscos. Si se repiten, el chat se bloquea un rato."), 12, Kit.MUTED, 200))
	_live = VBoxContainer.new()
	_live.add_theme_constant_override("separation", 4)
	_live.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_live)
	var row := Kit.hbox(6)
	body.add_child(row)
	var le := LineEdit.new()
	le.placeholder_text = _t("Escribí un mensaje…")
	le.max_length = 200
	le.custom_minimum_size = Vector2(0, 52)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_font_size_override("font_size", 18)
	row.add_child(le)
	var sendf := func() -> void:
		var txt := le.text
		if txt.strip_edges() == "":
			return
		le.text = ""
		var r: Dictionary = await social.send(ch, txt)
		if str(r["text"]) != "":
			_say(str(r["text"]))
		await social.poll(ch)
	row.add_child(Kit.button("➤", sendf, true, 22, Vector2(64, 52)))
	le.text_submitted.connect(func(_s: String) -> void: sendf.call())
	body.add_child(_status_label())
	if social.blocked_left() > 0:
		_say(_t("Tenés el chat bloqueado: faltan %d min.") % ceili(float(social.blocked_left()) / 60.0), false)
	_render_chat(ch)
	social.poll(ch)

func _on_chat(ch: String) -> void:
	if _alive(_live) and ch == social.watch:
		_render_chat(ch)

func _render_chat(ch: String) -> void:
	if not _alive(_live):
		return
	for c in _live.get_children():
		c.queue_free()
	var list: Array = social.msgs.get(ch, [])
	if list.is_empty():
		_live.add_child(Kit.wrap(_t("Todavía no hay mensajes. ¡Escribí el primero!"), 15, Kit.MUTED, 200))
	for m in list.slice(-40):
		var mine := bool(m.get("mine", false))
		var nm := str(m.get("sender_name", "?"))
		var h := Kit.hbox(6)
		var nb := Kit.button(nm, func() -> void:
			if not mine:
				_go("on_player", {"id": str(m.get("sender", "")), "name": nm}), false, 14, Vector2(0, 34))
		nb.add_theme_color_override("font_color", Kit.GOLD if mine else Kit.ACCENT)
		nb.disabled = mine
		nb.custom_minimum_size.x = 96
		nb.clip_text = true
		h.add_child(nb)
		var tl := Kit.wrap(str(m.get("body", "")), 15, Kit.TEXT, 120)
		h.add_child(tl)
		_live.add_child(h)
	if hud.opts_scroll != null:
		hud.opts_scroll.call_deferred("set", "scroll_vertical", 100000)

# ───────────────────────── privados ─────────────────────────
func _dms() -> void:
	_title("MENSAJES PRIVADOS")
	var info := Kit.wrap(_t("Cargando…"), 15, Kit.MUTED, 200)
	body.add_child(info)
	var list: Array = await social.threads()
	if not _alive(info):
		return
	info.text = _t("Todavía no tenés conversaciones. Tocá un jugador y elegí MENSAJE PRIVADO.") if list.is_empty() else ""
	for t in list:
		var pid := str(t.get("partner", ""))
		var pn := str(t.get("partner_name", "?"))
		body.add_child(Kit.card_button("✉ " + pn, str(t.get("last_body", "")), "", func() -> void:
			_go("on_chat", {"channel": social.channel_with(pid), "name": pn}), false, true, 62, 19))

# ───────────────────────── jugadores y amigos ─────────────────────────
func _players_page() -> void:
	_title("JUGADORES")
	var info := Kit.wrap(_t("Cargando…"), 15, Kit.MUTED, 200)
	body.add_child(info)
	var list: Array = await social.players()
	if not _alive(info):
		return
	_players = list
	var n := 0
	for p in list:
		if bool(p.get("is_me", false)):
			continue
		n += 1
		var pid := str(p.get("player_id", ""))
		var pn := str(p.get("name", "?"))
		var fr := bool(p.get("is_friend", false))
		body.add_child(Kit.card_button(("⭐ " if fr else "") + pn, str(p.get("car", "")), "%d km/h" % roundi(float(p.get("speed", 0.0))), func() -> void:
			_go("on_player", {"id": pid, "name": pn}), false, true, 62, 19))
	info.text = _t("No hay otros jugadores conectados ahora.") if n == 0 else _t("%d conectados") % n

func _friends_page() -> void:
	_title("AMIGOS")
	var info := Kit.wrap(_t("Cargando…"), 15, Kit.MUTED, 200)
	body.add_child(info)
	var list: Array = await social.friends()
	_players = await social.players()
	if not _alive(info):
		return
	info.text = _t("Todavía no seguís a nadie. Abrí el perfil de un jugador y tocá SEGUIR.") if list.is_empty() else ""
	for f in list:
		var pid := str(f.get("player_id", ""))
		var pn := str(f.get("name", "?"))
		var on := bool(f.get("online", false))
		body.add_child(Kit.card_button(("🟢 " if on else "⚪ ") + pn, _t("conectado") if on else _t("desconectado"), "↔" if bool(f.get("follows_me", false)) else "", func() -> void:
			_go("on_player", {"id": pid, "name": pn}), false, true, 62, 19))

func _player_page(arg: Dictionary) -> void:
	var pid := str(arg.get("id", ""))
	var pn := str(arg.get("name", "?"))
	_title("JUGADOR")
	body.add_child(Kit.label(pn, 24, Kit.GOLD))
	body.add_child(_btn("✉  " + _t("MENSAJE PRIVADO"), func() -> void: _go("on_chat", {"channel": social.channel_with(pid), "name": pn}), true))
	var fb := _btn("⭐  " + _t("SEGUIR"), Callable())
	body.add_child(fb)
	var fl: Array = await social.friends()
	_friend_ids.clear()
	for f in fl:
		_friend_ids[str(f.get("player_id", ""))] = true
	if not _alive(fb):
		return
	var set_txt := func() -> void:
		fb.text = "⭐  " + (_t("DEJAR DE SEGUIR") if _friend_ids.has(pid) else _t("SEGUIR"))
	set_txt.call()
	fb.pressed.connect(func() -> void:
		var on: bool = not _friend_ids.has(pid)
		fb.disabled = true
		var ok: bool = await social.follow(pid, on)
		if not _alive(fb):
			return
		fb.disabled = false
		if ok:
			if on:
				_friend_ids[pid] = true
			else:
				_friend_ids.erase(pid)
			set_txt.call()
		else:
			_say("No se pudo cambiar. Probá de nuevo."))
	var pos: Variant = null
	for p in _players:
		if str(p.get("player_id", "")) == pid:
			pos = Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0)))
	if pos == null:
		var pl: Array = await social.players()
		if not _alive(fb):
			return
		_players = pl
		for p in pl:
			if str(p.get("player_id", "")) == pid:
				pos = Vector2(float(p.get("x", 0.0)), float(p.get("z", 0.0)))
	if pos != null and hud.city_hud != null:
		var target: Vector2 = pos
		body.add_child(_btn("📍  " + _t("IR HASTA ÉL (GPS)"), func() -> void:
			hud.city_hud.set_dest(target, pn)
			hud._opts_close()
			hud.resume_pressed.emit()))
	else:
		body.add_child(Kit.wrap(_t("No está conectado en este momento: no se puede ir hasta él."), 13, Kit.MUTED, 200))
	body.add_child(_btn("🚩  " + _t("REPORTAR"), func() -> void: _go("on_report", {"id": pid, "name": pn})))
	body.add_child(_status_label())

func _report_page(arg: Dictionary) -> void:
	var pid := str(arg.get("id", ""))
	var pn := str(arg.get("name", "?"))
	_title("REPORTAR")
	body.add_child(Kit.label("🚩 " + pn, 22, Kit.GOLD))
	body.add_child(Kit.wrap(_t("Se guarda lo que pasó (sus mensajes, dónde estaba, a qué velocidad iba y lo que pasó cerca tuyo) para revisarlo a mano. Nadie recibe un castigo automático por un reporte."), 14, Kit.MUTED, 200))
	var le := LineEdit.new()
	le.placeholder_text = _t("Contanos qué pasó (opcional)")
	le.max_length = 300
	le.custom_minimum_size = Vector2(0, 52)
	le.add_theme_font_size_override("font_size", 17)
	body.add_child(le)
	var sendb := _btn("🚩  " + _t("ENVIAR REPORTE"), Callable(), true)
	body.add_child(sendb)
	body.add_child(_status_label())
	sendb.pressed.connect(func() -> void:
		sendb.disabled = true
		var r: Dictionary = await social.report(pid, le.text)
		if not _alive(sendb):
			return
		_say(str(r["text"]))
		sendb.disabled = bool(r["ok"]))

# ───────────────────────── mercado ─────────────────────────
static func car_title(id: String) -> String:
	var m: Dictionary = CarBuild.catalog()["cars"].get(id, {})
	return "%s %s" % [str(m.get("brand", id)), str(m.get("model", ""))]

static func upgrades_of(state: Dictionary) -> int:
	var n := 0
	for k in (state.get("upg", {}) as Dictionary):
		n += int(state["upg"][k])
	return n

func _market_page() -> void:
	_title("MERCADO DE AUTOS")
	body.add_child(_btn("💰  " + _t("VENDER UN AUTO MÍO"), func() -> void: _go("on_sell"), true))
	body.add_child(_status_label())
	var info := Kit.wrap(_t("Cargando…"), 15, Kit.MUTED, 200)
	body.add_child(info)
	var got: int = await social.market_collect()
	if got > 0:
		_say(_t("¡Vendiste autos! Cobraste %s créditos.") % Kit.fmt_cr(got), false)
	var list: Array = await social.market_browse()
	if not _alive(info):
		return
	info.text = _t("No hay autos en venta ahora.") if list.is_empty() else _t("En venta:")
	for row in list:
		var mine := bool(row.get("mine", false))
		var st: Dictionary = row["state"] if row.get("state") is Dictionary else {}
		var sub := "%s · %d %s" % [str(row.get("seller_name", "?")), upgrades_of(st), _t("mejoras")]
		body.add_child(Kit.card_button(("★ " if mine else "") + car_title(str(row.get("car", ""))), sub, Kit.fmt_cr(float(row.get("price", 0))), func() -> void:
			_go("on_buy", row), false, true, 66, 18))

func _buy_page(row: Dictionary) -> void:
	_title("COMPRAR")
	var cid := str(row.get("car", ""))
	var st: Dictionary = row["state"] if row.get("state") is Dictionary else {}
	var mine := bool(row.get("mine", false))
	body.add_child(Kit.label(car_title(cid), 22, Kit.GOLD))
	body.add_child(Kit.wrap("%s: %s\n%s: %d\n%s: %s" % [_t("Vendedor"), str(row.get("seller_name", "?")), _t("Mejoras"), upgrades_of(st), _t("Precio"), Kit.fmt_cr(float(row.get("price", 0)))], 16, Kit.TEXT, 200))
	body.add_child(Kit.wrap(_t("Tenés %s créditos.") % Kit.fmt_cr(float(profile.credits)), 14, Kit.MUTED, 200))
	var st_l := _status_label()
	var b: Button
	if mine:
		b = _btn("↩  " + _t("RETIRAR DE LA VENTA"), Callable())
		b.pressed.connect(func() -> void:
			b.disabled = true
			var r: Dictionary = await social.market_cancel(row)
			if _alive(st_l):
				st_l.text = _t(str(r["text"])))
	else:
		b = _btn("🛒  " + _t("COMPRAR"), Callable(), true)
		b.pressed.connect(func() -> void:
			b.disabled = true
			var r: Dictionary = await social.market_buy(row)
			if _alive(st_l):
				st_l.text = _t(str(r["text"]))
			if _alive(b):
				b.disabled = bool(r["ok"]))
	body.add_child(b)
	body.add_child(st_l)

func _sell_page() -> void:
	_title("VENDER")
	body.add_child(Kit.wrap(_t("Elegí el auto que querés vender. Se vende con sus mejoras y su pintura y vos ponés el precio. No podés vender tu único auto."), 14, Kit.MUTED, 200))
	var owned: Dictionary = profile.d["owned"]
	for id in owned:
		var cid: String = str(id)
		var st: Dictionary = owned[cid]
		body.add_child(Kit.card_button(car_title(cid), "%d %s" % [upgrades_of(st), _t("mejoras")], "", func() -> void: _go("on_sell_car", cid), false, owned.size() > 1, 62, 18))

func _sell_car_page(cid: String) -> void:
	_title("VENDER")
	body.add_child(Kit.label(car_title(cid), 22, Kit.GOLD))
	var base: int = int(CarBuild.catalog()["cars"].get(cid, {}).get("price", 10000))
	body.add_child(Kit.wrap(_t("Precio en créditos (el valor del auto nuevo es %s):") % Kit.fmt_cr(float(base)), 15, Kit.TEXT, 200))
	var le := LineEdit.new()
	le.text = str(base)
	le.max_length = 8
	le.custom_minimum_size = Vector2(0, 56)
	le.add_theme_font_size_override("font_size", 22)
	body.add_child(le)
	var sb := _btn("💰  " + _t("PUBLICAR EN EL MERCADO"), Callable(), true)
	body.add_child(sb)
	body.add_child(_status_label())
	sb.pressed.connect(func() -> void:
		var price := int(le.text) if le.text.is_valid_int() else 0
		if price < 1:
			_say("Poné un precio válido.")
			return
		sb.disabled = true
		var r: Dictionary = await social.market_sell(cid, price)
		if not _alive(sb):
			return
		_say(str(r["text"]))
		sb.disabled = bool(r["ok"]))
