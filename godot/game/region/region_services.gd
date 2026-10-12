extends RefCounted
## Los servicios de la región (gasolineras, gomerías, peajes y lugares para aparecer) se anotan en la ciudad (city.stations / pois / tolls / spawns) para que los módulos de Dream City
## (nafta, locales, peajes, mapa, GPS) los traten igual que a los de la ciudad. Cada uno lleva `region: true`: CityWorld no los dibuja (los dibuja RegionWorld al armar su cuadrado).

const CityLayout := preload("res://game/city/city_layout.gd")
const RegionData := preload("res://game/region/region_data.gd")

const STATION_COL := [Color(0.95, 0.72, 0.10), Color(0.88, 0.20, 0.15), Color(0.20, 0.68, 0.36), Color(0.16, 0.52, 0.86), Color(0.92, 0.45, 0.12), Color(0.55, 0.30, 0.78)]
const SPAWNS_FILE := "res://game/data/region/spawns.json"
const MAP_RECT := Rect2(-60000.0, -90000.0, 120000.0, 93000.0) # lo que cubre region_map.png (mismo recorte que la grilla del generador)

## ¿Está la región completa en esta compilación? (los datos de las rutas y la lista de lugares para aparecer; si falta algo no se ofrece)
static func available() -> bool:
	return FileAccess.file_exists(RegionData.FILE) and FileAccess.file_exists(SPAWNS_FILE)

static func spawn_list() -> Array:
	if not FileAccess.file_exists(SPAWNS_FILE):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPAWNS_FILE))
	return d if d is Array else []

static func install(city, rg: RegionData) -> void:
	var n_fuel := 0
	var n_shop := 0
	for poi in rg.pois:
		var kind := str(poi["kind"])
		var pos := Vector2(float(poi["x"]), float(poi["z"]))
		var yaw := float(poi["yaw"])
		var tn := Vector2(sin(yaw), cos(yaw))
		var side := float(poi["side"])
		var nrm := Vector2(-tn.y, tn.x) * side
		var lx := Vector2(nrm.y, -nrm.x)
		var h := float(poi["h"])
		if kind == "fuel":
			var size := str(poi["size"])
			var kd: Dictionary = CityLayout.STATION_KINDS[size]
			var R := float(kd["R"])
			var wpos := func(u: float, v: float) -> Vector2: return pos + lx * u + nrm * v
			var circles: Array = []
			for u in kd["cu"]:
				var c: Vector2 = wpos.call(float(u), 0.0)
				circles.append(c)
				rg.add_pad(c.x, c.y, R, h)
			var pumps: Array = []
			for pp in kd["pumps"]:
				pumps.append(wpos.call(float(pp[0]), float(pp[1])))
			var bays: Array = []
			for bp in kd["bays"]:
				bays.append(wpos.call(float(bp[0]), float(bp[1])))
			var pillars: Array = []
			for pl in kd["pillars"]:
				pillars.append(wpos.call(float(pl[0]), float(pl[1])))
			var blocks: Array = []
			for bl in kd["blocks"]:
				blocks.append(wpos.call(float(bl[0]), float(bl[1])))
			var col: Color = STATION_COL[n_fuel % STATION_COL.size()]
			var id := "rfuel_%d" % n_fuel
			var front := pos - nrm * 6.0
			var st := {"id": id, "name": str(poi["name"]), "center": pos, "yaw": yaw, "dir": nrm, "tn": tn, "lx": lx, "color": col, "kind": size, "fast": false, "rural": true,
				"fuel_points": bays, "pumps": pumps, "pillars": pillars, "blocks": blocks, "circles": circles, "r": R, "front": front, "region": true}
			city.stations.append(st)
			city.pois.append({"id": id, "kind": "fuel", "name": str(poi["name"]), "pos": pos, "yaw": yaw, "size": Vector2(2, 2), "color": col, "y": h, "road": -1, "front": front, "shop": "",
				"door": pos, "dir": nrm, "road_yaw": yaw, "region": true})
			poi["_id"] = id
			n_fuel += 1
		elif kind == "tires":
			rg.add_pad(pos.x, pos.y, 14.0, h)
			var id2 := "rgomeria_%d" % n_shop
			var front2 := pos - nrm * 3.0
			city.pois.append({"id": id2, "kind": "garage", "name": str(poi["name"]), "pos": pos, "yaw": yaw, "size": Vector2(14, 8), "color": Color(0.95, 0.80, 0.20), "y": h, "road": -1, "front": front2,
				"shop": "wheels", "door": pos + nrm * 5.0, "dir": nrm, "road_yaw": yaw, "region": true})
			poi["_id"] = id2
			n_shop += 1
	# peajes
	for i in rg.tolls.size():
		var t: Dictionary = rg.tolls[i]
		var tpos := Vector2(float(t["x"]), float(t["z"]))
		var ttn := Vector2(float(t["tx"]), float(t["tz"]))
		var price := int(round(float(CityLayout.TOLL_PRICE) * float(t["price_k"])))
		var td := {"id": "rpeaje_%d" % i, "name": str(t["name"]), "pos": tpos, "tn": ttn, "nrm": Vector2(-ttn.y, ttn.x), "hw": float(t["hw"]), "road": -1, "price": price, "region": true}
		city.tolls.append(td)
		t["_id"] = td["id"]
	# la entrada a la Aventura: la Salida 20 ya no cierra la ruta; el portón está al final de un desvío corto de la Ruta 20
	var avn := rg.node_by_id("aventura")
	if avn >= 0:
		for ei in rg.node_edges[avn]:
			var e: Array = rg.edges[ei]
			var n := rg.edge_n(ei)
			var last := rg.edge_point(ei, n - 1) if int(e[1]) == avn else rg.edge_point(ei, 0)
			var prev := rg.edge_point(ei, n - 3) if int(e[1]) == avn else rg.edge_point(ei, 2)
			var dv := last - prev
			for ex in city.exits:
				if int(ex["num"]) == 20:
					ex["pos"] = rg.node_pos(avn)
					ex["yaw"] = atan2(dv.x, dv.y)
			break
	# lugares para aparecer: después de los tres estacionamientos
	for sp in spawn_list():
		city.spawns.append([float(sp["x"]), float(sp["z"]), float(sp["yaw"])])
		city.spawn_names.append(str(sp["name"]))
