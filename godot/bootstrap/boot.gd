extends Control
## Cliente liviano de GSkorp Rally.
## El APK solo trae el motor y esta pantalla. El juego (res://game) viaja aparte en dos paquetes:
##  · "content.pck": todo menos las carrocerías de los autos;
##  · "cars.pck": las carrocerías con su textura, sin reducir (pesa varios cientos de MB, cambia poco: se baja una sola vez).
##  1. pregunta la versión en GitHub (manifest.json de la release "godot-content-<versión del motor>", por ejemplo "godot-content-4.5"; lista los paquetes),
##  2. por cada paquete con versión nueva lo descarga (con barra de progreso) y lo guarda en el teléfono,
##  3. sin internet usa los últimos guardados,
##  4. monta los paquetes y arranca el juego.
## Si el juego ya está dentro del programa (build completo o el editor) arranca directo.

const REPO := "webmaletin-art/Rally-Sim-movile"
const GAME_SCENE := "res://game/main.tscn"

## Los paquetes (.pck) los arma la misma versión del motor que corre el APK (cambian de formato entre versiones): cada versión (menor) del motor baja de su propia release.
## Los APK de Godot 4.4 leían «godot-content» (que ya no se actualiza y sigue sirviendo para ellos).
static func content_tag() -> String:
	var v := Engine.get_version_info()
	return "godot-content-%d.%d" % [int(v["major"]), int(v["minor"])]

static func manifest_url() -> String:
	return "https://github.com/" + REPO + "/releases/download/" + content_tag() + "/manifest.json"

var _manifest_url := manifest_url()
var _title: Label
var _status: Label
var _bar: ProgressBar
var _retry: Button
var _http: HTTPRequest
var _manifest: Dictionary = {}
var _packs: Array = [] # [{name, version, url, size, sha256}] en el orden en que se montan
var _pi := 0 # paquete que se está bajando
var _downloading := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--manifest="):
			_manifest_url = a.substr(11) # para pruebas locales
	_build_ui()
	if ResourceLoader.exists(GAME_SCENE):
		_start_game()
		return
	_check_updates()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -90)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_title = Label.new()
	_title.text = "DREAM RACING"
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(1.0, 0.48, 0.1))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_status = Label.new()
	_status.text = "Iniciando…"
	_status.add_theme_font_size_override("font_size", 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.visible = false
	box.add_child(_bar)
	_retry = Button.new()
	_retry.text = "Reintentar"
	_retry.custom_minimum_size = Vector2(0, 56)
	_retry.visible = false
	_retry.pressed.connect(_check_updates)
	box.add_child(_retry)
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.timeout = 30.0
	add_child(_http)

func _pck_path(name: String) -> String:
	return "user://%s.pck" % name

func _ver_path(name: String) -> String:
	return "user://%s_version.txt" % name

func _local_version(name: String) -> String:
	if FileAccess.file_exists(_ver_path(name)) and FileAccess.file_exists(_pck_path(name)):
		return FileAccess.get_file_as_string(_ver_path(name)).strip_edges()
	return ""

## ¿están todos los paquetes guardados (para jugar sin internet)?
func _have_all_local() -> bool:
	for n in ["content", "cars"]:
		if _local_version(n) == "":
			return false
	return true

func _check_updates() -> void:
	_retry.visible = false
	_bar.visible = false
	_status.text = "Buscando actualizaciones…"
	_http.download_file = ""
	if _http.request_completed.is_connected(_on_download_done):
		_http.request_completed.disconnect(_on_download_done)
	if not _http.request_completed.is_connected(_on_manifest):
		_http.request_completed.connect(_on_manifest)
	var err := _http.request(_manifest_url)
	if err != OK:
		_offline("No se pudo conectar (error %d)" % err)

func _on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.request_completed.disconnect(_on_manifest)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_offline("Sin conexión con el servidor (%d/%d)" % [result, code])
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("url") or not parsed.has("version"):
		_offline("Respuesta inválida del servidor")
		return
	_manifest = parsed
	_packs = [{"name": "content", "version": str(_manifest["version"]), "url": str(_manifest["url"]), "size": float(_manifest.get("size", 0)), "sha256": str(_manifest.get("sha256", ""))}]
	for p in _manifest.get("packs", []):
		_packs.append({"name": str(p["name"]), "version": str(p["version"]), "url": str(p["url"]), "size": float(p.get("size", 0)), "sha256": str(p.get("sha256", ""))})
	_pi = 0
	_next_pack()

## baja el primer paquete que esté desactualizado; si ya están todos, monta y arranca
func _next_pack() -> void:
	while _pi < _packs.size() and str(_packs[_pi]["version"]) == _local_version(str(_packs[_pi]["name"])):
		_pi += 1
	if _pi >= _packs.size():
		_status.text = "Juego al día"
		_mount_and_start()
		return
	_download()

func _download() -> void:
	var p: Dictionary = _packs[_pi]
	var mb := float(p["size"]) / 1048576.0
	_status.text = "Descargando %s (%.0f MB)…" % ["los autos" if str(p["name"]) == "cars" else "el juego", mb]
	_bar.value = 0.0
	_bar.visible = true
	_downloading = true
	_http.download_file = _pck_path(str(p["name"])) + ".tmp"
	_http.request_completed.connect(_on_download_done)
	var err := _http.request(str(p["url"]))
	if err != OK:
		_downloading = false
		_http.request_completed.disconnect(_on_download_done)
		_offline("No se pudo empezar la descarga (error %d)" % err)

func _process(_dt: float) -> void:
	if _downloading:
		var p: Dictionary = _packs[_pi]
		var total := float(p["size"])
		var got := float(_http.get_downloaded_bytes())
		if total > 0.0:
			_bar.value = clampf(got / total, 0.0, 1.0)
			_status.text = "Descargando %s (%d/%d)… %d%%  (%.0f / %.0f MB)" % ["los autos" if str(p["name"]) == "cars" else "el juego", _pi + 1, _packs.size(), int(100.0 * got / total), got / 1048576.0, total / 1048576.0]

func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	_http.request_completed.disconnect(_on_download_done)
	var p: Dictionary = _packs[_pi]
	var path := _pck_path(str(p["name"]))
	var tmp := path + ".tmp"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(tmp)
		_offline("Falló la descarga (%d/%d)" % [result, code])
		return
	var want := str(p["sha256"])
	if want != "" and FileAccess.get_sha256(tmp) != want:
		DirAccess.remove_absolute(tmp)
		_offline("El archivo descargado está dañado")
		return
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
	var f := FileAccess.open(_ver_path(str(p["name"])), FileAccess.WRITE)
	f.store_string(str(p["version"]))
	f.close()
	_pi += 1
	_next_pack()

## Sin internet: si ya hay una versión guardada se juega con esa; si no, se puede reintentar
func _offline(msg: String) -> void:
	_bar.visible = false
	if _have_all_local():
		_status.text = msg + "\nUsando la versión guardada."
		await get_tree().create_timer(1.2).timeout
		_mount_and_start()
	else:
		_status.text = msg + "\nLa primera vez hace falta internet para bajar el juego."
		_retry.visible = true

func _mount_and_start() -> void:
	for n in ["content", "cars"]:
		if not ProjectSettings.load_resource_pack(_pck_path(n)):
			for q in ["content", "cars"]:
				DirAccess.remove_absolute(_pck_path(q))
				DirAccess.remove_absolute(_ver_path(q))
			_status.text = "El juego guardado está dañado. Hay que volver a bajarlo."
			_retry.visible = true
			return
	_start_game()

func _start_game() -> void:
	_status.text = "Cargando…"
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)
