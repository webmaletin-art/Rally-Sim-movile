## Un auto automático recorre las rutas de la región (circunvalación, autopista y montaña) con la física real: no se sale del camino, no se traba y las pendientes se pueden subir.
## Uso: godot --headless --path godot --script res://tests/region_drive_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const NetDriver := preload("res://game/net/net_driver.gd")
const VehiclePhysics := preload("res://game/physics/vehicle_physics.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")

class Net:
	extends RefCounted
	var nodes := {}
	func probe(_x: float, _z: float, _r := 0.0) -> Array:
		return []
	func route(_a: Vector2, _b: Vector2) -> Array:
		return [PackedVector2Array(), 0.0]

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var track = CityTrack.new()
	var rg = track.region
	_check(rg != null, "la pista de la ciudad cargó la región")
	var names := {}
	for i in rg.nodes.size():
		names[str(rg.nodes[i][4])] = i
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var legs := [["exit20", "Puerto Alba", "hatch"], ["Villa Cóndor", "Paso del Cóndor", "pickup"], ["Santa Aurora", "Quebrada Roja", "gt"]]
	for leg in legs:
		var a: Vector2 = rg.node_pos(rg.node_by_id(leg[0]) if rg.node_by_id(leg[0]) >= 0 else names[leg[0]])
		var b: Vector2 = rg.node_pos(names[leg[1]])
		var r: Dictionary = rg.route(a, b)
		var route: PackedVector2Array = r["pts"]
		var d: Dictionary = vehicles[leg[2]].duplicate()
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var ph := VehiclePhysics.new(track, VehicleParams.from_dict(d))
		var p0 := route[0]
		var dir := (route[mini(8, route.size() - 1)] - p0).normalized()
		ph.reset(p0.x, p0.y, atan2(dir.x, dir.y))
		var drv := NetDriver.new(Net.new(), "wander", 0.72, 4)
		drv.set_route(route)
		var t := 0.0
		var h := 1.0 / 120.0
		var prev := p0
		var dist := 0.0
		var off := 0.0
		var stuck := 0.0
		var worst_stuck := 0.0
		var vmax := 0.0
		var hmin := 1e9
		var hmax := -1e9
		var wall_hits := 0
		var max_t := minf(420.0, r["len"] / 18.0 + 30.0)
		while t < max_t and dist < float(r["len"]) - 120.0:
			var c: Vector3 = drv.update(ph, h)
			ph.step(h, c.x, c.y, c.z, false, false)
			t += h
			var q := Vector2(ph.px, ph.pz)
			dist += q.distance_to(prev)
			prev = q
			var sp := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
			vmax = maxf(vmax, sp)
			stuck = stuck + h if sp < 1.0 else 0.0
			worst_stuck = maxf(worst_stuck, stuck)
			var gi: Vector2 = track.ground_info(q.x, q.y)
			hmin = minf(hmin, gi.x)
			hmax = maxf(hmax, gi.x)
			if int(gi.y) >= 2:
				off += h
			var pw: Vector3 = track.push(q.x, q.y, 1.0)
			if pw.z > 0.0:
				wall_hits += 1
				if wall_hits % 200 == 1 and wall_hits < 1500:
					print("     pared en (%.0f, %.0f) t=%.0f s a %.0f km/h, km %.2f" % [q.x, q.y, t, sp * 3.6, dist / 1000.0])
		_check(dist > 0.9 * minf(float(r["len"]), max_t * 12.0), "%s → %s (%s): recorrió %.1f km de %.1f en %.0f s (máx. %.0f km/h, alturas %.0f–%.0f m)" % [leg[0], leg[1], leg[2], dist / 1000.0, float(r["len"]) / 1000.0, t, vmax * 3.6, hmin, hmax])
		_check(off < t * 0.05, "  fuera de la calzada %.1f s de %.0f" % [off, t])
		_check(worst_stuck < 6.0, "  peor quedada parado %.1f s" % worst_stuck)
		_check(wall_hits < 60, "  contactos con la pared %d" % wall_hits)
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
