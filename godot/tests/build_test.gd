## buildParams y perfOf de Godot contra el código real de la versión HTML (tools/godot/extract_data.mjs).
extends SceneTree

const CarBuild := preload("res://game/data/car_build.gd")

func _init() -> void:
	var exp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/expected_build.json"))
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var ok := true
	for cs in exp["cases"]:
		var V: Dictionary = CarBuild.build_params(vehicles[cs["id"]], cs["state"])
		var worst := 0.0
		var wk := ""
		for k in cs["V"]:
			var ev = cs["V"][k]
			if not V.has(k):
				print("  falta ", k)
				ok = false
				continue
			if ev is float or ev is int:
				var d := absf(float(V[k]) - float(ev)) / maxf(1e-9, maxf(absf(float(ev)), 1e-3))
				if d > worst:
					worst = d
					wk = k
		var P: Dictionary = CarBuild.perf_of(V)
		var ep: Dictionary = cs["perf"]
		var pok: bool = P["pi"] == int(ep["pi"]) and P["hp"] == int(ep["hp"]) and P["vmax"] == int(ep["vmax"]) and P["kg"] == int(ep["kg"])
		var good := worst < 1e-9 and pok
		ok = ok and good
		print("%s %-8s mejoras %d · peor diferencia %s (%s) · PI %d/%d · %d cv · %d km/h" % ["OK  " if good else "FALLA", cs["id"], cs["state"]["upg"].size(), String.num_scientific(worst), wk, P["pi"], int(ep["pi"]), P["hp"], P["vmax"]])
	quit(0 if ok else 1)
