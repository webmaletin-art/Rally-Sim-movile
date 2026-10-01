## Las pistas por curva de Godot contra el código real de la versión HTML (tools/godot/track_reference.mjs):
## largo, posición de las muestras, y altura/superficie en puntos sobre el camino, la banquina, el pasto y afuera.
extends SceneTree

const RouteTrack := preload("res://game/track/route_track.gd")

func _init() -> void:
	var exp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/expected_tracks.json"))
	var ok := true
	for key in exp:
		var e: Dictionary = exp[key]
		var rid: String = key.replace("Rev", "")
		var t = RouteTrack.new(rid, e["mode"], key.ends_with("Rev"))
		var dl: float = absf(t.length - float(e["length"])) / float(e["length"])
		var smax := 0.0
		for s in e["samples"]:
			var i: int = int(s[0])
			var p: Vector3 = t.samples[i]
			smax = maxf(smax, Vector3(s[1], s[2], s[3]).distance_to(p))
		var ymax := 0.0
		var surf_bad := 0
		for pr in e["probes"]:
			t.hint = -1
			var g: Vector2 = t.ground_info(pr[0], pr[1])
			# el terreno de afuera ya no copia al del HTML (el camino va hundido): solo se compara camino y banquina
			var js_surf: int = {"asphalt": 0, "dirt": 1, "shoulder": 2, "grass": 3, "outside": 4, "mud": 5}[pr[3]]
			if int(g.y) != js_surf:
				surf_bad += 1
			if js_surf <= 2:
				ymax = maxf(ymax, absf(g.x - float(pr[2])))
		var good := dl < 0.003 and smax < 1.5 and ymax < 0.35 and surf_bad <= 2
		print("%s %-14s largo %.0f m (dif %.2f%%) · muestras: peor %.2f m · alturas: peor %.3f m · superficies distintas %d/%d" % ["OK  " if good else "FALLA", key, t.length, dl * 100.0, smax, ymax, surf_bad, e["probes"].size()])
		ok = ok and good
	quit(0 if ok else 1)
