extends RefCounted
## La Ruta de los Sueños (modo aventura): toda la ruta, de punta a punta, armada con piezas (rectas, curvas, estaciones,
## talleres, túneles, puentes…). Se genera una sola vez (es determinística) en muestras cada 2,5 m con sus datos: ambiente
## (ciudad, campo, bosque, montaña, cantera, nieve), superficie, ancho, banquina para estacionar, cultivos, etc.
## Cada etapa va de una estación de servicio a la siguiente; adv_track.gd recorta su tramo y lo centra en el origen.

const DS := 2.5

# ambientes (forma del terreno y colores)
enum { CITY, RURAL, FOREST, MOUNTAIN, QUARRY, SNOW, SNOWMT }
const BIOME_NAMES := ["city", "rural", "forest", "mountain", "quarry", "snow", "snowmt"]
# superficies del camino (las mismas de la física)
const S_ASPHALT := 0
const S_DIRT := 1
const S_SNOW := 6
# marcas por muestra
const F_TUNNEL := 1
const F_BRIDGE := 2
const F_STATION := 4
const F_WORKSHOP := 8
const F_UNDER := 16 # pasa por debajo de una avenida (paredes de hormigón a los costados)
const F_MINE := 32 # túnel de la mina (madera y roca)
const F_RAMP := 64

## Estilos de las curvas automáticas: largo de rectas, radios, ángulos (°) y cuánto se puede apartar del rumbo (°)
const STYLES := {
	"rural": {"s": [180.0, 520.0], "r": [180.0, 520.0], "a": [14.0, 45.0], "bound": 55.0},
	"forest": {"s": [50.0, 190.0], "r": [55.0, 190.0], "a": [20.0, 75.0], "bound": 80.0},
	"mountain": {"s": [30.0, 130.0], "r": [38.0, 120.0], "a": [30.0, 105.0], "bound": 95.0},
	"dirt": {"s": [40.0, 180.0], "r": [45.0, 160.0], "a": [20.0, 85.0], "bound": 85.0},
	"quarry": {"s": [40.0, 140.0], "r": [40.0, 110.0], "a": [30.0, 95.0], "bound": 90.0},
	"snow": {"s": [50.0, 170.0], "r": [50.0, 150.0], "a": [20.0, 80.0], "bound": 85.0},
	"fast": {"s": [250.0, 650.0], "r": [300.0, 700.0], "a": [10.0, 30.0], "bound": 40.0},
}

## Antes de la primera etapa: un poco de ruta y la estación de largada
const PRELUDE := [
	{"biome": CITY, "surf": S_ASPHALT, "hw": 4.2, "town": 1, "grade": 0.0},
	["S", 230.0],
	["station", "Estación Aurora"],
]

