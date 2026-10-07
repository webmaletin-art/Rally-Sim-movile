## MapData.convert_doc: un mapa personalizado v2 (con tramos de distinta superficie, árboles por tramo, rivales y evento de la carrera) se convierte a ruta + mapa + parche como espera el juego.
## Uso: godot --headless --path godot --script res://tests/map_data_test.gd
extends SceneTree

const MapData := preload("res://game/data/map_data.gd")
const RouteTrack := preload("res://game/track/route_track.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var pts: Array = []
	for i in 16:
		var a := TAU * float(i) / 16.0
		pts.append([600.0 * cos(a), 40.0 + 10.0 * sin(a * 2.0), 400.0 * sin(a)])
	var doc := {"format": "dreamracing-route", "version": 2, "id": "fixt", "name": "Fixture", "icon": "🏁", "type": "circuit", "surface": "asphalt", "reverse": true,
		"route": {"halfWidth": 4.6, "shoulder": 2.0, "points": pts},
		"sections": [{"from": 0.0, "to": 0.4, "surface": "asphalt", "density": 1.0}, {"from": 0.4, "to": 0.7, "surface": "mud", "density": 0.2}, {"from": 0.7, "to": 1.0, "surface": "sand"}],
		"scenery": {"trees": "pine", "density": 0.5}, "race": {"laps": 3}, "rivals": {"count": 5, "difficulty": 0.75}, "career": {"tier": "continental", "event": "c1"}}
	var out: Dictionary = MapData.convert_doc(doc)
	check(not out.is_empty() and out["id"] == "fixt", "convierte el mapa v2")
	var route: Dictionary = out["route"]
	var surf: Array = route["surf"]
	check(surf.size() == 3 and int(surf[0]["s"]) == 0 and int(surf[1]["s"]) == 5 and int(surf[2]["s"]) == 6, "tramos: asfalto → barro → arena (códigos 0, 5, 6)")
	check(out["map"]["mode"] == "dirt", "con tramos de tierra el modo base es tierra")
	check(is_equal_approx(float(surf[0]["mu"]) * 0.6, 1.0), "el agarre del asfalto vuelve a 1 sobre la base de tierra")
	check(out.has("map_rev") and out["map_rev"]["reverse"] == true, "versión inversa")
	check(out["patch"]["event"] == "c1" and int(out["patch"]["ai"]) == 5 and int(out["patch"]["laps"]) == 3, "parche del evento c1: 5 rivales, 3 vueltas")
	check(is_equal_approx(float(out["patch"]["skill"]), MapData.skill_of(0.75)) and MapData.skill_of(0.0) < 0.76 and MapData.skill_of(1.0) > 0.96, "la dificultad 0–100 % va de más fácil que Debut a más difícil que Leyenda")
	check(MapData.convert_doc({"format": "dreamracing-route", "version": 1}).is_empty(), "la v1 no se lee en el juego (el importador la convierte)")
	# la pista arma con las superficies por tramo, el atlas y la densidad por tramo
	MapData.load_all()["routes"]["fixt"] = route
	RouteTrack._routes = MapData.load_all()["routes"]
	var tr = RouteTrack.new("fixt", "dirt")
	check(tr.atlas and tr.road_col.size() == tr.n and tr.road_surf.size() == tr.n and tr.scen_w.size() == tr.n, "RouteTrack: atlas, superficies y densidad por muestra")
	var mid := int(tr.n * 0.55)
	check(int(tr.road_surf[mid]) == 5 and int(tr.road_surf[int(tr.n * 0.2)]) == 0 and int(tr.road_surf[int(tr.n * 0.85)]) == 6, "la superficie de cada muestra es la de su tramo")
	check(is_equal_approx(tr.scen_w[mid], 0.2) and is_equal_approx(tr.scen_w[int(tr.n * 0.2)], 1.0), "densidad de árboles por tramo")
	check(tr.ground_info(tr.samples[mid].x, tr.samples[mid].z).y == 5.0, "la física pisa barro en el tramo de barro")
	var m: Mesh = tr.build_road_mesh()
	check(m != null and m.get_surface_count() == 1, "el camino con atlas se dibuja")
	quit(1 if fail else 0)
