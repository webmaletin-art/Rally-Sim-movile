extends RefCounted
## Cuenta con correo. En la versión de Play (Release.ACCOUNT_REQUIRED) hay que iniciar sesión para jugar, también sin conexión: los créditos, los autos y las compras los guarda el SERVIDOR (account_econ.gd) y esta
## pantalla es la puerta («gate») que trae lo de la cuenta antes de entrar. En las compilaciones de desarrollo, o si el servidor no está configurado, la cuenta es opcional (sólo para el modo online).
## Los textos de resultado vienen de online.gd como claves en español (con «arg» si llevan %s).

const Kit := preload("res://game/ui/ui_kit.gd")
const Tr := preload("res://game/i18n/tr.gd")
const Release := preload("res://game/data/release.gd")

var m # menu.gd
var mail := "" # lo escrito, para que no se pierda si se redibuja la pantalla
var msg: Label
var busy := false
var first_run := false # la pantalla de bienvenida del primer inicio (sin botón atrás)

func _online() -> Node:
	return m.app.online

## Con la cuenta obligatoria (Release.ACCOUNT_REQUIRED) la primera pantalla es la de iniciar sesión; con el modo desarrollador o sin Supabase configurado no se pide
static func should_offer(profile: RefCounted, online: Node) -> bool:
	return Release.login_wall(profile, online)

## Qué hay que hacer antes de entrar al juego: "" = nada · "login" = iniciar sesión · "sync" = conectarse a confirmar la cuenta con el servidor
static func gate(app: Node) -> String:
	if app == null or app.get("account") == null:
		return ""
	return str(app.account.gate_state())

func build(arg) -> void:
	var mode := str(arg) if arg != null else "menu"
	if mode == "menu" and _online().is_account():
		mode = "status"
	match mode:
		"gate": _gate()
		"welcome": _welcome()
		"signup": _form("signup")
		"login": _form("login")
		"recover": _form("recover")
		"status": _status()
		_: _intro(false)

func _skip() -> void:
	m.profile.d["accountAsked"] = true
	m.profile.save()

func _intro(first: bool) -> void:
	first_run = first
	var required := Release.ACCOUNT_REQUIRED and Release.account_mode(m.profile, m.app.online)
	m.set_title("TU CUENTA")
	m.body.add_child(Kit.label("Tu cuenta de Dream Racing" if required else "Cuenta para el modo online", 24, Kit.ACCENT))
	if required:
		m.body.add_child(Kit.wrap(Tr.t("Para jugar iniciá sesión con tu correo. Tus créditos, tus autos y tus compras quedan guardados en tu cuenta: no se pierden si cambiás de teléfono y nadie los puede modificar. Una vez adentro, el juego también anda sin conexión (hasta %d días entre una verificación y otra).") % Release.ACCOUNT_GRACE_DAYS, 15, Kit.TEXT, 300))
	else:
		m.body.add_child(Kit.wrap("El modo online (rankings y, más adelante, carreras contra otros pilotos) necesita una cuenta con tu correo. El resto del juego funciona sin conexión y sin cuenta, y tu progreso (autos y créditos) se guarda en este teléfono.", 15, Kit.TEXT, 300))
	m.body.add_child(Kit.button("✉ CREAR CUENTA CON CORREO", func() -> void: m.go("account", "signup"), true, 19, Vector2(0, 58)))
	m.body.add_child(Kit.button("Ya tengo cuenta · Iniciar sesión", func() -> void: m.go("account", "login"), false, 17, Vector2(0, 50)))
	if first and not required:
		m.body.add_child(Kit.button("Jugar sin cuenta", func() -> void:
			_skip()
			m.go("home", null, false), false, 17, Vector2(0, 50)))
		m.body.add_child(Kit.wrap("Podés crearla cuando quieras desde Modo online.", 13, Kit.MUTED, 300))

func _welcome() -> void:
	_intro(true)