## Las etapas. rival: name, car (vehículo), paint, skill (ritmo), power y grip (ajuste fino del auto)
const STAGES := [
	{"name": "Villa Aurora", "sub": "Salida del pueblo y primeros campos", "sky": "dia",
		"rival": {"name": "Tito Benítez", "car": "pickup", "paint": "#e8742a", "skill": 0.8, "power": 1.25, "grip": 1.04, "bio": "El más rápido del pueblo. Maneja la camioneta del corralón."},
		"tip": "Arrancás en el pueblo: esquinas a 90° y calles angostas. Frená antes de cada esquina y acelerá a la salida. Afuera del pueblo el asfalto es rápido.",
		"setup": "Asfalto: tracción repartida 40/60 y presiones normales.",
		"pieces": [
			["S", 80.0], ["town", "VILLA AURORA"],
			["S", 150.0], ["R", 15.0, 90.0], ["S", 210.0], ["L", 14.0, 90.0], ["S", 150.0], ["L", 15.0, 90.0], ["S", 120.0], ["R", 16.0, 90.0],
			["S", 200.0], ["R", 70.0, 30.0], ["S", 120.0], ["L", 70.0, 30.0],
			{"biome": RURAL, "town": 0, "crop": 1, "hw": 4.0}, ["S", 150.0], ["sign", "LOS GIRASOLES 9 km"],
			["auto", 2400.0, "rural"],
			{"grade": 0.015}, ["auto", 1300.0, "rural"], {"grade": -0.012}, ["auto", 1300.0, "rural"], {"grade": 0.0},
			["sign", "ESTACIÓN DE SERVICIO 1 km"], ["auto", 700.0, "rural"], ["S", 150.0],
			["station", "Parador Los Girasoles"],
		]},
	{"name": "Campos de Girasol", "sub": "Llanura, chacras y molinos", "sky": "dia",
		"rival": {"name": "Romina «La Colorada» Paz", "car": "t1plus", "paint": "#d81f2a", "skill": 0.82, "power": 1.06, "grip": 1.02, "bio": "Corre desde los 15 años en la tierra de las chacras. No regala nada."},
		"tip": "Rectas largas entre girasoles y trigo: buscá la velocidad final. Ojo con las curvas rápidas: entrar pasado de velocidad te lleva al alambrado.",
		"setup": "Asfalto rápido: más presión de gomas y la suspensión baja.",
		"pieces": [
			{"biome": RURAL, "crop": 2}, ["auto", 1700.0, "fast"], ["farm"], {"crop": 1}, ["auto", 1500.0, "rural"],
			{"crop": 2}, ["auto", 1400.0, "rural"], ["farm"], {"crop": 3}, ["auto", 1100.0, "rural"],
			{"town": 1}, ["town", "COLONIA ESPERANZA"], ["S", 250.0], ["L", 40.0, 70.0], ["S", 200.0], ["R", 40.0, 70.0], ["S", 200.0],
			{"town": 0, "crop": 1}, ["auto", 1300.0, "rural"], ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 220.0],
			["station", "Estación La Esperanza"],
		]},
	{"name": "El Puente del Río Manso", "sub": "Del campo al bosque, cruzando el río", "sky": "nublado",
		"rival": {"name": "Facundo Herrera", "car": "t1plus", "paint": "#2a9d4b", "skill": 0.84, "power": 1.12, "grip": 1.03, "bio": "Guardaparque y piloto los fines de semana. Conoce cada curva del bosque."},
		"tip": "Después del puente entrás al bosque: curvas más cerradas y sombra. Los guardarraíles perdonan poco: trazá limpio.",
		"setup": "Mixto: suspensión media y frenos un poco hacia adelante.",
		"pieces": [
			{"biome": RURAL, "crop": 4}, ["auto", 1300.0, "rural"], ["overpass", "rail"], ["auto", 900.0, "rural"],
			["sign", "PUENTE RÍO MANSO"], ["S", 160.0], ["bridge", 280.0], ["S", 80.0],
			{"biome": FOREST}, ["auto", 2200.0, "forest"],
			{"biome": CITY, "town": 1}, ["town", "SAN CAYETANO"], ["S", 180.0], ["R", 15.0, 90.0], ["S", 160.0], ["L", 15.0, 90.0], ["S", 220.0],
			{"biome": FOREST, "town": 0}, ["auto", 1500.0, "forest"], ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Estación del Río"],
		]},
	{"name": "Subida a la Sierra", "sub": "Montaña, precipicio y un taller a mitad de camino", "sky": "dia",
		"rival": {"name": "Chango Quiroga", "car": "pickup", "paint": "#f2c230", "skill": 0.85, "power": 1.35, "grip": 1.06, "bio": "Sube la sierra todos los días con la camioneta del puesto. Sabe dónde frenar."},
		"tip": "Subida larga: el auto pierde empuje en la pendiente y las curvas se cierran. A mitad de camino hay un taller por si golpeaste.",
		"setup": "Montaña: más tracción atrás y la suspensión firme para las curvas.",
		"pieces": [
			{"biome": FOREST, "grade": 0.03}, ["auto", 700.0, "forest"],
			{"biome": MOUNTAIN, "mside": 1, "grade": 0.06}, ["auto", 1500.0, "mountain"], ["sign", "TALLER A 500 m"], ["auto", 420.0, "mountain"],
			{"grade": 0.0}, ["workshop", "Taller El Chivo"], {"grade": 0.065, "mside": -1}, ["auto", 1700.0, "mountain"],
			{"grade": 0.02}, ["auto", 900.0, "mountain"], {"grade": 0.0}, ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 160.0],
			["station", "Refugio de la Sierra"],
		]},
	{"name": "El Túnel del Cóndor", "sub": "Túnel bajo la montaña y bajada larga", "sky": "atardecer",
		"rival": {"name": "Valentina Ríos", "car": "t1plus", "paint": "#7b2cbf", "skill": 0.87, "power": 1.14, "grip": 1.04, "bio": "Ingeniera de motores. Baja la montaña como si fuera llano."},
		"tip": "Hay un túnel largo: adentro está oscuro y los ojos tardan en acostumbrarse. Después viene una bajada larga: frená antes, el auto pesa hacia adelante.",
		"setup": "Bajada: frenos más atrás para que no se bloqueen adelante.",
		"pieces": [
			{"biome": MOUNTAIN, "mside": 1, "grade": 0.025}, ["auto", 1300.0, "mountain"], {"grade": 0.0},
			["S", 200.0],
			# bifurcación: el túnel sigue derecho (atajo); el camino principal sube por el paso y da la vuelta a la montaña
			["fork", {"sign": "↑ TÚNEL DEL CÓNDOR (atajo)\n↖ PASO DEL CÓNDOR", "tunnel": "TÚNEL DEL CÓNDOR", "biome": MOUNTAIN, "wiggle": [16.0, 2.5],
				"main": [{"grade": 0.04}, ["L", 150.0, 35.0], ["S", 150.0], ["R", 150.0, 35.0], {"grade": 0.0}, ["S", 100.0], {"grade": -0.04},
					["R", 150.0, 35.0], ["S", 150.0], ["L", 150.0, 35.0], {"grade": 0.0}]}],
			["S", 90.0],
			{"mside": -1, "grade": -0.06}, ["auto", 2300.0, "mountain"], {"grade": -0.03, "biome": FOREST}, ["auto", 1400.0, "forest"],
			{"grade": 0.0, "biome": RURAL, "crop": 4}, ["auto", 600.0, "rural"], ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Estación El Cóndor"],
		]},
	{"name": "Ciudad del Valle", "sub": "Avenidas, esquinas y un paso bajo nivel", "sky": "ocaso",
		"rival": {"name": "Nico «Turbo» Sosa", "car": "t1plus", "paint": "#00b4d8", "skill": 0.9, "power": 1.16, "grip": 1.05, "bio": "Corredor de picadas de la ciudad. Muy rápido en las rectas, se apura en las esquinas."},
		"tip": "La ciudad: esquinas a 90°, avenidas anchas y un paso bajo nivel. Las veredas están altas: no te subas al cordón.",
		"setup": "Ciudad: más agarre adelante y frenos fuertes.",
		"pieces": [
			{"biome": RURAL, "crop": 3}, ["auto", 900.0, "rural"], {"biome": CITY, "town": 2, "hw": 5.0}, ["town", "CIUDAD DEL VALLE"],
			["S", 300.0], ["L", 16.0, 90.0], ["S", 200.0],
			# bifurcación en L: la avenida dobla y rodea la manzana; derecho se va por una calle angosta del centro
			["fork", {"sign": "↑ CENTRO (calle angosta)\n→ AVENIDA", "hw": 3.0, "wiggle": [6.0, 2.0], "town": 2, "biome": CITY, "tk": 0.35,
				"main": [["R", 20.0, 90.0], ["S", 30.0], ["L", 20.0, 90.0], ["S", 70.0], ["L", 20.0, 90.0], ["S", 30.0], ["R", 20.0, 90.0]]}],
			["S", 160.0], ["R", 16.0, 90.0], ["S", 200.0], ["under"], ["S", 220.0], ["R", 18.0, 90.0],
			["S", 200.0], ["L", 16.0, 90.0], ["S", 300.0], ["L", 35.0, 45.0], ["S", 240.0], ["R", 35.0, 45.0], ["S", 340.0],
			["R", 16.0, 90.0], ["S", 200.0], ["L", 16.0, 90.0], ["S", 420.0], {"town": 1, "hw": 4.2}, ["S", 380.0],
			{"biome": RURAL, "town": 0, "crop": 1, "hw": 4.0}, ["auto", 1400.0, "rural"], ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Estación Ruta 7"],
		]},
	{"name": "Fin del Asfalto", "sub": "La ruta se vuelve tierra", "sky": "dia",
		"rival": {"name": "Gringo Müller", "car": "t1plus", "paint": "#f5f5f2", "skill": 0.89, "power": 1.12, "grip": 1.05, "bio": "Chacarero y piloto de rally. En la tierra se siente en casa."},
		"tip": "Se termina el asfalto: en la tierra el auto se desliza. Frená en línea recta, doblá suave y acelerá cuando el auto ya apunta a la salida.",
		"setup": "Tierra: tracción más atrás, gomas con menos presión y suspensión alta y blanda.",
		"pieces": [
			{"biome": RURAL, "crop": 1}, ["auto", 1300.0, "rural"], ["sign", "FIN DEL ASFALTO"], ["S", 120.0],
			{"surf": S_DIRT, "hw": 4.5, "crop": 4}, ["auto", 1500.0, "dirt"], ["sign", "GOMERÍA A 500 m"], ["auto", 420.0, "dirt"],
			["workshop", "Gomería Los Hermanos"], {"biome": FOREST}, ["auto", 2400.0, "dirt"], ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Almacén y Estación La Tranquera"],
		]},
	{"name": "La Cantera Roja", "sub": "Terrazas de piedra, una mina y la rampa de salida", "sky": "dia",
		"rival": {"name": "Don Ramón", "car": "truck", "paint": "#c1121f", "skill": 0.9, "power": 2.3, "grip": 1.22, "bio": "Lleva 30 años manejando el camión de la cantera. Diez toneladas que no frenan por nadie."},
		"tip": "En la cantera hay polvo y piedra suelta. Pasás por adentro de una mina oscura y al final hay una rampa muy empinada: subí la altura de la suspensión.",
		"setup": "Rampa: suspensión alta y dura, tracción repartida 50/50.",
		"pieces": [
			{"biome": QUARRY, "surf": S_DIRT, "hw": 5.0, "grade": -0.035}, ["auto", 900.0, "quarry"], {"grade": 0.0}, ["auto", 1300.0, "quarry"],
			["sign", "MINA SANTA BÁRBARA"], ["S", 100.0], ["mine", 420.0, "MINA SANTA BÁRBARA"], ["S", 80.0], ["auto", 800.0, "quarry"],
			["sign", "RAMPA 15%"], {"grade": 0.13}, ["ramp", 280.0], {"grade": 0.0, "biome": FOREST, "hw": 4.5}, ["auto", 1500.0, "dirt"],
			["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Estación La Mina"],
		]},
	{"name": "Bosque de los Coihues", "sub": "Bosque cerrado bajo la lluvia", "sky": "lluvia",
		"rival": {"name": "Lucía Ferreyra", "car": "t1plus", "paint": "#ff6a08", "skill": 0.89, "power": 1.13, "grip": 1.05, "bio": "Campeona de rally de bosque. Con lluvia es todavía más rápida."},
		"tip": "Llueve: la tierra se pone resbaladiza y el agarre baja. Frená antes y no muevas el volante de golpe. A mitad de etapa hay un taller.",
		"setup": "Lluvia: gomas de grava o barro, menos presión y suspensión blanda.",
		"pieces": [
			{"biome": FOREST, "surf": S_DIRT, "hw": 4.5}, ["auto", 1100.0, "forest"], ["S", 150.0],
			# bifurcación: un atajo angosto y embarrado entre los árboles, o el camino del bosque que da la vuelta
			["fork", {"sign": "↑ ATAJO DEL BARRO\n↗ CAMINO DEL BOSQUE", "surf": 5, "hw": 3.3, "tk": 0.5, "wiggle": [7.0, 4.0],
				"main": [["R", 60.0, 60.0], ["S", 120.0], ["L", 60.0, 60.0], ["S", 100.0], ["L", 60.0, 60.0], ["S", 120.0], ["R", 60.0, 60.0]]}],
			["auto", 900.0, "forest"], ["sign", "TALLER A 500 m"], ["auto", 420.0, "forest"],
			["workshop", "Taller El Coihue"], ["auto", 2300.0, "forest"], ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Estación Los Coihues"],
		]},
	{"name": "Primeras Nieves", "sub": "La subida a la cordillera", "sky": "nublado",
		"rival": {"name": "Mati Ortega", "car": "t1plus", "paint": "#3a0ca3", "skill": 0.91, "power": 1.14, "grip": 1.06, "bio": "Instructor de manejo en nieve. Sereno, preciso, imposible de apurar."},
		"tip": "Empieza a nevar: la nieve pisada agarra mucho menos que la tierra. Acelerá con suavidad y frená mucho antes de las curvas.",
		"setup": "Nieve: tracción repartida, gomas blandas y suspensión blanda.",
		"pieces": [
			{"biome": FOREST, "surf": S_DIRT, "grade": 0.035}, ["auto", 1400.0, "dirt"], {"biome": SNOW}, ["auto", 1000.0, "snow"],
			{"surf": S_SNOW}, ["auto", 2200.0, "snow"], {"grade": 0.0}, ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Refugio Nevado"],
		]},
	{"name": "Paso del Viento Blanco", "sub": "Primer jefe: El Lobo Blanco", "sky": "nieve",
		"rival": {"name": "El Lobo Blanco", "car": "genesis", "paint": "#eef1f5", "skill": 0.94, "power": 1.06, "grip": 1.04, "boss": true, "bio": "Nadie sabe quién es. Gana todas las carreras de nieve desde hace diez años."},
		"tip": "Primer jefe: El Lobo Blanco maneja un auto igual al tuyo y no comete errores. Hay un túnel de nieve y un taller antes de la parte más dura.",
		"setup": "Nieve de montaña: tracción repartida y frenos hacia adelante.",
		"pieces": [
			{"biome": SNOWMT, "surf": S_SNOW, "grade": 0.045, "mside": 1}, ["auto", 1300.0, "snow"], ["sign", "TALLER A 500 m"], ["auto", 420.0, "snow"],
			{"grade": 0.0}, ["workshop", "Refugio Mecánico"], {"grade": 0.03}, ["auto", 600.0, "snow"], {"grade": 0.0},
			["tunnel", 520.0, "TÚNEL DEL VIENTO BLANCO"], ["S", 60.0], {"mside": -1}, ["auto", 2000.0, "snow"], ["sign", "ESTACIÓN DE SERVICIO 1 km"], ["S", 150.0],
			["station", "Estación del Paso"],
		]},
	{"name": "La Cumbre de los Sueños", "sub": "La final: dos jefes a la vez", "sky": "atardecer",
		"rival": {"name": "La Sombra", "car": "genesis", "paint": "#1c1c22", "skill": 0.95, "power": 1.08, "grip": 1.05, "boss": true, "bio": "La leyenda de la Ruta de los Sueños. Corre junto al Lobo Blanco: los dos te esperan en la cumbre."},
		"rival2": {"name": "El Lobo Blanco", "car": "genesis", "paint": "#eef1f5", "skill": 0.96, "power": 1.1, "grip": 1.05, "boss": true},
		"tip": "La final: dos rivales súper rápidos. Cumbre con nieve y después una bajada larga hasta la Estación de los Sueños. Tenés que llegar primero.",
		"setup": "Final: el ajuste que más confianza te dé. En la bajada frenos fuertes.",
		"pieces": [
			{"biome": SNOWMT, "surf": S_SNOW, "grade": 0.04, "mside": 1}, ["auto", 1400.0, "snow"], {"grade": 0.0}, ["sign", "LA CUMBRE · 3.600 m"],
			["auto", 800.0, "snow"], {"grade": -0.055, "mside": -1}, ["auto", 2300.0, "snow"],
			{"surf": S_DIRT, "biome": FOREST, "grade": -0.03}, ["auto", 1400.0, "dirt"], {"grade": 0.0, "surf": S_ASPHALT, "biome": RURAL, "crop": 2, "hw": 4.2},
			["auto", 600.0, "rural"], ["sign", "ESTACIÓN DE LOS SUEÑOS"], ["S", 200.0],
			["station", "Estación de los Sueños"],
		]},
]

