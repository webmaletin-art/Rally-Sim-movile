extends RefCounted
## Acerca de: versión (siete toques = modo desarrollador), créditos, política de privacidad y términos de uso, y la pantalla de
## aceptación del primer inicio (Google Play pide que el jugador conozca y acepte las condiciones).

const Kit := preload("res://game/ui/ui_kit.gd")
const Release := preload("res://game/data/release.gd")
const MenuAccount := preload("res://game/ui/menu_account.gd")

const POLICY_URL := "https://webmaletin-art.github.io/Rally-Sim-movile/docs/privacidad.html"
const TERMS_URL := "https://github.com/webmaletin-art/Rally-Sim-movile/blob/main/docs/TERMINOS.md"
const CONSENT_VERSION := 1

var m # menu.gd
var page := 0
var taps := 0
var tap_t := 0.0

const CREDITS := [
	["Dream Racing", "Un juego de rally y carreras de simulación hecho para jugar desde el celular, con pilotos y copilotos que viven cada curva."],
	["Autos", "Los autos del juego fueron diseñados y modelados por el equipo de Dream Racing."],
	["Personajes y animaciones", "Los pilotos y sus animaciones usan modelos y movimientos de Mixamo (Adobe), utilizados según su licencia."],
	["Escenarios y objetos", "Algunos modelos de casas y objetos provienen de Sweet Home 3D (bibliotecas de uso libre)."],
	["Motor", "Hecho con Godot Engine, software libre bajo licencia MIT (godotengine.org)."],
	["Gracias", "A quienes probaron el juego, mandaron ideas y ayudaron a que cada versión salga mejor."],
]

const PRIVACY := [
	["Resumen", "Dream Racing no tiene cuentas, ni publicidad, ni análisis. No recopilamos, vendemos ni compartimos datos personales. Tu progreso se guarda solo en tu teléfono."],
	["Qué se guarda", "Tu perfil de juego (nombre de piloto, autos, mejoras, pintura, dinero del juego, estrellas, tiempos y opciones) queda en el almacenamiento privado de la app. No se envía a ningún servidor. Si desinstalás la app, se pierde."],
	["Capturas", "Las capturas de pantalla que sacás con el botón de captura se guardan en tu teléfono, en la carpeta de imágenes del juego. Las podés borrar desde la galería del juego."],
	["Internet", "La app se conecta solo para descargar contenido del juego (modelos, pistas, música y actualizaciones) desde el repositorio público del proyecto en GitHub. Como en cualquier descarga, GitHub puede registrar tu dirección IP según su propia política."],
	["Permisos", "Internet (descargar contenido) y vibración (opcional). No pedimos ubicación, cámara, micrófono, contactos ni archivos personales. Los sensores de movimiento se usan solo para manejar inclinando el teléfono."],
	["Niños", "El juego no tiene publicidad ni chat, y no recopila datos de nadie, incluidos los menores. Las compras dentro del juego se hacen con la cuenta de Google Play de un adulto."],
	["Contacto", "Dudas o pedidos sobre tus datos o tu cuenta: roldanhr98@gmail.com (SRGamestudios)."],
]

## Versión de Google Play: funciona sin internet; solo las compras pasan por Google Play
const PRIVACY_STORE := [
	["Internet", "El juego funciona sin conexión: todo viene dentro de la app. Solo se usa internet, a través de Google Play, cuando hacés una compra dentro del juego. Los datos de pago los maneja Google y nunca llegan a nosotros."],
	["Permisos", "Vibración (opcional) y los permisos de red que necesita el servicio de compras de Google Play (el juego no los usa para nada más). No pedimos ubicación, cámara, micrófono, contactos ni archivos personales. Los sensores de movimiento se usan solo para manejar inclinando el teléfono."],
]

