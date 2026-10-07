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

## Archivo v2 → {id, route, map, [map_rev], [patch]}. Vacío si no es un mapa válido para el juego (la validación fuerte la hace tools/route_gen/route_spec.py al importar)
static func convert_doc(doc: Dictionary) -> Dictionary:
	if str(doc.get("format", "")) != "dreamracing-route" or int(doc.get("version", 0)) != 2:
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
	var route := {"halfWidth": float(rd["halfWidth"]), "shoulder": float(rd["shoulder"]), "points": rd["points"], "custom": true}
	var surf: Array = []
	var dens: Array = []
	var labels: Array = []
	var scen: Dictionary = doc.get("scenery", {})
	var dflt := float(scen.get("density", 0.6))
	for s in secs:
		var sd: Dictionary = s
		var sf := str(sd.get("surface", base))
		var code := int(SURF_CODE.get(sf, 1))
		surf.append({"from": float(sd["from"]), "to": float(sd["to"]), "s": code, "mu": float(SURF_MU.get(sf, 0.62)) / base_mu, "col": int(SURF_COL.get(sf, 1))})
		dens.append({"from": float(sd["from"]), "to": float(sd["to"]), "d": float(sd.get("density", dflt))})
		if str(sd.get("label", "")) != "":
			labels.append({"from": float(sd["from"]), "to": float(sd["to"]), "label": str(sd["label"])})
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