func _status() -> void:
	var on := _online()
	m.set_title("TU CUENTA")
	m.body.add_child(Kit.label("✔ Cuenta activa", 24, Kit.GREEN))
	m.body.add_child(Kit.label(on.email, 18, Kit.TEXT))
	m.body.add_child(Kit.wrap("Tus marcas del ranking van con tu nombre de piloto. Para entrar desde otro teléfono usá «Iniciar sesión» con este correo.", 14, Kit.MUTED, 300))
	if Release.dev(m.profile): # (sólo en la versión candidata) con el modo desarrollador los créditos y los autos son del teléfono: en otro teléfono se ve lo que tiene la cuenta en el servidor
		m.body.add_child(Kit.wrap("🛠 Modo desarrollador activo: los créditos y los autos de este teléfono son sólo de este teléfono, NO de tu cuenta. En otro teléfono vas a ver lo que tiene tu cuenta en el servidor. Apagá el modo desarrollador en Acerca de para usar los de tu cuenta.", 13, Kit.GOLD, 300))
	var acc: Node = m.app.account
	if acc != null and acc.is_active():
		var st := Kit.wrap(str(acc.status_text()), 14, Kit.MUTED, 300)
		m.body.add_child(st)
		m.body.add_child(Kit.button("☁ SINCRONIZAR AHORA", func() -> void: _sync_now(st), false, 16, Vector2(0, 46)))
	m.body.add_child(Kit.button("Cambiar la contraseña (te mandamos un correo)", func() -> void:
		busy = true
		var r: Dictionary = await on.recover(on.email)
		busy = false
		_say(r), false, 16, Vector2(0, 50)))
	m.body.add_child(Kit.button("Cerrar sesión", func() -> void:
		if m.app.account != null:
			await m.app.account.sync() # (se manda lo que haya esperando antes de cerrar: lo local de la economía se borra)
			m.app.account.on_logout()
		on.logout()
		m.toast("Sesión cerrada")
		m.stack.clear()
		m.go("account", "welcome", false), false, 16, Vector2(0, 50)))
	var del := Kit.button("Borrar mi cuenta y mis marcas", Callable(), false, 15, Vector2(0, 46))
	var sure := false
	del.pressed.connect(func() -> void:
		if not sure:
			sure = true
			del.text = Tr.t("¿Seguro? Se borran tu cuenta y tus marcas del ranking, para siempre. Tocá de nuevo para confirmar.")
			del.add_theme_color_override("font_color", Kit.RED)
			return
		del.disabled = true
		var r: Dictionary = await on.delete_account()
		if r["ok"]:
			if m.app.account != null:
				m.app.account.on_logout()
			m.toast(Tr.t(str(r["text"])))
			m.stack.clear()
			m.go("account", "welcome", false)
		else:
			del.disabled = false
			_say(r))
	m.body.add_child(del)
	msg = Kit.wrap("", 14, Kit.GREEN, 300)
	m.body.add_child(msg)

func _sync_now(st: Label) -> void:
	var acc: Node = m.app.account
	st.text = Tr.t("☁ Sincronizando…")
	var sr: Dictionary = await acc.sync()
	if not is_instance_valid(st):
		return
	if bool(sr.get("ok", false)):
		st.text = str(acc.status_text())
	else:
		st.text = Tr.t(str(sr.get("text", "")))

## Entrada al juego con la cuenta del servidor: se trae lo que dice el servidor (créditos, autos, compras) y recién entonces se juega. Pasa después de iniciar sesión, en un teléfono nuevo,
## si se tocó el archivo del perfil o si pasaron más de Release.ACCOUNT_GRACE_DAYS días sin conexión.
func _gate() -> void:
	var acc: Node = m.app.account
	m.set_title("TU CUENTA")
	m.body.add_child(Kit.label("Verificando tu cuenta…", 24, Kit.ACCENT))
	msg = Kit.wrap("Un momento: le preguntamos al servidor qué créditos y qué autos tiene tu cuenta.", 15, Kit.TEXT, 300)
	m.body.add_child(msg)
	var retry := Kit.button("REINTENTAR", func() -> void: m.go("account", "gate", false), true, 20, Vector2(0, 56))
	retry.visible = false
	m.body.add_child(retry)
	var out := Kit.button("Cerrar sesión", func() -> void: _logout_from_gate(), false, 16, Vector2(0, 48))
	out.visible = false
	m.body.add_child(out)
	var my_msg := msg
	var r: Dictionary = await acc.on_login()
	if not is_instance_valid(my_msg) or m.screen != "account" or m.screen_arg != "gate":
		return # (el jugador se fue de esta pantalla)
	if bool(r.get("ok", false)):
		m.stack.clear()
		m.go("home", null, false)
		return
	if acc.status == "login":
		m.stack.clear()
		m.go("account", "welcome", false)
		return
	if not acc.is_active():
		m.stack.clear() # (compilación de prueba y el servidor todavía sin la migración de la cuenta: se juega con el progreso de este teléfono)
		m.go("home", null, false)
		return
	_say({"ok": false, "text": str(r.get("text", "")), "detail": str(r.get("detail", ""))})
	retry.visible = true
	out.visible = true

