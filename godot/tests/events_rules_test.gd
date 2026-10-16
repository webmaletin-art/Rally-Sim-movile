## Fase 5 (eventos y retención): cacería accesible (city_modes → prey_ai / pi_ok), hitos de la temporada (season_due), desafíos del día (game/data/daily.gd:
## día con huso de Argentina, cambio de día, carrera marcada fija, cobro una sola vez, vuelta desde la cuenta al reinstalar) y colección (rewards.gd).
## Sin red ni mundo: sólo reglas. Corta (≈ 1 s). Uso: tools/test/run_test.sh events_rules_test 30
extends SceneTree

const CityModes := preload("res://game/city/city_modes.gd")
const Daily := preload("res://game/data/daily.gd")
const Rewards := preload("res://game/data/rewards.gd")
const Profile := preload("res://game/data/profile.gd")
const AccountEcon := preload("res://game/online/account_econ.gd")

var fail := false

func _check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

## perfil de mentira: lo mismo que usa el juego (d + earn) sin tocar el archivo del perfil
class FakeProfile extends RefCounted:
	var d: Dictionary = {}
	var earns: Array = []
	func earn(n: float, kind := "misc", ref := "", extra := {}) -> void:
		d["credits"] = int(d.get("credits", 0)) + roundi(n)
		earns.append([roundi(n), kind, ref, extra])

