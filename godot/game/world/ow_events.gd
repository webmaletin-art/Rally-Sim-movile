extends RefCounted
## Carreras del mundo abierto (docs/CARRERAS_MUNDO_ABIERTO.md): qué eventos hay, dónde largan, por dónde van y cuánto pagan. Puro y determinista (igual en todos los teléfonos):
## se arma a partir de la red de la región (RegionData) y de las calles de Dream City (CityGps), sin duplicar el mundo: cada evento es un tramo de calles que ya existen.
## Lo que pasa en la partida (descubrirlos, largar, rivales, meta, premio) está en city/city_events.gd.

const TYPES := {
	"sprint": {"icon": "🏁", "name": "Sprint", "rivals": 3, "base": 1600, "per_km": 480, "desc": "Punto A a punto B contra 3 rivales"},
	"rally": {"icon": "🌄", "name": "Rally", "rivals": 0, "base": 1900, "per_km": 600, "desc": "Contrarreloj de rally por tierra y ripio: oro, plata o bronce"},
	"montana": {"icon": "⛰", "name": "Contrarreloj de montaña", "rivals": 0, "base": 1900, "per_km": 620, "desc": "Subidas, bajadas y curvas cerradas contra el reloj"},
	"velocidad": {"icon": "⚡", "name": "Desafío de velocidad", "rivals": 0, "base": 1300, "per_km": 250, "desc": "Promedio de velocidad en la autopista: superá la marca"},
	"picada": {"icon": "🚦", "name": "Picada", "rivals": 1, "base": 1000, "per_km": 0, "desc": "400 m en recta, largada parada, contra un rival"},
	"circuito": {"icon": "🔁", "name": "Circuito urbano", "rivals": 3, "base": 2000, "per_km": 380, "desc": "Dos vueltas por las calles de Dream City contra 3 rivales"},
	"huida": {"icon": "🚨", "name": "Huida", "rivals": 0, "base": 2800, "per_km": 0, "desc": "Aguantá 90 segundos con la policía encima sin que te agarren"},
	"persecucion": {"icon": "🎯", "name": "Persecución", "rivals": 1, "base": 2300, "per_km": 260, "desc": "Alcanzá al auto que se escapa antes de que llegue a destino"},
}
## velocidad media de referencia por clase de calle (m/s) para las marcas de oro de las contrarreloj (RegionData.CLS_NAMES)
const CLS_V := [40.0, 44.0, 37.0, 33.0, 27.0, 23.0, 21.0, 17.0, 30.0]
const LEN := {"sprint": [2500.0, 5500.0], "rally": [2000.0, 4500.0], "montana": [1800.0, 4000.0], "velocidad": [1800.0, 3000.0], "persecucion": [2500.0, 5000.0]}
const CITY_R := 3600.0
const Sectors := preload("res://game/region/sectors.gd")
const HUIDA_T := 90.0

## Todos los eventos: [{id, type, name, start: Vector2, yaw, pts: PackedVector2Array (recorrido), len, laps, rivals, reward, gold, silver, bronze, speed, tier, where}]
static func build(region, city_gps = null) -> Array:
	var out: Array = []
	if region != null:
		_region_events(region, out)
	if city_gps != null:
		_city_events(city_gps, out)
	# sólo los que corren enteros por sectores abiertos (game/data/sectors.json): nada sobre una calle cortada
	var ok: Array = []
	for ev in out:
		var pts: PackedVector2Array = ev["pts"]
		var good := true
		var i := 0
		while i < pts.size():
			if not Sectors.is_open(pts[i]):
				good = false
				break
			i += 8
		if good and Sectors.is_open(pts[pts.size() - 1]):
			ok.append(ev)
	return ok

