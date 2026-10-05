extends RefCounted
## Desgaste de neumáticos (Etapa 13). Funciones PURAS: cuánto se gasta una goma según cómo se maneja y cuánto agarre pierde. Cuenta barata (se llama unas 10 veces por segundo).
## Familias (de los neumáticos del catálogo): STREET (calle) · SPORT (deportivo y semi-slick) · RALLY (grava y barro) · DRIFT (drift).
## Desgaste = 0 (nueva) … 1 (lisa). Agarre = 1 − (1 − AGARRE_MIN)·desgaste^1,35: se aplica multiplicando el agarre por superficie del auto (surfGrip), que es lo que ya usa la física.
## Online: el desgaste de un auto online lo guarda el SERVIDOR (instancia del auto); acá sólo está la regla. Offline: local, en el perfil, separado del online.

const FAMILY := {"street": "STREET", "sport": "SPORT", "slick": "SPORT", "gravel": "RALLY", "mud": "RALLY", "drift": "DRIFT"}
const LIFE_KM := {"STREET": 90.0, "SPORT": 60.0, "RALLY": 75.0, "DRIFT": 35.0} # km de manejo tranquilo hasta dejarla lisa
const GRIP_MIN := {"STREET": 0.66, "SPORT": 0.60, "RALLY": 0.66, "DRIFT": 0.72}
const NAMES := {"STREET": "Calle", "SPORT": "Deportiva", "RALLY": "Rally", "DRIFT": "Drift"}

static func family(tire_id: String) -> String:
	return str(FAMILY.get(tire_id, "STREET"))

## Desgaste que se suma en dt segundos: speed (m/s), a_lat y a_long (m/s²), slip (exceso de deslizamiento, 0 = agarra), asphalt (¿va sobre asfalto?)
static func wear_step(tire_id: String, speed: float, a_lat: float, a_long: float, slip: float, asphalt: bool, dt: float) -> float:
	if speed < 0.3:
		return 0.0
	var f := family(tire_id)
	var base := speed * dt / 1000.0 / float(LIFE_KM[f])
	var stress := 1.0 + 1.6 * clampf(absf(a_lat) / 9.0, 0.0, 1.5) + 1.2 * clampf(absf(a_long) / 8.0, 0.0, 1.5) + 5.0 * clampf(slip, 0.0, 1.0)
	var surf := 1.0
	match f:
		"SPORT": surf = 1.0 if asphalt else 1.5 # las deportivas sufren en tierra
		"RALLY": surf = 1.45 if asphalt else 0.85 # las de rally se comen en asfalto
		"DRIFT": stress *= 1.4 # el compuesto del drift está hecho para quemarse
		_: surf = 1.0 if asphalt else 1.15
	return base * stress * surf

## Multiplicador del agarre (1 = nueva)
static func grip_factor(tire_id: String, wear: float) -> float:
	var w := clampf(wear, 0.0, 1.0)
	return 1.0 - (1.0 - float(GRIP_MIN[family(tire_id)])) * pow(w, 1.35)

## Estado en palabras (sin traducir: pasa por Tr.t)
static func state_name(wear: float) -> String:
	if wear < 0.12:
		return "Nuevas"
	if wear < 0.45:
		return "Buenas"
	if wear < 0.75:
		return "Gastadas"
	if wear < 0.92:
		return "Muy gastadas"
	return "Lisas"

## Precio de cambiar el juego de gomas (la mitad de lo que cuesta, mínimo 250)
static func replace_cost(tire_cost: float) -> int:
	return maxi(250, int(round(tire_cost * 0.5 / 50.0)) * 50)

## ¿Un avisos para el jugador? 0 = nada, 1 = ya están gastadas, 2 = casi lisas
static func warn_level(wear: float) -> int:
	if wear >= 0.9:
		return 2
	if wear >= 0.7:
		return 1
	return 0
