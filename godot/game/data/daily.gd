## Desafíos del día (fase 5, 16/10/2026): tres objetivos cortos que cambian cada día y se arman con lo que ya existe (carreras del mapa, copas, carrera
## rápida, drift). No hace falta comprar nada ni estar conectado: el día y el desafío salen de la fecha (todos los teléfonos ven lo mismo el mismo día).
##   0 · Terminá N carreras del mapa (cualquiera, ganando o no).
##   1 · Ganá la carrera del mapa marcada (una que ya descubriste, elegida al empezar el día) o, si todavía no descubriste ninguna, ganá cualquiera.
##   2 · Terminá N eventos del menú (copas, carrera rápida, drift, picada).
## Premio: profile.earn(…, "daily", "<día>:<n>", {once: true}); el servidor (20261022) no paga dos veces la misma clave aunque reinstales o reconectes.
## La configuración (prendidos, premios, cuántas carreras, huso horario) viene con el estado de la cuenta («dcfg», migración 20261024) y queda guardada en
## el perfil; sin conexión se usa la última o la de fábrica (DEFAULT). El día cambia a la medianoche de Argentina (tz_h = -3), igual para todos.
## Estado en profile.d["dailyCh"] = {day, cnt: {play, race}, won: [ids ganadas hoy], pick: id marcada, got: {"<día>:<n>": 1}}.
extends RefCounted

const DEFAULT := {"on": true, "cr": [2500, 5000, 4000], "n_play": 2, "n_race": 2, "tz_h": -3}

static func cfg(d: Dictionary) -> Dictionary:
	var c := DEFAULT.duplicate(true)
	if d.get("dailyCfg") is Dictionary:
		for k in (d["dailyCfg"] as Dictionary):
			if c.has(k):
				c[k] = d["dailyCfg"][k]
	var cr: Array = c["cr"] if c["cr"] is Array else DEFAULT["cr"]
	while cr.size() < 3:
		cr.append(DEFAULT["cr"][cr.size()])
	c["cr"] = cr
	return c

## El día del desafío («AAAA-MM-DD») para una hora unix, en el huso de la configuración
static func day_of(unix: float, tz_h: int) -> String:
	return Time.get_date_string_from_unix_time(int(unix) + tz_h * 3600)

static func today(d: Dictionary) -> String:
	return day_of(Time.get_unix_time_from_system(), int(cfg(d)["tz_h"]))

## El estado del día (si cambió el día, arranca de cero y elige la carrera marcada entre las descubiertas)
static func state(d: Dictionary, day := "") -> Dictionary:
	if day == "":
		day = today(d)
	if not (d.get("dailyCh") is Dictionary):
		d["dailyCh"] = {"day": "", "cnt": {}, "won": [], "pick": "", "got": {}}
	var s: Dictionary = d["dailyCh"]
	if str(s.get("day", "")) != day:
		var got := {}
		for k in (s.get("got", {}) as Dictionary): # lo cobrado hoy (p. ej. vuelto del servidor antes de abrir el día) se conserva; lo viejo se borra
			if str(k).begins_with(day + ":"):
				got[k] = 1
		s.clear()
		s.merge({"day": day, "cnt": {"play": 0, "race": 0}, "won": [], "pick": pick_event(d, day), "got": got})
	return s

## La carrera marcada del día: una de las descubiertas, la misma para el mismo día y la misma lista
static func pick_event(d: Dictionary, day: String) -> String:
	var found: Array = []
	var ow: Dictionary = d.get("owEvents", {}) if d.get("owEvents") is Dictionary else {}
	for id in ow:
		if (ow[id] as Dictionary).get("found", false) == true:
			found.append(str(id))
	if found.is_empty():
		return ""
	found.sort()
	return str(found[absi(hash(day)) % found.size()])

## Los tres desafíos de hoy: [{n, text, have, need, done, got, cr, ref}]
static func list(d: Dictionary, day := "") -> Array:
	var c := cfg(d)
	var s := state(d, day)
	var cnt: Dictionary = s["cnt"]
	var pick := str(s.get("pick", ""))
	var won: Array = s.get("won", [])
	var out: Array = []
	var np := maxi(1, int(c["n_play"]))
	var nr := maxi(1, int(c["n_race"]))
	var title := ""
	if pick != "":
		var ow: Dictionary = d.get("owEvents", {}) if d.get("owEvents") is Dictionary else {}
		title = str((ow.get(pick, {}) as Dictionary).get("title", ""))
	var win_have := (1 if won.has(pick) else 0) if pick != "" else mini(won.size(), 1)
	var rows := [
		["🗺️", "Terminá %d carreras del mapa" % np, mini(int(cnt.get("play", 0)), np), np],
		["🏁", ("Ganá «%s» (carrera del mapa)" % title) if title != "" else ("Ganá la carrera del mapa marcada" if pick != "" else "Ganá una carrera del mapa"), win_have, 1],
		["🏆", "Terminá %d eventos del menú (copas, carrera rápida, drift)" % nr, mini(int(cnt.get("race", 0)), nr), nr],
	]
	for i in rows.size():
		var ref := "%s:%d" % [str(s["day"]), i]
		out.append({"n": i, "icon": rows[i][0], "text": rows[i][1], "have": rows[i][2], "need": rows[i][3], "done": int(rows[i][2]) >= int(rows[i][3]),
			"got": (s["got"] as Dictionary).has(ref), "cr": int(c["cr"][i]), "ref": ref})
	return out

## Cuántos están cumplidos y sin cobrar (para el aviso del menú)
static func ready_count(d: Dictionary) -> int:
	if not bool(cfg(d)["on"]):
		return 0
	var n := 0
	for ch in list(d):
		if ch["done"] and not ch["got"]:
			n += 1
	return n

## Avisos del juego. kind: "play" (terminó una carrera del mapa; won y id dicen si la ganó y cuál) o "race" (terminó un evento del menú)
static func note(d: Dictionary, kind: String, won := false, id := "", day := "") -> void:
	var s := state(d, day)
	var cnt: Dictionary = s["cnt"]
	cnt[kind] = int(cnt.get(kind, 0)) + 1
	if kind == "play" and won and id != "" and not (s["won"] as Array).has(id):
		(s["won"] as Array).append(id)

## Cobrar uno (devuelve el monto, 0 si no correspondía). La clave once la valida el servidor.
static func claim(profile: RefCounted, i: int) -> int:
	var d: Dictionary = profile.d
	if not bool(cfg(d)["on"]):
		return 0
	var l := list(d)
	if i < 0 or i >= l.size() or not l[i]["done"] or l[i]["got"]:
		return 0
	d["dailyCh"]["got"][l[i]["ref"]] = 1
	profile.earn(float(l[i]["cr"]), "daily", str(l[i]["ref"]), {"once": true})
	return int(l[i]["cr"])
