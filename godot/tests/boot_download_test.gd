## Descarga del juego en el APK liviano (bootstrap/boot.gd), arreglo del 15/10/2026 («Falló la descarga (13/0)» con buen wifi en otro teléfono):
## el 13 es RESULT_TIMEOUT y el tope de 30 s era para TODA la descarga. Contra un servidor local (tests/tools/dl_server.py) que corta un paquete
## en un tramo y deja otro trabado, comprueba que el cliente: baja por tramos (Range), no corta por tiempo total, detecta la traba, repite sólo el
## tramo perdido y termina con los dos paquetes íntegros (sha256), sin que el jugador toque «Reintentar». Anda igual con Godot 4.5 y 4.7
## (4.7 borra el archivo a medio bajar al fallar).
## Uso: godot --headless --path godot --script res://tests/boot_download_test.gd
extends SceneTree

const PORT := 18731
var fail := false
var done := false

class TestBoot extends "res://bootstrap/boot.gd":
	var finished := false
	func _ready() -> void:
		_build_ui()
		_check_updates()
	func _mount_and_start() -> void:
		finished = true

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)

func _run() -> void:
	var dir := ProjectSettings.globalize_path("user://dltest")
	DirAccess.make_dir_recursive_absolute(dir)
	for fn in DirAccess.get_files_at("user://dltest"):
		DirAccess.remove_absolute("user://dltest/" + fn)
	for n in ["content", "cars"]:
		for ext in [".pck", ".pck.tmp", ".pck.tmp.part", ".pck.tmp.ver", "_version.txt"]:
			DirAccess.remove_absolute("user://" + n + ext)
	var srv := ProjectSettings.globalize_path("res://tests/tools/dl_server.py")
	var pid := OS.create_process("python3", [srv, str(PORT), dir])
	_check(pid > 0, "servidor local de prueba")
	var t0 := Time.get_ticks_msec()
	var up := false # (espera a que el servidor conteste)
	while not up and Time.get_ticks_msec() - t0 < 30000:
		await create_timer(0.3).timeout
		var hc := HTTPClient.new()
		if hc.connect_to_host("127.0.0.1", PORT) == OK:
			for k in 20:
				hc.poll()
				if hc.get_status() == HTTPClient.STATUS_CONNECTED:
					up = true
					break
				if hc.get_status() in [HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR]:
					break
				await create_timer(0.05).timeout
		hc.close()
	var b := TestBoot.new()
	b._manifest_url = "http://127.0.0.1:%d/manifest.json" % PORT
	b.stall_s = 3.0
	b.seg = 1048576 # tramos de 1 MB (en el juego, 32 MB)
	root.add_child(b)
	t0 = Time.get_ticks_msec()
	var saw_retry := false
	while not b.finished and Time.get_ticks_msec() - t0 < 90000:
		await create_timer(0.1).timeout
		if OS.has_environment("DL_DEBUG"):
			print("  %.1f %s stall=%.1f got=%d" % [(Time.get_ticks_msec() - t0) / 1000.0, b._status.text.replace("\n", " · "), b._stall, b._http.get_downloaded_bytes()])
		if b._status.text.contains("Reintentando"):
			saw_retry = true
		if b._retry.visible:
			break
	_check(b.finished, "terminó de bajar los dos paquetes solo (en %.1f s; estado: %s)" % [(Time.get_ticks_msec() - t0) / 1000.0, b._status.text.replace("\n", " · ")])
	_check(saw_retry, "reintentó solo tras el corte y la traba")
	_check(not b._retry.visible, "no hizo falta tocar «Reintentar»")
	var lg := FileAccess.get_file_as_string("user://dltest/server.log")
	print("     servidor: " + lg.strip_edges().replace("\n", " | "))
	_check(lg.contains("content.pck pedido 3 desde 2097152") and lg.contains("content.pck pedido 4 desde 2097152"), "content.pck: el tramo cortado se volvió a pedir desde los 2 MB (no desde cero)")
	_check(lg.contains("cars.pck pedido 2 desde 1048576") and lg.contains("cars.pck pedido 3 desde 1048576"), "cars.pck: el vigilante cortó el tramo trabado y siguió desde 1 MB")
	_check(lg.contains("content.pck pedido 7 desde 5242880") and not lg.contains("pedido 1 desde 0\ncontent.pck pedido 2 desde 0"), "baja por tramos de 1 MB (content: 6 tramos + 1 repetido)")
	var ok_sha := FileAccess.file_exists("user://content.pck") and FileAccess.file_exists("user://cars.pck")
	_check(ok_sha and FileAccess.get_file_as_string("user://content_version.txt") == "v1" and FileAccess.get_file_as_string("user://cars_version.txt") == "c1", "paquetes guardados con su versión")
	_check(not FileAccess.file_exists("user://cars.pck.tmp") and not FileAccess.file_exists("user://cars.pck.tmp.part") and not FileAccess.file_exists("user://cars.pck.tmp.ver"), "no quedan restos de la descarga")
	OS.kill(pid)
	for n in ["content", "cars"]:
		for ext in [".pck", ".pck.tmp", ".pck.tmp.part", ".pck.tmp.ver", "_version.txt"]:
			DirAccess.remove_absolute("user://" + n + ext)
	print("RESULTADO: " + ("HAY FALLAS" if fail else "TODO OK"))
	quit(1 if fail else 0)
