## Plano de Dream City visto desde arriba (para ver huecos): rojo = calle/vereda, gris = edificio, blanco = vacío.
## Uso: godot --headless --script res://tests/city_plan.gd -- /tmp/plano.png [x0 z0 lado_m]
extends SceneTree
const CityLayout := preload("res://game/city/city_layout.gd")
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/plano.png"
	var x0 := float(args[1]) if args.size() > 1 else -1200.0
	var z0 := float(args[2]) if args.size() > 2 else -1200.0
	var side := float(args[3]) if args.size() > 3 else 2400.0
	var c := CityLayout.new()
	c.build()
	var n := 800
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	for iy in n:
		for ix in n:
			var x := x0 + (float(ix) + 0.5) * side / float(n)
			var z := z0 + (float(iy) + 0.5) * side / float(n)
			var col := Color(1, 1, 1)
			var pr := c.probe(x, z)
			if pr[0] > -0.05:
				col = Color(0.85, 0.3, 0.3) if float(pr[1]) <= float(pr[5]) else Color(0.95, 0.7, 0.6)
			img.set_pixel(ix, iy, col)
	# losas: la línea de frente en azul y el fondo (profundidad) en gris
	for key in c.slabs:
		for sl in c.slabs[key]:
			var sp: PackedVector3Array = sl["pts"]
			var aw: PackedVector2Array = sl["away"]
			for i in sp.size() - 1:
				for k in 6:
					var f := float(k) / 5.0
					var pa := Vector2(sp[i].x, sp[i].z).lerp(Vector2(sp[i + 1].x, sp[i + 1].z), f)
					var an := aw[i].lerp(aw[i + 1], f).normalized()
					for dd in range(0, int(float(sl["depth"]) * 1.0), 2):
						var q := pa + an * float(dd)
						var ix := int((q.x - x0) / side * float(n))
						var iy := int((q.y - z0) / side * float(n))
						if ix >= 0 and iy >= 0 and ix < n and iy < n:
							img.set_pixel(ix, iy, Color(0.45, 0.5, 0.6) if dd > 0 else Color(0.1, 0.1, 0.9))
	img.save_png(out)
	quit()
