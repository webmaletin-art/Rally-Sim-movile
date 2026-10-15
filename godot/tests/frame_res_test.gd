## RESOLUCIÓN DE FRAME (game/ui/frame_res.gd) y el ciclo de vida de las capas: reproduce lo de los registros del 14/10/2026
## («Attempt to disconnect a nonexistent connection from 'App' … Signal: 'child_order_changed'» justo después de cargar cada carrera):
## la pantalla de carga (una CanvasLayer hija de App) queda redirigida al frame reducido y se borra al terminar de cargar.
## Comprueba que ninguna capa (de la carrera o de afuera) salga del árbol todavía apuntando al frame, sin errores del motor.
## Uso: godot --headless --path godot --script res://tests/frame_res_test.gd
extends SceneTree

const FrameRes := preload("res://game/ui/frame_res.gd")
var fail := false
var errs: Array = []

class _Catch extends Logger:
	var out: Array
	func _log_error(_f: String, _file: String, _l: int, code: String, rationale: String, _e: bool, _t: int, _bt: Array[ScriptBacktrace]) -> void:
		out.append(code + " " + rationale)
	func _log_message(_m: String, _e: bool) -> void:
		pass

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _signal_errs() -> Array:
	return errs.filter(func(e) -> bool: return str(e).contains("child_order_changed") or str(e).contains("nonexistent"))

func _run() -> void:
	var lg := _Catch.new()
	lg.out = errs
	OS.add_logger(lg)
	var app := Node.new()
	app.name = "App"
	root.add_child(app)
	# 1) como app.gd: la pantalla de carga (hija de App) y después la carrera con su frame y su HUD
	var loading := CanvasLayer.new()
	loading.add_child(Label.new())
	app.add_child(loading)
	var race := Node.new()
	race.name = "Race"
	app.add_child(race)
	var hud := CanvasLayer.new()
	hud.add_child(Control.new())
	race.add_child(hud)
	var rig: Node = FrameRes.new()
	race.add_child(rig)
	rig.set_level(2)
	var late := CanvasLayer.new() # una capa que aparece durante la carrera (aviso, pausa…)
	race.add_child(late)
	await process_frame
	await process_frame
	_check(hud.custom_viewport == rig.sub and loading.custom_viewport == rig.sub and late.custom_viewport == rig.sub, "con el frame activo todas las capas dibujan en el frame")
	errs.clear()
	loading.queue_free() # la carrera terminó de cargar
	await process_frame
	_check(_signal_errs().is_empty(), "borrar la pantalla de carga no da el error de child_order_changed (%s)" % str(_signal_errs()))
	# 2) una capa que se saca y se vuelve a poner (no queda apuntando al frame al salir)
	race.remove_child(late)
	_check(late.custom_viewport == root, "una capa que sale del árbol vuelve a la ventana")
	race.add_child(late)
	await process_frame
	await process_frame
	_check(late.custom_viewport == rig.sub, "al volver a entrar se redirige otra vez")
	# 3) una capa de afuera de la carrera que sigue viva cuando la carrera se va SIN release_frame
	var outside := CanvasLayer.new()
	app.add_child(outside)
	await process_frame
	await process_frame
	_check(outside.custom_viewport == rig.sub, "la capa de afuera también dibuja en el frame")
	errs.clear()
	race.queue_free()
	await process_frame
	await process_frame
	_check(_signal_errs().is_empty(), "borrar la carrera con el frame activo no da errores de señales (%s)" % str(_signal_errs()))
	_check(is_instance_valid(outside) and outside.custom_viewport == root, "la capa de afuera vuelve a la ventana (no queda apuntando al frame borrado)")
	outside.queue_free()
	await process_frame
	_check(_signal_errs().is_empty(), "y después se borra sin errores")
	# 4) el camino normal: release_frame (nivel 0) y después borrar
	var race2 := Node.new()
	app.add_child(race2)
	var rig2: Node = FrameRes.new()
	race2.add_child(rig2)
	var hud2 := CanvasLayer.new()
	race2.add_child(hud2)
	rig2.set_level(3)
	await process_frame
	await process_frame
	errs.clear()
	rig2.set_level(0)
	_check(hud2.custom_viewport == root, "nivel 0: las capas vuelven a la ventana")
	race2.queue_free()
	await process_frame
	_check(_signal_errs().is_empty(), "y la carrera se borra sin errores (%s)" % str(_signal_errs()))
	OS.remove_logger(lg)
	print("RESULTADO: " + ("HAY FALLAS" if fail else "TODO OK"))
	quit(1 if fail else 0)
