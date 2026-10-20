## Taller de prueba en el mundo abierto ([B] 19/10/2026): al aplicar un ajuste el auto SIGUE donde estaba (posición, rumbo, velocidad), la sesión, el HUD del mapa, el GPS
## y los demás autos no se rehacen, y el minimapa no se dibuja sobre un menú abierto. Reporte del dueño: «al modificar la suspensión el auto hace un respawn de nuevo y el GPS
## aparece arriba del menú». Antes _lab_apply rehacía TODA la sesión del mundo abierto (race.gd → _rebuild_cars → _start_session → race_hud.setup).
## Uso: tools/test/run_test.sh lab_city_test 120
extends SceneTree

const RACE_SCENE := preload("res://game/race.tscn")
const Profile := preload("res://game/data/profile.gd")

var fail := false
var race
var loaded := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var profile := Profile.new()
	var cfg := {"type": "city", "track": "aurelia", "ai": 0, "sky": "day", "seed": 7, "back": "home", "quick": true, "spawn": 0, "online": false, "car": "hatch",
		"state": Profile.new_car_state("hatch"), "sim": "mid", "maxPI": 999}
	race = RACE_SCENE.instantiate()
	race.cfg = cfg
	race.profile = profile
	race.loaded.connect(func() -> void: loaded = true)
	root.add_child(race)
	var t0 := Time.get_ticks_msec()
	while not loaded and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	_check(loaded, "el mundo abierto cargó (%.1f s)" % [float(Time.get_ticks_msec() - t0) / 1000.0])
	if not loaded:
		quit(1)
		return
	for i in 10:
		await process_frame
	var hud = race.race_hud
	var ch = hud.city_hud
	_check(ch != null and race.session != null and race.cars.size() >= 1, "hay HUD del mapa, sesión y auto")
	# el auto va a 15 m/s con las ruedas girando
	var ph = race.cars[0].phys
	ph.vx = 11.0
	ph.vz = 9.0
	ph.yawRate = 0.3
	for w in ph.wheels:
		w.omega = 40.0
	var px: float = ph.px
	var pz: float = ph.pz
	var yaw: float = ph.yaw
	var old_car = race.cars[0]
	var old_session = race.session
	var old_n: int = race.cars.size()
	race._lab_apply()
	var ph2 = race.cars[0].phys
	_check(race.cars[0] != old_car, "el auto del jugador se rehízo (los ajustes nuevos)")
	_check(Vector2(ph2.px - px, ph2.pz - pz).length() < 0.05 and absf(wrapf(ph2.yaw - yaw, -PI, PI)) < 0.02, "sigue en el mismo lugar y con el mismo rumbo")
	_check(absf(ph2.vx - 11.0) < 0.01 and absf(ph2.vz - 9.0) < 0.01 and absf(ph2.yawRate - 0.3) < 0.01, "sigue con la misma velocidad y giro (no «vuelve a aparecer»)")
	var om_ok := true
	for w in ph2.wheels:
		if absf(w.omega - 40.0) > 0.01:
			om_ok = false
	_check(om_ok, "las ruedas siguen girando")
	_check(race.session == old_session, "la sesión del mundo abierto es la misma")
	_check(race.race_hud.city_hud == ch and is_instance_valid(ch), "el HUD del mapa (con su GPS) es el mismo")
	_check(race.cars.size() == old_n, "los demás autos siguen (%d)" % race.cars.size())
	# el minimapa no se dibuja sobre un menú abierto
	hud.update_hud(0.016, 1, race.cars)
	_check(ch._mini.visible and not ch.menu_open, "sin menú: el minimapa se ve")
	hud.pause_box.visible = true
	hud.update_hud(0.016, 1, race.cars)
	_check(not ch._mini.visible and not ch.street_l.visible and not ch.gps_l.visible, "con la pausa abierta: sin minimapa ni GPS arriba del menú")
	hud.pause_box.visible = false
	hud.external_menu = true # el taller de prueba
	hud.update_hud(0.016, 1, race.cars)
	_check(not ch._mini.visible, "con el taller de prueba abierto: sin minimapa")
	hud.external_menu = false
	hud.update_hud(0.016, 1, race.cars)
	_check(ch._mini.visible, "al cerrar los menús vuelve el minimapa")
	# faros: automáticos (de día apagados, de noche prendidos), encendidos a mano y apagados a mano
	var clk = race.clock
	_check(clk != null and clk._beam != null, "hay faros")
	clk._frozen = true
	clk.hour = 12.0
	clk._apply()
	_check(clk.lights_mode() == "auto" and not clk._beam.visible, "AUTO de día: los faros están apagados")
	clk.hour = 23.0
	clk._apply()
	_check(clk._beam.visible, "AUTO de noche: los faros están prendidos")
	clk.hour = 12.0
	clk.cycle_lights()
	_check(clk.lights_mode() == "on" and clk._beam.visible, "ENCENDIDAS: prendidos aunque sea de día")
	clk.hour = 23.0
	clk.cycle_lights()
	_check(clk.lights_mode() == "off" and not clk._beam.visible, "APAGADAS: apagados aunque sea de noche")
	clk.cycle_lights()
	_check(clk.lights_mode() == "auto" and clk._beam.visible and clk.lights_label().contains("AUTOM"), "vuelve a AUTOMÁTICAS (%s)" % clk.lights_label())
	race.queue_free()
	quit(1 if fail else 0)
