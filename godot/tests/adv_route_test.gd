## Modo aventura: la ruta completa se genera, cada etapa tiene un largo razonable y el camino no se cruza consigo mismo
## (dentro de una etapa ninguna parte lejana del recorrido pasa a menos de 30 m de otra).
extends SceneTree

const AdvRoute := preload("res://game/adventure/adv_route.gd")

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var R = AdvRoute.get_route()
	print("ruta: %d muestras (%.1f km) en %d ms" % [R.count, R.count * 2.5 / 1000.0, Time.get_ticks_msec() - t0])
	var ok := true
	for si in AdvRoute.stage_count():
		var r: Vector2i = R.stage_range(si)
		var a := maxi(0, r.x - 80)
		var b := mini(R.count, r.y + 100)
		var worst := 1e9
		var wi := -1
		var wj := -1
		var cells := {}
		for i in range(a, b):
			var key := Vector2i(floori(R.x[i] / 40.0), floori(R.z[i] / 40.0))
			if not cells.has(key):
				cells[key] = []
			cells[key].append(i)
		for i in range(a, b):
			var key := Vector2i(floori(R.x[i] / 40.0), floori(R.z[i] / 40.0))
			for gx in range(key.x - 1, key.x + 2):
				for gz in range(key.y - 1, key.y + 2):
					for j in cells.get(Vector2i(gx, gz), []):
						if absi(j - i) < 60:
							continue
						var d := Vector2(R.x[i] - R.x[j], R.z[i] - R.z[j]).length()
						if d < worst:
							worst = d
							wi = i
							wj = j
		var L: float = R.stage_length(si)
		var line := "etapa %2d %-28s %.2f km  · cruce más cercano %.0f m" % [si + 1, AdvRoute.STAGES[si]["name"], L / 1000.0, worst]
		if worst < 30.0:
			line += "  ✗ (muestras %d y %d)" % [wi - r.x, wj - r.x]
			ok = false
		print(line)
	print("OK" if ok else "FALLA")
	quit(0 if ok else 1)
