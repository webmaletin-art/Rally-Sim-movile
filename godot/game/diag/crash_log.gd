extends Node
## Registro de diagnóstico para los cierres inesperados (docs/REGISTRO_TECNICO.md → «Cierre al acelerar»).
## Vive en el CONTENIDO descargado (no en el APK): anda con cualquier APK liviano, viejo o nuevo. (El bootstrap/crash_guard.gd del APK
## nuevo sigue existiendo, pero el contenido no puede depender de él: un APK viejo no lo trae y la pantalla que lo cargaba se rompía.)
##  · Detecta si la sesión anterior terminó de golpe (marca en user:// que se borra al salir bien o al ir a segundo plano).
##  · Escribe su propio archivo por sesión (user://diag/s_<hora>.log) con escritura inmediata (flush): un cierre de golpe no pierde las últimas líneas.
##  · Captura los mensajes y errores del motor (Logger de Godot 4.5) y las «migas» que deja el juego: carga, audio, carrera y cada segundo la
##    velocidad, FPS y memoria (RAM real del juego y libre del teléfono) mientras se maneja.
##  · Tras un cierre de golpe le pregunta a Android el motivo (falta de memoria, error nativo, ANR…): _exit_reasons(). Con tope de líneas por segundo, para no escribir miles.
##  · report(): lo que copia el botón «COPIAR REGISTRO» (Acerca de y Opciones → Sonido): teléfono + sesión anterior + sesión actual.
## Se crea una sola vez en app.gd; los demás lo buscan con CrashLog.get_instance().

const Tombstone := preload("res://game/diag/tombstone.gd")
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
	var ms := int(started * 1000.0)
	while FileAccess.file_exists("%s/s_%d.log" % [DIR, ms]): # (dos aperturas en el mismo milisegundo no se pisan)
		ms += 1
	_path = "%s/s_%d.log" % [DIR, ms]
	_file = FileAccess.open(_path, FileAccess.WRITE)
	_mark_open()
	write("== sesión %s · %s" % [Time.get_datetime_string_from_system(), _device()])
	if crashed_last_time:
		write("[guard] la sesión anterior terminó de golpe (%d seguidas)" % crashes)
		_exit_reasons()
	elif not FileAccess.file_exists(TOMB_SEEN): # la primera vez con la lectura de lápidas: trae la del último cierre nativo aunque esta vez se haya salido bien
		_exit_reasons()
	_logger = _EngineLog.new()
	_logger._o = weakref(self)
	OS.add_logger(_logger)

func write(line: String, force := false) -> void:
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
		if _sec_n <= MAX_PER_SEC or force: # (force: la lápida de un cierre, que se escribe toda junta)
			_file.store_line("%7.1f %s" % [Time.get_ticks_msec() / 1000.0, line])
			_file.flush() # que llegue al disco ya: si el sistema mata la app, lo escrito queda
		else:
			_dropped += 1
	_mutex.unlock()

## ¿conviene el audio simple? (se cerró de golpe la vez anterior, o el jugador lo pidió). Desde el 14/10/2026 race.gd ya NO lo usa: el cierre no era del audio
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

## RAM que usa el juego de verdad (lo que mira Android para cerrarlo por falta de memoria) y la que le queda libre al teléfono.
## (MEMORY_STATIC da 0 en las compilaciones de Android: no sirve.)
static func ram_line() -> String:
	var rss := -1
	var f := FileAccess.open("/proc/self/status", FileAccess.READ) # (sólo Linux/Android; en otros sistemas no existe)
	if f != null:
		while not f.eof_reached():
			var ln := f.get_line()
			if ln.begins_with("VmRSS:"):
				rss = int(ln.substr(6).strip_edges().split(" ")[0]) / 1024
				break
		f.close()
	var mi: Dictionary = OS.get_memory_info()
	var avail := int(mi.get("available", -1))
	var phys := int(mi.get("physical", -1))
	return "RAM juego %s · libre %s de %s" % ["%d MB" % rss if rss >= 0 else "?", "%d MB" % (avail / 1048576) if avail > 0 else "?", "%d MB" % (phys / 1048576) if phys > 0 else "?"]

## Android (11 o más) guarda por qué terminó cada proceso de la app: falta de memoria, error nativo, «no responde»…
## Se le pregunta al arrancar después de un cierre de golpe. Es la prueba que falta para saber la causa (docs/REGISTRO_TECNICO.md).
## Si preguntarle llegara a cerrar el juego, la marca TRY queda y no se vuelve a intentar nunca más.
const EXIT_TRY := "user://diag/exitinfo.try"
const EXIT_REASONS := ["desconocido", "salió solo", "lo mató una señal", "FALTA DE MEMORIA (Android lo cerró)", "error de Java", "ERROR NATIVO (motor o driver)", "NO RESPONDE (ANR)",
	"falló al iniciar", "cambio de permisos", "uso excesivo de recursos", "lo cerró el usuario", "detenido por el usuario", "dependencia cerrada", "otro", "congelado", "cambio de paquete", "app actualizada"]