# ───────────────────────── ruta generada ─────────────────────────
var k := PackedFloat32Array() # curvatura (1/m, + = izquierda)
var grade := PackedFloat32Array()
var x := PackedFloat64Array()
var z := PackedFloat64Array()
var y := PackedFloat64Array()
var hd := PackedFloat64Array() # rumbo (rad)
var biome := PackedByteArray()
var surf := PackedByteArray()
var hw := PackedFloat32Array() # medio ancho del camino
var lay := PackedFloat32Array() # ensanche a la derecha (estaciones y talleres)
var flags := PackedInt32Array()
var crop := PackedByteArray() # 0 nada · 1 trigo · 2 girasol · 3 maíz · 4 pastura con vacas
var town := PackedByteArray() # 0 nada · 1 pueblo · 2 ciudad
var mside := PackedByteArray() # montaña a la derecha (1) o a la izquierda (0)
var events: Array = [] # {i, t, ...}
var stations: Array = [] # índice de la muestra de cada estación (surtidores)
var forks: Array = [] # bifurcaciones: {i0, i1, spec, + el ramal generado: x, z, y, k, ...}
var count := 0

static var _inst: RefCounted

static func get_route() -> RefCounted:
	if _inst == null:
		_inst = (load("res://game/adventure/adv_route.gd") as GDScript).new()
		_inst._generate()
	return _inst

