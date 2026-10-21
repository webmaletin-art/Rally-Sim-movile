extends RefCounted
## MODO DE PRUEBA en el menú (20/10/2026, pedido del dueño): una baldosa en el inicio (al lado de Aventura y Modo online, después de la configuración gráfica automática) que lleva a
##   1) la GUÍA, ANTES de entrar (qué es, cómo se juega; con la voz de Claudio si hay audio y siempre con subtítulos),
##   2) el ARMADO de la prueba (auto: camioneta, GT, clásico o superdeportivo · nivel de simulación · drift o carrera · reglajes · calidad gráfica),
##   3) la pista de pruebas (DriftTrack.new(true), TestSession) con el menú de pausa de la prueba (guía con imágenes, reglajes, SALIR DE LA PRUEBA).
## Es FIJO (pedido del dueño, 21/10/2026): la baldosa queda siempre en el inicio —para reglar el auto y probar cosas sin ir a una carrera— y se sale con un solo toque.
## La primera vez que se inicia el juego se lo manda a la guía de la prueba (menu.gd → offer_test_intro; marca testMode.intro desde _first_time).

const Kit := preload("res://game/ui/ui_kit.gd")
const Autotune := preload("res://game/autotune.gd")
const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Slides := preload("res://game/ui/guide_slides.gd")
const GuideVoice := preload("res://game/audio/guide_voice.gd")

## id del auto, ícono, nombre, línea de la guía que lo presenta
const CARS := [
	["pickup", "🛻", "CAMIONETA", "car_pickup"],
	["gt", "🏎", "GT", "car_gt"],
	["clasico60", "🚗", "CLÁSICO", "car_classic"],
	["veltor", "⚡", "SUPERDEPORTIVO", "car_super"],
]
const SIMS := [["arcade", "ARCADE", "sim_arcade"], ["mid", "INTERMEDIO", "sim_mid"], ["pro", "SIMULADOR TOTAL", "sim_pro"], ["custom", "PERSONALIZADO", "sim_custom"]]

var m: Node # menu.gd
var page := 0 # hoja de la guía que se está viendo
var first_arrival := false # la primera vez que se juega el menú lo trae acá (offer_test_intro): la guía da la bienvenida al juego y se puede dejar para después
var _welcome_id := "welcome" # la línea de bienvenida de esta visita (la que se repite al volver a encender la voz)

# ───────────────────────── estado (se guarda en el perfil) ─────────────────────────
static func state(profile: RefCounted) -> Dictionary:
	var d: Variant = profile.d.get("testMode")
	if not (d is Dictionary):
		profile.d["testMode"] = {}
	return profile.d["testMode"]

## ¿Ya hizo la prueba alguna vez (salió con «SALIR DE LA PRUEBA»)? Sólo sirve para despedirse la primera vez: la prueba se puede repetir todas las veces que quiera
static func is_done(profile: RefCounted) -> bool:
	return state(profile).get("done", false) == true

## ¿Se muestra la baldosa? Siempre, salvo antes de la configuración gráfica automática (la prueba corre con el perfil gráfico calibrado)
static func available(profile: RefCounted) -> bool:
	return not Autotune.pending(profile)

## Salió de la prueba: queda anotado que la hizo (la baldosa NO desaparece) y la primera vez el menú se despide
static func mark_done(profile: RefCounted) -> void:
	var st := state(profile)
	if st.get("done", false) != true:
		st["farewell"] = true # (el menú se despide una sola vez, la primera: «Listo, volvemos al menú… la prueba queda acá»)
	st["done"] = true
	st["intro"] = false # (si salió de la prueba ya no hace falta mandarlo)
	profile.save()

## Primera vez que se inicia el juego (perfil nuevo, sin autos): la primera vez que llegue al inicio se lo manda a la guía de la prueba (menu.gd → offer_test_intro)
static func mark_first_time(profile: RefCounted) -> void:
	state(profile)["intro"] = true
	profile.save()

## ¿Toca mandarlo ahora a la prueba? Si está esperando la configuración gráfica automática, queda pendiente
static func intro_due(profile: RefCounted) -> bool:
	return state(profile).get("intro", false) == true and available(profile)

## Lo manda a la prueba UNA sola vez: apenas se decide se anota (si cierra el juego o sale de la guía no vuelve a insistir)
static func take_intro(profile: RefCounted) -> bool:
	if not intro_due(profile):
		return false
	state(profile)["intro"] = false
	profile.save()
	return true

## ¿Hay que decir la despedida? Una sola vez, la primera vez que sale de la prueba
static func take_farewell(profile: RefCounted) -> bool:
	var st := state(profile)
	if st.get("farewell", false) != true:
		return false
	st["farewell"] = false
	profile.save()
	return true

