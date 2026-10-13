## Calidad del mapa de la región tras los retoques (tools/world_gen/polish_map.py): cruces parejos (el auto no salta), subidas con pendiente progresiva (sin «dobleces»), ningún cruce de calles sin nodo
## (salvo los pocos pegados a otro cruce), los ramales a los pueblos que quedaban lejos de la ruta principal y curvas abiertas en las rutas que eran rectas.
## Uso: godot --headless --path godot --script res://tests/region_polish_test.gd
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const RegionData := preload("res://game/region/region_data.gd")

const GRADE := {"anillo": 0.05, "autopista": 0.055, "ruta": 0.07, "provincial": 0.085, "camino": 0.10, "tierra": 0.11, "montana": 0.115, "calle": 0.08, "conector": 0.07}
const BRANCH_TOWNS := ["San Isidro Sur", "Los Molles", "Villa Cóndor", "Bahía Ámbar", "Cerro Verde", "Puerto Chico", "Pampa Seca", "La Candelaria", "Punta Aguada", "Monte Viejo"]

var fail := false
var rg: RegionData

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var city := CityLayout.new()
	city.build()
	rg = RegionData.new()
	_check(rg.load_file(city), "carga region_1.bin")
	_junction_heights()
	_grades()
	_crossings()
	_branches()
	_bends()
	print("REGION_POLISH_TEST ", "FALLÓ" if fail else "OK")
	quit(1 if fail else 0)

## altura de la calle ei a `s` metros del extremo (inicio si start, fin si no)
func _h_at_end(ei: int, start: bool, s: float) -> float:
	var e: Array = rg.edges[ei]
	var p0 := int(e[6])
	var n := int(e[7])
	var acc := 0.0
	var prev := p0 if start else p0 + n - 1
	var step := 1 if start else -1
	var k := prev
	while k + step >= p0 and k + step < p0 + n:
		var a := Vector2(rg.pts[2 * k], rg.pts[2 * k + 1]) * 0.1
		var b := Vector2(rg.pts[2 * (k + step)], rg.pts[2 * (k + step) + 1]) * 0.1
		var d := a.distance_to(b)
		if acc + d >= s:
			var t := (s - acc) / maxf(d, 1e-6)
			return lerpf(rg.hs[k], rg.hs[k + step], t)
		acc += d
		k += step
	return rg.hs[k]

## en cada cruce (3 o más calles) las calles llegan a la misma altura: el auto no salta al cruzar
func _junction_heights() -> void:
	var worst := 0.0
	var n_junc := 0
	var over20 := 0
	var worst_at := ""
	for ni in rg.nodes.size():
		var eds: PackedInt32Array = rg.node_edges[ni]
		if eds.size() < 3:
			continue
		n_junc += 1
		var lo := 1e9
		var hi := -1e9
		for ei in eds:
			var e: Array = rg.edges[ei]
			var h := _h_at_end(ei, int(e[0]) == ni, 8.0)
			lo = minf(lo, h)
			hi = maxf(hi, h)
		var d := hi - lo
		if d > 0.2:
			over20 += 1
		if d > worst:
			worst = d
			worst_at = str(rg.nodes[ni][0])
	_check(n_junc > 1000 and worst <= 0.8 and over20 <= 3, "cruces parejos: %d cruces, diferencia máxima de altura a 8 m del nodo %.2f m (en %s), con más de 20 cm: %d" % [n_junc, worst, worst_at, over20])

