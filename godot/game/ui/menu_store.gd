extends RefCounted
## Pantalla COMPRAS: el juego completo (compra única) y bolsas de créditos, con Google Play Billing (store/billing.gd).
## Los precios vienen de Google Play; sin el plugin (APK de prueba) la pantalla se ve pero no se puede comprar.

const Kit := preload("res://game/ui/ui_kit.gd")
const Products := preload("res://game/store/products.gd")
const Billing := preload("res://game/store/billing.gd")
const Release := preload("res://game/data/release.gd")
const Tr := preload("res://game/i18n/tr.gd")

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
	var coins_header := false
	for id in Products.ORDER:
		var pd: Dictionary = Products.PRODUCTS[id]
		if str(pd["kind"]) == "credits" and not coins_header:
			coins_header = true
			m.body.add_child(Kit.label("🪙 " + Tr.t("MONEDAS"), 22, Kit.GOLD))
			m.body.add_child(Kit.wrap("Para comprar autos de la tienda, piezas, pintura y nafta. Se pueden comprar las veces que quieras. Los autos premium y el DR Bisonte XR no se compran con monedas.", 12, Kit.MUTED, 300))
		var have: bool = bil.owned(id)
		var price: String = bil.price_of(id)
		var right := "✔ TUYO" if have else (price if price != "" else "—")
		var pid: String = id
		var b := Kit.card_button("%s  %s" % [pd["icon"], Tr.t(str(pd["name"]))], str(pd["desc"]), right, func() -> void:
			m.sfx.play("click")
			bil.buy(pid), pd.get("best", false) == true and not have, ready and not have and not bil.busy, 82.0, 19)
		m.body.add_child(b)
	m.body.add_child(Kit.button("↻ RESTAURAR COMPRAS", func() -> void:
		m.sfx.play("click")
		bil.restore(), false, 18, Vector2(0, 50)))
	m.body.add_child(Kit.wrap("Las compras las cobra Google Play. Los desbloqueos se pagan una sola vez: si cambiás de teléfono o reinstalás, los recuperás con RESTAURAR COMPRAS. Los autos premium quedan en tu garaje al comprarlos. Las monedas se acreditan al instante y no se restauran.", 12, Kit.MUTED, 300))

func _refresh() -> void:
	if m != null and is_instance_valid(m) and m.screen == "iap":
		m.go("iap", null, false)
		m.update_credits()

## Cartel de ofertas al abrir el juego (una vez por sesión): un auto premium en la sala 3D y lo que se puede desbloquear
func offer_popup() -> void:
	if m.app.offer_shown or Release.dev(m.profile) or (Release.covers(m.profile, "dr_full")):
		return
	m.app.offer_shown = true
	var pick: String = "hyper" if not Release.car_unlocked(m.profile, "hyper") else ("gt3" if not Release.car_unlocked(m.profile, "gt3") else "truck")
	m.refresh_car(pick, m.profile.new_car_state(pick))
	var box := Control.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	m.add_child(box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(dim)
	var p := Kit.panel(18)
	p.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	p.anchor_right = 0.46
	p.offset_left = 16
	p.offset_top = 16
	p.offset_bottom = -16
	p.offset_right = 0
	box.add_child(p)
	var v := Kit.vbox(10)
	p.add_child(v)
	v.add_child(Kit.label("💎 SEGUÍ CORRIENDO", 30, Kit.ACCENT))
	v.add_child(Kit.wrap("Ya tenés gratis la Copa Debut, 3 etapas de la aventura y todas las pistas. Desbloqueá más:", 17, Kit.TEXT, 320))
	for id in ["dr_full", "dr_adventure", "dr_garage"]:
		var pd: Dictionary = Products.PRODUCTS[id]
		v.add_child(Kit.label("%s  %s" % [pd["icon"], pd["name"]], 20, Kit.GOLD))
		v.add_child(Kit.wrap(str(pd["desc"]), 14, Kit.MUTED, 320))
	var spacer := Kit.spacer()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(Kit.button("VER LAS OFERTAS", func() -> void:
		m.sfx.play("click")
		box.queue_free()
		m.refresh_car()
		m.go("iap"), true, 22, Vector2(0, 58)))
	v.add_child(Kit.button("AHORA NO", func() -> void:
		m.sfx.play("click")
		box.queue_free()
		m.refresh_car(), false, 18, Vector2(0, 46)))