## «Mi auto»: se prueba el auto elegido en el garaje, con sus piezas y su reglaje (los ajustes que se hagan en la prueba no se guardan en él)
const MINE := "mine"

static func default_setup() -> Dictionary:
	return {"car": "gt", "mode": "drift", "score": "points", "loop": "dirt", "lab": true}

static func setup_of(profile: RefCounted) -> Dictionary:
	var out := default_setup()
	var saved: Variant = state(profile).get("setup")
	if saved is Dictionary:
		for k in (saved as Dictionary):
			out[k] = (saved as Dictionary)[k]
	return out

## La configuración de la carrera que se larga (race.gd la entiende: tipo «test», pista «pruebas»)
static func build_cfg(setup: Dictionary, profile: RefCounted = null) -> Dictionary:
	var id := str(setup.get("car", "gt"))
	var car_state: Dictionary = {}
	var mine := false
	if id == MINE:
		if profile != null and str(profile.current_id()) != "" and not (profile.car() as Dictionary).is_empty():
			id = str(profile.current_id())
			car_state = (profile.car() as Dictionary).duplicate(true) # (una copia: nada de lo que pase en la prueba toca el auto del garaje)
			mine = true
		else:
			id = "gt"
	if car_state.is_empty():
		car_state = Profile.new_car_state(id)
	var mode := str(setup.get("mode", "drift"))
	return {"type": "test", "track": "pruebas", "ai": 4 if mode == "drift" else 0, "sky": "day", "car": id, "state": car_state, "testCar": true, "test": true, "testMine": mine,
		"testSetup": {"mode": mode, "score": str(setup.get("score", "points")), "loop": str(setup.get("loop", "dirt")), "lab": setup.get("lab", true) == true, "tank": 1.0},
		"back": "home", "seed": 7, "maxPI": 999}

# ───────────────────────── pantallas ─────────────────────────
func build(name: String, _arg) -> void:
	match name:
		"test_guide": _guide()
		"test_pages": _pages()
		"test_setup": _setup()

func _say(id: String) -> void:
	m.guide_voice().say(id)

func _text(t: String, size := 15, col := Kit.TEXT) -> void:
	m.body.add_child(Kit.wrap(m.tr(t), size, col, 300))

## Botón que cambia cómo se escucha la guía (voz y texto · sólo texto · apagada). compact: el chico del armado (ícono y una palabra)
func _voice_button(compact := false) -> Button:
	var g = m.guide_voice()
	var b := Kit.button(GuideVoice.mode_short(g.mode) if compact else GuideVoice.mode_label(g.mode), Callable(), false, 14, Vector2(100 if compact else 0, 66 if compact else 40))
	b.pressed.connect(func() -> void:
		m.sfx.play("click")
		var nm: String = g.cycle_mode()
		m.profile.set_setting("guideMode", nm)
		b.text = GuideVoice.mode_short(nm) if compact else GuideVoice.mode_label(nm)
		Kit.fit_button_now(b)
		if nm != "off" and m.screen == "test_guide":
			g.say(_welcome_id, true))
	return b

## 1) La guía, antes de entrar
func _guide() -> void:
	m.set_title(m.tr("🎓 MODO DE PRUEBA"))
	m.refresh_car()
	var first := first_arrival
	first_arrival = false # (vale para esta entrada; si vuelve a abrir la guía es la de siempre)
	_welcome_id = "welcome_first" if first else "welcome"
	_say(_welcome_id)
	if first:
		_text("👋 ¡Bienvenido! Como es tu primera vez, arrancamos por acá.", 15, Kit.GOLD)
	_text("Un lugar para reglar tu auto y probar cosas sin ir a una carrera: manejá en una pista con lomos de burro, un punto de nafta, un camino de tierra por atrás de la ciudad y cuatro autos haciendo drift.", 15)
	var bul := Kit.vbox(4)
	m.body.add_child(bul)
	for line in ["🎮  Probá el nivel de simulación: arcade, intermedio, simulador total o personalizado.", "🔧  Ajustá el reglaje: suspensión, tracción, frenos, gomas… se aplica al instante.", "🌀  Hacé drift (por puntos o libre) o una carrera contrarreloj por puertas.", "🎥  Mirá las cámaras y las ayudas desde la pausa, con la guía en imágenes."]:
		bul.add_child(Kit.wrap(m.tr(line), 14, Kit.MUTED, 300))
	_text("✔ Queda siempre en el inicio: volvé cuando quieras.", 14, Kit.GOLD)
	var vrow := Kit.hbox(6) # (la voz y, la primera vez, «ahora no»: en una sola fila para que todo entre sin desplazar)
	m.body.add_child(vrow)
	var vb := _voice_button()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vrow.add_child(Kit.fit_button(vb, 11))
	if first:
		var skip := Kit.button(m.tr("AHORA NO · IR AL MENÚ"), func() -> void:
			m.sfx.play("click")
			m.go("home", null, false), false, 14, Vector2(0, 40))
		skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vrow.add_child(Kit.fit_button(skip, 11))
	m.body.add_child(m.menu_button(m.tr("📖 LEER LA GUÍA"), m.tr("las hojas con dibujos: suspensión, tracción, cámaras, volante…"), func() -> void:
		page = 0
		m.go("test_pages"), false))
	m.body.add_child(m.menu_button(m.tr("▶ IR A LA PRUEBA"), m.tr("elegir el auto y empezar"), func() -> void: m.go("test_setup"), true))

