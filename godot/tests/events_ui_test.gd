## Pantalla de EVENTOS (ui/events_ui.gd), [B] 19/10/2026: se arma con tarjetas de mentira, se elige un evento, los botones «IR AL EVENTO» / «SALIR DEL EVENTO» avisan,
## el puntito de «nuevo» está y la imagen de cada tipo existe. Con el argumento --shot=ruta.png y una pantalla (xvfb) guarda una captura.
## Corta (≈ 2 s). Uso: tools/test/run_test.sh events_ui_test 30
extends SceneTree

const EventsUi := preload("res://game/ui/events_ui.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _card(id: int, kind: String, live: bool, extra := {}) -> Dictionary:
	var c := {"id": id, "kind": kind, "icon": "🌀", "title": "Desafío de drift", "descr": "Sumá puntos derrapando en la Plaza de Drift.", "how": "Entrá a la Plaza de Drift y sumá todos los puntos que puedas.",
		"live": live, "done": false, "when": "En vivo · termina en 8h26", "when_short": "termina en 8h26", "reward": "premios: 1º KAIRÓS KL5 Sport", "reward_short": "1º KAIRÓS KL5 Sport · 2º $20000",
		"prizes": [{"car": "hatch", "icon": "🥇", "text": "1º · KAIRÓS KL5 Sport"}, {"car": "", "icon": "🥈", "text": "2º · $20000 de vale de taller + gomas Drift"}],
		"progress": "tu mejor: 1250 pts · vas 3º de 40", "car": "hatch", "go": true, "go_label": "IR A LA PLAZA DE DRIFT", "active": false, "new": true}
	c.merge(extra, true)
	return c

func _init() -> void:
	for k in ["drift", "escape", "bounty", "reach", "record", "season", "default"]:
		_check(EventsUi.image_for(k) != null, "hay imagen para «%s»" % k)
	var ui := EventsUi.new()
	var cards: Array = [_card(1, "drift", true, {"active": true}), _card(2, "season", true, {"title": "Temporada de la semana", "icon": "🏅", "go": false, "go_label": "IR AL EVENTO", "new": false}),
		_card(3, "reach", false, {"title": "Contrarreloj entre ciudades", "icon": "🏁", "live": false, "when": "Empieza en 1h05", "when_short": "empieza en 1h05"})]
	ui.cards_fn = func() -> Array: return cards
	ui.notes_fn = func() -> Array: return [{"t": 1, "text": "📢 Fulano ganó «Cacería»", "new": true}]
	ui.help_fn = func() -> String: return "❓ AYUDA\nLas carreras se descubren manejando."
	var state := {"seen": 0, "go": -1, "cancel": -1, "closed": 0}
	ui.seen_fn = func() -> void: state["seen"] = int(state["seen"]) + 1
	ui.go_pressed.connect(func(id: int) -> void: state["go"] = id)
	ui.cancel_pressed.connect(func(id: int) -> void: state["cancel"] = id)
	ui.closed.connect(func() -> void: state["closed"] = int(state["closed"]) + 1)
	root.size = Vector2(1290, 580)
	root.add_child(ui)
	ui.open()
	await process_frame
	await process_frame
	_check(ui.visible and int(state["seen"]) == 1, "al abrir se avisa que todo quedó visto (se apaga el puntito)")
	_check(ui.sel == 1, "queda elegido el primer evento (el que está en vivo)")
	_check(_count_buttons(ui, "SALIR DEL EVENTO") == 1, "el evento en curso muestra «SALIR DEL EVENTO»")
	_check(_count_buttons(ui, "IR A LA PLAZA DE DRIFT") == 1, "y el botón «IR» con el nombre del lugar")
	var go := _find_button(ui, "IR A LA PLAZA DE DRIFT")
	go.pressed.emit()
	_check(int(state["go"]) == 1, "tocar IR avisa con el id del evento")
	_find_button(ui, "SALIR DEL EVENTO").pressed.emit()
	_check(int(state["cancel"]) == 1, "tocar SALIR DEL EVENTO avisa con el id del evento")
	# elegir otro evento (sin lugar): el botón IR queda apagado y no hay SALIR
	ui.sel = 2
	ui.refresh()
	await process_frame
	var go2 := _find_button(ui, "IR AL EVENTO")
	_check(go2 != null and go2.disabled and _count_buttons(ui, "SALIR DEL EVENTO") == 0, "un evento sin lugar fijo: IR apagado y sin SALIR")
	ui.open("novedades")
	await process_frame
	_check(_has_text(ui, "Fulano ganó"), "NOVEDADES muestra lo que pasó")
	ui.open("ayuda")
	await process_frame
	_check(_has_text(ui, "Las carreras se descubren") and not _has_text(ui, "❓ AYUDA\n"), "AYUDA muestra el texto")
	ui.cards_fn = func() -> Array: return []
	ui.open("eventos")
	await process_frame
	_check(_has_text(ui, "Ahora no hay eventos"), "sin eventos: un mensaje, no una pantalla vacía")
	ui.close()
	_check(not ui.visible and int(state["closed"]) == 1, "ATRÁS cierra y avisa")
	# captura (opcional)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			ui.cards_fn = func() -> Array: return cards
			ui.sel = 1
			ui.open("eventos")
			for i in 4:
				await process_frame
			var img := root.get_texture().get_image()
			img.save_png(a.substr(7))
			print("captura: ", a.substr(7))
			ui.sel = 3
			ui.refresh()
			for i in 3:
				await process_frame
			root.get_texture().get_image().save_png(a.substr(7).replace(".png", "_2.png"))
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)

func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)

func _count_buttons(ui: Node, txt: String) -> int:
	var all: Array = []
	_walk(ui, all)
	var k := 0
	for n in all:
		if n is Button and (n as Button).text.contains(txt):
			k += 1
	return k

func _find_button(ui: Node, txt: String) -> Button:
	var all: Array = []
	_walk(ui, all)
	for n in all:
		if n is Button and (n as Button).text.contains(txt) and not (n as Node).is_queued_for_deletion():
			return n
	return null

func _has_text(ui: Node, txt: String) -> bool:
	var all: Array = []
	_walk(ui, all)
	for n in all:
		if (n as Node).is_queued_for_deletion():
			continue
		if n is Label and (n as Label).text.contains(txt):
			return true
	return false
