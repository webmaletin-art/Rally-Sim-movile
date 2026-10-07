extends RefCounted
## Mapas del juego: routes.json + los mapas personalizados de godot/game/data/custom_maps/*.json (los que exporta el generador HTML de rutas, formato «dreamracing-route» v2).
## Todo el juego pide los mapas por acá (load_all) para ver los dos juntos. Soltar un .json en custom_maps/ alcanza: se lee solo al arrancar.
##
## Del archivo v2 sale: la ruta (puntos, ancho, banquina y SUPERFICIE POR TRAMO → `surf`), el mapa (nombre, entorno con densidad de árboles por tramo, valores por defecto de vueltas/rivales/dificultad)
## y, si trae «career», un parche para el evento de la carrera que reemplaza (mapa, vueltas o tramo, rivales y dificultad).

const DIR := "res://game/data/custom_maps"
const ROUTES := "res://game/data/routes.json"

## Código de superficie del motor (ver RouteTrack / VehicleParams.SURF_NAMES) y agarre relativo para la IA (1 = asfalto)
const SURF_CODE := {"asphalt": 0, "dirt": 1, "gravel": 1, "mud": 5, "sand": 6}
const SURF_MU := {"asphalt": 1.0, "dirt": 0.62, "gravel": 0.72, "mud": 0.42, "sand": 0.55}
## Columna de la textura del camino (atlas) de cada superficie
const SURF_COL := {"asphalt": 0, "dirt": 1, "gravel": 2, "mud": 3, "sand": 4}

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache = {}

## {"routes": {...}, "maps": {...}, "patches": [...]}
static func load_all() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	var patches: Array = []
	var da := DirAccess.open(DIR)
	if da != null:
		var files: Array = []
		for f in da.get_files():
			var fn := str(f).trim_suffix(".remap") # (en el APK las listas de archivos pueden traer el sufijo .remap)
			if fn.ends_with(".json") and not files.has(fn):
				files.append(fn)
		files.sort()
		for f in files:
			var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + str(f)))
			if not (doc is Dictionary):
				push_warning("mapa personalizado ilegible: " + str(f))
				continue
			var out: Dictionary = convert_doc(doc as Dictionary)
			if out.is_empty():
				push_warning("mapa personalizado inválido: " + str(f))
				continue
			var id := str(out["id"])
			(d["routes"] as Dictionary)[id] = out["route"]
			(d["maps"] as Dictionary)[id] = out["map"]
			if out.has("map_rev"):
				(d["maps"] as Dictionary)[id + "Rev"] = out["map_rev"]
			if out.has("patch"):
				patches.append(out["patch"])
	d["patches"] = patches
	_cache = d
	return d

static func maps() -> Dictionary:
	return load_all()["maps"]

## Parches de eventos de la carrera que piden los mapas personalizados
static func patches() -> Array:
	return load_all()["patches"]

## Largo acumulado (m) hasta cada punto de control de la curva Catmull-Rom (la misma que arma RouteTrack): arcs[k] = largo desde el punto 0 hasta el punto k (arcs[n] = el lazo completo)
static func _ctrl_arcs(pts: Array) -> PackedFloat64Array:
	var n := pts.size()
	var arcs := PackedFloat64Array()
	arcs.resize(n + 1)
	var total := 0.0
	var prev := Vector3(pts[0][0], pts[0][1], pts[0][2])
	for i in n:
		arcs[i] = total
		var p0 := Vector3(pts[(i - 1 + n) % n][0], pts[(i - 1 + n) % n][1], pts[(i - 1 + n) % n][2])
		var p1 := Vector3(pts[i][0], pts[i][1], pts[i][2])
		var p2 := Vector3(pts[(i + 1) % n][0], pts[(i + 1) % n][1], pts[(i + 1) % n][2])
		var p3 := Vector3(pts[(i + 2) % n][0], pts[(i + 2) % n][1], pts[(i + 2) % n][2])
		for k in range(1, 25):
			var t := float(k) / 24.0
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			total += prev.distance_to(q)
			prev = q
	arcs[n] = total
	return arcs

const RUN := 200.0 # m de camino antes de la largada y después de la meta de un A→B