## pendiente máxima por clase y «dobleces» (cambios bruscos de pendiente entre puntos seguidos)
func _grades() -> void:
	var over := {}
	var kinks := PackedFloat64Array()
	for ei in rg.edges.size():
		var e: Array = rg.edges[ei]
		var cls := str(rg.CLS_NAMES[int(e[2])])
		var p0 := int(e[6])
		var n := int(e[7])
		var prev_g := 0.0
		var have := false
		for k in range(p0, p0 + n - 1):
			var a := Vector2(rg.pts[2 * k], rg.pts[2 * k + 1]) * 0.1
			var b := Vector2(rg.pts[2 * (k + 1)], rg.pts[2 * (k + 1) + 1]) * 0.1
			var d := a.distance_to(b)
			if d < 6.0:
				continue
			var g := (rg.hs[k + 1] - rg.hs[k]) / d
			if absf(g) > float(GRADE[cls]) + 0.025:
				over[cls] = int(over.get(cls, 0)) + 1
			if have:
				kinks.append(absf(g - prev_g))
			prev_g = g
			have = true
	kinks.sort()
	var p99 := kinks[int(float(kinks.size()) * 0.99)]
	_check(over.is_empty(), "ninguna subida pasa la pendiente de su clase (con 2,5 puntos de margen): %s" % str(over))
	_check(p99 <= 0.07 and kinks[kinks.size() - 1] <= 0.16, "subidas progresivas: el cambio de pendiente entre puntos seguidos es de a lo sumo %.3f (p99 %.3f)" % [kinks[kinks.size() - 1], p99])

## Dónde se cruzan los segmentos p→q y r→s: [punto, t, u] (t y u: qué tanto del trecho de cada uno) o null
func _seg_cross(p: Vector2, q: Vector2, r: Vector2, s: Vector2) -> Variant:
	var d1 := q - p
	var d2 := s - r
	var den := d1.x * d2.y - d1.y * d2.x
	if absf(den) < 1e-9:
		return null
	var t := ((r.x - p.x) * d2.y - (r.y - p.y) * d2.x) / den
	var u := ((r.x - p.x) * d1.y - (r.y - p.y) * d1.x) / den
	if t > 1e-6 and t < 1.0 - 1e-6 and u > 1e-6 and u < 1.0 - 1e-6:
		return [p + d1 * t, t, u]
	return null

## ningún par de calles se cruza sin tener un nodo en común a menos de 45 m del cruce, salvo unos pocos pegados a otro cruce (que de todos modos quedan a la misma altura: el auto no salta)
func _crossings() -> void:
	var seen := {}
	var bad: Array = []
	var worst_dh := 0.0
	for key in rg.cells:
		var lst: PackedInt32Array = rg.cells[key]
		for ii in lst.size():
			var i := int(lst[ii])
			var ei := int(rg.pe[i])
			var a := Vector2(rg.pts[2 * i], rg.pts[2 * i + 1]) * 0.1
			var b := Vector2(rg.pts[2 * (i + 1)], rg.pts[2 * (i + 1) + 1]) * 0.1
			if i + 1 >= rg.pe.size() or int(rg.pe[i + 1]) != ei or a.distance_to(b) < 1e-3:
				continue
			for jj in range(ii + 1, lst.size()):
				var j := int(lst[jj])
				var ej := int(rg.pe[j])
				if ej == ei or j + 1 >= rg.pe.size() or int(rg.pe[j + 1]) != ej:
					continue
				var pair := Vector2i(mini(i, j), maxi(i, j))
				if seen.has(pair):
					continue
				seen[pair] = true
				var c := Vector2(rg.pts[2 * j], rg.pts[2 * j + 1]) * 0.1
				var d := Vector2(rg.pts[2 * (j + 1)], rg.pts[2 * (j + 1) + 1]) * 0.1
				var hit: Variant = _seg_cross(a, b, c, d)
				if hit == null:
					continue
				var x: Vector2 = (hit as Array)[0]
				var ea: Array = rg.edges[ei]
				var eb: Array = rg.edges[ej]
				var ok := false
				for na in [int(ea[0]), int(ea[1])]:
					for nb in [int(eb[0]), int(eb[1])]:
						if na == nb and rg.node_pos(na).distance_to(x) < 45.0:
							ok = true
				if not ok:
					var ha := lerpf(rg.hs[i], rg.hs[i + 1], float((hit as Array)[1]))
					var hb := lerpf(rg.hs[j], rg.hs[j + 1], float((hit as Array)[2]))
					worst_dh = maxf(worst_dh, absf(ha - hb))
					bad.append("%s(%d,%s)×%s(%d,%s) en (%.0f, %.0f) a %.2f m de diferencia" % [str(ea[3]), ei, str(rg.CLS_NAMES[int(ea[2])]), str(eb[3]), ej, str(rg.CLS_NAMES[int(eb[2])]), x.x, x.y, absf(ha - hb)])
	_check(bad.size() <= 6 and worst_dh <= 0.2, "cruces de calles sin nodo: %d (hasta 6, pegados a otro cruce) y la diferencia de altura entre las dos calles es de a lo sumo %.2f m %s" % [bad.size(), worst_dh, str(bad.slice(0, 20))])

