extends Node
## Detecta si el juego se cerró de golpe la vez anterior (cierre inesperado). Al abrir deja una marca en el almacenamiento de la app y la borra cuando la app pasa a segundo plano o se cierra bien:
## si al abrir la marca sigue ahí, la sesión anterior terminó mal. Con eso el juego se pone solo en «audio simple» (car_audio.gd) y guarda el aviso para Acerca de.
## Vive en el APK liviano (bootstrap), así que anda antes de montar el contenido descargado.

const FLAG := "user://session_open.flag"
const STATE := "user://crash_guard.json"

var crashed_last_time := false # la sesión anterior terminó mal
var crashes := 0 # cierres inesperados seguidos
var started := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started = Time.get_unix_time_from_system()
	var st := _load()
	crashes = int(st.get("n", 0))
	crashed_last_time = FileAccess.file_exists(FLAG)
	if crashed_last_time:
		crashes += 1
		st["n"] = crashes
		st["last"] = int(started)
		_save(st)
		print("CrashGuard: la sesión anterior terminó de golpe (%d seguidas)" % crashes)
	_mark_open()

## ¿conviene el audio simple? (se cerró de golpe la última vez, o el jugador lo pidió)
func simple_audio(profile_on: bool) -> bool:
	return profile_on or crashes > 0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			_clean_exit()
		NOTIFICATION_APPLICATION_RESUMED:
			started = Time.get_unix_time_from_system()
			_mark_open()

func _exit_tree() -> void:
	_clean_exit() # (get_tree().quit() no manda aviso de cierre: acá sí pasa; un cierre de golpe del sistema no llega hasta acá)

func _mark_open() -> void:
	var f := FileAccess.open(FLAG, FileAccess.WRITE)
	if f != null:
		f.store_string(str(int(Time.get_unix_time_from_system())))
		f.close()

func _clean_exit() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))
	# una sesión que duró un rato sin caerse borra la cuenta de cierres seguidos
	if crashes > 0 and Time.get_unix_time_from_system() - started > 180.0:
		crashes = 0
		var st := _load()
		st["n"] = 0
		_save(st)

func _load() -> Dictionary:
	if FileAccess.file_exists(STATE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(STATE))
		if d is Dictionary:
			return d
	return {}

func _save(d: Dictionary) -> void:
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()

## Las últimas líneas del registro de la sesión anterior (para pegarlas y ver qué falló antes del cierre)
static func last_log(max_lines := 120) -> String:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return "(sin registro: todavía no se guardó ninguno)"
	var files: Array = []
	for fn in dir.get_files():
		if fn.begins_with("godot") and fn.ends_with(".log"):
			files.append(fn)
	files.sort() # godot.log es la sesión actual; los demás llevan la fecha: el último por orden es el anterior más reciente
	var pick := ""
	for fn in files:
		if fn != "godot.log":
			pick = fn
	if pick == "":
		pick = "godot.log"
	var lines := FileAccess.get_file_as_string("user://logs/" + pick).split("\n")
	var from := maxi(0, lines.size() - max_lines)
	return "[" + pick + "]\n" + "\n".join(lines.slice(from))
