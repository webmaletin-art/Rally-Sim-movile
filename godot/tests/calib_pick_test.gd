## La pantalla «CALIDAD GRÁFICA» entra en la pantalla (reporte del dueño, 20/10/2026: «no me carga todo, no me deja hacer scroll, no veo el resto del texto»):
##  · con la pantalla de siempre (1280×576) entra entera: el panel y el botón «MEDIR AUTOMÁTICAMENTE» quedan dentro y no hace falta deslizar;
##  · en una pantalla más baja (400 de alto) el panel sigue dentro de la pantalla, el botón de medir queda a la vista y lo del medio se desliza;
##  · cada calidad se puede elegir (3 columnas, 5 calidades) y al elegir se cierra y avisa cuál.
## Uso: godot --headless --path godot --script res://tests/calib_pick_test.gd
extends SceneTree

const Autotune := preload("res://game/autotune.gd")
const CalibUi := preload("res://game/ui/calib_ui.gd")
const Tr := preload("res://game/i18n/tr.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _frames(n := 8) -> void:
	for i in n:
		await process_frame

func _find(n: Node, pred: Callable) -> Node:
	if pred.call(n):
		return n
	for c in n.get_children():
		var r := _find(c, pred)
		if r != null:
			return r
	return null

func _init() -> void:
	_run()

## Abre la pantalla en un SubViewport del tamaño dado y devuelve {vp, dim, panel, measure, scroll, picked}
func _open(size: Vector2i) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	get_root().add_child(vp)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(root)
	var auto := {"rec": 3, "k60": 0.33, "probes": {0: {"avg": 27.0}, 1: {"avg": 27.0}, 2: {"avg": 27.0}, 3: {"avg": 27.0}}, "est": {4: 17.0}}
	var picked: Array = []
	var measured: Array = []
	var dim: Control = CalibUi.pick(root, Autotune.presets_for(auto), 3, func(i: int) -> void: picked.append(i), Autotune.preset_info(auto), true, func() -> void: measured.append(1), Autotune.preset_order(3))
	await _frames()
	var panel := _find(dim, func(n: Node) -> bool: return n is PanelContainer) as Control
	var measure := _find(dim, func(n: Node) -> bool: return n is Button and "MEDIR" in (n as Button).text) as Button
	var scroll := _find(dim, func(n: Node) -> bool: return n is ScrollContainer) as ScrollContainer
	return {"vp": vp, "dim": dim, "panel": panel, "measure": measure, "scroll": scroll, "picked": picked, "measured": measured}

func _inside(c: Control, size: Vector2i) -> bool:
	var r := c.get_global_rect()
	return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= float(size.x) + 0.5 and r.end.y <= float(size.y) + 0.5

func _run() -> void:
	Tr.set_language("es")
	# ── pantalla normal
	var big := Vector2i(1280, 576)
	var a: Dictionary = await _open(big)
	check(a["panel"] != null and a["measure"] != null and a["scroll"] != null, "la pantalla trae el panel, el botón de medir y el scroll")
	check(_inside(a["panel"], big), "1280×576: el panel entra entero en la pantalla (%s)" % str((a["panel"] as Control).get_global_rect()))
	check(_inside(a["measure"], big), "1280×576: «MEDIR AUTOMÁTICAMENTE» queda dentro de la pantalla")
	var sc: ScrollContainer = a["scroll"]
	var content: Control = sc.get_child(0)
	check(sc.size.y + 1.0 >= content.get_combined_minimum_size().y, "1280×576: el contenido entra sin deslizar (scroll %d, contenido %d)" % [int(sc.size.y), int(content.get_combined_minimum_size().y)])
	var buttons: Array = []
	var stack: Array = [a["dim"]]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and not ("MEDIR" in (n as Button).text):
			buttons.append(n)
		stack.append_array(n.get_children())
	check(buttons.size() == 5, "las 5 calidades se pueden elegir (%d botones)" % buttons.size())
	var all_in := true
	for b in buttons:
		if not _inside(b, big):
			all_in = false
	check(all_in, "1280×576: todos los botones de calidad quedan a la vista")
	# elegir una calidad: avisa cuál y se cierra
	var pick_btn: Button = null
	for b in buttons:
		if (b as Button).text.begins_with("NORMAL"):
			pick_btn = b
	check(pick_btn != null, "hay un botón NORMAL")
	if pick_btn != null:
		pick_btn.pressed.emit()
		await _frames(3)
		check(a["picked"] == [2], "elegir NORMAL avisa la calidad 2 (%s)" % str(a["picked"]))
		check(not is_instance_valid(a["dim"]) or (a["dim"] as Node).is_queued_for_deletion(), "…y la pantalla se cierra")
	(a["vp"] as Node).queue_free()
	await _frames(2)
	# ── pantalla baja: se desliza pero nada queda fuera
	var small := Vector2i(1280, 400)
	var s: Dictionary = await _open(small)
	check(_inside(s["panel"], small), "1280×400: el panel sigue dentro de la pantalla (%s)" % str((s["panel"] as Control).get_global_rect()))
	check(_inside(s["measure"], small), "1280×400: «MEDIR AUTOMÁTICAMENTE» sigue a la vista (fijo abajo)")
	var sc2: ScrollContainer = s["scroll"]
	var c2: Control = sc2.get_child(0)
	check(c2.get_combined_minimum_size().y > sc2.size.y + 1.0, "1280×400: el contenido no entra y se desliza (scroll %d, contenido %d)" % [int(sc2.size.y), int(c2.get_combined_minimum_size().y)])
	sc2.scroll_vertical = 100000
	await _frames(2)
	check(sc2.scroll_vertical > 0, "…y el scroll llega al final del texto (%d)" % sc2.scroll_vertical)
	(s["vp"] as Node).queue_free()
	await _frames(2)
	quit(1 if fail else 0)
