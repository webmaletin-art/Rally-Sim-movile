## Todos los scripts del juego compilan: un error de sintaxis o un identificador que no existe en un script que las demás pruebas no cargan (la pausa, un menú, una pista) sólo se vería al jugar en el teléfono.
## Uso: godot --headless --path godot --script res://tests/scripts_parse_test.gd
extends SceneTree

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _scan(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d == "addons":
			continue
		_scan(dir.path_join(d), out)

func _init() -> void:
	var files: Array = []
	_scan("res://game", files)
	_scan("res://bootstrap", files)
	files.sort()
	var bad: Array = []
	for p in files:
		var sc: Variant = load(p)
		if not (sc is GDScript) or not (sc as GDScript).can_instantiate():
			bad.append(str(p))
	_check(files.size() > 150, "scripts del juego: %d" % files.size())
	_check(bad.is_empty(), "todos compilan (con error: %s)" % str(bad.slice(0, 8)))
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
