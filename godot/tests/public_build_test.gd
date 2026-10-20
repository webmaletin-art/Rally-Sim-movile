## La versión PÚBLICA (main y Google Play) no trae nada de desarrollo; sólo la versión candidata «Dream Racing RC» y el editor (pedido del dueño, 20/10/2026):
##  · Release.internal() = editor o versión candidata marcada; Google Play (store) nunca; main exportado sin el marcador, tampoco;
##  · el marcador (game/build_channel.txt) NO está en el repositorio y lo escribe el flujo build-godot.yml sólo fuera de main; el flujo del AAB de Play no lo escribe;
##  · en la versión pública: «Acerca de» sin «COPIAR REGISTRO», sin modo desarrollador (siete toques no hacen nada) y con la versión como texto; Opciones → Sonido sin «COPIAR REGISTRO»;
##    un perfil que haya quedado con dev = true (de una versión de prueba) no libera nada;
##  · en la versión candidata todo eso sigue funcionando;
##  · nadie lee el ajuste «dev» por su cuenta: todo pasa por Release.dev() (así la versión pública no se salta el cierre).
## Uso: godot --headless --path godot --script res://tests/public_build_test.gd -- --menu --noconsent
extends SceneTree

const Release := preload("res://game/data/release.gd")
const Tr := preload("res://game/i18n/tr.gd")
const Profile := preload("res://game/data/profile.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _frames(n := 6) -> void:
	for i in n:
		await process_frame

## Todos los textos de botones y etiquetas de lo que hay en pantalla
func _texts(root: Node) -> Array:
	var out: Array = []
	var st: Array = [root]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is Button:
			out.append("B:" + str((n as Button).text))
		elif n is Label:
			out.append("L:" + str((n as Label).text))
		st.append_array(n.get_children())
	return out

static func _has(texts: Array, needle: String) -> bool:
	for t in texts:
		if needle in str(t):
			return true
	return false

## Los archivos .gd de res://game (para buscar lecturas sueltas del ajuste «dev»)
func _scripts(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scripts(dir.path_join(d), out)

func _init() -> void:
	_run()

func _run() -> void:
	# ── la regla
	check(Release.internal_for(false, true, false), "el editor es una compilación interna")
	check(Release.internal_for(false, false, true), "la versión candidata (con el marcador) es interna")
	check(not Release.internal_for(false, false, false), "main exportado, sin el marcador: pública")
	check(not Release.internal_for(true, false, true) and not Release.internal_for(true, true, false), "Google Play (store) nunca es interna, aunque tenga el marcador")
	check(Release.internal(), "corriendo en el editor: interna")
	Release.test_public = true
	check(not Release.internal(), "con la simulación de la versión pública: no es interna")
	Release.test_public = false
	# ── el marcador y el flujo de compilación
	var repo := ProjectSettings.globalize_path("res://").path_join("..")
	check(not FileAccess.file_exists(Release.CHANNEL_FILE), "el marcador de la versión candidata no está en el repositorio (lo escribe el flujo)")
	var wf := FileAccess.get_file_as_string(repo.path_join(".github/workflows/build-godot.yml"))
	var i := wf.find("- name: Marcar la versión candidata")
	check(i >= 0, "el flujo de la APK tiene el paso que marca la versión candidata")
	var step := wf.substr(maxi(i, 0), 900)
	check("if: github.ref != 'refs/heads/main'" in step and "game/build_channel.txt" in step, "…y ese paso no corre en main (así la versión pública no lo trae)")
	var aab := FileAccess.get_file_as_string(repo.path_join(".github/workflows/build-aab.yml"))
	check(aab != "" and not ("build_channel" in aab), "el flujo del AAB de Google Play no escribe el marcador")
	# ── nadie lee el ajuste «dev» por su cuenta
	var files: Array = []
	_scripts("res://game", files)
	var bad: Array = []
	for f in files:
		if str(f).ends_with("/data/release.gd") or str(f).ends_with("/data/profile.gd"):
			continue
		var src := FileAccess.get_file_as_string(str(f))
		if "setting(\"dev\")" in src or "\"settings\"].get(\"dev\"" in src or "[\"settings\"][\"dev\"]" in src:
			bad.append(str(f))
	check(bad.is_empty(), "sólo Release.dev() lee el ajuste «dev» (%s)" % ", ".join(PackedStringArray(bad)))
	# ── las pantallas
	var ps: PackedScene = load("res://game/main.tscn")
	var app: Node = ps.instantiate()
	get_root().add_child(app)
	await _frames(40)
	var menu: Node = app.get("menu")
	check(menu != null, "el menú arrancó")
	Tr.set_language("es") # (los textos que se buscan están en español, sea cual sea el idioma de la computadora)
	var profile: RefCounted = menu.get("profile")
	var snapshot: Dictionary = profile.d.duplicate(true) # (el perfil de la prueba es el guardado en la computadora: se deja como estaba)
	var about: RefCounted = menu.get("about")
	# versión candidata (el editor): COPIAR REGISTRO, la versión como botón y el modo desarrollador con siete toques
	menu.call("go", "about")
	await _frames()
	var tx: Array = _texts(menu.get("body"))
	check(_has(tx, "COPIAR REGISTRO"), "versión candidata: «Acerca de» trae COPIAR REGISTRO")
	check(_has(tx, "B:Versión"), "versión candidata: la versión es un botón (siete toques = modo desarrollador)")
	menu.call("go", "options", "sonido")
	await _frames()
	check(_has(_texts(menu.get("body")), "COPIAR REGISTRO"), "versión candidata: Opciones → Sonido trae COPIAR REGISTRO")
	# versión pública
	Release.test_public = true
	var old := Profile.new() # un perfil nuevo (sin lo guardado en la computadora) que quedó con el modo desarrollador de una versión de prueba
	old.d = Profile.default_profile()
	old.d["settings"]["dev"] = true
	check(not Release.dev(old), "versión pública: un perfil con dev = true no es modo desarrollador")
	check(not Release.full(old) and Release.adventure_limit(old) == Release.ADVENTURE_STAGES, "…no libera la aventura completa (sólo las %d etapas libres)" % Release.ADVENTURE_STAGES)
	check(not Release.car_unlocked(old, "hyper") and not Release.car_unlocked(old, "truck"), "…ni los autos premium")
	check(not Release.can_buy(old, "genesis") and not Release.tier_allowed(old, "continental"), "…ni el auto de premio ni las copas de pago")
	check(not Release.pvp_open(old) and Release.special_ids(old).is_empty(), "…ni abre el tiempo real ni los autos especiales")
	Release.test_public = false
	check(Release.dev(old) and Release.full(old) and Release.car_unlocked(old, "hyper"), "versión candidata: el mismo perfil sí es modo desarrollador (todo liberado)")
	Release.test_public = true
	profile.d["settings"]["dev"] = true
	menu.call("go", "about")
	await _frames()
	tx = _texts(menu.get("body"))
	check(not _has(tx, "COPIAR REGISTRO"), "versión pública: «Acerca de» no trae COPIAR REGISTRO")
	check(not _has(tx, "APAGAR MODO DEV") and not _has(tx, "desarrollador"), "versión pública: ni rastro del modo desarrollador en «Acerca de»")
	check(_has(tx, "L:Versión") and not _has(tx, "B:Versión"), "versión pública: la versión es sólo un texto (no hay dónde tocar)")
	menu.call("go", "options", "sonido")
	await _frames()
	check(not _has(_texts(menu.get("body")), "COPIAR REGISTRO"), "versión pública: Opciones → Sonido no trae COPIAR REGISTRO")
	profile.d["settings"]["dev"] = false
	for k in 8:
		about.call("_tap_version")
	check(not Release.dev(profile) and profile.d["settings"].get("dev", false) != true, "versión pública: ocho toques seguidos no activan el modo desarrollador")
	Release.test_public = false
	# versión candidata otra vez: los siete toques sí lo activan (y se apaga para no ensuciar el perfil)
	for k in 7:
		about.call("_tap_version")
	check(Release.dev(profile), "versión candidata: siete toques activan el modo desarrollador")
	Release.deactivate_dev(profile)
	check(not Release.dev(profile), "…y se apaga")
	profile.d = snapshot
	profile.save()
	quit(1 if fail else 0)
