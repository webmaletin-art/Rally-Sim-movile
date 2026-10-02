extends RefCounted
## Pantalla del modo aventura en el menú: el mapa de la Ruta de los Sueños con el avance, seguir / comenzar, las habilidades,
## cómo se juega, repetir etapas ya ganadas y reiniciar la aventura.

const Kit := preload("res://game/ui/ui_kit.gd")
const AdvRoute := preload("res://game/adventure/adv_route.gd")
const AdvData := preload("res://game/adventure/adv_data.gd")
const AdvHud := preload("res://game/adventure/adv_hud.gd")
const Release := preload("res://game/data/release.gd")

var m: Node # menu.gd

func build(name: String, arg) -> void:
	match name:
		"adventure": _main()
		"adv_skills": _skills()
		"adv_help": _help(int(arg) if arg != null else 0)
		"adv_stages": _stages()
		"adv_start": _start_info()

func _text(t: String, size := 16, col := Kit.TEXT) -> void:
	m.body.add_child(Kit.wrap(t, size, col, 300))

func _main() -> void:
	m.set_title("AVENTURA")
	var st := AdvData.state(m.profile)
	m.refresh_car(AdvData.CAR, AdvData.car_state(st)) # el DR Bisonte negro de la aventura en la sala
	m.adv_car_shown = true
	var limit := Release.adventure_limit(m.profile)
	var stage: int = mini(int(st["stage"]), AdvRoute.STAGES.size() - 1)
	var done: bool = st["done"] == true
	var capped := stage >= limit and not done
	if capped:
		stage = limit - 1
	var mp := AdvHud.RouteMap.new()
	mp.cur = stage if not done else -1
	mp.done = mini(int(st["stage"]), limit)
	mp.custom_minimum_size = Vector2(0, 122)
	m.body.add_child(mp)
	if done:
		_text("🏆 ¡Completaste la aventura! El DR Bisonte XR está en tu garaje. Podés volver a correr cualquier etapa.", 15, Kit.GREEN)
	elif st["started"] == true:
		var S: Dictionary = AdvRoute.STAGES[stage]
		var info := Kit.hbox(10)
		m.body.add_child(info)
		var th := _thumb(stage)
		if th != null:
			info.add_child(th)
		var col := Kit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(col)
		col.add_child(Kit.label("%s %d/%d" % [tr("Etapa"), stage + 1, AdvRoute.STAGES.size()], 13, Kit.MUTED))
		var nl := Kit.label(str(S["name"]), 20, Kit.TEXT)
		nl.clip_text = true
		nl.custom_minimum_size.x = 40
		col.add_child(nl)
		col.add_child(Kit.wrap(str(S["sub"]), 13, Kit.MUTED, 150))
		col.add_child(Kit.label("%s: %s%s" % [tr("Rival"), S["rival"]["name"], ("  👑" if S["rival"].get("boss", false) else "")], 13, Kit.MUTED))
	else:
		_text("Una sola ruta larguísima, de estación en estación: ciudades, campos, montaña, túneles, una cantera y la nieve. En cada etapa hay un rival que tenés que pasar.", 15)
	if capped:
		_text("🚧 Completaste la primera parte. Las próximas etapas llegan con una actualización.", 14, Kit.GOLD)
	if not done and not capped:
		var lbl := "▶ SEGUIR · ETAPA %d" % (stage + 1) if st["started"] == true else "▶ COMENZAR LA AVENTURA"
		m.body.add_child(m.menu_button(lbl, "%d puntos de habilidad para gastar" % int(st["points"]) if int(st["points"]) > 0 else "", func() -> void:
			if st["started"] == true or st["intro"] == true:
				_play(stage, false)
			else:
				m.go("adv_start"), true))
	var g := Kit.grid(4, 6, 6)
	m.body.add_child(g)
	var items := [
		["⭐", "HABILIDADES", "%d pts" % int(st["points"]), func(): m.go("adv_skills")],
		["📖", "CÓMO SE JUEGA", "", func(): m.go("adv_help", 0)],
		["🗺", "ETAPAS", "", func(): m.go("adv_stages")],
		["↺", "REINICIAR", "", func(): _confirm_reset()],
	]
	for it in items:
		g.add_child(m.tile(str(it[0]), str(it[1]), str(it[2]), it[3], false, 70.0))

## Miniatura de la etapa (la misma foto de la pantalla de carga)
func _thumb(si: int) -> Control:
	var path := "res://game/ui/tracks/adv%d.jpg" % si
	if not ResourceLoader.exists(path):
		return null
	var tr_ := TextureRect.new()
	tr_.texture = load(path)
	tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr_.custom_minimum_size = Vector2(150, 90)
	return tr_

## Antes de empezar por primera vez: qué es y cómo se maneja
func _start_info() -> void:
	m.set_title("ANTES DE EMPEZAR")
	m.body.add_child(Kit.label("SIMULACIÓN TOTAL…", 26, Kit.ACCENT))
	m.body.add_child(Kit.label("…con un poco de ayuda", 20, Kit.GOLD))
	_text("La aventura se maneja como un simulador: el auto tiene peso, las gomas se deslizan y cada superficie agarra distinto. Para que sea disfrutable de punta a punta tiene ABS y un poco de control de tracción y de estabilidad (se pueden cambiar en Opciones → Física).")
	_text("Manejás el DR Bisonte XR negro del equipo Dream Racing. Primero ves una presentación, después la explicación de cómo se juega y el mapa, y largás desde la Estación Aurora.", 14, Kit.MUTED)
	m.body.add_child(m.menu_button("▶ EMPEZAR", "presentación y primera etapa", func(): _play(0, true), true))