func _init() -> void:
	# 1) cacería: la de siempre igual que antes; la accesible sin empujón y con errores
	var hard := CityModes.prey_ai({"n": 3})
	_check(is_equal_approx(hard["power"], 1.15) and is_equal_approx(hard["mu"], 1.12) and is_equal_approx(hard["grip"], 1.15) and is_equal_approx(hard["pace"], 1.12) and not hard["errors"],
		"cacería de siempre (sin parámetros nuevos): +15 % motor, +12 % agarre, ritmo 112 %, sin errores (como antes)")
	var easy := CityModes.prey_ai({"boost": 1.0, "pace": 0.95, "errors": true})
	_check(is_equal_approx(easy["power"], 1.0) and is_equal_approx(easy["mu"], 1.0) and is_equal_approx(easy["grip"], 1.0) and is_equal_approx(easy["pace"], 0.95) and easy["errors"],
		"cacería accesible: la presa sin ventajas, más lenta (95 %) y con errores")
	_check(is_equal_approx(CityModes.prey_ai({"pace": 3.0})["pace"], 1.2) and is_equal_approx(CityModes.prey_ai({"pace": 0.1})["pace"], 0.8), "el ritmo que manda el servidor tiene tope (80–120 %)")
	_check(CityModes.pi_ok({"max_pi": 599}, 487) and not CityModes.pi_ok({"max_pi": 599}, 650) and CityModes.pi_ok({}, 900), "tope de PI: el R2 Turbo de serie (487) entra a la accesible, un PI 650 no; sin tope entra cualquiera")
	# 2) hitos de la temporada
	var se := {"kind": "season", "pts": 70, "hitos": [{"pts": 25, "reward": {"credits": 3000}}, {"pts": 60, "reward": {"credits": 6000}}, {"pts": 150, "reward": {"voucher": 15000}}], "hitos_got": [0.0]}
	_check(CityModes.season_due(se) == 1, "temporada con 70 pts y el primer hito cobrado: toca pedir el de 60")
	se["hitos_got"] = [0, 1]
	_check(CityModes.season_due(se) == -1 and CityModes.next_hito_text(se).contains("150"), "con los dos cobrados no pide nada y muestra el próximo (150 pts): «%s»" % CityModes.next_hito_text(se))
	_check(CityModes.season_due({"kind": "season", "pts": 500}) == -1, "una temporada vieja sin hitos (servidor sin la migración) no pide nada")
	# 3) desafíos del día
	var t0 := Time.get_unix_time_from_datetime_string("2026-10-17T02:59:00")
	_check(Daily.day_of(t0, -3) == "2026-10-16" and Daily.day_of(t0 + 120.0, -3) == "2026-10-17", "el día cambia a la medianoche de Argentina (02:59 UTC = 23:59 del 16; 03:01 UTC = 17)")
	var d := {"owEvents": {"ev_b": {"found": true, "title": "Bajada"}, "ev_a": {"found": true, "title": "Alta"}, "ev_x": {"found": false}}}
	var s1 := Daily.state(d, "2026-10-16")
	var pick := str(s1["pick"])
	_check(["ev_a", "ev_b"].has(pick), "la carrera marcada sale de las descubiertas (%s)" % pick)
	d["owEvents"]["ev_c"] = {"found": true}
	_check(str(Daily.state(d, "2026-10-16")["pick"]) == pick, "descubrir otra el mismo día no cambia la marcada")
	Daily.note(d, "play", false, "ev_x", "2026-10-16")
	Daily.note(d, "play", true, pick, "2026-10-16")
	Daily.note(d, "race", false, "", "2026-10-16")
	var l := Daily.list(d, "2026-10-16")
	_check(l[0]["done"] and l[1]["done"] and not l[2]["done"] and int(l[2]["have"]) == 1, "dos carreras del mapa (una ganada, la marcada) cumplen 0 y 1; un evento del menú deja el 2 en 1/2")
	_check(not Daily.list({"owEvents": {}}, "2026-10-16")[1]["text"].contains("marcada"), "sin carreras descubiertas el desafío es ganar cualquiera")
	var s2 := Daily.state(d, "2026-10-17")
	_check(int(s2["cnt"]["play"]) == 0 and (s2["won"] as Array).is_empty(), "al cambiar el día los contadores vuelven a cero")
	# cobrar: una sola vez, con la clave del día para el servidor
	var fp := FakeProfile.new()
	var today := Daily.today(fp.d)
	Daily.note(fp.d, "play", false, "", today)
	Daily.note(fp.d, "play", false, "", today)
	var cr := Daily.claim(fp, 0)
	_check(cr == 2500 and fp.earns.size() == 1 and str(fp.earns[0][1]) == "daily" and str(fp.earns[0][2]) == today + ":0" and fp.earns[0][3].get("once") == true,
		"cobrar el desafío 0: $2.500, earn «daily» con clave «%s» y once (el servidor no lo paga dos veces)" % (today + ":0"))
	_check(Daily.claim(fp, 0) == 0 and fp.earns.size() == 1, "cobrarlo otra vez no hace nada")
	_check(Daily.claim(fp, 2) == 0, "uno sin cumplir no se cobra")
	# reinstalar: la cuenta devuelve lo cobrado hoy y no se ofrece de nuevo
	var fresh := {"owEvents": {}}
	AccountEcon.restore_progress(fresh, {("daily:%s:0" % today): {"a": 2500}, "daily:2001-01-01:1": {"a": 5000}})
	Daily.note(fresh, "play", false, "", today)
	Daily.note(fresh, "play", false, "", today)
	_check(Daily.list(fresh)[0]["got"] and not (fresh["dailyCh"]["got"] as Dictionary).has("2001-01-01:1"), "al reinstalar, lo cobrado hoy vuelve de la cuenta (y lo de otros días no se guarda)")
	# la configuración del servidor manda
	var dc := {"dailyCfg": {"on": false, "cr": [1000, 2000, 3000]}}
	_check(Daily.ready_count(dc) == 0 and int(Daily.cfg(dc)["cr"][2]) == 3000 and int(Daily.cfg({})["n_play"]) == 2, "la configuración del servidor (apagados, otros premios) pisa la de fábrica")
	# 4) colección
	_check(Rewards.collection_cars().size() == 28 and Rewards.collection_cars(true).size() == 24, "colección: 28 autos (sin el monoplaza) y 24 que se compran con créditos")
	var cp := FakeProfile.new()
	cp.d = Profile.default_profile()
	cp.d["owned"] = {"hatch": {}, "torito": {}, "gt3": {}}
	var owe := {}
	for i in 21:
		owe["e%d" % i] = {"found": true, "wins": 1 if i < 5 else 0}
	cp.d["owEvents"] = owe
	var c := Rewards.collection(cp)
	_check(c["cars"] == [3, 28] and c["buyable"] == [2, 24] and c["found"] == [21, 79] and c["won"] == [5, 79], "la colección cuenta autos (3/28, 2/24 comprables), descubiertas (21/79) y ganadas (5/79)")
	_check(Rewards.ach_done(cp, "owfind20") and not Rewards.ach_done(cp, "owfind79") and not Rewards.ach_done(cp, "owwin25") and not Rewards.ach_done(cp, "carsall"), "metas de colección: «Explorador» cumplida; las otras no")
	_check(Rewards.ach_progress(cp, "carsall") == [2, 24] and Rewards.ach_progress(cp, "owwin25") == [5, 25], "el avance se muestra (2/24, 5/25)")
	var ids: Array = []
	for a in preload("res://game/data/car_build.gd").catalog()["achievements"]:
		ids.append(str(a["id"]))
	_check(ids.has("owfind20") and ids.has("carsall") and ids.size() == 23, "las 4 metas de colección están en el catálogo de logros (%d)" % ids.size())
	print("RESULTADO: ", "FALLA" if fail else "TODO OK")
	quit(1 if fail else 0)