const TERMS := [
	["Uso personal", "Dream Racing es un juego de simulación para entretenimiento, ofrecido «tal cual», sin garantías."],
	["Todo es virtual", "El dinero, los autos, las estrellas y los logros son virtuales: no tienen valor real, no se canjean por dinero ni se venden."],
	["Seguridad", "Es un juego: no imites lo que ves en la vida real y no uses el teléfono mientras manejás un vehículo."],
	["Contenido descargable", "El juego descarga contenido adicional de internet; la primera vez hace falta conexión. El contenido puede cambiar con las actualizaciones."],
	["Propiedad intelectual", "El juego, sus autos, pistas y diseños pertenecen a sus autores. Los modelos de Mixamo y de Sweet Home 3D se usan según sus licencias (ver Créditos)."],
	["Capturas y videos", "Podés compartir capturas y videos del juego libremente, citando «Dream Racing»."],
	["Cambios", "Podemos actualizar estos términos y el juego. Seguir usando la app después de un cambio implica aceptarlo."],
	["Contacto", "Dudas o pedidos sobre tus datos o tu cuenta: roldanhr98@gmail.com (SRGamestudios)."],
]

## Versión de Google Play: con compras dentro del juego
const TERMS_STORE := [
	["Compras", "Podés comprar con dinero real el juego completo y bolsas de créditos a través de Google Play. Las cobra y las administra Google: los reembolsos y reclamos se piden en Google Play, según sus políticas. Los créditos y el juego completo son para usar en el juego y no se pueden transferir ni canjear por dinero."],
	["Contenido descargable", "El juego completo viene dentro de la app y funciona sin conexión. Las actualizaciones se instalan desde Google Play."],
]

## Solo si esta versión trae el modo online configurado (los rankings son opcionales y están apagados de fábrica)
const PRIVACY_ONLINE := [
	["Resumen", "Dream Racing no tiene publicidad ni análisis. No vendemos ni compartimos datos personales. Tu progreso se guarda en tu teléfono. Solo si lo elegís, el modo online guarda en nuestro servidor tu nombre de piloto, tus marcas y, si creás una cuenta, tu correo."],
	["Niños", "El juego no tiene publicidad ni chat. El modo online es opcional y la cuenta con correo es solo para mayores de 13 años (o con permiso de un adulto); sin cuenta no se pide ningún dato personal. Las compras dentro del juego se hacen con la cuenta de Google Play de un adulto."],
	["Qué se guarda", "Tu perfil de juego (autos, mejoras, pintura, dinero del juego, estrellas, tiempos y opciones) queda en el almacenamiento privado de la app, en tu teléfono. Solo si participás en el modo online se envían tu nombre de piloto y tus mejores marcas, y tu correo si creás una cuenta. Si desinstalás la app, se pierde lo que está en el teléfono."],
	["Internet", "El juego funciona sin conexión. Se usa internet para las compras (a través de Google Play), para descargar contenido en la versión de prueba y, solo si participás, para el modo online (rankings y cuenta)."],
	["Dónde se guardan los datos online", "Los datos del modo online (nombre de piloto, marcas y, si creás una cuenta, tu correo) se guardan en servidores de Supabase, que los procesa por nuestra cuenta. Los conservamos hasta que borres tu cuenta o nos pidas borrarlos. Los registros técnicos de envíos solo sirven para frenar abusos."],
	["Rankings online (opcional)", "Si activás «Participar en los rankings online» (viene apagado), el juego crea un usuario anónimo y envía a nuestro servidor (Supabase) tu nombre de piloto y tus mejores marcas (tiempo o puntos, pista y auto) para armar el ranking, que ven todos los jugadores. No se envía ningún otro dato, y lo podés apagar cuando quieras. Para borrar tus marcas escribí al contacto del juego."],
	["Cuenta con correo (opcional)", "Si creás una cuenta, guardamos tu correo electrónico y una contraseña (que nunca vemos: se guarda cifrada) en Supabase, solo para que puedas recuperar tus marcas del ranking en otro teléfono. Tu correo no se muestra a otros jugadores ni se usa para publicidad. Es solo para mayores de 13 años. Podés cerrar sesión cuando quieras y borrar tu cuenta y tus marcas desde el juego (Modo online → Cuenta) o escribiendo al contacto del juego."],
]

