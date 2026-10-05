extends RefCounted
## Puntos de montaje de un auto y ajuste de las piezas. Las medidas salen del JSON del modelo (models/cars/<id>.json: largo, alto, semiancho, ejes, radio de rueda) y de los
## parámetros de física, así que NO hace falta definir los puntos a mano auto por auto. Si un auto necesita otro lugar, se escribe en data/vehicle_mounts.json (sólo la excepción).
## Espacio del cuerpo (igual que CarParts): +z hacia adelante, +y hacia arriba desde el piso, x lateral. Un montaje es {pos: Vector3, rot: Vector3 (grados), mirror: bool}.

const PATH := "res://game/data/vehicle_mounts.json"
static var _over: Dictionary = {}

static func overrides() -> Dictionary:
	if _over.is_empty():
		if FileAccess.file_exists(PATH):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			_over = d if d is Dictionary else {"vehicles": {}}
		else:
			_over = {"vehicles": {}}
	return _over

## Medidas del auto. meta = models/cars/<id>.json (vacío si no tiene carrocería propia); V = VehicleParams
static func dims(V: RefCounted, meta: Dictionary) -> Dictionary:
	var wb := float(V.wheelBase)
	var wf := float(V.weightFront)
	var d := {
		"L": float(meta.get("L", wb + 1.9)), "H": float(meta.get("H", 1.3)), "hw": float(meta.get("hw", float(V.trackF) * 0.5 + 0.1)),
		"a": float(meta.get("a", wb * (1.0 - wf))), "b": float(meta.get("b", wb * wf)), "R": float(V.wheelRadius), "track_f": float(V.trackF), "track_r": float(V.trackR),
		"rim": float((meta.get("wheel", {}) as Dictionary).get("rim", float(V.wheelRadius) * 0.58)), "wheelbase": wb,
	}
	return d

## Todos los puntos de montaje del auto
static func mounts(vehicle_id: String, V: RefCounted, meta: Dictionary) -> Dictionary:
	var d := dims(V, meta)
	var L: float = d["L"]
	var H: float = d["H"]
	var hw: float = d["hw"]
	var m := {
		"wheel_FL": {"pos": Vector3(-float(d["track_f"]) * 0.5, float(d["R"]), float(d["a"])), "rot": Vector3.ZERO, "mirror": true},
		"wheel_FR": {"pos": Vector3(float(d["track_f"]) * 0.5, float(d["R"]), float(d["a"])), "rot": Vector3.ZERO, "mirror": false},
		"wheel_RL": {"pos": Vector3(-float(d["track_r"]) * 0.5, float(d["R"]), -float(d["b"])), "rot": Vector3.ZERO, "mirror": true},
		"wheel_RR": {"pos": Vector3(float(d["track_r"]) * 0.5, float(d["R"]), -float(d["b"])), "rot": Vector3.ZERO, "mirror": false},
		"front_bumper": {"pos": Vector3(0.0, H * 0.30, L * 0.5 - 0.08), "rot": Vector3.ZERO, "mirror": false},
		"rear_bumper": {"pos": Vector3(0.0, H * 0.30, -L * 0.5 + 0.08), "rot": Vector3(0.0, 180.0, 0.0), "mirror": false},
		"spoiler": {"pos": Vector3(0.0, H * 0.88, -L * 0.40), "rot": Vector3.ZERO, "mirror": false},
		"hood": {"pos": Vector3(0.0, H * 0.66, L * 0.22), "rot": Vector3.ZERO, "mirror": false},
		"side_skirt_L": {"pos": Vector3(-hw * 0.97, H * 0.20, 0.0), "rot": Vector3.ZERO, "mirror": true},
		"side_skirt_R": {"pos": Vector3(hw * 0.97, H * 0.20, 0.0), "rot": Vector3.ZERO, "mirror": false},
	}
	# excepciones por auto (sólo lo que no sirve el cálculo)
	var ov: Dictionary = (overrides().get("vehicles", {}) as Dictionary).get(vehicle_id, {})
	for k in ov:
		if m.has(k):
			var e: Dictionary = ov[k]
			if e.has("pos"):
				m[k]["pos"] = Vector3(float(e["pos"][0]), float(e["pos"][1]), float(e["pos"][2]))
			if e.has("rot"):
				m[k]["rot"] = Vector3(float(e["rot"][0]), float(e["rot"][1]), float(e["rot"][2]))
	return m

## Nombres de montaje que usa una categoría ("wheel" → las cuatro ruedas; "side_skirt" → izquierdo y derecho)
static func mount_names(category: String) -> Array:
	match category:
		"wheel": return ["wheel_FL", "wheel_FR", "wheel_RL", "wheel_RR"]
		"side_skirt": return ["side_skirt_L", "side_skirt_R"]
	return [category]

## Ajuste de una pieza a un auto: escala, desplazamiento y rotación finales. NO deforma la pieza: sólo escala proporcional dentro de [min, max] (si no entra, es incompatible).
## Devuelve {ok, reason, scale, offset: Vector3, rot: Vector3}
static func fit(part_def: Dictionary, vehicle_id: String, V: RefCounted, meta: Dictionary) -> Dictionary:
	if not (preload("res://game/car/part_catalog.gd")).rule_compatible(part_def, vehicle_id):
		return {"ok": false, "reason": "no es compatible con este auto"}
	var d := dims(V, meta)
	var f: Dictionary = part_def.get("fit", {})
	var base: Dictionary = part_def.get("base", {})
	var ref := maxf(float(f.get("ref", 1.0)), 0.0001)
	var ratio := float(f.get("ratio", 1.0))
	var s := 1.0
	match str(f.get("mode", "none")):
		"width": s = ratio * 2.0 * float(d["hw"]) / ref
		"length": s = ratio * float(d["L"]) / ref
		"height": s = ratio * float(d["H"]) / ref
		"wheel": s = ratio * float(d["rim"]) / ref
	s *= float(base.get("scale", 1.0))
	# excepción de la pieza para un auto concreto
	var ov: Dictionary = (part_def.get("fit_overrides", {}) as Dictionary).get(vehicle_id, {})
	if ov.has("scale"):
		s = float(ov["scale"])
	var rel := s / maxf(float(base.get("scale", 1.0)), 0.0001)
	if str(f.get("mode", "none")) != "none" and (rel < float(f.get("min", 0.6)) or rel > float(f.get("max", 1.6))):
		return {"ok": false, "reason": "el tamaño no entra en este auto (x%.2f)" % rel}
	var off := Vector3(float((base.get("offset", [0, 0, 0]) as Array)[0]), float((base.get("offset", [0, 0, 0]) as Array)[1]), float((base.get("offset", [0, 0, 0]) as Array)[2]))
	var rot := Vector3(float((base.get("rot", [0, 0, 0]) as Array)[0]), float((base.get("rot", [0, 0, 0]) as Array)[1]), float((base.get("rot", [0, 0, 0]) as Array)[2]))
	if ov.has("offset"):
		off = Vector3(float(ov["offset"][0]), float(ov["offset"][1]), float(ov["offset"][2]))
	if ov.has("rot"):
		rot = Vector3(float(ov["rot"][0]), float(ov["rot"][1]), float(ov["rot"][2]))
	return {"ok": true, "reason": "", "scale": s, "offset": off * s, "rot": rot}
