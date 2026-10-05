extends RefCounted
## Catálogo de piezas modulares (data/parts.json). Se carga una sola vez. Registrar una pieza nueva = una entrada en el JSON (+ el modelo en game/models/parts/ si es GLB/OBJ):
## categoría, origen del modelo, escala base, ajuste (cómo se adapta al tamaño del auto), compatibilidad y variantes. El punto de montaje de cada auto NO se repite por pieza:
## sale de las medidas del auto (vehicle_mounts.gd).

const PATH := "res://game/data/parts.json"
static var _data: Dictionary = {}

const PACK_DIR := "res://game/data/parts/"

static func data() -> Dictionary:
	if _data.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = d if d is Dictionary else {"version": 1, "categories": {}, "parts": {}, "defaults": {}}
		_merge_packs()
	return _data

## Paquetes de piezas: cada archivo game/data/parts/*.json ({"parts": {id: def}}) suma piezas al catálogo SIN tocar parts.json (un pack nuevo = un JSON + sus modelos).
## Una pieza de un pack no puede pisar una del catálogo base (se ignora y se avisa).
static func _merge_packs() -> void:
	var parts: Dictionary = _data.get("parts", {})
	for f in DirAccess.get_files_at(PACK_DIR):
		if not f.ends_with(".json"):
			continue
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PACK_DIR + f))
		if not (j is Dictionary):
			push_warning("pack de piezas inválido: %s" % f)
			continue
		for id in ((j as Dictionary).get("parts", {}) as Dictionary):
			if parts.has(id):
				push_warning("pieza repetida en %s: %s (se ignora)" % [f, id])
				continue
			parts[id] = j["parts"][id]
	_data["parts"] = parts

static func categories() -> Dictionary:
	return data().get("categories", {})

static func category(id: String) -> Dictionary:
	return categories().get(id, {})

## La definición completa de una pieza (con los valores por defecto ya mezclados)
static func part(id: String) -> Dictionary:
	var raw: Dictionary = (data().get("parts", {}) as Dictionary).get(id, {})
	if raw.is_empty():
		return {}
	var df: Dictionary = data().get("defaults", {})
	var out := raw.duplicate(true)
	out["id"] = id
	for k in ["base", "fit", "compat"]:
		var m: Dictionary = (df.get(k, {}) as Dictionary).duplicate(true)
		for kk in (raw.get(k, {}) as Dictionary):
			m[kk] = raw[k][kk]
		out[k] = m
	return out

## Ids de las piezas de una categoría (sin las ocultas, que son de prueba)
static func parts_in(cat: String, include_hidden := false) -> Array:
	var out: Array = []
	for id in (data().get("parts", {}) as Dictionary):
		var p: Dictionary = data()["parts"][id]
		if str(p.get("category", "")) == cat and (include_hidden or p.get("hidden", false) != true):
			out.append(str(id))
	return out

## ¿Esta pieza admite este auto por reglas (lista de autos y exclusiones)? El ajuste de tamaño se comprueba aparte (vehicle_mounts.fit)
static func rule_compatible(part_def: Dictionary, vehicle_id: String) -> bool:
	var c: Dictionary = part_def.get("compat", {})
	if (c.get("exclude", []) as Array).has(vehicle_id):
		return false
	var allow: Array = c.get("vehicles", ["*"])
	return allow.has("*") or allow.has(vehicle_id)

## Revisa una definición (al registrar una pieza nueva): devuelve la lista de problemas (vacía = está bien)
static func validate(id: String, def: Dictionary) -> Array:
	var errs: Array = []
	if not categories().has(str(def.get("category", ""))):
		errs.append("categoría desconocida: %s" % str(def.get("category", "")))
	var src: Dictionary = def.get("source", {})
	match str(src.get("type", "")):
		"rim":
			if str(src.get("style", "")) == "":
				errs.append("falta source.style")
		"glb", "obj", "mesh":
			if not ResourceLoader.exists(str(src.get("path", ""))):
				errs.append("no existe el modelo %s" % str(src.get("path", "")))
		"boxes":
			if (src.get("boxes", []) as Array).is_empty():
				errs.append("source.boxes vacío")
		_:
			errs.append("source.type desconocido: %s" % str(src.get("type", "")))
	var fit: Dictionary = def.get("fit", {})
	if not str(fit.get("mode", "none")) in ["none", "width", "length", "height", "wheel"]:
		errs.append("fit.mode desconocido")
	if float(fit.get("min", 0.6)) > float(fit.get("max", 1.6)):
		errs.append("fit.min mayor que fit.max")
	return errs
