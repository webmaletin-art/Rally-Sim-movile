extends RefCounted
## Conecta la VIDA DEL MUNDO con Dream City (Etapa 23: antes estaba suelto dentro de race.gd). Crea el núcleo (WorldLife), registra sus sistemas (autos estacionados, tránsito civil, peatones),
## el audio ambiente, y cada cuadro le pasa lo del jugador (posición, velocidad, hora/clima). race.gd sólo hace: life = CityLife.new(); life.setup(self); life.update(dt).
## Expone world_life y ambient para quien los necesite (race.world_life / race.ambient siguen apuntando a los mismos objetos).

const WorldLife := preload("res://game/world/world_life.gd")
const WorldLifeConfig := preload("res://game/world/world_life_config.gd")
const WorldAmbient := preload("res://game/audio/world_ambient.gd")
const ParkedCars := preload("res://game/world/parked_cars.gd")
const CivilTraffic := preload("res://game/world/civil_traffic.gd")
const AmbientPeds := preload("res://game/world/ambient_peds.gd")
const CityLayout := preload("res://game/city/city_layout.gd")

var race # race.gd
var world_life
var ambient

func setup(p_race) -> void:
	race = p_race
	var track = race.track
	var profile = race.profile
	world_life = WorldLife.new() # un solo núcleo para offline y online (online: el servidor da id, versión, semilla y hora al entrar)
	world_life.setup(profile, CityLayout.CELL)
	var pk = ParkedCars.new() # autos estacionados deterministas (Etapa 8)
	pk.attach(track.city, track, track.world_node)
	world_life.register_system(pk)
	var ct = CivilTraffic.new() # tránsito civil cinemático (Etapa 9)
	ct.attach(track.city, track, track.world_node)
	world_life.register_system(ct)
	var pdx = AmbientPeds.new() # peatones de papel 2.5D por las veredas (Etapa 21)
	pdx.attach(track.city, track, track.world_node)
	world_life.register_system(pdx)
	world_life.set_enabled(profile.setting("worldLife") != false)
	ambient = WorldAmbient.new() # ambiente, tránsito en 3D, truenos y eco bajo tierra (Etapa 20)
	race.add_child(ambient)
	var q: String = WorldLifeConfig.profile_for(profile)
	ambient.setup(race, 2 if q == "LOW" else (3 if q == "MEDIUM" else 4))
	ambient.set_level(float(profile.setting("volAmb")) / 100.0)
	race.world_life = world_life
	race.ambient = ambient

## Online: se alinea con el servidor (id, versión, semilla y hora del mundo)
func join_online(online: Node) -> void:
	world_life.join_online(online)

## Cada cuadro (con el auto del jugador ya simulado)
func update(dt: float) -> void:
	if world_life == null or race.cars.is_empty():
		return
	var wp = race.cars[0].phys
	var vel := Vector2(wp.vx, wp.vz)
	var clock = race.clock
	var tsys = world_life.get_system("traffic")
	if tsys != null:
		tsys.player_vel = vel # para que el tránsito reaccione al jugador (frena, esquiva, se golpea)
	var psys = world_life.get_system("peds")
	if psys != null:
		psys.player_vel = vel
		psys.night = float(clock.night) if clock != null else 0.0
		psys.weather_on = race.profile.setting("worldWeather") != false
	world_life.update(dt, Vector2(wp.px, wp.pz))
	if ambient != null:
		ambient.enabled = race.audio_on
		ambient.update(dt, Vector2(wp.px, wp.pz), vel.length())

## Un cambio de Opciones hecho durante el juego
func apply_setting(key: String) -> void:
	var profile = race.profile
	match key:
		"quality", "trees", "shadowsQ", "textures":
			world_life.set_profile(WorldLifeConfig.profile_for(profile)) # LOW / MEDIUM / HIGH según la calidad
		"worldLife":
			world_life.set_enabled(profile.setting("worldLife") != false)
		"volAmb":
			if ambient != null:
				ambient.set_level(float(profile.setting("volAmb")) / 100.0)

## Al salir: guarda la hora del mundo
func save() -> void:
	if world_life != null:
		world_life.save(race.profile)