## Las hojas de la guía, una por una (también están en la pausa de la prueba)
func _pages() -> void:
	m.set_title(m.tr("📖 GUÍA DE LA PRUEBA"))
	_say("guide_pages")
	var sl := Slides.new()
	sl.custom_minimum_size = Vector2(0, 330)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.set_index(page)
	m.body.add_child(sl)
	var count_l := Kit.label("%d / %d" % [page + 1, sl.count()], 15, Kit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var row := Kit.hbox(8)
	m.body.add_child(row)
	var prev := Kit.button("◀ " + m.tr("ATRÁS"), func() -> void:
		m.sfx.play("click")
		sl.prev()
		page = sl.index
		count_l.text = "%d / %d" % [page + 1, sl.count()], false, 17, Vector2(0, 48))
	prev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(prev)
	row.add_child(count_l)
	var nxt := Kit.button(m.tr("ADELANTE") + " ▶", func() -> void:
		m.sfx.play("click")
		sl.next()
		page = sl.index
		count_l.text = "%d / %d" % [page + 1, sl.count()], false, 17, Vector2(0, 48))
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nxt)
	m.body.add_child(m.menu_button(m.tr("▶ IR A LA PRUEBA"), "", func() -> void: m.go("test_setup"), true))

func _say_force(id: String) -> void:
	m.guide_voice().say(id, true, true) # (lo elegido se explica en el momento: corta lo que estaba diciendo)

func _save(st: Dictionary) -> void:
	state(m.profile)["setup"] = st.duplicate()
	m.profile.save()

## Lo que se puede hacer en la pista: [texto, modo, puntuación, circuito, línea de la guía]. Un solo selector de dos por dos (las pantallas no se desplazan: «que todo entre»).
const ACTIVITIES := [
	["🌀 DRIFT POR PUNTOS", "drift", "points", "", "score_points"],
	["🌀 DRIFT LIBRE", "drift", "free", "", "score_free"],
	["🏁 CARRERA · CAMINO DE TIERRA", "race", "", "dirt", "loop_dirt"],
	["🏁 CARRERA · ENTRE EDIFICIOS", "race", "", "urban", "loop_urban"],
]

static func activity_on(a: Array, st: Dictionary) -> bool:
	return str(st.get("mode", "drift")) == str(a[1]) and (str(a[2]) == "" or str(st.get("score", "points")) == str(a[2])) and (str(a[3]) == "" or str(st.get("loop", "dirt")) == str(a[3]))