## los 10 pueblos que quedaban lejos de la ruta principal tienen su ramal (RP-84 a RP-93) y se llega a ellos desde la circunvalación
func _branches() -> void:
	var names := {}
	for i in rg.nodes.size():
		names[str(rg.nodes[i][4])] = i
	var ring := rg.node_by_id("ring0")
	var rp := {}
	for ei in rg.edges.size():
		var nm := str((rg.edges[ei] as Array)[3])
		if nm.begins_with("RP-") and int(nm.substr(3)) >= 84 and int(nm.substr(3)) <= 93:
			rp[nm] = float(rp.get(nm, 0.0)) + float((rg.edges[ei] as Array)[8])
	_check(rp.size() == 10, "los 10 ramales RP-84 a RP-93 existen (%d)" % rp.size())
	var short_ok := true
	for k in rp:
		if float(rp[k]) < 800.0 or float(rp[k]) > 13000.0:
			short_ok = false
	_check(short_ok, "cada ramal mide entre 0,8 y 13 km")
	var unreachable: Array = []
	for t in BRANCH_TOWNS:
		if not names.has(t):
			unreachable.append(t + " (no existe)")
			continue
		var r: Dictionary = rg.route(rg.node_pos(ring), rg.node_pos(int(names[t])))
		if r.is_empty() or (r.get("pts", PackedVector2Array()) as PackedVector2Array).size() < 2:
			unreachable.append(t)
	_check(unreachable.is_empty(), "se llega a los 10 pueblos desde la circunvalación (sin ruta: %s)" % str(unreachable))

## curvas abiertas: la mayoría de las rutas largas ya no son rectas (la desviación respecto de la cuerda es de decenas de metros)
func _bends() -> void:
	var long_n := 0
	var bent_n := 0
	for ei in rg.edges.size():
		var e: Array = rg.edges[ei]
		var cls := str(rg.CLS_NAMES[int(e[2])])
		if not ["autopista", "ruta", "provincial", "camino"].has(cls) or float(e[8]) < 3000.0:
			continue
		long_n += 1
		var p0 := int(e[6])
		var n := int(e[7])
		var a := Vector2(rg.pts[2 * p0], rg.pts[2 * p0 + 1]) * 0.1
		var b := Vector2(rg.pts[2 * (p0 + n - 1)], rg.pts[2 * (p0 + n - 1) + 1]) * 0.1
		var ab := b - a
		var L := ab.length()
		if L < 1.0:
			continue
		var maxdev := 0.0
		for k in range(p0, p0 + n):
			var p := Vector2(rg.pts[2 * k], rg.pts[2 * k + 1]) * 0.1
			maxdev = maxf(maxdev, absf((p - a).cross(ab)) / L)
		if maxdev > 25.0:
			bent_n += 1
	_check(long_n > 20 and float(bent_n) / float(long_n) >= 0.6, "curvas abiertas: %d de %d rutas largas se apartan más de 25 m de la recta" % [bent_n, long_n])
