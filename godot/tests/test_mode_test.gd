## MODO DE PRUEBA ([B] 20/10/2026, pedido del dueño): la pista de pruebas (Drift Plaza mejorada), la sesión (drift por puntos o libre, carrera contrarreloj por puertas, nafta),
## la guía hablada con subtítulos, el HUD, la pausa con la galería de hojas y la salida única con doble toque.
## Uso: tools/test/run_test.sh test_mode_test 240
extends SceneTree

const RACE_SCENE := preload("res://game/race.tscn")
const Profile := preload("res://game/data/profile.gd")
const MenuTest := preload("res://game/ui/menu_test.gd")
const TestSession := preload("res://game/test_session.gd")
const DriftTrack := preload("res://game/track/drift_track.gd")

## Perfil que no escribe en el disco (la prueba usa mark_done y no tiene que tocar el perfil del que la corre)
class NoSave:
	extends "res://game/data/profile.gd"
	func save() -> void:
		pass

var fail := false
var race
var loaded := false
var exit_to := ""

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	_run.call_deferred()

func _load(profile, setup: Dictionary) -> bool:
	if race != null and is_instance_valid(race):
		race.queue_free()
		await process_frame
	loaded = false
	exit_to = ""
	var cfg := MenuTest.build_cfg(setup)
	race = RACE_SCENE.instantiate()
	race.cfg = cfg
	race.profile = profile
	race.loaded.connect(func() -> void: loaded = true)
	race.exit_requested.connect(func(back: String) -> void: exit_to = back)
	root.add_child(race)
	var t0 := Time.get_ticks_msec()
	while not loaded and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	for i in 6:
		await process_frame
	return loaded

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var profile := NoSave.new()
	profile.d.erase("testMode")
	profile.d["settings"]["guideMode"] = "text" # (sin audio: sólo los subtítulos)
	profile.d["settings"]["simLevel"] = "mid"
	_check(MenuTest.is_done(profile) == false, "la prueba arranca sin usar")
	var setup := MenuTest.default_setup()
	setup["car"] = "gt"
	# ── 1) drift por puntos
	var ok: bool = await _load(profile, setup)
	_check(ok, "la pista de pruebas cargó")
	if not ok:
		quit(1)
		return
	var tr = race.track
	_check(tr is DriftTrack and tr.test_mode, "la pista es la Drift Plaza de pruebas")
	_check(race.session is TestSession and race.session.mode == "drift" and race.session.score_on, "sesión de prueba: drift por puntos")
	_check(race.cars.size() == 5, "el jugador y cuatro autos haciendo drift (%d)" % race.cars.size())
	_check(race.guide != null and race.guide.mode == "text", "hay guía hablada (modo %s)" % str(race.guide.mode if race.guide != null else "—"))
	_check(race.race_hud.test_on and race.race_hud.lab_on and race.race_hud.opts_on, "la pausa tiene OPCIONES y REGLAJES")
	_check(not race.session.blocks_throttle(), "con el tanque lleno el auto acelera")
	# el guion trae todas las líneas que usa el código
	var g = race.guide
	var used: Array = ["welcome", "guide_pages", "setup_welcome", "car_pickup", "car_gt", "car_classic", "car_super", "sim_arcade", "sim_mid", "sim_pro", "sim_custom", "mode_drift", "mode_race",
		"score_points", "score_free", "loop_dirt", "loop_urban", "lab_on", "lab_off", "gfx", "start", "test_welcome", "test_try_drift", "test_pause", "test_drift_first", "test_bumps", "test_fuel_corner", "test_refuel",
		"test_fuel_full", "test_fuel_low", "test_fuel_empty", "race_start", "test_lap_first", "test_lap_done", "cam_onboard", "cam_chase", "cam_aerial", "cam_free", "cam_rear", "cam_hood",
		"cam_bumper", "lab_open", "lab_motor", "lab_agarre", "lab_susp", "lab_frenos", "lab_trans", "lab_aero", "sim_changed", "wheel_real", "exit_warn", "exit_done"]
	var missing: Array = []
	for id in used:
		if not g.has_line(str(id)) or g.text_of(str(id)) == "":
			missing.append(id)
	_check(missing.is_empty(), "el guion tiene las %d líneas que usa el juego (faltan: %s)" % [used.size(), str(missing)])
	# largada: pasa la cuenta regresiva corta del drift
	var s = race.session
	var tw0 := Time.get_ticks_msec()
	while s.state != "run" and Time.get_ticks_msec() - tw0 < 8000: # (en tiempo real: los cuadros de la prueba corren más rápido que el juego)
		await process_frame
	_check(s.state == "run", "la prueba largó (%s)" % s.state)
	_check(g.heard.has("test_welcome"), "la guía dio la bienvenida de la pista")
	# pasaron unos segundos sin derrapar: la guía propone probar un drift (una sola vez)
	s.time = 30.0
	s.update(0.05, race.cars)
	_check(g.heard.has("test_try_drift"), "sin derrapar después de unos segundos: la guía propone probar un drift")
	s.time = 0.5
	# la nafta baja con la velocidad y la voz avisa
	var ph = race.cars[0].phys
	var t0: float = s.tank
	ph.vx = 0.0
	ph.vz = -30.0
	s.update(2.0, race.cars)
	_check(s.tank < t0, "la nafta baja al andar (%.3f → %.3f)" % [t0, s.tank])
	s.tank = 0.15
	ph.vz = -20.0
	s.update(0.1, race.cars)
	_check(g.heard.has("test_fuel_low"), "poca nafta: la guía avisa")
	s.tank = 0.0004
	s.update(0.1, race.cars)
	_check(s.blocks_throttle() and g.heard.has("test_fuel_empty"), "sin nafta: el auto no acelera y la guía avisa")
	# cargar nafta: quieto adentro del cuadrado verde
	var fz: Rect2 = DriftTrack.FUEL_ZONE
	race.cars[0].place(fz.position.x + 8.0, fz.position.y + 8.0, 0.0)
	ph = race.cars[0].phys
	ph.vx = 0.0
	ph.vz = 0.0
	s.update(0.5, race.cars)
	_check(s.refueling and s.blocks_throttle(), "adentro del cuadrado verde, quieto: carga y no acelera")
	_check(g.heard.has("test_refuel"), "la guía dice que está cargando")
	for i in 20:
		s.update(0.25, race.cars)
	_check(s.tank > 0.99 and not s.refueling, "el tanque se llenó (%.2f)" % s.tank)
	_check(g.heard.has("test_fuel_full"), "la guía avisa tanque lleno")
	# fuera del cuadrado a velocidad no carga
	s.tank = 0.5
	race.cars[0].place(fz.position.x - 40.0, fz.position.y + 8.0, 0.0)
	ph = race.cars[0].phys
	ph.vx = 0.0
	ph.vz = 0.0
	s.update(0.5, race.cars)
	_check(not s.refueling and s.tank <= 0.5, "fuera del cuadrado no carga")
	# ── 2) el taller de prueba (reglajes) no rehace la sesión ni los otros autos
	var old_s = s
	var old_n: int = race.cars.size()
	var old_bot = race.cars[1]
	race.cars[0].place(10.0, 40.0, 0.5)
	ph = race.cars[0].phys
	ph.vx = 6.0
	ph.vz = -8.0
	race._lab_apply()
	_check(race.session == old_s and race.cars.size() == old_n and race.cars[1] == old_bot, "los reglajes rehacen sólo el auto del jugador (sesión y rivales siguen)")
	var ph2 = race.cars[0].phys
	_check(absf(ph2.px - 10.0) < 0.05 and absf(ph2.pz - 40.0) < 0.05 and absf(ph2.vx - 6.0) < 0.01, "el auto sigue donde estaba y con la misma velocidad")
	# ── 3) las cámaras: la guía las comenta una vez
	for i in 9:
		race._next_camera()
	_check(g.heard.has("cam_onboard") and g.heard.has("cam_chase") and g.heard.has("cam_aerial") and g.heard.has("cam_free"), "la guía comentó las cámaras (onboard, persecución, aérea, libre)")
	_check(g.heard.has("cam_rear") and g.heard.has("cam_hood") and g.heard.has("cam_bumper"), "…y las interiores, el capó y el paragolpes")
	# ── 4) el nivel de simulación desde la pausa
	race.race_hud.sim_changed.emit("pro")
	_check(g.heard.has("sim_changed") and g.heard.has("wheel_real"), "al elegir simulador total la guía avisa del volante real")
	# ── 5) la pausa: galería a la derecha, reglajes con su hoja, salida con doble toque
	race._toggle_pause()
	await _frames(3)
	var hud = race.race_hud
	_check(hud.pause_box.visible and g.heard.has("test_pause"), "la pausa abre y la guía la explica")
	await _frames(2)
	_check(hud.gallery != null and hud.gallery.visible, "en la pausa se ve la galería de la guía a la derecha")
	var n0: int = hud.gslides.index
	hud.gslides.next()
	_check(hud.gslides.index == (n0 + 1) % hud.gslides.count(), "◀ ▶ pasan las hojas")
	hud.open_page("lab")
	await _frames(3)
	_check(g.heard.has("lab_open") and g.heard.has("lab_motor"), "al abrir los reglajes la guía los explica (y la solapa MOTOR)")
	_check(hud.gallery.visible and hud.gslides.index == hud.gslides.index_of("motor"), "la hoja de la derecha acompaña la solapa (motor)")
	hud.lab_tab[0] = 2
	hud._opts_go("lab", null, false)
	await _frames(2)
	_check(g.heard.has("lab_susp") and hud.gslides.index == hud.gslides.index_of("susp"), "solapa SUSPENSIÓN: la guía y la hoja cambian")
	hud.open_page("camadj")
	await _frames(2)
	_check(hud.gslides.index == hud.gslides.index_of("camaras"), "ajuste de cámara: la hoja de las cámaras")
	hud._opts_close()
	await _frames(2)
	hud.gallery_on = false
	await _frames(2)
	_check(not hud.gallery.visible, "OCULTAR LA GUÍA esconde la galería")
	hud.gallery_on = true
	# salir de la prueba: primer toque avisa, segundo confirma
	_check(not MenuTest.is_done(profile), "antes de salir la prueba no está usada")
	hud._fill_pause()
	hud.exit_btn.pressed.emit()
	_check(hud.exit_armed_t > 0.0 and g.heard.has("exit_warn") and exit_to == "", "primer toque en SALIR DE LA PRUEBA: avisa y no sale")
	hud.exit_btn.pressed.emit()
	_check(exit_to == "home" and MenuTest.is_done(profile), "segundo toque: sale al menú y la prueba queda usada")
	_check(not MenuTest.available(profile), "la baldosa desaparece (no se vuelve a entrar)")
	_check(MenuTest.take_farewell(profile) and not MenuTest.take_farewell(profile), "la despedida se dice una sola vez")
	# ── 6) carrera contrarreloj por el camino de tierra
	profile = NoSave.new()
	profile.d.erase("testMode")
	profile.d["settings"]["guideMode"] = "text"
	setup = MenuTest.default_setup()
	setup["mode"] = "race"
	setup["loop"] = "dirt"
	ok = await _load(profile, setup)
	_check(ok, "la carrera por el camino de tierra cargó")
	tr = race.track
	s = race.session
	g = race.guide
	_check(s.mode == "race" and not s.score_on and race.cars.size() == 1, "sesión de carrera: sin rivales ni puntos")
	_check(tr.loop == "dirt" and tr.map_lines.size() == tr._map_base.size() + 1, "el minimapa muestra las calles y sólo el circuito de tierra")
	var gates: Array = s.gates
	_check(gates.size() >= 8, "el circuito de tierra tiene sus puertas (%d)" % gates.size())
	var sp: Array = tr.start_pose(0)
	var p0: Vector3 = gates[0]
	_check(Vector2(float(sp[0]) - p0.x, float(sp[1]) - p0.y).length() < 90.0, "la largada está sobre la línea del circuito")
	var tw := Time.get_ticks_msec()
	while s.state != "run" and Time.get_ticks_msec() - tw < 12000: # (la cuenta regresiva de 3,6 s, en tiempo real)
		await process_frame
	_check(s.state == "run" and g.heard.has("race_start"), "la carrera largó y la guía explicó las puertas (%s)" % s.state)
	# pasa por todas las puertas en orden con el auto parado encima de cada una
	var laps0: int = s.laps_done.size()
	for gi in range(1, gates.size() + 1):
		var gv: Vector3 = gates[gi % gates.size()]
		race.cars[0].place(gv.x, gv.y, 0.0)
		race.cars[0].phys.vx = 0.0
		race.cars[0].phys.vz = 0.0
		s.update(0.05, race.cars)
	_check(s.laps_done.size() == laps0 + 1 and s.lap == 2, "pasar por todas las puertas en orden cuenta una vuelta (%d)" % s.laps_done.size())
	_check(g.heard.has("test_lap_first") and s.best_lap > 0.0, "la guía celebra la primera vuelta")
	# saltearse una puerta no cuenta
	var lap_before: int = s.laps_done.size()
	var gv2: Vector3 = gates[0]
	race.cars[0].place(gv2.x, gv2.y, 0.0)
	s.update(0.05, race.cars)
	_check(s.laps_done.size() == lap_before, "pasar por la meta sin haber hecho las puertas no suma vueltas")
	var lines: Array = s.hud_lines()
	_check(lines.size() == 3 and str(lines[1]).contains("VUELTA"), "el HUD de la carrera muestra vuelta y nafta (%s)" % str(lines[1]))
	# ── 7) circuito entre los edificios y drift libre
	setup["loop"] = "urban"
	ok = await _load(profile, setup)
	_check(ok and race.session.loop_name == "urban" and race.track.loop == "urban", "el circuito entre edificios carga")
	var us: Array = race.session.gates
	_check(us.size() == 12, "tiene 12 puertas (%d)" % us.size())
	var usp: Array = race.track.start_pose(0)
	_check(absf(float(usp[1]) + 92.0) < 0.5, "largada en la boca norte del playón")
	setup["mode"] = "drift"
	setup["score"] = "free"
	setup["lab"] = false
	ok = await _load(profile, setup)
	_check(ok and not race.session.score_on and not race.race_hud.lab_on, "drift libre sin ayuda de reglaje: sin puntos y sin REGLAJES en la pausa")
	var fl: Array = race.session.hud_lines()
	_check(str(fl[1]).contains("LIBRE") or str(fl[1]).contains("DRIFT"), "el HUD dice DRIFT LIBRE")
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