static func _region_events(region, out: Array) -> void:
	var settle: Array = []
	for ni in region.nodes.size():
		var k := int(region.nodes[ni][3])
		if k == 3 or k == 4: # ciudad, pueblo
			settle.append(ni)
	var used := {}
	# tramos de ruta que arrancan cerca de cada pueblo (los nodos del pueblo sólo tocan sus calles: las rutas salen de los cruces de las afueras)
	var near := {}
	for ei in region.edges.size():
		var e0: Array = region.edges[ei]
		var c0 := int(e0[2])
		if c0 == 7 or c0 == 0 or c0 == 8 or float(e0[8]) < 1600.0:
			continue
		for end in [int(e0[0]), int(e0[1])]:
			var ep: Vector2 = region.node_pos(end)
			for ni2 in settle:
				if (region.node_pos(ni2) as Vector2).distance_to(ep) < 1500.0:
					if not near.has(ni2):
						near[ni2] = []
					(near[ni2] as Array).append([ei, end])
	for ni in settle:
		var made := 0
		var nm := str(region.nodes[ni][4])
		for pair in near.get(ni, []):
			var ei: int = pair[0]
			if made >= 2 or used.has(ei):
				continue
			var e: Array = region.edges[ei]
			var cls := int(e[2])
			var L := float(e[8])
			var typ := "sprint"
			if int(e[5]) != 0:
				typ = "rally"
			elif cls == 6:
				typ = "montana"
			elif cls == 1:
				typ = "velocidad"
			elif made == 1 and cls in [2, 3]:
				typ = "persecucion"
			# sale del lado del pueblo, ya afuera de las casas
			var from_a: bool = int(e[0]) == int(pair[1])
			var s0 := 0.0
			while s0 < minf(700.0, L * 0.4):
				var q: Array = region.point_at(ei, s0 if from_a else L - s0)
				if not region.in_town((q[0] as Vector2).x, (q[0] as Vector2).y) and s0 >= 120.0:
					break
				s0 += 40.0
			var lr: Array = LEN.get(typ, [2500.0, 5000.0])
			var len := clampf(L - s0 - 150.0, 0.0, float(lr[1]))
			if len < float(lr[0]) * 0.7:
				continue
			var a := s0 if from_a else L - s0
			var b := a + len if from_a else a - len
			var pts: PackedVector2Array = region._dedup(region._slice(ei, a, b))
			if pts.size() < 3 or (pts[0] as Vector2).length() < CITY_R:
				continue
			used[ei] = true
			made += 1
			var ev := _make(typ, "%s_%d" % [typ, ei], "%s · %s" % [TYPES[typ]["name"], nm], pts, len, cls, nm)
			out.append(ev)
		# una picada y una huida cerca de las ciudades grandes
		if int(region.nodes[ni][3]) == 3:
			var pk := _picada(region, ni, used, near.get(ni, []))
			if not pk.is_empty():
				out.append(pk)
			var np: Vector2 = region.node_pos(ni)
			if np.length() > CITY_R:
				var rp: PackedFloat64Array = region.probe(np.x + 450.0, np.y, 300.0, false)
				if rp[0] > -1e8 and int(rp[1]) >= 0:
					var k2 := int(rp[2])
					var ra := Vector2(float(region.pts[k2 * 2]) * 0.1, float(region.pts[k2 * 2 + 1]) * 0.1)
					var rb := Vector2(float(region.pts[k2 * 2 + 2]) * 0.1, float(region.pts[k2 * 2 + 3]) * 0.1)
					var hv := _make("huida", "huida_%d" % ni, "%s · %s" % [TYPES["huida"]["name"], nm], PackedVector2Array([ra, rb]), 0.0, 2, nm)
					out.append(hv)

