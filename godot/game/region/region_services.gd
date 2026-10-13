extends RefCounted
## Los servicios de la región (gasolineras, gomerías, peajes y lugares para aparecer) se anotan en la ciudad (city.stations / pois / tolls / spawns) para que los módulos de Dream City
## (nafta, locales, peajes, mapa, GPS) los traten igual que a los de la ciudad. Cada uno lleva `region: true`: CityWorld no los dibuja (los dibuja RegionWorld al armar su cuadrado).

const CityLayout := preload("res://game/city/city_layout.gd")
const RegionData := preload("res://game/region/region_data.gd")

const STATION_COL := [Color(0.95, 0.72, 0.10), Color(0.88, 0.20, 0.15), Color(0.20, 0.68, 0.36), Color(0.16, 0.52, 0.86), Color(0.92, 0.45, 0.12), Color(0.55, 0.30, 0.78)]
const SPAWNS_FILE := "res://game/data/region/spawns.json"
const MAP_RECT := Rect2(-60000.0, -90000.0, 120000.0, 93000.0) # lo que cubre region_map.png (mismo recorte que la grilla del generador)

const DRIVE_R := 5.0 # radio de los discos del camino de acceso (10 m de ancho de pavimento)
const DRIVE_STEP := 3.0 # separación entre discos (se pisan: sin muescas)
const LOT_GAP := 3.0 # un playón de servicio no puede quedar sobre una calle: si cae encima se lo corre hasta dejar este hueco entre su borde y la banquina

## ¿Está la región completa en esta compilación? (los datos de las rutas y la lista de lugares para aparecer; si falta algo no se ofrece)
static func available() -> bool:
	return FileAccess.file_exists(RegionData.FILE) and FileAccess.file_exists(SPAWNS_FILE)

static func spawn_list() -> Array:
	if not FileAccess.file_exists(SPAWNS_FILE):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SPAWNS_FILE))
	return d if d is Array else []

## Hueco (m) entre el borde de los círculos de un playón (radio r) y la banquina de la calle más cercana a cualquiera de ellos: [hueco, índice del círculo, resultado de RegionData.probe]
## (hueco < 0: el playón pisa la calle; el índice es −1 si no hay ninguna calle a la vista)
static func _lot_gap(rg: RegionData, circles: Array, r: float) -> Array:
	var best_gap := 1e9
	var best_i := -1
	var best_pr := PackedFloat64Array()
	for i in circles.size():
		var c: Vector2 = circles[i]
		var pr: PackedFloat64Array = rg.probe(c.x, c.y, 128.0, false)
		if pr[0] < -1e8:
			continue
		var g: float = pr[4] - pr[5] - RegionData.SHOULDER - r
		if g < best_gap:
			best_gap = g
			best_i = i
			best_pr = pr
	return [best_gap, best_i, best_pr]

## Un playón que pisa una calle (las estaciones se anotaron sobre el eje recto del pueblo, no sobre el camino de verdad) se corre hacia el lado contrario hasta que quede a LOT_GAP de la banquina
static func _clear_of_roads(rg: RegionData, pos: Vector2, offs: Array, r: float) -> Vector2:
	var p := pos
	for it in 10:
		var cs: Array = []
		for o in offs:
			cs.append(p + (o as Vector2))
		var gp := _lot_gap(rg, cs, r)
		if int(gp[1]) < 0 or float(gp[0]) >= 0.0:
			break
		var pr: PackedFloat64Array = gp[2]
		p += -Vector2(pr[7], pr[8]) * (LOT_GAP - float(gp[0]) + 0.5)
	return p

## Camino de acceso: discos de pavimento que se pisan, desde adentro del playón hasta la calle más cercana (el borde del último toca el asfalto). Sin esto el playón queda rodeado de pasto y de pared invisible.
## Devuelve [dirección unitaria hacia la calle, altura de la calle en el empalme, metros de camino]; dirección cero si no hay calle a la vista.
static func _driveway(rg: RegionData, circles: Array, r: float, h: float) -> Array:
	var gp := _lot_gap(rg, circles, r)
	if int(gp[1]) < 0:
		return [Vector2.ZERO, h, 0.0]
	var pr: PackedFloat64Array = gp[2]
	var c0: Vector2 = circles[int(gp[1])]
	var u := Vector2(pr[7], pr[8])
	var hw: float = pr[5]
	var hr: float = pr[6]
	var t0 := r - 1.5 # el primer disco queda adentro del playón
	var t1 := float(pr[4]) - (hw + DRIVE_R - 0.1) # el último toca el borde del asfalto
	var L := t1 - t0
	if L > 0.2:
		var n := int(ceil(L / DRIVE_STEP))
		for i in n + 1:
			var f := float(i) / float(n)
			var c := c0 + u * (t0 + L * f)
			rg.add_pad(c.x, c.y, DRIVE_R, lerpf(h, hr, f))
	return [u, hr, maxf(L, 0.0)]

static func install(city, rg: RegionData) -> void:
	var n_fuel := 0
	var n_shop := 0
	var sps: Array = spawn_list() # lugares para aparecer: cada estación de servicio de una ciudad o pueblo (si se corrió la estación, el lugar la sigue)
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
			var old_spawn := pos - nrm * 3.0 # donde el generador puso el lugar para aparecer de esta estación
			var offs: Array = []
			for u in kd["cu"]:
				offs.append(lx * float(u))
			pos = _clear_of_roads(rg, pos, offs, R)
			poi["x"] = pos.x
			poi["z"] = pos.y
			var wpos := func(u: float, v: float) -> Vector2: return pos + lx * u + nrm * v
			var circles: Array = []
			for u in kd["cu"]:
				circles.append(wpos.call(float(u), 0.0))
			var dw := _driveway(rg, circles, R, h)
			h = float(dw[1]) # el playón queda a la altura de la calle donde empalma el acceso
			poi["h"] = h
			for c in circles:
				rg.add_pad((c as Vector2).x, (c as Vector2).y, R, h)
			for sp in sps:
				if Vector2(float(sp["x"]), float(sp["z"])).distance_to(old_spawn) < 1.0 and not sp.has("_fixed"):
					var du: Vector2 = dw[0]
					var q := pos - nrm * 3.0
					var yw := yaw
					if du != Vector2.ZERO:
						q = pos + du * 3.0 # se aparece mirando hacia la salida
						yw = atan2(du.x, du.y)
					sp["x"] = q.x
					sp["z"] = q.y
					sp["yaw"] = yw
					sp["_fixed"] = true
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
			pos = _clear_of_roads(rg, pos, [Vector2.ZERO], 14.0)
			poi["x"] = pos.x
			poi["z"] = pos.y
			var dw2 := _driveway(rg, [pos], 14.0, h)
			h = float(dw2[1])
			poi["h"] = h
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
	for sp in sps:
		city.spawns.append([float(sp["x"]), float(sp["z"]), float(sp["yaw"])])
		city.spawn_names.append(str(sp["name"]))
