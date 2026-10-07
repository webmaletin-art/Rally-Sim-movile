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

## Muestras de una curva Catmull-Rom CERRADA (la misma que arma RouteTrack): para medir el largo y dónde cae un punto de control
static func _loop_len(pts: Array, upto: int) -> Array:
	var n := pts.size()
	var total := 0.0
	var at := 0.0
	var prev := Vector3(pts[0][0], pts[0][1], pts[0][2])
	for i in n:
		if i == upto:
			at = total
		var p0 := Vector3(pts[(i - 1 + n) % n][0], pts[(i - 1 + n) % n][1], pts[(i - 1 + n) % n][2])
		var p1 := Vector3(pts[i][0], pts[i][1], pts[i][2])
		var p2 := Vector3(pts[(i + 1) % n][0], pts[(i + 1) % n][1], pts[(i + 1) % n][2])
		var p3 := Vector3(pts[(i + 2) % n][0], pts[(i + 2) % n][1], pts[(i + 2) % n][2])
		for k in range(1, 25):
			var t := float(k) / 24.0
			var q := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
			total += prev.distance_to(q)
			prev = q
	return [total, at]

## Un recorrido de A a B (puntos abiertos) se cierra con un tramo de vuelta que el juego dibuja pero no se corre: sigue 150 m pasando la meta, vuelve en una curva suave (Hermite) y entra a la
## largada 150 m antes de A. Devuelve {points, nb}: los puntos del lazo cerrado y la cantidad de puntos del tramo A→B (el último, B, es el índice nb - 1).
static func close_open_path(pts: Array) -> Dictionary:
	var n := pts.size()
	var a := Vector3(pts[0][0], pts[0][1], pts[0][2])
	var a2 := Vector3(pts[1][0], pts[1][1], pts[1][2])
	var b := Vector3(pts[n - 1][0], pts[n - 1][1], pts[n - 1][2])
	var b2 := Vector3(pts[n - 2][0], pts[n - 2][1], pts[n - 2][2])
	var ta := Vector3(a2.x - a.x, 0.0, a2.z - a.z).normalized()
	var tb := Vector3(b.x - b2.x, 0.0, b.z - b2.z).normalized()
	var run := 150.0
	var p0 := Vector3(b.x + tb.x * run, b.y, b.z + tb.z * run) # pasando la meta
	var p1 := Vector3(a.x - ta.x * run, a.y, a.z - ta.z * run) # antes de la largada
	var out: Array = pts.duplicate()
	out.append([p0.x, p0.y, p0.z])
	var d := Vector2(p1.x - p0.x, p1.z - p0.z).length()
	var sc := maxf(d * 1.2, 420.0) # fuerza de las tangentes: la vuelta hace una curva abierta (radio > 100 m) aunque A y B estén cerca
	var m0 := tb * sc
	var m1 := ta * sc
	var k := maxi(2, int(ceil(maxf(d, sc) / 150.0)))
	for i in range(1, k):
		var t := float(i) / float(k)
		var t2 := t * t
		var t3 := t2 * t
		var h00 := 2.0 * t3 - 3.0 * t2 + 1.0
		var h10 := t3 - 2.0 * t2 + t
		var h01 := -2.0 * t3 + 3.0 * t2
		var h11 := t3 - t2
		var q := h00 * p0 + h10 * m0 + h01 * p1 + h11 * m1
		q.y = lerpf(p0.y, p1.y, t)
		out.append([q.x, q.y, q.z])
	out.append([p1.x, p1.y, p1.z])
	return {"points": out, "nb": n}

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
	var seg_b := -1.0 # recorrido A→B (v3 «point_to_point»): fracción del lazo cerrado donde está B
	var frac := 1.0 # fracción del lazo que ocupa lo que dibujó el autor (1 = todo el lazo)
	if ver == 3 and str(doc.get("type", "circuit")) == "point_to_point":
		var cl: Dictionary = close_open_path(pts)
		pts = cl["points"]
		var ml: Array = _loop_len(pts, int(cl["nb"]) - 1)
		seg_b = clampf(float(ml[1]) / maxf(float(ml[0]), 1.0), 0.05, 0.98)
		frac = seg_b
	var est_len: float = float(_loop_len(pts, 0)[0])
	var route := {"halfWidth": float(rd["halfWidth"]), "shoulder": float(rd["shoulder"]), "points": pts, "custom": true, "samples": clampi(int(est_len / 4.5), 1100, 6000)}
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
		var f0 := float(sd["from"]) * frac
		var f1 := float(sd["to"]) * frac
		surf.append({"from": f0, "to": f1, "s": code, "mu": float(SURF_MU.get(sf, 0.62)) / base_mu, "col": int(SURF_COL.get(sf, 1))})
		dens.append({"from": f0, "to": f1, "d": float(sd.get("density", dflt))})
		if str(sd.get("label", "")) != "":
			labels.append({"from": f0, "to": f1, "label": str(sd["label"])})
	if seg_b > 0.0 and not secs.is_empty():
		# el tramo de vuelta: misma superficie que el final, sin árboles (nadie lo corre)
		var code2 := int(SURF_CODE.get(last_sf, 1))
		surf.append({"from": seg_b, "to": 1.0, "s": code2, "mu": float(SURF_MU.get(last_sf, 0.62)) / base_mu, "col": int(SURF_COL.get(last_sf, 1))})
		dens.append({"from": seg_b, "to": 1.0, "d": 0.0})
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
	if seg_b > 0.0:
		map["defaults"]["seg"] = [0.0, seg_b] # de A a B
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
