## Los cruces de la región son parejos: las rutas que llegan a un cruce están a la misma altura (el auto no salta al cruzar) y las pendientes de las rutas respetan el máximo de su clase.
## Antes (topo.compute_heights) quedaban escalones de hasta 18 m a pocos metros de 242 cruces y subidas de más del 30 % pegadas a los nodos; ahora las alturas salen de tools/world_gen/fix_heights.py.
## Uso: godot --headless --path godot --script res://tests/region_junction_test.gd
extends SceneTree

const CityTrack := preload("res://game/track/city_track.gd")
const RegionData := preload("res://game/region/region_data.gd")

# pendiente máxima por clase (network.CLS) con un 8 % de tolerancia por la interpolación entre puntos
const GRADE := {"anillo": 0.05, "autopista": 0.055, "ruta": 0.07, "provincial": 0.085, "camino": 0.10, "tierra": 0.11, "montana": 0.115, "calle": 0.08, "conector": 0.07}

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var tr := CityTrack.new()
	var rg: RegionData = tr.region
	_check(rg != null, "la región cargó")
	# ── pendientes por clase: ninguna ruta pasa de su máximo (puntos repetidos de los nodos aparte)
	var worst := {}
	var over := 0
	var n_seg := 0
	for ei in rg.edges.size():
		var e: Array = rg.edges[ei]
		var cls := str(rg.CLS_NAMES[int(e[2])])
		var n: int = rg.edge_n(ei)
		var p0 := int(e[6])
		for i in range(n - 1):
			var a := rg.edge_point(ei, i)
			var b := rg.edge_point(ei, i + 1)
			var d := a.distance_to(b)
			if d < 1.0:
				continue
			n_seg += 1
			var gr := absf(rg.hs[p0 + i + 1] - rg.hs[p0 + i]) / d
			if gr > float(worst.get(cls, 0.0)):
				worst[cls] = gr
			if gr > float(GRADE[cls]) * 1.08:
				over += 1
	print("     pendiente máxima por clase: ", worst)
	_check(over == 0, "ningún tramo pasa de la pendiente de su clase (%d de %d tramos)" % [over, n_seg])
	# ── cruces: alrededor de cada nodo con 3 o más rutas el piso es parejo y todas llegan a la altura del nodo
	var bad_nodes: Array = []
	var jump_nodes: Array = []
	var checked := 0
	var max_jump := 0.0
	for ni in range(0, rg.nodes.size(), 3): # un nodo de cada tres (alcanza y la prueba dura segundos)
		var edges: PackedInt32Array = rg.node_edges[ni]
		if edges.size() < 3:
			continue
		var kind := str(rg.KIND_NAMES[int((rg.nodes[ni] as Array)[3])])
		if kind in ["dream", "ciudad_salida", "ciudad"]:
			continue
		var c := rg.node_pos(ni)
		var hn := float((rg.nodes[ni] as Array)[5])
		checked += 1
		var worst_dh := 0.0
		# a lo largo de cada ruta que llega: la altura del piso a 3, 6, 9 y 12 m del nodo tiene que ser la del nodo (±0,3 m)
		for ei in edges:
			var e2: Array = rg.edges[ei]
			var at_a := int(e2[0]) == ni
			var n2: int = rg.edge_n(ei)
			var total: float = rg.edge_cum(ei)[n2 - 1]
			for dist in [3.0, 6.0, 9.0, 12.0]:
				var s: float = dist if at_a else total - float(dist)
				var q: Vector2 = rg.point_at(ei, s)[0]
				var g := rg.ground(q.x, q.y)
				worst_dh = maxf(worst_dh, absf(g.x - hn))
		if worst_dh > 0.3:
			bad_nodes.append("%s (%.0f, %.0f) dif. %.2f m" % [str((rg.nodes[ni] as Array)[0]), c.x, c.y, worst_dh])
		# caminando en línea recta por el centro del cruce (hacia las 4 direcciones) el piso no tiene escalones: entre dos puntos a 0,5 m no hay más de 0,15 m de diferencia
		for ang in [0.0, 45.0, 90.0, 135.0]:
			var dir := Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang)))
			var prev := NAN
			for k in range(0, 57):
				var q2 := c + dir * (-14.0 + float(k) * 0.5)
				var pr := rg.probe(q2.x, q2.y, 30.0, false)
				if pr[0] < -1e8 or pr[4] > pr[5]:
					prev = NAN # afuera de la calzada (el terreno entre calles no importa: no se maneja ahí)
					continue
				var h2 := rg.ground(q2.x, q2.y).x
				if not is_nan(prev):
					var jump := absf(h2 - prev)
					max_jump = maxf(max_jump, jump)
					if jump > 0.15:
						jump_nodes.append("%s (%.0f, %.0f) escalón %.2f m" % [str((rg.nodes[ni] as Array)[0]), c.x, c.y, jump])
						break
				prev = h2
	_check(checked >= 200, "cruces revisados: %d" % checked)
	_check(bad_nodes.size() <= int(checked * 0.01), "en %d de %d cruces las rutas llegan a la altura del nodo (±0,3 m a 3–12 m); fuera de eso: %s" % [checked - bad_nodes.size(), checked, str(bad_nodes.slice(0, 5))])
	_check(jump_nodes.size() <= int(checked * 0.01), "caminando por la calzada de los cruces no hay escalones (peor %.2f m; %d cruces con escalón: %s)" % [max_jump, jump_nodes.size(), str(jump_nodes.slice(0, 5))])
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