func _play(stage: int, intro: bool) -> void:
	if stage >= Release.adventure_limit(m.profile):
		m.sfx.play("error")
		m.toast(tr(Release.lock_text()))
		return
	var c := {"type": "adventure", "stage": stage, "back": "adventure"}
	if intro:
		c["intro"] = true
	m.app.start_race(c)

func _skills() -> void:
	m.set_title("HABILIDADES")
	var st := AdvData.state(m.profile)
	var sk: Dictionary = st["skills"]
	m.body.add_child(Kit.label("%s: %d   ·   +%d %s" % [tr("PUNTOS"), int(st["points"]), AdvData.POINTS_PER_STAGE, tr("por etapa ganada")], 16, Kit.GOLD))
	for S in AdvData.SKILLS:
		var id := str(S["id"])
		var lvl := int(sk.get(id, 0))
		var p := Kit.panel(8, Kit.PANEL2)
		m.body.add_child(p)
		var row := Kit.hbox(10)
		p.add_child(row)
		row.add_child(Kit.label(str(S["icon"]), 28))
		var col := Kit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Kit.label("%s  %s" % [S["name"], "●".repeat(lvl) + "○".repeat(AdvData.MAX_LEVEL - lvl)], 17))
		var dl := Kit.label(str(S["per"]), 12, Kit.MUTED)
		dl.clip_text = true
		dl.custom_minimum_size.x = 40
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
				m.go("adv_skills", null, false), int(st["points"]) >= c, 15, Vector2(112, 44))
			b.disabled = int(st["points"]) < c
			row.add_child(b)
		else:
			row.add_child(Kit.label("MÁX", 16, Kit.GREEN))

const HELP := [
	["CÓMO SE JUEGA", "• En cada etapa hay un rival adelante tuyo: pasalo y llegá primero a la próxima estación de servicio.\n• El rival maneja a tu ritmo: si vas con cuidado, él también; si apretás al límite, él aprieta. Si lo pasás, va a pelear por recuperar el puesto, pero nunca te choca a propósito.\n• Si llega él primero, repetís la etapa desde la estación anterior.\n• Al final te esperan dos jefes súper rápidos."],
	["ESTACIONES DE SERVICIO", "Son los puntos de guardado. Cuando llegás primero el auto entra solo, carga combustible y se guarda el avance. Antes de seguir podés leer la GUÍA de la próxima etapa (te explica un ajuste y te recomienda uno), ajustar el auto y gastar los puntos de habilidad."],
	["TALLERES", "En el camino hay talleres mecánicos. Un cartel te avisa antes: INGRESAR o SEGUIR. Entrar y salir no cuesta nada; cada reparación lleva unos segundos… y el rival no te espera.\nLos golpes dañan el auto: el motor pierde potencia, la dirección tira hacia un costado y la suspensión pierde agarre."],
	["CÁMARAS", "La aventura se juega con cuatro cámaras: tercera persona, el casco del piloto, adentro con el piloto y el copiloto, y sobre el capó. Cambialas con el botón CAM."],
]

func _help(page: int) -> void:
	m.set_title("CÓMO SE JUEGA")
	var P: Array = HELP[clampi(page, 0, HELP.size() - 1)]
	m.body.add_child(Kit.label(str(P[0]), 22, Kit.ACCENT))
	_text(str(P[1]), 15)
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

var st_page := 0

func _stages() -> void:
	m.set_title("ETAPAS")
	var st := AdvData.state(m.profile)
	var limit := Release.adventure_limit(m.profile)
	var reached := int(st["stage"])
	var best: Dictionary = st["best"]
	var per := 8
	var total := AdvRoute.STAGES.size()
	var pages := int(ceil(float(total) / float(per)))
	st_page = clampi(st_page, 0, pages - 1)
	var g := Kit.grid(2, 6, 6)
	m.body.add_child(g)
	for si in range(st_page * per, mini(total, (st_page + 1) * per)):
		var S: Dictionary = AdvRoute.STAGES[si]
		var avail := si < limit
		var open := si <= reached and avail
		var sub := str(S["sub"])
		if best.has(str(si)):
			sub = Kit.fmt_time(float(best[str(si)]))
		var right := "🔒" if not open else ("▶" if si == reached and not (st["done"] == true) else "✔")
		if not avail:
			right = "🚧"
		var idx := si
		g.add_child(Kit.card_button(str(S["name"]), sub, right, func() -> void: _play(idx, false), si == reached and avail and not (st["done"] == true), open, 58.0, 15, str(si + 1)))
	if pages > 1:
		m.body.add_child(Kit.pager(st_page, pages, func(pg: int) -> void:
			st_page = pg
			m.go("adv_stages", null, false)))

func _confirm_reset() -> void:
	for c in m.body.get_children():
		c.queue_free()
	m.body.add_child(Kit.label("¿Reiniciar la aventura?", 26, Kit.RED))
	_text("Se pierde el avance de las etapas, los puntos y las habilidades de la aventura.", 15, Kit.MUTED)
	m.body.add_child(Kit.button("Sí, empezar de cero", func():
		AdvData.reset(m.profile)
		m.go("adventure", null, false), false, 22))
	m.body.add_child(Kit.button("Cancelar", func(): m.go("adventure", null, false), true, 22))
