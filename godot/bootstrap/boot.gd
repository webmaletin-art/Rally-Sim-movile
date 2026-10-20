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
## CHANNEL: en la rama de la versión candidata (ccr-e7ae3f10-45afj2) vale "-rc" (el APK de prueba baja su propio contenido, «godot-content-4.7-rc»); en main, la versión pública, queda vacío.
const CHANNEL := ""

static func content_tag() -> String:
	var v := Engine.get_version_info()
	return "godot-content-%d.%d%s" % [int(v["major"]), int(v["minor"]), CHANNEL]

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
## Descarga (arreglo del 15/10/2026: «Falló la descarga (13/0)» con buen wifi). El 13 es RESULT_TIMEOUT: HTTPRequest.timeout es el tiempo TOTAL del pedido y
## estaba en 30 s también para bajar los paquetes (cientos de MB): sólo terminaba si bajaba a más de ~20 MB/s. Ahora: 30 s para el manifiesto, sin tope
## total para los paquetes y un vigilante que corta si no llega NADA durante stall_s. Se baja POR TRAMOS de SEG bytes (Range) y cada tramo terminado se
## pega al .tmp: si se corta, se pierde como mucho un tramo y se sigue desde ahí (Godot 4.7 borra el archivo a medio bajar al fallar: por eso tramos y no
## «seguir el archivo»). Reintenta solo AUTO_TRIES veces antes de mostrar «Reintentar».
var stall_s := 45.0 # (las pruebas lo achican con --stall=)
var seg := 32 * 1048576 # tamaño de cada tramo (las pruebas lo achican con --seg=)
const AUTO_TRIES := 4
var _tries := 0
var _stall := 0.0
var _last_got := -1
var _resume_from := 0 # bytes que ya estaban en el .tmp al pedir este tramo

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--manifest="):
			_manifest_url = a.substr(11) # para pruebas locales
		elif a.begins_with("--stall="):
			stall_s = float(a.substr(8))
		elif a.begins_with("--seg="):
			seg = int(a.substr(6))
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
	# sin hilo: con use_threads el motor lee en modo BLOQUEANTE y una conexión trabada deja la descarga colgada para siempre (ni cancel_request vuelve);
	# sin hilo se lee de a un bloque por cuadro (1 MB × 60 cuadros: sobra para cualquier wifi) y el vigilante puede cortar
	_http.use_threads = false
	_http.timeout = 30.0
	_http.download_chunk_size = 1048576
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
	_http.timeout = 30.0 # (el manifiesto es chico)
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
	_bar.visible = true
	_retry.visible = false
	var tmp := _pck_path(str(p["name"])) + ".tmp"
	# lo que quedó de un intento anterior de ESTA versión sirve (si es de otra versión, se empieza de cero)
	var vtmp := tmp + ".ver"
	if not FileAccess.file_exists(vtmp) or FileAccess.get_file_as_string(vtmp).strip_edges() != str(p["version"]):
		DirAccess.remove_absolute(tmp)
		var vf := FileAccess.open(vtmp, FileAccess.WRITE)
		if vf != null:
			vf.store_string(str(p["version"]))
			vf.close()
	var total := int(p["size"])
	_resume_from = _file_size(tmp)
	if total > 0 and _resume_from >= total:
		_finish_pack() # ya está entero: se verifica
		return
	var headers := PackedStringArray()
	if total > 0:
		headers.append("Range: bytes=%d-%d" % [_resume_from, mini(_resume_from + seg, total) - 1])
	else:
		DirAccess.remove_absolute(tmp) # (sin tamaño en el manifiesto: de una sola vez)
		_resume_from = 0
	_http.download_file = tmp + ".part"
	_downloading = true
	_stall = 0.0
	_last_got = -1
	_http.timeout = 0.0 # sin tope total: lo vigila _process (stall_s sin recibir nada)
	_http.request_completed.connect(_on_download_done)
	var err := _http.request(str(p["url"]), headers)
	if err != OK:
		_downloading = false
		_http.request_completed.disconnect(_on_download_done)
		_offline("No se pudo empezar la descarga (error %d)" % err)

static func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var n := int(f.get_length())
	f.close()
	return n

