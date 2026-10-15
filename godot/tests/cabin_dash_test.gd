## Tablero de la cabina (game/car/cockpit.gd, 15/10/2026): las 3 opciones (3D, imagen, clásico) se arman en autos con techo, la imagen
## no sale del ancho del habitáculo y queda debajo del parabrisas, y las cabinas abiertas (buggy) siempre usan el clásico.
## Uso: godot --headless --path godot --script res://tests/cabin_dash_test.gd
extends SceneTree

const Cockpit := preload("res://game/car/cockpit.gd")
var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	for car in ["hatch", "genesis", "gt3", "buggy"]:
		for st in ["modelo", "imagen", "clasico"]:
			Cockpit.dash_style = st
			var ck: Node3D = Cockpit.new(car)
			root.add_child(ck)
			var open := bool(ck.open_cab)
			var has_model: bool = ck.dash_node != null
			var has_img: bool = ck.dash_img_node != null
			if open:
				_check(not has_model and not has_img, "%s (abierto) · %s → clásico" % [car, st])
			elif st == "modelo":
				_check(has_model and not has_img, "%s · 3D" % car)
			elif st == "imagen":
				var ok := has_img and not has_model
				if ok:
					var aabb: AABB = ck.dash_img_node.transform * ck.dash_img_node.mesh.get_aabb()
					ok = aabb.size.x <= 2.0 * float(ck.hw) + 0.001 and aabb.end.y <= float(ck.cowl_y) + 0.02
					_check(ok, "%s · imagen: ancho %.2f ≤ %.2f, arriba %.2f ≤ parabrisas %.2f" % [car, aabb.size.x, 2.0 * float(ck.hw), aabb.end.y, float(ck.cowl_y)])
				else:
					_check(false, "%s · imagen" % car)
			else:
				_check(not has_model and not has_img, "%s · clásico" % car)
			ck.free()
	Cockpit.dash_style = "modelo"
	print("RESULTADO: " + ("HAY FALLAS" if fail else "TODO OK"))
	quit(1 if fail else 0)