## Puntos de control de un recorrido A→B (camino ABIERTO): los del autor más dos puntos «fantasma» antes de A y dos después de B, siguiendo la dirección y la pendiente de los extremos.
## RouteTrack sólo muestrea de A − 200 m a B + 200 m (open_lo / open_hi): ahí hay lugar para la parrilla y para frenar pasando la meta, y no queda ningún tramo de vuelta.
static func open_ctrl(pts: Array) -> Array:
	var n := pts.size()
	var a := Vector3(pts[0][0], pts[0][1], pts[0][2])
	var a2 := Vector3(pts[1][0], pts[1][1], pts[1][2])
	var b := Vector3(pts[n - 1][0], pts[n - 1][1], pts[n - 1][2])
	var b2 := Vector3(pts[n - 2][0], pts[n - 2][1], pts[n - 2][2])
	var ta := Vector3(a2.x - a.x, 0.0, a2.z - a.z)
	var tb := Vector3(b.x - b2.x, 0.0, b.z - b2.z)
	var sa := clampf((a2.y - a.y) / maxf(ta.length(), 1.0), -0.12, 0.12) # pendiente (dy/ds) de los extremos
	var sb := clampf((b.y - b2.y) / maxf(tb.length(), 1.0), -0.12, 0.12)
	ta = ta.normalized()
	tb = tb.normalized()
	var out: Array = []
	out.append([a.x - ta.x * 2.0 * RUN, a.y - sa * 2.0 * RUN, a.z - ta.z * 2.0 * RUN])
	out.append([a.x - ta.x * RUN, a.y - sa * RUN, a.z - ta.z * RUN])
	out.append_array(pts)
	out.append([b.x + tb.x * RUN, b.y + sb * RUN, b.z + tb.z * RUN])
	out.append([b.x + tb.x * 2.0 * RUN, b.y + sb * 2.0 * RUN, b.z + tb.z * 2.0 * RUN])
	return out