static func stage_count() -> int:
	return STAGES.size()

var _st := {}
var _head := 0.0
var _rng := RandomNumberGenerator.new()

func _push(kc: float) -> void:
	k.append(kc)
	grade.append(float(_st["grade"]))
	biome.append(int(_st["biome"]))
	surf.append(int(_st["surf"]))
	hw.append(float(_st["hw"]))
	lay.append(0.0)
	flags.append(0)
	crop.append(int(_st["crop"]))
	town.append(int(_st["town"]))
	mside.append(int(_st["mside"]))
	_head += kc * DS
	count += 1

func _straight(L: float) -> void:
	for i in maxi(1, int(round(L / DS))):
		_push(0.0)

## Curva: R radio (m), deg ángulo (+ izquierda, − derecha)
func _arc(R: float, deg: float) -> void:
	var a := deg_to_rad(absf(deg))
	var n := maxi(1, int(round(R * a / DS)))
	var kc := a / (float(n) * DS) * signf(deg)
	for i in n:
		_push(kc)

func _auto(total: float, style: String) -> void:
	var S: Dictionary = STYLES[style]
	var aim := _head
	if _st.has("aim"):
		aim = float(_st["aim"])
	var bound := deg_to_rad(float(S["bound"]))
	var acc := 0.0
	var last := 0.0
	while acc < total:
		var L := _rng.randf_range(S["s"][0], S["s"][1])
		_straight(L)
		acc += L
		if acc >= total:
			break
		var R := _rng.randf_range(S["r"][0], S["r"][1])
		var a := deg_to_rad(_rng.randf_range(S["a"][0], S["a"][1]))
		var dev := wrapf(_head - aim, -PI, PI)
		var dir := 1.0 if _rng.randf() < 0.5 else -1.0
		if last != 0.0 and _rng.randf() < 0.72:
			dir = -last # alterna como una ruta de verdad
		if absf(dev) > bound * 0.45:
			dir = -signf(dev) # vuelve hacia el rumbo general
		if absf(dev + dir * a) > bound:
			a = maxf(deg_to_rad(12.0), bound - absf(dev))
			if absf(dev + dir * a) > bound:
				dir = -dir
		_arc(R, rad_to_deg(a) * dir)
		acc += R * a
		last = dir

