extends RefCounted
## Cuenta con correo del modo online (opcional). Se ofrece una sola vez al abrir el juego por primera vez («welcome») y queda siempre
## disponible en Modo online. El juego anda igual sin cuenta: la cuenta solo mantiene tus marcas del ranking si cambiás de teléfono.
## Los textos de resultado vienen de online.gd como claves en español (con «arg» si llevan %s).

const Kit := preload("res://game/ui/ui_kit.gd")
const Tr := preload("res://game/i18n/tr.gd")

var m # menu.gd
var mail := "" # lo escrito, para que no se pierda si se redibuja la pantalla
var msg: Label
var busy := false
var first_run := false # la pantalla de bienvenida del primer inicio (sin botón atrás)

func _online() -> Node:
	return m.app.online

## ¿Hay que ofrecer la cuenta? (versión con modo online, primer inicio ya aceptado y todavía no se ofreció)
static func should_offer(profile: RefCounted, online: Node) -> bool:
	return online != null and online.configured() and profile.d.get("accountAsked") != true and not online.is_account()

func build(arg) -> void:
	var mode := str(arg) if arg != null else "menu"
	if mode == "menu" and _online().is_account():
		mode = "status"
	match mode:
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
	m.set_title("TU CUENTA")
	m.body.add_child(Kit.label("Guardá tus marcas", 24, Kit.ACCENT))
	m.body.add_child(Kit.wrap("Con una cuenta tus marcas de los rankings quedan a tu nombre aunque cambies de teléfono. Es opcional: el juego anda igual sin cuenta, y tu progreso (autos y créditos) se sigue guardando en este teléfono.", 15, Kit.TEXT, 300))
	m.body.add_child(Kit.button("✉ CREAR CUENTA CON CORREO", func() -> void: m.go("account", "signup"), true, 19, Vector2(0, 58)))
	m.body.add_child(Kit.button("Ya tengo cuenta · Iniciar sesión", func() -> void: m.go("account", "login"), false, 17, Vector2(0, 50)))
	if first:
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
	m.body.add_child(Kit.button("Cambiar la contraseña (te mandamos un correo)", func() -> void:
		busy = true
		var r: Dictionary = await on.recover(on.email)
		busy = false
		_say(r), false, 16, Vector2(0, 50)))
	m.body.add_child(Kit.button("Cerrar sesión", func() -> void:
		on.logout()
		m.toast("Sesión cerrada")
		m.go("account", null, false), false, 16, Vector2(0, 50)))
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
			m.toast(Tr.t(str(r["text"])))
			m.go("account", null, false)
		else:
			del.disabled = false
			_say(r))
	m.body.add_child(del)
	msg = Kit.wrap("", 14, Kit.GREEN, 300)
	m.body.add_child(msg)

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
		m.body.add_child(Kit.wrap("Es posible que te pidamos confirmar el correo con un enlace. Usamos tu correo solo para la cuenta del ranking, y al crearla se activan los rankings online (los podés apagar en Modo online).", 13, Kit.MUTED, 300))

func _say(r: Dictionary) -> void:
	if msg == null or not is_instance_valid(msg):
		return
	var t: String = Tr.t(str(r.get("text", "")))
	if r.has("arg"):
		t = t % str(r["arg"])
	msg.text = t
	msg.add_theme_color_override("font_color", Kit.GREEN if r.get("ok", false) else Kit.RED)
