## Policía del online (15/10/2026): cuántos patrulleros según el auto y el grupo, el aviso y el paso despacio, la persecución corta para los que andan solos
## (city_police.gd) y los mensajes que comparten los patrulleros entre jugadores (police_net.gd). Sin red ni servidores: reglas y armado de los mensajes.
## Uso: godot --headless --path godot --script res://tests/police_online_test.gd
extends SceneTree

const CityPolice := preload("res://game/city/city_police.gd")
const PoliceNet := preload("res://game/online/police_net.gd")

var fails := 0

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _initialize() -> void:
	var pol := CityPolice.new()
	# sin conexión: como siempre (2 + nivel)
	pol.online = false
	pol.heat = 1
	check(pol.wanted() == 3 and not pol.implacable(), "sin conexión no cambia nada: 2 + nivel (%d)" % pol.wanted())
	# online solo: 1 patrullero (auto común) o 2 (auto fuerte)
	pol.online = true
	pol.group = 1
	pol._strong = 0
	check(pol.wanted() == 1, "online, solo y con un auto común: 1 patrullero")
	pol._strong = 1
	check(pol.wanted() == 2, "online, solo y con un auto fuerte: 2 patrulleros")
	pol.group = 2
	check(pol.wanted() == 2 and not pol.implacable(), "dos jugadores juntos: siguen siendo 2 por jugador fuerte, sin ser implacables")
	pol.group = 3
	check(pol.implacable() and pol.wanted() == 4, "un grupo de 3: implacables y más patrulleros por jugador (%d)" % pol.wanted())
	pol.heat = 3
	check(pol.wanted() == 5, "con nivel alto, el tope es 5 por jugador")
	# el grupo se cuenta con las posiciones de los demás
	pol.group = 1
	pol.nearby_fn = func() -> Array: return [Vector2(100, 0), Vector2(900, 0), Vector2(5000, 0)]
	pol._group_t = 0.0
	pol._group_count(1.0, Vector2.ZERO)
	check(pol.group == 3, "cuenta a los que están a menos de %.0f m (y a uno mismo): %d" % [CityPolice.GROUP_R, pol.group])
	pol.online = false
	pol._group_t = 0.0
	pol._group_count(1.0, Vector2.ZERO)
	check(pol.group == 1, "sin conexión no hay grupo")
	check(CityPolice.SLOW_KMH > 30.0 and CityPolice.LENIENT_M >= 1500.0 and CityPolice.LENIENT_M <= 4000.0, "pasar despacio (< %d km/h) y persecución de un par de km (%.1f km) para los que andan solos" % [int(CityPolice.SLOW_KMH), CityPolice.LENIENT_M / 1000.0])
	# mensajes de los patrulleros
	var uid := "0123456789abcdef"
	var msg: Dictionary = PoliceNet.pack(uid, [[100.04, -200.0, 1.234, 98.6], [101.0, -190.0, 1.2, 102.0]], 7)
	var back: Dictionary = PoliceNet.unpack(JSON.parse_string(JSON.stringify(msg)))
	check(not back.is_empty() and (back["units"] as Array).size() == 2 and is_equal_approx(float(back["units"][0][0]), 100.0) and int(back["units"][1][3]) == 102, "el mensaje de los patrulleros va y vuelve (%s)" % JSON.stringify(msg))
	check(JSON.stringify(msg).length() < 120, "es chico (%d bytes con 2 patrulleros)" % JSON.stringify(msg).length())
	check(PoliceNet.unpack({"i": uid, "u": [[0, 0, 0]]}).is_empty(), "rechaza un patrullero sin todos los datos")
	check(PoliceNet.unpack({"i": uid, "u": [[1e9, 0, 0, 10]]}).is_empty(), "rechaza posiciones fuera del mundo")
	check(PoliceNet.unpack({"i": uid, "u": [[0, 0, 0, 900]]}).is_empty(), "rechaza velocidades absurdas")
	check(PoliceNet.unpack({"i": "x", "u": []}).is_empty(), "rechaza un id inválido")
	var many: Array = []
	for k in 9:
		many.append([0, 0, 0, 10])
	check((PoliceNet.pack(uid, many, 1)["u"] as Array).size() == PoliceNet.MAX_U, "manda como mucho %d patrulleros" % PoliceNet.MAX_U)
	# fantasmas: llegan, se actualizan y se borran con la lista vacía
	var pn := PoliceNet.new()
	pn.apply("otro_jugador_123", [[0.0, 0.0, 0.0, 50.0], [10.0, 0.0, 0.0, 50.0]])
	check(pn.ghosts.size() == 2, "dos patrulleros de otro jugador a la vista")
	pn.apply("otro_jugador_123", [[1.0, 0.0, 0.0, 50.0]])
	check(pn.ghosts.size() == 1, "si perdió uno, se borra")
	pn.apply("otro_jugador_123", [])
	check(pn.ghosts.is_empty(), "terminó la persecución: se borran todos")
	pn.free()
	print("POLICE_ONLINE_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)
