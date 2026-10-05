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

func _initialize() -> void:
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
	print("REMOTE_CARS_TEST ", "OK" if fails == 0 else "FALLÓ")
	quit(1 if fails > 0 else 0)