## 2) El armado de la prueba: todo entra sin desplazar (EMPEZAR queda fijo arriba)
func _setup() -> void:
	m.set_title(m.tr("🎓 ARMÁ TU PRUEBA"))
	var st := setup_of(m.profile)
	_say("setup_welcome")
	_say("start")
	var top := Kit.hbox(6)
	m.pinned.add_child(top)
	var go_b: Button = m.menu_button(m.tr("▶ EMPEZAR LA PRUEBA"), m.tr("salís y volvés cuando quieras"), func() -> void:
		m.guide_voice().stop()
		_save(st) # (la próxima vez queda armada como la dejó)
		m.launch(build_cfg(st, m.profile), false), true, true, 20)
	go_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(go_b)
	top.add_child(Kit.fit_button(_voice_button(true), 10))
	# el auto: «mi auto» (el del garaje, con sus piezas) o una tarjeta por cada uno de los cuatro de prueba; se ve en la sala
	var car_id := str(st["car"])
	var mine_id := str(m.profile.current_id())
	var mine_on := car_id == MINE and mine_id != ""
	if mine_on:
		m.refresh_car()
	else:
		if car_id == MINE:
			car_id = "gt" # (sin auto en el garaje no hay «mi auto»)
		m.refresh_car(car_id, Profile.new_car_state(car_id))
	var car_head := Kit.hbox(6)
	m.body.add_child(car_head)
	var car_l := Kit.label(m.tr("AUTO DE PRUEBA"), 14, Kit.GOLD)
	car_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	car_head.add_child(car_l)
	if mine_id != "":
		var mm: Dictionary = CarBuild.catalog()["cars"].get(mine_id, {})
		var mine_b := Kit.button("⭐ %s · %s" % [m.tr("MI AUTO"), str(mm.get("model", mine_id))], func() -> void:
			m.sfx.play("click")
			st["car"] = MINE
			_save(st)
			_say_force("car_mine")
			m.go("test_setup", null, false), mine_on, 13, Vector2(0, 26))
		mine_b.custom_minimum_size = Vector2(250, 26)
		mine_b.size_flags_horizontal = Control.SIZE_SHRINK_END
		car_head.add_child(Kit.fit_button(mine_b, 11))
	var g := Kit.grid(2, 6, 6)
	m.body.add_child(g)
	for c in CARS:
		var id: String = c[0]
		var cm: Dictionary = CarBuild.catalog()["cars"][id]
		var V: Dictionary = CarBuild.build_params(m.vehicles[id], Profile.new_car_state(id))
		var pf: Dictionary = CarBuild.perf_of(V)
		var b := Kit.card_button("%s %s" % [c[1], m.tr(str(c[2]))], "%s %s · %d cv" % [cm["brand"], cm["model"], int(pf["hp"])], "", func() -> void:
			m.sfx.play("click")
			st["car"] = id
			_save(st)
			_say_force(str(c[3]))
			m.go("test_setup", null, false), car_id == id and not mine_on, true, 50.0, 16)
		g.add_child(b)
	# nivel de simulación (el del perfil: lo mismo que en la pausa)
	var cur_sim := str(m.profile.setting("simLevel"))
	var sim_head := Kit.hbox(6)
	m.body.add_child(sim_head)
	var sim_l := Kit.label(m.tr("NIVEL DE SIMULACIÓN"), 14, Kit.GOLD)
	sim_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sim_head.add_child(sim_l)
	if cur_sim == "custom":
		sim_head.add_child(Kit.button(m.tr("⚙ AJUSTAR LAS AYUDAS Y EL VOLANTE"), func() -> void:
			m.sfx.play("click")
			m.go("options", "fisica"), false, 12, Vector2(0, 30)))
	var sn: Array = []
	var si := 0
	for i in SIMS.size():
		sn.append(m.tr(str(SIMS[i][1])))
		if str(SIMS[i][0]) == cur_sim:
			si = i
	m.body.add_child(Kit.tabs(sn, si, func(i: int) -> void:
		m.sfx.play("click")
		m.profile.set_setting("simLevel", str(SIMS[i][0]))
		_say_force(str(SIMS[i][2]))
		m.go("test_setup", null, false), 14, 40.0))
	# qué hacer
	m.body.add_child(Kit.label(m.tr("QUÉ QUERÉS HACER"), 14, Kit.GOLD))
	var ag := Kit.grid(2, 6, 6)
	m.body.add_child(ag)
	for a in ACTIVITIES:
		var act: Array = a
		ag.add_child(Kit.card_button(m.tr(str(act[0])), "", "", func() -> void:
			m.sfx.play("click")
			var mode_changed: bool = str(st.get("mode", "drift")) != str(act[1])
			st["mode"] = act[1]
			if str(act[2]) != "":
				st["score"] = act[2]
			if str(act[3]) != "":
				st["loop"] = act[3]
			_save(st)
			if mode_changed:
				_say_force("mode_" + str(act[1]))
				_say(str(act[4])) # (la línea del detalle espera su turno)
			else:
				_say_force(str(act[4]))
			m.go("test_setup", null, false), activity_on(act, st), true, 44.0, 15))
	# ayuda de reglaje y calidad gráfica, en una sola fila
	var lab_on: bool = st.get("lab", true) == true
	var row := Kit.hbox(6)
	m.body.add_child(row)
	var lab_b := Kit.button("🔧 %s: %s" % [m.tr("AYUDA DE REGLAJE"), m.tr("Sí").to_upper() if lab_on else m.tr("No").to_upper()], func() -> void:
		m.sfx.play("click")
		st["lab"] = not lab_on
		_save(st)
		_say_force("lab_on" if not lab_on else "lab_off")
		m.go("test_setup", null, false), lab_on, 14, Vector2(0, 40))
	lab_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(Kit.fit_button(lab_b, 10))
	var gfx := Kit.button(m.tr("⚙ CALIDAD GRÁFICA"), func() -> void:
		m.sfx.play("click")
		_say_force("gfx")
		m.request_calibration(""), false, 14, Vector2(0, 40))
	gfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(Kit.fit_button(gfx, 10))
