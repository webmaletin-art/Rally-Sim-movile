## Exporta el catálogo del juego (autos, mejoras, gomas, piezas con su compatibilidad por auto, locales con posición) a tools/online/online_catalog.json.
## Ese archivo alimenta las semillas del SQL de la economía online (tools/online/gen_economy_seed.py): el servidor valida compras contra ESTE catálogo, no contra lo que diga el teléfono.
## Uso: godot --headless --path godot --script res://../tools/online/export_catalog.gd  (o copiar a godot/ y correr con -s)
extends SceneTree

const CityLayout := preload("res://game/city/city_layout.gd")
const PartCatalog := preload("res://game/car/part_catalog.gd")
const VehicleCustomization := preload("res://game/car/vehicle_customization.gd")
const Shops := preload("res://game/data/shops.gd")
const Release := preload("res://game/data/release.gd")

func _init() -> void:
	var cat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/catalog.json"))
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var out := {"vehicles": [], "upgrades": [], "tires": [], "parts": [], "shops": [], "finishes": []}
	var modular := []
	for id in cat["cars"]:
		var c: Dictionary = cat["cars"][id]
		var m := VehicleCustomization.supports(str(id))
		if m:
			modular.append(str(id))
		out["vehicles"].append({"id": str(id), "price": int(c["price"]), "starter": bool(c.get("starter", false)), "modular": m, "paint": (c["paint"] as Dictionary).duplicate(), "buyable": not Release.REWARD_CARS.has(str(id)) and not Release.PREMIUM_CARS.has(str(id))})
	# categoría → local que la ofrece
	var shop_of := {}
	for sid in Shops.SHOPS:
		var sh: Dictionary = Shops.SHOPS[sid]
		for p in (sh.get("parts", []) as Array):
			shop_of[str(p)] = str(sid)
	shop_of["tires"] = "wheels"
	for u in cat["upgrades"]:
		var cats: String = str(u["id"])
		if not shop_of.has(cats):
			# estética de «aero», etc.: el local que lo ofrece
			for sid in Shops.SHOPS:
				if (Shops.SHOPS[sid].get("parts", []) as Array).has(cats):
					shop_of[cats] = str(sid)
		var lv := (u["levels"] as Array)
		for i in range(1, lv.size()):
			out["upgrades"].append({"category": cats, "level": i, "price": int(lv[i].get("cost", 0)), "shop": str(shop_of.get(cats, "engine"))})
	for t in cat["tires"]:
		out["tires"].append({"id": str(t["id"]), "price": int(t["cost"])})
	# piezas modulares: compatibilidad real por auto (misma regla que usa el juego: reglas + ajuste de tamaño)
	var ctx_state := {"upg": {}, "tires": "street", "tune": {}}
	for pid in (PartCatalog.data()["parts"] as Dictionary):
		var p := PartCatalog.part(str(pid))
		if bool(p.get("hidden", false)):
			continue
		var cat_id := str(p["category"])
		var ok_for: Array = []
		for vid in modular:
			var ctx := VehicleCustomization.context(str(vid), vehicles, ctx_state)
			if bool(VehicleCustomization.can_install(str(pid), str(vid), ctx["V"], ctx["meta"])["ok"]):
				ok_for.append(str(vid))
		out["parts"].append({"id": str(pid), "category": cat_id, "price": int(p.get("price", 0)), "shop": str(PartCatalog.category(cat_id).get("shop", "paint")), "vehicles": ok_for})
	var city := CityLayout.new()
	city.build()
	for poi in city.pois:
		if str(poi.get("shop", "")) != "":
			var sid := str(poi["shop"])
			var sh: Dictionary = Shops.get_shop(sid)
			var pos: Vector2 = poi["pos"]
			out["shops"].append({"id": sid, "name": str(sh.get("name", sid)), "x": snappedf(pos.x, 0.1), "z": snappedf(pos.y, 0.1)})
	for f in cat["finishes"]:
		out["finishes"].append(str(f["id"]) if f is Dictionary else str(f))
	var f := FileAccess.open("res://../tools/online/online_catalog.json", FileAccess.WRITE)
	if f == null:
		f = FileAccess.open("/tmp/online_catalog.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("catálogo exportado: ", out["vehicles"].size(), " autos, ", out["upgrades"].size(), " mejoras, ", out["tires"].size(), " gomas, ", out["parts"].size(), " piezas, ", out["shops"].size(), " locales")
	quit()
