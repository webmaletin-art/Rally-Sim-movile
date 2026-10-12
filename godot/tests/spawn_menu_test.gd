## La pantalla «¿DÓNDE APARECER?» lista los estacionamientos de Dream City y los pueblos de la región con un mapa que marca el lugar elegido.
## Uso: godot --headless --path godot --script res://tests/spawn_menu_test.gd -- --menu --noconsent
extends SceneTree

const RegionServices := preload("res://game/region/region_services.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _frames(n := 4) -> void:
	for i in n:
		await process_frame

func _find_by_text(n: Node, needle: String) -> Label:
	if n is Label and (n as Label).text.contains(needle):
		return n as Label
	for c in n.get_children():
		var r := _find_by_text(c, needle)
		if r != null:
			return r
	return null

func _init() -> void:
	_run()

func _run() -> void:
	var ps: PackedScene = load("res://game/main.tscn")
	var app: Node = ps.instantiate()
	get_root().add_child(app)
	await _frames(40)
	var menu: Node = app.get("menu")
	var spawns := RegionServices.spawn_list()
	check(spawns.size() >= 5, "hay lugares de la región para aparecer (%d)" % spawns.size())
	menu.call("go", "spawn")
	await _frames()
	var body: Node = menu.get("body")
	check(_find_by_text(body, "🅿") != null, "sigue el estacionamiento de Dream City")
	var btn := _find_by_text(body, "APARECER AHÍ")
	check(btn != null, "el botón de aparecer en un pueblo de la región")
	check(RegionServices.MAP_RECT.has_point(Vector2(float(spawns[0]["x"]), float(spawns[0]["z"]))), "el primer lugar cae dentro del mapa de la región")
	for sp in spawns:
		check(RegionServices.MAP_RECT.has_point(Vector2(float(sp["x"]), float(sp["z"]))), "«%s» entra en el mapa" % str(sp["name"]))
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
