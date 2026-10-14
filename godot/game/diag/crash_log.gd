extends Node
## Registro de diagnóstico para los cierres inesperados (docs/REGISTRO_TECNICO.md → «Cierre al acelerar»).
## Vive en el CONTENIDO descargado (no en el APK): anda con cualquier APK liviano, viejo o nuevo. (El bootstrap/crash_guard.gd del APK
## nuevo sigue existiendo, pero el contenido no puede depender de él: un APK viejo no lo trae y la pantalla que lo cargaba se rompía.)
##  · Detecta si la sesión anterior terminó de golpe (marca en user:// que se borra al salir bien o al ir a segundo plano).
##  · Escribe su propio archivo por sesión (user://diag/s_<hora>.log) con escritura inmediata (flush): un cierre de golpe no pierde las últimas líneas.
##  · Captura los mensajes y errores del motor (Logger de Godot 4.5) y las «migas» que deja el juego: carga, audio, carrera y cada 2 s la
##    velocidad, FPS y memoria mientras se maneja. Con tope de líneas por segundo, para no escribir miles.
##  · report(): lo que copia el botón «COPIAR REGISTRO» (Acerca de y Opciones → Sonido): teléfono + sesión anterior + sesión actual.
## Se crea una sola vez en app.gd; los demás lo buscan con CrashLog.get_instance().

const DIR := "user://diag"
const FLAG := "user://diag/open.flag"
const STATE := "user://diag/state.json"
const KEEP := 6 # sesiones guardadas
const MAX_PER_SEC := 40 # tope de líneas por segundo (lo que pase se cuenta y se anota)

static var _inst: Node = null

var crashed_last_time := false
var crashes := 0 # cierres de golpe seguidos (se reinicia tras 3 minutos sin caerse)
var started := 0.0
var _file: FileAccess
var _path := ""
var _mutex := Mutex.new()
var _sec := 0
var _sec_n := 0
var _dropped := 0
var _logger: Logger

static func get_instance() -> Node:
	return _inst if _inst != null and is_instance_valid(_inst) else null

## Anota una línea (desde cualquier lado; si no hay registro no hace nada)
static func mark(tag: String, text: String = "") -> void:
	var c := get_instance()
	if c != null:
		c.write("[%s] %s" % [tag, text])

class _EngineLog extends Logger:
	var _o: WeakRef
	func _log_message(message: String, error: bool) -> void:
		var o: Variant = _o.get_ref()
		if o != null:
			o.write(("E " if error else "") + message.strip_edges())
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		var o: Variant = _o.get_ref()
		if o != null:
			var kind: String = ["ERROR", "WARNING", "SCRIPT", "SHADER"][clampi(error_type, 0, 3)]
			o.write("%s %s %s (%s:%d %s)" % [kind, code, rationale, file.get_file(), line, function])

func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	started = Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(DIR)
	var st := _load()
	crashes = int(st.get("n", 0))
	crashed_last_time = FileAccess.file_exists(FLAG)
	if crashed_last_time:
		crashes += 1
		st["n"] = crashes
		_save(st)
	_rotate()
	_path = "%s/s_%d.log" % [DIR, int(started * 1000.0)] # (en milisegundos: dos aperturas en el mismo segundo no se pisan)
	_file = FileAccess.open(_path, FileAccess.WRITE)
	_mark_open()
	write("== sesión %s · %s" % [Time.get_datetime_string_from_system(), _device()])
	if crashed_last_time:
		write("[guard] la sesión anterior terminó de golpe (%d seguidas)" % crashes)
	_logger = _EngineLog.new()
	_logger._o = weakref(self)
	OS.add_logger(_logger)

func write(line: String) -> void:
	_mutex.lock()
	if _file != null:
		var s := int(Time.get_ticks_msec() / 1000)
		if s != _sec:
			if _dropped > 0:
				_file.store_line("… (%d líneas salteadas)" % _dropped)
			_sec = s
			_sec_n = 0
			_dropped = 0
		_sec_n += 1
		if _sec_n <= MAX_PER_SEC:
			_file.store_line("%7.1f %s" % [Time.get_ticks_msec() / 1000.0, line])
			_file.flush() # que llegue al disco ya: si el sistema mata la app, lo escrito queda
		else:
			_dropped += 1
	_mutex.unlock()

