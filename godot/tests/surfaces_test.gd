## Superficies del mundo (Etapa 14): asfalto, banquina, tierra, pasto, arena, roca y nieve donde corresponde. Sin red.
## Uso: godot --headless --path godot --script res://tests/surfaces_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const WS := preload("res://game/world/world_surfaces.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _init() -> void:
	var tr = CityTrack.new()
	var c = tr.city
	# sobre una avenida: asfalto
	var av: Dictionary = c.roads[c.road_named("Avenida 3")]
	var p: Vector3 = av["pts"][30]
	check(int(tr.ground_info(p.x, p.z).y) == 0, "sobre el asfalto de una avenida: código 0")
	# la plaza: pasto (fuera de las calles de la plaza)
	# playa: arena
	var sand := 0
	var sn := 0
	for i in 40:
		var x := -800.0 + float(i) * 40.0
		var z := 1210.0
		var h: float = c.height(x, z)
		if h < WS.SAND_H and int(c.probe(x, z)[6]) < 0:
			sn += 1
			if int(tr.ground_info(x, z).y) == WS.SAND:
				sand += 1
	check(sn > 5 and sand == sn, "la playa es arena (%d de %d puntos)" % [sand, sn])
	# la sierra: roca y nieve
	var rock := 0
	var snow := 0
	var best_h := 0.0
	for i in 60:
		var a := TAU * float(i) / 60.0
		for r in [250.0, 330.0, 420.0, 520.0, 650.0]:
			var q := Vector2(1950.0, 880.0) + Vector2(cos(a), sin(a)) * float(r)
			var h: float = c.height(q.x, q.y)
			best_h = maxf(best_h, h)
			var s := int(tr.ground_info(q.x, q.y).y)
			if h >= WS.SNOW_H and int(c.probe(q.x, q.y)[6]) < 0:
				snow += 1 if s == WS.SNOW else 0
			elif h >= WS.ROCK_H and int(c.probe(q.x, q.y)[6]) < 0:
				rock += 1 if s == WS.OUTSIDE else 0
	check(best_h > WS.SNOW_H, "la cumbre pasa los %d m (%.0f m)" % [int(WS.SNOW_H), best_h])
	check(snow > 0 and rock > 0, "hay nieve (%d) y roca (%d) en la sierra" % [snow, rock])
	# banquina de tierra al costado de la Ruta 20 y pasto más allá
	var r20: Dictionary = c.roads[c.road_named("Ruta 20")]
	var q20: Vector3 = r20["pts"][60]
	var tg := Vector2(r20["pts"][61].x - q20.x, r20["pts"][61].z - q20.z).normalized()
	var nr := Vector2(-tg.y, tg.x)
	var edge := float(r20["hw"]) + float(r20["sw"])
	var near := Vector2(q20.x, q20.z) + nr * (edge + 2.5)
	var far := Vector2(q20.x, q20.z) + nr * (edge + 40.0)
	check(int(tr.ground_info(near.x, near.y).y) == WS.SAND, "a 2,5 m de la banquina de la ruta: tierra (%d)" % int(tr.ground_info(near.x, near.y).y))
	check(int(tr.ground_info(far.x, far.y).y) == WS.GRASS, "a 40 m: pasto (%d)" % int(tr.ground_info(far.x, far.y).y))
	# el color coincide con lo que se pisa
	check(WS.color(80.0, 100.0, 0.0).r > 0.9 and WS.color(50.0, 100.0, 0.0) != Color.TRANSPARENT and WS.color(10.0, 100.0, 0.0) == Color.TRANSPARENT, "el color del suelo sigue las mismas alturas (nieve, roca, nada)")
	# costo: la consulta sigue siendo barata
	var t0 := Time.get_ticks_usec()
	for i in 20000:
		tr.ground_info(float(i % 700) * 3.0, float(i % 500) * 3.0)
	var us := float(Time.get_ticks_usec() - t0) / 20000.0
	check(us < 60.0, "ground_info cuesta %.1f µs por consulta" % us)
	print("SURFACES_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
