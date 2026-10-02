extends RefCounted
## Qué incluye la versión pública del juego y qué queda libre en el «modo desarrollador» (del dueño, para probar sin perder el
## progreso real). El modo desarrollador se activa en Opciones → Acerca de (tocar siete veces el número de versión).

## Etapas de la aventura que se pueden jugar en la versión pública (el resto llega en una actualización)
const ADVENTURE_STAGES := 2
## Copas de la carrera abiertas en la versión pública
const PUBLIC_TIERS := ["debut"]
## Autos que solo se consiguen jugando: se ven y se prueban en la concesionaria, pero se compran recién al ganarlos
const REWARD_CARS := ["genesis"]

static func dev(profile: RefCounted) -> bool:
	return profile != null and profile.setting("dev") == true

static func adventure_limit(profile: RefCounted) -> int:
	return 99 if dev(profile) else ADVENTURE_STAGES

static func tier_allowed(profile: RefCounted, tier_id: String) -> bool:
	return dev(profile) or PUBLIC_TIERS.has(tier_id)

## ¿Aparece en la concesionaria? (todos: los autos de premio se pueden ver y probar, pero no comprar hasta ganarlos)
static func car_for_sale(_profile: RefCounted, _id: String) -> bool:
	return true

## ¿Se puede comprar? Los autos de premio (DR Bisonte XR) se consiguen terminando la aventura; en modo desarrollador se compran
static func can_buy(profile: RefCounted, id: String) -> bool:
	return not REWARD_CARS.has(id) or dev(profile)

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
