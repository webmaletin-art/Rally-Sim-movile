## La economía de la CUENTA en el cliente (online/account_econ.gd + los ganchos de profile.gd): los premios y las compras se anotan como eventos, se mandan al servidor en tandas, el estado del servidor manda
## (lo que el servidor no reconoce desaparece), sin conexión se sigue jugando y se manda después, y el archivo tocado a mano se detecta. El «servidor» es un doble que imita las reglas de
## supabase/migrations/20261014000000_account_economy.sql (esas reglas se prueban aparte con tools/online/account_test.sql contra Postgres de verdad). Sin red.
## Uso: godot --headless --path godot --script res://tests/account_econ_test.gd
extends SceneTree

const Profile := preload("res://game/data/profile.gd")
const CarBuild := preload("res://game/data/car_build.gd")
const Release := preload("res://game/data/release.gd")
const AccountEcon := preload("res://game/online/account_econ.gd")
const MenuAbout := preload("res://game/ui/menu_about.gd")

## Doble de online.gd: sesión de cuenta y un servidor de mentira con las mismas reglas que el SQL
class FakeOnline:
	extends Node
	var cfg := true
	var account := true
	var uid := "11111111-1111-1111-1111-111111111111"
	var offline := false
	var missing := false # el servidor no tiene las funciones (404)
	var expired := false # la sesión ya no sirve
	# estado del «servidor»
	var credits := 5000
	var cars := {}
	var iap := {}
	var daily := ""
	var streak := 0
	var seen := {}
	var earned_hour := 0
	var calls := 0
	var batches: Array = []

	func configured() -> bool:
		return cfg
	func is_account() -> bool:
		return account

	func _state() -> Dictionary:
		return {"credits": credits, "cars": cars.duplicate(true), "iap": iap.duplicate(true), "streak": streak, "daily": daily, "seq": calls}

	func _fail(code: int, msg: String) -> Dictionary:
		return {"ok": false, "code": code, "data": null, "error": msg}

	func call_fn(fn: String, args: Dictionary) -> Dictionary:
		calls += 1
		if offline:
			return _fail(0, "sin conexión")
		if expired:
			return _fail(401, "JWT expired")
		if missing:
			return _fail(404, "Could not find the function public.%s" % fn)
		if fn == "account_state":
			return {"ok": true, "code": 200, "data": _state(), "error": ""}
		if fn == "account_apply":
			var evs: Array = args["p_events"]
			batches.append(evs.size())
			var results: Array = []
			for e in evs:
				var eid := str(e.get("id", ""))
				if seen.has(eid):
					results.append({"id": eid, "ok": true, "dup": true})
					continue
				var r := _one(e)
				seen[eid] = true
				var rr: Dictionary = {"id": eid}
				rr.merge(r)
				results.append(rr)
			var st := _state()
			st["results"] = results
			return {"ok": true, "code": 200, "data": st, "error": ""}
		return _fail(404, "Could not find the function public.%s" % fn)

	func call_edge(fn: String, args: Dictionary) -> Dictionary:
		if offline:
			return _fail(0, "sin conexión")
		if fn == "verify-purchase":
			var pid := str(args.get("product_id", ""))
			if str(args.get("purchase_token", "")) == "mala":
				return _fail(402, "recibo inválido")
			if pid.begins_with("dr_coins_"):
				var packs: Dictionary = {"dr_coins_s": 5000, "dr_coins_m": 12000, "dr_coins_l": 30000, "dr_coins_xl": 80000}
				var amount: int = int(packs[pid])
				var key := "tok:" + str(args.get("purchase_token", ""))
				if not seen.has(key):
					seen[key] = true
					credits += amount
			else:
				iap[pid] = {"at": 1}
			return {"ok": true, "code": 200, "data": {"ok": true, "state": _state()}, "error": ""}
		return _fail(404, "not found")

	func _has(product: String) -> bool:
		return iap.has(product) or iap.has("dr_full") or (product in ["car_truck", "car_gt3", "car_hyper"] and iap.has("dr_garage"))

	func _one(e: Dictionary) -> Dictionary:
		var t := str(e.get("t", ""))
		var car := str(e.get("car", ""))
		var cat: Dictionary = CarBuild.catalog()["cars"]
		match t:
			"earn":
				var a := mini(int(e.get("amount", 0)), 60000)
				if a <= 0:
					return {"ok": false, "reason": "monto inválido"}
				if earned_hour + a > 300000:
					return {"ok": false, "reason": "llegaste al límite de premios, probá en un rato"}
				earned_hour += a
				credits += a
				return {"ok": true, "granted": a}
			"spend":
				credits = maxi(0, credits - int(e.get("amount", 0)))
				return {"ok": true}
			"daily":
				var today := Time.get_date_string_from_system(true)
				if daily == today:
					return {"ok": false, "reason": "ya cobraste el regalo de hoy"}
				var y := Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)
				streak = mini(7, streak + 1) if daily == y else 1
				daily = today
				credits += 300 + streak * 150
				return {"ok": true}
			"give_car":
				var why := str(e.get("why", ""))
				if cars.has(car):
					return {"ok": true, "dup": true}
				if why == "starter" and cars.is_empty() and bool((cat.get(car, {}) as Dictionary).get("starter", false)):
					cars[car] = {"owned": [], "tires": ["street"], "parts": []}
					return {"ok": true}
				if why == "iap" and Release.PREMIUM_CARS.has(car) and _has(str(Release.PREMIUM_CARS[car])):
					cars[car] = {"owned": [], "tires": ["street"], "parts": []}
					return {"ok": true}
				if why == "adventure" and Release.REWARD_CARS.has(car):
					cars[car] = {"owned": [], "tires": ["street"], "parts": []}
					return {"ok": true}
				return {"ok": false, "reason": "no corresponde"}
			"buy_car":
				if not cat.has(car) or cars.has(car) or Release.PREMIUM_CARS.has(car) or Release.REWARD_CARS.has(car):
					return {"ok": false, "reason": "no se puede comprar"}
				var price := int(cat[car]["price"])
				if credits < price:
					return {"ok": false, "reason": "no te alcanza el dinero"}
				credits -= price
				cars[car] = {"owned": [], "tires": ["street"], "parts": []}
				return {"ok": true}
			"buy_upgrade":
				if not cars.has(car):
					return {"ok": false, "reason": "ese auto no es tuyo"}
				var u := CarBuild.upgrade(str(e.get("cat", "")))
				var lv := int(e.get("level", 0))
				if u.is_empty() or lv < 1 or lv >= (u["levels"] as Array).size():
					return {"ok": false, "reason": "esa mejora no existe"}
				var key2 := "%s:%d" % [str(e["cat"]), lv]
				if (cars[car]["owned"] as Array).has(key2):
					return {"ok": true, "dup": true}
				var cost := int(u["levels"][lv].get("cost", 0))
				if credits < cost:
					return {"ok": false, "reason": "no te alcanza el dinero"}
				credits -= cost
				(cars[car]["owned"] as Array).append(key2)
				return {"ok": true}
			"buy_tires":
				if not cars.has(car):
					return {"ok": false, "reason": "ese auto no es tuyo"}
				var tcost := int(CarBuild.tire(str(e.get("tire", ""))).get("cost", 0))
				if (cars[car]["tires"] as Array).has(str(e["tire"])):
					return {"ok": true, "dup": true}
				if credits < tcost:
					return {"ok": false, "reason": "no te alcanza el dinero"}
				credits -= tcost
				(cars[car]["tires"] as Array).append(str(e["tire"]))
				return {"ok": true}
			"replace_tires":
				if not cars.has(car):
					return {"ok": false, "reason": "ese auto no es tuyo"}
				var rc := int(e.get("cost", 0))
				if credits < rc:
					return {"ok": false, "reason": "no te alcanza el dinero"}
				credits -= rc
				return {"ok": true}
		return {"ok": false, "reason": "evento desconocido"}

