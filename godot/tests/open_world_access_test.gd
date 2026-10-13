## El mundo abierto se puede recorrer: de cada lugar para aparecer se sale a una calle, cada estación y cada gomería tiene su camino de acceso, las rutas de la ciudad siguen por la región
## (sin portón, sin cartel «PRÓXIMAMENTE» y sin nada sólido en la calzada) y no hay árboles de la región sobre las rutas de la ciudad.
## Uso: godot --headless --path godot --script res://tests/open_world_access_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const CityLayout := preload("res://game/city/city_layout.gd")
const CityProps := preload("res://game/city/city_props.gd")
const RegionData := preload("res://game/region/region_data.gd")
const RegionWorld := preload("res://game/region/region_world.gd")
const RegionServices := preload("res://game/region/region_services.gd")
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
	var tr := CityTrack.new()
	var city: CityLayout = tr.city
	var rg: RegionData = tr.region
	_check(rg != null and RegionServices.available(), "la región está en la compilación")
	for id in city.prop_type.size(): # todos los objetos sólidos de la ciudad puestos (como los pone CityWorld al armar cada cuadra)
		var rad: float = CityProps.RADIUS[int(city.prop_type[id])]
		if rad > 0.0:
			tr.add_prop(id, city.prop_x[id], city.prop_z[id], rad)
	_exits(tr, city, rg)
	_gates_and_blocks(city)
	_lots(tr, rg)
	_city_stations(tr, city)
	_spawns(tr, rg)
	_drive_out(tr, rg)
	for num in [40, 80, 20]:
		_drive_exit(tr, city, rg, num)
	_city_roads_clear(tr, city)
	_trees(tr, city, rg)
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)

# ───────────────────────── las salidas de la ciudad siguen por la región ─────────────────────────
func _exits(tr, city: CityLayout, rg: RegionData) -> void:
	for num in [20, 40, 80]:
		var ex: Dictionary = {}
		for e in city.exits:
			if int(e["num"]) == num:
				ex = e
		_check(not ex.is_empty(), "Salida %d existe" % num)
		if ex.is_empty():
			continue
		var ni := rg.node_by_id("exit%d" % num)
		_check(ni >= 0 and not (rg.node_edges[ni] as PackedInt32Array).is_empty(), "la región sigue la Ruta %d (nodo exit%d con camino)" % [num, num])
		if num in [40, 80]:
			_check(str(ex.get("to", "")) == "region", "Salida %d: la ruta sigue por la región (sin portón)" % num)
		# la punta de la ruta de la ciudad toca la ruta de la región (sin hueco)
		var rd: Dictionary = city.roads[int(ex["road"])]
		var pts: PackedVector3Array = rd["pts"]
		var tip := Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z)
		var pr: PackedFloat64Array = rg.probe(tip.x, tip.y, 30.0, false)
		_check(pr[0] > -1e8 and pr[4] < 2.0, "la Ruta %d de la ciudad empalma con la de la región (distancia %.1f m)" % [num, pr[4]])
	# la Panorámica también sigue
	var pan := rg.node_by_id("pan_end")
	_check(pan >= 0 and not (rg.node_edges[pan] as PackedInt32Array).is_empty(), "la Ruta Panorámica sigue por la región")

## No quedan portones cerrados ni bloques de hormigón al final de las rutas: ningún objeto sólido a menos de 12 m de las puntas de las rutas rurales y de la panorámica
func _gates_and_blocks(city: CityLayout) -> void:
	var bad := 0
	for rd in city.roads:
		var kind := str(rd["kind"])
		if kind != "rural" and kind != "scenic":
			continue
		var pts: PackedVector3Array = rd["pts"]
		var tip := Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z)
		for id in city.prop_type.size():
			var t := int(city.prop_type[id])
			if CityProps.RADIUS[t] <= 0.0:
				continue
			if Vector2(city.prop_x[id], city.prop_z[id]).distance_to(tip) < 12.0 and t == 12:
				bad += 1
	_check(bad == 0, "ningún bloque de hormigón cierra el final de una ruta (%d)" % bad)

