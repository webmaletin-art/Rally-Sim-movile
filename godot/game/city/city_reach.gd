extends RefCounted
## Ciudades y pueblos alcanzados (pedido del dueño, 14/10/2026): para aparecer en otra ciudad o pueblo de la región hay que haber llegado una vez manejando
## (pasando los controles policiales de las rutas largas). Al llegar queda anotado en el perfil (ajuste «reached»: nombres de los lugares de spawns.json),
## sale un aviso y desde ahí se puede elegir en «¿DÓNDE APARECER?» (menu_world.gd) y figura en el mapa. Dream City siempre está habilitada.

const RegionServices := preload("res://game/region/region_services.gd")
const Tr := preload("res://game/i18n/tr.gd")

const REACH_R := 450.0 # a menos de esto de la estación de servicio del lugar, se considera que llegaste

var race
var enabled := false
var places: Array = [] # [{name, pos, kind}] los que todavía no se alcanzaron
var _t := 0.0

## Los nombres alcanzados (lo usan el menú y el mapa)
static func reached_of(profile) -> Array:
	if profile == null:
		return []
	var r: Variant = profile.setting("reached")
	return r if r is Array else []

func setup(p_race) -> void:
	race = p_race
	if race.profile == null or race.cfg.get("testCar") != null or race.track.get("region") == null:
		return
	var got := reached_of(race.profile)
	for sp in RegionServices.spawn_list():
		if not got.has(str(sp["name"])):
			places.append({"name": str(sp["name"]), "pos": Vector2(float(sp["x"]), float(sp["z"])), "kind": str(sp.get("kind", "pueblo"))})
	enabled = not places.is_empty()

func update(dt: float) -> void:
	if not enabled or race.cars.is_empty():
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	var ph = race.cars[0].phys
	var p := Vector2(ph.px, ph.pz)
	for i in range(places.size() - 1, -1, -1):
		var pl: Dictionary = places[i]
		if p.distance_to(pl["pos"]) < REACH_R:
			places.remove_at(i)
			var got := reached_of(race.profile).duplicate()
			if not got.has(pl["name"]):
				got.append(pl["name"])
				race.profile.set_setting("reached", got)
				var icon := "🏙" if str(pl["kind"]) == "ciudad" else "🏘"
				if race.race_hud != null:
					race.race_hud.toast("%s %s %s · %s" % [icon, Tr.t("¡Llegaste a"), str(pl["name"]) + "!", Tr.t("ya podés aparecer acá desde el menú")], "good")
	enabled = not places.is_empty()
