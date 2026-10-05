extends RefCounted
## Estado fundamental de World Life. Identifica el mundo (id + versión + semilla) y guarda lo que los demás sistemas necesitan para reconstruir su vida de forma determinista.
## WORLD_VERSION es la versión de las REGLAS (no el tiempo); el tiempo vive en WorldClock. Son conceptos independientes.

const WorldSeed := preload("res://game/world/world_seed.gd")

var world_id := ""
var world_version := 1 # versión de las reglas del mundo (la que manda el servidor, o la del juego sin conexión)
var world_seed := 0
var config_version := 1 # versión de las reglas que trae ESTE juego (world_life.json)
var mode := "offline" # offline | online
var server_synced := false
var enabled := false
var profile_name := "MEDIUM"
var rules: Dictionary = {} # reglas del perfil de rendimiento
var player_pos := Vector2.ZERO
var player_sector := Vector2i(-99999, -99999)

## ¿Las reglas del servidor y las de este juego son compatibles? Si no, los sistemas de vida deberían quedarse quietos (el mundo se vería distinto del de los demás)
func compatible() -> bool:
	return world_version == config_version

## Huella del mundo en un instante: la misma id + versión + semilla + tiempo (en pasos de `bucket` segundos) da siempre el mismo número
func fingerprint(world_time: float, bucket := 1.0) -> int:
	var h := WorldSeed.str_hash(world_id)
	h = WorldSeed.combine(h, world_version)
	h = WorldSeed.combine(h, WorldSeed.fold(world_seed))
	return WorldSeed.combine(h, int(floor(world_time / maxf(bucket, 0.001))))

## Semilla derivada para un sistema (tráfico, estacionados…): mismas reglas en todos los teléfonos, distinta para cada sistema
func system_seed(system_name: String) -> int:
	return WorldSeed.combine(WorldSeed.combine(WorldSeed.str_hash(world_id), world_version), WorldSeed.combine(WorldSeed.fold(world_seed), WorldSeed.str_hash(system_name)))
