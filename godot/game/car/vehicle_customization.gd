extends RefCounted
## Personalización modular de un auto: qué piezas tiene instaladas y cómo se arman en el cuerpo. La configuración es un diccionario simple
##    mods = { "wheel": {"id": "rim_dish8", "v": 0}, "spoiler": {"id": "...", "v": 0}, ... }
## que se guarda dentro del estado del auto (state["mods"]). Es el MISMO formato para el garaje offline y para una instancia de auto online (ahí lo valida el servidor).
## Nada de este módulo conoce modelos concretos: las piezas salen del catálogo (part_catalog.gd) y los montajes de las medidas del auto (vehicle_mounts.gd).

const PartCatalog := preload("res://game/car/part_catalog.gd")
const VehicleMounts := preload("res://game/car/vehicle_mounts.gd")

## ¿Este auto admite piezas modulares? (por ahora los que tienen carrocería propia; los que usan la del Volt todavía no)
static func supports(vehicle_id: String) -> bool:
	return vehicle_id != "" and ResourceLoader.exists("res://game/models/cars/%s.glb" % vehicle_id)

static func installed(state: Dictionary) -> Dictionary:
	var m: Variant = state.get("mods", {})
	return m if m is Dictionary else {}

## ¿Se puede instalar? {ok, reason}
static func can_install(part_id: String, vehicle_id: String, V: RefCounted, meta: Dictionary) -> Dictionary:
	var p := PartCatalog.part(part_id)
	if p.is_empty():
		return {"ok": false, "reason": "pieza inexistente"}
	if not PartCatalog.categories().has(str(p["category"])):
		return {"ok": false, "reason": "categoría inexistente"}
	if not supports(vehicle_id):
		return {"ok": false, "reason": "este auto todavía no admite piezas"}
	var f := VehicleMounts.fit(p, vehicle_id, V, meta)
	return {"ok": bool(f["ok"]), "reason": str(f.get("reason", ""))}

## Instala (o reemplaza la de esa categoría) y deja el resultado en el estado del auto
static func install(state: Dictionary, vehicle_id: String, part_id: String, V: RefCounted, meta: Dictionary, variant := 0) -> Dictionary:
	var c := can_install(part_id, vehicle_id, V, meta)
	if not bool(c["ok"]):
		return c
	var p := PartCatalog.part(part_id)
	var mods: Dictionary = installed(state).duplicate(true)
	mods[str(p["category"])] = {"id": part_id, "v": variant}
	state["mods"] = mods
	return {"ok": true, "reason": ""}

static func remove(state: Dictionary, category: String) -> void:
	var mods: Dictionary = installed(state).duplicate(true)
	mods.erase(category)
	state["mods"] = mods

## Revisa una configuración guardada contra el catálogo y el auto: devuelve sólo las piezas que siguen siendo válidas (para no romper si el catálogo cambia o si viene de afuera)
static func sanitize(mods: Dictionary, vehicle_id: String, V: RefCounted, meta: Dictionary) -> Dictionary:
	var out := {}
	for cat in mods:
		var e: Variant = mods[cat]
		if not (e is Dictionary):
			continue
		var pid := str((e as Dictionary).get("id", ""))
		var p := PartCatalog.part(pid)
		if p.is_empty() or str(p["category"]) != str(cat):
			continue
		if not bool(can_install(pid, vehicle_id, V, meta)["ok"]):
			continue
		out[str(cat)] = {"id": pid, "v": int((e as Dictionary).get("v", 0))}
	return out

## Cambios para las ruedas: {style, rim_scale} si hay una llanta instalada y válida; vacío si no
static func wheel_override(vehicle_id: String, V: RefCounted, meta: Dictionary, mods: Dictionary) -> Dictionary:
	var e: Variant = mods.get("wheel")
	if not (e is Dictionary):
		return {}
	var p := PartCatalog.part(str((e as Dictionary).get("id", "")))
	if p.is_empty() or str(p["category"]) != "wheel" or str((p["source"] as Dictionary).get("type", "")) != "rim":
		return {}
	var f := VehicleMounts.fit(p, vehicle_id, V, meta)
	if not bool(f["ok"]):
		return {}
	var d := VehicleMounts.dims(V, meta)
	var sc := clampf(float(f["scale"]), 0.85, 1.15)
	if float(d["rim"]) * sc > float(d["R"]) * 0.82:
		sc = float(d["R"]) * 0.82 / maxf(float(d["rim"]), 0.001) # la llanta no puede comerse el neumático
	return {"style": str((p["source"] as Dictionary)["style"]), "rim_scale": sc, "part": str(p["id"])}

## Arma los nodos de las piezas que NO son llantas y los cuelga del cuerpo. Devuelve los nodos creados (para poder sacarlos).
static func attach(body: Node3D, vehicle_id: String, V: RefCounted, meta: Dictionary, mods: Dictionary, lo := false) -> Array:
	var made: Array = []
	var mts := VehicleMounts.mounts(vehicle_id, V, meta)
	for cat in mods:
		if str(cat) == "wheel":
			continue
		var e: Variant = mods[cat]
		if not (e is Dictionary):
			continue
		var p := PartCatalog.part(str((e as Dictionary).get("id", "")))
		if p.is_empty() or str(p["category"]) != str(cat):
			continue
		var f := VehicleMounts.fit(p, vehicle_id, V, meta)
		if not bool(f["ok"]):
			continue
		for mn in VehicleMounts.mount_names(str(cat)):
			var m: Dictionary = mts.get(mn, {})
			if m.is_empty():
				continue
			var node := _build_node(p, lo)
			if node == null:
				continue
			var mrot: Vector3 = m["rot"]
			var basis := Basis.from_euler(Vector3(deg_to_rad(mrot.x), deg_to_rad(mrot.y), deg_to_rad(mrot.z)))
			node.position = (m["pos"] as Vector3) + basis * (f["offset"] as Vector3)
			node.basis = basis * Basis.from_euler(Vector3(deg_to_rad((f["rot"] as Vector3).x), deg_to_rad((f["rot"] as Vector3).y), deg_to_rad((f["rot"] as Vector3).z)))
			var s := float(f["scale"])
			node.scale = Vector3(-s if bool(m.get("mirror", false)) else s, s, s) # el lado izquierdo se espeja
			node.name = "Part_%s_%s" % [str(cat), mn]
			body.add_child(node)
			made.append(node)
	return made

## El nodo de una pieza según su origen: modelo (GLB/OBJ ya importado) o cajas simples (piezas de prueba)
static func _build_node(p: Dictionary, lo: bool) -> Node3D:
	var src: Dictionary = p.get("source", {})
	match str(src.get("type", "")):
		"glb":
			var path := str(src.get("path", ""))
			if not ResourceLoader.exists(path):
				return null
			var sc: Variant = load(path)
			if sc is PackedScene:
				return (sc as PackedScene).instantiate() as Node3D
			return null
		"boxes":
			var root := Node3D.new()
			for b in (src.get("boxes", []) as Array):
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(float(b["size"][0]), float(b["size"][1]), float(b["size"][2]))
				mi.mesh = bm
				mi.position = Vector3(float(b["pos"][0]), float(b["pos"][1]), float(b["pos"][2]))
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(str(b.get("color", "#222222")))
				mat.roughness = 0.6
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mi)
			return root
	return null
