extends RefCounted
## Datos del modo aventura: habilidades del piloto, guías de las estaciones (tutoriales de ajuste), el auto de la aventura
## y el progreso guardado en el perfil (profile.d["adv"]).

const AdvRoute := preload("res://game/adventure/adv_route.gd")

const CAR := "genesis" # el DR Bisonte XR (se queda en el garaje al terminar la aventura)
const PAINT := {"body": "#0c0d10", "accent": "#d4a017", "rim": "#16181c", "finish": "metal", "livery": 3}
const POINTS_PER_STAGE := 5
const MAX_LEVEL := 5

## Habilidades: cada nivel cuesta tantos puntos como su número (1+2+3+4+5 = 15 por habilidad)
const SKILLS := [
	{"id": "curve", "icon": "↪", "name": "Curvas", "desc": "Más agarre lateral: el auto dobla más rápido sin irse de cola.", "per": "+2,5 % de agarre en curva por nivel"},
	{"id": "launch", "icon": "⚡", "name": "Aceleración", "desc": "Mejor salida de las curvas y de las estaciones.", "per": "+3 % de potencia por nivel"},
	{"id": "brake", "icon": "🛑", "name": "Frenada", "desc": "Frenás más tarde y más fuerte.", "per": "+6 % de fuerza de freno por nivel"},
	{"id": "control", "icon": "🎯", "name": "Control", "desc": "Volante más rápido y el auto se recupera mejor de un derrape.", "per": "+6 % de respuesta del volante y más estabilidad por nivel"},
	{"id": "armor", "icon": "🛡", "name": "Resistencia", "desc": "El auto se rompe menos con los golpes (menos tiempo en el taller).", "per": "−12 % de daño por nivel"},
]

## Guías de las estaciones (se muestran antes de cada etapa): explican un ajuste y recomiendan uno para lo que viene
const GUIDES := [
	{"title": "Bienvenido a la estación", "text": "Cada estación de servicio guarda tu avance. Antes de salir podés ajustar el auto para lo que viene: el camino cambia (asfalto, tierra, nieve) y el auto se maneja distinto.\n\nEn la pestaña AJUSTE tenés lo más importante: tracción, presión de gomas, altura y dureza de la suspensión y frenos.", "preset": {}},
	{"title": "La tracción", "text": "El DR Bisonte tiene tracción en las cuatro ruedas y podés repartir la fuerza.\n• Más atrás (30–40 % adelante): el auto rota más, ideal para curvas rápidas en asfalto.\n• Más adelante (50 % o más): más estable y tracciona mejor saliendo de curvas lentas o en piso suelto.\nPara los campos que vienen: 40 % adelante.", "preset": {"split": 40}},
	{"title": "Las gomas y la presión", "text": "Con más presión la goma responde rápido y gasta menos energía: mejor en asfalto liso. Con menos presión se apoya más superficie: mejor en tierra, ripio y nieve.\nEn el bosque que viene el asfalto está gastado: 30 psi.", "preset": {"pressF": 30, "pressR": 30}},
	{"title": "La suspensión", "text": "Resortes duros y el auto bajo: menos balanceo y respuesta rápida, ideal en la montaña asfaltada. Blanda y alta: copia los pozos.\nLa subida a la sierra tiene curvas cerradas: suspensión firme (resortes 115 %) y barras 110 %.", "preset": {"springF": 115, "springR": 112, "arbF": 110, "arbR": 108, "height": -20}},
	{"title": "Bajadas y frenos", "text": "En bajada el peso se va adelante: si el reparto de frenos está muy adelante las ruedas delanteras se bloquean y el auto no dobla.\nPara la bajada del Cóndor: reparto 58 % adelante y frená en línea recta.", "preset": {"bias": 58}},
	{"title": "Manejar en la ciudad", "text": "Las esquinas de 90° se toman lento: frená fuerte en línea recta, doblá cuando ya bajaste la velocidad y acelerá a la salida. Más agarre adelante ayuda: barra delantera más blanda (90 %).", "preset": {"arbF": 90, "arbR": 105}},
	{"title": "Más adelante hay tierra", "text": "Se termina el asfalto. En la tierra el auto desliza: tracción repartida (45 %), gomas de grava (Rally) y menos presión (25 psi). La suspensión alta (+40 mm) y blanda copia los pozos.\nMirá la guía del mapa: después del taller la tierra sigue por el bosque.", "preset": {"split": 45, "pressF": 25, "pressR": 25, "height": 40, "springF": 88, "springR": 88}, "tires": "gravel"},
	{"title": "La rampa de la cantera", "text": "Al salir de la cantera hay una rampa del 13 %: con la suspensión baja el auto toca el piso al llegar arriba. Subí la altura al máximo (+80 mm) y endurecé un poco los amortiguadores (compresión 120 %).", "preset": {"height": 80, "bump": 120, "rebound": 110, "split": 50}, "tires": "gravel"},
	{"title": "Lluvia en el bosque", "text": "Con lluvia el agarre baja mucho. Gomas de barro (M/T) o de grava, presión baja (24 psi) y la suspensión blanda. Frená antes y no muevas el volante de golpe.", "preset": {"pressF": 24, "pressR": 24, "springF": 85, "springR": 85, "height": 40}, "tires": "mud"},
	{"title": "La nieve", "text": "La nieve pisada agarra mucho menos que la tierra. Tracción repartida (50 %), gomas blandas con poca presión y acelerá con suavidad: si patinan, levantá un poco el pie.", "preset": {"split": 50, "pressF": 24, "pressR": 24, "height": 30}, "tires": "gravel"},
	{"title": "El primer jefe", "text": "El Lobo Blanco maneja un auto igual al tuyo y no se equivoca. Usá tus puntos de habilidad: Curvas y Control ayudan mucho en la nieve.", "preset": {"split": 48, "pressF": 24, "pressR": 24}, "tires": "gravel"},
	{"title": "La final", "text": "Dos jefes a la vez: La Sombra y El Lobo Blanco. La cumbre tiene nieve, después tierra y al final asfalto hasta la Estación de los Sueños. Elegí el ajuste que más confianza te dé.", "preset": {"split": 48}, "tires": "gravel"},
]