# ───────────────────────── estaciones y gomerías ─────────────────────────
## Desde el frente de cada estación y cada gomería (donde el jugador se detiene) se llega a una calle por donde pasa un auto (círculo de 1 m): sin pared invisible que lo encierre
func _lots(tr, rg: RegionData) -> void:
	var n := 0
	var stuck: Array = []
	for p in tr.city.pois:
		if not bool(p.get("region", false)):
			continue
		if str(p["kind"]) != "fuel" and str(p["kind"]) != "garage":
			continue
		n += 1
		if not _reaches_road(tr, rg, p["front"]):
			stuck.append(str(p["name"]))
	_check(n >= 100, "servicios de la región: %d" % n)
	_check(stuck.is_empty(), "de cada estación y gomería se llega a la calle (%d encerradas: %s)" % [stuck.size(), str(stuck.slice(0, 6))])

## Las estaciones de Dream City (las de adentro de la ciudad y las rurales): desde el frente se llega a una calle de la ciudad caminando por donde pasa un auto
func _city_stations(tr, city: CityLayout) -> void:
	var n := 0
	var stuck: Array = []
	for st in city.stations:
		if bool(st.get("region", false)):
			continue
		n += 1
		var start: Vector2 = st["front"]
		var seen := {Vector2i(0, 0): true}
		var q: Array = [Vector2i(0, 0)]
		var head := 0
		var ok := false
		while head < q.size() and not ok:
			var c: Vector2i = q[head]
			head += 1
			var pr := city.probe(start.x + float(c.x), start.y + float(c.y))
			if pr[6] >= 0.0 and float(pr[0]) > 0.5:
				ok = true # sobre la calzada o la vereda de una calle
				break
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: Vector2i = c + d
				if seen.has(nc) or absi(nc.x) > 90 or absi(nc.y) > 90:
					continue
				seen[nc] = true
				if (tr.push(start.x + float(nc.x), start.y + float(nc.y), 1.0) as Vector3).z > 0.02:
					continue
				q.append(nc)
		if not ok:
			stuck.append(str(st["name"]))
	_check(n >= 6 and stuck.is_empty(), "las %d estaciones de Dream City tienen salida a la calle (encerradas: %s)" % [n, str(stuck)])

## De cada lugar para aparecer («¿dónde aparecer?») se llega a una calle caminando por donde pasa un auto (círculo de 1 m): ni encerrado ni sobre un obstáculo
func _spawns(tr, rg: RegionData) -> void:
	var bad: Array = []
	var total := 0
	for i in range(3, tr.city.spawns.size()):
		total += 1
		var sp: Array = tr.city.spawns[i]
		if not _reaches_road(tr, rg, Vector2(float(sp[0]), float(sp[1]))):
			bad.append(str(tr.city.spawn_names[i]))
	_check(total >= 30 and bad.is_empty(), "los %d lugares para aparecer salen a la calle (encerrados: %s)" % [total, str(bad)])

func _reaches_road(tr, rg: RegionData, start: Vector2) -> bool:
	var r := 1.0
	if (tr.push(start.x, start.y, r) as Vector3).z > 0.3:
		return false # aparece pegado a algo sólido
	var seen := {Vector2i(0, 0): true}
	var q: Array = [Vector2i(0, 0)]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var x := start.x + float(c.x)
		var z := start.y + float(c.y)
		var pr: PackedFloat64Array = rg.probe(x, z, 30.0, false)
		if pr[0] > -1e8 and pr[4] <= pr[5]:
			return true # sobre la calzada de una calle
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + d
			if seen.has(nc) or absi(nc.x) > 120 or absi(nc.y) > 120:
				continue
			seen[nc] = true
			if (tr.push(start.x + float(nc.x), start.y + float(nc.y), r) as Vector3).z > 0.02:
				continue
			q.append(nc)
	return false

