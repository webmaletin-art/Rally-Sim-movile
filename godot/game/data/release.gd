extends RefCounted
## Qué incluye la versión pública del juego y qué queda libre en el «modo desarrollador» (del dueño, para probar sin perder el
## progreso real). El modo desarrollador se activa en Opciones → Acerca de (tocar siete veces el número de versión).

## Etapas de la aventura gratis (el resto y las copas Nacional, Continental y Leyenda se desbloquean con el paquete de aventura)
const ADVENTURE_STAGES := 3
## Copas de la carrera abiertas gratis
const PUBLIC_TIERS := ["debut"]
## Autos que solo se consiguen jugando: se ven y se prueban en la concesionaria, pero se compran recién al ganarlos
const REWARD_CARS := ["genesis"]
## Autos premium: no se pagan con monedas, se desbloquean con una compra (cada uno suelto, el paquete de garaje o el juego completo)
const PREMIUM_CARS := {"truck": "car_truck", "gt3": "car_gt3", "hyper": "car_hyper"}

## Versión de Google Play (se compila con la característica «store»): sin modo desarrollador, sin prueba de rendimiento y sin descargas
static func store() -> bool:
	return OS.has_feature("store")

## Hay compras dentro del juego para desbloquear el juego completo (si es false, lo bloqueado dice «próxima actualización»)
const IAP_FULL := true

static func dev(profile: RefCounted) -> bool:
	return not store() and profile != null and profile.setting("dev") == true

static func _iap(profile: RefCounted, id: String) -> bool:
	return profile != null and ((profile.d.get("iap", {}) as Dictionary).get(id, false) == true)

## ¿Tiene la aventura completa y las copas? (paquete de aventura, juego completo o modo desarrollador)
static func full(profile: RefCounted) -> bool:
	return dev(profile) or _iap(profile, "dr_adventure") or _iap(profile, "dr_full")

## ¿Está desbloqueado este auto premium? (suelto, paquete de garaje, juego completo o modo desarrollador)
static func car_unlocked(profile: RefCounted, car_id: String) -> bool:
	if not PREMIUM_CARS.has(car_id):
		return true
	return dev(profile) or _iap(profile, str(PREMIUM_CARS[car_id])) or _iap(profile, "dr_garage") or _iap(profile, "dr_full")

## ¿Ya tiene todo lo que da este producto? (para mostrar «✔ TUYO»)
static func covers(profile: RefCounted, product: String) -> bool:
	match product:
		"dr_adventure":
			return full(profile)
		"dr_garage":
			for id in PREMIUM_CARS:
				if not car_unlocked(profile, str(id)):
					return false
			return true
		"dr_full":
			return full(profile) and covers(profile, "dr_garage")
	for id in PREMIUM_CARS:
		if str(PREMIUM_CARS[id]) == product:
			return car_unlocked(profile, str(id))
	return false

## Pasa a la tienda del jugador los autos premium que ya compró (se llama al abrir y al recibir una compra)
static func sync_cars(profile: RefCounted) -> void:
	if profile == null:
		return
	var changed := false
	for id in PREMIUM_CARS:
		if not profile.owns(str(id)) and car_unlocked(profile, str(id)) and not dev(profile):
			profile.give(str(id))
			changed = true
	if changed:
		profile.save()

static func adventure_limit(profile: RefCounted) -> int:
	return 99 if full(profile) else ADVENTURE_STAGES

static func tier_allowed(profile: RefCounted, tier_id: String) -> bool:
	return full(profile) or PUBLIC_TIERS.has(tier_id)

## ¿Aparece en la concesionaria? (todos: los autos de premio se pueden ver y probar, pero no comprar hasta ganarlos)
static func car_for_sale(_profile: RefCounted, _id: String) -> bool:
	return true

## ¿Se puede comprar con monedas? Los autos de premio (DR Bisonte XR) se consiguen terminando la aventura y los premium con una compra;
## en modo desarrollador todo se compra
static func can_buy(profile: RefCounted, id: String) -> bool:
	if dev(profile):
		return true
	return not REWARD_CARS.has(id) and not PREMIUM_CARS.has(id)

static func lock_text() -> String:
	return "Desbloqueá la aventura completa en 💎 COMPRAS" if IAP_FULL else "Llega en una próxima actualización"

## Activa el modo desarrollador: todos los autos en el garaje y plata para probar piezas
static func activate_dev(profile: RefCounted) -> void:
	var CarBuild := preload("res://game/data/car_build.gd")
	profile.set_setting("dev", true)
	for id in CarBuild.catalog()["order"]:
		profile.give(str(id))
	profile.d["credits"] = maxi(int(profile.d["credits"]), 5000000)
	profile.save()

static func deactivate_dev(profile: RefCounted) -> void:
	profile.set_setting("dev", false)