func _mark(i0: int, i1: int, f: int) -> void:
	for i in range(maxi(0, i0), mini(count, i1)):
		flags[i] |= f

## Ensanche de la banquina derecha (para entrar a la estación o al taller): sube, se mantiene y baja
func _layby(i0: int, n: int, w: float, ramp: int) -> void:
	for j in n:
		var u := 1.0
		if j < ramp:
			u = float(j) / float(ramp)
		elif j > n - 1 - ramp:
			u = float(n - 1 - j) / float(ramp)
		u = u * u * (3.0 - 2.0 * u)
		lay[i0 + j] = maxf(lay[i0 + j], w * u)

func _piece(p) -> void:
	if p is Dictionary:
		for key in p:
			_st[key] = p[key]
		return
	var a: Array = p
	match str(a[0]):
		"S": _straight(float(a[1]))
		"L": _arc(float(a[1]), float(a[2]))
		"R": _arc(float(a[1]), -float(a[2]))
		"auto": _auto(float(a[1]), str(a[2]))
		"station":
			var i0 := count
			_straight(150.0)
			_layby(i0, 60, 15.0, 13)
			_mark(i0, i0 + 60, F_STATION)
			var anchor := i0 + 30
			stations.append(anchor)
			events.append({"i": anchor, "t": "station", "name": str(a[1])})
		"workshop":
			var i0 := count
			_straight(115.0)
			_layby(i0, 46, 12.0, 11)
			_mark(i0, i0 + 46, F_WORKSHOP)
			events.append({"i": i0 + 24, "t": "workshop", "name": str(a[1])})
		"tunnel", "mine":
			var i0 := count
			_straight(float(a[1]))
			_mark(i0, count, F_TUNNEL | (F_MINE if str(a[0]) == "mine" else 0))
			events.append({"i": i0, "i1": count - 1, "t": str(a[0]), "name": str(a[2])})
		"bridge":
			var i0 := count
			_straight(float(a[1]))
			_mark(i0, count, F_BRIDGE)
			events.append({"i": i0, "i1": count - 1, "t": "bridge"})
		"ramp":
			var i0 := count
			_straight(float(a[1]))
			_mark(i0, count, F_RAMP)
			events.append({"i": i0, "i1": count - 1, "t": "ramp"})
		"under":
			# paso bajo nivel: baja 4,5 m, pasa por debajo de la avenida y vuelve a subir
			var g0 := float(_st["grade"])
			var i0 := count
			_st["grade"] = -0.075
			_straight(60.0)
			_st["grade"] = 0.0
			_straight(45.0)
			_st["grade"] = 0.075
			_straight(60.0)
			_st["grade"] = g0
			_mark(i0, count, F_UNDER)
			events.append({"i": i0 + 24 + 9, "t": "overpass", "kind": "avenue", "i0": i0, "i1": count - 1})
		"overpass": events.append({"i": count, "t": "overpass", "kind": str(a[1])})
		"town": events.append({"i": count, "t": "town", "name": str(a[1])})
		"sign": events.append({"i": count, "t": "sign", "text": str(a[1])})
		"farm": events.append({"i": count + 30, "t": "farm", "side": 1 if _rng.randf() < 0.5 else -1})
		"fork":
			# bifurcación: el camino principal (piezas "main") y un ramal que se separa y vuelve a unirse más adelante
			var spec: Dictionary = a[1]
			var i0 := count
			events.append({"i": maxi(0, i0 - 34), "t": "sign", "text": str(spec["sign"])})
			for pp in spec["main"]:
				_piece(pp)
			forks.append({"i0": i0, "i1": count, "spec": spec})