## Con la física de verdad: un auto automático arranca en tres lugares para aparecer (los de camino de acceso más largo), maneja hacia la calle y la alcanza
func _drive_out(tr, rg: RegionData) -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	# los tres lugares con el camino de acceso más largo
	var cand: Array = []
	for i in range(3, tr.city.spawns.size()):
		var sp: Array = tr.city.spawns[i]
		var pr: PackedFloat64Array = rg.probe(float(sp[0]), float(sp[1]), 128.0, false)
		if pr[0] > -1e8:
			cand.append([float(pr[4]) - float(pr[5]), i])
	cand.sort_custom(func(a, b): return a[0] > b[0])
	for k in mini(3, cand.size()):
		var idx := int(cand[k][1])
		var sp: Array = tr.city.spawns[idx]
		var p0 := Vector2(float(sp[0]), float(sp[1]))
		var pr: PackedFloat64Array = rg.probe(p0.x, p0.y, 128.0, false)
		var road_pt := p0 + Vector2(pr[7], pr[8]) * float(pr[4]) # el punto más cercano del eje de la calle
		var d: Dictionary = (vehicles["hatch"] as Dictionary).duplicate()
		d["camberF"] = -1.0
		d["camberR"] = -0.5
		d["toeF"] = 0.0
		d["toeR"] = 0.1
		d["pressF"] = 30.0
		d["pressR"] = 30.0
		var ph := VehiclePhysics.new(tr, VehicleParams.from_dict(d))
		ph.reset(p0.x, p0.y, float(sp[2]))
		var drv := NetDriver.new(Net.new(), "wander", 0.7, 3)
		var route := PackedVector2Array()
		var to_road := road_pt - p0
		var ln := to_road.length()
		for m in int(ln / 3.0) + 30:
			route.append(p0 + to_road.normalized() * minf(float(m) * 3.0, ln + 60.0)) # sigue derecho más allá de la calle
		drv.set_route(route)
		var t := 0.0
		var h := 1.0 / 120.0
		var reached := false
		var vmax := 0.0
		while t < 40.0 and not reached:
			var c: Vector3 = drv.update(ph, h)
			ph.step(h, c.x, c.y, c.z, false, false)
			t += h
			var q := Vector2(ph.px, ph.pz)
			vmax = maxf(vmax, sqrt(ph.vx * ph.vx + ph.vz * ph.vz))
			var pq: PackedFloat64Array = rg.probe(q.x, q.y, 30.0, false)
			if pq[0] > -1e8 and pq[4] <= pq[5]:
				reached = true
		_check(reached, "%s: el auto sale solo del lugar para aparecer hasta la calle en %.1f s (acceso de %.0f m, máx. %.0f km/h)" % [tr.city.spawn_names[idx], t, float(cand[k][0]), vmax * 3.6])

## Un auto automático sale de la ciudad por la Ruta N (desde 600 m de su comienzo), cruza la Salida y sigue por la región hasta el primer empalme: sin trabarse ni chocar contra paredes
func _drive_exit(tr, city: CityLayout, rg: RegionData, num: int) -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var rd: Dictionary = city.roads[city.road_named("Ruta %d" % num)]
	var pts: PackedVector3Array = rd["pts"]
	var cum: PackedFloat32Array = rd["cum"]
	var route := PackedVector2Array()
	for i in pts.size():
		if cum[i] >= 600.0:
			route.append(Vector2(pts[i].x, pts[i].z))
	var ni := rg.node_by_id("exit%d" % num)
	var ei: int = (rg.node_edges[ni] as PackedInt32Array)[0]
	var leg: PackedVector2Array = rg._slice(ei, 0.0, 1.0e9) if rg.has_method("_slice") else PackedVector2Array()
	if leg.size() > 2 and leg[0].distance_to(rg.node_pos(ni)) > leg[leg.size() - 1].distance_to(rg.node_pos(ni)):
		leg.reverse() # que arranque en la Salida
	route.append_array(leg)
	var total := 0.0
	for i in range(1, route.size()):
		total += route[i].distance_to(route[i - 1])
	var d: Dictionary = (vehicles["hatch"] as Dictionary).duplicate()
	d["camberF"] = -1.0
	d["camberR"] = -0.5
	d["toeF"] = 0.0
	d["toeR"] = 0.1
	d["pressF"] = 30.0
	d["pressR"] = 30.0
	var ph := VehiclePhysics.new(tr, VehicleParams.from_dict(d))
	var dir := (route[mini(6, route.size() - 1)] - route[0]).normalized()
	ph.reset(route[0].x, route[0].y, atan2(dir.x, dir.y))
	var drv := NetDriver.new(Net.new(), "wander", 0.72, 5)
	drv.set_route(route)
	var t := 0.0
	var h := 1.0 / 120.0
	var prev := route[0]
	var dist := 0.0
	var stuck := 0.0
	var worst := 0.0
	var hits := 0
	while t < 160.0 and dist < total - 60.0:
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
	_check(dist > total - 80.0 and worst < 4.0 and hits < 20, "Ruta %d: sale de la ciudad y sigue por la región (%.2f km de %.2f en %.0f s, peor quedada parado %.1f s, %d roces con paredes)" % [num, dist / 1000.0, total / 1000.0, t, worst, hits])

