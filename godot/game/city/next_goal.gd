extends RefCounted
## «PRÓXIMO OBJETIVO» (auditoría del ciclo de juego, 16/10/2026): de todo lo que ya existe (carreras del mapa, eventos del servidor, plata para el próximo auto,
## temporada, récords), cuál conviene mostrar ahora. Reglas puras (sin nodos): las usa game/city/city_goal.gd y las prueba tests/next_goal_test.gd.
##
## ctx = {
##   pos: Vector2 (dónde está el auto), fuel: 0..1, credits: int, voucher: int,
##   events: [{id, name, icon, pos: Vector2, reward: int, found: bool, wins: int, best (float|null), type}],   ← las 79 del mapa
##   live: [{id, title, kind, ends_in: float, standing: String}],                                              ← eventos del servidor en curso
##   next_car: {id, name, price} (el auto más barato que todavía no tenés y se compra con plata; vacío si no hay),
##   fuel_pos: Vector2 (estación más cercana; o null), dealer_pos: Vector2 (concesionario; o null),
##   dismissed: {clave: true}  ← los que el jugador cerró con ✕ (no vuelven por un rato)
## }
## Devuelve la lista ordenada: [{key, icon, title, sub, pos (Vector2 o null: botón IR), prio}]. Sólo cosas posibles: nada que pida otro auto o acceso.

const NEAR_M := 6000.0 # una carrera «cerca» (para descubrir o ganar)
const FAR_M := 60000.0

static func pick(ctx: Dictionary) -> Array:
	var out: Array = []
	var pos: Vector2 = ctx.get("pos", Vector2.ZERO)
	var dis: Dictionary = ctx.get("dismissed", {})
	# 1) sin nafta no se llega a ningún lado: primero la estación
	var fuel := float(ctx.get("fuel", 1.0))
	if fuel < 0.15 and ctx.get("fuel_pos") is Vector2:
		out.append({"key": "fuel", "icon": "⛽", "title": "Cargá nafta", "sub": "estación a %s" % km(pos.distance_to(ctx["fuel_pos"])), "pos": ctx["fuel_pos"], "prio": 100})
	# 2) un evento del servidor en curso
	for e in (ctx.get("live", []) as Array):
		out.append({"key": "live:" + str(e.get("id", "")), "icon": str(e.get("icon", "📅")), "title": str(e.get("title", "")), "sub": "en vivo · termina en %s%s" % [dur(float(e.get("ends_in", 0))), str(e.get("standing", ""))], "pos": null, "prio": 80})
	# 3) la carrera del mapa más cercana sin ganar (descubierta) o por descubrir
	var best_won := {}
	var near_new := {}
	var near_unk := {}
	for ev in (ctx.get("events", []) as Array):
		var p: Vector2 = ev["pos"]
		var d := pos.distance_to(p)
		if d > FAR_M:
			continue
		if bool(ev.get("found", false)):
			if int(ev.get("wins", 0)) == 0:
				if near_new.is_empty() or d < float(near_new["d"]):
					near_new = {"ev": ev, "d": d}
			elif ev.get("best") != null and d < NEAR_M:
				if best_won.is_empty() or d < float(best_won["d"]):
					best_won = {"ev": ev, "d": d}
		elif near_unk.is_empty() or d < float(near_unk["d"]):
			near_unk = {"ev": ev, "d": d}
	if not near_new.is_empty():
		var ev: Dictionary = near_new["ev"]
		out.append({"key": "ow:" + str(ev["id"]), "icon": str(ev.get("icon", "🏁")), "title": str(ev.get("name", "")), "sub": "%s · premio $%s · cualquier auto" % [km(float(near_new["d"])), money(int(ev.get("reward", 0)))], "pos": ev["pos"], "prio": 60 if float(near_new["d"]) < NEAR_M else 40})
	if not near_unk.is_empty():
		out.append({"key": "unk:" + str(near_unk["ev"]["id"]), "icon": "❓", "title": "Carrera por descubrir", "sub": "%s · acercate y frená en el círculo" % km(float(near_unk["d"])), "pos": near_unk["ev"]["pos"], "prio": 55 if float(near_unk["d"]) < NEAR_M else 35})
	# 4) el próximo auto
	var nc: Dictionary = ctx.get("next_car", {})
	if not nc.is_empty():
		var have := int(ctx.get("credits", 0))
		var price := int(nc.get("price", 0))
		if have >= price:
			out.append({"key": "car:" + str(nc["id"]), "icon": "🚗", "title": "Ya te alcanza para el %s" % str(nc.get("name", "")), "sub": "$%s · andá al concesionario" % money(price), "pos": ctx.get("dealer_pos"), "prio": 50})
		else:
			out.append({"key": "car:" + str(nc["id"]), "icon": "🚗", "title": "Próximo auto: %s" % str(nc.get("name", "")), "sub": "te faltan $%s (%d %%)" % [money(price - have), int(100.0 * float(have) / maxf(1.0, float(price)))], "pos": null, "prio": 30})
	# 5) bajar un tiempo propio cerca
	if not best_won.is_empty():
		var ev2: Dictionary = best_won["ev"]
		out.append({"key": "rec:" + str(ev2["id"]), "icon": "⏱", "title": "Bajá tu tiempo: %s" % str(ev2.get("name", "")), "sub": "tu mejor %s · %s" % [clock(float(ev2["best"])), km(float(best_won["d"]))], "pos": ev2["pos"], "prio": 20})
	out = out.filter(func(g: Dictionary) -> bool: return not dis.has(str(g["key"])))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["prio"]) > int(b["prio"]))
	return out

static func km(m: float) -> String:
	return ("%.1f km" % (m / 1000.0)).replace(".", ",") if m >= 1000.0 else "%d m" % int(m)

static func money(n: int) -> String:
	var s := str(absi(n))
	var o := ""
	while s.length() > 3:
		o = "." + s.right(3) + o
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + o

static func dur(s: float) -> String:
	var n := int(s)
	return ("%dh%02d" % [n / 3600, (n % 3600) / 60]) if n >= 3600 else ("%d min" % maxi(1, n / 60))

static func clock(secs: float) -> String:
	return "%d:%04.1f" % [int(secs / 60.0), fmod(secs, 60.0)]