func _privacy() -> Array:
	var base: Array = _merged(PRIVACY, PRIVACY_STORE) if Release.store() else PRIVACY
	if m.app != null and m.app.online != null and m.app.online.configured():
		return _merged(base, PRIVACY_ONLINE)
	return base

## Solo si esta versión trae el modo online configurado
const TERMS_ONLINE := [
	["Cuenta y rankings online", "Si usás el modo online, tu nombre de piloto y tus mejores marcas se muestran a otros jugadores. Elegí un nombre que no sea ofensivo ni se haga pasar por otra persona: podemos cambiarlo, o quitar marcas conseguidas con trampas o programas externos. La cuenta con correo es personal y solo para mayores de 13 años: cuidá tu contraseña. Podés borrar tu cuenta cuando quieras desde el juego. El servicio online puede cambiar o detenerse, y no afecta lo que jugás sin conexión."],
]

func _terms() -> Array:
	var base: Array = _merged(TERMS, TERMS_STORE) if Release.store() else TERMS
	if m.app != null and m.app.online != null and m.app.online.configured():
		return _merged(base, TERMS_ONLINE)
	return base

## Reemplaza las secciones de igual título y agrega las nuevas al final
func _merged(base: Array, extra: Array) -> Array:
	var out: Array = []
	for it in base:
		var rep: Variant = null
		for e in extra:
			if str(e[0]) == str(it[0]):
				rep = e
		out.append(rep if rep != null else it)
	for e in extra:
		var found := false
		for it in base:
			if str(it[0]) == str(e[0]):
				found = true
		if not found:
			out.append(e)
	return out

func build(name: String, arg) -> void:
	match name:
		"about": _hub()
		"credits": _paged("CRÉDITOS", CREDITS, 3, "credits")
		"privacy": _paged("PRIVACIDAD", _privacy(), 3, "privacy")
		"terms": _paged("TÉRMINOS DE USO", _terms(), 4, "terms")

func version_text() -> String:
	var f := "res://game/build_id.txt"
	return FileAccess.get_file_as_string(f).strip_edges() if FileAccess.file_exists(f) else "desarrollo"

func _hub() -> void:
	m.set_title("ACERCA DE")
	var big := Kit.label("DREAM RACING", 34, Kit.ACCENT)
	m.body.add_child(big)
	var ver := Kit.button("Versión %s" % version_text(), func() -> void: _tap_version(), false, 16, Vector2(0, 40))
	m.body.add_child(ver)
	if Release.dev(m.profile):
		m.body.add_child(Kit.label("🛠 Modo desarrollador activo", 15, Kit.GREEN))
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	for it in [["🎬", "CRÉDITOS", "credits"], ["🔒", "PRIVACIDAD", "privacy"], ["📜", "TÉRMINOS DE USO", "terms"]]:
		var dest: String = it[2]
		g.add_child(m.tile(str(it[0]), str(it[1]), "", func() -> void:
			page = 0
			m.go(dest), false, 78.0))
	if Release.dev(m.profile):
		g.add_child(m.tile("🔓", "APAGAR MODO DEV", "", func() -> void:
			Release.deactivate_dev(m.profile)
			m.toast(tr("Modo desarrollador apagado"))
			m.go("about", null, false), false, 78.0))
	m.body.add_child(Kit.wrap("Los textos legales completos están en el repositorio del juego (docs/PRIVACIDAD.md y docs/TERMINOS.md).", 12, Kit.MUTED, 300))

func _tap_version() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - tap_t > 1.6:
		taps = 0
	tap_t = now
	taps += 1
	if taps >= 7 and not Release.dev(m.profile) and not Release.store():
		Release.activate_dev(m.profile)
		m.refresh_car()
		m.update_credits()
		m.sfx.play("buy")
		m.toast(tr("🛠 Modo desarrollador: todo desbloqueado"))
		m.go("about", null, false)
	elif taps >= 3 and not Release.dev(m.profile) and not Release.store():
		m.toast(tr("Faltan %d toques…") % (7 - taps))

