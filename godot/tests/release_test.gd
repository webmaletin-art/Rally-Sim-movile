## Prueba de lo gratis y lo pago: 3 etapas y la copa Debut gratis, autos premium por compra (sueltos, garaje o juego completo), y que
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
	check(Release.adventure_limit(p) == 3, "gratis: 3 etapas de la aventura")
	check(Release.tier_allowed(p, "debut") and not Release.tier_allowed(p, "nacional"), "gratis: copa Debut, no la Nacional")
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
	# modo online cerrado, herramientas técnicas sólo en desarrollo, tienda de monedas
	check(not Release.online_open(p) and not Release.ONLINE_OPEN, "el modo online está cerrado (salvo modo desarrollador)")
	check(not (Release.store() and Release.tools()), "la versión de Play no trae herramientas técnicas (📊, RENDIMIENTO)")
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
	bil.free()
	quit(1 if fail else 0)
