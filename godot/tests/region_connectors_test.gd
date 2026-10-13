## Los empalmes entre rutas paralelas (tools/world_gen/add_connectors.py): de una ruta se pasa a la paralela por el empalme (el GPS lo usa) y un auto lo maneja de punta a punta sin trabarse.
## Antes había que ir hasta el final de la ruta para entrar a la paralela (por ejemplo la RN-10 y la RN-11, a 40 m una de otra durante 3 km).
## Uso: godot --headless --path godot --script res://tests/region_connectors_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const RegionData := preload("res://game/region/region_data.gd")
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

## Un punto sobre la ruta `ei` (la que sale del nodo `ni`) a `dist` metros del nodo
func _along(rg: RegionData, ei: int, ni: int, dist: float) -> Vector2:
	var e: Array = rg.edges[ei]
	var total: float = rg.edge_cum(ei)[rg.edge_n(ei) - 1]
	var s: float = minf(dist, total * 0.9) if int(e[0]) == ni else maxf(total - dist, total * 0.1)
	return rg.point_at(ei, s)[0]

func _init() -> void:
	var tr := CityTrack.new()
	var rg: RegionData = tr.region
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var conn: Array = []
	for ei in rg.edges.size():
		if str((rg.edges[ei] as Array)[3]).begins_with("Empalme"):
			conn.append(ei)
	_check(conn.size() >= 20, "hay empalmes entre rutas paralelas (%d)" % conn.size())
	var short_ok := 0
	var bad: Array = []
	var driven := 0
	var drive_bad: Array = []
	for ci in conn:
		var e: Array = rg.edges[ci]
		var na := int(e[0])
		var nb := int(e[1])
		# las dos rutas que une: la que sigue de cada nodo (cualquiera de las otras dos)
		var ea := -1
		var eb := -1
		for x in rg.node_edges[na]:
			if x != ci and ea < 0:
				ea = x
		for x in rg.node_edges[nb]:
			if x != ci and eb < 0:
				eb = x
		if ea < 0 or eb < 0:
			bad.append("%s sin rutas en un extremo" % str(e[3]))
			continue
		var pa := _along(rg, ea, na, 120.0)
		var pb := _along(rg, eb, nb, 120.0)
		var r: Dictionary = rg.route(pa, pb)
		var line := pa.distance_to(pb)
		var len_ := float(r["len"])
		if len_ > 0.0 and len_ < line * 2.2 + 500.0:
			short_ok += 1
		else:
			bad.append("%s: de una ruta a la otra hay %.0f m por la red (en línea recta %.0f)" % [str(e[3]), len_, line])
			continue
		# con la física de verdad (un empalme de cada tres, o los que no hayan salido bien antes)
		if driven < 9 and (conn.find(ci) % 3 == 0):
			driven += 1
			var route: PackedVector2Array = r["pts"]
			# la ruta sigue derecho un poco más allá del final: el piloto de la red elige otro destino si se queda sin camino
			var last: Vector2 = route[route.size() - 1]
			var dl: Vector2 = (last - route[route.size() - 2]).normalized()
			for k in range(1, 40):
				route.append(last + dl * 10.0 * float(k))
			var d: Dictionary = (vehicles["hatch"] as Dictionary).duplicate()
			d["camberF"] = -1.0
			d["camberR"] = -0.5
			d["toeF"] = 0.0
			d["toeR"] = 0.1
			d["pressF"] = 30.0
			d["pressR"] = 30.0
			var ph := VehiclePhysics.new(tr, VehicleParams.from_dict(d))
			var p0 := route[0]
			var dir := (route[mini(6, route.size() - 1)] - p0).normalized()
			ph.reset(p0.x, p0.y, atan2(dir.x, dir.y))
			var drv := NetDriver.new(Net.new(), "wander", 0.7, 3)
			drv.set_route(route)
			var t := 0.0
			var h := 1.0 / 120.0
			var prev := p0
			var dist := 0.0
			var stuck := 0.0
			var worst := 0.0
			var hits := 0
			var hmax := 0.0
			var prev_y := 0.0
			while t < 90.0 and dist < len_ - 40.0:
				var c: Vector3 = drv.update(ph, h)
				ph.step(h, c.x, c.y, c.z, false, false)
				t += h
				var q := Vector2(ph.px, ph.pz)
				dist += q.distance_to(prev)
				prev = q
				var sp := sqrt(ph.vx * ph.vx + ph.vz * ph.vz)
				stuck = stuck + h if sp < 1.0 else 0.0
				worst = maxf(worst, stuck)
				if (tr.push(q.x, q.y, 1.0) as Vector3).z > 0.05:
					hits += 1
			if not (dist > len_ - 60.0 and worst < 4.0 and hits < 20):
				drive_bad.append("%s: %.0f m de %.0f, parado %.1f s, %d roces" % [str(e[3]), dist, len_, worst, hits])
	_check(bad.is_empty() and short_ok == conn.size(), "de una ruta se pasa a la paralela por el empalme (%d de %d; mal: %s)" % [short_ok, conn.size(), str(bad.slice(0, 4))])
	_check(drive_bad.is_empty() and driven >= 6, "un auto maneja de una ruta a la otra por el empalme (%d probados; mal: %s)" % [driven, str(drive_bad.slice(0, 4))])
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