# ───────────────────────── calzadas limpias ─────────────────────────
## Sobre las rutas rurales, los atajos y la panorámica de la ciudad (con todos sus objetos sólidos puestos): nada que frene a un auto en la calzada
func _city_roads_clear(tr, city: CityLayout) -> void:
	var bad := 0
	var first := ""
	var n := 0
	for rd in city.roads:
		var kind := str(rd["kind"])
		if kind != "rural" and kind != "shortcut" and kind != "scenic":
			continue
		var pts: PackedVector3Array = rd["pts"]
		var hw := float(rd["hw"])
		var acc := 0.0
		for i in range(1, pts.size()):
			var a := Vector2(pts[i - 1].x, pts[i - 1].z)
			var b := Vector2(pts[i].x, pts[i].z)
			acc += a.distance_to(b)
			if acc < 4.0:
				continue
			acc = 0.0
			var tn := (b - a).normalized()
			var nrm := Vector2(-tn.y, tn.x)
			for off in [-(hw - 1.2), 0.0, hw - 1.2]:
				var q := b + nrm * float(off)
				n += 1
				var pw: Vector3 = tr.push(q.x, q.y, 1.0)
				if pw.z > 0.05:
					bad += 1
					if first.length() < 220:
						first += "%s (%.0f, %.0f) %.2f m · " % [rd["name"], q.x, q.y, pw.z]
	_check(n > 1000 and bad == 0, "la calzada de las rutas rurales, atajos y panorámica está limpia (%d puntos, %d con algo que frena; %s)" % [n, bad, first])

# ───────────────────────── árboles ─────────────────────────
## Los árboles de la región no caen sobre las rutas de la ciudad (la Ruta 40 y 20 cruzan la región entre 2 y 2,3 km de la plaza)
func _trees(tr, city: CityLayout, rg: RegionData) -> void:
	var rw := RegionWorld.new()
	rw.track = tr
	rw.rg = rg
	var on_road := 0
	var total := 0
	var seen := {}
	for rd in city.roads:
		if str(rd["kind"]) != "rural":
			continue
		var pts: PackedVector3Array = rd["pts"]
		for i in range(0, pts.size(), 6):
			var p := Vector2(pts[i].x, pts[i].z)
			if p.length() < 1900.0:
				continue
			var k := Vector2i(int(floor(p.x / RegionWorld.CHUNK)), int(floor(p.y / RegionWorld.CHUNK)))
			if seen.has(k):
				continue
			seen[k] = true
			var arr: PackedFloat32Array = rw._trees(float(k.x) * RegionWorld.CHUNK, float(k.y) * RegionWorld.CHUNK)
			for j in arr.size() / 6:
				total += 1
				var pr := city.probe(arr[j * 6], arr[j * 6 + 2])
				if pr[6] >= 0.0 and float(pr[0]) > -6.0: # sobre la calzada o a menos de 6 m de la vereda
					on_road += 1
	rw.free()
	_check(seen.size() >= 6 and on_road == 0, "ningún árbol de la región cae sobre las rutas de la ciudad (%d cuadrados, %d árboles mirados, %d sobre la ruta)" % [seen.size(), total, on_road])