## Archivo v2/v3 → {id, route, map, [map_rev], [patch]}. Vacío si no es un mapa válido para el juego (la validación fuerte la hace tools/route_gen/route_spec.py al importar)
static func convert_doc(doc: Dictionary) -> Dictionary:
	var ver := int(doc.get("version", 0))
	if str(doc.get("format", "")) != "dreamracing-route" or (ver != 2 and ver != 3):
		return {}
	var id := str(doc.get("id", ""))
	var r: Variant = doc.get("route")
	if id == "" or not (r is Dictionary) or not ((r as Dictionary).get("points") is Array) or ((r as Dictionary)["points"] as Array).size() < 8:
		return {}
	var rd: Dictionary = r
	var base := str(doc.get("surface", "asphalt"))
	var secs: Array = doc.get("sections", [])
	var all_asphalt := base == "asphalt"
	for s in secs:
		if str((s as Dictionary).get("surface", base)) != "asphalt":
			all_asphalt = false
	var mode := "asphalt" if all_asphalt else "dirt"
	var base_mu := 1.0 if mode == "asphalt" else 0.6
	var pts: Array = rd["points"]
	var seg_a := -1.0 # recorrido A→B (v3 «point_to_point»): fracciones del camino muestreado donde están A y B
	var seg_b := -1.0
	var open_route := ver == 3 and str(doc.get("type", "circuit")) == "point_to_point"
	var est_len: float
	var n_pts := pts.size()
	var smp := 0
	if open_route:
		pts = open_ctrl(pts)
		var arcs: PackedFloat64Array = _ctrl_arcs(pts)
		var m := pts.size()
		var wl: float = arcs[m - 2] - arcs[1]
		seg_a = (arcs[2] - arcs[1]) / wl
		seg_b = (arcs[n_pts + 1] - arcs[1]) / wl
		est_len = wl
		smp = clampi(int(wl / 4.5), 300, 6000)
	else:
		est_len = _ctrl_arcs(pts)[pts.size()]
		smp = clampi(int(est_len / 4.5), 1100, 6000)
	var route := {"halfWidth": float(rd["halfWidth"]), "shoulder": float(rd["shoulder"]), "points": pts, "custom": true, "samples": smp}
	if ver == 3:
		route["flat"] = true # sin ondulaciones agregadas: la altura es la que dibujó el autor
		route["exact_y"] = true
	if open_route:
		route["open"] = true
		route["open_lo"] = 1
		route["open_hi"] = pts.size() - 2
	var frac := 1.0 if seg_a < 0.0 else (seg_b - seg_a)
	var f_off := 0.0 if seg_a < 0.0 else seg_a
	var surf: Array = []
	var dens: Array = []
	var labels: Array = []
	var scen: Dictionary = doc.get("scenery", {})
	var dflt := float(scen.get("density", 0.6))
	var last_sf := base
	for s in secs:
		var sd: Dictionary = s
		var sf := str(sd.get("surface", base))
		last_sf = sf
		var code := int(SURF_CODE.get(sf, 1))
		var f0 := f_off + float(sd["from"]) * frac
		var f1 := f_off + float(sd["to"]) * frac
		if open_route and float(sd["from"]) <= 0.0:
			f0 = 0.0 # la largada y la llegada siguen con la superficie del primer y del último tramo
		if open_route and float(sd["to"]) >= 1.0:
			f1 = 1.0
		surf.append({"from": f0, "to": f1, "s": code, "mu": float(SURF_MU.get(sf, 0.62)) / base_mu, "col": int(SURF_COL.get(sf, 1))})
		dens.append({"from": f0, "to": f1, "d": float(sd.get("density", dflt))})
		if str(sd.get("label", "")) != "":
			labels.append({"from": f0, "to": f1, "label": str(sd["label"])})
	if not surf.is_empty():
		route["surf"] = surf
		route["atlas"] = not all_asphalt or secs.size() > 0 # textura con una columna por superficie
	route["dens"] = dens
	var rc: Dictionary = doc.get("race", {})
	var riv: Dictionary = doc.get("rivals", {})
	var map := {"name": str(doc.get("name", id)), "icon": str(doc.get("icon", "🏁")), "kind": "route", "route": id, "mode": mode, "custom": true,
		"scenery": {"trees": str(scen.get("trees", "mixed")), "density": dflt},
		"defaults": {"laps": int(rc.get("laps", 2)), "ai": int(riv.get("count", 3)), "skill": skill_of(float(riv.get("difficulty", 0.5)))}}
	if rc.has("seg"):
		map["defaults"]["seg"] = rc["seg"]
	if seg_a >= 0.0:
		map["defaults"]["seg"] = [seg_a, seg_b] # de A a B
	var dec: Dictionary = doc.get("decor", {})
	map["decor"] = {"edge": str(dec.get("edge", "auto")), "veg": clampf(float(dec.get("vegetation", 1.0)), 0.0, 1.0)}
	var wth: Dictionary = doc.get("weather", {})
	if str(wth.get("sky", "")) != "":
		map["defaults"]["sky"] = str(wth["sky"])
	var style := str(rc.get("style", "race"))
	map["defaults"]["style"] = style
	map["defaults"]["chaseGap"] = float((rc.get("chase", {}) as Dictionary).get("maxGapM", 150.0))
	map["defaults"]["elimEvery"] = float((rc.get("elimination", {}) as Dictionary).get("everySec", 30.0))
	var out := {"id": id, "route": route, "map": map}
	if bool(doc.get("reverse", false)):
		out["map_rev"] = (map as Dictionary).duplicate(true)
		out["map_rev"]["name"] = str(map["name"]) + " (inversa)"
		out["map_rev"]["reverse"] = true
	var car: Dictionary = doc.get("career", {})
	if str(car.get("event", "")) != "":
		var p := {"event": str(car["event"]), "map": id, "ai": int(riv.get("count", 3)), "skill": skill_of(float(riv.get("difficulty", 0.5)))}
		if rc.has("seg"):
			p["seg"] = rc["seg"]
		else:
			p["laps"] = int(rc.get("laps", 2))
		if str(car.get("sky", "")) != "":
			p["sky"] = str(car["sky"])
		if bool(car.get("reverse", false)):
			p["map"] = id + "Rev"
			if not out.has("map_rev"):
				out["map_rev"] = (map as Dictionary).duplicate(true)
				out["map_rev"]["name"] = str(map["name"]) + " (inversa)"
				out["map_rev"]["reverse"] = true
		out["patch"] = p
	return out

## Dificultad 0..1 (el 1 %…100 % del generador) → habilidad de la IA. La IA de las copas va de 0.76 (Debut) a 0.96 (Leyenda): 0 % queda por debajo de Debut y 100 % por encima de Leyenda
static func skill_of(d: float) -> float:
	return snappedf(lerpf(0.62, 1.04, clampf(d, 0.0, 1.0)), 0.001)