func _generate() -> void:
	_st = {"biome": RURAL, "surf": S_ASPHALT, "hw": 4.2, "grade": 0.0, "crop": 0, "town": 0, "mside": 1}
	_head = 0.0
	for p in PRELUDE:
		_piece(p)
	for si in STAGES.size():
		_rng.seed = 1000 + si * 7919
		for p in STAGES[si]["pieces"]:
			_piece(p)
	_straight(300.0) # después de la última estación
	# curvatura suavizada (transiciones como clotoides) e integración del recorrido
	var ks := PackedFloat32Array()
	ks.resize(count)
	var W := 3
	for i in count:
		var s := 0.0
		for j in range(-W, W + 1):
			s += k[clampi(i + j, 0, count - 1)]
		ks[i] = s / float(2 * W + 1)
	x.resize(count)
	z.resize(count)
	y.resize(count)
	hd.resize(count)
	var h := 0.0
	var px := 0.0
	var pz := 0.0
	var py := 0.0
	for i in count:
		var hm := h + ks[i] * DS * 0.5
		x[i] = px
		z[i] = pz
		y[i] = py
		hd[i] = hm
		px += sin(hm) * DS
		pz += cos(hm) * DS
		py += float(grade[i]) * DS
		h += ks[i] * DS
	k = ks
	# altura suavizada (sin quiebres en los cambios de pendiente)
	for W2 in [16, 16, 8]:
		var o := PackedFloat64Array()
		o.resize(count)
		for i in count:
			var s := 0.0
			var c := 0
			for j in range(-W2, W2 + 1):
				var q := i + j
				if q >= 0 and q < count:
					s += y[q]
					c += 1
			o[i] = s / float(c)
		y = o
	for f in forks:
		_build_branch(f)