## Picada: 450 m casi rectos (menos de 2,5 m de desvío) sobre una ruta ancha cerca de la ciudad
static func _picada(region, ni: int, used: Dictionary, cand: Array) -> Dictionary:
	for pr in cand:
		var ei: int = pr[0]
		if used.has(ei):
			continue
		var e: Array = region.edges[ei]
		if not (int(e[2]) in [1, 2, 3]) or int(e[5]) != 0 or float(e[8]) < 1400.0:
			continue
		var L := float(e[8])
		var s := 300.0
		while s + 460.0 < L - 200.0:
			var p0: Vector2 = region.point_at(ei, s)[0]
			var p1: Vector2 = region.point_at(ei, s + 450.0)[0]
			var dv := (p1 - p0).normalized()
			var ok: bool = not region.in_town(p0.x, p0.y)
			var m := 30.0
			while ok and m < 450.0:
				var q: Vector2 = region.point_at(ei, s + m)[0]
				var off := absf((q - p0).cross(dv))
				if off > 2.5:
					ok = false
				m += 30.0
			if ok:
				used[ei] = true
				var nm := str(region.nodes[ni][4])
				return _make("picada", "picada_%d" % ei, "%s · %s" % [TYPES["picada"]["name"], nm], PackedVector2Array([p0, p0 + dv * 400.0]), 400.0, int(e[2]), nm)
			s += 120.0
	return {}

## Dream City: tres circuitos de dos vueltas por las calles (puntos fijos alrededor de la plaza, el recorrido lo da el GPS de la ciudad)
const CIRCUITS := [
	["Circuito Centro", [Vector2(0.0, -185.0), Vector2(208.0, -15.0), Vector2(-10.0, 177.0), Vector2(-142.0, -105.0)]],
	["Circuito del Puerto", [Vector2(104.0, -135.0), Vector2(193.0, 215.0), Vector2(-101.0, 137.0)]],
	["Circuito Norte", [Vector2(12.0, -560.0), Vector2(-381.0, -420.0), Vector2(-142.0, -105.0), Vector2(8.0, -185.0)]],
]

static func _city_events(gps, out: Array) -> void:
	for ci in CIRCUITS.size():
		var wp: Array = CIRCUITS[ci][1]
		var pts := PackedVector2Array()
		var total := 0.0
		var ok := true
		for k in wp.size():
			var r: Dictionary = gps.route(wp[k], wp[(k + 1) % wp.size()])
			var seg: PackedVector2Array = r.get("pts", PackedVector2Array())
			if seg.size() < 2:
				ok = false
				break
			if not pts.is_empty():
				seg = seg.slice(1)
			pts.append_array(seg)
			total += float(r.get("len", 0.0))
		if not ok or total < 600.0:
			continue
		var ev := _make("circuito", "circuito_%d" % ci, str(CIRCUITS[ci][0]), pts, total * 2.0, 7, "Dream City")
		ev["laps"] = 2
		ev["lap_len"] = total
		out.append(ev)

static func _make(typ: String, id: String, name: String, pts: PackedVector2Array, len: float, cls: int, where: String) -> Dictionary:
	var t: Dictionary = TYPES[typ]
	var d := (pts[1] - pts[0]).normalized() if pts.size() > 1 else Vector2(0, 1)
	var far: float = (pts[0] as Vector2).length()
	var tier := clampf((far - CITY_R) / 30000.0, 0.0, 1.0) # más lejos de Dream City, más difícil y mejor pago
	var reward := int(round((float(t["base"]) + float(t["per_km"]) * len / 1000.0) * (1.0 + 0.6 * tier) / 50.0) * 50.0)
	var ev := {"id": id, "type": typ, "name": name, "icon": str(t["icon"]), "desc": str(t["desc"]), "start": pts[0], "yaw": atan2(d.x, d.y), "pts": pts, "len": len,
		"laps": 1, "rivals": int(t["rivals"]), "reward": reward, "tier": tier, "where": where}
	var v: float = CLS_V[clampi(cls, 0, CLS_V.size() - 1)] * (0.92 + 0.12 * tier)
	if typ in ["rally", "montana"]:
		ev["gold"] = len / v
		ev["silver"] = ev["gold"] * 1.12
		ev["bronze"] = ev["gold"] * 1.26
	elif typ == "velocidad":
		ev["speed"] = [v * 1.18, v * 1.08, v * 0.98] # oro, plata, bronce (promedio en m/s)
	elif typ == "huida":
		ev["time"] = HUIDA_T
	return ev