func _exit_reasons() -> void:
	if OS.get_name() != "Android":
		return
	if FileAccess.file_exists(EXIT_TRY):
		write("[android] (no se pregunta el motivo del cierre: la otra vez falló)")
		return
	if not Engine.has_singleton("AndroidRuntime"):
		write("[android] sin AndroidRuntime: no se puede preguntar el motivo del cierre")
		return
	var t := FileAccess.open(EXIT_TRY, FileAccess.WRITE)
	if t != null:
		t.store_string("1")
		t.close()
	var rt: Object = Engine.get_singleton("AndroidRuntime")
	var act: Variant = rt.call("getActivity")
	if act is Object and act != null:
		var am: Variant = act.call("getSystemService", "activity")
		var pkg: Variant = act.call("getPackageName")
		if am is Object and am != null and pkg is String:
			var lst: Variant = am.call("getHistoricalProcessExitReasons", pkg, 0, 3)
			if lst is Object and lst != null:
				var n := int(lst.call("size"))
				var tomb_done := false
				for i in mini(n, 3):
					var e: Variant = lst.call("get", i)
					if not (e is Object) or e == null:
						continue
					var r := int(e.call("getReason"))
					var ts := int(e.call("getTimestamp")) / 1000
					write("[android] cierre %d: %s (código %d, estado %s) · hace %d s · RAM %d MB (pss %d MB) · %s" % [i + 1,
						EXIT_REASONS[r] if r >= 0 and r < EXIT_REASONS.size() else "?", r, str(e.call("getStatus")),
						int(Time.get_unix_time_from_system()) - ts, int(e.call("getRss")) / 1024, int(e.call("getPss")) / 1024, str(e.call("getDescription"))])
					if r == 5 and not tomb_done: # error nativo: la «lápida» del más reciente (hilo, biblioteca y logcat del instante del cierre)
						tomb_done = true
						_tombstone(e)
				if not tomb_done and not FileAccess.file_exists(TOMB_SEEN): # (sin cierres nativos: no se vuelve a preguntar en cada apertura)
					var sf := FileAccess.open(TOMB_SEEN, FileAccess.WRITE)
					if sf != null:
						sf.store_string("0")
						sf.close()
			else:
				write("[android] Android no devolvió los motivos de cierre")
	DirAccess.remove_absolute(EXIT_TRY)

## La lápida del cierre nativo (Android 13+: readAllBytes). Se lee una sola vez por cierre (se recuerda la hora del último leído) y se guarda
## también el archivo crudo (user://diag/lapida_<hora>.pb) por si hace falta decodificarlo entero. Ver diag/tombstone.gd.
const TOMB_SEEN := "user://diag/lapida_vista.txt"
func _tombstone(e: Object) -> void:
	var ts := str(e.call("getTimestamp"))
	if FileAccess.file_exists(TOMB_SEEN) and FileAccess.get_file_as_string(TOMB_SEEN).strip_edges() == ts:
		var old := "%s/lapida_%s.txt" % [DIR, ts]
		if FileAccess.file_exists(old): # ya se leyó: se repiten sus líneas (así el informe siempre la trae)
			for ln in FileAccess.get_file_as_string(old).split("\n"):
				if ln.strip_edges() != "":
					write(ln, true)
		return
	var sf := FileAccess.open(TOMB_SEEN, FileAccess.WRITE)
	if sf != null:
		sf.store_string(ts)
		sf.close()
	var st: Variant = e.call("getTraceInputStream")
	if not (st is Object) or st == null:
		write("[lápida] Android no guardó la lápida de este cierre")
		return
	var sdk := int(OS.get_version().get_slice(".", 0)) # (en Android de fábrica Godot informa «nivel de API.compilación»: 33 = Android 13; las ROM modificadas dan otra cosa y se intenta igual)
	if sdk >= 21 and sdk < 33:
		write("[lápida] (API %s: hace falta Android 13 (API 33) para leerla desde el juego)" % OS.get_version().get_slice(".", 0))
		return
	var raw: Variant = st.call("readAllBytes")
	st.call("close")
	if not (raw is PackedByteArray) or (raw as PackedByteArray).is_empty():
		write("[lápida] vacía o no se pudo leer (%s)" % type_string(typeof(raw)))
		return
	var b := raw as PackedByteArray
	var f := FileAccess.open("%s/lapida_%s.pb" % [DIR, ts], FileAccess.WRITE)
	if f != null:
		f.store_buffer(b)
		f.close()
	var ls := Tombstone.lines(b)
	var tf := FileAccess.open("%s/lapida_%s.txt" % [DIR, ts], FileAccess.WRITE)
	if tf != null:
		tf.store_string("\n".join(ls))
		tf.close()
	for ln in ls:
		write(ln, true)
	_prune_tombs()

## Deja sólo las 3 lápidas más nuevas
func _prune_tombs() -> void:
	var fs: Array = []
	for fn in DirAccess.get_files_at(DIR):
		if fn.begins_with("lapida_") and fn.ends_with(".pb"):
			fs.append(fn)
	fs.sort()
	for k in maxi(0, fs.size() - 3):
		var base := str(fs[k]).get_basename()
		DirAccess.remove_absolute(DIR + "/" + base + ".pb")
		DirAccess.remove_absolute(DIR + "/" + base + ".txt")

static func mem_line() -> String:
	return ram_line() + " · video %.0f MB · tex %.0f MB · nodos %d · objetos %d · fps %d" % [
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
	if _path != "" and FileAccess.file_exists(_path): # el motivo que dio Android, siempre arriba (aunque la sesión actual sea larga)
		for ln in FileAccess.get_file_as_string(_path).split("\n"):
			if ln.contains("[android]") or ln.contains("[lápida]"):
				out += ln.strip_edges() + "\n"
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