## El ramal de una bifurcación: curva suave (Hermite) desde el punto donde se separa hasta donde se vuelve a unir,
## saliendo y llegando con el rumbo del camino; la altura va derecha entre las dos puntas (más un lomo opcional).
func _build_branch(f: Dictionary) -> void:
	var i0: int = f["i0"]
	var i1: int = f["i1"]
	var spec: Dictionary = f["spec"]
	var P0 := Vector2(x[i0], z[i0])
	var P1 := Vector2(x[i1], z[i1])
	var D := P0.distance_to(P1)
	var T0 := Vector2(sin(hd[i0]), cos(hd[i0])) * D * float(spec.get("tk", 0.55))
	var T1 := Vector2(sin(hd[i1]), cos(hd[i1])) * D * float(spec.get("tk", 0.55))
	var bulge := float(spec.get("bulge", 0.0)) # desvío lateral del ramal (+ derecha)
	var dense: Array = []
	var N := 800
	for q in N + 1:
		var u := float(q) / float(N)
		var h00 := 2.0 * u * u * u - 3.0 * u * u + 1.0
		var h10 := u * u * u - 2.0 * u * u + u
		var h01 := -2.0 * u * u * u + 3.0 * u * u
		var h11 := u * u * u - u * u
		var pt := P0 * h00 + T0 * h10 + P1 * h01 + T1 * h11
		var dir := (P1 - P0).normalized()
		var right := Vector2(-dir.y, dir.x) # derecha del avance (en Godot, avanzando hacia +z la derecha es −x)
		if bulge != 0.0:
			pt += right * bulge * sin(PI * u)
		if spec.has("wiggle"):
			# eses: amplitud (m) y cantidad de ondas, que se apagan en las puntas
			var wg: Array = spec["wiggle"]
			var fade := sin(PI * u)
			pt += right * float(wg[0]) * sin(TAU * float(wg[1]) * u) * fade * fade
		dense.append(pt)
	# reparto cada 2,5 m
	var L := PackedFloat64Array([0.0])
	for q in range(1, dense.size()):
		L.append(L[q - 1] + (dense[q] as Vector2).distance_to(dense[q - 1]))
	var total: float = L[L.size() - 1]
	var m := maxi(4, int(round(total / DS)))
	var bx := PackedFloat64Array()
	var bz := PackedFloat64Array()
	var by := PackedFloat64Array()
	var q := 0
	for j in m + 1:
		var tgt := total * float(j) / float(m)
		while q < L.size() - 2 and L[q + 1] < tgt:
			q += 1
		var w := (tgt - L[q]) / maxf(1e-6, L[q + 1] - L[q])
		var pt2: Vector2 = (dense[q] as Vector2).lerp(dense[q + 1], w)
		bx.append(pt2.x)
		bz.append(pt2.y)
		var u2 := float(j) / float(m)
		by.append(lerpf(y[i0], y[i1], u2) + float(spec.get("hump", 0.0)) * sin(PI * u2))
	var bh := PackedFloat64Array()
	var bk := PackedFloat32Array()
	for j in m + 1:
		var ja := maxi(0, j - 1)
		var jb := mini(m, j + 1)
		bh.append(atan2(bx[jb] - bx[ja], bz[jb] - bz[ja]))
	for j in m + 1:
		var ja := maxi(0, j - 1)
		var jb := mini(m, j + 1)
		bk.append(wrapf(bh[jb] - bh[ja], -PI, PI) / maxf(0.1, float(jb - ja) * DS))
	f["x"] = bx
	f["z"] = bz
	f["y"] = by
	f["k"] = bk
	f["m"] = m

