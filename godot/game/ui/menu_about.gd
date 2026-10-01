extends RefCounted
## Acerca de: versión (siete toques = modo desarrollador), créditos, política de privacidad y términos de uso, y la pantalla de
## aceptación del primer inicio (Google Play pide que el jugador conozca y acepte las condiciones).

const Kit := preload("res://game/ui/ui_kit.gd")
const Release := preload("res://game/data/release.gd")

const POLICY_URL := "https://github.com/webmaletin-art/Rally-Sim-movile/blob/main/docs/PRIVACIDAD.md"
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
	["Niños", "El juego no tiene publicidad, compras con dinero real ni chat, y no recopila datos de nadie, incluidos los menores."],
]

const TERMS := [
	["Uso personal", "Dream Racing es un juego de simulación para entretenimiento, ofrecido «tal cual», sin garantías."],
	["Todo es virtual", "El dinero, los autos, las estrellas y los logros son virtuales: no tienen valor real, no se canjean ni se venden. No hay compras con dinero real."],
	["Seguridad", "Es un juego: no imites lo que ves en la vida real y no uses el teléfono mientras manejás un vehículo."],
	["Contenido descargable", "El juego descarga contenido adicional de internet; la primera vez hace falta conexión. El contenido puede cambiar con las actualizaciones."],
	["Propiedad intelectual", "El juego, sus autos, pistas y diseños pertenecen a sus autores. Los modelos de Mixamo y de Sweet Home 3D se usan según sus licencias (ver Créditos)."],
	["Capturas y videos", "Podés compartir capturas y videos del juego libremente, citando «Dream Racing»."],
	["Cambios", "Podemos actualizar estos términos y el juego. Seguir usando la app después de un cambio implica aceptarlo."],
]

func build(name: String, arg) -> void:
	match name:
		"about": _hub()
		"credits": _paged("CRÉDITOS", CREDITS, 3, "credits")
		"privacy": _paged("PRIVACIDAD", PRIVACY, 3, "privacy")
		"terms": _paged("TÉRMINOS DE USO", TERMS, 4, "terms")

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
	if taps >= 7 and not Release.dev(m.profile):
		Release.activate_dev(m.profile)
		m.refresh_car()
		m.update_credits()
		m.sfx.play("buy")
		m.toast(tr("🛠 Modo desarrollador: todo desbloqueado"))
		m.go("about", null, false)
	elif taps >= 3 and not Release.dev(m.profile):
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
	m.body.add_child(Kit.wrap("Dream Racing guarda tu progreso solo en tu teléfono, no tiene publicidad ni cuentas y no recopila datos personales. Descarga contenido del juego desde internet.", 15, Kit.TEXT, 300))
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
		m.go("home", null, false), true, 22, Vector2(0, 56))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
