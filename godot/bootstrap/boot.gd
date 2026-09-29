extends Control
## Cliente liviano de GSkorp Rally.
## El APK solo trae el motor y esta pantalla. El juego (res://game) viaja aparte en "content.pck":
##  1. pregunta la versión en GitHub (manifest.json de la release "godot-content"),
##  2. si hay una nueva la descarga (con barra de progreso) y la guarda en el teléfono,
##  3. sin internet usa la última guardada,
##  4. monta el paquete y arranca el juego.
## Si el juego ya está dentro del programa (build completo o el editor) arranca directo.

const REPO := "webmaletin-art/Rally-Sim-movile"
const MANIFEST_URL := "https://github.com/" + REPO + "/releases/download/godot-content/manifest.json"
const PCK_PATH := "user://content.pck"
const VER_PATH := "user://content_version.txt"
const GAME_SCENE := "res://game/main.tscn"

var _manifest_url := MANIFEST_URL
var _title: Label
var _status: Label
var _bar: ProgressBar
var _retry: Button
var _http: HTTPRequest
var _manifest: Dictionary = {}
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
	_title.text = "GSKORP RALLY"
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

func _local_version() -> String:
	if FileAccess.file_exists(VER_PATH) and FileAccess.file_exists(PCK_PATH):
		return FileAccess.get_file_as_string(VER_PATH).strip_edges()
	return ""

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
	if str(_manifest["version"]) == _local_version():
		_status.text = "Juego al día"
		_mount_and_start()
		return
	_download()

func _download() -> void:
	_status.text = "Descargando el juego (%.1f MB)…" % (float(_manifest.get("size", 0)) / 1048576.0)
	_bar.value = 0.0
	_bar.visible = true
	_downloading = true
	_http.download_file = PCK_PATH + ".tmp"
	_http.request_completed.connect(_on_download_done)
	var err := _http.request(str(_manifest["url"]))
	if err != OK:
		_downloading = false
		_http.request_completed.disconnect(_on_download_done)
		_offline("No se pudo empezar la descarga (error %d)" % err)

func _process(_dt: float) -> void:
	if _downloading:
		var total := float(_manifest.get("size", 0))
		var got := float(_http.get_downloaded_bytes())
		if total > 0.0:
			_bar.value = clampf(got / total, 0.0, 1.0)
			_status.text = "Descargando el juego… %d%%  (%.1f / %.1f MB)" % [int(100.0 * got / total), got / 1048576.0, total / 1048576.0]

func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_downloading = false
	_http.request_completed.disconnect(_on_download_done)
	var tmp := PCK_PATH + ".tmp"
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		DirAccess.remove_absolute(tmp)
		_offline("Falló la descarga (%d/%d)" % [result, code])
		return
	var want := str(_manifest.get("sha256", ""))
	if want != "" and FileAccess.get_sha256(tmp) != want:
		DirAccess.remove_absolute(tmp)
		_offline("El archivo descargado está dañado")
		return
	if FileAccess.file_exists(PCK_PATH):
		DirAccess.remove_absolute(PCK_PATH)
	DirAccess.rename_absolute(tmp, PCK_PATH)
	var f := FileAccess.open(VER_PATH, FileAccess.WRITE)
	f.store_string(str(_manifest["version"]))
	f.close()
	_mount_and_start()

## Sin internet: si ya hay una versión guardada se juega con esa; si no, se puede reintentar
func _offline(msg: String) -> void:
	_bar.visible = false
	if _local_version() != "":
		_status.text = msg + "\nUsando la versión guardada."
		await get_tree().create_timer(1.2).timeout
		_mount_and_start()
	else:
		_status.text = msg + "\nLa primera vez hace falta internet para bajar el juego."
		_retry.visible = true

func _mount_and_start() -> void:
	if not ProjectSettings.load_resource_pack(PCK_PATH):
		DirAccess.remove_absolute(PCK_PATH)
		if FileAccess.file_exists(VER_PATH):
			DirAccess.remove_absolute(VER_PATH)
		_status.text = "El juego guardado está dañado. Hay que volver a bajarlo."
		_retry.visible = true
		return
	_start_game()

func _start_game() -> void:
	_status.text = "Cargando…"
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)
