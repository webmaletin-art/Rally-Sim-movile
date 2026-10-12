## Costo de armar los cuadrados de la región (terreno, caminos, árboles, pueblos) en un hilo, por nivel de detalle.
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")

func _init() -> void:
	var track = CityTrack.new()
	var cw = track.build_world()
	var rw = track.world_node.get_node("region")
	var sites := {"llanura": Vector2(8000, -12000), "montaña": Vector2(-38878, -59164), "ciudad": Vector2(42551, 282), "autopista": Vector2(3300, -300), "pueblo": Vector2(34176, -73456)}
	for nm in sites:
		var p: Vector2 = sites[nm]
		var k := Vector2i(int(floor(p.x / 256.0)), int(floor(p.y / 256.0)))
		for tier in 3:
			var t0 := Time.get_ticks_usec()
			var d: Dictionary = rw._build(k, tier)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0
			var tris := 0
			for key in ["terrain", "roads", "sides", "marks", "rails", "buildings"]:
				tris += int((d[key].v as PackedVector3Array).size() / 3)
			print("%-10s nivel %d: %6.1f ms · %6d triángulos · %d árboles" % [nm, tier, ms, tris, int((d["trees"] as PackedFloat32Array).size() / 6) if d.has("trees") else 0])
	quit()