var fails := 0
var corrected_msgs: Array = []

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fails += 1

func _fresh_profile() -> Profile:
	var p: Profile = Profile.new()
	p.d = Profile.default_profile()
	p.d["settings"]["dev"] = false
	return p

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var on := FakeOnline.new()
	root.add_child(on)
	var p := _fresh_profile()
	var acc: Node = AccountEcon.new()
	root.add_child(acc)
	acc.attach(p, on)
	acc.corrected.connect(func(t: String) -> void: corrected_msgs.append(t))

	# ───── la cuenta manda sólo con Supabase configurado y sin modo desarrollador ─────
	check(Release.ACCOUNT_REQUIRED and Release.account_mode(p, on) and acc.is_active(), "cuenta obligatoria: con Supabase y sin modo desarrollador la economía es del servidor")
	on.cfg = false
	check(not acc.is_active() and acc.gate_state() == "", "sin Supabase configurado el juego anda todo local")
	on.cfg = true
	p.d["settings"]["dev"] = true
	check(not Release.store() and not acc.is_active(), "con el modo desarrollador (sólo en compilaciones de prueba) también es todo local")
	p.d["settings"]["dev"] = false
	check(Release.ACCOUNT_GRACE_DAYS == 14, "los 14 días de gracia que dicen los textos legales (menu_about.gd) son los del código")

	# ───── puerta de entrada ─────
	on.account = false
	check(acc.gate_state() == "login", "sin sesión hay que iniciar sesión")
	on.account = true
	check(acc.gate_state() == "sync", "con sesión pero sin verificar con el servidor (cuenta nueva en este teléfono) hay que conectarse")

	# ───── cuenta nueva: se trae el estado y se pide el auto de partida ─────
	var r: Dictionary = await acc.on_login()
	check(bool(r["ok"]), "iniciar sesión trae el estado del servidor")
	check(p.credits == 5000 and p.owns("hatch") and on.cars.has("hatch"), "cuenta nueva: $5000 y el auto de partida, que pidió el cliente y aceptó el servidor")
	check(acc.pending_count() == 0 and acc.status == "ok" and acc.gate_state() == "", "ya no queda nada esperando y se puede jugar")

	# ───── premios: se ven al instante y el servidor los confirma ─────
	p.earn(1500.0, "race", "debut_1")
	check(p.credits == 6500 and acc.pending_count() == 1, "un premio se suma al instante en pantalla y queda esperando para el servidor")
	r = await acc.sync()
	check(on.credits == 6500 and p.credits == 6500 and acc.pending_count() == 0, "el servidor lo acredita y el saldo en pantalla coincide")

	# ───── trampa: editar el saldo y regalarse un auto en profile.json ─────
	p.d["credits"] = 99999999
	p.d["owned"]["hyper"] = Profile.new_car_state("hyper")
	check(acc.tampered(), "editar el archivo a mano rompe el sello de integridad")
	r = await acc.sync()
	check(p.credits == 6500 and not p.owns("hyper") and not acc.tampered(), "el servidor pisa lo editado: vuelve al saldo y a los autos de verdad")

	# ───── compras: precio y saldo los pone el servidor ─────
	on.credits = 100000
	p.d["credits"] = 100000
	check(p.buy_car("torito"), "comprar un auto en pantalla anda al instante")
	var price := int(CarBuild.catalog()["cars"]["torito"]["price"])
	check(p.credits == 100000 - price and p.owns("torito"), "se descuenta el precio del catálogo")
	r = await acc.sync()
	check(on.cars.has("torito") and on.credits == 100000 - price and p.credits == on.credits, "el servidor confirma la compra con el mismo precio")
	# trampa: saldo inflado en el teléfono para comprar un auto caro que el servidor no puede cobrar
	on.credits = 1000
	p.d["credits"] = 500000
	check(p.buy_car("veltor_gtr"), "con el saldo inflado en el teléfono la compra «anda» en pantalla")
	corrected_msgs.clear()
	r = await acc.sync()
	check(not p.owns("veltor_gtr") and not on.cars.has("veltor_gtr") and p.credits == 1000, "el servidor rechaza (no hay saldo): el auto desaparece y el saldo vuelve al de verdad")
	check(corrected_msgs.size() == 1, "y el juego avisa que se ajustó la cuenta (%d aviso)" % corrected_msgs.size())
	# autos premium: sólo con la compra
	p.give("hyper")
	r = await acc.sync()
	check(not p.owns("hyper"), "un auto premium regalado sin la compra no se queda")
	p.give("hyper", "iap")
	r = await acc.sync()
	check(not p.owns("hyper") and not on.cars.has("hyper"), "pedirlo como «comprado» sin compra tampoco: lo rechaza el servidor")

	# ───── mejoras ─────
	on.credits = 50000
	p.d["credits"] = 50000
	var ucost := int(CarBuild.upgrade("engine")["levels"][1].get("cost", 0))
	check(p.buy_upgrade("hatch", "engine", 1) and p.credits == 50000 - ucost, "comprar la mejora de motor 1 descuenta su costo")
	r = await acc.sync()
	check((on.cars["hatch"]["owned"] as Array).has("engine:1") and p.upgrade_level("hatch", "engine") == 1 and p.credits == on.credits, "el servidor la anota y el auto sigue con la mejora puesta")
	p.d["owned"]["hatch"]["upg"]["brakes"] = 3 # trampa: un nivel puesto sin comprar
	r = await acc.sync()
	check(p.upgrade_level("hatch", "brakes") == 0, "un nivel de mejora puesto sin comprarlo se saca")
	p.d["owned"]["hatch"]["upg"]["turbo"] = 9 # (un nivel que ni existe)
	r = await acc.sync()
	check(p.upgrade_level("hatch", "turbo") == 0, "un nivel de mejora que ni existe también")
	# gomas
	var tc := int(CarBuild.tire("sport").get("cost", 0))
	var c0: int = p.credits
	check(p.buy_tires("hatch", "sport") and p.credits == c0 - tc, "comprar gomas deportivas")
	r = await acc.sync()
	check((on.cars["hatch"]["tires"] as Array).has("sport") and str(p.d["owned"]["hatch"]["tires"]) == "sport", "el servidor las anota")
	p.d["owned"]["hatch"]["tires"] = "slick" # trampa: unas gomas que no compró
	r = await acc.sync()
	check(str(p.d["owned"]["hatch"]["tires"]) == "street", "unas gomas puestas sin comprarlas vuelven a las de calle")
	# cambio de gomas
	c0 = p.credits
	var paid: int = p.replace_tires("hatch")
	check(paid >= 250 and c0 - p.credits == paid, "cambiar las gomas cobra (mínimo $250)")
	r = await acc.sync()
	check(p.credits == on.credits, "el servidor cobra lo mismo")

	# ───── gastos y regalo diario ─────
	c0 = p.credits
	check(p.spend(120, "fuel") and p.credits == c0 - 120, "un gasto (nafta) se ve al instante")
	var d := p.daily_check()
	check(not d.is_empty() and int(d["amount"]) == 450, "el regalo diario del primer día: $450")
	r = await acc.sync()
	check(p.credits == on.credits and on.daily == Time.get_date_string_from_system(true), "el servidor confirma el gasto y el regalo (el día se cuenta en UTC)")
	check(p.daily_check().is_empty(), "el mismo día no se cobra de nuevo")

	# ───── sin conexión: se juega y se manda después ─────
	on.offline = true
	c0 = p.credits
	p.earn(700.0, "race", "debut_2")
	p.earn(300.0, "race", "debut_3")
	check(p.credits == c0 + 1000 and acc.pending_count() == 2, "sin conexión se sigue ganando y quedan esperando 2 premios")
	r = await acc.sync()
	check(not bool(r["ok"]) and acc.status == "offline" and acc.pending_count() == 2, "sin conexión: no se pierde nada, queda en cola (estado «sin conexión»)")
	check(acc.gate_state() == "", "con la última verificación reciente se puede jugar sin conexión")
	on.offline = false
	r = await acc.sync()
	check(bool(r["ok"]) and acc.pending_count() == 0 and p.credits == c0 + 1000 and on.credits == p.credits, "al volver la conexión se mandan y todo coincide")
	# demasiados días sin verificar
	var ac: Dictionary = p.d["acct"]
	ac["synced"] = int(Time.get_unix_time_from_system()) - (Release.ACCOUNT_GRACE_DAYS + 1) * 86400
	p.save()
	check(acc.gate_state() == "sync", "pasados los días de gracia hay que conectarse a verificar")
	r = await acc.sync()
	check(acc.gate_state() == "", "y con la verificación vuelve a poder jugar")

	# ───── el mismo evento dos veces (se cerró el juego a mitad de camino) ─────
	var pend_before: Array = []
	p.earn(1000.0, "race", "debut_9")
	for e in (p.d["acct"]["pending"] as Array):
		pend_before.append((e as Dictionary).duplicate(true))
	r = await acc.sync()
	var c_after: int = on.credits
	(p.d["acct"]["pending"] as Array).append_array(pend_before) # el cliente «no se enteró» y los vuelve a mandar
	r = await acc.sync()
	check(on.credits == c_after and p.credits == on.credits, "un evento repetido no se cobra dos veces (idempotente por id)")

	# ───── tandas: no más de 40 por vez ─────
	for i in 95:
		p.spend(1, "x")
	on.batches.clear()
	r = await acc.sync()
	check(acc.pending_count() == 0 and on.batches.size() == 3 and on.batches.max() <= 40, "95 eventos juntos salen en %d tandas de a lo sumo 40" % on.batches.size())
	check(p.credits == on.credits, "y el saldo coincide")

	# ───── compras de la tienda: las verifica el servidor ─────
	r = await acc.verify_purchase("dr_coins_m", "tok1")
	check(bool(r["ok"]) and p.credits == on.credits, "una bolsa de monedas verificada acredita lo que dice el servidor")
	var c1: int = p.credits
	r = await acc.verify_purchase("dr_coins_m", "tok1")
	check(bool(r["ok"]) and p.credits == c1, "el mismo recibo otra vez no acredita de nuevo")
	r = await acc.verify_purchase("dr_coins_m", "mala")
	check(not bool(r["ok"]) and p.credits == c1, "un recibo inválido no acredita nada")
	check(not Release.car_unlocked(p, "hyper"), "antes de comprar, el auto premium está bloqueado")
	r = await acc.verify_purchase("car_hyper", "tok2")
	check(bool(r["ok"]) and Release.car_unlocked(p, "hyper"), "la compra del auto desbloquea el producto según el servidor")
	Release.sync_cars(p)
	r = await acc.sync()
	check(p.owns("hyper") and on.cars.has("hyper"), "y el auto premium comprado pasa al garaje (el servidor lo acepta)")
	p.d["iap"]["dr_full"] = true # trampa: regalarse el juego completo en el archivo
	check(Release.full(p), "(en pantalla el juego completo se ve desbloqueado…)")
	r = await acc.sync()
	check(not Release.full(p), "…hasta que el servidor, que es el que sabe qué se compró, lo saca")

	# ───── premio de la aventura ─────
	p.give("genesis", "adventure")
	r = await acc.sync()
	check(p.owns("genesis") and on.cars.has("genesis"), "el auto de premio de la aventura se entrega")

	# ───── otra cuenta en el mismo teléfono ─────
	on.uid = "22222222-2222-2222-2222-222222222222"
	on.credits = 5000
	on.cars = {}
	on.iap = {}
	on.daily = ""
	on.streak = 0
	check(acc.gate_state() == "sync", "otra cuenta en el mismo teléfono: hay que verificarla")
	r = await acc.on_login()
	check(p.credits == 5000 and p.owns("hatch") and not p.owns("torito") and not p.owns("hyper") and not Release.car_unlocked(p, "hyper"), "se borra lo de la cuenta anterior y se trae lo de la nueva")

	# ───── cerrar sesión ─────
	acc.on_logout()
	check(p.credits == 0 and (p.d["owned"] as Dictionary).is_empty() and (p.d["iap"] as Dictionary).is_empty(), "al cerrar sesión se borra lo de la economía de este teléfono")

	# ───── sesión vencida ─────
	on.uid = "11111111-1111-1111-1111-111111111111"
	await acc.on_login()
	on.expired = true
	var lost := {"v": false} # (las variables locales se copian en una lambda: se usa un diccionario)
	acc.login_needed.connect(func() -> void: lost["v"] = true)
	p.earn(100.0, "race", "x1")
	r = await acc.sync()
	check(not bool(r["ok"]) and acc.status == "login" and bool(lost["v"]), "si la sesión venció se pide iniciar sesión de nuevo (y no se pierde lo que esperaba)")
	check(acc.pending_count() == 1, "…el premio sigue en la cola")
	on.expired = false

	# ───── servidor sin la migración (compilación de prueba) ─────
	on.missing = true
	r = await acc.sync()
	check(acc.server_missing and not acc.is_active() and acc.gate_state() == "", "servidor sin actualizar: en la compilación de prueba se sigue con lo local (no se bloquea el juego)")
	var cl: int = p.credits
	p.earn(50.0)
	check(p.credits == cl + 50 and acc.pending_count() == 1, "…y los premios locales ya no se anotan para el servidor")
	on.missing = false
	acc.server_missing = false

	# ───── reconcile (pura): piezas y autos que el servidor no reconoce ─────
	var dd := Profile.default_profile()
	dd["owned"]["hatch"] = Profile.new_car_state("hatch")
	dd["owned"]["hatch"]["mods"] = {"wheel": {"id": "rim_star5"}}
	dd["owned"]["hatch"]["partsOwned"] = ["rim_star5"]
	dd["owned"]["gt"] = Profile.new_car_state("gt")
	var rep := AccountEcon.reconcile(dd, {"credits": 777, "cars": {"hatch": {"owned": [], "tires": ["street"], "parts": []}}, "iap": {"dr_adventure": {}}, "streak": 3, "daily": "2026-10-01"}, [])
	check(int(dd["credits"]) == 777 and not (dd["owned"] as Dictionary).has("gt") and (rep["removed"] as Array).has("gt"), "reconcile: el saldo y los autos son los del servidor")
	check(not (dd["owned"]["hatch"]["mods"] as Dictionary).has("wheel") and int(rep["fixed"]) >= 1, "reconcile: una pieza instalada que la cuenta no compró se saca")
	check((dd["iap"] as Dictionary).has("dr_adventure") and Release.full(_wrap(dd)), "reconcile: las compras de la tienda son las del servidor")
	check(str(dd["daily"]["day"]) == "2026-10-01" and int(dd["daily"]["streak"]) == 3, "reconcile: el regalo diario es el del servidor")
	var rep2 := AccountEcon.reconcile(dd, {"credits": 100, "cars": {"hatch": {"owned": [], "tires": ["street"], "parts": []}}, "iap": {}, "streak": 0, "daily": ""}, [{"t": "earn", "amount": 50, "d": 50, "id": "a"}, {"t": "buy_car", "car": "torito", "d": -18000, "id": "b"}])
	check(int(dd["credits"]) == maxi(0, 100 + 50 - 18000), "reconcile: saldo = servidor + lo que todavía no se mandó (nunca negativo)")
	check((dd["owned"] as Dictionary).has("hatch") and not (dd["owned"] as Dictionary).has("torito"), "reconcile: una compra que espera no inventa el auto (se arma con el estado del servidor)")
	check(rep2["removed"] is Array, "reconcile devuelve el informe")
	# ───── vale de taller (premio de eventos): saldo aparte para el taller ─────
	AccountEcon.reconcile(dd, {"credits": 100, "voucher": 30000, "cars": {"hatch": {"owned": [], "tires": ["street"], "parts": []}}, "iap": {}, "streak": 0, "daily": ""}, [{"t": "buy_upgrade", "car": "hatch", "cat": "engine", "level": 1, "d": 0, "v": 5000, "id": "c"}])
	check(int(dd.get("voucher", -1)) == 25000, "reconcile: el vale es el del servidor menos lo que usaron las compras que esperan (%d)" % int(dd.get("voucher", -1)))
	var pv := Profile.new()
	pv.d = Profile.default_profile()
	pv.d["credits"] = 1000
	pv.d["voucher"] = 5000
	check(pv.can_shop(6000) and not pv.can_shop(6001), "con vale: alcanza para el taller con créditos + vale")
	check(pv._take_shop(5500, {}) and pv.voucher() == 0 and pv.credits == 500, "una compra del taller usa primero el vale y después los créditos")
	check(not pv._take_shop(600, {}) and pv.credits == 500, "sin vale ni créditos suficientes no se compra")
	pv.d["voucher"] = 2000
	check(pv.spend(300, "fuel") and pv.voucher() == 2000 and pv.credits == 200, "la nafta no se paga con el vale")
	check(pv.spend(1500, "tune") and pv.voucher() == 500 and pv.credits == 200, "el reglaje sí se paga con el vale")

	# ───── los textos legales dicen lo mismo que el código ─────
	var src := FileAccess.get_file_as_string("res://game/ui/menu_about.gd")
	check("más de 14 días" in src, "el texto de privacidad dice 14 días (=ACCOUNT_GRACE_DAYS)")
	check(MenuAbout.CONSENT_VERSION >= 2, "la aceptación se vuelve a pedir con la cuenta obligatoria")

	on.queue_free()
	acc.queue_free()
	print("ACCOUNT_ECON_TEST ", "OK" if fails == 0 else "FALLÓ (%d)" % fails)
	quit(1 if fails > 0 else 0)

## un perfil mínimo con esos datos (para preguntarle a Release)
func _wrap(data: Dictionary) -> RefCounted:
	var w: RefCounted = Profile.new()
	w.d = data
	return w
