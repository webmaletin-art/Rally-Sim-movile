extends RefCounted
## Pantalla del modo aventura en el menú: el mapa de la Ruta de los Sueños con el avance, seguir / comenzar, las habilidades,
## cómo se juega, repetir etapas ya ganadas y reiniciar la aventura.

const Kit := preload("res://game/ui/ui_kit.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const AdvHud := preload("res://game/adventure/adv_hud.gd")

var m: Node # menu.gd

func build(name: String, arg) -> void:
	match name:
		"adventure": _main()
		"adv_skills": _skills()
		"adv_help": _help(int(arg) if arg != null else 0)
		"adv_stages": _stages()
		"adv_start": _start_info()

func _text(t: String, size := 18, col := Kit.TEXT) -> void:
	var l := Kit.label(t, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 360
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.body.add_child(l)

func _main() -> void:
	m.set_title("AVENTURA")
	var st := AdvData.state(m.profile)
	m.refresh_car(AdvData.CAR, AdvData.car_state(st)) # el DR Bisonte negro de la aventura en la sala
	m.adv_car_shown = true
	var stage: int = mini(int(st["stage"]), AdvRoute.STAGES.size() - 1)
	var done: bool = st["done"] == true
	m.body.add_child(Kit.label("La Ruta de los Sueños", 30, Kit.GOLD))
	var mp := AdvHud.RouteMap.new()
	mp.cur = stage if not done else -1
	mp.done = int(st["stage"])
	mp.custom_minimum_size = Vector2(0, 210)
	m.body.add_child(mp)
	if done:
		_text("🏆 ¡Completaste la aventura! El DR Bisonte XR está en tu garaje. Podés volver a correr cualquier etapa.", 18, Kit.GREEN)
	elif st["started"] == true:
		var S: Dictionary = AdvRoute.STAGES[stage]
		_stage_image(stage)
		_text("Etapa %d de %d: %s — %s" % [stage + 1, AdvRoute.STAGES.size(), S["name"], S["sub"]], 19)
		_text("Rival: %s%s" % [S["rival"]["name"], ("  👑" if S["rival"].get("boss", false) else "")], 17, Kit.MUTED)
	else:
		_text("Una sola ruta larguísima, de estación en estación: %d etapas, ciudades, campos, montaña, túneles, una cantera y la nieve. En cada etapa hay un rival que tenés que pasar." % AdvRoute.STAGES.size(), 18)
	if not done:
		var lbl := "▶ SEGUIR LA AVENTURA · ETAPA %d" % (stage + 1) if st["started"] == true else "▶ COMENZAR LA AVENTURA"
		m.body.add_child(m.menu_button(lbl, "%d puntos de habilidad para gastar" % int(st["points"]) if int(st["points"]) > 0 else "", func() -> void:
			if st["started"] == true or st["intro"] == true:
				_play(stage, false)
			else:
				m.go("adv_start"), true))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.body.add_child(g)
	var items := [
		["⭐ HABILIDADES", "%d puntos" % int(st["points"]), func(): m.go("adv_skills")],
		["📖 CÓMO SE JUEGA", "estaciones, talleres, rival", func(): m.go("adv_help", 0)],
		["🗺 ETAPAS", "repetir las ganadas", func(): m.go("adv_stages")],
		["↺ REINICIAR", "empezar de cero", func(): _confirm_reset()],
	]
	for it in items:
		var b: Button = m.menu_button(str(it[0]), str(it[1]), it[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(b)

## Antes de empezar por primera vez: qué es y cómo se maneja
func _start_info() -> void:
	m.set_title("ANTES DE EMPEZAR")
	m.body.add_child(Kit.label("SIMULACIÓN TOTAL…", 30, Kit.ACCENT))
	m.body.add_child(Kit.label("…con un poco de ayuda", 24, Kit.GOLD))
	_text("La aventura se maneja como un simulador: el auto tiene peso, las gomas se deslizan y cada superficie agarra distinto. Para que sea disfrutable de punta a punta tiene ABS y un poco de control de tracción y de estabilidad (se pueden cambiar en Opciones → Física).")
	_text("Manejás el DR Bisonte XR negro del equipo Dream Racing. Primero vas a ver una presentación, después la explicación de cómo se juega y el mapa, y largás desde la Estación Aurora.", 18, Kit.MUTED)
	m.body.add_child(m.menu_button("▶ EMPEZAR", "presentación y primera etapa", func(): _play(0, true), true))

## Foto de la etapa (la misma de la pantalla de carga)
func _stage_image(si: int) -> void:
	var path := "res://game/ui/tracks/adv%d.jpg" % si
	if not ResourceLoader.exists(path):
		return
	var tr := TextureRect.new()
	tr.texture = load(path)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size = Vector2(0, 150)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.body.add_child(tr)

func _play(stage: int, intro: bool) -> void:
	var c := {"type": "adventure", "stage": stage, "back": "adventure"}
	if intro:
		c["intro"] = true
	m.app.start_race(c)

func _skills() -> void:
	m.set_title("HABILIDADES")
	var st := AdvData.state(m.profile)
	m.body.add_child(Kit.label("PUNTOS: %d" % int(st["points"]), 26, Kit.GOLD))
	_text("Cada etapa ganada te da %d puntos. Cada nivel cuesta tantos puntos como su número (nivel 1 = 1 punto … nivel 5 = 5). Las habilidades valen solo en la aventura." % AdvData.POINTS_PER_STAGE, 16, Kit.MUTED)
	var sk: Dictionary = st["skills"]
	for S in AdvData.SKILLS:
		var id := str(S["id"])
		var lvl := int(sk.get(id, 0))
		var p := Kit.panel(10, Kit.PANEL2)
		m.body.add_child(p)
		var row := Kit.hbox(12)
		p.add_child(row)
		row.add_child(Kit.label(str(S["icon"]), 34))
		var col := Kit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Kit.label("%s  %s" % [S["name"], "●".repeat(lvl) + "○".repeat(AdvData.MAX_LEVEL - lvl)], 21))
		var dl := Kit.label(str(S["desc"]) + "\n" + str(S["per"]), 15, Kit.MUTED)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.custom_minimum_size.x = 240
		col.add_child(dl)
		if lvl < AdvData.MAX_LEVEL:
			var c := AdvData.cost(lvl + 1)
			var b := Kit.button("+1 (%d pt)" % c, func() -> void:
				var l2 := int(sk.get(id, 0))
				var c2 := AdvData.cost(l2 + 1)
				if l2 < AdvData.MAX_LEVEL and int(st["points"]) >= c2:
					sk[id] = l2 + 1
					st["points"] = int(st["points"]) - c2
					m.profile.save()
					m.sfx.play("buy")
				m.go("adv_skills", null, false), int(st["points"]) >= c, 17, Vector2(130, 50))
			b.disabled = int(st["points"]) < c
			row.add_child(b)
		else:
			row.add_child(Kit.label("MÁX", 18, Kit.GREEN))

const HELP := [
	["CÓMO SE JUEGA", "• En cada etapa hay un rival adelante tuyo: pasalo y llegá primero a la próxima estación de servicio.\n• El rival maneja a tu ritmo: si vas con cuidado, él también; si apretás al límite, él aprieta. Si lo pasás, va a pelear por recuperar el puesto, pero nunca te choca a propósito.\n• Si llega él primero, repetís la etapa desde la estación anterior.\n• Al final te esperan dos jefes súper rápidos."],
	["ESTACIONES DE SERVICIO", "Son los puntos de guardado. Cuando llegás primero el auto entra solo, carga combustible y se guarda el avance. Antes de seguir podés leer la GUÍA de la próxima etapa (te explica un ajuste y te recomienda uno), ajustar el auto y gastar los puntos de habilidad."],
	["TALLERES", "En el camino hay talleres mecánicos. Un cartel te avisa antes: INGRESAR o SEGUIR. Entrar y salir no cuesta nada; cada reparación lleva unos segundos… y el rival no te espera.\nLos golpes dañan el auto: el motor pierde potencia, la dirección tira hacia un costado y la suspensión pierde agarre."],
	["CÁMARAS", "La aventura se juega con tres cámaras: tercera persona, adentro con el piloto y sobre el capó. Cambialas con el botón CAM."],
]

func _help(page: int) -> void:
	m.set_title("CÓMO SE JUEGA")
	var P: Array = HELP[clampi(page, 0, HELP.size() - 1)]
	m.body.add_child(Kit.label(str(P[0]), 28, Kit.ACCENT))
	_text(str(P[1]), 19)
	var row := Kit.hbox(10)
	m.body.add_child(row)
	if page > 0:
		var b0 := Kit.button("← ANTERIOR", func(): m.go("adv_help", page - 1, false), false, 20)
		b0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b0)
	if page < HELP.size() - 1:
		var b1 := Kit.button("SIGUIENTE ▶", func(): m.go("adv_help", page + 1, false), true, 20)
		b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b1)

func _stages() -> void:
	m.set_title("ETAPAS")
	var st := AdvData.state(m.profile)
	var reached := int(st["stage"])
	var best: Dictionary = st["best"]
	for si in AdvRoute.STAGES.size():
		var S: Dictionary = AdvRoute.STAGES[si]
		var open := si <= reached
		var sub := str(S["sub"])
		if best.has(str(si)):
			sub += "  ·  mejor tiempo " + Kit.fmt_time(float(best[str(si)]))
		var b: Button = m.menu_button("%d · %s%s" % [si + 1, S["name"], "" if open else "  🔒"], sub, func(): _play(si, false), si == reached and not (st["done"] == true), open)
		m.body.add_child(b)

func _confirm_reset() -> void:
	for c in m.body.get_children():
		c.queue_free()
	m.body.add_child(Kit.label("¿Reiniciar la aventura?", 28, Kit.RED))
	_text("Se pierde el avance de las etapas, los puntos y las habilidades de la aventura.", 18, Kit.MUTED)
	m.body.add_child(Kit.button("Sí, empezar de cero", func():
		AdvData.reset(m.profile)
		m.go("adventure", null, false), false, 22))
	m.body.add_child(Kit.button("Cancelar", func(): m.go("adventure", null, false), true, 22))
