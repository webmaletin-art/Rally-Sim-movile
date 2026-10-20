## Calles cerradas en las carreras del mundo abierto ([B] 19/10/2026) y largadas lejos de talleres: arma Dream City y la región, y comprueba
##  · ninguna largada a menos de 100 m de un taller, concesionario, estación, gomería o peaje;
##  · en cada circuito de la ciudad hay vallas, ninguna sobre el recorrido, y desde el recorrido no se puede salir por las calles (una inundación por la red de calles que
##    se frena en las vallas no llega a más de ~25 m del recorrido);
##  · en las carreras de la región también hay vallas en los cruces y ninguna sobre el recorrido.
## Uso: tools/test/run_test.sh street_closure_test 120
extends SceneTree

const CL := preload("res://game/city/city_layout.gd")
const CG := preload("res://game/city/city_gps.gd")
const RD := preload("res://game/region/region_data.gd")
const OW := preload("res://game/world/ow_events.gd")
const SC := preload("res://game/city/street_closure.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var cl := CL.new()
	cl.build()
	var rg := RD.new()
	rg.load_file(cl)
	var gps := CG.new(cl)
	var evs: Array = OW.build(rg, gps)
	_check(evs.size() >= 70, "hay %d carreras" % evs.size())
	# 1) largadas lejos de los lugares
	var pads: Array = OW._pads(rg, gps)
	var worst := 1e9
	for e in evs:
		if str(e["type"]) in ["huida", "picada"]:
			continue
		worst = minf(worst, OW._pad_dist(e["start"], pads))
	_check(worst >= OW.PAD_MIN_D - 0.5, "ninguna largada a menos de %d m de un taller, concesionario, estación, gomería o peaje (la más cercana: %.0f m)" % [int(OW.PAD_MIN_D), worst])
	# 2) circuitos de la ciudad: vallas y sin escape
	var t0 := Time.get_ticks_msec()
	for e in evs:
		if str(e["type"]) != "circuito":
			continue
		var pts: PackedVector2Array = e["pts"]
		var grid := SC.grid_of(pts)
		var ex: Array = SC.exits_for(gps, rg, pts)
		_check(ex.size() >= 3 and ex.size() <= SC.MAX_FENCES, "%s: %d bocas de calle cerradas" % [e["name"], ex.size()])
		_check(_spurs(pts) == 0 and (pts[0] as Vector2).distance_to(pts[pts.size() - 1]) < 12.0, "%s: el recorrido es un lazo limpio, sin púas (ir y volver por la misma calle): %d puntos pasan dos veces por el mismo lugar" % [e["name"], _spurs(pts)])
		var on := 0
		for f in ex:
			if SC.dist_to(grid, pts, f["p"]) < SC.FAR_D - 0.5:
				on += 1
		_check(on == 0, "%s: ninguna valla sobre el recorrido ni a menos de %d m" % [e["name"], int(SC.FAR_D)])
		var reached := _flood(gps, pts, grid, ex)
		_check(reached < 30.0, "%s: no se puede salir del recorrido por las calles (lo más lejos que se llega: %.0f m)" % [e["name"], reached])
	# 3) región: vallas en los cruces
	var with := 0
	var bad := 0
	for e in evs:
		if str(e["type"]) in ["circuito", "huida", "picada"]:
			continue
		var pts2: PackedVector2Array = e["pts"]
		var grid2 := SC.grid_of(pts2)
		var ex2: Array = SC.exits_for(null, rg, pts2)
		if not ex2.is_empty():
			with += 1
		for f in ex2:
			if SC.dist_to(grid2, pts2, f["p"]) < 12.0:
				bad += 1
	_check(bad == 0, "región: ninguna valla sobre el recorrido (%d carreras con cruces cerrados)" % with)
	print("   (cálculo de todas: %d ms)" % (Time.get_ticks_msec() - t0))
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)

## Desde el recorrido, ¿hasta dónde se llega por las calles sin cruzar una valla? (distancia máxima al recorrido)
func _flood(gps, pts: PackedVector2Array, grid: Dictionary, ex: Array) -> float:
	var city = gps.city
	var blocked := {}
	for f in ex:
		for si in gps._near(f["p"], 9.0):
			var q := Vector2(city.s_x[si], city.s_z[si])
			# la valla corta la calle de lado a lado: se bloquean los puntos de calle cerca de la línea de la valla
			var d: Vector2 = f["dir"]
			var rel: Vector2 = q - (f["p"] as Vector2)
			if absf(rel.dot(d)) < 5.0 and absf(rel.cross(d)) < float(f["hw"]) + 3.0:
				blocked[si] = true
	var start := {}
	for q in pts:
		var si: int = gps.nearest(q)
		if si >= 0:
			start[si] = true
	var seen := {}
	var queue: Array = start.keys()
	for s in queue:
		seen[s] = true
	var worst := 0.0
	var qi := 0
	while qi < queue.size() and seen.size() < 20000:
		var n: int = queue[qi]
		qi += 1
		var dn := SC.dist_to(grid, pts, Vector2(city.s_x[n], city.s_z[n]))
		if dn > worst:
			worst = dn
			if dn > 40.0:
				print("   escape por el punto ", int(city.s_x[n]), ",", int(city.s_z[n]), " calle ", city.roads[int(city.s_road[n])].get("name", ""), " dist ", dn)
		for m in (gps.adj[n] as PackedInt32Array):
			if seen.has(m) or blocked.has(m):
				continue
			seen[m] = true
			queue.append(m)
	return worst

## Cuántos puntos del recorrido vuelven a pasar a menos de 4 m de un punto ya recorrido 60 m o más atrás (una «púa»: salir a un punto por una calle del costado y volver por la misma).
## El cierre del lazo (el final cerca del principio) no cuenta.
func _spurs(pts: PackedVector2Array) -> int:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))
	var total := cum[cum.size() - 1]
	var n := 0
	for j in range(pts.size()):
		for i in range(0, j):
			var along := cum[j] - cum[i]
			if along < 60.0 or total - along < 60.0:
				continue
			if pts[i].distance_to(pts[j]) < 4.0:
				n += 1
				break
	return n