func _process(dt: float) -> void:
	if _downloading:
		var p: Dictionary = _packs[_pi]
		var total := float(p["size"])
		var now := _http.get_downloaded_bytes()
		if now != _last_got:
			_last_got = now
			_stall = 0.0
		else:
			_stall += dt
			if _stall > stall_s: # no llega nada: se corta y se reintenta desde donde quedó
				_http.cancel_request()
				_on_download_done(HTTPRequest.RESULT_TIMEOUT, 0, PackedStringArray(), PackedByteArray())
				return
		var got := float(_resume_from + now)
		if total > 0.0:
			_bar.value = clampf(got / total, 0.0, 1.0)
			_status.text = "Descargando %s (%d/%d)… %d%%  (%.0f / %.0f MB)" % ["los autos" if str(p["name"]) == "cars" else "el juego", _pi + 1, _packs.size(), int(100.0 * got / total), got / 1048576.0, total / 1048576.0]

func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _downloading:
		return
	_downloading = false
	if _http.request_completed.is_connected(_on_download_done):
		_http.request_completed.disconnect(_on_download_done)
	var p: Dictionary = _packs[_pi]
	var tmp := _pck_path(str(p["name"])) + ".tmp"
	var part := tmp + ".part"
	var total := int(p["size"])
	var ok := result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 206)
	var whole := false
	if ok and code == 206: # un tramo: se pega al final
		ok = _append(tmp, part)
	elif ok: # el servidor mandó el archivo entero (no entiende Range): reemplaza lo anterior
		DirAccess.remove_absolute(tmp)
		ok = DirAccess.rename_absolute(part, tmp) == OK
		whole = true
	DirAccess.remove_absolute(part)
	if result == HTTPRequest.RESULT_SUCCESS and code == 416: # «ese tramo no existe»: lo que hay se verifica
		_finish_pack()
		return
	if result == HTTPRequest.RESULT_SUCCESS and code >= 400:
		DirAccess.remove_absolute(tmp) # (por las dudas: lo que hay puede no servir)
	if not ok:
		_fail_or_retry("Falló la descarga (%d/%d)" % [result, code])
		return
	_tries = 0 # llegó un tramo: los reintentos vuelven a contar desde cero
	if not whole and total > 0 and _file_size(tmp) < total:
		_download() # el tramo que sigue
		return
	_finish_pack()

## El paquete está entero en el .tmp: se verifica (sha256), se guarda con su versión y se pasa al siguiente
func _finish_pack() -> void:
	var p: Dictionary = _packs[_pi]
	var path := _pck_path(str(p["name"]))
	var tmp := path + ".tmp"
	var want := str(p["sha256"])
	if want != "" and FileAccess.get_sha256(tmp) != want:
		DirAccess.remove_absolute(tmp)
		_fail_or_retry("El archivo descargado está dañado")
		return
	_tries = 0
	DirAccess.remove_absolute(tmp + ".ver")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(tmp, path)
	var f := FileAccess.open(_ver_path(str(p["name"])), FileAccess.WRITE)
	f.store_string(str(p["version"]))
	f.close()
	_pi += 1
	_next_pack()

## Pega `part` al final de `dst` (de a 4 MB)
func _append(dst: String, part: String) -> bool:
	if not FileAccess.file_exists(part):
		return false
	var src := FileAccess.open(part, FileAccess.READ)
	var out := FileAccess.open(dst, FileAccess.READ_WRITE) if FileAccess.file_exists(dst) else FileAccess.open(dst, FileAccess.WRITE)
	if src == null or out == null:
		return false
	out.seek_end()
	var left := src.get_length()
	while left > 0:
		var n := mini(left, 4194304)
		out.store_buffer(src.get_buffer(n))
		left -= n
	src.close()
	out.close()
	return true

## Un intento falló: reintenta solo (sigue desde lo que ya bajó) hasta AUTO_TRIES veces; después muestra el botón
func _fail_or_retry(msg: String) -> void:
	_tries += 1
	if _tries < AUTO_TRIES:
		_status.text = "%s\nReintentando (%d de %d)…" % [msg, _tries + 1, AUTO_TRIES]
		await get_tree().create_timer(3.0).timeout
		_download()
		return
	_tries = 0
	_offline(msg)

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