static func default_state() -> Dictionary:
	return {"stage": 0, "points": 0, "skills": {"curve": 0, "launch": 0, "brake": 0, "control": 0, "armor": 0}, "tune": {}, "tires": "street",
		"damage": {"motor": 0.0, "dir": 0.0, "susp": 0.0}, "pull": 1.0, "intro": false, "best": {}, "tries": 0, "done": false, "started": false}

## Práctica (Carrera rápida → Ruta de los Sueños): un estado descartable, así no se toca el avance real de la aventura
static var practice: Dictionary = {}

static func state(profile: RefCounted) -> Dictionary:
	if not practice.is_empty():
		return practice
	if not profile.d.has("adv") or not (profile.d["adv"] is Dictionary):
		profile.d["adv"] = default_state()
	var st: Dictionary = profile.d["adv"]
	var def := default_state()
	for k in def:
		if not st.has(k):
			st[k] = def[k]
	return st

static func reset(profile: RefCounted) -> void:
	profile.d["adv"] = default_state()
	profile.save()

## Monedas por ganar una etapa por primera vez (crece de a poco: de $ 500 a $ 1.600)
static func stage_reward(stage: int) -> int:
	return 500 + stage * 100

static func cost(next_level: int) -> int:
	return next_level

## Estado del auto de la aventura para CarBuild (sin mejoras de taller: lo que cuenta es el ajuste y las habilidades)
static func car_state(st: Dictionary) -> Dictionary:
	var tires := str(st.get("tires", "street"))
	return {"upg": {"suspension": 3, "gearbox": 2, "diff": 2, "brakes": 1}, "tires": tires, "tiresOwned": [tires], "tune": (st["tune"] as Dictionary).duplicate(), "paint": PAINT.duplicate(), "km": 0.0}

## Habilidades y daño sobre los parámetros del auto (Dictionary de CarBuild antes de VehicleParams)
static func apply_skills(V: Dictionary, st: Dictionary) -> void:
	var sk: Dictionary = st["skills"]
	var c := float(sk.get("curve", 0))
	var l := float(sk.get("launch", 0))
	var b := float(sk.get("brake", 0))
	var ct := float(sk.get("control", 0))
	V["gripFront"] = float(V["gripFront"]) * (1.0 + 0.025 * c)
	V["gripRear"] = float(V["gripRear"]) * (1.0 + 0.025 * c)
	V["powerScale"] = float(V["powerScale"]) * (1.0 + 0.03 * l)
	V["brakeTorque"] = float(V["brakeTorque"]) * (1.0 + 0.06 * b)
	V["steerResponse"] = float(V["steerResponse"]) * (1.0 + 0.06 * ct)
	V["stabilityAssist"] = minf(1.0, float(V.get("stabilityAssist", 0.0)) + 0.04 * ct)

## Daño (0..1 por parte): motor → potencia · dirección → tira hacia un lado · suspensión → agarre
static func damage_mul(st: Dictionary) -> Dictionary:
	var d: Dictionary = st["damage"]
	return {"power": 1.0 - 0.3 * float(d["motor"]), "grip": 1.0 - 0.12 * float(d["susp"]), "pull": 0.14 * float(d["dir"]) * float(st.get("pull", 1.0))}

static func stage_name(si: int) -> String:
	return str(AdvRoute.STAGES[si]["name"])