## ¿conviene el audio simple? (se cerró de golpe la vez anterior, o el jugador lo pidió)
func simple_audio(profile_on: bool) -> bool:
	return profile_on or crashes > 0

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			write("[app] segundo plano / cierre pedido")
			_clean_exit()
		NOTIFICATION_APPLICATION_RESUMED:
			write("[app] vuelve")
			started = Time.get_unix_time_from_system()
			_mark_open()
		NOTIFICATION_OS_MEMORY_WARNING:
			write("[mem] AVISO DE MEMORIA DEL SISTEMA · " + mem_line())

func _exit_tree() -> void:
	write("[app] salida normal")
	_clean_exit()
	if _logger != null:
		OS.remove_logger(_logger)
	_mutex.lock()
	_file = null
	_mutex.unlock()

func _mark_open() -> void:
	var f := FileAccess.open(FLAG, FileAccess.WRITE)
	if f != null:
		f.store_string(str(int(Time.get_unix_time_from_system())))
		f.close()

func _clean_exit() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(FLAG)
	if crashes > 0 and Time.get_unix_time_from_system() - started > 180.0:
		crashes = 0
		var st := _load()
		st["n"] = 0
		_save(st)

func _rotate() -> void:
	var files := _sessions()
	while files.size() >= KEEP:
		DirAccess.remove_absolute(DIR + "/" + str(files.pop_front()))

func _sessions() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d != null:
		for fn in d.get_files():
			if fn.begins_with("s_") and fn.ends_with(".log"):
				out.append(fn)
	out.sort_custom(func(a, b) -> bool: return int(str(a).substr(2).to_int()) < int(str(b).substr(2).to_int()))
	return out

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

static func mem_line() -> String:
	return "mem %.0f MB · video %.0f MB · tex %.0f MB · nodos %d · objetos %d · fps %d" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.TIME_FPS))]

func _device() -> String:
	var v := Engine.get_version_info()
	var bid := "res://game/build_id.txt"
	var build := FileAccess.get_file_as_string(bid).strip_edges() if FileAccess.file_exists(bid) else "desarrollo"
	var apk := "APK con CrashGuard" if get_tree() != null and get_tree().root.get_node_or_null("CrashGuard") != null else "APK sin CrashGuard (viejo)"
	return "contenido %s · Godot %s.%s.%s · %s %s · %s · %s · %d núcleos · pantalla %s · %s" % [build, v["major"], v["minor"], v["patch"],
		OS.get_name(), OS.get_version(), OS.get_model_name(), RenderingServer.get_video_adapter_name(), OS.get_processor_count(),
		str(DisplayServer.screen_get_size()), apk]

func _tail(path: String, n: int) -> String:
	if not FileAccess.file_exists(path):
		return "(no hay)"
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var from := maxi(0, lines.size() - n)
	return "\n".join(lines.slice(from))

## Lo que copia «COPIAR REGISTRO»: la sesión anterior (la que se cerró) y el final de la actual
func report() -> String:
	var files := _sessions()
	var prev := ""
	for fn in files:
		if DIR + "/" + str(fn) != _path:
			prev = DIR + "/" + str(fn)
	var out := "DREAM RACING · registro\n" + _device() + "\n" + mem_line() + "\n"
	out += "cierres de golpe seguidos: %d (la anterior %s)\n" % [crashes, "TERMINÓ DE GOLPE" if crashed_last_time else "terminó bien"]
	out += "\n--- SESIÓN ANTERIOR [%s] ---\n%s\n" % [prev.get_file(), _tail(prev, 160) if prev != "" else "(no hay)"]
	out += "\n--- SESIÓN ACTUAL ---\n%s\n" % _tail(_path, 50)
	var gl := "user://logs/godot.log" # el registro del motor (sólo con el APK nuevo, que lo activa)
	if FileAccess.file_exists(gl):
		out += "\n--- MOTOR (godot.log, final) ---\n%s\n" % _tail(gl, 30)
	return out

## Para el botón: copia y devuelve cuántas líneas se copiaron
static func copy_to_clipboard() -> int:
	var c := get_instance()
	var txt: String = c.report() if c != null else "(el registro no está activo)"
	DisplayServer.clipboard_set(txt)
	return txt.count("\n")
