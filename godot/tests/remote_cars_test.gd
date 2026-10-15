## Autos de otros jugadores: se arma el modelo real con la pintura/gomas/piezas del servidor (y se mueve con las ruedas girando) sin necesitar red ni la carrera.
## Uso: godot --headless --path godot --script res://tests/remote_cars_test.gd
extends SceneTree

const RemoteCars := preload("res://game/online/remote_cars.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

class FakeRace extends Node:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var cars: Array = []

class FakePhys extends RefCounted:
	var px := 1000.0
	var pz := 1000.0

class FakeCar extends RefCounted:
	var phys := FakePhys.new()

class FakeCity extends RefCounted:
	func probe(_x: float, _z: float) -> Array:
		return [-9.0, 0, 0, 0, 0.0]
	func height(_x: float, _z: float) -> float:
		return 0.0

## La lista de jugadores del servidor, a mano: ok=false simula que no contestó
class FakeSocial extends Node:
	var active := true
	var ok := true
	var list: Array = []
	func players_safe() -> Dictionary:
		await get_tree().process_frame
		return {"ok": ok, "list": list.duplicate(true) if ok else []}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var rc := RemoteCars.new()
	rc.race = FakeRace.new()
	root.add_child(rc)
	var veh := {"vehicle": "hatch", "paint": {"body": "#112233", "rim": "#ffcc00", "finish": "metal"}, "mods": {}, "tires": "sport"}
	var vis: Node3D = rc._build_real(veh)
	check(vis != null, "se arma el modelo real del auto que el servidor dice (hatch)")
	if vis != null:
		rc.add_child(vis)
		var snap := rc._snap
		snap.px = 5.0
		snap.py = 1.0
		snap.pz = 3.0
		snap.yaw = 0.5
		snap.wheel_omega = PackedFloat64Array([10.0, 10.0, 10.0, 10.0])
		vis.sync_from(snap, 0.016)
		check(vis.position.is_equal_approx(Vector3(5, 1, 3)), "el modelo se coloca donde está el otro jugador")
	check(rc._build_real({"vehicle": "auto_que_no_existe"}) == null, "un modelo desconocido no rompe: queda el auto de papel")
	var a := RemoteCars.mesh_color(Color("#112233"))
	var b := RemoteCars.mesh_color(Color("#112233"))
	var c := RemoteCars.mesh_color(Color("#aa3322"))
	check(a == b and a != c, "el auto de papel toma el color de la pintura (y se reutiliza)")
	await _presence_rules()
	print("REMOTE_CARS_TEST ", "OK" if fails == 0 else "FALLÓ")
	quit(1 if fails > 0 else 0)

## 15/10/2026 («online fluido»): quién se muestra y cuándo se saca
func _presence_rules() -> void:
	var race := FakeRace.new()
	race.cars = [FakeCar.new()]
	root.add_child(race)
	var soc := FakeSocial.new()
	root.add_child(soc)
	var rc := RemoteCars.new()
	rc.setup(race, soc, FakeCity.new())
	rc.set_process(false)
	root.add_child(rc)
	var now := Time.get_ticks_msec() / 1000.0
	# 1) aparece con el primer dato en vivo, sin esperar la lista (antes no se dibujaba hasta que la lista lo traía: hasta 2 s)
	rc.apply_live("beto-0002", {"x": 1020.0, "z": 1000.0, "yaw": 0.0, "kmh": 50.0, "t": now, "arr": now})
	check(rc.cars.has("beto-0002"), "un auto aparece con el primer dato en vivo (sin esperar la lista)")
	check(rc._t <= 0.5, "y se pide la lista enseguida para su nombre y su modelo")
	# 2) una lista que falla no borra a nadie
	soc.ok = false
	await rc._poll()
	check(rc.cars.has("beto-0002") and int(rc.stats["poll_fail"]) == 1, "si el servidor no contesta la lista, los autos siguen (antes desaparecían todos)")
	# 3) la lista trae el nombre; uno lejos no se muestra; el que está en vivo sigue aunque la lista no lo traiga
	soc.ok = true
	soc.list = [{"player_id": "beto-0002", "name": "Beto", "x": 1020.0, "z": 1000.0, "speed": 50.0}, {"player_id": "lejos-0003", "name": "Lejos", "x": 9000.0, "z": 9000.0}]
	await rc._poll()
	check((rc.cars["beto-0002"]["label"] as Label3D).text == "Beto" and not rc.cars.has("lejos-0003"), "la lista le pone el nombre; el que está lejos no se dibuja")
	soc.list = []
	await rc._poll()
	check(rc.cars.has("beto-0002"), "el que manda en vivo sigue aunque la lista (con tope y algo atrasada) no lo traiga")
	# 4) histéresis: se muestra a menos de SHOW_R, se saca recién después de HIDE_R
	soc.list = [{"player_id": "borde-0004", "name": "Borde", "x": 1000.0 + RemoteCars.SHOW_R + 50.0, "z": 1000.0}]
	await rc._poll()
	check(not rc.cars.has("borde-0004"), "a más de %d m no aparece" % int(RemoteCars.SHOW_R))
	soc.list = [{"player_id": "borde-0004", "name": "Borde", "x": 1000.0 + RemoteCars.SHOW_R - 20.0, "z": 1000.0}]
	await rc._poll()
	soc.list = [{"player_id": "borde-0004", "name": "Borde", "x": 1000.0 + RemoteCars.SHOW_R + 60.0, "z": 1000.0}]
	await rc._poll()
	check(rc.cars.has("borde-0004"), "pero una vez que se ve, sigue hasta %d m (no titila en el borde)" % int(RemoteCars.HIDE_R))
	# 5) se va (cerró el juego): se saca ya y la lista, que todavía lo trae quieto donde estaba, no lo vuelve a poner (fantasma)
	rc.live_gone("beto-0002")
	check(not rc.cars.has("beto-0002"), "el que se va desaparece enseguida")
	soc.list = [{"player_id": "beto-0002", "name": "Beto", "x": 1020.0, "z": 1000.0, "speed": 0.0}]
	await rc._poll()
	check(not rc.cars.has("beto-0002") and int(rc.stats["ghosts_blocked"]) >= 1, "la lista del servidor (que lo tiene 45 s más) no lo vuelve a poner: sin fantasmas")
	soc.list = [{"player_id": "beto-0002", "name": "Beto", "x": 1060.0, "z": 1000.0, "speed": 30.0}]
	await rc._poll()
	check(rc.cars.has("beto-0002"), "si se mueve de nuevo (volvió), aparece")
	rc.live_gone("beto-0002")
	rc.apply_live("beto-0002", {"x": 1065.0, "z": 1000.0, "yaw": 0.0, "kmh": 30.0, "t": now + 1.0, "arr": now + 1.0})
	await process_frame
	check(rc.cars.has("beto-0002") and rc.cars.size() == rc.get_child_count(), "y si vuelve a mandar en vivo también, sin duplicarse (%d autos, %d nodos)" % [rc.cars.size(), rc.get_child_count()])
	rc.queue_free()
	race.queue_free()
	soc.queue_free()
