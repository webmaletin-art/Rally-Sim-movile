## Sectores del mundo abierto (region/sectors.gd + game/data/sectors.json + city/city_sectors.gd): abiertos Dream City y el corredor oeste, el resto en obra
## (barreras físicas en cada ruta que entra, sin aparecer ahí, sin carreras ni controles), y se puede abrir todo con open_all.
## Uso: godot --headless --path godot --script res://tests/sectors_test.gd
extends "res://tests/police_test.gd"

const Sectors := preload("res://game/region/sectors.gd")
const CitySectors := preload("res://game/city/city_sectors.gd")
const OW := preload("res://game/world/ow_events.gd")
const CityGps := preload("res://game/city/city_gps.gd")
const RegionServices := preload("res://game/region/region_services.gd")

func _run() -> void:
	var vehicles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/vehicles.json"))
	var tr := CityTrack.new()
	var rg = tr.region
	_check(Sectors.is_open(Vector2.ZERO) and Sectors.is_open(Vector2(-36800, -1700)) and Sectors.is_open(Vector2(-49800, -29000)), "abiertos: Dream City, Bahía Ámbar y Paso del Cóndor (sierra)")
	_check(not Sectors.is_open(Vector2(42800, 300)) and not Sectors.is_open(Vector2(30000, -47000)), "en obra: Puerto Alba y Monte Sol")
	# todo se abre con open_all (reversible)
	Sectors._open_all = true
	_check(Sectors.is_open(Vector2(42800, 300)), "open_all abre todo")
	Sectors.reload()
	Sectors._open_all = false
	Sectors.reload()
	# barreras
	var gates := CitySectors.find_gates(rg)
	_check(gates.size() > 5, "barreras de obra en las rutas que entran a sectores cerrados: %d" % gates.size())
	var bad := 0
	for g in gates:
		if not Sectors.is_open(g["p"]) or Sectors.is_open(g["p"] + g["dir"] * 400.0) and Sectors.is_open(g["p"] + g["dir"] * 120.0):
			bad += 1
	_check(bad <= gates.size() / 10, "cada barrera está del lado abierto, mirando hacia el cerrado (%d raras)" % bad)
	# lugares para aparecer, carreras y controles: sólo en sectores abiertos
	var sp_open := 0
	var sp_closed := 0
	for sp in RegionServices.spawn_list():
		if Sectors.is_open(Vector2(float(sp["x"]), float(sp["z"]))):
			sp_open += 1
		else:
			sp_closed += 1
	print("     lugares para aparecer: %d abiertos, %d en obra (no se muestran)" % [sp_open, sp_closed])
	_check(sp_open >= 3 and sp_closed > 0, "quedan lugares para aparecer en el oeste")
	var evs := OW.build(rg, CityGps.new(tr.city))
	var ev_bad := 0
	for e in evs:
		for q in e["pts"]:
			if not Sectors.is_open(q):
				ev_bad += 1
				break
	_check(evs.size() >= 10 and ev_bad == 0, "carreras sólo en sectores abiertos (%d, %d mal)" % [evs.size(), ev_bad])
	var probe: Array = _make(tr, vehicles, "hatch", 0.0, 0.0, 0.0)
	var cp_bad := 0
	for c in probe[1].checkpoints:
		if not Sectors.is_open(c["p"]):
			cp_bad += 1
	_check(probe[1].checkpoints.size() > 10 and cp_bad == 0, "controles policiales sólo en sectores abiertos (%d)" % probe[1].checkpoints.size())
	# a fondo contra tres barreras: el auto no pasa
	var race = probe[0]
	race.set("police", null)
	var cs := CitySectors.new()
	cs.setup(race)
	var me = probe[2]
	var through := 0
	var tried := 0
	for gi in [0, gates.size() / 2, gates.size() - 1]:
		var g: Dictionary = gates[gi]
		var start: Vector2 = g["p"] - g["dir"] * 120.0
		me.place(start.x, start.y, atan2(g["dir"].x, g["dir"].y))
		var drv := PoliceDriver.new()
		drv.mode = "path"
		drv.path = PackedVector2Array([start, g["p"] + g["dir"] * 200.0])
		drv.grip = 1.0
		me.driver = drv
		var maxa := -1e9
		for i in 120 * 20:
			me.step(1.0 / 120.0)
			maxa = maxf(maxa, (Vector2(me.phys.px, me.phys.pz) - g["p"]).dot(g["dir"]))
		tried += 1
		if maxa > 4.0:
			through += 1
		print("     barrera %d: lo más lejos que llegó %.1f m (del lado cerrado)" % [gi, maxa])
	_check(tried == 3 and through == 0, "a fondo no se pasa ninguna barrera")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
