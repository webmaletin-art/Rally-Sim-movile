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
	# carrera del mundo abierto: el GPS es sólo el circuito (sin el texto amarillo y con el resto de las calles apagado en el mapa); al terminar todo vuelve
	var cp := Vector2(race.cars[0].phys.px, race.cars[0].phys.pz)
	ch.set_course(PackedVector2Array([cp, cp + Vector2(40, 0), cp + Vector2(80, 25)]), "Circuito de prueba")
	hud.update_hud(0.2, 1, race.cars)
	_check(ch.in_course() and not ch.gps_l.visible and ch.gps_l.text == "", "en una carrera: el GPS es sólo el circuito (sin el texto amarillo)")
	ch.clear_course()
	hud.update_hud(0.2, 1, race.cars)
	_check(not ch.in_course() and ch.gps_l.visible, "al terminar la carrera el GPS vuelve a ser el de siempre")
	# pausa: OPCIONES y controles sólo en la Carrera rápida y las pruebas (opts_on); el taller de prueba (reglajes) ya no está en la pausa: sólo en el Modo de prueba (lab_on) — «el taller es del garaje y de los talleres del mundo»
	# (pedido del dueño, 20/10/2026); en copas, eventos y Aventura la pausa queda limpia
	_check(hud.opts_on and not hud.lab_on, "Carrera rápida: la pausa lleva OPCIONES y controles, pero no el taller de prueba")
	hud._fill_pause()
	await process_frame
	var ptx := _buttons_text(hud.pause_col)
	_check(ptx.contains("OPCIONES") and ptx.contains("MODIFICAR CONTROLES") and not ptx.contains("TALLER") and not ptx.contains("REGLAJES"), "Carrera rápida: OPCIONES y MODIFICAR CONTROLES están en la pausa; TALLER DE PRUEBA y REGLAJES no")
	hud.opts_on = false
	hud._fill_pause()
	await process_frame
	ptx = _buttons_text(hud.pause_col)
	_check(not ptx.contains("OPCIONES") and not ptx.contains("TALLER") and not ptx.contains("REGLAJES") and not ptx.contains("MODIFICAR") and not ptx.contains("AJUSTAR") and ptx.contains("SEGUIR") and ptx.contains("CÁMARA") and ptx.contains("REINICIAR"), "copas, eventos y Aventura: la pausa sin configuraciones ni reglajes (queda seguir, cámara, cine, reiniciar y salir)")
	hud.lab_on = true # (el Modo de prueba: ahí sí están los reglajes)
	hud._fill_pause()
	await process_frame
	_check(_buttons_text(hud.pause_col).contains("REGLAJES"), "Modo de prueba: la pausa lleva los REGLAJES")
	hud.lab_on = false
	hud.opts_on = true
	hud._fill_pause()
	await process_frame
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
	# GPS: si el auto se sale de la ruta, la ruta nueva sale enseguida (antes recién a más de 40 m: varias cuadras después)
	var city = race.track.city
	var A := Vector2.ZERO
	for si0 in range(1000, city.s_x.size(), 3):
		A = Vector2(city.s_x[si0], city.s_z[si0])
		if A.length() < 600.0 and str(city.roads[city.s_road[si0]]["kind"]) in ["major", "minor"]:
			break
	var dest := Vector2.ZERO
	for pi in city.pois.size():
		var q: Vector2 = city.pois[pi]["front"]
		if q.distance_to(A) > 500.0 and q.distance_to(A) < 900.0:
			dest = q
			break
	race.cars[0].place(A.x, A.y, 0.0)
	race.cars[0].restart_history(race.sim_t)
	ch.update_hud(0.1, race.cars[0])
	ch.clear_dest()
	ch.set_dest(dest, "prueba", true)
	_check(dest != Vector2.ZERO and ch.route.size() > 10, "GPS: ruta hasta el destino (%d puntos)" % ch.route.size())
	var old_route: PackedVector2Array = ch.route.duplicate()
	# siguiendo la ruta (un punto cada ~16 m, 0,1 s por punto) la ruta se va acortando y nunca se rehace (sin falsos desvíos)
	var shrink_ok := true
	var last_n: int = ch.route.size()
	var worst_dev := 0.0
	for k in range(1, 12):
		race.cars[0].place(old_route[k].x, old_route[k].y, 0.0)
		race.cars[0].restart_history(race.sim_t)
		for kk in 3:
			ch.update_hud(0.09, race.cars[0])
		worst_dev = maxf(worst_dev, ch._route_dev())
		if ch.route.size() > last_n:
			shrink_ok = false # (se rehízo: la ruta nueva no es más corta)
		last_n = ch.route.size()
	_check(shrink_ok and worst_dev < 6.0, "GPS: siguiendo la ruta no se rehace (desvío máximo %.1f m)" % worst_dev)
	ch.clear_dest()
	ch.set_dest(dest, "prueba", true)
	old_route = ch.route.duplicate()
	race.cars[0].place(A.x, A.y, 0.0)
	race.cars[0].restart_history(race.sim_t)
	ch.update_hud(0.1, race.cars[0])
	# otra calle, a 40–300 m de la ruta
	var B := Vector2.ZERO
	for k in range(0, city.s_x.size(), 7):
		var q2 := Vector2(city.s_x[k], city.s_z[k])
		if q2.length() > 800.0 or q2.x > 70000.0:
			continue
		var dmin := 1e9
		for rp in old_route:
			dmin = minf(dmin, rp.distance_to(q2))
		if dmin > 40.0 and dmin < 300.0 and q2.distance_to(A) < 700.0:
			B = q2
			break
	_check(B != Vector2.ZERO, "GPS: hay una calle apartada para probar el desvío")
	race.cars[0].place(B.x, B.y, 0.0)
	race.cars[0].restart_history(race.sim_t)
	for k in 14: # 1,2 s manejando por la calle equivocada
		ch.update_hud(0.09, race.cars[0])
	_check(ch.route.size() > 3 and ch._route_dev() < 14.0, "GPS: a los 1,2 s ya hay una ruta nueva desde donde estás (desvío %.1f m)" % ch._route_dev())
	_check(ch.route != old_route, "GPS: la ruta cambió")
	race.queue_free()
	quit(1 if fail else 0)

## Los textos de todos los botones de un menú, separados por «|»
func _buttons_text(root_n: Node) -> String:
	var out := ""
	var st: Array = [root_n]
	while not st.is_empty():
		var n: Node = st.pop_back()
		if n is Button:
			out += (n as Button).text + "|"
		st.append_array(n.get_children())
	return out
