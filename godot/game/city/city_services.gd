extends RefCounted
## Los servicios de Dream City que viven dentro de la carrera (Etapa 23: antes se creaban y actualizaban sueltos en race.gd): locales (talleres y concesionario), bocas de túnel y estacionamiento,
## nafta y gasolineras, desgaste de gomas, actividades (radares, contrarreloj, encargos), peajes y la Plaza de Drift.
## race.gd sólo hace: services = CityServices.new(); services.setup(self); services.update(dt). Cada servicio sigue accesible como race.fuel, race.tires… (los otros módulos los usan así).

const CityShops := preload("res://game/city/city_shops.gd")
const CityLinks := preload("res://game/city/city_links.gd")
const CityDrift := preload("res://game/city/city_drift.gd")
const CityFuel := preload("res://game/city/city_fuel.gd")
const CityTires := preload("res://game/city/city_tires.gd")
const CityActivities := preload("res://game/city/city_activities.gd")
const CityToll := preload("res://game/city/city_toll.gd")

var race # race.gd

func setup(p_race) -> void:
	race = p_race
	var track = race.track
	race.shops = CityShops.new()
	race.shops.setup(race, track.world_node, track.city)
	race.links = CityLinks.new()
	race.links.setup(race, track.world_node, track.city)
	race.fuel = CityFuel.new()
	race.fuel.setup(race, track.city)
	race.tires = CityTires.new() # desgaste de gomas (Etapa 13)
	race.tires.setup(race)
	race.acts = CityActivities.new() # radares, contrarreloj y encargos (Etapa 15)
	race.acts.setup(race, track.city, track.world_node)
	race.tolls = CityToll.new()
	race.tolls.setup(race, track.world_node, track.city)
	race.city_drift = CityDrift.new()
	race.city_drift.setup(race, track.world_node, track.city)

func update(dt: float) -> void:
	race.shops.update(dt)
	race.links.update(dt)
	race.fuel.update(dt)
	if race.tires != null:
		race.tires.update(dt)
	if race.acts != null:
		race.acts.update(dt)
	race.tolls.update(dt)
	if race.city_drift != null:
		race.city_drift.update(dt)
