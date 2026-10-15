## Lluvia bajo techo (15/10/2026, «llueve adentro del estacionamiento»): la ciudad arma la lista de techos (salas del estacionamiento, rampas, túneles, gasolineras)
## y el clima le pasa al shader de las gotas los más cercanos a la cámara; las gotas que caen debajo de un techo no se dibujan (weather_drop.gdshader → covered()).
## Acá se prueba la lista y la elección (el shader no corre sin GPU): misma cuenta que el shader, en GDScript. Sin red.
## Uso: godot --headless --path godot --script res://tests/rain_cover_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const Weather := preload("res://game/fx/weather.gd")

class FakeTrack extends RefCounted:
	var grip_mul := 1.0

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

## la misma cuenta que covered() del shader
func covered(q: Vector3, a: Array, b: Array, n: int) -> bool:
	for i in n:
		var c0: Vector4 = a[i]
		var c1: Vector4 = b[i]
		if q.y > c0.z or q.y < c0.w:
			continue
		var d := Vector2(q.x - c0.x, q.z - c0.y)
		if c1.w < 0.0:
			if d.length() < c1.z:
				return true
		elif absf(d.dot(Vector2(c1.x, c1.y))) < c1.z and absf(d.dot(Vector2(-c1.y, c1.x))) < c1.w:
			return true
	return false

func _initialize() -> void:
	_run.call_deferred() # (los nodos tienen que estar en el árbol para leer su posición)

func _run() -> void:
	var city := CityLayout.new()
	city.build()
	var cov: Array = city.rain_covers()
	check(city.halls.size() == 3, "el estacionamiento tiene sus tres salas")
	check(cov.size() >= 3 + city.stations.size(), "hay techos: salas, rampas/túneles y gasolineras (%d)" % cov.size())
	var root := Node3D.new()
	get_root().add_child(root)
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	var w := Weather.new()
	root.add_child(w)
	w.setup(env, sun, cam, FakeTrack.new(), null, StandardMaterial3D.new(), StandardMaterial3D.new())
	w.set_covers(cov)
	w.apply("lluvia", true)
	var hall: Dictionary = city.halls[0]
	var hc: Vector2 = hall["pos"]
	var hy := float(hall["y"])
	cam.global_position = Vector3(hc.x, hy + 1.5, hc.y)
	w._update_covers(1.0)
	var sm: ShaderMaterial = w._drop_mats[0]
	var n: int = sm.get_shader_parameter("cov_n")
	var a: Array = Array(sm.get_shader_parameter("cov0"))
	var b: Array = Array(sm.get_shader_parameter("cov1"))
	check(n > 0 and n <= Weather.COV_MAX, "adentro del estacionamiento el shader recibe los techos cercanos (%d)" % n)
	check(covered(Vector3(hc.x + 3.0, hy + 2.0, hc.y), a, b, n), "una gota adentro de la planta baja no se dibuja")
	var h1: Dictionary = city.halls[1]
	check(covered(Vector3((h1["pos"] as Vector2).x, float(h1["y"]) + 2.0, (h1["pos"] as Vector2).y), a, b, n), "tampoco en la planta alta (la sala de al lado)")
	var mid: Vector2 = (hc + (h1["pos"] as Vector2)) * 0.5
	check(covered(Vector3(mid.x, (hy + float(h1["y"])) * 0.5 + 1.5, mid.y), a, b, n), "ni en la rampa")
	check(not covered(Vector3(hc.x, hy + 12.0, hc.y), a, b, n), "arriba del techo sí llueve")
	var gp: Vector2 = city.garage["p"]
	check(not covered(Vector3(gp.x, hy + 1.0, gp.y), a, b, n), "en la ruta de enfrente sí llueve")
	# una gasolinera: debajo del techo no, al costado del playón sí
	var st: Dictionary = city.stations[0]
	var sc: Vector2 = st["center"]
	var sy := city.height(sc.x, sc.y)
	cam.global_position = Vector3(sc.x, sy + 1.5, sc.y)
	w._cov_t = 0.0
	w._update_covers(1.0)
	n = sm.get_shader_parameter("cov_n")
	a = Array(sm.get_shader_parameter("cov0"))
	b = Array(sm.get_shader_parameter("cov1"))
	var kd: Dictionary = CityLayout.STATION_KINDS[str(st["kind"])]
	var tn := Vector2((st["dir"] as Vector2).y, -(st["dir"] as Vector2).x).normalized()
	check(covered(Vector3(sc.x, sy + 2.0, sc.y) + Vector3(tn.x, 0, tn.y) * (float(kd["canopy"][0]) * 0.4), a, b, n), "debajo del techo de la gasolinera no llueve")
	check(not covered(Vector3(sc.x, sy + 2.0, sc.y) + Vector3(tn.x, 0, tn.y) * (float(kd["canopy"][0]) * 0.5 + 3.0), a, b, n), "al costado del techo sí")
	# lejos de todo: ningún techo
	cam.global_position = Vector3(0, 2, 0)
	w._cov_t = 0.0
	w._update_covers(1.0)
	var n0: int = sm.get_shader_parameter("cov_n")
	a = Array(sm.get_shader_parameter("cov0"))
	b = Array(sm.get_shader_parameter("cov1"))
	check(not covered(Vector3(0, 2, 0), a, b, n0), "en la plaza llueve (%d techos cerca)" % n0)
	print("RAIN_COVER_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
