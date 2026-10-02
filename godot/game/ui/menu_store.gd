extends RefCounted
## Pantalla COMPRAS: el juego completo (compra única) y bolsas de créditos, con Google Play Billing (store/billing.gd).
## Los precios vienen de Google Play; sin el plugin (APK de prueba) la pantalla se ve pero no se puede comprar.

const Kit := preload("res://game/ui/ui_kit.gd")
const Products := preload("res://game/store/products.gd")
const Billing := preload("res://game/store/billing.gd")
const Release := preload("res://game/data/release.gd")

var m: Node # menu.gd

func build() -> void:
	m.set_title("COMPRAS")
	var bil: Node = m.app.billing
	if not bil.state_changed.is_connected(_refresh):
		bil.state_changed.connect(_refresh)
		bil.message.connect(func(t: String) -> void: m.toast(t))
	var ready: bool = bil.is_ready()
	if not Billing.supported():
		m.body.add_child(Kit.wrap("Las compras funcionan en la versión de Google Play. En esta versión de prueba no están disponibles.", 15, Kit.MUTED, 300))
	elif not ready:
		m.body.add_child(Kit.wrap("Conectando con Google Play…", 15, Kit.MUTED, 300))
	for id in Products.ORDER:
		var pd: Dictionary = Products.PRODUCTS[id]
		var have: bool = str(pd["kind"]) == "unlock" and bil.owned(id)
		var price: String = bil.price_of(id)
		var right := "✔ TUYO" if have else (price if price != "" else "—")
		var pid: String = id
		var b := Kit.card_button("%s  %s" % [pd["icon"], pd["name"]], str(pd["desc"]), right, func() -> void:
			m.sfx.play("click")
			bil.buy(pid), false, ready and not have and not bil.busy, 74.0, 19)
		m.body.add_child(b)
	m.body.add_child(Kit.button("↻ RESTAURAR COMPRAS", func() -> void:
		m.sfx.play("click")
		bil.restore(), false, 18, Vector2(0, 50)))
	m.body.add_child(Kit.wrap("Las compras las cobra Google Play. Los créditos son dinero del juego para tu garaje; el juego completo se compra una sola vez y se recupera en otro teléfono con RESTAURAR.", 12, Kit.MUTED, 300))

func _refresh() -> void:
	if m != null and is_instance_valid(m) and m.screen == "iap":
		m.go("iap", null, false)
		m.update_credits()
