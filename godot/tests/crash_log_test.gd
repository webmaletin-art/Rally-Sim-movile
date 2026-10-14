## Registro de diagnóstico de cierres (game/diag/crash_log.gd): detecta el cierre de golpe anterior, escribe y conserva las sesiones,
## captura los errores del motor, y el contenido descargado no carga nada de res://bootstrap (un APK viejo no lo trae: así se rompió «COPIAR REGISTRO»).
## Uso: godot --headless --path godot --script res://tests/crash_log_test.gd
extends SceneTree

const CrashLog := preload("res://game/diag/crash_log.gd")
var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			_scan(dir.path_join(d), out)

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT) # (con --script el árbol entra recién en el primer cuadro)

func _run() -> void:
	# 1) nada del contenido apunta a res://bootstrap
	var files: Array = []
	_scan("res://game", files)
	var refs: Array = []
	for p in files:
		if FileAccess.get_file_as_string(p).contains("res://bootstrap/"):
			refs.append(p)
	_check(refs.is_empty(), "el contenido no carga nada de res://bootstrap (%s)" % str(refs))
	# 2) sesión limpia
	DirAccess.make_dir_recursive_absolute(CrashLog.DIR)
	for fn in DirAccess.get_files_at(CrashLog.DIR):
		DirAccess.remove_absolute(CrashLog.DIR + "/" + fn)
	var a: Node = CrashLog.new()
	root.add_child(a)
	_check(not a.crashed_last_time, "primera vez: la anterior no se cerró de golpe")
	CrashLog.mark("gas", "a fondo · prueba")
	push_error("error de prueba del motor")
	var txt := FileAccess.get_file_as_string(a._path)
	_check(txt.contains("[gas] a fondo · prueba"), "las migas llegan al archivo al instante (flush)")
	_check(txt.contains("error de prueba del motor"), "los errores del motor quedan anotados")
	# 3) simula un cierre de golpe: se saca el nodo sin pasar por la salida limpia (la marca queda)
	var flag_before := FileAccess.file_exists(CrashLog.FLAG)
	_check(flag_before, "con el juego abierto hay marca de sesión abierta")
	OS.remove_logger(a._logger)
	CrashLog._inst = null
	a.set_script(null) # sin script no corre _exit_tree: es como si el sistema hubiera matado la app
	a.free()
	_check(FileAccess.file_exists(CrashLog.FLAG), "la marca sigue ahí tras el «cierre de golpe»")
	var b: Node = CrashLog.new()
	root.add_child(b)
	_check(b.crashed_last_time and b.crashes == 1, "al volver a abrir se detecta el cierre de golpe (seguidas: %d)" % b.crashes)
	_check(b.simple_audio(false), "tras un cierre de golpe se pide audio simple")
	var rep: String = b.report()
	if not rep.contains("[gas] a fondo · prueba"):
		print(rep)
	_check(rep.contains("TERMINÓ DE GOLPE") and rep.contains("[gas] a fondo · prueba"), "el informe trae la sesión anterior con sus últimas líneas")
	_check(rep.contains("RAM juego") and rep.contains("video ") and rep.contains("Godot"), "el informe trae teléfono y memoria (RAM del juego y libre)")
	# 4) se conservan a lo sumo KEEP sesiones
	for i in CrashLog.KEEP + 3:
		var f := FileAccess.open("%s/s_%d.log" % [CrashLog.DIR, 1000 + i], FileAccess.WRITE)
		f.store_line("x")
		f.close()
	b._rotate()
	_check(b._sessions().size() < CrashLog.KEEP, "rotación: quedan %d sesiones" % b._sessions().size())
	# 5) salida limpia borra la marca
	b._clean_exit()
	_check(not FileAccess.file_exists(CrashLog.FLAG), "al salir bien se borra la marca")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