## Texto en secciones con paginador (n secciones por página)
func _paged(title: String, items: Array, per: int, screen: String) -> void:
	m.set_title(title)
	var pages := maxi(1, int(ceil(float(items.size()) / float(per))))
	page = clampi(page, 0, pages - 1)
	for i in range(page * per, mini(items.size(), (page + 1) * per)):
		var it: Array = items[i]
		var p := Kit.panel(10, Kit.PANEL2)
		m.body.add_child(p)
		var v := Kit.vbox(2)
		p.add_child(v)
		v.add_child(Kit.label(str(it[0]), 18, Kit.GOLD))
		v.add_child(Kit.wrap(str(it[1]), 14, Kit.TEXT, 300))
	if pages > 1:
		m.body.add_child(Kit.pager(page, pages, func(pg: int) -> void:
			page = pg
			m.go(screen, null, false)))

# ───────────────────────── primer inicio ─────────────────────────
static func needs_consent(profile: RefCounted) -> bool:
	var c: Variant = profile.d.get("consent")
	return not (c is Dictionary and int((c as Dictionary).get("v", 0)) >= CONSENT_VERSION)

func consent_screen() -> void:
	m.set_title("BIENVENIDO")
	m.body.add_child(Kit.label("Antes de empezar", 26, Kit.ACCENT))
	var intro := "Dream Racing guarda tu progreso solo en tu teléfono, no tiene publicidad ni cuentas y no recopila datos personales. Funciona sin internet; las compras dentro del juego pasan por Google Play." if Release.store() else "Dream Racing guarda tu progreso solo en tu teléfono, no tiene publicidad ni cuentas y no recopila datos personales. Descarga contenido del juego desde internet."
	if m.app != null and m.app.online != null and m.app.online.configured():
		intro = "Dream Racing guarda tu progreso solo en tu teléfono y no tiene publicidad. Los rankings online y la cuenta con correo son opcionales: si los usás, se envían tu nombre de piloto, tus marcas y, si creás una cuenta, tu correo. Funciona sin internet; las compras dentro del juego pasan por Google Play." if Release.store() else "Dream Racing guarda tu progreso solo en tu teléfono y no tiene publicidad. Los rankings online y la cuenta con correo son opcionales: si los usás, se envían tu nombre de piloto, tus marcas y, si creás una cuenta, tu correo. Descarga contenido del juego desde internet."
	m.body.add_child(Kit.wrap(intro, 15, Kit.TEXT, 300))
	var g := Kit.grid(2, 8, 8)
	m.body.add_child(g)
	g.add_child(m.tile("🔒", "POLÍTICA DE PRIVACIDAD", "", func() -> void:
		page = 0
		m.stack.append(["consent", null])
		m.go("privacy", null, false), false, 74.0))
	g.add_child(m.tile("📜", "TÉRMINOS DE USO", "", func() -> void:
		page = 0
		m.stack.append(["consent", null])
		m.go("terms", null, false), false, 74.0))
	m.body.add_child(Kit.wrap("Al tocar «Acepto» confirmás que leíste y aceptás la política de privacidad y los términos de uso.", 13, Kit.MUTED, 300))
	var row := Kit.hbox(8)
	m.body.add_child(row)
	var no := Kit.button("No acepto", func() -> void: m.get_tree().quit(), false, 18, Vector2(0, 56))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	var yes := Kit.button("ACEPTO", func() -> void:
		m.profile.d["consent"] = {"v": CONSENT_VERSION, "t": Time.get_unix_time_from_system()}
		m.profile.save()
		m.sfx.play("buy")
		m.stack.clear()
		if MenuAccount.should_offer(m.profile, m.app.online):
			m.go("account", "welcome", false)
		else:
			m.go("home", null, false), true, 22, Vector2(0, 56))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
