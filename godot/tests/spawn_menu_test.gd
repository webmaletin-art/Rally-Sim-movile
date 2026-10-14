## La pantalla «¿DÓNDE APARECER?» lista los estacionamientos de Dream City y los pueblos de la región con un mapa que marca el lugar elegido.
## Uso: godot --headless --path godot --script res://tests/spawn_menu_test.gd -- --menu --noconsent
extends SceneTree

const Release := preload("res://game/data/release.gd")

const RegionServices := preload("res://game/region/region_services.gd")
const SpawnMap := preload("res://game/ui/spawn_map.gd")
const Tr := preload("res://game/i18n/tr.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _frames(n := 4) -> void:
	for i in n:
		await process_frame

func _find_by_text(n: Node, needle: String) -> Control:
	if n is Label and (n as Label).text.contains(needle):
		return n as Label
	if n is Button and (n as Button).text.contains(needle):
		return n as Button
	for c in n.get_children():
		var r := _find_by_text(c, needle)
		if r != null:
			return r
	return null

func _find_map(n: Node) -> Control:
	if n.get_script() == SpawnMap:
		return n as Control
	for c in n.get_children():
		var r := _find_map(c)
		if r != null:
			return r
	return null

## un toque en el mapa (botón izquierdo apretado y soltado en el mismo lugar)
func _tap(map: Control, p: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		map._gui_input(ev)

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
	Tr.set_language("es") # los textos se buscan en español: sin esto, en una máquina con el teléfono/idioma en inglés (la compilación de GitHub) el botón sale traducido
	# (desde el 14/10/2026 los pueblos se habilitan al llegar manejando, city/city_reach.gd: se marca uno como alcanzado; los demás salen con candado)
	var prof0: RefCounted = menu.get("profile")
	prof0.set_setting("reached", [str(spawns[0]["name"])])
	menu.call("go", "spawn")
	await _frames()
	var body: Node = menu.get("body")
	check(_find_by_text(body, "APARECER") != null, "el botón de aparecer")
	var inside := true
	for sp in spawns:
		inside = inside and RegionServices.MAP_RECT.has_point(Vector2(float(sp["x"]), float(sp["z"])))
	check(inside, "los %d lugares de la región caen dentro del mapa" % spawns.size())
	var names := {}
	for sp in spawns:
		names[str(sp["name"])] = true
	check(names.size() == spawns.size(), "los nombres de los lugares no se repiten")
	# el mapa se toca: un toque sobre un pueblo lo elige; tocar Dream City pasa de un estacionamiento al siguiente
	var map := _find_map(body)
	check(map != null, "hay un mapa en la pantalla")
	if map != null:
		await _frames(3)
		var prof: RefCounted = menu.get("profile")
		var town := {}
		var locked := 0
		for mk in map.marks:
			if str(mk["kind"]) in ["pueblo", "ciudad"] and town.is_empty():
				town = mk
			elif str(mk["kind"]) == "locked":
				locked += 1
		check(not town.is_empty(), "el mapa tiene el pueblo alcanzado para elegir")
		check(locked == spawns.size() - 1 or Release.dev(prof), "los pueblos a los que no se llegó salen con candado (%d)" % locked)
		if not town.is_empty():
			_tap(map, map.to_screen(town["pos"]))
			await _frames(2)
			check(str(prof.setting("spawnPick")) == str(town["key"]), "tocar un pueblo en el mapa lo elige (%s)" % str(town["key"]))
			check(map.selected == str(town["key"]), "el mapa marca el pueblo tocado")
		var seen := {}
		for k in 3:
			_tap(map, map.to_screen(Vector2.ZERO))
			await _frames(2)
			seen[str(prof.setting("spawnPick"))] = true
		check(seen.size() == 3 and seen.has("park0") and seen.has("park1") and seen.has("park2"), "tocar Dream City recorre los 3 estacionamientos %s" % str(seen.keys()))
		# un toque lejos de todo no cambia nada
		var before := str(prof.setting("spawnPick"))
		_tap(map, Vector2(2.0, 2.0))
		await _frames(2)
		check(str(prof.setting("spawnPick")) == before, "un toque en el vacío no cambia el lugar")
	check(RegionServices.available(), "la región está completa (datos + lista de lugares)")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
