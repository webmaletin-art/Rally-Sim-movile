extends Node
## Compras dentro del juego con Google Play Billing (plugin «GodotGooglePlayBilling», que el flujo de compilación del AAB instala).
## Sin el plugin (APK de prueba, compu) todo queda «no disponible» y el juego sigue andando igual.
## Las compras se acreditan acá (perfil) y se reconocen/consumen en Google; al abrir se consultan las pendientes para no perder ninguna.
##
## OJO: el plugin no se puede probar fuera de Google Play. Se prueba con la pista de «Prueba interna» de Play Console y una cuenta de
## probador con licencia (ver docs/PLAY_STORE.md). Los nombres de señales y métodos siguen la API del plugin v3 (BillingClient.gd).

const Products := preload("res://game/store/products.gd")
const Release := preload("res://game/data/release.gd")
const Tr := preload("res://game/i18n/tr.gd")

signal state_changed
signal message(text: String)

const ADDON := "res://addons/GodotGooglePlayBilling/BillingClient.gd"
const OK := 0 # BillingClient.BillingResponseCode.OK
const USER_CANCELED := 1
const PURCHASED := 1 # BillingClient.PurchaseState.PURCHASED

var profile: RefCounted
var client = null
var connected := false
var details: Dictionary = {} # id → {"title", "price"}
var busy := false
var _pending_credits: Dictionary = {} # purchase_token → créditos a acreditar cuando Google confirme el consumo

## ¿Está el plugin en esta compilación?
static func supported() -> bool:
	return Engine.has_singleton("GodotGooglePlayBilling") and ResourceLoader.exists(ADDON)

func setup(p: RefCounted) -> void:
	profile = p
	if not supported():
		return
	var script: GDScript = load(ADDON)
	client = script.new()
	if client is Node:
		add_child(client as Node)
	_connect("connected", _on_connected)
	_connect("disconnected", _on_disconnected)
	_connect("connect_error", _on_connect_error)
	_connect("query_product_details_response", _on_details)
	_connect("query_purchases_response", _on_purchases)
	_connect("on_purchase_updated", _on_purchase_updated)
	_connect("acknowledge_purchase_response", _on_ack)
	_connect("consume_purchase_response", _on_consume)
	client.start_connection()

func _connect(sig: String, cb: Callable) -> void:
	if client.has_signal(sig):
		client.connect(sig, cb)

func is_ready() -> bool:
	return client != null and connected

func owned(id: String) -> bool:
	return profile != null and ((profile.d.get("iap", {}) as Dictionary).get(id, false) == true)

func price_of(id: String) -> String:
	return str((details.get(id, {}) as Dictionary).get("price", ""))

## Compra (abre la hoja de Google Play)
func buy(id: String) -> void:
	if not is_ready():
		message.emit(Tr.t("Las compras no están disponibles ahora. Probá de nuevo en un momento."))
		return
	busy = true
	state_changed.emit()
	var r: Variant = client.purchase(id)
	if r is Dictionary and int((r as Dictionary).get("response_code", OK)) != OK:
		busy = false
		message.emit(Tr.t("No se pudo iniciar la compra."))
		state_changed.emit()

## Vuelve a pedir a Google lo comprado (por si se reinstaló el juego o quedó algo pendiente)
func restore() -> void:
	if is_ready():
		client.query_purchases(0) # ProductType.INAPP
		message.emit(Tr.t("Buscando tus compras…"))

func _on_connected() -> void:
	connected = true
	client.query_product_details(Products.ids(), 0) # ProductType.INAPP
	client.query_purchases(0)
	state_changed.emit()

func _on_disconnected() -> void:
	connected = false
	state_changed.emit()

func _on_connect_error(_code = 0, _msg = "") -> void:
	connected = false
	state_changed.emit()

func _on_details(result: Dictionary) -> void:
	if int(result.get("response_code", result.get("result_code", OK))) != OK:
		return
	for d in result.get("product_details", []):
		var dd: Dictionary = d
		var id := str(dd.get("product_id", ""))
		var price := ""
		var offer: Variant = dd.get("one_time_purchase_offer_details")
		if offer is Dictionary:
			price = str((offer as Dictionary).get("formatted_price", ""))
		details[id] = {"title": str(dd.get("title", "")), "price": price}
	state_changed.emit()

func _on_purchases(result: Dictionary) -> void:
	for p in result.get("purchases", []):
		_handle(p)

func _on_purchase_updated(result: Dictionary) -> void:
	busy = false
	var code := int(result.get("response_code", -1))
	if code == OK:
		for p in result.get("purchases", []):
			_handle(p)
	elif code != USER_CANCELED:
		message.emit(Tr.t("No se pudo completar la compra."))
	state_changed.emit()

func _handle(p: Dictionary) -> void:
	if int(p.get("purchase_state", PURCHASED)) != PURCHASED:
		return # pendiente: se acredita cuando Google la confirme
	var token := str(p.get("purchase_token", ""))
	for id in p.get("product_ids", []):
		var def: Variant = Products.PRODUCTS.get(str(id))
		if def == null:
			continue
		var pd: Dictionary = def
		if str(pd["kind"]) == "credits":
			_pending_credits[token] = int(pd["amount"])
			client.consume_purchase(token)
		else:
			_grant_unlock(str(id))
			if p.get("is_acknowledged", false) != true:
				client.acknowledge_purchase(token)

func _grant_unlock(id: String) -> void:
	if profile == null or owned(id):
		return
	if not profile.d.has("iap"):
		profile.d["iap"] = {}
	profile.d["iap"][id] = true
	profile.save()
	message.emit(Tr.t("¡Gracias! Compra lista."))
	state_changed.emit()

func _on_ack(_result = null) -> void:
	pass

func _on_consume(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != OK:
		return
	var token := str(result.get("purchase_token", ""))
	if not _pending_credits.has(token):
		return
	var n: int = _pending_credits[token]
	_pending_credits.erase(token)
	profile.earn(n)
	profile.save()
	message.emit(Tr.t("¡Gracias! Te acreditamos $ %d.") % n)
	state_changed.emit()