## Datos de una etapa para armar su pista: el camino principal (fork = −1) o la variante que toma el ramal de la bifurcación
## número fork. Todo con índices locales (0 = 250 m antes de la estación de largada).
func variant_data(si: int, fork := -1) -> Dictionary:
	var rg: Vector2i = stage_range(si)
	var g0 := maxi(0, rg.x - 100)
	var g1 := mini(count - 1, rg.y + 110)
	var src: Array = [] # [tipo, índice]: tipo 0 = ruta principal (global), 1 = ramal
	var F: Dictionary = {}
	if fork >= 0:
		F = forks[fork]
		for g in range(g0, int(F["i0"])):
			src.append([0, g])
		for j in range(0, int(F["m"])):
			src.append([1, j])
		for g in range(int(F["i1"]), g1 + 1):
			src.append([0, g])
	else:
		for g in range(g0, g1 + 1):
			src.append([0, g])
	var n := src.size()
	var d := {"n": n, "x": PackedFloat64Array(), "z": PackedFloat64Array(), "y": PackedFloat64Array(), "k": PackedFloat32Array(),
		"hw": PackedFloat32Array(), "lay": PackedFloat32Array(), "surf": PackedByteArray(), "biome": PackedByteArray(), "flags": PackedInt32Array(),
		"crop": PackedByteArray(), "town": PackedByteArray(), "mside": PackedByteArray(), "events": [], "g0": g0}
	var spec: Dictionary = F.get("spec", {})
	var shift := 0 # cuánto se corren los índices después del ramal
	if fork >= 0:
		shift = int(F["m"]) - (int(F["i1"]) - int(F["i0"]))
	for e in src:
		var g: int = e[1]
		if int(e[0]) == 0:
			d["x"].append(x[g])
			d["z"].append(z[g])
			d["y"].append(y[g])
			d["k"].append(k[g])
			d["hw"].append(hw[g])
			d["lay"].append(lay[g])
			d["surf"].append(surf[g])
			d["biome"].append(biome[g])
			d["flags"].append(flags[g])
			d["crop"].append(crop[g])
			d["town"].append(town[g])
			d["mside"].append(mside[g])
		else:
			var i0: int = F["i0"]
			var mm: int = F["m"]
			d["x"].append(F["x"][g])
			d["z"].append(F["z"][g])
			d["y"].append(F["y"][g])
			d["k"].append(F["k"][g])
			# en las puntas el ancho pasa de a poco al del ramal
			var u := minf(float(g), float(mm - g)) / 12.0
			d["hw"].append(lerpf(hw[i0], float(spec.get("hw", hw[i0])), clampf(u, 0.0, 1.0)))
			d["lay"].append(0.0)
			d["surf"].append(int(spec.get("surf", surf[i0])) if g > 3 and g < mm - 3 else surf[i0])
			d["biome"].append(int(spec.get("biome", biome[i0])))
			var fl := 0
			if spec.has("tunnel") and g >= 16 and g < mm - 16:
				fl |= F_TUNNEL
			d["flags"].append(fl)
			d["crop"].append(int(spec.get("crop", crop[i0])))
			d["town"].append(int(spec.get("town", town[i0])))
			d["mside"].append(mside[i0])
	# eventos con índices locales de esta variante
	for ev in events:
		var gi: int = ev["i"]
		var li := -1
		if fork >= 0 and gi >= int(F["i0"]) and gi < int(F["i1"]):
			continue # cosas del camino principal que el ramal no pasa
		if gi >= g0 and gi <= g1:
			li = gi - g0 + (shift if fork >= 0 and gi >= int(F["i1"]) else 0)
		if li < 0 or li >= n:
			continue
		var c: Dictionary = (ev as Dictionary).duplicate()
		c["i"] = li
		for key in ["i0", "i1"]:
			if c.has(key):
				var gk: int = int(c[key])
				c[key] = gk - g0 + (shift if fork >= 0 and gk >= int(F["i1"]) else 0)
		d["events"].append(c)
	if fork >= 0:
		var a0: int = int(F["i0"]) - g0
		if spec.has("tunnel"):
			d["events"].append({"i": a0 + 16, "i1": a0 + int(F["m"]) - 17, "t": "tunnel", "name": str(spec["tunnel"])})
		d["split"] = a0
		d["join"] = a0 + int(F["m"])
	# bifurcaciones de esta etapa (en el camino principal)
	var fl2: Array = []
	for fi in forks.size():
		var Fk: Dictionary = forks[fi]
		if int(Fk["i0"]) > g0 and int(Fk["i1"]) < g1:
			fl2.append({"fork": fi, "split": int(Fk["i0"]) - g0, "join": int(Fk["i1"]) - g0, "m": int(Fk["m"])})
	d["forks"] = fl2
	d["i_start"] = rg.x - g0
	d["i_end"] = rg.y - g0 + shift
	d["origin"] = Vector3(x[rg.x], y[rg.x], z[rg.x])
	return d

## Índices de la muestra de la estación de largada y de llegada de una etapa
func stage_range(si: int) -> Vector2i:
	return Vector2i(int(stations[si]), int(stations[si + 1]))

## Largo de una etapa en metros (de surtidor a surtidor)
func stage_length(si: int) -> float:
	var r := stage_range(si)
	return float(r.y - r.x) * DS