func _logout_from_gate() -> void:
	var on := _online()
	if m.app.account != null:
		m.app.account.on_logout()
	on.logout()
	m.stack.clear()
	m.go("account", "welcome", false)

func _field(hint: String, secret: bool, text := "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = Tr.t(hint)
	le.text = text
	le.secret = secret
	le.custom_minimum_size = Vector2(0, 52)
	le.max_length = 80
	le.add_theme_font_size_override("font_size", 18)
	le.add_theme_color_override("font_color", Kit.TEXT)
	le.add_theme_color_override("font_placeholder_color", Kit.MUTED)
	le.add_theme_color_override("caret_color", Kit.ACCENT)
	le.add_theme_stylebox_override("normal", Kit.box(Kit.PANEL2, 10, Kit.LINE, 1, 12))
	le.add_theme_stylebox_override("focus", Kit.box(Kit.PANEL2, 10, Kit.ACCENT, 2, 12))
	le.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT if secret else LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	return le

func _form(kind: String) -> void:
	var on := _online()
	m.set_title({"signup": "CREAR CUENTA", "login": "INICIAR SESIÓN", "recover": "OLVIDÉ MI CONTRASEÑA"}[kind])
	var email := _field("Correo electrónico", false, mail)
	email.text_changed.connect(func(t: String) -> void: mail = t)
	m.body.add_child(email)
	var pw: LineEdit = null
	if kind != "recover":
		pw = _field("Contraseña (mínimo 8 caracteres)" if kind == "signup" else "Contraseña", true)
		m.body.add_child(pw)
		var show := Kit.button("👁 Mostrar contraseña", Callable(), false, 14, Vector2(0, 38))
		show.pressed.connect(func() -> void: pw.secret = not pw.secret)
		m.body.add_child(show)
	msg = Kit.wrap("", 14, Kit.RED, 300)
	var go_btn := Kit.button("", Callable(), true, 20, Vector2(0, 58))
	go_btn.text = Tr.t({"signup": "CREAR MI CUENTA", "login": "ENTRAR", "recover": "ENVIAR CORREO"}[kind])
	var run := func() -> void:
		if busy:
			return
		busy = true
		go_btn.disabled = true
		msg.add_theme_color_override("font_color", Kit.MUTED)
		msg.text = Tr.t("Un momento…")
		var r: Dictionary
		match kind:
			"signup": r = await on.create_account(email.text, pw.text)
			"login": r = await on.login(email.text, pw.text)
			_: r = await on.recover(email.text)
		busy = false
		go_btn.disabled = false
		_say(r)
		if r["ok"] and kind != "recover" and not r.get("confirm", false):
			_skip()
			m.profile.set_setting("onlineScores", true) # tener cuenta es querer estar en el ranking (se apaga en Modo online)
			m.sfx.play("buy")
			m.stack.clear()
			if m.app.account != null and m.app.account.is_active():
				m.go("account", "gate", false) # trae del servidor los créditos y los autos de esta cuenta (y entra al juego)
			else:
				m.go("home" if first_run else "account", null, false)
	go_btn.pressed.connect(run)
	email.text_submitted.connect(func(_t: String) -> void: if pw == null: run.call() else: pw.grab_focus())
	if pw != null:
		pw.text_submitted.connect(func(_t: String) -> void: run.call())
	m.body.add_child(go_btn)
	m.body.add_child(msg)
	if kind == "login":
		m.body.add_child(Kit.button("Olvidé mi contraseña", func() -> void: m.go("account", "recover", false), false, 15, Vector2(0, 44)))
	if kind == "signup":
		m.body.add_child(Kit.wrap("Es posible que te pidamos confirmar el correo con un enlace. Usamos tu correo solo para la cuenta del modo online, y al crearla se activan los rankings online (los podés apagar en Modo online).", 13, Kit.MUTED, 300))

func _say(r: Dictionary) -> void:
	if msg == null or not is_instance_valid(msg):
		return
	var t: String = Tr.t(str(r.get("text", "")))
	if r.has("arg"):
		t = t % str(r["arg"])
	if r.has("detail") and str(r["detail"]) != "":
		t += "\n(%s)" % str(r["detail"]) # el mensaje del servidor, para saber qué falló
	msg.text = t
	msg.add_theme_color_override("font_color", Kit.GREEN if r.get("ok", false) else Kit.RED)
