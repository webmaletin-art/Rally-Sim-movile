extends RefCounted
## GPS de todo el mundo abierto: la ciudad (CityGps) y la región (RegionData.route) unidas por las salidas de la ciudad. Misma interfaz que CityGps (route(a, b) → {pts, len}).
## Si el origen y el destino están del mismo lado, usa el mapa de ese lado; si no, prueba cada salida (Ruta 20, Ruta 40, Ruta 80 y la Panorámica) y se queda con la más corta.

const CityGps := preload("res://game/city/city_gps.gd")
const RegionData := preload("res://game/region/region_data.gd")

const EXIT_IDS := ["exit20", "exit40", "exit80", "pan_end"]

var city_gps: CityGps
var region: RegionData
var _exit_nodes: Array = []

func _init(p_city_gps: CityGps, p_region: RegionData) -> void:
	city_gps = p_city_gps
	region = p_region
	if region != null:
		for id in EXIT_IDS:
			var ni := region.node_by_id(id)
			if ni >= 0:
				_exit_nodes.append(region.node_pos(ni))

## ¿Está sobre las calles de la ciudad (a menos de 60 m de una)?
func in_city(p: Vector2) -> bool:
	var si := city_gps.nearest(p)
	if si < 0:
		return false
	return Vector2(city_gps.city.s_x[si], city_gps.city.s_z[si]).distance_to(p) < 60.0

func nearest(p: Vector2) -> int:
	return city_gps.nearest(p)

func route(a: Vector2, b: Vector2) -> Dictionary:
	if region == null:
		return city_gps.route(a, b)
	var ac := in_city(a)
	var bc := in_city(b)
	if ac and bc:
		return city_gps.route(a, b)
	if not ac and not bc:
		return _simplify(region.route(a, b))
	var best := {"pts": PackedVector2Array(), "len": 0.0}
	var bl := 1e30
	for ex in _exit_nodes:
		var first: Dictionary
		var second: Dictionary
		if ac:
			first = city_gps.route(a, ex)
			if (first["pts"] as PackedVector2Array).is_empty():
				continue
			second = region.route(ex, b)
		else:
			first = region.route(a, ex)
			if not bool(first.get("ok", true)) or (first["pts"] as PackedVector2Array).is_empty():
				continue
			second = city_gps.route(ex, b)
		if (second["pts"] as PackedVector2Array).is_empty():
			continue
		var tot: float = float(first["len"]) + float(second["len"])
		if tot < bl:
			bl = tot
			var pts := PackedVector2Array()
			pts.append_array(first["pts"] if ac else _simplify(first)["pts"])
			pts.append_array(_simplify(second)["pts"] if ac else second["pts"])
			best = {"pts": pts, "len": tot}
	return best

## Las rutas largas de la región tienen un punto cada 12 m: se dejan cada ~30 m (el GPS no necesita más y el mapa dibuja menos)
func _simplify(r: Dictionary) -> Dictionary:
	var pts: PackedVector2Array = r["pts"]
	if pts.size() < 40:
		return r
	var out := PackedVector2Array()
	var last := pts[0]
	out.append(last)
	for i in range(1, pts.size() - 1):
		if pts[i].distance_squared_to(last) >= 28.0 * 28.0:
			out.append(pts[i])
			last = pts[i]
	out.append(pts[pts.size() - 1])
	return {"pts": out, "len": r["len"]}
