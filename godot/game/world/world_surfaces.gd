extends RefCounted
## Superficies del mundo de Dream City (Etapa 14). Qué pisan las ruedas FUERA del asfalto (códigos de VehicleParams.SURF_NAMES: 0 asfalto · 1 tierra/arena · 2 banquina/vereda · 3 pasto · 4 «afuera»
## (roca, entre edificios) · 5 barro · 6 nieve). Es una función pura de la posición (altura, zona de la ciudad y la calle más cercana), así que sirve igual en el cliente, en el servidor y en
## los autos del tránsito. El agarre de cada una sale de `surfGrip` del auto × el neumático (data/catalog.json), y el polvo/sonido ya distinguen cada código (fx/effects.gd, audio/car_audio.gd).
## El color del suelo del mapa (CityWorld._ground_color) usa las mismas alturas, así lo que se ve coincide con lo que se pisa.

const SAND_H := 3.4 # por debajo de esta altura y cerca del mar: arena
const SAND_Z := 1090.0
const ROCK_H := 44.0 # desde acá la sierra es roca (poco agarre)
const SNOW_H := 64.0 # y la cumbre tiene nieve pisada
const VERGE := 6.0 # m de tierra a cada lado de una ruta rural/panorámica
const PLAZA_R := 56.0

const SAND := 1
const GRASS := 3
const OUTSIDE := 4
const SNOW := 6

## Superficie fuera de la calzada: h = altura del terreno ahí; zone = CityLayout.zone_of; clearance = CityLayout.verge_clearance (holgura al borde de la ruta de campo más cercana; -1e9 si no se calculó)
static func outside(x: float, z: float, h: float, zone: int, clearance: float) -> int:
	if h >= SNOW_H:
		return SNOW
	if h >= ROCK_H:
		return OUTSIDE
	if z > SAND_Z and h < SAND_H:
		return SAND # la playa
	if x * x + z * z < PLAZA_R * PLAZA_R:
		return GRASS # el pasto de la Plaza Aurora
	if clearance > -VERGE:
		return SAND # banquina de tierra (el polvo y el sonido son los de la tierra suelta)
	if zone >= 2:
		return GRASS # barrio, colina y campo: pasto
	return OUTSIDE

## Color del suelo según la misma regla (para que lo que se ve sea lo que se pisa); Color.TRANSPARENT = que decida la zona
static func color(h: float, z: float, jit: float) -> Color:
	if h >= SNOW_H:
		return Color(0.95 + jit, 0.96 + jit, 0.98)
	if h >= ROCK_H:
		var k := clampf((h - ROCK_H) / (SNOW_H - ROCK_H), 0.0, 1.0)
		return Color(0.56 + jit, 0.54 + jit, 0.50 + jit).lerp(Color(0.80, 0.80, 0.82), k * k)
	if z > SAND_Z and h < SAND_H:
		return Color(0.93 + jit, 0.85 + jit, 0.62 + jit)
	return Color.TRANSPARENT
