## Comprobación corta del sistema modular de piezas (catálogo, montajes, ajuste, compatibilidad, guardado, llantas). Sin red.
## Uso: godot --headless --script res://tests/parts_test.gd
extends SceneTree

const PartCatalog := preload("res://game/car/part_catalog.gd")
const VehicleMounts := preload("res://game/car/vehicle_mounts.gd")
const VehicleCustomization := preload("res://game/car/vehicle_customization.gd")
const VehicleParams := preload("res://game/physics/vehicle_params.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const CarVisual := preload("res://game/car/car_visual.gd")
const WheelGen := preload("res://game/car/wheel_gen.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _V(id: String) -> RefCounted:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	return VehicleParams.from_dict(CarBuild.build_params(vehicles[id], {"upg": {}, "tires": "street", "tune": {}}))

func _init() -> void:
	# catálogo
	check(PartCatalog.categories().has("wheel") and PartCatalog.categories().has("spoiler"), "el catálogo tiene categorías")
	var wheels := PartCatalog.parts_in("wheel")
	check(wheels.size() >= 9, "hay %d llantas registradas" % wheels.size())
	var all_ok := true
	for id in (PartCatalog.data()["parts"] as Dictionary):
		var errs := PartCatalog.validate(str(id), PartCatalog.part(str(id)))
		if not errs.is_empty():
			all_ok = false
			print("   ", id, " → ", errs)
	check(all_ok, "todas las piezas del catálogo son válidas")
	check(not PartCatalog.validate("x", {"category": "nada", "source": {"type": "glb", "path": "res://no_existe.glb"}}).is_empty(), "una pieza mal registrada se detecta")
	check(PartCatalog.parts_in("spoiler").is_empty() and not PartCatalog.parts_in("spoiler", true).is_empty(), "las piezas de prueba quedan ocultas")
	# montajes y ajuste en todos los autos con carrocería propia
	var own := ["pickup", "truck", "hatch", "suv", "buggy", "muscle", "gt", "gt3", "hyper"]
	var dev := PartCatalog.part("dev_spoiler_wing")
	for id in own:
		if not VehicleCustomization.supports(id):
			continue
		var V := _V(id)
		var meta := CarVisual.load_meta(id)
		var m := VehicleMounts.mounts(id, V, meta)
		var f := VehicleMounts.fit(dev, id, V, meta)
		var sp: Vector3 = m["spoiler"]["pos"]
		check(m.has("front_bumper") and m.has("wheel_FL") and bool(f["ok"]) and float(f["scale"]) > 0.3 and sp.z < 0.0 and sp.y > 0.5, "%s: montajes y ajuste del alerón (escala %.2f, y %.2f, z %.2f)" % [id, float(f["scale"]), sp.y, sp.z])
	# el mismo alerón queda más ancho en un auto más ancho (misma pieza, varios autos)
	var fa := VehicleMounts.fit(dev, "hatch", _V("hatch"), CarVisual.load_meta("hatch"))
	var fb := VehicleMounts.fit(dev, "hyper", _V("hyper"), CarVisual.load_meta("hyper"))
	check(float(fb["scale"]) > float(fa["scale"]), "una misma pieza se adapta al ancho de cada auto (hatch %.2f < hyper %.2f)" % [float(fa["scale"]), float(fb["scale"])])
	# compatibilidad: exclusiones y tamaño imposible
	var excl := PartCatalog.part("dev_spoiler_wing")
	excl["compat"]["exclude"] = ["gt"]
	check(not bool(VehicleMounts.fit(excl, "gt", _V("gt"), CarVisual.load_meta("gt"))["ok"]), "una pieza excluida se marca incompatible")
	var tiny := PartCatalog.part("dev_spoiler_wing")
	tiny["fit"]["max"] = 0.9
	check(not bool(VehicleMounts.fit(tiny, "truck", _V("truck"), CarVisual.load_meta("truck"))["ok"]), "si no entra por tamaño, es incompatible (no se deforma)")
	# instalar, guardar y cargar
	var state := {"upg": {}, "paint": {}}
	var V := _V("gt")
	var meta := CarVisual.load_meta("gt")
	var r1 := VehicleCustomization.install(state, "gt", "rim_dish8", V, meta)
	var r2 := VehicleCustomization.install(state, "gt", "dev_spoiler_wing", V, meta)
	check(bool(r1["ok"]) and bool(r2["ok"]) and VehicleCustomization.installed(state).size() == 2, "instalar llanta y alerón")
	var saved: Variant = JSON.parse_string(JSON.stringify(state)) # lo que haría guardar y volver a leer el perfil
	var loaded := VehicleCustomization.sanitize(VehicleCustomization.installed(saved as Dictionary), "gt", V, meta)
	check(loaded.size() == 2 and str(loaded["wheel"]["id"]) == "rim_dish8", "se guarda y se vuelve a cargar igual")
	check(VehicleCustomization.sanitize({"wheel": {"id": "no_existe"}, "spoiler": {"id": "rim_dish8"}}, "gt", V, meta).is_empty(), "una configuración inválida o de otra categoría se descarta")
	check(not bool(VehicleCustomization.install(state, "genesis", "rim_dish8", _V("genesis"), {})["ok"]), "los autos sin carrocería propia todavía no admiten piezas")
	VehicleCustomization.remove(state, "spoiler")
	check(VehicleCustomization.installed(state).size() == 1, "quitar una pieza")
	# llantas: cada estilo registrado genera su malla y el override sale bien
	var styles_ok := true
	for wid in wheels:
		var st := str((PartCatalog.part(str(wid))["source"] as Dictionary)["style"])
		var mesh := WheelGen.rim_mesh(st, 0.24, 0.2, false)
		if mesh == null or mesh.get_surface_count() == 0:
			styles_ok = false
			print("   sin malla: ", wid)
	check(styles_ok, "cada llanta del catálogo genera su malla")
	var wo := VehicleCustomization.wheel_override("gt", V, meta, loaded)
	check(str(wo.get("style", "")) == "dish8" and float(wo.get("rim_scale", 0.0)) >= 0.85, "la llanta instalada cambia el estilo de las ruedas (%s)" % str(wo))
	# armar nodos sobre un cuerpo
	var body := Node3D.new()
	var mods_all := {"spoiler": {"id": "dev_spoiler_wing", "v": 0}, "front_bumper": {"id": "dev_bumper_front", "v": 0}, "side_skirt": {"id": "dev_skirt", "v": 0}}
	var nodes := VehicleCustomization.attach(body, "gt", V, meta, mods_all, false)
	check(nodes.size() == 4 and body.get_child_count() == 4, "se arman 4 nodos (alerón, paragolpes y dos faldones espejados)")
	var skirts: Array = []
	for n in nodes:
		if (n as Node3D).name.begins_with("Part_side_skirt"):
			skirts.append(n)
	check(skirts.size() == 2 and (skirts[0] as Node3D).position.x * (skirts[1] as Node3D).position.x < 0.0, "los faldones quedan a cada lado")
	body.free()
	print("PARTS_TEST %s" % ("OK" if fails == 0 else "FALLÓ (%d)" % fails))
	quit(0 if fails == 0 else 1)
