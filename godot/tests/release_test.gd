## Prueba de lo gratis y lo pago: 5 etapas de la aventura y las copas Debut y Nacional gratis, autos premium por compra (sueltos, garaje o juego completo), y que
## las compras pasen los autos al garaje.
## Uso: godot --headless --path godot --script res://tests/release_test.gd
extends SceneTree

const Release := preload("res://game/data/release.gd")
const Profile := preload("res://game/data/profile.gd")
const Products := preload("res://game/store/products.gd")
const Billing := preload("res://game/store/billing.gd")

var fail := false

func check(ok: bool, msg: String) -> void:
	print(("OK   " if ok else "FALLA ") + msg)
	if not ok:
		fail = true

func _init() -> void:
	var p := Profile.new()
	p.d["iap"] = {}
	p.d["owned"] = {}
	p.d["settings"]["dev"] = false
	check(Release.adventure_limit(p) == 5 and Release.ADVENTURE_STAGES == 5, "gratis: 5 etapas de la aventura (pedido del dueño, 20/10/2026)")
	check(str(Products.PRODUCTS["dr_adventure"]["desc"]).contains("tenés %d gratis" % Release.ADVENTURE_STAGES), "la descripción de «Aventura completa» dice cuántas etapas son gratis (%d)" % Release.ADVENTURE_STAGES)
	check(Release.tier_allowed(p, "debut") and Release.tier_allowed(p, "nacional") and not Release.tier_allowed(p, "continental"), "gratis: copas Debut y Nacional, no la Continental")
	check(not Release.car_unlocked(p, "gt3") and Release.car_unlocked(p, "gt"), "el GT3 es premium; el Kaze GT no")
	check(not Release.can_buy(p, "hyper") and not Release.can_buy(p, "genesis") and Release.can_buy(p, "gt"), "premium y premio no se pagan con monedas")
	p.d["iap"]["car_gt3"] = true
	Release.sync_cars(p)
	check(Release.car_unlocked(p, "gt3") and not Release.car_unlocked(p, "hyper") and p.owns("gt3") and not p.owns("hyper"), "comprar el GT3 suelto lo deja en el garaje (y solo ese)")
	p.d["iap"]["dr_garage"] = true
	Release.sync_cars(p)
	check(p.owns("truck") and p.owns("hyper") and Release.covers(p, "dr_garage") and not Release.covers(p, "dr_full"), "el garaje premium da los tres")
	p.d["iap"]["dr_adventure"] = true
	check(Release.adventure_limit(p) == 99 and Release.tier_allowed(p, "leyenda") and Release.covers(p, "dr_full"), "aventura + garaje = juego completo")
	var q := Profile.new()
	q.d["iap"] = {"dr_full": true}
	q.d["owned"] = {}
	q.d["settings"]["dev"] = false
	Release.sync_cars(q)
	check(Release.adventure_limit(q) == 99 and q.owns("truck") and q.owns("gt3") and q.owns("hyper"), "el juego completo da todo")
	# lo que se vende es lo mismo en el juego, en el servidor y en la función que le pregunta a Google: si un producto falta en alguno, una compra real no se acredita
	var repo := ProjectSettings.globalize_path("res://").path_join("..")
	var fn_src := FileAccess.get_file_as_string(repo.path_join("supabase/functions/verify-purchase/handler.ts"))
	var sql_src := FileAccess.get_file_as_string(repo.path_join("supabase/migrations/20261014000000_account_economy.sql"))
	if fn_src != "" and sql_src != "":
		var ids_ok := true
		var amounts_ok := true
		var kinds_ok := true
		for pid in Products.ORDER:
			var pdd: Dictionary = Products.PRODUCTS[pid]
			ids_ok = ids_ok and fn_src.contains("'%s'" % pid)
			if str(pdd["kind"]) == "credits":
				amounts_ok = amounts_ok and sql_src.contains("('%s', 'coins', %d)" % [pid, int(pdd["amount"])])
			else:
				kinds_ok = kinds_ok and sql_src.contains("('%s', 'entitlement', 0)" % pid)
		check(ids_ok and Products.ORDER.size() == 10, "los %d productos del juego están en la función verify-purchase" % Products.ORDER.size())
		check(amounts_ok and kinds_ok, "el servidor (account_products) tiene las mismas bolsas de monedas y los mismos desbloqueos que el juego")
	# modo online abierto, herramientas técnicas sólo en desarrollo, tienda de monedas
	check(Release.online_open(p) and Release.ONLINE_OPEN and Release.REALTIME, "el modo online está abierto con tiempo real (autorizado por el dueño el 15/10/2026)")
	check(not (Release.store() and Release.tools()), "la versión de Play no trae herramientas técnicas (📊, RENDIMIENTO)")
	# jugador contra jugador en tiempo real: apagado hasta que el servidor lo habilite (app_flags.pvp, pedido del dueño 15/10/2026)
	q.d["settings"]["dev"] = false
	Release.pvp_remote = false
	check(not Release.PVP_FORCE and not Release.pvp_open(q), "el mundo online en tiempo real está apagado (online por datos)")
	Release.pvp_remote = true
	check(Release.pvp_open(q), "con la bandera del servidor (app_flags.pvp = true) se habilita sin APK nuevo")
	Release.pvp_remote = false
	var packs := 0
	for id in Products.ORDER:
		var pd: Dictionary = Products.PRODUCTS[id]
		if str(pd["kind"]) != "credits":
			continue
		packs += 1
		check(not Release.covers(p, str(id)), "la bolsa %s siempre se puede volver a comprar" % id)
	check(packs == 4 and int(Products.PRODUCTS["dr_coins_s"]["amount"]) < int(Products.PRODUCTS["dr_coins_m"]["amount"]) and int(Products.PRODUCTS["dr_coins_l"]["amount"]) < int(Products.PRODUCTS["dr_coins_xl"]["amount"]), "4 bolsas de monedas, de menor a mayor")
	p.d["iapTokens"] = [] # el perfil de prueba se guarda en disco: arrancar sin recibos
	var bil := Billing.new()
	bil.profile = p
	var before: int = int(p.d["credits"])
	bil._grant_credits("token-1", 5000)
	bil._grant_credits("token-1", 5000) # la misma compra reintentada: no acredita dos veces
	bil._grant_credits("token-2", 12000)
	check(int(p.d["credits"]) == before + 17000, "las monedas se acreditan una sola vez por compra (recibo) [%d → %d]" % [before, int(p.d["credits"])])
	# diagnóstico de compras: si Google no devuelve ningún producto, todos quedan «no disponibles» y se registra el motivo; nunca se acredita nada
	var bd := Billing.new()
	bd.profile = p
	bd._on_details({"response_code": 0, "product_details": [{"product_id": "dr_full", "one_time_purchase_offer_details": {"formatted_price": "US$ 9,99"}}]})
	check(bd.price_of("dr_full") == "US$ 9,99" and not bd.unavailable.has("dr_full") and bd.unavailable.has("dr_coins_s"), "los productos que Google no devuelve quedan como no disponibles (%d)" % bd.unavailable.size())
	bd._on_details({"response_code": 5, "debug_message": "Developer error"})
	check(int(bd.last_error.get("code", -9)) == 5 and str(bd.last_error.get("name", "")) == "DEVELOPER_ERROR", "el error real de Google (código y nombre) queda anotado")
	check(Billing.player_text(4) != Billing.player_text(3) and Billing.player_text(3) != Billing.player_text(99), "el jugador ve motivos distintos: producto no disponible, sin conexión y error genérico")
	bd.free()
	bil.free()
	quit(1 if fail else 0)
